class_name XAchievementScene
extends Control
## 成就界面（Star_AchievementSystem 的 Scene_AchievementBook；主菜单「成就」＝公共事件 431 SceneManager.push）。
## 窗口与逐项绘制按 achievement_probe 的 ui 测量：
## - 类型窗 (0,0,320,648)：行高 72，8 类（挑战 事件 副本 深渊 收集 节日 探索 光辉事迹），文字 (6, 宽 280) 在行内垂直居中。
## - 列表窗 (320,0,960,720)：行高 108（三行 36），一页画 6 项。全局已得（ConfigManager）：图标放大 2 倍在 (22,y)；
##   成就名、达成条件、「特殊奖励: …」在 x 114 的三行（drawTextEx）；「已获得」在 (12, 第三行)，「完成于…」字号 14 右对齐在第二行起
##   的 108 高行框里；未得只写「未获得」（整行 108 内居中，不显示名字与条件）。
## - 计数窗 (0,656,320,64)：「全局与本局都有的条数/总数」，x = 宽/2 − 条数文字宽。
## - 类型窗活动时换类型即刷新列表（列表无光标）；确定进入列表（选第 0 项，空类型也画光标），取消回到类型窗（列表光标消失）；
##   列表里确定无反应。类型窗取消关闭界面。上下首按循环；PageUp/PageDown 翻页；滚轮在活动窗口内滚一行。
## - 背景同主菜单（Scene_MenuBase＋MOG 底图），窗口不透明度 30。

signal closed

const TYPE_RECT := Rect2(0, 0, 320, 648)
const LIST_RECT := Rect2(320, 0, 960, 720)
const COUNT_RECT := Rect2(0, 656, 320, 64)
const TYPE_LH := 72.0
const LIST_LH := 108.0
const ROW := 36.0
const TEXT_EX_LH := 34.0     # drawTextEx：calcTextHeight = 字号 26 + 8
const PAGE_ROWS := 6         # floor((720 − 28) / 108)

var type_index := 0
var index := -1
var top := 0
var mode := "type"
var list: Array = []
var type_win: XMVWindow
var list_win: XMVWindow
var count_win: XMVWindow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)  # 成就弹窗在菜单里框与底只剩 30（MOG_MenuBackground）
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	type_win = XMVWindow.make(self, TYPE_RECT, XUI.MENU_WINDOW_OPACITY, _paint_types)
	list_win = XMVWindow.make(self, LIST_RECT, XUI.MENU_WINDOW_OPACITY, _paint_list)
	count_win = XMVWindow.make(self, COUNT_RECT, XUI.MENU_WINDOW_OPACITY, _paint_count)
	type_win.canvas.blink = true
	list_win.canvas.blink = true
	_load_list()


func types() -> Array:
	return XAchievement.types()


func _load_list() -> void:
	list = XAchievement.of_type(str(types()[type_index])) if type_index < types().size() else []
	top = clampi(top, 0, _max_top())
	_refresh()


func _max_top() -> int:
	return maxi(0, list.size() - PAGE_ROWS)


func _refresh() -> void:
	list_win.up_arrow = top > 0
	list_win.down_arrow = top < _max_top()
	for w in [type_win, list_win, count_win]:
		w.refresh()


# ---- 绘制 ----
func _paint_types(c: XMVCanvas) -> void:
	for i in types().size():
		var y := i * TYPE_LH
		if i == type_index:
			c.cursor(Rect2(0, y, c.size.x, TYPE_LH), mode == "type")
		c.text(str(types()[i]), 6, y, c.size.x - 12, "left", XUI.TEXT, XUI.FONT_SIZE, TYPE_LH)


func _paint_list(c: XMVCanvas) -> void:
	if index >= top and index < top + PAGE_ROWS:
		c.cursor(Rect2(0, (index - top) * LIST_LH, c.size.x, LIST_LH), mode == "list")
	for i in range(top, mini(top + PAGE_ROWS, list.size())):
		paint_item(c, int(list[i]), (i - top) * LIST_LH, c.size.x - 12)


