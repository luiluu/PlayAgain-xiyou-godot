extends Node
## 冠军庆典奖励（「丰富」档，v0.3.1）专项：XFestRing＋XFestReward＋使者菜单。
## 一、三枚冠军戒指：定义常驻、数值照稿 2.2、0 浮动无词缀固定 6 孔、欢庆成长每级 +1 到 60 级封顶（XActor.custom_param 的 levelCap）；
## 二、一穿四：真进伤害（finalMultiplier）、倒下一个敌人 +1 层、同一只只算一次、封顶 4 层、开战与战斗结束清零、欢庆戒指没有；
## 三、防刷四处（第 3 节／第 7 节第 5 条，各一项）：星级仓库拒收（meta PushDct）、法宝喂装备拒收、发放即锁定、关 XFest.ENABLED 后读档戒指还在；
##     另：商店不能卖、一键出售／挂机卖出跳过；
## 四、签到累计 3 天 200 币＋称号「全勤观众」；贺礼（50 币、5 万精魂、符文 ×2、抽奖券 ×10）；兑换店六样限购与扣币；收支 750；
## 五、收尾期过后读档剩币自动换精魂；活动期间每天第一次读档提醒；称号 45 并进 41；
## 六、天启篇存档：使者只送称号「冠军观赛团」和成就「我在现场」，不发币、精魂、戒指，不开签到、兑换店、冠军之路。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit


class MockHost:
	extends RefCounted
	var lines: Array = []
	var toasts: Array = []
	var picks: Array = []
	var menus: Array = []

	func show_message(m: Dictionary):
		lines.append_array(m.get("lines", []))
		if m.has("choices"):
			menus.append(m.choices)
			return int(picks.pop_front()) if not picks.is_empty() else -1
		return 0

	func toast(t: String) -> void:
		toasts.append(t)


class MockInterp:
	extends RefCounted
	var host := MockHost.new()

	func host_alive() -> bool:
		return true


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	kit = Kit.new("xiyou_fest_reward")
	XFest.TODAY_OVERRIDE = "2026-11-16"
	_ring_records()
	_growth()
	_one_four()
	await _anti_farm()
	_sign_gift_shop()
	await _envoy_menu()
	_load_hooks()
	await _tianqi()
	XFest.ENABLED = true
	XFest.TODAY_OVERRIDE = ""
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state() -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	for id in [1, 2, 3, 4, 5]:
		if not s.party.has(id):
			s.add_actor(id)
	s.init_battle_slots()
	for i in 5:
		s.set_battle_slot(i, [1, 2, 3, 4, 5][i])
	for a in s.members():
		a.recover_all()
	return s


func _wear(s: XState, a: XActor, inst: Dictionary) -> bool:
	var slot := a.equip_slots().find(XFestRing.ETYPE)
	return slot >= 0 and XEquipment.change(s, a, slot, inst)


