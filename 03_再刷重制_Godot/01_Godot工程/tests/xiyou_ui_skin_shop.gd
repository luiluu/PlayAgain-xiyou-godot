extends Node
## 【cc·T283·未经审查】新界面卡 I：通用小件（数量选择 XSkinStepper、统一确认弹窗 XSkinConfirm、页内页签 XSkinInnerTabs、面包屑 XSkinCrumb、
## 小标／空列表 XSkinTag、XSkinList 新行键 tags／check／empty_center）＋商店新布局 XSkinShopPage。
## - 小件：各自的接口（夹值、键、默认光标、点击、省略）；
## - 商店：T254 3.1 对应表逐行断言「旧页显示的每一项新页都取得到」；数量选择的焦点规则（列表上上下只换行、不改数量；确定落到数量条；
##   ←/→ ±1、↑/↓ ±10、E 最多、Q 回 1；再确定成交；取消回列表、数量复位）；一键出售接 XSafeSell.plan、保留确认；出售 C 多选；
##   只买不卖、收物品的店、买不起、拿满了、售完、空列表；触屏：列表态点数量钮、点主按钮。
## - 回退：XSkinShopPage.ENABLED＝false、西游存档、XUiSkin.ENABLED＝false 都不建新页（旧页逐像素不变由 皮肤关闭对照.py 核）。
## 带 -- --out=<目录> 且有窗口时截图：每页 16:9（800×450）＋20:9（1000×450）、各状态、字体 130%、旧画法对照。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []
var out_dir := ""
var closed_count := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(600))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func shot(name: String, sz := Vector2i(800, 450)) -> void:
	if not windowed():
		return
	var win := get_window()
	var old := win.size
	win.size = sz
	await frames(12)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	if img.get_size() != sz:
		img.resize(sz.x, sz.y, Image.INTERPOLATE_LANCZOS)
	check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK, img.get_size())
	win.size = old
	await frames(4)


## 16:9（800×450）＋20:9（1000×450）
func shots(name: String) -> void:
	if not windowed():
		return
	await shot(name + "_16x9", Vector2i(800, 450))
	await shot(name + "_20x9", Vector2i(1000, 450))


