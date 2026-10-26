extends Node
## 副本工会六部门 Map198 工会主席、Map199 财务部、Map200 行政部、Map201 销售部、Map202 技术部、Map203 宣传部与训练室 Map019 流程（地图场景里真走一遍）：
## - Map197 门 EV4～7、EV9（部门）与 EV1（主席，变量 512≥6 的第二页）；各部门 EV3（宣传部 EV2）出口回 Map197；
## - 各部门首领 EV2（宣传部 EV1）：敌群 669～672、674，开关 942～945／947 置位，变量 512 加一；
## - 主席 Map198 EV1：敌群 668，开关 948 置位；EV10 出口 → Map197 (11,3)；
## - 训练室 Map019：Map018 EV1 → (9,4)，EV1 回 Map018 (11,29)；木桩 EV2／8～16 对应敌群 70～75、352～355，战后 GetAcReward(60)。
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
	GameApp.fast_forward()  # 真走地图打战斗、等的是物理帧与计时器：headless 快进 4 倍（见 07_开发环境/测试提速.md）
	XSave.dir_override = "user://test_xiyou_floor_guild198"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261024)
	await _doors()
	await _bosses()
	await _chairman()
	await _training()
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
	# 部门门（来源 Map197 EV4～7、EV9）与各部门出口
	await _goto(197, 1, 8, 4, 199, Vector2i(10, 8))
	await _goto(197, 1, 14, 5, 200, Vector2i(10, 8))
	await _goto(197, 25, 7, 6, 201, Vector2i(2, 8))
	await _goto(197, 25, 14, 7, 202, Vector2i(2, 8))
	await _goto(197, 23, 16, 9, 203, Vector2i(6, 2))
	await _goto(199, 11, 9, 3, 197, Vector2i(1, 8))
	await _goto(200, 11, 9, 3, 197, Vector2i(1, 14))
	await _goto(201, 1, 9, 3, 197, Vector2i(25, 7))
	await _goto(202, 1, 9, 3, 197, Vector2i(25, 14))
	await _goto(203, 6, 2, 2, 197, Vector2i(23, 16))
	# 主席门：变量 512≥6 才进 Map198 (11,34)
	await _goto(197, 11, 3, 1, 198, Vector2i(11, 34), func(s, map): s.set_variable(512, 6))
	await _goto(198, 11, 35, 10, 197, Vector2i(11, 3))
	var s := _start(197, 11, 3)
	if _check("chair_door_loaded", await _wait_map(197)):
		await _run_event(_scene(), 1, [], "")
		_check("chair_door_locked", _scene().map_id == 197)


func _boss(map_id: int, ev: int, troop: int, sw: int) -> void:
	var s := _start(map_id, 6, 9)
	if not _check("boss%d_loaded" % map_id, await _wait_map(map_id)):
		return
	var n0 := battles.size()
	await _run_event(_scene(), ev, [], "win")
	_check("boss%d_fight" % map_id, battles.size() == n0 + 1 and battles[-1].troop == troop and battles[-1].result == 0 and s.switch(sw) and int(s.variable(512)) == 1, [battles.slice(n0), s.switch(sw), s.variable(512)])


func _bosses() -> void:
	await _boss(199, 2, 669, 942)
	await _boss(200, 2, 670, 943)
	await _boss(201, 2, 671, 944)
	await _boss(202, 2, 672, 945)
	await _boss(203, 1, 674, 947)


func _chairman() -> void:
	var s := _start(198, 11, 9)
	if not _check("chair_loaded", await _wait_map(198)):
		return
	var map: XMapScene = _scene()
	_check("chair_events", range(1, 11).all(func(i): return _event(map, i) != null))
	for i in range(2, 10):
		await _run_event(map, i, [], "")
	_check("chair_npcs", _scene().map_id == 198)
	s.set_switch(1713, true)
	map.refresh_events()
	var n0 := battles.size()
	await _run_event(map, 1, [], "win")
	_check("chair_fight", battles.size() == n0 + 1 and battles[-1].troop == 668 and s.switch(948), [battles.slice(n0), s.switch(948)])


func _training() -> void:
	await _goto(18, 11, 28, 1, 19, Vector2i(9, 4))
	await _goto(19, 9, 5, 1, 18, Vector2i(11, 29))
	var s := _start(19, 9, 6)
	if not _check("train_loaded", await _wait_map(19)):
		return
	var map: XMapScene = _scene()
	_check("train_events", [1, 2, 8, 9, 10, 11, 12, 13, 14, 15, 16].all(func(i): return _event(map, i) != null))
	var base := battles.size()
	var posts := {2: 70, 8: 71, 9: 72, 10: 73, 11: 74, 12: 75, 13: 352, 14: 353, 15: 354, 16: 355}
	for ev in posts:
		var n0 := battles.size()
		# 选项：0 测试伤害；木桩打不死，只能让队员倒下收场（result 2）
		await _run_event(map, ev, [0], "lose")
		_check("train_ev%d_fight" % ev, battles.size() == n0 + 1 and battles[-1].troop == posts[ev] and battles[-1].result == 2, [battles.slice(n0)])
	# 抵抗伤害 1W：开关 174；清除后全关
	await _run_event(map, 2, [1, 0], "")
	_check("train_resist_on", s.switch(174) and not s.switch(175), [s.switch(174), s.switch(175)])
	await _run_event(map, 2, [1, 4], "")
	_check("train_resist_clear", not s.switch(174) and not s.switch(175) and not s.switch(176) and not s.switch(177))
	await _run_event(map, 2, [2], "")
	_check("train_leave", battles.size() == base + posts.size())


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
