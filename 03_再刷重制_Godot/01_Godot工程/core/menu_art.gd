extends Control
## 【Codex·未经Claude检验】 Code-drawn background; no source-game art imported.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	for i in range(32):
		var t := float(i) / 31.0
		draw_rect(Rect2(0, h * t, w, h / 31.0 + 1), Color("14242d").lerp(Color("071417"), t))
	var moon := Vector2(w * 0.79, h * 0.24)
	draw_circle(moon, h * 0.14, Color(0.79, 0.66, 0.38, 0.07))
	draw_arc(moon, h * 0.125, 0, TAU, 96, Color(0.79, 0.66, 0.38, 0.22), 1.0, true)
	draw_circle(moon, h * 0.085, Color(0.79, 0.66, 0.38, 0.10))
	for layer in range(3):
		var points := PackedVector2Array([Vector2(0, h)])
		for i in range(17):
			var x := w * float(i) / 16.0
			var y := h * (0.70 + layer * 0.075) - sin(i * 1.28 + layer * 2.1) * h * 0.075
			points.append(Vector2(x, y))
		points.append(Vector2(w, h))
		draw_colored_polygon(points, [Color("18353a"), Color("10282d"), Color("091c20")][layer])
	for i in range(42):
		var p := Vector2(fmod(i * 193.0 + 43.0, max(w, 1.0)), h * (0.12 + fmod(i * 0.037, 0.50)))
		draw_circle(p, 1.2 if i % 3 else 2.0, Color(0.85, 0.72, 0.47, 0.16))
	draw_line(Vector2(48, 40), Vector2(w - 48, 40), Color(0.78, 0.65, 0.40, 0.18), 1)
	draw_line(Vector2(48, h - 40), Vector2(w - 48, h - 40), Color(0.78, 0.65, 0.40, 0.18), 1)
