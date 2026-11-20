extends Node
## 【cc·T285】天启篇首领暴击闪避按 D237 丙（首领暴击闪避评估 v0.2 第二节丙、第三节、第五节草稿卡）：
## 一、balance_table combat_rules.enemy_xparam_cap 全整数，cev_tiers 层段×难度（寻常 20／30／40，每升一档 +5）。
## 二、寻常 20／30／34 层守层者裸打暴击闪避 20／30／40%；艰险 25／35／45%（底子都高过上限，只看夹完的数）。
## 三、我方减益不再跟着 ×2、减法判定：34 层挂灵狐 −10%／荒芜 −30%／克拉辛 −50%／压制 25 后 CEV 30／10／0／15%，
##     面板 100% 实际暴击 70／90／100／85%；20／30 层裸打 80／70%、挂 −30% 后 100／100%（报告 3.1 表）。
## 四、下限 0：1 层守层者（底子 0）挂克拉辛 −50%，CEV 0，面板 70% 实际仍 70%（不再倒推成 100%）。
## 五、甚尔五感：34 层底子 40% 减半 20%，面板 100% 实际 80%；队友再挂 −20%（灵狐＋紫金法咒）后 100%。
## 六、开关：SUBTRACTIVE_CEV 关＝乘法（34 层 100%→60%、130%→78%）；ENEMY_XPARAM_CAP 关＝原式（底子＋减益一起 ×仓库倍率）；
##     SUPPRESS_CEV 关＝压制不减暴击闪避；TIANQI_CEV_HALF 关＝甚尔整份 ×0.34。
## 七、西游档：开关开着关着 XEnemy.xparam 与暴击计算一样。
## 八、T290：紫金法咒 188 天启篇 3 回合、回合末解除（auto 2）。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	XEnemy.force_roll = 100.0  # 守层者不按神话
	seed(20261120)
	var was := [XTianqiCombat.ENEMY_XPARAM_CAP, XTianqiCombat.SUBTRACTIVE_CEV, XTianqiAffixBattle.SUPPRESS_CEV, XToji.TIANQI_CEV_HALF]
	_check("switches.default_on", was == [true, true, true, true], was)
	_table()
	_floors()
	_debuffs()
	_floor_zero()
	_toji()
	_switches()
	_xiyou()
	_state188()
	XTianqiCombat.ENEMY_XPARAM_CAP = was[0]
	XTianqiCombat.SUBTRACTIVE_CEV = was[1]
	XTianqiAffixBattle.SUPPRESS_CEV = was[2]
	XToji.TIANQI_CEV_HALF = was[3]
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(tianqi := true, diff := "xunchang") -> XState:
	var lineup := [1, 2, 8, 9, 10]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, diff, lineup)
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


## 第 f 层守层者（34＝鸿钧）；返回 [logic, enemy]
func _guardian(f: int, tianqi := true, diff := "xunchang") -> Array:
	var s := _state(tianqi, diff)
	var troop := int(XGuardianRework.TROOPS.get(f, 469))
	if f == 34:
		s.flags.tianqi["line"] = "death"
		XTianqiSummit.prepare_hongjun(s)
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	for e in logic.enemies:
		if XGuardianRework.params_floor(e) > 0:
			return [logic, e]
	return [logic, null]


func _crit_skill() -> Dictionary:
	for id in range(2, 400):
		var s := XDB.rec("Skills", id)
		if not s.is_empty() and int(s.get("scope", 0)) == 1 and int(s.get("damage", {}).get("type", 0)) == 1 and bool(s.damage.get("critical", false)):
			return s
	return {}


func _add(e: XEnemy, id: int) -> void:
	e.state_ids.append(id)
	XActor.state_touch(id)
	e.param_mark_dirty()


func _table() -> void:
	var t := XTianqiCombat.xparam_cap_table()
	_check("table.loaded", not t.is_empty() and (t.get("cev_tiers", []) as Array).size() == 3, t.keys())
	var ints := true
	_check("table.eva_cri_mev_off", [int(t.get("eva", 0)), int(t.get("cri", 0)), int(t.get("mev", 0))] == [-1, -1, -1])
	for k in ["eva", "cri", "mev", "toji_cev_pct"]:
		ints = ints and t.get(k) is float and float(t[k]) == floorf(float(t[k]))  # JSON 读进来是 float，值是整数
	for r in t.get("cev_tiers", []):
		for v in (r.cap as Dictionary).values():
			ints = ints and float(v) == floorf(float(v))
	_check("table.integers", ints)
	_check("table.xunchang_row", [int(t.cev_tiers[0].cap.xunchang), int(t.cev_tiers[1].cap.xunchang), int(t.cev_tiers[2].cap.xunchang)] == [20, 30, 40])


