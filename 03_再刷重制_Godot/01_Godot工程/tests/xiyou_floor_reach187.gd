extends Node
## 水栽培与黑作坊簇（盘点簇 13，悟空_55）流程（地图场景里真走一遍）：
## - Map004 EV37 → Map187 水栽培 (1,9)；EV1 回 Map004 (24,16)；
## - 青霞 EV2：「重置仓库」走插件指令 PHWarehouse remove／create；
## - 菜地 EV3：开关 382 空地时选「大麻叶」扣种子 899、开关 383 开；熟了（玩了 ≥30 秒）收获 → 公共事件 917 随机给大麻叶，种子可能多得；
## - EV102 按开关 1794／1795 进 Map218／219，否则 Map217 黑作坊；作坊里 EV1 回水栽培 (11,15)；
##   Map217 EV11 作坊小妹选「生产间」置位 1981 等一批开关并记变量 753，选「我再想想」不变；
##   打工位 EV2 页 1（开关 1820）公共事件 1098 招人：选狗逍遥队员离开、开关 1801 开 1820 关。
## 原版随机固定（固定随机数）。队伍生命攻击都很大（只查流程）。
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
	XSave.dir_override = "user://test_xiyou_floor_reach187"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261024)
	await _garden()
	await _workshop()
	MVEventCore.fixed_random = -1.0
	_finish()


func _garden() -> void:
	var s := _start(4, 25, 17, 8)
	if not _check("garden_loaded", await _wait_map(4)):
		return
	var map: XMapScene = _scene()
	_check("garden_door_present", _event(map, 37) != null)
	await _run_event(map, 37, [], "")
	if not _check("garden_entered", await _wait_map(187) and _scene().player.grid == Vector2i(1, 9), [_scene().map_id]):
		return
	map = _scene()
	_check("garden_events", [1, 2, 3, 4, 5, 102].all(func(i): return _event(map, i) != null))
	# 青霞：重置仓库 → 我以取出重要物品（remove／create）
	await _run_event(map, 2, [1, 0], "")
	# 菜地：开关 382 为空地
	s.set_switch(382, true)
	map.refresh_events()
	s.gain_item(899, 1)
	await _run_event(map, 3, [0, 0, 1], "")
	_check("plant_seed_used", s.item_count(899) == 0, [s.item_count(899)])
	_check("plant_switches", s.switch(383) and not s.switch(382), [s.switch(382), s.switch(383)])
	map.refresh_events()
	# 没熟：提示后等 30 秒
	s.set_variable(321, 1.0e9)
	await _run_event(map, 3, [], "")
	_check("plant_not_ripe", s.switch(383) and not s.switch(382))
	# 熟了：收获，随机数固定为 0.99（大麻叶暴击＋额外种子都不出）与 0（出）
	s.set_variable(321, -100000)
	MVEventCore.fixed_random = 0.99
	var leaf0 := s.item_count(898)
	await _run_event(map, 3, [0], "")
	_check("harvest_leaf", s.item_count(898) > leaf0, [leaf0, s.item_count(898)])
	_check("harvest_reset", s.switch(382) and not s.switch(383), [s.switch(382), s.switch(383)])
	# 回超越大厅
	await _run_event(map, 1, [], "")
	_check("garden_back", await _wait_map(4) and _scene().player.grid == Vector2i(24, 16), [_scene().map_id, _scene().player.grid])


func _workshop() -> void:
	var s := _start(187, 11, 15, 2)
	if not _check("shop_door_loaded", await _wait_map(187)):
		return
	# 默认黑作坊 217
	await _run_event(_scene(), 102, [], "")
	if not _check("shop_entered", await _wait_map(217) and _scene().player.grid == Vector2i(11, 1), [_scene().map_id]):
		return
	var map: XMapScene = _scene()
	_check("shop_events", [1, 2, 3, 11].all(func(i): return _event(map, i) != null))
	# 作坊小妹：我再想想，不动开关
	await _run_event(map, 11, [3], "")
	_check("shop_think", not s.switch(1981), [s.switch(1981)])
	# 生产间：开关置位
	await _run_event(map, 11, [0], "")
	_check("shop_open", s.switch(1981) and s.switch(1793), [s.switch(1981), s.switch(1793)])
	map.refresh_events()
	# 打工位：1 号打工位（开关 1820）招狗逍遥（1 号队员）
	s.set_switch(1820, true)
	s.add_actor(1)
	map.refresh_events()
	_check("shop_hire_has_actor", s.members().any(func(a): return a.actor_id == 1))
	await _run_event(map, 2, [0], "")
	_check("shop_hire_left", not s.members().any(func(a): return a.actor_id == 1) and s.switch(1801) and not s.switch(1820), [s.switch(1801), s.switch(1820)])
	await _run_event(map, 1, [], "")
	_check("shop_back", await _wait_map(187) and _scene().player.grid == Vector2i(11, 15), [_scene().map_id, _scene().player.grid])
	# 开关 1794：黑作坊 218；1795：219
	s.set_switch(1794, true)
	await _run_event(_scene(), 102, [], "")
	_check("shop218", await _wait_map(218) and _scene().player.grid == Vector2i(11, 1), [_scene().map_id])
	await _run_event(_scene(), 1, [], "")
	if await _wait_map(187):
		s.set_switch(1794, false)
		s.set_switch(1795, true)
		await _run_event(_scene(), 102, [], "")
		_check("shop219", await _wait_map(219) and _scene().player.grid == Vector2i(11, 1), [_scene().map_id])
		await _run_event(_scene(), 1, [], "")
		_check("shop219_back", await _wait_map(187))


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
