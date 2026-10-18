class_name XFormulaExecution
extends XFormulaProgram
## The only privileged formula entry. Preview uses private battler copies and no real stream.
var _battlers := {}
var _skill_id := 0
var resources: XResourceContext
var _random: XRandomStream

static func run_item(item: Dictionary, a: XBattler, b: XBattler, variables, switches := {}, execute := false, random: XRandomStream = null, resource_context: XResourceContext = null) -> Dictionary:
	var program: Dictionary = item.get("damage", {}).get("formulaProgram", {})
	var status := str(program.get("status", "unsupported"))
	if int(program.get("version", 0)) != 1 or not status in ["pure", "effectful"]:
		return {"available": false, "value": 0.0, "diagnostic": "unsupported_program", "effectJournal": [], "results": {}}
	var mode: String = str(XDamage.elements_data().skills.get(str(int(item.id)), {}).get("mode", ""))
	if status == "effectful" and mode == "mixed":
		return {"available": false, "value": 0.0, "diagnostic": "effectful_mixed_pending", "effectJournal": [], "results": {}}
	for battler in [a, b]:
		var reason := XResourceContext.supported(battler) if status == "effectful" else ""
		if not reason.is_empty():
			return {"available": false, "value": 0.0, "diagnostic": reason, "effectJournal": [], "results": {}}
	var first: XBattler = a if execute else XFormulaContext.clone_battler(a)
	var second: XBattler = first if a == b else (b if execute else XFormulaContext.clone_battler(b))
	if first == null or second == null:
		return {"available": false, "value": 0.0, "diagnostic": "unregistered_snapshot_type", "effectJournal": [], "results": {}}
	var vm := XFormulaExecution.new()
	vm._battlers = {"a": first, "b": second}
	vm._skill_id = int(item.id)
	vm._random = random if execute else null
	vm.resources = resource_context if execute and resource_context != null else XResourceContext.new()
	if not execute and resource_context != null:
		vm.resources.slots[first] = resource_context.result(a).duplicate(true)
		vm.resources.slots[second] = resource_context.result(b).duplicate(true)
	vm.resources.preview = not execute
	vm.resources.random = vm._random
	vm.resources.labels[first] = "a"
	if second != first:
		vm.resources.labels[second] = "b"
	var context := {"v": variables.duplicate(true), "s": switches.duplicate(true)}
	var out := vm._run(program, context, int(item.damage.type), {})
	out.effectJournal = vm.resources.journal
	out.results = {"a": vm.resources.result(first).duplicate(true), "b": vm.resources.result(second).duplicate(true)}
	out.after = {"a": vm.resources.snapshot(first), "b": vm.resources.snapshot(second)}
	out.executed = execute
	return out

func _row(receiver: String) -> Dictionary:
	var battler: XBattler = _battlers[receiver]
	return XFormulaContext.row(battler, _skill_id)

func _read(node: Dictionary):
	if node.name == "mastery" and _battlers[node.receiver].has_meta("formula_read_error"):
		_fail("formula_read_error")
		return UNDEFINED
	return super._read(node)

func _gain(receiver: String, resource: String, amount: float):
	if not _error.is_empty():
		return UNDEFINED
	resources.gain(_battlers[receiver], resource, amount)
	if not resources.error.is_empty():
		return _fail(resources.error)
	return UNDEFINED

func _math(node: Dictionary):
	if node.name == "random" and _random != null:
		_draws += 1
		var value := _random.next_float("formula", str(_skill_id))
		return value if _random.error.is_empty() else _fail(_random.error)
	return super._math(node)
