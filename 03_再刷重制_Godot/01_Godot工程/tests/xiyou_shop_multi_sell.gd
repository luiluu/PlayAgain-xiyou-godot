extends Node
## 【cc·T224·未经审查】商店批量出售（XShop.MULTI_SELL，O-待定）：
## - 武器列表按 C 标记两件（光标下移）、锁定的标不上；确定弹多选确认窗（默认停在「取消」），选「出售已选」一次卖掉，金钱与件数对上。
## - 「清空选择」只清标记不卖；退出出售列表清标记。
## - 数量窗：E 到最大可卖数，Q 回 1。
## - 回退：MULTI_SELL＝false 时按 C 不标、确定照旧进单件出售（装备数量窗）。
var checks := 0
var failures := []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func _ready() -> void:
	_run.call_deferred()


func key(shop: XShop, code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	shop._unhandled_input(ev)


func make_shop(s: XState) -> XShop:
	var shop := XShop.new()
	shop.setup([[0, 1, 0, 0]], false, "")
	add_child(shop)
	return shop


func _run() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.gear.clear()
	var made := []
	for id in [1, 2, 3, 4]:
		var e := XGear.create("weapon", id, s)
		s.register_gear(e)
		s.gear.append(e)
		made.append(e)
	made[2].name = str(made[2].name) + XItemMarks.LOCK
	s.gold = 0
	var shop := make_shop(s)
	await get_tree().process_frame
	shop._mode = "sell"
	shop._cat = 2  # 武器
	shop._sell_index = 0
	shop._refresh()
	var d := shop._sell_data()
	check("list", d.size() == 4, d.size())
	key(shop, XShop.MARK_KEY)
	check("mark.first", shop.is_marked(d[0].rec) and shop._sell_index == 1, shop._sell_index)
	key(shop, XShop.MARK_KEY)
	check("mark.second", shop._marks.size() == 2 and shop._sell_index == 2)
	key(shop, XShop.MARK_KEY)  # 第 3 件锁定：标不上、光标不动
	check("mark.locked", shop._marks.size() == 2 and shop._sell_index == 2, shop._marks.size())
	var want := XItemMarks.selling_price(made[0]) + XItemMarks.selling_price(made[1])
	check("gold.preview", shop.marked_gold() == want, [shop.marked_gold(), want])
	shop._ok()
	check("confirm.open", shop._mode == "confirm" and shop._confirm_kind == "multi" and shop._confirm == 3 and shop.confirm_win.visible)
	check("confirm.rows", str(shop.confirm_rows()[1][0]) == "出售已选" and bool(shop.confirm_rows()[1][1]))
	shop._ok()  # 停在「取消」：回列表，标记还在
	check("confirm.cancel", shop._mode == "sell" and shop._marks.size() == 2)
	shop._ok()
	shop._confirm = 1
	shop._ok()
	check("sold", shop._mode == "sell" and s.gear.size() == 2 and s.gold == want and shop._marks.is_empty()
		and not s.gear.any(func(e): return is_same(e, made[0]) or is_same(e, made[1])), [s.gear.size(), s.gold, want])
	# 清空选择
	shop._sell_index = 0
	shop._refresh()
	key(shop, XShop.MARK_KEY)
	shop._ok()
	shop._confirm = 2
	shop._ok()
	check("clear", shop._mode == "sell" and shop._marks.is_empty() and s.gear.size() == 2)
	key(shop, XShop.MARK_KEY)
	shop._cancel()
	check("leave.clears", shop._mode == "category" and shop._marks.is_empty())
	# 数量窗跳到头
	s.gain_item(1, 37)
	shop._mode = "sell"
	shop._cat = 0
	shop._refresh()
	var items := shop._sell_data()
	var idx := -1
	for i in items.size():
		if int(items[i].rec.id) == 1:
			idx = i
	shop._sell_index = maxi(idx, 0)
	shop._ok()
	check("number.open", shop._mode == "number" and shop._number == 1)
	key(shop, KEY_E)
	check("number.max", shop._number == s.item_count(1), [shop._number, s.item_count(1)])
	key(shop, KEY_Q)
	check("number.min", shop._number == 1, shop._number)
	shop._cancel()
	# 回退
	XShop.MULTI_SELL = false
	shop._mode = "sell"
	shop._cat = 2
	shop._refresh()
	var dd := shop._sell_data()
	shop._sell_index = range(dd.size()).filter(func(i): return XShop.can_mark(dd[i].rec))[0]
	key(shop, XShop.MARK_KEY)
	check("off.no_mark", shop._marks.is_empty())
	shop._ok()
	check("off.single", shop._mode == "number" and shop._number_from == "sell")
	shop._cancel()
	shop._mode = "sell"
	shop._cat = 0
	shop._sell_index = maxi(idx, 0)
	shop._ok()
	var before := shop._number
	key(shop, KEY_E)
	check("off.number_no_jump", shop._number == before, shop._number)
	XShop.MULTI_SELL = true
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
