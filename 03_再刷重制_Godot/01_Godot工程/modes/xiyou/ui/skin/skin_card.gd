class_name XSkinCard
extends Control
## 【cc·天启篇·未经审查】详情牌：黑面板上从上往下排 图标＋名字（思源宋体，品质色）、一行辅助小字、说明（自动换行）、
## 若干分节（旧金小标题＋左名右值的行，或一段文字）、底部一排按钮（主按钮绯红渐变，焦点按钮带红乙选中条）。
## 内容太长时从下往上裁（说明、分节被按钮挡住的部分不画）；按钮总在底部。

signal button_pressed(index: int)

var icon: Texture2D
var title := ""
var title_color := XUiSkin.TEXT
var title_size := XUiSkin.FS_CARD
var subtitle := ""
var desc := ""
## [{title, lines: [{left, right, color, right_color}]}] 或 [{title, text}]
var sections: Array = []
## [{text, primary}]
var buttons: Array = []
var button_index := -1
var pad := XUiSkin.PAD_LG
const BUTTON_H := 46.0
const LINE_H := 30.0
const SECTION_H := 36.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func setup(d: Dictionary) -> XSkinCard:
	for k in d:
		set(k, d[k])
	queue_redraw()
	return self


func button_rect(i: int) -> Rect2:
	var n := buttons.size()
	if n == 0:
		return Rect2()
	var w := (size.x - pad * 2 - XUiSkin.GRID * (n - 1)) / n
	return Rect2(pad + i * (w + XUiSkin.GRID), size.y - pad - BUTTON_H, w, BUTTON_H)


func handle_input(event: InputEvent) -> bool:
	if buttons.is_empty():
		return false
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		var d := -1 if event.is_action("ui_left") else 1
		button_index = 0 if button_index < 0 else posmod(button_index + d, buttons.size())   # 第一次按左右先落到第一个按钮
		queue_redraw()
		return true
	if event.is_action_pressed("ui_accept") and button_index >= 0:
		button_pressed.emit(button_index)
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in buttons.size():
			if button_rect(i).has_point(event.position):
				button_index = i
				queue_redraw()
				button_pressed.emit(i)
				accept_event()
				return


func _draw() -> void:
	var ci := get_canvas_item()
	XUiSkin.shadow_style().draw(ci, Rect2(Vector2.ZERO, size))
	XUiSkin.panel_style().draw(ci, Rect2(Vector2.ZERO, size))
	var body := XUiSkin.font("body")
	var head := XUiSkin.font("title")
	var num := XUiSkin.font("num")
	var w := size.x - pad * 2
	var bottom := size.y - pad - (BUTTON_H + XUiSkin.GRID if not buttons.is_empty() else 0.0)
	var y := float(pad)
	var x := float(pad)
	if icon != null:
		draw_texture_rect(icon, Rect2(x, y, 48, 48), false)
		x += 48 + 12
	if title != "":
		var ty := y + (48 - title_size) / 2.0 + title_size * 0.86 if icon != null else y + title_size * 0.86
		draw_string(head, Vector2(x, ty), title, HORIZONTAL_ALIGNMENT_LEFT, pad + w - x, title_size, title_color)
		y += maxf(48.0 if icon != null else 0.0, title_size * 1.25)
	if subtitle != "":
		y += 4
		draw_string(body, Vector2(pad, y + XUiSkin.FS_AUX_MAX * 0.86), subtitle, HORIZONTAL_ALIGNMENT_LEFT, w, XUiSkin.FS_AUX, XUiSkin.TEXT_2)
		y += XUiSkin.FS_AUX_MAX + 6
	if desc != "":
		y += 8
		y = _paragraph(body, desc, y, w, XUiSkin.FS_AUX_MAX, XUiSkin.TEXT, bottom)
	for sec in sections:
		if y + SECTION_H > bottom:
			break
		y += 6
		draw_line(Vector2(pad, y), Vector2(pad + w, y), Color(XUiSkin.LINE, 0.14), 1.0)
		y += 4
		draw_string(body, Vector2(pad, y + XUiSkin.FS_AUX_MAX * 1.1), str(sec.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, w, XUiSkin.FS_AUX_MAX, XUiSkin.GOLD)
		y += SECTION_H - 10
		if sec.has("text"):
			y = _paragraph(body, str(sec.text), y, w, XUiSkin.FS_AUX, XUiSkin.TEXT_2, bottom)
		for ln in sec.get("lines", []):
			if y + LINE_H > bottom:
				break
			var base := y + LINE_H / 2.0
			draw_string(body, Vector2(pad, base + 15 * 0.36), str(ln.get("left", "")), HORIZONTAL_ALIGNMENT_LEFT, w * 0.6, 15, ln.get("color", XUiSkin.TEXT_2))
			var rt := str(ln.get("right", ""))
			if rt != "":
				var rw := num.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
				draw_string(num, Vector2(pad + w - rw, base + 21 * 0.36), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, ln.get("right_color", XUiSkin.TEXT))
			y += LINE_H
	for i in buttons.size():
		var r := button_rect(i)
		var b: Dictionary = buttons[i]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(BUTTON_H / 2))
		if bool(b.get("primary", false)):
			sb.bg_color = XUiSkin.SEL_FILL
			sb.shadow_color = Color(XUiSkin.SEL_FILL, 0.5)
			sb.shadow_size = 7
		else:
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color(XUiSkin.LINE, 0.55)
			sb.set_border_width_all(1)
		sb.draw(ci, r)
		if i == button_index:
			XUiSkin.draw_select(ci, r.grow(3), XUiSkin.breath_alpha())
		var t := str(b.get("text", ""))
		var tw := body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_LIST).x
		draw_string(body, Vector2(r.position.x + (r.size.x - tw) / 2.0, r.position.y + r.size.y / 2.0 + XUiSkin.FS_LIST * 0.36), t,
			HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_LIST, XUiSkin.TEXT)


func _paragraph(f: Font, text: String, y: float, w: float, fs: int, col: Color, bottom: float) -> float:
	var lh := roundf(fs * 1.5)
	var para := TextParagraph.new()
	para.width = w
	para.add_string(text, f, fs)
	for li in para.get_line_count():
		if y + lh > bottom:
			break
		var line_text_range := para.get_line_range(li)
		draw_string(f, Vector2(pad, y + fs * 1.1), text.substr(line_text_range.x, line_text_range.y - line_text_range.x), HORIZONTAL_ALIGNMENT_LEFT, w, fs, col)
		y += lh
	return y
