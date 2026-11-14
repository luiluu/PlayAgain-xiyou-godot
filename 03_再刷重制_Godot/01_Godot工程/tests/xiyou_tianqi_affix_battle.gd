extends Node
## 天启篇词条战斗结算（XTianqiAffixBattle）专项：
## 一、认装备与汇总：tianqi_affixes 按阶取值、七印装备 qiyin.affixes 当四阶、同名相加、传说同名取最高、减伤每条相乘。
## 二、面板：属性 %、命中暴击百分点、引敌、连击 +1（两件也只 +1）、再动几率、全队光环同名取最高（助力位的也算）。
## 三、伤害帧：伤害加成池（伤害加成＋先声只第一次＋背水＋猎首）、爆伤、技能伤只算技能、元素增伤、承伤（减伤、元素抗性、磐石、坚韧、庇护）、治疗。
## 四、行动：吸血上限、斩获、破绽（取最高、两回合后消失）、压制、回春、再释放、技能消耗 −50% 封顶、异常抵抗只管有害状态。
## 五、开战与奖励：开场护盾、初始 TP、掉落与阅历全队相加。
## 六、开关关掉、原版档：一条都不生效；整回合实跑不报错。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _logic(tianqi := true) -> XBattleLogic:
	var w := _ids()
	var lineup := [w[0], w[1], w[2], w[3], w[5]]
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
	for id in lineup:
		s.actor(id).recover_all()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	return lg


