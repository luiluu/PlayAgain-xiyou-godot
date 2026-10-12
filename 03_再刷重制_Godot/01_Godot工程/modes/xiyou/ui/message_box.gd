class_name XMessageBox
extends Control
## 对话框：底部面板＋左侧头像＋名字框＋逐字显示；选项为面板上方的按钮列（触屏可直接点）。
## show_text() 等玩家确认后返回；choose() 返回选中序号，取消返回 cancel_type（MV 语义）。

signal _advance
signal _chosen(index: int)

const CHARS_PER_FRAME := 2
var _panel: PanelContainer
var _face: TextureRect
var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _typing := false
var _waiting := false
var _cancel_type := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = XUI.theme()
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", XUI.panel())
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 40
	_panel.offset_right = -40
	_panel.offset_top = -210
	_panel.offset_bottom = -24
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_panel.add_child(row)
	_face = TextureRect.new()
	_face.custom_minimum_size = Vector2(144, 144)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_name = XUI.label("", 22, XUI.GOLD)
	col.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.scroll_active = false
	col.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_choices.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_choices.offset_right = -60
	_choices.add_theme_constant_override("separation", 8)
	add_child(_choices)
	visible = false


func show_text(face_name: String, face_index: int, lines: Array) -> void:
	await _show(face_name, face_index, lines)
	if lines.is_empty():
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
		var b := XUI.button(XText.plain(str(options[i])), 52)
		b.custom_minimum_size.x = 280
		b.pressed.connect(func(): _chosen.emit(i))
		_choices.add_child(b)
	_choices.position.y = -_choices.get_combined_minimum_size().y / 2.0
	await get_tree().process_frame
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()
	var r: int = await _chosen
	for c in _choices.get_children():
		c.queue_free()
	_cancel_type = -1
	return r


func _show(face_name: String, face_index: int, lines: Array) -> void:
	visible = true
	var conv := XText.convert("\n".join(lines))
	_face.texture = XUI.face_texture(face_name, face_index)
	_face.visible = _face.texture != null
	_name.text = conv.name
	_name.visible = conv.name != ""
	_text.text = str(conv.bbcode).strip_edges()
	_text.visible_characters = 0
	_typing = true
	while _typing and _text.visible_characters < _text.get_total_character_count():
		_text.visible_characters += CHARS_PER_FRAME
		await get_tree().process_frame
	_text.visible_characters = -1
	_typing = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var confirm := event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	var cancel := event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
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
