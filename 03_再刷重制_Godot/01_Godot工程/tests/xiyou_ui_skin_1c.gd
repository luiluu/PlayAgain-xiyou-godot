extends Node
## 新界面第 1C 批（ui-skin-1c）专项：装备页 XSkinEquipPage、装备详情 XSkinGearDetail、检索排序（XWebPanel 换皮）、状态页 XSkinStatusPage。
## - 装备页：天启篇存档开新布局、旧窗口全藏；开页在栏位环（没有指令窗）；13 栏分两页 7＋6；列表第一行「卸下」、一屏 10 行；
##   候选行主属性与「▲／▼」；确定进列表、牌上「换上后」只列变了的；挪光标不重建列表行（卡顿）；换上、卸下、清空、Q/E 换人、取消关页；
##   Y 展开全部属性与词条（三页签、属性对比 8 行）；X 检索排序；西游存档、总开关关掉走旧页。
## - 检索排序：XWebPanel 颜色换皮（开）／原样（关）。
## - 状态页：新布局、无旧窗口与战力条；页签换页、滚动、换人、取消；内容去掉表头；西游存档走旧页。
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


func _key(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _keycode(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	return e


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_1c")
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	_pure()
	await _equip_page()
	await _search_skin()
	await _status_page()
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


## 背包里放一批第一个栏位能装的武器（游戏数据）
func _fill_gear(s: XState, a: XActor, slot: int, want := 12) -> Array:
	var out := []
	for id in range(1, 3000):
		var rec := XGear.template("weapon", id)
		if rec.is_empty() or str(rec.get("name", "")) == "" or str(rec.get("name", "")).begins_with("-"):
			continue
		if not XEquipment.fits(a, slot, rec) or XEquipment.dual_blocked(a, slot, rec):
			continue
		s.gear.append(rec)
		out.append(rec)
		if out.size() >= want:
			break
	return out


# ---- 纯函数 ----
func _pure() -> void:
	check("display_remove_first", XSkinEquipPage.to_display(4, 5) == 0 and XSkinEquipPage.to_display(0, 5) == 1 and XSkinEquipPage.to_display(3, 5) == 4)
	check("display_roundtrip", range(6).all(func(i): return XSkinEquipPage.to_display(XSkinEquipPage.to_data(i, 6), 6) == i))
	check("ring_pages_13", XSkinEquipPage.ring_pages(13) == [2, 7], XSkinEquipPage.ring_pages(13))
	check("ring_pages_10", XSkinEquipPage.ring_pages(10) == [1, 10])
	check("ring_pages_19", XSkinEquipPage.ring_pages(19) == [2, 10])
	var w := {"kind": "weapon", "wtypeId": 1, "params": [0, 0, 35, 0, 0, 0, 5, 0]}
	check("main_param_weapon_atk", XSkinEquipPage.main_param(w) == 2)
	var ar := {"kind": "armor", "params": [100, 0, 0, 12, 0, 30, 0, 0]}
	check("main_param_armor_biggest", XSkinEquipPage.main_param(ar) == 0)
	check("main_param_none", XSkinEquipPage.main_param({"params": [0, 0, 0, 0, 0, 0, 0, 0]}) == -1)
	var cur := {"kind": "weapon", "wtypeId": 1, "params": [0, 0, 12, 0, 0, 0, 0, 0]}
	check("signed", XSkinEquipPage.signed(35) == "+35" and XSkinEquipPage.signed(-4) == "-4")


# ---- 装备页 ----
func _equip_page() -> void:
	var s := _state()
	var a: XActor = s.members()[0]
	var page := XEquipScene.new()
	var closed := [0]
	page.closed.connect(func(): closed[0] += 1)
	add_child(page)
	await frames(3)
	var sk := page.skin
	if not check("equip_skin_built", sk != null):
		page.queue_free()
		return
	var view := page.slot_view()
	check("equip_old_windows_hidden", not page.cmd_win.visible and not page.list_win.visible and not page.lower_win.visible and not page.status_win.visible
		and not page.toolbar.visible and not page.gear_detail.tabs.visible)
	check("equip_starts_on_slot", page._mode == "slot" and page._slot == int(view[0]) and sk.focus == "ring" and not sk.list.active, [page._mode, page._slot])
	check("equip_view_13", view.size() == 13, view.size())
	check("equip_ring_page1", sk.ring.items.size() == 7 and int(sk.ring.items[0].key) == int(view[0]), sk.ring.items.size())
	check("equip_ring_names", str(sk.ring.items[0].name) == page.slot_name(int(view[0])))
	check("equip_layout", sk.layout.left.size.x == 384.0 and sk.layout.right.size.x == 476.0 and sk.list.visible_rows() == 10, [sk.layout.left.size, sk.layout.right.size, sk.list.visible_rows()])
	check("equip_no_power_strip", sk.currency_pairs().is_empty())
	# 把第一栏卸空再放一批候选
	a.change_level(80)
	XEquipment.change(s, a, int(view[0]), null)
	var gear := _fill_gear(s, a, int(view[0]))
	page._cand_rev += 1
	page._refresh()
	check("equip_gear_found", gear.size() >= 6, gear.size())
	var n := page.candidates().size()
	check("equip_list_rows", sk.list.items.size() == n and str(sk.list.items[0].text) == "卸下" and n >= gear.size() + 1, [sk.list.items.size(), n])
	check("equip_list_title", sk.list_title == page.slot_name(int(view[0])), sk.list_title)
	check("equip_ring_empty_orb", bool(sk.ring.items[0].empty))
	await shots("ui_skin_1c_equip_slot")
	# 环：左右走栏位，跨页
	page._unhandled_input(_key("ui_right"))
	check("equip_ring_right", page._slot == int(view[1]) and sk.ring.index == 1, [page._slot, sk.ring.index])
	for i in 6:
		page._unhandled_input(_key("ui_right"))
	check("equip_ring_page2", page._slot == int(view[7]) and sk.ring.items.size() == 6 and sk.ring.index == 0 and sk.caption().contains("第 2 / 2 页"), [page._slot, sk.ring.items.size(), sk.caption()])
	page._unhandled_input(_key("ui_left"))
	check("equip_ring_back_page1", page._slot == int(view[6]) and sk.ring.items.size() == 7 and sk.ring.index == 6)
	for i in 6:
		page._unhandled_input(_key("ui_left"))
	check("equip_ring_home", page._slot == int(view[0]))
	# 确定进列表：光标落在第一件候选（「卸下」在第一行）
	page._unhandled_input(_key("ui_accept"))
	check("equip_ok_to_list", page._mode == "item" and sk.focus == "list" and sk.list.active and page._item_index == 0 and sk.list.index == 1, [page._mode, page._item_index, sk.list.index])
	var c0: Dictionary = page.candidates()[0].rec
	var row1: Dictionary = sk.list.items[1]
	var mp := XSkinEquipPage.main_param(c0)
	check("equip_row_main_param", mp >= 0 and str(row1.right) == XSkinEquipPage.signed(XSkinEquipPage.param_of(c0, mp)), [row1.right, mp])
	check("equip_row_delta_up", str(row1.right2).begins_with("▲") or XSkinEquipPage.param_of(c0, mp) <= 0, row1.right2)
	check("equip_card_title", sk.card.title == XQuality.list_name(c0), sk.card.title)
	check("equip_card_button", sk.card.buttons.size() == 1 and sk.card.buttons[0].text == "装备")
	check("equip_card_change_section", sk.card.sections.size() >= 1 and sk.card.sections[0].title == "换上后")
	var temp := XEquipment.preview(a, page._slot, c0)
	var changed := 0
	for i in 8:
		if int(a.param(i)) != int(temp.param(i)):
			changed += 1
	var lines: Array = sk.card.sections[0].lines
	check("equip_change_only_changed", lines.size() == changed + 1, [lines.size(), changed])
	check("equip_change_rest", str(lines[-1].left) == ("能力值不变" if changed == 0 else "其余 %d 项不变" % (8 - changed)), lines[-1])
	await shots("ui_skin_1c_equip_list")
	# 挪光标不重建列表行（O-374 卡顿那次：列表一次刷新重算六七遍）
	var src = sk._rows_src
	page._unhandled_input(_key("ui_down"))
	page._unhandled_input(_key("ui_up"))
	var t0 := Time.get_ticks_usec()
	page._unhandled_input(_key("ui_down"))
	var t1 := Time.get_ticks_usec()
	check("equip_move_no_rebuild", is_same(sk._rows_src, src) and page._item_index == 1 and sk.list.index == 2, [page._item_index, sk.list.index])
	print("equip move sync us=", t1 - t0)
	page._unhandled_input(_key("ui_up"))
	page._unhandled_input(_key("ui_up"))
	check("equip_up_to_remove", page._item_index == n - 1 and sk.list.index == 0 and sk.card.title == "卸下" and sk.card.buttons[0].text == "卸下", [page._item_index, sk.list.index, sk.card.title])
	page._unhandled_input(_key("ui_down"))
	page._unhandled_input(_key("ui_down"))
	var pick: Dictionary = page._candidate()
	# Y：全部属性与词条
	page._unhandled_input(_keycode(KEY_Y))
	check("equip_y_expands", sk.expanded and sk.detail.visible and not sk.list_panel.visible and not sk.card.visible)
	# 展开时左边栏位环不收点击（小A核查 P2-3）：环忽略鼠标，就算信号来了也不换栏位、不进出候选
	var slot_before := page._slot
	check("equip_detail_ring_ignores_mouse", sk.ring.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	sk._on_ring_changed(2)
	sk._equip_ring_activated(0)
	check("equip_detail_ring_blocked", page._slot == slot_before and page._mode == "item" and sk.expanded, [page._slot, page._mode])
	check("equip_detail_hints", sk.hint_list == XSkinEquipPage.detail_hints() and sk.hint_list[-1] == ["Y / 取消", "收起"])
	check("equip_detail_rows", not sk.detail._rows.is_empty() and sk.detail.item == pick, sk.detail._rows.size())
	page._unhandled_input(_key("ui_right"))
	check("equip_detail_compare", sk.detail.tab == 1 and sk.detail._cmp.size() == 8 and sk.detail.compare, sk.detail._cmp.size())
	await shots("ui_skin_1c_equip_detail")
	page._unhandled_input(_key("ui_right"))
	check("equip_detail_socket", sk.detail.tab == 2)
	page._unhandled_input(_key("ui_cancel"))
	check("equip_detail_cancel_collapses", not sk.expanded and page._mode == "item" and sk.list_panel.visible and sk.ring.mouse_filter == Control.MOUSE_FILTER_STOP)
	# 按键提示（小A文字审 P2-2）：候选时也有「Q / E 换人」，栏位时清空写「键盘 C」
	check("equip_item_hints_qe", sk.hint_list == [["确定", "装备"], ["取消", "回栏位"], ["Y", "全部属性与词条"], ["X", "检索排序"], ["Q / E", "换人"]], sk.hint_list)
	check("equip_slot_hints_c", XSkinEquipPage.slot_hints() == [["确定", "更换"], ["取消", "返回"], ["Y", "全部属性与词条"], ["X", "检索排序"], ["键盘 C", "清空"], ["Q / E", "换人"]])
	# 换上
	page._unhandled_input(_key("ui_accept"))
	check("equip_changed", is_same(a.equips[int(view[0])], pick) and page._mode == "slot" and sk.focus == "ring", page._mode)
	check("equip_ring_icon", int(sk.ring.items[0].icon) == int(pick.get("iconIndex", 0)) and not bool(sk.ring.items[0].empty))
	check("equip_rows_rebuilt_after_change", not is_same(sk._rows_src, src))
	# 卸下
	page._unhandled_input(_key("ui_accept"))
	page._unhandled_input(_key("ui_up"))
	check("equip_on_remove_row", sk.list.index == 0 and page._candidate().is_empty())
	page._unhandled_input(_key("ui_accept"))
	check("equip_removed", not (a.equips[int(view[0])] is Dictionary and not (a.equips[int(view[0])] as Dictionary).is_empty()))
	# 再换上后 C 清空
	page._unhandled_input(_key("ui_accept"))
	page._unhandled_input(_key("ui_accept"))
	check("equip_rewear", a.equips[int(view[0])] is Dictionary and not (a.equips[int(view[0])] as Dictionary).is_empty())
	page._unhandled_input(_keycode(KEY_C))
	var left := range(a.equips.size()).filter(func(i): return XEquipment.can_change(a, i) and a.equips[i] is Dictionary and not (a.equips[i] as Dictionary).is_empty())
	check("equip_clear_all", left.is_empty(), left)
	# 鼠标：点列表第 3 行＝进列表并选中；再点＝装备
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = sk.list.cell_rect(3).get_center()
	sk.list._gui_input(click)
	var up := click.duplicate() as InputEventMouseButton
	up.pressed = false   # 收口批 TOUCH_V2：列表松手才算点
	sk.list._gui_input(up)
	check("equip_click_selects", page._mode == "item" and sk.list.index == 3 and page._item_index == 2, [page._mode, sk.list.index, page._item_index])
	page._unhandled_input(_key("ui_cancel"))
	check("equip_cancel_to_slot", page._mode == "slot" and closed[0] == 0)
	# Q/E 换人
	page._unhandled_input(_keycode(KEY_E))
	check("equip_e_switch", page.actor_index == 1 and page._mode == "slot" and page._slot == int(page.slot_view()[0]) and sk.actor_strip.members[0].name == page.actor().display_name())
	page._unhandled_input(_keycode(KEY_Q))
	check("equip_q_back", page.actor_index == 0)
	# X 检索排序
	page._unhandled_input(_keycode(KEY_X))
	await frames(2)
	check("equip_x_search", page.search_panel != null and not sk.visible, [page.search_panel, sk.visible, page._mode])
	if page.search_panel != null:
		await shots("ui_skin_1c_gear_search")
		page.search_panel.close()
		await frames(2)
		check("equip_search_closed", page.search_panel == null and sk.visible and not page.toolbar.visible)
	# 栏位上取消＝关页
	page._unhandled_input(_key("ui_cancel"))
	check("equip_cancel_closes", closed[0] == 1)
	page.queue_free()
	await frames(3)
	# 西游存档：旧页
	_state(false)
	var old := XEquipScene.new()
	add_child(old)
	await frames(2)
	check("equip_xiyou_old", old.skin == null and old.cmd_win.visible and old._mode == "command")
	old.queue_free()
	# 天启篇但总开关关掉：旧页
	_state()
	XUiSkin.ENABLED = false
	var off := XEquipScene.new()
	add_child(off)
	await frames(2)
	check("equip_switch_off_old", off.skin == null and off.cmd_win.visible and off._mode == "command")
	# 对照：旧页同样挪一格候选的用时（只打印，交付单写对比）
	var oa: XActor = XState.current.members()[0]
	oa.change_level(80)
	_fill_gear(XState.current, oa, int(off.slot_view()[0]))
	off._ok()
	off._ok()
	var o0 := Time.get_ticks_usec()
	off._move(1, true)
	print("legacy move us=", Time.get_ticks_usec() - o0)
	XUiSkin.ENABLED = true
	off.queue_free()
	await frames(2)


# ---- 检索排序换皮 ----
func _search_skin() -> void:
	_state()
	check("web_skin_text", XWebPanel.skin_color(XWebPanel.TEXT) == XUiSkin.TEXT and XWebPanel.skin_color(XWebPanel.SYSTEM) == XUiSkin.GOLD)
	check("web_skin_cursor", XWebPanel.skin_color(XWebPanel.CURSOR_EDGE) == XUiSkin.SEL_LINE)
	# 检索列表选中行：底线、悬停底色都换成新皮肤的（小A核查 P2-1）
	XGearSearch.reset_session()
	var gs := XGearSearch.new()
	gs.source = XGearQuery.collection(XState.current)
	XGearSearch.selected_key = "k1"
	var row := gs._row({"key": "k1", "item": {"name": "测试剑", "params": [0, 0, 0, 0, 0, 0, 0, 0]}, "owner": ""})
	var nb: StyleBoxFlat = row.get_theme_stylebox("normal")
	var hb: StyleBoxFlat = row.get_theme_stylebox("hover")
	check("web_search_row_line", nb.border_color == XUiSkin.SEL_LINE and hb.bg_color == Color(XUiSkin.SEL_FILL, XUiSkin.FILL_ALPHA), [nb.border_color, hb.bg_color])
	row.free()
	gs.free()
	XGearSearch.reset_session()
	check("web_skin_other_kept", XWebPanel.skin_color(Color("#123456")) == Color("#123456"))
	_state(false)
	check("web_old_kept", XWebPanel.skin_color(XWebPanel.TEXT) == XWebPanel.TEXT and XWebPanel.skin_color(XWebPanel.SYSTEM) == XWebPanel.SYSTEM)


# ---- 状态页 ----
func _status_page() -> void:
	var s := _state()
	var page := XStatusPage.new()
	var closed := [0]
	page.closed.connect(func(): closed[0] += 1)
	add_child(page)
	await frames(3)
	var sk := page.skin
	if not check("status_skin_built", sk != null):
		page.queue_free()
		return
	check("status_no_old_windows", page.page_win == null and page.select_win == null and page.power_strip == null and page.power_button == null)
	check("status_layout", sk.page_panel.size.x > 800.0 and sk.list_panel.visible == false and sk.card.visible == false, sk.page_panel.size)
	check("status_rows_fit_page0", sk.visible_rows() >= 13 and page.max_top() == 0, [sk.visible_rows(), page.max_top()])
	var ops := XSkinStatusPage.body_ops(page.actor(), 0)
	check("status_body_no_header", not ops.is_empty() and ops.all(func(o): return o[0] != "face" and (float(o[3]) if o[0] in ["text", "icon"] else float(o[2])) >= XStatusPage.LH * XStatusPage.HEADER_LINES))
	check("status_skin_color", XSkinStatusPage.skin_color("#" + XUI.SYSTEM.to_html(false)) == XUiSkin.TEXT_2)
	await shots("ui_skin_1c_status_p0")
	page._unhandled_input(_key("ui_right"))
	check("status_right_page", page.page == 1)
	await shots("ui_skin_1c_status_p1")
	# 找一页内容超一屏的，往下滚
	var scrolled := false
	for p in XStatusPage.page_names().size():
		page.set_page(p)
		if page.max_top() > 0:
			page._unhandled_input(_key("ui_down"))
			scrolled = page.tops[p] == 1
			page._unhandled_input(_key("ui_up"))
			break
	check("status_scroll_or_fit", scrolled or range(XStatusPage.page_names().size()).all(func(p): return XSkinStatusPage.content_rows(page.actor(), p) <= sk.visible_rows()))
	page.set_page(0)
	page._unhandled_input(_keycode(KEY_E))
	check("status_e_switch", page.actor_index == 1 and page.skin == sk)
	# 点页签
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = sk.tab_rect(2).get_center()
	sk._on_page_gui(click)
	check("status_click_tab", page.page == 2)
	page._unhandled_input(_key("ui_cancel"))
	check("status_cancel", closed[0] == 1)
	page.queue_free()
	await frames(3)
	_state(false)
	var old := XStatusPage.new()
	add_child(old)
	await frames(2)
	check("status_xiyou_old", old.skin == null and old.page_win != null)
	old.queue_free()
	await frames(2)
