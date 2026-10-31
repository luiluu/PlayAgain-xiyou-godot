extends Node
## 飞艇状态与存档（天之上飞艇方案甲一）：
## - 开局与旧档缺字段：飞艇按 System 起始位置 Map186 (50,49)、朝向 4、Vehicle 第 3 格、BGM 用 System 的；玩家走路（Game_Vehicle.loadSystemSettings）；
## - 真实地图场景里跑写 202 的原版事件，飞艇停到事件里写的图与坐标（原版 Game_Vehicle.setLocation 只改图号与坐标）：
##   楼层回大厅 Map003 EV4 → 69 (30,25)；CE240 恰兰吉尔 → 69 (65,56)；CE1002 神魔战场 → 186 (50,49)；CE10 回到大厅 → 69 (30,25)；
## - 202 变量指定、323 改图像、140 改 BGM；条件分支 13（$gamePlayer.vehicle() === $gameMap.vehicle(p1)）：走路为假、在飞艇上只有 2 为真；
## - 原版参照 airship_probe（tests/fixtures/airship_oracle.json）：新局三种载具、条件 13、四处事件 202 的落点、变量指定＋323＋140 逐项比；
## - XSave 真存档读档往返一致。上下飞艇、飞行、画面是甲二、甲三的事，本专项不碰。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 120000
const SAVE_DIR := "user://test_airship_state"
const FIXTURE := "res://tests/fixtures/airship_oracle.json"
var ref := {}

var results: Array = []
var s: XState


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	# 换场景（传送）时测试节点不能挂在当前场景下，挂到根节点
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _wait_map(map_id: int) -> XMapScene:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var m = get_tree().current_scene
		if m is XMapScene and m.map_id == map_id and m.player != null and not m.busy:
			return m
		await get_tree().process_frame
	return null


func _open(map_id: int, x: int, y: int) -> XMapScene:
	s.map_id = map_id
	s.x = x
	s.y = y
	get_tree().change_scene_to_file(MAP_SCENE)
	return await _wait_map(map_id)


static func _cmd(code: int, parameters: Array, indent := 0) -> Dictionary:
	return {"code": code, "indent": indent, "parameters": parameters}


func _at(tag: String, map_id: int, x: int, y: int) -> void:
	var v := XState.current.vehicle(2)
	_check(tag, int(v.mapId) == map_id and int(v.x) == x and int(v.y) == y and int(v.direction) == 4, v)


## 在当前地图上以公共事件身份跑一张列表到结束（201 之后的 202 也跑完），换图由调用处 _wait_map 接
func _run_list(map: XMapScene, list: Array, answers := []) -> void:
	XMessageBox.auto_answers = answers.duplicate()
	await MVInterpreter.new(map, map.map_id, 0, list).run()


func _run_event(map: XMapScene, id: int, answers: Array) -> void:
	for e in map.events:
		if e.event_id == id:
			XMessageBox.auto_answers = answers.duplicate()
			await map.run_event(e)
			return
	_check("map%d_event%d_present" % [map.map_id, id], false)


## 参照的载具字段（Game_Vehicle 的 _mapId 等）与重制载具字典逐项比；BGM 两边都过一次 JSON
func _same_vehicle(v: Dictionary, o: Dictionary) -> bool:
	for k in ["mapId", "x", "y", "direction", "characterIndex", "altitude"]:
		if int(v.get(k, -1)) != int(o[k]):
			return false
	return str(v.characterName) == str(o.characterName) and bool(v.driving) == bool(o.driving) \
		and JSON.stringify(JSON.parse_string(JSON.stringify(v.bgm))) == JSON.stringify(o.bgm)


func _oracle(id: String) -> Variant:
	for c in ref.get("cases", []):
		if c.id == id:
			return c.observed if c.errors.is_empty() else null
	return null


func _at_oracle(tag: String, id: String) -> void:
	var o = _oracle(id)
	_check(tag + "_oracle", o != null and _same_vehicle(XState.current.vehicle(2), o[-1].after), [XState.current.vehicle(2), o])


