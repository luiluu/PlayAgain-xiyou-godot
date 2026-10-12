class_name XUpgradePage
extends XActorPage
## 复现 YEP_ItemCore / ItemUpgradeSlots：上方说明，左上240分类，右上大图标/参数，
## 下方左右半屏。选装备→操作菜单「升级」→强化材料替换左下列表，确认即镶嵌。
var selected: Dictionary = {}
var material_id := 0
var category := 0
var phase := "list"
var detail: VBoxContainer
var summary: Control
var help: RichTextLabel
var action: Button
var list: VBoxContainer
var material_buttons := {}
var help_height := 100.0
var category_height := 172.0
var summary_width := 972.0
func rebuild() -> void:
	super.rebuild()
	var vs := get_viewport_rect().size
	var padding := float(XDB.plugin("YEP_CoreEngine").get("Window Padding",14))
	help_height=2*XUI.LINE_HEIGHT+2*padding
	category_height=4*XUI.LINE_HEIGHT+2*padding
	var lower := help_height+category_height
	summary_width=vs.x-240-2*padding
	var w := window_at(Rect2(0,0,vs.x,help_height));w.name="HelpWindow"
	help=RichTextLabel.new();help.bbcode_enabled=true;w.add_child(help)
	var categories:=VBoxContainer.new();categories.add_theme_constant_override("separation",0)
	w=window_at(Rect2(0,help_height,240,category_height));w.name="CategoryWindow";w.add_child(categories)
	for i in range(4):
		var b:=XUI.button(["物品","武器","防具","重要物品"][i],XUI.LINE_HEIGHT);b.alignment=HORIZONTAL_ALIGNMENT_CENTER
		var index:=i;b.pressed.connect(func():category=index;phase="list";selected={};material_id=0;rebuild())
		if i==category:b.add_theme_stylebox_override("normal",XUI.cursor_style(0.5))
		categories.add_child(b)
	w=window_at(Rect2(240,help_height,vs.x-240,category_height));w.name="ItemStatusWindow"
	summary=Control.new();summary.custom_minimum_size.y=144;w.add_child(summary)
	w=window_at(Rect2(0,lower,vs.x/2,vs.y-lower));w.name="ItemWindow";list=scroll_column(w)
	w=window_at(Rect2(vs.x/2,lower,vs.x/2,vs.y-lower));w.name="ItemInfoWindow";detail=scroll_column(w)
	if material_id>0 and not selected.is_empty():phase="materials"
	match phase:
		"action":_actions()
		"materials":_materials()
		_:_inventory()
	_show_detail()
	var buttons:=list.get_children().filter(func(n):return n is Button and not n.disabled)
	if not buttons.is_empty():buttons[0].grab_focus.call_deferred()
	elif phase=="list":(categories.get_child(category) as Button).grab_focus.call_deferred()
func _inventory() -> void:
	var s:=XState.current
	if category in [0,3]:
		for id in s.items:
			var item:=XDB.rec("Items",int(id))
			if item.is_empty() or (int(item.get("itypeId",1))==2)!=(category==3):continue
			_row(item,s.item_count(int(id)))
	else:
		var kind: String=["","weapon","armor"][category]
		for e in s.gear:
			if e.kind==kind:_row(e,1)
		if str(XDB.plugin("YEP_ItemCore").get("List Equipped Items","true"))=="true":
			for a in s.members():
				for e in a.equip_list():
					if e.kind==kind:_row(e,1,a)
	if list.get_child_count()==0:XGearInfo.text(list,"（没有物品）",XUI.DIM)
func _row_view(item: Dictionary,count: int,owner: XActor=null) -> Button:
	var b:=XUI.button("",XUI.LINE_HEIGHT)
	var row:=HBoxContainer.new();row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);row.offset_left=6;row.offset_right=-6;row.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(row)
	var icon:=TextureRect.new();icon.texture=XUI.icon_texture(int(item.iconIndex));icon.custom_minimum_size=Vector2(32,32);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(icon)
	var label:=XUI.label(str(item.name),26,XGear.color(item));label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.clip_text=true;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(label)
	if owner!=null:
		var face:=TextureRect.new();face.texture=XUI.face_texture(str(owner.data().faceName),int(owner.data().faceIndex));face.custom_minimum_size=Vector2(36,36);face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;face.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(face)
	else:row.add_child(XUI.label(":%d"%count,26))
	return b
func _row(item: Dictionary,count: int,owner: XActor=null) -> void:
	var b:=_row_view(item,count,owner)
	var show:=func():selected=item;_show_detail()
	b.focus_entered.connect(show);b.mouse_entered.connect(show)
	b.pressed.connect(func():selected=item;material_id=0;phase="action";rebuild())
	list.add_child(b)
func _actions() -> void:
	var b:=XUI.button("使用 "+str(selected.name),XUI.LINE_HEIGHT);b.clip_text=true;b.icon=XUI.icon_texture(int(selected.iconIndex));b.disabled=not _usable(selected);b.pressed.connect(_use);list.add_child(b)
	if selected.has("kind"):
		b=XUI.button(str(XDB.plugin("YEP_X_ItemUpgradeSlots").get("Upgrade Command","升级 %1")).replace("%1",str(selected.name)),XUI.LINE_HEIGHT)
		b.clip_text=true;b.icon=XUI.icon_texture(int(selected.iconIndex));XGearInfo.button_color(b,selected);b.pressed.connect(func():phase="materials";rebuild());list.add_child(b)
	b=XUI.button("取消",XUI.LINE_HEIGHT);b.pressed.connect(_cancel);list.add_child(b)
