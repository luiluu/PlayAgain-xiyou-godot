extends Node
## 商店限购（KMS_ShopInventory，XShopStock）：
## - 严格级：与 mv_oracle/shared/stock.cjs 的冻结 v0.28 参照（generated/oracle/shop_stock.json）逐例比——零库存、刚好买完、
##   重开与卖回、共享组／不同组、预览与取消不耗库存、金钱不足、多货币与货币不足、restockAll／resetAll、上下限、按游戏时间补货、
##   不补货、supplySpeed（原版 NaN）、待用组覆盖、存读档、独立装备买卖、二十层后索礼商店（1912、1916 正式组名）。
## - 目录：全部受管商品的备注解析、全部 ShopInventory 指令的组名；解释器的插件指令把组交给下一次商店。
## - 界面（标准级）：tests/fixtures/shop_stock_ui_oracle.json 的正式版运行时读数（售完行、状态窗库存行），位置差 3 像素内。
## - 存档：旧档没有 shopStock 时全满。
## 窗口模式加 -- --out=<目录> 保存与正式版截图（codex_shop_stock_reference.png）同一夹具的 Godot 画面。

const ORACLE := "res://modes/xiyou/generated/oracle/shop_stock.json"
const UI_ORACLE := "res://tests/fixtures/shop_stock_ui_oracle.json"
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 15:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


# ---- 夹具：与 stock.cjs 的 shop()/snap() 同义 ----
class Shop:
	var s: XState
	var group := ""
	var kind := 0
	var id := 0
	var price := 0
	var item := {}

	func _init(st: XState, g, goods: Array) -> void:
		s = st
		if g != null:
			XShopStock.apply_group(s, str(g))
		group = XShopStock.open(s)
		kind = int(goods[0])
		id = int(goods[1])
		item = XItemMarks.shop_rec(kind, id)
		price = int(goods[3]) if int(goods[2]) == 1 else int(XDB.rec(XShopStock.TABLES[kind], id).get("price", 0))

	func max_buy() -> int:
		return XShopStock.max_buy(s, group, kind, id, XItemMarks.max_buy(s, item, price))

	func snap() -> Dictionary:
		return {"stock": XShopStock.remaining(s, group, kind, id) if group != "" else null,
			"enabled": XItemMarks.can_buy(s, item, price) and XShopStock.available(s, group, kind, id),
			"max": max_buy(), "gold": s.gold, "owned": s.item_count(id) if kind == 0 else 0,
			"nextInventory": null if s.shop_pending == "" else s.shop_pending}

	func buy(n: int) -> void:
		XItemMarks.buy(s, item, price, n)
		XShopStock.record_purchase(s, group, kind, id, n)

	func sell(n: int) -> void:
		XItemMarks.sell(s, XDB.rec("Items", id), n)
		XShopStock.record_sale(s, group, kind, id, n)


func _fixture() -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	s.gold = 10000000
	return s


func _pay(s: XState, kind: int, id: int) -> void:
	var r := XItemMarks.sell_rewards(XItemMarks.shop_rec(kind, id))
	for v in r.buy_vars:
		s.set_variable(int(v), 1000000)
	for k in r.buy_items:
		s.gain_item(int(k), 9999)


func _roundtrip(s: XState) -> XState:
	var d = JSON.parse_string(JSON.stringify(s.to_dict()))
	return XState.from_dict(d)


## 参照里的数字是浮点：统一后比较
func _same(a, b) -> bool:
	return JSON.stringify(_norm(a)) == JSON.stringify(_norm(b))


func _norm(v):
	if v is float and v == floorf(v):
		return int(v)
	if v is Dictionary:
		var keys: Array = v.keys()
		keys.sort()
		var out := {}
		for k in keys:
			out[str(k)] = _norm(v[k])
		return out
	if v is Array:
		return v.map(func(x): return _norm(x))
	return v


