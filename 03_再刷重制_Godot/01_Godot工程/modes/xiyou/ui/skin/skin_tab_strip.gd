class_name XSkinTabStrip
extends Control
## 【cc·天启篇·未经审查】组页签条：每页顶上一排组名（组配置在 XUiSkin.GROUPS，按存档只排看得见的组：现在天启篇 6 组，宠物组放开后 7 组）。
## 选中的组：绯红 22% 底＋底边 3px 朱红线（红乙 .nav .on）；其余次要字色。Q／E（或 prev／next）循环换组。
## 组里只剩一项时 current_direct() 给出那一项的键，页面据此「选组直接进」。

signal changed(index: int)

var groups: Array = []
var index := 0
var font_size := 17
const TAB_H := 38.0
const TAB_PAD := 14.0
const TAB_GAP := 4.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = TAB_H


## 按存档筛出看得见的组；keep_key 给了就尽量留在同一组
func set_groups(src: Array = XUiSkin.GROUPS, s: XState = null, keep_key := "") -> void:
	groups = XUiSkin.visible_groups(src, s)
	index = 0
	if keep_key != "":
		select_key(keep_key)
	custom_minimum_size.x = total_width()
	queue_redraw()


func select_key(key: String) -> bool:
	for i in groups.size():
		if str(groups[i].key) == key:
			select(i)
			return true
	return false


func select(i: int) -> void:
	if groups.is_empty():
		return
	i = posmod(i, groups.size())
	if i == index:
		return
	index = i
	queue_redraw()
	changed.emit(index)


func next() -> void:
	select(index + 1)


func prev() -> void:
	select(index - 1)


func current() -> Dictionary:
	return groups[index] if index < groups.size() else {}


## 当前组只剩一项时那一项的键（选组直接进），否则 ""
func current_direct() -> String:
	var g := current()
	return str(g.items[0].key) if not g.is_empty() and (g.items as Array).size() == 1 else ""


func tab_rect(i: int) -> Rect2:
	var f := XUiSkin.font("body")
	var x := 0.0
	for k in range(i):
		x += f.get_string_size(str(groups[k].name), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + TAB_PAD * 2 + TAB_GAP
	var w := f.get_string_size(str(groups[i].name), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + TAB_PAD * 2
	return Rect2(x, 0, w, TAB_H)


func total_width() -> float:
	return 0.0 if groups.is_empty() else tab_rect(groups.size() - 1).end.x


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in groups.size():
			if tab_rect(i).has_point(event.position):
				select(i)
				accept_event()
				return


func _draw() -> void:
	var f := XUiSkin.font("body")
	var ci := get_canvas_item()
	for i in groups.size():
		var r := tab_rect(i)
		var on := i == index
		if on:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(XUiSkin.SEL_FILL, 0.22)
			sb.set_corner_radius_all(XUiSkin.ROW_RADIUS)
			sb.border_color = XUiSkin.SEL_LINE
			sb.border_width_bottom = 3
			sb.draw(ci, r)
		draw_string(f, Vector2(r.position.x + TAB_PAD, r.position.y + TAB_H / 2.0 + font_size * 0.36), str(groups[i].name),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE if on else XUiSkin.TEXT_2)
