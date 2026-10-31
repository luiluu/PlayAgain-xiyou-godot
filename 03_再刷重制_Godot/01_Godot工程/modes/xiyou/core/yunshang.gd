class_name XYunshang
extends RefCounted
## 【cc·白龙_9·未经审查】174 云裳（正式 js/codex/runtime/installNativeYunshangRuntime.js，W.CodexYunshang）第一期：招募、技能同步、
## 能力值、被动缓存、公式、伤害钩子，以及只看云裳本人的战斗包装（必中、暴击、段数、目标、能不能用）。行号是该文件的。
## - 进阶次数 stage＝原版 a._AdvancedNum（XAdvance.rank）。unlocked(id)：配置 gates[id]＝[等级, 进阶]，没有就算解锁（第 43 行）。
## - 同步 Y.sync（第 51～56 行，包在 setup、levelUp、changeLevel 之后）：gates 里 10270～10281 与天衣铺 10287 解锁就学、没解锁就忘；
##   10282～10286（山河击、换锦、赠行、收存余光、符针结算）是天衣给的技能，不在这里学。
## - 能力值（第 57～70 行，Game_Actor.param 整个换掉、调旧链）：最大生命／魔攻／敏捷按等级与进阶 ×1.5（25 级）／2（30）／2.5（35 且进阶≥1）／
##   3（40 且≥1）／4（50 且≥2），取整、夹 [下限, 上限]。战斗内的六衡裁身、万法同裳、借来的能力、御风敏捷 ×1.33 是第二期。
## - 被动缓存（第 267～274 行，refreshPassiveCache 包装）：学了云丝展幅 10276 时 n＝min(99,等级)−24（≥0），暴伤 +1.88n、终伤 +0.1888n；
##   戴织神天梭 7935 另加终伤 3。
## - 公式 CodexYunshang.formula(this,a,b)（第 275～283 行）：pin 66.66、cut 111.88 ×max(0,魔攻−防×0.1)，gather 246.21×max(0,魔攻−防×0.05)×觉醒回合数，
##   山河击 888.88×max(0,物防＋魔防−防×0.1)，符针 33.33×max(0,魔攻−防×0.1)；防在 CodexDamage 计算中为 0，计算外取目标魔防（物理路线取物防，第二期）。
##   觉醒回合数（_yunGatherRounds）、符针记下的魔攻、_yunRaw 都来自第二期的觉醒与派生伤害，第一期为 0／本人魔攻／无。
## - 伤害钩子 yunshang 的 build（第 765～773 行）：云裳的伤害行动（伤害类型 1／2／5／6）定魔法；学了双针并行 10277 技能倍率 ×0.555；
##   学了云丝展幅且单体行动、目标不是 _yunPrimary 时 ×0.77（银针织阵 10278）／0.66（双针）／0.5——_yunPrimary 只在战力估算里设，
##   实战从不设，所以主目标也吃这一档（原版线上行为，照原版）；戴织神天梭时技能结算 ×1.99。split／enter、六衡与万法同裳的 categoryMax、
##   符针与灯的倍率是第二期。原版 makeDamageValue 整个换掉的那层（第 309～329 行）被后装的 installDamageElementRuntime 整个换掉、不调旧链，
##   不生效，同黄泉／宿傩不移植（山河击取暴伤／终伤下限那段也在里面）。
## - 战斗（第 252～265 行）：云裳的伤害技能 itemHit 1、itemEva 0；戴织神天梭时会暴击的行动暴击率 +3（夹到 1）；学了双针并行时伤害行动段数 ×2；
##   学了云丝展幅时单体对敌伤害行动打主目标再打其余活着的敌人（每个按段数重复）；能不能用：没解锁的不能用，敕衣点神 10273 要有活着的出战成员穿天衣，
##   收针 10274 要有人觉醒（觉醒是第二期，第一期一直不能用）。
## - 招募 Y.recruit（第 206 行）：入队、同步；本档第一次招募时背包得一件织神天梭（只进背包，不装）；提示「云裳已加入队伍」。
##   原版进阶次数取订单账本（独立文件，天衣铺进阶才会变），重制进阶次数本来就在存档里，不另设；账本、订单、天衣铺是养成期。
## 第二期：觉醒、赊账、幽灵、借技能、赠行／储行、拆段、符针、御风、天衣各件的战斗效果、自动战斗。
const ACTOR := 174
const RELIC := 7935
const ROBE_FIRST := 7920
const ROBE_END := 7935  # 不含
const PIN := 10270
const CUT := 10271
const WAKE := 10273
const GATHER := 10274
const SPREAD := 10276
const DOUBLE := 10277
const SILVER := 10278
const MOUNTAIN := 10282
const NEEDLE := 10286
const SHOP := 10287
const RECRUIT_TEXT := "云裳已加入队伍"
const RECRUITED_FLAG := "_codexYunshangRecruited"
const GATES := {10270: [1, 0], 10271: [10, 0], 10272: [20, 0], 10273: [35, 1], 10274: [50, 2], 10275: [35, 1], 10276: [25, 0], 10277: [30, 0],
	10278: [35, 1], 10279: [40, 1], 10280: [45, 1], 10281: [55, 2], 10282: [1, 0], 10283: [1, 0], 10284: [1, 0], 10285: [1, 0], 10286: [1, 0], 10287: [20, 0]}
