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


## 红乙选中条，内边距和平时那一档一样（换状态时字不跳）；state 见 XUiSkin.SelState（按下态的字跟着下沉 1px）
static func select(like: StyleBox = null, state := XUiSkin.SelState.FOCUS) -> StyleBox:
	var sel := XSkinSelectStyle.new()
	sel.state = state
	var src: StyleBox = like if like != null else style()
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sel.set_content_margin(side, src.get_content_margin(side))
	if state == XUiSkin.SelState.PRESSED and XUiSkin.SELECT_V2:
		sel.content_margin_top += 1
		sel.content_margin_bottom -= 1
	return sel


## 文字颜色：危险橙、其余正文白
static func text_color(kind := "") -> Color:
	return XUiSkin.DOWN if kind == "danger" else XUiSkin.TEXT


static func apply(b: Button, kind := "", font_size := -1) -> Button:
	var normal := style(kind)
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	var sel := select(normal)
	var press := select(normal, XUiSkin.SelState.PRESSED)
	b.add_theme_stylebox_override("focus", sel)
	b.add_theme_stylebox_override("hover", select(normal, XUiSkin.SelState.HOVER) if XUiSkin.SELECT_V2 else sel)
	for st in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, press if XUiSkin.SELECT_V2 else sel)
	wire_press(b, sel, press)
	b.add_theme_font_override("font", XUiSkin.font("body"))
	var fs := font_size if font_size > 0 else clampi(b.get_theme_font_size("font_size"), XUiSkin.FS_AUX, XUiSkin.FS_LIST)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_constant_override("outline_size", 0)
	var col := text_color(kind)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, col)
	b.add_theme_color_override("font_disabled_color", XUiSkin.TEXT_3)
	wire_focus_scale(b)
	return b


## T024 选中放大：拿到焦点的按钮以中心放大到 BUTTON_PEAK（只是画面缩放，不改按钮大小、不让容器重排，邻钮不动）；
## 0.12 秒过渡，界面动效关时直接到位；XSkinSelScale.ENABLED 关时不放大。
const BUTTON_PEAK := 1.05


static func wire_focus_scale(b: Control) -> void:
	if b.has_meta("skin_focus_scale_wired"):
		return
	b.set_meta("skin_focus_scale_wired", true)
	b.pivot_offset = b.size / 2.0
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.focus_entered.connect(func(): _scale_to(b, BUTTON_PEAK))
	b.focus_exited.connect(func(): _scale_to(b, 1.0))
	if b.is_inside_tree() and b.has_focus():
		b.scale = Vector2.ONE * focus_scale_target(true)


static func focus_scale_target(focused: bool) -> float:
	return BUTTON_PEAK if focused and XSkinSelScale.ENABLED else 1.0


static func _scale_to(b: Control, k: float) -> void:
	if not is_instance_valid(b):
		return
	if b.has_meta("skin_focus_tween"):
		var old = b.get_meta("skin_focus_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	k = k if XSkinSelScale.ENABLED else 1.0
	if XUiSkin.motion() == XUiSkin.Motion.OFF or not b.is_inside_tree():
		b.scale = Vector2.ONE * k
		return
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * k, XUiSkin.SEL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	b.set_meta("skin_focus_tween", tw)


## Godot 的 Button 把 focus 样式叠在 pressed 上面画，按住时焦点的整行实心底会盖掉按下的压暗：
## 按下期间把 focus 换成按下态，松开换回（手指点下去看得出来；SELECT_V2 关时不接）。
static func wire_press(b: Button, focus_style: StyleBox, press_style: StyleBox) -> void:
	if not XUiSkin.SELECT_V2 or b.has_meta("skin_press_wired"):
		return
	b.set_meta("skin_press_wired", true)
	b.button_down.connect(func(): b.add_theme_stylebox_override("focus", press_style))
	b.button_up.connect(func(): b.add_theme_stylebox_override("focus", focus_style))
