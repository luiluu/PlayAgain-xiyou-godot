class_name XBattleRandom
extends RefCounted
## Explicitly passed before enemy setup; each battle owns its two streams.
## pet：宠物捕捉（XPetCapture：开战掷可捕捉、捕捉道具、造宠物）的独立流，同样从本场种子派生，不占 rule／reward 的取数。
var rule: XRandomStream
var reward: XRandomStream
var pet: XRandomStream
var serial := 0
var master_seed := ""

static func create(seed_hex: String, battle_serial := 0) -> XBattleRandom:
	var out := XBattleRandom.new()
	out.serial = battle_serial
	out.master_seed = seed_hex
	out.rule = XRandomStream.create(XRandomStream.derive(seed_hex, "rule"), "rule")
	out.reward = XRandomStream.create(XRandomStream.derive(seed_hex, "reward"), "reward")
	out.pet = XRandomStream.create(XRandomStream.derive(seed_hex, "pet"), "pet")
	return out

func snapshot() -> Dictionary:
	return {"version": 1, "engine": XRandomStream.ENGINE, "serial": serial, "masterSeed": master_seed,
		"rule": rule.snapshot(), "reward": reward.snapshot(), "pet": pet.snapshot()}

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
	# 加 pet 流之前的快照没有这一项：按种子重新派生（未开始捕捉即与新建时相同）
	out.pet = XRandomStream.restore(data.pet) if data.get("pet") is Dictionary else null
	if out.pet == null or out.pet.domain != "pet":
		out.pet = XRandomStream.create(XRandomStream.derive(out.master_seed, "pet"), "pet")
	return out
