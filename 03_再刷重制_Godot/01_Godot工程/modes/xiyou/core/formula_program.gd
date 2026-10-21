class_name XFormulaProgram
extends RefCounted
## Bounded formula VM. Context consists of detached values; no Object/Callable access.
## Readonly entry rejects effects; explicit action execution uses a trusted subclass.
const UNDEFINED := &"formula_undefined"
var _locals := {}
var _context := {}
var _options := {}
var _error := ""
var _completion = UNDEFINED
var _budget := 4096
var _draws := 0

static func evaluate(program: Dictionary, context: Dictionary, damage_type := 1, options := {}) -> Dictionary:
	var vm := XFormulaProgram.new()
	if int(program.get("version", 0)) != 1 or program.get("status") != "pure":
		return {"available": false, "value": 0.0, "diagnostic": "unsupported_program", "randomDraws": 0}
	if not _detached(context) or not _detached(options):
		return {"available": false, "value": 0.0, "diagnostic": "context_must_be_detached", "randomDraws": 0}
	return vm._run(program, context, damage_type, options)

func _run(program: Dictionary, context: Dictionary, damage_type: int, options: Dictionary) -> Dictionary:
	# The VM only reads these dictionaries; retaining the graph preserves aliases.
	_context = context
	_options = options
	for name in program.get("locals", []):
		_locals[str(name)] = 0.0 if str(name) == "value" else UNDEFINED
	for step in program.get("steps", []):
		_step(step)
		if not _error.is_empty():
			break
	var raw = _locals.get("value", 0.0) if program.get("result") == "value" else _completion
	var number := _number(raw)
	var signed_value := number if is_nan(number) else maxf(0.0, number) * (-1.0 if damage_type in [3, 4] else 1.0)
	var native_kind := "nan" if is_nan(signed_value) else ("positive-infinity" if signed_value > 0 else "negative-infinity") if is_inf(signed_value) else "finite"
	# Keep the existing Godot damage adapter's finite guard, while exposing the
	# native outcome kind so NaN/Infinity are measured instead of silently hidden.
	var value := 0.0 if is_nan(signed_value) or is_inf(signed_value) or not _error.is_empty() else signed_value
	return {"available": _error.is_empty(), "value": value, "sourceValueKind": native_kind, "diagnostic": _error, "randomDraws": _draws}

static func _detached(value, depth := 0) -> bool:
	if depth > 64 or value is Object or value is Callable or value is Signal:
		return false
	if value is Dictionary:
		for key in value:
			if not _detached(key, depth + 1) or not _detached(value[key], depth + 1):
				return false
	elif value is Array:
		for child in value:
			if not _detached(child, depth + 1):
				return false
	return true

func _fail(reason: String):
	if _error.is_empty():
		_error = reason
	return UNDEFINED

func _tick() -> bool:
	_budget -= 1
	if _budget < 0:
		_fail("operation_limit")
	return _budget >= 0 and _error.is_empty()

func _number(value) -> float:
	if value == null:
		return 0.0
	if value is bool:
		return 1.0 if value else 0.0
	return float(value) if value is float or value is int else NAN

func _truth(value) -> bool:
	if value == null or (value is StringName and value == UNDEFINED):
		return false
	if value is bool:
		return value
	if value is float or value is int:
		return not is_nan(float(value)) and float(value) != 0.0
	return true

func _nullish(value) -> bool:
	return value == null or (value is StringName and value == UNDEFINED)

func _step(n: Dictionary) -> void:
	if not _tick():
		return
	match str(n.get("op", "")):
		"empty": pass
		"set":
			if not _locals.has(str(n.name)):
				_fail("unknown_local")
			else:
				_locals[str(n.name)] = _expr(n.value)
		"expr": _completion = _expr(n.value)
		"block":
			for s in n.steps:
				_step(s)
		"if": _step(n.yes if _truth(_expr(n.condition)) else n.no)
		_: _fail("unknown_statement")

