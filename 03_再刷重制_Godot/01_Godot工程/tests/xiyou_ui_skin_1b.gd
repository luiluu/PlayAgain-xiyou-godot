extends Node
## 新界面第 1B 批（ui-skin-1b）专项：模板页 XSkinTemplatePage、物品页 XSkinItemPage、技能页 XSkinSkillPage、说明卡换皮。
## - 模板：三块锚点（左环、中列表、右牌）、两列 10 行、页码、自动导航（环→列表→取消回环→back）、操作菜单、目标列表；
## - 两列：名字太长先缩字再加省略号；两列网格走法（左右一格、上下一行、到头循环）；
## - 物品页：天启篇存档开新布局、旧窗口全藏；五类环带数量；列表 20 项一屏；确定→操作菜单→使用→「给谁用」选人→用掉（数量减、血加）；
##   预估回复（+n／满）；取消逐层回；西游存档不建新布局；
## - 技能页：类型环、两列技能、消耗写右侧、对队友的技能选人、Q/E 换人；
## - 说明卡：新皮肤开时外框换成黑面板（品质色细线），关着时照旧。
## 带 -- --out=<目录> 且有窗口时截图（16:9、20:9）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func shot(name: String) -> void:
	if not windowed():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK, img.get_size())


## 16:9 拍一张，有窗口时再拍 20:9
func shots(name: String) -> void:
	if not windowed():
		return
	await frames(20)
	await shot(name + "_16x9")
	var win := get_window()
	var old := win.size
	win.size = Vector2i(1600, 720)
	await frames(12)
	await shot(name + "_20x9")
	win.size = Vector2i(960, 720)   # 收口批：4:3 也拍
	await frames(12)
	await shot(name + "_4x3")
	win.size = old
	await frames(8)


