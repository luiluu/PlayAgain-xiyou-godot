class_name XGraphics
extends RefCounted
## 画质设置（重制新增，Kyo 2026-11-13；设计见 00_设计/画质设置.md，O-待定-1）。
## 建在「画面平滑」（XScreenScale）之上，另加四项，存在配置的一个键 codexQuality（字典）里：
## - integer 整数倍缩放：根窗口 content_scale_stretch 设成整数倍，画面只按 1、2、3 倍放大，像素均匀、四周留黑边；
##   窗口比 1280×720 小时不生效（Godot 会按 1 倍画、裁掉画面）。
## - fps 帧率上限：0 跟随屏幕、60、30。只限画面刷新（Engine.max_fps）；游戏逻辑按物理帧走（XSpeedGear），速度不变。
## - window 窗口大小（只桌面）：auto 照旧（WindowFit 按屏幕九成）、三档固定大小、full 全屏。
## - crisp 像素柔边（默认开）：战斗图放大到 1.5 倍这类非整数倍时，像素不再宽窄不一；文字、图标不受影响。
## - motion 顺滑移动（默认开）：地图里走路、镜头在两个逻辑帧之间补位置，不再一顿一顿；游戏速度不变。
## - low 省电模式：帧率上限当作 30、画面按 1280×720 画再放大（同画面平滑开）、画面特效当作关；只覆盖生效值，不改那几项存的值。
## 像素柔边、顺滑移动默认开，其余默认「不干预」。
## 回退：ENABLED = false 时设置页不列「画质设置」，apply 什么都不碰，画面特效只看它自己的开关。

static var ENABLED := true
## 测试用：headless 下也照设帧率（平时 headless 不动 Engine.max_fps）
static var HEADLESS_APPLY := false

const KEY := "codexQuality"
const DEFAULTS := {"integer": false, "fps": 0, "window": "auto", "low": false, "crisp": true, "motion": true}
const FPS_CHOICES := [0, 60, 30]
const WINDOW_CHOICES := ["auto", "1280x720", "1600x900", "1920x1080", "full"]
const LOW_FPS := 30
const BASE := Vector2i(1280, 720)

## 上一次真正设到窗口上的 window 取值：同一个值不重复设（回标题会再进一次 apply，别盖掉玩家 F11 临时切的全屏）
static var _window_applied := "auto"


## 把存盘读回来的值校正成完整的字典（缺项、坏值按默认）
static func sanitize(saved: Variant) -> Dictionary:
	var out := DEFAULTS.duplicate()
	if not (saved is Dictionary):
		return out
	if saved.get("integer") is bool:
		out["integer"] = saved["integer"]
	if saved.get("low") is bool:
		out["low"] = saved["low"]
	if saved.get("crisp") is bool:
		out["crisp"] = saved["crisp"]
	if saved.get("motion") is bool:
		out["motion"] = saved["motion"]
	var fps = saved.get("fps")
	if (fps is int or fps is float) and FPS_CHOICES.has(int(fps)):
		out["fps"] = int(fps)
	if saved.get("window") is String and WINDOW_CHOICES.has(saved["window"]):
		out["window"] = saved["window"]
	return out


static func settings() -> Dictionary:
	return XConfig.quality()


static func low_power() -> bool:
	return ENABLED and bool(settings()["low"])


## 像素柔边现在开不开（XBattlerSprite 的身体材质用）：战斗图放大到非整数倍时像素仍一样大、交界处一个屏幕像素过渡。
## CRISP = false 是这一项自己的回退开关（O-待定-2）：不论设置都照旧最近邻，子页也不列。
static var CRISP := true
static func crisp_on() -> bool:
	return ENABLED and CRISP and bool(settings()["crisp"])


## 顺滑移动现在开不开。游戏逻辑按物理帧走（变速齿轮下每秒 96 步），屏幕 60 帧时一帧里有时走 1 步有时走 2 步，
## 跑步时画面一帧挪 12 像素、一帧挪 24 像素，看着一顿一顿（原版 MV 的主循环同样如此）。开着时用引擎的物理插值，
## 在两步之间按时间补位置（量过：每帧稳定挪 19 像素）。只画面补位置，逻辑、帧数、速度都不变。
## 只对登记过的节点（smooth_node，现在是地图场景）开，根节点关，别的界面不受影响。
## MOTION = false 是这一项自己的回退开关（O-待定-3）：不论设置都不补，子页也不列。
static var MOTION := true
const MOTION_GROUP := "xgraphics_motion"
static func motion_on() -> bool:
	return ENABLED and MOTION and bool(settings()["motion"])


