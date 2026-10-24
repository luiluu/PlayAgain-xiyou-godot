extends Node
## 制作（XCrafting／XCraftingScene）：对照冻结 v0.28 浏览器参照 tests/fixtures/crafting_oracle.json
## （新局 1/8/9/10，学会 setup.learn 的配方，配方 1 的材料各 ×3、配方 2 的第一种材料 ×1，金币 150000，打造经验 30）：
## 配方数据（458 条）、窗口几何、类别窗、四个类别的列表／每条配方的详情／确认窗／类别等级窗、金币窗逐条绘制（文字、字号、颜色、不透明度相等，坐标差 ≤ POS_TOL），
## 再走一遍配方 1 做 3 件（数量按钮矩形与点按、扣材料、得 3 件独立武器、加工经验 +30、弹窗文字与位置、做完后的列表与详情、弹窗确定后回列表），
## 插件指令 crafting learn／forget（解释器）、存读档与主菜单入口。

const FIXTURE := "res://tests/fixtures/crafting_oracle.json"
const POS_TOL := 0.05

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
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


static func _color(text: String) -> String:
	return (XQuality.parse_rgba(text) if text.begins_with("rgba") else Color(text)).to_html(false)


## 参照 → 比较形：文字 [文字,x,y,宽,对齐,字号,颜色hex,不透明度]（参照里不透明度为 null 的不比）、图标 [图标号,x,y,不透明度]
static func want_form(ops: Array) -> Array:
	return ops.map(func(o):
		if o[0] == "i":
			return [int(o[1]), float(o[2]), float(o[3]), int(o[4])]
		return [str(o[1]), float(o[2]), float(o[3]), float(o[4]), str(o[5]), float(o[6]), _color(str(o[7])), -1 if o[8] == null else int(o[8])])


static func got_form(ops: Array, want: Array = []) -> Array:
	var out := []
	for i in ops.size():
		var o: Array = ops[i]
		if o[0] == "i":
			out.append([int(o[1]), float(o[2]), float(o[3]), int(o[4])])
		else:
			var w_op := -2
			if i < want.size() and want[i].size() == 8 and want[i][7] == -1:
				w_op = -1
			out.append([str(o[1]), float(o[2]), float(o[3]), float(o[4]), str(o[6]), float(o[7]), (o[8] as Color).to_html(false), w_op if w_op == -1 else int(o[9])])
	return out


static func diff(got: Array, want: Array) -> String:
	for i in maxi(got.size(), want.size()):
		if i >= got.size() or i >= want.size():
			return "#%d 条数 %d≠%d %s" % [i, got.size(), want.size(), JSON.stringify(want[i] if i < want.size() else got[i])]
		var g: Array = got[i]
		var w: Array = want[i]
		var bad := g.size() != w.size()
		if not bad:
			for k in w.size():
				if w[k] is String:
					bad = bad or str(g[k]) != w[k]
				else:
					bad = bad or absf(float(g[k]) - float(w[k])) > POS_TOL
		if bad:
			return "#%d got %s want %s" % [i, JSON.stringify(g), JSON.stringify(w)]
	return ""


func cmp(name: String, got_ops: Array, want_ops: Array) -> bool:
	var w := want_form(want_ops)
	var d := diff(got_form(got_ops, w), w)
	return check(name, d == "", d)


func _setup(ref: Dictionary) -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in ref.setup.party:
		s.add_actor(int(id))
	for id in ref.setup.learn:
		XCrafting.learn(s, int(id))
	s.gold = int(ref.setup.gold)
	s.crafting.exp = ref.setup.craftExp.map(func(x): return int(x))
	for m in XCrafting.recipe(1).materials:
		_give(s, m, int(m.amount) * 3)
	_give(s, XCrafting.recipe(2).materials[0], int(XCrafting.recipe(2).materials[0].amount))
	return s


