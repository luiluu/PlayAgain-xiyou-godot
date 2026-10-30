extends Node
## 75 簇期四：厄运监狱 Map079（地图场景里真走一遍）：
## - 78 大厅（本图遇敌表清空）走到 EV5 厄运监狱门，带终极符文「挑战副本」→ 79 (15,5)；变量 5＝1、6＝16、21＝1，符文扣一；
## - B3（O-待定，MVTilemap.open_cells_fix）：原版入口落点区域和牢房走廊在图块上不连通，整座监狱走不进去；
##   打通 (15,8)、(15,10) 后从落点按图块 BFS 牢门 EV2～5 的前一格走得到；设 {} 回原版时牢门走不到；
## - 牢门：没钥匙（厄运监狱钥匙 403）提示「你没有钥匙」，有钥匙「打开」→ 开关 115～118，门页换成可通行的第 2 页，门后首领走得到；
## - 四位首领（EV12 泰岳 283、EV15 高提 281、EV14 格德尔 282、EV13 希利 284）各赢一场，开关 111～114；
## - 出口 EV1 (15,4)：「逃离」回 78 (34,19)，开关 111～118 关，变量 5／6 归零、21 减一；再回门口「重置副本」检查。
## 队伍生命攻击都很大（只查流程）。
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
		if not e.page.is_empty() and e.is_normal_priority() and not e.through:
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
	for d in [2, 8, 4, 6]:   # 出口 EV1 在走廊口，先试南面（北面要穿过它才到）
		var n: Vector2i = e.grid + DIRS[d]
		if cells.has(n):
			return await _step_onto(n, e.grid, dest)
	return false


func _vars() -> Array:
	return [int(s.variable(5)), int(s.variable(6)), int(s.variable(21)), s.item_count(RUNE)]


func _here(m: int, at: Vector2i) -> bool:
	return map != null and map.map_id == m and map.player.grid == at


func _where():
	return [map.map_id if map else -1, map.player.grid if map else null]


## 78 大厅 → 监狱门（挑战副本）→ 79 (15,5)
func _enter() -> bool:
	s.map_id = 78
	s.x = 21
	s.y = 34
	get_tree().change_scene_to_file(MAP_SCENE)
	if not _check("hall_78", await _wait_map(78) != null):
		return false
	map.map_data.encounterList = []
	s.gain_item(RUNE, 1)
	if not _check("door_talk", await _talk(5, [0]), _where()):
		return false
	return _check("enter_79", await _wait_map(79) != null and _here(79, Vector2i(15, 5)) and _vars() == [1, 16, 1, 0], [_where(), _vars()])


func _prison() -> bool:
	_check("79_events", range(1, 16).all(func(i): return _event(i) != null))
	_check("79_reach", REACH.unreachable(map, map.player.grid, [1, 2, 3, 4, 5]).is_empty(), REACH.unreachable(map, map.player.grid, [1, 2, 3, 4, 5]))
	# 回退：open_cells_fix 设 {} 时牢门走不到（原版），牢房走廊与落点区域不连通
	var saved := map.lower.open_cells
	map.lower.open_cells = []
	_check("79_original_sealed", REACH.unreachable(map, map.player.grid, [2, 3, 4, 5]).size() == 4, REACH.unreachable(map, map.player.grid, [2, 3, 4, 5]))
	map.lower.open_cells = saved
	# 牢门：没钥匙
	XMessageBox.auto_answers = [0]
	_check("door2_no_key", await _door(2) and _said("你没有钥匙") and not s.switch(115), XMessageBox.transcript)
	s.gain_item(403, 1)
	for row in [[2, 115, 12, 283, 111], [3, 116, 15, 281, 114], [4, 117, 14, 282, 113], [5, 118, 13, 284, 112]]:
		var door: int = row[0]
		_check("door%d_open" % door, await _door(door) and s.switch(row[1]), [s.switch(row[1]), XMessageBox.transcript])
		var boss: int = row[2]
		_check("boss%d_reach" % boss, REACH.unreachable(map, map.player.grid, [boss]).is_empty(), REACH.unreachable(map, map.player.grid, [boss]))
		var n0 := battles.size()
		var ok := await _win(func(): await _talk(boss, []))
		_check("boss%d_battle" % boss, ok and battles.size() == n0 + 1 and int(battles[-1].troop) == row[3] and battles[-1].result == 0 and s.switch(row[4]),
			[battles.slice(n0), s.switch(row[4]), XMessageBox.transcript])
	return true


## 站到牢门前一格（门在 y＝13，前一格 y＝12），向下撞门；answers 已设
func _door(ev: int) -> bool:
	var e := _event(ev)
	var front := e.grid + Vector2i(0, -1)
	if not await _walk(front):
		return false
	XMessageBox.transcript.clear()
	map.player.set_direction(2)
	await _step_to(e.grid)
	await _until(func(): return not map.busy)
	return true


func _leave() -> void:
	# 出口 EV1：落点区域的出口（15,4）；先走回去
	XMessageBox.auto_answers = [0]
	if not _check("exit_reach", REACH.unreachable(map, map.player.grid, [1]).is_empty(), REACH.unreachable(map, map.player.grid, [1])):
		return
	if not _check("exit_back", await _enter_ev(1, 78) and _here(78, Vector2i(34, 19)), [_where(), XMessageBox.transcript, s.switch(111)]):
		return
	_check("exit_reset", int(s.variable(5)) == 0 and int(s.variable(6)) == 0 and int(s.variable(21)) == 0
		and not [111, 112, 113, 114, 115, 116, 117, 118].any(func(sw): return s.switch(sw)), [_vars(), s.switch(111)])
	# 再进再重置：变量 5＝1 且 6＝16 时门口「重置副本」认，其余不认
	map.map_data.encounterList = []
	s.gain_item(RUNE, 1)
	await _talk(5, [0])
	await _wait_map(79)
	s.set_switch(111, true)
	s.map_id = 78
	s.x = 34
	s.y = 21
	get_tree().change_scene_to_file(MAP_SCENE)
	await _wait_map(78)
	map.map_data.encounterList = []
	await _talk(5, [1])
	_check("reset_door", _said("重置完毕") and int(s.variable(5)) == 0 and int(s.variable(6)) == 0 and not s.switch(111), [XMessageBox.transcript, _vars()])


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_reach079"
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
	if await _enter() and await _prison():
		await _leave()
	_finish()


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
