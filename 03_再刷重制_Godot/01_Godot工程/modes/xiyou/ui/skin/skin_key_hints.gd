class_name XSkinKeyHints
extends Control
## 【cc·天启篇·未经审查】底部按键提示：右对齐一排「[键] 说明」，键名套圆角胶囊框（小A文字审：按键提示统一套框）。
## 放在页面右下，离底 10（XUiSkin.HINT_BOTTOM）；place(view) 按视口和安全边距摆。

## [[键, 说明], …]，如 [["确定", "进入"], ["取消", "返回"], ["Q / E", "换组"]]
var hints: Array = []
var font_size := 15
const H := 22.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hints(arr: Array) -> void:
	hints = arr
	size = Vector2(total_width(), H)
	queue_redraw()


func total_width() -> float:
	var f := XUiSkin.font("body")
	var w := 0.0
	for i in hints.size():
		var h: Array = hints[i]
		w += f.get_string_size(str(h[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 20 + 6
		w += f.get_string_size(str(h[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if i < hints.size() - 1:
			w += 16
	return w


## 摆到视口右下（右边对齐安全边距或 16:9 的 24）
func place(view: Vector2) -> void:
	position = Vector2(view.x - XSkinLayout.margin_for(view.x) - total_width(), view.y - XUiSkin.HINT_BOTTOM - H)


func _draw() -> void:
	var f := XUiSkin.font("body")
	var ci := get_canvas_item()
	var x := 0.0
	for h in hints:
		var kw := f.get_string_size(str(h[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 20
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = XUiSkin.TEXT_2
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(11)
		sb.draw(ci, Rect2(x, 0, kw, H))
		draw_string(f, Vector2(x + 10, H / 2.0 + font_size * 0.36), str(h[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, XUiSkin.TEXT)
		x += kw + 6
		draw_string(f, Vector2(x, H / 2.0 + font_size * 0.36), str(h[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, XUiSkin.TEXT_2)
		x += f.get_string_size(str(h[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16
