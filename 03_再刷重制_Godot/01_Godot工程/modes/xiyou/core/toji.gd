class_name XToji
extends RefCounted
## 171 伏黑甚尔（正式 js/codex/runtime/installNativeTojiRuntime.js，W.CodexToji）第一期：招募、开机同步、能力值与基础伤害公式、伤害钩子。
## - 进阶次数 rank＝原版 a._AdvancedNum（XAdvance.rank）。knows(id)：是甚尔且学会了该技能。
## - 开机同步 repair（Game_Actor.setup 包装；原版另包 extractSaveContents 与进阶 onConfirmOk〔进阶后 rank≥1 才调〕）：
##   忘 10204；被动与咒具按 UNLOCK 表到等级就学、不到就忘（rank≥1 时 10208 霸王血铠改为忘）；rank≥1 学 10210 杰作·霸王血铠
##   与 10211 武器库，否则忘；MP 归 0。原版不包 levelUp：升级只按职业习得表学（与 UNLOCK 表相同），rank≥1 后再升到 30 级
##   会同时有 10208 与 10210，杰作优先、不影响数值，下次读档才忘掉 10208——重制照此不在升级时同步。
##   黑闪 10225 与觉醒：伏黑 10226 在职业 1 级习得表里（XBlackFlash 的 unlock 1 级同样会学），不另学。
## - 能力值（Game_Actor.param 包装，lv＝暴君 10205 学会时的等级，否则 0）：
##   天与咒缚 10203：最大 MP、魔攻恒 0，原值分别并进最大生命、物攻（读包装之内的原值 param_native）；
##   最大生命 round((原值＋原 MP)×(1＋0.10lv))；速度 round(原值×(1＋0.05lv))；物攻 (原值＋原魔攻)×(1＋0.05lv)，
##   霸王血铠 10208（或 rank≥1 且学了杰作 10210）再 (＋最大生命×2.5%／5%)×(1＋已损生命比例×12%／15%)，大力 10209 ×1.2，取整、至少 1。
##   xparam 暴击＋0.10lv；被动缓存（refreshPassiveCache 包装）终伤与暴伤各＋0.40lv。
## - 公式 CodexToji.damage(a,b,id,this)：CodexDamage 结算里减防项为 0（防御由结算按物防／魔防率处理）。
##   主技能 10216～10219 底数 max(0, 7777×物攻＋888×最大生命)：游云 ×1；释魂刀 ×(5＋追加次数)×0.95；万里锁／天逆鉾 本次行动第 2 段起
##   ×0.8，否则 ×4。武器库 10220～10223 为 2666×物攻。术师杀手·反弹 10224 为反弹基数（战斗内，第一期 0）。
##   追加次数（startAction 记的 attackTimesAdd）与第几段（apply 计数）是战斗内字段，第一期按初值 0／第 1 段。
## - 伤害钩子 toji（XActorDamageHooks；原版第 5 个，在 cat-sword 之前）：自己的 10216～10224 定物理（反弹为魔法）；敏锐五感 10206
##   物防率、魔防率 ×0.67；物理穿透 释魂刀 0.66（觉醒中的主行动 0.80）、武器库·释魂刀 0.33（借用释魂刀特效的主技能也 0.33，第二期）；
##   武器库技能 ×(1＋0.10×武器库熟练度)；主技能且学了暴君 ×成长 outputGrowth(主)，否则 ×成长 outputGrowth(非主)；
##   非反弹且戴藏兵咒灵 4580 ×1.11；暴君 ×3；溅射倍率（第二期）。
## - 招募（公共事件 9006 的 try { if (!CodexToji.recruit()) 还号角 }）：已在队返回 false；没戴藏兵咒灵时背包有就拿、没有就生成，
##   装进它装备类型（13）的槽，换下的进背包；入队；两条右上角提示。
## - 技能条件（meetsSkillConditions 包装，原版 367-377）：主技能只有当前形态那个（＝普攻技能）能用；咒具切换 10212～10215
##   要学了切换与对应主技能、且不是当前形态才能用（当前形态：第一个带着的形态状态 2630～2633，没有算游云）。
##   切换技能单独豁免战技类别封印（359-366）第二期做。切片加 171 后 wtype 参照（10 级、未进战斗）覆盖到 10212。
## - 已在别处：普攻＝当前形态主技能与指令名（XActor.attack_skill_id）、进阶石 rollAdvanceStone（XDungeon）、Map132 商店号角（XItemMarks）、
##   黑闪配置（XBlackFlash.CONFIGS 171）。
## 第二期（战斗内，参照 toji_battle_probe）：
## - 咒具形态：开战设第一形态（startBattle 包装在原 startBattle 之前，随后开战清 removeAtBattleEnd 状态又把它清掉，参照里开战后
##   没有形态状态，普攻照「没有算游云」）；切换技能 10212～10215 在 endAction 后换形态（去掉别的形态状态、加这一个）；
##   战斗中阵亡后复活（removeState 阵亡）且没有形态状态时回游云；endBattle 清形态。
## - 战斗中技能列表（Window_SkillList.includes）：战技类别只列切换技能，主技能、武器库、反弹不列；切换技能检查条件时
##   不受战技类别封印（isSkillTypeSealed 豁免，原版 359-366）。
## - 多段（startAction／actionActionEffect 包装）：主技能把目标收成第一个，记追加次数 floor(attackTimesAdd)；游云 5＋追加段、
##   释魂刀 1 段（追加次数折进 ×(5＋追加)×0.95）、万里锁／天逆鉾 1＋追加段，在第一条 ACTION EFFECT 里逐段打完（目标全倒就停），
##   之后的 ACTION EFFECT 不再打。每段 apply 计第几段（万里锁／天逆鉾第 2 段起 ×0.8）。黑闪觉醒中的游云（extraHitSkill）多 1 段。
## - apply 包装：命中后万里锁对其余活着的敌人溅射（倍率 0.33，觉醒中的主行动 0.50；内部行动、不判黑闪、不再溅射）；
##   天逆鉾给目标附封印 2634，次数 max(原次数或 1, 觉醒中的主行动 2／否则 1)，状态去掉时次数清零。
## - 封印失效（applyGlobal 包装）：带 2634 的行动者下一次主动技能失效并扣一次，普攻、防御、物品不扣。
## 未移植（第三期起，清单见交付单 cc_bajie-toji2「下期」）：武器库追击与借用特效、术师杀手减伤与反弹、
##   暴君免负面状态与弱化、天与咒缚的命中／闪避、五感必中与暴击闪避、智能 AI 档案；说明框熟练度行（画面）；读档时 repair。
##   原版 makeDamageValue 包装是死代码（installDamageElementRuntime 后装、整个换掉 makeDamageValue 不调旧链），不移植。
## 参照：slice_probe（切片角色行与伤害行）、toji_probe（等级／进阶／血量各档的能力值、公式、钩子帧，tests/xiyou_toji.gd）。

