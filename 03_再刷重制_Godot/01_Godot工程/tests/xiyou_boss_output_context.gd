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

class RefreshProbe extends XResourceContext:
	var refresh_calls := 0
	func refresh(b: XBattler) -> void:
		refresh_calls += 1
		super.refresh(b)

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

func boundary_checks() -> void:
	var s := fresh(3)
	var a := XEnemy.new().setup(6, 3, 100.0)
	var b := XEnemy.new().setup(6, 3, 100.0)
	var c := XEnemy.new().setup(6, 3, 100.0)
	for x in [a, b, c]:
		x.param_cache_begin()
		x.refresh_resources()
		x.hp = 500.0
		x.mp = 300.0
	a.sync_boss_armor(true)
	var r := RefreshProbe.new()
	var scope := r.boss_output
	var peer := XResourceContext.new()
	scope.with_action(a, b, func():
		# settled／direct must distinguish target AND resource.
		scope.enter_settled(b, "hp")
		check("settled.same", scope.loss_value(b, "hp", 7.0) == 7.0)
		check("settled.other_resource", scope.loss_value(b, "mp", 7.0) == 11.0)
		scope.with_action(a, c, func(): check("settled.other_target", scope.loss_value(c, "hp", 7.0) == 11.0))
		scope.leave_settled()
		scope.enter_direct(b, "hp")
		check("direct.same", scope.loss_value(b, "hp", 7.0) == 7.0)
		check("direct.other_resource", scope.loss_value(b, "mp", 7.0) == 11.0)
		scope.leave_direct()
		check("tp.unscaled", scope.loss_value(b, "tp", 7.9) == 7.9)
		check("peer.isolated", peer.boss_output.loss_value(b, "hp", 7.0) == 7.0)
		var programs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/boss_output_context_programs.json"))
		var item := XDB.rec("Skills", 1).duplicate(true)
		item.hitType = 0
		item.effects = []
		item.tpGain = 0
		item.damage.critical = false
		item.damage.variance = 0
		item.damage.formulaProgram = programs.hp
		var before_hp := b.hp
		var preview := XFormulaExecution.run_item(item, a, b, {}, {}, false, null, r)
		check("preview.available", preview.available)
		check("preview.private_domain", is_equal_approx(preview.after.b.resources[0], before_hp - 7.9))
		check("preview.no_mutation", b.hp == before_hp and r.journal.is_empty())
		var inner := XBattleLogic.new()
		inner.state = s
		inner._action_resources = r
		var out := inner.apply(c, item, b)
		check("nested.real_formula", out.formulaDiagnostic.is_empty() and is_equal_approx(b.hp, before_hp - 7.9), out)
		check("nested.resources_restored", inner._action_resources == r)
		check("nested.outer_restored", scope.frames.size() == 1 and scope.frames[-1].source == a)
		check("nested.outer_rate", scope.loss_value(b, "hp", 7.0) == 11.0)
		# A genuine VM diagnostic returns normally through apply and restores the outer frame.
		item.damage.formulaProgram = programs.set_unsupported
		out = inner.apply(c, item, b)
		check("diagnostic.explicit", out.formulaDiagnostic == "unsupported_program", out.formulaDiagnostic)
		check("diagnostic.outer_restored", inner._action_resources == r and scope.frames.size() == 1 and scope.frames[-1].source == a)
		check("diagnostic.resources_not_poisoned", r.error.is_empty())
	)
	check("nested.all_restored", scope.is_empty())
	var old := b.hp
	r.gain(b, "hp", -7.0)
	check("diagnostic.outside_unscaled", b.hp == old - 7.0)
	# Setter does not create gain slots, mark dirty, or refresh an equal input.
	r.refresh(b)
	var result_before := r.result(b).duplicate(true)
	var refresh_before := r.refresh_calls
	r.set_resource(b, "hp", b.hp)
	check("set.equal_no_refresh", r.refresh_calls == refresh_before)
	r.set_resource(b, "mp", b.mp - 1.0)
	check("set.no_gain_dirty", not b.effect_dirty and not b.param_dirty)
	check("set.no_result_write", same(result_before, r.result(b)))
	check("set.no_scope_leak", scope.is_empty())

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/boss_output_context_oracle.json"))
	check("source", fixture.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	boundary_checks()
	for c in fixture.cases:
		check(c.id + ".native", c.errors.is_empty())
		run_case(c)
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
