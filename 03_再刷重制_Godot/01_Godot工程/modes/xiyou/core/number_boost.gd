class_name XNumberBoost
extends RefCounted
## 米拉／渡鸦共用的数值池（正式 js/codex/runtime/installMiraRavenNumberBoostRuntime.js）第一期：面板暴击与伤害钩子。
## - 归属 owner：行动者是 168 且技能在米拉攻击表、或 167 且技能在渡鸦攻击表，目标是敌人、技能伤害类型 1。
## - 面板暴击（Game_Actor.xparam(2) 包装）：168 在 5 级起学了 10156 时加 lv≤15 ? 0.15＋0.08×(lv−5) : 0.95＋7.93×min(1,(lv−15)/55)；
##   167 学了 10137 时加 10×灵魂进度。
## - 伤害钩子 native-number-pools（XActorDamageHooks）：168 在 40 级起学了 10145 暴伤＋9.99、30 级起学了 10144 终伤 ×7.66、
##   70 级起进阶 3 次且学了 10164 结算 ×2；167 在 25 级起学了 10132 结算 ×1.15、60 级起阶位 5 且学了 10136 结算 ×4.25。
## 二期（命中三件，XBattleLogic.item_hit／item_eva／item_cri 调这里，参照 mv_oracle/mira_raven_hit_probe）：
## - 归属技能 itemHit 1、itemEva 0（只去掉闪避与未命中，物理／魔法类型和能否暴击照旧）；
## - 归属且可暴击时 itemCri 夹在 0～1（外层 DamageElement 本来也夹，这里不另做）；
## - 渡鸦 167 的动作不归属（普攻、非专属技能、目标不是敌人）时，itemCri 内层读面板暴击不带 +10×灵魂进度（suppress_raven），面板照实显示。
## 原版 makeDamageValue／applyCriticalRate 包装在 CodexDamage 结算下由上述伤害钩子代替，不另做。

const MIRA_ATTACKS := [10140, 10141, 10142, 10143, 10146, 10147, 10148, 10149, 10150, 10151]
const RAVEN_ATTACKS := [10122, 10123, 10124, 10125, 10126]

## itemCri 包装期间为真：渡鸦这次动作不借魂海暴击（原版 suppressRavenPanelCrit）
static var suppress_raven := false


static func owner(item: Dictionary, a, b) -> int:
	if not a is XActor or b == null or b.is_actor() or XBattleLogic.is_item(item) or int(item.get("damage", {}).get("type", 0)) != 1:
		return 0
	var id := int(item.get("id", 0))
	if int(a.actor_id) == 168 and MIRA_ATTACKS.has(id):
		return 168
	if int(a.actor_id) == 167 and RAVEN_ATTACKS.has(id):
		return 167
	return 0


static func xparam(a, i: int, v: float) -> float:
	if i != 2 or not a is XActor:
		return v
	var lv := int(a.level)
	if int(a.actor_id) == 168 and lv >= 5 and a.skill_ids.has(10156):
		return v + (0.15 + 0.08 * (lv - 5) if lv <= 15 else 0.95 + 7.93 * minf(1.0, (lv - 15) / 55.0))
	if int(a.actor_id) == 167 and not suppress_raven and a.skill_ids.has(10137):
		return v + 10 * XRaven.progress(a)
	return v


## itemCri 包装：渡鸦的非归属动作在 calc 期间压住魂海暴击（calc 是内层 itemCri）
static func item_cri(item: Dictionary, a, b, calc: Callable) -> float:
	var suppress := a is XActor and int(a.actor_id) == 167 and owner(item, a, b) != 167
	var before := suppress_raven
	if suppress:
		suppress_raven = true
	var rate: float = calc.call()
	suppress_raven = before
	return rate


static func damage_ops(item: Dictionary, a, b) -> Array:
	var who := owner(item, a, b)
	var lv := int(a.level) if a is XActor else 0
	var ops := []
	if who == 168:
		if lv >= 40 and a.skill_ids.has(10145):
			ops.append({"op": "add", "field": "criticalAdd", "value": 9.99})
		if lv >= 30 and a.skill_ids.has(10144):
			ops.append({"op": "mul", "field": "finalMultiplier", "value": 7.66})
		if lv >= 70 and XMira.rank(a) >= 3 and a.skill_ids.has(10164):
			ops.append({"op": "mul", "field": "settlementMultiplier", "value": 2.0})
	elif who == 167:
		if lv >= 25 and a.skill_ids.has(10132):
			ops.append({"op": "mul", "field": "settlementMultiplier", "value": 1.15})
		if lv >= 60 and XRaven.stage(a) >= 5 and a.skill_ids.has(10136):
			ops.append({"op": "mul", "field": "settlementMultiplier", "value": 4.25})
	return ops
