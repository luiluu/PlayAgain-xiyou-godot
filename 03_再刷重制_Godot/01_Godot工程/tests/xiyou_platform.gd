extends Node
## 跨平台二期（cc BH 2026-11-05）：XPlatform 两指取消、返回键、切后台补跑（O-待定-2 开与关）、XTouchControls 虚拟按键，
## 发行版存档目录与横屏设置。桌面上用 XPlatform.force_mobile 当成手机测，不依赖测试机平台。
var results := []

class Recorder extends Node:
	var right_clicks := 0
	var cancels := 0
	var accepts := 0
	var unhandled_touches := 0
	var unhandled_left := 0
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			right_clicks += 1
		if event.is_action_pressed("ui_cancel"):
			cancels += 1
		if event.is_action_pressed("ui_accept"):
			accepts += 1
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			unhandled_touches += 1
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			unhandled_left += 1

func _ready() -> void:
	_run.call_deferred()

func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))

func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame

## 画面坐标（1280×720）→ 窗口坐标：注入的事件按窗口坐标算，无头窗口只有 64×64，要先换算。
func to_window(pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * pos

func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = to_window(pos)
	e.pressed = pressed
	Input.parse_input_event(e)

func emulated_click(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.device = InputEvent.DEVICE_ID_EMULATION
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = to_window(pos)
	e.global_position = e.position
	Input.parse_input_event(e)

func _run() -> void:
	var saved_probe := XPlatform.idle_probe
	XPlatform.force_mobile = true
	var platform := XPlatform.new()
	add_child(platform)
	var rec := Recorder.new()
	add_child(rec)
	check("is_touch_forced", XPlatform.is_touch() and XPlatform.is_mobile())

	# 两指：第二指转成一次右键，第二指本身不往下传（地图不会当成走路目标）
	touch(1, Vector2(400, 300), true)
	touch(1, Vector2(400, 300), false)
	await frames(3)
	check("two_finger_right_click", rec.right_clicks >= 1, rec.right_clicks)
	check("second_finger_swallowed", rec.unhandled_touches == 0, rec.unhandled_touches)

	# 返回键：不在入口菜单时当取消键
	var before := rec.cancels
	platform.go_back()
	await frames(3)
	check("back_is_cancel", rec.cancels > before, [before, rec.cancels])

	# 切后台补跑
	var idle := [true]
	XPlatform.idle_probe = func(): return idle[0]
	platform.on_paused(0)
	var secs := platform.on_resumed(60_000)
	check("catch_up_started", is_equal_approx(secs, 60.0) and platform.is_catching_up()
		and Engine.time_scale == float(XPlatform.CATCH_UP_SPEED) and Engine.physics_ticks_per_second == 60 * XPlatform.CATCH_UP_SPEED, [secs, Engine.time_scale])
	platform.stop_catch_up()
	check("catch_up_restores_engine", not platform.is_catching_up() and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, [Engine.time_scale, Engine.physics_ticks_per_second])
	platform.on_paused(0)
	check("catch_up_capped", is_equal_approx(platform.on_resumed(10_000_000), XPlatform.BACKGROUND_CAP_SEC))
	platform.stop_catch_up()
	platform.on_paused(0)
	check("short_away_no_catch_up", platform.on_resumed(2_000) == 0.0 and not platform.is_catching_up())
	idle[0] = false
	platform.on_paused(0)
	idle[0] = true
	check("not_idle_when_paused_no_catch_up", platform.on_resumed(60_000) == 0.0)
	platform.on_paused(0)
	platform.on_resumed(60_000)
	idle[0] = false
	await frames(2)
	check("catch_up_stops_when_idle_ends", not platform.is_catching_up() and Engine.time_scale == 1.0)
	idle[0] = true
	# 点屏幕停止补跑
	platform.on_paused(0)
	platform.on_resumed(60_000)
	touch(0, Vector2(640, 200), true)
	await frames(2)
	touch(0, Vector2(640, 200), false)
	check("tap_stops_catch_up", not platform.is_catching_up())
	# O-待定-2 回退：关掉后台挂机就不补跑
	XPlatform.BACKGROUND_IDLE = false
	platform.on_paused(0)
	check("background_idle_off", platform.on_resumed(60_000) == 0.0 and not platform.is_catching_up())
	XPlatform.BACKGROUND_IDLE = true
	XPlatform.idle_probe = saved_probe

	# 虚拟按键
	XTouchControls.SETTINGS_PATH = "user://test_xiyou_platform_touch.json"
	DirAccess.remove_absolute(XTouchControls.SETTINGS_PATH)
	check("stick_dead_zone", XTouchControls.stick_direction(Vector2(5, 5)) == "")
	check("stick_one_axis", XTouchControls.stick_direction(Vector2(-40, 20)) == "ui_left" and XTouchControls.stick_direction(Vector2(10, -50)) == "ui_up"
		and XTouchControls.stick_direction(Vector2(30, 31)) == "ui_down" and XTouchControls.stick_direction(Vector2(50, 0)) == "ui_right")
	var pad := XTouchControls.new()
	platform.add_child(pad)
	await frames(2)
	var ok_center: Vector2 = (XTouchControls.BUTTONS.ok.rect as Rect2).get_center()
	var accepts := rec.accepts
	var left_before := rec.unhandled_left
	var touches_before := rec.unhandled_touches
	emulated_click(ok_center, true)  # Godot 由第一指转出的鼠标事件先到
	touch(0, ok_center, true)
	await frames(2)
	check("ok_button_presses_accept", Input.is_action_pressed("ui_accept") and rec.accepts > accepts, [rec.accepts, accepts])
	check("ok_button_swallows_mouse", rec.unhandled_left == left_before and rec.unhandled_touches == touches_before, [rec.unhandled_left, left_before, rec.unhandled_touches, touches_before])
	# 按着确定再用第二指按取消：不算两指取消
	var rights := rec.right_clicks
	var cancel_center: Vector2 = (XTouchControls.BUTTONS.cancel.rect as Rect2).get_center()
	touch(1, cancel_center, true)
	await frames(2)
	check("second_finger_on_button_not_two_finger", rec.right_clicks == rights and Input.is_action_pressed("ui_cancel"), [rec.right_clicks, rights])
	touch(1, cancel_center, false)
	emulated_click(ok_center, false)
	touch(0, ok_center, false)
	await frames(2)
	check("buttons_release", not Input.is_action_pressed("ui_accept") and not Input.is_action_pressed("ui_cancel"))
	# 按住连发：24 帧后再按
	accepts = rec.accepts
	touch(0, ok_center, true)
	for i in 40:
		await get_tree().physics_frame
	check("hold_repeats", rec.accepts >= accepts + 2, [rec.accepts, accepts])
	touch(0, ok_center, false)
	await frames(2)
	# 摇杆
	touch(0, XTouchControls.STICK_CENTER, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = to_window(XTouchControls.STICK_CENTER + Vector2(-50, 10))
	Input.parse_input_event(drag)
	await frames(2)
	check("stick_drag_left", Input.is_action_pressed("ui_left") and not Input.is_action_pressed("ui_down"))
	# 切后台松开所有键
	platform.on_paused(0)
	await frames(2)
	check("pause_releases_keys", not Input.is_action_pressed("ui_left"))
	platform.on_resumed(0)
	touch(0, XTouchControls.STICK_CENTER, false)
	# 跑步键按住＝Shift
	var run_center: Vector2 = (XTouchControls.BUTTONS.run.rect as Rect2).get_center()
	touch(0, run_center, true)
	await frames(2)
	check("run_holds_shift", Input.is_physical_key_pressed(KEY_SHIFT))
	touch(0, run_center, false)
	await frames(2)
	check("run_releases_shift", not Input.is_physical_key_pressed(KEY_SHIFT))
	# 隐藏按键
	var hide_center: Vector2 = (XTouchControls.BUTTONS.hide.rect as Rect2).get_center()
	touch(0, hide_center, true)
	touch(0, hide_center, false)
	await frames(2)
	check("hide_toggles", pad.hidden and pad.hit(ok_center) == "" and pad.hit(hide_center) == "hide" and FileAccess.file_exists(XTouchControls.SETTINGS_PATH))
	var pad2 := XTouchControls.new()
	platform.add_child(pad2)
	await frames(1)
	check("hide_remembered", pad2.hidden)
	pad2.queue_free()
	touch(0, hide_center, true)
	touch(0, hide_center, false)
	await frames(2)
	check("show_again", not pad.hidden and pad.hit(ok_center) == "ok")
	DirAccess.remove_absolute(XTouchControls.SETTINGS_PATH)

	# 设置：发行版存档目录去掉「_开发」（O-待定-1），横屏
	check("release_user_dir", str(ProjectSettings.get_setting("application/config/custom_user_dir_name.release", "")) == "KYO/再刷重制"
		and str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")) == "KYO/再刷重制_开发")
	check("landscape", int(ProjectSettings.get_setting("display/window/handheld/orientation", -1)) == 4)
	check("hang_up_probe_no_save", not XHangUp.current_active() or XState.current != null)

	XPlatform.force_mobile = null
	platform.queue_free()
	rec.queue_free()
	await frames()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
