extends Node
## 地图快捷键（YEP_ButtonCommonEvents，见 XMapHotkeys）：连发时序、绑定来自插件参数、可用场景（走动、挂机可按；
## 事件、文字、菜单不响应）、六个公共事件在真实地图上跑通（没有跳过的指令）。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func until(f: Callable, limit := 600) -> bool:
	for i in limit:
		if f.call():
			return true
		await get_tree().physics_frame
	return f.call()


func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## 按一下（按下等一个物理帧再松开）
func tap(code: int) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(1)


func settled(map: XMapScene) -> bool:
	return await until(func(): return not map.busy and XState.current.peek_common_event() == 0)


func test_timing() -> void:
	var h := XMapHotkeys.new()
	var held := {}
	var pressed := func(k): return held.get(k, false)
	var fired := []
	held[KEY_2] = true
	for i in 37:
		fired.append(h.step(pressed))
	var at := []
	for i in fired.size():
		if fired[i] != 0:
			at.append(i)
	# isRepeated：按下那帧，之后第 24、30、36 帧
	check("repeat_frames", at == [0, 24, 30, 36], at)
	check("repeat_event", fired[0] == 624, fired[0])
	held[KEY_T] = true
	check("latest_key_wins", h.step(pressed) == 626)
	held.erase(KEY_T)
	held.erase(KEY_2)
	check("released_silent", h.step(pressed) == 0)
	held[KEY_G] = true
	check("unbound_silent", h.step(pressed) == 0)


func test_bindings() -> void:
	var want := {KEY_QUOTELEFT: 428, KEY_1: 10, KEY_2: 624, KEY_R: 624, KEY_3: 626, KEY_T: 626, KEY_P: 486, KEY_L: 484}
	for k in want:
		check("bind_%d" % k, XMapHotkeys.event_of(k) == want[k], XMapHotkeys.event_of(k))


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_map_hotkeys"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	test_timing()
	test_bindings()
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 4
	s.x = 14
	s.y = 23
	s.set_self_switch(4, 20, "A", true)
	s.set_variable(21, 0)
	var map := XMapScene.new()
	add_child(map)
	await until(func(): return map.player != null and not map.busy)
	await frames(3)
	map.skipped_log.clear()

	# 回血：有无尽小紫瓶回 99999 生命魔法并提示；什么瓶都没有只提示
	var a: XActor = s.members()[0]
	XToast.shown.clear()
	await tap(KEY_2)
	await settled(map)
	check("heal_no_potion", XToast.shown.has("你没有无尽小红瓶或小紫瓶") and XToast.shown.has("你没有无尽小蓝瓶或小紫瓶"), XToast.shown)
	s.gain_item(793, 1)
	a.hp = 1
	a.mp = 0
	XToast.shown.clear()
	await tap(KEY_R)
	await settled(map)
	check("heal_R", a.hp > 1 and a.mp > 0 and XToast.shown.has("你恢复了10w生命、魔法"), [a.hp, a.mp, XToast.shown])

	# 隐身：有药才切，切换消耗一瓶；没药提示
	XToast.shown.clear()
	await tap(KEY_3)
	await settled(map)
	check("stealth_no_item", not s.switch(54) and XToast.shown.has("你的背包没有隐身药剂"), XToast.shown)
	s.gain_item(407, 1)
	await tap(KEY_T)
	await settled(map)
	check("stealth_on", s.switch(54) and s.item_count(407) == 0 and a.is_state_affected(174), [s.switch(54), s.item_count(407)])
	s.gain_item(408, 1)
	await tap(KEY_3)
	await settled(map)
	check("stealth_off", not s.switch(54) and s.item_count(408) == 0 and not a.is_state_affected(174))

	# 存档：大厅（变量 21＝0）按开局存档位存；副本里（变量 21≠0）只提示，不存
	s.set_switch(161, true)
	XSave.remove(1)
	XToast.shown.clear()
	await tap(KEY_QUOTELEFT)
	await settled(map)
	check("save_slot1", XSave.exists(1) and XToast.shown.has("存档成功，储存到了1号存档！"), XToast.shown)
	XSave.remove(1)
	s.set_variable(21, 1)
	s.set_variable(6, 37)
	await tap(KEY_QUOTELEFT)
	await settled(map)
	check("save_blocked_in_dungeon", not XSave.exists(1))

	# 挂机键：不在副本时解除禁用并提示；副本中不解除
	s.flags.HangUpProhibited = true
	await tap(KEY_L)
	await settled(map)
	check("hangup_keeps_prohibit_in_dungeon", not XHangUp.enabled(s))
	s.set_variable(21, 0)
	s.set_variable(6, 0)
	XToast.shown.clear()
	await tap(KEY_L)
	await settled(map)
	check("hangup_enable", XHangUp.enabled(s) and XToast.shown.has("摆烂功能已开启~！"), XToast.shown)

	# 屏蔽：开屏蔽页，取消回地图
	key(KEY_P, true)
	var opened := await until(func(): return _pingbi(map) != null, 120)
	key(KEY_P, false)
	check("pingbi_opens", opened and map.busy)
	await frames(1)
	if opened:
		_pingbi(map).cancel()
	await settled(map)
	check("pingbi_returns", not map.busy and _pingbi(map) == null and map.hud.visible)

	# 回大厅：副本中只提示不传送；大厅外传到地图 4；乘飞艇时拒绝
	s.set_variable(21, 1)
	var from := s.map_id
	await tap(KEY_1)
	await settled(map)
	check("home_blocked_in_dungeon", s.map_id == from)
	s.set_variable(21, 0)
	await tap(KEY_1)
	await settled(map)
	check("home_transfers", s.map_id == 4 and s.x == 14 and s.y == 21, [s.map_id, s.x, s.y])

	# 可用场景：菜单、事件（busy）不响应，也不留预约
	s.gain_item(793, 1)
	map._menu_open = true
	key(KEY_2, true)
	await frames(2)
	check("menu_no_reserve", s.peek_common_event() == 0 and not map.hotkeys_open())
	key(KEY_2, false)
	await frames(1)
	map._menu_open = false
	map.busy = true
	key(KEY_2, true)
	await frames(2)
	check("busy_no_reserve", s.peek_common_event() == 0 and not map.hotkeys_open())
	key(KEY_2, false)
	await frames(1)
	map.busy = false
	# 挂机中、走动中照样响应（原版只看 isEventRunning）
	s.hang_up_active = true
	s.hang_up_origin = map.player.grid
	check("hang_up_open", map.hotkeys_open())
	a.hp = 1
	await tap(KEY_2)
	await until(func(): return a.hp > 1, 120)
	check("heal_while_hanging", a.hp > 1)
	XHangUp.clear(s)
	await settled(map)

	check("no_skipped_commands", map.skipped_log.is_empty(), map.skipped_log)

	# 结果
	var failed := results.filter(func(r): return not r.passed)
	var passed := results.size() - failed.size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if failed.is_empty() else 1)


func _pingbi(map: XMapScene) -> XPingbiScene:
	for c in map.ui.get_children():
		if c is XPingbiScene and not c.is_queued_for_deletion():
			return c
	return null
