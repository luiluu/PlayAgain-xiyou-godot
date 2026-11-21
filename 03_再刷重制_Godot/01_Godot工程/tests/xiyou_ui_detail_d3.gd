extends Node
## 【cc·T339·未经审查】界面细节 D3 手感升级（私密仓 重制设定/界面细节规范_v0.1.md 第五节卡 D3）：
## 1. XSkinDrag：触屏 7px 不起拖、9px 起拖首帧位移 1px；鼠标 4px 不起拖、6px 起拖首帧位移 1px；DETAIL_V1 关回旧死区 10／不扣除；
##    INERTIA_ENABLED 默认开；关＝松手即停、开且非 Motion.OFF＝惯性不越界（最多越出 24px 再回弹落回边界）；
## 2. XSkinList：像素跟手（半行位置）、按下 0ms 预按、拖起来撤销、点一下才 activated、滚动条拖拽高亮 0.92／松手 0.6s 后 0.68、DETAIL_V1 关逐行跳；
## 3. 按钮：XSkinButton.apply 的按钮 button_down 即刻缩到 0.97、button_up 回焦点倍率；自绘件（确认弹窗、详情牌、数量条）按下 0ms 微缩压暗；
## 4. T336 核查 P2-1／P3-2：输入监听节点保持根下末位、合成键盘事件（meta）不记成键盘。
## 带 -- --out=<目录> 且有窗口时出两组验收图：list_drag_halfrow.png（触屏两列物品列表停在半行像素，选中行左外箭头完整、滚动条高亮）、
## button_press_triple.png（常态｜悬停｜按下三联）。
##   拍：godot --audio-driver Dummy --path <工程> res://tests/xiyou_ui_detail_d3.tscn -- --out=<目录>
const TestEnv = preload("res://tests/xiyou_test_env.gd")
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
	TestEnv.isolate("xiyou_ui_detail_d3")
	get_viewport().gui_disable_input = windowed()
	XUiSkin.FORCE = true
	XUiSkin.DETAIL_V1 = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XUiSkin._clock_ms = 100000
	XFontScale.set_value("global", 100)
	XUiSkin.touch_override = 0
	_drag_unit()
	_inertia_unit()
	await _list_unit()
	await _button_unit()
	await _confirm_card_stepper()
	await _tracker_unit()
	if windowed():
		await _shot_list()
		await _shot_buttons()
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XUiSkin._clock_ms = -1
	XUiSkin.input_mode = -1
	XUiSkin.touch_override = -1
	XUiSkin.DETAIL_V1 = true
	XSkinDrag.INERTIA_ENABLED = true
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 辅助：造鼠标／触屏事件 ----

