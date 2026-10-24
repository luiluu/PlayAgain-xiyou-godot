class_name XTrainingScene
extends Control
## 修炼（Star_ActorAttributePlusPoints 的 Scene_ActorAttributePlusPoints；魔塔教师、二十六层小萝莉等事件 SceneManager.push）。数据在 XTraining。
## 版面与逐条绘制按冻结 v0.28 浏览器参照（tests/fixtures/training_ui_oracle.json）；窗口不透明度照 MOG 菜单 30：
## - 队员目录 (0,0,426,720)：$gameParty.members() 的名字，光标一直显示（目录不活动时不闪）。
## - 状态窗 (426,0,854,720)，内容宽 826：SV 图以窗口内 (103.25, 103.25) 为中心（0-1-2-1 每 12 帧）；名字、「等级:N」在 x 140，
##   八项能力值「生命 485」照原版的三列 280／462／630 与三行（敏捷、幸运在第三列，第一行第三列空着）。
## - 精魂窗 (0,656,426,64)：图标 272，「数值＋精魂」在 x 34.67。
## - 底部「修炼」窗 (426.67,656,854,64)：一行（原版用 44 个空格把「修炼」推到中间），目录确定后才可选。
##   本工程字体的空格比原版窄，「修炼」按原版实测的空格宽（SPACE_W）定横坐标（ui_reference review_system_pages 的 training 读数）。
## - 修炼项窗 (426.67,136,854,388)：一直显示，XTraining.lines 的行文；「修炼」确定后才可选，修炼后留在本窗。
## 流程：目录确定 → 底部「修炼」→ 修炼项确定（XTraining.confirm，提示照原版 $.toaster）；修炼项取消回底部，底部取消回目录，目录取消关闭。
## 优化 O-082（ALIGN_COST，可回退）：原版用空格补齐「下一级费用」，中文字宽不同，各行对不齐（参照截图里差 3～20 像素）；
## 这里把「下一级费用…」画在同一列（各行左半段最宽者之后），文字不变。设 false 恢复原版的空格排法。

signal closed

const INDEX_RECT := Rect2(0, 0, 426, 720)
const STATUS_RECT := Rect2(426, 0, 854, 720)
const GOLD_RECT := Rect2(0, 656, 426, 64)
const BOTTOM_RECT := Rect2(1280.0 / 3.0, 656, 854, 64)
const LIST_RECT := Rect2(1280.0 / 3.0, 136, 854, 388)
const LH := 36.0
const CW := 826.0
const COL2 := CW / 2.0 + 7.0              # 420
const COLW := CW / 2.0 - 14.0             # 399
const INDEX_ROWS := 19                    # floor((720 − 28) / 36)
const LIST_ROWS := 10                     # fittingHeight(10)
const SPRITE_CENTER := Vector2(CW / 8.0, CW / 8.0)
const ATTR := ["生命", "魔法", "物理攻击", "物理防御", "魔法攻击", "魔法防御", "敏捷", "幸运"]
## drawAllContents 的八项：[能力编号, x, 行]
const ATTR_CELLS := [[0, COL2 / 3.0 * 2.0, 0], [1, COL2 / 10.0 * 11.0, 0], [2, COL2 / 3.0 * 2.0, 1], [3, COL2 / 10.0 * 11.0, 1],
	[6, COL2 / 10.0 * 15.0, 1], [4, COL2 / 3.0 * 2.0, 2], [5, COL2 / 10.0 * 11.0, 2], [7, COL2 / 10.0 * 15.0, 2]]
const BOTTOM_TEXT := "                                            修炼"
## 原版 CodexUserUI 26 号下 44 个空格实测宽 317.28125（training_bottom 读数），即每个空格 7.2109375
const SPACE_W := 317.28125 / 44.0
const GOLD_ICON := 272
const COST_MARK := "下一级费用"

static var ALIGN_COST := true

