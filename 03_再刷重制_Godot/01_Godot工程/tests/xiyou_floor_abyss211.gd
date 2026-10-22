extends Node
## 妄语深渊（Map211）流程（地图场景里真走一遍；数值与事件对照由 xiyou_event_compare 承担，这里查流程跑得通）：
## - 入口：二十八／二十九层副本首领宝箱问「是否前往妄语深渊」→ Map211 (19,23)。
## - 封印 EV5：第 1 页「解开封印」→ 开关 75；第 2 页「继续解开封印」→ 变量 108 取 1～6 对应敌群 717～722，胜后成就 82、
##   肝帝积分（变量 206 至少加变量 214 的 2～5，公共事件 1439 另有积分券）、开关 76；「前往未知存在」（Map210，未开放）选否留在原地；「离开」什么也不变。
## - 出口 EV8：按变量 6（38／39／40）传回 Map145 并公共事件 1024 重置副本变量（变量 5／6 归零）、关开关 75～78。
## 队伍生命攻击都很大（只查流程）；战斗中直接击倒敌人。事件走地图场景的 run_event。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const ABYSS := 211
const SEAL := 5
const EXIT := 8
const TIMEOUT_MS := 90000

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
	XSave.dir_override = "user://test_xiyou_floor_abyss211"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261022)
	await _seal()
	await _exit()
	_finish()


func _seal() -> void:
	var s := _start(ABYSS, 19, 18)
	if not _check("abyss_loaded", await _wait_map(ABYSS)):
		return
	var map: XMapScene = _scene()
	_check("abyss_events", [1, 2, 3, 4, 5, EXIT].all(func(i): return _event(map, i) != null))
	# 第 1 页，选「离开」：什么也不变
	await _run_event(map, SEAL, [1], "")
	_check("seal_leave", not s.switch(75) and battles.is_empty(), battles)
	# 解开封印：开关 75，之后事件换到第 2 页
	await _run_event(map, SEAL, [0], "")
	_check("seal_opened", s.switch(75) and not s.switch(76), [s.switch(75), s.switch(76)])
	# 第 2 页「离开」：什么也不变
	await _run_event(map, SEAL, [1], "")
	_check("seal2_leave", battles.is_empty() and not s.switch(76), battles)
	# 继续解开封印：战斗、奖励、开关 76；未知存在选「否」
	var j0 := int(s.variable(206))
	await _run_event(map, SEAL, [0, 1], "win")
	map = _scene()
	var v108 := int(s.variable(108))
	_check("seal2_battle", battles.size() == 1 and v108 >= 1 and v108 <= 6 and battles[0].troop == 716 + v108 and battles[0].result == 0, [battles, v108])
	var gain := int(s.variable(206)) - j0
	_check("seal2_points", int(s.variable(214)) >= 2 and int(s.variable(214)) <= 5 and gain >= int(s.variable(214)), [gain, s.variable(214)])
	_check("seal2_reward_switch", s.switch(76), s.switch(76))
	_check("seal2_stay", _scene() is XMapScene and _scene().map_id == ABYSS, _scene().name)


func _exit() -> void:
	var s := _start(ABYSS, 19, 11)
	if not _check("exit_loaded", await _wait_map(ABYSS)):
		return
	var map: XMapScene = _scene()
	s.set_variable(5, 1)
	s.set_variable(6, 38)
	s.set_switch(75, true)
	s.set_switch(76, true)
	# 选「否」：不动
	await _run_event(map, EXIT, [1], "")
	_check("exit_no", _scene().map_id == ABYSS and s.switch(75) and int(s.variable(6)) == 38)
	await _run_event(map, EXIT, [0], "")
	_check("exit_back", await _wait_map(145) and _scene().player.grid == Vector2i(9, 37), [_scene().name])
	_check("exit_reset", int(s.variable(6)) == 0 and not s.switch(75) and not s.switch(76), [s.variable(5), s.variable(6), s.switch(75)])


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
