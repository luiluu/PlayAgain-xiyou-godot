extends Node
## 商店装备状态窗「默认」模式（platform-shop1，YEP_ShopMenuCore Window_ShopStatus）：Tab 切换、←→ 换属性、Shift 翻队员页、
## 队员行画法（名字 x+220、属性增减 20 号右对齐涨绿降红、装不了写 Can't Equip）。
## 夹具来自插件源码推出的坐标（行高 36、第 2 行属性名、第 3 行起队员），不是正式版运行时读数；回退开关 XShop.STAT_DEFAULT_MODE。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


class RecCanvas extends XMVCanvas:
	var log := []

	func text(t: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, zoom := 1.0, pivot := Vector2.ZERO, outline := OUTLINE) -> void:
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


func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func _run() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.gold = 10000000
	var shop := XShop.new()
	shop.setup([[1, 1, 0, 0], [0, 1, 0, 0]], false, "")  # 武器 1、物品 1
	add_child(shop)
	for _i in range(3):
		await get_tree().process_frame
	shop._mode = "buy"
	shop._buy_index = 0
	shop._refresh()
	var sw: float = shop.status_win.canvas.size.x
	# 开店默认队员模式
	var log := await _paint(shop._paint_status, sw)
	check("starts_actor_mode", not shop._stat_default and log.any(func(e): return e[0] == "<<" and absf(e[2] - 36) < 0.5))
	# Tab 切到默认模式：第 2 行属性名居中（初始 paramId 2＝攻击）、<< >>
	shop._unhandled_input(key(KEY_TAB))
	check("tab_toggles_default", shop._stat_default)
	log = await _paint(shop._paint_status, sw)
	var pname := XItemStatusPainter.param_name(2)
	var e := log.filter(func(x): return x[0] == pname and absf(x[2] - 36) < 0.5 and x[4] == "center")
	check("param_name_line", not e.is_empty(), log)
	# 队员行：名字在 226、第 3 行起每 36 一行；装得了写增减（20 号右对齐，右缘 sw-6）
	var members := s.members()
	var item := XGear.template("weapon", 1)
	var rows_ok := true
	var detail := []
	for i in range(mini(4, members.size())):
		var y := 72.0 + i * 36
		var nm := log.filter(func(x): return x[0] == members[i].display_name() and absf(x[2] - y) < 0.5 and absf(x[1] - 226) < 0.5)
		if nm.is_empty():
			rows_ok = false
			detail.append([i, "no name"])
			continue
		var can: bool = members[i].can_equip(item)
		var tail := log.filter(func(x): return absf(x[2] - y) < 0.5 and x[4] == "right" and x[5] == 20)
		if tail.is_empty():
			rows_ok = false
			detail.append([i, "no tail"])
			continue
		if can:
			var want := int(item.params[2]) - XShop._worst_equipped_param(members[i], int(item.etypeId), 2)
			var txt := ("+" if want > 0 else "") + XMenu._group(want)
			if tail[0][0] != txt or absf(tail[0][1] + tail[0][3] - (sw - 6)) > 0.5:
				rows_ok = false
				detail.append([i, tail[0], txt])
		elif tail[0][0] != "Can't Equip" or absf(tail[0][7] - XUI.DIM.a) > 0.01:
			rows_ok = false
			detail.append([i, tail[0]])
	check("member_rows", rows_ok, detail)
	# ←→ 换属性（8 项轮换）
	var p0: int = shop._param_id
	shop._unhandled_input(key(KEY_RIGHT))
	check("right_next_param", shop._param_id == (p0 + 1) % 8)
	for _i in range(7):
		shop._unhandled_input(key(KEY_RIGHT))
	check("param_wraps", shop._param_id == p0)
	shop._unhandled_input(key(KEY_LEFT))
	check("left_prev_param_wrap", shop._param_id == (p0 + 7) % 8)
	# 物品不能切
	shop._unhandled_input(key(KEY_TAB))
	check("tab_back_to_actor", not shop._stat_default)
	shop._buy_index = 1
	shop._refresh()
	shop._unhandled_input(key(KEY_TAB))
	check("tab_ignored_on_item", not shop._stat_default)
	# 回退开关
	shop._buy_index = 0
	XShop.STAT_DEFAULT_MODE = false
	shop._unhandled_input(key(KEY_TAB))
	check("rollback_no_toggle", not shop._stat_default)
	XShop.STAT_DEFAULT_MODE = true
	# Shift 翻页只在队员多于 4 人时
	var before: int = shop._page_index
	shop._unhandled_input(key(KEY_SHIFT))
	check("shift_no_page_when_le4", shop._page_index == before or s.members().size() > 4)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
