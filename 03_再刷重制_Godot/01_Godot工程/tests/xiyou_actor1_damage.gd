extends Node
## 【cc·悟空·未经审查】1 号孙悟空普攻打敌群 3 第 1 只（白龙 yunshang4 记的「1 号基础伤害比原版高约 0.9%」）：
## 与 mv_oracle/actor1_damage_probe.cjs 的冻结 v0.28 参照（generated/oracle/actor1_damage.json）逐例比。
## 条件拆开：云裳 174 在不在队（在就排第一）、全员生命 +1e12、敌人物防 +5000、1 号 1／30 级；比出战名单、1 号与敌人的
## param／xparam／sparam、普攻伤害值与暴击（随机数固定 0.5，同参照 Math.random）。
const ORACLE := "oracle/actor1_damage.json"
var results := []


class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return lo + floori((hi - lo + 1) * value)


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + ORACLE))
	if not check("oracle", d is Dictionary and d.cases.size() >= 10 and d.cases.all(func(c): return c.errors.is_empty()), ORACLE):
		finish()
		return
	for c in d.cases:
		_case(c)
	XState.current = null
	finish()


static func _nums(v: Array) -> Array:
	return v.map(func(x): return snappedf(float(x), 0.000001))


static func _read(b: XBattler, n: int, f: Callable) -> Array:
	return range(n).map(func(i): return snappedf(float(f.call(b, i)), 0.000001))


func _case(c: Dictionary) -> void:
	var st: Dictionary = c.setup
	var o: Dictionary = c.observed
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	if int(st.level) > 1:
		s.actor(1).change_level_mv(int(st.level))
	s.party.clear()
	s.battle_slots.clear()
	for id in ([174, 1, 8, 9, 10] if bool(st.yun) else [1, 8, 9, 10]):
		s.add_actor(id)
	if bool(st.bigHp):
		for id in s.party:
			s.actor(id).add_param(0, 1e12)
			s.actor(id).refresh_passive()
	var rand := XBattleRandom.create("0000000000000001")
	rand.rule = FixedStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(int(st.troop), s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		if bool(st.defPlus):
			p[3] += 5000
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	logic.start_turn()
	var a: XActor = s.actor(1)
	var e: XEnemy = logic.enemies[0]
	var members := logic.actors.map(func(b): return b.actor_id)
	check(c.id + ".members", members == (o.members as Array).map(func(x): return int(x)), [members, o.members])
	for side in [["a", a], ["e", e]]:
		var b: XBattler = side[1]
		var want: Dictionary = o[side[0]]
		check("%s.%s.param" % [c.id, side[0]], _read(b, 8, func(x, i): return x.param(i)) == _nums(want.param), [_read(b, 8, func(x, i): return x.param(i)), want.param])
		check("%s.%s.xparam" % [c.id, side[0]], _read(b, 10, func(x, i): return x.xparam(i)) == _nums(want.xparam), [_read(b, 10, func(x, i): return x.xparam(i)), want.xparam])
		check("%s.%s.sparam" % [c.id, side[0]], _read(b, 10, func(x, i): return x.sparam(i)) == _nums(want.sparam), [_read(b, 10, func(x, i): return x.sparam(i)), want.sparam])
	a.mp = a.mmp
	a.tp = a.max_tp()
	var hits := []
	for l in logic.act(a, XDB.rec("Skills", 1), e):
		if l.get("type") == "hit" and l.get("user") == a and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)):
			hits.append([float(l.hp), bool(l.critical)])
	var want_hits: Array = (o.log as Array).map(func(l): return [float(l.value), bool(l.critical)])
	check(c.id + ".damage", hits == want_hits, [hits, want_hits])


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
