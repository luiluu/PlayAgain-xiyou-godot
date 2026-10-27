extends Node
## 地图事件状态随存档（XState.map_events／MVEvent.save_state）：对照 tests/fixtures/save_events_oracle.json（mv_oracle/save_events_probe.cjs）。
## 原版同版本读档不重设地图，Map004 里改过的事件读档后原样：事件 6 位置＋朝向、事件 7 强制路线走到一半（索引、仍在强制）、
## 事件 10 路线改的不透明度与图像、事件 14 临时消除、事件 1 自开关 A 的页。重制照同样操作，真实 XSave 存读档后重开地图场景逐项比。
## 另查：旧档没有 mapEvents 时事件回初始；换到别的地图再回来回初始（原版 Game_Map.setup）；读档后路线接着走完。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const ORACLE := "res://tests/fixtures/save_events_oracle.json"
const TIMEOUT_MS := 60000
const IDS := [1, 6, 7, 10, 14]

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
		print("FAIL ", name, " ", JSON.stringify(detail).left(2000))
	return ok


func _wait_map(map_id: int) -> XMapScene:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var m = get_tree().current_scene
		if m is XMapScene and m.map_id == map_id and m.player != null and not m.busy:
			return m
		await get_tree().process_frame
	return null


func _open(map_id: int) -> XMapScene:
	get_tree().change_scene_to_file(MAP_SCENE)
	return await _wait_map(map_id)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


static func _event(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


static func _cmd(code: int, params := []) -> Dictionary:
	return {"code": code, "parameters": params, "indent": null}


## 玩家可感知的字段（与参照的字段对应：_x/_y/_direction/_pageIndex/_erased/_moveRouteForcing/_moveRouteIndex/_opacity/_characterName…）
static func _snap(map: XMapScene) -> Dictionary:
	var out := {}
	for id in IDS:
		var e := _event(map, id)
		out[str(id)] = {} if e == null else {"x": e.grid.x, "y": e.grid.y, "direction": e.direction, "page": e.page_index,
			"erased": e.erased, "forcing": e.is_route_forcing(), "routeIndex": e._route_index, "opacity": e.opacity,
			"characterName": e.character_name, "characterIndex": e.character_index, "through": e.through,
			"selfA": XState.current.self_switch(4, id, "A")}
	return out


## 新局站在 Map004，照探针改五个事件；返回改后的快照
func _setup() -> XMapScene:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	s.x = 14
	s.y = 14
	var map := await _open(4)
	if map == null:
		return null
	_event(map, 6).locate(7, 9)
	_event(map, 6).set_direction(4)
	_event(map, 7).force_move_route({"list": [_cmd(1), _cmd(1), _cmd(1), _cmd(1), _cmd(0)], "repeat": false, "skippable": false, "wait": false})
	_event(map, 10).force_move_route({"list": [_cmd(42, [128]), _cmd(37), _cmd(41, ["People1", 3]), _cmd(0)], "repeat": false, "skippable": false, "wait": false})
	await _frames(40)
	map.erase_event(14)
	s.set_self_switch(4, 1, "A", true)
	_event(map, 1).refresh()
	return map


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_save_events"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	var ref = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	_check("oracle_clean", ref is Dictionary and ref.errors.is_empty() and ref.saveVersionMatches, ref.get("errors") if ref is Dictionary else ref)
	# 参照：同版本读档每个字段都还原；版本号不同同图重载时改过的字段回初始（自开关另存，不变）
	for id in IDS:
		var k := str(id)
		_check("oracle.%s.kept" % k, JSON.stringify(ref.loaded[k]) == JSON.stringify(ref.before[k]))
		_check("oracle.%s.changed" % k, JSON.stringify(ref.before[k]) != JSON.stringify(ref.initial[k]))
	_check("oracle.7.mid_route", bool(ref.before["7"]._moveRouteForcing) and int(ref.before["7"]._moveRouteIndex) > 0, ref.before["7"])

	var map := await _setup()
	if not _check("map004_loaded", map != null and IDS.all(func(id): return _event(map, id) != null)):
		return _finish()
	var initial_7 := Vector2i(int(map.map_data.events[7].x), int(map.map_data.events[7].y)) if map.map_data.events.size() > 7 and map.map_data.events[7] != null else Vector2i.ZERO
	var before := _snap(map)
	_check("setup.changed", before["6"].x == 7 and before["6"].direction == 4 and before["7"].forcing and before["7"].routeIndex > 0
		and before["10"].opacity == 128 and before["10"].characterName == "People1" and before["14"].erased and before["1"].selfA, before)
	# 真存读档，重开地图场景（Scene_Load → Scene_Map，不重设地图）
	_check("save_load", XSave.save(1) and XSave.load_slot(1))
	map = await _open(4)
	var after := _snap(map) if map != null else {}
	for id in IDS:
		_check("load.%d" % id, JSON.stringify(after.get(str(id))) == JSON.stringify(before[str(id)]), [after.get(str(id)), before[str(id)]])
	# 读档后强制路线接着走完：一共向下 4 格
	await _frames(240)
	var e7 := _event(map, 7) if map != null else null
	_check("load.route_finishes", e7 != null and not e7.is_route_forcing() and e7.grid == initial_7 + Vector2i(0, 4), [e7.grid if e7 else null, initial_7])

	# 旧档没有 mapEvents：事件回初始（自开关、临时消除照旧随档）
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(1)))
	d.erase("mapEvents")
	var f := FileAccess.open(XSave.path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	_check("legacy_load", XSave.load_slot(1))
	map = await _open(4)
	var legacy := _snap(map) if map != null else {}
	_check("legacy.initial_position", legacy.get("6", {}).get("x") == int(map.map_data.events[6].x) and not legacy.get("7", {}).get("forcing", true)
		and legacy.get("10", {}).get("opacity") == 255, legacy)
	_check("legacy.erased_and_self_switch_kept", legacy.get("14", {}).get("erased") == true and legacy.get("1", {}).get("selfA") == true, legacy)

	# 换到别的地图再回来：Game_Map.setup 重建，改过的事件回初始
	map = await _setup()
	await map.transfer(55, 10, 17, 2)
	map = await _wait_map(55)
	await map.transfer(4, 14, 14, 2)
	map = await _wait_map(4)
	var back := _snap(map) if map != null else {}
	_check("other_map.reset", back.get("6", {}).get("x") == int(map.map_data.events[6].x) and back.get("10", {}).get("opacity") == 255
		and not back.get("14", {}).get("erased", true), back)
	_finish()


func _finish() -> void:
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_save_events", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
