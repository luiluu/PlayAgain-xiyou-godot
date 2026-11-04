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
	for id in [SLEEP, TICK]:  # 参照 addNewState：甚尔免疫睡眠，这里只要它不能行动
		if not b.state_ids.has(id):
			b.state_ids.append(id)
		b.state_turns[id] = 3
	b.param_mark_dirty()
	b.param_refresh()


## 这一回合哪些读数变了；状态只看 10、303（重制开战状态和参照宿主不同）。参照的 before／after 同样过一遍
func _delta(x: Dictionary, y: Dictionary) -> Dictionary:
	var out := {}
	for k in x:
		var a = x[k] if k != "states" else x[k].filter(func(r): return int(r[0]) in [SLEEP, TICK])
		var b = y[k] if k != "states" else y[k].filter(func(r): return int(r[0]) in [SLEEP, TICK])
		if JSON.stringify(_norm(a)) != JSON.stringify(_norm(b)):
			out[k] = _norm(b)
	return out


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("oracle", ref is Dictionary and ref.cases.size() == 16 and ref.cases.all(func(c): return (c.errors as Array).is_empty()))
	for c in ref.cases:
		var o: Dictionary = c.observed
		if str(c.id) == "gate.lifelink":
			_gate_lifelink(o)
			continue
		if str(c.id) == "gate.party":
			_gate_party(o)
			continue
		var want := _delta(o.before, o.after)
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
		check(str(c.id) + ".delta", JSON.stringify(got) == JSON.stringify(want), [got, want])
		if not is_enemy:
			check(str(c.id) + ".foes", l.enemies.map(func(e): return float(e.hp)) == f0, [f0])
		l.end_battle(0)
	finish()


## 敌人跳过的回合不走 endAction：连命不同步（绕过 gain 直接写队友生命，这一回合不被拉回）
func _gate_lifelink(o: Dictionary) -> void:
	var l := _battle(1)
	var u: XActor = l.state.actor(1)
	var mate: XActor = l.state.actor(8)
	var item: Dictionary = XAlienation.create(l.state, "w", 1044, "boss", "lifelink").ok
	item.alien.config = {"actorId": 1, "partnerId": 8}
	u.equips[0] = item
	XAlienBattle.lock_party(l)
	mate.hp = 1.0
	check("gate.lifelink.has", XAlienBattle.has(u, "lifelink") and bool(o.has))
	check("gate.oracle_unchanged", o.before == o.after, o)
	var mate0 := mate.hp
	var u0 := u.hp
	l.act(l.enemies[0], null, null)
	check("gate.lifelink", mate.hp == mate0 and u.hp == u0, [mate0, mate.hp, u0, u.hp])
	l.end_battle(0)


## 门外各模块（审查 36）：屠苏持武中、谷雨、小猫在场，1 号心钢、8 号狂妄：敌人被控这一回合全队读数、行动计数都不变
func _gate_party(o: Dictionary) -> void:
	var s := XState.new_game_blank()
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [176, 175, 178, 1, 8]:
		s.add_actor(id)
		s.actor(id).change_level(60)
	for pair in [[1, XHeartsteel.ARMOR], [8, XHubris.ARMOR]]:
		s.gain_gear("armor", int(pair[1]), 1)
		var a: XActor = s.actor(int(pair[0]))
		a.equips[a.equip_slots().find(int(XDB.rec("Armors", int(pair[1])).get("etypeId", 0)))] = s.gear.pop_back()
		a.refresh_passive()
	for id in [176, 175, 178, 1, 8]:
		s.actor(id).recover_all()
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
		e.recover_all()
	l.start_turn()
	var ts := s.actor(176)
	ts.mp = ts.mmp
	l.act(ts, XDB.rec("Skills", XTusu.skill_id("huawu.sword")), s.actor(1))
	var e0: XBattler = l.enemies[0]
	_sleep(e0)
	var read := func(): return [176, 175, 178, 1, 8].map(func(id): return _read(s.actor(id)))
	var a0 = read.call()
	var f0: Array = l.enemies.map(func(e): return float(e.hp))
	var counts := func(): return [XHeartsteel.remaining(s.actor(1)), int(XHubris._moves.get(8, 0))]
	var c0 = counts.call()
	l.act(e0, null, null)
	check("gate.party.oracle", bool(o.bound) and bool(o.same) and bool(o.foes), o)
	check("gate.party.bound", XBinding.is_bound(ts))
	check("gate.party.same", JSON.stringify(read.call()) == JSON.stringify(a0), [read.call(), a0])
	check("gate.party.foes", l.enemies.map(func(e): return float(e.hp)) == f0)
	check("gate.party.counts", counts.call() == c0, [counts.call(), c0])
	l.end_battle(0)


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
