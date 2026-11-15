class_name XSkinBackButton
extends Control
## 【cc·天启篇·未经审查】收口批（TOUCH_V2，Fable 审 A4）：整页左上角固定的「‹」返回，点一下＝取消（同按取消键、两指点、安卓返回键）。
## 位置永远在页名前面；键盘手柄时也显示（只是个记号），点击只在松手且还在钮上时才算。

const W := 36.0
const H := 48.0
var _down := false


func _init() -> void:
	name = "SkinBack"
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP


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
	draw_polyline(PackedVector2Array([Vector2(cx + 6, cy - 12), Vector2(cx - 6, cy), Vector2(cx + 6, cy + 12)]), c, 3.0, true)
