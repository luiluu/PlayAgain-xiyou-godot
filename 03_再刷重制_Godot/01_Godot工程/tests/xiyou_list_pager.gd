extends Node
## 【cc·天启篇·T049】通用翻页件 XListPager 专项：
## - 纯函数：页数、第几页（末页夹底）、第 p 页的 top、重新进页的 top_for_index；
## - 翻页件：超一页才显示；点左右钮发 page_step；到头的钮点了没反应；按下松开不在同一钮不算；
## - XSkinList.page：整页翻、选中项跟着挪一页、没焦点只翻不挪、键盘 PageUp／PageDown 认、ui_page_down 动作（Q／E／肩键）不认；
## - 模板页（物品、技能、装备候选都走它）：超一页出翻页件、点钮翻页、页码跟着变、换页签（换列表）回第 1 页、一页内不出；
## - 图鉴三页（角色图鉴、怪物图鉴、符文图鉴）：新界面开着时少放一行给翻页件、点钮翻页、翻页件不压行；新界面关着（西游档）
##   没有翻页件、行数不变、下箭头照旧；怪物图鉴重新进页翻到上次选中那只所在的页。
## - T050（其余旧画布页）：仓库、星耀仓库、制作、成就、宠物、时装、地图传送、训练目录、遗忘技能、商人29、图鉴掉落列表：
##   新界面开着且列表超一页时有翻页件、行数少一行（成就窗底边本来有空地、行数不变）、件在最后一行之下、点钮翻页、切页签回第 1 页；
##   新界面关着（西游档）没有翻页件、行数不变；物品页键盘在分类态切分类回第 1 页。
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
	await _pages50()
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


# ---------------- T050：其余旧画布页 ----------------
## 一页的通用断言：新界面开着有翻页件且可见、行数＝基准−1（rows_minus＝0 时不变）、件在最后一行之下、点右钮翻到第 2 页、点左钮回第 1 页
func _page_checks(tag: String, pg: XListPager, rows: int, base: int, last_row_bottom: float, top_of: Callable, total: int, rows_minus := 1) -> void:
	if not check(tag + "_pager_exists_visible", pg != null and pg.visible, pg):
		return
	check(tag + "_rows_minus_one", rows == base - rows_minus, [rows, base])
	check(tag + "_pager_below_rows", pg.position.y >= last_row_bottom, [pg.position.y, last_row_bottom])
	check(tag + "_pager_touch_44", pg.size.y >= 44.0 and pg.button_rect(1).size.y >= 44.0 and pg.button_rect(1).size.x >= 44.0, pg.size)
	_pager_click(pg, 1)
	await frames(3)
	var want := XListPager.top_of(2, rows, total)
	check(tag + "_click_next_page", pg.page == 2 and int(top_of.call()) == want, [pg.page, top_of.call(), want])
	await shot(tag + "_p2")
	_pager_click(pg, -1)
	await frames(3)
	check(tag + "_click_prev_page", pg.page == 1 and int(top_of.call()) == 0, [pg.page, top_of.call()])


