extends Node
## 模式路由、窗口适配与全屏切换；本身不读写玩家存档（各模式按 save_directory() 隔离保存）。

const MODE_FILE := "res://content/modes.json"
var modes: Array = []
var current_mode: String = ""

var key_repeat: XKeyRepeat
var platform: XPlatform

func _ready() -> void:
	_headless_frame_sleep()
	XKeyMap.apply()  # 照正式版补 Z／J 确认、X／K／Insert 取消、WASD 与小键盘方向（platform-keys1）
	key_repeat = XKeyRepeat.new()  # 按住键的连发照原版 24／6 帧（ui11）
	key_repeat.name = "KeyRepeat"
	add_child(key_repeat)
	platform = XPlatform.new()  # 平台差异（两指取消、返回键、切后台、触屏按键），跨平台二期
	platform.name = "Platform"
	add_child(platform)
	if XPlatform.is_touch():
		var touch := XTouchControls.new()
		touch.name = "TouchControls"
		platform.add_child(touch)
	if OS.get_environment("XIYOU_TEST_FAST_FORWARD").is_valid_int():
		fast_forward()
	if WindowFit.should_apply(OS.get_cmdline_args()):
		WindowFit.apply(get_window())
	var data = JSON.parse_string(FileAccess.get_file_as_string(MODE_FILE))
	if not data is Dictionary or not data.get("modes") is Array:
		push_error("Invalid mode registry")
		return
	modes = data["modes"]
	if ReleaseEntry.is_release():
		get_window().title = ReleaseEntry.APP_NAME  # 发行包窗口标题（BI）
	# 官方导出模板不允许用命令行覆盖场景路径；调试包通过显式验收参数在包内跳转。
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--verify-export"):
		_verify_export.call_deferred()

## 无窗口（--headless，只有测试与工具这样跑）时 Godot 每帧固定睡 low_processor_mode_sleep_usec（默认 6900 微秒），
## 只等帧推进的测试大半时间在睡。设了 XIYOU_HEADLESS_SLEEP_USEC（微秒）就对所有 headless 运行改用这个值（实验与回退用）。
## 不全局改：不睡时一帧的 delta 只有零点几毫秒，拿「等 n 帧」当「等动画」的测试会失败（crafting、hud 等，木吒 2026-10-25 全量实测）。
func _headless_frame_sleep() -> void:
	var usec := OS.get_environment("XIYOU_HEADLESS_SLEEP_USEC")
	if usec.is_valid_int() and DisplayServer.get_name() == "headless":
		OS.low_processor_usage_mode_sleep_usec = int(usec)

## 测试开头调用：headless 下本测试每帧不睡（xiyou_dungeon 204→18 秒）。帧的 delta 仍是真实经过的时间，计时器、补间照旧
## 按真实秒数走；只给逐个核过「不拿帧数当时间」、不睡也通过的测试用。设了 XIYOU_HEADLESS_SLEEP_USEC 时以它为准（=6900 即回退）。
func fast_headless_frames() -> void:
	if DisplayServer.get_name() == "headless" and not OS.get_environment("XIYOU_HEADLESS_SLEEP_USEC").is_valid_int():
		OS.low_processor_usage_mode_sleep_usec = 0

## 测试快进（木吒 2026-10-26）：地图与战斗的逐帧逻辑在 _physics_process 里，Godot 每真实秒只跑 60 个物理帧，计时器、补间按真实秒走，
## 所以 floor 一类真走地图打战斗的测试大半时间在等。headless 下把物理帧率与 Engine.time_scale 一起乘 n：物理帧的 delta 仍是 1/60 秒，
## 逐帧逻辑、计时器、补间同比加快，彼此的先后不变，就像真实时间快了 n 倍（只有 ignore_time_scale 的计时器和墙钟照旧）。
## 只在测试开头调用，有窗口的游戏不受影响。设了 XIYOU_TEST_FAST_FORWARD 就以它为准，并且对所有 headless 运行生效（=1 即回退，实验时也可设别的倍数）。
const FAST_FORWARD := 4
func fast_forward(n := FAST_FORWARD) -> void:
	if DisplayServer.get_name() != "headless":
		return
	var env := OS.get_environment("XIYOU_TEST_FAST_FORWARD")
	if env.is_valid_int():
		n = int(env)
	n = maxi(1, n)
	Engine.physics_ticks_per_second = 60 * n
	Engine.max_physics_steps_per_frame = 8 * n
	Engine.time_scale = float(n)

## 默认跑 tests/xiyou_mac_export；加 --verify-scene=<场景名>（只认 tests/ 下的 xiyou_ 开头场景）改跑那一个，
## 导出冒烟（07_开发环境/导出冒烟.py）用它在调试包里跑 xiyou_flow（入口→新游戏→进图→战斗→存读档）。发行包排除 tests/，跑不到。
func _verify_export() -> void:
	await get_tree().process_frame
	var scene := "res://tests/xiyou_mac_export.tscn"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--verify-scene="):
			var name := arg.substr(15)
			if name.begins_with("xiyou_") and name.is_valid_filename() and ResourceLoader.exists("res://tests/%s.tscn" % name):
				scene = "res://tests/%s.tscn" % name
			else:
				push_error("--verify-scene 找不到场景：" + name)
				get_tree().quit(2)
				return
	get_tree().change_scene_to_file.call_deferred(scene)

func get_mode(mode_id: String) -> Dictionary:
	for mode in modes:
		if mode is Dictionary and mode.get("id", "") == mode_id:
			return mode
	return {}

func enter_mode(mode_id: String) -> bool:
	var mode := get_mode(mode_id)
	if mode.is_empty() or not mode.get("enabled", false):
		return false
	var scene = mode.get("entryScene")
	if not scene is String or not ResourceLoader.exists(scene):
		return false
	var previous := current_mode
	current_mode = mode_id
	var result := get_tree().change_scene_to_file(scene)
	if result != OK:
		current_mode = previous
		return false
	# 发行包冒烟（发行入口冒烟.py）靠这一行确认进的是哪个场景；只打印，不改流程。
	if OS.get_cmdline_user_args().has("--report-entry"):
		print("ENTRY_SCENE=" + scene)
	return true

func return_to_menu() -> void:
	current_mode = ""
	# 发行构建没有模式选择：回到西游标题（BI）。
	if ReleaseEntry.skips_menu() and enter_mode(ReleaseEntry.DIRECT_MODE):
		return
	get_tree().change_scene_to_file("res://scenes/entry_menu.tscn")

func save_directory() -> String:
	var mode := get_mode(current_mode)
	if mode.is_empty():
		return ""
	return "user://modes/" + str(mode["saveNamespace"])

func _input(event: InputEvent) -> void:
	if WindowFit.is_fullscreen_shortcut(event):
		var window := get_window()
		if window.mode == Window.MODE_FULLSCREEN:
			window.mode = Window.MODE_WINDOWED
			WindowFit.apply(window)
		else:
			window.mode = Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()
