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
	XGojo.unlock_override = 0  # 五条悟没解锁最强之名（不读本机配置）：超强者照 16 人
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
	_buzhao()
	_p3()
	_p4()
	_p5()
	_p6()
	_fill()
	_fill_charge()
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
	XGojo.unlock_override = 1
	_check("tier_super_gojo_unlocked", XTianqiSkills.ids(XTier.SUPER, true).size() == 17 and XTianqiSkills.ids(XTier.SUPER, true).has(XGojo.ACTOR))
	XGojo.unlock_override = 0
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


## 补招：表外号段按底号复制、按角色等级学会；原版档不学、Skills 表本身不变
func _buzhao() -> void:
	var size0: int = (XDB.table("Skills") as Array).size()
	var s := XTianqi.start_new_game(3, "jianxian", [8, 16, 21, 22, 1])
	XTianqi.take_pending()
	for id in [8, 16, 21, 22, 1]:
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	var r := XDB.rec("Skills", 10701)
	_check("new_rec", str(r.get("name", "")) == "因果审判" and int(r.id) == 10701 and str(r.damage.formulaProgram.get("module", "")) == XTianqiSkills.MODULE and not str(r.note).contains("ChangeTo["), r.get("name"))
	_check("new_table_untouched", (XDB.table("Skills") as Array).size() == size0 and size0 < 10701, size0)
	var x: XActor = s.actor(8)
	x.change_level(29)
	_check("learn_before", not x.skill_ids.has(10701))
	x.change_level(30)
	_check("learn_at_30", x.skill_ids.has(10701))
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var b := _enemy(lg)
	_check("new_damage", XTianqiSkills.formula(x, b, r) > 0.0)
	_check("new_heal", XTianqiSkills.formula(s.actor(16), s.actor(16), XDB.rec("Skills", 10706)) < 0.0 and int(XDB.rec("Skills", 10706).scope) == 7)
	var w: XActor = s.actor(22)
	w.change_level(30)
	_check("learn_move", w.skill_ids.has(3768))
	var m: XActor = s.actor(21)
	XTianqiSkills.CARDS = false
	m.change_level(25)
	XTianqiSkills.CARDS = true
	_check("learn_cards_off", not m.skill_ids.has(10707))
	XTianqiSkills.sync_learn(m)
	_check("learn_sync", m.skill_ids.has(10707))
	lg.end_battle(0)
	var legacy := _state(false)
	legacy.add_actor(8)
	var y: XActor = legacy.actor(8)
	y.change_level(30)
	_check("learn_legacy", not y.skill_ids.has(10701))


