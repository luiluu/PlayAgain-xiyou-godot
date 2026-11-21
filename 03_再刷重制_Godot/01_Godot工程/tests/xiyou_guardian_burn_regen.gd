extends Node
## 【cc·T327】1 层守层者挂灼伤 V（State 21，HP 再生率 −5%）每回合末掉约 20% 最大生命的来源（复现专项，不改数）：
## 一、来源：Star_Warehouse 的难度怪物属性把仓库倍率（天启篇开局借原版难度 3：DCultyL3，DCL3＝×2）同时乘在 Game_Enemy.xparam
##     （XEnemy.xparam → hrg）和 Game_Enemy.sparam（XEnemy.sparam → rec）上；krz_state_re regenerateHp 是
##     floor(mhp × hrg × rec)，于是 −5% × 2 × 2 ＝ −20%。原版 Star_Warehouse.js「难度怪物属性改变」两处也都乘，属原版行为。
## 二、regenerateHp 的 maxSlipDamage 把持续伤害夹到 hp−1：只靠灼伤打不死，5 回合到 1 血，之后任何一下都死（T239「8 回合赢」的来路）。
## 三、西游档存档同置 DCultyL3 时一模一样（不是天启篇引入的）。
## 四、T332（D249 乙，Kyo 11-21「天启篇不吃难度倍率」）：天启篇敌人回合末 HP 再生合计为负时 hrg、rec 都不乘仓库倍率（XEnemy.regen_rates，
##     开关 XTianqiCombat.DOT_NO_WAREHOUSE），灼伤 V 每回合 −5%；面板读的 hrg／rec 照旧 ×2；开关关掉回到 −20%；西游档照原版 −20%。
##     正再生（合计 ≥0）照旧乘倍率。
## 五、T332 r1 返修（小A 核 P1-1／P2-1）：天启篇把再生特性拆成正 pos、负 neg，正的照旧 ×w²、负的 ×1、rec 取原值：
##     10／11 层自带正再生的守层者挂灼伤 V、11 层挂中毒（−10%）跨 0 都连续；逆祷挡掉的负再生（drop）在拆开后扣，残留正再生照旧 ×w²。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	XEnemy.force_roll = 100.0  # 守层者不按神话
	seed(20261121)
	_case("tq", true)
	XTianqiCombat.DOT_NO_WAREHOUSE = false  # 回退支：天启篇也照原版 ×4
	_case("tq_off", true)
	XTianqiCombat.DOT_NO_WAREHOUSE = true
	_case("xiyou", false)
	_mixed("tq.f10.burn", true, 10, 21)
	_mixed("tq.f11.burn", true, 11, 21)
	_mixed("tq.f11.poison", true, 11, 4)
	_mixed("xiyou.f11.poison", false, 11, 4)
	XEnemy.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(tianqi: bool) -> XState:
	var lineup := [1, 2, 8, 9, 10]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "xunchang", lineup)
		XTianqi.take_pending()
		for id in lineup:
			XTianqi._joining = true
			s.add_actor(int(id))
			XTianqi._joining = false
	else:
		s = XState.new_game(3, 1, [8, 9, 10])
	var legacy := XTianqi.legacy_of("xunchang") if tianqi else 3  # 天启篇寻常借的原版难度 3；西游档同置 DCultyL3（DCL3＝2，L4 是 2.5）
	for i in range(1, 9):
		s.flags["DCultyL%d" % i] = i == legacy
	s.map_id = 4
	XState.current = s
	return s


