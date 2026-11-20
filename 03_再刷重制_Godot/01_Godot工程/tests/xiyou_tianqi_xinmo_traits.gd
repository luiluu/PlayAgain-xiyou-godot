extends Node
## 【cc·T318】天启篇心魔特点 a1（XTianqiXinmoTraits，T316 设计 v0.3；Kyo 11-20「245按推荐」）：
## 〇、挂法：按 trial.target 挂一条（1 沾尘、2 透骨、3 逆流；4～6 还没接不挂）；开场报特点；战前提示；非烙印试炼、西游档、ENABLED=false 不挂。
## 一、沾尘：心魔命中按几率挂 1 级弱化（同一行动对同一人只判一次、已弱化只刷新回合），减益 ≥2 项时心魔伤害 112%；回复、空 item 不乱乘。
## 二、透骨：打掉生命叠骨裂（上限 3）、每层 +8%；防御或护盾全挡消 1 层；被控时防御不算；回合末倒计时清零。
## 三、逆流：高血受疗 50%（已有虚不受补的不再减）、低血 115%；回合末冲刷 >60% 的人（扣 8% 现血、6% 最大魔法，不致死、不涨印纹），
##     下回合心魔伤害 +5%／人（封顶 20%）；心魔倒了不冲刷。
## 四、挂点：增伤在 execute_hp_damage 里生效；end_battle 清状态。
## 【cc·T319】a2：五、盗形（双数回合只剥安全临时增益、每人 1 项最多 2 项、无可剥自凝、攻增伤减、挑战者清醒命中震碎 1／带减益 2、倒计时）；
## 六、影劫（映照挑战者最新伤害招、控招诱影、兜底、合成技能不是普攻号只打 1 段、分档、护栏按整次行动累计、削势、高势主动招加印纹、被控消散）；
## 七、同堕（存活队伍均烙印共鸣、双数引纹防御／全盾断、满槽当场发作只叠 1 层、单回合 +2、135% 封顶、挑战者清醒镇压、发作不镇压、不改选目标）；
## 八、保命回归：号卷四号、灰印免死、临终在后三条倍率下照样留 1 点；九、T318 核查 P2-1／P2-2 与 P3 三条。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	XEnemy.force_roll = 100.0
	seed(20261120)
	_check("default_on", XTianqiXinmoTraits.ENABLED)
	_table()
	_mount()
	_zhanchen()
	_tougu()
	_niliu()
	_wiring()
	_rollback()
	_t318_fixes()
	_daoxing()
	_yingjie()
	_tongduo()
	_saves()
	_wiring_a2()
	XTianqiXinmoTraits.force_roll = -1.0
	XTianqiXinmoTraits.force_param = -1
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(passed_floor: int, tianqi := true) -> XState:
	var lineup := [1, 2, 8, 9, 10]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
		for id in lineup:
			XTianqi._joining = true
			s.add_actor(int(id))
			XTianqi._joining = false
	else:
		s = XState.new_game(3, 1, [2, 8, 9, 10])
	s.map_id = 4
	s.set_variable(20, passed_floor + 1)
	XState.current = s
	return s


## 按 XZhenqi._brand_trial 开心魔战（target＝要立的段）
func _xinmo(target: int, tianqi := true, brand := true, passed_floor := 10) -> XBattleLogic:
	var s := _state(passed_floor, tianqi)
	var actor_id := 2
	var troop := int(XZhenqi.TRIAL_TROOP["心魔"])
	var t := {"actorId": actor_id, "target": target, "ref": XZhenqi.trial_ref(s, 1), "kind": "心魔", "troopId": troop}
	if brand:
		t["brand"] = true
	XZhenqi.pending_trial = t
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	return logic


func _full(lg: XBattleLogic) -> void:
	for a in lg.actors:
		a.hp = a.mhp
		a.mp = a.mmp


func _texts(logs: Array) -> Array:
	return logs.filter(func(l): return str(l.get("type", "")) == "battle_text").map(func(l): return str(l.text))


func _table() -> void:
	XTianqiXinmoTraits.clear_cache()
	var tr: Dictionary = XTianqiXinmoTraits.data().get("traits", {})
	_check("table.six", tr.size() == 6 and range(1, 7).all(func(i): return tr.has(str(i))), tr.keys())
	var keys := range(1, 7).map(func(i): return str(XTianqiXinmoTraits.row(i).get("key", "")))
	_check("table.keys", keys == ["zhanchen", "tougu", "niliu", "daoxing", "yingjie", "tongduo"], keys)
	_check("table.done", range(1, 7).all(func(i): return XTianqiXinmoTraits.trait_key(i) != ""))
	var p: Dictionary = XTianqiXinmoTraits.row(3).get("params", {})
	_check("table.niliu_params", int(p.get("high_hp_heal_pct", 0)) == 50 and int(p.get("low_hp_heal_pct", 0)) == 115 and int(p.get("wash_hp_pct", 0)) == 60 and int(p.get("max_surge_pct", 0)) == 20, p)
	_check("table.niliu_desc_r3", str(XTianqiXinmoTraits.row(3).get("desc", "")).contains("已有虚不受补的不再减"))


func _mount() -> void:
	var lg := _xinmo(1)
	var c := XTianqiXinmoTraits.fight(lg)
	_check("mount.t1_key", str(c.get("key", "")) == "zhanchen" and c.get("xinmo", []).has(lg.enemies[0]), c.get("key"))
	_check("mount.open_log", _texts(lg.turn_start_logs).any(func(x): return x.begins_with("心魔特点【沾尘】")), _texts(lg.turn_start_logs))
	_check("mount.t2", XTianqiXinmoTraits.key_of(_xinmo(2)) == "tougu")
	_check("mount.t3", XTianqiXinmoTraits.key_of(_xinmo(3)) == "niliu")
	_check("mount.t4", XTianqiXinmoTraits.key_of(_xinmo(4)) == "daoxing")
	_check("mount.t5", XTianqiXinmoTraits.key_of(_xinmo(5)) == "yingjie")
	_check("mount.t6", XTianqiXinmoTraits.key_of(_xinmo(6)) == "tongduo")
	_check("mount.no_brand", XTianqiXinmoTraits.fight(_xinmo(1, true, false)).is_empty())
	var lx := _xinmo(1, false)
	_check("mount.xiyou", XTianqiXinmoTraits.fight(lx).is_empty() and not XGuardianRework.xinmo_on(lx))
	var s := _state(10)
	var l1 := XTianqiXinmoTraits.trial_line(s, 1)
	_check("trial_line.t1", l1.contains("【沾尘】") and l1.contains("身上减益达到 2 项时"), l1)
	_check("trial_line.t3", XTianqiXinmoTraits.trial_line(s, 3).contains("【逆流】"))
	_check("trial_line.t4_6", XTianqiXinmoTraits.trial_line(s, 4).contains("【盗形】") and XTianqiXinmoTraits.trial_line(s, 5).contains("【影劫】") and XTianqiXinmoTraits.trial_line(s, 6).contains("【同堕】"))
	_check("trial_line.xiyou_empty", XTianqiXinmoTraits.trial_line(_state(10, false), 1) == "")
	# 战前提示走 _brand_trial（立第 1 段要先到节点；直接拼页面不好造，验接口即可）
	XZhenqi.pending_trial = {}