func _key(action: String, echo := false) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _click(p: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	return e


func _keycode(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	return e


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_1b")
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	_fit_text()
	_grid()
	await _template()
	await _item_page()
	await _skill_page()
	await _help_card()
	XUiSkin.motion_override = -1
	XState.current = null
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(tianqi := true) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	if tianqi:
		s.flags["tianqi"] = {"rules": 1}
	return s


## 背包里放一批真实物品（名字、图标、说明都是游戏数据）
func _fill_items(s: XState) -> Array:
	var ids := []
	for id in range(1, 400):
		var rec := XDB.rec("Items", id)
		if rec.is_empty() or str(rec.get("name", "")).begins_with("-") or str(rec.get("name", "")) == "" or int(rec.get("itypeId", 1)) != 1:
			continue
		ids.append(id)
		s.gain_item(id, (id * 7) % 23 + 1)
		if ids.size() >= 30:
			break
	return ids


# ---- 两列名字放不下 ----
func _fit_text() -> void:
	var f := XUiSkin.font("body")
	var short: Array = XSkinList.fit_text(f, "止血草", 200, 19, 16)
	check("fit_short_keeps", short == ["止血草", 19], short)
	var mid: Array = XSkinList.fit_text(f, "治疗药水(小)", f.get_string_size("治疗药水(小)", HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 1, 19, 16)
	check("fit_shrinks_first", mid[0] == "治疗药水(小)" and int(mid[1]) < 19 and int(mid[1]) >= 16, mid)
	var long: Array = XSkinList.fit_text(f, "伙伴号角：里德的超长名字测试", 120, 19, 16)
	check("fit_ellipsis", str(long[0]).ends_with("…") and int(long[1]) == 16 and f.get_string_size(long[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= 120, long)


func _grid() -> void:
	check("grid_right", XSkinItemPage.grid_move(0, 5, 2, 1, 0, true) == 1)
	check("grid_right_wraps_row", XSkinItemPage.grid_move(1, 5, 2, 1, 0, true) == 2)
	check("grid_left_first_wraps", XSkinItemPage.grid_move(0, 5, 2, -1, 0, true) == 4)
	check("grid_left_first_echo_stays", XSkinItemPage.grid_move(0, 5, 2, -1, 0, false) == 0)
	check("grid_down", XSkinItemPage.grid_move(1, 5, 2, 0, 1, true) == 3)
	check("grid_down_wraps_top", XSkinItemPage.grid_move(3, 5, 2, 0, 1, true) == 1)
	check("grid_up_wraps_bottom", XSkinItemPage.grid_move(0, 5, 2, 0, -1, true) == 4)
	check("grid_up_wraps_short_col", XSkinItemPage.grid_move(1, 5, 2, 0, -1, true) == 3)
	check("grid_empty", XSkinItemPage.grid_move(0, 0, 2, 0, 1, true) == 0)


# ---- 模板页（自动导航）----
func _template() -> void:
	_state()
	var page := XSkinTemplatePage.new()
	page.title = "模板"
	page.group_key = "items"
	page.list_title = "测试"
	page.ring_center = ["30", "种"]
	var fired := {"activated": -1, "back": 0, "button": -1}
	page.item_activated.connect(func(i): fired.activated = i)
	page.back.connect(func(): fired.back += 1)
	page.card_button.connect(func(i): fired.button = i)
	add_child(page)
	await frames(3)
	var r := page.layout.rects()
	check("tpl_three_blocks", r.left.size.x == 300.0 and r.right.size.x == 336.0 and r.center.position.x >= r.left.end.x + 16 and r.right.position.x >= r.center.end.x + 16, r)
	check("tpl_center_1280", is_equal_approx(r.center.size.x, 1280 - 48 - 300 - 336 - 32), r.center)
	check("tpl_top_bottom", r.left.position.y == XUiSkin.TOP and is_equal_approx(r.left.end.y, XUiSkin.BOTTOM), r.left)
	var cats := []
	for k in 5:
		cats.append({"key": "c%d" % k, "name": "类%d" % k, "icon": 116, "count": k * 3})
	page.set_categories(cats, 1)
	check("tpl_ring_counts", page.ring.items.size() == 5 and page.ring.items[1].name == "类1 3" and page.ring.index == 1, page.ring.items)
	var rows := []
	for k in 45:
		rows.append({"text": "第%d项" % k, "icon": 116, "right": "×%d" % k})
	page.set_items(rows)
	check("tpl_two_cols_ten_rows", page.list.columns == 2 and page.list.visible_rows() == 10 and page.list.row_height == 48, [page.list.columns, page.list.visible_rows()])
	check("tpl_twenty_per_screen", page.list.visible_rows() * page.list.columns == 20)
	check("tpl_footer_pages", page.footer_text() == "第 1 / 3 页", page.footer_text())
	check("tpl_focus_ring_list_inactive", page.focus == "ring" and not page.list.active and not page.list.bar.visible)
	page.handle_input(_key("ui_right"))
	check("tpl_ring_moves", page.ring.index == 2)
	page.handle_input(_key("ui_accept"))
	check("tpl_ok_to_list", page.focus == "list" and page.list.active)
	for k in 11:
		page.handle_input(_key("ui_down"))
	await frames(2)
	check("tpl_list_scrolls", page.list.index == 22 and page.list.top_row > 0, [page.list.index, page.list.top_row])
	check("tpl_footer_follows", page.footer_text() == "第 2 / 3 页", page.footer_text())
	page.handle_input(_key("ui_accept"))
	check("tpl_item_activated", fired.activated == 22)
	page.set_card({"title": "牌", "desc": "说明", "buttons": [{"text": "甲", "primary": true}, {"text": "乙", "disabled": true}]})
	page.set_focus("card")
	check("tpl_card_focus_first_button", page.card.button_index == 0)
	page.handle_input(_key("ui_accept"))
	check("tpl_card_button", fired.button == 0, fired)
	page.handle_input(_key("ui_right"))
	fired.button = -1
	page.handle_input(_key("ui_accept"))
	check("tpl_card_disabled_no_fire", fired.button == -1 and page.card.button_index == 1)
	page.handle_input(_key("ui_cancel"))
	check("tpl_cancel_card_to_list", page.focus == "list")
	page.handle_input(_key("ui_cancel"))
	check("tpl_cancel_list_to_ring", page.focus == "ring")
	page.handle_input(_key("ui_cancel"))
	check("tpl_cancel_ring_back", fired.back == 1)
	page.open_menu([{"text": "一"}, {"text": "二"}], 1)
	check("tpl_menu_open", page.focus == "menu" and page.menu_panel.visible and page.menu.index == 1)
	check("tpl_menu_in_right_block", page.menu_panel.position.x >= 0 and page.menu_panel.get_rect().end.x <= page.layout.right.size.x and page.menu_panel.get_rect().end.y <= page.layout.right.size.y)
	page.set_focus("list")
	check("tpl_menu_closes", not page.menu_panel.visible)
	page.show_targets([{"name": "甲", "cur": 10, "max": 20, "right": "+5"}, {"name": "乙", "cur": 20, "max": 20, "right": "满"}], true, false, 1)
	check("tpl_targets_reserved", page.targets.visible and page.card.reserve_bottom >= XSkinTargetList.height_for(2) and page.targets.index == 1)
	check("tpl_targets_above_buttons", page.targets.get_rect().end.y <= page.card.button_rect(0).position.y + 0.5, [page.targets.get_rect(), page.card.button_rect(0)])
	page.show_targets([])
	check("tpl_targets_hidden", not page.targets.visible and page.card.reserve_bottom == 0.0)
	var cs := XSkinTemplatePage.help_rows([["名字", 20, "#fff", false, 0], ["\\c[2]红字\\i[5]", 16, "rgba(255,128,128,1)", false, 0], ["", 16, "#fff", false, 0],
		["甲：1\\col[50]乙：2", 16, "#fff", false, 0]])
	check("tpl_help_rows", cs.size() == 2 and cs[0].text == "红字" and cs[1].text == "甲：1　　乙：2", cs)
	check("tpl_currency_default", page.currency_pairs()[0][0] == "精魂")
	page.set_focus("ring")
	var vis := page.list.top_row * 2 + 1   # 当前屏里另一格（列表已滚过，cell_rect 按滚动后算）
	page.list._gui_input(_click(page.list.cell_rect(vis).get_center()))
	var up := _click(page.list.cell_rect(vis).get_center())
	up.pressed = false   # 收口批 TOUCH_V2：列表松手才算点
	page.list._gui_input(up)
	check("tpl_auto_click_list_focuses", page.focus == "list" and page.list.index == vis, [page.focus, page.list.index, vis])
	page.queue_free()
	await frames(2)
	var flat := XSkinTemplatePage.new()
	flat.show_ring = false
	add_child(flat)
	await frames(2)
	check("tpl_no_ring_focus_list", flat.focus == "list" and flat.list.active and not flat.ring.visible)
	flat.queue_free()
	await frames(2)


# ---- 物品页 ----
func _item_page() -> void:
	var s := _state()
	var ids := _fill_items(s)
	var a: XActor = s.members()[1]
	a.hp = maxf(a.mhp - 100.0, 1.0)
	var page := XItemScene.new()
	add_child(page)
	await frames(3)
	var sk := page.skin
	check("item_skin_built", sk != null)
	if sk == null:
		page.queue_free()
		return
	check("item_old_windows_hidden", not page.cat_win.visible and not page.list_win.visible and not page.info_win.visible and not page.status_win.visible and not page.toolbar.visible)
	check("item_ring_five", sk.ring.items.size() == 5 and str(sk.ring.items[0].name).begins_with("物品 "), sk.ring.items.map(func(x): return x.name))
	var n := page.entries().size()
	check("item_ring_count", n >= 12 and str(sk.ring.items[0].name) == "物品 %d" % n and sk.ring_center[0] == str(n), [sk.ring.items[0].name, sk.ring_center, n])
	check("item_list_20", sk.list.columns == 2 and sk.list.visible_rows() == 10 and sk.list.items.size() == n, [sk.list.visible_rows(), sk.list.items.size()])
	check("item_focus_ring", sk.focus == "ring" and not sk.list.active)
	check("item_title_wide", sk.layout.left.size.x == 300.0)
	await shots("ui_skin_1b_items_category")
	page._unhandled_input(_key("ui_right"))
	check("item_ring_right_moves_cat", page._cat == 1 and sk.ring.index == 1)
	page._unhandled_input(_key("ui_left"))
	page._unhandled_input(_key("ui_accept"))
	check("item_ok_to_list", page._mode == "list" and sk.focus == "list" and sk.list.active)
	page._unhandled_input(_key("ui_right"))
	check("item_list_right_one", page._index == 1 and sk.list.index == 1)
	page._unhandled_input(_key("ui_down"))
	check("item_list_down_two", page._index == 3 and sk.list.index == 3)
	# 选到治疗类（效果 11）的物品看「给谁用」
	var heal := -1
	var d := page.entries()
	for k in d.size():
		if d[k].rec.get("effects", []).any(func(e): return int(e.code) == 11 and float(e.value2) > 0) and int(d[k].rec.get("scope", 0)) == 7 and int(d[k].rec.get("occasion", 0)) in [0, 2]:
			heal = k
			break
	check("item_found_heal", heal >= 0)
	if heal >= 0:
		page._index = heal
		page._refresh()
		check("item_card_title", sk.card.title == XQuality.list_name(d[heal].rec), sk.card.title)
		check("item_card_effect", sk.card.sections.size() >= 1 and str(sk.card.sections[0].rows[0].text).begins_with("效果　回复生命"), sk.card.sections)
		check("item_card_use_button", sk.card.buttons.size() == 1 and sk.card.buttons[0].text == "使用")
		check("item_targets_preview", sk.targets.visible and sk.targets.rows.size() == s.members().size() and not sk.targets.selectable, sk.targets.rows.size())
		var row: Dictionary = sk.targets.rows[1]
		check("item_targets_gain", str(row.right).begins_with("+") and int(str(row.right).substr(1)) <= 100, row.right)
		check("item_targets_full", str(sk.targets.rows[0].right) == "满", sk.targets.rows[0].right)
		await shots("ui_skin_1b_items_list")
		var before := s.item_count(int(d[heal].rec.id))
		var hp0 := a.hp
		page._unhandled_input(_key("ui_accept"))
		check("item_action_menu", page._mode == "action" and sk.focus == "menu" and sk.menu_panel.visible and str(sk.menu.items[0].text).begins_with("使用"), sk.menu.items.map(func(x): return x.text))
		await shots("ui_skin_1b_items_action")
		page._unhandled_input(_key("ui_accept"))
		check("item_actor_mode", page._mode == "actor" and sk.focus == "targets" and sk.targets.selectable)
		page._unhandled_input(_key("ui_down"))
		check("item_actor_down", page._actor == 1 and sk.targets.index == 1)
		var cat0 := page._cat
		sk.ring.select(2)
		check("item_ring_click_ignored_in_actor", page._mode == "actor" and page._cat == cat0 and sk.ring.index == cat0, [page._mode, page._cat, sk.ring.index])
		await shots("ui_skin_1b_items_target")
		page._unhandled_input(_key("ui_accept"))
		check("item_used", s.item_count(int(d[heal].rec.id)) == before - 1 and a.hp > hp0, [before, s.item_count(int(d[heal].rec.id)), hp0, a.hp])
		check("item_stays_actor", page._mode == "actor")
		page._unhandled_input(_key("ui_cancel"))
		check("item_cancel_to_list", page._mode == "list" and sk.focus == "list")
	page._unhandled_input(_key("ui_cancel"))
	check("item_cancel_to_cat", page._mode == "category" and sk.focus == "ring")
	# 鼠标：点列表第 2 项＝进列表并选中
	var cell := sk.list.cell_rect(2)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = cell.get_center()
	sk.list._gui_input(click)
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false   # 收口批 TOUCH_V2：列表松手才算点
	sk.list._gui_input(release)
	check("item_click_selects", page._mode == "list" and page._index == 2)
	# 武器类：装备详情行照说明卡
	page._mode = "category"
	page._cat = 2
	page._refresh()
	check("item_weapon_cat", sk.list_title == "武器" and sk.ring_center[1] == "件", [sk.list_title, sk.ring_center])
	page.queue_free()
	await frames(3)
	# 西游存档：不建新布局
	_state(false)
	var old := XItemScene.new()
	add_child(old)
	await frames(2)
	check("item_xiyou_old", old.skin == null and old.cat_win.visible and old.list_win.visible)
	old.queue_free()
	# 天启篇但总开关关掉：旧页
	_state()
	XUiSkin.ENABLED = false
	var off := XItemScene.new()
	add_child(off)
	await frames(2)
	check("item_switch_off_old", off.skin == null and off.cat_win.visible)
	XUiSkin.ENABLED = true
	off.queue_free()
	await frames(2)


# ---- 技能页 ----
func _skill_page() -> void:
	var s := _state()
	var page := XSkillScene.new()
	add_child(page)
	await frames(3)
	var sk := page.skin
	check("skill_skin_built", sk != null)
	if sk == null:
		page.queue_free()
		return
	check("skill_old_hidden", not page.type_win.visible and not page.list_win.visible and not page.status_win.visible)
	check("skill_ring_types", sk.ring.items.size() == page.types().size() and sk.ring.items.size() > 0, sk.ring.items.size())
	check("skill_title_actor", sk.title == "技能")
	await shots("ui_skin_1b_skill_type")
	page._unhandled_input(_key("ui_accept"))
	check("skill_list_mode", page.mode == "list" and sk.focus == "list")
	check("skill_hints_list", sk.hint_list == [["确定", "选择"], ["取消", "回类型"], ["Q / E", "翻页"]], sk.hint_list)
	check("skill_list_rows", sk.list.items.size() == page.entries().size() and sk.list.columns == 2)
	if page.entries().size() > 1:
		page._unhandled_input(_key("ui_right"))
		check("skill_right_one", page.index == 1 and sk.list.index == 1)
	check("skill_card", sk.card.title != "" and sk.card.title == str(page.current().get("name", "")), sk.card.title)
	await shots("ui_skin_1b_skill_list")
	page._unhandled_input(_key("ui_cancel"))
	check("skill_cancel_to_type", page.mode == "type" and sk.focus == "ring")
	check("skill_hints_type", sk.hint_list == [["确定", "选择"], ["取消", "返回"], ["Q / E", "换人"]], sk.hint_list)
	var a0 := page.actor_index
	page._unhandled_input(_keycode(KEY_E))   # 类型环上 Q/E 换人（列表里 Q/E 是翻页，同旧页）
	check("skill_qe_actor", page.actor_index != a0 and page.mode == "type" and sk.focus == "ring")
	page._unhandled_input(_key("ui_cancel"))
	page.queue_free()
	await frames(3)
	_state(false)
	var old := XSkillScene.new()
	add_child(old)
	await frames(2)
	check("skill_xiyou_old", old.skin == null and old.type_win.visible)
	old.queue_free()
	await frames(2)


# ---- 说明卡换皮 ----
func _help_card() -> void:
	_state()
	var c := XHelpCard.new()
	add_child(c)
	c.show_for(XDB.rec("Items", 26))
	c.position = Vector2(400, 200)
	await frames(2)
	check("help_skinned", c.skinned(), c.skinned())
	await shot("ui_skin_1b_help_card")
	c.queue_free()
	_state(false)
	var c2 := XHelpCard.new()
	add_child(c2)
	c2.show_for(XDB.rec("Items", 26))
	await frames(2)
	check("help_xiyou_old", not c2.skinned())
	c2.queue_free()
	await frames(2)
