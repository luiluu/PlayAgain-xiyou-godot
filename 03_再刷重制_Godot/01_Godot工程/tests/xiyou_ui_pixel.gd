extends Node
## 界面逐页像素／矩形对照（白龙 ui-pixel1）：与 03_转换工具/ui_reference/review_system_pages.js 的 px_menu／px_item／px_equip／
## px_status／px_shop 取同一状态（新局 1/8/9/10、物品页另给 732 ×3、商店另给 50000 金、货品 [物品 732, 武器 1, 防具 4375]），
## 带 --out=<目录>（非 headless）时每态存 <名>.png 与 <名>.json（场景里所有可见 XMVWindow／XHelpCard 的全局矩形、开合），
## 再用 ui_reference/ui_pixel_compare.py 逐个比矩形、出像素差热图。headless 时只走状态断言。
## 矩形断言（下方 RECTS）是 v0.62.12 原版实跑读数里与本页一一对应的窗口。

const Dump := preload("res://tests/ui_pixel_dump.gd")

var results := []
var out_dir := ""
var s: XState


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


static func grect(w: Control) -> Array:
	var r := w.get_global_rect()
	return [r.position.x, r.position.y, r.size.x, r.size.y]


func shot(name: String, page: Node) -> Array:
	for i in 20:
		await get_tree().physics_frame
	await frames(2)
	var wins: Array = Dump.collect(page)
	if out_dir != "" and DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
		var f := FileAccess.open(out_dir.path_join(name + ".json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"shot": name, "windows": wins}, "  "))
	return wins


## 原版读数里能一一对应的窗口：[名, 窗口, 原版矩形]
func expect(tag: String, pairs: Array) -> void:
	for p in pairs:
		var w: Control = p[1]
		check("%s_%s" % [tag, p[0]], w != null and w.is_visible_in_tree() and Rect2(w.position, w.size) == Rect2(p[2][0], p[2][1], p[2][2], p[2][3]),
			[p[2], grect(w) if w != null else null])


func _fresh() -> void:
	XState.current = XState.new_game(3, 1, [8, 9, 10])
	s = XState.current


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_ui_pixel"
	XConfig._loaded_path = "<unloaded>"
	await _menu()
	await _item()
	await _equip()
	await _status()
	await _shop()
	await _round_wh_up()
	finish()


## YEP_CoreEngine Window._roundWhUp：窗口宽高向上取整（制作完成弹窗原版 297，算出来是 296.24）
func _round_wh_up() -> void:
	var holder := Control.new()
	add_child(holder)
	var w := XMVWindow.make(holder, Rect2(505.88, 328, 296.24, 64.5))
	await frames(1)
	check("round_wh_up", w.size == Vector2(297, 65) and is_equal_approx(w.position.x, 505.88) and w.canvas.size == Vector2(269, 37), [w.size, w.canvas.size])
	w.size = Vector2(240.00001, 64)
	check("round_wh_up_float_noise", w.size == Vector2(240, 64), w.size)
	w.queue_free()
	XMVWindow.ROUND_WH_UP = false
	var w2 := XMVWindow.make(holder, Rect2(0, 0, 296.24, 64))
	await frames(1)
	check("round_wh_up_rollback", is_equal_approx(w2.size.x, 296.24), w2.size)
	holder.queue_free()
	XMVWindow.ROUND_WH_UP = true


func _menu() -> void:
	_fresh()
	var m := XMenu.new()
	add_child(m)
	await frames(3)
	await shot("px_menu_0_command", m)
	expect("menu_0", [["cmd", m.cmd_win, [0, 0, 240, 568]], ["gold", m.gold_win, [0, 656, 240, 64]], ["status", m.status_win, [240, 0, 1040, 720]]])
	m._cmd_index = XMenu.COMMANDS.map(func(c): return c[1]).find("skill")
	m._ok()
	await frames(2)
	check("menu_1_actor_mode", m._mode == "actor", m._mode)
	await shot("px_menu_1_party", m)
	m.queue_free()
	await frames(2)


func _item() -> void:
	_fresh()
	s.gain_item(732, 3)
	var p := XItemScene.new()
	add_child(p)
	await frames(3)
	await shot("px_item_0_category", p)
	expect("item_0", [["cat", p.cat_win, [0, 0, 240, 172]], ["status", p.status_win, [240, 1, 1040, 172]],
		["list", p.list_win, [0, 172, 640, 548]], ["info", p.info_win, [640, 172, 640, 548]]])
	p._cat = 0
	p._ok()
	await frames(3)
	check("item_1_list_mode", p._mode == "list", p._mode)
	await shot("px_item_1_list", p)
	# 原版 Sprite_ItemHelp 本体 (660,236)：O-008 贴行放（x 654），但不盖信息窗首行（O-待定 NEAR_BELOW_HEADER，本体 y 236）
	check("item_1_help_card", p.help_card.is_visible_in_tree() and p.help_card.position == Vector2(654, 236), p.help_card.position)
	XHelpCard.NEAR_BELOW_HEADER = false
	p._update_help()
	check("item_1_help_card_rollback", p.help_card.position == Vector2(654, 186), p.help_card.position)
	XHelpCard.NEAR_BELOW_HEADER = true
	p._update_help()
	p.queue_free()
	await frames(2)


func _equip() -> void:
	_fresh()
	var e := XEquipScene.new()
	add_child(e)
	await frames(3)
	await shot("px_equip_0_command", e)
	expect("equip_0", [["cmd", e.cmd_win, [0, 1, 240, 172]], ["status", e.status_win, [240, 1, 1040, 172]], ["list", e.list_win, [0, 173, 640, 547]]])
	e._cmd = 0
	e._ok()
	await frames(2)
	check("equip_1_slot_mode", e._mode == "slot", e._mode)
	await shot("px_equip_1_slot", e)
	e._ok()
	await frames(2)
	check("equip_2_item_mode", e._mode == "item", e._mode)
	await shot("px_equip_2_list", e)
	e.queue_free()
	await frames(2)


func _status() -> void:
	_fresh()
	var st := XStatusPage.new()
	add_child(st)
	await frames(3)
	await shot("px_status_0", st)
	expect("status_0", [["select", st.select_win, [0, 0, 1280, 64]]])
	# 参数窗：战力先藏时 (0,72,1280,648)；开战力时让出战力条，与原版 JAH_Window_Status_Params (0,108,1280,612) 同
	expect("status_0_hidden_power", [["page", st.page_win, [0, 72, 1280, 648]]])
	st.queue_free()
	await frames(2)
	var was := XPower.SHOW_POWER_UI
	XPower.SHOW_POWER_UI = true
	if check("status_0_power_on_enabled", XPower.ui_enabled()):
		var st2 := XStatusPage.new()
		add_child(st2)
		await frames(3)
		expect("status_0_power_on", [["page", st2.page_win, [0, 108, 1280, 612]]])
		st2.queue_free()
		await frames(2)
	XPower.SHOW_POWER_UI = was


func _shop() -> void:
	_fresh()
	s.gain_gold(50000)
	var sh := XShop.new()
	sh.setup([[0, 732, 0, 0], [1, 1, 0, 0], [2, 4375, 0, 0]], false)
	add_child(sh)
	await frames(3)
	await shot("px_shop_0_command", sh)
	expect("shop_0", [["cmd", sh.cmd_win, [0, 1, 240, 172]], ["info", sh.info_win, [240, 1, 1040, 172]], ["list", sh.list_win, [0, 173, 768, 547]],
		["status", sh.status_win, [768, 173, 512, 483]], ["gold", sh.gold_win, [768, 656, 512, 64]]])
	sh._cmd = 0
	sh._ok()
	await frames(3)
	check("shop_1_buy_mode", sh._mode == "buy", sh._mode)
	await shot("px_shop_1_buy", sh)
	# 原版本体 (788,237)：不盖状态窗「持有数」（O-待定 NEAR_BELOW_HEADER）
	check("shop_1_help_card", sh.help_card.is_visible_in_tree() and sh.help_card.position == Vector2(782, 237), sh.help_card.position)
	XHelpCard.NEAR_BELOW_HEADER = false
	sh._update_help()
	check("shop_1_help_card_rollback", sh.help_card.position == Vector2(782, 187), sh.help_card.position)
	XHelpCard.NEAR_BELOW_HEADER = true
	sh._update_help()
	sh._cancel()
	await frames(2)
	sh._cmd = 1
	sh._ok()
	await frames(2)
	check("shop_2_category_mode", sh._mode == "category", sh._mode)
	await shot("px_shop_2_sell_category", sh)
	sh.queue_free()
	await frames(2)


func finish() -> void:
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
