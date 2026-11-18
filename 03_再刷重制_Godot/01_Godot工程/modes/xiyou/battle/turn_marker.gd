class_name XTurnMarker
extends Node2D
## 【cc·天启篇·未经审查】T196 行动标记：当前行动的我方角色头顶一颗立体的倒置宝石（Kyo 11-18：「三角标改到目前行动角色头上，做立体一点也要能动」）。
## 取代新界面队伍栏那一行左外的红色小箭头（XSkinSideStatus.draw_active 在标记开着时不画箭头）。只在新界面（XUiSkin.on()）里有。
## - 形状：四面的宝石——上面一圈冠部（斜面＋顶面台面）、下面倒金字塔亭部，尖朝下指着角色；每帧按 3D 投影画（略俯视），
##   各面按朝向打光（左上前方来光）：亮面朱红→淡珊瑚、暗面深红，边线旧金，台面左上一点高光星；背后一圈暖红光晕。
##   配色同新界面红乙（SEL_FILL／SEL_LINE／SEL2_FILL）＋旧金（GOLD／GOLD_LIGHT）。
## - 会动：界面动效「全部」——绕竖轴慢转（一圈 3.6 秒）＋上下浮动 3px（1.6 秒一回）＋光晕呼吸；「简化」只浮动；「关」静止。
## - 跟随：每帧贴着角色精灵当前位置（走上前出招也跟着），尖离头顶 GAP；换人时从旧角色头顶沿一道小弧滑过去（0.3 秒，团队看板缓动）；
##   轮到敌人行动（_active 为空）时停 HIDE_DELAY 再淡出，免得两次行动之间闪一下。
## - 不挡：放在 fx 层、z 比伤害数字（POPUP_Z）低一级，伤害数字盖在它上面；换人回合提示（XSkinTurnCue 的「某某 的回合」胶囊）演出时先隐去，
##   胶囊淡掉再出来；选我方目标、光标停在它自己身上时（目标提示胶囊在头顶）也隐去。
## - 只是画面：不改战斗流程、顺序、随机数。
## 回退：ENABLED = false 不建这颗标记，队伍栏那一行的左外小箭头回来。

static var ENABLED := true

const GAP := 10.0            # 宝石尖离头顶
const R := 15.0              # 腰圈半径
const CROWN_H := 7.5         # 冠部高
const TABLE_R := 8.0         # 台面半径
const DEPTH := 24.0          # 亭部深（腰圈到尖）
const TILT := 0.34           # 俯视的压扁量（圆在屏幕上的纵横比）
const SIDES := 4
const SPIN := 3.6            # 一圈秒数
const BOB := 3.0             # 浮动幅度（px）
const BOB_T := 1.6           # 浮动一回秒数
const GLIDE := 0.3           # 换人滑过去
const HOP := 18.0            # 滑过去时弧顶抬高
const FADE := 0.18
const HIDE_DELAY := 0.35
const TOP_MIN := 30.0        # 头顶太高（大型变身）时尖最高到这（原版坐标）
const LIGHT := -2.3          # 光从左前方来（腰圈上的角度，0＝正右、PI/2＝正对镜头）

var scene: XBattleScene
## 现在要标的人（null＝没人在行动）；正画在谁头上
var target: XBattler = null
var shown_for: XBattler = null
var alpha := 0.0
var t := 0.0
var _hide_in := -1.0
var _glide := 1.0
var _glide_from := Vector2.ZERO
var _anchor := Vector2.ZERO


static func on() -> bool:
	return ENABLED and XUiSkin.on()


## XBattleScene 开战建：放在 fx 层（同伤害数字一层，z 低一级）；关着返回 null
static func make(sc: XBattleScene, z: int) -> XTurnMarker:
	if not on() or sc == null or sc.fx == null:
		return null
	var m := XTurnMarker.new()
	m.scene = sc
	m.z_index = z
	m.name = "TurnMarker"
	sc.fx.add_child(m)
	return m


## XBattleScene._set_active 调：a 是轮到的我方角色，null＝行动结束／敌人行动
func set_target(a: XBattler) -> void:
	if a == null:
		target = null
		if _hide_in < 0.0:
			_hide_in = HIDE_DELAY
		return
	_hide_in = -1.0
	target = a
	if a == shown_for:
		return
	var to := anchor_for(a)
	if shown_for != null and alpha > 0.05 and _motion() != XUiSkin.Motion.OFF:
		_glide_from = _anchor
		_glide = 0.0
	else:
		_glide = 1.0
		_anchor = to
	shown_for = a


