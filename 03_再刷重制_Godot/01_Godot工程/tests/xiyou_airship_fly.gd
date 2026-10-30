extends Node
## 飞艇上下与飞行（天之上飞艇方案甲二，原版 Game_Player／Game_Vehicle 的载具部分）：
## - 静态对照：69／186 全图每格 XMapScene.airship_land_ok（isAirshipLandOk 且没有事件）与盘点脚本的表逐格相同
##   （tests/fixtures/airship_land.json＝00_项目管理/盘点脚本/载具可达.py 的第 4 个输出，冻结 v0.28 只读算出；格→块号）；
## - 上艇：Map069 (65,56) 站在飞艇上按确认，收拢跟随、升到 48 之前不能动；之后玩家透明穿透、速度 6、放飞艇 BGM、存下地图 BGM；
## - 飞行：站到事件上不触发、对着事件按确认不触发、步数不计、不减遇敌步数（塞一张假遇敌表）；传送按钮与挂机锁住（O-待定）；
##   有事件的格、isAirshipLandOk 不过的格按确认不下；
## - 逐块（交付单 claude_wukong-airship 1.2／1.3 表）：飞到该块离出口最近的可降落格降落（朝下、跟随叠到脚下、放回地图 BGM、
##   降到 0 才走路），落点块号与表一致；再按通行 BFS 走到出口事件跑一次：传送门进目标图、用目标图回 69 的事件回来（落回同一块），
##   对话类事件按「离开／我再看看」触发一次；然后走回飞艇再上；
## - 飞行中换图（事件 201）带着飞艇、仍在飞、BGM 不换；在空中存读档、重建地图后仍在飞、能降落。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const FIXTURE := "res://tests/fixtures/airship_land.json"
const SAVE_DIR := "user://test_airship_fly"
const WAIT := 6000
## 天之上各块：[块, 出口事件, 目标图（0＝不换图；−1＝目标图不在切片，只走到事件旁）, 目标图回 69 的事件, 应答]；块 25 回大厅放最后（回来靠 CE240＋恰兰吉尔出口）
const BLOCKS_69 := [
	[22, 48, 91, 2, []], [5, 45, 90, 8, []], [9, 44, 88, 4, []], [43, 46, 106, 4, []], [20, 65, 0, 0, [2]],
	[38, 71, 0, 0, [1]], [74, 52, 94, 1, []], [121, 70, 115, 1, []], [84, 56, 105, 1, []], [89, 53, 92, 1, []],
	[92, 69, 112, 3, []], [56, 18, -1, 0, []], [8, 0, 0, 0, []], [57, 0, 0, 0, []], [90, 0, 0, 0, []], [108, 0, 0, 0, []],
	[25, 3, 4, 0, []]]
## 神魔战场各块：[块, 对话事件（农田／矿：选「我再看看」）, 0, 0, 应答]
const BLOCKS_186 := [[2, 21, 0, 0, [1]], [3, 6, 0, 0, [1]], [6, 5, 0, 0, [1]], [19, 12, 0, 0, [1]], [32, 14, 0, 0, [1]],
	[38, 7, 0, 0, [1]], [41, 10, 0, 0, [1]], [47, 4, 0, 0, [1]]]
const DIRS := {2: Vector2i(0, 1), 4: Vector2i(-1, 0), 6: Vector2i(1, 0), 8: Vector2i(0, -1)}

var results: Array = []
var s: XState
var fx: Dictionary
var map: XMapScene


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


## 同 xiyou_floor_run._fast_clock：去掉每帧睡眠、物理帧 600／秒，逐帧逻辑照常只是跑得快
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


func _block(id: int, c: Vector2i) -> int:
	return int(fx[str(id)].block.get("%d,%d" % [c.x, c.y], 0))