## 改过卡的角色整场跑几回合不报错
## 第三期（31～60 号）新加的能力：新状态、层数持续伤害、本场次数、序列改写、免生命消耗、取高、TP、诅咒数、状态数、物攻比较、按已学技能补学、真火半伤、开场 TP
func _p3() -> void:
	var s := XTianqi.start_new_game(3, "jianxian", [31, 34, 38, 51, 58])
	XTianqi.take_pending()
	for id in [33, 34, 37, 38, 43, 52, 54, 58, 59]:
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	var st := XDB.rec("States", 10801)
	_check("p3_new_state", str(st.get("name", "")) == "长恨" and int(st.get("id", 0)) == 10801 and int(st.maxTurns) == 2 and str(st.note).contains("passiveCrHarmRi:10"), st.get("name"))
	_check("p3_dot_remove", not XDB.rec("States", 55).has("dot") and XDB.table("States")[55].has("dot"))
	var b106 := XDB.rec("States", 106)
	_check("p3_dot_tianqi", str(b106.get("dot", {}).get("kind", "")) == "tianqi" and not b106.has("effects"), b106.get("dot"))
	var seq := func(id): return (XDB.rec("Skills", id).yepSeq.target as Array)
	var fx := func(id): return (seq.call(id) as Array).filter(func(c): return str(c[0]) == "action effect")
	_check("p3_drop_cmd", not (seq.call(1340) as Array).any(func(c): return str(c[0]) == "Add State 942") and (fx.call(1340) as Array).size() == 9, (fx.call(1340) as Array).size())
	_check("p3_replace_cmd", (seq.call(1067) as Array).any(func(c): return str(c[0]) == "Hp -1%") and not (seq.call(1067) as Array).any(func(c): return str(c[0]) == "Hp -3%"))
	_check("p3_keep_effects", (fx.call(10710) as Array).size() == 1 and (fx.call(2067) as Array).size() == 5)
	_check("p3_drop_area", (fx.call(1212) as Array).all(func(c): return (c[1] as Array).is_empty()))
	var in_w := 0
	var on := false
	for c in seq.call(1098):
		if str(c[0]).begins_with("if ") and str(c[0]).contains("dataWeapons[1527]"):
			on = true
		elif str(c[0]) == "end":
			on = false
		elif on and str(c[0]) == "action effect":
			in_w += 1
	_check("p3_if_keep", in_w == 1, in_w)
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var b := _enemy(lg)
	# 层数持续伤害：曹操霸道真气每层物攻×0.1×等级缩放，最多 6 层
	var cao: XActor = s.actor(38)
	cao.change_level(99)
	b.state_data["_tq_stack_106"] = 6
	var dv := XTianqiSkills.dot_value(cao, b, b106.dot)
	_check("p3_dot_value", is_equal_approx(dv, float(cao.atk) * 0.6), [dv, cao.atk])
	# 本场忏悔次数：签弟赎罪每次 +10%，封顶 30%
	var qd: XActor = s.actor(34)
	qd.change_level(99)
	var shu := XDB.rec("Skills", 1017)
	qd.set_meta("xtq_casts", {})
	var v0 := XTianqiSkills.formula(qd, b, shu)
	qd.set_meta("xtq_casts", {1016: 2})
	var v2 := XTianqiSkills.formula(qd, b, shu)
	qd.set_meta("xtq_casts", {1016: 9})
	var v9 := XTianqiSkills.formula(qd, b, shu)
	_check("p3_cast_count", is_equal_approx(v2 / v0, 1.2) and is_equal_approx(v9 / v0, 1.3), [v0, v2, v9])
	# 晴明尸鬼尽封：扣 50% 生命，学了心法②不扣
	var qm: XActor = s.actor(33)
	qm.change_level(99)
	qm.learn_skill(5434)
	var gui := XDB.rec("Skills", 5434)
	var c0 := XBattleLogic.skill_hp_cost(qm, gui)
	qm.learn_skill(6919)
	_check("p3_hp_free", c0 > 0 and XBattleLogic.skill_hp_cost(qm, gui) == 0, c0)
	# 露丝取物攻、魔攻里高的
	var ls: XActor = s.actor(43)
	ls.change_level(99)
	var bao := XDB.rec("Skills", 1177)
	_check("p3_max_of", is_equal_approx(XTianqiSkills.formula(ls, b, bao), maxf(ls.atk, ls.mat) * 3.6), [XTianqiSkills.formula(ls, b, bao), ls.atk, ls.mat])
	# 天蓬净世诀吃 TP：每点 +0.3%，封顶 30%
	var tp: XActor = s.actor(37)
	tp.change_level(99)
	var jsj := XDB.rec("Skills", 1098)
	tp.tp = 0
	var t0 := XTianqiSkills.formula(tp, b, jsj)
	tp.tp = 50
	var t50 := XTianqiSkills.formula(tp, b, jsj)
	_check("p3_self_tp", is_equal_approx(t50 / t0, 1.15), [t0, t50])
	# 艾瑞塔数诅咒、迪昂数自己的状态
	b.add_state(189)
	b.add_state(191)
	var cr := XTianqiSkills._cond({"if": "target_states_in", "states": [99, 189, 191, 192], "per": 0.1, "cap": 0.3}, qm, b)
	_check("p3_target_states_in", is_equal_approx(cr, 1.2), cr)
	var di: XActor = s.actor(54)
	di.add_state(10803)
	di.add_state(10804)
	_check("p3_self_states", is_equal_approx(XTianqiSkills._cond({"if": "self_states", "per": 0.05, "cap": 0.3}, di, b), 1.0 + 0.05 * di.state_ids.size()) and di.state_ids.size() >= 2, di.state_ids)
	# 大羿物攻比较（追星判定时 ×1.3）
	var yi: XActor = s.actor(59)
	var hi := XTianqiSkills._cond({"if": "atk_above_target", "mult": 1.2}, yi, b)
	_check("p3_atk_above", is_equal_approx(hi, 1.2 if float(yi.atk) > float(b.atk) else 1.0), [yi.atk, b.atk])
	# 小青：学了进阶给的一剑破万光（5109），开战补学主动大招剑破万光（10711）
	var xq: XActor = s.actor(58)
	_check("p3_learn_s_not_level", not xq.learnings().any(func(l): return int(l.skillId) == 10711))
	xq.learn_skill(5109)
	XTianqiSkills.sync_learn(xq)
	_check("p3_learn_s", xq.skill_ids.has(10711) and int(XDB.rec("Skills", 10711).tpCost) == 100 and int(XDB.rec("Skills", 10711).scope) == 2)
	var wk: XActor = s.actor(52)
	wk.change_level(20)
	_check("p3_buzhao_wukong", wk.skill_ids.has(10712) and str(XDB.rec("Skills", 10712).name) == "气功连弹")
	# 至尊宝真火追击半伤；天蓬吞云开场 TP
	_check("p3_zhenhuo_half", is_equal_approx(XZhenhuo.scale_of(s.actor(31)), 0.5))
	tp.tp = 0
	_wear(tp, "armor", 3578)
	XTianqiSkills.start_turns([tp])
	_check("p3_start_tp", float(tp.tp) >= 50.0, tp.tp)
	lg.end_battle(0)

