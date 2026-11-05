extends Node
## 【cc·哪吒·未经审查】难度验收：难度 1～9 × 抽样敌人（神话／非神话）对冻结 v0.28 参照
## generated/oracle/difficulty_enemy.json（mv_oracle/difficulty_enemy_probe.cjs）：最终能力值（param／xparam／sparam）、等级、
## 数据库经验金钱（O-130 前原版难度倍率不生效，exp()／gold() 与难度无关）、dropItemRate、各件掉率。
## slice_probe 的敌群只到难度 6；这里补难度 7 灭世、8 洪荒、9 混沌。
const ORACLE := "oracle/difficulty_enemy.json"
var results := []


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 40:
		print("FAIL ", name, " ", JSON.stringify(detail).left(400))


func near(a, b) -> bool:
	return absf(float(a) - float(b)) <= 1e-5 * maxf(1.0, absf(float(b)))


func near_arr(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not near(a[i], b[i]):
			return false
	return true


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + ORACLE))
	if not (d is Dictionary and d.cases.size() >= 400 and d.cases.all(func(c): return c.errors.is_empty())):
		check("oracle", false, ORACLE)
		finish()
		return
	var states := {}
	for c in d.cases:
		var st: Dictionary = c.setup
		var diff := int(st.difficulty)
		if not states.has(diff):
			var s := XState.new_game(diff, 1, [8])
			XState.current = s
			s.actor_max_level = 99
			s.set_switch(2494, true)
			s.party.clear()
			s.battle_slots.clear()
			for id in [1, 8, 9, 10]:
				s.add_actor(id)
			states[diff] = s
		XState.current = states[diff]
		_case(c, states[diff])
	XState.current = null
	# 每例 9 项断言；总数对不上说明有例漏比（diff2：探针提速后防止悄悄少比）
	check("assert_count", results.size() == d.cases.size() * 9, [results.size(), d.cases.size() * 9])
	finish()


func _case(c: Dictionary, s: XState) -> void:
	var st: Dictionary = c.setup
	var o: Dictionary = c.observed
	var e := XEnemy.new().setup(int(st.enemy), int(st.difficulty), 0.0 if bool(st.elite) else 100.0)
	e.setup_level(1, 0.99)
	check(c.id + ".elite", e.elite == bool(o.isElite), [e.elite, o.isElite])
	check(c.id + ".level", e.level == int(o.level), [e.level, o.level])
	check(c.id + ".param", near_arr(range(8).map(func(i): return e.param(i)), o.param), [range(8).map(func(i): return e.param(i)), o.param])
	check(c.id + ".xparam", near_arr(range(10).map(func(i): return e.xparam(i)), o.xparam))
	check(c.id + ".sparam", near_arr(range(10).map(func(i): return e.sparam(i)), o.sparam))
	check(c.id + ".exp", e.exp_reward() == int(o.exp), [e.exp_reward(), o.exp])
	check(c.id + ".gold", e.gold_reward() == int(o.gold), [e.gold_reward(), o.gold])
	var rate := XAlienBattle.drop_item_rate(s, e)
	check(c.id + ".rate", is_equal_approx(snappedf(rate, 0.000001), float(o.dropItemRate)), [rate, o.dropItemRate])
	var logic := XBattleLogic.new()
	logic.state = s
	var got: Array = logic.drop_chances(e).map(func(x): return snappedf(minf(1.0, x.chance), 0.000001))
	got.sort()
	got.reverse()
	var want: Array = (o.chances as Array).map(func(x): return float(x))
	var same := got.size() == want.size()
	for i in mini(got.size(), want.size()):
		same = same and absf(got[i] - want[i]) <= 0.000002
	check(c.id + ".chances", same, [got, want])


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
