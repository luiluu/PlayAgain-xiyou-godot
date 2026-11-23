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
## r2（小A 核 r1）：
## 九、存档照开局置 DCultyL1～8（天启篇＝本档借的原版难度，现为 3），仓库倍率真为 2：底子、减益都不 ×2（P1-2、P1-3）；
##     8／10／15 层守层者原底子 5／10／15% 照原值，16 层艰险 20%；8～19 层寻常、证道都等于 min(原底子, 上限)。
## 十、eva／cri／mev 上限 -1 时零影响（P1-1）：1 层守层者负闪避照旧 ×2（−40%），20／34 层挂紫金法咒时闪避、魔法闪避开关前后一样。
## 十一、守层者残血变身（30 层玉皇大帝 → 538）在非楼层地图仍按 30 层段（P2-3）。
## 十二、封顶关、减法开：攻击方暴击 ≤0 时不因负暴击闪避倒推（P3-1）。
## 【cc·T397】D242 按难度（Kyo 11-22「按难度来调整」）：eva／cri／mev 上限按五档难度键（寻常 30／50／30，每档 +5，证道 50／70／50）。
## 上面一～十二节量的是 T285 机制本身，照旧在 eva／cri／mev 写回 -1 的表上跑（_xpc_off）；十三节 _d242 量开着的表：
## 十三、30 层守层者三档夹到上限、10 层原值低于上限照原值不 ×2、1 层负闪避留原值 −20%（不 ×2、不抬 0）、小怪敌群同样封顶、
##     开关关／表写回 -1 退回 ×2、西游档开着关着一样。

var results: Array = []
var _xpc_off := true   # T397：一～十二节在 eva／cri／mev＝-1 的表上跑
var _xpc_saved := {}


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
	var was_strip := XGuardianRework.STRIP
	XGuardianRework.STRIP = false  # T348 起天启篇守层者默认清掉正值双闪暴闪回血；本专项量的是机制本身，借守层者原数据的正值（别的敌人照吃这套）
	var was := [XTianqiCombat.ENEMY_XPARAM_CAP, XTianqiCombat.SUBTRACTIVE_CEV, XTianqiAffixBattle.SUPPRESS_CEV, XToji.TIANQI_CEV_HALF]
	_check("switches.default_on", was == [true, true, true, true], was)
	_table()
	_xpc_apply()
	_floors()
	_debuffs()
	_floor_zero()
	_toji()
	_switches()
	_xiyou()
	_state188()
	_low_floors()
	_zero_impact()
	_transform()
	_immune()
	_xpc_off = false
	_d242()
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
	XGuardianRework.STRIP = was_strip
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
	# 开局事件置的难度怪物属性（Map001 EV1 与选难度分支，XTianqi.opening_commands）：take_pending 丢了指令，这里照写（r2 P1-3）
	var legacy := XTianqi.legacy_of(diff) if tianqi else 3
	for i in range(1, 9):
		s.flags["DCultyL%d" % i] = i == legacy
	s.map_id = 4
	XState.current = s
	_xpc_apply()
	return s


