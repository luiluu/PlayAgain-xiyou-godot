class_name XSkinList
extends Control
## 【cc·天启篇·未经审查】直列表：一列／两列、行高可设、超出时右侧细滚动条，选中用红乙选中条（XSkinSelectBar）。
## 每项 {text, icon（图标号或 Texture2D）, badge（图标左上角的小角标贴图，如「新」）, sub（名字后的辅助小字）, right（右对齐数值，窄体数字字）, color, right_color, disabled}。
## 1C 加（可不给）：right2（right 再右边的第二列，正文字、右对齐，如装备候选的「▲23」）、right2_color；列宽 right2_w（整表一致，列才对得齐）。
## T283 加（可不给，不给就不画、和以前逐像素一样）：tags（名字后的小标 XSkinTag：["新"] 或 [{text, color}]，名字放不下先缩名字、小标不缩）、
## check（多选方框：0 空框、1 金色 ✓；没这个键的行不画框；要整表先设 check_column = true 才留出行首 28 的位置）；
## 表级 empty_center（空列表一句画在列表区正中、19 号 TEXT_3，T254 3.0「空列表」）。
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
## T283：空列表一句居中（XSkinTag.draw_empty）；false＝照旧左上一行
var empty_center := false
## T283：行首留多选方框的位置（行键 check）；false＝不留
var check_column := false
const CHECK_W := 28.0
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
## T339 D3：像素级跟手。scroll_px＝top_row 整行起点＋_sub（手指拖到的行内零头，松手后留着，下一次按键／滚轮整行对齐）；
## 方向键／滚轮／翻页仍按整行跳并把零头清掉。DETAIL_V1 关时永远为 0＝旧的整行跳
var _sub := 0.0
var scroll_px: float:
	get: return top_row * row_height + _sub
	set(v): _set_scroll_px(v)
## 拖拽时按下的那一行（预按轻底，滑过死区立即撤销）；-1＝没有
var pre_press := -1
var _xd := XSkinDrag.new()
var _touch_drag := true
var _bar_hi := false
var _bar_hi_gen := 0
const BAR_ALPHA_HI := 0.92
const BAR_ALPHA_LO := 0.68
const BAR_HI_HOLD := 0.6
const PRE_PRESS_ALPHA := 0.35
## 左右各留的不裁剪边（D51 外置小箭头在行左 -22 处）
const CLIP_SIDE := 26.0


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
		_sub = 0.0
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
	return Rect2(col * (cw + g), row * row_height - _sub, cw, row_height)


## 列间距：第一期正式美术的外置箭头（左探 22）要落在列缝里，不进左列（小A核 P2-1）：至少 26
func gap() -> float:
	return maxf(col_gap, 26.0) if columns > 1 and XSkinArt.select_on() else col_gap


func item_at(p: Vector2) -> int:
	if p.x < 0 or p.y < 0 or p.x > content_width() or p.y > visible_rows() * row_height:
		return -1
	var cw := (content_width() - gap() * (columns - 1)) / columns
	var col := clampi(floori(p.x / (cw + gap())), 0, columns - 1)
	var i := (floori((p.y + _sub) / row_height) + top_row) * columns + col
	if i < 0:
		return -1
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
	_snap_rows()   # 方向键按整行跳：手指拖出来的行内零头先对齐到最近的整行
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


## 把拖出来的行内零头对齐到最近的整行（scroll_px＝top_row*row_height）
func _snap_rows() -> void:
	if _sub == 0.0:
		return
	var maxrow := maxi(rows_total() - visible_rows(), 0)
	top_row = clampi(top_row + (1 if _sub >= row_height / 2.0 else 0), 0, maxrow)
	_sub = 0.0
	_relayout(true)


func handle_input(event: InputEvent) -> bool:
	# T049：键盘真正的 PageUp／PageDown 翻一页（ui_page_up/down 动作＝Q／E／肩键，页面拿它换角色，这里不认）
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		return page(1 if event.physical_keycode == KEY_PAGEDOWN else -1)
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
	if XUiSkin.detail_on():
		_drag_input_px(event)
		return
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


