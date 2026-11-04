class_name XBattleReplay
extends RefCounted
## Debug artifact only; restores a boundary save and re-executes commands.
const VERSION := 2

static func identity() -> Dictionary:
	var manifest: Dictionary = XDB.load_json("manifest.json")
	return {"schema": VERSION, "rngVersion": XRandomStream.VERSION, "engine": XRandomStream.ENGINE,
		"content": JSON.stringify([manifest.get("inputs", {}), manifest.get("runtimeInputs", {})]).sha256_text(),
		"build": JSON.parse_string(FileAccess.get_file_as_string("res://content/build_info.json"))}

static func valid(data: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(data.get("identity"))) == JSON.parse_string(JSON.stringify(identity())) and data.get("initial") is Dictionary and XSave.valid_data(data.initial) and data.get("initialRuntime") is Dictionary and XState.valid_runtime_random(data.initialRuntime) and data.get("battleStart") is Dictionary and XBattleRandom.restore(data.battleStart) != null and data.get("commands") is Array and data.get("random") is Dictionary and XBattleRandom.restore(data.random) != null

static func freeze(value, logic: XBattleLogic):
	if value is XBattler:
		return {"battler": logic.stable_id(value)}
	if value is Object:
		return {"unsupportedObject": value.get_class()}
	if value is Dictionary:
		var out := {}
		for key in value:
			var frozen = freeze(key, logic)
			out[JSON.stringify(frozen) if key is Object else str(key)] = freeze(value[key], logic)
		return out
	if value is Array:
		return value.map(func(child): return freeze(child, logic))
	return value

static func record(logic: XBattleLogic, initial: Dictionary, commands: Array, logs: Array) -> Dictionary:
	return {"identity": identity(), "initial": initial.duplicate(true), "troop": logic.troop_id,
		"initialRuntime": logic.replay_runtime_start.duplicate(true), "battleStart": logic.replay_battle_start.duplicate(true),
		"finalRuntime": logic.state.runtime_random_snapshot(),
		"rules": {"advanceLootOnCollapse": logic.advance_loot_on_collapse}, "commands": commands.duplicate(true),
		"random": logic.random.snapshot(), "journal": {"rule": logic.random.rule.journal.duplicate(true), "reward": logic.random.reward.journal.duplicate(true)},
		"logs": freeze(logs, logic), "final": freeze(logic.state.to_dict(), logic),
		"enemies": logic.enemies.map(func(e): return [logic.stable_id(e), e.hp, e.mp, e.tp, e.state_ids.duplicate(), e.state_turns.duplicate(true)])}

static func replay(data: Dictionary) -> Dictionary:
	if not valid(data):
		return {"available": false, "diagnostic": "replay_version_or_structure_mismatch"}
	var prior := XState.current
	var prior_zhenqi := XZhenqi.battle.duplicate(true)
	var prior_contexts := [XDungeon.battle, XZhenqi.pending_trial, XZhenqi.trial_done, XZhenqi.pending_scale, XHonghuang.power_battle]
	var state := XState.from_dict(data.initial.duplicate(true))
	state.restore_runtime_random(data.initialRuntime)
	var logic := XBattleLogic.new()
	logic.setup(int(data.troop), state, XBattleRandom.restore(data.battleStart))
	logic.advance_loot_on_collapse = bool(data.rules.advanceLootOnCollapse)
	logic.auto = true
	var logs := []
	var commands := []
	var diagnostic := ""
	for cmd in data.commands:
		if not cmd is Dictionary or not cmd.has_all(["turn", "user", "skill", "target", "automatic"]):
			diagnostic = "invalid_replay_command"
			break
		while logic.turn < int(cmd.turn):
			if logic.turn > 0:
				logs.append_array(logic.end_turn())
			logic.start_turn()
			logs.append_array(logic.take_turn_start_logs())
		var user := logic.next_subject()
		if user == null or logic.stable_id(user) != str(cmd.user):
			diagnostic = "replay_subject_mismatch"
			break
		var chosen: XBattler
		for b in logic.actors + logic.enemies:
			if logic.stable_id(b) == str(cmd.target):
				chosen = b
		var skill := XDB.rec("Items" if cmd.get("kind", "skill") == "item" else "Skills", int(cmd.skill))
		if bool(cmd.automatic):
			var decision := logic.decide(user)
			if (0 if decision[0] == null else int(decision[0].id)) != int(cmd.skill):  # 0：敌人没有可用行动
				diagnostic = "replay_ai_mismatch"
				break
			chosen = decision[1]
		logs.append_array(logic.act(user, skill, chosen))
		commands.append(cmd)
	if diagnostic.is_empty():
		var actual := record(logic, data.initial, commands, logs)
		for key in ["logs", "final", "finalRuntime", "enemies", "random", "journal"]:
			if JSON.parse_string(JSON.stringify(actual[key])) != JSON.parse_string(JSON.stringify(data[key])):
				diagnostic = "replay_result_mismatch:" + key
				break
	XState.current = prior
	XZhenqi.battle = prior_zhenqi
	XDungeon.battle = prior_contexts[0]
	XZhenqi.pending_trial = prior_contexts[1]
	XZhenqi.trial_done = prior_contexts[2]
	XZhenqi.pending_scale = prior_contexts[3]
	XHonghuang.power_battle = prior_contexts[4]
	return {"available": diagnostic.is_empty(), "diagnostic": diagnostic}
