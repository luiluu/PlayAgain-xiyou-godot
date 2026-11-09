extends Node
## 全灭回标题（O-244，Kyo 2026-11-08 定：同原版 Scene_Gameover）：
## - 默认显示 NULL 字图，NULL_IMAGE = false 回原版「菜」字图；
## - XGameOverScreen 状态机：淡入 24 帧，淡入完按确定才开始淡出，淡出 24 帧后发 finished；没按就一直停着；图在；
## - 真实地图场景里 game_over()（默认）：弹出游戏结束画面、BGM 停、gameoverMe 在放，不传回大厅、队伍不回满；
##   按确定走完后离开地图场景（回标题 entry）；
## - 回退 GAME_OVER_TO_LOBBY = true：旧做法——回满、传回大厅 Map004。
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const TIMEOUT_MS := 120000
const WaitBudget := preload("res://tests/wait_budget.gd")

var results: Array = []


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


func _wait_map(map_id: int) -> XMapScene:
	var t0 := WaitBudget.new(TIMEOUT_MS)
	while t0.waiting():
		var m = get_tree().current_scene
		if m is XMapScene and m.map_id == map_id and m.player != null and not m.busy:
			return m
		await get_tree().process_frame
	return null


func _open_lobby() -> XMapScene:
	var s := XState.new_game_blank()
	s.map_id = 4
	s.x = 14
	s.y = 23
	get_tree().change_scene_to_file(MAP_SCENE)
	return await _wait_map(4)


func _run_game_over(m: XMapScene, done: Array) -> void:
	await m.game_over()
	done[0] = true


func _hurt() -> void:
	for a in XState.current.members():
		a.hp = 1


func _all_hurt() -> bool:
	return XState.current.members().all(func(a): return a.hp == 1)


