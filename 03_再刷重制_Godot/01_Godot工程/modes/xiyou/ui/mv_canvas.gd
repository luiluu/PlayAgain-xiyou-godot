class_name XMVCanvas
extends Control
## MV 窗口内容位图（Window_Base.contents）的画法，用于逐像素复现原版界面。
## 坐标即 MV 的 contents 坐标（窗口左上角 + 内边距）。在 painter(canvas) 回调里调用下面的画图函数。
## 参照：原版界面参照工具（03_转换工具/ui_reference）从正式版运行时读出的窗口矩形与绘制代码。
##
## 规则（MV rpg_core Bitmap.drawText / Window_Base）：
## - 文字基线 = y + 行高 - (行高 - 字号×0.7) / 2；超出 maxWidth 时横向压缩（canvas fillText 的 maxWidth）。
## - drawFace：每格 144×144，给定区域小于一格时取中间部分。
## - YEP Gauge Outline 量条：条高 6、底条半透明（160/255）、上移 1px，填充内缩 1px、宽 -2。

const OUTLINE := Color(0, 0, 0, 0.45)
## Mac 上正式版（Chromium/CoreText）画字会加粗笔画；Godot 不加，用同色细描边补上（像素亮度对照见 界面风格.md）
const EMBOLDEN := 1
## 高分屏（窗口缩放 ≥1.5，如 Retina 全屏）上不加这圈同色描边：它按逻辑 1 像素算，放大后成两个多物理像素，字显得粗而软。
## 回退开关 CRISP_HIDPI_TEXT = false：回到任何缩放都加。1280×720 窗口（缩放 1）不受影响。
static var CRISP_HIDPI_TEXT := true

const HIDPI_SCALE := 1.5
const ARROW_DOWN := Rect2(132, 60, 24, 12)
const ARROW_UP := Rect2(132, 24, 24, 12)


## 这一缩放下文字要不要加同色描边加粗（CRISP_HIDPI_TEXT 开时高分屏不加）
static func embolden_at(scale: float) -> bool:
	return EMBOLDEN > 0 and not (CRISP_HIDPI_TEXT and scale >= HIDPI_SCALE)

var painter: Callable
var font: Font
var _t := 0.0
## 光标闪烁（MV Window._updateCursor：活动时每 40 帧透明度起伏）
var blink := false
## 本帧画到的纹理要一直引用到下一次重画，否则局部变量释放后 RID 失效、画成白块
var _keep: Array = []
static var _cache := {}
## 安卓卡顿（Kyo 11-12 v0.01 实机：商店、战斗选技能卡；O-319）：原先 blink 时每帧整块重画（每帧重跑 painter：商店每帧重算整张商品表、
## 战斗技能窗每帧重算每个技能），手机上掉帧。现在闪烁的光标画在背后一层（show_behind_parent，与原先先画光标再画字同序），
## 每帧只重画这一层；内容只在 refresh／queue_redraw 时重画。回退开关 BLINK_FULL_REDRAW = true：回到每帧整块重画。
static var BLINK_FULL_REDRAW := false
var _cursor_layer: Control
## 本次重画登记的闪烁光标 [Rect2, ...]（画在 _cursor_layer）
var _blink_cursors: Array = []


func _init() -> void:
	font = XUI.font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_cursor_layer = Control.new()
	_cursor_layer.name = "BlinkCursor"
	_cursor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_layer.show_behind_parent = true
	_cursor_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cursor_layer.draw.connect(_draw_cursor_layer)
	add_child(_cursor_layer, false, Node.INTERNAL_MODE_BACK)


func _process(delta: float) -> void:
	if blink:
		_t += delta
		if BLINK_FULL_REDRAW:
			queue_redraw()
		elif _cursor_layer != null and not _blink_cursors.is_empty():
			_cursor_layer.queue_redraw()


func _draw() -> void:
	_keep.clear()
	_blink_cursors.clear()
	if painter.is_valid():
		painter.call(self)
	if _cursor_layer != null:
		_cursor_layer.queue_redraw()