func _floors() -> void:
	var want := {20: 0.20, 30: 0.30, 34: 0.40}
	var want_jx := {20: 0.25, 30: 0.35, 34: 0.45}
	var sk := _crit_skill()
	for f in want:
		var r := _guardian(f)
		var e: XEnemy = r[1]
		_check("f%d.found" % f, e != null)
		if e == null:
			continue
		var raw: float = float(e.xparam_parts(3)[0]) * e.warehouse_rate()
		var raws := []
		for i in [1, 2, 4]:
			raws.append(float(e.xparam_parts(i)[0]) * e.warehouse_rate())
		print("T285 f%d raw_cev=%s cev=%s eva=%s cri=%s mev=%s raw_eva_cri_mev=%s" % [f, raw, e.cev, e.eva, e.cri, e.mev, raws])
		_check("f%d.raw_above_cap" % f, raw >= float(want[f]), raw)
		_check("f%d.cev" % f, _near(e.cev, want[f]), e.cev)
		# eva／cri／mev 表里先 -1（不封顶，待 Kyo 定）：等于底子×仓库倍率（无减益时）
		_check("f%d.no_cap_eva_cri_mev" % f, _near(e.eva, raws[0]) and _near(e.cri, raws[1]) and _near(e.mev, raws[2]), [e.eva, e.cri, e.mev, raws])
		_check("f%d.crit100" % f, _near(XTianqiCombat.crit_after_cev(1.0, null, sk, e), 1.0 - float(want[f])))
		_check("f%d.crit130" % f, _near(minf(XTianqiCombat.crit_after_cev(1.3, null, sk, e), 1.0), minf(1.3 - float(want[f]), 1.0) if f != 34 else 0.9))
		# 整条 itemCri：面板暴击＋critPush − CEV（20 层起没有别的暴击包装时）
		var a: XActor = r[0].actors[0]
		var rate := a.cri + a.crit_push(sk)
		var ic: float = r[0].item_cri(a, sk, e)
		_check("f%d.item_cri" % f, _near(ic, clampf(rate - e.cev, 0.0, 1.0)), [ic, rate, e.cev])
		var rj := _guardian(f, true, "jianxian")
		_check("f%d.jianxian" % f, rj[1] != null and _near(rj[1].cev, want_jx[f]), rj[1].cev if rj[1] != null else null)
	# 20 层、30 层挂荒芜 −30%：面板 100% 实际 100%
	for f in [20, 30]:
		var e: XEnemy = _guardian(f)[1]
		if e == null:
			continue
		_add(e, 187)
		_check("f%d.huangwu" % f, _near(XTianqiCombat.crit_after_cev(1.0, null, sk, e), 1.0), e.cev)


func _debuffs() -> void:
	var sk := _crit_skill()
	var want := {1596: [0.30, 0.70], 187: [0.10, 0.90], 268: [0.0, 1.0]}
	for id in want:
		var r := _guardian(34)
		var e: XEnemy = r[1]
		if e == null:
			_check("d%d.found" % id, false)
			continue
		_add(e, int(id))
		_check("d%d.cev" % id, _near(e.cev, want[id][0]), [e.cev, e.xparam_parts(3)])
		_check("d%d.crit" % id, _near(XTianqiCombat.crit_after_cev(1.0, null, sk, e), want[id][1]))
	# 压制 25：34 层 40%→15%，面板 100% 实际 85%
	var r := _guardian(34)
	var e: XEnemy = r[1]
	r[0].set_meta("xaffix", {"units": {}})
	XAlienBattle._logic_ref = weakref(r[0])
	var u := XTianqiAffixBattle._unit(r[0], e)
	u.suppress = 25.0
	u.suppress_turns = 2
	_check("suppress.cev", _near(e.cev, 0.15), e.cev)
	_check("suppress.crit", _near(XTianqiCombat.crit_after_cev(1.0, null, sk, e), 0.85))
	XTianqiAffixBattle.SUPPRESS_CEV = false
	_check("suppress.off", _near(e.cev, 0.40), e.cev)
	XTianqiAffixBattle.SUPPRESS_CEV = true
	XAlienBattle._logic_ref = null


