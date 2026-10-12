class_name XGameEndPanel
extends Control
## MV Scene_GameEnd：背景不透明度 128（底图变暗），指令窗 (520,310,240,100) 左对齐「回到标题 / 取消」。
## 参照截图 04_验证/本地结果/原版参照/14_game_end.png。

signal closed
signal to_title

const RECT := Rect2(520, 310, 240, 100)
const LH := 36.0
var _index := 0
var _win: XMVWindow


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 1.0 - 128.0 / 255.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_win = XMVWindow.make(self, RECT, XUI.MENU_WINDOW_OPACITY, _paint)
	_win.canvas.blink = true


func _paint(c: XMVCanvas) -> void:
	var items := ["回到标题", "取消"]
	for i in range(items.size()):
		if i == _index:
			c.cursor(Rect2(0, i * LH, c.size.x, LH))
		c.text(items[i], 6, i * LH, c.size.x - 12, "left", XUI.TEXT, XUI.FONT_SIZE, LH)


func _choose() -> void:
	if _index == 0:
		to_title.emit()
	else:
		closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			closed.emit()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var p: Vector2 = event.position - RECT.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			var i := floori(p.y / LH)
			if RECT.has_point(event.position) and i >= 0 and i < 2:
				if i == _index:
					_choose()
				else:
					_index = i
					_win.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_choose()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_index = 1 - _index
		_win.refresh()
