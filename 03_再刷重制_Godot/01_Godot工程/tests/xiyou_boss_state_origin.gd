extends Node
## Native Battler stateOrigin host vs translated gain_resource; other script ops replay inside run_one observer.
var checks := 0
var failures: Array = []
var bs := {}
var resources: XResourceContext
var expected: Array
var row_at := 0
var caught := 0
var active_phase := ""
const PHASES := {"addState":"apply", "removeState":"remove", "leaveState":"leave", "turnStartState":"turn_start", "turnEndState":"turn_end", "regenerateState":"regenerate", "actionStartState":"action_start", "actionEndState":"action_end"}
func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 15:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(800))

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func compare(tag: String, b: XBattler, row: Dictionary) -> void:
	var got := {"hp": b.hp, "mp": b.mp, "tp": b.tp, "shield": b.shield, "dirty": b.effect_dirty, "states": b.state_ids.duplicate()}
	for key in got:
		if not row.has(key):
			continue
		check(tag + "." + key, same(got[key], row[key]), [got[key], row[key]])
	for key in row.result:
		check(tag + ".result." + key, same(resources.result(b)[key], row.result[key]), [resources.result(b)[key], row.result[key]])

func fresh(count: int) -> XState:
	var s := XState.new_game_blank()
	s.difficulty = 3
	s.set_switch(2494, true)
	var ids := [106, 101, 100, 102, 104].slice(0, count) if count else [1]
	s.party.assign(ids)
	s.battle_slots = ids.duplicate()
	while s.battle_slots.size() < 5:
		s.battle_slots.append(0)
	return s


func set_origin(origin: String) -> void:
	bs.b.state_origins.erase(2998)
	if bs.has(origin):
		bs.b.state_origins[2998] = weakref(bs[origin])

func dispatch(ops: Array, tag: String) -> void:
	var previous := XStateEffects.observer
	var direct_gain: bool = ops.size() == 1 and ops[0].op == "gain" and ops[0].who == "b"
	var effects := []
	if direct_gain:
		var op: Dictionary = ops[0]
		compare(tag + ".row%d.before" % row_at, bs.b, expected[row_at].before)
		check(tag + ".row%d.op" % row_at, same(op, expected[row_at].op))
		effects = [{"phase": active_phase, "op": "gain_resource", "resource": op.kind, "amount": op.value}]
		XStateEffects.observer = Callable()
	else:
		effects = [{"phase": active_phase, "op": "mul", "cond": "never", "k": 1.0, "round": "floor"}]
		XStateEffects.observer = func(_p, _id, _holder, _ctx):
			if not run_ops(ops, tag):
				caught += 1
	var old_frames := resources.boss_output.frames.duplicate()
	var value := XStateEffects.run_one(active_phase, bs.b, {"id":2998, "effects":effects}, {"resources":resources, "value":31.0})
	check(tag + ".returned_value", value == 31.0)
	check(tag + ".restored_frames", same_frames(old_frames, resources.boss_output.frames))
	XStateEffects.observer = previous
	if direct_gain:
		compare(tag + ".row%d.after" % row_at, bs.b, expected[row_at].after)
		row_at += 1

func same_frames(a: Array, b: Array) -> bool:
	return a.size() == b.size() and (a.is_empty() or (a[-1].source == b[-1].source and a[-1].target == b[-1].target))

func run_ops(ops: Array, tag: String) -> bool:
	for op in ops:
		if op.op == "throw":
			return false
		if op.op == "nested":
			var old: Dictionary = bs.b.state_origins.duplicate()
			set_origin(op.origin)
			dispatch(op.ops, tag)
			bs.b.state_origins = old
			continue
		var b: XBattler = bs[op.who]
		check(tag + ".row%d.op" % row_at, same(op, expected[row_at].op))
		compare(tag + ".row%d.before" % row_at, b, expected[row_at].before)
		if op.op == "gain":
			resources.gain(b, op.kind, float(op.value))
		else:
			resources.set_resource(b, op.kind, float(op.value))
		compare(tag + ".row%d.after" % row_at, b, expected[row_at].after)
		row_at += 1
	return true

