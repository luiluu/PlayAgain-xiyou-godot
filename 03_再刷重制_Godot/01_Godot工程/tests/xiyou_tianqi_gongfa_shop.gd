extends Node
## T443 / T013-1c 专项：功法 50 本重标分门三重（补水风、同门互顶）＋人族首领 EV054 货架重整（含 K8 丁一插槽）。
## 覆盖：
## 1. 全库 50 本原版 stype=6 功法＋19 本新增（水/风两门与大成篇）运行期重标视图、D274① +5%～+15% 整数避 4、去穿透/爆炸项与状态 1656 重标；
## 2. 同门后重顶前重（含满格原地升级不占新格、已有高重拦低重、老存档同门去重）；
## 3. 九秘:行字诀（7140/7141）去再动、开战第 1 回合行动提前、第 2 回合恢复、偷袭不触发；
## 4. 瑞气盈身寻宝决（7169/7170/11319）+3%/+5%/+10% 精确进掉落与金钱统一池；
## 5. 特殊 10 本（D274④）：紫霞神功录下架 EV054 并归紫霞 70 号专属、5 突破＋传承升华重标去终伤/零消耗、炎黄后裔/九阳淬体图封禁禁学禁掉清零；
## 6. EV054 重整货架（无购买丹药、1/13/21 层分级、12 法宝＋7 专武＋仙道模式 5198 去重）、K8 丁一插槽模拟契约、开关回退与西游档零变化。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit


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


func _near(a: float, b: float, eps := 1e-4) -> bool:
	return absf(a - b) <= eps


func _find_actor_by_tier(s: XState, tier: String) -> XActor:
	for aid in XTier.ids(tier):
		var a: XActor = s.actor(int(aid))
		if a != null and XTier.tier_of(a) == tier and not XImportedBalance.is_disabled_actor(int(aid)) and int(aid) != 70:
			return a
	return null


func _fresh_tianqi(floor_n := 28) -> XState:
	var s := Kit.new_game()
	s.set_variable(20, floor_n)
	s.map_id = 4
	XState.current = s
	return s


# ---- 1. 全部 69 本功法重标视图、D274 数值与状态 1656 ----

