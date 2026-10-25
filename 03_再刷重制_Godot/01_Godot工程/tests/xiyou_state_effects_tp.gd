extends Node
## 2g: native TP resource/guard matrix and lifecycle-bound preview isolation.
## Apply fixtures temporarily supply the future op; production Apply stays JS
## until map/menu own an explicit operation result. No oracle values are edited.
class NativeActor extends XActor:
	var hp_cap := 485.0
	func param(i: int) -> float:
		return hp_cap if i == 0 else super(i)

class NativeEnemy extends XEnemy:
	var hp_cap := 7500.0
	func param(i: int) -> float:
		return hp_cap if i == 0 else 6.0 if i == 1 else super(i)

class NativeStart extends XBattleLogic:
	func _mod(n: int, reason: String) -> int:
		return 12 if reason == "initial_tp" else super(n, reason)

var checks := 0
var failures := []
var remap := {}

func check(label: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		if failures.size() <= 12:
			print("FAIL ", label, " ", JSON.stringify(detail).left(1400))

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func stream() -> XRandomStream:
	var tape := []
	for i in range(30):
		tape.append({"kind": "uint32", "value": 2147483648})
	return XRandomStream.scripted(tape)

func holder(kind: String, large := false) -> XBattler:
	if kind == "actor":
		var a := NativeActor.new()
		a.setup(1)
		a.hp_cap = 99999999.0 if large else 485.0
		return a
	var e := NativeEnemy.new()
	e.setup(int(XDB.rec("Troops", 2).members[0].enemyId), 3, 100.0)
	e.hp_cap = 75000007500.0 if large else 7500.0
	return e

func mapped(id: int) -> int:
	return int(remap.get(id, id))

func load_before(b: XBattler, before: Dictionary) -> XResourceContext:
	b.state_ids.assign(before.states.map(func(id): return mapped(int(id))))
	b.state_turns.clear()
	for key in before.turns:
		b.state_turns[mapped(int(key))] = int(before.turns[key])
	b.param_mark_dirty()
	b.param_refresh()
	b.states()
	b.effect_states("turn_start")
	b.hp = before.hp
	b.mp = before.mp
	b.tp = before.tp
	var r := XResourceContext.new()
	r.random = stream()
	r.seed_result(b, before.result)
	r.labels[b] = "b"
	return r

func snapshot(b: XBattler, r: XResourceContext) -> Dictionary:
	var result := r.result(b).duplicate(true)
	for key in ["missed", "evaded", "critical"]:
		result.erase(key)
	return {"hp": b.hp, "mp": b.mp, "tp": b.tp, "cap": b.max_tp(), "states": b.state_ids.duplicate(),
		"turns": b.state_turns.duplicate(), "dirty": b.effect_dirty, "result": result}

func expected(want: Dictionary) -> Dictionary:
	var w := want.duplicate(true)
	w.states = w.states.map(func(id): return mapped(int(id)))
	var turns := {}
	for key in w.turns:
		turns[mapped(int(key))] = w.turns[key]
	w.turns = turns
	return w

func compare(label: String, b: XBattler, r: XResourceContext, want: Dictionary) -> void:
	var got := snapshot(b, r)
	check(label, same(got, expected(want)), {"got": got, "want": expected(want)})

func fixture_state(name: String, traits: Array) -> int:
	var table: Array = XDB.table("States")
	var id := table.size()
	table.append({"id": id, "name": name, "traits": traits, "note": "", "meta": {}, "priority": 50,
		"minTurns": 1, "maxTurns": 1, "autoRemovalTiming": 0, "effects": []})
	return id

func _ready() -> void:
	var ref: Dictionary = XDB.load_json("oracle/state_effects.json")
	var cases := {}
	for c in ref.cases:
		cases[c.id] = c.observed
	check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	var untranslated := 0
	for st in XDB.table("States"):
		if st is Dictionary:
			for effect in st.get("effects", []):
				untranslated += int(effect.op == "js")
	check("inventory.444_to_437", untranslated == 437, untranslated)
	for id in [607, 609, 857]:
		check("production.battle.%d" % id, XDB.rec("States", id).effects.any(func(e): return e.phase == "battle" and e.op == "gain_resource"))
	var saved := {}
	for id in [1334, 1336]:
		var st := XDB.rec("States", id)
		saved[id] = st.effects
		check("pending.apply.%d" % id, st.effects.any(func(e): return e.phase == "apply" and e.op == "js"))
		st.effects = [{"phase": "apply", "op": "gain_resource", "recipient": "user", "resource": "tp", "amount": 25 if id == 1334 else 75}]
	matrix(cases)
	for id in saved:
		XDB.rec("States", id).effects = saved[id]
	preview_and_ownership()
	battle_start(cases["tp.battle_initialization"])
	XStateEffects.observer = Callable()
	print("TEST_RESULT=" + JSON.stringify({"test": "xiyou_state_effects_tp", "total": checks, "passed": checks - failures.size(), "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)

func matrix(cases: Dictionary) -> void:
	for row in cases["tp.native_blocks"].rows:
		var b := holder(row.kind, true)
		var r := load_before(b, row.before)
		XStateEffects.run_one(row.phase, b, XDB.rec("States", int(row.state)), r.state_context(b))
		compare("native.%s.%s.%s.%s" % [row.kind, row.state, row.tp, row.dead], b, r, row.after)
		check("native.draws", r.random.draws == int(row.draws), [r.random.draws, row.draws])
		check("native.journal", r.journal.size() == 1 and r.error.is_empty() and r.journal[0].requestedDelta == (50 if row.state == 857 else 25 if row.state == 1334 else 75 if row.state == 1336 else 200))
	for row in cases["tp.native_blocks"].applyRows:
		var b := holder(row.kind, true)
		var r := load_before(b, row.before)
		b.add_state_with_context(int(row.state), r.random, r.state_context(b))
		b.add_state_with_context(int(row.state), r.random, r.state_context(b))
		compare("reapply.%s.%s" % [row.kind, row.state], b, r, row.after)
		check("reapply.draws", r.random.draws == int(row.draws))
	for row in cases["tp.guarded_apply"].rows:
		var b := holder(row.kind)
		var r := load_before(b, row.before)
		b.add_state_with_context(int(row.state), r.random, r.state_context(b))
		compare("guard.first.%s.%s.%s" % [row.kind, row.state, row.hpZero], b, r, row.first)
		b.add_state_with_context(int(row.state), r.random, r.state_context(b))
		compare("guard.second", b, r, row.second)
		r.refresh(b)
		compare("guard.refresh", b, r, row.refreshed)
		check("guard.draws", r.random.draws == int(row.draws), [r.random.draws, row.draws])
	for row in cases["tp.actor_custom_caps"].rows:
		var b := holder("actor") as XActor
		var skills: Array = XDB.table("Skills")
		var skill := XDB.rec("Skills", 1).duplicate(true)
		skill.id = skills.size()
		skill.note = "<passiveEXTTP:%d>" % row.extra
		skill.meta = {"passiveEXTTP": str(int(row.extra))}
		skills.append(skill)
		b.learn_skill(int(skill.id))
		b.refresh_passive()
		var r := load_before(b, row.before)
		check("custom.cap", b.max_tp() == row.before.cap, b.max_tp())
		if row.mode == "addState":
			b.add_state_with_context(int(row.state), r.random, r.state_context(b))
		else:
			XStateEffects.run_one("apply" if row.state >= 1334 else "battle", b, XDB.rec("States", int(row.state)), r.state_context(b))
		compare("custom.%s.%s.%s" % [row.extra, row.state, row.mode], b, r, row.after)
		check("custom.draws", r.random.draws == int(row.draws))
	var boundary: Dictionary = cases["tp.refresh_state_boundary"]
	var victim := fixture_state("TP fixture victim", [])
	var resister := fixture_state("TP fixture resister", [{"code": 14, "dataId": victim, "value": 1.0}])
	remap[int(boundary.victim)] = victim
	remap[int(boundary.resister)] = resister
	for row in boundary.rows:
		var b := holder(row.kind)
		var r := load_before(b, row.before)
		if row.mode == "direct":
			XStateEffects.run_one("apply", b, XDB.rec("States", 1334), r.state_context(b))
		else:
			b.add_state_with_context(1334, r.random, r.state_context(b))
		compare("resist.%s.%s" % [row.kind, row.mode], b, r, row.after)
		r.refresh(b)
		compare("resist.refresh", b, r, row.refreshed)
		check("resist.draws", r.random.draws == int(row.draws))

func fingerprint(b: XBattler, r: XResourceContext) -> Array:
	return [b.hp, b.mp, b.tp, b.state_ids.duplicate(), b.state_turns.duplicate(), b.param_cells.duplicate(), b.param_dirty,
		b.effect_snapshot.duplicate(true), b.effect_lists.duplicate(true), b.effect_dirty, b.runtime_result.duplicate(true),
		r.slots.duplicate(true), r.journal.duplicate(true), r.random.snapshot(), XStateEffects.diagnostics.duplicate(true)]

func preview_and_ownership() -> void:
	var a := holder("actor")
	var b := holder("enemy")
	var r := XResourceContext.new()
	r.random = stream()
	r.seed_result(a, XResourceContext.empty_result())
	r.seed_result(b, XResourceContext.empty_result())
	var outer := {"resources": r, "random": r.random, "party_members": [a], "variables": [0, 1], "switches": {2: true}}
	a.lifecycle_context = outer
	b.lifecycle_context = outer
	var old := [fingerprint(a, r), fingerprint(b, r)]
	var clone := XFormulaContext.clone_battler(a)
	check("preview.clone_without_capability", clone != null and clone.lifecycle_context.is_empty())
	var item := XDB.rec("Skills", 857)
	var out := XFormulaExecution.run_item(item, a, b, [], {}, false, r.random, r)
	check("preview.effectful_available", out.available, out)
	check("preview.effectful_no_live_write", same(old, [fingerprint(a, r), fingerprint(b, r)]) and a.lifecycle_context == outer and b.lifecycle_context == outer)
	var calls := []
	XStateEffects.observer = func(_p, _id, _b, _c): calls.append(true)
	var value := XStateEffects.run_one("confirm", a, XDB.rec("States", 1421), {"execute": false, "attacker": a, "defender": b, "value": 7.0, "item": {"damage": {"type": 1}}, "variables": []})
	check("preview.phase_available", is_finite(value), value)
	XStateEffects.run_one("battle", a, XDB.rec("States", 607), {"execute": false})
	check("preview.all_channels_unchanged", same(old, [fingerprint(a, r), fingerprint(b, r)]) and calls.is_empty())
	XStateEffects.observer = Callable()
	# Unknown object-bearing properties/metadata still fail the detached guard.
	a.set_meta("unregistered_object", r)
	check("preview.guard_preserved", XFormulaContext.clone_battler(a) == null)
	a.remove_meta("unregistered_object")
	var inner := XResourceContext.new()
	inner.random = stream()
	var sid := fixture_state("nested TP", [])
	XDB.rec("States", sid).effects = [{"phase": "apply", "op": "gain_resource", "resource": "tp", "amount": 25}]
	XStateEffects.observer = func(_p, id, target, ctx):
		if id == sid:
			check("nested.bound", target == a and ctx.resources == inner and ctx.user == a and ctx.target == a)
			b.add_state_with_context(sid, inner.random, inner.state_context(b))
	var prev_tp := b.tp
	a.add_state_with_context(sid, inner.random, inner.state_context(a))
	check("nested.restored", a.lifecycle_context == outer and b.lifecycle_context == outer and XStateEffects.current().is_empty())
	check("nested.global_add_lock", not b.state_ids.has(sid) and b.tp == prev_tp and not inner.slots.has(b))
	check("nested.domain_isolated", r.journal.is_empty() and inner.journal.size() == 1)
	XStateEffects.observer = Callable()
	a.lifecycle_context = {}
	b.lifecycle_context = {}

func battle_start(o: Dictionary) -> void:
	var s := XState.new_game(3, 1, [8])
	var logic := NativeStart.new()
	logic.state = s
	logic.actors = s.battle_members()
	logic.enemies = [holder("enemy")]
	var all: Array = logic.actors + logic.enemies
	for i in range(3):
		var r := load_before(all[i], o.before[i])
		all[i].runtime_result = r.result(all[i]).duplicate(true)
	logic._start_battle_effects()
	for i in range(3):
		var r := XResourceContext.new()
		r.seed_result(all[i], all[i].runtime_result)
		compare("battle.initial.%d" % i, all[i], r, o.after[i])
	check("battle.journal", logic.battle_start_effects.journal.size() == 3 and logic.battle_start_effects.error.is_empty())
	var retained := logic.battle_start_effects.duplicate(true)
	var skill := XDB.rec("Skills", 1).duplicate(true)
	skill.damage.type = 0
	skill.effects = []
	var result := logic.apply(all[0], skill, all[2])
	check("battle.action_has_fresh_slot", result.result.tpDamage == 0.0 and same(retained, logic.battle_start_effects))
	var another := NativeStart.new()
	another.elite_roll = 100
	another.setup(2, XState.new_game(3, 1, [8]))
	check("battle.independent", another.battle_start_effects != logic.battle_start_effects and another.lifecycle_effects.is_empty())
