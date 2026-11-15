class_name XDifficultyNoticeCanvas
extends XMVCanvas
## 原版 Bitmap(1800,80)、drawText(550,0,1100,80,"center")，中心在屏幕宽/2−25。
## 25 遍黑字（dx/dy −2..2）后画彩字，字号34、粗体。提示在地图场景上，进入快照时保留。

var clock: XDifficultyNotice
var _bold_font: FontVariation


func _ready() -> void:
	size = Vector2(1800, 80)
	_bold_font = FontVariation.new()
	_bold_font.base_font = XUI.font()
	_bold_font.variation_embolden = 0.7
	font = _bold_font
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
	modulate.a = clock.opacity / 255.0
	var vs := get_viewport_rect().size
	if skinned:
		font = XUiSkin.font("title")
		clean_text = true
		var tw := font.get_string_size(clock.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
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


func _paint_notice(c: XMVCanvas) -> void:
	if XUiSkin.on():
		var col: Color = clock.color
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.065, 0.068, 0.08, 0.90)
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
		c.draw_string(f, Vector2(tx, ty + 1.0), clock.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0, 0.75))
		c.draw_string(f, Vector2(tx, ty), clock.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		return
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			c.text(clock.text, 550 + dx, dy, 1100, "center", Color.BLACK, 34, 80)
	c.text(clock.text, 550, 0, 1100, "center", clock.color, 34, 80)
