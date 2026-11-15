class_name XSkinButton
extends RefCounted
## 【cc·未经审查】独立小按钮的新界面样式（ui-skin-3b）：平时黑面板＋1px 细线（线色 42%）、圆角 6；悬停／按下／焦点用红乙选中条；
## 字换思源黑体、去描边；主按钮（kind = "primary"）旧金细线，危险操作（kind = "danger"）橙字橙线（红只表示「选中」，v0.7 第二节）。
## 标题页角落按钮、选线「再想想」、异化工坊的按钮共用。不改按钮的文字、大小和信号，只换外观。


static func style(kind := "") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(XUiSkin.PANEL, 0.92)
	sb.border_color = Color(XUiSkin.LINE, 0.42)
	if kind == "primary":
		sb.border_color = Color(XUiSkin.GOLD, 0.7)
	elif kind == "danger":
		sb.border_color = Color(XUiSkin.DOWN, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(XUiSkin.ROW_RADIUS)
	sb.content_margin_left = XUiSkin.PAD
	sb.content_margin_right = XUiSkin.PAD
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## 红乙选中条，内边距和平时那一档一样（换状态时字不跳）
static func select(like: StyleBox = null) -> StyleBox:
	var sel := XSkinSelectStyle.new()
	var src: StyleBox = like if like != null else style()
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sel.set_content_margin(side, src.get_content_margin(side))
	return sel


## 文字颜色：危险橙、其余正文白
static func text_color(kind := "") -> Color:
	return XUiSkin.DOWN if kind == "danger" else XUiSkin.TEXT


static func apply(b: Button, kind := "", font_size := -1) -> Button:
	var normal := style(kind)
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	var sel := select(normal)
	for st in ["hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, sel)
	b.add_theme_font_override("font", XUiSkin.font("body"))
	var fs := font_size if font_size > 0 else clampi(b.get_theme_font_size("font_size"), XUiSkin.FS_AUX, XUiSkin.FS_LIST)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_constant_override("outline_size", 0)
	var col := text_color(kind)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, col)
	b.add_theme_color_override("font_disabled_color", XUiSkin.TEXT_3)
	return b
