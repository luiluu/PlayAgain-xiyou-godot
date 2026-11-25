extends Node
## 【小A·未经审查】T463（西游档补回真气×天道加成 1/100 合算＋修行页一致）＋ T465（西游档削弱五河琴里 159、天剑·非天 147）专项（Kyo 11-24 D283）。

var passed := 0
var total := 0


func _ready() -> void:
	_run.call_deferred()


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _stub_dmg(id: int, elem := 1, base_val := 10000.0) -> Dictionary:
	var prog := {
		"version": 1, "status": "pure", "locals": ["value"],
		"source": {"sha256": "t463_%d" % id},
		"steps": [{"op": "set", "name": "value", "value": {"op": "literal", "value": base_val}}],
		"result": "value",
	}
	return {"id": id, "name": "T463_%d" % id, "scope": 1, "hitType": 0, "stypeId": 1, "mpCost": 0, "tpCost": 0, "effects": [], "note": "", "meta": {},
		"damage": {"type": 1, "elementId": elem, "critical": false, "variance": 0, "formula": str(base_val), "formulaProgram": prog}}


func _make_xiyou() -> XState:
	var s := XState.new_game_blank()
	s.random_master = XRandomStream.hex64(20261124)
	s.set_switch(2494, true)
	XState.current = s
	return s


func _make_tianqi() -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s := XTianqi.start_new_game(3, "lianyu", lineup)
	XTianqi.take_pending()
	s.map_id = 4
	XState.current = s
	return s


