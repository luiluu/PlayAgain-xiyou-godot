class_name XUpgradePage
extends XActorPage
## 先选择已装备或背包装备，再选择持有的强化材料；按钮点击才消费。
var selected: Dictionary = {}
var material_id := 0
var message := ""
var detail: VBoxContainer
var preview: VBoxContainer
var action: Button
func rebuild() -> void:
	super.rebuild()
	var vs := get_viewport_rect().size
	var head := VBoxContainer.new()
	window_at(Rect2(0,0,vs.x,104)).add_child(head)
	var row := HBoxContainer.new();head.add_child(row)
	row.add_child(XUI.label("装备强化",28,XUI.SYSTEM))
	var back := XUI.button("返回",40);back.pressed.connect(func():closed.emit());row.add_child(back)
	XGearInfo.text(head,"选择装备与材料后强化；消耗 1 件材料及对应插槽。" if message=="" else message)
	var list := scroll_column(window_at(Rect2(0,104,vs.x*0.36,vs.y-104)))
	var materials := scroll_column(window_at(Rect2(vs.x*0.36,104,vs.x*0.28,vs.y-104)))
	detail=scroll_column(window_at(Rect2(vs.x*0.64,104,vs.x*0.36,vs.y-104)))
	var s := XState.current
	for a in s.members():
		list.add_child(XUI.label(a.display_name()+" · 已装备",22,XUI.SYSTEM))
		for e in a.equip_list():_gear_button(list,e)
	list.add_child(XUI.label("背包装备",22,XUI.SYSTEM))
	for e in s.gear:_gear_button(list,e)
	materials.add_child(XUI.label("强化材料",24,XUI.SYSTEM))
	var first: Button
	for id in s.items:
		var item := XDB.rec("Items",int(id))
		if not item.has("upgrade"):continue
		var b := XUI.button("%s ×%d"%[item.name,s.item_count(int(id))],44)
		b.icon=XUI.icon_texture(int(item.iconIndex));XGearInfo.button_color(b,item)
		var iid := int(id)
		b.pressed.connect(func():material_id=iid;_show_detail())
		materials.add_child(b)
		if first==null:first=b
	if first==null:XGearInfo.text(materials,"背包中没有强化材料。",XUI.DIM)
	_show_detail()
	if not selected.is_empty() and first!=null:first.grab_focus.call_deferred()
	else:
		for child in list.get_children():
			if child is Button:child.grab_focus.call_deferred();break
func _gear_button(parent: Control,e: Dictionary) -> void:
	var b := XUI.button(str(e.name),44);b.icon=XUI.icon_texture(int(e.iconIndex));XGearInfo.button_color(b,e)
	b.pressed.connect(func():selected=e;material_id=0;message="";rebuild())
	parent.add_child(b)
func _show_detail() -> void:
	for n in detail.get_children():detail.remove_child(n);n.queue_free()
	if selected.is_empty():
		XGearInfo.text(detail,"先选择一件装备。",XUI.DIM);return
	XGearInfo.details(detail,selected)
	if material_id<=0:return
	var item := XDB.rec("Items",material_id)
	var reason := XGearUpgrade.reason(selected,item,XState.current.item_count(material_id))
	XGearInfo.text(detail,"材料："+str(item.name),XGear.color(item))
	XGearInfo.text(detail,XText.plain(str(item.description)),XUI.DIM,20)
	if reason=="":
		var copy := XGearUpgrade.preview(selected,item)
		XGearInfo.text(detail,"强化后插槽：%d / %d"%[int(copy.upgradeSlots),int(copy.originalUpgradeSlots)],XUI.SYSTEM)
		for i in range(8):
			if float(copy.params[i])!=float(selected.params[i]):XGearInfo.text(detail,"%s  %d → %d"%[XMenu.PARAM_NAMES[i],int(selected.params[i]),int(copy.params[i])],XUI.POWER_UP)
		for effect in item.upgrade[str(selected.kind)]:
			if bool(effect.get("random",false)):XGearInfo.text(detail,"随机属性范围 %d～%d，以实际强化结果为准。"%[-int(effect.value),int(effect.value)+1],XUI.DIM,20)
			elif effect.op=="element":XGearInfo.text(detail,"%s加成 %+.1f%%"%[XDB.system().elements[int(effect.element)],float(effect.value)*100],XUI.POWER_UP)
			elif effect.op=="xparam":XGearInfo.text(detail,"%s %+.1f%%"%[XGearInfo.XNAMES[int(effect.param)],float(effect.value)*100],XUI.POWER_UP)
		XGearInfo.text(detail,"消耗：材料 ×1，插槽 ×%d"%int(item.upgrade.cost),XUI.SYSTEM)
	else:XGearInfo.text(detail,reason,XUI.POWER_DOWN)
	action=XUI.button("强化",44);action.disabled=reason!="";action.pressed.connect(_apply);detail.add_child(action)
func _apply() -> void:
	if XGearUpgrade.apply(XState.current,selected,material_id):message="强化完成："+str(selected.name)
	else:message="当前装备或材料不可强化。"
	rebuild()
