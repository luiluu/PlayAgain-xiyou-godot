extends Node
## Native event313 / menu effects: old result slots, reapply, remove and clamped TP.
var passed := 0
var total := 0

class FixedActor extends XActor:
	func param(i: int) -> float:
		return 1000.0 if i == 0 else 300.0 if i == 1 else super(i)

func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail).left(900))

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func compare(tag: String, a: XActor, row: Dictionary) -> void:
	for key in ["hp", "mp", "tp"]:
		check(tag + "." + key, a.get(key) == float(row[key]), [a.get(key), row[key]])
	check(tag + ".states", same(a.state_ids, row.states), [a.state_ids, row.states])
	var turns := {}
	for id in a.state_turns:
		turns[str(id)] = a.state_turns[id]
	check(tag + ".turns", same(turns, row.turns), [turns, row.turns])
	for key in row.result:
		check(tag + ".result." + key, same(a.runtime_result[key], row.result[key]), [a.runtime_result[key], row.result[key]])

func fresh(tp: float) -> FixedActor:
	var s := XState.new_game_blank()
	var a := FixedActor.new()
	a.setup(1)
	s.actors[1] = a
	s.party = [1]
	a.equips.clear()
	a.skill_ids.clear()
	a.state_ids.clear()
	a.state_turns.clear()
	a.param_mark_dirty()
	a.refresh_resources()
	a.hp = 500.0
	a.mp = 100.0
	a.tp = tp
	a.runtime_result = XResourceContext.empty_result()
	a.runtime_result.merge({"hpAffected":true, "hpDamage":17.0, "mpDamage":4.0, "tpDamage":9.0, "addedStates":[44], "removedStates":[18]}, true)
	return a

func apply_step(core: MVEventCore, logic: XBattleLogic, a: XActor, spec: Dictionary, remove: bool) -> void:
	if spec.entry == "event313":
		core.list = [{"code":313, "indent":0, "parameters":[0, 1, 1 if remove else 0, spec.sid]}, {"code":0, "indent":0, "parameters":[]}]
		core.index = 0
		check("event.done", core.advance().kind == "done")
	else:
		logic._effect(a, a, {"code":22 if remove else 21, "dataId":spec.sid, "value1":1.0, "value2":0.0}, {"skill":{"hitType":0}, "added":[], "removed":[]})

func run_case(c: Dictionary, inherited: bool) -> void:
	check(c.id + ".native_clean", c.errors.is_empty(), c.errors)
	var a := fresh(float(c.setup.tp))
	var core := MVEventCore.new()
	var logic := XBattleLogic.new()
	logic.state = XState.current
	var resources := XResourceContext.new()
	if inherited:
		resources.seed_result(a, a.runtime_result)
		a.lifecycle_context = resources.state_context(a)
	var previous := a.lifecycle_context
	for i in c.observed.rows.size():
		var row: Dictionary = c.observed.rows[i]
		if row.name == "clear":
			a.runtime_result = XResourceContext.empty_result()
			if inherited:
				resources.seed_result(a, a.runtime_result)
		elif i > 0:
			apply_step(core, logic, a, c.setup, row.name == "remove")
			if inherited:
				resources.publish()
			check(c.id + ".context_restored", a.lifecycle_context == previous)
			if c.setup.entry == "event313":
				check(c.id + ".operation_record", core.last_state_operation.has("after") and core.last_state_operation.error.is_empty())
		compare(c.id + "." + str(inherited) + "." + row.name, a, row)
	check(c.id + ".no_battle_stream", logic.random == null)
	a.lifecycle_context = {}

func preview_boundary() -> void:
	var a := fresh(10.0)
	var rc := XResourceContext.new()
	rc.preview = true
	a.lifecycle_context = rc.state_context(a)
	var before := a.runtime_result.duplicate(true)
	var core := MVEventCore.new()
	var logic := XBattleLogic.new()
	logic.state = XState.current
	for entry in ["event313", "menuEffect"]:
		apply_step(core, logic, a, {"entry":entry, "sid":1334}, false)
	check("preview.no_state", a.state_ids.is_empty())
	check("preview.no_tp", a.tp == 10.0)
	check("preview.no_results", same(a.runtime_result, before))
	check("preview.no_real_slots", rc.slots.is_empty() and rc.journal.is_empty())
	a.lifecycle_context = {}

func _ready() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/state_operation_oracle.json"))
	if not ref is Dictionary:
		check("native_fixture", false)
	else:
		check("native_rows", ref.cases.size() == 8)
		check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
		for c in ref.cases:
			for inherited in [false, true]:
				run_case(c, inherited)
	preview_boundary()
	print("TEST_RESULT=", JSON.stringify({"passed":passed, "total":total}))
	get_tree().quit(0 if passed == total else 1)
