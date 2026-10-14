extends Node
## 对照正式 v0.15 的原插件计时器和绘制读数；测试只在内存建队，不读写任何存档。
var results := []
var out_dir := ""


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", detail)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func _run() -> void:
	var c := XDifficultyNotice.new()
	c.advance(9000, 2)
	check("default_simple_has_no_notice", c.remaining == 0 and not c.showing)
	c.free()
	c = XDifficultyNotice.new()
	c.advance(64, 3)
	check("changed_difficulty_fades_in", c.remaining == 238 and c.opacity == 20 and c.text == "当前难度：普通" and c.color == Color("4499ff"), [c.remaining,c.opacity,c.text])
	c.advance(29 * 30, 3)
	c.paint()
	# 真实插件定帧：239→推进30格→209，x=-485，y=10.1247419873，alpha=255。
	check("reference_plateau", c.remaining == 209 and c.opacity == 255 and is_equal_approx(c.bounce_y, 10.1247419873), [c.remaining,c.opacity,c.bounce_y])
	c.advance(180 * 30, 3)
	c.paint()
	check("reference_fade_out", c.remaining == 29 and c.opacity == 174 and is_equal_approx(c.bounce_y, 12.3333824853), [c.remaining,c.opacity,c.bounce_y])
	c.advance(29 * 30, 3)
	c.paint()
	check("expires_after_240_ticks", c.remaining == 0 and not c.showing)
	c.advance(15000, 3)
	check("same_difficulty_does_not_restart", c.remaining == 0 and not c.showing)
	c.advance(96, 4)
	check("difficulty_change_restarts", c.remaining >= 236 and c.text == "当前难度：困难" and c.color == Color("b050ff"), [c.remaining,c.text,c.color])
	var paused_text := c.text
	c.advance(7200, 5, false)
	check("background_clock_keeps_counting", c.remaining == 0 and c.text == paused_text)
	c.paint()
	check("return_after_expiry_hides_notice", not c.showing)
	var names := ["宝宝","简单","普通","困难","地狱","天灾"]
	var colors := ["ffffff","39ff39","4499ff","b050ff","ff9922","ffd700"]
	for i in range(6):
		c.difficulty = i + 1
		c.remaining = 200
		c.paint()
		check("difficulty_" + str(i + 1), c.text == "当前难度：" + names[i] and c.color == Color(colors[i]))
	check("rainbow_original_rgb", XDifficultyNotice.difficulty_color(9, 0) == Color8(247, 83, 83) and XDifficultyNotice.difficulty_color(9, 30) == Color8(83,247,83))
	c.free()
	# 实际地图挂载；统一墙钟不会被战斗加速改变，快照包含提示，活提示不盖在战斗上。
	XSave.dir_override = "user://test_xiyou_difficulty_notice"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8,9,10])
	s.map_id = 5
	s.x = 10
	s.y = 10
	var map := XMapScene.new()
	add_child(map)
	await frames(8)
	var clock := XDifficultyNotice.instance
	clock.set_process(false)
	clock.difficulty = 3
	clock.last_difficulty = 3
	clock.remaining = 209
	clock.paint()
	var notice := map.difficulty_notice
	check("map_notice_rect", notice.position.is_equal_approx(Vector2(-485,10.1247419873)) and notice.size == Vector2(1800,80) and notice.mouse_filter == Control.MOUSE_FILTER_IGNORE, [notice.position,notice.size])
	check("map_notice_not_hidden_with_hud", notice.get_parent() == map.ui and not map.hud.is_ancestor_of(notice))
	check("canvas_renders_original_plateau", notice.visible and notice.modulate.a == 1 and (notice.font as FontVariation).variation_embolden > 0)
	await shot("01_普通难度地图提示")
	map._set_busy(true)
	var finished := {"done":false}
	var go := func():
		await map.start_battle(2,true,false)
		finished.done = true
	go.call()
	for i in range(120):
		if map._in_battle:
			break
		await frames(1)
	var battles := map.ui.get_children().filter(func(n): return n is XBattleScene)
	check("battle_uses_snapshot_and_hides_live_notice", battles.size() == 1 and map._in_battle and not notice.visible and (DisplayServer.get_name() == "headless" or battles[0].snapshot != null))
	Engine.time_scale = 8
	clock.advance(960, 3, false)
	check("battle_clock_wall_time", clock.remaining == 177)
	await frames(30)
	await shot("02_战斗快照难度提示")
	Engine.time_scale = 1
	if not battles.is_empty():
		battles[0].finished.emit(1)
	await frames(2)
	check("return_restores_running_notice", finished.done and not map._in_battle and notice.visible)
	clock.advance(7200,3)
	check("expired_notice_cannot_enter_next_snapshot", not notice.visible)
	await shot("03_提示已消失")
	map.queue_free()
	await frames(2)
	XEnemy.force_roll = -1
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed":passed,"total":results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