func _run() -> void:
	var was_apply := XZhenqi.APPLY_TO_DAMAGE
	var was_nerf := XXiyouNerf.ENABLED
	var was_cl := XCanglong.REWORK
	var was_xf := XXufeng.REWORK
	var was_scale := XMagicWeapon.SCALE_99_TO_888
	var was_rel_cl := XImportedBalance.RELEASE_CANGLONG
	var was_rel_xf := XImportedBalance.RELEASE_XUFENG

	XZhenqi.APPLY_TO_DAMAGE = true
	XXiyouNerf.ENABLED = true
	XXiyouNerf.clear_cache()

	_check_t463_damage_chain()
	_check_t463_guide_and_retreat_sync()
	_check_t463_tianqi_untouched()
	_check_t465_table_pure_and_kotori()
	_check_t465_wpn87_save_sync()
	_check_t465_wpn87_runeword_save_sync()
	_check_t465_feitian_and_cri_cap()
	_check_t465_st2739_and_rollback()
	_check_t465_tianqi_untouched()

	# 还原全部全局开关
	XZhenqi.APPLY_TO_DAMAGE = was_apply
	XZhenqi.battle = {}
	XXiyouNerf.ENABLED = was_nerf
	XXiyouNerf.clear_cache()
	XCanglong.REWORK = was_cl
	XCanglong.clear_cache()
	XXufeng.REWORK = was_xf
	XXufeng.clear_cache()
	XMagicWeapon.SCALE_99_TO_888 = was_scale
	XImportedBalance.RELEASE_CANGLONG = was_rel_cl
	XImportedBalance.RELEASE_XUFENG = was_rel_xf
	XState.current = null
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_t463_t465", "passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _check_t463_damage_chain() -> void:
	# 1. scale_bonus 边界
	check("t463.scale_bonus_bounds",
		is_equal_approx(XZhenqi.scale_bonus(1.0), 1.0)
		and is_equal_approx(XZhenqi.scale_bonus(0.5), 0.5)
		and is_equal_approx(XZhenqi.scale_bonus(101.0), 2.0)
		and is_equal_approx(XZhenqi.scale_bonus(360.13 * 111.0), 1.0 + (360.13 * 111.0 - 1.0) / 100.0))

	# 2. 西游档：无天道层（普通 5 层）＋有天道层（洪荒 21 / 33 层）合算接入 XDamage
	var s := _make_xiyou()
	s.add_actor(1)
	s.set_battle_slot(0, 1)
	var a: XActor = s.actor(1)
	a.zhenqi = XZhenqi.from_save({"qi": 18000, "realm": 4})  # 化神：orig_rate ≈ 42.438
	var e := XEnemy.new()
	e.setup(1, 3)
	e.recover_all()
	var sk := _stub_dmg(99463, 1, 10000.0)

	# 2a) 无天道层（comp = 1.0）：eff = 1 + (rate - 1) / 100
	s.set_variable(20, 5)
	XZhenqi.battle_setup(s, 1)
	var want_no_comp := XZhenqi.scale_bonus(XZhenqi.rate(a))
	var dm_no_comp := XZhenqi.damage_mult(a, e)
	var r_on := XDamage.calculate(sk, a, e, {"variance": false})
	XZhenqi.APPLY_TO_DAMAGE = false
	var r_off := XDamage.calculate(sk, a, e, {"variance": false})
	XZhenqi.APPLY_TO_DAMAGE = true
	check("t463.no_comp_growth",
		absf(dm_no_comp - want_no_comp) < 1e-5
		and absf(float(r_on.breakdown.row.growth) - want_no_comp) < 1e-5
		and absf(float(r_off.breakdown.row.growth) - 1.0) < 1e-5
		and absf(float(r_on.value) / maxf(1.0, float(r_off.value)) - want_no_comp) < 0.01,
		[dm_no_comp, want_no_comp, r_on.value, r_off.value])

	# 2b) 洪荒 33 层道祖（qi=500000, realm=13, comp=111.0）：合算 1 + (rate*comp - 1)/100 ≈ 400.73×
	s.set_switch(2483, true)
	s.set_variable(20, 34)
	a.zhenqi = XZhenqi.from_save({"qi": 500000, "realm": 13})
	XZhenqi.battle_setup(s, 469)
	var orig_prod := XZhenqi.rate(a) * XZhenqi.comp_for("primordial", 33)
	var want_f33 := 1.0 + (orig_prod - 1.0) / 100.0
	var dm_f33 := XZhenqi.damage_mult(a, e)
	var r33 := XDamage.calculate(sk, a, e, {"variance": false})
	check("t463.primordial_f33_combined",
		absf(dm_f33 - want_f33) < 1e-4
		and dm_f33 > 400.0 and dm_f33 < 402.0
		and absf(float(r33.breakdown.row.growth) - want_f33) < 1e-4,
		[dm_f33, want_f33, r33.breakdown.row.growth])

	# 2c) 仅我方打敌人，敌人打我方／参考预览／元素吸收／治疗均不乘真气×天道
	var dm_enemy_to_actor := XZhenqi.damage_mult(e, a)
	var dm_ref := XZhenqi.damage_mult(a, e, {"reference": true})
	var r_ref := XDamage.calculate(sk, a, e, {"variance": false, "reference": true})
	var heal_sk := sk.duplicate(true)
	heal_sk.damage.type = 3
	var h_on := XDamage.calculate(heal_sk, a, a, {"variance": false})
	XZhenqi.APPLY_TO_DAMAGE = false
	var h_off := XDamage.calculate(heal_sk, a, a, {"variance": false})
	XZhenqi.APPLY_TO_DAMAGE = true
	check("t463.scope_guards",
		is_equal_approx(dm_enemy_to_actor, 1.0)
		and is_equal_approx(dm_ref, 1.0)
		and is_equal_approx(float(r_ref.breakdown.row.growth), 1.0)
		and is_equal_approx(float(h_on.value), float(h_off.value)),
		[dm_enemy_to_actor, dm_ref, r_ref.breakdown.row.growth, h_on.value, h_off.value])
	XZhenqi.battle = {}


