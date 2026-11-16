extends Node
## T024 全局选中放大（cc/select-scale）专项：XSkinSelScale 的过渡／动效关／首开直接放大／总开关，
## 各控件接线（直列表、战斗技能表、战斗指令球、页签条、角色条、给谁用、详情牌按钮、状态页与装备详情页签、主菜单子项、
## 新皮肤按钮、旧 MV 页光标行），不重叠／不出界／130% 字号不顶行，皮肤关时 MV 画布不放大。
## 带 -- --out=<目录> 且有窗口时出截图：每页一张放大开（sel）一张关（off）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []
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


func _run() -> void:
	TestEnv.isolate("xiyou_ui_sel_scale")
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XUiSkin.touch_override = 0
	_core()
	await _list()
	_battle_parts()
	await _strips()
	await _card_and_button()
	await _pages()
	await _fill()
	await _mv_canvas()
	await _font130()
	if windowed():
		await _shots()
	XSkinSelScale.ENABLED = true
	XFontScale.set_value("global", 100)
	XUiSkin.touch_override = -1
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XState.current = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(line := "war") -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian", "line": line}
	s.map_id = 1
	s.gold = 12480
	for id in range(1, 40):
		var rec := XDB.rec("Items", id)
		if not rec.is_empty() and str(rec.get("name", "")) != "" and not str(rec.get("name", "")).begins_with("-"):
			s.gain_item(id, 3)
	for id in range(1, 30):
		var rec := XDB.rec("Weapons", id)
		if not rec.is_empty() and str(rec.get("name", "")) != "" and not str(rec.get("name", "")).begins_with("-"):
			s.gain_gear("weapons", id, 1)
	return s