const ACTOR := 171
const ARMOR := 4580
const NO_MP := 10203
const TYRANT := 10205
const SENSES := 10206
const BLOOD := 10208
const POWER := 10209
const BLOOD_GREAT := 10210
const ARMORY := 10211
const MAIN := [10216, 10217, 10218, 10219]
## 原版 RANDOM 按形态序（游云、万里锁、释魂刀、天逆鉾）
const RANDOM := [10220, 10223, 10221, 10222]
const REFLECT := 10224
const SWITCH := [10212, 10213, 10214, 10215]
const SHAPES := [2630, 2631, 2632, 2633]
const SEAL := 2634
const AWAKENING := 10226
const DEATH := 1

## 战斗内：当前战斗（开战设、结束清；复活回形态与切换用）
static var _logic = null
## 本次行动（startAction 记，endAction 清）：switch 切换到的形态；count 段数、extra 追加次数、index 第几段、done 段已打完
static var action := {}
## 内部行动（溅射）进行中与它的倍率
static var internal := false
static var spread_rate := 0.0
## 天逆鉾封印次数（_tojiSealCharges）；状态不在时视为没有
static var seal_charges := {}
const BALANCE_AT_70 := 0.188208
## repair 的 unlock 表：技能 → 解锁等级
const UNLOCK := {10203: 1, 10205: 1, 10206: 10, 10207: 20, 10208: 30, 10209: 35, 10212: 1, 10213: 15, 10214: 30, 10215: 40,
	10216: 1, 10217: 15, 10218: 30, 10219: 40}
