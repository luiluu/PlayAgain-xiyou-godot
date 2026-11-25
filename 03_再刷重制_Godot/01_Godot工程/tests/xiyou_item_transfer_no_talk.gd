extends Node
## T507 玩家反馈：站在传送门／NPC 前打开背包用传送道具（指路灯），先触发了面前的对话，后传送；连点会误进对话里的选项。
## 真地图（大厅 EV004 李老嗨面前）、真按键：物品页选中指路灯按确认使用，菜单关掉回地图跑预约的公共事件。
## 断言：用掉道具的这一下不调查面前的 NPC（不开对话、不开店），直接放光柱传送到目的地；键盘、手柄、触屏虚拟键、鼠标点击各走一遍，
## 另测「连点」（使用后立刻再按几下确认）也不调查 NPC。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const LAMP := 386          # 指路灯:牛马关（CE229：光柱 → 场所移动 67）
const LAMP_MAP := 67
const LOBBY := 4

var results := []
var actions := 0
var shop_opens := 0


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


func _send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	_send(e)


func _pad(button: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	_send(e)


func _action(action: String, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	_send(e)


## 按一下：按下停 hold 帧再松开，再等 after 帧
func kb_ok(hold := 3, after := 8) -> void:
	_key(KEY_ENTER, true)
	await frames(hold)
	_key(KEY_ENTER, false)
	await frames(after)


func pad_ok(hold := 3, after := 8) -> void:
	_pad(JOY_BUTTON_A, true)
	await frames(hold)
	_pad(JOY_BUTTON_A, false)
	await frames(after)


func t_ok(hold := 3, after := 8) -> void:
	_action("ui_accept", true)
	await frames(hold)
	_action("ui_accept", false)
	await frames(after)


## 触屏点一下（ScreenTouch，引擎照常仿出鼠标左键）；pos 是画布坐标
var tap_pos := Vector2.ZERO
func touch_tap(hold := 3, after := 8) -> void:
	var sp: Vector2 = get_viewport().get_screen_transform() * tap_pos
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = sp
	e.pressed = true
	_send(e)
	await frames(hold)
	var r := InputEventScreenTouch.new()
	r.index = 0
	r.position = sp
	r.pressed = false
	_send(r)
	await frames(after)


func _first(map: XMapScene, cls) -> Node:
	for c in map.ui.get_children():
		if is_instance_of(c, cls) and not c.is_queued_for_deletion():
			return c
	return null


func _on_ui_child(n: Node) -> void:
	if n is XShop:
		shop_opens += 1


func _st(map: XMapScene) -> Array:
	return [map.map_id, map.busy, map._menu_open, actions, shop_opens, map.message._busy]


## 回大厅、站到 EV004 面前、背包里放一盏指路灯，打开物品页并把光标停在「使用」上
func _setup(map: XMapScene) -> XItemScene:
	var s := XState.current
	await until(func(): return not map.busy and not map._menu_open)
	if map.map_id != LOBBY:
		await map.load_map(LOBBY, 8, 10, 8)
		await until(func(): return not map.busy)
	map.player.grid = Vector2i(8, 10)
	map.player._sync_position()
	map.player.direction = 8
	s.items[LAMP] = 3
	await frames(5)
	map.open_menu()
	await until(func(): return map._menu_open and _first(map, XMenu) != null)
	await frames(10)
	var m := _first(map, XMenu) as XMenu
	m.run_command("item")
	await frames(5)
	var pages: Array = m.get_children().filter(func(n): return n is XItemScene)
	if pages.is_empty():
		return null
	var page: XItemScene = pages[0]
	page._mode = "list"
	page._index = -1
	for c in XShop.CATEGORIES.size():
		page._cat = c
		var list := page.entries()
		for i in list.size():
			if int(list[i].rec.id) == LAMP:
				page._index = i
		if page._index >= 0:
			break
	page._ok()   # 列表 → 操作窗
	page._act = 0
	for i in page._actions.size():
		if str(page._actions[i].symbol) == "use":
			page._act = i
	page._refresh()
	await frames(5)
	# 旧物品页（西游档不开新皮肤）操作窗里「使用」那一行的中心
	tap_pos = page.get_global_transform_with_canvas() * (XItemScene.LIST_RECT.position + Vector2(XMVWindow.PADDING + 60, XMVWindow.PADDING + (page._act + 0.5) * XItemScene.LH))
	return page


func _flow(map: XMapScene, tag: String, ok: Callable, mash: int) -> void:
	var page := await _setup(map)
	check("%s_item_page" % tag, page != null and page._mode == "action", _st(map))
	if page == null:
		return
	actions = 0
	shop_opens = 0
	await ok.call(3, 0)   # 使用：物品页与菜单关掉，回地图跑 CE229
	for i in mash:        # 连点：使用后紧接着又按确认
		await ok.call(2, 2)
	var arrived := await until(func(): return map.map_id == LAMP_MAP and not map.busy, 900)
	check("%s_transferred" % tag, arrived, _st(map))
	check("%s_no_npc_action" % tag, actions == 0, _st(map))
	check("%s_no_shop" % tag, shop_opens == 0, _st(map))
	await frames(10)
	# 收拾：若误开对话，按取消退出
	for i in 10:
		if not map.busy:
			break
		_key(KEY_ESCAPE, true)
		await frames(3)
		_key(KEY_ESCAPE, false)
		await frames(20)


## 对照：道具没用之前，站在 NPC 面前按确认照常调查（修法不能把正常对话也吃掉）
func _talk_still_works(map: XMapScene) -> void:
	await until(func(): return not map.busy and not map._menu_open)
	await map.load_map(LOBBY, 8, 10, 8)
	await until(func(): return not map.busy)
	map.player.direction = 8
	await frames(30)
	actions = 0
	await kb_ok()
	check("talk_after_transfer_still_works", actions == 1 and map.busy, _st(map))
	for i in 10:
		if not map.busy:
			break
		_key(KEY_ESCAPE, true)
		await frames(3)
		_key(KEY_ESCAPE, false)
		await frames(20)


func _run() -> void:
	TestEnv.isolate("xiyou_item_transfer_no_talk")
	XMessageBox.auto = false
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = LOBBY
	s.x = 8
	s.y = 10
	s.direction = 8
	var map := XMapScene.new()
	add_child(map)
	await until(func(): return map.player != null and not map.busy)
	map.ui.child_entered_tree.connect(_on_ui_child)
	map.player.action_pressed.connect(func(): actions += 1)
	await frames(5)
	await _flow(map, "kb", kb_ok, 0)
	await _flow(map, "pad", pad_ok, 0)
	await _flow(map, "touch", t_ok, 0)
	await _flow(map, "kb_mash", kb_ok, 6)
	await _flow(map, "touch_mash", t_ok, 6)
	await _flow(map, "tap", touch_tap, 0)
	await _flow(map, "tap_mash", touch_tap, 6)
	await _talk_still_works(map)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
