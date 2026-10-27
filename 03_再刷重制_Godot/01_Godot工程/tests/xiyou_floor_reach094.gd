extends Node
## 通天之上外的野外四图与北丑居（地图场景里真走一遍）：
## - 猛虎岭 94（天之上 EV52 进 (38,44)，出口 EV1 回 (93,66)）、洛水河畔 92（EV53 进 (34,0)，出口 EV1～3 回 (13,85)）、
##   猴山 93（EV55 进 (30,0)，出口 EV4～6 回 (86,76)，EV3 闲谈）、鹿吴山 105（EV56 进 (30,29)，出口 EV1 回 (39,73)，EV3 克苏鲁使徒认证）；
##   每张图查遇敌表（敌群与权重）并真遇敌打完一场；各图 EV2／EV4 的 !Flame 是原版遗留的测试战斗（敌群 1），不踩。
## - 北丑居 90（EV45 进 (8,13)，出口 EV8 回 (64,6)，EV4 南贤「进行修炼」开修炼界面）。
## 队伍生命攻击都很大（只查流程）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 240000   # 并行负载下单个事件可能跑到一两分钟，别用 90 秒的墙钟判失败

var results: Array = []
var battles: Array = []   # 每场：{troop, result}
var trainings := 0


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


func _start(map_id: int, x: int, y: int, dir := 8) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = dir
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	return s



func _run_call(map: XMapScene, call: Callable, mode := "win") -> bool:
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(func(n):
			print("DBG child ", n.get_class(), " ", n.name)
			if n is XBattleScene:
				n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT)
			elif n is XTrainingScene:
				print("DBG training child")
				trainings += 1
				(func(): n.closed.emit()).call_deferred())
	var st := {"done": false}
	(func():
		await call.call()
		st.done = true).call()
	var t0 := Time.get_ticks_msec()
	while not st.done and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var b := _battle_of(map)
		if b != null and not b.logic.enemies.is_empty() and mode == "win":
			for en in b.logic.enemies:
				if en.is_alive():
					en.hp = 0.0
					en.add_state(1)
		await get_tree().process_frame
	return _check("call_finished", st.done)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_reach094"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261026)
	if OS.get_environment("ONLY_BC") == "1":
		await _beichou()
		_finish()
		return
	# 进口事件、进入点、出口事件、出口面向（EV111 条件）、回到天之上的位置、遇敌表敌群
	await _field("tiger", 52, 8, 94, Vector2i(38, 44), [1, 2], 2, Vector2i(93, 66), [303, 304, 305, 306, 544, 545, 546, 547, 548])
	await _field("luo", 53, 2, 92, Vector2i(34, 0), [1, 2, 3, 4], 8, Vector2i(13, 85), [307, 308, 309, 310, 570, 571, 572, 573, 574, 575])
	await _field("monkey", 55, 2, 93, Vector2i(30, 0), [1, 2, 3, 4, 5, 6], 8, Vector2i(86, 76), [328, 329, 330, 331, 470, 471, 472, 473, 474])
	await _field("deer", 56, 8, 105, Vector2i(30, 29), [1, 2, 3], 2, Vector2i(39, 73), [339, 340, 341, 342, 539, 540, 541, 542])
	await _beichou()
	_finish()


## 一张野外图：进、事件在、遇敌表、真遇敌打完一场、出
func _field(tag: String, enter_ev: int, enter_dir: int, map_id: int, arrive: Vector2i, events: Array, exit_dir: int, back: Vector2i, troops: Array) -> void:
	_start(69, back.x, back.y, enter_dir)
	if not _check(tag + "_sky", await _wait_map(69)):
		return
	await _run_event(_scene(), enter_ev, [], "")
	if not _check(tag + "_entered", await _wait_map(map_id) and _scene().player.grid == arrive, [_scene().map_id, _scene().player.grid]):
		return
	var map: XMapScene = _scene()
	_check(tag + "_events", events.all(func(i): return _event(map, i) != null))
	_check(tag + "_table", map.map_data.encounterList.map(func(r): return int(r.troopId)) == troops, map.map_data.encounterList)
	# 每个敌群都抽得到
	var total := 0
	for r in map.map_data.encounterList:
		total += int(r.weight)
	var seen := {}
	for r in range(total):
		seen[XMapScene.encounter_troop(map.map_data.encounterList, r)] = true
	_check(tag + "_rolls", seen.keys().size() == troops.size() and troops.all(func(t): return seen.has(t)), seen.keys())
	# 真遇敌：原遇敌表整张抽一次，打完
	var n0 := battles.size()
	await _run_call(map, func(): await map._encounter(), "win")
	_check(tag + "_encounter", battles.size() == n0 + 1 and troops.has(int(battles[-1].troop)) and battles[-1].result == 0, battles.slice(n0))
	# 出口（面向条件）
	map = _scene()
	map.player.direction = exit_dir
	await _run_event(map, events[0] if tag != "monkey" else 4, [], "")
	_check(tag + "_back", await _wait_map(69) and _scene().player.grid == back, [_scene().map_id, _scene().player.grid])


## 北丑居：进、南贤（修炼界面）、出
func _beichou() -> void:
	_start(69, 64, 6, 8)
	if not _check("bc_sky", await _wait_map(69)):
		return
	await _run_event(_scene(), 45, [], "")
	if not _check("bc_entered", await _wait_map(90) and _scene().player.grid == Vector2i(8, 13), [_scene().map_id, _scene().player.grid]):
		return
	var map: XMapScene = _scene()
	_check("bc_events", _event(map, 4) != null and _event(map, 8) != null)
	var t0 := trainings
	print("DBG run1")
	await _run_call(map, func(): await _run_event(map, 4, [0], ""), "")
	print("DBG codes ", _event(map, 4).command_list().map(func(c): return [c.code, c.parameters]))
	print("DBG run1 done ", XState.current.self_switch(90, 4, "A") if XState.current.has_method("self_switch") else "?")   # 第一页：闲话，开独立开关 A
	await _run_call(map, func(): await _run_event(map, 4, [0], ""), "")   # 第二页：进行修炼
	_check("bc_training", trainings == t0 + 1, [t0, trainings])
	await _run_event(map, 8, [], "")
	_check("bc_back", await _wait_map(69) and _scene().player.grid == Vector2i(64, 6), [_scene().map_id, _scene().player.grid])


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
