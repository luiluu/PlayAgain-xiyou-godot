class_name XSkinCard
extends Control
## 【cc·天启篇·未经审查】详情牌：黑面板上从上往下排 图标＋名字（思源宋体，品质色）、一行辅助小字、说明（自动换行）、
## 若干分节（旧金小标题＋左名右值的行，或一段文字）、底部一排按钮（主按钮绯红渐变，焦点按钮带红乙选中条）。
## 内容太长时从下往上裁（说明、分节被按钮挡住的部分不画）；按钮总在底部。
## T288 卡 S（长说明卡分节）：分节多两种写法——cells（两列「名 值」格子）、行的 dim（还没到的分支画暗字），节可带 size（字号，行距 1.6 倍）；
## fold 开时放不下不再硬裁：牌底 56 高渐隐＋「Y 看完整说明 ▾」，按 Y 或点这一条，牌向左展开成 2 倍宽、整高（expand_bounds），
## 再按 Y／点一下／取消收回；展开后还放不下就能滚（手指拖、滚轮、上下键）。fold 关（默认）时画法与之前一样。

signal button_pressed(index: int)
signal expanded_changed(on: bool)

var icon: Texture2D
var title := ""
var title_color := XUiSkin.TEXT
var title_size := XUiSkin.FS_CARD
var subtitle := ""
var notice := ""
var desc := ""
## [{title, lines: [{left, right, color, right_color}]}] 或 [{title, text}] 或 [{title, rows: [{text, color, spans, dim}]}]（每行自动换行、各自颜色；title 可空）
## 或 [{title, cells: [[名, 值], …]}]（T288：两列格子，名次要字、值正文；一格放不下半宽就独占一行）；各节可带 size（rows／cells 的字号）
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

## ---- T288 长说明卡 ----
## 牌边描边色（透明＝不画；说明卡按品质上色）
var border_color := Color(0, 0, 0, 0)
## 放不下时渐隐＋「看完整说明」可展开；false＝照旧从下面裁
var fold := false
## 展开后牌的上下沿（画布坐标）
var expand_bounds := Vector2(XUiSkin.TOP, XUiSkin.BOTTOM)
## 收起时按 Y 展开要用掉这次按键；展开时按 Y 收起是否放行给页面（战斗里放行：Y 再按一次就照旧收起整张详情）
var y_pass_on_collapse := false
var expanded := false
var scroll := 0.0
const FADE_H := 56.0
const STRIP_H := 40.0
const SCROLL_STEP := 54.0
var _overflow := false
var _max_scroll := 0.0
var _content_key := ""
var _sheet: Control
var _drag := XSkinDrag.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	sel_scale = XSkinSelScale.attach(self)
	resized.connect(queue_redraw)


func setup(d: Dictionary) -> XSkinCard:
	for k in d:
		set(k, d[k])
	if fold:
		var key := str([title, subtitle, desc, sections])
		if key != _content_key:   # 换了一张牌：收起、回到顶
			_content_key = key
			scroll = 0.0
			if expanded:
				set_expanded(false)
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


## 牌宽 width 时内容（不裁）要多高：牌头＋各节＋上下内边距＋按钮
func natural_height(width: float) -> float:
	var y := _body(self, pad, pad, width - pad * 2, INF, true)
	return y + pad + (BUTTON_H + XUiSkin.GRID if not buttons.is_empty() else 0.0) + reserve_bottom


## 收起时牌底「看完整说明」这一条（整条可点）
func strip_rect() -> Rect2:
	var cb := content_bottom()
	return Rect2(0, cb - FADE_H + 8.0, size.x, FADE_H + pad - 8.0)


func can_expand() -> bool:
	return fold and _overflow


func set_expanded(on: bool) -> void:
	if on == expanded:
		return
	expanded = on
	scroll = 0.0
	if on:
		if _sheet == null:
			_sheet = Control.new()
			_sheet.clip_contents = true
			_sheet.z_index = 20
			_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
			_sheet.draw.connect(_draw_sheet)
			_sheet.gui_input.connect(_sheet_input)
			add_child(_sheet)
		var r := expanded_rect()
		_sheet.position = r.position
		_sheet.size = r.size
		_sheet.visible = true
		_sheet.queue_redraw()
	elif _sheet != null:
		_sheet.visible = false
	_drag.release()
	queue_redraw()
	expanded_changed.emit(on)


## 展开后的牌（本牌坐标）：右沿不动向左展开成 2 倍宽（画面放不下就贴左边 16），上下取 expand_bounds
func expanded_rect() -> Rect2:
	var g := get_global_rect().position if is_inside_tree() else position
	var vw := get_viewport_rect().size.x if is_inside_tree() else 1280.0
	var w2 := minf(size.x * 2.0, vw - 32.0)
	var x := clampf(g.x + size.x - w2, 16.0, maxf(16.0, vw - 16.0 - w2))
	return Rect2(Vector2(x, expand_bounds.x) - g, Vector2(w2, maxf(0.0, expand_bounds.y - expand_bounds.x)))


