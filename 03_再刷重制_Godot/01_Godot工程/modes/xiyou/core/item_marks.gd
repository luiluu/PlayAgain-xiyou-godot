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


## 装备实例（背包与身上）都有 kind（weapon/armor）与 instanceId；物品记录两者都没有
static func is_gear(rec: Dictionary) -> bool:
	return rec.has("instanceId") or str(rec.get("kind", "")) in ["weapon", "armor"]


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
	["skip", "<PROXY BUY:[ ](.*)>"], ["bvar", "<VARIABLE[ ](\\d+)[ ]BUY PRICE:[ ](\\d+)>"],
	["var", "<VARIABLE[ ](\\d+)[ ]SELL PRICE:[ ](\\d+)>"],
	["bitem", "<ITEM[ ](\\d+)[ ]BUY PRICE:[ ](\\d+)>"], ["skip", "<ITEM[ ](.*)[ ]BUY PRICE:[ ](\\d+)>"], ["item", "<ITEM[ ](\\d+)[ ]SELL PRICE:[ ](\\d+)>"], ["skip", "<ITEM[ ](.*)[ ]SELL PRICE:[ ](\\d+)>"],
	["skip", "<WEAPON[ ](.*)[ ]BUY PRICE:[ ](\\d+)>"], ["skip", "<WEAPON[ ](.*)[ ]SELL PRICE:[ ](\\d+)>"],
	["skip", "<ARMOR[ ](.*)[ ]BUY PRICE:[ ](\\d+)>"], ["skip", "<ARMOR[ ](.*)[ ]SELL PRICE:[ ](\\d+)>"]]
static var _rewards := {}
static var _mc_res: Array = []


## 基础记录（装备按 base）的 MoreCurrencies 价格 {"vars": {变量: 值}, "items": {物品: 数}（卖出报酬），
## "buy_vars": {变量: 值}, "buy_items": {物品: 数}（买入价）, "buy": 有无变量/物品买入价}
## 各表按备注行的先后；插件 unshift 进 xxxSellPrices／xxxBuyPrices，画价格时从右往左是倒序。
## 按名字的 <Item 名字 Buy Price> 正式数据里解析不到物品，不算；<Weapon/Armor x Buy Price> 的目标是独立装备，插件跳过。
static func sell_rewards(rec: Dictionary) -> Dictionary:
	var base := _base_rec(rec)
	var key := "%s:%d" % [str(base.get("_table", _table_of(rec))), int(base.get("id", 0))]
	if _rewards.has(key):
		return _rewards[key]
	if _mc_res.is_empty():
		for pair in _MC_LINE:
			_mc_res.append([pair[0], RegEx.create_from_string("(?i)" + str(pair[1]))])
	var out := {"vars": {}, "items": {}, "buy_vars": {}, "buy_items": {}, "buy": false}
	for line in RegEx.create_from_string("[\\r\\n]+").sub(str(base.get("note", "")), "\n", true).split("\n"):
		for pair in _mc_res:
			var m: RegExMatch = pair[1].search(line)
			if m == null:
				continue
			if pair[0] in ["bvar", "bitem"]:
				out.buy = true
			var bucket: String = {"var": "vars", "item": "items", "bvar": "buy_vars", "bitem": "buy_items"}.get(pair[0], "")
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


## YEP_X_MoreCurrencies Window_ShopNumber.isDrawGoldCurrency：有变量/物品买入价且基础价为 0 时，数量窗不画金币三行（买、卖都按买入价判断）。
static func draws_gold(rec: Dictionary) -> bool:
	return not sell_rewards(rec).buy or int(rec.get("price", 0)) > 0


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


# ---- 买入 ----

## 停用的伙伴号角（installImportedBalanceRuntime：Scene_Shop.prepare 从商品里滤掉，Window_ShopBuy.isEnabled 也拦下）
const DISABLED_HORNS := [255, 256, 257, 394, 440]
const MAX_ITEMS := 9999         # $gameParty.maxItems（物品）；独立装备每件单独，maxItems 为 1
static var _proxy := {}


const PILL_ANCHOR := 1693       # Codex_PercentPills SHOP_ANCHOR
const PILL_KEYS := ["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"]


