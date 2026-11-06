class_name XKeyRepeat
extends Node
## 按住键的连发节奏（ui11，优化 O-189）：原版 rpg_core Input.isRepeated——按下那帧触发，按住满 keyRepeatWait＝24 帧后
## 每 keyRepeatInterval＝6 帧再触发一次，只认最后按下的键（正式版没有插件改这两个数）。重制的菜单靠 Godot 的按键回显（echo），
## 节奏跟玩家系统的键盘设置走（各机不一样）。开着时由 GameApp 下的这个节点吞掉系统回显，按原版帧数自己补回显事件。
## 只管键盘；各页 _unhandled_input／_gui_input 收到的仍是「pressed＋echo」事件，写法不用改。用 _input 自己收键的页
## （victory_screen、casino_dialog、web_panel、boss_status_panel）先于本节点收到系统回显，不受影响。
## 回退开关 MV_REPEAT = false：不吞不补，回到系统节奏。

static var MV_REPEAT := true
## 手柄（platform-keys2）：原版 Input.gamepadMapper（A 确认、B 取消、X＝shift、Y＝menu、LB／RB 翻页、十字键）与 _updateGamepadState
## （左摇杆阈值 0.5，上下左右各自判断）。十字键、左摇杆、X 键被换成键盘方向键／Shift 的按键事件，页面和连发（24／6 帧）就同键盘一样；
## 摇杆抖动不会反复触发移动。A／B、LB／RB 走 Godot 默认的 ui_accept／ui_cancel 与 XKeyMap 补的 ui_page_up／down。
## 回退开关 MV_PAD = false：手柄事件原样往下传（回到 Godot 默认手柄映射）。
static var MV_PAD := true
const STICK_THRESHOLD := 0.5
const WAIT := 24       # Input.keyRepeatWait
const INTERVAL := 6    # Input.keyRepeatInterval

var _key: InputEventKey = null   # 最后按下、还按着的键
var _time := 0                   # 按下后过了几帧（Input._pressedTime）
var _pushing := false
var _axes := {JOY_AXIS_LEFT_X: 0.0, JOY_AXIS_LEFT_Y: 0.0}
var _dpad := {}                  # JOY_BUTTON_DPAD_* → 按着
var _pad_x := false
var _pad_keys := {}              # 手柄正按着的键盘等价键 keycode → true


func _ready() -> void:
	Input.joy_connection_changed.connect(func(_d, _c): _pad_release_all())


## isRepeated 的帧判定（按下那帧 time＝0 由原事件触发，这里只管之后）
static func repeats_at(t: int) -> bool:
	return t >= WAIT and t % INTERVAL == 0


func _input(event: InputEvent) -> void:
	if MV_PAD and not _pushing and _pad_input(event):
		XKeyMap.handled(self)
		return
	if _pushing or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if k.echo:
		if MV_REPEAT:
			XKeyMap.handled(self)
		return
	if k.pressed:
		_key = k.duplicate()
		_time = 0
	elif _key != null and _same(k, _key):
		_key = null


static func _same(a: InputEventKey, b: InputEventKey) -> bool:
	return a.physical_keycode == b.physical_keycode and a.keycode == b.keycode


## Input.update 一帧：按着的最后一个键计时，到点补一个回显
func _physics_process(_delta: float) -> void:
	if _key == null:
		return
	if not MV_REPEAT:
		return
	# 松键事件丢了（切走窗口等）时按实际按键状态收手
	var held := Input.is_physical_key_pressed(_key.physical_keycode) if _key.physical_keycode != KEY_NONE else Input.is_key_pressed(_key.keycode)
	held = held or _pad_keys.get(_key.keycode, false)
	if not held:
		_key = null
		return
	_time += 1
	if repeats_at(_time):
		push_repeat()


func push_repeat() -> void:
	var e: InputEventKey = _key.duplicate()
	e.echo = true
	e.pressed = true
	_pushing = true
	get_viewport().push_input(e)
	_pushing = false


## 测试用：当前跟着的键与帧数
func state() -> Dictionary:
	return {"key": _key.physical_keycode if _key else 0, "time": _time}


## 手柄事件：十字键／左摇杆／X 键吃掉，换成键盘方向键与 Shift 的按键事件（返回 true＝已吃掉）。其余手柄事件不管。
func _pad_input(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if m.axis != JOY_AXIS_LEFT_X and m.axis != JOY_AXIS_LEFT_Y:
			return false
		_axes[m.axis] = m.axis_value
	elif event is InputEventJoypadButton:
		var b := event as InputEventJoypadButton
		if b.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			_dpad[b.button_index] = b.pressed
		elif b.button_index == JOY_BUTTON_X:
			_pad_x = b.pressed
		else:
			return false
	else:
		return false
	_pad_sync()
	return true


## 原版 _updateGamepadState：先判上再判下、先判左再判右；十字键与摇杆合并
func pad_wanted() -> Dictionary:
	var up: bool = _dpad.get(JOY_BUTTON_DPAD_UP, false)
	var down: bool = _dpad.get(JOY_BUTTON_DPAD_DOWN, false)
	var left: bool = _dpad.get(JOY_BUTTON_DPAD_LEFT, false)
	var right: bool = _dpad.get(JOY_BUTTON_DPAD_RIGHT, false)
	var ay: float = _axes[JOY_AXIS_LEFT_Y]
	var ax: float = _axes[JOY_AXIS_LEFT_X]
	if ay < -STICK_THRESHOLD:
		up = true
	elif ay > STICK_THRESHOLD:
		down = true
	if ax < -STICK_THRESHOLD:
		left = true
	elif ax > STICK_THRESHOLD:
		right = true
	return {KEY_UP: up, KEY_DOWN: down and not up, KEY_LEFT: left, KEY_RIGHT: right and not left, KEY_SHIFT: _pad_x}


func _pad_sync() -> void:
	var want := pad_wanted()
	for code in want:
		if bool(want[code]) != bool(_pad_keys.get(code, false)):
			_pad_keys[code] = want[code]
			var e := InputEventKey.new()
			e.keycode = code
			e.physical_keycode = code
			e.pressed = want[code]
			get_viewport().push_input(e)


func _pad_release_all() -> void:
	_axes = {JOY_AXIS_LEFT_X: 0.0, JOY_AXIS_LEFT_Y: 0.0}
	_dpad.clear()
	_pad_x = false
	_pad_sync()