func _case(id: String) -> Dictionary:
	var s := _fixture()
	match id:
		"stock.purchase-reopen-sell":
			var sc := Shop.new(s, "oracle_shared", [0, 1911, 1, 10])
			var trace := [sc.snap()]
			sc.buy(2)
			trace.append(sc.snap())
			var re := Shop.new(s, "oracle_shared", [0, 1911, 1, 10])
			trace.append(re.snap())
			re.buy(3)
			trace.append(re.snap())
			re.sell(1)
			trace.append(re.snap())
			return {"trace": trace}
		"stock.group-scope":
			Shop.new(s, "shared_A", [0, 1911, 1, 10]).buy(2)
			Shop.new(s, "shared_B", [0, 1911, 1, 10])
			var again := Shop.new(s, "shared_A", [0, 1911, 1, 10])
			return {"a": XShopStock.remaining(s, "shared_A", 0, 1911), "b": XShopStock.remaining(s, "shared_B", 0, 1911),
				"sameObject": again.group == "shared_A", "nextConsumed": s.shop_pending == "", "ungrouped": Shop.new(s, null, [0, 1911, 1, 10]).group == ""}
		"stock.cancel-preview":
			var sc := Shop.new(s, "cancel", [0, 1911, 1, 10])
			var before := sc.snap()
			var saved := JSON.stringify(s.shop_stock)
			for i in range(5):
				sc.max_buy()
				XShopStock.available(s, "cancel", 0, 1911)
			check("cancel_preview_state_untouched", JSON.stringify(s.shop_stock) == saved)
			return {"before": before, "after": Shop.new(s, "cancel", [0, 1911, 1, 10]).snap()}
		"stock.affordability":
			s.gold = 9
			return Shop.new(s, "poor", [0, 1911, 1, 10]).snap()
		"stock.memory-roundtrip":
			Shop.new(s, "persist", [0, 1911, 1, 10]).buy(2)
			var before := XShopStock.remaining(s, "persist", 0, 1911)
			var s2 := _roundtrip(s)
			return {"before": before, "after": Shop.new(s2, "persist", [0, 1911, 1, 10]).snap(), "prototypeRestored": s2.shop_stock.inv.has("persist")}
		"stock.restock-reset":
			Shop.new(s, "reset", [0, 1911, 1, 10]).buy(2)
			var trace := [XShopStock.remaining(s, "reset", 0, 1911)]
			XShopStock.plugin_command(s, PackedStringArray(["ShopInventory", "restockAll", "reset"]))
			trace.append(XShopStock.remaining(s, "reset", 0, 1911))
			Shop.new(s, "reset", [0, 1911, 1, 10]).buy(1)
			XShopStock.plugin_command(s, PackedStringArray(["ShopInventory", "resetAll"]))
			var exists: bool = s.shop_stock.inv.has("reset")
			trace.append(XShopStock.remaining(s, "reset", 0, 1911))
			return {"trace": trace, "existsBeforeRead": exists}
		"stock.clamp-and-type":
			XShopStock._set_stock(s, "types", 0, 1911, -100)
			var low := XShopStock.remaining(s, "types", 0, 1911)
			XShopStock._set_stock(s, "types", 0, 1911, 10000)
			XShopStock._set_stock(s, "types", 2, 133, XShopStock.remaining(s, "types", 2, 133) - 1)
			return {"low": low, "high": XShopStock.remaining(s, "types", 0, 1911), "armor": XShopStock.remaining(s, "types", 2, 133),
				"armorMax": XShopStock.stock_max(2, 133), "unmanaged": XShopStock.managed(0, 1), "unmanagedStock": XShopStock.remaining(s, "types", 0, 1)}
		"stock.time-restock":
			s.play_seconds = 0
			XShopStock._set_stock(s, "timed", 0, 77, XShopStock.remaining(s, "timed", 0, 77) - 5)
			XShopStock._register(s, "timed", 0, 77)
			var trace := []
			for sec in [29, 30, 90, 150]:
				s.play_seconds = sec
				XShopStock.update_supplier(s)
				trace.append({"seconds": sec, "stock": XShopStock.remaining(s, "timed", 0, 77)})
			return {"trace": trace}
		"stock.no-restock":
			XShopStock._set_stock(s, "never", 0, 150, 0)
			XShopStock._register(s, "never", 0, 150)
			s.play_seconds = 600
			XShopStock.update_supplier(s)
			return {"stock": XShopStock.remaining(s, "never", 0, 150)}
		"stock.supply-speed-command":
			XShopStock.plugin_command(s, PackedStringArray(["ShopInventory", "supplySpeed", "speed", "3"]))
			var nan := s.shop_stock.inv.speed.speed == null and XShopStock._interval(s, "speed", 0, 1911) < 0
			return {"raw": "NaN" if nan else "x", "interval": "NaN" if nan else "x"}
		"stock.pending-overwrite":
			XShopStock.plugin_command(s, PackedStringArray(["ShopInventory", "apply", "pending_A"]))
			XShopStock.plugin_command(s, PackedStringArray(["ShopInventory", "apply", "pending_B"]))
			var first := XShopStock.open(s)
			var second := XShopStock.open(s)
			return {"first": first, "second": null if second == "" else second, "nextInventory": null if s.shop_pending == "" else s.shop_pending}
		"stock.timer-memory-roundtrip":
			s.play_seconds = 0
			XShopStock._set_stock(s, "saved_timer", 0, 77, 0)
			XShopStock._register(s, "saved_timer", 0, 77)
			s.play_seconds = 29
			var s2 := _roundtrip(s)
			var trace := [XShopStock.remaining(s2, "saved_timer", 0, 77)]
			s2.play_seconds = 30
			XShopStock.update_supplier(s2)
			trace.append(XShopStock.remaining(s2, "saved_timer", 0, 77))
			return {"trace": trace}
		"stock.gear-buy-sell":
			_pay(s, 2, 4279)
			var sc := Shop.new(s, "gear", [2, 4279, 0, 0])
			var before := sc.snap()
			var n0 := s.gear.size()
			sc.buy(1)
			var after := sc.snap()
			var bought := s.gear.size() > n0
			if bought:
				var inst: Dictionary = s.gear[s.gear.size() - 1]
				XItemMarks.sell(s, inst, 1)
				XShopStock.record_sale(s, "gear", 2, int(inst.get("id", 0)), 1)
			return {"before": before, "after": after, "instanceSold": bought, "baseAfterSell": XShopStock.remaining(s, "gear", 2, 4279)}
	if id.begins_with("stock.currency-and-stock."):
		var gid := int(id.get_slice(".", 2))
		var sc := Shop.new(s, "oracle_currency_%d" % gid, [0, gid, 0, 0])
		_pay(s, 0, gid)
		var before := sc.snap()
		var r := XItemMarks.sell_rewards(sc.item)
		var vars := {}
		for v in r.buy_vars:
			vars[v] = s.variable(int(v))
		var items := {}
		for k in r.buy_items:
			items[k] = s.item_count(int(k))
		if before.enabled and int(before.max) > 0:
			sc.buy(1)
		return {"before": before, "after": sc.snap(), "currencies": r.buy_vars.keys().map(func(v): return [int(v), vars[v], s.variable(int(v))]),
			"itemCurrencies": r.buy_items.keys().map(func(k): return [int(k), items[k], s.item_count(int(k))])}
	if id.begins_with("stock.currency-short."):
		var gid := int(id.get_slice(".", 2))
		var r := XItemMarks.sell_rewards(XItemMarks.shop_rec(0, gid))
		for v in r.buy_vars:
			s.set_variable(int(v), maxi(0, int(r.buy_vars[v]) - 1))
		for k in r.buy_items:
			s.gain_item(int(k), maxi(0, int(r.buy_items[k]) - 1))
		var sc := Shop.new(s, "short_%d" % gid, [0, gid, 0, 0])
		var before := sc.snap()
		return {"before": before, "after": sc.snap()}
	if id.begins_with("stock.floor-shop."):
		var gid := int(id.get_slice(".", 2))
		var group: String = {1912: "群仙俯首购买", 1916: "天宫之寒购买"}[gid]
		_pay(s, 0, gid)
		var sc := Shop.new(s, group, [0, gid, 0, 0])
		var trace := [sc.snap()]
		sc.buy(2)
		trace.append(sc.snap())
		var again := Shop.new(s, group, [0, gid, 0, 0])
		trace.append(again.snap())
		again.buy(again.max_buy())
		trace.append(again.snap())
		trace.append(Shop.new(s, group, [0, gid, 0, 0]).snap())
		trace.append(Shop.new(s, "其它组", [0, gid, 0, 0]).snap())
		return {"trace": trace}
	return {}


