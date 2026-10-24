class_name XInlayBook
extends Control
## 装备镶嵌图鉴（Star_EquipInlayBook 的 Scene_EquipInlayBook；方桌大厅魂灯商人 Map4 EV40 p1／p3「查看图鉴」＝
## 插件指令 StarEIBook GetAll 再 SceneManager.push(Scene_EquipInlayBook)）。数据是 Star_EquipmentMosaic 的符文之语配方（XDB Runewords）。
## 版面与逐条绘制按冻结 v0.28 浏览器参照（tests/fixtures/inlay_book_oracle.json，ui_reference/review_system_pages.js 的 inlay_book）：
## - 类型窗 (0,0,320,100)「武器／防具」，开场激活；目录窗 (0,100,320,620) 行高 36、可见 16 行，类型确定后才列出、选中第 1 项；
##   取消回类型窗时目录清空、状态窗清空。武器目录＝配方有武器模板的，防具目录＝有防具模板的（两者都有的两边都列）。
## - 状态窗 (320,0,960,720)，内容宽 932：「武器/防具镶嵌属性:」，下面三行八项能力（生命/魔法、物理攻击/物理防御/敏捷、魔法攻击/魔法防御/幸运，
##   横坐标按原版的 textWidth 空格算式），y 180「…镶嵌效果:」，y 216 模板备注 <pos … text=…> 的文字（前加两个空格，drawTextEx 逐字、\c[n]，
##   zidonghuanhang 放不下就换行、行高 34）；y 360「需求…镶嵌类型:」，y 396 起逐个类型名（间隔两个空格）；
##   y 504「镶嵌顺序:」与右下 y 648「镶嵌顺序为从左到右显示」，y 540 起逐个宝珠（drawItemName，每行 4 个、间隔 236.5）。
## - 解锁：原版 $gameParty.StarEMosaicOpt 记形成过的符文之语，没形成的写「？？？」；但正式版唯一的入口（Map4 EV40、Map66、Map137）
##   都先执行 StarEIBook GetAll 全部解锁，玩家看到的永远是全部，所以这里不记解锁、全部列出（GetAll 无操作）。

signal closed

const TYPE_RECT := Rect2(0, 0, 320, 100)
const INDEX_RECT := Rect2(0, 100, 320, 620)
const STATUS_RECT := Rect2(320, 0, 960, 720)
const LH := 36.0
const ROWS := 16
const ROW_W := 280.0                        # 内容宽 292 − textPadding 6×2
const CW := 932.0                           # 状态窗内容宽
const COL2 := CW / 2.0 + 7.0                # column2x 473
const COLW := CW / 2.0 - 14.0               # columnWidth 452
const TYPES := ["武器", "防具"]
const ATTRS := ["生命", "魔法", "物理攻击", "物理防御", "魔法攻击", "魔法防御", "敏捷", "幸运"]

var type_index := 0
var index := -1
var top := 0
var mode := "type"           # type / index
var lists := [[], []]        # 武器、防具配方
var list: Array = []         # 目录当前列出的（取消后清空）
var type_win: XMVWindow
var index_win: XMVWindow
var status_win: XMVWindow
var _status_ops: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	lists = recipes()
	type_win = XMVWindow.make(self, TYPE_RECT, XUI.MENU_WINDOW_OPACITY, _paint_type)
	index_win = XMVWindow.make(self, INDEX_RECT, XUI.MENU_WINDOW_OPACITY, _paint_index)
	status_win = XMVWindow.make(self, STATUS_RECT, XUI.MENU_WINDOW_OPACITY, _paint_status)
	type_win.canvas.blink = true
	index_win.canvas.blink = true
	_refresh()


# ---- 数据 ----
## Scene_EquipInlayBook.create 的 _WIdlist／_AIdlist：按配方编号，有武器／防具模板的分别列入
static func recipes() -> Array:
	var out := [[], []]
	for r in XDB.table("Runewords"):
		if not r is Dictionary:
			continue
		if int(r.get("weapon", 0)) > 0:
			out[0].append(r)
		if int(r.get("armor", 0)) > 0:
			out[1].append(r)
	return out


static func _w(s: String) -> float:
	return XActorBook.js_width(s, XUI.FONT_SIZE)


static func _t(text: String, x: float, y: float, w: float, color := XUI.TEXT, align := "left") -> Array:
	return ["t", text, x, y, w, LH, align, XUI.FONT_SIZE, color]


## 模板备注里 <pos=… text=… size=… color=… line=… align=…> 的 text（只取原版正则匹配到的行）
static func pos_texts(note: String) -> Array:
	var out := []
	var re := RegEx.create_from_string("(?i)<pos=(.+) text=(.+) size=(.+) color=(.+) line=(true|false) align=(0|1|2)>")
	for line in XEnemyBookPage.notetags(note):
		var m := re.search(line)
		if m != null:
			out.append(m.get_string(2))
	return out