## 第四期（61～94 号）的新能力
func _p4() -> void:
	var s := XTianqi.start_new_game(3, "jianxian", [61, 65, 69, 70, 74])
	XTianqi.take_pending()
	for id in [61, 63, 64, 65, 69, 70, 72, 74, 76, 78, 82]:
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var b := _enemy(lg)
	# 变量起点挪动（町甄纯真值：原版开局 6 点，按 2 点算，每点 +5%，最多 6 点）
	var zz: XActor = s.actor(61)
	s.set_variable(372, 6)
	_check("p4_offset", is_equal_approx(XTianqiSkills._cond({"if": "var_bonus", "var": 372, "per": 0.05, "cap": 0.3, "offset": -4}, zz, b), 1.1))
	s.set_variable(372, 20)
	_check("p4_offset_cap", is_equal_approx(XTianqiSkills._cond({"if": "var_bonus", "var": 372, "per": 0.05, "cap": 0.3, "offset": -4}, zz, b), 1.3))
	# 带着专属物再加（阿语寰怨 +2 滴）
	var ay: XActor = s.actor(72)
	s.set_variable(371, 1)
	var c0 := XTianqiSkills._cond({"if": "var_bonus", "var": 371, "per": 0.05, "cap": 0.3, "offset_with": {"e3830": 2}}, ay, b)
	_wear(ay, "armor", 3830)
	var c2 := XTianqiSkills._cond({"if": "var_bonus", "var": 371, "per": 0.05, "cap": 0.3, "offset_with": {"e3830": 2}}, ay, b)
	_check("p4_offset_with", is_equal_approx(c0, 1.05) and is_equal_approx(c2, 1.15), [c0, c2])
	# 状态解除时机改写（安抚圣光原版整场 → 1 回合、回合结束解除）
	var st228 := XDB.rec("States", 228)
	_check("p4_state_auto", int(st228.autoRemovalTiming) == 2 and int(st228.maxTurns) == 1, [st228.autoRemovalTiming, st228.maxTurns])
	# 制衡：全队生命比例拉平再 +5%
	var party: Array = lg.alive(lg.actors)
	for i in party.size():
		party[i].hp = float(party[i].mhp) * (0.2 if i == 0 else 1.0)
	var avg := 0.0
	for m in party:
		avg += float(m.hp) / float(m.mhp)
	avg = minf(1.0, avg / party.size() + 0.05)
	XTianqiSkills._hp_equalize(lg, party[0], XDB.rec("Skills", 2584))
	_check("p4_hp_equalize", party.all(func(m): return absf(float(m.hp) / float(m.mhp) - avg) < 0.01), avg)
	# 开局挂给敌人的状态的回合数（拉尔垂恤：安抚多 1 回合）
	var lr: XActor = s.actor(63)
	_wear(lr, "armor", 3822)
	b.add_state(228)
	XTianqiSkills.start_turns([lr], [b])
	_check("p4_foe_turns", int(b.state_turns.get(228, 0)) == 2, b.state_turns.get(228))
	# 念乡：振奋多 1 回合（全队）
	var ml: XActor = s.actor(69)
	var zn: XActor = s.actor(61)
	_wear(ml, "armor", 3828)
	ml.add_state(238)
	zn.add_state(238)
	XTianqiSkills.start_turns([ml, zn], [])
	_check("p4_start_party", int(zn.state_turns.get(238, 0)) == 3 and int(ml.state_turns.get(238, 0)) == 3, zn.state_turns.get(238))
	# 紫霞剑气：暴击率超过 100% 每 10% +3%，最多 +30%
	var zx: XActor = s.actor(70)
	var cri := float(zx.cri)
	var want := 1.0 + clampf((cri - 1.0) * 0.3, 0.0, 0.3)
	_check("p4_cri_over", is_equal_approx(XTianqiSkills._cond({"if": "self_cri_over", "per": 0.3, "cap": 0.3}, zx, b), want), cri)
	# 自己生命比例判定（玉面狐狸朔月依依）
	var hu: XActor = s.actor(82)
	hu.hp = hu.mhp
	var up := XTianqiSkills._cond({"if": "self_hp_above", "rate": 0.5, "mult": 1.1}, hu, b)
	hu.hp = float(hu.mhp) * 0.3
	var dn := XTianqiSkills._cond({"if": "self_hp_above", "rate": 0.5, "mult": 1.1}, hu, b)
	_check("p4_self_hp_above", is_equal_approx(up, 1.1) and is_equal_approx(dn, 1.0), [up, dn])
	# 陈醉拳打完回 10%，学了酒仙 20%
	var ch: XActor = s.actor(74)
	ch.learn_skill(2614)
	ch.hp = float(ch.mhp) * 0.5
	XTianqiSkills._self_heal(ch, XDB.rec("Skills", 2612))
	var h1 := float(ch.hp) / float(ch.mhp)
	ch.learn_skill(2619)
	ch.hp = float(ch.mhp) * 0.5
	XTianqiSkills._self_heal(ch, XDB.rec("Skills", 2612))
	var h2 := float(ch.hp) / float(ch.mhp)
	_check("p4_self_heal", absf(h1 - 0.6) < 0.01 and absf(h2 - 0.7) < 0.01, [h1, h2])
	# 白晶晶毒爆：每层骨毒 +1.2／3.6，封顶 3 层（骨姿 5 层）
	var bj: XActor = s.actor(76)
	b.add_state(502)
	b.state_data["_tq_stack_502"] = 3
	var g3 := XTianqiSkills._cond({"if": "target_stack", "state": 502, "per": 0.3333, "cap": 1.0, "cap_with": {"e3635": 1.6667}}, bj, b)
	b.state_data["_tq_stack_502"] = 5
	var g5 := XTianqiSkills._cond({"if": "target_stack", "state": 502, "per": 0.3333, "cap": 1.0, "cap_with": {"e3635": 1.6667}}, bj, b)
	_check("p4_target_stack", absf(g3 - 2.0) < 0.01 and absf(g5 - 2.0) < 0.01, [g3, g5])
	_check("p4_bone_dot", str(XDB.rec("States", 502).get("dot", {}).get("kind", "")) == "tianqi")
	# 击杀成长一次涨两项（白晶晶敏捷、幸运）
	s.flags.tianqi["skill_grow"] = {"baijingjing": 100}
	bj.learn_skill(3497)
	_check("p4_grow_params", is_equal_approx(XTianqiSkills.param_rate(bj, 6), 1.1) and is_equal_approx(XTianqiSkills.param_rate(bj, 7), 1.1) and is_equal_approx(XTianqiSkills.param_rate(bj, 2), 1.0))
	# 十三娘心绕：缠意开局 2 层
	var ss: XActor = s.actor(78)
	ss.set_meta("xtq_casts", {3737: 1})
	var k0 := XTianqiSkills._cond({"if": "cast_count", "of": [3737], "per": 0.05, "cap": 0.3, "offset_with": {"e3671": 2}}, ss, b)
	_wear(ss, "armor", 3671)
	var k2 := XTianqiSkills._cond({"if": "cast_count", "of": [3737], "per": 0.05, "cap": 0.3, "offset_with": {"e3671": 2}}, ss, b)
	_check("p4_cast_offset", is_equal_approx(k0, 1.05) and is_equal_approx(k2, 1.15), [k0, k2])
	# 新补的技能、表外状态
	_check("p4_new_skills", str(XDB.rec("Skills", 10713).name) == "地裂术" and int(XDB.rec("Skills", 10713).scope) == 2 and str(XDB.rec("Skills", 10727).name) == "剑影重重")
	_check("p4_new_states", str(XDB.rec("States", 10807).name) == "神性能量" and str(XDB.rec("States", 10810).name) == "冰冷")
	lg.end_battle(0)


