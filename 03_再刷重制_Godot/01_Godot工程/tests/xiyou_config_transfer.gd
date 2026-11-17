extends Node
## T154 设置「导入／导出配置」（XConfigTransfer、XConfigTransferScene）：导出格式带版本、导入校验与跳过计数、
## 本机专属与进度类不导出不导入、导入前备份与撤回、确认流程、设置页一行、剪贴板／文件（假剪贴板、测试目录，不碰本机真实设置）。
var results := []
const DIR := "user://test_xiyou_config_transfer"
var _clip := [""]
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


## 带窗口、给了 --out= 时截图（专项取证用；无头时跳过）
func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)


func reload() -> void:
	XConfig._loaded_path = "<unloaded>"
	XConfig.ensure_loaded()


func doc_of(text: String) -> Dictionary:
	var j = JSON.parse_string(Marshalls.base64_to_utf8(text.trim_prefix(XConfigTransfer.PREFIX)))
	return j if j is Dictionary else {}


func encode(d: Dictionary) -> String:
	return XConfigTransfer.PREFIX + Marshalls.utf8_to_base64(JSON.stringify(d))


func _cleanup() -> void:
	for d in [DIR + "/out", DIR]:
		var da := DirAccess.open(d)
		if da:
			for f in da.get_files():
				da.remove(f)
	DirAccess.remove_absolute(DIR + "/out")
	DirAccess.remove_absolute(DIR)


