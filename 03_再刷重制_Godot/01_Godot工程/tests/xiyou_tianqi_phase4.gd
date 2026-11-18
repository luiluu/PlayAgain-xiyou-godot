extends Node
## 【cc·T081】天启篇期四暗装接线（XTianqiBase.PHASE4，基础数值重构 v0.4 第七节第 2 条、第十节 T012-b）：
## 一、总开关默认关；关着每一行都是「关着」那一套（本体 NAN、K 1、U 1、守层者旧表、治疗照乘、绝对值原数、单段不封、九线爆伤不封、秘籍读旧键、面板没有天启注视）。
## 二、开着、天启篇存档：每一行都和总开关一致（rows_state），本体读标准线×职责×速度档，K＝表里的 base_damage（T082 实机标定 0.2）、进 dealt_parts，面板一行「天启注视　伤害 ×K」。
## 三、开着但是西游档：一律走关着那一套。
## 四、单段有效系数上限：开着时卡面系数×权重×条件超过档位上限压回上限，关着不封；全部卡在上限以内（数据校验同口径）。
## 五、角色卡跟着总开关开（CARDS 本身不动）。
## 六、端到端（核查 R2 P2-1，开、关各跑一遍）：双回复药走 _effect 生命、魔法各认自己那一行；持续伤害走 XExtDot.tick；
##     确认阶段治疗不乘 ×5（confirm_rows 的 skipTypesAny，按真实结算比；T214 回退 HEAL_SKIP_ALLY）；直接扣血 scale_direct 乘 K（反弹不乘）；九线爆伤封顶走 apply_nine_cap；伤害详情 gaze 行；骑士 U 进 stats／shadow_stats；表外角色回落职业曲线。
## 读的表：tianqi_data/base_line.json、abs_rescale.json、balance_table.json（combat_rules）、damage_ledger.json（phase4）、skill_rework.json（rules.single_hit_cap）。

const XIAOYAO := 1  # 狗逍遥：强者、输出、慢
const LVSIJI := 2

var results: Array = []


## T082 实机标定的 K（balance_table combat_rules.base_damage）；改标定只改这两行
const K_TABLE := 0.13
const K_TEXT := "0.13"
## T162 丙档实机量的首领生命临时折算 U（balance_table combat_rules.boss_hp_temp_unit）；重量只改这两行
const U_CRIT := 1.43
const U_NO_CRIT := 0.89

func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	seed(20261117)
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	XGojo.unlock_override = 0
	_check("default_on", XTianqiBase.PHASE4 and XTianqiSkills.MASTERY and not XTianqiSkills.CARDS and XTianqiSkills.cards_flag(), [XTianqiBase.PHASE4, XTianqiSkills.MASTERY, XTianqiSkills.CARDS])  # T220（T012-c）翻开关：总开关、熟练度默认开；CARDS 只给专项隔离用、照旧关，卡跟总开关走
	_off()
	_on()
	_xiyou()
	_hit_cap()
	_class_rate()
	_realm()
	_fabao()
	_tune_d189()
	_e2e(true)
	_e2e(false)
	_joint_smoke()
	XTianqiBase.PHASE4 = false
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _weak_ids() -> Array:
	return XTianqiSkills.ids(XTier.WEAK, true)


func _state(tianqi := true) -> XState:
	var w := _weak_ids().filter(func(id): return id != LVSIJI)
	var lineup := [XIAOYAO, LVSIJI, w[0], w[1], w[2]]
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
	return s


func _all_rows(want: bool) -> bool:
	var st := XTianqiBase.rows_state()
	for k in st:
		if bool(st[k]) != want:
			return false
	return true


## 关着：天启篇存档也照现在
func _off() -> void:
	XTianqiBase.PHASE4 = false
	var s := _state()
	var a: XActor = s.actor(XIAOYAO)
	a.change_level(81)
	_check("off.on", not XTianqiBase.on())
	_check("off.rows", _all_rows(false), XTianqiBase.rows_state())
	_check("off.base_nan", is_nan(XTianqiBase.param_base(a, 2)))
	var cls: Array = a.class_data().params
	_check("off.base_curve", is_equal_approx(a.param_base_direct(2), float(cls[2][a.level])), [a.param_base_direct(2), cls[2][a.level]])
	_check("off.k", XTianqiBase.k_for(a) == 1.0 and float(XTianqiCombat.dealt_parts(a, s).get("k", 0.0)) == 1.0)
	_check("off.u", XTianqiBase.boss_hp_unit(false) == 1.0 and XTianqiBase.boss_hp_unit(true) == 1.0)
	var old := {1: 2.0}
	_check("off.guardian_old", is_same(XTianqiBase.guardian_table("hp_base", old), old))
	_check("off.heal_x5", XTianqiBase.heal_skip_types().is_empty())
	_check("off.nine_crit", XTianqiBase.nine_crit_cap() < 0.0)
	_check("off.secret", XTianqiBase.secret_slot(0.123) == 0.123)
	_check("off.abs", XTianqiBase.abs_value("item_fixed_heal", 1, 500.0, a, "mhp") == 500.0)
	_check("off.hit_cap", XTianqiBase.single_hit_cap(a) == 0.0)
	_check("off.gaze", XTianqiBase.gaze_row().is_empty())
	_check("off.cards", not XTianqiSkills.cards_on() and XDB.rec("Skills", 3632).get("_tianqi_new") == null and not str(XDB.rec("Skills", 3632).get("damage", {}).get("formula", "")).contains("XTianqiSkills"))


