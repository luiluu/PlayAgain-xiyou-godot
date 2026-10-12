class_name XMessageBox
extends Control
## 对话框（照原版 MV Window_Message＋YEP 名字框）：底部全宽窗口＋左侧头像＋名字小窗＋逐字显示；
## 选项为消息窗右上方的选项窗（触屏可直接点）。
## show_text() 等玩家确认后返回；choose() 返回选中序号，取消返回 cancel_type（MV 语义）。

signal _advance
signal _chosen(index: int)

const CHARS_PER_FRAME := 2
## 自动测试用：auto 为真时文字自动翻页，选项依次取 auto_answers（取完后选第一个）。
static var auto := false
static var auto_answers: Array = []
static var transcript: Array = []
var _panel: PanelContainer
var _face: TextureRect
var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _choice_win: PanelContainer
var _name_box: PanelContainer
var _typing := false
var _waiting := false
var _cancel_type := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = XUI.theme()
	# MV Window_Message：全宽、4 行（行高 36、内边距 14 → 172 高），贴底；头像 144 在左，正文缩进 144+24
	var h := XUI.LINE_HEIGHT * 4 + 28
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", XUI.panel())
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -h
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_panel.add_child(row)
	_face = TextureRect.new()
	_face.custom_minimum_size = Vector2(144, 144)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_face)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", XUI.FONT_SIZE)
	_text.add_theme_constant_override("line_separation", XUI.LINE_HEIGHT - XUI.FONT_SIZE - 6)
	_text.scroll_active = false
	row.add_child(_text)
	# YEP_MessageCore 名字框：消息窗左上方的小窗口，名字用 \c[6]
	_name_box = PanelContainer.new()
	_name_box.add_theme_stylebox_override("panel", XUI.panel())
	_name_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_name_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_name_box.offset_left = 0
	_name_box.offset_bottom = -h
	_name_box.offset_top = -h - (XUI.LINE_HEIGHT + 28)
	add_child(_name_box)
	_name = XUI.label("", XUI.FONT_SIZE, XUI.text_color(6))
	_name_box.add_child(_name)
	# 选项窗（MV Window_ChoiceList）：消息窗右上方
	_choice_win = PanelContainer.new()
	_choice_win.add_theme_stylebox_override("panel", XUI.panel())
	_choice_win.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_choice_win.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_choice_win.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choice_win.offset_right = 0
	_choice_win.offset_bottom = -h
	_choice_win.visible = false
	add_child(_choice_win)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 0)
	_choice_win.add_child(_choices)
	visible = false


func show_text(face_name: String, face_index: int, lines: Array) -> void:
	await _show(face_name, face_index, lines)
	if lines.is_empty():
		return
	if auto:
		transcript.append(XText.plain("\n".join(lines)))
		await get_tree().process_frame
		visible = false
		return
	_waiting = true
	await _advance
	_waiting = false
	visible = false


func show_text_with_choices(face_name: String, face_index: int, lines: Array, options: Array, cancel_type: int) -> int:
	if not lines.is_empty():
		await _show(face_name, face_index, lines)
	var r := await choose(options, cancel_type)
	visible = false
	return r


func choose(options: Array, cancel_type: int) -> int:
	visible = true
	_cancel_type = cancel_type
	for c in _choices.get_children():
		c.queue_free()
	for i in range(options.size()):
		var b := XUI.button(XText.plain(str(options[i])), XUI.LINE_HEIGHT + 8)
		b.custom_minimum_size.x = 240
		b.pressed.connect(func(): _chosen.emit(i))
		_choices.add_child(b)
	_choice_win.visible = true
	_choice_win.reset_size()
	await get_tree().process_frame
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()
	var r: int
	if auto:
		r = int(auto_answers.pop_front()) if not auto_answers.is_empty() else 0
		transcript.append("选择：" + XText.plain(str(options[r])))
	else:
		r = await _chosen
	for c in _choices.get_children():
		c.queue_free()
	_choice_win.visible = false
	_cancel_type = -1
	return r


func _show(face_name: String, face_index: int, lines: Array) -> void:
	visible = true
	var conv := XText.to_bb("\n".join(lines))
	_face.texture = XUI.face_texture(face_name, face_index)
	_face.visible = _face.texture != null
	_name.text = conv.name
	_name_box.visible = conv.name != ""
	_text.text = str(conv.bbcode).strip_edges()
	_text.visible_characters = 0
	_typing = not auto
	while _typing and _text.visible_characters < _text.get_total_character_count():
		_text.visible_characters += CHARS_PER_FRAME
		await get_tree().process_frame
	_text.visible_characters = -1
	_typing = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var confirm: bool = event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	var cancel: bool = event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
	if _choices.get_child_count() > 0:
		if cancel and _cancel_type != -1:
			get_viewport().set_input_as_handled()
			_chosen.emit(_cancel_type)
		return
	if confirm:
		get_viewport().set_input_as_handled()
		if _typing:
			_typing = false
		elif _waiting:
			_advance.emit()
