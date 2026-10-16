class_name XChoiceWindow
extends Control
## Codex 原生选择窗（installNativeYunshangRuntime 的 Window_YunChoices／CodexYunshang.choose；宝珠坊、天衣铺等共用）。
## 正式 v0.28 运行时读数（宝珠坊，见 tests/fixtures/orb_shop_ui_oracle.json）：宽 760，高 ＝ fittingHeight(行数限 3～12)＋说明高
## （说明 n 行时 n×36＋12），最多 720，居中；内边距 14。说明行：第 1 行系统色，第 1、2 行不透明、其余半透明，
## 下方 y＝n×36＋5 画 2px 分隔线（normalColor，不透明度 72）。选项行从说明下方起，文字 x 6、宽 720；不可选的半透明，
## 确定蜂鸣。选项比可见行多时滚动（maxPageRows ＝ (高−28−说明高)/36）。确定后窗口先隐藏，再交给回调（回调多半再打开下一页）。

const WIDTH := 760.0
const LH := 36.0
const SEPARATOR_ALPHA := 72.0 / 255.0

var win: XMVWindow
var rows: Array = []
var info: Array = []
var index := 0
var top := 0
var _ok: Callable
var _cancel: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	win = XMVWindow.make(self, Rect2(0, 0, WIDTH, 100), XUI.MENU_WINDOW_OPACITY, _paint)
	win.canvas.blink = true
	visible = false


func info_height() -> float:
	return info.size() * LH + 12.0 if not info.is_empty() else 0.0


func window_height() -> float:
	var n := mini(12, maxi(3, rows.size()))
	return minf(720.0, n * LH + XMVWindow.PADDING * 2 + info_height())


func page_rows() -> int:
	return maxi(1, floori((win.size.y - XMVWindow.PADDING * 2 - info_height()) / LH))


## openRows：换行与说明，居中，选第一行
func open(list: Array, ok: Callable, cancel: Callable, lines := []) -> void:
	rows = list
	info = lines
	_ok = ok
	_cancel = cancel
	var h := window_height()
	win.size = Vector2(WIDTH, h)
	win.position = Vector2(floorf((1280.0 - WIDTH) / 2.0), floorf((720.0 - h) / 2.0))
	index = 0
	top = 0
	visible = true
	_refresh()


func _refresh() -> void:
	win.up_arrow = top > 0
	win.down_arrow = top + page_rows() < rows.size()
	win.refresh()


func _paint(c: XMVCanvas) -> void:
	var w := c.size.x
	for i in range(info.size()):
		c.text(str(info[i]), 0, i * LH, w, "left", XUI.SYSTEM if i == 0 else XUI.TEXT, XUI.FONT_SIZE, LH, 1.0 if i < 2 else XUI.DIM.a)
	if not info.is_empty():
		c.draw_rect(Rect2(0, info.size() * LH + 5, w, 2), Color(XUI.TEXT, SEPARATOR_ALPHA))
	var y0 := info_height()
	for i in range(top, mini(rows.size(), top + page_rows())):
		var y := y0 + (i - top) * LH
		if i == index:
			c.cursor(Rect2(0, y, w, LH))
		c.text(str(rows[i].get("label", "")), 6, y, w - 12, "left", XUI.TEXT, XUI.FONT_SIZE, LH, 1.0 if rows[i].get("enabled", true) != false else XUI.DIM.a)


func move(d: int, wrap := true) -> void:
	if rows.is_empty():
		return
	var old := index
	index = XMenu._move(index, d, rows.size(), wrap)
	top = XMenu._scroll_to(index, top, page_rows())
	if index != old:
		XSound.system(0)
	_refresh()


func ok() -> void:
	if index < 0 or index >= rows.size():
		return
	var r: Dictionary = rows[index]
	if r.get("enabled", true) == false:
		XSound.system(3)
		return
	XSound.system(1)
	visible = false
	_ok.call(r)


func cancel() -> void:
	XSound.system(2)
	visible = false
	if _cancel.is_valid():
		_cancel.call()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	if event.is_action_pressed("ui_cancel"):
		cancel()
	elif event.is_action_pressed("ui_accept"):
		ok()
	elif event.is_action_pressed("ui_down", true):
		move(1, not event.is_echo())
	elif event.is_action_pressed("ui_up", true):
		move(-1, not event.is_echo())
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			top = clampi(top + d, 0, maxi(0, rows.size() - page_rows()))
			_refresh()
		MOUSE_BUTTON_LEFT:
			var p: Vector2 = event.position - win.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING + info_height())
			if not Rect2(Vector2.ZERO, win.size).has_point(event.position - win.position) or p.y < 0:
				return
			var i := top + floori(p.y / LH)
			if i >= 0 and i < rows.size():
				if i == index:
					ok()
				else:
					index = i
					_refresh()
