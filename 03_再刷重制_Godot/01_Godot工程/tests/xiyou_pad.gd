extends Node
## 手柄（platform-keys2）：原版 Input.gamepadMapper／_updateGamepadState——A 确认、B 取消、X＝shift、Y＝menu、LB／RB 翻页，
## 十字键与左摇杆（阈值 0.5）变成方向键事件并按键盘节奏连发。回退开关 XKeyRepeat.MV_PAD。

var results := []
var got := []   # [帧, 事件类别, 码, echo]
var frame := 0


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _physics_process(_d: float) -> void:
	frame += 1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		got.append([frame, "key", int(event.keycode), event.echo])
	elif event is InputEventKey:
		got.append([frame, "keyup", int(event.keycode), false])
	elif event is InputEventJoypadMotion:
		got.append([frame, "motion", int(event.axis), false])
	elif event is InputEventJoypadButton and event.pressed:
		got.append([frame, "button", int(event.button_index), false])


static func axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e


static func button(b: JoyButton, pressed := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = pressed
	return e


func send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func kinds(k: String) -> Array:
	return got.filter(func(r): return r[1] == k)


func _run() -> void:
	# 动作映射
	check("a_accept", InputMap.event_is_action(button(JOY_BUTTON_A), "ui_accept"))
	check("b_cancel", InputMap.event_is_action(button(JOY_BUTTON_B), "ui_cancel"))
	check("lb_pageup", InputMap.event_is_action(button(JOY_BUTTON_LEFT_SHOULDER), "ui_page_up"))
	check("rb_pagedown", InputMap.event_is_action(button(JOY_BUTTON_RIGHT_SHOULDER), "ui_page_down"))
	check("y_menu", InputMap.event_is_action(button(JOY_BUTTON_Y), "mv_menu"))
	check("x_dash", InputMap.event_is_action(button(JOY_BUTTON_X), "mv_dash"))
	check("dpad_up", InputMap.event_is_action(button(JOY_BUTTON_DPAD_UP), "ui_up"))
	await phys(2)
	got.clear()
	# 摇杆：抖动只触发一次，原手柄事件被吃掉，换成方向键
	send(axis(JOY_AXIS_LEFT_Y, 0.4))
	await phys(2)
	check("below_threshold_nothing", got.is_empty(), got)
	send(axis(JOY_AXIS_LEFT_Y, 0.9))
	send(axis(JOY_AXIS_LEFT_Y, 1.0))
	send(axis(JOY_AXIS_LEFT_Y, 0.7))
	await phys(2)
	check("stick_down_once", kinds("key").size() == 1 and kinds("key")[0][2] == KEY_DOWN and not kinds("key")[0][3], got)
	check("motion_consumed", kinds("motion").is_empty(), got)
	# 连发：按住约 24 帧后每 6 帧一次
	got.clear()
	await phys(40)
	var echoes := kinds("key").filter(func(r): return r[3])
	check("repeat_echoes_every_6", echoes.size() >= 2 and echoes[0][2] == KEY_DOWN and echoes[1][0] - echoes[0][0] == 6, got)
	# 松开
	send(axis(JOY_AXIS_LEFT_Y, 0.0))
	await phys(2)
	check("release_keyup", kinds("keyup").size() == 1 and kinds("keyup")[0][2] == KEY_DOWN, got)
	got.clear()
	await phys(40)
	check("no_repeat_after_release", got.is_empty(), got)
	# 十字键、上优先于下、左优先于右
	send(button(JOY_BUTTON_DPAD_LEFT))
	await phys(2)
	check("dpad_left_key", kinds("key").size() == 1 and kinds("key")[0][2] == KEY_LEFT and kinds("button").is_empty(), got)
	send(button(JOY_BUTTON_DPAD_LEFT, false))
	await phys(2)
	got.clear()
	send(axis(JOY_AXIS_LEFT_Y, -0.8))
	send(button(JOY_BUTTON_DPAD_DOWN))
	await phys(2)
	check("up_beats_down", kinds("key").size() == 1 and kinds("key")[0][2] == KEY_UP, got)
	send(axis(JOY_AXIS_LEFT_Y, 0.0))
	send(button(JOY_BUTTON_DPAD_DOWN, false))
	await phys(2)
	# X＝shift
	got.clear()
	send(button(JOY_BUTTON_X))
	await phys(2)
	check("x_shift_key", kinds("key").size() == 1 and kinds("key")[0][2] == KEY_SHIFT, got)
	send(button(JOY_BUTTON_X, false))
	await phys(2)
	# A／B／LB 不被吃（走 Godot 默认动作）
	got.clear()
	send(button(JOY_BUTTON_A))
	send(button(JOY_BUTTON_A, false))
	await phys(2)
	check("a_passes", kinds("button").size() == 1, got)
	# 回退：手柄事件原样往下传
	XKeyRepeat.MV_PAD = false
	got.clear()
	send(axis(JOY_AXIS_LEFT_Y, 0.9))
	await phys(2)
	check("rollback_motion_passes", kinds("motion").size() == 1 and kinds("key").is_empty(), got)
	send(axis(JOY_AXIS_LEFT_Y, 0.0))
	XKeyRepeat.MV_PAD = true
	await phys(2)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
