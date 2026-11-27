extends Node
## T528 专项测试：角色自带加成入池上限＋贝吉特四形态重标＋T527 越线 4 人调数＋西游档零改动
## 1. 验收 1：漏删原版标签清零（12 条）、未入表 5877／st1309 纳入上限、设计超额角色运行期合计 ≤+30%（技/元/终）／≤+50%（爆）、超额折进招式系数生效。
## 2. 验收 2：贝吉特 9943→10562→10563～10566／2771～2774 四形态保留并重标（去 ×6、去 +200 TP、去 confirm 保留换装外观、超蓝＋自我极意功合计终伤 ≤+30%）。
## 3. 验收 3/6/8：T527 越线 4 人（107 天星·陨、167 黑翼裁决、171 释魂刀、175 谷雨储备终结）D287 调数与 XGuyu 运行期读取生效。
## 4. 验收 5：西游档零改动（XTianqi.active 守卫）。

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


func _touch(a: XActor) -> void:
	a.read_touch()
	a._pm_base = {}
	a.refresh_passive()


func _has_phase(effs, phase: String) -> bool:
	return effs is Array and (effs as Array).any(func(e): return e is Dictionary and str(e.get("phase", "")) == phase)


func _has_op(effs, op: String) -> bool:
	return effs is Array and (effs as Array).any(func(e): return e is Dictionary and str(e.get("op", "")) == op)


func _ensure_skills(a: XActor, ids: Array) -> void:
	for id in ids:
		if not a.skill_ids.has(int(id)):
			a.skill_ids.append(int(id))


