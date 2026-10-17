class_name XShopStock
extends RefCounted
## KMS_ShopInventory 商店库存（限购）。参照：mv_oracle/shared/stock.cjs → generated/oracle/shop_stock.json（tests/xiyou_shop_stock 逐例比）。
## - 商品备注 <kms_shop_stock: 上限, 补货间隔[, T/B]>（或运行时写好的 shopStockCountMax 字段）才受管；其余商品不限量。
## - 插件指令「ShopInventory apply 组名」只记下一次打开的商店用哪个组（$gameTemp.nextInventoryId，不存档）；
##   商店打开（Scene_Shop.prepare）时先补货再取走这个组名，没有 apply 的商店不限购。组名就是正式命令里的字符串，
##   同名的多个入口共用一份库存（如大厅人道碎片三家店）。
## - 存档 XState.shop_stock = {"inv": {组: {"speed": 倍率或 null, "stock": {"item"/"weapon"/"armor": {ID: 剩余}}}},
##   "schedules": [{"group", "kind", "id", "start"}]}；记剩余量（原版 Game_ShopInventory 的容器），没记过的商品＝上限。
##   旧档没有这一项：所有组按满库存（读档缺省）。
## - 预览、改数量、刷新列表只读（remaining／max_buy），只有 record_purchase／record_sale 改库存；货币仍由 XItemMarks.buy 扣。
## - 补货（Game_ShopSupplySchedule）：买入后登记，间隔按游戏时间秒（$gameSystem.playtime，重制版取地图累计秒）；
##   正式数据只有 T 方式（B 战斗次数无商品使用，这里不补）。

const MAX_ITEMS := 9999
const KINDS := ["item", "weapon", "armor"]
const TABLES := ["Items", "Weapons", "Armors"]

static var _spec_cache := {}


## 解析备注（parseNotesForStock）：返回 {max, interval, mode}，不受管返回 {}
static func spec(kind: int, id: int) -> Dictionary:
	var key := "%d:%d" % [kind, id]
	if _spec_cache.has(key):
		return _spec_cache[key]
	var out := {}
	var rec := XDB.rec(TABLES[kind], id)
	var raw = rec.get("meta", {}).get("kms_shop_stock")
	if rec.has("shopStockCountMax"):
		# 运行时新增的物品（如 Codex 渡鸦号角 2902、冥河断罪镰 4001）由插件直接写好字段，没有备注
		out = {"max": int(rec.shopStockCountMax), "interval": int(rec.get("shopStockSupplyInterval", 0)), "mode": int(rec.get("shopStockSupplyMode", 0))}
	elif raw != null:
		var opts := RegEx.create_from_string("\\s+").sub(str(raw), "", true).split(",")
		if opts.size() >= 2 and opts[0].is_valid_float() and opts[1].is_valid_float():
			var mode := 0
			if opts.size() >= 3 and opts[2].to_upper() == "B":
				mode = 1
			out = {"max": int(float(opts[0])), "interval": int(float(opts[1])), "mode": mode}
	_spec_cache[key] = out
	return out


static func managed(kind: int, id: int) -> bool:
	return not spec(kind, id).is_empty()


static func stock_max(kind: int, id: int) -> int:
	return int(spec(kind, id).max) if managed(kind, id) else MAX_ITEMS


# ---- 插件指令 ----

## Game_Interpreter.pluginCommand「ShopInventory …」：apply／supplySpeed／restockAll／resetAll（正式数据只用 apply）
static func plugin_command(s: XState, args: PackedStringArray) -> void:
	if args.size() < 2:
		return
	match args[1]:
		"apply":
			if args.size() > 2:
				apply_group(s, args[2])
		"supplySpeed":
			# 原版 setSupplySpeed() 漏传参数，倍率成 NaN：该组从此不再补货（stock.supply-speed-command）
			if args.size() > 3 and args[3].is_valid_float():
				_inv(s, args[2], true).speed = null
		"restockAll":
			if args.size() > 2 and _inv(s, args[2], false) != null:
				restock_all(s, args[2])
		"resetAll":
			reset_all(s)


static func apply_group(s: XState, group: String) -> void:
	s.shop_pending = group


## Scene_Shop.prepare：先补货，再取走待用组名（取过就清空）；返回 "" 表示这家店不限购
static func open(s: XState) -> String:
	update_supplier(s)
	var g := s.shop_pending
	s.shop_pending = ""
	return g


static func restock_all(s: XState, group: String) -> void:
	_inv(s, group, true).stock = {}


static func reset_all(s: XState) -> void:
	s.shop_stock = {"inv": {}, "schedules": []}


# ---- 查询（不改状态） ----

## Game_ShopInventory.getStock：不限购的店或不受管的商品为持有上限 9999
static func remaining(s: XState, group: String, kind: int, id: int) -> int:
	if group == "" or not managed(kind, id):
		return MAX_ITEMS
	var inv = _inv(s, group, false)
	if inv == null:
		return stock_max(kind, id)
	var box: Dictionary = inv.stock.get(KINDS[kind], {})
	return int(box.get(str(id), stock_max(kind, id)))


