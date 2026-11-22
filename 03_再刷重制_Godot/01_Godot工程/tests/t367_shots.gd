extends Node
## 工具（不是专项）：T367 异化工坊套模板页截图。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t367_shots.tscn -- --out=<目录>
## 16:9 窗口 800×450（设计 1280×720 的 0.625 倍）、20:9 窗口 1000×450（视口 1600×720）。
## 拍：四个页签、分解确认弹窗、重抽确认弹窗、空列表、字体 130%、20:9；回退（LAYOUT_V3 = false）对照两张。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _frames(n := 20) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _tq_state(line := "plague") -> XState:
	var ids := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 4)
	var s := XTianqi.start_new_game(3, "jianxian", ids)
	XTianqi.take_pending()
	for id in ids:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
	return s


func _full_state() -> XState:
	var s := _tq_state()
	s.gain_item(XAlienation.stone_id(), 3)
	s.gain_item(XAlienation.energy_id(), 26)
	s.gold = 500000
	var i: Dictionary = XTianqiAlienGear.create(s, "armor", 52, "plague", "huaxing", "mimic").ok
	s.gear.append(i)
	var j: Dictionary = XTianqiAlienGear.create(s, "weapon", 5, "plague", "shigu", "insulation").ok
	if j.has("instanceId"):
		s.gear.append(j)
	XTianqiAlienGear.add_core(s, "plague", "insulation", "shigu", "test")
	s.gain_gear("armor", 53, 1)
	s.gain_gear("armor", 54, 1)
	var wid := 0
	for r in XDB.table("Weapons"):
		if wid == 0 and r is Dictionary and str(r.get("name", "")) != "":
			var tpl := XGear.template("weapon", int(r.id))
			if XQuality.grade(tpl) == 6 and XTianqiAffixRoll.tier_of(tpl) == 4 and not XEquipment.is_exclusive(tpl):
				wid = int(r.id)
	var it := XGear.create("weapon", wid, s)
	XTianqiAffixRoll.set_affixes(it, [{"key": str(XTianqiAffixRoll.layer_candidates(it, "base")[0]), "tier": 4, "grade": "normal", "extra": {}},
		{"key": str(XTianqiAffixRoll.layer_candidates(it, "special")[0]), "tier": 4, "grade": "normal", "extra": {}}])
	s.register_gear(it)
	s.gear.append(it)
	return s


func _open() -> XAlienWorkshop:
	XAlienWorkshop.selected = ""
	var ws := XAlienWorkshop.new()
	ws.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ws)
	await _frames(10)
	return ws


func _press(ws: Node, prefix: String) -> void:
	for c in ws.find_children("*", "Button", true, false):
		if (c as Button).text.begins_with(prefix) and (c as Button).is_visible_in_tree():
			(c as Button).pressed.emit()
			break
	await _frames(10)


func _close(ws: Node) -> void:
	ws.queue_free()
	await _frames(3)


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	TestEnv.isolate("t367_shots")
	XSplashScreen.shown = true
	XConfig.ensure_loaded()
	XConfig._values["codexUiSkin"] = true
	XUiSkin.ENABLED = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	var win := get_window()
	win.size = Vector2i(800, 450)
	await _frames(10)
	for v3 in [false, true]:
		XAlienWorkshop.LAYOUT_V3 = v3
		var tag := "after" if v3 else "before"
		_full_state()
		var ws := await _open()
		for i in ws.skin_tabs.size():
			ws.skin_tab = i
			ws._skin_tab_name = str(ws.skin_tabs[i][0])
			ws.render(true)
			await _frames(10)
			await _shot("%s_tab%d" % [tag, i + 1])
		ws.skin_tab = 0
		ws._skin_tab_name = ""
		ws.render(true)
		await _frames(10)
		await _press(ws, "分解为")
		await _shot(tag + "_dismantle_confirm")
		await _close(ws)
	XAlienWorkshop.LAYOUT_V3 = true
	_full_state()
	var ws := await _open()
	await _press(ws, "使用1颗异化石重抽")
	await _shot("after_reroll_confirm")
	await _close(ws)
	_tq_state()
	ws = await _open()
	await _shot("after_empty")
	await _close(ws)
	XFontScale.set_value("global", 130)
	_full_state()
	ws = await _open()
	await _shot("after_font130")
	await _close(ws)
	XFontScale.set_value("global", 100)
	# 20:9：窗口 1000×450 → 视口 1600×720
	XSkinLayout.window_override = Vector2(1000, 450)
	win.size = Vector2i(1000, 450)
	await _frames(10)
	_full_state()
	ws = await _open()
	XSkinLayout._apply_wide(get_tree().root)
	await _frames(10)
	ws.render(true)
	await _frames(10)
	await _shot("after_wide_tab1")
	ws.skin_tab = 1
	ws._skin_tab_name = str(ws.skin_tabs[1][0])
	ws.render(true)
	await _frames(10)
	await _shot("after_wide_tab2")
	await _press(ws, "刻上")
	await _close(ws)
	XSkinLayout.window_override = Vector2.ZERO
	XState.current = null
	print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
	get_tree().quit.call_deferred(0)
