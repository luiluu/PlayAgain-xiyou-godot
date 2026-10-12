class_name XMenu
extends Control
## 地图菜单，照原版布局（YEP_MainMenuManager ＋ MOG_MenuBackground）：
## 菜单底图＋粒子；左上指令窗（宽 240），左下金钱窗，右侧队伍状态窗（头像、名字、等级、HP/MP/TP）。
## 选「状态／装备」时右侧换成该角色的页面，可用顶部名字切换角色；物品、存档同理。窗口整体不透明度 30。

signal closed

const PARAM_NAMES := ["最大生命", "最大魔法", "攻击", "防御", "魔攻", "魔防", "敏捷", "幸运"]
const CMD_WIDTH := 240.0
var _content: VBoxContainer
var _scroll: ScrollContainer
var _gold: Label
var _selected_actor := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var vs := get_viewport_rect().size
	var cmd := PanelContainer.new()
	cmd.add_theme_stylebox_override("panel", XUI.panel(XUI.MENU_WINDOW_OPACITY))
	cmd.position = Vector2.ZERO
	cmd.custom_minimum_size.x = CMD_WIDTH
	add_child(cmd)
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	cmd.add_child(tabs)
	for t in [["状态", _show_status], ["装备", _show_equip], ["物品", _show_items], ["存档", _show_save], ["回到标题", _to_title], ["关闭", func(): closed.emit()]]:
		var b := XUI.button(t[0], XUI.LINE_HEIGHT + 12)
		b.pressed.connect(t[1])
		tabs.add_child(b)
	(tabs.get_child(0) as Button).grab_focus.call_deferred()
	# 金钱窗（MV Window_Gold：数值右对齐，货币单位系统色）
	var gold_win := PanelContainer.new()
	gold_win.add_theme_stylebox_override("panel", XUI.panel(XUI.MENU_WINDOW_OPACITY))
	gold_win.custom_minimum_size = Vector2(CMD_WIDTH, 72)
	gold_win.position = Vector2(0, vs.y - 72)
	add_child(gold_win)
	var grow := HBoxContainer.new()
	gold_win.add_child(grow)
	_gold = XUI.label(str(XState.current.gold))
	_gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grow.add_child(_gold)
	grow.add_child(XUI.label(" " + str(XDB.system().currencyUnit), XUI.FONT_SIZE, XUI.SYSTEM))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", XUI.panel(XUI.MENU_WINDOW_OPACITY))
	panel.position = Vector2(CMD_WIDTH, 0)
	panel.size = Vector2(vs.x - CMD_WIDTH, vs.y)
	add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	_scroll.add_child(_content)
	_show_party()


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()
	_scroll.scroll_vertical = 0
	_gold.text = str(XState.current.gold)


func _header(text: String) -> void:
	_content.add_child(XUI.label(text, XUI.FONT_SIZE, XUI.SYSTEM))


## MV Window_MenuStatus：每人一行，头像 144、名字/等级/称号、HP/MP/TP 量条。
func _show_party() -> void:
	_clear()
	var s := XState.current
	for i in range(s.party.size()):
		var a := s.actor(s.party[i])
		var b := Button.new()
		b.custom_minimum_size.y = 160
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.pressed.connect(func():
			_selected_actor = idx
			_show_status())
		_content.add_child(b)
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_top = 8
		row.add_theme_constant_override("separation", 24)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		_actor_face(row, a)
		var c1 := VBoxContainer.new()
		c1.custom_minimum_size.x = 220
		c1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(c1)
		c1.add_child(XUI.label(a.display_name(), XUI.FONT_SIZE, XUI.DEATH if a.is_dead() else XUI.TEXT))
		var lv := HBoxContainer.new()
		lv.add_child(XUI.label("Lv", XUI.FONT_SIZE, XUI.SYSTEM))
		lv.add_child(XUI.label(" %d" % a.level))
		c1.add_child(lv)
		c1.add_child(XUI.label(str(a.nickname), 20))
		var c2 := VBoxContainer.new()
		c2.add_theme_constant_override("separation", 6)
		c2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(c2)
		c2.add_child(XUI.param_gauge("HP", a.hp, a.mhp, "hp", 220))
		c2.add_child(XUI.param_gauge("MP", a.mp, a.mmp, "mp", 220))
		c2.add_child(XUI.param_gauge("TP", a.tp, 100, "tp", 220))
	for b in _content.get_children():
		for n in b.get_children():
			_ignore_mouse(n)


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


func _actor_face(parent: Control, a: XActor) -> void:
	var face := TextureRect.new()
	face.texture = XUI.face_texture(str(a.data().faceName), int(a.data().faceIndex))
	face.custom_minimum_size = Vector2(144, 144)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(face)


func _actor_tabs(on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var s := XState.current
	for i in range(s.party.size()):
		var a := s.actor(s.party[i])
		var b := XUI.button(a.display_name())
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if i == _selected_actor:
			b.add_theme_stylebox_override("normal", XUI.cursor_style(0.5))
		var idx := i
		b.pressed.connect(func():
			_selected_actor = idx
			on_pick.call())
		row.add_child(b)


func _cur() -> XActor:
	var s := XState.current
	_selected_actor = clampi(_selected_actor, 0, s.party.size() - 1)
	return s.actor(s.party[_selected_actor])


func _show_status() -> void:
	_open_detail(XStatusPage.new())

func _show_equip() -> void:
	_open_detail(XEquipPage.new())

func _open_detail(page: XActorPage) -> void:
	# 进入子页时隐藏主菜单控件，避免 Enter 仍触发背后的旧指令。
	for node in get_children():
		if node is CanvasItem:
			node.hide()
	page.actor_index = _selected_actor
	add_child(page)
	page.closed.connect(func():
		_selected_actor = page.actor_index
		page.queue_free()
		for node in get_children():
			if node is CanvasItem and node != page:
				node.show()
		_show_party()
		var buttons := find_children("*", "Button", true, false)
		if not buttons.is_empty():
			buttons[0].grab_focus.call_deferred())


func _show_items() -> void:
	_open_detail(XUpgradePage.new())

func _show_save() -> void:
	_clear()
	_content.add_child(XUI.label("请选择一个文件插槽。（西游重制版独立存档，与 MV 版无关）", 22, XUI.DIM))
	for i in range(1, XSave.SLOTS + 1):
		var b := XUI.button(XSave.summary(i), 56)
		b.icon = XUI.icon_texture(int(XDB.plugin("YEP_SaveCore").get("Saved Icon" if XSave.exists(i) else "Empty Icon", 0)))
		var slot := i
		b.pressed.connect(func():
			var ok := XSave.save(slot)
			_show_save()
			_content.add_child(XUI.label("已保存到存档 %d。" % slot if ok else "保存失败。", 22, XUI.POWER_UP if ok else XUI.DEATH)))
		_content.add_child(b)


func _to_title() -> void:
	get_tree().change_scene_to_file("res://modes/xiyou/entry.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
