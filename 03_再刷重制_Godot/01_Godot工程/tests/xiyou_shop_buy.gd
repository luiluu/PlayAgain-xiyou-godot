extends Node
## 商店买入（XItemMarks.can_buy／max_buy／buy，YEP_X_MoreCurrencies 变量/物品买入价、代购，进阶石层数门槛）：
## 与 mv_oracle shop_buy_probe 的参照（generated/oracle/shop_buy.json）逐例比对——切片各图商店的每件商品 × 持有状态，
## 界面（标准级）：价格列、数量窗买入列、金钱窗与正式版运行时的绘制调用（ui_reference 浏览器里记录 contents.drawText／drawIcon，
## 2026-10-15）逐项比对。窗口模式加 -- --out=<目录> 保存截图。
## 比商品表整理（Scene_Shop.prepare）、能否选（isEnabled）、最多买几个（maxBuy）、买入后金币／变量／物品／武器／防具的变化，以及买入价解析与是否画金币。

const ORACLE := "res://modes/xiyou/generated/oracle/shop_buy.json"
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 12:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _price(g: Array, rec: Dictionary) -> int:
	return int(g[3]) if int(g[2]) == 1 else int(rec.get("price", 0))


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if check("shop_buy_oracle_loaded", data is Dictionary and data.get("cases", []).size() >= 1000, ORACLE):
		# 商品表：Scene_Shop.prepare 整条链的改写
		for sh in data.shops:
			var got := XItemMarks.shop_goods(sh.raw)
			var want: Array = sh.prepared.map(func(g): return [int(g[0]), int(g[1]), int(g[2]), int(g[3])])
			check("prepare_map%d_ev%d" % [int(sh.map), int(sh.event)], got == want, [got, want])
			# 宝珠运行时：整理后为空（全是宝珠）的店一打开就提示并关闭
			check("orb_only_map%d_ev%d" % [int(sh.map), int(sh.event)], XItemMarks.shop_orb_only(sh.raw) == (want.is_empty() and not sh.raw.is_empty()), [sh.raw.size(), want.size()])
		# 解析：买入价（插件 unshift 的顺序 = 备注行倒序）、代购、是否画金币
		for p in data.goods:
			var rec := XItemMarks.shop_rec(int(p.goods[0]), int(p.goods[1]))
			var r := XItemMarks.sell_rewards(rec)
			var vars: Array = r.buy_vars.keys().map(func(k): return [int(k), int(r.buy_vars[k])])
			var items: Array = r.buy_items.keys().map(func(k): return [int(k), int(r.buy_items[k])])
			vars.reverse()
			items.reverse()
			var got := [vars, items, XItemMarks.proxy_buy(rec), int(rec.get("price", 0)) > 0]
			var want := [p.variableBuyPrices.map(func(x): return [int(x[0]), int(x[1])]), p.itemBuyPrices.map(func(x): return [int(x[0]), int(x[1])]), int(p.proxyBuy), bool(p.drawsGold)]
			check("parse_%s" % JSON.stringify(p.goods), got == want, [got, want])
		for c in data.cases:
			var g: Array = c.goods
			var rec := XItemMarks.shop_rec(int(g[0]), int(g[1]))
			var price := _price(g, rec)
			var s := XState.new_game_blank()
			s.gold = int(c.gold)
			for v in c.vars:
				s.set_variable(int(v), float(c.vars[v]))
			for id in c.items:
				s.gain_item(int(id), int(c.items[id]))
			var got := {"enabled": XItemMarks.can_buy(s, rec, price), "max": XItemMarks.max_buy(s, rec, price)}
			var want := {"enabled": bool(c.enabled), "max": int(c.max)}
			if c.delta != null:
				var before := _snap(s)
				XItemMarks.buy(s, rec, price, int(c.number))
				got.delta = _delta(before, _snap(s))
				want.delta = _norm(c.delta)
			check("%s_%s" % [JSON.stringify(g), c.state], got == want, [got, want])
		check("shop_buy_currency_covered", data.goods.filter(func(p): return p.variableBuyPrices.size() + p.itemBuyPrices.size() > 0).size() >= 100)
		check("shop_buy_bought_covered", data.cases.filter(func(c): return c.delta != null).size() >= 500)
	await _ui_reference()
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _snap(s: XState) -> Dictionary:
	var count := func(kind: String) -> Dictionary:
		var out := {}
		for e in s.gear:
			if e.kind == kind:
				out[int(e.base)] = int(out.get(int(e.base), 0)) + 1
		return out
	return {"gold": s.gold, "vars": s.variables.duplicate(), "items": s.items.duplicate(), "weapons": count.call("weapon"), "armors": count.call("armor")}


func _delta(a: Dictionary, b: Dictionary) -> Dictionary:
	var d := {"gold": b.gold - a.gold, "vars": {}, "items": {}, "weapons": {}, "armors": {}}
	for k in ["vars", "items", "weapons", "armors"]:
		var keys := {}
		for x in a[k]:
			keys[int(x)] = true
		for x in b[k]:
			keys[int(x)] = true
		for id in keys:
			var v := int(b[k].get(id, 0)) - int(a[k].get(id, 0))
			if v != 0:
				d[k][id] = v
	return d


## 参照的 delta 键是字符串、值是浮点：统一成整数键、整数值
func _norm(d: Dictionary) -> Dictionary:
	var out := {"gold": int(d.gold), "vars": {}, "items": {}, "weapons": {}, "armors": {}}
	for k in ["vars", "items", "weapons", "armors"]:
		for id in d[k]:
			out[k][int(id)] = int(d[k][id])
	return out


