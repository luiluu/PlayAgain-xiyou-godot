extends Node
## 天启四骑士实战专项（XTianqiHorsemen、horsemen.json 接进 BattleLogic）：四位骑士各打几回合，看规则真的生效。
## 一、开战：整组换成骑士＋援军／小怪位子，能力值照本档、不是神话、不吃霸体、免疫控制和即死、不掉东西。
## 二、死亡·勇者：宝石叠攻防血、每回合 2 动最后出手、第 5 回合死期带走一人且本场不能复活、神圣剑、暴击免疫、逃跑失败并变身骑士队长。
## 三、战争·莉co：开场援军 3 只、再动、火花、号令、碎甲降最大生命、骑士倒下援军一起散。
## 四、饥荒·小镇做题家：开场 3 只小怪、结党吞小怪并饿出新的、资历、绝粮挡回蓝回 TP。
## 五、瘟疫·混子：疫病降属性、每回合掉血、治疗减半、嘲讽只能打混子、减伤、不服、盾。
## 六、原版档、开关关掉：照原版敌群，一处都不动。
## 七、评审 v0.1 第 1、2 条（cc/tianqi-review-fixes）：破产一剑是法术，破产标记要降法防才对这一击起作用；宝石加攻后的追加普攻当场读新攻。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a: float, b: float, eps := 1e-6) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


