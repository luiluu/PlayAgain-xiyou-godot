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
	var padding := float(XDB.plugin("YEP_CoreEngine").get("Window Padding",14))
	var help_height := XUI.LINE_HEIGHT*2+padding*2
	var command_height := XUI.LINE_HEIGHT*4+padding*2
	var lower := help_height+command_height
	var help_win := window_at(Rect2(0, 0, vs.x, help_height))
	help = RichTextLabel.new()
	help.bbcode_enabled = true
	help.fit_content = false
	help_win.add_child(help)
	var commands := VBoxContainer.new()
	commands.add_theme_constant_override("separation", 0)
	window_at(Rect2(0, help_height, 240, command_height)).add_child(commands)
	for spec in [["装备", _slots], ["最强装备", _optimize], ["卸载全部", _clear_equips], ["返回", func(): closed.emit()]]:
		var b := XUI.button(spec[0], 36)
		b.pressed.connect(spec[1])
		commands.add_child(b)
	var status := VBoxContainer.new()
	window_at(Rect2(240, help_height, vs.x - 240, command_height)).add_child(status)

	# 装备页状态头与原版相同：头像、名字、等级、HP/MP；紧凑排列。
	var a := actor()
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 24)
	status.add_child(info)
	var face := TextureRect.new()
	face.texture = XUI.face_texture(str(a.data().faceName), int(a.data().faceIndex))
	face.custom_minimum_size = Vector2(144, 144)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info.add_child(face)
	var col := VBoxContainer.new()
	info.add_child(col)
	col.add_child(XUI.label(a.display_name(), 26))
	col.add_child(XUI.label("Lv.%d   %s" % [a.level, a.class_data().name], 24))
	col.add_child(XUI.param_gauge("HP", a.hp, a.mhp, "hp", 300))
	col.add_child(XUI.param_gauge("MP", a.mp, a.mmp, "mp", 300))
	var left := scroll_column(window_at(Rect2(0, lower, vs.x / 2, vs.y - lower)))
	var detail_window := window_at(Rect2(vs.x / 2, lower, vs.x / 2, vs.y - lower))
	detail_window.tooltip_text = "Shift / Tab 切换装备信息与属性对比"
	details = scroll_column(detail_window)
	if slot < 0:
		var name_w := _slot_name_width(a)
		for i in range(a.equips.size()):
			var e = a.equips[i]
			var b := _slot_button(str(XDB.system().equipTypes[a.equip_slots()[i]]), e, name_w)
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
	for child in left.get_children():
		if child is Button and not child.disabled:
			child.grab_focus.call_deferred()
			break

## YEP_EquipCore setSlotNameWidth：槽位名列宽 = 各槽位名加一个空格的最大字宽，装备紧跟其后靠左。
func _slot_name_width(a: XActor) -> float:
	var w := 0.0
	for t in a.equip_slots():
		w = maxf(w, XUI.font().get_string_size(str(XDB.system().equipTypes[t]) + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, XUI.FONT_SIZE).x)
	return ceilf(w)

## 槽位名独立占一列，装备图标贴着物品名称；按钮自带 icon 会排到整行最左边。
## 间距照 drawItemName：图标画在 x+2，名字从 x+36 开始。
func _slot_button(caption: String, e, name_w: float) -> Button:
	var b := XUI.button("", XUI.LINE_HEIGHT)
	b.name = "Slot_" + caption
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = 4
	row.offset_bottom = -4
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var kind := XUI.label(caption, XUI.FONT_SIZE, XUI.SYSTEM)
	kind.name = "SlotName"
	kind.custom_minimum_size.x = name_w
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
	var item_name := XUI.label(str(e.name) if e is Dictionary else "", XUI.FONT_SIZE, XGear.color(e) if e is Dictionary else XUI.TEXT)
	item_name.name = "EquipName"
	item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_name.clip_text = true
	item_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(item_name)
	return b

func _candidate(parent: Control, e) -> void:
	var b := XUI.button(str(e.name) if e is Dictionary else "卸载", 36)
	b.icon = XUI.icon_texture(int(e.get("iconIndex", 0)) if e is Dictionary else int(XDB.plugin("YEP_EquipCore").get("Remove Icon", 1354)))
	if e is Dictionary:XGearInfo.button_color(b,e)
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
			XGearInfo.details(details,e,a)
			pair(details, "背包同款", str(XState.current.gear_count(str(e.kind), int(e.base))))
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
	if event is InputEventKey and event.pressed and event.keycode in [KEY_TAB,KEY_SHIFT]:
		get_viewport().set_input_as_handled()
		_toggle()