func _run() -> void:
	# 1. 画面状态机
	var g := XGameOverScreen.new()
	add_child(g)
	_check("screen_image", g.state().has_image, g.state())
	_check("screen_default_null_image", g.state().image == "NULL", g.state())
	XGameOverScreen.NULL_IMAGE = false
	var g0 := XGameOverScreen.new()
	add_child(g0)
	_check("screen_rollback_original_image", g0.state().image == "GameOver", g0.state())
	g0.queue_free()
	XGameOverScreen.NULL_IMAGE = true
	for i in range(30):
		g.step(false)
	_check("screen_waits_without_press", g.state().frame == XGameOverScreen.FADE_FRAMES and not g.state().fading_out and not g.state().done, g.state())
	g.step(true)
	_check("screen_fading_out_after_press", g.state().fading_out, g.state())
	var fired := [false]
	g.finished.connect(func(): fired[0] = true)
	for i in range(XGameOverScreen.FADE_FRAMES + 2):
		g.step(false)
	_check("screen_finished", fired[0] and g.state().done, g.state())
	# 2. 真实地图：默认回标题（hook 代替真的切到标题）
	var titled := [0]
	XMapScene.return_to_title_hook = func(): titled[0] += 1
	var m := await _open_lobby()
	if not _check("lobby_open", m != null):
		_finish()
		return
	_hurt()
	var over_done := [false]
	_run_game_over(m, over_done)    # 不 await：画面在等按键
	var scr: XGameOverScreen = null
	var t0 := WaitBudget.new(10000)
	while t0.waiting() and scr == null:
		for c in m.ui.get_children():
			if c is XGameOverScreen:
				scr = c
		await get_tree().process_frame
	_check("default_screen_shown", scr != null)
	_check("default_no_recover", _all_hurt())
	_check("default_bgm_stopped", not m.bgm.playing)
	_check("default_me_playing", m.me.playing or m.me.stream != null)
	_check("default_still_on_lobby_map", m.map_id == 4)
	if scr != null:
		for i in range(XGameOverScreen.FADE_FRAMES + 2):
			scr.step(false)
		scr.step(true)
		for i in range(XGameOverScreen.FADE_FRAMES + 2):
			scr.step(false)
	_check("default_returned_to_title", titled[0] == 1 and over_done[0], titled)
	_check("default_me_stopped", not m.me.playing)
	# 2b. 随机遇敌全灭（审查 70 P2①）：_encounter 收战斗结果，result==2 进结束画面（原来人 0 血留在地图）
	var m2 := await _open_lobby()
	if _check("lobby_reopen", m2 != null):
		_hurt()
		m2.map_data.encounterList = [{"weight": 1, "troopId": 4, "regionSet": []}]
		titled[0] = 0
		XMapScene.GAME_OVER_TO_LOBBY = false
		m2._encounter()   # 不 await：战斗自动打输后进结束画面，画面等按键
		var scr2: XGameOverScreen = null
		var t2 := WaitBudget.new(60000)
		while t2.waiting() and scr2 == null:
			for c in m2.ui.get_children():
				if c is XGameOverScreen:
					scr2 = c
			await get_tree().process_frame
		_check("encounter_wipe_game_over", scr2 != null)
		_check("encounter_wipe_busy", m2.busy)
		if scr2 != null:
			for i in range(XGameOverScreen.FADE_FRAMES + 2):
				scr2.step(false)
			scr2.step(true)
			for i in range(XGameOverScreen.FADE_FRAMES + 2):
				scr2.step(false)
			for i in range(5):
				await get_tree().process_frame
		_check("encounter_wipe_to_title", titled[0] == 1, titled)
	# 2c. 经解释器输掉（301 不可败，审查 70 P2②）：结束画面期间一直 busy，事件收尾也不放开，方向键人不动
	var m3 := await _open_lobby()
	if _check("lobby_reopen2", m3 != null):
		_hurt()
		titled[0] = 0
		m3._set_busy(true)
		var interp := MVInterpreter.new(m3, 4, 0, [
			{"code": 301, "indent": 0, "parameters": [0, 4, false, false]},
			{"code": 0, "indent": 0, "parameters": []},
		])
		var ev_done := [false]
		var go_ev := func():
			await interp.run()
			m3._set_busy(false)   # 同 run_event 的收尾
			ev_done[0] = true
		go_ev.call()
		var scr3: XGameOverScreen = null
		var t3 := WaitBudget.new(60000)
		while t3.waiting() and scr3 == null:
			for c in m3.ui.get_children():
				if c is XGameOverScreen:
					scr3 = c
			await get_tree().process_frame
		_check("interp_wipe_game_over", scr3 != null)
		var grid0: Vector2i = m3.player.grid
		Input.action_press("ui_right")
		for i in range(20):
			await get_tree().physics_frame
		Input.action_release("ui_right")
		_check("interp_wipe_busy_held", m3.busy and not ev_done[0], [m3.busy, ev_done[0]])
		_check("interp_wipe_player_still", m3.player.grid == grid0, [grid0, m3.player.grid])
		if scr3 != null:
			for i in range(XGameOverScreen.FADE_FRAMES + 2):
				scr3.step(false)
			scr3.step(true)
			for i in range(XGameOverScreen.FADE_FRAMES + 2):
				scr3.step(false)
			for i in range(5):
				await get_tree().process_frame
		_check("interp_wipe_to_title", titled[0] == 1 and ev_done[0], titled)
		_check("interp_wipe_busy_after", m3.busy, null)
	# 3. 回退：回大厅
	XMapScene.GAME_OVER_TO_LOBBY = true
	titled[0] = 0
	_hurt()
	XMessageBox.auto = true
	XMessageBox.auto_answers = []
	await m3.game_over()
	XMessageBox.auto = false
	XMapScene.GAME_OVER_TO_LOBBY = false
	_check("lobby_recovered", XState.current.members().all(func(a): return a.hp == a.mhp), XState.current.members().map(func(a): return [a.hp, a.mhp]))
	_check("lobby_no_title", titled[0] == 0)
	_check("lobby_on_map4", XState.current.map_id == 4)
	_finish()


func _finish() -> void:
	var cur := get_tree().current_scene
	if cur is XMapScene:
		cur.queue_free()
		for i in range(5):
			await get_tree().process_frame
	XMapScene.return_to_title_hook = Callable()
	XMapScene.GAME_OVER_TO_LOBBY = false
	XGameOverScreen.NULL_IMAGE = true
	XMessageBox.auto = false
	XMessageBox.auto_answers = []
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