func _zhanchen() -> void:
	var lg := _xinmo(1)
	var e: XEnemy = lg.enemies[0]
	var a: XActor = lg.actors[0]
	var b: XActor = lg.actors[1]
	var sk := XDB.rec("Skills", 1)
	_check("zc.base_100", XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0, sk) == 1000.0)
	a.buffs[2] = -1
	_check("zc.one_debuff_100", XTianqiXinmoTraits.debuff_count(a) == 1 and XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0, sk) == 1000.0)
	a.buffs[4] = -1
	_check("zc.two_debuffs_112", XTianqiXinmoTraits.debuff_count(a) == 2 and XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0, sk) == 1120.0, XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0, sk))
	_check("zc.floor_int", XTianqiXinmoTraits.hp_damage(lg, e, a, 999.0, sk) == floorf(999.0 * 112 / 100))
	_check("zc.empty_item", XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0) == 1120.0)
	_check("zc.heal_untouched", XTianqiXinmoTraits.hp_damage(lg, e, a, -500.0, sk) == -500.0)
	_check("zc.actor_hits_enemy", XTianqiXinmoTraits.hp_damage(lg, a, e, 1000.0, sk) == 1000.0)
	_check("zc.ally_hits_ally", XTianqiXinmoTraits.hp_damage(lg, b, a, 1000.0, sk) == 1000.0)
	a.buffs[2] = 0
	a.buffs[4] = 0
	# 命中挂弱化：固定掷中、挑第 1 个（物攻 2）
	XTianqiXinmoTraits.force_roll = 0.0
	XTianqiXinmoTraits.force_param = 0
	XTianqiXinmoTraits.act_begin(lg)
	var h0 := a.hp
	XTianqiXinmoTraits.after_hp(lg, e, a, 100.0, h0 + 100.0, sk)
	_check("zc.debuff_on_hit", a.buffs[2] == -1 and a.buff_turns[2] == 2, [a.buffs[2], a.buff_turns[2]])
	XTianqiXinmoTraits.force_param = 1
	XTianqiXinmoTraits.after_hp(lg, e, a, 100.0, h0 + 100.0, sk)
	_check("zc.once_per_action", a.buffs[4] == 0, a.buffs[4])
	XTianqiXinmoTraits.act_begin(lg)
	XTianqiXinmoTraits.force_param = 0
	a.buff_turns[2] = 1
	XTianqiXinmoTraits.after_hp(lg, e, a, 100.0, h0 + 100.0, sk)
	_check("zc.cap_minus1_refresh", a.buffs[2] == -1 and a.buff_turns[2] == 2, [a.buffs[2], a.buff_turns[2]])
	XTianqiXinmoTraits.act_begin(lg)
	XTianqiXinmoTraits.force_roll = 100.0
	XTianqiXinmoTraits.force_param = 2
	XTianqiXinmoTraits.after_hp(lg, e, a, 100.0, h0 + 100.0, sk)
	_check("zc.miss_roll", a.buffs[5] == 0, a.buffs[5])
	XTianqiXinmoTraits.act_begin(lg)
	XTianqiXinmoTraits.force_roll = 0.0
	XTianqiXinmoTraits.after_hp(lg, e, a, -100.0, h0, sk)
	_check("zc.heal_no_debuff", a.buffs[5] == 0, a.buffs[5])
	XTianqiXinmoTraits.after_hp(lg, b, a, 100.0, h0 + 100.0, sk)
	_check("zc.not_xinmo_no_debuff", a.buffs[5] == 0, a.buffs[5])
	XTianqiXinmoTraits.force_roll = -1.0
	XTianqiXinmoTraits.force_param = -1
	# 挂点：execute_hp_damage 里减益 ≥2 的人掉得更多
	_full(lg)
	var v := floorf(b.mhp * 30 / 100.0)
	var d0 := _hit(lg, e, b, v)
	b.buffs[2] = -1
	b.buffs[4] = -1
	b.hp = b.mhp
	var d2 := _hit(lg, e, b, v)
	_check("zc.wired_execute", d0 > 0.0 and d2 > d0 and d2 <= floorf(d0 * 112 / 100.0) + 1.0, [b.mhp, d0, d2])
	lg.end_battle()


func _hit(lg: XBattleLogic, u: XBattler, t: XBattler, v: float) -> float:
	var h := t.hp
	XTianqiXinmoTraits.act_begin(lg)
	XTianqiBrand.act_begin(lg)
	lg.horseman_strike(u, t, XDB.rec("Skills", 1), v, false)  # 带行动资源走 execute_hp_damage（item 为空：脚本伤害口）
	return h - t.hp


func _stun_state() -> int:
	for id in range(2, 400):
		var st := XDB.rec("States", id)
		if not st.is_empty() and int(st.get("restriction", 0)) == 4 and int(st.get("autoRemovalTiming", 0)) > 0:
			return id
	return 0


func _tougu() -> void:
	var lg := _xinmo(2)
	var e: XEnemy = lg.enemies[0]
	var a: XActor = lg.actors[0]
	var sk := XDB.rec("Skills", 1)
	_full(lg)
	var hit := func(dropped: bool) -> void:
		XTianqiXinmoTraits.act_begin(lg)
		XTianqiXinmoTraits.after_hp(lg, e, a, 100.0, a.hp + (100.0 if dropped else 0.0), sk)
	hit.call(true)
	_check("tg.stack1", XTianqiXinmoTraits.fracture(lg, a) == 1 and XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0, sk) == 1080.0, [XTianqiXinmoTraits.fracture(lg, a), XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0, sk)])
	_check("tg.stack_log", _texts(XTianqiXinmoTraits.take_logs(lg)).any(func(x): return x.contains("骨裂") and x.contains("1/3")))
	XTianqiXinmoTraits.after_hp(lg, e, a, 100.0, a.hp + 100.0, sk)  # 同一行动第二段
	_check("tg.multi_hit_once", XTianqiXinmoTraits.fracture(lg, a) == 1)
	hit.call(true)
	hit.call(true)
	hit.call(true)
	_check("tg.cap3_124", XTianqiXinmoTraits.fracture(lg, a) == 3 and XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0, sk) == 1240.0, XTianqiXinmoTraits.fracture(lg, a))
	hit.call(false)  # 护盾全挡
	_check("tg.shield_shed", XTianqiXinmoTraits.fracture(lg, a) == 2)
	_check("tg.shed_log", _texts(XTianqiXinmoTraits.take_logs(lg)).any(func(x): return x.contains("震散了 1 层")))
	a.guarding = true
	hit.call(true)  # 防御中掉了血也不叠、消 1 层
	_check("tg.guard_shed", a.is_guard() and XTianqiXinmoTraits.fracture(lg, a) == 1, [a.is_guard(), XTianqiXinmoTraits.fracture(lg, a)])
	var stun := _stun_state()
	if stun > 0:
		a.add_state(stun)
		a.param_mark_dirty()
		hit.call(true)
		_check("tg.stunned_guard_not_count", not a.is_guard() and XTianqiXinmoTraits.fracture(lg, a) == 2, [stun, a.is_guard(), XTianqiXinmoTraits.fracture(lg, a)])
		a.remove_state(stun)
	else:
		_check("tg.stunned_guard_not_count", false, "找不到不能行动的状态")
	a.guarding = false
	# 回合末倒计时：2 回合没再被打掉血就清
	XTianqiXinmoTraits.end_turn(lg)
	_check("tg.turn1_keep", XTianqiXinmoTraits.fracture(lg, a) == 2)
	XTianqiXinmoTraits.end_turn(lg)
	_check("tg.turn2_clear", XTianqiXinmoTraits.fracture(lg, a) == 0 and XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0, sk) == 1000.0)
	lg.end_battle()


func _setb(a: XActor, brand: int, realm: int) -> void:
	XZhenqi.data(a)
	a.zhenqi["brand"] = brand
	a.zhenqi["brand_realm"] = realm
	a.zhenqi["brand_carved"] = 1


