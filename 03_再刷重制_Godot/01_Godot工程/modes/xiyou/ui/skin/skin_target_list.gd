class_name XSkinTargetList
extends Control
## 【cc·天启篇·未经审查】「给谁用」目标列表（界面风格提案 v0.7 物品页右下）：旧金小标题＋每人一行
## 圆头像、名字、一条量条（生命玫粉／魔法蓝／TP 青）、「当前/上限」窄体数字、右侧预估（「+138」提升绿，或「满」最暗字）。
## 不透明面板由外面的详情牌画，这里只画内容（透明底）。
## selectable 为真时可选人：红乙选中条（XSkinSelectBar）；all 为真时整队都画选中（全体对象的物品／技能）。
## 按键：handle_input 认上下与确定（页面转进来）；鼠标点非当前行＝选中、点当前行＝确定。

signal index_changed(index: int)
signal activated(index: int)

## [{name, face（Texture2D）, kind（hp/mp/tp）, cur, max, right（右侧预估字）, right_color, dim（不能用在他身上时变暗）}]
var rows: Array = []
var title := "给谁用"
var index := 0
var selectable := false:
	set(v):
		selectable = v
		_place_bar(true)
var all := false:
	set(v):
		all = v
		_place_bar(true)
var bar: XSkinSelectBar
const ROW_H := 44.0
const TITLE_H := 32.0
const HEAD := 30.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	bar = XSkinSelectBar.new()
	add_child(bar, false, Node.INTERNAL_MODE_FRONT)
	bar.show_behind_parent = true
	bar.visible = false
	resized.connect(func(): _place_bar(true))


## 整块要多高（标题＋n 行）
static func height_for(n: int) -> float:
	return TITLE_H + ROW_H * n


func set_rows(arr: Array) -> void:
	rows = arr
	index = clampi(index, 0, maxi(rows.size() - 1, 0))
	_place_bar(true)
	queue_redraw()


func row_rect(i: int) -> Rect2:
	return Rect2(0, TITLE_H + i * ROW_H, size.x, ROW_H)


func select(i: int, animate := true) -> void:
	if rows.is_empty():
		return
	i = clampi(i, 0, rows.size() - 1)
	var changed := i != index
	index = i
	_place_bar(not animate)
	queue_redraw()
	if changed:
		index_changed.emit(index)


func _place_bar(instant: bool) -> void:
	if bar == null:
		return
	bar.visible = selectable and not all and index < rows.size()
	if bar.visible:
		bar.move_to(row_rect(index).grow_individual(0, -2, 0, -2), instant)
	queue_redraw()


func handle_input(event: InputEvent) -> bool:
	if not selectable or rows.is_empty():
		return false
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		if not all:
			select(posmod(index + (-1 if event.is_action("ui_up") else 1), rows.size()))
		return true
	if event.is_action_pressed("ui_accept"):
		activated.emit(index)
		return true
	return false


func row_at(p: Vector2) -> int:
	for i in rows.size():
		if row_rect(i).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if not selectable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := row_at(event.position)
		if i < 0:
			return
		if i == index or all:
			activated.emit(i)
		else:
			select(i)
		accept_event()


func _draw() -> void:
	var ci := get_canvas_item()
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	if title != "":
		draw_string(body, Vector2(0, XUiSkin.FS_AUX_MAX + 4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX_MAX, XUiSkin.GOLD)
		draw_line(Vector2(0, TITLE_H - 4), Vector2(size.x, TITLE_H - 4), Color(XUiSkin.LINE, 0.14), 1.0)
	for i in rows.size():
		var m: Dictionary = rows[i]
		var r := row_rect(i)
		if selectable and all:
			XUiSkin.draw_select(ci, r.grow_individual(0, -2, 0, -2), XUiSkin.breath_alpha())
		var a := 0.45 if bool(m.get("dim", false)) else 1.0
		var hc := Vector2(r.position.x + 10 + HEAD / 2.0, r.position.y + r.size.y / 2.0)
		draw_circle(hc, HEAD / 2.0, XUiSkin.ORB_LOW)
		var face = m.get("face")
		if face is Texture2D:
			XSkinPartyStrip.draw_round_texture(self, face, hc, HEAD / 2.0 - 1.5)
		draw_circle(hc, HEAD / 2.0, Color(XUiSkin.LINE, 0.65 * a), false, 1.2, true)
		var x := r.position.x + 10 + HEAD + 10
		var base := r.position.y + r.size.y / 2.0
		var right_w := 56.0
		var name_w := 72.0
		draw_string(body, Vector2(x, base + 17 * 0.36), str(m.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, name_w, 17, Color(XUiSkin.TEXT, a))
		x += name_w + 6
		var kind := str(m.get("kind", "hp"))
		var col: Color = XUiSkin.HP if kind == "hp" else (XUiSkin.MP if kind == "mp" else XUiSkin.TP)
		var txt_col: Color = XUiSkin.HP_TEXT if kind == "hp" else (XUiSkin.MP_TEXT if kind == "mp" else XUiSkin.TP_TEXT)
		var cur := float(m.get("cur", 0))
		var mx := float(m.get("max", 0))
		var vt := "%d/%d" % [int(cur), int(mx)]
		var vw := num.get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var bar_w := maxf(r.end.x - 10 - right_w - 8 - vw - 8 - x, 24.0)
		var track := Rect2(x, base - 2.5, bar_w, 5)
		_pill(ci, track, Color(1, 1, 1, 0.12))
		if mx > 0 and cur > 0:
			_pill(ci, Rect2(track.position, Vector2(track.size.x * clampf(cur / mx, 0, 1), 5)), Color(col, a))
		draw_string(num, Vector2(x + bar_w + 8, base + 16 * 0.36), vt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(txt_col, a))
		var rt := str(m.get("right", ""))
		if rt != "":
			var fs := 20 if rt.begins_with("+") else XUiSkin.FS_AUX
			var f := num if rt.begins_with("+") else body
			var rw := f.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(r.end.x - 10 - rw, base + fs * 0.36), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, m.get("right_color", XUiSkin.TEXT_3))


func _pill(ci: RID, r: Rect2, c: Color) -> void:
	if r.size.x <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(3)
	sb.draw(ci, r)
