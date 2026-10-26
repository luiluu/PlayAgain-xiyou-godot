extends Node
## 三十层（Map146 住峰天）轮回分支与 Map055 终末之间：页条件要求轮回开关 2303／2307 且变量 20≥31（普通流程开关 2302 不出现，
## 由 xiyou_floor_run 核对三十层这些事件没有可用的页）。本测试开轮回模式（开关 2307）、变量 20＝31，直接站在三十层：
## - 辛德瑞（4）「老版本解锁等级上限」→ 等级上限 80；辛德瑞（5）只说话。
## - 通往 Map055 的门（3）：六位守护者（变量 1101～1106）没全打过时只提示「你还没有资格进入此处。」；全为 1 后显示动画 117、传到 Map055 (10,17)。
## - 引路人（Map055 1，敌群 794）：开关 685 关时难度 2 开战，胜后难度设 1、开关 2306「最终boss」开；第 2 页给 1982「强者的证明」、传回大厅 (14,15)。
## - 开关 2306 开后三十层的门只剩空页（第 3 页），调查不做任何事。
## - 小明事件（6）要角色 99 在队（公共事件 1557 召唤，尚未进切片），本测试只核对队里没有 99 时它没有可用的页。
## 战斗只查流程：引路人吸收全部九种属性，开战后直接击倒（数值与敌群事件由 xiyou_troop_events 的 794 参照对照）。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const FLOOR_MAP := 146
const FINAL_MAP := 55
const HUB := 4
const NO_RIGHT := "你还没有资格进入此处。"
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
	var t0 := Time.get_ticks_msec()
	while not st.done and Time.get_ticks_msec() - t0 < TIMEOUT_MS:
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
	XSave.dir_override = "user://test_xiyou_floor30_seeker"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	seed(20261019)
	var s := XState.new_game(3, 1, [8, 9, 10])
	# dev.099 起战斗用本场规则流（主种子只在运行时生成），全局 seed() 管不到；固定主种子才能复现
	s.random_master = XRandomStream.hex64(20261019)
	XState.current = s
	s.set_switch(2307, true)   # 轮回模式
	s.set_variable(20, 31)
	s.actor_max_level = 75
	s.map_id = FLOOR_MAP
	s.x = 22
	s.y = 14
	s.direction = 8
	get_tree().change_scene_to_file(MAP_SCENE)
	if not _check("floor30_loaded", await _wait_map(FLOOR_MAP)):
		_finish()
		return
	var map: XMapScene = _scene()
	# 小明事件（6）：队里没有角色 99，没有可用的页
	var ev6 := _event(map, 6)
	_check("xiaoming_hidden_without_actor99", ev6 == null or ev6.page.is_empty(), ev6.page if ev6 != null else null)
	# 辛德瑞（4）「老版本解锁等级上限」（选项下标 4）
	XMessageBox.transcript.clear()
	await _run_event(map, 4, [4])
	_check("old_cap_80", s.max_level() == 80, s.max_level())
	_check("old_cap_toast", map.toasts.has("等级上限开放至:80"), map.toasts.slice(-3))
	# 辛德瑞（5）「第五句」
	XMessageBox.transcript.clear()
	await _run_event(map, 5, [0])
	_check("sindri5_line", XMessageBox.transcript.any(func(t): return str(t).contains("战斗是多么无趣")), XMessageBox.transcript)
	# 门（3）：守护者没打全
	for v in range(1101, 1106):
		s.set_variable(v, 1)
	XMessageBox.transcript.clear()
	await _run_event(map, 3, [])
	_check("door_refused", _scene() == map and map.map_id == FLOOR_MAP and XMessageBox.transcript.has(NO_RIGHT), XMessageBox.transcript)
	# 六位守护者都打过：传到 Map055 (10,17)
	s.set_variable(1106, 1)
	await _run_event(map, 3, [])
	if not _check("final_map_entered", await _wait_map(FINAL_MAP) and _scene().player.grid == Vector2i(10, 17), [_scene().map_id, _scene().player.grid if _scene() is XMapScene else null]):
		_finish()
		return
	map = _scene()
	# 引路人（敌群 794）
	var before := battles.size()
	await _run_event(map, 1, [], true)
	_check("guide_battle_won", battles.size() == before + 1 and battles[-1].troop == 794 and battles[-1].result == 0, battles.slice(before))
	_check("final_boss_switch", s.switch(2306))
	# 公共事件 1387「战斗背景更改——终极」的 283：本图之后的战斗用 DemonicWorld／DemonCastle2
	_check("battleback_changed", map.battleback_override == ["DemonicWorld", "DemonCastle2"], map.battleback_override)
	_check("difficulty_after_guide", s.difficulty == 1, s.difficulty)
	# 第 2 页（开关 2306）：强者的证明，传回大厅 (14,15)
	map = _scene()
	await _run_event(map, 1, [])
	_check("hub_after_final", await _wait_map(HUB) and _scene().player.grid == Vector2i(14, 15), [_scene().map_id, _scene().player.grid if _scene() is XMapScene else null])
	_check("proof_item", s.item_count(1982) == 1, s.item_count(1982))
	# 回三十层：门只剩空页
	s.map_id = FLOOR_MAP
	s.x = 31
	s.y = 6
	get_tree().change_scene_to_file(MAP_SCENE)
	if _check("floor30_reloaded", await _wait_map(FLOOR_MAP)):
		var door := _event(_scene(), 3)
		_check("door_blank_after_final", door != null and door.command_list().all(func(c): return int(c.code) == 0), door.command_list() if door != null else null)
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
