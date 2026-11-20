class_name XSkinMenuTreePage
extends XSkinTemplatePage
## 【cc·天启篇·未经审查】T299 卡 K：版型四「层级菜单页」通用件（T254 3.0 版型四、3.6）。
## 原来用一个选择窗（XChoiceWindow）一层层串起来的页（宝珠坊、种族祝福；以后天衣铺、屠苏器谱、星谱同样套）换成模板页摆法：
## - 不画分类环；左块放这一页的主视觉（left_draw 回调，或 left_icon＋left_lines）；
## - 选项进中间列表（列表标题＝面包屑最后一段，标题下一行面包屑 XSkinCrumb，每进一层多一段）；
## - 原来窗口上方的「说明几行」进右牌：第一行作牌名，其余进「说明」节，按牌宽自动折行（不再按 48 半角宽硬折）；
## - 结果页（opts.result）牌名旧金，牌底一枚「知道了」（＝取消，回到上一层，同旧页的取消）；
## - 确认页（opts.confirm）不换列表，弹统一确认弹窗 XSkinConfirm（钮＝原来的两行，说明几行进正文）。
## 接口和 XChoiceWindow 一样（rows／index／open／ok／cancel／move／page），旧页的回调一行不用改：
##   页面的 choose(rows, ok, cancel, lines) 里 if tree != null: tree.open(rows, ok, cancel, lines, opts) else: choice.open(…)。
## 行文一个字不改，只换地方放：行尾的「×N」「（…）」「→ …」挪到行尾右对齐（split_row；页面可给 row_view 自己摆）。
## 系统音同 XChoiceWindow（换行 0、确定 1、取消 2、不可选蜂鸣 3）。

## T299 卡 K 回退开关：false＝制作、宝珠坊、种族祝福三页都回旧页（西游存档、XUiSkin 关着时本来就是旧页）
static var ENABLED := true
const CRUMB_GAP := 4.0
const LEFT_ICON := 96.0

# ---- 跟 XChoiceWindow 同名的状态（测试、页面照旧用）----
var rows: Array = []
## 没折行的说明几行（右牌用）
var info: Array = []
var index := 0
var top := 0
var _ok: Callable
var _cancel: Callable

# ---- 这一层的摆法 ----
var opts: Dictionary = {}
var crumb: Array = []
## 左块主视觉：func(ctrl: Control, row: Dictionary)；没给就画 left_icon（图标号）＋left_lines（几行小字）
var left_draw: Callable
var left_icon := 0
var left_lines: Array = []
var crumb_node: XSkinCrumb
var dialog: XSkinConfirm
## 列表正显示的那一层（确认弹窗开着时列表不换，仍是上一层）
var _shown: Array = []
var _shown_opts: Dictionary = {}
var _syncing := false


func _init(page_title := "") -> void:
	name = "SkinMenuTree"
	title = page_title
	group_key = ""
	columns = 1
	row_height = XUiSkin.ROW_H
	right_w = 352.0
	show_ring = false
	auto_nav = false
	focus = "list"
	currencies = []
	hint_list = [["确定", "选择"], ["取消", "返回"]]


func _ready() -> void:
	super()
	list.empty_center = true
	list.right2_w = 0.0
	crumb_node = XSkinCrumb.new()
	list_panel.add_child(crumb_node)
	list.index_changed.connect(_on_list_index)
	list.activated.connect(_on_list_click)
	card_button.connect(func(_i): cancel())
	layout.left.draw.connect(_draw_left)
	gui_input.connect(_on_gui)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_place_crumb()


func relayout() -> void:
	super()
	_place_crumb()


func _place_crumb() -> void:
	if crumb_node == null or list == null:
		return
	var cs := layout.center.size
	var lx := list.position.x
	crumb_node.position = Vector2(XUiSkin.PAD + 8, LIST_TOP - 6.0)
	crumb_node.size = Vector2(cs.x - XUiSkin.PAD * 2 - 8, XSkinCrumb.H)
	var shift := XSkinCrumb.H + CRUMB_GAP
	list.position = Vector2(lx, LIST_TOP + shift)
	var n := floori((cs.y - LIST_TOP - shift - FOOTER_H) / float(row_height))
	list.size = Vector2(cs.x - lx - 8.0, n * row_height)


# ---- 跟 XChoiceWindow 一样的接口 ----