func _materials() -> void:
	material_buttons.clear();action=null
	for id in XState.current.items:
		var item:=XDB.rec("Items",int(id));var data:=XGearUpgrade.rule(item)
		if data.is_empty() or data.get(str(selected.kind),[]).is_empty() or not data.get("issues",[]).is_empty():continue
		var types: Array=data.get(str(selected.kind)+"Types",[]).map(func(v):return int(v))
		if not types.has(0) and not types.has(int(selected.get("wtypeId" if selected.kind=="weapon" else "atypeId",0))):continue
		var b:=_row_view(item,XState.current.item_count(int(id)))
		b.disabled=XGearUpgrade.reason(selected,item,XState.current.item_count(int(id)))!=""
		if b.disabled:b.modulate.a=0.5
		var iid:=int(id)
		var show:=func():material_id=iid;_show_detail()
		b.focus_entered.connect(show);b.mouse_entered.connect(show);b.pressed.connect(func():material_id=iid;_apply())
		list.add_child(b);material_buttons[iid]=b
		if iid==material_id:action=b
	if list.get_child_count()==0:XGearInfo.text(list,"（没有适用的强化材料）",XUI.DIM)
func _show_detail() -> void:
	for n in detail.get_children():detail.remove_child(n);n.queue_free()
	for n in summary.get_children():summary.remove_child(n);n.queue_free()
	if selected.is_empty():help.text="";return
	var help_item:=XDB.rec("Items",material_id) if phase=="materials" and material_id>0 else selected
	help.text=XText.to_bb(str(help_item.get("description",""))).bbcode
	var large:=TextureRect.new();large.texture=XUI.icon_texture(int(selected.iconIndex));large.position=Vector2(8,8);large.size=Vector2(128,128);large.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;large.texture_filter=Control.TEXTURE_FILTER_NEAREST;large.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;summary.add_child(large)
	for i in range(8):
		var rect:=ColorRect.new();rect.color=XUI.text_color(19);rect.modulate.a=0.5;rect.position=Vector2(144+(i%2)*(summary_width-144)/2,floori(i/2.0)*36);rect.size=Vector2((summary_width-144)/2-2,34);summary.add_child(rect)
		var value:=int(selected.get("params",[0,0,0,0,0,0,0,0])[i])
		var label:=XUI.label(XMenu.PARAM_NAMES[i],20,XUI.SYSTEM);label.position=rect.position+Vector2(6,0);summary.add_child(label)
		var number:=XUI.label("%+d"%value,20,XUI.POWER_UP if value>0 else XUI.DIM if value==0 else XUI.POWER_DOWN);number.position=rect.position+Vector2(6,0);number.size=Vector2(rect.size.x-12,36);number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;summary.add_child(number)
	if selected.has("kind"):XGearInfo.details(detail,selected)
	else:
		XGearInfo.text(detail,str(selected.name),XGear.color(selected),26)
		XGearInfo.text(detail,XText.plain(str(selected.description)),XUI.TEXT,20)
	if phase=="materials" and material_id>0:
		action=material_buttons.get(material_id)
func _apply() -> void:
	if XGearUpgrade.apply(XState.current,selected,material_id):
		var old_id:=material_id;material_id=0;rebuild()
		if material_buttons.has(old_id):material_buttons[old_id].grab_focus.call_deferred()
func _usable(item: Dictionary) -> bool:
	return not item.has("kind") and [0,2].has(int(item.get("occasion",0))) and [7,8,11].has(int(item.get("scope",0)))
func _use() -> void:
	if not _usable(selected):return
	if int(selected.scope)==8:_use_on(XState.current.members());return
	if int(selected.scope)==11:_use_on([actor()]);return
	for n in list.get_children():list.remove_child(n);n.queue_free()
	phase="targets"
	for a in XState.current.members():
		var b:=XUI.button(a.display_name(),XUI.LINE_HEIGHT);b.pressed.connect(func():_use_on([a]));list.add_child(b)
	(list.get_child(0) as Button).grab_focus.call_deferred()
func _use_on(targets: Array) -> void:
	var s:=XState.current
	if s.item_count(int(selected.id))<=0:return
	for t in targets:
		for effect in selected.get("effects",[]):
			match int(effect.code):
				11:t.hp=minf(t.mhp,t.hp+(t.mhp*float(effect.value1)+float(effect.value2))*t.rec)
				12:t.mp=minf(t.mmp,t.mp+(t.mmp*float(effect.value1)+float(effect.value2))*t.rec)
				22:t.remove_state(int(effect.dataId))
	if bool(selected.get("consumable",true)):s.gain_item(int(selected.id),-1)
	phase="list";selected={};rebuild()
func _cancel() -> void:
	if phase=="materials":phase="action";material_id=0;rebuild()
	elif phase in ["action","targets"]:phase="list";material_id=0;rebuild()
	else:closed.emit()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled();_cancel()
