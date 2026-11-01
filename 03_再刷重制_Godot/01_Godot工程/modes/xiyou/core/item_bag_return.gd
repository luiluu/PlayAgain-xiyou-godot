class_name XItemBagReturn
extends RefCounted
## installItemBagContinuationRuntime（正式版 Codex 运行模块）：物品页用道具前给全队、金钱、其他物品拍快照，用完给一句结果提示
## （物品页主说明卡＋toaster）；用后预约了公共事件的，回地图把事件跑完（同一张图、没有别的预约／事件／文字）再回物品页，
## 选回原分类与那件道具（没了就同一格），提示换成跑完后的结果。换装卡 CE1343 在物品页里当场跑完，不回地图。
## 中途换图、开了别的画面（战斗、商店、存档页等，原版 Scene_Map.stop 时下一个不是 Scene_Map）就不再回物品页。
## 参照 tests/fixtures/item_bag_oracle.json（mv_oracle/item_bag_probe.cjs）。
const WARDROBE_EVENT := 1343
const META := "item_bag_pending"

## O-133：原版快照不含 TP，回 TP 的道具（能量药剂、无尽哈啤等）明明加了 TP，提示却是「已使用」，不消耗的直接说
## 「未检测到效果……（请检查使用条件）」。重制把每个角色的 TP 也记进快照。设为 false 恢复原版（专项两边都跑）。
static var snapshot_tp := true


## snapshot(item)：count 是这件道具的数量；effects 比较全队顺序、金钱、每个已建角色的 HP／MP／等级／技能／状态／能力加成，
## 以及背包里其他东西（原版按 [id, 数量] 记，不分物品／装备；只把同 ID 的物品本身剔掉）
static func snapshot(s: XState, item: Dictionary) -> Dictionary:
	var item_id := int(item.get("id", 0))
	var details: Array = []
	var ids: Array = s.actors.keys()
	ids.sort()
	for id in ids:
		var a: XActor = s.actors[id]
		var row := [id, a.hp, a.mp, a.level, a.skill_ids.duplicate(), a.state_ids.duplicate(), s.mv_param_plus.get(str(id), [])]
		if snapshot_tp:
			row.append(a.tp)
		details.append(row)
	var others: Array = []
	var keys: Array = s.items.keys()
	keys.sort()
	for k in keys:
		if int(k) != item_id and int(s.items[k]) > 0:
			others.append([int(k), int(s.items[k])])
	for g in s.gear:
		others.append([str(g.get("instanceId", "")), int(g.get("base", 0))])
	return {"count": s.item_count(item_id), "effects": var_to_str([s.party.duplicate(), s.gold, details, others])}


## resultText：先看有没有变化，再看数量少了没有，再看事件跑过没有（或当场跑完）
static func result_text(s: XState, ctx: Dictionary) -> String:
	var after := snapshot(s, ctx.item)
	var name := str(ctx.item.get("name", ""))
	if str(ctx.before.effects) != str(after.effects):
		return "已生效：" + name + "（检测到角色或背包变化）"
	if int(after.count) < int(ctx.before.count):
		return "已使用：" + name + "（道具已消耗，请查看事件提示）"
	if bool(ctx.get("event_started", false)) or bool(ctx.get("inline", false)):
		return "事件已执行：" + name + "（未检测到可确认的变化）"
	return "未检测到效果：" + name + "（请检查使用条件）"


## 是不是 result_text 给的那四种提示之一
static func is_result_text(text: String) -> bool:
	return ["已生效：", "已使用：", "事件已执行：", "未检测到效果："].any(func(p): return text.begins_with(p))


## Scene_Item.useItem 包装开头：记下这次用的是哪件、在哪个分类哪一格、在哪张图
static func begin(s: XState, item: Dictionary, category: int, index: int) -> Dictionary:
	return {"item": item, "before": snapshot(s, item), "inline": false, "event_started": false,
		"map": s.map_id, "category": category, "index": index}


## inlineWardrobeEvent：CE1343 且只含 0/122/355/655、脚本里有 i<6859 那段
static func inline_wardrobe(ce: Dictionary) -> bool:
	if int(ce.get("id", 0)) != WARDROBE_EVENT:
		return false
	var list: Array = ce.get("list", [])
	if not list.any(func(c): return int(c.code) == 655 and str(c.parameters[0]).contains("i<6859")):
		return false
	return list.all(func(c): return int(c.code) in [0, 122, 355, 655])


## 这件道具自己的效果里有没有这条公共事件（换装卡当场跑的前提）
static func item_calls(item: Dictionary, event_id: int) -> bool:
	return item.get("effects", []).any(func(e): return int(e.code) == 44 and int(e.dataId) == event_id)


## checkCommonEvent 包装：有预约就记成待回物品页（预约的是哪条事件）
static func hold(s: XState, ctx: Dictionary) -> void:
	ctx.event = s.peek_common_event()
	s.set_meta(META, ctx)


## setupReservedCommonEvent 包装：地图开始跑的正是这条预约事件
static func event_started(s: XState, event_id: int) -> void:
	var ctx: Dictionary = s.get_meta(META, {})
	if not ctx.is_empty() and int(ctx.event) == event_id:
		ctx.event_started = true


## Scene_Map.stop 包装：从地图换到别的画面（战斗、商店、菜单类页面）就不再回物品页
static func scene_opened(s: XState) -> void:
	if s != null and s.has_meta(META):
		s.remove_meta(META)


## Scene_Map.update 包装：事件开始跑过之后，换了图就放弃；还有预约、事件在跑或文字没读完就等；都完了取出、算好提示
static func take(s: XState, busy: bool) -> Dictionary:
	if s == null or not s.has_meta(META):
		return {}
	var ctx: Dictionary = s.get_meta(META)
	if not bool(ctx.event_started):
		return {}
	if s.map_id != int(ctx.map):
		s.remove_meta(META)
		return {}
	if busy or s.peek_common_event() > 0:
		return {}
	s.remove_meta(META)
	ctx.message = result_text(s, ctx)
	return ctx