func _test_gongfa_views_and_stats() -> void:
	var s := _fresh_tianqi(28)
	var a := _find_actor_by_tier(s, XTier.WEAK)  # 6 格
	var d := XTianqiSecrets.data()
	var sk_tbl: Dictionary = d.get("skills", {})
	_check("table_has_69_gongfa", sk_tbl.size() == 69, sk_tbl.size())
	var re_bad := RegEx.create_from_string("(?i)(DepassiveHarmRe|passiveAPLUS|AgainUse|passiveEXTTP|passivePRETP|passiveWPNM|StartPushState|RecPushState0980|ConsumeReduce\\w*:\\s*100)")
	var bad_views := []
	for k in sk_tbl:
		var sid := int(k)
		var sp: Dictionary = sk_tbl[k]
		var iid := int(sp.get("item", 0))
		var sk := XDB.rec("Skills", sid)
		var it := XDB.rec("Items", iid)
		if sk.is_empty() or it.is_empty():
			bad_views.append(["empty", sid, iid])
			continue
		if re_bad.search(str(sk.get("note", ""))) != null:
			bad_views.append(["forbidden_tag", sid, sk.get("note", "")])
		if not (sk.get("traits", []) as Array).is_empty():
			bad_views.append(["traits_not_empty", sid])
		# 价格检查（有价条目与 XItemMarks.sell_rewards 对齐）
		var bp := int(sp.get("buy_price", 0))
		if bp > 0:
			var sr := XItemMarks.sell_rewards(it)
			if int(sr.get("buy_items", {}).get(2530, 0)) != bp:
				bad_views.append(["price_mismatch", iid, bp, sr.get("buy_items", {})])
	_check("all_69_views_clean_and_priced", bad_views.is_empty(), bad_views.slice(0, 5))

	# 抽测元素/物理功法三重（含物理 1、火 2、水 14、风 15）：+5% / +10% / +15%
	var elem_cases := [
		[1, [7145, 7146, 11301]],
		[2, [7147, 7148, 11302]],
		[14, [11310, 11311, 11312]],
		[15, [11313, 11314, 11315]],
	]
	var elem_ok := true
	var elem_detail := []
	for pair in elem_cases:
		var eid := int(pair[0])
		var sids: Array = pair[1]
		var b := _find_actor_by_tier(s, XTier.WEAK)
		var base_own := XDamage.own_bonus(b, eid)
		for idx in range(3):
			var sid := int(sids[idx])
			b.learn_skill(sid)
			b.refresh_passive()
			var got := XDamage.own_bonus(b, eid) - base_own
			var want: float = [0.05, 0.10, 0.15][idx]
			if not _near(got, want):
				elem_ok = false
				elem_detail.append([eid, sid, got, want])
		# 清理
		for sid in sids:
			b.skill_ids.erase(int(sid))
		b.refresh_passive()
	_check("elem_phys_water_wind_5_10_15", elem_ok, elem_detail)

	# 裂魔碎空劲三重：终伤 +5% / +8% / +12%
	var c := _find_actor_by_tier(s, XTier.WEAK)
	var base_harm := float(c.passive_cache().get("globalHarmRi", 0.0))
	var liemo_vals := []
	for sid in [7166, 7167, 7168]:
		c.learn_skill(sid)
		c.refresh_passive()
		liemo_vals.append(roundi((float(c.passive_cache().get("globalHarmRi", 0.0)) - base_harm) * 100.0))
	_check("liemo_5_8_12", liemo_vals == [5, 8, 12], liemo_vals)
	c.skill_ids.erase(7168)
	c.refresh_passive()

	# 玄天功：暴击率 +5% / +10% / +15%（去运气、去全伤）
	var base_cri := c.cri
	var base_luk := c.luk
	var xt_vals := []
	for sid in [7136, 7137, 7138]:
		c.learn_skill(sid)
		c.param_mark_dirty()
		c.refresh_passive()
		xt_vals.append(roundi((c.cri - base_cri) * 100.0))
	_check("xuantian_cri_5_10_15_no_luk", xt_vals == [5, 10, 15] and _near(c.luk, base_luk), [xt_vals, c.luk, base_luk])
	c.skill_ids.erase(7138)
	c.param_mark_dirty()
	c.refresh_passive()

	# 易筋洗髓经：消耗 -10% / -20% / -30%（去 -100%）
	var red_vals := []
	for sid in [7142, 7143, 11318]:
		c.learn_skill(sid)
		c.refresh_passive()
		red_vals.append(int(c.passive_cache().get("consumeReduce", {}).get("all", 0)))
	_check("yijin_xisui_reduce_10_20_30", red_vals == [10, 20, 30], red_vals)
	c.skill_ids.erase(11318)
	c.refresh_passive()

	# 易筋经妙法：最大生命 +10% / +15% / +20%（去 TP+150、去 RecPushState0980、去治疗+500%）
	var base_mhp := float(c.mhp)
	var base_tp := float(c.max_tp())
	var yjm_ok := true
	var yjm_detail := []
	for pair in [[7171, 1.10], [7172, 1.15], [7173, 1.20]]:
		c.learn_skill(int(pair[0]))
		c.param_mark_dirty()
		c.refresh_passive()
		var ratio := float(c.mhp) / base_mhp
		if absf(ratio - float(pair[1])) > 0.02 or not _near(float(c.max_tp()), base_tp):
			yjm_ok = false
			yjm_detail.append([pair[0], ratio, pair[1], c.max_tp(), base_tp])
	_check("yijin_miaofa_mhp_10_15_20_no_tp", yjm_ok, yjm_detail)
	c.skill_ids.erase(7173)
	c.param_mark_dirty()
	c.refresh_passive()

	# 九阳/九阴：五系 +3%/+5%/+8%＋生命/魔法 +5%/+8%/+10%，去双攻 +125%
	var base_atk := float(c.atk)
	var base_own2 := XDamage.own_bonus(c, 2)
	c.learn_skill(11316)  # 九阳大成
	c.param_mark_dirty()
	c.refresh_passive()
	_check("jiuyang_t3_elem8_hp10_no_atk", _near(XDamage.own_bonus(c, 2) - base_own2, 0.08) and absf(float(c.mhp) / base_mhp - 1.10) < 0.02 and _near(float(c.atk), base_atk),
		[XDamage.own_bonus(c, 2) - base_own2, float(c.mhp) / base_mhp, c.atk, base_atk])
	c.skill_ids.erase(11316)
	c.param_mark_dirty()
	c.refresh_passive()

	# 神照经妙法（7180）＋状态 1656 重标视图
	var st1656 := XDB.rec("States", 1656)
	var st_traits: Array = st1656.get("traits", [])
	var st_ok := st_traits.size() == 8 and st_traits.all(func(t): return int(t.get("code", 0)) == 21 and _near(float(t.get("value", 0.0)), 1.05)) \
		and str(st1656.get("note", "")).contains("<passiveHarmRi:8>") \
		and not str(st1656.get("note", "")).contains("passiveCrHarmRi") \
		and not str(st1656.get("note", "")).contains("DepassiveHarmRe")
	_check("shenzhao_state_1656_reworked", st_ok, st1656.get("note", ""))
	c.learn_skill(7180)
	c.param_mark_dirty()
	c.refresh_passive()
	_check("shenzhao_7180_heal10_no_tp200", _near(XDamage.own_bonus(c, 10), 0.10) and _near(float(c.max_tp()), base_tp),
		[XDamage.own_bonus(c, 10), c.max_tp(), base_tp])
	c.skill_ids.erase(7180)
	c.param_mark_dirty()
	c.refresh_passive()

	# 孤独九剑式（7181）：可装备剑＋用剑伤 +10%
	c.learn_skill(7181)
	c.refresh_passive()
	var sk7181 := XDB.rec("Skills", 7181)
	_check("gudu_7181_sword_and_10pct", str(sk7181.get("note", "")).contains("<passiveEWPN02>") and _near(float(c.passive_cache().get("SkETypeHarmRi", {}).get(2, 0.0)), 0.10),
		c.passive_cache().get("SkETypeHarmRi", {}))
	c.skill_ids.erase(7181)
	c.refresh_passive()


