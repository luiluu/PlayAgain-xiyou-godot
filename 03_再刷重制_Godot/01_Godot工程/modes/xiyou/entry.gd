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
	XDifficultyNotice.ensure(get_tree())
	if not XDB.available():
		theme = UI.make_theme()
		column = UI.layout(self)
		column.add_child(UI.label("尚未生成游戏数据：请先运行 03_转换工具/xiyou_export.py", 20, Color("d8664f")))
		var back := UI.button("返回版本选择")
		back.name = "ReturnToMenu"
		back.pressed.connect(GameApp.return_to_menu)
		column.add_child(back)
		return
	XSpeedGear.apply()  # 原版 Drill_SpeedGear：整个游戏每秒 96 帧（1.6 倍），见 speed_gear.gd
	theme = XUI.theme()
	_build_background()
	# MOG_TitleSplashScreen：一次运行第一次进标题前先放开场图，放完再出标题指令（XSplashScreen）
	# 天启篇改版（O-259）：默认换成「免费游戏、禁止倒卖」声明屏（XWarningScreen）；WARNING_SCREEN = false 回到三张开场图
	if XSplashScreen.wanted() and XSplashScreen.WARNING_SCREEN:
		# 天启篇启动动画（O-待定，v8_cc）：先放动画（合眼）→ 声明屏 → 标题从黑里淡入；XIntroAnim.ENABLED = false 回到只放声明屏
		var intro := XIntroAnim.play(self)
		if intro != null:
			intro.finished.connect(func():
				XWarningScreen.play(self).finished.connect(func():
					_title()
					XIntroAnim.fade_in_title(self)))
			return
		XWarningScreen.play(self).finished.connect(_title)
		return
	if XSplashScreen.wanted():
		var sp := XSplashScreen.play(self)
		if sp != null:
			sp.finished.connect(_title)
			return
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
## 正在标题页（有图片指令），不在读档、设置等子页（XPlatform 判断返回键是不是到了顶层）。
func is_title_page() -> bool:
	return not _commands.is_empty()


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
	# 发行构建没有版本选择，不放「返回版本选择」（BI）。
	if not ReleaseEntry.skips_menu():
		var back := _add_picture_command(-1, "返回版本选择", true, GameApp.return_to_menu)
		back.name = "ReturnToMenu"
	var ver := XUI.label(ReleaseEntry.APP_NAME if ReleaseEntry.is_release() else "重制开发版 · 首期：开局区域", 18, XUI.DIM)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = get_viewport_rect().size - Vector2(330, 40)
	_layer.add_child(ver)
	if XPlatform.is_touch():
		_add_transfer_buttons()
	if XSave.exists_auto():
		_add_auto_button()
	if OS.get_cmdline_user_args().has("--report-entry"):  # 冒烟：标题有没有「继续」（安卓实机冒烟.py，平台 FB 四单）
		print("AUTO_SAVE_PRESENT=%s" % XSave.exists_auto())
	# 光标与初始选中（审查报告第 16 项：原先误放在 _load_auto 末尾，标题没有光标，读自动存档失败后才冒出来）
	var cp := XDB.img_path("titles2", "Cursor")
	if cp != "":
		_cursor = TextureRect.new()
		_cursor.texture = load(cp)
		_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(_cursor)
	_sel = 0
	_select(0, true)


## 切后台时自动存的档（XAutoSave）：有就在左上角放一个「继续」，手动存档后那份就删了、按钮也就没了
func _add_auto_button() -> void:
	var insets := XPlatform.safe_insets(get_viewport())
	var b := Button.new()
	b.name = "ContinueAuto"
	b.text = "继续（切后台时自动存的档）"
	b.position = Vector2(maxf(8.0, insets[0]), maxf(8.0, insets[1]))
	b.size = Vector2(280, 40)
	b.add_theme_font_size_override("font_size", 16)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_confirm_auto)
	_layer.add_child(b)


func _confirm_auto() -> void:
	_window("继续切后台时自动存的档")
	column.add_child(XUI.label(XSave.auto_summary()))
	column.add_child(XUI.label("读的是切到后台那一刻的进度；你的存档位不受影响。手动存一次档后，这份自动存档就作废。", 18, XUI.DIM))
	_add(XUI.button("读取"), _load_auto)
	_add(XUI.button("取消"), _title)
	_focus_first()


