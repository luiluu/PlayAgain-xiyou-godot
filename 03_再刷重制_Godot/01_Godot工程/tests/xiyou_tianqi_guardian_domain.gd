extends Node
## 【cc·T229】天启篇关守层者领域（XGuardianRework.DOMAIN_OFF，Kyo 11-19「220丙」）：
## 一、天启篇 13 层（敌群 111）不交礼：第 1 回合不挂大道领域（我方 696、守层者 691／1103／44），轮回困难 1460 照挂；回退开关关掉时 696 照原版挂上（测试咬得住）。
## 二、20 层（456）不交礼不挂天道领域 698／686／1104，交了礼不挂伪领域 695／691；残血页（血 ≤20%＋变量 853）不再挂 698，334 回满照旧。
## 三、31 层（467）不挂霸者领域 1106／1110／1108，破阵阶段状态 1050 照挂。
## 四、西游档 13 层照原版挂 696；domain_off 只认 13～33 层守层者敌群（12 层 110、守护者 125 不算）。
## 五、三张表缺层逐层退回（T229，给 T239 写表用）：balance_table 写了 guardian_phase4（T239 第 6 轮），这一节先拿掉它测老表与缺层退回、测完放回；
##     临时塞一张只有 1～30 层的表：1～30 层读新表，31～34 层逐层退回旧表、取值跟没表时一致
##     （hp_base＝旧 HP_BASE×hp_unit，出伤倍率＝旧 ATK_SCALE，伤害抵抗＝旧 RESIST_TABLE），不再按 0／1 取。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	seed(20261119)
	var was := XGuardianRework.DOMAIN_OFF
	_check("default_on", XGuardianRework.DOMAIN_OFF)
	_f13()
	_f20()
	_f31()
	_xiyou()
	_scope()
	_tables()
	XGuardianRework.DOMAIN_OFF = was
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(tianqi := true) -> XState:
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
		s = XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	XState.current = s
	return s


func _battle(troop: int, paid := false, tianqi := true) -> XBattleLogic:
	var s := _state(tianqi)
	s.set_variable(842, 1 if paid else 0)
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	for a in logic.actors:
		a.recover_all()
	_turn(logic)
	return logic


func _turn(logic: XBattleLogic) -> void:
	var cmds := {}
	for a in logic.actors:
		cmds[a] = [XDB.rec("Skills", 1), logic.enemies[0]]
	logic.run_turn(cmds)
	_drain(logic)


func _drain(logic: XBattleLogic) -> void:
	var guard := 0
	while logic.is_event_waiting() and guard < 50:
		guard += 1
		logic.resume_event(0, 0)


func _party(logic: XBattleLogic, id: int) -> bool:
	return logic.actors.any(func(a): return a.is_state_affected(id))


func _foe(logic: XBattleLogic, id: int) -> bool:
	return logic.enemies.any(func(e): return e.is_state_affected(id))


func _f13() -> void:
	XGuardianRework.DOMAIN_OFF = true
	var lg := _battle(111)
	_check("f13.domain_off", XGuardianRework.domain_off(lg))
	_check("f13.no_696", not _party(lg, 696))
	_check("f13.no_foe_buffs", not _foe(lg, 691) and not _foe(lg, 1103), [_foe(lg, 691), _foe(lg, 1103)])
	_check("f13.hard_kept", _foe(lg, 1460) or _party(lg, 1460), [_foe(lg, 1460), _party(lg, 1460)])
	XGuardianRework.DOMAIN_OFF = false
	var lg0 := _battle(111)
	_check("f13.rollback_696", not XGuardianRework.domain_off(lg0) and _party(lg0, 696) and _foe(lg0, 691), [_party(lg0, 696), _foe(lg0, 691)])
	XGuardianRework.DOMAIN_OFF = true


func _f20() -> void:
	var lg := _battle(456)
	_check("f20.no_698", not _party(lg, 698) and not _foe(lg, 686) and not _foe(lg, 1104), [_party(lg, 698), _foe(lg, 686), _foe(lg, 1104)])
	_check("f20.hard_kept", _foe(lg, 1460) or _party(lg, 1460))
	var paid := _battle(456, true)
	_check("f20.paid_no_695", not _party(paid, 695) and not _foe(paid, 691), [_party(paid, 695), _foe(paid, 691)])
	# 残血页：守层者血 ≤20%＋变量 853＝1 → 原版对话后 1399 回满再开天道领域；关着只回满
	var e0: XBattler = lg.enemies[0]
	lg.state.set_variable(853, 1)
	e0.hp = floorf(e0.mhp * 0.15)
	lg.run_events()
	_drain(lg)
	# 回满后 8111 轮回困难的附加效果会按守层者自己的攻击扣它一下（原版如此），所以不比满血，只看回过血
	_check("f20.low_hp_refill_kept", e0.hp > floorf(e0.mhp * 0.15) * 2.0, [e0.hp, e0.mhp])
	_check("f20.low_hp_no_698", not _party(lg, 698) and not _foe(lg, 686), [_party(lg, 698), _foe(lg, 686)])
	XGuardianRework.DOMAIN_OFF = false
	var lg0 := _battle(456)
	_check("f20.rollback_698", _party(lg0, 698) and _foe(lg0, 686), [_party(lg0, 698), _foe(lg0, 686)])
	XGuardianRework.DOMAIN_OFF = true