## T397：按 _xpc_off 把 eva／cri／mev 改成 -1 或还原（建档后调，防重读数据表）
func _xpc_apply() -> void:
	var t := XTianqiCombat.xparam_cap_table()
	for k in ["eva", "cri", "mev"]:
		if not _xpc_saved.has(k) and t.has(k) and not (t[k] is float and int(t[k]) == -1):
			_xpc_saved[k] = t[k]
		if _xpc_off:
			t[k] = -1
		elif _xpc_saved.has(k):
			t[k] = _xpc_saved[k]


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
	var want := {"eva": [30, 35, 40, 45, 50], "cri": [50, 55, 60, 65, 70], "mev": [30, 35, 40, 45, 50]}
	for k in want:
		var v = t.get(k)
		_check("table.%s_by_diff" % k, v is Dictionary and v.keys() == ["xunchang", "jianxian", "jiusi", "lianyu", "zhengdao"] and v.values().map(func(x): return int(x)) == want[k], v)
		if v is Dictionary:
			for x in v.values():
				ints = ints and float(x) == floorf(float(x))
	ints = ints and t.get("toji_cev_pct") is float and float(t.toji_cev_pct) == floorf(float(t.toji_cev_pct))  # JSON 读进来是 float，值是整数
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
		_check("f%d.warehouse2" % f, e.warehouse_rate() == 2.0, e.warehouse_rate())
		var raw: float = float(e.xparam_parts(3)[0])  # 数据库原底子（不含 ×2）
		var raws := []
		for i in [1, 2, 4]:
			raws.append(float(e.xparam_parts(i)[0]) * e.warehouse_rate())  # eva／cri／mev 照原路，含 ×2
		print("T285 f%d raw_cev=%s cev=%s eva=%s cri=%s mev=%s eva_cri_mev_x2=%s" % [f, raw, e.cev, e.eva, e.cri, e.mev, raws])
		_check("f%d.raw_above_cap" % f, raw >= float(want[f]), raw)
		_check("f%d.cev" % f, _near(e.cev, want[f]), e.cev)
		# eva／cri／mev 表里先 -1（不封顶，待 Kyo 定）：照原路＝底子×仓库倍率（无减益时）
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
	# T312 云裳派生暴击底子：开关关＝改前乘法；开＝减法、攻击方 ≤0 为 0
	var ys := _Src.new()
	ys.cri = 1.0
	_check("ys.mult100", _near(XYunshang.derived_base_cri(ys, sk, e), 0.60))
	ys.cri = 1.3
	_check("ys.mult130", _near(XYunshang.derived_base_cri(ys, sk, e), 0.78))
	XTianqiCombat.SUBTRACTIVE_CEV = true
	ys.cri = 1.0
	_check("ys.sub100", _near(XYunshang.derived_base_cri(ys, sk, e), XTianqiCombat.crit_after_cev(1.0, null, sk, e)))
	ys.cri = 0.3
	_check("ys.sub_floor0", _near(XYunshang.derived_base_cri(ys, sk, e), maxf(0.3 - e.cev, 0.0)), e.cev)
	ys.cri = -0.2
	_check("ys.sub_neg0", _near(XYunshang.derived_base_cri(ys, sk, e), 0.0))
	XTianqiCombat.SUBTRACTIVE_CEV = true
	_add(e, 1596)
	XTianqiCombat.ENEMY_XPARAM_CAP = false
	_check("cap_off.warehouse2", e.warehouse_rate() == 2.0, e.warehouse_rate())
	var base: float = e.xparam_parts(3)[0]
	_check("cap_off.debuff_x2", _near(e.cev, (base - 0.1) * 2.0), [e.cev, base])  # 回退：底子、减益一起 ×2
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
	_check("xiyou.warehouse2", e.warehouse_rate() == 2.0, e.warehouse_rate())
	_check("xiyou.same", on == off, [on, off])
	_check("xiyou.mult", _near(float(on[4]), maxf(1.0, 0.0) * (1.0 - e.cev)))


func _state188() -> void:
	_state(true)
	var st := XDB.rec("States", 188)
	var tq := st  # 天启篇存档里 XDB.rec 已换成改写后的状态（XTianqiSkills.rec_state）
	print("T285 state188 ", [tq.get("minTurns"), tq.get("autoRemovalTiming")])
	_check("s188.turns", int(tq.get("minTurns", 0)) == 3 and int(tq.get("maxTurns", 0)) == 3, [tq.get("minTurns"), tq.get("maxTurns")])
	_check("s188.auto", int(tq.get("autoRemovalTiming", 0)) == 2, tq.get("autoRemovalTiming"))


