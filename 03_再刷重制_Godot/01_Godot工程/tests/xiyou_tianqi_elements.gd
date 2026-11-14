extends Node
## 天启篇元素系统重做（XTianqiElements，天启篇_元素系统重做方案_v0.7）专项：
## 一、牌组生成：1~33 层 60/60/20 不变量、1~5 层无免、体质禁用、同层互斥、读档持久化。
## 二、固定入口与异化怪：34 鸿钧、35 影子、36 骑士三阶段、里副本/塔外首领、化形/终焉仅承免疫。
## 三、伤害倍率与物理无属性：物理 1→0（保留 hitType=1）、弱+50%/转+25%/抗-33%/免0%+「无效」弹字、旧克制与吸收移除。
## 四、弱点暴露 + 破绽取 max；高阶 11 虚空吞没 / 12 混沌随机 / 13 空间空蚀 15% 真伤；七印天卷 resist_down。
## 五、技能转属（水/风/虚空/混沌/Option A vs B/passiveELUP）、转换书（1039 改名/3101~3105/互斥/当铺/炼狱证道掉落）。
## 六、开关关闭与西游原版档完全不回归。
## 七、gpt 甲档核查返修：旧档首建牌组由存档种子派生、Boss 面板按实际模式显示、免疫跳过 respond／establish、
##     新编号不撞生成数据库、牌组 JSON 往返与固定入口浮点归一。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) <= eps


func _tq_state(diff := "lianyu") -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var lineup := [w[0], w[1], w[2], w[3], w[5]]
	var s := XTianqi.start_new_game(3, diff, lineup)
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


func _west_state() -> XState:
	var s := XState.new_game_blank()
	s.difficulty = 3
	s.add_actor(1)
	s.map_id = 4
	XState.current = s
	return s


func _skill_stub(id: int, elem: int, hit_type := 2, formula := "1000", multi := []) -> Dictionary:
	var val := float(formula) if formula.is_valid_float() else 1000.0
	var prog := {
		"version": 1, "status": "pure", "locals": ["value"],
		"source": {"sha256": "test_%d" % id},
		"steps": [{"op": "set", "name": "value", "value": {"op": "literal", "value": val}}],
		"result": "value",
	}
	var sk := {
		"id": id, "name": "TestSkill_%d" % id, "scope": 1, "hitType": hit_type,
		"stypeId": 1, "mpCost": 0, "tpCost": 0, "effects": [], "note": "", "meta": {},
		"damage": {"type": 1, "elementId": elem, "critical": false, "variance": 0, "formula": formula, "formulaProgram": prog},
	}
	if not multi.is_empty():
		sk["yep"] = {"multipleElements": multi}
	return sk


func _enemy_floor(floor_no: int) -> XEnemy:
	var eid := int(XDB.table("Troops")[int(XGuardianRework.TROOPS[floor_no])].members[0].enemyId)
	var e := XEnemy.new()
	e.setup(eid, 3)
	return e


## 记 _establish（respond／establish 状态回调入口）调用次数
class _EstablishCounter extends XBattleLogic:
	var establish_calls := 0

	func _establish(u: XBattler, t: XBattler, r: Dictionary) -> void:
		establish_calls += 1
		super(u, t, r)


func _run() -> void:
	seed(20261114)
	_test_deck_invariants()
	_test_fixed_and_alien()
	_test_rates_and_popup()
	_test_exposure_higher_qiyin()
	_test_shifts_books_shop_drop()
	_test_switches_and_west_regression()
	_test_review_fixes()
	XState.current = null
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL:%s -> %s" % [r.name, str(r.detail)])
	print("TEST_RESULT=%s" % JSON.stringify({"total": results.size(), "passed": passed}))
	get_tree().quit(0 if passed == results.size() else 1)


