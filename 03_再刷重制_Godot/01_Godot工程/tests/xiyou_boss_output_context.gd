extends Node
## 原版真实行动上下文；资源API逐步回放。post/execute脚本宿主本身仍未移植。
var checks := 0
var failures: Array = []
var bs := {}
var resources: XResourceContext
var battle: XBattleLogic
var expected: Array
var row_at := 0
var caught := 0

class HookBattle extends XBattleLogic:
	var fixture_resources: XResourceContext
	var steps := Callable()
	func _new_lifecycle_resources() -> XResourceContext:
		return fixture_resources
	func _calculate_damage(_u: XBattler, _skill: Dictionary, _t: XBattler, critical: bool) -> Dictionary:
		steps.call()
		return {"value": 0.0, "critical": critical}

func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 15:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(800))

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func compare(tag: String, b: XBattler, row: Dictionary) -> void:
	var got := {"hp": b.hp, "mp": b.mp, "tp": b.tp, "shield": b.shield, "states": b.state_ids.duplicate()}
	for key in got:
		check(tag + "." + key, same(got[key], row[key]), [got[key], row[key]])
	for key in row.result:
		check(tag + ".result." + key, same(resources.result(b)[key], row.result[key]), [resources.result(b)[key], row.result[key]])

func run_ops(ops: Array, tag: String) -> bool:
	for op in ops:
		if op.op == "throw":
			# Native YEP eval catches a script exception. The translated host returns a diagnostic instead.
			return false
		if op.op == "nested":
			var ok = resources.boss_output.with_action(bs[op.source], bs[op.target], func(): return run_ops(op.ops, tag))
			if not ok:
				caught += 1
			continue
		var b: XBattler = bs[op.who]
		check(tag + ".row%d.op" % row_at, same(op, expected[row_at].op), [op, expected[row_at].op])
		compare(tag + ".row%d.before" % row_at, b, expected[row_at].before)
		if op.op == "gain":
			resources.gain(b, op.kind, float(op.value))
		elif op.op == "set":
			resources.set_resource(b, op.kind, float(op.value))
		else:
			if op.kind == "hp":
				battle.execute_hp_damage(bs.a, b, float(op.value), false)
			else:
				battle.execute_mp_damage(bs.a, b, float(op.value), false)
		compare(tag + ".row%d.after" % row_at, b, expected[row_at].after)
		row_at += 1
	return true

func fresh(count: int) -> XState:
	var s := XState.new_game_blank()
	s.difficulty = 3
	s.set_switch(2494, true)
	var ids := [106, 101, 100, 102, 104].slice(0, count) if count else [1]
	s.party.assign(ids)
	s.battle_slots = ids.duplicate()
	while s.battle_slots.size() < 5:
		s.battle_slots.append(0)
	return s

func run_case(c: Dictionary) -> void:
	var spec: Dictionary = c.setup
	var s := fresh(int(spec.count))
	var a := XEnemy.new().setup(6, 3, 100.0)
	var b: XBattler = s.actor(1) if spec.get("actorTarget", false) else XEnemy.new().setup(6, 3, 100.0)
	var other := XEnemy.new().setup(6, 3, 100.0)
	bs = {"a": a, "b": b, "c": other}
	for x in bs.values():
		x.param_cache_begin()
		x.refresh_resources()
	a.sync_boss_armor(spec.armor)
	if spec.get("noIcon", false):
		a.add_state(1)
		a.remove_state(1)
	for x in bs.values():
		x.hp = minf(float(spec.get("hp", 500)), x.mhp)
		x.mp = minf(300.0, x.mmp)
		x.tp = 0.0
		x.shield = 0.0
	b.shield = float(spec.get("shield", 0))
	resources = XResourceContext.new()
	var hb := HookBattle.new()
	hb.fixture_resources = resources
	hb.steps = func(): return run_ops(spec.ops, c.id)
	battle = hb
	battle.state = s
	battle._action_resources = resources
	expected = c.observed.rows
	row_at = 0
	caught = 0
	for k in bs:
		compare(c.id + ".before." + k, bs[k], c.observed.before[k])
	if spec.has("formula"):
		var item := XDB.rec("Skills", 1).duplicate(true)
		item.hitType = 0
		item.effects = []
		item.tpGain = 0
		item.damage.critical = false
		item.damage.variance = 0
		item.damage.formula = spec.formula
		var programs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/boss_output_context_programs.json"))
		var kind := "mp" if str(spec.formula).contains("gainMp") else "hp"
		item.damage.formulaProgram = programs[kind]
		var actual_battle := XBattleLogic.new()
		actual_battle.state = s
		actual_battle._action_resources = resources
		var out := actual_battle.apply(a, item, b)
		check(c.id + ".formula_diagnostic", out.formulaDiagnostic.is_empty(), out.formulaDiagnostic)
		check(c.id + ".formula_one_gain", out.effectJournal.size() == 2, out.effectJournal)
		check(c.id + ".resource_restore", actual_battle._action_resources == resources)
		resources.seed_result(b, out.result)
		compare(c.id + ".formula.after", b, expected[0].after)
		row_at = 1
	elif spec.host == "apply":
		var item := XDB.rec("Skills", 1).duplicate(true)
		item.hitType = 0
		item.effects = []
		item.tpGain = 0
		item.damage.critical = false
		battle.apply(a, item, b)
	elif spec.host == "none":
		run_ops(spec.ops, c.id)
	else:
		resources.boss_output.with_action(a, b, func(): return run_ops(spec.ops, c.id))
		# Native executeDamage settles 0 HP after pre-eval, replacing its result slot.
		if spec.host == "execute":
			battle.execute_hp_damage(a, b, 0.0, false)
	check(c.id + ".scope_restored", resources.boss_output.is_empty())
	var last: Dictionary = expected[row_at]
	compare(c.id + ".outside.before", b, last.before)
	resources.gain(b, "hp", -1.0)
	compare(c.id + ".outside.after", b, last.after)
	check(c.id + ".row_count", row_at + 1 == expected.size())
	check(c.id + ".caught", caught == c.observed.caught.size())
	check(c.id + ".diagnostic", resources.error.is_empty(), resources.error)
	for k in bs:
		compare(c.id + ".after." + k, bs[k], c.observed.after[k])
	check(c.id + ".icon", a.is_state_affected(2651) == c.observed.icon)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/boss_output_context_oracle.json"))
	check("source", fixture.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	for c in fixture.cases:
		check(c.id + ".native", c.errors.is_empty())
		run_case(c)
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