## r2 P1-2：8～19 层守层者底子不 ×2，等于 min(原底子, 上限)；打印给交付单列表
func _low_floors() -> void:
	var cap24 := {"xunchang": 0.20, "jianxian": 0.25, "jiusi": 0.30, "lianyu": 0.35, "zhengdao": 0.40}
	for f in range(8, 20):
		for diff in ["xunchang", "zhengdao"]:
			var e: XEnemy = _guardian(f, true, diff)[1]
			if e == null:
				_check("low.f%d.%s.found" % [f, diff], false)
				continue
			var raw: float = e.xparam_parts(3)[0]
			var want := minf(raw, float(cap24[diff]))
			if diff == "xunchang":
				print("T285 low f%d enemy=%d raw_cev=%s cev=%s" % [f, e.enemy_id, raw, e.cev])
			_check("low.f%d.%s" % [f, diff], _near(e.cev, want), [e.cev, raw, want])
	var spot := {8: 0.05, 10: 0.10, 15: 0.15}
	for f in spot:
		var e: XEnemy = _guardian(f)[1]
		_check("low.f%d.raw" % f, e != null and e.warehouse_rate() == 2.0 and _near(e.cev, spot[f]), e.cev if e != null else null)
	var e16: XEnemy = _guardian(16, true, "jianxian")[1]
	_check("low.f16.jianxian", e16 != null and _near(e16.cev, 0.20), e16.cev if e16 != null else null)


## r2 P1-1：上限 -1 的项（eva／cri／mev）零影响
func _zero_impact() -> void:
	var e: XEnemy = _guardian(1)[1]
	_check("zero.f1.found", e != null)
	if e != null:
		var on := e.eva
		XTianqiCombat.ENEMY_XPARAM_CAP = false
		var off := e.eva
		XTianqiCombat.ENEMY_XPARAM_CAP = true
		print("T285 f1 eva on=%s off=%s" % [on, off])
		_check("zero.f1.eva_neg", on == off and on < 0.0 and _near(on, float(e.xparam_parts(1)[0]) * 2.0), [on, off])
	for f in [20, 34]:
		var g: XEnemy = _guardian(f)[1]
		if g == null:
			_check("zero.f%d.found" % f, false)
			continue
		_add(g, 188)
		var on2 := [g.xparam(1), g.xparam(2), g.xparam(4)]
		XTianqiCombat.ENEMY_XPARAM_CAP = false
		var off2 := [g.xparam(1), g.xparam(2), g.xparam(4)]
		XTianqiCombat.ENEMY_XPARAM_CAP = true
		_check("zero.f%d.zijin_eva_mev" % f, on2 == off2, [on2, off2])
		_check("zero.f%d.zijin_x2" % f, _near(float(on2[0]), (float(g.xparam_parts(1)[0]) - 0.1) * 2.0), on2)


## r2 P2-3：守层者残血变身后在非楼层地图仍按原层段；P3-1 负暴击不倒推
func _transform() -> void:
	var r := _guardian(30)
	var e: XEnemy = r[1]
	_check("tf.map_not_floor", XDungeon.map_floor(XState.current.map_id) == 0, XState.current.map_id)
	if e == null:
		_check("tf.found", false)
		return
	r[0].enemy_transform(r[0].enemies.find(e), 538)
	_check("tf.id", e.enemy_id == 538, e.enemy_id)
	_check("tf.raw_above", float(e.xparam_parts(3)[0]) >= 0.30, e.xparam_parts(3))
	_check("tf.keep_30", _near(e.cev, 0.30), e.cev)
	_check("tf.gr_floor_30", int(e.get_meta(XGuardianRework.META_FLOOR, 0)) == 30, e.get_meta(XGuardianRework.META_FLOOR, 0))  # T317：变身也记守层者层（出伤、伤害抵抗）
	e.remove_meta(XTianqiCombat.META_KEEP_FLOOR)
	e.remove_meta(XGuardianRework.META_FLOOR)  # T317 起 enemy_floor 回退会读到它，反证要两个都去掉
	_check("tf.without_keep_20", _near(e.cev, 0.20), e.cev)  # 反证：不记层就掉回第一档
	var sk := _crit_skill()
	var g: XEnemy = _guardian(1)[1]
	_add(g, 268)
	XTianqiCombat.ENEMY_XPARAM_CAP = false
	_check("p31.neg_rate", _near(XTianqiCombat.crit_after_cev(-0.2, null, sk, g), 0.0), g.cev)
	XTianqiCombat.ENEMY_XPARAM_CAP = true


