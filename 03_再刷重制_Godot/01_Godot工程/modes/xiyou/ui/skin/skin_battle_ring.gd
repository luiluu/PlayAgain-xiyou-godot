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
static var BOWSTRING_B := true
static var CROSS_INTRO_B := true
static var RADIUS := 116.0
static var RADIUS_B := 104.0
static var ORB_R := 32.0
static var ORB_R_B := 14.0
const OLD_RADIUS := 124.0
const OLD_ORB_R := 41.0
## 项多时半径最多加到这么大，再多就把球缩小（最小 28）
static var MAX_RADIUS := 230.0
## 第 1 项的角度（度，0＝右、90＝下）、相邻两项的角度差（往小走＝逆时针＝画面上往下）
static var START_DEG := 258.0
static var STEP_DEG := 36.0
static var START_DEG_B := 242.0
static var STEP_DEG_B := 24.8
## 超过 6 项时可用的弧（从起点往下逆时针走多少度）
static var MAX_SPAN_DEG := 252.0
static var MAX_SPAN_DEG_B := 180.0
## 环心相对角色脚底的偏移（两排站位定了挪这里）
static var OFFSET := Vector2(0, -32)
## 离画面边至少留多少
static var MARGIN := 8.0
## B 方向金弦相对文字中心的左偏移、交叉展开时长
const STAR_OFFSET_B := 44.0
const STAR_R_B := 5.4
const SEAL_R_B := 9.2
const CROSS_IN_TIME := 0.34
static var SEL_MORPH_B := true
const STAR_PINCH_B := 0.45
const SQUARE_PINCH_B := 0.70710678
const SEL_MORPH_PERIOD := 1.6

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
## T096 动效：铺开计时（秒，≥ intro_total() 算铺完）、失活淡出（0～1）、新选中那颗的闪光（秒）、选中标记星/方循环计时
var intro_elapsed := 999.0
var vis := 1.0
var _flash_i := -1
var _flash_t := 999.0
var _last_index := -1
var _sel_morph_t := 0.0
const FLASH_TIME := 0.25


static func base_radius() -> float:
	if BOWSTRING_B:
		return RADIUS_B
	return RADIUS if SMALL_ORBS else OLD_RADIUS


static func base_orb_r() -> float:
	if BOWSTRING_B:
		return ORB_R_B
	return ORB_R if SMALL_ORBS else OLD_ORB_R


static func peak() -> float:
	return SEL_PEAK if (SMALL_ORBS or BOWSTRING_B) else OLD_SEL_PEAK


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


## 各项角度与半径；节点大小＝整环（弦星＋浮字／球＋上方名字）的外框
func _layout_ring() -> void:
	var n := maxi(entries.size(), 1)
	var start_d := START_DEG_B if BOWSTRING_B else START_DEG
	var step := STEP_DEG_B if BOWSTRING_B else STEP_DEG
	var max_span := MAX_SPAN_DEG_B if BOWSTRING_B else MAX_SPAN_DEG
	if (n - 1) * step > max_span:
		step = max_span / float(n - 1)
	# 项不重叠：相邻中心距 ≥ 2·项半径＋4；半径到 MAX_RADIUS 还不够就缩（不小于底限）
	var half := sin(deg_to_rad(step) / 2.0)
	var grow := (1.0 + peak()) / 2.0 if (SMALL_ORBS or BOWSTRING_B) else 1.0
	radius = clampf((base_orb_r() * grow + 2.0) / half, base_radius(), maxf(base_radius(), MAX_RADIUS))
	orb_r = minf(base_orb_r(), (radius * half - 2.0) / grow)
	_angles = []
	for i in n:
		_angles.append(start_d - i * step)
	var box := Rect2(Vector2(-radius - 4, -radius - 4), Vector2(radius + 4, radius + 4) * 2)
	for i in n:
		var p := orb_offset(i)
		if BOWSTRING_B:
			box = box.merge(Rect2(p - Vector2(STAR_OFFSET_B + 22.0, 24.0), Vector2(STAR_OFFSET_B + 78.0, 48.0)))
		else:
			box = box.merge(Rect2(p - Vector2(orb_r + 10, orb_r + 10), Vector2(orb_r + 10, orb_r + 10) * 2))
	if title != "":
		var top := box.position.y
		box = box.merge(Rect2(Vector2(-110, top - 30), Vector2(220, 30)))
	center = -box.position
	size = box.size


