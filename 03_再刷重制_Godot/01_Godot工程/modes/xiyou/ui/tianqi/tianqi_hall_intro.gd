class_name XTianqiHallIntro
extends CanvasLayer
## 天启篇进大厅过场「落印」（T103；开局界面提案 v0.2 第二节、第四节「时序锁」；D154＝B、D155）。
## 只在新开一局时播（XTianqi.has_pending()）：读档进大厅、从副本回大厅都不播；新皮肤关着（界面风格选了原版）或动效「关」不播。
## 地图场景 _ready 里：load_map 之前 cover() 先挂底盖住读图，load_map 之后 await play()，播完或跳过才去跑开局指令
## （引路人三句＋问道号 prompt，跑完才 refresh_events() 放 EV020 首次到达存档）。所以过场结束前不会出问道号、不会存档。
## 过程（全部档，约 2.4 秒＋地名条）：通用法阵铺开 → 五人从左边走进阵里站成一排 → 难度徽记从上面盖下来 →
## 法阵收成漩涡、五人被卷进去 → 从玩家落点一圈圈揭开大厅，出地名条。
## 简化档：直接显示合拢的漩涡和徽记，停 0.6 秒，然后淡入大厅＋地名条。
## 任意键、手柄键、点屏幕都跳过，直接淡到大厅（跳过时地图自己的地名条照常出）。

## 总开关：false＝不播，进大厅跟 T103 之前一样（测试里不想等过场的也设这个，不动「界面动效」，免得别的页的动画跟着变）
static var ENABLED := true

const NODE_NAME := "TianqiHallIntro"
const LAYER := 60            # 盖过 ui 层（10：HUD、对话框），低于地图的全屏黑幕（80）
const STAGE := Vector2(1280, 720)
const CENTER := Vector2(640, 360)
const CIRCLE_SIZE := 600.0
const BADGE_SIZE := 180.0
const BADGE_Y := 300.0
const WALK_Y := 428.0        # 五人站位的中心高度
const WALK_GAP := 92.0
const SPRITE := 96.0         # 战斗小人 64px ×1.5
const SKIP_FADE := 0.15
const HOLE_SHADER := """
shader_type canvas_item;
uniform vec2 center = vec2(640.0, 360.0);
uniform float radius = 0.0;
uniform vec2 size = vec2(1280.0, 720.0);
void fragment() {
	if (radius > 0.0) {
		COLOR.a *= smoothstep(radius - 3.0, radius + 3.0, distance(SCREEN_UV * size, center));
	}
}
"""

signal done

var mode := XUiSkin.Motion.FULL
var playing := false
var skipped := false
var finished := false
var title_text := ""
var sub_text := ""

var _scene: Node = null
var _mask: Control
var _hole: ShaderMaterial
var _stage: Control
var _circle: TextureRect
var _badge: TextureRect
var _badge_glow: TextureRect
var _ring: TextureRect
var _walkers: Array = []     # [{rect, frames}]
var _place: Control
var _skip_hint: Control
var _tween: Tween
var _sprite_t := 0.0


## 这次进图要不要播
static func wanted() -> bool:
	return ENABLED and XTianqi.has_pending() and XUiSkin.on() and XUiSkin.motion() != XUiSkin.Motion.OFF


## load_map 之前挂上：先只有底（盖住读图那几帧）
static func cover(scene: Node) -> XTianqiHallIntro:
	var old := scene.get_node_or_null(NODE_NAME)
	if old != null:
		return old
	var n := XTianqiHallIntro.new()
	n.name = NODE_NAME
	n._scene = scene
	scene.add_child(n)
	return n


## load_map 之后：播完或跳过才返回；返回时过场节点已经释放
static func play(scene: Node) -> void:
	var n := cover(scene)
	if n.finished:
		return
	n._start()
	if not n.finished:
		await n.done


## 地名条小字：「<难度名> · 存档 N」（存档位从开局指令里的存档位开关读；读不到只写难度）
static func subtitle(s: XState) -> String:
	var d := XTianqi.difficulty_of(s)
	var dn := str(d.get("name", ""))
	var slot := pending_slot()
	if slot <= 0:
		return dn
	return "%s · 存档 %d" % [dn, slot] if dn != "" else "存档 %d" % slot


