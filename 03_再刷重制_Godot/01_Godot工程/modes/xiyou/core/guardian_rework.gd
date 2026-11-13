class_name XGuardianRework
extends RefCounted
## 守层者按新成长重算（法宝与积分重构方案 v0.3 第三节、三之二节，O-待定-4）。只管天启篇存档（现在的新开局；原版档照旧）。
## - ATK：守层者对我方的最终 HP 伤害乘 ATK_SCALE[层]（XEnemy.output_scale）。按基准队（弱者 4 人、等级与法宝按层上限、
##   精良以下装备）实测反推：守层者每回合打掉基准队合计生命的 1/6.4，即不治疗约 8 回合团灭。1～4 层原版就几乎不打人，不放大（取 1）。
## - RESIST：19 层起守层者自带的「伤害抵抗」（技能备注 passiveHarmRe，原版 5000～50 兆，24 层起把基准队每一下都扣成 0）
##   换成 RESIST_TABLE[层]，约等于基准队单下伤害中位数的 30%。
## - 血量：等 Kyo 定基准队口径（v0.3 第 5 条）后再加。
## 回退：`XGuardianRework.ATK = false`；`XGuardianRework.RESIST = false`。
## 量数接口（tests/virtual_player/baseline_dps.tscn）：measure_resist、measure_neutral。

static var ATK := true
static var RESIST := true

const ATK_SCALE := {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 0.00884, 6: 3.07, 7: 1.29, 8: 1.9, 9: 0.589, 10: 1.09, 11: 0.952,
	12: 0.511, 13: 0.946, 14: 0.0151, 15: 0.284, 16: 0.439, 17: 0.115, 18: 0.634, 19: 0.33, 20: 0.074, 21: 0.0303, 22: 0.0585,
	23: 0.0903, 24: 0.0243, 25: 0.0164, 26: 0.00149, 27: 0.0107, 28: 0.00191, 29: 0.00521, 30: 0.00417, 31: 0.00121,
	32: 0.000161, 33: 0.0000256}
const RESIST_TABLE := {19: 4500, 20: 4900, 21: 5500, 22: 6000, 23: 6700, 24: 7300, 25: 8100, 26: 8900, 27: 9900, 28: 10900,
	29: 12000, 30: 13300, 31: 14600, 32: 16200, 33: 17800}

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
	var f := floor_of(e.enemy_id)
	if f == 0 or table.is_empty():
		return table
	var v := measure_resist
	if v < 0.0:
		if not RESIST or not RESIST_TABLE.has(f) or not _on():
			return table
		v = float(RESIST_TABLE[f])
	var out := {}
	for k in table:
		out[k] = v
	return out


## XEnemy.setup 末尾调：守层者的出伤倍率（不是守层者、没开、不是天启篇存档为 1）
static func atk_scale(e: XEnemy) -> float:
	var f := floor_of(e.enemy_id)
	if f == 0 or not ATK or not _on():
		return 1.0
	return float(ATK_SCALE.get(f, 1.0))


static func _on() -> bool:
	return XState.current != null and XTianqi.active(XState.current)


static func neutral(b: XBattler) -> bool:
	return measure_neutral and b is XEnemy and floor_of((b as XEnemy).enemy_id) > 0
