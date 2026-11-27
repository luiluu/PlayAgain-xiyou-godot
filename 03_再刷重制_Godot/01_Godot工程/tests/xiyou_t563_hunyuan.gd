extends Node
## T563 西游档马宝国「混元大成」调整专项（Kyo 11-27 D293，事项 86）。
## 西游档丙：反伤 =(受到伤害 D × 300 + 物攻 × 300 + 最大生命 × 300)+ 积分 × 5000，线性不封顶，每段触发；
## 原版 (D×90 + 物攻×90 + 最大生命×90)×(1 + 积分/100)。
## 断言积分 0／300／2900／35000／434951（玩家存档实际值）／5000000 六档、三段各反一次、零伤照反、最大生命 +10000 不变；
## 天启篇同名被动（技能 5115、状态 908 的记录）零改动；关开关回原版。

var passed := 0
var total := 0

const MA := 60
const POINTS := [0, 300, 2900, 35000, 434951, 5000000]


func _ready() -> void:
	_run.call_deferred()


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _hit(base: int) -> Dictionary:
	var sk: Dictionary = XDB.table("Skills")[1].duplicate(true)
	sk.name = "T563木桩回击"
	sk.damage.type = 1
	sk.damage.elementId = 0
	sk.damage.variance = 0
	sk.damage.critical = false
	sk.damage.formula = str(base)
	sk.hitType = 0
	sk.successRate = 100
	sk.effects = []
	sk.damage.formulaProgram = {"version": 1, "status": "pure", "capabilities": [], "locals": [], "result": "completion",
		"source": {"table": "Skills", "id": 0, "custom": false, "sha256": "t563_hit_%d" % base},
		"steps": [{"op": "expr", "value": {"op": "literal", "value": float(base)}}]}
	return sk


func _make_xiyou(points: int) -> XState:
	var s := XState.new_game_blank()
	s.random_master = XRandomStream.hex64(20261127)
	s.set_switch(2494, true)
	XState.current = s
	s.set_variable(206, points)
	s.add_actor(MA)
	var a: XActor = s.actor(MA)
	a.change_level(55)
	for rank in 4:
		XAdvance.advance(s, a)
	a.refresh_passive()
	a.param_mark_dirty()
	a.param_refresh()
	a.recover_all()
	return s


## 木桩（敌群 71）对马宝国打 hits 段固定伤害，记每段受到伤害、木桩掉血（＝反伤）、物攻、最大生命、是否挂着 908
func _bout(points: int, base: int, hits := 1) -> Dictionary:
	var s := _make_xiyou(points)
	var a: XActor = s.actor(MA)
	var logic := XBattleLogic.new()
	logic.auto = true
	logic.setup(71, s, XBattleRandom.create(XRandomStream.hex64(20261127)))
	var e: XEnemy = logic.enemies[0]
	check("t563.dummy_hp_headroom", e.hp > 1.0e10 and e.hp < 1.0e13, e.hp)  # 够扛最大反伤、又不丢整数精度
	var out := {"taken": [], "reflect": [], "atk": a.atk, "mhp": a.mhp, "state": a.state_ids.has(908)}
	var sk := _hit(base)
	logic.start_turn()  # 实战里受击都在回合开始之后（T561 木桩同此）
	for i in hits:
		var ah := a.hp
		var eh := e.hp
		logic.apply(e, sk, a)
		out.taken.append(ah - a.hp)
		out.reflect.append(eh - e.hp)
		a.recover_all()
	logic.end_battle()
	return out


## 丙：(D×300 + 物攻×300 + 最大生命×300) + P×5000
func _expect_c(d: float, atk: float, mhp: float, points: int) -> float:
	return 300.0 * (ceilf(d) + atk + mhp) + 5000.0 * float(points)


## 原版：(D×90 + 物攻×90 + 最大生命×90)×(1+P/100)
func _expect_orig(d: float, atk: float, mhp: float, points: int) -> float:
	return 90.0 * (ceilf(d) + atk + mhp) * (1.0 + float(points) / 100.0)


func _close(x: float, y: float) -> bool:
	return absf(x - y) <= maxf(1.0, absf(y) * 1e-9)