func _ring_records() -> void:
	var ok := true
	var detail := []
	for tier in 3:
		var r := XDB.rec("Armors", XFestRing.armor_id(tier))
		var want: Dictionary = XFestRing.RINGS[tier]
		var eq: Dictionary = r.get("equipment", {})
		ok = ok and str(r.get("name", "")) == str(want.name) and int(r.etypeId) == 10 and int(r.price) == 0
		ok = ok and (r.params as Array) == (want.params as Array) and XGear.quality(r) == int(want.quality)
		ok = ok and int(eq.get("variance", -1)) == 0 and int(eq.get("slotVariance", -1)) == 0 and int(eq.get("slots", 0)) == 6 and (eq.get("affixes", [1]) as Array).is_empty()
		ok = ok and bool(r.meta.get("PushDct", false)) and str(r.note).contains("<PushDct>") and str(r.note).contains("<passiveHarmRi:%d>" % int(want.final))
		ok = ok and (r.traits as Array).any(func(t): return int(t.code) == 22 and int(t.dataId) == 2 and is_equal_approx(float(t.value), float(want.crit)))
		ok = ok and (r.traits as Array).any(func(t): return int(t.code) == 22 and int(t.dataId) == 0 and is_equal_approx(float(t.value), float(want.hit)))
		detail.append([r.get("name"), r.get("params"), XGear.quality(r)])
	_check("ring_records_match_doc", ok, detail)
	var hong := XDB.rec("Armors", XFestRing.armor_id(2))
	_check("honghuang_all_damage_35", is_equal_approx(float(hong.yep.elementAmplify["1"]), 0.35) and is_equal_approx(float(hong.yep.elementAmplify["9"]), 0.35)
		and not XDB.rec("Armors", XFestRing.armor_id(1)).has("yep"))
	_check("ring_numbers_doc", (XFestRing.RINGS[1].params as Array) == [600, 0, 60, 20, 60, 20, 20, 0] and (XFestRing.RINGS[2].params as Array) == [1500, 0, 120, 40, 120, 40, 40, 0]
		and int(XFestRing.RINGS[2].final) == 30 and int(XFestRing.RINGS[2].all) == 35 and int(XFestRing.RINGS[0].final) == 10
		and is_equal_approx(XFestRing.STACK_STEP[1], 0.05) and is_equal_approx(XFestRing.STACK_STEP[2], 0.08) and XFestRing.STACK_MAX == 4)
	# 实例：发几次都一样（0 浮动、6 孔、无词缀）
	var s := _state()
	var a := XFestRing.grant(s, 2)
	var b := XFestRing.grant(s, 2)
	_check("ring_instances_identical", not a.is_empty() and (a.params as Array) == (b.params as Array) and (a.params as Array).map(func(v): return float(v)) == (XFestRing.RINGS[2].params as Array).map(func(v): return float(v))
		and int(a.upgradeSlots) == 6 and int(b.upgradeSlots) == 6 and (a.affixIds as Array).is_empty(), [a.get("params"), b.get("params"), a.get("upgradeSlots")])
	# 不进商店、掉落：表里只在 8010～8012，原表长不变
	_check("ring_ids_outside_table", XFestRing.ARMORS.all(func(id): return id > 8001))


func _growth() -> void:
	var s := _state()
	var a: XActor = s.actor(1)
	a.change_level(30)
	var base30 := a.param(2)
	var mat30 := a.param(4)
	var inst := XFestRing.grant(s, 0)
	var worn := _wear(s, a, inst)
	var with30 := a.param(2)
	var mat_with30 := a.param(4)
	a.change_level(60)
	var d60 := a.param(2)
	XEquipment.change(s, a, a.equip_slots().find(XFestRing.ETYPE), null)
	var b60 := a.param(2)
	a.change_level(90)
	var b90 := a.param(2)
	var ring := s.gear.filter(func(e): return XFestRing.tier_of(e) == 0)
	_wear(s, a, ring[0])
	var d90 := a.param(2)
	_check("growth_per_level", worn and is_equal_approx(with30 - base30, 30.0) and is_equal_approx(mat_with30 - mat30, 30.0), [with30, base30, mat_with30, mat30])
	_check("growth_capped_60", is_equal_approx(d60 - b60, 60.0) and is_equal_approx(d90 - b90, 60.0), [d60, b60, d90, b90])


