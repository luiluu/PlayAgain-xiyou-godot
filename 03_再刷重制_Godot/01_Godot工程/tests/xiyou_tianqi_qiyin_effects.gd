extends Node
## 天启篇七印装备战斗效果（XTianqiQiyinEffects）专项：
## 一、认装备：mark 打标记、套装件数、2／3／5 档按件数生效、武器印记／真印追加／独有、不立文字刻一条、同码只取一条。
## 二、伤害乘区：白印 3 件看减益、灰印 2 件斩杀线、黑真印无视防御、天平技能 +33% 与消耗 ×2、夺和大刀承伤 +15%、神器全队只生效一件。
## 三、消耗、最大生命：黑印 2 件 −15%、殉印 2 件生命 +15%。
## 四、行动与回合：疫叠层与回合末结算、判决、免死、替挡、击倒再动、砝码与必暴、默印 5 件沉默、灰镰处决与不能复活。
## 五、开关关掉、原版档：一条都不生效；整回合实跑不报错。
## 用天启篇开局建的存档（艰险）打敌群 2；装备直接造实例、打标记。

const ARMOR_ID := 1
const WEAPON_ID := 1

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _logic(tianqi := true) -> XBattleLogic:
	var w := _ids()
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
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
	for id in lineup:
		s.actor(id).recover_all()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	return lg