static func _give(s: XState, m: Dictionary, n: int) -> void:
	if str(m.type) == "item":
		s.gain_item(int(m.id), n)
	else:
		s.gain_gear(str(m.type), int(m.id), n)


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture_loaded", ref is Dictionary and ref.get("cats", {}).size() == 4, FIXTURE):
		get_tree().quit.call_deferred(1)
		return
	var all := XCrafting.recipes()
	check("recipes_458", all.size() == 458 and all.all(func(r): return not r.known and XCrafting.category_id(r) >= 0)
		and all.all(func(r): return int(r.pxp) == 0 and float(r.success) == 100.0), all.size())
	check("params_absent", int(ref.setup.params) == 0)
	var s := _setup(ref)
	check("recipe1_craftable_x3", XCrafting.amount_craftable(s, XCrafting.recipe(1)) == 3 and XCrafting.highest_level(s) == 1)
	var page := XCraftingScene.new()
	add_child(page)
	await frames()
	var rect := func(w: Control) -> Array: return [w.position.x, w.position.y, w.size.x, w.size.y]
	var geo: Dictionary = ref.geo
	check("geometry", rect.call(page.help_win) == geo.help.map(func(x): return float(x)) and rect.call(page.cat_win) == geo.cat.map(func(x): return float(x))
		and rect.call(page.list_win) == geo.list.map(func(x): return float(x)) and rect.call(page.detail_win) == geo.detail.map(func(x): return float(x))
		and rect.call(page.confirm_win) == geo.confirm.map(func(x): return float(x)) and rect.call(page.gold_win) == geo.gold.map(func(x): return float(x))
		and rect.call(page.gauge_win) == geo.gauge.map(func(x): return float(x)), [rect.call(page.cat_win), rect.call(page.gold_win)])
	check("start_category", page.mode == "category" and page.cat_index == 0 and page.index == -1 and not page.buttons_visible)
	cmp("category_ops", XCraftingScene.category_ops(), ref.catOps)
	var gold := [XCraftingScene._t(XMenu._group(s.gold), 6, 0, 164, XUI.TEXT, "right", 255, 20), ["i", XCraftingScene.GOLD_ICON, 174, 2, 255]]
	cmp("gold_ops", gold, ref.goldOps.map(func(o): return o if o[0] == "t" else o))
	for c in 4:
		var cat: Dictionary = ref.cats[str(c)]
		page.select_category(c)
		page.ok()
		var ids: Array = page.list.map(func(r): return int(r.id))
		check("cat%d_ids" % c, ids == cat.ids.map(func(x): return int(x)), [ids, cat.ids])
		var ops := []
		for i in mini(page.list.size(), XCraftingScene.LIST_ROWS):
			ops += XCraftingScene.list_row_ops(s, page.list[i], i * 36.0)
		cmp("cat%d_list" % c, ops, cat.list)
		cmp("cat%d_gauge" % c, XCraftingScene.gauge_ops(s, c), cat.gauge)
		var bad := []
		for i in page.list.size():
			page.select(i)
			var id := str(int(page.list[i].id))
			var w := want_form(cat.details[id])
			var d := diff(got_form(XCraftingScene.detail_ops(s, page.current()), w), w)
			var wc := want_form(cat.confirm[id][0])
			var dc := diff(got_form(page.confirm_ops(), wc), wc)
			if d != "" or dc != "" or page.confirm_win.opacity != int(cat.confirm[id][1]):
				bad.append("%s %s %s %d" % [id, d, dc, page.confirm_win.opacity])
		check("cat%d_details_confirm" % c, bad.is_empty(), bad.slice(0, 4))
		page.cancel()
	check("back_to_category", page.mode == "category" and page.index == -1)
	await _flow(page, s, ref)
	page.queue_free()
	await frames()
	await _plugin(s)
	_save(s)
	await _menu_entry()
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await get_tree().create_timer(0.5, true, false, true).timeout
	await frames(3)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 配方 1（加工·狼神爪）做 3 件