## T285 r3：真免暴击在封顶开着时仍是 0（死亡骑士 crit_immune、免暴击标记 META_CRIT_IMMUNE）；
## 反向：暴击闪避特性（如银鳞盾 +1000%）是底子，开封顶会被夹到层段上限、不再免暴；关封顶才回到「暴不出来」。七印魔塔 no_crit 见 xiyou_tianqi_qiyin_altar。
func _immune() -> void:
	var sk := _crit_skill()
	# 死亡骑士（实机准备流程，天启篇存档、封顶开）
	var s := _state(true, "jianxian")
	XTianqiHorsemen.prepare("death", s)
	var lg := XBattleLogic.new()
	lg.setup(0, s)
	var kn: XEnemy = lg.enemies[0]
	var a: XActor = lg.actors[0]
	_check("im.cap_on", XTianqiCombat.cap_on() and XTianqiCombat.xparam_cap_pct(kn, 3) >= 0, XTianqiCombat.xparam_cap_pct(kn, 3))
	_check("im.knight", XTianqiHorsemen.crit_immune(kn))
	_check("im.knight_zero", is_zero_approx(lg.item_cri(a, sk, kn)), lg.item_cri(a, sk, kn))
	_add(kn, 1596)  # 挂降暴闪也不破免暴
	_check("im.knight_zero_debuff", is_zero_approx(lg.item_cri(a, sk, kn)))
	lg.end_battle(0)
	# 免暴击标记：34 层鸿钧（底子 700% → 封顶 40%）
	var r := _guardian(34)
	var logic: XBattleLogic = r[0]
	var e: XEnemy = r[1]
	var u: XActor = logic.actors[0]
	var cri0 := logic.item_cri(u, sk, e)
	_check("im.plain_crits", cri0 > 0.0, [cri0, u.cri, e.cev])
	e.set_meta(XTianqiCombat.META_CRIT_IMMUNE, true)
	_check("im.mark_zero", is_zero_approx(logic.item_cri(u, sk, e)))
	XTianqiCombat.ENEMY_XPARAM_CAP = false
	XTianqiCombat.SUBTRACTIVE_CEV = false
	_check("im.mark_zero_switches_off", is_zero_approx(logic.item_cri(u, sk, e)))
	XTianqiCombat.ENEMY_XPARAM_CAP = true
	XTianqiCombat.SUBTRACTIVE_CEV = true
	e.remove_meta(XTianqiCombat.META_CRIT_IMMUNE)
	_check("im.mark_removed", _near(logic.item_cri(u, sk, e), cri0))
	# 反向：+1000% 暴击闪避状态（银鳞盾 626）是底子，封顶开着夹到 40%，不再免暴
	_add(e, 626)
	_check("im.trait_capped", _near(e.cev, 0.40), e.cev)
	_check("im.trait_not_immune", _near(logic.item_cri(u, sk, e), cri0), [logic.item_cri(u, sk, e), cri0])
	XTianqiCombat.ENEMY_XPARAM_CAP = false
	_check("im.trait_immune_cap_off", is_zero_approx(logic.item_cri(u, sk, e)), e.cev)
	XTianqiCombat.ENEMY_XPARAM_CAP = true


class _Src:
	var cri := 0.0