# ---- 2. 同门互顶（满格原地升级、已有高重拦低重、老档去重）----

func _test_same_school_override() -> void:
	var s := _fresh_tianqi(28)
	var sup := _find_actor_by_tier(s, XTier.SUPER)  # 3 格
	# 装满 3 格：火入门 7147、水入门 11310、风入门 11313
	sup.learn_skill(7147)
	sup.learn_skill(11310)
	sup.learn_skill(11313)
	_check("school_full_3_of_3", XTianqiSecrets.used_slots(sup, s) == 3)
	# 满格下直接学火小成 7148 → 放行、顶掉 7147、仍 3/3 格
	_check("school_full_upgrade_allowed", XTianqiSecrets.can_learn(sup, 7148, s))
	sup.learn_skill(7148)
	_check("school_upgrade_replaced_t1", sup.skill_ids.has(7148) and not sup.skill_ids.has(7147) and XTianqiSecrets.used_slots(sup, s) == 3, sup.skill_ids)
	# 继续满格升火大成 11302 → 顶掉 7148、仍 3/3 格
	sup.learn_skill(11302)
	_check("school_upgrade_replaced_t2", sup.skill_ids.has(11302) and not sup.skill_ids.has(7148) and XTianqiSecrets.used_slots(sup, s) == 3, sup.skill_ids)
	# 已学大成 11302 时再学入门 7147 或小成 7148 被拦
	var r_low := XTianqiSecrets.learn_reason(sup, 7147, s)
	_check("school_downgrade_blocked", r_low.contains("更高"), r_low)
	sup.learn_skill(7147)
	_check("school_downgrade_not_added", not sup.skill_ids.has(7147) and sup.skill_ids.has(11302))
	# 老存档同时有同门 3 本（直接灌 skill_ids 模拟老档）：migrate_after_load 合并只留最高重
	var a2 := _find_actor_by_tier(s, XTier.STRONG)
	a2.skill_ids.append(7166)
	a2.skill_ids.append(7167)
	a2.skill_ids.append(7168)
	a2.skill_ids.append(7136)
	a2.skill_ids.append(7139)
	XTianqiSecrets.migrate_after_load(s)
	_check("legacy_school_dedup", a2.skill_ids.has(7168) and not a2.skill_ids.has(7166) and not a2.skill_ids.has(7167)
		and a2.skill_ids.has(7139) and not a2.skill_ids.has(7136), a2.skill_ids)


