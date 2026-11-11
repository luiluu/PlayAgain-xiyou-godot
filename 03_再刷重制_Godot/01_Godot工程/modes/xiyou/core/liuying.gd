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
## 第二期（参照 mv_oracle/liuying2_probe.cjs → tests/fixtures/liuying2_oracle.json，tests/xiyou_liuying2）：见文末「第二期」各节。
## 第三期：说明按阶生成与技能名品质色（交界面）；萨姆残核掉落见文末「第三期」。

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
		if float(_frame.get("single", 0.0)) > 0.0:
			ops.append({"op": "mul", "field": "skillMultiplier", "value": float(_frame.single)})  # 只有一个目标 ×1.2／×1.5
		if spread_rate > 0.0:
			ops.append({"op": "mul", "field": "skillMultiplier", "value": spread_rate})  # 天火扩散 ×0.5
	var marks := mini(MARK_MAX, mark_count(b))
	if marks > 0:
		ops.append({"op": "mul", "field": "skillMultiplier", "value": 1.0 + 0.1 * marks})  # 击破印记：全队对它易伤
	if own(b) and learned(b, CHI_RAN) and item.get("damage") is Dictionary and _fire_or_physical(a, item):
		ops.append({"op": "mul", "field": "incomingMultiplier", "value": 1.0 - CHI_RAN_RATE})
	if firefly > 0 and a is XActor:
		ops.append({"op": "add", "field": "finalAdd", "value": FIREFLY_RATE * firefly})  # 萤火印记：全队行动者终伤 +10%/层
	return ops


# ---- 命中与段数 ----

static func sure(u, skill: Dictionary) -> bool:
	return _action(u, skill)


static func repeats(u, skill: Dictionary, base: int) -> int:
	begin_action(u, skill)
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


# ==== 第二期 ====
## 状态：击破印记 2787（敌人）、萨姆形态 2788、负面免疫 2789、免疫死亡 2790；萤火印记按备注 <CodexLiuyingState: firefly>（新源 2791）
const MARK := 2787
const FORM := 2788
const IMMUNE := 2789
const UNDYING := 2790
const STUN := 29
const MARK_MAX := 12
const EXPLODE_RATE := 6.0
const STUN_LOCK := 2
const SHIELD_CAP := 0.5
const HP_COST_RATE := 0.05
const RE_RELEASE := 0.2
const RS_COOLDOWN := 4
const FIREFLY_MAX := 30
const FIREFLY_RATE := 0.1
const FORM_SV := "Codex_Sam_SV"
const NEGATIVE_TYPE := "毒|灼伤|损伤|眩晕|睡眠|混乱|沉默|麻痹|破甲|疾病|减益|天灾|暗黑|黑暗|致盲|冰封|冰冷|过冷|溺水|魅惑|愤怒|禁咒|变形|封印|诅咒|流血|持续伤害"

## O-296（原版代码错误）：BattleManager.endAction 包装里 refreshUndying 先 removeState 再 addState，
## 同一次行动的结果里记着「刚移除」，原生 isStateAddable 不让加回，负面免疫与免疫死亡反倒没了。
## true＝修正：已有的就重置回合数、没有的照常附加；false＝照 v0.62.12 原版（移除后加不回）
static var FIX_UNDYING_REFRESH := true

static var _logic_ref: WeakRef = null
## 本次行动：{user, started, single, rerelease, marked, extra, extra_replay}（按行动者实例 id；numRepeats 时开新帧）
static var _frame := {}
static var spread_rate := 0.0
## 萤火印记层数（原版 $gameTroop._codexLbFirefly）：开战清零，只在内存
static var firefly := 0
## 萤火「一次」按一次行动计：原版比 BattleManager._action（行动结束不清，开战 setup 清），这里用行动序号
static var _action_serial := 0
static var _firefly_act := -1
static var _firefly_id := -1
static var _negative_re: RegEx = null
static var _marks_removing := false


