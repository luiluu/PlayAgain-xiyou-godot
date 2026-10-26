extends Node
## 十三层要塞遗址 Map029、十二层冰封洞穴 Map023、破败城堡 Map035／实验室 Map036 流程（地图场景里真走一遍）：
## - Map029：守层者圣骑士·瑟伦 EV1（敌群 111，胜后变量 20＋1、等级上限 38）、副本门 EV2（高级副本符文 110 → Map035 (14,25)）、
##   嘤嘤怪 EV3（敌群 1）、辛德瑞 EV4 回大厅；
## - Map035：试验品 EV16／8／9／28（敌群 107／139／140／141）、实验用狼 EV17 等（敌群 143，变量 267≥88 时被吓跑）、
##   入口 EV7 → Map036 (8,12)、逃离阵 EV29～31 → Map029 (10,31) 并重置；
## - Map036：塔克·修 EV2（敌群 142，开关 64）、通关页发奖并回 Map029 (10,31) 重置、EV1 回 Map035 (17,3)；
## - Map023：守层者奥法师·莉莎 EV1（敌群 110，等级上限 35）、副本门 EV2（中级副本符文 110 → Map034 (33,21)，画面下雪 236）、辛德瑞 EV3。
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
	s.gain_item(RUNE, 3)
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = 8
	_party()
	get_tree().change_scene_to_file(MAP_SCENE)
	return s


func _run() -> void:
	GameApp.fast_forward()  # 真走地图打战斗、等的是物理帧与计时器：headless 快进 4 倍（见 07_开发环境/测试提速.md）
	XSave.dir_override = "user://test_xiyou_floor_fortress029"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261024)
	await _fortress()
	await _castle()
	await _ice()
	await _finish()


func _fortress() -> void:
	var s := _start(29, 34, 24)
	if not _check("f029_loaded", await _wait_map(29)):
		return
	var map: XMapScene = _scene()
	s.set_variable(20, 13)
	var n0 := battles.size()
	await _run_event(map, 1, [0], "win")
	map = _scene()
	_check("guard_fight", battles.size() == n0 + 1 and battles[-1].troop == 111 and battles[-1].result == 0, battles.slice(n0))
	_check("guard_reward", int(s.variable(20)) == 14 and s.self_switch(29, 1, "A") and s.item_count(249) == 1 and s.actor_max_level == 38, [s.variable(20), s.item_count(249), s.actor_max_level])
	# 嘤嘤怪只在独立开关 A 开启时出现（原版由成就系统类事件触发，这里直接打开）
	s.set_self_switch(29, 3, "A", true)
	map.refresh_events()
	var n1 := battles.size()
	await _run_event(map, 3, [], "win")
	map = _scene()
	_check("yingying", battles.size() == n1 + 1 and battles[-1].troop == 1 and not s.self_switch(29, 3, "A"), battles.slice(n1))
	# 副本门：缺符文挡住，有符文进 Map035 (14,25)
	var rune := s.item_count(RUNE)
	s.gain_item(RUNE, -rune)
	await _run_event(map, 2, [0], "")
	_check("door_no_rune", _scene().map_id == 29 and int(s.variable(5)) == 0, [_scene().map_id, s.variable(5)])
	s.gain_item(RUNE, 3)
	await _run_event(map, 2, [0], "")
	_check("door_entered", await _wait_map(35) and _scene().player.grid == Vector2i(14, 25), [_scene().map_id, _scene().player.grid])
	_check("door_vars", int(s.variable(5)) == 1 and int(s.variable(6)) == 8 and s.item_count(RUNE) == 2, [s.variable(5), s.variable(6), s.item_count(RUNE)])
	# 随机遇敌表在冻结数据里是敌群 104～108
	var tab: Array = XDB.map(29).get("encounterList", [])
	_check("encounters", tab.map(func(r): return int(r.troopId)) == [104, 105, 106, 107, 108], tab)
	# 辛德瑞回大厅
	s.map_id = 29
	get_tree().change_scene_to_file(MAP_SCENE)
	if not _check("f029_reloaded", await _wait_map(29)):
		return
	await _run_event(_scene(), 4, [0], "")
	_check("cindy_home", await _wait_map(4) and _scene().player.grid == Vector2i(14, 23), [_scene().map_id])


