extends Node
## 未知存在 Map223、Map141、Map176 流程（地图场景里真走一遍；数值与事件对照由 xiyou_event_compare 承担）。三张图与 Map210 同模板：
## - 入口：Map223 ← 孽镜深渊 Map184 封印「前往未知存在」(9,14)；Map141 ← Map167／168 EV5；Map176 ← Map164／165 EV5。
## - 封印 EV4：变量 244 取 1～N 对应敌群（Map223 647～659、Map141 577～582、Map176 570～575），胜后开关 79、肝帝积分。
## - 副本协会主席（Map223 EV2、Map141 EV8、Map176 EV7）：开关 79 起按开关 2225～2229 分页抽奖，选「还得看脸」打敌群 661；开关 2302 页天道研究员（敌群 767）。
## - 出口 EV1：按变量 6 传回各自楼层并重置、关开关 75～79。
## - Map141 克苏鲁的化身 EV7：开关 696 时按变量 215 卖货或打敌群 413～416。
## 队伍生命攻击都很大（只查流程）；用 MVEventCore.fixed_random 固定事件随机数。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const MAPS := {
	223: {"troops": [647, 648, 649, 650, 651, 652, 653, 654, 655, 656, 657, 658, 659], "chair": 2, "events": 6,
		"exits": [[36, 180, Vector2i(22, 5)], [37, 182, Vector2i(18, 1)]]},
	141: {"troops": [577, 578, 579, 580, 581, 582], "chair": 8, "events": 8,
		"exits": [[32, 119, Vector2i(38, 5)], [33, 118, Vector2i(43, 46)]]},
	176: {"troops": [570, 571, 572, 573, 574, 575], "chair": 7, "events": 7,
		"exits": [[28, 116, Vector2i(17, 2)], [29, 117, Vector2i(35, 1)]]},
}
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
	XSave.dir_override = "user://test_xiyou_floor_unknown223"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261023)
	await _abyss_to_unknown()
	for m in MAPS:
		await _seal(m)
		await _chair(m)
		await _exit(m)
	await _cthulhu()
	MVEventCore.fixed_random = -1.0
	_finish()


## 孽镜深渊 Map184 封印选「前往未知存在」：传到 Map223 (9,14)
func _abyss_to_unknown() -> void:
	var s := _start(184, 19, 19)
	if not _check("abyss184_loaded", await _wait_map(184)):
		return
	s.set_switch(75, true)
	var map: XMapScene = _scene()
	map.refresh_events()
	MVEventCore.fixed_random = 0.1
	await _run_event(map, 5, [0, 0], "win")
	MVEventCore.fixed_random = -1.0
	_check("abyss184_to_223", await _wait_map(223) and _scene().player.grid == Vector2i(9, 14), [_scene().name])


func _seal(m: int) -> void:
	var s := _start(m, 9, 12)
	if not _check("m%d_loaded" % m, await _wait_map(m)):
		return
	var map: XMapScene = _scene()
	_check("m%d_events" % m, range(1, int(MAPS[m].events) + 1).all(func(i): return _event(map, i) != null))
	var n0 := battles.size()
	await _run_event(map, 4, [1], "")
	_check("m%d_seal_leave" % m, not s.switch(79) and battles.size() == n0)
	var troops: Array = MAPS[m].troops
	for k in range(1, troops.size() + 1):
		s.set_switch(79, false)
		map.refresh_events()
		MVEventCore.fixed_random = (k - 0.5) / troops.size()
		n0 = battles.size()
		var j0 := int(s.variable(206))
		await _run_event(map, 4, [0], "win")
		map = _scene()
		_check("m%d_battle_%d" % [m, k], battles.size() == n0 + 1 and int(s.variable(244)) == k and battles[-1].troop == troops[k - 1] and battles[-1].result == 0, [battles.slice(n0), s.variable(244)])
		_check("m%d_points_%d" % [m, k], int(s.variable(206)) - j0 >= 2, int(s.variable(206)) - j0)
		_check("m%d_switch79_%d" % [m, k], s.switch(79))
	MVEventCore.fixed_random = -1.0


## 主席页末有 214（暂时消除事件），每次都重新进图
func _fresh(m: int, switches: Array) -> Array:
	var s := _start(m, 9, 12)
	if not _check("m%d_chair_loaded" % m, await _wait_map(m)):
		return []
	var map: XMapScene = _scene()
	s.set_switch(79, true)
	for i in switches:
		s.set_switch(i, true)
	map.refresh_events()
	return [s, map]


func _chair(m: int) -> void:
	var ev: int = MAPS[m].chair
	var r := await _fresh(m, [])
	var s: XState = r[0]
	await _run_event(r[1], ev, [], "")
	_check("m%d_chair_hello" % m, s.switch(2225))
	r = await _fresh(m, [2225])
	s = r[0]
	await _run_event(r[1], ev, [0], "")
	_check("m%d_chair_draw" % m, _item_total(s) >= 1, s.items)
	r = await _fresh(m, [2225])
	var n0 := battles.size()
	await _run_event(r[1], ev, [1], "win")
	_check("m%d_chair_fight" % m, battles.size() == n0 + 1 and battles[-1].troop == 661 and battles[-1].result == 0, battles.slice(n0))
	r = await _fresh(m, [2302])
	MVEventCore.fixed_random = 0.99
	n0 = battles.size()
	await _run_event(r[1], ev, [], "win")
	MVEventCore.fixed_random = -1.0
	_check("m%d_researcher_fight" % m, battles.size() == n0 + 1 and battles[-1].troop == 767, battles.slice(n0))


func _exit(m: int) -> void:
	for dest in MAPS[m].exits:
		var s := _start(m, 9, 7)
		if not _check("m%d_exit_loaded" % m, await _wait_map(m)):
			return
		var map: XMapScene = _scene()
		s.set_variable(5, 1)
		s.set_variable(6, dest[0])
		for i in range(75, 80):
			s.set_switch(i, true)
		await _run_event(map, 1, [1], "")
		_check("m%d_exit_no_%d" % [m, dest[0]], _scene().map_id == m and s.switch(79))
		await _run_event(map, 1, [0], "")
		_check("m%d_exit_back_%d" % [m, dest[0]], await _wait_map(dest[1]) and _scene().player.grid == dest[2], [_scene().name])
		_check("m%d_exit_reset_%d" % [m, dest[0]], int(s.variable(6)) == 0 and not s.switch(75) and not s.switch(79), [s.variable(6), s.switch(75), s.switch(79)])


## Map141 克苏鲁的化身：变量 215＝4／5 时打手下敌群 413／414 并开关 697
func _cthulhu() -> void:
	for v in [[4, 413], [5, 414]]:
		var s := _start(141, 9, 12)
		if not _check("cthulhu_loaded", await _wait_map(141)):
			return
		var map: XMapScene = _scene()
		s.set_switch(696, true)
		s.set_variable(215, v[0])
		map.refresh_events()
		var n0 := battles.size()
		await _run_event(map, 7, [], "win")
		_check("cthulhu_fight_%d" % v[0], battles.size() == n0 + 1 and battles[-1].troop == v[1] and s.switch(697), [battles.slice(n0), s.switch(697)])


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
