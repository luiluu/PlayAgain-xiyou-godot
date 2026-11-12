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
## 按住左键（platform-keys2）：原版 Scene_Map.processMapTouch 按住满 15 帧后每帧把目的地更新到鼠标所在格，边按边拖就能带着人走。
## 这里只在鼠标换了一格时更新（不重复触发脚下／前方一格的确认）。回退开关 MV_HOLD_MOVE = false。
static var MV_HOLD_MOVE := true
## 原版点地移动走到目的地停下时，触发脚下「确定键、角色下方」的事件（triggerTouchActionD1）；重制原先走到就停、要再按确定。
## 回退开关 MV_TOUCH_D1 = false。
static var MV_TOUCH_D1 := true
var _hold_count := 0
var _hold_cell := Vector2i(-1, -1)
var dash := true
## 乘载具时的移动速度（Game_Player.updateVehicleGetOn 设成 Game_Vehicle.moveSpeed：飞艇 6）；0＝走路。乘载具时不跑步
var vehicle_speed := 0


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	# 手机按键设置「地图移动：仅方向键／轮盘移动」（改版 mapTouch，Scene_Map.processMapTouch 不处理）：触屏点按不走路
	if not XTouchControls.map_tap_allowed() and (event is InputEventScreenTouch or (event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION)):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hold_cell = _touch_cell(get_global_mouse_position())
		_hold_count = 1
		click_cell(_hold_cell)
	elif event is InputEventScreenTouch and event.pressed:
		var p2: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position
		touch_target = _touch_cell(p2)


## 鼠标点到某格（$gameTemp.setDestination）。Game_Player.triggerTouchAction：点自己脚下（D1，飞艇在这里就上下飞艇）或前方一格（D2）
## 当作确认；乘飞艇时 D2 只查事件（canStartLocalEvents 为假，什么都不做），前方一格照常当目的地飞过去
func click_cell(c: Vector2i) -> void:
	touch_target = c
	if touch_target == grid or (touch_target == front_cell(direction) and vehicle_speed <= 0):
		touch_target = Vector2i(-1, -1)
		action_pressed.emit()


## Game_Player 的跑步姿势保持帧数（跟随用 isDashingPoseFollower 读它）
static var dash_pose := 0


## MOG isDashingPose：在移动且跑步；getActorId＝$gameParty._actors[0]
func _update_pose() -> void:
	var s := XState.current
	_apply_dash_pose(is_moving() and is_dashing(), int(s.party[0]) if s != null and not s.party.is_empty() else 0)
	dash_pose = pose_dash


func _update_hold() -> void:
	if not MV_HOLD_MOVE or _hold_count <= 0:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not input_enabled:
		_hold_count = 0
		return
	_hold_count += 1
	if _hold_count >= 15:
		var c := _touch_cell(get_global_mouse_position())
		if c != _hold_cell:
			_hold_cell = c
			touch_target = c if c != grid else Vector2i(-1, -1)


func update_character() -> void:
	super.update_character()
	_update_hold()
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
			# 走到点的那格停下：Game_Player.updateNonmoving → triggerTouchAction → D1（脚下确定键事件）。
			# 点自己脚下在 click_cell 当场按确认、目标已清掉，所以到这里的一定是走过来的。
			var arrived := touch_target == grid and MV_TOUCH_D1
			touch_target = Vector2i(-1, -1)
			if arrived:
				touch_target_reached.emit()
	if d != 0:
		move_speed = vehicle_speed if vehicle_speed > 0 else walk_speed()
		if move_straight(d):
			stepped.emit()
		elif touch_target.x >= 0:
			# 走不过去：面向目标，若目标就是相邻格则视为调查（乘飞艇时只在图边飞不过去，D2 不触发事件）
			if front_cell(d) == touch_target and vehicle_speed <= 0:
				action_pressed.emit()
			touch_target = Vector2i(-1, -1)
	elif Input.is_action_just_pressed("ui_accept") and not WindowFit.fullscreen_modifier_held():
		# ⌘Enter（macOS）／Alt+Enter（其它平台）是切全屏（GameApp），轮询不受 set_input_as_handled 影响，这里排除
		action_pressed.emit()


func move_straight(d: int) -> bool:
	if can_pass(d):
		before_step.emit()
	return super.move_straight(d)


## MV updateDashing：始终跑步时 Shift 反转；鼠标目标始终跑步，地图禁跑时、乘载具时为 false。
func is_dashing(shift = null) -> bool:
	var pressed := (Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_action_pressed("mv_dash")) if shift == null else bool(shift)
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


## 走路速度（Game_CharacterBase.realMoveSpeed）：Game_Player._moveSpeed（XState.player_move_speed，默认 4）＋冲刺 1
## 渡鸦 animationWait 包装里玩家取 $gameParty.leader()
func walking_actor():
	return XState.current.leader() if XState.current else null


func walk_speed() -> int:
	var base := XState.current.player_move_speed if XState.current != null else 4
	return base + (1 if is_dashing() else 0)
