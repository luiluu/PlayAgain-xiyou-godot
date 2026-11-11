extends Node
## 自动更新第②批：补丁下载（多源、续传、校验）、登记、存档备份、启动计数与自动退回、手动退回。
## 用本进程里的小 HTTP 服务器（TCPServer，认 Range、能半路断开、能回占位页），不连外网。
## 只写 user://_test_update_install/，跑完删掉；存档备份用假的存档目录，不碰真存档。

const BootPatchScript := preload("res://core/boot_patch.gd")
const DIR := "user://_test_update_install"
const PORT := 18931
var results: Array = []
var _server := TCPServer.new()
var _files := {}       # 路径 → 字节
var _mode := {}        # 路径 → "ok"｜"cut"（发一半断开）｜"norange"（不认 Range）｜"placeholder"｜"404"
var _hits: Array = []  # [路径, Range 起点或 -1]

func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)

func _check(name: String, ok: bool) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL " + name)

func _process(_d: float) -> void:
	while _server.is_connection_available():
		_serve(_server.take_connection())

func _serve(c: StreamPeerTCP) -> void:
	var req := ""
	var waited := 0
	while not req.contains("\r\n\r\n") and waited < 200:
		c.poll()
		var n := c.get_available_bytes()
		if n > 0:
			req += c.get_utf8_string(n)
		else:
			waited += 1
			await get_tree().process_frame
	var path := req.split(" ")[1] if req.split(" ").size() > 1 else ""
	var start := -1
	for line in req.split("\r\n"):
		if line.to_lower().begins_with("range: bytes="):
			start = line.split("=")[1].split("-")[0].to_int()
	_hits.append([path, start])
	var mode: String = _mode.get(path, "ok")
	var data: PackedByteArray = _files.get(path.split("?")[0], PackedByteArray())
	var head := ""
	var body := data
	if mode == "redirect":
		head = "HTTP/1.1 302 Found\r\nLocation: %s\r\nContent-Length: 0\r\nConnection: close\r\n\r\n" % _url("/c.pck?signature=abc%3D")
		body = PackedByteArray()
	elif mode == "404" or not _files.has(path.split("?")[0]):
		head = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
		body = PackedByteArray()
	elif mode == "placeholder":
		body = "The content may contain violation information".to_utf8_buffer()
		head = "HTTP/1.1 200 OK\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body.size()
	elif start >= 0 and mode != "norange":
		body = data.slice(start)
		head = "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes %d-%d/%d\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [start, data.size() - 1, data.size(), body.size()]
	else:
		head = "HTTP/1.1 200 OK\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body.size()
	c.put_data(head.to_utf8_buffer())
	if mode == "cut":
		body = body.slice(0, body.size() / 2)  # 说好的长度没发完就断
	var off := 0
	while off < body.size():
		c.put_data(body.slice(off, mini(off + 65536, body.size())))
		off += 65536
		await get_tree().process_frame
	for i in range(40 if mode == "cut" else 1):  # 断线前留点时间让对面把已发的收走（真网络里大文件是边收边写的）
		await get_tree().process_frame
	c.disconnect_from_host()

func _url(path: String) -> String:
	return "http://127.0.0.1:%d%s" % [PORT, path]

func _patch(urls: Array, data: PackedByteArray, code := 9470) -> Dictionary:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return {"code": code, "size": data.size(), "sha256": ctx.finish().hex_encode(), "urls": urls}

func _rm(path: String) -> void:
	XUpdateInstall._remove_dir(path)

func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _state() -> Variant:
	return XUpdateInstall._read_json(XUpdateInstall.state_path())

