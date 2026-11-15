class_name XSkinBossArc
extends XBossHpBar
## 【cc·天启篇·未经审查】新界面 2B：首领血弧（盘点清册 #67，界面风格提案 v0.7 样稿 battle 的 .boss）。
## 只换画法：哪只敌人有血条、跟着谁、红条拖尾和数字追赶的速度、淡入淡出、受伤震动，全是 XBossHpBar 原来的逻辑（step／applied／ended）。
## 画面顶上一道大圆弧（圆心在画面中线上方，半径 320，露出下面 126°）：底槽黑 65%、玫粉血弧带外晕；扣血后原来那截先变橙（下降色），
## 追上后消失（原版的红条拖尾）；弧里面是首领名字（思源宋体 27，难度色同原版）和「现血量 / 上限」（窄体 34 玫粉浅色＋18 旧金）；
## 有 MOG 头像的首领在弧顶画一枚圆头像。血从右往左掉（同普通量条）。
## 位置参数（1280×720 画面坐标）：CENTER、RADIUS、SPAN_DEG、THICK。

static var CENTER := Vector2(640, -188)
static var RADIUS := 320.0
static var SPAN_DEG := 126.0
static var THICK := 14.0
const TRACK_THICK := 24.0
const HP_LIGHT := Color("ffc0dc")
const HP_DEEP := Color("ff5c9e")
const NAME_Y := 96.0
const NUM_Y := 130.0
const FACE_C := Vector2(640, 52)
const FACE_R := 36.0


func _build() -> void:
	super._build()
	position = Vector2.ZERO
	_base_y = 0.0
	if _name_canvas != null:
		_name_canvas.visible = false   # 名字由弧自己画


## 弧两端的角度（Godot 角度：0＝正右，顺时针为正；弧底在 90°）
static func arc_range() -> Vector2:
	return Vector2(90.0 - SPAN_DEG / 2.0, 90.0 + SPAN_DEG / 2.0)


## 比例 k（0～1）对应的角度：满血时从左端（153°）一直到右端（27°）
static func angle_at(k: float) -> float:
	var ar := arc_range()
	return ar.y - (ar.y - ar.x) * clampf(k, 0.0, 1.0)


## 弧底（最低点）的 y：名字、数字、状态胶囊都排在它下面一点
static func arc_bottom() -> float:
	return CENTER.y + RADIUS


func rates() -> Vector2:
	var r := _read(battler)
	var mhp := maxf(float(r.mhp), 1.0)
	return Vector2(clampf(float(r.hp) / mhp, 0.0, 1.0), clampf(hp_red / mhp, 0.0, 1.0))


func number_text() -> String:
	return format_number(hp_number)


func max_text() -> String:
	return format_number(maxf(float(_read(battler).mhp), 0.0))


func _draw() -> void:
	if battler == null or layout_alpha <= 0:
		return
	var al := layout_alpha / 255.0
	var ar := arc_range()
	var a_left := deg_to_rad(ar.y)
	var pts := 96
	draw_arc(CENTER, RADIUS, deg_to_rad(ar.x), a_left, pts, Color(0, 0, 0, 0.65 * al), TRACK_THICK, true)
	var k := rates()
	if k.y > k.x:   # 扣血残影（原红条）：橙
		draw_arc(CENTER, RADIUS, deg_to_rad(angle_at(k.x)), deg_to_rad(angle_at(k.y)), pts, Color(XUiSkin.DOWN, al), THICK, true)
	if k.x > 0.0:
		var a_hp := deg_to_rad(angle_at(k.x))
		draw_arc(CENTER, RADIUS, a_hp, a_left, pts, Color(XUiSkin.HP, 0.16 * al), THICK + 16.0, true)
		draw_arc(CENTER, RADIUS, a_hp, a_left, pts, Color(XUiSkin.HP, 0.30 * al), THICK + 6.0, true)
		# 左浅右深的渐变（样稿 hpa→hpb）：分几段画
		var segs := 12
		for i in segs:
			var t0 := float(i) / segs
			var t1 := float(i + 1) / segs
			var b0 := a_left - (a_left - a_hp) * t0
			var b1 := a_left - (a_left - a_hp) * t1
			var tt := (rad_to_deg(b0) - ar.x) / (ar.y - ar.x)
			draw_arc(CENTER, RADIUS, b1, b0, maxi(pts / segs, 4), Color(HP_DEEP.lerp(HP_LIGHT, tt), al), THICK, true)
	if _face_tex != null:
		draw_circle(FACE_C, FACE_R + 2.0, Color(0, 0, 0, 0.6 * al))
		XSkinPartyStrip.draw_round_texture(self, _face_tex, FACE_C, FACE_R)
		draw_arc(FACE_C, FACE_R, 0.0, TAU, 48, Color(XUiSkin.GOLD, 0.7 * al), 1.5, true)
	var title := XUiSkin.font("title")
	var num := XUiSkin.font("num")
	var nm := _name_text
	var nw := title.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x
	var shadow := Color(0, 0, 0, 0.75 * al)
	draw_string_outline(title, Vector2(CENTER.x - nw / 2.0, NAME_Y + 27), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, 4, shadow)
	draw_string(title, Vector2(CENTER.x - nw / 2.0, NAME_Y + 27), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(name_color(), al))
	if digits.is_empty():   # 插件参数关了血量数字
		return
	var cur := "".join(PackedStringArray(digits))
	var mx := " / " + max_text()
	var cw := num.get_string_size(cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var mw := num.get_string_size(mx, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var x0 := CENTER.x - (cw + mw) / 2.0
	draw_string_outline(num, Vector2(x0, NUM_Y + 30), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 4, shadow)
	draw_string(num, Vector2(x0, NUM_Y + 30), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(XUiSkin.HP_TEXT, al))
	draw_string_outline(num, Vector2(x0 + cw, NUM_Y + 30), mx, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 3, shadow)
	draw_string(num, Vector2(x0 + cw, NUM_Y + 30), mx, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(XUiSkin.GOLD, al))
