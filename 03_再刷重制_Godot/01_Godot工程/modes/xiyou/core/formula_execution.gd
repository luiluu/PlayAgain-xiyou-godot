class_name XFormulaExecution
extends XFormulaProgram
## The only privileged formula entry. Preview uses private battler copies and no real stream.
## Bounded debug diagnostics contain values only, never live battler references.
static var diagnostics: Array = []
const DIAGNOSTIC_LIMIT := 128

static func _unavailable(item: Dictionary, execute: bool, reason: String) -> Dictionary:
	return _report(item, execute, {"available": false, "value": 0.0, "diagnostic": reason, "effectJournal": [], "results": {}})

static func _report(item: Dictionary, execute: bool, out: Dictionary) -> Dictionary:
	if execute and not out.available:
		var row := {"kind": str(item.get("kind", "skill")), "id": int(item.get("id", 0)), "diagnostic": str(out.diagnostic)}
		diagnostics.append(row)
		if diagnostics.size() > DIAGNOSTIC_LIMIT:
			diagnostics.pop_front()
		push_warning("[xiyou] formula unavailable: " + JSON.stringify(row))
	return out

var _battlers := {}
var _skill_id := 0
var resources: XResourceContext
var _random: XRandomStream

## evalDamageFormula 的异化包装（逆骨）：公式求值期间压公式帧
static func run_item(item: Dictionary, a: XBattler, b: XBattler, variables, switches := {}, execute := false, random: XRandomStream = null, resource_context: XResourceContext = null) -> Dictionary:
	XAlienBattle.push_formula(item, a, b, true)
	var out := _run_item(item, a, b, variables, switches, execute, random, resource_context)
	XAlienBattle.pop_formula()
	return out


static func _run_item(item: Dictionary, a: XBattler, b: XBattler, variables, switches := {}, execute := false, random: XRandomStream = null, resource_context: XResourceContext = null) -> Dictionary:
	var program: Dictionary = item.get("damage", {}).get("formulaProgram", {})
	var status := str(program.get("status", "unsupported"))
	if status == "module" and program.get("module") == "cat":  # 整条公式是 CodexCat.formula(user,item,b)（转换器 MODULE_FORMULAS）
		return {"available": true, "value": XCat.formula(a, item), "diagnostic": "", "effectJournal": [], "results": {}, "executed": execute}
	if status == "module" and program.get("module") == "garou":  # CodexGarou.base(a,b,id)（173 饿狼，XGarou.formula）
		return {"available": true, "value": XGarou.formula(a, item), "diagnostic": "", "effectJournal": [], "results": {}, "executed": execute}
	if status == "module" and program.get("module") == "mira":  # CodexMira.damage(a,b,id)（168 米拉，XMira.formula）
		return {"available": true, "value": XMira.formula(a, b, item), "diagnostic": "", "effectJournal": [], "results": {}, "executed": execute}
	if status == "module" and program.get("module") == "sukuna":  # CodexSukuna.damage(a,b,id,this)（172 宿傩，XSukuna.formula）
		return {"available": true, "value": XSukuna.formula(a, b, item), "diagnostic": "", "effectJournal": [], "results": {}, "executed": execute}
	if status == "module" and program.get("module") == "jingliu":  # CodexJingliu.damage(a,b,id)（170 镜流，XYomiJingliu.j_formula）
		return {"available": true, "value": XYomiJingliu.j_formula(a, b, item), "diagnostic": "", "effectJournal": [], "results": {}, "executed": execute}
	if status == "module" and program.get("module") == "yomi":  # CodexYomi.damage(a,b,id)（169 黄泉，XYomiJingliu.formula）
		return {"available": true, "value": XYomiJingliu.formula(a, b, item), "diagnostic": "", "effectJournal": [], "results": {}, "executed": execute}
	if status == "module" and program.get("module") == "raven":  # 渡鸦 5 个伤害技能的整条公式（167，XRaven.formula）
		return {"available": true, "value": XRaven.formula(a, b, item), "diagnostic": "", "effectJournal": [], "results": {}, "executed": execute}
	if int(program.get("version", 0)) != 1 or not status in ["pure", "effectful"]:
		return _unavailable(item, execute, "unsupported_program")
	var mode: String = str(XDamage.elements_data().skills.get(str(int(item.id)), {}).get("mode", ""))
	if status == "effectful" and mode == "mixed":
		return _unavailable(item, execute, "effectful_mixed_pending")
	for battler in [a, b]:
		var reason := XResourceContext.supported(battler) if status == "effectful" else ""
		if not reason.is_empty():
			return _unavailable(item, execute, reason)
	var first: XBattler = a if execute else XFormulaContext.clone_battler(a)
	var second: XBattler = first if a == b else (b if execute else XFormulaContext.clone_battler(b))
	if first == null or second == null:
		return _unavailable(item, execute, "unregistered_snapshot_type")
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
	var context := {"v": variables, "s": switches}
	var out := vm._run(program, context, int(item.damage.type), {})
	out.effectJournal = vm.resources.journal
	out.results = {"a": vm.resources.result(first).duplicate(true), "b": vm.resources.result(second).duplicate(true)}
	out.after = {"a": vm.resources.snapshot(first), "b": vm.resources.snapshot(second)}
	out.executed = execute
	out.value = XImportedBalance.formula_value(float(out.value), a, item)  # Game_Action.evalDamageFormula 的导入效果平衡（÷10）
	return _report(item, execute, out)

