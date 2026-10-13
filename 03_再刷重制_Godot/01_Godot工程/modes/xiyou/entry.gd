extends Control
## 西游模式标题：照原版标题画面（titles1/login 底图、MOG_TitlePictureCom 图片指令、MOG_TitleParticles 粒子）。
## 指令：新的游戏 / 旧的回忆（读档）/ 返回版本选择。新游戏照 MV setupNewGame 从 System 起点（Map001）开始，
## 由原版开局事件选固定存档位、难度、英雄与教派（Map001 → Map002 → Map221 → 方桌大厅）。
## 数据未生成时提示先运行转换器（数据来自正式 v0.04，只读转换，不随工程提交）。

const UI = preload("res://core/menu_ui.gd")
const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
## MOG_TitlePictureCom Command Pos 1..3（原版 1280×720 坐标，图片左上角）
const COMMAND_POS := [Vector2(540, 375), Vector2(540, 450), Vector2(540, 525)]

var column: VBoxContainer
var _layer: Control               # 当前页面（标题指令或窗口）
var _commands: Array = []         # [{node, enabled, fn, top, bottom}]
var _sel := 0
var _cursor: TextureRect
var _cursor_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not XDB.available():
		theme = UI.make_theme()
		column = UI.layout(self)
		column.add_child(UI.label("尚未生成游戏数据：请先运行 03_转换工具/xiyou_export.py", 20, Color("d8664f")))
		var back := UI.button("返回版本选择")
		back.name = "ReturnToMenu"
		back.pressed.connect(GameApp.return_to_menu)
		column.add_child(back)
		return
	theme = XUI.theme()
	_build_background()
	_title()


func _build_background() -> void:
	var p := XDB.img_path("titles1", str(XDB.system().get("title1Name", "")))
	if p != "":
		var t := TextureRect.new()
		t.texture = load(p)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(t)
	var vs := get_viewport_rect().size
	# MOG_TitleParticles P1：向左上缓慢飘、加算混合
	var pp := XDB.img_path("titles2", "Particles")
	if pp != "":
		var parts := CPUParticles2D.new()
		parts.texture = load(pp)
		parts.amount = 25
		parts.lifetime = 12.0
		parts.preprocess = 12.0
		parts.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		parts.emission_rect_extents = vs / 2.0
		parts.position = vs / 2.0
		parts.direction = Vector2(-1, -0.3)
		parts.spread = 15.0
		parts.gravity = Vector2.ZERO
		parts.initial_velocity_min = 25.0
		parts.initial_velocity_max = 60.0
		parts.angular_velocity_min = -70.0
		parts.angular_velocity_max = 70.0
		parts.color_ramp = Gradient.new()
		parts.color_ramp.set_color(0, Color(1, 1, 1, 0))
		parts.color_ramp.add_point(0.2, Color(1, 1, 1, 1))
		parts.color_ramp.add_point(0.8, Color(1, 1, 1, 1))
		parts.color_ramp.set_color(parts.color_ramp.get_point_count() - 1, Color(1, 1, 1, 0))
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		parts.material = mat
		add_child(parts)


func _clear() -> void:
	if _layer:
		_layer.queue_free()
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_commands.clear()
	_cursor = null
	column = null


## 原版坐标（1280×720）换算到当前画面：横向居中对齐，纵向按比例。
func _pos(p: Vector2) -> Vector2:
	var vs := get_viewport_rect().size
	return Vector2(p.x + (vs.x - 1280.0) / 2.0, p.y * vs.y / 720.0)


func _title() -> void:
	_clear()
	var any := false
	for i in range(1, XSave.SLOTS + 1):
		any = any or XSave.exists(i)
	_add_picture_command(0, "新的游戏", true, _new_game)
	_add_picture_command(1, "旧的回忆", any, _choose_save)
	var back := _add_picture_command(-1, "返回版本选择", true, GameApp.return_to_menu)
	back.name = "ReturnToMenu"
	var ver := XUI.label("重制开发版 · 首期：开局区域", 18, XUI.DIM)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = get_viewport_rect().size - Vector2(330, 40)
	_layer.add_child(ver)
	var cp := XDB.img_path("titles2", "Cursor")
	if cp != "":
		_cursor = TextureRect.new()
		_cursor.texture = load(cp)
		_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(_cursor)
	_sel = 0
	_select(0, true)


