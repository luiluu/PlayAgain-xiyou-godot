extends Node
## 模式路由、窗口适配与全屏切换；本身不读写玩家存档（各模式按 save_directory() 隔离保存）。

const MODE_FILE := "res://content/modes.json"
var modes: Array = []
var current_mode: String = ""

func _ready() -> void:
	_headless_frame_sleep()
	if WindowFit.should_apply(OS.get_cmdline_args()):
		WindowFit.apply(get_window())
	var data = JSON.parse_string(FileAccess.get_file_as_string(MODE_FILE))
	if not data is Dictionary or not data.get("modes") is Array:
		push_error("Invalid mode registry")
		return
	modes = data["modes"]
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

func _verify_export() -> void:
	await get_tree().process_frame
	get_tree().change_scene_to_file.call_deferred("res://tests/xiyou_mac_export.tscn")

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
	return true

func return_to_menu() -> void:
	current_mode = ""
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
