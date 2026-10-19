extends Node
var checks := 0
var failed := []

func check(label: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failed.append(label)
		print("FAIL ", label, " ", detail)

func equal(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func _ready() -> void:
	for n in [0, 1, -1, 4294967295, 9223372036854775807, -9223372036854775807 - 1]:
		check("hex:" + str(n), XRandomStream.parse64(XRandomStream.hex64(n)) == n and XRandomStream.valid_hex(XRandomStream.hex64(n)))
	var first := XBattleRandom.create("eec8f70b95c81308", 5)
	var independent := XBattleRandom.create("eec8f70b95c81308", 5)
	for i in 128:
		first.reward.next_float("drop")
		randf()
		randi()
		check("owned_rule:" + str(i), first.rule.next_float("hit") == independent.rule.next_float("hit"))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(first.snapshot()))
	var restored := XBattleRandom.restore(saved)
	check("restore", restored != null)
	for i in 64:
		check("continuation:" + str(i), first.rule.next_int_inclusive(-7, 19, "range") == restored.rule.next_int_inclusive(-7, 19, "range"))
	var native := RandomNumberGenerator.new()
	native.seed = XRandomStream.parse64("123456789abcdef0")
	var owned := XRandomStream.create("123456789abcdef0", "rule")
	for i in range(1, 129):
		check("native_bounded:" + str(i), native.randi_range(-i, i) == owned.next_int_inclusive(-i, i, "native") and XRandomStream.hex64(native.state) == owned.snapshot().state)
	var wrong: Dictionary = saved.duplicate(true)
	wrong.engine = "future-engine"
	check("engine_reject", XBattleRandom.restore(wrong) == null)
	for value in ["fffffffffffffffg", "-123456789abcdef", "0", 10, null]:
		var bad: Dictionary = saved.rule.duplicate(true)
		bad.state = value
		check("state_reject:" + str(value), not XRandomStream.valid_saved(bad))
	for value in [-1, 1.5, INF, NAN, true]:
		var bad: Dictionary = saved.rule.duplicate(true)
		bad.draws = value
		check("count_reject:" + str(value), not XRandomStream.valid_saved(bad))
	var range_rng := XRandomStream.scripted([{"kind": "uint32", "value": 0}, {"kind": "uint32", "value": 9}, {"kind": "uint32", "value": 8}])
	check("bounded_rejection", range_rng.next_int_inclusive(0, 5, "range") == 3 and range_rng.draws == 2)
	check("singleton_consumed", range_rng.next_int_inclusive(4, 4, "range") == 4 and range_rng.draws == 3)
	range_rng.next_uint("overflow")
	check("tape_no_loop", range_rng.draws == 3 and range_rng.error.begins_with("random_tape_exhausted"))
	for tape in [[{"kind": "float", "value": 1.0}], [{"kind": "uint32", "value": -1}], [{"kind": "float", "value": 0.5, "domain": "equipment"}]]:
		var invalid := XRandomStream.scripted(tape)
		invalid.next_float("wrong")
		check("typed_tape_rejected", not invalid.error.is_empty() and invalid.draws == 0)
	var state := XState.new_game(3, 1, [])
	check("lazy_save", state.random_master.is_empty() and state._equipment_random == null)
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	legacy.erase("random")
	legacy.rom = {"x": range(20).map(func(i): return i * 0.01), "xn": 3, "xs": range(20).map(func(i): return i % 2), "xsn": 2, "g": [], "gn": 0}
	var loaded := XState.from_dict(legacy)
	check("legacy_zero_consumption", loaded.random_master.is_empty() and loaded._equipment_random == null and equal(loaded.rom, legacy.rom) and equal(loaded.gear, legacy.gear))
	var before := JSON.stringify(loaded.random_save())
	var gear := XGear.template("weapon", 56)
	XGearUpgrade.preview(gear, XDB.rec("Items", 258))
	XPower.actor(loaded.actor(1))
	check("previews_no_initialize", before == JSON.stringify(loaded.random_save()) and equal(loaded.rom, legacy.rom))
	loaded.gain_gear("weapon", 56, 1)
	var encoded: Dictionary = JSON.parse_string(JSON.stringify(loaded.to_dict()))
	var second := XState.from_dict(encoded)
	check("equipment_save", second != null and equal(loaded.random_save(), second.random_save()))
	loaded.gain_gear("weapon", 56, 2)
	second.gain_gear("weapon", 56, 2)
	check("equipment_continuation", equal(loaded.gear, second.gear) and equal(loaded.rom, second.rom) and equal(loaded.random_save(), second.random_save()))
	var b0 := loaded.reserve_battle_random()
	var b1 := loaded.reserve_battle_random()
	check("serial", b0.serial == 0 and b1.serial == 1 and b0.master_seed != b1.master_seed)
	var b1_before := b1.snapshot()
	b0.rule.next_float("hit")
	b0.reward.next_float("drop")
	check("two_battles", equal(b1_before, b1.snapshot()))
	var preview_logic := XBattleLogic.new()
	preview_logic.setup(2, loaded)
	var untouched := JSON.stringify([loaded.to_dict(), preview_logic.random.snapshot()])
	XDamage.eval_formula(XDB.rec("Skills", 857), loaded.actor(1), preview_logic.enemies[0], loaded.variable_array())
	check("full_preview_snapshot", untouched == JSON.stringify([loaded.to_dict(), preview_logic.random.snapshot()]))
	var outside := XBattleLogic.new()
	outside.state = loaded
	var serial_before := loaded.battle_serial
	var world_user := loaded.actor(1)
	world_user.hp = maxf(1.0, world_user.hp - 1.0)
	outside._effect(world_user, world_user, {"code": 11, "value1": 0.0, "value2": 1.0, "dataId": 0}, {"skill": XDB.rec("Items", 1), "hp": 0.0, "mp": 0.0, "added": [], "removed": []})
	check("menu_effect_world_owner", outside.random == null and loaded.battle_serial == serial_before)
	var replay_state := XState.new_game(3, 1, [])
	replay_state.random_master = "123456789abcdef0"
	var initial := replay_state.to_dict().duplicate(true)
	var logic := XBattleLogic.new()
	logic.setup(2, replay_state)
	logic.auto = true
	var commands := []
	var logs := []
	logic.start_turn()
	for i in 2:
		var user := logic.next_subject()
		if user == null: break
		var cmd := logic.decide(user)
		commands.append({"turn": logic.turn, "user": logic.stable_id(user), "skill": int(cmd[0].id), "target": "", "automatic": true})
		logs.append_array(logic.act(user, cmd[0], cmd[1]))
	var artifact := XBattleReplay.record(logic, initial, commands, logs)
	var replayed := XBattleReplay.replay(JSON.parse_string(JSON.stringify(artifact)))
	check("actual_command_replay", replayed.available, replayed)
	_hidden_event_streams()
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failed.size(), "total": checks}))
	get_tree().quit(0 if failed.is_empty() else 1)