## 参照里只比 Godot 能对应的键（sameObject 为同一组、prototypeRestored 为读回后组仍在；prepared／armorKeys／armors 等原版对象细节不比）
const SKIP_KEYS := ["prepared", "armorKeys", "armors", "ownedAfterSell"]


func _strip(v):
	if v is Dictionary:
		var out := {}
		for k in v:
			if not SKIP_KEYS.has(str(k)):
				out[k] = _strip(v[k])
		return out
	if v is Array:
		return v.map(func(x): return _strip(x))
	return v


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if check("stock_oracle_loaded", data is Dictionary and data.get("cases", []).size() >= 19, ORACLE):
		for c in data.cases:
			if not c.errors.is_empty():
				check("oracle_" + c.id, false, c.errors)
				continue
			var got = _case(c.id)
			var want = _strip(c.observed)
			check(c.id, not got.is_empty() and _same(_strip(got), want), [got, want])
		# 目录：备注解析（上限、间隔、方式）
		var bad := []
		var absent := []
		for e in data.catalog:
			var k := ["item", "weapon", "armor"].find(str(e.kind))
			if XDB.rec(XShopStock.TABLES[k], int(e.id)).is_empty():
				absent.append(int(e.id))
				continue
			var sp := XShopStock.spec(k, int(e.id))
			if sp.is_empty() or int(sp.max) != int(e.max) or int(sp.interval) != int(e.interval) or int(sp.mode) != int(e.mode):
				bad.append([e, sp])
		check("catalog_parse_%d" % data.catalog.size(), bad.is_empty(), bad.slice(0, 5))
		# 未导出的数据库行（切片外）不计；只允许少量
		check("catalog_absent_few", absent.size() <= 5, absent)
		# 全部 ShopInventory 指令：apply 把正式组名交给下一次商店
		var groups := {}
		bad = []
		for l in data.locations:
			var s := _fixture()
			var args := str(l.command).split(" ", false)
			XShopStock.plugin_command(s, args)
			if args[1] != "apply" or XShopStock.open(s) != args[2]:
				bad.append(l)
			groups[args[2]] = true
		check("locations_apply_%d_groups_%d" % [data.locations.size(), groups.size()], bad.is_empty(), bad.slice(0, 5))
	await _interpreter()
	_old_save()
	await _ui()
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_shop_stock", "passed": failed.is_empty(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit(0 if failed.is_empty() else 1)


