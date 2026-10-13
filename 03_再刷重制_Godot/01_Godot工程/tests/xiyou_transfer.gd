extends Node
## 地图传送页（MapTransferPlugin）：配置与解锁、预览敌人/掉率（正式 v0.13 运行时读数）、页面布局与操作流程、
## 传送与按钮显示条件、旧档补解锁、O-012～O-014。窗口模式加 -- --out=<目录> 保存实际绘制截图。

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
		print("FAIL ", name, " ", detail)


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


## 窗口开合（XMVWindow）按物理帧推进
func physics(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_transfer"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	Engine.time_scale = 6.0
	# ---- 配置 ----
	var maps := XMapTransfer.maps()
	check("config_count", maps.size() == 90, maps.size())
	check("config_first", maps[0].id == 4 and maps[0].name == "甜蜜之家" and maps[0].x == 14 and maps[0].y == 22 and maps[0].hidden and maps[0].canTransfer)
	check("config_extra", XMapTransfer.setting(220).extraEnemies == [1, 475] and not XMapTransfer.setting(220).canTransfer)
	check("config_visible", not XMapTransfer.setting(141).hidden)
	# ---- 掉率与预览（参照：出战 1/8/10/9，1 号 passiveIRUP 33 → 全队 1.33；非神话基础 0.2）----
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.set_self_switch(4, 20, "A", true)
	check("team_factor", is_equal_approx(XMapTransfer.team_drop_factor(s), 1.33), XMapTransfer.team_drop_factor(s))
	var enemies := XMapTransfer.preview_enemies(5)
	check("preview_enemies", enemies.map(func(e): return int(e.id)) == [1])
	var d := XMapTransfer.drops(s, enemies[0])
	check("preview_drops", d.map(func(x): return [x.id, x.rate]) == [[52, 13.3], [53, 1.33], [4542, 0.133]], d.map(func(x): return [x.id, x.rate]))
	check("preview_extra_enemies", XMapTransfer.preview_enemies(220).map(func(e): return int(e.id)) == [1, 475])
	check("format_hp", [100.0, 10000.0, 12345.0, 15000.0, 123456789.0].map(XMapTransfer.format_hp) == ["100", "1万", "1.23万", "1.5万", "1.23亿"])
	var img := Image.create_from_data(3, 1, false, Image.FORMAT_RGBA8, PackedByteArray([200, 100, 50, 255, 255, 0, 0, 255, 12, 200, 77, 255]))
	var h1 := XMapTransfer.rotate_hue(img, 90)
	var h2 := XMapTransfer.rotate_hue(img, 250)
	check("rotate_hue", h1.get_data().slice(0, 3) == PackedByteArray([75, 200, 50]) and h2.get_data().slice(8, 11) == PackedByteArray([200, 108, 12]))
	check("enemy_name_color", XEnemy.name_color("嘤嘤怪", 3) == Color("4499ff") and XEnemy.name_color("HP: 100", 3) == XUI.TEXT)
	# ---- 解锁与存档 ----
	var map := XMapScene.new()
	add_child(map)
	await frames(4)
	check("unlock_on_arrive", XMapTransfer.is_unlocked(s, 4) and not XMapTransfer.is_unlocked(s, 5) and not XMapTransfer.is_unlocked(s, 1))
	var old := s.to_dict()
	old.erase("unlockedMaps")
	var restored := XState.from_dict(old)
	check("old_save_backfill", XMapTransfer.is_unlocked(restored, 4) and not XMapTransfer.is_unlocked(restored, 5))
	XState.current = s
	check("save_roundtrip", XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict()))).unlocked_maps.keys() == [4])
	XState.current = s
	# ---- 按钮：变量 21 为 0 时显示；O-012 事件中不开放 ----
	check("button_rect", map.map_hud.transfer_button.get_rect() == XMapHUD.TRANSFER_RECT and map.map_hud.transfer_button.visible)
	map._set_busy(true)
	await frames(2)
	check("button_busy_disabled", map.map_hud.transfer_button.disabled)
	map._set_busy(false)
	s.set_variable(21, 1)
	await map.load_map(4, 14, 23, 2)
	await frames(2)
	check("button_hidden_in_dungeon", not map.map_hud.transfer_button.visible)
	s.set_variable(21, 0)
	await frames(2)
	check("button_appears", map.map_hud.transfer_button.visible and not map.map_hud.transfer_button.disabled)
	await shot("00_地图按钮.png")
	# ---- 页面 ----
	map.open_transfer()
	await frames(3)
	var page: XMapTransferScene = map.transfer_page
	check("page_open", page != null and map.busy and not map.hud.visible)
	check("page_rects", page.list_win.get_rect() == XMapTransferScene.LIST_RECT and page.info_win.get_rect() == XMapTransferScene.INFO_RECT
		and page.detail_win.get_rect() == XMapTransferScene.DETAIL_RECT and page.confirm_win.get_rect() == XMapTransferScene.CONFIRM_RECT)
	check("page_hub", page.index == 0 and page.map_id == 4 and page.enemies.is_empty() and page.list_win.down_arrow and not page.list_win.up_arrow)
	await shot("01_大厅.png")
	page._list_move(1, true)
	check("page_locked", page.map_id == 5 and XMapTransfer.is_locked(s, page.current_map()) and page.enemies.is_empty())
	page.confirm_map()
	await frames(2)
	page.request_transfer()
	check("locked_no_transfer", page.mode == "drops" and not page.confirm_win.visible)
	page.cancel()
	check("drops_cancel_to_list", page.mode == "list")
	XMapTransfer.on_arrive(s, 5)
	page.map_id = -1
	page._select(1)
	check("page_floor1", page.enemies.size() == 1 and page.heights == [142.0] and page.pages == [[0]], [page.heights, page.pages])
	check("drop_rects", page.drop_rects == [Rect2(250, 10, 264, 36), Rect2(524, 10, 264, 36), Rect2(798, 10, 264, 36)], page.drop_rects)
	await shot("02_一层.png")
	page.confirm_map()
	page.ok()
	check("enter_same_frame_no_detail", page.mode == "drops" and page.drop_index == 0)
	await frames(2)
	page._drop_move("left")
	check("drop_left_wraps", page.drop_index == 2)
	page._drop_move("right")
	check("drop_cooldown", page.drop_index == 2)
	await frames(12)
	page._drop_move("down")
	check("drop_down_no_wrap", page.drop_index == 2)
	page._drop_move("up")
	check("drop_up_to_last", page.drop_index == 2)
	await frames(12)
	page._drop_move("left")
	await shot("03_掉落选择.png")
	page.ok()
	await physics(10)
	check("detail_open", page.mode == "detail" and page.detail_win.visible and page.detail_win.is_open() and int(page._detail.id) == 53)
	await shot("04_掉落详情.png")
	page.ok()
	check("detail_close", page.mode == "drops" and not page.detail_win.visible)
	page.request_transfer()
	await physics(10)
	check("confirm_open", page.mode == "confirm" and page.confirm_win.is_open() and page.confirm_index == 0)
	await shot("05_传送确认.png")
	page.cancel()
	check("confirm_cancel", page.mode == "drops" and page.drop_index == 0 and not page.confirm_win.visible)
	# 不可传送的地图（嘤嘤怪的巢穴 canTransfer=false）：F 无反应
	page.cancel()
	page._select(2)
	page.confirm_map()
	await frames(2)
	page.request_transfer()
	check("cannot_transfer_map", page.mode == "drops" and not page.confirm_win.visible)
	page.cancel()
	page._select(1)
	page.confirm_map()
	await frames(2)
	page.request_transfer()
	page.confirm_ok()
	for i in 200:
		await get_tree().process_frame
		if not map.busy:
			break
	check("transfer_done", map.map_id == 5 and map.player.grid == Vector2i(11, 13) and map.player.direction == 8 and not map.busy and map.transfer_page == null and map.hud.visible and is_zero_approx(map.fader.modulate.a), [map.map_id, map.player.grid, map.busy])
	# 取消关闭：留在原地图，不淡入
	map.open_transfer()
	await frames(3)
	map.transfer_page.cancel()
	await frames(2)
	check("cancel_closes", map.transfer_page == null and map.map_id == 5 and not map.busy and map.hud.visible)
	map.queue_free()
	await frames(2)
	DirAccess.remove_absolute(XSave.dir())
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
