extends Node
## 真火秘境（盘点簇 4，悟空_54）流程（地图场景里真走一遍）：
## - Map012 EV28（页条件：开关 2284「极寒之毒」，公共事件 1552 小明二阶基因锁置位）→ Map222 (36,30)；
## - 传送点成对互传（EV2⇄EV5 等）；炎灵 EV3／4／10／13／14（敌群 821）胜后暂时消除；
## - EV1 真火草：摘取→敌群 822、物品 1415 +1、关开关 2284 回 Map012 (21,15)；EV15 传送门回 Map012 (21,15)。
## 队伍生命攻击都很大（只查流程）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
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
	XSave.dir_override = "user://test_xiyou_floor_reach222"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261024)
	await _fire()
	_finish()


func _fire() -> void:
	var s := _start(12, 21, 15, 8)
	if not _check("fire_door_loaded", await _wait_map(12)):
		return
	var map: XMapScene = _scene()
	_check("fire_door_present", _event(map, 28) != null)
	# 开关 2284 关着时入口页不出现：事件无可执行页，留在原图
	await _run_event(map, 28, [], "")
	_check("fire_door_closed", _scene().map_id == 12, [_scene().map_id])
	s.set_switch(2284, true)
	map.refresh_events()
	await _run_event(map, 28, [], "")
	if not _check("fire_entered", await _wait_map(222) and _scene().player.grid == Vector2i(36, 30), [_scene().map_id]):
		return
	map = _scene()
	_check("fire_events", range(1, 16).all(func(i): return _event(map, i) != null))
	# 成对传送点
	await _run_event(map, 2, [], "")
	_check("fire_pad_2", await _wait_map(222) and _scene().player.grid == Vector2i(8, 30), [_scene().player.grid])
	await _run_event(_scene(), 5, [], "")
	_check("fire_pad_5", _scene().player.grid == Vector2i(27, 30), [_scene().player.grid])
	await _run_event(_scene(), 11, [], "")
	_check("fire_pad_11", _scene().player.grid == Vector2i(24, 12), [_scene().player.grid])
	# 炎灵
	var n0 := battles.size()
	await _run_event(_scene(), 3, [], "win")
	_check("fire_spirit_fight", battles.size() == n0 + 1 and battles[-1].troop == 821 and battles[-1].result == 0, [battles.slice(n0)])
	# 真火草
	n0 = battles.size()
	var bag0 := s.item_count(1415)
	await _run_event(_scene(), 1, [0], "win")
	_check("fire_grass_fight", battles.size() == n0 + 1 and battles[-1].troop == 822 and battles[-1].result == 0, [battles.slice(n0)])
	_check("fire_grass_item", s.item_count(1415) == bag0 + 1, [bag0, s.item_count(1415)])
	_check("fire_grass_back", await _wait_map(12) and _scene().player.grid == Vector2i(21, 15) and not s.switch(2284), [_scene().map_id, s.switch(2284)])
	# 传送门：再进再出
	s.set_switch(2284, true)
	_scene().refresh_events()
	await _run_event(_scene(), 28, [], "")
	if _check("fire_reentered", await _wait_map(222)):
		await _run_event(_scene(), 15, [0], "")
		_check("fire_exit", await _wait_map(12) and _scene().player.grid == Vector2i(21, 15), [_scene().map_id])


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
