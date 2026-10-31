extends Node
## 飞艇图像与表现（天之上飞艇方案甲三，原版 Game_Vehicle.screenY／shadowX／shadowY／shadowOpacity、Spriteset_Map.createShadow／updateShadow）：
## - 停着：System 的默认图（Vehicle 第 3 格）、高度 0、贴地画、在角色下方、影子透明度 0；
## - 上艇：逐帧采样，高度每帧最多 +1，精灵上移＝高度、影子在不算高度的位置（行走图上移 6）、透明度 255×高度÷48、
##   升空后在上层图块之上（screenZ 5 > 上层图块 4）、影子再在飞艇之上（z 6），到 48 才能飞、原地踏步；
## - 飞行中鼠标点前方一格是飞过去（triggerTouchActionD2 只查事件），点脚下才降落（D1）；
## - 降落：逐帧采样高度每帧最多 −1、精灵与影子一致，到 0 回角色下方；
## - 指令 323 换图（改造包）：精灵照新图画，存读档后图还对；带 ! 的物件图（萌物）不上移 6，影子也跟着；
## - 每帧画面另按原版参照的同高度一行比：精灵上移、影子位置、透明度（shadowOpacity÷255）；升到 48、降到 0 的逐帧序列与参照相同；
## - 空中存读档、升空中存读档、降落中存读档：读回高度与存时一样，画面与高度一致，接着升或降到底。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const SAVE_DIR := "user://test_airship_view"
const WAIT := 6000
const TS := MVTiles.TILE_SIZE

var results: Array = []
var s: XState
var map: XMapScene
## --out=<目录>：在上艇、飞行、降落三处截图（对照原版，见交付单 claude_wukong-airship3；无头运行时不截）
var out_dir := ""
## 原版参照 airship_probe（view.rows.walk／object：高度 0～48 每档的精灵、影子偏移与透明度；view.rise_fall：升降逐帧高度）
const FIXTURE := "res://tests/fixtures/airship_oracle.json"
var ref := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
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


## 同 xiyou_airship_fly._fast_clock
func _fast_clock(on: bool) -> void:
	if not has_meta("clock"):
		set_meta("clock", [OS.low_processor_usage_mode_sleep_usec, Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame])
	var orig: Array = get_meta("clock")
	OS.low_processor_usage_mode_sleep_usec = 0 if on else orig[0]
	Engine.physics_ticks_per_second = 600 if on else orig[1]
	Engine.max_physics_steps_per_frame = 64 if on else orig[2]
	Engine.time_scale = 30.0 if on else 1.0


func _until(cond: Callable, limit := WAIT) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _wait_map(id: int) -> XMapScene:
	var ok := await _until(func():
		var m = get_tree().current_scene
		return m is XMapScene and m.map_id == id and m.player != null and is_instance_valid(m.player) and not m.busy)
	map = get_tree().current_scene if ok else null
	return map


func _open(id: int, x: int, y: int) -> XMapScene:
	s.map_id = id
	s.x = x
	s.y = y
	get_tree().change_scene_to_file(MAP_SCENE)
	return await _wait_map(id)


func _airship() -> Dictionary:
	return XState.current.vehicle("airship")


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _press() -> void:
	await _until(func(): return not map.busy)
	await map._on_action()


func _oracle(id: String):
	for c in ref.get("cases", []):
		if c.id == id:
			return c.observed if c.errors.is_empty() else null
	return null


## 原版同高度一行：Game_Vehicle.screenY 相对停地上移 dy、影子在 shadowY（含行走图 shiftY）、透明度 shadowOpacity
func _row_ok(a, sh, ground: Vector2, alt: int) -> bool:
	var o = _oracle("view.rows.object" if a.is_object() else "view.rows.walk")
	if o == null or alt < 0 or alt >= o.rows.size():
		return false
	var row: Dictionary = o.rows[alt]
	var shift := float(o.parked.shiftY)
	return a.position.is_equal_approx(ground + Vector2(0, float(row.dy))) \
		and (a.position + sh.position).is_equal_approx(ground + Vector2(float(row.shadowDx), float(row.shadowDy) - shift)) \
		and is_equal_approx(sh.modulate.a, float(row.shadowOpacity) / 255.0)


