class_name MVPlayer
extends MVCharacter
## 玩家：键盘方向键/WASD 或触控（点按目标格，按格逐步靠近）移动；确定键调查前方事件。
## 遇敌：MV makeEncounterCount＝随机(步数)+随机(步数)+1，每走一步减 1。

signal stepped
signal action_pressed
signal touch_target_reached
## 点按的 D1／D2（Game_Player.triggerTouchActionD1／D2）：d2 假＝脚下（飞艇上下、脚下「确定键、角色下方」事件），真＝面前一格事件。
## 只在 DEFER_CLICK_ACTION 开着时发；关着时照旧发通用确认 action_pressed
signal touch_action(d2: bool)
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
## 原版 Scene_Map.updateDestination：地图不在前台或玩家不能动（isMapTouchOk 假：开战后场景已停、事件／文字在跑、去菜单）时每帧清目的地。
## 重制原先点地的目的地跨战斗、事件、挂机一直留着：开了「步步遇敌」点远处一格，每走一步一场、打完接着走，一路打到目的地，
## 挂机前留下的目的地停挂机后也接着走（v0.01.10 玩家反馈「停了挂机，一局之后立刻下一局，停不下来、跑不出去」）。
## 这里玩家不收输入（input_enabled 假：busy、菜单、挂机、载具升降）时清掉目的地与按住拖动。回退开关 MV_CLEAR_DEST = false：目的地一直留着。
static var MV_CLEAR_DEST := true
var _hold_count := 0
var _hold_cell := Vector2i(-1, -1)
var dash := true
## 乘载具时的移动速度（Game_Player.updateVehicleGetOn 设成 Game_Vehicle.moveSpeed：飞艇 6）；0＝走路。乘载具时不跑步
var vehicle_speed := 0


## 确认键要真的落到地图上（没被商店、菜单、对话框等界面用掉）才算调查（玩家反馈 v0.01.09「PC 按一次响应多次」）。
## 原来在物理帧里轮询 Input.is_action_just_pressed：轮询不看 set_input_as_handled，商店里按确认选「取消」关店、事件当帧收尾，
## 紧接着的物理帧又看到「刚按下」，再调查一次 NPC（又开对话、又开店）；高刷新率显示器上处理帧多于物理帧，更容易撞上。
## 原版 popScene 回地图要隔帧，Input.isTriggered 早已过去。这里在 _unhandled_input 记下这一下，下一次物理帧用掉。
var _accept_queued := false
## T507 返修（小o 核 P1-1）：点自己脚下／前方一格当确认（D1／D2）原来在输入回调里当场发 action_pressed，比地图物理帧采样快捷键 1
## 还早：1 和点按同一批到达时，先开了面前的漩涡／NPC，busy 之后热键不再预约，回城请求被吞。开着时这一下也像确认键一样先记下，
## 到玩家自己的物理帧（排在地图物理帧采样、预约快捷键之后）再发，预约的回城就会先跑（XMapScene.RESERVED_FIRST）。
## 小o 抽核 P1-3：照冻结 MV（Scene_Map.processMapTouch 只存最新目的地；Game_Player.updateNonmoving → triggerTouchAction 按目的地走
## D1／D2）。站定点脚下＝D1、点面前一格＝D2，记下留到玩家物理帧发 touch_action；走动／滑行中点按只改目的地（后点覆盖前点），
## 不转成确认键，停稳后按目的地走 D1（走到停下的 touch_target_reached）或 D2（走不过去、目的地正是面前格）。同一下点按只发一次。
## 例外（R2 P1-2）：乘飞艇滑行中点的就是正在滑进的这一格，停稳时按 D1 降落（原版要停稳后再点）。
## 回退开关 DEFER_CLICK_ACTION = false：回到当场发通用确认 action_pressed。
static var DEFER_CLICK_ACTION := true
## 站定时点的 D1／D2，等玩家物理帧发：0 没有、1 D1、2 D2
var _touch_queued := 0
## 乘飞艇滑行中点了正滑进的这一格（停稳时 D1 降落）
var _tap_self_moving := false


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	# ⌘Enter（macOS）／Alt+Enter（其它平台）是切全屏（GameApp），不算调查
	if event.is_action_pressed("ui_accept") and not WindowFit.fullscreen_modifier_held():
		_accept_queued = true
	# 手机按键设置「地图移动：仅方向键／轮盘移动」（改版 mapTouch，Scene_Map.processMapTouch 不处理）：触屏点按不走路
	if not XTouchControls.map_tap_allowed() and (event is InputEventScreenTouch or (event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION)):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hold_cell = _touch_cell(_click_pos(event as InputEventMouseButton))
		_hold_count = 1
		click_cell(_hold_cell)
	elif event is InputEventScreenTouch and event.pressed and not (DEFER_CLICK_ACTION and _touch_emulates_mouse()):
		# 引擎从触屏仿出了鼠标左键时上面已按那一下处理过（目的地、D1／D2）；这里再写目的地会把 click_cell 清掉的目的地又写回来，
		# 停稳后同一下再走一次 D2（同一下点按触发两次，P1-3）
		var p2: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position
		touch_target = _touch_cell(p2)