func _check_t463_guide_and_retreat_sync() -> void:
	var s := _make_xiyou()
	s.add_actor(1)
	s.set_battle_slot(0, 1)
	var a: XActor = s.actor(1)
	# 无天道层：普通 5 层，化神 qi=18000 → 实际生效 1+(42.438-1)/100 ≈ 1.414 (+41%, ×1.4)
	s.set_variable(20, 5)
	a.zhenqi = XZhenqi.from_save({"qi": 18000, "realm": 4})
	var eff5 := XZhenqi.combined_mult(a, "normal", 5, s)
	var p5 := "\n".join(XGuide.panel_rows(s, a).map(func(r): return str(r.get("text", ""))))
	var d5 := "\n".join(XGuide.detail_rows(s, a).map(func(r): return str(r.get("text", ""))))
	var st5 := str(XGuide.strip_text(s, a)[0])
	var desc5 := XZhenqi.describe(s, a)
	check("t463.guide_no_comp_consistent",
		p5.contains("真气：伤害 \\C[3]%s\\C[0]" % XGuide.dmg_pct(eff5))
		and not p5.contains("天道加持")
		and d5.contains("真气：伤害 %s" % XGuide.dmg_pct(eff5))
		and st5.contains(XZhenqi.mult(eff5))
		and desc5.contains("×%.1f" % eff5),
		[eff5, p5, d5, st5, desc5])

	# 有天道层：洪荒 33 层，道祖 qi=500000 → 单真气 4.59× (+359%)，合算 400.73× (+39973%, ×400.7)
	s.set_switch(2483, true)
	s.set_variable(20, 33)
	a.zhenqi = XZhenqi.from_save({"qi": 500000, "realm": 13})
	var single33 := XZhenqi.display_rate(s, a)
	var eff33 := XZhenqi.combined_mult(a, "primordial", 33, s)
	var p33 := "\n".join(XGuide.panel_rows(s, a).map(func(r): return str(r.get("text", ""))))
	var d33 := "\n".join(XGuide.detail_rows(s, a).map(func(r): return str(r.get("text", ""))))
	var st33 := str(XGuide.strip_text(s, a)[0])
	var act_pg := "\n".join(XZhenqi.menu(s, {"page": "actor", "id": 1}).get("lines", []))
	check("t463.guide_with_comp_consistent",
		p33.contains("真气：伤害 \\C[3]%s\\C[0]" % XGuide.dmg_pct(single33))
		and p33.contains("天道加持：连同真气，本层伤害 \\C[3]%s\\C[0]（自动生效）" % XGuide.dmg_pct(eff33))
		and d33.contains("真气与天道（洪荒·第33层）：伤害 %s" % XGuide.dmg_pct(eff33))
		and st33.contains(XZhenqi.mult(eff33))
		and act_pg.contains("真气 500000　加成 ×%.1f（本层连同天道 ×%.1f）" % [single33, eff33]),
		[single33, eff33, p33, d33, st33, act_pg])


func _check_t463_tianqi_untouched() -> void:
	var tq := _make_tianqi()
	var aid := int(tq.flags.tianqi.lineup[0])
	if tq.actor(aid) == null:
		XTianqi._joining = true
		tq.add_actor(aid)
		XTianqi._joining = false
	var a: XActor = tq.actor(aid)
	a.zhenqi = XZhenqi.from_save({"qi": 500000, "realm": 13})
	var e := XEnemy.new()
	e.setup(1, 3)
	XZhenqi.battle = {"comp": 111.0}
	var sk := _stub_dmg(99464, 1, 10000.0)
	var res := XDamage.calculate(sk, a, e, {"variance": false})
	check("t463.tianqi_zero_change",
		is_equal_approx(XZhenqi.damage_mult(a, e), 1.0)
		and is_equal_approx(XZhenqi.effective_rate(a, tq), 1.0)
		and is_equal_approx(XZhenqi.combined_mult(a, "primordial", 33, tq), 1.0)
		and is_equal_approx(float(res.breakdown.row.growth), 1.0)
		and XGuide.strip_text(tq, a) == ["", false],
		[XZhenqi.damage_mult(a, e), res.breakdown.row.growth, XGuide.strip_text(tq, a)])
	XZhenqi.battle = {}