func _key(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


# ---- 公共实现 ----
func _core() -> void:
	var host := Control.new()
	add_child(host)
	var s := XSkinSelScale.attach(host)
	check("core_attached_internal", s.get_parent() == host and host.get_child_count() == 0)
	check("core_peak_default", is_equal_approx(s.peak, XUiSkin.SEL_SCALE) and s.peak >= 1.05 and s.peak <= 1.15)
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	s.sel(0)
	check("core_first_open_instant", is_equal_approx(s.k(0), s.peak), s.k(0))
	s.sel(1)
	check("core_new_starts_at_1", is_equal_approx(s.k(1), 1.0) and is_equal_approx(s.k(0), s.peak))
	s.advance(0.06)
	var mid1 := s.k(1)
	var mid0 := s.k(0)
	check("core_mid_transition", mid1 > 1.02 and mid1 < s.peak - 0.02 and mid0 < s.peak - 0.02 and mid0 > 1.02, [mid1, mid0])
	check("core_animating", s.animating())
	s.advance(0.1)
	check("core_done", is_equal_approx(s.k(1), s.peak) and is_equal_approx(s.k(0), 1.0) and not s.animating(), [s.k(1), s.k(0)])
	s.sel(null)
	s.advance(0.2)
	check("core_none_selected", is_equal_approx(s.k(1), 1.0))
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	s.sel(2)
	check("core_motion_off_instant", is_equal_approx(s.k(2), s.peak) and is_equal_approx(s.k(1), 1.0))
	XSkinSelScale.ENABLED = false
	check("core_switch_off", is_equal_approx(s.k(2), 1.0))
	XSkinSelScale.ENABLED = true
	var s2 := XSkinSelScale.attach(host, 1.08)
	s2.sel(3)
	check("core_custom_peak", is_equal_approx(s2.k(3), 1.08))
	check("core_fs_cap", XSkinSelScale.fs(19, 1.15) == 22 and XSkinSelScale.fs(25, 1.15, 27) == 27 and XSkinSelScale.fs(30, 1.15, 27) == 30)
	check("core_grow", XSkinSelScale.grow(Rect2(10, 10, 20, 20), 1.5) == Rect2(5, 5, 30, 30))
	host.queue_free()


# ---- 直列表 ----
func _list() -> void:
	var l := XSkinList.new()
	l.size = Vector2(420, 300)
	add_child(l)
	var arr := []
	for i in 8:
		arr.append({"text": "一个名字相当长的物品第%d号" % i, "icon": 1, "right": "×99"})
	l.set_items(arr)
	l.select(2)
	await frames(2)
	check("list_selected_scaled", is_equal_approx(l.sel_scale.k(2), XUiSkin.SEL_SCALE) and is_equal_approx(l.sel_scale.k(0), 1.0))
	l.active = false
	await frames(2)
	check("list_inactive_no_scale", is_equal_approx(l.sel_scale.k(2), 1.0))
	l.active = true
	await frames(2)
	# 选中名字的字号：行高 0.6 封顶，放大后名字仍按本行余宽缩字（不压右列）
	var body := XUiSkin.font("body")
	var fit := XSkinList.fit_text(body, str(arr[2].text), 200.0, XSkinSelScale.fs(l.font_size, XUiSkin.SEL_SCALE, l.sel_font_cap()), l.min_font_size)
	check("list_fit_within", body.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x <= 200.0, fit)
	check("list_font_cap", XSkinSelScale.fs(l.font_size, XUiSkin.SEL_SCALE, l.sel_font_cap()) <= floori(l.row_height * 0.6))
	l.queue_free()


# ---- 战斗：技能表、指令球 ----
func _battle_parts() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var entries := []
	for i in 6:
		entries.append({"text": "战技%d" % i, "icon": 0, "enabled": true})
	var lw := XSkinBattleSkillList.create_list(host, entries, "战技")
	lw.select(1)
	lw.queue_redraw()
	check("battle_list_has_scale", lw.sel_scale != null)
	for n in range(2, 17):
		var opts := []
		for i in n:
			opts.append({"text": "指令%d" % i, "key": "k%d" % i})
		var ring := XSkinBattleRing.create_ring(host, opts, "测试")
		var apart := true
		for i in n:
			var j := (i + 1) % n
			if j == 0 and n < 10:
				continue
			# 选中的球放大到 SEL_PEAK 也不和邻球相叠
			apart = apart and ring.orb_pos(i).distance_to(ring.orb_pos(j)) >= ring.orb_r * (1.0 + XSkinBattleRing.SEL_PEAK) - 0.01
		check("battle_ring_apart_%d" % n, apart, [n, ring.radius, ring.orb_r])
		if n == 6:
			check("battle_ring_sel_peak", is_equal_approx(ring.orb_scale(0), XSkinBattleRing.SEL_PEAK) and is_equal_approx(ring.orb_scale(1), 1.0))
			XSkinSelScale.ENABLED = false
			check("battle_ring_switch_off_old", is_equal_approx(ring.orb_scale(0), 1.08) and is_equal_approx(ring.orb_scale(1), 1.0))
			XSkinSelScale.ENABLED = true
		ring.free()
	host.queue_free()


# ---- 页签条、角色条、给谁用 ----
func _strips() -> void:
	_state()
	var tabs := XSkinTabStrip.new()
	add_child(tabs)
	tabs.set_groups()
	tabs.select(1)
	await frames(2)
	var f := XUiSkin.font("body")
	var ok := true
	for i in tabs.groups.size():
		var fs := XSkinSelScale.fs(tabs.font_size, XUiSkin.SEL_SCALE)
		var tw := f.get_string_size(str(tabs.groups[i].name), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ok = ok and tw <= tabs.tab_rect(i).size.x   # 放大的字仍在自己页签里，不进邻签
	check("tabs_scaled_fit", ok)
	check("tabs_selected_scaled", is_equal_approx(tabs.sel_scale.k(1), XUiSkin.SEL_SCALE) and is_equal_approx(tabs.sel_scale.k(0), 1.0))
	tabs.queue_free()
	var ps := XSkinPartyStrip.new()
	ps.size = Vector2(320, 260)
	add_child(ps)
	ps.members = XState.current.party.map(func(id): return XSkinPartyStrip.from_actor(XState.current.actor(id)))
	ps.selectable = false
	ps.queue_redraw()
	await frames(2)
	check("party_not_selectable_no_scale", is_equal_approx(ps.sel_scale.k(0), 1.0))
	ps.selectable = true
	ps.select(0)
	ps.queue_redraw()
	await frames(2)
	check("party_selectable_scaled", is_equal_approx(ps.sel_scale.k(ps.index), XUiSkin.SEL_SCALE))
	# 头像放大后仍在行里、不压名字
	var hr := XSkinPartyStrip.HEAD / 2.0 * XUiSkin.SEL_SCALE
	check("party_head_fits", hr * 2.0 <= XUiSkin.MEMBER_H and 14 + XSkinPartyStrip.HEAD / 2.0 + hr <= 14 + XSkinPartyStrip.HEAD + 12)
	ps.queue_free()
	var tl := XSkinTargetList.new()
	tl.size = Vector2(300, 200)
	add_child(tl)
	tl.rows = [{"name": "甲", "cur": 10, "max": 20}, {"name": "乙", "cur": 5, "max": 20}]
	tl.selectable = true
	tl.queue_redraw()
	await frames(2)
	check("target_selected_scaled", is_equal_approx(tl.sel_scale.k(tl.index), XUiSkin.SEL_SCALE))
	tl.all = true
	tl.queue_redraw()
	await frames(2)
	check("target_all_no_scale", is_equal_approx(tl.sel_scale.k(tl.index), 1.0))
	check("target_head_fits", XSkinTargetList.HEAD * XUiSkin.SEL_SCALE <= XSkinTargetList.ROW_H - 4)
	tl.queue_free()


# ---- 详情牌按钮、新皮肤按钮 ----
func _card_and_button() -> void:
	var card := XSkinCard.new()
	card.size = Vector2(336, 400)
	add_child(card)
	card.buttons = [{"text": "使用", "primary": true}, {"text": "丢弃"}]
	card.button_index = 0
	card.queue_redraw()
	await frames(2)
	check("card_button_scaled", is_equal_approx(card.sel_scale.k(0), XUiSkin.SEL_SCALE) and is_equal_approx(card.sel_scale.k(1), 1.0))
	card.button_index = -1
	card.queue_redraw()
	await frames(2)
	check("card_no_focus_no_scale", is_equal_approx(card.sel_scale.k(0), 1.0))
	card.queue_free()
	var box := HBoxContainer.new()
	add_child(box)
	var b1 := Button.new()
	b1.text = "重抽"
	var b2 := Button.new()
	b2.text = "分解"
	box.add_child(b1)
	box.add_child(b2)
	XSkinButton.apply(b1)
	XSkinButton.apply(b2)
	await frames(2)
	b1.grab_focus()
	await frames(2)
	check("button_focus_scaled", is_equal_approx(b1.scale.x, XSkinButton.BUTTON_PEAK) and is_equal_approx(b2.scale.x, 1.0), [b1.scale, b2.scale])
	check("button_pivot_center", b1.pivot_offset.is_equal_approx(b1.size / 2.0))
	var pos2 := b2.position
	b2.grab_focus()
	await frames(2)
	check("button_focus_moves", is_equal_approx(b1.scale.x, 1.0) and is_equal_approx(b2.scale.x, XSkinButton.BUTTON_PEAK) and b2.position == pos2, [b1.scale, b2.scale])
	# 放大只是画面缩放：两钮之间放大后不相叠（容器间距 ≥ 两边各多出的一半）
	var grow := b2.size.x * (XSkinButton.BUTTON_PEAK - 1.0) / 2.0
	check("button_no_overlap", b2.position.x - grow >= b1.position.x + b1.size.x, [b1.position, b1.size, b2.position, grow])
	XSkinSelScale.ENABLED = false
	b1.grab_focus()
	await frames(2)
	check("button_switch_off", is_equal_approx(b1.scale.x, 1.0))
	XSkinSelScale.ENABLED = true
	box.queue_free()


# ---- 页面接线 ----
func _pages() -> void:
	# 主菜单子项
	_state()
	var menu := XMenu.new()
	add_child(menu)
	await frames(4)
	if check("menu_skin", menu.skin != null):
		var sk = menu.skin
		sk.level = 0
		sk._set_group(2, 0)
		sk.enter()
		sk._set_group(2, 1)
		await frames(3)
		check("menu_item_scaled", is_equal_approx(sk.item_scale.k("%d:%d" % [sk.gi, sk.ii]), XUiSkin.SEL_SCALE), sk.item_scale.selected())
		check("menu_item_fs_fits_row", XSkinSelScale.fs(XUiSkin.FS_LIST_MAX, XUiSkin.SEL_SCALE, floori(XSkinMainMenu.ROW_ITEM * 0.62)) <= XSkinMainMenu.ROW_ITEM * 0.62)
		check("menu_ring_scaled", is_equal_approx(sk.ring.item_scale(sk.ring.index), XUiSkin.SEL_SCALE))
	menu.queue_free()
	await frames(3)
	# 物品页：分类环＋直列表
	_state("plague")
	var items := XItemScene.new()
	add_child(items)
	await frames(4)
	items._unhandled_input(_key("ui_accept"))
	await frames(3)
	var lists := _all(items, func(n): return n is XSkinList)
	var any_on := lists.any(func(l): return l.active and is_equal_approx(l.sel_scale.k(l.index), XUiSkin.SEL_SCALE))
	check("items_list_scaled", any_on, lists.size())
	items.queue_free()
	await frames(3)
	# 状态页页签
	_state()
	var st := XStatusPage.new()
	add_child(st)
	await frames(3)
	if check("status_skin", st.skin != null):
		check("status_tab_scaled", is_equal_approx(st.skin.tab_scale.k(st.page), XUiSkin.SEL_SCALE))
	st.queue_free()
	await frames(3)


func _all(n: Node, pred: Callable, out: Array = []) -> Array:
	for c in n.get_children(true):
		if pred.call(c):
			out.append(c)
		_all(c, pred, out)
	return out


# ---- 旧 MV 页（图鉴、商店……）的光标行 ----
func _mv_canvas() -> void:
	var c := XMVCanvas.new()
	c.size = Vector2(400, 200)
	add_child(c)
	var row := Rect2(0, 36, 400, 36)
	c._sel_rect = Rect2()
	c._mark_sel(row)
	check("mv_sel_in_row", is_equal_approx(c.sel_k_at(Vector2(10, 50)), XMVCanvas.SEL_PEAK))
	check("mv_sel_other_row", is_equal_approx(c.sel_k_at(Vector2(10, 10)), 1.0))
	# 皮肤关：不登记、不放大
	XUiSkin.FORCE = false
	XUiSkin.ENABLED = false
	var c2 := XMVCanvas.new()
	add_child(c2)
	c2._mark_sel(row)
	check("mv_skin_off_no_scale", is_equal_approx(c2.sel_k_at(Vector2(10, 50)), 1.0))
	XUiSkin.ENABLED = true
	XUiSkin.FORCE = true
	# 总开关关
	XSkinSelScale.ENABLED = false
	var c3 := XMVCanvas.new()
	add_child(c3)
	c3._mark_sel(row)
	check("mv_switch_off", is_equal_approx(c3.sel_k_at(Vector2(10, 50)), 1.0))
	XSkinSelScale.ENABLED = true
	# 动效开：换行时从 1 长到位
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	var c4 := XMVCanvas.new()
	add_child(c4)
	c4._mark_sel(row)
	check("mv_first_open_instant", is_equal_approx(c4.sel_k_at(Vector2(10, 50)), XMVCanvas.SEL_PEAK))
	c4._mark_sel(Rect2(0, 72, 400, 36))
	check("mv_new_row_starts_1", is_equal_approx(c4.sel_k_at(Vector2(10, 80)), 1.0))
	c4._process(0.2)
	check("mv_new_row_grows", is_equal_approx(c4.sel_k_at(Vector2(10, 80)), XMVCanvas.SEL_PEAK))
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	# 图鉴页真画一次：活动光标行登记上了
	_state()
	var book := XEnemyBookPage.new()
	add_child(book)
	await frames(4)
	var canv := _all(book, func(n): return n is XMVCanvas and (n as XMVCanvas)._sel_rect.has_area())
	check("enemy_book_cursor_row_marked", canv.size() >= 1)
	book.queue_free()
	for n in [c, c2, c3, c4]:
		n.queue_free()
	await frames(2)


# ---- T040 补齐：状态页分类页签、七印祭坛按钮、选线竖卡、工坊顶页签、角标、环导航总开关 ----
func _fill() -> void:
	# 队伍状态页分类页签
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	var lg := XBattleLogic.new()
	lg.elite_roll = 100.0
	lg.setup(2, s)
	var root := Control.new()
	root.size = Vector2(1280, 720)
	add_child(root)
	var sp := XSkinPartyStatusPanel.new()
	sp.members = lg.actors.filter(func(m): return m is XActor)
	root.add_child(sp)
	await frames(4)
	check("party_tab_scaled", is_equal_approx(sp.tab_scale.k(sp.tab), XUiSkin.SEL_SCALE) and is_equal_approx(sp.tab_scale.k("异常" if sp.tab != "异常" else "增益"), 1.0), [sp.tab, sp.tab_scale.selected()])
	sp.step_tab(1)
	await frames(3)
	check("party_tab_moves", is_equal_approx(sp.tab_scale.k(sp.tab), XUiSkin.SEL_SCALE), sp.tab)
	XSkinSelScale.ENABLED = false
	check("party_tab_switch_off", is_equal_approx(sp.tab_scale.k(sp.tab), 1.0))
	XSkinSelScale.ENABLED = true
	root.queue_free()
	await frames(2)
	# 七印祭坛底部按钮
	var ts := _ws_state()
	XTianqiQiyin.sync(ts)
	var alt := XTianqiSkinAltar.new()
	alt.setup(ts, XTianqiQiyin.altar_options(ts))
	add_child(alt)
	await frames(4)
	check("altar_button_scaled", alt.buttons.size() >= 1 and is_equal_approx(alt.btn_scale.k(alt.button), XSkinButton.BUTTON_PEAK), [alt.buttons.size(), alt.button])
	if alt.buttons.size() >= 2:
		alt.handle_input(_key("ui_down"))
		await frames(3)
		check("altar_button_moves", is_equal_approx(alt.btn_scale.k(alt.button), XSkinButton.BUTTON_PEAK) and is_equal_approx(alt.btn_scale.k(0), 1.0), alt.button)
	XSkinSelScale.ENABLED = false
	check("altar_button_switch_off", is_equal_approx(alt.btn_scale.k(alt.button), 1.0))
	XSkinSelScale.ENABLED = true
	alt.queue_free()
	await frames(2)
	# 选线竖卡
	var lc := XTianqiLineCards.new()
	lc.lines = XTianqi.LINES
	lc.playable = [true, true, true, true]
	add_child(lc)
	await frames(3)
	var picked: Control = lc._cards[lc.index]
	check("line_card_scaled", is_equal_approx(picked.scale.x, XTianqiLineCards.CARD_PEAK) and lc._cards.filter(func(k): return k != picked).all(func(k): return is_equal_approx(k.scale.x, 1.0)), picked.scale)
	check("line_card_pivot_center", picked.pivot_offset.is_equal_approx(XTianqiLineCards.CARD / 2.0))
	var gap: float = lc._cards[1].position.x - lc._cards[0].position.x - XTianqiLineCards.CARD.x
	check("line_card_no_overlap", XTianqiLineCards.CARD.x * (XTianqiLineCards.CARD_PEAK - 1.0) / 2.0 < gap, gap)
	check("line_back_hover_wired", lc._back.has_meta("skin_hover_scale_wired"))
	XSkinSelScale.ENABLED = false
	lc._highlight()
	check("line_card_switch_off", is_equal_approx(picked.scale.x, 1.0))
	XSkinSelScale.ENABLED = true
	lc.queue_free()
	await frames(2)
	# 工坊：当前页签放大、左列滚动容器给放大外扩留了余量
	_ws_state()
	XAlienWorkshop.selected = ""
	var ws := XAlienWorkshop.new()
	add_child(ws)
	await frames(4)
	var strips := _all(ws, func(n): return n.name == "SkinTabs")
	if check("workshop_tabs", not strips.is_empty()):
		var tbs := (strips[0] as Node).get_children().filter(func(n): return n is Button)
		check("workshop_tab_scaled", tbs.size() > 1 and is_equal_approx(tbs[ws.skin_tab].scale.x, XSkinButton.BUTTON_PEAK) and tbs.filter(func(b): return b != tbs[ws.skin_tab]).all(func(b): return is_equal_approx(b.scale.x, 1.0)), tbs.map(func(b): return b.scale.x))
	var lists := _all(ws, func(n): return n.name == "SkinList")
	if lists.is_empty():
		ws.skin_switch(1)   # 默认页签不是列表页时切过去
		await frames(3)
		lists = _all(ws, func(n): return n.name == "SkinList")
	if check("workshop_list", not lists.is_empty()):
		var scs := _all(lists[0], func(n): return n is ScrollContainer)
		var mcs: Array = scs[0].get_children().filter(func(n): return n is MarginContainer) if not scs.is_empty() else []
		check("workshop_scroll_margin", not mcs.is_empty() and (mcs[0] as MarginContainer).get_theme_constant("margin_left") == XAlienWorkshop.SCALE_ROOM)
		var btns := _all(lists[0], func(n): return n is Button and n.focus_mode != Control.FOCUS_NONE)
		var worst := 0.0
		for b in btns:
			worst = maxf(worst, (b as Control).size.x * (XSkinButton.BUTTON_PEAK - 1.0) / 2.0)
		check("workshop_scale_fits_room", worst <= XAlienWorkshop.SCALE_ROOM, worst)
	ws.queue_free()
	await frames(2)
	# 「新」角标跟选中行放大（仓库、物品列表）
	var c := XMVCanvas.new()
	add_child(c)
	var tex_sz := Vector2(16, 16)
	check("tex_rect_plain", c.tex_rect(Vector2(2, 38), tex_sz) == Rect2(Vector2(2, 38), tex_sz))
	c._mark_sel(Rect2(0, 36, 400, 36))
	var br := c.tex_rect(Vector2(2, 38), tex_sz)
	check("tex_rect_selected_grows", br.size.x > tex_sz.x and is_equal_approx(br.get_center().x, 10.0) and is_equal_approx(br.get_center().y, 46.0), br)
	check("tex_rect_other_row", c.tex_rect(Vector2(2, 2), tex_sz).size == tex_sz)
	XSkinSelScale.ENABLED = false
	var c2 := XMVCanvas.new()
	add_child(c2)
	c2._mark_sel(Rect2(0, 36, 400, 36))
	check("tex_rect_switch_off", c2.tex_rect(Vector2(2, 38), tex_sz).size == tex_sz)
	XSkinSelScale.ENABLED = true
	c.queue_free()
	c2.queue_free()
	# 环导航挂 XSkinSelScale.ENABLED 总开关
	var ring := XSkinRingNav.new()
	ring.items = [{"text": "甲"}, {"text": "乙"}]
	ring.index = 0
	check("ring_scaled_on", is_equal_approx(ring.item_scale(0), XUiSkin.SEL_SCALE) and is_equal_approx(ring.item_scale(1), 1.0))
	XSkinSelScale.ENABLED = false
	check("ring_switch_off", is_equal_approx(ring.item_scale(0), 1.0))
	ring._ease_scales(0.05)
	check("ring_switch_off_steady", is_equal_approx(ring.item_scale(0), 1.0))
	XSkinSelScale.ENABLED = true
	ring.free()


# ---- 130% 字号 ----
func _font130() -> void:
	XFontScale.set_value("global", 130)
	var l := XSkinList.new()
	check("font130_list_cap", XSkinSelScale.fs(l.font_size, XUiSkin.SEL_SCALE, l.sel_font_cap()) <= floori(XUiSkin.ROW_H * 0.6), [l.font_size])
	check("font130_battle_cap", XSkinSelScale.fs(XUiSkin.FS_LIST, XUiSkin.SEL_SCALE, floori(XSkinBattleSkillList.ROW_H * 0.6)) <= XSkinBattleSkillList.ROW_H * 0.6)
	l.free()
	XFontScale.set_value("global", 100)


# ---- 截图（每页：放大开 sel／关 off）----
func _shots() -> void:
	get_window().size = Vector2i(1280, 720)
	await frames(6)
	for page in ["menu", "items", "equip", "status", "options", "workshop", "enemybook", "battle", "party", "altar", "cards", "wstab"]:
		for on in [true, false]:
			XSkinSelScale.ENABLED = on
			var node: Node = await call("_shot_" + page)
			await frames(8)
			await _save_shot("%s_%s" % [page, "sel" if on else "off"])
			node.queue_free()
			await frames(3)
	XSkinSelScale.ENABLED = true
	XFontScale.set_value("global", 130)
	for page in ["items", "menu"]:
		var node: Node = await call("_shot_" + page)
		await frames(8)
		await _save_shot("%s_font130" % page)
		node.queue_free()
		await frames(3)
	XFontScale.set_value("global", 100)


func _save_shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_dir)
	check("shot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)


func _shot_menu() -> Node:
	_state()
	var menu := XMenu.new()
	add_child(menu)
	await frames(4)
	if menu.skin != null:
		menu.skin.level = 0
		menu.skin._set_group(2, 0)
		menu.skin.enter()
		menu.skin._set_group(2, 1)
	return menu


func _shot_items() -> Node:
	_state("plague")
	var page := XItemScene.new()
	add_child(page)
	await frames(4)
	page._unhandled_input(_key("ui_accept"))
	await frames(2)
	page._unhandled_input(_key("ui_down"))
	return page


func _shot_equip() -> Node:
	_state()
	var page := XEquipScene.new()
	add_child(page)
	await frames(4)
	for i in 2:
		page._unhandled_input(_key("ui_down"))
	page._unhandled_input(_key("ui_accept"))
	await frames(2)
	page._unhandled_input(_key("ui_down"))
	return page


func _shot_status() -> Node:
	_state()
	var page := XStatusPage.new()
	add_child(page)
	await frames(3)
	page._unhandled_input(_key("ui_right"))
	return page


func _shot_options() -> Node:
	_state()
	var page := XOptionsScene.new()
	add_child(page)
	await frames(3)
	page._unhandled_input(_key("ui_accept"))
	await frames(2)
	page._unhandled_input(_key("ui_down"))
	return page


func _ws_state() -> XState:   # 同 xiyou_ui_skin_3b：有一件异化装备、一枚核，列表不空
	var ids := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 4)
	var s := XTianqi.start_new_game(3, "jianxian", ids)
	XTianqi.take_pending()
	for id in ids:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	XState.current = s
	s.flags.tianqi["line"] = "plague"
	s.gain_item(XAlienation.stone_id(), 3)
	s.gear.append(XTianqiAlienGear.create(s, "armor", 52, "plague", "huaxing", "mimic").ok)
	XTianqiAlienGear.add_core(s, "plague", "insulation", "shigu", "test")
	s.gain_gear("armor", 53, 1)
	return s


func _shot_workshop() -> Node:
	_ws_state()
	XAlienWorkshop.selected = ""
	var page := XAlienWorkshop.new()
	add_child(page)
	await frames(4)
	var lst: Node = _all(page, func(n): return n.name == "SkinList").front() if not _all(page, func(n): return n.name == "SkinList").is_empty() else page
	var btn := _all(lst, func(n): return n is Button and n.is_visible_in_tree() and n.focus_mode != Control.FOCUS_NONE)
	if not btn.is_empty():
		(btn[0] as Button).grab_focus()
	return page


func _shot_enemybook() -> Node:
	_state()
	var page := XEnemyBookPage.new()
	add_child(page)
	await frames(4)
	page.select(2)
	return page


func _shot_battle() -> Node:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var bg := ColorRect.new()
	bg.color = XUiSkin.BG
	bg.size = host.size
	host.add_child(bg)
	var opts := []
	for t in ["攻击", "战技", "防御", "物品", "逃跑", "自动"]:
		opts.append({"text": t, "key": t})
	var ring := XSkinBattleRing.create_ring(host, opts, "测试")
	ring.place_for_actor(Vector2(1000, 430), XBattleScene.BOX)
	ring.select(1)
	var entries := []
	for i in 6:
		entries.append({"text": "战技第%d式" % i, "icon": 64 + i, "enabled": i != 4, "reason": "冷却" if i == 4 else ""})
	var lw := XSkinBattleSkillList.create_list(host, entries, "战技")
	lw.position = Vector2(120, 120)
	lw.select(2)
	return host


func _shot_party() -> Node:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8, 9])
	XState.current = s
	var lg := XBattleLogic.new()
	lg.elite_roll = 100.0
	lg.setup(2, s)
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var bg := ColorRect.new()
	bg.color = XUiSkin.BG
	bg.size = host.size
	host.add_child(bg)
	var sp := XSkinPartyStatusPanel.new()
	sp.members = lg.actors.filter(func(m): return m is XActor)
	host.add_child(sp)
	await frames(4)
	sp.step_tab(1)
	return host


func _shot_altar() -> Node:
	var ts := _ws_state()
	XTianqiQiyin.sync(ts)
	var alt := XTianqiSkinAltar.new()
	alt.setup(ts, XTianqiQiyin.altar_options(ts))
	add_child(alt)
	await frames(4)
	return alt


func _shot_cards() -> Node:
	_ws_state()
	var lc := XTianqiLineCards.new()
	lc.lines = XTianqi.LINES
	lc.playable = [true, true, true, true]
	add_child(lc)
	await frames(3)
	lc._handle(_key("ui_right"))
	return lc


func _shot_wstab() -> Node:
	_ws_state()
	XAlienWorkshop.selected = ""
	var page := XAlienWorkshop.new()
	add_child(page)
	await frames(4)
	return page
