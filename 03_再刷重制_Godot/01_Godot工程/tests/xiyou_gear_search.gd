extends Node
## 装备检索／排序（XGearQuery、XGearSearch、XZhCollation）对照正式 v0.28 参照：
## tests/fixtures/gear_search_oracle.json 是参照浏览器里正式版「装备词条检索」面板（仅背包）的读数——21 件实例的
## 8 种排序、分类／搜索／品质／部位／指定词条筛选、列表摘要与详情各行；实例能力值照参照覆盖（消掉随机浮动）。
## 另测拼音比较、物品页／装备页按检索条件筛选排序、工具条文字、面板几何（运行时读数）与配置保存。
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
		print("FAIL ", name, " ", JSON.stringify(detail))


func frames() -> void:
	for i in range(6):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func names(rows: Array) -> Array:
	return rows.map(func(r): return XGearSearch.star_name(r.item))


func _run() -> void:
	# 拼音比较：Node Intl.Collator('zh-Hans') 的结果（标点 < 数字 < 汉字按拼音 < 拉丁）
	var words := ["水果刀", "练习剑", "木棒", "Abc", "abc", "1刀", "*刀", "《字典》", "斩月"]
	words.sort_custom(XZhCollation.less)
	check("zh_collation_pinyin", words == ["《字典》", "*刀", "1刀", "练习剑", "木棒", "水果刀", "斩月", "abc", "Abc"], words)
	check("zh_collation_equal", XZhCollation.compare("斩月", "斩月") == 0 and XZhCollation.compare("斩月", "斩月-II") < 0)

	var path := "user://test_gear_search_options.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	XConfig.path_override = path
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
	check("fixture_names", s.gear.map(func(e): return str(e.name)) == o.bag.map(func(b): return str(b.name)), s.gear.map(func(e): return e.name))
	var src := XGearQuery.collection(s).filter(func(r): return r.owner == "")
	check("collection_bag", src.size() == 21, src.size())
	var f := XGearQuery.defaults()
	f.scope = "bag"
	for sort in o.sorts:
		f.sort = sort
		var got := names(XGearSearch.results(src, f))
		check("sort_" + sort, got == o.sorts[sort], got)
	f.sort = "quality"
	var rows := XGearSearch.results(src, f)
	var small := rows.map(func(r): return XGearSearch.row_small(r))
	var small_np := small.map(func(t): return XGearQuery._rx(" · 战力 [^·]+").sub(t, ""))
	var oracle_np: Array = o.small.map(func(t): return XGearQuery._rx(" · 战力 [^·]+").sub(t, ""))
	check("row_small_without_power", small_np == oracle_np, small_np)
	check("row_small_power", small == o.small, small)
	for cat in o.cats:
		f.category = cat
		var got := names(XGearSearch.results(src, f))
		check("category_" + cat, got == o.cats[cat], got)
	f.category = ""
	for q in o.queries:
		f.query = q
		var got := names(XGearSearch.results(src, f))
		check("query_" + q, got == o.queries[q], got)
	f.query = ""
	for q in o.quality:
		# 下拉里没有的值（如 L13）在网页 select 上落空为「全部品质」
		f.quality = q if XGearSearch.quality_options().any(func(x): return x[0] == q) else ""
		var got := names(XGearSearch.results(src, f))
		check("quality_" + q, got == o.quality[q], got)
	f.quality = ""
	f.type = "w2"
	check("type_w2", names(XGearSearch.results(src, f)) == o.type_w2, names(XGearSearch.results(src, f)))
	f.type = "a4"
	check("type_a4", names(XGearSearch.results(src, f)) == o.type_a4, names(XGearSearch.results(src, f)))
	f.type = ""
	f.term = "暴击率#%"
	check("term_filter", names(XGearSearch.results(src, f)) == o.term, names(XGearSearch.results(src, f)))
	check("term_sort_option", XGearSearch.sort_options(src, f).map(func(x): return x[0]) == o.sortOptions)
	f.sort = "term"
	f.sortTerm = "暴击率#%"
	check("term_sorted", names(XGearSearch.results(src, f)) == o.termSorted, names(XGearSearch.results(src, f)))
	f = XGearQuery.defaults()
	f.scope = "bag"
	rows = XGearSearch.results(src, f)
	check("quality_options", XGearSearch.quality_options() == o.options["品质"], XGearSearch.quality_options())
	var bad := []
	var bad_power := []
	for i in range(rows.size()):
		var got := XGearSearch.oracle_lines(XGearSearch.detail_blocks(rows[i]))
		var want: Array = o.detail[str(i)]
		var strip := func(lines: Array) -> Array: return lines.filter(func(l): return not (l.begins_with("H3|装备战力") or l.begins_with("DIV|输出 ")))
		if strip.call(got) != strip.call(want):
			bad.append([i, got, want])
		elif got != want:
			bad_power.append([i, got.slice(2, 4), want.slice(2, 4)])
	check("detail_rows", bad.is_empty(), bad.slice(0, 2))
	check("detail_power", bad_power.is_empty(), bad_power.slice(0, 3))

	# 物品页：默认排序、应用条件、工具条文字、清除
	XGearSearch.reset_session()
	var page := XItemScene.new()
	add_child(page)
	await frames()
	page._cat = 2
	page._ok()
	await frames()
	var weapon_names := page.entries().filter(func(e): return e.has("carry")).map(func(e): return XGearSearch.star_name(e.rec))
	check("item_list_default_sort", weapon_names == o.sorts.quality.filter(func(n): return weapon_names.has(n)), weapon_names)
	# 运行时读数：两按钮 (1038.07,8,139.93,39.2)、(1184,8,88,39.2)；字宽差 4px 以内
	var tb0 := page.toolbar.get_child(0) as Button
	var tb1 := page.toolbar.get_child(1) as Button
	check("toolbar_rect", absf(page.toolbar.position.x + page.toolbar.size.x - 1272) < 0.5 and page.toolbar.position.y == 8 and absf(tb0.size.y - 39.2) < 1
		and absf(tb0.size.x - 139.93) < 4 and absf(tb1.size.x - 88) < 4, [page.toolbar.position, tb0.size, tb1.size])
	check("toolbar_text", (page.toolbar.get_child(0) as Button).text == "装备检索 / 排序" and (page.toolbar.get_child(1) as Button).text == "清除筛选")
	var all_count := page.entries().size()
	page.open_search()
	await frames()
	var panel := page.search_panel
	check("panel_open", panel != null and not page.toolbar.visible and not page.help_card.visible)
	check("panel_geometry", panel._search.position.is_equal_approx(Vector2(40, 116.6)) and absf(panel._search.size.x - 1200) < 0.5 and absf(panel._search.size.y - 41.2) < 1
		and panel._list_scroll.position.is_equal_approx(Vector2(46, 291.8)) and absf(panel._count.position.y - 259) < 0.5,
		[panel._search.position, panel._search.size, panel._list_scroll.position, panel._count.position])
	await shot("gear_search_panel")
	panel._on_field("斩月", "query")
	panel._on_sort("name")
	panel.apply_filter()
	await frames()
	check("panel_closed", page.search_panel == null and page.toolbar.visible)
	var filtered := page.entries().map(func(e): return XGearSearch.star_name(e.rec))
	check("applied_filter", filtered == ["解放前的斩月", "斩月", "★斩月-虚与死神结合之力"], filtered)
	check("toolbar_filter_text", (page.toolbar.get_child(0) as Button).text == "词条筛选中 · 3件", (page.toolbar.get_child(0) as Button).text)
	check("sort_saved", XConfig.equipment_sort() == {"sort": "name", "term": ""} and FileAccess.get_file_as_string(path).contains("\"name\""))
	page.clear_filter()
	await frames()
	check("cleared", page.gear_filter.is_empty() and page.entries().size() == all_count and (page.toolbar.get_child(0) as Button).text == "装备检索 / 排序")
	XConfig.set_equipment_sort({"sort": "quality", "term": ""})
	page.open_search()
	await frames()
	# 原版 close() 不存排序：面板里只改条件、不动排序下拉就关闭，配置里的排序不变
	page.search_panel.filter.sort = "name"
	page.search_panel._on_field("斩月", "query")
	var key_ev := InputEventKey.new()
	key_ev.keycode = KEY_ESCAPE
	key_ev.pressed = true
	Input.parse_input_event(key_ev)
	await frames()
	check("escape_closes", page.search_panel == null)
	check("close_keeps_saved_sort", XConfig.equipment_sort() == {"sort": "quality", "term": ""}, XConfig.equipment_sort())
	page.queue_free()
	await frames()

	# 装备页：候选按条件筛选，「卸载」留在最后
	var eq := XEquipScene.new()
	add_child(eq)
	await frames()
	eq._ok()
	await frames()
	eq._slot = 0
	eq._ok()
	await frames()
	check("equip_item_mode", eq._mode == "item")
	var cands := eq.candidates()
	check("equip_unequip_last", (cands.back().rec as Dictionary).is_empty())
	eq.open_search()
	await frames()
	check("equip_source_is_candidates", eq.search_panel.source.size() == cands.size() - 1, eq.search_panel.source.size())
	eq.search_panel._on_field("6", "quality")
	eq.search_panel.apply_filter()
	await frames()
	cands = eq.candidates()
	check("equip_filtered", cands.size() >= 1 and cands.slice(0, -1).all(func(e): return XQuality.grade(e.rec) == 6) and (cands.back().rec as Dictionary).is_empty(), cands.map(func(e): return e.rec.get("name", "卸载")))
	eq.queue_free()

	XConfig.path_override = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	XGear.force_roll = -1
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
