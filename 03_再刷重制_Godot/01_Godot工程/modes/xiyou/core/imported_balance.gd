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


static func is_disabled_actor(b) -> bool:
	return DISABLED_ACTORS.has(_actor_id(b))


static func is_disabled_horn(item: Dictionary) -> bool:
	return XBattleLogic.is_item(item) and DISABLED_HORNS.has(int(item.get("id", 0)))


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