## 开着、天启篇存档
func _on() -> void:
	XTianqiBase.PHASE4 = true
	XTianqiBase.clear_cache()
	var s := _state()
	_check("on.survives_new_game", XTianqiBase.PHASE4)
	var a: XActor = s.actor(XIAOYAO)
	a.change_level(81)
	a.param_mark_dirty()
	_check("on.on", XTianqiBase.on(), [XTianqiBase.PHASE4, XTianqi.active(XState.current)])
	_check("on.rows", _all_rows(true), XTianqiBase.rows_state())
	_check("on.cards_follow", XTianqiSkills.cards_on() and not XTianqiSkills.CARDS and str(XDB.rec("Skills", 3632).damage.formula).contains("XTianqiSkills"))
	# 本体：标准线 20＋20×81＝1640；输出 hp/def ×0.9、慢速 ×0.8
	var lv := 81.0
	var atk := floorf(20.0 + 20.0 * lv)
	_check("on.base_atk", a.param_base_direct(2) == atk, [a.param_base_direct(2), atk])
	_check("on.base_mhp", a.param_base_direct(0) == floorf((20.0 + 20.0 * lv) * 25.0 * 0.9), a.param_base_direct(0))
	_check("on.base_def", a.param_base_direct(3) == floorf((20.0 + 20.0 * lv) * 0.9), a.param_base_direct(3))
	_check("on.base_agi", a.param_base_direct(6) == floorf((20.0 + 20.0 * lv) * 0.8), a.param_base_direct(6))
	_check("on.base_not_curve", a.param_base_direct(2) != float(a.class_data().params[2][a.level]))
	# K
	_check("on.k_table", is_equal_approx(XTianqiBase.k_base(), K_TABLE), XTianqiBase.k_base())
	var on_parts := XTianqiCombat.dealt_parts(a, s)
	XTianqiBase.PHASE4 = false
	var off_parts := XTianqiCombat.dealt_parts(a, s)
	XTianqiBase.PHASE4 = true
	_check("on.k_dealt", is_equal_approx(float(on_parts.mult), float(off_parts.mult) * K_TABLE) and is_equal_approx(float(on_parts.k), K_TABLE), [on_parts, off_parts])
	_check("on.gaze_row", XTianqiBase.gaze_row() == ["天启注视", "伤害 ×" + K_TEXT], XTianqiBase.gaze_row())
	var rows := XStatusPage.global_bonuses(a)
	_check("on.gaze_panel", not rows.is_empty() and rows[0] == ["天启注视", "伤害 ×" + K_TEXT], rows.slice(0, 2))
	# U、守层者、治疗、九线、秘籍、绝对值、单段上限
	_check("on.u", is_equal_approx(XTianqiBase.boss_hp_unit(false), U_CRIT) and is_equal_approx(XTianqiBase.boss_hp_unit(true), U_NO_CRIT))  # T162 丙档实机量（表里的数）
	var old := {1: 2.0}
	_check("on.guardian_fallback", is_same(XTianqiBase.guardian_table("hp_base", old), old))  # guardian_phase4 由 T012-c 补，缺就退回旧表
	_check("on.heal_x5_off", XTianqiBase.heal_skip_types() == [3, 4])
	_check("on.nine_crit", is_equal_approx(XTianqiBase.nine_crit_cap(), 0.3))
	_check("on.secret", is_equal_approx(XTianqiBase.secret_slot(0.123), 0.08))
	var heal := XTianqiBase.abs_value("item_fixed_heal", 1, 500.0, a, "mhp")
	_check("on.abs_item", heal == floorf(float(a.mhp) * 7.2 / 100.0), [heal, a.mhp])
	_check("on.abs_dot_sign", XTianqiBase.abs_value("state_dot", 33, -300.0, a) == -floorf(float(a.mhp) * 4.3 / 100.0))
	_check("on.abs_unknown", XTianqiBase.abs_value("item_fixed_heal", 999999, 77.0, a, "mhp") == 77.0)
	_check("on.hit_cap_strong", XTianqiBase.single_hit_cap(a) == 11.0)
	_check("on.hit_cap_weak", XTianqiBase.single_hit_cap(s.actor(LVSIJI)) == float(XTianqiSkills.data().rules.single_hit_cap.get(XTianqiSkills.tier_of(s.actor(LVSIJI)), 0)))
	_check("on.hit_cap_enemy", XTianqiBase.single_hit_cap(null) == 0.0)
	XTianqiBase.PHASE4 = false


