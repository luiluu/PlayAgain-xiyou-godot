extends Node
## 藏宝图直接／批量使用与至臻装备闪光（XTreasureBatch、XItemScene 数量窗、XPrestigeNotice；v0.62.12 installTreasureBatchRuntime）。
## 参照：tests/fixtures/treasure_batch_ui_oracle.json（ui_reference/review_system_pages.js 的 treasure_batch／prestige_notice，新源实跑）。
## 内存新局，不读写存档。
var results := []
var out_dir := ""
var ref: Dictionary


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func frames(n := 4) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func _ref(name: String) -> Dictionary:
	return ref.shots.get(name, {})


func _key(code: int) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = true
	return k


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_treasure_batch"
	XConfig.path_override = XSave.dir().path_join("options.json")
	ref = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/treasure_batch_ui_oracle.json"))
	check("oracle_present", ref is Dictionary and ref.shots.size() == 6)
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var map212 := XDB.rec("Items", 212)
	check("supports_212", XTreasureBatch.supports(map212))
	check("supports_all_21", XTreasureMap.V029_SPECS.all(func(sp): return XTreasureBatch.supports(XDB.rec("Items", int(sp[0])))))
	check("not_supports_potion", not XTreasureBatch.supports(XDB.rec("Items", 7)))
	check("usable_now_needs_stock", not XTreasureBatch.usable_now(s, map212))
	s.gain_item(212, 5)
	check("usable_now", XTreasureBatch.usable_now(s, map212))

	# ---- 数量窗 ----
	var page := XItemScene.new()
	add_child(page)
	await frames()
	page._item = map212
	page._mode = "action"
	page._use_direct()
	await frames()
	var want: Dictionary = _ref("treasure_0_open")
	var wwin: Dictionary = want.window
	check("window_open", not page._treasure.is_empty() and page.treasure_win.visible and str(page._treasure.state) == "quantity")
	check("window_rect", Rect2(page.treasure_win.position, page.treasure_win.size) == Rect2(wwin.rect[0], wwin.rect[1], wwin.rect[2], wwin.rect[3]),
		[page.treasure_win.position, page.treasure_win.size])
	check("number_start_1_max_5", int(page._treasure.number) == int(want.extra.number.number) and int(page._treasure.max) == int(want.extra.number.max))
	var rs := page._treasure_button_rects()
	var wb: Array = want.extra.number.buttons
	var ok_btn := true
	for i in 5:
		if rs[i] != Rect2(wb[i][0], wb[i][1], wb[i][2], wb[i][3]):
			ok_btn = false
	check("buttons", ok_btn and XItemScene.TREASURE_MAX_RECT == Rect2(wb[5][0], wb[5][1], wb[5][2], wb[5][3]), [rs, wb])
	check("help_hidden_while_open", not page.help_card.visible)
	await shot("treasure_01_open")
	page._unhandled_input(_key(KEY_RIGHT))
	page._unhandled_input(_key(KEY_RIGHT))
	check("right_plus_1", int(page._treasure.number) == int(_ref("treasure_1_plus").extra.number.number))
	page._unhandled_input(_key(KEY_UP))
	check("up_plus_10_clamped", int(page._treasure.number) == 5)
	page._unhandled_input(_key(KEY_DOWN))
	check("down_minus_10_clamped", int(page._treasure.number) == 1)
	page._unhandled_input(_key(KEY_PAGEDOWN))
	check("pagedown_max", int(page._treasure.number) == 5)
	var mx := InputEventMouseButton.new()
	mx.button_index = MOUSE_BUTTON_LEFT
	mx.pressed = true
	page._treasure.number = 1
	mx.position = XItemScene.TREASURE_RECT.position + XItemScene.TREASURE_MAX_RECT.get_center()
	page._treasure_click(mx)
	check("max_button", int(page._treasure.number) == 5)
	page._treasure.number = 3
	page._unhandled_input(_key(KEY_ENTER))
	for i in 600:
		await get_tree().process_frame
		if page._treasure.is_empty():
			break
	var done: Dictionary = _ref("treasure_3_done").extra.lastResult
	check("batch_result", page._treasure.is_empty() and int(page.last_treasure.used) == int(done.used) and int(page.last_treasure.requested) == int(done.requested)
		and int(page.last_treasure.remaining) == int(done.remaining) and str(page.last_treasure.reason) == str(done.reason), [page.last_treasure, done])
	check("stock_after", s.item_count(212) == 2)
	check("back_to_list", page._mode == "list" and not page.treasure_win.visible)
	check("notice_text", str(page._notice.get("text", "")) == XTreasureBatch.notice(map212, page.last_treasure)
		and str(page._notice.text).begins_with(str(_ref("treasure_3_done").extra.help.rows[0])), page._notice)
	check("no_event_left", s.peek_common_event() == 0)
	await shot("treasure_02_done")
	# 取消
	page._item = map212
	page._mode = "action"
	page._use_direct()
	await frames()
	page._unhandled_input(_key(KEY_ESCAPE))
	await frames()
	var cancel: Dictionary = _ref("treasure_4_cancel").extra.lastResult
	check("cancel_result", page._treasure.is_empty() and str(page.last_treasure.reason) == str(cancel.reason) and int(page.last_treasure.used) == 0
		and str(page._notice.get("text", "")) == str(_ref("treasure_4_cancel").extra.help.rows[0]), [page.last_treasure, page._notice])
	check("cancel_keeps_stock", s.item_count(212) == 2)
	page.queue_free()
	await frames()

	# ---- 至臻通知 ----
	XTreasureBatch.queue = {}
	s.gain_gear("weapon", 1885, 1)
	s.gain_gear("weapon", 1886, 1)
	s.gain_gear("armor", 3623, 1)
	check("prestige_queued", XTreasureBatch.queue.size() == 3 and XTreasureBatch.is_prestige(s.gear.back()))
	var node := get_tree().current_scene.get_node_or_null("XPrestigeNotice") as XPrestigeNotice
	check("prestige_node", node != null)
	if node != null:
		node.set_physics_process(false)
		node.step()
		var wantp: Dictionary = _ref("prestige_0_gain").extra
		check("prestige_rect", Rect2(node.win.position, node.win.size) == Rect2(wantp.rect[0], wantp.rect[1], wantp.rect[2], wantp.rect[3]), [node.win.position, node.win.size])
		check("prestige_count_items", node.count == 3 and node.items.size() == 3 and str(node.items[0].name) == str(wantp.texts[1][0]) and str(node.items[1].name) == str(wantp.texts[2][0]),
			[node.count, node.items])
		check("prestige_flash_first", is_equal_approx(node.flash.color.a, 128.0 / 255.0) and node.flash_frames == 44 and node.frames == 149 and node.win.visible)
		await shot("treasure_03_prestige")
		for i in 44:
			node.step()
		check("prestige_flash_end", node.flash.color.a == 0.0 or node.flash_frames == 0)
		for i in 105:
			node.step()
		check("prestige_hidden_after_150", node.frames == 0 and not node.win.visible)
		node.queue_free()
	var n_before := XTreasureBatch.queue.size()
	s.gain_gear("weapon", 2, 1)
	check("plain_not_prestige", XTreasureBatch.queue.size() == n_before)

	# ---- 回退：ENABLED = false ----
	XTreasureBatch.ENABLED = false
	check("rollback_not_supported", not XTreasureBatch.supports(map212))
	s.gain_gear("weapon", 1885, 1)
	check("rollback_no_prestige", XTreasureBatch.queue.is_empty())
	XTreasureBatch.ENABLED = true

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
