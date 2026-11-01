extends Node
## 三十一层（Map148 德颜天）的可选首领与副本协会主席：事件在大厅门之外没有页条件，站在三十一层直接按事件。
## 每位首领：选「我已经做好准备」（选项 0）→ 公共事件 1387 换战斗背景 → 战斗 → 战后变量记 1（时之恶魔 1111、暗夜哥布林 1107、奇异兽 1108……）。
## 战斗只查流程：开战后直接击倒敌人（数值与敌群事件由 xiyou_troop_events 对照）。「离开」（选项 1）不开战。
## 龙之祖（8）战后全员学 5565；瑞丁（6，要先过龙之祖）战后变量 206 加 20000、人道意志碎片 2530 +100、变量 1115 记 1。
## 副本协会主席（9）是没有分支的战斗事件（敌群 661）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const FLOOR_MAP := 148
## 事件号 → [敌群, 战后置 1 的变量（0＝无）]
## 龙之祖（8）要先于瑞丁（6，页条件：变量 1109≥1）；神·金之巨人（1）1112、怨之脑·魇之眼（4）1113。
const BOSSES := {2: [125, 1111], 3: [816, 1107], 13: [817, 1108], 9: [661, 0], 8: [126, 1109], 6: [818, 1115], 1: [830, 1112], 4: [831, 1113]}
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


func _run() -> void:
	GameApp.fast_forward()  # 真走地图打战斗、等的是物理帧与计时器：headless 快进 4 倍（见 07_开发环境/测试提速.md）
	XSave.dir_override = "user://test_xiyou_floor31_bosses"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261021)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = XRandomStream.hex64(20261021)
	XState.current = s
	s.set_variable(20, 31)
	s.actor_max_level = 75
	s.map_id = FLOOR_MAP
	s.x = 24
	s.y = 46
	s.direction = 8
	get_tree().change_scene_to_file(MAP_SCENE)
	if not _check("floor31_loaded", await _wait_map(FLOOR_MAP)):
		_finish()
		return
	var map: XMapScene = _scene()
	var v206 := s.variable(206)
	# 瑞丁要先过龙之祖：未过时只说话、不开战
	var before_ruiding := battles.size()
	await _run_event(map, 6, [0])
	_check("ev6_locked_before_dragon", battles.size() == before_ruiding, battles.size() - before_ruiding)
	for ev in BOSSES:
		var troop: int = BOSSES[ev][0]
		var flag_var: int = BOSSES[ev][1]
		# 「离开」：不开战、变量不变
		if flag_var > 0:
			var before := battles.size()
			await _run_event(map, ev, [1])
			_check("ev%d_leave_no_battle" % ev, battles.size() == before and s.variable(flag_var) == 0, [battles.size() - before, s.variable(flag_var)])
		var b0 := battles.size()
		await _run_event(map, ev, [0], true)
		_check("ev%d_battle_won" % ev, battles.size() == b0 + 1 and battles[-1].troop == troop and battles[-1].result == 0, battles.slice(b0))
		if flag_var > 0:
			_check("ev%d_flag" % ev, s.variable(flag_var) == 1, s.variable(flag_var))
		if ev == 8:
			_check("ev8_dragon_skill", s.members().all(func(a): return a.skill_ids.has(5565)), s.members().map(func(a): return a.skill_ids.has(5565)))
		if ev == 6:
			_check("ev6_rewards", s.variable(206) == v206 + 20000 and s.item_count(2530) == 100, [s.variable(206) - v206, s.item_count(2530)])
		map = _scene()
		_check("ev%d_back_on_floor" % ev, map is XMapScene and map.map_id == FLOOR_MAP, map.map_id if map is XMapScene else null)
	_check("battleback_changed", map.battleback_override == ["DemonicWorld", "DemonCastle2"], map.battleback_override)
	_finish()


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
