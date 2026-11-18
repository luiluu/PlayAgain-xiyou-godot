extends Node
## 【cc·T224·未经审查】商店批量出售（XShop.MULTI_SELL，O-待定）：
## - 武器列表按 C 标记两件（光标下移）、锁定的标不上；确定弹多选确认窗（默认停在「取消」），选「出售已选」一次卖掉，金钱与件数对上。
## - 「清空选择」只清标记不卖；退出出售列表清标记。
## - 数量窗：E 到最大可卖数，Q 回 1。
## - R1（小A 核 P1-1／P2-1）：点行首图标能标；专属、已培养、锁定、模板缺失、不可出售、身上（不在背包）的按 C 和点图标都标不上；
##   标后变成不能卖的，预览金币和确认窗只算能卖的。
## - R1 清单 4：一键出售「出售类别」行循环全部／只卖武器／只卖护甲；清单 5：物品多选（整组、数量窗 C 按数量加入，重要物品、
##   卖不了的标不上）；自定义数量：数字键、退格、夹上限、0／空回 1，点数量行弹数字键盘编辑框。
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


func click_icon(shop: XShop, row: int, x := 10.0) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = XShop.LIST_RECT.position + Vector2(XMVWindow.PADDING + x, XMVWindow.PADDING + row * XShop.LH + XShop.LH / 2.0)
	shop._gui_input(ev)


## 找一件模板带 <req_actors:> 的武器（专属）且有金币售价
func exclusive_weapon_id() -> int:
	var tab = XDB.table("Weapons")
	for r in tab:
		if r is Dictionary and int(r.get("price", 0)) > 0 \
				and RegEx.create_from_string("(?i)<req_actors\\s*:").search(str(r.get("note", ""))) != null:
			return int(r.id)
	return 0


func r1_guards(shop: XShop, s: XState) -> void:
	s.gear.clear()
	shop._marks.clear()
	var ex_id := exclusive_weapon_id()
	check("r1.exclusive_found", ex_id > 0, ex_id)
	var g := {}
	for k in ["a", "b", "ex", "grown", "lock", "orphan", "nosell"]:
		var e := XGear.create("weapon", ex_id if k == "ex" else 1, s)
		s.register_gear(e)
		s.gear.append(e)
		g[k] = e
	g.grown["boostCount"] = 1
	g.lock.name = str(g.lock.name) + XItemMarks.LOCK
	g.orphan["base"] = 999999
	g.nosell["cannotSell"] = true
	var worn := XGear.create("weapon", 1, s)   # 不在背包（身上的）
	s.register_gear(worn)
	check("r1.worn", not XShop.can_mark(worn))
	shop._mode = "sell"
	shop._cat = 2
	shop._sell_index = 0
	shop._sell_top = 0
	shop._drop_cache()
	shop._refresh()
	var d := shop._sell_data()
	check("r1.list", d.size() == 7, d.size())
	var row_of := func(e) -> int:
		for i in d.size():
			if is_same(d[i].rec, e):
				return i
		return -1
	for k in ["ex", "grown", "lock", "orphan", "nosell"]:
		check("r1.can_mark." + k, not XShop.can_mark(g[k]), XSafeSell.reason(s, g[k]))
		shop._sell_index = row_of.call(g[k])
		key(shop, XShop.MARK_KEY)
		check("r1.key." + k, shop._marks.is_empty(), shop._marks.size())
		click_icon(shop, row_of.call(g[k]))
		check("r1.click." + k, shop._marks.is_empty(), shop._marks.size())
	# 点图标能标、再点取消；点名字处不标只选中
	click_icon(shop, row_of.call(g.a))
	check("r1.click.mark", shop.is_marked(g.a) and shop._marks.size() == 1)
	click_icon(shop, row_of.call(g.a))
	check("r1.click.unmark", shop._marks.is_empty())
	click_icon(shop, row_of.call(g.a), 200.0)   # 光标在下一行，点 a 的名字处＝只选中
	check("r1.click.name_selects", shop._marks.is_empty() and shop._sell_index == row_of.call(g.a))
	# 标两件后其中一件变成已培养：金币与确认窗只算能卖的
	click_icon(shop, row_of.call(g.a))
	click_icon(shop, row_of.call(g.b))
	check("r1.two", shop._marks.size() == 2)
	g.b["boostCount"] = 1
	var pa := XItemMarks.selling_price(g.a)
	check("r1.gold_live", shop.marked_gold() == pa, [shop.marked_gold(), pa])
	shop._ok()
	check("r1.confirm_live", shop._mode == "confirm" and shop._marks.size() == 1 and str(shop.multi_rows()[0][0]).contains("1 件")
		and str(shop.multi_rows()[0][0]).contains(XMenu._group(pa)), shop.multi_rows())
	var gold0 := s.gold
	shop._confirm = 1
	shop._ok()
	check("r1.sold_only_a", s.gold == gold0 + pa and not s.gear.has(g.a) and s.gear.has(g.b) and s.gear.has(g.ex), [s.gold - gold0, pa])
	# 越界（P3-2）：列表比可见行多时，点在列表框底部、可见行之外的那一截不标
	for n in shop._list_rows() + 4:
		var e := XGear.create("weapon", 1, s)
		s.register_gear(e)
		s.gear.append(e)
	shop._drop_cache()
	shop._sell_top = 0
	shop._sell_index = 0
	shop._refresh()
	var rows := shop._list_rows()
	var py := XMVWindow.PADDING + rows * XShop.LH + XShop.LH / 2.0
	check("r1.oob.setup", shop._sell_data().size() > rows + 1 and py < XShop.LIST_RECT.size.y, [shop._sell_data().size(), rows, py])
	click_icon(shop, rows)
	check("r1.click.out_of_rows", shop._marks.is_empty() and shop._sell_index == 0, [shop._marks.size(), shop._sell_index])
	shop._cancel()


