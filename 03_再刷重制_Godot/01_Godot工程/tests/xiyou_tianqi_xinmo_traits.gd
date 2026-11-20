extends Node
## 【cc·T318】天启篇心魔特点 a1（XTianqiXinmoTraits，T316 设计 v0.3；Kyo 11-20「245按推荐」）：
## 〇、挂法：按 trial.target 挂一条（1 沾尘、2 透骨、3 逆流；4～6 还没接不挂）；开场报特点；战前提示；非烙印试炼、西游档、ENABLED=false 不挂。
## 一、沾尘：心魔命中按几率挂 1 级弱化（同一行动对同一人只判一次、已弱化只刷新回合），减益 ≥2 项时心魔伤害 112%；回复、空 item 不乱乘。
## 二、透骨：打掉生命叠骨裂（上限 3）、每层 +8%；防御或护盾全挡消 1 层；被控时防御不算；回合末倒计时清零。
## 三、逆流：高血受疗 50%（已有虚不受补的不再减）、低血 115%；回合末冲刷 >60% 的人（扣 8% 现血、6% 最大魔法，不致死、不涨印纹），
##     下回合心魔伤害 +5%／人（封顶 20%）；心魔倒了不冲刷。
## 四、挂点：增伤在 execute_hp_damage 里生效；end_battle 清状态。

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
	_check("table.done", range(1, 4).all(func(i): return XTianqiXinmoTraits.trait_key(i) != "") and range(4, 7).all(func(i): return XTianqiXinmoTraits.trait_key(i) == ""))
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
	var lg4 := _xinmo(4)
	_check("mount.t4_not_yet", XTianqiXinmoTraits.fight(lg4).is_empty() and XGuardianRework.xinmo_floor(lg4.enemies[0]) > 0)
	_check("mount.no_brand", XTianqiXinmoTraits.fight(_xinmo(1, true, false)).is_empty())
	var lx := _xinmo(1, false)
	_check("mount.xiyou", XTianqiXinmoTraits.fight(lx).is_empty() and not XGuardianRework.xinmo_on(lx))
	var s := _state(10)
	var l1 := XTianqiXinmoTraits.trial_line(s, 1)
	_check("trial_line.t1", l1.contains("【沾尘】") and l1.contains("身上减益达到 2 项时"), l1)
	_check("trial_line.t3", XTianqiXinmoTraits.trial_line(s, 3).contains("【逆流】"))
	_check("trial_line.t4_empty", XTianqiXinmoTraits.trial_line(s, 4) == "")
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
	_check("tg.shed_log", _texts(XTianqiXinmoTraits.take_logs(lg)).any(func(x): return x.contains("震散")))
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