func _flow(page: XCraftingScene, s: XState, ref: Dictionary) -> void:
	var f: Dictionary = ref.flow
	page.select_category(2)
	page.ok()
	page.select(0)
	await frames()
	await shot("craft_1_list")
	page.ok()
	await frames(12)
	check("confirm_open", page.mode == "confirm" and page.gold_win.openness < 255, [page.mode, page.gold_win.openness])
	for i in 3:
		page._side(1)
	check("amount_3", page.amount == int(f.amount))
	# 数量按钮（ButtonSet 五个，八戒_63 补）：矩形对原版重放读数；松开在同一按钮上才算点
	check("buttons_rects", page.buttons_visible and XCraftingScene.button_rects().map(func(r: Rect2): return [r.position.x, r.position.y, r.size.x, r.size.y])
		== ref.buttons.map(func(r): return r.map(func(x): return float(x))), XCraftingScene.button_rects())
	page.press_button(0)
	check("button_minus10", page.amount == 1, page.amount)
	page.press_button(3)
	check("button_plus10", page.amount == 3, page.amount)
	var b1: Rect2 = XCraftingScene.button_rects()[1]
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = b1.get_center()
	ev.pressed = true
	page._gui_input(ev)
	var held := page.amount == 3 and page._button_down == 1
	ev = ev.duplicate()
	ev.pressed = false
	page._gui_input(ev)
	check("button_release_minus1", held and page.amount == 2 and page._button_down == -1, page.amount)
	page.press_button(2)
	check("button_plus1", page.amount == 3, page.amount)
	cmp("confirm_x3", page.confirm_ops(), f.confOps)
	await frames(10)
	await shot("craft_3_confirm_x3")
	page.ok()
	check("after_counts", s.gear_count("weapon", 393) == 3 and s.gear_count("weapon", 392) == 0 and s.item_count(47) == 0
		and s.crafting.exp == f.after.exp.map(func(x): return int(x)) and s.crafting.level == f.after.lv.map(func(x): return int(x)),
		[s.gear_count("weapon", 393), s.gear_count("weapon", 392), s.item_count(47), s.crafting.exp])
	var pr: Array = f.popup[0]
	check("buttons_stay_in_popup", page.buttons_visible)
	check("popup", page.mode == "popup" and page.popup_text == str(f.popup[3][0][1]) and page.popup_icon == int(f.popup[3][1][1])
		and absf(page.popup_win.position.x - float(pr[0])) < 1.0 and page.popup_win.position.y == float(pr[1])
		and absf(page.popup_win.size.x - float(pr[2])) < 1.0, [page.popup_text, page.popup_win.position, page.popup_win.size])
	await frames(10)
	await shot("craft_4_popup")
	var ops := []
	for i in mini(page.list.size(), 1):
		ops += XCraftingScene.list_row_ops(s, page.list[i], 0)
	cmp("list_after", ops.slice(0, 2), f.listAfter.slice(0, 2))
	cmp("detail_after", XCraftingScene.detail_ops(s, page.current()), f.detailAfter)
	page.ok()
	await frames(12)
	check("after_popup", page.mode == "list" and page.popup_win.openness < 255 and page.gold_win.openness < 255 and not page.buttons_visible,
		[page.mode, page.gold_win.openness, page.buttons_visible])
	page.ok()
	check("not_craftable_buzz", page.mode == "list")


## 设计图公共事件里的插件指令 crafting learn N（解释器）；forget
func _plugin(s: XState) -> void:
	XState.current = s
	var it := MVInterpreter.new(self, s.map_id, 0, [{"code": 356, "indent": 0, "parameters": ["crafting learn 200"]}, {"code": 0, "indent": 0, "parameters": []}])
	await it.run()
	check("learn_via_event", XCrafting.known(s, XCrafting.recipe(200)) and it.skipped.is_empty(), it.skipped)
	XCrafting.plugin_command(s, PackedStringArray(["crafting", "forget", "200"]))
	check("forget", not XCrafting.known(s, XCrafting.recipe(200)))
	var ce := XDB.rec("CommonEvents", 40)
	check("ce40_learn_1", str(ce.list[0].parameters[0]) == "crafting learn 1")


func refresh_events() -> void:
	pass


func _save(s: XState) -> void:
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("save_roundtrip", XCrafting.known(back, XCrafting.recipe(1)) and not XCrafting.known(back, XCrafting.recipe(300))
		and XCrafting.craft_exp(back, 2) == 30 and XCrafting.craft_level(back, 0) == 1)
	var blank := XState.new_game_blank().to_dict()
	blank.erase("crafting")
	var old := XState.from_dict(blank)
	check("old_save_blank", not XCrafting.known(old, XCrafting.recipe(1)) and XCrafting.craft_level(old, 3) == 1 and XCrafting.craft_exp(old, 3) == 0)
	# 升级：50×等级
	XCrafting.gain_exp(old, 0, 130)
	check("level_up", XCrafting.craft_level(old, 0) == 2 and XCrafting.craft_exp(old, 0) == 80, [old.crafting])


func _menu_entry() -> void:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	var menu := XMenu.new()
	add_child(menu)
	await frames()
	var i := menu.command_names().find("制作")
	check("menu_enabled", i >= 0 and menu.command_enabled(i))
	menu._cmd_index = i
	menu._ok()
	await frames()
	var page = menu.get_children().filter(func(n): return n is XCraftingScene)
	check("menu_opens_crafting", page.size() == 1 and page[0].visible)
	if page.size() == 1:
		page[0].cancel()
		await frames()
	check("menu_back", menu.get_children().filter(func(n): return n is XCraftingScene and not n.is_queued_for_deletion()).is_empty())
	menu.queue_free()
	await frames()
