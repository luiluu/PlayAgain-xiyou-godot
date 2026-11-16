class_name XSkinList
extends Control
## 【cc·天启篇·未经审查】直列表：一列／两列、行高可设、超出时右侧细滚动条，选中用红乙选中条（XSkinSelectBar）。
## 每项 {text, icon（图标号或 Texture2D）, badge（图标左上角的小角标贴图，如「新」）, sub（名字后的辅助小字）, right（右对齐数值，窄体数字字）, color, right_color, disabled}。
## 1C 加（可不给）：right2（right 再右边的第二列，正文字、右对齐，如装备候选的「▲23」）、right2_color；列宽 right2_w（整表一致，列才对得齐）。
## 按键：handle_input 认 ui_up／ui_down／ui_left／ui_right／ui_accept／ui_cancel（页面在自己的 _input／_unhandled_input 里转进来）；
## 鼠标、触屏：点非当前项＝选中，点当前项＝确定；滚轮滚一行。上下到头循环（同 MV 列表按一下时的行为）。

signal index_changed(index: int)
signal activated(index: int)
signal cancelled

var columns := 1:
	set(v):
		columns = clampi(v, 1, 4)
		_relayout()
var row_height := XUiSkin.ROW_H:
	set(v):
		row_height = maxi(v, 24)
		_relayout()
var col_gap := XUiSkin.GRID
## 收口批（FONT_V2，小A核 P2-3）：没单独设过时每次画都按 XUiSkin 现取，设置页改字号后当前列表也跟着变；设过（>0）就用设的
var _font_size := 0
var _sub_size := 0
var font_size: int:
	get: return _font_size if _font_size > 0 else XUiSkin.FS_LIST
	set(v): _font_size = v
var sub_size: int:
	get: return _sub_size if _sub_size > 0 else XUiSkin.FS_AUX
	set(v): _sub_size = v
## 名字太长时最小缩到几号（再放不下才加省略号）
var min_font_size := 16
var right_size := 21
var icon_size := 32
## 第二右列（right2）的宽：整表一样宽，各行的 right 才对齐成一列
var right2_w := 64.0
var wrap := true
var empty_text := "空"
## 列表有没有焦点：没有时不画选中条（模板页里分类环有焦点时，列表只显示内容）
var active := true:
	set(v):
		active = v
		_relayout(true)
var items: Array = []
var index := 0
var top_row := 0
var bar: XSkinSelectBar
## T024 选中放大：选中行的图标、名字放大（行高、选中条不变，名字仍按本行余宽缩字／省略，不压右列和邻行）
var sel_scale: XSkinSelScale
const SCROLL_W := 4.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	bar = XSkinSelectBar.new()
	add_child(bar, false, Node.INTERNAL_MODE_FRONT)
	bar.show_behind_parent = true
	sel_scale = XSkinSelScale.attach(self)
	resized.connect(_relayout)


func set_items(arr: Array, keep_index := false) -> void:
	items = arr
	if not keep_index:
		index = 0
		top_row = 0
	index = clampi(index, 0, maxi(items.size() - 1, 0))
	_ensure_visible()
	_relayout(true)


func rows_total() -> int:
	return ceili(items.size() / float(columns))


func visible_rows() -> int:
	return maxi(floori(size.y / row_height), 1)


func scrollable() -> bool:
	return rows_total() > visible_rows()


func content_width() -> float:
	return size.x - (scroll_w() + XUiSkin.GRID if scrollable() else 0.0)


## 第 i 项在列表里的矩形（已减去滚动；不在可见范围时也照算）
func cell_rect(i: int) -> Rect2:
	var g := gap()
	var cw := (content_width() - g * (columns - 1)) / columns
	var row := floori(i / float(columns)) - top_row
	var col := i % columns
	return Rect2(col * (cw + g), row * row_height, cw, row_height)


## 列间距：第一期正式美术的外置箭头（左探 22）要落在列缝里，不进左列（小A核 P2-1）：至少 26
func gap() -> float:
	return maxf(col_gap, 26.0) if columns > 1 and XSkinArt.select_on() else col_gap


func item_at(p: Vector2) -> int:
	if p.x < 0 or p.y < 0 or p.x > content_width() or p.y > visible_rows() * row_height:
		return -1
	var cw := (content_width() - gap() * (columns - 1)) / columns
	var col := clampi(floori(p.x / (cw + gap())), 0, columns - 1)
	var i := (floori(p.y / row_height) + top_row) * columns + col
	return i if i < items.size() else -1