## 第 i 项中心相对环心
func orb_offset(i: int) -> Vector2:
	if i < 0 or i >= _angles.size():
		return Vector2.ZERO
	return Vector2.from_angle(deg_to_rad(float(_angles[i]))) * radius


func orb_pos(i: int) -> Vector2:
	return center + orb_offset(i)


func _bow_center() -> Vector2:
	return center - Vector2(STAR_OFFSET_B, 0.0)


func star_pos(i: int) -> Vector2:
	return _bow_center() + orb_offset(i)


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


## 实际画出来的范围（本节点坐标）：各项加上方「某某的行动」一行（新界面 4A 让位用）
func drawn_rect() -> Rect2:
	if entries.is_empty():
		return Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	var r: Rect2
	if BOWSTRING_B:
		r = Rect2(orb_pos(0) - Vector2(STAR_OFFSET_B + 14.0, 16.0), Vector2(STAR_OFFSET_B + 64.0, 32.0))
		for i in range(1, entries.size()):
			r = r.merge(Rect2(orb_pos(i) - Vector2(STAR_OFFSET_B + 14.0, 16.0), Vector2(STAR_OFFSET_B + 64.0, 32.0)))
	else:
		r = Rect2(orb_pos(0) - Vector2(orb_r, orb_r), Vector2(orb_r, orb_r) * 2.0)
		for i in range(1, entries.size()):
			r = r.merge(Rect2(orb_pos(i) - Vector2(orb_r, orb_r), Vector2(orb_r, orb_r) * 2.0))
	r.position.y -= 30.0   # 名字一行（字号 17，离顶 10）
	r.size.y += 30.0
	return r


## 环心在父节点里的位置（测试、截图看）
func ring_center() -> Vector2:
	return position + center


func refresh() -> void:
	queue_redraw()


func _paint(_c: XMVCanvas) -> void:
	pass


func hit_rect_b(i: int) -> Rect2:
	var lp := orb_pos(i)
	var top := lp.y - 24.0
	var bot := lp.y + 24.0
	if i > 0:
		top = maxf(top, (orb_pos(i - 1).y + lp.y) * 0.5)
	if i < entries.size() - 1:
		bot = minf(bot, (lp.y + orb_pos(i + 1).y) * 0.5)
	return Rect2(Vector2(lp.x - (STAR_OFFSET_B + 22.0), top), Vector2(STAR_OFFSET_B + 78.0, maxf(bot - top, 32.0)))


func _hit(p: Vector2) -> int:
	var local := p - position
	for i in entries.size():
		if BOWSTRING_B:
			if hit_rect_b(i).has_point(local):
				return i
		elif local.distance_to(orb_pos(i)) <= orb_r + 2.0:
			return i
	return -1


func sel_morph_active() -> bool:
	return BOWSTRING_B and SEL_MORPH_B and XSkinBattleMotion.on() and XUiSkin.breathing() and active and intro_elapsed >= intro_total()


static func sel_morph_values(t: float) -> Vector2:
	var u := fposmod(t, SEL_MORPH_PERIOD) / SEL_MORPH_PERIOD
	if u < 0.18:
		return Vector2(0.0, 0.0)
	if u < 0.50:
		var s := (u - 0.18) / 0.32
		var e := s * s * (3.0 - 2.0 * s)
		return Vector2(e, e * PI * 0.5)
	if u < 0.68:
		return Vector2(1.0, PI * 0.5)
	var s := (u - 0.68) / 0.32
	var e := s * s * (3.0 - 2.0 * s)
	return Vector2(1.0 - e, PI * 0.5 + e * PI * 0.5)


func sel_morph_factor(t := -1.0) -> float:
	if not sel_morph_active():
		return 0.0
	var tt := _sel_morph_t if t < 0.0 else t
	return sel_morph_values(tt).x


func _process(delta: float) -> void:
	if active != _drawn_active:
		queue_redraw()
	if XUiSkin.breathing() and active:
		_spin += delta
		queue_redraw()
	# T096：铺开、失活淡出／回来淡入、新选中那颗的闪光
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
		_sel_morph_t = 0.0
		if moving and active and index >= 0:
			_flash_i = index
			_flash_t = 0.0
	if _flash_t < FLASH_TIME:
		_flash_t += delta
		queue_redraw()
	if sel_morph_active():
		_sel_morph_t = fposmod(_sel_morph_t + delta, SEL_MORPH_PERIOD)
		queue_redraw()
	elif _sel_morph_t != 0.0 and not (moving and XUiSkin.breathing()):
		_sel_morph_t = 0.0
		queue_redraw()


