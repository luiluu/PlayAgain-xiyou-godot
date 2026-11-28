extends Node
## 伤害加成总账·期三（设计仓《天启篇_伤害加成总账_v0.4》第五节第 2～4 条、第八节期三行、「期二交付补记」）：
## 一、丹药下架：天启篇不上架、「使用」不可用；淬元丹已吃的计数天启篇不读、留在存档里；旧档（带计数）读入不报错；西游档照旧。开关 NO_PILLS 关回原样。
## 二、九线封顶：秘籍格按档位格数取前几本、每本每池 ＋8%；其余九线各池合计封顶（③ ＋35% 含套装确认阶段、种族、宝珠共鸣）；
##     伤害详情带 nineCap；CAP_NINE 关、西游档、只有一本书（没超）时伤害不变。
## 三、回合预算：take_extra 每人每回合多 1 次完整出手（掷出的再动、插队、再释放共用）；不造成伤害的 free 插队不占；醒来补排不重掷；
##     派生攻击按表每回合次数；派生表里每个七印 _derived 调用点都登记、有每回合次数；敌人、西游档、开关关不管。
## 四、期二补记：七印派生系数 qiyin_derived 永久允许（底数）、白印持续伤害 qiyin_dot 永久允许；种族混合招一半、暴击常驻规则 O-421 判定见 xiyou_tianqi_ledger p2_race_*、难度被动等价 bites_*。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit


class FakeLogic extends Node:
	var actors: Array = []
	var enemies: Array = []
	var current_order: Array = []
	var _acted: Dictionary = {}
	var turn := 1


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


func _state(tianqi := true) -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
	else:
		s = XState.new()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_ledger_p3")
	seed(20261116)
	XTianqiLedger.reload_table()
	_pills()
	_nine_cap()
	_budget()
	_derived_table()
	_notes()
	_t473_fixes()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 一、丹药下架 ----
func _pills() -> void:
	var ids := [1497, 1500, 1685, 1700, 1702, 1717, 1726, 1728, 2882, 2887]
	var s := _state()
	_check("pill_ids_delisted", ids.all(func(i): return XTianqiLedger.pill_delisted(i)) and not XTianqiLedger.pill_delisted(1701) and not XTianqiLedger.pill_delisted(1729))
	# 商店：有养血丹 1693 的货单在原版会追加六颗淬元丹；天启篇全部滤掉
	var goods := XItemMarks.shop_goods([[0, 1693, 0, 0], [0, 1685, 0, 0], [0, 1, 0, 0]])
	_check("pill_shop_filtered", not goods.any(func(g): return int(g[0]) == 0 and XTianqiLedger.is_pill_item(int(g[1]))) and goods.any(func(g): return int(g[1]) == 1), goods)
	_check("pill_cannot_use", not XItemMarks.can_acquire_item(s, XDB.rec("Items", 1693)) and not XItemMarks.can_acquire_item(s, XDB.rec("Items", 2883)) and XItemMarks.can_acquire_item(s, XDB.rec("Items", 1)))
	# 淬元丹：已吃的计数留在存档里、天启篇不读；不能再吃
	var a := s.actor(int(s.battle_slots[0]))
	var base := a.param(2)
	a.state_data[XPercentPills.FIELD] = {"2": 10}
	a.param_mark_dirty()
	_check("pill_count_ignored", a.param(2) == base and XPercentPills.count(a, 2) == 10, [base, a.param(2)])
	_check("pill_cannot_eat", XPercentPills.valid(XDB.rec("Items", 2883), a) == 0 and not XPercentPills.apply(XDB.rec("Items", 2883), a) and XPercentPills.count(a, 2) == 10)
	# 旧档：带计数存、读，读入不报错，计数原样、属性仍不算
	kit.save()
	var s2 := kit.reload()
	var a2 := s2.actor(int(s2.battle_slots[0])) if s2 != null else null
	_check("pill_old_save_loads", a2 != null and XPercentPills.count(a2, 2) == 10 and a2.param(2) == base, [a2.param(2) if a2 else null, base])
	# 开关关：回到原样（计数照算、能吃、商店有）
	XTianqiLedger.NO_PILLS = false
	a2.param_mark_dirty()
	var on_param := a2.param(2)
	var goods_off := XItemMarks.shop_goods([[0, 1693, 0, 0]])
	_check("pill_switch_off", on_param > base and XPercentPills.valid(XDB.rec("Items", 2883), a2) == 1 and goods_off.any(func(g): return int(g[1]) == 2882) and not XTianqiLedger.pill_delisted(1693), [on_param, base])
	XTianqiLedger.NO_PILLS = true
	# 西游档：照旧
	var x := _state(false)
	var xa := x.actor(int(x.battle_slots[0]))
	var xb := xa.param(2)
	xa.state_data[XPercentPills.FIELD] = {"2": 10}
	xa.param_mark_dirty()
	_check("pill_xiyou_same", xa.param(2) > xb and not XTianqiLedger.pill_delisted(1693) and XItemMarks.shop_goods([[0, 1693, 0, 0]]).any(func(g): return int(g[1]) == 2882))


