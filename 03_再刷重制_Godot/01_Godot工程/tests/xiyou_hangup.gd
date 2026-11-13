extends Node
## 挂机（XdRs_HangUp）第一批：默认设置、快捷界面与提示的布局（正式 v0.13 运行时读数）、无敌人/禁用、开关、
## 挂机中禁菜单与手动移动、范围内随机走动、遇敌自动战斗且不出结算、死亡停止、自动存档、读档清除、信息自动翻页。
## 窗口模式加 -- --out=<目录> 保存实际绘制截图。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []

## 记下画了哪些字（挂机提示的 drawWord）
class TextRec extends XMVCanvas:
	var texts: Array = []
	func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, zoom := 1.0, pivot := Vector2.ZERO, outline := OUTLINE) -> void:
		texts.append([s, x, y, max_w, align, color.to_html(false), size, lh])
var out_dir := ""
var _victory_screens := 0
var _clock_before := []


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


## 触屏点一下（坐标是视口坐标，换成窗口坐标再送）
func tap(at: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = get_viewport().get_final_transform() * at
	e.pressed = true
	Input.parse_input_event(e)
	await frames(3)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await frames(3)


func _run() -> void:
	TestEnv.isolate("xiyou_hangup")   # 新源大厅（Map4 EV76）首次进入的漩涡过场当作播过：过场占住地图，按挂机键被忽略、no_enemy 挂（集成分支 run 42343228257；本机留着上次的 options.json 才过）
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	# 计时实测的最慢项是等待物理帧（约139秒）。沿用楼层流程的headless快时钟，
	# 仍逐帧执行同样的240/150步、战斗、自动存档与翻页；窗口截图模式保持原节奏。
	_clock_before = [OS.low_processor_usage_mode_sleep_usec, Engine.physics_ticks_per_second,
		Engine.max_physics_steps_per_frame, Engine.time_scale]
	if DisplayServer.get_name() == "headless":
		OS.low_processor_usage_mode_sleep_usec = 0
		Engine.physics_ticks_per_second = 600
		Engine.max_physics_steps_per_frame = 64
		Engine.time_scale = 30.0
	else:
		Engine.time_scale = 6.0
	seed(20261014)
	var s := XState.new_game(3, 1, [8, 10, 9])
	# dev.099 起战斗用本场规则流（主种子只在运行时生成），全局 seed() 管不到；固定主种子才能复现
	s.random_master = XRandomStream.hex64(20261014)
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
	# 禁用时按 G（v0.01.06 玩家反馈「挂机没反应」：新游戏开局就禁用，原版要先按 L）：照 L 的公共事件 484 开启，不直接开始（O-待定）
	await frames(2)
	await key_g()
	check("g_enables_when_prohibited", await until(func(): return XHangUp.enabled(s) and not map.busy, 600) and not XHangUp.is_active(s), [s.flags.get("HangUpProhibited"), map.busy])
	# 副本里（变量 21 非 0）：公共事件只提示去重置，仍禁用
	s.flags.HangUpProhibited = true
	s.set_variable(21, 1)
	s.set_variable(6, 1)
	await key_g()
	await frames(60)
	await until(func(): return not map.busy, 600)
	check("g_in_dungeon_stays_prohibited", not XHangUp.enabled(s) and not XHangUp.is_active(s))
	s.set_variable(21, 0)
	s.set_variable(6, 0)
	# 回退开关：原版禁用时 G 只清除状态
	XHangUp.KEY_ENABLES = false
	await key_g()
	await frames(60)
	check("g_rollback_stays_prohibited", not XHangUp.enabled(s) and not XHangUp.is_active(s))
	XHangUp.KEY_ENABLES = true
	# 触屏（安卓没有 L 键）：禁用时也显示挂机按钮，点了照 L 开启（O-待定-2，XHangUp.TOUCH_SHOW_PROHIBITED）
	XPlatform.force_mobile = true
	await frames(2)
	check("touch_prohibited_button_shown", ov.inter.visible and ov.button.is_visible_in_tree())
	ov.button.pressed.emit()
	check("touch_button_enables", await until(func(): return XHangUp.enabled(s) and not map.busy, 600) and not XHangUp.is_active(s), [s.flags.get("HangUpProhibited"), map.busy])
	s.flags.HangUpProhibited = true
	XHangUp.TOUCH_SHOW_PROHIBITED = false
	await frames(2)
	check("touch_rollback_hidden", not ov.inter.visible)
	XHangUp.TOUCH_SHOW_PROHIBITED = true
	XPlatform.force_mobile = null
	await frames(2)
	check("desktop_prohibited_hidden", not ov.inter.visible)
	s.flags.HangUpProhibited = false
	# 一层：G 键开始
	await map.load_map(5, 11, 13, 2)
	await frames(2)
	map.encounter_count = 999
	# 触屏点挂机按钮（Kyo 11-13 安卓：点了不会开始）：Godot 把一下触屏送成鼠标键＋触屏两份按下，按下即触发的按钮开了又关；
	# 现在同一下只认一次（O-待定-1，XHangUpOverlay.ONE_PRESS_PER_TAP）
	var emu := Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	var at := ov.button.get_global_rect().get_center()
	await tap(at)
	check("touch_tap_starts", XHangUp.is_active(s) and map.player.touch_target == Vector2i(-1, -1), [XHangUp.is_active(s), map.player.touch_target])
	await frames(4)
	await tap(at)
	check("touch_tap_again_stops", not XHangUp.is_active(s))
	XHangUpOverlay.ONE_PRESS_PER_TAP = false
	await frames(4)
	await tap(at)
	check("touch_tap_rollback_toggles_twice", not XHangUp.is_active(s))
	XHangUpOverlay.ONE_PRESS_PER_TAP = true
	Input.emulate_mouse_from_touch = emu
	await physics(10)
	await map.load_map(5, 11, 13, 2)  # 挂机时随机走过，回到原点再测 G 键
	await frames(2)
	map.encounter_count = 999
	await key_g()
	check("start", XHangUp.is_active(s) and s.hang_up_origin == Vector2i(11, 13) and ov.tip.visible and not map.player.input_enabled, [s.hang_up_active, s.hang_up_origin])
	# 提示上的字（原版 drawWord 画进离屏画布从不显示；rules-bugfix1 照搬清单第 1 条修好，O-227）
	var tip_rec := TextRec.new()
	ov.tip_text.painter.call(tip_rec)
	check("tip_word_drawn", ov.tip_text.is_visible_in_tree() and tip_rec.texts == [["摆烂中.....", 0.0, 30.0, 560.0, "center", "ff6400", 28, 30]], tip_rec.texts)
	XHangUpOverlay.TIP_WORD = false
	var tip_rec2 := TextRec.new()
	ov.tip_text.painter.call(tip_rec2)
	check("tip_word_rollback_none", tip_rec2.texts.is_empty(), tip_rec2.texts)
	XHangUpOverlay.TIP_WORD = true
	tip_rec.free()
	tip_rec2.free()
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
	# pressed 同步停止并缩小按钮。快时钟下两个 process_frame 可能已跨过恢复所需的 8 个物理帧，
	# 所以立即核对按下效果，再照原来的 10 个物理帧验证恢复；不依赖渲染帧与物理帧的比例。
	check("button_stop", not XHangUp.is_active(s) and is_equal_approx(ov._button_sprite.scale.x, 0.9) and s.hang_up_total > total_before,
		[XHangUp.is_active(s), ov._button_sprite.scale.x, s.hang_up_total, total_before])
	await physics(10)
	# 按钮缩放由物理帧恢复，地图输入则由 _process 恢复；一次快时钟补帧可能尚未运行后者。
	await frames(2)
	check("button_scale_restore", is_equal_approx(ov._button_sprite.scale.x, 1.0) and map.player.input_enabled,
		[ov._button_sprite.scale.x, map.player.input_enabled, map.busy])
	map.queue_free()
	await frames(2)
	for i in range(1, 31):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir())
	_rollback_logic()
	XEnemy.force_roll = -1.0
	OS.low_processor_usage_mode_sleep_usec = _clock_before[0]
	Engine.physics_ticks_per_second = _clock_before[1]
	Engine.max_physics_steps_per_frame = _clock_before[2]
	Engine.time_scale = _clock_before[3]
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## O-016／O-017 回退（只算规则，不开地图）：
## - SILENT_WHEN_IDLE = false：没在挂机时战斗结束有人阵亡，原版 refrishHangUp 也调 stopHangUp，播一声取消音（system 2）
## - AUTO_SAVE_SETTING = false：原版定时存档不看「自动储存」（needAutoSave 没被调用），关着也照存；说明里的档位取插件参数 saveId，空为 1
func _rollback_logic() -> void:
	var prev := XState.current
	var st := XState.new_game(3, 1, [8, 9, 10])
	XState.current = st
	for silent in [true, false]:
		if silent:
			XHangUp.SILENT_WHEN_IDLE = true
		else:
			XHangUp.SILENT_WHEN_IDLE = false  # 回退值写成字面量，回退开关覆盖.py 才认得
		XHangUp.clear(st)
		st.members()[1].hp = 0
		XSound.system_log.clear()
		XHangUp.after_battle(st)
		st.members()[1].hp = 1
		check("idle_death_sound_%s" % ("silent" if silent else "original"), not XHangUp.is_active(st) and XSound.system_log.has(2) != silent, XSound.system_log)
	XHangUp.SILENT_WHEN_IDLE = true
	st.flags["SaveGameId"] = 7
	var raw := str(XHangUp.params().get("saveId", ""))
	var param_slot := int(raw) if raw.is_valid_int() and int(raw) != 0 else 1
	for setting in [true, false]:
		if setting:
			XHangUp.AUTO_SAVE_SETTING = true
		else:
			XHangUp.AUTO_SAVE_SETTING = false  # 回退值写成字面量，回退开关覆盖.py 才认得
		XHangUp.settings(st).autoSave = false
		st.hang_up_active = true
		st.hang_up_origin = Vector2i(1, 1)
		st.hang_up_save_pending = false
		st.hang_up_count = XHangUp.save_frames() - 1
		XHangUp.tick(st)
		var tag := "setting" if setting else "original"
		check("auto_save_off_%s" % tag, st.hang_up_save_pending != setting, [st.hang_up_count, st.hang_up_save_pending])
		check("auto_save_slot_%s" % tag, XHangUp.auto_save_slot(st) == (7 if setting else param_slot), XHangUp.auto_save_slot(st))
	XHangUp.AUTO_SAVE_SETTING = true
	XHangUp.clear(st)
	# O-273 守层者挂机门（条件脚本 XdRsData.hangUp.GuaJiStartBettleOk，经 MVScript.eval_expr）：
	# 开始挂机 → 门开；停止 → 门关；「读档」（clear，不经 stop）后：优化看是否正在挂机 → 关，原版残留标记 → 仍开
	const GATE := "XdRsData.hangUp.GuaJiStartBettleOk"
	for active_only in [true, false]:
		if active_only:
			XHangUp.GATE_ACTIVE_ONLY = true
		else:
			XHangUp.GATE_ACTIVE_ONLY = false  # 回退值写成字面量，回退开关覆盖.py 才认得
		var tag := "active" if active_only else "original"
		XHangUp.started_flag = false
		check("gate_idle_%s" % tag, MVScript.eval_expr(GATE) == false, MVScript.eval_expr(GATE))
		XHangUp.ready_start(st, true, Vector2i(2, 2))
		check("gate_hanging_%s" % tag, MVScript.eval_expr(GATE) == true, MVScript.eval_expr(GATE))
		XHangUp.clear(st)   # 读档：运行状态清掉，原版标记不清
		check("gate_after_load_%s" % tag, MVScript.eval_expr(GATE) == (not active_only), [MVScript.eval_expr(GATE), XHangUp.started_flag])
		XHangUp.ready_start(st, true, Vector2i(2, 2))
		XHangUp.stop(st)
		check("gate_after_stop_%s" % tag, MVScript.eval_expr(GATE) == false, MVScript.eval_expr(GATE))
	XHangUp.GATE_ACTIVE_ONLY = true
	XHangUp.started_flag = false
	XHangUp.clear(st)
	XState.current = prev
