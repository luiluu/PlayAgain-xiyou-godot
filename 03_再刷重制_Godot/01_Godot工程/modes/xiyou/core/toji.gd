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
## - 暴君（addState／addDebuff 包装）：负面状态（不是难度系统状态、阵亡与形态以外；限制行动的、BuffType 不在祝福／变身／魔法／
##   合剂／食物／愤怒／共鸣里的、没有 BuffType 时名字带毒灼诅咒封印等的）与弱化都加不上；学暴君（learnSkill 包装）与 repair 时清掉
##   身上的负面状态与弱化。O-138（优化登记）：原版清弱化调的 removeDebuff 在 MV 里不存在，清完负面状态碰到第一个弱化就抛错，
##   弱化留着；重制照说明清掉（CLEAR_DEBUFFS）。正常游戏里甚尔 1 级就学会暴君、弱化本来加不上，碰不到。
## - 命中／闪避／暴击：天与咒缚物理行动命中＋影速（速度比超出 1 的部分 ×0.15，至多 0.3）、被物理行动打时闪避＋影速；
##   五感时主技能与武器库不被闪避，主技能、武器库、反弹读到的目标暴击闪避 ×0.34（西游闪避公式为 0，命中常满，参照只看得出后两项）。
## 第三期：
## - 术师杀手 10207（伤害钩子 toji 受击一支＋apply 包装）：被别人的魔法生命伤害（不是反弹本身）打时受伤 ×0.2；结算（含
##   Confirm 与固定减伤）为正时记反弹：基数 0.264×结算值÷0.2、属性取结算行的属性；那次 apply 后（出手者还活着）甚尔用
##   术师杀手·反弹 10224 打回出手者：内部行动、不判黑闪、不再触发反弹，技能属性换成记下的属性（原版 item() 包装），
##   公式＝反弹基数（结算里减防项为 0），钩子按魔法、五感魔防率 ×0.67、暴君 ×3、成长 outputGrowth(非主)，不吃藏兵咒灵。
## - 武器库 10211（进阶 1 次后，startAction 包装）：主技能 50% 先用随机另一把可切咒具的武器库技能（10220 游云、10223 万里锁、
##   10221 释魂刀、10222 天逆鉾）打一次目标（倒了换第一个活着的；内部行动、不判黑闪）；本次主技能借它的特效：借游云追加次数＋1、
##   借万里锁每段 16% 溅射、借释魂刀物理穿透 0.33、借天逆鉾且 50% 掷中时附封印（武器库·天逆鉾本身同样掷中才封）；
##   武器库·万里锁自己也 16% 溅射。熟练度（_actionMastery）重制恒 0，不记。随机数 rule 流 toji_armory／toji_pick／toji_spear。
## 第四期：智能 AI 档案（ai_profile、ai_damage，XSmartAI 的 profile 与估伤读）。
## 未移植：说明框熟练度行（画面）；读档时 repair。
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

## O-138（优化登记）：学暴君／repair 时清弱化。false＝照原版（removeDebuff 不存在，抛错后弱化留着）
static var CLEAR_DEBUFFS := true
const POSITIVE_BUFF_TYPES := ["祝福", "变身", "魔法", "合剂", "食物", "愤怒", "共鸣"]
static var _negative_re := RegEx.create_from_string("中毒|毒|灼|诅咒|封印|眩晕|麻痹|虚弱|减速|沉默|睡眠|冻结|流血|失效")
static var _buff_type_re := RegEx.create_from_string("<BuffType:([^>]+)>")
static var _system_states := {}

## 战斗内：开战设、结束清（复活回形态只在战斗中）。不存战斗对象本身：静态变量拿着它，没走 end_battle 的测试退出时引擎会崩
static var battling := false
## 本次行动（startAction 记，endAction 清）：switch 切换到的形态；count 段数、extra 追加次数、index 第几段、done 段已打完
static var action := {}
## 内部行动（溅射）进行中与它的倍率
static var internal := false
static var spread_rate := 0.0
## 天逆鉾封印次数（_tojiSealCharges）；状态不在时视为没有
static var seal_charges := {}
const SLAYER := 10207
## 术师杀手：本次 apply 记下的反弹（target 甚尔、source 出手者、base、element）；反弹进行中的基数
static var pending := {}
static var no_reflect := false
static var reflect_base := 0.0
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
	return output_growth_at(int(a.level), main)


