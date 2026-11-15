class_name XSkinList
extends Control
## 【cc·天启篇·未经审查】直列表：一列／两列、行高可设、超出时右侧细滚动条，选中用红乙选中条（XSkinSelectBar）。
## 每项 {text, icon（图标号或 Texture2D）, badge（图标左上角的小角标贴图，如「新」）, sub（名字后的辅助小字）, right（右对齐数值，窄体数字字）, color, right_color, disabled}。
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
var font_size := XUiSkin.FS_LIST
var sub_size := XUiSkin.FS_AUX
## 名字太长时最小缩到几号（再放不下才加省略号）
var min_font_size := 16
var right_size := 21
var icon_size := 32
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
const SCROLL_W := 4.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	bar = XSkinSelectBar.new()
	add_child(bar, false, Node.INTERNAL_MODE_FRONT)
	bar.show_behind_parent = true
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
	return size.x - (SCROLL_W + XUiSkin.GRID if scrollable() else 0.0)


## 第 i 项在列表里的矩形（已减去滚动；不在可见范围时也照算）
func cell_rect(i: int) -> Rect2:
	var cw := (content_width() - col_gap * (columns - 1)) / columns
	var row := floori(i / float(columns)) - top_row
	var col := i % columns
	return Rect2(col * (cw + col_gap), row * row_height, cw, row_height)


func item_at(p: Vector2) -> int:
	if p.x < 0 or p.y < 0 or p.x > content_width() or p.y > visible_rows() * row_height:
		return -1
	var cw := (content_width() - col_gap * (columns - 1)) / columns
	var col := clampi(floori(p.x / (cw + col_gap)), 0, columns - 1)
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
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var i := item_at(mb.position)
		if i < 0:
			return
		if i == index:
			if not bool(items[i].get("disabled", false)):
				activated.emit(i)
		else:
			select(i)
		accept_event()


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
	for i in range(first, last):
		var it: Dictionary = items[i]
		var r := cell_rect(i)
		var x := r.position.x + 14.0
		var base := r.position.y + r.size.y / 2.0
		var dis := bool(it.get("disabled", false))
		var icon = it.get("icon")
		var tex: Texture2D = icon if icon is Texture2D else (XUI.icon_texture(int(icon)) if (icon is int or icon is float) and int(icon) > 0 else null)
		if tex != null:
			draw_texture_rect(tex, Rect2(x, base - icon_size / 2.0, icon_size, icon_size), false, Color(1, 1, 1, 0.45 if dis else 1.0))
			var badge = it.get("badge")
			if badge is Texture2D:
				var bs: Vector2 = (badge as Texture2D).get_size()
				var bk := 14.0 / maxf(bs.y, 1.0)
				draw_texture_rect(badge, Rect2(x - 4, base - icon_size / 2.0 - 4, bs.x * bk, bs.y * bk), false)
			x += icon_size + 10.0
		var right := str(it.get("right", ""))
		var right_w := 0.0
		if right != "":
			right_w = num.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, right_size).x
			var rc: Color = it.get("right_color", XUiSkin.TEXT)
			draw_string(num, Vector2(r.end.x - 14.0 - right_w, base + right_size * 0.36), right, HORIZONTAL_ALIGNMENT_LEFT, -1, right_size,
				XUiSkin.TEXT_3 if dis else rc)
		var max_w := r.end.x - 14.0 - right_w - (10.0 if right_w > 0 else 0.0) - x
		var col: Color = it.get("color", XUiSkin.TEXT)
		var fit := fit_text(body, str(it.get("text", "")), max_w, font_size, min_font_size)
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
		var track := Rect2(size.x - SCROLL_W, 0, SCROLL_W, visible_rows() * row_height)
		draw_rect(track, Color(1, 1, 1, 0.06))
		var h := maxf(track.size.y * visible_rows() / float(rows_total()), 16.0)
		var y := (track.size.y - h) * top_row / float(maxi(rows_total() - visible_rows(), 1))
		draw_rect(Rect2(track.position.x, y, SCROLL_W, h), Color(XUiSkin.LINE, 0.55))
