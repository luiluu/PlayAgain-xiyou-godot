class_name XWarehouseScene
extends Control
## 仓库（PH_Warehouse 的 Scene_Warehouse；方桌大厅仓库管理员 Map4 EV8「装备道具仓库」＝PHWarehouse show <仓库>）。数据与存取在 XWarehouse。
## 版面与绘制按冻结 v0.28 浏览器参照（tests/fixtures/warehouse_oracle.json，ui_reference/review_system_pages.js 的 warehouse）：
## - 标题 (0,0,1280,64)：仓库名居中、crisisColor；选项 (0,64,1280,64)「取出／储存」两列居中（格宽 620）；
##   分类 (0,136,1280,64)「物品／武器／护甲／重要物品」四列居中（格宽 304），开场不选；
##   列表 (0,208,1280,440) 两列（格宽 602、间距 48）、行高 36、可见 11 行；信息 (0,656,1280,64)「可用空间: 剩余 / 上限」。
## - 列表一格：图标 (x+2,y+2)、名字 x+36（品质色，宽 = 596 − textWidth("×0,000") − 36）、右侧字号 20 右对齐：
##   取出写「×仓库里的数量」，储存写持有数（物品「×数量」，独立装备「序号/9,999」）；没看过的画 NEW，但从不记看过
##   （Window_WarehouseItemList 没有说明窗，Galv 的 updateHelp 不走）。没有说明卡。
## - 操作：选项确定 → 分类（选第 1 类）；分类阶段列表跟着显示该类（无光标），确定进列表（有东西选第 1 项）；
##   列表确定即存入／取出一件（装备音效，不行蜂鸣），光标不动（取空了也停在原格）；取消逐级退回，选项取消关闭。
##   储存时仓库满了列表不可确定（蜂鸣）。

signal closed

const TITLE_RECT := Rect2(0, 0, 1280, 64)
const OPTION_RECT := Rect2(0, 64, 1280, 64)
const CAT_RECT := Rect2(0, 136, 1280, 64)
const LIST_RECT := Rect2(0, 208, 1280, 440)
const INFO_RECT := Rect2(0, 656, 1280, 64)
const LH := 36.0
const OPTION_W := 620.0
const CAT_W := 304.0
const COL_W := 602.0
const COL_STEP := 650.0
const ROWS := 11
const QTY_FONT := 20

var mode := "option"         # option / category / list
var option := 0
var category := -1
var index := -1
var top := 0                 # 列表首行（行号）
var data: Array = []
var title_win: XMVWindow
var option_win: XMVWindow
var cat_win: XMVWindow
var list_win: XMVWindow
var info_win: XMVWindow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	title_win = XMVWindow.make(self, TITLE_RECT, op, _paint_title)
	option_win = XMVWindow.make(self, OPTION_RECT, op, _paint_option)
	cat_win = XMVWindow.make(self, CAT_RECT, op, _paint_cat)
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	info_win = XMVWindow.make(self, INFO_RECT, op, _paint_info)
	for w in [option_win, cat_win, list_win]:
		w.canvas.blink = true
	XWarehouse.last_option = 0
	_reload()


func _symbol() -> String:
	return XWarehouse.CATEGORIES[maxi(category, 0)]


static func cat_names() -> Array:
	var t: Dictionary = XDB.system().get("terms", {})
	var basic: Array = t.get("commands", [])
	# TextManager.item／weapon／armor／keyItem ＝ $dataSystem.terms.commands[4]／[12]／[13]／[14]
	return [4, 12, 13, 14].map(func(i): return str(basic[i]) if i < basic.size() else "")


## 列表数据（Window_WarehouseItemList.loadItems）：取出＝仓库里的，储存＝持有的；分类窗没选中时（开场、退回选项）
## setCategory(null)，includes 全为假，列表是空的
func _reload() -> void:
	var s := XState.current
	XWarehouse.last_category = _symbol()
	if category < 0:
		data = []
	else:
		data = XWarehouse.stored(s, _symbol()) if option == 0 else XWarehouse.carried(s, _symbol())
	_refresh()


