class_name XSkinArcGauge
extends Control
## 【cc·天启篇·未经审查】弧形量条：kind＝hp（生命，玫粉）／mp（魔法，蓝）／tp／boss（首领血，玫粉、粗、带外晕）。
## 弧心在控件中心，半径＝短边一半减粗细；从 start_deg 起顺时针走 sweep_deg（0°＝正右）。
## 值变了时显示值 0.3 秒缓出追上（动效关时直接到）；扣血时先留一段白色残影，追上后消失。

var kind := "hp":
	set(v):
		kind = v
		queue_redraw()
var value := 1.0
var max_value := 1.0
var start_deg := 150.0
var sweep_deg := 240.0
var thickness := 6.0
var shown := 1.0      # 正在画的比例
var _trail := 1.0     # 扣血残影的比例
const CATCH_TIME := 0.3


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


static func color_of(k: String) -> Color:
	match k:
		"mp":
			return XUiSkin.MP
		"tp":
			return XUiSkin.TP
	return XUiSkin.HP


func rate() -> float:
	return clampf(value / maxf(max_value, 1.0), 0.0, 1.0)


func set_value(v: float, m := -1.0, instant := false) -> void:
	if m > 0.0:
		max_value = m
	value = v
	if instant or XUiSkin.motion() == XUiSkin.Motion.OFF:
		shown = rate()
		_trail = shown
	elif rate() < shown:
		_trail = maxf(_trail, shown)   # 扣血：残影从现在画到的地方开始
	else:
		_trail = shown
	queue_redraw()


func advance(delta: float) -> void:
	var target := rate()
	if not is_equal_approx(shown, target):
		var k := clampf(delta / CATCH_TIME * 3.0, 0.0, 1.0)
		shown = lerpf(shown, target, k)
		if absf(shown - target) < 0.002:
			shown = target
		queue_redraw()
	elif _trail > shown:
		_trail = maxf(shown, _trail - delta * 1.5)
		queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func arc_radius() -> float:
	return minf(size.x, size.y) / 2.0 - thickness - (8.0 if kind == "boss" else 0.0)


func _draw() -> void:
	var c := size / 2.0
	var r := arc_radius()
	if r <= 0.0:
		return
	var a0 := deg_to_rad(start_deg)
	var a1 := deg_to_rad(start_deg + sweep_deg)
	var col := color_of(kind)
	var pts := maxi(int(sweep_deg / 3.0), 8)
	draw_arc(c, r, a0, a1, pts, Color(1, 1, 1, 0.10), thickness, true)
	if _trail > shown:
		draw_arc(c, r, a0 + (a1 - a0) * shown, a0 + (a1 - a0) * _trail, pts, Color(1, 1, 1, 0.55), thickness, true)
	if shown > 0.0:
		var af := a0 + (a1 - a0) * shown
		if kind == "boss":
			draw_arc(c, r, a0, af, pts, Color(col, 0.18), thickness + 14.0, true)
			draw_arc(c, r, a0, af, pts, Color(col, 0.35), thickness + 6.0, true)
		draw_arc(c, r, a0, af, pts, col, thickness, true)
