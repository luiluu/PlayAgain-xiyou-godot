class_name XBulkPills
extends RefCounted
## 批量服用丹药（正式版 js/codex/runtime/installBulkPillsRuntime.js，CodexBulkPills v1）。
## - 支持 43 个丹药（凝血～九转 1685～1717 去掉 1701、养神丹 1726～1728、法宝经验丹 1901～1908 与 1987、1997）；
##   带公共事件的只认原版审过的那一个，且事件指令逐条和原版写死的结构一致（approved_event），否则整颗不支持、走原来的单颗使用。
## - 逐颗：库存与支持再查一次 → 使用者（可行动角色中 pha 最大者）→ 对队友的至少一个目标 testApply 有效 → 消耗、对目标逐效果、
##   applyGlobal 的公共事件；这一颗期间预约的公共事件先收集，审过的当场跑完（单槽不会被下一颗盖掉），没审过的连同后面的
##   按先进先出交给地图（XState.defer_common_events），批量就此结束。
## - 结束原因用原版中文：complete／等待已有事件／库存不足或道具已改变／当前没有可用角色／当前目标无法继续服用／后续事件交由地图执行。
## - 原版 fullyLearned（万灵增元丹 1497～1500 目标已学会时提示「目标已学会…」）在 Scene_Item.useItem 里，但 onActorOk 先看 canUse，
##   已学会时 testApply 为假直接蜂鸣（参照 bulk_pills_oracle.json learned），正式版走不到；重制不做。
## 参照：tests/fixtures/bulk_pills_oracle.json（mv_oracle/bulk_pills_probe.cjs）。画面入口见 ui/item_scene.gd。

## 法宝经验丹公共事件 → MagicWeaponAllGainExp 的经验
const EXP_EVENTS := {1188: 100, 1189: 200, 1192: 500, 1215: 5000, 1216: 50000, 1217: 1000000}
const EXP_ITEMS := [1901, 1902, 1903, 1906, 1907, 1908, 1987, 1997]
const EXP_ITEM_EVENTS := [1188, 1189, 1189, 1192, 1215, 1216, 1217, 1192]
## 每批最多连吃几颗再让出一帧（原版每帧最多 20 颗、8 毫秒）
const FRAME_BUDGET := 20

const COMPLETE := "complete"
const WAIT_EVENT := "等待已有事件"
const OUT_OF_STOCK := "库存不足或道具已改变"
const NO_USER := "当前没有可用角色"
const NO_TARGET := "当前目标无法继续服用"
const DEFERRED := "后续事件交由地图执行"


static func supported_ids() -> Array:
	var out := []
	for id in range(1685, 1701):
		out.append(id)
	for id in range(1702, 1718):
		out.append(id)
	out.append_array([1726, 1727, 1728])
	out.append_array(EXP_ITEMS)
	return out


## 物品该带的公共事件（没有为 0）
static func expected_event(item_id: int) -> int:
	# 1685～1692 → 1226、1693～1700 → 1227、1702～1709 → 1228、1710～1717 → 1229
	if item_id >= 1685 and item_id <= 1700:
		return 1226 + (item_id - 1685) / 8
	if item_id >= 1702 and item_id <= 1717:
		return 1228 + (item_id - 1702) / 8
	var i := EXP_ITEMS.find(item_id)
	return EXP_ITEM_EVENTS[i] if i >= 0 else 0


## toastScript：只认一句 $.toaster({message:'…'}) 或 '…'+$gameVariables.value(N)（N 要是该档的变量）
static func _toast_script(c: Dictionary, variable_id: int) -> bool:
	var p = c.get("parameters")
	if int(c.get("code", 0)) != 355 or not p is Array or p.size() != 1:
		return false
	var re := RegEx.create_from_string("^\\s*\\$\\.toaster\\(\\{\\s*message\\s*:\\s*'[^'\\\\\\r\\n]*'(?:\\+\\$gameVariables\\.value\\((\\d+)\\))?\\s*\\}\\);?\\s*$")
	var m := re.search(str(p[0]))
	if m == null:
		return false
	return int(m.get_string(1)) == variable_id if m.get_string(1) != "" else true


static func _same(a, b) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


## approvedEvent：法宝经验丹事件三条（356 MagicWeaponAllGainExp 经验、提示、结束）；四档丹药事件逐条比代码、缩进与参数
static func approved_event(event_id: int) -> bool:
	var ce := XDB.rec("CommonEvents", event_id)
	var list = ce.get("list")
	if ce.is_empty() or not list is Array:
		return false
	if EXP_EVENTS.has(event_id):
		return list.size() == 3 and int(list[0].code) == 356 and _same(list[0].parameters, ["MagicWeaponAllGainExp %d" % int(EXP_EVENTS[event_id])]) \
			and _toast_script(list[1], 0) and int(list[2].code) == 0
	if event_id < 1226 or event_id > 1229:
		return false
	var rank := event_id - 1226
	var v := 968 + rank
	var threshold: int = [240, 200, 120, 80][rank]
	var reward := 1497 + rank
	var unlock := 2466 + rank
	var schema := [
		[122, 0, [v, v, 1, 0, 1]], [355, 0, null],
		[111, 0, [1, v, 0, threshold, 0]], [126, 1, [reward, 0, 0, 1]],
		[121, 1, [unlock, unlock, 0]], [355, 1, null], [355, 1, null],
		[0, 1, []], [411, 0, []], [0, 1, []], [412, 0, []], [0, 0, []]]
	if rank == 3:
		schema.pop_back()
		for row in schema:
			row[1] += 1
		schema.push_front([111, 0, [1, v, 0, 80, 4]])
		schema.append_array([[0, 1, []], [412, 0, []], [0, 0, []]])
	if list.size() != schema.size():
		return false
	for i in range(schema.size()):
		var c: Dictionary = list[i]
		var row: Array = schema[i]
		if int(c.code) != row[0] or int(c.get("indent", 0)) != row[1]:
			return false
		if row[2] == null:
			if not _toast_script(c, v):
				return false
		elif not _same_numbers(c.get("parameters", []), row[2]):
			return false
	return true


