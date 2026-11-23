extends Node

const TestEnv := preload("res://tests/xiyou_test_env.gd")
const SaveKit := preload("res://tests/lib/tq_save_kit.gd")
const SCENE := "xiyou_lobby_stage3_adjacent"
const DOORS := {
	132: Vector2i(8, 4),
	187: Vector2i(2, 9),
	195: Vector2i(42, 14),
	18: Vector2i(18, 8),
	40: Vector2i(4, 7),
	224: Vector2i(9, 18),
	225: Vector2i(38, 32),
}
const ORIGINAL_A1 := {
	187: "fsm_C_Inside01_A1",
	195: "fsm_Town01_A1",
	225: "tgw_A1",
}

var _pass := 0
var _total := 0
var _out := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_run.call_deferred()


func _check(label: String, passed: bool) -> void:
	_total += 1
	_pass += int(passed)
	if not passed:
		push_error(label)


func _open(id: int, stage: int, tianqi := false) -> XMapScene:
	XLobbyCorruption.STAGE_OVERRIDE = stage
	var state := SaveKit.new_game() if tianqi else XState.new_game(3, 1, [8, 9, 10])
	state.map_id = id
	var door: Vector2i = DOORS[id]
	state.x = door.x
	state.y = door.y
	state.set_variable(20, 33)
	# 截图按已走过前段楼层的存档准备，避开进图补发通知。
	if _out != "":
		state.flags[XStarburstBooks.FLAG] = {"8": 1, "18": 1}
	XState.current = state
	var map := XMapScene.new()
	add_child(map)
	return map


func _snapshot(map: XMapScene) -> Dictionary:
	var passage := PackedByteArray()
	for y in map.lower.height:
		for x in map.lower.width:
			for direction in [2, 4, 6, 8]:
				passage.append(int(map.lower.is_passable(x, y, direction)))
	var events := []
	for event in map.events:
		events.append([event.event_id, event.grid, event.page_index, event.data])
	return {"passage": passage, "events": events, "tiles": map.lower.data, "flags": map.lower.flags}


func _sheets(map: XMapScene) -> Array:
	return [map.lower.sheets.duplicate(), map.upper.sheets.duplicate(), map.upper.visible]


func _art(map: XMapScene) -> XLobbyStage3Adjacent:
	return map.lower.get_node_or_null("Stage3Adjacent") as XLobbyStage3Adjacent


func _guarded_map(id: int, stage: int, expect_sheets: Array, tianqi := false) -> Array:
	var map := _open(id, stage, tianqi)
	var label := "Map%03d stage=%d tianqi=%s" % [id, stage, tianqi]
	_check(label + " no overlay", _art(map) == null)
	var sheets := _sheets(map)
	if not expect_sheets.is_empty():
		_check(label + " original sheets and layer visibility", sheets == expect_sheets)
	map.queue_free()
	await get_tree().process_frame
	return sheets


func _active_map(id: int) -> void:
	var map := _open(id, 3)
	var art := _art(map)
	var label := "Map%03d" % id
	_check(label + " mounted", art != null)
	if art == null:
		map.queue_free()
		await get_tree().process_frame
		return
	var ground := art.get_node("Ground") as Sprite2D
	var roots := art.get_node("Roots") as Sprite2D
	var front := art.get_node_or_null("Foreground") as Sprite2D
	_check(label + " full-size ground", ground.texture.get_size() == Vector2(map.lower.width, map.lower.height) * MVTiles.TILE_SIZE)
	_check(label + " roots above ground and below events", ground.z_index < roots.z_index and roots.z_index < 0)
	_check(label + " upper tile order", front.z_index == map.upper.z_index and not map.upper.visible if front else map.upper.visible)
	if ORIGINAL_A1.has(id):
		_check(label + " replacement A1 for native animation",
			map.lower.sheets[0].resource_path.ends_with("%s_a1.png" % label)
			and map.upper.sheets[0].resource_path.ends_with("%s.png" % ORIGINAL_A1[id]))
	var former := _snapshot(map)
	XLobbyStage3Adjacent.ENABLED = false
	var door: Vector2i = DOORS[id]
	await map.load_map(4, 14, 25, 2)
	await get_tree().process_frame
	_check(label + " released after transfer", not is_instance_valid(art))
	await map.load_map(id, door.x, door.y, 2)
	_check(label + " switch restores originals", _art(map) == null and map.upper.visible)
	var originals := _sheets(map)
	if ORIGINAL_A1.has(id):
		_check(label + " original A1 restored", map.lower.sheets[0].resource_path.ends_with("%s.png" % ORIGINAL_A1[id]))
	_check(label + " every passage direction and event position preserved", _snapshot(map) == former)
	map.queue_free()
	await get_tree().process_frame
	XLobbyStage3Adjacent.ENABLED = true

	await _guarded_map(id, 1, originals)
	await _guarded_map(id, 2, originals)
	var tianqi_sheets := await _guarded_map(id, 1, [], true)
	await _guarded_map(id, 3, tianqi_sheets, true)


func _screenshots() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	XMessageBox.auto = true
	for id in DOORS:
		var map := _open(id, 3)
		for frame in 36:
			await get_tree().process_frame
		map.message.hide()
		for popup in XAchievementPopup._stack:
			if is_instance_valid(popup):
				popup.hide()
		await RenderingServer.frame_post_draw
		var name := "Map%03d_stage3.png" % id
		var error := get_viewport().get_texture().get_image().save_png(_out.path_join(name))
		_check(name, error == OK and _art(map) != null)
		map.queue_free()
		await get_tree().process_frame


func _run() -> void:
	TestEnv.isolate(SCENE)
	if _out != "" and DisplayServer.get_name() != "headless":
		await _screenshots()
	else:
		for id in DOORS:
			await _active_map(id)
		var map := _open(187, 4)
		_check("stage four stays active", _art(map) != null)
		await map.load_map(204, 1, 1, 2)
		_check("second-hop map is excluded", _art(map) == null and map.upper.visible)
		map.queue_free()
		await get_tree().process_frame
	XLobbyCorruption.STAGE_OVERRIDE = 0
	print("TEST_RESULT=" + JSON.stringify({"passed": _pass, "total": _total}))
	get_tree().quit.call_deferred(0 if _pass == _total else 1)
