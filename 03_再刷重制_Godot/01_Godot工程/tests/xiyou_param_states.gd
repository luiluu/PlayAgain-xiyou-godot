extends Node
## 冻结原版1612/1768逐次账本、资源刷新、生命周期、持久与预览隔离。
class TracedActor extends XActor:
	var trace: Array = []
	func add_param(i: int, n: float) -> void:
		super(i, n)
		trace.append({"i": i, "n": n, "hp": hp, "mp": mp})

class MissBattle extends XBattleLogic:
	func _float(_reason: String) -> float:
		return 0.999999

var checks := 0
var failures: Array = []
var observations := 0

func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 15:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1200))

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func fresh() -> XState:
	var s := XState.new_game_blank()
	s.party.assign([1])
	s.battle_slots = [1, 0, 0, 0, 0]
	var a := TracedActor.new()
	s.actors[1] = a
	a.setup(1)
	a._lv = 3
	a.equips.fill(null)
	a.skill_ids.clear()
	a.state_ids.clear()
	a.refresh_passive()
	a.recover_all()
	a.trace.clear()
	return s

func compare(tag: String, a: XActor, row: Dictionary) -> void:
	var got := {"level": a.level, "plus": range(8).map(func(i): return a.param_plus(i)),
		"param": range(8).map(func(i): return a.param(i)), "hp": a.hp, "mp": a.mp, "states": a.state_ids.duplicate()}
	for key in got:
		check(tag + "." + key, same(got[key], row[key]), [got[key], row[key]])
	var trace: Array = a.trace.duplicate(true) if a is TracedActor else []
	check(tag + ".trace", same(trace, row.trace), [trace, row.trace])
	if a is TracedActor:
		a.trace.clear()

func lifecycle(c: Dictionary, bound := false) -> void:
	var s := fresh()
	var a: XActor = s.actor(1)
	a.add_param(0, 100000)
	a.add_param(1, 100000)
	a.recover_all()
	a.trace.clear()
	var rows: Array = c.observed.rows
	var resources := XResourceContext.new()
	if bound:
		a.lifecycle_context = {"resources": resources}
	compare(c.id + ".before", a, rows[0])
	a.add_state(1612)
	compare(c.id + ".apply", a, rows[1])
	a.add_state(1612)
	compare(c.id + ".reapply", a, rows[2])
	a._lv = 5
	a.refresh_passive()
	a.refresh_resources()
	a.hp = a.mhp
	a.mp = a.mmp
	compare(c.id + ".level5", a, rows[3])
	if c.id == "1612.forced_expire":
		a.remove_state_auto(1612)
	else:
		a.remove_state(1612)
	compare(c.id + ".remove", a, rows[4])
	a.remove_state(1612)
	compare(c.id + ".absent", a, rows[5])
	a.runtime_result = XResourceContext.empty_result()
	resources.seed_result(a, XResourceContext.empty_result())
	a.add_state(1612)
	compare(c.id + ".apply5", a, rows[6])
	a.lifecycle_context = {}
	s = XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	a = s.actor(1)
	compare(c.id + ".save", a, rows[7])
	# Restore tracing on the same live instance after the normal save roundtrip.
	var traced := TracedActor.new()
	traced.setup(1)
	for field in ["actor_id", "_lv", "exp_total", "equips", "skill_ids", "state_ids", "state_turns", "hp", "mp", "tp"]:
		traced.set(field, a.get(field))
	s.actors[1] = traced
	a = traced
	if bound:
		a.lifecycle_context = {"resources": resources}
	a.refresh_passive()
	a.remove_state(1612)
	compare(c.id + ".after_save_remove", a, rows[8])
	a.recover_all()
	compare(c.id + ".recover", a, rows[9])
	check(c.id + ".domain", resources.error.is_empty() and (not bound or a.lifecycle_context.resources == resources))
	a.lifecycle_context = {}

func conclude(c: Dictionary) -> void:
	var s := fresh()
	var a: XActor = s.actor(1)
	a.add_state(1768)
	a.refresh_resources()
	var b: XBattler = a if c.id == "1768.self" else XEnemy.new()
	if b != a:
		b.setup(1, 3, 100.0)
	if c.id in ["1768.hp0", "1768.both", "1768.self", "1768.hidden_hp0"]:
		b.hp = 0
	if c.id in ["1768.dead_state", "1768.both", "1768.hidden_dead"]:
		b.state_ids.append(1)
	if c.id.begins_with("1768.hidden"):
		b.hidden = true
	var rows: Array = c.observed.rows
	compare(c.id + ".before", a, rows[0])
	var r := XResourceContext.new()
	var ctx := {"attacker": a, "defender": b, "item": XDB.rec("Skills", 1), "resources": r}
	XStateEffects.run("conclude", a, ctx)
	compare(c.id + ".conclude", a, rows[1])
	XStateEffects.run("conclude", a, ctx)
	compare(c.id + ".repeat", a, rows[2])
	s = XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	compare(c.id + ".save", s.actor(1), rows[3])
	check(c.id + ".context_restored", a.lifecycle_context.is_empty())
	check(c.id + ".resource_error", r.error.is_empty(), r.error)