## 图片指令：Command_N.png 上半为选中（彩色），下半为未选中（灰）；没有图片的用文字代替。
func _add_picture_command(image: int, text: String, enabled: bool, fn: Callable) -> Button:
	var idx := _commands.size()
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = _pos(COMMAND_POS[idx])
	b.size = Vector2(200, 52)
	b.disabled = not enabled
	var cmd := {"node": b, "enabled": enabled, "fn": fn}
	var p := XDB.img_path("titles2", "Command_%d" % image) if image >= 0 else ""
	if p != "":
		var tex: Texture2D = load(p)
		var h := tex.get_height() / 2.0
		cmd.top = _atlas(tex, Rect2(0, 0, tex.get_width(), h))
		cmd.bottom = _atlas(tex, Rect2(0, h, tex.get_width(), h))
		var tr := TextureRect.new()
		tr.texture = cmd.bottom
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
		cmd.rect = tr
		b.size = Vector2(tex.get_width(), h)
	else:
		b.text = text
		b.add_theme_font_size_override("font_size", 34)
		b.add_theme_constant_override("outline_size", 8)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", Color("a0a0a0"))
		b.add_theme_color_override("font_hover_color", Color("ffd36b"))
		b.size = Vector2(200, 52)
	b.modulate.a = 1.0 if enabled else 0.45
	b.mouse_entered.connect(func(): if enabled: _select(idx))
	b.pressed.connect(func(): _activate(idx))
	_layer.add_child(b)
	_commands.append(cmd)
	return b


func _atlas(tex: Texture2D, r: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = r
	return a


func _select(i: int, instant := false) -> void:
	_sel = i
	for j in range(_commands.size()):
		var c: Dictionary = _commands[j]
		if c.has("rect"):
			c.rect.texture = c.top if j == i else c.bottom
		elif j == i:
			c.node.add_theme_color_override("font_color", Color("ffd36b"))
		else:
			c.node.add_theme_color_override("font_color", Color("a0a0a0"))
	if instant and _cursor:
		_cursor.position = _cursor_target()


func _cursor_target() -> Vector2:
	var b: Button = _commands[_sel].node
	# MOG：光标在指令左侧，-3,-5 偏移，左右轻微滑动
	return b.position + Vector2(-_cursor.size.x - 3, (b.size.y - _cursor.size.y) / 2.0 - 5)


func _activate(i: int) -> void:
	var c: Dictionary = _commands[i]
	if c.enabled:
		c.fn.call()


func _process(delta: float) -> void:
	if _cursor and not _commands.is_empty():
		_cursor_t += delta
		var slide := pingpong(_cursor_t * 20.0, 15.0) - 7.5
		var target := _cursor_target() + Vector2(slide * 0.6, 0)
		_cursor.position = _cursor.position.lerp(target, minf(1.0, delta * 12.0))


func _unhandled_input(event: InputEvent) -> void:
	if _commands.is_empty():
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var step := 1 if event.is_action_pressed("ui_down") else -1
		var n := _commands.size()
		var i := _sel
		for k in range(n):
			i = (i + step + n) % n
			if _commands[i].enabled:
				break
		_select(i)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate(_sel)
		get_viewport().set_input_as_handled()


## 标题以外的页面：居中的 MV 窗口，标题用系统色。
func _window(title: String, width := 640.0) -> VBoxContainer:
	_clear()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", XUI.panel())
	panel.custom_minimum_size.x = width
	_layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	col.add_child(XUI.label(title, XUI.FONT_SIZE, XUI.SYSTEM))
	column = col
	panel.resized.connect(func(): panel.position = (get_viewport_rect().size - panel.size) / 2.0)
	return col


func _add(b: Button, fn: Callable) -> void:
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(fn)
	column.add_child(b)


func _choose_save() -> void:
	_window("读取存档", 760)
	for i in range(1, XSave.SLOTS + 1):
		var b := XUI.button(XSave.summary(i))
		b.disabled = not XSave.exists(i)
		var slot := i
		_add(b, func():
			if XSave.load_slot(slot):
				get_tree().change_scene_to_file(MAP_SCENE))
	_add(XUI.button("返回"), _title)
	_focus_first()


func _focus_first() -> void:
	for c in column.get_children():
		if c is Button and not c.disabled:
			c.grab_focus.call_deferred()
			return
		if c is GridContainer and c.get_child_count() > 0:
			c.get_child(0).grab_focus.call_deferred()
			return


## Scene_Title.commandNewGame → DataManager.setupNewGame：空队伍、难度为初始值，站在 Map001 起点，开局事件自动执行
func _new_game() -> void:
	XState.new_game_blank()
	get_tree().change_scene_to_file(MAP_SCENE)
