extends Node
## 【cc·T336·未经审查】界面细节 D1a 底层（私密仓 重制设定/界面细节规范_v0.1.md 第五节卡 D1a）：
## 1. TianqiUiNum-Medium.ttf 经 _make_tabular 后 0 与 1 字宽相等（不开时不等，证明断言咬得住）；三字体模式下 font("num") 开 tnum、DETAIL_V1 关回原字；
## 2. TianqiUiSerif-Heavy.otf 经逐位定宽：「111」「777」「888」总宽相等、每位在格内居中；格宽＝0–9 最大字宽（T329 r2 P3-6）；
## 3. 输入模式：键盘／手柄（含摇杆死区）／真鼠标（含移动阈值）／DEVICE_ID_EMULATION 触屏、屏幕触摸下 show_focus_ring() 对；全局监听节点挂上；
## 4. DETAIL_V1＝false：无头下开关与 font("num") 回退（窗口逐像素与样稿已由 T349 D1b 接线后改在 xiyou_ui_detail_d1b）；
## 另：双环几何（内黑贴外缘 0～2px、外淡金 2～4px，紧凑控件同样 2px／4px，P3-7）、色阶、基线与行内图标出口。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const NUM_FONT := "res://content/ui_skin/fonts/TianqiUiNum-Medium.ttf"
const SERIF_FONT := "res://content/ui_skin/fonts/TianqiUiSerif-Heavy.otf"
const SHOT := Vector2i(1280, 720)

var results: Array = []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_d1a")
	get_viewport().gui_disable_input = windowed()
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XUiSkin._clock_ms = 100000
	XFontScale.set_value("global", 100)
	_tabular()
	_mono_digits()
	await _input_mode()
	_detail_switch_headless()
	_focus_geometry()
	_surfaces_and_baseline()
	# T349 D1b 已把双环／S3／12px 接进正式件：D1a 的「现有页面开关前后逐像素相同」与「改前｜改后样稿」两段窗口断言前提不再成立，
	# 改由 xiyou_ui_detail_d1b 的窗口断言接手（原样稿画法已删，样稿图存档在 协作交接/附图/T336）。
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XUiSkin._clock_ms = -1
	XUiSkin.input_mode = -1
	XUiSkin.touch_override = -1
	XUiSkin.DETAIL_V1 = true
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _w(f: Font, s: String, fs: int) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


# ---- 单测 1：tnum ----
func _tabular() -> void:
	var raw := load(NUM_FONT) as Font
	if not check("num_font_exists", raw != null):
		return
	var fs := 40
	check("num_raw_proportional", absf(_w(raw, "0", fs) - _w(raw, "1", fs)) > 0.5, [_w(raw, "0", fs), _w(raw, "1", fs)])
	var tab := XUiSkin._make_tabular(raw)
	var w0 := _w(tab, "0", fs)
	var widths := []
	for d in 10:
		widths.append(_w(tab, str(d), fs))
	check("num_tabular_0_eq_1", is_equal_approx(w0, _w(tab, "1", fs)), widths)
	check("num_tabular_all_digits", widths.all(func(w): return is_equal_approx(w, w0)), widths)
	check("num_tabular_457", absf(w0 - 0.457 * fs) < 0.6, [w0, 0.457 * fs])
	# font("num")：默认 FONT_V00300 恒 GameFont；三字体模式开 tnum，DETAIL_V1 关回原 FontFile
	check("font_num_default_gamefont", XUiSkin.font("num") == GameFont.current())
	XUiSkin.FONT_V00300 = false
	XUiSkin._fonts.clear()
	var fv := XUiSkin.font("num")
	check("font_num_tabular_variation", fv is FontVariation and is_equal_approx(_w(fv, "0", fs), _w(fv, "1", fs)), [fv, _w(fv, "0", fs), _w(fv, "1", fs)])
	XUiSkin.DETAIL_V1 = false
	var ff := XUiSkin.font("num")
	check("font_num_off_is_file", ff is FontFile and not is_equal_approx(_w(ff, "0", fs), _w(ff, "1", fs)), [ff])
	check("font_body_untouched", XUiSkin.font("body") is FontFile)
	XUiSkin.DETAIL_V1 = true
	XUiSkin.FONT_V00300 = true
	XUiSkin._fonts.clear()