const COEFFICIENTS := {PIN: 66.66, CUT: 111.88, GATHER: 246.21, NEEDLE: 33.33, MOUNTAIN: 888.88}


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func stage(a) -> int:
	return XAdvance.rank(XState.current, ACTOR) if own(a) else 0


static func unlocked(a, id: int) -> bool:
	var g = GATES.get(id)
	return g == null or int(a.level) >= int(g[0]) and stage(a) >= int(g[1])


static func knows(a, id: int) -> bool:
	return a != null and a.skill_ids.has(id)


## robe(a)：身上第一件天衣（本体 7920～7934），没有为空
static func robe(a) -> Dictionary:
	if not a is XActor:
		return {}
	for e in a.equip_list():
		var b := int(e.get("base", e.get("id", 0)))
		if b >= ROBE_FIRST and b < ROBE_END:
			return e
	return {}


static func key(a) -> int:
	var r := robe(a)
	return int(r.get("base", r.get("id", 0))) - ROBE_FIRST if not r.is_empty() else -1


static func relic(a) -> bool:
	return own(a) and a.has_base_equip("armor", RELIC)


## 伤害行动（damageAction）：伤害类型 1／2／5／6；派生伤害（第二期）不算
static func damage_action(item: Dictionary) -> bool:
	return int(item.get("damage", {}).get("type", 0)) in [1, 2, 5, 6]


static func for_one(item: Dictionary) -> bool:
	return int(item.get("scope", 0)) in [1, 3, 7, 9, 11]


static func sync(a) -> void:
	if not own(a):
		return
	for id in GATES:
		if id >= MOUNTAIN and id != SHOP:
			continue
		if unlocked(a, id):
			a.learn_skill(id)
		else:
			a.forget_skill(id)
	a.refresh_passive()


static func param(a, i: int, v: float) -> float:
	if not own(a):
		return v
	if i in [0, 4, 6]:
		var lv := int(a.level)
		var st := stage(a)
		var m := 1.0
		if lv >= 25: m = 1.5
		if lv >= 30: m = 2.0
		if lv >= 35 and st >= 1: m = 2.5
		if lv >= 40 and st >= 1: m = 3.0
		if lv >= 50 and st >= 2: m = 4.0
		v *= m
	return XPower.js_round(maxf(a.param_min(i), minf(a.param_max(i), v)))


static func passive_cache(a, c: Dictionary) -> void:
	if not own(a):
		return
	var n := maxi(0, mini(99, int(a.level)) - 24) if knows(a, SPREAD) else 0
	c.critHarmRi += n * 1.88
	c.globalHarmRi += n * 0.1888 + (3.0 if relic(a) else 0.0)