## 解释器：插件指令 356「ShopInventory apply 组」之后的 302 商店拿到该组（宿主 open_shop 同 XMapScene 先 XShopStock.open）
class ShopHost:
	extends Node
	var groups := []

	func open_shop(_goods: Array, _only: bool) -> void:
		groups.append(XShopStock.open(XState.current))

	func character(_id: int, _ev: int):
		return null


func _interpreter() -> void:
	var s := _fixture()
	var host := ShopHost.new()
	add_child(host)
	var cmds := [
		{"code": 356, "indent": 0, "parameters": ["ShopInventory apply 群仙俯首购买"]},
		{"code": 302, "indent": 0, "parameters": [0, 1912, 0, 0, true]},
		{"code": 302, "indent": 0, "parameters": [0, 1912, 0, 0, true]},
		{"code": 0, "indent": 0, "parameters": []}]
	var it := MVInterpreter.new(host, 116, 1, cmds)
	await it.run()
	check("interpreter_apply_then_shop", host.groups == ["群仙俯首购买", ""], host.groups)
	check("interpreter_not_skipped", it.skipped.filter(func(e): return str(e.get("text", "")).begins_with("ShopInventory")).is_empty(), it.skipped)
	check("pending_not_saved", not s.to_dict().has("shopPending") and _roundtrip(s).shop_pending == "")
	host.queue_free()


## 旧档（没有 shopStock）读回全满；新档带库存往返不变
func _old_save() -> void:
	var s := _fixture()
	Shop.new(s, "群仙俯首购买", [0, 1912, 0, 0]).buy(3)
	var d = JSON.parse_string(JSON.stringify(s.to_dict()))
	check("save_roundtrip", XShopStock.remaining(XState.from_dict(d), "群仙俯首购买", 0, 1912) == 2)
	d.erase("shopStock")
	var old := XState.from_dict(d)
	check("old_save_full_stock", XShopStock.remaining(old, "群仙俯首购买", 0, 1912) == 5 and old.shop_stock.inv.is_empty())


class RecCanvas extends XMVCanvas:
	var log := []

	func text(t: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, zoom := 1.0, pivot := Vector2.ZERO) -> void:
		log.append([t, x, y, max_w, align, size, color.to_html(false), alpha])

	func icon(index: int, x: float, y: float, alpha := 1.0, size := 32.0) -> void:
		pass

	func cursor(r: Rect2, active := true) -> void:
		pass


func _paint(painter: Callable, width: float) -> Array:
	var rc := RecCanvas.new()
	rc.size = Vector2(width, 455)
	rc.painter = painter
	add_child(rc)
	for _i in range(2):
		await get_tree().process_frame
	var out := rc.log.duplicate()
	rc.queue_free()
	return out


## 找文字：内容与 y 相同的画图调用；同名的几个（如「1/1」）取右缘最接近 right 的
func _find(log: Array, t: String, y: float, right := -1.0) -> Array:
	var best := []
	for e in log:
		if e[0] == t and absf(float(e[2]) - y) < 0.5:
			if right < 0:
				return e
			if best.is_empty() or absf(float(e[1]) + float(e[3]) - right) < absf(float(best[1]) + float(best[3]) - right):
				best = e
	return best


func _near(a, b) -> bool:
	return absf(float(a) - float(b)) <= 3