func scroll_by(dy: float) -> void:
	scroll = clampf(scroll + dy, 0.0, _max_scroll)
	if _sheet != null:
		_sheet.queue_redraw()


static func _is_y(event: InputEvent) -> bool:
	if event is InputEventKey:
		var k := event as InputEventKey
		return k.pressed and not k.echo and k.keycode == KEY_Y
	if event is InputEventJoypadButton:
		var j := event as InputEventJoypadButton
		return j.pressed and j.button_index == JOY_BUTTON_Y
	return false


## Y 展开／收起、展开时上下键滚动、取消收回：在页面收键之前先看（只在可展开或已展开时管）
func _input(event: InputEvent) -> void:
	if not fold or not is_visible_in_tree() or not (expanded or _overflow):
		return
	if _is_y(event):
		var was := expanded
		set_expanded(not expanded)
		XSound.system(0)
		if not (was and y_pass_on_collapse):
			get_viewport().set_input_as_handled()
		return
	if not expanded:
		return
	if event.is_action_pressed("ui_cancel"):
		set_expanded(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		scroll_by(-SCROLL_STEP if event.is_action("ui_up") else SCROLL_STEP)
		get_viewport().set_input_as_handled()


## 处理按钮的方向键／确定（页面焦点在牌上时转进来）
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
		if can_expand() and not expanded and strip_rect().has_point(event.position):
			set_expanded(true)
			XSound.system(0)
			accept_event()


## 展开的牌：滚轮、手指拖滚动；点一下（没拖）收回
func _sheet_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			scroll_by(-SCROLL_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else SCROLL_STEP)
			_sheet.accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag.press(mb.position, scroll)
			elif _drag.release():
				set_expanded(false)
				XSound.system(0)
			_sheet.accept_event()
	elif event is InputEventMouseMotion and _drag.active():
		var to := _drag.motion((event as InputEventMouseMotion).position)
		if not is_nan(to):
			scroll_by(to - scroll)
		_sheet.accept_event()


func _draw() -> void:
	if expanded:
		return   # 展开时由 _sheet 画整张
	var ci := get_canvas_item()
	XUiSkin.shadow_style().draw(ci, Rect2(Vector2.ZERO, size))
	XUiSkin.panel_style().draw(ci, Rect2(Vector2.ZERO, size))
	_draw_border(ci, Rect2(Vector2.ZERO, size))
	var bottom := content_bottom()
	_overflow = false
	if fold:
		_overflow = natural_height(size.x) > size.y + 0.5
	if _overflow:
		_body(self, pad, pad, size.x - pad * 2, bottom - 22.0, false)
		_draw_fade(self, Rect2(0, bottom - FADE_H, size.x, FADE_H), _strip_text(false))
	else:
		_body(self, pad, pad, size.x - pad * 2, bottom, false)
	sel_scale.sel(button_index if button_index >= 0 and button_index < buttons.size() else null)
	var body := XUiSkin.font("body")
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


func _draw_border(ci: RID, r: Rect2) -> void:
	if border_color.a <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(XUiSkin.RADIUS)
	sb.draw(ci, r)


## 展开的牌：整张面板＋内容（往上滚 scroll）＋牌底「收起」一条；_sheet 自己裁掉出界的部分
func _draw_sheet() -> void:
	var s := _sheet
	var r := Rect2(Vector2.ZERO, s.size)
	var ci := s.get_canvas_item()
	XUiSkin.panel_style().draw(ci, r)
	s.draw_rect(r, Color(XUiSkin.PANEL_LOW, 0.55))   # 压在下面的列表上，面板要不透明些
	_draw_border(ci, r)
	var bottom := s.size.y - pad - STRIP_H
	var end := _body(s, pad, pad - scroll, s.size.x - pad * 2, INF, false, pad, bottom)
	_max_scroll = maxf(0.0, end + scroll - bottom)
	scroll = clampf(scroll, 0.0, _max_scroll)
	if _max_scroll > 0.0:   # 右边一条细滚动条
		var track := bottom - pad
		var th := maxf(24.0, track * track / (track + _max_scroll))
		var ty := pad + (track - th) * (scroll / _max_scroll)
		s.draw_rect(Rect2(s.size.x - 6.0, ty, 3.0, th), Color(XUiSkin.LINE, 0.45))
	_draw_fade(s, Rect2(0, bottom - 16.0, s.size.x, s.size.y - bottom + 16.0), _strip_text(true))


func _strip_text(open: bool) -> String:
	var touch := XSkinKeyHints.touch_mode()
	if open:
		return "收起 ▴" if touch else "Y 收起 ▴"
	return "看完整说明 ▾" if touch else "Y 看完整说明 ▾"


## 牌底渐隐（上透明→下面板色）＋居中一行提示
func _draw_fade(t: Control, r: Rect2, text: String) -> void:
	var c0 := Color(XUiSkin.PANEL_LOW, 0.0)
	var c1 := Color(XUiSkin.PANEL_LOW, 0.96)
	var mid := r.position.y + r.size.y * 0.55
	t.draw_polygon(PackedVector2Array([Vector2(r.position.x + 1, r.position.y), Vector2(r.end.x - 1, r.position.y), Vector2(r.end.x - 1, mid), Vector2(r.position.x + 1, mid)]),
		PackedColorArray([c0, c0, c1, c1]))
	t.draw_rect(Rect2(r.position.x + 1, mid, r.size.x - 2, r.end.y - mid - XUiSkin.RADIUS * 0.5), c1)
	var body := XUiSkin.font("body")
	var fs := XUiSkin.FS_AUX
	var tw := body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	XUiSkin.ds(t, body, Vector2(r.position.x + (r.size.x - tw) / 2.0, r.end.y - pad * 0.5 - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_2)


## 牌头＋各节，从 (x0, y) 往下排，宽 w；画在 t 上（dry：只量不画）。bottom 以下的不画（行、节放不下就停）；
## top（展开滚动时）以上的行不画。返回排完的 y。
func _body(t: Control, x0: float, y: float, w: float, bottom: float, dry: bool, top := -INF, sheet_bottom := INF) -> float:
	var body := XUiSkin.font("body")
	var head := XUiSkin.font("title")
	var num := XUiSkin.font("num")
	if sheet_bottom < INF:
		bottom = INF   # 展开的牌整张排完（_sheet 裁），只用来量滚动
	var x := x0
	if icon != null:
		if not dry:
			t.draw_texture_rect(icon, Rect2(x, y, 48, 48), false)
		x += 48 + 12
	if title != "":
		if not dry:
			var ty := y + (48 - title_size) / 2.0 + title_size * 0.86 if icon != null else y + title_size * 0.86
			var fit := XSkinList.fit_text(head, title, x0 + w - x, title_size, 20)   # 长名字先缩到 20 号，再放不下加省略号
			XUiSkin.ds(t, head, Vector2(x, ty), fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1], title_color)
		y += maxf(48.0 if icon != null else 0.0, title_size * 1.25)
	if subtitle != "":
		y += 4
		if not dry:
			XUiSkin.ds(t, body, Vector2(x0, y + XUiSkin.FS_AUX_MAX * 0.86), subtitle, HORIZONTAL_ALIGNMENT_LEFT, w, XUiSkin.FS_AUX, XUiSkin.TEXT_2)
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
			if not dry:
				var nsb := StyleBoxFlat.new()
				nsb.bg_color = Color(XUiSkin.GOLD, 0.14)
				nsb.border_color = Color(XUiSkin.GOLD, 0.55)
				nsb.set_border_width_all(1)
				nsb.set_corner_radius_all(XUiSkin.ROW_RADIUS)
				nsb.draw(t.get_canvas_item(), Rect2(x0, y, w, nh))
				for li in npara.get_line_count():
					var r := npara.get_line_range(li)
					XUiSkin.ds(t, body, Vector2(x0 + 10.0, y + 5.0 + float(li) * nlh + XUiSkin.FS_AUX * 0.96), notice.substr(r.x, r.y - r.x), HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, XUiSkin.FS_AUX, XUiSkin.GOLD_LIGHT)
			y += nh + 4
	if desc != "":
		y += 8
		for part in (desc.split("\n", false) if fold else PackedStringArray([desc])):
			y = _paragraph(t, body, part, y, x0, w, XUiSkin.FS_AUX_MAX, XUiSkin.TEXT_2 if fold else XUiSkin.TEXT, bottom, [], dry, -1.0, top)
	for sec in sections:
		if y + SECTION_H > bottom:
			break
		var big: bool = sec.has("size")
		var fs := int(sec.get("size", XUiSkin.FS_AUX))
		var lh := roundf(fs * 1.6) if big else -1.0
		y += 6
		if not dry and y >= top:
			t.draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(XUiSkin.LINE, 0.14), 1.0)
		y += 4
		if str(sec.get("title", "")) != "":
			if not dry and y >= top:
				XUiSkin.ds(t, body, Vector2(x0, y + XUiSkin.FS_AUX_MAX * 1.1), str(sec.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, w, XUiSkin.FS_AUX_MAX, XUiSkin.GOLD)
			y += SECTION_H - 10
		for row in sec.get("rows", []):
			var col: Color = XUiSkin.TEXT_3 if bool(row.get("dim", false)) else row.get("color", XUiSkin.TEXT_2)
			y = _paragraph(t, body, str(row.get("text", "")), y, x0, w, fs, col, bottom, row.get("spans", []), dry, lh, top)
		if sec.has("cells"):
			y = _cells(t, body, sec.cells, y, x0, w, fs, roundf(fs * 1.6), bottom, dry, top)
		if sec.has("text"):
			y = _paragraph(t, body, str(sec.text), y, x0, w, XUiSkin.FS_AUX, XUiSkin.TEXT_2, bottom, [], dry, -1.0, top)
		for ln in sec.get("lines", []):
			if y + LINE_H > bottom:
				break
			if not dry and y >= top:
				var base := y + LINE_H / 2.0
				XUiSkin.ds(t, body, Vector2(x0, base + 15 * 0.36), str(ln.get("left", "")), HORIZONTAL_ALIGNMENT_LEFT, w * 0.6, 15, ln.get("color", XUiSkin.TEXT_2))
				var rt := str(ln.get("right", ""))
				if rt != "":
					var rw := num.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
					XUiSkin.ds(t, num, Vector2(x0 + w - rw, base + 21 * 0.36), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, ln.get("right_color", XUiSkin.TEXT))
			y += LINE_H
	return y


## 两列「名 值」格子：名次要字、值正文，两格一行；一格比半宽还宽就独占一行（再长自动换行）
func _cells(t: Control, f: Font, cells: Array, y: float, x0: float, w: float, fs: int, lh: float, bottom: float, dry: bool, top: float) -> float:
	var half := w / 2.0
	var col := 0
	for c in cells:
		var nm := str(c[0])
		var val := str(c[1]) if c.size() > 1 else ""
		var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cw := nw + (8.0 + f.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if val != "" else 0.0)
		if cw > half - 8.0:
			if col == 1:
				y += lh
				col = 0
			var spans := [[nm + ("　" if val != "" else ""), XUiSkin.TEXT_2], [val, XUiSkin.TEXT]]
			y = _paragraph(t, f, nm + ("　" if val != "" else "") + val, y, x0, w, fs, XUiSkin.TEXT, bottom, spans, dry, lh, top)
			continue
		if col == 0 and y + lh > bottom:
			return y
		if not dry and y >= top:
			var cx := x0 + half * col
			var by := y + fs * 1.1 + (lh - roundf(fs * 1.5)) / 2.0
			XUiSkin.ds(t, f, Vector2(cx, by), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_2)
			if val != "":
				XUiSkin.ds(t, f, Vector2(cx + nw + 8.0, by), val, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT)
		col += 1
		if col == 2:
			col = 0
			y += lh
	if col == 1:
		y += lh
	return y


## spans（可选）：[[字, 颜色], …] 拼起来＝text，逐段上色（装备「自带」属性分色，T095）
## lh：行距（<0＝字号×1.5，同旧）；top 以上的行只占位不画（展开滚动）
func _paragraph(t: Control, f: Font, text: String, y: float, x0: float, w: float, fs: int, col: Color, bottom: float, spans := [], dry := false, lh := -1.0, top := -INF) -> float:
	if lh < 0.0:
		lh = roundf(fs * 1.5)
	var para := TextParagraph.new()
	para.width = w
	para.add_string(text, f, fs)
	var off := (lh - roundf(fs * 1.5)) / 2.0
	for li in para.get_line_count():
		if y + lh > bottom:
			break
		if not dry and y + lh >= top:
			var line_text_range := para.get_line_range(li)
			if spans.is_empty():
				XUiSkin.ds(t, f, Vector2(x0, y + off + fs * 1.1), text.substr(line_text_range.x, line_text_range.y - line_text_range.x), HORIZONTAL_ALIGNMENT_LEFT, w, fs, col)
			else:
				_span_line(t, f, spans, line_text_range.x, line_text_range.y, Vector2(x0, y + off + fs * 1.1), fs)
		y += lh
	return y


## 画一行里 [from, to) 这段字，按 spans 换色
func _span_line(t: Control, f: Font, spans: Array, from: int, to: int, at: Vector2, fs: int) -> void:
	var off := 0
	var x := at.x
	for sp in spans:
		var s := str(sp[0])
		var a := maxi(from, off)
		var b := mini(to, off + s.length())
		if b > a:
			var piece := s.substr(a - off, b - a)
			XUiSkin.ds(t, f, Vector2(x, at.y), piece, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, sp[1])
			x += f.get_string_size(piece, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		off += s.length()