## 开局指令（XTianqi.start_new_game 放的）里打开的存档位开关：161～165 → 1～5，276～280 → 6～10；没有为 0
static func pending_slot() -> int:
	for c in XTianqi._pending:
		if not (c is Dictionary) or int(c.get("code", 0)) != 121:
			continue
		var p: Array = c.get("parameters", [])
		if p.size() < 3 or int(p[2]) != 0:
			continue
		var id := int(p[0])
		if id >= 161 and id <= 165:
			return id - 160
		if id >= 276 and id <= 280:
			return id - 270
	return 0


## 跳过提示：触屏写「轻触」，键盘手柄写「任意键」
static func skip_key_text() -> String:
	return "轻触" if XUiSkin.touch() else "任意键"


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	mode = XUiSkin.motion()
	_mask = Control.new()
	_mask.name = "Mask"
	_mask.mouse_filter = Control.MOUSE_FILTER_STOP   # 过场期间点不到下面的 HUD
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_mask)
	XUiSkin.menu_backdrop(_mask)   # 跟开局三页同一张底
	# 揭开时挖洞：底的每一层都挂同一个材质（按屏幕坐标算，渐变、火星、正式美术背景都一起挖）
	var sh := Shader.new()
	sh.code = HOLE_SHADER
	_hole = ShaderMaterial.new()
	_hole.shader = sh
	_apply_hole(_mask)


func _apply_hole(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).material = _hole
	for c in n.get_children():
		_apply_hole(c)


func _start() -> void:
	if playing:
		return
	playing = true
	var s := XState.current
	title_text = str(_scene.get("map_name_text")) if _scene != null and _scene.get("map_name_text") != null else ""
	if title_text == "":
		title_text = str(XDB.map(XTianqi.HALL_MAP).get("displayName", ""))
	sub_text = subtitle(s)
	if _scene != null and _scene.has_method("_show_map_name"):
		_scene._show_map_name("")   # 地名由过场的地名条出，地图自己那条先收起（跳过时再出）
	_build_stage(s)
	_build_place()
	_build_skip_hint()
	_layout()
	get_viewport().size_changed.connect(_layout)
	if mode == XUiSkin.Motion.SIMPLE:
		_run_simple()
	else:
		_run_full()


func _build_stage(s: XState) -> void:
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = STAGE
	add_child(_stage)
	_circle = _tex_rect(XUiSkin.circle_texture(), Vector2(CIRCLE_SIZE, CIRCLE_SIZE), CENTER)
	_circle.name = "Circle"
	_circle.modulate = Color(XUiSkin.GOLD_LIGHT, 0.0)
	_stage.add_child(_circle)
	var d := XTianqi.difficulty_of(s)
	var bp := XTianqi.badge_path(d) if not d.is_empty() else ""
	var badge_tex: Texture2D = load(bp) if bp != "" and ResourceLoader.exists(bp) else null
	_badge_glow = _tex_rect(XUiSkin.glow_texture(), Vector2(BADGE_SIZE, BADGE_SIZE) * 1.7, Vector2(CENTER.x, BADGE_Y))
	_badge_glow.modulate = Color(XUiSkin.SEL_FILL, 0.0)
	_stage.add_child(_badge_glow)
	_ring = _tex_rect(XUiSkin.seal_halo_texture(), Vector2(320, 320), CENTER)
	_ring.modulate = Color(XUiSkin.GOLD, 0.0)
	_stage.add_child(_ring)
	var lineup: Array = s.flags.get("tianqi", {}).get("lineup", []) if s != null else []
	for i in lineup.size():
		var frames := XTianqiStartPage._sv_frames(XDB.rec("Actors", int(lineup[i])))
		if frames.is_empty():
			continue
		var r := _tex_rect(frames[0], Vector2(SPRITE, SPRITE), _walk_spot(i, lineup.size()))
		r.name = "Walker%d" % i
		r.flip_h = true   # 侧视图朝左，走进来要朝右
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.modulate.a = 0.0
		_stage.add_child(r)
		_walkers.append({"rect": r, "frames": frames, "spot": _walk_spot(i, lineup.size()), "i": i})
	_badge = _tex_rect(badge_tex, Vector2(BADGE_SIZE, BADGE_SIZE), Vector2(CENTER.x, BADGE_Y))
	_badge.name = "Badge"
	_badge.modulate.a = 0.0
	_stage.add_child(_badge)


