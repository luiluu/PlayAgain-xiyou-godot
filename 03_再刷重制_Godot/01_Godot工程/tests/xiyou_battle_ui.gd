extends Node
## 战斗画面验收：与原版参照（04_验证/本地结果/原版参照/40～43，地图 5、队伍 狗逍遥/修/罗琳/美娜、敌群 2）同一场面，
## 核对站位、窗口矩形与操作流程。内存新游戏，不写任何存档。窗口模式加 -- --out=<目录> 截图。

const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func _until(cond: Callable, n := 900) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	get_viewport().push_input(e)
	await _frames(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	get_viewport().push_input(r)
	await _frames(2)


func _run() -> void:
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	seed(20261013)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 5
	s.x = 10
	s.y = 10
	s.direction = 2
	get_tree().change_scene_to_file(MAP_SCENE)
	var ok := await _until(func(): return get_tree().current_scene is XMapScene and get_tree().current_scene.player != null and not get_tree().current_scene.busy)
	_check("map5_loaded", ok)
	var map: XMapScene = get_tree().current_scene
	await _frames(10)
	XMessageBox.auto = false
	map._set_busy(true)
	var res := {"value": null}
	var go := func(): res.value = await map.start_battle(2, true, false)
	go.call()
	ok = await _until(func(): return _battle(map) != null and _battle(map).cmd_win != null)
	_check("command_shown", ok)
	var b: XBattleScene = _battle(map)
	if b == null:
		_finish()
		return
	# 站位（原版运行时：角色 x 819，y 230/329/427/526；敌人 = 敌群坐标 y + 48）
	var homes := b.logic.actors.map(func(a): return b.sprites[a].home)
	_check("actor_column", homes == [Vector2(819, 230), Vector2(819, 329), Vector2(819, 427), Vector2(819, 526)], homes)
	var ehomes := b.logic.enemies.map(func(e): return b.sprites[e].home)
	_check("enemy_reposition", ehomes == [Vector2(262, 331), Vector2(201, 463), Vector2(353, 409)], ehomes)
	_check("five_layout", XBattleScene.party_layout(5) == [Vector2(769, 216), Vector2(869, 297), Vector2(769, 378), Vector2(869, 459), Vector2(769, 540)], XBattleScene.party_layout(5))
	_check("actor_scale", is_equal_approx(b.sprites[b.logic.actors[0]].body_scale, 0.75))
	await _frames(30)
	await _shot("battle_40_input")
	_finish()


func _battle(map: XMapScene) -> XBattleScene:
	for c in map.ui.get_children():
		if c is XBattleScene:
			return c
	return null


func _finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
