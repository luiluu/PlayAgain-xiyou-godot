class_name XEquipPage
extends XActorPage
## YEP_EquipCore：顶部说明、左侧指令/右侧角色、下方左右各半（槽位/候选＋属性对比）。
var slot := -1
var comparing := false
var _hover = null
var help: RichTextLabel
var details: VBoxContainer

func rebuild() -> void:
	super.rebuild()
	var vs := get_viewport_rect().size
	var help_win := window_at(Rect2(0, 0, vs.x, 104))
	help = RichTextLabel.new()
	help.bbcode_enabled = true
	help.fit_content = false
	help_win.add_child(help)
	var commands := VBoxContainer.new()
	commands.add_theme_constant_override("separation", 0)
	window_at(Rect2(0, 104, 240, 200)).add_child(commands)
	for spec in [["装备", _slots], ["最强装备", _optimize], ["卸载全部", _clear_equips], ["返回", func(): closed.emit()]]:
		var b := XUI.button(spec[0], 36)
		b.pressed.connect(spec[1])
		commands.add_child(b)
	var status := VBoxContainer.new()
	window_at(Rect2(240, 104, vs.x - 240, 200)).add_child(status)
	selector(status)
	# 装备页状态头与原版相同：头像、名字、等级、HP/MP；紧凑排列。
	var a := actor()
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 24)
	status.add_child(info)
	var face := TextureRect.new()
	face.texture = XUI.face_texture(str(a.data().faceName), int(a.data().faceIndex))
	face.custom_minimum_size = Vector2(108, 108)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info.add_child(face)
	var col := VBoxContainer.new()
	info.add_child(col)
	col.add_child(XUI.label("Lv.%d   %s" % [a.level, a.class_data().name], 24))
	col.add_child(XUI.param_gauge("HP", a.hp, a.mhp, "hp", 300))
	col.add_child(XUI.param_gauge("MP", a.mp, a.mmp, "mp", 300))
	var left := scroll_column(window_at(Rect2(0, 304, vs.x / 2, vs.y - 304)))
	details = scroll_column(window_at(Rect2(vs.x / 2, 304, vs.x / 2, vs.y - 304)))
	if slot < 0:
		for i in range(a.equips.size()):
			var e = a.equips[i]
			var b := _slot_button(str(XDB.system().equipTypes[a.equip_slots()[i]]), e)
			b.disabled = not XEquipment.can_change(a, i)
			var idx := i
			b.pressed.connect(func(): slot = idx; comparing = true; rebuild())
			b.mouse_entered.connect(func(): _show_detail(e))
			b.focus_entered.connect(func(): _show_detail(e))
			left.add_child(b)
		_show_detail(null)
	else:
		left.add_child(XUI.label(str(XDB.system().equipTypes[a.equip_slots()[slot]]), 24, XUI.SYSTEM))
		_candidate(left, null)
		for e in XState.current.gear:
			if int(e.etypeId) == int(a.equip_slots()[slot]) and a.can_equip(e):
				_candidate(left, e)
		var back := XUI.button("返回装备槽", 36)
		back.pressed.connect(_slots)
		left.add_child(back)
		_show_detail(null)
	var toggle := XUI.button("装备信息 / 属性对比（Tab）", 36)
	toggle.pressed.connect(_toggle)
	# 固定在右侧底端，滚动内容为其留空间。
	toggle.position = Vector2(vs.x / 2 + 18, vs.y - 54)
	toggle.size.x = vs.x / 2 - 36
	content.add_child(toggle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 48
	details.add_child(spacer)
	for child in left.get_children():
		if child is Button and not child.disabled:
			child.grab_focus.call_deferred()
			break

## 槽位名独立占一列，装备图标贴着物品名称；按钮自带 icon 会排到整行最左边。
func _slot_button(caption: String, e) -> Button:
	var b := XUI.button("", 44)
	b.name = "Slot_" + caption
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = 4
	row.offset_bottom = -4
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var kind := XUI.label(caption, XUI.FONT_SIZE, XUI.SYSTEM)
	kind.name = "SlotName"
	kind.custom_minimum_size.x = 130
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(kind)
	var icon := TextureRect.new()
	icon.name = "EquipIcon"
	icon.texture = XUI.icon_texture(int(e.get("iconIndex", 0))) if e is Dictionary else null
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var item_name := XUI.label(str(e.name) if e is Dictionary else "")
	item_name.name = "EquipName"
	item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_name.clip_text = true
	item_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(item_name)
	return b

func _candidate(parent: Control, e) -> void:
	var b := XUI.button(str(e.name) if e is Dictionary else "卸载", 36)
	b.icon = XUI.icon_texture(int(e.get("iconIndex", 0)) if e is Dictionary else int(XDB.plugin("YEP_EquipCore").get("Remove Icon", 1354)))
	b.pressed.connect(func():
		if XEquipment.change(XState.current, actor(), slot, e):
			_slots())
	b.mouse_entered.connect(func(): _show_detail(e))
	b.focus_entered.connect(func(): _show_detail(e))
	parent.add_child(b)

func _show_detail(e) -> void:
	_hover = e
	for n in details.get_children():
		details.remove_child(n)
		n.queue_free()
	help.text = XText.to_bb(str(e.get("description", ""))).bbcode if e is Dictionary else "选择装备槽，查看或更换装备。" if slot < 0 else "卸下该槽装备。"
	var a := actor()
	if comparing:
		var b := XEquipment.preview(a, slot, e) if slot >= 0 else a
		details.add_child(XUI.label("%s   属性对比" % a.display_name(), 24, XUI.SYSTEM))
		for i in range(8):
			var before := int(a.param(i))
			var after := int(b.param(i))
			pair(details, XMenu.PARAM_NAMES[i], "%d → %d" % [before, after], XUI.POWER_UP if after > before else (XUI.POWER_DOWN if after < before else XUI.TEXT), 160)
	else:
		details.add_child(XUI.label("装备信息", 24, XUI.SYSTEM))
		if e is Dictionary:
			details.add_child(XUI.label(str(e.name), 26))
			pair(details, "持有数", str(XState.current.gear_count(str(e.kind), int(e.base))))
			for i in range(8):
				if int(e.params[i]) != 0:
					pair(details, XMenu.PARAM_NAMES[i], "%+d" % int(e.params[i]))
			var req := int(e.get("meta", {}).get("req_level", 0))
			if req > 0:
				pair(details, "需求等级", str(req))
		else:
			details.add_child(XUI.label("选中装备后显示详情。", 22, XUI.DIM))

func _slots() -> void:
	slot = -1
	rebuild()

func _optimize() -> void:
	XEquipment.optimize(XState.current, actor())
	_slots()

func _clear_equips() -> void:
	XEquipment.clear(XState.current, actor())
	_slots()

func _toggle() -> void:
	comparing = not comparing
	_show_detail(_hover)

func switch_actor(delta: int) -> void:
	slot = -1
	super.switch_actor(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and slot >= 0:
		get_viewport().set_input_as_handled()
		_slots()
	else:
		super._unhandled_input(event)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		_toggle()
