extends Node
## 说明卡验收：XHelpCard.content() 与正式版 Sprite_ItemHelp.setItem 实际画出的行（generated/oracle/help_cards.json，
## 探针 03_转换工具/mv_oracle/help_probe.cjs）逐行一致——文字、字号、颜色、对齐；layout() 用参照引擎同样的字宽
## （字数×字号×0.6）排出的每行 y 与卡高一致，含「装备战力」行（XPower.equipment）。
## 参照里每类第一件真装备（水果刀、学徒斗篷）没有战力行（参照引擎里首次 setItem 的现象，正式版游戏中不确定），
## 这几张比较时去掉 Godot 的战力行。

const ORACLE := "res://modes/xiyou/generated/oracle/help_cards.json"
const POWER_PREFIX := "装备战力："

var results := []
var detail_left := 12


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})
	if not ok and detail_left > 0:
		detail_left -= 1
		print("FAIL ", name, " ", JSON.stringify(detail))


## 参照引擎的 measureText：String(t).length × 字号 × 0.6
static func oracle_measure(t: String, s: int) -> float:
	return t.length() * s * 0.6


func _obj(cat: String, card: Dictionary) -> Dictionary:
	match cat:
		"skills":
			return XDB.rec("Skills", int(card.id))
		"items":
			return XDB.rec("Items", int(card.id))
		"weapons":
			return XDB.rec("Weapons", int(card.id))
		"armors":
			return XDB.rec("Armors", int(card.id))
	# 随机词缀实例：探针记录的实例字段
	var yep := {}
	if not card.elementAmplify.is_empty():
		yep.elementAmplify = card.elementAmplify
	if not card.elementAmplifyN.is_empty():
		yep.elementAmplifyN = card.elementAmplifyN
	var base := XDB.rec("Weapons" if card.kind == "weapon" else "Armors", int(card.id))
	var meta: Dictionary = base.get("meta", {}).duplicate()
	meta.quality = str(int(card.quality))
	return {"kind": card.kind, "name": card.name, "note": card.note, "description": card.description, "params": card.params,
		"price": card.price, "traits": card.traits, "meta": meta, "yep": yep}


func _expected(card: Dictionary) -> Dictionary:
	return {"rows": card.rows, "height": float(card.height), "power": card.rows.any(func(r): return str(r[0]).begins_with(POWER_PREFIX))}


func _compare(cat: String, card: Dictionary) -> void:
	var name := "%s_%d_%s" % [cat, int(card.id), card.name]
	if cat == "gear":
		name += "_%s" % str(card.roll)
	var obj := _obj(cat, card)
	var exp := _expected(card)
	var got := XHelpCard.content(obj, "" if cat != "gear" else str(card.kind))
	if not exp.power:
		got = got.filter(func(r): return not str(r[0]).begins_with(POWER_PREFIX))
	var lay := XHelpCard.layout(got, 0, XHelpCard.WIDTH, oracle_measure)
	var want: Array = exp.rows
	if got.size() != want.size():
		_check(name, false, {"rows": [got.size(), want.size()], "got": got.map(func(r): return r[0]), "want": want.map(func(r): return r[0])})
		return
	for i in range(want.size()):
		var g: Array = got[i]
		var w: Array = want[i]
		var g_align = null if g[4] == null else int(g[4])
		var w_align = null if w[4] == null else int(w[4])
		var row_ok: bool = str(g[0]) == str(w[0]) and int(g[1]) == int(w[1]) and str(g[2]) == str(w[2]) and g_align == w_align
		var y_ok := is_equal_approx(float(lay.lines[i].y), float(w[3]))
		if not (row_ok and y_ok):
			_check(name, false, {"row": i, "got": [g[0], g[1], g[2], g_align, lay.lines[i].y], "want": [w[0], w[1], w[2], w_align, w[3]]})
			return
	var h_ok: bool = is_equal_approx(float(lay.height), float(exp.height)) if float(card.height) > 0 else want.is_empty()
	_check(name, h_ok, null if h_ok else {"height": [lay.height, exp.height]})