func _niliu() -> void:
	var lg := _xinmo(3)
	var e: XEnemy = lg.enemies[0]
	var a: XActor = lg.actors[0]
	var sk := XDB.rec("Skills", 1)
	var healed := func(rate: float, amt: float) -> float:
		a.hp = floorf(a.mhp * rate)
		var h0 := a.hp
		lg.gain_hp(a, amt)
		return a.hp - h0
	_setb(a, 0, 0)
	_check("nl.high_half", healed.call(0.6, 100.0) == 50.0, healed.call(0.6, 100.0))
	_check("nl.low_115", healed.call(0.4, 100.0) == 115.0, healed.call(0.4, 100.0))
	_check("nl.half_exact_115", healed.call(0.5, 100.0) == 115.0, healed.call(0.5, 100.0))
	_setb(a, 4001, 3)
	_check("nl.weak_heal_has_cost", XTianqiBrand.has_cost(a, "weak_heal"))
	_check("nl.weak_heal_no_double", healed.call(0.6, 100.0) == 50.0, healed.call(0.6, 100.0))  # 虚不受补已减半，不再成 25
	_check("nl.weak_heal_low_115", healed.call(0.4, 100.0) == 115.0, healed.call(0.4, 100.0))
	_check("nl.damage_untouched", XTianqiXinmoTraits.heal(a, -100.0) == -100.0)
	_setb(a, 0, 0)
	_check("nl.surge0", XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0, sk) == 1000.0)
	# 回合末冲刷
	_full(lg)
	var low: XActor = lg.actors[1]
	low.hp = floorf(low.mhp * 0.6)
	var alive := lg.actors.filter(func(x): return x.is_alive())
	var want := {}
	for x in alive:
		want[x] = [x.hp - (floorf(x.hp * 8 / 100.0) if x != low else 0.0), x.mp - (floorf(x.mmp * 6 / 100.0) if x != low else 0.0)]
	var sear0 := alive.map(func(x): return XTianqiBrand.sear_of(lg, x))
	var logs := XTianqiXinmoTraits.end_turn(lg)
	var washed := alive.size() - 1
	_check("nl.wash_hp_mp", alive.all(func(x): return is_equal_approx(x.hp, want[x][0]) and is_equal_approx(x.mp, want[x][1])), alive.map(func(x): return [x.hp, want[x][0], x.mp, want[x][1]]))
	_check("nl.low_not_washed", is_equal_approx(low.hp, floorf(low.mhp * 0.6)))
	_check("nl.surge", int(XTianqiXinmoTraits.fight(lg).surge) == mini(washed * 5, 20), [washed, XTianqiXinmoTraits.fight(lg).surge])
	_check("nl.wash_log", _texts(logs).any(func(x): return x.contains("【逆流】倒卷") and x.contains("%d 名" % washed)), _texts(logs))
	_check("nl.wash_regen_rec", logs.any(func(l): return str(l.get("type", "")) == "regen" and float(l.get("mp", 0.0)) > 0.0))
	_check("nl.no_sear", alive.map(func(x): return XTianqiBrand.sear_of(lg, x)) == sear0, sear0)
	var pct := 100 + mini(washed * 5, 20)
	_check("nl.surge_dmg", XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0, sk) == floorf(1000.0 * pct / 100.0), XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0, sk))
	# 封顶：每人加到 10% 时 3 人以上也只到 max_surge_pct（拷一份参数改，不动表缓存）
	var c := XTianqiXinmoTraits.fight(lg)
	var p0: Dictionary = c.p
	c.p = p0.duplicate()
	c.p["per_washed_dmg_pct"] = 10
	_full(lg)
	XTianqiXinmoTraits.end_turn(lg)
	_check("nl.surge_cap", washed >= 2 and int(c.surge) == 20, [washed, c.surge])
	c.p = p0
	# 不致死：1 点血的人不在 60% 以上；高血端扣 8% 现血永远扣不到 0
	_full(lg)
	XTianqiXinmoTraits.end_turn(lg)
	_check("nl.not_lethal", lg.actors.all(func(x): return x.hp >= 1.0 and x.is_alive()))
	# 下一回合没人高血：增伤清零（不跨回合累积）
	for x in lg.actors:
		x.hp = floorf(x.mhp * 0.5)
	XTianqiXinmoTraits.end_turn(lg)
	_check("nl.surge_reset", int(XTianqiXinmoTraits.fight(lg).surge) == 0)
	# 心魔倒了不冲刷
	_full(lg)
	e.hp = 0.0
	e.add_state(1)
	var h := a.hp
	XTianqiXinmoTraits.end_turn(lg)
	_check("nl.xinmo_dead_no_wash", a.hp == h and int(XTianqiXinmoTraits.fight(lg).surge) == 0)
	lg.end_battle()
	_check("nl.end_clears", XTianqiXinmoTraits.fight(lg).is_empty() and XTianqiXinmoTraits.active_logic() == null)
	a.hp = floorf(a.mhp * 0.6)
	_check("nl.outside_battle", XTianqiXinmoTraits.heal(a, 100.0) == 100.0)


func _turns(logic: XBattleLogic, n: int) -> Array:
	var all := []
	_drain(logic)
	for _i in n:
		var cmds := {}
		for a in logic.actors:
			cmds[a] = [XDB.rec("Skills", 1), logic.enemies[0]]
		all.append_array(logic.run_turn(cmds))
		_drain(logic)
		if logic.is_over():
			break
	return all


func _drain(logic: XBattleLogic) -> void:
	var guard := 0
	while logic.is_event_waiting() and guard < 50:
		guard += 1
		logic.resume_event(0, 0)


## 真打几回合：三段都不报错，逆流回合末真冲刷（logic.end_turn 接上了）
func _wiring() -> void:
	for target in [1, 2, 3]:
		var lg := _xinmo(target)
		_full(lg)
		var logs := _turns(lg, 2)
		_check("wire.t%d_runs" % target, lg.turn >= 1 and not XTianqiXinmoTraits.fight(lg).is_empty(), lg.turn)
		if target == 3:
			_check("wire.t3_wash_in_end_turn", _texts(logs).any(func(x): return x.contains("【逆流】倒卷")) or int(XTianqiXinmoTraits.fight(lg).surge) > 0, _texts(logs))
		lg.end_battle()


func _rollback() -> void:
	XTianqiXinmoTraits.ENABLED = false
	var lg := _xinmo(3)
	var e: XEnemy = lg.enemies[0]
	var a: XActor = lg.actors[0]
	_check("off.no_trait", XTianqiXinmoTraits.fight(lg).is_empty() and XGuardianRework.xinmo_floor(e) > 0)
	_check("off.no_open_log", not _texts(lg.turn_start_logs).any(func(x): return x.begins_with("心魔特点")))
	_check("off.dmg", XTianqiXinmoTraits.hp_damage(lg, e, a, 1000.0) == 1000.0)
	a.hp = floorf(a.mhp * 0.6)
	var h0 := a.hp
	lg.gain_hp(a, 100.0)
	_check("off.heal", a.hp - h0 == 100.0, a.hp - h0)
	_check("off.trial_line", XTianqiXinmoTraits.trial_line(lg.state, 1) == "")
	lg.end_battle()
	XTianqiXinmoTraits.ENABLED = true


# ======================== T319（a2） ========================

func _challenger(lg: XBattleLogic) -> XActor:
	for a in lg.actors:
		if int(a.actor_id) == 2:
			return a
	return null


func _not_challenger(lg: XBattleLogic) -> XActor:
	for a in lg.actors:
		if int(a.actor_id) != 2 and a.is_alive():
			return a
	return null


