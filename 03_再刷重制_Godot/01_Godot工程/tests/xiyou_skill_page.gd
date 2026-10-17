extends Node
## 主菜单技能页（Scene_Skill）。预期值来自正式 v0.24 浏览器实测（原版参照/claude_skill_00、_01_list）：
## 狗逍遥 Lv10（学会 6168/5980/5548/2571/2786）：技能类型 战技/魔法/被动/其他/功法；战技列表 [160 万剑诀, 101 御剑术]，
## 地图上都不能用（战斗专用），列表两列宽 602、间距 48；选第一项时说明卡在 (650,236)。
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_skill_page"
	var s := XState.new_game(3, 1, [8, 9, 10])
	for id in [1, 8, 9, 10]:
		var a := s.actor(id)
		for k in [6168, 5980, 5548, 2571, 2786]:
			a.learn_skill(k)
		a.change_level(10)
		a.refresh_passive()
		a.recover_all()
	var page := XSkillScene.new()
	page.actor_index = 0
	add_child(page)
	await frames(3)
	check("layout", page.type_win.position == Vector2(0, 0) and page.type_win.size == Vector2(240, 172) and page.status_win.position == Vector2(240, 0)
		and page.list_win.position == Vector2(0, 172) and page.list_win.size == Vector2(1280, 548))
	var names := page.types().map(func(t): return page.type_name(t))
	check("types", names == ["战技", "魔法", "被动", "其他", "功法"], names)
	check("skill_order", s.actor(1).skills().map(func(k): return int(k.id)).slice(0, 6) == [160, 2571, 2786, 5548, 5980, 6168], s.actor(1).skills().map(func(k): return int(k.id)))
	check("list_stype1", page.entries().map(func(k): return int(k.id)) == [160, 101], page.entries().map(func(k): return int(k.id)))
	check("not_usable_on_map", page.entries().all(func(k): return not page.usable(k)))
	check("help_hidden_in_type", not page.help_card.visible)
	await shot("技能_类型.png")
	XSound.system_log.clear()
	await press("ui_accept")
	check("type_to_list", page.mode == "list" and page.index == 0 and XSound.system_log == [1], XSound.system_log)
	await frames(2)
	# 两列列表固定用正式位置（O-008 的贴边放法会盖住另一列）
	check("help_position", page.help_card.visible and page.help_card.position == Vector2(650, 236), page.help_card.position)
	await shot("技能_列表.png")
	await press("ui_right")
	check("right_moves_column", page.index == 1)
	XSound.system_log.clear()
	await press("ui_accept")
	check("battle_only_buzzer", page.mode == "list" and XSound.system_log == [3], XSound.system_log)
	await press("ui_cancel")
	check("list_cancel", page.mode == "type" and not page.help_card.visible)
	await press("ui_down")
	check("type_down", page.type_index == 1 and page.index == 0)
	# Q/E 换角色
	page.change_actor(1)
	check("next_actor", page.actor().actor_id == s.party[1] and page.mode == "type" and page.type_index == 0)
	page.change_actor(-1)
	# 地图上能用的技能：付消耗、回血，使用技能音（借用一个能在菜单用的回复技能数据）
	# 地图上能用的回复技能在数据里都是复活（对象 9）：用 499 先祖之魂（战技、无消耗）复活倒下的队友
	var a1 := s.actor(1)
	a1.learn_skill(499)
	var fallen := s.actor(s.party[1])
	fallen.add_state(1)
	fallen.hp = 0.0
	page.type_index = page.types().find(1)
	page.index = page.entries().find_custom(func(k): return int(k.id) == 499)
	page.mode = "list"
	check("revive_usable", page.usable(XDB.rec("Skills", 499)))
	page.ok()
	check("list_to_actor", page.mode == "actor" and not page.help_card.visible)   # v0.10：选人时隐藏说明卡
	page.actor_pick = 1
	XSound.system_log.clear()
	page.ok()
	check("use_skill_revives", fallen.is_alive() and fallen.hp > 0.0 and XSound.system_log == [23], [fallen.hp, XSound.system_log])
	page.actor_pick = 0
	XSound.system_log.clear()
	page.ok()
	check("no_valid_target_buzzer", XSound.system_log == [3], XSound.system_log)
	# 第五位也应能被选中／复活（Window_MenuActor 四行窗口会滚动）。
	s.add_actor(2)
	s.actor(2).add_state(1)
	page.actor_pick = 0
	page.actor_top = 0
	for i in range(4):
		page._move(1, false, false)
	var ref: Dictionary = XDB.load_json("oracle/party.json").get("menuActor", {})
	check("fifth_actor_scroll", page.actor_pick == int(ref.get("index", -1)) and page.actor_top == int(ref.get("topRow", -1))
		and XSkillScene.ACTOR_ROWS == int(ref.get("maxPageRows", -1)))
	page.ok()
	check("fifth_actor_revives", s.actor(2).is_alive())
	page.queue_free()

	# 主菜单：技能 → 选人 → 技能页
	var menu := XMenu.new()
	add_child(menu)
	await frames(2)
	menu._cmd_index = XMenu.COMMANDS.map(func(c): return c[1]).find("skill")
	menu._ok()
	menu._ok()
	check("menu_opens_skill", menu.get_children().any(func(n): return n is XSkillScene))
	menu.queue_free()
	await frames(2)
	# 事件降级会降低最大资源；原版 changeExp 最后 refresh，不能把原来的高等级 HP 留在新上限之外。
	var level_ref: Dictionary = XDB.load_json("oracle/party.json").get("levelDown", {})
	var level_state := XState.new_game_blank()
	level_state.add_actor(1)
	var level_actor := level_state.actor(int(level_ref.get("actor", 1)))
	level_actor.change_level_mv(int(level_ref.get("from", 10)))
	level_actor.recover_all()
	level_actor.change_level_mv(int(level_ref.get("to", 1)))
	check("level_down_clamps_resources", level_actor.hp == float(level_ref.get("hp", -1)) and level_actor.mp == float(level_ref.get("mp", -1)), [level_actor.hp, level_actor.mp, level_ref])
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