func _sell_row(obj: Dictionary) -> String:
	for r in XHelpCard.content(obj, "item"):
		if str(r[0]).begins_with("出售价格"):
			return str(r[0])
	return ""


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	_check("oracle_loaded", data is Dictionary and data.has("skills"))
	# 参照是原版 HelpExtend 的出售价格（四舍五入），逐行比对时关掉 O-049
	XHelpCard.REAL_SELL_PRICE = false
	# 探针把切片角色都 changeLevel(maxLevel)，新局等级上限 10 夹住；178 哈基米的说明卡按已有的 178（characterHelpActor）算，这里同样建一个 10 级的
	var prior := XState.current
	var cat_state := XState.new()
	cat_state.actor(XCat.ACTOR).change_level(10)
	if data is Dictionary:
		for cat in ["skills", "items", "weapons", "armors", "gear"]:
			XState.current = cat_state if cat == "skills" else prior  # 只给技能卡用（XPower 等读 XState.current，物品／装备卡照旧）
			var before := results.size()
			for card in data.get(cat, []):
				_compare(cat, card)
			var cat_results := results.slice(before)
			print("%s %d/%d" % [cat, cat_results.filter(func(r): return r.passed).size(), cat_results.size()])
	XState.current = prior
	XHelpCard.REAL_SELL_PRICE = true
	# O-049：出售价格与商店实卖一致（半价向下取整，<Sell Price> 优先）；关掉回到原版四舍五入
	var odd := {"kind": "item", "name": "测试药", "description": "", "price": 7}
	_check("sell_price_real_O049", _sell_row(odd) == "出售价格：3", _sell_row(odd))
	_check("sell_price_note_O049", _sell_row({"kind": "item", "name": "测试药", "description": "", "price": 7, "sellPrice": 1}) == "出售价格：1")
	XHelpCard.REAL_SELL_PRICE = false
	var original := _sell_row(odd)
	XHelpCard.REAL_SELL_PRICE = true
	_check("sell_price_original_O049", original == "出售价格：4", original)
	# 显示：节点能建、能按选中行贴边放（O-008）、最小字号生效（O-007）
	_check("seven_quality_windows", range(16).map(func(q): return XQuality.window_skin(q)) == [1, 1, 2, 3, 4, 7, 7, 7, 8, 8, 8, 8, 10, 8, 10, 10])
	_check("seven_quality_red_gold", XGear.color({"meta": {"quality": 12}}).is_equal_approx(Color8(255, 72, 60)) and XGear.color({"meta": {"quality": 13}}).is_equal_approx(Color8(255, 214, 90)))
	_check("seven_quality_tags", XQuality.label({"kind": "armor", "etypeId": 17, "meta": {"quality": 9}}, "armor") == "不朽（传家宝·神武）")
	var card := XHelpCard.new()
	add_child(card)
	card.show_for(XDB.rec("Skills", 160))
	_check("show_visible", card.visible and card.size.x == XHelpCard.WIDTH and card.size.y > 100, card.size)
	var plain_rows := XHelpCard.layout(XHelpCard.content(XDB.rec("Items", 1)), 0)
	var big_rows := XHelpCard.layout(XHelpCard.content(XDB.rec("Items", 1)), XHelpCard.MIN_FONT)
	_check("min_font_taller", big_rows.height > plain_rows.height, [plain_rows.height, big_rows.height])
	card.place_near(Rect2(900, 300, 300, 36), "left")
	_check("place_left", card.position.x + card.size.x <= 900 - 10 and card.position.y >= 12 and card.position.y + card.size.y <= 708, card.position)
	card.place_near(Rect2(40, 300, 300, 36), "left")
	_check("place_left_flips", card.position.x >= 340 + 10, card.position)
	# 技能书（学会技能效果 code 43）：所学技能附卡，主卡左边放得下放左边，否则右边，互不重叠
	card.show_for(XDB.rec("Items", 15))
	var skill_name := str(XDB.rec("Skills", 125).name)
	_check("skill_book_extra", card.extras.size() == 1 and str(card.extras[0].rows[0][0]) == skill_name, card.extras.map(func(c): return c.rows[0][0]))
	card.place_near(Rect2(0, 187, 768, 36), "right")   # 商店列表第一行
	if card.extras.size() == 1:
		var ex: XHelpCard = card.extras[0]
		_check("skill_book_extra_side", ex.position.x >= card.size.x + 20 or ex.position.x + ex.size.x + 20 <= 0, [card.position, ex.position])
		_check("skill_book_extra_clear_of_row", not Rect2(card.position + ex.position, ex.size).grow(10).intersects(Rect2(0, 187, 768, 36)), [card.position, ex.position])
	card.show_for(XDB.rec("Items", 1))
	_check("plain_item_no_extra", card.extras.is_empty())
	# 七档品质（西游 v0.15～v0.18）：映射、标签（多标签用 ·）、边框、列表名字色
	var grades := range(16).map(func(q): return XQuality.grade_of(q))
	_check("quality_grades", grades == [0, 0, 1, 2, 3, 4, 4, 4, 5, 5, 5, 5, 6, 5, 6, 6] and XQuality.grade_of(20) == 6, grades)
	var shenwu := {"meta": {"quality": "9"}, "etypeId": 17}
	_check("quality_label_tags", XQuality.label(shenwu, "armor") == "不朽（传家宝·神武）" and XQuality.label(shenwu, "item") == "不朽"
		and XQuality.label({"meta": {"quality": "12"}}, "weapon") == "神话（超·神器）", XQuality.label(shenwu, "armor"))
	# v0.18：星级在列表名字与说明卡名字行前，品质行不加星；物品、技能不加星
	var myth := {"name": "测试剑", "kind": "weapon", "meta": {"quality": "15"}, "description": ""}
	var myth_rows := XHelpCard.content(myth, "weapon")
	_check("star_name_row", XQuality.list_name(myth) == "★★★测试剑" and str(myth_rows[0][0]) == "★★★测试剑"
		and not myth_rows.any(func(r): return str(r[0]).begins_with("品质") and str(r[0]).contains("★"))
		and XQuality.list_name({"name": "药", "itypeId": 1, "meta": {"quality": "15"}}) == "药", myth_rows.slice(0, 3))
	_check("quality_window", XQuality.window_skin(10) == 8 and XQuality.window_skin(12) == 10 and XQuality.window_skin(5) == 7 and XQuality.window_skin(16) == 16)
	_check("quality_list_color", XQuality.list_color({"meta": {"quality": "13", "ici": "12"}}) == Color8(255, 214, 90)
		and XQuality.list_color({"meta": {"ici": "6"}}) == Color("ff8000") and XQuality.list_color({}) == Color.WHITE)
	await get_tree().process_frame
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
