extends Node
## T361 专项：页面级去网页味（界面审 F-06／F-07／F-08／F-09／F-13）。
## - F-06 装备检索（新皮肤）：没有「关闭 · Esc」框、六个下拉都收在「筛选」面板里（默认收起、取消先关面板）、
##   搜索条聚焦 1px、词条卡没有左竖条、没有开发腔文案；回退 SKIN_PAGE_V2 = false 回到旧排法。
## - F-07 更新页／更新说明页：暖炭底 1px 旧金细线、内边距在 8 的网格上；回退 FRAME_V2 = false 回到深紫蓝 2px。
## - F-08 异化工坊：操作栏只有 1 个实心主按钮、分解／取核在右边隔开；页签不再用红乙选中条；右上没有「返回」框、页名前有「‹」；
##   左下说明按 XSkinText 折行（末行不止一个字）。
## - F-09 地图横幅：难度胶囊、地名横幅的底在纯白上，字对比度 ≥ 4.5:1；淡入一半时字还没出。
## - F-13 成就旧弹窗：新皮肤没开时弹出的旧弹窗，新皮肤一开就转进提示道并移除（不同屏两份），提示道里不带叹号。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func pframes(n := 2) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _tq_state(line := "") -> XState:
	var ids := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 4)
	var s := XTianqi.start_new_game(3, "jianxian", ids)
	XTianqi.take_pending()
	for id in ids:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
	return s


func _all(n: Node, pred: Callable, out := []) -> Array:
	for c in n.get_children():
		if pred.call(c):
			out.append(c)
		_all(c, pred, out)
	return out


static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


## 底色 bg（带 a）叠在 under 上，字色 fg 在上面的对比度
static func contrast(fg: Color, bg: Color, under := Color.WHITE) -> float:
	var b := under.lerp(Color(bg.r, bg.g, bg.b), bg.a)
	var l1 := _lum(fg)
	var l2 := _lum(b)
	return (maxf(l1, l2) + 0.05) / (minf(l1, l2) + 0.05)


func _run() -> void:
	TestEnv.isolate("xiyou_t361_unslop")
	XConfig.ensure_loaded()
	XConfig._values["codexUiSkin"] = true
	XUiSkin.ENABLED = true
	await _gear_search()
	await _update_pages()
	await _workshop()
	_map_banners()
	await _map_fade()
	await _achievement()
	XState.current = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- F-06 ----
func _gear_search() -> void:
	var s := _tq_state()
	s.gain_gear("weapon", 5, 1)
	s.gain_gear("armor", 2, 1)
	check("gear_skin_on", XUiSkin.on())
	XGearSearch.reset_session()
	XGearSearch.filters_open = false
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var gs := XGearSearch.open(host, XGearQuery.collection(s))
	await frames(4)
	var buttons := _all(gs, func(c): return c is Button and not (c is OptionButton))
	var texts := buttons.map(func(b): return (b as Button).text)
	check("gear_no_close_box", not texts.any(func(t): return t.contains("关闭")), texts)
	var labels := _all(gs, func(c): return c is Label).map(func(l): return (l as Label).text)
	check("gear_no_dev_copy", not labels.any(func(t): return t.contains("真实效果") or t.contains("不改变装备") or t.contains("读取")), labels)
	var opts := _all(gs, func(c): return c is OptionButton)
	check("gear_selects_in_panel", opts.size() == 6 and opts.all(func(o): return gs._filter_panel.is_ancestor_of(o)), opts.size())
	check("gear_panel_closed", not gs._filter_panel.visible and gs._filter_btn.text == "筛选")
	var fp: StyleBoxFlat = gs._filter_panel.get_theme_stylebox("panel")
	check("gear_panel_solid", fp != null and fp.bg_color.a >= 0.94, fp.bg_color if fp else null)
	var sf: StyleBoxFlat = gs._search.get_theme_stylebox("focus")
	check("gear_search_focus_thin", sf.border_width_left == 1 and sf.border_color.is_equal_approx(Color(XUiSkin.GOLD, 0.7)), [sf.border_width_left, sf.border_color])
	var card: Control = XGearSearch.skin_card("攻击速度+3", "固定 · 行动")
	var pc: PanelContainer = card.get_child(0)
	var cs: StyleBoxFlat = pc.get_theme_stylebox("panel")
	check("gear_card_no_left_bar", cs.border_width_left == cs.border_width_right and cs.border_width_left == 1)
	card.free()
	check("gear_hints", gs._hints != null and gs._hints.hints.any(func(h): return h[0] == "取消"))
	gs._toggle_filters()
	check("gear_panel_open", gs._filter_panel.visible and gs._filter_btn.text == "收起筛选")
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	gs._input(ev)
	await frames(2)
	check("gear_cancel_closes_panel_first", is_instance_valid(gs) and not gs.is_queued_for_deletion() and not gs._filter_panel.visible)
	# 条件数写在钮上
	XGearSearch.filter.quality = "4"
	gs._render_results()
	check("gear_filter_count", gs._filter_btn.text == "筛选 · 1", gs._filter_btn.text)
	host.queue_free()
	await frames(2)
	# 回退
	XGearSearch.SKIN_PAGE_V2 = false
	XGearSearch.reset_session()
	host = Control.new()
	add_child(host)
	gs = XGearSearch.open(host, XGearQuery.collection(s))
	await frames(3)
	var t2 := _all(gs, func(c): return c is Button).map(func(b): return (b as Button).text)
	check("gear_rollback_close_box", t2.has("关闭 · Esc") and gs._filter_panel == null, t2)
	XGearSearch.SKIN_PAGE_V2 = true
	host.queue_free()
	XGearSearch.reset_session()
	await frames(2)