func _draw_cursor_layer() -> void:
	var a := blink_alpha()
	for r in _blink_cursors:
		_cursor_layer.draw_style_box(XUI.cursor_style(a), r)


## MV 活动窗口光标的 40 帧明暗周期
func blink_alpha() -> float:
	var n := int(_t * 60.0) % 40
	return 1.0 - (n if n < 20 else 40 - n) * 8.0 / 255.0


func text_width(s: String, size := XUI.FONT_SIZE) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Window_Base.drawText(text, x, y, maxWidth, align)，行高 lh。
## zoom/pivot：整体以 pivot 为中心缩放（MV 精灵 scale，如胜利结算的「等级提升！」）。
## outline：描边色（正式版 Bitmap 默认 rgba(0,0,0,0.45)；宽度被 installDisplayPreferencesRuntime 封顶 0.75px，颜色不封顶）。
func text(s: String, x: float, y: float, max_w: float, align := "left", color := XUI.TEXT, size := XUI.FONT_SIZE, lh := XUI.LINE_HEIGHT, alpha := 1.0, zoom := 1.0, pivot := Vector2.ZERO, outline := OUTLINE) -> void:
	if s == "":
		return
	var w := text_width(s, size)
	var sx := 1.0
	if max_w > 0 and w > max_w:
		sx = max_w / w
	var dw := w * sx
	var tx := x
	if align == "center":
		tx = x + (max_w - dw) / 2.0
	elif align == "right":
		tx = x + max_w - dw
	var base := y + lh - (lh - size * 0.7) / 2.0
	var c := Color(color, color.a * alpha)
	var xf := Transform2D(0.0, Vector2(sx, 1.0), 0.0, Vector2(roundf(tx), roundf(base)))
	if zoom != 1.0:
		xf = Transform2D(0.0, Vector2(zoom, zoom), 0.0, pivot - pivot * zoom) * xf
	draw_set_transform_matrix(xf)
	draw_string_outline(font, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 1, Color(outline, outline.a * alpha))
	if embolden_at(get_viewport().get_final_transform().get_scale().x):
		draw_string_outline(font, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, EMBOLDEN, c)
	draw_string(font, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
	draw_set_transform(Vector2.ZERO)


## size：图标边长（Olivia 缩放窗口用 round(32×0.8)=26，按 MV blt 缩放）
func icon(index: int, x: float, y: float, alpha := 1.0, size := 32.0) -> void:
	var t := XUI.icon_texture(index)
	if t:
		_keep.append(t)
		if size == 32.0:
			draw_texture(t, Vector2(x, y), Color(1, 1, 1, alpha))
		else:
			draw_texture_rect(t, Rect2(x, y, size, size), false, Color(1, 1, 1, alpha))


## 成就专用徽章（img/codex_achievements/<file>.png，256²）缩到 size×size；图没导出时不画（见 XAchievementBadge）
func badge(file: String, x: float, y: float, size: float, alpha := 1.0) -> void:
	var p := XDB.img_path("codex_achievements", file)
	if p == "":
		return
	if not _cache.has(p):
		_cache[p] = load(p)
	var tex: Texture2D = _cache[p]
	if tex == null:
		return
	draw_texture_rect(tex, Rect2(x, y, size, size), false, Color(1, 1, 1, alpha))


func fill_rect(r: Rect2, color: Color) -> void:
	draw_rect(r, color)


## 渐变描边字（成就 142 名字）：外圈阴影色、描边色、中间渐变色填充近似（参数见 XAchievementBadge.name_plan）
func gradient_text(plan: Dictionary) -> void:
	var s := str(plan.text)
	var size := int(plan.size)
	var pos := Vector2(roundf(float(plan.x)), roundf(float(plan.baseline)))
	var shadow := Color(str(plan.shadow), 0.6)
	var mid := Color(str(plan.stops[1][1]))
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(float(plan.lineWidth) + float(plan.shadowBlur)), shadow)
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(float(plan.lineWidth)), Color(str(plan.stroke)))
	# 填充：用渐变中间色近似（Godot 画布没有逐字渐变）
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, mid)