## Window_AchievementBookIndex.drawItem（rect = itemRectForText：x 6、宽 内容宽 − 12）
static func paint_item(c: XMVCanvas, id: int, y: float, width: float) -> void:
	var d := XAchievement.def(id)
	var owned := XAchievement.global_has(id)
	# 142／143 专用徽章与名字样式（XAchievementBadge，参照 achievement_badges.json）
	var plan := XAchievementBadge.list_plan(id, y, LIST_LH, owned)
	if not plan.is_empty() and plan.only_badge:
		XAchievementBadge.paint_op(c, plan.badge)
		return
	if not owned:
		c.text("未获得", 6, y, width, "left", XUI.TEXT, XUI.FONT_SIZE, LIST_LH)
		return
	var x := 6.0 + LIST_LH
	if plan.is_empty():
		c.icon(int(d.icon), 6 + 16, y, 1.0, 64.0)
		c.text(str(d.name), x, y, 0, "left", XUI.TEXT, XUI.FONT_SIZE, TEXT_EX_LH)
	else:
		XAchievementBadge.paint_op(c, plan.badge)
		XAchievementBadge.paint_op(c, plan.name)
	c.text(str(d.trigger), x, y + ROW, 0, "left", XUI.TEXT, XUI.FONT_SIZE, TEXT_EX_LH)
	if str(d.evalText) != "":
		c.text("特殊奖励: " + str(d.evalText), x, y + ROW * 2, 0, "left", XUI.TEXT, XUI.FONT_SIZE, TEXT_EX_LH)
	# (rect.x − lineHeight) × 2 = 12
	c.text("已获得", 12, y + ROW * 2, 0, "left", XUI.TEXT, XUI.FONT_SIZE, TEXT_EX_LH)
	var t := XAchievement.global_time(id)
	if t != "":
		c.text("完成于" + t, 12, y + ROW, width, "right", XUI.TEXT, 14, LIST_LH)


func _paint_count(c: XMVCanvas) -> void:
	var n: Array = XAchievement.count(XState.current)
	c.text("%d/%d" % n, c.size.x / 2.0 - c.text_width(str(n[0])), 0, c.size.x)


# ---- 操作 ----
func select_type(i: int) -> void:
	if i == type_index:
		return
	type_index = i
	XSound.system(0)
	_load_list()


func select(i: int) -> void:
	if i == index:
		return
	index = i
	XSound.system(0)
	_scroll_to_index()
	_refresh()


func _scroll_to_index() -> void:
	if index < 0:
		return
	if index < top:
		top = index
	elif index >= top + PAGE_ROWS:
		top = index - PAGE_ROWS + 1


## Scene_AchievementBook.onRangeOk：确定音，列表 setup（select 0、激活）
func ok() -> void:
	if mode != "type":
		return
	XSound.system(1)
	mode = "list"
	index = 0
	_scroll_to_index()
	_load_list()


## 列表取消（OnCancel）回到类型窗；类型窗取消关闭
func cancel() -> void:
	XSound.system(2)
	if mode == "list":
		mode = "type"
		index = -1
		_refresh()
	else:
		closed.emit()


func _move(d: int, wrap: bool) -> void:
	if mode == "type":
		select_type(XMenu._move(type_index, d, types().size(), wrap))
	elif not list.is_empty():
		select(XMenu._move(index, d, list.size(), wrap))


## Window_Selectable.cursorPagedown/up：一页 6 行
func _page(d: int) -> void:
	if mode != "list" or list.is_empty():
		return
	var before := index
	if d > 0 and top + PAGE_ROWS < list.size():
		top = mini(top + PAGE_ROWS, _max_top())
		index = mini(index + PAGE_ROWS, list.size() - 1)
	elif d < 0 and top > 0:
		top = maxi(top - PAGE_ROWS, 0)
		index = maxi(index - PAGE_ROWS, 0)
	if index != before:
		XSound.system(0)
	_refresh()


func _scroll(d: int) -> void:
	if mode == "list":
		top = clampi(top + d, 0, _max_top())
		_refresh()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if LIST_RECT.has_point(p):
				_scroll(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		MOUSE_BUTTON_LEFT:
			if mode == "type" and TYPE_RECT.has_point(p):
				var i := floori((p.y - TYPE_RECT.position.y - XMVWindow.PADDING) / TYPE_LH)
				if i >= 0 and i < types().size():
					if i == type_index:
						ok()
					else:
						select_type(i)
			elif mode == "list" and LIST_RECT.has_point(p):
				var i := top + floori((p.y - LIST_RECT.position.y - XMVWindow.PADDING) / LIST_LH)
				if i >= top and i < list.size() and i != index:
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
		_move(1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
	elif event.is_action_pressed("ui_page_down") or event.is_action_pressed("ui_page_up"):
		get_viewport().set_input_as_handled()
		_page(1 if event.is_action_pressed("ui_page_down") else -1)