static func _logic():
	return _logic_ref.get_ref() if _logic_ref != null else null


static func turn_now() -> int:
	var l = _logic()
	return int(l.turn) if l != null else 0


static func _in_battle() -> bool:
	return _logic() != null


static func firefly_state_id() -> int:
	if _firefly_id < 0:
		_firefly_id = 0
		var re := RegEx.create_from_string("(?i)<CodexLiuyingState:\\s*firefly\\s*>")
		for st in XDB.table("States"):
			if st is Dictionary and re.search(str(st.get("note", ""))) != null:
				_firefly_id = int(st.id)
				break
	return _firefly_id


static func begin_action(u, _skill: Dictionary) -> void:
	_frame = {"user": weakref(u) if u != null else null}
	spread_rate = 0.0
	_action_serial += 1


# ---- 印记 ----

static func mark_count(t) -> int:
	if t == null or not t is XBattler or not t.state_ids.has(MARK):
		return 0
	return maxi(0, int(t.state_data.get("_codexLbMark", 0)))


## 战斗中、目标没死、有印记：移除／抹除／清状态都挡下（只有引爆放行）
static func mark_locked(b, id: int) -> bool:
	return id == MARK and not _marks_removing and b is XEnemy and b.state_ids.has(MARK) and b.hp > 0.0 and _in_battle()


## 状态被移除（不在锁里）时清层
static func mark_removed(b, id: int) -> void:
	if id == MARK and b is XBattler and not b.state_ids.has(MARK):
		b.state_data.erase("_codexLbMark")


static func add_mark(logic, actor, t, count: int) -> void:
	if t == null or not t.is_alive() or not t is XEnemy or count <= 0:
		return
	if not t.state_ids.has(MARK):
		t.state_data["_codexLbMark"] = 0
		logic._state_add(t, MARK)
		if not t.state_ids.has(MARK):
			return
	var now := mini(MARK_MAX, mark_count(t) + count)
	t.state_data["_codexLbMark"] = now
	if now >= MARK_MAX:
		explode(logic, actor, t)


static func _hyper_armor(t) -> bool:
	return t is XEnemy and t.boss_difficulty_boss and t.boss_hyper_armor


static func explode(logic, actor, t) -> void:
	t.state_data["_codexLbMark"] = 0
	_marks_removing = true
	if t.state_ids.has(MARK):
		logic._state_remove(t, MARK)
	_marks_removing = false
	t.state_data.erase("_codexLbMark")
	var dmg := floorf(maxf(0.0, actor.mhp if actor != null else 0.0) * EXPLODE_RATE)
	if dmg > 0.0 and t.is_alive():  # 固定真伤：setHp，不经护盾账本与治疗修正（原生护盾照 setHp 吸收）
		var res: XResourceContext = logic._operation_resources(t)
		res.set_resource(t, "hp", maxf(0.0, t.hp - dmg))
		logic._finish_lifecycle_operation(res, t)
	var now := turn_now()
	var lock = t.state_data.get("_codexLbStunLock")
	if t.is_alive() and not _hyper_armor(t) and not (lock != null and int(lock) >= now):
		if not t.state_ids.has(STUN):
			t.add_new_state(STUN)  # 无视抵抗与有效度
		if t.state_ids.has(STUN):
			t.state_data["_codexLbForcedStun"] = true
			t.reset_state_counts(STUN, logic._rule())
			t.state_data["_codexLbStunLock"] = now + STUN_LOCK
			logic._refresh_battler(t)
	# 原版另弹「击破印记引爆！」提示（$.toaster），战斗日志没有这一行，重制不弹


## stateResistSet 包装：强制眩晕持续期间不按抵抗抹掉眩晕；眩晕结束后恢复
static func keeps_resisted(b, id: int) -> bool:
	if not b is XBattler or not bool(b.state_data.get("_codexLbForcedStun", false)):
		return false
	if b.state_ids.has(STUN):
		return id == STUN
	b.state_data.erase("_codexLbForcedStun")
	return false


