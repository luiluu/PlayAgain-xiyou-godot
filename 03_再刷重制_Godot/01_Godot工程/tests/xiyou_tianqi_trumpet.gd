extends Node
## 天启篇号卷（XTianqiTrumpet，权能书重做方案 v0.4）专项：
## 一、记录：天启篇存档里七卷道具、技能换名换说明，原洪荒效果标签去掉；遗忘符叫封卷；退役三本、原版档不动。
## 二、学习：弱者 3、强者 2、超强者 1；满了的提示；原 CodexParamRate 在天启篇不算。
## 三、掉落：只在炼狱、证道的不朽存在；起步 3%×全队掉率、没出 +3%、出了不再掉；分段；原版档照旧走洪荒。
## 四、商店：封卷只在炼狱、证道上架。
## 五、战斗：初号范围／单体、二号残血／满血、三号持续效果与受治疗、四号承伤／留一口气／暴击、五号站起来与之后减伤、
##    六号先手／免消耗／第 6 回合起减伤、七号掉率与金钱、七号齐鸣；整回合实跑不报错。
## 五之二、六号全免（Kyo 11-14 真全免）：走真 XBattleLogic.can_use＋pay_skill_cost，MP、TP、HP 定值／比例、物品第 1 回合不看不扣，
##    第 2 回合、非持有者照扣照挡；FREE_ALL 关掉回到只免 MP／TP。
## 五之三、五号起身那一回合的行动顺序：中途阵亡（带追加行动）、终焉锁复活、开场就阵亡（第 1 回合起身不行动、第 2 回合照常）。
## 六、开关关掉：一条都不生效。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a, b) -> bool:
	return a != null and absf(float(a) - float(b)) < 0.0001


func _weak() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id) and XTianqiSkills.tier_of(id, true) == XTier.WEAK)


