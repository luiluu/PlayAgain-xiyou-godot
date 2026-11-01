extends Node
## 小簇（盘点簇 7／10／14，悟空_55）流程（地图场景里真走一遍）：
## - 簇 7：Map004 EV66（页条件：开关 2464「气运昌隆」＋玩家朝上）→ Map224 洪荒宝宝之家 (9,18)；EV3「天之上」回 Map004 (7,6)；
##   遇敌表 10 个洪荒敌群（848～857）能开战；
## - 簇 10：Map061 EV6 → Map178 民宅 (10,13)；EV5 回 Map061 (21,6) 后插件指令 Autosave：存到最近用过的存档位（没手动存过就不存）；
##   Map178 EV6 黄昏的信徒、EV7 求道者·斯盖能跑完。
## 队伍生命攻击都很大（只查流程）。
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
	XSave.dir_override = "user://test_xiyou_floor_reach224"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261024)
	await _baby()
	await _house()
	_finish()


## 洪荒宝宝簇：EV66 要开关 2464 且玩家朝上
func _baby() -> void:
	var s := _start(4, 7, 6, 8)
	if not _check("baby_door_loaded", await _wait_map(4)):
		return
	var map: XMapScene = _scene()
	_check("baby_door_present", _event(map, 66) != null)
	# 开关 2464 关着：入口页不出现
	await _run_event(map, 66, [], "")
	_check("baby_door_closed", _scene().map_id == 4, [_scene().map_id])
	s.set_switch(2464, true)
	map.refresh_events()
	# 朝下：留在原图
	map.player.set_direction(2)
	await _run_event(map, 66, [], "")
	_check("baby_door_facing_down_stays", _scene().map_id == 4, [_scene().map_id])
	map.player.set_direction(8)
	await _run_event(map, 66, [], "")
	if not _check("baby_entered", await _wait_map(224) and _scene().player.grid == Vector2i(9, 18), [_scene().map_id]):
		return
	map = _scene()
	_check("baby_events", range(1, 4).all(func(i): return _event(map, i) != null))
	var tab: Array = XDB.map(224).get("encounterList", [])
	_check("baby_encounters", tab.map(func(r): return int(r.troopId)) == [855, 856, 850, 848, 849, 857, 851, 852, 853, 854], tab)
	# 遇敌表里每个敌群都能开战并打赢
	for r in tab:
		await _fight(map, int(r.troopId))
	await _run_event(map, 3, [], "")
	_check("baby_back", await _wait_map(4) and _scene().player.grid == Vector2i(7, 6), [_scene().map_id, _scene().player.grid])


## 开战（同遇敌：start_battle），战斗一开始击倒全部敌人
func _fight(map: XMapScene, troop: int) -> void:
	var n0 := battles.size()
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(func(n):
			if n is XBattleScene:
				n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT))
	var st := {"done": false}
	(func():
		await map.start_battle(troop, true, false)
		st.done = true).call()
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while not st.done and t0.waiting():
		var b := _battle_of(map)
		if b != null and not b.logic.enemies.is_empty():
			for en in b.logic.enemies:
				if en.is_alive():
					en.hp = 0.0
					en.add_state(1)
		await get_tree().process_frame
	_check("fight_%d" % troop, st.done and battles.size() == n0 + 1 and battles[-1].troop == troop and battles[-1].result == 0, [battles.slice(n0)])


## 民宅簇：Map061 EV6 进、Map178 EV5 出并 Autosave
func _house() -> void:
	var s := _start(61, 21, 7, 8)
	if not _check("house_door_loaded", await _wait_map(61)):
		return
	var map: XMapScene = _scene()
	_check("house_door_present", _event(map, 6) != null)
	await _run_event(map, 6, [], "")
	if not _check("house_entered", await _wait_map(178) and _scene().player.grid == Vector2i(10, 13), [_scene().map_id]):
		return
	map = _scene()
	_check("house_events", range(1, 8).all(func(i): return _event(map, i) != null))
	# 信徒、求道者：对话跑完（没有队员 3 走「否则」分支；求道者选「离开」）
	await _run_event(map, 6, [], "")
	await _run_event(map, 7, [1], "")
	# 没手动存过：出门不存档
	XSave.current_slot = 0
	await _run_event(map, 5, [], "")
	_check("house_exit", await _wait_map(61) and _scene().player.grid == Vector2i(21, 6), [_scene().map_id, _scene().player.grid])
	_check("autosave_none", not XSave.exists(3))
	# 手动存过（最近存档位 3）：再进再出，Autosave 写入该位
	XSave.current_slot = 3
	await _run_event(_scene(), 6, [], "")
	if _check("house_reentered", await _wait_map(178)):
		await _run_event(_scene(), 5, [], "")
		_check("house_exit2", await _wait_map(61) and _scene().player.grid == Vector2i(21, 6), [_scene().map_id])
		_check("autosave_written", XSave.exists(3) and not XSave.exists(1) and not XSave.exists(2))
	XSave.current_slot = 0


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
