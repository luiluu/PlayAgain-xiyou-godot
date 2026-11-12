class_name XLobbyDebugNpc
extends RefCounted
## 大厅两个原先当调试事件没放的 NPC（切片 keepEvents 不列 Map004 事件 55、69；玩家 v0.01.01 反馈「一键解锁图鉴的 NPC 保留着」，Kyo 11-12 定）。
##
## - 事件 55「全图鉴获取」（原版一直显示）：放回大厅，只做「EnemyBook complete」（怪物图鉴全部登记）和「图鉴获取完毕」一句；
##   原版前面的 GetAcReward 一串（全部成就）和 ConfigManager.DesignationN（全部称号）连同两句「…获取完毕」去掉
##   （Kyo 11-12「成就和称号不一键解锁」）。回退开关 BOOK_NPC = false：不放这个 NPC（回到之前）；BOOK_ONLY = false：照原版整页都做。
## - 事件 69「测试游戏角色技能」（一键 99 级）：照原版 installTestGateRuntime（v0.53 起）放进地图，第 1 页以开关 2501 为条件，
##   进地图和每帧把 2501 对齐成测试模式开着没有（只在变了时写、刷新事件），测试模式没开时是空页、看不见（Kyo 11-12「隐藏起来，只开放给测试模式」）。
##   回退开关 TEST_GATE = false：不放这个 NPC、不同步开关（回到之前）。
## O-354、O-355。

const MAP := 4
const BOOK_EV := 55
const TEST_EV := 69
const TEST_SWITCH := 2501
static var BOOK_NPC := true
static var BOOK_ONLY := true
static var TEST_GATE := true


## 切片 keepEvents 之外也要放进地图的事件
static func keep_event(map_id: int, ev_id: int) -> bool:
	if map_id != MAP:
		return false
	return (BOOK_NPC and ev_id == BOOK_EV) or (TEST_GATE and ev_id == TEST_EV)


## XDB.map 读图时改事件 55：只留怪物图鉴那一段
static func patch_map(map_id: int, data) -> void:
	if map_id != MAP or not BOOK_ONLY or not (data is Dictionary):
		return
	var events: Array = data.get("events", [])
	if events.size() <= BOOK_EV or not (events[BOOK_EV] is Dictionary):
		return
	var pages: Array = events[BOOK_EV].get("pages", [])
	if pages.is_empty():
		return
	var list: Array = pages[0].get("list", [])
	var at := -1
	for i in list.size():
		var c: Dictionary = list[i]
		if int(c.code) == 356 and str(c.parameters[0]).strip_edges() == "EnemyBook complete":
			at = i
			break
	if at < 0:
		return  # 来源变了（没有图鉴那条）：不动
	pages[0].list = list.slice(at)


## installTestGateRuntime.sync：开关 2501 对齐测试模式；变了返回 true（调用方刷新事件）
static func sync(s: XState) -> bool:
	if not TEST_GATE or s == null:
		return false
	var on := XTestMode.enabled()
	if s.switch(TEST_SWITCH) == on:
		return false
	s.set_switch(TEST_SWITCH, on)
	return true