const RECRUIT_TEXT := ["小伙伴 伏黑甚尔 加入队伍", "获得并装备专属法宝：藏兵咒灵"]


static func own(a) -> bool:
	return a is XActor and int(a.actor_id) == ACTOR


static func knows(a, id: int) -> bool:
	return own(a) and a.skill_ids.has(id)


static func rank(a) -> int:
	return XAdvance.rank(XState.current, ACTOR) if own(a) and XState.current != null else 0


static func weapon(a) -> bool:
	return a.equip_list().any(func(e): return int(e.get("base", e.get("id", 0))) == ARMOR)


static func _original_growth(lv: float) -> float:
	return 1.0 if lv >= 50 else 0.10 + 0.90 * pow(lv / 50.0, 2)


static func _smooth_tail(lv: float, anchor: float, base: float, slope: float, end: float) -> float:
	var span := 70.0 - anchor
	var delta := end - base
	var lo := 0.000001
	var hi := 10.0
	for i in 64:
		var k := (lo + hi) / 2
		if delta * k / (1 - exp(-k * span)) > slope:
			hi = k
		else:
			lo = k
	var rate := (lo + hi) / 2
	return base + delta * (1 - exp(-rate * (lv - anchor))) / (1 - exp(-rate * span))


## T.outputGrowth(actor, main)
static func output_growth(a, main: bool) -> float:
	var lv := maxf(1.0, float(a.level))
	var anchor := 20.0 if main else 10.0
	var p := _original_growth(anchor)
	var base := (1 + 0.1 * anchor) * p if main else p
	if lv <= anchor:
		return (1 + 0.1 * lv if main else 1.0) * _original_growth(lv)
	var slope := 0.1 * p + (1 + 0.1 * anchor) * 0.00072 * anchor if main else 0.00072 * anchor
	return _smooth_tail(lv, anchor, base, slope, BALANCE_AT_70 * (8.0 if main else 1.0))


## repair（setup 之后、进阶后 rank≥1）
static func repair(a) -> void:
	if not own(a):
		return
	if a.skill_ids.has(10204):
		a.forget_skill(10204)
	var r := rank(a)
	for id in UNLOCK:
		if int(a.level) >= int(UNLOCK[id]) and not (id == BLOOD and r >= 1):
			a.learn_skill(id)
		else:
			a.forget_skill(id)
	for id in [BLOOD_GREAT, ARMORY]:
		if r >= 1:
			a.learn_skill(id)
		else:
			a.forget_skill(id)
	a.mp = 0.0
	a.refresh_passive()


## Scene_ActorAdvanced.onConfirmOk 包装
static func after_advance(a) -> void:
	if own(a) and rank(a) >= 1:
		repair(a)


static func _growth_level(a) -> float:
	return float(a.level) if knows(a, TYRANT) else 0.0


## Game_Actor.param 包装（v 是包装前的值）
static func param(a, i: int, v: float) -> float:
	if not own(a):
		return v
	if i == 1 and knows(a, NO_MP):
		return 0.0
	if i == 4 and knows(a, NO_MP):
		return 0.0
	if i != 0 and i != 2 and i != 6:
		return v
	var growth := _growth_level(a)
	if i == 0:
		var source_mp: float = a.param_native(1) if knows(a, NO_MP) else 0.0
		return maxf(1.0, XPower.js_round((v + source_mp) * (1 + growth * 0.10)))
	if i == 6:
		return maxf(1.0, XPower.js_round(v * (1 + growth * 0.05)))
	var source_mat: float = a.param_native(4) if knows(a, NO_MP) else 0.0
	var result := (v + source_mat) * (1 + growth * 0.05)
	var fine := knows(a, BLOOD_GREAT) and rank(a) >= 1
	if fine or knows(a, BLOOD):
		var hp: float = a.param(0)
		var lost := maxf(0.0, minf(1.0, 1 - float(a.hp) / maxf(1.0, hp)))
		result = (result + hp * (0.05 if fine else 0.025)) * (1 + lost * (0.15 if fine else 0.12))
	if knows(a, POWER):
		result *= 1.2
	return maxf(1.0, XPower.js_round(result))