func miss_case(c: Dictionary) -> void:
	var s := fresh()
	var a: XActor = s.actor(1)
	a.add_state(1768)
	a.refresh_resources()
	var b := XEnemy.new()
	b.setup(1, 3, 100.0)
	if c.id.ends_with("hp0"):
		b.immortal = true
		b.hp = 0
	compare(c.id + ".before", a, c.observed.rows[0])
	var battle := MissBattle.new()
	battle.state = s
	battle.actors = [a]
	battle.enemies = [b]
	var skill := XDB.rec("Skills", 1).duplicate(true)
	skill.successRate = 0
	var out := battle.apply(a, skill, b)
	compare(c.id + ".apply", a, c.observed.rows[1])
	check(c.id + ".missed", out.missed == c.observed.missed and out.evaded == c.observed.evaded, out)

func fingerprint(s: XState, a: XActor, r: XResourceContext) -> String:
	return JSON.stringify([s.to_dict(), a.hp, a.mp, a.state_ids, a.state_turns, a.param_cells, a.param_dirty,
		a.effect_dirty, a.effect_lists, a.effect_snapshot, a.effect_snapshot_valid, a.runtime_result,
		r.slots, r.journal, s.runtime_random_snapshot(), XStateEffects.diagnostics, observations])

func isolation() -> void:
	var s := fresh()
	var a := s.actor(1)
	a.add_state(1768)
	a.refresh_resources()
	var b := XEnemy.new()
	b.setup(1, 3, 100.0)
	b.hp = 0
	var r := XResourceContext.new()
	r.seed_result(a, XResourceContext.empty_result())
	a.lifecycle_context = {"resources": r}
	XStateEffects.clear_diagnostics()
	XStateEffects.observer = func(_phase, _id, _holder, _ctx): observations += 1
	for mode in ["execute_false", "marker", "resource", "lifecycle_marker", "lifecycle_resource", "shadow"]:
		var clone := XFormulaContext.clone_battler(a)
		check(mode + ".clone", clone != null)
		if clone == null:
			continue
		var ctx := {"attacker": a, "defender": b, "resources": r, "execute": true}
		if mode == "execute_false":
			ctx.execute = false
		elif mode == "marker":
			ctx.preview = true
		elif mode == "resource":
			r.preview = true
		elif mode == "lifecycle_marker":
			a.lifecycle_context.preview = true
		elif mode == "lifecycle_resource":
			var preview_resources := XResourceContext.new()
			preview_resources.preview = true
			a.lifecycle_context.resources = preview_resources
		elif mode == "shadow":
			ctx.attacker = clone
		var before := fingerprint(s, a, r)
		XStateEffects.run("conclude", clone if mode == "shadow" else a, ctx)
		check(mode + ".isolated", before == fingerprint(s, a, r))
		for phase in ["apply", "remove", "leave"]:
			XStateEffects.run_one(phase, clone if mode == "shadow" else a, XDB.rec("States", 1612), ctx)
			check(mode + "." + phase, before == fingerprint(s, a, r))
		check(mode + ".stack", XStateEffects.current().is_empty())
		r.preview = false
		a.lifecycle_context = {"resources": r}
		before = fingerprint(s, a, r)
		clone.add_param(0, 999)
		check(mode + ".direct_shadow", before == fingerprint(s, a, r))
	# Direct API with a preview lifecycle also cannot write the shared ledger.
	a.lifecycle_context.preview = true
	var before := fingerprint(s, a, r)
	a.add_param(0, 999)
	check("direct_preview", before == fingerprint(s, a, r))
	a.lifecycle_context = {}
	XStateEffects.observer = Callable()
	# Enemy host is explicitly unavailable; it must not borrow an actor ledger.
	before = JSON.stringify(s.mv_param_plus)
	XStateEffects.run_one("conclude", b, XDB.rec("States", 1768), {"attacker": b, "defender": b})
	check("enemy.ledger", before == JSON.stringify(s.mv_param_plus))
	check("enemy.diagnostic", XStateEffects.diagnostics.any(func(d): return d.op == "param_add_actor_required"))
	XStateEffects.clear_diagnostics()

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/param_states_oracle.json"))
	check("fixture", fixture is Dictionary and fixture.cases.size() == 11)
	check("source", fixture.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	for c in fixture.cases:
		check(c.id + ".oracle", c.errors.is_empty())
		if c.id.begins_with("1612"):
			lifecycle(c)
			lifecycle(c, true)
		elif c.id.contains("apply_miss"):
			miss_case(c)
		else:
			conclude(c)
	isolation()
	print("TEST_RESULT=" + JSON.stringify({"total": checks, "passed": checks - failures.size(), "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
