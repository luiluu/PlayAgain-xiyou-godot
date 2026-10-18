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

class NativeActor extends XActor:
	func param(i: int) -> float:
		return [10000.0, 1000.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0][i]

class NativeEnemy extends XEnemy:
	func param(i: int) -> float:
		return [10000.0, 101.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0][i]

class ApplyLogic extends XBattleLogic:
	var mode := "apply"
	func item_hit(_u: XBattler, _sk: Dictionary, _t: XBattler) -> float:
		return 0.0 if mode == "miss" else 1.0
	func item_eva(_u: XBattler, _sk: Dictionary, _t: XBattler) -> float:
		return 1.0 if mode == "evade" else 0.0

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
			apply_case(c)
			continue
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

func apply_case(c: Dictionary) -> void:
	var a := NativeEnemy.new()
	a.setup(int(XDB.rec("Troops", 157).members[0].enemyId), 3, 100.0)
	var b := NativeActor.new()
	b.setup(8)
	for pair in [[a, c.observed.before.a], [b, c.observed.before.b]]:
		pair[0].state_ids.clear()
		pair[0].state_turns.clear()
		pair[0].hp = pair[1].resources[0]
		pair[0].mp = pair[1].resources[1]
		pair[0].tp = pair[1].resources[2]
	var logic := ApplyLogic.new()
	logic.mode = c.setup.mode
	logic.state = XState.new()
	logic.actors = [b]
	logic.enemies = [a]
	logic.random = XBattleRandom.create("123456789abcdef0")
	var tape := [{"kind": "float", "value": 0.5}]
	if logic.mode != "miss":
		tape.append({"kind": "float", "value": 0.5})
	if logic.mode == "apply":
		tape.append({"kind": "float", "value": 0.5})
		if b.hp < 3000:
			tape.append({"kind": "uint32", "value": 2147483648})
		tape.append_array([{"kind": "uint32", "value": 9}, {"kind": "uint32", "value": 9}])
	logic.random.rule = XRandomStream.scripted(tape)
	var actual := logic.apply(a, XDB.rec("Skills", 857), b)
	check(c.id + ".resources", same([b.hp, b.mp, b.tp], c.observed.after.b.resources), [b.hp, b.mp, b.tp])
	check(c.id + ".result", same(actual.result, c.observed.after.b.result), actual.result)
	check(c.id + ".journal", same(actual.effectJournal, c.observed.journal), actual.effectJournal)
	# The native Yunshang wrapper consumes two UUID floats even on a miss. Stable
	# action IDs replace those bookkeeping-only draws; the rule draws are preserved.
	check(c.id + ".rule_draws", logic.random.rule.error.is_empty() and logic.random.rule.draws == int(c.observed.randomDraws) - 2, logic.random.rule.journal)