func _one_four() -> void:
	var s := _state()
	var u: XActor = s.actor(1)
	_wear(s, u, XFestRing.grant(s, 1))
	var lg := XBattleLogic.new()
	lg.setup(XFestRoad.troop_id(0, 0), s)
	var t = lg.actors[1]
	var sk := XDB.rec("Skills", 1)
	var d0 := float(lg._damage_value(u, sk, t, false))
	u.set_meta(XFestRing.META_STACKS, 4)
	var d4 := float(lg._damage_value(u, sk, t, false))
	_check("one_four_reaches_real_damage", d0 > 0.0 and absf(d4 / d0 - 1.2) < 0.02, [d0, d4])
	u.remove_meta(XFestRing.META_STACKS)
	# 倒下计层：一只 +1、同一只不重复算、封顶 4；没戴的人不加；欢庆戒指没有一穿四
	var other: XActor = lg.actors[2]
	var w: XActor = s.actor(3)
	_wear(s, w, XFestRing.grant(s, 0))
	lg.enemies[0].hp = 0.0
	lg.enemies[0].add_state(1)
	lg.resolve_collapses()
	var after1 := XFestRing.stacks(u)
	lg.resolve_collapses()
	var again := XFestRing.stacks(u)
	for i in range(1, 5):
		lg.enemies[i].hp = 0.0
		lg.enemies[i].add_state(1)
	lg.resolve_collapses()
	var full := XFestRing.stacks(u)
	_check("one_four_counts_kills", after1 == 1 and again == 1 and full == 4 and XFestRing.stacks(other) == 0 and XFestRing.stacks(w) == 0
		and XFestRing.damage_ops(w).is_empty(), [after1, again, full, XFestRing.stacks(other), XFestRing.stacks(w)])
	lg.end_battle(0)
	_check("one_four_cleared_at_end", XFestRing.stacks(u) == 0 and XFestRing.damage_ops(u).is_empty())
	u.set_meta(XFestRing.META_STACKS, 3)
	var lg2 := XBattleLogic.new()
	lg2.setup(XFestRoad.troop_id(0, 0), s)
	_check("one_four_cleared_at_start", XFestRing.stacks(u) == 0)
	# 洪荒档每层 8%
	var h: XActor = s.actor(2)
	_wear(s, h, XFestRing.grant(s, 2))
	h.set_meta(XFestRing.META_STACKS, 4)
	var ops := XFestRing.damage_ops(h)
	h.remove_meta(XFestRing.META_STACKS)
	_check("one_four_honghuang_32", not ops.is_empty() and is_equal_approx(float(ops[0].value), 1.32), ops)
	# 和活动开关无关：关了照样生效（戒指是装备的效果）
	XFest.ENABLED = false
	u.set_meta(XFestRing.META_STACKS, 2)
	var off_ops := XFestRing.damage_ops(u)
	u.remove_meta(XFestRing.META_STACKS)
	XFest.ENABLED = true
	_check("one_four_independent_of_switch", not off_ops.is_empty() and is_equal_approx(float(off_ops[0].value), 1.1), off_ops)


func _anti_farm() -> void:
	var s := _state()
	var inst := XFestRing.grant(s, 1)
	# 防刷 1：星级仓库拒收（装备有 meta 时只看 meta）
	_check("antifarm_1_star_warehouse_refuses", bool(inst.meta.get("PushDct", false)) and XStarWarehouse.push_dct(inst)
		and XStarWarehouse.deposit_gear(s, inst) == "不可存放" and s.gear.has(inst))
	# 防刷 3：发放时已锁定
	_check("antifarm_3_locked_on_grant", XItemMarks.is_locked(s, inst) and str(inst.name).contains(XItemMarks.LOCK))
	# 防刷 2：法宝喂装备拒收（解了锁也不行）
	s.gain_gear("armor", 3557, 1)
	var fabao: Dictionary = s.gear.back()
	XItemMarks.toggle_lock(s, inst)
	var why := XFabaoFeed.reason(s, fabao, inst)
	var fed := XFabaoFeed.feed(s, fabao, [inst])
	_check("antifarm_2_fabao_feed_refuses", not XItemMarks.is_locked(s, inst) and why == "限定装备无法喂入" and int(fed.used) == 0 and s.gear.has(inst), [why, fed])
	# 不能卖：商店不收，一键出售（安全出售开／关）和挂机自动卖都跳过（解锁状态下）
	var all := range(0, 16)
	var safe0 := XSafeSell.ENABLED
	XSafeSell.ENABLED = false
	var legacy_list := XItemMarks.sellable_gear(s, all, true)
	XSafeSell.ENABLED = safe0
	_check("cannot_sell", not XItemMarks.can_sell(inst) and not legacy_list.has(inst) and XSafeSell.reason(s, inst) != "", XSafeSell.reason(s, inst))
	# 防刷 4：关掉 XFest.ENABLED 后读档，戒指还在、定义查得到、属性照算、照样存不进仓库
	XState.current = s
	XFest.ENABLED = false
	XDB._tables.erase("Armors")
	var back := kit.roundtrip()
	var ring: Array = [] if back == null else back.gear.filter(func(e): return XFestRing.tier_of(e) == 1)
	var rec := XDB.rec("Armors", XFestRing.armor_id(1))
	var a: XActor = null if back == null else back.actor(1)
	var refused := false if ring.is_empty() else XStarWarehouse.deposit_gear(back, ring[0]) == "不可存放"
	var p0 := 0.0 if a == null else a.param(0)
	var worn := false if ring.is_empty() else _wear(back, a, ring[0])
	var p1 := 0.0 if a == null else a.param(0)
	_check("antifarm_4_ring_survives_switch_off", back != null and ring.size() == 1 and not rec.is_empty() and worn and is_equal_approx(p1 - p0, 600.0)
		and refused and not XFest.ENABLED,
		[ring.size(), rec.get("name"), p0, p1])
	XFest.ENABLED = true
	XState.current = s


