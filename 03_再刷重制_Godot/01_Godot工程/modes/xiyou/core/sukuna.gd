class_name XSukuna
extends RefCounted
## 172 宿傩（正式 js/codex/runtime/installNativeSukunaRuntime.js，W.CodexSukuna）第一期：招募、技能同步、能力值／被动、公式、伤害钩子。
## - 进阶次数 rank＝原版 a._AdvancedNum（XAdvance.rank）。allowed(id)：技能备注 CodexUnlockLevel ≤ 等级、CodexUnlockRank ≤ 进阶次数，
##   有 CodexUnlockMaxRank 时进阶次数不超过它。stage：学会且允许 10245／10244／10243 → 3／2／1，否则 0。
## - 同步 S.sync（包在 setup、levelUp、changeLevel 之后，进阶确定后也调）：10229～10249（10236～10238 除外）允许就学、不允许就忘；
##   没学黑闪 10225 就学。
## - 能力值：stage 3 时八项 ×3（取整、夹上限）；xparam 命中／暴击加 stage 1／2／3 → 3／6.66／9.99；被动缓存 stage 2／3 时
##   终伤与暴伤各加 6.66／9.99（refreshPassiveCache 包装）。
## - 公式 CodexSukuna.damage(a,b,id,this)：权重 × (火术用魔攻，否则攻击) × coefficient × (1＋0.15×熟练度)；CodexDamage 结算里减防项为 0
##   （防御由伤害钩子 sukuna 的物防／魔防率 ×0.5、捌 ×0.15 处理）。coefficient：没学 10247 为 88888，否则 50～上限级插值。
##   斩击另乘：适应层（战斗内，第一期 0）、捌打护盾 ×1.5、领域 ×1.3、黑闪觉醒、带伤口且戴神武解 ×1.2 等——只有护盾、伤口、神武解
##   这几项不靠战斗机制，照写；其余战斗内状态第一期恒为初值。
## - 伤害钩子 sukuna（XActorDamageHooks）：10229～10238 定物理（神灶 10232／10233 为魔法）；空间斩／次元斩（10234／10235）为真伤、
##   属性 13；其余物防率 ×0.5（捌非冲击段 ×0.15）、魔防率 ×0.5；stage 3 结算 ×1.5。
## - 招募（公共事件 9007 的 try { if (!CodexSukuna.recruit()) 还号角 }）：已在队返回 false；没戴神武解 4581 时背包有就拿、没有就生成，
##   装进装备类型 13 的槽；入队、同步；右上角提示「宿傩加入队伍，已装备神武解。」。
## 未移植（第二期起）：领域展开与神灶准备、看破层数、追斩、伤口（受治疗减半）、魔虚罗适应、黑闪（CodexBlackFlash，与甚尔共用）、
## 真伤段免护盾、技能使用条件与战斗中技能列表过滤、领域减耗、普攻换 10238、stage 3 的 makeDamageValue ×1.99（另见下）、
## 开战 TP 至少 60、技能分类与界面、外观、Map132 商店补号角 2938、旧档迁移。

const ACTOR := 172
const ARMOR := 4581
const WOUND := 2637
const RECRUIT_TEXT := "宿傩加入队伍，已装备神武解。"
const WEIGHTS := {10229: 1.0, 10230: 1.6, 10231: 1.0, 10232: 4.0, 10233: 5.4, 10234: 4.0, 10235: 7.0, 10236: 0.2, 10237: 9.0, 10238: 0.3}
const SLASH := [10229, 10230, 10231, 10234, 10235, 10236, 10237]
const PRIMARY := [10229, 10230, 10231]
const MASTERY_SOURCE := {10233: 10232, 10234: 10229, 10235: 10229, 10236: 10229, 10237: 10231, 10238: 10229}


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func rank(a) -> int:
	return XAdvance.rank(XState.current, ACTOR) if own(a) else 0


static func _meta_int(meta: Dictionary, key: String, fallback: int) -> int:
	var t := str(meta.get(key, "")).strip_edges()
	return int(t) if t.is_valid_int() and int(t) != 0 else fallback


static func allowed(a, id: int) -> bool:
	if not own(a):
		return false
	var meta: Dictionary = XDB.rec("Skills", id).get("meta", {})
	var max_rank := _meta_int(meta, "CodexUnlockMaxRank", 0)
	return int(a.level) >= _meta_int(meta, "CodexUnlockLevel", 1) and rank(a) >= _meta_int(meta, "CodexUnlockRank", 0) and (max_rank == 0 or rank(a) <= max_rank)


static func knows(a, id: int) -> bool:
	return allowed(a, id) and a.skill_ids.has(id)


