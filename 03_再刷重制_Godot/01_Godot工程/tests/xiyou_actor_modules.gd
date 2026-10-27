extends Node
## 专属角色模块第一期（XActorModules：XGarou 173、XRaven 167、XMira 168、XSukuna 172、XYomiJingliu 169、XNumberBoost、XActorDamageHooks）的行为专项。
## 能力值、技能表、伤害行由 xiyou_actor_p0／xiyou_rules 对 slice_probe、actor_passive_probe 参照；这里验参照覆盖不到的：
## 非模块角色走快速路径、被动准入挡 learn_skill、降级同步、开机进阶表、伤害钩子帧操作、号角招募给的法宝。
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(600))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := XState.new_game(7, 1, [8])
	XState.current = s
	s.actor_max_level = 99  # 新开局的队伍等级上限很低，change_level_mv 会被夹住
	# 快速路径
	var one := XActor.new().setup(1)
	check("fast.can_learn", XActorModules.can_learn(one, 10266))
	check("fast.param", XActorModules.param(one, 2, 123.0) == 123.0 and XActorModules.xparam(one, 2, 0.5) == 0.5)
	# 173 饿狼
	var g := XActor.new().setup(173)
	check("garou.lv1_skills", [10250, 10265, 10269].all(func(i): return g.skill_ids.has(i)), g.skill_ids)
	check("garou.form_state", g.state_ids.has(2644), g.state_ids)
	g.change_level_mv(50)
	check("garou.lv50_gated", not [10266, 10267, 10268].any(func(i): return g.skill_ids.has(i)), g.skill_ids)
	g.learn_skill(10266)
	check("garou.learn_blocked", not g.skill_ids.has(10266))
	check("garou.formula", is_equal_approx(XGarou.formula(g, XDB.rec("Skills", 10250)), g.atk * 1.88 * 66), [XGarou.formula(g, XDB.rec("Skills", 10250)), g.atk])
	check("garou.formula_other", XGarou.formula(one, XDB.rec("Skills", 10250)) == 0.0)
	s.actor_advance[173] = 1
	g.change_level_mv(49)
	check("garou.rank1_down_sync", g.skill_ids.has(10266) and g.skill_ids.has(10251) and not g.skill_ids.has(10250) and g.state_ids.has(2645) and not g.state_ids.has(2644), [g.skill_ids, g.state_ids])
	s.actor_advance.erase(173)
	# 167 渡鸦
	var r := XActor.new().setup(167)
	check("raven.lv1_skills", [10122, 10137, 10138].all(func(i): return r.skill_ids.has(i)) and not r.skill_ids.has(10127) and not r.skill_ids.has(10170), r.skill_ids)
	check("raven.formula", is_equal_approx(XRaven.formula(r, r, XDB.rec("Skills", 10122)), (r.mat * 78 + r.mmp * 39) * 6.0 / 11.0 * 9), XRaven.formula(r, r, XDB.rec("Skills", 10122)))
	r.change_level_mv(25)
	check("raven.lv25_gate", r.skill_ids.has(10132) and not r.skill_ids.has(10123), r.skill_ids)
	check("raven.pools", is_equal_approx(float(r.passive_cache().critHarmRi) - XRaven.growth_pools(r)[0] / 100.0, _base_cache(r, "critHarmRi")), r.passive_cache().critHarmRi)
	var rows: Array = XAdvance.rows().filter(func(row): return int(row.actor) == 167)
	check("raven.advance_rows", rows.size() == 5 and rows.map(func(row): return int(row.level)) == [15, 25, 35, 45, 45], rows)
	var ops: Array = XActorDamageHooks.capture(XDB.rec("Skills", 10122), r, XEnemy.new().setup(1, 1)).ops
	check("raven.hook_mode", ops.any(func(o): return o.field == "mode" and o.value == "magical"), ops)
	check("raven.hook_number_pool", ops.any(func(o): return o.field == "settlementMultiplier" and is_equal_approx(float(o.value), 1.15)), ops)
	check("raven.growth_lv1", XRaven.growth_rate(XActor.new().setup(167)) == 16.0)
	# 168 米拉
	var m := XActor.new().setup(168)
	var plain_def := m.param(3)
	m.change_level_mv(35)
	check("mira.lv35_def", m.skill_ids.has(10144) and m.param(3) > plain_def, [m.param(3), plain_def])
	check("mira.crit", XNumberBoost.xparam(m, 2, 0.0) > 0.9, XNumberBoost.xparam(m, 2, 0.0))
	check("mira.hook_mode", XActorDamageHooks.mira_ops(XDB.rec("Skills", 10142), m, m)[0].value == "magical")
	# 172 宿傩
	var k := XActor.new().setup(172)
	check("sukuna.lv1_skills", [10225, 10229, 10239, 10240].all(func(i): return k.skill_ids.has(i)) and not k.skill_ids.has(10230), k.skill_ids)
	check("sukuna.formula", is_equal_approx(XSukuna.formula(k, k, XDB.rec("Skills", 10229)), k.atk * 88888.0), [XSukuna.formula(k, k, XDB.rec("Skills", 10229)), k.atk])
	check("sukuna.formula_other", XSukuna.formula(one, k, XDB.rec("Skills", 10229)) == 0.0)
	k.change_level_mv(50)
	check("sukuna.lv50_rank0", [10230, 10231, 10232, 10233, 10241, 10242].all(func(i): return k.skill_ids.has(i)) and not [10234, 10243, 10245].any(func(i): return k.skill_ids.has(i)) and XSukuna.stage(k) == 0, k.skill_ids)
	var k_atk := k.param(2)
	var k_crit := k.xparam(2)
	s.actor_advance[172] = 3
	k.change_level_mv(55)
	check("sukuna.rank3_sync", [10235, 10245, 10246, 10247].all(func(i): return k.skill_ids.has(i)) and not [10234, 10243, 10244, 10248].any(func(i): return k.skill_ids.has(i)), k.skill_ids)
	check("sukuna.stage3", XSukuna.stage(k) == 3 and k.param(2) > k_atk * 2.5 and is_equal_approx(k.xparam(2) - k_crit, 9.99), [k.param(2), k_atk, k.xparam(2), k_crit])
	check("sukuna.coefficient", XSukuna.coefficient(k) == 100000.0, XSukuna.coefficient(k))
	k.change_level_mv(49)
	check("sukuna.down_sync", not k.skill_ids.has(10245) and not k.skill_ids.has(10247) and XSukuna.stage(k) == 0, k.skill_ids)
	s.actor_advance.erase(172)
	var k_ops: Array = XActorDamageHooks.capture(XDB.rec("Skills", 10234), k, XEnemy.new().setup(1, 1)).ops
	check("sukuna.hook_true", k_ops.any(func(o): return o.field == "kind" and o.value == "true") and k_ops.any(func(o): return o.field == "elements" and o.value == [13]), k_ops)
	k_ops = XActorDamageHooks.capture(XDB.rec("Skills", 10230), k, XEnemy.new().setup(1, 1)).ops
	check("sukuna.hook_pierce", k_ops.any(func(o): return o.field == "physicalDefenseRate" and is_equal_approx(float(o.value), 0.15)), k_ops)
	# 169 黄泉
	var y := XActor.new().setup(169)
	var foe := XEnemy.new().setup(1, 1)
	check("yomi.lv1_skills", y.skill_ids.has(10171) and y.skill_ids.has(10175) and not y.skill_ids.has(10176), y.skill_ids)
	check("yomi.action_plus", y.action_plus_set().count(1.0) >= 1, y.action_plus_set())
	check("yomi.formula", is_equal_approx(XYomiJingliu.formula(y, foe, XDB.rec("Skills", 10171)), y.atk * 50000 + y.agi * 5000 + y.luk * 7000))
	foe.state_ids.append(XYomiJingliu.Y_MARK)
	check("yomi.formula_marked", XYomiJingliu.debuff_count(foe) == 1 and is_equal_approx(XYomiJingliu.formula(y, foe, XDB.rec("Skills", 10171)), y.atk * 55000 + y.agi * 5500 + y.luk * 7700))
	check("yomi.formula_other", XYomiJingliu.formula(one, foe, XDB.rec("Skills", 10171)) == 0.0)
	var y_luk := y.luk
	y.change_level_mv(45)
	check("yomi.lv45_skills", [10172, 10176, 10177, 10178, 10179, 10180, 10181, 10182, 10183].all(func(i): return y.skill_ids.has(i)), y.skill_ids)
	check("yomi.param_plus", XYomiJingliu.param_plus(y, 7, 0.0) == 888.0 and XYomiJingliu.param_plus(y, 6, 0.0) == 777.0 and XYomiJingliu.param_plus(y, 2, 0.0) == 888.0 and XYomiJingliu.param_plus(one, 7, 0.0) == 0.0)
	check("yomi.luk", y.luk > y_luk + 888.0 - 1.0, [y.luk, y_luk])
	check("yomi.repeats", XYomiJingliu.repeats(y, 10171) == 2 + mini(6, floori(y.luk / 6666.0)) and XYomiJingliu.repeats(y, 10174) == XYomiJingliu.repeats(y, 10171) + 4)
	var y_crit := y.xparam(2)
	y.learn_skill(10185)
	check("yomi.crit", is_equal_approx(y.xparam(2) - y_crit, 9.99 if XYomiJingliu.CRIT_FIX else 0.0), [y.xparam(2), y_crit])
	var y_atk := y.param(2)
	y.learn_skill(10186)
	check("yomi.rank0_atk", y.param(2) == y_atk, [y.param(2), y_atk])
	s.actor_advance[169] = 2
	check("yomi.rank2_atk", y.param(2) >= y_atk + floorf(y.luk * 1.88) - 1.0 and is_equal_approx(XYomiJingliu.penetration(y), 0.66), [y.param(2), y_atk, y.luk, XYomiJingliu.penetration(y)])
	s.actor_advance.erase(169)
	check("yomi.pen_rank0", is_equal_approx(XYomiJingliu.penetration(y), 0.44), XYomiJingliu.penetration(y))
	var y_ops: Array = XActorDamageHooks.capture(XDB.rec("Skills", 10171), y, foe).ops
	var y_mul := func(ops: Array) -> float: return ops.filter(func(o): return o.field == "skillMultiplier").reduce(func(acc, o): return acc * float(o.value), 1.0)
	check("yomi.hook", y_ops.any(func(o): return o.field == "mode" and o.value == "physical") and y_ops.any(func(o): return o.field == "physicalIncomingPierce" and is_equal_approx(float(o.value), 0.44))
		and y_ops.any(func(o): return o.field == "elementAdd" and int(o.element) == 5 and is_equal_approx(float(o.value), 0.77)) and y_ops.any(func(o): return o.field == "criticalAdd" and is_equal_approx(float(o.value), 6.66))
		and is_equal_approx(y_mul.call(y_ops), 16.55), y_ops)
	check("yomi.hook_ult", is_equal_approx(y_mul.call(XActorDamageHooks.capture(XDB.rec("Skills", 10174), y, foe).ops), 1.33))
	check("yomi.hook_other_skill", XYomiJingliu.damage_ops(XDB.rec("Skills", 10229), y, foe).is_empty())
	# 号角招募
	s.set_switch(2494, true)  # 超强者挑战（XItemMarks.SUPER_SWITCHES）
	check("recruit.garou", XGarou.recruit(s) and s.party.has(173) and s.actor(173).has_base_equip("armor", 7904))
	check("recruit.garou_again", not XGarou.recruit(s))
	check("recruit.mira", XMira.recruit(s) and s.party.has(168) and s.actor(168).has_base_equip("armor", 4577))
	check("recruit.raven", XRaven.recruit(s) and s.party.has(167) and s.gear.filter(func(e): return int(e.base) == 4001).size() == 1)
	XRaven.recruit(s)
	check("recruit.raven_once", s.gear.filter(func(e): return int(e.base) == 4001).size() == 1)
	check("recruit.sukuna", XSukuna.recruit(s) and s.party.has(172) and s.actor(172).has_base_equip("armor", 4581))
	check("recruit.sukuna_again", not XSukuna.recruit(s))
	check("recruit.yomi", XYomiJingliu.recruit(s, 169).size() == 2 and s.party.has(169) and s.actor(169).has_base_equip("armor", 4578))
	check("recruit.yomi_again", XYomiJingliu.recruit(s, 169).is_empty())
	var yr := s.actor(169)
	check("yomi.armor_hook", is_equal_approx(y_mul.call(XActorDamageHooks.capture(XDB.rec("Skills", 10171), yr, foe).ops), 1.77) or yr.skill_ids.has(10185), yr.skill_ids)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


## 不含渡鸦池的暴伤合计：去掉 10137 重算
func _base_cache(r: XActor, key: String) -> float:
	r.skill_ids.erase(10137)
	r.refresh_passive()
	var v := float(r.passive_cache()[key])
	r.skill_ids.append(10137)
	r.skill_ids.sort()
	r.refresh_passive()
	return v
