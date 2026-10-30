extends Node
## 兑换大厅 Map132 商店追加伙伴号角与专属法宝（XItemMarks.shop_goods 的 map_id、_lobby_additions）：与 mv_oracle/map132_shop_probe.cjs
## 的冻结 v0.28 参照（generated/oracle/map132_shops.json）逐店比——Map132 每家店在 mapId 132 与对照 131 下 Scene_Shop.prepare 整理后的商品表。
## 另核：商店界面按当前地图取商品（XShop._buy_data 读 XState.current.map_id），追加的号角都受限购管（上限 1）。

const ORACLE := "res://modes/xiyou/generated/oracle/map132_shops.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 12:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


static func _rows(a: Array) -> Array:
	return a.map(func(g): return [int(g[0]), int(g[1]), int(g[2]), int(g[3])])


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	var cases: Array = data.get("cases", []) if data is Dictionary else []
	if check("map132_oracle_loaded", cases.size() >= 80, ORACLE):
		var changed := 0
		var added := {}
		for c in cases:
			var want := _rows(c.prepared)
			var got := XItemMarks.shop_goods(c.raw, int(c.mapId))
			check("prepare_%s" % c.id, got == want, [got, want])
			if int(c.mapId) == 132:
				for g in want:
					if not _rows(c.raw).has(g):
						added["%d:%d" % [g[0], g[1]]] = true
						changed += 1
		# 参照里真的有追加（防止参照退化成 shop_buy 那样不设地图）：号角店 5 家、2788 店 3 页、不朽法宝店 20 张、秘籍店 2 页
		check("map132_has_additions", changed >= 60 and added.has("0:2902") and added.has("0:2940") and added.has("2:4001") and added.has("0:2933"), [changed, added.keys()])
		for k in added:
			var p: PackedStringArray = k.split(":")
			if p[0] == "0" and str(XDB.rec("Items", int(p[1])).get("name", "")).begins_with("伙伴号角："):
				check("stock_limited_%s" % k, XShopStock.stock_max(0, int(p[1])) == 1, XShopStock.stock_max(0, int(p[1])))
		# 界面：同一张号角店商品表，在 Map132 列出渡鸦号角，在别的地图不列
		var horn_case: Dictionary = {}
		for c in cases:
			if int(c.mapId) == 132 and _rows(c.prepared).has([0, 2902, 0, 0]):
				horn_case = c
				break
		var s := XState.new_game_blank()
		XState.current = s
		var shop := XShop.new()
		shop.setup(horn_case.get("raw", []), false)
		s.map_id = 132
		var ids_132: Array = shop._buy_data().map(func(e): return e.gid)
		s.map_id = 4
		var ids_4: Array = shop._buy_data().map(func(e): return e.gid)
		shop.free()
		check("shop_ui_uses_map_id", ids_132.has(2902) and not ids_4.has(2902), [ids_132.size(), ids_4.size()])
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_map132_shop", "passed": results.size() - failed.size(), "total": results.size(), "failed": failed.map(func(r): return r.name)}))
	get_tree().quit(0 if failed.is_empty() else 1)