## 按 horseman_strike 的样子带行动资源走 execute_hp_damage，但带上 item（影劫要认合成技能）
func _strike(lg: XBattleLogic, u: XBattler, t: XBattler, v: float, item: Dictionary) -> float:
	var h := t.hp
	var prev = lg._action_resources
	lg._action_resources = lg._new_lifecycle_resources()
	lg._action_resources.boss_output.enter_action(u, t)
	lg._action_resources.labels = {u: "a", t: "b"}
	lg.execute_hp_damage(u, t, v, false, item)
	lg._action_resources.publish()
	lg._action_resources.boss_output.leave_action()
	lg._action_resources = prev
	return h - t.hp


func _t318_fixes() -> void:
	# P2-1：透骨这一下打死了不叠骨裂、不播报
	var lg := _xinmo(2)
	var e: XEnemy = lg.enemies[0]
	var a: XActor = lg.actors[0]
	XTianqiXinmoTraits.take_logs(lg)
	XTianqiXinmoTraits.act_begin(lg)
	a.hp = 0.0
	a.add_state(1)
	XTianqiXinmoTraits.after_hp(lg, e, a, 100.0, 100.0, XDB.rec("Skills", 1))
	_check("p2_1.dead_no_fracture", XTianqiXinmoTraits.fracture(lg, a) == 0 and XTianqiXinmoTraits.take_logs(lg).is_empty())
	a.remove_state(1)
	a.hp = a.mhp
	lg.end_battle()
	# P2-2：同一个战斗对象重开 setup 先清旧状态（这次不挂也不留上一场的）
	var lg2 := _xinmo(3)
	_check("p2_2.before", not XTianqiXinmoTraits.fight(lg2).is_empty() and XTianqiXinmoTraits.active_logic() == lg2)
	XTianqiXinmoTraits.ENABLED = false
	XTianqiXinmoTraits.setup(lg2, lg2.state)
	XTianqiXinmoTraits.ENABLED = true
	_check("p2_2.cleared", XTianqiXinmoTraits.fight(lg2).is_empty() and XTianqiXinmoTraits.active_logic() == null)
	lg2.end_battle()
	# P3：逆流分界调到 50% 以下时，分界与 50% 之间带虚不受补的人虚不受补不减、逆流照减
	var lg3 := _xinmo(3)
	var b: XActor = lg3.actors[0]
	_setb(b, 4001, 3)
	var c := XTianqiXinmoTraits.fight(lg3)
	var p0: Dictionary = c.p
	c.p = p0.duplicate()
	c.p["heal_split_pct"] = 45
	b.hp = floorf(b.mhp * 0.47)
	var h0 := b.hp
	lg3.gain_hp(b, 100.0)
	_check("p3.split45_weak_heal_between", b.hp - h0 == 50.0, b.hp - h0)
	b.hp = floorf(b.mhp * 0.6)
	h0 = b.hp
	lg3.gain_hp(b, 100.0)
	_check("p3.split45_weak_heal_above", b.hp - h0 == 50.0, b.hp - h0)
	c.p = p0
	_setb(b, 0, 0)
	lg3.end_battle()
	# P3：沾尘已弱化时的刷新也吃有效度×幸运差掷点：幸运差到 0（幸运极高）的人刷新不了
	var lg4 := _xinmo(1)
	var e4: XEnemy = lg4.enemies[0]
	var t4: XActor = lg4.actors[0]
	t4.add_param(7, 100000.0)
	t4.param_mark_dirty()
	t4.buffs[2] = -1
	t4.buff_turns[2] = 1
	XTianqiXinmoTraits.force_roll = 0.0
	XTianqiXinmoTraits.force_param = 0
	XTianqiXinmoTraits.act_begin(lg4)
	XTianqiXinmoTraits.after_hp(lg4, e4, t4, 100.0, t4.hp + 100.0, {})
	_check("p3.zhanchen_refresh_rolls", XBattleLogic._luk_rate(e4, t4) == 0.0 and t4.buff_turns[2] == 1, [XBattleLogic._luk_rate(e4, t4), t4.buff_turns[2]])
	XTianqiXinmoTraits.force_roll = -1.0
	XTianqiXinmoTraits.force_param = -1
	lg4.end_battle()


## 一个安全可剥的增益状态号（Buff 类、有图标、有限回合、没有禁剥标签），和一个带 <Custom 的增益状态号
func _buff_states() -> Array:
	var safe := 0
	var custom := 0
	for id in range(3, 2000):
		var st := XDB.rec("States", id)
		if st.is_empty() or XBossStatus.kind_of(st) != "Buff" or int(st.get("iconIndex", 0)) <= 0 or int(st.get("autoRemovalTiming", 0)) <= 0:
			continue
		var note := str(st.get("note", "")).to_lower()
		if custom == 0 and note.contains("<custom"):
			custom = id
		if safe == 0 and bool(st.get("removeAtBattleEnd", true)) and not XTianqiXinmoTraits.STEAL_BANNED_TAGS.any(func(t): return note.contains(t)) and int(st.get("restriction", 0)) == 0:
			safe = id
		if safe > 0 and custom > 0:
			break
	return [safe, custom]


func _clear_buffs(lg: XBattleLogic) -> void:
	for a in lg.actors:
		for pid in range(8):
			a.buffs[pid] = 0
			a.buff_turns[pid] = 0


