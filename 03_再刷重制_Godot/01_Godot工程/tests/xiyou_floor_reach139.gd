extends Node
## 剑气长城战场（盘点簇 剑气长城，悟空_56）流程（地图场景里真走一遍）：
## - Map139 EV7 三选一：外围→Map140 (15,4)、中心→Map179 (16,16)、否；EV12（接触）→ Map189 城隍庙 (20,38)，Map189 EV20 回 Map139 (13,5)；
## - Map140 遇敌表 447～450、EV14 圣人投影（敌群 451）；Map179 遇敌表 595～598、EV1 蛮荒圣人（敌群 599）；
## - Map189：碰瓷老人 EV1（扶起扣金币＝变量 449、变量 206＋20；不理则敌群 661 并中状态 699）、黄昏的信徒 EV7（公共事件 819）、城隍 EV21 授武运。
## 原版随机分支一律固定（变量 449 的随机值、公共事件 819 的 12 选 1）；队伍生命攻击都很大（只查流程）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 240000   # 并行负载下单个事件可能跑到一两分钟，别用 90 秒的墙钟判失败
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


## 跑一段异步调用到结束，模式同 _run_event
func _run_call(map: XMapScene, call: Callable, mode := "win") -> bool:
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(func(n):
			if n is XBattleScene:
				n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT))
	var st := {"done": false}
	(func():
		await call.call()
		st.done = true).call()
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while not st.done and t0.waiting():
		var b := _battle_of(map)
		if b != null and not b.logic.enemies.is_empty() and mode == "win":
			for en in b.logic.enemies:
				if en.is_alive():
					en.hp = 0.0
					en.add_state(1)
		await get_tree().process_frame
	return _check("call_finished", st.done)


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




func _run() -> void:
	GameApp.fast_forward()  # 真走地图打战斗、等的是物理帧与计时器：headless 快进 4 倍（见 07_开发环境/测试提速.md）
	XSave.dir_override = "user://test_xiyou_floor_reach139"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261025)
	await _battlefields()
	await _temple()
	_finish()


## 剑气长城 → 外围／中心：落点、事件、遇敌表、圣人战、真实遇敌
func _battlefields() -> void:
	var s := _start(139, 13, 35, 8)
	if not _check("wall_loaded", await _wait_map(139)):
		return
	_check("wall_door_present", _event(_scene(), 7) != null and _event(_scene(), 12) != null)
	await _run_event(_scene(), 7, [2], "")
	_check("wall_no_choice_stays", _scene().map_id == 139 and _scene().player.grid == Vector2i(13, 35), [_scene().map_id])
	await _run_event(_scene(), 7, [0], "")
	if not _check("outer_entered", await _wait_map(140) and _scene().player.grid == Vector2i(15, 4), [_scene().map_id]):
		return
	var map: XMapScene = _scene()
	_check("outer_events", [1, 2, 13, 14, 15, 20].all(func(i): return _event(map, i) != null) and _event(map, 19) == null)
	_check("outer_encounters", map.map_data.encounterList.map(func(r): return int(r.troopId)) == [447, 448, 449, 450], map.map_data.encounterList)
	for r in [0, 5, 10, 15, 19]:
		_check("outer_roll%d" % r, XMapScene.encounter_troop(map.map_data.encounterList, r) == 447 + int(r / 5), r)
	var n0 := battles.size()
	await _run_event(map, 14, [], "win")
	_check("sage_projection", battles.size() == n0 + 1 and battles[-1].troop == 451 and battles[-1].result == 0, battles.slice(n0))
	# 真实遇敌：把遇敌表收成一项再让 _encounter 抽
	map = _scene()
	for tid in [447, 448, 449, 450]:
		map.map_data.encounterList = [{"troopId": tid, "weight": 5, "regionSet": []}]
		n0 = battles.size()
		await _run_call(map, func(): await map._encounter(), "win")
		_check("outer_encounter%d" % tid, battles.size() == n0 + 1 and battles[-1].troop == tid and battles[-1].result == 0, battles.slice(n0))
	# 中心
	s = _start(139, 13, 35, 8)
	if not _check("wall_loaded2", await _wait_map(139)):
		return
	await _run_event(_scene(), 7, [1], "")
	if not _check("center_entered", await _wait_map(179) and _scene().player.grid == Vector2i(16, 16), [_scene().map_id]):
		return
	map = _scene()
	_check("center_events", range(1, 6).all(func(i): return _event(map, i) != null))
	_check("center_encounters", map.map_data.encounterList.map(func(r): return int(r.troopId)) == [595, 596, 597, 598], map.map_data.encounterList)
	n0 = battles.size()
	await _run_event(map, 1, [], "win")
	_check("sage_absolute", battles.size() == n0 + 1 and battles[-1].troop == 599 and battles[-1].result == 0, battles.slice(n0))
	map = _scene()
	for tid in [595, 596, 597, 598]:
		map.map_data.encounterList = [{"troopId": tid, "weight": 5, "regionSet": []}]
		n0 = battles.size()
		await _run_call(map, func(): await map._encounter(), "win")
		_check("center_encounter%d" % tid, battles.size() == n0 + 1 and battles[-1].troop == tid and battles[-1].result == 0, battles.slice(n0))


