class_name XMVCanvas
extends Control
## MV 窗口内容位图（Window_Base.contents）的画法，用于逐像素复现原版界面。
## 坐标即 MV 的 contents 坐标（窗口左上角 + 内边距）。在 painter(canvas) 回调里调用下面的画图函数。
## 参照：原版界面参照工具（03_转换工具/ui_reference）从正式版运行时读出的窗口矩形与绘制代码。
##
## 规则（MV rpg_core Bitmap.drawText / Window_Base）：
## - 文字基线 = y + 行高 - (行高 - 字号×0.7) / 2；超出 maxWidth 时横向压缩（canvas fillText 的 maxWidth）。
## - drawFace：每格 144×144，给定区域小于一格时取中间部分。
## - YEP Gauge Outline 量条：条高 6、底条半透明（160/255）、上移 1px，填充内缩 1px、宽 -2。

const OUTLINE := Color(0, 0, 0, 0.45)
const ARROW_DOWN := Rect2(132, 60, 24, 12)
const ARROW_UP := Rect2(132, 24, 24, 12)

var painter: Callable
var font: Font
var _t := 0.0
## 光标闪烁（MV Window._updateCursor：活动时每 40 帧透明度起伏）
var blink := false
## 本帧画到的纹理要一直引用到下一次重画，否则局部变量释放后 RID 失效、画成白块
var _keep: Array = []
static var _cache := {}


func _init() -> void:
	font = XUI.font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	if blink:
		_t += delta
		queue_redraw()


func _draw() -> void:
	_keep.clear()
	if painter.is_valid():
		painter.call(self)


func text_width(s: String, size := XUI.FONT_SIZE) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Window_Base.drawText(text, x, y, maxWidth, align)，行高 lh。
func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0) -> void:
	if s == "":
		return
	var w := text_width(s, size)
	var sx := 1.0
	if max_w > 0 and w > max_w:
		sx = max_w / w
	var dw := w * sx
	var tx := x
	if align == "center":
		tx = x + (max_w - dw) / 2.0
	elif align == "right":
		tx = x + max_w - dw
	var base := y + lh - (lh - size * 0.7) / 2.0
	var c := Color(color, color.a * alpha)
	draw_set_transform(Vector2(roundf(tx), roundf(base)), 0.0, Vector2(sx, 1.0))
	draw_string_outline(font, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 1, Color(OUTLINE, OUTLINE.a * alpha))
	draw_string(font, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
	draw_set_transform(Vector2.ZERO)


func icon(index: int, x: float, y: float, alpha := 1.0) -> void:
	var t := XUI.icon_texture(index)
	if t:
		_keep.append(t)
		draw_texture(t, Vector2(x, y), Color(1, 1, 1, alpha))


## Window_Base.drawFace(faceName, faceIndex, x, y, width, height)
func face(face_name: String, index: int, x: float, y: float, w := 144.0, h := 144.0, alpha := 1.0) -> void:
	var p := XDB.img_path("faces", face_name) if face_name != "" else ""
	if p == "":
		return
	if not _cache.has(p):
		_cache[p] = load(p)
	var tex: Texture2D = _cache[p]
	var pw := 144.0
	var ph := 144.0
	var sw := minf(w, pw)
	var sh := minf(h, ph)
	var dx := floorf(x + maxf(w - pw, 0) / 2.0)
	var dy := floorf(y + maxf(h - ph, 0) / 2.0)
	var sx := (index % 4) * pw + (pw - sw) / 2.0
	var sy := floorf(index / 4.0) * ph + (ph - sh) / 2.0
	draw_texture_rect_region(tex, Rect2(dx, dy, sw, sh), Rect2(sx, sy, sw, sh), Color(1, 1, 1, alpha))


## YEP_CoreEngine drawGauge（Gauge Outline 开启）
func gauge(dx: float, dy: float, dw: float, rate: float, c1: Color, c2: Color, lh := XUI.LINE_HEIGHT) -> void:
	var gh := 6.0
	var gy := dy + lh - gh - 2.0
	draw_rect(Rect2(dx, gy - 1.0, dw, gh), Color(XUI.GAUGE_BACK, 160.0 / 255.0))
	var fw := maxf(floorf(dw * clampf(rate, 0.0, 1.0)) - 2.0, 0.0)
	if fw > 0.0:
		gradient(Rect2(dx + 1.0, gy, fw, gh - 2.0), c1, c2)


func gradient(r: Rect2, c1: Color, c2: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c1, c2, c2, c1]))


## 选中光标（Window.png 光标框）；blink 时按 MV 活动窗口的 40 帧周期变淡。
func cursor(r: Rect2, active := true) -> void:
	var a := 1.0
	if active and blink:
		var n := int(_t * 60.0) % 40
		a = 1.0 - (n if n < 20 else 40 - n) * 8.0 / 255.0
	draw_style_box(XUI.cursor_style(a), r)


## MV Window 的上下滚动箭头（皮肤 Window.png），x 为窗口宽的一半，坐标相对窗口左上。
static func arrows(win: Control, up: bool, down: bool) -> void:
	var sk := XUI.skin()
	if sk == null:
		return
	var w := win.size.x
	if up:
		win.draw_texture_rect_region(sk, Rect2(w / 2.0 - 12, 6, 24, 12), ARROW_UP)
	if down:
		win.draw_texture_rect_region(sk, Rect2(w / 2.0 - 12, win.size.y - 12 - 6, 24, 12), ARROW_DOWN)