# ---- 二、九线封顶 ----
func _secret_books(n: int) -> Array:
	var out := []
	var seen_sc := {}
	var per_pct := XTianqiBase.secret_slot(XTianqiLedger.nine_cap("secret_slot")) * 100.0
	var re_harm := RegEx.create_from_string("<passiveHarmRi\\s*:\\s*(\\d+)")
	# 核查 P1：先取真功法（类型 6）、再取通用被动书（类型 4），都要由书教、判进秘籍桶；
	# T443 功法重标后同门互顶且单本 ≤15%，故只取不同门且当前视图 passiveHarmRi > per_pct 的书验证单本封顶
	for want in [6, 4]:
		for sk0 in XDB.table("Skills"):
			if not (sk0 is Dictionary):
				continue
			var sid := int(sk0.get("id", 0))
			if sid <= 0 or out.has(sid):
				continue
			var sk := XDB.rec("Skills", sid)
			if int(sk.get("stypeId", 0)) != want or not XTianqiLedger.is_secret_skill(sid, want):
				continue
			if XTianqiSecrets.is_banned_skill(sid):
				continue
			var sc := XTianqiSecrets.school_of(sid)
			if sc != "" and seen_sc.has(sc):
				continue
			var m := re_harm.search(str(sk.get("note", "")))
			if m != null and float(m.get_string(1)) > per_pct:
				out.append(sid)
				if sc != "":
					seen_sc[sc] = true
				if out.size() >= n:
					return out
	return out


func _calc(a, b) -> Dictionary:
	return XDamage.calculate(XDB.rec("Skills", 1), a, b, {"critical": false, "variance": false})


