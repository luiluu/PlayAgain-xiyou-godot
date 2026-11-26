extends Node
## T524 天启篇止血专项测试（小A 起稿，cc 续：改用现有接口、补超赛只删确认阶段与西游档对照）：
## 1. 止血 1：艾瑞塔 5459 咒灭魔弹删旧 SkillPass538/2058（暗影毁灭弹学 5459 前后伤害一致，不再 ×3）。
## 2. 止血 2：贝吉特 10563～10566 去两条 +100 TP；超赛状态 2771～2774 改写（物攻魔攻 ≤ ×1.15、去确认阶段 ×k、换装外观照留）。
## 3. 止血 3：破限之心全 7 阶（armor:7904～7911，含星空 7911）删 passiveHarmRi/passiveCrHarmRi。
## 4. 止血 4：被封印的秘籍书在 XPowerBooks.param_rate_bonus 中不再加属性，解封后恢复。
## 5. 扫描同类修复：Boss 血脉（SkillPass）、7499/7516 横霸千峰、armor:4514/4517/4519、state 2590/2733/2735/2737、
##    CE 衍生被动（维利 3780～3788、三笠 8123～8146、裴钱 4415～4435）。
## 6. 西游档零改动：上述技能、状态、装备与权能书属性倍率在西游档保持原貌。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _new_tianqi_state(lineup: Array) -> XState:
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		s.actor(int(id)).recover_all()
	return s


func _enemy(floor_no := 12) -> XEnemy:
	var eid := int(XDB.table("Troops")[int(XGuardianRework.TROOPS[floor_no])].members[0].enemyId)
	var e := XEnemy.new()
	e.setup(eid, 3)
	e.recover_all()
	return e


func _touch(a: XActor) -> void:
	a.read_touch()
	a._pm_base = {}
	a.refresh_passive()


func _has_phase(effs, phase: String) -> bool:
	return effs is Array and (effs as Array).any(func(e): return e is Dictionary and str(e.get("phase", "")) == phase)


func _has_op(effs, op: String) -> bool:
	return effs is Array and (effs as Array).any(func(e): return e is Dictionary and str(e.get("op", "")) == op)