## Window_Base.drawTextEx：逐字 drawText(字, x, y, 字宽×2, 行高)，只有 \c[n]；zidonghuanhang 放不下（内容宽 − x < 字宽）先换行。
## installDisplayPreferencesRuntime 的 convertEscapeCharacters 先把「全伤」写成「全属性伤害」（CodexDisplay.text＝XHelpCard._terms）
static func text_ex_ops(raw: String, x0: float, y0: float) -> Array:
	var ops := []
	var s := XMVText.convert_escapes(XHelpCard._terms(raw))
	var color := XUI.TEXT
	var x := x0
	var y := y0
	var lh := XUI.FONT_SIZE + 8.0
	var i := 0
	var code := RegEx.create_from_string("^\u001b[cC]\\[(\\d+)\\]")
	while i < s.length():
		var m := code.search(s.substr(i))
		if m != null:
			color = XUI.text_color(int(m.get_string(1)))
			i += m.get_string(0).length()
			continue
		var c := s[i]
		if c == "\n":
			x = x0
			y += lh
			i += 1
			continue
		var w := _w(c)
		if CW - x < w:
			x = x0
			y += lh
		ops.append(["t", c, x, y, w * 2.0, lh, "left", XUI.FONT_SIZE, color])
		x += w
		i += 1
	return ops


## Window_EquipInlayBookStatus.drawAllContents（kind 0 武器、1 防具）
static func status_ops(r: Dictionary, kind: int) -> Array:
	var ops := []
	if r.is_empty():
		return ops
	var weapon := kind == 0
	var tpl_id := int(r.get("weapon" if weapon else "armor", 0))
	var x := 0.0
	var y := 0.0
	var head := "武器" if weapon else "防具"
	if tpl_id > 0:
		ops.append(_t(head + "镶嵌属性:", x, y, COLW))
	y += LH
	var sp7 := _w("       ")
	var c3 := COL2 / 3.0
	var label_pos := [[0, x, y], [1, c3 + sp7, y], [2, x, y + LH], [3, c3 + sp7, y + LH], [6, COL2 - sp7, y + LH],
		[4, x, y + LH * 2], [5, c3 + sp7, y + LH * 2], [7, COL2 - sp7, y + LH * 2]]
	for p in label_pos:
		ops.append(_t(ATTRS[p[0]], p[1], p[2], COLW, XUI.SYSTEM))
	if tpl_id <= 0:
		return ops
	var tpl := XDB.rec("Weapons" if weapon else "Armors", tpl_id)
	var params: Array = tpl.get("params", [0, 0, 0, 0, 0, 0, 0, 0])
	var v := func(i: int) -> String: return XEnemyBookPage.js_num(float(params[i]))
	ops.append(_t(v.call(0), x + _w(ATTRS[0] + "  "), y, COLW))
	ops.append(_t(v.call(1), c3 + _w(ATTRS[1] + "        "), y, COLW))
	ops.append(_t(v.call(2), x + _w(ATTRS[2] + "  "), y + LH, COLW))
	ops.append(_t(v.call(3), c3 + _w(ATTRS[3] + "        "), y + LH, COLW))
	ops.append(_t(v.call(6), COL2 + _w(ATTRS[6]) - _w("      "), y + LH, COLW))
	ops.append(_t(v.call(4), x + _w(ATTRS[4] + "  "), y + LH * 2, COLW))
	ops.append(_t(v.call(5), c3 + _w(ATTRS[5] + "        "), y + LH * 2, COLW))
	ops.append(_t(v.call(7), COL2 + _w(ATTRS[7]) - _w("      "), y + LH * 2, COLW))
	y += LH * 4
	ops.append(_t(head + "镶嵌效果:", x, y, COLW))
	y += LH
	# 每条 pos 行都画在同一 y（原版循环里不下移）
	for text in pos_texts(str(tpl.get("note", ""))):
		ops += text_ex_ops("  " + text, x, y)
	y += LH * 4
	ops.append(_t("需求" + head + "镶嵌类型:", x, y, COLW))
	y += LH
	var names: Array = XDB.system().get("weaponTypes" if weapon else "equipTypes", [])
	var nx := _w("  ") + x
	for t in r.get("weaponTypes" if weapon else "armorSlots", []):
		var n := str(names[int(t)]) if int(t) < names.size() else "undefined"
		ops.append(_t(n, nx, y, COLW))
		nx += _w(n + "  ")
	y += LH * 2
	var mats: Array = r.get("materials", [])
	if not mats.is_empty():
		y += LH
		ops.append(_t("镶嵌顺序:", x, y, COLW))
		ops.append(_t("镶嵌顺序为从左到右显示", x, LH * 18, CW, XUI.TEXT, "right"))
		y += LH
	nx = _w("  ") + x
	for i in mats.size():
		if i == 4 or i == 8 or i == 12:
			nx -= COL2 / 2.0 * 4.0
			y += LH
		# Window_Base.drawItemName：图标 (x+2, y+2)，名字 x+36、宽 columnWidth−36、品质色
		var item := XDB.rec("Items", int(mats[i]))
		if not item.is_empty():
			ops.append(["i", int(item.get("iconIndex", 0)), nx + 2.0, y + 2.0])
			ops.append(_t(str(item.get("name", "")), nx + 36.0, y, COLW - 36.0, XQuality.list_color(item)))
		nx += COL2 / 2.0
	return ops


