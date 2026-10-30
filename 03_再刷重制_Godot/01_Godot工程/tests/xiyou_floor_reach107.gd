extends Node
## 75 簇期三：深渊:魔王之渊（Map107）流程（地图场景里真走一遍）：
## - 入口：厄运王座宝箱（Map080 EV13）出深渊之门、选「进入此门」且变量 107＝1 → Map107 (19,24)（变量 5／6／21 不变，6＝17）；
##   107≠1 的那支由 O-120 改走「离开」分支（见 xiyou_seal_doors）。
## - 地图：从落点按图块 BFS，封印 EV5、商人 EV6、出口 EV8 走得到（xiyou_reach_check）；
## - 封印 EV5：第 1 页「解开封印」→ 开关 75；第 2 页「继续解开封印」→ 变量 108 取 1～4 对应敌群 344～347，胜后成就 81、
##   变量 217 抽 3000 取 1 的稀有支（成就 139、更衣 −37；不在这里核）、开关 76；「离开」什么也不变。
## - 商人 EV6：开关 76 后自动页按变量 110 开商店（开关 77、变量 109＝1～34）或不开（开关 78）；商人页按变量 109 开店。
## - 出口 EV8：「是」且变量 6＝17 传回 Map078 (21,26)，变量 5／6／21／175 复位、开关 127～131 关，再关 75～78；「否」不动。
## 队伍生命攻击都很大（只查流程）；战斗中直接击倒敌人。事件走地图场景的 run_event。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const ABYSS := 107
const REACH := preload("res://tests/xiyou_reach_check.gd")
const SEAL := 5
const EXIT := 8
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
	XSave.dir_override = "user://test_xiyou_floor_reach107"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XShop.auto_close = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261022)
	await _seal()
	await _shop()
	await _exit()
	_finish()


func _seal() -> void:
	var s := _start(ABYSS, 19, 18)
	if not _check("abyss_loaded", await _wait_map(ABYSS)):
		return
	var map: XMapScene = _scene()
	_check("abyss_events", [1, 2, 3, 4, 5, 6, EXIT].all(func(i): return _event(map, i) != null))
	_check("abyss_reach", REACH.unreachable(map, map.player.grid, [5, 6, EXIT]).is_empty(), REACH.unreachable(map, map.player.grid, [5, 6, EXIT]))
	await _run_event(map, SEAL, [1], "")
	_check("seal_leave", not s.switch(75) and battles.is_empty(), battles)
	await _run_event(map, SEAL, [0], "")
	_check("seal_opened", s.switch(75) and not s.switch(76), [s.switch(75), s.switch(76)])
	await _run_event(map, SEAL, [1], "")
	_check("seal2_leave", battles.is_empty() and not s.switch(76), battles)
	# 四种被封印者各打一场（变量 108 取 1～4 对应敌群 344～347）：用固定随机数逐个取
	for k in range(1, 5):
		s.set_switch(75, true)
		s.set_switch(76, false)
		map.refresh_events()
		battles.clear()
		MVInterpreter.fixed_random = (k - 0.5) / 4.0
		await _run_event(map, SEAL, [0], "win")
		map = _scene()
		_check("seal2_battle_%d" % k, battles.size() == 1 and int(s.variable(108)) == k and battles[0].troop == 343 + k and battles[0].result == 0, [battles, s.variable(108)])
		_check("seal2_reward_%d" % k, s.switch(76), s.switch(76))
	MVInterpreter.fixed_random = -1.0
	_check("seal2_stay", _scene() is XMapScene and _scene().map_id == ABYSS, _scene().name)


## 商人：开关 76 的自动页按变量 110 开商店；商人页按变量 109 开店（XShop.auto_close 时直接关）
func _shop() -> void:
	var s := _start(ABYSS, 19, 18)
	if not _check("shop_loaded", await _wait_map(ABYSS)):
		return
	var map: XMapScene = _scene()
	s.set_switch(76, true)
	s.set_switch(77, true)
	map.refresh_events()
	var shops := {}
	for k in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		s.set_variable(109, k)
		XMessageBox.transcript.clear()
		await _run_event(map, 6, [0, 1], "")
		shops[k] = XMessageBox.transcript.any(func(t): return str(t).contains("深渊商人"))
	_check("shop_talks", shops.values().all(func(v): return v), shops)


func _exit() -> void:
	var s := _start(ABYSS, 19, 11)
	if not _check("exit_loaded", await _wait_map(ABYSS)):
		return
	var map: XMapScene = _scene()
	s.set_variable(5, 1)
	s.set_variable(6, 17)
	s.set_variable(21, 1)
	s.set_variable(175, 5)
	for sw in [75, 76, 127, 128, 129, 130, 131]:
		s.set_switch(sw, true)
	await _run_event(map, EXIT, [1], "")
	_check("exit_no", _scene().map_id == ABYSS and s.switch(75) and int(s.variable(6)) == 17)
	await _run_event(map, EXIT, [0], "")
	_check("exit_back", await _wait_map(78) and _scene().player.grid == Vector2i(21, 26), [_scene().name])
	_check("exit_reset", int(s.variable(5)) == 0 and int(s.variable(6)) == 0 and int(s.variable(21)) == 0 and int(s.variable(175)) == 0 \
		and not [75, 76, 127, 128, 129, 130, 131].any(func(sw): return s.switch(sw)), [s.variable(5), s.variable(6), s.variable(21), s.variable(175)])


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
