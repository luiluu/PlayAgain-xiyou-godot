class_name XSkinBackButton
extends Control
## 【cc·天启篇·未经审查】收口批（TOUCH_V2，Fable 审 A4）：整页左上角固定的「‹」返回，点一下＝取消（同按取消键、两指点、安卓返回键）。
## 位置永远在页名前面；键盘手柄时也显示（只是个记号），点击只在松手且还在钮上时才算。

const W := 36.0
const H := 48.0
var _down := false
## T359 D255：返回钮的焦点态。它不抢页面焦点（不进 Tab 顺序、不吞方向键）；键盘／手柄按下取消键的那一刻亮淡金双环（＝「这一下就是它」的反馈，松手即放），
## 页面也可以直接写 focused 把它设成焦点。鼠标／触屏不画环（show_focus_ring）。DETAIL_V1 关＝不画
var focused := false:
	set(v):
		if focused == v:
			return
		focused = v
		queue_redraw()


## 加到整页上（TOUCH_V2 关时不加，返回 null）；页面画页名前调 place() 摆好并拿到页名的 x
static func attach(page: Control) -> XSkinBackButton:
	if not XUiSkin.TOUCH_V2:
		return null
	var b := XSkinBackButton.new()
	page.add_child(b)
	return b


## 摆到页名前（m＝页边距），返回页名该画的 x
static func place(b: XSkinBackButton, m: float) -> float:
	if b == null or not is_instance_valid(b):
		return m
	b.position = Vector2(m - 8, 10)
	return m + W


func _init() -> void:
	name = "SkinBack"
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if event.is_action_released("ui_cancel"):   # 松手无条件放掉（页面可能已在按下时隐藏）
		focused = false
	elif focused and not is_visible_in_tree():
		focused = false
	elif is_visible_in_tree() and XUiSkin.detail_on() and event.is_action_pressed("ui_cancel") and not (event is InputEventKey and event.echo):
		focused = not (XSkinList.T366_V1 and _covered_by_dialog())   # T366（T359 P3）：弹窗盖在上面时取消键是弹窗的，底层返回钮不亮环


## 页面没隐藏、上面却压着确认弹窗（XSkinConfirm）：取消键归弹窗
func _covered_by_dialog() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for c in tree.root.find_children("SkinConfirm*", "", true, false):
		if c is XSkinConfirm and (c as CanvasItem).is_visible_in_tree() and not c.is_queued_for_deletion():
			return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		focused = false


func _gui_input(event: InputEvent) -> void:
	var down := false
	var hit := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		down = event.pressed
		hit = true
	elif event is InputEventScreenTouch:
		down = event.pressed
		hit = true
	if not hit:
		return
	accept_event()
	if down:
		_down = true
	elif _down:
		_down = false
		if Rect2(Vector2.ZERO, size).has_point(event.position):
			XSkinKeyHints.fire.call_deferred("取消")
	queue_redraw()


func _draw() -> void:
	var c := Color(XUiSkin.SEL_LINE) if _down else Color(XUiSkin.GOLD, 0.9)
	var cx := W / 2.0
	var cy := H / 2.0 + 2.0
	if XUiSkin.polish_on():
		draw_circle(Vector2(cx, cy), 16.0, Color(0.07, 0.058, 0.056, 0.78 if _down else 0.56))
		draw_arc(Vector2(cx, cy), 16.0, 0, TAU, 32, Color(XUiSkin.SEL_LINE, 0.85) if _down else Color(XUiSkin.GOLD, 0.38), 1.2, true)
	draw_polyline(PackedVector2Array([Vector2(cx + 6, cy - 12), Vector2(cx - 6, cy), Vector2(cx + 6, cy + 12)]), c, 3.0, true)
	if focused and XUiSkin.detail_on() and XUiSkin.show_focus_ring():
		XUiSkin.draw_focus_circle(self, Vector2(cx, cy), 16.0)
