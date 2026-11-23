class_name XImportedBalance
extends RefCounted
## 导入角色平衡（正式 js/codex/runtime/installImportedBalanceRuntime.js，CodexImportedBalance）：
## v0.62.12 新源：v0.29 起去掉 12.27 异界制约、v0.36 连拳一也解除，outgoingRate 恒为 1（结算与持续伤害都不再缩放）；
## 共用伤害技能的公式 ÷10 也去掉了（evalDamageFormula 包装两支都返回 value）；禁用名单扩成 10 人／10 个号角。
## 下面几条是旧源（v0.28）口径，缩放入口保留，倍率为 1 时都不生效：
## - 141～166 号角色造成的伤害结算 ×outgoingRate（163＝0.001，其余 0.01），向下取整、不保底 1；在最外层先缩放，
##   之后才走真气减伤、护盾吸收等（executeHpDamage／executeMpDamage 的包装在最外）。
## - 只缩放打到别人身上的（行动者打自己不缩放），魔法反射回行动者自己时照样缩放；治疗（负值）不缩放。
## - 行动序列 HP／MP 减少（actionHpModify／actionMpModify 的 gainHp／gainMp）对序列目标同样缩放。
## - 持续伤害：敌人身上由导入角色附加的状态，其负的 HP 再生率（特性 22／7）那一部分 ×0.01（固定 0.01，163 也一样）。
## - 143／144／145／157／160 禁用：canUse 全否；其行动与序列对目标都无效，useItem 也直接返回（不付费）；禁用号角（物品 255／256／257／394／440）同理（不扣物品，菜单「使用」灰）。
## - 共用伤害技能的公式值 ÷10（formula_value，CodexImportedEffects）。
## 未移植：导入角色专属装备的效果补丁（CodexImportedEffects.patches）、行动内公式直接 gainHp／setHp 的缩放、Bailong A.C.S 合并尾段、反击状态脚本 1341／2550 的来源改写（Godot 无对应机制，见交付单）。

const DISABLED_ACTORS := [141, 143, 144, 145, 146, 152, 157, 160, 161, 166]
const DISABLED_HORNS := [245, 255, 256, 257, 274, 359, 394, 440, 456, 494]
const DOT_RATE := 0.01

## v0.62.12 installIntegratedV029Runtime（v0.30 起，CodexV029.hiddenActors）：这 7 名从队伍、仓库、出战栏移走（新局／读档 U.sync），
## 仓库列表（Star_Window_PartyList.createActorOrder）与人物图鉴目录（Window_ActorBookIndex.refresh）里不出现。
## 都在 DISABLED_ACTORS 里（add_actor 本来就不让入队），所以出战栏两边都没有；差的是图鉴目录和仓库列表。
## O-299（V029 隐藏角色）：V029_HIDE_ACTORS = false 回到 v0.28（图鉴目录照列全部角色槽）。
const HIDDEN_ACTORS := [141, 146, 152, 157, 160, 161, 166]
static var V029_HIDE_ACTORS := true


static func is_hidden_actor(id: int) -> bool:
	return (V029_HIDE_ACTORS and HIDDEN_ACTORS.has(id) and not released_actor(id)) or XGojo.hidden(id)  # 五条悟只在天启篇


## 【cc·未经审查】解放苍龙破晓（Kyo 11-11，O-313）：开关开着时 146 不算停用、不隐藏，号角 274 不算停用号角
## （回到兑换大厅号角商店，Map132 EV16 本来就有这一行）。招募照旧走 CE2506（入队、送法宝【上邪】），超强者门槛照旧。
## 名单常量不动（参照测试按原版比），凡是判断停用／隐藏的地方都改问下面几个函数。RELEASE_CANGLONG = false 回原版。
static var RELEASE_CANGLONG := true
const CANGLONG := 146
const CANGLONG_HORN := 274


static func released_actor(id: int) -> bool:
	return (RELEASE_CANGLONG and id == CANGLONG) or (RELEASE_XUFENG and id == XUFENG)


