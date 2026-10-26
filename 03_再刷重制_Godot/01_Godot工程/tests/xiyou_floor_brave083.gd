extends Node
## 勇者之塔二层 Map083、三层 Map084、王座 Map085 流程（地图场景里真走一遍；数值与事件对照由 xiyou_event_compare 承担）：
## - 楼梯（触碰）：一层 Map082 EV2 → 二层 (5,8)；二层 EV2／EV3 → 三层 (25,8)／(15,5)，EV1 回一层；三层 EV3 → 王座 (5,10)，EV1／EV2 回二层；王座 EV2 回三层 (5,8)。
##   一层主席带活力水行贿 → 王座 (15,13)。
## - 精英：二层 EV4 敌群 293（开关 122）、EV5／6 291（打完暂时消除）、EV7 295（开关 124）；三层 EV4 294（123）、EV5～8 291（暂时消除）、EV9 297（125）。
## - 三层魔塔教师 EV10「进行修炼」（修炼界面未做）与被困的灵魂 EV11「认证 魔塔之主」（三顶王冠，称号脚本未接）只测「离开」与缺物品。
## - 王座 EV1 霍格尔（开关 1709～1712 每档一页，敌群 296）：胜后开关 126、909（主席）、所选档＝本档时开下一档开关、肝帝积分；宝箱（开关 126、变量 450 档）发奖，
##   有邀请函 179 必出深渊之门：「进入此门」按变量 136／107 去 Map056～059，「离开这是非之地」回 Map081 (17,33) 重置并退还邀请函。
## 队伍生命攻击都很大（只查流程）；用 MVEventCore.fixed_random 固定事件随机数。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const INVITE := 179
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



func _run() -> void:
	GameApp.fast_forward()  # 真走地图打战斗、等的是物理帧与计时器：headless 快进 4 倍（见 07_开发环境/测试提速.md）
	XSave.dir_override = "user://test_xiyou_floor_brave083"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	await _stairs()
	await _elites()
	await _floor3_npcs()
	await _throne()
	await _chest()
	MVEventCore.fixed_random = -1.0
	await _finish()


func _goto(from: int, x: int, y: int, ev: int, to: int, cell: Vector2i, answers := []) -> void:
	var s := _start(from, x, y)
	if not _check("m%d_loaded_%d" % [from, ev], await _wait_map(from)):
		return
	if from == 82 and ev == 6:
		s.set_switch(909, true)
		s.gain_item(912, 1)
		_scene().refresh_events()
	await _run_event(_scene(), ev, answers, "")
	_check("m%d_ev%d_to_%d" % [from, ev, to], await _wait_map(to) and _scene().player.grid == cell, [_scene().name])


func _stairs() -> void:
	await _goto(82, 15, 24, 2, 83, Vector2i(5, 8))
	await _goto(82, 15, 24, 6, 85, Vector2i(15, 13), [0])
	await _goto(83, 15, 10, 1, 82, Vector2i(5, 8))
	await _goto(83, 15, 10, 2, 84, Vector2i(25, 8))
	await _goto(83, 15, 10, 3, 84, Vector2i(15, 5))
	await _goto(84, 15, 14, 1, 83, Vector2i(25, 8))
	await _goto(84, 15, 14, 2, 83, Vector2i(15, 5))
	await _goto(84, 15, 14, 3, 85, Vector2i(5, 10))
	await _goto(85, 15, 15, 2, 84, Vector2i(5, 8))


func _elites() -> void:
	for c in [[83, [[4, 293, 122], [5, 291, 0], [7, 295, 124]]], [84, [[4, 294, 123], [6, 291, 0], [9, 297, 125]]]]:
		var s := _start(c[0], 15, 14)
		if not _check("m%d_elite_loaded" % c[0], await _wait_map(c[0])):
			return
		var map: XMapScene = _scene()
		_check("m%d_events" % c[0], range(1, 8 if c[0] == 83 else 12).all(func(i): return _event(map, i) != null))
		for e in c[1]:
			var n0 := battles.size()
			await _run_event(map, e[0], [], "win")
			map = _scene()
			_check("m%d_elite%d" % [c[0], e[0]], battles.size() == n0 + 1 and battles[-1].troop == e[1] and battles[-1].result == 0 and (e[2] == 0 or s.switch(e[2])), [battles.slice(n0), e[2]])


