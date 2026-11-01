extends Node
## 火焰之河 115 与混沌避难所 114（地图场景里真走一遍）：
## - 火焰之河：天之上 EV70 面朝上进 (24,49)（开关 21 关；开关 21 开时第二页改传 Map102 旅馆）；出口 EV1～3（面朝下）回 (30,110)；EV5 泰瑞雨兑换商店 2948（XShop.auto_close）；
##   EV4 衣卒尔：不朽灵魂（变量 201）不足 88 不收、够了扣 88 并开独立开关 A，之后「传送」去 114 (32,42)；遇敌 388～392。
## - 混沌避难所：EV17 衣卒尔传回 115 (24,8)；EV18～22 混沌之祭祀骨堆投入祭品（物品 724／728／726／727／725），集齐 5 件（变量 238）弹提示；
##   EV23 大菠萝（敌群 412）打赢后按变量 208／209／210 发奖，再重掷三个变量（原版随机分支，专项固定变量值逐支核对）；遇敌表 394＋407～411 首领。
## 队伍生命攻击都很大（只查流程）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 240000   # 并行负载下单个事件可能跑到一两分钟，别用 90 秒的墙钟判失败
const WaitBudget := preload("res://tests/wait_budget.gd")  # 墙钟与帧数都过了才算超时（tools30）
const ROUTE := preload("res://tests/xiyou_airship_route.gd")
const REACH := preload("res://tests/xiyou_reach_check.gd")
## 进天之上的落点：恰兰吉尔南出口（Map071 EV3）进 (63,50)，飞艇停在 (65,56)（同 xiyou_floor_reach094、xiyou_airship_fly）
const SKY_ENTRY := Vector2i(63, 50)

var results: Array = []
var battles: Array = []   # 每场：{troop, result}
var trainings := 0
## 战斗一结束（掉落已经进包、事件发奖之前）读一次的数（大菠萝那支用来分开自身掉落与事件发奖）；无效时不读
var count_at_end := Callable()


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
	ROUTE.park(s, 69)
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = dir
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	return s



func _on_ui_child(n: Node) -> void:
	if n is XBattleScene:
		n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r, "count": count_at_end.call() if count_at_end.is_valid() else -1}), CONNECT_ONE_SHOT)
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
	XSave.dir_override = "user://test_xiyou_floor_reach115"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XShop.auto_close = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261027)
	await _fire_and_chaos()
	_finish()


func _enter(tag: String, enter_ev: int, dir: int, map_id: int, arrive: Vector2i) -> XState:
	var s := _start(69, SKY_ENTRY.x, SKY_ENTRY.y, dir)
	if not _check(tag + "_sky", await _wait_map(69)):
		return null
	# 入口在别的岛上：从落点走不到（要坐飞艇）；走到飞艇、飞过去降落、走过去踩／撞入口（原来直接跑入口事件）
	_check(tag + "_needs_airship", REACH.unreachable(_scene(), _scene().player.grid, [enter_ev]) == [enter_ev])
	_check(tag + "_fly_in", await ROUTE.new(self, _scene()).go(enter_ev), [_scene().map_id, _scene().player.grid])
	if not _check(tag + "_entered", await _wait_map(map_id) and _scene().player.grid == arrive, [_scene().map_id, _scene().player.grid]):
		return null
	return s


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


func _boss(tag: String, t: int) -> void:
	var n0 := battles.size()
	await _run_call(_scene(), func(): await _scene().start_battle(t, false, false), "win")
	_check("%s_boss_%d" % [tag, t], battles.size() == n0 + 1 and int(battles[-1].troop) == t and battles[-1].result == 0, battles.slice(n0))


func _has_shop(map: XMapScene, id: int, goods: int) -> bool:
	var e := _event(map, id)
	return e != null and e.command_list().any(func(c): return int(c.code) == 302 and int(c.parameters[1]) == goods)