## rows：[{label, enabled, …}]；ok(row)、cancel()；lines：说明几行（不折行）；
## o：{crumb: [...], result: bool, confirm: {title, danger}, row_view: Callable(row)->Dictionary, card_for: Callable(row)->Dictionary,
##     list_title: String, hints: Array}
func open(list_rows: Array, ok_cb: Callable, cancel_cb: Callable, lines := [], o := {}) -> void:
	rows = list_rows
	info = lines
	_ok = ok_cb
	_cancel = cancel_cb
	opts = o
	index = 0
	top = 0
	if o.has("crumb"):
		crumb = o.crumb
	visible = true
	if o.has("confirm"):
		_open_dialog()
	else:
		_close_dialog()
		_shown = rows
		_shown_opts = o
	sync()


func current_row() -> Dictionary:
	var arr := rows if dialog == null else _shown
	var i := index if dialog == null else clampi(list.index, 0, maxi(_shown.size() - 1, 0))
	return arr[i] if i >= 0 and i < arr.size() else {}


func ok() -> void:
	if index < 0 or index >= rows.size():
		return
	var r: Dictionary = rows[index]
	if r.get("enabled", true) == false:
		XSound.system(3)
		return
	XSound.system(1)
	_close_dialog()
	_ok.call(r)


func cancel() -> void:
	XSound.system(2)
	_close_dialog()
	if _cancel.is_valid():
		_cancel.call()


func move(d: int, wrap_around := true) -> void:
	if rows.is_empty():
		return
	var old := index
	index = XMenu._move(index, d, rows.size(), wrap_around)
	if index != old:
		XSound.system(0)
	sync()


func page(d: int) -> void:
	if rows.is_empty() or dialog != null:
		return
	var old := index
	var r := XMenu.page(list.top_row, index, rows.size(), list.visible_rows(), d)
	index = r[1]
	if index != old:
		XSound.system(0)
	sync()


# ---- 画 ----

func sync() -> void:
	if layout == null:
		return
	_syncing = true
	crumb_node.set_parts(crumb if crumb.size() > 1 else [])   # 第 0 层只有页名：标题已写，面包屑不重复
	list_title = str(_shown_opts.get("list_title", crumb.back() if not crumb.is_empty() else title))
	if dialog == null:
		var view: Array = []
		for r in rows:
			view.append(row_item(r))
		set_items(view, clampi(index, 0, maxi(rows.size() - 1, 0)))
		top = list.top_row
		set_card(card_data(current_row()))
	else:
		dialog.setup(_dialog_data())
	set_hint_list(_hints())
	_syncing = false
	_place_crumb()
	list_panel.queue_redraw()
	layout.left.queue_redraw()
	top_layer.queue_redraw()


## 一行怎么摆：页面给了 row_view 就用它，否则 split_row
func row_item(r: Dictionary) -> Dictionary:
	var it := {}
	var rv = _shown_opts.get("row_view", null)
	if rv is Callable and (rv as Callable).is_valid():
		it = (rv as Callable).call(r)
	if it.is_empty():
		it = split_row(str(r.get("label", "")))
	if r.get("enabled", true) == false:
		it.disabled = true
	if not it.has("icon"):
		it.icon = 0
	return it


## 行尾的数量、价钱挪到右边（字不改）：「名 ×3」→ 名｜×3；「兑换 5 枚（50 残片）」→ 兑换 5 枚｜50 残片；「分解 1 颗 → 10 残片」→ 分解 1 颗｜10 残片
static func split_row(label: String) -> Dictionary:
	var m := RegEx.create_from_string("^(.+?) (×\\d+)$").search(label)
	if m:
		return {"text": m.get_string(1), "right": m.get_string(2), "right_color": XUiSkin.GOLD_LIGHT}
	m = RegEx.create_from_string("^(.+?)（([^（）]*\\d[^（）]*)）$").search(label)
	if m:
		return {"text": m.get_string(1), "right": m.get_string(2), "right_color": XUiSkin.GOLD_LIGHT}
	m = RegEx.create_from_string("^(.+?) → (.+)$").search(label)
	if m:
		return {"text": m.get_string(1), "right": m.get_string(2), "right_color": XUiSkin.GOLD_LIGHT}
	return {"text": label}


## 右牌：页面给了 card_for 且返回非空就用它；否则「说明几行」：第一行作牌名、其余进「说明」节
func card_data(r: Dictionary) -> Dictionary:
	var cf = _shown_opts.get("card_for", null)
	if cf is Callable and (cf as Callable).is_valid() and not r.is_empty():
		var d: Dictionary = (cf as Callable).call(r)
		if not d.is_empty():
			return d
	return info_card(info, bool(_shown_opts.get("result", false)))


