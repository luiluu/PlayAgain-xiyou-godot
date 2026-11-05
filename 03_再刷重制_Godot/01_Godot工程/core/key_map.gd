class_name XKeyMap
extends RefCounted
## 键位（platform-keys1）：照正式版运行时的 Input.keyMapper。核心 rpg_core 只有方向键／数字键盘／Z、空格、回车／X、Esc、Insert／Q、W；
## 但游戏启用的 YEP_ButtonCommonEvents 在每个场景开头（_revertButton('ALL')）把键位改成：
## 确认 回车、空格、Z、J；取消 Esc、Insert、X、K、小键盘0；上下左右 方向键、WASD、小键盘 8/2/4/6；翻页 PageUp／Q、PageDown／E（W 改成上）。
## 这里把缺的键补进 Godot 的 ui_* 动作，各页原来问 ui_accept／ui_cancel／ui_up… 的地方不用改。翻页 Q／E 各页已单独处理，不放进动作。
## 地图上数字键盘 2/4/6/8 在原版被插件改成快捷键名而不能走路（BCE 参数写错的副作用），这里不照搬，地图上也能走。
## 回退开关 MV_KEYS = false：不补，回到只有 Godot 默认键位（只影响开关关之后的 apply，已补的键靠 remove 撤）。

static var MV_KEYS := true

const EXTRA := {
	"ui_accept": [KEY_Z, KEY_J],
	"ui_cancel": [KEY_X, KEY_K, KEY_INSERT, KEY_KP_0],
	"ui_up": [KEY_W, KEY_KP_8],
	"ui_down": [KEY_S, KEY_KP_2],
	"ui_left": [KEY_A, KEY_KP_4],
	"ui_right": [KEY_D, KEY_KP_6],
}


static func _has(action: String, code: Key) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == code:
			return true
	return false


static func apply() -> void:
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


static func remove() -> void:
	for action in EXTRA:
		if not InputMap.has_action(action):
			continue
		for e in InputMap.action_get_events(action).duplicate():
			if e is InputEventKey and (e as InputEventKey).physical_keycode in EXTRA[action]:
				InputMap.action_erase_event(action, e)


## 菜单收到 Esc 关掉的同一帧，地图的 _process 还看得到「Esc 刚按下」，会立刻又开菜单；关菜单那帧不许开
static func menu_call_blocked(closed_frame: int, frame: int) -> bool:
	return closed_frame == frame
