extends Node
## 【cc·天启篇·未经审查】T288 卡 S 长说明卡分节专项：
## - 节标记覆盖全部行：技能（专属 10122～10299、普通 1～400、流萤 10622／10623 各阶）、成长装备（参照全部例，带「这一场」）、武器、防具、物品抽样，
##   XHelpCard.section_tags 与行等长、每个标记都在 SECTION_TAGS 里（没有落空的行）；content() 不因分节变（同一张卡开关前后行相同）；
## - skin_card_data 不丢行：每条非空、非名字行的字都进了牌（抬头小字／描述／格子／节里的行）；
## - 分节样子：渡鸦 10122 有 基本信息→伤害怎么算→成长→效果；普通技能没有成长节；成长装备有「这一场」（本场成长）；流萤 0 阶「解锁」行画暗字；
## - XSkinCard：fold 关时 Y 不展开（同旧）；fold 开且放不下时 Y 展开、再 Y 收回、取消收回；点牌底一条展开；展开后能滚到底；换牌自动收起；
## - 回退：SECTIONS 关时浮动说明卡照旧画（不建详情牌）、技能页右牌照旧一节无标题（行＝help_rows）；皮肤关时不分节。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(1500))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func _key_y() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_Y
	e.physical_keycode = KEY_Y
	e.pressed = true
	return e


func _texts(rows: Array) -> Array:
	return rows.map(func(r): return str(r[0]))


func _growth_cases() -> Array:
	var fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/growth_help_oracle.json"))
	var out := []
	for c in fx.cases:
		var base := XDB.rec("Armors", int(c.base))
		var meta: Dictionary = base.get("meta", {}).duplicate()
		meta.quality = str(int(c.quality))
		var o := {"kind": "armor", "base": int(c.base), "id": 9000 + int(c.base), "etypeId": int(base.get("etypeId", 0)), "atypeId": int(base.get("atypeId", 0)), "name": c.name,
			"note": c.note0, "description": c.description0, "params": c.params, "price": c.price, "traits": c.traits, "meta": meta, "yep": {}}
		for k in c.fields:
			o[k] = c.fields[k]
		out.append([o, int(c.pending)])
	return out


## 一张卡：标记等长、全在表里；牌里不丢字
func _cover(tag: String, obj: Dictionary, rows: Array) -> bool:
	var tags := XHelpCard.section_tags(rows, obj)
	var ok := tags.size() == rows.size() and tags.all(func(t): return XHelpCard.SECTION_TAGS.has(t))
	if not ok:
		return check("cover." + tag, false, {"tags": tags, "rows": _texts(rows)})
	var d := XHelpCard.skin_card_data(rows, obj)
	var bag := str(d.subtitle) + "\n" + str(d.desc)
	for sec in d.sections:
		for r in sec.get("rows", []):
			bag += "\n" + str(r.text)
		for c in sec.get("cells", []):
			bag += "\n" + str(c[0]) + "：" + str(c[1])
	var plain := RegEx.create_from_string("(?i)(?:\\\\|\u001b)(?:[a-z]+\\[[^\\]]*\\]|[{}.|!><^$])")
	var col := RegEx.create_from_string("(?i)(?:\\\\|\u001b)col\\[\\d+\\]")
	for i in range(1, rows.size()):
		if tags[i] == "gap":
			continue
		for part in col.sub(XMVText.convert_escapes(str(rows[i][0])), "\u0001", true).split("\u0001"):
			for ln in plain.sub(part, "", true).split("\n", false):
				var t := ln.strip_edges()
				if t == "":
					continue
				# 节里去掉了和小标题重复的字头（效果：／成长：／伤害：），比字头后面的部分
				var core := RegEx.create_from_string("^(?:效果|成长|伤害)[：:]\\s*").sub(t, "")
				core = RegEx.create_from_string("^([^：:]{1,12})[：:]\\s*").sub(core, "")   # 格子里「名：值」拆开了，比值
				if core != "" and not bag.contains(core.strip_edges()):
					return check("keep." + tag, false, {"row": t, "bag": bag})
	return true


