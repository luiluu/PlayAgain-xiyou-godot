extends Node
## 魔塔外围簇（盘点簇 8，悟空_55）流程（地图场景里真走一遍）：
## - Map004 EV29「塔外」→ Map195 魔塔外围 (43,14)，EV6 回 Map004 (4,16)；
## - Map195 EV7 洞窟入口 → Map149 无尽矿洞 (9,2)（公共事件 838 矿点刷新、变量 454 矿洞层数 1）；EV2 下一层（层数 2，再到 (9,2)）、
##   EV1 在第 2 层回上一层 (11,5)、在第 1 层问「要离开矿点么」→ Map195 (21,3)；
## - Map195 EV21 → Map207 奇兽捕捉 (8,35)：EV3 要变量 14≥1、开关 2303，扣物品 1974 奇兽捕捉许可证，
##   按变量 755（随机 1～13，固定住逐个试）开战敌群 319～327、334、335、337、338；EV1／EV2 回 Map004 (14,15)。
## 队伍生命攻击都很大（只查流程）。
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
	GameApp.fast_forward()  # 真走地图打战斗、等的是物理帧与计时器：headless 快进 4 倍（见 07_开发环境/测试提速.md）
	XSave.dir_override = "user://test_xiyou_floor_reach207"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261024)
	await _outside()
	await _beasts()
	MVEventCore.fixed_random = -1.0
	_finish()


func _outside() -> void:
	var s := _start(4, 3, 17, 8)
	if not _check("tower_loaded", await _wait_map(4)):
		return
	var map: XMapScene = _scene()
	_check("tower_door_present", _event(map, 29) != null)
	await _run_event(map, 29, [], "")
	if not _check("tower_entered", await _wait_map(195) and _scene().player.grid == Vector2i(43, 14), [_scene().map_id]):
		return
	map = _scene()
	_check("tower_events", [1, 5, 6, 7, 8, 13, 20, 21].all(func(i): return _event(map, i) != null))
	# 兔兔：选「我讨厌动物」
	await _run_event(map, 5, [1], "")
	# 出口回方桌大厅
	await _run_event(map, 6, [], "")
	_check("tower_back", await _wait_map(4) and _scene().player.grid == Vector2i(4, 16), [_scene().map_id, _scene().player.grid])
	# 再进，走矿洞
	await _run_event(_scene(), 29, [], "")
	if not _check("tower_reentered", await _wait_map(195)):
		return
	await _run_event(_scene(), 7, [], "")
	if not _check("mine_entered", await _wait_map(149) and _scene().player.grid == Vector2i(9, 2) and int(s.variable(454)) == 1, [_scene().map_id, s.variable(454)]):
		return
	map = _scene()
	_check("mine_events", [1, 2, 3, 4, 5].all(func(i): return _event(map, i) != null))
	await _run_event(map, 2, [0], "")
	_check("mine_level2", await _wait_map(149) and _scene().player.grid == Vector2i(9, 2) and int(s.variable(454)) == 2, [_scene().player.grid, s.variable(454)])
	await _run_event(_scene(), 1, [0], "")
	_check("mine_level1", await _wait_map(149) and _scene().player.grid == Vector2i(11, 5) and int(s.variable(454)) == 1, [_scene().player.grid, s.variable(454)])
	await _run_event(_scene(), 1, [0], "")
	_check("mine_exit", await _wait_map(195) and _scene().player.grid == Vector2i(21, 3), [_scene().map_id, _scene().player.grid])


const BEASTS := [319, 320, 321, 322, 323, 324, 325, 326, 327, 334, 335, 337, 338]


func _beasts() -> void:
	var s := _start(195, 8, 34, 2)
	if not _check("beast_door_loaded", await _wait_map(195)):
		return
	# 魔塔外围 EV21 页条件：变量 14「是否开启高难度」≥1
	s.set_variable(14, 1)
	_scene().refresh_events()
	await _run_event(_scene(), 21, [], "")
	if not _check("beast_entered", await _wait_map(207) and _scene().player.grid == Vector2i(8, 35), [_scene().map_id]):
		return
	var map: XMapScene = _scene()
	_check("beast_events", [1, 2, 3].all(func(i): return _event(map, i) != null))
	s.set_switch(2303, true)
	s.set_variable(14, 1)
	map.refresh_events()
	# 没有许可证：只提示，不开战，留在原图
	var n0 := battles.size()
	s.set_variable(754, -100000)
	await _run_event(map, 3, [], "win")
	_check("beast_no_permit", battles.size() == n0 and _scene().map_id == 207, [battles.slice(n0), _scene().map_id])
	# 出口
	await _run_event(map, 1, [], "")
	_check("beast_back", await _wait_map(4) and _scene().player.grid == Vector2i(14, 15), [_scene().map_id, _scene().player.grid])
	for i in range(BEASTS.size()):
		# 每只重新进图（捕捉完会被送回 Map004）；固定随机数：变量 755 ＝ 1 + floor(13 × r)
		MVEventCore.fixed_random = (float(i) + 0.5) / 13.0
		s = _start(207, 8, 30, 2)
		if not _check("beast_%d_loaded" % BEASTS[i], await _wait_map(207)):
			return
		s.set_switch(2303, true)
		s.set_variable(14, 1)
		s.set_variable(754, -100000)
		s.gain_item(1974, 1)
		_scene().refresh_events()
		n0 = battles.size()
		await _run_event(_scene(), 3, [], "win")
		_check("beast_%d_fight" % BEASTS[i], battles.size() == n0 + 1 and battles[-1].troop == BEASTS[i] and battles[-1].result == 0, [battles.slice(n0)])
		_check("beast_%d_permit_used" % BEASTS[i], s.item_count(1974) == 0, [s.item_count(1974)])
		_check("beast_%d_sent_back" % BEASTS[i], await _wait_map(4) and _scene().player.grid == Vector2i(14, 15), [_scene().map_id, _scene().player.grid])


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