func _test_deck_invariants() -> void:
	var s := _tq_state()
	var d1 := XTianqiElements.ensure_deck(s, 12345)
	_check("deck_valid_seed_12345", XTianqiElements.validate_floor_deck(d1), d1.size())
	var f1 := XTianqiElements.floor_deck(s, 1)
	var d1_again := XTianqiElements.ensure_deck(s)
	_check("deck_persists_without_override", JSON.stringify(d1_again["1"]) == JSON.stringify(f1), f1)
	var all_ok := true
	for k in range(20):
		var dd := XTianqiElements.ensure_deck(s, 7000 + k * 37)
		if not XTianqiElements.validate_floor_deck(dd):
			all_ok = false
			break
	_check("deck_valid_20_seeds", all_ok)
	# 验证 1~5 层无免疫 + 28 层体质不落弱点
	var dd0 := XTianqiElements.ensure_deck(s, 20261114)
	var low_no_imm := true
	for f in range(1, 6):
		if not (dd0[str(f)].immune as Array).is_empty():
			low_no_imm = false
	_check("floors_1_to_5_no_immune", low_no_imm)
	var ban28: Array = XTianqiElements.data().guardian_constitutions["28"]
	var w28: Array = dd0["28"].weak
	_check("floor_28_weak_excludes_constitution", not w28.any(func(e): return ban28.has(int(e))), [w28, ban28])


func _test_fixed_and_alien() -> void:
	var s := _tq_state()
	XTianqiElements.ensure_deck(s, 99911)
	# 34 鸿钧
	var hj := XEnemy.new()
	hj.setup(1, 3)
	hj.horseman = {"rec": {"_ref": "hongjun"}, "knight": false}
	var hp := XTianqiElements.enemy_profile(hj, null, s)
	_check("hongjun_2w_2r_1i_excl_7_8", hp.weak.size() == 2 and hp.resist.size() == 2 and hp.immune.size() == 1 and not hp.weak.has(7) and not hp.weak.has(8), hp)
	# 35 影子
	var lg_sh := XBattleLogic.new()
	lg_sh.setup(2, s)
	var yz := XEnemy.new()
	yz.setup(1, 3)
	yz.horseman = {"rec": {"_ref": ""}, "knight": true}
	lg_sh.set_meta(XTianqiHorsemen.META, {"mode": "shadow", "phase": 1})
	var yp := XTianqiElements.enemy_profile(yz, lg_sh, s)
	_check("yingzi_2w_2r_1i", yp.weak.size() == 2 and yp.resist.size() == 2 and yp.immune.size() == 1 and yp.source == "yingzi", yp)
	# 36 骑士三阶段：每阶段 2 弱 2 抗 1 免、同阶段互不重复、三阶段各自全不重复、同种子重读不变、旧 1 弱存档重掷
	var lg_kn := XBattleLogic.new()
	lg_kn.setup(2, s)
	var kn := XEnemy.new()
	kn.setup(1, 3)
	kn.horseman = {"rec": {"_ref": ""}, "knight": true}
	lg_kn.set_meta(XTianqiHorsemen.META, {"mode": "body", "phase": 1})
	var kp1 := XTianqiElements.enemy_profile(kn, lg_kn, s)
	var msg2 := XTianqiElements.on_horsemen_phase(lg_kn, kn, 2)
	var kp2 := XTianqiElements.enemy_profile(kn, lg_kn, s)
	XTianqiElements.on_horsemen_phase(lg_kn, kn, 3)
	var kp3 := XTianqiElements.enemy_profile(kn, lg_kn, s)
	var k_phases := [kp1, kp2, kp3]
	var k_counts_ok := true
	var k_intra_distinct := true
	var all_w := {}
	var all_r := {}
	var all_i := {}
	for kp in k_phases:
		if kp.weak.size() != 2 or kp.resist.size() != 2 or kp.immune.size() != 1:
			k_counts_ok = false
		var seen := {}
		for e in kp.weak:
			seen[int(e)] = true
			all_w[int(e)] = true
		for e in kp.resist:
			seen[int(e)] = true
			all_r[int(e)] = true
		for e in kp.immune:
			seen[int(e)] = true
			all_i[int(e)] = true
		if seen.size() != 5:
			k_intra_distinct = false
	var adj_no_repeat := true
	for idx in range(2):
		for e in k_phases[idx].weak:
			if (k_phases[idx + 1].weak as Array).has(int(e)):
				adj_no_repeat = false
	_check("knight_3_phases_2w_2r_1i_no_repeat_weak",
		k_counts_ok and k_intra_distinct and adj_no_repeat
		and all_w.size() == 6 and all_r.size() == 6 and all_i.size() == 3
		and msg2.contains("P2"), [kp1, kp2, kp3])
	var s_same := _tq_state()
	XTianqiElements.ensure_deck(s_same, 99911)
	var same_ok := true
	for ph in range(1, 4):
		var a_d := XTianqiElements.fixed_deal(s_same, "knight", ph)
		var b_d := XTianqiElements.fixed_deal(s, "knight", ph)
		if JSON.stringify(a_d.weak) != JSON.stringify(b_d.weak) or JSON.stringify(a_d.resist) != JSON.stringify(b_d.resist) or JSON.stringify(a_d.immune) != JSON.stringify(b_d.immune):
			same_ok = false
	_check("knight_same_seed_reload_unchanged", same_ok)
	var s_legacy := _tq_state()
	XTianqiElements.ensure_deck(s_legacy, 99911)
	s_legacy.flags.tianqi.elements.fixed["knight:1"] = {"weak": [2], "resist": [3, 4], "immune": [5]}
	s_legacy.flags.tianqi.elements.fixed["knight:2"] = {"weak": [6], "resist": [7, 8], "immune": [9]}
	s_legacy.flags.tianqi.elements.fixed["knight:3"] = {"weak": [14], "resist": [15, 2], "immune": [3]}
	var legacy_redeal_ok := true
	for ph in range(1, 4):
		var a_l := XTianqiElements.fixed_deal(s_legacy, "knight", ph)
		var b_l := XTianqiElements.fixed_deal(s, "knight", ph)
		if JSON.stringify(a_l.weak) != JSON.stringify(b_l.weak) or JSON.stringify(a_l.resist) != JSON.stringify(b_l.resist) or JSON.stringify(a_l.immune) != JSON.stringify(b_l.immune):
			legacy_redeal_ok = false
	_check("knight_legacy_1w_save_redeals_deterministically", legacy_redeal_ok)
	# 里副本 Boss vs 精英；普通怪
	var qb := XEnemy.new()
	qb.setup(1, 3)
	qb.horseman = {"rec": {"_ref": "qiyin", "_qiyin_boss": true}, "knight": false}
	var qe := XEnemy.new()
	qe.setup(1, 3)
	qe.horseman = {"rec": {"_ref": "qiyin"}, "knight": false}
	_check("qiyin_boss_has_deck_elite_neutral",
		XTianqiElements.enemy_profile(qb, null, s).weak.size() == 2 and XTianqiElements.enemy_profile(qe, null, s).weak.is_empty())
	# 化形异化怪只继承当前楼层免疫
	var lg_al := XBattleLogic.new()
	lg_al.setup(int(XGuardianRework.TROOPS[10]), s)
	var f10 := XTianqiElements.floor_deck(s, 10)
	var alien := _enemy_floor(10)
	lg_al.set_meta(XTianqiPlagueAlien.META, {"units": {alien: {"tier": "huaxing"}}})
	var ap := XTianqiElements.enemy_profile(alien, lg_al, s)
	_check("alien_huaxing_only_immune", ap.source == "alien" and ap.weak.is_empty() and ap.resist.is_empty() and JSON.stringify(ap.immune) == JSON.stringify(f10.immune), [ap, f10])


