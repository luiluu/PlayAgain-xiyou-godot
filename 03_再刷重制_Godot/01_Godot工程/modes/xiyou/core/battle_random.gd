class_name XBattleRandom
extends RefCounted
## Explicitly passed before enemy setup; each battle owns its two streams.
var rule: XRandomStream
var reward: XRandomStream
var serial := 0
var master_seed := ""

static func create(seed_hex: String, battle_serial := 0) -> XBattleRandom:
	var out := XBattleRandom.new()
	out.serial = battle_serial
	out.master_seed = seed_hex
	out.rule = XRandomStream.create(XRandomStream.derive(seed_hex, "rule"), "rule")
	out.reward = XRandomStream.create(XRandomStream.derive(seed_hex, "reward"), "reward")
	return out

func snapshot() -> Dictionary:
	return {"version": 1, "engine": XRandomStream.ENGINE, "serial": serial, "masterSeed": master_seed,
		"rule": rule.snapshot(), "reward": reward.snapshot()}

static func restore(data: Dictionary) -> XBattleRandom:
	if int(data.get("version", 0)) != 1 or data.get("engine") != XRandomStream.ENGINE:
		return null
	var out := XBattleRandom.new()
	out.rule = XRandomStream.restore(data.get("rule", {}))
	out.reward = XRandomStream.restore(data.get("reward", {}))
	if out.rule == null or out.reward == null or out.rule.domain != "rule" or out.reward.domain != "reward":
		return null
	out.serial = int(data.get("serial", 0))
	out.master_seed = str(data.get("masterSeed", ""))
	return out