## 角色身上放一件带词条的装备（占一个空着或已有的格；夹具直接塞实例）
func _wear(a: XActor, affixes: Array, slot := -1) -> void:
	a.keep_unequippable = true
	var inst := {"kind": "armor", "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3, "tianqi_affixes": affixes}
	if slot < 0:
		slot = 1
		while slot < a.equips.size() and a.equips[slot] is Dictionary and a.equips[slot].has("tianqi_affixes"):
			slot += 1
	while a.equips.size() <= slot:
		a.equips.append(null)
	a.equips[slot] = inst
	a.param_mark_dirty()
	a.param_refresh()


func _strip(a: XActor) -> void:
	for i in a.equips.size():
		if a.equips[i] is Dictionary and (a.equips[i].has("tianqi_affixes") or a.equips[i].has("qiyin")):
			a.equips[i] = null
	a.param_mark_dirty()
	a.param_refresh()


func _x(key: String, tier := 4, grade := "normal", extra := {}) -> Dictionary:
	return {"key": key, "tier": tier, "grade": grade, "extra": extra}


func _hit(id := 99999, element := 0) -> Dictionary:
	return {"id": id, "scope": 1, "damage": {"type": 1, "elementId": element, "critical": true, "variance": 0, "formula": "1"}, "effects": [], "stypeId": 1, "mpCost": 100, "tpCost": 20}


func _op(ops: Array, field: String, element := -1) -> Variant:
	var add := 0.0
	var mul := 1.0
	var seen := false
	for o in ops:
		if str(o.field) == field and (element < 0 or int(o.get("element", -1)) == element):
			seen = true
			if str(o.op) == "add":
				add += float(o.value)
			else:
				mul *= float(o.value)
	if not seen:
		return null
	return add if add != 0.0 else mul


func _near(a, b) -> bool:
	return a != null and absf(float(a) - float(b)) < 0.0001


## 重新开本场数据（夹具穿完装备后）
func _fresh(lg: XBattleLogic) -> void:
	XTianqiAffixBattle.start(lg)
	for m in lg.actors + XTianqiAffixBattle.members(lg.state):
		m.param_mark_dirty()
		m.param_refresh()


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XTianqiAffixTable.reload()
	_fold()
	_panel()
	_damage()
	_actions()
	_start_rewards()
	_switches()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _fold() -> void:
	var p := XTianqiAffixBattle.fold([_x("atk", 4, "fine"), _x("atk", 1, "perfect")])
	_check("sum_by_tier_grade", _near(p.get("atk"), 9.0), p)  # 四阶上品 6 ＋ 一阶极 3
	p = XTianqiAffixBattle.fold([_x("last_stand", 3, "normal"), _x("last_stand", 4, "perfect")])
	_check("legendary_max", _near(p.get("last_stand"), 35.0), p)
	p = XTianqiAffixBattle.fold([_x("damage_reduction"), _x("damage_reduction")])
	_check("reduction_multiply", _near(p.get("damage_reduction"), 0.97 * 0.97), p)
	p = XTianqiAffixBattle.fold([_x("final_damage", 1)])
	_check("special_tier1_none", not p.has("final_damage"), p)
	p = XTianqiAffixBattle.fold([_x("element_damage", 4, "normal", {"element": "fire"}), _x("element_damage", 4, "normal", {"element": "ice"})])
	_check("element_split", p.has("element_damage:fire") and p.has("element_damage:ice"), p)
	var qi := XTianqiAffixBattle.item_affixes({"qiyin": {"affixes": [{"key": "atk", "grade": "fine", "extra": {}}]}})
	_check("qiyin_tier4", qi.size() == 1 and int(qi[0].tier) == 4 and _near(XTianqiAffixBattle.fold(qi).get("atk"), 6.0), qi)
	_check("element_ids", XTianqiAffixBattle.element_id("physical") == 1 and XTianqiAffixBattle.element_id("fire") == 2 and XTianqiAffixBattle.element_id("dark") == 9)


func _panel() -> void:
	var lg := _logic()
	var a: XActor = lg.actors[0]
	var atk0 := a.atk
	var cri0 := a.cri
	var tgr0 := a.sparam(0)
	_wear(a, [_x("atk", 4, "perfect"), _x("cri")])  # 物攻 +8%，暴击率 +5 点
	_wear(a, [_x("combo"), _x("reaction", 4, "perfect"), _x("target_rate", 4, "normal", {"variant": "draw"})])
	_wear(a, [_x("combo")])
	_fresh(lg)
	_check("param_rate_atk", _near(XTianqiAffixBattle.param_rate(a, 2), 1.08), XTianqiAffixBattle.param_rate(a, 2))
	_check("atk_panel_up", a.atk > atk0, [atk0, a.atk])
	_check("cri_points", _near(a.cri - cri0, 0.05), [cri0, a.cri])
	_check("target_rate_draw", _near(a.sparam(0), tgr0 * 1.1), [tgr0, a.sparam(0)])
	var base_add := a.attack_times_add()
	_strip(a)
	_fresh(lg)
	_check("combo_once", _near(base_add - a.attack_times_add(), 1.0), [base_add, a.attack_times_add()])
	_wear(a, [_x("reaction", 4, "perfect")])
	_fresh(lg)
	_check("reaction_rate", a.action_plus_set().has(0.2), a.action_plus_set())
	# 光环：别人戴的、助力位戴的，同名取最高
	_strip(a)
	var b: XActor = lg.actors[1]
	_wear(b, [_x("aura_fervor", 3, "normal")])  # 3
	var helper_id := int(lg.state.battle_slots[XTianqi.HELPER_SLOT]) if lg.state.battle_slots.size() > XTianqi.HELPER_SLOT else 0
	var helper: XActor = lg.state.actors.get(helper_id)
	_check("helper_exists", helper != null and not lg.actors.has(helper), [helper_id, lg.state.battle_slots])
	if helper != null:
		_wear(helper, [_x("aura_fervor", 4, "fine")])  # 5
	_fresh(lg)
	_check("aura_party_max", _near(XTianqiAffixBattle.param_rate(a, 2), 1.05), XTianqiAffixBattle.param_rate(a, 2))
	_check("aura_not_other_stat", _near(XTianqiAffixBattle.param_rate(a, 4), 1.0))
	_wear(b, [_x("aura_fury", 4, "perfect")], 2)  # 暴击 +6 点、爆伤 +12%
	_fresh(lg)
	_check("aura_fury_cri", _near(XTianqiAffixBattle.xparam(a, 2, 0.0), 0.06))
	var ops := XTianqiAffixBattle.damage_ops(_hit(), a, lg.enemies[0])
	_check("aura_fury_crit_add", _near(_op(ops, "criticalAdd"), 0.12), ops)
	lg.end_battle(0)


func _damage() -> void:
	var lg := _logic()
	var a: XActor = lg.actors[0]
	var e: XEnemy = lg.enemies[0]
	_wear(a, [_x("final_damage", 4, "perfect"), _x("crit_damage"), _x("skill_damage")])
	_wear(a, [_x("first_strike"), _x("last_stand"), _x("headhunter"), _x("element_damage", 4, "normal", {"element": "fire"})])
	_fresh(lg)
	e.elite = false
	e.boss_difficulty_boss = false
	var ops := XTianqiAffixBattle.damage_ops(_hit(), a, e)
	_check("final_add_only_final", _near(_op(ops, "finalAdd"), 0.15), ops)  # 不是本回合第一击、血满、普通敌人
	_check("crit_add", _near(_op(ops, "criticalAdd"), 0.15), ops)
	_check("skill_mult", _near(_op(ops, "skillMultiplier"), 0.12), ops)
	_check("element_fire", _near(_op(ops, "elementAdd", 2), 0.15), ops)
	ops = XTianqiAffixBattle.damage_ops(_hit(int(a.attack_skill().get("id", 1))), a, e)
	_check("attack_no_skill_mult", _op(ops, "skillMultiplier") == null, ops)
	e.elite = true
	_check("headhunter_elite", _near(_op(XTianqiAffixBattle.damage_ops(_hit(), a, e), "finalAdd"), 0.15 + 0.15))
	e.elite = false
	a.hp = floorf(a.mhp * 0.2)
	_check("last_stand_low", _near(_op(XTianqiAffixBattle.damage_ops(_hit(), a, e), "finalAdd"), 0.15 + 0.25))
	a.hp = a.mhp
	var sk := _hit()
	XTianqiAffixBattle.begin_action(lg, a, sk)
	_check("first_strike_first", _near(_op(XTianqiAffixBattle.damage_ops(sk, a, e), "finalAdd"), 0.15 + 0.20))
	XTianqiAffixBattle.end_action(lg, a, sk)
	XTianqiAffixBattle.begin_action(lg, a, sk)
	_check("first_strike_once_per_turn", _near(_op(XTianqiAffixBattle.damage_ops(sk, a, e), "finalAdd"), 0.15))
	XTianqiAffixBattle.end_action(lg, a, sk)
	# 承伤（敌人打角色）
	var t: XActor = lg.actors[1]
	_wear(t, [_x("damage_reduction"), _x("damage_reduction"), _x("element_resist", 4, "normal", {"element": "fire"})])
	_wear(t, [_x("bulwark"), _x("tenacity")])
	_wear(lg.actors[2], [_x("aura_shelter", 4, "normal")])
	_fresh(lg)
	t.hp = t.mhp
	var m0 := 0.97 * 0.97 * 0.90 * 0.97  # 两条减伤、磐石（血高于 70%）、庇护光环
	_check("taken_mult", _near(_op(XTianqiAffixBattle.damage_ops(_hit(), e, t), "incomingMultiplier"), m0), XTianqiAffixBattle.damage_ops(_hit(), e, t))
	var fire := _hit(99999, 2)
	_check("taken_fire_resist", _near(_op(XTianqiAffixBattle.damage_ops(fire, e, t), "incomingMultiplier"), m0 * 0.90))
	XTianqiAffixBattle.crit_now = true
	_check("tenacity_on_crit", _near(_op(XTianqiAffixBattle.damage_ops(_hit(), e, t), "incomingMultiplier"), m0 * 0.75))
	XTianqiAffixBattle.crit_now = false
	t.hp = floorf(t.mhp * 0.5)
	_check("bulwark_off_half_hp", _near(_op(XTianqiAffixBattle.damage_ops(_hit(), e, t), "incomingMultiplier"), 0.97 * 0.97 * 0.97))
	# 治疗
	_wear(a, [_x("heal_dealt")])
	_wear(t, [_x("heal_received")])
	_fresh(lg)
	var heal := {"id": 99998, "scope": 7, "damage": {"type": 3, "elementId": 0, "critical": false, "variance": 0, "formula": "1"}, "effects": []}
	_check("heal_mult", _near(_op(XTianqiAffixBattle.damage_ops(heal, a, t), "healingMultiplier"), 1.08 * 1.08))
	lg.end_battle(0)


func _damage_skill() -> Dictionary:
	for id in range(2, 400):
		var s := XDB.rec("Skills", id)
		if not s.is_empty() and int(s.get("scope", 0)) == 1 and int(s.get("damage", {}).get("type", 0)) == 1 and int(s.get("mpCost", 0)) == 0 and int(s.get("tpCost", 0)) == 0:
			return s
	return {}


func _actions() -> void:
	var lg := _logic()
	var a: XActor = lg.actors[0]
	var e: XEnemy = lg.enemies[0]
	_wear(a, [_x("lifesteal", 4, "perfect"), _x("expose"), _x("suppress")])
	_wear(a, [_x("harvest")])
	_fresh(lg)
	# 吸血：四阶极 6%，造成 1000 回 60，上限最大生命 10%
	a.hp = 1.0
	var sk := _hit()
	XTianqiAffixBattle.begin_action(lg, a, sk)
	XTianqiAffixBattle.after_apply(lg, a, sk, e, {"hp": 1000.0})
	_check("lifesteal", _near(a.hp, 1.0 + floorf(minf(60.0, a.mhp * 0.1))), [a.hp, a.mhp])
	a.hp = 1.0
	XTianqiAffixBattle.after_apply(lg, a, sk, e, {"hp": 1.0e9})
	_check("lifesteal_cap", _near(a.hp, 1.0 + floorf(a.mhp * 0.1)), [a.hp, a.mhp])
	a.hp = a.mhp
	# 破绽：目标承伤 +8%，两回合后消失
	_check("expose_on", _near(_op(XTianqiAffixBattle.damage_ops(_hit(), lg.actors[1], e), "incomingMultiplier"), 1.08))
	var cri0 := e.xparam(2)
	_check("suppress_cri", e.xparam(2) <= maxf(0.0, cri0) and XTianqiAffixBattle._unit(lg, e).suppress_turns == 2)
	XTianqiAffixBattle.end_turn(lg)
	XTianqiAffixBattle.end_turn(lg)
	_check("expose_off_after_two", _op(XTianqiAffixBattle.damage_ops(_hit(), lg.actors[1], e), "incomingMultiplier") == null)
	_check("suppress_off_after_two", int(XTianqiAffixBattle._unit(lg, e).suppress_turns) == 0)
	# 压制的数值：手动给敌人 30 点暴击时减 15 点
	XTianqiAffixBattle._unit(lg, e).suppress = 15.0
	XTianqiAffixBattle._unit(lg, e).suppress_turns = 1
	_check("suppress_value", _near(XTianqiAffixBattle.enemy_xparam(e, 2, 0.3), 0.15) and _near(XTianqiAffixBattle.enemy_xparam(e, 2, 0.1), 0.0) and _near(XTianqiAffixBattle.enemy_xparam(e, 0, 0.3), 0.3))
	# 斩获：打倒时回 9%，一次行动只一次
	a.hp = 1.0
	a.mp = 0.0
	XTianqiAffixBattle.end_action(lg, a, sk)
	XTianqiAffixBattle.begin_action(lg, a, sk)
	XTianqiAffixBattle.before_apply(lg, a, sk, e)
	e.hp = 0.0
	e.add_state(1)
	XTianqiAffixBattle.after_apply(lg, a, sk, e, {"hp": 10.0})
	XTianqiAffixBattle.after_apply(lg, a, sk, e, {"hp": 10.0})
	_check("harvest_once", _near(a.hp, 1.0 + floorf(a.mhp * 0.09) + floorf(minf(0.6, a.mhp * 0.1))) and _near(a.mp, floorf(a.mmp * 0.09)), [a.hp, a.mp, a.mhp, a.mmp])
	XTianqiAffixBattle.end_action(lg, a, sk)
	# 回春：治疗溢出转护盾，上限目标最大生命 10%
	var h: XActor = lg.actors[1]
	_wear(h, [_x("rejuvenate")])
	_fresh(lg)
	var t: XActor = lg.actors[2]
	t.hp = t.mhp - 100.0
	t.shield = 0.0
	XTianqiAffixBattle.begin_action(lg, h, {})
	XTianqiAffixBattle.before_apply(lg, h, {}, t)
	t.hp = t.mhp
	XTianqiAffixBattle.after_apply(lg, h, {}, t, {"hp": -1.0e9})
	_check("rejuvenate_cap", _near(t.shield, floorf(t.mhp * 0.10) * (1.0 + t.shield_effect_bonus())), [t.shield, t.mhp])
	XTianqiAffixBattle.end_action(lg, h, {})
	# 技能消耗：十条极 −6% 合 −60%，封顶 −50%
	var many := []
	for i in 10:
		many.append(_x("skill_cost", 4, "perfect"))
	_wear(a, many, 5)
	var c := XTianqiAffixBattle.cost(a, _hit(), {"mp": 100, "tp": 20})
	_check("skill_cost_cap", int(c.mp) == 50 and int(c.tp) == 10, c)
	_fresh(lg)
	var with_cost := int(lg._skill_cost(a, _hit(), false, 0.0).mp)
	XTianqiAffixBattle.ENABLED = false
	var without_cost := int(lg._skill_cost(a, _hit(), false, 0.0).mp)
	XTianqiAffixBattle.ENABLED = true
	_check("skill_cost_in_logic", without_cost > 0 and with_cost == int(floorf(without_cost * 0.5)), [with_cost, without_cost])
	# 异常抵抗：有害状态 ×0.85，有益状态不变，战斗不能不变
	_wear(a, [_x("state_resist", 4, "fine")], 6)
	_fresh(lg)
	var bad := 0
	var good := 0
	for id in range(2, 300):
		if XDB.rec("States", id).is_empty():
			continue
		if bad == 0 and XSmartAI.harmful_state(id):
			bad = id
		elif good == 0 and not XSmartAI.harmful_state(id):
			good = id
	_check("state_resist_bad", bad > 0 and _near(XTianqiAffixBattle.state_rate(a, bad), 0.88), [bad, XTianqiAffixBattle.state_rate(a, bad)])
	_check("state_resist_good", good > 0 and _near(XTianqiAffixBattle.state_rate(a, good), 1.0), good)
	_check("state_resist_death", _near(XTianqiAffixBattle.state_rate(a, 1), 1.0))
	_check("state_rate_in_logic", bad > 0 and _near(lg.state_rate(a, bad), a.traits_pi(XBattler.TRAIT_STATE_RATE, bad) * 0.88))
	lg.end_battle(0)
	# 再释放：堆到 100% 以上必触发；再放出来的那次不再触发
	var lg2 := _logic()
	var u: XActor = lg2.actors[0]
	var rc := []
	for i in 17:
		rc.append(_x("recast", 4, "perfect"))  # 17×6＝102%
	_wear(u, rc)
	_fresh(lg2)
	var real := _damage_skill()
	_check("found_damage_skill", not real.is_empty())
	if not real.is_empty():
		var tgt: XEnemy = lg2.enemies[0]
		tgt.hp = tgt.mhp
		XTianqiAffixBattle.begin_action(lg2, u, real)
		lg2.apply(u, real, tgt)
		var logs := XTianqiAffixBattle.end_action(lg2, u, real)
		_check("recast_fires_once", logs.size() == 2 and str(logs[0].get("type", "")) == "action", logs.size())
		_check("recast_no_chain", int(XTianqiAffixBattle._store(lg2).depth) == 0)
		var none := XTianqiAffixBattle.end_action(lg2, u, real)
		_check("recast_needs_action", none.is_empty())
		# 评审 v0.1 第 8 条：走整次行动时，再释放那一下的命中也带画面快照（血条跟着动）
		tgt.hp = tgt.mhp
		lg2.current_order.clear()
		var acted := lg2.act(u, real, tgt)
		var hits := acted.filter(func(l): return l is Dictionary and l.get("type") == "hit")
		var acts := acted.filter(func(l): return l is Dictionary and l.get("type") == "action" and is_same(l.get("user"), u))
		_check("review8_recast_hits_have_views", acts.size() >= 2 and hits.size() >= 2 and hits.all(func(l): return l.has("views")), [acts.size(), hits.size(), hits.map(func(l): return l.has("views"))])
	lg2.end_battle(0)


func _start_rewards() -> void:
	var lg := _logic()
	var a: XActor = lg.actors[0]
	_wear(a, [_x("opening_shield", 4, "perfect"), _x("initial_tp", 4, "perfect"), _x("drop_rate"), _x("exp_gold")])
	a.shield = 0.0
	a.tp = 0.0
	_fresh(lg)
	_check("opening_shield", _near(a.shield, floorf(a.mhp * 0.08) * (1.0 + a.shield_effect_bonus())), [a.shield, a.mhp])
	_check("initial_tp", _near(a.tp, 10.0), a.tp)
	var helper: XActor = lg.state.actors.get(int(lg.state.battle_slots[XTianqi.HELPER_SLOT])) if lg.state.battle_slots.size() > XTianqi.HELPER_SLOT else null
	if helper != null:
		_wear(helper, [_x("drop_rate", 4, "perfect"), _x("exp_gold", 4, "perfect")])
	_fresh(lg)
	var drop := 3.0 + (6.0 if helper != null else 0.0)
	_check("drop_party_sum", _near(XTianqiAffixBattle.drop_mult(lg), 1.0 + drop / 100.0), XTianqiAffixBattle.drop_mult(lg))
	var out := {"exp": 1000, "gold": 1000}
	XTianqiAffixBattle.rewards(lg, out)
	var eg := 5.0 + (10.0 if helper != null else 0.0)
	_check("exp_gold_party_sum", int(out.exp) == int(floorf(1000.0 * (1.0 + eg / 100.0))) and int(out.gold) == int(out.exp), out)
	# 实跑几回合不报错
	_wear(a, [_x("reaction", 4, "perfect"), _x("combo"), _x("lifesteal"), _x("expose"), _x("recast", 4, "perfect")], 3)
	_fresh(lg)
	var t0 := lg.turn
	for k in 3:
		if lg.is_over():
			break
		lg.run_turn({})
	_check("run_turns_ok", lg.turn > t0, lg.turn)
	lg.end_battle(0)
	_check("finish_clears", not lg.has_meta("xaffix"))


func _switches() -> void:
	XTianqiAffixBattle.ENABLED = false
	var lg := _logic()
	var a: XActor = lg.actors[0]
	_wear(a, [_x("atk", 4, "perfect"), _x("final_damage"), _x("combo")])
	_fresh(lg)
	_check("off_no_store", not lg.has_meta("xaffix"))
	_check("off_param", XTianqiAffixBattle.param_rate(a, 2) == 1.0 and XTianqiAffixBattle.attack_times(a) == 0.0)
	_check("off_no_ops", XTianqiAffixBattle.damage_ops(_hit(), a, lg.enemies[0]).is_empty())
	XTianqiAffixBattle.ENABLED = true
	lg.end_battle(0)
	var lg3 := _logic(false)
	var b: XActor = lg3.actors[0]
	_wear(b, [_x("atk", 4, "perfect"), _x("skill_cost", 4, "perfect")])
	_fresh(lg3)
	_check("legacy_no_store", not lg3.has_meta("xaffix"))
	_check("legacy_param", XTianqiAffixBattle.param_rate(b, 2) == 1.0)
	_check("legacy_cost", int(XTianqiAffixBattle.cost(b, _hit(), {"mp": 100, "tp": 20}).mp) == 100)
	lg3.end_battle(0)
