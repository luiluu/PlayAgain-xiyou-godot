class_name XGuardianRework
extends RefCounted
## 守层者按新成长重算（法宝与积分重构方案 v0.3 第三节，O-待定-4）：每层守层者的血量、攻击、伤害抵抗。
## 现在只有量数用的接口（tests/virtual_player/baseline_dps.tscn）；每层的表量好、Kyo 看过后再填。

## 每层守层者那场的敌群号（地图事件里「战斗后变量 20 加一」的那一场；5 层取群狼森林、7 层取科维努斯镇）
const TROOPS := {1: 4, 2: 5, 3: 8, 4: 22, 5: 28, 6: 39, 7: 52, 8: 53, 9: 67, 10: 69, 11: 109, 12: 110, 13: 111, 14: 118, 15: 138,
	16: 172, 17: 173, 18: 174, 19: 333, 20: 456, 21: 457, 22: 458, 23: 459, 24: 460, 25: 461, 26: 462, 27: 463, 28: 464, 29: 465,
	30: 466, 31: 467, 32: 468, 33: 469}

## 工具用：≥0 时守层者的伤害抵抗（技能备注 passiveHarmRe，20 层起 200 万～50 兆）一律换成这个值；-1 不动
static var measure_resist := -1.0

## 工具用：为真时我方打守层者一律按元素中性（抗性 1，不吸收、不免疫），量「不挑元素」的基准伤害
static var measure_neutral := false

static var _floor_of := {}


## 敌人号是哪一层的守层者（不是返回 0）
static func floor_of(enemy_id: int) -> int:
	if _floor_of.is_empty():
		for f in TROOPS:
			var t := XDB.rec("Troops", int(TROOPS[f]))
			for m in t.get("members", []):
				var id := int(m.get("enemyId", 0))
				if id > 0 and not _floor_of.has(id) and str(XDB.rec("Enemies", id).get("name", "")).contains("守层者"):
					_floor_of[id] = int(f)
	return int(_floor_of.get(enemy_id, 0))


## XEnemy.refresh_passive 末尾调：守层者的元素固定减伤
static func harm_re(e: XEnemy, table: Dictionary) -> Dictionary:
	if measure_resist < 0.0 or floor_of(e.enemy_id) == 0:
		return table
	var out := {}
	for k in table:
		out[k] = measure_resist
	return out


static func neutral(b: XBattler) -> bool:
	return measure_neutral and b is XEnemy and floor_of((b as XEnemy).enemy_id) > 0