func _nine_cap() -> void:
	var s := _state()
	var a := s.actor(int(s.battle_slots[0]))
	var e := XEnemy.new().setup(1, 3, 100.0)
	# 核查 P1：判桶口径——真功法（6）、通用被动书（4）由书教的进秘籍；羁绊这类没书教的「其他」、号卷、种族技能不进
	var sk_of := func(id: int) -> Dictionary: return XDB.rec("Skills", id)
	var cases := {7144: "secret", 7145: "secret", 2776: "secret", 6137: "secret", 1077: "actor", 1126: "actor", 7238: "actor"}
	var wrong := []
	for id in cases:
		var got := XTianqiLedger.bucket_of(sk_of.call(id), a)
		if got != cases[id]:
			wrong.append([id, got])
	# 复核 P2①：公共事件（物品效果 44）教的通用被动书也占秘籍格
	var ce_books := [5189, 5214, 5308, 3680, 3184, 3687, 5091, 5098]
	var ce_miss := ce_books.filter(func(id): return XTianqiLedger.bucket_of(sk_of.call(id), a) != "secret")
	_check("bucket_secret_ce_books", ce_miss.is_empty(), ce_miss)
	_check("bucket_secret_by_book", wrong.is_empty() and int(sk_of.call(7144).stypeId) == 6 and int(sk_of.call(2776).stypeId) == 4 and int(sk_of.call(1077).stypeId) == 5, wrong)
	var slots := XTianqiLedger.secret_slots(a)
	_check("secret_slots_by_tier", slots == XTianqiBalance.secret_cap(XTianqiSkills.tier_of(a)) and slots > 0, slots)
	# 正式秘籍格与重标数据由 B2 专项覆盖。这里恢复两个旧视图，实际造出超格、超单本上限的回退档。
	var books_enabled := XTianqiGeneralBooks.ENABLED
	var secrets_enabled := XTianqiSecrets.ENABLED
	XTianqiGeneralBooks.ENABLED = false
	XTianqiSecrets.ENABLED = false
	var books := _secret_books(slots + 3)
	_check("secret_books_found", books.size() == slots + 3, books)
	# 一本书：没超（≤8% 的不变；超了也只封到 8%）
	a.learn_skill(int(books[0]))
	a.refresh_passive()
	var one := _calc(a, e)
	var by: Dictionary = a.passive_cache().get("bySource", {})
	var raw1 := float(by.get("globalHarmRi", {}).get("secret", 0.0))
	XTianqiLedger.CAP_NINE = false
	var one_off := _calc(a, e)
	XTianqiLedger.CAP_NINE = true
	var per := XTianqiBase.secret_slot(XTianqiLedger.nine_cap("secret_slot"))
	var cut1 := maxf(0.0, raw1 - per)
	_check("cap_one_book", is_equal_approx(float(one.breakdown.row.terminal), float(one_off.breakdown.row.terminal) - cut1), [raw1, one.breakdown.row.terminal, one_off.breakdown.row.terminal])
	# 学满格数＋3：只算前 slots 本，每本 ≤per（D274 为 15%）
	for id in books.slice(1):
		a.learn_skill(int(id))
	a.refresh_passive()
	by = a.passive_cache().get("bySource", {})
	var kept := XTianqiLedger.secret_kept(a, by)
	_check("secret_kept_count", kept.size() == slots, kept)
	var res := _calc(a, e)
	XTianqiLedger.CAP_NINE = false
	var res_off := _calc(a, e)
	XTianqiLedger.CAP_NINE = true
	var raw := float(by.globalHarmRi.get("secret", 0.0))
	var terminal_drop := float(res_off.breakdown.row.terminal) - float(res.breakdown.row.terminal)
	_check("cap_secret_slots", terminal_drop > 0.0 and is_equal_approx(terminal_drop, raw - per * slots) and res.breakdown.row.has("nineCap"), [raw, slots, per, terminal_drop, res.breakdown.row.get("nineCap")])
	_check("cap_value_lower", float(res.value) < float(res_off.value), [res.value, res_off.value])
	XTianqiSecrets.ENABLED = secrets_enabled
	XTianqiGeneralBooks.ENABLED = books_enabled
	# 其余九线：③ 合计 ＋35%（套装确认阶段 ＋1 → 封到 0.35）
	var b := s.actor(int(s.battle_slots[1]))
	b.change_level(40)
	var eslots := b.equip_slots()
	for id in [4184, 4185, 4186]:
		var eq := XActor.make_equip("armor", id)
		var at := eslots.find(int(eq.etypeId))
		if at >= 0:
			b.equips[at] = eq
	b.read_touch()
	b.refresh_passive()
	b.effect_snapshot_valid = false
	b.effect_lists = {}
	var suit := XTianqiLedger.suit_confirm_add(b, e, 1)
	var rs := _calc(b, e)
	XTianqiLedger.CAP_NINE = false
	var rs_off := _calc(b, e)
	XTianqiLedger.CAP_NINE = true
	var nine_bonus := suit
	var bys: Dictionary = b.passive_cache().get("bySource", {})
	for k in XTianqiLedger.NINE_BUCKETS:
		nine_bonus += float(bys.get("globalHarmRi", {}).get(k, 0.0))
	var want := maxf(0.0, nine_bonus - 0.35)
	_check("cap_nine_bonus_35", suit >= 1.0 and is_equal_approx(float(rs_off.breakdown.row.terminal) - float(rs.breakdown.row.terminal), want), [suit, nine_bonus, rs.breakdown.row.terminal, rs_off.breakdown.row.terminal])
	# 属性：套装属性倍率 ×1.5 → 封到 1.3
	_check("param_cap", is_equal_approx(XTianqiLedger.param_cap(b, 2, 1.0, 1.5), 1.3 / 1.5) and XTianqiLedger.param_cap(b, 2, 1.0, 1.2) == 1.0)
	# 核查 P2②：特性 21 是加算（traits_pi＝1＋Σ(v−1)），宝珠镶进去的认 _codexOrb；超出从特性那份扣
	var eq0 = b.stat_equips()[0]
	(eq0.traits as Array).append({"code": 21, "dataId": 2, "value": 1.5, "_codexOrb": "ledger_test:1"})
	var base := b.traits_pi(21, 2)
	var f_orb := XTianqiLedger.param_cap(b, 2, base, 1.0)
	var f_mix := XTianqiLedger.param_cap(b, 2, base, 1.1)
	(eq0.traits as Array).pop_back()
	_check("param_cap_additive_orb", is_equal_approx(f_orb, (base - 0.2) / base) and is_equal_approx(f_mix, (base - 0.3) / base) and base >= 1.5, [base, f_orb, f_mix])
	# 复核 P1：同族宝珠超过上限（familyCap，3）丢掉的那颗不算九线：4 件各镶一颗同族 +36%，只算 3 颗，封顶后不低于 1.0
	var fa := s.actor(int(s.battle_slots[2]))
	var eqs: Array = fa.equips.filter(func(x): return x is Dictionary and not x.is_empty())
	var cslots := fa.equip_slots()
	for id in [4184, 4185, 4186, 4187, 4188]:
		if eqs.size() >= 4:
			break
		var made := XActor.make_equip("armor", id)
		var at2 := cslots.find(int(made.etypeId))
		if at2 >= 0 and (fa.equips[at2] == null or (fa.equips[at2] is Dictionary and fa.equips[at2].is_empty())):
			fa.equips[at2] = made
			eqs.append(made)
	var fam := []
	for k in mini(4, eqs.size()):
		var tr := {"code": 21, "dataId": 2, "value": 1.36, "_codexOrb": "ledger_fam:5"}
		(eqs[k].traits as Array).append(tr)
		fam.append([eqs[k], tr])
	fa.read_touch()
	var cbase := fa.traits_pi(21, 2)
	var fc := XTianqiLedger.param_cap(fa, 2, cbase, 1.0)
	for pr in fam:
		(pr[0].traits as Array).erase(pr[1])
	fa.read_touch()
	_check("param_cap_family_drop", fam.size() == 4 and is_equal_approx(fc, (cbase - (3 * 0.36 - 0.3)) / cbase) and cbase * fc >= 1.0, [fam.size(), cbase, fc, cbase * fc])
	# 核查 P2③：虚空～风借火～暗最低的一系，封顶前后照同样取法扣
	var keep_yep = eq0.get("yep", {}).duplicate(true)
	var yep: Dictionary = eq0.get("yep", {}).duplicate(true)
	var amp := {}
	for c in [2, 3, 4, 5, 6, 7, 8, 9]:
		amp[str(c)] = 0.5
	yep["elementAmplify"] = amp
	eq0["yep"] = yep
	b.read_touch()
	b._pm_base = {}
	b.refresh_passive()
	var frame := {"normalAdd": 0.0, "finalAdd": 0.0, "criticalAdd": 0.0, "elementAdd": {}}
	var cut := XTianqiLedger.apply_nine_cap(XDB.rec("Skills", 1), b, frame, b.passive_cache(), {})
	eq0["yep"] = keep_yep
	b.read_touch()
	b._pm_base = {}
	b.refresh_passive()
	var c11 := float(cut.get("element", {}).get(11, 0.0))
	_check("cap_elements_11_15", is_equal_approx(float(cut.get("element", {}).get(2, 0.0)), 0.2) and is_equal_approx(c11, 0.2) \
		and is_equal_approx(float(frame.elementAdd.get("15", 0.0)), -0.2) and is_equal_approx(float(frame.elementAdd.get("9", 0.0)), -0.2), [cut, frame.elementAdd])
	# 西游档：不封
	var x := _state(false)
	var xa := x.actor(int(x.battle_slots[0]))
	for id in books:
		xa.learn_skill(int(id))
	xa.refresh_passive()
	var xr := _calc(xa, e)
	_check("cap_xiyou_none", not xr.breakdown.row.has("nineCap") and not xa.passive_cache().has("bySource") and XTianqiLedger.param_cap(xa, 2, 1.0, 2.0) == 1.0)


