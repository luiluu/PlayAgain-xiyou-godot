extends Node
## 【cc·T349·未经审查】界面细节 D1b（私密仓 重制设定/界面细节规范_v0.1.md 第五节卡 D1b）：框形控件接淡金双环聚焦＋S2/S3/S4 色阶收口。
## 1. 确认弹窗、详情牌：横排钮距 12px（DETAIL_V1 关＝GRID）；手柄态焦点钮上缘外 1px 内黑、3px 淡金；鼠标／触屏态不留环；DETAIL_V1 关＝没有淡金环、仍画旧红选中条；
## 2. 数量条：手柄态底托外有双环，触屏态不留；关＝旧选中条；
## 3. XSkinButton：焦点样式是双环模式（ring），悬停样式只抬 S4；关＝旧红选中条样式；
## 4. 斑马纹：列表偶数行底色 S2z（0.08）、DETAIL_V1 关回 0.026；对比表同；子卡底（boss 状态）S2；
## 5. 详情牌展开面底 S3；确认弹窗底 S3（窗口下取像素）。
## 带 -- --out=<目录> 且有窗口时出三组验收图：d1b_confirm、d1b_card_stepper、d1b_bright_list（见各函数注释）。
##   拍：godot --audio-driver Dummy --path <工程> res://tests/xiyou_ui_detail_d1b.tscn -- --out=<目录>
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const SHOT := Vector2i(1280, 720)
const GOLD_PX := Color("f2d08a")

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
	return DisplayServer.get_name() != "headless"


func _run() -> void:
	TestEnv.isolate("xiyou_ui_detail_d1b")
	get_viewport().gui_disable_input = windowed()
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XUiSkin._clock_ms = 100000
	XUiSkin.DETAIL_V1 = true
	XFontScale.set_value("global", 100)
	_gap_logic()
	_button_styles()
	_zebra_logic()
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


# ---- 逻辑（无头也跑）----
func _gap_logic() -> void:
	var dlg := XSkinConfirm.new()
	dlg.size = Vector2(620, 330)
	add_child(dlg)
	dlg.setup({"title": "卖掉这一档？", "body": "会卖掉 14 件", "buttons": ["确认出售", "取消"]})
	check("confirm_gap_12", is_equal_approx(dlg.button_rect(1).position.x - dlg.button_rect(0).end.x, 12.0))
	XUiSkin.DETAIL_V1 = false
	check("confirm_gap_off_grid", is_equal_approx(dlg.button_rect(1).position.x - dlg.button_rect(0).end.x, float(XUiSkin.GRID)))
	XUiSkin.DETAIL_V1 = true
	dlg.queue_free()
	var card := XSkinCard.new()
	card.size = Vector2(540, 250)
	add_child(card)
	card.setup({"title": "饮血长刀", "buttons": [{"text": "装备", "primary": true}, {"text": "丢弃"}], "button_index": 0})
	check("card_gap_12", is_equal_approx(card.button_rect(1).position.x - card.button_rect(0).end.x, 12.0))
	XUiSkin.DETAIL_V1 = false
	check("card_gap_off_grid", is_equal_approx(card.button_rect(1).position.x - card.button_rect(0).end.x, float(XUiSkin.GRID)))
	XUiSkin.DETAIL_V1 = true
	card.queue_free()
	check("s3_tex_alpha_94", absf(XSkinConfirm.s3_panel_tex().get_image().get_pixel(48, 48).a - 0.94) < 0.01)


