class_name XWhatsNewPage
extends Control
## 【cc·update-whatsnew·未经审查】「本次更新内容」弹窗（Kyo 2026-11-15）：更新装好、重启进游戏后在标题画面弹一次；
## 设置页「本次更新内容」一行可以再看。记录与何时弹在 XWhatsNew（core/whats_new.gd）。
## 样式两套：skin＝true 走天启篇新皮肤（XUiSkin 黑面板、思源字、红乙选中条；天启篇新标题、新界面设置页用），
## false 走重制版旧样式（同「检查更新」框：深紫底、金边、金字标题）。文字列表（texts）交小A审。
## 一个按钮「知道了」；确定、取消键、点按钮、点框外暗处都能关。说明长了在框里滚动（上下键、翻页键、滚轮）。
## 开着时键盘、手柄全部在这里处理，不漏到下面的标题或设置页。

signal closed

const W := 720.0
## 比「检查更新」框（XUpdatePage.LAYER＝90）低一层：强制更新框后来盖上来时在它上面
const LAYER := 89
const SCROLL_STEP := 72.0

var record: Dictionary = {}
var skin := false
var _panel: PanelContainer
var _scroll: ScrollContainer
var _body: Label
var _more: Label
var _ok: Button


## 文字（纯函数，测试直接比；小A审）。record 是 XWhatsNew.current／pending 的结果。
static func texts(rec: Dictionary) -> Dictionary:
	var ver := str(rec.get("version", ""))
	var date := str(rec.get("date", ""))
	var lines := PackedStringArray()
	if ver != "":
		lines.append("已更新到 %s%s" % [ver, "（%s）" % date if date != "" else ""])
		lines.append("")
	for n in rec.get("notes", PackedStringArray()):
		lines.append("· " + str(n))
	return {"title": "本次更新内容", "body": "\n".join(lines), "ok": "知道了", "more": "↑↓ 滚动查看全部内容"}


## 盖在 host 上（单独的 CanvasLayer，按整个视口居中），关掉时连层一起删。已经开着就返回那一页。
static func open(host: Node, rec: Dictionary, use_skin: bool) -> XWhatsNewPage:
	var old := host.get_node_or_null("WhatsNewLayer/WhatsNewPage") as XWhatsNewPage
	if old != null and not old.is_queued_for_deletion():
		return old
	var layer := CanvasLayer.new()
	layer.name = "WhatsNewLayer"
	layer.layer = LAYER
	var p := XWhatsNewPage.new()
	p.name = "WhatsNewPage"
	p.record = rec
	p.skin = use_skin
	layer.add_child(p)
	host.add_child(layer)
	return p


