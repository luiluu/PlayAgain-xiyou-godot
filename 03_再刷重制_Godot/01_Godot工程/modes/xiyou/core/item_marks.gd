class_name XItemMarks
extends RefCounted
## 出售锁定（Star_ShopOnekey）与道具置顶（Star_ItemTop）。
## - 物品：锁定／置顶的 ID 存在 $gameParty.ItemSpLock / TopItem（这里是 XState.flags 的同名键，随存档）。
##   原版把「[锁定]」「[置顶]」直接加在 $dataItems 的名字上（全局改名，列表重建时才同步）；这里只在物品列表里画（O-030）。
## - 装备：锁定直接改实例名字加／去「[锁定]」（与原版相同，随存档；挂机自动卖出、一键出售都按名字跳过）。装备没有置顶。
## - 列表（Window_ItemList.makeItemList，物品页、商店出售列表共用）：先按锁定加名，再把置顶的物品逐个移到最前（倒序：后出现的在更前）。
## 出售（商店普通出售、一键出售、挂机自动卖出共用 sell）：YEP sellingPrice 的金币＋YEP_X_MoreCurrencies 卖出报酬（变量、物品）。

const LOCK := "[锁定]"
const TOP := "[置顶]"
## O-030：物品的标记只画在物品列表里（不改数据库名字）。设 false 恢复原版：切换时直接改 XDB 物品记录的名字（全局生效到重启）。
const LIST_ONLY_NAMES := true


static func _ids(s: XState, key: String) -> Array:
	var v = s.flags.get(key, [])
	return v.map(func(x): return int(x)) if v is Array else []


static func _toggle_id(s: XState, key: String, id: int) -> bool:
	var ids := _ids(s, key)
	var on := not ids.has(id)
	if on:
		ids.append(id)
	else:
		ids.erase(id)
	s.flags[key] = ids
	return on


static func is_gear(rec: Dictionary) -> bool:
	return rec.has("instanceId")


static func is_locked(s: XState, rec: Dictionary) -> bool:
	if is_gear(rec):
		return str(rec.get("name", "")).contains(LOCK)
	return _ids(s, "ItemSpLock").has(int(rec.get("id", 0)))


static func is_top(s: XState, rec: Dictionary) -> bool:
	return not is_gear(rec) and _ids(s, "TopItem").has(int(rec.get("id", 0)))


## Scene_Item.onSetLock：物品切换 ItemSpLock（无提示）；装备改名，提示「锁定完成」／「取消锁定」。返回提示文字（无则空）。
static func toggle_lock(s: XState, rec: Dictionary) -> String:
	if not is_gear(rec):
		_rename(rec, LOCK, _toggle_id(s, "ItemSpLock", int(rec.get("id", 0))))
		return ""
	var name := str(rec.get("name", ""))
	if not name.contains(LOCK):
		rec.name = name + LOCK
		return "锁定完成"
	rec.name = name.replace(LOCK, "")
	return "取消锁定"


## Scene_Item.onItemTop：切换 TopItem，提示「置顶完成」／「取消置顶」
static func toggle_top(s: XState, rec: Dictionary) -> String:
	var on := _toggle_id(s, "TopItem", int(rec.get("id", 0)))
	_rename(rec, TOP, on)
	return "置顶完成" if on else "取消置顶"


## 原版做法（LIST_ONLY_NAMES 为 false 时）：直接改数据库记录的名字
static func _rename(rec: Dictionary, mark: String, on: bool) -> void:
	if LIST_ONLY_NAMES:
		return
	var name := str(rec.get("name", "")).replace(mark, "")
	rec.name = name + mark if on else name


## 物品列表的显示用记录：锁定／置顶的物品换成加了标记名字的副本（id 等不变）；装备原样
static func decorate(s: XState, rec: Dictionary) -> Dictionary:
	if is_gear(rec) or rec.is_empty() or not LIST_ONLY_NAMES:
		return rec
	var suffix := (LOCK if is_locked(s, rec) else "") + (TOP if is_top(s, rec) else "")
	if suffix == "":
		return rec
	var copy := rec.duplicate()
	copy.name = str(rec.get("name", "")) + suffix
	return copy


## makeItemList：entries 每项 {rec, …}。物品加标记名；置顶物品按出现先后逐个 unshift 到最前。
static func apply_list(s: XState, entries: Array) -> Array:
	var rest := []
	var top := []
	for e in entries:
		var d: Dictionary = e.duplicate()
		d.rec = decorate(s, e.rec)
		if is_top(s, e.rec):
			top.append(d)
		else:
			rest.append(d)
	for d in top:
		rest.push_front(d)
	return rest


# ---- 出售 ----

## YEP_X_MoreCurrencies processMCNotetags1：逐行按插件的判断顺序取第一个匹配的写法（一行只认一种）；同一 ID 只取第一行。
## 卖出报酬只有 <Variable x Sell Price: y> 与 <Item x Sell Price: y>：<Weapon/Armor x Sell Price> 的目标是独立装备时插件跳过，
## 本 MOD 的武器、防具都是独立装备，所以从不生效；按名字的写法（<Item 名字 Sell Price>）正式数据里没有，不做。
const _MC_LINE := [
	["skip", "<PROXY BUY:[ ](.*)>"], ["skip", "<VARIABLE[ ](\\d+)[ ]BUY PRICE:[ ](\\d+)>"],
	["var", "<VARIABLE[ ](\\d+)[ ]SELL PRICE:[ ](\\d+)>"],
	["skip", "<ITEM[ ](.*)[ ]BUY PRICE:[ ](\\d+)>"], ["item", "<ITEM[ ](\\d+)[ ]SELL PRICE:[ ](\\d+)>"], ["skip", "<ITEM[ ](.*)[ ]SELL PRICE:[ ](\\d+)>"],
	["skip", "<WEAPON[ ](.*)[ ]BUY PRICE:[ ](\\d+)>"], ["skip", "<WEAPON[ ](.*)[ ]SELL PRICE:[ ](\\d+)>"],
	["skip", "<ARMOR[ ](.*)[ ]BUY PRICE:[ ](\\d+)>"], ["skip", "<ARMOR[ ](.*)[ ]SELL PRICE:[ ](\\d+)>"]]
