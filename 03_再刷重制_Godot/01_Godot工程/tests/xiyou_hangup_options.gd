extends Node
## 主菜单「设置」与挂机设置页（XOptionsScene / XHangUpOptionsScene）：正式 v0.16 运行时读数的窗口位置、
## 选项顺序与状态文字、范围/开关的改值与循环、选择移动、点击、子页未做时不改值、范围格、自动储存（O-017）。
## 从真实地图打开菜单→设置→挂机设置。窗口模式加 -- --out=<目录> 保存实际绘制截图。

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


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))


func press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await frames(1)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await frames(1)


func click(p: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = p
		e.global_position = p
		e.pressed = down
		Input.parse_input_event(e)
		await frames(1)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_hangup_options"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 5
	s.x = 11
	s.y = 13
	s.set_self_switch(4, 20, "A", true)
	s.flags.SaveGameId = 4
	XConfig.set_map_xy(true)
	var map := XMapScene.new()
	add_child(map)
	await frames(4)
	map.open_menu()
	await frames(3)
	var menu: XMenu = map.ui.get_children().filter(func(n): return n is XMenu).front()
	check("menu_options_enabled", menu.COMMANDS.any(func(c): return c[1] == "options" and c[2]))
	menu._cmd_index = menu.COMMANDS.map(func(c): return c[1]).find("options")
	menu._ok()
	await frames(2)
	var opt: XOptionsScene = menu.get_children().filter(func(n): return n is XOptionsScene).front()
	check("options_open", opt != null and not menu.cmd_win.visible)
	check("options_rect", opt.win.position == Vector2(440, 130) and opt.win.size == Vector2(400, 460))
	check("options_list", opt.symbols().size() == 33 and opt.symbols()[0] == "MapXy" and opt.symbols()[1] == "HangUp"
		and opt.symbols()[32] == "codexFeedbackPending")
	check("options_status", opt.status_text(0) == "ON" and opt.status_text(1) == "" and opt.status_text(11) == "")
	await shot("00_设置.png")
	# 坐标显示：确定切换，右开左关
	opt.ok()
	check("mapxy_toggle", not XConfig.map_xy())
	opt._side(true)
	check("mapxy_right", XConfig.map_xy())
	# 未重制的选项：确定不打开任何页
	opt.index = 2
	opt.ok()
	check("unimplemented_noop", opt._page == null)
	# 下键循环与滚动
	opt.index = 0
	for i in 12:
		opt._select(XMenu._move(opt.index, 1, 33, true))
	check("options_scroll", opt.index == 12 and opt.top == 1 and opt.win.up_arrow and opt.win.down_arrow, [opt.index, opt.top])
	opt._select(XMenu._move(32, 1, 33, true))
	check("options_wrap", opt.index == 0 and opt.top == 0)
	# 挂机设置
	opt._select(1)
	await press("ui_accept")
	var page: XHangUpOptionsScene = opt._page
	check("hangup_open", page != null and not opt.win.visible)
	check("title_rect", page.title_win.position == Vector2.ZERO and page.title_win.size == Vector2(1280, 64) and page.title_win.padding == 10.0)
	var expect := [Vector2(0, 64), Vector2(0, 132), Vector2(0, 200), Vector2(0, 268), Vector2(0, 336), Vector2(0, 404), Vector2(0, 472),
		Vector2(0, 540), Vector2(1280.0 / 3, 540), Vector2(2560.0 / 3, 540), Vector2(0, 608), Vector2(1280.0 / 3, 608), Vector2(2560.0 / 3, 608)]
	var rects_ok := true
	for i in 13:
		var w: XMVWindow = page.item_wins[i]
		rects_ok = rects_ok and w.position.is_equal_approx(expect[i]) and w.size.is_equal_approx(Vector2(427, 68)) and w.canvas.size.is_equal_approx(Vector2(407, 48))
	check("item_rects", rects_ok, page.item_wins.map(func(w): return [w.position, w.size, w.canvas.size]))
	check("range_rect", page.range_win.position.is_equal_approx(Vector2(1280.0 / 3, 64)) and page.range_win.size == Vector2(854, 480)
		and page.range_win.canvas.size == Vector2(834, 460))
	var names := []
	var status := []
	for i in 13:
		names.append(page.words(page.SYMS[i])[0])
		status.append(page.status_text(i))
	check("item_names", names == ["挂机范围", "快捷界面", "快速战斗", "死亡停止", "自动储存", "稀有逃跑", "前所未见逃跑", "小怪逃跑",
		"技能次数", "技能顺序", "自动吃药", "自动卖出", "屏蔽掉落"], names)
	check("item_status", status == ["10", "YES", "NO", "YES", "YES", "NO", "NO", "NO", "open", "open", "open", "open", "NO"], status)
	check("title_text", page.words("range")[1] == "挂机时角色随机移动/侦测范围半径。")
	check("auto_save_text_slot", page.words("autoSave")[1] == "挂机时，是否自动储存游戏到 4 号档位。", page.words("autoSave")[1])
	check("player_tile", page.player_tile == map.player_screen_tile())
	await shot("01_挂机设置.png")
	# 选择：上键从第一项循环到最后一项
	await press("ui_up")
	check("up_wraps", page.index == 12)
	await press("ui_down")
	check("down_wraps", page.index == 0)
	# 范围：确定/右 +1，左 −1，1～20 循环
	page.ok()
	check("range_inc", int(XHangUp.settings(s).range) == 11)
	page.left()
	page.left()
	check("range_dec", int(XHangUp.settings(s).range) == 9)
	XHangUp.settings(s).range = 20
	page.ok()
	check("range_wrap_up", int(XHangUp.settings(s).range) == 1)
	page.left()
	check("range_wrap_down", int(XHangUp.settings(s).range) == 20)
	XHangUp.settings(s).range = 1
	page._refresh()
	var cells := page.lattice()
	var t := Vector2i(page.player_tile)
	check("lattice_r1", cells.size() == 4 and not cells.has(t) and cells.has(t + Vector2i(1, 0)), cells)
	XHangUp.settings(s).range = 10
	# 开关：确定/左都取反
	page.select(1)
	page.ok()
	check("bool_ok", not XHangUp.settings(s).showInter)
	page.left()
	check("bool_left", XHangUp.settings(s).showInter)
	# 子页未做：不改设置
	page.select(10)
	var before := XHangUp.settings(s).duplicate()
	page.ok()
	check("subpage_noop", XHangUp.settings(s) == before)
	# 点击：点非活动窗口＝选中，再点活动窗口的项＝确定
	if DisplayServer.get_name() != "headless":
		await click(Vector2(100, 300))
		check("click_select", page.index == 3)
		await click(Vector2(100, 300))
		check("click_ok", not XHangUp.settings(s).deathStop)
		XHangUp.settings(s).deathStop = true
	# O-017：自动储存关掉时不记待存
	XHangUp.settings(s).autoSave = false
	s.hang_up_active = true
	s.hang_up_origin = Vector2i(11, 13)
	s.hang_up_count = XHangUp.save_frames() - 1
	XHangUp.tick(s)
	check("autosave_off", not s.hang_up_save_pending)
	XHangUp.settings(s).autoSave = true
	s.hang_up_count = XHangUp.save_frames() - 1
	XHangUp.tick(s)
	check("autosave_on", s.hang_up_save_pending)
	XHangUp.clear(s)
	# 取消：回到设置页，再取消回到主菜单
	await press("ui_cancel")
	await frames(1)
	check("hangup_close", opt._page == null and opt.win.visible)
	await press("ui_cancel")
	await frames(1)
	check("options_close", menu.cmd_win.visible and not is_instance_valid(opt) or opt.is_queued_for_deletion())
	# 挂机被禁用时设置里没有「挂机设置」
	s.flags.HangUpProhibited = true
	var opt2 := XOptionsScene.new()
	add_child(opt2)
	check("prohibited_no_hangup", opt2.symbols().size() == 32 and not opt2.symbols().has("HangUp"))
	opt2.queue_free()
	s.flags.HangUpProhibited = false
	map.queue_free()
	await frames(2)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