func _test_rates_and_popup() -> void:
	var s := _tq_state()
	XTianqiElements.ensure_deck(s, 55112)
	var a: XActor = s.battle_members()[0]
	var lg := XBattleLogic.new()
	lg.setup(int(XGuardianRework.TROOPS[12]), s)
	XTianqiElements.start(lg)
	var boss: XEnemy = lg.enemies[0]
	boss.recover_all()
	var prof := XTianqiElements.enemy_profile(boss, lg, s)
	var w_elem := int(prof.weak[0])
	var r_elem := int(prof.resist[0])
	var i_elem := int(prof.immune[0])
	var n_elem := 0
	for e in XTianqiElements.BASE_ELEMENTS:
		if not prof.weak.has(e) and not prof.resist.has(e) and not prof.immune.has(e):
			n_elem = e
			break
	# 旧克制网与吸收失效
	_check("old_matchup_neutralized", _near(XDamage.matchup(w_elem, [r_elem]), 1.0))
	_check("old_absorb_disabled", not boss.is_absorb_element(2) and not boss.is_absorb_element(3))
	# 物理 1 → 无属性 0（仍保留 hitType=1）
	var phys_sk := _skill_stub(98001, 1, 1, "1000")
	var phys_calc := XDamage.calculate(phys_sk, a, boss, {"preview": true, "tianqi_logic": lg})
	_check("physical_becomes_neutral_keep_hittype1",
		XDamage.is_physical(phys_sk) and int(phys_calc.breakdown.row.element) == 0 and _near(float(phys_calc.breakdown.row.resistance), 1.0), phys_calc.breakdown.row)
	# 弱点 +50% / 转换书弱点 +25% / 抗性 -33% / 免疫 0%
	var cw := XDamage.calculate(_skill_stub(98002, w_elem, 2, "1000"), a, boss, {"preview": true, "tianqi_logic": lg})
	var cn := XDamage.calculate(_skill_stub(98003, n_elem, 2, "1000"), a, boss, {"preview": true, "tianqi_logic": lg})
	var cr := XDamage.calculate(_skill_stub(98004, r_elem, 2, "1000"), a, boss, {"preview": true, "tianqi_logic": lg})
	var ci := XDamage.calculate(_skill_stub(98005, i_elem, 2, "1000"), a, boss, {"preview": true, "tianqi_logic": lg})
	_check("weak_50_resist_33_immune_0",
		_near(float(cw.breakdown.row.resistance), 1.5)
		and _near(float(cn.breakdown.row.resistance), 1.0)
		and _near(float(cr.breakdown.row.resistance), 0.67)
		and _near(float(ci.breakdown.row.resistance), 0.0) and float(ci.value) == 0.0,
		[cw.breakdown.row.resistance, cr.breakdown.row.resistance, ci.value])
	# 转换书命中弱点：+25%（1.25）
	var c_skill_id := 11201
	var c_sk := XDB.rec("Skills", c_skill_id)
	var conv_elem := int(c_sk.get("meta", {}).get("DamageElements", 14))
	# 给 Boss 临时指定弱点为 conv_elem 以测转换书 1.25
	var saved_weak: Array = XTianqiElements.floor_deck(s, 12).weak.duplicate()
	var saved_imm: Array = XTianqiElements.floor_deck(s, 12).immune.duplicate()
	XTianqiElements.floor_deck(s, 12).weak = [conv_elem]
	XTianqiElements.floor_deck(s, 12).immune = []
	XTianqiElements.floor_deck(s, 12).resist = []
	a.learn_skill(c_skill_id)
	a.refresh_passive()
	var c_conv := XDamage.calculate(_skill_stub(98006, 2, 2, "1000"), a, boss, {"preview": true, "tianqi_logic": lg})
	var c_orig := XDamage.calculate(_skill_stub(98007, conv_elem, 2, "1000"), a, boss, {"preview": true, "tianqi_logic": lg})
	_check("converted_weak_25_vs_native_50",
		_near(float(c_conv.breakdown.row.resistance), 1.25) and _near(float(c_orig.breakdown.row.resistance), 1.5),
		[c_conv.breakdown.row.resistance, c_orig.breakdown.row.resistance, a.skills().filter(func(sk): return int(sk.get("id", 0)) == c_skill_id), XDB.rec("Skills", c_skill_id).get("meta", {})])
	a.forget_skill(c_skill_id)
	a.refresh_passive()
	XTianqiElements.floor_deck(s, 12).weak = saved_weak
	XTianqiElements.floor_deck(s, 12).immune = saved_imm
	# 实战免疫触发「无效」弹字
	var imm_sk := _skill_stub(98008, i_elem, 2, "1000")
	imm_sk["scope"] = 1
	var res_imm := lg.apply(a, imm_sk, boss)
	_check("immune_hit_triggers_wuxiao_popup",
		res_imm.hp == 0.0 and bool(res_imm.get("element_immune", false))
		and (res_imm.get("custom_popups", []) as Array).any(func(p): return str(p.get("text", "")) == "无效"), res_imm)


