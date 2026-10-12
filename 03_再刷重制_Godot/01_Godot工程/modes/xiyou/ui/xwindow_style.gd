class_name XWindowStyle
extends StyleBox
## 原版窗口皮肤（img/system/Window.png，MV Window 的画法）：
##   背景 (0,0,96,96) 拉伸 ＋ 花纹 (0,96,96,96) 平铺，四周内缩 4px，透明度 back_opacity；
##   边框 (96,0,96,96) 九宫格，角 24px；
##   cursor=true 时改画选中光标 (96,96,48,48)，九宫格角 4px。
## opacity 对应 MV window.opacity（背景与边框一起乘；菜单场景 MOG_MenuBackground 设为 30）。

var skin: Texture2D
var opacity := 1.0
var back_opacity := 192.0 / 255.0
var cursor := false
var cursor_alpha := 1.0


func _draw(ci: RID, rect: Rect2) -> void:
	if skin == null:
		return
	var rs := RenderingServer
	if cursor:
		rs.canvas_item_add_nine_patch(ci, rect, Rect2(96, 96, 48, 48), skin.get_rid(), Vector2(4, 4), Vector2(4, 4),
			RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, Color(1, 1, 1, cursor_alpha))
		return
	if opacity <= 0.0:
		return
	var back := rect.grow(-4)
	if back.size.x > 0 and back.size.y > 0:
		var tint := Color(1, 1, 1, back_opacity * opacity)
		rs.canvas_item_add_texture_rect_region(ci, back, skin.get_rid(), Rect2(0, 0, 96, 96), tint)
		var y := 0.0
		while y < back.size.y:
			var h := minf(96.0, back.size.y - y)
			var x := 0.0
			while x < back.size.x:
				var w := minf(96.0, back.size.x - x)
				rs.canvas_item_add_texture_rect_region(ci, Rect2(back.position + Vector2(x, y), Vector2(w, h)), skin.get_rid(), Rect2(0, 96, w, h), tint)
				x += 96.0
			y += 96.0
	rs.canvas_item_add_nine_patch(ci, rect, Rect2(96, 0, 96, 96), skin.get_rid(), Vector2(24, 24), Vector2(24, 24),
		RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, false, Color(1, 1, 1, opacity))