# ---- 3. 九秘:行字诀首回合提前、第 2 回合恢复、无再动 ----

func _test_xingzi_first_turn() -> void:
	var s := _fresh_tianqi(28)
	var ids: Array[int] = []
	for aid in XTier.ids(XTier.WEAK):
		var a: XActor = s.actor(int(aid))
		if a != null and not XImportedBalance.is_disabled_actor(int(aid)) and int(aid) != 70:
			ids.append(int(aid))
			if ids.size() >= 4:
				break
	s.party = ids
	s.battle_slots = ids.duplicate()
	# 压低 0 号位敏捷，拉高队友与敌方，保证不带行字诀时 0 号位首回合稳排最后
	var slow := s.actor(ids[0])
	slow.change_level(1)
	for i in range(1, ids.size()):
		s.actor(ids[i]).change_level(80)

	var run_order := func(skill_id: int, surprise_flag := false) -> Dictionary:
		for sid in [7140, 7141]:
			slow.skill_ids.erase(sid)
		if skill_id > 0:
			slow.learn_skill(skill_id)
		slow.refresh_passive()
		seed(20261124)
		var lg := XBattleLogic.new()
		lg.setup(4, s)
		lg.surprise = surprise_flag
		lg.preemptive = false
		lg._orders_made = false
		lg._make_action_orders()
		var idx1 := lg.current_order.find(slow)
		var times1 := lg.make_action_times(slow)
		# 第 2 回合（_orders_made == true）
		lg._make_action_orders()
		var idx2 := lg.current_order.find(slow)
		return {"t1": idx1, "t2": idx2, "len": lg.current_order.size(), "times": times1}

	var base_r: Dictionary = run_order.call(0)
	var r7140: Dictionary = run_order.call(7140)
	var r7141: Dictionary = run_order.call(7141)
	var r_surp: Dictionary = run_order.call(7141, true)
	_check("xingzi_no_extra_action", int(r7140.times) == 1 and int(r7141.times) == 1, [r7140.times, r7141.times])
	_check("xingzi_7140_t1_advance_t2_restore", int(r7140.t1) <= int(base_r.t1) - 2 and int(r7140.t2) >= int(base_r.t2) - 1, [base_r, r7140])
	_check("xingzi_7141_t1_first_t2_restore", int(r7141.t1) == 0 and int(r7141.t2) > 0, [base_r, r7141])
	_check("xingzi_surprise_no_trigger", int(r_surp.t1) == -1, r_surp)


# ---- 4. 瑞气盈身寻宝决三重 +3 / +5 / +10 精确进掉落与金钱统一池 ----

func _test_xunbao_drop_and_money() -> void:
	var s := _fresh_tianqi(28)
	var a := _find_actor_by_tier(s, XTier.WEAK)
	s.party = [a.actor_id]
	s.battle_slots = [a.actor_id]
	var base_drop := XTianqiDrop.party_bonus(s, [a])
	var base_gold := XTianqiMoney.income_bonus([a], s)
	var drops := []
	var golds := []
	for sid in [7169, 7170, 11319]:
		a.learn_skill(sid)
		a.refresh_passive()
		drops.append(roundi(XTianqiDrop.party_bonus(s, [a]) - base_drop))
		golds.append(roundi(XTianqiMoney.income_bonus([a], s) - base_gold))
	_check("xunbao_drop_pool_3_5_10", drops == [3, 5, 10], drops)
	_check("xunbao_gold_pool_3_5_10", golds == [3, 5, 10], golds)


