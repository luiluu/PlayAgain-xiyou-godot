extends Node
## 步步遇敌（设置 yd100）下停不下来（v0.01.10 玩家反馈，安卓）：「停了挂机，一局之后立刻下一局，停不下来、跑不出去」，
## 「手机连点器模拟也一样」「不开遇敌挂三小时没事」。根因：点地移动的目的地（MVPlayer.touch_target）跨战斗、事件、挂机一直留着，
## 原版 Scene_Map.updateDestination 在开战（场景已停）、事件中、菜单时每帧清掉（MVPlayer.MV_CLEAR_DEST）。步步遇敌下每走一步一场，
## 打完接着朝旧目的地走，一路打到底；挂机前点地留下的目的地，停挂机后也接着走。
## 本专项：步步遇敌开着点地远处只打一场就停；挂机前留下的目的地停挂机后不再走；步步遇敌下各时刻点停挂机都停得住；回退开关验原来的坏表现。
## 框架照 xiyou_hangup_stop（关挂机（v0.01.09 玩家反馈：安卓前台挂了一小时，关挂机之后停不下来，狂按回城才回去）。
## 触屏真点左上挂机按钮（ScreenTouch＋触屏转鼠标，按手机打开遇敌演出），在挂机的各个时刻点：走路中、遇敌演出（黑幕盖着按钮）、
## 战斗刚开始、战斗中、战斗收场淡出（黑幕盖着按钮）、回到地图、挂满一小时自动存档之后；点完断言挂机停了、之后不再走动遇敌。
## 根因：两段黑幕 XSceneFade 挡鼠标、盖在按钮上，点了整个被吞掉（XHangUpOverlay.TAP_THROUGH_FADE，O-460）；
## 连点时停了又开回来（RESTART_GUARD_MSEC，O-461）。末尾两个回退开关各验一次原来的坏表现。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []
var map: XMapScene
var s: XState
var battles := 0
var _was_in_battle := false
var _toggles := 0
var _downs := 0
var _fade_note := ""
var _watch_stop := false  # 停挂机观察：置真后，每个物理帧看挂机已停、目的地是否还留着（事件计数，不靠点按之后才采样的位置）
var _stop_seen_target := false


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
	if _watch_stop and map and s and not XHangUp.is_active(s) and map.player.touch_target.x >= 0:
		_stop_seen_target = true


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


## 按正常时钟点一下挂机按钮：快时钟下点按那几帧里游戏已跑出几十个物理帧，人早走完停挂机前后的路，
## 之后再采样就漏记点按期间的移动（低渲染帧率下稳定出现，max_fps=15 即复现）。点按用正常时钟，采样紧跟其后
func tap_button_normal() -> void:
	var clock := [Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame, Engine.time_scale]
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 1
	Engine.time_scale = 1.0
	await tap(button_at())
	Engine.physics_ticks_per_second = clock[0]
	Engine.max_physics_steps_per_frame = clock[1]
	Engine.time_scale = clock[2]


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
	TestEnv.isolate("xiyou_step_encounter_stop")
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	if DisplayServer.get_name() == "headless":
		OS.low_processor_usage_mode_sleep_usec = 0
		Engine.physics_ticks_per_second = 600
		Engine.max_physics_steps_per_frame = 64
		Engine.time_scale = 30.0
	# 手动压测渲染帧率（偶发排查）：XIYOU_STEP_FPS=15 复现低帧率下一帧跑多个物理帧的调度；默认不设
	if OS.get_environment("XIYOU_STEP_FPS") != "":
		Engine.max_fps = int(OS.get_environment("XIYOU_STEP_FPS"))
	seed(20261115)
	s = XState.new_game(3, 1, [8, 10, 9])
	s.random_master = XRandomStream.hex64(20261115)
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.set_self_switch(4, 20, "A", true)
	s.flags.SaveGameId = 1
	XPlatform.force_mobile = true
	Input.emulate_mouse_from_touch = true
	ReleaseEntry.simulate_release = true  # 玩家用的是发行包：按发行模式跑（天启篇关着）
	XBattleTransition.IN_HEADLESS = true  # 手机上有遇敌演出与回地图淡出
	XConfig.set_session("yd100", true)  # 设置「步步遇敌」
	map = XMapScene.new()
	add_child(map)
	await frames(4)
	map.hang_overlay.toggle_requested.connect(func(): _toggles += 1)
	map.hang_overlay.button.button_down.connect(func(): _downs += 1)
	# 不挂机点地：只打一场
	await tap_walk("tap_far_one_battle", Vector2(7, 0), 1)
	await tap_walk("tap_near_one_battle", Vector2(3, 0), 1)
	# 挂机前点地留下的目的地：停挂机后不再走
	await stale_target_hangup("stale_target_after_hangup_stop")
	# 步步遇敌下各时刻点停挂机
	var t := [0]
	await stop_at("battle_mid", func():
		if map._in_battle:
			t[0] += 1
		return t[0] > 200)
	var was := [false]
	await stop_at("after_battle", func():
		if map._in_battle:
			was[0] = true
		return was[0] and not map._in_battle)
	# 回退开关：目的地一直留着，点远处一路打到底、挂机前的目的地停挂机后接着走
	MVPlayer.MV_CLEAR_DEST = false
	await tap_walk("rollback_tap_far_many_battles", Vector2(7, 0), -1)
	await stale_target_hangup("rollback_stale_target_walks", true)
	MVPlayer.MV_CLEAR_DEST = true
	XConfig.set_session("yd100", null)  # 收尾：不再遇敌，等手上这场打完再退出（退出时战斗没收完会报已释放的音频）
	await wait_still()
	for i in 60:  # 战斗场景（含收场淡出里的）都走完再退出
		if battle_scene() == null and not map._in_battle and not map.busy:
			break
		await settle()
		await physics(60)
	await frames(10)
	# stop_fade 传入已释放的播放器：不报错、不崩（偶发 SCRIPT ERROR「previously freed」）
	var dead := AudioStreamPlayer.new()
	dead.free()
	XAudio.stop_fade(dead)
	check("stop_fade_freed_player_ok", true)
	_finish()


