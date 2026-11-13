class_name XScreenScale
extends RefCounted
## 画面平滑（玩家反馈 v0.01「画面锐化太高」，O-340）。
## 原版 MV 先把整幅画面画在 1280×720 的画布上，再由浏览器把画布双线性放大到窗口（安卓 WebView、全屏、Retina 都是），
## 所以放大后整体偏柔；人物、战斗图在画布里按 CrispScaling 最近邻。重制原先用 canvas_items：每张图直接按屏幕分辨率画，
## 战斗图最近邻放大 1.5、2.25 这类非整数倍，像素宽窄不一，看着发硬发锐。
## 开着「画面平滑」时根窗口改用 viewport 缩放：先画 1280×720，再整幅双线性放大到屏幕，与原版观感一致（安卓上还少画像素）。
## 关掉回到 canvas_items（文字、图标按屏幕分辨率画，最清晰）。
## 默认：各平台都关（玩家反馈 v0.01.06「画质变低」，O-待定）。dev497 起触屏默认开，手机屏多是 2400×1080 这类，
## 1280×720 整幅放大 1.5 倍后文字、图标发糊；现在照 v0.01 默认清晰，想要柔和的在设置页「画面平滑」自己开，存配置。
## 回退：ENABLED = false 时不论设置都用 canvas_items、设置页也不列这一项。
## 回退：TOUCH_DEFAULT_ON = true 回到 dev497（触屏默认开；配置里存过的值不论是不是玩家自己选的都认）。

static var ENABLED := true
## O-待定：true＝dev497 的默认（触屏开、桌面关）；false＝各平台默认关，且只认玩家在设置页亲手选过的值
static var TOUCH_DEFAULT_ON := false
## 配置键（XConfig）；没存过时按 default_on()
const KEY := "codexScreenSmooth"
## 玩家在设置页亲手改过「画面平滑」的记号（XConfig 原样存读）。dev497～ 的配置会把触屏默认的 true 连同别的设置一起写进文件，
## 没有这个记号就分不清是玩家选的还是默认写进去的，所以没记号的一律当没选过、按 default_on()
const CHOSEN_KEY := "codexScreenSmoothChosen"


## 没存过设置时的默认值：都关（TOUCH_DEFAULT_ON 时触屏开、桌面关）
static func default_on() -> bool:
	return TOUCH_DEFAULT_ON and XPlatform.is_touch()


## 读配置文件里的「画面平滑」：玩家亲手选过（有 CHOSEN_KEY）才认存的值，否则按 default_on()
static func saved_value(data: Dictionary) -> bool:
	if data.get(KEY) is bool and (TOUCH_DEFAULT_ON or data.get(CHOSEN_KEY) == true):
		return data[KEY]
	return default_on()


## 现在该不该平滑（开关关掉恒为否）
static func wanted(smooth: bool) -> bool:
	return ENABLED and smooth


## 把根窗口切到对应的缩放方式；返回切完的模式。tree 为空时取主循环。
static func apply(smooth: bool, tree: SceneTree = null) -> int:
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return -1
	var mode := Window.CONTENT_SCALE_MODE_VIEWPORT if wanted(smooth) else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if tree.root.content_scale_mode != mode:
		tree.root.content_scale_mode = mode
	return mode


## 屏幕像素 → 画面坐标（1280×720）的变换。canvas_items 时就是根视口的最终变换；viewport 缩放时最终变换是单位阵，
## 放大和黑边在贴到窗口时才做，这里按 keep 比例自己算（与 Godot 的 attach_to_screen_rect 一致）。
static func screen_to_view(viewport: Viewport) -> Transform2D:
	var win := viewport as Window
	if win == null or win.content_scale_mode != Window.CONTENT_SCALE_MODE_VIEWPORT:
		return viewport.get_final_transform().affine_inverse()
	var ws := Vector2(win.size)
	var vs := viewport.get_visible_rect().size
	if ws.x <= 0 or ws.y <= 0 or vs.x <= 0 or vs.y <= 0:
		return Transform2D()
	var k := minf(ws.x / vs.x, ws.y / vs.y)
	var off := (ws - vs * k) / 2.0
	return Transform2D(0.0, Vector2(k, k), 0.0, off).affine_inverse()
