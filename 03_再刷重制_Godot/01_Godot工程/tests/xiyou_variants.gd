extends Node
## 轮回／求道者变体：各层守层者事件在开关 2302／2303（求道者单挑，敌群 748～765）与 2307（「我们联合」联合战，敌群 798～814）下
## 走对应页、开对应敌群、跑完不跳过任何指令（原版 Map030 第 8 号起共 18 张图 19 个事件）。敌群本身的战斗事件由 xiyou_troop_events 对照参照。
## 用例按序号轮流分 parts 份，一个场景管一份（xiyou_variants 第 0 份、xiyou_variants_b 第 1 份；困难模式在最后一份），
## 免得单场景满载时逼近 600 秒超时线（木吒 2026-10-25，单跑约 280 秒）；各份断言数相加与拆分前相同。
@export var part := 0
@export var parts := 1
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
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
	runner.set("part", part)
	runner.set("parts", parts)
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



const LEGACIES := [[0, 814, 778, 6219, 857], [1, 815, 779, 6233, 881], [2, 816, 776, 6227, 882], [3, 817, 777, 6223, 883], [4, 824, 785, 2829, 884]]



## [地图, 事件, 开关 2302 的敌群, 2303 的敌群, 2307 的敌群]
const CASES := [[30, 8, 749, 749, 799], [32, 1, 750, 750, 800], [33, 3, 751, 751, 801], [45, 1, 752, 752, 802], [46, 1, 753, 753, 803],
	[47, 13, 754, 754, 804], [64, 1, 748, 748, 798], [116, 1, 755, 755, 805], [117, 1, 756, 756, 806], [118, 3, 758, 758, 808],
	[119, 13, 757, 757, 807], [120, 1, 759, 759, 809], [144, 1, 764, 764, 813], [145, 1, 763, 763, 812], [146, 1, 765, 765, 814],
	[147, 1, 760, 760, 810], [155, 1, 761, 761, 761], [182, 1, 762, 762, 811]]
const SWITCHES := [2302, 2303, 2307]


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_variants"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	for i in CASES.size():
		if i % parts != part:
			continue
		var c: Array = CASES[i]
		for k in range(3):
			var tag := "map%d_ev%d_sw%d" % [c[0], c[1], SWITCHES[k]]
			var s := _start(c[0], 1, 1)
			if not _check(tag + "_loaded", await _wait_map(c[0])):
				continue
			var map: XMapScene = _scene()
			s.set_switch(SWITCHES[k], true)
			map.refresh_events()
			var n0 := battles.size()
			if not await _run_event(map, c[1], [], "win"):
				continue
			var fought: Array = battles.slice(n0).map(func(b): return b.troop)
			_check(tag + "_battle", fought == [c[2 + k]], fought)
			var sk: Array = _scene().skipped_log if _scene() is XMapScene else []
			_check(tag + "_no_skipped", sk.is_empty(), sk)
	if part == parts - 1:
		await _hard_mode()
	_finish()


## 公共事件 1435 轮回模式·困难：开关 2282 时按层数档全员学 8106…，变量 1173 记档（原先被整个跳过）
func _hard_mode() -> void:
	var s := _start(32, 1, 1)
	if not _check("hard_loaded", await _wait_map(32)):
		return
	var map: XMapScene = _scene()
	s.set_switch(2307, true)
	s.set_switch(2282, true)
	s.set_variable(20, 6)
	map.refresh_events()
	await _run_event(map, 1, [], "win")
	_check("hard_1173", int(s.variable(1173)) >= 1, s.variable(1173))
	_check("hard_learned", s.leader().skill_ids.has(8106), s.leader().skill_ids.size())


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