func _test_exposure_higher_qiyin() -> void:
	var s := _tq_state()
	XTianqiElements.ensure_deck(s, 66223)
	var a: XActor = s.battle_members()[0]
	var lg := XBattleLogic.new()
	lg.setup(int(XGuardianRework.TROOPS[14]), s)
	XTianqiElements.start(lg)
	var boss: XEnemy = lg.enemies[0]
	boss.recover_all()
	var prof := XTianqiElements.enemy_profile(boss, lg, s)
	var w_elem := int(prof.weak[0])
	var r_elem := int(prof.resist[0])
	var i_elem := int(prof.immune[0])
	# 弱点暴露：首击触发，次击生效 +11%；与破绽取 max；回合末清除
	var r1 := lg.apply(a, _skill_stub(98010, w_elem, 2, "1000"), boss)
	var exposed := XTianqiElements.has_weak_exposure(lg, boss)
	_check("weak_exposure_triggers_and_caps_with_affix",
		bool(r1.get("weak_exposed_now", false)) and exposed
		and _near(XTianqiElements.combined_exposure_pct(lg, boss, 8.0), 11.0)
		and _near(XTianqiElements.combined_exposure_pct(lg, boss, 15.0), 15.0))
	lg.end_turn()
	_check("weak_exposure_clears_end_turn", not XTianqiElements.has_weak_exposure(lg, boss))
	# 11 虚空：无视抗/免 +25% 并吞没当前回合抗性
	var v_calc := XDamage.calculate(_skill_stub(98011, 11, 2, "1000"), a, boss, {"preview": true, "tianqi_logic": lg})
	var r_void := lg.apply(a, _skill_stub(98012, 11, 2, "1000"), boss)
	var cr_after_void := XDamage.calculate(_skill_stub(98013, r_elem, 2, "1000"), a, boss, {"preview": true, "tianqi_logic": lg})
	var ci_after_void := XDamage.calculate(_skill_stub(98014, i_elem, 2, "1000"), a, boss, {"preview": true, "tianqi_logic": lg})
	_check("void_25_engulfs_resist_not_immune",
		_near(float(v_calc.breakdown.row.resistance), 1.25)
		and bool(r_void.get("void_engulfed", false))
		and _near(float(cr_after_void.breakdown.row.resistance), 1.0)
		and _near(float(ci_after_void.breakdown.row.resistance), 0.0))
	lg.end_turn()
	# 12 混沌：+11%/+22%/+33%
	var chaos_ok := true
	var seen_rates := {}
	for k in range(25):
		var crnd := XDamage.calculate(_skill_stub(98015, 12, 2, "1000"), a, boss, {"tianqi_logic": lg, "random": lg._rule()})
		var rv := snappedf(float(crnd.breakdown.row.resistance), 0.01)
		seen_rates[rv] = true
		if not (rv == 1.11 or rv == 1.22 or rv == 1.33):
			chaos_ok = false
	_check("chaos_rolls_within_11_22_33", chaos_ok and seen_rates.size() >= 2, seen_rates.keys())
	# 13 空间：空蚀 15% 真伤无视盾；全被盾挡时不触发
	boss.recover_all()
	boss.shield = 9999999.0
	var hp_before_shield := boss.hp
	var r_sp_shield := lg.apply(a, _skill_stub(98016, 13, 2, "1000"), boss)
	_check("space_no_erosion_when_all_absorbed_by_shield",
		float(r_sp_shield.get("space_erosion", 0.0)) == 0.0 and _near(boss.hp, hp_before_shield))
	boss.shield = 0.0
	var sp_sk := _skill_stub(98017, 13, 2, "5000")
	var hp_pre := boss.hp
	var r_sp := lg.apply(a, sp_sk, boss)
	var net_loss := float(r_sp.hp)
	var erosion := float(r_sp.get("space_erosion", 0.0))
	_check("space_erosion_15pct_true_hp_loss",
		erosion > 0.0 and _near(erosion, floorf(net_loss * 0.15), 1.0)
		and _near(hp_pre - boss.hp, net_loss + erosion, 1.0),
		[net_loss, erosion, hp_pre - boss.hp])
	# 七印天卷 resist_down 无视 -33% 抗性
	XTianqiQiyinEffects._unit(lg, boss).resist_down = 3
	var cr_qiyin := XDamage.calculate(_skill_stub(98018, r_elem, 2, "1000"), a, boss, {"preview": true, "tianqi_logic": lg})
	var ci_qiyin := XDamage.calculate(_skill_stub(98019, i_elem, 2, "1000"), a, boss, {"preview": true, "tianqi_logic": lg})
	_check("qiyin_resist_down_neutralizes_resist_only",
		_near(float(cr_qiyin.breakdown.row.resistance), 1.0) and _near(float(ci_qiyin.breakdown.row.resistance), 0.0))


