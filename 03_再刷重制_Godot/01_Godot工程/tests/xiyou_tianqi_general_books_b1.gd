extends Node
## T444（T013-1d）通用书第一批专项：
## 1. 教派包丁二全收：止戈 6185、天怒 6204、深渊六式 24 原技能并 18 口径（6186~6203/6206~6211）、五条传承 21 技能（2826~2830/6217~6234）、三本极尽升华被动（6236/6237/6239）与配套状态；
## 2. EV054 内 4 本主动书（7188/7163/7164/7165）与轮回之力状态 1655；
## 3. 全量 147 本（含 6501 共 148）抽奖与秘境被动全覆盖、零违规标签、T446 P3-1（6325~6328/6530 去乘法状态）、CodexParamRate 缓存隔离、掉率直读；
## 4. 实机战斗施放与总账守卫 0 违规；
## 5. ENABLED = false 完整回退与西游档零变化。

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


func _tq_state(diff := "zhengdao") -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s := XTianqi.start_new_game(3, diff, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _xiyou_state() -> XState:
	var s := XState.new()
	s.add_actor(1)
	XState.current = s
	return s


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_general_books_b1")
	seed(20261124)
	XTianqiGeneralBooks.ENABLED = true
	XTianqiGeneralBooks.reload_table()
	var s := _tq_state("zhengdao")
	_test_sect_ding2(s)
	_test_ev054_actives(s)
	_test_lottery_all(s)
	_test_battle_and_ledger(s)
	_test_rollback_and_xiyou()
	XTianqiGeneralBooks.ENABLED = true
	XTianqiGeneralBooks.reload_table()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _test_sect_ding2(s: XState) -> void:
	# 1. 止戈 6185 & 天怒 6204
	var st1004 := XDB.rec("States", 1004)
	var note1004 := str(st1004.get("note", ""))
	var atk_rate_1004 := 1.0
	var mat_rate_1004 := 1.0
	for t in st1004.get("traits", []):
		if int(t.get("code", 0)) == 21 and int(t.get("dataId", -1)) == 2:
			atk_rate_1004 = float(t.get("value", 1.0))
		if int(t.get("code", 0)) == 21 and int(t.get("dataId", -1)) == 4:
			mat_rate_1004 = float(t.get("value", 1.0))
	_check("ding2_zhige_pct", not note1004.contains("G_ShuXing") and is_equal_approx(atk_rate_1004, 0.9) and is_equal_approx(mat_rate_1004, 0.9), [atk_rate_1004, mat_rate_1004])

	var st1007 := XDB.rec("States", 1007)
	var atk_rate_1007 := 1.0
	for t in st1007.get("traits", []):
		if int(t.get("code", 0)) == 21 and int(t.get("dataId", -1)) == 2:
			atk_rate_1007 = float(t.get("value", 1.0))
	_check("ding2_tiannu_pct", is_equal_approx(atk_rate_1007, 1.08), atk_rate_1007)

	# 2. 深渊六式 6 主动：全切模块公式、去旧双号 if 块、1006 附骨之疽去 origin.mat*100
	var abyss_ok := true
	var bad_abyss := []
	for pair in [[6186, "6193", 50], [6187, "6195", 0], [6188, "6197", 0], [6189, "6199", 0], [6190, "6201", 50], [6191, "6203", 0]]:
		var r := XDB.rec("Skills", int(pair[0]))
		var mod := str(r.get("damage", {}).get("formulaProgram", {}).get("module", ""))
		var seq_txt := JSON.stringify(r.get("yepSeq", {}))
		var ok := mod == XTianqiGeneralBooks.MODULE and int(r.get("tpCost", -1)) == int(pair[2]) and not seq_txt.contains(str(pair[1]))
		if not ok:
			abyss_ok = false
			bad_abyss.append([pair[0], mod, r.get("tpCost", -1), seq_txt.contains(str(pair[1]))])
	_check("ding2_abyss_actives", abyss_ok, bad_abyss)

	var st1006 := XDB.rec("States", 1006)
	_check("ding2_abyss_1006_no_mat100", not st1006.has("effects") and (st1006.get("traits", []) as Array).any(func(t): return int(t.code) == 22 and int(t.dataId) == 7 and is_equal_approx(float(t.value), -0.05)), st1006.get("traits", []))

	# 3. 深渊六式强化被动（单双号 6192~6203）均压至 +10% 元素 / +15% 招式伤
	var reinf_ok := true
	for sid in range(6192, 6204):
		var n := str(XDB.rec("Skills", sid).get("note", ""))
		if n.contains("300%") or n.contains("350%") or n.contains("100%") or not n.contains(":10%>") or not n.contains(":15%>"):
			reinf_ok = false
	_check("ding2_abyss_reinforce_capped", reinf_ok)

	# 4. 黯灭幻影无再动、重岩壁垒无固定减伤
	var sk6210 := XDB.rec("Skills", 6210)
	var st1013 := XDB.rec("States", 1013)
	var has_61 := (st1013.get("traits", []) as Array).any(func(t): return int(t.get("code", 0)) == 61)
	var a := s.actor(s.party[0])
	a.add_state(1013)
	var aplus_with_1013 := a.action_plus_set()
	a.remove_state(1013)
	_check("ding2_anmie_no_action_plus", not str(sk6210.get("note", "")).contains("AgainUse") and not has_61 and not aplus_with_1013.has(0.35), [has_61, aplus_with_1013])

	var st1012 := XDB.rec("States", 1012)
	var pdr_1012 := 1.0
	for t in st1012.get("traits", []):
		if int(t.get("code", 0)) == 23 and int(t.get("dataId", -1)) == 6:
			pdr_1012 = float(t.get("value", 1.0))
	_check("ding2_zhongyan_no_flat_re", not str(st1012.get("note", "")).contains("passiveHarmRe") and is_equal_approx(pdr_1012, 0.9), pdr_1012)

	# 5. 五条传承 21 技能：剑魔/天魔星不叠成 100% 减耗、瞬影四阶递增且吃 TP、神龙炎弹四阶递增
	var sk2828 := XDB.rec("Skills", 2828)
	var sk2829 := XDB.rec("Skills", 2829)
	_check("ding2_inherit_consume_cap", str(sk2828.get("note", "")).contains("ConsumeReduceZj: 10%") and str(sk2829.get("note", "")).contains("ConsumeReduceZj: 15%"))

	var logic0 := XBattleLogic.new()
	logic0.setup(4, s)
	var e: XEnemy = logic0.enemies[0]
	a.level = 99
	a.tp = 0.0
	var sy1_0 := XTianqiGeneralBooks.formula(a, e, XDB.rec("Skills", 6221))
	a.tp = 100.0
	var sy1_100 := XTianqiGeneralBooks.formula(a, e, XDB.rec("Skills", 6221))
	_check("ding2_shunying_tp_bonus", sy1_0 > 0.0 and is_equal_approx(sy1_100 / sy1_0, 1.2), [sy1_0, sy1_100])

	var sl1 := XTianqiGeneralBooks.formula(a, e, XDB.rec("Skills", 6225))
	var sl2 := XTianqiGeneralBooks.formula(a, e, XDB.rec("Skills", 6226))
	var sl3 := XTianqiGeneralBooks.formula(a, e, XDB.rec("Skills", 6227))
	var sl4 := XTianqiGeneralBooks.formula(a, e, XDB.rec("Skills", 6228))
	_check("ding2_shenlong_monotonic", sl1 > 0.0 and sl2 > sl1 and sl3 > sl2 and sl4 > sl3, [sl1, sl2, sl3, sl4])

	# 6. 三本极尽升华被动爆伤压至 +15%
	var asc_ok := true
	for sid in [6236, 6237, 6239]:
		var n := str(XDB.rec("Skills", sid).get("note", ""))
		if not n.contains("<passiveCrHarmRi:15>") or n.contains("<passiveCrHarmRi:30>"):
			asc_ok = false
	_check("ding2_ascension_crit_15", asc_ok)


func _test_ev054_actives(s: XState) -> void:
	var a := s.actor(s.party[0])
	var sk7163 := XDB.rec("Skills", 7163)
	var sk7164 := XDB.rec("Skills", 7164)
	var sk7165 := XDB.rec("Skills", 7165)
	var sk7188 := XDB.rec("Skills", 7188)
	var h1 := XTianqiGeneralBooks.formula(a, a, sk7163)
	var h2 := XTianqiGeneralBooks.formula(a, a, sk7164)
	var h3 := XTianqiGeneralBooks.formula(a, a, sk7165)
	var no_dup_hp := not (sk7163.get("effects", []) as Array).any(func(ef): return int(ef.code) == 11) \
		and not (sk7164.get("effects", []) as Array).any(func(ef): return int(ef.code) == 11) \
		and not (sk7165.get("effects", []) as Array).any(func(ef): return int(ef.code) in [11, 12, 13])
	_check("ev054_heals_pct", is_equal_approx(h1, -float(a.mhp) * 0.08) and is_equal_approx(h2, -float(a.mhp) * 0.12) and is_equal_approx(h3, -float(a.mhp) * 0.25) and no_dup_hp, [h1, h2, h3, a.mhp, no_dup_hp])

	var st1655 := XDB.rec("States", 1655)
	var r1655 := float((st1655.get("traits", []) as Array)[0].get("value", 0.0))
	_check("ev054_1655_state_110", is_equal_approx(r1655, 1.1) and (sk7188.get("effects", []) as Array).any(func(ef): return int(ef.code) == 44 and int(ef.dataId) == 2486), r1655)


func _test_lottery_all(s: XState) -> void:
	var re_forbid := RegEx.create_from_string("(?i)<(passiveAPLUS|AgainUse\\w+|DepassiveHarmRe\\d+|passiveHarmRe\\d+|passiveWPNM\\d+|passivePBSTEX\\d+|StartPushState(?:1245|1246|1247|1248|1645))\\b")
	var re_flat_pbst := RegEx.create_from_string("<passivePBST\\d:\\s*[+-]?\\d+(?:\\.\\d+)?\\s*>")
	var taught := {}
	for it in XDB.table("Items"):
		if not it is Dictionary:
			continue
		for ef in it.get("effects", []):
			if int(ef.get("code", 0)) == 43:
				var sid := int(ef.get("dataId", 0))
				var raw: Dictionary = XDB.table("Skills")[sid] if sid > 0 and sid < XDB.table("Skills").size() and XDB.table("Skills")[sid] is Dictionary else {}
				if int(raw.get("stypeId", 0)) == 5:
					taught[sid] = true
	var bad_cov := []
	var bad_tags := []
	for sid in taught:
		if not XTianqiGeneralBooks.has(int(sid)):
			bad_cov.append(sid)
		var note := str(XDB.rec("Skills", int(sid)).get("note", ""))
		if re_forbid.search(note) != null or re_flat_pbst.search(note) != null:
			bad_tags.append(sid)
	_check("lottery_147_full_coverage_clean", taught.size() == 147 and bad_cov.is_empty() and bad_tags.is_empty(), [taught.size(), bad_cov.size(), bad_tags])

	# T446 P3-1：学了 6325~6328 和 6530 开战后，身上不再挂 1245~1248 / 1645 乘法状态，改由 passiveHarmRi 合计 +16%
	var a := s.actor(s.party[0])
	for sid in [6325, 6326, 6327, 6328, 6530]:
		a.learn_skill(sid)
	a.refresh_passive()
	var logic := XBattleLogic.new()
	logic.setup(4, s)
	var has_old_mul_state := false
	for stid in [1245, 1246, 1247, 1248, 1645]:
		if a.is_state_affected(stid):
			has_old_mul_state = true
	var p_sum := 0
	for sid in [6325, 6326, 6327, 6328, 6530]:
		p_sum += int(XDB.rec("Skills", sid).get("meta", {}).get("passiveHarmRi", "0"))
	_check("t446_p3_no_mul_states", not has_old_mul_state and p_sum == 16, [has_old_mul_state, p_sum])

	# 掉率直读（6301=+2%，6304=+8%，不被旧 tier() 强圆到 5/10）
	a.learn_skill(6301)
	a.learn_skill(6304)
	a.refresh_passive()
	var srcs := XTianqiDrop.sources_of(a)
	var v6301 := -1.0
	var v6304 := -1.0
	for row in srcs:
		if str(row.name).contains("物品爆率·Lv1"):
			v6301 = float(row.value)
		if str(row.name).contains("物品爆率·LvMax"):
			v6304 = float(row.value)
	_check("lottery_drop_exact_values", is_equal_approx(v6301, 2.0) and is_equal_approx(v6304, 8.0), [v6301, v6304])

	# CodexParamRate 缓存跨档隔离（10436：天启篇 +5%，西游档 +25%）
	a.learn_skill(10436)
	var tq_rate := XPowerBooks.param_rate_bonus(a, 2)
	var xs := _xiyou_state()
	var xa := xs.actor(xs.party[0])
	xa.learn_skill(10436)
	var xy_rate := XPowerBooks.param_rate_bonus(xa, 2)
	XState.current = s
	var tq_rate2 := XPowerBooks.param_rate_bonus(a, 2)
	_check("codex_param_rate_cache_isolation", is_equal_approx(tq_rate, 5.0) and is_equal_approx(xy_rate, 25.0) and is_equal_approx(tq_rate2, 5.0), [tq_rate, xy_rate, tq_rate2])


func _test_battle_and_ledger(s: XState) -> void:
	var s2 := _tq_state("zhengdao")
	var a := s2.actor(s2.party[0])
	a.level = 81
	a.refresh_resources()
	for sid in [6186, 6192, 6224, 6228, 7163, 6308, 6316, 6328, 6530, 6652]:
		a.learn_skill(sid)
	a.refresh_passive()
	var logic := XBattleLogic.new()
	logic.setup(4, s2)
	var e: XEnemy = logic.enemies[0]
	e.hp = e.mhp
	XTianqiLedger.violations.clear()
	var dmg_total := 0
	for sid in [6186, 6224, 6228]:
		var sk := XDB.rec("Skills", sid)
		var res := XDamage.calculate(sk, a, e, {"critical": false, "variance": false})
		dmg_total += int(res.value)
	var heal_res := XDamage.calculate(XDB.rec("Skills", 7163), a, a, {"critical": false, "variance": false})
	_check("battle_cast_and_ledger_zero_violations", dmg_total > 0 and int(heal_res.value) < 0 and XTianqiLedger.violations.is_empty(), [dmg_total, heal_res.value, XTianqiLedger.violations])


func _test_rollback_and_xiyou() -> void:
	var s := _tq_state("zhengdao")
	# 1. ENABLED = false 完整回退
	XTianqiGeneralBooks.ENABLED = false
	var sk6186_off := XDB.rec("Skills", 6186)
	var sk6210_off := XDB.rec("Skills", 6210)
	var sk6328_off := XDB.rec("Skills", 6328)
	var st1012_off := XDB.rec("States", 1012)
	var st1013_off := XDB.rec("States", 1013)
	var st1004_off := XDB.rec("States", 1004)
	var a := s.actor(s.party[0])
	a.learn_skill(10436)
	var rate_off := XPowerBooks.param_rate_bonus(a, 2)
	var off_ok := str(sk6186_off.get("damage", {}).get("formulaProgram", {}).get("module", "")) != XTianqiGeneralBooks.MODULE \
		and str(sk6210_off.get("note", "")).contains("AgainUseAll") \
		and str(sk6328_off.get("note", "")).contains("StartPushState1248") \
		and str(st1012_off.get("note", "")).contains("passiveHarmRe01:8000") \
		and (st1013_off.get("traits", []) as Array).any(func(t): return int(t.code) == 61) \
		and str(st1004_off.get("note", "")).contains("G_ShuXing") \
		and is_equal_approx(rate_off, 25.0)
	_check("switch_disabled_full_rollback", off_ok, [rate_off])

	# 2. 西游档零变化（ENABLED = true）
	XTianqiGeneralBooks.ENABLED = true
	var xs := _xiyou_state()
	var xy_ok := str(XDB.rec("Skills", 6186).get("damage", {}).get("formulaProgram", {}).get("module", "")) != XTianqiGeneralBooks.MODULE \
		and str(XDB.rec("Skills", 6210).get("note", "")).contains("AgainUseAll") \
		and str(XDB.rec("Skills", 6328).get("note", "")).contains("StartPushState1248") \
		and str(XDB.rec("States", 1012).get("note", "")).contains("passiveHarmRe01:8000") \
		and (XDB.rec("States", 1013).get("traits", []) as Array).any(func(t): return int(t.code) == 61)
	_check("xiyou_save_zero_change", xy_ok)
	XState.current = s
