extends Node
## 哥布林王国 Map024 与四个哥布林地宫 Map025～028 流程（地图场景里真走一遍）：
## - 入口：Map031 EV1「挑战副本」（开关 45＋1701，符文 110）→ Map024 (21,38)，变量 5＝1、450＝1；
## - 小怪 EV6～13／18／19（敌群 91，各令变量 45 加一）、国王三战 EV5（敌群 92／93／94，变量 45≥10，置开关 32）、
##   国王的贡品 EV4（开关 32：发奖、传回 Map031 并重置）、逃离阵 EV21、副本协会主席 EV22（敌群 661）、被困的灵魂 EV20；
## - 四个地宫门 EV14～17（接触）→ Map025～028 (8,11)，各地宫首领 EV2（敌群 97／95／96／98），出口 EV1 回 Map024。
## 队伍生命攻击都很大（只查流程）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const RUNE := 110
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
	s.gain_item(RUNE, 2)
	s.set_switch(45, true)     # 副本入口第一页（开关 45＋1701）
	s.set_switch(1701, true)
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = 8
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	return s


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_goblin024"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261024)
	await _kingdom()
	await _vaults()
	await _side()
	await _finish()


func _kingdom() -> void:
	var s := _start(31, 5, 6)
	if not _check("door_loaded", await _wait_map(31)):
		return
	await _run_event(_scene(), 1, [0], "")
	if not _check("entered", await _wait_map(24) and _scene().player.grid == Vector2i(21, 38), [_scene().name]):
		return
	var map: XMapScene = _scene()
	_check("entry_vars", int(s.variable(5)) == 1 and int(s.variable(450)) == 1 and s.item_count(RUNE) == 1, [s.variable(5), s.variable(450), s.item_count(RUNE)])
	# 国王的贡品：击败国王前只出提示页，不进副本重置
	await _run_event(map, 4, [], "")
	_check("tribute_locked", _scene().map_id == 24)
	# 小怪 10 只，每只令变量 45 加一
	var n0 := battles.size()
	var mobs := [6, 7, 8, 9, 10, 11, 12, 13, 18, 19]
	for ev in mobs:
		await _run_event(map, ev, [], "win")
		map = _scene()
	_check("mobs_fought", battles.size() == n0 + 10 and battles.slice(n0).all(func(b): return b.troop == 91 and b.result == 0), battles.slice(n0))
	_check("mobs_counted", int(s.variable(45)) == 10, s.variable(45))
	# 国王三战（将军 → 宰相 → 国王）
	var n1 := battles.size()
	await _run_event(map, 5, [], "win")
	map = _scene()
	var fought := battles.slice(n1).map(func(b): return int(b.troop))
	_check("king_fights", fought == [92, 93, 94], fought)
	_check("king_switches", s.switch(32), [s.switch(32), s.switch(1701), s.variable(214)])
	# 贡品：发奖后传回 Map031 (5,5) 并重置副本
	await _run_event(map, 4, [], "")
	_check("tribute_returned", await _wait_map(31) and _scene().player.grid == Vector2i(5, 5), [_scene().map_id])
	_check("tribute_reset", int(s.variable(5)) == 0 and int(s.variable(450)) == 0 and not s.switch(32), [s.variable(5), s.variable(450), s.switch(32)])


func _vaults() -> void:
	var troops := {25: 97, 26: 95, 27: 96, 28: 98}
	var doors := {25: 14, 26: 15, 27: 16, 28: 17}
	var backs := {25: Vector2i(7, 12), 26: Vector2i(37, 12), 27: Vector2i(5, 28), 28: Vector2i(42, 28)}
	for m in troops:
		var s := _start(24, 8, 12)
		if not _check("v%d_loaded" % m, await _wait_map(24)):
			return
		await _run_event(_scene(), doors[m], [], "")
		_check("v%d_entered" % m, await _wait_map(m) and _scene().player.grid == Vector2i(8, 11), [_scene().name])
		var map: XMapScene = _scene()
		_check("v%d_events" % m, _event(map, 1) != null and _event(map, 2) != null)
		# 首领 EV2 第 1 页需要变量 45≥6
		s.set_variable(45, 6)
		s.set_switch(21, true)
		map.refresh_events()
		var n0 := battles.size()
		await _run_event(map, 2, [], "win")
		_check("v%d_boss" % m, battles.size() == n0 + 1 and battles[-1].troop == troops[m] and battles[-1].result == 0, battles.slice(n0))
		map = _scene()
		await _run_event(map, 1, [], "")
		_check("v%d_exit" % m, await _wait_map(24) and _scene().player.grid == backs[m], [_scene().map_id])


func _side() -> void:
	var s := _start(24, 21, 36)
	if not _check("side_loaded", await _wait_map(24)):
		return
	var map: XMapScene = _scene()
	# 逃离阵（开关 45 页）：选传送回 Map031 并重置
	await _run_event(map, 21, [0], "")
	_check("escape", await _wait_map(31) and _scene().player.grid == Vector2i(5, 5) and int(s.variable(450)) == 0, [_scene().map_id])
	# 副本协会主席：「我就看看」不动
	s = _start(24, 15, 19)
	if not _check("chair_loaded", await _wait_map(24)):
		return
	s.set_switch(906, true)
	_scene().refresh_events()
	var n0 := battles.size()
	await _run_event(_scene(), 22, [2], "")
	_check("chair_look", battles.size() == n0)
	await _run_event(_scene(), 22, [0], "win")
	_check("chair_gift_fails_fight", battles.size() == n0 + 1 and battles[-1].troop == 661, battles.slice(n0))
	# 被困的灵魂：缺材料时认证不成功（称号 8 不开）
	await _run_event(_scene(), 20, [0], "")
	_check("soul_needs_items", _scene().map_id == 24)


func _finish() -> void:
	for player in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	print("战斗：", JSON.stringify(battles))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
