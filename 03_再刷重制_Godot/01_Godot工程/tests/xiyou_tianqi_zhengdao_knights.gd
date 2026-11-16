extends Node
## 证道骑士规则表专项（horsemen.json 的 zhengdao 节，全弱者证道资格 v0.4.4 第一节第 3 条；cc/zhengdao-rules-fill）。
## 一、只在证道 36 层本体战生效：别的档、生存战、35 层影子查不到规则。
## 二、狂暴（D58 莉co、D74 混子、D81 做题家）：倍率 2＋(回合−R)；只乘骑士本体、援军不乘；混子疫病掉血同乘、狂暴后治疗再减半；
##     做题家与莉co／混子各一个开关，互不牵连；勇者没有伤害狂暴。
## 三、回血：勇者每回合末回 2%（D82）、莉co回 1.5%（D58），各一个开关；艰险没有。
## 四、勇者甲（D32、D54）：死期从出战栏最后一格往前点；到第 doom_every_from 回合起每回合点一人；开关关掉照旧（5 回合、随机）。
## 数是 v044 参考组占位（T014 标数），断言都从表里读，改数不用改测试。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a: float, b: float, eps := 1e-6) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(key: String, tough := 200000000.0) -> XState:
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


func _logic(line: String, key := "zhengdao", mode := "body") -> XBattleLogic:
	var s := _state(key)
	XTianqiHorsemen.prepare(line, s, mode)
	var lg := XBattleLogic.new()
	lg.setup(0, s)
	return lg


func _hp(lg: XBattleLogic, u, t, v: float) -> void:
	lg._action_resources = lg._new_lifecycle_resources()
	lg.execute_hp_damage(u, t, v, false)
	lg._action_resources = null


func _guard_all(lg: XBattleLogic) -> Dictionary:
	var c := {}
	for a in lg.actors:
		if a.is_alive():
			c[a] = [XDB.rec("Skills", 2), null]
	return c


func _row(line: String) -> Dictionary:
	return XTianqiHorsemen.zd_table().get(line, {})


func _run() -> void:
	XMessageBox.auto = true
	seed(20261116)
	_scope()
	_enrage()
	_plague_enrage()
	_regen()
	_doom()
	_reset()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _reset() -> void:
	XTianqiHorsemen.ZD_ENRAGE = true
	XTianqiHorsemen.ZD_FAMINE_ENRAGE = true
	XTianqiHorsemen.ZD_DEATH_REGEN = true
	XTianqiHorsemen.ZD_WAR_REGEN = true
	XTianqiHorsemen.ZD_DOOM = true


# ---- 一、范围 ----

func _scope() -> void:
	var z := XTianqiHorsemen.zd_table()
	_check("table_present", not z.is_empty() and str(z.get("key", "")) == "zhengdao", z.keys())
	_check("table_nice_numbers", XTianqiHorsemen.nice_number_violations().is_empty(), XTianqiHorsemen.nice_number_violations())
	for line in XTianqiHorsemen.LINES:
		var lg := _logic(line)
		var f := XTianqiHorsemen.fight(lg)
		_check("zd_rule_" + line, not XTianqiHorsemen.zd_rule(f).is_empty())
		lg.end_battle(0)
		for key in ["jiusi", "lianyu"]:
			var lg2 := _logic(line, key)
			var f2 := XTianqiHorsemen.fight(lg2)
			_check("no_rule_%s_%s" % [line, key], XTianqiHorsemen.zd_rule(f2).is_empty() and XTianqiHorsemen.enrage_turn(f2) == 0 and XTianqiHorsemen.zd_regen_rate(f2) == 0.0)
			lg2.end_battle(0)
		for mode in ["survival", "shadow"]:
			var lg3 := _logic(line, "zhengdao", mode)
			var f3 := XTianqiHorsemen.fight(lg3)
			_check("no_rule_%s_%s" % [line, mode], not f3.is_empty() and XTianqiHorsemen.zd_rule(f3).is_empty() and XTianqiHorsemen.enrage_turn(f3) == 0)
			lg3.end_battle(0)


# ---- 二、狂暴 ----