## T339 D3：统一走 XSkinDrag（死区触屏 8／鼠标 5、起拖扣死区），列表 1:1 像素跟手；按下 0ms 给那一行预按轻底，滑过死区立即撤销；
## 松手没拖过才算一次点。惯性与回弹挂 XSkinDrag.INERTIA_ENABLED（默认关）。
func _drag_input_px(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		accept_event()
		if mb.pressed:
			_xd.press(mb.position, scroll_px)
			_touch_drag = XSkinDrag.is_touch_event(mb)
			pre_press = item_at(mb.position)
			queue_redraw()
			return
		var from := _xd.from
		var was := _xd.dragging
		var tap := _xd.release()
		pre_press = -1
		if was:
			_bar_hi_release()
			if _xd.begin_inertia(scroll_px):
				set_process(true)
		queue_redraw()
		if tap and from != Vector2.INF:
			_tap(mb.position)
		return
	if event is InputEventMouseMotion and _xd.active():
		if not scrollable():
			return
		var to := _xd.motion((event as InputEventMouseMotion).position, _touch_drag)
		if not is_nan(to):
			if pre_press >= 0:
				pre_press = -1   # 拖起来了：预按立刻撤销
			_bar_hi = true
			_bar_hi_gen += 1
			_set_scroll_px(to)
			accept_event()


func _process(delta: float) -> void:
	if not _xd.inertia_active():
		set_process(false)
		return
	_set_scroll_px(_xd.tick_inertia(delta, 0.0, max_scroll_px()), true)
	if not _xd.inertia_active():
		set_process(false)


func max_scroll_px() -> float:
	return maxf(rows_total() - visible_rows(), 0) * row_height


## 把滚动位置设到 v 像素。over＝允许在两端越出（惯性回弹时），否则截断到 [0, max_scroll_px]
func _set_scroll_px(v: float, over := false) -> void:
	var mx := max_scroll_px()
	if not over:
		v = clampf(v, 0.0, mx)
	var maxrow := maxi(rows_total() - visible_rows(), 0)
	var r := clampi(floori(v / row_height), 0, maxrow)
	var sub := v - r * row_height
	if r == top_row and is_equal_approx(sub, _sub):
		return
	top_row = r
	_sub = sub
	_relayout(true)


## 松手后滚动条高亮再保持 BAR_HI_HOLD 秒才回常态
func _bar_hi_release() -> void:
	_bar_hi_gen += 1
	var gen := _bar_hi_gen
	if not is_inside_tree():
		_bar_hi = false
		return
	get_tree().create_timer(BAR_HI_HOLD).timeout.connect(func() -> void:
		if is_instance_valid(self) and gen == _bar_hi_gen:
			_bar_hi = false
			queue_redraw())


## 滚动条拇指现在该多亮：拖拽中 0.92，松手 0.6s 后回 0.68
func scroll_alpha() -> float:
	return BAR_ALPHA_HI if _bar_hi else BAR_ALPHA_LO


## T283 多选方框（行键 check）：14×14 圆角框，标上是金色 ✓（不画框）；pos＝左缘、竖直中线
func _draw_check(pos: Vector2, on: bool, dis: bool) -> void:
	if on:
		var c := XUiSkin.GOLD if not dis else XUiSkin.TEXT_3
		draw_polyline(PackedVector2Array([pos + Vector2(1, 0), pos + Vector2(6, 5), pos + Vector2(15, -6)]), c, 2.5, true)
		return
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(XUiSkin.text2_c() if not dis else XUiSkin.TEXT_3, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.draw(get_canvas_item(), Rect2(pos.x, pos.y - 7.0, 14.0, 14.0))


## T254 3.0「用不了的行」：字 TEXT_3，被选中时提到 #c9cbd0（T300 小A核 P2-3）。DIS_SEL_ON＝false 回到选中也是 TEXT_3
static var DIS_SEL_ON := true
const DIS_SEL := Color("c9cbd0")


func dis_color(i: int) -> Color:
	return DIS_SEL if DIS_SEL_ON and i == index and active else XUiSkin.TEXT_3


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


## T049 翻页：往后（d>0）或往前（d<0）整整一页（visible_rows 行）；到头不动返回 false。
## move_index＝选中项跟着挪一页（光标留在同一屏位置）；列表没焦点（active＝false）时只翻不挪，免得悄悄换了选中项。
func page(d: int, move_index := true) -> bool:
	var vis := visible_rows()
	var r := clampi(top_row + (vis if d > 0 else -vis), 0, maxi(rows_total() - vis, 0))
	var delta := r - top_row
	if delta == 0:
		return false
	if move_index and not items.is_empty():
		select(clampi(index + delta * columns, 0, items.size() - 1))
		scroll_to(r)   # select 已滚到看得见；再对齐成整页
	else:
		scroll_to(r)
	return true


func scroll_to(row: int) -> void:
	var r := clampi(row, 0, maxi(rows_total() - visible_rows(), 0))
	if r == top_row and _sub == 0.0:
		return
	top_row = r
	_sub = 0.0
	_relayout(true)


func _ensure_visible() -> bool:
	var row := floori(index / float(columns))
	var old := top_row
	var was_sub := _sub != 0.0
	if was_sub:
		var y := (row - top_row) * row_height - _sub
		if y >= 0.0 and y + row_height <= visible_rows() * row_height + 0.5:
			return false   # 拖出来的半行位置上这一行已完整可见：点选不动画面
	_sub = 0.0   # 要滚了：把拖出来的行内零头对齐成整行
	if row < top_row:
		top_row = row
	elif row >= top_row + visible_rows():
		top_row = row - visible_rows() + 1
	top_row = clampi(top_row, 0, maxi(rows_total() - visible_rows(), 0))
	return old != top_row or was_sub


func _relayout(instant := false) -> void:
	if bar == null:
		return
	bar.visible = active and not items.is_empty()
	if not items.is_empty():
		var r := cell_rect(index)
		if _sub != 0.0:   # 像素跟手：选中条跟着行半截滑进滑出（上下由列表的纵向裁剪切掉）
			bar.visible = active and r.end.y > 0.0 and r.position.y < visible_rows() * row_height
		else:
			bar.visible = active and r.position.y >= 0 and r.end.y <= visible_rows() * row_height + 0.5
		bar.move_to(r, instant or _sub != 0.0)
	queue_redraw()


func _draw() -> void:
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var pol := XUiSkin.polish_on()
	if items.is_empty():
		if empty_center:
			XSkinTag.draw_empty(self, Rect2(0, 0, size.x, size.y), empty_text)
			return
		XUiSkin.ds(self, body, Vector2(XUiSkin.PAD, row_height / 2.0 + font_size * 0.35), empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, XUiSkin.TEXT_3)
		return
	var first := top_row * columns
	var last := mini(items.size(), (top_row + visible_rows() + (1 if _sub != 0.0 else 0)) * columns)
	_apply_clip()
	sel_scale.sel(index if active else null)
	if pre_press >= 0 and pre_press >= first and pre_press < last and not (pre_press == index and active):
		draw_rect(cell_rect(pre_press).grow_individual(-2.0, -1.0, -2.0, -1.0), Color(XUiSkin.SEL_FILL.darkened(0.35), PRE_PRESS_ALPHA))
	for i in range(first, last):
		var it: Dictionary = items[i]
		var r := cell_rect(i)
		if pol and not (i == index and active) and (floori(i / float(columns)) % 2) == 1:
			draw_rect(r.grow_individual(-2.0, -1.0, -2.0, -1.0), Color(0.95, 0.90, 0.82, 0.026))
		var x := r.position.x + 14.0
		var base := r.position.y + r.size.y / 2.0
		var dis := bool(it.get("disabled", false))
		var sk := sel_scale.k(i)
		if check_column:
			if it.has("check"):
				_draw_check(Vector2(x + 2.0, base), int(it.check) == 1, dis)
			x += CHECK_W
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
			XUiSkin.ds(self, body, Vector2(end_x - r2w, base + (right_size - 3) * 0.36), r2, HORIZONTAL_ALIGNMENT_LEFT, -1, right_size - 3,
				dis_color(i) if dis else it.get("right2_color", XUiSkin.TEXT_2))
			end_x -= right2_w
		if right != "":
			right_w = num.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, right_size).x
			var rc: Color = it.get("right_color", XUiSkin.TEXT)
			XUiSkin.ds(self, num, Vector2(end_x - right_w, base + right_size * 0.36), right, HORIZONTAL_ALIGNMENT_LEFT, -1, right_size,
				dis_color(i) if dis else rc)
		var max_w := end_x - right_w - (10.0 if right_w > 0 else 0.0) - x
		var col: Color = it.get("color", XUiSkin.TEXT)
		if i == index and active:
			col = XUiSkin.sel_text(col)
		var tags: Array = it.get("tags", [])
		var tags_w := XSkinTag.row_width(tags) + XSkinTag.GAP * 2.0 if not tags.is_empty() else 0.0
		var fit := fit_text(body, str(it.get("text", "")), max_w - tags_w, XSkinSelScale.fs(font_size, sk, sel_font_cap()), min_font_size)
		var text: String = fit[0]
		var fs: int = fit[1]
		XUiSkin.ds(self, body, Vector2(x, base + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dis_color(i) if dis else col)
		var after := 0.0   # 小标占掉的宽（sub 接在小标后面）
		if not tags.is_empty():
			var tx := x + body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + XSkinTag.GAP * 2.0
			for t in tags:
				var p := XSkinTag.parse(t)
				if str(p[0]) == "":
					continue
				var tw2 := XSkinTag.draw(self, Vector2(tx, base), str(p[0]), dis_color(i) if dis else p[1])
				tx += tw2 + XSkinTag.GAP
				after += tw2 + XSkinTag.GAP
			after += XSkinTag.GAP
		var sub := str(it.get("sub", ""))
		if sub != "":
			var tw := body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + after
			var sx := x + tw + 10.0
			if sx < x + max_w - 20.0:
				XUiSkin.ds(self, body, Vector2(sx, base + sub_size * 0.36), sub, HORIZONTAL_ALIGNMENT_LEFT, x + max_w - sx, sub_size, XUiSkin.TEXT_2)
	if scrollable():
		var track := Rect2(size.x - scroll_w(), 0, scroll_w(), visible_rows() * row_height)
		var h := maxf(track.size.y * visible_rows() / float(rows_total()), 16.0)
		var y := (track.size.y - h) * top_row / float(maxi(rows_total() - visible_rows(), 1))
		if _sub != 0.0 or _bar_hi:
			y = (track.size.y - h) * clampf(scroll_px / maxf(max_scroll_px(), 1.0), 0.0, 1.0)
		XUiSkin.draw_scrollbar(self, track, y, h, Color(1, 1, 1, 0.06), Color(XUiSkin.LINE, 0.55))
		if _bar_hi and pol:   # 拖拽中高亮：在常态 0.68 的拇指上再叠一层，合成 0.92
			var gsb := StyleBoxFlat.new()
			gsb.bg_color = Color(0.78, 0.69, 0.54, 1.0 - (1.0 - BAR_ALPHA_HI) / (1.0 - BAR_ALPHA_LO))
			gsb.set_corner_radius_all(maxi(2, int(track.size.x * 0.5)))
			gsb.draw(get_canvas_item(), Rect2(track.position.x + 0.5, y, maxf(2.0, track.size.x - 1.0), maxf(8.0, h)))


## 像素跟手时只裁上下、不裁左右：D51 外置小箭头在行左 -22，整控件 clip_contents 会把它裁掉，
## 所以只在行有半截位移时给画布项开剪裁，并把自定义矩形左右各放宽 CLIP_SIDE。静止（零头为 0）时关掉，和旧画法逐像素相同
func _apply_clip() -> void:
	var ci := get_canvas_item()
	var on := _sub != 0.0 and XUiSkin.detail_on()
	RenderingServer.canvas_item_set_clip(ci, on)
	if on:
		RenderingServer.canvas_item_set_custom_rect(ci, true, clip_rect())
	else:
		RenderingServer.canvas_item_set_custom_rect(ci, false)


func clip_rect() -> Rect2:
	return Rect2(-CLIP_SIDE, 0.0, size.x + CLIP_SIDE * 2.0, visible_rows() * row_height)
