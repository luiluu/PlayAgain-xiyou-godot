extends Node
## 跨平台二期（cc BH 2026-11-05）：XPlatform 两指取消、返回键、切后台补跑（O-201 开与关）、XTouchControls 虚拟按键，
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

class FakeScene extends Node:
	var on_title := true
	func is_title_page() -> bool:
		return on_title

func fake(path: String) -> FakeScene:
	var s := FakeScene.new()
	s.scene_file_path = path
	return s

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
	# 顶层按返回（O-202）：第一次提示、两秒内再按退出；发行包跳过入口菜单时西游标题页也是顶层
	platform.quit_on_back = false
	var quits := [0]
	platform.quit_requested.connect(func(): quits[0] += 1)
	var title := fake(XPlatform.XIYOU_TITLE)
	var menu := fake("res://scenes/entry_menu.tscn")
	var saved_release := ReleaseEntry.simulate_release
	ReleaseEntry.simulate_release = false
	check("debug_title_back_is_cancel", platform.go_back(1000, title) == "cancel" and quits[0] == 0)
	check("menu_back_twice_quits", platform.go_back(1000, menu) == "hint" and platform.hint_text() != ""
		and platform.go_back(2500, menu) == "quit" and quits[0] == 1)
	ReleaseEntry.simulate_release = true
	check("release_title_is_top", platform.is_top_level(title) and not platform.is_top_level(fake("res://modes/xiyou/map/map_scene.tscn")))
	check("release_title_back_hint", platform.go_back(10000, title) == "hint" and platform.hint_text().contains("再按一次") and quits[0] == 1)
	check("release_title_back_twice_quits", platform.go_back(11500, title) == "quit" and quits[0] == 2)
	check("release_title_slow_second_press_hints_again", platform.go_back(20000, title) == "hint" and platform.go_back(23000, title) == "hint" and quits[0] == 2)
	title.on_title = false
	check("release_title_subpage_is_cancel", platform.go_back(23500, title) == "cancel" and quits[0] == 2)
	title.on_title = true
	ReleaseEntry.direct_title = false
	check("release_with_menu_title_not_top", platform.go_back(30000, title) == "cancel")
	ReleaseEntry.direct_title = true
	XPlatform.BACK_EXIT_ON_TOP = false
	check("back_exit_off_is_cancel", platform.go_back(40000, title) == "cancel" and platform.go_back(40500, title) == "cancel" and quits[0] == 2)
	XPlatform.BACK_EXIT_ON_TOP = true
	ReleaseEntry.simulate_release = saved_release
	title.free()
	menu.free()

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
	# O-201 回退：关掉后台挂机就不补跑
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

	# 三期：大小／透明度／位置（原版 limits、步长 5）、安全区
	XTouchControls.instance = pad
	pad.name = "TouchControls"
	check("layout_default_same", pad.rects.ok == XTouchControls.BUTTONS.ok.rect and pad.rects.hide == XTouchControls.BUTTONS.hide.rect
		and pad.stick_center == XTouchControls.STICK_CENTER and pad.stick_radius == XTouchControls.STICK_RADIUS, [pad.rects, pad.stick_center])
	pad.set_value("buttons", 150)
	var actions: Rect2 = pad.group_rects.actions
	check("buttons_scale_keep_corner", pad.rects.ok.size.is_equal_approx(Vector2(165, 108)) and actions.end.is_equal_approx(Vector2(1260, 704)), [pad.rects.ok, actions])
	pad.set_value("buttons", 999)
	pad.set_value("stick", 123)
	pad.set_value("transparency", 40)
	check("value_limits", pad.settings.buttons == 160 and pad.settings.stick == 125 and is_equal_approx(pad.root.modulate.a, 0.6), pad.settings)
	pad.set_value("stick", 150)
	check("stick_scale", is_equal_approx(pad.stick_radius, 108.0) and pad.hit(pad.stick_center + Vector2(120, 0)) == "stick"
		and is_equal_approx(pad.group_rects.movement.position.x, 24.0) and is_equal_approx(pad.group_rects.movement.end.y, 696.0), pad.group_rects.movement)
	touch(0, pad.stick_center + Vector2(0, -60), true)
	await frames(1)
	check("stick_scaled_dir", Input.is_action_pressed("ui_up"))
	touch(0, pad.stick_center + Vector2(0, -60), false)
	await frames(1)
	var pad3 := XTouchControls.new()
	platform.add_child(pad3)
	await frames(1)
	check("sizes_remembered", pad3.settings.stick == 150 and pad3.settings.buttons == 160 and pad3.settings.transparency == 40, pad3.settings)
	pad3.queue_free()
	await frames(1)
	XTouchControls.instance = pad
	pad.set_insets([60.0, 0.0, 80.0, 30.0])
	check("insets_push_defaults", is_equal_approx(pad.group_rects.movement.position.x, 60.0) and is_equal_approx(pad.group_rects.movement.end.y, 690.0)
		and is_equal_approx(pad.group_rects.actions.end.x, 1200.0) and is_equal_approx(pad.group_rects.top.end.x, 1200.0)
		and is_equal_approx(pad.group_rects.top.position.y, 8.0), pad.group_rects)
	# 调整位置：拖 movement 到右上角之外，限制在安全区内
	pad.start_layout()
	check("layout_shows_all", pad.layout_editing and is_equal_approx(pad.root.modulate.a, 1.0) and pad.hit(pad.rects.ok.get_center()) == "ok")
	var grab: Vector2 = pad.group_rects.movement.get_center()
	touch(0, grab, true)
	var mv := InputEventScreenDrag.new()
	mv.index = 0
	mv.position = to_window(Vector2(1270, 5))
	Input.parse_input_event(mv)
	touch(0, Vector2(1270, 5), false)
	await frames(2)
	var moved: Rect2 = pad.group_rects.movement
	check("layout_drag_clamped", pad.positions.has("movement") and is_equal_approx(moved.end.x, 1280.0 - 12.0 - 80.0) and is_equal_approx(moved.position.y, 6.0)
		and not Input.is_action_pressed("ui_up") and not Input.is_action_pressed("ui_right"), [moved, pad.positions])
	check("back_finishes_layout", platform.go_back(999_999_000) == "layout" and not pad.layout_editing and is_equal_approx(pad.root.modulate.a, 0.6))
	var pad4 := XTouchControls.new()
	platform.add_child(pad4)
	await frames(1)
	pad4.set_insets([60.0, 0.0, 80.0, 30.0])
	check("position_remembered", pad4.group_rects.movement.is_equal_approx(moved), [pad4.group_rects.movement, moved])
	pad4.queue_free()
	await frames(1)
	XTouchControls.instance = pad
	pad.set_insets([0.0, 0.0, 0.0, 0.0])
	pad.reset_defaults()
	check("reset_defaults", pad.rects.ok == XTouchControls.BUTTONS.ok.rect and pad.stick_center == XTouchControls.STICK_CENTER
		and pad.positions.is_empty() and is_equal_approx(pad.root.modulate.a, 1.0))
	# 安全区换算：64×64 无头窗口里画面是 64×36（上下各 14 黑边），左右各缩进 4 像素＝画面 80
	XPlatform.safe_area_override = Rect2i(4, 0, 56, 64)
	var ins := XPlatform.safe_insets(get_viewport())
	XPlatform.safe_area_override = Rect2i()
	check("safe_insets_canvas", is_equal_approx(ins[0], 80.0) and is_equal_approx(ins[2], 80.0) and ins[1] == 0.0 and ins[3] == 0.0, ins)
	check("safe_insets_none", XPlatform.safe_insets(get_viewport()) == [0.0, 0.0, 0.0, 0.0])
	# 设置页：触屏时设置列表末尾有「手机按键设置」，页里改大小、开关显示
	var opts := XOptionsScene.new()
	add_child(opts)
	await frames(1)
	var syms := opts.symbols()
	check("options_touch_row", syms[-1] == "codexAndroidControls" and opts.status_text(syms.size() - 1) == "调整", syms.slice(-3))
	opts.queue_free()
	XPlatform.force_mobile = false
	var opts2 := XOptionsScene.new()
	add_child(opts2)
	await frames(1)
	check("options_no_touch_row", not opts2.symbols().has("codexAndroidControls"))
	opts2.queue_free()
	XPlatform.force_mobile = true
	var page := XTouchOptionsScene.new()
	add_child(page)
	await frames(1)
	page.index = 1
	page.side(true)
	page.index = 0
	page.ok()
	check("touch_page_edits", pad.settings.stick == 105 and pad.hidden and page.status_text(0) == "关" and page.status_text(1) == "105%")
	page.index = 4
	page.side(false)
	check("touch_page_floor", pad.settings.transparency == 0)
	page.index = 6
	page.ok()
	check("touch_page_reset", not pad.hidden and pad.settings.stick == 100)
	page.queue_free()
	DirAccess.remove_absolute(XTouchControls.SETTINGS_PATH)

	# 存档导出导入（原版二合一包 exportSave／prepareJSONImport 的做法）
	var save_dir := "user://test_xiyou_platform_saves"
	var saved_dir := XSave.dir_override
	XSave.dir_override = save_dir
	DirAccess.make_dir_recursive_absolute(save_dir)
	for f in DirAccess.get_files_at(save_dir):
		DirAccess.remove_absolute(save_dir.path_join(f))
	var saved_state = XState.current
	XState.new_game_blank()
	check("transfer_make_save", XSave.save(1))
	var out := XSaveTransfer.export_text(1)
	var wrapped = JSON.parse_string(str(out.get("text", "")))
	check("transfer_export", wrapped is Dictionary and wrapped.format == XSaveTransfer.FORMAT and int(wrapped.slot) == 1
		and XSave.valid_data(wrapped.data), out.get("error"))
	check("transfer_export_empty", XSaveTransfer.export_text(3).has("error"))
	var file := save_dir.path_join("exported.json")
	var picked := []
	XSaveTransfer.dialog_override = func(mode, filename, done):
		picked.append([mode, filename])
		done.call(true, PackedStringArray([file]), 0)
	XSaveTransfer.pick(true, XSaveTransfer.file_name(1), func(path): picked.append(XSaveTransfer.write_file(path, out.text)))
	check("transfer_pick_save", picked.size() == 2 and picked[0][0] == DisplayServer.FILE_DIALOG_MODE_SAVE_FILE and picked[1] == ""
		and str(picked[0][1]).begins_with("再刷重制存档01_") and FileAccess.file_exists(file), picked)
	XSaveTransfer.dialog_override = func(_mode, _filename, done): done.call(false, PackedStringArray(), 0)
	var cancelled := ["unset"]
	XSaveTransfer.pick(false, "", func(path): cancelled[0] = path)
	check("transfer_pick_cancel", cancelled[0] == "")
	XSaveTransfer.dialog_override = Callable()
	var got := XSaveTransfer.read_import(file)
	check("transfer_read_back", got.has("data") and JSON.stringify(got.data) == JSON.stringify(wrapped.data), got.get("error"))
	check("transfer_bare_save_ok", XSaveTransfer.parse_import(FileAccess.get_file_as_string(XSave.path(1))).has("data"))
	var mv_err := str(XSaveTransfer.parse_import(JSON.stringify({"format": "kyo-save-json-v1", "game": "org.kyo.xiyou", "data": {}})).get("error", ""))
	check("transfer_rejects_mv", mv_err.contains("原版"), mv_err)
	check("transfer_rejects_junk", XSaveTransfer.parse_import("not json").has("error") and XSaveTransfer.parse_import("{\"format\":\"x\"}").has("error")
		and XSaveTransfer.parse_import(JSON.stringify({"format": XSaveTransfer.FORMAT, "game": XSaveTransfer.GAME, "data": {"mode": "xiyou"}})).has("error"))
	check("transfer_import_empty_slot", XSaveTransfer.import_to(2, got.data) == "" and XSave.exists(2) and XSave.summary(2) != "存档 2：无法读取")
	var before_files := DirAccess.get_files_at(save_dir).size()
	var old_text := FileAccess.get_file_as_string(XSave.path(1))
	var import_ok := XSaveTransfer.import_to(1, got.data) == ""
	var kept := false
	for f in DirAccess.get_files_at(save_dir):
		if f.begins_with("save_1.json.before_import_") and FileAccess.get_file_as_string(save_dir.path_join(f)) == old_text:
			kept = true
	check("transfer_import_backs_up", import_ok and kept and DirAccess.get_files_at(save_dir).size() == before_files + 1)
	# 标题页：触屏时右上有两个按钮；导入走「选文件 → 选存档位」
	var title_page: Control = load("res://modes/xiyou/entry.tscn").instantiate()
	add_child(title_page)
	await frames(1)
	var import_btn := title_page.find_child("ImportSave", true, false) as Button
	check("title_transfer_buttons", import_btn != null and title_page.find_child("ExportSave", true, false) != null)
	XSaveTransfer.dialog_override = func(_mode, _filename, done): done.call(true, PackedStringArray([file]), 0)
	if import_btn != null:
		import_btn.pressed.emit()
	await frames(1)
	var slot_btn: Button = null
	for b in title_page.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("存档 3："):
			slot_btn = b
	check("title_import_slot_page", slot_btn != null and not title_page.is_title_page())
	if slot_btn != null:
		slot_btn.pressed.emit()
	await frames(1)
	check("title_import_done", XSave.exists(3))
	XSaveTransfer.dialog_override = Callable()
	title_page.queue_free()
	await frames(1)
	check("transfer_bad_slot", XSaveTransfer.import_to(0, got.data) != "" and XSaveTransfer.import_to(XSave.SLOTS + 1, got.data) != "")
	for f in DirAccess.get_files_at(save_dir):
		DirAccess.remove_absolute(save_dir.path_join(f))
	DirAccess.remove_absolute(save_dir)
	XSave.dir_override = saved_dir
	XState.current = saved_state

	# 设置：发行版存档目录去掉「_开发」（O-200），横屏
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
