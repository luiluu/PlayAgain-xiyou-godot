extends Node
## 战斗画面验收：与原版参照（04_验证/本地结果/原版参照/40～43，地图 5、队伍 狗逍遥/修/罗琳/美娜、敌群 2）同一场面，
## 核对站位、窗口矩形与操作流程。内存新游戏，不写任何存档。窗口模式加 -- --out=<目录> 截图。

const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func _until(cond: Callable, n := 900) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	get_viewport().push_input(e)
	await _frames(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	get_viewport().push_input(r)
	await _frames(2)


func _run() -> void:
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	seed(20261013)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.gain_item(1, 5)
	s.map_id = 5
	s.x = 10
	s.y = 10
	s.direction = 2
	get_tree().change_scene_to_file(MAP_SCENE)
	var ok := await _until(func(): return get_tree().current_scene is XMapScene and get_tree().current_scene.player != null and not get_tree().current_scene.busy)
	_check("map5_loaded", ok)
	var map: XMapScene = get_tree().current_scene
	await _frames(10)
	XMessageBox.auto = false
	map._set_busy(true)
	var res := {"value": null}
	var go := func(): res.value = await map.start_battle(2, true, false)
	go.call()
	ok = await _until(func(): return _battle(map) != null and _battle(map).cmd_win != null)
	_check("command_shown", ok)
	var b: XBattleScene = _battle(map)
	if b == null:
		_finish()
		return
	# 站位（原版运行时：角色 x 819，y 230/329/427/526；敌人 = 敌群坐标 y + 48）
	var homes := b.logic.actors.map(func(a): return b.sprites[a].home)
	_check("actor_column", homes == [Vector2(819, 230), Vector2(819, 329), Vector2(819, 427), Vector2(819, 526)], homes)
	var ehomes := b.logic.enemies.map(func(e): return b.sprites[e].home)
	_check("enemy_reposition", ehomes == [Vector2(262, 331), Vector2(201, 463), Vector2(353, 409)], ehomes)
	_check("five_layout", XBattleScene.party_layout(5) == [Vector2(769, 216), Vector2(869, 297), Vector2(769, 378), Vector2(869, 459), Vector2(769, 540)], XBattleScene.party_layout(5))
	_check("actor_scale", is_equal_approx(b.sprites[b.logic.actors[0]].body_scale, 0.75))
	await _frames(30)
	await _shot("battle_40_input")
	# 指令窗（原版：851,462,220,196；6 条居中）
	var cw: XBattleList = b.cmd_win
	_check("command_rect", [cw.position, cw.size] == [Vector2(851, 462), Vector2(220, 196)], [cw.position, cw.size])
	_check("command_entries", cw.entries.map(func(e): return e.text) == ["攻击", "战技", "魔法", "防御", "物品", "逃跑"], cw.entries.map(func(e): return e.text))
	# 战技 → 技能列表（原版：830,478,450,51）
	await _press("ui_down")
	await _press("ui_accept")
	await _frames(5)
	var lw: XBattleList = b.list_win
	_check("skill_list_open", lw != null)
	if lw:
		_check("skill_list_rect", lw.position.x == 830.0 and lw.size == Vector2(450, 29 * lw.rows + 22), [lw.position, lw.size, lw.rows])
	await _shot("battle_41_skill")
	await _press("ui_cancel")
	await _frames(3)
	_check("list_cancel_back_to_command", b.list_win == null and b.cmd_win != null and b.cmd_win.active)
	await _press("ui_up")
	await _press("ui_accept")
	await _frames(10)
	_check("target_mode", b._target_mode == "enemy")
	var target: XEnemy = b._hover
	_check("target_defaults_to_rightmost", target != null and b.sprites[target].home.x == 353)
	_check("only_selected_cursor", b.sprites.values().filter(func(v): return v.selected).size() == 1 and b.sprites[target].cursor != null)
	_check("target_has_no_extra_help_button", not b.help_bar.visible)
	_check("auto_controls_clear_of_otb", b.auto_btn.get_global_rect().end.y < b.otb.position.y)
	await _shot("battle_42_target")
	await _press("ui_left")
	_check("keyboard_target_changes", b._hover != target and b.sprites[b._hover].selected and not b.sprites[target].selected)
	await _press("ui_cancel")
	_check("target_cancel_returns", b._target_mode == "" and b.cmd_win != null and b.cmd_win.visible and b.sprites.values().all(func(v): return not v.selected))
	await _press("ui_down")
	await _press("ui_accept")
	await _press("ui_accept")
	_check("skill_opens_target", b._target_mode == "enemy")
	await _press("ui_cancel")
	_check("skill_target_cancel_to_list", b._target_mode == "" and b.list_win != null and b.list_win.active and not b.cmd_win.active)
	await _press("ui_cancel")
	_check("skill_list_second_cancel_to_command", b.list_win == null and b.cmd_win != null and b.cmd_win.active)
	# 物品列表 → 我方目标；取消不消耗药水，目标状态条左移 24。
	for i in range(3):
		await _press("ui_down")
	await _press("ui_accept")
	_check("item_list_open", b.list_win != null)
	await _shot("battle_43_item")
	await _press("ui_accept")
	_check("item_targets_ally", b._target_mode == "ally" and b.sprites[b._hover].cursor != null and b.status_rows[b._hover].selected)
	await _shot("battle_43b_ally_target")
	await _press("ui_cancel")
	_check("item_target_cancel_to_list", b.list_win != null and b.list_win.active and s.item_count(1) == 5)
	await _press("ui_cancel")
	for i in range(4):
		await _press("ui_up")
	await _press("ui_accept")
	target = b._hover
	var hp := target.hp
	await _press("ui_accept")
	ok = await _until(func(): return b._target_mode == "" and target.hp < hp)
	_check("keyboard_target_confirm_attacks", ok, [hp, target.hp])
	# 五人结算与空掉落：第五行仍在画面内，不画虚构的「没有获得物品」。
	var members: Array = s.battle_members().duplicate()
	members.append(s.actor(2))
	var before := {}
	for a in members:
		before[a] = {"exp": a.exp_total, "level": a.level}
	var victory := XVictoryScreen.new()
	victory.setup({"gold":1234,"exp":5678,"drops":[]}, before, members, false)
	b.hide()
	map.ui.add_child(victory)
	await get_tree().create_timer(3.1).timeout
	_check("victory_five_fit", victory.rows.size() == 5 and XVictoryScreen.ROW_Y + 4 * XVictoryScreen.ROW_STEP + 72 <= 720)
	_check("victory_empty_drop_list", victory._drops.is_empty())
	await _shot("battle_44_victory_5_empty")
	_check("victory_sorted_drops", XVictoryScreen.grouped_drops([{ "kind":3,"id":2},{"kind":1,"id":2},{"kind":1,"id":1},{"kind":1,"id":2}]) == [{"kind":1,"id":1,"count":1},{"kind":1,"id":2,"count":2},{"kind":3,"id":2,"count":1}])
	_finish()


func _battle(map: XMapScene) -> XBattleScene:
	for c in map.ui.get_children():
		if c is XBattleScene:
			return c
	return null


func _finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