# ---- 5. 特殊 10 本（D274④）：紫霞、5 突破＋传承升华、炎黄/九阳图封禁 ----

func _test_special_ten_books() -> void:
	var s := _fresh_tianqi(28)
	var other := _find_actor_by_tier(s, XTier.WEAK)
	var zixia := s.actor(70)
	# 紫霞神功录：非紫霞被拦，紫霞可学且下篇顶上篇、仅加 6 招 +8%/+15%、无暴击/终伤/物火
	var r_other := XTianqiSecrets.learn_reason(other, 7178, s)
	_check("zixia_blocked_for_other", r_other.contains("仅") and XTianqiSecrets.blocks_learn(other, 7179, s), r_other)
	var z_base_cri := zixia.cri
	zixia.learn_skill(7178)
	zixia.refresh_passive()
	var r8 := float(zixia.passive_cache().get("skillPass", {}).get(2395, {}).get("rate", 0.0))
	zixia.learn_skill(7179)
	zixia.refresh_passive()
	var r15 := float(zixia.passive_cache().get("skillPass", {}).get(2395, {}).get("rate", 0.0))
	var z_harm := float(zixia.passive_cache().get("globalHarmRi", 0.0))
	_check("zixia_7178_7179_8_to_15_clean",
		_near(r8, 0.08) and _near(r15, 0.15) and not zixia.skill_ids.has(7178) and _near(z_harm, 0.0) and _near(zixia.cri, z_base_cri),
		[r8, r15, z_harm, zixia.cri, z_base_cri])

	# 5 本突破（7182~7186）＋传承升华（7187）：无终伤、无零消耗、精准 SkillPass +12% / +15%
	var inh_ok := true
	var inh_detail := []
	for pair in [[7182, 2826, 0.12], [7183, 6217, 0.12], [7184, 6221, 0.12], [7185, 6225, 0.12], [7186, 6229, 0.12], [7187, 6231, 0.15]]:
		var sid := int(pair[0])
		var tgt := int(pair[1])
		var want := float(pair[2])
		other.learn_skill(sid)
		other.refresh_passive()
		var rate := float(other.passive_cache().get("skillPass", {}).get(tgt, {}).get("rate", 0.0))
		var h := float(other.passive_cache().get("globalHarmRi", 0.0))
		var red: Dictionary = other.passive_cache().get("consumeReduce", {})
		var bt: Dictionary = red.get("byType", {})
		if not _near(rate, want) or not _near(h, 0.0) or int(red.get("all", 0)) != 0 or int(bt.get("Mf", 0)) != 0 or int(bt.get("Zj", 0)) != 0:
			inh_ok = false
			inh_detail.append([sid, rate, want, h, red])
		other.skill_ids.erase(sid)
		other.refresh_passive()
	_check("five_breakthroughs_and_ascend_clean", inh_ok, inh_detail)

	# 炎黄后裔（2237/7135）与九阳淬体图（2240/7144）：禁学、禁掉、老档清零
	_check("banned_7135_7144_blocked",
		XTianqiSecrets.blocks_learn(other, 7135, s) and XTianqiSecrets.blocks_learn(other, 7144, s)
		and XTianqiSecrets.item_learn_reason(other, XDB.rec("Items", 2237), s).contains("封禁")
		and XTianqiSecrets.item_learn_reason(other, XDB.rec("Items", 2240), s).contains("封禁"))
	var fake_drops := [{"kind": 1, "id": 2237, "chance": 1.0}, {"kind": 1, "id": 2240, "chance": 1.0}, {"kind": 1, "id": 2530, "chance": 1.0}]
	var filtered := XTianqiSecrets.filter_drop_rows(s, fake_drops)
	_check("banned_drops_filtered", filtered.size() == 1 and int(filtered[0].id) == 2530, filtered)
	# 老档已学 7135/7144：清零增伤与暴击
	var base_c := other.cri
	var base_e2 := XDamage.own_bonus(other, 2)
	other.skill_ids.append(7135)
	other.skill_ids.append(7144)
	other.param_mark_dirty()
	other.refresh_passive()
	_check("banned_legacy_zero_power", _near(other.cri, base_c) and _near(XDamage.own_bonus(other, 2), base_e2) and _near(float(other.passive_cache().get("globalHarmRi", 0.0)), 0.0),
		[other.cri, base_c, XDamage.own_bonus(other, 2), base_e2])


