class_name XStarWarehouseScene
extends Control
## 星级仓库（Star_Warehouse 的 Scene_StarSaveWarehouse／Scene_StarWarehouse；黄金大厅通用仓库管理员 Map041 EV1「存放／取出」）。
## 一个画面两用：save_mode 真＝存放（列背包装备与宠物），假＝取出（列仓库）。数据与存取在 XStarWarehouse。
## 版面按冻结 v0.28 浏览器参照（tests/fixtures/star_warehouse_oracle.json，ui_reference/review_system_pages.js 的 star_warehouse）：
## - 说明窗被 HelpExtend 换成物品说明卡（Window_Help 只剩 400×1、不显示），所以分类窗在 (0,1,1280,64)：「装备／宠物」两列居中（格宽 620），
##   开场就激活、选第 1 项，列表跟着显示该类（无光标）；列表 (0,65,1280,655) 两列（格宽 602、间距 48）、行高 36、可见 17 行。
## - 列表一格：装备画图标 (x+2,y+2)＋名字 x+36（品质色，宽 = 596 − textWidth("000") − 36），不画数量、不画 NEW；
##   宠物只写名字（白字，x+0，宽 596 − textWidth("000")）：存放列 XPets.pet_name（出战的带「[出战]」），取出列原名（不去稀有度标签）。
## - 操作：分类确定 → 列表选第 1 项；列表确定 → 存入／取出一件，刷新后光标不动（取空了也停在原格）；取消逐级退回，分类取消关闭。
##   声音：只有普通确定音（Window_Selectable.processOk，isCurrentItemEnabled 恒真），存取成功也没有装备音效，出战宠物、空格、
##   不可存放都不蜂鸣（这与 PH 仓库 XWarehouseScene 不同，别「统一」）；不可存放另弹提示。
## - 说明卡：装备选中时显示（同物品页的说明卡）；宠物不显示——原版宠物是 Game_Enemy 没有 note，选中时 HelpExtend 读
##   item.note.split 抛错停机（O-待定，优化登记），这里不画卡、照常存取。

signal closed

const CAT_RECT := Rect2(0, 1, 1280, 64)
const LIST_RECT := Rect2(0, 65, 1280, 655)
const LH := 36.0
const CAT_W := 620.0
const COL_W := 602.0
const COL_STEP := 650.0
const ROWS := 17
const CATS := ["equip", "Pet"]

var save_mode := true
var mode := "category"       # category / list
var category := 0
var index := -1
var top := 0
var data: Array = []
var cat_win: XMVWindow
var list_win: XMVWindow
var help_card: XHelpCard


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	cat_win = XMVWindow.make(self, CAT_RECT, op, _paint_cat)
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	for w in [cat_win, list_win]:
		w.canvas.blink = true
	help_card = XHelpCard.new()
	add_child(help_card)
	help_card.show_for({})
	_reload()


func _symbol() -> String:
	return CATS[category]


## makeItemList：存放＝背包（防具在前）／宠物列表，取出＝仓库
func _reload() -> void:
	var s := XState.current
	if _symbol() == "equip":
		data = XStarWarehouse.carried_gear() if save_mode else XStarWarehouse.gear().duplicate()
	else:
		data = XPets.list(s).duplicate() if save_mode else XStarWarehouse.pets().duplicate()
	_refresh()


# ---- 绘制（操作 ["t", 文字, x, y, 宽, 行高, 对齐, 字号, 颜色]／["i", 图标, x, y]，与参照同形） ----
static func _t(text: String, x: float, y: float, w: float, color := XUI.TEXT, align := "left") -> Array:
	return ["t", text, x, y, w, LH, align, XUI.FONT_SIZE, color]


static func cat_ops() -> Array:
	return [_t("装备", 6, 0, CAT_W - 12, XUI.TEXT, "center"), _t("宠物", CAT_W + 12 + 6, 0, CAT_W - 12, XUI.TEXT, "center")]