func _run() -> void:
	TestEnv.isolate("xiyou_help_card_sections")
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.flags["tianqi"] = {"rules": 1}
	XUiSkin.FORCE = true
	_coverage(s)
	_shapes(s)
	await _card_input()
	await _rollback(s)
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XState.current = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _coverage(s: XState) -> void:
	var n := 0
	var bad := 0
	var ids := range(1, 401) + range(10122, 10300)
	for id in ids:
		var sk := XDB.rec("Skills", id)
		if sk.is_empty() or str(sk.get("name", "")) == "":
			continue
		n += 1
		var before := _texts(XHelpCard.content(sk, "skill"))
		if not _cover("skill.%d" % id, sk, XHelpCard.content(sk, "skill", false, 300.0)):
			bad += 1
		if _texts(XHelpCard.content(sk, "skill")) != before:
			check("content_stable.%d" % id, false)
	check("cover.skills", bad == 0 and n > 200, [n, bad])
	for r in range(0, 5):
		s.actor_advance[XLiuying.ACTOR] = r
		for id in [10622, 10623]:
			_cover("liuying.%d.r%d" % [id, r], XDB.rec("Skills", id), XHelpCard.content(XDB.rec("Skills", id), "skill", false, 300.0))
	s.actor_advance[XLiuying.ACTOR] = 0
	var gn := 0
	for pair in _growth_cases():
		var o: Dictionary = pair[0]
		if pair[1] > 0:
			(XHeartsteel._ledger if XHeartsteel.is_gear(o) else XHubris._ledger).append({"item": o, "gain": pair[1]})
		_cover("growth.%d" % gn, o, XHelpCard.content(o, "armor"))
		_cover("growth_detail.%d" % gn, o, XHelpCard.detail_rows(o, 300.0))
		XHeartsteel._ledger.clear()
		XHubris._ledger.clear()
		gn += 1
	check("cover.growth_cases", gn > 0, gn)
	var gear_n := 0
	for table in ["Weapons", "Armors", "Items"]:
		var kind: String = {"Weapons": "weapon", "Armors": "armor", "Items": "item"}[table]
		for id in range(1, 300, 7):
			var rec := XDB.rec(table, id)
			if rec.is_empty() or str(rec.get("name", "")) == "":
				continue
			gear_n += 1
			_cover("%s.%d" % [kind, id], rec, XHelpCard.content(rec, kind))
	check("cover.gear_items", gear_n > 30, gear_n)


func _sec(d: Dictionary, tag: String) -> Dictionary:
	for sec in d.sections:
		if str(sec.get("tag", "")) == tag:
			return sec
	return {}


func _shapes(s: XState) -> void:
	var raven := XDB.rec("Skills", 10122)
	var d := XHelpCard.skin_card_data(XHelpCard.content(raven, "skill", false, 300.0), raven)
	var order: Array = d.sections.map(func(x): return str(x.tag))
	check("raven.order", order.slice(0, 2) == ["info", "formula"] and order.has("effect"), [order, _texts(XHelpCard.content(raven, "skill", false, 300.0))])
	check("raven.titles", d.sections.all(func(x): return str(x.title) == str(XHelpCard.SECTION_TITLES[x.tag])), d.sections.map(func(x): return x.title))
	check("raven.info_cells", (_sec(d, "info").get("cells", []) as Array).has(["目标", "敌方单体"]), _sec(d, "info"))
	# 专属技能里带成长行的：成长节在效果节前、字是 UP 绿；全段节次序都照 SECTION_ORDER
	var grown := 0
	var bad_order := []
	for id in range(10122, 10300):
		var sk := XDB.rec("Skills", id)
		if sk.is_empty():
			continue
		var dd := XHelpCard.skin_card_data(XHelpCard.content(sk, "skill", false, 300.0), sk)
		var idx: Array = dd.sections.map(func(x): return XHelpCard.SECTION_ORDER.find(str(x.tag)))
		var sorted := idx.duplicate()
		sorted.sort()
		if idx != sorted:
			bad_order.append(id)
		var g := _sec(dd, "growth")
		if not g.is_empty():
			grown += 1
			if not g.rows.all(func(r): return r.color == XUiSkin.UP):
				bad_order.append(-id)
	check("exclusive.order_and_growth_up", bad_order.is_empty() and grown > 10, [grown, bad_order])
	check("raven.label_stripped", not _sec(d, "effect").is_empty() and not str(_sec(d, "effect").rows[0].text).begins_with("效果："), _sec(d, "effect"))
	var plain := XDB.rec("Skills", 3760)
	var dp := XHelpCard.skin_card_data(XHelpCard.content(plain, "skill", false, 300.0), plain)
	check("plain.no_growth", _sec(dp, "growth").is_empty() and not _sec(dp, "info").is_empty(), dp.sections.map(func(x): return x.tag))
	check("plain.flavor_desc", str(dp.desc) != "", dp.desc)
	s.actor_advance[XLiuying.ACTOR] = 0
	var lb := XDB.rec("Skills", 10623)
	var dl := XHelpCard.skin_card_data(XHelpCard.content(lb, "skill", false, 300.0), lb)
	var locked: Array = _sec(dl, "effect").get("rows", []).filter(func(r): return str(r.text).begins_with("解锁"))
	check("liuying.locked_dim", locked.size() == 1 and bool(locked[0].dim), locked)
	var cases := _growth_cases().filter(func(p): return p[1] > 0)
	if check("growth.has_pending_case", not cases.is_empty()):
		var o: Dictionary = cases[0][0]
		(XHeartsteel._ledger if XHeartsteel.is_gear(o) else XHubris._ledger).append({"item": o, "gain": cases[0][1]})
		var dg := XHelpCard.skin_card_data(XHelpCard.detail_rows(o, 300.0), o)
		var now := _sec(dg, "now")
		check("growth.now_section", not now.is_empty() and str(now.title) == "这一场" and str(now.rows[0].text).begins_with("本场成长") and now.rows[0].color == XUiSkin.GOLD_LIGHT, now)
		check("growth.order", dg.sections.map(func(x): return str(x.tag)).slice(0, 3) == ["base", "growth", "now"], dg.sections.map(func(x): return x.tag))
		XHeartsteel._ledger.clear()
		XHubris._ledger.clear()