func _check_t465_table_pure_and_kotori() -> void:
	var s := _make_xiyou()
	s.add_actor(159)
	s.set_battle_slot(0, 159)
	var k: XActor = s.actor(159)
	k.change_level(80)
	k.param_mark_dirty()
	k.refresh_passive()
	k.recover_all()
	var e := XEnemy.new()
	e.setup(1, 3)

	# 1. 共享原表零污染
	var raw_10055: Dictionary = XDB.table("Skills")[10055]
	var raw_w87: Dictionary = XDB.table("Weapons")[87]
	var raw_10485: Dictionary = XDB.table("Skills")[10485]
	var raw_st2739: Dictionary = XDB.table("States")[2739]
	check("t465.shared_tables_untouched",
		str(raw_10055.damage.formula).contains("100000+")
		and str(raw_10055.damage.formula).contains("v[1510]*8")
		and is_equal_approx(float(raw_w87.yep.elementAmplify["1"]), 12.0)
		and str(raw_10485.damage.formula).contains("* 43300 *")
		and is_equal_approx(float(raw_st2739.effects[0].k), 2.5),
		[raw_10055.damage.formula, raw_w87.yep.elementAmplify, raw_st2739.effects[0].k])

	# 2. 五河琴里 10055~10058 公式与卡面同步（v[1510]=0 与 500 实算验证）
	for sid in [10055, 10056, 10057, 10058]:
		var sk := XDB.rec("Skills", sid)
		var atk_c := 30.0 if sid in [10055, 10058] else 300.0
		var vars0 := []
		vars0.resize(1600)
		vars0.fill(0)
		var vars500 := vars0.duplicate()
		vars500[1510] = 500
		var v0 := XDamage.eval_formula(sk, k, e, vars0)
		var v500 := XDamage.eval_formula(sk, k, e, vars500)
		var lv_f := 1.0 + float(k.level) * 0.25
		var m_f := 1.0 + float(XSkillMastery.level(k, sid))
		var want0 := (5000.0 + float(k.atk) * atk_c) * 1.0 * m_f * lv_f
		var want500 := (5000.0 + float(k.atk) * atk_c) * (1.0 + 500.0 * 2.0) * m_f * lv_f
		check("t465.kotori_sk_%d" % sid,
			absf(v0 - want0) < 1.0 and absf(v500 - want500) < 10.0
			and str(sk.note).contains("[5000+") and str(sk.note).contains("火力值*2]"),
			[v0, want0, v500, want500])

	# 3. 琴里专武 WPN 87 数值与卡面同步（注意 XTextFix 已把「最终伤害」规范为「伤害」）
	var w87 := XDB.rec("Weapons", 87)
	check("t465.kotori_wpn87_data_and_text",
		is_equal_approx(float(w87.yep.elementAmplify["1"]), 2.0)
		and is_equal_approx(float(w87.yep.elementAmplify["2"]), 2.0)
		and str(w87.meta.get("passiveHarmRi", "")) == "150"
		and str(w87.meta.get("SkillPass10055", "")).strip_edges() == "200%"
		and (str(w87.note).contains("神兵(伤害+150%)") or str(w87.note).contains("神兵(最终伤害+150%)"))
		and str(w87.note).contains("火焰/物理伤害+200%")
		and str(w87.note).contains("专属技能伤害+200%"),
		[w87.yep, w87.meta.get("passiveHarmRi"), w87.meta.get("SkillPass10055"), w87.note])


func _check_t465_wpn87_save_sync() -> void:
	# 模拟旧档（原版 weapon:87 + 宝珠/词缀增量 +0.35 物伤）：读档同步到西游档削弱值且完整保留增量，关开关读档还原
	XXiyouNerf.ENABLED = false
	XXiyouNerf.clear_cache()
	var s := _make_xiyou()
	s.add_actor(159)
	var k: XActor = s.actor(159)
	var w := k.make_equip("weapon", 87)
	var orb_delta := 0.35
	w.yep.elementAmplify["1"] = float(w.yep.elementAmplify["1"]) + orb_delta
	k.equips[0] = w
	var dump = JSON.parse_string(JSON.stringify(s.to_dict()))

	XXiyouNerf.ENABLED = true
	XXiyouNerf.clear_cache()
	var s_nerf := XState.from_dict(dump)
	var w_nerf: Dictionary = s_nerf.actor(159).equips[0]
	var e1_nerf := float(w_nerf.yep.elementAmplify["1"])
	var dump_nerf = JSON.parse_string(JSON.stringify(s_nerf.to_dict()))

	XXiyouNerf.ENABLED = false
	XXiyouNerf.clear_cache()
	var s_back := XState.from_dict(dump_nerf)
	var w_back: Dictionary = s_back.actor(159).equips[0]
	var e1_back := float(w_back.yep.elementAmplify["1"])
	XXiyouNerf.ENABLED = true
	XXiyouNerf.clear_cache()
	check("t465.wpn87_save_roundtrip_preserves_orb",
		absf(e1_nerf - (2.0 + orb_delta)) < 0.001
		and absf(e1_back - (12.0 + orb_delta)) < 0.001
		and (str(w_nerf.note).contains("神兵(伤害+150%)") or str(w_nerf.note).contains("神兵(最终伤害+150%)"))
		and (str(w_back.note).contains("神兵(伤害+600%)") or str(w_back.note).contains("神兵(最终伤害+600%)")),
		[orb_delta, e1_nerf, e1_back])


