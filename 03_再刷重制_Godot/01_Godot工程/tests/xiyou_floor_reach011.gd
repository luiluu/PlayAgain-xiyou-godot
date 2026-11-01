extends Node
## 七层科维努斯镇 Map011 与珈蓝寺 142、夜雨寺 143 副本（地图场景里真走一遍）：
## - 011：遇敌表 40～44；EV10 武器／防具商人（27／387）；EV11 神魔之塔七层首领 52，之后商人 835；EV12 传送回方桌大厅 Map4 (14,23)；
##   EV14／EV15 副本门：缺入场物品 24 不进，副本未重置不进，有则扣一件、副本号变量 6＝25／26 进 142／143 (9,18)，也可重置副本。
## - 142：EV4～7 四队 440（变量 241 记数）；EV3 如来分身 442，开开关 19，奖励页按变量 94 发装备，回 011 (2,27) 并重置；EV9 逃离。
## - 143（原版重置不清变量 241）：EV13～16 四队 441；EV11 如来分身 443，开开关 20，奖励页同上；EV17 逃离回 011 (47,28)。
## 队伍生命攻击都很大（只查流程）；随机用 MVEventCore.fixed_random 固定。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 240000   # 并行负载下单个事件可能跑到一两分钟，别用 90 秒的墙钟判失败
const WaitBudget := preload("res://tests/wait_budget.gd")  # 墙钟与帧数都过了才算超时（tools30）

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
		map.ui.child_entered_tree.connect(_on_ui_child)
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



func _on_ui_child(n: Node) -> void:
	if n is XBattleScene:
		n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT)
	elif n is XTrainingScene:
		trainings += 1
		n.closed.emit.call_deferred()


func _run_call(map: XMapScene, call: Callable, mode := "win") -> bool:
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(_on_ui_child)
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




func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_reach011"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XShop.auto_close = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261027)
	await _town()
	await _temple(142, 14, 25, 440, 4, 3, 442, 19, Vector2i(2, 27), 9, [4, 5, 6, 7])
	await _temple(143, 15, 26, 441, 4, 11, 443, 20, Vector2i(47, 28), 17, [13, 14, 15, 16])
	MVEventCore.fixed_random = -1.0
	_finish()


func _pick(k: int, n: int) -> void:
	MVEventCore.fixed_random = (k - 0.5) / float(n)


func _table(tag: String, map: XMapScene, troops: Array) -> void:
	_check(tag + "_table", map.map_data.encounterList.map(func(r): return int(r.troopId)) == troops, map.map_data.encounterList)
	var total := 0
	for r in map.map_data.encounterList:
		total += int(r.weight)
	var seen := {}
	for r in range(total):
		seen[XMapScene.encounter_troop(map.map_data.encounterList, r)] = true
	_check(tag + "_rolls", seen.keys().size() == troops.size() and troops.all(func(t): return seen.has(t)), seen.keys())


func _fight(tag: String, map: XMapScene, troops: Array) -> void:
	var n0 := battles.size()
	await _run_call(map, func(): await map._encounter(), "win")
	_check(tag + "_encounter", battles.size() == n0 + 1 and troops.has(int(battles[-1].troop)) and battles[-1].result == 0, battles.slice(n0))


func _shop_is(n: int, type: int, id: int) -> bool:
	return XShop.auto_log.size() == n + 1 and XShop.auto_log[-1].goods.size() > 0 and int(XShop.auto_log[-1].goods[0][0]) == type and int(XShop.auto_log[-1].goods[0][1]) == id