static var _rewards := {}
static var _mc_res: Array = []


## 基础记录（装备按 base）的卖出报酬 {"vars": {变量: 值}, "items": {物品: 数}}
static func sell_rewards(rec: Dictionary) -> Dictionary:
	var base := _base_rec(rec)
	var key := "%s:%d" % [str(base.get("_table", _table_of(rec))), int(base.get("id", 0))]
	if _rewards.has(key):
		return _rewards[key]
	if _mc_res.is_empty():
		for pair in _MC_LINE:
			_mc_res.append([pair[0], RegEx.create_from_string("(?i)" + str(pair[1]))])
	var out := {"vars": {}, "items": {}}
	for line in RegEx.create_from_string("[\\r\\n]+").sub(str(base.get("note", "")), "\n", true).split("\n"):
		for pair in _mc_res:
			var m: RegExMatch = pair[1].search(line)
			if m == null:
				continue
			var bucket := "vars" if pair[0] == "var" else "items" if pair[0] == "item" else ""
			if bucket != "" and not out[bucket].has(int(m.get_string(1))):
				out[bucket][int(m.get_string(1))] = int(m.get_string(2))
			break
	_rewards[key] = out
	return out


static func _table_of(rec: Dictionary) -> String:
	if is_gear(rec):
		return "Weapons" if str(rec.get("kind", "")) == "weapon" else "Armors"
	return "Items"


static func _base_rec(rec: Dictionary) -> Dictionary:
	if is_gear(rec):
		return XDB.rec(_table_of(rec), int(rec.get("base", 0)))
	var r := XDB.rec("Items", int(rec.get("id", 0)))
	return r if not r.is_empty() else rec


static func has_sell_rewards(rec: Dictionary) -> bool:
	var r := sell_rewards(rec)
	return not r.vars.is_empty() or not r.items.is_empty()


## Window_ShopSell.isEnabled（YEP_ShopMenuCore）：有价格，或有卖出报酬备注（MoreCurrencies 设 canSell）。
## 正式数据没有 <Can Sell>／<Cannot Sell>／<Price>／<Sell Price> 备注。
static func can_sell(rec: Dictionary) -> bool:
	return not rec.is_empty() and (int(rec.get("price", 0)) > 0 or has_sell_rewards(rec))


## Scene_Shop.doSell(number)／XdRsData.hangUp.doSell：金币 sellingPrice×数量，报酬变量与物品各加 值×数量，再失去物品。
## 物品按 ID 减数量；装备移除该实例（身上的不经过这里）。
static func sell(s: XState, rec: Dictionary, number := 1) -> void:
	s.gain_gold(selling_price(rec) * number)
	var r := sell_rewards(rec)
	for v in r.vars:
		s.set_variable(int(v), s.variable(int(v)) + int(r.vars[v]) * number)
	for id in r.items:
		s.gain_item(int(id), int(r.items[id]) * number)
	if is_gear(rec):
		s.gear.erase(rec)
	else:
		s.gain_item(int(rec.get("id", 0)), -number)


## Scene_Shop.sellingPrice（YEP_ShopMenuCore：<Sell Price> 优先，否则 MV 半价向下取整）
static func selling_price(rec: Dictionary) -> int:
	if rec.has("sellPrice"):
		return int(rec.sellPrice)
	return int(rec.get("price", 0)) / 2


## 一键出售指令（installUnifiedQualityRuntime 改写 Window_OnekeySellCommand）：七档中含旧档 0～14 的各一行
static func onekey_grades() -> Array:
	var cfg := XQuality.config()
	var out := []
	for g in cfg.names.size():
		if onekey_members(g).size() > 0:
			out.append({"grade": g, "text": "出售%s品质" % cfg.names[g]})
	return out


static func onekey_members(g: int) -> Array:
	var grades: Array = XQuality.config().itemGrades
	var out := []
	for q in range(mini(grades.size(), 15)):
		if int(grades[q]) == g:
			out.append(q)
	return out


## Scene_Shop.sellUnifiedQuality：背包（不含身上）里备注品质属于该档旧档 0～14、名字不带「[锁定]」的装备逐件 doSell(1)。
## 卖价为 0 的也卖掉（原版现行代码不查价格）。返回 [件数, 金额]。
static func onekey_sell(s: XState, g: int) -> Array:
	var legacy := onekey_members(g)
	var count := 0
	var gold := 0
	for e in s.gear.duplicate():
		var q := str(e.get("meta", {}).get("quality", "")).strip_edges()
		if not q.is_valid_int() or not legacy.has(int(q)) or str(e.get("name", "")).contains(LOCK):
			continue
		var price := selling_price(e)
		sell(s, e, 1)
		count += 1
		gold += price
	return [count, gold]
