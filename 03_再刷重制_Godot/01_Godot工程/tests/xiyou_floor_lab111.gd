extends Node
## 大神机械实验室 Map111 流程（地图场景里真走一遍）：
## - 入口：Map031 EV5「挑战副本」（开关 141＋1705，符文 171）→ Map111 (17,26)，变量 5＝1、450＝1；
## - 六个机械首领 EV1～6（敌群 362／363／364／367／365／366，战后开 142～147、变量 195 加一）、
##   小怪 EV10～14（敌群 361）、终局 EV9（敌群 368，开关 148，胜后发奖）、宝箱页传回 Map031 (8,5) 并重置；
## - 逃离阵 EV23、副本协会主席 EV24（敌群 661）、范海辛 EV25。
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
	s.gain_item(RUNE, 2)
	s.set_switch(141, true)    # 副本入口第一页（开关 141＋1705）
	s.set_switch(1705, true)
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = 8
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	return s


func _run() -> void:
	GameApp.fast_forward()  # 真走地图打战斗、等的是物理帧与计时器：headless 快进 4 倍（见 07_开发环境/测试提速.md）
	XSave.dir_override = "user://test_xiyou_floor_lab111"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261024)
	await _lab()
	await _side()
	await _finish()


func _lab() -> void:
	var s := _start(31, 8, 6)
	if not _check("door_loaded", await _wait_map(31)):
		return
	await _run_event(_scene(), 5, [0], "")
	if not _check("entered", await _wait_map(111) and _scene().player.grid == Vector2i(17, 26), [_scene().name]):
		return
	var map: XMapScene = _scene()
	_check("entry_vars", int(s.variable(5)) == 1 and int(s.variable(450)) == 1 and s.item_count(RUNE) == 1, [s.variable(5), s.variable(450), s.item_count(RUNE)])
	var n0 := battles.size()
	var bosses := {1: 362, 2: 363, 3: 364, 4: 367, 5: 365, 6: 366}
	for ev in bosses:
		await _run_event(map, ev, [], "win")
		map = _scene()
		_check("boss%d_fight" % ev, battles.size() == n0 + ev and battles[-1].troop == bosses[ev] and battles[-1].result == 0, battles.slice(n0))
		_check("boss%d_switch" % ev, s.switch(141 + ev), 141 + ev)
	_check("bosses_counted", int(s.variable(195)) == 6, s.variable(195))
	# 小怪
	var n1 := battles.size()
	for ev in [10, 11, 12, 13, 14]:
		await _run_event(map, ev, [], "win")
		map = _scene()
	_check("mobs", battles.size() == n1 + 5 and battles.slice(n1).all(func(b): return b.troop == 361 and b.result == 0), battles.slice(n1))
	# 终局：机械牛马
	var n2 := battles.size()
	await _run_event(map, 9, [], "win")
	map = _scene()
	_check("final_fight", battles.size() == n2 + 1 and battles[-1].troop == 368 and battles[-1].result == 0 and s.switch(148), [battles.slice(n2), s.switch(148)])
	# 宝箱页：强制有邀请函而出现传送门，明确选择「离开这是非之地」，验证固定的回程与重置分支。
	s.gain_item(179, 1)
	await _run_event(map, 9, [1], "")
	_check("chest_portal_declined", int(s.variable(106)) == 1, s.variable(106))
	_check("chest_returned", await _wait_map(31) and _scene().player.grid == Vector2i(8, 5), [_scene().map_id])
	_check("chest_reset", int(s.variable(5)) == 0 and int(s.variable(450)) == 0 and not s.switch(148) and not s.switch(142), [s.variable(5), s.variable(450), s.switch(148)])


func _side() -> void:
	var s := _start(111, 17, 25)
	if not _check("side_loaded", await _wait_map(111)):
		return
	var map: XMapScene = _scene()
	# 范海辛：弹幕之雨不够，不给书
	await _run_event(map, 25, [], "")
	_check("vh_short", not s.actor(1).skill_ids.has(1984) and _scene().map_id == 111)
	# 副本协会主席：「我就看看」不动，送礼（开关 908）失败则战斗
	s.set_switch(908, true)
	map.refresh_events()
	var n0 := battles.size()
	await _run_event(map, 24, [2], "")
	_check("chair_look", battles.size() == n0)
	await _run_event(map, 24, [0], "win")
	_check("chair_fight", battles.size() == n0 + 1 and battles[-1].troop == 661, battles.slice(n0))
	map = _scene()
	# 逃离阵：回 Map031
	await _run_event(map, 23, [], "")
	_check("escape", await _wait_map(31) and _scene().player.grid == Vector2i(8, 5), [_scene().map_id])


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
