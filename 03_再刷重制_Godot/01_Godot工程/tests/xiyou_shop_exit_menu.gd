extends Node
## 玩家反馈 v0.01.09①：随便开一个商店，退出商店后又自动打开了菜单（物品页）。
## 地图事件开店（302）→ 按取消键关店：键盘 Esc、手柄 B、触屏／鼠标右键各走一遍，关店之后地图不应再开菜单。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []


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


func _shop(map: XMapScene) -> XShop:
	for c in map.ui.get_children():
		if c is XShop and not c.is_queued_for_deletion():
			return c
	return null


func _menu(map: XMapScene) -> XMenu:
	for c in map.ui.get_children():
		if c is XMenu:
			return c
	return null


func _event(map: XMapScene, id: int) -> MVEvent:
	for e in map.events:
		if e.event_id == id:
			return e
	return null


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


func _mouse_right(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = down
	e.position = get_viewport().get_final_transform() * Vector2(640, 360)
	e.global_position = e.position
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## 同地图事件开店：解释器跑着（busy）→ 302 开店 → 关店后事件结束、放开 busy（XMapScene.run_event 的收尾）
func _shop_event(map: XMapScene) -> void:
	map._set_busy(true)
	await map.open_shop([[0, 1, 0, 0], [0, 2, 0, 0]], false)
	map._set_busy(false)


## 开店，用 press 关店，再等一阵看菜单有没有被带出来
func _case(map: XMapScene, name: String, press: Callable, release: Callable) -> void:
	await until(func(): return not map.busy and not map._menu_open)
	_shop_event(map)
	var opened := await until(func(): return _shop(map) != null)
	check("%s_shop_opened" % name, opened)
	if not opened:
		return
	await frames(3)
	press.call()
	await frames(3)
	release.call()
	await frames(20)
	check("%s_shop_closed" % name, _shop(map) == null)
	check("%s_no_menu_after_shop" % name, not map._menu_open and _menu(map) == null, [map._menu_open, _menu(map) != null])
	# 收拾：万一菜单被带出来就关掉，免得影响下一项
	var m := _menu(map)
	if m != null:
		m.closed.emit()
		await frames(5)


func _run() -> void:
	TestEnv.isolate("xiyou_shop_exit_menu")
	XMessageBox.auto = true
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 4
	s.x = 4
	s.y = 20
	var map := XMapScene.new()
	add_child(map)
	await until(func(): return map.player != null and not map.busy)
	await frames(3)
	await _case(map, "esc", func(): _key(KEY_ESCAPE, true), func(): _key(KEY_ESCAPE, false))
	await _case(map, "pad_b", func(): _pad(JOY_BUTTON_B, true), func(): _pad(JOY_BUTTON_B, false))
	await _case(map, "right_click", func(): _mouse_right(true), func(): _mouse_right(false))
	# 关店后正常按 Esc 仍能开菜单（不能把菜单键整个挡掉）
	await until(func(): return not map.busy)
	await frames(5)
	_key(KEY_ESCAPE, true)
	await frames(3)
	_key(KEY_ESCAPE, false)
	var menu_ok := await until(func(): return map._menu_open, 120)
	check("esc_opens_menu_later", menu_ok)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
