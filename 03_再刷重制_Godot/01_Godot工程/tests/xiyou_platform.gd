extends Node
## 跨平台二期（cc BH 2026-11-05）：XPlatform 两指取消、返回键、切后台补跑（O-201 开与关）、XTouchControls 虚拟按键，
## 发行版存档目录与横屏设置。桌面上用 XPlatform.force_mobile 当成手机测，不依赖测试机平台。
var results := []

## 后台挂机插件替身（android-bgidle1）：方法名同安卓插件 XiyouBgIdle
class FakeBgIdle extends RefCounted:
	var armed := false
	var away := -1
	var stopped := false
	var asked := 0
	func setArmed(on: bool) -> void:
		armed = on
	func lastAwayMsec() -> int:
		return away
	func lastStoppedByUser() -> bool:
		return stopped
	func requestNotificationPermission() -> bool:
		asked += 1
		return true

class Recorder extends Node:
	var right_clicks := 0
	var cancels := 0
	var accepts := 0
	var page_downs := 0
	var page_ups := 0
	var unhandled_touches := 0
	var unhandled_left := 0
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			right_clicks += 1
		if event.is_action_pressed("ui_cancel"):
			cancels += 1
		if event.is_action_pressed("ui_accept"):
			accepts += 1
		# 审查 66 P3-4：页面真收到的翻页事件（_input 里认 is_action_pressed，同各页）
		if event.is_action_pressed("ui_page_down"):
			page_downs += 1
		if event.is_action_pressed("ui_page_up"):
			page_ups += 1
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			unhandled_touches += 1
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			unhandled_left += 1

class FakeScene extends Node:
	var on_title := true
	func is_title_page() -> bool:
		return on_title

## 当成地图页（XMapScene.touch_save_visible）：存档键只在地图与主菜单显示（fix1）
class FakeMap extends Node:
	var allow := true
	func touch_save_visible() -> bool:
		return allow

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

