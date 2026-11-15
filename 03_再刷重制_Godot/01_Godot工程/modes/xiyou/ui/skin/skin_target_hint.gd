class_name XSkinTargetHint
extends Control
## 【cc·天启篇·未经审查】新界面 2A：选目标时挂在目标头上的提示（胶囊：名字＋范围，敌人朱红边、我方旧金边；
## 目标脚下一圈锁定环，0.2 秒从大缩到位）。只是画面提示，选哪个、怎么确定都还是 XBattleScene 原来的流程。

const H := 40.0
const GAP := 14.0          # 胶囊底离头顶
const LOCK_TIME := 0.2

var target_name := ""
var sub := ""
var enemy := true
var feet := Vector2.ZERO   # 目标脚底（父节点坐标）
var body_h := 64.0
var _lock_t := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5


## feet：目标脚底在父节点里的位置；h：目标图高
func show_for(name_text: String, sub_text: String, feet_pos: Vector2, h: float, is_enemy: bool) -> void:
	var changed := name_text != target_name or feet_pos != feet or not visible
	target_name = name_text
	sub = sub_text
	enemy = is_enemy
	feet = feet_pos
	body_h = h
	visible = true
	if changed:
		_lock_t = 0.0 if XUiSkin.motion() != XUiSkin.Motion.OFF else 1.0
	_layout()
	queue_redraw()


## 胶囊宽
func pill_width() -> float:
	var title := XUiSkin.font("title")
	var body := XUiSkin.font("body")
	var w := title.get_string_size(target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 44.0
	if sub != "":
		w += body.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 10.0
	return w


## 胶囊在父节点里的矩形（贴在头顶上方，收在 1280×720 画布里；画布原点由调用方加过）
func pill_rect() -> Rect2:
	var w := pill_width()
	var p := Vector2(feet.x - w / 2.0, feet.y - body_h - GAP - H)
	if p.y < 8.0:
		p.y = feet.y + 16.0   # 头顶放不下就放脚下
	var vw := get_parent_area_size().x if is_inside_tree() else 1280.0
	p.x = clampf(p.x, 8.0, maxf(8.0, vw - w - 8.0))
	return Rect2(p, Vector2(w, H))


func _layout() -> void:
	position = Vector2.ZERO
	size = Vector2(1, 1)


func _process(delta: float) -> void:
	if visible and _lock_t < 1.0:
		_lock_t = minf(1.0, _lock_t + delta / LOCK_TIME)
		queue_redraw()


func _draw() -> void:
	if target_name == "":
		return
	var edge := XUiSkin.SEL_LINE if enemy else XUiSkin.GOLD
	# 锁定环（脚下的椭圆，从 2 倍缩到位）
	var k := 1.0 - pow(1.0 - _lock_t, 3.0)
	var rx := 46.0 * lerpf(2.0, 1.0, k)
	var ry := 14.0 * lerpf(2.0, 1.0, k)
	draw_set_transform(feet, 0.0, Vector2(1.0, ry / rx))
	draw_arc(Vector2.ZERO, rx, 0, TAU, 48, Color(edge, 0.35 * k), 7.0, true)
	draw_arc(Vector2.ZERO, rx, 0, TAU, 48, Color(edge, 0.9 * k), 2.0, true)
	draw_set_transform(Vector2.ZERO)
	# 胶囊
	var r := pill_rect()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(XUiSkin.BG, 0.92)
	s.border_color = edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(int(H / 2.0))
	s.shadow_color = Color(edge, 0.35)
	s.shadow_size = 8
	s.draw(get_canvas_item(), r)
	var title := XUiSkin.font("title")
	var body := XUiSkin.font("body")
	var x := r.position.x + 22.0
	var base := r.position.y + H / 2.0 + 8.0
	draw_string(title, Vector2(x, base), target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, XUiSkin.TEXT)
	if sub != "":
		x += title.get_string_size(target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 10.0
		draw_string(body, Vector2(x, base - 2.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, XUiSkin.GOLD)
