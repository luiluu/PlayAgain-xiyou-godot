extends Node
## 【cc·T336·未经审查】界面细节 D1a 底层（私密仓 重制设定/界面细节规范_v0.1.md 第五节卡 D1a）：
## 1. TianqiUiNum-Medium.ttf 经 _make_tabular 后 0 与 1 字宽相等（不开时不等，证明断言咬得住）；三字体模式下 font("num") 开 tnum、DETAIL_V1 关回原字；
## 2. TianqiUiSerif-Heavy.otf 经逐位定宽：「111」「777」「888」总宽相等、每位在格内居中；格宽＝0–9 最大字宽（T329 r2 P3-6）；
## 3. 输入模式：键盘／手柄（含摇杆死区）／真鼠标（含移动阈值）／DEVICE_ID_EMULATION 触屏、屏幕触摸下 show_focus_ring() 对；全局监听节点挂上；
## 4. DETAIL_V1＝false 回退：现有页面（确认弹窗、详情牌）开关前后逐像素相同（要窗口）；默认字体模式下 font("num") 不变；
## 另：双环几何（内黑贴外缘 0～2px、外淡金 2～4px，紧凑控件同样 2px／4px，P3-7）、色阶、基线与行内图标出口。
## 带 -- --out=<目录> 且有窗口时出 Q1 样稿：确认弹窗＋详情牌双按钮「改前（现状）｜改后（双环＋S3＋12px）」1:1 并排（手柄态），
## 并逐像素断言改后环色。样稿只在本测试里直绘（PreviewConfirm／PreviewCard 子类），不改正式页面。
##   拍：godot --audio-driver Dummy --path <工程> res://tests/xiyou_ui_skin_d1a.tscn -- --out=<目录>
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
	if windowed():
		await _pixel_rollback()
		await _q1_sample()
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


# ---- 窗口：DETAIL_V1 关开前后现有组件逐像素相同 ----
func _grab() -> Image:
	await frames(6)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _pixel_rollback() -> void:
	var win := get_window()
	win.size = SHOT
	var root := _column(false, "")
	add_child(root)
	XUiSkin.DETAIL_V1 = true
	var on_img := await _grab()
	XUiSkin.DETAIL_V1 = false
	for c in _all_canvas(root):
		c.queue_redraw()
	var off_img := await _grab()
	XUiSkin.DETAIL_V1 = true
	check("rollback_pixel_same", on_img.get_data() == off_img.get_data())
	root.queue_free()
	await frames(2)


func _all_canvas(n: Node) -> Array:
	var out := []
	if n is CanvasItem:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_canvas(c))
	return out


# ---- 窗口：Q1 样稿 ----
const COL_W := 620.0
const CARD_SIZE := Vector2(540, 250)
const CONFIRM_BOX := Vector2(620, 330)


func _column(after: bool, caption: String) -> Control:
	var col := Control.new()
	col.size = Vector2(COL_W, SHOT.y)
	col.clip_contents = true
	var bg := ColorRect.new()
	bg.color = Color("090808")
	bg.size = col.size
	col.add_child(bg)
	var smoke := Panel.new()
	smoke.add_theme_stylebox_override("panel", XUiSkin.panel_style())
	smoke.position = Vector2(16, 64)
	smoke.size = Vector2(COL_W - 32, 300)
	col.add_child(smoke)
	if caption != "":
		var lb := Label.new()
		lb.text = caption
		lb.add_theme_font_override("font", XUiSkin.font("body"))
		lb.add_theme_font_size_override("font_size", 22)
		lb.add_theme_color_override("font_color", XUiSkin.GOLD)
		lb.position = Vector2(24, 18)
		col.add_child(lb)
	var card: XSkinCard = PreviewCard.new() if after else XSkinCard.new()
	card.position = Vector2(40, 88)
	card.size = CARD_SIZE
	col.add_child(card)
	card.setup({"title": "饮血长刀", "title_color": XUiSkin.quality_color(4), "subtitle": "武器 · 传说",
		"desc": "攻击 +128　暴击 +6%　吸血 3%",
		"buttons": [{"text": "装备", "primary": true}, {"text": "丢弃"}], "button_index": 0})
	var box := Control.new()
	box.position = Vector2(0, 380)
	box.size = CONFIRM_BOX
	col.add_child(box)
	var dlg: XSkinConfirm = PreviewConfirm.new() if after else XSkinConfirm.new()
	box.add_child(dlg)
	dlg.setup({"title": "卖掉这一档？", "body": "会卖掉 14 件，得 4,200", "buttons": ["确认出售", "取消"], "danger": true})
	col.set_meta("card", card)
	col.set_meta("dlg", dlg)
	return col