## 第五期（95～140 号）的新能力：护盾、反弹、按比例的条件、记录字段、带条件的无视防御
func _p5() -> void:
	var s := XTianqi.start_new_game(3, "jianxian", [95, 100, 107, 108, 109])
	XTianqi.take_pending()
	for id in [95, 100, 107, 108, 109]:
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var b := _enemy(lg)
	# 当前魔法比例当倍率（奈叶厄临星爆：最多 0.9）、已损生命（牢大）、目标生命比例（南宫恨）
	var ny: XActor = s.actor(108)
	ny.mp = float(ny.mmp) * 0.5
	var f5 := XTianqiSkills._cond({"if": "self_mp_frac", "cap": 0.9}, ny, b)
	ny.mp = ny.mmp
	var f9 := XTianqiSkills._cond({"if": "self_mp_frac", "cap": 0.9}, ny, b)
	_check("p5_mp_frac", is_equal_approx(f5, 0.5) and is_equal_approx(f9, 0.9), [f5, f9])
	var ld: XActor = s.actor(109)
	ld.hp = float(ld.mhp) * 0.6
	var l1 := XTianqiSkills._cond({"if": "self_hp_lost", "per": 0.5, "cap": 0.3}, ld, b)
	ld.hp = 1.0
	var l2 := XTianqiSkills._cond({"if": "self_hp_lost", "per": 0.5, "cap": 0.3}, ld, b)
	_check("p5_hp_lost", is_equal_approx(l1, 1.2) and is_equal_approx(l2, 1.3), [l1, l2])
	b.hp = float(b.mhp) * 0.5
	_check("p5_target_hp_rate", is_equal_approx(XTianqiSkills._cond({"if": "target_hp_rate", "per": 0.2, "cap": 0.2}, ld, b), 1.1))
	b.hp = b.mhp
	# 护盾：钟离玉璋护盾给自己加生命上限 20%，只在正式结算（execute）时加；护盾满时岩脊 +30%
	var zl: XActor = s.actor(107)
	zl.shield = 0.0
	var rec := XDB.rec("Skills", 5671)
	XFormulaExecution.run_item(rec, zl, zl, lg.vars(), {}, false)
	var pre := float(zl.shield)
	XFormulaExecution.run_item(rec, zl, zl, lg.vars(), {}, true)
	_check("p5_shield", pre == 0.0 and absf(float(zl.shield) - floorf(float(zl.mhp) * 0.2) * (1.0 + zl.shield_effect_bonus())) < 1.0, [pre, zl.shield, zl.mhp])
	zl.shield = float(zl.mhp) * 0.2
	_check("p5_shield_full", is_equal_approx(XTianqiSkills._cond({"if": "self_shield", "full": 0.2, "cap": 0.3}, zl, b), 1.3))
	zl.shield = 0.0
	# 反弹：云霄阵眼不灭 20%（原版 ×88 的脚本去掉）
	var yx: XActor = s.actor(100)
	yx.add_state(1061)
	b.hp = b.mhp
	var hp0 := float(b.hp)
	XTianqiSkills._reflect(b, yx, {"hp": 1000.0})
	var cut := hp0 - float(b.hp)
	_check("p5_reflect", is_equal_approx(cut, 200.0) or is_equal_approx(cut, 100.0), cut)
	_check("p5_reflect_script_gone", (XDB.rec("States", 1061).get("effects", []) as Array).is_empty())
	# 记录字段：厄临星爆的「按当前魔法扣、每 2000 蓝多打一段」关掉
	var el := XDB.rec("Skills", 5706)
	_check("p5_fields", float(el.get("mpCostCurrentRate", 1)) == 0.0 and not bool(el.get("postDamageCostRepeat", true)) and int(el.mpCost) == 0, [el.get("mpCostCurrentRate"), el.get("postDamageCostRepeat"), el.mpCost])
	# 后颈斩：目标生命低于 30% 才无视物防 30%、必暴
	var ms: XActor = s.actor(95)
	var hj := XDB.rec("Skills", 10731)
	var full_ops := XTianqiSkills.damage_ops(hj, ms, b)
	b.hp = float(b.mhp) * 0.2
	var low_ops := XTianqiSkills.damage_ops(hj, ms, b)
	_check("p5_pierce_when", full_ops.is_empty() and low_ops.size() == 2 and is_equal_approx(XTianqiSkills.item_cri(ms, hj, b, 0.1), 1.0), [full_ops, low_ops])
	b.hp = b.mhp
	# 三笠补的四招、锻炼；表外状态
	_check("p5_new_skills", str(XDB.rec("Skills", 10728).name) == "换刃" and int(XDB.rec("Skills", 10730).scope) == 2 and str(XDB.rec("Skills", 10731).name) == "后颈斩")
	_check("p5_learn", (XTianqiSkills.data().learn.get("95", []) as Array).size() == 4)
	_check("p5_new_states", str(XDB.rec("States", 10813).name) == "换刃" and str(XDB.rec("States", 10816).name) == "生门")
	_check("p5_fire_dot", str(XDB.rec("States", 1819).get("dot", {}).get("kind", "")) == "tianqi")
	_check("p5_self_states", (XTianqiSkills.spec(5600).get("self_states", []) as Array).has(10819.0) and str(XDB.rec("States", 10819).name) == "碧天独行")
	s.set_variable(1490, 10)
	_check("p5_duanlian", is_equal_approx(XTianqiSkills._cond({"if": "var_bonus", "var": 1490, "per": 0.03, "cap": 0.3}, ms, b), 1.3))
	lg.end_battle(0)


