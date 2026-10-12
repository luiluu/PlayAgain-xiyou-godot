class_name XMenu
extends Control
## 地图菜单：状态、装备、物品、存档、回到标题。左侧分页按钮，右侧内容区；按钮够大，触屏可用。

signal closed

const PARAM_NAMES := ["最大生命", "最大魔法", "攻击", "防御", "魔攻", "魔防", "敏捷", "幸运"]
var _content: VBoxContainer
var _selected_actor := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_top = 40
	root.offset_right = -40
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size.x = 200
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for t in [["状态", _show_status], ["装备", _show_equip], ["物品", _show_items], ["存档", _show_save], ["回到标题", _to_title], ["关闭", func(): closed.emit()]]:
		var b := XUI.button(t[0], 56)
		b.pressed.connect(t[1])
		tabs.add_child(b)
	var gold := XUI.label("%d %s" % [XState.current.gold, XDB.system().currencyUnit], 20, XUI.GOLD)
	tabs.add_child(gold)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", XUI.panel())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	_show_status()


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()


func _actor_tabs(on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var s := XState.current
	for i in range(s.party.size()):
		var a := s.actor(s.party[i])
		var b := XUI.button(a.display_name(), 44)
		b.disabled = i == _selected_actor
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
	top.add_theme_constant_override("separation", 18)
	_content.add_child(top)
	var face := TextureRect.new()
	face.texture = XUI.face_texture(str(a.data().faceName), int(a.data().faceIndex))
	face.custom_minimum_size = Vector2(144, 144)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top.add_child(face)
	var info := VBoxContainer.new()
	top.add_child(info)
	info.add_child(XUI.label("%s  「%s」" % [a.display_name(), a.nickname], 26, XUI.GOLD))
	info.add_child(XUI.label("等级 %d    经验 %d / 下一级 %d" % [a.level, a.exp_total, a.exp_for_level(a.level + 1)], 20))
	info.add_child(XUI.label("HP %d / %d    MP %d / %d" % [a.hp, a.mhp, a.mp, a.mmp], 20))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 28)
	_content.add_child(grid)
	for i in range(8):
		grid.add_child(XUI.label(PARAM_NAMES[i], 19, XUI.DIM))
		grid.add_child(XUI.label(str(int(a.param(i))), 19))
	_content.add_child(XUI.label("命中 %d%%  闪避 %d%%  暴击 %d%%" % [a.hit * 100, a.eva * 100, a.cri * 100], 19))
	_content.add_child(XUI.label("技能", 22, XUI.GOLD))
	for sk in a.skills():
		if int(sk.id) <= 2:
			continue
		var l := XUI.label(("【被动】" if int(sk.stypeId) == 4 else "") + str(sk.name), 18)
		l.tooltip_text = XText.plain(str(sk.description))
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		_content.add_child(l)


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
		var lab := XUI.label(str(types[slots[i]]), 20, XUI.DIM)
		lab.custom_minimum_size.x = 90
		row.add_child(lab)
		var name := str(current.name) if current != null and not current.is_empty() else "（空）"
		var b := XUI.button(name, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var slot := i
		b.pressed.connect(func(): _choose_equip(a, slot))
		row.add_child(b)
	if _content.get_child_count() <= 1:
		_content.add_child(XUI.label("背包里没有可以装备的东西。", 20, XUI.DIM))


func _choose_equip(a: XActor, slot: int) -> void:
	_clear()
	var s := XState.current
	var et := int(a.equip_slots()[slot])
	_content.add_child(XUI.label("选择装备", 22, XUI.GOLD))
	var current = a.equips[slot]
	if current != null and not current.is_empty():
		var un := XUI.button("卸下 " + str(current.name), 46)
		un.pressed.connect(func():
			s.gear.append(current)
			a.equips[slot] = null
			a.refresh_passive()
			_show_equip())
		_content.add_child(un)
	for e in s.gear:
		if int(e.etypeId) != et or not a.can_equip(e):
			continue
		var diff := []
		for i in range(8):
			var d := int(e.params[i]) - (int(current.params[i]) if current != null and not current.is_empty() else 0)
			if d != 0:
				diff.append("%s%+d" % [PARAM_NAMES[i], d])
		var b := XUI.button("%s   %s" % [e.name, " ".join(diff)], 46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
		_content.add_child(b)
	var back := XUI.button("返回", 44)
	back.pressed.connect(_show_equip)
	_content.add_child(back)


func _show_items() -> void:
	_clear()
	var s := XState.current
	if s.items.is_empty() and s.gear.is_empty():
		_content.add_child(XUI.label("背包是空的。", 20, XUI.DIM))
	for id in s.items.keys():
		var rec := XDB.rec("Items", int(id))
		if rec.is_empty():
			continue
		var usable := [0, 2].has(int(rec.get("occasion", 0))) and [7, 8, 11].has(int(rec.get("scope", 0)))
		var b := XUI.button("%s  ×%d" % [rec.name, s.items[id]], 46)
		b.icon = XUI.icon_texture(int(rec.get("iconIndex", 0)))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = XText.plain(str(rec.get("description", "")))
		b.disabled = not usable
		var iid := int(id)
		b.pressed.connect(func(): _use_item(iid))
		_content.add_child(b)
	if not s.gear.is_empty():
		_content.add_child(XUI.label("装备（%d 件）" % s.gear.size(), 20, XUI.GOLD))
		for e in s.gear:
			_content.add_child(XUI.label("  " + str(e.name), 18))


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
	_content.add_child(XUI.label("存档（西游模式独立存档，与 MV 版无关）", 20, XUI.DIM))
	for i in range(1, XSave.SLOTS + 1):
		var b := XUI.button(XSave.summary(i), 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var slot := i
		b.pressed.connect(func():
			var ok := XSave.save(slot)
			_show_save()
			_content.add_child(XUI.label("已保存到存档 %d。" % slot if ok else "保存失败。", 20, Color("7fe08a") if ok else XUI.HP)))
		_content.add_child(b)


func _to_title() -> void:
	get_tree().change_scene_to_file("res://modes/xiyou/entry.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