func _fire_and_chaos() -> void:
	var s := await _enter("fire", 70, 8, 115, Vector2i(24, 49))
	if s == null:
		return
	var map: XMapScene = _scene()
	_check("fire_events", range(1, 6).all(func(i): return _event(map, i) != null))
	_table("fire", map, [388, 389, 390, 391, 392])
	# 商店
	var shop0 := XShop.auto_log.size()
	await _run_event(map, 5, [0], "")
	_check("fire_shop2948", XShop.auto_log.size() == shop0 + 1 and _has_shop(map, 5, 2948), XShop.auto_log.size() - shop0)
	await _fight("fire", map, [388, 389, 390, 391, 392])
	await _boss("fire", 392)
	map = _scene()
	# 衣卒尔：不朽灵魂不足不收费，够了扣 88
	s.set_variable(201, 50)
	await _run_event(map, 4, [0, 0], "")
	_check("fire_pay_short", int(s.variable(201)) == 50, s.variable(201))
	s.set_variable(201, 100)
	await _run_event(map, 4, [0, 0], "")
	_check("fire_pay_ok", int(s.variable(201)) == 12, s.variable(201))
	# 付过费后「传送」去 114
	await _run_event(map, 4, [0], "")
	if not _check("chaos_entered", await _wait_map(114) and _scene().player.grid == Vector2i(32, 42), [_scene().map_id, _scene().player.grid]):
		return
	map = _scene()
	_check("chaos_events", range(1, 24).all(func(i): return _event(map, i) != null))
	_table("chaos", map, [394, 407, 411, 409, 410, 408])
	await _fight("chaos", map, [394, 407, 411, 409, 410, 408])
	for t in [407, 408, 409, 410, 411]:
		await _boss("chaos", t)
	map = _scene()
	# 祭祀骨堆：缺物品提示，齐了扣一件、变量 238 加一，第五件弹提示并把开关打开
	var offers := [[18, 724, 186], [19, 728, 187], [20, 726, 188], [21, 727, 189], [22, 725, 190]]
	for o in offers:
		s.items.erase(int(o[1]))   # 前面打过 407～411 首领，已掉了这几件骨头，清零再测
	s.set_variable(238, 0)
	await _run_event(map, 18, [0], "")
	_check("chaos_offer_missing", int(s.variable(238)) == 0 and not s.switch(186))
	var k := 0
	for o in offers:
		s.gain_item(int(o[1]), 1)
		await _run_event(map, int(o[0]), [0], "")
		k += 1
		_check("chaos_offer_%d" % o[0], int(s.variable(238)) == k and s.item_count(int(o[1])) == 0 and s.switch(int(o[2])), [s.variable(238), s.item_count(int(o[1]))])
	# 大菠萝：按变量 208／209／210 发奖（固定变量值逐支核对），打完重掷三个变量、开关清零。
	# 大菠萝自己也可能掉 2851～2859 套装（dev.257 掉落照原版后看概率）：战斗结束时先数一次，自身掉落＝结束时−战前（0 或 1），
	# 事件发奖＝事件跑完−结束时，必须正好 1（审查 19 期 P3①：原来按区间断言，发奖漏发会被自身掉落盖住）
	var cases := [
		{"v": [1, 3, 0], "gear": 2971, "what": "rare3"},
		{"v": [50, 0, 5], "gear": 2855, "what": "normal5"},
		{"v": [1, 7, 0], "item": 751, "what": "rare7"},
	]
	for c in cases:
		s.set_variable(238, 5)
		s.set_variable(208, c.v[0])
		s.set_variable(209, c.v[1])
		s.set_variable(210, c.v[2])
		count_at_end = func(): return s.gear_count("armor", int(c.gear)) if c.has("gear") else s.item_count(int(c.item))
		var g0: int = count_at_end.call()
		var n0 := battles.size()
		await _run_event(map, 23, [], "win")
		var g1: int = count_at_end.call()
		var at_end := int(battles[-1].count) if battles.size() == n0 + 1 else -1
		count_at_end = Callable()
		_check("chaos_boss412_" + c.what, battles.size() == n0 + 1 and int(battles[-1].troop) == 412 and at_end - g0 >= 0 and at_end - g0 <= 1 and g1 - at_end == 1, [battles.slice(n0), g0, at_end, g1])
		_check("chaos_reroll_" + c.what, int(s.variable(238)) == 0 and not s.switch(186) and int(s.variable(208)) >= 1 and int(s.variable(208)) <= 100 and int(s.variable(209)) >= 1 and int(s.variable(209)) <= 6 and int(s.variable(210)) >= 1 and int(s.variable(210)) <= 12, [s.variable(238), s.variable(208), s.variable(209), s.variable(210)])
	# 衣卒尔传回火焰之河，再出口
	await _run_event(map, 17, [0], "")
	if not _check("fire_back", await _wait_map(115) and _scene().player.grid == Vector2i(24, 8), [_scene().map_id, _scene().player.grid]):
		return
	map = _scene()
	map.player.direction = 2
	await _run_event(map, 1, [], "")
	_check("fire_exit", await _wait_map(69) and _scene().player.grid == Vector2i(30, 110), [_scene().map_id, _scene().player.grid])


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