func _state(key := "lianyu") -> XState:
	var w := _weak()
	var lineup := [w[0], w[1], w[2], w[3], w[5]]
	var s := XTianqi.start_new_game(3, key, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		s.actor(id).recover_all()
	return s


func _logic(s: XState) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	return lg


func _learn(a: XActor, n: int) -> void:
	var id := int(XTianqiTrumpet.scroll(n).skill)
	if not a.skill_ids.has(id):
		a.skill_ids.append(id)
	a.refresh_passive()


func _op(ops: Array, field: String) -> Variant:
	var add := 0.0
	var mul := 1.0
	var seen := false
	for o in ops:
		if str(o.field) == field:
			seen = true
			if str(o.op) == "add":
				add += float(o.value)
			else:
				mul *= float(o.value)
	if not seen:
		return null
	return add if add != 0.0 else mul


func _skill(scope: int, type := 1) -> Dictionary:
	return {"id": 99999, "scope": scope, "damage": {"type": type, "elementId": 0, "critical": true, "variance": 0, "formula": "1"}, "effects": [], "stypeId": 1, "mpCost": 100, "tpCost": 20}


func _run() -> void:
	XMessageBox.auto = true
	seed(20261114)
	_records()
	_learning()
	_drops()
	_shop()
	_battle()
	_cavalry_pay()
	_abyss_order()
	_switches()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _records() -> void:
	var s := XState.new()
	XState.current = s
	_check("plain.item_name", str(XDB.rec("Items", 1654).name) == "权能书：时之主宰", XDB.rec("Items", 1654).name)
	_check("plain.forget_name", str(XDB.rec("Items", 3044).name) == "权能遗忘符")
	_check("plain.skill_tags", XDB.rec("Skills", 7238).meta.has("passiveHarmRi"))
	_state()
	var it := XDB.rec("Items", 1654)
	_check("tq.item_name", str(it.name) == "号卷：初号·雹火", it.name)
	_check("tq.item_power", XPowerBooks.book_skill(it) == 7238)
	_check("tq.item_segment", str(it.meta.get("CodexPower", "")).strip_edges() == "1", it.meta)
	var sk := XDB.rec("Skills", 7238)
	_check("tq.skill_name", str(sk.name) == "初号·雹火", sk.name)
	_check("tq.skill_tags_gone", not sk.meta.has("passiveHarmRi") and not sk.meta.has("ConsumeReduceAll") and not str(sk.note).contains("StartPushState"), sk.meta)
	_check("tq.skill_marker", str(sk.meta.get("TianqiTrumpet", "")).strip_edges() == "1")
	_check("tq.seven", XDB.rec("Items", 1718).name == "号卷：七号·赏赐" and XDB.rec("Skills", 7247).name == "七号·赏赐")
	_check("tq.forget", str(XDB.rec("Items", 3044).name) == "封卷" and XTianqiTrumpet.forget_name() == "封卷")
	_check("tq.retired_untouched", str(XDB.rec("Items", 1656).name) == "权能书：命运指引")
	_check("tq.cached_same", is_same(XDB.rec("Skills", 7238), XDB.rec("Skills", 7238)))
	# 七卷号码、道具号、技能号各不相同；分段按吹号的次序
	var segs := XTianqiTrumpet.scrolls().map(func(x): return int(x.segment))
	_check("table.segments", segs == [1, 1, 2, 3, 4, 5, 5], segs)
	_check("table.seven", XTianqiTrumpet.scrolls().size() == 7)


func _learning() -> void:
	var s := _state()
	var weak: XActor = s.members()[0]
	_check("limit.weak", XPowerBooks.limit(weak) == 3, XPowerBooks.limit(weak))
	var strong := XTianqiSkills.ids(XTier.STRONG).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var sup := XTianqiSkills.ids(XTier.SUPER).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	for pair in [[strong, 2, "limit.strong"], [sup, 1, "limit.super"]]:
		var ids: Array = pair[0]
		_check(pair[2] + ".found", not ids.is_empty())
		if ids.is_empty():
			continue
		XTianqi._joining = true
		s.add_actor(int(ids[0]))
		XTianqi._joining = false
		var x := s.actor(int(ids[0]))
		_check(pair[2], XPowerBooks.limit(x) == int(pair[1]), [ids[0], XPowerBooks.limit(x)])
	for n in [1, 2, 3]:
		_check("learn.ok%d" % n, XPowerBooks.can_learn(weak, int(XTianqiTrumpet.scroll(n).skill)))
		_learn(weak, n)
	var why := XPowerBooks.learn_reason(weak, int(XTianqiTrumpet.scroll(4).skill))
	_check("learn.full", why.contains("3卷号卷") and why.contains("封卷"), why)
	_check("learn.same", XPowerBooks.learn_reason(weak, int(XTianqiTrumpet.scroll(1).skill)) == "已经学会这卷号卷")
	_learn(weak, 4)  # 四号原来是死之掌握（CodexParamRate 物攻魔攻 +50%）
	_check("rate.skipped", XPowerBooks.param_rate_bonus(weak, 2) == 0.0, XPowerBooks.param_rate_bonus(weak, 2))
	s.gain_item(XPowerBooks.FORGET_ITEM, 1)
	var r := XPowerBooks.forget_paid(s, weak, int(XTianqiTrumpet.scroll(4).skill))
	_check("forget.ok", bool(r.ok) and not XTianqiTrumpet.has(weak, 4))
	_check("forget.missing_word", str(XPowerBooks.forget_paid(s, weak, int(XTianqiTrumpet.scroll(1).skill)).reason).contains("封卷"))


func _immortal(s: XState) -> int:
	s.map_id = 177  # 未知区域（不朽存在不配对），敌群 584～589
	return 584


func _drops() -> void:
	var s := _state("lianyu")
	var troop := _immortal(s)
	_check("drop.eligible_lianyu", XTianqiTrumpet.eligible(s, troop) == true)
	_check("drop.not_normal_troop", XTianqiTrumpet.eligible(s, 2) == false)
	XHonghuang.battle_started(s, troop)
	_check("drop.hh_eligible", bool(XHonghuang.power_battle.eligible), XHonghuang.power_battle)
	var floor_no := int(XHonghuang.power_battle.floor)
	var seg := XTianqiTrumpet.segment(floor_no)
	var in_seg := XTianqiTrumpet.scrolls().filter(func(x): return int(x.segment) == seg).map(func(x): return int(x.n))
	var mult := XTianqiDrop.party_mult(s)
	_check("drop.chance_start", _near(XTianqiTrumpet.chance(s, int(in_seg[0])), 0.03 * mult), [XTianqiTrumpet.chance(s, int(in_seg[0])), mult])
	XHonghuang.battle_ended(0)
	var r := XHonghuang.roll_power(s, func(): return 0.99)
	_check("drop.miss", r.got.is_empty() and not r.has("x"), r)
	_check("drop.fail_counted", int(XTianqiTrumpet.store(s).fails.get(str(in_seg[0]), 0)) == 1)
	_check("drop.chance_rises", _near(XTianqiTrumpet.chance(s, int(in_seg[0])), 0.06 * mult), XTianqiTrumpet.chance(s, int(in_seg[0])))
	_check("drop.once_per_battle", XHonghuang.roll_power(s, func(): return 0.0).got.is_empty())
	XHonghuang.battle_started(s, troop)
	XHonghuang.battle_ended(0)
	r = XHonghuang.roll_power(s, func(): return 0.0)
	var want := in_seg.map(func(n): return int(XTianqiTrumpet.scroll(n).item))
	_check("drop.hit", r.got == want and s.item_count(int(want[0])) == 1, [r, want])
	_check("drop.toast", str(r.toasts[0]).contains("号卷："), r.toasts)
	_check("drop.reset_fail", not XTianqiTrumpet.store(s).fails.has(str(in_seg[0])))
	XHonghuang.battle_started(s, troop)
	XHonghuang.battle_ended(0)
	_check("drop.only_once", XHonghuang.roll_power(s, func(): return 0.0).got.is_empty() and s.item_count(int(want[0])) == 1)
	# 分段：0～15 一段（初号、二号），26 层起第五段（六号、七号）
	_check("seg.floor1", XTianqiTrumpet.segment(1) == 1 and XTianqiTrumpet.segment(16) == 2 and XTianqiTrumpet.segment(22) == 4 and XTianqiTrumpet.segment(30) == 5)
	# 别的档不掉
	var low := _state("jianxian")
	troop = _immortal(low)
	_check("drop.not_jianxian", XTianqiTrumpet.eligible(low, troop) == false)
	XHonghuang.battle_started(low, troop)
	_check("drop.hh_not_eligible", not bool(XHonghuang.power_battle.eligible))
	# 原版档：照洪荒开关（不开就不掉、开了照原版）
	var plain := XState.new()
	XState.current = plain
	plain.map_id = 177
	_check("drop.plain_null", XTianqiTrumpet.eligible(plain, 584) == null)
	XHonghuang.battle_started(plain, 584)
	_check("drop.plain_off", not bool(XHonghuang.power_battle.eligible))
	plain.set_switch(2483, true)
	XHonghuang.battle_started(plain, 584)
	_check("drop.plain_honghuang", bool(XHonghuang.power_battle.eligible))


func _shop() -> void:
	var goods := [[2, 5200, 0, 0, false], [0, 1990, 0, 0], [0, 3044, 0, 0]]
	var s := _state("jianxian")
	_check("shop.hidden", XTianqiTrumpet.shop_goods(s, goods).size() == 2)
	s = _state("lianyu")
	_check("shop.lianyu", XTianqiTrumpet.shop_goods(s, goods).size() == 3)
	XState.current = XState.new()
	_check("shop.plain", XTianqiTrumpet.shop_goods(XState.current, goods).size() == 3)


func _battle() -> void:
	var s := _state()
	var ms: Array = s.members()
	var a: XActor = ms[0]
	var b: XActor = ms[1]
	var c: XActor = ms[2]
	var d: XActor = ms[3]
	_learn(a, 1)
	_learn(a, 2)
	_learn(a, 3)
	_learn(b, 4)
	_learn(b, 5)
	_learn(b, 6)
	_learn(c, 7)
	var lg := _logic(s)
	XTianqiTrumpet.start(lg)
	var e: XEnemy = lg.enemies[0]
	lg.turn = 2
	# 初号
	e.hp = e.mhp * 0.5
	_check("hail.aoe", _near(_op(XTianqiTrumpet.damage_ops(_skill(2), a, e), "finalAdd"), 0.2))
	_check("hail.single", _near(_op(XTianqiTrumpet.damage_ops(_skill(1), a, e), "finalAdd"), -0.1))
	_check("hail.ally_heal_none", _op(XTianqiTrumpet.damage_ops(_skill(8, 3), a, b), "healingMultiplier") == null)
	# 二号
	e.hp = floorf(e.mhp * 0.2)
	_check("blood.low", _near(_op(XTianqiTrumpet.damage_ops(_skill(2), a, e), "finalAdd"), 0.7))
	e.hp = e.mhp
	_check("blood.high", _near(_op(XTianqiTrumpet.damage_ops(_skill(2), a, e), "finalAdd"), 0.1))
	# 三号：受治疗、持续效果
	_check("worm.heal", _near(_op(XTianqiTrumpet.damage_ops(_skill(7, 3), b, a), "healingMultiplier"), 0.8))
	_check("worm.dot", _near(XTianqiTrumpet.dot_value(a, 100.0), 133.0))
	_check("worm.dot_other", _near(XTianqiTrumpet.dot_value(b, 100.0), 100.0))
	var harm := -1
	for st in XDB.table("States"):
		if st is Dictionary and int(st.get("id", 0)) > 10 and XSmartAI.harmful_state(int(st.id)) and int(st.get("autoRemovalTiming", 0)) == 2 and int(st.get("minTurns", 0)) == 3 and int(st.get("maxTurns", 0)) == 3:
			harm = int(st.id)
			break
	if harm > 0:
		e.state_turns[harm] = 3
		XTianqiTrumpet.state_added(e, harm, a)
		_check("worm.debuff_turns", int(e.state_turns[harm]) == 4, e.state_turns[harm])  # ceil(3×1.33)
		e.state_turns[harm] = 3
		XTianqiTrumpet.state_added(e, harm, b)
		_check("worm.debuff_other", int(e.state_turns[harm]) == 3)
	else:
		_check("worm.debuff_state_found", false)
	# 四号：承伤、暴击、留一口气（每场一次）
	_check("eclipse.taken", _near(_op(XTianqiTrumpet.damage_ops(_skill(1), e, b), "incomingMultiplier"), 0.9))
	_check("eclipse.crit", _near(XTianqiTrumpet.cri(b, 0.5), 0.4) and _near(XTianqiTrumpet.cri(b, 0.05), 0.0) and _near(XTianqiTrumpet.cri(a, 0.5), 0.5))
	b.hp = 100.0
	var v := XTianqiTrumpet.hp_damage(lg, e, b, 99999.0)
	_check("eclipse.save", _near(v, 100.0 + b.shield - 1.0), v)
	_check("eclipse.save_once", _near(XTianqiTrumpet.hp_damage(lg, e, b, 99999.0), 99999.0))
	_check("eclipse.not_lethal", _near(XTianqiTrumpet.hp_damage(lg, e, a, 1.0), 1.0))
	# 六号：第 1 回合先手、免消耗；第 6 回合起 −10%
	lg.turn = 1
	var cost := XTianqiTrumpet.cost(b, _skill(1), {"mp": 50, "tp": 20})
	_check("cavalry.free", int(cost.mp) == 0 and int(cost.tp) == 0)
	_check("cavalry.others_pay", int(XTianqiTrumpet.cost(a, _skill(1), {"mp": 50, "tp": 20}).mp) == 50)
	lg.current_order = [e, a, e, b, c]
	XTianqiTrumpet.start_turn(lg)
	_check("cavalry.first", lg.current_order[0] == b and lg.current_order.count(b) == 1 and lg.current_order.size() == 5)
	lg.turn = 2
	_check("cavalry.paid_later", int(XTianqiTrumpet.cost(b, _skill(1), {"mp": 50, "tp": 20}).mp) == 50)
	lg.turn = 6
	e.hp = e.mhp * 0.5
	_check("cavalry.late", _near(_op(XTianqiTrumpet.damage_ops(_skill(1), b, e), "finalAdd"), -0.1))
	# 五号：死了下一回合开始站起来，之后 −20%，一场一次
	b.add_state(1)
	b.hp = 0.0
	XTianqiTrumpet.turn_begin(lg)
	_check("abyss.rise", b.is_alive() and _near(b.hp, maxf(1.0, floorf(b.mhp * 0.33))), [b.is_alive(), b.hp, b.mhp])
	_check("abyss.after", _near(_op(XTianqiTrumpet.damage_ops(_skill(1), b, e), "finalAdd"), -0.3))  # 起身 −20 ＋ 第 6 回合起 −10
	b.add_state(1)
	b.hp = 0.0
	XTianqiTrumpet.turn_begin(lg)
	_check("abyss.once", b.is_dead())
	b.remove_state(1)
	b.recover_all()
	# 七号：掉率、金钱
	var src := XTianqiDrop.sources_of(c).filter(func(x): return str(x.name) == "七号·赏赐")
	_check("reward.drop_source", src.size() == 1 and _near(src[0].value, 30.0), src)
	var out := {"exp": 100, "gold": 1000}
	XTianqiTrumpet.gold(lg, out)
	_check("reward.gold", int(out.gold) == 700, out)
	# 齐鸣：上场的四个人凑齐了七卷（a 1～3、b 4～6、c 7）
	_check("chorus.yes", XTianqiTrumpet.chorus(lg) == (lg.actors.has(a) and lg.actors.has(b) and lg.actors.has(c)), lg.actors.size())
	lg.turn = 1
	e.hp = e.mhp * 0.5
	if XTianqiTrumpet.chorus(lg):
		_check("chorus.first_turn", _near(_op(XTianqiTrumpet.damage_ops(_skill(7), d, e), "finalAdd"), 0.1))
	lg.turn = 2
	_check("chorus.only_turn1", _op(XTianqiTrumpet.damage_ops(_skill(7), d, e), "finalAdd") == null)
	lg.end_battle(0)
	# 七号挪到助力位：齐鸣没了，掉率照算
	var helpers := XTianqiAffixBattle.members(s).filter(func(m): return not ms.slice(0, 4).has(m))
	_check("helper.found", not helpers.is_empty(), XTianqiAffixBattle.members(s).size())
	if not helpers.is_empty():
		c.skill_ids.erase(int(XTianqiTrumpet.scroll(7).skill))
		_learn(helpers[0], 7)
		var lg2 := _logic(s)
		_check("chorus.helper_not_counted", not XTianqiTrumpet.chorus(lg2) and lg2.actors.has(c), lg2.actors.size())
		out = {"exp": 100, "gold": 1000}
		XTianqiTrumpet.gold(lg2, out)
		_check("helper.gold", int(out.gold) == 700)
		_check("helper.drop", XTianqiDrop.party_bonus(s) >= 30.0, XTianqiDrop.party_bonus(s))
		lg2.end_battle(0)
	# 整回合实跑
	var lg3 := _logic(s)
	_check("run.started", lg3.has_meta("xtrumpet"))
	for k in 3:
		if lg3.is_over():
			break
		lg3.run_turn({})
	_check("run.turns", lg3.turn >= 1, lg3.turn)
	lg3.end_battle(0)
	_check("run.cleared", not lg3.has_meta("xtrumpet"))


## 带费用的测试技能：stypeId 0 不看技能类别，id 用不存在的号免得撞上各角色的专属规则
func _cost_skill(id: int, note: String, mp := 0, tp := 0) -> Dictionary:
	return {"id": id, "name": "测试", "occasion": 0, "scope": 11, "stypeId": 0, "mpCost": mp, "tpCost": tp, "note": note,
		"damage": {"type": 0, "elementId": 0, "critical": false, "variance": 0, "formula": "0"}, "effects": []}


func _cost_item() -> int:
	for id in range(1, 200):
		if not XDB.rec("Items", id).is_empty():
			return id
	return 1


func _cavalry_pay() -> void:
	var s := _state()
	var ms: Array = s.members()
	var a: XActor = ms[0]  # 没学六号
	var b: XActor = ms[1]  # 学了六号
	_learn(b, 6)
	var lg := _logic(s)
	XTianqiTrumpet.start(lg)
	lg.turn = 1
	var item := _cost_item()
	var hp_flat := _cost_skill(99991, "<HP Cost: 500>")
	var hp_per := _cost_skill(99992, "<HP Cost: 90%>")
	var items := _cost_skill(99993, "<Item %d Cost: 3>" % item)
	var mptp := _cost_skill(99994, "", 100, 20)
	var all := _cost_skill(99995, "<HP Cost: 500>\n<Item %d Cost: 3>" % item, 100, 20)
	var poor := func(x: XActor) -> void:
		x.hp = 100.0
		x.mp = 0.0
		x.tp = 0.0
		s.gain_item(item, -s.item_count(item))
	# 第 1 回合、六号持有者：样样付不起也能放，放了一样不扣
	for sk in [hp_flat, hp_per, items, mptp, all]:
		poor.call(b)
		var tag := "cavalry.pay.%d" % int(sk.id)
		_check(tag + ".can_use", lg.can_use(b, sk), [b.hp, b.mhp])
		lg.pay_skill_cost(b, sk)
		_check(tag + ".not_paid", _near(b.hp, 100.0) and _near(b.mp, 0.0) and _near(b.tp, 0.0) and s.item_count(item) == 0, [b.hp, b.mp, b.tp, s.item_count(item)])
	# 余额够时也一样不扣（余额 0 时扣成负会被夹回 0，看不出扣没扣）
	b.recover_all()
	b.tp = 100.0
	s.gain_item(item, 5)
	var full_hp := b.hp
	var full_mp := b.mp
	lg.pay_skill_cost(b, all)
	_check("cavalry.pay.rich_not_paid", _near(b.hp, full_hp) and _near(b.mp, full_mp) and _near(b.tp, 100.0) and s.item_count(item) == 5, [full_hp, b.hp, full_mp, b.mp, b.tp, s.item_count(item)])
	_check("cavalry.pay.hp_cost_zero", XBattleLogic.skill_hp_cost(b, hp_flat) == 0 and XBattleLogic.skill_hp_cost(b, hp_per) == 0)
	# 第 1 回合、没学六号的人：付不起被挡；付得起照扣
	poor.call(a)
	_check("cavalry.pay.other_blocked_hp", not lg.can_use(a, hp_flat))
	_check("cavalry.pay.other_blocked_per", not lg.can_use(a, hp_per))
	_check("cavalry.pay.other_blocked_item", not lg.can_use(a, items))
	_check("cavalry.pay.other_blocked_mp", not lg.can_use(a, mptp))
	a.recover_all()
	a.tp = 100.0
	s.gain_item(item, 5)
	var hp0 := a.hp
	lg.pay_skill_cost(a, all)
	_check("cavalry.pay.other_paid", _near(a.hp, hp0 - 500.0) and s.item_count(item) == 2, [hp0, a.hp, s.item_count(item)])
	# 第 2 回合、六号持有者：照扣照挡
	lg.turn = 2
	poor.call(b)
	_check("cavalry.pay.t2_blocked_hp", not lg.can_use(b, hp_flat))
	_check("cavalry.pay.t2_blocked_per", not lg.can_use(b, hp_per))
	_check("cavalry.pay.t2_blocked_item", not lg.can_use(b, items))
	_check("cavalry.pay.t2_blocked_mp", not lg.can_use(b, mptp))
	b.recover_all()
	b.tp = 100.0
	s.gain_item(item, 5)
	hp0 = b.hp
	var mp0 := b.mp
	lg.pay_skill_cost(b, all)
	_check("cavalry.pay.t2_paid", _near(b.hp, hp0 - 500.0) and s.item_count(item) == 2 and b.mp < mp0 and _near(b.tp, 80.0), [hp0, b.hp, mp0, b.mp, b.tp, s.item_count(item)])
	# 开关关掉：第 1 回合只免 MP／TP（旧行为），生命、物品照挡照扣
	lg.turn = 1
	XTianqiTrumpet.FREE_ALL = false
	poor.call(b)
	_check("cavalry.off.hp_blocked", not lg.can_use(b, hp_flat))
	_check("cavalry.off.item_blocked", not lg.can_use(b, items))
	_check("cavalry.off.mptp_still_free", lg.can_use(b, mptp))
	b.recover_all()
	s.gain_item(item, 5)
	hp0 = b.hp
	lg.pay_skill_cost(b, all)
	_check("cavalry.off.paid", _near(b.hp, hp0 - 500.0) and s.item_count(item) == 2, [hp0, b.hp, s.item_count(item)])
	XTianqiTrumpet.FREE_ALL = true
	lg.end_battle(0)


## 五号起身那一回合不行动：这一回合的顺序是上一回合排的，阵亡时 _sync_orders 已把人（连追加行动）从下回合顺序里拿掉
func _abyss_order() -> void:
	var s := _state()
	var ms: Array = s.members()
	var b: XActor = ms[1]
	_learn(b, 5)
	var lg := _logic(s)
	XTianqiTrumpet.start(lg)
	lg.start_turn()  # 第 1 回合
	_check("abyss.order.t1_has", lg.current_order.has(b))
	# 追加行动：下回合顺序里排两次
	lg.next_order.insert(lg.next_order.find(b), b)
	var before := lg._movable_snapshot()
	b.add_state(1)
	b.hp = 0.0
	lg._sync_orders(before, true)
	_check("abyss.order.dead_cleared", not lg.next_order.has(b) and not lg.current_order.has(b), [lg.next_order.count(b), lg.current_order.count(b)])
	lg.current_order.clear()
	lg.start_turn()  # 第 2 回合：站起来，但这一回合不动
	_check("abyss.order.risen", b.is_alive() and lg.turn == 2)
	_check("abyss.order.risen_no_act", not lg.current_order.has(b), lg.current_order.count(b))
	_check("abyss.order.next_turn_back", lg.next_order.has(b))
	lg.end_battle(0)
	# 终焉锁复活：不站起来、不算用掉、也不进顺序
	var lg2 := _logic(s)
	b.recover_all()
	XTianqiTrumpet.start(lg2)
	lg2.start_turn()
	b.add_state(1)
	b.hp = 0.0
	lg2._sync_orders({b: true}, true)
	lg2.set_meta(XTianqiDeathAlien.META, {"preset": "", "units": {}, "queue": [], "doom": {}, "dead": {}, "lock": {}, "no_revive": {b: true}, "knell_lock": -1, "absorbed": {}})
	var old_ref = XTianqiDeathAlien._logic_ref
	XTianqiDeathAlien._logic_ref = weakref(lg2)
	lg2.current_order.clear()
	lg2.start_turn()
	_check("abyss.lock.stays_dead", b.is_dead() and int(XTianqiTrumpet._unit(lg2, b).revives) == 0)
	_check("abyss.lock.no_order", not lg2.current_order.has(b) and not lg2.next_order.has(b))
	lg2.remove_meta(XTianqiDeathAlien.META)
	XTianqiDeathAlien._logic_ref = old_ref
	lg2.end_battle(0)
	# 开场就阵亡：第 1 回合开始站起来
	b.remove_state(1)
	b.recover_all()
	var lg3 := _logic(s)
	XTianqiTrumpet.start(lg3)
	b.add_state(1)
	b.hp = 0.0
	lg3.start_turn()
	_check("abyss.t1dead.risen", b.is_alive())
	_check("abyss.t1dead.no_act", not lg3.current_order.has(b), lg3.current_order.count(b))
	_check("abyss.t1dead.next_has", lg3.next_order.has(b))
	# 拿掉只动本回合顺序：别人的先后不变，状态回合数不碰
	var others: Array = lg3.current_order.duplicate()
	var timed := -1
	for st in XDB.table("States"):
		if st is Dictionary and int(st.get("id", 0)) > 10 and int(st.get("autoRemovalTiming", 0)) == 1 and int(st.get("maxTurns", 0)) >= 3:
			timed = int(st.id)
			break
	if timed > 0:
		b.add_state(timed)
	var turns0: Dictionary = b.state_turns.duplicate()
	lg3.current_order.insert(mini(2, lg3.current_order.size()), b)
	XTianqiTrumpet._rest_risen(lg3)
	_check("abyss.t1dead.order_kept", lg3.current_order == others, [lg3.current_order.size(), others.size()])
	_check("abyss.t1dead.state_turns_kept", timed > 0 and b.state_turns == turns0, [timed, b.state_turns, turns0])
	if timed > 0:
		b.remove_state(timed)
	lg3.start_turn()  # 第 2 回合：照常行动
	_check("abyss.t1dead.t2_acts", lg3.turn == 2 and lg3.current_order.has(b), lg3.current_order.count(b))
	lg3.end_battle(0)
	b.remove_state(1)
	b.recover_all()


func _switches() -> void:
	var s := _state()
	XTianqiTrumpet.ENABLED = false
	_check("off.item", str(XDB.rec("Items", 1654).name) == "权能书：时之主宰")
	_check("off.limit", XPowerBooks.limit(s.members()[0]) == 6)
	var lg := _logic(s)
	XTianqiTrumpet.start(lg)
	_check("off.no_store", not lg.has_meta("xtrumpet"))
	_check("off.eligible_null", XTianqiTrumpet.eligible(s, 584) == null)
	XTianqiTrumpet.ENABLED = true
	_check("on.again", str(XDB.rec("Items", 1654).name) == "号卷：初号·雹火")
