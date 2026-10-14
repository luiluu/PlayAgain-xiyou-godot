extends Node
## 整队（YEP_PartySystem Scene_Party）与出战栏位模型。预期值来自正式 v0.22 浏览器实测（原版参照/claude_party_*）：
## 队伍 1,8,9,10,2,3,4 → 出战栏 [1,8,9,10,2]；整队把名单第 6 行（3）放进第 0 格 → [3,8,9,10,2]，队伍 [3,8,9,10,2,1,4]。
var results := []
var out_dir := ""
var formal := {}


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


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)


func trace(name: String, s: XState) -> void:
	var row: Array = formal.get("trace", []).filter(func(r): return r.name == name)
	if row.is_empty():
		check("formal_" + name, false, "缺少正式整队测量")
		return
	var actual := {"slots": s.battle_slots, "party": Array(s.party),
		"battle": s.battle_members().map(func(a): return a.actor_id), "leader": s.leader().actor_id if s.leader() else 0}
	# Godot JSON 数字为 float，先按稳定角色编号转 int 后比较。
	check("formal_" + name, actual.slots == row[0].slots.map(func(v): return int(v))
		and actual.party == row[0].party.map(func(v): return int(v))
		and actual.battle == row[0].battle.map(func(v): return int(v)) and actual.leader == int(row[0].leader), actual)


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_party"
	formal = XDB.load_json("oracle/party.json")
	var s := XState.new_game(3, 1, [8, 9, 10])
	for id in [2, 3, 4]:
		s.add_actor(id)
	check("slots_initial", s.battle_slots == [1, 8, 9, 10, 2] and Array(s.party) == [1, 8, 9, 10, 2, 3, 4], [s.battle_slots, s.party])
	check("battle_members", s.battle_members().map(func(a): return a.actor_id) == [1, 8, 9, 10, 2])
	trace("initial", s)

	var page := XPartyScene.new()
	add_child(page)
	await frames(3)
	check("layout", page.cmd_win.position == Vector2(0, 0) and page.cmd_win.size == Vector2(240, 172) and page.slot_win.position == Vector2(240, 0)
		and page.slot_win.size == Vector2(1040, 172) and page.list_win.position == Vector2(0, 172) and page.list_win.size == Vector2(1280, 548))
	check("initial_state", page.mode == "command" and page.slot_index == -1 and page.list_index == 1 and page.list_data() == [0, 1, 8, 9, 10, 2, 3, 4, 0])
	await shot("整队_打开.png")
	XSound.system_log.clear()
	await press("ui_accept")
	check("change_to_slot", page.mode == "slot" and page.slot_index == 0 and XSound.system_log == [1], XSound.system_log)
	await press("ui_accept")
	check("slot_to_list", page.mode == "list" and page.list_index == 1)
	for i in 5:
		await press("ui_down")
	check("list_index_6", page.list_index == 6)
	await shot("整队_名单.png")
	XSound.system_log.clear()
	await press("ui_accept")
	check("swap_matches_formal", s.battle_slots == [3, 8, 9, 10, 2] and Array(s.party) == [3, 8, 9, 10, 2, 1, 4] and page.mode == "slot", [s.battle_slots, s.party])
	trace("reserve_into_slot", s)
	check("list_ok_sounds", XSound.system_log == [1, 4], XSound.system_log)
	# 已在别格的角色：两格互换
	page.slot_index = 1
	page.mode = "list"
	page.list_index = page.list_data().find(10)
	page.ok()
	check("swap_existing", s.battle_slots == [3, 10, 9, 8, 2], s.battle_slots)
	trace("swap_existing", s)
	# 名单「离队」行：清空该格
	page.mode = "list"
	page.list_index = 0
	page.ok()
	check("list_remove_row", s.battle_slots == [3, 0, 9, 8, 2] and Array(s.party) == [3, 9, 8, 2, 1, 4, 10], [s.battle_slots, s.party])
	trace("remove_row", s)
	await shot("整队_空位.png")
	# 出战栏 Q/E：与相邻格互换，使用实际键盘输入
	page.mode = "slot"
	page.slot_index = 0
	await key(KEY_Q)
	check("page_swap_wrap", s.battle_slots == [2, 0, 9, 8, 3] and page.slot_index == 4, [s.battle_slots, page.slot_index])
	trace("page_wrap", s)
	var before_keys := s.battle_slots.duplicate()
	await key(KEY_W)
	check("w_is_up_not_swap", s.battle_slots == before_keys and page.slot_index == 4 and formal.keys.W == "up")
	await key(KEY_E)
	check("e_is_page_down", s.battle_slots == [3, 0, 9, 8, 2] and page.slot_index == 0 and formal.keys.E == "pagedown")
	await key(KEY_Q)
	# 指令「离队」：出战栏确定直接清空
	page.mode = "command"
	page.cmd_index = 1
	page.ok()
	page.slot_index = 2
	XSound.system_log.clear()
	page.ok()
	check("remove_command", s.battle_slots == [2, 0, 0, 8, 3] and XSound.system_log == [1, 4], [s.battle_slots, XSound.system_log])
	trace("remove_command", s)
	# 还原：恢复进页时的出战栏
	page.cancel()
	page.cmd_index = 2
	page.ok()
	check("revert", s.battle_slots == [1, 8, 9, 10, 2] and Array(s.party) == [1, 8, 9, 10, 2, 3, 4] and page.mode == "command", [s.battle_slots, s.party])
	trace("revert", s)
	# 完成：出战栏全空时灰显、蜂鸣
	s.battle_slots = [0, 0, 0, 0, 0]
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page.cmd_index = 3
	XSound.system_log.clear()
	page.ok()
	check("finish_disabled_buzzer", XSound.system_log == [3] and page.is_inside_tree())
	XSound.system_log.clear()
	await press("ui_cancel")
	check("empty_cancel_disabled", not closed[0] and XSound.system_log.is_empty() and not page.finish_enabled())
	for a in s.members():
		a.hp = 0
	s.battle_slots = [1, 8, 9, 10, 2]
	check("dead_all_finish_disabled", not page.finish_enabled())
	s.actor(4).recover_all()
	check("alive_reserve_finish_formal", page.finish_enabled() == bool(formal.eligibility[2].enabled))
	for a in s.members():
		a.recover_all()
	s.battle_slots = [1, 8, 9, 10, 2]
	s.rearrange_actors()
	page.ok()
	check("finish_closes", closed[0])
	page.queue_free()

	# 模型：满员时加入只排在队尾；出战栏里的人离队留空并重排（后备按编号）
	s.add_actor(5)
	check("add_when_full", s.battle_slots == [1, 8, 9, 10, 2] and Array(s.party) == [1, 8, 9, 10, 2, 3, 4, 5], s.party)
	trace("add_full", s)
	s.remove_actor(8)
	check("remove_battle_member", s.battle_slots == [1, 0, 9, 10, 2] and Array(s.party) == [1, 9, 10, 2, 3, 4, 5], [s.battle_slots, s.party])
	trace("remove_actor", s)
	s.add_actor(999999)
	check("invalid_actor_does_not_fill", s.battle_slots == [1, 0, 9, 10, 2] and not s.party.has(999999))
	s.add_actor(8)
	check("add_fills_empty", s.battle_slots == [1, 8, 9, 10, 2] and Array(s.party) == [1, 8, 9, 10, 2, 3, 4, 5], [s.battle_slots, s.party])
	trace("fill_empty", s)
	s.battle_slots[0] = 0
	s.rearrange_actors()
	s.add_actor(3)
	trace("add_existing_reserve_to_empty", s)
	s.battle_slots = [0, 8, 0, 3, 0]
	s.rearrange_actors()
	var d := s.to_dict()
	check("slots_saved_with_holes", XState.from_dict(JSON.parse_string(JSON.stringify(d))).battle_slots == [0, 8, 0, 3, 0])
	check("slots_valid_with_holes", XSave.valid_data(JSON.parse_string(JSON.stringify(d))))
	for corrupt in ["broken", [1], [8, 8, 0, 0, 0], [999999, 0, 0, 0, 0], [8.5, 0, 0, 0, 0]]:
		var bad := d.duplicate(true)
		bad.battleSlots = corrupt
		check("reject_bad_slots_" + str(corrupt), not XSave.valid_data(bad))
	d.erase("battleSlots")
	check("legacy_save_init", XState.from_dict(JSON.parse_string(JSON.stringify(d))).battle_slots == Array(s.party).slice(0, 5))
	XState.current = s
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.set_self_switch(4, 20, "A", true)
	check("save_with_holes", XSave.save(1))
	check("load_preserves_holes", XSave.load_slot(1) and XState.current.battle_slots == [0, 8, 0, 3, 0])
	s = XState.current
	# 地图与战斗必须使用实际出战者，不能把后备角色补进空位。
	var map := XMapScene.new()
	add_child(map)
	await frames(4)
	check("map_leader_from_battle", map.player.character_name == str(s.actor(8).data().characterName))
	check("map_followers_compressed", map.followers[0].character_name == str(s.actor(3).data().characterName)
		and map.followers.slice(1).all(func(f): return f.character_name == ""))
	var battle := XBattleLogic.new()
	battle.setup(2, s)
	check("battle_uses_slots", battle.actors.map(func(a): return a.actor_id) == [8, 3])
	var reserve := s.actor(1)
	reserve.exp_total = 0
	var old_level := reserve.level
	battle.grant({"exp": 20, "gold": 0, "drops": []})
	check("reserve_still_gets_exp", reserve.exp_total > 0 and reserve.level >= old_level)
	battle.end_battle()
	s.battle_slots = [0, 0, 0, 0, 0]
	map.refresh_party_sprites()
	check("empty_battle_has_no_map_leader", s.leader() == null and map.player.character_name == "")
	s.battle_slots = [0, 8, 0, 3, 0]
	map.queue_free()
	await frames(2)

	# 主菜单「整队」打开本页
	var menu := XMenu.new()
	add_child(menu)
	await frames(2)
	menu._cmd_index = XMenu.COMMANDS.map(func(c): return c[1]).find("formation")
	menu._ok()
	check("menu_opens_party", menu.get_children().any(func(n): return n is XPartyScene))
	menu.queue_free()
	if XSave.exists(1):
		DirAccess.remove_absolute(XSave.path(1))
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
