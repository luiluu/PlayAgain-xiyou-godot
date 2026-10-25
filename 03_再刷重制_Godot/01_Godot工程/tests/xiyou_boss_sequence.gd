extends Node
## YEP数值序列真实入口参照；通用EVAL宿主不在本期。
var total := 0
var failures: Array = []

func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 18:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(700))

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func snap(b: XBattler) -> Dictionary:
	var r := {}
	for k in ["hpAffected", "hpDamage", "mpDamage", "tpDamage", "addedStates", "removedStates"]:
		r[k] = b.runtime_result[k]
	return {"hp": b.hp, "mp": b.mp, "tp": b.tp, "shield": b.shield, "dirty": b.effect_dirty, "states": b.state_ids.duplicate(), "result": r}

func compare(tag: String, b: XBattler, want: Dictionary) -> void:
	var got := snap(b)
	for k in got:
		check(tag + "." + k, same(got[k], want[k]), [got[k], want[k]])

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
	var boss := XEnemy.new().setup(int(spec.get("enemy", 6)), 3, 100.0)
	var actor := s.actor(1)
	var other := XEnemy.new().setup(6, 3, 100.0)
	var third := XEnemy.new().setup(6, 3, 100.0)
	var a: XBattler = actor if spec.get("actorSource", false) else boss
	var b: XBattler = actor if spec.get("actorTarget", false) else other
	var bs := {"a": a, "b": b, "c": third}
	for x in s.battle_members():
		if not bs.values().has(x):
			bs["p%d" % x.actor_id] = x
	var members := [boss, actor, other, third]
	for x in bs.values():
		if not members.has(x):
			members.append(x)
	for x in members:
		x.param_cache_begin()
		x.refresh_resources()
	boss.sync_boss_armor(bool(spec.armor))
	for x in members:
		x.hp = minf(500.0, x.mhp)
		x.mp = minf(300.0, x.mmp)
		x.tp = 0.0
		x.shield = 0.0
		x.runtime_result = XResourceContext.empty_result()
	b.shield = float(spec.get("shield", 0))
	var logic := XBattleLogic.new()
	logic.state = s
	logic.actors = s.battle_members()
	logic.enemies = [boss, other, third]
	if spec.has("variable"):
		s.set_variable(20, float(spec.variable))
	var list: Array = spec.targets.map(func(k): return bs[k])
	var command := str(spec.kind) + " " + str(spec.change)
	var item := {"yepSeq": {"whole": [[command, [spec.selector]]]}}
	var seq := XActionSequence.create(logic, a, item, list)
	seq.targets = list.duplicate()
	var resolved := seq.make_targets(str(spec.selector)).map(func(x): return bs.find_key(x))
	check(c.id + ".resolved", same(resolved, c.observed.resolved), [resolved, c.observed.resolved])
	for k in bs:
		compare(c.id + ".before." + k, bs[k], c.observed.before[k])
	if spec.entry == "direct":
		seq._resources = logic._new_lifecycle_resources()
		seq._modify(str(spec.kind), command, seq.make_targets(str(spec.selector)))
	else:
		seq.run()
	if spec.get("interleaved", false):
		# 原版：一次数值指令后执行普通MP伤害，再对另一目标执行数值指令。
		# 后一指令不能把前一目标的结果槽回写为旧值。
		var mid := XResourceContext.new()
		mid.seed_result(b, b.runtime_result)
		logic._action_resources = mid
		logic.execute_mp_damage(a, b, 5.0, false)
		mid.publish()
		logic._action_resources = null
		seq.targets = [third]
		seq._modify(str(spec.kind), command, [third])
	check(c.id + ".domain_restored", seq._resources.boss_output.is_empty())
	check(c.id + ".diagnostic", seq._resources.error.is_empty(), seq._resources.error)
	for k in bs:
		compare(c.id + ".after." + k, bs[k], c.observed.after[k])
	compare(c.id + ".outside.before", b, c.observed.outsideBefore)
	var outside := XResourceContext.new()
	outside.seed_result(b, b.runtime_result)
	outside.gain(b, "hp", -1.0)
	outside.publish()
	compare(c.id + ".outside.after", b, c.observed.outsideAfter)

func boundaries() -> void:
	fresh(3)
	var a := XEnemy.new().setup(6, 3, 100.0)
	var b := XEnemy.new().setup(6, 3, 100.0)
	var c := XEnemy.new().setup(6, 3, 100.0)
	a.sync_boss_armor(true)
	var scope := XBossOutputContext.new()
	scope.enter_targets(a, [a, b])
	check("list.target", scope.loss_value(b, "hp", 7.0) == 11.0)
	check("list.self", scope.loss_value(a, "hp", 7.0) == 7.0)
	check("list.outside", scope.loss_value(c, "hp", 7.0) == 7.0)
	scope.enter_action(c, b)
	check("nested.inner_source", scope.loss_value(b, "hp", 7.0) == 7.0)
	scope.leave_action()
	check("nested.outer_list", scope.loss_value(b, "mp", 7.0) == 11.0)
	scope.enter_targets(a, [])
	check("nested.empty_shadows_outer", scope.loss_value(b, "hp", 7.0) == 7.0)
	scope.leave_action()
	scope.leave_action()
	check("list.restored", scope.is_empty())
	var logic := XBattleLogic.new()
	var s := fresh(3)
	logic.state = s
	b.hp = 500.0
	logic.sequence_gain(b, "HP", -7.0)
	check("event.no_boss_source", b.hp == 493.0)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/boss_sequence_oracle.json"))
	check("source", fixture.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("complete", fixture.cases.size() == 88)
	var ids := {}
	for c in fixture.cases:
		ids[c.id] = true
	check("unique", ids.size() == 88)
	boundaries()
	for c in fixture.cases:
		check(c.id + ".native", c.errors.is_empty())
		run_case(c)
	print("TEST_RESULT=" + JSON.stringify({"passed": total - failures.size(), "total": total, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
