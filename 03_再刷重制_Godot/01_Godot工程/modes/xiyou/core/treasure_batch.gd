class_name XTreasureBatch
extends RefCounted
## 【cc·界面·未经审查】藏宝图直接／批量使用与至臻装备闪光（跟到 v0.62.12 installTreasureBatchRuntime.js 的界面部分；
## 挖宝本身 RunGetFun 的 v0.29 改写在 XTreasureMap._run_v029，早已做）。
## - supports：表里 21 种藏宝图（XTreasureMap.V029_SPECS），物品带「效果 44＝它那条公共事件」。旧源（没有这个运行时）不支持，照原来单张使用。
## - use_one（T.useOne）：不在战斗里、没有已预约的公共事件、库存至少 1 张；该图的宝点（四类候选都不空的）里，后续公共事件只能是
##   118／119／120／1377（啥也没有、1 万／10 万精魂、什么都没挖到），否则整张图不支持批量。当场跑完：先跑这张图的公共事件
##   （解释器带 common_id，RunGetFun 按它认藏宝图），期间预约的后续事件依次当场跑（最多 12 条），提示一律不弹（原版换掉 $.toaster）。
##   成功＝库存正好少 1 张。
## - 至臻（T.isPrestige／rare／updateNotice）：底子名字以「至臻」开头（可带“「" 前引号）的武器、防具，队伍新得到时记进队列，
##   物品页、地图、战斗上弹「至臻现世 · 获得 N 件」窗（XPrestigeNotice）。
## 开关：ENABLED = false 回到 v0.28（藏宝图单张使用回地图跑事件、不弹至臻窗）。复现原版，不登 O 号。

static var ENABLED := true
## T.useOne 的 allowed：宝点后续公共事件只能是这几条
const ALLOWED := [118, 119, 120, 1377]
const MAX_CHAIN := 12
## processTreasure：每帧最多用几张（原版另限 8 毫秒）
const FRAME_BUDGET := 8

const DONE := "完成"
const CANCELLED := "取消"
const STOPPED := "已停止"
const OUT_OF_STOCK := "库存不足"
const BUSY := "请先完成当前事件"
const CANNOT := "当前无法继续使用"
const BROKEN := "本次使用中断"
const LEFT := "离开背包"


static func spec_of(item_id: int) -> Array:
	for sp in XTreasureMap.V029_SPECS:
		if int(sp[0]) == item_id:
			return sp
	return []


## supports：表里的藏宝图、普通物品、效果 44 指向表里那条公共事件
static func supports(item: Dictionary) -> bool:
	if not ENABLED or item.is_empty() or not XTreasureMap.v029():
		return false
	if item.has("kind") or item.has("wtypeId") or item.has("atypeId"):
		return false
	var sp := spec_of(int(item.get("id", 0)))
	if sp.is_empty():
		return false
	return (item.get("effects", []) as Array).any(func(e): return int(e.get("code", 0)) == 44 and int(e.get("dataId", 0)) == int(sp[1]))


static func stock(s: XState, item: Dictionary) -> int:
	return maxi(0, s.item_count(int(item.get("id", 0))))


## nativeTable：首尾之间四类候选都不空的宝点
static func rows(sp: Array) -> Array:
	var list := XTreasureMap.spots()
	var out := []
	for i in range(int(sp[2]), int(sp[3]) + 1):
		var spot = list[i] if i < list.size() else null
		if spot != null and not spot.item.is_empty() and not spot.armor.is_empty() and not spot.weapon.is_empty() and not spot.common.is_empty():
			out.append(spot)
	return out


## 能不能当场用：宝点非空、后续事件都在 ALLOWED 且存在
static func usable_now(s: XState, item: Dictionary, in_battle := false) -> bool:
	if not supports(item) or stock(s, item) < 1 or in_battle or s.peek_common_event() > 0:
		return false
	var rs := rows(spec_of(int(item.id)))
	if rs.is_empty():
		return false
	for r in rs:
		for id in r.common:
			if not ALLOWED.has(int(id)) or XDB.rec("CommonEvents", int(id)).is_empty():
				return false
	return true


