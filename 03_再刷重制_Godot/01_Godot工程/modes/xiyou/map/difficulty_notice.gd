class_name XDifficultyNoticeCanvas
extends XMVCanvas
## 原版 Bitmap(1800,80)、drawText(550,0,1100,80,"center")，中心在屏幕宽/2−25。
## 25 遍黑字（dx/dy −2..2）后画彩字，字号34、粗体。提示在地图场景上，进入快照时保留。

var clock: XDifficultyNotice


func _ready() -> void:
	size = Vector2(1800, 80)
	var bold := FontVariation.new()
	bold.base_font = XUI.font()
	bold.variation_embolden = 0.7
	font = bold
	clock = XDifficultyNotice.ensure(get_tree())
	clock.painted.connect(refresh)
	painter = _paint_notice
	refresh()


func refresh() -> void:
	visible = clock.showing
	position = Vector2((get_viewport_rect().size.x - 2250.0) / 2.0, clock.bounce_y)
	modulate.a = clock.opacity / 255.0
	queue_redraw()


func _paint_notice(c: XMVCanvas) -> void:
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			c.text(clock.text, 550 + dx, dy, 1100, "center", Color.BLACK, 34, 80)
	c.text(clock.text, 550, 0, 1100, "center", clock.color, 34, 80)
