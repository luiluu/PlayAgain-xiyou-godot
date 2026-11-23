extends Node
## 【小A·未经审查】T411 徐凤年 152 天启篇技能卡 v0.3 专项：
## 1) 剑一～剑八（9987～9994 / 状态 2530～2537）hit_extra_pct 真实扣血＋r.extra／r.hit_extra＋回退开关 HIT_EXTRA_ON＋清掉 +165% 物理/寒冰增伤与 +52% 穿抗；
## 2) 主动两招：9998 剑气滚龙壁·封印单体五段、无 2539、无 TP 消耗、variance=0；9995 剑九主动终式单体八段、目标 <30% 斩杀翻倍、放完 1 回合不能动（10833 剑竭）、每场一次；
## 3) 其余被动：9985 大黄庭（再动 +10%）、9986 大帝转世（物品掉落率 +10%）、9996 九阶基因锁（空壳隐藏、清 -100% 经验）、9997 天下第一（暴击 +10%、承伤 -10%、清 2525 与旧乘区）；
## 4) 角色本体 Actors.json[152].traits 清理（再动 +100%、攻次 +2、物伤 -20%）及回退开关 ACTOR_TRAITS_STRIP；
## 5) 4 件专属装备（armor:143、weapon:76、armor:129、weapon:94）天启篇清场；
## 6) 西游原版档（非天启篇）零变化证明：本体 traits、状态 2530～2537、技能 9985～9998 与专属装备完全保持原版。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _make_tianqi_state() -> XState:
	var s := XState.new_game(XTianqi.legacy_of("zhengdao"), 152, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "zhengdao", "lineup": [152]}
	s.random_master = XRandomStream.hex64(20261123)
	s.actor_max_level = 81
	XState.current = s
	if not s.party.has(152):
		XTianqi._joining = true
		s.add_actor(152)
		XTianqi._joining = false
	for i in 5:
		s.set_battle_slot(i, 152 if i == 0 else 0)
	var a := s.actor(152)
	a.change_level_mv(81)
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	return s


func _make_xiyou_state() -> XState:
	var s := XState.new_game_blank()
	s.random_master = XRandomStream.hex64(20261123)
	s.set_switch(2494, true)
	XState.current = s
	s.add_actor(152)
	for i in 5:
		s.set_battle_slot(i, 152 if i == 0 else 0)
	var a := s.actor(152)
	a.change_level_mv(81)
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	return s


func _find_multi_troop() -> int:
	for tid in range(1, 200):
		var tr := XDB.rec("Troops", tid)
		if tr is Dictionary and (tr.get("members", []) as Array).size() >= 2:
			return tid
	return 1