## 换人（XBattleScene._swap_sprite_from）：标着被换下的人时改标换上的人
func replaced(old: XBattler, h: XBattler) -> void:
	if shown_for == old:
		shown_for = h
	if target == old:
		target = h


static func _motion() -> int:
	return XUiSkin.motion()


## 角色头顶上宝石尖的位置（fx 层坐标＝原版坐标；跟精灵当前位置，含出招时走位、浮空）
func anchor_for(b: XBattler) -> Vector2:
	if scene == null or b == null:
		return position
	var s: XBattlerSprite = scene.sprites.get(b)
	if s == null or not is_instance_valid(s):
		return position
	var p := s.position + Vector2(0, -s.height() - GAP)
	p.y = maxf(p.y, TOP_MIN)
	return p


## 这会儿要不要让开（换人回合提示演出中、目标提示挂在它头上）
func blocked() -> bool:
	if shown_for == null:
		return true
	if XSkinBattleMotion.on() and XSkinTurnCue.title_alpha() < 1.0:
		return true
	if scene != null and scene._target_mode == "ally" and is_same(scene._hover, shown_for):
		return true
	return false


func _process(delta: float) -> void:
	t += delta
	if _hide_in >= 0.0:
		_hide_in -= delta
		if _hide_in < 0.0:
			_hide_in = -1.0
			if target == null:
				shown_for = null
	if shown_for != null and not is_instance_valid(shown_for):
		shown_for = null
	var want := 0.0 if (shown_for == null or (target == null and _hide_in < 0.0) or blocked()) else 1.0
	if _motion() == XUiSkin.Motion.OFF:
		alpha = want
	else:
		alpha = move_toward(alpha, want, delta / FADE)
	if shown_for != null:
		var to := anchor_for(shown_for)
		if _glide < 1.0:
			_glide = minf(1.0, _glide + delta / GLIDE)
			var e := XPartyFold.ease_board(_glide)
			_anchor = _glide_from.lerp(to, e) + Vector2(0, -HOP * sin(PI * _glide))
		else:
			_anchor = to
	position = _anchor + Vector2(0, -bob())
	visible = alpha > 0.0
	if visible:
		queue_redraw()


## 浮动（简化档也有）、转角（只在全部档）
func bob() -> float:
	if _motion() == XUiSkin.Motion.OFF:
		return 0.0
	return BOB * (0.5 + 0.5 * sin(t * TAU / BOB_T))


func spin() -> float:
	if _motion() != XUiSkin.Motion.FULL:
		return PI / 4.0   # 静止时正对一条棱（左右两面都看得见，最显立体）
	return PI / 4.0 + t * TAU / SPIN


func breath() -> float:
	if _motion() != XUiSkin.Motion.FULL:
		return 0.5
	return 0.5 + 0.5 * sin(t * TAU / 2.2)


## 3D → 屏幕：腰圈在原点上方 DEPTH（尖在 0,0），俯视压扁
static func _ring(ang: float, r: float, y: float) -> Vector2:
	return Vector2(cos(ang) * r, y + sin(ang) * r * TILT)


## 一个面的亮度（0～1）：面中线朝向与光的夹角；朝镜头（sin＞0）略加亮
static func _lit(mid: float) -> float:
	return clampf(0.5 + 0.42 * cos(mid - LIGHT) + 0.18 * sin(mid), 0.0, 1.0)


