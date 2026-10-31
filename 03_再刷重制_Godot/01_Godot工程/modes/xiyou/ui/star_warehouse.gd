class_name XStarWarehouseScene
extends Control
## 通用仓库画面（Star_Warehouse：save_mode 真＝Scene_StarSaveWarehouse 存放，假＝Scene_StarWarehouse 取出）。数据与存取在 XStarWarehouse。
## 两个画面结构相同（Scene_ItemBase，1280×720），按 MV 窗口公式（行高 36、内边距 14，同 XWarehouseScene 量到的值）：
## - 说明 (0,0,1280,100) Window_Help 两行：列表阶段显示选中装备的说明（drawTextEx，x 6）；宠物（Game_Enemy）没有 description，空白；
##   分类阶段 Window_Selectable.updateHelp 清空。
## - 分类 (0,100,1280,64) Window_HorzCommand 两列「装备／宠物」（格宽 620），开场就激活、选第 1 项；光标移动时列表跟着换分类。
## - 列表 (0,164,1280,556) 两列（格宽 602、间距 48），行高 36、可见 14 行。装备：图标 (x+2,y+2)＋名字 x+36（品质色，
##   宽 = 596 − textWidth("000") − 36），不画数量、不画 NEW；宠物只写名字（x，宽 596 − textWidth("000")）。没有置灰（isCurrentItemEnabled 恒真）。
##   存放：装备是背包里的防具在前、武器在后；宠物是宠物列表（出战的名字带 [出战]）。取出：仓库里的。
## - 操作：分类确定 → 列表（select(0)，空列表也把光标放在第 1 格）。列表确定（普通确定音，沙僧 Q3：Window_Selectable.processOk
##   先 playOk 再调处理）→ 存入／取出一件，刷新，光标不动（越过末尾也不收回）；没有装备音效与蜂鸣（区别于 PH 仓库，别「统一」）。
##   <PushDct> 装备弹「不可存放」；出战宠物没有反应。取消：列表 → 分类（去掉光标），分类 → 关闭。

signal closed

const HELP_RECT := Rect2(0, 0, 1280, 100)
const CAT_RECT := Rect2(0, 100, 1280, 64)
const LIST_RECT := Rect2(0, 164, 1280, 556)
const LH := 36.0
const CAT_W := 620.0
const COL_W := 602.0
const COL_STEP := 650.0
const ROWS := 14
const CATEGORIES := ["equip", "Pet"]
const PUSH_DCT_TEXT := "不可存放"

var save_mode := true
var mode := "category"       # category / list
var category := 0
var index := -1
var top := 0
var data: Array = []
var help_win: XMVWindow
var cat_win: XMVWindow
var list_win: XMVWindow


func _init(save := true) -> void:
	save_mode = save


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	help_win = XMVWindow.make(self, HELP_RECT, op, _paint_help)
	cat_win = XMVWindow.make(self, CAT_RECT, op, _paint_cat)
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	for w in [cat_win, list_win]:
		w.canvas.blink = true
	_reload()


## makeItemList：存放＝背包里的装备／宠物列表，取出＝仓库里的
func _reload() -> void:
	var s := XState.current
	if CATEGORIES[category] == "equip":
		data = XStarWarehouse.carried_gear(s) if save_mode else XStarWarehouse.gear().duplicate()
	else:
		data = XPets.list(s).duplicate() if save_mode else XStarWarehouse.pets().duplicate()
	_refresh()


func current():
	return data[index] if index >= 0 and index < data.size() else null


# ---- 绘制（操作同 XWarehouseScene：["t", 文字, x, y, 宽, 行高, 对齐, 字号, 颜色]／["i", 图标, x, y]） ----
static func _t(text: String, x: float, y: float, w: float, align := "left", color := XUI.TEXT) -> Array:
	return ["t", text, x, y, w, LH, align, XUI.FONT_SIZE, color]


static func cat_ops() -> Array:
	return [_t("装备", 6, 0, CAT_W - 12, "center"), _t("宠物", CAT_W + 12 + 6, 0, CAT_W - 12, "center")]


static func cell(i: int, first_row := 0) -> Vector2:
	return Vector2((i % 2) * COL_STEP, (floori(i / 2.0) - first_row) * LH)