# ---- F-07 ----
func _update_pages() -> void:
	XState.current = null
	var st := XUpdatePage.frame_style()
	check("update_frame_warm", st.bg_color.is_equal_approx(Color(XSkinConfirm.DLG_LOW, 0.98)) and st.border_width_left == 1 and st.corner_radius_top_left == XUiSkin.RADIUS, [st.bg_color, st.border_width_left])
	var grid_ok := true
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		grid_ok = grid_ok and int(st.get_content_margin(side)) % XUiSkin.GRID == 0
	check("update_frame_grid", grid_ok)
	check("update_no_purple", not st.bg_color.is_equal_approx(Color(0.06, 0.05, 0.1, 0.96)))
	var old := XUpdateClient.ENABLED
	XUpdateClient.ENABLED = false
	var page := XUpdatePage.open(self)
	await frames(3)
	var ps: StyleBoxFlat = (page.find_child("Panel", true, false) as PanelContainer).get_theme_stylebox("panel")
	check("update_page_uses_frame", ps.bg_color.is_equal_approx(st.bg_color) and ps.border_width_top == 1)
	page.get_parent().queue_free()
	await frames(2)
	var wn := XWhatsNewPage.open(self, {"code": 1, "version": "v0.01.10", "date": "2026-11-21", "notes": ["一条"]}, false)
	await frames(3)
	var ws: StyleBoxFlat = (wn.find_child("Panel", true, false) as PanelContainer).get_theme_stylebox("panel")
	check("whats_new_uses_frame", ws.bg_color.is_equal_approx(st.bg_color) and ws.border_width_top == 1)
	wn.get_parent().queue_free()
	XUpdateClient.ENABLED = old
	XUpdatePage.FRAME_V2 = false
	var o := XUpdatePage.frame_style()
	check("update_rollback_purple", o.bg_color.is_equal_approx(Color(0.06, 0.05, 0.1, 0.96)) and o.border_width_left == 2)
	XUpdatePage.FRAME_V2 = true
	await frames(2)


