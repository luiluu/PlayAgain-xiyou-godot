extends Node
## 诅咒 7201～7215 与洪荒压制 10300 的战斗效果对原版参照 tests/fixtures/honghuang_curse_battle_oracle.json
## （mv_oracle/honghuang_curse_battle_probe.cjs）：1 号学一个诅咒、敌群 3，比开战后双方的状态与回合、八维、xparam、sparam、敌人再动，
## 普攻一次的伤害（随机固定 0.5）；残魂苟存打到 0 血不倒；死而复燃（状态 1270）在 0.1／0.5 随机下打死后的血蓝 TP。
## 尾巴：7207／7205 暴击（随机 0.1）、7213／7212 魔法火焰 9 号、7211 掉率、7203／7204 的回合数与之后三次回合结束。
const FIXTURE := "res://tests/fixtures/honghuang_curse_battle_oracle.json"
var checks := 0
var failures: Array = []


class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648
	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return floori(n * value) if n > 0 else 0
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return lo + floori((hi - lo + 1) * value)


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 30:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(600))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameApp.fast_headless_frames()
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("source", f.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("complete", f.cases.size() == 34, f.cases.size())
	for c in f.cases:
		check(c.id + ".oracle", c.errors.is_empty(), c.errors)
		if c.errors.is_empty():
			_case(c)
	var passed := checks - failures.size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": checks}))
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)


func _setup(curse: int, start_rnd := 0.5) -> Array:
	var s := XState.new_game_blank()
	XState.current = s
	s.add_actor(1)
	if curse > 0:
		s.actor(1).learn_skill(curse)
	var stream := FixedStream.new()
	stream.domain = "rule"
	stream.value = start_rnd
	var rand := XBattleRandom.create("0000000000000174")
	rand.rule = stream
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	# 同参照的 refresh：开战状态的 Confirm 列表要等第一回合刷新才生效（krz 缓存）
	for b in [s.actor(1)] + logic.enemies:
		b.param_mark_dirty()
		b.param_refresh()
	return [logic, s.actor(1), logic.enemies[0], stream]


func _nums(want: Array, got: Array, tag: String) -> void:
	var same := want.size() == got.size()
	for i in mini(want.size(), got.size()):
		same = same and absf(float(want[i]) - float(got[i])) < 1e-5
	check(tag, same, [want, got])


func _look(tag: String, want: Dictionary, b: XBattler) -> void:
	var states: Array = b.state_ids.filter(func(id): return int(id) > 1)
	states.sort()
	check(tag + ".states", states == want.states.map(func(v): return int(v)), [want.states, states])
	var turns: Array = want.turns.map(func(r): return [int(r[0]), int(r[1])])
	var got_turns: Array = states.map(func(id): return [int(id), int(b.state_turns.get(id, b.state_turns.get(str(id), -99)))])
	check(tag + ".turns", turns.filter(func(r): return states.has(r[0])) == got_turns, [turns, got_turns])
	var params := []
	for i in 8:
		params.append(b.param(i))
	_nums(want.params, params, tag + ".params")
	var x := []
	var sp := []
	for i in 10:
		x.append(b.xparam(i))
		sp.append(b.sparam(i))
	_nums(want.x, x, tag + ".x")
	_nums(want.s, sp, tag + ".s")
	_nums(want.plus, b.action_plus_set(), tag + ".plus")
	var resist: bool = b.traits_set(XBattler.TRAIT_STATE_RESIST).has(1)
	check(tag + ".resist", resist == bool(want.rates.death), [want.rates, resist])


func _attack(logic: XBattleLogic, a: XActor, e: XBattler, skill := 1) -> Dictionary:
	var r: Dictionary = logic.apply(a, XDB.rec("Skills", skill), e)
	return r


func _turns(c: Dictionary) -> void:
	var r := _setup(int(c.setup.curse), float(c.setup.startRnd))
	var logic: XBattleLogic = r[0]
	var b: XBattler = r[2] if str(c.setup.who) == "enemy" else r[1]
	(r[3] as FixedStream).value = 0.5
	var state := int(c.setup.state)
	for i in c.observed.rows.size():
		var want: Dictionary = c.observed.rows[i]
		if i > 0:
			logic.end_turn()
		var has: bool = b.state_ids.has(state)
		var turns = int(b.state_turns.get(state, -1)) if has else null
		var got := {"has": has, "turns": turns, "canMove": logic.can_move(b)}
		var same: bool = has == bool(want.has) and logic.can_move(b) == bool(want.canMove) and (not has or int(want.turns) == turns)
		check("%s.row%d" % [c.id, i], same, [want, got])


func _case(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var kind := str(c.id).get_slice(".", 0)
	if kind == "turns":
		_turns(c)
		return
	var r := _setup(int(c.setup.curse))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var e: XBattler = r[2]
	var stream: FixedStream = r[3]
	if kind == "curse":
		_look(c.id + ".actor", o.actor, a)
		_look(c.id + ".enemy", o.enemy, e)
		e.hp = e.mhp
		a.hp = a.mhp
		var h := _attack(logic, a, e)
		check(c.id + ".damage", float(h.hp) == float(o.attack.hp) and bool(h.critical) == bool(o.attack.critical), [o.attack, h.hp, h.critical])
		return
	if kind == "drop":
		var rate := XAlienBattle.drop_item_rate(XState.current, e)
		check(c.id + ".rate", absf(rate - float(o.rate)) < 1e-5, [o.rate, rate])
		return
	if kind == "crit" or kind == "elem":
		stream.value = 0.1 if kind == "crit" else 0.5
		e.hp = e.mhp
		var hit := _attack(logic, a, e, 1 if kind == "crit" else 9)
		check(c.id + ".damage", float(hit.hp) == float(o.attack.hp) and bool(hit.critical) == bool(o.attack.critical), [o.attack, hit.hp, hit.critical])
		return
	e.hp = 1.0
	if kind == "revive":
		stream.value = float(c.setup.rnd)
		e.mp = 0.0
		e.tp = 50.0
	var h := _attack(logic, a, e)
	check(c.id + ".result", float(h.hp) == float(o.hp), [o.hp, h.hp])
	check(c.id + ".hp", is_equal_approx(e.hp, float(o.hpAfter)), [o.hpAfter, e.hp])
	check(c.id + ".alive", e.is_alive() == bool(o.alive), [o.alive, e.is_alive()])
	check(c.id + ".died", bool(h.died) == bool(o.dead), [o.dead, h.died])
	var states: Array = e.state_ids.duplicate()
	states.sort()
	check(c.id + ".states", states == o.states.map(func(v): return int(v)), [o.states, states])
	if kind == "revive":
		check(c.id + ".mp", is_equal_approx(e.mp, float(o.mp)), [o.mp, e.mp])
		check(c.id + ".tp", is_equal_approx(e.tp, float(o.tp)), [o.tp, e.tp])
