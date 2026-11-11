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
	XCanglong.original_data()  # 按原版比：漩涡二阶段、苍龙重做与解放（优化登记三条）关掉，新行为由 xiyou_rift2_canglong 核
	XPower.SHOW_POWER_UI = true  # 战力先藏（默认关）：本专项测战力显示，开着才与藏之前逐字一致
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
	return {"rows": card.rows, "height": float(card.height), "power": card.rows.any(func(r): return str(r[0]).replace("\\lock[1]", "").begins_with(POWER_PREFIX))}


func _compare(cat: String, card: Dictionary) -> void:
	var name := "%s_%d_%s" % [cat, int(card.id), card.name]
	if cat == "gear":
		name += "_%s" % str(card.roll)
	var obj := _obj(cat, card)
	var exp := _expected(card)
	var got := XHelpCard.content(obj, "" if cat != "gear" else str(card.kind))
	if not exp.power:
		got = got.filter(func(r): return not str(r[0]).replace("\\lock[1]", "").begins_with(POWER_PREFIX))  # v0.43 排版行首带 \lock[1]
		if XHelpCard.LAYOUT_V043:  # 战力行单独成块时，拿掉后留下的空行并成一个（原版没开战力时本来就没有这一块）
			var kept := []
			for r in got:
				if str(r[0]) == " " and (kept.is_empty() or str(kept.back()[0]) == " "):
					continue
				kept.append(r)
			if not kept.is_empty() and str(kept.back()[0]) == " ":
				kept.pop_back()
			got = kept
	var lay := XHelpCard.layout(got, 0, XHelpCard.note_width(obj), oracle_measure)
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


## 量排版之前的价格行：v0.43 排版把购买／出售价格并成一行两列（\col[50]），这里只比出售价本身
func _sell_row(obj: Dictionary) -> String:
	var keep := XHelpCard.LAYOUT_V043
	XHelpCard.LAYOUT_V043 = false
	var rows := XHelpCard.content(obj, "item")
	XHelpCard.LAYOUT_V043 = keep
	for r in rows:
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
	# 专属角色技能（10122～10299）同理：characterHelpActor 取探针已建好的 10 级所属角色（切片里的 166 奈叶、167 渡鸦、168 米拉、171 甚尔、172 宿傩、173 饿狼、174 云裳、175 谷雨、176 屠苏、177 璇；屠苏、璇的技能号在 10299 之后，nowGrowthView 一样按所属角色）
	for id in [166, 167, 168, 171, 172, 173, 174, 175, 176, 177]:
		cat_state.actor(id).change_level(10)
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
	_rollback_display(card)
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
	# 冻结后跟进 v0.36（D.equipmentRows）：白字属性排到第一条蓝字「特效：」前（WHITE_STATS_FIRST；集成分支默认开，关＝备注原位）
	# 下面比的是排版前的行（v0.43 排版 LAYOUT_V043 另测），先关掉排版、白字开关两头测
	_check("white_stats_default_on_v062", XHelpCard.WHITE_STATS_FIRST and XHelpCard.LAYOUT_V043)
	XHelpCard.LAYOUT_V043 = false
	XHelpCard.WHITE_STATS_FIRST = false
	var white := "rgba(255,255,255,1)"
	var wnote := ["<pos=AP text=暴击率：＋5% size=normalsize color=" + white + " line=false align=0>",
		"<pos=AP text=\\c[2]攻击力：＋9 size=normalsize color=" + white + " line=false align=0>",
		"<pos=AP text=\\c[1]特效：测试 size=normalsize color=normalcolor line=false align=0>",
		"<pos=AP text=闪避率：＋3% size=normalsize color=rgba(255,0,0,1) line=false align=0>",
		"<pos=AP text=说明：不是属性 size=normalsize color=" + white + " line=false align=0>"]
	var wgear := {"kind": "weapon", "name": "白字测试剑", "description": "", "note": "\n".join(wnote), "params": [0, 0, 0, 0, 0, 0, 0, 0], "wtypeId": 1, "meta": {}}
	var texts := func(rows: Array) -> Array: return rows.map(func(r): return str(r[0]))
	var off_rows := XHelpCard.content(wgear, "weapon")
	var off_t: Array = texts.call(off_rows)
	_check("white_stats_off", not XHelpCard.WHITE_STATS_FIRST and off_t.find("\\c[1]特效：测试") < off_t.find("暴击率：＋5%"), off_t)
	XHelpCard.WHITE_STATS_FIRST = true
	var on_t: Array = texts.call(XHelpCard.content(wgear, "weapon"))
	var bi := on_t.find("\\c[1]特效：测试")
	_check("white_stats_before_blue", on_t.find("暴击率：＋5%") >= 0 and on_t.find("暴击率：＋5%") < bi, on_t)
	_check("white_stats_keep_colored", on_t.find("\\c[2]攻击力：＋9") > bi and on_t.find("闪避率：＋3%") == off_t.find("闪避率：＋3%") and on_t.find("说明：不是属性") == off_t.find("说明：不是属性"), [off_t, on_t])
	var a1 := off_t.duplicate()
	var a2 := on_t.duplicate()
	a1.sort()
	a2.sort()
	_check("white_stats_same_rows", a1 == a2 and off_t.size() == on_t.size(), [off_t, on_t])
	var no_blue := {"kind": "weapon", "name": "无特效", "description": "", "note": wnote[0], "params": [0, 0, 0, 0, 0, 0, 0, 0], "wtypeId": 1, "meta": {}}
	_check("white_stats_no_blue_unchanged", texts.call(XHelpCard.content(no_blue, "weapon")) == texts.call(XHelpCard.equipment_rows(XHelpCard.content(no_blue, "weapon"))))
	var skill_obj := {"kind": "skill", "name": "技", "description": "", "note": "\n".join(wnote), "stypeId": 1, "mpCost": 0, "tpCost": 0, "meta": {}}
	var skill_on: Array = texts.call(XHelpCard.content(skill_obj, "skill"))
	XHelpCard.WHITE_STATS_FIRST = false
	_check("white_stats_skill_untouched", skill_on == texts.call(XHelpCard.content(skill_obj, "skill")), skill_on)
	XHelpCard.WHITE_STATS_FIRST = true
	# v0.43 排版开关两头：关＝v0.28 排法（没有 \lock、描述在第二行），开＝品质类别合行、块间 4 号空行
	var potion := XDB.rec("Items", 1)
	var old_rows := XHelpCard.content(potion, "item")
	XHelpCard.LAYOUT_V043 = true
	var new_rows := XHelpCard.content(potion, "item")
	_check("layout_v043_off_is_v028", not old_rows.any(func(r): return str(r[0]).contains("\\lock[1]")) and int(old_rows[1][1]) == XHelpCard.DESC_SIZE, old_rows)
	_check("layout_v043_on", str(new_rows[1][0]).begins_with("\\lock[1]品质：") and new_rows.any(func(r): return str(r[0]) == " " and int(r[1]) == 4), new_rows.map(func(r): return r[0]))
	await get_tree().process_frame
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