func _run() -> void:
	_rm(DIR)
	DirAccess.make_dir_recursive_absolute(DIR)
	XUpdateInstall.dir = DIR.path_join("updates")
	_check("假服务器起来了", _server.listen(PORT, "127.0.0.1") == OK)
	var inst := XUpdateInstall.instance(get_tree())
	var data := PackedByteArray()
	data.resize(300000)
	for i in range(data.size()):
		data[i] = (i * 31 + 7) % 251
	_files = {"/a.pck": data, "/b.pck": data, "/c.pck": data}
	var base := 453
	var final := XUpdateInstall.dir.path_join("patch_453_9470.pck")
	var seen := []
	inst.progress.connect(func(d, t): seen.append([d, t]))

	# 1 正常下载（valid_patch 要 https，测试里放开成本机地址：直接调 download 前先过一遍结构）
	var p := _patch([_url("/a.pck")], data)
	_check("本机 http 地址过不了 valid_patch（正式只认 https）", not XUpdateCheck.valid_patch(p))
	XUpdateInstall.allow_http_for_tests = true
	var got := await inst.download(p, base)
	_check("正常下载：文件到位、字节一致", got == final and FileAccess.get_file_as_bytes(final) == data)
	_check("没留下 .part／.chunk", not FileAccess.file_exists(final + ".part") and not FileAccess.file_exists(final + ".chunk"))
	_check("报过进度，最后是满的", not seen.is_empty() and seen[-1] == [data.size(), data.size()])
	_hits.clear()
	got = await inst.download(p, base)
	_check("已有校验过的文件就不再下载", got == final and _hits.is_empty())

	# 2 第一个地址发一半断开，第二个地址带 Range 续上
	DirAccess.remove_absolute(final)
	_mode = {"/a.pck": "cut"}
	_hits.clear()
	got = await inst.download(_patch([_url("/a.pck"), _url("/b.pck")], data), base)
	_check("断在半路后换地址续传成功", got == final and FileAccess.get_file_as_bytes(final) == data)
	_check("第二个地址是带 Range 从断点接着下的", _hits.size() == 2 and _hits[0] == ["/a.pck", -1] and _hits[1][0] == "/b.pck" and _hits[1][1] > 0 and _hits[1][1] <= data.size() / 2)

	# 3 都断了：返回失败但留着 .part；下次再点接着下
	DirAccess.remove_absolute(final)
	_mode = {"/a.pck": "cut"}
	got = await inst.download(_patch([_url("/a.pck")], data), base)
	_check("下不完返回失败、已下的留在 .part", got == "" and XUpdateInstall._file_size(final + ".part") > 0 and XUpdateInstall._file_size(final + ".part") <= data.size() / 2 and not inst.busy)
	var had := XUpdateInstall._file_size(final + ".part")
	_mode = {}
	_hits.clear()
	got = await inst.download(_patch([_url("/a.pck")], data), base)
	_check("下次接着下（带 Range），完成", got == final and _hits == [["/a.pck", had]] and FileAccess.get_file_as_bytes(final) == data)

	# 3b 续传到一半又断：收到的那截接上，下一个地址从更后面的位置续
	DirAccess.remove_absolute(final)
	var q := FileAccess.open(final + ".part", FileAccess.WRITE)
	q.store_buffer(data.slice(0, 100000))
	q.close()
	_mode = {"/a.pck": "cut"}
	_hits.clear()
	got = await inst.download(_patch([_url("/a.pck"), _url("/b.pck")], data), base)
	_check("续传中又断线：那一截也留着，下一个地址从 20 万字节处接着下", got == final and _hits == [["/a.pck", 100000], ["/b.pck", 200000]] and FileAccess.get_file_as_bytes(final) == data)
	# 3c 取消：返回失败，已下的留着
	DirAccess.remove_absolute(final)
	_mode = {"/a.pck": "cut"}
	inst.progress.connect(func(d, t): inst.cancel(), CONNECT_ONE_SHOT)
	got = await inst.download(_patch([_url("/a.pck"), _url("/b.pck")], data), base)
	_check("取消后返回失败、不再试下一个地址", got == "" and not inst.busy and not FileAccess.file_exists(final))
	DirAccess.remove_absolute(final + ".part")
	DirAccess.remove_absolute(final + ".chunk")
	_mode = {}

	# 4 服务器不认 Range：整份重下也对
	DirAccess.remove_absolute(final)
	var half := FileAccess.open(final + ".part", FileAccess.WRITE)
	half.store_buffer(data.slice(0, 1000))
	half.close()
	_mode = {"/a.pck": "norange"}
	got = await inst.download(_patch([_url("/a.pck")], data), base)
	_check("不认 Range 的服务器：整份换上", got == final and FileAccess.get_file_as_bytes(final) == data)

	# 5 占位页、404：换下一个地址
	DirAccess.remove_absolute(final)
	_mode = {"/a.pck": "placeholder", "/b.pck": "404"}
	got = await inst.download(_patch([_url("/a.pck"), _url("/b.pck"), _url("/c.pck")], data), base)
	_check("占位页和 404 都跳过，第三个地址成功", got == final and FileAccess.get_file_as_bytes(final) == data)

	# 5b 跳转（Gitee 的 raw 地址会 302 到带签名参数的地址）
	DirAccess.remove_absolute(final)
	_mode = {"/a.pck": "redirect"}
	_hits.clear()
	got = await inst.download(_patch([_url("/a.pck")], data), base)
	_check("跟着 302 跳转下载", got == final and _hits.size() == 2 and _hits[1][0] == "/c.pck?signature=abc%3D" and FileAccess.get_file_as_bytes(final) == data)

	# 6 .part 里是坏内容：SHA 不符，删掉整份重来
	DirAccess.remove_absolute(final)
	var junk := FileAccess.open(final + ".part", FileAccess.WRITE)
	var bad := data.duplicate()
	bad[5] = bad[5] ^ 1
	junk.store_buffer(bad)
	junk.close()
	_mode = {}
	got = await inst.download(_patch([_url("/a.pck")], data), base)
	_check("已下的内容不对：删掉重下", got == final and FileAccess.get_file_as_bytes(final) == data)

	# 7 服务器上的文件和清单对不上：失败，不留下正式文件
	DirAccess.remove_absolute(final)
	var wrong := _patch([_url("/a.pck")], data)
	wrong["sha256"] = "0".repeat(64)
	got = await inst.download(wrong, base)
	_check("内容和清单的 SHA 对不上：失败、不留正式文件", got == "" and not FileAccess.file_exists(final))

	# 7b 页面走一遍：立即更新 → 下载 → 备份存档 → 登记 → 提示重启
	XUpdateInstall.save_dir = DIR.path_join("modes")
	_write(XUpdateInstall.save_dir.path_join("xiyou/save_1.json"), "一号档")
	var client_was := XUpdateClient.ENABLED
	XUpdateClient.ENABLED = false  # 页面打开时的检查不联网
	var saved_stamp := XUpdateClient.stamp_path
	XUpdateClient.stamp_path = DIR.path_join("check.json")
	var host := Control.new()
	get_tree().root.add_child(host)
	var page := XUpdatePage.open(host)
	for i in range(6):
		await get_tree().process_frame
	_check("页面上没有正在用的补丁时不显示退回按钮", not (page.find_child("Rollback", true, false) as Button).visible)
	var res := {"state": XUpdateCheck.PATCH, "current": "0.453", "version": "0.9470", "code": 9470, "date": "", "notes": PackedStringArray(), "patch": _patch([_url("/a.pck")], data), "revoked": false}
	page.show_result(res)
	_mode = {}
	(page.find_child("Primary", true, false) as Button).pressed.emit()
	_check("点立即更新后进入下载中", page.state == "downloading")
	for i in range(600):
		if page.state != "downloading":
			break
		await get_tree().process_frame
	_check("下完显示已准备好", page.state == "ready" and (page.find_child("Body", true, false) as Label).text.contains("新版本 0.9470 已下载，存档已备份"))
	_check("已登记、待重启生效", XUpdateInstall.pending_code() == 9470 and _state()["confirmed"] == false)
	var backups := DirAccess.open(XUpdateInstall.dir.path_join("save_backup")).get_directories()
	_check("登记前备份了存档", backups.size() == 1 and FileAccess.get_file_as_string(XUpdateInstall.dir.path_join("save_backup").path_join(backups[0]).path_join("xiyou/save_1.json")) == "一号档")
	page.close_page()
	await get_tree().process_frame
	page = XUpdatePage.open(host)
	await get_tree().process_frame
	_check("再打开直接显示已准备好（不重复下载）", page.state == "ready")
	page.close_page()
	host.queue_free()
	XUpdateInstall.rollback(true)
	XUpdateInstall.take_rollback_notice()
	XUpdateInstall._remove_dir(XUpdateInstall.dir.path_join("save_backup"))
	XUpdateClient.ENABLED = client_was
	XUpdateClient.stamp_path = saved_stamp
	XUpdateClient.instance(get_tree()).last = {}

	# 8 开关
	XUpdateInstall.ENABLED = false
	got = await inst.download(_patch([_url("/a.pck")], data), base)
	_check("开关关着不下载", got == "")
	XUpdateInstall.ENABLED = true
	XUpdateInstall.allow_http_for_tests = false
	_server.stop()

	# 9 存档备份：只留最近三份
	var saves := DIR.path_join("modes")
	_write(saves.path_join("xiyou/save_1.json"), "一号档")
	_write(saves.path_join("xiyou/sub/x.json"), "子目录")
	var b1 := XUpdateInstall.backup_saves(9470, saves)
	_check("备份到 save_backup，内容和目录结构一致", b1 != "" and FileAccess.get_file_as_string(b1.path_join("xiyou/save_1.json")) == "一号档" and FileAccess.get_file_as_string(b1.path_join("xiyou/sub/x.json")) == "子目录")
	for i in range(4):
		XUpdateInstall.backup_saves(471 + i, saves)
	var kept := DirAccess.open(XUpdateInstall.dir.path_join("save_backup")).get_directories()
	_check("只留最近 3 份", kept.size() == 3 and not DirAccess.dir_exists_absolute(b1))
	_check("原存档没被动", FileAccess.get_file_as_string(saves.path_join("xiyou/save_1.json")) == "一号档")
	_check("没有存档目录时不算失败", XUpdateInstall.backup_saves(9470, DIR.path_join("没有")) == "")

	# 10 登记、待生效、退回
	var f := FileAccess.open(final, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()
	var p9470 := _patch(["https://x.invalid/p"], data, 9470)
	_check("登记成功", XUpdateInstall.register(p9470, base))
	var st = _state()
	_check("登记内容：未确认、计数 0、没有上一份", st["file"] == "patch_453_9470.pck" and st["confirmed"] == false and st["boots"] == 0 and st["prev"] == null and int(st["code"]) == 9470 and int(st["base"]) == 453)
	_check("待生效的是 9470", XUpdateInstall.pending_code() == 9470)
	var p_bad := p9470.duplicate()
	p_bad["sha256"] = "0".repeat(64)
	_check("文件和清单对不上不登记", not XUpdateInstall.register(p_bad, base))

	# 启动计数：两次没确认，第三次启动前退回
	var sp := XUpdateInstall.state_path()
	BootPatchScript.prepare(sp)
	_check("第一次启动计 1", int(_state()["boots"]) == 1)
	BootPatchScript.prepare(sp)
	_check("第二次启动计 2", int(_state()["boots"]) == 2)
	BootPatchScript.prepare(sp)
	_check("两次都没确认：退回安装包自带内容（登记删掉）", not FileAccess.file_exists(sp))
	var note := XUpdateInstall.take_rollback_notice()
	_check("留了退回提示，读一次就没了", int(note.get("code", 0)) == 9470 and note.get("reason") == "启动失败" and XUpdateInstall.take_rollback_notice().is_empty())

	# 确认后不再计数；再装新补丁，上一份记在 prev；新补丁启动失败退回上一份
	XUpdateInstall.register(p9470, base)
	BootPatchScript.prepare(sp)
	BootPatchScript.confirm(sp)
	_check("确认后 confirmed、计数清零", _state()["confirmed"] == true and int(_state()["boots"]) == 0)
	BootPatchScript.prepare(sp)
	BootPatchScript.prepare(sp)
	BootPatchScript.prepare(sp)
	_check("确认过的补丁再启动多少次都不退回", int(_state()["code"]) == 9470)
	var data2 := data.slice(0, 5000)
	var f2 := FileAccess.open(XUpdateInstall.dir.path_join("patch_453_9475.pck"), FileAccess.WRITE)
	f2.store_buffer(data2)
	f2.close()
	var p9475 := _patch(["https://x.invalid/p"], data2, 9475)
	_check("登记 9475", XUpdateInstall.register(p9475, base))
	st = _state()
	_check("上一份 9470 记在 prev，文件留着", int(st["code"]) == 9475 and int(st["prev"]["code"]) == 9470 and FileAccess.file_exists(final))
	BootPatchScript.prepare(sp)
	BootPatchScript.prepare(sp)
	BootPatchScript.prepare(sp)
	st = _state()
	_check("9475 两次没起来：自动退回 9470（已确认）", int(st["code"]) == 9470 and st["confirmed"] == true and st["file"] == "patch_453_9470.pck")
	var r: Dictionary = BootPatchScript.apply(sp)
	_check("退回后的 9470 能过载入器的校验（底包号不符在测试里是预期）", not ["登记坏了", "文件不在", "字节数不符", "校验不符"].has(r["reason"]))
	XUpdateInstall.take_rollback_notice()

	# 手动退回
	XUpdateInstall.register(p9475, base)
	BootPatchScript.confirm(sp)
	_check("手动退回上一份", XUpdateInstall.rollback(false) == 9470 and int(_state()["code"]) == 9470)
	_check("手动退回到安装包自带内容", XUpdateInstall.rollback(true) == 0 and not FileAccess.file_exists(sp))
	_check("没有登记时退回不出错", XUpdateInstall.rollback(true) == 0)

	# 静默检查见到「现在运行的版本被撤回」：登记着的就是正在跑的才退；已登记新补丁只差重启时不退（审查 78 P3-4）
	XUpdateInstall.register(p9470, base)
	BootPatchScript.confirm(sp)
	var client := XUpdateClient.instance(get_tree())
	var keep := {"urls": XUpdateClient.channel_urls, "key": XUpdateClient.public_key, "stamp": XUpdateClient.stamp_path, "result": BootPatchScript.result.duplicate()}
	var key := Crypto.new().generate_rsa(2048)
	XUpdateClient.public_key = key.save_to_string(true)
	XUpdateClient.channel_urls = PackedStringArray(["https://a.invalid/godot/channel.json"])
	XUpdateClient.stamp_path = DIR.path_join("check2.json")
	var cur_code := XUpdateClient.current_code()
	var man := JSON.stringify({"schema": 1, "latest": {"version": "0.%d" % (cur_code + 9), "code": cur_code + 9}, "bases": {}, "min_base": 0, "revoked": [cur_code]}).to_utf8_buffer()
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(man)
	var sig := Crypto.new().sign(HashingContext.HASH_SHA256, hc.finish(), key)
	client.fetcher = func(url: String) -> PackedByteArray: return sig if url.ends_with(".sig") else man
	# 假装正在跑的是一个补丁（号＝当前号，底包更旧），登记里却已经是更新的 470
	BootPatchScript.result = {"loaded": true, "reason": "已载入", "code": cur_code, "base": cur_code - 1, "confirmed": true}
	await get_tree().process_frame  # 让前面关掉的检查更新页真正离开场景树（页面开着时由页面处理撤回）
	await get_tree().process_frame
	var rr: Dictionary = await client.check()
	_check("撤回名单里有现在运行的版本", rr["revoked"] == true)
	_check("已登记新补丁只差重启：静默检查不退回", int(_state()["code"]) == 9470 and XUpdateInstall.take_rollback_notice().is_empty())
	# 登记着的就是正在跑的：退
	BootPatchScript.result = {"loaded": true, "reason": "已载入", "code": 9470, "base": cur_code - 1, "confirmed": true}
	_check("这时没有待生效的", XUpdateInstall.pending_code() == 0)
	man = JSON.stringify({"schema": 1, "latest": {"version": "0.%d" % (cur_code + 9), "code": cur_code + 9}, "bases": {}, "min_base": 0, "revoked": [cur_code]}).to_utf8_buffer()
	rr = await client.check()
	_check("登记着的就是正在跑的被撤回版本：静默检查退回", rr["revoked"] == true and not FileAccess.file_exists(sp) and XUpdateInstall.take_rollback_notice().get("reason") == "已撤回")
	client.fetcher = Callable()
	client.last = {}
	BootPatchScript.result = keep["result"]
	XUpdateClient.channel_urls = keep["urls"]
	XUpdateClient.public_key = keep["key"]
	XUpdateClient.stamp_path = keep["stamp"]
	f = FileAccess.open(final, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()

	# 旧文件清理：登记 9475 后只留 9475 和上一份
	var f3 := FileAccess.open(XUpdateInstall.dir.path_join("patch_453_460.pck"), FileAccess.WRITE)
	f3.store_string("旧的")
	f3.close()
	XUpdateInstall.register(p9470, base)
	BootPatchScript.confirm(sp)
	f2 = FileAccess.open(XUpdateInstall.dir.path_join("patch_453_9475.pck"), FileAccess.WRITE)  # 上面登记 9470 时已把它当旧文件清掉
	f2.store_buffer(data2)
	f2.close()
	f3 = FileAccess.open(XUpdateInstall.dir.path_join("patch_453_460.pck"), FileAccess.WRITE)
	f3.store_string("旧的")
	f3.close()
	XUpdateInstall.register(p9475, base)
	_check("登记时清掉用不到的旧补丁，留现在和上一份", not FileAccess.file_exists(XUpdateInstall.dir.path_join("patch_453_460.pck")) and FileAccess.file_exists(final) and FileAccess.file_exists(XUpdateInstall.dir.path_join("patch_453_9475.pck")))

	# 页面文字
	_check("下载中", XUpdatePage.texts({"state": "downloading", "done": 1048576, "total": 2097152}, true)["body"].begins_with("1.0 MB / 2.0 MB") and XUpdatePage.texts({"state": "downloading"}, true)["primary"] == "取消下载")
	_check("已准备好", XUpdatePage.texts({"state": "ready", "version": "0.9475"}, true)["body"].contains("新版本 0.9475 已下载，存档已备份") )
	_check("没下完", XUpdatePage.texts({"state": "failed", "version": "0.9475", "message": "已取消。"}, true)["body"].contains("已取消。") and XUpdatePage.texts({"state": "failed"}, true)["primary"] == "再试一次")

	XUpdateInstall.dir = BootPatchScript.DIR
	XUpdateInstall.save_dir = XUpdateInstall.SAVE_DIR
	inst.queue_free()
	_rm(DIR)
	var passed := results.filter(func(x): return x["passed"]).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