## T397 十三：D242 eva／cri／mev 上限按难度开着
func _d242() -> void:
	var caps := {"xunchang": [0.30, 0.50, 0.30], "jianxian": [0.35, 0.55, 0.35], "zhengdao": [0.50, 0.70, 0.50]}
	for diff in caps:
		var e: XEnemy = _guardian(30, true, diff)[1]
		if e == null:
			_check("d242.f30.%s.found" % diff, false)
			continue
		var raw := [float(e.xparam_parts(1)[0]), float(e.xparam_parts(2)[0]), float(e.xparam_parts(4)[0])]
		var got := [e.eva, e.cri, e.mev]
		var exp := []
		for j in 3:
			exp.append(minf(float(raw[j]), float(caps[diff][j])))
		print("T397 f30 %s raw=%s got=%s exp=%s" % [diff, raw, got, exp])
		_check("d242.f30.%s.raw_above" % diff, raw.all(func(x): return float(x) >= 0.5), raw)
		_check("d242.f30.%s.capped" % diff, _near(got[0], exp[0]) and _near(got[1], exp[1]) and _near(got[2], exp[2]), [got, exp])
		XTianqiCombat.ENEMY_XPARAM_CAP = false
		var off := [e.eva, e.cri, e.mev]
		XTianqiCombat.ENEMY_XPARAM_CAP = true
		_check("d242.f30.%s.switch_off_x2" % diff, _near(off[0], raw[0] * 2.0) and _near(off[1], raw[1] * 2.0) and _near(off[2], raw[2] * 2.0), off)
	# 10 层守层者暴击原值 15% 低于上限：照原值、不 ×2
	var e10: XEnemy = _guardian(10)[1]
	if e10 != null:
		var r10 := float(e10.xparam_parts(2)[0])
		_check("d242.f10.cri_raw", r10 < 0.5 and _near(e10.cri, r10), [e10.cri, r10])
	# 1 层守层者负闪避：留原值（不 ×2、不抬 0）
	var e1: XEnemy = _guardian(1)[1]
	if e1 != null:
		var r1 := float(e1.xparam_parts(1)[0])
		_check("d242.f1.eva_neg_raw", r1 < 0.0 and _near(e1.eva, r1), [e1.eva, r1])
	# 表写回 -1＝退回原路 ×2
	var e30: XEnemy = _guardian(30)[1]
	if e30 != null:
		var t := XTianqiCombat.xparam_cap_table()
		var keep = t.cri
		t.cri = -1
		var rc := float(e30.xparam_parts(2)[0])
		var c_off := e30.cri
		t.cri = keep
		_check("d242.table_minus1_x2", _near(c_off, rc * 2.0) and _near(e30.cri, 0.5), [c_off, rc, e30.cri])
	# 小怪敌群（20 层喜乐天吉吉战士 476、25 层古树守护者 501）：同样封顶
	for troop in [476, 501]:
		var s := _state(true, "jianxian")
		var lg := XBattleLogic.new()
		lg.setup(troop, s)
		var ok := not lg.enemies.is_empty()
		var seen := []
		for m in lg.enemies:
			var mm: XEnemy = m
			seen.append([mm.enemy_id, mm.eva, mm.cri, mm.mev])
			for j in [[1, 0.35], [2, 0.55], [4, 0.35]]:
				var rw := float(mm.xparam_parts(j[0])[0])
				ok = ok and _near(mm.xparam(j[0]), minf(rw, j[1]) if rw >= 0.0 else rw)
		print("T397 minion troop %d %s" % [troop, seen])
		_check("d242.minion%d" % troop, ok, seen)
	# 西游档：开着的表也不动
	var sk := _crit_skill()
	var ex: XEnemy = _guardian(30, false)[1]
	if ex != null:
		var on := [ex.xparam(1), ex.xparam(2), ex.xparam(4), XTianqiCombat.crit_after_cev(1.0, null, sk, ex)]
		XTianqiCombat.ENEMY_XPARAM_CAP = false
		var off := [ex.xparam(1), ex.xparam(2), ex.xparam(4), XTianqiCombat.crit_after_cev(1.0, null, sk, ex)]
		XTianqiCombat.ENEMY_XPARAM_CAP = true
		_check("d242.xiyou.same", on == off, [on, off])
