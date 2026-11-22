extends Node
## T368 专项（卡 G，T254 R9）：装备检索新皮肤版「筛选小块」（XSkinGearSearch）。
## - 开页不弹键盘（没有聚焦的输入框）、没有下拉框；点「搜词条」才出输入框并聚焦，回车收起、小块写「搜：…」、✕ 清掉。
## - 品质七枚色块可多选（filter.quality 逗号分隔），XGearQuery.matches 逐个 OR；单个值与旧写法逐件相同（七档、L 旧档）。
## - 部位图标、位置两枚、排序四枚点一下生效，再点取消（排序除外）；「更多」挑选框里是其余排序。
## - 旧页每一项新页都取得到：分类、部位、品质（含旧档）、位置、指定词条、排序的每个选项逐行走新页的点法，条件一致。
## - 详情牌：detail_blocks 的每块字都在牌上；没有结果时列表正中一句、牌空。
## - 取消顺序：输入框 → 挑选框 → 牌 → 关页；「按此筛选」把多选品质交给页面，页面筛出的件数同检索结果。
## - 回退：SKIN_PAGE_R9 = false 回到 T361 版式；皮肤关回到网页版（两者都没有新页）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 3) -> void:
	for i in range(n):
		await get_tree().process_frame


func _act(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


static func _state() -> XState:
	XGear.force_roll = 0.5
	var o: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/gear_search_oracle.json"))
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.gear.clear()
	for b in o.bag:
		s.gain_gear(str(b.kind), int(b.dbId), 1)
		var inst: Dictionary = s.gear.back()
		inst.params = (b.params as Array).map(func(v): return float(v))
		inst.name = str(b.name)
		inst.note = str(b.note)
		inst.description = str(b.description)
		inst.meta.quality = str(b.quality) if b.quality != null else null
		if inst.meta.quality == null:
			inst.meta.erase("quality")
	XState.current = s
	return s


func _chips(p: XSkinGearSearch, group: String) -> Array:
	var out := []
	for i in p.chips.size():
		if str(p.chips[i].group) == group:
			out.append(i)
	return out


func _chip(p: XSkinGearSearch, group: String, key: String) -> int:
	for i in p.chips.size():
		if str(p.chips[i].group) == group and str(p.chips[i].key) == key:
			return i
	return -1


func _open(host: Control, s: XState) -> XGearSearch:
	XGearSearch.reset_session()
	var gs := XGearSearch.open(host, XGearQuery.collection(s))
	return gs


func _run() -> void:
	TestEnv.isolate("xiyou_t368_gear_r9")
	XConfig.path_override = "user://test_t368_options.json"
	XConfig.ensure_loaded()
	XUiSkin.FORCE = true
	XKeyMap.apply()   # R1：实机 X／K／小键盘 0 也绑在 ui_cancel 上，测试照实机键位
	var s := _state()
	_query_rules(s)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var gs := _open(host, s)
	await frames(4)
	var p: XSkinGearSearch = gs.page
	check("r9_page", p != null and is_instance_valid(p) and gs._filter_panel == null)
	await _basics(gs, p)
	await _chips_work(gs, p)
	_old_options_reachable(gs, p)
	_detail_parity(gs, p)
	await _empty_and_cancel(gs, p, host)
	await _apply_to_page(s)
	await _rollback(s)
	XUiSkin.FORCE = false
	XState.current = null
	XGearSearch.reset_session()
	await frames(2)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _all(n: Node, pred: Callable, out := []) -> Array:
	for c in n.get_children():
		if pred.call(c):
			out.append(c)
		_all(c, pred, out)
	return out


# ---- XGearQuery 多选品质：单个值同原来，逗号分隔逐个 OR ----
func _query_rules(s: XState) -> void:
	var src := XGearQuery.collection(s)
	var f := XGearQuery.defaults()
	var all_q := {}
	for r in src:
		all_q[XQuality.grade_of(XGearQuery.quality(r.item))] = true
	check("fixture_has_grades", all_q.size() >= 3, all_q.keys())
	for g in 7:
		f.quality = str(g)
		var got := src.filter(func(r): return XGearQuery.matches(r.item, f)).size()
		var want := src.filter(func(r): return XGearQuery.is_gear(r.item) and XQuality.grade_of(XGearQuery.quality(r.item)) == g).size()
		check("single_grade_%d" % g, got == want, [got, want])
	for lq in [12, 14, 15]:
		f.quality = "L%d" % lq
		var got := src.filter(func(r): return XGearQuery.matches(r.item, f)).size()
		var want := src.filter(func(r): return XGearQuery.is_gear(r.item) and XGearQuery.quality(r.item) == lq).size()
		check("single_legacy_%d" % lq, got == want, [got, want])
	var gs: Array = all_q.keys()
	f.quality = "%d,%d" % [gs[0], gs[1]]
	var multi := src.filter(func(r): return XGearQuery.matches(r.item, f)).size()
	var a := src.filter(func(r): return XGearQuery.is_gear(r.item) and XQuality.grade_of(XGearQuery.quality(r.item)) in [gs[0], gs[1]]).size()
	check("multi_grade_or", multi == a and multi > 0, [multi, a])
	f.quality = "%d,L15" % gs[0]
	var mixed := src.filter(func(r): return XGearQuery.matches(r.item, f)).size()
	var b := src.filter(func(r): return XGearQuery.is_gear(r.item) and (XQuality.grade_of(XGearQuery.quality(r.item)) == gs[0] or XGearQuery.quality(r.item) == 15)).size()
	check("multi_grade_legacy_or", mixed == b, [mixed, b])
	f.quality = ""
	check("empty_quality_all", src.filter(func(r): return XGearQuery.matches(r.item, f)).size() == src.filter(func(r): return XGearQuery.is_gear(r.item)).size())


# ---- 开页：不弹键盘、没有下拉；小块齐 ----
func _basics(gs: XGearSearch, p: XSkinGearSearch) -> void:
	check("no_option_buttons", _all(gs, func(c): return c is OptionButton).is_empty())
	var edits := _all(gs, func(c): return c is LineEdit)
	check("no_keyboard_on_open", edits.size() == 1 and not (edits[0] as LineEdit).visible and not (edits[0] as LineEdit).has_focus(), edits.size())
	check("quality_chips_7", _chips(p, "quality").size() == 7)
	check("quality_chip_colors", _chips(p, "quality").all(func(i): return (p.chips[i].color as Color) == XUiSkin.quality_color(int(p.chips[i].key))))
	check("legacy_chip", _chips(p, "legacy").size() == 1)
	var types := XGearSearch.type_options(gs.source).size() - 1
	check("type_icons_row", _chips(p, "type").size() == types and types >= 2, [_chips(p, "type").size(), types])
	check("type_icons_have_icon", _chips(p, "type").all(func(i): return int(p.chips[i].get("icon", 0)) > 0))
	check("scope_chips_2", _chips(p, "scope").size() == 2)
	check("sort_chips_4", _chips(p, "sort").size() == 4)
	check("search_button", _chips(p, "search").size() == 1 and str(p.chips[_chips(p, "search")[0]].text).contains("搜词条"))
	check("back_button", p.back_button != null)
	check("page_title", p.title == "装备检索")
	check("list_one_column", p.list.columns == 1 and p.list.items.size() == gs._results.size() and gs._results.size() == gs.source.size())
	check("list_title_count", p.list_title.begins_with("符合 %d / %d 件" % [gs._results.size(), gs.source.size()]), p.list_title)
	# 小块都在左块里、彼此不重叠
	var lw := p.layout.left.size.x
	var ok := true
	for i in p.chips.size():
		var r: Rect2 = p.chips[i].rect
		if r.position.x < 0 or r.end.x > lw + 0.5 or r.end.y > p.layout.left.size.y:
			ok = false
		for j in range(i + 1, p.chips.size()):
			if r.intersects(p.chips[j].rect):
				ok = false
	check("chips_inside_left_no_overlap", ok, [lw, p.layout.left.size.y, p.chips.map(func(c): return c.rect)])


# ---- 点一下生效 ----
func _chips_work(gs: XGearSearch, p: XSkinGearSearch) -> void:
	var f := XGearSearch.filter
	var grades := {}
	for r in gs.source:
		grades[XQuality.grade_of(XGearQuery.quality(r.item))] = true
	var gk: Array = grades.keys()
	p.press_chip(_chip(p, "quality", str(gk[0])))
	p.press_chip(_chip(p, "quality", str(gk[1])))
	check("two_qualities", XSkinGearSearch.quality_set(f) == [str(gk[0]), str(gk[1])], f.quality)
	check("two_qualities_results", not gs._results.is_empty() and gs._results.all(func(r): return XQuality.grade_of(XGearQuery.quality(r.item)) in [gk[0], gk[1]]))
	check("two_qualities_on", p.chips[_chip(p, "quality", str(gk[0]))].on and p.chips[_chip(p, "quality", str(gk[1]))].on)
	p.press_chip(_chip(p, "quality", str(gk[1])))
	check("quality_toggle_off", XSkinGearSearch.quality_set(f) == [str(gk[0])], f.quality)
	p.press_chip(_chip(p, "quality", str(gk[0])))
	check("quality_all_off", str(f.quality) == "")
	var tk := str(p.chips[_chips(p, "type")[0]].key)
	p.press_chip(_chip(p, "type", tk))
	check("type_on", str(f.type) == tk and gs._results.all(func(r): return XGearQuery.type_key(r.item) == tk) and p.chips[_chip(p, "type", tk)].on)
	p.press_chip(_chip(p, "type", tk))
	check("type_off", str(f.type) == "")
	p.press_chip(_chip(p, "scope", "worn"))
	check("scope_worn", str(f.scope) == "worn" and gs._results.all(func(r): return str(r.owner) != ""))
	p.press_chip(_chip(p, "scope", "bag"))
	check("scope_bag", str(f.scope) == "bag" and gs._results.all(func(r): return str(r.owner) == ""))
	p.press_chip(_chip(p, "scope", "bag"))
	check("scope_all_again", str(f.scope) == "all" and gs._results.size() == gs.source.size())
	for k in ["count", "name", "quality"]:
		p.press_chip(_chip(p, "sort", k))
		check("sort_" + k, str(f.sort) == k and p.chips[_chip(p, "sort", k)].on)
	p.press_chip(_chip(p, "sort", "more"))
	check("sort_more_picker", p.picker_panel.visible and p.focus == "picker" and p.picker_kind == "sort")
	var keys: Array = p._picker_keys
	check("sort_more_rest", keys.has("original") and keys.has("param2") and not keys.has("quality"), keys)
	p._picker_pick(keys.find("param2"))
	check("sort_param", str(f.sort) == "param2" and not p.picker_panel.visible and str(p.chips[_chip(p, "sort", "more")].text).begins_with("物攻"))
	p.press_chip(_chip(p, "sort", "quality"))
	# 搜词条：点了才出输入框、才聚焦
	p.press_chip(_chips(p, "search")[0])
	await frames(2)
	check("search_opens_edit", p.search_edit.visible and p.search_edit.has_focus() and p.focus == "typing")
	p.search_edit.text = "暴击"
	p.search_edit.text_changed.emit("暴击")
	check("search_live", str(f.query) == "暴击")
	p.search_edit.text_submitted.emit("暴击")
	await frames(2)
	check("search_closes", not p.search_edit.visible and not p.search_edit.has_focus() and str(p.chips[_chips(p, "search")[0]].text) == "搜：暴击")
	check("search_clear_chip", _chips(p, "search_clear").size() == 1)
	p.press_chip(_chips(p, "search_clear")[0])
	check("search_cleared", str(f.query) == "" and _chips(p, "search_clear").is_empty())
	# 键盘：筛选区方向键走小块、确定切换；→ 到行尾进列表；列表 ← 回筛选区
	p.set_focus("filters")
	p.cursor = _chip(p, "quality", "0")
	p.handle_key(_act("ui_right"))
	check("key_right_moves", p.cursor == _chip(p, "quality", "1"))
	p.handle_key(_act("ui_accept"))
	check("key_accept_toggles", XSkinGearSearch.quality_set(f) == ["1"], f.quality)
	p.handle_key(_act("ui_accept"))
	p.handle_key(_act("ui_down"))
	check("key_down_next_row", str(p.chips[p.cursor].group) == "type", p.chips[p.cursor].group)
	p.cursor = _chips(p, "reset")[0]
	p.handle_key(_act("ui_right"))
	check("key_right_to_list", p.focus == "list")
	p.handle_key(_act("ui_left"))
	check("key_left_to_filters", p.focus == "filters")
	var kx := InputEventKey.new()
	kx.physical_keycode = KEY_X
	kx.pressed = true
	p.handle_key(kx)
	await frames(1)
	check("key_x_search", p.typing())
	p.close_search()
	await _r1_keys(gs, p)


func _key(code: int, uni := 0) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.unicode = uni
	e.pressed = true
	return e


func _tap(pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	e.global_position = pos
	return e


# ---- R1 返修（小A核 T368_核报告R1）：经 gs._input 走实机路径 ----
func _r1_keys(gs: XGearSearch, p: XSkinGearSearch) -> void:
	check("r1_x_is_cancel_bound", _key(KEY_X, 120).is_action_pressed("ui_cancel"))
	# P1-1：没在输入时按 X（键盘或点「X 搜词条」胶囊合成的 KEY_X）＝搜词条，不关页
	p.set_focus("list")
	gs._input(_key(KEY_X, 120))
	await frames(1)
	if not check("r1_p1_1_x_opens_search", is_instance_valid(gs) and not gs.is_queued_for_deletion() and p.typing() and p.search_edit.has_focus()):
		_bail()
		return
	# P1-2：输入框聚焦时 x／k／小键盘 0 是打字，不收起输入框、不关页
	for kc in [[KEY_X, 120], [KEY_K, 107], [KEY_KP_0, 48]]:
		gs._input(_key(kc[0], kc[1]))
		await frames(1)
		if not check("r1_p1_2_typing_keeps_%d" % kc[0], is_instance_valid(gs) and not gs.is_queued_for_deletion() and p.typing()):
			_bail()
			return
	# P2-1：输入时 Y 不给详情牌拦（牌不收键）；Esc 收起输入框、不关页
	check("r1_p2_1_card_no_y_while_typing", not p.card.is_processing_input())
	gs._input(_key(KEY_ESCAPE))
	await frames(1)
	check("r1_esc_closes_search_only", is_instance_valid(gs) and not gs.is_queued_for_deletion() and not p.typing() and p.card.is_processing_input())
	# 触屏「取消 收起」：输入态提示是可点的「取消」
	p.open_search()
	check("r1_p3_typing_hint_tappable", p._hints_for("typing").all(func(h): return not XSkinKeyHints.key_events(str(h[0])).is_empty()), p._hints_for("typing"))
	gs._input(_act("ui_cancel"))
	await frames(1)
	check("r1_action_cancel_closes_search", is_instance_valid(gs) and not p.typing())
	# P2-1：输入时点别的小块：输入框收起、键盘方向键照常走
	p.open_search()
	await frames(1)
	var qc: Rect2 = p.chips[_chip(p, "quality", "0")].rect
	gs._input(_tap(p.filters.get_global_rect().position + qc.get_center()))
	check("r1_p2_1_tap_chip_closes_search", not p.typing() and p.focus == "filters")
	check("r1_p2_1_keys_work_after", p.handle_key(_act("ui_down")))
	# 点在输入框里面不收
	p.open_search()
	await frames(1)
	gs._input(_tap(p.search_edit.get_global_rect().get_center()))
	check("r1_p2_1_tap_inside_keeps", p.typing())
	# 输入时开挑选框也先收输入框
	p.open_picker("category")
	check("r1_p2_1_picker_closes_search", not p.typing() and p.focus == "picker")
	# P2-2：挑选框左边留外置箭头
	check("r1_p2_2_picker_margin", p.picker.position.x == (28.0 if XSkinArt.select_on() else 8.0) and p.picker.get_rect().end.x <= p.picker_panel.size.x - 7.5, [p.picker.position, p.picker.size, p.picker_panel.size])
	p.close_picker()
	# P2-3：在筛选区／牌上时点列表行，焦点回列表
	p.set_focus("filters")
	p.list.gui_input.emit(_tap(Vector2(40, 10)))
	check("r1_p2_3_tap_list_focus", p.focus == "list")
	p.set_focus("card")
	p.list.gui_input.emit(_tap(Vector2(40, 10)))
	check("r1_p2_3_tap_list_from_card", p.focus == "list")
	# P2-4：30 种部位也收得进左块
	var lw := p.layout.left.size.x
	var lh := p.filters.size.y
	var ok := true
	for n in [1, 7, 14, 21, 28, 30, 35]:
		var ts := XSkinGearSearch.type_chip_size(n, lw, lh)
		var per := maxi(1, floori((lw + XSkinGearSearch.CHIP_GAP) / (ts + XSkinGearSearch.CHIP_GAP)))
		var rows := ceili(n / float(per))
		if XSkinGearSearch.FIXED_H + rows * (ts + XSkinGearSearch.CHIP_GAP) - XSkinGearSearch.CHIP_GAP > lh or ts < XSkinGearSearch.TYPE_MIN:
			ok = false
	check("r1_p2_4_30_types_fit", ok, [lw, lh])
	check("r1_p2_4_few_types_full_size", XSkinGearSearch.type_chip_size(7, lw, lh) == XSkinGearSearch.CHIP_H)
	var last: Rect2 = p.chips[p.chips.size() - 1].rect
	check("r1_fixed_h_matches_layout", absf(last.end.y - (XSkinGearSearch.FIXED_H + _type_rows_h(p))) < 0.5, [last.end.y, XSkinGearSearch.FIXED_H, _type_rows_h(p)])
	# P3：文字、部位名预览
	check("r1_p3_sort_names", p.sort_short("original") == "默认" and p.sort_short("term") == "词条")
	check("r1_p3_search_text", str(p.chips[_chips(p, "search")[0]].text) == "搜词条" and p.search_edit.placeholder_text == "搜装备名或词条，空格隔开")
	p.set_focus("filters")
	p.cursor = _chips(p, "type")[1]
	check("r1_p3_type_preview", p.group_note("type").contains(str(p.chips[p.cursor].text)) and str(XGearSearch.filter.type) == "", p.group_note("type"))
	p.set_focus("list")
	check("r1_p3_type_note_back", p.group_note("type") == "全部", p.group_note("type"))


## 页被关掉后面没法再测：直接收尾报失败（不然协程断在已释放的页上，测试挂住不退）
func _bail() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(1)


func _type_rows_h(p: XSkinGearSearch) -> float:
	var t := _chips(p, "type")
	var top: float = p.chips[t[0]].rect.position.y
	var bot: float = p.chips[t[t.size() - 1]].rect.end.y
	return bot - top


# ---- 旧页每项新页都取得到（对应表逐行）----
func _old_options_reachable(gs: XGearSearch, p: XSkinGearSearch) -> void:
	var f := XGearSearch.filter
	var miss := []
	# 分类（旧：下拉 10 项）→ 分类挑选框
	for o in [["", "全部分类"]] + XGearQuery.CATEGORIES.map(func(c): return [c, c]):
		p.press_chip(_chips(p, "category")[0])
		p._picker_pick(p._picker_keys.find(str(o[0])))
		if str(f.category) != str(o[0]):
			miss.append(["分类", o])
	# 部位（旧：下拉）→ 图标；「全部装备」＝都不点
	for o in XGearSearch.type_options(gs.source):
		if str(o[0]) == "":
			if str(f.type) != "":
				p.press_chip(_chip(p, "type", str(f.type)))
		else:
			if str(f.type) != str(o[0]):
				p.press_chip(_chip(p, "type", str(o[0])))
		if str(f.type) != str(o[0]):
			miss.append(["部位", o])
	if str(f.type) != "":
		p.press_chip(_chip(p, "type", str(f.type)))
	# 品质（旧：下拉 七档＋旧档）→ 色块／★ 挑选框；单选旧值＝只点它一个
	for o in XGearSearch.quality_options():
		f.quality = ""
		var key := str(o[0])
		if key.begins_with("L"):
			p.press_chip(_chips(p, "legacy")[0])
			p._picker_pick(p._picker_keys.find(key))
			p.close_picker()
		elif key != "":
			p.press_chip(_chip(p, "quality", key))
		if str(f.quality) != key:
			miss.append(["品质", o])
	f.quality = ""
	# 位置（旧：三项）→ 两枚；「背包 + 已装备」＝都不点
	for o in XGearQuery.SCOPES:
		var key := str(o[0])
		if key == "all":
			if str(f.scope) != "all":
				p.press_chip(_chip(p, "scope", str(f.scope)))
		elif str(f.scope) != key:
			p.press_chip(_chip(p, "scope", key))
		if str(f.scope) != key:
			miss.append(["位置", o])
	# 指定词条（旧：下拉）→ 挑选框
	var terms := XGearSearch.term_options(gs.source)
	check("terms_nonempty", terms.size() > 3, terms.size())
	for o in terms:
		p.press_chip(_chips(p, "term")[0])
		p._picker_pick(p._picker_keys.find(str(o[0])))
		if str(f.term) != str(o[0]):
			miss.append(["指定词条", o])
	# 排序（旧：下拉；挑一个有数值的词条让「单项词条」也出现）→ 三枚＋更多
	for o in terms:
		if str(o[0]) != "" and XGearSearch._has_number_term(gs.source, str(o[0])):
			gs._on_term(str(o[0]))
			break
	var sorts := XGearSearch.sort_options(gs.source, f)
	check("sorts_include_term", sorts.any(func(o): return o[0] == "term"), sorts)
	for o in sorts:
		var key := str(o[0])
		if key in XSkinGearSearch.SORT_MAIN:
			p.press_chip(_chip(p, "sort", key))
		else:
			p.press_chip(_chip(p, "sort", "more"))
			p._picker_pick(p._picker_keys.find(key))
		if str(f.sort) != key:
			miss.append(["排序", o])
	check("old_options_all_reachable", miss.is_empty(), miss)
	# 清空条件
	p.press_chip(_chips(p, "reset")[0])
	f = XGearSearch.filter   # 清空条件换了一份新字典
	check("reset_chip", str(f.term) == "" and str(f.category) == "" and str(f.quality) == "" and str(f.scope) == "all" and str(f.query) == "")


# ---- 详情牌一块不落 ----
func _detail_parity(gs: XGearSearch, p: XSkinGearSearch) -> void:
	var bad := []
	for r in gs._results:
		var d := XSkinGearSearch.card_of(r)
		var blob := JSON.stringify([d.get("title", ""), d.get("subtitle", ""), d.get("desc", ""), d.get("sections", [])])
		for b in XGearSearch.detail_blocks(r):
			var texts := []
			if b.has("pills"):
				for t in b.pills:
					var s := str(t)
					var k := s.rfind(" ")
					texts.append_array([s.left(k), s.substr(k + 1)] if k > 0 else [s])
			else:
				texts.append(str(b.get("text", "")))
				if b.has("small"):
					texts.append(str(b.small))
			for t in texts:
				if not blob.contains(JSON.stringify(t).trim_prefix("\"").trim_suffix("\"")):
					bad.append([str(r.key), t])
	check("card_has_every_detail_block", bad.is_empty(), bad.slice(0, 5))
	check("card_button_apply", p.card.buttons.size() == 1 and str(p.card.buttons[0].text) == "按此筛选" and bool(p.card.buttons[0].primary))
	check("card_title_matches_selected", p.card.title == XGearSearch.star_name(gs._results.filter(func(x): return x.key == XGearSearch.selected_key)[0].item))


# ---- 没有结果、取消顺序 ----
func _empty_and_cancel(gs: XGearSearch, p: XSkinGearSearch, host: Control) -> void:
	gs._on_field("这词不存在zzz", "query")
	check("empty_list", p.list.items.is_empty() and p.list.empty_center and p.list.empty_text.contains("没有符合"))
	check("empty_card", p.card.title == "" and p.card.sections.is_empty())
	check("empty_title", p.list_title.begins_with("符合 0 / "), p.list_title)
	gs._on_field("", "query")
	p.press_chip(_chips(p, "category")[0])
	gs._input(_act("ui_cancel"))
	await frames(1)
	check("cancel_closes_picker_first", is_instance_valid(gs) and not gs.is_queued_for_deletion() and not p.picker_panel.visible)
	p.set_focus("list")
	p.handle_key(_act("ui_accept"))
	check("list_accept_to_card", p.focus == "card")
	gs._input(_act("ui_cancel"))
	check("cancel_card_to_list", p.focus == "list" and not gs.is_queued_for_deletion())
	gs._input(_act("ui_cancel"))
	await frames(1)
	check("cancel_closes_page", not is_instance_valid(gs) or gs.is_queued_for_deletion())
	await frames(2)


# ---- 按此筛选：多选品质交给物品页，页面筛出的件数同检索 ----
func _apply_to_page(s: XState) -> void:
	var page := XItemScene.new()
	add_child(page)
	await frames(3)
	page.open_search()
	await frames(3)
	var gs: XGearSearch = page.search_panel
	var p: XSkinGearSearch = gs.page
	var grades := {}
	for r in gs.source:
		if str(r.owner) == "":
			grades[XQuality.grade_of(XGearQuery.quality(r.item))] = true
	var gk: Array = grades.keys()
	p.press_chip(_chip(p, "quality", str(gk[0])))
	p.press_chip(_chip(p, "quality", str(gk[1])))
	var want := gs._results.size()
	var bag_want := gs._results.filter(func(r): return str(r.owner) == "").size()
	p.card_button.emit(0)
	await frames(2)
	check("applied_multi_quality", str(page.gear_filter.get("quality", "")) == "%s,%s" % [gk[0], gk[1]], page.gear_filter)
	var f: Dictionary = page.gear_filter
	var listed := 0
	for e in s.gear:
		if XGearQuery.matches(e, f):
			listed += 1
	check("page_filter_same_count", listed == bag_want and want >= bag_want and listed > 0, [listed, bag_want, want])
	page.queue_free()
	XGearSearch.reset_session()
	await frames(2)


# ---- 回退 ----
func _rollback(s: XState) -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	XGearSearch.SKIN_PAGE_R9 = false
	var gs := _open(host, s)
	await frames(3)
	check("rollback_r9_t361", gs.page == null and gs._filter_panel != null)
	gs.queue_free()
	XGearSearch.SKIN_PAGE_R9 = true
	XUiSkin.FORCE = false
	XUiSkin.ENABLED = false
	gs = _open(host, s)
	await frames(3)
	var t := _all(gs, func(c): return c is Button).map(func(b): return (b as Button).text)
	check("skin_off_web", gs.page == null and t.has("关闭 · Esc") and gs._filter_panel == null, t)
	XUiSkin.ENABLED = true
	XUiSkin.FORCE = true
	host.queue_free()
	await frames(2)