func _check_t465_wpn87_runeword_save_sync() -> void:
	XXiyouNerf.original_data()
	var s := _make_xiyou()
	s.add_actor(159)
	var w := XGear.template("weapon", 87)
	var recipe: Dictionary = XDB.table("Runewords").filter(func(r): return r is Dictionary and r.get("name") == "诛魔")[0]
	w.upgradeSlots = 0
	w.upgrades = recipe.materials.map(func(id): return {"item": int(id), "name": "", "cost": 1})
	XRunewords.check(w)
	w.meta["t465_instance_only"] = {"sentinel": true}
	s.actor(159).equips[0] = w
	var old_meta: Dictionary = w.meta.duplicate(true)
	var old_note := str(w.note)

	XXiyouNerf.ENABLED = true
	var s_nerf := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	var w_nerf: Dictionary = s_nerf.actor(159).equips[0]
	var expected := old_meta.duplicate(true)
	expected["passiveHarmRi"] = " " + str(230.0)
	for id in XXiyouNerf.KOTORI_SKILLS:
		expected["SkillPass%d" % id] = " 200%"
	check("t465.wpn87_runeword_preserves_meta",
		w.runewords == [int(recipe.id)] and float(old_meta.get("passiveHarmRi", 0)) == 680.0
		and w_nerf.meta == expected and is_equal_approx(float(w_nerf.yep.elementAmplify["1"]), 2.5)
		and not XXiyouNerf.sync_gear_item(w_nerf, true),
		[w.runewords, old_meta, w_nerf.meta, expected])

	XXiyouNerf.original_data()
	var s_back := XState.from_dict(JSON.parse_string(JSON.stringify(s_nerf.to_dict())))
	var w_back: Dictionary = s_back.actor(159).equips[0]
	check("t465.wpn87_runeword_restores_save",
		w_back.meta == old_meta and w_back.note == old_note, [w_back.meta, old_meta])
	XXiyouNerf.ENABLED = true


func _check_t465_feitian_and_cri_cap() -> void:
	var s := _make_xiyou()
	s.add_actor(147)
	s.set_battle_slot(0, 147)
	var f: XActor = s.actor(147)
	f.change_level(80)
	for vid in range(1580, 1590):
		s.set_variable(vid, 1)
	f.param_mark_dirty()
	f.refresh_passive()
	f.recover_all()
	var e := XEnemy.new()
	e.setup(1, 3)

	# D286：10072（6000）、10485（1200）、10486（3000）及暴击率 500% 封顶。
	var sk72 := XDB.rec("Skills", 10072)
	var sk85 := XDB.rec("Skills", 10485)
	var sk86 := XDB.rec("Skills", 10486)
	var vars := []
	vars.resize(1600)
	vars.fill(0)
	for vid in range(1580, 1590):
		vars[vid] = 1
	# 通过武器 traits 设三档暴击率，第一档在上限以下，其余两档均超过上限。
	var w_cri_low := {"kind": "weapon", "id": 99981, "base": 99981, "etypeId": 1, "wtypeId": 2, "params": [0,0,0,0,0,0,0,0],
		"traits": [{"code": 22, "dataId": 2, "value": 0.0}], "note": "", "meta": {}, "yep": {}}
	var w_cri15 := w_cri_low.duplicate(true)
	w_cri15.traits[0].value = 12.5
	var w_cri45 := w_cri_low.duplicate(true)
	w_cri45.traits[0].value = 42.5

	f.equips[0] = w_cri_low
	f.refresh_passive()
	var cri_low := f.cri
	var v85_low := XDamage.eval_formula(sk85, f, e, vars)
	var v86_low := XDamage.eval_formula(sk86, f, e, vars)

	f.equips[0] = w_cri15
	f.refresh_passive()
	var cri_15 := f.cri
	var v72_15 := XDamage.eval_formula(sk72, f, e, vars)
	var v85_15 := XDamage.eval_formula(sk85, f, e, vars)
	var v86_15 := XDamage.eval_formula(sk86, f, e, vars)

	f.equips[0] = w_cri45
	f.refresh_passive()
	var cri_45 := f.cri
	var v72_45 := XDamage.eval_formula(sk72, f, e, vars)
	var v85_45 := XDamage.eval_formula(sk85, f, e, vars)
	var v86_45 := XDamage.eval_formula(sk86, f, e, vars)

	var want85_cap := (float(f.atk) * 55.0 + float(f.mat) * 55.0 * (1.0 + 0.0 + 5.0 * 3.0)) * 1200.0
	var want72_cap := (float(f.atk) * 15.0 + float(f.mat) * 15.0 * (1.0 + 0.0 + 5.0)) * 6000.0
	check("t465.feitian_coef_and_cri_cap_500pct",
		cri_low < 5.0 and cri_15 > 5.0 and cri_45 > 40.0
		and v85_low < v85_15 and v86_low < v86_15
		and is_equal_approx(v72_15, v72_45)
		and is_equal_approx(v85_15, v85_45)
		and is_equal_approx(v86_15, v86_45)
		and absf(v85_45 - want85_cap) < 10.0
		and absf(v72_45 - want72_cap) < 10.0
		and str(sk86.damage.formula).contains("* 3000 *")
		and str(sk85.note).contains("暴击率(上限500%)")
		and str(sk86.note).contains("暴击(上限500%)*2"),
		[cri_low, cri_15, cri_45, v85_low, v85_15, v85_45, want85_cap])


