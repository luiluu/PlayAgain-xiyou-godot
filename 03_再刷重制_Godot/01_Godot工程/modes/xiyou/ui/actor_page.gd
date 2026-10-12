class_name XActorPage
extends Control
## 状态/装备共用全屏页面：原版菜单背景、窗口皮肤、角色切换与键盘返回。
signal closed
var actor_index := 0
var content: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	rebuild()

func actor() -> XActor:
	var s := XState.current
	actor_index = posmod(actor_index, s.party.size())
	return s.actor(s.party[actor_index])

func rebuild() -> void:
	for n in content.get_children():
		content.remove_child(n)
		n.queue_free()

func switch_actor(delta: int) -> void:
	actor_index += delta
	rebuild()

func window_at(rect: Rect2) -> PanelContainer:
	var w := PanelContainer.new()
	w.position = rect.position
	w.size = rect.size
	w.add_theme_stylebox_override("panel", XUI.panel(XUI.MENU_WINDOW_OPACITY))
	content.add_child(w)
	return w

func scroll_column(w: PanelContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	w.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	scroll.add_child(col)
	return col

func selector(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	for spec in [["◀", -1], ["▶", 1]]:
		var b := XUI.button(spec[0], 36)
		var d: int = spec[1]
		b.pressed.connect(func(): switch_actor(d))
		row.add_child(b)
	var a := actor()
	row.add_child(XUI.label(a.display_name() + (",「%s」" % a.nickname if a.nickname != "" else "")))

func actor_summary(parent: Control, xp := false) -> void:
	var a := actor()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	parent.add_child(row)
	var face := TextureRect.new()
	face.texture = XUI.face_texture(str(a.data().faceName), int(a.data().faceIndex))
	face.custom_minimum_size = Vector2(144, 144)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(face)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)
	info.add_child(XUI.label("%s   Lv.%d   %s" % [a.display_name(), a.level, a.class_data().name], 24))
	info.add_child(XUI.param_gauge("HP", a.hp, a.mhp, "hp", 300))
	info.add_child(XUI.param_gauge("MP", a.mp, a.mmp, "mp", 300))
	if xp:
		info.add_child(XUI.label("距下一级  %s" % (str(maxi(0, a.exp_for_level(a.level + 1) - a.exp_total)) if a.level < a.max_level() else "------"), 20))
		info.add_child(XUI.gauge(a.exp_total - a.exp_for_level(a.level), a.exp_for_level(a.level + 1) - a.exp_for_level(a.level) if a.level < a.max_level() else 1, "xp", 300, 12))

func pair(parent: Control, caption: String, value: String, color := XUI.TEXT, width := 180.0) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 36
	parent.add_child(row)
	var key := XUI.label(caption, 22, XUI.SYSTEM)
	key.custom_minimum_size.x = width
	row.add_child(key)
	var v := XUI.label(value, 22, color)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed("ui_page_up") or event.is_action_pressed("ui_page_down"):
		get_viewport().set_input_as_handled()
		switch_actor(-1 if event.is_action_pressed("ui_page_up") else 1)