## 鼠标点到某格（$gameTemp.setDestination）。Game_Player.triggerTouchAction：点自己脚下（D1，飞艇在这里就上下飞艇）或前方一格（D2）
## 当作确认；乘飞艇时 D2 只查事件（canStartLocalEvents 为假，什么都不做），前方一格照常当目的地飞过去
func click_cell(c: Vector2i) -> void:
	touch_target = c
	if not DEFER_CLICK_ACTION:
		if touch_target == grid or (touch_target == front_cell(direction) and vehicle_speed <= 0):
			touch_target = Vector2i(-1, -1)
			action_pressed.emit()
		return
	# 后点覆盖前点：之前记下的 D1／D2 与飞艇滑行点脚下都作废
	_touch_queued = 0
	_tap_self_moving = false
	if is_moving():
		_tap_self_moving = vehicle_speed > 0 and c == grid
		return
	if c == grid:
		touch_target = Vector2i(-1, -1)
		_touch_queued = 1
	elif c == front_cell(direction) and vehicle_speed <= 0:
		touch_target = Vector2i(-1, -1)
		_touch_queued = 2


## T587：安卓点地目的地整体往左上偏（20:9 手机约左 4.7 格、上 0.75 格），点右边几格走不过去、斜着走。根因是启动时
## WindowFit.apply 给安卓根窗口记了个居中 position（引擎挪不动窗口，但值记下了），引擎算 get_global_mouse_position 时把它
## 又减一次（安卓的鼠标坐标本来就是窗口内坐标）；T507 之前触屏分支用事件自身坐标把目的地改回正确格，掩盖了它。
## 开着时移动端点地用事件自身坐标、长按跟手用最近一次鼠标事件自身坐标，不读窗口 position；桌面一行不变。
## WindowFit.MOBILE_SKIP（同号）从根上不再给移动端设窗口位置。回退：MOBILE_TAP_POS = false（O-690）。
static var MOBILE_TAP_POS := true

## T621（玩家反馈 11-28「点一个地方，哪怕用轮盘控制方向强行走开，最后还是会奔着那个点去」，Kyo「同时碰到的话轮盘优先级更高」）：
## 原版 Game_Player.moveByInput 有方向输入就 $gameTemp.clearDestination()，移植时漏了——方向键／轮盘只顶掉当步，点地目的地一直留着，
## 一松手又奔回去。开着时：站定要走的那一帧只要有方向输入（键盘、手柄、触屏轮盘），先清掉点地目的地和长按跟手，按方向走，
## 松开也不回头；同一帧刚点了地、排着的 D1／D2（点脚下／点面前）也作废，轮盘优先。T587 的点地坐标不动。
## false＝回到移植原样（方向只顶当步，目的地留着）。
static var STICK_CANCELS_TAP := true