# ---- 三、回合预算 ----
func _budget() -> void:
	var s := _state()
	var u := s.actor(int(s.battle_slots[0]))
	var v := s.actor(int(s.battle_slots[1]))
	var en := XEnemy.new().setup(1, 3, 100.0)
	var L := FakeLogic.new()
	L.actors = [u, v]
	L.enemies = [en]
	# 只排了一次：行动完（已行动 1、顺序里没了）还能多 1 次
	L._acted = {u: 1}
	L.current_order = [v]
	var first := XTianqiLedger.take_extra(L, u, "test.push")
	L.current_order.push_front(u)
	var second := XTianqiLedger.take_extra(L, u, "test.push")
	var recast := XTianqiLedger.take_extra(L, u, "test.recast", true)
	_check("budget_one_extra", first and not second and not recast, XTianqiLedger._budget(L).log)
	# 掷出来的再动（顺序里排两次）占掉预算：第一次行动完问，不给
	L.turn = 2
	L._acted = {u: 1}
	L.current_order = [u, v]
	_check("budget_rolled_takes_it", not XTianqiLedger.take_extra(L, u, "test.push") and not XTianqiLedger.take_extra(L, u, "test.recast", true))
	# 再释放记数：一回合一次
	L.turn = 3
	L._acted = {u: 1}
	L.current_order = [v]
	var r1 := XTianqiLedger.take_extra(L, u, "test.recast", true)
	var r2 := XTianqiLedger.take_extra(L, u, "test.recast", true)
	var p1 := XTianqiLedger.take_extra(L, u, "test.push")
	_check("budget_recast_shared", r1 and not r2 and not p1)
	# 行动中途问（流萤）：这次还没记进已行动
	L.turn = 4
	L._acted = {}
	L.current_order = [v]
	var mid := XTianqiLedger.take_extra(L, u, "test.mid", true, true)
	var mid2 := XTianqiLedger.take_extra(L, u, "test.mid", true, true)
	_check("budget_in_action", mid and not mid2)
	# 不造成伤害的 free 插队不占
	L.turn = 5
	L._acted = {u: 1}
	L.current_order = [v]
	XTianqiLedger.note_free(L, u)
	L.current_order.push_front(u)
	_check("budget_free_not_counted", XTianqiLedger.take_extra(L, u, "test.after_free"))
	# 醒来补排：不重掷，1＋1 − 已行动 − 已用再释放
	L.turn = 6
	L._acted = {u: 1}
	L.current_order = [v]
	var w1 := XTianqiLedger.wake_times(L, u)
	XTianqiLedger.take_extra(L, u, "test.recast", true)
	var w0 := XTianqiLedger.wake_times(L, u)
	_check("budget_wake_times", w1 == 1 and w0 == 0, [w1, w0])
	# 派生：每回合按表次数
	L.turn = 7
	var row := XTianqiLedger.derived_row("qiyin.single_skill_repeat")
	var n := 0
	for i in 10:
		if XTianqiLedger.take_derived(L, u, "qiyin.single_skill_repeat"):
			n += 1
	_check("derived_per_turn", n == int(row.per_turn) and n > 0, [n, row])
	# 敌人、开关关、西游档：不管
	L.turn = 8
	L._acted = {u: 1}
	L.current_order = [u, v]
	XTianqiLedger.TURN_BUDGET = false
	var off := XTianqiLedger.take_extra(L, u, "test.off") and XTianqiLedger.wake_times(L, u) == -1
	XTianqiLedger.TURN_BUDGET = true
	_check("budget_scope", off and XTianqiLedger.take_extra(L, en, "test.enemy") and XTianqiLedger.take_extra(L, en, "test.enemy"))
	var x := _state(false)
	var xu := x.actor(int(x.battle_slots[0]))
	L.actors = [xu]
	L._acted = {xu: 1}
	L.current_order = [xu]
	_check("budget_xiyou_none", XTianqiLedger.take_extra(L, xu, "test.xiyou") and XTianqiLedger.take_extra(L, xu, "test.xiyou", true))
	# 核查 P2①：云裳赠行、放行（add_actions）逐次过预算：本回合只排了一次的人最多再加 1 次
	var s2 := _state()
	var y := s2.actor(int(s2.battle_slots[2]))
	L.actors = [y]
	L.turn = 20
	L._acted = {}
	L.current_order = [y]
	var gave := XYunshang.add_actions(L, y, 2, "gift")
	var n1 := L.current_order.count(y)
	var again := XYunshang.add_actions(L, y, 1, "gift")
	_check("budget_yunshang_gift", gave and n1 == 2 and not again and L.current_order.count(y) == 2, [n1, L.current_order.count(y)])
	# 复核 P2②：手操赠行对自己施放（这次行动还没记进已行动）：in_action 时顺序里那一次就是本次，再加 1 次就满
	L.turn = 21
	L._acted = {}
	L.current_order = []
	var self1 := XYunshang.add_actions(L, y, 1, "gift", true)
	var self2 := XYunshang.add_actions(L, y, 1, "gift", true)
	_check("budget_yunshang_self_gift", self1 and not self2 and L.current_order.count(y) == 1, L.current_order.count(y))
	L.free()


