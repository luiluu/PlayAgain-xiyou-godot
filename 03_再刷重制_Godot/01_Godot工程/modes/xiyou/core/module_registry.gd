class_name XModuleRegistry
extends RefCounted
## Immutable, compiled module table. Handlers receive value-only frozen snapshots,
## return typed frame operations, and never receive a battler, RNG or mutator.
## Resource/host hooks remain pending until their owner supplies a proven boundary.

const POINTS := {
	"battler.collect_traits": false, "battle.setup": false,
	"action.before_cost": false, "action.after_cost": false,
	"damage.before": true, "damage.after": false,
	"state.before_add": false, "state.after_add": false, "state.after_remove": false,
	"turn.start": false, "turn.end": false, "enemy.transformed": false,
	"reward.candidate": false, "reward.grant": false,
	"world.event": false, "progression.commit": false, "preview.evaluate": false,
}
const SCALARS := ["skillMultiplier", "flatSkill", "normalAdd", "criticalAdd", "finalAdd", "finalMultiplier",
	"growthMultiplier", "settlementMultiplier", "physicalDefenseRate", "magicalDefenseRate",
	"physicalDamageMultiplier", "magicalDamageMultiplier", "flatMitigationRate", "healingMultiplier",
	"physicalIncomingPierce", "magicalIncomingPierce", "resistancePierce", "incomingMultiplier"]
const MAPS := ["elementAdd", "elementMultiplier", "flatMitigationAdd"]
const OTHER := ["mode", "kind", "elements", "noElement", "categoryMax"]
const CONTEXTS := ["item", "subject", "target", "options", "facts", "operationId"]

var _entries: Array = []
var _hooks: Array = []
var _errors: Array = []
static var _standard: XModuleRegistry

static func standard() -> XModuleRegistry:
	if _standard == null:
		_standard = compile([orb_descriptor(), XActorDamageHooks.descriptor(), XCatDamageHooks.descriptor(), XRaceBattle.descriptor(), XAlienBattle.descriptor()])
	return _standard

static func orb_descriptor() -> Dictionary:
	# Native loaded registry index 19, build after enter. 2*n + 1 preserves
	# adjacent enter/build order when future modules acquire both handlers.
	return {"id": "orb-sets", "version": "1", "capabilities": ["damage.orb_sets"],
		"contexts": ["item", "subject", "facts"], "hooks": [{"point": "damage.before", "order": 39,
		"reads": ["facts.orbMultiplier"], "writes": ["finalMultiplier"], "handler": _orb_sets}]}

static func _orb_sets(context: Dictionary, _frame: Dictionary) -> Dictionary:
	return {"ops": [{"op": "mul", "field": "finalMultiplier", "value": context.facts.orbMultiplier}]}

## No register/unregister operation exists on a live table. Session enablement
## must select a compiled table explicitly; callers cannot mutate standard().
static func compile(entries: Array) -> XModuleRegistry:
	var registry := XModuleRegistry.new()
	registry._compile(entries)
	return registry

func valid() -> bool:
	return _errors.is_empty()

func diagnostics() -> Array:
	return _errors.duplicate(true)

func manifest() -> Array:
	var result := _entries.duplicate(true)
	for entry in result:
		for hook in entry.get("hooks", []):
			if hook is Dictionary:
				var handler = hook.get("handler")
				hook.handler = str(handler.get_method()) if handler is Callable else "<invalid>"
	return result