func _daoxing() -> void:
	var lg := _xinmo(4)
	var e: XEnemy = lg.enemies[0]
	var sk := XDB.rec("Skills", 1)
	var c := XTianqiXinmoTraits.fight(lg)
	var a0: XActor = lg.actors[0]
	var a1: XActor = lg.actors[1]
	var a2: XActor = lg.actors[2]
	_check("dx.open_log", _texts(lg.turn_start_logs).any(func(x): return x.begins_with("心魔特点【盗形】")))
	_clear_buffs(lg)
	var bs := _buff_states()
	var safe := int(bs[0])
	_check("dx.found_safe_state", safe > 0, bs)
	# 第 1 类：a0 两项、a1 一项、a2 一项（状态）→ 先 a0（项数多），再 a1（同项数按站位），每人 1 项、共 2 项
	a0.buffs[2] = 1
	a0.buff_turns[2] = 3
	a0.buffs[6] = 1
	a0.buff_turns[6] = 3
	a1.buffs[4] = 1
	a1.buff_turns[4] = 3
	if safe > 0:
		a2.add_state(safe)
		a2.state_turns[safe] = 3
	lg.turn = 1
	XTianqiXinmoTraits.take_logs(lg)
	_check("dx.odd_turn_no_steal", XTianqiXinmoTraits.start_turn(lg).is_empty() and a0.buffs[2] == 1 and int(c.stacks) == 0)
	lg.turn = 2
	var logs := XTianqiXinmoTraits.start_turn(lg)
	_check("dx.steal_first_class_most_first", a0.buffs[2] == 0 and a0.buffs[6] == 1, [a0.buffs[2], a0.buffs[6]])
	_check("dx.one_per_member_max2", a1.buffs[4] == 0 and (safe == 0 or a2.state_ids.has(safe)), [a1.buffs[4], a2.state_ids])
	_check("dx.stacks_4", int(c.stacks) == 4 and int(c.turns) == 2, [c.stacks, c.turns])
	_check("dx.steal_log", _texts(logs).any(func(x): return x.contains("剥走") and x.contains("物攻强化") and x.contains("4/4")), _texts(logs))
	_check("dx.no_state_on_xinmo", not e.state_ids.any(func(id): return int(id) == safe))
	_check("dx.dealt_124", XTianqiXinmoTraits.hp_damage(lg, e, a0, 1000.0, sk) == 1240.0, XTianqiXinmoTraits.hp_damage(lg, e, a0, 1000.0, sk))
	_check("dx.taken_80", XTianqiXinmoTraits.hp_damage(lg, a0, e, 1000.0, sk) == 800.0, XTianqiXinmoTraits.hp_damage(lg, a0, e, 1000.0, sk))
	# 第 2 类：只剩状态；防御态 2、<Custom 状态不剥
	_clear_buffs(lg)
	c.stacks = 0
	a0.guarding = false
	a0.add_state(2)
	var custom := int(bs[1])
	if custom > 0:
		a0.add_state(custom)
		a0.state_turns[custom] = 3
	_check("dx.guard_not_safe", not XTianqiXinmoTraits.steal_safe_state(a0, 2))
	_check("dx.custom_not_safe", custom == 0 or not XTianqiXinmoTraits.steal_safe_state(a0, custom), custom)
	_check("dx.dead_not_safe", not XTianqiXinmoTraits.steal_safe_state(a0, 1))
	if safe > 0:
		_check("dx.safe_state_ok", XTianqiXinmoTraits.steal_safe_state(a2, safe))
		a2.state_turns[safe] = 0
		_check("dx.no_turns_not_safe", not XTianqiXinmoTraits.steal_safe_state(a2, safe))
		a2.state_turns[safe] = 3
	lg.turn = 4
	XTianqiXinmoTraits.start_turn(lg)
	_check("dx.steal_state", safe == 0 or not a2.state_ids.has(safe), a2.state_ids)
	_check("dx.keep_guard_custom", a0.state_ids.has(2) and (custom == 0 or a0.state_ids.has(custom)), a0.state_ids)
	_check("dx.state_steal_stacks", int(c.stacks) == 2, c.stacks)
	a0.remove_state(2)
	if custom > 0:
		a0.remove_state(custom)
	# 无可剥：自凝 1 层
	c.stacks = 0
	lg.turn = 6
	logs = XTianqiXinmoTraits.start_turn(lg)
	_check("dx.fallback_1", int(c.stacks) == 1 and _texts(logs).any(func(x): return x.contains("窥视无隙") and x.contains("1/4")), [c.stacks, _texts(logs)])
	# 震碎：挑战者清醒命中 1 层；心魔带减益 2 层；同一行动只算一次；队友、发作行动、反击不算
	var ch := _challenger(lg)
	var mate := _not_challenger(lg)
	c.stacks = 4
	XTianqiXinmoTraits.act_begin(lg, ch, sk)
	XTianqiXinmoTraits.after_hp(lg, ch, e, 100.0, e.hp + 100.0, sk)
	_check("dx.break_1", int(c.stacks) == 3, c.stacks)
	XTianqiXinmoTraits.after_hp(lg, ch, e, 100.0, e.hp + 100.0, sk)
	_check("dx.break_once_per_action", int(c.stacks) == 3, c.stacks)
	_check("dx.break_log", _texts(XTianqiXinmoTraits.take_logs(lg)).any(func(x): return x.contains("震碎心魔 1 层") and x.contains("剩 3 层")))
	e.buffs[2] = -1
	XTianqiXinmoTraits.act_begin(lg, ch, sk)
	XTianqiXinmoTraits.after_hp(lg, ch, e, 100.0, e.hp + 100.0, sk)
	_check("dx.break_2_when_debuffed", int(c.stacks) == 1, c.stacks)
	e.buffs[2] = 0
	XTianqiXinmoTraits.act_begin(lg, mate, sk)
	XTianqiXinmoTraits.after_hp(lg, mate, e, 100.0, e.hp + 100.0, sk)
	_check("dx.ally_no_break", int(c.stacks) == 1)
	XTianqiXinmoTraits.act_begin(lg, ch, XTianqiBrand._cmd("misfire"))
	XTianqiXinmoTraits.after_hp(lg, ch, e, 100.0, e.hp + 100.0, sk)
	_check("dx.fit_no_break", int(c.stacks) == 1)
	XTianqiXinmoTraits.act_begin(lg, e, sk)  # 心魔的行动里挑战者反击
	XTianqiXinmoTraits.after_hp(lg, ch, e, 100.0, e.hp + 100.0, sk)
	_check("dx.counter_no_break", int(c.stacks) == 1)
	# 倒计时：2 回合到期清零
	c.stacks = 4
	c.turns = 2
	XTianqiXinmoTraits.end_turn(lg)
	_check("dx.turn1_keep", int(c.stacks) == 4)
	XTianqiXinmoTraits.end_turn(lg)
	_check("dx.turn2_clear", int(c.stacks) == 0)
	_check("dx.no_decide", XTianqiXinmoTraits.decide(lg, e).is_empty())
	lg.end_battle()


## 一个魔法、全体、带元素、带效果的伤害技能
func _magic_aoe() -> Dictionary:
	for id in range(3, 3000):
		var sk := XDB.rec("Skills", id)
		if sk.is_empty():
			continue
		if int(sk.get("damage", {}).get("type", 0)) == 1 and int(sk.get("hitType", 0)) == 2 and int(sk.get("scope", 0)) == 2 and int(sk.get("damage", {}).get("elementId", 0)) > 0:
			return sk
	return {}


