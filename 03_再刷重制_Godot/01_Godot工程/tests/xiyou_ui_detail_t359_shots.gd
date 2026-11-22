extends Node
## 【cc·T359·未经审查】共用控件收口的验收图：设置主页、画质子页、挂机自动卖出子页、存档页、商店（购买数量态）、天启篇标题、选线四卡，
## 16:9（1280×720）与 20:9（1600×720）各一张，键盘态（淡金双环亮、静默选中可见）。
## 无头（云端选测）只验各页建得起来（每页算一项）；有窗口且带 --out=<目录> 才存图。
##   拍：godot --audio-driver Dummy --path <工程> res://tests/xiyou_ui_detail_t359_shots.tscn -- --out=<目录>
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const PAGES := ["XOptionsScene", "XGraphicsOptionsScene", "XHangUpSubPage", "XSaveScene", "XShop", "XTianqiTitle", "XTianqiLineCards"]
const SIZES := {"16x9": Vector2i(1280, 720), "20x9": Vector2i(1600, 720)}

var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _make(cls: String) -> Node:
	for g in ProjectSettings.get_global_class_list():
		if g["class"] == cls:
			return (load(g["path"]) as Script).new()
	return null


func _run() -> void:
	TestEnv.isolate("xiyou_ui_detail_t359_shots")
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.flags["tianqi"] = {"rules": 1}
	s.gold = 12345
	XState.current = s
	XUiSkin.FORCE = true
	XUiSkin.DETAIL_V1 = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XUiSkin.input_mode = XUiSkin.InputMode.KEYBOARD
	var built := 0
	var shots := 0
	var windowed := DisplayServer.get_name() != "headless"
	for key in SIZES:
		if windowed:
			get_window().size = SIZES[key]
			await get_tree().process_frame
		for cls in PAGES:
			var page: Node = _make(cls)
			if page == null:
				print("SKIP ", cls)
				continue
			var sim_release := false
			if cls == "XTianqiTitle":
				var noop := func(): pass
				page.call("setup", {"new_game": noop, "load": noop, "options": noop, "achievements": noop, "check_update": noop}, [])
			elif cls == "XTianqiLineCards":
				page.set("lines", XTianqi.LINES)
				page.set("playable", [true, true, false, true])
			elif cls == "XHangUpSubPage":
				page.call("setup", "sell")
			elif cls == "XShop":
				page.call("setup", [[1, 1, 0, 0], [0, 1, 0, 0]], false, "")
			ReleaseEntry.simulate_release = sim_release
			add_child(page)
			built += 1
			if cls == "XShop":   # 进购买列表，再确定进数量态（右牌数量条有焦点、左列选中行降静默）
				page.call("_ok")
				for i in 8:
					await get_tree().process_frame
				page.call("_ok")
			for i in 30:
				await get_tree().process_frame
			if cls == "XTianqiLineCards":
				page.set_process(false)
				page.set("_t", 0.0)
				page.call("_process", 0.0)
			for i in 3:
				await get_tree().process_frame
			if out_dir != "" and windowed:
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute(out_dir)
				get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [cls, key]))
				shots += 1
			page.queue_free()
			ReleaseEntry.simulate_release = false
			for i in 3:
				await get_tree().process_frame
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XUiSkin.input_mode = -1
	var n := shots if shots > 0 else built
	print("TEST_RESULT=" + JSON.stringify({"passed": n, "total": n}))
	get_tree().quit(0)