## 选第 i 项（滚到看得见）
func select(i: int, animate := true) -> void:
	if items.is_empty():
		return
	i = clampi(i, 0, items.size() - 1)
	var changed := i != index
	index = i
	var scrolled := _ensure_visible()
	bar.move_to(cell_rect(index), not animate or scrolled)
	bar.visible = active
	queue_redraw()
	if changed:
		index_changed.emit(index)


## 方向键：dy 上下一行、dx 左右一格（两列时）
func move(dx: int, dy: int) -> bool:
	if items.is_empty():
		return false
	var n := items.size()
	var i := index
	if dy != 0:
		i += dy * columns
		if i < 0 or i >= n:
			if not wrap:
				return false
			i = (index % columns) + (0 if dy > 0 else (rows_total() - 1) * columns)
			if i >= n:
				i -= columns
	if dx != 0:
		var col := index % columns + dx
		if columns == 1 or col < 0 or col >= columns or i + dx >= n:
			return false
		i += dx
	if i == index:
		return false
	select(i)
	return true


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up", true):
		return move(0, -1)
	if event.is_action_pressed("ui_down", true):
		return move(0, 1)
	if event.is_action_pressed("ui_left", true):
		return move(-1, 0)
	if event.is_action_pressed("ui_right", true):
		return move(1, 0)
	if event.is_action_pressed("ui_accept"):
		if not items.is_empty() and not bool(items[index].get("disabled", false)):
			activated.emit(index)
		return true
	if event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_to(top_row + (-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1))
			accept_event()
			return
	if XUiSkin.TOUCH_V2:
		_drag_input(event)
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_tap(mb.position)
		accept_event()


func _tap(p: Vector2) -> void:
	var i := item_at(p)
	if i < 0:
		return
	bar.press()
	if i == index:
		if not bool(items[i].get("disabled", false)):
			activated.emit(i)
	else:
		select(i)


## 收口批（TOUCH_V2）手指拖动：按下只记位置，上下拖过 DRAG_SLOP 就按行滚（不选中、不触发）；松手时没拖过才算一次点（选中／再点打开）。
## 触屏会被引擎模拟成鼠标左键，所以只接鼠标事件。
const DRAG_SLOP := 10.0
var _drag_from := Vector2.INF
var _drag_row0 := 0
var _dragging := false


func _drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		accept_event()
		if mb.pressed:
			_drag_from = mb.position
			_drag_row0 = top_row
			_dragging = false
			return
		var was := _dragging
		var from := _drag_from
		_drag_from = Vector2.INF
		_dragging = false
		if not was and from != Vector2.INF:
			_tap(mb.position)
		return
	if event is InputEventMouseMotion and _drag_from != Vector2.INF:
		var dy := _drag_from.y - (event as InputEventMouseMotion).position.y
		if not _dragging and absf(dy) >= DRAG_SLOP and scrollable():
			_dragging = true
		if _dragging:
			scroll_to(_drag_row0 + roundi(dy / row_height))
			accept_event()


## 滚动条宽：触屏版 8（手指找得到），旧 4
func scroll_w() -> float:
	return 8.0 if XUiSkin.TOUCH_V2 else SCROLL_W


## 选中放大后名字最大几号：行高的 0.6（46 行→27），130% 字号时不顶到行边
func sel_font_cap() -> int:
	return floori(row_height * 0.6)


