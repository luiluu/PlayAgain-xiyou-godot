class_name XWebPanel
extends Control
## 正式西游 Codex 网页覆盖层面板的公共部件（installEquipmentStatusRuntime 的 #cq-modal＋installGamePanelTheme 外观）：
## 装备检索（XGearSearch）与角色战力（XPowerPanel）共用。读数见 XGearSearch 页眉（参照浏览器 1280×720）。
## - 面板 (8,8,1264,704)：底色 #16161f、圆角 8、Window 皮肤边框（96,0,96,96 切 24，画进 12px 边）、内边距 16/20。
## - 标题区 .cq-head：标题 23 号粗体 (40,36)、说明 13 号 (40,72.8)、「关闭 · Esc」靠右 (y 44.2)；下 1px 分隔线 (y 103.6)，下距 12。
## - 按钮 17 号、黑 0.28 底、白 0.4 边、圆角 6、内边距 6/10、高 41.2；悬停与 .cq-active 用光标色。
## - 详情框 .cq-detail：黑 0.25 底、白 0.22 边、圆角 6、内边距 13；滚动条 8 宽。
## - h3：17 号粗体系统色，上 12 下 6；.cq-note 13 号 #c9ced8 行高 20.8；胶囊：金色 13 号、黑 0.3 底、金 0.45 边、内边距 3/7、间距 7。
## - 卡片 .cq-effect：白 0.04 底、左 3px 系统色、内边距 9/10、下距 7。
## Esc 关闭；打开时其余按键不再传给游戏窗口。

signal closed

const PANEL := Rect2(8, 8, 1264, 704)
const BORDER := 12.0
const PAD := Vector2(20, 16)
const CONTENT_X := 40.0
const CONTENT_W := 1200.0
const TEXT := Color(1, 1, 1)
const MUTED := Color("#c9ced8")
const SYSTEM := Color("#84aaff")
const GOLD := Color("#ffd373")
const LINE := Color(1, 1, 1, 0.22)
const PANEL_BG := Color("#16161f")
const FIELD_BG := Color(0, 0, 0, 0.42)
const BUTTON_BG := Color(0, 0, 0, 0.28)
const BUTTON_EDGE := Color(1, 1, 1, 0.4)
const CURSOR := Color(160 / 255.0, 230 / 255.0, 235 / 255.0, 0.22)
const CURSOR_EDGE := Color(200 / 255.0, 245 / 255.0, 250 / 255.0, 0.75)


static func _font(bold := false) -> Font:
	if not bold:
		return XUI.font()
	var v := FontVariation.new()
	v.base_font = XUI.font()
	v.variation_embolden = 0.6
	v.spacing_glyph = 1
	return v


# ---- 外观 ----
static func _box(bg: Color, edge: Color, radius := 6, border := 1, pad := Vector2(10, 6)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	# CSS 盒子：内容到外沿＝内边距＋边框
	s.content_margin_left = pad.x + border
	s.content_margin_right = pad.x + border
	s.content_margin_top = pad.y + border
	s.content_margin_bottom = pad.y + border
	return s


static func _outline(c: Control) -> void:
	c.add_theme_color_override("font_outline_color", Color.BLACK)
	c.add_theme_constant_override("outline_size", 2)


## installGamePanelTheme 的按钮：17 号、黑 0.28 底、白 0.4 边、圆角 6；悬停光标色
static func style_button(b: Button, pad := Vector2(10, 6)) -> void:
	b.add_theme_font_override("font", XUI.font())
	b.add_theme_font_size_override("font_size", 17)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, TEXT)
	_outline(b)
	b.add_theme_stylebox_override("normal", _box(BUTTON_BG, BUTTON_EDGE, 6, 1, pad))
	b.add_theme_stylebox_override("hover", _box(CURSOR, CURSOR_EDGE, 6, 1, pad))
	b.add_theme_stylebox_override("pressed", _box(CURSOR, CURSOR_EDGE, 6, 1, pad))
	b.add_theme_stylebox_override("hover_pressed", _box(CURSOR, CURSOR_EDGE, 6, 1, pad))
	var focus := _box(Color(0, 0, 0, 0), CURSOR_EDGE, 7, 2, Vector2.ZERO)
	focus.set_expand_margin_all(3)
	b.add_theme_stylebox_override("focus", focus)


static func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_outline(l)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 详情里的段落：按容器宽度折行（CSS overflow-wrap:anywhere）
static func _para(text: String, size: int, color: Color, line_h: float, bold := false) -> Label:
	var l := _fixed(_label(text, size, color, bold), line_h)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## 行高按 CSS line-height（字号 × 1.6），不用字体自身的行高
