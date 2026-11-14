extends Node
## 强制更新（XForceUpdate、XUpdatePage.open_forced、清单 min_playable／download_url，Kyo 11-14）。
## 清单用假 fetcher（不联网）、测试自己的密钥签；补丁下载用本进程里的小 HTTP 服务器（127.0.0.1），不连外网。
## 只写 user://_test_force_update/，跑完删掉；存档备份用假的存档目录，不碰真存档。

const DIR := "user://_test_force_update"
const PORT := 18947
const TITLE := "res://modes/xiyou/entry.tscn"
var results: Array = []
var _served := {}     # 清单 url → 字节
var _delay := 1       # 假 fetcher 每次等几帧
var _files := {}      # HTTP 路径 → 字节
var _server := TCPServer.new()
var _key: CryptoKey
var _opened: Array = []

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

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _send(action: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)

func _process(_d: float) -> void:
	while _server.is_listening() and _server.is_connection_available():
		_serve(_server.take_connection())

## 只会回 200 整份或 404 的小服务器
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
	if _files.has(path):
		var body: PackedByteArray = _files[path]
		c.put_data(("HTTP/1.1 200 OK\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body.size()).to_utf8_buffer())
		c.put_data(body)
	else:
		c.put_data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_utf8_buffer())
	await _frames(2)
	c.disconnect_from_host()

func _url(path: String) -> String:
	return "http://127.0.0.1:%d%s" % [PORT, path]

func _fake_fetch(url: String) -> PackedByteArray:
	await _frames(_delay)
	return _served.get(url, PackedByteArray())

func _sign(raw: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(raw)
	return Crypto.new().sign(HashingContext.HASH_SHA256, ctx.finish(), _key)

func _manifest(code: int, base: int, patch_code := 0, extra := {}) -> Dictionary:
	var d := {"schema": 1, "latest": {"version": "0.%d" % code, "code": code, "date": "2026-11-20", "notes": ["修了一处"]},
		"bases": {}, "min_base": 0, "revoked": []}
	if patch_code > 0:
		d["bases"][str(base)] = {"patch": {"code": patch_code, "size": _pck.size(), "sha256": _sha(_pck), "urls": ["https://example.invalid/p.pck"]}}
	d.merge(extra, true)
	return d

var _pck := "假补丁内容".repeat(500).to_utf8_buffer()

func _sha(b: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(b)
	return ctx.finish().hex_encode()

## 把清单放到假源上（raw 给了就用 raw 的字节，签名照样对）
func _serve_manifest(m: Variant) -> void:
	var raw: PackedByteArray = m if m is PackedByteArray else JSON.stringify(m).to_utf8_buffer()
	_served = {"https://a.invalid/godot/channel.json": raw, "https://a.invalid/godot/channel.sig": _sign(raw)}

## 跑一遍门：清掉上次的、开始查、等查完、出标题
func _gate(host: Control, hint: Control) -> XUpdatePage:
	XForceUpdate.reset()
	XUpdateClient.instance(get_tree()).last = {}
	XForceUpdate.begin(get_tree())
	for i in range(60):
		if XForceUpdate._done:
			break
		await get_tree().process_frame
	return XForceUpdate.on_title(host, hint)

func _close_all(host: Node) -> void:
	for c in host.get_children():
		if c is CanvasLayer:
			host.remove_child(c)
			c.free()

func _cleanup(path := DIR) -> void:
	var da := DirAccess.open(path)
	if da:
		for n in da.get_files():
			da.remove(n)
		for sub in da.get_directories():
			_cleanup(path.path_join(sub))
		DirAccess.remove_absolute(path)

func _run() -> void:
	XUpdateCheck.release_name = ""
	XUpdateCheck.release_base = 1
	_cleanup()
	DirAccess.make_dir_recursive_absolute(DIR)
	_key = Crypto.new().generate_rsa(2048)
	var C := XUpdateCheck

	# ── 清单判断（纯函数）
	var r := C.evaluate(_manifest(470, 453, 470, {"min_playable": 465}), 453, 460)
	_check("低于最低可玩版本＝强制", r["forced"] and r["state"] == C.PATCH and r["min_playable"] == 465)
	r = C.evaluate(_manifest(470, 453, 470, {"min_playable": 460}), 453, 460)
	_check("等于最低可玩版本＝不强制（照旧红点）", not r["forced"] and r["state"] == C.PATCH)
	r = C.evaluate(_manifest(470, 453, 470, {"min_playable": 455}), 453, 460)
	_check("高于最低可玩版本＝不强制", not r["forced"])
	r = C.evaluate(_manifest(470, 453, 470), 453, 460)
	_check("老清单没有 min_playable＝不强制", not r["forced"] and r["min_playable"] == 0 and r["download_url"] == "")
	r = C.evaluate(_manifest(470, 453, 470, {"min_playable": "999"}), 453, 460)
	_check("min_playable 不是数字＝不强制", not r["forced"])
	r = C.evaluate(_manifest(460, 453, 0, {"min_playable": 470}), 453, 460)
	_check("清单没有更新的版本时不强制（拦了也没东西可更新）", not r["forced"] and r["state"] == C.LATEST)
	r = C.evaluate(_manifest(470, 400, 470, {"min_playable": 465, "download_url": "https://example.invalid/dl"}), 453, 460)
	_check("底包没有补丁＝强制且只能整包，带下载页", r["forced"] and r["state"] == C.FULL and r["download_url"] == "https://example.invalid/dl")
	r = C.evaluate(_manifest(470, 453, 470, {"min_playable": 465, "download_url": "http://example.invalid/dl"}), 453, 460)
	_check("下载页不是 https 不认", r["download_url"] == "")
	_check("清单多了字段 parse 照样认（老客户端只看 schema 和 latest）", not C.parse(JSON.stringify(_manifest(470, 453, 0, {"min_playable": 465, "download_url": "https://x"}))).is_empty())

	# ── 门：开关与条件
	var saved := {"urls": XUpdateClient.channel_urls, "key": XUpdateClient.public_key, "stamp": XUpdateClient.stamp_path,
		"dir": XUpdateInstall.dir, "save_dir": XUpdateInstall.save_dir, "wait": XForceUpdate.WAIT_SEC}
	XUpdateClient.channel_urls = PackedStringArray(["https://a.invalid/godot/channel.json"])
	XUpdateClient.public_key = _key.save_to_string(true)
	XUpdateClient.stamp_path = DIR.path_join("check.json")
	XUpdateInstall.dir = DIR.path_join("updates")
	XUpdateInstall.save_dir = DIR.path_join("modes")
	XUpdateInstall.allow_http_for_tests = true
	var client := XUpdateClient.instance(get_tree())
	client.fetcher = _fake_fetch
	var base := XUpdateClient.base_code()
	var cur := XUpdateClient.current_code()
	_check("调试构建不查", not XForceUpdate.wanted())
	ReleaseEntry.simulate_release = true
	_check("发行构建、无头默认不查（冒烟不联网）", not XForceUpdate.wanted())
	XForceUpdate.allow_headless = true
	_check("发行构建查", XForceUpdate.wanted())
	XForceUpdate.ENABLED = false
	_check("开关关了不查", not XForceUpdate.wanted())
	XForceUpdate.reset()
	XForceUpdate.begin(get_tree())
	_check("开关关了 begin 什么都不做、出标题不拦", not XForceUpdate._started and XForceUpdate.on_title(self) == null)
	XForceUpdate.ENABLED = true
	XUpdateClient.ENABLED = false
	_check("更新总开关关了也不查", not XForceUpdate.wanted())
	XUpdateClient.ENABLED = true

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(host)
	var hint := Control.new()
	host.add_child(hint)

	# 等于／高于／没有字段：放行
	_serve_manifest(_manifest(cur + 5, base, cur + 5, {"min_playable": cur}))
	_check("等于最低可玩版本：放行", await _gate(host, hint) == null and XForceUpdate.result["state"] == C.PATCH)
	_check("放行时红点照旧", client.has_update())
	_serve_manifest(_manifest(cur + 5, base, cur + 5, {"min_playable": cur - 1}))
	_check("高于最低可玩版本：放行", await _gate(host, hint) == null)
	_serve_manifest(_manifest(cur + 5, base, cur + 5))
	_check("没有 min_playable：放行", await _gate(host, hint) == null)
	_check("查到了就不放「未能检查更新」", hint.get_node_or_null("UpdateOfflineHint") == null)
	# 断网、清单坏：放行并提示
	_served = {}
	_check("断网：放行", await _gate(host, hint) == null and XForceUpdate.result["state"] == C.BAD)
	_check("断网：标题角落提示未能检查更新", hint.get_node_or_null("UpdateOfflineHint") != null)
	hint.get_node("UpdateOfflineHint").free()
	_serve_manifest("{\"schema\":1,\"latest\":".to_utf8_buffer())
	_check("清单坏了（签名对）：放行并提示", await _gate(host, hint) == null and hint.get_node_or_null("UpdateOfflineHint") != null)
	hint.get_node("UpdateOfflineHint").free()
	var good := JSON.stringify(_manifest(cur + 5, base, cur + 5, {"min_playable": cur + 5})).to_utf8_buffer()
	_served = {"https://a.invalid/godot/channel.json": good, "https://a.invalid/godot/channel.sig": _sign("别的".to_utf8_buffer())}
	_check("验签不过：放行", await _gate(host, hint) == null)
	hint.get_node("UpdateOfflineHint").free()

	# ── 低于最低可玩版本、能装补丁：强制更新框
	_serve_manifest(_manifest(cur + 5, base, cur + 5, {"min_playable": cur + 3, "download_url": "https://example.invalid/download"}))
	var page := await _gate(host, hint)
	_check("低于最低可玩版本：盖强制更新框", page != null and page.forced and page.state == C.PATCH)
	await _frames(3)
	var title: Label = page.find_child("Title", true, false)
	var body: Label = page.find_child("Body", true, false)
	var primary: Button = page.find_child("Primary", true, false)
	var close_b: Button = page.find_child("Close", true, false)
	var link: Button = page.find_child("Link", true, false)
	_check("强制框文字：需要更新、版本号、大小", title.text == "需要更新" and body.text.contains("请更新到 0.%d" % (cur + 5)) and body.text.contains("更新大小") and body.text.contains("· 修了一处"))
	_check("强制框按钮：更新＋退出游戏，没有关闭、没有手动下载", primary.visible and primary.text == "更新" and close_b.text == "退出游戏" and not link.visible)
	_check("强制框盖住整个画面", page.get_parent() is CanvasLayer and (page.find_child("Dim", true, false) as ColorRect).color.a > 0.9)
	_send("ui_cancel")
	await _frames(3)
	_check("取消键关不掉", is_instance_valid(page) and not page.is_queued_for_deletion())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(2, 2)
	click.global_position = Vector2(2, 2)
	page._gui_input(click)
	await _frames(2)
	_check("点暗处关不掉", is_instance_valid(page) and not page.is_queued_for_deletion())
	_check("从子页回到标题不重复盖", XForceUpdate.on_title(host, hint) == page and host.get_children().filter(func(c): return c is CanvasLayer).size() == 1)

	# 下载失败 → 再试一次＋手动下载；重试成功 → 已准备好、重启
	XUpdatePage.link_opener = func(u): _opened.append(u)
	_server.listen(PORT, "127.0.0.1")
	var res: Dictionary = page.get_meta("result")
	res["patch"]["urls"] = [_url("/missing.pck")]
	primary.pressed.emit()
	for i in range(300):
		if page.state == XUpdatePage.FAILED:
			break
		await get_tree().process_frame
	_check("下载失败：卡在更新框、显示再试一次", page.state == XUpdatePage.FAILED and title.text == "更新没完成" and primary.text == "再试一次" and is_instance_valid(page))
	_check("下载失败：显示手动下载链接和按钮", body.text.contains("https://example.invalid/download") and link.visible)
	link.pressed.emit()
	_check("点手动下载打开下载页", _opened == ["https://example.invalid/download"])
	_files["/p.pck"] = _pck
	res["patch"]["urls"] = [_url("/p.pck")]
	primary.pressed.emit()
	for i in range(300):
		if page.state in [XUpdatePage.READY, XUpdatePage.FAILED] and not page.installer.busy:
			break
		await get_tree().process_frame
	_check("重试成功：已准备好、提示重启", page.state == XUpdatePage.READY and primary.visible and (primary.text == "立即重启" or primary.text == "退出游戏"))
	_check("重试成功：补丁已登记，下次启动载入", XUpdateInstall.pending_code() == cur + 5 and FileAccess.file_exists(XUpdateInstall.dir.path_join(XUpdateInstall.file_name(base, cur + 5))))
	_close_all(host)
	page = await _gate(host, hint)
	await _frames(3)
	_check("已下好只差重启：再进来直接是已准备好", page != null and page.state == XUpdatePage.READY)
	_close_all(host)
	XUpdateInstall._remove_dir(XUpdateInstall.dir)

	# ── 底包太旧（只能整包）：只给手动下载
	_serve_manifest(_manifest(cur + 5, base + 999, cur + 5, {"min_playable": cur + 5, "download_url": "https://example.invalid/download"}))
	page = await _gate(host, hint)
	await _frames(3)
	primary = page.find_child("Primary", true, false)
	body = page.find_child("Body", true, false)
	_check("只能整包：主按钮是打开下载页、文字带链接", page.state == C.FULL and primary.visible and primary.text == "打开下载页" and body.text.contains("游戏内更新不了") and body.text.contains("https://example.invalid/download"))
	_opened.clear()
	primary.pressed.emit()
	_check("只能整包：点了打开下载页", _opened == ["https://example.invalid/download"])
	_close_all(host)
	_serve_manifest(_manifest(cur + 5, base + 999, cur + 5, {"min_playable": cur + 5}))
	page = await _gate(host, hint)
	await _frames(3)
	body = page.find_child("Body", true, false)
	_check("只能整包且清单没给下载页：指 QQ 群、没有主按钮", page.forced and body.text.contains(XUpdatePage.GROUP_HINT) and not (page.find_child("Primary", true, false) as Button).visible)
	_close_all(host)

	# ── 出标题时还没查完：先盖「正在检查」，查完再定
	_delay = 20
	_serve_manifest(_manifest(cur + 5, base, cur + 5, {"min_playable": cur + 5}))
	XForceUpdate.reset()
	client.last = {}
	XForceUpdate.begin(get_tree())
	page = XForceUpdate.on_title(host, hint)
	_check("还没查完：先盖正在检查、关不掉", page != null and page.forced and page.state == "checking")
	await _frames(70)
	_check("查完要强制：同一个框换成更新", is_instance_valid(page) and page.state == C.PATCH)
	_close_all(host)
	_serve_manifest(_manifest(cur + 5, base, cur + 5))
	XForceUpdate.reset()
	client.last = {}
	XForceUpdate.begin(get_tree())
	page = XForceUpdate.on_title(host, hint)
	await _frames(70)
	_check("查完不用强制：正在检查的框自己关掉", not is_instance_valid(page) or page.is_queued_for_deletion())
	await _frames(2)
	_close_all(host)
	# 等太久放行，之后结果回来要强制再盖上
	_delay = 90
	XForceUpdate.WAIT_SEC = 0.2
	_serve_manifest(_manifest(cur + 5, base, cur + 5, {"min_playable": cur + 5}))
	XForceUpdate.reset()
	client.last = {}
	XForceUpdate.begin(get_tree())
	page = XForceUpdate.on_title(host, hint)
	await get_tree().create_timer(0.5).timeout
	_check("等太久：放行（框关掉）", not XForceUpdate._done and (not is_instance_valid(page) or page.is_queued_for_deletion()))
	for i in range(200):
		if XForceUpdate._done:
			break
		await get_tree().process_frame
	await _frames(3)
	var late := host.get_node_or_null("UpdateLayer/UpdatePage") as XUpdatePage
	_check("结果晚到且要强制：再盖上来", late != null and late.forced and late.state == C.PATCH)
	_close_all(host)
	XForceUpdate.WAIT_SEC = saved["wait"]
	_delay = 1

	# ── 真标题：发行模式进西游标题，低于最低可玩版本就盖上强制更新框
	var save_override := XSave.dir_override
	XSave.dir_override = DIR + "/entry_saves"
	_serve_manifest(_manifest(cur + 5, base, cur + 5, {"min_playable": cur + 5}))
	XForceUpdate.reset()
	client.last = {}
	get_tree().change_scene_to_file(TITLE)
	for i in range(120):
		await get_tree().process_frame
		if get_tree().current_scene and get_tree().current_scene.get_node_or_null("UpdateLayer/UpdatePage") != null and XForceUpdate._done:
			break
	await _frames(3)
	var scene := get_tree().current_scene
	var tp := scene.get_node_or_null("UpdateLayer/UpdatePage") as XUpdatePage if scene else null
	_check("西游标题：启动就查、盖上强制更新框", XForceUpdate._started and tp != null and tp.forced and tp.state == C.PATCH)
	# 回退开关：不查、不拦
	XForceUpdate.ENABLED = false
	XForceUpdate.reset()
	get_tree().change_scene_to_file(TITLE)
	await _frames(8)
	scene = get_tree().current_scene
	_check("开关关了：西游标题不拦", scene != null and scene.get_node_or_null("UpdateLayer/UpdatePage") == null and not XForceUpdate._started)
	XForceUpdate.ENABLED = true
	XSave.dir_override = save_override

	# 收尾
	_server.stop()
	ReleaseEntry.simulate_release = false
	XForceUpdate.allow_headless = false
	XForceUpdate.reset()
	XUpdatePage.link_opener = Callable()
	XUpdateInstall.allow_http_for_tests = false
	XUpdateInstall.dir = saved["dir"]
	XUpdateInstall.save_dir = saved["save_dir"]
	client.fetcher = Callable()
	client.last = {}
	XUpdateClient.channel_urls = saved["urls"]
	XUpdateClient.public_key = saved["key"]
	XUpdateClient.stamp_path = saved["stamp"]
	host.queue_free()
	_cleanup()
	var passed := results.filter(func(x): return x["passed"]).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