func _run() -> void:
	XMessageBox.auto = true
	var kit := Kit.new("xiyou_tianqi_t524_leaks")
	seed(20261126)
	XTianqiSkills.reload_table()
	XTianqiSecrets.reload_table()

	_test_1_arita_5459()
	_test_2_vegito_chain_and_states()
	_test_3_garou_relics_gear()
	_test_4_sealed_book_param_rate()
	_test_5_scan_fixes()
	_test_6_xiyou_untouched()

	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		print(("PASS " if r.passed else "FAIL "), r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 1. 止血 1：艾瑞塔 5459 漏 note_remove
func _test_1_arita_5459() -> void:
	var s := _new_tianqi_state([53, 1, 2, 3, 4])
	var sk := XDB.rec("Skills", 5459)
	var note := str(sk.get("note", ""))
	var meta: Dictionary = sk.get("meta", {})
	_check("t1_5459_note_stripped", not note.contains("SkillPass") and not meta.has("SkillPass538") and not meta.has("SkillPass2058"), meta.keys())

	var arita: XActor = s.actor(53)
	arita.change_level(60)
	for id in [2058, 5459]:
		if not arita.skill_ids.has(id):
			arita.skill_ids.append(id)
	_touch(arita)
	var learned := arita.skills().any(func(o): return int(o.get("id", 0)) == 5459)
	var sp: Dictionary = arita._passive_cache.get("skillPass", {})
	var r2058 := float(sp.get(2058, {}).get("rate", 0.0))
	var r538 := float(sp.get(538, {}).get("rate", 0.0))
	# 撤掉修复时这两项各是 +2.0（×3）；修后 5459 不再给，旁的来源（2057、2059、2060 原版也带）在卡里也已删
	var dmg := XDamage.preview_hit(XDB.rec("Skills", 2058), arita, _enemy(1))
	_check("t1_arita_5459_no_skillpass_in_battle", learned and r2058 < 0.01 and r538 < 0.01 and dmg > 0.0, [learned, sp, dmg])


## 2. 止血 2：贝吉特升级链技能与超赛状态
func _test_2_vegito_chain_and_states() -> void:
	var s := _new_tianqi_state([164, 1, 2, 3, 4])
	var bad_sk := []
	for sid in [10563, 10564, 10565, 10566]:
		var sk := XDB.rec("Skills", sid)
		var has_tp := (sk.get("effects", []) as Array).any(func(e): return int(e.get("code", -1)) == 13)
		var keeps_state := (sk.get("effects", []) as Array).any(func(e): return int(e.get("code", -1)) == 21)
		if not XTianqiSkills.has(sid) or has_tp or not keeps_state:
			bad_sk.append([sid, XTianqiSkills.has(sid), has_tp, keeps_state])
	_check("t2_vegito_skills_10563_10566_reworked", bad_sk.is_empty(), bad_sk)

	var bad_st := []
	for stid in [2771, 2772, 2773, 2774]:
		var st := XDB.rec("States", stid)
		var effs = st.get("effects", [])
		var max_param := 1.0
		var has_aplus := false
		for t in st.get("traits", []):
			if int(t.get("code", 0)) == 21:
				max_param = maxf(max_param, float(t.get("value", 1.0)))
			elif int(t.get("code", 0)) == 61:
				has_aplus = true
		if _has_phase(effs, "confirm") or not _has_op(effs, "costume_image") or max_param > 1.15 + 1e-6 or has_aplus:
			bad_st.append([stid, _has_phase(effs, "confirm"), _has_op(effs, "costume_image"), max_param, has_aplus])
	_check("t2_vegito_states_2771_2774_capped", bad_st.is_empty(), bad_st)

	# 实战面板：挂超蓝后物攻、魔攻约 ×1.15（原版 ×6），总账不再把超蓝当 +500% 归池
	var vegito: XActor = s.actor(164)
	vegito.clear_states()
	_touch(vegito)
	var atk0 := vegito.atk
	var mat0 := vegito.mat
	vegito.add_state(2774)
	_touch(vegito)
	var ra := vegito.atk / maxf(1.0, atk0)
	var rm := vegito.mat / maxf(1.0, mat0)
	var pooled := XTianqiLedger.live_pool_effects(vegito).filter(func(x): return int(x[0]) == 2774)
	_check("t2_vegito_blue_2774_runtime", ra >= 1.10 and ra <= 1.20 and rm >= 1.10 and rm <= 1.20 and pooled.is_empty(), [atk0, vegito.atk, ra, mat0, vegito.mat, rm, pooled.size()])
	vegito.clear_states()


## 3. 止血 3：破限之心全 7 阶
func _test_3_garou_relics_gear() -> void:
	_new_tianqi_state([173, 1, 2, 3, 4])
	var bad := []
	for aid in [7904, 7905, 7906, 7908, 7909, 7910, 7911]:
		var raw := XDB.rec("Armors", aid).duplicate(true)
		raw["kind"] = "armor"
		raw["base"] = aid
		var view: Dictionary = XTianqiSkills.gear_view(raw)
		var note := str(view.get("note", ""))
		var meta: Dictionary = view.get("meta", {})
		if note.contains("passiveHarmRi") or note.contains("passiveCrHarmRi") or meta.has("passiveHarmRi") or meta.has("passiveCrHarmRi"):
			bad.append([aid, meta.keys()])
	_check("t3_garou_relics_7904_7911_stripped", bad.is_empty(), bad)


## 4. 止血 4：被封印的秘籍书不再加属性，解封后恢复
func _test_4_sealed_book_param_rate() -> void:
	var s := _new_tianqi_state([1, 2, 3, 4, 5])
	s.gold = 99999999
	var a: XActor = s.actor(1)
	# 488 体能强化（天启篇 最大生命 +8%）、3686 剑心（物攻 +10%、物防 −10%），都占秘籍格
	for id in [488, 3686]:
		if not a.skill_ids.has(id):
			a.skill_ids.append(id)
	_touch(a)
	var mhp_on := XPowerBooks.param_rate_bonus(a, 0)
	var atk_on := XPowerBooks.param_rate_bonus(a, 2)
	var mhp_v := a.mhp
	var atk_v := a.atk
	_check("t4_active_books_add_param_rate", mhp_on > 0.0 and atk_on > 0.0, [mhp_on, atk_on])

	var r1 := XTianqiSecrets.seal(s, a, 488)
	var r2 := XTianqiSecrets.seal(s, a, 3686)
	_touch(a)
	var mhp_off := XPowerBooks.param_rate_bonus(a, 0)
	var atk_off := XPowerBooks.param_rate_bonus(a, 2)
	_check("t4_sealed_books_zero_param_rate", bool(r1.get("ok", false)) and bool(r2.get("ok", false)) and absf(mhp_off) < 0.01 and absf(atk_off) < 0.01 and a.mhp < mhp_v and a.atk < atk_v, [r1, r2, mhp_off, atk_off, mhp_v, a.mhp, atk_v, a.atk])

	var r3 := XTianqiSecrets.unseal(s, a, 488)
	_touch(a)
	var mhp_back := XPowerBooks.param_rate_bonus(a, 0)
	_check("t4_unsealed_book_restores_param_rate", bool(r3.get("ok", false)) and absf(mhp_back - mhp_on) < 0.01, [r3, mhp_back, mhp_on])


## 5. 扫描脚本查出的同类真漏项
func _test_5_scan_fixes() -> void:
	_new_tianqi_state([12, 22, 79, 95, 104])
	var bad_bl := []
	for sid in [2807, 2813, 3224, 3236, 4701, 4707]:
		if str(XDB.rec("Skills", sid).get("note", "")).contains("SkillPass"):
			bad_bl.append(sid)
	_check("t5_bloodlines_no_skillpass", bad_bl.is_empty(), bad_bl)

	var n7499 := str(XDB.rec("Skills", 7499).get("note", ""))
	var n7516 := str(XDB.rec("Skills", 7516).get("note", ""))
	var zj7516 := RegEx.create_from_string("<ConsumeReduceZj:[^>]*>").search_all(n7516).size()
	_check("t5_7499_7516_consume_reduce", not n7499.contains("ConsumeReduceZj") and zj7516 == 1 and n7516.contains("<ConsumeReduceZj: 20%>"), [n7499.contains("ConsumeReduceZj"), zj7516])

	var bad_g := []
	for pair in [[4514, "passiveHarmRe"], [4517, "SkillPass"], [4519, "SkillPass"]]:
		var raw := XDB.rec("Armors", int(pair[0])).duplicate(true)
		raw["kind"] = "armor"
		raw["base"] = int(pair[0])
		if str(XTianqiSkills.gear_view(raw).get("note", "")).contains(str(pair[1])):
			bad_g.append(pair)
	_check("t5_gear_4514_4517_4519_stripped", bad_g.is_empty(), bad_g)

	var bad_st := []
	if str(XDB.rec("States", 2590).get("note", "")).contains("passiveHarmRe"):
		bad_st.append(2590)
	for stid in [2733, 2735, 2737]:
		if str(XDB.rec("States", stid).get("note", "")).contains("passivePBST"):
			bad_st.append(stid)
	_check("t5_states_2590_2733_2737_stripped", bad_st.is_empty(), bad_st)

	var n3788 := str(XDB.rec("Skills", 3788).get("note", ""))
	var vili_ok := not n3788.contains("passiveHarmRe") and n3788.contains("<passivePBST0:10%>")
	var n8142 := str(XDB.rec("Skills", 8142).get("note", ""))
	var n8146 := str(XDB.rec("Skills", 8146).get("note", ""))
	var mikasa_ok := not n8142.contains("passiveHarmRi") and not n8142.contains("passiveCrHarmRi") and not n8146.contains("SkillPass") and not n8146.contains("passivePBST")
	var n4424 := str(XDB.rec("Skills", 4424).get("note", ""))
	var n4435 := str(XDB.rec("Skills", 4435).get("note", ""))
	var peiqian_ok := not n4424.contains("passiveHarmRe") and not n4424.contains("passivePBST") and not n4435.contains("passiveELUP") and not n4435.contains("passivePBST")
	_check("t5_ce_derived_vili_mikasa_peiqian", vili_ok and mikasa_ok and peiqian_ok, [vili_ok, mikasa_ok, peiqian_ok])

	# cc 续：陈（74）经公共事件切换到的两个姿态照稿 74 节改写（玄牛 每回合回 5% 生命；金钟罩 承伤 −10%，原版受伤 −2000）
	var m2616: Dictionary = XDB.rec("Skills", 2616).get("meta", {})
	var m2623: Dictionary = XDB.rec("Skills", 2623).get("meta", {})
	var chen_ok := not m2616.keys().any(func(k): return str(k).begins_with("SkillPass") or str(k).begins_with("passiveELUP")) \
		and m2616.has("passiveXPBST7") \
		and not m2623.keys().any(func(k): return str(k).begins_with("passiveHarmRe")) \
		and m2623.has("passiveSPBST6") and m2623.has("passiveSPBST7")
	_check("t5_chen_2616_2623_stances", chen_ok and XTianqiSkills.has(2616) and XTianqiSkills.has(2623), [m2616.keys(), m2623.keys()])


## 6. 西游档零改动
func _test_6_xiyou_untouched() -> void:
	var s := XState.new_game_blank()
	s.difficulty = 3
	s.add_actor(1)
	s.map_id = 4
	XState.current = s
	XTextFix.sync_mode()
	var n5459 := str(XDB.rec("Skills", 5459).get("note", ""))
	var st2774 := XDB.rec("States", 2774)
	var atk_mult := 1.0
	for t in st2774.get("traits", []):
		if int(t.get("code", 0)) == 21 and int(t.get("dataId", -1)) == 2:
			atk_mult = float(t.get("value", 1.0))
	var tp10566 := (XDB.rec("Skills", 10566).get("effects", []) as Array).any(func(e): return int(e.get("code", -1)) == 13)
	var raw := XDB.rec("Armors", 7911).duplicate(true)
	raw["kind"] = "armor"
	raw["base"] = 7911
	var v7911: Dictionary = XTianqiSkills.gear_view(raw)
	var a: XActor = s.actor(1)
	if not a.skill_ids.has(488):
		a.skill_ids.append(488)
	_touch(a)
	var detail := [n5459.contains("SkillPass538"), atk_mult, _has_phase(st2774.get("effects", []), "confirm"), tp10566, str(v7911.get("note", "")).contains("passiveHarmRi"), XPowerBooks.param_rate_bonus(a, 0)]
	_check("t6_xiyou_zero_change", detail[0] and absf(atk_mult - 6.0) < 0.01 and detail[2] and tp10566 and detail[4], detail)