## 【cc·T082】职业属性倍率（惠惠 153 职业魔攻 ×3）：期四开着不算，CLASS_RATE_OFF 关掉或总开关关着照算
func _class_rate() -> void:
	var s := _state()
	XTianqi._joining = true
	s.add_actor(153)
	XTianqi._joining = false
	var a: XActor = s.actor(153)
	XTianqiBase.PHASE4 = true
	a.param_mark_dirty()
	var on_rate := a.param_rate(4)
	XTianqiBase.CLASS_RATE_OFF = false
	a.param_mark_dirty()
	var kept := a.param_rate(4)
	XTianqiBase.CLASS_RATE_OFF = true
	XTianqiBase.PHASE4 = false
	a.param_mark_dirty()
	var off_rate := a.param_rate(4)
	_check("class_rate.stripped", is_equal_approx(on_rate, kept - 2.0), [on_rate, kept])
	_check("class_rate.switch_back", is_equal_approx(kept, off_rate) and off_rate >= 3.0, [kept, off_rate])
	_check("class_rate.other_param", (func():
		XTianqiBase.PHASE4 = true
		a.param_mark_dirty()
		var r := a.param_rate(2)
		XTianqiBase.PHASE4 = false
		a.param_mark_dirty()
		return is_equal_approx(r, a.param_rate(2))).call())


## 【cc·T082】原版境界被动（9976 圣者境界：终伤、爆伤各 +100%）：期四开着拦掉数值标签，REALM_OFF 关掉或总开关关着照原版
func _realm() -> void:
	_state()
	XTianqiBase.PHASE4 = true
	var on_note := str(XDB.rec("Skills", 9976).get("note", ""))
	XTianqiBase.REALM_OFF = false
	var kept := str(XDB.rec("Skills", 9976).get("note", ""))
	XTianqiBase.REALM_OFF = true
	XTianqiBase.PHASE4 = false
	var off_note := str(XDB.rec("Skills", 9976).get("note", ""))
	_check("realm.stripped", not on_note.contains("passiveHarmRi") and not on_note.contains("passiveCrHarmRi") and not on_note.contains("passivePBST"), on_note.left(200))
	_check("realm.switch_back", kept.contains("passiveHarmRi") and kept == off_note)
	XTianqiBase.PHASE4 = true
	_check("realm.push_state", not str(XDB.rec("Skills", 5777).get("note", "")).contains("StartPushState"))
	_check("realm.card_skill_untouched", XDB.rec("Skills", 9933) == XTianqiSkills.rec(9933, XDB.table("Skills")[9933]))
	XTianqiBase.PHASE4 = false


## 【cc·T163】法宝读表（D187）：期四开着、天启篇存档时 99 级法宝＝半件 80 级装备（攻击、生命 ×0.5×品质），其余六项 0；
## FABAO_TABLE 关掉或总开关关着照原版每级成长；西游档照原版
func _fabao() -> void:
	var s := _state()
	XTianqiGear.clear_effective_cache()
	var e := XGear.template("armor", 4575)  # 阴阳扇·狂龙：原版每级物攻 +45、生命 +15，品质旧档 8（不朽 1.8）
	e.level = 99.0
	var raw := [XActor.magic_param(e, 0), XActor.magic_param(e, 2), XActor.magic_param(e, 4)]
	XTianqiBase.PHASE4 = true
	var conv := 1.0 + 80.0 * 98.0 / 90.0
	var want_atk := floorf(XTianqiBase.line(conv, "atk") * 0.5 * 1.8)
	var want_hp := floorf(XTianqiBase.line(conv, "mhp") * 0.5 * 1.8)
	var on := [XActor.magic_param(e, 0), XActor.magic_param(e, 2), XActor.magic_param(e, 4), XActor.magic_param(e, 3), XActor.magic_param(e, 1)]
	_check("fabao.table", on[0] == want_hp and on[1] == want_atk and on[2] == 0.0 and on[3] == 0.0 and on[4] == 0.0, [on, want_hp, want_atk])
	var g := XGear.template("armor", 4519)  # 戒指朱：物攻魔攻成长一样大 → 两项都给
	g.level = 99.0
	_check("fabao.tie_both", XActor.magic_param(g, 2) > 0.0 and XActor.magic_param(g, 2) == XActor.magic_param(g, 4))
	var half := e.duplicate()
	half.level = 39.0  # FLOOR_CAP 10 层上限 39 级：等级照旧封顶，读表按等级线性
	_check("fabao.by_level", XActor.magic_param(half, 2) < want_atk and XActor.magic_param(half, 2) > 0.0)
	XTianqiGear.FABAO_TABLE = false
	var back := [XActor.magic_param(e, 0), XActor.magic_param(e, 2), XActor.magic_param(e, 4)]
	XTianqiGear.FABAO_TABLE = true
	_check("fabao.switch_back", back == raw and raw[1] > want_atk * 2.0, [back, raw])
	var other := e.duplicate(true)
	other.etypeId = 5  # T175（T163 甲核 P3-1）：只认法宝栏 etypeId 13，别的栏带 Magic Weapon 备注照原版
	_check("fabao.etype_only", int(e.get("etypeId", 0)) == 13 and [XActor.magic_param(other, 0), XActor.magic_param(other, 2), XActor.magic_param(other, 4)] == raw, [e.get("etypeId"), raw])
	XTianqiBase.PHASE4 = false
	_check("fabao.phase4_off", [XActor.magic_param(e, 0), XActor.magic_param(e, 2), XActor.magic_param(e, 4)] == raw)
	XTianqiBase.PHASE4 = true
	_state(false)
	_check("fabao.xiyou", [XActor.magic_param(e, 0), XActor.magic_param(e, 2), XActor.magic_param(e, 4)] == raw)
	XTianqiBase.PHASE4 = false
	XState.current = s