func _build_place() -> void:
	_place = Control.new()
	_place.name = "PlaceBar"
	_place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place.modulate.a = 0.0
	add_child(_place)
	var band := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.82, 1.0])
	var k := Color(XUiSkin.BG, 0.82)
	g.colors = PackedColorArray([Color(k, 0.0), k, k, Color(k, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	band.texture = gt
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.name = "Band"
	_place.add_child(band)
	var t := _label(title_text, XUiSkin.fs(46), Color.WHITE)
	t.name = "PlaceTitle"
	_place.add_child(t)
	var sub := _label(sub_text, XUiSkin.fs(17), XUiSkin.GOLD)
	sub.name = "PlaceSub"
	_place.add_child(sub)


func _build_skip_hint() -> void:
	_skip_hint = HBoxContainer.new()
	_skip_hint.name = "SkipHint"
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint.add_theme_constant_override("separation", 6)
	_skip_hint.modulate.a = 0.0
	add_child(_skip_hint)
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = XUiSkin.TEXT_2
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(11)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	pill.add_theme_stylebox_override("panel", sb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key := _label(skip_key_text(), XUiSkin.fs(15), XUiSkin.TEXT)
	key.name = "SkipKey"
	pill.add_child(key)
	_skip_hint.add_child(pill)
	var word := _label("跳过", XUiSkin.fs(15), XUiSkin.TEXT_2)
	word.name = "SkipWord"
	_skip_hint.add_child(word)


## 舞台按 1280×720 排，宽屏时整体居中；地名条、跳过提示贴可见区
func _layout() -> void:
	if not is_inside_tree():
		return
	var vs := get_viewport().get_visible_rect().size
	if _stage != null:
		_stage.position = ((vs - STAGE) / 2.0).round()
	if _hole != null:
		_hole.set_shader_parameter("size", vs)
	if _place != null:
		var t: Label = _place.get_node("PlaceTitle")
		var sub: Label = _place.get_node("PlaceSub")
		var w := maxf(t.get_minimum_size().x, sub.get_minimum_size().x) + 140.0
		var h := t.get_minimum_size().y + sub.get_minimum_size().y + 20.0
		_place.position = Vector2(roundf((vs.x - w) / 2.0), roundf(vs.y * 250.0 / 720.0))
		_place.size = Vector2(w, h)
		var band: TextureRect = _place.get_node("Band")
		band.position = Vector2.ZERO
		band.size = Vector2(w, h)
		t.position = Vector2(0, 10)
		t.size = Vector2(w, t.get_minimum_size().y)
		sub.position = Vector2(0, 10 + t.get_minimum_size().y)
		sub.size = Vector2(w, sub.get_minimum_size().y)
	if _skip_hint != null:
		var ms := _skip_hint.get_combined_minimum_size()
		_skip_hint.size = ms
		_skip_hint.position = Vector2(vs.x - 24.0 - ms.x, vs.y - 14.0 - ms.y)


## 揭开的圆心：玩家开局落点在屏幕上的坐标（相机变换后；宽屏也对得上）
func _reveal_center() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	var p = _scene.get("player") if _scene != null else null
	if p is Node2D and is_instance_valid(p):
		var at: Vector2 = get_viewport().get_canvas_transform() * ((p as Node2D).global_position + Vector2(0, -24))
		return Vector2(clampf(at.x, 0.0, vs.x), clampf(at.y, 0.0, vs.y))
	return vs / 2.0


func _reveal_radius(c: Vector2) -> float:
	var vs := get_viewport().get_visible_rect().size
	var r := 0.0
	for corner in [Vector2.ZERO, Vector2(vs.x, 0), Vector2(0, vs.y), vs]:
		r = maxf(r, c.distance_to(corner))
	return r + 8.0


func _walk_spot(i: int, n: int) -> Vector2:
	return Vector2(CENTER.x + (i - (n - 1) / 2.0) * WALK_GAP, WALK_Y)


func _set_center(r: Control, c: Vector2) -> void:
	r.position = c - r.size / 2.0


## ---- 全部档（时间点照样稿 trans_b 的关键帧，3.0 秒片长里前 2.4 秒是过场） ----
func _run_full() -> void:
	var t := create_tween().set_parallel(true)
	_tween = t
	# 法阵：0～0.35 铺开（0.3→1、-60°→0°），0.35～1.3 慢转 30°，1.3～1.75 收成漩涡（转到 420°、缩到 0.06），1.9 前消失
	_circle.scale = Vector2(0.3, 0.3)
	_circle.rotation_degrees = -60.0
	t.tween_property(_circle, "modulate:a", 0.85, 0.35)
	t.tween_property(_circle, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_circle, "rotation_degrees", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	t.tween_property(_circle, "rotation_degrees", 30.0, 0.95).set_delay(0.35)
	t.tween_property(_circle, "rotation_degrees", 420.0, 0.45).set_delay(1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_circle, "scale", Vector2(0.06, 0.06), 0.45).set_delay(1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_circle, "modulate:a", 1.0, 0.45).set_delay(1.3)
	t.tween_property(_circle, "modulate:a", 0.0, 0.15).set_delay(1.75)
	# 五人：0～约 1.0 从左边走进来站成一排（队伍间距一路不变，排尾先停），1.3～1.65 卷进阵心（缩小、淡出）
	var n := _walkers.size()
	for w in _walkers:
		var r: TextureRect = w.rect
		var spot: Vector2 = w.spot
		var i: int = w.i
		var lead := (n - 1 - i) * 0.04   # 排头（最右）先动、走得最远
		_set_center(r, Vector2(spot.x - 900.0, spot.y))
		r.modulate.a = 1.0
		r.pivot_offset = r.size / 2.0
		t.tween_property(r, "position", spot - r.size / 2.0, 0.95 - lead).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(r, "position", Vector2(CENTER.x, WALK_Y + 12.0) - r.size / 2.0, 0.35).set_delay(1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(r, "scale", Vector2(0.2, 0.2), 0.35).set_delay(1.3)
		t.tween_property(r, "modulate:a", 0.0, 0.35).set_delay(1.3)
	# 徽记：0.95～1.1 从上面盖下来（2.6→0.92），1.18 回到 1，1.35～1.7 缩进漩涡
	_badge.scale = Vector2(2.6, 2.6)
	t.tween_property(_badge, "modulate:a", 1.0, 0.15).set_delay(0.95)
	t.tween_property(_badge, "scale", Vector2(0.92, 0.92), 0.15).set_delay(0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_badge, "scale", Vector2.ONE, 0.08).set_delay(1.1)
	t.tween_property(_badge, "scale", Vector2(0.1, 0.1), 0.35).set_delay(1.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_badge, "modulate:a", 0.0, 0.35).set_delay(1.35)
	t.tween_property(_badge_glow, "modulate:a", 0.9, 0.15).set_delay(0.95)
	t.tween_property(_badge_glow, "modulate:a", 0.0, 0.35).set_delay(1.35)
	# 盖印的冲击环：1.1～1.5 从 0.3 扩到 1.6、淡出
	_ring.scale = Vector2(0.3, 0.3)
	t.tween_callback(func(): _ring.modulate.a = 0.9).set_delay(1.1)
	t.tween_property(_ring, "scale", Vector2(1.6, 1.6), 0.4).set_delay(1.1).set_ease(Tween.EASE_OUT)
	t.tween_property(_ring, "modulate:a", 0.0, 0.4).set_delay(1.12).set_ease(Tween.EASE_OUT)
	# 揭开大厅：1.8～2.4 从玩家落点挖洞扩到全屏
	t.tween_method(_reveal, 0.0, 1.0, 0.6).set_delay(1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# 地名条：2.15～2.4 浮上来，停到 2.85，2.85～3.1 淡出
	_place_tracks(t, 2.15, 0.45)
	# 跳过提示：0.3～0.45 出，2.1～2.2 收
	t.tween_property(_skip_hint, "modulate:a", 1.0, 0.15).set_delay(0.3)
	t.tween_property(_skip_hint, "modulate:a", 0.0, 0.1).set_delay(2.1)
	t.chain().tween_callback(_finish)


## ---- 简化档：合拢的漩涡＋徽记停 0.6 秒，然后淡入大厅＋地名条 ----
func _run_simple() -> void:
	_circle.scale = Vector2(0.32, 0.32)
	_circle.rotation_degrees = 420.0
	_circle.modulate.a = 1.0
	_badge.scale = Vector2(0.6, 0.6)
	_badge.modulate.a = 1.0
	_set_center(_badge, CENTER)   # 徽记压在合拢的漩涡正中
	_set_center(_badge_glow, CENTER)
	_badge_glow.modulate.a = 0.9
	_skip_hint.modulate.a = 1.0
	var t := create_tween().set_parallel(true)
	_tween = t
	t.tween_property(_stage, "modulate:a", 0.0, 0.3).set_delay(0.6)
	t.tween_property(_mask, "modulate:a", 0.0, 0.3).set_delay(0.6)
	t.tween_property(_skip_hint, "modulate:a", 0.0, 0.1).set_delay(0.6)
	_place_tracks(t, 0.75, 0.5)
	t.chain().tween_callback(_finish)


func _place_tracks(t: Tween, at: float, hold: float) -> void:
	_place.position.y += 10.0
	var y := _place.position.y
	t.tween_property(_place, "modulate:a", 1.0, 0.25).set_delay(at)
	t.tween_property(_place, "position:y", y - 10.0, 0.25).set_delay(at).set_ease(Tween.EASE_OUT)
	t.tween_property(_place, "modulate:a", 0.0, 0.25).set_delay(at + 0.25 + hold)


func _reveal(k: float) -> void:
	if k <= 0.0:
		_hole.set_shader_parameter("radius", 0.0)
		return
	var c := _reveal_center()
	_hole.set_shader_parameter("center", c)
	_hole.set_shader_parameter("radius", maxf(_reveal_radius(c) * k, 0.5))
	_stage.modulate.a = 0.0 if k > 0.0 else 1.0


func _process(delta: float) -> void:
	if not playing or _walkers.is_empty():
		return
	_sprite_t += delta / maxf(Engine.time_scale, 0.001)
	var f := int(_sprite_t / 0.15) % 4
	for w in _walkers:
		var frames: Array = w.frames
		(w.rect as TextureRect).texture = frames[[0, 1, 2, 1][f] % frames.size()]


## 任意键、手柄键、点屏幕（鼠标按下、触屏按下）都跳过；松开、移动、长按回显不算
func _input(event: InputEvent) -> void:
	if not playing or skipped or finished:
		return
	var hit := false
	if event is InputEventKey:
		hit = event.pressed and not event.echo
	elif event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch:
		hit = event.pressed
	if not hit:
		return
	get_viewport().set_input_as_handled()
	skip()


## 跳过：停掉时间轴，整层 0.15 秒淡掉；地图自己的地名条照常出
func skip() -> void:
	if not playing or skipped or finished:
		return
	skipped = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var t := create_tween().set_parallel(true)
	_tween = t
	for c in [_mask, _stage, _place, _skip_hint]:
		if c != null:
			t.tween_property(c, "modulate:a", 0.0, SKIP_FADE)
	t.chain().tween_callback(func():
		if _scene != null and is_instance_valid(_scene) and _scene.has_method("_show_map_name") and title_text != "":
			_scene._show_map_name(title_text)
		_finish())


func _finish() -> void:
	if finished:
		return
	finished = true
	playing = false
	done.emit()
	queue_free()


func _tex_rect(tex: Texture2D, sz: Vector2, center: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = sz
	r.pivot_offset = sz / 2.0
	r.position = center - sz / 2.0
	return r


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", XUiSkin.font("title"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", XUiSkin.outline_size())
	l.add_theme_color_override("font_outline_color", XUiSkin.outline_color())
	return l