func act(shop: XShop, action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	shop._unhandled_input(e)


func key(shop: XShop, k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	shop._unhandled_input(e)


func _state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.flags["tianqi"] = {"rules": 1}
	s.gold = 50000
	return s


func open_shop(goods: Array, only := false, group := "") -> XShop:
	var shop := XShop.new()
	shop.setup(goods, only, group)
	shop.closed.connect(func(): closed_count += 1)
	add_child(shop)
	return shop


## 有金币价的武器、护甲、物品各找几个（按 ID 从小到大）
func priced(table: String, n: int, extra := Callable()) -> Array:
	var out := []
	for r in XDB.table(table):
		if r is Dictionary and int(r.get("price", 0)) > 0 and str(r.get("name", "")) != "" and (not extra.is_valid() or extra.call(r)):
			out.append(int(r.id))
			if out.size() >= n:
				break
	return out


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_shop")
	get_viewport().gui_disable_input = windowed()   # 有窗口截图时真鼠标停在环上会悬停选球；本测试全靠直接调函数，不吃真输入
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XFontScale.set_value("global", 100)
	_widgets()
	await _gates()
	await _buy()
	await _sell()
	await _onekey()
	await _special_shops()
	await _touch()
	await _font_and_old()
	await _review_fixes()
	XUiSkin.motion_override = -1
	XFontScale.set_value("global", 100)
	XState.current = null
	for pl in XSound._players:   # 系统音还在放会在退出时报「resources still in use」（同 xiyou_ui_skin_5c）
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 通用小件 ----
func _widgets() -> void:
	# 数量选择
	var st := XSkinStepper.new()
	st.sound = false
	st.size = Vector2(304, XSkinStepper.H)
	var got := []
	st.value_changed.connect(func(v): got.append(v))
	st.set_range(1, 25, 1)
	check("stepper.range_no_signal", got.is_empty() and st.value == 1)
	var ev := InputEventAction.new()
	ev.pressed = true
	for pair in [["ui_right", 2], ["ui_up", 12], ["ui_down", 2], ["ui_left", 1], ["ui_left", 1]]:
		ev.action = pair[0]
		st.handle_input(ev)
		check("stepper.key_%s_%d" % [pair[0], pair[1]], st.value == int(pair[1]), st.value)
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_E
	e.physical_keycode = KEY_E
	st.handle_input(e)
	check("stepper.E_max", st.value == 25, st.value)
	e.keycode = KEY_Q
	e.physical_keycode = KEY_Q
	st.handle_input(e)
	check("stepper.Q_min", st.value == 1, st.value)
	st.type_digit(9)
	st.type_digit(9)
	check("stepper.digits_clamp", st.value == 25, st.value)
	st.type_digit(-1)
	st.type_digit(-1)
	check("stepper.backspace_to_min", st.value == 1, st.value)
	check("stepper.signal_only_on_change", got == [2, 12, 2, 1, 25, 1, 9, 25, 2, 1], got)
	check("stepper.layout_fits", st.button_rect(4).end.x <= st.size.x + 0.5 and st.number_rect().size.x >= 24.0, [st.button_rect(4), st.number_rect()])
	ev.action = "ui_accept"
	check("stepper.accept_not_eaten", not st.handle_input(ev))
	st.free()
	# 确认弹窗：危险停「取消」，普通停第一枚；左右换；确定发 chosen
	var dlg := XSkinConfirm.new()
	dlg.setup({"title": "卖掉这一档？", "body": "会卖掉 3 件", "buttons": ["确认出售", "取消"], "danger": true})
	check("confirm.danger_default_cancel", dlg.index == 1 and dlg.danger)
	dlg.setup({"title": "确定？", "buttons": ["确定", "取消"]})
	check("confirm.normal_default_first", dlg.index == 0 and not dlg.danger)
	var chosen := []
	dlg.chosen.connect(func(i): chosen.append(i))
	var cancels := [0]
	dlg.cancelled.connect(func(): cancels[0] += 1)
	ev.action = "ui_right"
	dlg.handle_input(ev)
	ev.action = "ui_accept"
	dlg.handle_input(ev)
	ev.action = "ui_cancel"
	dlg.handle_input(ev)
	check("confirm.keys", chosen == [1] and cancels[0] == 1, [chosen, cancels])
	dlg.setup({"title": "x", "buttons": [{"text": "出售已选", "disabled": true}, "清空选择", "取消"], "danger": true})
	check("confirm.three_buttons", dlg.buttons.size() == 3 and dlg.index == 2 and dlg.is_disabled(0))
	dlg.free()
	# 页内页签：Q／E 循环
	var tb := XSkinInnerTabs.new()
	tb.set_tabs(["物品", "消耗品", "武器"], 0)
	var ch := []
	tb.changed.connect(func(i): ch.append(i))
	e.keycode = KEY_E
	e.physical_keycode = KEY_E
	tb.handle_input(e)
	e.keycode = KEY_Q
	e.physical_keycode = KEY_Q
	tb.handle_input(e)
	tb.handle_input(e)
	check("tabs.qe_wrap", ch == [1, 0, 2], ch)
	tb.free()
	# 面包屑：放不下时前面换「…」，最后一段完整
	check("crumb.fit_full", XSkinCrumb.fit_parts(["画面", "画质设置"], 1000.0) == ["画面", "画质设置"])
	var fit := XSkinCrumb.fit_parts(["很长的第一层名字", "很长的第二层名字", "画质设置"], XSkinCrumb.width_of(["…", "画质设置"]) + 2.0)
	check("crumb.fit_ellipsis", fit == ["…", "画质设置"], fit)
	# 小标
	check("tag.colors", XSkinTag.color_for("新") == XUiSkin.GOLD and XSkinTag.color_for("出战 1") == XUiSkin.GOLD and XSkinTag.color_for("已锁定") == XUiSkin.TEXT_2)
	check("tag.size", XSkinTag.height() >= 22.0 and XSkinTag.width("新") > 15.0)
	# 列表新行键：不给就和以前一样（默认关）
	var l := XSkinList.new()
	check("list.new_keys_default_off", not l.check_column and not l.empty_center)
	l.free()


# ---- 开关与门控 ----
func _gates() -> void:
	var s := _state()
	var g := [[1, priced("Weapons", 1)[0], 0, 0]]
	check("gate.skin_on_tianqi", XUiSkin.on())
	var shop := open_shop(g)
	await frames(2)
	check("gate.tianqi_builds_page", shop.skin != null and shop.skin.visible)
	check("gate.old_windows_hidden", not shop.cmd_win.visible and not shop.list_win.visible and not shop.status_win.visible and not shop.gold_win.visible and not shop.help_card.visible)
	shop.queue_free()
	XSkinShopPage.ENABLED = false
	shop = open_shop(g)
	await frames(2)
	check("gate.rollback_switch_old_page", shop.skin == null and shop.cmd_win.visible and shop.list_win.visible)
	shop.queue_free()
	XSkinShopPage.ENABLED = true
	s.flags.erase("tianqi")
	shop = open_shop(g)
	await frames(2)
	check("gate.xiyou_save_old_page", shop.skin == null and shop.cmd_win.visible)
	shop.queue_free()
	s.flags["tianqi"] = {"rules": 1}
	XUiSkin.ENABLED = false
	shop = open_shop(g)
	await frames(2)
	check("gate.skin_master_off_old_page", shop.skin == null)
	shop.queue_free()
	XUiSkin.ENABLED = true
	await frames(2)


# ---- 购买 ----
func _buy() -> void:
	var s := _state()
	var w := priced("Weapons", 3)
	var a := priced("Armors", 2)
	var it := priced("Items", 3, func(r): return int(r.get("itypeId", 1)) == 1 and int(r.get("price", 0)) < 2000 and not XItemMarks.sell_rewards(r).buy)
	var goods := []
	for id in w:
		goods.append([1, id, 0, 0])
	for id in a:
		goods.append([2, id, 0, 0])
	for id in it:
		goods.append([0, id, 0, 0])
	goods.append([1, w[0], 1, 999999])   # 买不起（指定价）
	var shop := open_shop(goods)
	await frames(3)
	var pg := shop.skin
	# 对应表：指令窗 → 环上三个球
	check("buy.ring_three", pg.ring.items.map(func(x): return x.key) == ["buy", "sell", "onekey"], pg.ring.items)
	check("buy.ring_focus_first", pg.focus == "ring" and shop._mode == "command")
	await shots("shop_buy_ring")
	act(shop, "ui_down")
	check("buy.ring_move", shop._cmd == 1 and pg.ring.index == 1 and pg.inner_tabs.visible)
	act(shop, "ui_up")
	check("buy.ring_back", shop._cmd == 0 and not pg.inner_tabs.visible)
	act(shop, "ui_accept")
	check("buy.enter_list", shop._mode == "buy" and pg.focus == "list")
	# 列表行：名字、品质色、价格、买不起变橙
	var d := shop._buy_data()
	check("buy.rows_count", pg.list.items.size() == d.size(), [pg.list.items.size(), d.size()])
	var ok_rows := true
	for i in d.size():
		var row: Dictionary = pg.list.items[i]
		if row.text != XQuality.list_name(d[i].rec) or row.color != XGear.color(d[i].rec):
			ok_rows = false
	check("buy.rows_name_color", ok_rows)
	check("buy.row_price", pg.list.items[0].right == XSkinTemplatePage._group(int(d[0].price)), [pg.list.items[0].right, d[0].price])
	var last: Dictionary = pg.list.items[d.size() - 1]
	check("buy.unaffordable_orange", last.right_color == XUiSkin.DOWN and not last.get("disabled", false), last)
	check("buy.list_title_right", pg._list_right.begins_with("买得起"), pg._list_right)
	# 右牌：名字、持有、装备「换上后」、数量条、合计、主按钮
	check("buy.card_title", pg.card.title == XQuality.list_name(d[0].rec).strip_edges(), pg.card.title)
	check("buy.card_owned", str(pg.card.subtitle).contains("持有 "), pg.card.subtitle)
	var sec_titles: Array = pg.card.sections.map(func(x): return str(x.get("title", "")))
	var actor_name: String = s.members()[0].display_name()
	check("buy.card_equip_section", sec_titles.any(func(t): return t.begins_with("换上后") and t.contains(actor_name)), sec_titles)
	check("buy.stepper_visible", pg.stepper.visible and pg.stepper.value == 1 and not pg.stepper.focused)
	check("buy.foot_total", pg._foot_lines.size() == 1 and pg._foot_lines[0][0] == "合计")
	check("buy.button", pg.card.buttons.size() == 1 and pg.card.buttons[0].text == "购买")
	check("buy.currency", pg.currency_pairs() == [["精魂", "50,000"]], pg.currency_pairs())
	await shots("shop_buy")
	# 左右换人（旧页 << 队员 >>）
	act(shop, "ui_right")
	var actor2: String = s.members()[1].display_name()
	check("buy.switch_actor", shop._actor_index == 1 and pg.card.sections.any(func(x): return str(x.get("title", "")).contains(actor2)))
	# Tab：旧页「默认」看法（一项属性 × 全队）也取得到
	key(shop, KEY_TAB)
	check("buy.tab_default_mode", shop._stat_default and pg.card.sections.any(func(x): return str(x.get("title", "")).contains(XItemStatusPainter.param_name(shop._param_id))))
	key(shop, KEY_TAB)
	# 焦点规则：列表上上下只换行、不改数量
	act(shop, "ui_down")
	check("buy.list_down_moves_row", shop._buy_index == 1 and shop._mode == "buy" and pg.stepper.value == 1)
	act(shop, "ui_up")
	check("buy.list_up_moves_row", shop._buy_index == 0 and pg.stepper.value == 1)
	# 物品行：右牌没有「换上后」
	shop._buy_index = w.size() + a.size()
	shop._refresh()
	check("buy.item_card_no_equip", not pg.card.sections.any(func(x): return str(x.get("title", "")).begins_with("换上后")))
	var price := int(shop._buy_data()[shop._buy_index].price)
	# 确定落到数量条
	act(shop, "ui_accept")
	check("buy.accept_to_stepper", shop._mode == "number" and pg.focus == "stepper" and pg.stepper.focused and pg.list.active, [shop._mode, pg.focus])
	act(shop, "ui_right")
	check("buy.right_plus1", shop._number == 2 and pg.stepper.value == 2, shop._number)
	act(shop, "ui_up")
	check("buy.up_plus10", shop._number == 12, shop._number)
	act(shop, "ui_down")
	check("buy.down_minus10", shop._number == 2, shop._number)
	key(shop, KEY_E)
	check("buy.E_max", shop._number == shop._max_number() and pg.stepper.value == shop._number, [shop._number, shop._max_number()])
	key(shop, KEY_Q)
	check("buy.Q_one", shop._number == 1)
	act(shop, "ui_right")
	act(shop, "ui_right")
	check("buy.total_follows", pg._foot_lines[0][1] == XSkinTemplatePage._group(price * 3), pg._foot_lines)
	await shots("shop_buy_stepper")
	act(shop, "ui_cancel")
	check("buy.cancel_back_reset", shop._mode == "buy" and pg.focus == "list" and pg.stepper.value == 1)
	act(shop, "ui_accept")
	act(shop, "ui_right")
	var gold0 := s.gold
	var n0 := s.item_count(int(shop._buy_data()[shop._buy_index].gid))
	act(shop, "ui_accept")
	check("buy.trade", s.gold == gold0 - price * 2 and s.item_count(int(shop._buy_data()[shop._buy_index].gid)) == n0 + 2 and shop._mode == "buy", [gold0, s.gold, price])
	# 买不起：主按钮「精魂不够」、数量条禁用
	shop._buy_index = d.size() - 1
	shop._refresh()
	check("buy.short_button", pg.card.buttons[0].text == "精魂不够" and pg.card.buttons[0].disabled and not pg.stepper.enabled, pg.card.buttons)
	await shots("shop_state_cannot_afford")
	# 拿满了
	shop._buy_index = w.size() + a.size()
	s.gain_item(int(shop._buy_data()[shop._buy_index].gid), 9999)
	shop._refresh()
	check("buy.full_bag", pg.list.items[shop._buy_index].get("disabled", false) and pg.card.buttons[0].text == "拿满了", pg.card.buttons)
	await shots("shop_state_bag_full")
	act(shop, "ui_cancel")
	check("buy.cancel_to_ring", shop._mode == "command" and pg.focus == "ring")
	var c0 := closed_count
	act(shop, "ui_cancel")
	check("buy.cancel_ring_closes", closed_count == c0 + 1)
	shop.queue_free()
	await frames(2)


# ---- 出售（页签、小标、多选、数量） ----
func _sell() -> void:
	var s := _state()
	var w := priced("Weapons", 4)
	var it := priced("Items", 2, func(r): return int(r.get("itypeId", 1)) == 1 and bool(r.get("consumable", false)))
	var gear := []
	for id in w:
		var e := XGear.create("weapon", id, s)
		s.register_gear(e)
		s.gear.append(e)
		gear.append(e)
	gear[1].name = str(gear[1].name) + XItemMarks.LOCK
	gear[2].name = "一把名字特别特别特别特别特别特别长的练习用木剑"
	s.gain_item(it[0], 7)
	var shop := open_shop([[1, w[0], 0, 0]])
	await frames(3)
	var pg := shop.skin
	act(shop, "ui_down")
	act(shop, "ui_accept")
	check("sell.enter_direct", shop._mode == "sell" and pg.inner_tabs.visible, shop._mode)
	check("sell.tabs_are_categories", pg.inner_tabs.tabs == XShop.CATEGORIES.map(func(c): return c[0]))
	# 页签 Q／E 换分类（不经分类窗）
	shop._cat = 0
	shop._refresh()
	key(shop, KEY_E)
	key(shop, KEY_E)
	check("sell.tab_E", shop._cat == 2 and pg.inner_tabs.index == 2 and shop._mode == "sell", shop._cat)
	await shots("shop_sell_empty_mark")
	var d := shop._sell_data()
	var row_of := func(e) -> int:
		for i in d.size():
			if is_same(d[i].rec, e):
				return i
		return -1
	var lr: Dictionary = pg.list.items[row_of.call(gear[1])]
	check("sell.locked_row", lr.get("tags", []).has("已锁定") and lr.right == "不能卖" and lr.disabled and not lr.has("check"), lr)
	check("sell.locked_name_clean", not str(lr.text).contains(XItemMarks.LOCK), lr.text)
	var r0: Dictionary = pg.list.items[row_of.call(gear[0])]
	check("sell.row_price_and_carry", r0.right == XSkinTemplatePage._group(XItemMarks.selling_price(gear[0])) and str(r0.sub) == XItemRow.right_text(d[row_of.call(gear[0])]), r0)
	check("sell.check_column", pg.list.check_column and r0.get("check", -1) == 0)
	# 锁定的选中按确定：原话提示、留在列表
	shop._sell_index = row_of.call(gear[1])
	shop._refresh()
	act(shop, "ui_accept")
	check("sell.locked_stays", shop._mode == "sell")
	# C 多选：标两件，光标下移，标题右、主按钮、提示跟着
	shop._sell_index = row_of.call(gear[0])
	shop._refresh()
	key(shop, XShop.MARK_KEY)
	check("sell.mark_moves_down", shop.is_marked(gear[0]) and shop._sell_index == row_of.call(gear[0]) + 1)
	shop._sell_index = row_of.call(gear[3])
	shop._refresh()
	key(shop, XShop.MARK_KEY)
	check("sell.marked_rows", pg.list.items[row_of.call(gear[0])].check == 1 and pg.list.items[row_of.call(gear[3])].check == 1)
	check("sell.title_right", pg._list_right.begins_with("已选 ") and pg._list_right.contains(XSkinTemplatePage._group(shop.marked_gold())), pg._list_right)
	shop._sell_index = row_of.call(gear[0])
	shop._refresh()
	check("sell.button_multi", pg.card.buttons[0].text == "出售已选 2 件", pg.card.buttons)
	check("sell.hint_c", pg.hint_list.any(func(h): return h[0] == "C"), pg.hint_list)
	await shots("shop_sell")
	# 确定 → 统一确认弹窗（橙边、停在「取消」，三个选项照旧）
	act(shop, "ui_accept")
	check("sell.confirm_dialog", shop._mode == "confirm" and pg.dialog != null and pg.dialog.danger and pg.dialog.index == 2 and shop._confirm == 3)
	check("sell.confirm_buttons", pg.dialog.buttons.map(func(b): return b.text) == ["出售已选", "清空选择", "取消"], pg.dialog.buttons)
	check("sell.confirm_text_jinghun", pg.dialog.title == "出售已选物品？" and pg.dialog.body.contains("精魂") and not pg.dialog.body.contains("金币"), [pg.dialog.title, pg.dialog.body])
	await shots("shop_state_multi_confirm")
	act(shop, "ui_left")
	act(shop, "ui_left")
	check("sell.confirm_move", shop._confirm == 1 and pg.dialog.index == 0, shop._confirm)
	var gold0 := s.gold
	var want := shop.marked_gold()
	act(shop, "ui_accept")
	check("sell.confirm_sold", shop._mode == "sell" and s.gold == gold0 + want and not s.gear.has(gear[0]) and not s.gear.has(gear[3]) and pg.dialog == null, [s.gold - gold0, want])
	# 能叠的物品：出数量；装备：不出数量
	shop._cat = 1
	shop._drop_cache()
	shop._sell_index = maxi(0, shop._sell_data().find_custom(func(x): return int(x.rec.get("id", 0)) == it[0]))
	shop._refresh()
	check("sell.stack_stepper", pg.stepper.visible and pg.stepper.max_value == 7 and pg.stepper.value == 1 and pg.card.buttons[0].text == "出售", [pg.stepper.visible, pg.stepper.max_value])
	act(shop, "ui_accept")
	check("sell.stack_number", shop._mode == "number" and pg.stepper.visible and pg.stepper.max_value == 7, [shop._mode, pg.stepper.max_value])
	check("sell.number_tabs_quiet", not pg.inner_tabs.focused and not pg.inner_tabs.is_processing_input() and pg.list.quiet, [pg.inner_tabs.focused, pg.list.quiet])
	await shots("shop_state_sell_stack")
	act(shop, "ui_cancel")
	shop._cat = 2
	shop._sell_index = 0
	shop._drop_cache()
	shop._refresh()
	check("sell.gear_no_stepper", not pg.stepper.visible)
	await shots("shop_state_long_name")
	# 空分类：中间一句、右牌不画（新局带的重要物品先拿掉）
	for k in s.items.keys():
		if int(XDB.rec("Items", int(k)).get("itypeId", 1)) == 2:
			s.items.erase(k)
	shop._cat = 4
	shop._sell_index = 0
	shop._drop_cache()
	shop._refresh()
	check("sell.empty", pg.list.items.is_empty() and pg.list.empty_text == XSkinShopPage.T_EMPTY_SELL and not pg.card.visible)
	await shots("shop_state_empty")
	# 取消回环（清标记）
	act(shop, "ui_cancel")
	check("sell.cancel_to_ring", shop._mode == "command" and shop._cmd == 1)
	shop.queue_free()
	await frames(2)


# ---- 一键出售（XSafeSell.plan、确认保留） ----
func _onekey() -> void:
	var s := _state()
	var w := priced("Weapons", 3)
	for id in w:
		var e := XGear.create("weapon", id, s)
		s.register_gear(e)
		s.gear.append(e)
	s.gear[0].name = str(s.gear[0].name) + XItemMarks.LOCK
	var shop := open_shop([[1, w[0], 0, 0]])
	await frames(3)
	var pg := shop.skin
	act(shop, "ui_up")
	check("onekey.ring", shop._cmd == 2)
	act(shop, "ui_accept")
	check("onekey.mode", shop._mode == "onekey" and pg.focus == "list")
	var rows := shop._onekey_rows()
	check("onekey.rows", pg.list.items.size() == rows.size() and pg.list.items.map(func(r): return r.text) == rows.map(func(r): return str(r.text)))
	# 选普通那一档（第一件武器的品质档）
	var g := XQuality.grade_of(XQuality.legacy(s.gear[1]))
	var gi := -1
	for i in rows.size():
		if int(rows[i].grade) == g:
			gi = i
	shop._onekey = maxi(gi, 0)
	shop._refresh()
	var p := shop._onekey_plan(s, int(rows[shop._onekey].grade))
	var row: Dictionary = pg.list.items[shop._onekey]
	check("onekey.row_count", (p.sell as Array).is_empty() or row.right == "%d 件" % (p.sell as Array).size(), [row, p.sell.size()])
	var secs: Array = pg.card.sections
	check("onekey.card_plan", secs.size() >= 1 and secs[0].title == "会卖掉" and secs[0].lines[0].right == str((p.sell as Array).size()), secs)
	check("onekey.card_keep", (p.keep as Array).is_empty() or secs.any(func(x): return str(x.title) == "自动留住 %d 件" % (p.keep as Array).size()), secs)
	check("onekey.button", pg.card.buttons[0].text == "卖掉这一档…")
	await shots("shop_onekey")
	if not (p.sell as Array).is_empty():
		act(shop, "ui_accept")
		check("onekey.confirm", shop._mode == "confirm" and pg.dialog != null and pg.dialog.danger and pg.dialog.index == 1 and shop._confirm == 3)
		check("onekey.confirm_buttons", pg.dialog.buttons.map(func(b): return b.text) == ["确认出售", "取消"])
		await shots("shop_state_onekey_confirm")
		act(shop, "ui_cancel")
		check("onekey.cancel_keeps", shop._mode == "onekey" and s.gear.size() == 3)
		act(shop, "ui_accept")
		act(shop, "ui_left")
		check("onekey.confirm_left", shop._confirm == 2 and pg.dialog.index == 0)
		var n := (p.sell as Array).size()
		act(shop, "ui_accept")
		check("onekey.sold", shop._mode == "command" and s.gear.size() == 3 - n, [s.gear.size(), n])
	# 保留词条行：确定换一档
	shop._mode = "onekey"
	shop._onekey = 0
	shop._refresh()
	if int(shop._onekey_rows()[0].grade) == -1:
		var before := XSafeSell.label(s)
		act(shop, "ui_accept")
		check("onekey.cycle_threshold", XSafeSell.label(s) != before and pg.card.title == "保留词条")
	shop.queue_free()
	await frames(2)


# ---- 只买不卖、收物品的店、库存 ----
func _special_shops() -> void:
	var s := _state()
	var w := priced("Weapons", 2)
	var shop := open_shop([[1, w[0], 0, 0], [1, w[1], 0, 0]], true)
	await frames(3)
	var pg := shop.skin
	check("only.no_ring", not pg.show_ring and not pg.ring.visible and shop._mode == "buy" and pg.focus == "list")
	await shots("shop_state_purchase_only")
	var c0 := closed_count
	act(shop, "ui_cancel")
	check("only.cancel_closes", closed_count == c0 + 1)
	shop.queue_free()
	await frames(2)
	# 收物品的店：右上货币跟着商品换、价格写计价物
	var alt := 0
	for r in XDB.table("Items"):
		if r is Dictionary and str(r.get("name", "")) != "" and not (XItemMarks.sell_rewards(r).buy_items as Dictionary).is_empty() and int(r.get("price", 0)) == 0:
			alt = int(r.id)
			break
	if check("alt.found", alt > 0):
		shop = open_shop([[0, alt, 0, 0], [1, w[0], 0, 0]])
		await frames(3)
		pg = shop.skin
		act(shop, "ui_accept")
		var bi: Dictionary = XItemMarks.sell_rewards(XDB.rec("Items", alt)).buy_items
		var cname := str(XDB.rec("Items", int(bi.keys()[0])).get("name", ""))
		check("alt.currency_follows", pg.currency_pairs().any(func(x): return x[0] == cname) and not pg.currency_pairs().any(func(x): return x[0] == "精魂"), pg.currency_pairs())
		check("alt.price_unit", str(pg.list.items[0].right).contains(cname), pg.list.items[0])
		check("alt.short_button", pg.card.buttons[0].text == cname + "不够", pg.card.buttons)
		await shots("shop_state_item_currency")
		act(shop, "ui_down")
		check("alt.currency_back_gold", pg.currency_pairs().any(func(x): return x[0] == "精魂"))
		shop.queue_free()
		await frames(2)
	# 库存：名字后「库存 剩余 / 上限」，售完整行变灰写「售完」
	var managed := 0
	for r in XDB.table("Items"):
		if r is Dictionary and int(r.get("price", 0)) > 0 and XShopStock.shop_managed(0, int(r.id)) and not XItemMarks.sell_rewards(r).buy:
			managed = int(r.id)
			break
	if managed > 0:
		shop = open_shop([[0, managed, 0, 0]], false, "t283")
		await frames(3)
		pg = shop.skin
		act(shop, "ui_accept")
		var mx := XShopStock.stock_max(0, managed)
		check("stock.sub", str(pg.list.items[0].get("sub", "")) == "%s %d / %d" % [XShop.STOCK_CAPTION, XShopStock.remaining(s, "t283", 0, managed), mx], pg.list.items[0])
		XShopStock.record_purchase(s, "t283", 0, managed, mx)
		shop._drop_cache()
		shop._refresh()
		check("stock.sold_out", pg.list.items[0].right == XShop.SOLD_OUT and pg.list.items[0].disabled, pg.list.items[0])
		shop.queue_free()
		await frames(2)
	else:
		check("stock.managed_found", false)
	# 没货的店
	shop = open_shop([])
	await frames(3)
	act(shop, "ui_accept")
	check("empty.buy", shop.skin.list.items.is_empty() and shop.skin.list.empty_text == XSkinShopPage.T_EMPTY_BUY and not shop.skin.card.visible)
	shop.queue_free()
	await frames(2)


# ---- 触屏：列表态点数量钮、点主按钮 ----
func _touch() -> void:
	var s := _state()
	var it := priced("Items", 1, func(r): return int(r.get("itypeId", 1)) == 1 and int(r.get("price", 0)) < 1000)
	var shop := open_shop([[0, it[0], 0, 0]])
	await frames(3)
	var pg := shop.skin
	act(shop, "ui_accept")
	var price := int(shop._buy_data()[0].price)
	# 点「＋10」：先落到数量条，再改数
	var r := pg.stepper.button_rect(3)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = r.get_center()
	pg.stepper._gui_input(mb)
	mb.pressed = false
	pg.stepper._gui_input(mb)
	check("touch.stepper_from_list", shop._mode == "number" and shop._number == 11, [shop._mode, shop._number])
	var gold0 := s.gold
	pg._on_card_button(0)
	check("touch.button_trade", s.gold == gold0 - price * 11 and shop._mode == "buy", [gold0 - s.gold, price])
	# 列表态直接点主按钮：买 1 个
	gold0 = s.gold
	pg._on_card_button(0)
	check("touch.button_from_list_one", s.gold == gold0 - price)
	shop.queue_free()
	await frames(2)


# ---- 字体 130%、旧画法对照 ----
func _font_and_old() -> void:
	var s := _state()
	var w := priced("Weapons", 3)
	var goods := w.map(func(id): return [1, id, 0, 0])
	XFontScale.set_value("global", 130)
	var shop := open_shop(goods)
	await frames(3)
	act(shop, "ui_accept")
	check("font130.mult", XUiSkin.font_mult() >= 1.29)
	await shots("shop_font130")
	shop.queue_free()
	XFontScale.set_value("global", 100)
	await frames(2)
	XSkinShopPage.ENABLED = false
	shop = open_shop(goods)
	await frames(3)
	act(shop, "ui_accept")
	check("old.page", shop.skin == null and shop.list_win.visible)
	await shots("shop_old_compare")
	shop.queue_free()
	XSkinShopPage.ENABLED = true
	await frames(2)
	var _u = s


# ---- 小A 核 T283 的 P2 修正 ----
func _review_fixes() -> void:
	var s := _state()
	var it := priced("Items", 1, func(r): return int(r.get("itypeId", 1)) == 1 and int(r.get("price", 0)) < 1000 and bool(r.get("consumable", false)) and not XItemMarks.sell_rewards(r).buy)
	var shop := open_shop([[0, it[0], 0, 0]])
	await frames(3)
	var pg := shop.skin
	# P2-2：环上点列表里亮着的第 1 行（XSkinList 发 activated）＝进列表
	check("fix.p2_2_command_row0", shop._mode == "command" and pg.list.index == 0)
	pg._on_list_click(0)
	check("fix.p2_2_enter", shop._mode == "buy" and shop._buy_index == 0, shop._mode)
	# P2-1：数量态开了手输框，离开数量态就收起
	act(shop, "ui_accept")
	pg.stepper.open_editor()
	check("fix.p2_1_editor_open", pg.stepper.editing())
	act(shop, "ui_cancel")
	check("fix.p2_1_editor_closed", shop._mode == "buy" and not pg.stepper.editing())
	shop.queue_free()
	await frames(2)
	# P2-4：禁用时停掉按住连加、收起手输框；手输删空回下限
	var st := XSkinStepper.new()
	st.sound = false
	add_child(st)
	st.size = Vector2(304, XSkinStepper.H)
	st.set_range(1, 50, 5)
	st._hold = 2
	st.open_editor()
	st.enabled = false
	check("fix.p2_4_disable_stops", st._hold == -1 and st._press == -1 and not st.editing())
	st.enabled = true
	st.open_editor()
	st._edit.text = "12"
	st._edit.text_changed.emit("12")
	st._edit.text = ""
	st._edit.text_changed.emit("")
	check("fix.p2_4_empty_to_min", st.value == 1, st.value)
	st.queue_free()
	# P2-5：弹窗吃掉右键
	var host := Control.new()
	add_child(host)
	var dlg := XSkinConfirm.open(host, {"title": "x", "buttons": ["确定", "取消"]})
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_RIGHT
	mb.pressed = true
	dlg._gui_input(mb)
	check("fix.p2_5_right_click_no_choice", dlg.index == 0)
	host.queue_free()
	# W-4：勾了能叠的物品时主按钮写「项」
	s.gain_item(it[0], 5)
	shop = open_shop([[0, it[0], 0, 0]])
	await frames(3)
	pg = shop.skin
	shop._item_marks[it[0]] = 3
	shop._mode = "sell"
	shop._cat = 1
	shop._drop_cache()
	shop._sell_index = maxi(0, shop._sell_data().find_custom(func(x): return int(x.rec.get("id", 0)) == it[0]))
	shop._refresh()
	check("fix.w4_items_xiang", pg.card.buttons[0].text == "出售已选 1 项", pg.card.buttons)
	shop.queue_free()
	await frames(2)
