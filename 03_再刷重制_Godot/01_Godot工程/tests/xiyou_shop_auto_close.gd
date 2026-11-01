extends Node
## 商店的测试用自动关闭钩子（XShop.auto_close）：XMessageBox.auto／auto_answers 不管商店，楼层专项走到「购买物品」会一直等输入到超时。
## - 默认关着（正式游戏不受影响）；打开后商店一打开就把本次的商品、只购买、库存组记进 XShop.auto_log 并关闭，事件接着往下走。
## - 实例：恰兰吉尔战争利器武器店 Map072 EV2（选「购买物品」→ 商店 1240～1251 号武器各 200000 → 公共事件 249），选「离开」不开店。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 120000
const WaitBudget := preload("res://tests/wait_budget.gd")  # 墙钟与帧数都过了才算超时（tools30）

var results: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	# 换场景时测试节点不能挂在当前场景下，挂到根节点
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


func _run_event(map: XMapScene, id: int, answers: Array) -> bool:
	var e := _event(map, id)
	if not _check("event%d_present" % id, e != null):
		return false
	XMessageBox.auto_answers = answers.duplicate()
	var st := {"done": false}
	(func():
		await map.run_event(e)
		st.done = true).call()
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while not st.done and t0.waiting():
		await get_tree().process_frame
	return st.done


func _shops(map: XMapScene) -> int:
	return map.ui.get_children().filter(func(c): return c is XShop and not c.is_queued_for_deletion()).size()


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_shop_auto_close"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	_check("default_off", XShop.auto_close == false)
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.map_id = 72
	s.x = 8
	s.y = 12
	s.direction = 8
	get_tree().change_scene_to_file(MAP_SCENE)
	if not _check("map72", await _wait_map(72)):
		_finish()
		return
	var map: XMapScene = _scene()
	XShop.auto_close = true
	XShop.auto_log.clear()
	# 选「离开」：不开店
	_check("leave_finished", await _run_event(map, 2, [1]))
	_check("leave_no_shop", XShop.auto_log.is_empty(), XShop.auto_log)
	# 选「购买物品」：商店打开即关，事件走完
	_check("buy_finished", await _run_event(map, 2, [0]))
	var want := []
	for id in range(1240, 1252):
		want.append([1, id, 1, 200000])
	var got: Array = XShop.auto_log[0].goods.map(func(g): return [int(g[0]), int(g[1]), int(g[2]), int(g[3])]) if XShop.auto_log.size() == 1 else []
	_check("buy_logged", XShop.auto_log.size() == 1 and got == want and XShop.auto_log[0].purchase_only == false, XShop.auto_log)
	await get_tree().process_frame
	_check("shop_freed", _shops(map) == 0)
	_check("map_idle", not map.busy)
	XShop.auto_close = false
	XShop.auto_log.clear()
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