## 画面与飞艇状态一致：精灵上移＝高度、影子在原位（行走图上移 6，物件 0）、透明度＝高度÷48、层级
func _view(tag: String) -> bool:
	var v := _airship()
	var a := map.airship
	var sh := map.airship_shadow
	var alt := int(v.altitude)
	var at := a.real + (a.tilemap.loop_shift(a.real) if a.tilemap.loop_x or a.tilemap.loop_y else Vector2.ZERO)
	var ground := Vector2(at.x * TS + TS / 2.0, at.y * TS + TS)
	var shift := 0.0 if a.is_object() else 6.0
	var z_ok := a.z_index == -1 if alt <= 0 else (a.z_index == MVCharacter.ABOVE_UPPER_Z and a.z_index > map.upper.z_index and sh.z_index > a.z_index)
	return _check(tag, a.altitude == alt and a.position.is_equal_approx(ground - Vector2(0, alt))
		and (a.position + sh.position).is_equal_approx(ground - Vector2(0, shift)) and a.real.is_equal_approx(map.player.real) and map.followers.all(func(f): return f.transparent == map.player.transparent) and is_equal_approx(sh.modulate.a, alt / 48.0)
		and sh.texture != null and z_ok and _row_ok(a, sh, ground, alt) and a.character_name == str(v.characterName) and a.character_index == int(v.characterIndex),
		[alt, a.altitude, a.position, ground, sh.position, sh.modulate.a, a.z_index, sh.z_index, a.character_name, a.character_index, v.characterName])


## 逐帧采样直到 cond：每帧高度变化不超过 step 的方向、每帧画面一致；返回采样到的高度序列
func _sample(tag: String, step: int, cond: Callable, shot_at := -1, shot_name := "") -> Array:
	var seen: Array = [int(_airship().altitude)]
	var ok := true
	for i in WAIT:
		await get_tree().physics_frame
		var alt := int(_airship().altitude)
		if not (alt - int(seen[-1]) in [0, step]):
			ok = false
		if alt != int(seen[-1]):
			seen.append(alt)
			if alt == shot_at:
				_shot(shot_name)
		if not _view(tag + "_frame") :
			ok = false
			break
		if cond.call():
			break
	# 采样帧的逐帧检查只在失败时留条目，免得把几十帧都算成断言
	results = results.filter(func(r): return r.name != tag + "_frame" or not r.passed)
	_check(tag + "_step", ok, seen)
	return seen


func _get_on(tag: String) -> void:
	await _press()
	_check(tag + "_getting_on", s.vehicle_type == "airship" and not map.vehicle_can_move(), _airship())
	var seen := await _sample(tag + "_rise", 1, func(): return map.vehicle_can_move(), 24, tag + "_rise_24")
	_check(tag + "_rise_0_to_48", seen.front() == 0 and seen.back() == 48 and seen.size() == 49, seen)
	var rf = _oracle("view.rise_fall")
	_check(tag + "_rise_oracle", rf != null and seen == rf.rise.map(func(v): return int(v)) and int(_oracle("view.rows.walk").maxAltitude) == XMapScene.AIRSHIP_MAX_ALTITUDE, [seen, rf])
	_check(tag + "_flying", map.vehicle_can_move() and map.airship.step_anime and map.airship.priority_type == 2, _airship())
	await _view(tag + "_high")


func _land(tag: String) -> void:
	await _press()
	_check(tag + "_landing", map._vehicle_getting_off, _airship())
	var seen := await _sample(tag + "_fall", -1, func(): return s.vehicle_type == "walk")
	_check(tag + "_fall_to_0", seen.front() >= 47 and seen.back() == 0 and seen.size() == seen.front() + 1, seen)
	# 参照从 48 降起；重制按下降键那一帧可能已降了一格，比参照序列的对应尾段
	var rf = _oracle("view.rise_fall")
	var want: Array = rf.fall.map(func(v): return int(v)) if rf != null else []
	_check(tag + "_fall_oracle", rf != null and seen == want.slice(want.size() - seen.size()), [seen, want])
	_check(tag + "_parked", map.airship.priority_type == 0 and map.airship.z_index == -1 and is_zero_approx(map.airship_shadow.modulate.a) and not map.airship.step_anime)


## 存档→读档→重建地图；返回读回的地图
func _save_load(tag: String, id: int) -> bool:
	if not (_check(tag + "_save", XSave.save(1)) and _check(tag + "_load", XSave.load_slot(1))):
		return false
	s = XState.current
	get_tree().change_scene_to_file(MAP_SCENE)
	return _check(tag + "_reload", await _wait_map(id) != null)


## 存档后读档：读到 XState 时高度与存时一样（还没重建地图、没走帧）
func _save_load_altitude(tag: String, id: int) -> int:
	var before := int(_airship().altitude)
	if not (_check(tag + "_save", XSave.save(1)) and _check(tag + "_load", XSave.load_slot(1))):
		return -1
	s = XState.current
	_check(tag + "_altitude_kept", int(_airship().altitude) == before, [before, _airship()])
	get_tree().change_scene_to_file(MAP_SCENE)
	_check(tag + "_reload", await _wait_map(id) != null)
	return before