# ---- 派生表：七印每个 _derived 调用点都登记、有每回合次数；预算入口都登记 ----
func _derived_table() -> void:
	var src := FileAccess.get_file_as_string("res://modes/xiyou/core/tianqi_qiyin_effects.gd")
	var bad := []
	var calls := 0
	for line in src.split("\n"):
		if line.contains("(_derived(logic") and not line.strip_edges().begins_with("static func"):
			calls += 1
			var m := RegEx.create_from_string("# (derived|recast):([\\w.]+)").search(line)
			if m == null:
				bad.append(line.strip_edges())
				continue
			if m.get_string(1) == "derived":
				var row := XTianqiLedger.derived_row(m.get_string(2))
				if row.is_empty() or (row.get("per_turn") is String and row.get("enforced") != "自管"):
					bad.append(m.get_string(2))
			elif not (XTianqiLedger.data().get("turn_budget", {}).get("recast", []) as Array).has(m.get_string(2)):
				bad.append(m.get_string(2))
	_check("derived_sites_registered", bad.is_empty() and calls >= 5, [calls, bad])
	# 模块追击：表里有、文件在、期四到期
	var mods: Array = (XTianqiLedger.data().get("derived", []) as Array).filter(func(r): return str(r.id).begins_with("module."))
	_check("derived_modules_listed", mods.size() >= 7 and mods.all(func(r): return int(r.get("expires", 0)) == 4 and FileAccess.file_exists("res://modes/xiyou/core/" + str(r.file))), mods.map(func(r): return r.id))
	# 每个接预算的源文件里确实调了 take_extra
	var sites := {"gojo.gd": "gojo.again", "yomi_jingliu.gd": "jingliu.extra", "liuying.gd": "liuying.rerelease", "race_battle.gd": "race.human996",
		"tianqi_affix_battle.gd": "affix.recast", "tianqi_qiyin_effects.gd": "qiyin.kill_extra_action", "tianqi_skills.gd": "card.free_action"}
	var miss := []
	for f in sites:
		if not FileAccess.get_file_as_string("res://modes/xiyou/core/" + f).contains("\"" + sites[f] + "\""):
			miss.append(f)
	for k in ["event.recast", "event.freeze_followup", "event.push_recast"]:
		if not FileAccess.get_file_as_string("res://modes/xiyou/battle/battle_event_runner.gd").contains("\"" + k + "\""):
			miss.append(k)
	if not FileAccess.get_file_as_string("res://modes/xiyou/battle/battle_logic.gd").contains("XTianqiLedger.wake_times"):
		miss.append("battle_logic.wake_times")
	_check("budget_sites_wired", miss.is_empty(), miss)