func _floor_zero() -> void:
	var sk := _crit_skill()
	var r := _guardian(1)
	var e: XEnemy = r[1]
	_check("f1.found", e != null)
	if e == null:
		return
	var base: float = e.xparam_parts(3)[0]
	_check("f1.base_zero", _near(base, 0.0), base)
	_add(e, 268)
	_check("f1.floor0", _near(e.cev, 0.0), e.cev)
	_check("f1.no_free_crit", _near(XTianqiCombat.crit_after_cev(0.7, null, sk, e), 0.7))
	XTianqiCombat.SUBTRACTIVE_CEV = false
	_check("f1.no_free_crit_mult", _near(XTianqiCombat.crit_after_cev(0.7, null, sk, e), 0.7))
	XTianqiCombat.SUBTRACTIVE_CEV = true
	XTianqiCombat.ENEMY_XPARAM_CAP = false
	_check("f1.old_negative", e.cev < 0.0, e.cev)  # 回退：原式没有下限（负暴击闪避）
	XTianqiCombat.ENEMY_XPARAM_CAP = true


func _toji() -> void:
	var r := _guardian(34)
	var e: XEnemy = r[1]
	var toji := XActor.new().setup(XToji.ACTOR)
	toji.learn_skill(XToji.SENSES)
	var main := XDB.rec("Skills", XToji.MAIN[0])
	_check("toji.knows", XToji.cev_rate(toji, main) < 1.0)
	_check("toji.cev_half", _near(e.cev_for_toji(50), 0.20), e.cev_for_toji(50))
	_check("toji.crit_alone", _near(XTianqiCombat.crit_after_cev(1.0, toji, main, e), 0.80))
	_add(e, 1596)
	_add(e, 188)
	_check("toji.team_debuff", _near(e.cev_for_toji(50), 0.0), [e.cev_for_toji(50), e.xparam_parts(3)])
	_check("toji.crit_team", _near(XTianqiCombat.crit_after_cev(1.0, toji, main, e), 1.0))
	XToji.TIANQI_CEV_HALF = false
	_check("toji.off", _near(XTianqiCombat.crit_after_cev(1.0, toji, main, e), 1.0 - e.cev * 0.34), e.cev)
	XToji.TIANQI_CEV_HALF = true


func _switches() -> void:
	var sk := _crit_skill()
	var e: XEnemy = _guardian(34)[1]
	XTianqiCombat.SUBTRACTIVE_CEV = false
	_check("mult.crit100", _near(XTianqiCombat.crit_after_cev(1.0, null, sk, e), 0.60))
	_check("mult.crit130", _near(XTianqiCombat.crit_after_cev(1.3, null, sk, e), 0.78))
	XTianqiCombat.SUBTRACTIVE_CEV = true
	_add(e, 1596)
	XTianqiCombat.ENEMY_XPARAM_CAP = false
	var old: float = (float(e.xparam_parts(3)[0]) + float(e.xparam_parts(3)[1])) * e.warehouse_rate()
	_check("cap_off.old_formula", _near(e.cev, old), [e.cev, old])
	_check("cap_off.debuff_x2", e.warehouse_rate() == 1.0 or not _near(e.cev, float(e.xparam_parts(3)[0]) * e.warehouse_rate() - 0.1))
	XTianqiCombat.ENEMY_XPARAM_CAP = true
	_check("cap_on.debuff_x1", _near(e.cev, 0.30), e.cev)


func _xiyou() -> void:
	var sk := _crit_skill()
	var r := _guardian(30, false)
	var e: XEnemy = r[1]
	_check("xiyou.found", e != null)
	if e == null:
		return
	_add(e, 187)
	var on := [e.xparam(1), e.xparam(2), e.xparam(3), e.xparam(4), XTianqiCombat.crit_after_cev(1.0, null, sk, e)]
	XTianqiCombat.ENEMY_XPARAM_CAP = false
	XTianqiCombat.SUBTRACTIVE_CEV = false
	var off := [e.xparam(1), e.xparam(2), e.xparam(3), e.xparam(4), XTianqiCombat.crit_after_cev(1.0, null, sk, e)]
	XTianqiCombat.ENEMY_XPARAM_CAP = true
	XTianqiCombat.SUBTRACTIVE_CEV = true
	_check("xiyou.same", on == off, [on, off])
	_check("xiyou.mult", _near(float(on[4]), maxf(1.0, 0.0) * (1.0 - e.cev)))


func _state188() -> void:
	_state(true)
	var st := XDB.rec("States", 188)
	var tq := st  # 天启篇存档里 XDB.rec 已换成改写后的状态（XTianqiSkills.rec_state）
	print("T285 state188 ", [tq.get("minTurns"), tq.get("autoRemovalTiming")])
	_check("s188.turns", int(tq.get("minTurns", 0)) == 3 and int(tq.get("maxTurns", 0)) == 3, [tq.get("minTurns"), tq.get("maxTurns")])
	_check("s188.auto", int(tq.get("autoRemovalTiming", 0)) == 2, tq.get("autoRemovalTiming"))
