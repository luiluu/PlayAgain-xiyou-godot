class_name XPingbiScene
extends Control
## 设置「屏蔽掉落」：SiShiTan-PingBi-fix2 的 Scene_PingbiMenu（行由 installUnifiedQualityRuntime 改为七档），
## 按正式 v0.21 运行时复现（参照 原版参照/claude_pingbi_00、claude_pingbi_01_toggled）。
## - 背景同主菜单，Window_PingbiCommands 宽 240、高按行数（5 行 208），画面居中 (520,256)；不透明度 30。
## - 行「屏蔽X装备 关/开/部分」左对齐在 (6, 宽 200)，行高 36。规则见 XPingbi。
## - 确定：确定音，整档切换（全关→全开，否则全关）；上下首按循环、换行光标音；左右无作用；取消音返回设置。
##   点非当前行＝选中，点当前行＝确定（原版场景在光标停在第一项时对任意点击另做一次切换，未照搬，见 O-025）。

signal closed

const W := 240.0
const LH := 36.0

var index := 0
var win: XMVWindow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	win = XMVWindow.make(self, rect(), XUI.MENU_WINDOW_OPACITY, _paint)
	win.canvas.blink = true


func rows() -> Array:
	return XPingbi.rows(XState.current)


## Window_Command 高 = 行数×36＋内边距 14×2，Scene 居中
func rect() -> Rect2:
	var h := rows().size() * LH + XMVWindow.PADDING * 2
	return Rect2((1280.0 - W) / 2.0, (720.0 - h) / 2.0, W, h)


func _paint(c: XMVCanvas) -> void:
	var list := rows()
	for i in list.size():
		var y := i * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		c.text(list[i][1], 6, y, c.size.x - 12)


func select(i: int) -> void:
	if i == index:
		return
	index = i
	XSound.system(0)
	win.refresh()


func ok() -> void:
	XSound.system(1)
	XPingbi.toggle(XState.current, int(rows()[index][0]))
	win.refresh()


func cancel() -> void:
	XSound.system(2)
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_LEFT:
			var r := rect()
			var p: Vector2 = event.position - r.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			if not r.has_point(event.position) or p.y < 0:
				return
			var i := floori(p.y / LH)
			if i >= rows().size():
				return
			if i == index:
				ok()
			else:
				select(i)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		var d := 1 if event.is_action_pressed("ui_down", true) else -1
		select(XMenu._move(index, d, rows().size(), not event.is_echo()))
	elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true):
		get_viewport().set_input_as_handled()