func _sign_gift_shop() -> void:
	var s := _state()
	XFest.TODAY_OVERRIDE = "2026-11-16"
	var r1 := XFestReward.sign_in(s)
	var r1b := XFestReward.sign_in(s)
	XFest.TODAY_OVERRIDE = "2026-11-20"
	var r2 := XFestReward.sign_in(s)
	XFest.TODAY_OVERRIDE = "2026-11-28"
	XConfig.designations().erase(str(XFest.TITLE_ATTEND))
	var r3 := XFestReward.sign_in(s)
	XFest.TODAY_OVERRIDE = "2026-11-29"
	var r4 := XFestReward.sign_in(s)
	_check("sign_3_days_200", bool(r1.ok) and int(r1.coins) == 70 and not bool(r1b.ok) and str(r1b.why) == "today" and int(r2.coins) == 70
		and int(r3.coins) == 60 and bool(r3.title) and not bool(r4.ok) and str(r4.why) == "full" and XFest.coins(s) == 200
		and XDesignation.unlocked(XFest.TITLE_ATTEND), [r1, r2, r3, r4, XFest.coins(s)])
	XFest.TODAY_OVERRIDE = "2026-12-01"
	_check("sign_closed_in_grace", not bool(XFestReward.sign_in(_state()).ok))
	XFest.TODAY_OVERRIDE = "2026-11-16"
	# 贺礼：50 币、5 万精魂、符文 ×2（按等级）、抽奖券 ×10，只一次
	var g := _state()
	var gold0 := g.gold
	var rune := XFestReward.rune_item(g)
	var t1 := XFestReward.gift(g)
	var t2 := XFestReward.gift(g)
	_check("gift_contents_once", t1 != "" and t2 == "" and XFest.coins(g) == 50 and g.gold - gold0 == 50000 and g.item_count(rune) == 2 and g.item_count(1639) == 10,
		[t1, XFest.coins(g), g.gold - gold0, rune, g.item_count(rune), g.item_count(1639)])
	_check("rune_by_level", rune == 24 and _rune_at(35) == 64 and _rune_at(45) == 110 and _rune_at(70) == 171, [rune, _rune_at(35), _rune_at(45), _rune_at(70)])
	# 兑换店：限购全买下 480 币；扣币、发货；买满、币不够都不动
	var b := _state()
	XFest.add_coins(b, 750)
	var gold1 := b.gold
	var errs := []
	for row in XFestReward.SHOP:
		if int(row.limit) > 0:
			for i in int(row.limit):
				errs.append(XFestReward.buy(b, str(row.key)))
	var limited := 0
	for row in XFestReward.SHOP:
		limited += int(row.price) * int(row.limit)
	_check("shop_limited_total_480", limited == 480 and errs.all(func(e): return e == "") and XFest.coins(b) == 750 - 480, [limited, errs, XFest.coins(b)])
	_check("shop_delivers", XDesignation.unlocked(XFest.TITLE_WATCH) and b.item_count(1639) == 20 and b.item_count(180) == 8 and b.item_count(179) == 2
		and b.item_count(XFestReward.rune_item(b)) == 4, [b.item_count(1639), b.item_count(180), b.item_count(179)])
	var sold := XFestReward.buy(b, "party")
	var c0 := XFest.coins(b)
	var gold_ok := XFestReward.buy(b, "gold", 27)
	var poor := XFestReward.buy(b, "gold")
	_check("shop_limits_and_gold", sold == "sold_out" and gold_ok == "" and c0 == 270 and XFest.coins(b) == 0 and b.gold - gold1 == 270000 and poor == "coins",
		[sold, gold_ok, poor, c0, XFest.coins(b), b.gold - gold1])
	# 收支：一个存档最多 750（贺礼 50＋签到 200＋三档 200／150／150）
	var total := XFestReward.GIFT_COINS
	for c in XFestReward.SIGN_COINS:
		total += int(c)
	for tier in 3:
		var rw: Dictionary = XFestRoad.REWARDS[tier]
		total += 4 * int(rw.first) + int(rw.clear) + int(rw.flawless)
	_check("coin_budget_750", total == 750, total)
	XFest.TODAY_OVERRIDE = "2026-12-03"
	_check("shop_closed_after_grace", XFestReward.buy(b, "gold") == "closed")
	XFest.TODAY_OVERRIDE = "2026-12-01"
	XFest.add_coins(b, 10)
	_check("shop_open_in_grace", XFestReward.buy(b, "gold") == "")
	XFest.TODAY_OVERRIDE = "2026-11-16"


