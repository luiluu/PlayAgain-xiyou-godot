extends Node
## 桂树小屋（盘点序 9，悟空_56）流程（地图场景里真走一遍）：
## - Map147 EV2（开关 1657「25层普通」页）：挑战副本→缺不朽灵魂(640)提示／有则扣一个，变量 450＝1、21＋1、5＋1、6＝35、94 随机 1～40、250 随机 1～10，
##   按 250 落到 Map173 十个起点之一；变量 5＝1 时提示「请重置副本」；重置副本（5＝1 且 6＝35）清变量与开关 254～263；
## - Map173 十个房间：首领 EV（敌群 528～537）打赢各开 254～263，再进同一事件的宝箱页（公共事件 1413 按 94 发奖）→ 异门选「是」按变量 251 落到 Map175 起点（变量 450 清 0）、选「否」回 Map147 并重置；
##   出口 EV31～40（接触）回 Map147 (12,7)；
## - Map175 十个房间：首领 EV（敌群 559～568）打赢各开 264～273，选「前往未知存在」→ Map177 (9,15)。
## 原版随机分支一律固定（变量 94／250／251 在需要处直接设定）；队伍生命攻击都很大（只查流程）。
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


## 跑一段异步调用到结束，模式同 _run_event
func _run_call(map: XMapScene, call: Callable, mode := "win") -> bool:
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(func(n):
			if n is XBattleScene:
				n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT))
	var st := {"done": false}
	(func():
		await call.call()
		st.done = true).call()
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while not st.done and t0.waiting():
		var b := _battle_of(map)
		if b != null and not b.logic.enemies.is_empty() and mode == "win":
			for en in b.logic.enemies:
				if en.is_alive():
					en.hp = 0.0
					en.add_state(1)
		await get_tree().process_frame
	return _check("call_finished", st.done)


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





## 起点（变量 250／251 的 1～10）和对应的首领事件、敌群（173 与 175 各一份）
const STARTS := [Vector2i(6, 8), Vector2i(28, 10), Vector2i(47, 10), Vector2i(6, 22), Vector2i(22, 25), Vector2i(49, 25), Vector2i(62, 22), Vector2i(10, 40), Vector2i(32, 40), Vector2i(52, 40)]
const BOSS173 := [4, 3, 5, 6, 7, 8, 9, 30, 11, 10]
const TROOP173 := [528, 529, 530, 531, 532, 533, 534, 535, 536, 537]
const BOSS175 := [4, 3, 5, 6, 7, 8, 9, 30, 11, 10]
const TROOP175 := [559, 560, 561, 562, 563, 564, 565, 566, 567, 568]


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_reach173"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261025)
	await _entry()
	await _rooms()
	await _exit_and_decline()
	_finish()


## Map147 EV2：缺魂提示、扣魂入副本、请重置、重置副本
func _entry() -> void:
	var s := _start(147, 12, 7, 8)
	if not _check("hub_loaded", await _wait_map(147)):
		return
	s.set_switch(1657, true)
	_scene().refresh_events()
	_check("hub_door_present", _event(_scene(), 2) != null)
	await _run_event(_scene(), 2, [0], "")
	_check("no_soul_stays", _scene().map_id == 147 and int(s.variable(5)) == 0 and int(s.variable(450)) == 1, [_scene().map_id, s.variable(5), s.variable(450)])
	s.gain_item(640, 2)
	await _run_event(_scene(), 2, [0], "")
	var v250 := int(s.variable(250))
	if not _check("entered_173", await _wait_map(173) and v250 >= 1 and v250 <= 10 and _scene().player.grid == STARTS[v250 - 1], [_scene().map_id, v250]):
		return
	_check("entry_vars", s.item_count(640) == 1 and int(s.variable(21)) == 1 and int(s.variable(5)) == 1 and int(s.variable(6)) == 35 and int(s.variable(450)) == 1 and int(s.variable(94)) >= 1 and int(s.variable(94)) <= 40, [s.item_count(640), s.variable(21), s.variable(5), s.variable(6), s.variable(94)])
	# 已在副本里（变量 5＝1）再挑战：请重置副本，不扣魂
	s = _start(147, 12, 7, 8)
	if not _check("hub_loaded2", await _wait_map(147)):
		return
	s.set_switch(1657, true)
	s.set_variable(5, 1)
	s.set_variable(6, 35)
	s.set_variable(21, 1)
	s.gain_item(640, 1)
	s.set_switch(255, true)
	_scene().refresh_events()
	await _run_event(_scene(), 2, [0], "")
	_check("must_reset_first", _scene().map_id == 147 and s.item_count(640) == 1, [_scene().map_id, s.item_count(640)])
	await _run_event(_scene(), 2, [1], "")
	_check("reset_done", int(s.variable(5)) == 0 and int(s.variable(6)) == 0 and int(s.variable(21)) == 0 and not s.switch(255) and int(s.variable(450)) == 0, [s.variable(5), s.variable(6), s.variable(21), s.switch(255), s.variable(450)])
	await _run_event(_scene(), 2, [1], "")
	_check("reset_idle", int(s.variable(5)) == 0)