# ---- F-08 ----
func _workshop() -> void:
	var s := _tq_state("plague")
	s.gain_item(XAlienation.stone_id(), 3)
	var i: Dictionary = XTianqiAlienGear.create(s, "armor", 52, "plague", "huaxing", "mimic").ok
	s.gear.append(i)
	XTianqiAlienGear.add_core(s, "plague", "insulation", "shigu", "test")
	XAlienWorkshop.selected = ""
	var ws := XAlienWorkshop.new()
	ws.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ws)
	await frames(4)
	check("ws_skin", ws.skin)
	var acts: Node = _all(ws, func(c): return c.name == "SkinActions").front()
	var btns := _all(acts, func(c): return c is Button)
	var filled := btns.filter(func(b): return (b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.is_equal_approx(Color(XUiSkin.BTN_IDLE_FILL, 0.98)))
	check("ws_one_primary", filled.size() == 1, btns.map(func(b): return b.text))
	var danger := btns.filter(func(b): return RegEx.create_from_string(XAlienWorkshop.DANGER_RE).search(b.text) != null)
	var left: Node = acts.get_child(0)
	check("ws_danger_isolated", not danger.is_empty() and danger.all(func(b): return not left.is_ancestor_of(b)), danger.map(func(b): return b.text))
	var head: Node = _all(ws, func(c): return c.name == "SkinHeader").front()
	check("ws_no_return_box", _all(head, func(c): return c is Button and c.text == "返回").is_empty())
	check("ws_back_arrow", not _all(ws, func(c): return c is XSkinBackButton).is_empty())
	var tabs: Array = _all(ws, func(c): return c.name == "SkinTabs")
	var tbs: Array = tabs[0].get_children().filter(func(n): return n is Button) if not tabs.is_empty() else []
	check("ws_tabs_one_style", tbs.size() > 1 and tbs.all(func(b): return not (b.get_theme_stylebox("normal") is XSkinSelectStyle) and b.get_theme_stylebox("normal") is StyleBoxFlat and not (b.get_theme_stylebox("normal") as StyleBoxFlat).draw_center))
	var cur: StyleBoxFlat = tbs[ws.skin_tab].get_theme_stylebox("normal") if not tbs.is_empty() else null
	check("ws_tab_underline", cur != null and cur.border_width_bottom == 2 and cur.border_width_left == 0)
	# 左下说明：末行不止一个字
	var lst: Node = _all(ws, func(c): return c.name == "SkinList").front()
	var notes := _all(lst, func(c): return c is Label and (c as Label).text.contains("异化石"))
	var last := ""
	if not notes.is_empty():
		var ls: PackedStringArray = (notes[0] as Label).text.split("\n")
		last = ls[ls.size() - 1]
	check("ws_note_no_widow", not notes.is_empty() and last.strip_edges().length() > 2, last)
	ws.queue_free()
	await frames(2)
	# P1-2：130% 全局字号（U-07 硬门禁档）、触屏宽钮时操作栏不把详情面板撑出 1280 右缘
	for touch in [false, true]:
		XFontScale.set_value("global", 130)
		XUiSkin.touch_override = 1 if touch else 0
		ws = XAlienWorkshop.new()
		ws.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(ws)
		await frames(4)
		var dp: Control = _all(ws, func(c): return c.name == "SkinDetail").front()
		var ab: Control = _all(ws, func(c): return c.name == "SkinActions").front()
		var vw := ws.size.x
		var ab_end := ab.global_position.x + ab.size.x
		var btn_end := 0.0
		for b in _all(ab, func(c): return c is Button):
			btn_end = maxf(btn_end, (b as Control).global_position.x + (b as Control).size.x)
		check("ws_130_fits_%s" % ("touch" if touch else "desk"), dp.position.x + dp.size.x <= vw + 0.5 and ab_end <= vw and btn_end <= dp.global_position.x + dp.size.x, [dp.position, dp.size, ab_end, btn_end, vw])
		ws.queue_free()
		XFontScale.set_value("global", 100)
		XUiSkin.touch_override = -1
		await frames(2)
	XAlienWorkshop.LAYOUT_V2 = false
	ws = XAlienWorkshop.new()
	ws.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ws)
	await frames(4)
	head = _all(ws, func(c): return c.name == "SkinHeader").front()
	check("ws_rollback_return_box", not _all(head, func(c): return c is Button and c.text == "返回").is_empty())
	XAlienWorkshop.LAYOUT_V2 = true
	ws.queue_free()
	await frames(2)


# ---- F-09 ----
func _map_banners() -> void:
	var a := XDifficultyNoticeCanvas.BACKDROP_A
	var bg := Color(XUiSkin.PANEL_LOW, a)
	var c1 := contrast(XUiSkin.TEXT_HI, bg)
	var c2 := contrast(XUiSkin.GOLD, bg)
	check("diff_contrast_on_white", c1 >= 4.5 and c2 >= 4.5, [c1, c2])
	# 修前的毛病在淡入淡出：整块一起半透（opacity 128）时，半透的字叠在半透的底上、底下是白雪
	var m := 128.0 / 255.0
	var under := Color.WHITE.lerp(Color(XUiSkin.PANEL_LOW), 0.92 * m)
	var text_mid := under.lerp(XUiSkin.GOLD, m)
	var c0 := contrast(text_mid, Color(under, 1.0))
	check("diff_old_midfade_short", c0 < 4.5, c0)
	var plate := Color(0.04, 0.04, 0.05, 0.95)
	var c3 := contrast(XUiSkin.TEXT, plate)
	check("map_name_contrast_on_white", c3 >= 4.5, c3)