## 按等级算（说明卡用：预览没有角色时取说明卡的等级）
static func output_growth_at(level: int, main: bool) -> float:
	var lv := maxf(1.0, float(level))
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
	clear_debuffs(a)
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
	return reflect_base if id == REFLECT else 0.0  # action._tojiReflectBase


## 伤害钩子 toji（只含自己的技能；术师杀手受击分支第三期）
static func damage_ops(item: Dictionary, a) -> Array:
	var id := int(item.get("id", 0))
	if not own(a) or not (is_main(id) or is_random(id) or id == REFLECT):
		return []
	var ops := [{"op": "set", "field": "mode", "value": "magical" if id == REFLECT else "physical"}]
	if knows(a, SENSES):
		ops.append({"op": "mul", "field": "physicalDefenseRate", "value": 0.67})
		ops.append({"op": "mul", "field": "magicalDefenseRate", "value": 0.67})
	ops.append({"op": "set", "field": "physicalIncomingPierce", "value": (0.80 if awakened(a, id) else 0.66) if id == MAIN[2] else (0.33 if id == RANDOM[2] or (is_main(id) and int(action.get("borrow", -1)) == 2) else 0.0)})
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


## CodexDifficulty.isSystemState：难度系统技能（XState.difficulty_managed_skills 与分档技能）备注 <Start(WT)PushStateN: 100%> 给的状态
static func system_state(id: int) -> bool:
	if _system_states.is_empty():
		var re := RegEx.create_from_string("(?i)<Start(?:WT)?PushState(\\d+):\\s*100%>")
		for sid in XState.difficulty_managed_skills() + XState.DIFFICULTY_ROLE_SKILLS:
			for m in re.search_all(str(XDB.rec("Skills", int(sid)).get("note", ""))):
				_system_states[int(m.get_string(1))] = true
		_system_states[-1] = true  # 已建表
	return _system_states.has(id)


## negativeState
static func negative_state(id: int) -> bool:
	if system_state(id) or id == DEATH or SHAPES.has(id):
		return false
	var st := XDB.rec("States", id)
	if st.is_empty():
		return false
	if int(st.get("restriction", 0)) > 0:
		return true
	var m := _buff_type_re.search(str(st.get("note", "")))
	if m:
		return not POSITIVE_BUFF_TYPES.has(m.get_string(1))
	return _negative_re.search(str(st.get("name", ""))) != null


## Game_Actor.addState 包装：暴君挡负面状态
static func blocks_state(a, id: int) -> bool:
	return knows(a, TYRANT) and negative_state(id)


## T.clearDebuffs（学了暴君才清）：去掉负面状态，再去掉弱化（CLEAR_DEBUFFS，见上）
static func clear_debuffs(a) -> void:
	if not knows(a, TYRANT):
		return
	for id in a.state_ids.duplicate():
		if negative_state(int(id)):
			a.remove_state(int(id))
	if CLEAR_DEBUFFS:
		for p in a.buffs.size():
			if a.buffs[p] < 0:
				a.buffs[p] = 0
				a.buff_turns[p] = 0


## Game_Actor.learnSkill 包装：学暴君时清
static func learned(a, id: int) -> void:
	if id == TYRANT and own(a):
		clear_debuffs(a)


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
	battling = true
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
	battling = false
	action = {}


