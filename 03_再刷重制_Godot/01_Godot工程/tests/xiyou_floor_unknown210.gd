extends Node
## 未知存在（Map210）流程（地图场景里真走一遍；数值与事件对照由 xiyou_event_compare 承担，这里查流程跑得通）：
## - 入口：妄语深渊 Map211 封印 EV5「前往未知存在」→ Map210 (9,14)。
## - 封印 EV4（开关 75 时第 1 页）：变量 244 取 1～6 对应敌群 724～729，胜后开关 79、成就 76、肝帝积分（变量 214 的 2～5）。
## - 副本协会主席 EV2：开关 79 起按开关 2225～2229 分页（抽奖 CE1424 次数）；选「还得看脸」打敌群 661；开关 2302 页是天道研究员（变量 30＝20 时敌群 767）。
## - 出口 EV1：按变量 6（38／39／40）传回 Map145／Map144 并公共事件 1024／1025 重置、关开关 75～79。
## 队伍生命攻击都很大（只查流程）；用 MVEventCore.fixed_random 固定事件随机数。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const UNKNOWN := 210
const SEAL := 4
const CHAIR := 2
const EXIT := 1
const TIMEOUT_MS := 90000

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
	XSave.dir_override = "user://test_xiyou_floor_unknown210"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	await _seal()
	await _chair()
	await _exit()
	MVEventCore.fixed_random = -1.0
	_finish()


func _seal() -> void:
	var s := _start(UNKNOWN, 9, 12)
	if not _check("unknown_loaded", await _wait_map(UNKNOWN)):
		return
	var map: XMapScene = _scene()
	_check("unknown_events", [1, 2, 3, 4, 5, 6].all(func(i): return _event(map, i) != null))
	# 开关 75 未开：封印事件没有可运行页，不出战斗
	s.set_switch(75, true)
	map.refresh_events()
	await _run_event(map, SEAL, [1], "")
	_check("seal_leave", not s.switch(79) and battles.is_empty(), battles)
	# 六个敌群各打一遍（变量 244 由固定随机数决定）
	for k in range(1, 7):
		s.set_switch(75, true)
		s.set_switch(79, false)
		map.refresh_events()
		MVEventCore.fixed_random = (k - 0.5) / 6.0
		var n0 := battles.size()
		var j0 := int(s.variable(206))
		await _run_event(map, SEAL, [0], "win")
		map = _scene()
		_check("seal_battle_%d" % k, battles.size() == n0 + 1 and int(s.variable(244)) == k and battles[-1].troop == 723 + k and battles[-1].result == 0, [battles.slice(n0), s.variable(244)])
		_check("seal_points_%d" % k, int(s.variable(214)) >= 2 and int(s.variable(206)) - j0 >= int(s.variable(214)), [s.variable(214), int(s.variable(206)) - j0])
		_check("seal_switch79_%d" % k, s.switch(79))
	MVEventCore.fixed_random = -1.0


## 主席与研究员的页末有 214（暂时消除事件），每次都重新进图
func _fresh(switches: Array) -> Array:
	var s := _start(UNKNOWN, 15, 10)
	if not _check("chair_loaded", await _wait_map(UNKNOWN)):
		return []
	var map: XMapScene = _scene()
	s.set_switch(79, true)
	for i in switches:
		s.set_switch(i, true)
	map.refresh_events()
	return [s, map]


func _chair() -> void:
	# 第 1 页：打招呼，开关 2225
	var r := await _fresh([])
	var s: XState = r[0]
	await _run_event(r[1], CHAIR, [], "")
	_check("chair_hello", s.switch(2225))
	# 第 2 页：默默离开
	r = await _fresh([2225])
	s = r[0]
	var n0 := battles.size()
	await _run_event(r[1], CHAIR, [2], "")
	_check("chair_leave", battles.size() == n0 and _item_total(s) == 0)
	# 要抽奖（CE1424）
	r = await _fresh([2225])
	s = r[0]
	await _run_event(r[1], CHAIR, [0], "")
	_check("chair_draw", _item_total(s) >= 1, s.items)
	# 不要则开战敌群 661
	r = await _fresh([2225])
	s = r[0]
	await _run_event(r[1], CHAIR, [1], "win")
	_check("chair_fight", battles.size() == n0 + 1 and battles[-1].troop == 661 and battles[-1].result == 0, battles.slice(n0))
	# 多抽页：开关 2226 起每页多一次 CE1424
	r = await _fresh([2225, 2226])
	s = r[0]
	await _run_event(r[1], CHAIR, [0], "")
	_check("chair_draw2", _item_total(s) >= 2, s.items)
	# 天道研究员页（开关 2302）：变量 30＝20 开战敌群 767；否则求道者小队，打晕得物品
	r = await _fresh([2302])
	s = r[0]
	MVEventCore.fixed_random = 0.99
	n0 = battles.size()
	await _run_event(r[1], CHAIR, [], "win")
	_check("researcher_fight", battles.size() == n0 + 1 and battles[-1].troop == 767 and battles[-1].result == 0, battles.slice(n0))
	r = await _fresh([2302])
	s = r[0]
	MVEventCore.fixed_random = 0.0
	n0 = battles.size()
	await _run_event(r[1], CHAIR, [0], "")
	_check("researcher_stun", battles.size() == n0 and _item_total(s) >= 1, s.items)
	r = await _fresh([2302])
	await _run_event(r[1], CHAIR, [2], "")
	MVEventCore.fixed_random = -1.0


func _item_total(s: XState) -> int:
	var n := 0
	for k in s.items:
		n += int(s.items[k])
	return n


func _exit() -> void:
	var s := _start(UNKNOWN, 9, 7)
	if not _check("exit_loaded", await _wait_map(UNKNOWN)):
		return
	var map: XMapScene = _scene()
	s.set_variable(5, 1)
	s.set_variable(6, 38)
	for i in range(75, 80):
		s.set_switch(i, true)
	await _run_event(map, EXIT, [1], "")
	_check("exit_no", _scene().map_id == UNKNOWN and s.switch(75) and int(s.variable(6)) == 38)
	await _run_event(map, EXIT, [0], "")
	_check("exit_back", await _wait_map(145) and _scene().player.grid == Vector2i(9, 37), [_scene().name])
	_check("exit_reset", int(s.variable(6)) == 0 and not s.switch(75) and not s.switch(79), [s.variable(6), s.switch(75), s.switch(79)])


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
