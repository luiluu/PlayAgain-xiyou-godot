class_name XSkinBattleRing
extends XBattleList
## 【cc·天启篇·未经审查】新界面 2A：战斗指令环（样稿 battle：行动者身边一圈圆球，球里写指令名，上方写「某某的回合」）。
## 只换画法和点选范围：选中、确定、上下循环、点选、右键、回显都继承 XBattleList，XBattleScene 用法不变。
## 排法：第 1 项在行动者左上（258°），往下逆时针排、相邻 36°（上下键＝画面上往下／往上）；超过 6 项时在 18°～270° 的
## 左半边等分、半径加大到球不相叠。环心＝角色脚底往上 32（样稿 819,494 对脚底 526）＋ OFFSET，整环收在画面里。
## 两排站位（Kyo 问过「指令窗要不要挪」，还没定）：位置参数都是 static var，定了只改这几个数。

## 环半径（样稿 124；6 项时为了球不相叠实际是 139）、球半径（样稿 82 直径）
static var RADIUS := 124.0
static var ORB_R := 41.0
## 项多时半径最多加到这么大，再多就把球缩小（最小 28）
static var MAX_RADIUS := 230.0
## 第 1 项的角度（度，0＝右、90＝下）、相邻两项的角度差（往小走＝逆时针＝画面上往下）
static var START_DEG := 258.0
static var STEP_DEG := 36.0
## 超过 6 项时可用的弧（从 START_DEG 往下逆时针走多少度）
static var MAX_SPAN_DEG := 252.0
## 环心相对角色脚底的偏移（两排站位定了挪这里）
static var OFFSET := Vector2(0, -32)
## 离画面边至少留多少
static var MARGIN := 8.0

var title := ""
var radius := 124.0
var orb_r := 41.0
var center := Vector2.ZERO       # 本节点里的环心
var _angles: Array = []
var _spin := 0.0
var _drawn_active := true
## T024 选中放大：选中的球原本直接 ×1.08，现在 0.12 秒过渡到 1.08（相邻 36° 的球在 1.15 时会相叠 2px，所以留 1.08）
const SEL_PEAK := 1.08
var sel_scale: XSkinSelScale


static func create_ring(parent: Control, list: Array, actor_name := "") -> XSkinBattleRing:
	var w := XSkinBattleRing.new()
	w.entries = list
	w.align = "center"
	w.rows = maxi(list.size(), 1)
	w.padding = 0.0
	w.title = ("%s的回合" % actor_name) if actor_name != "" else ""
	w.canvas.visible = false
	w._layout_ring()
	w.sel_scale = XSkinSelScale.attach(w, SEL_PEAK)
	parent.add_child(w)
	w.select(0)
	return w


## 各项角度与半径；节点大小＝整环（球＋外圈虚线＋上方名字）的外框
func _layout_ring() -> void:
	var n := maxi(entries.size(), 1)
	var step := STEP_DEG
	if (n - 1) * step > MAX_SPAN_DEG:
		step = MAX_SPAN_DEG / float(n - 1)
	# 球不相叠：相邻两球心距 ≥ 2·球半径＋4；半径到 MAX_RADIUS 还不够就缩球
	var half := sin(deg_to_rad(step) / 2.0)
	radius = clampf((ORB_R + 2.0) / half, RADIUS, maxf(RADIUS, MAX_RADIUS))
	orb_r = minf(ORB_R, radius * half - 2.0)
	_angles = []
	for i in n:
		_angles.append(START_DEG - i * step)
	var box := Rect2(Vector2(-radius - 4, -radius - 4), Vector2(radius + 4, radius + 4) * 2)
	for i in n:
		var p := orb_offset(i)
		box = box.merge(Rect2(p - Vector2(orb_r + 10, orb_r + 10), Vector2(orb_r + 10, orb_r + 10) * 2))
	if title != "":
		var top := box.position.y
		box = box.merge(Rect2(Vector2(-110, top - 30), Vector2(220, 30)))
	center = -box.position
	size = box.size


## 第 i 项球心相对环心
func orb_offset(i: int) -> Vector2:
	if i < 0 or i >= _angles.size():
		return Vector2.ZERO
	return Vector2.from_angle(deg_to_rad(float(_angles[i]))) * radius


func orb_pos(i: int) -> Vector2:
	return center + orb_offset(i)


func angle_of(i: int) -> float:
	return float(_angles[i]) if i >= 0 and i < _angles.size() else 0.0


## XBattleScene._place_near_actor 转来：feet＝角色脚底（画布坐标），box＝画布大小；整环收在画面里
## 收口批（TOUCH_V2，Kyo 定）：触屏时整环固定在右下角（拇指够得着，每回合不换地方）；键盘手柄照旧跟着角色。
func place_for_actor(feet: Vector2, box: Vector2) -> void:
	if fixed_corner():
		position = Vector2(box.x - size.x - MARGIN, box.y - size.y - MARGIN)
		return
	var c := feet + OFFSET
	var p := c - center
	p.x = clampf(p.x, MARGIN, maxf(MARGIN, box.x - size.x - MARGIN))
	p.y = clampf(p.y, MARGIN, maxf(MARGIN, box.y - size.y - MARGIN))
	position = p


static func fixed_corner() -> bool:
	return XUiSkin.TOUCH_V2 and XUiSkin.touch()


