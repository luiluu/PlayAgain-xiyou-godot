extends Node
## 【cc·八戒·未经审查】深渊／不朽商人（XAbyssMerchant）对「修复后原版」参照 tests/fixtures/merchant29_oracle.json
## （mv_oracle/merchant29_probe.cjs：新源 v0.62.12 把 CE1439 与商人事件那几条字符串参数改回数组＝v0.62.13 修法，26 例）：
## complete（胜负、敌群、换图、领两次、再进图、出现率与保底、未知存在的不朽／深渊身份键）、draw（三档、分组、生成的装备、扣点、次数上限、错误文字）、装备池。
## 另测：MERCHANT29_FIX＝false（回到 v0.62.12 原版）时 355 只取第一个字符、商人页不成立；商人界面三页的行与标题文字。
var checks := 0
var failures: Array = []
var o: Dictionary
var opened := 0
var toasts: Array = []


class FakeHost:
	extends RefCounted
	var page: Node
	func toast(t: String) -> void:
		page.toasts.append(t)
	func refresh_events() -> void:
		pass
	func open_merchant29() -> void:
		page.opened += 1


class FakeInterp:
	extends RefCounted
	var host: FakeHost


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 30:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1500))


func _ready() -> void:
	_run.call_deferred()


static func norm(v):
	if v is float and v == floorf(v):
		return int(v)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = norm(v[k])
		return out
	if v is Array:
		return v.map(func(x): return norm(x))
	return v


func interp() -> FakeInterp:
	var h := FakeHost.new()
	h.page = self
	var i := FakeInterp.new()
	i.host = h
	return i


func fresh() -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.map_id = 4
	toasts = []
	opened = 0
	XAbyssMerchant.battle = {}
	XAbyssMerchant.active = false
	MVEventCore.fixed_random = 0.5
	return s


func goto(s: XState, map: int, seed := 0.5) -> void:
	MVEventCore.fixed_random = seed
	XAlienBattle.on_map_setup(s, s.map_id, map)
	XYunshangOrders.on_map_setup(s, s.map_id, map)
	XAbyssMerchant.on_map_setup(s, s.map_id, map)
	s.map_id = map
	MVEventCore.fixed_random = 0.5


func fight(s: XState, troop: int, result) -> void:
	XAbyssMerchant.battle_started(s, troop)
	if result != null:
		XAbyssMerchant.battle_ended(int(result))


func complete(s: XState, appear: float) -> bool:
	MVEventCore.fixed_random = appear
	var ok: bool = await XAbyssMerchant.complete(s, interp())
	MVEventCore.fixed_random = 0.5
	return ok


func snap(s: XState) -> Dictionary:
	var r = XAbyssMerchant.run(s)
	var l = s.flags.get(XAbyssMerchant.LEDGER_FLAG)
	return norm({"run": null if r == null else {"sequence": r.sequence, "claimed": r.claimed, "appeared": r.appeared, "used": r.used, "seed": r.seed,
			"identity": r.get("identity"), "pool": (r.pool as Array).size() if r.has("pool") else null},
		"ledger": null if l == null else l.duplicate(true), "has": XAbyssMerchant.has_merchant(s), "toasts": toasts.duplicate(), "pushed": opened})


func want_snap(a: Dictionary) -> Dictionary:
	return norm({"run": a.run, "ledger": a.ledger, "has": a.has, "toasts": a.toasts, "pushed": (a.pushed as Array).size()})


func case_of(id: String) -> Dictionary:
	for c in o.cases:
		if c.id == id:
			return c
	return {}


func _run() -> void:
	o = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/merchant29_oracle.json"))
	check("source", o.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("cases", o.cases.size() == 26 and o.cases.all(func(c): return c.errors.is_empty()))
	var c := XAbyssMerchant.config()
	check("config", norm({"costs": c.costs, "reward": c.reward, "encounterRate": c.encounterRate, "pity": c.pity, "visitLimit": c.visitLimit}) == norm(o.config), o.config)
	await complete_cases()
	await draw_cases()
	pool_cases()
	await fix_switch()
	await ui_layout()
	ui_rows()
	MVEventCore.fixed_random = -1.0
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)