static func available(s: XState, group: String, kind: int, id: int) -> bool:
	return remaining(s, group, kind, id) > 0


## Scene_Shop.maxBuy：原上限（持有余量、金钱与各货币）再与库存取小
static func max_buy(s: XState, group: String, kind: int, id: int, base_max: int) -> int:
	return base_max if group == "" else mini(base_max, remaining(s, group, kind, id))


# ---- 记账 ----

## Scene_Shop.doBuy 之后：扣库存并登记补货（货币与物品已由 XItemMarks.buy 记过）
static func record_purchase(s: XState, group: String, kind: int, id: int, number: int) -> void:
	if group == "":
		return
	_set_stock(s, group, kind, id, remaining(s, group, kind, id) - number)
	_register(s, group, kind, id)


## Scene_Shop.doSell 之后：卖回的商品补回该组库存（不超过上限）。独立装备卖的是实例（另有 ID），原版记在实例上、
## 不回商品库存（stock.gear-buy-sell），这里不记。
static func record_sale(s: XState, group: String, kind: int, id: int, number: int) -> void:
	if group == "" or kind != 0:
		return
	_set_stock(s, group, kind, id, remaining(s, group, kind, id) + number)


static func _set_stock(s: XState, group: String, kind: int, id: int, n: int) -> void:
	if not managed(kind, id):
		return
	var inv: Dictionary = _inv(s, group, true)
	if not inv.stock.has(KINDS[kind]):
		inv.stock[KINDS[kind]] = {}
	inv.stock[KINDS[kind]][str(id)] = clampi(n, 0, stock_max(kind, id))


static func _inv(s: XState, group: String, create: bool):
	if not s.shop_stock.has("inv"):
		reset_all(s)
	var all: Dictionary = s.shop_stock.inv
	if not all.has(group):
		if not create:
			return null
		all[group] = {"speed": 1.0, "stock": {}}
	return all[group]


# ---- 补货 ----

## Game_ShopInventory.getSupplyInterval：间隔×倍率取整；倍率 NaN（null）时返回 -1（不补）
static func _interval(s: XState, group: String, kind: int, id: int) -> int:
	var speed = _inv(s, group, true).speed
	if speed == null:
		return -1
	return maxi(floori(int(spec(kind, id).get("interval", 0)) * float(speed)), 0)


static func _count(s: XState, kind: int, id: int) -> int:
	return floori(s.play_seconds) if int(spec(kind, id).get("mode", 0)) == 0 else -1


## Game_ShopInventorySupplier.register：同组同商品已有有效计划就不重登；间隔 0 的不登记
static func _register(s: XState, group: String, kind: int, id: int) -> void:
	for sc in s.shop_stock.schedules:
		if sc.group == group and int(sc.kind) == kind and int(sc.id) == id:
			return
	if _interval(s, group, kind, id) <= 0:
		return
	var now := _count(s, kind, id)
	if now >= 0:
		s.shop_stock.schedules.append({"group": group, "kind": kind, "id": id, "start": now})


## Game_ShopInventorySupplier.update：每个计划按经过的间隔数补货，补满就停
static func update_supplier(s: XState) -> void:
	if not s.shop_stock.has("schedules"):
		reset_all(s)
	var keep := []
	for sc in s.shop_stock.schedules:
		var kind := int(sc.kind)
		var id := int(sc.id)
		var iv := _interval(s, sc.group, kind, id)
		if iv <= 0:
			continue
		var now := _count(s, kind, id)
		if now < 0:
			continue
		if now < int(sc.start):
			sc.start = now
		var n := floori((now - int(sc.start)) / float(iv))
		if n > 0:
			_set_stock(s, sc.group, kind, id, remaining(s, sc.group, kind, id) + n)
			if remaining(s, sc.group, kind, id) >= stock_max(kind, id):
				continue
			sc.start = int(sc.start) + n * iv
		keep.append(sc)
	s.shop_stock.schedules = keep


## 读档：旧档缺这一项给空库存（全满）；JSON 读回的数字统一成整数
static func from_save(d) -> Dictionary:
	var out := {"inv": {}, "schedules": []}
	if not d is Dictionary:
		return out
	var inv = d.get("inv", {})
	if inv is Dictionary:
		for g in inv:
			var row: Dictionary = inv[g] if inv[g] is Dictionary else {}
			var stock := {}
			for k in row.get("stock", {}):
				stock[str(k)] = {}
				for id in row.stock[k]:
					stock[str(k)][str(id)] = int(row.stock[k][id])
			var speed = row.get("speed", 1.0)
			out.inv[str(g)] = {"speed": null if speed == null else float(speed), "stock": stock}
	for sc in d.get("schedules", []):
		if sc is Dictionary:
			out.schedules.append({"group": str(sc.get("group", "")), "kind": int(sc.get("kind", 0)), "id": int(sc.get("id", 0)), "start": int(sc.get("start", 0))})
	return out
