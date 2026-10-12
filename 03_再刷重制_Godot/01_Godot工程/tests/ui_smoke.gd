extends Node
## 入口界面冒烟测试：西游可进入并返回，新版禁用，手机横屏比例扩展。
## 运行：godot --path <工程> res://tests/ui_smoke.tscn -- --out=<截图目录>
## 不读写任何保存；截图只写入 --out 指定目录。

const MENU := "res://scenes/entry_menu.tscn"
var out_dir := ""
var results: Array = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	if has_meta("runner"):
		_run.call_deferred()
		return
	# 场景切换会释放当前场景，测试执行器挂在 root 下才能跨场景存活。
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	runner.out_dir = out_dir
	get_tree().root.add_child.call_deferred(runner)

func _check(name: String, ok: bool) -> void:
	results.append({"name": name, "passed": ok})

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _shot(file: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))

func _find(name: String) -> Node:
	return get_tree().current_scene.find_child(name, true, false)

func _run() -> void:
	get_tree().change_scene_to_file(MENU)
	await _frames(4)
	_check("menu_loaded", get_tree().current_scene.scene_file_path == MENU)
	_check("two_modes_registered", GameApp.modes.size() == 2)
	var xiyou: Button = _find("XiyouEntry")
	var future: Button = _find("NewEntry")
	_check("xiyou_button_enabled", xiyou != null and not xiyou.disabled)
	_check("new_button_disabled", future != null and future.disabled)
	_check("new_mode_refused", not GameApp.enter_mode("new"))
	_check("unknown_mode_refused", not GameApp.enter_mode("missing"))
	_check("menu_two_columns_wide", _find("XiyouEntry").get_parent().get_parent().columns == 2)
	await _shot("01_入口_宽屏.png")
	xiyou.pressed.emit()
	await _frames(4)
	_check("xiyou_entered", get_tree().current_scene.scene_file_path == "res://modes/xiyou/entry.tscn")
	_check("xiyou_current_mode", GameApp.current_mode == "xiyou")
	_check("xiyou_save_namespace", GameApp.save_directory() == "user://modes/xiyou")
	await _shot("02_西游预览.png")
	var back: Button = _find("ReturnToMenu")
	_check("return_button_present", back != null)
	back.pressed.emit()
	await _frames(4)
	_check("returned_to_menu", get_tree().current_scene.scene_file_path == MENU)
	_check("mode_cleared", GameApp.current_mode == "" and GameApp.save_directory() == "")
	# 20:9 横屏手机比例：stretch aspect=expand 应扩展可视宽度而非加黑边。
	get_window().size = Vector2i(1600, 720)
	await _frames(6)
	var visible := get_viewport().get_visible_rect().size
	_check("phone_ratio_expands_width", visible.x > 1280.0 and is_equal_approx(visible.y, 800.0))
	await _shot("03_入口_手机比例.png")
	_check("no_user_saves_written", not DirAccess.dir_exists_absolute("user://modes"))
	var passed := results.filter(func(r): return r["passed"]).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
