extends Node
## 【小A·未经审查】T523 天启篇两处修复与西游档零改动回归专项：
## 1) 凛冬刺击（Skill 169，小痔）：天启篇 skill_rework.json 用 effects_remove [[22,23]] + effects_add [{code:21,dataId:23,value1:1,value2:0}]
##    将原版误写的「移除冰冷II」修成「附加冰冷II」，卡面不动；实战验证场景 A（无 23 → 挂上 23 降敏）与场景 B（已有 23 → 不驱散 23）。
## 2) 天虎令气伤链（3550 烽舞／7510～7513 天熄乱舞／7492 气傲天苍／7485、7508、7486、7487 红尘一步／1341 气伤）：
##    天启篇收口未实装链路——XMagicWeapon.TIANQI_SKIP_LEARN_SKILL 停用 3550 Learn Skill（不再出 7510～7513 卡与开战 1337～1340），
##    skill_rework.json 对红尘一步四招 seq 用 drop_if 去掉 1337～1340 挂 1341，7492 同口径标为空壳隐藏；实战三条验证不挂 1341、零 js 诊断。
## 3) 西游档回归：169 原效果码 22 不变；3550 领悟 7510～7513、7492 原卡、红尘一步挂 1341 叠层与受击气伤追加全部不变。

var passed := 0
var total := 0


func _ready() -> void:
	_run.call_deferred()


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func _make_tianqi(lineup: Array, floor_no := 25) -> XState:
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		if not s.party.has(int(id)):
			XTianqi._joining = true
			s.add_actor(int(id))
			XTianqi._joining = false
	s.battle_slots = [0, 0, 0, 0]
	for i in range(mini(4, lineup.size())):
		s.battle_slots[i] = int(lineup[i])
	s.set_variable(20, floor_no)
	s.map_id = 4
	XState.current = s
	return s


func _make_xiyou(actor_ids: Array, floor_no := 25) -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	s.difficulty = 9  # 混沌难度允许超强者（104 天虎令）正常编入西游档出战栏
	s.set_variable(20, floor_no)
	s.party = []
	s.battle_slots = [0, 0, 0, 0]
	for i in range(actor_ids.size()):
		var aid := int(actor_ids[i])
		s.actor(aid)
		s.party.append(aid)
		if i < 4:
			s.battle_slots[i] = aid
	return s


func _equip_armor(a: XActor, armor_id: int, lv := 0) -> Dictionary:
	var item := XGear.template("armor", armor_id)
	if lv > 0:
		item["level"] = float(lv)
	var slots := a.equip_slots()
	var idx := slots.find(int(item.get("etypeId", 0)))
	if idx >= 0:
		if a.equips.size() < slots.size():
			a.equips.resize(slots.size())
		a.equips[idx] = item
	return item


func _equip_weapon(a: XActor, weapon_id: int) -> Dictionary:
	var item := XGear.template("weapon", weapon_id)
	var slots := a.equip_slots()
	var idx := slots.find(1)
	if idx >= 0:
		if a.equips.size() < slots.size():
			a.equips.resize(slots.size())
		a.equips[idx] = item
	return item


