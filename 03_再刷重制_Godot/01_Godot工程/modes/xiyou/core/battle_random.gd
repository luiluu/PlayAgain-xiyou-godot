class_name XBattleRandom
extends RefCounted
## Explicitly passed before enemy setup; each battle owns its two streams.
## pet：宠物捕捉（XPetCapture：开战掷可捕捉、捕捉道具、造宠物）的独立流，同样从本场种子派生，不占 rule／reward 的取数。
var rule: XRandomStream
var reward: XRandomStream
var pet: XRandomStream
var serial := 0
var master_seed := ""
## 天启篇战斗键钉住（XTianqiRandom.battle_random，R3；西游档、测试自建的流都不钉，以下全空，行为与原来逐字节相同）：
## pin_seed＝存档种子＋战斗键（敌群号｜本档打这个敌群的第几次）派生；setup＝开战布阵阶段的取数（BattleLogic.setup 整段），
## 奖励按键分子流（reward_for），各子流只看「本场＋键」，谁先倒下、倒了几个都不串号。rule／pet 照旧运行时（回合内读档可变）。
var battle_key := ""
var pin_seed := ""
var setup: XRandomStream = null
## 当前取数阶段（BattleLogic._rule 经 rule_now 取）：""＝回合内（rule）；"setup"＝布阵；其余＝结算段，取 reward_for(phase)
var phase := ""
var _subs := {}

static func create(seed_hex: String, battle_serial := 0) -> XBattleRandom:
	var out := XBattleRandom.new()
	out.serial = battle_serial
	out.master_seed = seed_hex
	out.rule = XRandomStream.create(XRandomStream.derive(seed_hex, "rule"), "rule")
	out.reward = XRandomStream.create(XRandomStream.derive(seed_hex, "reward"), "reward")
	out.pet = XRandomStream.create(XRandomStream.derive(seed_hex, "pet"), "pet")
	return out

## 钉到战斗键上（只由 XTianqiRandom.battle_random 调）
func pin(key: String, seed_hex: String) -> void:
	battle_key = key
	pin_seed = seed_hex
	setup = XRandomStream.create(XRandomStream.derive(seed_hex, "setup"), "setup")
	_subs.clear()


func pinned() -> bool:
	return pin_seed != ""


## 结算取数：钉住时按 key 现开（并缓存）一条 derive(pin_seed, "reward|" + key)；没钉住时就是原来那一条 reward
func reward_for(key: String) -> XRandomStream:
	if not pinned():
		return reward
	if not _subs.has(key):
		_subs[key] = XRandomStream.create(XRandomStream.derive(pin_seed, "reward|" + key), "reward")
	return _subs[key]


## BattleLogic._rule 的取数口：没钉住或回合内是 rule；钉住时布阵阶段取 setup，结算段取该段的奖励子流
func rule_now() -> XRandomStream:
	if not pinned() or phase == "":
		return rule
	if phase == "setup":
		return setup
	return reward_for(phase)


## 各子流的取数记录（回放比对用）
func sub_journals() -> Dictionary:
	var out := {}
	for k in _subs:
		out[k] = (_subs[k] as XRandomStream).journal.duplicate(true)
	return out


func snapshot() -> Dictionary:
	var out := {"version": 1, "engine": XRandomStream.ENGINE, "serial": serial, "masterSeed": master_seed,
		"rule": rule.snapshot(), "reward": reward.snapshot(), "pet": pet.snapshot()}
	if pinned():  # 西游档、没钉住的不加键，快照与原来逐字节相同
		var subs := {}
		for k in _subs:
			subs[k] = (_subs[k] as XRandomStream).snapshot()
		out["battleKey"] = battle_key
		out["pinSeed"] = pin_seed
		out["setup"] = setup.snapshot()
		out["subs"] = subs
	return out

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
	if data.has("pinSeed"):  # 天启篇钉住的本场：种子、布阵流、各奖励子流（回放才能重放子流）
		if not XRandomStream.valid_hex(data.get("pinSeed")) or not data.get("setup") is Dictionary or not data.get("subs", {}) is Dictionary:
			return null
		out.battle_key = str(data.get("battleKey", ""))
		out.pin_seed = str(data.pinSeed)
		out.setup = XRandomStream.restore(data.setup)
		if out.setup == null or out.setup.domain != "setup":
			return null
		for k in data.get("subs", {}):
			var st := XRandomStream.restore(data.subs[k]) if data.subs[k] is Dictionary else null
			if st == null or st.domain != "reward":
				return null
			out._subs[str(k)] = st
	return out