func _row(receiver: String) -> Dictionary:
	var battler: XBattler = _battlers[receiver]
	return XFormulaContext.row(battler, _skill_id)

func _read(node: Dictionary):
	if node.name == "mastery" and _battlers[node.receiver].has_meta("formula_read_error"):
		_fail("formula_read_error")
		return UNDEFINED
	var b: XBattler = _battlers[node.receiver]
	var args: Array = node.args.map(func(arg): return _expr(arg))
	var index := _number(args[0]) if args.size() == 1 else NAN
	var valid := not is_nan(index) and not is_inf(index) and index == floorf(index)
	match str(node.name):
		"equipment_level":
			if not b is XActor:
				return _fail("equipment_query_requires_actor")
			return XEquipmentView.first_armor_level(b.equip_list(), int(index)) if valid else 0.0
		"element": return b.element_rate(int(index)) if valid else 1.0
		"mastery": return b.skillMasteryLevel(int(index)) if valid else 0
		"has_state": return b.is_state_affected(int(index)) if valid else false
		"states_count": return b.states().size()
		"max_tp": return b.max_tp()
		"actor_id": return b.actor_id if b is XActor else null
		"hp_rate": return _divide(b.hp, b.mhp)
		"mp_rate": return _divide(b.mp, b.mmp) if b.mmp != 0.0 else 0.0
		"param": return b.param(int(index)) if valid and index >= 0 and index < 8 else UNDEFINED
		"xparam": return b.xparam(int(index)) if valid and index >= 0 and index < 10 else UNDEFINED
		"sparam": return b.sparam(int(index)) if valid and index >= 0 and index < 10 else UNDEFINED
	return _fail("unknown_read")

func _property(receiver: String, name: String):
	return _battlers[receiver].get(name) if name in XFormulaContext.PROPERTIES.split(" ") else _fail("unknown_property")

func _gain(receiver: String, resource: String, amount: float):
	if not _error.is_empty():
		return UNDEFINED
	resources.gain(_battlers[receiver], resource, amount)
	if not resources.error.is_empty():
		return _fail(resources.error)
	return UNDEFINED

## ShieldSystem addShield：返回 undefined（公式通常写 x.addShield(...); 0）
func _add_shield(receiver: String, amount: float):
	if not _error.is_empty():
		return UNDEFINED
	resources.add_shield(_battlers[receiver], amount)
	return _fail(resources.error) if not resources.error.is_empty() else UNDEFINED

func _math(node: Dictionary):
	if node.name == "random" and _random != null:
		_draws += 1
		var value := _random.next_float("formula", str(_skill_id))
		return value if _random.error.is_empty() else _fail(_random.error)
	return super._math(node)