## T.useOne：当场用一张，成功返回 true。host 给解释器用（toast 不弹，见 QuietHost）
static func use_one(host: Node, s: XState, item: Dictionary) -> bool:
	if not usable_now(s, item):
		return false
	var sp := spec_of(int(item.id))
	var before := stock(s, item)
	var queue := [int(sp[1])]
	var n := 0
	while not queue.is_empty() and n < MAX_CHAIN:
		var id: int = queue.pop_front()
		if id != int(sp[1]) and not ALLOWED.has(id):
			return false   # 藏宝图后续事件未完成
		var interp := MVInterpreter.new(host, 0, 0, XDB.rec("CommonEvents", id).list)
		interp.common_id = id
		await interp.run()
		# 期间预约的后续事件（单槽）拿出来排进队列
		while s.peek_common_event() > 0:
			queue.append(s.peek_common_event())
			s.clear_common_event()
		n += 1
	if not queue.is_empty():
		return false   # 藏宝图后续事件过多
	return stock(s, item) == before - 1


## 结束时说明卡上的话（finish 的 notice）
static func notice(item: Dictionary, result: Dictionary) -> String:
	var used := int(result.used)
	var why := str(result.reason)
	if used > 0:
		var prestige := int(result.get("prestige", 0))
		return "已使用 %s ×%d；剩余 %d 张%s%s" % [str(item.get("name", "")), used, int(result.remaining),
			"；获得至臻装备 %d 件" % prestige if prestige > 0 else "", "" if why == DONE else "（%s）" % why]
	return "已取消使用藏宝图" if why == CANCELLED else "藏宝图使用已停止：" + why


## 物品页批量用时的宿主：提示不弹（原版每张期间把 $.toaster 换成空函数）
class QuietHost extends Node:
	func toast(_text: String) -> void:
		pass

	func refresh_events() -> void:
		pass

	func character(_id, _from):
		return null


# ---- 至臻 ----
static var _series = null
## 至臻队列：{key: {name, icon, count}}，按先后；serial 累计件数（结果提示「获得至臻装备 N 件」用差值）
static var queue := {}
static var serial := 0
static var _owner = null


static func series_key(kind: String, base_id: int) -> String:
	if _series == null:
		_series = {}
		for pair in [["Weapons", "w"], ["Armors", "a"]]:
			for rec in XDB.table(pair[0]):
				if rec is Dictionary and not rec.is_empty() and XRx.re("^[“「\"]?至臻").search(str(rec.get("name", ""))) != null:
					_series[str(pair[1]) + str(int(rec.id))] = true
	var key := ("w" if kind == "weapon" else "a") + str(base_id)
	return key if _series.has(key) else ""


static func is_prestige(item: Dictionary) -> bool:
	return item.has("kind") and series_key(str(item.kind), int(item.get("base", item.get("id", 0)))) != ""


## rare：队伍新得到至臻装备（gain_gear 调）；新开局／读档换了状态就清掉旧队列
static func note_gain(s: XState, kind: String, base_id: int, name: String, icon: int, count: int) -> void:
	if not ENABLED or count < 1 or s != XState.current:
		return
	var key := series_key(kind, base_id)
	if key == "":
		return
	_sync_owner(s)
	if not queue.has(key):
		queue[key] = {"name": name, "icon": icon, "count": 0}
	queue[key].count += count
	serial += count
	XPrestigeNotice.ensure()


static func _sync_owner(s: XState) -> void:
	if _owner == null or not is_instance_valid(_owner) or _owner != s:
		_owner = s
		queue = {}
		serial = 0


static func take_queue() -> Array:
	if _owner != XState.current:
		queue = {}
		return []
	var out := queue.values()
	queue = {}
	return out