## 印记：受到治疗 −10%/层（最低 0），向下取整
static func heal_value(b, amount: float) -> float:
	var marks := mini(MARK_MAX, mark_count(b)) if amount > 0.0 else 0
	return floorf(amount * maxf(0.0, 1.0 - 0.1 * marks)) if marks > 0 else amount


# ---- 施放流程（Game_Action.apply 包装，原版第 34 个） ----

static func wraps(u, skill: Dictionary, t) -> bool:
	return spread_rate == 0.0 and _action(u, skill) and t != null


static func _alive_enemies(logic) -> Array:
	return logic.enemies.filter(func(e): return e.is_alive())


static func _hit(r) -> bool:
	return r is Dictionary and r.get("type") == "hit" and not bool(r.get("missed", false)) and not bool(r.get("evaded", false))


## 天火付费：5% 当前生命（至少留 1），直接改生命（不经护盾与账本），按实际扣量转原生护盾（吃护盾加成）
static func _pay_hp(a) -> float:
	var hp := maxf(0.0, a.hp)
	var cost := minf(floorf(hp * HP_COST_RATE), maxf(0.0, hp - 1.0))
	if cost <= 0.0:
		return 0.0
	a.hp = hp - cost  # 原版直写 _hp：不经护盾账本与原生护盾（总装 11-06 定照原版）
	a.param_mark_dirty()
	note_hp_loss(a)
	return cost


static func apply(logic, u, skill: Dictionary, t) -> Array:
	var id := int(skill.id)
	if not bool(_frame.get("started", false)):
		_frame.started = true
		u.set_meta("liuying_cast_shield", XShieldLedger.total(u))
		var singles: bool = _alive_enemies(logic).size() == 1
		if id == TIANHUO:
			var paid := _pay_hp(u)
			if paid > 0.0:
				u.shield = maxf(0.0, u.shield + floorf(paid * (1.0 + maxf(0.0, u.shield_effect_bonus()))))
			if singles:
				_frame.single = 1.2
		else:
			var snapshot := float(u.get_meta("liuying_cast_shield"))
			if rank(u) >= 3:
				var add := minf(floorf(snapshot), floorf(u.mhp * SHIELD_CAP))  # 不吃加成
				if add > 0.0:
					u.shield = maxf(0.0, u.shield + add)
			elif snapshot > 0.0:
				u.add_shield(-snapshot)  # 只消耗自身原生护盾；队友给的期限护盾（护盾账本）保留
			var res: XResourceContext = logic._operation_resources(u)
			res.set_resource(u, "hp", u.mhp)
			logic._finish_lifecycle_operation(res, u)
			if singles:
				_frame.single = 1.5
			var cd := RS_COOLDOWN
			if rank(u) >= 3:
				cd = maxi(0, cd - 1)
				if logic._float("liuying_cooldown") < 0.33:
					cd = 0
			u.state_data["_codexLbRsReady"] = turn_now() + cd if cd > 0 else 0
		_frame.rerelease = logic._float("liuying_rerelease") < RE_RELEASE
	var out := _segment(logic, u, skill, t, false)
	if bool(_frame.get("rerelease", false)):
		out.append_array(_segment(logic, u, skill, t, true))
	return out


static func _segment(logic, u, skill: Dictionary, t, replay: bool) -> Array:
	var id := int(skill.id)
	var r: Dictionary = logic.apply(u, skill, t)
	var out := [r]
	if _hit(r) and not replay and not bool(_frame.get("marked", false)):
		_frame.marked = true
		add_mark(logic, u, t, 1 if id == TIANHUO else 5)
	if id == TIANHUO:
		for other in _alive_enemies(logic):
			if other == t:
				continue
			spread_rate = 0.5
			out.append(logic.apply(u, skill, other))
			spread_rate = 0.0
	var flag := "extra_replay" if replay else "extra"
	if id == RANSHAO and _alive_enemies(logic).size() == 1 and not bool(_frame.get(flag, false)):
		_frame[flag] = true
		for i in 4:
			out.append(logic.apply(u, skill, t))
	return out


