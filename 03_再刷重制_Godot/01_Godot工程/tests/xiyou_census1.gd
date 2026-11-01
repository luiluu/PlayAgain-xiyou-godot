extends Node
## 盘点第一批（悟空_45）：信徒的藏身点 Map188（Map013 EV7 进，坤坤任务的黄昏的信徒、出口回 Map013）、信徒藏匿处 Map194
## （Map046 EV4 进，黄昏的信徒、古怪的恶魔换被动书、出口回 Map046）、决战：天外天 Map158（大厅门变量 20＝34 进，洪荒通关页）。
## 走地图场景真走一遍。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 90000
const WaitBudget := preload("res://tests/wait_budget.gd")  # 墙钟与帧数都过了才算超时（tools30）
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
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while t0.waiting():
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
		XActor.test_param_max = 1.0e30  # 队伍属性堆过原版上限 99999999（XActor.PARAM_MAX），只在测试里放开
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
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while not st.done and t0.waiting():
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



const LEGACIES := [[0, 814, 778, 6219, 857], [1, 815, 779, 6233, 881], [2, 816, 776, 6227, 882], [3, 817, 777, 6223, 883], [4, 824, 785, 2829, 884]]



func _run() -> void:
	XSave.dir_override = "user://test_xiyou_census1"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	await _hideout188()
	await _hideout194()
	await _altar158()
	_finish()


func _at(map_id: int, x: int, y: int) -> Array:
	var s := _start(map_id, x, y)
	if not _check("loaded_%d" % map_id, await _wait_map(map_id)):
		return []
	return [s, _scene()]


func _hideout188() -> void:
	var r := await _at(13, 36, 21)
	if r.is_empty():
		return
	await _run_event(r[1], 7, [], "")
	_check("m13_to_188", await _wait_map(188) and _scene().player.grid == Vector2i(12, 12), [_scene().name])
	var map: XMapScene = _scene()
	var s: XState = r[0]
	# 黄昏的信徒：队伍有艾坤（角色 3）时公共事件 12信徒，变量 346 加一
	var v0 := int(s.variable(346))
	await _run_event(map, 1, [], "")
	_check("m188_cultist_no_ai_kun", int(s.variable(346)) == v0 or s.members().any(func(a): return int(a.actor_id) == 3), s.variable(346))
	var s2 := _start(188, 7, 10)
	s2.add_actor(3)
	_check("m188_reloaded", await _wait_map(188))
	var map2: XMapScene = _scene()
	var v1 := int(s2.variable(346))
	await _run_event(map2, 1, [], "")
	_check("m188_cultist_found", int(s2.variable(346)) == v1 + 1, [v1, s2.variable(346)])
	_check("m188_cultist_page2", _event(map2, 1).page_index == 1, _event(map2, 1).page_index)
	await _run_event(map2, 2, [], "")
	_check("m188_back", await _wait_map(13) and _scene().player.grid == Vector2i(36, 20), [_scene().name])


func _hideout194() -> void:
	var r := await _at(46, 30, 13)
	if r.is_empty():
		return
	await _run_event(r[1], 4, [], "")
	_check("m46_to_194", await _wait_map(194) and _scene().player.grid == Vector2i(4, 8), [_scene().name])
	var map: XMapScene = _scene()
	var s: XState = r[0]
	# 古怪的恶魔（变量 14＝1 时）：要 3 把尸山血海（武器 1105）换被动书 1983
	s.set_variable(14, 1)
	map.refresh_events()
	await _run_event(map, 3, [0], "")
	_check("m194_demon_short", s.item_count(1983) == 0 and not s.self_switch(194, 3, "A"))
	s.gain_gear("weapon", 1105, 2)
	await _run_event(map, 3, [0], "")
	_check("m194_demon_short2", s.item_count(1983) == 0 and s.gear_count("weapon", 1105) == 2)
	s.gain_gear("weapon", 1105, 1)
	await _run_event(map, 3, [0], "")
	_check("m194_demon_trade", s.item_count(1983) == 1 and s.gear_count("weapon", 1105) == 0 and s.self_switch(194, 3, "A"), [s.item_count(1983), s.gear_count("weapon", 1105)])
	await _run_event(map, 2, [], "")
	_check("m194_back", await _wait_map(46) and _scene().player.grid == Vector2i(30, 13), [_scene().name])


func _altar158() -> void:
	var r := await _at(4, 7, 33)
	if r.is_empty():
		return
	var s: XState = r[0]
	s.set_variable(20, 34)
	r[1].refresh_events()
	await _run_event(r[1], 36, [], "")
	_check("lobby_to_158", await _wait_map(158) and _scene().player.grid == Vector2i(7, 33), [_scene().name, _scene().player.grid])
	var map: XMapScene = _scene()
	# 页 1（无条件的默认页）：开关 2483 未开只说「前面都没开呢」；原版页 0（自开关 D 的古龙祭坛入口）被无条件的页 1 永远盖住、没有事件设 D，照放不测
	s.set_variable(1476, 0)
	await _run_event(map, 1, [], "")
	_check("m158_default_closed", _scene().map_id == 158 and int(s.variable(1476)) == 0 and not s.self_switch(158, 1, "A"))
	# 开关 2483：变量 1475≠1 → 「没打鸿钧」全队学 6213
	s.set_switch(2483, true)
	s.set_variable(1475, 0)
	await _run_event(map, 1, [], "")
	_check("m158_skipped_boss", s.leader().skill_ids.has(6213) or XDB.rec("Skills", 6213).is_empty(), s.leader().skill_ids.size())
	# 变量 1475＝1：保存提示选「是」→ 变量 1476＝1，自开关 A 页
	s.set_variable(1475, 1)
	await _run_event(map, 1, [0], "")
	_check("m158_clear_reward", int(s.variable(1476)) == 1 and s.self_switch(158, 1, "A"), [s.variable(1476), s.self_switch(158, 1, "A")])
	await _run_event(map, 1, [], "")
	_check("m158_after_clear", _scene().map_id == 158 and _event(map, 1).page_index == 2, _event(map, 1).page_index)


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