## 点按落点（画布坐标）：移动端用事件自身坐标（同 ScreenTouch 分支），桌面照旧 get_global_mouse_position
func _click_pos(e: InputEventMouseButton) -> Vector2:
	if MOBILE_TAP_POS and XPlatform.is_mobile():
		return get_canvas_transform().affine_inverse() * e.position
	return get_global_mouse_position()


## 移动端最近一次鼠标事件（触屏仿出）的视口坐标，长按跟手用；在 _input 里记，界面控件吃掉的拖动也记得到
var _last_pointer := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if MOBILE_TAP_POS and event is InputEventMouse and XPlatform.is_mobile():
		_last_pointer = (event as InputEventMouse).position


## 长按跟手时手指当前位置（画布坐标）：移动端用最近一次鼠标事件自身坐标，桌面照旧 get_global_mouse_position
func _pointer_pos() -> Vector2:
	if MOBILE_TAP_POS and XPlatform.is_mobile():
		return get_canvas_transform().affine_inverse() * _last_pointer
	return get_global_mouse_position()


static func _touch_emulates_mouse() -> bool:
	return bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))


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
		var c := _touch_cell(_pointer_pos())
		if c != _hold_cell:
			_hold_cell = c
			touch_target = c if c != grid else Vector2i(-1, -1)
			_tap_self_moving = false


## $gameTemp.clearDestination（连同 Scene_Map._touchCount）
func clear_destination() -> void:
	touch_target = Vector2i(-1, -1)
	_hold_count = 0
	_tap_self_moving = false


func update_character() -> void:
	super.update_character()
	_update_hold()
	# 这一下确认键只给紧接着的这一个物理帧（同原版 isTriggered 只在按下那帧为真；走动中、不收输入时按的作废）
	var accept := _accept_queued
	_accept_queued = false
	# 站定时点的 D1／D2（DEFER_CLICK_ACTION）：不收输入（事件、菜单、挂机、升降）时作废
	var touch_kind := _touch_queued
	if not input_enabled:
		_touch_queued = 0
		_tap_self_moving = false
		touch_kind = 0
	if not is_moving() and auto_step.is_valid():
		for d in auto_step.call():
			if move_straight(d):
				stepped.emit()
				break
		return
	if is_moving() or not input_enabled:
		return
	var d := _input_dir()
	if STICK_CANCELS_TAP and d != 0 and (touch_kind != 0 or touch_target.x >= 0 or _hold_count > 0):
		_touch_queued = 0
		touch_kind = 0
		clear_destination()
	if touch_kind != 0:
		_touch_queued = 0
		touch_action.emit(touch_kind == 2)
		return
	if d == 0 and touch_target.x >= 0:
		d = _toward(touch_target)
		if d == 0:
			# 走到点的那格停下：Game_Player.updateNonmoving → triggerTouchAction → D1（脚下确定键事件）。
			# 点自己脚下在 click_cell 当场按确认、目标已清掉，所以到这里的一定是走过来的。
			var arrived := touch_target == grid and MV_TOUCH_D1
			var self_tap := _tap_self_moving and touch_target == grid
			_tap_self_moving = false
			touch_target = Vector2i(-1, -1)
			if self_tap:
				touch_action.emit(false)   # 飞艇滑行中点了这一格：D1 降落
			elif arrived:
				touch_target_reached.emit()
	if d != 0:
		move_speed = vehicle_speed if vehicle_speed > 0 else walk_speed()
		if move_straight(d):
			stepped.emit()
		elif touch_target.x >= 0:
			# 走不过去：面向目标，若目标就是相邻格则视为调查（乘飞艇时只在图边飞不过去，D2 不触发事件）
			if front_cell(d) == touch_target and vehicle_speed <= 0:
				if DEFER_CLICK_ACTION:
					touch_action.emit(true)   # D2：只查面前一格
				else:
					action_pressed.emit()
			touch_target = Vector2i(-1, -1)
	elif accept:
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
