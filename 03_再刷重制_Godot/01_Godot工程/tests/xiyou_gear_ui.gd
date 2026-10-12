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
	var upgrade:=XUpgradePage.new();upgrade.selected=s.gear.back();upgrade.material_id=258;add_child(upgrade);await frames()
	check("upgrade_preview",text(upgrade).contains("攻击  12 → 14") and not upgrade.action.disabled)
	await shot("13_强化预览")
	var total:=int(upgrade.selected.params[2]);upgrade._apply();await frames()
	check("upgrade_apply_once",int(upgrade.selected.params[2])==total+2 and s.item_count(258)==1 and text(upgrade).contains("强化完成"))
	upgrade.material_id=170;upgrade._show_detail();await frames()
	check("unsupported_disabled",upgrade.action.disabled and text(upgrade).contains("强化效果尚未支持"))
	upgrade.queue_free();await frames()
	var menu:=XMenu.new();add_child(menu);await frames();check("menu_upgrade_entry",text(menu).contains("强化"));menu._show_upgrade();await frames()
	var pages:=menu.get_children().filter(func(n):return n is XUpgradePage)
	var focus:=get_viewport().gui_get_focus_owner()
	check("upgrade_keyboard_focus",pages.size()==1 and focus!=null and pages[0].is_ancestor_of(focus))
	pages[0].closed.emit();await frames();check("upgrade_return",menu.get_children().all(func(n):return not n is XUpgradePage));menu.queue_free();await frames()
	XGear.force_roll=-1
	var passed:=results.filter(func(r):return r.passed).size();print("TEST_RESULT="+JSON.stringify({"passed":passed,"total":results.size()}));get_tree().quit(0 if passed==results.size() else 1)