func run_case(c: Dictionary) -> void:
	var spec: Dictionary = c.setup
	var s := fresh(int(spec.count))
	var a := XEnemy.new().setup(6, 3, 100.0)
	var b: XBattler = s.actor(1) if spec.get("actorTarget", false) else XEnemy.new().setup(6, 3, 100.0)
	bs = {"a":a, "b":b, "c":XEnemy.new().setup(6, 3, 100.0)}
	for x in bs.values():
		x.param_cache_begin()
		x.refresh_resources()
	a.sync_boss_armor(spec.armor)
	for x in bs.values():
		x.hp = minf(300.0, x.mhp)
		x.mp = minf(300.0, x.mmp)
		x.tp = 20.0
		x.shield = 0.0
	b.shield = float(spec.get("shield", 0))
	resources = XResourceContext.new()
	expected = c.observed.rows
	row_at = 0
	caught = 0
	active_phase = PHASES.get(spec.phase, spec.phase)
	set_origin(spec.origin)
	for k in bs:
		compare(c.id + ".before." + k, bs[k], c.observed.before[k])
	if spec.outer == "none":
		dispatch(spec.ops, c.id)
	else:
		resources.boss_output.with_action(a, bs[spec.outer], func(): dispatch(spec.ops, c.id))
	check(c.id + ".scope_empty", resources.boss_output.is_empty())
	compare(c.id + ".outside.before", b, expected[row_at].before)
	resources.gain(b, "hp", -1.0)
	compare(c.id + ".outside.after", b, expected[row_at].after)
	row_at += 1
	check(c.id + ".row_count", row_at == expected.size())
	check(c.id + ".caught", caught == c.observed.caught.size())
	check(c.id + ".no_diagnostic", resources.error.is_empty(), resources.error)
	for k in bs:
		compare(c.id + ".after." + k, bs[k], c.observed.after[k])

func boundary_checks() -> void:
	var _s := fresh(3)
	var a := XEnemy.new().setup(6, 3, 100.0)
	var b := XEnemy.new().setup(6, 3, 100.0)
	var low := XEnemy.new().setup(6, 3, 100.0)
	for x in [a,b,low]:
		x.param_cache_begin()
		x.refresh_resources()
		x.hp = 500.0
	a.sync_boss_armor(true)
	var r := XResourceContext.new()
	b.state_origins[2998] = weakref(a)
	var st := {"id":2998, "effects":[{"phase":"turn_end", "op":"gain_resource", "resource":"hp", "amount":-7.0}]}
	b.lifecycle_context = {"resources":r}
	XStateEffects.run_one("turn_end", b, st)
	check("lifecycle.inherited_context", b.hp == 489.0)
	check("lifecycle.restored", r.boss_output.is_empty() and XStateEffects.current().is_empty())
	r.boss_output.with_action(a,b,func():
		var old := b.hp
		XStateEffects.run_one("turn_end", b, st, {"execute":false, "resources":r})
		check("preview.no_mutation", b.hp == old)
		check("preview.domain_unchanged", r.boss_output.frames.size() == 1)
		b.state_origins[2998] = weakref(low)
		XStateEffects.observer = func(_p,_id,_holder,_ctx): r.gain(b,"hp",-7.0)
		XStateEffects.run_one("react", b, {"id":2998,"effects":[{"phase":"react","op":"mul","cond":"never","k":1.0,"round":"floor"}]}, {"attacker":a,"defender":b,"resources":r})
		check("action.ordinary_keeps_outer", b.hp == old - 11.0)
		XStateEffects.observer = Callable()
		XStateEffects.run_one("turn_end", b, {"id":2998,"effects":[{"phase":"turn_end","op":"js"}]})
		check("diagnostic.outer_restored", r.boss_output.frames.size() == 1 and r.boss_output.frames[-1].source == a)
		check("diagnostic.stack_restored", XStateEffects.current().is_empty())
	)
	check("boundary.all_restored", r.boss_output.is_empty())
	b.lifecycle_context.clear()

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/boss_state_origin_oracle.json"))
	check("source", fixture.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("fixture.complete", fixture.cases.size() == 121, fixture.cases.size())
	var ids := {}
	for c in fixture.cases:
		check(c.id + ".unique", not ids.has(c.id))
		ids[c.id] = true
		check(c.id + ".native", c.errors.is_empty(), c.errors)
		if c.errors.is_empty():
			run_case(c)
	boundary_checks()
	print("TEST_RESULT=" + JSON.stringify({"passed":checks-failures.size(),"total":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