## 名字放不下时先缩字（最小 min_fs），还放不下就截断加「…」（1B：两列物品名不再被硬裁成「治疗药水(」）。返回 [文字, 字号]
static func fit_text(f: Font, text: String, max_w: float, fs: int, min_fs: int) -> Array:
	if max_w <= 0.0 or text == "":
		return [text, fs]
	var s := fs
	while s > min_fs and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		s -= 1
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= max_w:
		return [text, s]
	var n := text.length()
	while n > 1 and f.get_string_size(text.substr(0, n) + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		n -= 1
	return [text.substr(0, n) + "…", s]


func scroll_to(row: int) -> void:
	var r := clampi(row, 0, maxi(rows_total() - visible_rows(), 0))
	if r == top_row:
		return
	top_row = r
	_relayout(true)


func _ensure_visible() -> bool:
	var row := floori(index / float(columns))
	var old := top_row
	if row < top_row:
		top_row = row
	elif row >= top_row + visible_rows():
		top_row = row - visible_rows() + 1
	top_row = clampi(top_row, 0, maxi(rows_total() - visible_rows(), 0))
	return old != top_row


func _relayout(instant := false) -> void:
	if bar == null:
		return
	bar.visible = active and not items.is_empty()
	if not items.is_empty():
		var r := cell_rect(index)
		bar.visible = active and r.position.y >= 0 and r.end.y <= visible_rows() * row_height + 0.5
		bar.move_to(r, instant)
	queue_redraw()


func _draw() -> void:
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	if items.is_empty():
		draw_string(body, Vector2(XUiSkin.PAD, row_height / 2.0 + font_size * 0.35), empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, XUiSkin.TEXT_3)
		return
	var first := top_row * columns
	var last := mini(items.size(), (top_row + visible_rows()) * columns)
	sel_scale.sel(index if active else null)
	for i in range(first, last):
		var it: Dictionary = items[i]
		var r := cell_rect(i)
		var x := r.position.x + 14.0
		var base := r.position.y + r.size.y / 2.0
		var dis := bool(it.get("disabled", false))
		var sk := sel_scale.k(i)
		var icon = it.get("icon")
		var tex: Texture2D = icon if icon is Texture2D else (XUiSkin.icon(int(icon)) if (icon is int or icon is float) and int(icon) > 0 else null)
		if tex != null:
			var ir := XSkinSelScale.grow(Rect2(x, base - icon_size / 2.0, icon_size, icon_size), sk)
			draw_texture_rect(tex, ir, false, Color(1, 1, 1, 0.45 if dis else 1.0))
			var badge = it.get("badge")
			if badge is Texture2D:
				var bs: Vector2 = (badge as Texture2D).get_size()
				var bk := 14.0 / maxf(bs.y, 1.0)
				draw_texture_rect(badge, Rect2(ir.position.x - 4, ir.position.y - 4, bs.x * bk, bs.y * bk), false)
			x = ir.end.x + 10.0
		var right := str(it.get("right", ""))
		var right_w := 0.0
		var end_x := r.end.x - 14.0
		if it.has("right2"):
			var r2 := str(it.right2)
			var r2w := body.get_string_size(r2, HORIZONTAL_ALIGNMENT_LEFT, -1, right_size - 3).x
			draw_string(body, Vector2(end_x - r2w, base + (right_size - 3) * 0.36), r2, HORIZONTAL_ALIGNMENT_LEFT, -1, right_size - 3,
				XUiSkin.TEXT_3 if dis else it.get("right2_color", XUiSkin.TEXT_2))
			end_x -= right2_w
		if right != "":
			right_w = num.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, right_size).x
			var rc: Color = it.get("right_color", XUiSkin.TEXT)
			draw_string(num, Vector2(end_x - right_w, base + right_size * 0.36), right, HORIZONTAL_ALIGNMENT_LEFT, -1, right_size,
				XUiSkin.TEXT_3 if dis else rc)
		var max_w := end_x - right_w - (10.0 if right_w > 0 else 0.0) - x
		var col: Color = it.get("color", XUiSkin.TEXT)
		if i == index and active:
			col = XUiSkin.sel_text(col)
		var fit := fit_text(body, str(it.get("text", "")), max_w, XSkinSelScale.fs(font_size, sk, sel_font_cap()), min_font_size)
		var text: String = fit[0]
		var fs: int = fit[1]
		draw_string(body, Vector2(x, base + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.TEXT_3 if dis else col)
		var sub := str(it.get("sub", ""))
		if sub != "":
			var tw := body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var sx := x + tw + 10.0
			if sx < x + max_w - 20.0:
				draw_string(body, Vector2(sx, base + sub_size * 0.36), sub, HORIZONTAL_ALIGNMENT_LEFT, x + max_w - sx, sub_size, XUiSkin.TEXT_2)
	if scrollable():
		var track := Rect2(size.x - scroll_w(), 0, scroll_w(), visible_rows() * row_height)
		draw_rect(track, Color(1, 1, 1, 0.06))
		var h := maxf(track.size.y * visible_rows() / float(rows_total()), 16.0)
		var y := (track.size.y - h) * top_row / float(maxi(rows_total() - visible_rows(), 1))
		draw_rect(Rect2(track.position.x, y, scroll_w(), h), Color(XUiSkin.LINE, 0.55))