func _run() -> void:
	var was_skip := XMagicWeapon.TIANQI_SKIP_LEARN_SKILL
	var was_d200 := XTianqiBase.TUNE_D200
	var was_force := XEnemy.force_roll
	var was_auto := XMessageBox.auto

	XMagicWeapon.TIANQI_SKIP_LEARN_SKILL = true
	XEnemy.force_roll = 100.0
	XMessageBox.auto = true
	seed(20261125)

	_test_tianqi_lindong_169()
	_test_tianqi_qishang_1341()
	_test_tianqi_common_event_learn()
	_test_xiyou_regression()
	_test_xiyou_common_event_learn()

	XMagicWeapon.TIANQI_SKIP_LEARN_SKILL = was_skip
	XTianqiBase.TUNE_D200 = was_d200
	XTianqiSkills.reload_table()
	XEnemy.force_roll = was_force
	XMessageBox.auto = was_auto
	XStateEffects.clear_diagnostics()
	XState.current = null
	print("TEST_RESULT=" + JSON.stringify({"test": "xiyou_t523_lindong_qishang", "passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _test_tianqi_lindong_169() -> void:
	var s := _make_tianqi([5, 1, 2, 3], 15)
	var xz: XActor = s.actor(5)
	xz.change_level(50)
	xz.learn_skill(169)
	xz.learn_skill(315)
	xz.recover_all()

	# 1) 数据改写检查（D200 开与关均生效，卡面保留冰冷描述）
	XTianqiBase.TUNE_D200 = true
	XTianqiSkills.reload_table()
	var sk169 := XDB.rec("Skills", 169)
	var effs: Array = sk169.get("effects", [])
	var has_add_23 := effs.any(func(e): return int(e.get("code", -1)) == 21 and int(e.get("dataId", -1)) == 23 and is_equal_approx(float(e.get("value1", 0.0)), 1.0))
	var has_rem_23 := effs.any(func(e): return int(e.get("code", -1)) == 22 and int(e.get("dataId", -1)) == 23)
	check("tq.s169.effects_add_23_no_remove", has_add_23 and not has_rem_23, effs)
	check("tq.s169.tags_debuff", XTianqiSkills.spec(169).get("tags", []) == ["减益"], XTianqiSkills.spec(169).get("tags"))
	check("tq.s169.card_text_intact", str(sk169.get("note", "")).contains("效果：随机两个敌人；冰冷（敏捷 −10%）"), str(sk169.get("note", "")))

	XTianqiBase.TUNE_D200 = false
	XTianqiSkills.reload_table()
	var sk169_base := XDB.rec("Skills", 169)
	var effs_base: Array = sk169_base.get("effects", [])
	check("tq.s169.d200_off_still_add_23",
		effs_base.any(func(e): return int(e.get("code", -1)) == 21 and int(e.get("dataId", -1)) == 23)
		and not effs_base.any(func(e): return int(e.get("code", -1)) == 22 and int(e.get("dataId", -1)) == 23),
		effs_base)
	XTianqiBase.TUNE_D200 = true
	XTianqiSkills.reload_table()
	sk169 = XDB.rec("Skills", 169)
	var sk315 := XDB.rec("Skills", 315)

	# 2) 天启篇实战：场景 A（敌无 23 → 放 169 命中后挂上 23 冰冷II、敏捷下降）
	var lg := XBattleLogic.new()
	lg.elite_roll = 100.0
	lg.setup(2, s, XBattleRandom.create("0000000000000523"))
	for e in lg.enemies:
		e.add_param(0, 1e9)
		e.param_refresh()
		e.hp = e.mhp
	lg.start_turn()
	for e in lg.enemies:
		e.remove_state(23)
		e.remove_state(22)
		e.remove_state(10941)
		e.param_refresh()
	var base_agi: float = lg.enemies[0].agi
	var logs_a := lg.act(xz, sk169, lg.enemies[0])
	var hits_a := logs_a.filter(func(r): return r is Dictionary and r.get("type") == "hit" and not bool(r.get("missed", false)) and not bool(r.get("evaded", false)))
	var hit_targets_a := []
	var added_23_a := false
	var removed_23_a := false
	for h in hits_a:
		if not hit_targets_a.has(h.get("target")):
			hit_targets_a.append(h.get("target"))
		if (h.get("added", []) as Array).has(23):
			added_23_a = true
		if (h.get("removed", []) as Array).has(23):
			removed_23_a = true
	var all_hit_have_23: bool = not hit_targets_a.is_empty() and hit_targets_a.all(func(t): return (t as XEnemy).is_state_affected(23))
	var agi_dropped_a: bool = not hit_targets_a.is_empty() and hit_targets_a.all(func(t): return (t as XEnemy).agi < base_agi)
	check("tq.s169.scene_a_applies_23", hits_a.size() >= 1 and added_23_a and not removed_23_a and all_hit_have_23 and agi_dropped_a,
		{"hits": hits_a.size(), "added23": added_23_a, "removed23": removed_23_a, "all_have23": all_hit_have_23, "base_agi": base_agi})

	# 3) 天启篇实战：场景 B（先放 315 给敌全体挂 23，再放 169 不再驱散 23）
	xz.recover_all()
	lg.act(xz, sk315, lg.enemies[0])
	for e in lg.enemies:
		if not e.is_state_affected(23):
			e.add_state(23)
		e.remove_state(10941)
		e.param_refresh()
	var agi_with_23: float = lg.enemies[0].agi
	check("tq.s169.scene_b_precondition_23", lg.enemies.all(func(e): return e.is_state_affected(23)) and agi_with_23 < base_agi,
		{"agi_with_23": agi_with_23, "base_agi": base_agi})
	xz.recover_all()
	var logs_b := lg.act(xz, sk169, lg.enemies[0])
	var hits_b := logs_b.filter(func(r): return r is Dictionary and r.get("type") == "hit")
	var removed_23_b := hits_b.any(func(h): return (h.get("removed", []) as Array).has(23))
	var all_keep_23: bool = lg.enemies.all(func(e): return e.is_state_affected(23))
	var agi_not_restored: bool = lg.enemies.all(func(e): return e.agi <= agi_with_23)
	check("tq.s169.scene_b_never_removes_23", hits_b.size() >= 1 and not removed_23_b and all_keep_23 and agi_not_restored,
		{"hits": hits_b.size(), "removed23": removed_23_b, "states": lg.enemies.map(func(e): return e.state_ids)})


func _test_tianqi_qishang_1341() -> void:
	var s := _make_tianqi([104, 1, 2, 3], 25)
	var th: XActor = s.actor(104)
	var ally: XActor = s.actor(1)
	th.change_level(60)
	ally.change_level(60)
	for sid in [7485, 7508, 7486, 7487, 7492, 7494]:
		th.learn_skill(sid)
	th.mastery_levels[7485] = 5
	_equip_weapon(th, 1925)
	var fengwu := _equip_armor(th, 3550, 40)
	th.refresh_passive()
	th.recover_all()
	ally.recover_all()

	# 1) 天启篇 3550 烽舞各档等级（10/20/30/40/99）均不领悟 7510～7513 天熄乱舞
	var mw_any_learned := false
	for lv in [10, 20, 30, 40, 99]:
		fengwu["level"] = float(lv)
		if not XMagicWeapon.item_skills(fengwu).is_empty():
			mw_any_learned = true
	fengwu["level"] = 40.0
	var th_native := th.native_skill_ids()
	var th_skill_ids := th.skills().map(func(rec): return int(rec.get("id", 0)))
	var leaked_mw := [7510, 7511, 7512, 7513].any(func(id): return th_native.has(id) or th_skill_ids.has(id))
	check("tq.1341.no_7510_7513_cards", not mw_any_learned and not leaked_mw, {"mw_any": mw_any_learned, "leaked": leaked_mw})

	# 2) 7492 气傲天苍同口径隐藏（is_shell == true 且卡面不露旧版天熄乱舞／气伤文案）
	var sk7492 := XDB.rec("Skills", 7492)
	check("tq.1341.s7492_shell_hidden", XTianqiSkills.is_shell(7492)
		and not str(sk7492.get("note", "")).contains("天熄乱舞")
		and not str(sk7492.get("note", "")).contains("气伤"),
		{"is_shell": XTianqiSkills.is_shell(7492), "note": str(sk7492.get("note", ""))})

	# 3) 红尘一步四招（7485/7508/7486/7487）seq 已删净 1337～1340 与 Add State 1341，段数保持 5 段
	var seq_clean := true
	for sid in [7485, 7508, 7486, 7487]:
		var rec := XDB.rec("Skills", sid)
		var target_seq: Array = rec.get("yepSeq", {}).get("target", [])
		var seq_json := JSON.stringify(target_seq)
		if seq_json.contains("1341") or seq_json.contains("1337") or seq_json.contains("1338") or seq_json.contains("1339") or seq_json.contains("1340"):
			seq_clean = false
		if XTianqiSkills._seq_effect_count(rec.get("yepSeq", {})) != 5:
			seq_clean = false
	check("tq.1341.hongchen_seq_clean_5_hits", seq_clean)

	# 4) 天启篇实战三条：开战不挂 1337～1340；放 7485（第一招）、再放 7485（第二招）、队友放技能 1（第三招）均不挂 1341、零 js 诊断
	XStateEffects.clear_diagnostics()
	var lg := XBattleLogic.new()
	lg.elite_roll = 100.0
	lg.setup(2, s, XBattleRandom.create("0000000000000523"))
	var foe: XEnemy = lg.enemies[0]
	for e in lg.enemies:
		e.add_param(0, 1e9)
		e.param_refresh()
		e.hp = e.mhp
	lg.start_turn()
	var has_1337_1340 := [1337, 1338, 1339, 1340].any(func(sid): return th.is_state_affected(sid))
	check("tq.1341.battle_start_no_1337_1340", not has_1337_1340, th.state_ids)

	var sk7485 := XDB.rec("Skills", 7485)
	var hp0 := foe.hp
	var logs1 := lg.act(th, sk7485, foe)
	var hits1 := logs1.filter(func(r): return r is Dictionary and r.get("type") == "hit" and r.get("target") == foe)
	var sum1 := 0.0
	for h in hits1:
		sum1 += float(h.get("hp", 0.0))
	var diag1 := XStateEffects.diagnostics.filter(func(d): return int(d.get("state", 0)) == 1341)
	check("tq.1341.cast1_7485_no_1341_5_hits", hits1.size() == 5 and is_equal_approx(hp0 - foe.hp, sum1)
		and not foe.is_state_affected(1341) and diag1.is_empty(),
		{"hits": hits1.size(), "loss": hp0 - foe.hp, "sum": sum1, "states": foe.state_ids, "diag": diag1})

	# 第二招：即便强行给天虎令挂 1340（防旧档／外部残留），红尘一步四招 seq 也绝不挂 1341
	XStateEffects.clear_diagnostics()
	th.add_state(1340)
	var hp1 := foe.hp
	var logs2 := lg.act(th, sk7485, foe)
	var loss2 := hp1 - foe.hp
	var hits2 := logs2.filter(func(r): return r is Dictionary and r.get("type") == "hit" and r.get("target") == foe)
	var sum2 := 0.0
	for h in hits2:
		sum2 += float(h.get("hp", 0.0))
	for sid in [7508, 7486, 7487]:
		th.recover_all()
		lg.act(th, XDB.rec("Skills", sid), foe)
	var any_foe_1341 := lg.enemies.any(func(e): return e.is_state_affected(1341))
	var diag2 := XStateEffects.diagnostics.filter(func(d): return int(d.get("state", 0)) == 1341)
	check("tq.1341.cast2_all4_even_with_1340_no_1341", hits2.size() == 5 and is_equal_approx(loss2, sum2)
		and not any_foe_1341 and diag2.is_empty(),
		{"hits": hits2.size(), "loss": loss2, "sum": sum2, "any1341": any_foe_1341, "diag": diag2})

	# 第三招：队友普攻技能 1 命中敌方，无 1341 诊断与额外扣血
	XStateEffects.clear_diagnostics()
	var hp2 := foe.hp
	var logs3 := lg.act(ally, XDB.rec("Skills", 1), foe)
	var sum3 := 0.0
	for r in logs3:
		if r is Dictionary and r.get("type") == "hit" and r.get("target") == foe:
			sum3 += float(r.get("hp", 0.0))
	var diag3 := XStateEffects.diagnostics.filter(func(d): return int(d.get("state", 0)) == 1341)
	check("tq.1341.cast3_ally_clean", is_equal_approx(hp2 - foe.hp, sum3) and diag3.is_empty(),
		{"loss": hp2 - foe.hp, "sum": sum3, "diag": diag3})

	# 5) 回退开关验证：XMagicWeapon.TIANQI_SKIP_LEARN_SKILL = false 时恢复原 7513 领悟
	XMagicWeapon.TIANQI_SKIP_LEARN_SKILL = false
	check("tq.1341.rollback_switch", XMagicWeapon.item_skills(fengwu) == [7513], XMagicWeapon.item_skills(fengwu))
	XMagicWeapon.TIANQI_SKIP_LEARN_SKILL = true


## 真跑公共事件 1406／1408：同一固定种子反复预约执行，直到领悟抽签覆盖全部分支；记下提示与学会的技能
func _run_learn_ce(s: XState, ce_id: int, seed_hex: String) -> Dictionary:
	var th: XActor = s.actor(104)
	th.change_level(60)
	var lg := XBattleLogic.new()
	lg.elite_roll = 100.0
	lg.setup(2, s, XBattleRandom.create(seed_hex))
	for sid in range(7490, 7503) + [7520]:
		th.forget_skill(sid)
	for sw in range(2241, 2255):
		s.set_switch(sw, false)
	var toasts := []
	var rolls := {}
	var skipped := []
	for i in range(3000):
		lg._check = {}
		XBattleCommonEvent.reserve(lg, ce_id)
		var r := XBattleCommonEvent.take(lg)
		var guard := 0
		while str(r.advance().kind) != "done" and guard < 20:
			guard += 1
		skipped.append_array(r.skipped)
		for x in r.take_logs():
			if x.get("type") == "toast" and str(x.get("text")).contains("领悟技能"):
				toasts.append(str(x.get("text")))
		rolls[int(s.variable(1166))] = true
	var learned := (range(7490, 7503) + [7520]).filter(func(sid): return th.skill_ids.has(sid))
	return {"toasts": toasts, "learned": learned, "rolled_3": rolls.has(3), "switch_2243": s.switch(2243), "skipped": skipped}


func _test_tianqi_common_event_learn() -> void:
	var others: Array = (range(7490, 7503) + [7520]).filter(func(sid): return sid != 7492)
	for ce_id in [1406, 1408]:
		var res := _run_learn_ce(_make_tianqi([104, 1, 2, 3], 25), ce_id, "0000000000000525")
		check("tq.ce%d.no_7492_no_toast" % ce_id, res.rolled_3 and not res.learned.has(7492) and not res.switch_2243
			and not res.toasts.any(func(t): return t.contains("气傲天苍")), res)
		check("tq.ce%d.other_learns_kept" % ce_id, res.learned == others and res.toasts.size() == others.size(), res)
	XBattleCommonEvent.TIANQI_SKIP_SHELL_LEARN = false
	var back := _run_learn_ce(_make_tianqi([104, 1, 2, 3], 25), 1406, "0000000000000525")
	check("tq.ce.rollback_switch", back.learned.has(7492) and back.toasts.any(func(t): return t.contains("气傲天苍")), back)
	XBattleCommonEvent.TIANQI_SKIP_SHELL_LEARN = true


func _test_xiyou_common_event_learn() -> void:
	for ce_id in [1406, 1408]:
		var res := _run_learn_ce(_make_xiyou([104, 5], 25), ce_id, "0000000000000525")
		check("xy.ce%d.learns_7492_with_toast" % ce_id, res.learned.has(7492) and res.switch_2243 and res.learned.size() == 14
			and res.toasts.any(func(t): return t.contains("气傲天苍")), res)
		var rec := XDB.rec("CommonEvents", ce_id)
		check("xy.ce%d.list_untouched" % ce_id, XBattleCommonEvent.command_list(ce_id, rec) == rec.list)


func _test_xiyou_regression() -> void:
	# 西游档零改动回归：169 仍为原版 code=22；3550 领悟 7510～7513；7492 非空壳；红尘一步挂 1341 叠层＋受击气伤照常生效
	var sx := _make_xiyou([104, 5], 25)
	var sk169_x := XDB.rec("Skills", 169)
	var effs_x: Array = sk169_x.get("effects", [])
	check("xy.s169_unchanged_code_22",
		effs_x.size() == 1 and int(effs_x[0].get("code", -1)) == 22 and int(effs_x[0].get("dataId", -1)) == 23,
		effs_x)

	var thx: XActor = sx.actor(104)
	thx.change_level(15)
	for sid in [7485, 7492, 7494]:
		thx.learn_skill(sid)
	thx.mastery_levels[7485] = 2
	_equip_weapon(thx, 1925)
	var fengwu_x := _equip_armor(thx, 3550, 40)
	thx.refresh_passive()
	thx.recover_all()
	thx.tp = 100.0

	var lv_expect := {10: [7510], 20: [7511], 30: [7512], 40: [7513]}
	var lv_ok := true
	for lv in lv_expect:
		fengwu_x["level"] = float(lv)
		if XMagicWeapon.item_skills(fengwu_x) != lv_expect[lv]:
			lv_ok = false
	fengwu_x["level"] = 40.0
	check("xy.fabao_3550_learns_7510_7513", lv_ok and thx.native_skill_ids().has(7513), thx.native_skill_ids())
	check("xy.s7492_not_shell", not XTianqiSkills.is_shell(7492) and str(XDB.rec("Skills", 7492).get("note", "")).contains("天熄乱舞"))

	XStateEffects.clear_diagnostics()
	var lgx := XBattleLogic.new()
	lgx.elite_roll = 100.0
	lgx.setup(2, sx, XBattleRandom.create("0000000000000524"))
	var foex: XEnemy = lgx.enemies[0]
	foex.add_param(0, 1e11)
	foex.param_refresh()
	foex.hp = foex.mhp
	foex.shield = 0.0
	lgx.start_turn()
	check("xy.battle_start_has_1340", thx.is_state_affected(1340), thx.state_ids)

	var sk7485_x := XDB.rec("Skills", 7485)
	lgx.act(thx, sk7485_x, foex)
	var cnt1 := float(foex.state_data.get("_stateCounter", {}).get("1341", 0.0))
	check("xy.cast1_applies_1341_and_counter", foex.is_state_affected(1341) and cnt1 == 1.0,
		{"states": foex.state_ids, "counter": foex.state_data.get("_stateCounter", {})})

	thx.tp = 100.0
	foex.hp = foex.mhp
	foex.shield = 0.0
	var dmm := maxf(0.0, thx.atk * 2.0 + thx.mhp)
	var ddd0 := float(ceil(foex.element_rate(1) * thx.mdr * dmm * 1.25 / 2.0))
	var lv_combat := XMagicWeapon.combat_level(fengwu_x)
	var want_qishang := ddd0 + float(ceil(ddd0 * (float(thx.mastery_levels[7485]) + lv_combat)))
	var hp_before := foex.hp
	var logs_x2 := lgx.act(thx, sk7485_x, foex)
	var hit_cnt_x2 := 0
	var hit_sum_x2 := 0.0
	var qishang_pop_sum := 0.0
	for r in logs_x2:
		if r is Dictionary and r.get("type") == "hit" and r.get("target") == foex:
			hit_cnt_x2 += 1
			hit_sum_x2 += float(r.get("hp", 0.0))
			for p in r.get("started_popups", []):
				if p is Dictionary and bool(p.get("hpAffected", false)) and float(p.get("hpDamage", 0.0)) > 0.0:
					qishang_pop_sum += float(p.get("hpDamage", 0.0))
	var actual_loss_x2 := hp_before - foex.hp
	var diag_x := XStateEffects.diagnostics.filter(func(d): return int(d.get("state", 0)) == 1341)
	check("xy.cast2_1341_react_deals_extra_damage",
		foex.is_alive() and hit_cnt_x2 >= 1 and is_equal_approx(qishang_pop_sum, float(hit_cnt_x2) * want_qishang)
		and actual_loss_x2 >= qishang_pop_sum and diag_x.is_empty(),
		{"alive": foex.is_alive(), "hits": hit_cnt_x2, "actual_loss": actual_loss_x2, "hit_sum": hit_sum_x2, "qishang_pop": qishang_pop_sum, "want": float(hit_cnt_x2) * want_qishang, "diag": diag_x})
