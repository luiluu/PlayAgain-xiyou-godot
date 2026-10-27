extends Node
## 可达图收尾：空图 Map102，以及期七遗留的 Map062 正式入口（地图场景里真走一遍）。
## 黄金大厅 Map041 暂不收（星级仓库画面未做，见交付单）。
## - 69 EV47 第二页（开关 21 开）→ 空图 102 (29,22)。
## - 指路灯物品 247 → 公共事件 164 → 传送到 62 (23,19)（不经 Map127）：普通情形传送；在副本中（变量 21≠0）只提示不传送。
## 队伍生命攻击都很大（只查流程）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 240000   # 并行负载下单个事件可能跑到一两分钟，别用 90 秒的墙钟判失败

var results: Array = []
var battles: Array = []   # 每场：{troop, result}
var trainings := 0


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
		map.ui.child_entered_tree.connect(_on_ui_child)
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



func _on_ui_child(n: Node) -> void:
	if n is XBattleScene:
		n.finished.connect(func(r): battles.append({"troop": n.logic.troop_id, "result": r}), CONNECT_ONE_SHOT)
	elif n is XTrainingScene:
		trainings += 1
		n.closed.emit.call_deferred()


func _run_call(map: XMapScene, call: Callable, mode := "win") -> bool:
	if not map.has_meta("watched"):
		map.set_meta("watched", true)
		map.ui.child_entered_tree.connect(_on_ui_child)
	var st := {"done": false}
	(func():
		await call.call()
		st.done = true).call()
	var t0 := Time.get_ticks_msec()
	while not st.done and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
		var b := _battle_of(map)
		if b != null and not b.logic.enemies.is_empty() and mode == "win":
			for en in b.logic.enemies:
				if en.is_alive():
					en.hp = 0.0
					en.add_state(1)
		await get_tree().process_frame
	return _check("call_finished", st.done)




func _run() -> void:
	XSave.dir_override = "user://test_xiyou_floor_reach041"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XShop.auto_close = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261027)
	await _empty()
	await _lamp()
	MVEventCore.fixed_random = -1.0
	_finish()


## 空图 102：Map69 EV47 第二页（开关 21 开）进入
func _empty() -> void:
	var s := _start(69, 38, 78, 2)
	s.set_switch(21, true)
	if not _check("empty_start", await _wait_map(69)):
		return
	await _run_event(_scene(), 47, [], "")
	_check("empty_entered", await _wait_map(102) and _scene().player.grid == Vector2i(29, 22), [_scene().map_id, _scene().player.grid])
	var map: XMapScene = _scene()
	_check("empty_no_table", map.map_data.encounterList.is_empty())


## 指路灯 247 → 公共事件 164 → 62
func _lamp() -> void:
	var s := _start(4, 12, 18, 8)
	s.gain_item(247, 2)
	s.clear_common_event()
	if not _check("lamp_start", await _wait_map(4)):
		return
	# 物品菜单使用：预约公共事件 164（指路灯不消耗），回地图
	var page := XItemScene.new()
	add_child(page)
	await _frames(2)
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page._item = XDB.rec("Items", 247)
	page._make_actions()
	page._mode = "action"
	page._act = 0
	_check("lamp_enabled", bool(page._actions[0].enabled))
	page._ok()
	if page._mode == "actor":
		page._actor = 0
		page._ok()
	_check("lamp_use", s.peek_common_event() == 164 and s.item_count(247) == 2 and page.to_map and closed[0], [s.peek_common_event(), s.item_count(247), page.to_map, closed[0]])
	page.queue_free()
	# 在副本中（变量 21≠0）：只提示，不传送
	s.set_variable(21, 1)
	await _run_call(_scene(), func(): await _scene().run_reserved_common_event(s), "")
	_check("lamp_in_dungeon", _scene().map_id == 4 and s.peek_common_event() == 0, [_scene().map_id, s.peek_common_event()])
	# 普通情形：传送到 62 (23,19)
	s.set_variable(21, 0)
	s.reserve_common_event(164)
	await _run_call(_scene(), func(): await _scene().run_reserved_common_event(s), "")
	_check("lamp_to62", await _wait_map(62) and _scene().player.grid == Vector2i(23, 19) and s.peek_common_event() == 0, [_scene().map_id, _scene().player.grid])

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
