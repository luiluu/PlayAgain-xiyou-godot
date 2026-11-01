extends Node
## 地图事件状态随存档（XState.map_events／MVEvent.save_state）：对照 tests/fixtures/save_events_oracle.json（mv_oracle/save_events_probe.cjs）。
## 原版同版本读档不重设地图，Map004（切片保留的事件）里改过的事件读档后原样：72 位置＋朝向、7 强制路线走到一半（索引、仍在强制）、
## 73 路线改的不透明度／穿透／图像、65 临时消除、36 自开关 A 换页。重制照同样操作，真实 XSave 存读档后重开地图场景逐项比。
## 另查：旧档没有 mapEvents 时事件回初始；换到别的地图再回来回初始（原版 Game_Map.setup）；读档后路线接着走完。
## 强制路线跳跃到一半存读档（沙僧第六期 S1／P2）：原版 _jumpCount／_jumpPeak 随 JsonEx 进存档（参照 eventKeys），读档后仍在空中。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const ORACLE := "res://tests/fixtures/save_events_oracle.json"
const TIMEOUT_MS := 60000
const WaitBudget := preload("res://tests/wait_budget.gd")  # 墙钟与帧数都过了才算超时（tools30）
const IDS := [7, 36, 65, 72, 73]

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
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while t0.waiting():
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
			"erased": e.erased, "forcing": e.is_route_forcing(), "routeIndex": e._route_index if e.is_route_forcing() else -1, "opacity": e.opacity,
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
	_event(map, 72).locate(22, 15)
	_event(map, 72).set_direction(8)
	_event(map, 7).force_move_route({"list": [_cmd(1), _cmd(1), _cmd(1), _cmd(1), _cmd(0)], "repeat": false, "skippable": false, "wait": false})
	_event(map, 73).force_move_route({"list": [_cmd(42, [128]), _cmd(37), _cmd(41, ["People1", 3]), _cmd(0)], "repeat": false, "skippable": false, "wait": false})
	await _frames(40)
	map.erase_event(65)
	s.set_self_switch(4, 36, "A", true)
	_event(map, 36).refresh()
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
	_check("setup.changed", before["72"].x == 22 and before["72"].direction == 8 and before["7"].forcing and before["7"].routeIndex > 0
		and before["73"].opacity == 128 and before["73"].characterName == "People1" and before["73"].through and before["65"].erased and before["36"].selfA
		and before["36"].page == int(ref.before["36"]._pageIndex) and before["36"].page != int(ref.initial["36"]._pageIndex), before)
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
	_check("legacy.initial_position", legacy.get("72", {}).get("x") == int(map.map_data.events[72].x) and not legacy.get("7", {}).get("forcing", true)
		and legacy.get("73", {}).get("opacity") == 255, legacy)
	_check("legacy.erased_and_self_switch_kept", legacy.get("65", {}).get("erased") == true and legacy.get("36", {}).get("selfA") == true, legacy)

	# 换到别的地图再回来：Game_Map.setup 重建，改过的事件回初始
	map = await _setup()
	await map.transfer(55, 10, 17, 2)
	map = await _wait_map(55)
	await map.transfer(4, 14, 14, 2)
	map = await _wait_map(4)
	var back := _snap(map) if map != null else {}
	_check("other_map.reset", back.get("72", {}).get("x") == int(map.map_data.events[72].x) and back.get("73", {}).get("opacity") == 255
		and not back.get("65", {}).get("erased", true), back)
	await _check_jump_save()
	_finish()


static func _jump_snap(e: MVEvent) -> Dictionary:
	return {"count": e._jump_count, "peak": e._jump_peak, "height": e.jump_height(), "jumping": e.is_jumping(),
		"forcing": e.is_route_forcing(), "routeIndex": e._route_index, "grid": [e.grid.x, e.grid.y], "real": [e.real.x, e.real.y]}


## 读档重开地图时先停住事件的帧更新（地图场景开好要过几帧），好逐项比存档那一刻的跳跃状态
func _freeze_event(node: Node) -> void:
	if node is MVEvent:
		node.process_mode = Node.PROCESS_MODE_DISABLED


func _load_frozen(slot: int) -> XMapScene:
	get_tree().node_added.connect(_freeze_event)
	var ok := XSave.load_slot(slot)
	var map: XMapScene = await _open(4) if ok else null
	get_tree().node_added.disconnect(_freeze_event)
	return map


## Map004 事件 7 强制路线跳 (0,2)，推进 4 帧：count 12、peak 8（10＋2－速度 4）、高 24、在空中、路线索引 1
func _check_jump_save() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	s.x = 14
	s.y = 14
	var map := await _open(4)
	var e7 := _event(map, 7) if map != null else null
	if not _check("jump.setup", e7 != null):
		return
	e7.process_mode = Node.PROCESS_MODE_DISABLED
	var start := e7.grid
	e7.force_move_route({"list": [_cmd(14, [0, 2]), _cmd(0)], "repeat": false, "skippable": false, "wait": false})
	for i in 4:
		e7.update_character()
	var before := _jump_snap(e7)
	_check("jump.before", before.count == 12 and before.peak == 8 and is_equal_approx(before.height, 24.0) and before.jumping
		and before.forcing and before.routeIndex == 1, before)
	_check("jump.save", XSave.save(1))
	map = await _load_frozen(1)
	e7 = _event(map, 7) if map != null else null
	var after := _jump_snap(e7) if e7 != null else {}
	_check("jump.load", JSON.stringify(after) == JSON.stringify(before), [after, before])
	# 放开后接着在空中走完：再 12 帧落地，路线结束
	if e7 != null:
		e7.process_mode = Node.PROCESS_MODE_INHERIT
		await _frames(20)
		_check("jump.lands", not e7.is_jumping() and not e7.is_route_forcing() and e7.grid == start + Vector2i(0, 2)
			and e7.real == Vector2(e7.grid), _jump_snap(e7))
	# 旧档的事件状态没有跳跃字段：读档后不在跳跃（位置、路线照旧）
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(1)))
	var saved7: Dictionary = d.mapEvents.events["7"]
	for k in ["jumpPeak", "jumpCount", "stopCount", "animeCount", "moveWait"]:
		saved7.erase(k)
	var f := FileAccess.open(XSave.path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	map = await _load_frozen(1)
	e7 = _event(map, 7) if map != null else null
	var legacy := _jump_snap(e7) if e7 != null else {}
	_check("jump.legacy_not_jumping", legacy.get("jumping") == false and legacy.get("count") == 0 and legacy.get("peak") == 0
		and legacy.get("forcing") == true and legacy.get("routeIndex") == 1, legacy)


func _finish() -> void:
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_save_events", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)