# ---- 6. EV054 货架重整＋K8 丁一插槽模拟契约＋开关回退＋西游档零变化 ----

func _test_ev54_shop_and_dingyi_slot() -> void:
	var s := _fresh_tianqi(1)
	_check("ev54_intercepts_on", XTianqiSecrets.ev54_intercepts(s, 4, 54))
	var menu1 := XTianqiSecrets.ev54_menu(s)
	var labels1 := menu1.map(func(x): return str(x[0]))
	_check("ev54_no_pills_option", not labels1.any(func(lb): return lb.contains("丹药")), labels1)
	# 1 层：入门功法开（含水 3210、风 3213），小成/大成/法宝/神武未解锁
	var t1 := XTianqiSecrets.ev54_tab_goods(s, "gongfa_t1")
	_check("ev54_f1_has_water_wind_t1",
		t1.any(func(g): return int(g[0]) == 0 and int(g[1]) == 3210)
		and t1.any(func(g): return int(g[0]) == 0 and int(g[1]) == 3213)
		and XTianqiSecrets.ev54_tab_goods(s, "gongfa_t2").is_empty()
		and XTianqiSecrets.ev54_tab_goods(s, "fabao").is_empty(), t1.size())

	# 13 层：小成开，法宝页含全部 12 把系别法宝（含 8101/8102），尚未含 21 层专武
	s.set_variable(20, 13)
	var fab13 := XTianqiSecrets.ev54_tab_goods(s, "fabao")
	var fab13_ids := fab13.filter(func(g): return int(g[0]) == 2).map(func(g): return int(g[1]))
	_check("ev54_f13_12_fabaos_no_weapons", fab13_ids.size() == 12 and fab13_ids.has(8101) and fab13_ids.has(8102) and fab13.size() == 12, fab13_ids)

	# 21 层：大成开，法宝专武含 12 法宝＋7 专武，神武页去重只留 5198，无 4553/4540/1981/2328/2329/2237/2240/丹药
	s.set_variable(20, 21)
	var fab21 := XTianqiSecrets.ev54_tab_goods(s, "fabao")
	var div21 := XTianqiSecrets.ev54_tab_goods(s, "divine")
	var t3_21 := XTianqiSecrets.ev54_tab_goods(s, "gongfa_t3")
	var all21 := t1 + XTianqiSecrets.ev54_tab_goods(s, "gongfa_t2") + t3_21 + fab21 + div21
	var forbidden := [[2, 4553], [2, 4540], [0, 1981], [0, 2328], [0, 2329], [0, 2237], [0, 2240], [2, 4279]]
	var has_bad := all21.any(func(g):
		var k := int(g[0])
		var id := int(g[1])
		if k == 0 and id >= 1685 and id <= 1717:
			return true
		return forbidden.any(func(f): return int(f[0]) == k and int(f[1]) == id))
	_check("ev54_f21_complete_and_clean",
		fab21.size() == 19 and div21.size() == 1 and int(div21[0][1]) == 5198
		and t3_21.any(func(g): return int(g[1]) == 3212) and t3_21.any(func(g): return int(g[1]) == 3215)
		and not has_bad, [fab21.size(), div21, has_bad])

	# 模拟 K8 丁一插槽（按楼层 10/15/20/22/25/27 追加深渊六式被动＋校验仍过 XTianqiSect.shop_goods 过滤 1960）
	XTianqiSect._ev54_extra_test_hook = func(_st, tab: String, top_floor: int) -> Array:
		if tab != "abyss":
			return []
		var out := []
		if top_floor >= 10:
			out.append([0, 2463, 0, 0])
			out.append([0, 2488, 0, 0])
			out.append([0, 1960, 0, 0])  # 故意混入已下架研究日志 1960，验证必经 XTianqiSect.shop_goods 过滤
		if top_floor >= 27:
			out.append([0, 2473, 0, 0])
			out.append([0, 2493, 0, 0])
		return out
	s.set_variable(20, 10)
	var ab10 := XTianqiSecrets.ev54_tab_goods(s, "abyss")
	var menu10 := XTianqiSecrets.ev54_menu(s).map(func(x): return str(x[0]))
	s.set_variable(20, 27)
	var ab27 := XTianqiSecrets.ev54_tab_goods(s, "abyss")
	XTianqiSect._ev54_extra_test_hook = Callable()
	_check("dingyi_slot_f10_f27_and_sect_filter",
		ab10.size() == 2 and ab10.any(func(g): return int(g[1]) == 2463)
		and not ab10.any(func(g): return int(g[1]) == 1960)
		and menu10.has("深渊秘传")
		and ab27.size() == 4 and ab27.any(func(g): return int(g[1]) == 2493),
		[ab10, menu10, ab27])

	# 回退开关：GONGFA_REWORK = false / EV54_SHOP = false
	XTianqiSecrets.GONGFA_REWORK = false
	XTianqiSecrets.EV54_SHOP = false
	var raw7145 := XDB.rec("Skills", 7145)
	var new_off := XDB.rec("Skills", 11310)
	var st_off := XDB.rec("States", 1656)
	_check("rollback_switches_restore_original",
		str(raw7145.get("note", "")).contains("<passiveELUP01:120%>")
		and new_off.is_empty()
		and str(st_off.get("note", "")).contains("<passiveCrHarmRi:150>")
		and not XTianqiSecrets.ev54_intercepts(s, 4, 54),
		[raw7145.get("name", ""), new_off.is_empty()])
	XTianqiSecrets.GONGFA_REWORK = true
	XTianqiSecrets.EV54_SHOP = true

	# 西游档零变化（含买价缓存不串台）
	var x := XState.new()
	x.map_id = 4
	XState.current = x
	var x_sk := XDB.rec("Skills", 7145)
	var x_it := XDB.rec("Items", 2241)
	var x_sr := XItemMarks.sell_rewards(x_it)
	var x_new := XDB.rec("Items", 3210)
	_check("xiyou_save_zero_change",
		str(x_sk.get("note", "")).contains("<passiveELUP01:120%>")
		and int(x_sr.get("buy_items", {}).get(2530, 0)) == 13
		and x_new.is_empty()
		and not XTianqiSecrets.ev54_intercepts(x, 4, 54),
		[x_sr.get("buy_items", {}), x_new.is_empty()])


