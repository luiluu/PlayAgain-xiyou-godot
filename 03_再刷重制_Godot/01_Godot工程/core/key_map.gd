class_name XKeyMap
extends RefCounted
## 键位（platform-keys1）：照正式版运行时的 Input.keyMapper。核心 rpg_core 只有方向键／数字键盘／Z、空格、回车／X、Esc、Insert／Q、W；
## 但游戏启用的 YEP_ButtonCommonEvents 在每个场景开头（_revertButton('ALL')）把键位改成：
## 确认 回车、空格、Z、J；取消 Esc、Insert、X、K、小键盘0；上下左右 方向键、WASD、小键盘 8/2/4/6；翻页 PageUp／Q、PageDown／E（W 改成上）。
## 这里把缺的键补进 Godot 的 ui_* 动作，各页原来问 ui_accept／ui_cancel／ui_up… 的地方不用改。翻页 Q／E 各页已单独处理，不放进动作。
## 地图上数字键盘 2/4/6/8 在原版被插件改成快捷键名而不能走路（BCE 参数写错的副作用），这里不照搬，地图上也能走。
## 回退开关 MV_KEYS = false：不补，回到只有 Godot 默认键位（只影响开关关之后的 apply，已补的键靠 remove 撤）。

static var MV_KEYS := true
## 按键标成已处理（O-212）：确认键开新游戏、读档、回大厅这类处理里，change_scene 会立刻把当前场景摘下树，
## 之后再 get_viewport() 是 null。调试版只报「Cannot call method 'set_input_as_handled' on a null value」，
## 发行模板的 GDScript 不查空，直接对空指针调用、闪退（11-06 天启篇标题按空格/J 退出，崩溃报告 SIGSEGV 0x450）。
## 回退开关 SAFE_HANDLED = false：照旧直接调用（不在树上时发行版仍会闪退）。
static var SAFE_HANDLED := true
## Codex 审查报告第 14 项（O-226）：自己用 _input 收键的弹层（网页面板 XWebPanel、批量抽奖窗 XCasinoDialog）原先只认 Esc，
## 虚拟取消键、安卓返回键（都发 ui_cancel 动作）、手柄 B、X／K／Insert 都关不掉，手机上只能点「关闭」。现在认 ui_cancel 全部来源。
## 优先级：输入框（LineEdit／TextEdit）有焦点时，会打出字的取消键（X、K、小键盘 0）归输入框；Esc、虚拟取消键、返回键、手柄 B 照样关。
## 回退开关 POPUP_CANCEL_ACTION = false：回到只认 Esc。
static var POPUP_CANCEL_ACTION := true
## 地图上右键（两指点按）呼出菜单（platform-keys2，原版 isMenuCalled 含 TouchInput.isCancelled）
static var MV_MAP_RIGHT_MENU := true
## O-待定-1：触屏点一下，Godot 会送两份按下（第一指转出的鼠标左键＋触屏事件本身），按下即触发
## （ACTION_MODE_BUTTON_PRESS）的按钮会触发两次：挂机按钮开了又关（Kyo 11-13 反馈 v0.01.07 安卓点了不开始），
## 回城枫叶连播两声、预约两次回大厅。按钮的 pressed 里先问 first_press(按钮)：相隔不超过 2 帧的第二次不算。
## 回退开关 ONE_PRESS_PER_TAP = false：每份都算。
static var ONE_PRESS_PER_TAP := true
const TAP_FRAMES := 2

const EXTRA := {
	"ui_accept": [KEY_Z, KEY_J],
	"ui_cancel": [KEY_X, KEY_K, KEY_INSERT, KEY_KP_0],
	"ui_up": [KEY_W, KEY_KP_8],
	"ui_down": [KEY_S, KEY_KP_2],
	"ui_left": [KEY_A, KEY_KP_4],
	"ui_right": [KEY_D, KEY_KP_6],
}


## 手柄：LB／RB 翻页；X（冲刺）与 Y（菜单）给地图轮询用的动作（MV 的 shift／menu）。A、B、十字键、左摇杆用 Godot 默认的 ui_*。
static func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _has_joy(action: String, button: JoyButton) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return true
	return false


