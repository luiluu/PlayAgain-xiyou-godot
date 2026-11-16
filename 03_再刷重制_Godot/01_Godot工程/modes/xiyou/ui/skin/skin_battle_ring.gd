class_name XSkinBattleRing
extends XBattleList
## 【cc·天启篇·未经审查】新界面 2A：战斗指令环（样稿 battle：行动者身边一圈圆球，球里写指令名，上方写「某某的回合」）。
## 只换画法和点选范围：选中、确定、上下循环、点选、右键、回显都继承 XBattleList，XBattleScene 用法不变。
## 排法：第 1 项在行动者左上（258°），往下逆时针排、相邻 36°（上下键＝画面上往下／往上）；超过 6 项时在 18°～270° 的
## 左半边等分、半径加大到球不相叠。环心＝角色脚底往上 32（样稿 819,494 对脚底 526）＋ OFFSET，整环收在画面里。
## 两排站位（Kyo 问过「指令窗要不要挪」，还没定）：位置参数都是 static var，定了只改这几个数。

## 环半径、球半径。T096（Kyo 11-16「栏位圈太大，缩小，只有选到的稍微放大 20%」）：球直径 82→64、选中 1.2 倍；
## 半径按「选中的球放大后也不碰邻球」算（6 项实际约 120）。旧值（样稿 124／82 直径／选中 1.08）在 SMALL_ORBS＝false 时用（可回退）。
static var SMALL_ORBS := true
static var RADIUS := 116.0
static var ORB_R := 32.0
const OLD_RADIUS := 124.0
const OLD_ORB_R := 41.0
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
## T024 选中放大：0.12 秒过渡到 SEL_PEAK（T096 起 1.2；旧 1.08）
const SEL_PEAK := 1.2
const OLD_SEL_PEAK := 1.08
var sel_scale: XSkinSelScale
## T096 动效：铺开计时（秒，≥ intro_total() 算铺完）、失活淡出（0～1）、新选中那颗的白圈闪（秒）
var intro_elapsed := 999.0
var vis := 1.0
var _flash_i := -1
var _flash_t := 999.0
var _last_index := -1
const FLASH_TIME := 0.25


static func base_radius() -> float:
	return RADIUS if SMALL_ORBS else OLD_RADIUS


static func base_orb_r() -> float:
	return ORB_R if SMALL_ORBS else OLD_ORB_R


static func peak() -> float:
	return SEL_PEAK if SMALL_ORBS else OLD_SEL_PEAK


static func create_ring(parent: Control, list: Array, actor_name := "") -> XSkinBattleRing:
	var w := XSkinBattleRing.new()
	w.entries = list
	w.align = "center"
	w.rows = maxi(list.size(), 1)
	w.padding = 0.0
	w.title = ("%s的行动" % actor_name) if actor_name != "" else ""   # T096：同样稿「美娜的行动」；「某某的回合」留给换人提示
	w.canvas.visible = false
	w._layout_ring()
	w.sel_scale = XSkinSelScale.attach(w, peak())
	if XSkinBattleMotion.on():
		w.intro_elapsed = 0.0
	parent.add_child(w)
	w.select(0)
	w._last_index = w.index
	return w


## 各项角度与半径；节点大小＝整环（球＋外圈虚线＋上方名字）的外框
func _layout_ring() -> void:
	var n := maxi(entries.size(), 1)
	var step := STEP_DEG
	if (n - 1) * step > MAX_SPAN_DEG:
		step = MAX_SPAN_DEG / float(n - 1)
	# 球不相叠：相邻两球心距 ≥ 2·球半径＋4；半径到 MAX_RADIUS 还不够就缩球
	var half := sin(deg_to_rad(step) / 2.0)
	# 相邻两颗：一颗放大到 peak、一颗原大，也留 4 的缝（T096；旧算法只按原大留缝）
	var grow := (1.0 + peak()) / 2.0 if SMALL_ORBS else 1.0
	radius = clampf((base_orb_r() * grow + 2.0) / half, base_radius(), maxf(base_radius(), MAX_RADIUS))
	orb_r = minf(base_orb_r(), (radius * half - 2.0) / grow)
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
	# T096：铺开、失活淡出／回来淡入、新选中白圈闪
	var moving := XSkinBattleMotion.on()
	if intro_elapsed < intro_total():
		intro_elapsed = intro_elapsed + delta if moving else 999.0
		queue_redraw()
	var want := 1.0 if active else 0.0
	if vis != want:
		vis = move_toward(vis, want, delta / XSkinBattleMotion.RING_FADE) if moving else want
		queue_redraw()
	if index != _last_index:
		_last_index = index
		if moving and active and index >= 0:
			_flash_i = index
			_flash_t = 0.0
	if _flash_t < FLASH_TIME:
		_flash_t += delta
		queue_redraw()