func _frames(n := 4) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _run_yield_probe() -> void:
	var presets := {
		"超强者_95": {"aid": 95, "skill": 10731, "t1": [7145, 7166, 7174], "t2": [7146, 7167, 7175], "t3": [11301, 7168, 11316]},
		"强者_1":   {"aid": 1,  "skill": 4749,  "t1": [7145, 7166, 7174, 7136], "t2": [7146, 7167, 7175, 7137], "t3": [11301, 7168, 11316, 7138]},
		"弱者_12":  {"aid": 12, "skill": 318,   "t1": [7145, 7166, 7174, 7136, 7171, 7181], "t2": [7146, 7167, 7175, 7137, 7172, 7181], "t3": [11301, 7168, 11316, 7138, 7173, 7181]},
	}
	for sd in [101, 202, 303]:
		seed(sd)
		var s := _fresh_tianqi(28)
		for aid in [95, 1, 12]:
			if s.actors.get(aid) == null:
				XTianqi._joining = true
				s.add_actor(aid)
				XTianqi._joining = false
		var e := XEnemy.new().setup(4, 3, 100.0)
		for label in presets:
			var cfg: Dictionary = presets[label]
			var a: XActor = s.actor(int(cfg.aid))
			a.change_level(81)
			var sk := XDB.rec("Skills", int(cfg.skill))
			var base_skills := a.skill_ids.duplicate()
			var res := {}
			for stage in ["base", "t1", "t2", "t3"]:
				a.skill_ids = base_skills.duplicate()
				if stage != "base":
					for sid in cfg[stage]:
						a.learn_skill(int(sid))
				a.param_mark_dirty()
				a.refresh_passive()
				seed(sd * 100 + int(cfg.aid))
				var sum_v := 0.0
				var max_v := 0.0
				for _h in range(5):
					var r := XDamage.calculate(sk, a, e, {"critical": true, "variance": true})
					var v := float(r.value)
					sum_v += v
					max_v = maxf(max_v, v)
				res[stage] = {"max": roundi(max_v), "avg": roundi(sum_v / 5.0), "used": XTianqiSecrets.used_slots(a, s), "mhp": roundi(a.mhp), "cri_pct": roundi(a.cri * 100.0)}
			var bmax := maxf(1.0, float(res.base.max))
			print("YIELD_ROW ", JSON.stringify({
				"seed": sd, "role": label, "cap": XTianqiSecrets.limit(a),
				"base": res.base.max,
				"t1": res.t1.max, "t1_pct": snappedf((float(res.t1.max) / bmax - 1.0) * 100.0, 0.1),
				"t2": res.t2.max, "t2_pct": snappedf((float(res.t2.max) / bmax - 1.0) * 100.0, 0.1),
				"t3": res.t3.max, "t3_pct": snappedf((float(res.t3.max) / bmax - 1.0) * 100.0, 0.1),
				"t3_used": res.t3.used, "t3_mhp_pct": snappedf((float(res.t3.mhp) / maxf(1.0, float(res.base.mhp)) - 1.0) * 100.0, 0.1),
				"t3_cri_diff": int(res.t3.cri_pct) - int(res.base.cri_pct),
			}))