## 登记一个要补位置的节点（连同它下面的）；之后设置改了 apply 会跟着改
static func smooth_node(node: Node) -> void:
	node.add_to_group(MOTION_GROUP)
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON if motion_on() else Node.PHYSICS_INTERPOLATION_MODE_INHERIT


## 一步挪这么远算传送（最快的移动速度 6 是每步四分之一格，差一格以上不会是走出来的）
static func is_teleport(from: Vector2, to: Vector2) -> bool:
	return absf(to.x - from.x) >= 47.0 or absf(to.y - from.y) >= 47.0


static func _apply_motion(tree: SceneTree) -> void:
	var on := motion_on()
	if on:
		tree.root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if tree.physics_interpolation != on:
		tree.physics_interpolation = on
	for node in tree.get_nodes_in_group(MOTION_GROUP):
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON if on else Node.PHYSICS_INTERPOLATION_MODE_INHERIT
		if on:
			node.reset_physics_interpolation()


## 「画面特效」现在放不放（XLobbyCorruption、XRiftAlien 用）：省电模式开着当作关
static func fx_on() -> bool:
	return XConfig.flag("codexScreenFx") and not low_power()


## 生效的帧率上限（0＝不限，跟随屏幕）
static func fps_cap(q: Dictionary = settings()) -> int:
	var f := int(q["fps"])
	if q["low"]:
		return LOW_FPS if f == 0 else mini(f, LOW_FPS)
	return f


## 窗口现在能放下的整数倍数（0＝比 1280×720 小，整数倍不可用）
static func integer_factor(win: Window) -> int:
	var base := win.content_scale_size if win.content_scale_size.x > 0 and win.content_scale_size.y > 0 else BASE
	return floori(minf(float(win.size.x) / base.x, float(win.size.y) / base.y))


## 固定窗口大小在屏幕可用区里的位置：居中，放不下就等比收小
static func window_rect(choice: String, usable: Rect2i) -> Rect2i:
	var parts := choice.split("x")
	if parts.size() != 2 or usable.size.x <= 0 or usable.size.y <= 0:
		return Rect2i()
	var dims := Vector2(int(parts[0]), int(parts[1]))
	if dims.x <= 0 or dims.y <= 0:
		return Rect2i()
	var k := minf(1.0, minf(usable.size.x / dims.x, usable.size.y / dims.y))
	var size := Vector2i((dims * k).round())
	return Rect2i(usable.position + (usable.size - size) / 2, size)


## 改一项并存盘、立刻生效；值没变返回 false
static func set_value(key: String, value: Variant) -> bool:
	var q := settings()
	if not DEFAULTS.has(key) or typeof(value) != typeof(DEFAULTS[key]) or q[key] == value:
		return false
	q[key] = value
	XConfig.set_quality(q)
	apply()
	return true


## 按当前设置把引擎状态设好。进西游模式时与每次改动后调用；tree 为空时取主循环。
static func apply(tree: SceneTree = null) -> void:
	if not ENABLED:
		return
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var q := settings()
	var root := tree.root
	XScreenScale.apply(XConfig.flag(XScreenScale.KEY) or bool(q["low"]), tree)
	if not root.size_changed.is_connected(_resized):
		root.size_changed.connect(_resized)
	_apply_integer(root, q)
	_apply_motion(tree)
	var real := DisplayServer.get_name() != "headless"
	if real or HEADLESS_APPLY:
		Engine.max_fps = fps_cap(q)
	if real and not XPlatform.is_mobile() and WindowFit.should_apply(OS.get_cmdline_args()):
		_apply_window(root, str(q["window"]))


static func _apply_integer(root: Window, q: Dictionary) -> void:
	var on: bool = q["integer"] and integer_factor(root) >= 1
	var stretch := Window.CONTENT_SCALE_STRETCH_INTEGER if on else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if root.content_scale_stretch != stretch:
		root.content_scale_stretch = stretch


static func _resized() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if ENABLED and tree != null and tree.root != null:
		_apply_integer(tree.root, settings())


static func _apply_window(root: Window, choice: String) -> void:
	if choice == _window_applied:
		return
	_window_applied = choice
	if choice == "full":
		root.mode = Window.MODE_FULLSCREEN
		return
	if root.mode != Window.MODE_WINDOWED:
		root.mode = Window.MODE_WINDOWED
	if choice == "auto":
		WindowFit.apply(root)
		return
	var rect := window_rect(choice, DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()))
	if rect.size.x > 0:
		root.size = rect.size
		root.position = rect.position