func _rune_at(lv: int) -> int:
	var s := _state()
	for a in s.members():
		a.change_level(lv)
	return XFestReward.rune_item(s)


func _envoy_menu() -> void:
	XFest.TODAY_OVERRIDE = "2026-11-16"
	var s := _state()
	var it := MockInterp.new()
	await XFestLobby.envoy(it)   # 第一次：贺礼
	var it2 := MockInterp.new()
	# 菜单：冠军之路是什么／四支战队／签到／庆典币兑换／再见 → 选签到，再选再见
	it2.host.picks = [2, 4]
	await XFestLobby.envoy(it2)
	var menu: Array = it2.host.menus[0] if not it2.host.menus.is_empty() else []
	_check("envoy_menu_sign_shop", menu.has(XFestText.SIGN_MENU) and menu.has(XFestText.SHOP_MENU) and XFest.coins(s) == 50 + 70
		and it2.host.toasts.any(func(t): return str(t).contains("签到成功")), [menu, XFest.coins(s), it2.host.toasts])
	_check("envoy_scene_achievement", XAchievement.party_has(s, int(XFestReward.ACHIEVEMENT_IDS.scene)) and not XAchievement.def(144).is_empty()
		and str(XAchievement.def(144).type) == "节日")
	# 兑换店走一遍：选称号 → 换 → 退出（币够）
	XFest.add_coins(s, 100)
	XConfig.designations().erase(str(XFest.TITLE_WATCH))
	var it3 := MockInterp.new()
	it3.host.picks = [3, 0, 0, XFestReward.SHOP.size(), 4]
	await XFestLobby.envoy(it3)
	_check("envoy_shop_buys_title", XDesignation.unlocked(XFest.TITLE_WATCH) and XFestReward.bought(s, "title") == 1 and XFest.coins(s) == 50 + 70,
		[XFest.coins(s), it3.host.toasts, it3.host.menus.size()])
	# 收尾期：只剩兑换
	XFest.TODAY_OVERRIDE = "2026-12-01"
	var it4 := MockInterp.new()
	it4.host.picks = [1]
	await XFestLobby.envoy(it4)
	var m4: Array = it4.host.menus[0] if not it4.host.menus.is_empty() else []
	_check("grace_menu_shop_only", m4.has(XFestText.SHOP_MENU) and not m4.has(XFestText.SIGN_MENU), m4)
	XFest.TODAY_OVERRIDE = "2026-11-16"


