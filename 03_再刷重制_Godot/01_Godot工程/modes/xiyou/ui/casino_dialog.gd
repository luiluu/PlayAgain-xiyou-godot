class_name XCasinoDialog
extends Control
## 批量抽奖的数量框（installCasinoBatchRuntime 的 DOM 覆盖层 #codex-casino-batch，逻辑在 XCasinoBatch）。照原版内联样式：
## - 全屏黑 0.66 底，面板居中：宽 min(480, 85vw)、内边距 26、边 1px #8b9cab、圆角 14、底色 #17222e、字色 #edf2f7、阴影 0 12 50 黑。
## - 标题 24 号（下距 14）；说明 16 号行高 1.7；「抽数（持有 N 张券，最多 N 抽）」；数字框（22 号、内边距 10、底 #0d1520、边 #76899c、圆角 6）
##   与「MAX」并排（间距 10、上 10 下 14）；状态行 16 号（最小高 24）；底部右对齐「取消」「开始抽取」（间距 12）。
##   按钮：内边距 10/18、边 #8195a7、圆角 6、底 #344c60、白字 17 号。
## - 数字框改动即预览「共 N 抽，消耗 N 张券；积分门槛 …」；MAX 填最大数；开始抽取校验 1～最大的整数；Enter（数字框里）确定、Esc 取消。
##   抽取中数字框与 MAX 禁用、「开始抽取」隐藏、「取消」变「停止后续抽取」，按下后禁用并写「正在完成当前一抽／20连抽」，
##   状态行「已完成 a / b抽；二阶段 n 次」。打开时按键与点击不再传给游戏窗口。

const TEXT := Color("#edf2f7")

var session: Dictionary
var title: Label
var desc: Label
var label: Label
var input: LineEdit
var max_button: Button
var status: Label
var cancel_button: Button
var ok_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.66)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var box := _box(Color("#17222e"), Color("#8b9cab"), 14, Vector2(26, 26))
	box.shadow_color = Color.BLACK
	box.shadow_size = 25
	box.shadow_offset = Vector2(0, 12)
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size.x = minf(480, 1280 * 0.85)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	var rules: Dictionary = session.rules
	var twenty: bool = session.mode == "twenty"
	title = _label(str(rules.title), 24)
	title.custom_minimum_size.y = 24 * 1.2 + 14
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	col.add_child(title)
	desc = _label(("每次消耗20张券，完整执行一次20连抽，逐次判定二阶段、欧皇之证及原生奖励。" if twenty else "每抽消耗1张券，逐次判定二阶段与欧皇之证。")
		+ "自动选择「赢下所有」，积分不足时停止。", 16)
	desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	desc.add_theme_constant_override("line_spacing", int(16 * 0.7))
	col.add_child(_spaced(desc, 16, 16))
	label = _label("", 16)
	col.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	input = LineEdit.new()
	input.text = "1"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_font_override("font", XUI.font())
	input.add_theme_font_size_override("font_size", 22)
	input.add_theme_color_override("font_color", Color.WHITE)
	input.add_theme_stylebox_override("normal", _box(Color("#0d1520"), Color("#76899c"), 6, Vector2(10, 10)))
	input.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color("#a9c3da"), 6, Vector2(10, 10)))
	input.text_changed.connect(func(_t): preview())
	input.text_submitted.connect(func(_t): if session.state == "quantity": confirm())
	row.add_child(input)
	max_button = _button("MAX", press_max)
	row.add_child(max_button)
	col.add_child(_spaced(row, 10, 14))
	status = _label("", 16)
	status.custom_minimum_size.y = 24
	status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	col.add_child(_spaced(status, 16, 16))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	cancel_button = _button("取消", XCasinoBatch.cancel)
	ok_button = _button("开始抽取", confirm)
	buttons.add_child(cancel_button)
	buttons.add_child(ok_button)
	col.add_child(buttons)
	refresh_limit()
	preview()
	input.grab_focus.call_deferred()
	input.select_all.call_deferred()


static func _box(bg: Color, edge: Color, radius: int, pad: Vector2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x + 1
	s.content_margin_right = pad.x + 1
	s.content_margin_top = pad.y + 1
	s.content_margin_bottom = pad.y + 1
	return s


static func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", XUI.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## CSS 段落外边距（p 默认上下 1em）
static func _spaced(c: Control, top: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.add_child(c)
	return m


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", XUI.font())
	b.add_theme_font_size_override("font_size", 17)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(k, Color.WHITE if k != "font_disabled_color" else Color(1, 1, 1, 0.5))
	var normal := _box(Color("#344c60"), Color("#8195a7"), 6, Vector2(18, 10))
	var hover := _box(Color("#3f5a71"), Color("#a9c3da"), 6, Vector2(18, 10))
	var off := _box(Color("#344c60", 0.5), Color("#8195a7", 0.5), 6, Vector2(18, 10))
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("disabled", off)
	b.pressed.connect(cb)
	return b


## 数字框的值（原版 Number(input.value)）：不是整数为 -1
static func number(text: String) -> int:
	var t := text.strip_edges()
	if t.is_valid_int():
		return int(t)
	if t.is_valid_float() and float(t) == floorf(float(t)):
		return int(float(t))
	return -1


func refresh_limit() -> int:
	var s := XState.current
	var n := XCasinoBatch.maximum(s, session.mode)
	max_button.disabled = n < 1
	var twenty: bool = session.mode == "twenty"
	label.text = "%s（持有 %d 张券，最多 %d%s）" % ["20连抽次数" if twenty else "抽数", XCasinoBatch.stock(s), n, " 次" if twenty else " 抽"]
	return n


func preview() -> void:
	var n := number(input.text)
	var cost := int(session.rules.cost)
	status.text = "共 %d 抽，消耗 %d 张券；积分门槛 %d。" % [n * cost, n * cost, int(session.rules.threshold)] if n > 0 else ""


func confirm() -> void:
	var n := refresh_limit()
	var value := number(input.text)
	if value < 1 or value > n:
		status.text = "请输入1～%d之间的整数。" % n
		return
	XCasinoBatch.begin(value)


func press_max() -> void:
	if session.state != "quantity":
		return
	var n := refresh_limit()
	if n < 1:
		status.text = "抽奖券不足。"
		return
	input.text = str(n)
	preview()
	input.grab_focus()
	input.select_all()


func drawing_started() -> void:
	input.editable = false
	max_button.disabled = true
	ok_button.visible = false
	cancel_button.text = "停止后续抽取"


func stopping() -> void:
	cancel_button.disabled = true
	cancel_button.text = "正在完成当前" + ("20连抽" if session.mode == "twenty" else "一抽")


func set_status(text: String) -> void:
	status.text = text


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if not cancel_button.disabled:
			XCasinoBatch.cancel()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventAction:
		get_viewport().set_input_as_handled()
