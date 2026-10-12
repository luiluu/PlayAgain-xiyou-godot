extends Control
## 西游模式标题：新游戏 / 继续 / 返回版本选择。新游戏进入开局选择（难度＋初始英雄）。
## 数据未生成时提示先运行转换器（数据来自正式 v0.04，只读转换，不随工程提交）。

const UI = preload("res://core/menu_ui.gd")
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const STARTERS := [1, 2, 3, 4, 5, 6, 7]
const COMPANIONS := [8, 9, 10]
const DIFFICULTIES := [[2, "简单"], [3, "普通"], [4, "困难"]]

var column: VBoxContainer
var _difficulty := 3


func _ready() -> void:
	theme = XUI.theme() if XDB.available() else UI.make_theme()
	column = UI.layout(self)
	_title()


func _clear() -> void:
	for c in column.get_children():
		c.queue_free()


func _title() -> void:
	_clear()
	column.add_child(UI.label("西游改版", 58, Color("f0e5cc")))
	column.add_child(UI.label("重制开发版 · 首期：开局区域", 20, Color("b69d6c")))
	if not XDB.available():
		column.add_child(UI.label("尚未生成游戏数据：请先运行 03_转换工具/xiyou_export.py", 20, Color("d8664f")))
	else:
		_add(UI.button("新游戏"), _choose_difficulty)
		var any := false
		for i in range(1, XSave.SLOTS + 1):
			any = any or XSave.exists(i)
		var cont := UI.button("继续", not any)
		_add(cont, _choose_save)
	var back := UI.button("返回版本选择")
	back.name = "ReturnToMenu"
	_add(back, GameApp.return_to_menu)


func _add(b: Button, fn: Callable) -> void:
	b.custom_minimum_size.x = 360
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(fn)
	column.add_child(b)


func _choose_save() -> void:
	_clear()
	column.add_child(UI.label("读取存档", 40, Color("f0e5cc")))
	for i in range(1, XSave.SLOTS + 1):
		var b := UI.button(XSave.summary(i), not XSave.exists(i))
		var slot := i
		_add(b, func():
			if XSave.load_slot(slot):
				get_tree().change_scene_to_file(MAP_SCENE))
		b.custom_minimum_size.x = 760
	_add(UI.button("返回"), _title)


func _choose_difficulty() -> void:
	_clear()
	column.add_child(UI.label("选择难度", 40, Color("f0e5cc")))
	column.add_child(UI.label("难度越高，敌人越强，奖励越多。首期提供三档。", 19, Color("93a8a8")))
	for d in DIFFICULTIES:
		var id: int = d[0]
		var rates := XEnemy.difficulty_rates(id)
		var b := UI.button("%s    敌人生命 ×%s    奖励 ×%s" % [d[1], str(rates[0]), str(Array(str(XDB.plugin("Vitsuno_Difficulty").get("%d : Drop Rate" % id, "1")).split(","))[0])])
		_add(b, func():
			_difficulty = id
			_choose_starter())
		b.custom_minimum_size.x = 760
	_add(UI.button("返回"), _title)


func _choose_starter() -> void:
	_clear()
	column.add_child(UI.label("选择你的初始英雄", 36, Color("f0e5cc")))
	column.add_child(UI.label("修、罗琳、美娜会作为伙伴同行。", 19, Color("93a8a8")))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	column.add_child(grid)
	for id in STARTERS:
		var a := XDB.rec("Actors", id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(250, 190)
		b.icon = XUI.face_texture(str(a.faceName), int(a.faceIndex))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = "%s\n%s" % [a.name, a.nickname]
		b.add_theme_font_size_override("font_size", 18)
		var m := RegEx.create_from_string("(?s)<ActorNote>(.*?)</ActorNote>").search(str(a.note))
		b.tooltip_text = m.get_string(1).strip_edges() if m else ""
		var aid: int = id
		b.pressed.connect(func(): _start(aid))
		grid.add_child(b)
	_add(UI.button("返回"), _choose_difficulty)


## 开局：与正式版 Map001/Map002 结束时一致——学会开局被动、当前层数=1、送三名伙伴，站在方桌大厅。
func _start(starter: int) -> void:
	var s := XState.new_game(_difficulty, starter, COMPANIONS)
	var cfg: Dictionary = XMapScene.slice().get("start", {})
	for k in cfg.get("variables", {}):
		s.set_variable(int(k), float(cfg.variables[k]))
	var passives := [2747, 6168]
	if _difficulty >= 2 and _difficulty <= 4:
		passives.append(5980)
	for a in s.members():
		for sid in passives:
			a.learn_skill(sid)
		a.refresh_passive()
		a.recover_all()
	s.map_id = int(cfg.get("mapId", 4))
	s.x = int(cfg.get("x", 14))
	s.y = int(cfg.get("y", 23))
	s.direction = int(cfg.get("direction", 8))
	get_tree().change_scene_to_file(MAP_SCENE)
