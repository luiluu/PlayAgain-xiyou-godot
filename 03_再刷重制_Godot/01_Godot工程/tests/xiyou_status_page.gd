extends Node
## 状态页逐像素复现（XStatusPage，JAH_StatusMenuCore）：对照 tests/fixtures/status_page_oracle.json（正式 v0.62.12 无头浏览器读数，ui_reference/dom_ref.cjs＋status_page_ref.js）。
## - 窗口矩形：选页窗 (0,0,1280,64)、页窗 (0,108,1280,612)（开着战力）／(0,72,1280,648)（关掉战力）。
## - 每个角色 × 前三页：contents 上的每个绘制调用（文字、位置、宽、对齐、字号、颜色；脸图、图标、量条、分隔线）逐项比对；
##   x 与宽差 1.5 以内（两边字体量宽的小数差），y 与对齐、字号、颜色一致。
## - 滚动：最大滚动行、滚到底后的调用；左右换页（循环）、上下滚动、Q/W 换角色重置滚动；「战力 N」按钮打开战力面板。
## 加 -- --out=<目录> 时保存截图。

const ORACLE := "res://tests/fixtures/status_page_oracle.json"
## 浏览器开着五乘区成长修正、数字不同的项（只比位置与格式，不比数值）：无（初始 1 级与重制版一致；有差异时在这里登记）
const VALUE_FREE := []
var results := []
var out_dir := ""


func _ready() -> void:
	XPower.SHOW_POWER_UI = true  # 战力先藏（默认关）：本专项测战力显示，开着才与藏之前逐字一致
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 4) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_status_page"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.set_flag("codexPowerEnabled", true)
	var o: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	var ids: Array = o.actors.map(func(x): return int(x.actorId))
	var s := XState.new_game(3, ids[0], ids.slice(1))
	for want in o.actors:
		var a := s.actor(int(want.actorId))
		for p in range(3):
			var w: Dictionary = want.pages[p]
			compare("a%d_p%d" % [a.actor_id, p], XStatusPage.page_ops(a, p, 612.0), w.ops)
			check("a%d_p%d_lines" % [a.actor_id, p], XStatusPage.line_count(a, p) == int(w.maxItems), [XStatusPage.line_count(a, p), w.maxItems])
	# O-295：关掉开关回到 v0.28（武器类型加成只写百分比，不带「 生效／ 未持有」）
	XStatusPage.WTYPE_HOLD_V041 = false
	var off_ops := XStatusPage.page_ops(s.actor(1), 1, 612.0).filter(func(op): return op[0] == "text" and float(op[2]) > 700 and float(op[2]) < 720 and float(op[3]) >= 252)
	XStatusPage.WTYPE_HOLD_V041 = true
	var on_ops := XStatusPage.page_ops(s.actor(1), 1, 612.0).filter(func(op): return op[0] == "text" and float(op[2]) > 700 and float(op[2]) < 720 and float(op[3]) >= 252)
	check("wtype_hold_switch", off_ops.size() == 12 and off_ops.all(func(op): return str(op[1]).ends_with("%"))
		and on_ops.size() == 12 and on_ops.all(func(op): return str(op[1]).ends_with(" 生效") or str(op[1]).ends_with(" 未持有")), [off_ops.slice(0, 2), on_ops.slice(0, 2)])
	await _scene(o, s)
	XConfig.set_flag("codexPowerEnabled", true)
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	# 换页与返回播过音效：停掉播放器后按真实时间等 0.5 秒再退出（AGENTS.md 测试规则）
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


