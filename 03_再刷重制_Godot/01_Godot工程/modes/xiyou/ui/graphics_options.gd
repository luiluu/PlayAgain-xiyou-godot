class_name XGraphicsOptionsScene
extends Control
## 设置「画质设置」子页（重制新增，XGraphics；设计见 00_设计/画质设置.md）。样式照「消息提醒」子页（XNoticeOptionsScene）：
## - 标题窗 (260,24,760,104)：标题字号 24、说明字号 18。
## - 列表 (260,140,760,行数×36＋36)：名字宽 170、说明 systemColor 字号 20、状态右对齐宽 150。
## - 确定：确定音，换到下一档（开关取反）；左右：开关右开左关，多档的左右各走一档、到头不动；值变了才存并播光标音。
##   上下首按循环；点非当前行＝选中，点当前行＝确定；取消播取消音返回设置。每次改动即存盘并生效。
## - 「窗口大小」只在桌面列出。

signal closed

const HEAD_RECT := Rect2(260, 24, 760, 104)
const LIST_POS := Vector2(260, 140)
const LIST_W := 760.0
const LH := 36.0
const NAME_W := 170.0
const STATUS_W := 150.0
const HINT_SIZE := 20
const ON_COLOR := Color("a9dfb7")
const OFF_COLOR := Color("c0c0c0")
const TITLE := "画质设置"
const NOTE := "默认都不改动画面。改了立刻生效并保存；想恢复就全部调回最左边一档。"
## [键, 名字, 说明]
const ROWS := [["integer", "整数倍缩放", "画面只放大整数倍，像素均匀，四周留黑边"],
	["fps", "帧率上限", "降低可省电、少发热；游戏速度不变"],
	["window", "窗口大小", "自动＝按屏幕大小；也可用 F11 切全屏"],
	["low", "省电模式", "低配手机用：30 帧、柔和放大、关画面特效"]]
const WINDOW_NAMES := {"auto": "自动", "1280x720": "1280×720", "1600x900": "1600×900", "1920x1080": "1920×1080", "full": "全屏"}

var index := 0
var head_win: XMVWindow
var list_win: XMVWindow
var _rows: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rows = rows()
	XUI.menu_background(self)
	head_win = XMVWindow.make(self, HEAD_RECT, XUI.MENU_WINDOW_OPACITY, _paint_head)
	list_win = XMVWindow.make(self, list_rect(), XUI.MENU_WINDOW_OPACITY, _paint_list)
	list_win.canvas.blink = true


## 本平台列出的行（窗口大小只在桌面）
static func rows() -> Array:
	return ROWS.filter(func(r): return r[0] != "window" or not XPlatform.is_mobile())


func list_rect() -> Rect2:
	return Rect2(LIST_POS, Vector2(LIST_W, _rows.size() * LH + XMVWindow.PADDING * 2))


func keys() -> Array:
	return _rows.map(func(r): return r[0])


## 某一项可选的各档（默认档在最前）
static func choices(key: String) -> Array:
	match key:
		"fps":
			return XGraphics.FPS_CHOICES
		"window":
			return XGraphics.WINDOW_CHOICES
	return [false, true]


func status_text(i: int) -> String:
	var key: String = _rows[i][0]
	var v = XGraphics.settings()[key]
	match key:
		"integer":
			if not v:
				return "关"
			var n := XGraphics.integer_factor(get_tree().root) if is_inside_tree() else 1
			return "开（%d倍）" % n if n >= 1 else "开（屏幕太小）"
		"fps":
			return "跟随屏幕" if int(v) == 0 else "%d 帧" % int(v)
		"window":
			return str(WINDOW_NAMES.get(v, v))
	return "开" if v else "关"


func _is_default(i: int) -> bool:
	var key: String = _rows[i][0]
	return XGraphics.settings()[key] == XGraphics.DEFAULTS[key]


func _paint_head(c: XMVCanvas) -> void:
	c.text(TITLE, 0, 0, c.size.x, "left", XUI.TEXT, 24)
	c.text(NOTE, 0, 36, c.size.x, "left", XUI.TEXT, 18)


func _paint_list(c: XMVCanvas) -> void:
	var w := c.size.x - 12.0
	for i in _rows.size():
		var row: Array = _rows[i]
		var y := i * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		c.text(row[1], 6, y, NAME_W)
		c.text(row[2], 6 + NAME_W, y, w - NAME_W - STATUS_W, "left", XUI.SYSTEM, HINT_SIZE)
		c.text(status_text(i), 6 + w - STATUS_W, y, STATUS_W, "right", OFF_COLOR if _is_default(i) else ON_COLOR)


func _refresh() -> void:
	list_win.refresh()


func select(i: int) -> void:
	if i == index:
		return
	index = i
	XSound.system(0)
	_refresh()


## 把当前行设成第 n 档；值变了才存、播光标音
func _set_choice(n: int) -> void:
	var key: String = _rows[index][0]
	var list := choices(key)
	if XGraphics.set_value(key, list[clampi(n, 0, list.size() - 1)]):
		XSound.system(0)
		_refresh()


func _current() -> int:
	var key: String = _rows[index][0]
	return maxi(0, choices(key).find(XGraphics.settings()[key]))


## 确定：换到下一档，过了最后一档回到第一档
func ok() -> void:
	XSound.system(1)
	_set_choice((_current() + 1) % choices(_rows[index][0]).size())


## 左右：各走一档，到头不动
func side(right: bool) -> void:
	_set_choice(_current() + (1 if right else -1))


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
			var rect := list_rect()
			var p: Vector2 = event.position - rect.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			if not rect.has_point(event.position) or p.y < 0:
				return
			var i := floori(p.y / LH)
			if i >= _rows.size():
				return
			if i == index:
				ok()
			else:
				select(i)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		XKeyMap.handled(self)
		cancel()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		XKeyMap.handled(self)
		var d := 1 if event.is_action_pressed("ui_down", true) else -1
		select(XMenu._move(index, d, _rows.size(), not event.is_echo()))
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		XKeyMap.handled(self)
		side(event.is_action_pressed("ui_right", true))
