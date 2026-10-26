extends Node
## 盘点里「入口事件在已接地图、原版可达」的三簇（悟空_53，用户破例范围）流程（地图场景里真走一遍）：
## - Map004 EV27（接触，页条件：玩家朝下）→ Map132 兑换大厅 (8,3)；Map132 EV7 → Map204 8号当铺 (2,8)，Map204 EV2 → Map132 (14,8)，Map132 EV2（页条件：朝上）→ Map004 (14,29)；
## - 物品 1269「指路灯:剑气长城」→ 公共事件 514：乘坐载具时提示、副本中（变量 21≠0）提示，否则传 Map139 剑气长城 (13,30)；
##   Map139 EV1 崔城（开关 1694）接受传承置开关 1700 与独立开关 A，再进商店页；军需官 EV10 离开；
## - Map064 EV5 → Map192 信徒藏身 (6,27)，EV1 回 Map064 (38,27)；变量 20≥16 且变量 14＝1 时 EV4 超级嘤雄（敌群 768）与 EV5 狗逍遥·心魔。
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
	XSave.dir_override = "user://test_xiyou_floor_reach139"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261024)
	await _hall()
	await _sword()
	await _hideout()
	await _finish()


## 兑换大厅簇：EV27 只在玩家朝下时传送
func _hall() -> void:
	var s := _start(4, 14, 29, 8)
	if not _check("hall_door_loaded", await _wait_map(4)):
		return
	var map: XMapScene = _scene()
	_check("hall_door_present", _event(map, 27) != null)
	await _run_event(map, 27, [], "")
	_check("hall_door_facing_up_stays", _scene().map_id == 4, [_scene().map_id])
	s = _start(4, 14, 29, 2)
	if not _check("hall_door2_loaded", await _wait_map(4)):
		return
	await _run_event(_scene(), 27, [], "")
	_check("hall_entered", await _wait_map(132) and _scene().player.grid == Vector2i(8, 3), [_scene().map_id])
	map = _scene()
	_check("hall_events", [2, 3, 7, 12, 13].all(func(i): return _event(map, i) != null))
	await _run_event(map, 7, [], "")
	_check("pawn_entered", await _wait_map(204) and _scene().player.grid == Vector2i(2, 8), [_scene().map_id])
	await _run_event(_scene(), 2, [], "")
	_check("pawn_back", await _wait_map(132) and _scene().player.grid == Vector2i(14, 8), [_scene().map_id])
	# 方桌大厅的门（EV2）也只在朝上时传送：朝下不动，朝上才回 Map004
	await _run_event(_scene(), 2, [], "")
	_check("hall_exit_facing_down_stays", _scene().map_id == 132)
	_scene().player.set_direction(8)
	await _run_event(_scene(), 2, [], "")
	_check("hall_exit", await _wait_map(4) and _scene().player.grid == Vector2i(14, 29), [_scene().map_id])


## 剑气长城：物品 1269 预约的公共事件 514
func _use_sword(s: XState, map: XMapScene) -> void:
	s.reserve_common_event(514)
	map.run_reserved_common_event(s)
	var t0 := Time.get_ticks_msec()
	while map.busy and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		await get_tree().process_frame
	await _frames(2)


func _sword() -> void:
	var s := _start(31, 8, 6)
	if not _check("sword_start_loaded", await _wait_map(31)):
		return
	# 副本中（变量 21≠0）不可用：留在原地
	s.set_variable(21, 1)
	await _use_sword(s, _scene())
	_check("sword_blocked_in_dungeon", _scene().map_id == 31, [_scene().map_id])
	s.set_variable(21, 0)
	await _use_sword(s, _scene())
	if not _check("sword_entered", await _wait_map(139) and _scene().player.grid == Vector2i(13, 30), [_scene().map_id]):
		return
	var map: XMapScene = _scene()
	_check("wall_events", [1, 2, 3, 4, 5, 7, 10, 12].all(func(i): return _event(map, i) != null))
	# 崔城：开关 1694 的页接受传承，置开关 1700 与独立开关 A，再进商店页选「离开」
	s.set_switch(1694, true)
	map.refresh_events()
	await _run_event(map, 1, [0], "")
	_check("wall_inherit", s.switch(1700) and s.self_switch(139, 1, "A"), [s.switch(1700), s.self_switch(139, 1, "A")])
	await _run_event(map, 10, [1], "")
	_check("wall_quartermaster_leave", _scene().map_id == 139)


## 信徒藏身：Map064 EV5 进、EV1 出
func _hideout() -> void:
	var s := _start(64, 39, 27, 8)
	if not _check("hide_door_loaded", await _wait_map(64)):
		return
	await _run_event(_scene(), 5, [], "")
	if not _check("hide_entered", await _wait_map(192) and _scene().player.grid == Vector2i(6, 27), [_scene().map_id]):
		return
	var map: XMapScene = _scene()
	_check("hide_events", [1, 2, 3, 4, 5, 6].all(func(i): return _event(map, i) != null))
	s.set_variable(20, 16)
	s.set_variable(14, 1)
	map.refresh_events()
	var n0 := battles.size()
	await _run_event(map, 4, [0], "win")
	map = _scene()
	_check("hide_yingxiong_fight", battles.size() == n0 + 1 and battles[-1].troop == 768 and battles[-1].result == 0 and s.self_switch(192, 4, "A"), [battles.slice(n0), s.self_switch(192, 4, "A")])
	await _run_event(map, 5, [], "")
	_check("hide_heart_demon", s.self_switch(192, 5, "A") and int(s.variable(851)) == 1, [s.self_switch(192, 5, "A"), s.variable(851)])
	await _run_event(_scene(), 1, [], "")
	_check("hide_exit", await _wait_map(64) and _scene().player.grid == Vector2i(38, 27), [_scene().map_id])


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