func _card_input() -> void:
	var lb := XDB.rec("Skills", 10622)
	var d := XHelpCard.skin_card_data(XHelpCard.content(lb, "skill", false, 300.0), lb)
	# fold 关：同旧，Y 不展开
	var old := XSkinCard.new()
	old.size = Vector2(392, 300)
	add_child(old)
	old.setup(d)
	await frames(2)
	old._input(_key_y())
	check("fold_off.no_expand", not old.expanded and not old.can_expand())
	old.queue_free()
	var c := XSkinCard.new()
	c.fold = true
	c.position = Vector2(856, 72)
	c.size = Vector2(392, 400)
	add_child(c)
	c.setup(d)
	await frames(2)
	check("fold.overflow", c.can_expand() and c.natural_height(392) > 400.0, c.natural_height(392))
	c._input(_key_y())
	check("fold.y_expand", c.expanded)
	var r := c.expanded_rect()
	check("fold.rect_2x_left", is_equal_approx(r.size.x, 784.0) and is_equal_approx(r.end.x, 392.0) and is_equal_approx(r.position.y + c.position.y, XUiSkin.TOP), r)
	c._input(_key_y())
	check("fold.y_collapse", not c.expanded)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = c.strip_rect().get_center()
	c._gui_input(mb)
	check("fold.tap_expand", c.expanded)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	c._input(cancel)
	check("fold.cancel_collapse", not c.expanded)
	# 130% 字：展开后还放不下，能滚到底
	XFontScale.set_value("global", 130)
	var lb2 := XDB.rec("Skills", 10623)
	c.setup(XHelpCard.skin_card_data(XHelpCard.content(lb2, "skill", false, 300.0), lb2))
	c.size = Vector2(392, 596)
	c.set_expanded(true)
	await frames(3)
	c.scroll_by(99999)
	await frames(2)
	check("fold.scroll_bottom", c._max_scroll > 0.0 and is_equal_approx(c.scroll, c._max_scroll), [c._max_scroll, c.scroll])
	# 换一张牌：收起、回到顶
	c.setup(d)
	check("fold.new_card_collapses", not c.expanded and c.scroll == 0.0)
	XFontScale.set_value("global", 100)
	c.queue_free()
	await frames(2)


func _rollback(s: XState) -> void:
	var raven := XDB.rec("Skills", 10122)
	# 浮动说明卡：开＝详情牌，关＝旧画法
	var hc := XHelpCard.new()
	add_child(hc)
	hc.show_for(raven)
	await frames(2)
	check("float.sectioned", hc.sectioned() and hc.skin_card != null and hc.skin_card.visible and not hc.canvas.visible)
	XHelpCard.SECTIONS = false
	hc.show_for(raven)
	await frames(2)
	check("float.off_old", not hc.sectioned() and hc.canvas.visible and (hc.skin_card == null or not hc.skin_card.visible))
	XHelpCard.SECTIONS = true
	hc.show_text("毒鸡汤")
	check("float.text_old", not hc.sectioned() and hc.canvas.visible)
	XUiSkin.FORCE = false
	var was := XUiSkin.ENABLED
	XUiSkin.ENABLED = false
	hc.show_for(raven)
	check("float.skin_off_old", not hc.sectioned() and hc.canvas.visible)
	XUiSkin.ENABLED = was
	XUiSkin.FORCE = true
	hc.queue_free()
	# 技能页右牌：开＝分节＋fold，关＝一节无标题、行＝help_rows（一字不变）
	var a: XActor = s.actor(int(s.party[0]))
	a.learn_skill(10122)
	for on in [true, false]:
		XHelpCard.SECTIONS = on
		var page := XSkillScene.new()
		add_child(page)
		await frames(3)
		var found := false
		for ti in page.types().size():
			page.type_index = ti
			var k := page.entries().map(func(e): return int(e.get("id", 0))).find(10122)
			if k >= 0:
				page.mode = "list"
				page.index = k
				page._refresh()
				found = true
				break
		await frames(2)
		var card: XSkinCard = page.skin.card if page.skin != null else null
		if check("page.%s.found" % on, found and card != null):
			XHelpCard.scene_actor = a
			var view := XGrowthHelp.skill_view(raven, a)
			var want_rows := XSkinTemplatePage.help_rows(XHelpCard.content(view, "skill", bool(view.get("skill_copy", false)), 300.0))
			if on:
				check("page.on.sections", card.fold and card.sections.size() >= 3 and str(card.sections[0].title) == "基本信息", card.sections.map(func(x): return x.title))
			else:
				check("page.off.unchanged", not card.fold and card.sections.size() == 1 and str(card.sections[0].title) == "" and str(card.sections[0].rows) == str(want_rows) and str(card.desc) == "",
					[card.sections, want_rows])
		page.queue_free()
		await frames(2)
	XHelpCard.SECTIONS = true