# ---- 单测 2：宋体 Heavy 逐位定宽 ----
func _mono_digits() -> void:
	var f := load(SERIF_FONT) as Font
	if not check("serif_font_exists", f != null):
		return
	for fs in [34, 40, 50]:
		check("serif_raw_1_narrow_%d" % fs, _w(f, "1", fs) < _w(f, "0", fs) - 1.0, [_w(f, "1", fs), _w(f, "0", fs)])
		var cell := XUiSkin.mono_digit_cell(f, fs)
		var mx := 0.0
		for d in 10:
			mx = maxf(mx, _w(f, str(d), fs))
		check("serif_cell_max_0_9_%d" % fs, is_equal_approx(cell, mx), [cell, mx])
		var w111 := XUiSkin.mono_digits_width(f, "111", fs)
		var w777 := XUiSkin.mono_digits_width(f, "777", fs)
		var w888 := XUiSkin.mono_digits_width(f, "888", fs)
		check("serif_equal_width_%d" % fs, is_equal_approx(w111, w777) and is_equal_approx(w777, w888) and is_equal_approx(w888, cell * 3.0), [w111, w777, w888, cell])
		var centered := true
		for t in ["111", "777", "888", "1789"]:
			var slots := XUiSkin.mono_digit_slots(f, t, fs)
			for i in slots.size():
				var sl: Array = slots[i]
				var mid := float(sl[1]) + float(sl[2]) * 0.5
				if absf(mid - (i + 0.5) * cell) > 0.01:
					centered = false
		check("serif_digit_centered_%d" % fs, centered)
	# 非数字按自身宽（「+」「,」不占数字格）
	var slots2 := XUiSkin.mono_digit_slots(f, "+1,2", 40)
	check("serif_nondigit_own_width", is_equal_approx(float(slots2[0][3]), _w(f, "+", 40)) and is_equal_approx(float(slots2[2][3]), _w(f, ",", 40)), slots2)


# ---- 单测 3：输入模式 ----
func _key() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_RIGHT
	e.pressed = true
	return e


func _input_mode() -> void:
	XUiSkin.input_mode = -1
	XUiSkin.touch_override = 0
	check("mode_initial_keyboard", XUiSkin.current_input_mode() == XUiSkin.InputMode.KEYBOARD and XUiSkin.show_focus_ring())
	XUiSkin.touch_override = 1
	check("mode_initial_touch", XUiSkin.current_input_mode() == XUiSkin.InputMode.TOUCH and not XUiSkin.show_focus_ring())
	XUiSkin.touch_override = 0
	XUiSkin.note_input(_key())
	check("mode_key", XUiSkin.input_mode == XUiSkin.InputMode.KEYBOARD and XUiSkin.show_focus_ring())
	# 真鼠标：小幅移动不切，点一下切鼠标
	var mv := InputEventMouseMotion.new()
	mv.device = 0
	mv.relative = Vector2(2, 1)
	XUiSkin.note_input(mv)
	check("mode_mouse_jitter_ignored", XUiSkin.input_mode == XUiSkin.InputMode.KEYBOARD)
	mv.relative = Vector2(12, 3)
	XUiSkin.note_input(mv)
	check("mode_mouse_move", XUiSkin.input_mode == XUiSkin.InputMode.MOUSE and not XUiSkin.show_focus_ring())
	XUiSkin.note_input(_key())
	var mb := InputEventMouseButton.new()
	mb.device = 0
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	XUiSkin.note_input(mb)
	check("mode_mouse_click", XUiSkin.input_mode == XUiSkin.InputMode.MOUSE and not XUiSkin.show_focus_ring())
	# 手柄：摇杆死区内不切；按钮、推过死区切手柄
	var jm := InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_LEFT_X
	jm.axis_value = 0.2
	XUiSkin.note_input(jm)
	check("mode_joy_deadzone", XUiSkin.input_mode == XUiSkin.InputMode.MOUSE)
	jm.axis_value = -0.8
	XUiSkin.note_input(jm)
	check("mode_joy_axis", XUiSkin.input_mode == XUiSkin.InputMode.GAMEPAD and XUiSkin.show_focus_ring())
	XUiSkin.input_mode = XUiSkin.InputMode.MOUSE
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	jb.pressed = true
	XUiSkin.note_input(jb)
	check("mode_joy_button", XUiSkin.input_mode == XUiSkin.InputMode.GAMEPAD and XUiSkin.show_focus_ring())
	# 触屏模拟鼠标（DEVICE_ID_EMULATION）→ 触屏，不留环
	var em := InputEventMouseButton.new()
	em.device = InputEvent.DEVICE_ID_EMULATION
	em.button_index = MOUSE_BUTTON_LEFT
	em.pressed = true
	XUiSkin.note_input(em)
	check("mode_emulated_touch", XUiSkin.input_mode == XUiSkin.InputMode.TOUCH and not XUiSkin.show_focus_ring())
	XUiSkin.note_input(jb)
	var st := InputEventScreenTouch.new()
	st.pressed = true
	XUiSkin.note_input(st)
	check("mode_screen_touch", XUiSkin.input_mode == XUiSkin.InputMode.TOUCH and not XUiSkin.show_focus_ring())
	# 外接手柄按一下立刻亮环
	XUiSkin.note_input(jb)
	check("mode_touch_then_pad", XUiSkin.show_focus_ring())
	# 全局监听：真事件经 Input.parse_input_event 走到 _input
	await frames(2)
	check("tracker_attached", get_tree().root.get_node_or_null("XUiSkinInputTracker") != null)
	XUiSkin.input_mode = XUiSkin.InputMode.MOUSE
	Input.parse_input_event(_key())
	await frames(2)
	if not windowed():   # 有窗口时真鼠标在窗口上的移动也会进来，可能抢先改成 MOUSE；只在无头时断言
		check("tracker_sees_key", XUiSkin.input_mode == XUiSkin.InputMode.KEYBOARD, XUiSkin.input_mode)
	var up := _key()
	up.pressed = false
	Input.parse_input_event(up)
	await frames(1)
	XUiSkin.input_mode = -1
	XUiSkin.touch_override = -1


