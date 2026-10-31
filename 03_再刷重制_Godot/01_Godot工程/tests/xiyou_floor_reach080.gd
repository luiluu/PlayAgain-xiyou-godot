extends Node
## 75 簇期二：厄运王座副本（地图场景里真走一遍）：
## - 78 大厅（落点 (21,34)，本图遇敌表清空：门口这段沿用期一做法）走到 EV2 厄运王座门，带终极符文「挑战副本」→ 80 (21,24)；
##   变量 5＝1、6＝17、21＝1，符文扣一（期一「门能扣符文却进不去」随 80 入切片消失）；
## - 80 正厅：按图块 BFS 出口与首领、宝箱走得到（xiyou_reach_check）；EV1 → 76 北半 (17,20)；
## - 76 北半：从南半走不到（期一已核），北半 EV10、11、12、13 走得到；EV10 指挥官高弗（289）；EV12 → 80 西翼 (10,12)；
## - 80 西翼：EV7 火皮高费尔（287）；面朝左撞 EV6 → 86 王后闺房 (4,5)；86 EV3 王后高娜（288）；86 EV1 → 80 (8,5)；
##   80 EV5 → 76 (11,13)；76 EV13 → 80 东翼 (33,5)；EV4 御厨高乙（286）；面朝上撞 EV3 → 76 (25,5)；76 EV11 → 80 (21,29)；
## - 80 正厅：EV15 厄运之王高尔戈（290，选「是」）；五位首领打完变量 175＝5，宝箱 EV13 第 4 页：得一件奖励、回 78 (21,26)、副本重置
##   （变量 5、6、21、175 归零，开关 127～131 关）。出深渊之门时选「离开这是非之地」（随机）。
## - 每张图的落点都核 REACH；每场首领战都赢。队伍生命攻击都很大（只查流程）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const REACH := preload("res://tests/xiyou_reach_check.gd")
const WAIT := 6000
const TIMEOUT_MS := 240000
const DIRS := {2: Vector2i(0, 1), 4: Vector2i(-1, 0), 6: Vector2i(1, 0), 8: Vector2i(0, -1)}
const RUNE := 397

var results: Array = []
var battles: Array = []
var walk_battles: Array = []   # 走路途中真遇敌打的
var s: XState
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
	if map != null and not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(_on_ui_child)
	return map


func _on_ui_child(n: Node) -> void:
	if n is XBattleScene:
		n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT)


