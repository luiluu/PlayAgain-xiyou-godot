extends Node
## 首期流程测试（无人操作）：入口 → 西游 → 新游戏 → 原版开局事件（Map001 选 1 号存档位、输入名字、普通难度 →
## Map002 剧情、选狗逍遥 → Map221 选求道者雕像）→ 方桌大厅（首次到达存档、学难度被动）→ 进门到一层 →
## 遇敌自动战斗获胜 → 与辛德瑞对话后离开 → 挑战守层者里德（开局等级必败，验证战败回大厅）→ 存档/读档一致。
## 对话与选项自动应答，战斗强制自动；存档写到 user://test_xiyou_flow，测试结束删除。
## 窗口模式加 -- --out=<目录> 会在关键步骤截图。

const ENTRY := "res://modes/xiyou/entry.tscn"
var results: Array = []
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
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func _key(code: Key, meta := false, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.meta_pressed = meta
	e.pressed = pressed
	return e


func _scene() -> Node:
	return get_tree().current_scene


func _wait_map(map_id: int, timeout := 600, even_busy := false) -> bool:
	for i in range(timeout):
		var s = _scene()
		if s is XMapScene and s.map_id == map_id and s.player != null and (even_busy or not s.busy):
			return true
		await get_tree().process_frame
	return false


func _event(scene: XMapScene, id: int) -> MVEvent:
	for e in scene.events:
		if e.event_id == id:
			return e
	return null


func _run() -> void:
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0   # 流程测试不出神话敌人（神话另由 xiyou_combat 测）
	XSave.dir_override = "user://test_xiyou_flow"
	Engine.time_scale = 6.0
	seed(20261012)
	# 入口 → 西游 → 新游戏
	_check("enter_xiyou", GameApp.enter_mode("xiyou"))
	await _frames(3)
	var entry = _scene()
	_check("xiyou_title", entry.scene_file_path == ENTRY and XDB.available())
	await _shot("01_西游标题.png")
	# 原版开局：存档位 1 → 模式（唯一）→ 名字 → 天道使者「是」→ 普通难度 → 接受 → 就选他（狗逍遥）
	XMessageBox.auto_answers = [0, 0, 0, "测试玩家", 0, 2, 0, 0]
	entry._new_game()
	var ok := await _wait_map(2, 3000, true)
	_check("opening_map002", ok)
	await _shot("02_开局剧情.png")
	ok = await _wait_map(221, 6000)
	_check("opening_map221", ok)
	var map: XMapScene = _scene()
	var s := XState.current
	_check("opening_choices", s.fixed_save_slot() == 1 and s.difficulty == 3 and s.actor_name == "测试玩家" and s.switch(682), [s.fixed_save_slot(), s.difficulty, s.actor_name])
	_check("opening_party", s.party == [1, 8, 10, 9], s.party)
	await _frames(10)
	await _shot("02b_教派选择.png")
	# 求道者雕像 → 方桌大厅；首次到达的自动事件存到 1 号存档位并按难度学被动
	XMessageBox.auto_answers = [0]
	await map.run_event(_event(map, 2))
	ok = await _wait_map(4, 3000)
	for i in range(600):
		if s.self_switch(4, 20, "A") and not _scene().busy:
			break
		await get_tree().process_frame
	_check("hub_loaded", ok and s.self_switch(4, 20, "A"))
	map = _scene()
	var a1 := s.actor(1)
	_check("opening_sect", s.switch(2301) and not s.switch(2302) and s.item_count(4) == 1 and s.item_count(2896) == 1 and s.item_count(10) == 1)
	# 开局被动：天道诅咒 6168（变量 14＝1）、难度适应 5980、普通难度 5548、万众一心 2571、SupperStar 2786；v0.13 走 Map002 第 5 页，不送暴爽 2747
	_check("opening_passives", [6168, 5980, 5548, 2571, 2786].all(func(id): return a1.skill_ids.has(id)) and not a1.skill_ids.has(2747), a1.skill_ids)
	_check("companion_passives", s.actor(9).skill_ids.has(5548) and s.actor(9).skill_ids.has(6168) and not s.actor(9).skill_ids.has(2571))
	_check("opening_saved_slot1", XSave.exists(1) and map.toasts.has("存档成功，储存到了1号存档！"), map.toasts)
	_check("opening_vars", s.variable(20) == 1 and s.variable(14) == 1 and s.self_switch(4, 20, "A"))
	print("opening skipped: ", JSON.stringify(map.skipped_log.map(func(r): return "%d %s" % [r.code, r.text])).left(1500))
	_check("hub_start_pos", map.player.grid == Vector2i(14, 23), map.player.grid)
	_check("hub_door_present", _event(map, 36) != null)
	# ⌘Enter 只切全屏，地图轮询确定键时不能同时触发调查。只在无界面模式按，免得真的切到全屏。
	if DisplayServer.get_name() == "headless":
		var acts := [0]
		var count := func(): acts[0] += 1
		map.player.action_pressed.connect(count)
		Input.parse_input_event(_key(KEY_META, true))
		Input.parse_input_event(_key(KEY_ENTER, true))
		# 按住若干物理帧再松开：同一物理帧内按下又松开时 is_action_just_pressed 仍为真而 ⌘ 已松开，会误判（测试时序问题，非真人操作）
		for i in range(3):
			await get_tree().physics_frame
		Input.parse_input_event(_key(KEY_ENTER, true, false))
		Input.parse_input_event(_key(KEY_META, false, false))
		await _frames(2)
		map.player.action_pressed.disconnect(count)
		get_window().mode = Window.MODE_WINDOWED
		_check("cmd_enter_not_map_action", acts[0] == 0 and not map.busy, acts[0])
	await _frames(10)
	await _shot("03_方桌大厅.png")
	# 玩家走几步（真实移动与碰撞）
	var start := map.player.grid
	for i in range(3):
		map.player.move_straight(8)
		await _frames(20)
	_check("player_walks", map.player.grid.y < start.y, [start, map.player.grid])
	# 进门到一层
	XMessageBox.auto_answers = [0]
	await map.run_event(_event(map, 36))
	ok = await _wait_map(5)
	_check("floor1_loaded", ok and _scene().player.grid == Vector2i(11, 14))
	map = _scene()
	_check("floor1_events", [2, 4, 6].all(func(id): return _event(map, id) != null))
	await _frames(10)
	await _shot("04_一层方间林地.png")
	# 辛德瑞：选择「离开」
	XMessageBox.auto_answers = [1]
	await map.run_event(_event(map, 6))
	_check("talk_leave_stays", map.map_id == 5)
	# 遇敌 → 自动战斗胜利
	var gold0 := s.gold
	var exp0 := s.actor(1).exp_total
	map._set_busy(true)
	get_tree().create_timer(2.5 * Engine.time_scale).timeout.connect(func(): _shot("05_战斗.png"))
	var result: int = await map.start_battle(2, true, false)
	map._set_busy(false)
	_check("encounter_won", result == 0, result)
	_check("rewards", s.gold > gold0 and s.actor(1).exp_total > exp0, [s.gold, s.actor(1).exp_total])
	await _frames(5)
	# 菜单、状态、商店（原版界面风格）
	map.open_menu()
	await _frames(15)
	await _shot("07_菜单.png")
	var menus := map.ui.get_children().filter(func(c): return c is XMenu)
	_check("menu_opened", menus.size() == 1)
	if menus.size() == 1:
		var m: XMenu = menus[0]
		_check("menu_commands_like_original", m.command_names().size() == 18 and m.command_names()[0] == "物品" and m.command_names()[17] == "游戏结束", m.command_names())
		# 状态：先选人（光标到队伍窗），确定后进入状态页，关闭后回到指令窗
		m._cmd_index = 3
		m._ok()
		await _frames(3)
		await _shot("07b_菜单选人.png")
		_check("menu_actor_select", m._mode == "actor")
		m._ok()
		await _frames(5)
		await _shot("08_状态.png")
		var pages := m.get_children().filter(func(n): return n is XStatusPage)
		_check("menu_status_page", pages.size() == 1)
		if pages.size() == 1:
			pages[0].closed.emit()
		await _frames(3)
		_check("menu_back_to_commands", m._mode == "command")
		# 游戏结束窗口（只截图，选「取消」返回）
		m._cmd_index = 17
		m._cmd_top = 3
		m._ok()
		await _frames(3)
		await _shot("07c_游戏结束.png")
		var ends := m.get_children().filter(func(n): return n is XGameEndPanel)
		_check("menu_game_end", ends.size() == 1)
		if ends.size() == 1:
			ends[0].closed.emit()
		await _frames(2)
		m.closed.emit()
	await _frames(3)
	_check("menu_closed", not map._menu_open)
	map.open_shop([[0, 1, 0, 0], [0, 2, 0, 0], [1, 1, 0, 0]], false)
	await _frames(10)
	await _shot("09_商店.png")
	var shops := map.ui.get_children().filter(func(c): return c is XShop)
	_check("shop_opened", shops.size() == 1)
	if shops.size() == 1:
		var sh: XShop = shops[0]
		_check("shop_commands_like_original", sh.COMMANDS.map(func(c): return c[0]) == ["购买", "出售", "一键出售", "取消"])
		# 购买：选商品 → 数量窗 → 确定（治疗药水 50）
		sh._ok()
		await _frames(3)
		await _shot("09_商店.png")
		_check("shop_help_card_buy", sh.help_card.visible and str(sh.help_card.rows[0][0]) == "治疗药水(小)")
		sh._buy_index = 2
		sh._refresh()
		await _frames(3)
		await _shot("09b_商店_武器.png")
		# 说明卡在列表窗口右侧，不盖住列表（原版参照 61：卡左边 ≈ 列表右边）
		_check("shop_help_card_weapon", str(sh.help_card.rows[0][0]) == str(XDB.rec("Weapons", 1).name) and sh.help_card.position.x - 10 >= sh.list_win.position.x + sh.list_win.size.x, sh.help_card.position)
		sh._buy_index = 0
		sh._ok()
		await _frames(3)
		await _shot("09c_商店_数量.png")
		_check("shop_number_window", sh._mode == "number" and sh._number == 1)
		_check("shop_number_hides_help_card", not sh.help_card.visible)
		var g0 := s.gold
		var n0 := s.item_count(1)
		sh._ok()
		_check("shop_bought", s.gold == g0 - 50 and s.item_count(1) == n0 + 1, [g0, s.gold, n0, s.item_count(1)])
		# 出售：分类 → 物品 → 数量 → 确定（半价 25）
		sh._cancel()
		sh._cmd = 1
		sh._ok()
		sh._ok()
		sh._refresh()
		await _frames(3)
		await _shot("09d_商店_出售.png")
		var g1 := s.gold
		var n1 := s.item_count(1)
		var idx := sh._sell_data().map(func(e): return int(e.rec.id)).find(1)
		sh._sell_index = idx
		sh._ok()
		sh._ok()
		_check("shop_sold_half_price", idx >= 0 and s.gold == g1 + 25 and s.item_count(1) == n1 - 1, [idx, g1, s.gold, n1, s.item_count(1)])
		sh.closed.emit()
	await _frames(3)
	# 存档 / 读档
	_check("save", XSave.save(1))
	var before := JSON.stringify(JSON.parse_string(JSON.stringify(s.to_dict())))
	_check("load", XSave.load_slot(1))
	var after := JSON.stringify(JSON.parse_string(JSON.stringify(XState.current.to_dict())))
	var diff := []
	for i in range(mini(before.length(), after.length())):
		if before[i] != after[i]:
			diff = [before.substr(maxi(0, i - 60), 140), after.substr(maxi(0, i - 60), 140)]
			break
	_check("save_roundtrip", before == after, diff)
	s = XState.current
	# 挑战守层者：开局等级打不过（500 万生命），不能战败 → 回方桌大厅且全员恢复
	XMessageBox.auto_answers = [0]
	await map.run_event(_event(map, 2))
	ok = await _wait_map(4, 3000)
	_check("boss_defeat_returns_hub", ok)
	_check("party_recovered", s.members().all(func(a): return a.hp == a.mhp), s.members().map(func(a): return [a.hp, a.mhp]))
	_check("boss_not_beaten", not s.self_switch(5, 2, "A"))
	await _frames(10)
	await _shot("06_战败回大厅.png")
	# 清理测试存档
	DirAccess.remove_absolute(XSave.path(1))
	DirAccess.remove_absolute(XSave.dir())
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("transcript: ", " / ".join(XMessageBox.transcript.slice(0, 12)).left(600))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
