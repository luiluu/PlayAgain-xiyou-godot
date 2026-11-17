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
var notice := ""
var desc := ""
## [{title, lines: [{left, right, color, right_color}]}] 或 [{title, text}] 或 [{title, rows: [{text, color}]}]（每行自动换行、各自颜色；title 可空）
var sections: Array = []
## 底部按钮之上给别的控件（如「给谁用」目标列表）留的高度：说明、分节画到这里为止
var reserve_bottom := 0.0
## [{text, primary, disabled}]（disabled：变暗、不触发）
var buttons: Array = []
var button_index := -1
var pad := XUiSkin.PAD_LG
## T024 选中放大：焦点按钮的字放大（按钮框不变，字放不下就不放大）
var sel_scale: XSkinSelScale
const BUTTON_H := 46.0
const LINE_H := 30.0
const SECTION_H := 36.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	sel_scale = XSkinSelScale.attach(self)
	resized.connect(queue_redraw)


func setup(d: Dictionary) -> XSkinCard:
	for k in d:
		set(k, d[k])
	queue_redraw()
	return self


## 说明、分节能画到的最低处（按钮和 reserve_bottom 之上）
func content_bottom() -> float:
	return size.y - pad - (BUTTON_H + XUiSkin.GRID if not buttons.is_empty() else 0.0) - reserve_bottom


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
		if not bool(buttons[button_index].get("disabled", false)):
			button_pressed.emit(button_index)
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in buttons.size():
			if button_rect(i).has_point(event.position):
				button_index = i
				queue_redraw()
				if not bool(buttons[i].get("disabled", false)):
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
	var bottom := content_bottom()
	var y := float(pad)
	var x := float(pad)
	if icon != null:
		draw_texture_rect(icon, Rect2(x, y, 48, 48), false)
		x += 48 + 12
	if title != "":
		var ty := y + (48 - title_size) / 2.0 + title_size * 0.86 if icon != null else y + title_size * 0.86
		var fit := XSkinList.fit_text(head, title, pad + w - x, title_size, 20)   # 长名字先缩到 20 号，再放不下加省略号
		XUiSkin.ds(self, head, Vector2(x, ty), fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1], title_color)
		y += maxf(48.0 if icon != null else 0.0, title_size * 1.25)
	if subtitle != "":
		y += 4
		XUiSkin.ds(self, body, Vector2(pad, y + XUiSkin.FS_AUX_MAX * 0.86), subtitle, HORIZONTAL_ALIGNMENT_LEFT, w, XUiSkin.FS_AUX, XUiSkin.TEXT_2)
		y += XUiSkin.FS_AUX_MAX + 6
	if notice != "":
		y += 6
		var npara := TextParagraph.new()
		npara.width = w - 20.0
		npara.add_string(notice, body, XUiSkin.FS_AUX)
		var nlh := roundf(XUiSkin.FS_AUX * 1.45)
		var ncnt := maxi(1, npara.get_line_count())
		var nh := float(ncnt) * nlh + 10.0
		if y + nh <= bottom:
			var nsb := StyleBoxFlat.new()
			nsb.bg_color = Color(XUiSkin.GOLD, 0.14)
			nsb.border_color = Color(XUiSkin.GOLD, 0.55)
			nsb.set_border_width_all(1)
			nsb.set_corner_radius_all(XUiSkin.ROW_RADIUS)
			nsb.draw(ci, Rect2(pad, y, w, nh))
			for li in npara.get_line_count():
				var r := npara.get_line_range(li)
				XUiSkin.ds(self, body, Vector2(pad + 10.0, y + 5.0 + float(li) * nlh + XUiSkin.FS_AUX * 0.96), notice.substr(r.x, r.y - r.x), HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, XUiSkin.FS_AUX, XUiSkin.GOLD_LIGHT)
			y += nh + 4
	if desc != "":
		y += 8
		y = _paragraph(body, desc, y, w, XUiSkin.FS_AUX_MAX, XUiSkin.TEXT, bottom)
	for sec in sections:
		if y + SECTION_H > bottom:
			break
		y += 6
		draw_line(Vector2(pad, y), Vector2(pad + w, y), Color(XUiSkin.LINE, 0.14), 1.0)
		y += 4
		if str(sec.get("title", "")) != "":
			XUiSkin.ds(self, body, Vector2(pad, y + XUiSkin.FS_AUX_MAX * 1.1), str(sec.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, w, XUiSkin.FS_AUX_MAX, XUiSkin.GOLD)
			y += SECTION_H - 10
		for row in sec.get("rows", []):
			y = _paragraph(body, str(row.get("text", "")), y, w, XUiSkin.FS_AUX, row.get("color", XUiSkin.TEXT_2), bottom, row.get("spans", []))
		if sec.has("text"):
			y = _paragraph(body, str(sec.text), y, w, XUiSkin.FS_AUX, XUiSkin.TEXT_2, bottom)
		for ln in sec.get("lines", []):
			if y + LINE_H > bottom:
				break
			var base := y + LINE_H / 2.0
			XUiSkin.ds(self, body, Vector2(pad, base + 15 * 0.36), str(ln.get("left", "")), HORIZONTAL_ALIGNMENT_LEFT, w * 0.6, 15, ln.get("color", XUiSkin.TEXT_2))
			var rt := str(ln.get("right", ""))
			if rt != "":
				var rw := num.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
				XUiSkin.ds(self, num, Vector2(pad + w - rw, base + 21 * 0.36), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, ln.get("right_color", XUiSkin.TEXT))
			y += LINE_H
	sel_scale.sel(button_index if button_index >= 0 and button_index < buttons.size() else null)
	for i in buttons.size():
		var r := button_rect(i)
		var b: Dictionary = buttons[i]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(BUTTON_H / 2))
		if bool(b.get("primary", false)) and not bool(b.get("disabled", false)):
			XUiSkin.primary_button_style(sb, i == button_index)
		else:
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color(XUiSkin.LINE, 0.55)
			sb.set_border_width_all(1)
		sb.draw(ci, r)
		if i == button_index:
			XUiSkin.draw_select(ci, r.grow(3), XUiSkin.breath_alpha())
		var t := str(b.get("text", ""))
		var bfs := XSkinSelScale.fs(XUiSkin.FS_LIST, sel_scale.k(i), floori(r.size.y * 0.66))
		var tw := body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
		if bfs != XUiSkin.FS_LIST and tw > r.size.x - 12.0:
			bfs = XUiSkin.FS_LIST
			tw = body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
		XUiSkin.ds(self, body, Vector2(r.position.x + (r.size.x - tw) / 2.0, r.position.y + r.size.y / 2.0 + bfs * 0.36), t,
			HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, XUiSkin.TEXT_3 if bool(b.get("disabled", false)) else XUiSkin.TEXT)


