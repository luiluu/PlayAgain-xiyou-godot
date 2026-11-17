extends Node
## 天启篇进大厅过场「落印」（T103，XTianqiHallIntro；开局界面提案 v0.2 第二节、第四节「时序锁」、D155）：
## 一、开关：新开局、新皮肤、动效不是「关」才播；动效「关」、界面风格原版、总开关关、开局指令取走后（读档、回大厅）都不播。
## 二、全部档整段播完：过场期间开局指令没取走、地图忙着、没有道号、EV020 没存档；地名条「方桌大厅」「九死 · 存档 3」，五人上场；
##     播完才跑问道号，EV020 首次到达存档照常；同图再进一次不播。
## 三、任意键跳过、点屏幕（触屏「轻触 跳过」）跳过、鼠标点一下、手柄键跳过：很快结束，开局照常；跳过后地图自己的地名条照常出。
## 四、简化档：直接合拢的漩涡＋徽记，比全部档短，播完开局照常。
## 五、读档进大厅不播。
## 存档写到 user://test_xiyou_hall_intro，测试结束删除；只改内存里的设置，不写本机 options.json。

const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
const HUB := 4

var results: Array = []
var _full_secs := 0.0


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _scene() -> Node:
	return get_tree().current_scene


func _wait(cond: Callable, timeout := 6000) -> bool:
	for i in range(timeout):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _map_idle() -> bool:
	var s = _scene()
	return s is XMapScene and s.map_id == HUB and s.player != null and not s.busy


func _intro() -> XTianqiHallIntro:
	var s = _scene()
	return s.get_node_or_null(XTianqiHallIntro.NODE_NAME) as XTianqiHallIntro if s is XMapScene else null