func _run() -> void:
	_cleanup()
	XSave.dir_override = DIR
	XConfig.path_override = DIR.path_join("options.json")
	DirAccess.make_dir_recursive_absolute(DIR + "/out")
	reload()
	XFeedback.export_dir_override = DIR + "/out"
	XConfigTransfer.clipboard_get = func(): return _clip[0]
	XConfigTransfer.clipboard_set = func(t): _clip[0] = t
	var T := XConfigTransfer

	# 每个配置键都分了类（设置／本机专属／进度），新加设置忘了归类就挂
	var unclassified := XConfig.DEFAULTS.keys().filter(func(k): return not (T.SETTINGS.has(k) or T.DEVICE.has(k) or T.PROGRESS.has(k)))
	check("每个配置键都归了类", unclassified.is_empty(), unclassified)
	var overlap := T.SETTINGS.filter(func(k): return T.DEVICE.has(k) or T.PROGRESS.has(k))
	check("三类不重叠", overlap.is_empty(), overlap)

	# 导出：格式、版本、内容
	XConfig.set_volume("bgmVolume", 80)
	XConfig.set_flag("alwaysDash", false)
	XConfig.set_notice("race", false)
	XConfig.set_quality({"integer": true, "fps": 30, "window": "1280x720", "low": true, "crisp": false, "motion": false})
	XConfig._values["SAchievementS"] = {"a1": true}
	XConfig._values["codexWhisperSeen"] = ["k1"]
	XConfig.save_achievements()
	var text := T.export_text()
	var d := doc_of(text)
	check("导出是一行带前缀的文本", text.begins_with(T.PREFIX) and not text.contains("\n"))
	check("导出带配置格式版本和游戏版本", int(d.get("format", 0)) == T.FORMAT and str(d.get("game", "")) == T.game_version() and T.game_version() != "" and int(d.get("code", 0)) == XUpdateClient.current_code(), d)
	var st: Dictionary = d.get("settings", {})
	check("导出含设置项", int(st.get("bgmVolume", 0)) == 80 and st.get("alwaysDash") == false and st.get("codexNotices", {}).get("race") == false)
	check("不导出进度类（成就、看过的过场等）", not st.has("SAchievementS") and not st.has("codexWhisperSeen") and not st.has("ChangeClothesLite") and not st.has("DesignationN"))
	check("不导出本机专属（画面平滑）", not st.has("codexScreenSmooth"))
	check("画质只导出柔边、平滑移动两项", st.get("codexQuality", {}).keys().size() == 2 and st["codexQuality"].get("crisp") == false and not st["codexQuality"].has("window") and not st["codexQuality"].has("fps"))

	# 预览：坏文本
	check("空文本给提示", not T.preview("")["ok"] and T.preview("  ")["error"] != "")
	check("不是本游戏的文本给提示", T.preview("你好")["error"] == "这不是本游戏导出的配置。")
	check("前缀对、内容坏给提示", not T.preview(T.PREFIX + "@@@")["ok"] and T.preview(T.PREFIX + "@@@")["error"].contains("损坏"))
	check("截断的文本给提示", not T.preview(text.substr(0, text.length() - 7))["ok"])
	check("JSON 不是配置给提示", not T.preview("{\"a\": 1}")["ok"])
	# 预览：聊天软件插了换行和空格、前面多了别的字照样认
	var mangled := "朋友发来的：" + text.substr(0, 20) + "\n " + text.substr(20, 30) + "\r\n" + text.substr(50)
	check("插了换行空格、前面有别的字也能认", T.preview(mangled)["ok"])
	check("直接粘 JSON 也认", T.preview(JSON.stringify(d))["ok"])

	# 别的版本的配置：认得的导入，不认得的、类型不对的跳过并计数，本机专属与进度类也跳过
	var foreign := {"format": 9, "game": "9.99", "code": 99999, "settings": {
		"seVolume": 20.0, "battleAniSpeed": 2, "MapXy": true, "codexNotices": {"chest": false, "未来的类别": false},
		"codexQuality": {"crisp": true, "motion": true, "window": "fullscreen", "fps": 144, "low": true},
		"未来新设置": 1, "alwaysDash": "是", "SAchievementS": {"x": true}, "codexScreenSmooth": true, "codexWhisperSeen": ["偷看"]}}
	var pv := T.preview(encode(foreign))
	check("更高格式版本照样读", pv["ok"] and pv["format"] == 9 and pv["game"] == "9.99")
	check("认得的项都收", pv["values"].has("seVolume") and pv["values"].has("battleAniSpeed") and pv["values"].has("MapXy") and pv["values"].has("codexNotices") and pv["values"].has("codexQuality"), pv["values"])
	check("跳过不认识、类型不对、本机专属、进度类，并计数", pv["skipped"] == 5 and Array(pv["skipped_keys"]).has("未来新设置") and Array(pv["skipped_keys"]).has("alwaysDash"), pv["skipped_keys"])
	check("画质只收柔边、平滑移动", pv["values"]["codexQuality"].keys().size() == 2)
	check("确认提示写了导入几项、跳过几项、来自哪个版本", T.confirm_text(pv).contains("将导入 5 项") and T.confirm_text(pv).contains("跳过 5 项") and T.confirm_text(pv).contains("9.99"), T.confirm_text(pv))
	var only_unknown := T.preview(encode({"format": 1, "settings": {"未来新设置": 1}}))
	check("一项都不认识给提示", not only_unknown["ok"] and only_unknown["error"].contains("没有本版本能用"))

	# 导入：备份、合并、写盘、进度不动、本机专属不动
	check("没导入过没有备份", not T.has_backup())
	var r := T.apply(encode(foreign))
	check("导入成功", r["ok"] and T.result_text(r) == "已导入 5 项设置，跳过 5 项本版本不认识的设置。", T.result_text(r))
	check("导入前自动备份", T.has_backup() and FileAccess.file_exists(DIR.path_join(T.BACKUP_NAME)))
	reload()
	check("导入的值写进设置文件", XConfig.volume("seVolume") == 20 and XConfig.battle_speed() == 2 and XConfig.flag("MapXy"))
	check("没给的项保持原样", XConfig.volume("bgmVolume") == 80 and not XConfig.flag("alwaysDash"))
	check("嵌套按子项合并（消息提醒 race 仍关、chest 关）", not XConfig.notice_on("race") and not XConfig.notice_on("chest") and XConfig.notice_on("zhenqi"))
	var q := XConfig.quality()
	check("画质：柔边、平滑移动导入，窗口、帧率、省电、整数缩放保持本机", q["crisp"] == true and q["motion"] == true and q["window"] == "1280x720" and int(q["fps"]) == 30 and q["low"] == true and q["integer"] == true, q)
	check("进度类不动", XConfig.achievements().get("a1") == true and XConfig._values["codexWhisperSeen"] == ["k1"] and not XConfig.achievements().has("x"))
	# 读档校正照旧：范围外的值回到合法范围
	T.apply(encode({"format": 1, "settings": {"bgmVolume": 999, "battleAniSpeed": 77}}))
	reload()
	check("超范围的值按读档规矩校正", XConfig.volume("bgmVolume") == 100 and XConfig.battle_speed() == 4)
	# 撤回：回到上一次导入前（只动设置，不动进度）
	XConfig._values["SAchievementS"]["a2"] = true
	XConfig.save_achievements()
	check("撤回成功", T.undo())
	reload()
	check("撤回换回导入前的设置", XConfig.volume("bgmVolume") == 80 and XConfig.battle_speed() == 2)
	check("撤回不动进度（导入后新拿的成就还在）", XConfig.achievements().get("a2") == true)
	check("撤回后备份删掉", not T.has_backup() and not T.undo())
	# 坏文本导入不动任何东西
	var before := FileAccess.get_file_as_string(XConfig.path())
	check("坏文本导入失败且不备份、不改设置", not T.apply("坏的")["ok"] and not T.has_backup() and FileAccess.get_file_as_string(XConfig.path()) == before)

	# 文件
	check("PC／Mac 能存文件", T.file_supported())
	var fp := T.export_file()
	check("导出到「下载」文件夹（测试目录）", fp.begins_with(DIR + "/out") and fp.ends_with(".txt") and T.preview(T.read_file(fp))["ok"])

	# 设置页：一行「导入／导出配置」
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var opt := XOptionsScene.new()
	add_child(opt)
	await frames()
	var oi := opt.symbols().find("codexConfigTransfer")
	check("设置页有导入／导出配置一行", oi >= 0 and opt._list[oi][0] == "导入／导出配置" and opt.status_text(oi) == "打开")
	check("排在原版各项之后", oi > opt.symbols().find("codexCostumes"))
	opt._select(oi)
	XSound.system_log.clear()
	opt.ok()
	check("确定打开子页", opt._page is XConfigTransferScene and XSound.system_log == [1], XSound.system_log)
	var p: XConfigTransferScene = opt._page
	await frames(3)
	var keys := XConfigTransferScene.rows().map(func(x): return x[0])
	check("子页五行（PC／Mac 带文件两行）", keys == ["copy", "save", "paste", "open", "undo"], keys)
	check("没备份时撤回一行是灰的", not p.enabled(4))
	await shot("导入导出配置_子页.png")
	# 导出到剪贴板
	_clip[0] = ""
	p.ok()
	check("导出配置复制到剪贴板", T.preview(_clip[0])["ok"] and p.message.contains("已复制"))
	# 导出到文件
	p.select(1)
	p.ok()
	check("导出到文件给路径", p.message.begins_with("已存到："))
	# 从剪贴板导入：先确认、再导入
	_clip[0] = encode({"format": 1, "game": "0.01", "settings": {"meVolume": 0}})
	p.select(2)
	XSound.system_log.clear()
	p.ok()
	await frames(2)
	await shot("导入导出配置_确认.png")
	check("第一次确定只预览", not p.pending.is_empty() and XConfig.volume("meVolume") != 0 and p.message.contains("再按一次确定"))
	p.select(3)
	check("换行就取消确认", p.pending.is_empty())
	p.select(2)
	p.ok()
	XSound.system_log.clear()
	p.cancel()
	check("取消键先取消确认、不关页", p.pending.is_empty() and opt._page == p and XSound.system_log == [2])
	p.ok()
	p.ok()
	check("第二次确定才导入", XConfig.volume("meVolume") == 0 and p.message.contains("已导入 1 项") and p.enabled(4))
	# 坏剪贴板
	_clip[0] = "随便什么"
	XSound.system_log.clear()
	p.ok()
	check("剪贴板不是配置：蜂鸣并提示", p.pending.is_empty() and XSound.system_log == [3] and p.message == "这不是本游戏导出的配置。")
	# 从文件导入（假选文件框）
	XConfigTransferScene.file_picker = func(cb): cb.call(fp)
	p.select(3)
	p.ok()
	check("选了文件先预览", not p.pending.is_empty() and p.pending["row"] == "open")
	p.ok()
	check("文件导入成功", p.pending.is_empty() and p.message.contains("已导入"))
	XConfigTransferScene.file_picker = func(cb): cb.call("")
	p.ok()
	check("选文件框取消什么都不做", p.pending.is_empty())
	XConfigTransferScene.file_picker = Callable()
	# 撤回
	p.select(4)
	p.ok()
	check("撤回一行可用", p.message == "已换回导入前的设置。" and not p.enabled(4))
	XSound.system_log.clear()
	p.ok()
	check("没备份时点撤回蜂鸣", XSound.system_log == [3])
	# 键盘：上键首按循环、取消返回设置页
	p.select(0)
	await press("ui_up")
	check("上键循环到最后一行", p.index == 4)
	await press("ui_cancel")
	await frames(2)
	check("取消返回设置页", opt._page == null and opt.win.visible)
	# 回退开关
	opt.queue_free()
	T.ENABLED = false
	var opt2 := XOptionsScene.new()
	add_child(opt2)
	await frames()
	check("开关关掉不列这一行", opt2.symbols().find("codexConfigTransfer") < 0)
	opt2.queue_free()
	T.ENABLED = true

	XConfigTransfer.clipboard_get = Callable()
	XConfigTransfer.clipboard_set = Callable()
	XFeedback.export_dir_override = ""
	_cleanup()
	XConfig.path_override = ""
	XSave.dir_override = ""
	XConfig._loaded_path = "<unloaded>"
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