func _castle() -> void:
	var s := _start(35, 14, 25)
	s.set_variable(5, 1)     # 进副本时已加一，离开时再减回 0
	s.set_variable(21, 1)
	if not _check("f035_loaded", await _wait_map(35)):
		return
	var map: XMapScene = _scene()
	# 四个试验品
	var bosses := {16: 107, 8: 139, 9: 140, 28: 141}
	for ev in bosses:
		var n := battles.size()
		await _run_event(map, ev, [], "win")
		map = _scene()
		_check("boss%d_fight" % ev, battles.size() == n + 1 and battles[-1].troop == bosses[ev] and battles[-1].result == 0, battles.slice(n))
	_check("boss_switches", s.switch(61) and s.switch(62) and s.switch(63), [s.switch(61), s.switch(62), s.switch(63)])
	# 实验用狼：变量 267 < 88 战斗，≥ 88 被吓跑
	s.set_variable(267, 0)
	var n1 := battles.size()
	await _run_event(map, 17, [], "win")
	map = _scene()
	_check("wolf_fight", battles.size() == n1 + 1 and battles[-1].troop == 143, battles.slice(n1))
	s.set_variable(267, 88)
	var n2 := battles.size()
	await _run_event(map, 18, [], "win")
	map = _scene()
	_check("wolf_scared", battles.size() == n2)
	# 入口 EV7 → Map036 (8,12)
	await _run_event(map, 7, [], "")
	_check("to_lab", await _wait_map(36) and _scene().player.grid == Vector2i(8, 12), [_scene().map_id])
	map = _scene()
	# Map036：塔克·修
	var n3 := battles.size()
	await _run_event(map, 2, [], "win")
	map = _scene()
	_check("tuck_fight", battles.size() == n3 + 1 and battles[-1].troop == 142 and battles[-1].result == 0 and s.switch(64), [battles.slice(n3), s.switch(64)])
	# 通关页：没有 38 号角色就回 Map029 (10,31) 并重置
	# 原版持有179必出门；没有179也有随机出门的可能。强制出现门并选「离开」，固定本例的回程。
	s.gain_item(179, 1)
	await _run_event(map, 2, [1], "")
	_check("lab_portal_declined", int(s.variable(106)) == 1, s.variable(106))
	_check("lab_exit", await _wait_map(29) and _scene().player.grid == Vector2i(10, 31), [_scene().map_id])
	_check("lab_reset", int(s.variable(5)) == 0 and int(s.variable(6)) == 0 and not s.switch(61) and not s.switch(64), [s.variable(5), s.switch(61)])
	# 回 Map035，逃离阵
	s.map_id = 35
	s.x = 14
	s.y = 25
	s.direction = 2        # 逃离阵要玩家面朝下
	s.set_variable(5, 1)
	get_tree().change_scene_to_file(MAP_SCENE)
	if not _check("f035_reloaded", await _wait_map(35)):
		return
	await _run_event(_scene(), 29, [0], "")
	_check("escape", await _wait_map(29) and _scene().player.grid == Vector2i(10, 31), [_scene().map_id])


func _ice() -> void:
	var s := _start(23, 28, 11)
	if not _check("f023_loaded", await _wait_map(23)):
		return
	var map: XMapScene = _scene()
	s.set_variable(20, 12)
	var n0 := battles.size()
	await _run_event(map, 1, [0], "win")
	map = _scene()
	_check("ice_guard_fight", battles.size() == n0 + 1 and battles[-1].troop == 110 and battles[-1].result == 0, battles.slice(n0))
	_check("ice_guard_reward", int(s.variable(20)) == 13 and s.item_count(250) == 1 and s.actor_max_level == 35, [s.variable(20), s.item_count(250), s.actor_max_level])
	var tab: Array = XDB.map(23).get("encounterList", [])
	_check("ice_encounters", tab.map(func(r): return int(r.troopId)) == [99, 100, 101, 102, 103], tab)
	# 副本门：进 Map034 (33,21) 并开始下雪
	_check("no_snow_before", s.screen.weather_type == "none")
	await _run_event(map, 2, [0], "")
	_check("ice_door_entered", await _wait_map(34) and _scene().player.grid == Vector2i(33, 21), [_scene().map_id])
	_check("ice_snow", s.screen.weather_type == "snow" and s.screen.weather_power_target == 7.0, s.screen.to_dict())
	# 天气画面层在物理帧里刷新可见性，负载高时一帧里还没轮到：等它出现（最多 600 帧）
	var w := 0
	while w < 600 and not _scene().screen_fx._weather.visible:
		await get_tree().process_frame
		w += 1
	_check("ice_snow_view", _scene().screen_fx._weather.visible)
	# 洞穴里的出口回 Map023；辛德瑞回大厅
	s.map_id = 23
	s.x = 28
	s.y = 35
	get_tree().change_scene_to_file(MAP_SCENE)
	if not _check("f023_reloaded", await _wait_map(23)):
		return
	await _run_event(_scene(), 3, [0], "")
	_check("ice_cindy_home", await _wait_map(4) and _scene().player.grid == Vector2i(14, 23), [_scene().map_id])


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