# ---- 绘制 ----
func _paint_type(c: XMVCanvas) -> void:
	c.cursor(Rect2(0, type_index * LH, c.size.x, LH), mode == "type")
	for i in TYPES.size():
		c.text(TYPES[i], 6, i * LH, ROW_W)


func _paint_index(c: XMVCanvas) -> void:
	if index >= top and index < top + ROWS:
		c.cursor(Rect2(0, (index - top) * LH, c.size.x, LH), mode == "index")
	for i in range(top, mini(top + ROWS, list.size())):
		c.text(str(list[i].get("name", "")), 6, (i - top) * LH, ROW_W)


func _paint_status(c: XMVCanvas) -> void:
	XActorBook.paint_ops(c, _status_ops)


func _refresh() -> void:
	index_win.up_arrow = top > 0
	index_win.down_arrow = top + ROWS < list.size()
	for w in [type_win, index_win, status_win]:
		w.refresh()


# ---- 操作 ----
## Scene_EquipInlayBook.update：目录选中项变了就画状态窗
func _select(i: int) -> void:
	index = i
	top = XMenu._scroll_to(index, top, ROWS)
	_status_ops = status_ops(list[index], type_index) if index >= 0 and index < list.size() else []
	_refresh()


## onRangeOk：列出该类目录并选中第 1 项
func ok() -> void:
	if mode != "type":
		return  # 目录窗没有确定处理
	XSound.system(1)
	mode = "index"
	list = lists[type_index]
	top = 0
	if list.is_empty():
		index = -1
		_refresh()
	else:
		_select(0)


## OnCancel：目录清空、状态窗清空，回类型窗；类型窗取消关闭
func cancel() -> void:
	XSound.system(2)
	if mode == "index":
		mode = "type"
		list = []
		index = -1
		top = 0
		_status_ops = []
		_refresh()
	else:
		closed.emit()


func _move(d: int, wrap: bool) -> void:
	if mode == "type":
		var i := XMenu._move(type_index, d, TYPES.size(), wrap)
		if i != type_index:
			type_index = i
			XSound.system(0)
			_refresh()
	elif not list.is_empty():
		var i := XMenu._move(index, d, list.size(), wrap)
		if i != index:
			XSound.system(0)
			_select(i)


## Window_Selectable.cursorPagedown／Pageup（目录窗）
func _page(d: int) -> void:
	if mode != "index" or list.is_empty():
		return
	var max_top := maxi(0, list.size() - ROWS)
	if d > 0 and top + ROWS < list.size():
		top = mini(top + ROWS, max_top)
		index = mini(index + ROWS, list.size() - 1)
	elif d < 0 and top > 0:
		top = maxi(top - ROWS, 0)
		index = maxi(index - ROWS, 0)
	else:
		return
	XSound.system(0)
	_select(index)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p: Vector2 = event.position
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			cancel()
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP:
			if mode == "index" and INDEX_RECT.has_point(p):
				top = clampi(top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, list.size() - ROWS))
				_refresh()
		MOUSE_BUTTON_LEFT:
			if mode == "type" and TYPE_RECT.has_point(p):
				var row := floori((p.y - TYPE_RECT.position.y - XMVWindow.PADDING) / LH)
				if row >= 0 and row < TYPES.size():
					if row == type_index:
						ok()
					else:
						type_index = row
						XSound.system(0)
						_refresh()
			elif mode == "index" and INDEX_RECT.has_point(p):
				var row := floori((p.y - INDEX_RECT.position.y - XMVWindow.PADDING) / LH)
				var i := top + row
				if row >= 0 and row < ROWS and i < list.size() and i != index:
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
		_move(1 if event.is_action_pressed("ui_down", true) else -1, not event.is_echo())
	elif event.is_action_pressed("ui_page_down") or event.is_action_pressed("ui_page_up"):
		get_viewport().set_input_as_handled()
		_page(1 if event.is_action_pressed("ui_page_down") else -1)