static func cell(i: int, first_row := 0) -> Vector2:
	return Vector2((i % 2) * COL_STEP, (floori(i / 2.0) - first_row) * LH)


static func number_width() -> float:
	return XActorBook.js_width("000", XUI.FONT_SIZE)


## Window_StarItemList.drawItem
static func gear_ops(rec: Dictionary, p: Vector2) -> Array:
	var w := COL_W - 6.0 - number_width()
	return [["i", int(rec.get("iconIndex", 0)), p.x + 2.0, p.y + 2.0],
		_t(XQuality.list_name(rec), p.x + 36.0, p.y, w - 36.0, XGear.color(rec))]


static func pet_ops(text: String, p: Vector2) -> Array:
	return [_t(text, p.x, p.y, COL_W - 6.0 - number_width())]


func pet_label(pet: Dictionary) -> String:
	return XPets.pet_name(XState.current, pet) if save_mode else XStarWarehouse.stored_pet_name(pet)


func list_ops() -> Array:
	var ops := []
	for i in range(top * 2, mini((top + ROWS) * 2, data.size())):
		ops += gear_ops(data[i], cell(i, top)) if _symbol() == "equip" else pet_ops(pet_label(data[i]), cell(i, top))
	return ops


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
	for w in [cat_win, list_win]:
		w.refresh()
	_update_help()


## updateHelp：列表有光标且选中装备时出说明卡，贴着选中格
func _update_help() -> void:
	if mode != "list" or _symbol() != "equip" or index < 0 or index >= data.size():
		help_card.show_for({})
		return
	help_card.show_for(data[index])
	var p := cell(index, top)
	help_card.place_for_row(Rect2(LIST_RECT.position + Vector2(XMVWindow.PADDING, XMVWindow.PADDING) + p, Vector2(COL_W, LH)))


# ---- 操作 ----
func ok() -> void:
	XSound.system(1)  # 分类窗、列表的确定都只有普通确定音
	match mode:
		"category":
			mode = "list"
			_select(0)
		"list":
			_move_item()


## onItemOk：存入／取出一件；空格只刷新
func _move_item() -> void:
	var s := XState.current
	var e = data[index] if index >= 0 and index < data.size() else null
	if e != null:
		if _symbol() == "equip":
			if save_mode:
				var msg := XStarWarehouse.deposit_gear(s, e)
				if msg != "":
					XToast.show_text(msg, true)
			else:
				XStarWarehouse.withdraw_gear(s, e)
		elif save_mode:
			XStarWarehouse.deposit_pet(s, XPets.list(s).find_custom(func(p): return is_same(p, e)))
		else:
			XStarWarehouse.withdraw_pet(s, e)
	_reload()


func cancel() -> void:
	XSound.system(2)
	match mode:
		"list":
			mode = "category"
			index = -1
			_refresh()
		"category":
			help_card.show_for({})
			closed.emit()


func _select(i: int) -> void:
	index = i
	top = XMenu._scroll_to(floori(i / 2.0), top, ROWS)
	_refresh()


func _set_category(i: int) -> void:
	if i == category:
		return
	category = i
	XSound.system(0)
	top = 0
	_reload()


func _move(dx: int, dy: int, wrap: bool) -> void:
	match mode:
		"category":
			# Window_HorzCommand：左右（按住不回绕），上下不动
			if dx != 0:
				_set_category(XMenu._move(category, dx, 2, wrap))
		"list":
			# Window_Selectable（两列）：右／左逐格可跨行，首尾不回绕；上／下跳一行（±2），到边不动
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
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if LIST_RECT.has_point(p):
				top = clampi(top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, ceili(data.size() / 2.0) - ROWS))
				_refresh()
		MOUSE_BUTTON_LEFT:
			var pad := XMVWindow.PADDING
			if mode == "category" and CAT_RECT.has_point(p):
				var i := clampi(floori((p.x - pad) / (CAT_W + 12)), 0, 1)
				if i == category:
					ok()
				else:
					_set_category(i)
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