func _take_shots(out_dir: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().size = Vector2i(1280, 720)
	var s := _fresh_tianqi(28)
	s.gain_item(2530, 999)
	s.gold = 999999
	var old_skin := XUiSkin.ENABLED
	XUiSkin.ENABLED = true
	for pair in [["gongfa_t3", "luiluu_t443_ev54_gongfa_t3.png", 9], ["fabao", "luiluu_t443_ev54_fabao.png", 10]]:
		var tab := str(pair[0])
		var fn := str(pair[1])
		var sel := int(pair[2])
		var goods := XTianqiSecrets.ev54_tab_goods(s, tab)
		XShopStock.set_context(4, 54)
		var shop := XShop.new()
		shop.setup(goods, true, "")
		add_child(shop)
		await _frames(6)
		if "_buy_idx" in shop:
			shop._buy_idx = mini(sel, maxi(0, goods.size() - 1))
			if shop.has_method("_refresh"):
				shop._refresh()
		await _frames(6)
		var img := get_viewport().get_texture().get_image()
		if img != null:
			var err := img.save_png(out_dir.path_join(fn))
			print("SHOT ", fn, " err=", err, " size=", img.get_size())
		shop.queue_free()
		XShopStock.shop_context = {}
		await _frames(3)
	XUiSkin.ENABLED = old_skin


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_gongfa_shop")
	seed(20261124)
	XTianqiSecrets.reload_table()
	var args := OS.get_cmdline_user_args()
	if args.has("--yield-probe"):
		_run_yield_probe()
	for a in args:
		if a.begins_with("--shots="):
			await _take_shots(a.substr(8))
	_test_gongfa_views_and_stats()
	_test_same_school_override()
	_test_xingzi_first_turn()
	_test_xunbao_drop_and_money()
	_test_special_ten_books()
	_test_ev54_shop_and_dingyi_slot()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=", JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
