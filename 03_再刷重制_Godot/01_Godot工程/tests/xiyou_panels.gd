extends Node
## 状态/装备/胜利页面验收；全部用内存新游戏，不触及任何保存。
var results := []
var out_dir := ""
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.substr(6)
	_run.call_deferred()
func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name":name,"passed":ok,"detail":detail})
func _frames(n := 5) -> void:
	for i in range(n): await get_tree().process_frame
func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	_check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)
func _all_text(node: Node) -> String:
	var text := str(node.text) + "\n" if node is Label or node is Button else ""
	for c in node.get_children(): text += _all_text(c)
	return text
func _run() -> void:
	XEnemy.force_roll = 100
	_check("current_xiyou_font_loaded", GameFont.current() is FontFile and GameFont.current().has_char("游".unicode_at(0)))
	_check("font_shared_with_entry", preload("res://core/menu_ui.gd").make_theme().default_font == XUI.theme().default_font)
	var s := XState.new_game(3,1,[8,9,10])
	var a := s.actor(1)
	s.gain_gear("weapon",2,2)
	var item: Dictionary = s.gear.back()
	item.params[2] += 17
	item.traits.append({"code":21,"dataId":2,"value":1.25})
	var before := JSON.stringify(s.to_dict())
	var preview := XEquipment.preview(a,0,item)
	_check("preview_keeps_state", JSON.stringify(s.to_dict()) == before)
	_check("preview_changes_clone", preview != a and preview.equips[0] == item)
	var total := s.gear.size() + a.equip_list().size()
	_check("equip_valid", XEquipment.change(s,a,0,item))
	_check("trade_conserves_gear", s.gear.size() + a.equip_list().size() == total)
	_check("compare_matches_equipped", range(8).all(func(i):return a.param(i)==preview.param(i)))
	_check("unequip_valid", XEquipment.change(s,a,0,null))
	_check("unequip_conserves_gear", s.gear.size() + a.equip_list().size() == total)
	var invalid := XActor.make_equip("weapon",2); invalid.meta.req_level = 99999; s.gear.append(invalid)
	before = JSON.stringify(s.to_dict())
	_check("level_rejected", not XEquipment.change(s,a,0,invalid) and JSON.stringify(s.to_dict()) == before)
	_check("slot_rejected", not XEquipment.change(s,a,1,item))
	XEquipment.optimize(s,a)
	_check("optimize_conserves_gear", s.gear.size() + a.equip_list().size() == total + 1)
	var status := XStatusPage.new()
	add_child(status)
	await _frames()
	_check("status_params", _all_text(status).contains("命中率") and _all_text(status).contains("物理攻击"))
	await _shot("01_状态")
	status.page = 1; status.rebuild(); await _frames()
	_check("status_resistances", _all_text(status).contains("承伤") and _all_text(status).contains("终伤加成"))
	await _shot("02_加成与抗性")
	status.page = 2; status.rebuild(); await _frames()
	_check("status_mastery", _all_text(status).contains("角色可使用"))
	await _shot("03_掌握")
	status.switch_actor(1)
	_check("actor_switch", status.actor().actor_id == 8)
	status.queue_free(); await _frames()
	var equip := XEquipPage.new()
	add_child(equip); await _frames()
	_check("all_slots", _all_text(equip).contains(str(XDB.system().equipTypes.back())))
	var weapon_row := equip.find_child("Slot_武器", true, false)
	_check("slot_name_before_icon", weapon_row != null and weapon_row.find_child("SlotName",true,false).position.x < weapon_row.find_child("EquipIcon",true,false).position.x and weapon_row.find_child("EquipIcon",true,false).position.x < weapon_row.find_child("EquipName",true,false).position.x)
	await _shot("04_装备槽")
	equip.slot = 0; equip.comparing = true; equip.rebuild(); await _frames(); equip._show_detail(item); await _frames()
	_check("candidate_compare", _all_text(equip).contains("属性对比") and _all_text(equip).contains("→"))
	await _shot("05_装备对比")
	equip._toggle(); await _frames()
	_check("candidate_info", _all_text(equip).contains("装备信息"))
	await _shot("06_装备详情")
	equip.queue_free(); await _frames()
	var snapshot := {}
	for member in s.battle_members(): snapshot[member] = {"level":member.level,"exp":member.exp_total}
	var drops := [{"kind":1,"id":1},{"kind":1,"id":1},{"kind":2,"id":1}]
	var grouped := XVictoryScreen.grouped_drops(drops)
	_check("drop_groups", grouped.size() == 2 and int(grouped[0].count) == 2)
	a.gain_exp(a.exp_for_level(3))
	var victory := XVictoryScreen.new()
	victory.setup({"exp":100,"gold":40,"drops":drops},snapshot,s.battle_members(),false)
	add_child(victory); await _frames()
	before = JSON.stringify(s.to_dict())
	victory._update_exp(1)
	_check("victory_no_double_grant", JSON.stringify(s.to_dict()) == before)
	_check("victory_level_up", victory.rows[0].notified and victory.rows[0].display_level == 3)
	victory._elapsed=3.1; victory._process(0.1)
	await _frames(40); await _shot("07_胜利结算")
	victory.queue_free(); await _frames()
	var menu := XMenu.new(); add_child(menu); await _frames()
	menu._show_status(); await _frames()
	var pages := menu.get_children().filter(func(n): return n is XStatusPage)
	var focused := get_viewport().gui_get_focus_owner()
	_check("detail_keyboard_focus", pages.size() == 1 and focused != null and pages[0].is_ancestor_of(focused))
	if pages.size() == 1: pages[0].closed.emit()
	await _frames()
	_check("detail_returns_to_menu", menu.get_children().all(func(n): return not n is XStatusPage))
	menu.queue_free(); await _frames()
	# 非自动场景截图：轮到角色时停在指令窗，验证顺序条实际接入。
	var battle := XBattleScene.new()
	battle.setup(2,true,false,XDB.map(5)); add_child(battle)
	await get_tree().create_timer(1.4).timeout
	_check("otb_visible", battle.otb != null and not battle.logic.next_order.is_empty())
	await _shot("08_OTB战斗")
	battle.queue_free(); await _frames()
	# 从真实战斗胜利路径验收镜头、结算和关闭；不进入任何存档。
	battle = XBattleScene.new()
	battle.setup(2,true,false,XDB.map(5))
	for enemy in battle.logic.enemies: enemy.hp = 0
	var done := []
	battle.finished.connect(func(result): done.append(result))
	add_child(battle)
	await get_tree().create_timer(2.0).timeout
	var screens := battle.ui.get_children().filter(func(n): return n is XVictoryScreen)
	_check("battle_victory_screen", screens.size() == 1)
	_check("victory_zoom", is_equal_approx(battle.field.scale.x,2.0))
	if screens.size() == 1:
		var screen: XVictoryScreen = screens[0]
		var cmd_enter := InputEventKey.new(); cmd_enter.keycode = KEY_ENTER; cmd_enter.meta_pressed = true; cmd_enter.pressed = true
		var closing_before: bool = screen._ready_to_close
		screen._input(cmd_enter)
		_check("victory_ignores_fullscreen_key", screen._ready_to_close == closing_before and done.is_empty())
		var event := InputEventAction.new(); event.action = "ui_cancel"; event.pressed = true
		screen._input(event)
		await _frames(40); await _shot("09_战斗胜利镜头")
		screen._input(event)
		await _frames()
		_check("victory_can_exit", done == [0])
	battle.queue_free(); await _frames()
	if DisplayServer.get_name() != "headless":
		WindowFit.apply(get_window())
		await _frames(8)
		var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		_check("native_window_fit", get_window().size == WindowFit.rectangle(usable).size)
		var large := XStatusPage.new(); add_child(large)
		await _frames(); await _shot("10_Mac自适应窗口")
		large.queue_free(); await _frames()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed: print("FAIL ",r.name," ",JSON.stringify(r.detail))
	print("TEST_RESULT="+JSON.stringify({"passed":passed,"total":results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
