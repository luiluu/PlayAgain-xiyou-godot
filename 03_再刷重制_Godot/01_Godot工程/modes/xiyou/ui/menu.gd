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
	_clear()
	_actor_tabs(_show_status)
	var a := _cur()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	_content.add_child(top)
	_actor_face(top, a)
	var info := VBoxContainer.new()
	top.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_child(XUI.label(a.display_name()))
	name_row.add_child(XUI.label("   " + str(a.nickname), 22))
	info.add_child(name_row)
	var lv := HBoxContainer.new()
	lv.add_child(XUI.label("Lv", XUI.FONT_SIZE, XUI.SYSTEM))
	lv.add_child(XUI.label(" %d" % a.level))
	info.add_child(lv)
	info.add_child(XUI.param_gauge("HP", a.hp, a.mhp, "hp", 260))
	info.add_child(XUI.param_gauge("MP", a.mp, a.mmp, "mp", 260))
	var exp := VBoxContainer.new()
	exp.add_theme_constant_override("separation", 0)
	top.add_child(exp)
	exp.add_child(XUI.label("当前经验", 22, XUI.SYSTEM))
	exp.add_child(XUI.label(str(a.exp_total), 22))
	exp.add_child(XUI.label("距下一级", 22, XUI.SYSTEM))
	exp.add_child(XUI.label(str(maxi(0, a.exp_for_level(a.level + 1) - a.exp_total)), 22))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 36)
	_content.add_child(grid)
	for i in range(8):
		grid.add_child(XUI.label(PARAM_NAMES[i], 22, XUI.SYSTEM))
		grid.add_child(XUI.label(str(int(a.param(i))), 22))
	var x := HBoxContainer.new()
	x.add_theme_constant_override("separation", 36)
	_content.add_child(x)
	for p in [["命中", a.hit], ["闪避", a.eva], ["暴击", a.cri], ["反击", a.cnt]]:
		x.add_child(XUI.label(p[0], 22, XUI.SYSTEM))
		x.add_child(XUI.label("%d%%" % roundi(p[1] * 100), 22))
	_header("技能")
	for sk in a.skills():
		if int(sk.id) <= 2:
			continue
		var row := HBoxContainer.new()
		var ic := TextureRect.new()
		ic.texture = XUI.icon_texture(int(sk.get("iconIndex", 0)))
		ic.custom_minimum_size = Vector2(32, 32)
		row.add_child(ic)
		var l := XUI.label(("【被动】" if int(sk.stypeId) == 4 else "") + str(sk.name), 22)
		l.tooltip_text = XText.plain(str(sk.description))
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(l)
		_content.add_child(row)


func _show_equip() -> void:
	_clear()
	_actor_tabs(_show_equip)
	var a := _cur()
	var s := XState.current
	var types: Array = XDB.system().equipTypes
	var slots := a.equip_slots()
	for i in range(slots.size()):
		var current = a.equips[i]
		var choices := s.gear.filter(func(e): return int(e.etypeId) == int(slots[i]) and a.can_equip(e))
		if (current == null or current.is_empty()) and choices.is_empty():
			continue
		var row := HBoxContainer.new()
		_content.add_child(row)
		var lab := XUI.label(str(types[slots[i]]), 22, XUI.SYSTEM)
		lab.custom_minimum_size.x = 110
		row.add_child(lab)
		var has := current != null and not current.is_empty()
		var b := XUI.button(str(current.name) if has else "", 44)
		if has:
			b.icon = XUI.icon_texture(int(current.get("iconIndex", 0)))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot := i
		b.pressed.connect(func(): _choose_equip(a, slot))
		row.add_child(b)
	if _content.get_child_count() <= 1:
		_content.add_child(XUI.label("背包里没有可以装备的东西。", 22, XUI.DIM))