static func _fixed(l: Label, line_h: float) -> Label:
	var ls := LabelSettings.new()
	ls.font = l.get_theme_font("font")
	ls.font_size = l.get_theme_font_size("font_size")
	ls.font_color = l.get_theme_color("font_color")
	ls.outline_size = 2
	ls.outline_color = Color.BLACK
	ls.line_spacing = 0
	var f := ls.font
	ls.line_spacing = line_h - (f.get_ascent(ls.font_size) + f.get_descent(ls.font_size))
	l.label_settings = ls
	l.custom_minimum_size.y = line_h
	return l


## 面板底、Window 皮肤边框与标题区分隔线（_draw 里调用）
func draw_frame() -> void:
	var bg := _box(PANEL_BG, Color(0, 0, 0, 0), 8, 0, Vector2.ZERO)
	bg.shadow_color = Color(0, 0, 0, 0.65)
	bg.shadow_size = 20
	bg.shadow_offset = Vector2(0, 10)
	draw_style_box(bg, PANEL)
	# border-image：Window 皮肤 (96,0,96,96) 切 24，四角缩成 12，四边拉伸，不画中间
	var skin := XUI.skin()
	if skin != null:
		var r := PANEL
		var s := 24.0
		var b := BORDER
		var xs := [[0.0, s, r.position.x, b], [s, 48.0, r.position.x + b, r.size.x - b * 2], [72.0, s, r.end.x - b, b]]
		var ys := [[0.0, s, r.position.y, b], [s, 48.0, r.position.y + b, r.size.y - b * 2], [72.0, s, r.end.y - b, b]]
		for xi in range(3):
			for yi in range(3):
				if xi == 1 and yi == 1:
					continue
				var x: Array = xs[xi]
				var y: Array = ys[yi]
				draw_texture_rect_region(skin, Rect2(x[2], y[2], x[3], y[3]), Rect2(96 + x[0], y[0], x[1], y[1]))
	# 标题区下的分隔线
	draw_line(Vector2(CONTENT_X, 103.6), Vector2(CONTENT_X + CONTENT_W, 103.6), LINE, 1.0)


## 加进场景树后字体才生效，宽度变了也保持右端对齐
func _right_align(b: Button, right: float, y: float) -> void:
	b.size = b.get_combined_minimum_size()
	b.size.y = 41.2
	b.position = Vector2(right - b.size.x, y)
	b.resized.connect(func(): b.position.x = right - b.size.x)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b)
	b.pressed.connect(cb)
	b.size = b.get_combined_minimum_size()
	b.size.y = 41.2
	return b


## 标题区：标题、说明与「关闭 · Esc」
func head(title: String, subtitle: String) -> void:
	var h := _fixed(_label(title, 23, TEXT, true), 36.8)
	h.position = Vector2(CONTENT_X, 36)
	add_child(h)
	var sub := _fixed(_label(subtitle, 13, MUTED), 20.8)
	sub.position = Vector2(CONTENT_X, 72.8)
	add_child(sub)
	var close_b := _button("关闭 · Esc", close)
	add_child(close_b)
	_right_align(close_b, CONTENT_X + CONTENT_W, 44.2)


## 底部栏：左说明、右按钮（.cq-footer，面板内底）；返回栏顶 y
func footer(note: String, text: String, cb: Callable) -> float:
	var y := PANEL.end.y - BORDER - PAD.y - 41.2
	var n := _fixed(_label(note, 13, MUTED), 20.8)
	n.position = Vector2(CONTENT_X, y + (41.2 - 20.8) / 2)
	add_child(n)
	var b := _button(text, cb)
	add_child(b)
	_right_align(b, CONTENT_X + CONTENT_W, y)
	return y


func _panel_scroll(r: Rect2, pad: float) -> ScrollContainer:
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.25), LINE, 6, 1, Vector2.ZERO))
	frame.position = r.position
	frame.size = r.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var sc := ScrollContainer.new()
	sc.position = r.position + Vector2(1 + pad, 1 + pad)
	sc.size = r.size - Vector2(2 + pad * 2, 2 + pad * 2)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	var grab := _box(Color(1, 1, 1, 0.35), Color(0, 0, 0, 0), 4, 0, Vector2(4, 0))
	var bar := sc.get_v_scroll_bar()
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab)
	bar.add_theme_stylebox_override("grabber_pressed", grab)
	bar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	bar.custom_minimum_size.x = 8
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	add_child(sc)
	return sc


func _empty(text: String) -> Control:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 20)
	m.add_child(_para(text, 18, MUTED, 28.8))
	return m


## h3：上 12 下 6、17 号粗体；top 给前一块的下边距折叠用（CSS 相邻外边距取大者）
static func h3(text: String, color := SYSTEM, top := 12) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", 6)
	m.add_child(_para(text, 17, color, 27.2, true))
	return m


