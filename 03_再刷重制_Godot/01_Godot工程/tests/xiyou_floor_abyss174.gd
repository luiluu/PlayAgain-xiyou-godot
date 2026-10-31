extends Node
## 痛苦深渊 Map174、孽镜深渊 Map184、未知存在 Map177 流程（地图场景里真走一遍；数值与事件对照由 xiyou_event_compare 承担）：
## - 入口：Map172 EV2 → Map174；Map181 EV4 → Map184。两图与妄语深渊 Map211 同模板：
##   深渊封印 EV5 第 1 页「解开封印」开关 75；第 2 页变量 108（Map174 取 1～5 敌群 551～555，Map184 取 1～6 敌群 640～645），
##   胜后开关 76、肝帝积分，再问「前往未知存在」（Map174 → Map177 (9,15)；Map184 → Map223，未接，测试只选「否」）。
## - 出口 EV8：Map174 变量 6＝34 传 Map120 (41,1)；Map184 变量 6＝36 传 Map180 (22,5)；重置变量 6 与开关 75～78。
## - Map177 与 Map210 同模板：封印 EV4 变量 244 取 1～6（敌群 584／585／586／588／587／589）开关 79；
##   主席 EV2（开关 2225 起，敌群 661）；出口 EV1 变量 6＝34／35 传 Map120／Map147 (12,7)。
## 队伍生命攻击都很大（只查流程）；用 MVEventCore.fixed_random 固定事件随机数。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const ABYSS := {174: [551, 552, 553, 554, 555], 184: [640, 641, 642, 643, 644, 645]}
const ABYSS_EXIT := {174: [34, 120, Vector2i(41, 1)], 184: [36, 180, Vector2i(22, 5)]}
const UNKNOWN := 177
const UNKNOWN_TROOPS := [584, 585, 586, 588, 587, 589]
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
	XSave.dir_override = "user://test_xiyou_floor_abyss174"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	for m in ABYSS:
		await _abyss_seal(m)
		await _abyss_exit(m)
	await _abyss_to_unknown()
	await _unknown_seal()
	await _unknown_chair()
	await _unknown_exit()
	MVEventCore.fixed_random = -1.0
	_finish()


func _abyss_seal(m: int) -> void:
	var s := _start(m, 19, 19)
	if not _check("abyss%d_loaded" % m, await _wait_map(m)):
		return
	var map: XMapScene = _scene()
	_check("abyss%d_events" % m, [1, 2, 3, 4, 5, 8].all(func(i): return _event(map, i) != null))
	var n0 := battles.size()
	await _run_event(map, 5, [1], "")
	_check("abyss%d_leave" % m, not s.switch(75) and battles.size() == n0)
	await _run_event(map, 5, [0], "")
	_check("abyss%d_unseal" % m, s.switch(75) and not s.switch(76))
	var troops: Array = ABYSS[m]
	for k in range(1, troops.size() + 1):
		s.set_switch(75, true)
		s.set_switch(76, false)
		map.refresh_events()
		MVEventCore.fixed_random = (k - 0.5) / troops.size()
		n0 = battles.size()
		var j0 := int(s.variable(206))
		await _run_event(map, 5, [0, 1], "win")
		map = _scene()
		_check("abyss%d_battle_%d" % [m, k], battles.size() == n0 + 1 and int(s.variable(108)) == k and battles[-1].troop == troops[k - 1] and battles[-1].result == 0, [battles.slice(n0), s.variable(108)])
		_check("abyss%d_points_%d" % [m, k], int(s.variable(214)) >= 2 and int(s.variable(206)) - j0 >= int(s.variable(214)), [s.variable(214), int(s.variable(206)) - j0])
		_check("abyss%d_stay_%d" % [m, k], s.switch(76) and map.map_id == m)
	MVEventCore.fixed_random = -1.0


func _abyss_exit(m: int) -> void:
	var dest: Array = ABYSS_EXIT[m]
	var s := _start(m, 19, 11)
	if not _check("abyss%d_exit_loaded" % m, await _wait_map(m)):
		return
	var map: XMapScene = _scene()
	s.set_variable(5, 1)
	s.set_variable(6, dest[0])
	s.set_switch(75, true)
	s.set_switch(76, true)
	await _run_event(map, 8, [1], "")
	_check("abyss%d_exit_no" % m, _scene().map_id == m and s.switch(75) and int(s.variable(6)) == dest[0])
	await _run_event(map, 8, [0], "")
	_check("abyss%d_exit_back" % m, await _wait_map(dest[1]) and _scene().player.grid == dest[2], [_scene().name])
	_check("abyss%d_exit_reset" % m, int(s.variable(6)) == 0 and not s.switch(75) and not s.switch(76), [s.variable(6), s.switch(75), s.switch(76)])


