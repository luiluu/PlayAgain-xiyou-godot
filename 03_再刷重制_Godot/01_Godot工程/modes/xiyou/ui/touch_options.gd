class_name XTouchOptionsScene
extends Control
## 设置「手机按键设置」（平台三期，cc BP 2026-11-06）：原版 Codex_AndroidTouchSettings.js 在 Window_Options 末尾加
## 「手机按键设置」（状态「调整」），确定打开按键设置面板。原版面板是 HTML（单选、滑块），这里照消息提醒页的窗口画法：
## - 显示屏幕按键（开／关，即右上「隐藏按键」）；轮盘大小 70～170%、右侧按键大小 70～160%、顶部按钮大小 80～140%、
##   按键透明度 0～80%（原版 limits，步长 5）：左右键 ∓5，确定＝+5、到顶回最小；
## - 调整UI位置：页面先收起，拖动三组按键，点「完成」或按返回键回到本页；恢复默认：大小、透明度、位置、显示全部回默认。
## 11-12（Kyo「把那个没装的虚拟按键定为默认按键」）：补上原版面板的「操作布局」（原版虚拟按钮／改版按键，默认原版）、
## 「移动方式」（轮盘／方向键）、「右侧布局」（A／B 两键／原多键；另留旧三键）、「显示跑步键」、「地图移动」（可点击／仅按键）、
## 「战斗点击操作」（仅屏幕按键／按键＋点击）、「方向键大小」。原版虚拟按钮时，只对改版按键有用的行显示「—」、不能改（原版面板是藏起来）。
## 仍没做：后台挂机、战力显示（在别处）。
## ui6：加「摇杆拖动翻页」（开／关，默认开；XTouchControls.STICK_PAGE = false 时不列这一行）。
## 每次改动即写入 user://touch_controls.json（XTouchControls 管）。

signal closed

const HEAD_RECT := Rect2(260, 8, 760, 96)
const LIST_RECT := Rect2(260, 108, 760, 576)
const LH := 36.0
const NAME_W := 220.0
const STATUS_W := 200.0
const TITLE := "手机按键设置"
const NOTE := "左右键或点选调整，改动立即生效。调整UI位置：拖动按键，点「完成」或按返回键结束。"
## [名字, 键]
const ROWS := [["显示屏幕按键", "visible"], ["轮盘大小", "stick"], ["右侧按键大小", "buttons"], ["顶部按钮大小", "tools"],
	["按键透明度", "transparency"], ["摇杆拖动翻页", "stick_page"], ["操作布局", "style"], ["移动方式", "mode"], ["右侧布局", "layout"],
	["显示跑步键", "show_run"], ["方向键大小", "pad"], ["地图移动", "map_touch"], ["战斗点击操作", "battle_touch"],
	["调整UI位置", "position"], ["恢复默认", "reset"]]
## 选项类：键 → [[值, 显示], ...]（左右键、确定在其中轮换）
const CHOICES := {
	"style": [["original", "原版虚拟按钮"], ["modern", "改版按键"]],
	"mode": [["joystick", "轮盘"], ["buttons", "方向键"]],
	"layout": [["ab", "A／B 两键"], ["full", "原多键"], ["classic", "确定取消跑步"]],
}
## 开关类：键 → [关的显示, 开的显示]
const FLAG_TEXT := {"show_run": ["关", "开"], "map_touch": ["仅按键", "可点击"], "battle_touch": ["仅屏幕按键", "按键＋点击"]}
## 只对改版按键有用的行（原版虚拟按钮时显示「—」、不能改）
const MODERN_ONLY := ["mode", "layout", "show_run", "pad"]


## 实际列出的行（摇杆翻页关掉整个功能时不列）
static func rows() -> Array:
	return ROWS.filter(func(r): return XTouchControls.STICK_PAGE or r[1] != "stick_page")

var index := 0
var head_win: XMVWindow
var list_win: XMVWindow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	head_win = XMVWindow.make(self, HEAD_RECT, XUI.MENU_WINDOW_OPACITY, _paint_head)
	list_win = XMVWindow.make(self, LIST_RECT, XUI.MENU_WINDOW_OPACITY, _paint_list)
	list_win.canvas.blink = true