func _enrage() -> void:
	for line in ["war", "plague", "famine"]:
		var r := int(_row(line).get("enrage", 0))
		_check("enrage_set_" + line, r > 0, r)
		var lg := _logic(line)
		var f := XTianqiHorsemen.fight(lg)
		_check("enrage_turn_" + line, XTianqiHorsemen.enrage_turn(f) == r)
		lg.turn = r - 1
		_check("enrage_before_" + line, XTianqiHorsemen.enrage_mult(lg) == 1.0)
		lg.turn = r
		_check("enrage_x2_" + line, _near(XTianqiHorsemen.enrage_mult(lg), 2.0))
		lg.turn = r + 2
		_check("enrage_x4_" + line, _near(XTianqiHorsemen.enrage_mult(lg), 2.0 + 2.0 * float(XTianqiHorsemen.zd_table().get("enrage_step", 1.0))))
		# 实打：同一段本体伤害在狂暴回合 ×倍率；援军／小怪不乘
		var kn: XEnemy = f.knight
		var t: XActor = lg.actors[0]
		var sk := XTianqiHorsemen._skill("probe", "探针", 1, 1, 1.0, false)
		lg.turn = r - 1
		t.recover_all()
		var v1 := float(XTianqiHorsemen._strike(lg, kn, t, sk, 100000.0, false).hp)
		lg.turn = r + 2
		t.recover_all()
		var v3 := float(XTianqiHorsemen._strike(lg, kn, t, sk, 100000.0, false).hp)
		var m := XTianqiHorsemen.enrage_mult(lg)
		_check("enrage_hit_" + line, v1 > 0.0 and absf(v3 - v1 * m) <= m + 1.0, [v1, v3, m])
		if not f.adds.is_empty():
			var e: XEnemy = f.adds[0]
			lg.turn = r - 1
			t.recover_all()
			var a1 := float(XTianqiHorsemen._strike(lg, e, t, sk, 100000.0, false).hp)
			lg.turn = r + 2
			t.recover_all()
			var a3 := float(XTianqiHorsemen._strike(lg, e, t, sk, 100000.0, false).hp)
			_check("enrage_add_unchanged_" + line, _near(a1, a3), [a1, a3])
		# 开关：做题家只看 ZD_FAMINE_ENRAGE，莉co／混子只看 ZD_ENRAGE
		XTianqiHorsemen.ZD_ENRAGE = false
		var off_main := XTianqiHorsemen.enrage_mult(lg)
		XTianqiHorsemen.ZD_ENRAGE = true
		XTianqiHorsemen.ZD_FAMINE_ENRAGE = false
		var off_famine := XTianqiHorsemen.enrage_mult(lg)
		XTianqiHorsemen.ZD_FAMINE_ENRAGE = true
		if line == "famine":
			_check("switch_famine_enrage", off_famine == 1.0 and off_main > 1.0, [off_main, off_famine])
		else:
			_check("switch_enrage_" + line, off_main == 1.0 and off_famine > 1.0, [off_main, off_famine])
		# 进入狂暴回合时日志报一句
		lg.turn = r - 1
		var logs := lg.run_turn(_guard_all(lg))
		_check("enrage_log_" + line, logs.any(func(l): return l.type == "battle_text" and str(l.text).contains("狂暴")), lg.turn)
		lg.end_battle(0)
	# 勇者没有伤害狂暴
	var ld := _logic("death")
	ld.turn = 30
	_check("death_no_enrage", XTianqiHorsemen.enrage_mult(ld) == 1.0 and not _row("death").has("enrage"))
	ld.end_battle(0)


func _plague_enrage() -> void:
	var r := int(_row("plague").enrage)
	var heal := float(XTianqiHorsemen.zd_table().get("plague_enrage_heal", 0.5))
	var down := float(XTianqiHorsemen.knight("plague").plague.heal_down)
	var dot := float(XTianqiHorsemen.knight("plague").plague.dot)
	var lg := _logic("plague")
	var a: XActor = lg.actors[0]
	# 狂暴前：治疗只吃疫病的 −50%
	lg.turn = r - 1
	a.hp = a.mhp * 0.5
	var h0 := a.hp
	_hp(lg, a, a, -1000.0)
	_check("plague_heal_before", _near(a.hp - h0, 1000.0 * (1.0 - down)), a.hp - h0)
	lg.turn = r
	a.hp = a.mhp * 0.5
	h0 = a.hp
	_hp(lg, a, a, -1000.0)
	_check("plague_heal_enraged", _near(a.hp - h0, 1000.0 * (1.0 - down) * heal), a.hp - h0)
	XTianqiHorsemen.ZD_ENRAGE = false
	a.hp = a.mhp * 0.5
	h0 = a.hp
	_hp(lg, a, a, -1000.0)
	_check("switch_plague_heal", _near(a.hp - h0, 1000.0 * (1.0 - down)), a.hp - h0)
	XTianqiHorsemen.ZD_ENRAGE = true
	# 疫病掉血同乘（第 R 回合末 ×2）
	lg.turn = r - 1
	for x in lg.actors:
		x.recover_all()
	var mhp := a.mhp
	var logs := lg.run_turn(_guard_all(lg))
	_check("plague_dot_enraged", logs.any(func(l): return l.type == "regen" and is_same(l.target, a) and _near(float(l.hp), floorf(mhp * dot * 2.0))), [mhp, logs.filter(func(l): return l.type == "regen" and is_same(l.target, a)).map(func(l): return l.hp)])
	lg.end_battle(0)


# ---- 三、回血 ----

func _knight_regen(logs: Array, kn) -> Array:
	return logs.filter(func(l): return l.type == "regen" and is_same(l.target, kn) and float(l.hp) < 0.0).map(func(l): return -float(l.hp))