func _ui() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(UI_ORACLE))
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.gold = 10000000
	XShopStock._set_stock(s, "ref", 0, 1912, 0)
	XShopStock._set_stock(s, "ref", 0, 1685, 7)
	XShopStock.apply_group(s, "ref")
	var shop := XShop.new()
	shop.setup([[0, 1912, 0, 0], [0, 1685, 0, 0], [0, 1, 0, 0], [2, 4279, 0, 0]], false, XShopStock.open(s))
	add_child(shop)
	for _i in range(3):
		await get_tree().process_frame
	shop._mode = "buy"
	shop._buy_index = 1
	shop._refresh()
	if out_dir != "" and DisplayServer.get_name() != "headless":
		for _i in range(3):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("Godot_限购商店.png"))
	var w: float = shop.list_win.canvas.size.x
	var log := await _paint(shop._paint_list, w)
	var so: Array = ref.soldOutRow.soldOut
	var e := _find(log, "售完", 0)
	check("ui_sold_out", not e.is_empty() and _near(e[1], so[1]) and _near(e[3], so[3]) and e[4] == "right" and e[5] == int(so[5]) and e[6] == "ffffff" and absf(e[7] - 160.0 / 255.0) < 0.01, [e, so, w])
	var nm: Array = ref.soldOutRow.name
	e = _find(log, str(nm[0]), 0)
	check("ui_sold_out_name", not e.is_empty() and _near(float(e[1]) + float(e[3]), float(nm[1]) + float(nm[3])), [e, nm])
	check("ui_sold_out_no_price", log.filter(func(x): return absf(float(x[2])) < 0.5 and x[5] == 20).is_empty(), log)
	# 状态窗：物品库存行
	var sw: float = shop.status_win.canvas.size.x
	log = await _paint(shop._paint_status, sw)
	for t in ref.statusItem.texts.slice(1):
		e = _find(log, str(t[0]), float(t[2]))
		var right := float(t[1]) + float(t[3]) if t.size() > 5 else -1.0
		check("ui_status_item_" + str(t[0]), not e.is_empty() and e[5] == int(t[5] if t.size() > 5 else t[4]) and (right < 0 or _near(float(e[1]) + float(e[3]), right)), [e, t])
	# 装备：O-043 改到能力表下方；关掉优化回到原版第 2 行、20 号字
	shop._buy_index = 3
	shop._refresh()
	log = await _paint(shop._paint_status, sw)
	e = _find(log, "库存", 36 * 10)
	check("ui_status_gear_below_O043", not e.is_empty() and e[5] == XUI.FONT_SIZE, log.filter(func(x): return x[0] == "库存"))
	XShop.STOCK_GEAR_BELOW = false
	log = await _paint(shop._paint_status, sw)
	XShop.STOCK_GEAR_BELOW = true
	for t in ref.statusGear.texts:
		e = _find(log, str(t[0]), float(t[2]), float(t[1]) + float(t[3]))
		check("ui_status_gear_original_" + str(t[0]), not e.is_empty() and e[5] == int(t[5]) and _near(float(e[1]) + float(e[3]), float(t[1]) + float(t[3])), [e, t])
	# 操作：售完的行确定无效；1685 库存 7 时数量上限 7，买完变售完，库存记账
	shop._buy_index = 0
	shop._ok()
	check("ui_sold_out_not_selectable", shop._mode == "buy")
	s.gain_item(2530, 1000)
	shop._buy_index = 1
	shop._ok()
	check("ui_number_max_is_stock", shop._mode == "number" and shop._max_number() == 7, [shop._mode, shop._max_number()])
	shop._number = 7
	shop._ok()
	check("ui_bought_out", shop._mode == "buy" and XShopStock.remaining(s, "ref", 0, 1685) == 0 and s.item_count(1685) == 7 and s.item_count(2530) == 1000 - 14,
		[XShopStock.remaining(s, "ref", 0, 1685), s.item_count(1685), s.item_count(2530)])
	shop._ok()
	check("ui_bought_out_locked", shop._mode == "buy")
	# 不限购的店（没有 apply）：不画库存、不限量
	var free := XShop.new()
	free.setup([[0, 1912, 0, 0]], false, XShopStock.open(s))
	add_child(free)
	await get_tree().process_frame
	free._mode = "buy"
	free._refresh()
	log = await _paint(free._paint_status, sw)
	check("ui_unmanaged_shop_no_stock", _find(log, "库存", 36).is_empty() and free._max_number() > 5, [log, free._max_number()])
	free.queue_free()
	shop.queue_free()