func _event(id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null



## 队伍参数：生命极大、攻击魔攻 5e13（一回合打完），同 xiyou_floor_reach106
func _party() -> void:
	for a in s.members():
		var eq: Array = a.equip_list()
		var item: Dictionary
		if not eq.is_empty():
			item = eq[0]
		else:
			for id in range(1, 200):
				if XDB.rec("Weapons", id).is_empty():
					continue
				var inst := XGear.create("weapon", id)
				if not inst.is_empty() and a.can_equip(inst):
					s.register_gear(inst)
					a.equips[0] = inst
					item = inst
					break
		if item.is_empty():
			continue
		item.params = [1.0e14, 1.0e6, 5.0e13, 5.0e6, 5.0e13, 5.0e6, 1.0e5, 1.0e3]
		XActor.test_param_max = 1.0e30  # 队伍属性堆过原版上限 99999999（XActor.PARAM_MAX），只在测试里放开
		a.refresh_passive()
		a.hp = a.mhp
		a.mp = a.mmp


# ---- 走路（同 xiyou_airship_fly）----

func _step_to(c: Vector2i) -> bool:
	map.player.touch_target = c
	return await _until(func(): return map.busy or (map.player.grid == c and not map.player.is_moving()), 600)


func _press() -> void:
	await _until(func(): return not map.busy)
	await map._on_action()


## 走路 BFS（图块双向通行；不踩别的事件格）
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


## 走路途中真遇敌：打完（击倒全部敌人）接着走，记在 walk_battles
func _walk(goal: Vector2i) -> bool:
	if map.player.grid == goal:
		return true
	var path := _path(map.player.grid, goal)
	if path.is_empty():
		return false
	var id := map.map_id
	for c in path:
		for attempt in 3:
			await _step_to(c)
			var fighting := map.busy and map.map_id == id and await _in_battle()
			if fighting:
				var n0 := battles.size()
				await _win(func(): await _until(func(): return not map.busy, 60000))
				walk_battles.append_array(battles.slice(n0))
				continue
			break
		if map.busy or map.player.grid != c:
			return false
	return map.player.grid == goal


func _in_battle() -> bool:
	for i in 60:
		if map.ui.get_children().any(func(n): return n is XBattleScene):
			return true
		await get_tree().process_frame
	return false


## 走到 from 再一步踩上 cell（接触触发的出口：踩上去时的朝向就是走的方向）；等到换图
func _step_onto(from: Vector2i, cell: Vector2i, dest: int) -> bool:
	if not await _walk(from):
		return false
	await _step_to(cell)
	return await _wait_map(dest) != null


## 走到同层事件旁、面向它按确认；answers 按顺序答选项
func _talk(ev_id: int, answers: Array) -> bool:
	var e := _event(ev_id)
	if e == null:
		return false
	for d in [2, 8, 4, 6]:
		var side: Vector2i = e.grid + DIRS[d]
		if map.player.grid != side and _path(map.player.grid, side).is_empty():
			continue
		if not await _walk(side):
			continue
		map.player.set_direction(10 - d)
		XMessageBox.auto_answers = answers.duplicate()
		XMessageBox.transcript.clear()
		await _press()
		await _until(func(): return not map.busy)
		return true
	return false


func _said(text: String) -> bool:
	return XMessageBox.transcript.any(func(t): return str(t).contains(text))



func _win(call: Callable) -> bool:
	var st := {"done": false}
	(func():
		await call.call()
		st.done = true).call()
	var t0 := Time.get_ticks_msec()
	while not st.done and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		for n in map.ui.get_children():
			if n is XBattleScene and not n.logic.enemies.is_empty():
				for en in n.logic.enemies:
					if en.is_alive():
						en.hp = 0.0
						en.add_state(1)
		await get_tree().process_frame
	return st.done


## 接触触发的出口事件：从走得到的四邻之一踩上去（朝向就是走的方向）
func _enter_ev(ev: int, dest: int) -> bool:
	var e := _event(ev)
	var cells := REACH.reachable(map, map.player.grid)
	for d in [8, 2, 4, 6]:
		var n: Vector2i = e.grid + DIRS[d]
		if cells.has(n):
			return await _step_onto(n, e.grid, dest)
	return false


func _bosses() -> Array:
	return [127, 128, 129, 130, 131].map(func(sw): return s.switch(sw))


func _here(m: int, at: Vector2i) -> bool:
	return map != null and map.map_id == m and map.player.grid == at


func _where():
	return [map.map_id if map else -1, map.player.grid if map else null]


## 首领：走到旁边按确认（answers 答选项），赢下 troop 那场
func _boss(tag: String, ev: int, troop: int, answers: Array, sw: int) -> bool:
	var n0 := battles.size()
	var ok := await _win(func(): await _talk(ev, answers))
	return _check(tag, ok and battles.size() == n0 + 1 and int(battles[-1].troop) == troop and battles[-1].result == 0 and s.switch(sw),
		[battles.slice(n0), _bosses(), XMessageBox.transcript])


## 78 大厅 → 王座门
func _enter() -> bool:
	s.map_id = 78
	s.x = 21
	s.y = 34
	get_tree().change_scene_to_file(MAP_SCENE)
	if not _check("hall_78", await _wait_map(78) != null):
		return false
	map.map_data.encounterList = []
	s.gain_item(RUNE, 1)
	if not _check("door_talk", await _talk(2, [0]), _where()):
		return false
	return _check("enter_80", await _wait_map(80) != null and _here(80, Vector2i(21, 24)) and _vars() == [1, 17, 1, 0], [_where(), _vars()])


func _hall() -> bool:
	_check("80_events", [1, 2, 3, 4, 5, 6, 7, 13, 15].all(func(i): return _event(i) != null))
	_check("80_reach_hall", REACH.unreachable(map, map.player.grid, [1, 2, 13, 15]).is_empty(), REACH.unreachable(map, map.player.grid, [1, 2, 13, 15]))
	# 东西翼（EV3～7）从正厅走不到，要绕 76 北半
	_check("80_wings_apart", REACH.unreachable(map, map.player.grid, [3, 4, 5, 6, 7]).size() == 5, REACH.unreachable(map, map.player.grid, [3, 4, 5, 6, 7]))
	return _check("80_to_76", await _step_onto(Vector2i(21, 28), Vector2i(21, 29), 76) and _here(76, Vector2i(17, 20)), _where())


func _north76() -> bool:
	_check("76n_reach", REACH.unreachable(map, map.player.grid, [10, 11, 12, 13]).is_empty(), REACH.unreachable(map, map.player.grid, [10, 11, 12, 13]))
	_check("76n_south_apart", REACH.unreachable(map, map.player.grid, [1, 2, 3, 7]).size() == 4)
	map.map_data.encounterList = []
	await _boss("boss_289", 10, 289, [], 128)
	return _check("76_to_80w", await _step_onto(Vector2i(11, 13), Vector2i(11, 12), 80) and _here(80, Vector2i(10, 12)), _where())


func _west() -> bool:
	_check("80w_reach", REACH.unreachable(map, map.player.grid, [5, 6, 7]).is_empty(), REACH.unreachable(map, map.player.grid, [5, 6, 7]))
	await _boss("boss_287", 7, 287, [], 130)
	# 面朝左撞 EV6（条件分支要角色朝左）
	if not _check("80w_to_86", await _step_onto(Vector2i(8, 5), Vector2i(7, 5), 86) and _here(86, Vector2i(4, 5)), _where()):
		return false
	_check("86_reach", REACH.unreachable(map, map.player.grid, [1, 3]).is_empty(), REACH.unreachable(map, map.player.grid, [1, 3]))
	await _boss("boss_288", 3, 288, [], 131)
	if not _check("86_to_80", await _step_onto(Vector2i(4, 5), Vector2i(5, 5), 80) and _here(80, Vector2i(8, 5)), _where()):
		return false
	return _check("80w_to_76", await _step_onto(Vector2i(10, 11), Vector2i(10, 12), 76) and _here(76, Vector2i(11, 13)), _where())


func _east() -> bool:
	map.map_data.encounterList = []
	if not _check("76_to_80e", await _enter_ev(13, 80) and _here(80, Vector2i(33, 5)), _where()):
		return false
	_check("80e_reach", REACH.unreachable(map, map.player.grid, [3, 4]).is_empty(), REACH.unreachable(map, map.player.grid, [3, 4]))
	await _boss("boss_286", 4, 286, [], 129)
	# 面朝上撞 EV3
	if not _check("80e_to_76", await _step_onto(Vector2i(33, 5), Vector2i(33, 4), 76) and _here(76, Vector2i(25, 5)), _where()):
		return false
	map.map_data.encounterList = []
	return _check("76_to_80hall", await _enter_ev(11, 80) and _here(80, Vector2i(21, 29)), _where())


func _throne() -> void:
	await _boss("boss_290", 15, 290, [0], 127)
	_check("all_bosses", _bosses() == [true, true, true, true, true] and int(s.variable(175)) == 5, [_bosses(), s.variable(175)])
	var gear := s.gear.size()
	XMessageBox.auto_answers = [1]
	if not _check("chest_talk", await _talk(13, [1]), _where()):
		return
	await _wait_map(78)
	_check("chest_reward_reset", _here(78, Vector2i(21, 26)) and s.gear.size() == gear + 1 and _vars() == [0, 0, 0, 0] and int(s.variable(175)) == 0
		and _bosses() == [false, false, false, false, false], [_where(), s.gear.size() - gear, _vars(), _bosses(), XMessageBox.transcript])


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_reach080"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XShop.auto_close = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261030)
	_fast_clock(true)
	s = XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.set_variable(21, 0)
	_party()
	if await _enter() and await _hall() and await _north76() and await _west() and await _east():
		await _throne()
	_finish()


func _vars() -> Array:
	return [int(s.variable(5)), int(s.variable(6)), int(s.variable(21)), s.item_count(RUNE)]


func _finish() -> void:
	_fast_clock(false)
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	XMessageBox.auto_answers = []
	print("战斗：", JSON.stringify(battles), " 走路遇敌：", JSON.stringify(walk_battles))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