# ---- 四、期二补记 ----
func _notes() -> void:
	# 顺看（小A，T035 范围外）：七印 end_action 的派生在弱者专属词条里算「原生追加 FOLLOW」——行动执行完就 set_kind FOLLOW、在 root_end 之前，
	# 不是主动根 ROOT，所以不会被当主动根记命中；DERIVED 是弱者词条自己代出的派生，七印的不该归那类（不改）。这里锁住次序。
	var bl := FileAccess.get_file_as_string("res://modes/xiyou/battle/battle_logic.gd")
	var i_follow := bl.find("XTianqiWeakAffix.set_kind(self, XTianqiWeakAffix.FOLLOW)")
	var i_qiyin := bl.find("XTianqiQiyinEffects.end_action(self, u, skill)")
	var i_root_end := bl.find("XTianqiWeakAffix.root_end(self, u)")
	_check("qiyin_derived_under_follow", i_follow > 0 and i_follow < i_qiyin and i_qiyin < i_root_end, [i_follow, i_qiyin, i_root_end])
	_check("note2_qiyin_derived_allowed", XTianqiLedger.row("qiyin_derived").get("status") == "allowed" and XTianqiLedger.row("qiyin_derived").has("phase3"))
	_check("note3_qiyin_dot_allowed", XTianqiLedger.row("qiyin_dot").get("status") == "allowed")
	_check("ledger_phase3", XTianqiLedger.phase() >= 3 and not XTianqiLedger.data().get("nine_caps", {}).is_empty())