func _item_intro_dur() -> float:
	return CROSS_IN_TIME if (BOWSTRING_B and CROSS_INTRO_B) else XSkinBattleMotion.RING_ORB_IN


## 铺开总时长：最后一项也长完
func intro_total() -> float:
	return _item_intro_dur() + XSkinBattleMotion.RING_STAGGER * maxf(entries.size() - 1, 0)


## 第 i 项的铺开进度 0～1
func intro_of(i: int) -> float:
	if intro_elapsed >= intro_total():
		return 1.0
	return clampf((intro_elapsed - XSkinBattleMotion.RING_STAGGER * i) / _item_intro_dur(), 0.0, 1.0)


## 失活（开着技能／物品列表、选目标、看怪物信息）时整环不画
func _draw() -> void:
	_drawn_active = active
	self_modulate.a = vis   # T096：失活时淡出（动效关时 vis 当场归 0，同原来直接不画）
	if vis <= 0.0:
		return
	if BOWSTRING_B:
		_draw_bowstring_arc()
	else:
		# 旧版 T096 外圈虚线（14 秒一圈）
		var dashes := 48
		var off := _spin * TAU / 14.0
		for k in dashes:
			var a0 := off + k * TAU / dashes
			draw_arc(center, radius, a0, a0 + TAU / dashes * 0.55, 4, Color(XUiSkin.GOLD_LIGHT, 0.45), 1.5, true)
	# 名字（某某的行动）
	var title_font := XUiSkin.font("title")
	if title != "":
		var fs := 17
		var tw := title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var top := INF
		var item_top_pad := 16.0 if BOWSTRING_B else orb_r
		for i in entries.size():
			top = minf(top, orb_pos(i).y - item_top_pad)
		if top == INF:
			top = center.y - radius
		var tx := (orb_pos(0).x - tw / 2.0 + 4.0) if BOWSTRING_B else (center.x - tw / 2.0)
		var pos := Vector2(tx, top - 10.0)
		var ta := XSkinTurnCue.title_alpha() if XSkinBattleMotion.on() else 1.0   # T096：换人提示胶囊淡掉后再出来
		if ta < 1.0:
			queue_redraw()
		if XSkin4A.text_on() and ta >= 1.0:  # 新界面 4A（A5）：回合提示垫深色胶囊底
			XSkin4A.draw_text_backing(self, pos.x, pos.y, tw, fs)
		draw_string_outline(title_font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7 * ta))
		draw_string(title_font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(XUiSkin.GOLD, ta))
	# 项
	if sel_scale != null:
		sel_scale.sel(index)
	if BOWSTRING_B:
		var body_font := XUiSkin.font("body")
		for i in entries.size():
			_draw_bow_item(i, body_font)
	else:
		for i in entries.size():
			_draw_orb(i, title_font)


func _draw_bowstring_arc() -> void:
	if _angles.is_empty():
		return
	var bc := _bow_center()
	var a_top := float(_angles[0]) + 10.0
	var a_bot := float(_angles[_angles.size() - 1]) - 10.0
	var reveal := 1.0 if intro_elapsed >= intro_total() else clampf(intro_elapsed / 0.14, 0.0, 1.0)
	var segs := 36
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for k in range(segs + 1):
		var f := float(k) / float(segs)
		var ang := deg_to_rad(lerpf(a_top, a_bot, f))
		pts.append(bc + Vector2.from_angle(ang) * radius)
		var end_fade := sin(f * PI)
		var col := Color(0.92, 0.78, 0.48, (0.18 + 0.46 * end_fade) * end_fade * reveal)
		cols.append(col)
	draw_polyline_colors(pts, cols, 1.5, true)
	# 内侧细游丝回声弧
	var ipts := PackedVector2Array()
	var icols := PackedColorArray()
	for k in range(segs + 1):
		var f := float(k) / float(segs)
		var ang := deg_to_rad(lerpf(a_top - 5.0, a_bot + 5.0, f))
		ipts.append(bc + Vector2.from_angle(ang) * (radius - 4.5))
		var end_fade := sin(f * PI)
		icols.append(Color(0.95, 0.82, 0.55, 0.24 * end_fade * reveal))
	draw_polyline_colors(ipts, icols, 0.85, true)
	# 选中项朱红焦点光弧
	if index >= 0 and index < _angles.size():
		var sa := float(_angles[index])
		var breath := XUiSkin.breath_alpha() if XUiSkin.breathing() else 1.0
		var it := intro_of(index)
		var fa := minf(1.0, it * 2.0) * breath
		if fa > 0.01:
			var f0 := deg_to_rad(sa - 13.0)
			var f1 := deg_to_rad(sa + 13.0)
			draw_arc(bc, radius, f0, f1, 18, Color(1.0, 0.32, 0.22, 0.24 * fa), 6.0, true)
			draw_arc(bc, radius, f0, f1, 18, Color(1.0, 0.36, 0.25, 0.96 * fa), 2.5, true)