func _test_shifts_books_shop_drop() -> void:
	var s := _tq_state("lianyu")
	# 甲/乙/高阶技能改属（独立于 XTianqiSkills.CARDS）
	_check("skill_shift_1117_water", int(XDB.rec("Skills", 1117).damage.elementId) == 14)
	_check("skill_shift_2587_wind", int(XDB.rec("Skills", 2587).damage.elementId) == 15)
	_check("skill_shift_7090_wind", int(XDB.rec("Skills", 7090).damage.elementId) == 15)
	_check("skill_shift_2729_ice_wind",
		int(XDB.rec("Skills", 2729).damage.elementId) == 3 and (XDB.rec("Skills", 2729).get("yep", {}).get("multipleElements", []) as Array).has(15))
	_check("skill_shift_5759_ice_water",
		int(XDB.rec("Skills", 5759).damage.elementId) == 3 and (XDB.rec("Skills", 5759).get("yep", {}).get("multipleElements", []) as Array).has(14))
	_check("skill_shift_10640_void", int(XDB.rec("Skills", 10640).damage.elementId) == 11)
	_check("skill_shift_7327_chaos", int(XDB.rec("Skills", 7327).damage.elementId) == 12)
	# 物理转水/风 Option A vs Option B
	XTianqiElements.PHYSICAL_DUAL_KEEP_NEUTRAL = false
	_check("phys_shift_option_a_single", int(XDB.rec("Skills", 86).damage.elementId) == 14 and int(XDB.rec("Skills", 1226).damage.elementId) == 15)
	XTianqiElements.PHYSICAL_DUAL_KEEP_NEUTRAL = true
	var opt_b := XDB.rec("Skills", 86)
	_check("phys_shift_option_b_dual", int(opt_b.damage.elementId) == 0 and (opt_b.get("yep", {}).get("multipleElements", []) as Array).has(14))
	XTianqiElements.PHYSICAL_DUAL_KEEP_NEUTRAL = false
	# passiveELUP 改属
	_check("passive_1116_elup14", str(XDB.rec("Skills", 1116).note).contains("<passiveELUP14:") and str(XDB.rec("Skills", 2505).note).contains("<passiveELUP14:"))
	# 转换书 1039 改名 + 3101~3105 + 8 号当铺 + 互斥 + 仅炼狱/证道单档限1次掉落
	_check("book_1039_renamed_nature", str(XDB.rec("Items", 1039).name) == "元素转换:自然" and str(XDB.rec("CommonEvents", 641).name) == "元素自然")
	var item_water := XDB.rec("Items", 3101)
	var item_void := XDB.rec("Items", 3103)
	_check("new_books_exist_3101_3105", str(item_water.name) == "元素转换:水" and str(item_void.name) == "元素转换:虚空")
	var shop := XTianqiElements.shop_goods(s, 204, [[0, 1039, 0, 0]])
	_check("pawnshop_adds_water_wind", shop.any(func(g): return int(g[1]) == 3101) and shop.any(func(g): return int(g[1]) == 3102))
	var act: XActor = s.battle_members()[0]
	act.learn_skill(5068)
	act.learn_skill(11201)
	_check("conversion_skill_mutual_exclusion", not act.skill_ids.has(5068) and act.skill_ids.has(11201))
	act.forget_skill(11201)
	# 高阶转换书仅炼狱/证道掉落且单档每本限 1 次
	var s_low := _tq_state("jianxian")
	var tx_low := XTianqiElements.roll_higher_books(s_low, null, func(): return 0.0)
	_check("higher_books_blocked_below_lianyu", tx_low.is_empty() and s_low.item_count(3103) == 0)
	var tx_hi1 := XTianqiElements.roll_higher_books(s, null, func(): return 0.0)
	var tx_hi2 := XTianqiElements.roll_higher_books(s, null, func(): return 0.0)
	_check("higher_books_once_per_save_in_lianyu",
		tx_hi1.size() == 3 and s.item_count(3103) == 1 and s.item_count(3104) == 1 and s.item_count(3105) == 1 and tx_hi2.is_empty())


