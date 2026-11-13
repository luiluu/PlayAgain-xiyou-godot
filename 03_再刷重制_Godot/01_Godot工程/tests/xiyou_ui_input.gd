extends Node
## 界面输入（ui-input1，Codex 审查报告第 13、14、16 项）。全部走真实事件分发：Input.parse_input_event 注入触屏、按键、手柄、动作事件，
## 经 GameApp 下的 XKeyRepeat 等节点，再看页面收到了什么；不直接调页面的处理方法。
## - 第 13 项：虚拟确定键按住只算一次新按下（松开再按才算第二次），其余是回显（O-待定 HOLD_OK_ECHO：战斗列表、选目标认回显连发）；
##   虚拟方向键按住的连发是可识别的回显（echo），不是新的按下。
## - 第 14 项：网页面板、批量抽奖窗认 ui_cancel（虚拟取消键、安卓返回键、手柄 B、X 键）；输入框有焦点时打字键归输入框。
## - 第 16 项：标题初始化（光标）在 _title() 里，进标题就有光标、方向键能选；不是读自动存档失败后才出现。
## 回退开关两边都跑。
var results := []

## 记页面收到的事件：确定的「新按下」次数；方向的新按下与回显次数（与 shop._unhandled_input 同样的判断）
class Recorder extends Node:
	var accepts := 0
	var accept_echoes := 0
	var down_presses := 0
	var down_echoes := 0
	var accept_just := 0  # 轮询 is_action_just_pressed 的次数（地图 mv_player 这样问），回显不能让它再触发
	func _physics_process(_d: float) -> void:
		if Input.is_action_just_pressed("ui_accept"):
			accept_just += 1
	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept"):
			accepts += 1
		elif event.is_action_pressed("ui_accept", true):
			accept_echoes += 1
		if event.is_action_pressed("ui_down", true):
			if event.is_echo():
				down_echoes += 1
			else:
				down_presses += 1

func _ready() -> void:
	_run.call_deferred()

func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))

func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame

