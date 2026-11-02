extends Node
## 大厅 Map004、一层 Map005、黄金大厅 Map041 收齐地图事件（content1）：除大厅两个调试事件（55 全图鉴获取、69 测试游戏角色技能）外全放。
## 每个事件的默认路径已有事件对照（m4e*／m5e*／m41e*，与冻结 v0.28 一致）；这里在地图场景里查：
## - 放上地图：切片 keepEvents 列表与地图上的事件一致；55、69 不放。
## - 走得到：从落点（大厅 (14,23)、一层 (11,14)、黄金大厅 (10,18)）按图块 BFS（tests/xiyou_reach_check.gd），全部有内容的事件走得到。
## - 真跑一遍：每个新放的事件在地图里跑到结束，选项一律取消（取消不了的取第一项），开的界面当场关、战斗直接赢；没有跳过的指令。
## - 几条主路径：调速「快」、仓库「装备道具仓库」开仓库、木桩「测试伤害」打敌群 70、马老师打敌群 662（两处敌人防死，打输回地图）、
##   黄金大厅出口回 Map040 (19,6)；种族向导挪位。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const REACH := preload("res://tests/xiyou_reach_check.gd")
const TIMEOUT_MS := 240000
const WaitBudget := preload("res://tests/wait_budget.gd")
const DEBUG_EVENTS := [55, 69]
## 本期新放的事件（地图 → 事件号）
const ADDED := {
	4: [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 14, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26, 35, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 56, 57, 58, 59, 60, 61, 62, 64, 67, 68, 71],
	5: [1, 3, 5, 7, 9, 10],
	41: [1, 2],
}
const LANDING := {4: Vector2i(14, 23), 5: Vector2i(11, 14), 41: Vector2i(10, 18)}
## 原版也走不到的（图块通行与 MV checkPassage 一致）：大厅三个角上的宝箱门 9／53／58 与右下角的重置等级 64；自动执行／并行的不用走到（20）
const UNREACHABLE := {4: [9, 53, 58, 64]}
## 选项取消会回到菜单、一直转的：先选「离开」
const LEAVE := {[4, 25]: [3], [4, 71]: [5]}

var results: Array = []
var battles: Array = []   # 每场：{troop, result}
var pages: Array = []     # 打开过的界面


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
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
		map.ui.child_entered_tree.connect(_on_ui_child)
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



func _on_ui_child(n: Node) -> void:
	if n is XBattleScene:
		n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT)
	elif n.has_signal("closed"):
		pages.append(n.get_class() if n.get_script() == null else str(n.get_script().get_global_name()))
		n.closed.emit.call_deferred()


func _run_call(map: XMapScene, call: Callable, mode := "win") -> bool:
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(_on_ui_child)
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




func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_reach004"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XShop.auto_close = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261102)
	_kept()
	for m in ADDED:
		await _reach(m)
	for m in ADDED:
		for id in ADDED[m]:
			await _smoke(m, id)
	await _paths()
	MVEventCore.fixed_random = -1.0
	_finish()


## 切片里放的就是地图上有内容的全部事件（大厅去掉两个调试事件）
func _kept() -> void:
	var keep: Dictionary = XMapScene.slice().get("keepEvents", {})
	for m in ADDED:
		var want := []
		for e in XDB.map(m).get("events", []):
			if not e is Dictionary or (m == 4 and DEBUG_EVENTS.has(int(e.id))):
				continue
			var n := 0
			for p in e.pages:
				n += p.list.size()
			if n > e.pages.size():
				want.append(int(e.id))
		want.sort()
		var got: Array = keep.get(str(m), []).map(func(v): return int(v))
		got.sort()
		_check("kept_map%d" % m, got == want, [got, want])
	var lobby: Array = keep.get("4", []).map(func(v): return int(v))
	_check("debug_not_kept", not lobby.has(55) and not lobby.has(69), lobby)


## 落点走得到全部放上的事件（变量 20＝31：按层数出现的都出现）
func _reach(m: int) -> void:
	var s := _start(m, LANDING[m].x, LANDING[m].y, 2)
	s.set_variable(20, 31)
	if not _check("reach_start_map%d" % m, await _wait_map(m)):
		return
	if m == 4:
		XRace.state(s).guideChosen = true   # 选过族：种族向导 22 让开入塔门口（见 _race_guide）
		_scene().relocate_race_guide()
	var ids: Array = XMapScene.slice().keepEvents[str(m)].map(func(v): return int(v)).filter(func(id):
		var e := _event(_scene(), id)
		return e != null and not (e.data.pages as Array).filter(func(p): return (p.list as Array).size() > 1).all(func(p): return int(p.trigger) in [3, 4]))
	var miss := REACH.unreachable(_scene(), _scene().player.grid, ids)
	var want: Array = UNREACHABLE.get(m, [])
	_check("reach_map%d" % m, miss == want, [miss, want])


