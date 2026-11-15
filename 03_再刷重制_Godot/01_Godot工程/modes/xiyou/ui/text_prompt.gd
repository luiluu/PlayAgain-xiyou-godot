class_name XTextPrompt
extends Control
## 事件脚本里的 prompt(提示, 默认)（原版是 NW.js 浏览器自带的输入框：提示文字、一行输入、确定/取消）。
## 这里用 MV 窗口皮肤做同样的三样东西；确定返回输入内容，取消（Esc／右键）返回空字符串（原版 prompt 取消得到 null）。

signal closed(text: String)

var _prompt := ""
var _default := ""
var edit: LineEdit


func setup(prompt: String, default := "") -> void:
	_prompt = prompt
	_default = default


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skin := XUiSkin.on()   # 新界面（5C）：黑面板＋细线、红乙选中条，输入框也换；关着时一行旧代码都不变
	theme = XUiSkin.theme() if skin else XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if skin:
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.6)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", XUiSkin.panel_style() if skin else XUI.panel())
	panel.custom_minimum_size = Vector2(560, 0)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(XUI.label(_prompt))
	edit = LineEdit.new()
	edit.text = _default
	edit.custom_minimum_size = Vector2(0, 44)
	if skin:
		for state in ["normal", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(1, 1, 1, 0.05)
			box.set_border_width_all(1)
			box.border_color = XUiSkin.SEL_LINE if state == "focus" else Color(XUiSkin.LINE, 0.42)
			box.set_corner_radius_all(XUiSkin.ROW_RADIUS)
			box.content_margin_left = XUiSkin.PAD
			box.content_margin_right = XUiSkin.PAD
			edit.add_theme_stylebox_override(state, box)
		edit.add_theme_color_override("font_color", XUiSkin.TEXT)
		edit.add_theme_color_override("caret_color", XUiSkin.SEL_LINE)
		edit.add_theme_font_size_override("font_size", XUiSkin.FS_LIST)
	edit.text_submitted.connect(func(t: String): closed.emit(t))
	col.add_child(edit)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	var ok := XUI.button("确定", 40)
	ok.pressed.connect(func(): closed.emit(edit.text))
	row.add_child(ok)
	var cancel := XUI.button("取消", 40)
	cancel.pressed.connect(func(): closed.emit(""))
	row.add_child(cancel)
	panel.resized.connect(func(): panel.position = (get_viewport_rect().size - panel.size) / 2.0)
	edit.grab_focus.call_deferred()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		closed.emit("")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		closed.emit("")
