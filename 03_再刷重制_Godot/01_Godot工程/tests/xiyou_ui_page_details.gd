extends Node
## 零散界面页面细节（ui14）：照冻结 v0.28 的 rpg_windows.js／rpg_scenes.js 与插件，核对几页原来缺的系统音和技能遗忘窗的外观。
## - 商店（Scene_Shop＋YEP_ShopMenuCore＋Star_ShopOnekey）：换行光标音、确定音、不可选蜂鸣、取消音；数量窗确定只响商店音（21），
##   数量变了才响光标音，数量窗取消响两次取消音；装备商品左右换队员响光标音、物品不响。
## - 物品页（Scene_Item）：分类、列表换行、翻页、点别的行响光标音；光标没动（到头按住）不响。
## - 结束游戏（Scene_GameEnd）：换行光标音、确定、取消。
## - 技能遗忘（Star_Window_ForgetSkill）：宽 400、高 fittingHeight(min(项数,12))、正中；名字左、状态右（x＝内容宽−12−120、宽 120）；
##   确定无声、翻转状态；按住确定连续翻转；空列表确定不动作；取消音后关闭；Q／E 翻页、滚轮。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 2) -> void:
	for _i in range(n):
		await get_tree().process_frame


static func act(name: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e


static func key(code: Key, echo := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	e.echo = echo
	return e


static func click(p: Vector2, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = p
	return e


## 跑一段动作，返回这段里响过的系统音编号
func sounds(f: Callable) -> Array:
	XSound.system_log.clear()
	f.call()
	return XSound.system_log.duplicate()


class TextCanvas extends XMVCanvas:
	var texts := []

	func text(s: String, x: float, y: float, max_w: float, align := "left", _color := XUI.TEXT, _size := XUI.FONT_SIZE, _lh := XUI.LINE_HEIGHT, _alpha := 1.0, _zoom := 1.0, _pivot := Vector2.ZERO, _outline := OUTLINE) -> void:
		texts.append([s, x, y, max_w, align])

	func icon(_index: int, _x: float, _y: float, _alpha := 1.0, _size := 32.0) -> void:
		pass

	func cursor(_r: Rect2, _active := true) -> void:
		pass


func _run() -> void:
	await _shop()
	await _item_page()
	await _game_end()
	await _forget()
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _shop() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.gold = 99999999
	# 一件买得起的物品、一件买不起的（指定价 10 亿）、一件武器
	var item_id := 0
	for id in range(1, 200):
		var r := XDB.rec("Items", id)
		if not r.is_empty() and int(r.get("price", 0)) > 0 and str(r.get("name", "")) != "" and XItemMarks.can_buy(s, r, int(r.price)):
			item_id = id
			break
	var weapon_id := 0
	for id in range(1, 400):
		var r := XDB.rec("Weapons", id)
		if not r.is_empty() and int(r.get("price", 0)) > 0 and str(r.get("name", "")) != "" and XItemMarks.can_buy(s, r, int(r.price)):
			weapon_id = id
			break
	check("shop_goods_found", item_id > 0 and weapon_id > 0, [item_id, weapon_id])
	var shop := XShop.new()
	shop.setup([[0, item_id, 0, 0], [0, item_id, 1, 1000000000], [1, weapon_id, 0, 0]], false)
	add_child(shop)
	await frames(3)
	check("shop_cmd_down_cursor", sounds(func(): shop._unhandled_input(act("ui_down"))) == [0], XSound.system_log)
	check("shop_cmd_up_cursor", sounds(func(): shop._unhandled_input(act("ui_up"))) == [0])
	check("shop_cmd_buy_ok", sounds(func(): shop._unhandled_input(act("ui_accept"))) == [1] and shop._mode == "buy")
	check("shop_buy_down_cursor", sounds(func(): shop._unhandled_input(act("ui_down"))) == [0] and shop._buy_index == 1)
	check("shop_buy_disabled_buzzer", sounds(func(): shop._unhandled_input(act("ui_accept"))) == [3] and shop._mode == "buy", [XSound.system_log, shop._mode])
	shop._unhandled_input(act("ui_up"))
	# 物品：左右换队员不响（YEP 只对装备 updateParamSwitch）
	check("shop_item_actor_silent", sounds(func(): shop._unhandled_input(act("ui_right"))) == [])
	check("shop_buy_ok", sounds(func(): shop._unhandled_input(act("ui_accept"))) == [1] and shop._mode == "number")
	check("shop_number_change_cursor", sounds(func(): shop._unhandled_input(act("ui_right"))) == [0] and shop._number == 2)
	check("shop_number_floor_silent", sounds(func(): shop._change_number(-10)) == [0] and sounds(func(): shop._change_number(-1)) == [], shop._number)
	var gold := s.gold
	check("shop_number_ok_shop_se", sounds(func(): shop._unhandled_input(act("ui_accept"))) == [21] and shop._mode == "buy" and s.gold < gold, [XSound.system_log, shop._mode])
	shop._unhandled_input(act("ui_accept"))
	check("shop_number_cancel_twice", sounds(func(): shop._unhandled_input(act("ui_cancel"))) == [2, 2] and shop._mode == "buy", XSound.system_log)
	# 装备：左右换队员响光标音
	shop._buy_index = 2
	check("shop_gear_actor_cursor", sounds(func(): shop._unhandled_input(act("ui_right"))) == [0])
	# 鼠标：点别的行光标音，点选中行＝确定
	var row0 := shop.LIST_RECT.position + Vector2(XMVWindow.PADDING + 10, XMVWindow.PADDING + 5)
	check("shop_click_other_row_cursor", sounds(func(): shop._gui_input(click(row0))) == [0] and shop._buy_index == 0, shop._buy_index)
	check("shop_click_same_row_ok", sounds(func(): shop._gui_input(click(row0))) == [1] and shop._mode == "number")
	check("shop_right_click_cancel", sounds(func(): shop._gui_input(click(row0, MOUSE_BUTTON_RIGHT))) == [2, 2])
	check("shop_buy_cancel", sounds(func(): shop._unhandled_input(act("ui_cancel"))) == [2] and shop._mode == "command")
	shop.queue_free()
	# 只买不卖的店：出售是灰的，确定蜂鸣
	var only := XShop.new()
	only.setup([[0, item_id, 0, 0]], true)
	add_child(only)
	await frames(2)
	only._cmd = 1
	check("shop_sell_disabled_buzzer", sounds(func(): only._unhandled_input(act("ui_accept"))) == [3] and only._mode == "command")
	only.queue_free()
	await frames()


func _item_page() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	for id in range(1, 60):
		var r := XDB.rec("Items", id)
		if not r.is_empty() and str(r.get("name", "")) != "" and int(r.get("itypeId", 0)) == 1:
			s.gain_item(id, 1)
	var page := XItemScene.new()
	add_child(page)
	await frames(3)
	page._mode = "category"
	page._cat = 0
	page._refresh()
	check("item_cat_down_cursor", sounds(func(): page._unhandled_input(act("ui_down"))) == [0] and page._cat == 1, page._cat)
	page._cat = 0
	page._mode = "category"
	page._ok()
	var n := page.entries().size()
	check("item_list_ready", page._mode == "list" and n >= 2, [page._mode, n])
	page._index = 0
	check("item_list_down_cursor", sounds(func(): page._unhandled_input(act("ui_down"))) == [0] and page._index == 1)
	page._index = n - 1
	page._top = XMenu._scroll_to(page._index, page._top, page._rows())
	# 末项按住下（echo，不回绕）：光标没动，不响
	check("item_list_end_held_silent", sounds(func(): page._move(1, false)) == [] and page._index == n - 1)
	page._index = 0
	page._top = 0
	var r := XMenu.page(0, 0, n, page._rows(), 1)
	check("item_list_page_cursor", sounds(func(): page._page(1)) == ([0] if r[1] != 0 else []), [r, page._index])
	page._index = 0
	page._top = 0
	page._refresh()
	var row1 := XItemScene.LIST_RECT.position + Vector2(XMVWindow.PADDING + 10, XMVWindow.PADDING + XItemScene.LH + 5)
	check("item_click_other_row_cursor", sounds(func(): page._gui_input(click(row1))) == [0] and page._index == 1, page._index)
	check("item_click_same_row_no_cursor", not sounds(func(): page._gui_input(click(row1))).has(0), XSound.system_log)
	page.queue_free()
	await frames()


func _game_end() -> void:
	var p := XGameEndPanel.new()
	add_child(p)
	await frames(2)
	var titled := [false]
	var closed := [false]
	p.to_title.connect(func(): titled[0] = true)
	p.closed.connect(func(): closed[0] = true)
	check("game_end_down_cursor", sounds(func(): p._unhandled_input(act("ui_down"))) == [0])
	check("game_end_ok", sounds(func(): p._unhandled_input(act("ui_accept"))) == [1] and closed[0] and not titled[0])
	closed[0] = false
	check("game_end_cancel", sounds(func(): p._unhandled_input(act("ui_cancel"))) == [2] and closed[0])
	var row0 := XGameEndPanel.RECT.position + Vector2(XMVWindow.PADDING + 10, XMVWindow.PADDING + 5)
	check("game_end_click_cursor", sounds(func(): p._gui_input(click(row0))) == [0] and p._index == 0)
	check("game_end_click_ok", sounds(func(): p._gui_input(click(row0))) == [1] and titled[0])
	p.queue_free()
	await frames()


func _forget() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var a := s.actor(8)
	var ids := []
	for id in range(1, 3000):
		var r := XDB.rec("Skills", id)
		if not r.is_empty() and str(r.get("name", "")) != "" and int(r.get("stypeId", 0)) in XForgetSkillScene.TYPES:
			ids.append(id)
			if ids.size() >= 20:
				break
	for id in ids:
		if not a.skill_ids.has(id):
			a.learn_skill(id)
	var listed := XForgetSkillScene.listed_skills(a)
	check("forget_listed", listed.size() >= 14, listed.size())
	check("forget_rect_full", XForgetSkillScene.window_rect(listed.size()) == Rect2(440, (720 - (12 * 36 + XMVWindow.PADDING * 2)) / 2.0, 400, 12 * 36 + XMVWindow.PADDING * 2))
	check("forget_rect_three", XForgetSkillScene.window_rect(3) == Rect2(440, (720 - (3 * 36 + XMVWindow.PADDING * 2)) / 2.0, 400, 3 * 36 + XMVWindow.PADDING * 2))
	check("forget_rect_empty", XForgetSkillScene.window_rect(0).size.y == XMVWindow.PADDING * 2)
	var f := XForgetSkillScene.new().setup(a)
	add_child(f)
	await frames(2)
	check("forget_window_placed", Rect2(f.win.position, f.win.size) == XForgetSkillScene.window_rect(listed.size()), [f.win.position, f.win.size])
	var c := TextCanvas.new()
	c.size = f.win.canvas.size
	f._paint(c)
	var cw := 400.0 - XMVWindow.PADDING * 2
	var first_id: int = listed[0]
	check("forget_paint_name", c.texts.size() >= 2 and c.texts[0] == [str(XDB.rec("Skills", first_id).name), 6.0, 0.0, cw - 12 - 120, "left"], c.texts.slice(0, 2))
	check("forget_paint_status", c.texts.size() >= 2 and c.texts[1] == ["未遗忘", cw - 12 - 120, 0.0, 120.0, "right"], c.texts.slice(0, 2))
	c.free()
	check("forget_ok_silent_toggle", sounds(func(): f._unhandled_input(act("ui_accept"))) == [] and not f.rows[0].kept and not a.skill_ids.has(first_id))
	# 按住确定（isRepeated）继续翻转
	var held := InputEventKey.new()
	held.physical_keycode = KEY_ENTER
	held.keycode = KEY_ENTER
	held.pressed = true
	held.echo = true
	f._unhandled_input(held)
	check("forget_held_ok_toggles", f.rows[0].kept and a.skill_ids.has(first_id), f.rows[0].kept)
	check("forget_down_cursor", sounds(func(): f._unhandled_input(act("ui_down"))) == [0] and f.index == 1)
	f.index = 0
	f.top = 0
	f._unhandled_input(key(KEY_E))
	check("forget_page_down", f.index == mini(12, listed.size() - 1) and f.top == mini(12, listed.size() - 12), [f.index, f.top])
	f.index = 0
	f.top = 0
	var wheel := click(f.win.position + Vector2(50, 50), MOUSE_BUTTON_WHEEL_DOWN)
	f._gui_input(wheel)
	check("forget_wheel", f.top == 1 and f.index == 0, [f.top, f.index])
	f.top = 0
	f._refresh()
	var row1 := f.win.position + Vector2(XMVWindow.PADDING + 10, XMVWindow.PADDING + 36 + 5)
	check("forget_click_row_cursor", sounds(func(): f._gui_input(click(row1))) == [0] and f.index == 1)
	var closed := [false]
	f.closed.connect(func(): closed[0] = true)
	check("forget_cancel", sounds(func(): f._unhandled_input(act("ui_cancel"))) == [2] and closed[0])
	f.queue_free()
	# 空列表：确定不动作
	var b := s.actor(9)
	for id in XForgetSkillScene.listed_skills(b):
		b.forget_skill(id)
	var e := XForgetSkillScene.new().setup(b)
	add_child(e)
	await frames(2)
	check("forget_empty_rect", e.win.size == Vector2(400, XMVWindow.PADDING * 2), e.win.size)
	check("forget_empty_ok_nothing", sounds(func(): e._unhandled_input(act("ui_accept"))) == [] and e.rows.is_empty())
	e.queue_free()
	await frames()