## Scene_Shop.prepare 整条链对商品表的改写（切片商店用到的）：
## - Codex_PercentPills：商品里有 1693 时，把所有 <CodexPill: mhp…luk> 的物品追加到末尾（已有的不重复）；
## - installNativeRaceRuntime：旧版祝福进阶石按 CodexRaces.legacyItems 换成正规 ID，再去掉完全相同的行；
## - installImportedBalanceRuntime：滤掉停用的伙伴号角。
## 未移植：Map132 号角商店追加新伙伴号角（多个 installNative…Runtime）、installNativeOrbRuntime 撤下宝珠——切片商店不受影响（shop_buy_probe）。
static func shop_goods(goods: Array) -> Array:
	var rows: Array = goods.map(func(g): return [int(g[0]), int(g[1]), int(g[2]), int(g[3])])
	rows = rows.filter(func(g): return not _orb_filtered(g))
	if rows.any(func(g): return g[0] == 0 and g[1] == PILL_ANCHOR):
		var db: Array = XDB.table("Items")
		for i in range(1, db.size()):
			var key := str(db[i].get("meta", {}).get("CodexPill", "")).strip_edges() if db[i] is Dictionary else ""
			if PILL_KEYS.has(key) and not rows.any(func(g): return g[0] == 0 and g[1] == i):
				rows.append([0, i, 0, 0])
	var races = XDB.table("CodexRaces")
	var legacy: Dictionary = races.get("legacyItems", {}) if races is Dictionary else {}
	var out := []
	for g in rows:
		if g[0] == 0 and legacy.has(str(g[1])):
			g[1] = int(legacy[str(g[1])])
		if not out.has(g) and not (g[0] == 0 and DISABLED_HORNS.has(g[1])):
			out.append(g)
	return out


## 宝珠运行时（installNativeOrbRuntime）：宝珠改为副本掉落，Scene_Shop.prepare 先从商品表滤掉宝珠物品（CodexOrbs 的新宝珠
## items、神秘珠 bands、原作宝珠 legacyRefund；shopKeep 里的保留），再交给其余改写；商品表非空而全被滤掉时，商店一打开就提示并关闭。
const ORB_SHOP_TEXT := "宝珠已改为副本掉落：刷副本Boss得神秘珠，到宝珠坊鉴定"


static func is_orb_item(id: int) -> bool:
	var cfg = XDB.table("CodexOrbs")
	if not cfg is Dictionary:
		return false
	var key := str(id)
	return cfg.get("items", {}).has(key) or cfg.get("legacyRefund", {}).has(key) \
		or cfg.get("bands", []).any(func(b): return int(b.get("itemId", 0)) == id)


static func _orb_filtered(g: Array) -> bool:
	var cfg = XDB.table("CodexOrbs")
	return cfg is Dictionary and int(g[0]) == 0 and is_orb_item(int(g[1])) \
		and not cfg.get("shopKeep", []).any(func(k): return int(k) == int(g[1]))


## 商品表非空、滤掉宝珠后为空（Scene_Shop._codexOrbOnly）
static func shop_orb_only(goods: Array) -> bool:
	return not goods.is_empty() and goods.all(func(g): return _orb_filtered([int(g[0]), int(g[1])]))


## 商品记录（goods 的类型 0物品/1武器/2防具 + ID）：装备补上 kind、base，买入各函数据此认表
static func shop_rec(kind: int, id: int) -> Dictionary:
	if kind == 0:
		return XDB.rec("Items", id)
	var r := XDB.rec("Weapons" if kind == 1 else "Armors", id)
	if r.is_empty():
		return r
	r = r.duplicate()
	r.kind = "weapon" if kind == 1 else "armor"
	r.base = id
	return r


## <Proxy Buy: x>（YEP_X_MoreCurrencies）：买到的是同表的另一件（数字是 ID，否则按名字，同名取 ID 最大的）；0 为没有。
## 插件读数据库时把代购件的名字、图标、说明（物品还有效果，装备还有能力）抄到商品上。
static func proxy_buy(rec: Dictionary) -> int:
	var table := _table_of(rec)
	var key := "%s:%d" % [table, int(rec.get("base", rec.get("id", 0)))]
	if _proxy.has(key):
		return _proxy[key]
	var id := 0
	var m := RegEx.create_from_string("(?i)<PROXY BUY:[ ](.*)>").search(str(_base_rec(rec).get("note", "")))
	if m:
		var v := m.get_string(1)
		if v.is_valid_int():
			id = int(v)
		else:
			var db: Array = XDB.table(table)
			for i in range(1, db.size()):
				if db[i] is Dictionary and str(db[i].get("name", "")).to_upper() == v.to_upper():
					id = i
	_proxy[key] = id
	return id


