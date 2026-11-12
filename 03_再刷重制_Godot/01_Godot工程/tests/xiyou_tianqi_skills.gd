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
	_check("defaults", not XTianqiSkills.CARDS and not XTianqiSkills.MASTERY and XTianqiSkills.ACTION_CAP and XTianqiSkills.TIERS)
	_default_off()
	XTianqiSkills.CARDS = true  # 角色卡、熟练度默认关（等数值线），专项打开测
	XTianqiSkills.MASTERY = true
	_tiers()
	_records()
	_damage()
	_mastery()
	_actions()
	_table()
	_states()
	_follow()
	_gear()
	_xinfa()
	_smoke()
	_switches()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 默认（角色卡、熟练度关）：天启篇存档也照原版技能和熟练度
func _default_off() -> void:
	var s := _state()
	_check("default_record", str(XDB.rec("Skills", 101).damage.formula).begins_with("250+"))
	XSkillMastery.set_level(s.actor(XIAOYAO), 101, 50)
	_check("default_mastery", XSkillMastery.level(s.actor(XIAOYAO), 101) == 50)
	_check("default_tiers_on", XTianqiSkills.tier_of(96) == XTier.STRONG)
	XState.current = XState.new()


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


## 表里每一行：天启篇存档里改写生效、伤害行算得出正数、冷却和 TP 对得上
func _table() -> void:
	var s := _state()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var b := _enemy(lg)
	var a: XActor = s.actor(XIAOYAO)
	a.change_level(99)
	var bad := []
	for k in XTianqiSkills.data().skills:
		var id := int(k)
		var sp: Dictionary = XTianqiSkills.spec(id)
		var r := XDB.rec("Skills", id)
		if r.is_empty():
			bad.append([id, "empty"])
			continue
		if sp.has("damage") or sp.has("heal"):
			if str(r.damage.formulaProgram.get("module", "")) != XTianqiSkills.MODULE:
				bad.append([id, "module"])
			var v := XTianqiSkills.formula(a, b if sp.has("damage") else a, r)
			if is_nan(v) or is_inf(v) or (sp.has("damage") and v <= 0.0):
				bad.append([id, "value", v])
		if sp.has("cooldown") and str(r.meta.get("Cooldown", "")).strip_edges() != str(int(sp.cooldown)):
			bad.append([id, "cooldown", r.meta.get("Cooldown")])
		if sp.has("tp") and int(r.tpCost) != int(sp.tp):
			bad.append([id, "tp"])
		if sp.has("mp_pct") and not is_equal_approx(float(XBattleLogic.note_costs(r).get("mpCostPer", -1.0)), float(sp.mp_pct) / 100.0):
			bad.append([id, "mp_pct"])
		for tag in sp.get("note_remove", []):
			if RegEx.create_from_string("<\\s*(?:%s)\\s*(?::[^>]*)?>" % str(tag)).search(str(r.note).replace(str(sp.get("note_add", "")), "")) != null:
				bad.append([id, "note_remove", tag])
	_check("table_rows", bad.is_empty(), bad)
	var effects := func(id, base := false): return ((XDB.table("Skills")[id] if base else XDB.rec("Skills", id)).yepSeq.target as Array).filter(func(c): return str(c[0]) == "action effect").size()
	_check("seq_add", effects.call(379) == 6 and effects.call(379, true) == 5, [effects.call(379), effects.call(379, true)])
	_check("seq_drop_if", effects.call(506) == 3 and effects.call(506, true) == 5, [effects.call(506), effects.call(506, true)])
	_check("seq_if_to_effects", effects.call(521) == 6, effects.call(521))
	_check("seq_clear_args", (XDB.rec("Skills", 821).yepSeq.target as Array).all(func(c): return str(c[0]) != "action effect" or (c[1] as Array).is_empty()) and effects.call(821) == 6)
	_check("change_to_removed", not str(XDB.rec("Skills", 223).note).contains("ChangeTo["))
	_check("table_rows_count", XTianqiSkills.data().skills.size() >= 100, XTianqiSkills.data().skills.size())
	lg.end_battle(0)


## 状态改写：碎甲 −10%、冰冷 −20%、领域按比例；原版档照旧
func _states() -> void:
	var s := _state()
	var st := XDB.rec("States", 12)
	_check("state_traits", st.traits.size() == 1 and int(st.traits[0].code) == 21 and is_equal_approx(float(st.traits[0].value), 0.9) and not str(st.note).contains("def = -10") and int(st.maxTurns) == 3, st.traits)
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var b: XActor = s.actor(XIAOYAO)
	b.param_mark_dirty()
	var agi0 := b.agi
	b.add_state(26)
	b.param_mark_dirty()
	_check("state_rate_applies", b.state_ids.has(26) and absf(b.agi - agi0 * 0.8) <= 1.0, [agi0, b.agi, b.state_ids])
	b.remove_state(26)
	lg.end_battle(0)
	_state(false)
	_check("state_legacy", XDB.rec("States", 12).traits.is_empty() and str(XDB.rec("States", 12).note).contains("def = -10"))


