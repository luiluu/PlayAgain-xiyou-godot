class_name XLiuying
extends RefCounted
## 【cc·悟空·未经审查】179 流萤（新源 v0.62.12 js/codex/runtime/installLiuyingRuntime.js，W.CodexLiuying 运行时 1.2.0，modules.json 第 34 个：
## 云裳 33 之后、异化 36 之前）。参照 mv_oracle/liuying_probe.cjs → tests/fixtures/liuying_oracle.json（tests/xiyou_liuying）。
## 第一期（本文件现有内容）：
## - 公式 CodexLiuying.damage(a,b,id)（10622 天火轰击、10623 完全燃烧，转换器 MODULE_FORMULAS → "liuying"）：
##   round((基数＋最大生命×3000＋攻击×3888＋敏捷＋护盾×3888)×0.7)，≤0 或非有限为 1；基数 10622 88000、10623 880000，别的 id 为 0。
##   护盾取施放前快照（_codexLbCastShield，第二期施放流程写）没有就取当前护盾（原版 a.shield getter 含护盾账本，重制 XShieldLedger.total）。
##   不检查是不是流萤（原版也不查）。AI 估值（CodexAIEstimators）：流萤用这两招时同一个值。
## - 伤害钩子 liuying（CodexDamageHooks，并进 XActorDamageHooks）：流萤用两招时物理；赤染之茧 10627 物理受伤率穿透 0.33、火（元素 2）抗性穿透 33%
##   （按元素穿透取较大值，在 XDamage 建帧时写，见 pierce_by_element）；自限装甲 10626 火、物理各 +2；戴萨姆变身器 4582 技能倍率 ×4；
##   坠落 10628 终伤 +2、长夜 10631 终伤 +3；戴飞萤逐火 4004 失熵：每 1 万最大生命终伤 +1%；星河 10629 天火 ×5；飞萤 10630 燃烧 ×1.5。
##   流萤学了赤染、受到火或物理（命中类型物理且含物理元素）伤害 ×0.67（双属性只减一次）。
##   印记易伤、萤火终伤、单目标 ×1.2／×1.5、扩散 ×0.5 是第二期（施放流程）。
## - 必中（itemHit 1、itemEva 0）、段数（天火 5＋星河 3、燃烧 9）。
## - 能力值：param（在云裳夹值之外、异化之内）生命 ×(1＋自限 1.5＋坠落 2＋明天 3)、敏捷 ×(1＋过载 0.3＋明天 2)、过载攻击 +5000，各自向下取整；
##   paramPlus 逐火生命、戴专武攻击与敏捷各 +30×等级；shieldEffectBonus 自限 +1；actionPlusSet 过载 0.3、戴法宝 1、进阶 ≥1 再 1。
## - 逐火（gainRewards 之后，出战且戴专武）：前 2000 场每场 +10 基础生命，之后每场 10×2000/已胜场数；存在 state_data
##   （_codexLbEmber、_codexLbEmberWins，随存档）。缺胜场字段时按已得生命÷10 估一次，估完即写胜场，之后不再重估。
## - 学忘同步 sync（读档、levelUp、changeLevel 后）：等级 1／20／35／35 学 10624／10625／10626／10627，进阶 1／2／2／2／3／3 学
##   10628／10623／10629／10630／10631／10632 与梦应（<CodexLiuyingPassive: mengYing>，进阶 1），不够的忘掉；总会学 10622。
##   learnSkill 学到 10628 时连带学梦应（一阶进阶由进阶插件学 10628）。新建角色 setup 不同步（原版也不包 setup 的学忘）。
## - 招募 CodexLiuying.recruit()（公共事件 9043，号角 3063）：已在队返回 false；入队，专武 4004、法宝 4582 有就装、没有就生成后装；三条提示。
##   超强者门槛同别的角色（XMvScript._recruit_blocked）。
## 第二期：击破印记、施放流程（付费转护盾走护盾账本、冻结燃烧冷却、再释放、扩散、单目标额外段）、萨姆形态／负面免疫／免死、萤火印记。
## 第三期：说明按阶生成与技能名品质色（界面）、萨姆残核掉落。