func _run() -> void:
	XMessageBox.auto = true
	var kit := Kit.new("xiyou_tianqi_t528")
	seed(20261126)
	XTianqiSkills.reload_table()
	XTianqiSecrets.reload_table()

	_test_1_leaked_tags_and_unreworked()
	_test_1_innate_caps_runtime()
	_test_1_folded_coefs()
	_test_2_vegito_four_forms()
	_test_2b_vegito_two_turn_upgrade()
	_test_2c_vegito_cards()
	_test_3_t527_outliers()
	_test_5_xiyou_zero_change()

	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		print(("PASS " if r.passed else "FAIL "), r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 1A. 漏删原版标签清零 + 未入表 5877／st1309 补录
func _test_1_leaked_tags_and_unreworked() -> void:
	_new_tianqi_state([1, 4, 85, 88, 164])
	var bad_st := []
	for sid in [1062, 3756, 3726, 2768, 4772, 4773, 5996, 5864, 5847, 7458, 7008]:
		var n := str(XDB.rec("Skills", sid).get("note", ""))
		if n.contains("SkillTypesDvup"):
			bad_st.append(sid)
	var n4704 := str(XDB.rec("Skills", 4704).get("note", ""))
	_check("t1_leaked_tags_stripped", bad_st.is_empty() and not n4704.contains("passiveHarmRi"), [bad_st, n4704.contains("passiveHarmRi")])

	var n5877 := str(XDB.rec("Skills", 5877).get("note", ""))
	var st1309 := XDB.rec("States", 1309)
	var n1309 := str(st1309.get("note", ""))
	var amp1309: Dictionary = st1309.get("yep", {}).get("elementAmplify", {})
	_check("t1_5877_and_1309_capped",
		n5877.contains("<SkillTypesDvupA:30%>") and not n5877.contains("200%")
		and n1309.contains("<Replace Attack: 7317>") and not n1309.contains("passiveCrHarmRi")
		and not n1309.contains("Element Amplify") and amp1309.is_empty(),
		[n5877.contains("<SkillTypesDvupA:30%>"), n1309.contains("<Replace Attack: 7317>"), amp1309])


## 1B. 运行期角色自带加成合计检验（技能/元素/终伤 ≤+30%、爆伤 ≤+50%）
func _test_1_innate_caps_runtime() -> void:
	var s := _new_tianqi_state([1, 4, 32, 81, 86, 159, 162])
	# 1 狗逍遥：41 + 717 + 1746 + 2746 物理元素 = 30%
	var a1: XActor = s.actor(1)
	a1.equips = []
	_ensure_skills(a1, [41, 717, 1746, 2746])
	_touch(a1)
	var e1 := XDamage.own_bonus(a1, 1)
	_check("t1_actor1_elem_cap30", is_equal_approx(e1, 0.30), e1)

	# 4 窃格瓦拉：2769 + 1238 + 心法 4733 爆伤 = 50%
	var a4: XActor = s.actor(4)
	a4.equips = []
	_ensure_skills(a4, [2769, 1238, 4733])
	_touch(a4)
	var c4 := float(a4._passive_cache.get("critHarmRi", 0.0))
	_check("t1_actor4_crit_cap50", is_equal_approx(c4, 0.50), c4)

	# 32 涅斐莉：5422 + 6910 爆伤 = 50%
	var a32: XActor = s.actor(32)
	a32.equips = []
	_ensure_skills(a32, [5422, 6910])
	_touch(a32)
	var c32 := float(a32._passive_cache.get("critHarmRi", 0.0))
	_check("t1_actor32_crit_cap50", is_equal_approx(c32, 0.50), c32)

	# 81 申公豹：4837 + st850 道友请上路 爆伤 = 50%
	var a81: XActor = s.actor(81)
	a81.equips = []
	_ensure_skills(a81, [4837])
	a81.clear_states()
	a81.add_state(850)
	_touch(a81)
	var c81 := float(a81._passive_cache.get("critHarmRi", 0.0))
	_check("t1_actor81_crit_cap50", is_equal_approx(c81, 0.50), c81)

	# 86 张三丰：5859 太极拳 + 5864 少林绝技，技能伤(拳套) = 30%，SkillTypesDvup = 0
	var a86: XActor = s.actor(86)
	a86.equips = []
	a86.skill_ids = [5859, 5864]
	_touch(a86)
	var sk86 := float(a86._passive_cache.get("SkETypeHarmRi", {}).get(5, 0.0))
	var st86: Dictionary = a86._passive_cache.get("skillTypeDvup", {})
	_check("t1_actor86_skill_cap30", is_equal_approx(sk86, 0.30) and st86.is_empty(), [sk86, st86])

	# 159 五河琴里：10054 + 10059 + st2553 + st2765 + st2786 → 爆伤 = 50%、火伤 = 30%
	var a159: XActor = s.actor(159)
	a159.equips = []
	a159.skill_ids = [10054, 10059]
	a159.clear_states()
	a159.add_state(2553)
	a159.add_state(2765)
	a159.add_state(2786)
	_touch(a159)
	var c159 := float(a159._passive_cache.get("critHarmRi", 0.0))
	var f159 := XDamage.own_bonus(a159, 2)
	_check("t1_actor159_caps", is_equal_approx(c159, 0.50) and is_equal_approx(f159, 0.30), [c159, f159])

	# 162 诛仙：st2721 凝气成罡 终伤 = 30%（state 桶 = 0.30；含共用进阶 1240~1244 的 +0.20 共 0.50，去共用进阶后恰好 0.30）
	var a162: XActor = s.actor(162)
	a162.equips = []
	a162.clear_states()
	a162.add_state(2721)
	_touch(a162)
	var by162: Dictionary = a162._passive_cache.get("bySource", {}).get("globalHarmRi", {})
	var st_h162 := float(by162.get("state", 0.0))
	a162.skill_ids = a162.skill_ids.filter(func(id): return not int(id) in [1240, 1241, 1242, 1244])
	_touch(a162)
	var h162 := float(a162._passive_cache.get("globalHarmRi", 0.0))
	_check("t1_actor162_harm_cap30", is_equal_approx(st_h162, 0.30) and is_equal_approx(h162, 0.30), [st_h162, h162, by162])


## 1C. 超额折进招式系数生效
func _test_1_folded_coefs() -> void:
	_new_tianqi_state([1, 4, 32, 86, 88, 159, 162])
	var checks := {
		"160": is_equal_approx(float(XTianqiSkills.spec(160).damage.coef), 0.46),
		"1233": is_equal_approx(float(XTianqiSkills.spec(1233).damage.coef), 0.92),
		"508": is_equal_approx(float(XTianqiSkills.spec(508).damage.coef), 6.0),
		"1696": is_equal_approx(float(XTianqiSkills.spec(1696).damage.coef), 5.0),
		"5860": is_equal_approx(float(XTianqiSkills.spec(5860).damage.stats.atk), 0.21),
		"5888": is_equal_approx(float(XTianqiSkills.spec(5888).damage.coef), 3.0),
		"10056": is_equal_approx(float(XTianqiSkills.spec(10056).damage.coef), 7.0),
		"10456": is_equal_approx(float(XTianqiSkills.spec(10456).damage.coef), 0.44),
	}
	var bad := checks.keys().filter(func(k): return not bool(checks[k]))
	_check("t1_folded_coefs_applied", bad.is_empty(), [bad, checks])


## 2. 贝吉特四形态保留并重标（去 ×6、去 +200 TP、留换装外观、与自我极意功合计 ≤+30%）
func _test_2_vegito_four_forms() -> void:
	var s := _new_tianqi_state([164, 1, 2, 3])
	var expected := {
		2771: [1.05, 0.10, "bjtc1"],
		2772: [1.10, 0.15, "cjbjt2"],
		2773: [1.12, 0.18, "cjbjt3"],
		2774: [1.15, 0.20, "clbjt"],
	}
	var bad := []
	for stid in expected:
		var st := XDB.rec("States", stid)
		var effs = st.get("effects", [])
		var atk_m := 1.0
		var has_aplus := false
		for t in st.get("traits", []):
			if int(t.get("code", 0)) == 21 and int(t.get("dataId", 0)) == 2:
				atk_m = float(t.get("value", 1.0))
			elif int(t.get("code", 0)) == 61:
				has_aplus = true
		var img := ""
		for e in effs:
			if e is Dictionary and str(e.get("op", "")) == "costume_image":
				img = str(e.get("image", ""))
		if _has_phase(effs, "confirm") or img != str(expected[stid][2]) or not is_equal_approx(atk_m, float(expected[stid][0])) or has_aplus:
			bad.append([stid, _has_phase(effs, "confirm"), img, atk_m, has_aplus])
	_check("t2_vegito_four_forms_spec", bad.is_empty(), bad)

	# 运行期：超蓝 2774 + 自我极意功 2776 → 终伤恰好 +30%（≤30%），物攻魔攻约 ×1.15（不再 ×6），换装外观变 clbjt
	var v: XActor = s.actor(164)
	v.equips = []
	v.skill_ids = [9940, 10566, 10568]
	v.clear_states()
	_touch(v)
	var atk0 := v.atk
	var mat0 := v.mat
	v.add_state(2776)
	v.add_state(2774)
	_touch(v)
	var ra := v.atk / maxf(1.0, atk0)
	var rm := v.mat / maxf(1.0, mat0)
	var harm := float(v._passive_cache.get("globalHarmRi", 0.0))
	var elem := XDamage.own_bonus(v, 1)
	var pooled := XTianqiLedger.live_pool_effects(v).filter(func(x): return int(x[0]) == 2774)
	var form_img := XCostumes.vegetto_form(s, v, "")
	_check("t2_vegito_blue_plus_ego_runtime",
		ra >= 1.12 and ra <= 1.18 and rm >= 1.12 and rm <= 1.18
		and is_equal_approx(harm, 0.30) and is_equal_approx(elem, 0.30)
		and pooled.is_empty() and form_img == "clbjt",
		[ra, rm, harm, elem, pooled.size(), form_img])


## 2B. T528 R2（核查 P1-1）：真战斗里两回合升级——上一回合挂着旧形态，升级后下一回合施放新形态招，旧形态要被移除、终伤不越 +30%
## 学会／遗忘照公共事件 1717（学 10563 忘 10562）、1720（学 10566 忘 10565）的内容手动做；回合结束／开始走 XBattleLogic.end_turn／start_turn。
func _test_2b_vegito_two_turn_upgrade() -> void:
	var s := _new_tianqi_state([164, 1, 2, 3])
	var v: XActor = s.actor(164)
	v.equips = []
	v.skill_ids = [9940, 10562, 10568]
	v.clear_states()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	v.add_state(2776)
	# 链一：五十倍界王拳 → 超赛 1
	lg.start_turn()
	lg.act(v, XDB.rec("Skills", 10562), v)
	var had_2770 := v.is_state_affected(2770)
	v.learn_skill(10563)
	v.forget_skill(10562)
	lg.end_turn()
	lg.start_turn()
	lg.act(v, XDB.rec("Skills", 10563), v)
	_touch(v)
	var h1 := float(v._passive_cache.get("globalHarmRi", 0.0))
	_check("t2b_kaioken_to_ss1_replaces",
		had_2770 and v.is_state_affected(2771) and not v.is_state_affected(2770) and is_equal_approx(h1, 0.20),
		[had_2770, v.is_state_affected(2771), v.is_state_affected(2770), h1])
	# 链二：超赛 3 → 超蓝
	v.learn_skill(10565)
	v.forget_skill(10563)
	lg.end_turn()
	lg.start_turn()
	lg.act(v, XDB.rec("Skills", 10565), v)
	var had_2773 := v.is_state_affected(2773) and not v.is_state_affected(2771)
	v.learn_skill(10566)
	v.forget_skill(10565)
	lg.end_turn()
	lg.start_turn()
	lg.act(v, XDB.rec("Skills", 10566), v)
	_touch(v)
	var h2 := float(v._passive_cache.get("globalHarmRi", 0.0))
	var forms := [2567, 2770, 2771, 2772, 2773, 2774].filter(func(id): return v.is_state_affected(id))
	_check("t2b_ss3_to_blue_replaces",
		had_2773 and forms == [2774] and is_equal_approx(h2, 0.30) and str(v.data().get("battlerName", "")) == "clbjt",
		[had_2773, forms, h2, v.data().get("battlerName", "")])


## 2C. T528 R2（核查 P2-2）：变身卡对象是自己、超蓝写战后倒下；形态状态说明进运行时记录
func _test_2c_vegito_cards() -> void:
	_new_tianqi_state([164])
	var bad := []
	for sid in [10563, 10564, 10565, 10566]:
		var n := str(XDB.rec("Skills", sid).get("note", ""))
		if not n.contains("对象:自己") or n.contains("单个敌人"):
			bad.append(sid)
	var blue := " ".join(XTianqiSkills.spec(10566).get("desc", []))
	var notes := []
	for stid in [2567, 2770, 2771, 2772, 2773, 2774]:
		if not str(XDB.rec("States", stid).get("note", "")).contains("<StateNote>"):
			notes.append(stid)
	_check("t2c_vegito_cards_self_and_notes",
		bad.is_empty() and blue.contains("战斗结束时，贝吉特会倒下") and notes.is_empty()
		and str(XDB.rec("States", 2774).get("note", "")).contains("战斗结束时倒下"),
		[bad, blue, notes])


## 3. T527 越线 4 人（107/167/171/175）D287 调数验证
func _test_3_t527_outliers() -> void:
	_new_tianqi_state([107, 167, 171, 175])
	var d167: Dictionary = XTianqiSkills.spec(10125).damage.stats
	var d171: Dictionary = XTianqiSkills.spec(10218).damage.stats
	var d107: Dictionary = XTianqiSkills.spec(5673).damage.stats
	var f175 := XGuyu.tq_pct("finish_pct", 100.0)
	var desc175 := " ".join(XTianqiSkills.spec(10292).get("desc", []))
	_check("t3_t527_four_outliers_tuned",
		is_equal_approx(float(d167.get("mat", 0.0)), 0.85) and is_equal_approx(float(d167.get("mhp", 0.0)), 0.01)
		and is_equal_approx(float(d171.get("atk", 0.0)), 2.0) and is_equal_approx(float(d171.get("mhp", 0.0)), 0.0)
		and is_equal_approx(float(d107.get("mhp", 0.0)), 0.06) and is_equal_approx(float(d107.get("mat", 0.0)), 0.0)
		and is_equal_approx(f175, 0.07) and desc175.contains("×7%"),
		[d167, d171, d107, f175, desc175])


## 5. 西游档零改动（XTianqi.active 守卫）
func _test_5_xiyou_zero_change() -> void:
	var plain := XState.new_game_blank()
	XState.current = plain
	var n5847 := str(XDB.rec("Skills", 5847).get("note", ""))
	var n5877 := str(XDB.rec("Skills", 5877).get("note", ""))
	var st1309 := str(XDB.rec("States", 1309).get("note", ""))
	var st850 := str(XDB.rec("States", 850).get("note", ""))
	var st2774 := XDB.rec("States", 2774)
	var atk_m := 1.0
	for t in st2774.get("traits", []):
		if int(t.get("code", 0)) == 21 and int(t.get("dataId", 0)) == 2:
			atk_m = float(t.get("value", 1.0))
	var tp10566 := (XDB.rec("Skills", 10566).get("effects", []) as Array).any(func(e): return int(e.get("code", -1)) == 13)
	var ok := (not XTianqi.active(plain)
		and n5847.contains("SkillTypesDvupA: 200%")
		and n5877.contains("SkillTypesDvupA: 200%")
		and st1309.contains("Element Amplify 3: +130%")
		and st850.contains("passiveCrHarmRi:100")
		and absf(atk_m - 6.0) < 0.01
		and _has_phase(st2774.get("effects", []), "confirm")
		and tp10566)
	_check("t5_xiyou_zero_change", ok, [n5847.contains("200%"), n5877.contains("200%"), st1309.contains("+130%"), st850.contains(":100"), atk_m, _has_phase(st2774.get("effects", []), "confirm"), tp10566])