func _map_fade() -> void:
	var s := _tq_state()
	s.map_id = 4
	var map := XMapScene.new()
	add_child(map)
	await frames(4)
	var dn: XDifficultyNoticeCanvas = map.difficulty_notice
	dn.clock.set_physics_process(false)
	dn.clock.showing = true
	dn.clock.opacity = 100   # 淡入不到一半：底先到、字还没出
	dn.refresh()
	check("diff_fade_text_later", dn.modulate.a > 0.7 and dn._text_a == 0.0, [dn.modulate.a, dn._text_a])
	dn.clock.opacity = 160   # 字开始出时底已经满了
	dn.refresh()
	check("diff_text_only_on_full_backdrop", dn._text_a > 0.0 and is_equal_approx(dn.modulate.a, 1.0), [dn.modulate.a, dn._text_a])
	dn.clock.opacity = 255
	dn.refresh()
	check("diff_full", is_equal_approx(dn.modulate.a, 1.0) and is_equal_approx(dn._text_a, 1.0))
	# P1-1：地名横幅淡入同口径——进度不到一半只升底；字开始出时底已满（字对比在纯白上 ≥ 4.5:1）
	map._show_map_name("雪原的小镇")
	var plate: XMVCanvas = map.hud.find_child("MapNamePlate", true, false)
	map._map_name_tween.kill()
	map._plate_alpha(0.4, plate)
	var ta_lo := clampf(map._map_name_fade * 2.0 - 1.0, 0.0, 1.0) / maxf(plate.modulate.a, 0.001)
	check("map_name_fade_text_later", plate.modulate.a > 0.7 and ta_lo == 0.0, [plate.modulate.a, ta_lo])
	var bad := []
	for v in [0.45, 0.51, 0.55, 0.6, 0.65, 0.8, 1.0]:
		map._plate_alpha(v, plate)
		var ta := clampf(map._map_name_fade * 2.0 - 1.0, 0.0, 1.0) / maxf(plate.modulate.a, 0.001)
		if ta > 0.0 and not is_equal_approx(plate.modulate.a, 1.0):
			bad.append([v, plate.modulate.a, ta])   # 字出了、底还没满
	var worst := contrast(XUiSkin.TEXT, Color(0.04, 0.04, 0.05, 0.95))
	check("map_name_text_only_on_full_backdrop", bad.is_empty() and worst >= 4.5, [bad, worst])
	map._plate_alpha(1.0, plate)
	map.queue_free()
	await frames(2)


# ---- F-13 ----
func _achievement() -> void:
	XState.current = null
	if not is_instance_valid(get_tree().current_scene) or get_tree().current_scene.is_queued_for_deletion():
		get_tree().current_scene = self   # 前面的地图场景把自己设成了当前场景又被删掉
	check("ach_skin_off_first", not XSkinNoticeLane.on())
	XAchievementPopup._stack.clear()
	XAchievementPopup.show_for({"id": 1, "name": "T361测试成就！", "icon": 100})
	await frames(2)
	check("ach_old_popup_made", XAchievementPopup._stack.size() == 1 and is_instance_valid(XAchievementPopup._stack[0]))
	var h0 := XSkinNoticeLane.history.size()
	_tq_state()
	check("ach_skin_on_now", XSkinNoticeLane.on())
	await pframes(3)
	check("ach_old_popup_gone", XAchievementPopup._stack.is_empty())
	var got := XSkinNoticeLane.history.slice(h0)
	check("ach_into_lane_once", got.size() == 1 and str(got[0].get("title", "")) == "T361测试成就" and not str(got[0].get("sub", "")).contains("！"), got)
	# 回退：不接管
	XAchievementPopup.LANE_TAKEOVER = false
	check("ach_rollback_keeps_bang", XAchievementPopup.lane_item({"id": 1, "name": "好！", "icon": 1}).title == "好！")
	XAchievementPopup.LANE_TAKEOVER = true
	XSkinNoticeLane.queue.clear()
	await frames(2)