const ACTOR := 179
const TIANHUO := 10622
const RANSHAO := 10623
const PIAN_SHI := 10624
const GUO_ZAI := 10625
const ZI_XIAN := 10626
const CHI_RAN := 10627
const ZHUI_LUO := 10628
const XING_HE := 10629
const FEI_YING := 10630
const CHANG_YE := 10631
const MING_TIAN := 10632
const WEAPON := 4004
const ARMOR := 4582
const HORN := 3063
const BASE := {10622: 88000.0, 10623: 880000.0}
const HP_N := 3000.0
const DAMAGE_N := 3888.0
const HIDDEN_RATE := 0.7
const CHI_RAN_RATE := 0.33
const EMBER_FULL := 2000.0
const LEVEL_MAP := [[1, PIAN_SHI], [20, GUO_ZAI], [35, ZI_XIAN], [35, CHI_RAN]]
const RANK_MAP := [[1, ZHUI_LUO], [2, RANSHAO], [2, XING_HE], [2, FEI_YING], [3, CHANG_YE], [3, MING_TIAN]]
const RECRUIT_TEXT := ["小伙伴 流萤 加入队伍", "获得并装备专属武器：飞萤逐火·向死而生", "获得并装备专属法宝：萨姆变身器"]

static var _meng := -1
static var _syncing := false


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func lb_skill(id: int) -> bool:
	return id == TIANHUO or id == RANSHAO


static func rank(a) -> int:
	return XAdvance.rank(XState.current, int(a.actor_id)) if a is XActor else 0


static func learned(a, id: int) -> bool:
	return a is XActor and id > 0 and a.skill_ids.has(id)


## 梦应归于何处：技能表里第一个带 <CodexLiuyingPassive: mengYing> 的（新源 10633）
static func meng_ying_id() -> int:
	if _meng < 0:
		_meng = 0
		var re := RegEx.create_from_string("(?i)<CodexLiuyingPassive:\\s*mengYing\\s*>")
		for s in XDB.table("Skills"):
			if s is Dictionary and re.search(str(s.get("note", ""))) != null:
				_meng = int(s.id)
				break
	return _meng


static func _action(u, skill: Dictionary) -> bool:
	return own(u) and lb_skill(int(skill.get("id", 0))) and not XBattleLogic.is_item(skill)


# ---- 公式与伤害钩子 ----

## CodexLiuying.damage(a,b,id)
static func formula(a, _b, item: Dictionary) -> float:
	if a == null:
		return 0.0
	var id := int(item.get("id", 0))
	if not BASE.has(id):
		return 0.0
	var shield := maxf(0.0, float(a.get_meta("liuying_cast_shield"))) if a.has_meta("liuying_cast_shield") else maxf(0.0, XShieldLedger.total(a))
	var raw := (float(BASE[id]) + maxf(0.0, a.mhp) * HP_N + maxf(0.0, a.atk) * DAMAGE_N + (maxf(0.0, a.agi) + shield * DAMAGE_N)) * HIDDEN_RATE
	if not is_finite(raw) or raw <= 0.0:
		return 1.0
	return roundf(raw)


## CodexAIEstimators：流萤用两招（公式是 CodexLiuying.damage(a,b,1062x)）时给公式值，否则 null
static func ai_raw(a, t, rec: Dictionary):
	if own(a) and lb_skill(int(rec.get("id", 0))) and str(rec.get("damage", {}).get("formula", "")).replace(" ", "").begins_with("CodexLiuying.damage(a,b,1062"):
		return formula(a, t, rec)
	return null


## 赤染之茧：流萤用两招时火（2）的按元素穿透取 max(原值, 33)
static func pierce_by_element(item: Dictionary, a, by_element: Dictionary) -> Dictionary:
	if _action(a, item) and learned(a, CHI_RAN):
		by_element[2] = maxf(float(by_element.get(2, 0.0)), CHI_RAN_RATE * 100.0)
	return by_element


