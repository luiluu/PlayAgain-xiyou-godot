extends Node
## 五层黄金平原 62、灵气枯竭的福地 154、原神空间 153 副本与奇珍密室 100（地图场景里真走一遍）：
## - 62：遇敌表 240～244；EV1 商店 79；EV2 指路灯给钱／硬抢（敌群 263）；EV4 神魔之塔五层首领 245，之后变量 145（1～17）卖 917～933；
##   EV3 传送回方桌大厅 Map4；EV6 触碰进 154，154 EV1 触碰回 62。
## - 154 EV3 副本：缺入场物品 24 不进，有则扣一件、副本号变量 6＝24 进 153 (13,23)；153 四个守护首领 433／435／434／436（变量 292 记数）、
##   满 4 个后 EV1 最终首领 437，奖励页按变量 140／94 随机发装备，回 154 并重置；153 EV3 逃离。
## - 99 EV2 → 奇珍密室 100：EV6 兑换商店 2929，EV1 回 99。
## 队伍生命攻击都很大（只查流程）；随机用 MVEventCore.fixed_random 固定。
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
		map.ui.child_entered_tree.connect(_on_ui_child)
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
	XSave.dir_override = "user://test_xiyou_floor_reach062"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XShop.auto_close = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261027)
	await _plain()
	await _vault()
	await _curio()
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


## 五层黄金平原 62（直接站到地图上；正式入口是指路灯物品的公共事件 164 与 Map127 EV7，不在本专项里走）
func _plain() -> void:
	var s := _start(62, 22, 8, 2)
	if not _check("plain_start", await _wait_map(62)):
		return
	var map: XMapScene = _scene()
	_check("plain_events", range(1, 7).all(func(i): return _event(map, i) != null))
	_table("plain", map, [240, 241, 242, 243, 244])
	await _fight("plain", map, [240, 241, 242, 243, 244])
	# EV1 商店 79
	var n := XShop.auto_log.size()
	await _run_event(map, 1, [0], "")
	_check("plain_shop79", _shop_is(n, 0, 79), XShop.auto_log.slice(n))
	# EV2 指路灯：给钱（五万金币换物品 388，开独立开关 B）
	s.set_switch(109, true)   # 开关 109 开后才是指路灯问答页
	map.refresh_events()
	await _wait_map(62)
	s.gold = 60000
	await _run_event(map, 2, [0, 0], "")
	_check("plain_lamp_pay", s.gold == 10000 and s.item_count(388) == 1 and s.self_switch(62, 2, "B"), [s.gold, s.item_count(388)])
	# 硬抢：钱不够时不能给钱，选硬抢打敌群 263
	s.set_self_switch(62, 2, "B", false)
	map.refresh_events()
	await _wait_map(62)
	s.gold = 0
	var n0 := battles.size()
	await _run_event(map, 2, [0, 1], "win")
	_check("plain_lamp_rob", battles.size() == n0 + 1 and int(battles[-1].troop) == 263 and s.self_switch(62, 2, "A"), battles.slice(n0))
	# EV4 神魔之塔五层首领 245（第一次），之后独立开关 A 变商人：变量 145＝1～17 卖 917～933
	s.set_self_switch(62, 4, "A", false)
	n0 = battles.size()
	await _run_event(map, 4, [0], "win")
	_check("plain_tower_boss", battles.size() == n0 + 1 and int(battles[-1].troop) == 245 and s.self_switch(62, 4, "A"), battles.slice(n0))
	for k in range(1, 18):
		_pick(k, 17)
		n = XShop.auto_log.size()
		await _run_event(map, 4, [0], "")
		if not _shop_is(n, 0, 916 + k):
			_check("plain_tower_shop%d" % k, false, XShop.auto_log.slice(n))
	MVEventCore.fixed_random = -1.0
	_check("plain_tower_shop_all", true)
	# EV3 传送 → 方桌大厅 Map4 (12,18)，成就 51
	await _run_event(map, 3, [0], "")
	_check("plain_tp4", await _wait_map(4) and _scene().player.grid == Vector2i(12, 18) and s.achievements.has("51"), [_scene().map_id, _scene().player.grid])
	# 回 62，EV6 触碰进福地 154 (1,11)
	s = _start(62, 43, 12, 6)
	if not _check("plain_back", await _wait_map(62)):
		return
	await _run_event(_scene(), 6, [], "")
	_check("plain_to154", await _wait_map(154) and _scene().player.grid == Vector2i(1, 11), [_scene().map_id, _scene().player.grid])
	# 154 EV1 触碰回 62 (43,12)
	await _run_event(_scene(), 1, [], "")
	_check("vault_to62", await _wait_map(62) and _scene().player.grid == Vector2i(43, 12), [_scene().map_id, _scene().player.grid])