# ---- 五、T473 漏口：原版装 tianqi_affixes／alien.tq 不逃逸九线封顶＋secret_slots 按天启档位 ----
func _t473_fixes() -> void:
	var s := _state()
	var a := s.actor(int(s.battle_slots[0]))
	var e := XEnemy.new().setup(1, 3, 100.0)
	var sample_affix := [{"key": "final_damage", "tier": 4, "grade": "perfect", "extra": {}}]
	# 1) 分桶：原版装（4535 苍琉幻生灭、4285 双鱼念气瓶、4075 三环剑、4115 苍苍白骨）贴 tianqi_affixes 或天启异化后仍归 equip；
	#    符文之语／成长装贴 tianqi_affixes 仍归 runeword／hubris；纯天启装（qiyin／tq_reward）仍归 tianqi
	var eq4535 := XActor.make_equip("armor", 4535)
	var eq4285 := XActor.make_equip("armor", 4285)
	var eq4075 := XActor.make_equip("armor", 4075)
	var eq4115 := XActor.make_equip("armor", 4115)
	for eq in [eq4535, eq4285, eq4075, eq4115]:
		XTianqiAffixRoll.set_affixes(eq, sample_affix.duplicate(true))
	var eq4535_alien := XActor.make_equip("armor", 4535)
	eq4535_alien["alien"] = {"uid": "t473-alien", "affix": "dying", "tq": {"line": "death", "level": "huaxing"}}
	var rw_affix := {"kind": "armor", "runewords": [1], "tianqi_affixes": sample_affix.duplicate(true)}
	var hub_affix := XActor.make_equip("armor", XHubris.ARMOR)
	XTianqiAffixRoll.set_affixes(hub_affix, sample_affix.duplicate(true))
	var bucket_ok := XTianqiLedger.bucket_of(eq4535, a) == "equip" \
		and XTianqiLedger.bucket_of(eq4285, a) == "equip" \
		and XTianqiLedger.bucket_of(eq4075, a) == "equip" \
		and XTianqiLedger.bucket_of(eq4115, a) == "equip" \
		and XTianqiLedger.bucket_of(eq4535_alien, a) == "equip" \
		and XTianqiLedger.bucket_of(rw_affix, a) == "runeword" \
		and XTianqiLedger.bucket_of(hub_affix, a) == "hubris" \
		and XTianqiLedger.bucket_of({"kind": "weapon", "qiyin": {"kind": "weapon"}}, a) == "tianqi" \
		and XTianqiLedger.bucket_of({"kind": "armor", "tq_reward": {"kind": "seal"}}, a) == "tianqi"
	_check("t473_bucket_original_gear_with_tq_affix", bucket_ok, [
		XTianqiLedger.bucket_of(eq4535, a), XTianqiLedger.bucket_of(eq4285, a),
		XTianqiLedger.bucket_of(eq4075, a), XTianqiLedger.bucket_of(eq4115, a),
		XTianqiLedger.bucket_of(eq4535_alien, a), XTianqiLedger.bucket_of(rw_affix, a),
		XTianqiLedger.bucket_of(hub_affix, a)
	])
	# 2) 4535 苍琉幻生灭＋4285 双鱼念气瓶贴 tianqi_affixes 上身实测：原版被动全部落 equip 桶被九线封顶，tianqi 桶为 0；天启词条自身增量仍生效
	a.change_level(81)
	var eslots := a.equip_slots()
	var neck_idx := eslots.find(9)
	var off_idx := eslots.find(2)
	var old_neck = a.equips[neck_idx] if neck_idx >= 0 else null
	var old_off = a.equips[off_idx] if off_idx >= 0 else null
	var eq4535_plain := XActor.make_equip("armor", 4535)
	var eq4285_plain := XActor.make_equip("armor", 4285)
	if neck_idx >= 0:
		a.equips[neck_idx] = eq4535_plain
	if off_idx >= 0:
		a.equips[off_idx] = eq4285_plain
	a.read_touch()
	a.refresh_passive()
	# 启动一场短战斗使 XTianqiAffixBattle 激活，验证词条增量正常叠加、原版被动被九线封顶
	var bl := XBattleLogic.new()
	bl.setup(2, s)
	var probe_skill := XDB.rec("Skills", 1).duplicate(true)
	probe_skill["meta"] = probe_skill.get("meta", {}).duplicate(true)
	probe_skill["meta"]["SkillTypes"] = "[\"A\"]"
	probe_skill["damage"] = probe_skill.get("damage", {}).duplicate(true)
	probe_skill["damage"]["elementId"] = 7
	var res_plain := XDamage.calculate(probe_skill, a, e, {"critical": true, "variance": false})
	# 换成贴了 tianqi_affixes（仅 4535 挂一条 final_damage 四阶极品）的 4535＋带词条 4285（4285 换一条非伤害词条避免叠 final_damage）
	var eq4285_def := XActor.make_equip("armor", 4285)
	XTianqiAffixRoll.set_affixes(eq4285_def, [{"key": "def", "tier": 4, "grade": "normal", "extra": {}}])
	if neck_idx >= 0:
		a.equips[neck_idx] = eq4535
	if off_idx >= 0:
		a.equips[off_idx] = eq4285_def
	a.read_touch()
	a.refresh_passive()
	var by4535: Dictionary = a.passive_cache().get("bySource", {})
	var res_affix := XDamage.calculate(probe_skill, a, e, {"critical": true, "variance": false})
	XTianqiAffixBattle.finish(bl)
	XAlienBattle.finish(bl, [])
	var cut4535: Dictionary = res_affix.breakdown.row.get("nineCap", {})
	var affix_fd := float(XTianqiAffixTable.value("final_damage", 4, "perfect")) / 100.0
	var elem7_eq := float(by4535.get("elementAmplify", {}).get(7, {}).get("equip", 0.0))  # T532：普通防具本体元素伤全身合计封 +20%，到不了旧九线元素顶 30%，元素那一刀为 0
	var pools_ok := float(by4535.get("globalHarmRi", {}).get("tianqi", 0.0)) == 0.0 \
		and float(by4535.get("critHarmRi", {}).get("tianqi", 0.0)) == 0.0 \
		and float(by4535.get("elementAmplify", {}).get(7, {}).get("tianqi", 0.0)) == 0.0 \
		and float(by4535.get("globalHarmRi", {}).get("equip", 0.0)) >= 1.75 - 1e-4 \
		and float(by4535.get("critHarmRi", {}).get("equip", 0.0)) >= 3.00 - 1e-4 \
		and float(by4535.get("skillTypeDvup", {}).get("A", {}).get("equip", 0.0)) >= 2.15 - 1e-4 \
		and elem7_eq > 0.0 and elem7_eq <= XTianqiGear.armor_cap_pct() / 100.0 + 1e-6 \
		and float(cut4535.get("bonus", 0.0)) >= 1.40 - 1e-4 \
		and float(cut4535.get("crit", 0.0)) >= 2.70 - 1e-4 \
		and float(cut4535.get("skill", 0.0)) >= 2.00 - 1e-4 \
		and is_equal_approx(float(cut4535.get("element", {}).get(7, 0.0)), maxf(0.0, elem7_eq - 0.30)) \
		and is_equal_approx(float(res_affix.breakdown.row.terminal) - float(res_plain.breakdown.row.terminal), affix_fd) \
		and is_equal_approx(float(res_affix.breakdown.row.critical), float(res_plain.breakdown.row.critical))
	_check("t473_4535_affix_capped_all_pools", pools_ok, {
		"by_fin": by4535.get("globalHarmRi", {}),
		"by_crit": by4535.get("critHarmRi", {}),
		"by_elem7": by4535.get("elementAmplify", {}).get(7, {}),
		"cut": cut4535,
		"term_diff": float(res_affix.breakdown.row.terminal) - float(res_plain.breakdown.row.terminal),
		"affix_fd": affix_fd,
	})
	if neck_idx >= 0:
		a.equips[neck_idx] = old_neck
	if off_idx >= 0:
		a.equips[off_idx] = old_off
	a.read_touch()
	a.refresh_passive()
	# 3) NINE_OFF：原版装带特性 34／61 贴 tianqi_affixes 或 alien.tq 后仍受 NINE_OFF 停用，不逃逸
	var extra_eq := {"kind": "weapon", "traits": [{"code": 34, "dataId": 0, "value": 1.0}, {"code": 61, "dataId": 0, "value": 1.0}], "tianqi_affixes": sample_affix.duplicate(true)}
	_check("t473_nine_off_not_escaped_by_affix", XTianqiLedger.nine_off_source(a, extra_eq) and XTianqiLedger.nine_off_source(a, eq4535_alien))
	# 4) secret_slots：天启篇按天启档位（三笠 95→3、绿司机 2→4、维利 22→4、艾坤 3→6），西游档照 XTier 零改动（4/6/6/6）
	var tq_slots := [XTianqiLedger.secret_slots(s.actor(95), s), XTianqiLedger.secret_slots(s.actor(2), s),
		XTianqiLedger.secret_slots(s.actor(22), s), XTianqiLedger.secret_slots(s.actor(3), s)]
	var xs := _state(false)
	var xy_slots := [XTianqiLedger.secret_slots(xs.actor(95), xs), XTianqiLedger.secret_slots(xs.actor(2), xs),
		XTianqiLedger.secret_slots(xs.actor(22), xs), XTianqiLedger.secret_slots(xs.actor(3), xs)]
	_check("t473_ledger_secret_slots_tq_tier", tq_slots == [3, 4, 4, 6] and xy_slots == [4, 6, 6, 6], {"tq": tq_slots, "xy": xy_slots})