## 合 main dev.092：隐藏 slot 的 setup、出现、变身及公共事件子游标必须共享本场规则流。
func _hidden_event_streams() -> void:
	var s := XState.new_game(3, 1, [])
	s.random_master = "1122334455667788"
	var before := s.to_dict().duplicate(true)
	var logic := XBattleLogic.new()
	logic.setup(824, s)
	var other_state := XState.from_dict(before)
	for i in 64:
		randf()
		randi()
	var other := XBattleLogic.new()
	other.setup(824, other_state)
	check("hidden.setup_same_stream", equal(logic.random.snapshot(), other.random.snapshot()))
	check("hidden.setup_no_world", s._world_random == null and other_state._world_random == null)
	check("hidden.setup_all_slots", logic.enemies.size() == 6)
	for reason in ["enemy_elite", "enemy_level"]:
		check("hidden.draws_" + reason, logic.random.rule.journal.filter(func(e): return e.reason == reason).size() == 6)
	for i in logic.enemies.size():
		var e: XEnemy = logic.enemies[i]
		check("hidden.id:" + str(i), logic.stable_id(e) == "enemy:%d:%d" % [i, e.enemy_id])
		check("hidden.setup_value:" + str(i), [e.elite, e.enemy_level, e.tp, e.hidden] == [other.enemies[i].elite, other.enemies[i].enemy_level, other.enemies[i].tp, other.enemies[i].hidden])
	var ce1 := XDB.rec("CommonEvents", 1)
	var ce2 := XDB.rec("CommonEvents", 2)
	var old1: Array = ce1.list
	var old2: Array = ce2.list
	ce1.list = [{"code": 117, "indent": 0, "parameters": [2]}]
	ce2.list = [
		{"code": 122, "indent": 0, "parameters": [700, 702, 0, 2, 7, 9]},
		{"code": 313, "indent": 0, "parameters": [0, 1, 0, 4]},
		{"code": 333, "indent": 0, "parameters": [0, 0, 4]},
		{"code": 333, "indent": 0, "parameters": [1, 0, 4]},
		{"code": 101, "indent": 0, "parameters": ["", 0, 0, 2]},
		{"code": 401, "indent": 0, "parameters": ["随机流挂起验收"]},
		{"code": 122, "indent": 0, "parameters": [703, 703, 0, 2, 5, 5]},
	]
	logic.turn = 2
	logic.random.rule = XRandomStream.scripted([
		{"kind": "uint32", "value": 7, "reason": "event_variable", "event": "2"},
		{"kind": "uint32", "value": 0, "reason": "state_duration", "event": "4"},
		{"kind": "uint32", "value": 0, "reason": "state_duration", "event": "4"},
		{"kind": "uint32", "value": 0, "reason": "event_variable", "event": "2"},
	])
	var reward_before := logic.random.reward.snapshot()
	var persistent_before := s.random_save()
	var old_fixed := MVEventCore.fixed_random
	MVEventCore.fixed_random = 0.99  # 战斗不能被地图对照的静态固定值覆盖。
	seed(867)
	var expected_global := randi()
	seed(867)
	var runner := XBattleEventRunner.new(logic, [{"code": 117, "indent": 0, "parameters": [1]}])
	var request := runner.advance()
	check("event.nested_message", request.kind == "message" and runner.waiting_frame() != runner)
	check("event.range_once_for_multiple_variables", s.variable(700) == 8 and s.variable(701) == 8 and s.variable(702) == 8)
	check("event.actor_duration", s.actor(1).state_turns.get(4) == 1)
	check("event.enemy_duration", logic.enemies[0].state_turns.get(4) == 1)
	check("event.hidden_state_rejected", not logic.enemies[1].is_state_affected(4))
	check("event.draws_before_wait", logic.random.rule.draws == 3 and logic.random.rule.error.is_empty(), logic.random.rule.journal)
	check("event.wait_does_not_draw", runner.advance().kind == "waiting" and logic.random.rule.draws == 3)
	runner.waiting_frame().resume()
	check("event.nested_resumed", runner.advance().kind == "done" and s.variable(703) == 5)
	check("event.singleton_consumed", logic.random.rule.draws == 4 and logic.random.rule.error.is_empty(), logic.random.rule.error)
	check("event.no_global_consumption", randi() == expected_global)
	check("event.no_reward_or_world", equal(reward_before, logic.random.reward.snapshot()) and equal(persistent_before, s.random_save()))
	MVEventCore.fixed_random = old_fixed
	ce1.list = old1
	ce2.list = old2
	var ids: Array = logic.enemies.map(func(e): return logic.stable_id(e))
	for i in range(1, logic.enemies.size()):
		var e: XEnemy = logic.enemies[i]
		var resources := [e.hp, e.mp, e.tp, e.enemy_level, e.elite, e.state_ids.duplicate(), e.state_turns.duplicate()]
		logic.enemy_appear(i)
		check("hidden.appear_preserves_setup:" + str(i), not e.hidden and resources == [e.hp, e.mp, e.tp, e.enemy_level, e.elite, e.state_ids, e.state_turns] and logic.stable_id(e) == ids[i])
	logic.enemy_transform(1, 175)
	check("hidden.transform_preserves_id", logic.enemies[1].enemy_id == 175 and logic.stable_id(logic.enemies[1]) == ids[1])
	check("hidden.appear_transform_no_draw", logic.random.rule.draws == 4 and logic.random.rule.error.is_empty() and equal(persistent_before, s.random_save()))
	logic.enemy_recover_all(-1)
	check("event.recover_no_extra_draw", logic.random.rule.draws == 4 and logic.random.rule.error.is_empty() and equal(persistent_before, s.random_save()))

	# 336 的资源刷新若新建死亡状态，也只能抽本场 rule（而不是落到 current.world）。
	var death_state := XState.new_game(3, 1, [])
	death_state.random_master = "8877665544332211"
	var death_logic := XBattleLogic.new()
	death_logic.setup(2, death_state)
	death_logic.random.rule = XRandomStream.scripted([
		{"kind": "uint32", "value": 0, "reason": "state_duration", "event": "b:1"},
	])
	var death_persistent := death_state.random_save()
	death_logic.enemies[0].hp = 0.0
	death_logic.enemies[0].state_ids.clear()
	death_logic.enemies[0].state_turns.clear()
	var death_id := death_logic.stable_id(death_logic.enemies[0])
	death_logic.enemy_transform(0, 2)
	check("event.transform_death_duration", death_logic.enemies[0].is_state_affected(1) and death_logic.enemies[0].state_turns.get(1) == 1
		and death_logic.random.rule.draws == 1 and death_logic.random.rule.error.is_empty(), death_logic.random.rule.error)
	check("event.transform_death_no_world", equal(death_persistent, death_state.random_save()) and death_logic.stable_id(death_logic.enemies[0]) == death_id)
	death_logic.enemy_recover_all(0)
	check("event.recover_death_preserves_stream", death_logic.enemies[0].is_alive() and death_logic.random.rule.draws == 1
		and death_logic.random.rule.error.is_empty() and equal(death_persistent, death_state.random_save()))