## 逐项比对：每个参照调用找同类同文字、位置最近的一项
func compare(name: String, got: Array, want: Array) -> void:
	var used := {}
	var bad := []
	for wop in want:
		var best := -1
		var best_d := INF
		for i in range(got.size()):
			if used.has(i) or got[i][0] != wop[0]:
				continue
			if wop[0] == "text" and got[i][1] != wop[1] and not VALUE_FREE.has(wop[1]):
				continue
			if wop[0] == "face" and str(got[i][1]) != str(wop[1]) or wop[0] == "icon" and int(got[i][1]) != int(wop[1]):
				continue
			var gp := _pos(got[i])
			var d := gp.distance_to(_pos(wop))
			if d < best_d:
				best_d = d
				best = i
		if best < 0:
			bad.append(["missing", wop])
			continue
		used[best] = true
		var g: Array = got[best]
		var ok := _pos(g).distance_to(_pos(wop)) <= 1.6 and absf(_pos(g).y - _pos(wop).y) < 0.5
		match str(wop[0]):
			"text":
				ok = ok and absf(float(g[4]) - float(wop[4])) <= 1.5 and int(g[5]) == int(wop[5]) and g[6] == wop[6] and int(g[7]) == int(wop[7]) \
					and Color(g[8]).is_equal_approx(Color(wop[8]))
			"face":
				ok = ok and int(g[2]) == int(wop[2])
			"gauge":
				ok = ok and absf(float(g[3]) - float(wop[3])) < 0.5 and absf(float(g[4]) - float(wop[4])) < 0.5 and g[5] == wop[5] and g[6] == wop[6]
			"line":
				ok = ok and absf(float(g[3]) - float(wop[3])) < 0.5
		if not ok:
			bad.append(["diff", wop, g])
	for i in range(got.size()):
		if not used.has(i):
			bad.append(["extra", got[i]])
	check(name, bad.is_empty(), bad)


static func _pos(op: Array) -> Vector2:
	match str(op[0]):
		"text":
			return Vector2(op[2], op[3])
		"face":
			return Vector2(op[3], op[4])
		"icon":
			return Vector2(op[2], op[3])
	return Vector2(op[1], op[2])


