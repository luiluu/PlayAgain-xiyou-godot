extends Control
## 【Codex·未经Claude检验】 Two entry points; future mode has no gameplay design.

const UI = preload("res://core/menu_ui.gd")
var cards: GridContainer

func _ready() -> void:
	theme = UI.make_theme()
	var column := UI.layout(self)
	column.add_child(UI.label("再刷一把", 58, Color("f0e5cc")))
	column.add_child(UI.label("选择你的世界", 22, Color("a5b7b5")))
	var space := Control.new()
	space.custom_minimum_size.y = 14
	column.add_child(space)
	cards = GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 28)
	cards.add_theme_constant_override("v_separation", 18)
	column.add_child(cards)
	for mode in GameApp.modes:
		_add_card(mode)
	var footer := UI.label("开发预览", 16, Color("708c8d"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(footer)
	resized.connect(_adapt_layout)
	_adapt_layout()

func _add_card(mode: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	cards.add_child(box)
	var enabled: bool = mode["enabled"]
	var tag := UI.label("当前改版" if enabled else "未来篇章", 16, Color("b69d6c") if enabled else Color("698083"))
	box.add_child(tag)
	var entry := UI.button(str(mode["title"]), not enabled)
	entry.name = "XiyouEntry" if mode["id"] == "xiyou" else "NewEntry"
	entry.set_meta("mode_id", mode["id"])
	entry.pressed.connect(_enter.bind(str(mode["id"])))
	box.add_child(entry)
	var note := UI.label("进入开发预览" if enabled else "暂未开放", 17, Color("93a8a8") if enabled else Color("627c80"))
	box.add_child(note)

func _enter(mode_id: String) -> void:
	GameApp.enter_mode(mode_id)

func _adapt_layout() -> void:
	if is_instance_valid(cards):
		cards.columns = 1 if size.x < 900 else 2
