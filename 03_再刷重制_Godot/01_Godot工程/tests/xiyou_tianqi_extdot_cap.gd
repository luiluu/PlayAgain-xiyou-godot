extends Node
## 【cc·T453】D273 封顶纳入 XExtDot：传承 2617 火海披风（开战给全体敌人挂 State 243 火海，XExtDot 按血量 100%±20%）
## 对守层者／首领的回合末持续伤害与再生合计每回合 ≤ ⌊最大生命×5%⌋（表 boss_neg_hrg_cap_extdot_states、开关 BOSS_NEG_HRG_CAP）。
## 一、带披风开战：22／29／30 层守层者与副本首领都挂上 243；三个回合键各量一次，XExtDot＋再生合计 ≤5%；
## 二、243 ＋ 灼伤 I～V（再生 −14%）同挂：合计仍 ≤5%（预算两路共用）；
## 三、普通小怪不封（1 层嘤嘤怪挂 243 照扣约 100%）；四、开关关：守层者回到整血级掉血；五、西游档零变化（同样挂 243 不封）；
## 六、不在表里的状态（灼伤单独）不走 XExtDot 预算，仍只由再生那一路封顶。

var results: Array = []
const BURN5 := [17, 18, 19, 20, 21]


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _state(tianqi: bool) -> XState:
	var lineup := [1, 2, 8, 9, 10]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
		for id in lineup:
			XTianqi._joining = true
			s.add_actor(int(id))
			XTianqi._joining = false
	else:
		s = XState.new_game(3, 1, [8, 9, 10])
	var legacy := XTianqi.legacy_of("jianxian") if tianqi else 3
	for i in range(1, 9):
		s.flags["DCultyL%d" % i] = i == legacy
	s.map_id = 4
	XState.current = s
	return s


func _wear_cloak(s: XState) -> void:
	var a: XActor = s.actor(1)
	a.change_level(81)
	var item := XGear.create("armor", 2617, s)
	a.equips[a.equip_slots().find(int(item.etypeId))] = item
	a.refresh_passive()


func _add_states(e: XEnemy, ids: Array) -> void:
	for sid in ids:
		if not e.state_ids.has(int(sid)):
			e.state_ids.append(int(sid))
		XActor.state_touch(int(sid))
	e.param_mark_dirty()


## 一个回合末：XExtDot.tick → _regenerate；返回掉血量（血量每回合补满）。turn_key 变一个，持续伤害的随机波动跟着换。
func _turn_loss(logic: XBattleLogic, e: XEnemy, turn_key: int) -> float:
	logic.turn = turn_key
	e.hp = e.mhp
	XExtDot.tick(logic, e, [])
	logic._regenerate(e, [])
	return float(e.mhp) - float(e.hp)


