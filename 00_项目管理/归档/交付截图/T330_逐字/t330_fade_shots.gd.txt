extends Node
## T330 截帧：新皮肤下演一句天启篇对白，每个物理帧存一张到 --out=<目录>；另量 20 次整页重画的 CPU 耗时（演 vs 不演）。窗口模式跑，加 --audio-driver Dummy。
var out := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_run.call_deferred()

func _run() -> void:
	XConfig.path_override = "user://t330_shots_options.json"
	XMessageBox.auto = false
	XUiSkin.FORCE = true
	XState.new_game(3, 1, [])
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	var box := XMessageBox.new()
	add_child(box)
	await get_tree().physics_frame
	var t := func(): await box.run({"face": "Actor3", "index": 5, "position": 2, "lines": ["\\n<毒大炮>七印的锁链在黑暗里一枚一枚亮起来，没有人知道最后一枚熄灭的时候，会发生什么。"]})
	t.call()
	var n := 0
	var started := false
	var anim := []
	var idle := []
	while n < 150:
		await RenderingServer.frame_post_draw
		var rec := [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.TIME_FPS)]
		if started:
			(anim if box._fade_running() else idle).append(rec)
		if not box._page_glyphs.is_empty():
			started = true
		if started and out != "":
			get_viewport().get_texture().get_image().save_png(out.path_join("f%03d.png" % n))
		if started:
			n += 1
	print("PERF anim_frames=%d idle_frames=%d" % [anim.size(), idle.size()])
	for name in ["anim", "idle"]:
		var a: Array = anim if name == "anim" else idle
		if a.is_empty():
			continue
		var sp := 0.0
		var dc := 0.0
		for r in a:
			sp += r[0]
			dc += r[1]
		print("PERF %s process_ms=%.3f drawcalls=%.1f" % [name, sp / a.size(), dc / a.size()])
	get_tree().quit()
