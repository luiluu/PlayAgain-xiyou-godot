extends Node
## T563 西游档马宝国「混元大成」调整专项（Kyo 11-27 D293，事项 86）。
## 西游档反伤 = 10 ×(受到伤害 D + 物攻 + 最大生命)× min(1 + 积分/100, 30)，每段触发；
## 断言积分 0／300／2900／35000 四档、三段各反一次、零伤照反、最大生命 +10000 不变；
## 天启篇同名被动（技能 5115、状态 908 的记录）零改动；关开关回原版 90 倍无上限。

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


func _expect(coef: float, d: float, atk: float, mhp: float, points: int, cap: bool) -> float:
	var mul := 1.0 + float(points) / 100.0
	if cap:
		mul = minf(mul, float(XXiyouNerf.HUNYUAN_POINTS_CAP))
	return coef * (ceilf(d) + atk + mhp) * mul


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
		str(st.note).contains(" * 10) * Math.min(1 + v[206] / 100, 30)") and not str(st.note).contains("* 90)"), st.note)
	check("t563.skill_card_player_text",
		str(sk.note).contains(XXiyouNerf.HUNYUAN_NEW_TEXT) and not str(sk.note).contains("*90")
		and not str(sk.note).contains("×30") and not str(sk.note).contains(", 30)") and str(sk.note).contains("最大生命+10000")
		and str(sk.get("meta", {}).get("passivePBST0", "")).strip_edges() == "10000"
		and sk.description == base_sk.description, [sk.note, sk.description])


func _check_formula_four_points() -> void:
	for p in POINTS:
		var r := _bout(p, 1000)
		var want := _expect(10.0, r.taken[0], r.atk, r.mhp, p, true)
		check("t563.formula_p%d" % p, r.state and r.taken[0] > 0.0 and _close(r.reflect[0], want),
			{"points": p, "taken": r.taken, "reflect": r.reflect, "want": want, "atk": r.atk, "mhp": r.mhp})
	# 封顶：2900（1+29＝30，正好到顶）与 35000 反伤相同、都是 0 分的 30 倍；300 档倍率 4
	var r29 := _bout(2900, 1000)
	var r35 := _bout(35000, 1000)
	var r3 := _bout(300, 1000)
	var r0 := _bout(0, 1000)
	check("t563.points_cap_30x", XXiyouNerf.HUNYUAN_POINTS_CAP == 30 and _close(r29.reflect[0], r35.reflect[0]) and _close(r29.reflect[0], r0.reflect[0] * 30.0),
		[r0.reflect, r29.reflect, r35.reflect])
	check("t563.points_300_is_4x", _close(r3.reflect[0], r0.reflect[0] * 4.0), [r0.reflect, r3.reflect])


func _check_per_segment_and_zero() -> void:
	var r := _bout(300, 1000, 3)
	var ok: bool = r.reflect.size() == 3
	for i in r.reflect.size():
		ok = ok and _close(r.reflect[i], _expect(10.0, r.taken[i], r.atk, r.mhp, 300, true))
	check("t563.three_segments_three_triggers", ok, r)
	var z := _bout(300, 0)
	check("t563.zero_damage_still_reflects", z.taken[0] == 0.0 and _close(z.reflect[0], _expect(10.0, 0.0, z.atk, z.mhp, 300, true)), z)


func _check_original_and_rollback() -> void:
	XXiyouNerf.original_data()
	var r := _bout(35000, 1000)
	var want := _expect(90.0, r.taken[0], r.atk, r.mhp, 35000, false)
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
	check("t563.tianqi_not_patched", not on_st.contains("Math.min(1 + v[206] / 100") and not on_sk.contains(XXiyouNerf.HUNYUAN_NEW_TEXT))
