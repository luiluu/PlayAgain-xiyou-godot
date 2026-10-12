class_name WindowFit
extends RefCounted
## 按屏幕的实际可用像素选窗口大小；Retina 的 window.size 是物理像素。
## 画面仍使用 1280×720 逻辑坐标，由 canvas_items 统一缩放，不独立缩小文字。
const BASE := Vector2(1280, 720)
const SCREEN_FRACTION := 0.90

static func rectangle(usable: Rect2i) -> Rect2i:
	var available := Vector2(usable.size) * SCREEN_FRACTION
	var scale := minf(available.x / BASE.x, available.y / BASE.y)
	var dims := Vector2i((BASE * scale).round())
	return Rect2i(usable.position + (usable.size - dims) / 2, dims)

static func apply(window: Window) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rect := rectangle(DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()))
	window.size = rect.size
	window.position = rect.position

static func should_apply(args: PackedStringArray) -> bool:
	for arg in args:
		if arg.begins_with("res://tests/") or arg in ["--resolution", "--fullscreen", "--maximized", "--editor", "-e"]:
			return false
	return true
