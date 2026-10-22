extends Node
## 地图 HUD 集成：实际备份文件隔离，验证空位递增/满档保护/读档/冷却，回城事件与副本限制，配置与输入隔离。
## 窗口模式加 -- --out=<目录> 保存实际绘制截图。

var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	if out_dir != "":
		print("HUD_CHECK ", name, " ", ok)
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_hud"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	Engine.time_scale = 6.0
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.set_self_switch(4, 20, "A", true)
	s.flags.DCultyL3 = true
	s.rom.g = [71, 93, 52]
	s.rom.gn = 1
	XConfig.set_map_xy(true)
	var map := XMapScene.new()
	add_child(map)
	await frames(4)
	check("coordinates", map.map_hud.coords.visible and map.map_hud.coordinate_text() == "坐标<14,23> " and map.map_hud.difficulty_text() == "挑战模式 普通")
	check("map_button_rects", map.map_hud.backup_button.get_rect() == XMapHUD.BACKUP_RECT and map.map_hud.return_button.get_rect() == XMapHUD.RETURN_RECT)
	# 配置是局外事实，局内回滚不会改它；重开配置也能读到同一个值。
	XConfig._loaded_path = "<unloaded>"
	check("config_reload", XConfig.map_xy())
	await MVScript.run("ConfigManager.MapXy=false;", MVInterpreter.new(map, 4, 0, []))
	await frames(2)
	check("config_script_hide", not map.map_hud.coords.visible)
	await MVScript.run("ConfigManager.MapXy=true;", MVInterpreter.new(map, 4, 0, []))
	await frames(2)
	# 所有正式难度文字由实际 DCultyL 标记决定，不按 difficulty 猜。
	for i in range(1, 9):
		s.flags.clear()
		s.flags["DCultyL%d" % i] = true
		check("difficulty_%d" % i, map.map_hud.difficulty_text() == XMapHUD.DIFFICULTY_TEXT[i])
	s.flags.clear()
	check("free_mode", map.map_hud.difficulty_text() == "自由模式")
	s.flags.DCultyL3 = true
	await shot("01_地图HUD.png")
	# 地图名第一次动效尚未结束就切换，之后只按新地图的时间线移动。
	Engine.time_scale = 1.0  # Tween 的最大帧步长与 SceneTreeTimer 在高速时不同，按真实时间验证。
	map._show_map_name("旧地图")
	await get_tree().create_timer(0.4).timeout
	map._show_map_name("方桌大厅")
	await get_tree().create_timer(1.85).timeout
	var plate: Control = map.hud.find_child("MapNamePlate", true, false)
	check("map_name_reentry", absf(plate.position.y - 48) < 2 and plate.modulate.a > 0.95, plate.position)
	Engine.time_scale = 6.0
	# 忙碌时不能保存剧情中间态；立即重复点击也不新建备份。
	map.busy = true
	await map.backup_game()
	check("backup_busy_blocked", not XSave.exists(11))
	map.busy = false
	s.gold = 123
	check("normal_save", XSave.save(1))
	var normal_hash := FileAccess.get_sha256(XSave.path(1))
	if out_dir != "" and DisplayServer.get_name() != "headless":
		XMessageBox.auto = false
		map.backup_game()
		await frames(90)
		await shot("02_备份完成.png")
		map.message._terminate(0)
		while map.busy:
			await frames(1)
		XMessageBox.auto = true
	else:
		await map.backup_game()
	check("backup_first", XSave.exists(11) and XSave.current_slot == 11 and FileAccess.get_sha256(XSave.path(1)) == normal_hash)
	await map.backup_game()
	check("backup_cooldown", not XSave.exists(12))
	# 真正的鼠标事件经过 Control 命中测试：按钮区域不能成为地图的寻路目标。
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		# parse_input_event 接收窗口像素坐标；无界面窗口也会缩放逻辑画布。
		event.position = get_viewport().get_final_transform() * map.map_hud.backup_button.get_global_rect().get_center()
		event.global_position = event.position
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)
	check("backup_click_not_walk", map.player.touch_target == Vector2i(-1, -1) and map.player.grid == Vector2i(14, 23), map.player.touch_target)
	# 跳过已占的格（13），先 12 再 14，不覆盖普通格或已有备份。
	check("backup_sparse_setup", XSave.save(13))
	var sparse_hash := FileAccess.get_sha256(XSave.path(13))
	check("backup_sparse_next", XSave.backup() == 12 and XSave.backup() == 14 and FileAccess.get_sha256(XSave.path(13)) == sparse_hash)
	var backup_hash := FileAccess.get_sha256(XSave.path(11))
	for i in range(15, 31):
		XSave.save(i)
	check("backup_full_protect", XSave.backup() == 0 and FileAccess.get_sha256(XSave.path(11)) == backup_hash and XSave.current_slot == 30)
	check("invalid_slots", not XSave.save(0) and not XSave.save(31) and XSave.current_slot == 30)
	s.gold = 999
	check("backup_load", XSave.load_slot(11) and XState.current.gold == 123 and XSave.current_slot == 11 and XState.current.rom.gn == 1 and XState.current.rom.g == [71, 93, 52])
	# dev.015 之前的本工程档没有局外配置：补已发生的大厅显示开关；显式关闭的配置不能被读档改回。
	DirAccess.remove_absolute(XConfig.path_override)
	XConfig._loaded_path = "<unloaded>"
	check("old_godot_config_backfill", XSave.load_slot(11) and XConfig.map_xy())
	XConfig.set_map_xy(false)
	check("explicit_config_not_rolled_back", XSave.load_slot(11) and not XConfig.map_xy())
	XConfig.set_map_xy(true)
	s = XState.current
	# 菜单/战斗不显示 HUD；打开菜单后按取消回地图。
	map.open_menu()
	await frames(2)
	check("menu_hides_hud", not map.hud.visible)
	var menu: XMenu
	for child in map.ui.get_children():
		if child is XMenu:
			menu = child
	menu.closed.emit()
	await frames(2)
	check("menu_restores_hud", map.hud.visible)
	# 回城运行正式公共事件 10，不能绕过变量 21 的副本限制。
	await map.load_map(5, 11, 13, 2)
	await frames(2)
	s.set_variable(21, 1)
	await map.return_to_hub()
	check("return_dungeon_blocked", map.map_id == 5)
	s.set_variable(21, 0)
	# 跟随者收拢：不用穿越地图边界，也不会因为空的第五位等待不结束。
	map.followers[0].locate(11, 16)
	await map.gather_followers()
	check("followers_gather", map.followers.slice(0, 3).all(func(f): return f.grid == map.player.grid and not f.is_moving()))
	# 事件进行中点枫叶：照 reserveCommonEvent 预约，事件结束后才回城。
	map._set_busy(true)
	await map.return_to_hub()
	check("return_reserved_while_busy", map.map_id == 5 and s.peek_common_event() == 10)
	map._set_busy(false)
	for i in 600:
		await get_tree().process_frame
		if map.map_id == 4 and not map.busy:
			break
	await frames(2)
	check("return_hub_event", map.map_id == 4 and map.player.grid == Vector2i(14, 21) and map.player.direction == 8 and not map.busy and s.peek_common_event() == 0)
	# 备份位可从标题读档页访问；滚动容器让 30 格均可达。
	map.queue_free()
	await frames(2)
	var entry = load("res://modes/xiyou/entry.tscn").instantiate()
	add_child(entry)
	entry.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	entry.size = get_viewport().get_visible_rect().size
	await frames(2)
	entry._choose_save()
	await frames(3)
	var page: XSaveScene = entry.find_child("LoadPage", true, false)
	# 30 格都可达：移到第 11 格（备份位），列表滚动后它在可见范围里
	var reach := page != null
	if reach:
		page.index = 0
		for k in range(10):
			page.move(1)
		reach = page.index == 10 and page.index >= page.top and page.index < page.top + page.page_rows() and page.data(11) != null
	check("backup_load_ui", reach, page.index if page else null)
	check("backup_load_ui_fits", page != null and page.list_win.get_global_rect().end.y <= 720 and page.info_win.get_global_rect().end.y <= 720)
	await shot("03_备份读档页.png")
	entry.queue_free()
	for i in range(1, 31):
		if XSave.exists(i):
			DirAccess.remove_absolute(XSave.path(i))
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
