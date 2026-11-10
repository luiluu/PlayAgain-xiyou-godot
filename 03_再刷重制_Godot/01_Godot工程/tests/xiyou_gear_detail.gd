extends Node
## 装备页／物品页右侧装备详情（XGearDetail；v0.62.12 installEquipmentDetailV041＋installPanelLayoutV043）。
## 参照：tests/fixtures/gear_detail_oracle.json（ui_reference/review_system_pages.js 的 equip_detail／item_detail，新源实跑读数）。
## 全部用内存新局，不读写存档（XSave.dir_override／XConfig.path_override 指到本测试自己的目录）。
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
	preload("res://tests/ui_pixel_dump.gd").dump(get_tree().root, out_dir.path_join(name + ".win.json"), name)


func _shot_ref(name: String) -> Dictionary:
	return ref.shots.get(name, {})


func _win(name: String, type: String, index := 0) -> Dictionary:
	var hits: Array = _shot_ref(name).windows.filter(func(w): return w.type == type)
	return hits[index] if index < hits.size() else {}


func _rect(r: Array) -> Rect2:
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func _wrect(w: XMVWindow) -> Rect2:
	return Rect2(w.position, w.size)


## [文字, 字号, 颜色, 对齐] 逐行比；颜色按 Color 比（rgba() 与 # 写法都认）
func _rows_match(got: Array, want: Array) -> Array:
	var bad := []
	if got.size() != want.size():
		bad.append(["count", got.size(), want.size()])
	for i in mini(got.size(), want.size()):
		var g: Array = got[i]
		var w: Array = want[i]
		var gc := XHelpCard._css(str(g[2]))
		var wc := XHelpCard._css(str(w[2]))
		var galign := int(g[4]) if g.size() > 4 and g[4] != null else 0
		if str(g[0]) != str(w[0]) or int(g[1]) != int(w[1]) or not gc.is_equal_approx(wc) or galign != int(w[3]):
			bad.append([i, g, w])
	return bad


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_gear_detail"
	XConfig.path_override = XSave.dir().path_join("options.json")
	ref = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/gear_detail_oracle.json"))
	check("oracle_present", ref is Dictionary and ref.shots.size() == 12)
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var a := s.actor(1)

	# ---- 内容（rows41）：原版读数的三件（练习剑＝新局角色 1 的武器，1706 无极西瓜刀，67 卍解-斩月）----
	for pair in [["equip_detail_1_slot", 2], ["equip_detail_4_item", 1706], ["item_detail_0_weapon", 67]]:
		var want: Array = _shot_ref(pair[0]).detail.rows
		var got := XHelpCard.detail_rows(XGear.template("weapon", int(pair[1])), 612.0)
		var bad := _rows_match(got, want)
		check("rows_" + str(pair[1]), bad.is_empty(), bad.slice(0, 4))
	# 详情不带说明卡那层的「装备战力：」行
	var plain := XHelpCard.detail_rows(XGear.template("weapon", 2), 612.0)
	check("no_power_row", not plain.any(func(r): return str(r[0]).contains(XHelpCard.POWER_PREFIX)))

	# ---- 装备页 ----
	var equip := XEquipScene.new()
	add_child(equip)
	await frames()
	var gd := equip.gear_detail
	check("equip_has_detail", gd != null)
	check("equip_rects", _wrect(gd.tabs) == _rect(_win("equip_detail_0_command", "Window_Help").rect)
		and _wrect(gd.detail) == _rect(_shot_ref("equip_detail_0_command").detail.rect)
		and _wrect(gd.nav) == _rect(_win("equip_detail_0_command", "Window_Help", 1).rect)
		and _wrect(equip.lower_win) == _rect(_win("equip_detail_2_compare", "Window_StatCompare").rect),
		[_wrect(gd.tabs), _wrect(gd.detail), _wrect(gd.nav), _wrect(equip.lower_win)])
	check("equip_canvas_612x403", gd.detail.canvas.size == Vector2(612, 403), gd.detail.canvas.size)
	check("equip_tabs_text", gd.tab_text() == _win("equip_detail_0_command", "Window_Help").text, gd.tab_text())
	check("equip_command_hint", gd.rows.size() == 1 and str(gd.rows[0][0]) == str(_shot_ref("equip_detail_0_command").detail.rows[0][0]))
	check("equip_detail_default", gd.mode == 0 and gd.detail.visible and gd.nav.visible and not equip.lower_win.visible and not equip.help_card.visible)
	await shot("gear_detail_01_command")
	equip._ok()
	await frames()
	check("slot_detail_follows", equip._mode == "slot" and gd.item == equip._slot_item() and str(gd.rows[0][0]).contains(str(equip._slot_item().name)))
	check("slot_no_help_card", not equip.help_card.visible)
	check("one_page_nav_empty", gd.pages == 1 and gd.tops == [0.0])
	await shot("gear_detail_02_slot")
	# → 换属性对比、再 → 插槽、再 → 回详情（首尾相接）；← 反向
	equip._unhandled_input(_key(KEY_RIGHT))
	await frames()
	check("right_to_compare", gd.mode == 1 and equip.lower_win.visible and not gd.detail.visible and not gd.nav.visible and gd.tabs.visible
		and gd.tab_text() == _win("equip_detail_2_compare", "Window_Help").text, gd.tab_text())
	await shot("gear_detail_03_compare")
	equip._unhandled_input(_key(KEY_TAB))
	await frames()
	check("tab_to_sockets", gd.mode == 2 and gd.detail.visible and not equip.lower_win.visible and gd.tab_text() == _win("equip_detail_3_sockets", "Window_Help").text)
	var want_sock: Array = _shot_ref("equip_detail_3_sockets").detail.rows
	# 孔数是每件实例按存档种子掷的（原版那件 1 孔），只比行的结构：标题、孔数、每孔一行、符文、记录、提示
	var holes: Array = equip._slot_item().get("augmentSlots", [])
	check("socket_rows_shape", gd.rows.size() == 5 + holes.size() and str(gd.rows[1][0]) == "宝珠插槽：%d个" % holes.size()
		and (holes.is_empty() or str(gd.rows[2][0]) == str(want_sock[2][0])) and str(gd.rows[0][2]) == "#ffe499" and str(gd.rows[1][0]).begins_with("宝珠插槽：")
		and str(gd.rows[gd.rows.size() - 3][0]).begins_with("符文镶嵌：剩余 ") and str(gd.rows.back()[0]) == str(want_sock.back()[0])
		and str(gd.rows[gd.rows.size() - 2][0]) == "尚无符文镶嵌记录。", [gd.rows, want_sock])
	await shot("gear_detail_04_sockets")
	equip._unhandled_input(_key(KEY_RIGHT))
	await frames()
	check("right_wraps_to_detail", gd.mode == 0)
	equip._unhandled_input(_key(KEY_LEFT))
	await frames()
	check("left_wraps_to_sockets", gd.mode == 2)
	equip._unhandled_input(_key(KEY_LEFT))
	equip._unhandled_input(_key(KEY_LEFT))
	await frames()
	check("left_back_to_detail", gd.mode == 0)
	# 点页签条：按三等分
	var tr := _wrect(gd.tabs)
	equip._gui_input(_click(Vector2(tr.position.x + tr.size.x * 0.5, tr.position.y + 20)))
	check("click_tab_compare", gd.mode == 1 and equip.lower_win.visible)
	equip._gui_input(_click(Vector2(tr.end.x - 5, tr.position.y + 20)))
	check("click_tab_sockets", gd.mode == 2)
	equip._gui_input(_click(Vector2(tr.position.x + 5, tr.position.y + 20)))
	check("click_tab_detail", gd.mode == 0)
	# 点详情区不再轮换窗口
	equip._gui_input(_click(Vector2(900, 400)))
	equip._gui_input(_release(Vector2(900, 400)))
	check("click_detail_keeps_mode", gd.mode == 0)
	# PageUp／PageDown 在详情页翻详情，不换角色（指令阶段也一样）
	equip._cancel()
	await frames()
	var who := equip.actor().actor_id
	equip._unhandled_input(_key(KEY_PAGEDOWN))
	check("pagedown_not_actor_switch", equip.actor().actor_id == who and equip._mode == "command")
	equip._unhandled_input(_key(KEY_RIGHT))
	equip._unhandled_input(_key(KEY_PAGEDOWN))
	check("pagedown_in_compare_switches_actor", equip.actor().actor_id != who, equip.actor().actor_id)
	equip.queue_free()
	await frames()

	# ---- 分页（render43）与翻页／滚动（turn41／scroll41／syncPage43）：用一份长内容 ----
	var ui_host := Control.new()
	add_child(ui_host)
	var probe := XGearDetail.new(ui_host, Rect2(640, 173, 640, 547), 255)
	await frames()
	var long_rows := []
	for i in range(40):
		long_rows.append(["第%d行说明文字" % i, 18, "#ffffff", false, 0])
		if i % 7 == 6:
			long_rows.append([" ", 4, "#000000", false, 0])
	var view_h := probe.detail.canvas.size.y
	_render_rows(probe, long_rows)
	var expect := _expected_tops(long_rows, view_h)
	check("paging_tops", probe.tops == expect.tops and probe.pages == expect.tops.size(), [probe.tops, expect.tops])
	check("paging_full_h", is_equal_approx(probe.full_h, view_h * probe.pages))
	var spacer_tops := probe._placed.filter(func(p): return p.glyphs.is_empty() and float(p.top) in probe.tops and float(p.top) > 0.0)
	check("paging_no_spacer_at_top", spacer_tops.is_empty(), spacer_tops.size())
	probe.turn(1)
	check("turn_next", probe.page == 1 and is_equal_approx(probe.origin_y, minf(probe.max_scroll(), probe.tops[1])))
	probe.turn(99)
	check("turn_clamp_last", probe.page == probe.pages - 1 and is_equal_approx(probe.origin_y, probe.max_scroll()))
	probe.turn(-99)
	probe.scroll(view_h * 0.5)
	check("scroll_keeps_page", probe.page == 0 and is_equal_approx(probe.origin_y, view_h * 0.5))
	probe.scroll(view_h * 0.5 - 1.0)
	check("scroll_sync_plus2", probe.page == 1, [probe.origin_y, probe.page])
	probe.scroll(1.0e6)
	check("scroll_bottom_last_page", probe.page == probe.pages - 1 and is_equal_approx(probe.origin_y, probe.max_scroll()))
	# 翻页条：左半上一页、右半下一页；滚轮滚 100；拖动反向滚
	var nr := _wrect(probe.nav)
	probe.mouse(_click(Vector2(nr.position.x + 10, nr.position.y + 20)))
	check("nav_left_prev", probe.page == probe.pages - 2)
	probe.mouse(_click(Vector2(nr.end.x - 10, nr.position.y + 20)))
	check("nav_right_next", probe.page == probe.pages - 1)
	probe.turn(-99)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = Vector2(900, 400)
	probe.mouse(wheel)
	check("wheel_scrolls_100", is_equal_approx(probe.origin_y, 100.0), probe.origin_y)
	probe.mouse(_click(Vector2(900, 400)))
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(900, 397)
	probe.mouse(mv)
	check("drag_under_6_ignored", is_equal_approx(probe.origin_y, 100.0))
	mv.position = Vector2(900, 360)
	probe.mouse(mv)
	check("drag_scrolls", is_equal_approx(probe.origin_y, 140.0), probe.origin_y)
	probe.mouse(_release(Vector2(900, 360)))
	# 换装备回第一页
	probe.set_item(XGear.template("weapon", 2))
	check("new_item_first_page", probe.page == 0 and probe.origin_y == 0.0)
	for w in [probe.tabs, probe.detail, probe.nav]:
		w.queue_free()
	# 原版 fullHeight（MIN_FONT 0＝原版字号）：练习剑 259、无极西瓜刀 389、卍解-斩月 404
	var keep_min := XHelpCard.MIN_FONT
	XHelpCard.MIN_FONT = 0
	var probe2 := XGearDetail.new(ui_host, Rect2(640, 173, 640, 547), 255)
	await frames()
	# 卍解-斩月的读数在物品页（内容高 404）：总高正好 404，装备页（403）会多出一页
	var probe3 := XGearDetail.new(ui_host, XItemScene.INFO_RECT, 255, ["装备详情", "插槽与镶嵌"], [0, 2])
	await frames()
	for pair in [["equip_detail_1_slot", 2], ["equip_detail_4_item", 1706], ["item_detail_0_weapon", 67]]:
		if int(pair[1]) == 67:
			probe2 = probe3
		probe2.key = ""
		probe2.set_item(XGear.template("weapon", int(pair[1])))
		var want_h: float = _shot_ref(pair[0]).detail.fullHeight
		check("full_height_" + str(pair[1]), absf(probe2.full_h - want_h) <= 2.0 and probe2.pages == 1, [probe2.full_h, want_h])
	XHelpCard.MIN_FONT = keep_min
	for w in [probe2.tabs, probe2.detail, probe2.nav]:
		w.queue_free()
	# 探针的详情窗（probe、probe3）一并拆掉，免得叠在物品页截图下面、混进窗口矩形读数（白龙 ui-pixel2）
	ui_host.queue_free()
	await frames()

	# ---- 物品页 ----
	s.gain_gear("weapon", 67, 1)
	var page := XItemScene.new()
	add_child(page)
	await frames()
	var ig := page.gear_detail
	check("item_detail_hidden_in_category", ig != null and not ig.is_shown() and page.info_win.visible)
	page._cat = XShop.CATEGORIES.map(func(c): return c[1]).find("weapon")
	page._ok()
	await frames()
	var idx := page.entries().map(func(e): return int(e.rec.get("base", e.rec.get("id", 0)))).find(67)
	page._index = maxi(0, idx)
	page._refresh()
	await frames()
	check("item_gear_shows_detail", page.gear_shown() and ig.is_shown() and not page.info_win.visible and not page.help_card.visible)
	check("item_rects", _wrect(ig.tabs) == _rect(_win("item_detail_0_weapon", "Window_Help").rect)
		and _wrect(ig.detail) == _rect(_shot_ref("item_detail_0_weapon").detail.rect)
		and _wrect(ig.nav) == _rect(_win("item_detail_0_weapon", "Window_Help", 1).rect),
		[_wrect(ig.tabs), _wrect(ig.detail), _wrect(ig.nav)])
	check("item_tabs_text", ig.tab_text() == _win("item_detail_0_weapon", "Window_Help").text, ig.tab_text())
	await shot("gear_detail_05_item")
	page._unhandled_input(_key(KEY_TAB))
	await frames()
	check("item_tab_sockets", ig.mode == 2 and ig.tab_text() == _win("item_detail_1_sockets", "Window_Help").text, ig.tab_text())
	page._unhandled_input(_key(KEY_TAB))
	check("item_tab_back", ig.mode == 0)
	var itr := _wrect(ig.tabs)
	page._gui_input(_click(Vector2(itr.end.x - 5, itr.position.y + 20)))
	check("item_click_right_half", ig.mode == 2)
	page._gui_input(_click(Vector2(itr.position.x + 5, itr.position.y + 20)))
	check("item_click_left_half", ig.mode == 0)
	# 操作菜单：详情收起、信息窗回来
	page._ok()
	await frames()
	check("item_action_info_back", page._mode == "action" and not ig.is_shown() and page.info_win.visible)
	page._cancel()
	page._cancel()
	await frames()
	page._cat = XShop.CATEGORIES.map(func(c): return c[1]).find("item")
	page._ok()
	await frames()
	check("item_plain_item_no_detail", not page.gear_shown() and page.info_win.visible)
	page.queue_free()
	await frames()

	# ---- 回退：DETAIL_V041／DETAIL_V043 = false 回到 v0.28 ----
	XEquipScene.DETAIL_V041 = false
	XItemScene.DETAIL_V043 = false
	var old_equip := XEquipScene.new()
	add_child(old_equip)
	await frames()
	check("rollback_equip", old_equip.gear_detail == null and _wrect(old_equip.lower_win) == XEquipScene.LOWER_RECT)
	old_equip.queue_free()
	var old_page := XItemScene.new()
	add_child(old_page)
	await frames()
	check("rollback_item", old_page.gear_detail == null and not old_page.gear_shown())
	old_page.queue_free()
	XEquipScene.DETAIL_V041 = true
	XItemScene.DETAIL_V043 = true
	await frames()

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 直接给 rows 排一次（render 的内容换成给定行）
func _render_rows(d: XGearDetail, rows: Array) -> void:
	d.rows_override = rows
	d.render()
	d.rows_override = []


## 照 render43 的分页规则独立算一遍页顶
func _expected_tops(rows: Array, view_h: float) -> Dictionary:
	var sized := []
	for r in rows:
		var rr: Array = (r as Array).duplicate()
		if str(rr[0]) != " ":
			rr[1] = maxi(int(rr[1]), XHelpCard.MIN_FONT)
		sized.append(rr)
	var lay := XHelpCard.layout(sized, 0, 612.0 + XHelpCard.PAD * 2)
	var tops := [0.0]
	var y := 0.0
	var pg := 0.0
	for line in lay.lines:
		var h: float = line.h
		if y > pg and y + h > pg + view_h:
			pg += view_h
			y = pg
			tops.append(pg)
		y += h
	return {"tops": tops}


func _key(code: int) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = true
	return k


func _click(p: Vector2) -> InputEventMouseButton:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.position = p
	return b


func _release(p: Vector2) -> InputEventMouseButton:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = false
	b.position = p
	return b