func complete_cases() -> void:
	for x in o.cases:
		var id := str(x.id)
		if not id.begins_with("complete.") or not x.setup.has("rolls"):
			continue
		var s := fresh()
		var rolls: Array = x.setup.rolls
		goto(s, int(x.setup.map), float(rolls[0]))
		var before := snap(s)
		check(id + ".before", norm(before.run) == norm(x.observed.before.run), [before.run, x.observed.before.run])
		fight(s, int(x.setup.troop), x.setup.result)
		await complete(s, float(rolls[1]))
		var got := snap(s)
		check(id, got == want_snap(x.observed.after), [got, x.observed.after])
		check(id + ".page", MVEvent.merchant29_present() == (int(x.observed.after.page if x.observed.after.page != null else 0) == 1), [MVEvent.merchant29_present(), x.observed.after.page])
	var s := fresh()
	goto(s, 37)
	var ok: bool = await XAbyssMerchant.complete(s, interp())
	check("complete.no_battle", not ok and snap(s) == want_snap(case_of("complete.no_battle").observed.after), snap(s))
	s = fresh()
	goto(s, 37)
	fight(s, int(XAbyssMerchant.route(37).troops[0]), 0)
	await complete(s, 0.9)
	var second := await complete(s, 0.1)
	check("complete.twice", second == bool(case_of("complete.twice").observed.second) and snap(s) == want_snap(case_of("complete.twice").observed.after), snap(s))
	s = fresh()
	goto(s, 37)
	fight(s, int(XAbyssMerchant.route(37).troops[0]), 0)
	goto(s, 38)
	ok = await XAbyssMerchant.complete(s, interp())
	check("complete.left_map", not ok and snap(s) == want_snap(case_of("complete.left_map").observed.after), snap(s))
	s = fresh()
	goto(s, 37)
	fight(s, int(XAbyssMerchant.route(37).troops[0]), 0)
	goto(s, 4)
	goto(s, 37)
	ok = await XAbyssMerchant.complete(s, interp())
	check("complete.reenter", not ok and snap(s) == want_snap(case_of("complete.reenter").observed.after), snap(s))
	s = fresh()
	var rounds := []
	for i in 4:
		goto(s, 4)
		goto(s, 37)
		fight(s, int(XAbyssMerchant.route(37).troops[0]), 0)
		await complete(s, 0.9)
		var sn := snap(s)
		rounds.append({"appeared": sn.run.appeared, "misses": sn.ledger.misses, "balances": sn.ledger.balances, "toasts": sn.toasts})
	check("complete.pity", norm(rounds) == norm(case_of("complete.pity").observed.rounds), rounds)
	for tag in ["abyss", "immortal", "legacy"]:
		var x := case_of("unknown." + tag)
		if x.is_empty():
			continue
		s = fresh()
		var origin = x.setup.origin
		if origin == null:
			s.set_variable(107, 2)
		s.map_id = 4 if origin == null else int(origin)
		goto(s, int(x.setup.map))
		fight(s, int(x.observed.troop), 0)
		check("unknown.%s.immortal" % tag, XYunshangOrders.immortal_clear(s, int(x.observed.troop)) == bool(x.observed.immortal))
		await complete(s, 0.1)
		check("unknown." + tag, snap(s) == want_snap(x.observed.after), [snap(s), x.observed.after])


func present(map: int, bal: int) -> XState:
	var s := fresh()
	goto(s, map)
	fight(s, int(XAbyssMerchant.route(map).troops[0]), 0)
	await complete(s, 0.1)
	XAbyssMerchant.ledger(s).balances[str(XAbyssMerchant.run(s).identity.key)] = bal
	XAbyssMerchant.active = false
	return s


func view(i) -> Dictionary:
	if i is String:
		return {"ok": false, "error": i}
	return norm({"ok": true, "item": {"base": int(i.base), "name": i.name, "params": i.params, "affix": i._codexExtraAffix29, "slots": i.upgradeSlots}})