# ---- 单测 4（无头部分）：开关 ----
func _detail_switch_headless() -> void:
	check("detail_on", XUiSkin.detail_on())
	XUiSkin.DETAIL_V1 = false
	check("detail_off", not XUiSkin.detail_on())
	check("detail_off_font_num_same", XUiSkin.font("num") == GameFont.current())
	XUiSkin.DETAIL_V1 = true
	XUiSkin.FORCE = false
	XUiSkin._cli_mode = 0
	check("detail_needs_skin", not XUiSkin.detail_on())
	XUiSkin._cli_mode = -2
	XUiSkin.FORCE = true


func _focus_geometry() -> void:
	check("ring_expand_4", XUiSkin.FOCUS_EXPAND == 4 and XUiSkin.FOCUS_RING_W == 2)
	check("ring_gap_12", XUiSkin.FOCUS_BTN_GAP - 2 * XUiSkin.FOCUS_EXPAND == 4 and XUiSkin.FOCUS_BTN_GAP_COMPACT >= 10)
	check("ring_colors", XUiSkin.FOCUS_IN == Color("090808") and XUiSkin.GOLD_LIGHT == Color("f2d08a"))


func _surfaces_and_baseline() -> void:
	XUiSkin.POLISH_V1 = true
	check("surface_warm", XUiSkin.surface_c(XUiSkin.Surface.S0) == Color("090808") and XUiSkin.surface_c(XUiSkin.Surface.S2) == Color("2e2928")
		and XUiSkin.surface_c(XUiSkin.Surface.S4) == Color("413a38"))
	var g3 := XUiSkin.surface_grad(XUiSkin.Surface.S3)
	check("surface_s3_grad", (g3[0] as Color).is_equal_approx(Color(Color("36302e"), 0.94)) and (g3[1] as Color).is_equal_approx(Color(Color("25201f"), 0.94)), g3)
	# 相邻级明度差 ≥ 6%（HSL L；S1 对 S0、S2 对 S1、S4 对 S2）
	var steps := true
	for pair in [[0, 1], [1, 2], [2, 4]]:
		var a := XUiSkin.surface_c(pair[0])
		var b := XUiSkin.surface_c(pair[1])
		var la := (maxf(a.r, maxf(a.g, a.b)) + minf(a.r, minf(a.g, a.b))) * 0.5
		var lb := (maxf(b.r, maxf(b.g, b.b)) + minf(b.r, minf(b.g, b.b))) * 0.5
		if lb - la < 0.06:
			steps = false
	check("surface_steps_6pct", steps)
	XUiSkin.POLISH_V1 = false
	check("surface_cold", XUiSkin.surface_c(XUiSkin.Surface.S0) == Color("050506") and XUiSkin.surface_c(XUiSkin.Surface.S2) == Color("26282e"))
	XUiSkin.POLISH_V1 = true
	check("zebra_008", XUiSkin.zebra_c().is_equal_approx(Color(Color("f0e6d8"), 0.08)))
	check("sunken", XUiSkin.sunken_c().a > 0.7 and XUiSkin.surface_overlay("sunken") == XUiSkin.sunken_c())
	check("baseline_036", XUiSkin.TEXT_CY_K == 0.36 and XUiSkin.text_baseline_y(100.0, 20) == 107.0 and XUiSkin.text_baseline_y(50.0, 19) == roundf(50.0 + 19 * 0.36))
	check("icon_rect", XUiSkin.ICON_DY_K == 0.0 and XUiSkin.inline_icon_rect(10.4, 40.0, 32.0, 19) == Rect2(10, 24, 32, 32))
	check("icon_gap", XUiSkin.inline_icon_gap(15) == 6 and XUiSkin.inline_icon_gap(34) == 12)
