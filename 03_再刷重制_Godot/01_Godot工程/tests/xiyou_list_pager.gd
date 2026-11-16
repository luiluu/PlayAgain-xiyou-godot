extends Node
## 【cc·天启篇·T049】通用翻页件 XListPager 专项：
## - 纯函数：页数、第几页（末页夹底）、第 p 页的 top、重新进页的 top_for_index；
## - 翻页件：超一页才显示；点左右钮发 page_step；到头的钮点了没反应；按下松开不在同一钮不算；
## - XSkinList.page：整页翻、选中项跟着挪一页、没焦点只翻不挪、键盘 PageUp／PageDown 认、ui_page_down 动作（Q／E／肩键）不认；
## - 模板页（物品、技能、装备候选都走它）：超一页出翻页件、点钮翻页、页码跟着变、换页签（换列表）回第 1 页、一页内不出；
## - 图鉴三页（角色图鉴、怪物图鉴、符文图鉴）：新界面开着时少放一行给翻页件、点钮翻页、翻页件不压行；新界面关着（西游档）
##   没有翻页件、行数不变、下箭头照旧；怪物图鉴重新进页翻到上次选中那只所在的页。
## 带 -- --out=<目录> 且有窗口时截图（--wide 1600×720 即 20:9，--touch 按触屏画；默认 16:9）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []
var out_dir := ""
var wide := false
var touch := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg == "--wide":
			wide = true
		elif arg == "--touch":
			touch = true
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 2) -> void:
	for _i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func shot(name: String) -> void:
	if not windowed():
		return
	await frames(10)
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	check("screenshot_" + name, img.save_png(out_dir.path_join("%s_%s%s.png" % [name, "20x9" if wide else "16x9", "_touch" if touch else ""])) == OK)