func _draw() -> void:
	if alpha <= 0.0:
		return
	var a := alpha
	var rot := spin()
	var waist := -DEPTH
	var table := -DEPTH - CROWN_H
	var apex := Vector2.ZERO
	var dark := XUiSkin.SEL2_FILL_R.darkened(0.25)
	var mid_c := XUiSkin.SEL_FILL
	var lite := XUiSkin.SEL_LINE.lerp(Color("ffc2a8"), 0.35)
	var gold := XUiSkin.GOLD
	# 光晕（呼吸）
	var g := XUiSkin.glow_texture()
	if g != null:
		var gr := 32.0 + 5.0 * breath()
		draw_texture_rect(g, Rect2(Vector2(-gr, waist - gr * 0.85), Vector2(gr * 2.0, gr * 2.0)), false,
			Color(XUiSkin.SEL_FILL, (0.30 + 0.18 * breath()) * a))
	var w := []   # 腰圈各点
	var tb := []  # 台面各点
	var angs := []
	for i in SIDES:
		var ang := rot + TAU * i / SIDES
		angs.append(ang)
		w.append(_ring(ang, R, waist))
		tb.append(_ring(ang, TABLE_R, table))
	# 投影：整颗的外轮廓往右下偏一点、压暗，当厚度和落影
	var hull := PackedVector2Array([apex])
	for p in w:
		hull.append(p)
	for p in tb:
		hull.append(p)
	var outline := Geometry2D.convex_hull(hull)
	if outline.size() >= 3:
		var sh := PackedVector2Array()
		for p in outline:
			sh.append(p + Vector2(1.5, 2.5))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.45 * a))
	# 面：[深度(越大越近), 点, 颜色]
	var faces := []
	for i in SIDES:
		var j := (i + 1) % SIDES
		var m: float = (angs[i] + angs[j]) / 2.0 if j != 0 else angs[i] + PI / SIDES
		var near := sin(m)
		# 亭部（倒金字塔）：只画朝镜头的
		if near > -0.05:
			var b := _lit(m) * 0.82
			faces.append([near - 1.0, PackedVector2Array([apex, w[i], w[j]]), dark.lerp(mid_c, b * 1.15).lerp(lite, maxf(0.0, b - 0.72) * 1.6)])
		# 冠部斜面：俯视时背面也露一点
		if near > -0.45:
			var b2 := _lit(m)
			faces.append([near, PackedVector2Array([w[i], w[j], tb[j], tb[i]]), mid_c.lerp(lite, b2 * 0.9).lerp(dark, maxf(0.0, 0.35 - b2))])
	faces.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	# 背面冠部先画，再画台面，再画前面
	var table_poly := PackedVector2Array(tb)
	var drawn_table := false
	for f in faces:
		if not drawn_table and float(f[0]) >= 0.0:
			_draw_table(table_poly, lite, gold, a)
			drawn_table = true
		draw_colored_polygon(f[1], Color(f[2], a))
		var edge := PackedVector2Array(f[1])
		edge.append(edge[0])
		draw_polyline(edge, Color(dark.darkened(0.3), 0.55 * a), 1.0, true)
	if not drawn_table:
		_draw_table(table_poly, lite, gold, a)
	# 腰圈旧金边（前半圈亮、后半圈暗）
	for i in SIDES:
		var j := (i + 1) % SIDES
		var m: float = (angs[i] + angs[j]) / 2.0 if j != 0 else angs[i] + PI / SIDES
		var ga := 0.95 if sin(m) > 0.0 else 0.45
		draw_line(w[i], w[j], Color(gold, ga * a), 1.4, true)
	# 亭部朝镜头的棱：旧金细线引到尖
	for i in SIDES:
		if sin(angs[i]) > 0.0:
			draw_line(w[i], apex, Color(gold, 0.55 * a * sin(angs[i])), 1.0, true)
	# 高光：台面左上一颗淡金四芒星（呼吸）＋尖上一点
	var hp := table_poly[0]
	for p in table_poly:
		if p.x + p.y < hp.x + hp.y:
			hp = p
	var sp := hp.lerp(Vector2(0, table), 0.45)
	var s := 3.0 + 1.5 * breath()
	var star := Color(XUiSkin.GOLD_LIGHT.lerp(Color.WHITE, 0.5), (0.65 + 0.35 * breath()) * a)
	draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -s), sp + Vector2(s * 0.28, 0), sp + Vector2(0, s), sp + Vector2(-s * 0.28, 0)]), star)
	draw_colored_polygon(PackedVector2Array([sp + Vector2(-s, 0), sp + Vector2(0, -s * 0.28), sp + Vector2(s, 0), sp + Vector2(0, s * 0.28)]), star)
	draw_circle(apex + Vector2(0, -2.0), 1.2, Color(XUiSkin.GOLD_LIGHT, 0.8 * a))


func _draw_table(poly: PackedVector2Array, lite: Color, gold: Color, a: float) -> void:
	draw_colored_polygon(poly, Color(lite.lerp(XUiSkin.GOLD_LIGHT, 0.25), a))
	var edge := PackedVector2Array(poly)
	edge.append(edge[0])
	draw_polyline(edge, Color(gold, 0.9 * a), 1.2, true)