## 实际画出来的范围（本节点坐标）：各球加上方「某某的回合」一行（新界面 4A 让位用）
func drawn_rect() -> Rect2:
	if entries.is_empty():
		return Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	var r := Rect2(orb_pos(0) - Vector2(orb_r, orb_r), Vector2(orb_r, orb_r) * 2.0)
	for i in range(1, entries.size()):
		r = r.merge(Rect2(orb_pos(i) - Vector2(orb_r, orb_r), Vector2(orb_r, orb_r) * 2.0))
	r.position.y -= 30.0   # 名字一行（字号 17，离球顶 10）
	r.size.y += 30.0
	return r


## 环心在父节点里的位置（测试、截图看）
func ring_center() -> Vector2:
	return position + center


func refresh() -> void:
	queue_redraw()


func _paint(_c: XMVCanvas) -> void:
	pass


func _hit(p: Vector2) -> int:
	var local := p - position
	for i in entries.size():
		if local.distance_to(orb_pos(i)) <= orb_r + 2.0:
			return i
	return -1


func _process(delta: float) -> void:
	if active != _drawn_active:
		queue_redraw()
	if XUiSkin.breathing() and active:
		_spin += delta
		queue_redraw()


## 失活（开着技能／物品列表、选目标、看怪物信息）时整环不画（样稿：列表出来环就收起；选目标时 XBattleScene 另把它淡出）
func _draw() -> void:
	_drawn_active = active
	if not active:
		return
	var line := XUiSkin.LINE
	# 外圈虚线（14 秒一圈）
	var dashes := 48
	var off := _spin * TAU / 14.0
	for k in dashes:
		var a0 := off + k * TAU / dashes
		draw_arc(center, radius, a0, a0 + TAU / dashes * 0.55, 4, Color(XUiSkin.GOLD_LIGHT, 0.45), 1.5, true)
	# 名字（某某的回合）
	var title_font := XUiSkin.font("title")
	if title != "":
		var fs := 17
		var tw := title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var top := INF
		for i in entries.size():
			top = minf(top, orb_pos(i).y - orb_r)
		if top == INF:
			top = center.y - radius
		var pos := Vector2(center.x - tw / 2.0, top - 10.0)
		if XSkin4A.text_on():  # 新界面 4A（A5）：回合提示垫深色胶囊底
			XSkin4A.draw_text_backing(self, pos.x, pos.y, tw, fs)
		draw_string_outline(title_font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
		XUiSkin.ds(self, title_font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, XUiSkin.GOLD)
	# 球
	if sel_scale != null:
		sel_scale.sel(index)
	for i in entries.size():
		_draw_orb(i, title_font)


func _draw_orb(i: int, font: Font) -> void:
	var e: Dictionary = entries[i]
	var on := i == index and active
	var sel := i == index
	var en := bool(e.get("enabled", true))
	var p := orb_pos(i)
	var r := orb_r * orb_scale(i)
	var alpha := 1.0 if en else 0.5
	if sel:
		var g := XUiSkin.glow_texture()
		draw_texture_rect(g, Rect2(p - Vector2(r + 18, r + 18), Vector2(r + 18, r + 18) * 2), false,
			Color(XUiSkin.SEL_FILL, (0.85 if on else 0.4) * XUiSkin.breath_alpha()))
	draw_circle(p + Vector2(0, 3), r + 2, Color(0, 0, 0, 0.45 * alpha))
	draw_circle(p, r, Color(XUiSkin.ORB_LOW, 0.92))
	draw_circle(p + Vector2(-r * 0.15, -r * 0.2), r * 0.72, Color(XUiSkin.ORB_HI, 0.85 * alpha))
	if sel:
		draw_circle(p, r, XUiSkin.SEL_LINE, false, 2.5, true)
	else:
		draw_circle(p, r, Color(XUiSkin.LINE, 0.6 * alpha), false, 1.5, true)
	var text := str(e.get("text", ""))
	var color := Color.WHITE if sel else XUiSkin.GOLD
	color.a = alpha
	_orb_text(font, text, p, r, color)


## 第 i 个球现在的倍数（选中放大关掉时照旧直接 ×1.08）
func orb_scale(i: int) -> float:
	if sel_scale == null or not XSkinSelScale.ENABLED:
		return SEL_PEAK if i == index else 1.0
	sel_scale.sel(index)
	return sel_scale.k(i)


## 球里的字：一行放得下就一行（23 起、最小 14）；四字以上放不下折两行
func _orb_text(font: Font, text: String, p: Vector2, r: float, color: Color) -> void:
	var max_w := r * 1.7
	var lines := [text]
	var fs := orb_font_size(text, max_w)
	if fs < 17 and text.length() >= 4:
		var half := ceili(text.length() / 2.0)
		lines = [text.substr(0, half), text.substr(half)]
		fs = mini(orb_font_size(lines[0], max_w), orb_font_size(lines[1], max_w))
	var lh := fs * 1.1
	var y0 := p.y - lh * lines.size() / 2.0 + fs * 0.86
	for k in lines.size():
		var tw := font.get_string_size(lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(p.x - tw / 2.0, y0 + k * lh)
		draw_string_outline(font, pos, lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.6 * color.a))
		XUiSkin.ds(self, font, pos, lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func orb_font_size(text: String, max_w: float) -> int:
	var font := XUiSkin.font("title")
	var fs := 23
	while fs > XUiSkin.FS_MIN and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 1
	return fs
