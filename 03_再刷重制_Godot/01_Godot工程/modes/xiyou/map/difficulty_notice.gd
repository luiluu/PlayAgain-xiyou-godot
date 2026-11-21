class_name XDifficultyNoticeCanvas
extends XMVCanvas
## 原版 Bitmap(1800,80)、drawText(550,0,1100,80,"center")，中心在屏幕宽/2−25。
## 25 遍黑字（dx/dy −2..2）后画彩字，字号34、粗体。提示在地图场景上，进入快照时保留。

var clock: XDifficultyNotice
var _bold_font: FontVariation
## T361（F-09）回退开关：亮图（雪地）上的可读性——新皮肤胶囊底提到 0.95（旧金难度名在纯白底上对比 ≥ 4.5:1），
## 淡入淡出时胶囊先到满、字后出（字只在底够暗时才显），不再整块半透叠在白底上；false＝回到底 0.92、整块一起淡
static var BACKDROP_V2 := true
const BACKDROP_A := 0.95
## 字的相对透明度（乘在 modulate 上）：BACKDROP_V2 时 = clamp(2a−1) / min(1, 2a)
var _text_a := 1.0


func _ready() -> void:
	size = Vector2(1800, 80)
	_bold_font = FontVariation.new()
	_bold_font.base_font = XUI.font()
	_bold_font.variation_embolden = 0.7
	font = _bold_font
	add_to_group(XSkinNoticeLane.AVOID_GROUP)   # T254 卡 C：提示道亮着时让到这条横幅下面
	clock = XDifficultyNotice.ensure(get_tree())
	clock.painted.connect(refresh)
	painter = _paint_notice
	refresh()


func _boss_arc_bottom() -> float:
	var p := get_parent()
	if p == null:
		return 0.0
	for n in p.get_children():
		if n is XBattleScene and n.visible and n.get("boss_hp") is XSkinBossArc:
			var arc: XSkinBossArc = n.boss_hp
			if arc != null and arc.visible and arc.battler != null and arc.layout_alpha > 0:
				return XSkinBossArc.arc_bottom() + 48.0
	return 0.0


func refresh() -> void:
	var skinned := XUiSkin.on()
	visible = clock.showing
	var a := clock.opacity / 255.0
	modulate.a = a
	_text_a = 1.0
	if skinned and BACKDROP_V2:
		modulate.a = minf(1.0, a * 2.0)
		_text_a = clampf(a * 2.0 - 1.0, 0.0, 1.0) / modulate.a if modulate.a > 0.0 else 0.0
	var vs := get_viewport_rect().size
	if skinned:
		font = XUiSkin.font("title")
		clean_text = true
		var tw := font.get_string_size(clock.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		if XSkinNoticeLane.on():
			font = XUiSkin.font("body")
			tw = _v2_width()
		var bw := maxf(240.0, tw + 48.0)
		var bh := 36.0
		size = Vector2(bw, bh)
		var arc_y := _boss_arc_bottom()
		var y := maxf(clock.bounce_y, arc_y) if arc_y > 0.0 else clock.bounce_y
		position = Vector2(roundf((vs.x - bw) / 2.0), y)
	else:
		font = _bold_font
		clean_text = false
		size = Vector2(1800, 80)
		position = Vector2((vs.x - 2250.0) / 2.0, clock.bounce_y)
	queue_redraw()


## T254 卡 C（R2）：「当前难度：」和难度名分开量、分开上色
func _v2_parts() -> Array:
	var s := clock.text
	var i := s.find("：")
	return [s.substr(0, i + 1), s.substr(i + 1)] if i >= 0 else ["", s]


func _v2_width() -> float:
	var p := _v2_parts()
	return XUiSkin.font("body").get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + XUiSkin.font("title").get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x


## T254 卡 C（R2）：v0.7 深色胶囊（PANEL_LOW 92%＋1px 线），前缀最亮字、难度名旧金；不再用难度色的框和竖条
func _paint_v2(c: XMVCanvas) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(XUiSkin.PANEL_LOW, BACKDROP_A if BACKDROP_V2 else 0.92)
	box.border_color = Color(XUiSkin.LINE, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(int(size.y / 2.0))
	if not BACKDROP_V2:   # 底已实心，不再垫投影（投影超出画布被裁成灰方块）
		box.shadow_color = Color(0, 0, 0, 0.4)
		box.shadow_size = 8
		box.shadow_offset = Vector2(0, 3)
	box.anti_aliasing = true
	c.draw_style_box(box, Rect2(Vector2.ZERO, size))
	var p := _v2_parts()
	var bf := XUiSkin.font("body")
	var tf := XUiSkin.font("title")
	var x := roundf((size.x - _v2_width()) / 2.0)
	var y := roundf(size.y / 2.0 + 18.0 * 0.36)
	XUiSkin.ds(c, bf, Vector2(x, y), p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(XUiSkin.TEXT_HI, _text_a))
	x += bf.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	XUiSkin.ds(c, tf, Vector2(x, y), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(XUiSkin.GOLD, _text_a))


func _paint_notice(c: XMVCanvas) -> void:
	if XSkinNoticeLane.on():
		_paint_v2(c)
		return
	if XUiSkin.on():
		var col: Color = clock.color
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.065, 0.068, 0.08, BACKDROP_A if BACKDROP_V2 else 0.90)
		box.border_color = Color(col, 0.55)
		box.set_border_width_all(1)
		box.set_corner_radius_all(10)
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 8
		box.shadow_offset = Vector2(0, 3)
		c.draw_style_box(box, Rect2(Vector2.ZERO, size))
		c.draw_rect(Rect2(10.0, 9.0, 3.0, size.y - 18.0), Color(col, 0.95))
		var f := XUiSkin.font("title")
		var tw := f.get_string_size(clock.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var tx := roundf((size.x - tw) / 2.0) + 3.0
		var ty := roundf(size.y / 2.0 + 18.0 * 0.35)
		c.draw_string(f, Vector2(tx, ty + 1.0), clock.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0, 0.75 * _text_a))
		c.draw_string(f, Vector2(tx, ty), clock.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(col, col.a * _text_a))
		return
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			c.text(clock.text, 550 + dx, dy, 1100, "center", Color.BLACK, 34, 80)
	c.text(clock.text, 550, 0, 1100, "center", clock.color, 34, 80)