static func info_card(lines: Array, result := false) -> Dictionary:
	var d := {"title": str(lines[0]) if not lines.is_empty() else "", "title_color": XUiSkin.GOLD if result else XUiSkin.TEXT, "sections": [], "buttons": []}
	if lines.size() > 1:
		d.sections = [{"title": "说明", "rows": lines.slice(1).map(func(t): return {"text": str(t), "color": XUiSkin.TEXT_2})}]
	if result:
		d.buttons = [{"text": "知道了", "primary": true}]
	return d


func _hints() -> Array:
	if dialog != null:
		return [["← / →", "切换"], ["确定", "选择"], ["取消", "返回"]]
	var h = _shown_opts.get("hints", null)
	if h is Array:
		return h
	return [["确定", "选择"], ["取消", "离开" if crumb.size() <= 1 else "返回"]]


func _draw_left() -> void:
	if left_draw.is_valid():
		left_draw.call(layout.left, current_row())
		return
	var lb := layout.left.size
	var c := Vector2(lb.x / 2.0, lb.y / 2.0 - 60.0)
	var tex := XUiSkin.icon(left_icon) if left_icon > 0 else null
	if tex != null:
		layout.left.draw_circle(c, LEFT_ICON * 0.72, Color(XUiSkin.GOLD, 0.08))
		layout.left.draw_arc(c, LEFT_ICON * 0.72, 0, TAU, 48, Color(XUiSkin.GOLD, 0.35), 1.5, true)
		layout.left.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layout.left.draw_texture_rect(tex, Rect2(c - Vector2(LEFT_ICON, LEFT_ICON) / 2.0, Vector2(LEFT_ICON, LEFT_ICON)), false)
	var body := XUiSkin.font("body")
	var y := c.y + LEFT_ICON * 0.72 + 36.0
	for ln in left_lines:
		var t := str(ln)
		var fs := XUiSkin.fs(XUiSkin.FS_AUX)
		var fit := XSkinList.fit_text(body, t, lb.x - 16.0, fs, 15)
		var tw := body.get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x
		XUiSkin.ds(layout.left, body, Vector2((lb.x - tw) / 2.0, y), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), XUiSkin.TEXT_2)
		y += fs * 1.6


# ---- 确认弹窗 ----

func _dialog_data() -> Dictionary:
	var c: Dictionary = opts.get("confirm", {})
	var buttons := rows.map(func(r): return {"text": str(r.get("label", "")), "disabled": r.get("enabled", true) == false})
	return {"title": str(c.get("title", str(rows[0].get("label", "")) + "？" if not rows.is_empty() else "")), "body": "\n".join(info.map(func(t): return str(t))),
		"buttons": buttons, "danger": bool(c.get("danger", false)), "index": index}


func _open_dialog() -> void:
	if dialog == null:
		dialog = XSkinConfirm.new()
		dialog.chosen.connect(func(i):
			index = i
			ok())
		dialog.index_changed.connect(func(i):
			if _syncing:
				return
			if i != index:
				index = i
				XSound.system(0))
		dialog.cancelled.connect(cancel)
		add_child(dialog)
	var d := _dialog_data()
	d.erase("index")
	dialog.setup(d)
	index = dialog.index   # 危险操作默认停在最后一枚（取消），普通的停第一枚


func _close_dialog() -> void:
	if dialog != null:
		dialog.queue_free()
		dialog = null


# ---- 按键、点击 ----

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if dialog != null:
		if dialog.handle_input(event):
			XKeyMap.handled(self)
		return
	var handled := true
	if event.is_action_pressed("ui_cancel"):
		cancel()
	elif event.is_action_pressed("ui_accept"):
		ok()
	elif event.is_action_pressed("ui_down", true):
		move(1, not event.is_echo())
	elif event.is_action_pressed("ui_up", true):
		move(-1, not event.is_echo())
	elif XMenu.page_dir(event) != 0:
		page(XMenu.page_dir(event))
	else:
		handled = false
	if handled:
		XKeyMap.handled(self)


func _on_list_index(i: int) -> void:
	if _syncing or dialog != null:
		return
	index = i   # 点非当前行＝选中（同旧选择窗：不响）
	sync()


func _on_list_click(i: int) -> void:
	if dialog != null:
		return
	if i == index:
		ok()


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		cancel()