## meetsSkillConditions：完全燃烧未到可用的自然回合不能用
static func meets(a, skill: Dictionary) -> bool:
	if own(a) and int(skill.get("id", 0)) == RANSHAO:
		return int(a.state_data.get("_codexLbRsReady", 0)) <= turn_now()
	return true


# ---- 形态、负面免疫、免死 ----

static func is_negative(id: int) -> bool:
	if id <= 1:
		return false
	var st := XDB.rec("States", id)
	if st.is_empty():
		return false
	if _negative_re == null:
		_negative_re = RegEx.create_from_string(NEGATIVE_TYPE)
	var m := RegEx.create_from_string("(?i)<BuffType:\\s*([^>]+)>").search(str(st.get("note", "")))
	if m != null:
		return _negative_re.search(m.get_string(1)) != null
	if int(st.get("restriction", 0)) > 0:
		return true
	return _negative_re.search(str(st.get("name", ""))) != null


## addState／isStateAddable 包装：负面免疫中的流萤不吃负面状态
static func blocks_state(b, id: int) -> bool:
	return own(b) and b.state_ids.has(IMMUNE) and is_negative(id)


## refresh 包装：负面免疫中清掉绕过 addState 写进来的负面状态
static func after_refresh(b) -> void:
	if not (own(b) and b.state_ids.has(IMMUNE)):
		return
	for id in b.state_ids.duplicate():
		if id != IMMUNE and is_negative(id):
			b.state_ids.erase(id)
			b.state_turns.erase(id)


## battlerName 包装：萨姆形态时 Codex_Sam_SV
static func battler_name(a, own_name: String) -> String:
	return FORM_SV if own(a) and a.state_ids.has(FORM) else own_name


## BattleManager.setup／startBattle／onBattleStart 包装：戴法宝变身，学了飞萤给负面免疫与免死；萤火清零
static func start_battle(logic) -> void:
	_logic_ref = weakref(logic)
	firefly = 0
	_frame = {}
	_action_serial = 0
	_firefly_act = -1
	spread_rate = 0.0
	for a in logic.actors:
		if not own(a):
			continue
		if a.has_base_equip("armor", ARMOR) and not a.state_ids.has(FORM):
			logic._state_add(a, FORM)
		if learned(a, FEI_YING):
			if not a.state_ids.has(IMMUNE):
				logic._state_add(a, IMMUNE)
			if not a.state_ids.has(UNDYING):
				logic._state_add(a, UNDYING)


## BattleManager.endAction 包装：戴专武、学了飞萤的流萤放完完全燃烧后刷新负面免疫与免死
static func end_action(logic, u, skill) -> void:
	if not (own(u) and u.has_base_equip("weapon", WEAPON) and skill is Dictionary and int(skill.get("id", 0)) == RANSHAO and learned(u, FEI_YING)):
		return
	for id in [IMMUNE, UNDYING]:
		if not u.state_ids.has(id):
			logic._state_add(u, id)
		elif FIX_UNDYING_REFRESH:
			u.reset_state_counts(id, logic._rule())
		else:
			logic._state_remove(u, id)  # 原版：移除后同一次行动的结果记着「刚移除」，addState 加不回


## BattleManager.endBattle 包装：全队流萤去掉形态、免疫、免死，清本场字段
static func end_battle(logic) -> void:
	for a in (logic.state.members() if logic != null and logic.state != null else []):
		if not own(a):
			continue
		for id in [FORM, IMMUNE, UNDYING]:
			if a.state_ids.has(id):
				logic._state_remove(a, id)
		a.state_data.erase("_codexLbRsReady")  # 施放前护盾快照原版不清（下次施放才覆盖），照搬
	_frame = {}
	spread_rate = 0.0
	_logic_ref = null  # 萤火层数原版不在结束时清（下场开战清）


# ---- 梦应归于何处：萤火印记 ----