## CodexYunshang.formula(this,a,b)；calculating＝CodexDamage.isCalculating()（伤害计算里防为 0）
static func formula(a, b, item: Dictionary, calculating := true) -> float:
	var id := int(item.get("id", 0))
	var defense := 0.0 if calculating else float(b.mdf)
	var v := 0.0
	match id:
		PIN, CUT, NEEDLE:
			v = COEFFICIENTS[id] * maxf(0.0, a.mat - defense * 0.1)
		GATHER:
			v = COEFFICIENTS[id] * maxf(0.0, a.mat - defense * 0.05) * gather_rounds
		MOUNTAIN:
			v = COEFFICIENTS[id] * maxf(0.0, a.def + a.mdf - defense * 0.1)
	return maxf(0.0, v)

## 收针的觉醒回合数（action._yunGatherRounds，第二期的觉醒才给；第一期恒 0）
static var gather_rounds := 0


static func damage_ops(item: Dictionary, a) -> Array:
	var ops := []
	if own(a) and damage_action(item):
		ops.append({"op": "set", "field": "mode", "value": "magical"})
		if knows(a, DOUBLE):
			ops.append({"op": "mul", "field": "skillMultiplier", "value": 0.555})
		if knows(a, SPREAD) and for_one(item):
			ops.append({"op": "mul", "field": "skillMultiplier", "value": 0.77 if knows(a, SILVER) else (0.66 if knows(a, DOUBLE) else 0.5)})
	if relic(a) and not XBattleLogic.is_item(item) and int(item.get("damage", {}).get("type", 0)) > 0:
		ops.append({"op": "mul", "field": "settlementMultiplier", "value": 1.99})
	return ops


## itemHit 1／itemEva 0：云裳的伤害技能
static func sure(u, skill: Dictionary) -> bool:
	return own(u) and not XBattleLogic.is_item(skill) and int(skill.get("damage", {}).get("type", 0)) > 0


## itemCri 包装：戴织神天梭、行动会暴击时 +3（夹 0～1）
static func cri(u, skill: Dictionary, n: float) -> float:
	return clampf(n + 3.0, 0.0, 1.0) if relic(u) and bool(skill.get("damage", {}).get("critical", false)) else n


## numRepeats 包装：学了双针并行的伤害行动 ×2
static func repeats(u, skill: Dictionary, n: int) -> int:
	return n * 2 if own(u) and knows(u, DOUBLE) and damage_action(skill) else n


## makeTargets 包装：学了云丝展幅的单体对敌伤害行动＝[主目标]＋其余活着的敌人（没有主目标就是全部活着的敌人）
static func targets(logic, u, skill: Dictionary, list: Array) -> Array:
	if not (own(u) and knows(u, SPREAD) and int(skill.get("scope", 0)) in [1, 3] and damage_action(skill)):
		return list
	var foes: Array = logic.alive(logic.enemies)
	if list.is_empty():
		return foes
	return [list[0]] + foes.filter(func(x): return x != list[0])


## meetsSkillConditions 包装：没解锁的不能用；敕衣点神要有活着的出战成员穿天衣；收针要有人觉醒（第二期，现恒否）
static func meets(a, skill: Dictionary, logic) -> bool:
	if XBattleLogic.is_item(skill):
		return true
	var id := int(skill.get("id", 0))
	if own(a) and not unlocked(a, id):
		return false
	if id == WAKE and not logic.actors.any(func(m): return m.is_alive() and not robe(m).is_empty()):
		return false
	if id == GATHER:
		return false
	return true


## Y.recruit：入队、同步；本档第一次得一件织神天梭（只进背包）
static func recruit(s: XState) -> void:
	s.add_actor(ACTOR)
	sync(s.actor(ACTOR))
	if not bool(s.flags.get(RECRUITED_FLAG, false)):
		s.gain_gear("armor", RELIC, 1)
		s.flags[RECRUITED_FLAG] = true