func _compile(entries: Array) -> void:
	var ids := {}
	var capabilities := {}
	for entry in entries:
		if not entry is Dictionary or not entry.get("id") is String or str(entry.id).is_empty() or not entry.get("version") is String or str(entry.version).is_empty():
			_errors.append("invalid_module_identity")
			continue
		var id: String = entry.id
		if ids.has(id):
			_errors.append("duplicate_module:" + id)
		ids[id] = entry
		for field in ["capabilities", "contexts", "hooks", "dependsOn"]:
			if (field != "dependsOn" and not entry.has(field)) or not entry.get(field, []) is Array:
				_errors.append("invalid_module_array:" + id + ":" + field)
		if not _errors.is_empty():
			continue
		for capability in entry.get("capabilities", []):
			if not capability is String or capabilities.has(capability):
				_errors.append("capability_conflict:" + str(capability))
			capabilities[capability] = id
		for context in entry.get("contexts", []):
			if not CONTEXTS.has(context):
				_errors.append("unknown_context:" + str(context))
		var local_hooks := {}
		for hook in entry.get("hooks", []):
			if not hook is Dictionary:
				_errors.append("invalid_hook:" + id)
				continue
			var point := str(hook.get("point", ""))
			if not POINTS.has(point):
				_errors.append("unknown_point:" + point)
			elif not POINTS[point]:
				_errors.append("pending_point:" + point)
			if not hook.get("order") is int or not hook.get("handler") is Callable or not hook.handler.is_valid():
				_errors.append("invalid_order_or_handler:" + id)
			if hook.get("handler") is Callable and hook.handler.is_valid() and hook.handler.get_argument_count() != 2:
				_errors.append("invalid_handler_arity:" + id)
			var key := point + ":" + str(hook.get("order"))
			if local_hooks.has(key):
				_errors.append("duplicate_hook:" + id + ":" + key)
			local_hooks[key] = true
			for access in ["reads", "writes"]:
				if not hook.get(access) is Array:
					_errors.append("missing_access_declaration:" + id)
					continue
				for field in hook[access]:
					var root := str(field).get_slice(".", 0)
					if not field is String or not (SCALARS + MAPS + OTHER + (CONTEXTS if access == "reads" else [])).has(root if access == "reads" else field):
						_errors.append("unknown_access:" + id + ":" + str(field))
					if access == "reads" and CONTEXTS.has(root) and not entry.get("contexts", []).has(root):
						_errors.append("undeclared_context:" + id + ":" + root)
			_hooks.append({"id": id, "version": entry.version, "contexts": entry.get("contexts", []).duplicate(), "hook": hook.duplicate(true)})
		_entries.append(entry.duplicate(true))
	# Validate dependencies separately; deterministic numeric order remains the
	# source of dispatch order, rather than silently topologically reordering it.
	var remaining := ids.duplicate()
	var resolved := []
	while not remaining.is_empty():
		var progressed := false
		for id in remaining.keys():
			var dependencies = remaining[id].get("dependsOn", [])
			if not dependencies is Array:
				_errors.append("invalid_dependencies:" + id)
				remaining.erase(id)
				progressed = true
				continue
			var ready := true
			for dependency in dependencies:
				if not ids.has(dependency):
					_errors.append("missing_dependency:" + id + ":" + str(dependency))
				elif not resolved.has(dependency):
					ready = false
			if ready:
				resolved.append(id)
				remaining.erase(id)
				progressed = true
		if not progressed:
			_errors.append("cyclic_dependencies")
			break
	if not valid():
		_hooks.clear()
		return
	_hooks.sort_custom(func(a, b):
		if a.hook.order != b.hook.order: return a.hook.order < b.hook.order
		return a.id < b.id)
	for row in _hooks:
		for dependency in ids[row.id].get("dependsOn", []):
			for other in _hooks:
				if other.id == dependency and other.hook.point == row.hook.point and _hooks.find(other) >= _hooks.find(row):
					_errors.append("dependency_order_conflict:" + row.id + ":" + dependency)

## Frozen arguments are recursively value-only; even nested dictionaries and
## arrays cannot alias a live item, options, formula outcome or module spec.
static func value_copy(value):
	if value is Dictionary:
		var result := {}
		for key in value:
			if not key is String and not key is StringName and not key is int:
				return null
			var copied = value_copy(value[key])
			if copied == null and value[key] != null: return null
			result[str(key) if key is StringName else key] = copied
		return result
	if value is Array:
		var result := []
		for item in value:
			var copied = value_copy(item)
			if copied == null and item != null: return null
			result.append(copied)
		return result
	if value is StringName: return str(value)
	if value == null or value is String or value is bool or value is int or value is float:
		return value
	return null

static func freeze(value) -> void:
	if value is Dictionary or value is Array:
		for item in (value.values() if value is Dictionary else value):
			freeze(item)
		value.make_read_only()

