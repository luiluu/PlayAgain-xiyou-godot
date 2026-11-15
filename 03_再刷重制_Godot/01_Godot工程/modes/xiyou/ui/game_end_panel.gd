class_name XGameEndPanel
extends Control
## MV Scene_GameEnd：背景不透明度 128（底图变暗），指令窗 (520,310,240,100) 左对齐「回到标题 / 取消」。
## 参照截图 04_验证/本地结果/原版参照/14_game_end.png。
## 系统音（ui14，原来无声）：Window_Command 换行光标音、确定音、取消音（右键同取消）。

signal closed
signal to_title

const RECT := Rect2(520, 310, 240, 100)
const LH := 36.0
var _index := 0
var _win: XMVWindow
## 新界面（5C）：叫法改「返回标题」；视口比 16:9 宽时窗口居中（旧界面坐标按 1280 摆）
var _skin := false
var _holder: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 1.0 - 128.0 / 255.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_skin = XUiSkin.on()
	_holder = Control.new()
	_holder.name = "Holder"
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.size = Vector2(1280, 720)
	add_child(_holder)
	_win = XMVWindow.make(_holder, RECT, XUI.MENU_WINDOW_OPACITY, _paint)
	_win.canvas.blink = true
	_place()
	get_viewport().size_changed.connect(_place)


func _offset() -> Vector2:
	return Vector2(maxf(roundf((get_viewport_rect().size.x - 1280.0) / 2.0), 0.0), 0) if _skin else Vector2.ZERO


func _place() -> void:
	_holder.position = _offset()


func _paint(c: XMVCanvas) -> void:
	var items := ["返回标题" if _skin else "回到标题", "取消"]
	for i in range(items.size()):
		if i == _index:
			c.cursor(Rect2(0, i * LH, c.size.x, LH))
		c.text(items[i], 6, i * LH, c.size.x - 12, "left", XUI.TEXT, XUI.FONT_SIZE, LH)


func _choose() -> void:
	XSound.system(1)
	if _index == 0:
		to_title.emit()
	else:
		closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			XSound.system(2)
			closed.emit()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var p: Vector2 = event.position - _offset() - RECT.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			var i := floori(p.y / LH)
			if RECT.has_point(event.position - _offset()) and i >= 0 and i < 2:
				if i == _index:
					_choose()
				else:
					_index = i
					XSound.system(0)
					_win.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		XSound.system(2)
		closed.emit()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		_choose()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		XKeyMap.handled(self)
		_index = 1 - _index
		XSound.system(0)
		_win.refresh()