func _run() -> void:
	var was := XXiyouNerf.ENABLED
	XXiyouNerf.ENABLED = true
	XXiyouNerf.clear_cache()

	_check_tables()
	_check_formula_four_points()
	_check_per_segment_and_zero()
	_check_original_and_rollback()
	_check_tianqi_untouched()

	XXiyouNerf.ENABLED = was
	XXiyouNerf.clear_cache()
	XState.current = null
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_t563_hunyuan", "passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _check_tables() -> void:
	var base_st: Dictionary = XDB.table("States")[908]
	var base_sk: Dictionary = XDB.table("Skills")[5115]
	_make_xiyou(0)
	var st := XDB.rec("States", 908)
	var sk := XDB.rec("Skills", 5115)
	check("t563.shared_table_untouched",
		str(base_st.note).contains(" * 90) * (1 + v[206]*0.01)") and str(base_sk.note).contains(XXiyouNerf.HUNYUAN_OLD_TEXT),
		[base_st.note])
	check("t563.state_note_new_formula",
		str(st.note).contains(XXiyouNerf.HUNYUAN_NEW_JS) and not str(st.note).contains(XXiyouNerf.HUNYUAN_OLD_JS)
		and not str(st.note).contains("Math.min"), st.note)
	check("t563.skill_card_c_text",
		str(sk.note).contains("效果:马老师受到任何伤害，反弹(受到伤害*300+物攻*300+自身最大生命*300+肝帝积分*5000)的伤害")
		and not str(sk.note).contains("*90") and not str(sk.note).contains("/100")
		and str(sk.note).contains("最大生命+10000")
		and str(sk.get("meta", {}).get("passivePBST0", "")).strip_edges() == "10000"
		and sk.description == base_sk.description, [sk.note, sk.description])
	# 卡面与原文只差这一段式子（其余字一字不差）
	check("t563.card_only_formula_changed",
		str(sk.note) == str(base_sk.note).replace(XXiyouNerf.HUNYUAN_OLD_TEXT, XXiyouNerf.HUNYUAN_NEW_TEXT)
		and str(sk.note) != str(base_sk.note), sk.note)


func _check_formula_four_points() -> void:
	var rs := {}
	for p in POINTS:
		var r := _bout(p, 1000)
		rs[p] = r
		var want := _expect_c(r.taken[0], r.atk, r.mhp, p)
		check("t563.formula_c_p%d" % p, r.state and r.taken[0] > 0.0 and _close(r.reflect[0], want),
			{"points": p, "taken": r.taken, "reflect": r.reflect, "want": want, "atk": r.atk, "mhp": r.mhp})
	# 积分线性相加、不封顶：每档比 0 分多出的恰好是 积分×5000（受伤、物攻、生命各档相同）
	var ok := true
	for p in POINTS:
		ok = ok and _close(rs[p].reflect[0] - rs[0].reflect[0], 5000.0 * float(p))
	check("t563.points_additive_linear", ok, POINTS.map(func(p): return rs[p].reflect))
	# 积分 0 时比原版强（300 对 90）；玩家实际 43.5 万分时低于原版（本夹具 B 小，约 0.28 倍）
	var r0: Dictionary = rs[0]
	var rp: Dictionary = rs[434951]
	check("t563.vs_original", r0.reflect[0] > _expect_orig(r0.taken[0], r0.atk, r0.mhp, 0) * 3.0
		and rp.reflect[0] < _expect_orig(rp.taken[0], rp.atk, rp.mhp, 434951) * 0.5,
		[r0.reflect, rp.reflect])


func _check_per_segment_and_zero() -> void:
	var r := _bout(300, 1000, 3)
	var ok: bool = r.reflect.size() == 3
	for i in r.reflect.size():
		ok = ok and _close(r.reflect[i], _expect_c(r.taken[i], r.atk, r.mhp, 300))
	check("t563.three_segments_three_triggers", ok, r)
	var z := _bout(300, 0)
	check("t563.zero_damage_still_reflects", z.taken[0] == 0.0 and _close(z.reflect[0], _expect_c(0.0, z.atk, z.mhp, 300)), z)


func _check_original_and_rollback() -> void:
	XXiyouNerf.original_data()
	var r := _bout(35000, 1000)
	var want := _expect_orig(r.taken[0], r.atk, r.mhp, 35000)
	check("t563.rollback_original_90x_uncapped", _close(r.reflect[0], want), [r, want])
	check("t563.rollback_rec_is_base", XDB.rec("States", 908).note == XDB.table("States")[908].note
		and XDB.rec("Skills", 5115).note == XDB.table("Skills")[5115].note)
	XXiyouNerf.ENABLED = true
	XXiyouNerf.clear_cache()


func _make_tianqi() -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var s := XTianqi.start_new_game(3, "lianyu", [w[0], w[1], w[2], w[3], w[4]])
	XTianqi.take_pending()
	s.map_id = 4
	XState.current = s
	return s


func _check_tianqi_untouched() -> void:
	_make_tianqi()
	XXiyouNerf.ENABLED = true
	XXiyouNerf.clear_cache()
	var on_st := JSON.stringify(XDB.rec("States", 908))
	var on_sk := JSON.stringify(XDB.rec("Skills", 5115))
	XXiyouNerf.ENABLED = false
	XXiyouNerf.clear_cache()
	var off_st := JSON.stringify(XDB.rec("States", 908))
	var off_sk := JSON.stringify(XDB.rec("Skills", 5115))
	XXiyouNerf.ENABLED = true
	XXiyouNerf.clear_cache()
	check("t563.tianqi_records_identical", on_st == off_st and on_sk == off_sk)
	check("t563.tianqi_not_patched", not on_st.contains(XXiyouNerf.HUNYUAN_NEW_JS) and not on_sk.contains(XXiyouNerf.HUNYUAN_NEW_TEXT))
