extends Node
## 冻结原版普通输出入口：逐例比资源、护盾、状态及伤害结果槽。
var checks := 0
var failures: Array = []

func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(800))

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func snap(b: XBattler, resources: XResourceContext) -> Dictionary:
	return {"hp": b.hp, "mp": b.mp, "tp": b.tp, "shield": b.shield, "states": b.state_ids.duplicate(), "result": resources.result(b).duplicate(true)}

func compare(tag: String, b: XBattler, resources: XResourceContext, expected: Dictionary) -> void:
	var got := snap(b, resources)
	for key in ["hp", "mp", "tp", "shield", "states"]:
		check(tag + "." + key, same(got[key], expected[key]), [got[key], expected[key]])
	# success/miss/critical are owned by the surrounding action host; this direct entry tests resource slots.
	for key in ["hpAffected", "hpDamage", "mpDamage", "tpDamage", "addedStates", "removedStates"]:
		check(tag + ".result." + key, same(got.result[key], expected.result[key]), [got.result[key], expected.result[key]])

func run_case(c: Dictionary) -> void:
	var spec: Dictionary = c.setup
	var s := XState.new_game_blank()
	s.difficulty = 3
	s.set_switch(2494, true)
	var ids := [106, 101, 100, 102, 104].slice(0, int(spec.count)) if int(spec.count) else [1]
	s.party.assign(ids)
	s.battle_slots = ids.duplicate()
	while s.battle_slots.size() < 5:
		s.battle_slots.append(0)
	for id in ids:
		s.actor(id)._lv = 37
	var e := XEnemy.new().setup(int(spec.get("enemy", 6)), 3, 100.0)
	var other := XEnemy.new().setup(1, 3, 100.0)
	var actor := s.actor(1)
	for b in [e, other, actor]:
		b.param_cache_begin()
		b.refresh_resources()
	e.sync_boss_armor(spec.armor)
	if spec.get("noIcon", false):
		e.add_state(1)
		e.remove_state(1)
	var source: XBattler = actor if spec.get("actorSource", false) else e
	var target: XBattler = source if spec.get("self", false) else (actor if spec.get("actorTarget", false) else other)
	for b in [e, other, actor]:
		b.hp = minf(500.0, b.mhp)
		b.mp = minf(300.0, b.mmp)
		b.tp = 0.0
		b.shield = 0.0
	target.shield = float(spec.get("shield", 0))
	var resources := XResourceContext.new()
	var battle := XBattleLogic.new()
	battle.state = s
	battle.troop_id = 1
	battle._action_resources = resources
	compare(c.id + ".before.source", source, resources, c.observed.before.source)
	compare(c.id + ".before.target", target, resources, c.observed.before.target)
	check(c.id + ".rate", same(e.boss_output_rate() if source == e else 1.0, c.observed.rate))
	check(c.id + ".armor", e.boss_hyper_armor == c.observed.armor)
	check(c.id + ".icon", e.is_state_affected(2651) == c.observed.icon)
	if spec.kind == "hp":
		battle.execute_hp_damage(source, target, float(spec.value), spec.get("drain", false))
	else:
		battle.execute_mp_damage(source, target, float(spec.value), spec.get("drain", false))
	check(c.id + ".diagnostic", resources.error.is_empty(), resources.error)
	compare(c.id + ".after.source", source, resources, c.observed.after.source)
	compare(c.id + ".after.target", target, resources, c.observed.after.target)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	XDB.load_db()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/boss_output_oracle.json"))
	for c in fixture.cases:
		check(c.id + ".native", c.errors.is_empty())
		run_case(c)
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
