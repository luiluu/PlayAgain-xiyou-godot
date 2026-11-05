class_name XKeyRepeat
extends Node
## 按住键的连发节奏（ui11，优化 O-待定）：原版 rpg_core Input.isRepeated——按下那帧触发，按住满 keyRepeatWait＝24 帧后
## 每 keyRepeatInterval＝6 帧再触发一次，只认最后按下的键（正式版没有插件改这两个数）。重制的菜单靠 Godot 的按键回显（echo），
## 节奏跟玩家系统的键盘设置走（各机不一样）。开着时由 GameApp 下的这个节点吞掉系统回显，按原版帧数自己补回显事件。
## 只管键盘；各页 _unhandled_input／_gui_input 收到的仍是「pressed＋echo」事件，写法不用改。用 _input 自己收键的页
## （victory_screen、casino_dialog、web_panel、boss_status_panel）先于本节点收到系统回显，不受影响。
## 回退开关 MV_REPEAT = false：不吞不补，回到系统节奏。

static var MV_REPEAT := true
const WAIT := 24       # Input.keyRepeatWait
const INTERVAL := 6    # Input.keyRepeatInterval

var _key: InputEventKey = null   # 最后按下、还按着的键
var _time := 0                   # 按下后过了几帧（Input._pressedTime）
var _pushing := false


## isRepeated 的帧判定（按下那帧 time＝0 由原事件触发，这里只管之后）
static func repeats_at(t: int) -> bool:
	return t >= WAIT and t % INTERVAL == 0


func _input(event: InputEvent) -> void:
	if _pushing or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if k.echo:
		if MV_REPEAT:
			get_viewport().set_input_as_handled()
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
