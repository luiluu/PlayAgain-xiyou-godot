extends Node
## 被控回合对照 tests/fixtures/stunned_turn_oracle.json（mv_oracle/stunned_turn_probe.cjs）：角色不能行动原版走 startAction（没有行动）→endAction，
## 专属模块的收尾都不做事，只减行动结束的状态回合；敌人连这个也不减。比这一回合前后的差：生命、魔法、TP、状态回合、增益、敌人生命（绝对值不比，只看变化）。
const FIXTURE := "res://tests/fixtures/stunned_turn_oracle.json"
const SLEEP := 10
const TICK := 303
var results := []


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648
	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return floori(n * 0.5) if n > 0 else 0
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return lo + floori((hi - lo + 1) * 0.5)


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(700))


func _ready() -> void:
	_run.call_deferred()


func _battle(id: int) -> XBattleLogic:
	var s := XState.new_game_blank()
	XState.current = s
	s.switches[2494] = true
	s.actor_max_level = 99
	for m in ([1, 8, 9, 10] if id == 1 else [id, 1, 8, 9]):
		s.add_actor(m)
	s.actor(id).change_level(60)
	for m in s.battle_members():
		m.refresh_passive()
		m.recover_all()
	var l := XBattleLogic.new()
	var rand := XBattleRandom.create("0000000000000042")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	l.setup(3, s, rand)
	for e in l.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e9
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
	l.start_turn()
	for b in l.actors + l.enemies:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	return l


func _read(b) -> Dictionary:
	var ids: Array = b.state_ids.duplicate()
	ids.sort()
	return {"hp": float(b.hp), "mp": float(b.mp), "tp": float(b.tp), "states": ids.map(func(i): return [int(i), int(b.state_turns.get(i, 0))]), "buffs": b.buffs.map(func(v): return int(v))}


func _sleep(b) -> void:
	for id in [SLEEP, TICK]:
		b.add_state(id)
		b.state_turns[id] = 3


## 只看这一回合哪些键变了、变成什么：原版的 before→after 和重制的 before→after
func _delta(x: Dictionary, y: Dictionary) -> Dictionary:
	var out := {}
	for k in x:
		if str(x[k]) != str(y[k]):
			out[k] = y[k]
	return out


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("oracle", ref is Dictionary and ref.cases.size() == 14 and ref.cases.all(func(c): return (c.errors as Array).is_empty()))
	for c in ref.cases:
		var o: Dictionary = c.observed
		var want := {}
		for k in o.before:
			if JSON.stringify(o.before[k]) != JSON.stringify(o.after[k]):
				want[k] = o.after[k]
		var is_enemy: bool = str(c.id) == "enemy.sleep"
		var l := _battle(1 if is_enemy else int(c.setup.id))
		var u = l.enemies[0] if is_enemy else l.state.actor(int(c.setup.id))
		if not is_enemy:
			l.act(u, u.attack_skill(), l.enemies[0])
		_sleep(u)
		check(str(c.id) + ".cannot_move", not l.can_move(u) and not bool(o.canMove))
		var a0 := _read(u)
		var f0: Array = l.enemies.map(func(e): return float(e.hp))
		l.act(u, null if is_enemy else u.attack_skill(), null)
		var got := _delta(a0, _read(u))
		check(str(c.id) + ".delta", JSON.stringify(_norm(got)) == JSON.stringify(_norm(want)), [got, want])
		if not is_enemy:
			check(str(c.id) + ".foes", l.enemies.map(func(e): return float(e.hp)) == f0, [f0])
		l.end_battle(0)
	finish()


func _norm(v):
	if v is Dictionary:
		var o := {}
		var keys: Array = v.keys()
		keys.sort()
		for k in keys:
			o[str(k)] = _norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float or v is int:
		return int(v)
	return v


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=", JSON.stringify({"name": "xiyou_stunned_turn", "passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