## 城隍庙：进出、碰瓷老人（两条路）、黄昏的信徒、城隍授武运
func _temple() -> void:
	var s := _start(139, 13, 5, 2)
	if not _check("wall2_loaded", await _wait_map(139)):
		return
	await _run_event(_scene(), 12, [], "")
	if not _check("temple_entered", await _wait_map(189) and _scene().player.grid == Vector2i(20, 38), [_scene().map_id]):
		return
	var map: XMapScene = _scene()
	_check("temple_events", [1, 2, 7, 9, 17, 20, 21, 22].all(func(i): return _event(map, i) != null))
	# 老人：扶起扣钱
	s.gold = 1000000000
	s.set_variable(206, 0)
	await _run_event(map, 1, [0], "")
	var paid := 1000000000 - s.gold
	_check("oldman_pay", paid == int(s.variable(449)) and paid >= 0 and paid <= 99999999 and int(s.variable(206)) == 20 and s.self_switch(189, 1, "A"), [paid, s.variable(449), s.variable(206)])
	var n0 := battles.size()
	await _run_event(map, 1, [], "")
	_check("oldman_page2_no_battle", battles.size() == n0 and s.gold == 1000000000 - paid)
	# 老人：不理→主席；打赢无事，战败（可败）全队中重伤 699
	s.set_self_switch(189, 1, "A", false)
	map.refresh_events()
	await _run_event(map, 1, [1], "win")
	_check("oldman_refuse_win", battles.size() == n0 + 1 and battles[-1].troop == 661 and battles[-1].result == 0 and s.members().all(func(a): return not a.is_state_affected(699)), battles.slice(n0))
	s.set_self_switch(189, 1, "A", false)
	map.refresh_events()
	n0 = battles.size()
	await _run_event(map, 1, [1], "lose")
	_check("oldman_refuse_lose", battles.size() == n0 + 1 and battles[-1].troop == 661 and battles[-1].result != 0 and s.members().all(func(a): return a.is_state_affected(699)), [battles.slice(n0), s.members().map(func(a): return [a.actor_id, a.is_state_affected(699)])])
	map = _scene()
	for a in s.members():
		a.hp = a.mhp
	# 信徒：队里没有艾鲲（3）→ 台词；有则走公共事件 819
	map = _scene()
	await _run_event(map, 7, [], "")
	_check("believer_no_ai", int(s.variable(346)) == 0 and not s.self_switch(189, 7, "A"), [s.variable(346)])
	s.add_actor(3)
	await _run_event(map, 7, [], "")
	_check("believer_found", int(s.variable(346)) == 1 and s.self_switch(189, 7, "A"), [s.variable(346)])
	# 城隍授武运
	map.refresh_events()
	await _run_event(map, 21, [0, 0], "")
	var ok := true
	for id in [8, 9, 10]:
		var a: XActor = s.actor(id)
		ok = ok and a.skill_ids.has(3920) and not a.skill_ids.has(3921)
	_check("chenghuang_blessing", ok and s.actor(1).skill_ids.has(3921) and not s.actor(1).skill_ids.has(3920) and s.self_switch(189, 21, "A"))
	await _run_event(map, 22, [], "")
	# 出口
	await _run_event(map, 20, [], "")
	_check("temple_exit", await _wait_map(139) and _scene().player.grid == Vector2i(13, 5), [_scene().map_id])


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