func _run() -> void:
	var was_phase4 := XTianqiBase.PHASE4
	var was_hit_extra := XTianqiSkills.HIT_EXTRA_ON
	var was_strip := XTianqiSkills.ACTOR_TRAITS_STRIP
	var was_rel := XImportedBalance.RELEASE_XUFENG
	var was_tq := XImportedBalance.XUFENG_TIANQI
	XMessageBox.auto = true
	XTianqiBase.PHASE4 = true
	XTianqiSkills.HIT_EXTRA_ON = true
	XTianqiSkills.ACTOR_TRAITS_STRIP = true
	XImportedBalance.RELEASE_XUFENG = true
	XImportedBalance.XUFENG_TIANQI = true
	XTianqiSkills.reload_table()

	# ---- 一、天启篇存档 ----
	var s := _make_tianqi_state()
	var a := s.actor(152)

	# 1. 角色名框与本体 traits 清理（再动 +100%、攻次 +2、物伤 -20% 全清）
	check("tq.actor_name", str(XTianqiSkills.data().get("actors", {}).get("152", {}).get("name", "")) == "徐凤年")
	check("tq.strip.atk_times", is_equal_approx(a.attack_times_add(), 0.0), a.attack_times_add())
	var aplus_sum := 0.0
	for p in a.action_plus_set():
		aplus_sum += float(p)
	check("tq.strip.action_plus", is_equal_approx(aplus_sum, 0.10), a.action_plus_set())
	check("tq.strip.phys_rate", is_equal_approx(a.element_rate(1), 1.0), a.element_rate(1))
	# 回退开关 ACTOR_TRAITS_STRIP = false
	XTianqiSkills.ACTOR_TRAITS_STRIP = false
	a.param_mark_dirty()
	check("tq.strip.off_atk_times", is_equal_approx(a.attack_times_add(), 2.0), a.attack_times_add())
	check("tq.strip.off_phys_rate", is_equal_approx(a.element_rate(1), 0.8), a.element_rate(1))
	XTianqiSkills.ACTOR_TRAITS_STRIP = true
	a.param_mark_dirty()

	# 2. 被动清场：9985/9986/9996/9997 与 9987～9994 残余标签
	var sk9986 := XDB.rec("Skills", 9986)
	check("tq.9986.irup", str(sk9986.get("meta", {}).get("passiveIRUP", "")).strip_edges() == "10", sk9986.get("meta"))
	var sk9996 := XDB.rec("Skills", 9996)
	check("tq.9996.shell", XTianqiSkills.is_shell(9996), sk9996.get("note", ""))
	check("tq.9996.no_spbst9", not sk9996.get("meta", {}).has("passiveSPBST9") and (sk9996.get("effects", []) as Array).is_empty(), sk9996.get("meta"))
	var sk9997 := XDB.rec("Skills", 9997)
	var m9997: Dictionary = sk9997.get("meta", {})
	check("tq.9997.clean", not m9997.has("StartPushState2525") and not m9997.has("passiveHarmRi") and not m9997.has("passiveCrHarmRi")
		and str(m9997.get("passiveXPBST2", "")).strip_edges() == "10%" and str(m9997.get("passiveSPBST6", "")).strip_edges() == "-10%"
		and str(m9997.get("passiveSPBST7", "")).strip_edges() == "-10%", m9997)
	var pc: Dictionary = a.passive_cache()
	check("tq.swords.no_elup", pc.get("passiveELUP", {}).is_empty() and pc.get("depassiveHarmRe", {}).is_empty(), [pc.get("passiveELUP"), pc.get("depassiveHarmRe")])

	# 3. 专属装备 4 件清场
	for pair in [["armor", 143], ["weapon", 76], ["armor", 129], ["weapon", 94]]:
		var item := XGear.template(pair[0], pair[1])
		var view: Dictionary = XTianqiSkills.gear_view(item)
		var vm: Dictionary = view.get("meta", {})
		var bad_traits: Array = (view.get("traits", []) as Array).filter(func(t): return int(t.get("code", 0)) in [11, 21, 22, 23, 34, 61])
		check("tq.gear.%s_%d" % [pair[0], pair[1]], bad_traits.is_empty() and not vm.has("passiveHarmRi") and not vm.has("passiveCrHarmRi")
			and not vm.has("StartPushState2301") and not vm.has("StartPushState2315"), [bad_traits, vm.keys()])

	# 4. 战斗实测：开战自动挂 2530～2537、命中追加伤害真实扣血＋写 r.extra／r.hit_extra
	var logic := XBattleLogic.new()
	logic.setup(_find_multi_troop(), s, XBattleRandom.create(str(s.random_master)))
	var has_all_swords := true
	for stid in range(2530, 2538):
		if not a.is_state_affected(stid):
			has_all_swords = false
	check("tq.battle.start_states", has_all_swords, a.state_ids)
	check("tq.battle.no_2539_2525", not a.is_state_affected(2539) and not a.is_state_affected(2525), a.state_ids)

	var e0: XEnemy = logic.enemies[0]
	var e1: XEnemy = logic.enemies[1]
	for foe in logic.enemies:
		foe.add_param(0, 1.0e8)
		foe.param_mark_dirty()
		foe.recover_all()

	# 4a. 单击测试：主段伤害 + 8 条追加 = 精确扣血
	var sk9998 := XDB.rec("Skills", 9998)
	check("tq.9998.fields", int(sk9998.get("tpCost", -1)) == 0 and int(sk9998.get("damage", {}).get("variance", -1)) == 0 and int(sk9998.get("yepEffects", 0)) == 5)
	var hp_before: float = e0.hp
	XStateEffects.force_critical = true
	var r_hit := logic.apply(a, sk9998, e0)
	XStateEffects.force_critical = false
	var base_dmg := float(r_hit.get("hp", 0.0))
	var expected_extra := 0.0
	for pct in [2, 4, 6, 8, 10, 15, 20, 30]:
		expected_extra += floorf(base_dmg * float(pct) / 100.0)
	var actual_loss := hp_before - e0.hp
	check("tq.hit_extra.active", base_dmg > 0.0 and (r_hit.get("extra", []) as Array).size() == 8
		and is_equal_approx(float(r_hit.get("hit_extra", 0.0)), expected_extra)
		and is_equal_approx(actual_loss, base_dmg + expected_extra),
		{"base": base_dmg, "extra": r_hit.get("extra", []), "hit_extra": r_hit.get("hit_extra", 0.0), "want": expected_extra, "loss": actual_loss})

	# 4b. 回退开关 HIT_EXTRA_ON = false 时不追加
	XTianqiSkills.HIT_EXTRA_ON = false
	var hp_b2: float = e0.hp
	XStateEffects.force_critical = true
	var r_off := logic.apply(a, sk9998, e0)
	XStateEffects.force_critical = false
	check("tq.hit_extra.off", float(r_off.get("hit_extra", 0.0)) == 0.0 and not r_off.has("extra")
		and is_equal_approx(hp_b2 - e0.hp, float(r_off.get("hp", 0.0))),
		{"hp": r_off.get("hp", 0.0), "loss": hp_b2 - e0.hp, "extra": r_off.get("extra", [])})
	XTianqiSkills.HIT_EXTRA_ON = true

	# 4c. 9998 整招执行：单体五段，多敌时不波及旁人 e1
	e0.recover_all()
	e1.recover_all()
	var e1_hp0: float = e1.hp
	var logs9998: Array = logic.execute(a, sk9998, e0, true)
	var hits9998 := logs9998.filter(func(x): return x is Dictionary and str(x.get("type", "")) == "hit" and is_same(x.get("target"), e0))
	check("tq.9998.single_5hits", hits9998.size() == 5 and is_equal_approx(e1.hp, e1_hp0), {"hits": hits9998.size(), "e1_hp": e1.hp, "e1_hp0": e1_hp0})

	# 5. 9995 剑九：主动终式、单体八段、斩杀翻倍（<30%）、放完 1 回合不能动（10833 剑竭）
	var sk9995 := XDB.rec("Skills", 9995)
	check("tq.9995.fields", int(sk9995.get("stypeId", 0)) == 1 and int(sk9995.get("occasion", 0)) == 1
		and int(sk9995.get("yepEffects", 0)) == 8 and int(sk9995.get("damage", {}).get("variance", -1)) == 0
		and not sk9995.get("meta", {}).has("Hide in Battle") and not sk9995.get("meta", {}).has("StartPushState2538")
		and (sk9995.get("effects", []) as Array).is_empty(),
		{"stypeId": sk9995.get("stypeId"), "occ": sk9995.get("occasion"), "yepEffects": sk9995.get("yepEffects")})
	# 满血 vs <30% 血斩杀翻倍
	e0.hp = e0.mhp
	XStateEffects.force_critical = true
	var r_full := logic.apply(a, sk9995, e0)
	e0.hp = e0.mhp * 0.25
	var r_exec := logic.apply(a, sk9995, e0)
	XStateEffects.force_critical = false
	var dmg_full := float(r_full.get("hp", 0.0)) + float(r_full.get("hit_extra", 0.0))
	var dmg_exec := float(r_exec.get("hp", 0.0)) + float(r_exec.get("hit_extra", 0.0))
	check("tq.9995.execute_double", dmg_full > 0.0 and absf(dmg_exec / dmg_full - 2.0) < 0.02, {"full": dmg_full, "exec": dmg_exec, "ratio": dmg_exec / maxf(1.0, dmg_full)})
	# 整招八段 + 挂 10833 剑竭（下回合无法行动、再下回合恢复）
	e0.hp = e0.mhp * 0.25
	var logs9995: Array = logic.act(a, sk9995, e0)
	var hits9995 := logs9995.filter(func(x): return x is Dictionary and str(x.get("type", "")) == "hit" and is_same(x.get("target"), e0))
	check("tq.9995.8hits_and_stun", hits9995.size() == 8 and a.is_state_affected(10833) and not logic.can_move(a),
		{"hits": hits9995.size(), "states": a.state_ids, "can_move": logic.can_move(a)})
	logic.end_turn()  # 本回合结束：2 → 1，下回合仍无法行动
	check("tq.9995.stun_next_turn", a.is_state_affected(10833) and not logic.can_move(a), {"turns": a.state_turns.get(10833), "can_move": logic.can_move(a)})
	logic.end_turn()  # 下回合结束：1 → 0，解除恢复
	check("tq.9995.stun_recovers", not a.is_state_affected(10833) and logic.can_move(a), {"states": a.state_ids, "can_move": logic.can_move(a)})
	# 战斗结束后 2530～2537（battle_end: true）自动清除不残留
	logic.end_battle(0)
	var leftover := []
	for stid in range(2530, 2538):
		if a.is_state_affected(stid):
			leftover.append(stid)
	check("tq.battle.end_clean", leftover.is_empty(), leftover)

	# ---- 二、西游原版档零变化证明 ----
	var xs := _make_xiyou_state()
	var xa := xs.actor(152)
	check("xy.not_tianqi", not XTianqi.active(xs) and not XTianqiSkills.cards_on(xs))
	check("xy.traits.orig", is_equal_approx(xa.attack_times_add(), 2.0) and is_equal_approx(xa.element_rate(1), 0.8)
		and xa.action_plus_set().any(func(v): return is_equal_approx(float(v), 1.0)),
		{"atk_times": xa.attack_times_add(), "el1": xa.element_rate(1), "aplus": xa.action_plus_set()})
	var xy_st2530 := XDB.rec("States", 2530)
	check("xy.state2530.empty", (xy_st2530.get("effects", []) as Array).is_empty(), xy_st2530.get("effects"))
	var xy_sk9995 := XDB.rec("Skills", 9995)
	var xy_sk9986 := XDB.rec("Skills", 9986)
	var xy_sk9998 := XDB.rec("Skills", 9998)
	check("xy.skills.orig", int(xy_sk9995.get("stypeId", 0)) == 4 and str(xy_sk9986.get("meta", {}).get("passiveIRUP", "")).strip_edges() == "300"
		and xy_sk9998.get("meta", {}).has("StartPushState2539"))
	var xy_gear: Dictionary = XTianqiSkills.gear_view(XGear.template("armor", 143))
	check("xy.gear143.orig", (xy_gear.get("traits", []) as Array).size() >= 10, (xy_gear.get("traits", []) as Array).size())
	var xlogic := XBattleLogic.new()
	xlogic.setup(1, xs, XBattleRandom.create(str(xs.random_master)))
	var xe: XEnemy = xlogic.enemies[0]
	xe.add_param(0, 1.0e12)
	xe.param_mark_dirty()
	xe.recover_all()
	var xhp0: float = xe.hp
	var xr := xlogic.apply(xa, xy_sk9998, xe)
	check("xy.hit_extra.none", not xr.has("hit_extra") and not xr.has("extra") and is_equal_approx(xhp0 - xe.hp, minf(xhp0, float(xr.get("hp", 0.0)))),
		{"hit_extra": xr.get("hit_extra"), "extra": xr.get("extra"), "hp": xr.get("hp"), "loss": xhp0 - xe.hp})
	xlogic.end_battle(0)

	# 还原全局开关
	XTianqiBase.PHASE4 = was_phase4
	XTianqiSkills.HIT_EXTRA_ON = was_hit_extra
	XTianqiSkills.ACTOR_TRAITS_STRIP = was_strip
	XImportedBalance.RELEASE_XUFENG = was_rel
	XImportedBalance.XUFENG_TIANQI = was_tq
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
