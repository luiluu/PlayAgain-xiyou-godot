extends Node
## 商店买入（XItemMarks.can_buy／max_buy／buy，YEP_X_MoreCurrencies 变量/物品买入价、代购，进阶石层数门槛）：
## 与 mv_oracle shop_buy_probe 的参照（generated/oracle/shop_buy.json）逐例比对——切片各图商店的每件商品 × 持有状态，
## 比商品表整理（Scene_Shop.prepare）、能否选（isEnabled）、最多买几个（maxBuy）、买入后金币／变量／物品／武器／防具的变化，以及买入价解析与是否画金币。

const ORACLE := "res://modes/xiyou/generated/oracle/shop_buy.json"
var results := []


func _ready() -> void:
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