func _defaults() -> void:
	ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_check("oracle_source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	s = XState.new_game_blank()
	var o0 = _oracle("state.new")
	_check("new_oracle", o0 != null and s.vehicle_type == str(o0.vehicleType) and range(3).all(func(i): return _same_vehicle(s.vehicle(i), o0.vehicles[i])), [s.vehicles, o0])
	_check("new_walk", s.vehicle_type == "walk", s.vehicle_type)
	var v := s.vehicle(2)
	_check("new_airship", v.mapId == 186 and v.x == 50 and v.y == 49 and v.direction == 4 and v.characterName == "Vehicle" and v.characterIndex == 3 and v.bgm == null and v.altitude == 0 and v.driving == false, v)
	_check("new_boat_ship", s.vehicle(0).mapId == 0 and s.vehicle(1).characterIndex == 1 and s.vehicle("airship") == v and s.vehicle("walk").is_empty() and s.vehicle(3).is_empty())
	# 旧档：没有 vehicles／vehicleType；半截的飞艇字典按缺省补
	var d := s.to_dict()
	d.erase("vehicles")
	d.erase("vehicleType")
	var old := XState.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check("old_save_default", old.vehicle_type == "walk" and old.vehicles.size() == 3 and old.vehicle(2) == XState.default_vehicle(2), old.vehicles)
	d["vehicles"] = [{}, {}, {"mapId": 69, "x": 3}]
	d["vehicleType"] = "bogus"
	old = XState.from_dict(JSON.parse_string(JSON.stringify(d)))
	var p := old.vehicle(2)
	_check("partial_save", old.vehicle_type == "walk" and p.mapId == 69 and p.x == 3 and p.y == 49 and p.characterIndex == 3 and typeof(p.mapId) == TYPE_INT, p)


func _conditions() -> void:
	var core := MVEventCore.new()
	XState.current.vehicle_type = "walk"
	_check("cond13_walk", [0, 1, 2].all(func(i): return not core._condition([13, i])))
	XState.current.vehicle_type = "airship"
	_check("cond13_airship", core._condition([13, 2]) and not core._condition([13, 0]) and not core._condition([13, 1]))
	var oc = _oracle("state.cond13")
	XState.current.vehicle_type = "walk"
	var walk := [0, 1, 2].map(func(i): return core._condition([13, i]))
	XState.current.vehicle_type = "airship"
	var air := [0, 1, 2].map(func(i): return core._condition([13, i]))
	_check("cond13_oracle", oc != null and walk == oc.walk and air == oc.airship, [walk, air, oc])
	XState.current.vehicle_type = "walk"


func _run() -> void:
	XSave.dir_override = SAVE_DIR
	XMessageBox.auto = true
	_defaults()
	s = XState.new_game(3, 1, [8, 9, 10])
	_conditions()
	_at("start_186", 186, 50, 49)
	s.set_variable(21, 0)
	# 楼层回大厅：Map003 EV4（站在 (30,31) 选「传送」）
	var map := await _open(3, 30, 31)
	if _check("map3", map != null):
		await _run_event(map, 4, [0])
		map = await _wait_map(4)
		_check("ev4_to_hub", map != null)
		_at("floor_return_69_30_25", 69, 30, 25)
		_at_oracle("floor_return_69_30_25", "state.event.map3.ev4")
	# CE240 恰兰吉尔 → Map071；飞艇停 69 (65,56)
	if map != null:
		await _run_list(map, XDB.rec("CommonEvents", 240).list)
		map = await _wait_map(71)
		_check("ce240_to_71", map != null)
		_at("ce240_69_65_56", 69, 65, 56)
		_at_oracle("ce240_69_65_56", "state.event.ce240")
	# CE1002 神魔战场 → Map186 (46,51)；飞艇停 186 (50,49)
	if map != null:
		await _run_list(map, XDB.rec("CommonEvents", 1002).list)
		map = await _wait_map(186)
		_check("ce1002_to_186", map != null)
		_at("ce1002_186_50_49", 186, 50, 49)
		_at_oracle("ce1002_186_50_49", "state.event.ce1002")
	# CE10 回到大厅 → Map004；飞艇停 69 (30,25)
	if map != null:
		await _run_list(map, XDB.rec("CommonEvents", 10).list)
		map = await _wait_map(4)
		_check("ce10_to_hub", map != null)
		_at("ce10_69_30_25", 69, 30, 25)
		_at_oracle("ce10_69_30_25", "state.event.ce10")
	if map == null:
		_finish()
		return
	# 在飞艇上时 CE240 被条件 13 拦住：不换图、不挪飞艇（原版弹「正在乘坐飞艇」提示）
	s.vehicle_type = "airship"
	await _run_list(map, XDB.rec("CommonEvents", 240).list, [0])
	_check("ce240_blocked_in_airship", get_tree().current_scene == map and map.map_id == 4, map.map_id)
	_at("blocked_no_move", 69, 30, 25)
	s.vehicle_type = "walk"
	# 202 变量指定、323、140；不认识的载具编号不报错不改
	s.set_variable(901, 186)
	s.set_variable(902, 12)
	s.set_variable(903, 34)
	var bgm := {"name": "Theme_Amara", "pan": 0, "pitch": 100, "volume": 80}
	await _run_list(map, [_cmd(202, [2, 1, 901, 902, 903]), _cmd(323, [2, "SF_Vehicle", 5]), _cmd(140, [2, bgm]), _cmd(202, [7, 0, 1, 1, 1]), _cmd(0, [])])
	_at("set_by_vars", 186, 12, 34)
	var v := s.vehicle(2)
	_check("image_323", v.characterName == "SF_Vehicle" and v.characterIndex == 5, v)
	_check("bgm_140", v.bgm == bgm and v.bgm != null, v.bgm)
	_check("other_vehicles_untouched", s.vehicle(0) == XState.default_vehicle(0) and s.vehicle(1) == XState.default_vehicle(1))
	var ov = _oracle("state.vars")
	_check("vars_oracle", ov != null and range(3).all(func(i): return _same_vehicle(s.vehicle(i), ov.vehicles[i])), [s.vehicles, ov])
	# 存读档往返
	var before = JSON.parse_string(JSON.stringify(s.vehicles))
	if _check("save", XSave.save(1)) and _check("load", XSave.load_slot(1)):
		var after = JSON.parse_string(JSON.stringify(XState.current.vehicles))
		_check("roundtrip_vehicles", after == before, [before, after])
		_check("roundtrip_type", XState.current.vehicle_type == "walk")
		_check("roundtrip_int", typeof(XState.current.vehicle(2).x) == TYPE_INT)
	_finish()


func _finish() -> void:
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	for f in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR.path_join(f))
	DirAccess.remove_absolute(SAVE_DIR)
	XMessageBox.auto_answers = []
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