func _abyss_to_unknown() -> void:
	var s := _start(174, 19, 19)
	if not _check("abyss_go_loaded", await _wait_map(174)):
		return
	s.set_switch(75, true)
	var map: XMapScene = _scene()
	map.refresh_events()
	MVEventCore.fixed_random = 0.1
	await _run_event(map, 5, [0, 0], "win")
	MVEventCore.fixed_random = -1.0
	_check("abyss_go_unknown", await _wait_map(UNKNOWN) and _scene().player.grid == Vector2i(9, 15), [_scene().name])


func _unknown_seal() -> void:
	var s := _start(UNKNOWN, 9, 12)
	if not _check("unknown_loaded", await _wait_map(UNKNOWN)):
		return
	var map: XMapScene = _scene()
	_check("unknown_events", range(1, 7).all(func(i): return _event(map, i) != null))
	var n0 := battles.size()
	await _run_event(map, 4, [1], "")
	_check("unknown_seal_leave", not s.switch(79) and battles.size() == n0)
	for k in range(1, 7):
		s.set_switch(79, false)
		map.refresh_events()
		MVEventCore.fixed_random = (k - 0.5) / 6.0
		n0 = battles.size()
		var j0 := int(s.variable(206))
		await _run_event(map, 4, [0], "win")
		map = _scene()
		_check("unknown_battle_%d" % k, battles.size() == n0 + 1 and int(s.variable(244)) == k and battles[-1].troop == UNKNOWN_TROOPS[k - 1] and battles[-1].result == 0, [battles.slice(n0), s.variable(244)])
		_check("unknown_points_%d" % k, int(s.variable(206)) - j0 >= 2, int(s.variable(206)) - j0)
		_check("unknown_switch79_%d" % k, s.switch(79))
	MVEventCore.fixed_random = -1.0


## 主席页末有 214（暂时消除事件），每次都重新进图
func _fresh(switches: Array) -> Array:
	var s := _start(UNKNOWN, 15, 10)
	if not _check("chair_loaded", await _wait_map(UNKNOWN)):
		return []
	var map: XMapScene = _scene()
	s.set_switch(79, true)
	for i in switches:
		s.set_switch(i, true)
	map.refresh_events()
	return [s, map]


func _unknown_chair() -> void:
	var r := await _fresh([])
	var s: XState = r[0]
	await _run_event(r[1], 2, [], "")
	_check("chair_hello", s.switch(2225))
	r = await _fresh([2225])
	s = r[0]
	await _run_event(r[1], 2, [0], "")
	_check("chair_draw", _item_total(s) >= 1, s.items)
	r = await _fresh([2225])
	var n0 := battles.size()
	await _run_event(r[1], 2, [1], "win")
	_check("chair_fight", battles.size() == n0 + 1 and battles[-1].troop == 661 and battles[-1].result == 0, battles.slice(n0))
	r = await _fresh([2302])
	MVEventCore.fixed_random = 0.99
	n0 = battles.size()
	await _run_event(r[1], 2, [], "win")
	MVEventCore.fixed_random = -1.0
	_check("researcher_fight", battles.size() == n0 + 1 and battles[-1].troop == 767, battles.slice(n0))


func _unknown_exit() -> void:
	for dest in [[34, 120, Vector2i(41, 1)], [35, 147, Vector2i(12, 7)]]:
		var s := _start(UNKNOWN, 9, 7)
		if not _check("unknown_exit_loaded", await _wait_map(UNKNOWN)):
			return
		var map: XMapScene = _scene()
		s.set_variable(5, 1)
		s.set_variable(6, dest[0])
		for i in range(75, 80):
			s.set_switch(i, true)
		await _run_event(map, 1, [1], "")
		_check("unknown_exit_no_%d" % dest[0], _scene().map_id == UNKNOWN and s.switch(79))
		await _run_event(map, 1, [0], "")
		_check("unknown_exit_back_%d" % dest[0], await _wait_map(dest[1]) and _scene().player.grid == dest[2], [_scene().name])
		_check("unknown_exit_reset_%d" % dest[0], int(s.variable(6)) == 0 and not s.switch(75) and not s.switch(79), [s.variable(6), s.switch(75), s.switch(79)])


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
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
