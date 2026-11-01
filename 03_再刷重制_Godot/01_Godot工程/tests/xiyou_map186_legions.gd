extends Node
## 神魔战场 Map186 其余八个军团（EV24～31）：变量 666～673 档 7 时连打八场（精英小队＋元帅），犒劳后换到自开关 A 页。
## 与 xiyou_map186 拆开，免得单场景逼近 300 秒。
## 分段：xiyou_map186_legions 跑 EV24～27，xiyou_map186_legions_b 跑 EV28～31（每个军团自己开新局，合计断言不变）
@export var first_event := 24
@export var last_event := 31
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 90000  # 墙钟与帧数（60 帧/秒折算）都过了、事件也不再推进才算卡住，见 wait_budget.gd
const WaitBudget := preload("res://tests/wait_budget.gd")
var results: Array = []
var battles: Array = []   # 每场：{troop, result}


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	# 换场景（传送）时测试节点不能挂在当前场景下，挂到根节点
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set("first_event", first_event)
	runner.set("last_event", last_event)
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
	var w := WaitBudget.new(TIMEOUT_MS)
	while w.waiting():
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


## 事件进度签名：打完的场数、当前战斗（哪一场、第几回合、敌人剩几个）、还没用掉的自动回答
func _progress(map: XMapScene) -> Array:
	var b := _battle_of(map)
	var alive := -1
	if b != null:
		alive = b.logic.enemies.filter(func(en): return en.is_alive()).size()
	return [battles.size(), b.get_instance_id() if b != null else 0, b.logic.turn if b != null else -1, alive, XMessageBox.auto_answers.size()]


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
	# 事件还在推进（打完一场、换了一场、回合往前、答了一句）就续等，不单靠墙钟（tools30）
	var w := WaitBudget.new(TIMEOUT_MS)
	while not st.done and w.waiting(_progress(map)):
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



const WAR := 186


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_map186_legions"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	await _other_legions()
	_finish()


func _in_war(x := 46, y := 52) -> Array:
	var s := _start(WAR, x, y)
	if not await _wait_map(WAR):
		_check("war_loaded", false)
		return []
	return [s, _scene()]


## 其余八个军团（EV24～31）：变量 666～673 档 7 时连打八场（精英小队＋元帅），犒劳后换到自开关 A 页
func _other_legions() -> void:
	for id in range(first_event, last_event + 1):
		var r := await _in_war(46, 52)
		if r.is_empty():
			return
		var s: XState = r[0]
		var map: XMapScene = r[1]
		for v in range(665, 674):
			s.set_variable(v, 7)
		var n0 := battles.size()
		await _run_event(map, id, [0, 0], "win")
		var fought: Array = battles.slice(n0).map(func(b): return b.troop)
		_check("legion%d_battles" % id, fought.size() == 8 and fought.all(func(t): return t >= 676 and t <= 693) and battles[-1].result == 0, fought)
		# EV24、25 的页序是 B、A，EV26～31 是 A、B：自开关 A 页分别是第 3、2 页的下标 2 和 1
		var want_page := 2 if id <= 25 else 1
		_check("legion%d_page_A" % id, _event(map, id).page_index == want_page, _event(map, id).page_index)


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
