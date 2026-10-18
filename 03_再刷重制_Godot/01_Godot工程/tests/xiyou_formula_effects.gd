extends Node
## Native ordered gain/set/refresh/death fixtures; compare every intermediate snapshot.
class ProbeBattler extends XBattler:
	var params := [10000, 1000, 100, 100, 100, 100, 100, 100]
	var cap_state := false
	var death_resist := false
	func param(i: int) -> float:
		return float(params[i]) * (2.0 if i == 1 and cap_state and state_ids.has(29999) else 1.0)
	func trait_objects() -> Array:
		return [{"traits": [{"code": 14, "dataId": 1, "value": 1}]}] if death_resist else []

var checks := 0
var failures := []

func check(label: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		if failures.size() <= 8:
			print("FAIL ", label, " ", detail)

func same(a, b) -> bool:
	# JSON numbers and state-turn dictionary keys have different Godot types.
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func battler(before: Dictionary, setup: Dictionary, subject: bool) -> ProbeBattler:
	var out := ProbeBattler.new()
	out.params = [10000, 101, 100, 100, 100, 100, 100, 100] if subject else [10000, 1000, 100, 100, 100, 100, 100, 100]
	out.cap_state = not subject and setup.get("capState", false)
	out.death_resist = not subject and setup.get("deathResist", false)
	out.hp = before.resources[0]
	out.mp = before.resources[1]
	out.tp = before.resources[2]
	out.immortal = before.immortal
	out.state_ids.assign(before.states.map(func(x): return int(x)))
	for id in before.stateTurns:
		out.state_turns[int(id)] = before.stateTurns[id]
	out.buffs.assign(before.buffs.map(func(x): return int(x)))
	out.buff_turns.assign(before.buffTurns.map(func(x): return int(x)))
	if subject and setup.get("throwRead", false):
		out.set_meta("formula_read_error", true)
	return out

func _ready() -> void:
	var reference = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + "oracle/formula_effects.json"))
	var language = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/formula_effect_programs.json"))
	check("source_112", reference is Dictionary and reference.cases.size() == 112)
	for c in reference.cases:
		if c.setup.mode != "eval":
			continue # apply fixtures are also exercised below through XBattleLogic.
		var a := battler(c.observed.before.a, c.setup, c.setup.pair != "self")
		var b := a if c.setup.pair == "self" else battler(c.observed.before.b, c.setup, false)
		var context := XResourceContext.new()
		context.seed_result(a, c.observed.before.a.result)
		context.seed_result(b, c.observed.before.b.result)
		var item := XDB.rec("Skills", int(c.setup.get("skill", 857))).duplicate(true)
		if c.setup.has("formula"):
			item.damage.formula = language[c.id].formula
			item.damage.formulaProgram = language[c.id].program
		check(c.id + ".source", item.damage.formulaProgram.source.sha256 == c.observed.formulaSHA256)
		var before := [context.snapshot(a), context.snapshot(b)]
		var preview := XFormulaExecution.run_item(item, a, b, [], {}, false, null, context)
		check(c.id + ".preview_no_write", same(before, [context.snapshot(a), context.snapshot(b)]))
		var tape := []
		for i in range(int(c.observed.randomDraws)):
			tape.append({"kind": "uint32", "value": 2147483648})
		var rng := XRandomStream.scripted(tape)
		var actual := XFormulaExecution.run_item(item, a, b, [], {}, true, rng, context)
		check(c.id + ".value", actual.value == c.observed.value and actual.available == c.observed.diagnostics.is_empty(), actual)
		check(c.id + ".after", same(actual.after, c.observed.after), [actual.after, c.observed.after])
		check(c.id + ".journal", same(actual.effectJournal, c.observed.journal), [actual.effectJournal, c.observed.journal])
		check(c.id + ".draws", rng.error.is_empty() and rng.draws == c.observed.randomDraws, rng.journal)
		check(c.id + ".preview_same", same(preview.after, actual.after) and preview.value == actual.value and same(preview.effectJournal, actual.effectJournal), preview)
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks}))
	get_tree().quit(0 if failures.is_empty() else 1)
