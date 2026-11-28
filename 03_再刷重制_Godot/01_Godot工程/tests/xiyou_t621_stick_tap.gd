extends Node
## T621 专项：轮盘（方向输入）优先于点地（玩家反馈 11-28「点一个地方，哪怕用轮盘强行走开，最后还是奔着那个点去」）。
## 原版 Game_Player.moveByInput 有方向输入就 clearDestination，移植漏了；MVPlayer.STICK_CANCELS_TAP 开着时补上。
## 大厅 Map004 找一段横排 5 格空地：
## - 点地后推轮盘：点右边 4 格、走出一步后推左（ui_left，触屏轮盘发的就是这组动作）走回一步、松开，目的地清掉、不再往右走；
## - 同帧点地＋推轮盘：同一帧点右边 4 格又推左，第一步往左、目的地清掉；
## - 同帧点脚下（D1 排队）＋推轮盘：D1 作废，按轮盘走；
## - 长按跟手中推轮盘：跟手停掉；
## - 回退：开关关掉时松开后照旧奔回目的地（复现玩家说的现象）；
## - 不推轮盘只点地照旧走到（T587 点地不受影响）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []
var map: XMapScene
var actions := 0


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	print(("PASS " if ok else "FAIL ") + name + ("" if ok else " " + JSON.stringify(detail)))


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func until(f: Callable, limit := 600) -> bool:
	for i in limit:
		if f.call():
			return true
		await get_tree().physics_frame
	return f.call()


func _send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _free(c: Vector2i) -> bool:
	return not map.events.any(func(o): return o.grid == c)


## 找一段往右 5 格都能走、没有事件的横排（站在最左格）
func _pick_row() -> Vector2i:
	var w: int = map.lower.width
	var h: int = map.lower.height
	# 从地图中部往外找，避开左上角地图名横幅一类挡点击的界面
	var ys := range(2, h - 2)
	ys.sort_custom(func(a, b): return absi(a - h / 2) < absi(b - h / 2))
	var xs := range(2, w - 7)
	xs.sort_custom(func(a, b): return absi(a - w / 2) < absi(b - w / 2))
	for y in ys:
		for x in xs:
			var ok := true
			for k in range(0, 5):
				var c := Vector2i(x + k, y)
				if not _free(c) or not map.lower.is_passable(c.x, c.y, 6) or not map.lower.is_passable(c.x, c.y, 4):
					ok = false
					break
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _clear() -> void:
	for i in 12:
		if not map.busy and not map._menu_open:
			return
		for down in [true, false]:
			var e := InputEventKey.new()
			e.physical_keycode = KEY_ESCAPE
			e.keycode = KEY_ESCAPE
			e.pressed = down
			_send(e)
			await frames(3)
		await frames(20)


## 站到某格并等地图安静（照 xiyou_touch_dest_d1d2：大厅加载后可能跑事件，先清掉）
func _stand(c: Vector2i) -> void:
	await _clear()
	await map.load_map(map.map_id, c.x, c.y, 2)
	var calm := 0
	for i in 600:
		if map.busy or map._menu_open:
			calm = 0
			await _clear()
		else:
			calm += 1
			if calm >= 30:
				break
		await frames(1)
	map.player.clear_destination()
	await frames(2)


func _stick(action: String, down: bool) -> void:
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)


## 点地后推轮盘：开着时清目的地、停在推回的那格；关着时松开又奔回目的地
func _tap_then_stick(start: Vector2i, on: bool) -> void:
	var tag := "tap_then_stick" if on else "switch_off.tap_then_stick"
	MVPlayer.STICK_CANCELS_TAP = on
	await _stand(start + Vector2i(1, 0))
	var p := map.player
	p.click_cell(start + Vector2i(4, 0))
	# 格坐标在起步时就换成下一格：走向 +2 那步一开始就推左，这步走完按轮盘回头；回头那步一开始就松开
	await until(func(): return map.player.grid.x == start.x + 2, 300)
	_stick("ui_left", true)
	await until(func(): return map.player.grid.x == start.x + 1, 300)
	_stick("ui_left", false)
	await until(func(): return not map.player.is_moving(), 120)
	var cleared := p.touch_target.x < 0
	await frames(120)
	if on:
		check(tag + ".cleared", cleared, p.touch_target)
		check(tag + ".stays", p.grid == start + Vector2i(1, 0) and not p.is_moving(), p.grid)
	else:
		check(tag + ".goes_back", p.grid == start + Vector2i(4, 0), p.grid)
	MVPlayer.STICK_CANCELS_TAP = true


func _same_frame(start: Vector2i) -> void:
	await _stand(start + Vector2i(1, 0))
	var p := map.player
	p.click_cell(start + Vector2i(4, 0))
	_stick("ui_left", true)
	await until(func(): return map.player.grid != start + Vector2i(1, 0), 60)
	_stick("ui_left", false)
	var first_left := p.grid == start and p.direction == 4
	await until(func(): return not map.player.is_moving(), 120)
	await frames(60)
	check("same_frame.stick_first", first_left and p.touch_target.x < 0, [p.grid, p.direction, p.touch_target])
	check("same_frame.no_return", p.grid == start, p.grid)


func _same_frame_d1(start: Vector2i) -> void:
	await _stand(start + Vector2i(1, 0))
	var p := map.player
	actions = 0
	var count := func(_d2): actions += 1
	p.touch_action.connect(count)   # 站位换图会重建主角，连当前这个
	p.click_cell(p.grid)   # 点脚下：站定时排 D1
	_stick("ui_left", true)
	await until(func(): return map.player.grid != start + Vector2i(1, 0), 60)
	_stick("ui_left", false)
	await until(func(): return not map.player.is_moving(), 120)
	await frames(10)
	check("same_frame_d1.dropped", actions == 0 and p.grid == start, [actions, p.grid])
	p.touch_action.disconnect(count)


func _hold(start: Vector2i) -> void:
	await _stand(start + Vector2i(1, 0))
	var p := map.player
	p.click_cell(start + Vector2i(4, 0))
	p._hold_count = 20   # 长按跟手中
	_stick("ui_left", true)
	await frames(2)
	var stopped := p._hold_count == 0 and p.touch_target.x < 0
	await until(func(): return map.player.grid != start + Vector2i(1, 0), 60)
	_stick("ui_left", false)
	await until(func(): return not map.player.is_moving(), 120)
	check("hold.stopped", stopped, [p._hold_count, p.touch_target])


func _tap_only(start: Vector2i) -> void:
	await _stand(start)
	var p := map.player
	p.click_cell(start + Vector2i(4, 0))
	var ok := await until(func(): return map.player.grid == start + Vector2i(4, 0) and not map.player.is_moving(), 400)
	check("tap_only.arrives", ok, p.grid)


func _run() -> void:
	TestEnv.isolate("xiyou_t621_stick_tap")
	print("T621 XTestMode.enabled=", XTestMode.enabled())
	XMessageBox.auto = false
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 4
	s.x = 8
	s.y = 12
	s.direction = 2
	map = XMapScene.new()
	add_child(map)
	await until(func(): return map.player != null and not map.busy)
	var start := _pick_row()
	check("row_found", start.x >= 0, start)
	if start.x >= 0:
		await _tap_then_stick(start, true)
		await _tap_then_stick(start, false)
		await _same_frame(start)
		await _same_frame_d1(start)
		await _hold(start)
		await _tap_only(start)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