func _cloak_battle(s: XState, troop: int) -> Array:
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	lg._battle_start_states()
	return [lg, lg.enemies[0]]


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	XEnemy.force_roll = 100.0
	var was_cap := XTianqiCombat.BOSS_NEG_HRG_CAP
	var was_strip := XGuardianRework.STRIP
	XTianqiCombat.BOSS_NEG_HRG_CAP = true
	XGuardianRework.STRIP = true

	var s := _state(true)
	_wear_cloak(s)
	# 一、带披风开战，22／29／30 层守层者、副本首领：243 挂上，三个回合键各量一次
	for entry in [["f22", 458], ["f29", 465], ["f30", 466], ["dungeon", 422]]:
		var pair := _cloak_battle(s, int(entry[1]))
		var lg: XBattleLogic = pair[0]
		var e: XEnemy = pair[1]
		var budget := floorf(float(e.mhp) * 0.05)
		_check("tq.%s.cloak_state_243_applied" % entry[0], e.state_ids.has(243), e.state_ids)
		var worst := 0.0
		var best := INF
		for k in [11, 22, 33]:
			var loss := _turn_loss(lg, e, k)
			worst = maxf(worst, loss)
			best = minf(best, loss)
		_check("tq.%s.cloak_dot_capped_5pct" % entry[0], worst <= budget + 0.5 and best >= budget - 0.5, [worst, best, budget, e.mhp])

	# 二、243 ＋ 灼伤 I～V（再生 −14%）同挂：合计仍 ≤5%
	var pair2 := _cloak_battle(s, 465)
	var lg2: XBattleLogic = pair2[0]
	var e2: XEnemy = pair2[1]
	_add_states(e2, BURN5)
	var budget2 := floorf(float(e2.mhp) * 0.05)
	var worst2 := 0.0
	for k in [11, 22, 33]:
		worst2 = maxf(worst2, _turn_loss(lg2, e2, k))
	_check("tq.f29.cloak_plus_burn_total_le_5pct", worst2 <= budget2 + 0.5, [worst2, budget2])

	# 三、普通小怪（1 层嘤嘤怪，敌群 1）：243 不封顶
	var pair3 := _cloak_battle(s, 1)
	var emob: XEnemy = pair3[1]
	var lmob := _turn_loss(pair3[0], emob, 11)
	_check("tq.mob.cloak_not_capped", not XTianqiCombat.is_neg_hrg_boss(emob) and lmob > float(emob.mhp) * 0.5, [lmob, emob.mhp])

	# 四、开关关：守层者回到整血级掉血
	XTianqiCombat.BOSS_NEG_HRG_CAP = false
	var pair4 := _cloak_battle(s, 465)
	var e4: XEnemy = pair4[1]
	var l4 := _turn_loss(pair4[0], e4, 11)
	_check("tq.f29.switch_off_full_dot", l4 > float(e4.mhp) * 0.5, [l4, e4.mhp])
	XTianqiCombat.BOSS_NEG_HRG_CAP = true

	# 五、西游档：同样挂 243，照原版 10000±20%（不换成按血量比例、不封），开关开／关一样
	var sx := _state(false)
	var lx := XBattleLogic.new()
	lx.setup(4, sx)
	var ex: XEnemy = lx.enemies[0]
	_add_states(ex, [243])
	var lx_on := _turn_loss(lx, ex, 11)
	XTianqiCombat.BOSS_NEG_HRG_CAP = false
	var lx_off := _turn_loss(lx, ex, 11)
	_check("xiyou.cloak_dot_unchanged_on_eq_off", absf(lx_on - 10000.0) < 3000.0 and absf(lx_off - 10000.0) < 3000.0 and not ex.has_meta(XTianqiCombat.META_DOT_USED), [lx_on, lx_off, ex.mhp])
	XTianqiCombat.BOSS_NEG_HRG_CAP = true

	# 六、灼伤单独（不在 XExtDot 预算表里）：仍只走再生那一路 5% 封顶，预算账不残留
	XState.current = s
	var pair6 := _cloak_battle(s, 465)
	var e6: XEnemy = pair6[1]
	e6.state_ids.erase(243)
	_add_states(e6, BURN5)
	var l6 := _turn_loss(pair6[0], e6, 11)
	_check("tq.f29.burn_only_still_5pct_no_meta_left", is_equal_approx(l6, floorf(float(e6.mhp) * 0.05)) and not e6.has_meta(XTianqiCombat.META_DOT_USED), [l6, e6.mhp])

	# 七、T456 验收 1：自带正再生首领（11 层 STRIP=false，正再生 >5%）挂 243 ＋ 灼伤 I～V，负再生不吃正再生，合计负向恰为 5%
	XGuardianRework.STRIP = false
	var pair7 := _cloak_battle(s, int(XGuardianRework.TROOPS[11]))
	var lg7: XBattleLogic = pair7[0]
	var e7: XEnemy = pair7[1]
	e7.state_ids.erase(243)
	var hp7_base := floorf(float(e7.mhp) / 2.0)
	e7.hp = hp7_base
	lg7._regenerate(e7, [])
	var gain7_base := float(e7.hp) - hp7_base  # 无 243、无灼伤时的纯正再生
	var budget7 := floorf(float(e7.mhp) * 0.05)
	_add_states(e7, [243] + BURN5)
	e7.hp = hp7_base
	lg7.turn = 11
	XExtDot.tick(lg7, e7, [])
	lg7._regenerate(e7, [])
	var delta7_both := float(e7.hp) - hp7_base
	var neg7_impact := gain7_base - delta7_both
	_check("tq.f11.pos_regen_243_plus_burn_not_eaten", gain7_base > budget7 and is_equal_approx(neg7_impact, budget7) and not e7.has_meta(XTianqiCombat.META_DOT_USED),
		[gain7_base, delta7_both, neg7_impact, budget7])

	# 七 b、正再生 <5% 首领（29 层＋状态 2781 +1%×w²=+4%）挂 243＋灼伤：正再生照旧保留，净掉血 1%、合计负向 5%（修前吃成 9%）
	XGuardianRework.STRIP = true
	var pair7b := _cloak_battle(s, 465)
	var lg7b: XBattleLogic = pair7b[0]
	var e7b: XEnemy = pair7b[1]
	e7b.state_ids.erase(243)
	_add_states(e7b, [2781])
	var hp7b_base := floorf(float(e7b.mhp) / 2.0)
	e7b.hp = hp7b_base
	lg7b._regenerate(e7b, [])
	var gain7b_base := float(e7b.hp) - hp7b_base
	var budget7b := floorf(float(e7b.mhp) * 0.05)
	_add_states(e7b, [243] + BURN5)
	e7b.hp = hp7b_base
	lg7b.turn = 11
	XExtDot.tick(lg7b, e7b, [])
	lg7b._regenerate(e7b, [])
	var delta7b_both := float(e7b.hp) - hp7b_base
	var neg7b_impact := gain7b_base - delta7b_both
	_check("tq.f29.small_pos_regen_243_plus_burn_not_eaten", gain7b_base > 0.0 and gain7b_base < budget7b and is_equal_approx(neg7b_impact, budget7b) and not e7b.has_meta(XTianqiCombat.META_DOT_USED),
		[gain7b_base, delta7b_both, neg7b_impact, budget7b])

	# 七 c、部分预算已用（XExtDot 用掉 40% 预算）：XEnemy.cap_neg_hrg 只留剩余 60% 给负再生，正再生不被吃
	XGuardianRework.STRIP = false
	var pair7c := _cloak_battle(s, int(XGuardianRework.TROOPS[11]))
	var lg7c: XBattleLogic = pair7c[0]
	var e7c: XEnemy = pair7c[1]
	e7c.state_ids.erase(243)
	var budget7c := floorf(float(e7c.mhp) * 0.05)
	var used7c := floorf(budget7c * 0.4)
	_add_states(e7c, BURN5)
	e7c.set_meta(XTianqiCombat.META_DOT_USED, used7c)
	var eff7c := e7c.cap_neg_hrg(-0.14, 1.0)
	var left7c := budget7c - used7c
	e7c.hp = hp7_base
	lg7c._regenerate(e7c, [])
	var delta7c := float(e7c.hp) - hp7_base
	var total7c_neg := used7c + (gain7_base - delta7c)
	_check("tq.f11.partial_dot_budget_deducted_in_cap_neg_hrg", is_equal_approx(eff7c, -left7c / float(e7c.mhp)) and total7c_neg <= budget7c + 1.0 and not e7c.has_meta(XTianqiCombat.META_DOT_USED),
		[eff7c, -left7c / float(e7c.mhp), total7c_neg, budget7c])
	XGuardianRework.STRIP = true

	# 八、T456 验收 2：小怪分支逆祷导入不重复扣、不翻正
	var sp := _state(true)
	var a_prayer: XActor = sp.actor(1)
	var a_imp: XActor = sp.actor(2)
	var a_norm: XActor = sp.actor(8)
	var lg8 := XBattleLogic.new()
	lg8.setup(1, sp)
	if lg8.has_meta("xalien"):
		lg8.get_meta("xalien").party[a_prayer] = {"item": {}, "affix": "prayer", "config": {}}
	else:
		var prayer_gear := XGear.template("armor", 2617)
		prayer_gear["alien"] = {"affix": "prayer"}
		a_prayer.equips[a_prayer.equip_slots().find(int(prayer_gear.etypeId))] = prayer_gear
	var mob8: XEnemy = lg8.enemies[0]
	_add_states(mob8, [21])  # 灼伤 V -5%，来源是逆祷导入角色
	mob8.state_origins[21] = weakref(a_prayer)
	var pb8 := XAlienBattle.prayer_regen_block(mob8)
	var rr8: Array = mob8.regen_rates(pb8)
	var dh8_0 := floorf(mob8.mhp * float(rr8[0]) * float(rr8[1]))
	var dh8 := XBattleLogic._apply_imported_regen(mob8, rr8, pb8, [21], dh8_0)
	_check("tq.mob.imported_prayer_no_double_deduct_no_flip", pb8 < 0.0 and dh8 <= 0.0 and is_equal_approx(dh8, 0.0), [pb8, rr8, dh8_0, dh8])

	# 八 b、小怪混合：逆祷导入(-5%) ＋ 非逆祷导入(-4%) ＋ 普通非导入(-2%)
	_add_states(mob8, [20, 18])
	mob8.state_origins[20] = weakref(a_imp)
	mob8.state_origins[18] = weakref(a_norm)
	var pb8b := XAlienBattle.prayer_regen_block(mob8)
	var rr8b: Array = mob8.regen_rates(pb8b)
	var dh8b_0 := floorf(mob8.mhp * float(rr8b[0]) * float(rr8b[1]))
	var dh8b := XBattleLogic._apply_imported_regen(mob8, rr8b, pb8b, [20, 21], dh8b_0)
	var other8b := floorf(mob8.mhp * -0.02 * float(rr8b[1]))
	var want8b := other8b - floorf(maxf(0.0, other8b - dh8b_0) * XImportedBalance.DOT_RATE)
	_check("tq.mob.imported_mixed_prayer_and_normal", is_equal_approx(dh8b, want8b) and dh8b < 0.0, [pb8b, rr8b, dh8b_0, dh8b, want8b])

	# 八 c、首领封顶关（走 else 分支）＋ 逆祷导入：同样不重复扣、不翻正
	XTianqiCombat.BOSS_NEG_HRG_CAP = false
	var lg8c := XBattleLogic.new()
	lg8c.setup(465, sp)
	if lg8c.has_meta("xalien"):
		lg8c.get_meta("xalien").party[a_prayer] = {"item": {}, "affix": "prayer", "config": {}}
	var boss8c: XEnemy = lg8c.enemies[0]
	_add_states(boss8c, [21])
	boss8c.state_origins[21] = weakref(a_prayer)
	var pb8c := XAlienBattle.prayer_regen_block(boss8c)
	var rr8c: Array = boss8c.regen_rates(pb8c)
	var dh8c_0 := floorf(boss8c.mhp * float(rr8c[0]) * float(rr8c[1]))
	var dh8c := XBattleLogic._apply_imported_regen(boss8c, rr8c, pb8c, [21], dh8c_0)
	_check("tq.boss.cap_off_imported_prayer_no_flip", pb8c < 0.0 and is_equal_approx(dh8c, 0.0), [pb8c, rr8c, dh8c])
	XTianqiCombat.BOSS_NEG_HRG_CAP = true

	# 九、T456 验收 3：关 T332（DOT_NO_WAREHOUSE=false）＋ 开封顶（BOSS_NEG_HRG_CAP=true）时：243 仍封 5%，再生不夹（与注释一致），且清账
	XState.current = s
	var was_t332 := XTianqiCombat.DOT_NO_WAREHOUSE
	XTianqiCombat.DOT_NO_WAREHOUSE = false
	XTianqiCombat.BOSS_NEG_HRG_CAP = true
	var pair9 := _cloak_battle(s, 465)
	var lg9: XBattleLogic = pair9[0]
	var e9: XEnemy = pair9[1]
	_add_states(e9, BURN5)
	var budget9 := floorf(float(e9.mhp) * 0.05)
	lg9.turn = 11
	e9.hp = e9.mhp
	XExtDot.tick(lg9, e9, [])
	var dot9 := float(e9.mhp) - float(e9.hp)
	var hp9_before_regen := float(e9.hp)
	var want9_regen := -floorf(float(e9.mhp) * e9.hrg * e9.rec)  # 关 T332：原版 ×w²（-14%×4=-56%），不夹
	lg9._regenerate(e9, [])
	var regen9 := hp9_before_regen - float(e9.hp)
	_check("tq.f29.t332_off_cap_on_243_capped_regen_uncapped", is_equal_approx(dot9, budget9) and is_equal_approx(regen9, want9_regen) and regen9 > budget9 * 5.0 and not e9.has_meta(XTianqiCombat.META_DOT_USED),
		[dot9, budget9, regen9, want9_regen])
	XTianqiCombat.DOT_NO_WAREHOUSE = was_t332

	# 十、T456 验收 6：State 261 怨毒（同为 pct100，5 名首领魔法技可被反射回自身）纳入 5% 预算，小怪不封、西游零变化
	var lg10 := XBattleLogic.new()
	lg10.setup(411, s)  # 传火邪妖（Enemy #463，施放 2598 怨毒的 MOG_BossHP 首领，自身带正再生，单测 XExtDot.tick 扣血量）
	var e10: XEnemy = lg10.enemies[0]
	_add_states(e10, [261])
	lg10.turn = 11
	e10.hp = e10.mhp
	XExtDot.tick(lg10, e10, [])
	var l10 := float(e10.mhp) - float(e10.hp)
	var b10 := floorf(float(e10.mhp) * 0.05)
	_check("tq.boss.state_261_capped_5pct", XTianqiCombat.is_neg_hrg_boss(e10) and is_equal_approx(l10, b10), [l10, b10, e10.mhp])
	var lg10_mob := XBattleLogic.new()
	lg10_mob.setup(1, s)
	var e10_mob: XEnemy = lg10_mob.enemies[0]
	_add_states(e10_mob, [261])
	var l10_mob := _turn_loss(lg10_mob, e10_mob, 11)
	_check("tq.mob.state_261_not_capped", not XTianqiCombat.is_neg_hrg_boss(e10_mob) and l10_mob > float(e10_mob.mhp) * 0.5, [l10_mob, e10_mob.mhp])
	XState.current = sx
	var lx10 := XBattleLogic.new()
	lx10.setup(4, sx)
	var ex10: XEnemy = lx10.enemies[0]
	_add_states(ex10, [261])
	var lx10_on := _turn_loss(lx10, ex10, 11)
	XTianqiCombat.BOSS_NEG_HRG_CAP = false
	var lx10_off := _turn_loss(lx10, ex10, 11)
	_check("xiyou.state_261_unchanged_on_eq_off", absf(lx10_on - 8000.0) < 2500.0 and absf(lx10_off - 8000.0) < 2500.0 and not ex10.has_meta(XTianqiCombat.META_DOT_USED), [lx10_on, lx10_off])
	XTianqiCombat.BOSS_NEG_HRG_CAP = true

	XTianqiCombat.BOSS_NEG_HRG_CAP = was_cap
	XGuardianRework.STRIP = was_strip
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