## 找物品：key＝true 找重要物品，否则找能卖的普通物品；sellable＝false 找卖不了的（价 0 又没别的出售货币）
func find_item(key: bool, sellable := true, skip := []) -> int:
	var tab = XDB.table("Items")
	for r in tab:
		if not (r is Dictionary) or str(r.get("name", "")) == "" or skip.has(int(r.id)):
			continue
		if (int(r.get("itypeId", 1)) == 2) != key:
			continue
		if XItemMarks.can_sell(r) == sellable and XSafeSell.sellable(r) == sellable:
			return int(r.id)
	return 0


func click_list(shop: XShop, row: int, x := 200.0) -> void:
	click_icon(shop, row, x)


## 清单 4：一键出售按类别；清单 5：物品多选；自定义数量
func r1_more(shop: XShop, s: XState) -> void:
	# ---- 一键出售按类别 ----
	s.gear.clear()
	var w := XGear.create("weapon", 1, s)
	var a := XGear.create("armor", 1, s)
	for e in [w, a]:
		s.register_gear(e)
		s.gear.append(e)
	var rows := shop._onekey_rows()
	check("kind.row", str(rows.back().text) == "出售类别：全部" and int(rows.back().grade) == XShop.ONEKEY_KIND_ROW, rows.back())
	shop._mode = "onekey"
	shop._onekey = rows.size() - 1
	shop._ok()
	check("kind.cycle", shop._mode == "onekey" and str(shop._onekey_rows().back().text) == "出售类别：只卖武器", shop._onekey_rows().back())
	var g := XQuality.grade_of(XQuality.legacy(w))
	var p_all := XSafeSell.plan(s, g)
	var p_w := shop._onekey_plan(s, g)
	check("kind.weapon_only", p_w.sell.all(func(e): return str(e.kind) == "weapon") and p_w.keep.all(func(r): return str(r.item.kind) == "weapon")
		and p_w.sell.size() + p_w.keep.size() <= p_all.sell.size() + p_all.keep.size(), [p_w.sell.size(), p_all.sell.size()])
	shop._ok()
	var p_a := shop._onekey_plan(s, XQuality.grade_of(XQuality.legacy(a)))
	check("kind.armor_only", str(shop._onekey_rows().back().text) == "出售类别：只卖护甲" and p_a.sell.all(func(e): return str(e.kind) == "armor"))
	shop._ok()
	check("kind.wrap", str(shop._onekey_rows().back().text) == "出售类别：全部")
	XShop.ONEKEY_KIND = false
	check("kind.off", shop._onekey_rows().size() == rows.size() - 1 and shop._onekey_rows().all(func(r): return int(r.grade) != XShop.ONEKEY_KIND_ROW))
	XShop.ONEKEY_KIND = true
	shop._mode = "command"
	# ---- 物品多选 ----
	var it := find_item(false)
	var it2 := find_item(false, true, [it])
	var key_id := find_item(true)
	var bad := find_item(false, false)
	check("item.found", it > 0 and it2 > 0 and key_id > 0 and bad > 0, [it, it2, key_id, bad])
	for id in s.items.keys():
		s.items.erase(id)
	s.gain_item(it, 20)
	s.gain_item(it2, 5)
	s.gain_item(bad, 3)
	check("item.can", XShop.can_mark_item(XDB.rec("Items", it)) and not XShop.can_mark_item(XDB.rec("Items", bad)) and not XShop.can_mark_item(XDB.rec("Items", key_id)))
	shop._mode = "sell"
	shop._cat = 0
	shop._sell_top = 0
	shop._drop_cache()
	shop._refresh()
	var row_of := func(id: int) -> int:
		var dd := shop._sell_data()
		for i in dd.size():
			if int(dd[i].rec.id) == id:
				return i
		return -1
	shop._sell_index = row_of.call(bad)
	key(shop, XShop.MARK_KEY)
	check("item.bad", shop._item_marks.is_empty())
	click_icon(shop, row_of.call(bad))
	check("item.bad.click", shop._item_marks.is_empty())
	click_icon(shop, row_of.call(it))   # 点图标：弹数量窗，预填全部
	check("item.number", shop._mode == "number" and shop._number_mark and shop._number == 20, [shop._mode, shop._number])
	shop._ok()
	check("item.mark_all", shop._mode == "sell" and int(shop._item_marks.get(it, 0)) == 20, shop._item_marks)
	# 按 C：it2 只选 2 个
	shop._sell_index = row_of.call(it2)
	key(shop, XShop.MARK_KEY)
	check("item.number2", shop._mode == "number" and shop._number == 5)
	shop.jump_number(-1)
	shop._change_number(1)
	check("item.number_hint", shop._number_markable())
	shop._ok()
	check("item.mark_part", shop._mode == "sell" and int(shop._item_marks.get(it2, 0)) == 2, shop._item_marks)
	# 再按 C 取消；数量窗里取消不加入
	shop._sell_index = row_of.call(it2)
	key(shop, XShop.MARK_KEY)
	check("item.unmark", not shop._item_marks.has(it2))
	shop._sell_index = row_of.call(it2)
	key(shop, XShop.MARK_KEY)
	shop._cancel()
	check("item.mark_cancel", shop._mode == "sell" and not shop._item_marks.has(it2) and not shop._number_mark)
	shop._sell_index = row_of.call(it2)
	key(shop, XShop.MARK_KEY)
	key(shop, KEY_2)
	shop._ok()
	check("item.mark_typed", int(shop._item_marks.get(it2, 0)) == 2, shop._item_marks)
	var pi := XItemMarks.selling_price(XDB.rec("Items", it))
	var pi2 := XItemMarks.selling_price(XDB.rec("Items", it2))
	check("item.gold", shop.marked_gold() == pi * 20 + pi2 * 2 and shop.marked_count() == 22, [shop.marked_gold(), shop.marked_count()])
	check("item.rows", str(shop.multi_rows()[0][0]) == "已选物品 22 个，共得 %s 金币" % XMenu._group(pi * 20 + pi2 * 2), shop.multi_rows()[0])
	# 卖之前手上少了：按手上数卖
	s.gain_item(it, -5)
	var gold0 := s.gold
	shop._ok()
	check("item.confirm", shop._mode == "confirm" and shop._confirm_kind == "multi" and int(shop._item_marks.get(it, 0)) == 15, shop._item_marks)
	shop._confirm = 1
	shop._ok()
	check("item.sold", s.item_count(it) == 0 and s.item_count(it2) == 3 and s.item_count(bad) == 3 and s.gold == gold0 + pi * 15 + pi2 * 2
		and shop._item_marks.is_empty(), [s.item_count(it), s.item_count(it2), s.gold - gold0])
	# 退出列表清物品标记
	shop._drop_cache()
	shop._sell_index = row_of.call(it2)
	key(shop, XShop.MARK_KEY)
	shop._ok()
	check("item.remark", not shop._item_marks.is_empty())
	shop._cancel()
	check("item.leave", shop._item_marks.is_empty())
	# 回退：ITEM_MULTI 关时物品列表不能标
	XShop.ITEM_MULTI = false
	shop._mode = "sell"
	shop._cat = 0
	shop._drop_cache()
	shop._sell_index = row_of.call(it2)
	key(shop, XShop.MARK_KEY)
	check("item.off", shop._item_marks.is_empty() and not shop._gear_sell_list())
	XShop.ITEM_MULTI = true
	# ---- 自定义数量 ----
	s.gain_item(it2, 40)   # 共 43
	shop._drop_cache()
	shop._sell_index = row_of.call(it2)
	shop._ok()
	check("num.open", shop._mode == "number" and shop._number == 1)
	key(shop, KEY_1)
	key(shop, KEY_2)
	check("num.type", shop._number == 12, shop._number)
	key(shop, KEY_BACKSPACE)
	check("num.back", shop._number == 1 and shop._num_text == "1", [shop._number, shop._num_text])
	key(shop, KEY_KP_9)
	key(shop, KEY_9)
	check("num.clamp", shop._number == 43 and shop._num_text == "43", [shop._number, shop._num_text])
	key(shop, KEY_RIGHT)
	shop._change_number(-1)
	key(shop, KEY_0)
	check("num.zero", shop._number == 1, shop._number)
	key(shop, KEY_BACKSPACE)
	check("num.empty", shop._number == 1)
	key(shop, KEY_5)
	check("num.restart", shop._number == 5, shop._number)
	# 点数量那一行：弹编辑框（手机数字键盘）
	click_list(shop, 2)
	check("num.editor", shop._mode == "number" and shop._num_edit != null and shop._num_edit.visible
		and shop._num_edit.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER)
	shop._num_edit.text_changed.emit("100")
	check("num.editor.clamp", shop._number == 43 and shop._num_edit.text == "43", [shop._number, shop._num_edit.text])
	shop._num_edit.text_changed.emit("")
	check("num.editor.empty", shop._number == 1)
	shop._num_edit.text_changed.emit("7")
	shop._num_edit.text_submitted.emit("7")
	check("num.editor.close", not shop._num_edit.visible and shop._number == 7)
	var c0 := s.item_count(it2)
	shop._ok()
	check("num.sell", s.item_count(it2) == c0 - 7, [c0, s.item_count(it2)])
	# 回退：NUM_INPUT 关时数字键不改
	XShop.NUM_INPUT = false
	shop._ok()
	key(shop, KEY_5)
	check("num.off", shop._number == 1)
	XShop.NUM_INPUT = true
	shop._cancel()
	shop._cancel()


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
	r1_guards(shop, s)
	r1_more(shop, s)
	var spare := XGear.create("weapon", 1, s)
	s.register_gear(spare)
	s.gear.append(spare)
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