## 四角菱形星参数（pinch=0.13 成纤细十字形；pinch=0.50 成饱满菱形星；rot 旋转角）
static func _diamond_star_pts(c: Vector2, r: float, pinch: float, rot: float) -> PackedVector2Array:
	var w := r * pinch * 0.70710678
	var raw := [
		Vector2(0, -r), Vector2(w, -w),
		Vector2(r, 0), Vector2(w, w),
		Vector2(0, r), Vector2(-w, w),
		Vector2(-r, 0), Vector2(-w, -w),
	]
	var pts := PackedVector2Array()
	for v in raw:
		pts.append(c + v.rotated(rot))
	return pts


func _draw_diamond_star(c: Vector2, r: float, pinch: float, rot: float, fill: Color, rim: Color, inner_c: Color, rim_w := 1.1) -> void:
	var outer := _diamond_star_pts(c, r, pinch, rot)
	draw_colored_polygon(outer, fill)
	var closed := PackedVector2Array(outer)
	closed.append(outer[0])
	draw_polyline(closed, rim, rim_w, true)
	if inner_c.a > 0.01:
		var m := clampf((pinch - STAR_PINCH_B) / maxf(SQUARE_PINCH_B - STAR_PINCH_B, 0.001), 0.0, 1.0)
		var inner_pinch := lerpf(minf(pinch + 0.12, SQUARE_PINCH_B), SQUARE_PINCH_B, m)
		draw_colored_polygon(_diamond_star_pts(c, r * 0.44, inner_pinch, rot), inner_c)


