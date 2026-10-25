extends Node
## 冻结原版27组Boss快照／缓存与2651生命周期；输出倍率单列后期。
var checks := 0
var failures: Array = []
var fixture: Dictionary

func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1000))

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func fresh(count: int) -> XState:
	var s := XState.new_game_blank()
	s.difficulty = 3
	s.set_switch(2494, true)
	var ids := [106, 101, 100, 102, 104].slice(0, count) if count else [1]
	s.party.assign(ids)
	s.battle_slots = ids.duplicate()
	while s.battle_slots.size() < 5:
		s.battle_slots.append(0)
	for id in ids:
		s.actor(id)._lv = 37
	return s

func compare(tag: String, e: XEnemy, row: Dictionary) -> void:
	var turns := {}
	for id in e.state_ids:
		if e.state_turns.has(id):
			turns[str(id)] = e.state_turns[id]
	var got := {"id": e.enemy_id, "count": e.boss_strong_count, "boss": e.boss_difficulty_boss,
		"rate": e.boss_attribute_rate(), "armor": e.boss_hyper_armor, "hp": e.hp, "mp": e.mp,
		"param": range(8).map(func(i): return e.param(i)), "states": e.state_ids.duplicate(), "turns": turns}
	for key in got:
		check(tag + "." + key, same(got[key], row[key]), [got[key], row[key]])

func setup_case(c: Dictionary) -> void:
	var s := fresh(int(c.setup.count))
	var e := XEnemy.new().setup(int(c.setup.id), 3, 100.0)
	var rows: Array = c.observed.rows
	compare(c.id + ".setup", e, rows[0])
	e.param_cache_begin()
	e.refresh_resources()
	compare(c.id + ".cached", e, rows[1])
	for i in range(3):
		compare(c.id + ".repeat%d" % i, e, rows[2 + i])
	e.add_state(4)
	e.refresh_resources()
	compare(c.id + ".debuff", e, rows[5])
	e.remove_state(4)
	e.refresh_resources()
	compare(c.id + ".removed", e, rows[6])
	s.battle_slots = [1, 0, 0, 0, 0]
	compare(c.id + ".party_changed", e, rows[7])
	for i in range(8):
		check(c.id + ".unscaled_cache%d" % i, e.param_cells[i] == e.param_now(i))
	var clone := XFormulaContext.clone_battler(e)
	check(c.id + ".shadow", clone != null)
	if clone != null:
		clone.boss_strong_count = 0
		check(c.id + ".detached", e.boss_strong_count == int(c.setup.count))

func battle_for(count: int) -> XBattleLogic:
	var s := fresh(count)
	var battle := XBattleLogic.new()
	battle.state = s
	battle.actors = s.battle_members()
	battle.enemies = [XEnemy.new().setup(1, 3, 100.0)]
	return battle

func turns_case(c: Dictionary) -> void:
	var battle := battle_for(int(c.setup.count))
	var e: XEnemy = battle.enemies[0]
	battle.enemy_transform(0, 6)
	var rows: Array = c.observed.rows
	var at := 0
	compare(c.id + ".setup", e, rows[at])
	at += 1
	for n in range(1, 7):
		if n == 2:
			for id in [6, 7, 4]:
				e.add_state(id)
		# Native fixture calls only increaseTurn, without later unit onTurnStart.
		battle.turn += 1
		e.sync_boss_armor(n % 2 == 0)
		compare(c.id + ".turn%d" % n, e, rows[at])
		at += 1
		if n == 2:
			# Godot removal hosts all reach remove_state; guard auto removal too.
			for mode in range(3):
				if mode == 1:
					e.remove_state_auto(2651)
				else:
					e.remove_state(2651)
				compare(c.id + ".remove%d" % mode, e, rows[at])
				at += 1
			for id in [6, 7, 8, 10, 4]:
				e.add_state(id)
				compare(c.id + ".add%d" % id, e, rows[at])
				at += 1
			e.add_state(6)
			compare(c.id + ".direct", e, rows[at])
			at += 1
			e.recover_all()
			compare(c.id + ".recover", e, rows[at])
			at += 1
	battle.end_battle(1)
	compare(c.id + ".end", e, rows[at])

func transform_case(c: Dictionary) -> void:
	var battle := battle_for(int(c.setup.count))
	var e: XEnemy = battle.enemies[0]
	e.param_cache_begin()
	e.refresh_resources()
	for n in range(int(c.setup.turn)):
		battle.turn += 1
		e.sync_boss_armor(battle.turn % 2 == 0)
	var rows: Array = c.observed.rows
	compare(c.id + ".before", e, rows[0])
	for i in range(1, rows.size()):
		battle.enemy_transform(0, int(rows[i].id))
		compare(c.id + ".%d" % i, e, rows[i])

func death_case(c: Dictionary) -> void:
	var battle := battle_for(3)
	var e: XEnemy = battle.enemies[0]
	battle.enemy_transform(0, 6)
	battle.turn = 2
	e.sync_boss_armor(true)
	var rows: Array = c.observed.rows
	compare(c.id + ".armor", e, rows[0])
	if c.setup.mode == "hidden_death":
		e.hidden = true
	if c.setup.mode == "hp0":
		e.hp = 0
	else:
		e.add_state(1)
	compare(c.id + ".dead", e, rows[1])
	var at := 2
	if c.setup.mode == "remove_dead":
		e.remove_state(2651)
		compare(c.id + ".remove", e, rows[at])
		at += 1
	if c.setup.mode == "recover":
		e.recover_all()
	else:
		e.remove_state(1)
	compare(c.id + ".revive", e, rows[at])
	e.sync_boss_armor(true)
	compare(c.id + ".sync", e, rows[at + 1])

func integration() -> void:
	for count in [0, 1, 3, 5]:
		var s := fresh(count)
		var battle := XBattleLogic.new()
		battle.elite_roll = 100.0
		battle.level_roll = 0.5
		battle.setup(2, s)
		for e in battle.enemies:
			check("integration.snapshot", e.boss_strong_count == count)
		s.battle_slots = [1, 0, 0, 0, 0]
		battle.enemy_transform(0, 6)
		for n in range(1, 5):
			battle.start_turn()
			var e: XEnemy = battle.enemies[0]
			check("integration.turn%d.%d" % [count, n], e.boss_hyper_armor == (n % 2 == 0) and e.is_state_affected(2651) == (n % 2 == 0))
			check("integration.fixed_count", e.boss_strong_count == count)
		battle.end_battle(2)
		check("integration.cleanup", not battle.enemies[0].boss_hyper_armor and not battle.enemies[0].is_state_affected(2651))

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/boss_lifecycle_oracle.json"))
	check("fixture", fixture.cases.size() == 27)
	check("source", fixture.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	for st in fixture.controls:
		check("control.%d" % int(st.id), XEnemy.boss_control_state(int(st.id)) == st.control)
	for c in fixture.cases:
		check(c.id + ".oracle", c.errors.is_empty())
		if c.id.begins_with("setup."):
			setup_case(c)
		elif c.id.begins_with("turns."):
			turns_case(c)
		elif c.id.begins_with("transform."):
			transform_case(c)
		else:
			death_case(c)
	integration()
	print("TEST_RESULT=" + JSON.stringify({"total": checks, "passed": checks - failures.size(), "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