func _floor3_npcs() -> void:
	var s := _start(84, 15, 14)
	if not _check("f3_npc_loaded", await _wait_map(84)):
		return
	var map: XMapScene = _scene()
	var n0 := battles.size()
	await _run_event(map, 10, [1], "")
	_check("f3_teacher_leave", _scene().map_id == 84)
	await _run_event(map, 11, [1], "")
	await _run_event(map, 11, [0], "")
	_check("f3_soul_no_crowns", _scene().map_id == 84 and battles.size() == n0)


func _throne() -> void:
	for tier in range(1, 5):
		var s := _start(85, 15, 15)
		if not _check("throne_loaded_%d" % tier, await _wait_map(85)):
			return
		var map: XMapScene = _scene()
		s.set_switch(1708 + tier, true)
		s.set_variable(450, tier)
		map.refresh_events()
		var n0 := battles.size()
		var j0 := int(s.variable(206))
		await _run_event(map, 1, [], "win")
		_check("throne_boss_%d" % tier, battles.size() == n0 + 1 and battles[-1].troop == 296 and battles[-1].result == 0, battles.slice(n0))
		_check("throne_after_%d" % tier, s.switch(126) and s.switch(909) and int(s.variable(206)) > j0, [s.switch(126), s.switch(909), int(s.variable(206)) - j0])
		if tier < 4:
			_check("throne_next_tier_%d" % tier, s.switch(1709 + tier) and not s.switch(1708 + tier), [s.switch(1708 + tier), s.switch(1709 + tier)])


## 宝箱：有邀请函时必出深渊之门
func _chest() -> void:
	# 离开这是非之地：回 Map081 重置、退还邀请函
	var s := await _chest_start()
	if s == null:
		return
	await _run_event(_scene(), 1, [1], "")
	_check("chest_leave", await _wait_map(81) and _scene().player.grid == Vector2i(17, 33), [_scene().name])
	_check("chest_leave_reset", int(s.variable(6)) == 0 and int(s.variable(21)) == 0 and not s.switch(126) and s.item_count(INVITE) == 1, [s.variable(6), s.variable(21), s.switch(126), s.item_count(INVITE)])
	# 普通档宝箱档次 1：武器 1350
	_check("chest_loot", s.gear_count("weapon", 1350) == 1, s.gear.size())
	# 进入此门：变量 136／107 由固定随机数决定，去 Map056～059 之一
	s = await _chest_start()
	if s == null:
		return
	MVEventCore.fixed_random = 0.1
	await _run_event(_scene(), 1, [0], "")
	MVEventCore.fixed_random = -1.0
	var ok := false
	for m in [56, 57, 58, 59]:
		if _scene() is XMapScene and _scene().map_id == m:
			ok = true
	if not ok:
		var t0 := Time.get_ticks_msec()
		while not ok and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
			await get_tree().process_frame
			var sc = _scene()
			ok = sc is XMapScene and [56, 57, 58, 59].has(sc.map_id) and not sc.busy
	_check("chest_gate", ok and _scene().player.grid == Vector2i(19, 24), [_scene().name])
	_check("chest_gate_used_invite", s.item_count(INVITE) == 0, s.item_count(INVITE))


func _chest_start() -> XState:
	var s := _start(85, 15, 15)
	if not _check("chest_loaded", await _wait_map(85)):
		return null
	s.set_switch(126, true)
	s.set_variable(450, 1)
	s.set_variable(94, 1)
	s.set_variable(5, 1)
	s.set_variable(6, 18)
	s.set_variable(21, 1)
	s.gain_item(INVITE, 1)
	_scene().refresh_events()
	return s


func _item_total(s: XState) -> int:
	var n := 0
	for k in s.items:
		n += int(s.items[k])
	return n


func _finish() -> void:
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	print("战斗：", JSON.stringify(battles))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	for player in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