func _load_auto() -> void:
	if XSave.load_auto():
		get_tree().change_scene_to_file(MAP_SCENE)
	else:
		_notice("自动存档", "这份自动存档读不出来。")


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
		XKeyMap.handled(self)
	elif event.is_action_pressed("ui_accept"):
		_activate(_sel)
		XKeyMap.handled(self)


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


## 平台三期：原版二合一包标题右上的「导入存档」「导出存档」（只在触屏；虚拟按键「隐藏按键」在它们右边）。
## 刘海机右缩进或调过按键位置，「隐藏按键」（存档键回退成所有页面显示时连同存档键）挡在这一行时，两个按钮整体往左让（审查 50 P2-1）。
func _add_transfer_buttons() -> void:
	var top := maxf(8.0, XPlatform.safe_insets(get_viewport())[1])
	var right := 1160.0
	var pad := XTouchControls.instance
	if pad != null:
		var row := Rect2(940.0, top, 220.0, 40.0)
		for key in ["hide", "save"]:
			if pad.rects.has(key) and (key == "hide" or pad.save_shown()) and (pad.rects[key] as Rect2).intersects(row):
				right = minf(right, (pad.rects[key] as Rect2).position.x - 10.0)
	for spec in [["ImportSave", "导入存档", right - 220.0, _import_save], ["ExportSave", "导出存档", right - 105.0, _export_save]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.position = Vector2(spec[2], top)
		b.size = Vector2(105, 40)
		b.add_theme_font_size_override("font_size", 16)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[3])
		_layer.add_child(b)


## 一句话结果页（导入导出用）
func _notice(title: String, text: String) -> void:
	_window(title)
	column.add_child(XUI.label(text))
	_add(XUI.button("返回"), _title)
	_focus_first()


## 导出：选已有存档 → 系统「另存为」（原版 exportSave）
func _export_save() -> void:
	var slots := range(1, XSave.SLOTS + 1).filter(func(n): return XSave.exists(n))
	if slots.is_empty():
		_notice("导出存档", "还没有可导出的存档，请先在游戏中保存。")
		return
	_window("导出存档：选择存档（导出最近一次保存的进度）")
	for slot in slots:
		_add(XUI.button(XSave.summary(slot)), _export_slot.bind(slot))
	_add(XUI.button("取消"), _title)
	_focus_first()


func _export_slot(slot: int) -> void:
	var out := XSaveTransfer.export_text(slot)
	if out.has("error"):
		_notice("导出存档", "存档未导出：" + str(out.error))
		return
	var opened := XSaveTransfer.pick(true, XSaveTransfer.file_name(slot), func(path: String):
		if path == "":
			_title()
			return
		var err := XSaveTransfer.write_file(path, out.text)
		_notice("导出存档", "存档未导出：" + err if err != "" else "已导出存档 %d。" % slot))
	if not opened:
		_notice("导出存档", "这台设备打不开系统文件选择，导出不了。")


## 导入：先选 JSON、检查格式，再选存档位（原版 importsavejson → prepareJSONImport）
func _import_save() -> void:
	var opened := XSaveTransfer.pick(false, "", func(path: String):
		if path == "":
			_title()
			return
		var got := XSaveTransfer.read_import(path)
		if got.has("error"):
			_notice("导入存档", "存档未导入：" + str(got.error))
			return
		_choose_import_slot(got.data))
	if not opened:
		_notice("导入存档", "这台设备打不开系统文件选择，导入不了。")


func _choose_import_slot(data: Dictionary) -> void:
	_window("导入存档：选择存档位（已有存档会先备份一份再覆盖）")
	var grid := GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	for slot in range(1, XSave.SLOTS + 1):
		var b := XUI.button(XSave.summary(slot))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_import_slot.bind(slot, data))
		grid.add_child(b)
	_add(XUI.button("取消"), _title)
	_focus_first()


func _import_slot(slot: int, data: Dictionary) -> void:
	var err := XSaveTransfer.import_to(slot, data)
	_notice("导入存档", "存档未导入：" + err if err != "" else "已导入到存档 %d，可在「旧的回忆」读取。" % slot)


## 旧的回忆：YEP_SaveCore 的读档页（XSaveScene 读档模式）；读到档进地图，取消回标题
func _choose_save() -> void:
	_clear()
	var page := XSaveScene.new()
	page.name = "LoadPage"
	page.mode = "load"
	_layer.add_child(page)
	page.loaded.connect(func(): get_tree().change_scene_to_file(MAP_SCENE))
	page.closed.connect(_title)


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
