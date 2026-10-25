extends Node
## Synthetic native customEffectEval scripts replay resource ops inside the translated phase host.
## This tests source domains, not a general JS host or the full original 1341/2550 scripts.
var checks := 0
var failures: Array = []
var resources: XResourceContext
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



func run_case(c: Dictionary) -> void:
	var spec: Dictionary = c.setup
	var _s := fresh(int(spec.count))
	var a := XEnemy.new().setup(6,3,100.0)
	var b := XEnemy.new().setup(6,3,100.0)
	var other := XEnemy.new().setup(6,3,100.0)
	var bs := {"a":a,"b":b,"c":other}
	for x in bs.values():
		x.param_cache_begin()
		x.refresh_resources()
	a.sync_boss_armor(spec.armor)
	b.sync_boss_armor(spec.sideArmor)
	for x in bs.values():
		x.hp = minf(300.0,x.mhp)
		x.mp = minf(300.0,x.mmp)
		x.tp = 20.0
		x.shield = 0.0
	var victim: XBattler = a if int(spec.state) == 2550 else b
	victim.shield = float(spec.get("shield",0))
	if spec.origin != "none":
		b.state_origins[int(spec.state)] = weakref(bs[spec.origin])
	resources = XResourceContext.new()
	for key in bs:
		compare(c.id+".before."+key,bs[key],c.observed.before[key])
	var expected: Array = c.observed.rows
	XStateEffects.observer = func(_p,_id,_holder,_ctx):
		for i in spec.ops.size():
			var op: Dictionary = spec.ops[i]
			var x: XBattler = bs[op.who]
			check(c.id+".op",same(op,expected[i].op))
			compare(c.id+".op.before",x,expected[i].before)
			if op.op == "gain":
				resources.gain(x,op.kind,float(op.value))
			else:
				resources.set_resource(x,op.kind,float(op.value))
			compare(c.id+".op.after",x,expected[i].after)
	var phase := str(spec.phase).trim_suffix("State")
	var run := func():
		return XStateEffects.run_one(phase,b,{"id":int(spec.state),"effects":[{"phase":phase,"op":"mul","cond":"never","k":1.0,"round":"floor"}]},
			{"attacker":a,"defender":bs[spec.target],"item":{"damage":{"type":1}},"resources":resources,"value":17.0})
	var value = resources.boss_output.with_action(a,bs[spec.target],run) if spec.outer else run.call()
	XStateEffects.observer = Callable()
	check(c.id+".returned",value == c.observed.returned)
	check(c.id+".restored",resources.boss_output.is_empty() and XStateEffects.current().is_empty())
	compare(c.id+".outside.before",b,expected[-1].before)
	resources.gain(b,"hp",-1.0)
	compare(c.id+".outside.after",b,expected[-1].after)
	check(c.id+".no_error",resources.error.is_empty())
	for key in bs:
		compare(c.id+".after."+key,bs[key],c.observed.after[key])

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/boss_react_oracle.json"))
	check("source",fixture.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("fixture.complete",fixture.cases.size() == 72,fixture.cases.size())
	var ids := {}
	for c in fixture.cases:
		check(c.id+".unique",not ids.has(c.id))
		ids[c.id] = true
		check(c.id+".native",c.errors.is_empty())
		if c.errors.is_empty():
			run_case(c)
	print("TEST_RESULT="+JSON.stringify({"passed":checks-failures.size(),"total":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