## 每个新放的事件跑到结束：选项一律取消，界面当场关，战斗直接赢；没有跳过的指令
func _smoke(m: int, id: int) -> void:
	var s := _start(m, LANDING[m].x, LANDING[m].y, 2)
	s.set_variable(20, 31)
	if not await _wait_map(m):
		_check("smoke_start_map%d_ev%d" % [m, id], false)
		return
	var map: XMapScene = _scene()
	map.skipped_log.clear()
	var answers: Array = LEAVE.get([m, id], []).duplicate()
	for i in 40:
		answers.append(-1)
	await _run_event(map, id, answers, "win")
	var skipped: Array = map.skipped_log if is_instance_valid(map) else []
	_check("smoke_map%d_ev%d_no_skipped" % [m, id], skipped.is_empty(), skipped.slice(0, 3))


func _paths() -> void:
	# 调速「快」：移动速度 4
	var s := _start(4, 14, 23, 2)
	if await _wait_map(4):
		await _run_event(_scene(), 44, [1], "")
		_check("speed_fast", s.player_move_speed == 4, s.player_move_speed)
		await _run_event(_scene(), 44, [2], "")
		_check("speed_faster", s.player_move_speed == 5, s.player_move_speed)
	# 仓库「装备道具仓库」：建仓库并打开仓库界面
	s = _start(4, 14, 23, 2)
	s.set_variable(20, 5)
	if await _wait_map(4):
		pages.clear()
		await _run_event(_scene(), 8, [0], "")
		_check("warehouse_opened", s.warehouses.has("仓库") and pages.has("XWarehouseScene"), [s.warehouses.keys(), pages])
	# 木桩、马老师的敌人防死（训练用，生命归零也不倒），可输可逃：直接打输
	# 木桩「测试伤害」：敌群 70
	s = _start(4, 14, 23, 2)
	if await _wait_map(4):
		battles.clear()
		await _run_event(_scene(), 25, [0, 3, 3, 3], "lose")
		_check("dummy_battle70", battles.any(func(b): return int(b.troop) == 70), battles)
	# 马老师「与马老师正常比武」：敌群 662
	s = _start(5, 11, 14, 2)
	if await _wait_map(5):
		battles.clear()
		await _run_event(_scene(), 9, [0], "lose")
		_check("ma_battle662", battles.any(func(b): return int(b.troop) == 662), battles)
	await _race_guide()
	# 黄金大厅出口：回 Map040 (19,6)
	s = _start(41, 10, 18, 2)
	if await _wait_map(41):
		await _run_event(_scene(), 2, [], "")
		_check("golden_exit", await _wait_map(40) and _scene().player.grid == Vector2i(19, 6), [_scene().map_id, _scene().player.grid])


## 种族向导 22：没选族时站在入塔门 36 前 (14,5)，门走不到；选族后（进大厅时、选单关闭后）挪到赌场 47 右边 (11,5)
func _race_guide() -> void:
	var s := _start(4, 14, 23, 2)
	if not await _wait_map(4):
		return
	var map: XMapScene = _scene()
	var g := _event(map, 22)
	_check("guide_at_door", g != null and g.grid == Vector2i(14, 5), g.grid if g != null else null)
	_check("door_blocked", REACH.unreachable(map, map.player.grid, [36]) == [36])
	XRace.state(s).guideChosen = true
	map.relocate_race_guide()
	_check("guide_moved", g.grid == Vector2i(11, 5) and g.direction == 2, [g.grid, g.direction])
	_check("door_open", REACH.unreachable(map, map.player.grid, [36]).is_empty())
	# 再进大厅：按存档摆回去也照样挪开
	s = _start(4, 14, 23, 2)
	s.set_switch(283, true)
	if await _wait_map(4):
		_check("guide_moved_on_enter", _event(_scene(), 22).grid == Vector2i(11, 5), _event(_scene(), 22).grid)


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