## 追加释放：艾坤学了篮球之神，大灌篮后 50%（鲲稚啸天 100%）追加球来；每回合最多一次
func _follow() -> void:
	var s := _state()
	var a: XActor = s.actor(XIAOYAO)
	var dunk := XDB.rec("Skills", 506)
	_check("follow_none", XTianqiSkills._follow_of(a, dunk).is_empty())
	a.learn_skill(1235)
	var f := XTianqiSkills._follow_of(a, dunk)
	_check("follow_half", f.size() == 1 and int(f[0][0].id) == 4370 and is_equal_approx(float(f[0][1]), 0.5), f.size())
	a.learn_skill(3514)
	f = XTianqiSkills._follow_of(a, dunk)
	_check("follow_full", f.size() == 1 and is_equal_approx(float(f[0][1]), 1.0))
	_check("dunk_no_ce", not XDB.rec("Skills", 506).effects.any(func(e): return int(e.code) == 44))
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var b := _enemy(lg)
	XTianqiSkills.begin_action(lg, a, dunk)
	XTianqiSkills.after_apply(lg, a, dunk, b)
	var logs := XTianqiSkills.end_action(lg, a, dunk)
	_check("follow_cast", logs.size() == 2 and int(logs[0].skill.id) == 4370, logs.size())
	XTianqiSkills.begin_action(lg, a, dunk)
	XTianqiSkills.after_apply(lg, a, dunk, b)
	_check("follow_once_per_turn", XTianqiSkills.end_action(lg, a, dunk).is_empty())
	lg.end_battle(0)


## 把专属装备穿到对应栏位（按装备类型找第一个同类栏）
func _wear(a: XActor, kind: String, base: int) -> Dictionary:
	var eq := XActor.make_equip(kind, base)
	var slots := a.equip_slots()
	for i in slots.size():
		if int(slots[i]) == (1 if kind == "weapon" else int(eq.get("etypeId", -1))):
			a.equips[i] = eq
			break
	a.param_mark_dirty()
	a.refresh_passive()
	return eq


## 专属法宝、武器：天启篇换改写视图（紫电承伤 −10%，原来的固定减伤去掉）；原版档、卡关时原样
func _gear() -> void:
	var s := _state()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var a: XActor = s.actor(XIAOYAO)
	var pdr0 := a.sparam(6)
	var eq := _wear(a, "armor", 3672)
	var view: Dictionary = XTianqiGear.stat_list(a.equip_list()).filter(func(e): return int(e.get("base", 0)) == 3672)[0]
	_check("gear_view", not str(view.note).contains("passiveHarmRe") and view.traits.any(func(t): return int(t.code) == 23 and int(t.dataId) == 6 and is_equal_approx(float(t.value), 0.9)) and str(eq.note).contains("passiveHarmRe"), view.traits)
	_check("gear_sparam", is_equal_approx(a.sparam(6), pdr0 * 0.9), [pdr0, a.sparam(6)])
	_check("gear_passive_cache", a.passive_cache().harmRe.is_empty(), a.passive_cache().harmRe)
	var rows := XHelpCard.content(eq)
	_check("gear_help", JSON.stringify(rows).contains("受到的伤害-10%") and not JSON.stringify(rows).contains("-3000"))
	_check("gear_owns", XTianqiSkills.owns(a, "e3672") and not XTianqiSkills.owns(a, "e4512") and XTianqiSkills.owns(a, float(a.skill_ids[0])))
	var w := _wear(a, "weapon", 1687)
	var wv: Dictionary = XTianqiSkills.gear_view(w)
	_check("gear_weapon", str(wv.note).contains("<SkillPass3632: 20%>") and not str(wv.note).contains("250%") and wv.traits.any(func(t): return int(t.code) == 21 and int(t.dataId) == 6 and is_equal_approx(float(t.value), 0.8)), wv.traits)
	XTianqiSkills.CARDS = false
	_check("gear_cards_off", is_same(XTianqiSkills.gear_view(eq), eq))
	XTianqiSkills.CARDS = true
	# 冰音：吃我一痔挂上的冰冷多 1 回合
	var sk := XDB.rec("Skills", 2770)
	lg.end_battle(0)
	var s5 := XTianqi.start_new_game(3, "jianxian", [5, 7, 13, 29, 1])
	XTianqi.take_pending()
	for id in [5, 7, 13, 29, 1]:
		XTianqi._joining = true
		s5.add_actor(id)
		XTianqi._joining = false
	s5.map_id = 4
	XState.current = s5
	lg = XBattleLogic.new()
	lg.setup(2, s5)
	var b := _enemy(lg)
	var x5: XActor = s5.actor(5)
	_wear(x5, "armor", 3674)
	b.add_state(26)
	var t0 := int(b.state_turns.get(26, 0))
	XTianqiSkills.begin_action(lg, x5, sk)
	XTianqiSkills.after_apply(lg, x5, sk, b)
	XTianqiSkills.after_apply(lg, x5, sk, b)
	_check("on_hit_extend", t0 == 2 and int(b.state_turns.get(26, 0)) == 3, [t0, b.state_turns.get(26)])
	XTianqiSkills.end_action(lg, x5, sk)
	# 茉蕾音叉：治疗 +10%
	var x7: XActor = s5.actor(7)
	_check("heal_mult_off", XTianqiSkills.damage_ops(XDB.rec("Skills", 108), x7, x7).is_empty())
	_wear(x7, "armor", 3614)
	var ops := XTianqiSkills.damage_ops(XDB.rec("Skills", 108), x7, x7)
	_check("heal_mult", ops.size() == 1 and str(ops[0].field) == "healingMultiplier" and is_equal_approx(float(ops[0].value), 1.1), ops)
	# 金蝉子九锡拳套：开局佛陀真身 2 回合
	var x29: XActor = s5.actor(29)
	x29.add_state(66)
	x29.equips[0] = XActor.make_equip("weapon", 1529)  # 挂状态会刷新装备（测试角色等级不够穿），所以挂完再直接放进武器栏
	XTianqiSkills.start_turns([x29])
	_check("start_turns", int(x29.state_turns.get(66, 0)) == 2, x29.state_turns.get(66))
	lg.end_battle(0)
	_state(false)
	var legacy := XActor.make_equip("armor", 3672)
	_check("gear_legacy", is_same(XTianqiSkills.gear_view(legacy), legacy))