class RecCanvas extends XMVCanvas:
	var log := []

	func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, zoom := 1.0, pivot := Vector2.ZERO) -> void:
		log.append(["text", s, x + max_w, y, color.to_html(false), size, align])

	func icon(index: int, x: float, y: float, alpha := 1.0, size := 32.0) -> void:
		log.append(["icon", index, x, y])

	func cursor(r: Rect2, active := true) -> void:
		pass


## 正式版运行时记录：金币 12,345，变量 206（肝帝积分）=5000，物品 182×400、2201×50；商品 [物品 2230, 防具 4375, 物品 732]。
## [文字或图标, 内容, 文字右缘或图标 x, y, 颜色]；只取货币部分（字号 20 的文字与非行首图标）。
## 2230：0 价，变量 206 买 1000＋物品 2201 买 30 → 不画金币；4375：金币 5000＋物品 182 买 333；732：0 价，变量 206 买 130。
const UI_REF := {
	"list": [["text", "肝帝积分", 734, 0, "84aaff"], ["icon", 2242, 616, 2], ["text", "1,000", 616, 0, "ffffff"], ["icon", 354, 525.25, 2], ["text", "30", 525.25, 0, "ffffff"],
		["text", "5,000", 698, 36, "ffffff"], ["icon", 416, 702, 38], ["icon", 2013, 605.25, 38], ["text", "333", 605.25, 36, "ffffff"],
		["text", "肝帝积分", 734, 72, "84aaff"], ["icon", 2242, 616, 74], ["text", "130", 616, 72, "ffffff"]],
	"number0": [["text", "肝帝积分", 734, 108, "84aaff"], ["icon", 2242, 616, 110], ["text", "5,000", 616, 108, "ffffff"],
		["text", "肝帝积分", 734, 144, "84aaff"], ["icon", 2242, 616, 146], ["text", "-2,000", 616, 144, "ffffff"],
		["text", "肝帝积分", 734, 180, "84aaff"], ["icon", 2242, 616, 182], ["text", "3,000", 616, 180, "ffffff"],
		["icon", 354, 511.265625, 110], ["text", "50", 511.265625, 108, "ffffff"], ["icon", 354, 511.265625, 146], ["text", "-60", 511.265625, 144, "ffffff"],
		["icon", 354, 511.265625, 182], ["text", "-10", 511.265625, 180, "ffffff"]],
	"number1": [["text", "12,345", 698, 108, "ffffff"], ["icon", 416, 702, 110], ["text", "-10,000", 698, 144, "ffffff"], ["icon", 416, 702, 146],
		["text", "2,345", 698, 180, "ffffff"], ["icon", 416, 702, 182],
		["icon", 2013, 568.453125, 110], ["text", "400", 568.453125, 108, "ffffff"], ["icon", 2013, 568.453125, 146], ["text", "-666", 568.453125, 144, "ffffff"],
		["icon", 2013, 568.453125, 182], ["text", "-266", 568.453125, 180, "ffffff"]],
	"gold0": [["text", "肝帝积分", 478, 0, "84aaff"], ["icon", 2242, 360, 2], ["text", "5,000", 360, 0, "ffffff"], ["icon", 354, 269.25, 2], ["text", "50", 269.25, 0, "ffffff"]],
}


func _ui_reference() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.gold = 12345
	s.set_variable(206, 5000)
	s.gain_item(182, 400)
	s.gain_item(2201, 50)
	var shop := XShop.new()
	shop.setup([[0, 2230, 0, 0], [2, 4375, 0, 0], [0, 732, 0, 0]], false)
	add_child(shop)
	for _i in range(4):
		await get_tree().process_frame
	shop._mode = "buy"
	shop._buy_index = 0
	shop._refresh()
	await _compare_paint("list", shop._paint_list, 740, func(e): return not (e[0] == "icon" and e[2] == 2.0) and not (e[0] == "text" and e[5] != 20))
	await _compare_paint("gold0", shop._paint_gold, 484, func(e): return true)
	if out_dir != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("Godot_买入列表.png"))
	for i in [0, 1]:
		shop._mode = "buy"
		shop._buy_index = i
		shop._number_from = "buy"
		shop._mode = "number"
		shop._number = 2
		shop._refresh()
		await _compare_paint("number%d" % i, shop._paint_number, 740, func(e): return float(e[3]) >= 108)
		if i == 0 and out_dir != "" and DisplayServer.get_name() != "headless":
			# 截图使用可实际购买的 1 件（上述 2 件夹具只测绘制，持有的材料不够买两件）。
			shop._number = 1
			shop._refresh()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("Godot_买入数量窗_2230.png"))
	shop.queue_free()


## 按顺序比对每个画图调用；位置差在 3 像素内（MV 与 Godot 字宽略有差别，后一列会累积），文字比颜色与字号 20、右对齐
func _compare_paint(key: String, painter: Callable, width: float, keep: Callable) -> void:
	var rc := RecCanvas.new()
	rc.size = Vector2(width, 511)
	rc.painter = painter
	add_child(rc)
	for _i in range(2):
		await get_tree().process_frame
	var got: Array = rc.log.filter(keep)
	var want: Array = UI_REF[key]
	var ok: bool = got.size() == want.size()
	for i in range(mini(got.size(), want.size())):
		var g: Array = got[i]
		var w: Array = want[i]
		ok = ok and g[0] == w[0] and str(g[1]) == str(w[1]) and absf(float(g[2]) - float(w[2])) <= 3 and float(g[3]) == float(w[3])
		if w[0] == "text":
			ok = ok and g[4] == w[4] and g[5] == 20 and g[6] == "right"
	check("ui_" + key, ok, [got.map(func(e): return e.slice(0, 5)), want])
	rc.queue_free()