func _expr(n: Dictionary):
	if not _tick():
		return UNDEFINED
	match str(n.get("op", "")):
		"literal": return n.value
		"undefined": return UNDEFINED
		"local": return _locals.get(str(n.name), UNDEFINED)
		"property":
			return _property(str(n.receiver), str(n.name))
		"lookup":
			var index = _expr(n.index)
			var numeric := index is int or index is float
			var key := ""
			if index is bool:
				key = "true" if index else "false"
			elif index == null:
				key = "null"
			elif index is StringName and index == UNDEFINED:
				key = "undefined"
			elif numeric and not is_nan(float(index)) and not is_inf(float(index)) and absf(float(index)) < 4294967295.0:
				key = str(int(index)) if floorf(float(index)) == float(index) else str(index)
			else:
				return UNDEFINED
			var pool = _context.get(str(n.pool), {})
			var value = UNDEFINED
			if pool is Array:
				value = pool[int(index)] if numeric and floorf(float(index)) == float(index) and float(index) >= 0 and int(index) < pool.size() else UNDEFINED
			elif pool is Dictionary:
				value = pool.get(key, UNDEFINED)
			else:
				return _fail("invalid_lookup_pool")
			return _fail("non_scalar_variable_pending") if value is Array or value is Dictionary or value is String else value
		"length":
			var value = _expr(n.value)
			return value.size() if value is Array else _fail("length_requires_array")
		"read": return _read(n)
		"select": return _expr(n.yes if _truth(_expr(n.condition)) else n.no)
		"unary":
			var arg = _expr(n.arg)
			match str(n.operator):
				"!": return not _truth(arg)
				"+": return _number(arg)
				"-": return -_number(arg)
		"binary":
			var left = _expr(n.left)
			if n.operator == "&&":
				return _expr(n.right) if _truth(left) else left
			if n.operator == "||":
				return left if _truth(left) else _expr(n.right)
			return _binary(str(n.operator), left, _expr(n.right))
		"gain":
			var amount := _number(_expr(n.amount))
			return _gain(str(n.receiver), str(n.resource), amount) if _error.is_empty() else UNDEFINED
		"shield":
			var amount := _number(_expr(n.amount))
			return _add_shield(str(n.receiver), amount) if _error.is_empty() else UNDEFINED
		"math": return _math(n)
	return _fail("unknown_expression")

func _row(receiver: String) -> Dictionary:
	return _context.get(receiver, {})

func _property(receiver: String, name: String):
	# ShieldSystem 的 shield 读数经 validNumber，没设过时是 0（较早的参照上下文没录这一项）
	return _row(receiver).get("properties", {}).get(name, 0.0 if name == "shield" else UNDEFINED)

func _gain(_receiver: String, _resource: String, _amount: float):
	return _fail("write_capability_required")

func _add_shield(_receiver: String, _amount: float):
	return _fail("write_capability_required")

func _read(n: Dictionary):
	var row: Dictionary = _row(str(n.receiver))
	var args: Array = n.args.map(func(a): return _expr(a))
	var index := float(args[0]) if args.size() == 1 and (args[0] is int or args[0] is float) else NAN
	var key := str(int(index)) if not is_nan(index) and not is_inf(index) and floorf(index) == index else ""
	var p: Dictionary = row.get("properties", {})
	match str(n.name):
		"equipment_level":
			if row.get("actorId") == null:
				return _fail("equipment_query_requires_actor")
			return XEquipmentView.first_armor_level(row.get("equipment", []), int(index)) if not is_nan(index) and not is_inf(index) else 0.0
		"element": return row.get("elements", {}).get(key, 1.0)
		"mastery": return row.get("mastery", {}).get(key, 0.0)
		"has_state": return row.get("stateIds", []).has(int(key)) if not key.is_empty() else false
		"states_count": return row.get("states", []).size()
		"max_tp": return row.get("maxTp", UNDEFINED)
		"actor_id":
			# Game_Enemy 没有 actorId 方法：公式里 a.actorId() 在敌方行为上抛 TypeError，原版按公式出错记 0
			if row.get("actorId") == null:
				return _fail("actor_id_requires_actor")
			return row.get("actorId")
		"hp_rate": return _divide(_number(p.get("hp")), _number(p.get("mhp")))
		"mp_rate": return _divide(_number(p.get("mp")), _number(p.get("mmp"))) if _number(p.get("mmp")) != 0.0 else 0.0
		"param", "xparam", "sparam":
			var values: Array = row.get(str(n.name), [])
			var i := int(key) if not key.is_empty() else -1
			return values[i] if i >= 0 and i < values.size() else UNDEFINED
	return _fail("unknown_read")

