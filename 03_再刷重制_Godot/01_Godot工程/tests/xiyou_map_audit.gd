extends Node
## 全量地图盘点的补漏（悟空 floor5，清单见 04_验证/地图盘点.md）：
## - 一护剧情副本 Map234～239 切片收了图却没写 keepEvents，图上一个事件都不生成：现在整图放，断言生成的事件数与原版一致。
## - O-240（MVEvent.page_switch_ignore）：Map069 EV47 毒蛇沼泽入口在开关 21 开着时，原版选第 2 页传到 Map102 (29,22)
##   （图只有 29×18，人落在图外）。开关 21 只在洞窟碰到捕猎者时打开、逃离／打完／重置都会关，原版要读异常存档才碰得到；全灭回标题、读档恢复（O-待定·全灭回大厅，Kyo 11-08 定），只有回退开关 GAME_OVER_TO_LOBBY = true 时才碰得到；修后照第 1 页进 Map087 (13,28)。回退支 page_switch_ignore = {} 时断言选回第 2 页。
## - O-241（MVTilemap.open_autotile_fix，floor6）：Map236 落点 (8,14) 四周是不可通行的深水自动图块，人动不了；
##   修后从落点走得到殿顶 Boss EV1 (8,4)。回退支 open_autotile_fix = {} 时断言只剩落点一格。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const CASE_MS := 30000
const WaitBudget := preload("res://tests/wait_budget.gd")
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const REACH := preload("res://tests/xiyou_reach_check.gd")

var results: Array = []
var fails: Array = []


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
		fails.append(name)
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _scene() -> Node:
	return get_tree().current_scene


func _map_ready(map_id: int) -> bool:
	var s = _scene()
	return s is XMapScene and s.map_id == map_id and s.player != null


func _open(m: int, x: int, y: int, dir := 2) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = m
	s.x = x
	s.y = y
	s.direction = dir
	return s


func _load(m: int) -> bool:
	get_tree().change_scene_to_file(MAP_SCENE)
	var t0 := WaitBudget.new(CASE_MS)
	while t0.waiting() and not (_map_ready(m) and not _scene().busy):
		await get_tree().process_frame
	return _map_ready(m)


func _event(id: int) -> MVEvent:
	for e in _scene().events:
		if e.event_id == id:
			return e
	return null


func _ichigo_maps() -> void:
	for m in range(234, 240):
		_open(m, 8, 14)
		if not _check("m%d_loaded" % m, await _load(m)):
			continue
		var want: int = XDB.map(m).get("events", []).filter(func(e): return e != null).size()
		_check("m%d_events" % m, want > 0 and _scene().events.size() == want, {"want": want, "got": _scene().events.size()})


func _sky_gate(fixed: bool) -> void:
	var tag := "sky47_" + ("fixed" if fixed else "orig")
	if not fixed:
		MVEvent.page_switch_ignore = {}
	var s := _open(69, 38, 78, 8)
	s.set_switch(21, true)
	if _check(tag + "_loaded", await _load(69)):
		var e := _event(47)
		if _check(tag + "_spawned", e != null):
			e.refresh()
			_check(tag + "_page", e.page_index == (0 if fixed else 1), e.page_index)
			if fixed:
				var st := {"done": false}
				var map: XMapScene = _scene()
				(func():
					await map.run_event(e)
					st.done = true).call()
				var t0 := WaitBudget.new(CASE_MS)
				while t0.waiting() and not _map_ready(87):
					await get_tree().process_frame
				_check(tag + "_landed", _map_ready(87) and _scene().player.grid == Vector2i(13, 28),
					[_scene().get("map_id"), _scene().player.grid if _scene() is XMapScene else null])
				var t1 := WaitBudget.new(5000)
				while t1.waiting() and not st.done:
					await get_tree().process_frame
	MVEvent.page_switch_ignore = _saved_ignore


var _saved_ignore: Dictionary
var _saved_autotile: Dictionary


func _qilin(fixed: bool) -> void:
	var tag := "qilin_" + ("fixed" if fixed else "orig")
	if not fixed:
		MVTilemap.open_autotile_fix = {}
	_open(236, 8, 14)
	if _check(tag + "_loaded", await _load(236)):
		var cells := REACH.reachable(_scene(), Vector2i(8, 14))
		if fixed:
			_check(tag + "_boss_reachable", cells.has(Vector2i(8, 4)), cells.size())
		else:
			_check(tag + "_stuck", cells.size() == 1, cells.size())
	MVTilemap.open_autotile_fix = _saved_autotile


func _run() -> void:
	GameApp.fast_forward()
	TestEnv.isolate("xiyou_map_audit")
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	_saved_ignore = MVEvent.page_switch_ignore
	_saved_autotile = MVTilemap.open_autotile_fix
	await _ichigo_maps()
	await _sky_gate(true)
	await _sky_gate(false)
	await _qilin(true)
	await _qilin(false)
	print("失败：", JSON.stringify(fails))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
