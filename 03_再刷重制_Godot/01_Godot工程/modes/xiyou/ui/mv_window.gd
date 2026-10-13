class_name XMVWindow
extends Control
## 一个 MV 窗口：Window.png 皮肤画在自身矩形上，内容画在内边距 14 以内的 XMVCanvas（canvas）里。
## 矩形用正式版运行时读出的 x/y/宽/高（1280×720 画布坐标）。
## 另照 MV Window / Window_Base：
## - openness 0～255：皮肤纵向缩放（以窗口中线为轴），完全打开前不显示内容；open()/close() 每帧 ±32（60 帧/秒）。
## - background_type：0 窗口、1 暗底（dimmer：上下内边距处渐隐的黑 0.6，透明度随 openness）、2 透明。
## - pause：右下角改为底边中间的翻页标记（Window.png (144,96) 2×2 帧、每 16 帧换一帧、出现时每帧 +0.1 透明度）。

const PADDING := 14.0
const PAUSE_SRC := Vector2(144, 96)

var canvas: XMVCanvas
var opacity := 255
var up_arrow := false
var down_arrow := false
var openness := 255:
	set(v):
		openness = clampi(v, 0, 255)
		if canvas:
			canvas.visible = openness >= 255
		queue_redraw()
var background_type := 0:
	set(v):
		background_type = v
		queue_redraw()
var pause := false
var _opening := false
var _closing := false
var _anim := 0
var _pause_alpha := 0.0


static func make(parent: Control, rect: Rect2, window_opacity := 255, painter := Callable()) -> XMVWindow:
	var w := XMVWindow.new()
	w.position = rect.position
	w.size = rect.size
	w.opacity = window_opacity
	parent.add_child(w)
	w.canvas.painter = painter
	return w


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = XMVCanvas.new()
	add_child(canvas)
	resized.connect(_layout)


func _layout() -> void:
	canvas.position = Vector2(PADDING, PADDING)
	canvas.size = size - Vector2(PADDING, PADDING) * 2.0
	queue_redraw()


func _ready() -> void:
	_layout()


func set_rect(r: Rect2) -> void:
	position = r.position
	size = r.size


func open() -> void:
	if not is_open():
		_opening = true
	_closing = false


func close() -> void:
	if not is_closed():
		_closing = true
	_opening = false


func is_open() -> bool:
	return openness >= 255


func is_closed() -> bool:
	return openness <= 0


func is_opening() -> bool:
	return _opening


func is_closing() -> bool:
	return _closing


## MV Window_Base.update（updateOpen/updateClose）＋ Window.update（_animationCount），每帧一次。
func _physics_process(_delta: float) -> void:
	if _opening:
		openness += 32
		if is_open():
			_opening = false
	elif _closing:
		openness -= 32
		if is_closed():
			_closing = false
	_anim += 1
	if pause:
		_pause_alpha = minf(_pause_alpha + 0.1, 1.0)
	else:
		_pause_alpha = 0.0
	if pause or _pause_alpha > 0.0 or _opening or _closing:
		queue_redraw()


func _draw() -> void:
	if openness <= 0:
		return
	var r := Rect2(Vector2.ZERO, size)
	var o := openness / 255.0
	if background_type == 1:
		_draw_dimmer(o)
	elif background_type == 0:
		draw_set_transform(Vector2(0, size.y / 2.0 * (1.0 - o)), 0.0, Vector2(1, o))
		draw_style_box(XUI.panel(opacity), r)
		draw_set_transform(Vector2.ZERO)
	if not is_open():
		return
	XMVCanvas.arrows(self, up_arrow, down_arrow)
	if pause and XUI.skin():
		var fx := floori(_anim / 16.0) % 2
		var fy := floori(_anim / 32.0) % 2
		draw_texture_rect_region(XUI.skin(), Rect2(size.x / 2.0 - 12, size.y - 24, 24, 24),
			Rect2(PAUSE_SRC + Vector2(fx * 24, fy * 24), Vector2(24, 24)), Color(1, 1, 1, _pause_alpha))


## Window_Base.refreshDimmerBitmap：上下各一个内边距高的渐变，中间 rgba(0,0,0,0.6)；opacity = openness。
func _draw_dimmer(o: float) -> void:
	var c1 := Color(0, 0, 0, 0.6 * o)
	var c2 := Color(0, 0, 0, 0)
	var m := PADDING
	var w := size.x
	var h := size.y
	_vgrad(Rect2(0, 0, w, m), c2, c1)
	draw_rect(Rect2(0, m, w, h - m * 2), c1)
	_vgrad(Rect2(0, h - m, w, m), c1, c2)


func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func refresh() -> void:
	queue_redraw()
	canvas.queue_redraw()