var mode := "index"          # index / bottom / list
var index := 0
var top := 0
var cmd := -1                # 底部「修炼」窗的选择（-1 不选）
var row := -1                # 修炼项窗的选择
var index_win: XMVWindow
var status_win: XMVWindow
var gold_win: XMVWindow
var bottom_win: XMVWindow
var list_win: XMVWindow
var _status_ops: Array = []
var _sprite_tex: Texture2D
var _frame := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(XAchievementPopup.MBACK_GROUP)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var op := XUI.MENU_WINDOW_OPACITY
	index_win = XMVWindow.make(self, INDEX_RECT, op, _paint_index)
	status_win = XMVWindow.make(self, STATUS_RECT, op, _paint_status)
	gold_win = XMVWindow.make(self, GOLD_RECT, op, _paint_gold)
	bottom_win = XMVWindow.make(self, BOTTOM_RECT, op, _paint_bottom)
	list_win = XMVWindow.make(self, LIST_RECT, op, _paint_list)
	for w in [index_win, bottom_win, list_win]:
		w.canvas.blink = true
	_select_actor()


func _process(_delta: float) -> void:
	_frame += 1
	if _sprite_tex != null and _frame % 12 == 0:
		status_win.canvas.queue_redraw()


# ---- 数据 ----
func members() -> Array:
	return XState.current.members()


func current() -> XActor:
	var l := members()
	return l[index] if index >= 0 and index < l.size() else null


static func _t(text: String, x: float, y: float, w: float, color := XUI.TEXT) -> Array:
	return ["t", text, x, y, w, LH, "left", XUI.FONT_SIZE, color]


## Window_ActorAttributePlusPointsIndex.drawItem
static func index_ops(s: XState) -> Array:
	var ops := []
	var l := s.members()
	for i in l.size():
		ops.append(_t((l[i] as XActor).display_name(), 6, i * LH, INDEX_RECT.size.x - 28.0 - 12.0))  # itemRectForText：398 − 12
	return ops


## Window_ActorAttributePlusPointsStatus.drawAllContents
static func status_ops(a: XActor) -> Array:
	var ops := []
	if a == null:
		return ops
	ops.append(_t(a.display_name(), COL2 / 3.0, 0, COLW))
	for cell in ATTR_CELLS:
		ops.append(_t("%s %d" % [ATTR[cell[0]], int(a.param(cell[0]))], cell[1], LH * cell[2], COLW))
	ops.append(_t("等级:" + str(a.level), COL2 / 3.0, LH, COLW))
	return ops


## Window_ActorAttributePlusPointsGold.drawCurrencyValue：先画「数值＋单位」（单位宽 2/3 处），再在 0 画图标
static func gold_ops(s: XState) -> Array:
	var unit := str(XDB.system().get("currencyUnit", ""))
	var unit_w := minf(80.0, XActorBook.js_width(unit, XUI.FONT_SIZE))
	var col_w := (GOLD_RECT.size.x - 28.0) / 2.0 - 14.0
	return [_t(str(s.gold) + unit, unit_w * 2.0 / 3.0, 0, col_w * 2.0 - unit_w - 6.0), ["i", GOLD_ICON, 0.0, 0.0]]


static func bottom_ops() -> Array:
	return [_t(BOTTOM_TEXT, 6, 0, CW - 12.0)]


## Window_AddLittleConfirm：每行一项（行文见 XTraining.line）；ALIGN_COST 时「下一级费用…」另起一段画在同一列
static func list_ops(s: XState, actor_id: int) -> Array:
	var lines := XTraining.lines(s, actor_id)
	var ops := []
	if not ALIGN_COST:
		for i in lines.size():
			ops.append(_t(lines[i], 6, i * LH, CW - 12.0))
		return ops
	var col := 0.0
	var heads := []
	for l in lines:
		var at := str(l).find(COST_MARK)
		var head := str(l).substr(0, at).strip_edges(false, true) if at >= 0 else str(l)
		heads.append(head)
		if at >= 0:
			col = maxf(col, XActorBook.js_width(head, XUI.FONT_SIZE))
	col = ceilf(col + XActorBook.js_width("    ", XUI.FONT_SIZE))
	for i in lines.size():
		var l := str(lines[i])
		var at := l.find(COST_MARK)
		ops.append(_t(heads[i], 6, i * LH, CW - 12.0))
		if at >= 0:
			ops.append(_t(l.substr(at), 6 + col, i * LH, CW - 12.0 - col))
	return ops


# ---- 绘制 ----
static func _paint_ops(c: XMVCanvas, ops: Array) -> void:
	for o in ops:
		if o[0] == "i":
			c.icon(int(o[1]), o[2], o[3])
		else:
			c.text(o[1], o[2], o[3], o[4], o[6], o[8], int(o[7]), o[5])