func _event(id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


## 按 touch_target 一格一格走（走 MVPlayer.update_character 的真实路径：stepped、接触、确认都照常）
func _step_to(c: Vector2i) -> bool:
	map.player.touch_target = c
	return await _until(func(): return map.busy or (map.player.grid == c and not map.player.is_moving()), 600)


## 飞到某格（穿透，_toward 直线靠近）
func _fly_to(c: Vector2i) -> bool:
	map.player.touch_target = c
	return await _until(func(): return map.player.grid == c and not map.player.is_moving())


## 按确认（Game_Player.triggerButtonAction）
func _press() -> void:
	await _until(func(): return not map.busy)
	await map._on_action()


func _get_on(tag: String) -> bool:
	await _press()
	if not _check(tag + "_getting_on", s.vehicle_type == "airship" and not map.vehicle_can_move(), [s.vehicle_type, _airship()]):
		return false
	return _check(tag + "_flying", await _until(func(): return map.vehicle_can_move()) and int(_airship().altitude) == 48 and map.player.through and map.player.transparent and map.player.vehicle_speed == 6, _airship())


func _land(tag: String) -> bool:
	await _press()
	if not _check(tag + "_landing", map._vehicle_getting_off and not bool(_airship().driving) and map.player.direction == 2 and not map.player.through, [s.vehicle_type, _airship()]):
		return false
	return _check(tag + "_walk", await _until(func(): return s.vehicle_type == "walk" and map.vehicle_can_move()) and not map.player.transparent and int(_airship().altitude) == 0, _airship())


## 走路 BFS（图块双向通行、同层事件挡路；不踩别的事件格）
func _path(from: Vector2i, goal: Vector2i) -> Array:
	var occupied := {}
	for e in map.events:
		if not e.page.is_empty():
			occupied[e.grid] = true
	var prev := {from: from}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == goal:
			var out := []
			while c != from:
				out.push_front(c)
				c = prev[c]
			return out
		for d in DIRS:
			var n: Vector2i = c + DIRS[d]
			if prev.has(n) or not map.lower.is_valid(n) or (occupied.has(n) and n != goal):
				continue
			if map.lower.is_passable(c.x, c.y, d) and map.lower.is_passable(n.x, n.y, 10 - d):
				prev[n] = c
				q.append(n)
	return []


func _walk(goal: Vector2i) -> bool:
	for c in _path(map.player.grid, goal):
		if not await _step_to(c) or map.busy:
			return false
	return map.player.grid == goal


## 走到事件跑一次：同层的从四边（下、上、左、右，事件可能要求朝向）靠过去撞它；角色下方的踩上去。
## 跑完后 dest＞0 要换到 dest，否则只要跑过。地图场景跨传送不换（load_map 在本场景里），事件节点会换
func _run_exit(ev_id: int, dest: int, answers: Array) -> bool:
	var e := _event(ev_id)
	if e == null:
		return false
	var grid := e.grid
	var normal := e.is_normal_priority()
	var map_id := map.map_id
	var sides: Array = [grid + DIRS[2], grid + DIRS[8], grid + DIRS[4], grid + DIRS[6]] if normal else [grid]
	for side in sides:
		if map.player.grid != side and _path(map.player.grid, side).is_empty():
			continue
		XMessageBox.auto_answers = answers.duplicate()
		var ran := [false]
		var cb := func(b: bool): ran[0] = ran[0] or b
		map.busy_changed.connect(cb)
		await _walk(side)
		if normal and not map.busy and map.map_id == map_id:
			await _step_to(grid)   # 撞上去：update_character 走不过去时面向目标、按调查
		await _until(func(): return not map.busy)
		map.busy_changed.disconnect(cb)
		if dest > 0 and map.map_id == dest:
			return await _wait_map(dest) != null
		if dest == 0 and ran[0]:
			return true
	return false


## 跑目标图的出口事件回到 to（出口常要求朝向，如 Map088、071 要朝下：依次转向再跑，相当于在出口格上转身）
func _run_back(ev_id: int, to: int) -> bool:
	for d in [map.player.direction, 2, 8, 4, 6]:
		var back := _event(ev_id)
		if back == null or map.map_id == to:
			break
		map.player.set_direction(d)
		XMessageBox.auto_answers = []
		await map.run_event(back)
		await _until(func(): return not map.busy)
	return await _wait_map(to) != null


func _static_compare() -> void:
	for id in [69, 186]:
		var m := await _open(id, 1, 1)
		if not _check("open_%d" % id, m != null):
			continue
		var want: Dictionary = fx[str(id)].block
		var diff := []
		var n := 0
		for y in m.lower.height:
			for x in m.lower.width:
				var ok := m.airship_land_ok(Vector2i(x, y))
				n += int(ok)
				if ok != want.has("%d,%d" % [x, y]):
					diff.append([x, y, ok])
		_check("land_table_%d" % id, diff.is_empty() and n == want.size() and n > 0, [n, want.size(), diff.slice(0, 10)])


## 第一次上艇与飞行中的各项
func _first_flight() -> void:
	_airship().mapId = 69
	_airship().x = 65
	_airship().y = 56
	if not _check("open_69_airship", await _open(69, 65, 56) != null):
		return
	_check("parked_visible", map.airship != null and not map.airship.transparent and map.airship.grid == Vector2i(65, 56) and map.airship.priority_type == 0)
	# 飞艇不在脚下时按确认不上
	_airship().x = 66
	await _press()
	_check("not_on_airship_cell", s.vehicle_type == "walk" and not map.busy)
	_airship().x = 65
	for f in map.followers:
		f.synchronize(Vector2i(66, 56), 4)
	var map_bgm := str(map._bgm_name)
	if not await _get_on("first"):
		return
	_check("followers_gathered", map.followers.all(func(f): return f.grid == map.player.grid and f.transparent))
	_check("airship_bgm", map._bgm_name == "Theme_Amara" and s.walking_bgm is Dictionary and str(s.walking_bgm.name) == map_bgm, [map._bgm_name, s.walking_bgm])
	_check("airship_above", map.airship.priority_type == 2 and map.airship.grid == map.player.grid)
	# 飞行中站到事件上（EV5 恰兰吉尔口，接触触发、传送）：不触发；对着它按确认也不下、不触发；塞一张假遇敌表
	var steps := s.steps
	map.map_data.encounterList = [{"troopId": 1, "weight": 1, "regionSet": []}]
	map.encounter_count = 1
	# O-待定：传送按钮、挂机（有遇敌表时没锁会开始挂机）
	await get_tree().process_frame
	_check("transfer_locked", map.map_hud.transfer_button.disabled)
	map.toggle_hang_up()
	_check("hang_up_locked", not s.hang_up_active)
	map.open_transfer()
	_check("transfer_page_locked", map.transfer_page == null)
	await _fly_to(Vector2i(63, 49))
	# 判据是没被 EV5 传到 Map071；地图上偶尔有别的提示（修行指引等）在跑，先等它跑完（并行负载下曾撞上，偶发 1 次）
	await _until(func(): return not map.busy)
	_check("no_touch_event", map.map_id == 69 and s.vehicle_type == "airship" and map.player.grid == Vector2i(63, 49), [map.map_id, map.busy, s.vehicle_type, map.player.grid])
	_check("no_steps_no_encounter", s.steps == steps and map.encounter_count == 1 and not map.can_encounter() and not map._in_battle, [s.steps, steps, map.encounter_count])
	await _press()
	await _until(func(): return not map.busy)
	_check("no_land_on_event", bool(_airship().driving) and not map._vehicle_getting_off and map.map_id == 69, [_airship(), map._vehicle_getting_off, map.map_id, map.busy])
	map.map_data.encounterList = []
	# isAirshipLandOk 不过的格（最近的一格）
	var bad := Vector2i(-1, -1)
	for r in range(1, 30):
		for c in [Vector2i(63 - r, 49), Vector2i(63 + r, 49), Vector2i(63, 49 - r), Vector2i(63, 49 + r)]:
			if bad.x < 0 and map.lower.is_valid(c) and not map.lower.is_airship_land_ok(c.x, c.y):
				bad = c
	if _check("found_no_land_cell", bad.x >= 0):
		await _fly_to(bad)
		await _press()
		_check("no_land_0x0800", bool(_airship().driving) and not map._vehicle_getting_off, bad)
	# 飞到本块别处降落，再上
	await _fly_to(Vector2i(56, 64))
	if await _land("block33"):
		await get_tree().process_frame
		await get_tree().process_frame   # process_frame 信号在各节点 _process 之前发，跟随的透明在下一帧才跟上
		_check("followers_sync", map.followers.all(func(f): return f.grid == map.player.grid and not f.transparent), map.followers.map(func(f): return [f.grid, f.transparent, map.player.grid]))
		_check("walking_bgm_back", map._bgm_name == map_bgm, map._bgm_name)
		_check("airship_parked_here", int(_airship().x) == 56 and int(_airship().y) == 64 and int(_airship().direction) == 4 and map.airship.priority_type == 0)
		await _get_on("block33_again")


## 落点：块里离出口事件最近、又不和它相邻的可降落格（站在飞艇上按确认先上飞艇，原版 triggerButtonAction 的顺序）
func _landing(id: int, block: int, near: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 1 << 30
	for k in fx[str(id)].block:
		if int(fx[str(id)].block[k]) != block:
			continue
		var p: PackedStringArray = k.split(",")
		var c := Vector2i(int(p[0]), int(p[1]))
		var d := absi(c.x - near.x) + absi(c.y - near.y)
		if d >= 2 and d < bd or (d == bd and (c.y < best.y or (c.y == best.y and c.x < best.x))):
			bd = d
			best = c
	return best


func _visit(id: int, row: Array) -> void:
	var block: int = row[0]
	var tag := "%d_b%d" % [id, block]
	var e := _event(row[1]) if row[1] > 0 else null
	var near: Vector2i = e.grid if e else Vector2i(0, 0)
	var land := _landing(id, block, near)
	if not _check(tag + "_has_landing", land.x >= 0):
		return
	await _fly_to(land)
	if not await _land(tag) or not _check(tag + "_block", _block(id, map.player.grid) == block, map.player.grid):
		return
	if e and row[2] < 0:
		_check(tag + "_reach_ev%d" % row[1], [DIRS[2], DIRS[8], DIRS[4], DIRS[6]].any(func(o): return not _path(map.player.grid, e.grid + o).is_empty()))
	elif e:
		var dest: int = row[2]
		var ok := await _run_exit(row[1], dest, row[4])
		_check(tag + "_exit_ev%d" % row[1], ok, [map.map_id if map else -1])
		if not ok:
			return
		if dest > 0 and row[3] > 0:
			# 用目标图回 69 的事件回来
			_check(tag + "_back_69", await _run_back(row[3], id) and _block(id, map.player.grid) in [0, block], map.player.grid if map else null)
		elif dest > 0:
			return
	if map == null or map.map_id != id:
		return
	# 走回飞艇、再上
	var at := Vector2i(int(_airship().x), int(_airship().y))
	if _check(tag + "_walk_back", await _walk(at), [map.player.grid, at]):
		await _get_on(tag + "_reboard")


func _run() -> void:
	XSave.dir_override = SAVE_DIR
	XMessageBox.auto = true
	_fast_clock(true)
	fx = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	s = XState.new_game(3, 1, [8, 9, 10])
	s.set_variable(21, 0)
	await _static_compare()
	await _first_flight()
	for row in BLOCKS_69:
		if map == null or map.map_id != 69 or s.vehicle_type != "airship":
			break
		await _visit(69, row)
	# 块 25 去了大厅：CE240 把飞艇停回 69 (65,56)、去恰兰吉尔，再走恰兰吉尔下口回 69
	if map != null and map.map_id == 4:
		await MVInterpreter.new(map, 4, 0, XDB.rec("CommonEvents", 240).list).run()
		if _check("ce240_to_71", await _wait_map(71) != null):
			if _check("back_69_from_71", await _run_back(3, 69)):
				var at := Vector2i(int(_airship().x), int(_airship().y))
				if _check("walk_to_airship_65_56", at == Vector2i(65, 56) and await _walk(at)):
					await _get_on("after_hub")
	# 飞行中换图：事件 201 到神魔战场，飞艇跟过去、仍在飞、BGM 不换、记下新图 BGM
	if map != null and s.vehicle_type == "airship":
		await MVInterpreter.new(map, 69, 0, [{"code": 201, "indent": 0, "parameters": [0, 186, 50, 49, 0, 0]}, {"code": 0, "indent": 0, "parameters": []}]).run()
		if _check("fly_transfer_186", await _wait_map(186) != null):
			var v := _airship()
			_check("airship_follows", int(v.mapId) == 186 and bool(v.driving) and map.player.through and map.player.transparent and map.vehicle_can_move(), v)
			_check("bgm_kept", map._bgm_name == "Theme_Amara" and str(s.walking_bgm.name) == "yaosaiyizhi", [map._bgm_name, s.walking_bgm])
			# 在空中存读档
			if _check("save_air", XSave.save(1)) and _check("load_air", XSave.load_slot(1)):
				s = XState.current
				get_tree().change_scene_to_file(MAP_SCENE)
				if _check("reload_186", await _wait_map(186) != null):
					_check("still_flying", s.vehicle_type == "airship" and bool(_airship().driving) and map.player.through and map.player.transparent and map.vehicle_can_move() and map._bgm_name == "Theme_Amara")
			for row in BLOCKS_186:
				if map == null or map.map_id != 186 or s.vehicle_type != "airship":
					break
				await _visit(186, row)
	_check("ended_on_186_airship", map != null and map.map_id == 186 and s.vehicle_type == "airship")
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