func _regen() -> void:
	for line in ["death", "war"]:
		var rate := float(_row(line).get("regen", 0.0))
		_check("regen_set_" + line, rate > 0.0, rate)
		var lg := _logic(line)
		var kn: XEnemy = XTianqiHorsemen.fight(lg).knight
		kn.hp = floorf(kn.mhp * 0.8)  # 留在第一阶段
		var logs := lg.run_turn(_guard_all(lg))
		var got := _knight_regen(logs, kn)
		_check("regen_" + line, got.size() == 1 and absf(got[0] - floorf(kn.mhp * rate)) <= 1.0, [got, kn.mhp, rate])
		# 满血不回、不报
		kn.hp = kn.mhp
		_check("regen_full_" + line, _knight_regen(lg.run_turn(_guard_all(lg)), kn).is_empty())
		# 开关
		if line == "death":
			XTianqiHorsemen.ZD_DEATH_REGEN = false
		else:
			XTianqiHorsemen.ZD_WAR_REGEN = false
		kn.hp = floorf(kn.mhp * 0.8)
		_check("switch_regen_" + line, _knight_regen(lg.run_turn(_guard_all(lg)), kn).is_empty())
		_reset()
		lg.end_battle(0)
		# 炼狱没有
		var lg2 := _logic(line, "lianyu")
		var k2: XEnemy = XTianqiHorsemen.fight(lg2).knight
		k2.hp = floorf(k2.mhp * 0.8)
		_check("no_regen_lianyu_" + line, _knight_regen(lg2.run_turn(_guard_all(lg2)), k2).is_empty())
		lg2.end_battle(0)
	# 做题家、混子没有回血
	for line in ["famine", "plague"]:
		var lg3 := _logic(line)
		_check("no_regen_" + line, XTianqiHorsemen.zd_regen_rate(XTianqiHorsemen.fight(lg3)) == 0.0)
		lg3.end_battle(0)


# ---- 四、勇者甲 ----

func _doomed(lg: XBattleLogic) -> Array:
	return lg.actors.filter(func(a): return bool(XTianqiHorsemen.mark_of(lg, a).get("doom", false)))


## 跑到回合开头（start_turn 挂完死期、还没回合末带走），看点了谁
func _doom_at(lg: XBattleLogic, turn: int, last: int) -> Array:
	var f := XTianqiHorsemen.fight(lg)
	lg.turn = turn - 1
	f.doom_last = last
	lg.start_turn()
	lg.take_turn_start_logs()
	return _doomed(lg)


func _doom() -> void:
	var every := int(_row("death").get("doom_every_from", 0))
	_check("doom_every_set", every > 0 and bool(_row("death").get("doom_from_last", false)), _row("death"))
	# 第 5 回合（距上次 5 回合）：点出战栏最后一格（活着的）
	var lg := _logic("death")
	var d := _doom_at(lg, 5, 0)
	_check("doom_last_slot", d.size() == 1 and is_same(d[0], lg.actors[lg.actors.size() - 1]), d.map(func(a): return a.display_name()))
	XTianqiHorsemen.mark_of(lg, d[0]).erase("doom")
	# 最后一格倒下了就往前一格
	var last: XActor = lg.actors[lg.actors.size() - 1]
	last.hp = 0.0
	last.refresh_resources()
	lg._die(last)
	d = _doom_at(lg, 10, 5)
	_check("doom_prev_slot", d.size() == 1 and is_same(d[0], lg.actors[lg.actors.size() - 2]), d.map(func(a): return a.display_name()))
	XTianqiHorsemen.mark_of(lg, d[0]).erase("doom")
	# 加速前：距上次 1 回合不点
	d = _doom_at(lg, every - 1, every - 2)
	_check("doom_not_every_before", d.is_empty(), every)
	# 加速后：距上次 1 回合也点，连着两回合
	d = _doom_at(lg, every, every - 1)
	_check("doom_every_turn_a", d.size() == 1, every)
	for a in d:
		XTianqiHorsemen.mark_of(lg, a).erase("doom")
	d = _doom_at(lg, every + 1, every)
	_check("doom_every_turn_b", d.size() == 1, every + 1)
	for a in d:
		XTianqiHorsemen.mark_of(lg, a).erase("doom")
	# 开关关掉：加速没了（5 回合）
	XTianqiHorsemen.ZD_DOOM = false
	d = _doom_at(lg, every + 2, every + 1)
	_check("switch_doom_interval", d.is_empty())
	_check("switch_doom_rule", XTianqiHorsemen.zd_doom(XTianqiHorsemen.fight(lg)).is_empty())
	_reset()
	lg.end_battle(0)
	# 炼狱：照旧（不加速、随机点）
	var lg2 := _logic("death", "lianyu")
	_check("doom_lianyu_plain", XTianqiHorsemen.zd_doom(XTianqiHorsemen.fight(lg2)).is_empty())
	d = _doom_at(lg2, every, every - 1)
	_check("doom_lianyu_no_accel", d.is_empty())
	lg2.end_battle(0)
	# 实打一回合：死期回合末带走最后一格
	var lg3 := _logic("death")
	var f3 := XTianqiHorsemen.fight(lg3)
	lg3.turn = 4
	f3.doom_last = 0
	var tail: XActor = lg3.actors[lg3.actors.size() - 1]
	lg3.run_turn(_guard_all(lg3))
	_check("doom_kills_last", tail.is_dead() and lg3.actors.filter(func(a): return a.is_dead()).size() == 1, lg3.actors.map(func(a): return a.hp))
	lg3.end_battle(0)
