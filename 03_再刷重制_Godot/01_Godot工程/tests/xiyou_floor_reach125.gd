extends Node
## 伐木场／伐木者小屋（盘点簇 6，悟空_54）流程（地图场景里真走一遍）：
## - 入口：Map006 EV11（接触）→ Map125 (32,11)；Map125 EV1 回 Map006 (6,21)；
## - Map125 EV2 偷伐者的小屋之门（页条件：开关 1569「3层普通」）：缺符文提示、有符文 24 扣一张进 Map126 (20,35)，
##   变量 450＝1、5＝1、21＋1、6＝23；
## - Map126：四首领 EV16～19（敌群 429／428／427／430，各开开关 236／233／234／235、变量 288＋1），
##   巨灵神 EV15（敌群 431，288≥4 后换页，开 883、231）、宝箱页（变量 450＝1，公共事件 1427，奖励随变量 94）传回 Map125 (6,23) 并重置；
##   逃离阵 EV1；副本协会主席 EV2（开关 883 后出现，敌群 661）。
## 原版随机分支一律固定（变量 94 的奖励档）；队伍生命攻击都很大（只查流程）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 240000   # 并行负载下单个事件可能跑到一两分钟，别用 90 秒的墙钟判失败
const WaitBudget := preload("res://tests/wait_budget.gd")  # 墙钟与帧数都过了才算超时（tools30）

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
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while t0.waiting():
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
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while not st.done and t0.waiting():
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
	XSave.dir_override = "user://test_xiyou_floor_reach125"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261024)
	await _clear()
	await _escape()
	_finish()


## 入口→挑战→四首领→巨灵神→宝箱→回伐木场
func _clear() -> void:
	var s := _start(6, 1, 20, 4)
	if not _check("enter_door_loaded", await _wait_map(6)):
		return
	_check("enter_door_present", _event(_scene(), 11) != null)
	await _run_event(_scene(), 11, [], "")
	if not _check("lumber_entered", await _wait_map(125) and _scene().player.grid == Vector2i(32, 11), [_scene().map_id]):
		return
	var map: XMapScene = _scene()
	_check("lumber_events", range(1, 13).all(func(i): return _event(map, i) != null))
	await _run_event(map, 1, [], "")
	_check("lumber_back", await _wait_map(6) and _scene().player.grid == Vector2i(6, 21), [_scene().map_id])
	await _run_event(_scene(), 11, [], "")
	if not _check("lumber_reentered", await _wait_map(125)):
		return
	map = _scene()
	s.set_switch(1569, true)
	map.refresh_events()
	await _run_event(map, 2, [0], "")
	_check("door_no_rune", _scene().map_id == 125 and int(s.variable(5)) == 0, [_scene().map_id, s.variable(5)])
	s.gain_item(24, 1)
	await _run_event(map, 2, [0], "")
	if not _check("hut_entered", await _wait_map(126) and _scene().player.grid == Vector2i(20, 35), [_scene().map_id]):
		return
	map = _scene()
	_check("entry_vars", int(s.variable(450)) == 1 and int(s.variable(5)) == 1 and int(s.variable(21)) == 1 and int(s.variable(6)) == 23 and s.item_count(24) == 0, [s.variable(450), s.variable(5), s.variable(21), s.variable(6), s.item_count(24)])
	_check("hut_events", [1, 2, 15, 16, 17, 18, 19].all(func(i): return _event(map, i) != null))
	s.set_variable(94, 1)   # 奖励档固定（原版进门时随机 1～8）
	var n0 := battles.size()
	var bosses := {16: 429, 17: 428, 18: 427, 19: 430}
	for ev in bosses:
		await _run_event(map, ev, [], "win")
		map = _scene()
		_check("boss%d_fight" % ev, battles.size() > n0 and battles[-1].troop == bosses[ev] and battles[-1].result == 0, battles.slice(n0))
		n0 = battles.size()
	_check("bosses_counted", int(s.variable(288)) == 4 and s.switch(233) and s.switch(234) and s.switch(235) and s.switch(236), [s.variable(288), s.switch(233)])
	map.refresh_events()
	await _run_event(map, 15, [], "win")
	map = _scene()
	_check("giant_fight", battles.size() == n0 + 1 and battles[-1].troop == 431 and battles[-1].result == 0 and s.switch(231) and s.switch(883), [battles.slice(n0), s.switch(231)])
	map.refresh_events()
	await _run_event(map, 15, [], "")
	_check("chest_returned", await _wait_map(125) and _scene().player.grid == Vector2i(6, 23), [_scene().map_id])
	_check("chest_reset", int(s.variable(5)) == 0 and int(s.variable(450)) == 0 and not s.switch(231), [s.variable(5), s.variable(450), s.switch(231)])


## 逃离阵、副本协会主席
func _escape() -> void:
	var s := _start(126, 20, 36, 8)
	if not _check("esc_loaded", await _wait_map(126)):
		return
	s.set_variable(5, 1)
	s.set_variable(450, 1)
	s.set_variable(21, 1)
	var map: XMapScene = _scene()
	await _run_event(map, 1, [0], "")
	_check("escape_out", await _wait_map(125) and _scene().player.grid == Vector2i(6, 24) and int(s.variable(5)) == 0 and int(s.variable(21)) == 0, [_scene().map_id, s.variable(5), s.variable(21)])
	s = _start(126, 21, 36, 8)
	if not _check("pres_loaded", await _wait_map(126)):
		return
	map = _scene()
	var n0 := battles.size()
	_check("president_hidden_before_883", not s.switch(883))
	s.set_switch(883, true)
	map.refresh_events()
	await _run_event(map, 2, [1], "win")
	_check("president_fight", battles.size() == n0 + 1 and battles[-1].troop == 661, [battles.slice(n0)])


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
