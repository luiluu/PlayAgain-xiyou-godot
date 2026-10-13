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
	var wd := XUI.font().get_string_size(text(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	position = Vector2(at.x - (32 + 12 + wd) / 2.0, at.y - 32 + OFFSET_Y - fx * SPACE)
	_wait_hold = WAIT + (total * WAIT - fx * WAIT)
	_icon = XUI.icon_texture(int(rec.get("iconIndex", 0)) if not rec.is_empty() else GOLD_ICON)


func text() -> String:
	return "%s x %d" % [str(rec.get("name", "")), amount] if not rec.is_empty() else str(amount)


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
