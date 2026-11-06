extends Node
## 键位补全（platform-keys1）：Z／J 确认，X／K／Insert／小键盘0 取消，WASD 与小键盘 8/2/4/6 方向；Esc 关菜单那帧地图不再重开。回退开关 XKeyMap.MV_KEYS。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


static func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e


func _run() -> void:
	# 启动时已补好（GameApp._ready）
	var want := {"ui_accept": [KEY_Z, KEY_J, KEY_ENTER, KEY_SPACE], "ui_cancel": [KEY_X, KEY_K, KEY_INSERT, KEY_KP_0, KEY_ESCAPE],
		"ui_up": [KEY_W, KEY_KP_8, KEY_UP], "ui_down": [KEY_S, KEY_KP_2, KEY_DOWN],
		"ui_left": [KEY_A, KEY_KP_4, KEY_LEFT], "ui_right": [KEY_D, KEY_KP_6, KEY_RIGHT]}
	for action in want:
		for code in want[action]:
			check("%s_%s" % [action, OS.get_keycode_string(code)], InputMap.event_is_action(key(code), action), null)
	# 不该有的：W 不是翻页，Q／E 不进方向动作
	check("w_not_page", not InputMap.event_is_action(key(KEY_W), "ui_page_down"))
	check("q_not_direction", not InputMap.event_is_action(key(KEY_Q), "ui_up"))
	# 重复 apply 不叠加
	var n := InputMap.action_get_events("ui_accept").size()
	XKeyMap.apply()
	check("apply_idempotent", InputMap.action_get_events("ui_accept").size() == n)
	# 回退
	XKeyMap.remove()
	check("rollback_removes", not InputMap.event_is_action(key(KEY_Z), "ui_accept") and InputMap.event_is_action(key(KEY_ENTER), "ui_accept") and InputMap.event_is_action(key(KEY_ESCAPE), "ui_cancel"))
	XKeyMap.MV_KEYS = false
	XKeyMap.apply()
	check("switch_off_no_add", not InputMap.event_is_action(key(KEY_J), "ui_accept"))
	XKeyMap.MV_KEYS = true
	XKeyMap.apply()
	check("restored", InputMap.event_is_action(key(KEY_J), "ui_accept"))
	# Esc 关菜单同一帧不重开
	check("menu_call_blocked_same_frame", XKeyMap.menu_call_blocked(100, 100))
	check("menu_call_ok_next_frame", not XKeyMap.menu_call_blocked(100, 101) and not XKeyMap.menu_call_blocked(-1, 0))
	# 高分屏文字不加同色描边的开关（platform-keys1）
	check("crisp_switch", XMVCanvas.CRISP_HIDPI_TEXT and XMVCanvas.HIDPI_SCALE > 1.0 and XMVCanvas.HIDPI_SCALE < 2.0)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
