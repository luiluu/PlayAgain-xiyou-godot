extends Node
## 传承人（Map116 EV7，二十层大厅门图）：开关 2303／2307 时的传承页（五条传承各打一场【传承者】敌群 776～779／785，
## 胜后公共事件学技能、变量 814～817／824 记已得，再来只说「已经获得」）；变量 20≥21 的页是「传承之火已熄」。
## 走地图场景真走一遍；数值与事件对照由 xiyou_event_compare 承担。
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



const MAP_ID := 116
const HEIR := 7
## [选项, 变量, 敌群, 学到的技能, 记录学习者的变量]
const LEGACIES := [[0, 814, 778, 6219, 857], [1, 815, 779, 6233, 881], [2, 816, 776, 6227, 882], [3, 817, 777, 6223, 883], [4, 824, 785, 2829, 884]]


func _run() -> void:
	GameApp.fast_forward()  # 真走地图打战斗、等的是物理帧与计时器：headless 快进 4 倍（见 07_开发环境/测试提速.md）
	XSave.dir_override = "user://test_xiyou_heir116"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	for sw in [2303, 2307]:
		await _legacies(sw)
	await _extinguished()
	_finish()


func _fresh(sw: int) -> Array:
	var s := _start(MAP_ID, 21, 21)
	if not _check("heir_loaded", await _wait_map(MAP_ID)):
		return []
	var map: XMapScene = _scene()
	if sw > 0:
		s.set_switch(sw, true)
	map.refresh_events()
	return [s, map]


func _legacies(sw: int) -> void:
	var tag := "sw%d_" % sw
	var r := await _fresh(sw)
	if r.is_empty():
		return
	var s: XState = r[0]
	var map: XMapScene = r[1]
	var leader = s.leader()
	var aid := int(leader.actor_id)
	# 选「离开」：什么也不变
	var b0 := battles.size()
	await _run_event(map, HEIR, [5], "")
	_check(tag + "leave", battles.size() == b0)
	for L in LEGACIES:
		s.set_variable(L[4], aid)
		var n0 := battles.size()
		await _run_event(map, HEIR, [L[0]], "win")
		map = _scene()
		_check(tag + "battle_%d" % L[0], battles.size() == n0 + 1 and battles[-1].troop == L[2] and battles[-1].result == 0, battles.slice(n0))
		_check(tag + "flag_%d" % L[0], int(s.variable(L[1])) == 1, s.variable(L[1]))
		_check(tag + "skill_%d" % L[0], leader.skill_ids.has(L[3]), L[3])
		# 再选同一条：已获得，不再开战
		n0 = battles.size()
		await _run_event(map, HEIR, [L[0]], "win")
		_check(tag + "again_%d" % L[0], battles.size() == n0)


func _extinguished() -> void:
	for sw in [2303, 2307]:
		var r := await _fresh(sw)
		if r.is_empty():
			return
		var s: XState = r[0]
		s.set_variable(20, 21)
		r[1].refresh_events()
		var n0 := battles.size()
		await _run_event(r[1], HEIR, [0], "win")
		_check("fire_out_%d" % sw, battles.size() == n0 and int(s.variable(814)) == 0)


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
