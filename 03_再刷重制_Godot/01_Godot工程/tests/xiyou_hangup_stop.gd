extends Node
## 关挂机（v0.01.09 玩家反馈：安卓前台挂了一小时，关挂机之后停不下来，狂按回城才回去）。
## 触屏真点左上挂机按钮（ScreenTouch＋触屏转鼠标，按手机打开遇敌演出），在挂机的各个时刻点：走路中、遇敌演出（黑幕盖着按钮）、
## 战斗刚开始、战斗中、战斗收场淡出（黑幕盖着按钮）、回到地图、挂满一小时自动存档之后；点完断言挂机停了、之后不再走动遇敌。
## 根因：两段黑幕 XSceneFade 挡鼠标、盖在按钮上，点了整个被吞掉（XHangUpOverlay.TAP_THROUGH_FADE，O-待定-1）；
## 连点时停了又开回来（RESTART_GUARD_MSEC，O-待定-2）。末尾两个回退开关各验一次原来的坏表现。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []
var map: XMapScene
var s: XState
var battles := 0
var _was_in_battle := false
var _toggles := 0
var _downs := 0
var _fade_note := ""


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	print(("PASS " if ok else "FAIL "), name, " ", detail if detail != null else "")


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


func _physics_process(_d: float) -> void:
	if map and map._in_battle and not _was_in_battle:
		battles += 1
	_was_in_battle = map != null and map._in_battle


## 触屏点一下（视口坐标）：按下与松开之间隔 hold 帧
func tap(at: Vector2, hold := 3) -> void:
	_fade_note = ""
	if map:
		for c in map.ui.get_children():
			if c is Control and c.get_index() > map.hang_overlay.get_index() and c.visible and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(at):
				_fade_note += ("(freed)" if c.is_queued_for_deletion() else "") + c.get_class() + ":" + str(c.get_script().get_global_name() if c.get_script() else "") + " "
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = get_viewport().get_final_transform() * at
	e.pressed = true
	Input.parse_input_event(e)
	await frames(hold)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await frames(2)


## 地图 ui 上有没有正在用的遇敌／收场黑幕
func fade_on() -> bool:
	return map.ui.get_children().any(func(c): return c is XSceneFade and not c.is_queued_for_deletion())


func battle_scene() -> XBattleScene:
	for c in map.ui.get_children():
		if c is XBattleScene:
			return c
	return null


## 停挂机之后：战斗里还要人手选指令的，交给自动战斗打完；等回到地图静下来
func settle() -> void:
	for i in 40:
		var b := battle_scene()
		if b and b.logic and not b.logic.auto and b.auto_btn:
			b.auto_btn.pressed.emit()
		if not map._in_battle and not map.busy:
			break
		await physics(100)


func start_hanging() -> void:
	await settle()
	if XHangUp.is_active(s):
		XHangUp.stop(s)
	await map.load_map(5, 11, 13, 2)
	await frames(4)
	map.encounter_count = 999
	await tap(button_at())
	await frames(2)


func button_at() -> Vector2:
	return map.hang_overlay.button.get_global_rect().get_center()


## 在 when 成立的那一帧点挂机按钮，之后看挂机停没停、还会不会再遇敌
func stop_at(tag: String, when: Callable, limit := 6000, prep := Callable(), expect_stop := true) -> void:
	await start_hanging()
	if not XHangUp.is_active(s):
		check("start_" + tag, false, "没开始")
		return
	map.encounter_count = 3
	if prep.is_valid():
		prep.call()
	var hit := await until(when, limit)
	if not hit:
		check("reach_" + tag, false, [map._in_battle, map.busy, battles])
		return
	var at_frame := Engine.get_physics_frames()
	_toggles = 0
	_downs = 0
	# 点按那几帧按正常时钟走：快时钟一帧跑几十个物理帧，黑幕（24／60 帧）会在按下送到之前就结束，测不到被盖住的情形
	var clock := [Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame, Engine.time_scale]
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 1
	Engine.time_scale = 1.0
	var fade_at_tap := fade_on()
	await tap(button_at())
	Engine.physics_ticks_per_second = clock[0]
	Engine.max_physics_steps_per_frame = clock[1]
	Engine.time_scale = clock[2]
	var stopped_now := not XHangUp.is_active(s)
	await settle()
	var b0 := battles
	var g0 := map.player.grid
	await physics(900)
	var ok := not XHangUp.is_active(s) and battles == b0 and map.player.grid == g0
	if not expect_stop:
		ok = not stopped_now and _toggles == 0
	if tag.contains("effect") or tag.contains("returning") or tag.contains("fade"):
		ok = ok and fade_at_tap  # 这几项要真在黑幕下点
	check("stop_" + tag, ok, {"fade_at_tap": fade_at_tap, "toggles": _toggles, "downs": _downs, "fades": _fade_note, "stopped_at_tap": stopped_now, "active": XHangUp.is_active(s), "battles_after": battles - b0,
		"moved": map.player.grid != g0, "frame": at_frame, "touch_target": map.player.touch_target})


