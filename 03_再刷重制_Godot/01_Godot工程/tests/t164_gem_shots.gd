extends Node
## 工具（不是专项）：T164 宝石发挥度开／关截图。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t164_gem_shots.tscn -- --out=<目录>
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const Kit := preload("res://tests/lib/tq_save_kit.gd")
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _frames(n := 20) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	TestEnv.isolate("t164_gem_shots")
	XSplashScreen.shown = true
	var s := Kit.new_game("jianxian")
	XState.current = s
	var g := XGear.create("weapon", 972, s)
	g["instanceId"] = "t164_shot"
	XGearUpgrade.apply_effects(g, XDB.rec("Items", 258), true, s)
	for sc in ["on", "off"]:
		XTianqiBase.PHASE4 = sc == "on"
		XTianqiGear.clear_effective_cache()
		for mode in [0, 2]:
			var bg := ColorRect.new()
			bg.color = Color("202020")
			bg.size = Vector2(1280, 720)
			add_child(bg)
			var d := XGearDetail.new(bg, Rect2(320, 0, 960, 720), XUI.MENU_WINDOW_OPACITY, ["装备详情", "插槽与镶嵌"], [0, 2])
			d.set_item(g)
			d.set_mode(mode)
			await _frames(5)
			await _shot("%s_detail_mode%d" % [sc, mode])
			bg.queue_free()
			await _frames(3)
		var b := XInlayBook.new()
		add_child(b)
		await _frames(10)
		b.ok()
		await _frames(10)
		await _shot(sc + "_inlay_book")
		b.queue_free()
		await _frames(3)
	XTianqiBase.PHASE4 = false
	get_tree().quit()