## 【cc·未经审查】解放徐凤年（Kyo 11-23，D262，T411，O-待定）：开关开着时 152 不算停用、不隐藏，号角 359 不算停用号角
## （Map132 EV16 号角商店本来就有这一行）。招募照旧走 CE2512（入队、送绣冬 76 与不朽法宝 143），超强者门槛照旧。
## 名单常量不动；RELEASE_XUFENG = false 回原版（参照测试由 XCanglong.original_data 一并关掉）。
static var RELEASE_XUFENG := true
const XUFENG := 152
const XUFENG_HORN := 359
## 号角 359 上架门槛（D262「漩涡三阶段后开放」）：
## Kyo 11-23 定先做漩涡三阶段（T412：看完二阶后下一次进大厅播三阶，徐凤年从天而降），看过 rift3 才上架；没看过的新档买不到。已有 359 号角或 152 已在队伍／仓库的老档不受影响（始终上架）。
## XUFENG_HORN_GATE = false 回到「解放即上架」。
static var XUFENG_HORN_GATE := true
## 天启篇候选池（抽阵容）放不放 152：天启篇技能卡还没给徐凤年写（skill_rework.json 0 条，T204 K_SKIP no_damage_row），
## 先不放；技能卡接线、量数过线后改 true。只管天启篇抽阵容（XTianqi._disabled），西游档不看它。
static var XUFENG_TIANQI := false


## 漩涡三阶段过场看过没有（T412 交出的 CodexWhisper 键 rift3，记在配置 codexWhisperSeen，全存档共用，同 rift2）
const XUFENG_WHISPER := "rift3"


static func xufeng_gate_met() -> bool:
	return XConfig.whisper_seen(XUFENG_WHISPER)


static func xufeng_horn_on_sale() -> bool:
	if not XUFENG_HORN_GATE or xufeng_gate_met():
		return true
	var s: XState = XState.current
	return s != null and (s.item_count(XUFENG_HORN) > 0 or s.saved_actors.has(XUFENG) or s.party.has(XUFENG))


## 苍龙破晓号角 274 上架条件（Kyo 11-15，#005）：要等漩涡二阶段过场（CodexWhisper 'rift2'）看过之后才进 Map132 EV16 商店；
## 没看过的新档买不到。已经有 274 号角或 146 已入队的老档不受影响（始终上架）。HORN_AFTER_RIFT2 = false 回到「解放即上架」。
static var HORN_AFTER_RIFT2 := true


static func canglong_horn_on_sale() -> bool:
	if not HORN_AFTER_RIFT2 or XConfig.whisper_seen("rift2"):
		return true
	var s: XState = XState.current
	return s != null and (s.item_count(CANGLONG_HORN) > 0 or s.saved_actors.has(CANGLONG) or s.party.has(CANGLONG))


## 改版向导 Map004 EV071「花橙、落芸、苍龙破晓、徐凤年……已停用」那一句（Kyo 11-23，T411 Q3）：解放开着的人从名单里删掉
## （苍龙 RELEASE_CANGLONG、徐凤年 RELEASE_XUFENG 各管各的；开关关着照原文）。XDB.map 读图时调，改开关后要清 map:4 缓存。
const GUIDE_MAP := 4
const GUIDE_EVENT := 71
const GUIDE_MARK := "已停用，不能招募"


static func patch_map(map_id: int, data) -> void:
	if map_id != GUIDE_MAP or not data is Dictionary or not (RELEASE_CANGLONG or RELEASE_XUFENG):
		return
	var events: Array = data.get("events", [])
	if events.size() <= GUIDE_EVENT or not events[GUIDE_EVENT] is Dictionary:
		return
	for p in events[GUIDE_EVENT].get("pages", []):
		for c in (p as Dictionary).get("list", []):
			if int(c.get("code", 0)) != 401 or not str(c.parameters[0]).contains(GUIDE_MARK):
				continue
			var line := str(c.parameters[0])
			if RELEASE_CANGLONG:
				line = line.replace("苍龙破晓、", "")
			if RELEASE_XUFENG:
				line = line.replace("徐凤年、", "")
			c.parameters[0] = line


## 号角编号是不是停用号角（商店过滤、能否购买、菜单「使用」灰）
static func horn_id_disabled(id: int) -> bool:
	return DISABLED_HORNS.has(id) and not (RELEASE_CANGLONG and id == CANGLONG_HORN) and not (RELEASE_XUFENG and id == XUFENG_HORN)


