extends Node
## 挂机（XdRs_HangUp）第一批：默认设置、快捷界面与提示的布局（正式 v0.13 运行时读数）、无敌人/禁用、开关、
## 挂机中禁菜单与手动移动、范围内随机走动、遇敌自动战斗且不出结算、死亡停止、自动存档、读档清除、信息自动翻页。
## 窗口模式加 -- --out=<目录> 保存实际绘制截图。

var results := []
var out_dir := ""
var _victory_screens := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	get_tree().node_added.connect(func(n): if n is XVictoryScreen: _victory_screens += 1)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func physics(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func until(f: Callable, limit := 3000) -> bool:
	for i in limit:
		if f.call():
			return true
		await get_tree().physics_frame
	return f.call()


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func key_g() -> void:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_G
	e.keycode = KEY_G
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await frames(1)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_hangup"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	Engine.time_scale = 6.0
	seed(20261014)
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.set_self_switch(4, 20, "A", true)
	s.flags.SaveGameId = 1
	check("defaults", XHangUp.settings(s) == XHangUp.DEFAULTS and XHangUp.DEFAULTS.range == 10 and XHangUp.DEFAULTS.deathStop and not XHangUp.DEFAULTS.fastFt)
	check("time_text", XHangUp.time_text(s) == "---")
	s.hang_up_active = true
	s.hang_up_origin = Vector2i(1, 1)
	s.hang_up_count = 3725 * 60
	check("time_text_running", XHangUp.time_text(s) == "01:02:05", XHangUp.time_text(s))
	XHangUp.clear(s)
	check("clear_adds_total", s.hang_up_total == 3725 * 60 and s.hang_up_count == 0 and not XHangUp.is_active(s))
	s.hang_up_total = 0
	check("toward", XHangUp.toward(Vector2i(5, 5), Vector2i(1, 4)) == [4, 8] and XHangUp.toward(Vector2i(5, 5), Vector2i(5, 9)) == [2]
		and XHangUp.toward(Vector2i(5, 5), Vector2i(7, 7)) == [2, 6] and XHangUp.toward(Vector2i(5, 5), Vector2i(5, 5)) == [])
	s.hang_up_origin = Vector2i(0, 0)
	check("out_of_range_returns", XHangUp.next_dirs(s, Vector2i(9, 3)) == [4, 8])
	s.hang_up_origin = Vector2i(-1, -1)
	var map := XMapScene.new()
	add_child(map)
	await frames(4)
	var ov := map.hang_overlay
	check("inter_layout", ov.inter.visible and ov.inter.position == Vector2(20, 10) and ov.inter.size == Vector2(240, 74)
		and ov.button.get_global_rect() == Rect2(25, 25, 54, 54) and not ov.tip.visible)
	check("tip_layout", ov.tip.position == Vector2(360, 100) and ov.tip.size == Vector2(546, 88) and is_equal_approx(ov.tip.modulate.a, 160.0 / 255.0))
	await shot("00_快捷界面.png")
	# 大厅没有遇敌表：不能开始
	await map.toggle_hang_up()
	check("no_enemy", not XHangUp.is_active(s) and not map.busy)
	# 禁用（ProhibitHangUp）：快捷界面不显示，按键只清除
	s.flags.HangUpProhibited = true
	await frames(2)
	check("prohibited_hidden", not ov.inter.visible)
	var interp := MVInterpreter.new(map, 4, 0, [])
	interp._plugin_command("EnableHangUp")
	check("plugin_enable", XHangUp.enabled(s) and interp.skipped.is_empty())
	interp._plugin_command("ProhibitHangUp")
	check("plugin_prohibit", not XHangUp.enabled(s))
	s.flags.HangUpProhibited = false
	# 一层：G 键开始
	await map.load_map(5, 11, 13, 2)
	await frames(2)
	map.encounter_count = 999
	await key_g()
	check("start", XHangUp.is_active(s) and s.hang_up_origin == Vector2i(11, 13) and ov.tip.visible and not map.player.input_enabled, [s.hang_up_active, s.hang_up_origin])
	map.open_menu()
	await frames(2)
	check("menu_blocked", not map._menu_open)
	await physics(240)
	check("wanders_in_range", map.player.grid != Vector2i(11, 13) and XHangUp.in_range(s.hang_up_origin, map.player.grid, 11) and s.hang_up_count > 0, [map.player.grid, s.hang_up_count])
	await shot("01_挂机中.png")
	# 遇敌：自动战斗，胜利不出结算，回到地图仍在挂机
	map.encounter_count = 1
	var battled := await until(func(): return map._in_battle)
	check("encounter", battled)
	await physics(150)
	await shot("02_挂机战斗.png")
	var done := await until(func(): return not map._in_battle and not map.busy, 20000)
	var alive := s.members().all(func(a): return not a.is_dead())
	check("battle_auto_no_victory_screen", done and _victory_screens == 0, [done, _victory_screens])
	check("still_hanging_after_win", XHangUp.is_active(s) == alive, [XHangUp.is_active(s), alive])
	# 死亡停止
	if not XHangUp.is_active(s):
		XHangUp.ready_start(s, true, map.player.grid)
	s.members()[1].hp = 0
	XHangUp.after_battle(s)
	check("death_stop", not XHangUp.is_active(s))
	s.members()[1].hp = 1
	XHangUp.settings(s).deathStop = false
	XHangUp.ready_start(s, true, map.player.grid)
	s.members()[1].hp = 0
	XHangUp.after_battle(s)
	check("death_stop_off", XHangUp.is_active(s))
	s.members()[1].hp = 1
	XHangUp.settings(s).deathStop = true
	# 自动存档：计时满 10 分钟时存到开局固定存档位
	map.encounter_count = 999
	s.hang_up_count = XHangUp.save_frames() - 2
	var saved := await until(func(): return XSave.exists(1) and not map.busy, 600)
	check("auto_save", saved and not s.hang_up_save_pending and XSave.current_slot == 1)
	# 信息自动翻页：挂机中不按键，60 帧后自行结束
	XMessageBox.auto = false
	var msg := {"done": false}
	var go := func():
		await map.message.show_text("", 0, ["挂机中的信息"])
		msg.done = true
	go.call()
	var auto_closed := await until(func(): return msg.done, 400)
	check("message_auto_advance", auto_closed)
	XMessageBox.auto = true
	# 读档：设置与总时长保留，运行状态清除
	var total_before := s.hang_up_total
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var loaded := XState.from_dict(d)
	check("load_clears", not XHangUp.is_active(loaded) and loaded.hang_up.range == 10 and loaded.hang_up_total == total_before)
	XState.current = s
	# 面板按钮停止
	ov.button.pressed.emit()
	await frames(2)
	check("button_stop", not XHangUp.is_active(s) and is_equal_approx(ov._button_sprite.scale.x, 0.9) and s.hang_up_total > total_before)
	await physics(10)
	check("button_scale_restore", is_equal_approx(ov._button_sprite.scale.x, 1.0) and map.player.input_enabled)
	map.queue_free()
	await frames(2)
	for i in range(1, 31):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir())
	XEnemy.force_roll = -1.0
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
