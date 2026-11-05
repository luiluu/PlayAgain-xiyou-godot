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

## 全屏组合键的修饰键按平台：macOS 是 ⌘，Windows／其它是 Alt（各平台惯例）。static var 让测试能切到另一平台的写法。
static var fullscreen_uses_meta := OS.has_feature("macos")

## 当前平台全屏组合键的修饰键（KEY_META 或 KEY_ALT）。
static func fullscreen_modifier_key() -> Key:
	return KEY_META if fullscreen_uses_meta else KEY_ALT

## 全屏组合键的修饰键是否按着（地图轮询确定键时排除用）。
static func fullscreen_modifier_held() -> bool:
	return Input.is_key_pressed(fullscreen_modifier_key())

## F11，或 ⌘Enter（macOS）／Alt+Enter（其它平台）切换全屏。组合键同时也匹配 ui_accept（Godot 动作匹配不看多余的修饰键），
## 轮询 ui_accept 或在 _input 里处理确定键的地方要先排除它，否则会同时触发调查/翻页。
static func is_fullscreen_shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var key := event as InputEventKey
	var modifier := key.meta_pressed if fullscreen_uses_meta else key.alt_pressed
	return key.keycode == KEY_F11 or (key.keycode in [KEY_ENTER, KEY_KP_ENTER] and modifier)

static func should_apply(args: PackedStringArray) -> bool:
	for arg in args:
		if arg.begins_with("res://tests/") or arg in ["--resolution", "--fullscreen", "--maximized", "--editor", "-e"]:
			return false
	return true