## 天启篇存档、5 个弱者；每人加厚生命和防御，好看几回合的规则（骑士 36 层的攻击打 1 级角色一下就倒）
func _state(key: String, tough := 20000000.0) -> XState:
	var w := _ids(XTier.WEAK)
	var lineup := w.slice(0, 5)
	var s := XTianqi.start_new_game(3, key, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		var a := s.actor(id)
		a.add_param(0, tough)
		a.add_param(3, 10000.0)
		a.add_param(5, 10000.0)
		a.recover_all()
	return s


func _logic(line: String, key := "jianxian", tough := 20000000.0) -> XBattleLogic:
	var s := _state(key, tough)
	XTianqiHorsemen.prepare(line, s)
	var lg := XBattleLogic.new()
	lg.setup(0, s)
	return lg


## 战斗外直接结算一段生命伤害（executeHpDamage 要一份行动资源）
func _hp(lg: XBattleLogic, u, t, v: float) -> void:
	lg._action_resources = lg._new_lifecycle_resources()
	lg.execute_hp_damage(u, t, v, false)
	lg._action_resources = null


## 我方这回合都防御（看骑士出手不被我方输出打乱）
func _guard_all(lg: XBattleLogic) -> Dictionary:
	var c := {}
	for a in lg.actors:
		c[a] = [XDB.rec("Skills", 2), null]
	return c


func _run() -> void:
	XMessageBox.auto = true
	seed(20261111)
	_setup_common()
	_death()
	_war()
	_famine()
	_plague()
	_plain()
	_review_fixes()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _setup_common() -> void:
	for line in XTianqiHorsemen.LINES:
		for key in ["jianxian", "zhengdao"]:
			var lg := _logic(line, key)
			var kn: XEnemy = lg.enemies[0]
			var st := XTianqiHorsemen.stats(line, key)
			var tag := "%s_%s" % [line, key]
			_check("knight_" + tag, XTianqiHorsemen.is_knight(lg, kn) and kn.display_name() == st.name, kn.display_name())
			_check("mhp_" + tag, _near(kn.mhp, float(st.hp)), [kn.mhp, st.hp])
			_check("atk_" + tag, _near(kn.atk, float(st.atk)) and _near(kn.mat, float(st.mat)) and _near(kn.def, float(st.def)), [kn.atk, kn.mat, kn.def])
			_check("no_elite_armor_" + tag, not kn.elite and not kn.boss_difficulty_boss and not kn.boss_hyper_armor)
			_check("no_rewards_" + tag, kn.exp_reward() == 0 and kn.gold_reward() == 0 and lg.drops_of(kn).is_empty())
	# 免疫停手的控制、即死；普通敌人照挂
	var lg0 := _logic("death")
	var kn0: XEnemy = lg0.enemies[0]
	kn0.add_state(124)
	kn0.add_state(1)
	_check("immune_control_death", not kn0.is_state_affected(124) and kn0.is_alive())
	_check("adds_none_death", lg0.enemies.size() == 1)
	# 霸体：偶数回合不上 2651
	lg0.run_turn(_guard_all(lg0))
	lg0.run_turn(_guard_all(lg0))
	_check("no_hyper_armor_turn2", not kn0.is_state_affected(XEnemy.BOSS_ARMOR_STATE))
	lg0.end_battle(0)
	_check("end_clears", not lg0.has_meta(XTianqiHorsemen.META) and XTianqiHorsemen.active_logic() == null)


func _death() -> void:
	var lg := _logic("death")
	var kn: XEnemy = lg.enemies[0]
	var atk0 := kn.atk
	var def0 := kn.def
	var hp0 := kn.mhp
	lg.run_turn(_guard_all(lg))
	var f := XTianqiHorsemen.fight(lg)
	_check("death_two_gems_turn1", int(f.gems) == 2 and int(f.unique) == 2, f.gems)
	_check("death_red_blue", _near(kn.atk, atk0 + roundf(atk0 * 0.06)) and _near(kn.def, def0 + roundf(def0 * 0.06)), [kn.atk, kn.def])
	lg.run_turn(_guard_all(lg))
	_check("death_holy_water", _near(kn.mhp, hp0 + hp0 * 0.03), [kn.mhp, hp0])
	# 暴击免疫
	_check("death_crit_immune", lg.item_cri(lg.actors[0], XDB.rec("Skills", 1), kn) == 0.0)
	# 敏捷 0：每回合最后出手
	_check("death_agi_zero", kn.agi == 0.0)
	# 第 4 回合开始亮出神圣剑目标，第 5 回合死期挂上、回合末带走
	lg.run_turn(_guard_all(lg))
	lg.run_turn(_guard_all(lg))
	_check("death_sword_target", f.sword_target != null, f.sword_target)
	var before_alive := lg.alive(lg.actors).size()
	var logs := lg.run_turn(_guard_all(lg))
	var swords := logs.filter(func(l): return l.type == "hit" and str(l.skill.get("tianqi_horseman", "")) == "holy_sword")
	_check("death_holy_sword_hits", swords.size() >= 9, swords.size())  # 第 5 回合：前 4 回合 8 颗宝石＋本回合 1 颗
	var dead := lg.actors.filter(func(a): return a.is_dead())
	_check("death_doom_killed", dead.size() >= 1 and lg.alive(lg.actors).size() < before_alive, [before_alive, lg.alive(lg.actors).size()])
	if not dead.is_empty():
		var d: XActor = dead[0]
		_check("death_doom_mark", bool(XTianqiHorsemen.mark_of(lg, d).get("no_revive", false)))
		d.remove_state(1)
		_check("death_no_revive", d.is_dead())
	# 逃跑：必定失败，没变身的当场变身骑士队长
	_check("death_escape_fails", not lg.try_escape() and bool(f.captain) and not lg.can_escape)
	_check("death_captain_atk", kn.atk > atk0 * 1.33, [kn.atk, atk0])
	# 第二阶段（66% 以下）：接管变身；第三阶段：终末叠层，满 5 层放「现在一切结束了」
	var lg2 := _logic("death")
	var k2: XEnemy = lg2.enemies[0]
	k2.hp = k2.mhp * 0.3
	lg2.run_turn(_guard_all(lg2))
	var f2 := XTianqiHorsemen.fight(lg2)
	_check("death_phase3", int(f2.phase) == 3 and bool(f2.captain) and int(f2.finale) == 1, [f2.phase, f2.finale])
	for i in range(4):
		lg2.run_turn(_guard_all(lg2))
	var l6 := lg2.run_turn(_guard_all(lg2))
	var fin := l6.filter(func(l): return l.type == "hit" and str(l.skill.get("tianqi_horseman", "")) == "finale")
	_check("death_finale_cast", fin.size() >= 1 and int(f2.finale) <= 1, [fin.size(), f2.finale])
	lg2.end_battle(0)
	lg.end_battle(0)


func _war() -> void:
	var lg := _logic("war")
	var kn: XEnemy = lg.enemies[0]
	var f := XTianqiHorsemen.fight(lg)
	var adds: Array = f.adds
	_check("war_slots", adds.size() == 5)
	_check("war_first_wave", lg.alive(adds).size() == 3, lg.alive(adds).size())
	_check("war_extra_action", lg.make_action_times(kn) == 3, lg.make_action_times(kn))
	_check("war_agi", kn.agi > 0.0)
	lg.run_turn(_guard_all(lg))
	_check("war_sparks", int(f.sparks) >= 3, f.sparks)
	# 号令：打倒一只援军莉co立刻 +3 火花
	var s0 := int(f.sparks)
	var e: XEnemy = lg.alive(adds)[0]
	e.hp = 0.0
	e.refresh_resources()
	lg._die(e)
	lg.act(lg.actors[0], XDB.rec("Skills", 2), null)
	_check("war_rally", int(f.sparks) == s0 + 3, [s0, f.sparks])
	_check("war_extra_two_adds", lg.make_action_times(kn) == 3, lg.make_action_times(kn))
	var e2: XEnemy = lg.alive(adds)[0]
	e2.hp = 0.0
	e2.refresh_resources()
	lg._die(e2)
	lg.act(lg.actors[0], XDB.rec("Skills", 2), null)
	_check("war_extra_one_add", lg.make_action_times(kn) == 2, lg.make_action_times(kn))
	# 第 4 回合补一波（场上 1 只，补 3 只到 4 只），再动 +2
	lg.run_turn(_guard_all(lg))
	lg.run_turn(_guard_all(lg))
	lg.run_turn(_guard_all(lg))
	_check("war_second_wave", lg.alive(adds).size() == 4, lg.alive(adds).size())
	_check("war_extra_four_adds", lg.make_action_times(kn) == 4)
	# 碎甲（第 2 层配方，血量 83% 以下）：雷火弹命中降最大生命
	var lg2 := _logic("war")
	var k2: XEnemy = lg2.enemies[0]
	var f2 := XTianqiHorsemen.fight(lg2)
	k2.hp = k2.mhp * 0.6
	f2.sparks = 6
	var a0: XActor = lg2.actors[0]
	var mhp0 := a0.mhp
	lg2.run_turn(_guard_all(lg2))
	_check("war_layer3", int(f2.layer) == 3, f2.layer)
	_check("war_shrapnel_mhp", a0.mhp < mhp0 and int(XTianqiHorsemen.mark_of(lg2, a0).get("shrapnel", 0)) > 0, [a0.mhp, mhp0])
	# 火花满 20：漫天烟火
	f2.sparks = 20
	f2.cd.clear()
	var logs := lg2.run_turn(_guard_all(lg2))
	_check("war_fireworks", logs.any(func(l): return l.type == "action" and str(l.skill.get("tianqi_horseman", "")) == "fireworks"))
	# 骑士倒下：援军一起散，战斗胜利
	var atk: XActor = lg2.actors.filter(func(a): return a.is_alive())[0]
	k2.hp = 0.0
	k2.refresh_resources()
	lg2._die(k2)
	lg2.act(atk, XDB.rec("Skills", 2), null)
	_check("war_win_when_knight_down", lg2.is_won(), lg2.alive(lg2.enemies).size())
	lg2.end_battle(0)
	lg.end_battle(0)


func _famine() -> void:
	var lg := _logic("famine")
	var f := XTianqiHorsemen.fight(lg)
	_check("famine_adds", lg.alive(f.adds).size() == 3)
	# 绝粮：MP、TP 在战斗中不能恢复
	var a: XActor = lg.actors[0]
	a.mp = 0.0
	a.tp = 0.0
	var res := XResourceContext.new()
	res.gain(a, "mp", 50.0)
	res.gain(a, "tp", 50.0)
	_check("famine_starved", a.mp == 0.0 and a.tp == 0.0, [a.mp, a.tp])
	# 结党：每回合两次技能各吞一只小怪 50%，两口就死，饿出新的，资历 +1
	lg.run_turn(_guard_all(lg))
	_check("famine_devour", int(f.seniority) >= 1, f.seniority)
	_check("famine_adds_refilled", lg.alive(f.adds).size() == 3, lg.alive(f.adds).size())
	_check("famine_seen", lg.actors.any(func(x): return int(XTianqiHorsemen.mark_of(lg, x).get("seen", 0)) > 0))
	# 识破：防御 −22%
	var seen: Array = lg.actors.filter(func(x): return int(XTianqiHorsemen.mark_of(lg, x).get("seen", 0)) > 0)
	var t: XActor = seen[0]
	var m: Dictionary = XTianqiHorsemen.mark_of(lg, t)
	var d1 := t.def
	m.seen = 0
	t.param_mark_dirty()
	var d0 := t.def
	_check("famine_seen_def", absf(d1 - roundf(d0 * 0.78)) <= 1.0, [d0, d1])
	# 资历 5 → 第二阶段（第 3 回合放破产一剑），10 → 第三阶段（全属性 +33%）
	f.seniority = 5
	var mat0: float = lg.enemies[0].mat
	lg.run_turn(_guard_all(lg))
	lg.run_turn(_guard_all(lg))
	_check("famine_phase2", int(f.phase) >= 2 and bool(f.broke1))
	f.seniority = 10
	lg.run_turn(_guard_all(lg))
	_check("famine_phase3", int(f.phase) == 3 and lg.enemies[0].mat > mat0 * 1.3, [f.phase, lg.enemies[0].mat, mat0])
	var logs := lg.run_turn(_guard_all(lg))
	logs.append_array(lg.run_turn(_guard_all(lg)))
	logs.append_array(lg.run_turn(_guard_all(lg)))
	_check("famine_sword_rain", logs.any(func(l): return l.type == "action" and str(l.skill.get("tianqi_horseman", "")) == "sword_rain"))
	lg.end_battle(0)
	res = XResourceContext.new()
	a.mp = 0.0
	res.gain(a, "mp", 50.0)
	_check("famine_starved_only_in_battle", a.mp > 0.0, a.mp)


func _plague() -> void:
	var lg := _logic("plague")
	var kn: XEnemy = lg.enemies[0]
	var f := XTianqiHorsemen.fight(lg)
	var a: XActor = lg.actors[0]
	_check("plague_marked", lg.actors.all(func(x): return bool(XTianqiHorsemen.mark_of(lg, x).get("plague", false))))
	# 疫病开局 −10%、病弱：疫病＋嘲讽两个减益 −6%
	var m: Dictionary = XTianqiHorsemen.mark_of(lg, a)
	var atk1 := a.atk
	m.erase("plague")
	a.param_mark_dirty()
	var atk0 := a.atk
	m.plague = true
	a.param_mark_dirty()
	_check("plague_down_start", absf(atk1 - roundf(atk0 * 0.9 * 0.94)) <= 1.0, [atk0, atk1])
	# 嘲讽：我方打敌人的技能只能打混子；打到混子的伤害 ×(1−11%)×(1−22%)
	_check("plague_taunt_mult", _near(XTianqiHorsemen.taken_mult(kn), 0.89 * 0.78))
	_check("plague_taunt_targets", lg.targets_for(a, XDB.rec("Skills", 1), null) == [kn])
	# 治疗减半
	a.hp = a.mhp * 0.5
	var hp0 := a.hp
	_hp(lg, a, a, -1000.0)
	_check("plague_heal_half", _near(a.hp - hp0, 500.0), a.hp - hp0)
	# 回合末：每人掉 5% 最大生命，疫病降属性再 −5%
	a.recover_all()
	var mhp := a.mhp
	var tlogs := lg.run_turn(_guard_all(lg))
	_check("plague_dot", tlogs.any(func(l): return l.type == "regen" and is_same(l.target, a) and _near(float(l.hp), floorf(mhp * 0.05))), mhp)
	_check("plague_down_grow", _near(float(f.plague_down), 0.15), f.plague_down)
	for i in range(8):
		lg.run_turn(_guard_all(lg))
	_check("plague_down_cap", _near(float(f.plague_down), 0.33), f.plague_down)
	# 打混子：每次行动 +1 不服
	var attacker: XActor = lg.alive(lg.actors)[0]
	var mk: Dictionary = XTianqiHorsemen.mark_of(lg, attacker)
	mk.defiance = 0
	var tries := 0
	while int(mk.get("defiance", 0)) == 0 and tries < 8:  # 普通攻击可能没打中，多打几下
		lg.act(attacker, XDB.rec("Skills", 1), kn)
		tries += 1
	_check("plague_defiance", int(mk.get("defiance", 0)) == 1, [mk.get("defiance"), tries])
	# 第二阶段：盾累计到 22% 就碎，下一回合嘲讽解除
	kn.hp = kn.mhp * 0.6
	lg.run_turn(_guard_all(lg))
	_check("plague_phase2", int(f.phase) == 2 and bool(f.shield_open))
	_hp(lg, attacker, kn, kn.mhp * 0.23)
	_check("plague_shield_break", int(f.broken_turn) == lg.turn, [f.broken_turn, lg.turn])
	lg.run_turn(_guard_all(lg))
	_check("plague_taunt_off", not bool(f.taunt) and _near(XTianqiHorsemen.taken_mult(kn), 0.89))
	lg.run_turn(_guard_all(lg))
	_check("plague_taunt_back", bool(f.taunt))
	lg.end_battle(0)
	a.param_mark_dirty()
	# 战斗结束：疫病等标记不带出战斗（开战状态的加成也随战斗结束去掉，所以不和战斗中的数比）
	_check("plague_cleared_after", XTianqiHorsemen.actor_param(a, 2, 100.0) == 100.0 and XTianqiHorsemen.mark_of(lg, a).is_empty())


func _plain() -> void:
	# 原版档：prepare 不收，开战照原版敌群
	var s := XState.new_game_blank()
	for id in _ids(XTier.WEAK).slice(0, 4):
		s.add_actor(int(id))
	XState.current = s
	_check("plain_prepare", not XTianqiHorsemen.prepare("war", s))
	var lg := XBattleLogic.new()
	lg.setup(1, s)
	_check("plain_troop", not lg.has_meta(XTianqiHorsemen.META) and lg.enemies.all(func(e): return e.horseman.is_empty()))
	lg.end_battle(0)
	# 天启篇存档没 prepare：照原版敌群
	var s2 := _state("jianxian")
	var lg2 := XBattleLogic.new()
	lg2.setup(1, s2)
	_check("tianqi_no_prepare", not lg2.has_meta(XTianqiHorsemen.META) and not lg2.enemies.is_empty())
	lg2.end_battle(0)
	# 开关关掉：prepare 过也不换
	var s3 := _state("jianxian")
	XTianqiHorsemen.prepare("war", s3)
	XTianqiHorsemen.ENABLED = false
	var lg3 := XBattleLogic.new()
	lg3.setup(1, s3)
	XTianqiHorsemen.ENABLED = true
	_check("switch_off", not lg3.has_meta(XTianqiHorsemen.META))
	lg3.end_battle(0)


## 七、评审 v0.1 第 1、2 条：各跑开关开、关两遍，关着时复现原问题
func _review_fixes() -> void:
	var famine := XTianqiHorsemen.knight("famine")
	var keep := 1.0 - float(famine.bankrupt.def_down)
	for on in [true, false]:
		XTianqiHorsemen.BANKRUPT_MDF = on
		var tag := "on" if on else "off"
		var lg := _logic("famine")
		var f := XTianqiHorsemen.fight(lg)
		var kn: XEnemy = lg.enemies[0]
		for e in f.adds:  # 去掉小怪：不结党，倍率只剩资历
			e.hp = 0.0
			e.refresh_resources()
			lg._die(e)
		var t: XActor = lg.actors[0]
		var mdf0 := t.mdf
		var sk := XTianqiHorsemen._skill("bankrupt", "仙法：破产一剑", 1, 1, float(famine.bankrupt.coef), true)
		var mult := 1.0 + float(famine.seniority.per) * int(f.seniority)
		var base := kn.mat * float(sk.coef) * mult
		# 不挂破产的同一击（法术、打法防）
		var plain: float = XTianqiHorsemen._strike(lg, kn, t, sk, base, false).hp
		t.hp = t.mhp
		var logs := XTianqiHorsemen._famine_perform(lg, f, kn, sk, t)
		var hits := logs.filter(func(l): return l.type == "hit" and is_same(l.target, t))
		var hp: float = hits[0].hp if not hits.is_empty() else -1.0
		var want := plain * XTianqiHorsemen.hit_value(kn.mat, roundf(mdf0 * keep), base, 1.0) / maxf(1.0, XTianqiHorsemen.hit_value(kn.mat, mdf0, base, 1.0))
		if on:
			_check("review1_bankrupt_hits_mdf_" + tag, hp > plain and absf(hp - want) <= maxf(2.0, want * 0.01), [hp, plain, want, mdf0])
		else:
			_check("review1_bankrupt_mark_useless_" + tag, absf(hp - plain) <= 1.0, [hp, plain])
		_check("review1_bankrupt_cleared_" + tag, not XTianqiHorsemen.mark_of(lg, t).has("bankrupt") and _near(t.mdf, mdf0), [t.mdf, mdf0])
		lg.end_battle(0)
	XTianqiHorsemen.BANKRUPT_MDF = true
	# 第 2 条：红宝石加攻后，同一行动里的追加普攻读攻击（_follow_up 读 u.atk）
	for on in [true, false]:
		XTianqiHorsemen.FRESH_PARAM = on
		var tag := "on" if on else "off"
		var lg := _logic("death")
		var kn: XEnemy = lg.enemies[0]
		var atk0 := kn.atk  # 读一次：缓存格变热
		var logs := XTianqiHorsemen.perform(lg, kn, XTianqiHorsemen._skill("red", "红宝石", 1, 1, 0.0, false), null)
		var follow := logs.any(func(l): return l.type == "hit" and str(l.skill.get("tianqi_horseman", "")) == "follow")
		var atk1 := kn.atk  # 追加普攻同一时刻读的就是它
		if on:
			_check("review2_red_fresh_atk_" + tag, follow and atk1 > atk0, [follow, atk0, atk1])
		else:
			_check("review2_red_stale_atk_" + tag, follow and _near(atk1, atk0), [follow, atk0, atk1])
		lg.end_battle(0)
	XTianqiHorsemen.FRESH_PARAM = true