func _choose_equip(a: XActor, slot: int) -> void:
	_clear()
	var s := XState.current
	var et := int(a.equip_slots()[slot])
	_header("选择装备")
	var current = a.equips[slot]
	if current != null and not current.is_empty():
		var un := XUI.button("卸载", 44)
		un.icon = XUI.icon_texture(int(XDB.plugin("YEP_EquipCore").get("Remove Icon", 0)))
		un.pressed.connect(func():
			s.gear.append(current)
			a.equips[slot] = null
			a.refresh_passive()
			_show_equip())
		_content.add_child(un)
	for e in s.gear:
		if int(e.etypeId) != et or not a.can_equip(e):
			continue
		var row := HBoxContainer.new()
		_content.add_child(row)
		var b := XUI.button(str(e.name), 44)
		b.icon = XUI.icon_texture(int(e.get("iconIndex", 0)))
		b.custom_minimum_size.x = 380
		var inst: Dictionary = e
		b.pressed.connect(func():
			s.gear.erase(inst)
			if current != null and not current.is_empty():
				s.gear.append(current)
			a.equips[slot] = inst
			a.refresh_passive()
			a.hp = minf(a.hp, a.mhp)
			a.mp = minf(a.mp, a.mmp)
			_show_equip())
		row.add_child(b)
		# 能力值变化：升为 powerUpColor、降为 powerDownColor（MV Window_EquipStatus）
		for i in range(8):
			var d := int(e.params[i]) - (int(current.params[i]) if current != null and not current.is_empty() else 0)
			if d != 0:
				row.add_child(XUI.label("%s%+d" % [PARAM_NAMES[i], d], 20, XUI.POWER_UP if d > 0 else XUI.POWER_DOWN))
	var back := XUI.button("返回", 44)
	back.pressed.connect(_show_equip)
	_content.add_child(back)


func _show_items() -> void:
	_clear()
	var s := XState.current
	if s.items.is_empty() and s.gear.is_empty():
		_content.add_child(XUI.label("背包是空的。", 22, XUI.DIM))
	for id in s.items.keys():
		var rec := XDB.rec("Items", int(id))
		if rec.is_empty():
			continue
		var usable := [0, 2].has(int(rec.get("occasion", 0))) and [7, 8, 11].has(int(rec.get("scope", 0)))
		var b := XUI.button("%s" % rec.name, 44)
		b.icon = XUI.icon_texture(int(rec.get("iconIndex", 0)))
		b.tooltip_text = XText.plain(str(rec.get("description", "")))
		b.disabled = not usable
		var num := XUI.label(":%d" % s.items[id], XUI.FONT_SIZE, XUI.DIM if not usable else XUI.TEXT)
		num.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		num.offset_left = -90
		num.offset_right = -12
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(num)
		var iid := int(id)
		b.pressed.connect(func(): _use_item(iid))
		_content.add_child(b)
	if not s.gear.is_empty():
		_header("装备（%d 件）" % s.gear.size())
		for e in s.gear:
			var row := HBoxContainer.new()
			var ic := TextureRect.new()
			ic.texture = XUI.icon_texture(int(e.get("iconIndex", 0)))
			ic.custom_minimum_size = Vector2(32, 32)
			row.add_child(ic)
			row.add_child(XUI.label(str(e.name), 22))
			_content.add_child(row)


## 物品对全队/单人生效：只处理回复类效果（11 HP、12 MP、22 解除状态）。
func _use_item(id: int) -> void:
	var s := XState.current
	var rec := XDB.rec("Items", id)
	var targets := s.members() if int(rec.scope) == 8 else [_cur()]
	for t in targets:
		for eff in rec.get("effects", []):
			match int(eff.code):
				11: t.hp = minf(t.mhp, t.hp + (t.mhp * float(eff.value1) + float(eff.value2)) * t.rec)
				12: t.mp = minf(t.mmp, t.mp + (t.mmp * float(eff.value1) + float(eff.value2)) * t.rec)
				22: t.remove_state(int(eff.dataId))
	if bool(rec.get("consumable", true)):
		s.gain_item(id, -1)
	_show_items()


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