func _yingjie() -> void:
	var lg := _xinmo(5)
	var e: XEnemy = lg.enemies[0]
	var c := XTianqiXinmoTraits.fight(lg)
	var ch := _challenger(lg)
	var mate := _not_challenger(lg)
	var atk := XDB.rec("Skills", 1)
	var mag := _magic_aoe()
	_check("yj.found_magic_aoe", not mag.is_empty())
	# 映照：挑战者非发作伤害招；队友、防御、发作不记
	XTianqiXinmoTraits.act_begin(lg, mate, mag)
	_check("yj.mate_not_mirrored", c.mirror.is_empty())
	XTianqiXinmoTraits.act_begin(lg, ch, XDB.rec("Skills", 2))
	_check("yj.guard_not_mirrored", c.mirror.is_empty())
	XTianqiXinmoTraits.act_begin(lg, ch, mag)
	var m: Dictionary = c.mirror
	_check("yj.mirror_magic_aoe", str(m.get("name", "")) == str(mag.name) and int(m.hit_type) == 2 and bool(m.is_aoe) and bool(m.is_heavy) and int(m.element_id) == int(mag.damage.elementId), m)
	XTianqiXinmoTraits.act_begin(lg, ch, XTianqiBrand._cmd("misfire"))
	_check("yj.fit_not_mirrored", str(c.mirror.name) == str(mag.name))
	# 合成技能
	var sk := XTianqiXinmoTraits.ying_skill(c, 3)
	_check("yj.skill_shape", str(sk.name) == "影·" + str(mag.name) and int(sk.hitType) == 2 and int(sk.scope) == 2 and int(sk.damage.type) == 1 and int(sk.damage.elementId) == int(mag.damage.elementId) and int(sk.repeats) == 1 and (sk.effects as Array).is_empty() and str(sk.note) == "" and (sk.meta as Dictionary).is_empty(), sk)
	_check("yj.keeps_formula", sk.damage.has("formulaProgram") == atk.damage.has("formulaProgram") and str(sk.damage.get("formula", "")) == str(atk.damage.get("formula", "")))
	_check("yj.not_id_1_not_attack", int(sk.id) != 1 and not e.is_attack(sk), sk.id)
	_check("yj.magic_mode", XDamage.is_magical(sk) and not XDamage.elements_data().skills.has(str(int(sk.id))))
	# 特性 34（普攻追加 1 次）：普攻 2 段，影劫仍 1 段
	var st34 := 0
	for id in range(2, 1000):
		var st := XDB.rec("States", id)
		if not st.is_empty() and (st.get("traits", []) as Array).any(func(tr): return int(tr.code) == 34 and float(tr.value) >= 1.0):
			st34 = id
			break
	_check("yj.found_trait34", st34 > 0)
	e.add_state(st34)
	e.param_mark_dirty()
	_check("yj.trait34_attack_2", XBattleLogic.attack_repeats(e, atk, 1) >= 2, XBattleLogic.attack_repeats(e, atk, 1))
	_check("yj.trait34_ying_1", XBattleLogic.attack_repeats(e, sk, 1) == 1)
	# 单体 3 层：真走 execute，心魔攻击拉到极高，满血目标只掉护栏 60%（按整次行动累计），只结算一段
	c.mirror = {"name": "裂空斩", "hit_type": 1, "element_id": 0, "is_aoe": false, "is_heavy": true, "user": ch.display_name()}
	var single := XTianqiXinmoTraits.ying_skill(c, 3)
	e.add_param(2, 9000000.0)
	e.add_param(4, 9000000.0)
	e.param_mark_dirty()
	_full(lg)
	for a in lg.actors:
		a.shield = 0.0
	XTianqiBrand.act_begin(lg)
	XTianqiXinmoTraits.act_begin(lg, e, single)
	var elogs := lg.execute(e, single, mate)
	var hits := elogs.filter(func(l): return str(l.get("type", "")) == "hit" and is_same(l.get("target"), mate))
	_check("yj.single_one_segment", hits.size() == 1, hits.size())
	_check("yj.single_cap_60_left_40", mate.hp >= ceilf(mate.mhp * 0.4) - 1.0 and mate.hp < mate.mhp, [mate.hp, mate.mhp])
	e.remove_state(st34)
	# 护栏按行动累计：同一行动两下加起来不超过 60%
	_full(lg)
	XTianqiXinmoTraits.act_begin(lg, e, single)
	var d1 := XTianqiXinmoTraits.hp_damage(lg, e, mate, mate.mhp, single)
	var d2 := XTianqiXinmoTraits.hp_damage(lg, e, mate, mate.mhp, single)
	_check("yj.cap_per_action", d1 == floorf(mate.mhp * 60 / 100.0) and d2 == 0.0, [d1, d2, mate.mhp])
	# 分档（小数值不碰护栏）
	var tiers := []
	for n in 4:
		XTianqiXinmoTraits.act_begin(lg, e, single)
		tiers.append(XTianqiXinmoTraits.hp_damage(lg, e, mate, 100.0, XTianqiXinmoTraits.ying_skill(c, n)))
	_check("yj.single_tiers", tiers == [105.0, 120.0, 135.0, 150.0], tiers)
	c.mirror = {"name": str(mag.name), "hit_type": 2, "element_id": 0, "is_aoe": true, "is_heavy": true, "user": ch.display_name()}
	tiers = []
	for n in 4:
		XTianqiXinmoTraits.act_begin(lg, e, single)
		tiers.append(XTianqiXinmoTraits.hp_damage(lg, e, mate, 100.0, XTianqiXinmoTraits.ying_skill(c, n)))
	_check("yj.aoe_tiers", tiers == [71.0, 81.0, 91.0, 100.0], tiers)
	XTianqiXinmoTraits.act_begin(lg, e, single)
	_check("yj.aoe_cap_50", XTianqiXinmoTraits.hp_damage(lg, e, mate, mate.mhp * 10.0, XTianqiXinmoTraits.ying_skill(c, 3)) == floorf(mate.mhp * 50 / 100.0))
	_check("yj.normal_attack_100", XTianqiXinmoTraits.hp_damage(lg, e, mate, 1000.0, atk) == 1000.0)
	# 额外印纹：主动招、影势 ≥2、掉了血才加；普攻底、1 层、没掉血不加
	var heavy3 := XTianqiXinmoTraits.ying_skill(c, 3)
	var heavy1 := XTianqiXinmoTraits.ying_skill(c, 1)
	_full(lg)
	var s0 := XTianqiBrand.sear_of(lg, mate)
	XTianqiXinmoTraits.act_begin(lg, e, heavy3)
	XTianqiXinmoTraits.after_hp(lg, e, mate, 100.0, mate.hp + 100.0, heavy3)
	_check("yj.sear_aoe_8", XTianqiBrand.sear_of(lg, mate) - s0 == 8 or XTianqiBrand.fills_of(lg, mate) > 0, [s0, XTianqiBrand.sear_of(lg, mate)])
	s0 = XTianqiBrand.sear_of(lg, mate)
	XTianqiXinmoTraits.after_hp(lg, e, mate, 100.0, mate.hp + 100.0, heavy3)
	_check("yj.sear_once_per_action", XTianqiBrand.sear_of(lg, mate) == s0)
	XTianqiXinmoTraits.act_begin(lg, e, heavy1)
	XTianqiXinmoTraits.after_hp(lg, e, mate, 100.0, mate.hp + 100.0, heavy1)
	_check("yj.sear_low_stacks_none", XTianqiBrand.sear_of(lg, mate) == s0)
	XTianqiXinmoTraits.act_begin(lg, e, heavy3)
	XTianqiXinmoTraits.after_hp(lg, e, mate, 100.0, mate.hp, heavy3)
	_check("yj.sear_shield_none", XTianqiBrand.sear_of(lg, mate) == s0)
	c.mirror = {"name": "普通攻击", "hit_type": 1, "element_id": 0, "is_aoe": false, "is_heavy": false, "user": ch.display_name()}
	var light3 := XTianqiXinmoTraits.ying_skill(c, 3)
	XTianqiXinmoTraits.act_begin(lg, e, light3)
	XTianqiXinmoTraits.after_hp(lg, e, mate, 100.0, mate.hp + 100.0, light3)
	_check("yj.sear_attack_none", XTianqiBrand.sear_of(lg, mate) == s0)
	# 循环：第 2 回合蓄势（3 层、明牌），蓄势回合挑战者改打普攻覆盖原大招（控招诱影），挑战者削 2、队友削 1
	c.mirror = {}
	XTianqiXinmoTraits.act_begin(lg, ch, mag)
	lg.turn = 1
	_check("yj.t1_no_charge", XTianqiXinmoTraits.start_turn(lg).is_empty() and int(c.ying) == 0)
	lg.turn = 2
	var logs := XTianqiXinmoTraits.start_turn(lg)
	_check("yj.t2_charge_3", int(c.ying) == 3 and int(c.charge_turn) == 2, [c.ying, c.charge_turn])
	_check("yj.charge_log", _texts(logs).any(func(x): return x.contains(str(mag.name)) and x.contains("影·") and x.contains(ch.display_name())), _texts(logs))
	XTianqiXinmoTraits.act_begin(lg, ch, ch.attack_skill())
	_check("yj.lure_overwrites", not bool(c.mirror.is_heavy) and not bool(c.mirror.is_aoe), c.mirror)
	XTianqiXinmoTraits.after_hp(lg, ch, e, 100.0, e.hp + 100.0, atk)
	_check("yj.challenger_shed_2", int(c.ying) == 1, c.ying)
	XTianqiXinmoTraits.after_hp(lg, ch, e, 100.0, e.hp + 100.0, atk)
	_check("yj.shed_once_per_action", int(c.ying) == 1)
	XTianqiXinmoTraits.act_begin(lg, mate, atk)
	XTianqiXinmoTraits.after_hp(lg, mate, e, 100.0, e.hp + 100.0, atk)
	_check("yj.ally_shed_1", int(c.ying) == 0, c.ying)
	_check("yj.shed_log", _texts(XTianqiXinmoTraits.take_logs(lg)).any(func(x): return x.contains("迎击奏效") and x.contains("降至 0 层")))
	c.ying = 3
	XTianqiXinmoTraits.act_begin(lg, ch, XTianqiBrand._cmd("misfire"))
	XTianqiXinmoTraits.after_hp(lg, ch, e, 100.0, e.hp + 100.0, atk)
	_check("yj.fit_no_shed", int(c.ying) == 3)
	# 第 3 回合：心魔头一次行动换成【影·普通攻击】，带当时的影势，用掉；第二次照常
	lg.turn = 3
	XTianqiXinmoTraits.act_begin(lg, mate, atk)
	XTianqiXinmoTraits.after_hp(lg, mate, e, 100.0, e.hp + 100.0, atk)
	_check("yj.no_shed_outside_charge", int(c.ying) == 3)
	var dec := XTianqiXinmoTraits.decide(lg, e)
	_check("yj.replay", dec.size() == 2 and str(dec[0].get("name", "")) == "影·" + str(ch.attack_skill().name) and int(dec[0].get("_ying_stacks", -1)) == 3 and dec[1] == null, dec)
	_check("yj.replay_once", XTianqiXinmoTraits.decide(lg, e).is_empty() and int(c.ying) == 0)
	_check("yj.not_actor", XTianqiXinmoTraits.decide(lg, mate).is_empty())
	# 被控没出手：重演回合末影势消散
	lg.turn = 5
	XTianqiXinmoTraits.start_turn(lg)
	_check("yj.t5_charge", int(c.ying) == 3 and int(c.charge_turn) == 5)
	lg.turn = 6
	XTianqiXinmoTraits.end_turn(lg)
	_check("yj.fade_after_replay_turn", int(c.ying) == 0)
	# 兜底：挑战者没出过伤害招
	c.mirror = {}
	lg.turn = 8
	XTianqiXinmoTraits.start_turn(lg)
	_check("yj.fallback_mirror", not c.mirror.is_empty() and str(c.mirror.user) == ch.display_name(), c.mirror)
	lg.end_battle()


