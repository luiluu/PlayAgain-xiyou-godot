class_name XBattleCommonEvent
extends RefCounted
## 战斗中技能／物品带的公共事件（使用效果 44）。冻结 v0.28 的流程：
## - YEP_BattleEngineCore 把 Game_Action.applyGlobal 在战斗中关掉，改由行动序列预约：默认收尾段的 ACTION COMMON EVENT
##   （actionActionCommonEvent）把这次行动道具的每个 44 效果依次 $gameTemp.reserveCommonEvent——单槽，后一个盖前一个；
##   ActSeqPack1 的 COMMON EVENT: X 没有事件在跑时同样预约（有事件在跑时插成子事件立即执行，重制排到当前事件之后，见交付单）。
## - 行动结束后 BattleManager.updateEventMain → Game_Troop.setupBattleEvent：解释器空闲时预约的公共事件优先于敌群页
##   （setupReservedCommonEvent），跑完下一次检查再看敌群页或新的预约。YEP 的 checkBattleEnd 在行动刚结束的 actionList 阶段
##   与事件进行中都不判定，所以**打倒最后一只敌人后预约的公共事件照样跑完**（参照 thunder_battle_end：84 仍强制 533），之后才胜利；
##   重制的战斗画面在打赢／打输后、进结算前先跑一次（XBattleScene._main），无界面 run_turn 本来就先查事件。
## 重制：预约记在 XBattleLogic 的 meta "battle_ce"；XBattleLogic._drive_events 选页之前调 take 取成 XBattleEventRunner 执行，
## 指令与敌群页同一套（MVEventCore＋战斗环境），没翻译的记进 XBattleLogic.common_event_skipped（敌群页的另记 troop_event_skipped）。
## 一次事件检查里接连预约（强制行动再预约）最多 CHAIN_LIMIT 次，防止条件写错时死循环（原版会一直跑）。
## Star_PetSystem 的 PetGet 读「最后一个 setItem 的行动」：用道具时记在 meta "last_item_action"（XPetCapture.pet_get 读）。

const CHAIN_LIMIT := 64


static func reserve(logic, id: int) -> void:
	if id > 0:
		logic.set_meta("battle_ce", id)


## ACTION COMMON EVENT：这次行动的道具里每个 44 效果依次预约（单槽，最后一个生效）
static func reserve_action(logic, user, item: Dictionary, targets: Array) -> void:
	if XBattleLogic.is_item(item):
		logic.set_meta("last_item_action", {"user": user, "item": item, "target": targets[0] if not targets.is_empty() else null})
	for e in item.get("effects", []):
		if int(e.code) == 44:
			reserve(logic, int(e.dataId))


static func reserved(logic) -> int:
	return int(logic.get_meta("battle_ce", 0))


static func last_item_action(logic) -> Dictionary:
	return logic.get_meta("last_item_action", {})


## setupBattleEvent 的预约分支：取走预约，返回执行游标（没有时 null）
static func take(logic) -> XBattleEventRunner:
	var id := reserved(logic)
	if id <= 0:
		return null
	logic.remove_meta("battle_ce")
	var ce := XDB.rec("CommonEvents", id)
	if ce.is_empty():
		return null
	var n := int(logic._check.get("ce_chain", 0)) + 1
	logic._check.ce_chain = n
	if n > CHAIN_LIMIT:
		push_warning("XBattleCommonEvent: 公共事件 %d 接连预约超过 %d 次，停下" % [id, CHAIN_LIMIT])
		return null
	var r := XBattleEventRunner.new(logic, ce.get("list", []), logic._check.get("first"))
	r.set_meta("page", -1)
	r.set_meta("common_event", id)
	return r
