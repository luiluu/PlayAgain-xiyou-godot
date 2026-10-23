extends Node
## 法宝图标等级字（CP_MagicWeapon drawItemName → drawLevelOnIcon）：对照冻结 v0.28 浏览器参照 tests/fixtures/magic_level_oracle.json。
## 商店买入列表（大罗剑胎、麒麟对剑带等级字；画完不透明度回到不透明，同行价格不再半透明）、装备槽（第 13 槽法宝）、物品详情头画；
## 物品列表一系（物品页、出售、装备候选）不画。

const FIXTURE := "res://tests/fixtures/magic_level_oracle.json"
const TOL := 0.05

var results := []


class RecCanvas extends XMVCanvas:
	var log := []

	func text(t: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, zoom := 1.0, pivot := Vector2.ZERO, outline := OUTLINE) -> void:
		log.append(["t", t, x, y, max_w, align, size, color.to_html(false), roundi(alpha * 255)])

	func icon(index: int, x: float, y: float, alpha := 1.0, size := 32.0) -> void:
		log.append(["i", index, x, y, roundi(alpha * 255)])

	func cursor(r: Rect2, active := true) -> void:
		pass


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func _paint(painter: Callable, size: Vector2) -> Array:
	var rc := RecCanvas.new()
	rc.size = size
	rc.painter = painter
	add_child(rc)
	for _i in range(2):
		await get_tree().process_frame
	var out := rc.log.duplicate()
	rc.queue_free()
	return out


static func _col(t: String) -> String:
	return (XQuality.parse_rgba(t) if t.begins_with("rgba") else Color(t)).to_html(false)


## 参照里的等级字（16 号）逐条在 Godot 记录里找到：文字、坐标、宽、对齐、颜色、不透明度相等
## x_tol：装备槽的槽名宽 Godot 取整数字宽（59，原版 59.21），图标与等级字都跟着差 0.21，属原有差异
static func badges_match(log: Array, ref_ops: Array, x_tol := TOL) -> String:
	for o in ref_ops:
		if o[0] != "t" or int(o[6]) != 16:
			continue
		var found := false
		for g in log:
			if g[0] == "t" and g[1] == str(o[1]) and absf(g[2] - float(o[2])) < x_tol and absf(g[3] - float(o[3])) < TOL \
					and absf(g[4] - float(o[4])) < TOL and g[5] == str(o[5]) and int(g[6]) == 16 and g[7] == _col(str(o[7])) and g[8] == int(o[8]):
				found = true
		if not found:
			return "缺 %s；Godot 16 号字：%s" % [JSON.stringify(o), JSON.stringify(log.filter(func(g): return g[0] == "t" and int(g[6]) == 16))]
	return ""


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture_loaded", ref is Dictionary and ref.has("shopBuy")):
		get_tree().quit.call_deferred(1)
		return
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	XState.current = s
	check("magic_flags", XEquipmentView.level(XDB.rec("Armors", 13)) == 1.0 and XEquipmentView.level(XDB.rec("Weapons", 73)) == 1.0
		and XEquipmentView.level(XDB.rec("Armors", 52)) == -1.0)
	# 商店买入
	var shop := XShop.new()
	# 参照的 goods：防具 13、武器 73、防具 52
	shop.setup([[2, 13, 0, 0], [1, 73, 0, 0], [2, 52, 0, 0]], false)
	add_child(shop)
	await get_tree().process_frame
	shop._mode = "buy"
	shop._buy_index = -1
	var log := await _paint(shop._paint_list, shop.list_win.canvas.size)
	var d := badges_match(log, ref.shopBuy.ops)
	check("shop_buy_badges", d == "", d)
	# 第 0 行（买不起，名字半透明）的价格因等级字改回不透明；草帽（非法宝）价格仍半透明
	var name0 := log.filter(func(g): return g[0] == "t" and g[1] == "大罗剑胎")
	var price0 := log.filter(func(g): return g[0] == "t" and int(g[6]) == 20 and absf(g[3]) < TOL)
	var price2 := log.filter(func(g): return g[0] == "t" and int(g[6]) == 20 and absf(g[3] - 72.0) < TOL)
	check("shop_buy_opacity", not name0.is_empty() and name0[0][8] == 160 and not price0.is_empty() and price0.all(func(g): return g[8] == 255)
		and not price2.is_empty() and price2.all(func(g): return g[8] == 160), [name0, price0, price2])
	shop.queue_free()
	# 装备槽：角色 1 第 13 槽（法宝）装大罗剑胎
	var a := s.actor(1)
	var inst := XGear.create("armor", 13, s)
	s.register_gear(inst)
	a.equips[int(ref.slot.slotIndex)] = inst
	var eq := XEquipScene.new()
	add_child(eq)
	await get_tree().process_frame
	var r: Array = ref.slot.rect
	log = await _paint(eq._paint_list, Vector2(float(r[2]) - 28, float(r[3]) - 28))
	d = badges_match(log, ref.slot.ops, 0.25)
	check("equip_slot_badge", d == "", d)
	eq.queue_free()
	# 物品详情头
	log = await _paint(func(c): XItemScene.paint_info(c, inst), Vector2(612, 520))
	d = badges_match(log, ref.itemInfo.ops)
	check("item_info_badge", d == "", d)
	# 物品列表一系不画
	log = await _paint(func(c): XItemRow.paint(c, inst, 0, "1/9,999"), Vector2(606, 100))
	check("item_list_no_badge", log.filter(func(g): return g[0] == "t" and int(g[6]) == 16).is_empty(), log)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
