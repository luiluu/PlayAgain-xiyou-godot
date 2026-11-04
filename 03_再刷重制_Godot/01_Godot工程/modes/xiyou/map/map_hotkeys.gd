class_name XMapHotkeys
extends RefCounted
## 地图快捷键（YEP_ButtonCommonEvents）：按键预约公共事件，能不能用、用了什么效果都在公共事件里，这里只管按键。
## 正式 v0.28 插件参数：~ 428 一键存档、1 回到大厅 10、2／R 快捷回血 624、3／T 隐身 626、P 屏蔽 486、L 挂机 484。
## 可用场景（Scene_Map.updateScene 包装，只读源码）：只在地图页面（isActive，开着菜单、战斗、别的页面都不响应）；
## 文字窗开着不响应（isSceneChangeOk）；事件运行中不响应（isEventRunning）。其余一律响应：走动中、挂机中、乘载具中都行。
## 判定用 Input.isRepeated：按下那一帧触发，按住 24 帧后每 6 帧再触发一次，只认最后按下的键。按键计时不看场景，
## 所以在菜单里按住键、回到地图时可能正好接着连发，和原版一样。
## 和原版的差别：原版「最后按下的键」包含方向键等所有按键，这里只算这七个，按住 R 再按方向键时回血继续连发（原版停）。

const KEYS := {"Key ~": KEY_QUOTELEFT, "Key 1": KEY_1, "Key 2": KEY_2, "Key 3": KEY_3,
	"Key R": KEY_R, "Key T": KEY_T, "Key P": KEY_P, "Key L": KEY_L}
const REPEAT_WAIT := 24  # Input.keyRepeatWait
const REPEAT_INTERVAL := 6  # Input.keyRepeatInterval

var _down := {}
var _latest := 0
var _time := 0


## 插件参数里这个键绑的公共事件（没有绑或不是数字为 0）
static func event_of(physical_key: int) -> int:
	var params := XDB.plugin("YEP_ButtonCommonEvents")
	for name in KEYS:
		if KEYS[name] == physical_key:
			var v := str(params.get(name, ""))
			return int(v) if v.is_valid_int() else 0
	return 0


## Input.update 一帧（每物理帧调一次）：pressed(物理键码) -> bool。返回这一帧 isRepeated 成立的公共事件，没有为 0。
func step(pressed: Callable) -> int:
	if _latest != 0:
		if pressed.call(_latest):
			_time += 1
		else:
			_latest = 0
	for key in KEYS.values():
		var now: bool = pressed.call(key)
		if now and not _down.get(key, false):
			_latest = key
			_time = 0
		_down[key] = now
	if _latest == 0 or not (_time == 0 or (_time >= REPEAT_WAIT and _time % REPEAT_INTERVAL == 0)):
		return 0
	return event_of(_latest)
