extends Node
## 指路灯能到的四张图（云端第二批）流程（地图场景里真走一遍）：
## - 黑金村 Map068：指路灯 388 的公共事件 230（变量 21≠0 时只提示「正在挑战副本」）→ (17,21)；吞魂魔 EV10（敌群 262，开关 110）；
##   涅斐莉 EV9 第 2 页「没问题」→ 32 号入队，图像、名字、职业 32、称号「女战士」，独立开关 A 后隐去；
## - 肝帝之地 Map185：指路灯 1634 的公共事件 1214 → (15,35)；辛德瑞 EV1「传送」→ 大厅 Map004 (14,23)；
## - 牛马关 Map067：指路灯 386 的公共事件 229 → (45,33)；马神残影 EV2（四匹人马 41～44 在队且都≥35 级）传授技能，开开关 134、2305，
##   独立开关 A；牛马之森入口 EV9（开关 134＋1717）缺符文提示，有符文 24 扣一张进 Map138 (29,36)，变量 450＝1、5＝1、21＋1、6＝44；
## - 牛马之森 Map138：五处牛马护卫 EV1～5（敌群 592，变量 351＋1，暂时消除），351≥3 后首领 EV6（敌群 593，开 910、274，
##   1717→1718 升档）；开关 274 后宝箱页（变量 450＝1，奖励随变量 94）传回 Map067 (1,25) 并重置；逃离阵 EV7。
## 原版随机分支一律固定（变量 94 的奖励档）；队伍生命攻击都很大（只查流程）。
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
	XSave.dir_override = "user://test_xiyou_floor_reach068"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261025)
	await _heijin()
	await _gandi()
	await _niuma()
	_finish()


## 指路灯：照物品页用完后的做法预约公共事件，回地图由场景执行
func _lamp(ce: int) -> void:
	XState.current.reserve_common_event(ce)
	await _frames(2)


## 黑金村：进村、吞魂魔、涅斐莉入队；副本中用灯只提示
func _heijin() -> void:
	var s := _start(10, 10, 10, 2)
	if not _check("heijin_start", await _wait_map(10)):
		return
	s.set_variable(21, 1)
	await _lamp(230)
	await _frames(30)
	_check("heijin_blocked_in_dungeon", _scene().map_id == 10 and not _scene().busy, [_scene().map_id])
	s.set_variable(21, 0)
	await _lamp(230)
	if not _check("heijin_entered", await _wait_map(68) and _scene().player.grid == Vector2i(17, 21), [_scene().map_id]):
		return
	var map: XMapScene = _scene()
	_check("heijin_events", range(1, 11).all(func(i): return _event(map, i) != null))
	var n0 := battles.size()
	await _run_event(map, 10, [], "win")
	map = _scene()
	_check("heijin_boss", battles.size() == n0 + 1 and battles[-1].troop == 262 and battles[-1].result == 0 and s.switch(110), [battles.slice(n0), s.switch(110)])
	map.refresh_events()
	await _run_event(map, 9, [0], "")
	var a := s.actor(32)
	_check("heijin_recruit", s.party.has(32) and a.display_name() == "涅斐莉" and a.nickname == "女战士" and a.class_id == 32
		and str(a.data().characterName) == "QY xingzou" and int(a.data().characterIndex) == 1 and str(a.data().faceName) == "qgtx"
		and int(a.data().faceIndex) == 3 and str(a.data().battlerName) == "nfl" and s.self_switch(68, 9, "A"),
		[s.party, a.display_name(), a.nickname, a.class_id, a.data().characterName, s.self_switch(68, 9, "A")])
	map.refresh_events()
	_check("heijin_recruit_gone", _event(map, 9).command_list().size() <= 1)


## 肝帝之地：进图、辛德瑞传回大厅
func _gandi() -> void:
	var s := _start(10, 10, 10, 2)
	if not _check("gandi_start", await _wait_map(10)):
		return
	await _lamp(1214)
	if not _check("gandi_entered", await _wait_map(185) and _scene().player.grid == Vector2i(15, 35), [_scene().map_id]):
		return
	var map: XMapScene = _scene()
	_check("gandi_encounters", map.map_data.get("encounterList", []).size() == 14 and int(map.map_data.get("encounterStep", 0)) == 5)
	await _run_event(map, 1, [0], "")
	_check("gandi_back", await _wait_map(4) and _scene().player.grid == Vector2i(14, 23), [_scene().map_id])


