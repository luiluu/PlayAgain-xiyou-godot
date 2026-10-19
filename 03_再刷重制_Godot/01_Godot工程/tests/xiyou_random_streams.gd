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
	var outside := XBattleLogic.new()
	outside.state = loaded
	var serial_before := loaded.battle_serial
	var user := loaded.actor(1)
	user.hp = maxf(1.0, user.hp - 1.0)
	outside._effect(user, user, {"code": 11, "value1": 0.0, "value2": 1.0, "dataId": 0}, {"skill": XDB.rec("Items", 1), "hp": 0.0, "mp": 0.0, "added": [], "removed": []})
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
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failed.size(), "total": checks}))
	get_tree().quit(0 if failed.is_empty() else 1)