## 【cc·T163】D189 逐个调角色的覆盖层（skill_rework.json tune.D189）：开着读覆盖后的系数和卡面，TUNE_D189 关掉 reload 后照原卡
func _tune_d189() -> void:
	XTianqiSkills.reload_table()
	var on_coef := float(XTianqiSkills.spec(10727).damage.coef)
	var on_hp := float(XTianqiSkills.spec(7057).damage.stats.mhp)
	var on_atk := float(XTianqiSkills.spec(7057).damage.stats.atk)
	var on_7057 := float(XTianqiSkills.spec(7057).damage.coef)
	var on_rem := [float(XTianqiSkills.spec(5757).damage.coef), float(XTianqiSkills.spec(5757).damage.stats.mhp), float(XTianqiSkills.spec(5759).damage.coef), float(XTianqiSkills.spec(5758).damage.coef), float(XTianqiSkills.spec(508).damage.coef)]
	var on_desc := str(XTianqiSkills.spec(10727).desc)
	XTianqiBase.TUNE_D189 = false
	XTianqiSkills.reload_table()
	var off_coef := float(XTianqiSkills.spec(10727).damage.coef)
	var off_hp := float(XTianqiSkills.spec(7057).damage.stats.mhp)
	var off_desc := str(XTianqiSkills.spec(10727).desc)
	var off_rem := [float(XTianqiSkills.spec(5757).damage.coef), float(XTianqiSkills.spec(5757).damage.stats.mhp), float(XTianqiSkills.spec(5759).damage.coef), float(XTianqiSkills.spec(5758).damage.coef), float(XTianqiSkills.spec(508).damage.coef)]
	XTianqiBase.TUNE_D189 = true
	XTianqiSkills.reload_table()
	# T175（附则 E 系数整数、D194 艾琳 4／508 5、D193 115 三招降）：7057 改成 物攻×2＋生命上限×1%（系数 1）
	# T191（D199 Kyo 11-18）：10727 4→5
	_check("tune_d189.on", on_coef == 5.0 and on_hp == 0.01 and on_atk == 2.0 and on_7057 == 1.0 and on_desc.contains("×5"), [on_coef, on_hp, on_atk, on_7057, on_desc])
	_check("tune_d189.d193_d194", on_rem == [18.0, 0.01, 3.0, 5.0, 5.0] and off_rem == [8.0, 0.03, 1.6, 7.2, 6.0], [on_rem, off_rem])
	_check("tune_d189.switch_back", off_coef == 6.0 and off_hp == 0.0133 and off_desc.contains("×6.0"), [off_coef, off_hp])
	_check("tune_d189.no_note_keys", not XTianqiSkills.spec(10727).has("_note"))
	# 【cc·T191】D200 A：原卡小数系数全表取整（tune.D200，叠在 D189 之后）；TUNE_D200 关掉 reload 后照取整前
	var d200_on := [float(XTianqiSkills.spec(101).damage.coef), float(XTianqiSkills.spec(160).damage.coef), (XTianqiSkills.spec(160).damage.conds as Array).size(), str(XTianqiSkills.spec(101).desc)]
	XTianqiBase.TUNE_D200 = false
	XTianqiSkills.reload_table()
	var d200_off := [float(XTianqiSkills.spec(101).damage.coef), float(XTianqiSkills.spec(160).damage.coef), (XTianqiSkills.spec(160).damage.conds as Array).size(), str(XTianqiSkills.spec(101).desc)]
	var d200_off_10727 := float(XTianqiSkills.spec(10727).damage.coef)
	XTianqiBase.TUNE_D200 = true
	XTianqiSkills.reload_table()
	_check("tune_d200.switch", d200_on.slice(0, 3) == [4.0, 0.45, 0] and str(d200_on[3]).contains("物理攻击×4") and d200_off.slice(0, 3) == [3.6, 0.5, 1] and str(d200_off[3]).contains("×3.6") and d200_off_10727 == 5.0, [d200_on, d200_off, d200_off_10727])
	# 第二批（偏弱超强者调高）：176 贯日 6.0→10、177 棱光 2.5→6（T175 取整；T163 的本体成长 ×1.2 撤掉，开着也是 1）；关掉照原卡
	var d209_was := XTianqiBase.TUNE_D209
	XTianqiBase.TUNE_D209 = false  # T209 R1：D209（超强者按名次重排）又调了 10337／5706 等，D189、D198 两段只看各自的层，D209 层由 xiyou_tianqi_skills p7_d209_table 管
	XTianqiBase.TUNE_D198 = false  # T192：D198 又调了 177 棱光，这段只看 D189 层
	XTianqiSkills.reload_table()
	var on_gr := [float(XTianqiSkills.spec(10315).damage.coef), float(XTianqiSkills.spec(10337).damage.coef), XTianqiBase.actor_mult(177, "mat"), XTianqiBase.actor_mult(176, "atk"), XTianqiBase.actor_mult(108, "mmp")]
	XTianqiBase.TUNE_D189 = false
	XTianqiSkills.reload_table()
	var off_gr := [float(XTianqiSkills.spec(10315).damage.coef), float(XTianqiSkills.spec(10337).damage.coef), XTianqiBase.actor_mult(177, "mat"), XTianqiBase.actor_mult(176, "atk"), XTianqiBase.actor_mult(108, "mmp")]
	XTianqiBase.TUNE_D189 = true
	XTianqiSkills.reload_table()
	_check("tune_d189.raise_on", on_gr == [10.0, 6.0, 1.0, 1.0, 1.0] and str(XTianqiSkills.spec(10337).desc).contains("×6；"), on_gr)  # T175：成长 ×1.2 撤掉、系数取整
	var frac := []
	for sid in (XTianqiSkills.data().get("tune", {}).get("D189", {}).get("skills", {}) as Dictionary).keys():
		var c = XTianqiSkills.spec(int(sid)).get("damage", {}).get("coef", 1)
		if float(c) != floorf(float(c)):
			frac.append([sid, c])
	_check("tune_d189.integer", frac.is_empty(), frac)
	_check("tune_d189.raise_switch_back", off_gr == [6.0, 2.5, 1.0, 1.0, 1.0], off_gr)
	XTianqiBase.TUNE_D198 = true
	XTianqiSkills.reload_table()
	# 【cc·T192】D198 A：偏弱超强者调高（tune.D198，叠在 D200 之后）；超上限的拆段、流萤两招 cap_hits；TUNE_D198 关掉 reload 后照调前
	var ids198 := [10731, 5706, 9938, 10151, 10218, 10263, 10337, 10623, 10622]
	var pick := func() -> Array:
		return ids198.map(func(i): return [float(XTianqiSkills.spec(i).damage.get("coef", 0)), (XTianqiSkills.spec(i).get("seq", []) as Array).filter(func(o): return str(o.get("op", "")) == "split_effects").map(func(o): return int(o.n)), XTianqiSkills.cap_hits(XTianqiSkills.spec(i).damage)])
	var d198_on: Array = pick.call()
	XTianqiBase.TUNE_D198 = false
	XTianqiSkills.reload_table()
	var d198_off: Array = pick.call()
	XTianqiBase.TUNE_D198 = true
	XTianqiSkills.reload_table()
	_check("tune_d198.on", d198_on == [[7.0, [], 1.0], [12.0, [2], 1.0], [1.0, [2], 1.0], [1.0, [3], 1.0], [6.0, [], 1.0], [9.0, [2], 1.0], [8.0, [2], 1.0], [12.0, [], 9.0], [6.0, [], 5.0]], d198_on)
	_check("tune_d198.switch_back", d198_off == [[4.0, [], 1.0], [12.0, [], 1.0], [1.0, [], 1.0], [1.0, [], 1.0], [2.0, [], 1.0], [11.0, [], 1.0], [6.0, [], 1.0], [6.0, [], 1.0], [4.0, [], 1.0]], d198_off)
	var frac198 := []
	for sid in (XTianqiSkills.data().get("tune", {}).get("D198", {}).get("skills", {}) as Dictionary).keys():
		var dm: Dictionary = XTianqiSkills.spec(int(sid)).get("damage", {})
		for v in [dm.get("coef", 1)] + (dm.get("stats", {}) as Dictionary).values():
			if float(v) >= 1.0 and float(v) != floorf(float(v)):
				frac198.append([sid, v])
	_check("tune_d198.integer", frac198.is_empty(), frac198)
	# T192 R1（小A P1-1）：小魔炮六档同组，60%／90% 档跟 30% 档一起调
	var tiers198 := [5703, 5704, 5705].map(func(i): return float(XTianqiSkills.spec(i).damage.coef)) + [5706, 5708, 5709].map(func(i): return (XTianqiSkills.spec(i).get("seq", []) as Array).size())
	_check("tune_d198.cannon_tiers", tiers198 == [2.0, 2.0, 2.0, 1, 1, 1] and str(XTianqiSkills.spec(5692).desc).contains("×4＋魔法上限×14%"), tiers198)
	# cap_hits：卡上 12（九段合计）×流萤角色条件，按每段封不压；没写 cap_hits 的照整招封
	_check("tune_d198.cap_hits", XTianqiSkills.cap_hits({"coef": 12, "cap_hits": 9}) == 9.0 and XTianqiSkills.cap_hits({"coef": 12}) == 1.0)
	XTianqiBase.TUNE_D209 = d209_was
	XTianqiSkills.reload_table()

