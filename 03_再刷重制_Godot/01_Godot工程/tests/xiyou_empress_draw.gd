extends Node
## 洪荒技能书随机抽奖（物品 1653 的效果＝公共事件 1441「洪荒技能抽奖·增益」）：变量 1481 取 1～10 十档，每档给一本技能书（物品 1642～1652），
## 另有档位的附带效果——第 2 档肝帝积分（＋30 万再乘 5）、第 3 档抽奖被动上限（变量 9）＋20、第 4 档开关 2482（解锁洪荒女皇）＋人道碎片 2530 ×2000、
## 第 9 档开关 2464。每次都开关 2483、变量 1482＝1。事件列表直接交给地图场景的解释器跑；对照参照见 xiyou_event_compare（公共事件 1441 已入切片 extraCommonEvents）。
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



## [档, 技能书物品 ID 列表]
const DRAWS := [[1, [1642]], [2, [1643]], [3, [1644]], [4, [1645]], [5, [1646]], [6, [1647]], [7, [1648]], [8, [1649, 1650]], [9, [1651]], [10, [1652]]]


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_empress_draw"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	for d in DRAWS:
		await _draw(d[0], d[1])
	_finish()


func _draw(k: int, books: Array) -> void:
	var tag := "draw%d" % k
	var s := _start(4, 10, 10)
	if not _check(tag + "_loaded", await _wait_map(4)):
		return
	var map: XMapScene = _scene()
	s.set_variable(206, 1000)
	s.set_variable(9, 5)
	var points0 := int(s.variable(206))
	MVEventCore.fixed_random = (k - 0.5) / 10.0
	var interp := MVInterpreter.new(map, 4, 0, [{"code": 117, "indent": 0, "parameters": [1441]}])
	await interp.run()
	MVEventCore.fixed_random = -1.0
	_check(tag + "_level", int(s.variable(1481)) == k, s.variable(1481))
	_check(tag + "_flags", s.switch(2483) and int(s.variable(1482)) == 1)
	for id in books:
		_check(tag + "_book_%d" % id, s.item_count(id) == 1, s.item_count(id))
	_check(tag + "_skipped", interp.skipped.is_empty(), interp.skipped)
	_check(tag + "_points", int(s.variable(206)) == (points0 + 300000) * 5 if k == 2 else int(s.variable(206)) == points0, s.variable(206))
	_check(tag + "_cap", int(s.variable(9)) == (25 if k == 3 else 5), s.variable(9))
	_check(tag + "_humanity", (s.switch(2482) and s.item_count(2530) == 2000) if k == 4 else (not s.switch(2482) and s.item_count(2530) == 0), [s.switch(2482), s.item_count(2530)])
	_check(tag + "_welfare", s.switch(2464) == (k == 9), s.switch(2464))


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
