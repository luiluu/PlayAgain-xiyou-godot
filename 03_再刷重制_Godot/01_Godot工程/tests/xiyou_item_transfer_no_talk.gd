extends Node
## T507 玩家反馈：站在传送门／NPC 前打开背包用传送道具，先触发了面前的对话，后传送；连点会误进深渊（取消了传送）。
## 真地图、真按键：大厅两处——EV004 李老嗨（NPC）面前、EV075 时空漩涡（深渊入口）面前；物品页选中指路灯:牛马关（CE229：光柱 → 场所移动）按确认使用。
## 每处先确认「站这儿按确认会调查到它」（不然断言没意义），再用道具：
## 键盘、手柄、触屏虚拟确定键（动作事件）、真触屏点旧物品页「使用」、按住久一点在菜单关掉后才抬手、新界面物品页点牌上「使用」，
## 以及使用后紧接着连点确认／连点屏幕。断言：直接传到牛马关，面前的 NPC／漩涡一次都没被调查、没开店。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const LAMP := 386          # 指路灯:牛马关（CE229：光柱 → 场所移动 67）
const LAMP_MAP := 67
const LOBBY := 4
const SPOTS := {"npc": Vector2i(8, 10), "rift": Vector2i(14, 20)}   # 都朝上：李老嗨 (8,9)、时空漩涡 (14,19)

var results := []
var actions := 0
var shop_opens := 0
var tap_pos := Vector2.ZERO
var watch: XMapScene = null
## 地图事件真的跑起来了几次（running_event_id 从 0 变成非 0；回城、指路灯是公共事件，不算在内）
var ev_runs := 0
var _last_ev := 0


func _process(_dt: float) -> void:
	if watch == null:
		return
	var ev := watch.running_event_id
	if ev != 0 and ev != _last_ev:
		ev_runs += 1
	_last_ev = ev


func _ready() -> void:
	_run.call_deferred()


var mute := false   # 验旧行为时预期的失败不打印（运行器见 FAIL 行即判失败）


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok and not mute:
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


