extends Node
## 【cc·T359·未经审查】共用控件收口（T356 审稿 F-03／F-05／F-14，Kyo 11-21 D250～D256 全按推荐）：
## 1. 按钮圆角（D251）：XUiSkin.btn_radius＝9（矮控件跟着缩、DETAIL_V1 关＝半高全圆角）；XSkinButton 9／关 6；窗口下确认弹窗焦点钮角上 4px 处仍是钮色（全圆角会是底色）；
## 2. 静默选中（D256）：XSkinList.quiet 带动选中条 quiet；DETAIL_V1 关不降；商店数量态、存档页列表降静默；
## 3. 页签／返回钮焦点（D255）：Q／E 让页签条拿焦点、别的键放掉；取消键按下返回钮亮、松手灭；窗口下手柄态画淡金双环、鼠标态不画；
## 4. 标题菜单对称（D254）：选中条 symmetric；窗口下左右 15% 处亮度对称，关回左浓右淡；选线卡选中＝淡金双环（D253）；
## 5. F-03 面包屑：整行下移 4px（字头离金线 ≥8px），DETAIL_V1 关 0；F-14：开淡金关灰、设置页不挂精魂。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const SHOT := Vector2i(1280, 720)
const GOLD_PX := Color("f2d08a")

var results: Array = []


func _ready() -> void:
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
	return DisplayServer.get_name() != "headless"