## Window_Base.drawFace(faceName, faceIndex, x, y, width, height)
func face(face_name: String, index: int, x: float, y: float, w := 144.0, h := 144.0, alpha := 1.0) -> void:
	var p := XDB.img_path("faces", face_name) if face_name != "" else ""
	if p == "":
		return
	if not _cache.has(p):
		_cache[p] = load(p)
	var tex: Texture2D = _cache[p]
	var pw := 144.0
	var ph := 144.0
	var sw := minf(w, pw)
	var sh := minf(h, ph)
	var dx := floorf(x + maxf(w - pw, 0) / 2.0)
	var dy := floorf(y + maxf(h - ph, 0) / 2.0)
	var sx := (index % 4) * pw + (pw - sw) / 2.0
	var sy := floorf(index / 4.0) * ph + (ph - sh) / 2.0
	draw_texture_rect_region(tex, Rect2(dx, dy, sw, sh), Rect2(sx, sy, sw, sh), Color(1, 1, 1, alpha))


## Window_Base.drawCharacter：行走图朝下中间一格，底边中点在 (x, y)；clip_h > 0 时只画上面 clip_h 像素（列表行覆盖下一行的部分）。
func character(name: String, index: int, x: float, y: float, clip_h := 0.0, alpha := 1.0) -> void:
	var p := XDB.img_path("characters", name) if name != "" else ""
	if p == "":
		return
	if not _cache.has(p):
		_cache[p] = load(p)
	var tex: Texture2D = _cache[p]
	if tex == null:
		return
	var big := name.begins_with("$") or name.begins_with("!$")
	var pw := tex.get_width() / (3.0 if big else 12.0)
	var ph := tex.get_height() / (4.0 if big else 8.0)
	var sx := ((index % 4) * 3 + 1) * pw if not big else pw
	var sy := floorf(index / 4.0) * 4.0 * ph if not big else 0.0
	var h := ph if clip_h <= 0.0 else minf(ph, clip_h)
	draw_texture_rect_region(tex, Rect2(x - pw / 2.0, y - ph, pw, h), Rect2(sx, sy, pw, h), Color(1, 1, 1, alpha))


## YEP_CoreEngine drawGauge（Gauge Outline 开启）
func gauge(dx: float, dy: float, dw: float, rate: float, c1: Color, c2: Color, lh := XUI.LINE_HEIGHT) -> void:
	var gh := 6.0
	var gy := dy + lh - gh - 2.0
	draw_rect(Rect2(dx, gy - 1.0, dw, gh), Color(XUI.GAUGE_BACK, 160.0 / 255.0))
	var fw := maxf(floorf(dw * clampf(rate, 0.0, 1.0)) - 2.0, 0.0)
	if fw > 0.0:
		gradient(Rect2(dx + 1.0, gy, fw, gh - 2.0), c1, c2)


func gradient(r: Rect2, c1: Color, c2: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c1, c2, c2, c1]))


## 选中光标（Window.png 光标框）；blink 时按 MV 活动窗口的 40 帧周期变淡。
func cursor(r: Rect2, active := true) -> void:
	var a := 1.0
	if active and blink:
		if not BLINK_FULL_REDRAW:
			_blink_cursor(r)
			return
		a = blink_alpha()
	draw_style_box(XUI.cursor_style(a), r)


## 闪烁光标登记到背后那层
func _blink_cursor(r: Rect2) -> void:
	_blink_cursors.append(r)


## MV Window 的上下滚动箭头（皮肤 Window.png），x 为窗口宽的一半，坐标相对窗口左上。
static func arrows(win: Control, up: bool, down: bool) -> void:
	var sk := XUI.skin()
	if sk == null:
		return
	var w := win.size.x
	if up:
		win.draw_texture_rect_region(sk, Rect2(w / 2.0 - 12, 6, 24, 12), ARROW_UP)
	if down:
		win.draw_texture_rect_region(sk, Rect2(w / 2.0 - 12, win.size.y - 12 - 6, 24, 12), ARROW_DOWN)