static func stage(a) -> int:
	return 3 if knows(a, 10245) else (2 if knows(a, 10244) else (1 if knows(a, 10243) else 0))


static func sync(a) -> void:
	if not own(a):
		return
	for id in range(10229, 10250):
		if id in [10236, 10237, 10238]:
			continue
		if allowed(a, id):
			a.learn_skill(id)
		else:
			a.forget_skill(id)
	a.learn_skill(10225)
	a.refresh_passive()


static func coefficient(a) -> float:
	if not knows(a, 10247):
		return 88888.0
	var cap := 99 if knows(a, 10249) else (70 if knows(a, 10248) else 60)
	var level := clampi(int(a.level), 50, cap)
	var nodes := [[50, 88888], [55, 100000], [60, 111111], [70, 133333], [81, 155555], [99, 200000]]
	for i in range(1, nodes.size()):
		if level <= nodes[i][0]:
			return XPower.js_round(nodes[i - 1][1] + (nodes[i][1] - nodes[i - 1][1]) * float(level - nodes[i - 1][0]) / (nodes[i][0] - nodes[i - 1][0]))
	return 200000.0


static func artifact(a) -> bool:
	return a.equip_list().any(func(e): return int(e.get("base", e.get("id", 0))) == ARMOR)


## CodexSukuna.damage(a,b,id,this)：第一期没有施放帧（_sukunaCast／_sukunaPart），按单段直接施放算
static func formula(a, b, item: Dictionary) -> float:
	var id := int(item.get("id", 0))
	if not own(a) or not WEIGHTS.has(id):
		return 0.0
	var m := float(a.skillMasteryLevel(MASTERY_SOURCE.get(id, id)))
	var fire := id == 10232 or id == 10233
	var weight: float = WEIGHTS[id]
	var value := maxf(0.0, (a.mat if fire else a.atk) * weight) * coefficient(a) * (1 + 0.15 * m)
	if SLASH.has(id):
		if id == 10230 and float(b.shield) > 0.0:
			value *= 1.5
		var wounded: bool = b.state_ids.has(WOUND)
		if wounded and artifact(a) and PRIMARY.has(id):
			value *= 1.2
		if id == 10237 and stage(a) >= 2 and wounded:
			value *= 1.2
	if id == 10233 and artifact(a):
		value *= 1.2
	return value


static func param(a, i: int, v: float) -> float:
	if not own(a) or stage(a) != 3:
		return v
	return XPower.js_round(minf(a.param_max(i), v * 3))


static func xparam(a, i: int, v: float) -> float:
	if not own(a) or not (i == 0 or i == 2):
		return v
	var s := stage(a)
	return v + (0.0 if s == 0 else (9.99 if s == 3 else (6.66 if s == 2 else 3.0)))


static func passive_cache(a, c: Dictionary) -> void:
	if not own(a):
		return
	var s := stage(a)
	var v := 9.99 if s == 3 else (6.66 if s == 2 else 0.0)
	c.globalHarmRi += v
	c.critHarmRi += v


static func damage_ops(item: Dictionary, a) -> Array:
	if not own(a):
		return []
	var id := int(item.get("id", 0))
	var ops := []
	if id >= 10229 and id <= 10238:
		ops.append({"op": "set", "field": "mode", "value": "magical" if id == 10232 or id == 10233 else "physical"})
		if id == 10234 or id == 10235:
			ops.append({"op": "set", "field": "kind", "value": "true"})
			ops.append({"op": "set", "field": "elements", "value": [13]})
		else:
			ops.append({"op": "mul", "field": "physicalDefenseRate", "value": 0.15 if id == 10230 else 0.5})
			ops.append({"op": "mul", "field": "magicalDefenseRate", "value": 0.5})
	if stage(a) == 3:
		ops.append({"op": "mul", "field": "settlementMultiplier", "value": 1.5})
	return ops


## CodexSukuna.recruit()
static func recruit(s: XState) -> bool:
	if s.party.has(ACTOR):
		return false
	var a := s.actor(ACTOR)
	var slot := a.equip_slots().find(13)
	if slot < 0:
		push_error("[xiyou] 神武解装备槽不可用")
		return false
	var worn = a.equips[slot]
	if not (worn is Dictionary and int(worn.get("base", 0)) == ARMOR):
		var idx := s.gear.find_custom(func(e): return e.kind == "armor" and int(e.base) == ARMOR)
		if idx < 0:
			s.gain_gear("armor", ARMOR, 1)
			idx = s.gear.size() - 1
		var item: Dictionary = s.gear[idx]
		s.gear.remove_at(idx)
		if worn is Dictionary and not worn.is_empty():
			s.gear.append(worn)
		a.equips[slot] = item
	s.add_actor(ACTOR)
	sync(a)
	return true