## .cq-pills：金色胶囊，上下 8、间距 7（胶囊高 28.8＝20.8＋上下 3＋边框 1）
static func pills(texts: Array, width := 1164.0) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	var items := []
	for t in texts:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.3), Color(1, 211 / 255.0, 115 / 255.0, 0.45), 6, 1, Vector2(7, 3)))
		p.add_child(_fixed(_label(t, 13, GOLD), 20.8))
		items.append(p)
	m.add_child(flow(items, width, 7, 7, 28.8))
	return m


## CSS flex-wrap：按宽度换行，横 hgap、纵 vgap；高度不取整（Godot 的 FlowContainer 会把行高截成整数）
static func flow(items: Array, width: float, hgap: float, vgap: float, line_h: float) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := 0.0
	var y := 0.0
	for c in items:
		box.add_child(c)
		var w := _min_width(c)
		if x > 0 and x + w > width:
			x = 0.0
			y += line_h + vgap
		c.position = Vector2(x, y)
		c.size = Vector2(w, line_h)
		x += w + hgap
	box.custom_minimum_size = Vector2(0, y + line_h if not items.is_empty() else 0.0)
	return box


## .cq-effect 卡片：rows 为 [文字, 字号, 颜色, 行高, 粗体]
static func card(rows: Array) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_bottom", 7)
	var p := PanelContainer.new()
	var st := _box(Color(1, 1, 1, 0.04), SYSTEM, 0, 0, Vector2(10, 9))
	st.border_width_left = 3
	st.content_margin_left = 13
	p.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	for r in rows:
		v.add_child(_para(r[0], r[1], r[2], r[3], r[4] if r.size() > 4 else false))
	p.add_child(v)
	m.add_child(p)
	return m


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


## Esc 先于输入框处理；其余按键交给控件（Tab 移动焦点），没被控件用掉的也不再传给游戏窗口
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventAction:
		get_viewport().set_input_as_handled()


## 进场景树前的最小宽度：PanelContainer 的缓存尺寸要进树才更新，这里按「子项＋面板样式」自己算
static func _min_width(c: Control) -> float:
	if c is PanelContainer and c.get_child_count() > 0:
		var st: StyleBox = c.get_theme_stylebox("panel")
		return (c.get_child(0) as Control).get_combined_minimum_size().x + (st.get_minimum_size().x if st else 0.0)
	return c.get_combined_minimum_size().x


# ---- 精确排版（CSS 小数高度；Godot 的 Box/Margin/Flow 容器会把子项高度取整，逐块累积误差） ----
## 纵向堆叠：各块宽 width、高取 custom_minimum_size.y（块自己算好），y 用小数累加；返回带最小尺寸的容器
static func stack(blocks: Array, width: float) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var y := 0.0
	for b in blocks:
		var c: Control = b
		box.add_child(c)
		c.position = Vector2(0, y)
		c.size = Vector2(width, c.custom_minimum_size.y)
		y += c.custom_minimum_size.y
	box.custom_minimum_size = Vector2(width, y)
	return box


## 外边距块：上 top、下 bottom 包住 inner（inner 已带 custom_minimum_size.y）
static func spaced(inner: Control, top: float, bottom: float, width: float) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(inner)
	inner.position = Vector2(0, top)
	inner.size = Vector2(width, inner.custom_minimum_size.y)
	box.custom_minimum_size = Vector2(0, top + inner.custom_minimum_size.y + bottom)
	return box


## 一段文字（.cq-note 等）：按宽度折行，高＝行数×行高
static func text_block(text: String, size: int, color: Color, line_h: float, width: float, bold := false) -> Label:
	var l := _para(text, size, color, line_h, bold)
	l.size = Vector2(width, line_h)
	var lines := maxi(1, l.get_line_count())
	l.custom_minimum_size = Vector2(0, lines * line_h)
	return l


## h3 块（上 top 下 6，17 号粗体 27.2）
static func h3_block(text: String, width: float, top := 12.0, color := SYSTEM) -> Control:
	return spaced(text_block(text, 17, color, 27.2, width, true), top, 6, width)


## .cq-effect 卡片块：白 0.04 底、左 3px 系统色、内边距 9/10、下距 7；rows 为 [文字, 字号, 颜色, 行高, 粗体]
static func card_block(rows: Array, width: float) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	var st := _box(Color(1, 1, 1, 0.04), SYSTEM, 0, 0, Vector2.ZERO)
	st.border_width_left = 3
	bg.add_theme_stylebox_override("panel", st)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)
	var y := 9.0
	for r in rows:
		var l := text_block(r[0], r[1], r[2], r[3], width - 23, r[4] if r.size() > 4 else false)
		l.position = Vector2(13, y)
		box.add_child(l)
		y += l.custom_minimum_size.y
	bg.position = Vector2.ZERO
	bg.size = Vector2(width, y + 9)
	box.custom_minimum_size = Vector2(0, y + 9 + 7)
	return box