func _setb_all(lg: XBattleLogic, vals: Array) -> void:
	for i in lg.actors.size():
		_setb(lg.actors[i], int(vals[i % vals.size()]), 6)


func _tongduo() -> void:
	var lg := _xinmo(6)
	var e: XEnemy = lg.enemies[0]
	var c := XTianqiXinmoTraits.fight(lg)
	var sk := XDB.rec("Skills", 1)
	var ch := _challenger(lg)
	var mate := _not_challenger(lg)
	var open := _texts(lg.turn_start_logs).filter(func(x): return x.begins_with("心魔特点【同堕】"))
	_check("td.open_log_formatted", open.size() == 1 and not open[0].contains("%d") and open[0].contains("伤害 +%d%%" % int(c.res)), open)
	_setb_all(lg, [8500, 4000, 6000, 2000])
	lg.turn = 1
	XTianqiXinmoTraits.start_turn(lg)
	var live := lg.actors.filter(func(a): return a.is_alive())
	var sum := 0
	for a in live:
		sum += int(floorf(XTianqiBrand.pct(a)))
	var avg := sum / live.size()
	_check("td.avg", int(c.avg) == avg and int(c.res) == mini(avg * 20 / 100, 20), [c.avg, c.res, avg])
	mate.hp = 0.0
	mate.add_state(1)
	XTianqiXinmoTraits.start_turn(lg)
	live = lg.actors.filter(func(a): return a.is_alive())
	sum = 0
	for a in live:
		sum += int(floorf(XTianqiBrand.pct(a)))
	_check("td.avg_alive_only", int(c.avg) == sum / live.size(), [c.avg, sum, live.size()])
	mate.remove_state(1)
	mate.hp = mate.mhp
	_setb_all(lg, [10000])
	XTianqiXinmoTraits.start_turn(lg)
	_check("td.res_cap_20", int(c.res) <= 20 and int(c.res) == mini(int(c.avg) * 20 / 100, 20), [c.avg, c.res])
	# 双数回合引纹：掉了血 +8；防御、全盾、单数回合不加；同一行动一次
	_full(lg)
	lg.turn = 2
	var s0 := XTianqiBrand.sear_of(lg, mate)
	var f0 := XTianqiBrand.fills_of(lg, mate)
	XTianqiXinmoTraits.act_begin(lg, e, sk)
	XTianqiXinmoTraits.after_hp(lg, e, mate, 100.0, mate.hp + 100.0, sk)
	_check("td.even_sear_8", XTianqiBrand.sear_of(lg, mate) - s0 == 8 or XTianqiBrand.fills_of(lg, mate) > f0, [s0, XTianqiBrand.sear_of(lg, mate)])
	s0 = XTianqiBrand.sear_of(lg, mate)
	XTianqiXinmoTraits.after_hp(lg, e, mate, 100.0, mate.hp + 100.0, sk)
	_check("td.even_once_per_action", XTianqiBrand.sear_of(lg, mate) == s0)
	XTianqiXinmoTraits.act_begin(lg, e, sk)
	mate.guarding = true
	XTianqiXinmoTraits.after_hp(lg, e, mate, 100.0, mate.hp + 100.0, sk)
	mate.guarding = false
	_check("td.guard_no_sear", XTianqiBrand.sear_of(lg, mate) == s0)
	XTianqiXinmoTraits.act_begin(lg, e, sk)
	XTianqiXinmoTraits.after_hp(lg, e, mate, 100.0, mate.hp, sk)
	_check("td.shield_no_sear", XTianqiBrand.sear_of(lg, mate) == s0)
	lg.turn = 3
	XTianqiXinmoTraits.act_begin(lg, e, sk)
	XTianqiXinmoTraits.after_hp(lg, e, mate, 100.0, mate.hp + 100.0, sk)
	_check("td.odd_no_sear", XTianqiBrand.sear_of(lg, mate) == s0)
	# 叠堕势：满槽（当场引发的发作不再数）只叠 1 层
	c.fall = 0
	XTianqiXinmoTraits.take_logs(lg)
	var fit0 := (XTianqiBrand.fight(lg).get("fit_log", []) as Array).size()
	lg.turn = 4
	if not lg.current_order.has(mate):
		lg.current_order.append(mate)  # 还没行动：满槽当场发作（source＝sear）
	XTianqiBrand.sear_add(lg, mate, 99999)
	var fits := (XTianqiBrand.fight(lg).get("fit_log", []) as Array).slice(fit0)
	_check("td.sear_full_one_stack", int(c.fall) == 1, [c.fall, fits])
	_check("td.sear_fit_source", fits.is_empty() or fits.all(func(f): return str(f.source) == "sear"), fits)
	_check("td.stack_log", _texts(XTianqiXinmoTraits.take_logs(lg)).any(func(x): return x.contains("堕势 1/3")))
	# 自发发作叠 1 层；同一回合全队最多 +2
	var fc := XTianqiBrand._fc(lg)
	XTianqiBrand._start_fit(lg, fc, ch, "self")
	_check("td.self_fit_stack", int(c.fall) == 2, c.fall)
	XTianqiBrand._start_fit(lg, fc, lg.actors[2], "self")
	_check("td.max_gain_per_turn", int(c.fall) == 2, c.fall)
	lg.turn = 5
	XTianqiBrand._start_fit(lg, fc, lg.actors[2], "test")
	_check("td.next_turn_stack_3", int(c.fall) == 3 and int(c.fall_turns) == 2, [c.fall, c.fall_turns])
	lg.turn = 6
	XTianqiBrand._start_fit(lg, fc, ch, "self")
	_check("td.stack_cap_3", int(c.fall) == 3)
	# 出伤：min(100＋共鸣＋堕势×6, 135)；承伤：100−堕势×5
	c.res = 12
	c.fall = 2
	_check("td.dealt", XTianqiXinmoTraits.hp_damage(lg, e, mate, 1000.0, sk) == 1240.0, XTianqiXinmoTraits.hp_damage(lg, e, mate, 1000.0, sk))
	c.res = 20
	c.fall = 3
	_check("td.cap_135", XTianqiXinmoTraits.hp_damage(lg, e, mate, 1000.0, sk) == 1350.0, XTianqiXinmoTraits.hp_damage(lg, e, mate, 1000.0, sk))
	_check("td.taken_85", XTianqiXinmoTraits.hp_damage(lg, mate, e, 1000.0, sk) == 850.0)
	# 镇压：挑战者清醒命中消 1 层、本回合与下回合共鸣减半、堕势减伤失效；发作行动不镇压；队友不镇压
	XTianqiXinmoTraits.act_begin(lg, mate, sk)
	XTianqiXinmoTraits.after_hp(lg, mate, e, 100.0, e.hp + 100.0, sk)
	_check("td.ally_no_suppress", int(c.fall) == 3 and not XTianqiXinmoTraits.suppressed(lg))
	XTianqiXinmoTraits.act_begin(lg, ch, XTianqiBrand._cmd("misfire"))
	XTianqiXinmoTraits.after_hp(lg, ch, e, 100.0, e.hp + 100.0, sk)
	_check("td.fit_no_suppress", int(c.fall) == 3 and not XTianqiXinmoTraits.suppressed(lg))
	XTianqiXinmoTraits.take_logs(lg)
	XTianqiXinmoTraits.act_begin(lg, ch, sk)
	XTianqiXinmoTraits.after_hp(lg, ch, e, 100.0, e.hp + 100.0, sk)
	_check("td.suppress_shed", int(c.fall) == 2 and XTianqiXinmoTraits.suppressed(lg), [c.fall, c.suppress_to])
	_check("td.suppress_log", _texts(XTianqiXinmoTraits.take_logs(lg)).any(func(x): return x.contains("守住本心") and x.contains("消去 1 层")))
	_check("td.suppress_dealt", XTianqiXinmoTraits.hp_damage(lg, e, mate, 1000.0, sk) == 1220.0, XTianqiXinmoTraits.hp_damage(lg, e, mate, 1000.0, sk))
	_check("td.suppress_taken_100", XTianqiXinmoTraits.hp_damage(lg, mate, e, 1000.0, sk) == 1000.0)
	lg.turn = 7
	_check("td.suppress_next_turn", XTianqiXinmoTraits.suppressed(lg))
	lg.turn = 8
	_check("td.suppress_ends", not XTianqiXinmoTraits.suppressed(lg))
	c.fall = 0
	XTianqiXinmoTraits.act_begin(lg, ch, sk)
	XTianqiXinmoTraits.after_hp(lg, ch, e, 100.0, e.hp + 100.0, sk)
	_check("td.suppress_only_log", _texts(XTianqiXinmoTraits.take_logs(lg)).any(func(x): return x.contains("压制了心魔的【同堕】共鸣")))
	# 倒计时
	c.fall = 2
	c.fall_turns = 2
	XTianqiXinmoTraits.end_turn(lg)
	_check("td.turn1_keep", int(c.fall) == 2)
	XTianqiXinmoTraits.end_turn(lg)
	_check("td.turn2_clear", int(c.fall) == 0)
	_check("td.no_decide", XTianqiXinmoTraits.decide(lg, e).is_empty())
	_setb_all(lg, [0])
	lg.end_battle()
	# 别的段、不是心魔战：通知 O(1) 不做事
	var lg1 := _xinmo(1)
	XTianqiXinmoTraits.on_brand_resonance(lg1, lg1.actors[0], "sear")
	_check("td.other_trait_ignores", not XTianqiXinmoTraits.fight(lg1).has("fall") or int(XTianqiXinmoTraits.fight(lg1).fall) == 0)
	lg1.end_battle()
	XTianqiXinmoTraits.on_brand_resonance(null, null, "fit")
	_check("td.null_safe", true)