# ---- 绘制（操作 ["t", 文字, x, y, 宽, 行高, 对齐, 字号, 颜色]／["i", 图标, x, y]，与参照同形） ----
static func _t(text: String, x: float, y: float, w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE) -> Array:
	return ["t", text, x, y, w, LH, align, size, color]


static func title_ops() -> Array:
	return [_t(XWarehouse.last_active, 0, 0, 1280, "center", XUI.text_color(17))]


static func option_ops() -> Array:
	var p := XDB.plugin("PH_Warehouse")
	return [_t(str(p.get("Withdraw Text", "取出")), 6, 0, OPTION_W - 12, "center"),
		_t(str(p.get("Deposit Text", "储存")), OPTION_W + 12 + 6, 0, OPTION_W - 12, "center")]


static func cat_ops() -> Array:
	var ops := []
	var names := cat_names()
	for i in names.size():
		ops.append(_t(names[i], i * (CAT_W + 12) + 6, 0, CAT_W - 12, "center"))
	return ops


static func info_ops() -> Array:
	return [_t(XWarehouse.info_text(XState.current), 0, 0, 0)]


## 列表第 i 格的位置（两列）
static func cell(i: int, first_row := 0) -> Vector2:
	return Vector2((i % 2) * COL_STEP, (floori(i / 2.0) - first_row) * LH)


## Window_WarehouseItemList.drawItem：名字宽 = 格宽 − 6 − numberWidth − 36；取出「×数量」、储存为持有数
static func row_ops(e: Dictionary, withdraw: bool, p: Vector2) -> Array:
	var rec: Dictionary = e.rec
	var w := COL_W - 6.0
	var name_w := w - XActorBook.js_width("×0,000", XUI.FONT_SIZE) - 36.0
	var right := "×" + XMenu._group(int(e.qty)) if withdraw else XItemRow.right_text(e)
	return [["i", int(rec.get("iconIndex", 0)), p.x + 2.0, p.y + 2.0],
		_t(XQuality.list_name(rec), p.x + 36.0, p.y, name_w, "left", XGear.color(rec)),
		_t(right, p.x, p.y, w, "right", XUI.TEXT, QTY_FONT)]


func list_ops() -> Array:
	var ops := []
	for i in range(top * 2, mini((top + ROWS) * 2, data.size())):
		ops += row_ops(data[i], option == 0, cell(i, top))
	return ops


func _paint_title(c: XMVCanvas) -> void:
	XActorBook.paint_ops(c, title_ops())


func _paint_option(c: XMVCanvas) -> void:
	c.cursor(Rect2(option * (OPTION_W + 12), 0, OPTION_W, LH), mode == "option")
	XActorBook.paint_ops(c, option_ops())


func _paint_cat(c: XMVCanvas) -> void:
	if category >= 0:
		c.cursor(Rect2(category * (CAT_W + 12), 0, CAT_W, LH), mode == "category")
	XActorBook.paint_ops(c, cat_ops())


func _paint_list(c: XMVCanvas) -> void:
	if index >= 0 and floori(index / 2.0) >= top and floori(index / 2.0) < top + ROWS:
		var p := cell(index, top)
		c.cursor(Rect2(p.x, p.y, COL_W, LH), mode == "list")
	XActorBook.paint_ops(c, list_ops())
	var s := XState.current
	var tex := XItemRow.new_icon()
	for i in range(top * 2, mini((top + ROWS) * 2, data.size())):
		if tex != null and XItemRow.shows_new(s, data[i].rec):
			c.draw_texture(tex, cell(i, top) + Vector2(2, 2))


func _paint_info(c: XMVCanvas) -> void:
	XActorBook.paint_ops(c, info_ops())