func _paint_index(c: XMVCanvas) -> void:
	var n := members().size()
	if index >= top and index < top + INDEX_ROWS and n > 0:
		c.cursor(Rect2(0, (index - top) * LH, c.size.x, LH), mode == "index")
	var ops := index_ops(XState.current)
	for i in range(top, mini(top + INDEX_ROWS, ops.size())):
		var o: Array = ops[i].duplicate()
		o[3] = (i - top) * LH
		_paint_ops(c, [o])


func _paint_status(c: XMVCanvas) -> void:
	if _sprite_tex != null:
		var center := SPRITE_CENTER - Vector2(XMVWindow.PADDING, XMVWindow.PADDING)
		var cw := _sprite_tex.get_width() / 9.0
		var ch := _sprite_tex.get_height() / 6.0
		var src := Rect2([0, 1, 2, 1][floori(_frame / 12.0) % 4] * cw, 0, cw, ch)
		var scale := 1.0
		if cw > CW / 2.0:
			scale = CW / cw / 2.0
		var sz := src.size * scale
		c.draw_texture_rect_region(_sprite_tex, Rect2(center - sz / 2.0, sz), src)
	_paint_ops(c, _status_ops)


func _paint_gold(c: XMVCanvas) -> void:
	_paint_ops(c, gold_ops(XState.current))


func _paint_bottom(c: XMVCanvas) -> void:
	if cmd == 0:
		c.cursor(Rect2(0, 0, c.size.x, LH), mode == "bottom")
	# 行首空格按原版空格宽折成横坐标，免得「修炼」随本工程字体的空格宽偏左
	for o in bottom_ops():
		var word := str(o[1]).strip_edges(true, false)
		var pad := (str(o[1]).length() - word.length()) * SPACE_W
		c.text(word, o[2] + pad, o[3], o[4] - pad, o[6], o[8], int(o[7]), o[5])


func _paint_list(c: XMVCanvas) -> void:
	var a := current()
	if a == null:
		return
	if row >= 0 and row < LIST_ROWS:
		c.cursor(Rect2(0, row * LH, c.size.x, LH), mode == "list")
	_paint_ops(c, list_ops(XState.current, a.actor_id))


# ---- 操作 ----
## Scene_ActorAttributePlusPoints.update：目录选中项变了刷新状态窗、精魂窗与修炼项
func _select_actor() -> void:
	var a := current()
	_status_ops = status_ops(a)
	_sprite_tex = null
	if a != null:
		var p := XDB.img_path("sv_actors", str(a.data().get("battlerName", "")))
		_sprite_tex = load(p) if p != "" else null
	_refresh()


func _refresh() -> void:
	index_win.up_arrow = top > 0
	index_win.down_arrow = top + INDEX_ROWS < members().size()
	for w in [index_win, status_win, gold_win, bottom_win, list_win]:
		w.refresh()


func select(i: int) -> void:
	if i == index:
		return
	index = i
	XSound.system(0)
	top = XMenu._scroll_to(index, top, INDEX_ROWS)
	_select_actor()


func ok() -> void:
	match mode:
		"index":
			if members().is_empty():
				return
			XSound.system(1)  # onRangeOk → startBottomConfirmWindow
			mode = "bottom"
			cmd = 0
		"bottom":
			XSound.system(1)  # onBottomConfirmOk → startConfirmWindow
			mode = "list"
			cmd = -1
			row = 0
		"list":
			var a := current()
			var listed := XTraining.listed()
			if a == null or row < 0 or row >= listed.size():
				return
			XSound.system(1)
			var text := XTraining.confirm(XState.current, a.actor_id, int(listed[row].id))
			if text != "":
				XToast.show_text(text, true)
			_select_actor()
			return
	_refresh()


func cancel() -> void:
	XSound.system(2)
	match mode:
		"index":
			closed.emit()
			return
		"bottom":
			mode = "index"  # onBottomConfirmCancel
			cmd = -1
		"list":
			mode = "bottom"  # onConfirmCancel
			row = -1
			cmd = 0
	_refresh()


func _move(d: int, wrap: bool) -> void:
	match mode:
		"index":
			if not members().is_empty():
				select(XMenu._move(index, d, members().size(), wrap))
		"list":
			var n := XTraining.listed().size()
			if n > 0:
				row = XMenu._move(row, d, n, wrap)
				XSound.system(0)
				_refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()


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
