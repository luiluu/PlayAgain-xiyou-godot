extends Node
## Shadow evaluator compared with real frozen YEP evalDamageFormula.
var checks := 0
var failures := []

func check(label: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		if failures.size() <= 10:
			print("FAIL ", label, " ", detail)

func _ready() -> void:
	var reference = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + "oracle/formula_programs.json"))
	if not reference is Dictionary:
		check("oracle_present", false)
		return finish()
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + "manifest.json"))
	check("same_runtime_source", reference.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	check("shadow_scope", reference.get("hostScope") == "pure-formula-shadow" and reference.cases.size() > 1000)
	var random_program := {}
	for c in reference.cases:
		check(str(c.id) + ".source_clean", c.errors.is_empty())
		if not c.errors.is_empty():
			continue
		var setup: Dictionary = c.setup
		var program: Dictionary
		var type: int
		if setup.has("program"):
			program = setup.program
			if str(c.id) == "language.and_use":
				random_program = program
			type = int(setup.type)
			check(str(c.id) + ".source_hash", str(setup.formula).sha256_text() == program.source.sha256)
		else:
			var item := XDB.rec(str(setup.table), int(setup.id))
			program = item.damage.formulaProgram
			type = int(item.damage.type)
			check(str(c.id) + ".source_hash", str(program.source.sha256) == str(c.observed.formulaSHA256))
		var context: Dictionary = reference.contexts[str(setup.context)]
		var before := JSON.stringify(context)
		var result := XFormulaProgram.evaluate(program, context, type)
		var expected := float(c.observed.normalizedValue)
		check(str(c.id), result.available and result.sourceValueKind == c.observed.valueKind and absf(float(result.value) - expected) <= maxf(0.000001, absf(expected) * 0.000001), [result, c.observed])
		check(str(c.id) + ".preview_does_not_write", before == JSON.stringify(context))
		if c.observed.has("randomDraws"):
			check(str(c.id) + ".short_circuit_draws", int(result.randomDraws) == int(c.observed.randomDraws), result)
	# Only detached values may enter this evaluator.
	var pure: Dictionary = XDB.rec("Skills", 1).damage.formulaProgram
	check("objects_rejected", not XFormulaProgram.evaluate(pure, {"a": XActor.new()}).available)
	check("old_version_rejected", not XFormulaProgram.evaluate({"version": 0}, {}).available)
	var tape := XFormulaProgram.evaluate(random_program, {}, 1, {"randomValues": [0.25]})
	check("explicit_random_tape", tape.available and tape.value == 0.25 and tape.randomDraws == 1, tape)
	check("empty_tape_fails", not XFormulaProgram.evaluate(random_program, {}, 1, {"randomValues": []}).available)
	check("upper_bound_tape_fails", not XFormulaProgram.evaluate(random_program, {}, 1, {"randomValues": [1.0]}).available)
	check("negative_tape_fails", not XFormulaProgram.evaluate(random_program, {}, 1, {"randomValues": [-0.1]}).available)
	check("object_tape_fails", not XFormulaProgram.evaluate(random_program, {}, 1, {"randomValues": [self]}).available)
	check("unknown_vm_opcode_fails", not XFormulaProgram.evaluate({"version": 1, "status": "pure", "steps": [{"op": "expr", "value": {"op": "host_eval"}}]}, {}).available)
	finish()

func finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failedSample": failures.slice(0, 5)}))
	get_tree().quit(0 if failures.is_empty() else 1)