static func xparam(a, i: int, v: float) -> float:
	return v + 0.10 * float(a.level) if i == 2 and knows(a, TYRANT) else v


static func passive_cache(a, c: Dictionary) -> void:
	if not own(a):
		return
	var growth := 0.40 * float(a.level) if knows(a, TYRANT) else 0.0
	c.globalHarmRi += growth
	c.critHarmRi += growth


static func is_main(id: int) -> bool:
	return MAIN.has(id)


static func is_random(id: int) -> bool:
	return RANDOM.has(id)


## CodexToji.damage(a,b,id,this)（CodexDamage 结算里，减防项为 0）
static func formula(a, _b, item: Dictionary) -> float:
	var id := int(item.get("id", 0))
	if not own(a):
		return 0.0
	var atk := maxf(0.0, float(a.atk))
	if is_main(id):
		var base := maxf(0.0, 7777 * atk + 888 * maxf(0.0, float(a.mhp)))
		var extra := int(action.get("extra", 0))  # action._tojiExtra
		var index := int(action.get("index", 0))  # action._tojiIndex（溅射沿用源行动的）
		if id == MAIN[0]:
			return base
		if id == MAIN[2]:
			return base * (5 + extra) * 0.95
		return base * (0.8 if index > 1 else 4.0)
	if is_random(id):
		return maxf(0.0, 2666 * atk)
	return 0.0  # REFLECT：action._tojiReflectBase（第二期）


## 伤害钩子 toji（只含自己的技能；术师杀手受击分支第三期）
static func damage_ops(item: Dictionary, a) -> Array:
	var id := int(item.get("id", 0))
	if not own(a) or not (is_main(id) or is_random(id) or id == REFLECT):
		return []
	var ops := [{"op": "set", "field": "mode", "value": "magical" if id == REFLECT else "physical"}]
	if knows(a, SENSES):
		ops.append({"op": "mul", "field": "physicalDefenseRate", "value": 0.67})
		ops.append({"op": "mul", "field": "magicalDefenseRate", "value": 0.67})
	ops.append({"op": "set", "field": "physicalIncomingPierce", "value": (0.80 if awakened(a, id) else 0.66) if id == MAIN[2] else (0.33 if id == RANDOM[2] else 0.0)})
	var mult := 1.0
	if is_random(id):
		mult *= 1 + 0.10 * a.skillMasteryLevel(ARMORY)
	var main_tyrant := is_main(id) and knows(a, TYRANT)
	if main_tyrant:
		mult *= output_growth(a, true)
	if id != REFLECT and weapon(a):
		mult *= 1.11
	if knows(a, TYRANT):
		mult *= 3
	if spread_rate > 0.0:
		mult *= spread_rate
	if not main_tyrant:
		mult *= output_growth(a, false)
	ops.append({"op": "mul", "field": "skillMultiplier", "value": mult})
	return ops


## eligibleShape：学了该形态的切换与主技能
static func eligible_shape(a, index: int) -> bool:
	return index >= 0 and index < 4 and knows(a, SWITCH[index]) and knows(a, MAIN[index])


## currentShape：第一个带着的形态状态，没有算 0
static func current_shape(a) -> int:
	for i in 4:
		if a.state_ids.has(SHAPES[i]):
			return i
	return 0


## meetsSkillConditions 包装：false 就不能用（其余条件照常由原链判）
static func meets(a, skill: Dictionary) -> bool:
	if not own(a):
		return true
	var id := int(skill.get("id", 0))
	if is_main(id) and id != a.attack_skill_id():
		return false
	var index := SWITCH.find(id)
	return index < 0 or (eligible_shape(a, index) and current_shape(a) != index)


