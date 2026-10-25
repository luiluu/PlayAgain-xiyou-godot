class_name XRaven
extends RefCounted
## 167 渡鸦（正式 js/codex/runtime/installNativeRavenRuntime.js，W.CodexRaven）第一期：招募、开机数据、技能解锁、公式、被动、伤害钩子。
## - 阶位 stage＝原版 _codexRavenStage（取 _AdvancedNum 与它的较大者，进阶时两者同步），重制读 XAdvance.rank，夹在 0～5。
## - 开机数据（isDatabaseLoaded 的 finishRavenDatabaseCompatibility）：给原版角色进阶表补渡鸦 0～4 次的 5 行（需求等级 15／25／35／45／45、
##   冥羽进阶印 2901×1，学 10131／10132／10133／10134／[10127,10170]），由转换器 boot_database_records 写进 Plugins.json。
## - 技能解锁 SKILL_GATE（技能 → [等级, 阶位]）：setup 与每次升级后（setupRaven）按职业习得表重排——到级且到阶的职业技能补学，
##   渡鸦专属技能 10122～10139 与 10170 未解锁的忘掉；职业一的旧技能 160／311／502／1746 与 10168 也去掉。
## - 公式（5 个伤害技能整条公式）：(魔攻×k1＋MP 上限×k2)×legionStrikeRate×skillCoefficient；黑翼裁决按目标失血加成。
##   legionStrikeRate：学了 10138「魄」时 [6,10,20,33,66,99][阶]/11，否则 1；skillCoefficient 按阶位查表。
## - 被动（initPassiveCache 包装）：学了 10137 时暴伤池、终伤池按等级插值（1／10／25／40／55／70 级）加进 critHarmRi／globalHarmRi（÷100）。
## - 面板暴击（NumberBoost 的 xparam 包装，学了 10137）：+10×灵魂进度；伤害钩子 raven 见 XActorDamageHooks。
## - 灵魂值 soul：第一期不积累（恒 0），进度、冥河冠冕溢出、法宝魂力加成都按 0 算。
## - 招募（公共事件 9002 的 CodexRaven.recruit()）：不在队就入队；重排技能；队伍（含已装备）没有冥河断罪镰 4001 才给一件；
##   提示「渡鸦加入队伍，获得专属法宝：冥河断罪镰！」。总是返回 true。
## 未移植（第二期起）：灵魂积累与铸印、进阶界面的渡鸦分支、神话形态、残响／三羽成环／收割与回响追加伤害、numRepeats（冥羽连葬吃再动）、
## 法宝 4001 的运行时法宝字段（每级成长、等级上限）与 paramPlus 固定加成、熟练度上限、技能分类与界面、敌人掉率与图鉴、
## 插件指令 RavenAdd、商店价格字段、表现模块（RavenSkillEffects／RavenMonsterVisual）、旧档迁移。

const ACTOR := 167
const CLASS := 165
const ARTIFACT := 4001
const HORN := 2902
const LEGION := 10138
const SOUL_LEDGER := 10137
const SKILL_GATE := {10129: [5, 0], 10130: [10, 0], 10131: [15, 0], 10123: [20, 1], 10132: [25, 0], 10124: [30, 2],
	10133: [35, 3], 10125: [40, 3], 10134: [45, 0], 10126: [50, 4], 10138: [1, 0], 10139: [55, 3],
	10127: [1, 5], 10136: [60, 5], 10170: [1, 5]}
const SKILL_COEFFICIENTS := {10122: [9, 6.9, 3.9, 2.0, 1.3, 1], 10123: [0, 6.9, 3.9, 2.0, 1.3, 1],
	10124: [0, 0, 0.39, 0.19, 0.13, 0.1], 10125: [0, 0, 0, 0.6, 0.39, 0.33], 10126: [0, 0, 0, 0, 0.19, 0.2]}
const LEGACY := [160, 311, 502, 1746]
const GROWTH := {10: 16, 15: 35, 20: 50, 25: 33, 30: 27, 35: 191, 40: 22, 45: 6, 50: 7, 55: 3, 60: 1.2, 65: 1, 70: 2.66, 75: 2.66, 80: 2.66}
const REQUIRE := [0, 3000, 12000, 35000, 80000, 150000]
const RECRUIT_TEXT := "渡鸦加入队伍，获得专属法宝：冥河断罪镰！"


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func stage(a) -> int:
	return clampi(XAdvance.rank(XState.current, ACTOR), 0, 5) if own(a) else 0


static func soul(_a) -> float:
	return 0.0


static func progress(a) -> float:
	return clampf(soul(a) / REQUIRE[5], 0.0, 1.0)


static func unlocked(a, skill: int) -> bool:
	var gate = SKILL_GATE.get(skill)
	return gate == null or own(a) and int(a.level) >= gate[0] and stage(a) >= gate[1]


static func has(a, skill: int) -> bool:
	return unlocked(a, skill) and own(a) and a.skill_ids.has(skill)


## setupRaven（setup、levelUp 后）
static func sync(a) -> void:
	if not own(a):
		return
	for id in LEGACY + [10168]:
		a.forget_skill(id)
	var all := []
	for l in XDB.rec("Classes", CLASS).get("learnings", []):
		if int(l.get("level", 1)) <= int(a.level) and unlocked(a, int(l.skillId)):
			all.append(int(l.skillId))
	for id in a.skill_ids.duplicate():
		if (id == 10170 or (id >= 10122 and id <= 10139)) and not all.has(id):
			a.forget_skill(id)
	for id in all:
		a.learn_skill(id)
	a.refresh_passive()