## 原版 Sprite_ItemHelp.updatePos＋setItem 的位置公式（优化登记 O-008「原版行为」栏）：战斗在行左 −宽−80，其他在行右 −4，行底 −4，
## 出画面贴边留 4；再 x<900 右移 52（否则左移 10）、y<220 下移 32、y>400 上移 100、仍>500 再上移 250，超出右／下边留 30
static func _original_pos(anchor: Rect2, sz: Vector2, battle: bool) -> Vector2:
	var p := Vector2(anchor.position.x - sz.x - 80, anchor.end.y - 4) if battle else Vector2(anchor.end.x - 4, anchor.end.y - 4)
	p.x = 4 if p.x < 0 else (1280 - sz.x - 4 if p.x + sz.x > 1280 else p.x)
	if p.y + sz.y > 720:
		p.y = 720 - sz.y - 4
	p.x += 52 if p.x < 900 else -10
	p.y += 32 if p.y < 220 else 0
	p.y -= 100 if p.y > 400 else 0
	p.y -= 250 if p.y > 500 else 0
	if p.x + sz.x > 1280:
		p.x = 1280 - sz.x - 30
	if p.y + sz.y > 720:
		p.y = 720 - sz.y - 30
	return p.round()


## O-007／O-008 回退：MIN_FONT 设 0 回到原版字号（描述 10），卡变矮；PLACE_NEAR 设 false 照原版位置公式、技能书附卡间距回到 10
func _rollback_display(card: XHelpCard) -> void:
	var item := XDB.rec("Items", 1)
	card.show_for(item)
	var big_h := card.size.y
	XHelpCard.MIN_FONT = 0
	var small := XHelpCard.new()
	add_child(small)
	small.show_for(item)
	XHelpCard.MIN_FONT = 16
	_check("min_font_original_O007", small.min_font == 0 and small.size.y < big_h, [small.min_font, small.size.y, big_h])
	small.queue_free()
	XHelpCard.PLACE_NEAR = false
	for c in [[Rect2(0, 187, 768, 36), false], [Rect2(0, 600, 768, 36), false], [Rect2(900, 300, 300, 36), true]]:
		card.place_for_row(c[0], c[1])
		var want := _original_pos(c[0], card.size, c[1])
		_check("place_original_O008_%d_%d" % [int(c[0].position.y), int(c[1])], card.position == want, [card.position, want])
	card.show_for(XDB.rec("Items", 15))
	card.place_for_row(Rect2(0, 187, 768, 36))
	if card.extras.size() == 1:
		var ex: XHelpCard = card.extras[0]
		_check("extra_gap_original_O008", ex.position == Vector2(card.size.x + 10, 0) or ex.position == Vector2(-10 - ex.size.x, 0)
			or ex.position == Vector2(0, card.size.y + 10), [card.position, card.size, ex.position])
	else:
		_check("extra_gap_original_O008", false, card.extras.size())
	XHelpCard.PLACE_NEAR = true
	card.show_for(item)