## 号卷四号、灰印免死、临终：后三条倍率之后照样留 1 点（倍率挂在三处保命之前）
func _saves() -> void:
	for target in [4, 5, 6]:
		var kinds := ["trumpet", "cheat", "dying"]
		for kind in kinds:
			var s := _state(10)
			var holder: XActor = s.battle_members()[0]
			if kind == "trumpet":
				var id := int(XTianqiTrumpet.scroll(4).skill)
				if not holder.skill_ids.has(id):
					holder.skill_ids.append(id)
				holder.refresh_passive()
			elif kind == "dying":
				var item: Dictionary = XTianqiAlienGear.create(s, "armor", 52, "death", "huaxing", "dying").ok
				s.gear.append(item)
				XEquipment.change(s, holder, holder.equip_slots().find(int(item.etypeId)), item)
			var troop := int(XZhenqi.TRIAL_TROOP["心魔"])
			XZhenqi.pending_trial = {"actorId": 2, "target": target, "ref": XZhenqi.trial_ref(s, 1), "kind": "心魔", "troopId": troop, "brand": true}
			var lg := XBattleLogic.new()
			lg.setup(troop, s)
			var e: XEnemy = lg.enemies[0]
			var c := XTianqiXinmoTraits.fight(lg)
			var t: XActor = holder if lg.actors.has(holder) else lg.actors[0]
			if kind == "cheat":
				XTianqiQiyinEffects._store(lg).fx[t] = {"cheat_death": {"per_battle": 1, "turns": 1, "hp": 1}}
			var item := XDB.rec("Skills", 1)
			match target:
				4:
					c.stacks = 4
				5:
					c.mirror = {"name": "裂空斩", "hit_type": 1, "element_id": 0, "is_aoe": true, "is_heavy": true, "user": "x"}
					item = XTianqiXinmoTraits.ying_skill(c, 3)
				6:
					c.fall = 3
					c.res = 20
			t.recover_all()
			t.shield = 0.0
			t.hp = floorf(t.mhp * 0.2)
			XTianqiBrand.act_begin(lg)
			XTianqiXinmoTraits.act_begin(lg, e, item)
			_strike(lg, e, t, t.mhp * 10.0, item)
			var name := "save.t%d_%s" % [target, kind]
			if kind == "dying":
				_check(name + "_key", XTianqiAlienAffix.key_of(t) == "dying")
			_check(name, t.is_alive() and t.hp >= 1.0 and t.hp <= floorf(t.mhp * 0.2), [t.hp, t.mhp, t.is_alive()])
			lg.end_battle()
	XZhenqi.pending_trial = {}


## 真打：4～6 段几回合不报错；影劫第 3 回合真出【影·…】、只一段
func _wiring_a2() -> void:
	for target in [4, 5, 6]:
		var lg := _xinmo(target)
		_full(lg)
		var logs := _turns(lg, 3)
		_check("wire.t%d_runs" % target, lg.turn >= 2 and not XTianqiXinmoTraits.fight(lg).is_empty(), lg.turn)
		if target == 4:
			_check("wire.t4_turn2_steal", _texts(logs).any(func(x): return x.contains("【盗形】")), _texts(logs))
		if target == 5:
			var acts := logs.filter(func(l): return str(l.get("type", "")) == "action" and str(l.get("skill", {}).get("name", "")).begins_with("影·"))
			_check("wire.t5_replay_cast", acts.size() == 1, acts.size())
			_check("wire.t5_charge_log", _texts(logs).any(func(x): return x.contains("蓄起 3 层「影势」")), _texts(logs))
		lg.end_battle()
