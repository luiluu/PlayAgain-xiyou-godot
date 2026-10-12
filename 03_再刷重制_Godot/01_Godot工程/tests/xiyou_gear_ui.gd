extends Node
var results := []
var out_dir := ""
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out_dir=arg.substr(6)
	_run.call_deferred()
func check(name: String,ok: bool) -> void:
	results.append({"name":name,"passed":ok})
	if not ok:print("FAIL ",name)
func frames() -> void:
	for i in range(6):await get_tree().process_frame
func text(n: Node) -> String:
	var value := str(n.text)+"\n" if n is Button or n is Label else ""
	for child in n.get_children():value+=text(child)
	return value
func shot(name: String) -> void:
	if out_dir=="" or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check("screenshot_"+name,get_viewport().get_texture().get_image().save_png(out_dir.path_join(name+".png"))==OK)
func _run() -> void:
	XGear.force_roll=0.5
	var s := XState.new_game(3,1,[8,9,10]);var a:=s.actor(1);a.change_level(30)
	for id in [235,236,240]:
		var e:=XGear.create("armor",id);s.register_gear(e);a.equips[int(e.etypeId)-1]=e
	a.refresh_passive()
	s.gain_gear("weapon",56,1);s.gain_item(258,2);s.gain_item(1904,1);s.gain_item(170,1)
	var status := XStatusPage.new();status.page=3;add_child(status);await frames()
	check("suit_threshold_visible",text(status).contains("狼魂") and text(status).contains("已生效") and text(status).contains("队伍掉率"))
	await shot("11_套装状态");status.queue_free();await frames()
	var equip:=XEquipPage.new();add_child(equip);await frames();equip._show_detail(a.equips[2]);await frames()
	check("quality_and_slots",text(equip).contains("品质：") and text(equip).contains("强化插槽：") and text(equip).contains("狼魂"))
	await shot("12_装备详细");equip.queue_free();await frames()
	var upgrade:=XUpgradePage.new();upgrade.selected=s.gear.back();upgrade.category=1;upgrade.material_id=258;add_child(upgrade);await frames()
	check("upgrade_material_list",text(upgrade).contains("劣质磨刀石") and upgrade.action!=null and not upgrade.action.disabled)
	var category_window:=upgrade.content.get_node("CategoryWindow") as Control
	var items_window:=upgrade.content.get_node("ItemWindow") as Control
	check("original_item_geometry",category_window.position==Vector2(0,100) and category_window.size.x==240 and items_window.position==Vector2(0,272) and items_window.size.x==get_viewport().get_visible_rect().size.x/2)
	await shot("13_原版物品强化")
	var total:=int(upgrade.selected.params[2]);upgrade._apply();await frames()
	check("upgrade_apply_once",int(upgrade.selected.params[2])==total+2 and s.item_count(258)==1 and text(upgrade).contains("(+1)"))
	upgrade.material_id=170;upgrade._show_detail();await frames()
	check("unsupported_disabled",not upgrade.material_buttons.has(170) and XGearUpgrade.reason(upgrade.selected,XDB.rec("Items",170),1)!="")
	upgrade._cancel();await frames();check("upgrade_cancel_to_actions",upgrade.phase=="action" and text(upgrade).contains("升级"))
	upgrade._cancel();await frames();check("action_cancel_to_inventory",upgrade.phase=="list" and text(upgrade).contains("练习剑"))
	s.gain_item(1,1);upgrade.selected=XDB.rec("Items",1);upgrade.phase="action";upgrade.rebuild();await frames();upgrade._use();await frames()
	check("single_item_target_selection",upgrade.phase=="targets")
	var other_hp:=s.actor(8).hp;upgrade._use_on([a]);await frames();check("item_uses_once_on_target",s.item_count(1)==0 and s.actor(8).hp==other_hp)
	upgrade.queue_free();await frames()
	var menu:=XMenu.new();add_child(menu);await frames();check("menu_item_entry",text(menu).contains("物品"));menu._show_items();await frames()
	var pages:=menu.get_children().filter(func(n):return n is XUpgradePage)
	var focus:=get_viewport().gui_get_focus_owner()
	check("upgrade_keyboard_focus",pages.size()==1 and focus!=null and pages[0].is_ancestor_of(focus))
	pages[0].closed.emit();await frames();check("upgrade_return",menu.get_children().all(func(n):return not n is XUpgradePage));menu.queue_free();await frames()
	XGear.force_roll=-1
	var passed:=results.filter(func(r):return r.passed).size();print("TEST_RESULT="+JSON.stringify({"passed":passed,"total":results.size()}));get_tree().quit(0 if passed==results.size() else 1)