func _draw_bow_item(i: int, font: Font) -> void:
	var e: Dictionary = entries[i]
	var on := i == index and active
	var sel := i == index
	var en := bool(e.get("enabled", true))
	var t := intro_of(i)
	if t <= 0.0:
		return
	var en_alpha := 1.0 if en else 0.5
	var k := orb_scale(i)
	var sf := clampf((k - 1.0) / maxf(peak() - 1.0, 0.001), 0.0, 1.0)
	var sc := star_pos(i)
	var lp := orb_pos(i) + Vector2(-8.0 * sf, 0.0)

	# 菱形星放大＋打开时「旋转收成十字形再展开」动效（受界面动效设置管）；铺完后选中项在菱形星↔菱形方块循环
	var rot := 0.0
	var pinch := STAR_PINCH_B if sel else 0.52
	var star_mult := 1.0
	var label_t := t
	if CROSS_INTRO_B and t < 1.0:
		if t < 0.45:
			var p := t / 0.45
			var ep := XSkinBattleMotion.ease_out(p)
			rot = lerpf(-PI * 0.25, 0.0, ep)
			pinch = lerpf(0.48, 0.13, ep)         # 旋转收束成十字形
			star_mult = lerpf(1.32, 1.12, ep)
		else:
			var p := (t - 0.45) / 0.55
			var bp := XSkinBattleMotion.ease_out_back(p)
			rot = lerpf(0.0, PI * 0.5, clampf(p, 0.0, 1.0))
			pinch = lerpf(0.13, 0.52, clampf(bp, 0.13, 0.62))   # 旋转展开成菱形星
			star_mult = lerpf(1.05, 1.0, clampf(bp, 0.0, 1.15))
		label_t = clampf((t - 0.35) / 0.65, 0.0, 1.0)
		lp.x -= (1.0 - XSkinBattleMotion.ease_out(label_t)) * 10.0
	elif sel and sel_morph_active():
		var mv := sel_morph_values(_sel_morph_t)
		pinch = lerpf(STAR_PINCH_B, SQUARE_PINCH_B, mv.x)
		rot = mv.y

	var text_alpha := en_alpha * XSkinBattleMotion.ease_out(label_t)
	var g := XUiSkin.glow_texture()
	var text := str(e.get("text", ""))

	# 1) 底纹：无框柔墨韵 / 选中绯红梭影＋上下渐隐细线
	if text_alpha > 0.01:
		if sel:
			var ba := (0.95 if on else 0.55) * text_alpha
			var hw := 58.0 * k
			var hh := 19.5 * k
			draw_texture_rect(g, Rect2(lp - Vector2(hw, hh), Vector2(hw * 2.0, hh * 2.0)), false,
				Color(0.78, 0.14, 0.10, 0.62 * ba))
			# 尖梭绯红烟底（左右两尖透明归零，绝不生硬画方框）
			var sp_pts := PackedVector2Array([
				lp + Vector2(-hw, 0.0),
				lp + Vector2(-hw * 0.42, -hh * 0.72),
				lp + Vector2(0.0, -hh * 0.85),
				lp + Vector2(hw * 0.42, -hh * 0.62),
				lp + Vector2(hw, 0.0),
				lp + Vector2(hw * 0.42, hh * 0.62),
				lp + Vector2(0.0, hh * 0.85),
				lp + Vector2(-hw * 0.42, hh * 0.72),
			])
			var sp_cols := PackedColorArray([
				Color(0.95, 0.28, 0.20, 0.05 * ba),
				Color(0.68, 0.12, 0.09, 0.48 * ba),
				Color(0.68, 0.12, 0.09, 0.54 * ba),
				Color(0.45, 0.08, 0.06, 0.28 * ba),
				Color(0.30, 0.06, 0.05, 0.0),
				Color(0.45, 0.08, 0.06, 0.28 * ba),
				Color(0.68, 0.12, 0.09, 0.54 * ba),
				Color(0.68, 0.12, 0.09, 0.48 * ba),
			])
			draw_polygon(sp_pts, sp_cols)
			# 上下渐隐赤金细线
			for sgn: float in [-1.0, 1.0]:
				var ly: float = lp.y + sgn * (15.5 * k)
				var lpts := PackedVector2Array([Vector2(lp.x - 38.0 * k, ly), Vector2(lp.x, ly), Vector2(lp.x + 38.0 * k, ly)])
				var lcols := PackedColorArray([Color(1.0, 0.50, 0.36, 0.0), Color(1.0, 0.64, 0.46, 0.80 * ba), Color(1.0, 0.50, 0.36, 0.0)])
				draw_polyline_colors(lpts, lcols, 1.1, true)
		else:
			# 字肚正下方柔化暖墨韵（无边框、无圆饼）
			draw_texture_rect(g, Rect2(lp - Vector2(46.0, 19.0), Vector2(92.0, 38.0)), false,
				Color(0.035, 0.025, 0.028, 0.58 * text_alpha))

	# 2) 金弦星点 / 选中赤金双层菱印
	var sa := en_alpha * minf(1.0, t * 2.5)
	if sel:
		var sr := SEAL_R_B * (0.9 + 0.1 * k) * star_mult
		draw_texture_rect(g, Rect2(sc - Vector2(sr * 1.9, sr * 1.9), Vector2(sr * 3.8, sr * 3.8)), false,
			Color(1.0, 0.34, 0.22, 0.65 * sa))
		_draw_diamond_star(sc, sr, pinch, rot,
			Color(0.92, 0.20, 0.14, 0.96 * sa),
			Color(1.0, 0.86, 0.64, 0.96 * sa),
			Color(1.0, 0.96, 0.88, sa), 1.4)
		if i == _flash_i and _flash_t < FLASH_TIME:
			var f := _flash_t / FLASH_TIME
			var fpts := _diamond_star_pts(sc, sr + 2.0 + 7.0 * f, pinch, rot)
			var fclosed := PackedVector2Array(fpts)
			fclosed.append(fpts[0])
			draw_polyline(fclosed, Color(1.0, 0.95, 0.84, 0.9 * (1.0 - f)), 2.2 * (1.0 - f) + 0.5, true)
	else:
		var sr := STAR_R_B * star_mult
		var tick_len := 10.0 * XSkinBattleMotion.ease_out(label_t)
		if tick_len > 1.0:
			draw_polyline_colors(PackedVector2Array([sc + Vector2(sr * 0.7, 0), sc + Vector2(sr * 0.7 + tick_len, 0)]),
				PackedColorArray([Color(0.89, 0.74, 0.45, 0.68 * sa), Color(0.89, 0.74, 0.45, 0.0)]), 1.0, true)
		_draw_diamond_star(sc, sr, pinch, rot,
			Color(0.94, 0.81, 0.54, 0.92 * sa),
			Color(1.0, 0.92, 0.74, 0.55 * sa),
			Color(1.0, 0.96, 0.86, 0.65 * sa), 0.9)

	# 3) 浮字（选中项放大 20% = k=1.2，字号 22→26）
	if text_alpha > 0.01:
		var fs := orb_font_size(text, 92.0 * k, roundi(22.0 * k), font)
		var col := Color(1.0, 0.98, 0.93, text_alpha) if sel else Color(0.95, 0.90, 0.80, text_alpha)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var baseline := lp + Vector2(-tw / 2.0, fs * 0.35)
		if sel:
			draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color(0.95, 0.25, 0.18, 0.28 * text_alpha))
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.03, 0.02, 0.02, 0.95 * text_alpha))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


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
	if ORB_STYLE == 0:
		draw_circle(p, r, Color(XUiSkin.ORB_LOW, 0.92))
		draw_circle(p + Vector2(-r * 0.15, -r * 0.2), r * 0.72, Color(XUiSkin.ORB_HI, 0.85 * alpha))
	else:
		_draw_orb_body(p, r, sel, on, alpha)
	if sel:
		draw_circle(p, r, XUiSkin.SEL_LINE, false, 2.5, true)
		if i == _flash_i and _flash_t < FLASH_TIME:   # T096：新选中闪一圈白（样稿 bo1），0.25 秒散开淡掉
			var f := _flash_t / FLASH_TIME
			draw_circle(p, r + 2.0 + 6.0 * f, Color(1, 1, 1, 0.9 * (1.0 - f)), false, 3.0 * (1.0 - f) + 0.5, true)
	elif ORB_STYLE == 0:
		draw_circle(p, r, Color(XUiSkin.LINE, 0.6 * alpha), false, 1.5, true)
	else:
		draw_circle(p, r, Color(XUiSkin.GOLD, (0.55 if ORB_STYLE != 2 else 0.75) * alpha), false, 1.5, true)
	var text := str(e.get("text", ""))
	var color := Color.WHITE if sel else XUiSkin.GOLD
	color.a = alpha
	_orb_text(font, text, p, r, color)