## Game_Actor.removeState 包装：战斗中复活（去掉阵亡）且没有形态时回游云
static func revived(a, id: int, had: bool) -> void:
	if not battling or id != DEATH or not had or not own(a) or not a.is_alive() or SHAPES.any(func(s): return a.state_ids.has(s)):
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
## 返回武器库追击打出的结果（记进行动日志）
static func begin(logic, u, skill: Dictionary, targets: Array) -> Array:
	if not own(u):
		return []
	action = {}
	var id := int(skill.get("id", 0))
	if SWITCH.has(id):
		action.switch = SWITCH.find(id)
		return []
	if not is_main(id) or targets.is_empty():
		return []
	var index := MAIN.find(id)
	var extra := maxi(0, floori(float(u.attack_times_add())))
	var target = targets[0]
	targets.clear()
	action.merge({"extra": extra, "index": 0, "borrow": -1, "spear": false, "done": false})
	var out := []
	# 武器库（进阶后 10211）：50% 先用随机另一把可切咒具的武器库技能打一次，本次主技能借它的特效
	if knows(u, ARMORY) and rank(u) >= 1 and logic._float("toji_armory") < 0.5:
		var pool := range(4).filter(func(n): return n != index and eligible_shape(u, n))
		if not pool.is_empty():
			var pick: int = pool[floori(logic._float("toji_pick") * pool.size())]
			var alive_foes: Array = logic.alive(logic.enemies)
			var aim = target if target.is_alive() else (alive_foes[0] if not alive_foes.is_empty() else null)
			if aim != null:
				var spear: bool = pick == 3 and logic._float("toji_spear") < 0.5
				action.spear = spear
				internal = true
				XBlackFlash.nested += 1
				out = apply(logic, u, XDB.rec("Skills", RANDOM[pick]), aim)
				XBlackFlash.nested -= 1
				internal = false
				action.borrow = pick
				if pick == 0:
					extra += 1
				if not target.is_alive():
					alive_foes = logic.alive(logic.enemies)
					target = alive_foes[0] if not alive_foes.is_empty() else null
	if target == null:
		action = {}
		return out
	targets.append(target)
	action.extra = extra
	action.count = 5 + extra if index == 0 else (1 if index == 2 else 1 + extra)
	return out


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
	var borrow := int(action.get("borrow", -1))
	var spear: bool = bool(action.get("spear", false))
	if (is_main(id) and (id == MAIN[3] or (borrow == 3 and spear))) or (id == RANDOM[3] and spear):
		logic._state_add(t, SEAL)
		if t.state_ids.has(SEAL):
			seal_charges[t] = maxi(maxi(seal_count(t), 1), 2 if id == MAIN[3] and awakened(u, id) else 1)
	if spread_rate == 0.0 and is_main(id) and (id == MAIN[1] or borrow == 1):
		out.append_array(_spread(logic, u, skill, t, (0.50 if awakened(u, id) else 0.33) if id == MAIN[1] else 0.16))
	elif spread_rate == 0.0 and id == RANDOM[1]:
		out.append_array(_spread(logic, u, skill, t, 0.16))
	return out


## spread：对其余活着的敌人各打一次内部行动（不判黑闪、不再溅射）
static func _spread(logic, u, skill: Dictionary, source, rate: float) -> Array:
	var out := []
	internal = true
	spread_rate = rate
	XBlackFlash.nested += 1
	for e in logic.alive(logic.enemies):
		if e != source:  # 子行动 child.apply 也走云裳包装（各自一帧，觉醒时各引爆自己目标一根针）
			out.append_array(XYunshang.child(logic, u, skill, e, func(): return [logic.apply(u, skill, e)]))
	XBlackFlash.nested -= 1
	spread_rate = 0.0
	internal = false
	return out


## shadowRate：快的一方相对慢的一方速度比超出 1 的部分 ×0.15，夹到 0～cap
static func _shadow(faster, slower, cap: float) -> float:
	return minf(cap, maxf(0.0, float(faster.agi) / maxf(1.0, float(slower.agi)) - 1) * 0.15)


## itemHit 包装：天与咒缚的物理行动命中＋影速（夹值在外层）
static func hit_bonus(u, skill: Dictionary, t) -> float:
	return _shadow(u, t, 0.30) if XDamage.is_physical(skill) and knows(u, NO_MP) else 0.0


## itemEva 包装：五感时主技能与武器库不被闪避
static func sure(u, skill: Dictionary) -> bool:
	var id := int(skill.get("id", 0))
	return knows(u, SENSES) and (is_main(id) or is_random(id))


## itemEva 包装：天与咒缚被物理行动打时闪避＋影速
static func eva_bonus(u, skill: Dictionary, t) -> float:
	return _shadow(t, u, 0.30) if XDamage.is_physical(skill) and knows(t, NO_MP) else 0.0


## itemCri 包装：五感时主技能、武器库、反弹读到的目标暴击闪避 ×0.34
static func cev_rate(u, skill: Dictionary) -> float:
	var id := int(skill.get("id", 0))
	return 0.34 if knows(u, SENSES) and (is_main(id) or is_random(id) or id == REFLECT) else 1.0


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


# ---- 第三期：术师杀手 ----

static func _slayer_hit(item: Dictionary, a, b) -> bool:
	return knows(b, SLAYER) and XDamage.is_magical(item) and int(item.get("damage", {}).get("type", 0)) == 1 and a != b and not no_reflect


## 伤害钩子 toji 受击一支：受伤 ×0.2
static func incoming_ops(item: Dictionary, a, b) -> Array:
	return [{"op": "mul", "field": "incomingMultiplier", "value": 0.2}] if _slayer_hit(item, a, b) else []