# ---- 第二期：战斗内 ----

## 本次是觉醒中的主行动（awakenedAction：黑闪施放帧觉醒、未结束、不是内部行动、学了觉醒：伏黑）
static func awakened(a, id: int) -> bool:
	var c: Dictionary = XBlackFlash.cast
	return is_main(id) and not internal and knows(a, AWAKENING) and not c.is_empty() and c.actor == a and bool(c.awake)


## setShape：可切才换；去掉其余形态状态、加这一个
static func set_shape(logic, a, index: int) -> bool:
	if not own(a) or not eligible_shape(a, index):
		return false
	for id in SHAPES:
		if a.state_ids.has(id):
			if logic != null:
				logic._state_remove(a, id)
			else:
				a.remove_state(id)
	if logic != null:
		logic._state_add(a, SHAPES[index])
	else:
		a.add_state(SHAPES[index])
	return a.state_ids.has(SHAPES[index])


## BattleManager.startBattle 包装（原 startBattle 之前）：甚尔在队就设第一形态
static func start_battle(logic) -> void:
	_logic = logic
	action = {}
	internal = false
	spread_rate = 0.0
	seal_charges.clear()
	if logic.state.party.has(ACTOR):
		set_shape(logic, logic.state.actor(ACTOR), 0)


## BattleManager.endBattle 包装：清形态
static func end_battle(logic) -> void:
	if logic.state.actors.has(ACTOR):
		var a = logic.state.actors[ACTOR]
		for id in SHAPES:
			if a.state_ids.has(id):
				logic._state_remove(a, id)
	_logic = null
	action = {}


## Game_Actor.removeState 包装：战斗中复活（去掉阵亡）且没有形态时回游云
static func revived(a, id: int, had: bool) -> void:
	if _logic == null or id != DEATH or not had or not own(a) or not a.is_alive() or SHAPES.any(func(s): return a.state_ids.has(s)):
		return
	set_shape(null, a, 0)


## Window_SkillList.includes 包装（战斗中）：战技类别只列切换技能；主技能、武器库、反弹不列
static func listed(a, skill: Dictionary) -> bool:
	if not own(a):
		return true
	var id := int(skill.get("id", 0))
	if int(skill.get("stypeId", 0)) == 1 and not SWITCH.has(id):
		return false
	return not (is_main(id) or is_random(id) or id == REFLECT)


## isSkillTypeSealed 豁免：检查切换技能条件时战技类别不算封印
static func switch_unsealed(a, skill: Dictionary) -> bool:
	return own(a) and SWITCH.has(int(skill.get("id", 0))) and int(skill.get("stypeId", 0)) == 1


## BattleManager.startAction 包装：切换记形态；主技能把目标收成第一个，记段数与追加次数（targets 原地改）
static func begin(_logic_ref, u, skill: Dictionary, targets: Array) -> void:
	if not own(u):
		return
	action = {}
	var id := int(skill.get("id", 0))
	if SWITCH.has(id):
		action.switch = SWITCH.find(id)
		return
	if not is_main(id) or targets.is_empty():
		return
	var index := MAIN.find(id)
	var extra := maxi(0, floori(float(u.attack_times_add())))
	var target = targets[0]
	targets.clear()
	targets.append(target)
	action.merge({"extra": extra, "index": 0, "count": 5 + extra if index == 0 else (1 if index == 2 else 1 + extra), "done": false})


## 黑闪 startAction 包装：觉醒中的游云多 1 段（读施放帧，第一次打段时算）
static func _count(u, id: int) -> int:
	var c: Dictionary = XBlackFlash.cast
	var extra_hit: bool = id == MAIN[0] and not c.is_empty() and c.actor == u and bool(c.awake)
	return int(action.count) + (1 if extra_hit else 0)