## 铺开总时长：最后一颗也长完
func intro_total() -> float:
	return XSkinBattleMotion.RING_ORB_IN + XSkinBattleMotion.RING_STAGGER * maxf(entries.size() - 1, 0)


## 第 i 颗的铺开进度 0～1
func intro_of(i: int) -> float:
	if intro_elapsed >= intro_total():
		return 1.0
	return clampf((intro_elapsed - XSkinBattleMotion.RING_STAGGER * i) / XSkinBattleMotion.RING_ORB_IN, 0.0, 1.0)


## 失活（开着技能／物品列表、选目标、看怪物信息）时整环不画（样稿：列表出来环就收起；选目标时 XBattleScene 另把它淡出）
func _draw() -> void:
	_drawn_active = active
	self_modulate.a = vis   # T096：失活时淡出（动效关时 vis 当场归 0，同原来直接不画）
	if vis <= 0.0:
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
		var ta := XSkinTurnCue.title_alpha() if XSkinBattleMotion.on() else 1.0   # T096：换人提示胶囊淡掉后再出来
		if ta < 1.0:
			queue_redraw()
		if XSkin4A.text_on() and ta >= 1.0:  # 新界面 4A（A5）：回合提示垫深色胶囊底
			XSkin4A.draw_text_backing(self, pos.x, pos.y, tw, fs)
		draw_string_outline(title_font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7 * ta))
		draw_string(title_font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(XUiSkin.GOLD, ta))
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
	var t := intro_of(i)
	var r := orb_r * orb_scale(i) * lerpf(0.6, 1.0, XSkinBattleMotion.ease_out_back(t))   # T096 铺开：0.6→1、错开 0.03 秒
	if t <= 0.0:
		return
	var alpha := (1.0 if en else 0.5) * minf(1.0, t * 1.6)
	if sel:
		var g := XUiSkin.glow_texture()
		draw_texture_rect(g, Rect2(p - Vector2(r + 18, r + 18), Vector2(r + 18, r + 18) * 2), false,
			Color(XUiSkin.SEL_FILL, (0.85 if on else 0.4) * XUiSkin.breath_alpha()))
	draw_circle(p + Vector2(0, 3), r + 2, Color(0, 0, 0, 0.45 * alpha))
	draw_circle(p, r, Color(XUiSkin.ORB_LOW, 0.92))
	draw_circle(p + Vector2(-r * 0.15, -r * 0.2), r * 0.72, Color(XUiSkin.ORB_HI, 0.85 * alpha))
	if sel:
		draw_circle(p, r, XUiSkin.SEL_LINE, false, 2.5, true)
		if i == _flash_i and _flash_t < FLASH_TIME:   # T096：新选中闪一圈白（样稿 bo1），0.25 秒散开淡掉
			var f := _flash_t / FLASH_TIME
			draw_circle(p, r + 2.0 + 6.0 * f, Color(1, 1, 1, 0.9 * (1.0 - f)), false, 3.0 * (1.0 - f) + 0.5, true)
	else:
		draw_circle(p, r, Color(XUiSkin.LINE, 0.6 * alpha), false, 1.5, true)
	var text := str(e.get("text", ""))
	var color := Color.WHITE if sel else XUiSkin.GOLD
	color.a = alpha
	_orb_text(font, text, p, r, color)


## 第 i 个球现在的倍数（选中放大关掉时照旧直接 ×1.08）
func orb_scale(i: int) -> float:
	if sel_scale == null or not XSkinSelScale.ENABLED:
		return peak() if i == index else 1.0
	sel_scale.sel(index)
	return sel_scale.k(i)


## 球里的字：一行放得下就一行（23 起、最小 14）；四字以上放不下折两行
func _orb_text(font: Font, text: String, p: Vector2, r: float, color: Color) -> void:
	var max_w := r * 1.7
	var lines := [text]
	var start := clampi(roundi(r * 0.56), XUiSkin.FS_MIN, 23)   # T096：字跟球一起缩放（41→23 号、32→18 号、选中 1.2 倍→21 号）
	var fs := orb_font_size(text, max_w, start)
	if fs < mini(17, start) and text.length() >= 4:
		var half := ceili(text.length() / 2.0)
		lines = [text.substr(0, half), text.substr(half)]
		fs = mini(orb_font_size(lines[0], max_w, start), orb_font_size(lines[1], max_w, start))
	var lh := fs * 1.1
	var y0 := p.y - lh * lines.size() / 2.0 + fs * 0.86
	for k in lines.size():
		var tw := font.get_string_size(lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(p.x - tw / 2.0, y0 + k * lh)
		draw_string_outline(font, pos, lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.6 * color.a))
		draw_string(font, pos, lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func orb_font_size(text: String, max_w: float, start := 23) -> int:
	var font := XUiSkin.font("title")
	var fs := start
	while fs > XUiSkin.FS_MIN and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 1
	return fs
