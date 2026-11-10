extends Node
## 启动开场图（XSplashScreen，MOG_TitleSplashScreen；天启篇改版默认换成开场声明屏 XWarningScreen，两者都测）与存读档小字（XAutosaveNotice，YEP_X_Autosave Window_Autosave）。
## 原版读数照源码推（参数见两个类的头注释）：开场图每张淡入 51 帧（+5 到 255，第 51 帧到顶时停留先减 1）、停 89 帧、淡出 51 帧，
## 一张共 191 帧；存读档小字 120 帧内每帧 +16，之后每帧 −16。
## 内存新局；存档写到 user://test_xiyou_splash_autosave，不碰开发档。
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func _host() -> Control:
	var c := Control.new()
	c.size = Vector2(1280, 720)
	add_child(c)
	return c


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_splash_autosave"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var hold := XSplashScreen.shown

	# ---- 开场图 ----
	check("splash_not_in_tests", not XSplashScreen.wanted())
	# 按键冒烟不放开场图（安卓模拟器冒烟的第一下键不能落在开场图上）
	check("splash_smoke_detect", XSplashScreen.is_smoke_run(PackedStringArray(["--report-entry", "--smoke-keys=space"])))
	check("splash_smoke_detect_no_keys", not XSplashScreen.is_smoke_run(PackedStringArray(["--report-entry"])))
	check("splash_smoke_detect_empty", not XSplashScreen.is_smoke_run(PackedStringArray()))
	check("splash_smoke_skip_default_on", XSplashScreen.SKIP_FOR_SMOKE)
	for n in XSplashScreen.IMAGES:
		check("splash_image_" + n, XDB.img_path("titles2", n) != "")
	var host := _host()
	var sp := XSplashScreen.play(host)
	check("splash_plays", sp != null)
	check("splash_marks_shown", XSplashScreen.shown)
	if sp != null:
		sp.set_physics_process(false)
		var done := [false]
		sp.finished.connect(func(): done[0] = true)
		check("splash_first_is_image", sp.state().index == 0 and not sp.state().blank and sp.state().opacity == 0)
		check("splash_centered", sp._sprite.position == Vector2(0, -10), sp._sprite.position)
		for i in 50:
			sp.step()
		check("splash_fade_in_50", sp.state().opacity == 250, sp.state())
		sp.step()
		check("splash_full_51", sp.state().opacity == 255 and sp._hold == 89, [sp.state(), sp._hold])
		await shot("splash_0")
		for i in 89:
			sp.step()
		check("splash_hold_end", sp._hold == 0 and sp.state().opacity == 255)
		sp.step()
		check("splash_fade_out_starts", sp.state().opacity == 250 and sp.state().index == 0)
		for i in 50:
			sp.step()
		check("splash_second_191", sp.state().index == 1 and sp.state().opacity == 0, sp.state())
		for i in 191 * 2:
			sp.step()
		check("splash_finished_573", done[0], sp.state())
		# 跳过：不透明度 ≤ 60 时不认，> 60 时开始淡出，淡完直接结束
		var sp2 := XSplashScreen.play(host)
		sp2.set_physics_process(false)
		var done2 := [false]
		sp2.finished.connect(func(): done2[0] = true)
		for i in 12:
			sp2.step(true)
		check("skip_ignored_at_60", sp2.state().opacity == 60 and sp2._hold == 90, sp2.state())
		sp2.step(true)
		check("skip_starts_fade", sp2._hold == 0 and sp2.state().opacity == 65)
		for i in 12:
			sp2.step()
		check("skip_not_done_yet", not done2[0] and sp2.state().opacity == 5)
		sp2.step()
		check("skip_done_after_fade", done2[0])
		# 回退：原版先放一张空图
		XSplashScreen.BLANK_FIRST_V028 = true
		var sp3 := XSplashScreen.play(host)
		sp3.set_physics_process(false)
		check("v028_blank_first", sp3.state().blank and sp3._tex.size() == 4)
		for i in 191:
			sp3.step()
		check("v028_then_splash_0", sp3.state().index == 1 and not sp3.state().blank)
		XSplashScreen.BLANK_FIRST_V028 = false
		sp3.queue_free()
	# ---- 开场声明屏（天启篇改版，取代上面三张图；O-259）----
	check("warning_default_on", XSplashScreen.WARNING_SCREEN)
	XSplashScreen.shown = false
	var w := XWarningScreen.play(host)
	check("warning_marks_shown", XSplashScreen.shown)
	w.set_physics_process(false)
	var wdone := [false]
	w.finished.connect(func(): wdone[0] = true)
	check("warning_text_free", "免费" in XWarningScreen.LINES[0] and "倒卖" in XWarningScreen.LINES[1])
	check("warning_red_bar", (w._root.get_node("Bar") as ColorRect).color == XWarningScreen.RED)
	check("warning_starts_hidden", w.state().opacity == 0 and w._root.modulate.a == 0.0)
	for i in XWarningScreen.FADE:
		w.step(true)  # 开头连按不算跳过
	check("warning_fade_in_full", w.state().opacity == 255 and not w.state().fading_out, w.state())
	await shot("warning")
	for i in XWarningScreen.HOLD:
		w.step()
	check("warning_hold_end", w.state().opacity == 255 and not w.state().fading_out, w.state())
	w.step()
	check("warning_fade_out_starts", w.state().fading_out and w.state().opacity < 255, w.state())
	for i in XWarningScreen.FADE:
		w.step()
	check("warning_auto_finish", wdone[0], w.state())
	# 跳过：MIN_SKIP 帧之后按一下就淡出
	var w2 := XWarningScreen.play(host)
	w2.set_physics_process(false)
	var wdone2 := [false]
	w2.finished.connect(func(): wdone2[0] = true)
	for i in XWarningScreen.MIN_SKIP:
		w2.step(true)
	check("warning_skip_ignored_early", not w2.state().fading_out, w2.state())
	check("warning_hint_shown", w2._hint.visible)
	w2.step(true)
	check("warning_skip_fades", w2.state().fading_out)
	for i in XWarningScreen.FADE:
		w2.step()
	check("warning_skip_done", wdone2[0], w2.state())
	# 回退：回到原版三张开场图
	XSplashScreen.WARNING_SCREEN = false
	check("rollback_warning_off", not XSplashScreen.WARNING_SCREEN)
	XSplashScreen.WARNING_SCREEN = true

	XSplashScreen.ENABLED = false
	check("rollback_not_wanted", not XSplashScreen.wanted())
	XSplashScreen.ENABLED = true
	XSplashScreen.shown = hold
	host.queue_free()

	# ---- 存读档小字 ----
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	XAutosaveNotice.loading = true
	check("save_ok", XSave.save(1))
	check("save_clears_loading", not XAutosaveNotice.loading)
	check("load_ok", XSave.load_slot(1))
	check("load_sets_loading", XAutosaveNotice.loading)
	var scene := Node.new()
	add_child(scene)
	XAutosaveNotice.map_ready(scene)
	check("load_clears_flag", not XAutosaveNotice.loading)
	var n := scene.get_node_or_null("XAutosaveNotice") as XAutosaveNotice
	check("load_notice_shown", n != null and n.message == XAutosaveNotice.MSG_LOAD and n.show_count == 120)
	if n != null:
		n.set_physics_process(false)
		check("window_rect", n.win.position == Vector2(1000, 648) and n.win.size == Vector2(1280, 36), [n.win.position, n.win.size])
		check("text_width_icon_plus_text", is_equal_approx(XAutosaveNotice.text_width("\\i[907]"), 36.0))
		for i in 16:
			n.step()
		check("fade_in_16", n.contents_opacity == 255 and n.show_count == 104)
		await shot("autosave_load")
		n.reveal(XAutosaveNotice.MSG_SAVE)
		check("reveal_ignored_while_showing", n.message == XAutosaveNotice.MSG_LOAD and n.show_count == 104)
		for i in 104:
			n.step()
		n.step()
		check("fade_out_starts", n.contents_opacity == 239)
		for i in 15:
			n.step()
		check("faded_out", n.contents_opacity == 0)
	XAutosaveNotice.map_ready(scene)
	check("second_map_no_notice", n != null and n.show_count == 0)
	scene.queue_free()
	# 事件插件指令 Autosave：允许且有存档位才存，存好出「存档成功！」（挂在当前场景）
	var interp := MVInterpreter.new(self, 0, 0, [])
	s.allow_autosave = true
	interp._plugin_command("Autosave")
	var cur := get_tree().current_scene.get_node_or_null("XAutosaveNotice") as XAutosaveNotice
	check("autosave_cmd_notice", cur != null and cur.message == XAutosaveNotice.MSG_SAVE and cur.show_count == 120)
	if cur != null:
		cur.queue_free()
		await get_tree().process_frame
	interp._plugin_command("DisableAutosave")
	interp._plugin_command("Autosave")
	check("disabled_no_notice", get_tree().current_scene.get_node_or_null("XAutosaveNotice") == null)
	# 回退
	XAutosaveNotice.ENABLED = false
	XSave.load_slot(1)
	var scene2 := Node.new()
	add_child(scene2)
	XAutosaveNotice.map_ready(scene2)
	check("rollback_no_load_notice", scene2.get_node_or_null("XAutosaveNotice") == null and not XAutosaveNotice.loading)
	XAutosaveNotice.ENABLED = true
	XAutosaveNotice.loading = false
	DirAccess.remove_absolute(XSave.path(1))

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
