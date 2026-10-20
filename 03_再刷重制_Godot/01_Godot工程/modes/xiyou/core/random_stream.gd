class_name XRandomStream
extends RefCounted
## An owned rule/reward/equipment stream. No global random state, no looping tapes.
const VERSION := 1
const ENGINE := "4.7.2.stable.official.ed1daf0bf"
var domain := ""
var draws := 0
var journal: Array = []
var error := ""
var _rng := RandomNumberGenerator.new()
var _tape: Array = []
var _scripted := false
var _seed_hex := ""

## Runtime entropy is independent of the persistent orb seed and global RNG.
static func fresh_seed() -> String:
	var source := RandomNumberGenerator.new()
	source.randomize()
	return hex64(source.seed)

static func hex64(value: int) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, value)
	bytes.reverse()
	return bytes.hex_encode()

static func parse64(value: String) -> int:
	var bytes := value.hex_decode()
	if bytes.size() != 8:
		return 0
	bytes.reverse()
	return bytes.decode_s64(0)

static func derive(seed_hex: String, key: String) -> String:
	return ("xiyou-rng-v1|" + seed_hex + "|" + key).sha256_text().substr(0, 16)

static func create(seed_hex: String, stream_domain: String) -> XRandomStream:
	var out := XRandomStream.new()
	out.domain = stream_domain
	out._seed_hex = seed_hex
	out._rng.seed = parse64(seed_hex)
	return out

static func scripted(values: Array, stream_domain := "rule") -> XRandomStream:
	var out := create("0000000000000000", stream_domain)
	out._scripted = true
	out._tape = values.duplicate(true)
	return out

func _take(kind: String, reason: String, event_key: String):
	if not error.is_empty():
		return null
	var value
	if _scripted:
		if draws >= _tape.size():
			error = "random_tape_exhausted:" + domain + ":" + reason
			return null
		var entry = _tape[draws]
		if not entry is Dictionary or entry.get("kind") != kind or (entry.has("domain") and entry.domain != domain) \
			or (entry.has("reason") and entry.reason != reason) or (entry.has("event") and entry.event != event_key):
			error = "random_tape_mismatch:" + domain + ":" + reason
			return null
		value = entry.get("value")
	else:
		# Half-open double precision interval, including zero and excluding one.
		# A raw uint draw also keeps consumption independent of Godot randf internals.
		value = float(_rng.randi()) / 4294967296.0 if kind == "float" else _rng.randi()
	var valid := (value is int or value is float) and not is_nan(float(value)) and not is_inf(float(value))
	valid = valid and (float(value) >= 0.0 and float(value) < 1.0 if kind == "float" else float(value) >= 0.0 and float(value) <= 4294967295.0 and float(value) == floorf(float(value)))
	if not valid:
		error = "random_value_out_of_range:" + domain + ":" + reason
		return null
	journal.append({"domain": domain, "ordinal": draws, "kind": kind, "reason": reason, "event": event_key, "value": value})
	draws += 1
	return value

func next_float(reason: String, event_key := "") -> float:
	var value = _take("float", reason, event_key)
	return float(value) if value != null else 0.0

func next_uint(reason: String, event_key := "") -> int:
	var value = _take("uint32", reason, event_key)
	return int(value) if value != null else 0

func next_index_mod(n: int, reason: String, event_key := "") -> int:
	if n <= 0:
		error = "invalid_random_modulus"
		return 0
	return next_uint(reason, event_key) % n

func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
	if hi < lo or hi - lo >= 4294967295:
		error = "invalid_random_range"
		return lo
	# PCG bounded distribution (same inclusive range distribution as Godot).
	# Even a singleton range consumes one raw draw, as the existing rule path does.
	var bound := hi - lo + 1
	var threshold := 4294967296 % bound
	var value := next_uint(reason, event_key)
	while value < threshold and error.is_empty():
		value = next_uint(reason, event_key)
	return lo + value % bound

func snapshot() -> Dictionary:
	return {"version": VERSION, "engine": ENGINE, "domain": domain, "seed": _seed_hex,
		"state": hex64(_rng.state), "draws": draws, "scripted": _scripted,
		"tape": _tape.duplicate(true) if _scripted else []}

static func valid_saved(data) -> bool:
	if not data is Dictionary or data.get("version") != VERSION or data.get("engine") != ENGINE:
		return false
	for key in ["seed", "state"]:
		var value = data.get(key)
		if not valid_hex(value):
			return false
	var count = data.get("draws")
	return data.get("domain") is String and (count is int or count is float) and is_finite(float(count)) and float(count) >= 0.0 and float(count) == floorf(float(count)) and float(count) < 9007199254740992.0 and data.get("scripted", false) is bool and data.get("tape", []) is Array

static func valid_hex(value) -> bool:
	return value is String and RegEx.create_from_string("^[0-9a-f]{16}$").search(value) != null

static func restore(data: Dictionary) -> XRandomStream:
	if not valid_saved(data):
		return null
	var out := create(str(data.seed), str(data.domain))
	out._rng.state = parse64(str(data.state))
	out.draws = int(data.draws)
	out._scripted = bool(data.get("scripted", false))
	out._tape = data.get("tape", []).duplicate(true)
	return out