## 商品的显示记录：有代购时抄上代购件的名字、图标、说明（Copy Name/Icon/Help 均为 true）
static func shop_display(rec: Dictionary) -> Dictionary:
	var pid := proxy_buy(rec)
	if pid <= 0:
		return rec
	var src := XDB.rec(_table_of(rec), pid)
	var out := rec.duplicate()
	for k in ["name", "iconIndex", "description"]:
		out[k] = src.get(k, out.get(k))
	return out


## CodexZhenqi.progressFloor：进度层数 = 变量 20 − 1（0～33）
static func progress_floor(s: XState) -> int:
	return clampi(int(s.variable(20)) - 1, 0, 33)


## 祝福进阶石（installNativeRaceRuntime 改 Window_ShopBuy.isEnabled）：CodexRaces.stones 第 k 件（k 从 0）要进度层数 ≥ bands[k][0]
static func stone_locked(s: XState, rec: Dictionary) -> bool:
	if is_gear(rec):
		return false
	var races = XDB.table("CodexRaces")
	if not races is Dictionary:
		return false
	var k: int = races.get("stones", []).map(func(x): return int(x)).find(int(rec.get("id", 0)))
	return k >= 0 and progress_floor(s) < int(races.bands[k][0])


## Window_ShopBuy.isEnabled 整条链（price 为商品的买入价，指定价格优先）：停用号角、进阶石层数、
## MoreCurrencies 变量/物品买入价都够、YEP_ItemCore 独立装备该类不超过 9999 件、MV 价格不超过金钱且物品未满。
## 未移植：超强者伙伴号角限地狱及以上（installBossDifficultyRuntime）、轮回随机阵容限制（installReincarnationRandomRuntime）。
## KMS_ShopInventory 库存在 XShop._buy_enabled 另乘（XShopStock，链的最后一环）。
static func can_buy(s: XState, rec: Dictionary, price: int) -> bool:
	if rec.is_empty():
		return false
	if not is_gear(rec) and DISABLED_HORNS.has(int(rec.get("id", 0))):
		return false
	if stone_locked(s, rec):
		return false
	var r := sell_rewards(rec)
	for v in r.buy_vars:
		if s.variable(int(v)) < int(r.buy_vars[v]):
			return false
	for id in r.buy_items:
		if s.item_count(int(id)) < int(r.buy_items[id]):
			return false
	if is_gear(rec):
		var kind := str(rec.get("kind", "weapon"))
		if s.gear.filter(func(e): return e.kind == kind).size() >= MAX_ITEMS:
			return false
		return price <= s.gold
	return price <= s.gold and s.item_count(int(rec.id)) < MAX_ITEMS


## Scene_Shop.maxBuy：持有上限余量（物品 9999−持有，独立装备 1），有价格时再受金钱限制，MoreCurrencies 再按各变量/物品取整
static func max_buy(s: XState, rec: Dictionary, price: int) -> int:
	var mx := 1 if is_gear(rec) else MAX_ITEMS - s.item_count(int(rec.get("id", 0)))
	if price > 0:
		mx = mini(mx, s.gold / price)
	var r := sell_rewards(rec)
	for v in r.buy_vars:
		mx = mini(mx, floori(s.variable(int(v)) / float(r.buy_vars[v])))
	for id in r.buy_items:
		mx = mini(mx, s.item_count(int(id)) / int(r.buy_items[id]))
	return mx


## Scene_Shop.doBuy(number)：doBuyGold 扣金币与各变量、物品买入价×数量，doBuyItem 得到商品（有代购时得到代购件）
static func buy(s: XState, rec: Dictionary, price: int, number := 1) -> void:
	s.gain_gold(-price * number)
	var r := sell_rewards(rec)
	for v in r.buy_vars:
		s.set_variable(int(v), s.variable(int(v)) - int(r.buy_vars[v]) * number)
	for id in r.buy_items:
		s.gain_item(int(id), -int(r.buy_items[id]) * number)
	var pid := proxy_buy(rec)
	var id := pid if pid > 0 else int(rec.get("id", 0))
	if is_gear(rec):
		s.gain_gear(str(rec.get("kind", "weapon")), id, number)
	else:
		s.gain_item(id, number)


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
