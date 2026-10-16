extends Node
var results := []
var out_dir := ""
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out_dir=arg.substr(6)
	_run.call_deferred()
func check(name: String,ok: bool,detail=null) -> void:
	results.append({"name":name,"passed":ok})
	if not ok:print("FAIL ",name," ",JSON.stringify(detail))
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
	check("suit_threshold_visible",status.all_text().contains("狼魂") and status.all_text().contains("已生效") and status.all_text().contains("队伍掉率"))
	await shot("11_套装状态");status.queue_free();await frames()
	# 物品页（XItemScene，参照 70～74）：窗口矩形、分类五项、列表/信息/状态、NEW、装备序号与装备者、说明卡、升级、选人使用
	var page:=XItemScene.new();add_child(page);await frames()
	check("item_geometry",[page.cat_win.position,page.cat_win.size,page.status_win.position,page.list_win.position,page.list_win.size,page.info_win.position]==[Vector2(0,0),Vector2(240,172),Vector2(240,1),Vector2(0,172),Vector2(640,548),Vector2(640,172)])
	check("item_categories",XShop.CATEGORIES.map(func(c):return c[0])==["物品","消耗品","武器","护甲","重要物品"] and page._mode=="category" and not page.help_card.visible)
	page._cat=2;page._refresh();page._ok();await frames()
	var rows:=page.entries()
	var worn:=rows.filter(func(r):return r.get("owner")!=null)
	var bag:=rows.filter(func(r):return r.has("carry"))
	check("weapon_rows_bag_and_worn",bag.size()>=1 and worn.size()>=1 and XItemRow.right_text(bag[0])=="1/9,999" and worn.any(func(r):return XItemRow.right_text(r)==a.display_name()),rows.map(func(r):return XItemRow.right_text(r)))
	var q:=rows.map(func(r):return XGearQuery.rank(XGear.quality(r.rec)))
	var sorted_q:=q.duplicate();sorted_q.sort();sorted_q.reverse()
	check("weapon_rows_quality_sorted",q==sorted_q,q)
	var first:Dictionary=page._current()
	check("new_until_cursor_leaves",s.is_new(first) and page.help_card.visible and str(page.help_card.rows[0][0])==str(first.name))
	if rows.size()>1:
		page._move(1,true);page._refresh();check("seen_after_leaving",not s.is_new(first))
		page._move(-1,true);page._refresh()
	await shot("13_原版物品强化")
	page._index=rows.find_custom(func(r):return is_same(r.rec,s.gear.back()));page._refresh();page._ok();await frames()
	check("gear_actions",page._mode=="action" and page._actions.map(func(x):return x.symbol)==["use","upgrade","lock","cancel"] and not page._actions[0].enabled and page._actions[1].enabled and page.help_card.visible)
	page._act=1;page._ok();await frames()
	var mats:=page.materials()
	var m258:=mats.find_custom(func(r):return int(r.rec.id)==258)
	check("upgrade_material_list",page._mode=="upgrade" and m258>=0 and XGearUpgrade.reason(page._item,mats[m258].rec,2)=="")
	page._up_index=m258;page._refresh()
	var total:=int(page._item.params[2]);page._ok();await frames()
	check("upgrade_apply_once",int(page._item.params[2])==total+2 and s.item_count(258)==1 and str(page._item.name).contains("(+1)") and page._mode=="upgrade")
	check("unsupported_disabled",mats.all(func(r):return int(r.rec.id)!=170) or XGearUpgrade.reason(page._item,XDB.rec("Items",170),1)!="")
	await shot("14_物品升级")
	page._cancel();await frames();check("upgrade_cancel_to_actions",page._mode=="action")
	page._cancel();await frames();check("action_cancel_to_inventory",page._mode=="list")
	page._cancel();await frames();check("list_cancel_to_category",page._mode=="category" and not page.help_card.visible)
	s.gain_item(1,1);page._cat=0;page._refresh();page._ok();await frames()
	page._index=page.entries().find_custom(func(r):return int(r.rec.id)==1);page._refresh();page._ok()
	check("item_actions",page._actions.map(func(x):return x.symbol)==["use","top","lock","cancel"] and page._actions[0].enabled)
	page._act=0;page._ok();await frames()
	check("single_item_target_selection",page._mode=="actor" and page.actor_win.visible and not page.list_win.visible and not page.help_card.visible)
	await shot("15_物品选人")
	for m in s.members():m.hp=m.mhp
	var full_buzz:=s.item_count(1);page._actor=0;page._ok();check("full_hp_buzzer",s.item_count(1)==full_buzz,[full_buzz,s.item_count(1)])
	a.hp=a.mhp-100;var other_hp:=s.actor(8).hp;page._actor=0;page._ok();await frames()
	check("item_uses_once_on_target",s.item_count(1)==full_buzz-1 and a.hp==a.mhp and s.actor(8).hp==other_hp and page._mode=="actor")
	page._cancel();await frames();check("actor_cancel_to_list",page._mode=="list")
	page.queue_free();await frames()
	# 装备页（XEquipScene，参照 75～78）：窗口矩形、指令、槽位列宽、候选＋卸载、信息/对比轮换、换装与 HP 比例、清空、换角色、说明卡
	var equip:=XEquipScene.new();add_child(equip);await frames()
	check("equip_geometry",[equip.cmd_win.position,equip.cmd_win.size,equip.status_win.position,equip.status_win.size,equip.list_win.position,equip.list_win.size,equip.lower_win.position,equip.lower_win.size]==[Vector2(0,1),Vector2(240,172),Vector2(240,1),Vector2(1040,172),Vector2(0,173),Vector2(640,547),Vector2(640,173),Vector2(640,547)])
	check("equip_commands",equip.commands().map(func(c):return c.text)==["装备","清空","返回"] and equip._mode=="command" and not equip.help_card.visible and not equip._compare)
	# YEP setSlotNameWidth：最长槽位名＋空格（正式版读数 59.21）；装备图标在其后 +2、名字 +36
	var nw:=equip.slot_name_width(equip.list_win.canvas)
	check("slot_name_width",absf(nw-59.21)<1.0,nw)
	await shot("12a_装备指令")
	equip._ok();await frames()
	check("slot_phase",equip._mode=="slot" and equip._slot==0 and equip._shown_item()==a.equips[0] and equip.help_card.visible and equip._temp_actor()==null)
	equip._move(-1,true);await frames()
	check("slot_scroll_wraps",equip._slot==a.equips.size()-1 and equip._slot_top==a.equips.size()-equip._rows() and equip.list_win.up_arrow)
	equip._slot=2;equip._slot_top=0;equip._refresh();await frames()
	check("slot_card_follows",equip.help_card.visible and str(equip.help_card.rows[0][0])==str(equip._slot_item().name))
	await shot("12b_装备槽位")
	equip._slot=0;equip._refresh();equip._ok();await frames()
	var cands:=equip.candidates()
	check("candidates_bag_and_remove",equip._mode=="item" and cands.size()==2 and int(cands[0].rec.base)==56 and XItemRow.right_text(cands[0])=="1/9,999" and cands.back().rec.is_empty(),cands.map(func(r):return r.rec.get("name","卸载")))
	check("candidate_info_and_card",equip._shown_item()==cands[0].rec and equip.help_card.visible and equip._temp_actor()!=null)
	equip.shift_lower();await frames()
	check("compare_toggle",equip._compare)
	# v0.28 属性对比列（运行时读数）：名字 6、当前值 151.21 宽 200、箭头 359.21 宽 38、新值 405.21 宽 200.79（右端 606）
	var col:=XEquipScene.compare_columns(equip.lower_win.canvas)
	var want:=[6.0,151.21,200.0,359.21,38.0,405.21,200.79]
	check("compare_columns_v028",equip.lower_win.canvas.size.x==612.0 and range(7).all(func(i):return absf(float(col[i])-want[i])<0.6),col)
	check("compare_diff_text",XEquipScene.compare_text(485,500)=="500 (+15)" and XEquipScene.compare_text(1200,1000)=="1,000 (-200)" and XEquipScene.compare_text(3,3)=="3")
	# v0.28 说明卡在左侧列表区：选中行底 +12；x = 640 − 宽 − 12（运行时读数 228,235）
	check("equip_card_in_list",equip.help_card.position==Vector2(maxf(12,640-equip.help_card.size.x-12),173+14+(equip._item_index-equip._item_top)*36+36+12) or equip.help_card.position.y<173+14+(equip._item_index-equip._item_top)*36,equip.help_card.position)
	await shot("12c_装备对比")
	var ev_tab:=InputEventKey.new();ev_tab.keycode=KEY_TAB;ev_tab.pressed=true;get_viewport().push_input(ev_tab);await frames()
	check("tab_back_to_info",not equip._compare)
	var old_weapon=a.equips[0];var gear_total:=s.gear.size()+a.equip_list().size()
	a.hp=floorf(a.mhp/2.0);var hp_rate:=a.hp/a.mhp
	equip._ok();await frames()
	check("equip_candidate",equip._mode=="slot" and is_same(a.equips[0],cands[0].rec) and s.gear.has(old_weapon) and not s.gear.has(cands[0].rec) and s.gear.size()+a.equip_list().size()==gear_total)
	check("equip_keeps_hp_rate",a.hp==maxf(1.0,floorf(a.mhp*hp_rate)),[a.hp,a.mhp])
	equip._ok();await frames();equip._item_index=equip.candidates().size()-1;equip._refresh();await frames()
	check("remove_row_no_card",not equip.help_card.visible and equip._shown_item().is_empty() and equip._temp_actor()!=null)
	equip._ok();await frames()
	check("remove_equip",equip._mode=="slot" and a.equips[0]==null and s.gear.size()+a.equip_list().size()==gear_total)
	equip._cancel();await frames()
	check("slot_cancel_to_command",equip._mode=="command" and not equip.help_card.visible and equip._shown_item().is_empty())
	equip._cmd=1;equip._ok();await frames()
	check("clear_all",a.equip_list().is_empty() and s.gear.size()==gear_total and equip._mode=="command")
	equip.switch_actor(1);await frames()
	check("actor_switch",equip.actor().actor_id==s.party[1] and equip._mode=="command")
	equip.switch_actor(-1);equip.queue_free();await frames()
	var menu:=XMenu.new();add_child(menu);await frames();check("menu_item_entry",menu.command_names().has("物品"));menu._show_items();await frames()
	var pages:=menu.get_children().filter(func(n):return n is XItemScene)
	check("item_scene_opened",pages.size()==1)
	if pages.size()==1:
		var ev:=InputEventAction.new();ev.action="ui_accept";ev.pressed=true;get_viewport().push_input(ev);await frames()
		check("item_scene_keyboard",pages[0]._mode=="list")
		pages[0].closed.emit()
	await frames();check("item_scene_return",menu.get_children().all(func(n):return not n is XItemScene));menu.queue_free();await frames()
	menu=XMenu.new();add_child(menu);await frames();menu._show_equip();await frames()
	var eq_pages:=menu.get_children().filter(func(n):return n is XEquipScene)
	check("equip_scene_opened",eq_pages.size()==1 and eq_pages[0].actor_index==0)
	if eq_pages.size()==1:
		var ev2:=InputEventAction.new();ev2.action="ui_accept";ev2.pressed=true;get_viewport().push_input(ev2);await frames()
		check("equip_scene_keyboard",eq_pages[0]._mode=="slot")
		eq_pages[0].closed.emit()
	await frames();check("equip_scene_return",menu.get_children().all(func(n):return not n is XEquipScene));menu.queue_free();await frames()
	XGear.force_roll=-1
	var passed:=results.filter(func(r):return r.passed).size();print("TEST_RESULT="+JSON.stringify({"passed":passed,"total":results.size()}));get_tree().quit(0 if passed==results.size() else 1)