## drawItem：rect.width −= textPadding；装备 drawItemName(宽 − numberWidth)，宠物 drawText(name, 宽 − numberWidth)
static func row_ops(e: Dictionary, equip: bool, p: Vector2) -> Array:
	var w := COL_W - 6.0 - XActorBook.js_width("000", XUI.FONT_SIZE)
	if not equip:
		return [_t(XPets.pet_name(XState.current, e), p.x, p.y, w)]
	return [["i", int(e.get("iconIndex", 0)), p.x + 2.0, p.y + 2.0], _t(XQuality.list_name(e), p.x + 36.0, p.y, w - 36.0, "left", XGear.color(e))]


func list_ops() -> Array:
	var ops := []
	for i in range(top * 2, mini((top + ROWS) * 2, data.size())):
		ops += row_ops(data[i], CATEGORIES[category] == "equip", cell(i, top))
	return ops


## Window_Help：列表阶段 setHelpWindowItem(item)（装备的说明；宠物没有 description）；分类阶段清空
func help_text() -> String:
	var e = current()
	if mode != "list" or e == null or CATEGORIES[category] != "equip":
		return ""
	return str(e.get("description", ""))


func _paint_help(c: XMVCanvas) -> void:
	var t := XMVText.new(XMVText.convert_escapes(help_text()), 6, 0, c.size.x - 12)
	t.run()
	XMVText.paint(c, t.glyphs)


func _paint_cat(c: XMVCanvas) -> void:
	c.cursor(Rect2(category * (CAT_W + 12), 0, CAT_W, LH), mode == "category")
	XActorBook.paint_ops(c, cat_ops())


func _paint_list(c: XMVCanvas) -> void:
	if index >= 0 and floori(index / 2.0) >= top and floori(index / 2.0) < top + ROWS:
		var p := cell(index, top)
		c.cursor(Rect2(p.x, p.y, COL_W, LH), mode == "list")
	XActorBook.paint_ops(c, list_ops())


func _refresh() -> void:
	list_win.up_arrow = top > 0
	list_win.down_arrow = (top + ROWS) * 2 < data.size()
	for w in [help_win, cat_win, list_win]:
		w.refresh()


# ---- 操作 ----
func ok() -> void:
	XSound.system(1)
	if mode == "category":
		mode = "list"
		_select(0)
		return
	var e = current()
	if e != null:
		var s := XState.current
		if CATEGORIES[category] == "equip":
			if save_mode:
				if not XStarWarehouse.deposit_gear(s, e):
					XToast.show_text(PUSH_DCT_TEXT, true)
			else:
				XStarWarehouse.withdraw_gear(s, index)
		elif save_mode:
			XStarWarehouse.deposit_pet(s, index)
		else:
			XStarWarehouse.withdraw_pet(s, index)
	_reload()


func cancel() -> void:
	XSound.system(2)
	if mode == "list":
		mode = "category"
		index = -1
		_refresh()
	else:
		closed.emit()


func _select(i: int) -> void:
	index = i
	top = XMenu._scroll_to(floori(i / 2.0), top, ROWS)
	_refresh()


func _move(dx: int, dy: int, wrap: bool) -> void:
	if mode == "category":
		if dx != 0:
			var i := XMenu._move(category, dx, 2, wrap)
			if i != category:
				category = i
				XSound.system(0)
				top = 0  # setCategory：换分类时 resetScroll
				_reload()
		return
	# Window_Selectable（两列）：右／左逐格可跨行，上／下跳一行，到边不动
	var n := data.size()
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
	var pad := XMVWindow.PADDING
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if LIST_RECT.has_point(p):
				top = clampi(top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, ceili(data.size() / 2.0) - ROWS))
				_refresh()
		MOUSE_BUTTON_LEFT:
			if mode == "category" and CAT_RECT.has_point(p):
				var i := clampi(floori((p.x - pad) / (CAT_W + 12)), 0, 1)
				if i == category:
					ok()
				else:
					category = i
					XSound.system(0)
					top = 0
					_reload()
			elif mode == "list" and LIST_RECT.has_point(p):
				var row := floori((p.y - LIST_RECT.position.y - pad) / LH)
				var i := (top + row) * 2 + (1 if p.x - pad >= COL_STEP else 0)
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