func _strict_equal(a, b) -> bool:
	if a is Array or a is Dictionary or b is Array or b is Dictionary:
		return is_same(a, b)
	if (a is float or a is int) and (b is float or b is int):
		return not is_nan(float(a)) and not is_nan(float(b)) and float(a) == float(b)
	return typeof(a) == typeof(b) and a == b

func _divide(a: float, b: float) -> float:
	if b == 0.0:
		var negative_zero := _negative_zero(b)
		return NAN if a == 0.0 or is_nan(a) else INF * signf(a) * (-1.0 if negative_zero else 1.0)
	return a / b

func _negative_zero(value: float) -> bool:
	return value == 0.0 and PackedFloat64Array([value]).to_byte_array().decode_s64(0) < 0

func _zero(negative: bool) -> float:
	# The GDScript compiler folds the literal -0.0 into +0.0.
	return PackedByteArray([0, 0, 0, 0, 0, 0, 0, 128]).decode_double(0) if negative else 0.0

func _minmax(args: Array, maximum: bool) -> float:
	var result := -INF if maximum else INF
	for value in args:
		var number := float(value)
		if is_nan(number):
			return NAN
		if (number > result if maximum else number < result):
			result = number
		elif number == 0.0 and result == 0.0:
			var negative := _negative_zero(number) and _negative_zero(result) if maximum else _negative_zero(number) or _negative_zero(result)
			result = _zero(negative)
	return result

func _power(base: float, exponent: float) -> float:
	if exponent == 0.0:
		return 1.0
	if is_nan(base) or is_nan(exponent):
		return NAN
	if absf(base) == 1.0 and is_inf(exponent):
		return NAN
	return pow(base, exponent)

func _binary(op: String, left, right):
	var a := _number(left)
	var b := _number(right)
	match op:
		"+": return a + b
		"-": return a - b
		"*": return a * b
		"/": return _divide(a, b)
		"%": return fmod(a, b) if b != 0.0 and not is_inf(a) else NAN
		"**": return _power(a, b)
		"<": return a < b
		">": return a > b
		"<=": return a <= b
		">=": return a >= b
		"===": return _strict_equal(left, right)
		"!==": return not _strict_equal(left, right)
		"==", "!=":
			var nullish := _nullish(left) and _nullish(right)
			var equal := nullish or _strict_equal(left, right) or (not is_nan(a) and not is_nan(b) and a == b and left != null and right != null)
			return equal if op == "==" else not equal
	return _fail("unknown_operator")

func _math(n: Dictionary):
	if n.name == "random":
		var values: Array = _options.get("randomValues", [])
		if _options.has("randomValues"):
			if _draws >= values.size():
				return _fail("random_tape_exhausted")
			var value := _number(values[_draws])
			_draws += 1
			return value if value >= 0.0 and value < 1.0 else _fail("invalid_random_value")
		_draws += 1
		return 0.5
	var args: Array = n.args.map(func(a): return _number(_expr(a)))
	match str(n.name):
		"min": return _minmax(args, false)
		"max": return _minmax(args, true)
		"floor": return floorf(args[0])
		"ceil": return ceilf(args[0])
		"round":
			var value := float(args[0])
			if value == 0.0 or is_nan(value) or is_inf(value):
				return value
			if value >= -0.5 and value < 0.0:
				return _zero(true)
			var lo := floorf(value)
			return lo if value - lo < 0.5 else lo + 1.0
		"abs": return absf(args[0])
		"sqrt": return sqrt(args[0])
		"pow": return _power(args[0], args[1])
	return _fail("unknown_math")