func _run() -> void:
	TestEnv.isolate("xiyou_ui_detail_t359")
	get_viewport().gui_disable_input = windowed()
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XUiSkin._clock_ms = 100000
	XUiSkin.DETAIL_V1 = true
	XFontScale.set_value("global", 100)
	_radius_logic()
	_quiet_logic()
	await _focus_logic()
	_crumb_and_values()
	if windowed():
		await _pixels()
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XUiSkin._clock_ms = -1
	XUiSkin.input_mode = -1
	XUiSkin.DETAIL_V1 = true
	await frames(2)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _key(code: Key, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	return e


# ---- 1 圆角 ----
func _radius_logic() -> void:
	check("btn_radius_46_is_9", XUiSkin.btn_radius(46.0) == 9)
	check("btn_radius_small_follows_half", XUiSkin.btn_radius(12.0) == 6)
	check("btn_radius_in_8_to_10", XUiSkin.btn_radius(52.0) >= 8 and XUiSkin.btn_radius(52.0) <= 10)
	XUiSkin.DETAIL_V1 = false
	check("btn_radius_off_full_pill", XUiSkin.btn_radius(46.0) == 23)
	check("button_radius_off_row", XSkinButton.style().corner_radius_top_left == XUiSkin.ROW_RADIUS)
	XUiSkin.DETAIL_V1 = true
	check("button_radius_on_9", XSkinButton.style().corner_radius_top_left == 9)


# ---- 2 静默选中 ----
func _quiet_logic() -> void:
	var l := XSkinList.new()
	l.size = Vector2(400, 300)
	add_child(l)
	l.set_items([{"text": "甲"}, {"text": "乙"}], 0)
	check("list_not_quiet_by_default", not l.bar.quiet_now())
	l.quiet = true
	check("list_quiet_drives_bar", l.bar.quiet and l.bar.quiet_now())
	XUiSkin.DETAIL_V1 = false
	check("list_quiet_off_no_demote", not l.bar.quiet_now())
	XUiSkin.DETAIL_V1 = true
	l.quiet = false
	check("list_quiet_release", not l.bar.quiet_now())
	l.queue_free()


# ---- 3 页签／返回钮焦点 ----
func _focus_logic() -> void:
	var tabs := XSkinInnerTabs.new()
	tabs.size = Vector2(500, XSkinInnerTabs.H)
	add_child(tabs)
	tabs.set_tabs(["物品", "消耗品", "武器"], 0)
	check("tabs_start_unfocused", not tabs.focused)
	tabs._input(_key(KEY_E))
	check("tabs_focus_on_page_key", tabs.focused)
	tabs._input(_key(KEY_DOWN))
	check("tabs_release_on_other_key", not tabs.focused)
	tabs._input(_key(KEY_Q))
	XUiSkin.DETAIL_V1 = false
	tabs._input(_key(KEY_DOWN))
	check("tabs_off_releases_focus", not tabs.focused)   # 关＝放掉、不画
	XUiSkin.DETAIL_V1 = true
	var rr := tabs.ring_rect()
	check("tabs_ring_rect_inside_height", rr.position.y >= 0.0 and rr.end.y <= tabs.size.y and rr.size.x > 20.0, rr)
	tabs.queue_free()
	var back := XSkinBackButton.new()
	add_child(back)
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	back._input(ev)
	check("back_focus_on_cancel_press", back.focused)
	var up := InputEventKey.new()
	up.keycode = KEY_ESCAPE
	up.physical_keycode = KEY_ESCAPE
	up.pressed = false
	back._input(up)
	check("back_release_on_cancel_up", not back.focused)
	# 按下取消后页面隐藏、隐藏后才松手：不得卡亮；隐藏本身也清位
	back.focused = false
	back._input(ev)
	check("back_focus_before_hide", back.focused)
	back.visible = false
	check("back_hide_clears_focus", not back.focused)
	back.visible = true
	back.focused = true
	back.visible = false
	back._input(up)
	check("back_release_while_hidden_clear", not back.focused)
	back.queue_free()
	var tb := XSkinInnerTabs.new()
	tb.size = Vector2(300, XSkinInnerTabs.H)
	add_child(tb)
	tb.set_tabs(["甲", "乙"], 0)
	var ll := XSkinList.new()
	add_child(ll)
	tb.linked_list = ll
	tb._input(_key(KEY_E))
	check("tabs_focus_quiets_linked_list", tb.focused and ll.quiet)
	tb.visible = false
	check("tabs_hide_clears_and_unquiets", not tb.focused and not ll.quiet)
	tb.queue_free()
	ll.queue_free()


# ---- 5 面包屑与开关色 ----
func _crumb_and_values() -> void:
	for pct in [100, 130]:
		XFontScale.set_value("global", pct)
		var gap := XUiSkin.PAD + 40 + XSkinSubPage.crumb_dy() - 0.95 * XUiSkin.fs(XSkinCrumb.FS) - (XUiSkin.PAD + 25.5)
		check("crumb_gap_ge8_at_%d" % pct, gap >= 8.0, gap)
	XFontScale.set_value("global", 130)
	var dy130 := XSkinSubPage.crumb_dy()
	XFontScale.set_value("global", 100)
	check("crumb_dy_grows_with_font", dy130 > XSkinSubPage.crumb_dy(), dy130)
	XUiSkin.DETAIL_V1 = false
	check("crumb_dy_off_0", XSkinSubPage.crumb_dy() == 0.0)
	check("value_color_off_fallback", XSkinSubPage.value_color("开", XUiSkin.TEXT) == XUiSkin.TEXT)
	check("on_color_off_old", XSkinSubPage.on_color(false) == XUiSkin.TEXT_2)
	XUiSkin.DETAIL_V1 = true
	check("value_on_gold", XSkinSubPage.value_color("开（2倍）", XUiSkin.TEXT) == XUiSkin.GOLD_LIGHT)
	check("value_off_gray", XSkinSubPage.value_color("关", XUiSkin.GOLD_LIGHT) == XUiSkin.TEXT_3)
	check("value_other_fallback", XSkinSubPage.value_color("120%", XUiSkin.TEXT_2) == XUiSkin.TEXT_2)
	check("on_color_off_gray", XSkinSubPage.on_color(false) == XUiSkin.TEXT_3 and XSkinSubPage.on_color(true) == XUiSkin.GOLD_LIGHT)
	var op := XSkinOptionsPage.new(null)
	check("options_no_gold_pair", op.currency_pairs().is_empty())
	op.free()
	var sp := XSkinSubPage.new(null)
	check("subpage_no_gold_pair", sp.currency_pairs().is_empty())
	sp.free()
	XUiSkin.DETAIL_V1 = false
	var op2 := XSkinOptionsPage.new(null)
	check("options_off_gold_pair_back", op2.currency_pairs().size() == 1)
	op2.free()
	XUiSkin.DETAIL_V1 = true


# ---- 窗口：取像素 ----
func _grab() -> Image:
	await frames(6)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _is_gold(c: Color) -> bool:
	return absf(c.r - GOLD_PX.r) < 0.07 and absf(c.g - GOLD_PX.g) < 0.07 and absf(c.b - GOLD_PX.b) < 0.09


func _gpos(node: Control, p: Vector2) -> Vector2i:
	var g := node.get_global_transform() * p
	return Vector2i(int(g.x), int(g.y))


func _stage(w := 640.0, bg := Color("090808")) -> Control:
	get_window().size = SHOT
	var root := Control.new()
	root.size = Vector2(w, SHOT.y)
	root.clip_contents = true
	var back := ColorRect.new()
	back.color = bg
	back.size = root.size
	root.add_child(back)
	add_child(root)
	return root


func _pixels() -> void:
	await _corner_pixels()
	await _tabs_ring_pixels()
	await _symmetric_pixels()
	await _line_card_pixels()


## 确认弹窗焦点钮（红底）左上角：圆角矩形 9 时离角 4px 处在钮内（红）、离角 1px 在圆角外（不红）
func _corner_pixels() -> void:
	XUiSkin.DETAIL_V1 = true
	XUiSkin.input_mode = XUiSkin.InputMode.GAMEPAD
	var root := _stage()
	var dlg := XSkinConfirm.new()
	dlg.size = Vector2(640, 330)
	dlg.position = Vector2(0, 150)
	root.add_child(dlg)
	dlg.setup({"title": "卖掉这一档？", "body": "会卖掉 14 件", "buttons": ["确认出售", "取消"], "danger": true})
	var img := await _grab()
	var r := dlg.button_rect(dlg.index)
	var c4 := img.get_pixelv(_gpos(dlg, r.position + Vector2(4, 4)))
	var c1 := img.get_pixelv(_gpos(dlg, r.position + Vector2(1, 1)))
	check("confirm_corner_rect9_filled_at_4", c4.r > c4.g * 1.8 and c4.r > 0.25, c4.to_html())
	check("confirm_corner_rounded_at_1", not (c1.r > c1.g * 1.8 and c1.r > 0.25), c1.to_html())
	root.queue_free()
	await frames(2)


func _tabs_ring_pixels() -> void:
	for mode in [XUiSkin.InputMode.GAMEPAD, XUiSkin.InputMode.MOUSE]:
		XUiSkin.input_mode = mode
		var root := _stage()
		var tabs := XSkinInnerTabs.new()
		tabs.position = Vector2(60, 100)
		tabs.size = Vector2(500, XSkinInnerTabs.H)
		root.add_child(tabs)
		tabs.set_tabs(["物品", "消耗品", "武器"], 1)
		tabs.focused = true
		var img := await _grab()
		var rr := tabs.ring_rect()
		var top := _gpos(tabs, Vector2(rr.position.x + rr.size.x * 0.5, rr.position.y))
		var c3 := img.get_pixelv(Vector2i(top.x, top.y - 3))
		var pad: bool = mode == XUiSkin.InputMode.GAMEPAD
		check("tabs_ring_%s" % ("gold" if pad else "absent_mouse"), _is_gold(c3) == pad, c3.to_html())
		root.queue_free()
		await frames(2)


## 对称选中条：宽 400，取 15% 与 85% 处，亮度差 < 0.03；关＝左浓右淡（左比右亮）
func _symmetric_pixels() -> void:
	if not XSkinArt.select_on():
		check("symmetric_skipped_no_art", true)
		return
	for on in [true, false]:
		XUiSkin.DETAIL_V1 = on
		var root := _stage(640.0, Color("000000"))
		var bar := XSkinSelectBar.new()
		bar.symmetric = true
		root.add_child(bar)
		bar.move_to(Rect2(100, 300, 400, 48), true)
		var img := await _grab()
		var l := img.get_pixelv(_gpos(bar, Vector2(60, 24))).get_luminance()
		var m := img.get_pixelv(_gpos(bar, Vector2(200, 24))).get_luminance()
		var r := img.get_pixelv(_gpos(bar, Vector2(340, 24))).get_luminance()
		if on:
			check("symmetric_left_right_equal", absf(l - r) < 0.02 and m >= l - 0.005, [l, m, r])
		else:
			check("symmetric_off_left_heavier", l > r + 0.01, [l, m, r])
		root.queue_free()
		await frames(2)
	XUiSkin.DETAIL_V1 = true


## 选线卡选中：卡边内 1～3px 处有淡金（双环外环贴卡边内），关＝没有
func _line_card_pixels() -> void:
	for on in [true, false]:
		XUiSkin.DETAIL_V1 = on
		var root := _stage()
		var card = XTianqiLineCards._Card.new()
		card.skin = true
		card.key = "war"
		card.selected = true
		card.size = Vector2(240, 400)
		card.position = Vector2(100, 100)
		root.add_child(card)
		var img := await _grab()
		var c := img.get_pixelv(_gpos(card, Vector2(card.size.x * 0.5, 1.0)))
		check("line_card_ring_%s" % ("gold" if on else "off_no_gold"), _is_gold(c) == on, c.to_html())
		root.queue_free()
		await frames(2)
	XUiSkin.DETAIL_V1 = true