## spans（可选）：[[字, 颜色], …] 拼起来＝text，逐段上色（装备「自带」属性分色，T095）
func _paragraph(f: Font, text: String, y: float, w: float, fs: int, col: Color, bottom: float, spans := []) -> float:
	var lh := roundf(fs * 1.5)
	var para := TextParagraph.new()
	para.width = w
	para.add_string(text, f, fs)
	for li in para.get_line_count():
		if y + lh > bottom:
			break
		var line_text_range := para.get_line_range(li)
		if spans.is_empty():
			XUiSkin.ds(self, f, Vector2(pad, y + fs * 1.1), text.substr(line_text_range.x, line_text_range.y - line_text_range.x), HORIZONTAL_ALIGNMENT_LEFT, w, fs, col)
		else:
			_span_line(f, spans, line_text_range.x, line_text_range.y, Vector2(pad, y + fs * 1.1), fs)
		y += lh
	return y


## 画一行里 [from, to) 这段字，按 spans 换色
func _span_line(f: Font, spans: Array, from: int, to: int, at: Vector2, fs: int) -> void:
	var off := 0
	var x := at.x
	for sp in spans:
		var s := str(sp[0])
		var a := maxi(from, off)
		var b := mini(to, off + s.length())
		if b > a:
			var piece := s.substr(a - off, b - a)
			XUiSkin.ds(self, f, Vector2(x, at.y), piece, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, sp[1])
			x += f.get_string_size(piece, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		off += s.length()