func _p6() -> void:
	var ids := [147, 155, 163, 167, 142]
	var s := XTianqi.start_new_game(3, "jianxian", ids)
	XTianqi.take_pending()
	for id in ids:
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var b := _enemy(lg)
	# 非天吞剑：十个变量加权相加，每点 +2%，满 +30%；纯阳破军上限 +35%
	var ft: XActor = s.actor(147)
	var tj: Dictionary = XTianqiSkills.data().skills["10072"].damage.conds[0]
	for v in [1580, 1581, 1582]:
		s.set_variable(v, 1)
	var t4 := XTianqiSkills._cond(tj, ft, b)
	for v in range(1580, 1590):
		s.set_variable(v, 1)
	_check("p6_var_sum", is_equal_approx(t4, 1.08) and is_equal_approx(XTianqiSkills._cond(tj, ft, b), 1.3), [t4, XTianqiSkills._cond(tj, ft, b)])
	# 病娇爱之惩罚：残血线 25%，天外天·巴雷特提到 35%
	var bj: XActor = s.actor(155)
	var c25: Dictionary = XTianqiSkills.data().skills["10020"].damage.conds[0]
	b.hp = float(b.mhp) * 0.3
	var no85 := XTianqiSkills._cond(c25, bj, b)
	_wear(bj, "weapon", 85)
	var with85 := XTianqiSkills._cond(c25, bj, b)
	b.hp = b.mhp
	_check("p6_hp_below_rate_with", is_equal_approx(no85, 1.0) and is_equal_approx(with85, 1.5), [no85, with85])
	# 拳一无限超越：本场第几回合（开始行动时记），每回合 +3%，最多 10 回合；一拳法宝开局就算 2 层
	var qy: XActor = s.actor(163)
	var bt := {"if": "battle_turn", "per": 0.03, "cap": 0.3, "offset_with": {"e124": 2}}
	qy.set_meta("xtq_turn", 1)
	var r1 := XTianqiSkills._cond(bt, qy, b)
	qy.set_meta("xtq_turn", 5)
	var r5 := XTianqiSkills._cond(bt, qy, b)
	qy.set_meta("xtq_turn", 30)
	_check("p6_battle_turn", is_equal_approx(r1, 1.0) and is_equal_approx(r5, 1.12) and is_equal_approx(XTianqiSkills._cond(bt, qy, b), 1.3), [r1, r5])
	# 目标已损生命、两项属性之比
	b.hp = float(b.mhp) * 0.5
	_check("p6_target_hp_lost", is_equal_approx(XTianqiSkills._cond({"if": "target_hp_lost", "per": 0.5, "cap": 0.5}, qy, b), 1.25))
	b.hp = b.mhp
	var ratio := float(qy.luk) / maxf(1.0, float(qy.atk))
	var want := 1.3 if ratio >= 1.0 else (1.15 if ratio >= 0.5 else 1.0)
	_check("p6_stat_ratio", is_equal_approx(XTianqiSkills._cond({"if": "stat_ratio", "num": "luk", "den": "atk", "steps": [[0.5, 1.15], [1.0, 1.3]]}, qy, b), want))
	# 专属模块收口：表里改写过的技能，模块的终伤／结算倍率、加成去掉，无视防御最多三成；别的技能原样
	var rv: XActor = s.actor(167)
	var mods := [{"op": "mul", "field": "settlementMultiplier", "value": 4.25}, {"op": "add", "field": "finalAdd", "value": 1.5},
		{"op": "mul", "field": "magicalDefenseRate", "value": 0.1}, {"op": "set", "field": "mode", "value": "magical"},
		{"op": "mul", "field": "incomingMultiplier", "value": 0.8}]
	var capped := XTianqiSkills.module_ops(XDB.rec("Skills", 10122), rv, mods)
	var kept := XTianqiSkills.module_ops(XDB.rec("Skills", 1), rv, mods)
	_check("p6_module_ops", capped.size() == 3 and is_equal_approx(float(capped[0].value), 0.7) and kept.size() == 5, capped)
	XTianqiSkills.MODULE_CAP = false
	_check("p6_module_cap_switch", XTianqiSkills.module_ops(XDB.rec("Skills", 10122), rv, mods).size() == 5)
	XTianqiSkills.MODULE_CAP = true
	# 麒麟踏天来：人剑 20% 接地剑（半伤），麒麟对剑 +10%
	var ql: XActor = s.actor(142)
	ql.learn_skill(10109)
	var fl := XTianqiSkills._follow_of(ql, XDB.rec("Skills", 10098))
	_check("p6_qilin_follow", fl.size() == 1 and int(fl[0][0].id) == 10099 and is_equal_approx(float(fl[0][1]), 0.2) and is_equal_approx(float(fl[0][2]), 0.5), fl.size())
	# 新招、补学、状态
	_check("p6_new_skills", str(XDB.rec("Skills", 10737).name) == "剑*非天·一线" and int(XDB.rec("Skills", 10737).scope) == 1 and str(XDB.rec("Skills", 10753).name) == "万剑归宗·三段")
	_check("p6_learn", (XTianqiSkills.data().learn.get("165", []) as Array).size() == 2 and (XTianqiSkills.data().learn.get("156", []) as Array).size() == 2)
	_check("p6_states", str(XDB.rec("States", 10826).name) == "趴下" and is_equal_approx(float(XTianqiSkills._states[2550].get("reflect", 0.0)), 0.3))
	lg.end_battle(0)