func _f31() -> void:
	var lg := _battle(467)
	_check("f31.no_overlord", not _party(lg, 1106) and not _foe(lg, 1110) and not _foe(lg, 1108), [_party(lg, 1106), _foe(lg, 1110), _foe(lg, 1108)])
	_check("f31.phase_kept", _foe(lg, 1050), _foe(lg, 1050))
	XGuardianRework.DOMAIN_OFF = false
	var lg0 := _battle(467)
	_check("f31.rollback_1106", _party(lg0, 1106) and _foe(lg0, 1110), [_party(lg0, 1106), _foe(lg0, 1110)])
	XGuardianRework.DOMAIN_OFF = true


func _xiyou() -> void:
	var lg := _battle(111, false, false)
	_check("xiyou.untouched", not XGuardianRework.domain_off(lg) and _party(lg, 696) and _foe(lg, 691), [_party(lg, 696), _foe(lg, 691)])


func _scope() -> void:
	var s := _state(true)
	var ok := true
	for t in [110, 125, 4, 755]:
		var lg := XBattleLogic.new()
		lg.setup(t, s)
		if XGuardianRework.domain_off(lg):
			ok = false
	var in_scope := true
	for t in [111, 333, 456, 466, 469]:
		var lg := XBattleLogic.new()
		lg.setup(t, s)
		if not XGuardianRework.domain_off(lg):
			in_scope = false
	_check("scope", ok and in_scope, [ok, in_scope])


func _tables() -> void:
	_check("tables.phase4_on", XTianqiBase.PHASE4)
	var bal: Dictionary = XTianqiBalance.data()
	# T239 第 6 轮起 balance_table 写了 guardian_phase4：先认写了（34 层血量齐全），再拿掉它测老表与缺层退回，测完放回
	var real = bal.get("guardian_phase4")
	_check("tables.written", real is Dictionary and range(1, 35).all(func(f): return real.get("hp_base", {}).has(str(f))))
	bal.erase("guardian_phase4")
	var old_hp := []
	for f in range(1, 35):
		old_hp.append(XGuardianRework.hp_base(f))
	_check("tables.old_hp_base", range(1, 35).all(func(f): return is_equal_approx(old_hp[f - 1], float(XGuardianRework.HP_BASE[f]) * XTianqiNoX6.hp_unit())))
	var hp := {}
	var atk := {}
	var res := {}
	for f in range(1, 31):
		hp[str(f)] = 1000 + f
		atk[str(f)] = 2.0 + f
		if f >= 19:
			res[str(f)] = 100 + f
	bal["guardian_phase4"] = {"hp_base": hp, "atk_scale": atk, "resist": res}
	var bad := []
	for f in range(1, 35):
		var want: float = float(hp[str(f)]) if hp.has(str(f)) else old_hp[f - 1]
		if not is_equal_approx(XGuardianRework.hp_base(f), want):
			bad.append([f, XGuardianRework.hp_base(f), want])
	_check("tables.hp_base_fallback", bad.is_empty(), bad)
	var s := _state(true)
	var bad_atk := []
	var bad_res := []
	for f in [13, 20, 30, 31, 32, 33]:
		var lg := XBattleLogic.new()
		lg.setup(int(XGuardianRework.TROOPS[f]), s)
		var e: XEnemy = null
		for x in lg.enemies:
			if XGuardianRework.floor_of(x.enemy_id) == f:
				e = x
				break
		if e == null:
			bad_atk.append([f, "没有守层者"])
			continue
		var want_atk := float(atk[str(f)]) if atk.has(str(f)) else float(XGuardianRework.ATK_SCALE[f])
		if not is_equal_approx(e.output_scale, want_atk):
			bad_atk.append([f, e.output_scale, want_atk])
		if f >= 19:
			var want_res := float(res[str(f)]) if res.has(str(f)) else float(XGuardianRework.RESIST_TABLE[f])
			var got: Dictionary = XGuardianRework.harm_re(e, {1: 1.0})
			if not is_equal_approx(float(got.get(1, -1.0)), want_res):
				bad_res.append([f, got, want_res])
	bal.erase("guardian_phase4")
	if real is Dictionary:
		bal["guardian_phase4"] = real
	_check("tables.atk_scale_fallback", bad_atk.is_empty(), bad_atk)
	_check("tables.resist_fallback", bad_res.is_empty(), bad_res)