## 心法：变体技能有行、诛心无视双防、坐忘痔霄①对减速目标必暴
func _xinfa() -> void:
	var s := _state()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var a: XActor = s.actor(XIAOYAO)
	var b := _enemy(lg)
	a.change_level(99)
	var base := XTianqiSkills.formula(a, b, XDB.rec("Skills", 4748))
	_check("xinfa_pohun", is_equal_approx(XTianqiSkills.formula(a, b, XDB.rec("Skills", 4749)), base * 1.5), [base])
	var ops := XTianqiSkills.damage_ops(XDB.rec("Skills", 4751), a, b)
	_check("xinfa_pierce", ops.size() == 2 and is_equal_approx(float(ops[0].value), 0.7), ops)
	_check("xinfa_pierce_none", XTianqiSkills.damage_ops(XDB.rec("Skills", 4748), a, b).is_empty())
	var sk := XDB.rec("Skills", 4762)
	_check("xinfa_crit_plain", is_equal_approx(XTianqiSkills.item_cri(a, sk, b, 0.1), 0.1))
	b.add_state(26)
	_check("xinfa_crit_slow", is_equal_approx(XTianqiSkills.item_cri(a, sk, b, 0.1), 1.0))
	b.remove_state(26)
	_check("xinfa_note", str(XDB.rec("Skills", 4723).note).contains("<passivePBST6:-30%>") and not str(XDB.rec("Skills", 4723).note).contains("-1500"))
	var ten := XDB.rec("Skills", 4774)
	_check("xinfa_follow_oil", not str(ten.note).contains("ChangeTo[4775]") and int(XTianqiSkills.spec(4774).follow[0].cast) == 4775)
	lg.end_battle(0)


## 改过卡的角色整场跑几回合不报错
func _smoke() -> void:
	for group in [[3, 4, 5, 6, 7], [8, 9, 10, 11, 12], [13, 14, 15, 1, 2], [16, 17, 18, 19, 20], [21, 22, 23, 24, 25], [26, 27, 28, 29, 30]]:
		_smoke_group(group)


func _smoke_group(group: Array) -> void:
	var s := XTianqi.start_new_game(3, "jianxian", group)
	XTianqi.take_pending()
	for id in group:
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in group:
		var a: XActor = s.actor(id)
		a.change_level(60)
		for sid in XTianqiSkills.data().skills:
			if int(XTianqiSkills.spec(int(sid)).get("actor", 0)) == id:
				a.learn_skill(int(sid))
		for gk in XTianqiSkills.data().get("gear", {}):
			var kb := str(gk).split(":")
			var rec := XDB.rec("Weapons" if kb[0] == "weapon" else "Armors", int(kb[1]))
			if str(rec.get("note", "")).contains("<req_actors: %04d>" % id):
				_wear(a, kb[0], int(kb[1]))
		a.recover_all()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var t0 := lg.turn
	for k in 4:
		if lg.is_over():
			break
		lg.run_turn({})
	_check("smoke_turns_%s" % group[0], lg.turn > t0, lg.turn)
	lg.end_battle(0)
