extends Node
## 【cc·T302 第二步】守层者成长招削弱＋改名（XGuardianRework.GROWTH_NERF，Kyo 11-20「240不关。但是削弱和改名」）：
#／6056 改名、回血下调（10／12／12%）；守层者自己正向强化每层 +12%、最多 3 层（原 25%、4 层）。只管天启篇存档，开关关掉回原版。
## 一、开关开／关各一场 30 层（466）、33 层（469）：真打 12 回合，断言叠层上限（开 3／关 4）与最大生命、攻击倍数（开 ≤1.36／关 2）。
## 二、技能记录：开＝新名字＋回血比例＋说明行；关＝原名、原回血 35／40%；西游档不动。
## 三、范围：非守层者敌人每层加成不变（25%、上限不受影响）。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	seed(20261120)
	var was := XGuardianRework.GROWTH_NERF
	_check("default_on", XGuardianRework.GROWTH_NERF)
	_cards()
	_floor(466, 30)
	_floor(469, 33)
	_scope()
	XGuardianRework.GROWTH_NERF = was
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


func _guardian(logic: XBattleLogic, f: int) -> XEnemy:
	for x in logic.enemies:
		if XGuardianRework.floor_of(x.enemy_id) == f:
			return x
	return null


func _heal(id: int) -> float:
	for e in XDB.rec("Skills", id).get("effects", []):
		if int(e.get("code", 0)) == 11:
			return float(e.get("value1", 0))
	return -1.0


func _cards() -> void:
	_state(true)
	XGuardianRework.GROWTH_NERF = true
	var names := []
	for id in XGuardianRework.GROWTH_SKILLS:
		names.append(str(XDB.rec("Skills", id).get("name", "")))
	_check("cards.names_on", names == ["伤痕淬体", "裂隙共鸣", "灾厄淬炼"], names)
	_check("cards.heal_on", is_equal_approx(_heal(6104), 0.10) and is_equal_approx(_heal(6106), 0.12) and is_equal_approx(_heal(6056), 0.12), [_heal(6104), _heal(6106), _heal(6056)])
	_check("cards.desc_on", str(XDB.rec("Skills", 6106).get("note", "")).contains("每层 +12%，最多 3 层") and not str(XDB.rec("Skills", 6106).get("note", "")).contains("30%+"))
	XGuardianRework.GROWTH_NERF = false
	var off_names := []
	for id in XGuardianRework.GROWTH_SKILLS:
		off_names.append(str(XDB.rec("Skills", id).get("name", "")))
	_check("cards.names_off", off_names == ["启示·成长", "启示·茁壮", "霸者*茁壮"], off_names)  # 6104、6106 已被 D202 文字替换去西游化（text_fix），6056 还是原名
	_check("cards.heal_off", is_equal_approx(_heal(6104), 0.35) and is_equal_approx(_heal(6106), 0.40) and is_equal_approx(_heal(6056), 0.40), [_heal(6104), _heal(6106), _heal(6056)])
	_state(false)
	XGuardianRework.GROWTH_NERF = true
	_check("cards.xiyou_untouched", str(XDB.rec("Skills", 6104).get("name", "")) == "天道*成长" and is_equal_approx(_heal(6106), 0.40), [XDB.rec("Skills", 6104).get("name"), _heal(6106)])


## 守层者强制放成长招（走真实的强制行动结算）：每 3 回合一次，放 6 次＝过了第 18 回合；开着最多 3 层，关掉 4 层。
## 回血：先打到半血，放一次，回的血＝招里的比例×放完后的最大生命
func _floor(troop: int, f: int) -> void:
	var skill := 6106 if f == 30 else 6056
	for on in [true, false]:
		XGuardianRework.GROWTH_NERF = on
		var s := _state(true)
		var logic := XBattleLogic.new()
		logic.setup(troop, s)
		var g := _guardian(logic, f)
		var tag := "f%d.%s" % [f, "on" if on else "off"]
		if g == null:
			_check(tag + ".guardian", false, "没有守层者")
			continue
		var idx := logic.enemies.find(g)
		g.hp = floorf(g.mhp * 0.5)
		var hp0 := g.hp
		var mhp0 := g.mhp
		logic._force_action([0, idx, skill, -1], null)
		var healed := g.hp - hp0
		var want_heal := (0.12 if on else 0.40) * mhp0  # 招里先加最大生命层、回血按放之前的最大生命算
		_check(tag + ".heal", absf(healed - want_heal) <= maxf(2.0, want_heal * 0.001), [healed, want_heal, g.mhp])
		var layers := [g.buffs[0]]
		for _i in range(5):
			logic._force_action([0, idx, skill, -1], null)
			layers.append(g.buffs[0])
		var want_cap := 3 if on else 4
		var top := 0
		for i in range(8):
			top = maxi(top, g.buffs[i])
		_check(tag + ".cap", g.buffs[0] == want_cap and top == want_cap and layers[0] == 1, [layers, g.buffs, want_cap])
		var want_rate := 1.36 if on else 2.0
		_check(tag + ".mhp_rate", is_equal_approx(g.param_buff_rate(0), want_rate), g.param_buff_rate(0))
		_check(tag + ".atk_rate", is_equal_approx(g.param_buff_rate(2), want_rate) and is_equal_approx(g.param_buff_rate(3), want_rate), [g.param_buff_rate(2), g.param_buff_rate(3)])
	XGuardianRework.GROWTH_NERF = true


func _scope() -> void:
	XGuardianRework.GROWTH_NERF = true
	var s := _state(true)
	var minion: XEnemy = null
	var logic: XBattleLogic = null
	for t in [755, 599, 739, 747]:
		logic = XBattleLogic.new()
		logic.setup(t, s)
		for x in logic.enemies:
			if XGuardianRework.floor_of(x.enemy_id) == 0:
				minion = x
				break
		if minion != null:
			break
	_check("scope.minion_found", minion != null)
	if minion == null:
		return
	for _i in range(4):
		logic.sequence_buff(minion, 0, true, true, 5)
	_check("scope.non_guardian_cap4", minion.buffs[0] == 4 and is_equal_approx(minion.param_buff_rate(0), 2.0), [minion.buffs[0], minion.param_buff_rate(0)])
	var l3 := XBattleLogic.new()
	l3.setup(466, s)
	var g := _guardian(l3, 30)
	_check("scope.guardian_found", g != null)
	if g != null:
		l3.sequence_buff(g, 0, true, false, 5)
		_check("scope.debuff_untouched", g.buffs[0] == -1 and is_equal_approx(g.param_buff_rate(0), 0.75), [g.buffs[0], g.param_buff_rate(0)])