func _case(tag: String, tianqi: bool) -> void:
	var s := _state(tianqi)
	var logic := XBattleLogic.new()
	logic.setup(int(XGuardianRework.TROOPS.get(1, 469)), s)
	var e: XEnemy = null
	for x in logic.enemies:
		if not tianqi or XGuardianRework.params_floor(x) > 0:
			e = x
			break
	_check("%s.found" % tag, e != null)
	if e == null:
		return
	var w := e.warehouse_rate()
	_check("%s.warehouse2" % tag, w == 2.0, w)
	var hrg0 := e.hrg
	var rec0 := e.rec
	if hrg0 >= 0.0:  # 合计不为负（没灼伤时）：regen_rates 照旧乘倍率
		var rr0 := e.regen_rates()
		_check("%s.nonneg_scaled" % tag, is_equal_approx(rr0[0], hrg0) and is_equal_approx(rr0[1], rec0), rr0)
	e.state_ids.append(21)
	XActor.state_touch(21)
	e.param_mark_dirty()
	var hrg1 := e.hrg
	var rec1 := e.rec
	print("T327 %s mhp=%s hrg %s→%s rec %s→%s" % [tag, e.mhp, hrg0, hrg1, rec0, rec1])
	# 关掉存档的难度怪物属性（DCultyL 全假＝不乘）读一遍原值
	var saved := {}
	for i in range(1, 9):
		saved[i] = s.flags.get("DCultyL%d" % i, false)
		s.flags["DCultyL%d" % i] = false
	e.param_mark_dirty()
	var hrg_raw := e.hrg
	var rec_raw := e.rec
	for i in saved:
		s.flags["DCultyL%d" % i] = saved[i]
	e.param_mark_dirty()
	print("T327 %s raw hrg=%s rec=%s" % [tag, hrg_raw, rec_raw])
	# 灼伤 V 的 −0.05 在 xparam 里被乘 ×2；rec 本身也被 sparam ×2
	_check("%s.hrg_x2" % tag, is_equal_approx(hrg1, hrg_raw * w) and is_equal_approx(hrg1 - hrg0, -0.05 * w), [hrg_raw, hrg0, hrg1])
	_check("%s.rec_x2" % tag, is_equal_approx(rec1, rec_raw * w) and is_equal_approx(rec1, rec0), [rec_raw, rec1])
	var mhp := e.mhp
	e.hp = mhp
	logic._regenerate(e, [])
	var lost := mhp - e.hp
	var unscaled := tianqi and XTianqiCombat.DOT_NO_WAREHOUSE  # T332：天启篇负再生不吃仓库倍率
	var want := -floorf(mhp * hrg_raw * rec_raw) if unscaled else -floorf(mhp * hrg1 * rec1)
	_check("%s.tick_eq_formula" % tag, is_equal_approx(lost, want), [lost, want])
	var rr := e.regen_rates()
	_check("%s.regen_rates" % tag, is_equal_approx(rr[0], hrg_raw if unscaled else hrg1) and is_equal_approx(rr[1], rec_raw if unscaled else rec1), rr)
	if is_zero_approx(hrg0):  # 守层者自身没有再生时：天启篇一回合正好 5%（T332）；西游档与开关关掉 20%（＝原版 5% × 仓库倍率²）
		var k := 1.0 if unscaled else w * w
		_check("%s.tick_%dpct" % [tag, int(5 * k)], is_equal_approx(lost, -floorf(mhp * -0.05 * k)), [lost, mhp])
	# 夹到 hp−1：再 5 回合（天启篇 −5% 时再 25 回合）也只到 1 血，不会自己死
	for i in (25 if unscaled else 5):
		logic._regenerate(e, [])
	_check("%s.floor_at_1" % tag, e.hp == 1.0 and e.is_alive(), e.hp)


## r1：自带正再生的守层者挂负再生状态 sid：天启篇 floor(mhp × (pos×w² ＋ neg) × rec原值)，西游档照原版 floor(mhp × hrg × rec)
func _mixed(tag: String, tianqi: bool, floor_no: int, sid: int) -> void:
	var s := _state(tianqi)
	var logic := XBattleLogic.new()
	logic.setup(int(XGuardianRework.TROOPS.get(floor_no, 469)), s)
	var e: XEnemy = null
	for x in logic.enemies:
		if XGuardianRework.params_floor(x) == floor_no or (not tianqi and e == null):
			e = x
			break
	_check("%s.found" % tag, e != null)
	if e == null:
		return
	var w := e.warehouse_rate()
	var pos_raw := e.hrg / w  # 挂状态前：守层者自带的再生（原值）
	var rec_raw := e.rec / w
	if tianqi:
		_check("%s.pos_regen" % tag, pos_raw > 0.0, pos_raw)
	var before := e.regen_rates()
	_check("%s.no_neg_unchanged" % tag, before[0] == e.hrg and before[1] == e.rec and not before[2], before)
	var neg := float(XDB.rec("States", sid).traits.filter(func(t): return int(t.code) == 22 and int(t.dataId) == 7)[0].value)
	e.state_ids.append(sid)
	XActor.state_touch(sid)
	e.param_mark_dirty()
	var mhp := e.mhp
	e.hp = floorf(mhp / 2.0)
	var hp0 := e.hp
	logic._regenerate(e, [])
	var got := e.hp - hp0
	var want: float
	if tianqi:
		want = floorf(mhp * (pos_raw * w * w + neg) * rec_raw)
	else:
		want = floorf(mhp * e.hrg * e.rec)
	want = clampf(want, -(hp0 - 1.0), mhp - hp0)
	print("T332r1 %s mhp=%s w=%s pos=%s neg=%s got=%s want=%s" % [tag, mhp, w, pos_raw, neg, got, want])
	_check("%s.tick" % tag, is_equal_approx(got, want), [got, want])
	if tianqi:
		_check("%s.pos_kept_x4" % tag, got > floorf(mhp * (pos_raw + neg) * rec_raw), got)  # 正再生没被砍成 ×1
		# 逆祷：挡掉全部负再生后只剩正再生 ×w²（P2-1，单元层面给 drop）
		var rr := e.regen_rates(neg)
		_check("%s.prayer_drop" % tag, rr[2] and is_equal_approx(float(rr[0]), pos_raw * w * w) and is_equal_approx(float(rr[1]), rec_raw), rr)