## B.migrateParty（读档 extractSaveContents 包装；新局、initializeBattleMembers 等时也跑，重制 add_actor 本来就拦，只剩读档要做）：
## 停用角色从队伍挪进仓库末尾（只挪编号，角色数据不动），出战栏里的清成 0；队伍挪空了按 仓库里第一名可用的 → 角色 1 补一名
## （从仓库拿走）；出战栏全空就放队伍第一名。返回有没有改动。（V029 隐藏的 7 名之后在仓库列表里滤掉，见 XActorWarehouse.stored）
static func migrate_party(s: XState) -> bool:
	var retired: Array[int] = []
	for id in s.party + s.battle_slots:
		if int(id) > 0 and is_disabled_actor(int(id)) and not retired.has(int(id)):
			retired.append(int(id))
	if retired.is_empty():
		return false
	for id in retired:
		if not s.saved_actors.has(id):
			s.saved_actors.append(id)
	s.party.assign(s.party.filter(func(id): return not is_disabled_actor(int(id))))
	if s.party.is_empty():
		var stored := s.saved_actors.filter(func(id): return int(id) > 0 and not is_disabled_actor(int(id)) and not XDB.rec("Actors", int(id)).is_empty())
		var rep := int(stored[0]) if not stored.is_empty() else 1
		s.party.append(rep)
		s.saved_actors.erase(rep)
	for i in s.battle_slots.size():
		if is_disabled_actor(int(s.battle_slots[i])):
			s.battle_slots[i] = 0
	if not s.battle_slots.is_empty() and not s.battle_slots.any(func(id): return int(id) > 0):
		s.set_battle_slot(0, s.party[0])
	return true

## 当前行动者（弱引用）：YEP 附加状态时把它记成状态来源（stateOrigin），持续伤害据此判断。用 set_acting／acting_battler 读写。
static var _acting: WeakRef


static func set_acting(b: XBattler) -> void:
	_acting = weakref(b) if b != null else null


static func acting_battler() -> XBattler:
	return _acting.get_ref() if _acting != null else null


## 状态来源（XBattler.state_origins 里的弱引用）
static func origin(b: XBattler, state_id: int) -> XBattler:
	var w = b.state_origins.get(state_id)
	return w.get_ref() if w is WeakRef else null


static func outgoing_rate(_b) -> float:
	return 1.0  # v0.36：B.outgoingRate = function(actor) { return 1; }


## 测试用：临时当作没停用的角色（weapon_unleash 参照量 166 专武 93 时把 166 从停用名单拿掉，用例输入 enabledDisabledActor）
static var probe_enabled: Array = []

static func is_disabled_actor(b) -> bool:
	var id := _actor_id(b)
	return (DISABLED_ACTORS.has(id) and not probe_enabled.has(id) and not released_actor(id)) or XGojo.hidden(id) or XGojo.locked(id)  # 五条悟只在天启篇、要解锁最强之名


static func is_disabled_horn(item: Dictionary) -> bool:
	return XBattleLogic.is_item(item) and horn_id_disabled(int(item.get("id", 0)))


## 禁用角色或禁用号角：行动对目标无效
static func blocks(subject: XBattler, item: Dictionary) -> bool:
	return is_disabled_actor(subject) or is_disabled_horn(item)


## 这次结算要不要缩放：行动者是导入角色，且目标不是自己（魔法反射回自己时例外）
static func scales(subject: XBattler, target: XBattler, reflected := false) -> bool:
	return subject != null and target != null and outgoing_rate(subject) != 1.0 and (subject != target or reflected)


static func reduced(value: float, subject: XBattler) -> float:
	return floorf(value * outgoing_rate(subject))


## CodexImportedEffects（同文件「12.27 authored effect/skill coefficient balance」）：导入角色 141～166 用不是本人专属的
## 伤害技能（伤害类型 1／2／5／6；本人技能 9906～10121 与 10169 除外，普攻等共用技能都算）时，Game_Action.evalDamageFormula ÷10。
## 混合模式求偏导的能力值代理（XDamage._ParamProxy）按它代理的行动者算，保证权重比例不变。
static func formula_value(value: float, _a, _item: Dictionary) -> float:
	return value  # v0.62.12：旧源对导入角色共用伤害技能 ÷10，新源两支都返回 value


static func _actor_id(b) -> int:
	if b is int or b is float:
		return int(b)
	return int(b.actor_id) if b is XActor else 0