## 牛马关：马神残影传授、牛马之森副本一轮
func _niuma() -> void:
	var s := _start(10, 10, 10, 2)
	if not _check("niuma_start", await _wait_map(10)):
		return
	s.actor_max_level = 99
	for id in [41, 42, 43, 44]:
		s.add_actor(id)
		s.actor(id).change_level_mv(35)
	_party()
	await _lamp(229)
	if not _check("niuma_entered", await _wait_map(67) and _scene().player.grid == Vector2i(45, 33), [_scene().map_id]):
		return
	var map: XMapScene = _scene()
	_check("niuma_door_hidden", _event(map, 9).command_list().size() <= 1)
	await _run_event(map, 2, [], "")
	var learned := [[42, 2841], [42, 3700], [43, 3700], [43, 3704], [44, 3700], [44, 3701], [41, 3700], [41, 3705], [41, 2843]]
	_check("niuma_teach", learned.all(func(p): return s.actor(p[0]).skill_ids.has(p[1])) and s.switch(134) and s.switch(2305) and s.self_switch(67, 2, "A"),
		[learned.filter(func(p): return not s.actor(p[0]).skill_ids.has(p[1])), s.switch(134), s.switch(2305)])
	# 入口第 1 页（开关 134＋1717「普通」）：缺符文提示；有符文进副本
	s.set_switch(1717, true)
	map.refresh_events()
	await _run_event(map, 9, [0], "")
	_check("niuma_no_rune", _scene().map_id == 67 and int(s.variable(5)) == 0, [_scene().map_id, s.variable(5)])
	s.gain_item(24, 1)
	await _run_event(map, 9, [0], "")
	if not _check("forest_entered", await _wait_map(138) and _scene().player.grid == Vector2i(29, 36), [_scene().map_id]):
		return
	map = _scene()
	_check("forest_vars", int(s.variable(450)) == 1 and int(s.variable(5)) == 1 and int(s.variable(21)) == 1 and int(s.variable(6)) == 44 and s.item_count(24) == 0,
		[s.variable(450), s.variable(5), s.variable(21), s.variable(6), s.item_count(24)])
	s.set_variable(94, 1)   # 奖励档固定（原版进门时随机）
	var n0 := battles.size()
	for ev in [1, 2, 3]:
		await _run_event(map, ev, [], "win")
		map = _scene()
	_check("forest_guards", battles.size() == n0 + 3 and battles.slice(n0).all(func(b): return b.troop == 592 and b.result == 0) and int(s.variable(351)) == 3,
		[battles.slice(n0), s.variable(351)])
	map.refresh_events()
	n0 = battles.size()
	await _run_event(map, 6, [], "win")
	map = _scene()
	_check("forest_boss", battles.size() == n0 + 1 and battles[-1].troop == 593 and s.switch(910) and s.switch(274) and s.switch(1718) and not s.switch(1717),
		[battles.slice(n0), s.switch(910), s.switch(274), s.switch(1718)])
	map.refresh_events()
	await _run_event(map, 6, [], "")
	_check("forest_chest_returned", await _wait_map(67) and _scene().player.grid == Vector2i(1, 25), [_scene().map_id])
	_check("forest_reset", int(s.variable(5)) == 0 and int(s.variable(21)) == 0 and not s.switch(274), [s.variable(5), s.variable(21), s.switch(274)])
	# 逃离阵
	s = _start(138, 30, 35, 2)
	if not _check("forest_escape_loaded", await _wait_map(138)):
		return
	s.set_variable(5, 1)
	s.set_variable(21, 1)
	s.set_switch(274, true)
	await _run_event(_scene(), 7, [0], "")
	_check("forest_escape", await _wait_map(67) and _scene().player.grid == Vector2i(1, 25) and int(s.variable(5)) == 0 and int(s.variable(21)) == 0 and not s.switch(274),
		[_scene().map_id, s.variable(5), s.variable(21)])


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