static func setup(a) -> void:
	sync(a)


static func level_up(a) -> void:
	sync(a)


## 暴伤池、终伤池（百分数）
static func growth_pools(a) -> Array:
	var lv := clampi(int(a.level), 1, 70)
	var knots := [[1, 0, 0], [10, 20, 15], [25, 80, 60], [40, 180, 140], [55, 300, 240], [70, 500, 399]]
	for i in range(1, knots.size()):
		if lv <= knots[i][0]:
			var p: float = float(lv - knots[i - 1][0]) / (knots[i][0] - knots[i - 1][0])
			return [knots[i - 1][1] + p * (knots[i][1] - knots[i - 1][1]), knots[i - 1][2] + p * (knots[i][2] - knots[i - 1][2])]
	return [500.0, 399.0]


## initPassiveCache 包装
static func passive_cache(a, c: Dictionary) -> void:
	if own(a) and a.skill_ids.has(SOUL_LEDGER):
		var p := growth_pools(a)
		c.critHarmRi += p[0] / 100.0
		c.globalHarmRi += p[1] / 100.0


static func legion_rate(a) -> float:
	if not own(a) or not has(a, LEGION):
		return 1.0
	return [6, 10, 20, 33, 66, 99][stage(a)] / 11.0


static func skill_coefficient(a, id: int) -> float:
	if not own(a):
		return 1.0
	var rates = SKILL_COEFFICIENTS.get(id)
	return float(rates[stage(a)]) if rates != null else 1.0


## 5 个伤害技能的整条公式
static func formula(a, b, item: Dictionary) -> float:
	var id := int(item.get("id", 0))
	var base := 0.0
	match id:
		10122, 10123: base = a.mat * 78 + a.mmp * 39
		10124: base = a.mat * 798 + a.mmp * 399
		10125: base = a.mat * (3999 + 3999 * (1 - b.hp_rate()))
		10126: base = a.mat * 33333 + a.mmp * 3333
	return base * (legion_rate(a) * skill_coefficient(a, id))


static func crown_rate(a) -> float:
	if not own(a) or not has(a, 10139):
		return 1.0
	var base: float = [1, 1, 1, 1.5, 1.5, 2][stage(a)]
	var overflow := maxf(0.0, soul(a) - REQUIRE[5])
	return base * (1 + 0.06 * log(1 + overflow / REQUIRE[5]) / log(2.0)) if stage(a) >= 5 and has(a, 10136) else base


static func defense_factor(a) -> float:
	if not own(a) or not has(a, 10130):
		return 1.0
	return 1.0 - minf(0.90, 0.60 + 0.30 * progress(a))


static func growth_rate(a) -> float:
	if not own(a):
		return 1.0
	# 不到 10 级也按 10 级那档（原版从最小的键起步，再取不超过等级的最大键）
	var best := 10
	for k in GROWTH.keys():
		if int(a.level) >= k:
			best = maxi(best, k)
	return float(GROWTH[best])


static func artifact_equipped(a) -> bool:
	return own(a) and a.equip_list().any(func(e): return int(e.get("base", e.get("id", 0))) == ARTIFACT and str(e.get("kind", "")) == "armor")


## 伤害钩子 raven 的帧操作（XActorDamageHooks 在宿主侧取值）
static func damage_ops(item: Dictionary, a) -> Array:
	if not own(a) or not item.get("meta", {}).has("CodexRavenDamage"):
		return []
	var p := progress(a)
	var tempered := has(a, 10131)
	var ops := [{"op": "set", "field": "mode", "value": "magical"},
		{"op": "mul", "field": "magicalDefenseRate", "value": defense_factor(a)}]
	if int(item.get("damage", {}).get("elementId", 0)) == 9:
		ops.append({"op": "add", "field": "elementAdd", "element": 9, "value": (2 + p) if tempered else 0.0})
	else:
		ops.append({"op": "add", "field": "normalAdd", "value": (1.5 + p) if tempered else 0.0})
	ops.append({"op": "add", "field": "finalAdd", "value": 1.5 * minf(1.0, (stage(a) + p) / 5.0) if tempered else 0.0})
	if has(a, 10136):
		ops.append({"op": "mul", "field": "finalMultiplier", "value": 1.1})
	ops.append({"op": "mul", "field": "skillMultiplier", "value": 1.6 if artifact_equipped(a) else 1.0})
	ops.append({"op": "mul", "field": "settlementMultiplier", "value": crown_rate(a) * growth_rate(a)})
	return ops


## CodexRaven.recruit()
static func recruit(s: XState) -> bool:
	if not s.party.has(ACTOR):
		s.add_actor(ACTOR)
	var a := s.actor(ACTOR)
	sync(a)
	var held := s.gear.any(func(e): return e.kind == "armor" and int(e.base) == ARTIFACT)
	for id in s.party:
		held = held or s.actor(id).has_base_equip("armor", ARTIFACT)
	if not held:
		s.gain_gear("armor", ARTIFACT, 1)
	return true