static func pad() -> XTouchControls:
	return XTouchControls.instance


func status_text(i: int) -> String:
	var p := pad()
	if p == null:
		return ""
	var key: String = rows()[i][1]
	match key:
		"visible":
			return "关" if p.hidden else "开"
		"stick_page":
			return "开" if p.stick_page_on() else "关"
		"position", "reset":
			return "调整" if key == "position" else ""
	if p.ghost() and MODERN_ONLY.has(key):
		return "—"
	if CHOICES.has(key):
		for c in CHOICES[key]:
			if c[0] == str(p.settings.get(key, "")):
				return c[1]
		return ""
	if FLAG_TEXT.has(key):
		return FLAG_TEXT[key][1 if bool(p.settings.get(key, false)) else 0]
	return "%d%%" % int(p.settings[key])


func _paint_head(c: XMVCanvas) -> void:
	c.text(TITLE, 0, 0, c.size.x, "left", XUI.TEXT, 24)
	c.text(NOTE, 0, 36, c.size.x, "left", XUI.TEXT, 18)


func _paint_list(c: XMVCanvas) -> void:
	var w := c.size.x - 12.0
	for i in rows().size():
		var y := i * LH
		if i == index:
			c.cursor(Rect2(0, y, c.size.x, LH))
		c.text(rows()[i][0], 6, y, NAME_W)
		c.text(status_text(i), 6 + w - STATUS_W, y, STATUS_W, "right")


func select(i: int) -> void:
	if i == index:
		return
	index = i
	XSound.system(0)
	list_win.refresh()


## 大小／透明度 ±5；显示按键左关右开。值变了才播光标音。
func side(right: bool) -> void:
	var p := pad()
	var key: String = rows()[index][1]
	if p == null or key == "position" or key == "reset" or (p.ghost() and MODERN_ONLY.has(key)):
		return
	var before := status_text(index)
	if CHOICES.has(key):
		_cycle(p, key, 1 if right else -1)
	elif FLAG_TEXT.has(key):
		p.set_flag(key, right)
	elif key == "visible":
		p.set_hidden(not right)
	elif key == "stick_page":
		p.set_stick_page(right)
	else:
		p.set_value(key, int(p.settings[key]) + (XTouchControls.STEP if right else -XTouchControls.STEP))
	if status_text(index) != before:
		XSound.system(0)
		list_win.refresh()


func ok() -> void:
	var p := pad()
	if p == null:
		XSound.system(3)
		return
	var key: String = rows()[index][1]
	match key:
		"visible":
			XSound.system(1)
			p.set_hidden(not p.hidden)
		"stick_page":
			XSound.system(1)
			p.set_stick_page(not p.stick_page_on())
		"position":
			XSound.system(1)
			start_layout()
			return
		_ when p.ghost() and MODERN_ONLY.has(key):
			XSound.system(3)
			return
		_ when CHOICES.has(key):
			XSound.system(1)
			_cycle(p, key, 1)
		_ when FLAG_TEXT.has(key):
			XSound.system(1)
			p.set_flag(key, not bool(p.settings.get(key, false)))
		"reset":
			XSound.system(1)
			p.reset_defaults()
		_:
			XSound.system(1)
			var lim: Array = XTouchControls.LIMITS[key]
			var next := int(p.settings[key]) + XTouchControls.STEP
			p.set_value(key, lim[0] if next > lim[1] else next)
	list_win.refresh()


## 选项类往前／后轮换一个
func _cycle(p: XTouchControls, key: String, d: int) -> void:
	var opts: Array = CHOICES[key]
	var i := 0
	for j in opts.size():
		if opts[j][0] == str(p.settings.get(key, "")):
			i = j
	p.set_choice(key, opts[(i + d + opts.size()) % opts.size()][0])


## 调位置时整页收起，完成后回来。
func start_layout() -> void:
	var p := pad()
	visible = false
	p.layout_finished.connect(func():
		visible = true
		list_win.refresh(), CONNECT_ONE_SHOT)
	p.start_layout()


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
	if not visible:
		return
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
		side(event.is_action_pressed("ui_right", true))