## 等回到地图、人不动、没在打
func wait_still() -> void:
	for i in 40:
		await settle()
		await physics(120)
		if not map._in_battle and not map.busy and not map.player.is_moving():
			await physics(300)
			if not map._in_battle and not map.busy and not map.player.is_moving():
				return


## 点玩家所在格偏 off 格（格数）的那一格
## 点按那几帧按正常时钟走（快时钟一帧跑几十个物理帧，点按期间人已走出好几格）
func tap_cell(off: Vector2) -> void:
	var clock := [Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame, Engine.time_scale]
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 1
	Engine.time_scale = 1.0
	await tap(map.player.get_global_transform_with_canvas().origin + off * 48.0)
	Engine.physics_ticks_per_second = clock[0]
	Engine.max_physics_steps_per_frame = clock[1]
	Engine.time_scale = clock[2]


## 不挂机：点 off 格外的一格走过去。原版开战时清目的地（Scene_Map.stop→isMapTouchOk 假→clearDestination），只打一场就停。
## want＝-1 表示要多于一场（回退开关）
func tap_walk(tag: String, off: Vector2, want: int) -> void:
	await settle()
	if XHangUp.is_active(s):
		XHangUp.stop(s)
	await map.load_map(5, 11, 13, 2)
	await frames(4)
	var g0 := map.player.grid
	var b0 := battles
	await tap_cell(off)
	await wait_still()
	var n := battles - b0
	# 步步遇敌下第一步就开战、目的地随即清掉，所以看人动没动、打了几场
	check(tag, map.player.grid != g0 and (n == want if want >= 0 else n > 1) and map.player.touch_target.x < 0,
		{"battles": n, "from": g0, "now": map.player.grid, "touch_target": map.player.touch_target})


## 没开步步遇敌、遇敌步数很大时点地远处，人一动就开挂机（目的地留着），挂一会儿停掉，再开步步遇敌：停后不该再走、再打
func stale_target_hangup(tag: String, expect_walk := false) -> void:
	await settle()
	if XHangUp.is_active(s):
		XHangUp.stop(s)
	XConfig.set_session("yd100", null)
	await map.load_map(5, 11, 13, 2)
	await frames(4)
	map.encounter_count = 999
	var pre := [map.map_id, map.player.grid, map.busy, map.player.input_enabled, map._in_battle]
	map.player.click_cell(map.player.grid + Vector2i(7, 0))  # 点地（真点按已由 tap_walk 验过；这里只要留下目的地）
	var tt: bool = await until(func(): return map.player.is_moving() or map.player.grid != pre[1], 200)  # 点地生效、人走起来了
	await tap_button_normal()  # 开挂机
	var started := XHangUp.is_active(s)
	await physics(200)
	# 挂机前留下的目的地还在（不靠点按时机）：取人刚离开的那一格，停后走得回去（固定格子在云端随机走到别处时可能走不过去）
	await until(func(): return not map.player.is_moving(), 200)
	var left := map.player.grid
	await until(func(): return map.player.grid != left, 400)
	map.player.touch_target = left
	map.encounter_count = 999
	_stop_seen_target = false
	_watch_stop = true  # 挂机一停就开始看：目的地还留着（回退开关）＝停后会接着走，点按期间人已走到的也记得住
	await tap_button_normal()  # 停挂机
	var stopped := not XHangUp.is_active(s)
	XConfig.set_session("yd100", true)
	map.encounter_count = 1
	var b0 := battles
	await until(func(): return not map.player.is_moving(), 200)
	var g0 := map.player.grid  # 停的那一步走完的格子
	await physics(900)
	await wait_still()
	_watch_stop = false
	var walked := battles > b0 or map.player.grid != g0 or _stop_seen_target
	check(tag, tt and started and stopped and walked == expect_walk,
		{"pre": pre, "walking": tt, "started": started, "stopped": stopped, "battles_after": battles - b0, "from": g0, "now": map.player.grid, "touch_target": map.player.touch_target, "target_kept_after_stop": _stop_seen_target})


func _finish() -> void:
	XPlatform.force_mobile = null
	ReleaseEntry.simulate_release = false
	XConfig.set_session("yd100", null)
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"passed": results.size() - failed.size(), "total": results.size()}))
	for i in range(1, 31):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	get_tree().quit.call_deferred(1 if failed.size() > 0 else 0)
