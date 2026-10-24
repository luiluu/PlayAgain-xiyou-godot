extends Node
## 传送室 Map031、勇者之塔 Map081、勇者之塔一层 Map082 流程（地图场景里真走一遍；数值与事件对照由 xiyou_event_compare 承担）：
## - 入口：未知存在 Map160 出口（变量 6＝19）→ Map031 (8,5)、Map162 出口（＝45）→ Map031 (14,6)、（＝18）→ Map081 (17,33)。
## - Map031 EV4（开关 97）「传送」→ Map081 (17,38)；其余门去 Map024／018／111／197，未接。
## - Map081 EV1（开关 1709～1712 每档一页）：缺特级符文 171 不进；有符文进 Map082 (15,25)，变量 6＝18、21／5 加一；
##   副本未重置（变量 5≥1）时「请重置副本！」，重置分支把 5／6／21 减回、关开关 121～126、924；EV2「传送」回 Map031 (9,5)。
## - Map082：门卫葛雷果 EV1（敌群 292，胜后开关 121）；逃离 EV3 → Map081 (17,33) 并重置；副本协会主席 EV6（开关 909）送土特产或没带礼开战 661
##   （带活力水 912 行贿传王座 Map085，未接，不测）；魔塔教师 EV4「进行修炼」开修炼界面（Scene_ActorAttributePlusPoints，未做），只测「离开」。
## 队伍生命攻击都很大（只查流程）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const RUNE := 171
const TIMEOUT_MS := 240000   # 并行负载下单个事件可能跑到一两分钟，别用 90 秒的墙钟判失败

var results: Array = []
var battles: Array = []   # 每场：{troop, result}


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


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _scene() -> Node:
	return get_tree().current_scene