## 赤染之茧减免的伤害类型：元素（普攻元素取攻击者的）或多元素里有火；或命中类型物理且有物理元素
static func _fire_or_physical(subject, item: Dictionary) -> bool:
	var ids := []
	var e := int(item.get("damage", {}).get("elementId", 0))
	if e > 0:
		ids.append(e)
	if e < 0 and subject != null:
		ids.append_array(subject.attack_elements())
	ids.append_array(item.get("yep", {}).get("multipleElements", []))
	ids = ids.map(func(v): return int(v))
	if ids.has(2):
		return true
	return int(item.get("hitType", 0)) == 1 and ids.has(1)


static func damage_ops(item: Dictionary, a, b) -> Array:
	var ops := []
	var id := int(item.get("id", 0))
	if _action(a, item):
		ops.append({"op": "set", "field": "mode", "value": "physical"})
		if learned(a, CHI_RAN):
			ops.append({"op": "set", "field": "physicalIncomingPierce", "value": CHI_RAN_RATE})  # 原版 max(原值, 0.33)；流萤这两招别的钩子不写它
		if learned(a, ZI_XIAN):
			ops.append({"op": "add", "field": "elementAdd", "element": 2, "value": 2.0})
			ops.append({"op": "add", "field": "elementAdd", "element": 1, "value": 2.0})
		if a.has_base_equip("armor", ARMOR):
			ops.append({"op": "mul", "field": "skillMultiplier", "value": 4.0})
		if learned(a, ZHUI_LUO):
			ops.append({"op": "add", "field": "finalAdd", "value": 2.0})
		if learned(a, CHANG_YE):
			ops.append({"op": "add", "field": "finalAdd", "value": 3.0})
		if a.has_base_equip("weapon", WEAPON):
			var lost := floorf(maxf(0.0, a.mhp) / 10000.0)
			if lost > 0.0:
				ops.append({"op": "add", "field": "finalAdd", "value": lost * 0.01})
		if id == TIANHUO and learned(a, XING_HE):
			ops.append({"op": "mul", "field": "skillMultiplier", "value": 5.0})
		if id == RANSHAO and learned(a, FEI_YING):
			ops.append({"op": "mul", "field": "skillMultiplier", "value": 1.5})
	if own(b) and learned(b, CHI_RAN) and item.get("damage") is Dictionary and _fire_or_physical(a, item):
		ops.append({"op": "mul", "field": "incomingMultiplier", "value": 1.0 - CHI_RAN_RATE})
	return ops


# ---- 命中与段数 ----

static func sure(u, skill: Dictionary) -> bool:
	return _action(u, skill)


static func repeats(u, skill: Dictionary, base: int) -> int:
	if not _action(u, skill):
		return base
	return 5 + (3 if learned(u, XING_HE) else 0) if int(skill.id) == TIANHUO else 9


# ---- 能力值 ----

static func param(a, i: int, v: float) -> float:
	if not own(a):
		return v
	if i == 0:
		var hp_rate := 1.0
		if learned(a, ZI_XIAN): hp_rate += 1.5
		if learned(a, ZHUI_LUO): hp_rate += 2.0
		if learned(a, MING_TIAN): hp_rate += 3.0
		v = floorf(v * hp_rate)
	if i == 6:
		var agi_rate := 1.0
		if learned(a, GUO_ZAI): agi_rate += 0.3
		if learned(a, MING_TIAN): agi_rate += 2.0
		v = floorf(v * agi_rate)
	if i == 2 and learned(a, GUO_ZAI):
		v += 5000.0
	return v


static func param_plus(a, i: int, v: float) -> float:
	if not own(a):
		return v
	if i == 0:
		v += float(a.state_data.get("_codexLbEmber", 0.0))
	if (i == 2 or i == 6) and a.has_base_equip("weapon", WEAPON):
		v += 30.0 * maxf(1.0, float(a.level))
	return v


