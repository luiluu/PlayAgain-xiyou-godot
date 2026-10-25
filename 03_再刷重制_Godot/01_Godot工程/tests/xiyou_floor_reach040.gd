extends Node
## 地下甬道簇（盘点簇 11，悟空_55）流程（地图场景里真走一遍）：
## - Map004 EV13：变量 20「神魔之塔层数」<16 时碰到提示「暂时无法进入」；≥16 且玩家朝右 → Map040 地下甬道 (4,7)；
## - Map040：EV2 ⇄ Map042 超越大厅、EV3 ⇄ Map066 符石大厅、EV1 ⇄ Map133 地下室，EV4 黄金大厅要开关 170（自由模式，原版无处置 ON，不接）→ 提示不可进入，EV6 回 Map004 (20,6)；
## - Map066 符石师：变量 14≥1 时领被动书「符文之王 +1」（变量 31 只领一次）；Map042 修炼师、技能师、战技师与 Map133 地下守卫对话能走完（选「离开」）。
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
	XSave.dir_override = "user://test_xiyou_floor_reach040"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261024)
	await _tunnel()
	_finish()


func _tunnel() -> void:
	var s := _start(4, 24, 6, 6)
	if not _check("gate_loaded", await _wait_map(4)):
		return
	var map: XMapScene = _scene()
	_check("gate_present", _event(map, 13) != null)
	# 变量 20 不到 16：只出提示
	s.set_variable(20, 15)
	map.refresh_events()
	await _run_event(map, 13, [], "")
	_check("gate_closed", _scene().map_id == 4, [_scene().map_id])
	s.set_variable(20, 16)
	map.refresh_events()
	# 朝下：条件分支不过，留在原图
	map.player.set_direction(2)
	await _run_event(map, 13, [], "")
	_check("gate_facing_down_stays", _scene().map_id == 4, [_scene().map_id])
	map.player.set_direction(6)
	await _run_event(map, 13, [], "")
	if not _check("tunnel_entered", await _wait_map(40) and _scene().player.grid == Vector2i(4, 7), [_scene().map_id]):
		return
	map = _scene()
	_check("tunnel_events", [1, 2, 3, 4, 6].all(func(i): return _event(map, i) != null))
	# 超越大厅
	await _run_event(map, 2, [], "")
	if _check("hall_entered", await _wait_map(42) and _scene().player.grid == Vector2i(10, 23), [_scene().map_id]):
		map = _scene()
		_check("hall_events", [1, 2, 3, 7, 8].all(func(i): return _event(map, i) != null))
		await _run_event(map, 2, [1], "")
		await _run_event(map, 7, [2], "")
		await _run_event(map, 8, [2], "")
		await _run_event(map, 1, [], "")
		_check("hall_back", await _wait_map(40) and _scene().player.grid == Vector2i(11, 6), [_scene().map_id, _scene().player.grid])
	# 符石大厅
	await _run_event(_scene(), 3, [], "")
	if _check("rune_entered", await _wait_map(66) and _scene().player.grid == Vector2i(9, 12), [_scene().map_id]):
		map = _scene()
		s.set_variable(14, 1)
		var bag0 := s.item_count(1967)
		await _run_event(map, 3, [1], "")
		_check("rune_book", s.item_count(1967) == bag0 + 1 and s.variable(31) == 1, [bag0, s.item_count(1967), s.variable(31)])
		await _run_event(map, 3, [1], "")
		_check("rune_book_once", s.item_count(1967) == bag0 + 1, [s.item_count(1967)])
		s.set_variable(14, 0)
		await _run_event(map, 3, [1], "")
		_check("rune_book_locked", s.item_count(1967) == bag0 + 1)
		await _run_event(map, 1, [], "")
		_check("rune_back", await _wait_map(40) and _scene().player.grid == Vector2i(15, 6), [_scene().map_id, _scene().player.grid])
	# 地下室
	await _run_event(_scene(), 1, [], "")
	if _check("cellar_entered", await _wait_map(133) and _scene().player.grid == Vector2i(4, 4), [_scene().map_id]):
		await _run_event(_scene(), 1, [1], "")
		await _run_event(_scene(), 2, [], "")
		_check("cellar_back", await _wait_map(40) and _scene().player.grid == Vector2i(20, 7), [_scene().map_id, _scene().player.grid])
	# 黄金大厅：开关 170 关着，提示不可进入
	await _run_event(_scene(), 4, [], "")
	_check("gold_hall_closed", _scene().map_id == 40, [_scene().map_id])
	# 出口
	await _run_event(_scene(), 6, [], "")
	_check("tunnel_exit", await _wait_map(4) and _scene().player.grid == Vector2i(20, 6), [_scene().map_id, _scene().player.grid])


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