## 七层科维努斯镇 11
func _town() -> void:
	var s := _start(11, 12, 20, 2)
	if not _check("town_start", await _wait_map(11)):
		return
	var map: XMapScene = _scene()
	_check("town_events", [10, 11, 12, 14, 15].all(func(i): return _event(map, i) != null))
	_table("town", map, [40, 41, 42, 43, 44])
	await _fight("town", map, [40, 41, 42, 43, 44])
	# EV10 武器／防具商人
	var n := XShop.auto_log.size()
	await _run_event(map, 10, [0], "")
	_check("town_weapons", _shop_is(n, 1, 27), XShop.auto_log.slice(n))
	n = XShop.auto_log.size()
	await _run_event(map, 10, [1], "")
	_check("town_armors", _shop_is(n, 2, 387), XShop.auto_log.slice(n))
	# EV11 神魔之塔七层首领 52，之后换成商人 835
	var v20 := int(s.variable(20))
	var n0 := battles.size()
	await _run_event(map, 11, [0], "win")
	_check("town_tower_boss", battles.size() == n0 + 1 and int(battles[-1].troop) == 52 and battles[-1].result == 0 and s.self_switch(11, 11, "A") and int(s.variable(20)) == v20 + 1, battles.slice(n0))
	n = XShop.auto_log.size()
	await _run_event(map, 11, [0], "")
	_check("town_tower_shop835", _shop_is(n, 0, 835), XShop.auto_log.slice(n))
	# EV12 传送回方桌大厅 Map4 (14,23)，成就 51
	await _run_event(map, 12, [0], "")
	_check("town_tp4", await _wait_map(4) and _scene().player.grid == Vector2i(14, 23) and s.achievements.has("51"), [_scene().map_id, _scene().player.grid])
	# 副本门：缺物品 24 不进；副本未重置不进；重置；进入
	for d in [[14, 142, 25], [15, 143, 26]]:
		s = _start(11, 12, 20, 2)
		if not _check("door%d_start" % d[1], await _wait_map(11)):
			return
		map = _scene()
		s.items.erase(24)
		await _run_event(map, int(d[0]), [0], "")
		_check("door%d_no_item" % d[1], _scene().map_id == 11 and int(s.variable(6)) != int(d[2]), [_scene().map_id, s.variable(6)])
		s.gain_item(24, 1)
		s.set_variable(5, 1)
		await _run_event(map, int(d[0]), [0], "")
		_check("door%d_busy" % d[1], _scene().map_id == 11 and s.item_count(24) == 1, [_scene().map_id, s.item_count(24)])
		s.set_variable(6, int(d[2]))
		s.set_switch(19 if d[1] == 142 else 20, true)
		s.set_variable(241, 3)
		await _run_event(map, int(d[0]), [1], "")
		_check("door%d_reset" % d[1], int(s.variable(5)) == 0 and int(s.variable(6)) == 0 and not s.switch(19 if d[1] == 142 else 20) and (d[1] == 143 or int(s.variable(241)) == 0), [s.variable(5), s.variable(6), s.variable(241)])
		await _run_event(map, int(d[0]), [0], "")
		_check("door%d_enter" % d[1], await _wait_map(int(d[1])) and _scene().player.grid == Vector2i(9, 18) and s.item_count(24) == 0 and int(s.variable(6)) == int(d[2]) and int(s.variable(5)) == 1, [_scene().map_id, _scene().player.grid, s.item_count(24), s.variable(6), s.variable(5)])


## 寺内副本：门事件 door，四队小怪 mobs（敌群 mob，变量 241 记数），如来分身 boss（敌群 boss，开关 sw），奖励回 011 back，逃离 esc
func _temple(map_id: int, door: int, vnum: int, mob: int, _n: int, boss_ev: int, boss: int, sw: int, back: Vector2i, esc: int, mobs: Array) -> void:
	var tag := "t%d" % map_id
	var s := _start(11, 12, 20, 2)
	if not _check(tag + "_start", await _wait_map(11)):
		return
	s.gain_item(24, 1)
	await _run_event(_scene(), door, [0], "")
	if not _check(tag + "_entered", await _wait_map(map_id) and _scene().player.grid == Vector2i(9, 18), [_scene().map_id]):
		return
	var map: XMapScene = _scene()
	_check(tag + "_no_table", map.map_data.encounterList.is_empty())
	_check(tag + "_events", mobs.all(func(i): return _event(map, int(i)) != null) and _event(map, boss_ev) != null and _event(map, esc) != null)
	for i in range(mobs.size()):
		var n0 := battles.size()
		await _run_event(map, int(mobs[i]), [], "win")
		_check("%s_mob%d" % [tag, i], battles.size() == n0 + 1 and int(battles[-1].troop) == mob and battles[-1].result == 0 and int(s.variable(241)) == i + 1, [battles.slice(n0), s.variable(241)])
	# 如来分身
	var nb := battles.size()
	await _run_event(map, boss_ev, [], "win")
	_check(tag + "_boss", battles.size() == nb + 1 and int(battles[-1].troop) == boss and battles[-1].result == 0 and s.switch(sw), battles.slice(nb))
	# 奖励页：var94＝1 发装备 165，var218 掷出 1 发成就 26
	map.refresh_events()
	await _wait_map(map_id)
	s.set_variable(94, 1)
	s.set_variable(140, 1)
	var g0 := s.gear_count("armor", 165)
	MVEventCore.fixed_random = 0.0001
	await _run_event(map, boss_ev, [], "")
	MVEventCore.fixed_random = -1.0
	_check(tag + "_reward_back", await _wait_map(11) and _scene().player.grid == back and int(s.variable(6)) == 0 and int(s.variable(5)) == 0 and not s.switch(sw), [_scene().map_id, _scene().player.grid, s.variable(6), s.variable(5)])
	_check(tag + "_reward_gear", s.gear_count("armor", 165) == g0 + 1, [g0, s.gear_count("armor", 165)])
	_check(tag + "_ach26", s.achievements.has("26"), s.achievements.keys())
	# 逃离
	s = _start(map_id, 9, 19, 2)
	s.set_variable(6, vnum)
	s.set_variable(5, 1)
	if not _check(tag + "_escape_start", await _wait_map(map_id)):
		return
	await _run_event(_scene(), esc, [0], "")
	_check(tag + "_escape", await _wait_map(11) and _scene().player.grid == back and int(s.variable(6)) == 0 and int(s.variable(5)) == 0, [_scene().map_id, _scene().player.grid, s.variable(6)])


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