func _touch(down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = get_viewport().get_screen_transform() * tap_pos
	e.pressed = down
	_send(e)


## 各种「按一下」：按下停 hold 帧再松开，再等 after 帧
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


## 真触屏点一下（ScreenTouch，引擎照常仿出鼠标左键）；落点 tap_pos（画布坐标）
func touch_tap(hold := 3, after := 8) -> void:
	_touch(true)
	await frames(hold)
	_touch(false)
	await frames(after)


## 按住 30 帧才抬手：菜单关掉、回地图后才松开
func touch_long(_hold := 3, after := 8) -> void:
	await touch_tap(30, after)


func _first(map: XMapScene, cls) -> Node:
	for c in map.ui.get_children():
		if is_instance_of(c, cls) and not c.is_queued_for_deletion():
			return c
	return null


## 换图会换一个玩家节点：每次都把「调查」计数挂到当前玩家上
func _count_on(map: XMapScene) -> void:
	if not map.player.action_pressed.is_connected(_on_action):
		map.player.action_pressed.connect(_on_action)


func _on_action() -> void:
	actions += 1


func _on_ui_child(n: Node) -> void:
	if n is XShop:
		shop_opens += 1


func _st(map: XMapScene) -> Array:
	return [map.map_id, map.player.grid, map.busy, map._menu_open, actions, ev_runs, shop_opens, map.message._busy]


func _clear(map: XMapScene) -> void:
	for i in 12:
		if not map.busy and not map._menu_open:
			return
		_key(KEY_ESCAPE, true)
		await frames(3)
		_key(KEY_ESCAPE, false)
		await frames(20)


func _stand(map: XMapScene, spot: Vector2i) -> void:
	await _clear(map)
	await until(func(): return not map.busy and not map._menu_open)
	await map.load_map(LOBBY, spot.x, spot.y, 8)
	await until(func(): return not map.busy)
	map.player.direction = 8
	# 进图后可能接着弹提示（新档引导、播报等）：退掉，等连续 40 帧都空闲
	var calm := 0
	for i in 600:
		if map.busy or map._menu_open:
			calm = 0
			await _clear(map)
		else:
			calm += 1
			if calm >= 40:
				break
		await frames(1)
	map.player.direction = 8
	_count_on(map)


## 站好、背包放指路灯、打开物品页。旧物品页停在操作窗「使用」上，tap_pos 是那一行；新界面停在列表选中指路灯，tap_pos 是牌上「使用」钮
func _setup(map: XMapScene, spot: Vector2i) -> XItemScene:
	await _stand(map, spot)
	XState.current.items[LAMP] = 3
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
	if page.skin != null:
		page._refresh()
		await frames(5)
		var card := page.skin.card
		tap_pos = card.get_global_transform_with_canvas() * card.button_rect(0).get_center()
		return page
	page._ok()   # 列表 → 操作窗
	page._act = 0
	for i in page._actions.size():
		if str(page._actions[i].symbol) == "use":
			page._act = i
	page._refresh()
	await frames(5)
	tap_pos = page.get_global_transform_with_canvas() * (XItemScene.LIST_RECT.position + Vector2(XMVWindow.PADDING + 60, XMVWindow.PADDING + (page._act + 0.5) * XItemScene.LH))
	return page


## 站这儿按确认确实会调查到面前的事件
func _baseline(map: XMapScene, where: String) -> void:
	await _stand(map, SPOTS[where])
	actions = 0
	shop_opens = 0
	ev_runs = 0
	await kb_ok()
	await frames(20)
	check("%s_baseline_confirm_investigates" % where, actions == 1 and ev_runs == 1 and (map.busy or shop_opens > 0), _st(map))
	await _clear(map)


func _flow(map: XMapScene, where: String, tag: String, ok: Callable, mash := 0, mash_with: Callable = Callable()) -> void:
	var name := "%s_%s" % [where, tag]
	var page := await _setup(map, SPOTS[where])
	var ready := page != null and (page._mode == "action" if page.skin == null else page._mode == "list")
	check("%s_item_page" % name, ready, _st(map))
	if not ready:
		return
	actions = 0
	shop_opens = 0
	ev_runs = 0
	await ok.call(3, 0)   # 使用：物品页与菜单关掉，回地图跑 CE229
	var m: Callable = mash_with if mash_with.is_valid() else ok
	for i in mash:        # 连点：使用后紧接着又按
		await m.call(2, 2)
	var arrived := await until(func(): return map.map_id == LAMP_MAP and not map.busy, 900)
	check("%s_transferred" % name, arrived, _st(map))
	check("%s_no_investigate" % name, ev_runs == 0 and shop_opens == 0, _st(map))
	await frames(10)
	await _clear(map)


## 枫叶回城（TCLH_levelUP_button＝快捷键 1，预约 CE10：光柱 → 回大厅 (14,21)）：真触屏点枫叶。
## 回大厅后落点就在漩涡正下方，所以「传到了」看的是光柱放完、落到 (14,21)；站在 NPC 前时也一样。
func _flow_leaf(map: XMapScene, where: String, tag: String, tapper: Callable, mash := 0, mash_with: Callable = Callable()) -> void:
	var name := "%s_%s" % [where, tag]
	await _stand(map, SPOTS[where])
	var btn: Control = map.map_hud.return_button
	var center := btn.get_global_transform_with_canvas() * (btn.size / 2)
	tap_pos = center
	actions = 0
	shop_opens = 0
	ev_runs = 0
	var before := map.player.grid
	await tapper.call(3, 0)
	var m: Callable = mash_with if mash_with.is_valid() else tapper
	for i in mash:
		tap_pos = center
		await m.call(2, 2)
	var arrived := await until(func(): return map.map_id == LOBBY and map.player.grid == Vector2i(14, 21) and not map.busy, 900)
	check("%s_returned" % name, arrived, _st(map) + [before])
	check("%s_no_investigate" % name, ev_runs == 0 and shop_opens == 0, _st(map))
	await frames(10)
	await _clear(map)


## 快捷键 1（YEP_ButtonCommonEvents → CE10 回大厅）只预约、下一次 _process 才开跑；同一帧又按了确认（或预约还没开跑时按确认）
## 不能先调查面前的 NPC／漩涡——原版 Game_Map.update 先 setupStartingEvent 跑预约事件，玩家那一帧动不了。
## keys：同一帧按下的键；extra：预约后、开跑前再补一下确认（直接在预约上按确认）
func _flow_hotkey(map: XMapScene, where: String, tag: String, keys: Array, pre_reserve := false) -> void:
	var name := "%s_%s" % [where, tag]
	await _stand(map, SPOTS[where])
	actions = 0
	shop_opens = 0
	ev_runs = 0
	if pre_reserve:
		# 预约已在（例：快捷键／枫叶在别处预约过、还没轮到开跑），这一刻按确认
		XState.current.reserve_common_event(10)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = true
		Input.parse_input_event(e)
	Input.flush_buffered_events()
	await get_tree().physics_frame
	await get_tree().physics_frame
	for k in keys:
		_key(k, false)
	var arrived := await until(func(): return map.map_id == LOBBY and map.player.grid == Vector2i(14, 21) and not map.busy, 900)
	check("%s_returned" % name, arrived, _st(map))
	check("%s_no_investigate" % name, ev_runs == 0 and shop_opens == 0, _st(map))
	await frames(10)
	await _clear(map)


## 小o 核 P1-1：快捷键 1 和点按面前一格同一批到达（中间不跨物理帧）。地图点按（触屏仿出的左键）落在漩涡上＝D2 调查。
## order："key_first" 先送 1 再点；"tap_first" 先点再送 1；"tap_only" 只点（对照：照常调查）
func _cell_screen(map: XMapScene, c: Vector2i) -> Vector2:
	var ts := float(MVPlayer.TS)
	var world := Vector2(c) * ts + Vector2(ts, ts) / 2
	return get_viewport().get_screen_transform() * (map.player.get_canvas_transform() * world)


func _flow_tap_hotkey(map: XMapScene, where: String, order: String) -> void:
	var name := "%s_tap_hotkey_%s" % [where, order]
	await _stand(map, SPOTS[where])
	actions = 0
	shop_opens = 0
	ev_runs = 0
	var front := map.player.front_cell(8)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = _cell_screen(map, front)
	touch.pressed = true
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.keycode = KEY_1
	key.pressed = true
	var batch: Array = [touch] if order == "tap_only" else ([key, touch] if order == "key_first" else [touch, key])
	for e in batch:
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var up := touch.duplicate()
	up.pressed = false
	_send(up)
	if order != "tap_only":
		_key(KEY_1, false)
	if order == "tap_only":
		await frames(20)
		check("%s_investigates" % name, ev_runs == 1, _st(map))
	else:
		var arrived := await until(func(): return map.map_id == LOBBY and map.player.grid == Vector2i(14, 21) and not map.busy, 900)
		check("%s_returned" % name, arrived, _st(map))
		check("%s_no_investigate" % name, ev_runs == 0 and shop_opens == 0, _st(map))
	await frames(10)
	await _clear(map)


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
	watch = map
	await until(func(): return map.player != null and not map.busy)
	map.ui.child_entered_tree.connect(_on_ui_child)
	await frames(5)
	for where in SPOTS:
		await _baseline(map, where)
		await _flow(map, where, "kb", kb_ok)
		await _flow(map, where, "pad", pad_ok)
		await _flow(map, where, "vkey", t_ok)
		await _flow(map, where, "tap", touch_tap)
		await _flow(map, where, "tap_long", touch_long)
		await _flow(map, where, "kb_mash", kb_ok, 8)
		await _flow(map, where, "vkey_mash", t_ok, 8)
		await _flow(map, where, "tap_mash", touch_tap, 8)
		await _flow(map, where, "tap_mash_vkey", touch_tap, 8, t_ok)
	for where in SPOTS:
		await _flow_leaf(map, where, "leaf_tap", touch_tap)
		await _flow_leaf(map, where, "leaf_tap_long", touch_long)
		await _flow_leaf(map, where, "leaf_tap_mash", touch_tap, 8)
		await _flow_leaf(map, where, "leaf_mash_vkey", touch_tap, 8, t_ok)
	for where in SPOTS:
		await _flow_hotkey(map, where, "hotkey1", [KEY_1])
		await _flow_hotkey(map, where, "hotkey1_with_ok", [KEY_1, KEY_ENTER])
		await _flow_hotkey(map, where, "reserved_then_ok", [KEY_ENTER], true)
	for where in SPOTS:
		await _flow_tap_hotkey(map, where, "tap_only")
		await _flow_tap_hotkey(map, where, "key_first")
		await _flow_tap_hotkey(map, where, "tap_first")
	# 新界面物品页（天启线开了、界面风格选「新」的西游档也会用到）：点牌上「使用」
	XUiSkin.FORCE = true
	for where in SPOTS:
		await _flow(map, where, "skin_tap", touch_tap)
		await _flow(map, where, "skin_tap_mash", touch_tap, 8)
		await _flow(map, where, "skin_kb_mash", touch_tap, 8, kb_ok)
	XUiSkin.FORCE = false
	# 用过道具之后，站在 NPC 面前按确认照常调查（修法不能把正常对话吃掉）
	await _baseline(map, "npc")
	# 回退开关 XMapScene.RESERVED_FIRST = false：旧行为——同一帧按 1 和确认，先调查面前的 NPC
	XMapScene.RESERVED_FIRST = false
	await _stand(map, SPOTS["npc"])
	ev_runs = 0
	for k in [KEY_1, KEY_ENTER]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = true
		Input.parse_input_event(e)
	Input.flush_buffered_events()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_key(KEY_1, false)
	_key(KEY_ENTER, false)
	await frames(20)
	check("switch_off_old_behavior_investigates_first", ev_runs == 1 and map.map_id == LOBBY and map.player.grid == SPOTS["npc"], _st(map))
	XMapScene.RESERVED_FIRST = true
	await _clear(map)
	# 回退开关 MVPlayer.DEFER_CLICK_ACTION = false：旧行为——先点漩涡再按 1（同一批），点按当场调查漩涡，回城被吞
	MVPlayer.DEFER_CLICK_ACTION = false
	var n0 := results.size()
	mute = true
	await _flow_tap_hotkey(map, "rift", "tap_first")
	mute = false
	var old_ok: bool = results.size() == n0 + 2 and not results[n0].passed and not results[n0 + 1].passed
	results.resize(n0)
	check("switch_off_click_old_behavior_swallows_return", old_ok)
	MVPlayer.DEFER_CLICK_ACTION = true
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
