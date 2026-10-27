extends Node
## Native death admission and retained result slots; original probe and failed harness attempts preserved.
var passed := 0
var total := 0
func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))
func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fresh() -> XEnemy:
	XState.new_game(3, 1, [])
	var e := XEnemy.new().setup(1, 3, 100.0)
	e.runtime_result = XResourceContext.empty_result()
	return e
func add(e: XEnemy) -> void:
	var rc := XResourceContext.new()
	rc.seed_result(e, e.runtime_result)
	rc.add_state(e, 1)
	rc.publish()
func compare(tag: String, e: XEnemy, row: Dictionary) -> void:
	check(tag + ".hp", e.hp == float(row.hp), [e.hp, row.hp])
	check(tag + ".states", same(e.state_ids, row.states), [e.state_ids, row.states])
	check(tag + ".added", same(e.runtime_result.addedStates, row.added), [e.runtime_result.addedStates, row.added])
	check(tag + ".removed", same(e.runtime_result.removedStates, row.removed), [e.runtime_result.removedStates, row.removed])
func _ready() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/death_admission_oracle.json"))
	check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	for c in ref.cases:
		check(c.id + ".native_clean", c.issues.is_empty())
		var e := fresh()
		if c.id.begins_with("zero_hp_add_death"):
			e.hp = 0.0
			e.state_ids.clear(); e.state_turns.clear()
			e.hidden = bool(c.setup.hidden)
			add(e)
			compare(c.id, e, c.observed.rows[-1])
		elif c.id == "revive_then_death_result":
			add(e); compare(c.id + ".death", e, c.observed.rows[0])
			e.hp = 1.0; e.refresh_resources(); compare(c.id + ".revive", e, c.observed.rows[1])
			add(e); compare(c.id + ".readd", e, c.observed.rows[2])
			e.hp = 1.0; e.refresh_resources(); e.hp = 0.0; e.refresh_resources()
			compare(c.id + ".death_again", e, c.observed.rows[3])
			e.runtime_result = XResourceContext.empty_result(); e.refresh_resources()
			compare(c.id + ".death_after_clear", e, c.observed.rows[4])
		else:
			e.hp = 0.0
			var logic := XBattleLogic.new()
			logic.state = XState.current
			logic._die(e) # Convenience entry represents native die + refresh.
			compare(c.id, e, c.observed.rows[-1])
	print("TEST_RESULT=" + JSON.stringify({"passed":passed, "total":total}))
	get_tree().quit(0 if passed == total else 1)