func _pages50() -> void:
	var ids := []
	for i in range(1, 41):
		ids.append(i)
	var s := XState.new_game(3, 1, ids)
	XState.current = s
	var pad := XMVWindow.PADDING
	var lh := 36.0
	for skin_on in [true, false]:
		XUiSkin.FORCE = skin_on
		var tg := "skin_on" if skin_on else "skin_off"
		# --- 仓库（两列；总量按行算）
		for id in range(1, 60):
			var rec := XDB.rec("Items", id)
			if rec.is_empty() or str(rec.get("name", "")) == "" or str(rec.get("name", "")).begins_with("-") or int(rec.get("itypeId", 1)) != 1:
				continue
			s.gain_item(id, 2)
		var wh := XWarehouseScene.new()
		add_child(wh)
		await frames(3)
		wh.option = 1
		wh.mode = "category"
		wh.category = 0
		wh._reload()
		await frames(2)
		if skin_on:
			check("wh_items_over_one_page", ceili(wh.data.size() / 2.0) > XWarehouseScene.ROWS, wh.data.size())
			await _page_checks("wh", wh.list_pager, wh.list_rows(), XWarehouseScene.ROWS, pad + wh.list_rows() * lh, func(): return wh.top, ceili(wh.data.size() / 2.0))
			check("wh_arrow_hidden_by_pager", not wh.list_win.down_arrow)
			# 分类态翻页不动选中；切页签（点分类）回第 1 页
			wh.top = 3
			wh._refresh()
			var cat_click := InputEventMouseButton.new()
			cat_click.button_index = MOUSE_BUTTON_LEFT
			cat_click.pressed = true
			cat_click.position = Vector2(XWarehouseScene.CAT_RECT.position.x + pad + (XWarehouseScene.CAT_W + 12) * 1.5, XWarehouseScene.CAT_RECT.position.y + pad + 10)
			wh._gui_input(cat_click)
			check("wh_tab_switch_back_to_page1", wh.top == 0 and wh.index == -1, [wh.top, wh.index])
		else:
			check("wh_skin_off_unchanged", wh.list_pager == null and wh.list_rows() == XWarehouseScene.ROWS, wh.list_rows())
		wh.queue_free()
		await frames(2)
		# --- 星耀仓库（两列；注入 40 件装备）
		var sw := XStarWarehouseScene.new()
		add_child(sw)
		await frames(3)
		var gear := []
		for id in range(1, 41):
			gear.append(XDB.rec("Weapons", id))
		sw.data = gear
		sw.mode = "category"
		sw.category = 0
		sw._refresh()
		await frames(2)
		if skin_on:
			await _page_checks("sw", sw.list_pager, sw.list_rows(), XStarWarehouseScene.ROWS, pad + sw.list_rows() * lh, func(): return sw.top, ceili(sw.data.size() / 2.0))
		else:
			check("sw_skin_off_unchanged", sw.list_pager == null and sw.list_rows() == XStarWarehouseScene.ROWS, sw.list_rows())
		sw.queue_free()
		await frames(2)
		# --- 制作
		var cr := XCraftingScene.new()
		add_child(cr)
		await frames(3)
		var rs := XCrafting.recipes()
		var many := []
		for i in 30:
			many.append(rs[i % rs.size()])
		cr.list = many
		cr.mode = "category"
		cr.index = -1
		cr.top = 0
		cr._refresh()
		await frames(2)
		if skin_on:
			await _page_checks("craft", cr.list_pager, cr.list_rows(), XCraftingScene.LIST_ROWS, pad + cr.list_rows() * lh, func(): return cr.top, cr.list.size())
			cr.top = 5
			cr._refresh()
			cr.select_category((cr.cat_index + 1) % XCrafting.CATEGORIES.size())
			check("craft_tab_switch_back_to_page1", cr.top == 0, cr.top)
		else:
			check("craft_skin_off_unchanged", cr.list_pager == null and cr.list_rows() == XCraftingScene.LIST_ROWS, cr.list_rows())
		cr.queue_free()
		await frames(2)
		# --- 成就（每页 6 条不变：窗口底边本来有 44px 空地）
		var ac := XAchievementScene.new()
		add_child(ac)
		await frames(3)
		if skin_on:
			check("ach_over_one_page", ac.list.size() > XAchievementScene.PAGE_ROWS, ac.list.size())
			await _page_checks("ach", ac.list_pager, XAchievementScene.PAGE_ROWS, XAchievementScene.PAGE_ROWS, pad + XAchievementScene.PAGE_ROWS * 108.0, func(): return ac.top, ac.list.size(), 0)
			ac.top = 3
			ac._refresh()
			ac.select_type((ac.type_index + 1) % ac.types().size())
			check("ach_tab_switch_back_to_page1", ac.top == 0, ac.top)
		else:
			check("ach_skin_off_unchanged", ac.list_pager == null, ac.list_pager)
		ac.queue_free()
		await frames(2)
		# --- 宠物
		var pets := []
		for id in range(1, 60):
			var p := XPets.create(id)
			if not p.is_empty():
				pets.append(p)
			if pets.size() >= 20:
				break
		s.pets = {"list": pets, "war": 0, "team_a": 0}
		var ps := XPetScene.new()
		add_child(ps)
		await frames(3)
		if skin_on:
			check("pets_over_one_page", pets.size() > XPetScene.ROWS, pets.size())
			await _page_checks("pets", ps.index_pager, ps.index_rows(), XPetScene.ROWS, pad + ps.index_rows() * lh, func(): return ps.top, XPets.list(s).size())
		else:
			check("pets_skin_off_unchanged", ps.index_pager == null and ps.index_rows() == XPetScene.ROWS, ps.index_rows())
		ps.queue_free()
		await frames(2)
		# --- 时装
		var cs := XCostumesScene.new()
		add_child(cs)
		await frames(3)
		cs.actors = s.members().slice(0, 30)
		cs.index = 0
		cs.top = 0
		cs._refresh()
		await frames(2)
		if skin_on:
			await _page_checks("costumes", cs.list_pager, cs.list_rows(), XCostumesScene.ROWS, pad + cs.list_rows() * lh, func(): return cs.top, cs.actors.size())
		else:
			check("costumes_skin_off_unchanged", cs.list_pager == null and cs.list_rows() == XCostumesScene.ROWS, cs.list_rows())
		cs.queue_free()
		await frames(2)
		# --- 地图传送（窗高随屏幕）
		var mt := XMapTransferScene.new()
		add_child(mt)
		await frames(4)
		if skin_on:
			check("transfer_over_one_page", XMapTransfer.maps().size() > mt._list_rows() + 1, XMapTransfer.maps().size())
			await _page_checks("transfer", mt.list_pager, mt._list_rows(), mt._list_rows() + 1, pad + mt._list_rows() * lh, func(): return mt.top, XMapTransfer.maps().size())
			check("transfer_pager_in_window", mt.list_pager.position.y + mt.list_pager.size.y <= mt.list_win.size.y and mt.list_pager.size.x <= mt.list_win.size.x, [mt.list_pager.position, mt.list_pager.size, mt.list_win.size])
		else:
			check("transfer_skin_off_unchanged", mt.list_pager == null and mt._list_rows() == XMapTransferScene.LIST_ROWS, mt._list_rows())
		mt.queue_free()
		await frames(2)
		# --- 训练目录（40 人；精魂窗盖在目录窗底 64px，件摆在它上面，超 17 人只放 16 行）
		var tr := XTrainingScene.new()
		add_child(tr)
		await frames(3)
		if skin_on:
			check("training_over_17", s.members().size() > 17 and tr.index_rows() == 16, [s.members().size(), tr.index_rows()])
			await _page_checks("training", tr.index_pager, tr.index_rows(), XTrainingScene.INDEX_ROWS, pad + tr.index_rows() * lh, func(): return tr.top, s.members().size(), 3)
			check("training_pager_above_gold", tr.index_pager.position.y + tr.index_pager.size.y <= XTrainingScene.GOLD_RECT.position.y, tr.index_pager.position)
		else:
			check("training_skin_off_unchanged", tr.index_pager == null and tr.index_rows() == XTrainingScene.INDEX_ROWS, tr.index_rows())
		tr.queue_free()
		await frames(2)
		# --- 遗忘技能（窗口裹着行数：超一页每页 11 行、窗加高放件）
		var fa: XActor = s.members()[0]
		var sk_ids := []
		for id in range(1, 400):
			var r := XDB.rec("Skills", id)
			if not r.is_empty() and str(r.get("name", "")) != "" and int(r.get("stypeId", 0)) in XForgetSkillScene.TYPES:
				sk_ids.append(id)
			if sk_ids.size() >= 20:
				break
		for id in sk_ids:
			if not fa.skill_ids.has(id):
				fa.learn_skill(id)
		var fs := XForgetSkillScene.new().setup(fa)
		add_child(fs)
		await frames(3)
		if skin_on:
			check("forget_window_taller_for_pager", fs.win.size.y == 11 * lh + pad * 2 + 46.0 and fs.page_rows() == 11, [fs.win.size.y, fs.page_rows()])
			await _page_checks("forget", fs.pager, fs.page_rows(), XForgetSkillScene.MAX_ROWS, pad + fs.page_rows() * lh, func(): return fs.top, fs.rows.size())
			check("forget_pager_inside_window", fs.pager.position.y + fs.pager.size.y <= fs.win.size.y, [fs.pager.position, fs.win.size])
		else:
			check("forget_skin_off_unchanged", fs.pager == null and fs.page_rows() == XForgetSkillScene.MAX_ROWS and fs.win.size.y == 12 * lh + pad * 2, [fs.page_rows(), fs.win.size])
		fs.queue_free()
		await frames(2)
		# --- 商人29（列表翻页件翻左侧列表，PageUp／PageDown 仍翻详情）
		var m29 := XMerchant29Page.new()
		add_child(m29)
		await frames(3)
		var fake := []
		for i in 30:
			fake.append({"text": "条目%d" % i, "enabled": true})
		m29.choose(fake, func(_r): pass, func(): pass)
		await frames(2)
		if skin_on:
			await _page_checks("m29", m29.list.pager, m29.list.rows, XMerchant29Page.LIST_ROWS, pad + m29.list.rows * lh, func(): return m29.list.top, m29.list.entries.size())
		else:
			check("m29_skin_off_unchanged", m29.list.pager == null and m29.list.rows == XMerchant29Page.LIST_ROWS, m29.list.rows)
		m29.queue_free()
		await frames(2)
		# --- 图鉴掉落列表
		var eb := XEnemyBookPage.new()
		add_child(eb)
		await frames(3)
		var row0 := {}
		for id in range(1, 200):
			var dr := XEnemyBookPage.drop_rows(XEnemyBookPage.new_enemy(id))
			if not dr.is_empty():
				row0 = dr[0]
				break
		var fk := []
		for i in 60:
			fk.append(row0)
		eb.mode = "drops"
		eb.drop_list = fk
		eb.drop_index = 0
		eb.drop_top = 0
		eb._show_drops(true)
		eb._refresh()
		await frames(2)
		if skin_on:
			await _page_checks("drops", eb.drop_pager, eb.drop_rows_visible(), 19, pad + eb.drop_rows_visible() * lh, func(): return eb.drop_top, eb.drop_list.size())
		else:
			check("drops_skin_off_unchanged", eb.drop_pager == null and eb.drop_rows_visible() == 19, eb.drop_rows_visible())
		eb.queue_free()
		await frames(2)
	XUiSkin.FORCE = true
	await _item_category_key()


## 物品页：键盘在分类态用 _move_inner 切分类，选中项清零回第 1 页（小A 复核附注）；西游档不变
func _item_category_key() -> void:
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
	XUiSkin.FORCE = true
	var page := XItemScene.new()
	add_child(page)
	await frames(3)
	var sk := page.skin
	if not check("item_key_page_built", sk != null):
		return
	page._unhandled_input(_action("ui_accept"))
	await frames(2)
	page._index = 25
	page._top = 5
	page._refresh()
	await frames(3)
	check("item_key_on_page2", sk.pager.page == 2, sk.pager.page)
	page._mode = "category"
	page._move_inner(1, false)
	page._refresh()
	await frames(3)
	check("item_key_category_switch_back_to_page1", page._index == 0 and page._top == 0 and sk.pager.page == 1, [page._index, page._top, sk.pager.page])
	await _clear()