## 灵气枯竭的福地 154 → 原神空间 153 副本
func _vault() -> void:
	var s := _start(154, 14, 16, 8)
	if not _check("vault_start", await _wait_map(154)):
		return
	var map: XMapScene = _scene()
	_check("vault_events", [1, 3].all(func(i): return _event(map, i) != null))
	# 缺入场物品（24）不进
	s.items.erase(24)
	await _run_event(map, 3, [0], "")
	_check("vault_no_item", _scene().map_id == 154 and int(s.variable(6)) != 24, [_scene().map_id, s.variable(6)])
	s.gain_item(24, 1)
	await _run_event(map, 3, [0], "")
	if not _check("vault_entered", await _wait_map(153) and _scene().player.grid == Vector2i(13, 23), [_scene().map_id, _scene().player.grid]):
		return
	_check("vault_item_used", s.item_count(24) == 0 and int(s.variable(6)) == 24 and int(s.variable(5)) == 1, [s.item_count(24), s.variable(6), s.variable(5)])
	map = _scene()
	_check("origin_events", [1, 2, 3, 11, 12, 13, 14].all(func(i): return _event(map, i) != null))
	_check("origin_no_table", map.map_data.encounterList.is_empty())
	# 四个守护首领 433／435／434／436 各一场，变量 292 记数
	var guards := [[11, 433, 237], [12, 435, 239], [13, 434, 238], [14, 436, 240]]
	for g in guards:
		var n0 := battles.size()
		await _run_event(map, int(g[0]), [], "win")
		_check("origin_guard_%d" % g[1], battles.size() == n0 + 1 and int(battles[-1].troop) == int(g[1]) and battles[-1].result == 0 and s.switch(int(g[2])), battles.slice(n0))
	_check("origin_v292", int(s.variable(292)) == 4, s.variable(292))
	# 最终首领 437（变量 292≥4 的第二页），再按页发奖励并重置副本回 154
	map.refresh_events()
	await _wait_map(153)
	var n1 := battles.size()
	await _run_event(map, 1, [], "win")
	_check("origin_final_437", battles.size() == n1 + 1 and int(battles[-1].troop) == 437 and battles[-1].result == 0 and s.switch(242), battles.slice(n1))
	# 奖励页（开关 242）：固定 var140＝1、var94＝1，回 154 (14,16) 并重置
	map.refresh_events()
	await _wait_map(153)
	_pick(1, 16)
	await _run_event(map, 1, [], "")
	MVEventCore.fixed_random = -1.0
	_check("origin_reward_back", await _wait_map(154) and _scene().player.grid == Vector2i(14, 16) and int(s.variable(6)) == 0 and not s.switch(242) and int(s.variable(292)) == 0, [_scene().map_id, _scene().player.grid, s.variable(6), s.variable(292)])
	# 逃离（EV3 触碰事件）：重进后从 153 EV3 逃离回 154
	s = _start(153, 13, 24, 2)
	s.set_variable(6, 24)
	s.set_variable(5, 1)
	if not _check("escape_start", await _wait_map(153)):
		return
	await _run_event(_scene(), 3, [0], "")
	_check("escape", await _wait_map(154) and _scene().player.grid == Vector2i(14, 16) and int(s.variable(6)) == 0, [_scene().map_id, _scene().player.grid, s.variable(6)])


## 挑战者协会:二楼 99 → 奇珍密室 100
func _curio() -> void:
	var s := _start(99, 8, 5, 2)
	if not _check("curio_start", await _wait_map(99)):
		return
	await _run_event(_scene(), 2, [], "")
	if not _check("curio_entered", await _wait_map(100) and _scene().player.grid == Vector2i(8, 12), [_scene().map_id, _scene().player.grid]):
		return
	var map: XMapScene = _scene()
	_check("curio_events", [1, 3, 4, 5, 6].all(func(i): return _event(map, i) != null))
	var n := XShop.auto_log.size()
	await _run_event(map, 6, [0], "")
	_check("curio_shop2929", XShop.auto_log.size() == n + 1 and int(XShop.auto_log[-1].goods[0][0]) == 2 and int(XShop.auto_log[-1].goods[0][1]) == 2929, XShop.auto_log.slice(n))
	await _run_event(map, 1, [], "")
	_check("curio_back", await _wait_map(99) and _scene().player.grid == Vector2i(8, 5), [_scene().map_id, _scene().player.grid])


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
