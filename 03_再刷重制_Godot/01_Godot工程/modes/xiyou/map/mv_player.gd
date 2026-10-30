class_name MVPlayer
extends MVCharacter
## 玩家：键盘方向键/WASD 或触控（点按目标格，按格逐步靠近）移动；确定键调查前方事件。
## 遇敌：MV makeEncounterCount＝随机(步数)+随机(步数)+1，每走一步减 1。

signal stepped
signal action_pressed
signal touch_target_reached
## Game_Player.moveStraight：能走时先让队伍跟随追上一步（追的是玩家移动前的位置）
signal before_step

var input_enabled := true
## 挂机（XdRs_HangUp）：不在移动时调用，返回要依次尝试的方向；空数组为不动
var auto_step := Callable()
var touch_target := Vector2i(-1, -1)
var dash := true
## 乘载具时的移动速度（Game_Player.updateVehicleGetOn 设成 Game_Vehicle.moveSpeed：飞艇 6）；0＝走路。乘载具时不跑步
var vehicle_speed := 0


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := get_global_mouse_position()
		touch_target = _touch_cell(p)
		if touch_target == front_cell(direction) or touch_target == grid:
			touch_target = Vector2i(-1, -1)
			action_pressed.emit()
	elif event is InputEventScreenTouch and event.pressed:
		var p2: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position
		touch_target = _touch_cell(p2)


func update_character() -> void:
	super.update_character()
	if not is_moving() and auto_step.is_valid():
		for d in auto_step.call():
			if move_straight(d):
				stepped.emit()
				break
		return
	if is_moving() or not input_enabled:
		return
	var d := _input_dir()
	if d == 0 and touch_target.x >= 0:
		d = _toward(touch_target)
		if d == 0:
			touch_target = Vector2i(-1, -1)
	if d != 0:
		move_speed = vehicle_speed if vehicle_speed > 0 else (5 if is_dashing() else 4)
		if move_straight(d):
			stepped.emit()
		elif touch_target.x >= 0:
			# 走不过去：面向目标，若目标就是相邻格则视为调查
			if front_cell(d) == touch_target:
				action_pressed.emit()
			touch_target = Vector2i(-1, -1)
	elif Input.is_action_just_pressed("ui_accept") and not Input.is_key_pressed(KEY_META):
		# ⌘Enter 是切全屏（GameApp），轮询不受 set_input_as_handled 影响，这里排除
		action_pressed.emit()


func move_straight(d: int) -> bool:
	if can_pass(d):
		before_step.emit()
	return super.move_straight(d)


## MV updateDashing：始终跑步时 Shift 反转；鼠标目标始终跑步，地图禁跑时、乘载具时为 false。
func is_dashing(shift = null) -> bool:
	var pressed := Input.is_physical_key_pressed(KEY_SHIFT) if shift == null else bool(shift)
	return dash and vehicle_speed <= 0 and (touch_target.x >= 0 or (not pressed if XConfig.flag("alwaysDash") else pressed))


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


## 点到的格子（循环地图上点在绕回的那一份时换回地图内的格子）
func _touch_cell(p: Vector2) -> Vector2i:
	var c := Vector2i(floori(p.x / TS), floori(p.y / TS))
	return tilemap.round_cell(c) if tilemap else c

## 朝 d 的前方一格（循环地图绕回）
func front_cell(d: int) -> Vector2i:
	return tilemap.round_cell(grid + dir_offset(d)) if tilemap else grid + dir_offset(d)


func _toward(t: Vector2i) -> int:
	var diff := tilemap.delta(t, grid) if tilemap else t - grid
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
