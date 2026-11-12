class_name XScreenScale
extends RefCounted
## 画面平滑（玩家反馈 v0.01「画面锐化太高」，O-340）。
## 原版 MV 先把整幅画面画在 1280×720 的画布上，再由浏览器把画布双线性放大到窗口（安卓 WebView、全屏、Retina 都是），
## 所以放大后整体偏柔；人物、战斗图在画布里按 CrispScaling 最近邻。重制原先用 canvas_items：每张图直接按屏幕分辨率画，
## 战斗图最近邻放大 1.5、2.25 这类非整数倍，像素宽窄不一，看着发硬发锐。
## 开着「画面平滑」时根窗口改用 viewport 缩放：先画 1280×720，再整幅双线性放大到屏幕，与原版观感一致（安卓上还少画像素）。
## 关掉回到 canvas_items（文字、图标按屏幕分辨率画，最清晰）。
## 默认：触屏（安卓）开、桌面关（桌面窗口多是 1:1 或 Retina 2 倍，原先已按物理像素处理过清晰度）。设置页「画面平滑」可改，存配置。
## 回退：ENABLED = false 时不论设置都用 canvas_items、设置页也不列这一项。

static var ENABLED := true
## 配置键（XConfig）；没存过时按 default_on()
const KEY := "codexScreenSmooth"


## 没存过设置时的默认值：触屏开、桌面关
static func default_on() -> bool:
	return XPlatform.is_touch()


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