func _button_styles() -> void:
	var b := Button.new()
	XSkinButton.apply(b, "primary")
	var foc := b.get_theme_stylebox("focus") as XSkinSelectStyle
	var norm := b.get_theme_stylebox("normal") as StyleBoxFlat
	var hov := b.get_theme_stylebox("hover") as StyleBoxFlat
	check("button_focus_ring_mode", foc != null and foc.ring and foc.state == XUiSkin.SelState.FOCUS)
	XUiSkin.touch_override = 0
	b.free()
	b = Button.new()
	XSkinButton.apply(b, "primary")
	norm = b.get_theme_stylebox("normal") as StyleBoxFlat
	hov = b.get_theme_stylebox("hover") as StyleBoxFlat
	check("button_hover_real_s4", hov != null and hov.bg_color == XUiSkin.surface_c(XUiSkin.Surface.S4) and hov.bg_color.a >= 0.99, hov.bg_color.to_html() if hov else "null")
	check("button_hover_keeps_border", hov.border_color == norm.border_color and hov.get_border_width(SIDE_LEFT) == norm.get_border_width(SIDE_LEFT)
		and hov.corner_radius_top_left == norm.corner_radius_top_left, [hov.border_color, norm.border_color])
	b.free()
	XUiSkin.touch_override = 1
	b = Button.new()
	XSkinButton.apply(b, "primary")
	var hov_t := b.get_theme_stylebox("hover") as StyleBoxFlat
	check("button_hover_touch_no_lift", hov_t.bg_color == (b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color)
	b.free()
	XUiSkin.touch_override = -1
	XUiSkin.DETAIL_V1 = false
	var b2 := Button.new()
	XSkinButton.apply(b2, "primary")
	check("button_off_old_style", not (b2.get_theme_stylebox("focus") as XSkinSelectStyle).ring and b2.get_theme_stylebox("hover") is XSkinSelectStyle)
	XUiSkin.DETAIL_V1 = true
	b2.free()


func _zebra_logic() -> void:
	check("zebra_c_008", is_equal_approx(XUiSkin.zebra_c().a, 0.08))
	check("s2_overlay_009", is_equal_approx(XUiSkin.surface_overlay("s2").a, 0.09))


# ---- 窗口：取像素＋验收图 ----
func _grab() -> Image:
	await frames(6)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _is_gold(c: Color) -> bool:
	return absf(c.r - GOLD_PX.r) < 0.07 and absf(c.g - GOLD_PX.g) < 0.07 and absf(c.b - GOLD_PX.b) < 0.09


func _redraw_all(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()
	for c in n.get_children():
		_redraw_all(c)


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
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	await _confirm_pixels()
	await _card_stepper_pixels()
	await _bright_list_pixels()
	await _ring_nav_pixels()
	await _hover_pixels()
	await _gear_zebra_pixels()


func _confirm_dlg(root: Control) -> XSkinConfirm:
	var dlg := XSkinConfirm.new()
	dlg.size = Vector2(640, 330)
	dlg.position = Vector2(0, 150)
	root.add_child(dlg)
	dlg.setup({"title": "卖掉这一档？", "body": "会卖掉 14 件，得 4,200", "buttons": ["确认出售", "取消"], "danger": true})
	return dlg


## 验收图 1：确认弹窗横排按钮（手柄态）左＝DETAIL_V1 关（红叠红、8px），右＝开（S3 底、双环、12px）
func _confirm_pixels() -> void:
	var imgs := {}
	for on in [false, true]:
		XUiSkin.DETAIL_V1 = on
		XUiSkin.input_mode = XUiSkin.InputMode.GAMEPAD
		var root := _stage()
		var dlg := _confirm_dlg(root)
		var img := await _grab()
		imgs[on] = img
		var r := dlg.button_rect(dlg.index)
		var top := _gpos(dlg, Vector2(r.position.x + r.size.x * 0.5, r.position.y))
		var c_in := img.get_pixelv(Vector2i(top.x, top.y - 1))
		var c_out := img.get_pixelv(Vector2i(top.x, top.y - 3))
		if on:
			check("confirm_pad_inner_black", c_in.v < 0.12, c_in.to_html())
			check("confirm_pad_outer_gold", _is_gold(c_out), c_out.to_html())
			# 两钮净缝：缝中线上没有任何金色
			var r0 := dlg.button_rect(0)
			var mid := _gpos(dlg, Vector2((r0.end.x + dlg.button_rect(1).position.x) * 0.5, r0.position.y + r0.size.y * 0.5))
			check("confirm_gap_no_gold", not _is_gold(img.get_pixelv(mid)), img.get_pixelv(mid).to_html())
			# 弹窗底是 S3：面板左上内侧取点，亮度高于旧底（#241f1e）
			var pr := dlg.panel_rect()
			var pp := _gpos(dlg, pr.position + Vector2(40, 60))
			check("confirm_panel_s3", img.get_pixelv(pp).v > 0.17, img.get_pixelv(pp).to_html())
			# 触屏：不留环
			XUiSkin.input_mode = XUiSkin.InputMode.TOUCH
			_redraw_all(root)
			var img_t := await _grab()
			check("confirm_touch_no_ring", not _is_gold(img_t.get_pixelv(Vector2i(top.x, top.y - 3))), img_t.get_pixelv(Vector2i(top.x, top.y - 3)).to_html())
			XUiSkin.input_mode = XUiSkin.InputMode.MOUSE
			_redraw_all(root)
			var img_m := await _grab()
			check("confirm_mouse_no_ring", not _is_gold(img_m.get_pixelv(Vector2i(top.x, top.y - 3))))
		else:
			check("confirm_off_no_gold_ring", not _is_gold(c_out), c_out.to_html())
		root.queue_free()
		await frames(2)
	_save_pair("d1b_confirm.png", imgs[false], imgs[true])
	XUiSkin.DETAIL_V1 = true


func _card_stepper_stage(root: Control) -> Array:
	var card := XSkinCard.new()
	card.position = Vector2(40, 40)
	card.size = Vector2(540, 250)
	root.add_child(card)
	card.setup({"title": "饮血长刀", "subtitle": "武器 · 传说", "desc": "攻击 +128　暴击 +6%　吸血 3%",
		"buttons": [{"text": "装备", "primary": true}, {"text": "丢弃"}], "button_index": 0})
	var st := XSkinStepper.new()
	st.position = Vector2(100, 380)
	st.size = Vector2(440, XSkinStepper.H)
	st.sound = false
	root.add_child(st)
	st.set_range(1, 999, 1)
	st.set_value(10)
	st.focused = true
	return [card, st]


## 验收图 2：详情牌双按钮＋数量条，左＝手柄态，右＝触屏点完后（无残留双环）
func _card_stepper_pixels() -> void:
	var imgs := {}
	for mode in [XUiSkin.InputMode.GAMEPAD, XUiSkin.InputMode.TOUCH]:
		XUiSkin.input_mode = mode
		var root := _stage()
		var parts := _card_stepper_stage(root)
		var card: XSkinCard = parts[0]
		var st: XSkinStepper = parts[1]
		var img := await _grab()
		imgs[mode] = img
		var r := card.button_rect(0)
		var top := _gpos(card, Vector2(r.position.x + r.size.x * 0.5, r.position.y))
		var s_top := _gpos(st, Vector2(st.size.x * 0.5, (st.size.y - XSkinStepper.H) / 2.0 - 3.0))
		var pad: bool = mode == XUiSkin.InputMode.GAMEPAD
		var tag := "pad" if pad else "touch"
		var cb := img.get_pixelv(Vector2i(top.x, top.y - 3))
		var sb := img.get_pixelv(Vector2i(s_top.x, s_top.y - 3))
		check("card_%s_ring_%s" % [tag, "gold" if pad else "absent"], _is_gold(cb) == pad, cb.to_html())
		check("stepper_%s_ring_%s" % [tag, "gold" if pad else "absent"], _is_gold(sb) == pad, sb.to_html())
		if pad:
			check("card_pad_inner_black", img.get_pixelv(Vector2i(top.x, top.y - 1)).v < 0.12)
		root.queue_free()
		await frames(2)
	_save_pair("d1b_card_stepper.png", imgs[XUiSkin.InputMode.GAMEPAD], imgs[XUiSkin.InputMode.TOUCH])
	# 详情牌展开面底 S3
	XUiSkin.input_mode = XUiSkin.InputMode.GAMEPAD
	var root2 := _stage()
	var card2 := XSkinCard.new()
	card2.position = Vector2(40, 40)
	card2.size = Vector2(540, 400)
	root2.add_child(card2)
	var long_desc := ""
	for i in 30:
		long_desc += "第%d行说明文字。" % i
	card2.setup({"title": "饮血长刀", "desc": long_desc, "fold": true, "buttons": [{"text": "装备", "primary": true}], "button_index": 0})
	await frames(3)
	card2.set_expanded(true)
	var img2 := await _grab()
	var sh: Control = card2._sheet
	var sp := _gpos(sh, Vector2(sh.size.x - 30.0, 40.0)) if sh != null else Vector2i.ZERO
	check("card_sheet_s3", card2.expanded and sh != null and img2.get_pixelv(sp).v > 0.15, [card2.expanded, img2.get_pixelv(sp).to_html()])
	root2.queue_free()
	await frames(2)


func _bright_list(root: Control) -> Array:
	var smoke := Panel.new()   # 返修（小A核 P2-1）：列表放进烟底面板，实测 S2z 在烟底颗粒上的可读性
	smoke.add_theme_stylebox_override("panel", XUiSkin.panel_style())
	smoke.position = Vector2(16, 24)
	smoke.size = Vector2(608, 390)
	root.add_child(smoke)
	var lst := XSkinList.new()
	lst.position = Vector2(30, 40)
	lst.size = Vector2(580, 360)
	var arr := []
	for i in 7:
		arr.append({"text": "烈焰刀 +%d" % i, "right": str(100 + i * 11)})
	root.add_child(lst)
	lst.set_items(arr)
	lst.index = 0
	var b := Button.new()
	b.text = "装备"
	b.position = Vector2(60, 440)
	b.size = Vector2(140, 52)
	XSkinButton.apply(b, "primary")
	root.add_child(b)
	var b2 := Button.new()
	b2.text = "丢弃"
	b2.position = Vector2(212, 440)
	b2.size = Vector2(140, 52)
	XSkinButton.apply(b2)
	root.add_child(b2)
	return [lst, b, b2]


## 验收图 3：亮火光背景＋烟底列表＋框形按钮（手柄态），左＝关，右＝开（斑马纹 S2z、内暗隔离环）
func _bright_list_pixels() -> void:
	var imgs := {}
	var zebra_px := {}
	for on in [false, true]:
		XUiSkin.DETAIL_V1 = on
		XUiSkin.input_mode = XUiSkin.InputMode.GAMEPAD
		var root := _stage(640.0, Color("e8892a"))
		var parts := _bright_list(root)
		var lst: XSkinList = parts[0]
		var b: Button = parts[1]
		b.grab_focus()
		var img := await _grab()
		imgs[on] = img
		var rr := lst.cell_rect(1)
		var zp := _gpos(lst, rr.position + Vector2(rr.size.x * 0.5, 4.0))
		zebra_px[on] = img.get_pixelv(zp)
		if on:
			var top := _gpos(b, Vector2(b.size.x * 0.5, 0))
			var c_in := img.get_pixelv(Vector2i(top.x, top.y - 1))
			var c_out := img.get_pixelv(Vector2i(top.x, top.y - 3))
			check("button_pad_inner_dark_on_bright", c_in.v < 0.2, c_in.to_html())
			check("button_pad_outer_gold", _is_gold(c_out), c_out.to_html())
			XUiSkin.input_mode = XUiSkin.InputMode.TOUCH
			_redraw_all(root)
			var img_t := await _grab()
			check("button_touch_no_ring", not _is_gold(img_t.get_pixelv(Vector2i(top.x, top.y - 3))), img_t.get_pixelv(Vector2i(top.x, top.y - 3)).to_html())
		root.queue_free()
		await frames(2)
	# 斑马纹行底在同一位置：开比关亮（0.08 vs 0.026）
	check("zebra_brighter_on", (zebra_px[true] as Color).g > (zebra_px[false] as Color).g + 0.01, [zebra_px[false].to_html(), zebra_px[true].to_html()])
	_save_pair("d1b_bright_list.png", imgs[false], imgs[true])
	XUiSkin.DETAIL_V1 = true


## 左右拼成一张 1280×720 存盘
func _save_pair(name: String, left: Image, right: Image) -> void:
	if out_dir == "":
		return
	var out := Image.create(SHOT.x, SHOT.y, false, Image.FORMAT_RGBA8)
	out.fill(Color("090808"))
	out.blit_rect(left, Rect2i(0, 0, 640, SHOT.y), Vector2i(0, 0))
	out.blit_rect(right, Rect2i(0, 0, 640, SHOT.y), Vector2i(640, 0))
	check("saved_" + name, out.save_png(out_dir.path_join(name)) == OK)


func _is_red(c: Color) -> bool:
	return c.r > 0.6 and c.g < 0.5 and c.b < 0.45 and c.r > c.g + 0.3


## 返修（小A核 P1-1）：选中球双环在所有页都画（非装备页没有环纹第 3 层）；手柄态无红晕红圈；触屏回原红描边；关＝无金环
func _ring_nav_pixels() -> void:
	for variant in ["plain", "layers"]:
		for case in ["pad", "touch", "off"]:
			XUiSkin.DETAIL_V1 = case != "off"
			XUiSkin.input_mode = XUiSkin.InputMode.TOUCH if case == "touch" else XUiSkin.InputMode.GAMEPAD
			var root := _stage(640.0)
			var rn := XSkinRingNav.new()
			rn.size = Vector2(640, 600)
			rn.items = [{"name": "甲"}, {"name": "乙"}, {"name": "丙"}]
			if variant == "layers":
				rn.orb_frames = {1: {"outline": Color("d9925c"), "outline_w": 2.0}}
			root.add_child(rn)
			rn.index = 0
			var img := await _grab()
			var p := rn.item_pos(0)
			var r := rn.orb_radius * rn.item_scale(0)
			var gold := false
			var red := false
			var g0 := _gpos(rn, p)
			for dy in range(int(r) - 1, int(r) + 9):   # 球上方一条竖线（离开球体后）
				var c := img.get_pixelv(Vector2i(g0.x, g0.y - dy))
				gold = gold or _is_gold(c)
				red = red or _is_red(c)
			var tag := "ringnav_%s_%s" % [variant, case]
			if case == "pad":
				check(tag + "_gold", gold)
				check(tag + "_no_red", not red)
			elif case == "touch":
				check(tag + "_no_gold", not gold)
				check(tag + "_old_red", red)
			else:
				check(tag + "_no_gold", not gold)
			root.queue_free()
			await frames(2)
	XUiSkin.DETAIL_V1 = true


## 返修（小A核 P1-2）：悬停底＝真 S4 实心＋保留边框（把 hover 样式真画出来取像素）
func _hover_pixels() -> void:
	XUiSkin.touch_override = 0
	var root := _stage(640.0)
	var b := Button.new()
	XSkinButton.apply(b, "primary")
	var hov := b.get_theme_stylebox("hover") as StyleBoxFlat
	var pn := Panel.new()
	pn.position = Vector2(100, 100)
	pn.size = Vector2(200, 60)
	pn.add_theme_stylebox_override("panel", hov)
	root.add_child(pn)
	var img := await _grab()
	var mid := img.get_pixelv(Vector2i(200, 130))
	var edge := img.get_pixelv(Vector2i(200, 100))
	var s4 := XUiSkin.surface_c(XUiSkin.Surface.S4)
	check("hover_px_center_s4", absf(mid.r - s4.r) < 0.03 and absf(mid.g - s4.g) < 0.03, [mid.to_html(), s4.to_html()])
	check("hover_px_border_kept", absf(edge.r - mid.r) + absf(edge.g - mid.g) > 0.05, [edge.to_html(), mid.to_html()])
	b.free()
	root.queue_free()
	XUiSkin.touch_override = -1
	await frames(2)


## 返修（小A核 P2-1）：详情对比表斑马纹实绘（S2z 0.08）；开比关亮、开时≈ 底＋0.08×f0e6d8。Boss 状态页的 S2 子卡是 XMVCanvas 内画，这里没有实绘断言（见交付单）
func _gear_zebra_pixels() -> void:
	var px := {}
	for on in [false, true]:
		XUiSkin.DETAIL_V1 = on
		var root := _stage(700.0)
		var g := XSkinGearDetail.new()
		g.size = Vector2(700, 520)
		root.add_child(g)
		g.tab = 1
		g.compare = true
		g._cmp = [["最大生命", 12345, 13456], ["最大魔力", 2345, 2345], ["攻击", 345, 99]]
		g._place()
		g._content_h = g._measure()
		await frames(3)
		var img := await _grab()
		# 第 0 行斑马条空白处（行左上内侧 4px，字在 x=12 以后但上边 2px 内没有字）
		var gp := g.body.get_global_transform() * Vector2(w_edge(), 2 + 3)
		px[on] = img.get_pixelv(Vector2i(int(gp.x), int(gp.y)))
		root.queue_free()
		await frames(2)
	check("gear_zebra_s2z_real", (px[true] as Color).g > (px[false] as Color).g + 0.015 and absf((px[true] as Color).g - (0.035 + 0.08 * 0.9)) < 0.05, [px[false].to_html(), px[true].to_html()])
	XUiSkin.DETAIL_V1 = true


func w_edge() -> float:
	return 300.0
