class_name XCatDamageHooks
extends RefCounted
## Frozen CodexCat 1.0.1 cat-sword: numeric handlers only. The host captures
## live facts; handlers receive frozen values and never mutate the base module.
const BASE := "res://modes/xiyou/core/cat.gd"
const ELEMENTS := [2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15]
const SKILLS := [10437, 10438, 10439, 10440, 10445]
static var _checked := false
static var _base: RefCounted

static func descriptor() -> Dictionary:
	return {"id": "cat-sword", "version": "1.0.1", "capabilities": ["damage.cat_sword"],
		"contexts": ["item", "subject", "target", "facts"], "hooks": [
			{"point": "damage.before", "order": 18, "reads": ["facts.cat"], "writes": ["flatMitigationAdd"], "handler": enter},
			{"point": "damage.before", "order": 19, "reads": ["facts.cat"],
				"writes": ["normalAdd", "elementAdd", "finalAdd", "criticalAdd", "settlementMultiplier"], "handler": build}]}

static func base_provider() -> RefCounted:
	if not _checked:
		_checked = true
		# A partial character checkout must not enable its combat mechanics.
		if ResourceLoader.exists(BASE) and XActor.new().has_method("stat_equips"):
			var script = load(BASE)
			if script is Script and script.can_instantiate(): _base = script.new()
	return _base

static func _own(b: XBattler) -> bool:
	return b is XActor and b.actor_id == 178

static func _sword(b: XBattler) -> bool:
	if not _own(b) or not b.skill_ids.has(10441) or b.equips.is_empty(): return false
	var weapon = b.equips[0]
	return weapon is Dictionary and weapon.get("kind") == "weapon" and int(weapon.get("wtypeId", 0)) == 2

## Host-side snapshot builder. Optional provider permits isolated fixtures and
## future explicit session services; no provider reference escapes into facts.
static func capture(_item: Dictionary, a: XBattler, b: XBattler, options: Dictionary, provider: RefCounted = null) -> Dictionary:
	if provider == null: provider = base_provider()
	var out := {"enabled": provider != null, "subjectSword": false, "targetSword": false,
		"heart": false, "advanced": false, "targetSpeed": 0.0, "round": null}
	if provider == null: return out
	out.subjectSword = _sword(a)
	out.targetSword = _sword(b)
	out.heart = _own(a) and a.skill_ids.has(10443)
	if out.subjectSword and out.heart:
		if not provider.has_method("advanced"):
			out.diagnostic = "cat_base_advanced_missing"
			return out
		var advanced = provider.call("advanced", a)
		if not advanced is bool:
			out.diagnostic = "cat_base_advanced_invalid"
			return out
		out.advanced = advanced
	if out.targetSword:
		out.targetSpeed = b.agi
		if not is_finite(float(out.targetSpeed)): out.diagnostic = "cat_target_speed_invalid"
	var natural_round = options.get("battleRound")
	if (natural_round is int or natural_round is float) and is_finite(float(natural_round)) and float(natural_round) == floorf(float(natural_round)):
		out.round = maxi(1, int(natural_round))
	return out

static func _operation(field: String, value: float, element := -1, operation := "add") -> Dictionary:
	var out := {"op": operation, "field": field, "value": value}
	if element >= 0: out.element = element
	return out

static func _failure(facts: Dictionary) -> Dictionary:
	return {"ops": [], "available": false, "diagnostic": str(facts.diagnostic)}

static func enter(context: Dictionary, _frame: Dictionary) -> Dictionary:
	var cat: Dictionary = context.facts.cat
	if cat.has("diagnostic"): return _failure(cat)
	var ops := []
	if not cat.enabled: return {"ops": ops}
	if context.target.kind == "actor" and int(context.target.id) == 178 and cat.targetSword:
		var speed := float(cat.targetSpeed)
		ops.append(_operation("flatMitigationAdd", minf(16000.0, minf(floorf(3 * speed), 15030 + floorf(speed / 8))), 1))
		for element in ELEMENTS:
			ops.append(_operation("flatMitigationAdd", minf(18000.0, minf(floorf(3.2 * speed), 16400 + floorf(2 * speed / 11))), element))
	if context.target.kind == "enemy" and int(context.target.id) == 1999:
		if not cat.get("round") is int:
			return {"ops": [], "available": false, "diagnostic": "cat_dragon_round_missing"}
		if (int(cat.round) - 1) % 5 != 3:
			ops.append(_operation("flatMitigationAdd", 1e11, 1))
			ops.append(_operation("flatMitigationAdd", 5e10, 8))
	return {"ops": ops}

static func build(context: Dictionary, _frame: Dictionary) -> Dictionary:
	var cat: Dictionary = context.facts.cat
	if cat.has("diagnostic"): return _failure(cat)
	var ops := []
	if cat.enabled and context.subject.kind == "actor" and int(context.subject.id) == 178 and cat.subjectSword and int(context.item.id) in SKILLS:
		ops = [_operation("normalAdd", 6), _operation("elementAdd", 6, 1), _operation("elementAdd", 6, 8)]
		if cat.heart:
			ops.append(_operation("finalAdd", 8)); ops.append(_operation("criticalAdd", 12))
			if cat.advanced: ops.append(_operation("settlementMultiplier", 2, -1, "mul"))
	return {"ops": ops}
