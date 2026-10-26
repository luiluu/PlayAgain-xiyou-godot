extends Node
## 通天之上（Map069）及近邻（魂河畔 88／帐篷 89、蓝天飞艇公司 91、飨龙教堂 112）流程（地图场景里真走一遍）：
## - 通天之上：从恰兰吉尔南出口（Map071 EV3）进 (63,50)；滑稽树 EV51（被污染的滑稽币 731 换人道意志碎片 2530×3）；
##   镇凶塔 EV71（变量 202＝0 → 敌群 396 六臂魔猿，镇压后重抽 202）；通往魂河畔 EV44、蓝天飞艇公司 EV48、飨龙教堂 EV69、回恰兰吉尔 EV5；
## - 魂河畔：EV2 进帐篷 89，帐篷 EV5 回 (9,6)，南出口 EV4 回通天之上 (92,8)；
## - 蓝天飞艇公司：三位改装员商店（421／424／420）、出口回 (64,24)；
## - 飨龙教堂：南贤认证飨龙者（持 644～653 十种龙心，脚本 DesignationN 为界面选项，忽略）、祭坛商店 644、出口回 (64,90)。
## 贪婪宫殿（109）、毒蛇沼泽等其余出口未接，专项不踩。队伍生命攻击都很大（只查流程）。
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
	XSave.dir_override = "user://test_xiyou_floor_reach069"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261026)
	await _tianzhishang()
	await _neighbors()
	_finish()


func _has_shop(map: XMapScene, id: int, goods: int) -> bool:
	var e := _event(map, id)
	return e != null and e.command_list().any(func(c): return int(c.code) == 302 and int(c.parameters[1]) == goods)


## 通天之上：从恰兰吉尔进、滑稽树、镇凶塔、出口
func _tianzhishang() -> void:
	var s := _start(71, 38, 75, 2)
	if not _check("town_start", await _wait_map(71)):
		return
	await _run_event(_scene(), 3, [], "")
	if not _check("sky_entered", await _wait_map(69) and _scene().player.grid == Vector2i(63, 50), [_scene().map_id, _scene().player.grid]):
		return
	var map: XMapScene = _scene()
	_check("sky_events", [3, 5, 8, 44, 45, 46, 47, 48, 51, 65, 69, 71, 73, 75, 79].all(func(i): return _event(map, i) != null))
	# 滑稽树：没有币什么都不发生；有币换 3 个碎片
	await _run_event(map, 51, [0], "")
	_check("tree_no_coin", s.item_count(2530) == 0)
	s.gain_item(731, 1)
	await _run_event(map, 51, [0], "")
	_check("tree_purify", s.item_count(731) == 0 and s.item_count(2530) == 3, [s.item_count(731), s.item_count(2530)])
	# 镇凶塔：查看、镇压六臂魔猿
	s.set_variable(202, 0)
	var n0 := battles.size()
	await _run_event(map, 71, [0, 0], "win")
	map = _scene()
	_check("tower_boss", battles.size() == n0 + 1 and battles[-1].troop == 396 and battles[-1].result == 0, [battles.slice(n0)])
	_check("tower_var", int(s.variable(202)) >= 0 and int(s.variable(202)) <= 2, [s.variable(202)])
	# 回恰兰吉尔
	await _run_event(map, 5, [], "")
	_check("sky_back_town", await _wait_map(71) and _scene().player.grid == Vector2i(40, 75), [_scene().map_id, _scene().player.grid])


## 近邻三张图（含帐篷）：进出与商店
func _neighbors() -> void:
	var s := _start(69, 92, 8, 8)
	if not _check("sky_start", await _wait_map(69)):
		return
	await _run_event(_scene(), 44, [], "")
	if not _check("river_entered", await _wait_map(88) and _scene().player.grid == Vector2i(19, 20), [_scene().map_id, _scene().player.grid]):
		return
	var map: XMapScene = _scene()
	_check("river_events", range(1, 13).all(func(i): return _event(map, i) != null))
	await _run_event(map, 2, [], "")
	if not _check("tent_entered", await _wait_map(89) and _scene().player.grid == Vector2i(10, 7), [_scene().map_id, _scene().player.grid]):
		return
	await _run_event(_scene(), 5, [], "")
	if not _check("tent_back", await _wait_map(88) and _scene().player.grid == Vector2i(9, 6), [_scene().map_id, _scene().player.grid]):
		return
	_scene().player.direction = 2   # EV4 条件：面朝下
	await _run_event(_scene(), 4, [], "")
	_check("river_to_sky", await _wait_map(69) and _scene().player.grid == Vector2i(92, 8), [_scene().map_id, _scene().player.grid])
	# 蓝天飞艇公司
	await _run_event(_scene(), 48, [], "")
	if not _check("airship_entered", await _wait_map(91) and _scene().player.grid == Vector2i(16, 31), [_scene().map_id, _scene().player.grid]):
		return
	map = _scene()
	_check("airship_shops", _has_shop(map, 7, 421) and _has_shop(map, 10, 424) and _has_shop(map, 11, 420))
	await _run_event(map, 2, [], "")
	_check("airship_back", await _wait_map(69) and _scene().player.grid == Vector2i(64, 24), [_scene().map_id, _scene().player.grid])
	# 飨龙教堂
	await _run_event(_scene(), 69, [], "")
	if not _check("church_entered", await _wait_map(112) and _scene().player.grid == Vector2i(9, 19), [_scene().map_id, _scene().player.grid]):
		return
	map = _scene()
	_check("church_altar_shop", _has_shop(map, 5, 644))
	await _run_event(map, 4, [0], "")   # 缺龙心：不出现「认证成功」
	_check("church_certify_short", _event(map, 4) != null)
	for id in range(644, 654):
		s.gain_item(id, 1)
	await _run_event(map, 4, [0], "")
	_check("church_certify_done", _event(map, 4) != null)
	await _run_event(map, 3, [], "")
	_check("church_back", await _wait_map(69) and _scene().player.grid == Vector2i(64, 90), [_scene().map_id, _scene().player.grid])


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
