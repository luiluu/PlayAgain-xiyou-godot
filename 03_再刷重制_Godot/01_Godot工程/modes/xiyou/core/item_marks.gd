class_name XItemMarks
extends RefCounted
## 出售锁定（Star_ShopOnekey）与道具置顶（Star_ItemTop）。
## - 物品：锁定／置顶的 ID 存在 $gameParty.ItemSpLock / TopItem（这里是 XState.flags 的同名键，随存档）。
##   原版把「[锁定]」「[置顶]」直接加在 $dataItems 的名字上（全局改名，列表重建时才同步）；这里只在物品列表里画（O-030）。
## - 装备：锁定直接改实例名字加／去「[锁定]」（与原版相同，随存档；挂机自动卖出、一键出售都按名字跳过）。装备没有置顶。
## - 列表（Window_ItemList.makeItemList，物品页、商店出售列表共用）：先按锁定加名，再把置顶的物品逐个移到最前（倒序：后出现的在更前）。

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
		s.gain_gold(price)
		s.gear.erase(e)
		count += 1
		gold += price
	return [count, gold]