## BattleManager.actionActionEffect 包装：主技能第一条 ACTION EFFECT 打完全部段（目标全倒就停），之后的不打。true＝已处理
static func effects(seq, args: Array) -> bool:
	if not own(seq.user) or not is_main(int(seq.skill.get("id", 0))) or internal or not action.has("count"):
		return false
	if bool(action.done):
		return true
	action.done = true
	for i in _count(seq.user, int(seq.skill.id)):
		var list: Array = seq.make_targets(str(args[0])) if not args.is_empty() and str(args[0]) != "" else seq.targets
		if not list.any(func(t): return t != null and t.is_alive()):
			break
		seq._action_effect(args)
	return true


## Game_Action.apply 包装要接管的：甚尔的主技能与武器库
static func wraps(u, skill: Dictionary) -> bool:
	var id := int(skill.get("id", 0))
	return own(u) and (is_main(id) or is_random(id))


static func seal_count(t) -> int:
	if not t.state_ids.has(SEAL):
		seal_charges.erase(t)
		return 0
	return int(seal_charges.get(t, 0))


## Game_Action.apply 包装：计段、命中后天逆鉾封印、万里锁溅射。返回本次（含溅射）的结果
static func apply(logic, u, skill: Dictionary, t) -> Array:
	var id := int(skill.get("id", 0))
	if is_main(id) and not internal and action.has("count"):
		action.index = int(action.index) + 1
	var used: bool = t.is_alive() or int(skill.get("scope", 0)) in [9, 10]
	var r: Dictionary = logic.apply(u, skill, t)
	var out := [r]
	if not (used and not r.missed and not r.evaded):
		return out
	if id == MAIN[3]:
		logic._state_add(t, SEAL)
		if t.state_ids.has(SEAL):
			seal_charges[t] = maxi(maxi(seal_count(t), 1), 2 if awakened(u, id) else 1)
	if spread_rate == 0.0 and id == MAIN[1]:
		out.append_array(_spread(logic, u, skill, t, 0.50 if awakened(u, id) else 0.33))
	return out


## spread：对其余活着的敌人各打一次内部行动（不判黑闪、不再溅射）
static func _spread(logic, u, skill: Dictionary, source, rate: float) -> Array:
	var out := []
	internal = true
	spread_rate = rate
	XBlackFlash.nested += 1
	for e in logic.alive(logic.enemies):
		if e != source:
			out.append(logic.apply(u, skill, e))
	XBlackFlash.nested -= 1
	spread_rate = 0.0
	internal = false
	return out


## Game_Action.applyGlobal 包装（付费之后）：带封印 2634 的行动者用主动技能（非物品、非普攻、非防御）时这次失效，扣一次，
## 扣完去状态；之后整段行动序列跳过（processActionSequenceCheck、startAction 清目标）。true＝失效
static func suppressed(logic, u, skill: Dictionary) -> bool:
	if XBattleLogic.is_item(skill) or u.is_attack(skill) or int(skill.get("id", 0)) == XBattleLogic.GUARD_SKILL or not u.state_ids.has(SEAL):
		return false
	var left := maxi(0, maxi(seal_count(u), 1) - 1)
	seal_charges[u] = left
	if left == 0:
		logic._state_remove(u, SEAL)
	if own(u):
		action = {}  # 失效的切换不换形态
	return true


## BattleManager.endAction 包装（原 endAction 之后）：切换技能换形态；清本次行动
static func finish(logic, u, _skill) -> void:
	if not own(u):
		return
	var shape = action.get("switch")
	action = {}
	if shape != null:
		set_shape(logic, u, int(shape))


## CodexToji.recruit()：入队了返回提示行，已在队返回空
static func recruit(s: XState) -> Array:
	if s.party.has(ACTOR):
		return []
	var a := s.actor(ACTOR)
	var slot := a.equip_slots().find(int(XDB.rec("Armors", ARMOR).get("etypeId", 0)))
	if slot < 0:
		push_error("[xiyou] 藏兵咒灵装备槽不可用")
		return []
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
		a.refresh_passive()  # changeEquip 刷新特性与被动
	s.add_actor(ACTOR)
	return RECRUIT_TEXT.duplicate()
