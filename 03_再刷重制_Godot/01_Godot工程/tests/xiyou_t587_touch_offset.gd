extends Node
## T587：安卓点地目的地往左上偏（点右边几格走不过去、斜着走、切后台回来又好了）的等效模拟。
## 本机没有安卓真机，headless 也走不到引擎「FEATURE_MOUSE」那条换算分支，所以这样模拟：
## - 根窗口放大成手机分辨率（20:9 的 2400×1080、16:9 的 1920×1080），画面照 canvas_items 缩放；
## - 根窗口 position 设成旧版 WindowFit.apply 在安卓上记下的居中偏移（WindowFit.rectangle 算出来的那个）；
## - 「旧路」按 Godot 4.7.2 安卓的算法手算：(窗口 position 平移 × 画面缩放)⁻¹ × 触点（viewport.cpp:1489-1495＋window.cpp:3244），
##   断言它确实偏到别的格（复现）；
## - 「新路」发真 InputEventScreenTouch（引擎仿出鼠标左键），断言目的地就是点的那格、真走到；
## - 长按跟手：按住、拖到另一格、等 15 帧以上，目的地跟到拖到的格；
## - 切后台回来：引擎把窗口 position 归 0（display_server_android.cpp:773-776），归 0 前后点同一格结果一样；
## - WindowFit.mobile_skip：移动端不再设窗口；
## - 桌面（不是移动端）以及开关关：_click_pos／_pointer_pos 与 get_global_mouse_position 逐项相等（桌面一行不变）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []
var map: XMapScene


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


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


## 某格中心在窗口里的像素（安卓触屏事件给的就是这个坐标）
func _cell_screen(c: Vector2i) -> Vector2:
	var ts := float(MVPlayer.TS)
	var world := Vector2(c) * ts + Vector2(ts, ts) / 2
	return get_viewport().get_screen_transform() * (map.player.get_canvas_transform() * world)


func _touch(p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = p
	e.pressed = down
	_send(e)


func _drag(p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = p
	e.relative = rel
	_send(e)


func tap(c: Vector2i) -> void:
	var p := _cell_screen(c)
	_touch(p, true)
	_touch(p, false)


## 窗口像素对应的格（正确算法：只经画面缩放与镜头）
func _screen_cell(screen: Vector2) -> Vector2i:
	var world := map.player.get_canvas_transform().affine_inverse() * (get_viewport().get_screen_transform().affine_inverse() * screen)
	return Vector2i(floori(world.x / MVPlayer.TS), floori(world.y / MVPlayer.TS))


## 旧路：Godot 4.7.2 安卓 get_global_mouse_position 的算法（窗口 position 被多减一次）
func _old_cell(screen: Vector2, win_pos: Vector2i) -> Vector2i:
	var xf := Transform2D(0.0, Vector2(win_pos)) * get_viewport().get_screen_transform()
	var world := map.player.get_canvas_transform().affine_inverse() * (xf.affine_inverse() * screen)
	return Vector2i(floori(world.x / MVPlayer.TS), floori(world.y / MVPlayer.TS))


func _settle() -> void:
	await until(func(): return not map.player.is_moving() and map.player.touch_target.x < 0, 400)
	await frames(10)


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


func _res(tag: String, size: Vector2i, start: Vector2i) -> void:
	var root := get_window()
	root.size = size
	await frames(3)
	await _stand(start)
	var fit := WindowFit.rectangle(Rect2i(Vector2i.ZERO, size))
	var right3 := start + Vector2i(3, 0)
	# 复现：旧路按旧窗口偏移算，点右边 3 格会偏到别处
	var p := _cell_screen(right3)
	var old := _old_cell(p, fit.position)
	check("%s_old_path_offset_reproduced" % tag, old != right3, [old, right3, fit.position])
	check("%s_old_path_lands_left" % tag, old.x < right3.x and old.y <= right3.y, [old, right3])
	# 新路：窗口 position 还留着旧偏移（老版本冷启动的样子），点右边 1～4 格都准、真走到
	root.position = fit.position
	for k in [1, 2, 3, 4]:
		await _stand(start)
		var t := start + Vector2i(k, 0)
		tap(t)
		check("%s_tap_right%d_target" % [tag, k], map.player._hold_cell == t, [map.player._hold_cell, t])
		await _settle()
		check("%s_tap_right%d_walks_there" % [tag, k], map.player.grid == t, [map.player.grid, t])
	# 长按跟手：按在右 1 格，拖到右 4 格，等 30 帧（跟手要 15 帧起）
	await _stand(start)
	var a := _cell_screen(start + Vector2i(1, 0))
	var b := _cell_screen(start + Vector2i(4, 0))
	_touch(a, true)
	await frames(2)
	_drag(b, b - a)
	# 按住不动时镜头跟着人物卷，指下的格子会变（原版 TouchInput 按住每帧按屏幕点重算目的地，同桌面），所以每帧比「当下指下那格」
	var follow_ok := true
	var follow_seen := 0
	var follow_detail := []
	for i in 40:
		await frames(1)
		if map.player._hold_count < 15:
			continue
		var under := _screen_cell(b)
		var tgt := map.player.touch_target
		if tgt.x >= 0:
			follow_seen += 1
			if tgt != under:
				follow_ok = false
				follow_detail = [i, tgt, under, _old_cell(b, fit.position)]
	_touch(b, false)
	await _settle()
	check("%s_hold_follow_under_finger" % tag, follow_ok and follow_seen > 0, [follow_seen, follow_detail])
	check("%s_hold_follow_went_right" % tag, map.player.grid.y == start.y and map.player.grid.x >= start.x + 4, map.player.grid)
	# 切后台回来：引擎把 position 归 0，点同一格结果一样
	await _stand(start)
	tap(right3)
	var before := map.player._hold_cell
	await _settle()
	root.position = Vector2i.ZERO
	await _stand(start)
	tap(right3)
	var after := map.player._hold_cell
	await _settle()
	check("%s_resume_same_cell" % tag, before == right3 and after == right3 and map.player.grid == right3, [before, after, map.player.grid])


## 桌面与开关关：点落点、长按落点都等于 get_global_mouse_position（桌面那条路一行没改）
func _desktop_same() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(123, 45)
	XPlatform.force_mobile = false
	check("desktop_click_pos_is_global", map.player._click_pos(e) == map.player.get_global_mouse_position())
	check("desktop_pointer_pos_is_global", map.player._pointer_pos() == map.player.get_global_mouse_position())
	check("desktop_window_fit_not_skipped_by_mobile", not WindowFit.mobile_skip())
	XPlatform.force_mobile = true
	MVPlayer.MOBILE_TAP_POS = false
	check("switch_off_click_pos_is_global", map.player._click_pos(e) == map.player.get_global_mouse_position())
	check("switch_off_pointer_pos_is_global", map.player._pointer_pos() == map.player.get_global_mouse_position())
	MVPlayer.MOBILE_TAP_POS = true
	check("mobile_window_fit_skipped", WindowFit.mobile_skip())
	WindowFit.MOBILE_SKIP = false
	check("switch_off_window_fit_not_skipped", not WindowFit.mobile_skip())
	WindowFit.MOBILE_SKIP = true


func _run() -> void:
	TestEnv.isolate("xiyou_t587_touch_offset")
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
		XPlatform.force_mobile = true
		await _res("w20x9", Vector2i(2400, 1080), start)
		await _res("w16x9", Vector2i(1920, 1080), start)
		get_window().position = Vector2i.ZERO
		await _desktop_same()
		XPlatform.force_mobile = null
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
