extends Node
## T507 抽核 P1-3：触屏点地照冻结 MV 走 D1／D2（Scene_Map.processMapTouch 只存最新目的地；Game_Player.updateNonmoving → triggerTouchAction）。
## 西游档、天启篇两种模式各跑一遍，在大厅找一个面前一列空着的 NPC，站在它正南四格：
## - 只点它正南一格空地 T：停在 T，不开对话（对照）
## - 点 T，最后一步滑进 T 时再点 T（一次／连点四次）：停在 T，不开对话
## - 点 T，滑进 T 时改点身后空地 B：转身走到 B，不开对话
## - 站在 T 朝上点 NPC（D2）：开对话一次；从四格外点 NPC：走到面前停下自动调查一次
## - 重复触发：滑行中点 T、停稳后、站定点脚下，各只发一次 D1（touch_action／touch_target_reached／action_pressed 合计）
## 输入都是真 InputEventScreenTouch（引擎仿出鼠标左键），落点按当时镜头算。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const Kit := preload("res://tests/lib/tq_save_kit.gd")

var results := []
var map: XMapScene
var ev_runs := 0
var _last_ev := 0
var sig := {"d1": 0, "d2": 0, "reach": 0, "action": 0}


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _process(_dt: float) -> void:
	if map == null or not is_instance_valid(map):
		return
	var ev := map.running_event_id
	if ev != 0 and ev != _last_ev:
		ev_runs += 1
	_last_ev = ev


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


func _cell_screen(c: Vector2i) -> Vector2:
	var ts := float(MVPlayer.TS)
	var world := Vector2(c) * ts + Vector2(ts, ts) / 2
	return get_viewport().get_screen_transform() * (map.player.get_canvas_transform() * world)


## 真触屏点一下（同一物理帧内按下、松开）
func tap(c: Vector2i) -> void:
	var p := _cell_screen(c)
	for down in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = p
		e.pressed = down
		_send(e)


func _st() -> Array:
	return [map.map_id, map.player.grid, map.player.is_moving(), map.busy, ev_runs, sig.duplicate()]


func _reset() -> void:
	ev_runs = 0
	_last_ev = map.running_event_id
	for k in sig:
		sig[k] = 0


func _hook() -> void:
	var p := map.player
	if not p.is_connected("touch_action", _on_touch_action) if p.has_signal("touch_action") else not p.action_pressed.is_connected(_on_any):
		if p.has_signal("touch_action"):
			p.connect("touch_action", _on_touch_action)
		else:
			p.action_pressed.connect(_on_any)
		p.touch_target_reached.connect(func(): sig.reach += 1)
		p.action_pressed.connect(func(): sig.action += 1)


func _on_any() -> void:
	pass


func _on_touch_action(d2: bool) -> void:
	sig["d2" if d2 else "d1"] += 1


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


func _stand(c: Vector2i, dir := 8) -> void:
	await _clear()
	await map.load_map(map.map_id, c.x, c.y, dir)
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
	map.player.direction = dir
	map.player.clear_destination()
	_hook()
	await frames(2)
	_reset()


func _settle() -> void:
	await until(func(): return not map.player.is_moving() and map.player.touch_target.x < 0, 400)
	await frames(30)


## 大厅里找一个能用的 NPC：确定键、同层、有图，正南四格是空地（没有事件、走得过去）
func _pick_npc() -> Vector2i:
	for e in map.events:
		if e.page.is_empty() or e.trigger() != 0 or not e.is_normal_priority() or e.character_name == "":
			continue
		var n: Vector2i = e.grid
		var ok := true
		for k in range(1, 5):
			var c := n + Vector2i(0, k)
			if map.events.any(func(o): return o.grid == c) or not map.lower.is_passable(c.x, c.y, 8) or not map.lower.is_passable(c.x, c.y, 2):
				ok = false
				break
		if not ok:
			continue
		# 试走：站南四格点 T，要真的停在 T、不开对话
		await _stand(n + Vector2i(0, 4))
		tap(n + Vector2i(0, 1))
		await _settle()
		if map.player.grid == n + Vector2i(0, 1) and ev_runs == 0:
			return n
	return Vector2i(-1, -1)


func _wait_slide_into(t: Vector2i) -> bool:
	return await until(func(): return map.player.grid == t and map.player.is_moving(), 300)


func _mode(tag: String) -> void:
	var npc := await _pick_npc()
	check("%s_npc_found" % tag, npc.x >= 0)
	if npc.x < 0:
		return
	var t := npc + Vector2i(0, 1)
	var b := npc + Vector2i(0, 2)
	var start := npc + Vector2i(0, 4)
	# 对照：只点 T
	await _stand(start)
	tap(t)
	await _settle()
	check("%s_tap_empty_stops" % tag, map.player.grid == t and ev_runs == 0, _st())
	# 滑进 T 时再点 T 一次
	await _stand(start)
	tap(t)
	var slid := await _wait_slide_into(t)
	tap(t)
	await _settle()
	check("%s_slide_retap_no_talk" % tag, slid and map.player.grid == t and ev_runs == 0, _st())
	check("%s_slide_retap_one_d1" % tag, sig.reach + sig.d1 + sig.d2 + sig.action == 1, _st())
	await _clear()
	# 滑进 T 时连点 T 四次
	await _stand(start)
	tap(t)
	slid = await _wait_slide_into(t)
	for i in 4:
		tap(t)
		await frames(1)
	await _settle()
	check("%s_slide_mash_no_talk" % tag, slid and map.player.grid == t and ev_runs == 0, _st())
	check("%s_slide_mash_one_d1" % tag, sig.reach + sig.d1 + sig.d2 + sig.action == 1, _st())
	await _clear()
	# 滑进 T 时改点身后 B：后点覆盖前点
	await _stand(start)
	tap(t)
	slid = await _wait_slide_into(t)
	tap(b)
	await _settle()
	check("%s_slide_retarget_behind" % tag, slid and map.player.grid == b and ev_runs == 0, _st())
	await _clear()
	# 站定点脚下：D1 一次，不查面前（面前就是 NPC）
	await _stand(t)
	tap(t)
	await frames(60)
	check("%s_tap_self_d1_once_no_talk" % tag, sig.d1 == 1 and sig.d2 + sig.reach + sig.action == 0 and ev_runs == 0, _st())
	await _clear()
	# 站定点面前 NPC：D2 开对话一次
	await _stand(t)
	tap(npc)
	await frames(30)
	check("%s_tap_front_npc_talks_once" % tag, ev_runs == 1 and sig.d2 == 1 and sig.action == 0, _st())
	await _clear()
	# 四格外点 NPC：走到面前停下自动调查一次（原版 D2）
	await _stand(start)
	tap(npc)
	await until(func(): return ev_runs > 0, 400)
	await frames(30)
	check("%s_tap_far_npc_walks_and_talks_once" % tag, ev_runs == 1 and map.player.grid == t, _st())
	await _clear()


func _new_map(s: XState, map_id: int) -> void:
	if map != null and is_instance_valid(map):
		map.queue_free()
		await frames(2)
	s.map_id = map_id
	s.x = 8
	s.y = 12
	s.direction = 8
	map = XMapScene.new()
	add_child(map)
	await until(func(): return map.player != null and not map.busy)


func _run() -> void:
	TestEnv.isolate("xiyou_touch_dest_d1d2")
	XMessageBox.auto = false
	var s := XState.new_game(3, 1, [8, 10, 9])
	await _new_map(s, 4)
	await _mode("xiyou")
	var tq := Kit.new_game("jiusi")
	await _new_map(tq, XTianqi.HALL_MAP)
	await _mode("tianqi")
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