func _test_switches_and_west_regression() -> void:
	var s := _tq_state()
	XTianqiElements.ENABLED = false
	_check("switch_off_restores_original",
		str(XDB.rec("Items", 1039).name) == "元素转换:风"
		and XDB.rec("Items", 3101).is_empty()
		and XTianqiElements.shop_goods(s, 204, [[0, 1039, 0, 0]]).size() == 1)
	XTianqiElements.ENABLED = true
	var ws := _west_state()
	_check("west_save_untouched",
		not XTianqiElements.on(ws)
		and str(XDB.rec("Items", 1039).name) == "元素转换:风"
		and int(XDB.rec("Skills", 1117).damage.elementId) == 14
		and XTianqiElements.shop_goods(ws, 204, [[0, 1039, 0, 0]]).size() == 1)


func _test_review_fixes() -> void:
	# P2-1：旧天启篇档（无 elements 字段）首次建牌组由存档种子派生，不吃全局随机流；不存档重读牌组不变
	var s := _tq_state()
	s.flags.tianqi.erase("elements")
	seed(4242)
	var expect_next := randi()
	seed(4242)
	var deck_a := JSON.stringify(XTianqiElements.ensure_deck(s))
	var seed_a := int(s.flags.tianqi.elements.seed)
	_check("review1_first_deck_no_global_randi", randi() == expect_next)
	s.flags.tianqi.erase("elements")
	seed(9999)
	var deck_b := JSON.stringify(XTianqiElements.ensure_deck(s))
	_check("review1_old_save_reload_same_deck",
		deck_a == deck_b and seed_a == int(s.flags.tianqi.elements.seed) and seed_a == XTianqiElements.derived_seed(s), [seed_a, s.flags.tianqi.elements.seed])
	var s2 := _tq_state()
	s2.orb_seed = s.orb_seed + 1
	s2.flags.tianqi.erase("elements")
	_check("review1_seed_follows_save", XTianqiElements.derived_seed(s2) != seed_a and XTianqiElements.validate_floor_deck(XTianqiElements.ensure_deck(s2)))
	# 存档往返：to_dict → JSON → from_dict 后牌组、固定入口不变且是整数
	XState.current = s
	XTianqiElements.fixed_deal(s, "yingzi")
	XTianqiElements.fixed_deal(s, "hongjun")
	XTianqiElements.fixed_deal(s, "knight", 2)
	var before := JSON.stringify(s.flags.tianqi.elements)
	var s_rt := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	XState.current = s_rt
	var floors_rt := XTianqiElements.ensure_deck(s_rt)
	var yz := XTianqiElements.fixed_deal(s_rt, "yingzi")
	var hj := XTianqiElements.fixed_deal(s_rt, "hongjun")
	var kn := XTianqiElements.fixed_deal(s_rt, "knight", 2)
	var all_int := true
	for entry in [floors_rt["17"], yz, hj, kn]:
		for fld in ["weak", "resist", "immune"]:
			for x in entry[fld]:
				if not (x is int):
					all_int = false
	var el_rt: Dictionary = s_rt.flags.tianqi.elements
	var el0: Dictionary = s.flags.tianqi.elements
	_check("review_save_roundtrip_deck_equal",
		JSON.stringify(el_rt.floors) == JSON.stringify(el0.floors) and JSON.stringify(el_rt.fixed) == JSON.stringify(el0.fixed)
		and int(el_rt.seed) == int(el0.seed) and int(s_rt.orb_seed) == int(s.orb_seed), [before, JSON.stringify(el_rt)])
	_check("review_fixed_entries_float_normalized", all_int and yz.weak.size() == 2 and (yz.weak as Array).has(int(yz.weak[0])), [yz, hj, kn])
	# 新编号 3101~3105／11201~11205／9101~9105 不撞生成数据库（原表该号为空或在表外），且没被别的表外补招占用
	var clash := []
	for pair in [["Items", 3101], ["Skills", 11201], ["CommonEvents", 9101]]:
		var t: Array = XDB.table(pair[0])
		for k in range(5):
			var id: int = int(pair[1]) + k
			if id < t.size() and t[id] != null:
				clash.append("%s:%d" % [pair[0], id])
			if pair[0] == "Skills" and XTianqiSkills.has_new(id):
				clash.append("XTianqiSkills:%d" % id)
	_check("review_new_ids_no_db_clash", clash.is_empty(), clash)
	var synth_ok := true
	for k in range(5):
		if int(XDB.rec("Items", 3101 + k).get("id", 0)) != 3101 + k or int(XDB.rec("Skills", 11201 + k).get("id", 0)) != 11201 + k or int(XDB.rec("CommonEvents", 9101 + k).get("id", 0)) != 9101 + k:
			synth_ok = false
	_check("review_new_ids_resolve_to_synthetic", synth_ok)
	# P2-2：Boss 面板传本场 logic，影子战显示 yingzi 牌组、生存战不显示骑士牌组
	XState.current = s
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var kb := XEnemy.new()
	kb.setup(1, 3)
	kb.horseman = {"rec": {"_ref": ""}, "knight": true}
	var panel := XBossStatusPanel.new()
	panel.battler = kb
	panel.logic_source = func(): return lg
	lg.set_meta(XTianqiHorsemen.META, {"mode": "shadow", "phase": 1})
	var pp: Dictionary = panel._tq_profile()
	var yd := XTianqiElements.fixed_deal(s, "yingzi")
	_check("review2_panel_shadow_shows_yingzi",
		str(pp.get("source", "")) == "yingzi" and JSON.stringify(pp.weak) == JSON.stringify(yd.weak) and pp.weak.size() == 2, pp)
	lg.set_meta(XTianqiHorsemen.META, {"mode": "survival", "phase": 1})
	_check("review2_panel_survival_no_knight_deck", panel._tq_profile().is_empty(), panel._tq_profile())
	panel.free()
	# P2-3：免疫命中跳过 respond／establish；中立命中照跑；西游档照跑
	XTianqiElements.ensure_deck(s, 55112)
	var a: XActor = s.battle_members()[0]
	var lc := _EstablishCounter.new()
	lc.setup(int(XGuardianRework.TROOPS[12]), s)
	XTianqiElements.start(lc)
	var boss: XEnemy = lc.enemies[0]
	boss.recover_all()
	var prof := XTianqiElements.enemy_profile(boss, lc, s)
	var n_elem := 0
	for e in XTianqiElements.BASE_ELEMENTS:
		if not prof.weak.has(e) and not prof.resist.has(e) and not prof.immune.has(e):
			n_elem = e
			break
	var r_imm := lc.apply(a, _skill_stub(98101, int(prof.immune[0]), 2, "1000"), boss)
	var calls_imm := lc.establish_calls
	var r_neu := lc.apply(a, _skill_stub(98102, n_elem, 2, "1000"), boss)
	_check("review3_immune_skips_establish",
		calls_imm == 0 and bool(r_imm.get("element_immune", false)) and float(r_imm.hp) == 0.0
		and lc.establish_calls >= 1 and float(r_neu.hp) > 0.0, [calls_imm, lc.establish_calls, r_imm.hp, r_neu.hp])
	XTianqiElements.ENABLED = false
	var before_off := lc.establish_calls
	lc.apply(a, _skill_stub(98103, int(prof.immune[0]), 2, "1000"), boss)
	_check("review3_switch_off_establish_runs", lc.establish_calls > before_off)
	XTianqiElements.ENABLED = true
	var ws := _west_state()
	var lw := _EstablishCounter.new()
	lw.setup(2, ws)
	var we: XEnemy = lw.enemies[0]
	we.recover_all()
	lw.apply(ws.battle_members()[0], _skill_stub(98104, 2, 2, "0"), we)
	_check("review3_west_zero_damage_establish_runs", lw.establish_calls >= 1 and not XTianqiElements.immune_hit(lw, ws.battle_members()[0], _skill_stub(98104, 2), we, {"best_row": {"tianqiKind": "immune", "resistance": 0.0}}))
