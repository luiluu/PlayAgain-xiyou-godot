class_name MVPlayer
extends MVCharacter
## 玩家：键盘方向键/WASD 或触控（点按目标格，按格逐步靠近）移动；确定键调查前方事件。
## 遇敌：MV makeEncounterCount＝随机(步数)+随机(步数)+1，每走一步减 1。

signal stepped
signal action_pressed
signal touch_target_reached

var input_enabled := true
var touch_target := Vector2i(-1, -1)
var dash := true


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := get_global_mouse_position()
		touch_target = Vector2i(floori(p.x / TS), floori(p.y / TS))
		if touch_target == grid + dir_offset(direction) or touch_target == grid:
			touch_target = Vector2i(-1, -1)
			action_pressed.emit()
	elif event is InputEventScreenTouch and event.pressed:
		var p2: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position
		touch_target = Vector2i(floori(p2.x / TS), floori(p2.y / TS))


func update_character() -> void:
	super.update_character()
	if is_moving() or not input_enabled:
		return
	var d := _input_dir()
	if d == 0 and touch_target.x >= 0:
		d = _toward(touch_target)
		if d == 0:
			touch_target = Vector2i(-1, -1)
	if d != 0:
		move_speed = 5 if dash and (Input.is_physical_key_pressed(KEY_SHIFT) or touch_target.x >= 0) else 4
		if move_straight(d):
			stepped.emit()
		elif touch_target.x >= 0:
			# 走不过去：面向目标，若目标就是相邻格则视为调查
			if grid + dir_offset(d) == touch_target:
				action_pressed.emit()
			touch_target = Vector2i(-1, -1)
	elif Input.is_action_just_pressed("ui_accept") and not Input.is_key_pressed(KEY_META):
		# ⌘Enter 是切全屏（GameApp），轮询不受 set_input_as_handled 影响，这里排除
		action_pressed.emit()


func _input_dir() -> int:
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S):
		return 2
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		return 4
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		return 6
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W):
		return 8
	return 0


func _toward(t: Vector2i) -> int:
	var diff := t - grid
	if diff == Vector2i.ZERO:
		return 0
	var horiz := 6 if diff.x > 0 else 4
	var vert := 2 if diff.y > 0 else 8
	var first := horiz if absi(diff.x) >= absi(diff.y) else vert
	var second := vert if first == horiz else horiz
	if first == horiz and diff.x != 0 and can_pass(horiz):
		return horiz
	if first == vert and diff.y != 0 and can_pass(vert):
		return vert
	if second == horiz and diff.x != 0 and can_pass(horiz):
		return horiz
	if second == vert and diff.y != 0 and can_pass(vert):
		return vert
	return first