func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func to_window(pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * pos

func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = to_window(pos)
	e.pressed = pressed
	Input.parse_input_event(e)

func drag(index: int, pos: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = index
	d.position = to_window(pos)
	Input.parse_input_event(d)

func key(code: Key, pressed := true, unicode := 0) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.unicode = unicode
	e.pressed = pressed
	Input.parse_input_event(e)

func action(name: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = name
		e.pressed = pressed
		Input.parse_input_event(e)

func joy_b() -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_B
		e.pressed = pressed
		Input.parse_input_event(e)

func _run() -> void:
	XPlatform.force_mobile = true
	XTouchControls.SETTINGS_PATH = "user://test_xiyou_ui_input_touch.json"
	DirAccess.remove_absolute(XTouchControls.SETTINGS_PATH)
	var platform := XPlatform.new()
	platform.quit_on_back = false
	add_child(platform)
	var pad := XTouchControls.new()
	platform.add_child(pad)
	var rec := Recorder.new()
	add_child(rec)
	await frames(2)
	await _item13(pad, rec)
	await _item14(platform)
	await _item16()
	XPlatform.force_mobile = null
	DirAccess.remove_absolute(XTouchControls.SETTINGS_PATH)
	platform.queue_free()
	rec.queue_free()
	await frames()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 第 13 项 ----
func _hold_ok(pad: XTouchControls, rec: Recorder, n: int) -> Array:
	var ok_center: Vector2 = (pad.rects.ok as Rect2).get_center()
	var a := rec.accepts
	var ae := rec.accept_echoes
	var aj := rec.accept_just
	touch(0, ok_center, true)
	await physics(n)
	var held := [rec.accepts - a, rec.accept_echoes - ae, rec.accept_just - aj]
	touch(0, ok_center, false)
	await frames(2)
	held.append(Input.is_action_pressed("ui_accept"))  # 松开后不该还按着
	return held

func _hold_down(pad: XTouchControls, rec: Recorder, n: int) -> Array:
	var p := rec.down_presses
	var e := rec.down_echoes
	touch(0, pad.stick_center, true)
	drag(0, pad.stick_center + Vector2(0, 50))
	await physics(n)
	var held := [rec.down_presses - p, rec.down_echoes - e, Input.is_action_pressed("ui_down")]
	touch(0, pad.stick_center, false)
	await frames(2)
	return held

func _item13(pad: XTouchControls, rec: Recorder) -> void:
	# 按住确定 60 帧（过了 24 帧的连发点好几次）：只算一次新按下，其余是回显（24 帧后每 6 帧），轮询也只触发一次，松开即松
	var held: Array = await _hold_ok(pad, rec, 60)
	check("13_ok_hold_confirms_once", held[0] == 1, held)
	check("13_ok_hold_repeats_as_echo", held[1] >= 4, held)
	check("13_ok_hold_just_pressed_once", held[2] == 1, held)
	check("13_ok_released_after_echo", not held[3], held)
	# 松开再按：第二次确认
	var again: Array = await _hold_ok(pad, rec, 4)
	check("13_ok_release_then_press_again", again[0] == 1, again)
	# 摇杆往下按住 60 帧：一次新按下，其余是回显（24 帧后每 6 帧），方向一直按着
	var down: Array = await _hold_down(pad, rec, 60)
	check("13_stick_hold_one_press", down[0] == 1, down)
	check("13_stick_hold_repeats_as_echo", down[1] >= 4, down)
	check("13_stick_hold_still_pressed", down[2], down)
	# 同一次按住不延续到下一个页面：按着摇杆时换了场景，回显停下（要松开再按）
	var other := Node.new()
	add_child(other)
	var e0 := rec.down_echoes
	touch(0, pad.stick_center, true)
	drag(0, pad.stick_center + Vector2(0, 50))
	await physics(30)
	var mid := rec.down_echoes
	XTouchControls.scene_override = other
	await physics(40)
	var after := rec.down_echoes
	touch(0, pad.stick_center, false)
	await frames(2)
	check("13_hold_does_not_carry_to_next_scene", mid > e0 and after == mid, [e0, mid, after])
	XTouchControls.scene_override = null
	# 确定的连发也一样：按着换了场景就停
	var oe0 := rec.accept_echoes
	var ok_center: Vector2 = (pad.rects.ok as Rect2).get_center()
	touch(0, ok_center, true)
	await physics(30)
	var omid := rec.accept_echoes
	XTouchControls.scene_override = other
	await physics(40)
	var oafter := rec.accept_echoes
	touch(0, ok_center, false)
	await frames(2)
	check("13_ok_hold_does_not_carry_to_next_scene", omid > oe0 and oafter == omid, [oe0, omid, oafter])
	XTouchControls.scene_override = null
	other.queue_free()
	# 回退开关 HOLD_OK_ECHO = false：按住确定一点不连发（O-225 的样子）
	XTouchControls.HOLD_OK_ECHO = false
	var no_echo: Array = await _hold_ok(pad, rec, 60)
	check("13_rollback_ok_no_echo", no_echo[0] == 1 and no_echo[1] == 0, no_echo)
	XTouchControls.HOLD_OK_ECHO = true
	# 回退开关：照旧所有键按住都按「新按下」连发
	XTouchControls.HOLD_REPEAT_ECHO = false
	var old_ok: Array = await _hold_ok(pad, rec, 60)
	check("13_rollback_ok_repeats", old_ok[0] >= 3, old_ok)
	var old_down: Array = await _hold_down(pad, rec, 60)
	check("13_rollback_stick_repeats_as_press", old_down[0] >= 3 and old_down[1] == 0, old_down)
	XTouchControls.HOLD_REPEAT_ECHO = true


# ---- 第 14 项 ----
func _web_panel(with_input: bool) -> Array:
	var panel := XWebPanel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var edit: LineEdit = null
	if with_input:  # 装备检索的搜索框
		edit = LineEdit.new()
		edit.size = Vector2(300, 40)
		panel.add_child(edit)
	var closed := [false]
	panel.closed.connect(func(): closed[0] = true)
	add_child(panel)
	await frames(1)
	if edit != null:
		edit.grab_focus()
	await frames(1)
	return [panel, closed, edit]

func _cancel_closes(how: Callable, with_input := false) -> bool:
	var got: Array = await _web_panel(with_input)
	how.call()
	await frames(2)
	var closed: bool = got[1][0]
	if is_instance_valid(got[0]) and not got[0].is_queued_for_deletion():
		got[0].queue_free()
		await frames(1)
	return closed

func _dialog() -> XCasinoDialog:
	var d := XCasinoDialog.new()
	var se := {"mode": "single", "rules": XCasinoBatch.MODES.single, "state": "drawing", "stop": false}
	d.session = se
	se.dialog = d
	XCasinoBatch.session = se
	add_child(d)
	await frames(2)
	d.input.grab_focus()
	await frames(1)
	return d

func _item14(platform: XPlatform) -> void:
	var saved_state := XState.current
	XState.current = XState.new()
	check("14_esc_closes_web_panel", await _cancel_closes(func(): key(KEY_ESCAPE); key(KEY_ESCAPE, false)))
	check("14_virtual_cancel_closes_web_panel", await _cancel_closes(func(): action("ui_cancel")))
	check("14_back_key_closes_web_panel", await _cancel_closes(func(): platform.go_back(0)))
	check("14_pad_b_closes_web_panel", await _cancel_closes(func(): joy_b()))
	check("14_x_key_closes_web_panel", await _cancel_closes(func(): key(KEY_X, true, 0x78); key(KEY_X, false)))
	# 输入框有焦点：X 是打字，归输入框，不关；Esc、虚拟取消照样关
	check("14_x_in_input_types_not_closes", not await _cancel_closes(func(): key(KEY_X, true, 0x78); key(KEY_X, false), true))
	check("14_esc_in_input_closes", await _cancel_closes(func(): key(KEY_ESCAPE); key(KEY_ESCAPE, false), true))
	check("14_virtual_cancel_in_input_closes", await _cancel_closes(func(): action("ui_cancel"), true))
	# 批量抽奖窗（数字框有焦点）：虚拟取消、返回键、手柄 B 都算「停止后续抽取」；小键盘 0 打进数字框
	for spec in [["virtual", func(): action("ui_cancel")], ["back", func(): platform.go_back(0)], ["pad_b", func(): joy_b()]]:
		var d := await _dialog()
		spec[1].call()
		await frames(2)
		check("14_casino_%s_cancels" % spec[0], XCasinoBatch.session.get("stop", false), spec[0])
		d.queue_free()
		XCasinoBatch.session = {}
	var d := await _dialog()
	key(KEY_KP_0, true, 0x30)
	key(KEY_KP_0, false)
	await frames(2)
	check("14_casino_kp0_types_not_cancels", not XCasinoBatch.session.get("stop", false))
	d.queue_free()
	XCasinoBatch.session = {}
	# 回退开关：只认 Esc
	XKeyMap.POPUP_CANCEL_ACTION = false
	check("14_rollback_virtual_cancel_ignored", not await _cancel_closes(func(): action("ui_cancel")))
	check("14_rollback_esc_still_closes", await _cancel_closes(func(): key(KEY_ESCAPE); key(KEY_ESCAPE, false)))
	XKeyMap.POPUP_CANCEL_ACTION = true
	XState.current = saved_state
	await frames(1)


# ---- 第 16 项 ----
func _item16() -> void:
	if not XDB.available():
		check("16_skipped_no_data", true)
		return
	var saved_dir = XSave.dir_override
	XSave.dir_override = "user://test_ui_input/" + str(Time.get_ticks_usec())
	var tq_title := XTianqiTitle.ENABLED
	XTianqiTitle.ENABLED = false  # 第 16 项查原版标题的光标与选中；新标题的光标和上下移动由 xiyou_tianqi_title 测
	var title: Node = load("res://modes/xiyou/entry.tscn").instantiate()
	add_child(title)
	await frames(3)
	check("16_title_has_cursor", title._cursor != null and is_instance_valid(title._cursor) and title._cursor.is_inside_tree())
	# 方向键选指令（真实按键）：没有存档时「旧的回忆」不可选，往下跳到下一个可选的
	var before: int = title._sel
	key(KEY_DOWN)
	key(KEY_DOWN, false)
	await frames(2)
	var n: int = title._commands.size()
	check("16_title_down_moves_selection", n < 2 or title._sel != before, [before, title._sel, n])
	XTianqiTitle.ENABLED = tq_title
	title.queue_free()
	await frames(1)
	XSave.dir_override = saved_dir
