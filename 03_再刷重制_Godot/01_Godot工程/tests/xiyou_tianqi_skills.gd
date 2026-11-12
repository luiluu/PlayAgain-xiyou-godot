extends Node
## 天启篇全角色技能重构（XTianqiSkills）第一期专项：
## 一、档位名单：超强者 16 人（轮回者·里德、五条悟另算）、强者 52 人、不开放的不进候选池；三笠跟锻炼和进阶、饿狼跟形态升档；名单按天启篇、原版档照 XTier。
## 二、技能记录：天启篇存档里 XDB.rec 换成改写后的副本（TP、MP 比例、冷却、效果、被动标签、说明），原版档原样。
## 三、伤害：属性×满级系数×等级缩放（1 级一半）×条件（敏捷低于目标、愤怒中的敌人）；复活回生命上限比例；走 XFormulaExecution 结果一致。
## 四、熟练度：每级 +3%、上限 10 级，公式里的熟练度读 0。
## 五、行动次数：角色每回合最多多 1 次，敌人不管。
## 六、开关：ENABLED 关掉整套回原版。

const XIAOYAO := 1
const LVSIJI := 2
const MIKASA := 95
const GAROU := 173
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XTianqiSkills.reload()
	_tiers()
	_records()
	_damage()
	_mastery()
	_actions()
	_switches()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _weak_ids() -> Array:
	return XTianqiSkills.ids(XTier.WEAK, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


## 天启篇存档（阵容固定：狗逍遥、绿司机＋三个弱者）
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


func _tiers() -> void:
	var sup := XTianqiSkills.ids(XTier.SUPER, true)
	var strong := XTianqiSkills.ids(XTier.STRONG, true)
	_check("tier_super_16", sup.size() == 16 and sup.has(MIKASA) and sup.has(122) and not sup.has(96), sup)
	_check("tier_strong_52", strong.size() == 52 and strong.has(96) and strong.has(XIAOYAO) and not strong.has(8), strong.size())
	_check("tier_demoted_weak", XTianqiSkills.tier_of(8, true) == XTier.WEAK and XTianqiSkills.tier_of(141, true) == XTier.WEAK and XTianqiSkills.tier_of(11, true) == XTier.WEAK)
	_check("tier_hidden", XTianqiSkills.tier_of(110, true) == "" and not XTianqiSkills.ids(XTier.STRONG, true).has(110) and not XTianqiSkills.ids(XTier.WEAK, true).has(110))
	var p := XTianqi.pool("lianyu")
	_check("pool_uses_list", p[XTier.SUPER].has(MIKASA) and not p[XTier.SUPER].has(96) and p[XTier.STRONG].has(96) and not (p[XTier.STRONG] + p[XTier.WEAK]).has(110))
	_check("legacy_list_untouched", XTianqiSkills.tier_of(96) == XTier.tier_of(96))  # 当前不是天启篇存档、不 force：照 XTier
	var s := _state()
	s.set_variable(1490, 0)
	_check("mikasa_untrained_weak", XTianqiSkills.battle_tier(MIKASA, s) == XTier.WEAK)
	s.set_variable(1490, 10)
	_check("mikasa_trained_strong", XTianqiSkills.battle_tier(MIKASA, s) == XTier.STRONG)
	s.actor_advance[MIKASA] = 4
	_check("mikasa_advanced_super", XTianqiSkills.battle_tier(MIKASA, s) == XTier.SUPER)
	var g := []
	for r in [0, 1, 2, 3, 4, 6]:
		s.actor_advance[GAROU] = r
		g.append(XTianqiSkills.battle_tier(GAROU, s))
	_check("garou_forms", g == [XTier.WEAK, XTier.WEAK, XTier.STRONG, XTier.STRONG, XTier.SUPER, XTier.SUPER], g)
	_check("battle_tier_plain", XTianqiSkills.battle_tier(XIAOYAO, s) == XTier.STRONG and XTianqiSkills.battle_tier(LVSIJI, s) == XTier.WEAK)
	var a: XActor = s.actor(XIAOYAO)
	_check("combat_reads_list", is_equal_approx(float(XTianqiCombat.dealt_parts(a, s).get("tier", 0.0)), 1.5))


func _records() -> void:
	_state(false)
	var legacy := XDB.rec("Skills", 101)
	_check("legacy_record", int(legacy.tpCost) == 10 and str(legacy.damage.formula).begins_with("250+"), legacy.damage.formula)
	_check("legacy_cooldown_none", XDB.rec("Skills", 3632).get("meta", {}).get("Cooldown") == null)
	_state()
	var r := XDB.rec("Skills", 101)
	_check("rec_module", str(r.damage.formulaProgram.get("module", "")) == XTianqiSkills.MODULE and int(r.tpCost) == 10)
	_check("rec_cached", is_same(r, XDB.rec("Skills", 101)))
	_check("rec_base_untouched", str(XDB.table("Skills")[101].damage.formula).begins_with("250+"))
	var wj := XDB.rec("Skills", 160)
	_check("mp_pct", int(wj.mpCost) == 0 and is_equal_approx(float(XBattleLogic.note_costs(wj).get("mpCostPer", 0.0)), 0.05), XBattleLogic.note_costs(wj))
	_check("tp_rewrite", int(XDB.rec("Skills", 311).tpCost) == 30 and int(XDB.rec("Skills", 502).tpCost) == 50)
	_check("cooldown", str(XDB.rec("Skills", 3632).meta.get("Cooldown", "")).strip_edges() == "6" and str(XDB.rec("Skills", 504).meta.get("Cooldown", "")).strip_edges() == "3")
	var anger: Array = XDB.rec("Skills", 102).effects.filter(func(e): return int(e.code) == 21 and int(e.dataId) == 7)
	_check("effect_value", anger.size() == 1 and is_equal_approx(float(anger[0].value1), 0.1))
	var revive := XDB.rec("Skills", 313)
	var hp_fx: Array = revive.effects.filter(func(e): return int(e.code) == 11)
	var tp_fx: Array = revive.effects.filter(func(e): return int(e.code) == 13)
	_check("revive_effects", float(hp_fx[0].value2) == 0.0 and float(tp_fx[0].value1) == 30.0 and int(revive.mpCost) == 0)
	var ring: Dictionary = XDB.rec("Skills", 746).meta
	_check("passive_tags", str(ring.get("passiveELUP06", "")) == "10%" and not ring.has("passiveHarmRi") and ring.has("passiveSTREG006") and str(ring.get("passiveXPBST1", "")) == "5%", ring.keys())
	var limit: Dictionary = XDB.rec("Skills", 1240).meta
	_check("advance_shared", str(limit.get("passiveHarmRi", "")) == "5" and str(limit.get("passivePBST0", "")) == "5%" and not limit.has("passivePBST2"))
	var awake: Dictionary = XDB.rec("Skills", 1746).meta
	_check("awake_no_skillpass", not awake.keys().any(func(k): return str(k).begins_with("SkillPass")) and str(awake.get("passiveELUP01", "")) == "10%")
	var lead: Dictionary = XDB.rec("Skills", 2772).meta
	_check("leader", not lead.has("passiveAPLUS") and not lead.has("AgainUseAll") and str(lead.get("passiveXPBST7", "")) == "5%")
	var note := str(XDB.rec("Skills", 3632).note)
	_check("desc_lines", note.contains("物理攻击×10.8") and not note.contains("*12*") and note.contains("冷却时间:6回合"), note.substr(0, 200))
	var a: XActor = XState.current.actor(XIAOYAO)
	a.learn_skill(2746)
	a.param_mark_dirty()
	_check("actor_passive_read", a.passive_values("passiveELUP01").has("10%"), a.passive_values("passiveELUP01"))


func _enemy(lg: XBattleLogic) -> XBattler:
	return lg.enemies[0]


func _damage() -> void:
	var s := _state()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var a: XActor = s.actor(XIAOYAO)
	var b := _enemy(lg)
	a.change_level(99)
	var sk := XDB.rec("Skills", 101)
	_check("dmg_full", is_equal_approx(XTianqiSkills.formula(a, b, sk), a.atk * 3.6), [XTianqiSkills.formula(a, b, sk), a.atk])
	var via: Dictionary = XFormulaExecution.run_item(sk, a, b, s.variables if "variables" in s else {})
	_check("dmg_pipeline", via.available and is_equal_approx(float(via.value), a.atk * 3.6), via)
	a.change_level(1)
	_check("dmg_level1_half", is_equal_approx(XTianqiSkills.formula(a, b, sk), a.atk * 1.8))
	a.change_level(50)
	_check("dmg_level_mid", is_equal_approx(XTianqiSkills.formula(a, b, sk), a.atk * 3.6 * (0.5 + 0.5 * 49.0 / 98.0)))
	a.change_level(99)
	var one := XDB.rec("Skills", 3632)
	var slow := a.agi < b.agi
	_check("cond_agi", is_equal_approx(XTianqiSkills.formula(a, b, one), a.atk * 10.8 * (1.3 if slow else 1.0)))
	var c: XActor = s.actor(LVSIJI)
	c.change_level(99)
	var hat := XDB.rec("Skills", 102)
	b.add_state(7)
	var plain := XTianqiSkills.formula(c, b, hat)
	c.learn_skill(3792)
	var angry := XTianqiSkills.formula(c, b, hat)
	_check("cond_anger", is_equal_approx(plain, c.mat * 2.5) and is_equal_approx(angry, c.mat * 2.5 * 1.2), [plain, angry, c.mat])
	b.remove_state(7)
	_check("cond_anger_off", is_equal_approx(XTianqiSkills.formula(c, b, hat), c.mat * 2.5))
	var rev := XDB.rec("Skills", 313)
	_check("revive_heal", is_equal_approx(XTianqiSkills.formula(c, a, rev), -a.mhp * 0.3))
	lg.end_battle(0)


func _mastery() -> void:
	var s := _state()
	var a: XActor = s.actor(XIAOYAO)
	var sk := XDB.rec("Skills", 101)
	XSkillMastery.set_level(a, 101, 5)
	_check("mastery_3pct", is_equal_approx(XSkillMastery.damage(sk, a, 100.0), 115.0), XSkillMastery.damage(sk, a, 100.0))
	XSkillMastery.set_level(a, 101, 50)
	_check("mastery_cap10", XSkillMastery.level(a, 101) == 10 and is_equal_approx(XSkillMastery.damage(sk, a, 100.0), 130.0))
	# 公式里的熟练度读 0：旋转斩击 8119 的原公式乘 (1＋熟练度)，天启篇不再乘
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var spin := XDB.rec("Skills", 8119)
	var v0: float = XFormulaExecution.run_item(spin, a, lg.enemies[0], {}).value
	XSkillMastery.set_level(a, 8119, 3)
	var v3: float = XFormulaExecution.run_item(spin, a, lg.enemies[0], {}).value
	_check("formula_mastery_zero", is_equal_approx(v0, v3), [v0, v3])
	lg.end_battle(0)
	_state(false)
	var b: XActor = XState.current.actor(XIAOYAO)
	XSkillMastery.set_level(b, 101, 50)
	_check("legacy_mastery_uncapped", XSkillMastery.level(b, 101) == 50)


func _actions() -> void:
	var s := _state()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var a: XActor = s.actor(XIAOYAO)
	_check("cap_actor", XTianqiSkills.cap_actions(a, 3) == 2 and XTianqiSkills.cap_actions(a, 1) == 1)
	_check("cap_enemy_free", XTianqiSkills.cap_actions(_enemy(lg), 3) == 3)
	_check("make_action_times_ok", lg.make_action_times(a) <= 2)
	lg.end_battle(0)
	_state(false)
	_check("cap_legacy_free", XTianqiSkills.cap_actions(XState.current.actor(XIAOYAO), 3) == 3)


func _switches() -> void:
	XTianqiSkills.ENABLED = false
	var s := _state()
	_check("off_record", str(XDB.rec("Skills", 101).damage.formula).begins_with("250+"))
	_check("off_tier", XTianqiSkills.tier_of(96, true) == XTier.tier_of(96) and XTianqiSkills.battle_tier(MIKASA, s) == XTier.tier_of(MIKASA))
	_check("off_cap", XTianqiSkills.cap_actions(s.actor(XIAOYAO), 3) == 3)
	XSkillMastery.set_level(s.actor(XIAOYAO), 101, 50)
	_check("off_mastery", XSkillMastery.level(s.actor(XIAOYAO), 101) == 50)
	XTianqiSkills.ENABLED = true
	XTianqiSkills.MASTERY = false
	_check("mastery_switch", not XTianqiSkills.mastery_on() and XTianqiSkills.on())
	XTianqiSkills.MASTERY = true
