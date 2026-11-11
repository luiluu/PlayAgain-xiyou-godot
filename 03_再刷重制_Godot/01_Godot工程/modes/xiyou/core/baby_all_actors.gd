class_name XBabyAllActors
extends RefCounted
## 【cc·悟空·未经审查】v0.62 宝宝路线开放全部角色（正式 js/codex/runtime/installBabyAllActorsRuntime.js，CodexBabyAllActors；
## Kyo 2026-10-31 定：隐藏角色不可用、超强者可用、方式选「号角商店全部免费」）：
## - 宝宝路线（开关 2496）下，卖伙伴号角的商店改列全部可用角色的号角，价格全 0（金币、魂灯等货币都不扣），每次最多买 1 支。
## - 每名角色只能免费领一次：领过的记在存档 flags["_codexBabyHornActors"]；已拥有（队伍、仓库、背包里已有这支号角，
##   或招募事件开头的「已招募」变量 ≥1）的也不列。排除停用角色与 V029 隐藏角色、没名字的。
## - 超强者：宝宝路线视同已开放（XItemMarks.super_enabled）。招募仍走号角原生流程，本模块不直接加角色。
## 原版装在最后（Scene_Shop.prepare 最外层）：先改商品表，再走其余 prepare 链（XItemMarks.shop_goods）。
## O-301（宝宝号角免费）：ENABLED = false 回到 v0.28（宝宝路线商店照常）。
const SWITCH := 2496
const TAKEN := "_codexBabyHornActors"
static var ENABLED := true
## 免费商店开着期间（Scene_Shop.prepare 到 terminate）：号角的额外货币买入价清空（XItemMarks.sell_rewards 看这个）
static var free_open := false


static func active(s: XState) -> bool:
	return ENABLED and s != null and s.switch(SWITCH)


static func is_horn(rec: Dictionary) -> bool:
	return not rec.is_empty() and not XItemMarks.is_gear(rec) and str(rec.get("name", "")).begins_with("伙伴号角")


static func _horn_events(rec: Dictionary) -> Array:
	return (rec.get("effects", []) as Array).filter(func(e): return int(e.code) == 44).map(func(e): return int(e.dataId))


## B.hornActor：先用超强者模块的识别，再取招募事件里第一个「加入队伍」（129，参数[1]＝0）
static func horn_actor(rec: Dictionary) -> int:
	if not is_horn(rec):
		return 0
	var id := XItemMarks.recruit_actor_id(rec)
	if id > 0:
		return id
	for ce_id in _horn_events(rec):
		for c in XDB.rec("CommonEvents", ce_id).get("list", []):
			if int(c.code) == 129 and int(c.parameters[1]) == 0:
				return int(c.parameters[0])
	return 0


static func excluded(id: int) -> bool:
	if (XImportedBalance.DISABLED_ACTORS.has(id) or XImportedBalance.HIDDEN_ACTORS.has(id)) and not XImportedBalance.released_actor(id):
		return true
	return str(XDB.rec("Actors", id).get("name", "")) == ""


## 招募事件开头「变量 ≥1 → 已有该队友」的那个变量已 ≥1
static func _recruited_var(s: XState, rec: Dictionary) -> bool:
	for ce_id in _horn_events(rec):
		var list: Array = XDB.rec("CommonEvents", ce_id).get("list", [])
		if list.is_empty():
			continue
		var c: Dictionary = list[0]
		var p: Array = c.get("parameters", [])
		if int(c.code) == 111 and p.size() >= 5 and int(p[0]) == 1 and int(p[2]) == 0 and int(p[3]) == 1 and int(p[4]) == 0 and float(s.variable(int(p[1]))) >= 1:
			return true
	return false


static func taken(s: XState) -> Array:
	if not s.flags.has(TAKEN) or not (s.flags[TAKEN] is Array):
		s.flags[TAKEN] = []
	return s.flags[TAKEN]


static func owned(s: XState, id: int, rec: Dictionary) -> bool:
	return taken(s).has(id) or s.party.has(id) or s.saved_actors.has(id) \
		or (not rec.is_empty() and (_recruited_var(s, rec) or s.item_count(int(rec.id)) > 0))


## B.catalog：每名角色取一支号角，优先商店里本来就卖的那支，其次编号最小的；按角色号排
static func catalog(preferred: Array) -> Array:
	var by_actor := {}
	var db: Array = XDB.table("Items")
	for i in range(1, db.size()):
		var rec = db[i]
		if not (rec is Dictionary) or not is_horn(rec):
			continue
		var id := horn_actor(rec)
		if id <= 0 or excluded(id):
			continue
		var cur = by_actor.get(id)
		if cur == null or (preferred.has(int(rec.id)) and not preferred.has(int(cur.id))):
			by_actor[id] = rec
	var ids := by_actor.keys()
	ids.sort()
	return ids.map(func(id): return {"actor": id, "item": by_actor[id]})


## Scene_Shop.prepare 包装：宝宝路线且商品里有号角时，号角行换成「全部可用、未拥有」的号角（价格 0），返回 [新商品表, 是否免费店]
static func prepare(s: XState, goods: Array) -> Array:
	if not active(s) or not goods.any(func(g): return int(g[0]) == 0 and is_horn(XDB.rec("Items", int(g[1])))):
		return [goods, false]
	var sold := goods.filter(func(g): return int(g[0]) == 0).map(func(g): return int(g[1]))
	var others := goods.filter(func(g): return not (int(g[0]) == 0 and is_horn(XDB.rec("Items", int(g[1])))))
	var horns := catalog(sold).filter(func(r): return not owned(s, int(r.actor), r.item)).map(func(r): return [0, int(r.item.id), 1, 0])
	return [others + horns, true]


## doBuy 包装：买过的角色记进已领，商品表去掉这支
static func bought(s: XState, rec: Dictionary, goods: Array) -> Array:
	var aid := horn_actor(rec)
	if aid > 0 and not taken(s).has(aid):
		taken(s).append(aid)
	return goods.filter(func(g): return not (int(g[0]) == 0 and int(g[1]) == int(rec.get("id", 0))))
