extends Node
## 按住键的连发节奏（ui11，O-189）：照 rpg_core Input.isRepeated，按下触发、满 24 帧后每 6 帧一次，只认最后按下的键；
## 系统回显被吞掉。回退开关 XKeyRepeat.MV_REPEAT。

var results := []
var got := []      # [帧, 物理键码, echo]
var frame := 0


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _physics_process(_d: float) -> void:
	frame += 1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		got.append([frame, int(event.physical_keycode), event.echo])


static func key(code: Key, pressed := true, echo := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	e.echo = echo
	return e


func send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var kr: XKeyRepeat = get_node("/root/GameApp").key_repeat
	check("node_under_gameapp", kr != null and kr.get_parent().name == "GameApp")
	check("frames_rule", not XKeyRepeat.repeats_at(23) and XKeyRepeat.repeats_at(24) and not XKeyRepeat.repeats_at(27) and XKeyRepeat.repeats_at(30), null)
	await phys(2)
	got.clear()
	send(key(KEY_DOWN))
	var f0 := frame
	# 系统回显被吞
	send(key(KEY_DOWN, true, true))
	await phys(40)
	var echoes := got.filter(func(r): return r[2])
	var firsts := got.filter(func(r): return not r[2])
	check("press_once", firsts.size() == 1, got)
	check("three_mv_echoes_in_40", echoes.size() == 3, got)
	if echoes.size() == 3:
		check("echo_gap_6", echoes[1][0] - echoes[0][0] == 6 and echoes[2][0] - echoes[1][0] == 6, echoes)
		check("first_echo_about_24", absi(echoes[0][0] - f0 - 24) <= 1, [echoes[0][0], f0])
	# 只认最后按下的键：按着下再按右，下不再连发
	got.clear()
	send(key(KEY_RIGHT))
	await phys(31)
	var downs := got.filter(func(r): return r[2] and r[1] == KEY_DOWN)
	var rights := got.filter(func(r): return r[2] and r[1] == KEY_RIGHT)
	check("latest_key_only", downs.is_empty() and rights.size() == 2, got)
	send(key(KEY_RIGHT, false))
	send(key(KEY_DOWN, false))
	got.clear()
	await phys(40)
	check("released_stops", got.is_empty(), got)
	# 回退：系统回显照常、不补
	XKeyRepeat.MV_REPEAT = false
	send(key(KEY_UP))
	send(key(KEY_UP, true, true))
	await phys(40)
	var e2 := got.filter(func(r): return r[2])
	check("rollback_os_echo_passes", e2.size() == 1, got)
	send(key(KEY_UP, false))
	XKeyRepeat.MV_REPEAT = true
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