func _check_t465_st2739_and_rollback() -> void:
	var s := _make_xiyou()
	s.add_actor(147)
	var st := XDB.rec("States", 2739)
	check("t465.st2739_mul_1_5",
		is_equal_approx(float(st.effects[0].k), 1.5)
		and str(st.note).contains("value * 1.5"),
		[st.effects[0].k, st.note])

	# XCanglong.original_data() 一并关闭 T463 与 T465
	XCanglong.original_data()
	var sk85_off := XDB.rec("Skills", 10485)
	var w87_off := XDB.rec("Weapons", 87)
	var st_off := XDB.rec("States", 2739)
	check("t465.original_data_rollback",
		not XZhenqi.APPLY_TO_DAMAGE
		and not XXiyouNerf.ENABLED
		and str(sk85_off.damage.formula).contains("* 43300 *")
		and is_equal_approx(float(w87_off.yep.elementAmplify["1"]), 12.0)
		and is_equal_approx(float(st_off.effects[0].k), 2.5),
		[XZhenqi.APPLY_TO_DAMAGE, XXiyouNerf.ENABLED, w87_off.yep.elementAmplify, st_off.effects[0].k])

	XZhenqi.APPLY_TO_DAMAGE = true
	XXiyouNerf.ENABLED = true
	XXiyouNerf.clear_cache()


func _check_t465_tianqi_untouched() -> void:
	var _tq := _make_tianqi()
	var sk55_on := XDB.rec("Skills", 10055)
	var sk85_on := XDB.rec("Skills", 10485)
	var w87_on := XDB.rec("Weapons", 87)
	var st39_on := XDB.rec("States", 2739)
	XXiyouNerf.ENABLED = false
	XXiyouNerf.clear_cache()
	var sk55_off := XDB.rec("Skills", 10055)
	var sk85_off := XDB.rec("Skills", 10485)
	var w87_off := XDB.rec("Weapons", 87)
	var st39_off := XDB.rec("States", 2739)
	XXiyouNerf.ENABLED = true
	XXiyouNerf.clear_cache()
	check("t465.tianqi_zero_change",
		not XXiyouNerf.xiyou_save_on()
		and JSON.stringify(sk55_on) == JSON.stringify(sk55_off)
		and JSON.stringify(sk85_on) == JSON.stringify(sk85_off)
		and JSON.stringify(w87_on) == JSON.stringify(w87_off)
		and JSON.stringify(st39_on) == JSON.stringify(st39_off))