func want_view(r: Dictionary) -> Dictionary:
	if not r.ok:
		return {"ok": false, "error": r.error}
	return norm({"ok": true, "item": {"base": r.item.base, "name": r.item.name, "params": r.item.params, "affix": r.item.affix, "slots": r.item.slots}})


func draw_cases() -> void:
	for x in o.cases:
		var id := str(x.id)
		if not id.begins_with("draw.t"):
			continue
		var s: XState = await present(int(x.setup.map), 500)
		var g := "" if x.setup.group == null else str(x.setup.group)
		check(id + ".pool", XAbyssMerchant.pool(s, g).size() == int(x.observed.pool), XAbyssMerchant.pool(s, g).size())
		var before := s.gear.size()
		var got := view(XAbyssMerchant.draw(s, int(x.setup.tier), g))
		var want := want_view(x.observed)
		check(id, got == want, [got, want])
		var key := str(XAbyssMerchant.run(s).identity.key)
		check(id + ".after", XAbyssMerchant.balance(s, key) == int(x.observed.balance) and int(XAbyssMerchant.run(s).used) == int(x.observed.used)
			and s.gear.size() - before == (1 if want.ok else 0), [XAbyssMerchant.balance(s, key), XAbyssMerchant.run(s).used])
	var seq := case_of("draw.sequence")
	var s: XState = await present(37, 500)
	var out := []
	for n in 4:
		out.append(view(XAbyssMerchant.draw(s, 0, "武器")))
	check("draw.sequence", out == (seq.observed.out as Array).map(func(r): return want_view(r)), out)
	check("draw.sequence.after", XAbyssMerchant.balance(s, "abyss:37") == int(seq.observed.balance) and int(XAbyssMerchant.run(s).used) == int(seq.observed.used))
	s = await present(37, 29)
	check("draw.poor", view(XAbyssMerchant.draw(s, 0, "武器")) == want_view(case_of("draw.poor").observed.r))
	s = fresh()
	goto(s, 37)
	check("draw.no_merchant", view(XAbyssMerchant.draw(s, 0, "武器")) == want_view(case_of("draw.no_merchant").observed.r))
	s = await present(37, 500)
	check("draw.bad_tier", view(XAbyssMerchant.draw(s, 3, "武器")) == want_view(case_of("draw.bad_tier").observed.r))


func pool_cases() -> void:
	for x in o.cases:
		if not str(x.id).begins_with("pool."):
			continue
		var map := int(x.setup.map)
		var got := (XAbyssMerchant.route(map).pool as Array).map(func(d): return [str(d.db), int(d.id), str(XAbyssMerchant.item(d).name), XAbyssMerchant.group(d)])
		check(str(x.id), str(XAbyssMerchant.route(map).name) == str(x.observed.name) and norm(got) == norm(x.observed.pool), got)


## 回退开关 O-286：MERCHANT29_FIX＝false 时 355 只取第一个字符（v0.62.12 原版），商人页不成立
func fix_switch() -> void:
	var s: XState = await present(37, 500)
	check("fix.on.page", MVEvent.merchant29_present())
	MVEvent.MERCHANT29_FIX = false
	check("fix.off.page", not MVEvent.merchant29_present())
	var ce: Array = XDB.rec("CommonEvents", 1439).list
	var last: Dictionary = ce.filter(func(cmd): return int(cmd.code) == 355).back()
	check("fix.off.raw", str(last.parameters[0]) == "i" and str(last.get("mvStringParameters", "")).ends_with("complete(this);"), last)
	MVEvent.MERCHANT29_FIX = true
	check("fix.on.has", XAbyssMerchant.has_merchant(s))