func _load_hooks() -> void:
	# 读档提醒：活动期间每个存档每天一次
	XFest.TODAY_OVERRIDE = "2026-11-16"
	var s := _state()
	XFestReward.after_load(s)
	var p1 := XFestReward.pending()
	XFestReward.after_load(s)
	var p2 := XFestReward.pending()
	XFest.TODAY_OVERRIDE = "2026-11-17"
	XFestReward.after_load(s)
	var p3 := XFestReward.pending()
	XFest.TODAY_OVERRIDE = "2026-12-01"
	XFestReward.after_load(s)
	var p4 := XFestReward.pending()
	_check("remind_once_a_day", p1 == [XFestText.REMIND_TOAST] and p2.is_empty() and p3 == [XFestText.REMIND_TOAST] and p4.is_empty(), [p1, p2, p3, p4])
	# 剩币：收尾期里不换；收尾期过后读档按 10 币＝1 万精魂换掉、提示
	XFest.add_coins(s, 275)
	XFestReward.after_load(s)
	var kept := XFest.coins(s)
	XFest.TODAY_OVERRIDE = "2026-12-03"
	var gold0 := s.gold
	XFestReward.after_load(s)
	var pl := XFestReward.pending()
	_check("leftover_converted_after_grace", kept == 275 and XFest.coins(s) == 5 and s.gold - gold0 == 270000
		and pl.size() == 1 and str(pl[0]).contains("270") and str(pl[0]).contains("270000"), [kept, XFest.coins(s), s.gold - gold0, pl])
	XFestReward.after_load(s)
	_check("leftover_once", XFest.coins(s) == 5 and XFestReward.pending().is_empty())
	# 开关关了也照换（币是玩家已经拿到的）
	XFest.add_coins(s, 15)
	XFest.ENABLED = false
	XFestReward.after_load(s)
	XFest.ENABLED = true
	_check("leftover_even_switch_off", XFest.coins(s) == 0, XFest.coins(s))
	XFestReward.map_start()
	# 称号 45 并进 41
	var n := XConfig.designations()
	n.erase(str(XFest.TITLE_ROAD))
	XDesignation.unlock(XFest.TITLE_ROAD_HARD)
	XFestReward.after_load(s)
	_check("title_45_merged_into_41", XDesignation.unlocked(XFest.TITLE_ROAD))
	n.erase(str(XFest.TITLE_ROAD_HARD))
	XConfig.save_designations()
	XFest.TODAY_OVERRIDE = "2026-11-16"


func _tianqi() -> void:
	XFest.TODAY_OVERRIDE = "2026-11-16"
	var n := XConfig.designations()
	n.erase(str(XFest.TITLE_WATCH))
	XConfig.save_designations()
	var tq := Kit.new_game()
	var gold0 := tq.gold
	var gear0 := tq.gear.size()
	var it := MockInterp.new()
	await XFestLobby.envoy(it)
	_check("tianqi_envoy_title_and_achievement", XDesignation.unlocked(XFest.TITLE_WATCH) and XAchievement.party_has(tq, int(XFestReward.ACHIEVEMENT_IDS.scene))
		and XFest.coins(tq) == 0 and tq.gold == gold0 and tq.gear.size() == gear0 and tq.item_count(1639) == 0, [XFest.coins(tq), tq.gold - gold0, it.host.toasts])
	var it2 := MockInterp.new()
	await XFestLobby.envoy(it2)
	_check("tianqi_envoy_once", it2.host.toasts.is_empty() and it2.host.menus.is_empty())
	_check("tianqi_no_sign_shop", XFestReward.menu(tq).is_empty() and not bool(XFestReward.sign_in(tq).ok) and XFestReward.buy(tq, "gold") == "closed")
	XFestReward.after_load(tq)
	_check("tianqi_no_remind_after_gift", XFestReward.pending().is_empty())