## Kyo 11-12「把那个没装的虚拟按键定为默认按键」：原版虚拟按钮（Mehmet_GhostButtons）当默认，另可切改版按键（A／B、原多键、方向键、跑步键）
func _touch_styles(platform: XPlatform, rec: Recorder) -> void:
	DirAccess.remove_absolute(XTouchControls.SETTINGS_PATH)
	XTouchControls.knob_character_override = ["1-XiaoMing", 0]
	var g := XTouchControls.new()
	platform.add_child(g)
	await frames(2)
	check("ghost_default", g.ghost() and g.settings.style == "original" and not g.settings.battle_touch and g.settings.map_touch, g.settings)
	check("ghost_geometry", g.rects.ok.get_center().is_equal_approx(Vector2(1030, 520)) and g.rects.cancel.get_center().is_equal_approx(Vector2(1160, 410))
		and g.rects.ok.size.is_equal_approx(Vector2(120, 120)) and g.stick_center.is_equal_approx(Vector2(220, 540)) and is_equal_approx(g.stick_radius, 140.0),
		[g.rects.ok, g.rects.cancel, g.stick_center, g.stick_radius])
	var lab := (g._buttons.ok as Panel).get_node("Label") as Label
	check("ghost_look", lab.text == "A" and ((g._buttons.cancel as Panel).get_node("Label") as Label).text == "B"
		and lab.get_theme_color("font_color") == XTouchControls.GHOST_TEXT and g._ghost_base.visible and not g._stick_base.visible
		and is_equal_approx((g._buttons.ok as Panel).modulate.a, XTouchControls.GHOST_IDLE) and not g.active.has("run"), [lab.text, g.active])
	check("ghost_taps_default", not XTouchControls.battle_tap_allowed() and XTouchControls.map_tap_allowed())
	var accepts := rec.accepts
	touch(0, g.rects.ok.get_center(), true)
	await frames(2)
	check("ghost_a_accepts", rec.accepts == accepts + 1 and is_equal_approx((g._buttons.ok as Panel).modulate.a, 1.0), [rec.accepts, accepts])
	touch(0, g.rects.ok.get_center(), false)
	for i in 70:
		await get_tree().physics_frame
	check("ghost_fades_back", is_equal_approx((g._buttons.ok as Panel).modulate.a, XTouchControls.GHOST_IDLE), (g._buttons.ok as Panel).modulate.a)
	touch(0, g.stick_center, true)
	var dr := InputEventScreenDrag.new()
	dr.index = 0
	dr.position = to_window(g.stick_center + Vector2(-80, 10))
	Input.parse_input_event(dr)
	await frames(2)
	check("ghost_stick_left", Input.is_action_pressed("ui_left") and g._ghost_knob.position.x < g.stick_center.x - XTouchControls.GHOST_KNOB - 10, g._ghost_knob.position)
	touch(0, g.stick_center, false)
	await frames(2)
	check("ghost_stick_release", not Input.is_action_pressed("ui_left"))
	# 改版按键：A／B 两键（右下角贴边）
	g.set_choice("style", "modern")
	check("modern_ab", not g.ghost() and g.layout() == "ab" and g.rects.ok.size.is_equal_approx(Vector2(XTouchControls.AB_BUTTON, XTouchControls.AB_BUTTON))
		and g.group_rects.actions.end.is_equal_approx(Vector2(1260, 704)) and ((g._buttons.ok as Panel).get_node("Label") as Label).text == "A"
		and g._stick_base.visible and not g._ghost_base.visible, [g.rects.ok, g.group_rects.actions])
	# 原多键：前页＝ui_page_up
	g.set_choice("layout", "full")
	var ups := rec.page_ups
	check("modern_full_keys", g.active.has("pageup") and g.active.has("ctrl") and ((g._buttons.ok as Panel).get_node("Label") as Label).text == "确认", g.active)
	touch(0, g.rects.pageup.get_center(), true)
	await frames(2)
	touch(0, g.rects.pageup.get_center(), false)
	await frames(2)
	check("modern_full_pageup", rec.page_ups == ups + 1, [rec.page_ups, ups])
	# 方向键
	g.set_choice("mode", "buttons")
	check("modern_dpad", not g._uses_stick and g.hit(g.rects.left.get_center()) == "left" and g.hit(g.stick_center) != "stick", g.active)
	touch(0, g.rects.left.get_center(), true)
	await frames(2)
	check("dpad_left_press", Input.is_action_pressed("ui_left"))
	touch(0, g.rects.left.get_center(), false)
	await frames(2)
	check("dpad_left_release", not Input.is_action_pressed("ui_left"))
	# 跑步键（改版默认不显示）
	g.set_flag("show_run", true)
	check("modern_run_shown", g.active.has("run") and g.group_rects.movement.encloses(g.rects.run) and ((g._buttons.run as Panel).get_node("Label") as Label).text == "跑", [g.rects.run, g.group_rects.movement])
	touch(0, g.rects.run.get_center(), true)
	await frames(2)
	check("modern_run_shift", Input.is_physical_key_pressed(KEY_SHIFT))
	touch(0, g.rects.run.get_center(), false)
	await frames(2)
	g.set_flag("battle_touch", true)
	g.set_flag("map_touch", false)
	check("taps_flags", XTouchControls.battle_tap_allowed() and not XTouchControls.map_tap_allowed())
	var g2 := XTouchControls.new()
	g2._load()
	check("styles_remembered", g2.settings.style == "modern" and g2.settings.layout == "full" and g2.settings.mode == "buttons" and g2.settings.show_run
		and g2.settings.battle_touch and not g2.settings.map_touch, g2.settings)
	g2.free()
	# 设置页：原版虚拟按钮时改版专用行显示「—」、不能改
	var page := XTouchOptionsScene.new()
	add_child(page)
	await frames(1)
	var keys := XTouchOptionsScene.rows().map(func(r): return r[1])
	page.index = keys.find("style")
	check("page_style_modern", page.status_text(page.index) == "改版按键")
	page.side(false)
	check("page_style_original", g.ghost() and page.status_text(page.index) == "原版虚拟按钮")
	page.index = keys.find("layout")
	page.side(true)
	check("page_modern_only_locked", page.status_text(page.index) == "—" and g.layout() == "full")
	page.index = keys.find("battle_touch")
	page.ok()
	check("page_battle_touch", not g.settings.battle_touch and page.status_text(page.index) == "仅屏幕按键")
	page.queue_free()
	g.reset_defaults()
	check("reset_to_ghost", g.ghost() and g.layout() == "ab" and g.move_mode() == "joystick" and not g.settings.show_run)
	# 回退开关：默认回到 v0.01 旧三键、战斗点击开
	XTouchControls.MODERN_DEFAULT = false
	g.reset_defaults()
	check("rollback_classic", not g.ghost() and g.layout() == "classic" and g.rects.ok == XTouchControls.BUTTONS.ok.rect and g.settings.battle_touch)
	XTouchControls.MODERN_DEFAULT = true
	XTouchControls.knob_character_override = []
	g.queue_free()
	await frames(1)


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
	# Codex 报告第 6 项（平台 EH）：补跑自然耗尽要恢复倍速——旧代码先把剩余减到 0 以下、stop 又以「剩余>0」判断在补跑，直接返回，一直八倍速
	platform.start_catch_up(1.0)
	platform._process(2.0)
	check("catch_up_natural_end_restores", not platform.is_catching_up() and Engine.time_scale == 1.0
		and Engine.physics_ticks_per_second == 60 and Engine.max_physics_steps_per_frame == 8,
		[Engine.time_scale, Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame])
	# 自然耗尽后再补跑一次：存下的「原始设置」不能是八倍速
	platform.start_catch_up(1.0)
	platform._process(2.0)
	check("catch_up_twice_natural_end_restores", Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, [Engine.time_scale, Engine.physics_ticks_per_second])
	# 补跑中又补跑（续时）：不重存原始设置，停下回到 1 倍
	platform.start_catch_up(5.0)
	platform.start_catch_up(5.0)
	check("catch_up_repeat_extends", platform.is_catching_up() and is_equal_approx(platform.catch_up_left(), 5.0))
	platform._process(2.0)
	platform.stop_catch_up()
	check("catch_up_repeat_stop_restores", not platform.is_catching_up() and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, [Engine.time_scale])
	platform.stop_catch_up()
	check("catch_up_stop_twice_harmless", Engine.time_scale == 1.0)
	# 基准倍率不是 1（变速齿轮 1.6：96 帧、time_scale 1.6）：补跑按基准×8，耗尽后回到基准而不是 1 倍
	Engine.physics_ticks_per_second = 96
	Engine.time_scale = 1.6
	platform.start_catch_up(1.0)
	check("catch_up_relative_to_base", Engine.physics_ticks_per_second == 96 * XPlatform.CATCH_UP_SPEED
		and is_equal_approx(Engine.time_scale, 1.6 * XPlatform.CATCH_UP_SPEED), [Engine.physics_ticks_per_second, Engine.time_scale])
	# 补跑按平常速度的秒数扣：齿轮 1.6 下一帧 delta＝1.6×8＝12.8，只算 8 秒（以前扣 12.8，开齿轮只补离开时长的 1/1.6）
	platform.start_catch_up(10.0)
	platform._process(1.6 * XPlatform.CATCH_UP_SPEED)
	check("catch_up_counts_base_seconds", platform.is_catching_up() and is_equal_approx(platform.catch_up_left(), 10.0 - XPlatform.CATCH_UP_SPEED), platform.catch_up_left())
	platform._process(20.0)
	check("catch_up_restores_base_gear", not platform.is_catching_up() and Engine.physics_ticks_per_second == 96
		and is_equal_approx(Engine.time_scale, 1.6) and Engine.max_physics_steps_per_frame == 8, [Engine.physics_ticks_per_second, Engine.time_scale])
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	# O-201 回退：关掉后台挂机就不补跑
	XPlatform.BACKGROUND_IDLE = false
	platform.on_paused(0)
	check("background_idle_off", platform.on_resumed(60_000) == 0.0 and not platform.is_catching_up())
	XPlatform.BACKGROUND_IDLE = true
	# 后台挂机前台服务（O-248，android-bgidle1）：插件替身
	var fake := FakeBgIdle.new()
	var saved_stopper := XPlatform.idle_stopper
	var stops := [0]
	XPlatform.idle_stopper = func(): stops[0] += 1
	XPlatform.bg_service_override = fake
	idle[0] = true
	platform._process(0.0)
	check("service_armed_when_idle", fake.armed and platform.service_armed() and fake.asked == 1, [fake.armed, fake.asked])
	idle[0] = false
	platform._process(0.0)
	check("service_disarmed_when_idle_ends", not fake.armed and not platform.service_armed())
	idle[0] = true
	platform._process(0.0)
	check("notify_permission_asked_once", fake.armed and fake.asked == 1, fake.asked)
	# 服务陪着离开 2 小时：用插件量的真实时间（游戏计时只走了 1 秒），不受 O-201 的 30 分钟上限
	fake.away = 7_200_000
	platform.on_paused(0)
	var svc_secs := platform.on_resumed(1000)
	check("service_away_real_time", is_equal_approx(svc_secs, 7200.0) and platform.is_catching_up(), svc_secs)
	platform.stop_catch_up()
	check("service_no_stop_without_button", stops[0] == 0 and not platform.is_catching_up())
	fake.away = 72_000_000
	platform.on_paused(0)
	check("service_capped", is_equal_approx(platform.on_resumed(1000), XPlatform.SERVICE_CAP_SEC))
	platform.stop_catch_up()
	# 通知上按了停止：只补到按的那一刻（插件给的时长），补完结束挂机
	fake.away = 600_000
	fake.stopped = true
	platform.on_paused(0)
	check("service_stopped_counts_until_stop", is_equal_approx(platform.on_resumed(1000), 600.0) and stops[0] == 0)
	platform._process(700.0)
	check("service_stopped_ends_idle_after_catch_up", not platform.is_catching_up() and stops[0] == 1, stops[0])
	# 点屏幕提前停补跑也结束挂机
	platform.on_paused(0)
	platform.on_resumed(1000)
	platform.stop_catch_up()
	check("service_stopped_tap_ends_idle", stops[0] == 2, stops[0])
	# 按了停止、离开不到 5 秒：不补跑，直接结束挂机
	fake.away = 2000
	platform.on_paused(0)
	check("service_stopped_short_away", platform.on_resumed(1000) == 0.0 and stops[0] == 3 and not platform.is_catching_up(), stops[0])
	fake.stopped = false
	# 这次没起服务（插件给 -1）：退回 O-201 的游戏计时和 30 分钟上限
	fake.away = -1
	platform.on_paused(0)
	check("service_missing_falls_back", is_equal_approx(platform.on_resumed(10_000_000), XPlatform.BACKGROUND_CAP_SEC))
	platform.stop_catch_up()
	# 回退：关掉前台服务就不起服务，插件给的时长也不用
	XPlatform.BACKGROUND_SERVICE = false
	platform._process(0.0)
	fake.away = 7_200_000
	platform.on_paused(0)
	var off_secs := platform.on_resumed(60_000)
	check("background_service_off", not fake.armed and not platform.service_armed() and is_equal_approx(off_secs, 60.0), [fake.armed, off_secs])
	platform.stop_catch_up()
	XPlatform.BACKGROUND_SERVICE = true
	XPlatform.bg_service_override = null
	platform._process(0.0)
	check("service_none_on_desktop", platform.bg_service() == null and not platform.service_armed())
	XPlatform.idle_stopper = saved_stopper
	XPlatform.idle_probe = saved_probe

	# 虚拟按键（这一段量的是 v0.01 的旧三键：回退开关关掉原版虚拟按钮默认；原版／改版按键在后面 _touch_styles 量）
	XTouchControls.SETTINGS_PATH = "user://test_xiyou_platform_touch.json"
	DirAccess.remove_absolute(XTouchControls.SETTINGS_PATH)
	XTouchControls.MODERN_DEFAULT = false
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
	# 按住确定不连发（审查报告第 13 项，O-225；方向的回显连发见 xiyou_ui_input）
	accepts = rec.accepts
	touch(0, ok_center, true)
	for i in 40:
		await get_tree().physics_frame
	check("hold_ok_no_repeat", rec.accepts == accepts + 1, [rec.accepts, accepts])
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
	await frames(2)
	# 摇杆拖动翻页（ui6）：推深（≥65%）按满 36 帧翻第一页，之后每 24 帧一页；推浅不翻；设置关掉不翻
	var p0 := pad.pages_sent
	var d0 := rec.page_downs
	var u0 := rec.page_ups
	touch(0, XTouchControls.STICK_CENTER, true)
	var deep := InputEventScreenDrag.new()
	deep.index = 0
	deep.position = to_window(XTouchControls.STICK_CENTER + Vector2(60, 0))
	Input.parse_input_event(deep)
	for i in 30:
		await get_tree().physics_frame
	check("stick_page_waits", pad.pages_sent == p0 and pad._held.has("ui_right") and rec.page_downs == d0, [pad.pages_sent, p0, rec.page_downs, d0])
	for i in 40:
		await get_tree().physics_frame
	check("stick_page_every_24", pad.pages_sent == p0 + 2, [pad.pages_sent, p0])
	# 端到端：每次发出都被页面接到（向右＝ui_page_down，不会误出 ui_page_up）
	check("stick_page_reaches_pages", rec.page_downs == d0 + 2 and rec.page_ups == u0, [rec.page_downs, d0, rec.page_ups, u0])
	check("stick_page_stops_lr_echo", not pad._held.has("ui_right") and Input.is_action_pressed("ui_right"))
	touch(0, XTouchControls.STICK_CENTER, false)
	await frames(2)
	check("stick_page_release", not Input.is_action_pressed("ui_right"))
	p0 = pad.pages_sent
	d0 = rec.page_downs
	u0 = rec.page_ups
	touch(0, XTouchControls.STICK_CENTER, true)
	var shallow := InputEventScreenDrag.new()
	shallow.index = 0
	shallow.position = to_window(XTouchControls.STICK_CENTER + Vector2(-40, 0))
	Input.parse_input_event(shallow)
	for i in 80:
		await get_tree().physics_frame
	check("stick_page_shallow_no", pad.pages_sent == p0 and Input.is_action_pressed("ui_left") and rec.page_downs == d0 and rec.page_ups == u0, [pad.pages_sent, rec.page_downs, rec.page_ups])
	touch(0, XTouchControls.STICK_CENTER, false)
	await frames(2)
	# 按住满 24 帧发过方向回显再松手，方向要真松开（Godot 把回显记成键盘设备按着；ui6 修，地图上人物会一直走）
	check("stick_echo_then_release", not Input.is_action_pressed("ui_left") and not Input.is_physical_key_pressed(KEY_LEFT))
	pad.set_stick_page(false)
	touch(0, XTouchControls.STICK_CENTER, true)
	Input.parse_input_event(deep)
	for i in 80:
		await get_tree().physics_frame
	check("stick_page_setting_off", pad.pages_sent == p0 and rec.page_downs == d0, [pad.pages_sent, rec.page_downs, d0])
	touch(0, XTouchControls.STICK_CENTER, false)
	await frames(2)
	pad.set_stick_page(true)
	# 跑步键按住＝Shift
	var run_center: Vector2 = (XTouchControls.BUTTONS.run.rect as Rect2).get_center()
	touch(0, run_center, true)
	await frames(2)
	check("run_holds_shift", Input.is_physical_key_pressed(KEY_SHIFT))
	touch(0, run_center, false)
	await frames(2)
	check("run_releases_shift", not Input.is_physical_key_pressed(KEY_SHIFT))
	# 存档键＝键盘 ~（Mehmet_GhostButtons 的 Save，一键存档公共事件 428）
	var save_center: Vector2 = (XTouchControls.BUTTONS.save.rect as Rect2).get_center()
	# 照原版只在地图与主菜单（[Scene_Map, Scene_Menu]）：别的页面不显示、不吃触摸（fix1）
	var not_map := fake(XPlatform.XIYOU_TITLE)
	XTouchControls.scene_override = not_map
	await frames(1)
	check("save_hidden_off_map", pad.hit(save_center) == "" and not (pad._buttons.save as Panel).visible, pad.hit(save_center))
	var fake_map := FakeMap.new()
	XTouchControls.scene_override = fake_map
	await frames(1)
	check("save_shown_on_map", pad.hit(save_center) == "save" and (pad._buttons.save as Panel).visible)
	fake_map.allow = false
	await frames(1)
	check("save_hidden_in_battle_or_subpage", pad.hit(save_center) == "" and not (pad._buttons.save as Panel).visible)
	XTouchControls.SAVE_MAP_MENU_ONLY = false
	XTouchControls.scene_override = not_map
	check("save_rollback_all_pages", pad.hit(save_center) == "save")
	XTouchControls.SAVE_MAP_MENU_ONLY = true
	fake_map.allow = true
	XTouchControls.scene_override = fake_map
	await frames(1)
	touch(0, save_center, true)
	await frames(2)
	check("save_holds_tilde", Input.is_physical_key_pressed(KEY_QUOTELEFT))
	touch(0, save_center, false)
	await frames(2)
	check("save_releases_tilde", not Input.is_physical_key_pressed(KEY_QUOTELEFT))
	XTouchControls.scene_override = null
	not_map.free()
	fake_map.free()
	# 安卓商店页存档键按了没反应（DH）：事件打开的商店、存档页、仓库等独立页面开着时，真地图页也不显示存档键
	var real_map := XMapScene.new()   # 不进树，_ready 不跑，只量 touch_save_visible 的判断
	real_map.ui = CanvasLayer.new()
	add_child(real_map.ui)
	check("map_save_shown_plain", real_map.touch_save_visible())
	var shop_page := Control.new()
	real_map._add_scene_page(shop_page)
	check("map_save_hidden_scene_page", not real_map.touch_save_visible() and real_map.scene_page_open())
	XTouchControls.scene_override = real_map
	await frames(1)
	check("map_save_pad_hidden_scene_page", pad.hit(save_center) == "" and not (pad._buttons.save as Panel).visible, pad.hit(save_center))
	XMapScene.SCENE_PAGE_HIDES_SAVE = false
	check("map_save_rollback_scene_page", real_map.touch_save_visible())
	XMapScene.SCENE_PAGE_HIDES_SAVE = true
	shop_page.queue_free()
	check("map_save_back_after_close", real_map.touch_save_visible() and not real_map.scene_page_open())
	XTouchControls.scene_override = null
	await frames(1)
	real_map.ui.free()
	real_map.free()
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
	page.index = 5
	page.ok()
	check("touch_page_stick_page_off", not pad.stick_page_on() and page.status_text(5) == "关"
		and JSON.parse_string(FileAccess.get_file_as_string(XTouchControls.SETTINGS_PATH)).get("stick_page") == false)
	var pad_reload := XTouchControls.new()
	pad_reload._load()
	check("touch_page_stick_page_remembered", pad_reload.settings.stick_page == false)
	pad_reload.free()
	page.side(true)
	check("touch_page_stick_page_side", pad.stick_page_on() and page.status_text(5) == "开")
	page.side(false)
	XTouchControls.STICK_PAGE = false
	check("touch_page_rollback_hides_row", XTouchOptionsScene.rows().size() == XTouchOptionsScene.ROWS.size() - 1 and not pad.stick_page_on())
	XTouchControls.STICK_PAGE = true
	page.index = XTouchOptionsScene.rows().size() - 1
	page.ok()
	check("touch_page_reset", not pad.hidden and pad.settings.stick == 100 and pad.stick_page_on())
	page.queue_free()
	DirAccess.remove_absolute(XTouchControls.SETTINGS_PATH)
	XTouchControls.MODERN_DEFAULT = true
	await _touch_styles(platform, rec)
	XTouchControls.instance = pad
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
	# O-206 回退：BACKUP_BEFORE_IMPORT = false 时覆盖有档的格子不留 .before_import 备份（照样导入）
	XSaveTransfer.BACKUP_BEFORE_IMPORT = false
	var files_off := DirAccess.get_files_at(save_dir).size()
	var import_off := XSaveTransfer.import_to(1, got.data) == ""
	XSaveTransfer.BACKUP_BEFORE_IMPORT = true
	check("transfer_import_rollback_no_backup", import_off and XSave.exists(1) and DirAccess.get_files_at(save_dir).size() == files_off)
	# 标题页：触屏时右上有两个按钮；导入走「选文件 → 选存档位」
	var title_page: Control = load("res://modes/xiyou/entry.tscn").instantiate()
	add_child(title_page)
	await frames(1)
	var import_btn := title_page.find_child("ImportSave", true, false) as Button
	check("title_transfer_buttons", import_btn != null and title_page.find_child("ExportSave", true, false) != null)
	# 真触摸点按钮中心（审查 50 P2-1：存档键曾盖住「导出存档」）：按钮收到、存档键没收到 ~
	# 每个按钮用一个新标题页（按下去会换页，盖住另一个）
	title_page.queue_free()
	await frames(1)
	var title_hits := {}
	for n in ["ExportSave", "ImportSave"]:
		var tp: Control = load("res://modes/xiyou/entry.tscn").instantiate()
		add_child(tp)
		XTouchControls.scene_override = tp
		await frames(1)
		var btn := tp.find_child(n, true, false) as Button
		title_hits[n] = 0
		btn.pressed.connect(func(): title_hits[n] += 1)
		var c: Vector2 = btn.get_global_rect().get_center()
		emulated_click(c, true)
		touch(0, c, true)
		await frames(1)
		check("title_touch_no_tilde_" + n, not Input.is_physical_key_pressed(KEY_QUOTELEFT) and pad.hit(c) == "")
		emulated_click(c, false)
		touch(0, c, false)
		await frames(1)
		tp.queue_free()
		await frames(1)
	check("title_touch_export_pressed", title_hits.ExportSave == 1, title_hits)
	check("title_touch_import_pressed", title_hits.ImportSave == 1, title_hits)
	# 刘海机：右缩进 80 把「隐藏按键」推到左边，标题两个按钮跟着往左让，不重叠
	pad.set_insets([0.0, 0.0, 80.0, 0.0])
	var notch_page: Control = load("res://modes/xiyou/entry.tscn").instantiate()
	add_child(notch_page)
	await frames(1)
	var notch_ok := true
	for n in ["ImportSave", "ExportSave"]:
		var r := (notch_page.find_child(n, true, false) as Button).get_global_rect()
		notch_ok = notch_ok and not r.intersects(pad.rects.hide) and pad.hit(r.get_center()) == ""
	check("title_buttons_clear_notch", notch_ok, [pad.rects.hide, (notch_page.find_child("ExportSave", true, false) as Button).get_global_rect()])
	notch_page.queue_free()
	pad.set_insets([0.0, 0.0, 0.0, 0.0])
	XTouchControls.scene_override = null
	title_page = load("res://modes/xiyou/entry.tscn").instantiate()
	add_child(title_page)
	await frames(1)
	import_btn = title_page.find_child("ImportSave", true, false) as Button
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