static func add_firefly(logic) -> int:
	firefly = mini(FIREFLY_MAX, firefly + 1)
	var sid := firefly_state_id()
	if sid > 0 and logic != null:
		for m in logic.actors:
			if m.is_alive() and not m.state_ids.has(sid):
				logic._state_add(m, sid)
	return firefly


## 流萤掉血（setHp 变少、天火付费）：学了梦应，每次行动只叠 1 层；行动之外每次各 1 层
static func note_hp_loss(a) -> void:
	var logic = _logic()
	if not (own(a) and logic != null and meng_ying_id() > 0 and learned(a, meng_ying_id())):
		return
	if _action_serial > 0 and _firefly_act == _action_serial:
		return
	_firefly_act = _action_serial
	add_firefly(logic)


# ==== 第三期：萨姆残核掉落（v0.62.08，第 16 节） ====
## BattleManager.makeRewards 包装（在原奖励之后）：被击败的、备注带 <CodexLiuyingCoreDrop[:下限%]> 的敌人每只独立掷一次，
## 中了就把残核 3062 加进奖励（不吃队伍掉落率、不经掉落件数上限与品质屏蔽）。只在深渊地图（地图名以「深渊」开头）或
## 地图备注带 <CodexLiuyingCoreDrop> 的地图里掉。概率按路线：洪荒按诅咒倍率在两端之间插值，灭世一档，其余（含未选路线）一档；
## 敌人备注写了下限就取较大值。具体数值见下面常量（照新源）。
const CORE_ITEM := 3062
const CORE_RATES := {"base": 0.03, "doom": 0.05, "primordialMin": 0.06, "primordialMax": 0.18}
const HH_MAX := 6.075
const PRIMORDIAL_SW := [2483, 2463]
const DOOM_SW := [2487, 2462]
## O-297：false＝不掉（回到没有这段运行时）
static var CORE_DROP := true
static var _core_re: RegEx = null


static func core_rate(s: XState) -> float:
	if PRIMORDIAL_SW.any(func(id): return s.switch(id)):
		var holder := XHonghuang.curse_holder(s)
		var h := minf(HH_MAX, maxf(1.0, XHonghuang.curse_bonus(holder) if holder != null else 1.0))
		return CORE_RATES.primordialMin + (CORE_RATES.primordialMax - CORE_RATES.primordialMin) * (h - 1.0) / (HH_MAX - 1.0)
	if DOOM_SW.any(func(id): return s.switch(id)):
		return CORE_RATES.doom
	return CORE_RATES.base


static func core_map_ok(s: XState) -> bool:
	if str(XDB.rec("MapInfos", s.map_id).get("name", "")).begins_with("深渊"):
		return true
	return str(XDB.map(s.map_id).get("note", "")).to_lower().contains("<codexliuyingcoredrop>")


static func core_rate_for(s: XState, enemy_note: String) -> float:
	if _core_re == null:
		_core_re = RegEx.create_from_string("(?i)<CodexLiuyingCoreDrop(?::\\s*(\\d+(?:\\.\\d+)?))?>")
	var m := _core_re.search(enemy_note)
	if m == null or not core_map_ok(s):
		return 0.0
	return maxf(core_rate(s), float(m.get_string(1)) / 100.0 if m.get_string(1) != "" else 0.0)


## 奖励里追加的残核（每只倒下的标记敌人掷一次，奖励随机流 liuying_core）
static func core_drops(logic) -> Array:
	var out := []
	var s: XState = logic.state
	if not CORE_DROP or s == null or logic.random == null or XDB.rec("Items", CORE_ITEM).is_empty():
		return out
	for e in logic.enemies:
		if e.hidden or e.is_alive():
			continue  # deadMembers
		var rate := core_rate_for(s, str(e.data().get("note", "")))
		if rate > 0.0 and logic.random.reward.next_float("liuying_core", "0") < rate:
			out.append({"kind": 1, "id": CORE_ITEM})
	return out
