extends Control
## 【Codex·未经Claude检验】 Preview landing only; no old game or save is launched.

const UI = preload("res://core/menu_ui.gd")

func _ready() -> void:
	theme = UI.make_theme()
	var column := UI.layout(self)
	column.add_child(UI.label("西游改版", 58, Color("f0e5cc")))
	column.add_child(UI.label("开发预览", 20, Color("b69d6c")))
	column.add_child(UI.label("游戏内容正在接入", 23, Color("a5b7b5")))
	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	column.add_child(gap)
	var back := UI.button("返回版本选择")
	back.name = "ReturnToMenu"
	back.custom_minimum_size.x = 320
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(GameApp.return_to_menu)
	column.add_child(back)
