extends Node
## 更新后弹一次「本次更新内容」（XWhatsNew、XWhatsNewPage，Kyo 2026-11-15，update-whatsnew）。
## 记录：装补丁记、查清单补记、号不对／说明空不记不弹、已读不再弹；旧记录（check.json）恢复说明；
## 界面：两套样式、标题弹一次、强制更新框开着不弹、设置页「本次更新内容」；游戏内真装一次补丁（本进程小 HTTP 服务器）；
## 真标题（开发模式、发行模拟）弹一次、再进不弹；回退开关。
## 只写 user://_test_whats_new/，跑完删掉；不联网、不碰真存档和真更新目录。

const DIR := "user://_test_whats_new"
const PORT := 18963
const TITLE := "res://modes/xiyou/entry.tscn"
var results: Array = []
var _server := TCPServer.new()
var _files := {}
var _served := {}
var _key: CryptoKey

func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)

func _check(name: String, ok: bool, info: Variant = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL " + name + ("" if info == null else " " + str(info)))

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
	for i in range(3):
		await get_tree().process_frame
	c.disconnect_from_host()

func _fake_fetch(url: String) -> PackedByteArray:
	await get_tree().process_frame
	return _served.get(url, PackedByteArray())

func _sign(raw: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(raw)
	return Crypto.new().sign(HashingContext.HASH_SHA256, ctx.finish(), _key)

func _serve_manifest(m: Dictionary) -> void:
	var raw := JSON.stringify(m).to_utf8_buffer()
	_served = {"https://a.invalid/godot/channel.json": raw, "https://a.invalid/godot/channel.sig": _sign(raw)}

func _sha(b: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(b)
	return ctx.finish().hex_encode()

func _cleanup(path := DIR) -> void:
	var da := DirAccess.open(path)
	if da:
		for n in da.get_files():
			da.remove(n)
		for sub in da.get_directories():
			_cleanup(path.path_join(sub))
		DirAccess.remove_absolute(path)

func _close_layers(host: Node) -> void:
	for c in host.get_children():
		if c is CanvasLayer:
			host.remove_child(c)
			c.free()

func _record() -> Dictionary:
	var j := JSON.new()
	if not FileAccess.file_exists(XWhatsNew.path) or j.parse(FileAccess.get_file_as_string(XWhatsNew.path)) != OK:
		return {}
	return j.data

func _wait_title() -> Node:
	for i in range(120):
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and s.has_method("is_title_page") and s.is_title_page():
			break
	await _frames(3)
	return get_tree().current_scene

func _run() -> void:
	XUpdateCheck.release_name = ""
	XUpdateCheck.release_base = 1
	_cleanup()
	DirAccess.make_dir_recursive_absolute(DIR)
	_key = Crypto.new().generate_rsa(2048)
	var W := XWhatsNew
	var saved := {"path": W.path, "urls": XUpdateClient.channel_urls, "key": XUpdateClient.public_key, "stamp": XUpdateClient.stamp_path,
		"dir": XUpdateInstall.dir, "save_dir": XUpdateInstall.save_dir, "save_override": XSave.dir_override}
	W.path = DIR.path_join("updates/whatsnew.json")
	# 「检查更新」框一打开就查：先换成假源（不联网），清单先放一份「已是最新」但不是这一版的
	XUpdateClient.channel_urls = PackedStringArray(["https://a.invalid/godot/channel.json"])
	XUpdateClient.public_key = _key.save_to_string(true)
	XUpdateClient.stamp_path = DIR.path_join("check.json")
	var client := XUpdateClient.instance(get_tree())
	client.fetcher = _fake_fetch
	var cur := XUpdateClient.current_code()
	_check("现在运行的号可读", cur > 0, cur)

	# ── 记录：装补丁
	var res := {"state": XUpdateCheck.PATCH, "version": "0.%d" % cur, "code": cur, "date": "2026-11-20", "notes": PackedStringArray(["修了一处", " ", "加了一样"])}
	_check("装的就是最新版：记下", W.note_install(res, {"code": cur}))
	var rec := _record()
	_check("记录：号、版本、日期、说明（去掉空行）、未读", int(rec.get("code", 0)) == cur and rec.get("version") == "0.%d" % cur
		and rec.get("date") == "2026-11-20" and rec.get("notes") == ["修了一处", "加了一样"] and rec.get("seen") == false, rec)
	_check("号对得上、没看过：要弹", not W.pending(cur).is_empty())
	_check("号对不上（还没重启、或被退回）：不弹", W.pending(cur - 1).is_empty() and W.pending(cur + 1).is_empty())
	W.mark_seen(cur)
	_check("记已读后不弹", W.pending(cur).is_empty() and _record().get("seen") == true)
	_check("已读的设置页照样能看", not W.current(cur).is_empty() and W.current(cur)["seen"])
	_check("装的不是清单最新那一版（说明对不上）：不记", not W.note_install(res, {"code": cur - 1}) and int(_record().get("code", 0)) == cur)
	var no_notes := res.duplicate()
	no_notes["notes"] = PackedStringArray()
	no_notes["code"] = cur + 3
	_check("清单没有说明：不记、不弹", not W.note_install(no_notes, {"code": cur + 3}) and W.pending(cur + 3).is_empty())
	var bad_notes := no_notes.duplicate()
	bad_notes["notes"] = [1, null, {"a": 1}]
	_check("说明不是字符串：不记", not W.note_install(bad_notes, {"code": cur + 3}))

	# ── 记录：查清单补记（整包首次启动、旧客户端装的补丁）
	DirAccess.remove_absolute(W.path)
	var latest := {"state": XUpdateCheck.LATEST, "version": "0.%d" % cur, "code": cur, "date": "2026-11-21", "notes": PackedStringArray(["整包说明"])}
	_check("已是最新且就是现在这版：补记", W.note_check(latest, cur) and not W.pending(cur).is_empty())
	W.mark_seen(cur)
	_check("同一个号已记过：不覆盖（已读不变回未读）", not W.note_check(latest, cur) and W.pending(cur).is_empty())
	var older := latest.duplicate()
	older["code"] = cur - 1
	_check("清单最新号比现在的旧（开发版、测试）：不补记", not W.note_check(older, cur))
	var newer := latest.duplicate()
	newer["state"] = XUpdateCheck.PATCH
	newer["code"] = cur + 1
	_check("有更新的版本：不补记", not W.note_check(newer, cur))
	DirAccess.remove_absolute(W.path)
	W.FROM_CHECK = false
	_check("FROM_CHECK 关：查清单不补记", not W.note_check(latest, cur) and not FileAccess.file_exists(W.path))
	W.FROM_CHECK = true
	DirAccess.make_dir_recursive_absolute(W.path.get_base_dir())
	var f := FileAccess.open(W.path, FileAccess.WRITE)
	f.store_string("{\"code\":")
	f.close()
	_check("记录坏了：不弹、查清单照常补记", W.pending(cur).is_empty() and W.note_check(latest, cur) and not W.pending(cur).is_empty())

	# ── 合法 JSON 但缺字段／类型不对（co 甲档核查 P2）：一律当坏数据，不弹、不报错，查清单同号照样重记
	var host0 := Control.new()
	get_tree().root.add_child(host0)
	var bads := {
		"缺 version／date／seen": {"code": cur, "notes": ["hello"]},
		"缺 seen": {"code": cur, "version": "v", "date": "", "notes": ["hello"]},
		"code 是数组": {"code": [cur], "version": "v", "date": "", "notes": ["hello"], "seen": false},
		"code 是字符串": {"code": str(cur), "version": "v", "date": "", "notes": ["hello"], "seen": false},
		"code 是小数": {"code": cur + 0.5, "version": "v", "date": "", "notes": ["hello"], "seen": false},
		"code 是负数": {"code": -cur, "version": "v", "date": "", "notes": ["hello"], "seen": false},
		"seen 是字符串": {"code": cur, "version": "v", "date": "", "notes": ["hello"], "seen": "false"},
		"seen 是数字": {"code": cur, "version": "v", "date": "", "notes": ["hello"], "seen": 0},
		"notes 是字符串": {"code": cur, "version": "v", "date": "", "notes": "hello", "seen": false},
		"version 是数字": {"code": cur, "version": 1, "date": "", "notes": ["hello"], "seen": false},
		"date 是 null": {"code": cur, "version": "v", "date": null, "notes": ["hello"], "seen": false},
	}
	for why in bads:
		var bf := FileAccess.open(W.path, FileAccess.WRITE)
		bf.store_string(JSON.stringify(bads[why]))
		bf.close()
		W.mark_seen(cur)  # 坏记录：不改、不报错
		var shown := XWhatsNewPage.show_pending(host0, false)
		_check("坏记录（%s）：不弹、current 空、mark_seen 不改文件" % why, W.pending(cur).is_empty() and W.current(cur).is_empty()
			and shown == null and host0.get_node_or_null("WhatsNewLayer") == null
			and FileAccess.get_file_as_string(W.path) == JSON.stringify(bads[why]))
		_check("坏记录（%s）：查清单同号照样重记" % why, W.note_check(latest, cur) and not W.pending(cur).is_empty())
	_check("正常记录：JSON 读回的浮点 code 当整数认", W.validate(JSON.parse_string(JSON.stringify({"code": cur, "version": "v", "date": "", "notes": [], "seen": false}))).get("code") == cur)
	host0.free()

	# ── 回退开关：不记、不弹、设置页不列
	DirAccess.remove_absolute(W.path)
	W.ENABLED = false
	_check("开关关：装补丁不记", not W.note_install(res, {"code": cur}) and not FileAccess.file_exists(W.path))
	_check("开关关：查清单不补记", not W.note_check(latest, cur) and not FileAccess.file_exists(W.path))
	W.ENABLED = true
	W.note_install(res, {"code": cur})
	W.ENABLED = false
	_check("开关关：有记录也不弹", W.pending(cur).is_empty() and W.current(cur).is_empty())
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(host)
	_check("开关关：标题不弹", XWhatsNewPage.show_pending(host, false) == null and host.get_node_or_null("WhatsNewLayer") == null)
	var opts := XOptionsScene.new()
	opts._build_list()
	_check("开关关：设置页不列「本次更新内容」", not opts.symbols().has("codexWhatsNew"))
	W.ENABLED = true
	opts._build_list()
	_check("有这一版的说明：设置页列「本次更新内容」、状态「查看」", opts.symbols().has("codexWhatsNew")
		and opts.status_text(opts.symbols().find("codexWhatsNew")) == "查看")
	opts.free()

	# ── 文字（小A审）
	var t := XWhatsNewPage.texts(W.current(cur))
	_check("文字：标题、版本日期、说明逐条、按钮", t["title"] == "本次更新内容" and t["ok"] == "知道了"
		and t["body"] == "已更新到 0.%d（2026-11-20）\n\n· 修了一处\n· 加了一样" % cur, t)
	t = XWhatsNewPage.texts({"version": "0.01.11", "date": "", "notes": PackedStringArray(["甲"])})
	_check("文字：没有日期不带括号", t["body"] == "已更新到 0.01.11\n\n· 甲", t)

	# ── 标题弹一次（两套样式）
	var up := XUpdatePage.open(host)  # 检查更新框开着：不弹、也不记已读
	await _frames(2)
	_check("检查更新／强制更新框开着：不弹、不记已读", XWhatsNewPage.show_pending(host, false) == null and not W.pending(cur).is_empty())
	for i in range(60):
		await get_tree().process_frame
		if not client.checking:
			break
	_close_layers(host)
	await _frames(1)
	var page := XWhatsNewPage.show_pending(host, false)
	await _frames(3)
	_check("旧样式：弹出、标题和说明对、记已读", page != null and not page.skin and (page.find_child("Title", true, false) as Label).text == "本次更新内容"
		and (page.find_child("Body", true, false) as Label).text.contains("· 加了一样") and W.pending(cur).is_empty())
	_check("弹窗在独立层、盖在画面上", page.get_parent() is CanvasLayer and (page.get_parent() as CanvasLayer).layer == XWhatsNewPage.LAYER)
	_check("焦点在「知道了」", get_viewport().gui_get_focus_owner() == page.find_child("Ok", true, false))
	_check("已读：再进标题不弹", XWhatsNewPage.show_pending(host, false) == null)
	_send("ui_accept")
	await _frames(3)
	_check("确定键关掉", not is_instance_valid(page) or page.is_queued_for_deletion())
	_close_layers(host)
	page = XWhatsNewPage.open(host, W.current(cur), true)
	await _frames(3)
	var ok_b := page.find_child("Ok", true, false) as Button
	_check("新皮肤：思源字、红乙选中条、面板贴图", page.skin and (page.find_child("Panel", true, false).get_theme_stylebox("panel") is XSkinArt.SmokeStyle if XSkinArt.panel_on() else page.find_child("Panel", true, false).get_theme_stylebox("panel") is StyleBoxTexture)  # O-515 第一期美术开着时面板是烟色九宫格
		and ok_b.get_theme_stylebox("focus") is XSkinSelectStyle)
	_check("已开着再开返回同一页", XWhatsNewPage.open(host, W.current(cur), true) == page)
	_send("ui_cancel")
	await _frames(3)
	_check("取消键关掉", not is_instance_valid(page) or page.is_queued_for_deletion())
	_close_layers(host)
	var long_rec := W.current(cur)
	var many := PackedStringArray()
	for i in range(40):
		many.append("第 %d 条比较长的更新说明，用来撑满框看会不会滚动" % i)
	long_rec["notes"] = many
	page = XWhatsNewPage.open(host, long_rec, false)
	await _frames(3)
	var sc := page.find_child("Scroll", true, false) as ScrollContainer
	_check("说明很长：框里滚动、显示滚动提示", (page.find_child("More", true, false) as Label).visible and sc.custom_minimum_size.y < 700)
	_send("ui_down")
	await _frames(2)
	_check("下键滚动、不关", sc.scroll_vertical > 0 and is_instance_valid(page) and not page.is_queued_for_deletion())
	_close_layers(host)

	# ── 旧记录（check.json）恢复说明
	client.last = {"state": XUpdateCheck.PATCH, "version": "0.%d" % (cur + 5), "code": cur + 5, "date": "2026-11-22",
		"notes": PackedStringArray(["旧记录里的说明"]), "patch": {}, "revoked": false}
	client._save_stamp()
	client.last = {}
	client._load_stamp()
	_check("旧记录恢复：带说明、标成旧的", client.last.get("stale") == true and Array(client.last.get("notes")) == ["旧记录里的说明"], client.last)
	_check("旧记录恢复：更新框正文有「更新内容」", XUpdatePage.texts(client.last, false)["body"].contains("更新内容\n· 旧记录里的说明"))
	f = FileAccess.open(XUpdateClient.stamp_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"time": 1, "state": "patch", "version": "0.%d" % (cur + 5), "code": cur + 5, "date": ""}))
	f.close()
	client.last = {}
	client._load_stamp()
	var tb: String = XUpdatePage.texts(client.last, false)["body"]
	_check("更早的旧记录（没有 notes）：不出「更新内容」空标题", Array(client.last.get("notes")).is_empty() and not tb.contains("更新内容"), tb)
	client.last = {}

	# ── 查清单（真 check 流程）补记
	DirAccess.remove_absolute(W.path)
	_serve_manifest({"schema": 1, "latest": {"version": "0.%d" % cur, "code": cur, "date": "2026-11-23", "notes": ["清单说明"]}, "bases": {}})
	var r: Dictionary = await client.check()
	_check("check 已是最新且是这一版：补记", r["state"] == XUpdateCheck.LATEST and W.pending(cur).get("notes") == PackedStringArray(["清单说明"]), W.pending(cur))
	_check("check 记下的旧记录带说明", JSON.parse_string(FileAccess.get_file_as_string(XUpdateClient.stamp_path)).get("notes") == ["清单说明"])
	DirAccess.remove_absolute(W.path)
	_serve_manifest({"schema": 1, "latest": {"version": "0.%d" % cur, "code": cur, "date": "2026-11-23"}, "bases": {}})
	await client.check()
	_check("已推的老格式清单没有 notes：不记不弹", not FileAccess.file_exists(W.path))

	# ── 游戏内真装一次补丁（XUpdatePage._install → 登记成功 → 记下说明）
	XUpdateInstall.dir = DIR.path_join("updates")
	XUpdateInstall.save_dir = DIR.path_join("modes")
	XUpdateInstall.allow_http_for_tests = true
	var base := XUpdateClient.base_code()
	var pck := "假补丁内容".repeat(300).to_utf8_buffer()
	_files["/p.pck"] = pck
	_server.listen(PORT, "127.0.0.1")
	var install_res := {"state": XUpdateCheck.PATCH, "version": "0.%d" % (cur + 2), "code": cur + 2, "date": "2026-11-24",
		"notes": PackedStringArray(["装补丁时的说明"]), "revoked": false,
		"patch": {"code": cur + 2, "size": pck.size(), "sha256": _sha(pck), "urls": ["http://127.0.0.1:%d/p.pck" % PORT]}}
	var upage := XUpdatePage.open(host)
	for i in range(60):  # 等它打开时那一轮检查结束，免得结果盖掉下面的状态
		await get_tree().process_frame
		if upage.state != "checking" and not client.checking:
			break
	upage.show_result(install_res)
	upage._install(install_res)
	for i in range(300):
		if upage.state in [XUpdatePage.READY, XUpdatePage.FAILED]:
			break
		await get_tree().process_frame
	_check("游戏内装补丁：登记好", upage.state == XUpdatePage.READY, upage.state)
	_check("游戏内装补丁：记下说明（号＝补丁号、未读）", int(_record().get("code", 0)) == cur + 2 and _record().get("notes") == ["装补丁时的说明"] and _record().get("seen") == false, _record())
	_check("还没重启（现在运行的号不是补丁号）：不弹", W.pending(cur).is_empty())
	_close_layers(host)
	_server.stop()

	# ── 真标题：开发模式（新标题、新皮肤）与发行模拟，弹一次、再进不弹
	XSave.dir_override = DIR + "/entry_saves"
	for how in ["dev", "release"]:
		ReleaseEntry.simulate_release = how == "release"
		DirAccess.remove_absolute(W.path)
		W.remember(cur, "0.%d" % cur, "2026-11-25", ["标题弹窗说明 " + how])
		get_tree().change_scene_to_file(TITLE)
		var scene := await _wait_title()
		var wp := scene.get_node_or_null("WhatsNewLayer/WhatsNewPage") as XWhatsNewPage if scene else null
		_check("%s 标题：弹「本次更新内容」" % how, wp != null and (wp.find_child("Body", true, false) as Label).text.contains("标题弹窗说明 " + how))
		_check("%s 标题：样式跟标题（新标题＝新皮肤）" % how, wp != null and wp.skin == (scene._tq_title != null), [wp.skin if wp else null, scene._tq_title != null])
		_check("%s 标题：已记已读" % how, W.pending(cur).is_empty())
		_send("ui_accept")
		await _frames(3)
		_check("%s 标题：确定关掉、留在标题" % how, scene.get_node_or_null("WhatsNewLayer") == null and scene.is_title_page())
		get_tree().change_scene_to_file(TITLE)
		scene = await _wait_title()
		_check("%s 标题：再启动不弹" % how, scene.get_node_or_null("WhatsNewLayer") == null)
		DirAccess.remove_absolute(W.path)
		W.remember(cur + 9, "0.%d" % (cur + 9), "", ["号不对"])
		get_tree().change_scene_to_file(TITLE)
		scene = await _wait_title()
		_check("%s 标题：号不对不弹" % how, scene.get_node_or_null("WhatsNewLayer") == null)
	ReleaseEntry.simulate_release = false
	DirAccess.remove_absolute(W.path)
	W.remember(cur, "0.%d" % cur, "", ["开关测试"])
	W.ENABLED = false
	get_tree().change_scene_to_file(TITLE)
	var sc2 := await _wait_title()
	_check("开关关：真标题不弹", sc2.get_node_or_null("WhatsNewLayer") == null)
	W.ENABLED = true

	# 收尾
	XSave.dir_override = saved["save_override"]
	XUpdateInstall.allow_http_for_tests = false
	XUpdateInstall.dir = saved["dir"]
	XUpdateInstall.save_dir = saved["save_dir"]
	client.fetcher = Callable()
	client.last = {}
	XUpdateClient.channel_urls = saved["urls"]
	XUpdateClient.public_key = saved["key"]
	XUpdateClient.stamp_path = saved["stamp"]
	W.path = saved["path"]
	host.queue_free()
	_cleanup()
	var passed := results.filter(func(x): return x["passed"]).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