func _run() -> void:
	ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_check("oracle_source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	XSave.dir_override = SAVE_DIR
	XMessageBox.auto = true
	_fast_clock(true)
	s = XState.new_game(3, 1, [8, 9, 10])
	var sys: Dictionary = XDB.system().airship
	_check("default_image", str(_airship().characterName) == str(sys.characterName) and int(_airship().characterIndex) == int(sys.characterIndex)
		and str(sys.characterName) == "Vehicle" and int(sys.characterIndex) == 3, [_airship(), sys])
	_airship().mapId = 69
	_airship().x = 65
	_airship().y = 56
	if not _check("open_69", await _open(69, 65, 56) != null):
		return _finish()
	_check("texture_loaded", map.airship._tex != null and map.airship.character_name == "Vehicle" and map.airship.character_index == 3)
	await _view("parked")
	await _get_on("first")
	# 飞几格：影子跟着
	map.player.touch_target = Vector2i(65, 52)
	await _until(func(): return map.player.grid == Vector2i(65, 52) and not map.player.is_moving())
	await _view("flown")
	_shot("flying_65_52")
	# 触控：点前方一格是飞过去，不降落；点脚下才降落
	map.player.set_direction(8)
	map.player.click_cell(Vector2i(65, 51))
	_check("click_front_flies", map.player.touch_target == Vector2i(65, 51) and not map._vehicle_getting_off and bool(_airship().driving))
	_check("click_front_arrives", await _until(func(): return map.player.grid == Vector2i(65, 51) and not map.player.is_moving()) and bool(_airship().driving))
	# 空中存读档
	var alt := await _save_load_altitude("air", 69)
	_check("air_still_flying", alt == 48 and s.vehicle_type == "airship" and map.vehicle_can_move())
	await _view("air_loaded")
	# 改造包：323 换成直升机（SF_Vehicle 第 3 格），飞行中精灵马上换；存读档后还是直升机
	await MVInterpreter.new(map, 69, 0, [{"code": 323, "indent": 0, "parameters": [2, "SF_Vehicle", 3]}, {"code": 0, "indent": 0, "parameters": []}]).run()
	await get_tree().physics_frame
	_check("swap_323", map.airship.character_name == "SF_Vehicle" and map.airship.character_index == 3 and map.airship._tex != null, [map.airship.character_name, map.airship._tex])
	await _view("swap_view")
	if await _save_load("swap", 69):
		_check("swap_kept", str(_airship().characterName) == "SF_Vehicle" and int(_airship().characterIndex) == 3 and map.airship.character_name == "SF_Vehicle" and map.airship._tex != null)
		await _view("swap_loaded")
	# 飞回 (65,56)（原停泊格，能降落），点脚下降落（D1）
	map.player.touch_target = Vector2i(65, 56)
	await _until(func(): return map.player.grid == Vector2i(65, 56) and not map.player.is_moving())
	map.player.click_cell(map.player.grid)
	_check("click_self_lands", map._vehicle_getting_off)
	var seen := await _sample("land", -1, func(): return s.vehicle_type == "walk", 24, "land_24")
	_check("land_to_0", seen.front() >= 47 and seen.back() == 0 and seen.size() == seen.front() + 1, seen)
	await _view("landed")
	# 降落中存读档：存在一半，读回接着降
	await _get_on("second")
	await _press()
	await _until(func(): return int(_airship().altitude) <= 30)
	alt = await _save_load_altitude("falling", 69)
	_check("falling_resumes", alt > 0 and alt < 48 and map._vehicle_getting_off and not map.vehicle_can_move(), [alt, _airship()])
	await _view("falling_loaded")
	var seen2 := await _sample("falling_rest", -1, func(): return s.vehicle_type == "walk")
	_check("falling_to_0", seen2.back() == 0 and s.vehicle_type == "walk", seen2)
	# 升空中存读档：读回接着升到 48 才能飞
	await _press()
	await _until(func(): return int(_airship().altitude) >= 20)
	alt = await _save_load_altitude("rising", 69)
	_check("rising_resumes", alt > 0 and alt < 48 and s.vehicle_type == "airship" and bool(_airship().driving), [alt, _airship()])
	await _view("rising_loaded")
	var seen3 := await _sample("rising_rest", 1, func(): return map.vehicle_can_move())
	_check("rising_to_48", seen3.back() == 48 and map.vehicle_can_move(), seen3)
	# 物件图（! 开头，不上移 6）：萌物
	await MVInterpreter.new(map, 69, 0, [{"code": 323, "indent": 0, "parameters": [2, "!$occ01jp_mv03_georgette_tv", 0]}, {"code": 0, "indent": 0, "parameters": []}]).run()
	await get_tree().physics_frame
	_check("object_image", map.airship.is_object() and map.airship._tex != null)
	await _view("object_view")
	await _land("object")
	await _view("object_parked")
	_finish()


func _finish() -> void:
	_fast_clock(false)
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		for f in DirAccess.get_files_at(SAVE_DIR):
			DirAccess.remove_absolute(SAVE_DIR.path_join(f))
		DirAccess.remove_absolute(SAVE_DIR)
	XMessageBox.auto_answers = []
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
