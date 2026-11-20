class_name XNoticeOptionsScene
extends Control
## 设置「消息提醒」：installV019UsabilityRuntime 的 Scene_CodexNotices，按正式 v0.21 运行时复现
## （参照 原版参照/claude_notices_01_page、claude_notices_02_off；测量见 mv_oracle/options_probe 的 notices）。
## - 背景同主菜单（Scene_MenuBase＋MOG 底图），窗口不透明度 30。
## - 标题窗 (260,24,760,104)：「消息提醒」字号 24 在第 0 行，说明字号 18 在 y 36。
## - 列表 Window_CodexNotices (260,140,760,352)：9 行、行高 36。名字在 (6, 宽 170)；说明 systemColor、字号 20
##   在 x 176、宽 460；状态右对齐在最后 90：「开」#a9dfb7，「关」textColor(8)。
## - 确定：确定音，切换并播光标音；左键头关、右键头开（值变了才播光标音，光标不动）；上下首按循环。
##   点非当前行＝选中，点当前行＝确定。取消播取消音返回设置（配置每次切换即写入，原版在退出时保存）。

signal closed

const HEAD_RECT := Rect2(260, 24, 760, 104)
const LIST_RECT := Rect2(260, 140, 760, 352)
const LH := 36.0
const NAME_W := 170.0
const STATUS_W := 90.0
const HINT_SIZE := 20               # max(16, standardFontSize 26 − 6)
const ON_COLOR := Color("a9dfb7")
const OFF_COLOR := Color("c0c0c0")  # textColor(8)
const TITLE := "消息提醒"
const NOTE := "点选切换开／关。关闭后不再自动弹出；菜单里操作的结果和提示照常显示。"

var index := 0
var head_win: XMVWindow
var list_win: XMVWindow
## T300 卡 L：新界面开着时的设置子页版型（XSkinSubPage）；关着为 null，旧页一行不变
var skin: XSkinSubPage


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	head_win = XMVWindow.make(self, HEAD_RECT, XUI.MENU_WINDOW_OPACITY, _paint_head)
	list_win = XMVWindow.make(self, LIST_RECT, XUI.MENU_WINDOW_OPACITY, _paint_list)
	list_win.canvas.blink = true
	if XSkinSubPage.wanted():
		head_win.hide()
		list_win.hide()
		skin = XSkinSubPage.attach(self)


static func rows() -> Array:
	return XConfig.NOTICES


func _paint_head(c: XMVCanvas) -> void:
	c.text(TITLE, 0, 0, c.size.x, "left", XUI.TEXT, 24)
	c.text(NOTE, 0, 36, c.size.x, "left", XUI.TEXT, 18)


func _paint_list(c: XMVCanvas) -> void:
	var w := c.size.x - 12.0
	for i in rows().size():
		var row: Array = rows()[i]
		var y := i * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		var on := XConfig.notice_on(row[0])
		c.text(row[1], 6, y, NAME_W)
		c.text(row[2], 6 + NAME_W, y, w - NAME_W - STATUS_W, "left", XUI.SYSTEM, HINT_SIZE)
		c.text("开" if on else "关", 6 + w - STATUS_W, y, STATUS_W, "right", ON_COLOR if on else OFF_COLOR)


# ---- T300 新版型（XSkinSubPage 向这里要行和牌）----

func skin_self_hosted() -> bool:
	return XSkinSubPage.wanted()


func skin_name() -> String:
	return TITLE


func skin_cat() -> String:
	return "general"


func skin_rows() -> Array:
	var out := []
	for r in rows():
		var on := XConfig.notice_on(r[0])
		out.append({"text": r[1], "right": "开" if on else "关", "right_color": XSkinSubPage.on_color(on)})
	return out


func skin_card(i: int) -> Dictionary:
	var r: Array = rows()[i]
	var on := XConfig.notice_on(r[0])
	return {"title": r[1], "subtitle": "开" if on else "关", "desc": r[2],
		"sections": [XSkinSubPage.choices_section(["开", "关"], 0 if on else 1, 0),
			{"title": "操作", "text": NOTE}]}


func skin_hints() -> Array:
	return [["确定", "切换"], ["左右", "关／开"], ["取消", "返回"]]


func _refresh() -> void:
	list_win.refresh()


func select(i: int) -> void:
	if i == index:
		return
	index = i
	XSound.system(0)
	_refresh()


## toggleCurrent：值变了才写入、播光标音
func toggle(value = null) -> void:
	var key: String = rows()[index][0]
	var next: bool = not XConfig.notice_on(key) if value == null else bool(value)
	if next == XConfig.notice_on(key):
		return
	XConfig.set_notice(key, next)
	XSound.system(0)
	_refresh()


## Window_Selectable.processOk → 'toggle' 处理
func ok() -> void:
	XSound.system(1)
	toggle()


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
			if skin != null:
				return   # 新版型的点击由列表自己接（XSkinSubPage）
			var p: Vector2 = event.position - LIST_RECT.position - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
			if not LIST_RECT.has_point(event.position) or p.y < 0:
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
		XKeyMap.handled(self)
		cancel()
	elif event.is_action_pressed("ui_accept"):
		XKeyMap.handled(self)
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		XKeyMap.handled(self)
		var d := 1 if event.is_action_pressed("ui_down", true) else -1
		select(XMenu._move(index, d, rows().size(), not event.is_echo()))
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		XKeyMap.handled(self)
		toggle(event.is_action_pressed("ui_right", true))
