extends Node
## 知识厅堂 Map018、副本工会 Map197、青训部 Map196 流程（地图场景里真走一遍；数值与事件对照由 xiyou_event_compare 承担）：
## - 入口：大厅 Map004 EV12（变量 20≥11、面朝左）→ Map018 (17,8)；传送室 Map031 EV2（触碰）→ Map018 (9,12)；
##   传送室 EV6（开关 941＋1713～1716 每档一页，特级符文 171，变量 6＝45）→ Map197 (12,16)。
## - Map018：知识贤者 EV2（持损坏的指路灯 405 时可修成 404）、古代文明学者 EV3（开关 2303／2307 且变量 20≥31 时打敌群 797，变量 1106＝1）、
##   隐藏彩蛋 EV9（物品 411）；出口 EV6 → 传送室 (9,10)、EV10（面朝右）→ 大厅 (4,6)、EV1 → 训练室 Map019（未接）。
## - Map197：前台 EV2；部门门 EV8 → 青训部 Map196 (6,2)（其余部门 199～203、主席 Map198 未接）；逃离 EV3 → 传送室 (14,6) 并重置副本。
## - Map196：青训部 EV1（敌群 673，开关 946，变量 512 加一）；出口 EV2 → Map197 (3,16)。
## 队伍生命攻击都很大（只查流程）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const RUNE := 171
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
	XSave.dir_override = "user://test_xiyou_floor_guild197"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	await _doors()
	await _hall()
	await _guild_gate()
	await _guild()
	await _finish()


func _goto(from: int, x: int, y: int, ev: int, to: int, cell: Vector2i, setup := Callable(), answers := []) -> void:
	var s := _start(from, x, y)
	if not _check("m%d_loaded_%d" % [from, ev], await _wait_map(from)):
		return
	if setup.is_valid():
		setup.call(s, _scene())
		_scene().refresh_events()
	await _run_event(_scene(), ev, answers, "")
	_check("m%d_ev%d_to_%d" % [from, ev, to], await _wait_map(to) and _scene().player.grid == cell, [_scene().name])


func _doors() -> void:
	await _goto(4, 4, 6, 12, 18, Vector2i(17, 8), func(s, map):
		s.set_variable(20, 11)
		map.player.direction = 4)
	await _goto(31, 9, 9, 2, 18, Vector2i(9, 12))
	await _goto(18, 9, 12, 6, 31, Vector2i(9, 10))
	await _goto(18, 18, 8, 10, 4, Vector2i(4, 6), func(s, map): map.player.direction = 6)
	await _goto(197, 12, 15, 8, 196, Vector2i(6, 2))
	await _goto(196, 6, 3, 2, 197, Vector2i(3, 16))


func _hall() -> void:
	var s := _start(18, 11, 15)
	if not _check("hall_loaded", await _wait_map(18)):
		return
	var map: XMapScene = _scene()
	_check("hall_events", range(1, 11).all(func(i): return _event(map, i) != null))
	# 知识贤者：持损坏的指路灯 405 时修成 404
	s.gain_item(405, 1)
	await _run_event(map, 2, [1], "")
	_check("sage_repair", s.item_count(405) == 0 and s.item_count(404) == 1, [s.item_count(405), s.item_count(404)])
	await _run_event(map, 2, [1], "")
	_check("sage_leave", s.item_count(404) == 1)
	# 隐藏彩蛋：物品 411，独立开关 A 后消失
	await _run_event(map, 9, [], "")
	_check("egg", s.item_count(411) == 1, s.item_count(411))
	# 古代文明学者：开关 2303、变量 20≥31 时打敌群 797
	s.set_switch(2303, true)
	s.set_variable(20, 31)
	map.refresh_events()
	await _run_event(map, 3, [1], "")
	_check("scholar_leave", battles.is_empty())
	await _run_event(map, 3, [0], "win")
	_check("scholar_fight", battles.size() == 1 and battles[0].troop == 797 and battles[0].result == 0 and int(s.variable(1106)) == 1, [battles, s.variable(1106)])


func _guild_gate() -> void:
	var s := _start(31, 14, 6)
	if not _check("gate_loaded", await _wait_map(31)):
		return
	s.set_switch(941, true)
	s.set_switch(1713, true)
	s.gain_item(RUNE, 1)
	_scene().refresh_events()
	await _run_event(_scene(), 6, [0], "")
	_check("gate_enter", await _wait_map(197) and _scene().player.grid == Vector2i(12, 16), [_scene().name])
	_check("gate_vars", s.item_count(RUNE) == 0 and int(s.variable(6)) == 45 and int(s.variable(21)) == 1, [s.item_count(RUNE), s.variable(6), s.variable(21)])


func _guild() -> void:
	var s := _start(196, 6, 9)
	if not _check("youth_loaded", await _wait_map(196)):
		return
	var n0 := battles.size()
	await _run_event(_scene(), 1, [], "win")
	_check("youth_fight", battles.size() == n0 + 1 and battles[-1].troop == 673 and s.switch(946) and int(s.variable(512)) == 1, [battles.slice(n0), s.switch(946), s.variable(512)])
	s = _start(197, 12, 15)
	if not _check("guild_loaded", await _wait_map(197)):
		return
	var map: XMapScene = _scene()
	_check("guild_events", range(1, 10).all(func(i): return _event(map, i) != null))
	await _run_event(map, 2, [], "")
	_check("guild_reception", _scene().map_id == 197)
	s.set_variable(5, 1)
	s.set_variable(6, 45)
	s.set_variable(21, 1)
	s.set_variable(512, 3)
	s.set_switch(946, true)
	await _run_event(map, 3, [1], "")
	_check("guild_escape_no", _scene().map_id == 197)
	await _run_event(map, 3, [0], "")
	_check("guild_escape", await _wait_map(31) and _scene().player.grid == Vector2i(14, 6), [_scene().name])
	_check("guild_escape_reset", int(s.variable(6)) == 0 and int(s.variable(21)) == 0 and int(s.variable(512)) == 0 and not s.switch(946), [s.variable(6), s.variable(21), s.variable(512), s.switch(946)])


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