func _wait_map(map_id: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var s = _scene()
		if s is XMapScene and s.map_id == map_id and s.player != null and not s.busy:
			return true
		await get_tree().process_frame
	return false


func _event(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


## 队伍参数：生命极大、攻击魔攻 5e13（一回合打完）
func _party() -> void:
	for a in XState.current.members():
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
					XState.current.register_gear(inst)
					a.equips[0] = inst
					item = inst
					break
		if item.is_empty():
			continue
		item.params = [1.0e14, 1.0e6, 5.0e13, 5.0e6, 5.0e13, 5.0e6, 1.0e5, 1.0e3]
		a.refresh_passive()
		a.hp = a.mhp
		a.mp = a.mmp


func _battle_of(map: XMapScene) -> XBattleScene:
	for n in map.ui.get_children():
		if n is XBattleScene:
			return n
	return null


## 跑一个事件到结束；mode：""＝不干预，"win"＝战斗一开始击倒全部敌人，"lose"＝击倒全部队员
func _run_event(map: XMapScene, id: int, answers: Array, mode := "win") -> bool:
	var e := _event(map, id)
	if not _check("map%d_event%d_present" % [map.map_id, id], e != null):
		return false
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(func(n):
			if n is XBattleScene:
				n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT))
	XMessageBox.auto_answers = answers.duplicate()
	var st := {"done": false}
	(func():
		await map.run_event(e)
		st.done = true).call()
	var t0 := Time.get_ticks_msec()
	while not st.done and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var b := _battle_of(map)
		if b != null and not b.logic.enemies.is_empty():
			if mode == "win":
				for en in b.logic.enemies:
					if en.is_alive():
						en.hp = 0.0
						en.add_state(1)
			elif mode == "lose":
				for a in b.logic.actors:
					if a.is_alive():
						a.hp = 0.0
						a.add_state(1)
		await get_tree().process_frame
	return _check("map%d_event%d_finished" % [map.map_id, id], st.done)


func _start(map_id: int, x: int, y: int) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = 8
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	return s



func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_brave081"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	await _from_unknown()
	await _teleport_room()
	await _tower_gate()
	await _floor1()
	_finish()


## 未知存在出口接到传送室／勇者之塔
func _from_unknown() -> void:
	for c in [[160, 19, 31, Vector2i(8, 5)], [162, 45, 31, Vector2i(14, 6)], [162, 18, 81, Vector2i(17, 33)]]:
		var s := _start(c[0], 9, 7)
		if not _check("m%d_loaded" % c[0], await _wait_map(c[0])):
			return
		s.set_variable(5, 1)
		s.set_variable(6, c[1])
		await _run_event(_scene(), 1, [0], "")
		_check("m%d_exit_%d" % [c[0], c[1]], await _wait_map(c[2]) and _scene().player.grid == c[3], [_scene().name])
		_check("m%d_exit_reset_%d" % [c[0], c[1]], int(s.variable(6)) == 0, s.variable(6))


func _teleport_room() -> void:
	var s := _start(31, 11, 7)
	if not _check("room_loaded", await _wait_map(31)):
		return
	var map: XMapScene = _scene()
	_check("room_events", range(1, 7).all(func(i): return _event(map, i) != null))
	s.set_switch(97, true)
	map.refresh_events()
	await _run_event(map, 4, [1], "")
	_check("room_stay", _scene().map_id == 31)
	await _run_event(map, 4, [0], "")
	_check("room_to_tower", await _wait_map(81) and _scene().player.grid == Vector2i(17, 38), [_scene().name])
	map = _scene()
	await _run_event(map, 2, [0], "")
	_check("tower_to_room", await _wait_map(31) and _scene().player.grid == Vector2i(9, 5), [_scene().name])


func _tower_gate() -> void:
	var s := _start(81, 17, 34)
	if not _check("tower_loaded", await _wait_map(81)):
		return
	var map: XMapScene = _scene()
	_check("tower_events", [1, 2].all(func(i): return _event(map, i) != null))
	s.set_switch(1709, true)
	map.refresh_events()
	# 没有符文：留在门口
	await _run_event(map, 1, [0], "")
	_check("tower_no_rune", _scene().map_id == 81 and int(s.variable(6)) == 0, [s.variable(6)])
	# 有符文：扣符文进一层
	s.gain_item(RUNE, 1)
	await _run_event(map, 1, [0], "")
	_check("tower_enter", await _wait_map(82) and _scene().player.grid == Vector2i(15, 25), [_scene().name])
	_check("tower_enter_vars", s.item_count(RUNE) == 0 and int(s.variable(6)) == 18 and int(s.variable(5)) == 1 and int(s.variable(21)) == 1 and int(s.variable(450)) == 1,
		[s.item_count(RUNE), s.variable(6), s.variable(5), s.variable(21), s.variable(450)])
	# 回门口：副本未重置时进不去，重置后变量减回
	s.set_variable(21, 0)
	s.map_id = 81
	s.x = 17
	s.y = 34
	get_tree().change_scene_to_file(MAP_SCENE)
	if not _check("tower_back_loaded", await _wait_map(81)):
		return
	map = _scene()
	s.gain_item(RUNE, 1)
	await _run_event(map, 1, [0], "")
	_check("tower_sealed", _scene().map_id == 81 and s.item_count(RUNE) == 1, [_scene().name, s.item_count(RUNE)])
	s.set_switch(121, true)
	await _run_event(map, 1, [1], "")
	_check("tower_reset", int(s.variable(5)) == 0 and int(s.variable(6)) == 0 and not s.switch(121), [s.variable(5), s.variable(6), s.switch(121)])


func _floor1() -> void:
	var s := _start(82, 15, 24)
	s.direction = 2   # 逃离点 EV3 只在面朝下时问
	if not _check("f1_loaded", await _wait_map(82)):
		return
	var map: XMapScene = _scene()
	_check("f1_events", range(1, 7).all(func(i): return _event(map, i) != null))
	var n0 := battles.size()
	await _run_event(map, 1, [], "win")
	_check("f1_guard", battles.size() == n0 + 1 and battles[-1].troop == 292 and battles[-1].result == 0 and s.switch(121), [battles.slice(n0), s.switch(121)])
	# 魔塔教师：只测「离开」
	await _run_event(map, 4, [1], "")
	_check("f1_teacher_leave", _scene().map_id == 82)
	# 主席：送土特产开战 661；没带活力水送礼也开战
	s.set_switch(909, true)
	map.refresh_events()
	n0 = battles.size()
	await _run_event(map, 6, [1], "win")
	_check("f1_chair_gift", battles.size() == n0 + 1 and battles[-1].troop == 661, battles.slice(n0))
	map = _scene()
	n0 = battles.size()
	await _run_event(map, 6, [0], "win")
	_check("f1_chair_no_water", battles.size() == n0 + 1 and battles[-1].troop == 661, battles.slice(n0))
	map = _scene()
	n0 = battles.size()
	await _run_event(map, 6, [2], "")
	_check("f1_chair_look", battles.size() == n0)
	# 逃离：回 Map081 (17,33) 并重置
	s.set_variable(5, 1)
	s.set_variable(6, 18)
	s.set_variable(21, 1)
	map.player.direction = 2
	await _run_event(map, 3, [1], "")
	_check("f1_escape_no", _scene().map_id == 82)
	await _run_event(map, 3, [0], "")
	_check("f1_escape", await _wait_map(81) and _scene().player.grid == Vector2i(17, 33), [_scene().name])
	_check("f1_escape_reset", int(s.variable(6)) == 0 and int(s.variable(21)) == 0 and not s.switch(121), [s.variable(6), s.variable(21), s.switch(121)])


func _item_total(s: XState) -> int:
	var n := 0
	for k in s.items:
		n += int(s.items[k])
	return n


func _finish() -> void:
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	print("战斗：", JSON.stringify(battles))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