## 商人界面三页的行与标题（照 Scene_Merchant29 home29／preview29／tiers29）
func ui_rows() -> void:
	var s: XState = await present(37, 100)
	check("ui.home.info", XMerchant29Page.home_info(s) == ["深渊商人　深渊:无垠虚空", "战利品点 100　剩余抽取 3 次"], XMerchant29Page.home_info(s))
	var rows := XMerchant29Page.home_rows(s).map(func(r): return [r.text, r.get("enabled", true)])
	check("ui.home.rows", rows == [["查看本副本完整装备池", true], ["抽取武器", true], ["抽取防具", true], ["抽取饰品", true], ["离开", true]], rows)
	var tiers := XMerchant29Page.tier_rows(s).map(func(r): return [r.text, r.enabled])
	check("ui.tiers", tiers == [["30点　必出1条Mod特效", true], ["90点　必出1条神话特效", true], ["150点　必出1条混沌神话特效", false]], tiers)
	var pool := XMerchant29Page.pool_rows(37)
	check("ui.pool", pool.size() == 21 and pool[0].text == "冰霜之王的泪滴　饰品", pool.slice(0, 2))


## 期二版面（Scene_Merchant29.create／list29／updateHelp／render29／turn29）
func ui_layout() -> void:
	var s: XState = await present(37, 100)
	var page := XMerchant29Page.new()
	add_child(page)
	check("ui2.rects", page.header.position == Vector2(0, 0) and page.header.size == Vector2(1280, 100)
		and page.list.position == Vector2(0, 100) and page.list.size == Vector2(550, 620)
		and page.detail.position == Vector2(550, 100) and page.detail.size == Vector2(730, 556)
		and page.nav.position == Vector2(550, 656) and page.nav.size == Vector2(730, 64), [page.list.size, page.detail.size])
	check("ui2.home", page.title_lines == XMerchant29Page.home_info(s) and page.detail_rows == [["确认选择；取消返回上一级。", 22, "#ffffff", false, 0]]
		and page.nav_text() == "◀ 上一页     1／1     下一页 ▶", [page.detail_rows, page.nav_text()])
	page.list.select(1)
	page._home_pick(page.rows[1])
	check("ui2.tier.help", page.title_lines[0] == "武器抽奖　深渊:无垠虚空" and str(page.detail_rows[0][0]) == "消耗本路线战利品点30；装备本体和具体特效随机。", page.detail_rows)
	page.list.select(2)
	page._ok.call(page.rows[2])
	check("ui2.tier.error", page.detail_key.begins_with("text:") and str(page.detail_rows[0][0]) != "" and int(XAbyssMerchant.run(s).used) == 0, page.detail_rows)
	page._back.call()
	page._home_pick(page.rows[0])
	var it: Dictionary = page.rows[0].item
	var want := XHelpCard.desc_params(it, 1 if XHelpCard.kind_of(it) == "weapon" else 2)
	check("ui2.pool.detail", page.title_lines[0] == "深渊:无垠虚空　完整装备池（21件）" and page.detail_rows == want and page.page == 0, page.detail_rows.slice(0, 2))
	# 详情分页：内容高 528，每页 488；长文字超出一屏时 1＋ceil(溢出／488) 页，翻到末页不越界
	page.set_text("\n".join(range(40).map(func(i): return "第%d行" % i)))
	var ch := 556.0 - 28.0
	var want_pages := maxi(1, 1 + ceili(maxf(0.0, page.full_h - ch) / (ch - 40.0)))
	check("ui2.pages", page.pages == want_pages and page.pages >= 2, [page.full_h, page.pages])
	page.turn(1)
	check("ui2.turn", page.page == 1 and page.origin_y == minf(page.full_h - ch, ch - 40.0) and page.nav_text() == "◀ 上一页     2／%d     下一页 ▶" % page.pages, [page.origin_y, page.nav_text()])
	page.turn(99)
	page.turn(1)
	check("ui2.turn.end", page.page == page.pages - 1 and page.origin_y == page.full_h - ch, page.origin_y)
	page.turn(-99)
	check("ui2.turn.start", page.page == 0 and page.origin_y == 0.0)
	page._pool_pick(page.rows[1])
	check("ui2.pool.pick", page.detail_key.begins_with("item:") and page.page == mini(1, page.pages - 1), [page.page, page.pages])
	page.queue_free()
