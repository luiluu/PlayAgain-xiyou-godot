extends Node
## All 31 Plan-12 blocks through the production and shadow execution entries.
## The fixture is measured by formula_rest_probe.cjs from frozen v0.28.
class ProbeActor extends XActor:
	var fixed := []
	var mastery := 7
	var element := 1.25
	var critical := 0.1
	func param(i: int) -> float:
		return float(fixed[i])
	func xparam(i: int) -> float:
		return critical if i == 2 else 0.0
	func sparam(_i: int) -> float:
		return 1.0
	func element_rate(_i: int) -> float:
		return element
	func skillMasteryLevel(_i: int) -> int:
		return mastery
	func max_tp() -> float:
		return 200.0

var checks := 0
var failures := []

func check(label: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		if failures.size() <= 8:
			print("FAIL ", label, " ", JSON.stringify(detail).left(1000))

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func subject(setup: Dictionary, first: bool) -> ProbeActor:
	var a := ProbeActor.new()
	a.actor_id = 1 if first else 8
	a.fixed = setup.paramsA if first else setup.paramsB
	a.mastery = int(setup.mastery)
	a.element = float(setup.elementRate)
	a.critical = float(setup.criticalRate)
	var resources: Array = setup.resourcesA if first else setup.resourcesB
	a.hp = resources[0]; a.mp = resources[1]; a.tp = resources[2]
	if first:
		for row in setup.equipment:
			a.equips.append({"kind": row.kind, "base": row.baseItemId, "level": row.level, "meta": row.meta.duplicate(true)})
	return a

func result_fields(r: Dictionary) -> Dictionary:
	var out := {}
	for k in ["hpAffected", "hpDamage", "mpDamage", "tpDamage", "success", "addedStates", "removedStates"]:
		out[k] = r[k]
	return out

func _ready() -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/formula_rest_oracle.json"))
	check("source_identity", reference.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("scope", reference.hostScope == "plan12-custom-formula-execution")
	check("inventory_31", reference.inventory.size() == 31)
	check("native_cases_135", reference.cases.size() == 135)
	var covered := {}
	for c in reference.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty() and c.observed.diagnostics.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var item := XDB.rec("Skills", int(c.setup.skill))
		covered[int(item.id)] = true
		check(c.id + ".source", item.damage.formulaProgram.source.sha256 == c.observed.formulaSHA256)
		var a := subject(c.setup, true)
		var b := subject(c.setup, false)
		var variables: Dictionary = c.setup.variables.duplicate(true)
		var resources := XResourceContext.new()
		var rng := XRandomStream.scripted([])
		var before := JSON.stringify([resources.snapshot(a), resources.snapshot(b), a.equips, b.equips, variables, rng.snapshot()])
		var preview := XFormulaExecution.run_item(item, a, b, variables, {}, false, rng, resources)
		check(c.id + ".preview_isolated", before == JSON.stringify([resources.snapshot(a), resources.snapshot(b), a.equips, b.equips, variables, rng.snapshot()]) and resources.journal.is_empty())
		var actual := XFormulaExecution.run_item(item, a, b, variables, {}, true, rng, resources)
		check(c.id + ".value", actual.available and actual.sourceValueKind == c.observed.valueKind and is_equal_approx(actual.value, c.observed.value), [actual, c.observed])
		check(c.id + ".resources", same(actual.after.a.resources, c.observed.resourcesA) and same(actual.after.b.resources, c.observed.resourcesB), actual.after)
		check(c.id + ".result_slots", same(result_fields(actual.results.a), c.observed.resultA) and same(result_fields(actual.results.b), c.observed.resultB), actual.results)
		check(c.id + ".preview_matches", preview.available and preview.value == actual.value and same(preview.after, actual.after) and same(preview.effectJournal, actual.effectJournal), preview)
		check(c.id + ".rng", rng.error.is_empty() and rng.draws == c.observed.randomDraws and actual.randomDraws == c.observed.randomDraws, rng.journal)
		var pure: bool = item.damage.formulaProgram.status == "pure"
		check(c.id + ".writes", actual.effectJournal.size() == (0 if pure else 3))
		if pure:
			var context := XFormulaContext.capture(a, b, variables, {}, int(item.id), item.damage.formulaProgram)
			var readonly := XFormulaProgram.evaluate(item.damage.formulaProgram, context, int(item.damage.type))
			check(c.id + ".readonly_matches", readonly.available and readonly.value == actual.value, readonly)
	check("covered_31", covered.size() == 31)
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks}))
	get_tree().quit(0 if failures.is_empty() else 1)