func _run() -> void:
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XSave.dir_override = "user://test_xiyou_hall_intro"
	XConfig.ensure_loaded()
	XConfig._values["codexUiSkin"] = true
	XUiSkin.touch_override = 0
	for slot in range(1, 11):
		DirAccess.remove_absolute(XSave.path(slot))
	Engine.time_scale = 4.0
	seed(20261117)
	_gate()
	await _full()
	await _skip("key", 4)
	await _skip("touch", 5)
	await _skip("mouse", 6)
	await _skip("joy", 10)
	await _simple()
	await _load_game()
	await _off()
	XUiSkin.motion_override = -1
	XUiSkin.touch_override = -1
	for slot in range(1, 11):
		DirAccess.remove_absolute(XSave.path(slot))
	DirAccess.remove_absolute(XSave.dir())
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _lineup() -> Array:
	var w: Array = XTianqiSkills.ids(XTier.WEAK, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var sup: Array = XTianqiSkills.ids(XTier.SUPER, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not [95, 173].has(id))
	return [w[5], sup[0], w[1], w[2], w[3]]


func _new_game(slot: int, scene := true) -> XState:
	XMessageBox.auto_answers = ["测试道号"]
	var s := XTianqi.start_new_game(slot, "jiusi", _lineup())
	s.random_master = XRandomStream.hex64(20261117 + slot)
	if scene:
		get_tree().change_scene_to_file(MAP_SCENE)
	return s


## 大厅首次到达的漩涡过场（EV76）、苍龙破晓（EV203）放完再走，免得协程挂着
func _settle(s: XState) -> void:
	await _wait(func(): return _map_idle() and s.self_switch(HUB, 76, "A") and (not XRift.STAGE2 or s.self_switch(HUB, XRift.RIFT2, "A")))


func _opening_done(tag: String, s: XState, slot: int) -> void:
	var ok := await _wait(func(): return _map_idle() and s.self_switch(HUB, 20, "A"))
	_check(tag + ".opening_after", ok and s.actor_name == "测试道号" and not XTianqi.has_pending(), [ok, s.actor_name])
	_check(tag + ".ev020_saved", s.fixed_save_slot() == slot and XSave.exists(slot), [s.fixed_save_slot(), XSave.exists(slot)])


# ---- 一、开关 ----
func _gate() -> void:
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	_check("gate.no_pending", not XTianqiHallIntro.wanted())
	var s := _new_game(9, false)
	XState.current = s
	_check("gate.new_game_full", XTianqiHallIntro.wanted())
	_check("gate.slot_from_pending", XTianqiHallIntro.pending_slot() == 9 and XTianqiHallIntro.subtitle(s) == "九死 · 存档 9", XTianqiHallIntro.subtitle(s))
	XUiSkin.motion_override = XUiSkin.Motion.SIMPLE
	_check("gate.simple_plays", XTianqiHallIntro.wanted())
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	_check("gate.motion_off", not XTianqiHallIntro.wanted())
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XConfig._values["codexUiSkin"] = false
	_check("gate.skin_old", not XTianqiHallIntro.wanted())
	XConfig._values["codexUiSkin"] = true
	XTianqiHallIntro.ENABLED = false
	_check("gate.switch_off", not XTianqiHallIntro.wanted())
	XTianqiHallIntro.ENABLED = true
	XUiSkin.touch_override = 1
	_check("gate.hint_touch", XTianqiHallIntro.skip_key_text() == "轻触")
	XUiSkin.touch_override = 0
	_check("gate.hint_keys", XTianqiHallIntro.skip_key_text() == "任意键")
	XTianqi.take_pending()
	_check("gate.pending_taken", not XTianqiHallIntro.wanted())


# ---- 二、全部档整段 ----
func _full() -> void:
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	var s := _new_game(3)
	var seen := await _wait(func(): return _intro() != null, 600)
	_check("full.cover", seen)
	var playing := await _wait(func(): return _intro() != null and _intro().playing, 600)
	_check("full.playing", playing)
	if not playing:
		return
	var it := _intro()
	_check("full.mode", it.mode == XUiSkin.Motion.FULL)
	_check("full.place_text", it.title_text == "方桌大厅" and it.sub_text == "九死 · 存档 3", [it.title_text, it.sub_text])
	_check("full.walkers", it._walkers.size() == 5, it._walkers.size())
	_check("full.badge", it._badge.texture != null)
	_check("full.skip_hint", (it.find_child("SkipKey", true, false) as Label).text == "任意键")
	_check("full.map_plate_hidden", _scene().map_name_text == "")
	# 触屏虚拟摇杆、AB 键：过场在全屏组里，跟全屏菜单一样收起
	_check("full.touch_controls_hide", it._mask.is_in_group(XUiSkin.FULLSCREEN_GROUP) and XUiSkin.fullscreen_menu_open(get_tree()))
	# 过场期间：开局指令还没取走、地图忙、没有道号、EV020 没存档
	var bad := []
	var frames := 0
	var wr: WeakRef = weakref(it)
	var flag := []
	it.done.connect(func(): flag.append(it.skipped))
	while wr.get_ref() != null and not (wr.get_ref() as XTianqiHallIntro).finished:
		frames += 1
		if not XTianqi.has_pending():
			bad.append("pending_taken")
		if not _scene().busy:
			bad.append("not_busy")
		if s.actor_name == "测试道号":
			bad.append("dao_hao")
		if s.self_switch(HUB, 20, "A") or XSave.exists(3):
			bad.append("ev020")
		if bad.size() > 0 or frames > 3000:
			break
		await get_tree().process_frame
		_full_secs += get_process_delta_time()
	var ended := wr.get_ref() == null or (wr.get_ref() as XTianqiHallIntro).finished
	_check("full.lock_held", bad.is_empty() and ended, [bad, frames])
	_check("full.not_skipped", ended and flag == [false], flag)
	_check("full.length", _full_secs > 2.6 and _full_secs < 3.8, _full_secs)
	await _opening_done("full", s, 3)
	await _settle(s)
	# 同图再进一次（回大厅）：不是新开局，不播
	_check("full.rehub_not_wanted", not XTianqiHallIntro.wanted())
	await _scene().load_map(HUB, s.x, s.y, s.direction)
	await get_tree().process_frame
	_check("full.rehub_no_intro", _intro() == null)


# ---- 三、跳过 ----
func _skip(how: String, slot: int) -> void:
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XUiSkin.touch_override = 1 if how == "touch" else 0
	var s := _new_game(slot)
	var playing := await _wait(func(): return _intro() != null and _intro().playing, 600)
	_check(how + ".playing", playing)
	if not playing:
		return
	var it := _intro()
	_check(how + ".hint", (it.find_child("SkipKey", true, false) as Label).text == ("轻触" if how == "touch" else "任意键"))
	for i in 3:
		await get_tree().process_frame
	var ev: InputEvent
	match how:
		"key":
			var k := InputEventKey.new()
			k.keycode = KEY_A
			k.physical_keycode = KEY_A
			k.pressed = true
			ev = k
		"touch":
			var t := InputEventScreenTouch.new()
			t.position = Vector2(400, 300)
			t.pressed = true
			ev = t
		"joy":
			var j := InputEventJoypadButton.new()
			j.button_index = JOY_BUTTON_A
			j.pressed = true
			ev = j
		_:
			var m := InputEventMouseButton.new()
			m.button_index = MOUSE_BUTTON_LEFT
			m.position = Vector2(400, 300)
			m.pressed = true
			ev = m
	var wr: WeakRef = weakref(it)
	var flag := []
	it.done.connect(func(): flag.append(it.skipped))
	Input.parse_input_event(ev)
	# 跳过淡出 0.15 秒：4 倍速下几帧就完；60 帧还没完算没跳过（整段要 3 秒多）
	var gone := await _wait(func(): return wr.get_ref() == null or (wr.get_ref() as XTianqiHallIntro).finished, 60)
	_check(how + ".skipped_fast", gone)
	_check(how + ".skipped_flag", flag == [true], flag)
	if how == "key":
		var up := InputEventKey.new()
		up.keycode = KEY_A
		up.physical_keycode = KEY_A
		up.pressed = false
		Input.parse_input_event(up)
	elif how == "mouse":
		var mu := InputEventMouseButton.new()
		mu.button_index = MOUSE_BUTTON_LEFT
		mu.position = Vector2(400, 300)
		mu.pressed = false
		Input.parse_input_event(mu)
	elif how == "joy":
		var ju := InputEventJoypadButton.new()
		ju.button_index = JOY_BUTTON_A
		ju.pressed = false
		Input.parse_input_event(ju)
	else:
		var tu := InputEventScreenTouch.new()
		tu.position = Vector2(400, 300)
		tu.pressed = false
		Input.parse_input_event(tu)
	_check(how + ".map_plate_back", _scene().map_name_text == "方桌大厅", _scene().map_name_text)
	await _opening_done(how, s, slot)
	await _settle(s)
	XUiSkin.touch_override = 0


# ---- 四、简化档 ----
func _simple() -> void:
	XUiSkin.motion_override = XUiSkin.Motion.SIMPLE
	var s := _new_game(7)
	var playing := await _wait(func(): return _intro() != null and _intro().playing, 600)
	_check("simple.playing", playing)
	if not playing:
		return
	var it := _intro()
	_check("simple.mode", it.mode == XUiSkin.Motion.SIMPLE)
	_check("simple.closed_vortex", it._circle.scale.x < 0.5 and it._badge.modulate.a > 0.9, [it._circle.scale, it._badge.modulate.a])
	var wr: WeakRef = weakref(it)
	var secs := 0.0
	var n := 0
	while wr.get_ref() != null and not (wr.get_ref() as XTianqiHallIntro).finished and n < 3000:
		await get_tree().process_frame
		secs += get_process_delta_time()   # 已乘 time_scale：过场自己的时间轴
		n += 1
	var ended := wr.get_ref() == null or (wr.get_ref() as XTianqiHallIntro).finished
	# 全部档约 3.1 秒（含地名条），简化档约 1.75 秒
	_check("simple.shorter", ended and secs < _full_secs * 0.7 and secs > 1.0, [secs, _full_secs])
	_check("simple.not_skipped", wr.get_ref() == null or not (wr.get_ref() as XTianqiHallIntro).skipped)
	await _opening_done("simple", s, 7)
	await _settle(s)


# ---- 五、读档不播 ----
func _load_game() -> void:
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	_check("load.slot", XSave.load_slot(3))
	_check("load.not_wanted", not XTianqiHallIntro.wanted())
	get_tree().change_scene_to_file(MAP_SCENE)
	var any := false
	for i in 600:
		if _intro() != null:
			any = true
			break
		if _map_idle():
			break
		await get_tree().process_frame
	_check("load.no_intro", not any and _map_idle())


# ---- 动效「关」：新开局也不播，开局跟以前一样 ----
func _off() -> void:
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	var s := _new_game(8)
	var any := false
	for i in 6000:
		if _intro() != null:
			any = true
		if _map_idle() and s.self_switch(HUB, 20, "A"):
			break
		await get_tree().process_frame
	_check("off.no_intro", not any)
	await _opening_done("off", s, 8)
	await _settle(s)
