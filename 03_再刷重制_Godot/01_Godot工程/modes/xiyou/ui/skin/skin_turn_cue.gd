class_name XSkinTurnCue
extends Node2D
## 【cc·天启篇·未经审查】T096 换人回合提示（v0.7 样稿 battle 的 .horn 两道旧金圈＋.tname 胶囊）：XSkinBattle.turn_cue 建，演完自己释放。
## 金色＝事件（README 第二节「回合提示从红改成金」）。只是画面，不挡点击、不占输入。

const TIME := 0.85          # 整段
const RING_TIME := 0.33     # 一道圈扩开淡掉
const RING2_DELAY := 0.1
const POP_TIME := 0.12      # 胶囊 0.6→1.06→1
const FADE_AT := 0.68       # 胶囊开始淡出
const H := 40.0

var who := ""
var feet := Vector2.ZERO    # 角色脚底（父节点坐标）
var body_h := 64.0
var t := 0.0
## 最近一次提示开始的时刻（毫秒）：指令环上方「某某的行动」等胶囊淡掉再淡入，两行字不叠
static var last_ms := -100000


func _ready() -> void:
	z_index = 6
	last_ms = Time.get_ticks_msec()


## 指令环名字现在的透明度（提示演完前 0，之后 0.17 秒淡入）
static func title_alpha() -> float:
	var e := (Time.get_ticks_msec() - last_ms) / 1000.0
	return clampf((e - FADE_AT) / (TIME - FADE_AT), 0.0, 1.0)


func _process(delta: float) -> void:
	t += delta
	if t >= TIME:
		queue_free()
		return
	queue_redraw()


func center() -> Vector2:
	return feet - Vector2(0, body_h * 0.45)


func capsule_rect() -> Rect2:
	var f := XUiSkin.font("title")
	var w := f.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + XUiSkin.font("body").get_string_size("的回合", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44.0
	w += 6.0
	# 摆在角色右边、头的高度（指令环在左半边，胶囊不压球；样稿那一刻环还没出来）；右边放不下就放左边
	var r := Rect2(feet.x + 30.0, feet.y - body_h * 0.6 - H / 2.0, w, H)
	var right := get_viewport_rect().size.x - 8.0
	if r.end.x > right:
		r.position.x = feet.x - 30.0 - w
	r.position.y = clampf(r.position.y, 8.0, maxf(8.0, get_viewport_rect().size.y - H - 8.0))
	return r


func _draw() -> void:
	var c := center()
	for k in 2:
		var lt := (t - RING2_DELAY * k) / RING_TIME
		if lt <= 0.0 or lt >= 1.0:
			continue
		var sc := lerpf(0.3, 2.2 if k == 0 else 1.8, XSkinBattleMotion.ease_out(lt))
		var a := (1.0 - lt) * (1.0 if k == 0 else 0.8)
		draw_arc(c, 30.0 * sc, 0.0, TAU, 48, Color(XUiSkin.GOLD, a), 3.0, true)
		draw_arc(c, 30.0 * sc, 0.0, TAU, 48, Color(XUiSkin.GOLD, a * 0.35), 9.0, true)
	# 胶囊
	var pa := 1.0
	if t > FADE_AT:
		pa = clampf(1.0 - (t - FADE_AT) / (TIME - FADE_AT), 0.0, 1.0)
	var pt := clampf(t / POP_TIME, 0.0, 1.0)
	var ps := lerpf(0.6, 1.0, XSkinBattleMotion.ease_out_back(pt))
	var r := capsule_rect()
	var mid := r.get_center()
	draw_set_transform(mid, 0.0, Vector2(ps, ps))
	var rr := Rect2(r.position - mid, r.size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(XUiSkin.BG, 0.92 * pa * pt)
	sb.border_color = Color(XUiSkin.GOLD, pa * pt)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(H / 2.0))
	sb.shadow_color = Color(XUiSkin.GOLD, 0.35 * pa * pt)
	sb.shadow_size = 10
	sb.draw(get_canvas_item(), rr)
	var tf := XUiSkin.font("title")
	var bf := XUiSkin.font("body")
	var x := rr.position.x + 22.0
	var y := rr.position.y + H / 2.0 + 8.0
	XUiSkin.ds(self, tf, Vector2(x, y), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(XUiSkin.TEXT, pa * pt))
	x += tf.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 6.0
	XUiSkin.ds(self, bf, Vector2(x, y - 1.0), "的回合", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(XUiSkin.GOLD, pa * pt))
	draw_set_transform(Vector2.ZERO)
