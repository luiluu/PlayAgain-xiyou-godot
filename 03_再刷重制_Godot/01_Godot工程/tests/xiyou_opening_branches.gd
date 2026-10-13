extends Node
## 开局 Map221 引路人的两条分支（无人操作，原版事件实跑）：
## A「攻击他？」：打真·天道投影（敌群 771，打不过、可战败）→ 英雄与伙伴全部离队、里德入队、随机伙伴魂灯、强者/弱者压制 → 方桌大厅。
## B「轮回归来！·普通」：打投影（敌群 815，5 点血）→ 开关 2307、强者/弱者压制 → 方桌大厅，队伍不变。
## 存档写到 user://test_xiyou_branches，测试结束删除。

var results: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _scene() -> Node:
	return get_tree().current_scene


func _wait(cond: Callable, timeout := 6000) -> bool:
	for i in range(timeout):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _map_idle(map_id: int) -> bool:
	var s = _scene()
	return s is XMapScene and s.map_id == map_id and s.player != null and not s.busy


## 新游戏走到 Map221（存档位 1、普通难度、狗逍遥），返回地图场景
func _to_map221() -> XMapScene:
	XMessageBox.auto_answers = [0, 0, 0, "测试", 0, 2, 0, 0]
	XState.new_game_blank()
	get_tree().change_scene_to_file("res://modes/xiyou/map/map_scene.tscn")
	await _wait(func(): return _map_idle(221))
	return _scene()


func _event(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


func _run() -> void:
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XSave.dir_override = "user://test_xiyou_branches"
	Engine.time_scale = 6.0
	seed(20261013)
	# A：攻击他？
	var map := await _to_map221()
	var s := XState.current
	_check("a_reached_221", map != null and map.map_id == 221 and s.party == [1, 8, 10, 9], s.party)
	XMessageBox.auto_answers = [0]
	await map.run_event(_event(map, 3))
	var ok := await _wait(func(): return _map_idle(4) and s.self_switch(4, 20, "A"))
	_check("a_hub", ok)
	_check("a_party_reid", s.party == [11], s.party)
	_check("a_switches", s.switch(2303) and s.switch(2465))
	_check("a_items", s.item_count(10) == 0 and s.item_count(4) == 1 and s.item_count(2896) == 1, [s.item_count(10), s.item_count(4), s.item_count(2896)])
	var lamps := s.items.keys().filter(func(id): return int(id) >= 2701 and int(id) <= 2819)
	_check("a_partner_lamps", lamps.size() >= 3, lamps)
	# 强者/弱者压制：名单内（如 1、11）学 6216，名单外有名字的（如 2）学 6235
	_check("a_suppression", s.actor(11).skill_ids.has(6216) and not s.actor(11).skill_ids.has(6235) and s.actor(2).skill_ids.has(6235), [s.actor(11).skill_ids, s.actor(2).skill_ids])
	print("A skipped: ", JSON.stringify(_scene().skipped_log.map(func(r): return "%d %s" % [r.code, r.text])).left(800))
	# B：轮回归来！→ 开启轮回·普通
	map = await _to_map221()
	s = XState.current
	XMessageBox.auto_answers = [1, 0]
	await map.run_event(_event(map, 3))
	ok = await _wait(func(): return _map_idle(4) and s.self_switch(4, 20, "A"))
	_check("b_hub", ok)
	_check("b_party_kept", s.party == [1, 8, 10, 9], s.party)
	_check("b_switches", s.switch(2307) and not s.switch(2282) and not s.switch(2303))
	_check("b_items", s.item_count(4) == 1 and s.item_count(2896) == 1 and s.item_count(10) == 1)
	_check("b_suppression", s.actor(1).skill_ids.has(6216) and s.actor(8).skill_ids.has(6216))
	print("B skipped: ", JSON.stringify(_scene().skipped_log.map(func(r): return "%d %s" % [r.code, r.text])).left(800))
	DirAccess.remove_absolute(XSave.path(1))
	DirAccess.remove_absolute(XSave.dir())
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
