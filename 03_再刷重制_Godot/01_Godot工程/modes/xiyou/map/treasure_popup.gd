class_name XTreasurePopup
extends Node2D
## MOG_TreasurePopup：事件指令获得物品/武器/护甲/金钱（125～128，数量 > 0）时，在触发事件的位置浮出「图标 名字 x 数量」
## （金钱只写数量、图标 416）。同一帧获得的几样按序号 fx 往上错开 20 像素、依次多停 15 帧。
## 参数照正式版：字号 25、偏移 Y −32、上浮 1 像素/帧、淡入 15 帧（每帧 +17）、停留 15＋(总数−序号−1)×15 帧、之后每帧 −8 淡出。
## 位置是地图世界坐标（随地图卷动），画法：图标 (0,0)，名字 x 36、宽 145（Bitmap 150×32 的 drawText）。

const FONT_SIZE := 25
const OFFSET_Y := -32.0
const SPEED_Y := 1.0
const FADE_IN := 15
const WAIT := 15
const FADE_SPEED := 8
const SPACE := 20.0
const GOLD_ICON := 416

var rec: Dictionary = {}
var amount := 0
var _wait_in := FADE_IN
var _wait_hold := 0
var _alpha := 0.0
## 图标纹理存在成员里：_draw 里临时建的 AtlasTexture 用完即释放，会画成白块（同 XMVCanvas._keep）
var _icon: Texture2D


## at：事件的 screenX/screenY（世界坐标，脚下中心再减行走图偏移）
func setup(item: Dictionary, n: int, at: Vector2, fx: int, total: int) -> void:
	rec = item
	amount = n
	var f := XUiSkin.font("body") if XUiSkin.on() else XUI.font()
	var fs := 18 if XUiSkin.on() else FONT_SIZE
	var disp := _display_text()
	var wd := f.get_string_size(disp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pad_w := 44.0
	position = Vector2(at.x - (pad_w + wd) / 2.0, at.y - 32 + OFFSET_Y - fx * SPACE)
	_wait_hold = WAIT + (total * WAIT - fx * WAIT)
	_icon = XUI.icon_texture(int(rec.get("iconIndex", 0)) if not rec.is_empty() else GOLD_ICON)


func text() -> String:
	return "%s x %d" % [str(rec.get("name", "")), amount] if not rec.is_empty() else str(amount)


func _display_text() -> String:
	if not XUiSkin.on():
		return text()
	return "%s × %d" % [str(rec.get("name", "")), amount] if not rec.is_empty() else str(amount)


func _tint_color() -> Color:
	if rec.is_empty():
		return XUiSkin.GOLD_LIGHT
	return XQuality.list_color(rec)


func _physics_process(_delta: float) -> void:
	if _wait_in > 0:
		_wait_in -= 1
		_alpha = minf(255.0, _alpha + 17.0)
	elif _wait_hold > 0:
		_wait_hold -= 1
	else:
		position.y -= SPEED_Y
		_alpha = maxf(0.0, _alpha - FADE_SPEED)
		if _alpha <= 0.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var a := _alpha / 255.0
	if XUiSkin.on():
		var f := XUiSkin.font("body")
		var fs := 18
		var t := _display_text()
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sx := minf(1.0, 180.0 / maxf(w, 1.0))
		var dw := w * sx
		var pill_w := 36.0 + dw + 14.0
		var pill_h := 30.0
		var col := _tint_color()
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.06, 0.062, 0.075, 0.88 * a)
		box.border_color = Color(col, 0.65 * a)
		box.set_border_width_all(1)
		box.set_corner_radius_all(8)
		box.shadow_color = Color(0, 0, 0, 0.4 * a)
		box.shadow_size = 6
		box.shadow_offset = Vector2(0, 2)
		draw_style_box(box, Rect2(-6.0, 1.0, pill_w, pill_h))
		if _icon:
			draw_texture_rect(_icon, Rect2(0.0, 4.0, 24.0, 24.0), false, Color(1, 1, 1, a))
		var base := 1.0 + pill_h / 2.0 + fs * 0.35
		draw_set_transform(Vector2(30.0, base), 0.0, Vector2(sx, 1.0))
		draw_string(f, Vector2(0, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.75 * a))
		draw_string(f, Vector2.ZERO, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
		draw_set_transform(Vector2.ZERO)
		return
	if _icon:
		draw_texture(_icon, Vector2.ZERO, Color(1, 1, 1, a))
	var font := XUI.font()
	var t := text()
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var sx := minf(1.0, 145.0 / maxf(w, 1.0))
	var base := 32.0 - (32.0 - FONT_SIZE * 0.7) / 2.0
	draw_set_transform(Vector2(36, base), 0.0, Vector2(sx, 1.0))
	draw_string_outline(font, Vector2.ZERO, t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0, 0, 0, 0.5 * a))
	draw_string(font, Vector2.ZERO, t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)