func dispatch(point: String, context: Dictionary, initial: Dictionary) -> Dictionary:
	var errors := diagnostics()
	var trace := []
	var frame = value_copy(initial)
	var snapshot = value_copy(context)
	if not POINTS.get(point, false): errors.append("unavailable_point:" + point)
	if frame == null or snapshot == null: errors.append("non_value_context")
	if frame is Dictionary:
		for key in SCALARS:
			if not (frame.get(key) is int or frame.get(key) is float) or not is_finite(float(frame.get(key, NAN))): errors.append("invalid_frame:" + key)
		for key in MAPS:
			if not frame.get(key) is Dictionary: errors.append("invalid_frame:" + key)
		for key in OTHER:
			if not frame.has(key): errors.append("invalid_frame:" + key)
	if not errors.is_empty():
		return {"available": false, "frame": initial.duplicate(true), "trace": trace, "diagnostics": errors}
	freeze(snapshot)
	for row in _hooks:
		var hook: Dictionary = row.hook
		if hook.point != point: continue
		for required in row.contexts:
			if not snapshot.has(required): errors.append("missing_context:" + row.id + ":" + required)
		for path in hook.reads:
			var root: String = str(path).get_slice(".", 0)
			if CONTEXTS.has(root) and not _has_path(snapshot, str(path)):
				errors.append("missing_read_context:" + row.id + ":" + str(path))
		if not errors.is_empty(): break
		var before: Dictionary = frame.duplicate(true)
		var readonly: Dictionary = frame.duplicate(true)
		freeze(readonly)
		var result = hook.handler.call(snapshot, readonly)
		var next: Dictionary = frame.duplicate(true)
		var diagnostic := ""
		if not result is Dictionary or not result.get("ops", []) is Array or value_copy(result) == null:
			diagnostic = "invalid_handler_result"
		elif result.get("available", true) != true or not str(result.get("diagnostic", "")).is_empty():
			diagnostic = str(result.get("diagnostic", "handler_unavailable"))
		else:
			for operation in result.get("ops", []):
				diagnostic = _apply(next, operation, hook.writes)
				if not diagnostic.is_empty(): break
		trace.append({"module": row.id, "version": row.version, "point": point, "order": hook.order,
			"operationId": str(snapshot.get("operationId", "")), "input": before,
			"ops": value_copy(result.get("ops", [])) if result is Dictionary else [], "diagnostic": diagnostic})
		if not diagnostic.is_empty():
			errors.append(row.id + ":" + diagnostic)
			break
		frame = next
	return {"available": errors.is_empty(), "frame": frame, "trace": trace, "diagnostics": errors}

static func _apply(frame: Dictionary, operation, writes: Array) -> String:
	if not operation is Dictionary: return "invalid_operation"
	var field := str(operation.get("field", ""))
	var op := str(operation.get("op", ""))
	if not writes.has(field): return "undeclared_write:" + field
	if not op in ["set", "add", "mul"]: return "unknown_operation:" + op
	var value = operation.get("value")
	if SCALARS.has(field) or MAPS.has(field):
		if not (value is float or value is int) or not is_finite(float(value)): return "non_finite_numeric_operation"
		var previous: float
		if MAPS.has(field):
			if not operation.get("element") is int or int(operation.element) < 0 or int(operation.element) > 15: return "invalid_element"
			var key := str(operation.element)
			previous = float(frame[field].get(key, 1.0 if field == "elementMultiplier" else 0.0))
			var next := float(value) if op == "set" else previous + float(value) if op == "add" else previous * float(value)
			if not is_finite(next): return "non_finite_result"
			frame[field][key] = next
		else:
			previous = float(frame[field])
			var next := float(value) if op == "set" else previous + float(value) if op == "add" else previous * float(value)
			if not is_finite(next): return "non_finite_result"
			frame[field] = next
	elif op != "set": return "non_numeric_operation"
	elif field == "mode" and value in ["physical", "magical", "mixed"]: frame[field] = value
	elif field == "kind" and value in ["normal", "true", "fixed", "percent", "settled"]: frame[field] = value
	elif field in ["noElement", "categoryMax"] and value is bool: frame[field] = value
	elif field == "elements" and value is Array and value.all(func(e): return e is int and e >= 0 and e <= 15): frame[field] = value.duplicate()
	else: return "invalid_field_value:" + field
	return ""

static func _has_path(snapshot: Dictionary, path: String) -> bool:
	var value = snapshot
	for key in path.split("."):
		if not value is Dictionary or not value.has(key): return false
		value = value[key]
	return true

## Snapshot construction belongs to the host, outside pure numeric handlers.
## Explicit caller snapshots support previews; each handler still sees frozen
## copies. Legacy orbMultiplier remains owned by XDamage's existing boundary.
func capture_facts(item: Dictionary, a: XBattler, b: XBattler, options: Dictionary, existing: Dictionary) -> Dictionary:
	var out := {}
	if not existing.has("cat") and _entries.any(func(entry): return entry.id == "cat-sword"):
		out.cat = XCatDamageHooks.capture(item, a, b, options)
	if not existing.has("actorModules") and _entries.any(func(entry): return entry.id == "actor-modules"):
		out.actorModules = XActorDamageHooks.capture(item, a, b)
	if not existing.has("race") and _entries.any(func(entry): return entry.id == "race-blessings"):
		out.race = XRaceBattle.capture(item, a, b, options)
	if not existing.has("alienation") and _entries.any(func(entry): return entry.id == "alienation"):
		out.alienation = XAlienBattle.capture(item, a, b)
	return out