static func _has(action: String, code: Key) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == code:
			return true
	return false


static func apply() -> void:
	apply_pad()
	if not MV_KEYS:
		return
	for action in EXTRA:
		if not InputMap.has_action(action):
			continue
		for code in EXTRA[action]:
			if _has(action, code):
				continue
			var e := InputEventKey.new()
			e.physical_keycode = code
			InputMap.action_add_event(action, e)


static func apply_pad() -> void:
	for name in ["mv_dash", "mv_menu"]:  # 动作本身总是有（地图轮询它们），键位随开关
		if not InputMap.has_action(name):
			InputMap.add_action(name)
	if not MV_KEYS:
		return
	# A 确认、B 取消：先清掉 Godot 默认的手柄键（平台设置可能把两个对调），再按原版 gamepadMapper 0／1 加
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		for e in InputMap.action_get_events(pair[0]).duplicate():
			if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index != pair[1]:
				InputMap.action_erase_event(pair[0], e)
		if not _has_joy(pair[0], pair[1]):
			InputMap.action_add_event(pair[0], _joy(pair[1]))
	for pair in [["ui_page_up", JOY_BUTTON_LEFT_SHOULDER], ["ui_page_down", JOY_BUTTON_RIGHT_SHOULDER], ["mv_dash", JOY_BUTTON_X], ["mv_menu", JOY_BUTTON_Y]]:
		if not _has_joy(pair[0], pair[1]):
			InputMap.action_add_event(pair[0], _joy(pair[1]))


static func remove() -> void:
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		for e in InputMap.action_get_events(pair[0]).duplicate():
			if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == pair[1]:
				InputMap.action_erase_event(pair[0], e)
	for pair in [["ui_page_up", JOY_BUTTON_LEFT_SHOULDER], ["ui_page_down", JOY_BUTTON_RIGHT_SHOULDER], ["mv_dash", JOY_BUTTON_X], ["mv_menu", JOY_BUTTON_Y]]:
		for e in InputMap.action_get_events(pair[0]).duplicate():
			if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == pair[1]:
				InputMap.action_erase_event(pair[0], e)
	for action in EXTRA:
		if not InputMap.has_action(action):
			continue
		for e in InputMap.action_get_events(action).duplicate():
			if e is InputEventKey and (e as InputEventKey).physical_keycode in EXTRA[action]:
				InputMap.action_erase_event(action, e)


## 菜单收到 Esc 关掉的同一帧，地图的 _process 还看得到「Esc 刚按下」，会立刻又开菜单；关菜单那帧不许开
static func menu_call_blocked(closed_frame: int, frame: int) -> bool:
	return closed_frame == frame


## 弹层的取消（见 POPUP_CANCEL_ACTION）：node 是弹层自己，用来找输入焦点。
static func popup_cancel(event: InputEvent, node: Node) -> bool:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		return true
	if not POPUP_CANCEL_ACTION or not event.is_action_pressed("ui_cancel"):
		return false
	if event is InputEventKey and (event as InputEventKey).unicode != 0:
		var vp := node.get_viewport()
		var focus := vp.gui_get_focus_owner() if vp != null else null
		if (focus is LineEdit and (focus as LineEdit).editable) or (focus is TextEdit and (focus as TextEdit).editable):
			return false
	return true


## 代替 get_viewport() 再 set_input_as_handled()：节点已不在树上（刚切走场景）时跳过（不标已处理，和调试版报错后的表现一样，测试一直跑的就是这种情况）。
static func handled(node: Node) -> void:
	var vp := node.get_viewport()
	if vp == null and SAFE_HANDLED:
		return
	vp.set_input_as_handled()


## 这次按下算不算（同一下触屏的第二份按下返回 false）。记在按钮的 meta 上，各按钮各算各的。
static func first_press(button: Object) -> bool:
	var f := Engine.get_process_frames()
	var last := int(button.get_meta("_x_press_frame", -1))
	if ONE_PRESS_PER_TAP and last >= 0 and f - last <= TAP_FRAMES:
		return false
	button.set_meta("_x_press_frame", f)
	return true