## 给角色穿上七印装备：marks 是 mark() 的描述列表；套装件放防具格，武器放武器格
func _wear(a: XActor, marks: Array) -> void:
	a.keep_unequippable = true  # 夹具直接塞实例（部位、甲种不一定对得上），不让 refresh 卸掉
	var slot := 1
	for m in marks:
		var kind := "weapon" if str(m.kind) == "weapon" else "armor"
		var inst := XGear.create(kind, WEAPON_ID if kind == "weapon" else ARMOR_ID, a.state if "state" in a else XState.current)
		if inst.is_empty():
			inst = {"kind": kind, "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 1 if kind == "weapon" else 3}
		XTianqiQiyinEffects.mark(inst, m)
		if kind == "weapon":
			a.equips[0] = inst
		else:
			while slot < a.equips.size() - 1 and a.equips[slot] != null and not a.equips[slot].is_empty() and not XTianqiQiyinEffects.mark_of(a.equips[slot]).is_empty():
				slot += 1
			if slot >= a.equips.size():
				a.equips.append(inst)
			else:
				a.equips[slot] = inst
			slot += 1
	a.param_mark_dirty()
	a.param_refresh()


func _gear_set(seal: String, n: int, true_seal := false) -> Array:
	var parts := ["head", "body", "hands", "waist", "legs", "feet"]
	var out := []
	for i in n:
		out.append({"kind": "set", "seal": seal, "part": parts[i], "true_seal": true_seal})
	return out


func _hit(scope := 1, id := 99999, element := 0) -> Dictionary:
	return {"id": id, "scope": scope, "damage": {"type": 1, "elementId": element, "critical": true, "variance": 0, "formula": "1"}, "effects": [], "stypeId": 1, "mpCost": 100, "tpCost": 20}


func _final(ops: Array) -> float:
	var m := 1.0
	for o in ops:
		if str(o.field) == "finalMultiplier":
			m *= float(o.value)
	return m


func _fresh(lg: XBattleLogic) -> void:
	XTianqiQiyinEffects.start(lg)


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XTianqiQiyinGear.reload()
	_marks()
	_damage()
	_cost_hp()
	_actions()
	_burst_views()
	_switches()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _marks() -> void:
	var lg := _logic()
	var a: XActor = lg.actors[0]
	_wear(a, _gear_set("bai", 3) + _gear_set("hong", 2) + [{"kind": "weapon", "seal": "hei", "wtype": "gun", "true_seal": true}])
	var c := XTianqiQiyinEffects.set_counts(a)
	_check("count_bai3_hong2", int(c.get("bai", 0)) == 3 and int(c.get("hong", 0)) == 2, c)
	var fx := XTianqiQiyinEffects.fold(XTianqiQiyinEffects.gear_effects(a))
	_check("bai_2_3_on", fx.has("dot_dealt_pct") and fx.has("dmg_per_target_debuff_pct"), fx.keys())
	_check("bai_5_off", not fx.has("dot_extra_tick"))
	_check("hong_2_on_3_off", fx.has("aoe_skill_dmg_pct") and not fx.has("kill_stack_dmg_pct"))
	_check("gun_mark_true_unique", fx.has("single_action_dmg_pct") and fx.has("ignore_def_pct") and fx.has("mp_dump"), fx.keys())
	var m := {}
	XTianqiQiyinEffects.mark(m, {"kind": "weapon", "seal": "hei", "wtype": "拳套"})
	_check("weapon_key_by_cn_name", str(m.qiyin.key) == "yilijiangshihui", m)
	var rng := XRandomStream.create("0000000000000007", "qiyin_test")
	var mo := {}
	XTianqiQiyinEffects.mark(mo, {"kind": "weapon", "seal": "mo", "wtype": "sword"}, rng)
	_check("buliwenzi_engraves_other", str(mo.qiyin.key) == "buliwenzi" and XTianqiQiyinEffects.unique_pool().has(str(mo.qiyin.unique)) and XTianqiQiyinEffects.unique_pool().size() == 12, mo)
	var b: XActor = lg.actors[1]
	_wear(b, [{"kind": "weapon", "seal": "mo", "key": "buliwenzi", "unique": "zhige"}])
	var bfx := XTianqiQiyinEffects.fold(XTianqiQiyinEffects.gear_effects(b))
	_check("buliwenzi_mark_plus_borrowed", bfx.has("normal_attack_as_skill") and bfx.has("hit_count_burst") and not bfx.has("random_unique"), bfx.keys())
	var j := XTianqiQiyinEffects.fold([{"code": "judgment", "trigger": "on_hit", "max_hp_pct": 5}, {"code": "judgment", "trigger": "on_attack", "max_hp_pct": 5}, {"code": "max_hp_pct", "value": 15}, {"code": "max_hp_pct", "value": 99}])
	_check("fold_judgment_split_same_code_first", j.has("judgment:on_hit") and j.has("judgment:on_attack") and int(j.max_hp_pct.value) == 15, j.keys())


func _damage() -> void:
	var lg := _logic()
	var a: XActor = lg.actors[0]
	var e: XEnemy = lg.enemies[0]
	_fresh(lg)
	_check("no_gear_no_ops", XTianqiQiyinEffects.damage_ops(_hit(), a, e).is_empty())
	_wear(a, _gear_set("hui", 2))
	_fresh(lg)
	e.hp = e.mhp * 0.4
	_check("hui2_low_target", is_equal_approx(_final(XTianqiQiyinEffects.damage_ops(_hit(), a, e)), 1.15), XTianqiQiyinEffects.damage_ops(_hit(), a, e))
	e.hp = e.mhp
	_check("hui2_full_target", XTianqiQiyinEffects.damage_ops(_hit(), a, e).is_empty())
	var b: XActor = lg.actors[1]
	_wear(b, _gear_set("bai", 3))
	_fresh(lg)
	_check("bai3_no_debuff", XTianqiQiyinEffects.damage_ops(_hit(), b, e).is_empty())
	e.buffs[2] = -1
	e.buffs[3] = -1
	_check("bai3_two_debuffs", is_equal_approx(_final(XTianqiQiyinEffects.damage_ops(_hit(), b, e)), 1.1))
	e.buffs[2] = 0
	e.buffs[3] = 0
	var c: XActor = lg.actors[2]
	_wear(c, [{"kind": "weapon", "seal": "hei", "wtype": "fist", "true_seal": true}])
	_fresh(lg)
	var ops := XTianqiQiyinEffects.damage_ops(_hit(), c, e)
	_check("hei_true_ignore_def", ops.any(func(o): return str(o.field) == "physicalDefenseRate" and is_equal_approx(float(o.value), 0.67)), ops)
	# 神器：全队只生效出战顺序里第一个
	var d: XActor = lg.actors[3]
	_wear(d, [{"kind": "artifact", "key": "scales"}])
	_wear(c, [{"kind": "artifact", "key": "great_sword"}])
	_fresh(lg)
	var owner = lg.get_meta("xqiyin").artifact_owner
	_check("artifact_first_in_order", is_same(owner, c), owner)
	_check("great_sword_taken_up", is_equal_approx(_final(XTianqiQiyinEffects.damage_ops(_hit(), e, c)), 1.15))
	_check("scales_inactive_second", XTianqiQiyinEffects.damage_ops(_hit(), d, e).is_empty())
	_check("great_sword_kill_extra", XTianqiQiyinEffects.effects(lg, c).has("kill_extra_action"))


func _cost_hp() -> void:
	var lg := _logic()
	var a: XActor = lg.actors[0]
	var mhp0 := a.mhp
	_wear(a, _gear_set("hei", 2) + _gear_set("xun", 2))
	_fresh(lg)
	var cost := XTianqiQiyinEffects.cost(a, _hit(), {"mp": 100, "tp": 20})
	_check("hei2_cost", int(cost.mp) == 85 and int(cost.tp) == 17, cost)
	_check("xun2_mhp_rate", is_equal_approx(XTianqiQiyinEffects.param_rate(a, 0), 1.15) and is_equal_approx(XTianqiQiyinEffects.param_rate(a, 2), 1.0))
	_check("xun2_mhp_applied", a.mhp > mhp0, [mhp0, a.mhp])
	var b: XActor = lg.actors[1]
	_wear(b, [{"kind": "artifact", "key": "scales"}])
	_fresh(lg)
	_check("scales_cost_double", int(XTianqiQiyinEffects.cost(b, _hit(), {"mp": 100, "tp": 20}).mp) == 200)
	_check("scales_skill_dmg", is_equal_approx(_final(XTianqiQiyinEffects.damage_ops(_hit(), b, lg.enemies[0])), 1.33))


func _actions() -> void:
	var lg := _logic()
	var a: XActor = lg.actors[0]
	var e: XEnemy = lg.enemies[0]
	# 疫：命中叠层，回合末按物攻 10% × 层数
	_wear(a, [{"kind": "weapon", "seal": "bai", "wtype": "hidden"}])
	_fresh(lg)
	var sk := _hit()
	XTianqiQiyinEffects.begin_action(lg, a, sk)
	XTianqiQiyinEffects.after_apply(lg, a, sk, e, {"hp": 100.0})
	XTianqiQiyinEffects.after_apply(lg, a, sk, e, {"hp": 100.0})
	_check("plague_two_stacks", XTianqiQiyinEffects.plague_of(lg, e) == 2)
	XTianqiQiyinEffects.end_action(lg, a, sk)
	var hp0 := e.hp
	XTianqiQiyinEffects.end_turn(lg)
	var expect := floorf(a.atk * 0.1 * 2)
	_check("plague_tick", is_equal_approx(hp0 - e.hp, expect) or (e.shield > 0.0), [hp0 - e.hp, expect])
	# 判决：攻击时追加最大生命 5%
	var b: XActor = lg.actors[1]
	_wear(b, [{"kind": "weapon", "seal": "xun", "wtype": "blunt"}])
	_fresh(lg)
	e.recover_all()
	e.shield = 0.0
	b.hp = b.mhp
	hp0 = e.hp
	XTianqiQiyinEffects.begin_action(lg, b, sk)
	XTianqiQiyinEffects.after_apply(lg, b, sk, e, {"hp": 1.0})
	XTianqiQiyinEffects.after_apply(lg, b, sk, e, {"hp": 1.0})
	_check("judgment_once_per_target", is_equal_approx(hp0 - e.hp, floorf(b.mhp * 0.05)), [hp0 - e.hp, b.mhp])
	XTianqiQiyinEffects.end_action(lg, b, sk)
	# 免死（灰印 5 件）一场一次
	var c: XActor = lg.actors[2]
	_wear(c, _gear_set("hui", 5))
	_fresh(lg)
	c.recover_all()
	c.shield = 0.0
	var v := XTianqiQiyinEffects.hp_damage(lg, e, c, c.hp + 999.0)
	_check("cheat_death_leaves_1", is_equal_approx(v, c.hp - 1.0), [v, c.hp])
	_check("cheat_death_once", is_equal_approx(XTianqiQiyinEffects.hp_damage(lg, e, c, c.hp + 999.0), c.hp + 999.0))
	XTianqiQiyinEffects.doom_kill = true
	_fresh(lg)
	_check("cheat_death_not_vs_doom", is_equal_approx(XTianqiQiyinEffects.hp_damage(lg, e, c, c.hp + 999.0), c.hp + 999.0))
	XTianqiQiyinEffects.doom_kill = false
	# 替挡（殉印 3 件）：生命最低的队友挨打，持有者挡一半
	var g: XActor = lg.actors[3]
	_wear(g, _gear_set("xun", 3))
	_fresh(lg)
	for x in lg.actors:
		x.param_mark_dirty()
		x.param_refresh()
		x.refresh_resources()
		x.recover_all()
		x.shield = 0.0
	var low: XActor = lg.actors[0]
	low.hp = low.mhp * 0.2
	var g0 := g.hp
	var got := XTianqiQiyinEffects.hp_damage(lg, e, low, 100.0)
	_check("guard_half", is_equal_approx(got, 50.0) and is_equal_approx(g0 - g.hp, 50.0), [got, g0 - g.hp])
	# 击倒后再行动（红印 5 件）每回合一次
	var h: XActor = lg.actors[1]
	_wear(h, _gear_set("hong", 5))
	_fresh(lg)
	var e2: XEnemy = lg.enemies[0]
	e2.recover_all()
	XTianqiQiyinEffects.begin_action(lg, h, sk)
	e2.hp = 0.0
	lg._die(e2)
	XTianqiQiyinEffects.after_apply(lg, h, sk, e2, {"hp": 10.0, "state_value": 10.0})
	lg.current_order.clear()
	XTianqiQiyinEffects.end_action(lg, h, sk)
	_check("kill_extra_action", lg.current_order.size() == 1 and is_same(lg.current_order[0], h), lg.current_order.size())
	_check("kill_stack_counted", int(lg.get_meta("xqiyin").units[h].kills) == 1)
	# 砝码（黑印 3、5 件）：回合开始得层，满 5 层必暴、暴伤 +50%
	var w: XActor = lg.actors[2]
	_wear(w, _gear_set("hei", 5))
	_fresh(lg)
	for i in 5:
		XTianqiQiyinEffects.start_turn(lg)
	_check("weights_capped_5", int(lg.get_meta("xqiyin").units[w].weights) == 5)
	var en: XEnemy = lg.enemies[-1]
	en.recover_all()
	XTianqiQiyinEffects.begin_action(lg, w, sk)
	var wops := XTianqiQiyinEffects.damage_ops(sk, w, en)
	_check("weights_dmg_crit", is_equal_approx(_final(wops), 1.75) and wops.any(func(o): return str(o.field) == "criticalAdd") and XTianqiQiyinEffects.cri(lg, w, 0.1) == 1.0, wops)
	XTianqiQiyinEffects.end_action(lg, w, sk)
	_check("weights_spent", int(lg.get_meta("xqiyin").units[w].weights) == 0)
	# 默印 5 件：敌方沉默
	var m: XActor = lg.actors[4] if lg.actors.size() > 4 else lg.actors[3]
	_wear(m, _gear_set("mo", 5))
	_fresh(lg)
	_check("silence_all", XTianqiQiyinEffects.use_silence_all(lg, m) and XTianqiQiyinEffects.silenced(lg, en))
	_check("silence_once", not XTianqiQiyinEffects.use_silence_all(lg, m))
	_check("silence_blocks_skill", not lg.can_use(en, {"id": 99999, "occasion": 0, "stypeId": 1, "damage": {"type": 1}}))
	# 灰镰：处决普通敌人；不能复活
	var s2: XActor = lg.actors[0]
	_wear(s2, [{"kind": "artifact", "key": "grey_scythe"}])
	lg.remove_meta("xqiyin")
	for x in lg.actors:
		if x != s2:
			for i in x.equips.size():
				if x.equips[i] != null and XTianqiQiyinEffects.mark_of(x.equips[i]).get("kind", "") == "artifact":
					x.equips[i] = {}
	_fresh(lg)
	var mob: XEnemy = null
	for x in lg.enemies:
		x.recover_all()
		if not XBossStatus.is_boss(x):
			mob = x
	if mob != null:
		mob.hp = mob.mhp * 0.1
		XTianqiQiyinEffects.begin_action(lg, s2, sk)
		XTianqiQiyinEffects.after_apply(lg, s2, sk, mob, {"hp": 1.0})
		XTianqiQiyinEffects.end_action(lg, s2, sk)
		_check("scythe_execute", mob.is_dead())
	_check("scythe_no_revive", XTianqiQiyinEffects.blocks_revive(s2))


func _switches() -> void:
	# 整回合实跑：全队穿满不报错
	var lg := _logic()
	var sets := ["bai", "hong", "hei", "hui", "xun"]
	var types := ["bow", "sword", "gun", "katana", "spear"]
	for i in mini(5, lg.actors.size()):
		_wear(lg.actors[i], _gear_set(sets[i], 5) + [{"kind": "weapon", "seal": sets[i], "wtype": types[i], "true_seal": true}])
	_fresh(lg)
	var t0 := lg.turn
	for k in 3:
		if lg.is_over():
			break
		lg.run_turn({})
	_check("run_turns_ok", lg.turn > t0, lg.turn)
	lg.end_battle(0)
	_check("finish_clears", not lg.has_meta("xqiyin"))
	# 开关关掉
	XTianqiQiyinEffects.ENABLED = false
	var lg2 := _logic()
	var a: XActor = lg2.actors[0]
	_wear(a, _gear_set("hui", 2) + _gear_set("xun", 2))
	_fresh(lg2)
	lg2.enemies[0].hp = lg2.enemies[0].mhp * 0.2
	_check("off_no_store", not lg2.has_meta("xqiyin"))
	_check("off_no_ops", XTianqiQiyinEffects.damage_ops(_hit(), a, lg2.enemies[0]).is_empty())
	_check("off_param_rate", XTianqiQiyinEffects.param_rate(a, 0) == 1.0)
	XTianqiQiyinEffects.ENABLED = true
	# 原版档
	var lg3 := _logic(false)
	var b: XActor = lg3.actors[0]
	_wear(b, _gear_set("hui", 2))
	_fresh(lg3)
	_check("legacy_no_store", not lg3.has_meta("xqiyin"))
	_check("legacy_cost_unchanged", XTianqiQiyinEffects.cost_mult(b, _hit()) == 1.0)


## 评审 v0.1 第 8 条（gpt 核查返修）：攒段横扫多段打同一目标，走整次行动时每段命中的画面快照是那一段打完的血量
func _burst_views() -> void:
	var lg := _logic()
	var u: XActor = lg.actors[0]
	_wear(u, [{"kind": "weapon", "seal": "mo", "key": "buliwenzi", "unique": "zhige"}])
	_fresh(lg)
	var e: XEnemy = lg.enemies[0]
	for x in lg.enemies:
		x.recover_all()
		x.shield = 0.0
	XTianqiQiyinEffects._unit(lg, u).burst = 1
	lg.current_order.clear()
	var logs := lg.act(u, u.attack_skill(), e)
	var hits := logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("target"), e) and float(l.get("hp", 0.0)) > 0.0)
	var hps := hits.map(func(l): return float(l.get("views", {}).get(e, {}).get("hp", -1.0)))
	var down := hps.size() >= 3 and not hps.has(-1.0)
	for i in range(1, hps.size()):
		down = down and hps[i] < hps[i - 1]
	_check("review8_burst_views_each_hit", down, hps)
	_check("review8_burst_first_not_final", hps.size() >= 2 and hps[0] > e.hp, [hps, e.hp])
	lg.end_battle(0)