func _q1_sample() -> void:
	XUiSkin.input_mode = XUiSkin.InputMode.GAMEPAD   # 手柄态：双环常显
	var win := get_window()
	win.size = SHOT
	var left := _column(false, "改前（现状）：红叠红＋左外箭头，钮距 8px")
	var right := _column(true, "改后（Q1）：S3 弹窗底＋内黑外淡金双环，钮距 12px")
	right.position.x = SHOT.x - COL_W
	var back := ColorRect.new()
	back.color = Color("090808")
	back.size = Vector2(SHOT)
	add_child(back)
	var sep := ColorRect.new()
	sep.color = Color(XUiSkin.GOLD, 0.5)
	sep.position = Vector2(COL_W + 19, 0)
	sep.size = Vector2(2, SHOT.y)
	add_child(left)
	add_child(right)
	add_child(sep)
	var img := await _grab()
	check("q1_size", img.get_size() == SHOT, img.get_size())
	DirAccess.make_dir_recursive_absolute(out_dir)
	check("q1_saved", img.save_png(out_dir.path_join("q1_double_ring_compare.png")) == OK)
	# 改后的环色：焦点钮上缘外 1px 内黑、3px 淡金；卡片主钮同
	var dlg: XSkinConfirm = right.get_meta("dlg")
	var card: XSkinCard = right.get_meta("card")
	for tag in ["dlg", "card"]:
		var node: Control = dlg if tag == "dlg" else card
		var r: Rect2 = dlg.button_rect(dlg.index) if tag == "dlg" else card.button_rect(card.button_index)
		var top := node.get_global_transform() * Vector2(r.position.x + r.size.x * 0.5, r.position.y)
		var c_in := img.get_pixelv(Vector2i(int(top.x), int(top.y) - 1))
		var c_out := img.get_pixelv(Vector2i(int(top.x), int(top.y) - 3))
		check("q1_%s_inner_black" % tag, c_in.v < 0.12, [c_in.to_html(), top])
		check("q1_%s_outer_gold" % tag, absf(c_out.r - 0.949) < 0.06 and absf(c_out.g - 0.816) < 0.06 and absf(c_out.b - 0.541) < 0.08, c_out.to_html())
	# 改后两钮净缝 ≥ 4px（各外扩 4 后）
	var gap := dlg.button_rect(1).position.x - dlg.button_rect(0).end.x
	check("q1_gap_12", is_equal_approx(gap, 12.0), gap)
	# 鼠标／触屏态：改后不画环（焦点钮上缘外 3px 不是淡金）
	XUiSkin.input_mode = XUiSkin.InputMode.TOUCH
	dlg.queue_redraw()
	card.queue_redraw()
	var img2 := await _grab()
	var r2: Rect2 = dlg.button_rect(dlg.index)
	var top2 := dlg.get_global_transform() * Vector2(r2.position.x + r2.size.x * 0.5, r2.position.y)
	var c2 := img2.get_pixelv(Vector2i(int(top2.x), int(top2.y) - 3))
	check("q1_touch_no_ring", not (absf(c2.r - 0.949) < 0.06 and absf(c2.g - 0.816) < 0.06), c2.to_html())
	check("q1_touch_saved", img2.save_png(out_dir.path_join("q1_double_ring_compare_touch.png")) == OK)
	XUiSkin.input_mode = -1
	left.queue_free()
	right.queue_free()
	sep.queue_free()
	back.queue_free()
	await frames(2)