func _click(target: Control, p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = p
	e.pressed = true
	target._gui_input(e)
	var u := e.duplicate()
	u.pressed = false
	target._gui_input(u)


func _pager_click(pg: XListPager, side: int) -> void:
	_click(pg, pg.button_rect(side).get_center())


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e


func _action(name: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	await frames(2)


func _run() -> void:
	XConfig.path_override = "user://test_xiyou_list_pager_options.json"
	XConfig.ensure_loaded()
	XMessageBox.auto = true
	if windowed() and wide:
		get_window().size = Vector2i(1600, 720)
		await frames(5)
	if touch:
		XUiSkin.touch_override = 1
		XPlatform.force_mobile = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XState.new_game(3, 1, [8, 9, 10])
	_pure()
	await _widget()
	await _skin_list()
	await _template()
	await _item_page()
	await _books()
	print("TEST_RESULT=" + JSON.stringify({"passed": results.filter(func(x): return x.passed).size(), "total": results.size()}))
	get_tree().quit()


func _pure() -> void:
	check("pages_of", XListPager.pages_of(45, 10) == 5 and XListPager.pages_of(40, 10) == 4 and XListPager.pages_of(0, 10) == 1 and XListPager.pages_of(10, 10) == 1)
	check("page_of", XListPager.page_of(0, 10, 45) == 1 and XListPager.page_of(10, 10, 45) == 2 and XListPager.page_of(35, 10, 45) == 5 and XListPager.page_of(31, 10, 45) == 5 and XListPager.page_of(25, 10, 45) == 4)
	check("top_of", XListPager.top_of(1, 10, 45) == 0 and XListPager.top_of(2, 10, 45) == 10 and XListPager.top_of(5, 10, 45) == 35 and XListPager.top_of(9, 10, 45) == 35)
	check("top_for_index", XListPager.top_for_index(0, 10, 45) == 0 and XListPager.top_for_index(23, 10, 45) == 20 and XListPager.top_for_index(44, 10, 45) == 35 and XListPager.top_for_index(-3, 10, 45) == 0)
	XUiSkin.FORCE = false
	check("rows_for_skin_off_unchanged", XListPager.rows_for(19, 100) == 19 and XListPager.rows_for(19, 5) == 19)
	XUiSkin.FORCE = true
	check("rows_for_skin_on_minus_one_only_when_over", XListPager.rows_for(19, 100) == 18 and XListPager.rows_for(19, 19) == 19 and XListPager.rows_for(19, 20) == 18)


func _widget() -> void:
	var pg := XListPager.new()
	add_child(pg)
	var got := []
	pg.page_step.connect(func(d): got.append(d))
	pg.set_state(0, 10, 10)
	check("pager_hidden_when_one_page", not pg.visible)
	pg.set_state(0, 10, 45)
	check("pager_shown_over_one_page", pg.visible and pg.page == 1 and pg.pages == 5)
	_pager_click(pg, -1)
	check("pager_first_page_left_disabled", got.is_empty(), got)
	_pager_click(pg, 1)
	check("pager_right_steps_plus1", got == [1], got)
	pg.set_state(35, 10, 45)
	_pager_click(pg, 1)
	check("pager_last_page_right_disabled", got == [1] and pg.page == 5, got)
	_pager_click(pg, -1)
	check("pager_left_steps_minus1", got == [1, -1], got)
	# 按在右钮、松在左钮：不算
	pg.set_state(10, 10, 45)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pg.button_rect(1).get_center()
	pg._gui_input(e)
	var u := e.duplicate()
	u.pressed = false
	u.position = pg.button_rect(-1).get_center()
	pg._gui_input(u)
	check("pager_press_release_must_match", got == [1, -1], got)
	check("pager_button_touch_size", pg.button_rect(1).size.x >= 44 and pg.button_rect(-1).size.y >= 44, pg.button_rect(1))
	var mid := InputEventMouseButton.new()
	mid.button_index = MOUSE_BUTTON_LEFT
	mid.pressed = true
	mid.position = pg.size / 2.0
	pg._gui_input(mid)
	var mid_up := mid.duplicate()
	mid_up.pressed = false
	pg._gui_input(mid_up)
	check("pager_label_area_does_nothing", got == [1, -1], got)
	await _clear()


func _skin_list() -> void:
	var l := XSkinList.new()
	l.columns = 2
	l.row_height = 48
	l.size = Vector2(600, 480)
	add_child(l)
	var rows := []
	for k in 45:
		rows.append({"text": "项%d" % k})
	l.set_items(rows)
	check("list_ten_rows_23_total", l.visible_rows() == 10 and l.rows_total() == 23)
	check("list_page_down", l.page(1) and l.top_row == 10 and l.index == 20, [l.top_row, l.index])
	check("list_page_down_clamp_last", l.page(1) and l.top_row == 13 and l.index == 26, [l.top_row, l.index])
	check("list_page_down_at_end_false", not l.page(1) and l.top_row == 13)
	check("list_page_up", l.page(-1) and l.top_row == 3 and l.index == 6, [l.top_row, l.index])
	l.set_items(rows)
	l.active = false
	check("list_inactive_page_keeps_index", l.page(1, false) and l.top_row == 10 and l.index == 0, [l.top_row, l.index])
	l.set_items(rows)
	l.active = true
	check("key_pagedown_pages", l.handle_input(_key(KEY_PAGEDOWN)) and l.top_row == 10)
	check("key_pageup_pages", l.handle_input(_key(KEY_PAGEUP)) and l.top_row == 0)
	l.set_items(rows)
	check("action_page_down_not_taken_qe_stay_actor_swap", not l.handle_input(_action("ui_page_down")) and l.top_row == 0)
	await _clear()


func _template_rows(n: int) -> Array:
	var rows := []
	for k in n:
		rows.append({"text": "第%d项" % k, "icon": 116, "right": "×%d" % k})
	return rows


func _template() -> void:
	XUiSkin.FORCE = true
	var page := XSkinTemplatePage.new()
	page.title = "模板"
	page.group_key = "items"
	page.list_title = "测试"
	page.ring_center = ["45", "种"]
	add_child(page)
	await frames(3)
	var cats := []
	for k in 3:
		cats.append({"key": "c%d" % k, "name": "类%d" % k, "icon": 116, "count": 5})
	page.set_categories(cats, 0)
	page.set_items(_template_rows(5))
	await frames(3)
	check("tpl_no_pager_when_one_page", not page.pager.visible)
	check("tpl_footer_text_when_one_page", page.footer_text() == "")
	page.set_items(_template_rows(45))
	await frames(3)
	check("tpl_pager_over_one_page", page.pager.visible and page.pager.pages == 3 and page.pager.page == 1, [page.pager.visible, page.pager.pages])
	var panel := page.list_panel.size
	var list_end := page.list.position.y + page.list.size.y
	check("tpl_pager_below_list", page.pager.position.y >= list_end and page.pager.position.y + page.pager.size.y <= panel.y + 0.5, [page.pager.position, page.pager.size, list_end, panel])
	check("tpl_pager_inside_panel_width", page.pager.position.x >= 0 and page.pager.position.x + page.pager.size.x <= panel.x, [page.pager.position, page.pager.size, panel])
	check("tpl_pager_height_ge_44", page.pager.size.y >= 44.0 and page.pager.button_rect(1).size.y >= 44.0, page.pager.size)
	await shot("tpl_page1")
	_pager_click(page.pager, 1)
	await frames(3)
	check("tpl_click_right_pages", page.list.top_row == 10 and page.pager.page == 2, [page.list.top_row, page.pager.page])
	check("tpl_ring_focus_keeps_index", page.list.index == 0, page.list.index)
	_pager_click(page.pager, 1)
	await frames(3)
	check("tpl_last_page_label", page.pager.page == 3 and page.pager.pages == 3)
	await shot("tpl_page3")
	_pager_click(page.pager, -1)
	await frames(3)
	check("tpl_click_left_pages_back", page.pager.page == 2)
	# 换页签（换一份列表）：回第 1 页
	page.set_items(_template_rows(30))
	await frames(3)
	check("tpl_tab_switch_back_to_page1", page.list.top_row == 0 and page.pager.page == 1 and page.pager.pages == 2, [page.list.top_row, page.pager.page])
	# 列表有焦点时翻页：选中项跟着挪
	page.set_focus("list")
	_pager_click(page.pager, 1)
	await frames(3)
	check("tpl_focus_list_index_follows", page.list.index == 10 and page.list.top_row == 5 and page.pager.page == 2, [page.list.index, page.list.top_row])   # 30 项＝15 行，末页夹到 top 5（不留空行）
	# 再回第一页后返回再进＝新建页从第 1 页起
	await _clear()
	var again := XSkinTemplatePage.new()
	again.title = "模板"
	again.group_key = "items"
	add_child(again)
	await frames(3)
	again.set_items(_template_rows(45))
	await frames(3)
	check("tpl_reenter_starts_page1", again.list.top_row == 0 and again.pager.page == 1)
	await _clear()


## 物品页：在第 2 页切分类回第 1 页（T049 小A核 P2-2：原来 _top 清了、_index 没清，会停在第 2 页）
func _item_page() -> void:
	XUiSkin.FORCE = true
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.flags["tianqi"] = {"rules": 1}
	var n := 0
	for id in range(1, 500):
		var rec := XDB.rec("Items", id)
		if rec.is_empty() or str(rec.get("name", "")).begins_with("-") or str(rec.get("name", "")) == "" or int(rec.get("itypeId", 1)) != 1:
			continue
		s.gain_item(id, 3)
		n += 1
		if n >= 45:
			break
	var page := XItemScene.new()
	add_child(page)
	await frames(3)
	var sk := page.skin
	if not check("item_page_built", sk != null):
		return
	check("item_pager_over_one_page", page.entries().size() > 20 and sk.pager.visible, page.entries().size())
	page._unhandled_input(_action("ui_accept"))
	await frames(2)
	page._index = 25
	page._top = 5
	page._refresh()
	await frames(3)
	check("item_on_page2", sk.pager.page == 2, [sk.pager.page, sk.list.top_row])
	sk._on_ring_changed(1)
	await frames(3)
	check("item_ring_switch_back_to_page1", page._index == 0 and page._top == 0 and sk.list.top_row == 0 and sk.pager.page == 1, [page._index, page._top, sk.list.top_row, sk.pager.page])
	await _clear()


func _books() -> void:
	XState.new_game(3, 1, [8, 9, 10])   # 不带天启篇标记：FORCE 关掉后新界面也是关的（西游档）
	XUiSkin.FORCE = true
	var book := XActorBook.new()
	add_child(book)
	await frames(4)
	var n := XActorBook.actor_count()
	check("actor_book_over_one_page", n > XActorBook.INDEX_ROWS, n)
	check("actor_skin_on_has_pager_and_one_row_less", book.index_pager != null and book.index_pager.visible and book.index_rows() == XActorBook.INDEX_ROWS - 1, book.index_rows())
	check("actor_pager_below_rows", book.index_pager.position.y >= XMVWindow.PADDING + book.index_rows() * XActorBook.LH, [book.index_pager.position, book.index_rows()])
	check("actor_arrow_hidden_by_pager", not book.index_win.down_arrow)
	await shot("actor_book_p1")
	_pager_click(book.index_pager, 1)
	await frames(3)
	check("actor_click_next_page", book.top == book.index_rows() and book.index_pager.page == 2 and book.index >= book.top, [book.top, book.index, book.index_pager.page])
	await shot("actor_book_p2")
	_pager_click(book.index_pager, -1)
	await frames(3)
	check("actor_click_prev_page", book.top == 0 and book.index_pager.page == 1, [book.top, book.index_pager.page])
	# 技能页（第二个翻页件）：找一个技能超一页的角色
	var found := -1
	for i in n:
		book.index = i
		book._select_actor()
		book.ok()
		await frames(2)
		if book.skill_list.size() > XActorBook.LIST_ROWS:
			found = i
			break
		book.cancel()
		await frames(2)
	if check("actor_has_actor_with_many_skills", found >= 0):
		check("actor_skills_pager_and_rows", book.mode == "skills" and book.list_pager != null and book.list_pager.visible and book.list_rows() == XActorBook.LIST_ROWS - 1, book.list_rows())
		check("actor_skills_pager_below_rows", book.list_pager.position.y >= XMVWindow.PADDING + book.list_rows() * XActorBook.LH, book.list_pager.position)
		_pager_click(book.list_pager, 1)
		await frames(3)
		check("actor_skills_click_next_page", book.skill_top == mini(book.list_rows(), book.skill_list.size() - book.list_rows()) and book.list_pager.page == 2 and book.skill_index >= book.skill_top, [book.skill_top, book.skill_index, book.list_pager.page])
		await shot("actor_book_skills_p2")
	await _clear()

	var eb := XEnemyBookPage.new()
	add_child(eb)
	await frames(4)
	var total := eb.ids.size()
	check("enemy_book_over_one_page", total > XEnemyBookPage.ROWS, total)
	check("enemy_skin_on_pager_and_rows", eb.index_pager != null and eb.index_pager.visible and eb.index_rows() == XEnemyBookPage.ROWS - 1)
	check("enemy_pager_below_rows", eb.index_pager.position.y >= XMVWindow.PADDING + eb.index_rows() * 36.0, eb.index_pager.position)
	await shot("enemy_book_p1")
	_pager_click(eb.index_pager, 1)
	await frames(3)
	check("enemy_click_next_page", eb.top == eb.index_rows() and eb.index_pager.page == 2 and eb.index == eb.index_rows(), [eb.top, eb.index])
	await shot("enemy_book_p2")
	XEnemyBookPage.last_index = 40
	await _clear()
	var eb2 := XEnemyBookPage.new()
	add_child(eb2)
	await frames(4)
	var want := XListPager.top_for_index(40, eb2.index_rows(), eb2.ids.size())
	check("enemy_reenter_to_page_of_selection", eb2.top == want and eb2.index >= eb2.top and eb2.index < eb2.top + eb2.index_rows(), [eb2.top, eb2.index, want])
	XEnemyBookPage.last_index = 0
	await _clear()

	var ib := XInlayBook.new()
	add_child(ib)
	await frames(4)
	ib.ok()
	await frames(3)
	check("inlay_over_one_page", ib.list.size() > XInlayBook.ROWS, ib.list.size())
	check("inlay_skin_on_pager_and_rows", ib.index_pager != null and ib.index_pager.visible and ib.index_rows() == XInlayBook.ROWS - 1)
	check("inlay_pager_below_rows", ib.index_pager.position.y >= XMVWindow.PADDING + ib.index_rows() * XInlayBook.LH, ib.index_pager.position)
	await shot("inlay_book_p1")
	_pager_click(ib.index_pager, 1)
	await frames(3)
	check("inlay_click_next_page", ib.top == ib.index_rows() and ib.index_pager.page == 2, [ib.top, ib.index_pager.page])
	await shot("inlay_book_p2")
	await _clear()

	# 西游档（新界面关着）：没有翻页件、行数不变、下箭头照旧
	XUiSkin.FORCE = false
	var ob := XActorBook.new()
	add_child(ob)
	await frames(4)
	check("skin_off_actor_unchanged", ob.index_pager == null and ob.list_pager == null and ob.index_rows() == XActorBook.INDEX_ROWS and ob.index_win.down_arrow)
	var oe := XEnemyBookPage.new()
	add_child(oe)
	await frames(4)
	check("skin_off_enemy_unchanged", oe.index_pager == null and oe.index_rows() == XEnemyBookPage.ROWS and oe.index_win.down_arrow)
	var oi := XInlayBook.new()
	add_child(oi)
	await frames(4)
	oi.ok()
	await frames(3)
	check("skin_off_inlay_unchanged", oi.index_pager == null and oi.index_rows() == XInlayBook.ROWS and oi.index_win.down_arrow)
	await _clear()