## f.after：结算值为正时记反弹（返回原结算值）
static func record(a, item: Dictionary, b, calc: Dictionary, value: float) -> float:
	if _slayer_hit(item, a, b) and value > 0.0:
		var row: Dictionary = calc.get("breakdown", {}).get("row", {})
		pending = {"target": b, "source": a, "base": 0.264 * value / 0.2, "element": int(row.get("element", item.get("damage", {}).get("elementId", 0)))}
	return value


## reflect：出手者那次 apply 之后，甚尔用 10224 打回去
static func reflect(logic, target) -> Array:
	var p := pending
	pending = {}
	if p.is_empty() or p.target != target or not p.source.is_alive():
		return []
	var item: Dictionary = XDB.rec("Skills", REFLECT).duplicate(true)
	item.damage.elementId = int(p.element)
	internal = true
	no_reflect = true
	reflect_base = float(p.base)
	XBlackFlash.nested += 1
	var out := XYunshang.child(logic, target, item, p.source, func(): return [logic.apply(target, item, p.source)])  # 子行动也走云裳包装（敌人出手前引爆身上全部针）
	XBlackFlash.nested -= 1
	reflect_base = 0.0
	no_reflect = false
	internal = false
	return out


# ---- 第四期：智能 AI 档案 ----

## T.aiProfile（登记进 CodexSmartAI 的 profile，只读：不换形态、不付费、不掷随机数）：
## 切换技能（可切且不是当前形态）给后续主技能 followupSkill、铺垫 1 次行动；主技能给段数 hits（游云 5＋追加＋觉醒 1，
## 释魂刀 1〔追加折进公式〕，万里锁／天逆鉾 1＋追加×0.2〔第 2 段起 ×0.8 而非 ×4〕）、倍率 multiplier（学暴君 成长(主)×3，
## 否则 成长(非主)；藏兵咒灵 ×1.11；觉醒 ×1.2）、溅射 splash（万里锁 0.33／觉醒 0.50）、穿透 pierce（释魂刀 0.66／觉醒 0.80）。
## extra 是追加次数（原版写进 action._tojiExtra 给估伤读）。觉醒＝学了伏黑、带觉醒状态且黑闪觉醒未到期。其余返回空
static func ai_profile(a, skill: Dictionary) -> Dictionary:
	if not own(a):
		return {}
	var id := int(skill.get("id", 0))
	var si := SWITCH.find(id)
	if si >= 0:
		return {"followupSkill": MAIN[si], "setupActions": 1} if eligible_shape(a, si) and current_shape(a) != si else {}
	var index := MAIN.find(id)
	if index < 0:
		return {}
	var extra := maxi(0, floori(float(a.attack_times_add())))
	var awake: bool = knows(a, AWAKENING) and a.state_ids.has(XBlackFlash.STATE) \
		and int(XBlackFlash._temp.get(a, {}).get("expires", -1)) >= XBlackFlash.round
	var hits := float(5 + extra + (1 if awake else 0)) if index == 0 else 1.0 if index == 2 else 1.0 + extra * 0.2
	var mult := (output_growth(a, true) * 3 if knows(a, TYRANT) else output_growth(a, false)) * (1.11 if weapon(a) else 1.0) * (1.2 if awake else 1.0)
	return {"hits": hits, "multiplier": mult, "splash": (0.50 if awake else 0.33) if index == 1 else 0.0,
		"pierce": (0.80 if awake else 0.66) if index == 2 else 0.0, "extra": extra}


## 智能 AI 估伤（CodexSmartAI.safeDamage 的 CodexToji.damage 一支，主技能 10216～10219）：不在结算里，减防项照算
## （目标防御，五感 ×0.67）；AI 的行动没有第几段，万里锁／天逆鉾按第 1 段 ×4；释魂刀 ×(5＋追加)×0.95
static func ai_damage(a, t, id: int, extra: int) -> float:
	if not own(a) or t == null or not is_main(id):
		return 0.0
	var guard := maxf(0.0, float(t.def)) * (0.67 if knows(a, SENSES) else 1.0)
	var base := maxf(0.0, 7777 * maxf(0.0, float(a.atk)) + 888 * maxf(0.0, float(a.mhp)) - guard)
	if id == MAIN[0]:
		return base
	if id == MAIN[2]:
		return base * (5 + extra) * 0.95
	return base * 4.0


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