static func shield_effect_bonus(b) -> float:
	return 1.0 if own(b) and learned(b, ZI_XIAN) else 0.0


static func action_plus_set(a, rates: Array) -> void:
	if not own(a):
		return
	if learned(a, GUO_ZAI): rates.append(0.3)
	if a.has_base_equip("armor", ARMOR): rates.append(1.0)
	if rank(a) >= 1: rates.append(1.0)


## BattleManager.gainRewards 之后：出战且戴专武的流萤逐火
static func gain_rewards(members: Array) -> void:
	for a in members:
		if not (own(a) and a.has_base_equip("weapon", WEAPON)):
			continue
		var ember := maxf(0.0, float(a.state_data.get("_codexLbEmber", 0.0)))
		var wins := maxf(0.0, float(a.state_data["_codexLbEmberWins"])) if a.state_data.get("_codexLbEmberWins") != null else floorf(ember / 10.0)
		a.state_data["_codexLbEmber"] = ember + 10.0 * (1.0 if wins < EMBER_FULL else EMBER_FULL / wins)
		a.state_data["_codexLbEmberWins"] = wins + 1.0
		a.param_mark_dirty()


# ---- 学忘同步 ----

static func sync(a) -> void:
	if not own(a) or _syncing:
		return
	_syncing = true
	var lv := int(a.level)
	var r := rank(a)
	for pair in LEVEL_MAP:
		_keep(a, int(pair[1]), lv >= int(pair[0]))
	var rmap: Array = RANK_MAP.duplicate()
	if meng_ying_id() > 0:
		rmap.append([1, meng_ying_id()])
	for pair in rmap:
		_keep(a, int(pair[1]), r >= int(pair[0]))
	if not a.skill_ids.has(TIANHUO):
		a.learn_skill(TIANHUO)
	_syncing = false
	a.refresh_passive()


static func _keep(a, id: int, on: bool) -> void:
	if on and not a.skill_ids.has(id):
		a.learn_skill(id)
	elif not on and a.skill_ids.has(id):
		a.forget_skill(id)


## learnSkill 包装：学到 10628 时连带学梦应
static func learned_skill(a, id: int) -> void:
	if own(a) and id == ZHUI_LUO and meng_ying_id() > 0 and not a.skill_ids.has(meng_ying_id()):
		a.learn_skill(meng_ying_id())


## extractSaveContents 包装：角色数据里有流萤就整理一次（不在队也整理）
static func after_load(s: XState) -> void:
	if s.actors.has(ACTOR):
		sync(s.actors[ACTOR])


# ---- 招募 ----

## L.recruit：已在队返回空数组；否则入队、装专武与法宝，返回三条提示
static func recruit(s: XState) -> Array:
	if s.party.has(ACTOR):
		return []
	var a := s.actor(ACTOR)
	s.add_actor(ACTOR)
	if not s.party.has(ACTOR):
		return []  # 超强者门槛挡下（原版包在 recruit 外层，不会走到这里；重制兜底）
	_equip_base(s, a, "weapon", WEAPON)
	_equip_base(s, a, "armor", ARMOR)
	return RECRUIT_TEXT.duplicate()


## equipBase：第一个类型相符的槽；已经穿着同款就不动；不是独立物品时也照样生成实例（重制装备一律是实例）
static func _equip_base(s: XState, a: XActor, kind: String, base: int) -> void:
	var rec := XDB.rec("Weapons" if kind == "weapon" else "Armors", base)
	var slot := a.equip_slots().find(int(rec.get("etypeId", 0)))
	if slot < 0:
		return
	var worn = a.equips[slot]
	if worn is Dictionary and int(worn.get("base", 0)) == base:
		return
	s.gain_gear(kind, base, 1)
	XEquipment.change(s, a, slot, s.gear[s.gear.size() - 1])