## 十个房间：首领→宝箱页→异门→Map175 同号房间首领→未知存在门
func _rooms() -> void:
	for k in range(1, 11):
		var s := _start(173, STARTS[k - 1].x, STARTS[k - 1].y, 8)
		if not _check("r%d_loaded" % k, await _wait_map(173)):
			return
		s.set_switch(1657, true)
		s.set_variable(450, 1)
		s.set_variable(5, 1)
		s.set_variable(6, 35)
		s.set_variable(21, 1)
		s.set_variable(94, 1 + (k % 5))
		_scene().refresh_events()
		var map: XMapScene = _scene()
		_check("r%d_events" % k, _event(map, BOSS173[k - 1]) != null and _event(map, 30 + k) != null)
		var n0 := battles.size()
		await _run_event(map, BOSS173[k - 1], [], "win")
		_check("r%d_boss173" % k, battles.size() == n0 + 1 and battles[-1].troop == TROOP173[k - 1] and battles[-1].result == 0 and s.switch(253 + k), [battles.slice(n0), s.switch(253 + k)])
		map = _scene()
		map.refresh_events()
		s.set_variable(251, 1)   # 仅占位；异门处会重新掷 1～10
		var gold0: int = s.gold
		await _run_event(map, BOSS173[k - 1], [0], "")
		var v251 := int(s.variable(251))
		if not _check("r%d_door_to_175" % k, await _wait_map(175) and v251 >= 1 and v251 <= 10 and _scene().player.grid == STARTS[v251 - 1] and int(s.variable(450)) == 0, [_scene().map_id, v251, s.variable(450)]):
			return
		map = _scene()
		var b := v251 - 1
		_check("r%d_events175" % k, _event(map, BOSS175[b]) != null)
		n0 = battles.size()
		await _run_event(map, BOSS175[b], [0], "win")
		_check("r%d_boss175" % k, battles.size() == n0 + 1 and battles[-1].troop == TROOP175[b] and battles[-1].result == 0 and s.switch(264 + b), [battles.slice(n0), TROOP175[b], s.switch(264 + b)])
		_check("r%d_unknown_door" % k, await _wait_map(177) and _scene().player.grid == Vector2i(9, 15), [_scene().map_id])


## 出口（接触）回 Map147；异门选「否」回 Map147 并重置
func _exit_and_decline() -> void:
	var s := _start(173, STARTS[0].x, STARTS[0].y, 8)
	if not _check("exit_loaded", await _wait_map(173)):
		return
	s.set_variable(5, 1)
	s.set_variable(21, 1)
	await _run_event(_scene(), 31, [], "")
	_check("exit31_back", await _wait_map(147) and _scene().player.grid == Vector2i(12, 7), [_scene().map_id])
	s = _start(173, STARTS[1].x, STARTS[1].y, 8)
	if not _check("decline_loaded", await _wait_map(173)):
		return
	s.set_switch(1657, true)
	s.set_variable(450, 1)
	s.set_variable(5, 1)
	s.set_variable(6, 35)
	s.set_variable(21, 1)
	s.set_variable(94, 5)
	_scene().refresh_events()
	var map: XMapScene = _scene()
	await _run_event(map, BOSS173[1], [], "win")
	map = _scene()
	map.refresh_events()
	await _run_event(map, BOSS173[1], [1], "")
	_check("decline_back_hub", await _wait_map(147) and _scene().player.grid == Vector2i(12, 7) and int(s.variable(5)) == 0 and not s.switch(255) and int(s.variable(450)) == 0, [_scene().map_id, s.variable(5), s.switch(255), s.variable(450)])


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