## 补完：首领减半（控制减半、1 回合控制无效、减益减半至少 1 回合、按招换减伤）、百分比生命伤害对首领无效
func _fill() -> void:
	var s := _state()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var b := _enemy(lg) as XEnemy
	b.boss_difficulty_boss = true
	b.boss_hyper_armor = false
	XTianqiSkills._act_skill = 0
	var two := 0  # 卡里 2 回合的控制状态（晴明失魄这类）
	for id in XTianqiSkills._states:
		var r := XDB.rec("States", int(id))
		if XEnemy.boss_control_state(int(id)) and int(r.get("minTurns", 0)) == 2 and int(r.get("maxTurns", 0)) == 2 and int(r.get("autoRemovalTiming", 0)) > 0:
			two = int(id)
			break
	b.add_state(two)
	_check("fill_boss_ctrl_half", two > 0 and b.is_state_affected(two) and int(b.state_turns.get(two, 0)) == 1, [two, b.state_turns.get(two)])
	b.remove_state(two)
	b.add_state(1043)
	_check("fill_boss_ctrl_1turn_immune", not b.is_state_affected(1043))
	XTianqiSkills._act_skill = 4830
	b.add_state(1043)
	_check("fill_boss_sub", not b.is_state_affected(1043) and b.is_state_affected(10827) and str(XDB.rec("States", 10827).name) == "首领压制")
	XTianqiSkills._act_skill = 0
	b.add_state(1819)
	var base := int(XDB.rec("States", 1819).maxTurns)
	_check("fill_boss_debuff_ceil", int(b.state_turns.get(1819, 0)) == maxi(1, ceili(base / 2.0)), [base, b.state_turns.get(1819)])
	var n := lg.enemies[1] as XEnemy if lg.enemies.size() > 1 else null
	if n != null:
		n.boss_difficulty_boss = false
		n.add_state(two)
		_check("fill_nonboss_full", int(n.state_turns.get(two, 0)) == 2, n.state_turns.get(two))
	var a: XActor = s.actor(XIAOYAO)
	_check("fill_pct_immune", XTianqiSkills.boss_pct_immune(a, b, 1067) and not XTianqiSkills.boss_pct_immune(a, b, 1) and (n == null or not XTianqiSkills.boss_pct_immune(a, n, 1067)))
	# 双持副手只算一半属性：第二把武器的物攻贡献 ×0.5
	var w0 = a.equips[0]
	var keep1 = a.equips[1] if a.equips.size() > 1 else null
	if w0 is Dictionary and not w0.is_empty() and a.equips.size() > 1:
		a.equips[1] = {}
		var one := a._param_plus(2)
		a.equips[1] = w0.duplicate(true)
		var half := a._param_plus(2)
		XTianqiSkills.OFFHAND_HALF = false
		var full := a._param_plus(2)
		XTianqiSkills.OFFHAND_HALF = true
		a.equips[1] = keep1
		_check("fill_offhand_half", full > one and is_equal_approx(half - one, (full - one) * 0.5), [one, half, full])
	else:
		_check("fill_offhand_half", false, "没有武器")
	# 马宝国混元：反弹受到伤害的 30%，肝帝积分每 10 分 +1%（最多 +30%），首领减半
	if n != null:
		a.add_state(908)
		s.set_variable(206, 100)
		n.hp = n.mhp
		var h0 := float(n.hp)
		XTianqiSkills._reflect(n, a, {"hp": 1000.0})
		_check("fill_mabaoguo_reflect", is_equal_approx(h0 - float(n.hp), 330.0), h0 - float(n.hp))
		b.hp = b.mhp
		var hb := float(b.hp)
		XTianqiSkills._reflect(b, a, {"hp": 1000.0})
		_check("fill_mabaoguo_boss_half", is_equal_approx(hb - float(b.hp), 165.0), hb - float(b.hp))
		a.remove_state(908)
	XTianqiSkills.CARDS = false
	b.remove_state(1043)
	b.add_state(1043)
	_check("fill_cards_off", b.is_state_affected(1043))
	XTianqiSkills.CARDS = true
	lg.end_battle(0)


