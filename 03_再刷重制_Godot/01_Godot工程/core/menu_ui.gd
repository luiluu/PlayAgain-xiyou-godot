extends RefCounted
## Shared UI presentation for the entry menu.

static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = GameFont.current()
	theme.default_font_size = 20
	return theme

static func label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

static func button(title: String, inactive: bool = false) -> Button:
	var node := Button.new()
	node.text = title
	node.custom_minimum_size = Vector2(0, 72)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", 25)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("203b40") if state != "disabled" else Color("17292d")
		if state == "hover":
			box.bg_color = Color("2b4c50")
		if state == "pressed":
			box.bg_color = Color("152e33")
		box.border_color = Color("9d8556") if state != "disabled" else Color("405050")
		box.set_border_width_all(1 if state != "focus" else 2)
		box.set_corner_radius_all(9)
		node.add_theme_stylebox_override(state, box)
	node.add_theme_color_override("font_color", Color("f4e8cf"))
	node.add_theme_color_override("font_hover_color", Color("fff2d5"))
	node.add_theme_color_override("font_disabled_color", Color("778b8e"))
	node.disabled = inactive
	return node

static func layout(parent: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 65)
	parent.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)
	return column