func _scene(o: Dictionary, s: XState) -> void:
	var page := XStatusPage.new()
	add_child(page)
	await frames()
	# 窗口矩形
	check("select_rect", Rect2(page.select_win.position, page.select_win.size) == Rect2(0, 0, 1280, 64))
	check("page_rect", Rect2(page.page_win.position, page.page_win.size) == Rect2(o.page.rect[0], o.page.rect[1], o.page.rect[2], o.page.rect[3]),
		[page.page_win.position, page.page_win.size])
	check("page_rows", page.page_rows() == int(o.page.maxPageRows), page.page_rows())
	check("window_opacity", page.page_win.opacity == int(o.page.opacity) and page.select_win.opacity == int(o.page.opacity))
	check("arrows_top", page.page_win.down_arrow == bool(o.page.downArrow) and page.page_win.up_arrow == bool(o.page.upArrow))
	# 选页窗：v0.62.12 夹具 5 项（O-292），各项居中，光标在第一项；XGuide.PANEL_V062 关时回到 v0.28 的 4 项（304／316，Window_HorzCommand 公式）
	var names := XStatusPage.page_names()
	var texts := []
	for i in range(names.size()):
		texts.append(["text", names[i], i * XStatusPage.item_step() + 6, 0.0, XStatusPage.item_w() - 12, 36, "center", 26, "#ffffff"])
	compare("select_items", texts, o.select.texts.duplicate(true))
	var items := range(names.size()).map(func(i): return [i * XStatusPage.item_step(), 0.0, XStatusPage.item_w(), 36.0])
	check("select_item_rects", items == (o.select.items as Array).map(func(r): return (r as Array).map(func(v): return float(v))), [items, o.select.items])
	check("select_cursor", Rect2(o.select.cursor[0], o.select.cursor[1], o.select.cursor[2], o.select.cursor[3]) == Rect2(0, 0, XStatusPage.item_w(), 36), o.select.cursor)
	check("select_v028_four", floorf((1280.0 - 28 + 12) / 4 - 12) == XStatusPage.ITEM_W and XStatusPage.ITEM_STEP == XStatusPage.ITEM_W + 12 and XStatusPage.PAGE_NAMES.size() == 4)
	await shot("status_1_p0")
	# 滚动到底：最大滚动行与滚动后的调用（整体上移 top×36）
	var a := s.actor(1)
	for i in range(6):
		_key(page, "ui_down")
	await frames()
	check("scroll_max", page.tops[0] == int(o.scrolled.topRow) and page.page_win.up_arrow and not page.page_win.down_arrow, page.tops)
	var shifted := XStatusPage.page_ops(a, 0, 612.0).map(func(op): return _shift(op, -page.tops[0] * 36.0))
	compare("scrolled_ops", shifted, o.scrolled.ops)
	_key(page, "ui_up")
	check("scroll_up", page.tops[0] == int(o.scrolled.topRow) - 1)
	# 左右换页（按下循环）
	_key(page, "ui_left")
	check("page_wrap_left", page.page == XStatusPage.page_names().size() - 1)
	_key(page, "ui_right")
	check("page_wrap_right", page.page == 0 and page.tops[0] == int(o.scrolled.topRow) - 1)
	_key(page, "ui_right")
	await frames()
	await shot("status_1_p1")
	_key(page, "ui_right")
	await frames()
	await shot("status_1_p2")
	_key(page, "ui_right")
	await frames()
	await shot("status_1_p3")
	if XGuide.PANEL_V062:
		_key(page, "ui_right")
		await frames()
		check("detail_page", page.page == 4 and page.all_text().contains("【难度对照") and page.all_text().contains("结算伤害·合计"), page.page)
		await shot("status_1_p4")
	# 换角色：滚动复位，战力条与按钮跟着换
	page.page = 0
	page.switch_actor(2)
	await frames()
	check("switch_actor_resets_scroll", page.actor().actor_id == 23 and page.tops == [0, 0, 0, 0, 0] and page.power_strip.actor == page.actor())
	await shot("status_23_p0")
	page.page = 1
	page._scroll(0)
	await frames()
	await shot("status_23_p1")
	page.page = 0
	page._scroll(0)
	# 「战力 N」按钮：右上 (−8, 8)、高 39.2，点开角色战力面板（当前角色），Esc 关掉
	var b := page.power_button
	check("power_button", b != null and b.text == XPowerPanel.button_text(page.actor()) and absf(b.position.x + b.size.x - 1272) < 0.5
		and b.position.y == 8 and absf(b.size.y - 39.2) < 0.01, [b.position, b.size] if b else null)
	b.pressed.emit()
	await frames()
	check("power_panel_open", page.power_panel != null and page.power_panel.actor().actor_id == 23)
	var before := page.page
	_key(page, "ui_right")
	check("panel_blocks_page_input", page.page == before)
	page.power_panel.close()
	await frames()
	check("power_panel_closed", page.power_panel == null)
	# 右键与取消键都返回（Window_Selectable.processTouch 的 isCancelled → processCancel）
	var closes := [0]
	page.closed.connect(func(): closes[0] += 1)
	var rc := InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	page._gui_input(rc)
	XSound.system_log.clear()
	_key(page, "ui_cancel")
	check("right_click_and_cancel_close", closes[0] == 2 and XSound.system_log == [2], [closes, XSound.system_log])
	page.queue_free()
	await frames()
	# 关掉战力：没有战力条与按钮，页窗回到 (0,72,1280,648)
	XConfig.set_flag("codexPowerEnabled", false)
	var off := XStatusPage.new()
	add_child(off)
	await frames()
	check("power_off_layout", off.power_strip == null and off.power_button == null
		and Rect2(off.page_win.position, off.page_win.size) == Rect2(0, 72, 1280, 648) and off.page_rows() == 17)
	off.queue_free()
	await frames()


func _key(page: XStatusPage, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	page._unhandled_input(ev)


static func _shift(op: Array, dy: float) -> Array:
	var o := op.duplicate()
	match str(o[0]):
		"text":
			o[3] += dy
		"face":
			o[4] += dy
		"icon":
			o[3] += dy
		_:
			o[2] += dy
	return o