## 开着但是西游档：全走关着
func _xiyou() -> void:
	XTianqiBase.PHASE4 = true
	var s := _state(false)
	var a: XActor = s.actor(XIAOYAO)
	a.change_level(81)
	_check("xiyou.off", not XTianqiBase.on())
	_check("xiyou.base_curve", is_nan(XTianqiBase.param_base(a, 2)) and is_equal_approx(a.param_base_direct(2), float(a.class_data().params[2][a.level])))
	_check("xiyou.k", XTianqiBase.k_for(a) == 1.0 and XTianqiBase.gaze_row().is_empty())
	_check("xiyou.abs", XTianqiBase.abs_value("item_fixed_heal", 1, 500.0, a, "mhp") == 500.0)
	_check("xiyou.cards", not XTianqiSkills.cards_on())
	XTianqiBase.PHASE4 = false


## 单段上限：开着压回上限、关着不封
func _hit_cap() -> void:
	XTianqiBase.PHASE4 = true
	var s := _state()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var a: XActor = s.actor(XIAOYAO)
	a.change_level(99)
	a.param_mark_dirty()
	var b: XBattler = lg.enemies[0]
	var sk := XDB.rec("Skills", 3632)
	var slow := 1.3 if a.agi < b.agi else 1.0
	_check("cap.within", is_equal_approx(XTianqiSkills.formula(a, b, sk), a.atk * 4.0 * slow), [  # T191（D200）3.6 取整成 4
		XTianqiSkills.formula(a, b, sk), a.atk])
	var row: Dictionary = XTianqiSkills.data().skills["3632"].damage
	var keep := float(row.coef)
	row.coef = 30.0
	_check("cap.clamped", is_equal_approx(XTianqiSkills.formula(a, b, sk), a.atk * 11.0), [XTianqiSkills.formula(a, b, sk), a.atk * 11.0])
	XTianqiBase.PHASE4 = false
	XTianqiSkills.CARDS = true  # 只开卡、总开关关：不封（本体回到职业曲线，敏捷变了，条件重判）
	a.param_mark_dirty()
	var slow2 := 1.3 if a.agi < b.agi else 1.0
	_check("cap.off_unclamped", is_equal_approx(XTianqiSkills.formula(a, b, sk), a.atk * 30.0 * slow2), [XTianqiSkills.formula(a, b, sk), a.atk, slow2])
	XTianqiSkills.CARDS = false
	row.coef = keep
	# 权重口径：寒锋（物攻 1.8＋敏捷 1.8，T191 取整成 2＋2）权重 4，和数据校验同口径
	_check("cap.weight", is_equal_approx(XTianqiSkills.hit_weight(XTianqiSkills.data().skills["3645"].damage), 4.0) and is_equal_approx(XTianqiSkills.hit_weight({"stats": {"atk": 1, "mhp": 0.007}}), 1.175))