## 标题画面调：有没看过的「本次更新内容」就弹一次并记已读。强制更新框盖着、或已经弹着时不弹。返回弹出的页（没弹为 null）。
static func show_pending(host: Node, use_skin: bool) -> XWhatsNewPage:
	if not XWhatsNew.ENABLED:
		return null
	var up := host.get_node_or_null("UpdateLayer/UpdatePage")
	if up != null and not up.is_queued_for_deletion():
		return null  # 检查更新／强制更新框开着：先不弹，下回进标题再说（还没记已读）
	if host.get_node_or_null("WhatsNewLayer") != null:
		return null
	var code := XUpdateClient.current_code()
	var rec := XWhatsNew.pending(code)
	if rec.is_empty():
		return null
	XWhatsNew.mark_seen(code)  # 弹出来就算看过：关掉、或开着时退出游戏都不再弹（设置页能再看）
	print("WHATS_NEW shown code=%d" % code)  # 冷启动验证看这一行
	return open(host, rec, use_skin)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_fit)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = XUiSkin.theme() if skin else XUI.theme()
	var t := texts(record)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	var title := _label(t["title"], XUiSkin.FS_PAGE if skin else 32, XUiSkin.GOLD if skin else Color(1.0, 0.86, 0.5))
	title.name = "Title"
	if skin:
		title.add_theme_font_override("font", XUiSkin.font("title"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var line := ColorRect.new()
	line.color = Color(XUiSkin.LINE, 0.35) if skin else Color(0.86, 0.72, 0.38, 0.5)
	line.custom_minimum_size = Vector2(0, 1 if skin else 2)
	box.add_child(line)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = false
	box.add_child(_scroll)
	_body = _label(t["body"], XUiSkin.FS_LIST_MAX - 2 if skin else 22, XUiSkin.TEXT if skin else XUI.TEXT)
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_more = _label(t["more"], XUiSkin.FS_AUX if skin else 16, XUiSkin.TEXT_2 if skin else XUI.DIM)
	_more.name = "More"
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_more)
	_ok = _make_button(t["ok"])
	_ok.name = "Ok"
	_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ok.pressed.connect(close_page)
	box.add_child(_ok)
	_fit()
	_ok.grab_focus.call_deferred()


func _label(text: String, fs: int, col: Color) -> Label:
	if skin:
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", col)
		l.add_theme_constant_override("outline_size", 0)
		return l
	return XUI.label(text, fs, col)


func _panel_style() -> StyleBox:
	if skin:
		var s := XUiSkin.panel_style().duplicate() as StyleBox
		s.content_margin_left = XUiSkin.PAD_LG + 8
		s.content_margin_right = XUiSkin.PAD_LG + 8
		s.content_margin_top = XUiSkin.PAD_LG
		s.content_margin_bottom = XUiSkin.PAD_LG
		return s
	var style := StyleBoxFlat.new()  # 同 XUpdatePage 的框
	style.bg_color = Color(0.06, 0.05, 0.1, 0.96)
	style.border_color = Color(0.86, 0.72, 0.38, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 18
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style


func _make_button(text: String) -> Button:
	if skin:
		var sb := XSkinButton.apply(Button.new(), "primary", XUiSkin.FS_LIST)
		sb.text = text
		sb.custom_minimum_size = Vector2(200, 46)
		sb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		return sb
	var b := XUI.button(text, 52)  # 同 XUpdatePage 的按钮
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size.x = 200
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.06)
	normal.border_color = Color(0.86, 0.72, 0.38, 0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	var hot := normal.duplicate() as StyleBoxFlat
	hot.bg_color = Color(0.86, 0.72, 0.38, 0.28)
	hot.border_color = Color(1.0, 0.86, 0.5)
	hot.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", normal)
	for st in ["hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, hot)
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.92, 0.7))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.7))
	return b


## 框的宽高跟着视口：说明区最多占到放得下按钮为止，超出就在框里滚动。
func _fit() -> void:
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	var w := minf(W, vp.x - 64.0)
	_panel.custom_minimum_size = Vector2(w, 0)
	var inner := w - 64.0
	_body.custom_minimum_size = Vector2(inner - 12.0, 0)
	var lh := float(_body.get_line_height())
	var font := _body.get_theme_font("font")
	var fs := _body.get_theme_font_size("font_size")
	var n := 0
	for para in _body.text.split("\n"):
		var pw := font.get_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		n += maxi(1, int(ceil(pw / maxf(1.0, inner - 12.0))))
	var want := n * (lh + 2.0) + 4.0
	var chrome := 44.0 + 2.0 + 22.0 + 52.0 + 44.0 + 12.0 * 4  # 标题、分隔线、提示、按钮、上下边距
	var cap := maxf(120.0, vp.y - 64.0 - chrome)
	_scroll.custom_minimum_size = Vector2(inner, minf(want, cap))
	_more.visible = want > cap + 1.0


func close_page() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	var layer := get_parent()
	if layer is CanvasLayer and layer.name == "WhatsNewLayer":
		layer.queue_free()
	else:
		queue_free()


func _gui_input(event: InputEvent) -> void:
	# 点到框外的暗处才关（框里的空白、滚轮都不算）
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		accept_event()
		if not _panel.get_global_rect().has_point(event.global_position):
			close_page()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction):
		return
	XKeyMap.handled(self)
	if is_queued_for_deletion() or not event.is_pressed():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		close_page()
	elif event.is_action_pressed("ui_up", true):
		_scroll.scroll_vertical -= int(SCROLL_STEP)
	elif event.is_action_pressed("ui_down", true):
		_scroll.scroll_vertical += int(SCROLL_STEP)
	elif event.is_action_pressed("ui_page_up", true):
		_scroll.scroll_vertical -= int(_scroll.size.y * 0.8)
	elif event.is_action_pressed("ui_page_down", true):
		_scroll.scroll_vertical += int(_scroll.size.y * 0.8)