func _refresh() -> void:
	list_win.up_arrow = top > 0
	list_win.down_arrow = (top + ROWS) * 2 < data.size()
	for w in [title_win, option_win, cat_win, list_win, info_win]:
		w.refresh()


# ---- 操作 ----
func _enabled() -> bool:
	if data.is_empty():
		return false
	return option == 0 or XWarehouse.has_space(XState.current)


func ok() -> void:
	match mode:
		"option":
			XSound.system(1)
			XWarehouse.last_option = option
			mode = "category"
			category = 0
			_reload()
		"category":
			XSound.system(1)
			mode = "list"
			if not data.is_empty():
				_select(0)
			_refresh()
		"list":
			# Window_WarehouseItemList.playOkSound 是空的；不可确定时 Window_Selectable 放蜂鸣
			if not _enabled():
				XSound.system(3)
				return
			_move_item()


## moveItem：存入／取出一件
func _move_item() -> void:
	var s := XState.current
	var e = data[index] if index >= 0 and index < data.size() else null
	var done := false
	if e != null:
		if option == 1:
			done = XWarehouse.deposit(s, _symbol(), e.rec)
		else:
			done = XWarehouse.withdraw(s, _symbol(), e.rec)
	XSound.system(4 if done else 3)
	_reload()


func cancel() -> void:
	XSound.system(2)
	match mode:
		"list":
			mode = "category"
			index = -1
			top = 0
		"category":
			mode = "option"
			category = -1
			_reload()
		"option":
			closed.emit()
			return
	_refresh()


func _select(i: int) -> void:
	index = i
	var row := floori(i / 2.0)
	top = XMenu._scroll_to(row, top, ROWS)
	_refresh()


func _move(dx: int, dy: int, wrap: bool) -> void:
	match mode:
		"option":
			if dx != 0:
				var i := XMenu._move(option, dx, 2, wrap)
				if i != option:
					option = i
					XSound.system(0)
					_refresh()
		"category":
			if dx != 0:
				var i := XMenu._move(category, dx, 4, wrap)
				if i != category:
					category = i
					XSound.system(0)
					index = -1
					top = 0
					_reload()
		"list":
			# Window_Selectable（两列、非横排）：右／左逐格可跨行，首尾不回绕；上／下跳一行（±2），到边不动
			var n := data.size()
			if n == 0:
				return
			var i := index
			if dx > 0 and index < n - 1:
				i = index + 1
			elif dx < 0 and index > 0:
				i = index - 1
			elif dy > 0 and index < n - 2:
				i = index + 2
			elif dy < 0 and index >= 2:
				i = index - 2
			if i != index:
				XSound.system(0)
				_select(i)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if LIST_RECT.has_point(p):
				top = clampi(top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, ceili(data.size() / 2.0) - ROWS))
				_refresh()
		MOUSE_BUTTON_LEFT:
			var pad := XMVWindow.PADDING
			if mode == "option" and OPTION_RECT.has_point(p):
				var i := clampi(floori((p.x - pad) / (OPTION_W + 12)), 0, 1)
				if i == option:
					ok()
				else:
					option = i
					XSound.system(0)
					_refresh()
			elif mode == "category" and CAT_RECT.has_point(p):
				var i := clampi(floori((p.x - pad) / (CAT_W + 12)), 0, 3)
				if i == category:
					ok()
				else:
					category = i
					XSound.system(0)
					_reload()
			elif mode == "list" and LIST_RECT.has_point(p):
				var row := floori((p.y - LIST_RECT.position.y - pad) / LH)
				var col := 1 if p.x - pad >= COL_STEP else 0
				var i := (top + row) * 2 + col
				if row >= 0 and row < ROWS and i < data.size():
					if i == index:
						ok()
					else:
						XSound.system(0)
						_select(i)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		ok()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_move(0, 1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		get_viewport().set_input_as_handled()
		_move(1 if event.is_action_pressed("ui_right", true) else -1, 0, not event.is_echo())