## 端到端：每一处结算点开、关各断一次（只改测试里的临时数据，结束复原）
func _e2e(on: bool) -> void:
	var tag := "e2e_on." if on else "e2e_off."
	XTianqiBase.PHASE4 = on
	XTianqiBase.clear_cache()
	var s := _state()
	var a: XActor = s.actor(XIAOYAO)
	a.change_level(81)
	a.param_mark_dirty()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	# （1）双回复药 28：11 回生命认 mhp 那一行、12 回魔法认 mmp 那一行（原来按 id 建索引，mmp 覆盖 mhp）
	var item := XDB.rec("Items", 28)
	var e_hp := XTianqiBase.abs_entry("item_fixed_heal", 28, "mhp")
	var e_mp := XTianqiBase.abs_entry("item_fixed_heal", 28, "mmp")
	_check(tag + "abs_two_rows", not e_hp.is_empty() and not e_mp.is_empty() and float(e_hp.new.pct) != float(e_mp.new.pct), [e_hp, e_mp])
	var seen := {}
	for eff in item.get("effects", []):
		var code := int(eff.code)
		if not code in [11, 12] or float(eff.value2) == 0.0:
			continue
		a.hp = 1.0
		a.mp = 0.0
		var r := {"skill": item}
		lg._effect(a, a, eff, r)
		var got := -float(r.get("hp" if code == 11 else "mp", 0.0))
		var cap := float(a.mhp if code == 11 else a.mmp)
		var v2 := float(eff.value2)
		if on:
			v2 = floorf(cap * float((e_hp if code == 11 else e_mp).new.pct) / 100.0)
		var want := floorf((cap * float(eff.value1) + v2) * a.rec * a.pha)
		seen[code] = true
		_check(tag + "item28_code%d" % code, got == want, [got, want, cap, eff])
	_check(tag + "item28_both", seen.has(11) and seen.has(12), seen)
	# （2）持续伤害 33（常数 300）：开着扣持有者生命上限 4.3%（关波动、元素倍率 1）
	var st := XDB.rec("States", 33)
	var dot: Dictionary = st.get("dot", {})
	var keep_var = dot.get("variance")
	dot["variance"] = 0
	XExtDot.test_hooks = {"element_rate": func(_b, _e): return 1.0}
	a.hp = a.mhp
	a.add_state(33)
	var logs := []
	XExtDot.tick(lg, a, logs)
	var dmg := float(logs[0].hp) if not logs.is_empty() else -1.0
	var want_dot := floorf(float(a.mhp) * 4.3 / 100.0) if on else 300.0
	_check(tag + "ext_dot", dmg == want_dot, [dmg, want_dot, a.mhp, logs.size()])
	a.remove_state(33)
	XExtDot.test_hooks = {}
	if keep_var == null:
		dot.erase("variance")
	else:
		dot["variance"] = keep_var
	# （3）确认阶段：开着回复（3、4）也跳过 ×5——按真实结算比（T214：原来只看表里有没有 3、4，没看出 _active 只对敌人目标跳过）
	var rows := XTianqiNoDiffPassive.confirm_rows(a, [])
	var skip_ok := not rows.is_empty()
	for row in rows:
		var sk: Array = row.effects[0].skipTypes + row.effects[0].get("skipTypesAny", [])
		skip_ok = skip_ok and (sk.has(3) and sk.has(4)) == on
	_check(tag + "confirm_heal_x5", skip_ok, rows)
	var ally: XActor = s.actor(LVSIJI)
	var foe := XEnemy.new().setup(1, 3, 100.0)
	var heal := XDB.rec("Skills", 8)  # HP 回复（type 3）
	var mp_heal := heal.duplicate(true)
	mp_heal.damage.type = 4
	var confused := XDB.rec("Skills", 1)  # HP 伤害（type 1）打自己人
	var ratios := {}
	for pair in [["heal", heal, ally], ["mp_heal", mp_heal, ally], ["heal_self", heal, a], ["heal_foe", heal, foe], ["hit_ally", confused, ally], ["hit_foe", confused, foe]]:
		var r0 := XDamage.calculate(pair[1], a, pair[2], {"critical": false, "variance": false})
		var v0 := float(r0.value)
		var fin := XDamage.apply_state_effects(v0, pair[1], a, pair[2], [], "confirm")
		ratios[pair[0]] = fin / v0 if v0 != 0.0 else NAN
	var x5 := func(r) -> bool: return r > 4.99 and r < 5.01
	var x1 := func(r) -> bool: return r > 0.999 and r < 1.001
	var x6 := func(r) -> bool: return r > 5.9 and r < 6.1
	# 开着：我方回复（打自己人、自己、敌人）都不乘；关着：照乘 ×5（原版难度适应连治疗一起乘）
	for k in ["heal", "mp_heal", "heal_self", "heal_foe"]:
		_check(tag + "confirm_value." + k, x1.call(ratios[k]) if on else x5.call(ratios[k]), ratios)
	# 伤害：打敌人跟去全队 ×6（XTianqiNoX6，O-470，不随期四总开关）走；打自己人（混乱）都 ×6——T214 没动伤害这一支
	_check(tag + "confirm_value.hit_foe", x1.call(ratios.hit_foe) if not XTianqiNoX6.skip_types().is_empty() else x6.call(ratios.hit_foe), ratios)
	_check(tag + "confirm_value.hit_ally", x6.call(ratios.hit_ally), ratios)
	if on:  # 回退：HEAL_SKIP_ALLY = false 照原来——回复并进只对敌人生效的 skipTypes，打自己人照乘 ×5、打敌人不乘
		XTianqiBase.HEAL_SKIP_ALLY = false
		var back := {}
		for pair in [["heal", ally], ["heal_foe", foe]]:
			var v0 := float(XDamage.calculate(heal, a, pair[1], {"critical": false, "variance": false}).value)
			back[pair[0]] = XDamage.apply_state_effects(v0, heal, a, pair[1], [], "confirm") / v0
		XTianqiBase.HEAL_SKIP_ALLY = true
		_check(tag + "confirm_value.rollback", x5.call(back.heal) and x1.call(back.heal_foe), back)
	# （4）九线爆伤合计封顶：装备 0.5＋宝珠 0.2＝0.7，开着封到 0.3（扣 0.4），关着不封
	var by := {"SkETypeHarmRi": {}, "skillTypeDvup": {}, "skillPass": {}, "elementAmplify": {}, "passiveELUP": {}, "globalHarmRi": {},
		"critHarmRi": {"equip": 0.5, "orb": 0.2}, "books": {"globalHarmRi": {}, "critHarmRi": {}, "skillTypeDvup": {}, "SkETypeHarmRi": {}, "skillPass": {}, "elementAmplify": {}, "passiveELUP": {}}}
	var frame := {"normalAdd": 0.0, "finalAdd": 0.0, "criticalAdd": 0.7, "elementAdd": {}}
	var cut := XTianqiLedger.apply_nine_cap(XDB.rec("Skills", 1), a, frame, {"bySource": by}, {})
	var crit_cut := float(cut.get("crit", 0.0))
	_check(tag + "nine_crit_cap", is_equal_approx(crit_cut, 0.4) if on else crit_cut == 0.0, [cut, frame])
	_check(tag + "nine_crit_frame", is_equal_approx(float(frame.criticalAdd), 0.3 if on else 0.7), frame)
	# （5）伤害详情：开着带 gaze（K 本身），关着没有
	var res := XDamage.calculate(XDB.rec("Skills", 1), a, XEnemy.new().setup(1, 3, 100.0), {"critical": false, "variance": false})
	var g = res.breakdown.row.get("gaze")
	_check(tag + "damage_gaze", (g is Dictionary and is_equal_approx(float(g.k), K_TABLE) and str(g.name) == "天启注视") if on else g == null, g)
	# （6）骑士 U：表里先填 1，临时改成 crit 2／no_crit 3 看本体、影子血量跟着乘
	var cr: Dictionary = XTianqiBalance.data().combat_rules
	var keep_u = cr.get("boss_hp_temp_unit")
	var line := "plague"
	var key := "zhengdao"
	XTianqiBase.PHASE4 = false
	var hp0 := float(XTianqiHorsemen.stats(line, key).hp)
	var sh0 := float(XTianqiHorsemen.shadow_stats(line, key).hp)
	XTianqiBase.PHASE4 = on
	cr["boss_hp_temp_unit"] = {"crit": 2.0, "no_crit": 3.0}
	var u := 3.0 if bool(XTianqiHorsemen.knight(line).get("crit_immune", false)) else 2.0
	var hp1 := float(XTianqiHorsemen.stats(line, key).hp)
	var sh1 := float(XTianqiHorsemen.shadow_stats(line, key).hp)
	_check(tag + "knight_u", hp1 == (roundf(hp0 * u) if on else hp0) and sh1 == (roundf(sh0 * u) if on else sh0), [hp0, hp1, sh0, sh1, u])
	if keep_u == null:
		cr.erase("boss_hp_temp_unit")
	else:
		cr["boss_hp_temp_unit"] = keep_u
	# （8）绕过结算直接扣敌人血（scale_direct）：开着再乘 K；反弹（gaze＝false）不乘
	var en: XBattler = lg.enemies[0]
	var base6 := maxf(1.0, floorf(600.0 * XTianqiNoX6.hp_unit())) if XTianqiNoX6.on() else 600.0
	var want_k := maxf(1.0, floorf(base6 * K_TABLE)) if on else base6
	_check(tag + "scale_direct_k", XTianqiNoX6.scale_direct(a, en, 600.0) == want_k and XTianqiNoX6.scale_direct(a, en, 600.0, false) == base6 \
		and XTianqiNoX6.scale_direct(en, a, 600.0) == 600.0, [XTianqiNoX6.scale_direct(a, en, 600.0), want_k, base6])
	# （7）表外角色：开着也回落职业曲线
	var out_id := 0
	for id in range(1, 400):
		if not XDB.rec("Actors", id).is_empty() and str(XDB.rec("Actors", id).get("name", "")) != "" and not XTianqiBase.has_actor(id):
			out_id = id
			break
	if out_id > 0:
		XTianqi._joining = true
		s.add_actor(out_id)
		XTianqi._joining = false
		var o: XActor = s.actor(out_id)
		o.change_level(50)
		_check(tag + "out_of_table", is_nan(XTianqiBase.param_base(o, 2)) and is_equal_approx(o.param_base_direct(2), float(o.class_data().params[2][o.level])), [out_id, o.param_base_direct(2)])
	else:
		_check(tag + "out_of_table_found", false, "表外角色没找到")
	XTianqiBase.PHASE4 = false


