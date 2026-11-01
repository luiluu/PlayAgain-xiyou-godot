extends Node
## 三十一层（Map148 德颜天）错误数据（EV20）：第 1 页三段对话后给物品 1421～1426（126），再开独立开关 A（第 2 页空白）。
## 物品效果是代码 43 学技能 8221～8226（<Hide in Battle>、<StartPushState1741…1749: 100%>）：使用后学到、进战斗给自己附加对应状态。
## 状态 1741～1749 的 <Custom Turn Start／Turn End／Leave／Confirm Effect> 脚本效果未做（见交付单），本测试只验到「状态已附加」。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const FLOOR_MAP := 148
const TIMEOUT_MS := 90000
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


func _battle_of(map: XMapScene) -> XBattleScene:
	for n in map.ui.get_children():
		if n is XBattleScene:
			return n
	return null


## 跑一个事件到结束（或换了地图）；kill：战斗一开始就把敌人全部击倒
func _run_event(map: XMapScene, id: int, answers: Array, kill := false) -> bool:
	var e := _event(map, id)
	if not _check("map%d_event%d_present" % [map.map_id, id], e != null and not e.page.is_empty()):
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
		if kill:
			var b := _battle_of(map)
			if b != null and not b.logic.enemies.is_empty():
				for en in b.logic.enemies:
					if en.is_alive():
						en.hp = 0.0
						en.add_state(1)
		await get_tree().process_frame
	return _check("map%d_event%d_finished" % [map.map_id, id], st.done)



const ITEMS := [1421, 1422, 1423, 1424, 1425, 1426]
const SKILLS := [8221, 8222, 8223, 8224, 8225, 8226]
const STATES := [1741, 1742, 1743, 1747, 1748, 1749]


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_error_data"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	s.set_variable(20, 32)
	s.map_id = FLOOR_MAP
	s.x = 5
	s.y = 34
	s.direction = 8
	get_tree().change_scene_to_file(MAP_SCENE)
	if not _check("floor31_loaded", await _wait_map(FLOOR_MAP)):
		_finish()
		return
	var map: XMapScene = _scene()
	var ev := _event(map, 20)
	_check("ev20_placed", ev != null and not ev.page.is_empty() and int(ev.data.x) == 5 and int(ev.data.y) == 32, ev != null)
	_check("bag_empty_before", ITEMS.all(func(i): return s.item_count(i) == 0))
	await _run_event(map, 20, [])
	_check("bag_has_six", ITEMS.all(func(i): return s.item_count(i) == 1), ITEMS.map(func(i): return s.item_count(i)))
	_check("self_switch_a", s.self_switch(FLOOR_MAP, 20, "A"))
	var ev2 := _event(map, 20)
	_check("page2_blank", ev2 != null and ev2.page.get("list", []).size() <= 1, ev2.page if ev2 != null else null)
	# 再碰不重复给
	await _run_event(map, 20, [])
	_check("no_second_gift", ITEMS.all(func(i): return s.item_count(i) == 1))
	# 使用：与 Scene_Item._use 同路径（战斗效果栏 code 43）
	var a: XActor = s.actor(8)
	_check("skills_unknown_before", SKILLS.all(func(k): return not a.skill_ids.has(k)))
	var logic := XBattleLogic.new()
	logic.state = s
	for i in ITEMS.size():
		var item: Dictionary = XDB.rec("Items", ITEMS[i])
		for e in item.get("effects", []):
			logic._effect(a, a, e, {"skill": item, "hp": 0.0, "mp": 0.0, "added": [], "removed": []})
	_check("skills_learned", SKILLS.all(func(k): return a.skill_ids.has(k)), a.skill_ids)
	for k in SKILLS:
		var meta: Dictionary = XDB.rec("Skills", k).get("meta", {})
		_check("skill%d_hidden" % k, meta.has("Hide in Battle"), meta)
	# 进战斗（队里另有默认角色 1 没学技能，只验角色 8）：开战标签给自己附加 1741～1743、1747～1749
	a.refresh_passive()
	var b := XBattleLogic.new()
	b.elite_roll = 100.0
	b.setup(2, s)
	for sid in STATES:
		_check("state%d_attached" % sid, b.actors.any(func(x): return x.actor_id == 8 and x.is_state_affected(sid)), sid)
	_finish()


func _finish() -> void:
	for i in range(1, XSave.SLOTS + 1):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
