extends Node
## Native Boss stateOrigin interactions with the three helpers added by main.
var passed := 0
var total := 0

class FixedEnemy extends XEnemy:
	func param(i: int) -> float:
		match i:
			0: return 5000.0
			1: return 300.0
			2: return 7.0
			4: return 3.0
		return super(i)

func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail).left(900))

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func compare(tag: String, b: XBattler, row: Dictionary) -> void:
	for key in ["hp", "shield"]:
		check(tag + "." + key, b.get(key) == float(row[key]), [b.get(key), row[key]])
	check(tag + ".dirty", b.effect_dirty == row.dirty, [b.effect_dirty, row.dirty])
	check(tag + ".states", same(b.state_ids, row.states), [b.state_ids, row.states])
	for key in row.result:
		check(tag + ".result." + key, same(b.runtime_result[key], row.result[key]), [b.runtime_result[key], row.result[key]])

func run_case(c: Dictionary, mode: String) -> void:
	check(c.id + ".native_clean", c.errors.is_empty(), c.errors)
	var spec: Dictionary = c.setup
	var s := XState.new_game_blank()
	s.difficulty = 3
	s.set_switch(2494, true)
	s.party.assign([106, 101, 100] if int(spec.count) else [1])
	s.battle_slots = s.party.duplicate()
	while s.battle_slots.size() < 5:
		s.battle_slots.append(0)
	var a := FixedEnemy.new().setup(6, 3, 100.0)
	var b := FixedEnemy.new().setup(6, 3, 100.0)
	for x in [a, b]:
		x.param_cache_begin()
		x.refresh_resources()
	a.sync_boss_armor(true)
	for x in [a, b]:
		x.hp = 300.0
		x.mp = 300.0
		x.tp = 20.0
		x.shield = 0.0
	b.shield = float(spec.shield)
	var program := {"version":1, "status":"pure", "locals":["value"], "steps":[{"op":"set", "pos":0, "name":"value", "value":{"op":"literal", "pos":0, "value":-7.9}}]}
	var gain := {"phase":"battle", "op":"gain_steps", "steps":[{"resource":"hp", "program":program}]}
	var states: Array = XDB.table("States")
	var previous = states[2997]
	var inner: Dictionary = XDB.rec("States", 2).duplicate(true)
	inner.id = 2997
	inner.effects = [{"phase":"apply", "op":"gain_steps", "steps":gain.steps}]
	states[2997] = inner
	var st := {"id":2998, "effects":[{"phase":"battle", "op":"add_state", "who":"user", "id":2997}] if spec.op == "add" else [gain]}
	if spec.op == "poison":
		b.state_ids.append(460)
		b.state_data._stackingPoison = 1.0
		st = XDB.rec("States", 460)
	b.state_origins[2998] = weakref(a)
	b.state_origins[460] = weakref(a)
	var resources := XResourceContext.new()
	var ctx := {}
	if mode == "explicit":
		ctx.resources = resources
	elif mode == "inherited":
		b.lifecycle_context = resources.state_context(b)
	XImportedBalance.set_acting(a)
	check(c.id + ".rate", a.boss_output_rate() == float(c.observed.rate))
	compare(c.id + ".before", b, c.observed.before)
	XStateEffects.run_one("regenerate" if spec.op == "poison" else "battle", b, st, ctx)
	if mode != "standalone":
		resources.publish()
	compare(c.id + "." + mode + ".after", b, c.observed.after)
	check(c.id + ".domain_restored", resources.boss_output.is_empty() and XStateEffects.current().is_empty())
	check(c.id + ".resource_clean", resources.error.is_empty(), resources.error)
	b.lifecycle_context = {}
	XImportedBalance.set_acting(null)
	states[2997] = previous

func _ready() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/state_merge_context_oracle.json"))
	if not ref is Dictionary:
		check("native_fixture", false)
	else:
		check("native_rows", ref.cases.size() == 12)
		check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
		for c in ref.cases:
			for mode in ["explicit", "inherited", "standalone"]:
				run_case(c, mode)
	print("TEST_RESULT=", JSON.stringify({"passed":passed, "total":total}))
	get_tree().quit(0 if passed == total else 1)