## JSON 里数字载入后是浮点：按数值比
static func _same_numbers(a, b: Array) -> bool:
	if not a is Array or a.size() != b.size():
		return false
	for i in range(b.size()):
		if typeof(a[i]) in [TYPE_INT, TYPE_FLOAT] and typeof(b[i]) in [TYPE_INT, TYPE_FLOAT]:
			if float(a[i]) != float(b[i]):
				return false
		elif not _same(a[i], b[i]):
			return false
	return true


## supports：名单内、可消耗、是普通物品（不是装备、不是独立实例）；效果 44 恰好一条且是审过的那个事件，没有该带的事件时不许有 44
static func supports(item: Dictionary) -> bool:
	var id := int(item.get("id", 0))
	if item.is_empty() or not supported_ids().has(id) or not bool(item.get("consumable", false)) \
			or item.has("instanceId") or not item.has("itypeId"):
		return false
	var events: Array = item.get("effects", []).filter(func(e): return int(e.code) == 44)
	var expected := expected_event(id)
	if expected > 0:
		return events.size() == 1 and int(events[0].dataId) == expected and approved_event(expected)
	return events.is_empty()


static func stock(s: XState, item: Dictionary) -> int:
	return maxi(0, s.item_count(int(item.get("id", 0))))


## Scene_Item.user：可行动角色中药物知识 pha 最大者（同 pha 取靠前的）
static func item_user(s: XState, logic: XBattleLogic) -> XActor:
	var user: XActor = null
	for a in s.members():
		if logic.can_move(a) and (user == null or a.pha > user.pha):
			user = a
	return user


## processBatch：逐颗服用 requested 颗（调用方已把它夹在库存内）。targets 是开数量窗时的目标（不对队友的为空），
## effective 是目标的 testApply（物品页的 _effective）。host 给公共事件解释器用（toast 等）。
## 返回 {used, reason, remaining, events}：events 是当场跑完的公共事件（逐颗计）。
static func run(host: Node, s: XState, item: Dictionary, requested: int, targets: Array, for_friend: bool, effective: Callable) -> Dictionary:
	var logic := XBattleLogic.new()
	logic.state = s
	var used := 0
	var ran := []
	var reason := COMPLETE
	var budget := 0
	while true:
		if used >= requested:
			break
		if s.peek_common_event() > 0:
			reason = WAIT_EVENT
			break
		if not supports(item) or stock(s, item) < 1:
			reason = OUT_OF_STOCK
			break
		var user := item_user(s, logic)
		if user == null:
			reason = NO_USER
			break
		if for_friend and not targets.any(func(t): return t != null and effective.call(t)):
			reason = NO_TARGET
			break
		# 这一颗期间的预约先收集（原版临时换掉 $gameTemp.reserveCommonEvent）
		var events := s.capture_common_events(func(): _use_one(s, logic, user, item, targets))
		used += 1
		var stop := false
		while not events.is_empty():
			var id: int = events.pop_front()
			if not approved_event(id):
				s.defer_common_events([id] + events)
				events = []
				stop = true
				break
			await MVInterpreter.new(host, 0, 0, XDB.rec("CommonEvents", id).list).run()
			ran.append(id)
		if stop:
			reason = DEFERRED
			break
		budget += 1
		if budget >= FRAME_BUDGET and host.is_inside_tree():
			budget = 0
			await host.get_tree().process_frame
	return {"used": used, "reason": reason, "remaining": stock(s, item), "events": ran}


## 一颗：useItem（消耗）→ 对每个目标 numRepeats 次 apply → applyGlobal（效果 44 预约公共事件）
static func _use_one(s: XState, logic: XBattleLogic, user: XActor, item: Dictionary, targets: Array) -> void:
	if targets.size() == 1:
		s.item_target_actor_id = targets[0].actor_id
	if bool(item.get("consumable", true)):
		s.gain_item(int(item.id), -1)
	var dead_scope := int(item.get("scope", 0)) in [9, 10]
	for t in targets:
		if t.is_dead() != dead_scope:
			continue  # 同物品页 _use：对活人的不作用于阵亡者
		for r in range(maxi(1, int(item.get("repeats", 1)))):
			for e in item.get("effects", []):
				logic._effect(user, t, e, {"skill": item, "hp": 0.0, "mp": 0.0, "added": [], "removed": []})
	for e in item.get("effects", []):
		if int(e.code) == 44:
			s.reserve_common_event(int(e.dataId))


## 结束时帮助窗的话
static func notice(item: Dictionary, result: Dictionary) -> String:
	var why := str(result.reason)
	return "已服用 %s × %d；剩余 %d 颗%s" % [str(item.get("name", "")), int(result.used), int(result.remaining), "" if why == COMPLETE else "（%s）" % why]


## 物品页跑公共事件用的宿主：提示进菜单的 toast，别的画面指令不做（审过的事件只有变量、条件、给物品、开关、提示与法宝经验）
class EventHost extends Node:
	var toasts: Array = []

	func toast(text: String) -> void:
		toasts.append(text)
		XToast.show_text(text, true)

	func refresh_events() -> void:
		pass

	func character(_id, _from):
		return null
