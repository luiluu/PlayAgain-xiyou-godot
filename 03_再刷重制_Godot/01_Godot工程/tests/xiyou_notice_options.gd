extends Node
## 设置「消息提醒」：正式 options_probe 的 notices 对照（子页行/说明/开关操作/状态文字/配置读写/提示分类），
## 提示过滤（菜单内照常显示）与设置页打开、键盘操作、返回；主菜单的光标/确定/蜂鸣/取消音效。
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


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


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func reload() -> void:
	XConfig._loaded_path = "<unloaded>"
	XConfig.ensure_loaded()


func set_off(off: Array) -> void:
	for n in XConfig.NOTICES:
		XConfig.set_notice(n[0], not off.has(n[0]))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_notice_options"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.make_dir_recursive_absolute(XSave.dir())
	DirAccess.remove_absolute(XConfig.path())
	reload()
	var ref = XDB.load_json("oracle/options.json")
	if not (ref is Dictionary and ref.has("notices")):
		check("oracle_present", false)
		return finish()
	var nt: Dictionary = ref.notices
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs and ref.sourceIdentity.releaseVersion == manifest.releaseVersion)

	# 默认全开（applyData({})）
	for k in nt.defaults.notices:
		check("default_" + k, XConfig.notice_on(k) == nt.defaults.notices[k])
	check("default_skillLevel", XConfig.notice_on("skillLevel") == nt.defaults.skillLevel)
	check("status_default", XConfig.notices_text() == nt.status[0].text)

	# 子页行、说明与布局
	var rows := XNoticeOptionsScene.rows()
	check("rows", rows.map(func(r): return [r[0], r[1], r[2]]) == nt.rows.map(func(r): return [r.key, r.name, r.hint]), rows)
	var hr := XNoticeOptionsScene.HEAD_RECT
	var lr := XNoticeOptionsScene.LIST_RECT
	var rect_nums := [hr.position.x, hr.position.y, hr.size.x, hr.size.y, lr.position.x, lr.position.y, lr.size.x, lr.size.y, rows.size(), 0]
	check("rects", rect_nums.map(func(v): return float(v)) == (nt.heading + nt.list).map(func(v): return float(v)), rect_nums)

	# 开关操作序列（toggle / 右开 / 左关），光标不动
	var page := XNoticeOptionsScene.new()
	add_child(page)
	await frames()
	var ops_ok := true
	for op in nt.ops:
		page.index = int(op.index)
		match op.op:
			"toggle": page.toggle()
			"cursorRight": page.toggle(true)
			"cursorLeft": page.toggle(false)
		if page.index != int(op.index2) or XConfig.notice_on(rows[page.index][0]) != op.on:
			ops_ok = false
			check("op_%d_%s" % [int(op.index), op.op], false, [page.index, XConfig.notice_on(rows[page.index][0])])
	check("ops_all", ops_ok)
	page.queue_free()

	# 设置页状态文字
	for row in nt.status:
		if row.has("off"):
			set_off(row.off)
			check("status_%d" % row.off.size(), XConfig.notices_text() == row.text, XConfig.notices_text())

	# 配置读写：只有存成 false 的类别关闭；技能升级通告非 false 即开
	set_off(["zhenqi", "skillLevel"])
	reload()
	check("persist", not XConfig.notice_on("zhenqi") and not XConfig.notice_on("skillLevel") and XConfig.notice_on("race"))
	var data = JSON.parse_string(FileAccess.get_file_as_string(XConfig.path()))
	check("file_fields", data is Dictionary and data.codexNotices is Dictionary and data.codexNotices.zhenqi == false and data.codexSkillLevelNotice == false)
	var f := FileAccess.open(XConfig.path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"codexNotices": {"race": 0, "chest": null, "zhenqi": false}, "codexSkillLevelNotice": 0}))
	f.close()
	reload()
	for k in nt.loose:
		check("loose_" + k, XConfig.notice_on(k) == nt.loose[k])
	check("loose_skillLevel", XConfig.notice_on("skillLevel"))
	f = FileAccess.open(XConfig.path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"MapXy": true}))
	f.close()
	reload()
	check("legacy_config_all_on", XConfig.notices_text() == "全部显示" and XConfig.map_xy())

	# 提示分类与过滤
	for row in nt.classify:
		var want: String = "" if row.key == null else str(row.key)
		check("classify_" + str(row.message), XToast.classify(str(row.message)) == want, XToast.classify(str(row.message)))
	set_off(["chest"])
	XToast.shown.clear()
	XToast.show_text("宝箱收获：金币×3")
	XToast.show_text("宝箱收获：金币×4", true)
	XToast.show_text("装备出售完成")
	XToast.show_text("种族祝福生效", false, "race")
	check("filter_auto_hidden", not XToast.shown.has("宝箱收获：金币×3"))
	check("filter_menu_shown", XToast.shown.has("宝箱收获：金币×4"))
	check("filter_unclassified_shown", XToast.shown.has("装备出售完成"))
	check("filter_explicit_key", XToast.shown.has("种族祝福生效"))
	set_off(["race"])
	XToast.show_text("种族祝福生效2", false, "race")
	check("filter_explicit_key_off", not XToast.shown.has("种族祝福生效2"))
	set_off([])

	# 设置页：打开、键盘切换、返回
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var opt := XOptionsScene.new()
	add_child(opt)
	await frames()
	var oi := opt.symbols().find("codexNotices")
	check("options_row_enabled", oi >= 0 and opt._list[oi][2] and opt.status_text(oi) == "全部显示")
	opt._select(oi)
	var before := opt.index
	opt._side(true)
	opt._side(false)
	check("options_side_noop", opt._page == null and opt.index == before and XConfig.notices_text() == "全部显示")
	await press("ui_accept")
	check("page_opened", opt._page is XNoticeOptionsScene and not opt.win.visible)
	var p: XNoticeOptionsScene = opt._page
	await frames(3)
	await shot("消息提醒_全开.png")
	XSound.system_log.clear()
	await press("ui_accept")
	check("key_ok_toggles", not XConfig.notice_on("race") and p.index == 0)
	check("key_ok_sounds", XSound.system_log == [1, 0], XSound.system_log)
	XSound.system_log.clear()
	await press("ui_left")
	check("key_left_unchanged_silent", XSound.system_log.is_empty() and not XConfig.notice_on("race"))
	await press("ui_right")
	check("key_right_on", XConfig.notice_on("race"))
	await press("ui_left")
	check("key_left_off", not XConfig.notice_on("race"))
	await press("ui_up")
	check("key_up_wraps", p.index == rows.size() - 1)
	await press("ui_accept")
	check("key_skill_level", not XConfig.notice_on("skillLevel"))
	await press("ui_down")
	check("key_down_wraps", p.index == 0)
	await frames(3)
	await shot("消息提醒_两项关闭.png")
	await press("ui_cancel")
	await frames()
	check("page_closed", opt._page == null and opt.win.visible)
	check("options_status_updated", opt.status_text(oi) == "2项关闭", opt.status_text(oi))
	check("options_index_kept", opt.index == oi if XOptionsScene.KEEP_INDEX_AFTER_PAGE else opt.index == 0)
	await shot("消息提醒_设置页.png")
	opt.queue_free()
	set_off([])

	# 主菜单（Window_MenuCommand / Window_MenuStatus）音效
	var menu := XMenu.new()
	add_child(menu)
	await frames()
	XSound.system_log.clear()
	await press("ui_down")
	check("menu_cursor", menu._cmd_index == 1 and XSound.system_log == [0], XSound.system_log)
	# 灰显指令（异化工坊；种族祝福 dev.149 起可用）蜂鸣；技能页 dev.030 起可用，真气第二批起可用
	menu._cmd_index = XMenu.COMMANDS.map(func(c): return c[1]).find("feedback")
	XSound.system_log.clear()
	await press("ui_accept")
	check("menu_disabled_buzzer", menu._mode == "command" and XSound.system_log == [3], XSound.system_log)
	menu._cmd_index = 1
	XSound.system_log.clear()
	await press("ui_down")
	await press("ui_accept")
	check("menu_ok_actor_select", menu._mode == "actor" and XSound.system_log == [0, 1], XSound.system_log)
	XSound.system_log.clear()
	await press("ui_cancel")
	check("menu_cancel_actor", menu._mode == "command" and XSound.system_log == [2], XSound.system_log)
	XSound.system_log.clear()
	menu._cmd_index = 0
	await press("ui_up")
	check("menu_wrap_cursor", menu._cmd_index == XMenu.COMMANDS.size() - 1 and XSound.system_log == [0], XSound.system_log)
	XSound.system_log.clear()
	var closed := [false]
	menu.closed.connect(func(): closed[0] = true)
	await press("ui_cancel")
	check("menu_cancel_close", closed[0] and XSound.system_log == [2], XSound.system_log)
	menu.queue_free()
	# 公共Toast的高度同步必须在收起前解绑，动画结束后全部释放。
	await get_tree().create_timer(XToast.TIMEOUT + XToast.FADE + 0.1,true,false,true).timeout
	var toast := get_tree().root.get_node_or_null("XToast") as XToast
	check("toast_all_collapsed",toast == null or toast.stack.get_child_count() == 0)
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
