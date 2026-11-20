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
## T300 卡 L：新界面开着时的设置子页版型（XSkinSubPage）；关着为 null，旧页一行不变
var skin: XSkinSubPage
## 调整位置的拖动态（新版型下页面不 hide，只淡出，这里记着免得键盘穿到底下）
var _layout_busy := false
## 恢复默认的统一确认弹窗（新版型）
var _dlg: XSkinConfirm


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
		skin.remove_from_group(XUiSkin.FULLSCREEN_GROUP)   # 收口批：按键设置页要看着键调位置，虚拟键不收


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


# ---- T300 新版型（XSkinSubPage 向这里要行和牌）----

func skin_self_hosted() -> bool:
	return XSkinSubPage.wanted()


func skin_name() -> String:
	return TITLE


func skin_cat() -> String:
	return "hangup"


func _key_at(i: int) -> String:
	return str(rows()[i][1])


## 大小、透明度这类百分比行：[最小, 最大]；其余 []
func _limits(key: String) -> Array:
	return XTouchControls.LIMITS[key] if XTouchControls.LIMITS.has(key) else []


func _is_off(key: String) -> bool:
	var p := pad()
	return p != null and p.ghost() and MODERN_ONLY.has(key)


func skin_rows() -> Array:
	var out := []
	for i in rows().size():
		var key := _key_at(i)
		var t := status_text(i)
		var d := {"text": rows()[i][0], "right": t, "right_color": XUiSkin.GOLD_LIGHT}
		if _is_off(key):
			d["disabled"] = true   # 对当前布局没用的行变灰，值仍是「—」
		elif key == "position":
			d["right"] = "调整 ›"
		elif key == "reset":
			d["right"] = ""
		out.append(d)
	return out


func skin_bars() -> Array:
	var p := pad()
	var out := []
	for i in rows().size():
		var key := _key_at(i)
		var lim := _limits(key)
		if p == null or lim.is_empty() or _is_off(key):
			out.append(-1.0)
		else:
			out.append(float(int(p.settings[key]) - int(lim[0])) / float(maxi(int(lim[1]) - int(lim[0]), 1)))
	return out


func skin_card(i: int) -> Dictionary:
	var key := _key_at(i)
	var p := pad()
	var d := {"title": rows()[i][0], "subtitle": status_text(i), "desc": "", "sections": [], "buttons": []}
	if p == null:
		return d
	var secs := []
	var how := "左右键调整，确定循环切换。"
	if _is_off(key):
		d["desc"] = "只对「改版按键」有用。现在用的是原版虚拟按钮，这一行不能改。"
		d["subtitle"] = "—"
		how = "先把「操作布局」换成「改版按键」。"
	elif key == "visible":
		d["desc"] = "屏幕上的虚拟按键显示或隐藏（即右上的「隐藏按键」）。"
		secs.append(XSkinSubPage.choices_section(["开", "关"], 1 if p.hidden else 0, 0))
		how = "左右键或确定切换。"
	elif key == "stick_page":
		d["desc"] = "用摇杆拖动来翻页。"
		secs.append(XSkinSubPage.choices_section(["开", "关"], 0 if p.stick_page_on() else 1, 0))
		how = "左右键或确定切换。"
	elif key == "position":
		d["desc"] = "进入后页面收起，直接拖动三组按键；点「完成」或按返回键回到这里。"
		d["buttons"] = [{"text": "调整位置", "primary": true}]
		how = "确定进入。"
	elif key == "reset":
		d["desc"] = "把按键大小、透明度、位置、显示全部换回默认。"
		d["buttons"] = [{"text": "恢复默认", "primary": true}]
		how = "确定后会再问一次。"
	elif CHOICES.has(key):
		var labels: Array = CHOICES[key].map(func(c): return c[1])
		var cur := 0
		for j in CHOICES[key].size():
			if CHOICES[key][j][0] == str(p.settings.get(key, "")):
				cur = j
		secs.append(XSkinSubPage.choices_section(labels, cur, 0))
	elif FLAG_TEXT.has(key):
		var on := bool(p.settings.get(key, false))
		secs.append(XSkinSubPage.choices_section(FLAG_TEXT[key], 1 if on else 0, -1))
	else:
		var lim := _limits(key)
		if not lim.is_empty():
			d["desc"] = "范围 %d%%～%d%%。" % [int(lim[0]), int(lim[1])]
			how = "左右键每次增减 %d%%；确定 +%d%%，到顶回最小。" % [XTouchControls.STEP, XTouchControls.STEP]
	secs.append({"title": "操作", "text": how})
	d["sections"] = secs
	return d


func skin_button(_i: int) -> void:
	ok()


func skin_hints() -> Array:
	if _layout_busy:
		return [["取消", "完成"]]
	return [["确定", "切换"], ["左右", "调整"], ["取消", "返回"]]


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
			if skin != null:
				_ask_reset()
				return
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
	if skin != null:
		_start_layout_skin(p)
		return
	visible = false
	p.layout_finished.connect(func():
		visible = true
		list_win.refresh(), CONNECT_ONE_SHOT)
	p.start_layout()


## 新版型：整页淡出，只留一枚「完成」胶囊在上沿正中（用 XTouchControls 自带的那条按钮栏，挪到上沿正中），完成后淡入
func _start_layout_skin(p: XTouchControls) -> void:
	_layout_busy = true
	skin.fade_out()
	var bar: Control = p._layout_bar if "_layout_bar" in p else null
	var old_pos := Vector2.ZERO
	if bar != null:
		old_pos = bar.position
		bar.position = Vector2(roundf((get_viewport_rect().size.x - bar.size.x) / 2.0), 8.0)
	p.layout_finished.connect(func():
		_layout_busy = false
		if bar != null and is_instance_valid(bar):
			bar.position = old_pos
		if is_instance_valid(skin):
			skin.fade_in(), CONNECT_ONE_SHOT)
	p.start_layout()


## 恢复默认：统一确认弹窗（橙边、停在「取消」）
func _ask_reset() -> void:
	_dlg = XSkinConfirm.open(skin, {"title": "恢复默认？", "body": "按键显示开关、大小、透明度和位置都会换回默认，不能撤回。", "buttons": ["恢复", "取消"], "danger": true})
	_dlg.chosen.connect(func(i):
		var d := _dlg
		_dlg = null
		d.close()
		if i == 0:
			XSound.system(1)
			pad().reset_defaults()
		else:
			XSound.system(2))
	_dlg.cancelled.connect(func():
		var d := _dlg
		_dlg = null
		d.close()
		XSound.system(2))


func cancel() -> void:
	XSound.system(2)
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if _layout_busy:
		return   # 拖动态：右击等不能关子页（会把拖动态和按钮栏留在场上）
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
	if _layout_busy:   # 拖动态：Esc／返回键结束拖动（桌面没有触屏按钮栏也能退出）
		if event.is_action_pressed("ui_cancel") and pad() != null and pad().layout_editing:
			XKeyMap.handled(self)
			pad().finish_layout()
		return
	if not visible:
		return
	if _dlg != null and is_instance_valid(_dlg):
		if _dlg.handle_input(event):
			XKeyMap.handled(self)
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