func _run() -> void:
	TestEnv.isolate("xiyou_hangup_stop")
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	if DisplayServer.get_name() == "headless":
		OS.low_processor_usage_mode_sleep_usec = 0
		Engine.physics_ticks_per_second = 600
		Engine.max_physics_steps_per_frame = 64
		Engine.time_scale = 30.0
	seed(20261114)
	s = XState.new_game(3, 1, [8, 10, 9])
	s.random_master = XRandomStream.hex64(20261114)
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.set_self_switch(4, 20, "A", true)
	s.flags.SaveGameId = 1
	XPlatform.force_mobile = true
	Input.emulate_mouse_from_touch = true
	ReleaseEntry.simulate_release = true  # 玩家用的是发行包：按发行模式跑（天启篇关着）
	XBattleTransition.IN_HEADLESS = true  # 手机上有遇敌演出与回地图淡出（盖住挂机按钮的黑幕）
	map = XMapScene.new()
	add_child(map)
	await frames(4)
	map.hang_overlay.toggle_requested.connect(func(): _toggles += 1)
	map.hang_overlay.button.button_down.connect(func(): _downs += 1)
	await stop_at("walking", func(): return not map._in_battle and not map.busy and map.player.is_moving())
	await stop_at("encounter_effect", func(): return map.busy and not map._in_battle and fade_on())
	await stop_at("battle_early", func(): return map._in_battle)
	var t := [0]
	await stop_at("battle_mid", func():
		if map._in_battle:
			t[0] += 1
		return t[0] > 200)
	var was := [false]
	await stop_at("battle_returning", func():
		for c in map.ui.get_children():
			if c is XSceneFade and not c.is_queued_for_deletion() and map._in_battle and battle_scene() and battle_scene().logic.is_over():
				return true
		return false)
	was[0] = false
	await stop_at("after_battle", func():
		if map._in_battle:
			was[0] = true
		return was[0] and not map._in_battle)
	# 挂满一小时：计时过了自动存档点（每 10 分钟存一次并弹「已自动存储」），存完之后再点停
	if XSave.exists(1):
		DirAccess.remove_absolute(XSave.path(1))
	await stop_at("after_hour_autosave", func(): return XSave.exists(1) and not map.busy and not map._in_battle, 6000, func():
		map.encounter_count = 999
		s.hang_up_count = 3600 * 60 - 3)
	# 连点（以为没点到再点一下）：点停后半秒内再点不重新开始（O-待定-2）
	await double_tap("double_tap_stays_stopped", false)
	# 过了半秒再点照常开始
	await start_hanging()
	await tap(button_at())
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < XHangUpOverlay.RESTART_GUARD_MSEC + 50:
		await frames(1)
	await tap(button_at())
	check("tap_after_guard_starts", XHangUp.is_active(s))
	# 回退开关：黑幕下点不到（O-待定-1），连点又开回来（O-待定-2）
	XHangUpOverlay.TAP_THROUGH_FADE = false
	await stop_at("rollback_fade_swallows", func():
		for c in map.ui.get_children():
			if c is XSceneFade and not c.is_queued_for_deletion() and map._in_battle and battle_scene() and battle_scene().logic.is_over():
				return true
		return false, 6000, Callable(), false)
	XHangUpOverlay.TAP_THROUGH_FADE = true
	var guard := XHangUpOverlay.RESTART_GUARD_MSEC
	XHangUpOverlay.RESTART_GUARD_MSEC = 0
	await double_tap("rollback_double_tap_restarts", true)
	XHangUpOverlay.RESTART_GUARD_MSEC = guard
	await settle()
	_finish()


func double_tap(tag: String, expect_active: bool) -> void:
	await start_hanging()
	map.encounter_count = 999
	await frames(6)
	await tap(button_at())
	await frames(3)
	await tap(button_at())
	check(tag, XHangUp.is_active(s) == expect_active, XHangUp.is_active(s))


func _finish() -> void:
	XPlatform.force_mobile = null
	ReleaseEntry.simulate_release = false
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"passed": results.size() - failed.size(), "total": results.size()}))
	for i in range(1, 31):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	get_tree().quit.call_deferred(1 if failed.size() > 0 else 0)