## T096 追加（Kyo 11-16「指令球全黑底不好看」）：球的底色三版，0＝原来的全黑（可回退）。
## 1 深红：绯红到近黑的径向渐变、旧金细描边，选中更亮更红；
## 2 烟底：半透明深灰（透出背景）＋旧金描边和内细圈，选中换绯红半透明；
## 3 暗金：暖炭灰渐变＋旧金描边，选中换深红渐变。
static var ORB_STYLE := 3   # 选 3：没选中的不带红，「红＝选中」不乱（README 第三节）；1 整环发红、选中不突出，2 在亮背景上发灰
const ORB_STYLES := {
	# [外圈色, 中心亮面色, 选中外圈, 选中亮面]
	1: [Color("1e0708"), Color("5c1a1a"), Color("4a0e0b"), Color("b8352a")],
	2: [Color(0.04, 0.04, 0.045, 0.55), Color(0.16, 0.16, 0.17, 0.55), Color(0.42, 0.08, 0.06, 0.62), Color(0.81, 0.17, 0.12, 0.62)],
	3: [Color("14120f"), Color("3d362a"), Color("3c0c0a"), Color("a12a20")],
}


## 球身：多层同心圆叠出径向渐变（亮面偏左上），再加一道内细圈
func _draw_orb_body(p: Vector2, r: float, sel: bool, on: bool, alpha: float) -> void:
	var cs: Array = ORB_STYLES.get(ORB_STYLE, ORB_STYLES[1])
	var outer: Color = cs[2] if sel else cs[0]
	var inner: Color = cs[3] if sel else cs[1]
	if sel and not on:   # 失活时（开着列表）选中那颗暗一点
		inner = inner.lerp(outer, 0.4)
	const STEPS := 10
	var hi := Vector2(-r * 0.22, -r * 0.28)
	for k in STEPS:
		var f := float(k) / float(STEPS - 1)     # 0 外 → 1 内
		var c := outer.lerp(inner, f)
		c.a *= alpha if ORB_STYLE != 2 else alpha * (1.0 if k == 0 else 0.35)
		draw_circle(p + hi * f, r * lerpf(1.0, 0.3, f), c)
	if not sel:
		draw_circle(p, r - 4.0, Color(XUiSkin.GOLD, 0.16 * alpha), false, 1.0, true)


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


func orb_font_size(text: String, max_w: float, start := 23, font: Font = null) -> int:
	if font == null:
		font = XUiSkin.font("title")
	var fs := start
	while fs > XUiSkin.FS_MIN and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 1
	return fs
