extends Node
## 玩家反馈 v0.01.09：PC 上按一次键响应多次。键盘、手柄、触屏虚拟键（动作事件）各走一遍。真地图、真按键（按下→几帧→松开），每一下只该让界面走一步：
## 对话一页一页翻、商店光标一格一格挪、选「取消」关店后不再触发 NPC、菜单光标一格、物品页取消只退一层、关菜单不再开。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []
var shop_opens := 0
var menu_opens := 0
var actions := 0


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func until(f: Callable, limit := 600) -> bool:
	for i in limit:
		if f.call():
			return true
		await get_tree().process_frame
	return f.call()


func _key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _pad(button: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## 触屏虚拟键（XTouchControls._send_action：确定／取消／方向都是发动作事件）
func _action(action: String, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func tap_action(action: String) -> void:
	_action(action, true)
	await frames(3)
	_action(action, false)
	await frames(8)


## 按一下：按下停 3 帧再松开，再等 8 帧
func tap(code: int) -> void:
	_key(code, true)
	await frames(3)
	_key(code, false)
	await frames(8)


func tap_pad(button: int) -> void:
	_pad(button, true)
	await frames(3)
	_pad(button, false)
	await frames(8)


func _first(map: XMapScene, cls) -> Node:
	for c in map.ui.get_children():
		if is_instance_of(c, cls) and not c.is_queued_for_deletion():
			return c
	return null


func _st(map: XMapScene) -> Array:
	return [map.busy, map.message._busy, map.message._input_mode, shop_opens, menu_opens]


func _on_ui_child(n: Node) -> void:
	if n is XShop:
		shop_opens += 1
	elif n is XMenu:
		menu_opens += 1


## 对 NPC（大厅 EV004 李老嗨：一句话 → 三选一 → 武器店）一路按确认到开店，然后在店里挪光标、选「取消」
func _shop_flow(map: XMapScene, tag: String, ok: Callable, down: Callable, cancel_any: Callable) -> void:
	await until(func(): return not map.busy and not map._menu_open)
	await frames(5)
	shop_opens = 0
	await ok.call()   # 调查 NPC：出对话
	check("%s_talk_starts" % tag, map.busy and shop_opens == 0, _st(map))
	# 对话打字中按确认先显示全文（原版 Window_Message 的快进），再按一次翻页；按到出选项为止，途中不能已经开店
	var presses := 0
	while map.message._input_mode != "choice" and presses < 4:
		await ok.call()
		presses += 1
		check("%s_talk_step_%d_no_shop" % [tag, presses], shop_opens == 0, _st(map))
	check("%s_choice_shown" % tag, map.message._input_mode == "choice" and map.message._choice_index == 0, _st(map))
	await frames(20)   # 选项窗打开动画（openness）期间不收输入，照原版
	await ok.call()   # 选「购买武器」：开店
	await frames(10)
	var sh := _first(map, XShop) as XShop
	check("%s_shop_opened_once" % tag, sh != null and shop_opens == 1, _st(map))
	if sh == null:
		return
	check("%s_shop_cmd0" % tag, sh._mode == "command" and sh._cmd == 0, [sh._mode, sh._cmd])
	for i in range(3):
		await down.call()
		check("%s_shop_down_%d" % [tag, i + 1], sh._cmd == i + 1, sh._cmd)
	actions = 0
	await ok.call()   # 「取消」关店
	await frames(30)
	check("%s_shop_closed_not_reopened" % tag, _first(map, XShop) == null and shop_opens == 1, shop_opens)
	# 关店那一下确认键不能再调查一次 NPC（之后可能接着弹修行指引等别的文字，不算）
	check("%s_no_retalk" % tag, actions == 0 and shop_opens == 1, _st(map) + [actions])
	# 收拾：万一又触发了对话，按取消一路退出
	for i in range(8):
		if not map.busy:
			break
		await frames(20)
		await cancel_any.call()


func _menu_flow(map: XMapScene, tag: String, ok: Callable, cancel: Callable, down: Callable) -> void:
	await until(func(): return not map.busy and not map._menu_open)
	await frames(5)
	menu_opens = 0
	await cancel.call()   # 开菜单
	await frames(10)
	var m := _first(map, XMenu) as XMenu
	check("%s_menu_opened_once" % tag, m != null and menu_opens == 1, menu_opens)
	if m == null:
		return
	var c0 := m._cmd_index
	await down.call()
	check("%s_menu_down_one" % tag, m._cmd_index == c0 + 1, [c0, m._cmd_index])
	m._cmd_index = 0
	m._refresh()
	await ok.call()   # 物品
	await frames(5)
	var items: Array = m.get_children().filter(func(n): return n is XItemScene)
	check("%s_items_opened" % tag, items.size() == 1, items.size())
	if items.size() == 1:
		var page: XItemScene = items[0]
		await down.call()
		check("%s_item_cat_down_one" % tag, page._cat == 1, page._cat)
		await cancel.call()   # 物品页分类上取消：回菜单（只退一层）
		await frames(5)
		check("%s_items_cancel_one_level" % tag, map._menu_open and is_instance_valid(m) and m.is_inside_tree()
			and m.get_children().filter(func(n): return n is XItemScene and not n.is_queued_for_deletion()).is_empty(), [map._menu_open])
	await cancel.call()   # 关菜单
	await frames(20)
	check("%s_menu_closed_not_reopened" % tag, not map._menu_open and menu_opens == 1, [map._menu_open, menu_opens])


func _run() -> void:
	TestEnv.isolate("xiyou_one_press")
	XMessageBox.auto = false
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 4
	s.x = 8
	s.y = 10
	s.direction = 8
	var map := XMapScene.new()
	add_child(map)
	await until(func(): return map.player != null and not map.busy)
	map.ui.child_entered_tree.connect(_on_ui_child)
	map.player.action_pressed.connect(func(): actions += 1)
	await frames(5)
	map.player.direction = 8
	var kb_ok := func(): await tap(KEY_ENTER)
	var kb_cancel := func(): await tap(KEY_ESCAPE)
	var kb_down := func(): await tap(KEY_DOWN)
	var pad_ok := func(): await tap_pad(JOY_BUTTON_A)
	var pad_cancel := func(): await tap_pad(JOY_BUTTON_B)
	var pad_down := func(): await tap_pad(JOY_BUTTON_DPAD_DOWN)
	var t_ok := func(): await tap_action("ui_accept")
	var t_cancel := func(): await tap_action("ui_cancel")
	var t_down := func(): await tap_action("ui_down")
	await _shop_flow(map, "kb", kb_ok, kb_down, kb_cancel)
	await _shop_flow(map, "pad", pad_ok, pad_down, pad_cancel)
	await _menu_flow(map, "kb", kb_ok, kb_cancel, kb_down)
	await _menu_flow(map, "pad", pad_ok, pad_cancel, pad_down)
	await _shop_flow(map, "touch", t_ok, t_down, t_cancel)
	await _menu_flow(map, "touch", t_ok, t_cancel, t_down)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
