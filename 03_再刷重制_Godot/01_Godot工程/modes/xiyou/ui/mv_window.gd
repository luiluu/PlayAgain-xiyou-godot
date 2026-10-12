class_name XMVWindow
extends Control
## 一个 MV 窗口：Window.png 皮肤画在自身矩形上，内容画在内边距 14 以内的 XMVCanvas（canvas）里。
## 矩形用正式版运行时读出的 x/y/宽/高（1280×720 画布坐标）。

const PADDING := 14.0

var canvas: XMVCanvas
var opacity := 255
var up_arrow := false
var down_arrow := false


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


func _ready() -> void:
	_layout()


func _draw() -> void:
	draw_style_box(XUI.panel(opacity), Rect2(Vector2.ZERO, size))
	XMVCanvas.arrows(self, up_arrow, down_arrow)


func refresh() -> void:
	queue_redraw()
	canvas.queue_redraw()
