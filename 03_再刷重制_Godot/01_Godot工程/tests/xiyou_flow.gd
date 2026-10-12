extends Node
## 首期流程测试（无人操作）：入口 → 西游 → 新游戏（普通、狗逍遥）→ 方桌大厅 → 进门到一层 →
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


func _scene() -> Node:
	return get_tree().current_scene


func _wait_map(map_id: int, timeout := 600) -> bool:
	for i in range(timeout):
		var s = _scene()
		if s is XMapScene and s.map_id == map_id and s.player != null and not s.busy:
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
	entry._difficulty = 3
	entry._choose_starter()
	await _frames(3)
	await _shot("02_选择英雄.png")
	entry._start(1)
	var ok := await _wait_map(4)
	_check("hub_loaded", ok)
	var map: XMapScene = _scene()
	var s := XState.current
	_check("party", s.party == [1, 8, 9, 10], s.party)
	_check("opening_passives", s.actor(1).skill_ids.has(5980) and s.actor(1).skill_ids.has(6168))
	_check("hub_start_pos", map.player.grid == Vector2i(14, 23), map.player.grid)
	_check("hub_door_present", _event(map, 36) != null)
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
		menus[0]._show_status()
		await _frames(5)
		await _shot("08_状态.png")
		menus[0].closed.emit()
	await _frames(3)
	_check("menu_closed", not map._menu_open)
	map.open_shop([[0, 1, 0, 0], [0, 2, 0, 0], [1, 1, 0, 0]], false)
	await _frames(10)
	await _shot("09_商店.png")
	var shops := map.ui.get_children().filter(func(c): return c is XShop)
	_check("shop_opened", shops.size() == 1)
	if shops.size() == 1:
		shops[0].closed.emit()
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
