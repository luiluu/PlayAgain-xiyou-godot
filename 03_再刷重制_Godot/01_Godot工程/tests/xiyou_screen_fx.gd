extends Node
## 指令 223 更改画面色调／236 设置天气：
## - XScreenFx 逐帧数值与参照引擎 Game_Screen（startTint／changeWeather／update）逐帧一致（期望值取自冻结正式源实测）；
## - 真实 XMapScene 里跑解释器：色调／天气渐变、等待帧数、天气粒子数（强度×10）、色调层显隐；
## - 存读档保留色调与天气，换地图不清。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 60000

var results: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 1e-9


func _wait_map(map_id: int) -> XMapScene:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var m = get_tree().current_scene
		if m is XMapScene and m.map_id == map_id and m.player != null and not m.busy:
			return m
		await get_tree().process_frame
	return null


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _cmd(code: int, params: Array) -> Dictionary:
	return {"code": code, "indent": 0, "parameters": params}


func _math() -> void:
	# 参照：$gameScreen.startTint([68,-34,-34,170],60) 后逐帧；changeWeather('snow',7,60)；changeWeather('none',7,60)；changeWeather('storm',3,0)
	var f := XScreenFx.new()
	f.start_tint([68, -34, -34, 170], 60)
	for i in range(1, 61):
		f.update()
		if i == 1:
			_check("tint1", _near(f.tone[0], 1.1333333333333333) and _near(f.tone[3], 2.8333333333333335), f.tone)
		if i == 10:
			_check("tint10", _near(f.tone[0], 11.333333333333334) and _near(f.tone[1], -5.666666666666667), f.tone)
		if i == 59:
			_check("tint59", _near(f.tone[0], 66.86666666666667) and _near(f.tone[3], 167.16666666666669), f.tone)
	_check("tint60", f.tone == [68.0, -34.0, -34.0, 170.0], f.tone)
	f.change_weather("snow", 7, 60)
	for i in range(1, 61):
		f.update()
		if i == 1:
			_check("snow1", f.weather_type == "snow" and _near(f.weather_power, 0.11666666666666667), f.weather_power)
		if i == 30:
			_check("snow30", _near(f.weather_power, 3.5000000000000004) and f.weather_duration == 30, f.weather_power)
	_check("snow60", f.weather_power == 7.0 and f.weather_duration == 0, f.weather_power)
	f.change_weather("none", 7, 60)
	_check("none0", f.weather_type == "snow" and f.weather_power == 7.0 and f.weather_duration == 60)
	for i in range(1, 61):
		f.update()
		if i == 1:
			_check("off1", f.weather_type == "snow" and _near(f.weather_power, 6.883333333333334), f.weather_power)
		if i == 59:
			_check("off59", f.weather_type == "snow" and _near(f.weather_power, 0.11666666666666663) and f.weather_duration == 1, f.weather_power)
	_check("off60", f.weather_type == "none" and f.weather_power == 0.0, f.weather_type)
	f.change_weather("storm", 3, 0)
	_check("storm0", f.weather_type == "storm" and f.weather_power == 3.0)
	# 即时色调（帧数 0）
	var g := XScreenFx.new()
	g.start_tint([10, 20, 30, 40], 0)
	_check("tint_instant", g.tone == [10.0, 20.0, 30.0, 40.0] and g.has_tone())
	_check("roundtrip", XScreenFx.from_dict(JSON.parse_string(JSON.stringify(f.to_dict()))).to_dict() == f.to_dict())
	_check("default_screen", not XScreenFx.new().has_tone() and XScreenFx.new().weather_type == "none")


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_screen_fx"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	_math()
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	s.x = 14
	s.y = 23
	get_tree().change_scene_to_file(MAP_SCENE)
	var map := await _wait_map(4)
	if not _check("map_loaded", map != null):
		await _finish()
		return
	var view: XScreenFxView = map.screen_fx
	_check("idle_hidden", not view._tone_rect.visible and not view._weather.visible)
	# 223 带等待：60 帧后到目标，色调层显示；236 不等待
	var tint_list := [_cmd(223, [[68, -34, -34, 170], 60, true]), _cmd(236, ["snow", 7, 60, false]), _cmd(0, [])]
	var it := MVInterpreter.new(map, 4, 0, tint_list)
	var f0 := Engine.get_physics_frames()
	await it.run()
	var waited := Engine.get_physics_frames() - f0
	_check("tint_waited", waited >= 59 and waited <= 63, waited)
	await _frames(2)    # 等待结束在最后一次更新之前，再走一两帧到位
	_check("tint_reached", s.screen.tone == [68.0, -34.0, -34.0, 170.0], s.screen.tone)
	_check("tone_layer_on", view._tone_rect.visible)
	_check("weather_ramping", s.screen.weather_type == "snow" and s.screen.weather_power > 0.0 and s.screen.weather_power < 7.0, s.screen.weather_power)
	await _frames(70)
	_check("weather_full", _near(s.screen.weather_power, 7.0), s.screen.weather_power)
	_check("weather_sprites", view._weather.visible and view._weather._sprites.size() == 70, view._weather._sprites.size())
	# 存读档保留，换地图不清
	var saved := XSave.save(1) and XSave.load_slot(1)
	_check("save_load", saved)
	if saved:
		var t: XScreenFx = XState.current.screen
		_check("save_kept", t.tone == [68.0, -34.0, -34.0, 170.0] and t.weather_type == "snow" and t.weather_power == 7.0, t.to_dict())
	map = get_tree().current_scene
	await map.transfer(4, 14, 22, 2)
	map = await _wait_map(4)
	_check("transfer_keeps", map != null and XState.current.screen.weather_type == "snow" and map.screen_fx._weather.visible)
	# 关掉：236 none 渐弱 60 帧后类型归 none、粒子清空；223 回零
	var off_list := [_cmd(223, [[0, 0, 0, 0], 60, true]), _cmd(236, ["none", 7, 60, true]), _cmd(0, [])]
	await MVInterpreter.new(map, 4, 0, off_list).run()
	await _frames(3)
	_check("cleared", XState.current.screen.weather_type == "none" and not XState.current.screen.has_tone())
	_check("view_cleared", not map.screen_fx._tone_rect.visible and not map.screen_fx._weather.visible, map.screen_fx._weather._sprites.size())
	await _finish()


func _finish() -> void:
	for player in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_screen_fx", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