## 补完：白起杀气（上限 6、耗 3／6、不够不能放、暴击多攒、击杀返还、满 6 再动、开战归零）
func _fill_charge() -> void:
	var ids := [80, 60, 71, 95, 100]
	var s := XTianqi.start_new_game(3, "jianxian", ids)
	XTianqi.take_pending()
	for id in ids:
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var a: XActor = s.actor(80)
	s.set_variable(369, 7)
	XTianqiSkills.start_turns([a], [])
	var dt := XDB.rec("Skills", 4450)
	_check("fill_charge_start", int(s.variable(369)) == 0 and not lg.can_use(a, dt) and not XTianqiSkills.meets(a, dt))
	_check("fill_charge_no_ce", not (XDB.rec("Skills", 4448).effects as Array).any(func(e): return int(e.code) == 44) and not (dt.effects as Array).any(func(e): return int(e.code) == 44))
	var kz := XDB.rec("Skills", 4448)
	for i in 3:
		XTianqiSkills._charge(lg, a, {"u": a, "skill": kz, "targets": [], "crit": true})
	_check("fill_charge_gain", int(s.variable(369)) == 3 and XTianqiSkills.meets(a, dt), s.variable(369))
	if not a.skill_ids.has(4459):
		a.learn_skill(4459)
	XTianqiSkills._charge(lg, a, {"u": a, "skill": kz, "targets": [], "crit": true})
	_check("fill_charge_crit", int(s.variable(369)) == 5, s.variable(369))
	var b := _enemy(lg)
	_check("fill_charge_low", is_equal_approx(XTianqiSkills._cond({"if": "var_at_least", "var": 369, "n": 6, "cap": 6, "mult": 1.6667}, a, b), 1.0))
	if not a.skill_ids.has(4456):
		a.learn_skill(4456)
	var q := lg.current_order.size()
	XTianqiSkills._charge(lg, a, {"u": a, "skill": kz, "targets": [], "crit": true})
	_check("fill_charge_full_again", int(s.variable(369)) == 6 and lg.current_order.size() == q + 1, [s.variable(369), lg.current_order.size(), q])
	s.set_variable(369, 5)
	XTianqiSkills._charge(lg, a, {"u": a, "skill": kz, "targets": [], "crit": false})
	_check("fill_charge_again_once", lg.current_order.size() == q + 1)
	_check("fill_charge_high", is_equal_approx(XTianqiSkills._cond({"if": "var_at_least", "var": 369, "n": 6, "cap": 6, "mult": 1.6667}, a, b), 1.6667))
	XTianqiSkills._charge(lg, a, {"u": a, "skill": dt, "targets": []})
	_check("fill_charge_spend_high", int(s.variable(369)) == 0, s.variable(369))
	s.set_variable(369, 5)
	if not a.skill_ids.has(4461):
		a.learn_skill(4461)
	b.hp = 0.0
	b.add_state(1)
	XTianqiSkills._charge(lg, a, {"u": a, "skill": dt, "targets": [b]})
	_check("fill_charge_refund", int(s.variable(369)) == 3, s.variable(369))
	lg.end_battle(0)


func _smoke() -> void:
	for group in [[3, 4, 5, 6, 7], [8, 9, 10, 11, 12], [13, 14, 15, 1, 2], [16, 17, 18, 19, 20], [21, 22, 23, 24, 25], [26, 27, 28, 29, 30],
			[31, 32, 33, 34, 35], [36, 37, 38, 39, 40], [41, 42, 43, 44, 45], [46, 47, 48, 49, 50], [51, 52, 53, 54, 55], [56, 57, 58, 59, 60],
			[61, 62, 63, 64, 65], [66, 67, 68, 69, 70], [71, 72, 73, 74, 75], [76, 77, 78, 79, 80], [81, 82, 83, 84, 85], [86, 87, 88, 89, 90], [91, 92, 93, 94, 61],
			[95, 96, 97, 98, 99], [100, 101, 102, 103, 104], [105, 106, 107, 108, 109], [115, 117, 118, 119, 120], [122, 123, 124, 127, 128], [129, 130, 131, 95, 100],
			[142, 147, 148, 149, 150], [151, 153, 154, 155, 156], [158, 159, 162, 163, 164], [165, 142, 147, 148, 149],
			[167, 168, 169, 170, 171], [172, 173, 174, 175, 176], [177, 178, 179, 167, 168]]:
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