## 【cc·T220 R1】小A P2-3：三开关（期四、熟练度、烙印）全开＋七印＋词条，真跑两回合（start_turn → 逐个 decide/act → end_turn）。
## 只查跑得通：没有脚本卡死、我方 K 那一项＝表里的 K×烙印、敌人掉血、没有负生命
func _joint_smoke() -> void:
	XTianqiBase.PHASE4 = true
	XTianqiSkills.MASTERY = true
	XTianqiBrand.ENABLED = true
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	var s := _state()
	var a: XActor = s.actor(XIAOYAO)
	a.change_level(81)
	XZhenqi.data(a)
	a.zhenqi["brand_carved"] = 1
	a.zhenqi["brand_realm"] = XTianqiBrand.last_realm()
	a.zhenqi["brand"] = 100 * XTianqiBrand.scale()
	a.keep_unequippable = true
	var w := XGear.create("weapon", 1, s)
	if w.is_empty():
		w = {"kind": "weapon", "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 1}
	XTianqiQiyinEffects.mark(w, {"kind": "weapon", "seal": "bai", "wtype": "hidden"})
	a.equips[0] = w
	a.equips[1] = {"kind": "armor", "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3,
		"tianqi_affixes": [{"key": "lifesteal", "tier": 4, "grade": "perfect", "extra": {}}, {"key": "expose", "tier": 4, "grade": "normal", "extra": {}}]}
	for id in s.party:
		s.actor(id).param_mark_dirty()
		s.actor(id).recover_all()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var k_ok := is_equal_approx(float(XTianqiCombat.dealt_parts(a, s).k), XTianqiBase.k_base(s) * 1.5)
	var hp0: float = lg.enemies.reduce(func(acc, e): return acc + e.hp, 0.0)
	var acted := 0
	for round_i in 2:
		if lg.is_over():
			break
		lg.start_turn()
		var guard := 0
		while not lg.is_over() and guard < 40:
			guard += 1
			var u = lg.next_subject()
			if u == null:
				break
			var cmd: Array = lg.decide(u)
			lg.act(u, cmd[0], cmd[1])
			acted += 1
		if not lg.is_over():
			lg.end_turn()
	var hp1: float = lg.enemies.reduce(func(acc, e): return acc + e.hp, 0.0)
	var neg := (lg.actors + lg.enemies).filter(func(b): return float(b.hp) < 0.0)
	_check("joint_smoke", XTianqiSkills.cards_on(s) and XTianqiSkills.mastery_on() and XTianqiBrand.on(s) and k_ok and acted >= 4 and hp1 < hp0 and neg.is_empty(),
		[XTianqiSkills.cards_on(s), XTianqiSkills.mastery_on(), XTianqiBrand.on(s), k_ok, acted, hp0, hp1, neg.size()])
	lg.end_battle(0)