## ---- 样稿用：改后画法（只在本测试里；D1b 照这个改正式件）----

class PreviewConfirm extends XSkinConfirm:
	## S3 浮层底（暖 #36302e→#25201f，94%）圆角九宫格
	static var _s3_tex: Texture2D


	static func s3_panel_tex() -> Texture2D:
		if _s3_tex != null:
			return _s3_tex
		var n := 96
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var g := XUiSkin.surface_grad(XUiSkin.Surface.S3)
		var top_c: Color = g[0]
		var low_c: Color = g[1]
		for y in range(n):
			var t := clampf((y - 2.0) / float(n - 4), 0.0, 1.0)
			var fill := top_c.lerp(low_c, t * t * (3.0 - 2.0 * t))
			for x in range(n):
				var d := XUiSkin._round_rect_dist(Vector2(x + 0.5, y + 0.5), Vector2(n, n), float(XUiSkin.RADIUS))
				if d > 0.5:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var c := fill
				c.a = fill.a * clampf(0.5 - d, 0.0, 1.0)
				img.set_pixel(x, y, c)
		_s3_tex = ImageTexture.create_from_image(img)
		return _s3_tex

	func button_rect(i: int) -> Rect2:
		var p := panel_rect()
		var n := maxi(buttons.size(), 1)
		var gap := float(XUiSkin.FOCUS_BTN_GAP)
		var bw := (p.size.x - PAD * 2 - gap * (n - 1)) / n
		return Rect2(p.position.x + PAD + i * (bw + gap), p.end.y - PAD - BTN_H, bw, BTN_H)

	func _draw() -> void:
		var ci := get_canvas_item()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.024, 0.024, DIM))
		var p := panel_rect()
		var sh := StyleBoxFlat.new()
		sh.draw_center = false
		sh.shadow_color = Color(0, 0, 0, 0.62)
		sh.shadow_size = 18
		sh.shadow_offset = Vector2(0, 10)
		sh.set_corner_radius_all(XUiSkin.RADIUS)
		sh.draw(ci, p)
		RenderingServer.canvas_item_add_nine_patch(ci, p, Rect2(0, 0, 96, 96), s3_panel_tex().get_rid(), Vector2(24, 24), Vector2(24, 24),
			RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, Color.WHITE)
		var lw := p.size.x * 0.72
		var lx0 := p.position.x + (p.size.x - lw) * 0.5
		XUiSkin.draw_divider(self, lx0, lx0 + lw, p.position.y + 2.0, true, 0.85)
		var edge := StyleBoxFlat.new()
		edge.draw_center = false
		edge.set_corner_radius_all(XUiSkin.RADIUS)
		edge.anti_aliasing = true
		edge.border_color = Color(XUiSkin.down_c(), 0.85) if danger else Color(XUiSkin.GOLD, 0.48)
		edge.set_border_width_all(2 if danger else 1)
		edge.draw(ci, p)
		var head := XUiSkin.font("title")
		var f := XUiSkin.font("body")
		var inner := p.size.x - PAD * 2
		var y := p.position.y + PAD
		var tfs := XUiSkin.fs(TITLE_FS)
		y = _para(head, title, Vector2(p.position.x + PAD, y), inner, tfs, roundf(tfs * 1.3), XUiSkin.down_c() if danger else XUiSkin.GOLD_LIGHT)
		if body != "":
			XUiSkin.draw_divider(self, p.position.x + PAD, p.end.x - PAD, y + 5.0, not danger, 0.8)
			y += 10.0
			var bfs := XUiSkin.fs(BODY_FS)
			_para(f, body, Vector2(p.position.x + PAD, y), inner, bfs, roundf(bfs * 1.5), XUiSkin.TEXT_2)
		for i in buttons.size():
			var r := button_rect(i)
			var b: Dictionary = buttons[i]
			var dis := bool(b.get("disabled", false))
			var bs := StyleBoxFlat.new()
			bs.set_corner_radius_all(int(BTN_H / 2.0))
			bs.anti_aliasing = true
			if i == index and not dis:
				XUiSkin.primary_button_style(bs, true)
				bs.shadow_size = 0   # 改后：焦点由双环表达，不再垫红晕（红晕在环外一圈发糊）
			else:
				bs.bg_color = Color(0.08, 0.068, 0.066, 0.55 if _press != i else 0.78)
				bs.border_color = Color(XUiSkin.line_c(), 0.52)
				bs.set_border_width_all(1)
			bs.draw(ci, r)
			if i == index and XUiSkin.show_focus_ring():
				XUiSkin.draw_focus_ring(ci, r, int(BTN_H / 2.0))
			var t := str(b.get("text", ""))
			var fs := XUiSkin.FS_LIST
			var fit := XSkinList.fit_text(f, t, r.size.x - 16.0, fs, 15)
			var tw := f.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x
			XUiSkin.ds(self, f, Vector2(r.position.x + (r.size.x - tw) / 2.0, XUiSkin.text_baseline_y(r.position.y + r.size.y / 2.0, int(fit[1]))), str(fit[0]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.TEXT_3 if dis else XUiSkin.TEXT)


class PreviewCard extends XSkinCard:
	func button_rect(i: int) -> Rect2:
		var n := buttons.size()
		if n == 0:
			return Rect2()
		var gap := float(XUiSkin.FOCUS_BTN_GAP)
		var w := (size.x - pad * 2 - gap * (n - 1)) / n
		return Rect2(pad + i * (w + gap), size.y - pad - BUTTON_H, w, BUTTON_H)

	func _draw() -> void:
		var ci := get_canvas_item()
		XUiSkin.shadow_style().draw(ci, Rect2(Vector2.ZERO, size))
		XUiSkin.panel_style().draw(ci, Rect2(Vector2.ZERO, size))
		_draw_border(ci, Rect2(Vector2.ZERO, size))
		_body(self, pad, pad, size.x - pad * 2, content_bottom(), false)
		sel_scale.sel(button_index if button_index >= 0 and button_index < buttons.size() else null)
		var body := XUiSkin.font("body")
		for i in buttons.size():
			var r := button_rect(i)
			var b: Dictionary = buttons[i]
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(int(BUTTON_H / 2))
			sb.anti_aliasing = true
			if bool(b.get("primary", false)) and not bool(b.get("disabled", false)):
				XUiSkin.primary_button_style(sb, i == button_index)
				sb.shadow_size = 0
			else:
				sb.bg_color = Color(0.06, 0.05, 0.048, 0.38)
				sb.border_color = Color(XUiSkin.line_c(), 0.52)
				sb.set_border_width_all(1)
			sb.draw(ci, r)
			if i == button_index and XUiSkin.show_focus_ring():
				XUiSkin.draw_focus_ring(ci, r, int(BUTTON_H / 2))
			var t := str(b.get("text", ""))
			var bfs := XSkinSelScale.fs(XUiSkin.FS_LIST, sel_scale.k(i), floori(r.size.y * 0.66))
			var tw := body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
			if bfs != XUiSkin.FS_LIST and tw > r.size.x - 12.0:
				bfs = XUiSkin.FS_LIST
				tw = body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
			XUiSkin.ds(self, body, Vector2(r.position.x + (r.size.x - tw) / 2.0, XUiSkin.text_baseline_y(r.position.y + r.size.y / 2.0, bfs)), t,
				HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, XUiSkin.TEXT_3 if bool(b.get("disabled", false)) else XUiSkin.TEXT)
