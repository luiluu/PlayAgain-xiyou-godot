class_name XSkinLayout
extends Control
## 【cc·天启篇·未经审查】横屏铺满骨架（界面风格提案 v0.7 第二节「横屏铺满」四条）：
## 1. 三块锚点：左块贴左、右块贴右，中间块跟着变宽；中间块最宽 720（XUiSkin.CENTER_MAX），再宽就在左右块之间居中、两边留空。
## 2. 安全边距：比 16:9 宽的屏左右各留 56（刘海、圆角、手握），界面的东西不进去；背景铺满到边（背景不放在这三块里）。
##    16:9（1280 宽）就是样稿的 24；宽度每多 2 像素边距多 1，到 1344 宽起就是 56，不会一过 16:9 就跳。
## 3. 虚拟按键只在地图上（这里不管）。
## 4. 比 16:9 窄的屏（4:3 平板）上下留边、不重排：request_wide 按窗口比例选拉伸方式——窄屏 KEEP（视口 1280×720、上下黑边），宽屏 KEEP_HEIGHT（p1fix 改；原来一律 KEEP_HEIGHT，4:3 被压成 960 宽）。
## 各期页面怎么摆留给后面：这里只给三块容器（left／center／right，子节点放进去即可）和算矩形的规则（compute，纯函数，测试直接调）。
##
## 视口要比 1280 宽，宽屏窗口得用 KEEP_HEIGHT 横向扩展；窄屏用 KEEP 上下留黑边（KEEP_HEIGHT 在窄屏会把视口压窄）。旧页面都按 1280×720 摆，
## 所以不全局改，由按新稿排好的页面在自己进树时 request_wide、离开时自动还原（计数，嵌套页面也对）。

var left_w := 416.0
var right_w := 360.0
var gap := float(XUiSkin.PANEL_GAP)
var top := float(XUiSkin.TOP)
var bottom_margin := 720.0 - XUiSkin.BOTTOM
var left: Control
var center: Control
var right: Control
## 测试可钉住视口大小（Vector2.ZERO＝用真实视口）
var view_override := Vector2.ZERO

static var _wide_users := 0
static var _saved_aspect := -1


func _init() -> void:
	name = "SkinLayout"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	left = _block("Left")
	center = _block("Center")
	right = _block("Right")


func _block(n: String) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(relayout)
	get_viewport().size_changed.connect(relayout)
	relayout()


## 左右边距：16:9 的 24 到宽屏的 56（宽度每多 2 像素多 1）
static func margin_for(width: float) -> float:
	return clampf(XUiSkin.EDGE + (width - 1280.0) / 2.0, XUiSkin.EDGE, XUiSkin.SAFE_X)


## 三块的矩形（视口坐标）：{margin, safe, left, center, right}
static func compute(view: Vector2, lw := 416.0, rw := 360.0, g := 16.0, t := 72.0, bm := 52.0) -> Dictionary:
	var m := margin_for(view.x)
	var h := view.y - bm - t
	var l := Rect2(m, t, lw, h)
	var r := Rect2(view.x - m - rw, t, rw, h)
	var x0 := l.end.x + g
	var x1 := r.position.x - g
	var cw := clampf(x1 - x0, 0.0, XUiSkin.CENTER_MAX)
	var c := Rect2(roundf((x0 + x1) / 2.0 - cw / 2.0), t, cw, h)
	return {"margin": m, "safe": Rect2(m, 0, view.x - m * 2.0, view.y), "left": l, "center": c, "right": r}


func view_size() -> Vector2:
	if view_override != Vector2.ZERO:
		return view_override
	return get_viewport_rect().size if is_inside_tree() else size   # 离树途中（拉伸方式还原触发的重排）不报错


func rects() -> Dictionary:
	return compute(view_size(), left_w, right_w, gap, top, bottom_margin)


func relayout() -> void:
	var d := rects()
	for pair in [[left, d.left], [center, d.center], [right, d.right]]:
		(pair[0] as Control).position = (pair[1] as Rect2).position
		(pair[0] as Control).size = (pair[1] as Rect2).size


## ---- 窗口拉伸方式：按新稿排好的页面进树时调 request_wide(self) ----
## 窄屏留边（cc/ui-skin-p1fix，小A审 v0.7 P1-2）：原来一律 KEEP_HEIGHT，4:3 平板上视口被压成 960 宽、三栏挤烂（写反了）。
## true（默认）：窗口比 16:9 宽才 KEEP_HEIGHT 横向铺满，16:9 及更窄用 KEEP（视口锁 1280×720、上下留黑边、不重排）；窗口改大小时跟着换。
## false：回到原来一律 KEEP_HEIGHT（可回退）。
static var NARROW_LETTERBOX := true
const WIDE_RATIO := 16.0 / 9.0


## 窗口大小 → 拉伸方式（纯函数，测试直接调）
static func aspect_for(win: Vector2) -> Window.ContentScaleAspect:
	if not NARROW_LETTERBOX:
		return Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
	if win.y <= 0.0 or win.x / win.y > WIDE_RATIO + 0.001:
		return Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
	return Window.CONTENT_SCALE_ASPECT_KEEP


## 某个窗口大小下视口多大（纯函数；画面设计 1280×720）
static func view_for(win: Vector2) -> Vector2:
	if win.y <= 0.0 or win.x <= 0.0:
		return Vector2(1280, 720)
	if aspect_for(win) == Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT:
		return Vector2(roundf(720.0 * win.x / win.y), 720)
	return Vector2(1280, 720)


## node 在树里期间视口按窗口比例换拉伸方式（比 16:9 宽的横向铺满、窄的上下留边）；node 离开树时自动还原。新皮肤关着时什么都不做。
static func request_wide(node: Node) -> void:
	if not XUiSkin.on() or node == null or not node.is_inside_tree():
		return
	var root := node.get_tree().root
	if _wide_users == 0:
		_saved_aspect = root.content_scale_aspect
		_wide_cb = _apply_wide.bind(root)
		if not root.size_changed.is_connected(_wide_cb):
			root.size_changed.connect(_wide_cb)
	_wide_users += 1
	_apply_wide(root)
	node.tree_exiting.connect(func(): _release_wide(root), CONNECT_ONE_SHOT)


static var _wide_cb := Callable()
## 测试可钉住窗口大小（Vector2.ZERO＝用真实窗口）
static var window_override := Vector2.ZERO


static func _apply_wide(root: Window) -> void:
	if _wide_users <= 0 or not is_instance_valid(root):
		return
	var win := window_override if window_override != Vector2.ZERO else Vector2(root.size)
	var want := aspect_for(win)
	if root.content_scale_aspect != want:
		root.content_scale_aspect = want


static func _release_wide(root: Window) -> void:
	_wide_users = maxi(_wide_users - 1, 0)
	if _wide_users == 0 and _saved_aspect >= 0 and is_instance_valid(root):
		if _wide_cb.is_valid() and root.size_changed.is_connected(_wide_cb):
			root.size_changed.disconnect(_wide_cb)
		_wide_cb = Callable()
		root.content_scale_aspect = _saved_aspect as Window.ContentScaleAspect
		_saved_aspect = -1


static func wide_active() -> bool:
	return _wide_users > 0