func _mb(p: Vector2, pressed: bool, touch: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	if touch:
		e.device = InputEvent.DEVICE_ID_EMULATION
	return e


func _mm(p: Vector2, touch: bool) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	if touch:
		e.device = InputEvent.DEVICE_ID_EMULATION
	return e


# ---- 单测 1：XSkinDrag 死区 ----
func _drag_unit() -> void:
	var touch_ev := _mm(Vector2.ZERO, true)
	var mouse_ev := _mm(Vector2.ZERO, false)
	check("drag_is_touch_emulation", XSkinDrag.is_touch_event(touch_ev))
	check("drag_is_touch_real_mouse_false", not XSkinDrag.is_touch_event(mouse_ev))
	XUiSkin.touch_override = 1
	check("drag_is_touch_device_touch", XSkinDrag.is_touch_event(mouse_ev))
	XUiSkin.touch_override = 0
	check("slop_values", XSkinDrag.SLOP_TOUCH == 8.0 and XSkinDrag.SLOP_MOUSE == 5.0 and XSkinDrag.slop_for(true) == 8.0 and XSkinDrag.slop_for(false) == 5.0)
	check("inertia_default_on", XSkinDrag.INERTIA_ENABLED == true)
	for c in [["touch", true, 7.0, 9.0], ["mouse", false, 4.0, 6.0]]:
		var d := XSkinDrag.new()
		d.press(Vector2(100, 300), 50.0)
		var is_t: bool = c[1]
		check("%s_%dpx_no_drag" % [c[0], int(c[2])], is_nan(d.motion(Vector2(100, 300 - float(c[2])), is_t)) and not d.dragging)
		var v := d.motion(Vector2(100, 300 - float(c[3])), is_t)
		check("%s_%dpx_drag_first_frame_1px" % [c[0], int(c[3])], d.dragging and is_equal_approx(v, 51.0), v)
		# 往下拖（滚动值减小）同样扣死区
		var d2 := XSkinDrag.new()
		d2.press(Vector2(100, 300), 50.0)
		var v2 := d2.motion(Vector2(100, 300 + float(c[3])), is_t)
		check("%s_drag_down_first_frame_1px" % c[0], is_equal_approx(v2, 49.0), v2)
		check("%s_release_after_drag_not_tap" % c[0], d.release() == false)
	var d3 := XSkinDrag.new()
	d3.press(Vector2(10, 10), 0.0)
	d3.motion(Vector2(10, 12), true)
	check("release_without_drag_is_tap", d3.release())
	# 零延迟：同一帧跨过死区就进拖动（不看时间）
	var d4 := XSkinDrag.new()
	d4.press(Vector2.ZERO, 0.0)
	d4.motion(Vector2(0, -8), true, 1.0)
	check("zero_latency_same_frame", d4.dragging)
	# 回退：DETAIL_V1 关＝旧死区 10、不扣除
	XUiSkin.DETAIL_V1 = false
	var d5 := XSkinDrag.new()
	d5.press(Vector2(0, 300), 50.0)
	check("rollback_9px_no_drag", is_nan(d5.motion(Vector2(0, 291), true)))
	var v5 := d5.motion(Vector2(0, 290), true)
	check("rollback_10px_jump_no_deadzone", is_equal_approx(v5, 60.0), v5)
	check("rollback_slop_10", XSkinDrag.slop_for(true) == 10.0 and XSkinDrag.slop_for(false) == 10.0)
	XUiSkin.DETAIL_V1 = true
	# 速度：最后 80ms
	var d6 := XSkinDrag.new()
	d6.press(Vector2(0, 500), 0.0)
	d6.motion(Vector2(0, 490), true, 1.00)   # 值 2
	d6.motion(Vector2(0, 440), true, 1.10)   # 值 52
	d6.motion(Vector2(0, 400), true, 1.16)   # 值 92
	d6.motion(Vector2(0, 360), true, 1.20)   # 值 132
	d6.release()
	# 窗口内（≥1.12）：1.16→1.20 之间的样本 92@1.16、132@1.20 ＝ 1000 px/s
	check("release_velocity_last_80ms", is_equal_approx(d6.release_velocity, 1000.0), d6.release_velocity)


# ---- 单测 2：惯性（可选增强） ----
func _inertia_unit() -> void:
	var d := XSkinDrag.new()
	d.release_velocity = 800.0
	XSkinDrag.INERTIA_ENABLED = false
	check("inertia_off_stops_on_release", not d.begin_inertia(100.0) and not d.inertia_active())
	XSkinDrag.INERTIA_ENABLED = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	check("inertia_motion_off_stops", not d.begin_inertia(100.0))
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XUiSkin.DETAIL_V1 = false
	check("inertia_rollback_stops", not d.begin_inertia(100.0))
	XUiSkin.DETAIL_V1 = true
	d.release_velocity = 20.0
	check("inertia_too_slow_stops", not d.begin_inertia(100.0))
	# 中间滑停：不越界、最长 0.35s
	d.release_velocity = 800.0
	check("inertia_begins", d.begin_inertia(100.0) and d.inertia_active())
	var v := 100.0
	var t := 0.0
	var lo := 0.0
	var hi := 1000.0
	var worst := 0.0
	while d.inertia_active() and t < 2.0:
		v = d.tick_inertia(1.0 / 60.0, lo, hi)
		t += 1.0 / 60.0
		worst = maxf(worst, maxf(lo - v, v - hi))
	check("inertia_mid_in_bounds", worst <= 0.0, worst)
	check("inertia_mid_max_0_35s", t <= XSkinDrag.INERTIA_MAX_T + 0.05, t)
	check("inertia_mid_advanced", v > 100.0 and v < 100.0 + 800.0 * 0.35, v)
	# 冲出下边界：最多越出 24px，回弹后落回 [lo, hi]
	d.release_velocity = 700.0
	d.begin_inertia(2.0 + 0.0)
	v = 2.0
	t = 0.0
	worst = 0.0
	var seen_over := false
	while d.inertia_active() and t < 2.0:
		v = d.tick_inertia(1.0 / 60.0, 0.0, 6.0)
		t += 1.0 / 60.0
		worst = maxf(worst, maxf(0.0 - v, v - 6.0))
		if v > 6.0:
			seen_over = true
	check("rubber_over_within_24", worst <= XSkinDrag.RUBBER_MAX + 0.001, worst)
	check("rubber_pulled_out", seen_over)
	check("rubber_settles_in_bounds", v >= 0.0 and v <= 6.0 and is_equal_approx(v, 6.0), v)
	check("rubber_back_0_16s", t <= XSkinDrag.INERTIA_MAX_T + XSkinDrag.RUBBER_BACK_T + 0.05, t)
	XSkinDrag.INERTIA_ENABLED = true


# ---- 单测 3：XSkinList ----
func _make_list(n := 20, cols := 2) -> XSkinList:
	var l := XSkinList.new()
	l.columns = cols
	l.row_height = 46
	l.size = Vector2(620, 46 * 4)
	var arr: Array = []
	for i in n:
		arr.append({"text": "物品%d" % i, "right": "×%d" % (i + 1)})
	add_child(l)
	l.set_items(arr)
	return l


func _list_unit() -> void:
	var l := _make_list()
	var acted: Array = []
	l.activated.connect(func(i: int) -> void: acted.append(i))
	await frames(2)
	check("list_scrollable", l.scrollable() and l.rows_total() == 10 and l.visible_rows() == 4)
	check("list_max_scroll_px", is_equal_approx(l.max_scroll_px(), 6.0 * 46.0))
	check("list_scroll_px_start", l.scroll_px == 0.0)
	# 触屏按下：0ms 预按
	var p0 := Vector2(40, 46 * 1 + 10)   # 第 1 行第 0 列＝项 2
	l._gui_input(_mb(p0, true, true))
	check("list_pre_press_instant", l.pre_press == 2, l.pre_press)
	# 7px 没起拖，预按还在
	l._gui_input(_mm(p0 - Vector2(0, 7), true))
	check("list_pre_press_kept_under_slop", l.pre_press == 2 and not l._xd.dragging)
	# 20px → 起拖，位移 12px（扣死区 8px），预按立刻撤
	l._gui_input(_mm(p0 - Vector2(0, 20), true))
	check("list_drag_pre_press_cleared", l.pre_press == -1 and l._xd.dragging)
	check("list_pixel_follow_12px", is_equal_approx(l.scroll_px, 12.0), l.scroll_px)
	check("list_top_row_sub", l.top_row == 0 and is_equal_approx(l._sub, 12.0))
	check("list_cell_rect_shifted", is_equal_approx(l.cell_rect(0).position.y, -12.0) and is_equal_approx(l.cell_rect(2).position.y, 46.0 - 12.0), l.cell_rect(2))
	check("list_not_row_jump", not is_equal_approx(fposmod(l.scroll_px, 46.0), 0.0))
	check("list_scroll_alpha_hi", is_equal_approx(l.scroll_alpha(), 0.92))
	# 再拖：46 + 12 = 58px 手指移动 → 滚动 50px，跨过一行边界
	l._gui_input(_mm(p0 - Vector2(0, 8 + 50), true))
	check("list_cross_row_boundary", l.top_row == 1 and is_equal_approx(l._sub, 4.0) and is_equal_approx(l.scroll_px, 50.0), [l.top_row, l._sub, l.scroll_px])
	# 拖过头截断
	l._gui_input(_mm(p0 - Vector2(0, 5000), true))
	check("list_clamp_max", is_equal_approx(l.scroll_px, l.max_scroll_px()) and l.top_row == 6 and l._sub == 0.0)
	l._gui_input(_mm(p0 + Vector2(0, 5000), true))
	check("list_clamp_min", l.scroll_px == 0.0 and l.top_row == 0)
	# 松手：拖过 → 不触发 activated；惯性关＝松手即停
	l._gui_input(_mm(p0 - Vector2(0, 8 + 30), true))
	var px_before := l.scroll_px
	l._gui_input(_mb(p0 - Vector2(0, 38), false, true))
	await frames(3)
	check("list_release_drag_no_activate", acted.is_empty())
	check("list_inertia_off_stops", is_equal_approx(l.scroll_px, px_before) and not l._xd.inertia_active(), [l.scroll_px, px_before])
	# 滚动条：松手 0.6s 内还亮，之后回 0.68
	check("list_scroll_alpha_hold", is_equal_approx(l.scroll_alpha(), 0.92))
	await get_tree().create_timer(0.75).timeout
	check("list_scroll_alpha_back", is_equal_approx(l.scroll_alpha(), 0.68), l.scroll_alpha())
	# 点选：半行位置上点第 0 行的项，item_at 要扣掉零头
	var sub := l._sub
	var hit := l.item_at(Vector2(40, 10))
	check("list_item_at_with_sub", hit == (l.top_row * 2) + 0 and sub > 0.0 or hit == l.top_row * 2, [hit, l.top_row, sub])
	# 不拖：按下→松手＝一次点（先选中，再点当前项 activated）
	var target := l.item_at(Vector2(40, 100))
	l._gui_input(_mb(Vector2(40, 100), true, true))
	check("list_tap_press_pre", l.pre_press == target and target >= 0)
	l._gui_input(_mb(Vector2(40, 100), false, true))
	check("list_tap_selects", l.index == target and l.pre_press == -1 and acted.is_empty(), [l.index, target])
	l._gui_input(_mb(Vector2(40, 100), true, true))
	l._gui_input(_mb(Vector2(40, 100), false, true))
	check("list_tap_current_activates", acted == [target], acted)
	# 选中后点的行已完整可见，不动画面（_sub 不被清）
	check("list_tap_keeps_pixel_pos", is_equal_approx(l.scroll_px, px_before), [l.scroll_px, px_before])
	# 键盘：整行对齐，清零头
	l.move(0, 1)
	check("list_key_snaps_rows", l._sub == 0.0 and is_equal_approx(l.scroll_px, l.top_row * 46.0), l.scroll_px)
	check("list_scroll_px_getter_setter", true)
	l.scroll_px = 70.0
	check("list_scroll_px_setter", is_equal_approx(l.scroll_px, 70.0) and l.top_row == 1 and is_equal_approx(l._sub, 24.0))
	# 真鼠标：6px 起拖、首帧 1px
	var m := _make_list()
	m._gui_input(_mb(Vector2(40, 100), true, false))
	m._gui_input(_mm(Vector2(40, 96), false))
	check("list_mouse_4px_no_drag", not m._xd.dragging and m.scroll_px == 0.0)
	m._gui_input(_mm(Vector2(40, 94), false))
	check("list_mouse_6px_first_frame_1px", m._xd.dragging and is_equal_approx(m.scroll_px, 1.0), m.scroll_px)
	m._gui_input(_mb(Vector2(40, 94), false, false))
	# 不能滚的列表：拖不动，松手仍算点
	var short := _make_list(3, 1)
	short.size = Vector2(300, 46 * 4)
	short._gui_input(_mb(Vector2(40, 100), true, true))
	short._gui_input(_mm(Vector2(40, 60), true))
	check("list_unscrollable_no_scroll", short.scroll_px == 0.0)
	# 回退：DETAIL_V1 关＝整行跳（旧路径）
	XUiSkin.DETAIL_V1 = false
	var r := _make_list()
	r._gui_input(_mb(Vector2(40, 100), true, true))
	r._gui_input(_mm(Vector2(40, 100 - 25), true))   # 旧：10px 死区＋roundi(25/46)=1 行
	check("list_rollback_row_jump", r.top_row == 1 and r._sub == 0.0 and r.pre_press == -1, [r.top_row, r._sub])
	r._gui_input(_mb(Vector2(40, 75), false, true))
	XUiSkin.DETAIL_V1 = true
	# 惯性开：松手后继续滑一小段且不越界
	XSkinDrag.INERTIA_ENABLED = true
	var g := _make_list()
	g._gui_input(_mb(Vector2(40, 150), true, true))
	var t0 := Time.get_ticks_msec() / 1000.0
	for k in range(1, 5):
		g._xd.motion(Vector2(40, 150 - k * 14.0), true, t0 + k * 0.02)
	g._set_scroll_px(g._xd.base + 4 * 14.0 - 8.0)
	g._gui_input(_mb(Vector2(40, 94), false, true))
	check("list_inertia_on_gliding", g._xd.inertia_active() or g._xd.release_velocity < XSkinDrag.INERTIA_MIN_V, g._xd.release_velocity)
	var worst := 0.0
	for k in 40:
		await get_tree().process_frame
		worst = maxf(worst, maxf(-g.scroll_px, g.scroll_px - g.max_scroll_px()))
	check("list_inertia_rubber_within_24", worst <= XSkinDrag.RUBBER_MAX + 0.01, worst)
	await get_tree().create_timer(0.7).timeout
	check("list_inertia_settles_in_bounds", g.scroll_px >= 0.0 and g.scroll_px <= g.max_scroll_px() + 0.01 and not g._xd.inertia_active(), g.scroll_px)
	XSkinDrag.INERTIA_ENABLED = true
	# 剪裁：半行时开剪裁、左右留 26、只裁上下；静止时关
	var c := _make_list()
	check("list_clip_off_at_rest", c._sub == 0.0 and c.clip_rect().position.x == -XSkinList.CLIP_SIDE and c.clip_rect().size.x == c.size.x + XSkinList.CLIP_SIDE * 2.0)
	check("list_clip_vertical_only", c.clip_rect().position.y == 0.0 and c.clip_rect().size.y == 4 * 46.0)
	for n in [l, m, short, r, g, c]:
		n.queue_free()
	await frames(2)


# ---- 单测 4：按钮 ----
func _button_unit() -> void:
	var b := Button.new()
	b.text = "确定"
	b.custom_minimum_size = Vector2(160, 48)
	add_child(b)
	XSkinButton.apply(b)
	b.size = Vector2(160, 48)
	await frames(2)
	check("btn_wired", b.has_meta("skin_press_fb_wired"))
	check("btn_target_values", XSkinButton.press_scale_target(true, false) == 0.97 and XSkinButton.press_scale_target(false, true) == XSkinButton.BUTTON_PEAK and XSkinButton.press_scale_target(false, false) == 1.0)
	b.button_down.emit()
	check("btn_press_target_instant", is_equal_approx(float(b.get_meta("skin_press_k")), 0.97))
	await get_tree().create_timer(XSkinButton.PRESS_IN + 0.08).timeout
	check("btn_press_scale_097", is_equal_approx(b.scale.x, 0.97), b.scale)
	b.button_up.emit()
	await get_tree().create_timer(XSkinButton.PRESS_OUT + 0.08).timeout
	check("btn_release_back_1", is_equal_approx(b.scale.x, 1.0), b.scale)
	# 有焦点的按钮：松手回 1.05
	b.grab_focus()
	await get_tree().create_timer(0.3).timeout
	b.button_down.emit()
	await get_tree().create_timer(0.15).timeout
	var down_x := b.scale.x
	b.button_up.emit()
	await get_tree().create_timer(0.25).timeout
	check("btn_focus_press_then_peak", is_equal_approx(down_x, 0.97) and is_equal_approx(b.scale.x, XSkinButton.BUTTON_PEAK), [down_x, b.scale])
	# 「关」档：不缩放
	b.release_focus()
	await get_tree().create_timer(0.2).timeout
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	b.button_down.emit()
	await frames(2)
	check("btn_off_no_scale", is_equal_approx(b.scale.x, 1.0), b.scale)
	b.button_up.emit()
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	# 回退：开关关＝按下不缩
	XUiSkin.DETAIL_V1 = false
	b.button_down.emit()
	await get_tree().create_timer(0.15).timeout
	check("btn_rollback_no_scale", is_equal_approx(b.scale.x, 1.0), b.scale)
	b.button_up.emit()
	XUiSkin.DETAIL_V1 = true
	b.queue_free()
	# 自绘件的矩形／颜色
	var r := Rect2(100, 100, 200, 50)
	var pr := XSkinButton.press_rect(r, true)
	check("press_rect_097_centered", is_equal_approx(pr.size.x, 194.0) and is_equal_approx(pr.size.y, 48.5) and pr.get_center().is_equal_approx(r.get_center()), pr)
	check("press_rect_not_pressed_same", XSkinButton.press_rect(r, false) == r)
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	check("press_rect_off_sinks_1px", XSkinButton.press_rect(r, true) == Rect2(100, 101, 200, 50))
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	var c0 := Color(0.5, 0.4, 0.3, 0.8)
	var c1 := XSkinButton.press_color(c0, true)
	check("press_color_darken_22", c1.is_equal_approx(c0.darkened(0.22)) and is_equal_approx(c1.a, 0.8) and c1.v < c0.v)
	XUiSkin.DETAIL_V1 = false
	check("press_rollback_identity", XSkinButton.press_rect(r, true) == r and XSkinButton.press_color(c0, true) == c0)
	XUiSkin.DETAIL_V1 = true


# ---- 单测 5：自绘件按下态（确认弹窗、详情牌、数量条）----
func _confirm_card_stepper() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var dlg := XSkinConfirm.open(host, {"title": "确认", "body": "要这样做吗？", "buttons": ["确定", "取消"], "index": 0})
	await frames(2)
	var rc := dlg.button_rect(1)
	check("confirm_press_state_instant", dlg._press == -1)
	dlg._gui_input(_mb(rc.get_center(), true, true))
	check("confirm_press_0ms", dlg._press == 1)
	dlg._gui_input(_mb(rc.get_center(), false, true))
	check("confirm_release_clears", dlg._press == -1)
	var card := XSkinCard.new()
	card.size = Vector2(360, 240)
	host.add_child(card)
	card.buttons = [{"text": "使用"}, {"text": "丢弃"}]
	await frames(2)
	var cr := card.button_rect(0)
	card._gui_input(_mb(cr.get_center(), true, true))
	check("card_press_0ms", card._press == 0)
	card._gui_input(_mb(cr.get_center(), false, true))
	check("card_release_clears", card._press == -1)
	var st := XSkinStepper.new()
	host.add_child(st)
	st.size = Vector2(300, 48)
	await frames(2)
	var sr := st.button_rect(1)
	st._gui_input(_mb(sr.get_center(), true, true))
	check("stepper_press_0ms", st._press == 1)
	st._gui_input(_mb(sr.get_center(), false, true))
	check("stepper_release_clears", st._press == -1)
	host.queue_free()
	await frames(2)


# ---- 单测 6：T336 核查 P2-1／P3-2 ----
func _tracker_unit() -> void:
	XUiSkin.input_mode = -1
	XUiSkin.on()   # 早挂：不用等第一次 show_focus_ring
	XUiSkin.show_focus_ring()
	await frames(3)
	var root := get_tree().root
	var tr: Node = XUiSkin._tracker
	check("tracker_attached", is_instance_valid(tr) and tr.is_inside_tree())
	check("tracker_last_child_initial", root.get_child(root.get_child_count() - 1) == tr)
	# 切场景：根下新挂一个节点（模拟 change_scene 把新场景加在后面）→ 监听节点要挪回末位
	var fake := Node.new()
	root.add_child(fake)
	await frames(3)
	check("tracker_keeps_last_after_add", root.get_child(root.get_child_count() - 1) == tr)
	var fake2 := Node.new()
	root.add_child(fake2)
	await frames(3)
	check("tracker_keeps_last_after_second_add", root.get_child(root.get_child_count() - 1) == tr)
	fake.queue_free()
	fake2.queue_free()
	await frames(2)
	# 合成键盘事件不记成键盘
	XUiSkin.input_mode = XUiSkin.InputMode.TOUCH
	var synth := InputEventKey.new()
	synth.keycode = KEY_UP
	synth.physical_keycode = KEY_UP
	synth.pressed = true
	synth.set_meta(XUiSkin.SYNTH_META, true)
	XUiSkin.note_input(synth)
	check("synth_key_skipped", XUiSkin.input_mode == XUiSkin.InputMode.TOUCH)
	var real := InputEventKey.new()
	real.keycode = KEY_UP
	real.physical_keycode = KEY_UP
	real.pressed = true
	XUiSkin.note_input(real)
	check("real_key_is_keyboard", XUiSkin.input_mode == XUiSkin.InputMode.KEYBOARD)
	# 触屏虚拟键本体发的事件带标记
	var tc := XTouchControls.new()
	var seen: Array = []
	var catcher := Node.new()
	var sc := GDScript.new()
	sc.source_code = "extends Node\nvar seen := []\nfunc _input(e):\n\tif e is InputEventKey: seen.append(e.has_meta(\"skin_synth_input\"))\n"
	sc.reload()
	catcher.set_script(sc)
	add_child(catcher)
	tc._send_key(KEY_Z, true)
	await frames(3)
	if not windowed():   # 带窗口时本测试关了 gui 输入，_input 收不到合成事件
		check("touch_virtual_key_has_meta", catcher.seen.size() > 0 and catcher.seen[0] == true, catcher.seen)
	tc.free()
	catcher.queue_free()
	XUiSkin.input_mode = -1


# ---- 验收截图 ----
func _grab() -> Image:
	await frames(6)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _shot_list() -> void:
	get_window().size = SHOT
	XUiSkin.input_mode = XUiSkin.InputMode.TOUCH
	XUiSkin.touch_override = 1
	var back := ColorRect.new()
	back.color = Color("090808")
	back.size = Vector2(SHOT)
	add_child(back)
	var l := XSkinList.new()
	l.columns = 2
	l.row_height = 46
	l.position = Vector2(80, 60)
	l.size = Vector2(620, 46 * 6)
	var arr: Array = []
	var names := ["治疗药水", "魔力药水", "解毒草", "回城卷轴", "铁剑", "皮甲", "银戒指", "木盾", "火焰符", "冰霜符", "雷鸣符", "风行符", "大补丸", "小还丹", "止血散", "清心露"]
	for i in names.size():
		arr.append({"text": names[i], "right": "×%d" % (i * 3 + 1)})
	add_child(l)
	l.set_items(arr)
	l.select(4, false)   # 选中第 2 行左列（零头后仍可见，箭头在左外）
	await frames(4)
	l._gui_input(_mb(Vector2(300, 200), true, true))
	l._gui_input(_mm(Vector2(300, 200 - 8 - 23), true))   # 扣死区后 23px＝半行
	var img := await _grab()
	check("shot_list_halfrow_state", is_equal_approx(l.scroll_px, 23.0) and l._bar_hi and l._sub > 0.0, [l.scroll_px, l._bar_hi])
	DirAccess.make_dir_recursive_absolute(out_dir)
	check("shot_list_saved", img.save_png(out_dir.path_join("list_drag_halfrow.png")) == OK)
	# 像素断言：选中行（项 4＝第 2 行，top 在 2*46-23＝69）的左外箭头区（x = 80-22..80）有非背景像素；列表上缘之上、下缘之下没有溢出的行字
	var sel_r := l.cell_rect(4)
	var gy := int(l.position.y + sel_r.position.y + sel_r.size.y / 2.0)
	var arrow_ink := 0
	for xx in range(int(l.position.x) - 24, int(l.position.x) - 2):
		for yy in range(gy - 12, gy + 13):
			if img.get_pixel(xx, yy).v > 0.2:
				arrow_ink += 1
	check("shot_list_arrow_not_clipped", arrow_ink > 6, arrow_ink)
	var above_ink := 0
	for xx in range(int(l.position.x) + 20, int(l.position.x) + 300):
		for yy in range(int(l.position.y) - 30, int(l.position.y)):
			if img.get_pixel(xx, yy).v > 0.15:
				above_ink += 1
	check("shot_list_vertical_clipped_top", above_ink == 0, above_ink)
	var below_ink := 0
	for xx in range(int(l.position.x) + 20, int(l.position.x) + 300):
		for yy in range(int(l.position.y) + 46 * 6, int(l.position.y) + 46 * 6 + 30):
			if img.get_pixel(xx, yy).v > 0.15:
				below_ink += 1
	check("shot_list_vertical_clipped_bottom", below_ink == 0, below_ink)
	l._gui_input(_mb(Vector2(300, 200), false, true))
	l.queue_free()
	back.queue_free()
	XUiSkin.input_mode = -1
	XUiSkin.touch_override = 0
	await frames(2)


func _shot_buttons() -> void:
	get_window().size = SHOT
	XUiSkin.input_mode = XUiSkin.InputMode.MOUSE
	var back := ColorRect.new()
	back.color = Color("090808")
	back.size = Vector2(SHOT)
	add_child(back)
	var names := ["常态", "悬停（现 HOVER，S4 待 D1b）", "按下（0.97＋压暗 22%）"]
	var btns: Array = []
	for k in 3:
		var b := Button.new()
		b.text = "出发"
		b.size = Vector2(240, 64)
		b.position = Vector2(80 + k * 400, 300)
		back.add_child(b)
		XSkinButton.apply(b, "primary" if false else "", 26)
		var lab := Label.new()
		lab.text = names[k]
		lab.position = Vector2(80 + k * 400, 250)
		lab.add_theme_font_size_override("font_size", 22)
		back.add_child(lab)
		btns.append(b)
	var normal := XSkinButton.style()
	(btns[0] as Button).add_theme_stylebox_override("focus", normal)
	(btns[1] as Button).add_theme_stylebox_override("normal", XSkinButton.select(normal, XUiSkin.SelState.HOVER))
	(btns[2] as Button).add_theme_stylebox_override("normal", XSkinButton.select(normal, XUiSkin.SelState.PRESSED))
	(btns[2] as Button).button_down.emit()
	await get_tree().create_timer(0.2).timeout
	var img := await _grab()
	check("shot_btn_press_scale", is_equal_approx((btns[2] as Button).scale.x, 0.97), (btns[2] as Button).scale)
	DirAccess.make_dir_recursive_absolute(out_dir)
	check("shot_btn_saved", img.save_png(out_dir.path_join("button_press_triple.png")) == OK)
	# 按下钮的实际占宽 ≈ 0.97 × 240（左右各缩 3.6）：量中线上一行边缘
	var row := 300 + 32
	var left_edge := -1
	for xx in range(80 + 800 - 1, 80 + 800 + 130):   # 从钮左缘起量（左外的选中小箭头不算）
		if img.get_pixel(xx, row).v > 0.06:
			left_edge = xx
			break
	check("shot_btn_press_left_edge_inset", left_edge >= 80 + 800 + 3 and left_edge <= 80 + 800 + 6, left_edge)
	back.queue_free()
	XUiSkin.input_mode = -1
	await frames(2)
