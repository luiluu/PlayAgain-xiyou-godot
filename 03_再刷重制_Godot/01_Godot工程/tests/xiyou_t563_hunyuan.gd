extends Node
## T563 西游档马宝国「混元大成」调整专项（Kyo 11-27 D293，事项 86）。
## 西游档 V6：反伤 =(受到伤害 D + 90 + 物攻 × 90 + 最大生命 × 90)×(1 + 积分/100)，不封顶，每段触发；
## 原版 (D×90 + 物攻×90 + 最大生命×90)×(1 + 积分/100)，V6 只把 D 后的 ×90 换成 +90。
## 断言积分 0／300／2900／35000 四档、三段各反一次、零伤照反、最大生命 +10000 不变；
## 天启篇同名被动（技能 5115、状态 908 的记录）零改动；关开关回原版。

var passed := 0
var total := 0

const MA := 60
const POINTS := [0, 300, 2900, 35000]


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


## V6：(D+90 + 物攻×90 + 最大生命×90)×(1+P/100)
func _expect_v6(d: float, atk: float, mhp: float, points: int) -> float:
	return (ceilf(d) + 90.0 + atk * 90.0 + mhp * 90.0) * (1.0 + float(points) / 100.0)


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
	# 卡面：与原文只差一处「受到伤害*90」→「受到伤害+90」
	check("t563.skill_card_v6_text",
		str(sk.note).contains("效果:马老师受到任何伤害，反弹(受到伤害+90+物攻*90+自身最大生命*90)*(1+肝帝积分/100)的伤害")
		and str(sk.note).contains("最大生命+10000")
		and str(sk.get("meta", {}).get("passivePBST0", "")).strip_edges() == "10000"
		and sk.description == base_sk.description, [sk.note, sk.description])
	var diffs := []
	var o := str(base_sk.note)
	var n := str(sk.note)
	if o.length() == n.length():
		for i in o.length():
			if o[i] != n[i]:
				diffs.append([i, o[i], n[i]])
	check("t563.card_diff_only_one_op", diffs.size() == 1 and diffs.all(func(d): return d[1] == "*" and d[2] == "+"), diffs)


func _check_formula_four_points() -> void:
	var rs := {}
	for p in POINTS:
		var r := _bout(p, 1000)
		rs[p] = r
		var want := _expect_v6(r.taken[0], r.atk, r.mhp, p)
		check("t563.formula_v6_p%d" % p, r.state and r.taken[0] > 0.0 and _close(r.reflect[0], want),
			{"points": p, "taken": r.taken, "reflect": r.reflect, "want": want, "atk": r.atk, "mhp": r.mhp})
	# 不封顶：倍率严格按 1+P/100（300→4、2900→30、35000→351 倍于 0 分）
	check("t563.points_uncapped", _close(rs[300].reflect[0], rs[0].reflect[0] * 4.0)
		and _close(rs[2900].reflect[0], rs[0].reflect[0] * 30.0) and _close(rs[35000].reflect[0], rs[0].reflect[0] * 351.0),
		[rs[0].reflect, rs[300].reflect, rs[2900].reflect, rs[35000].reflect])
	# 与原版之比：只有受到伤害不再 ×90；物攻、最大生命两项仍 ×90
	var r0: Dictionary = rs[0]
	check("t563.weaker_than_original", r0.reflect[0] < _expect_orig(r0.taken[0], r0.atk, r0.mhp, 0) and r0.reflect[0] > (r0.atk + r0.mhp) * 90.0,
		[r0.reflect, r0.atk, r0.mhp])


func _check_per_segment_and_zero() -> void:
	var r := _bout(300, 1000, 3)
	var ok: bool = r.reflect.size() == 3
	for i in r.reflect.size():
		ok = ok and _close(r.reflect[i], _expect_v6(r.taken[i], r.atk, r.mhp, 300))
	check("t563.three_segments_three_triggers", ok, r)
	var z := _bout(300, 0)
	check("t563.zero_damage_still_reflects", z.taken[0] == 0.0 and _close(z.reflect[0], _expect_v6(0.0, z.atk, z.mhp, 300)), z)


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
