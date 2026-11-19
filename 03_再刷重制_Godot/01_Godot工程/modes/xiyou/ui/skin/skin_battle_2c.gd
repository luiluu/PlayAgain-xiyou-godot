class_name XSkin2C
extends RefCounted
## 【cc·天启篇·未经审查】新界面 2C 卡 A（T265，照 T254 细节设计 1.1「落印」、1.2「灭印」，Kyo D231）：胜利结算、全灭画面换新画法。
## 只换画法：奖励发放、经验条 3 秒、1 秒后可关、自动战斗 3.4 秒自动关、升级音效、全灭之后的淡出与回标题，一行逻辑不动；
## 只有全灭开头的 24 帧淡入，新画法下换成 1.0 秒「灭印」（可跳过）。
## 只在 XUiSkin.on()（天启篇存档且设置「界面风格」选新）时走新画法；西游存档、开关关着时两页旧画法一行不变。
## 回退开关：
##   VICTORY            胜利结算落印（关＝旧页）
##   GAMEOVER           全灭灭印＋提示（关＝旧页）
##   DROP_SORT_QUALITY  结算掉落按品质高的在前（只改显示；关＝旧序：物品／武器／防具各按编号）
##   GAMEOVER_SUMMARY   全灭 B 版「本局去到哪」两行（问题 2C-1，Kyo 没点头，默认关）
## 战斗里的四个浮层（印盘、伤害统计、连击、掉落图标）归卡 B，不在这里。

static var ENABLED := true
static var VICTORY := true
static var GAMEOVER := true
static var DROP_SORT_QUALITY := true
static var GAMEOVER_SUMMARY := false

## 进场时长（秒）：首领战全套、小怪战半程（D231）；简化档只留淡入（＋首领战盖蜡）
const BOSS_INTRO := 1.0
const MINOR_INTRO := 0.5
const SIMPLE_INTRO := 0.2
const SIMPLE_SEAL := 0.2    # 简化档首领战：淡入完接着盖蜡那一下（0.2 起 0.12 秒）

const RING_C := Vector2(640, 372)
const RING_R := 286.0
const CELL_W := 170.0
const CELL_W5 := 150.0
const CELL_TOP := 236.0
const SPRITE_H := 160.0
const FEET_Y := 400.0
const BIG_MAX := 4
const BIG_D := 68.0
const BIG_CELL := 148.0
const SMALL_D := 44.0
const SMALL_CELL := 56.0
const DROP_ROW_Y := 566.0
const DETAIL := Rect2(288, 88, 704, 544)
const DETAIL_ROW := 48.0
const DETAIL_DROP_ROW := 40.0
const AUTO_CLOSE := 3.4
const DRAG_SLOP := 8.0


static func on() -> bool:
	return ENABLED and XUiSkin.on()


static func victory_on() -> bool:
	return VICTORY and on()


static func gameover_on() -> bool:
	return GAMEOVER and on()


## ---- 公用 ----

static var _serif: Font = null


## 「战斗胜利」专用宋体 Heavy（D231 宋体例外，只这一处和卡 B 的连击数字）；字距 22。读不到字体文件时落回玩家版字体
static func serif() -> Font:
	if _serif == null:
		var path: String = XUiSkin.FONT_DIR + str(XUiSkin.FONT_FILES.title)
		var base: Font = load(path) if ResourceLoader.exists(path) else null
		var fv := FontVariation.new()
		fv.base_font = base if base != null else GameFont.current()
		fv.spacing_glyph = 22
		_serif = fv
	return _serif


static func _f() -> Font:
	return XUiSkin.font("body")


static func _tw(s: String, fs: int, f: Font = null) -> float:
	return (f if f != null else _f()).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## 一行字：pos.y 是这行的上沿（行高按 fs×1.25 算，字的基线自己找）
static func _text(ci: CanvasItem, x: float, top: float, s: String, fs: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, f: Font = null) -> void:
	var font := f if f != null else _f()
	var base := top + (fs * 1.25 - (font.get_ascent(fs) + font.get_descent(fs))) / 2.0 + font.get_ascent(fs)
	XUiSkin.ds(ci, font, Vector2(x, base), s, align, width, fs, color)


## 名字太长：截断加省略号（不缩字）
static func fit(s: String, fs: int, w: float) -> String:
	if _tw(s, fs) <= w:
		return s
	var t := s
	while t.length() > 1 and _tw(t + "…", fs) > w:
		t = t.left(t.length() - 1)
	return t + "…"


static func _diamond(ci: CanvasItem, c: Vector2, half: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -half), c + Vector2(half, 0), c + Vector2(0, half), c + Vector2(-half, 0)]), color)


static func _diamond_line(ci: CanvasItem, c: Vector2, half: float, color: Color, w := 1.0) -> void:
	ci.draw_polyline(PackedVector2Array([c + Vector2(0, -half), c + Vector2(half, 0), c + Vector2(0, half), c + Vector2(-half, 0), c + Vector2(0, -half)]), color, w, true)


static func _pill(ci: CanvasItem, r: Rect2, fill: Color, border := Color(0, 0, 0, 0), bw := 1) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(r.size.y / 2.0))
	if border.a > 0.0:
		sb.set_border_width_all(bw)
		sb.border_color = border
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


static func _glow(ci: CanvasItem, c: Vector2, radius: float, color: Color) -> void:
	var t := XUiSkin.glow_texture()
	if t != null:
		ci.draw_texture_rect(t, Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)
	else:
		ci.draw_circle(c, radius * 0.5, Color(color, color.a * 0.4))


## 横向两头淡出的线（中间 30%～70% 实色）
static func _fade_line(ci: CanvasItem, x0: float, x1: float, y: float, h: float, color: Color) -> void:
	var xs := [x0, lerpf(x0, x1, 0.3), lerpf(x0, x1, 0.7), x1]
	var al := [0.0, 1.0, 1.0, 0.0]
	for i in 3:
		var p := PackedVector2Array([Vector2(xs[i], y), Vector2(xs[i + 1], y), Vector2(xs[i + 1], y + h), Vector2(xs[i], y + h)])
		var c0 := Color(color, color.a * al[i])
		var c1 := Color(color, color.a * al[i + 1])
		ci.draw_polygon(p, PackedColorArray([c0, c1, c1, c0]))


static func ease_out(p: float) -> float:
	p = clampf(p, 0.0, 1.0)
	return 1.0 - (1.0 - p) * (1.0 - p)


static func seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / maxf(b - a, 0.0001), 0.0, 1.0)


## 通用金蜡（T254 t254lib.seal()：不带任何一印的图案，七芒星，程序画）。c＝中心，size＝直径
static func draw_wax(ci: CanvasItem, c: Vector2, size: float, alpha := 1.0) -> void:
	var c1 := Color("f6dc9c")
	var c2 := Color("c99a48")
	var c3 := Color("6e4a1a")
	var r := size / 2.0
	ci.draw_circle(c + Vector2(0, 3), r * 0.98, Color(0, 0, 0, 0.45 * alpha))
	# 径向渐变：外 c3 → 中 c2 → 里 c1（亮心偏左上）
	var steps := 14
	for i in steps:
		var k := float(i) / (steps - 1)
		var col := c3.lerp(c2, minf(k / 0.45, 1.0)) if k < 0.45 else c2.lerp(c1, (k - 0.45) / 0.55)
		var rr := r * (1.0 - k * 0.92)
		var off := Vector2(-0.12, -0.18) * r * k
		ci.draw_circle(c + off, rr, Color(col, alpha))
	ci.draw_arc(c, r * 0.70, 0, TAU, 48, Color(c3, 0.75 * alpha), maxf(1.0, size * 0.025), true)
	ci.draw_arc(c, r * 0.66, 0, TAU, 48, Color(c1, 0.5 * alpha), 1.0, true)
	var pts := PackedVector2Array()
	for k in 8:
		var a := deg_to_rad(-90.0 + (k % 7) * 3.0 * 360.0 / 7.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r * 0.54)
	ci.draw_polyline(pts, Color(c3, 0.9 * alpha), maxf(1.5, size * 0.03), true)
	var pts2 := PackedVector2Array()
	for p in pts:
		pts2.append(p - Vector2(0.8, 0.8))
	ci.draw_polyline(pts2, Color(c1, 0.55 * alpha), 1.0, true)
	ci.draw_circle(c, r * 0.1, Color(c3, 0.85 * alpha))


## ---- 掉落：品质分档、排序 ----

static func drop_rec(d: Dictionary) -> Dictionary:
	return XDB.rec({1: "Items", 2: "Weapons", 3: "Armors"}.get(int(d.kind), "Items"), int(d.id))


## 显示档：有品质的走 XQuality.show_grade（0 普通…6 神话），没品质的（多数物品）算 -1
static func drop_grade(d: Dictionary) -> int:
	var rec := drop_rec(d)
	if rec.is_empty() or not XQuality.has_quality(rec):
		return -1
	return XQuality.show_grade(rec)


static func drop_color(d: Dictionary) -> Color:
	var rec := drop_rec(d)
	return XQuality.list_color(rec) if not rec.is_empty() else XUiSkin.TEXT


## 品质高的在前；同档照旧序（稳定排序）
static func sort_by_quality(drops: Array) -> Array:
	var keyed := []
	for i in drops.size():
		keyed.append([drop_grade(drops[i]), i, drops[i]])
	keyed.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	return keyed.map(func(k): return k[2])


## 底下一排的摆法：大章（史诗以上，最多 4 枚，按档高低）＋竖线＋小章，放不下最后一格「还有 N 样」。
## 返回 {big: [[drop, x中心]], small: [[drop, x中心]], sep: x（无为 -1）, more: N, more_x: 胶囊左缘, width: 总宽}；x 是相对整排左缘
static func drop_row(drops: Array, max_w: float) -> Dictionary:
	var big := []
	var rest := []
	var cand := []
	for i in drops.size():
		var g := drop_grade(drops[i])
		if g >= 3:
			cand.append([g, i, drops[i]])
		else:
			rest.append([g, i, drops[i]])
	cand.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	for k in cand.size():
		if k < BIG_MAX:
			big.append(cand[k][2])
		else:
			rest.append(cand[k])
	rest.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]) if DROP_SORT_QUALITY else a[1] < b[1])
	var small := rest.map(func(k): return k[2])
	var out := {"big": [], "small": [], "sep": -1.0, "more": 0, "more_x": 0.0, "width": 0.0}
	var x := 0.0
	for d in big:
		out.big.append([d, x + BIG_CELL / 2.0])
		x += BIG_CELL
	var sep_w := 21.0
	if not big.is_empty() and not small.is_empty():
		out.sep = x + 6.0
		x += sep_w
	for i in small.size():
		var left := small.size() - i - 1
		var need := SMALL_CELL + (more_w(left + 1) + 10.0 if left > 0 else 0.0)
		if x + need > max_w:
			out.more = small.size() - i
			break
		out.small.append([small[i], x + SMALL_CELL / 2.0])
		x += SMALL_CELL
	if out.more > 0:
		if out.small.is_empty() and out.sep >= 0.0:
			out.sep = -1.0
			x -= sep_w
		out.more_x = x + 10.0
		x += 10.0 + more_w(out.more)
	out.width = x
	return out


static func more_text(n: int) -> String:
	return "还有 %d 样" % n


static func more_w(n: int) -> float:
	return _tw(more_text(n), XUiSkin.fs(15)) + 28.0


## ---- 胜利结算 ----

static func victory_view(v: XVictoryScreen) -> Control:
	var view := VictoryView.new()
	view.v = v
	return view


## 详单里掉落一屏放几行（队伍几人决定剩多少高）
static func detail_rows(people: int) -> int:
	var top := DETAIL.position.y + 52.0 + people * DETAIL_ROW + 12.0 + 32.0
	return maxi(1, int((DETAIL.end.y - 16.0 - top) / DETAIL_DROP_ROW))


static func detail_scroll_max(v: XVictoryScreen) -> int:
	return maxi(0, v._drops.size() - detail_rows(v.rows.size()))


## 进场总长：首领战 1.0、小怪战 0.5；简化 0.2（首领战带盖蜡到 0.46）；关 0
static func intro_len(boss: bool, motion: int) -> float:
	match motion:
		XUiSkin.Motion.OFF:
			return 0.0
		XUiSkin.Motion.SIMPLE:
			return SIMPLE_SEAL + 0.12 if boss else SIMPLE_INTRO
	return BOSS_INTRO if boss else MINOR_INTRO


class Layer extends Control:
	var painter: Callable

	func _init(p: Callable, nearest := false) -> void:
		painter = p
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if nearest:
			texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		painter.call(self)


## 落印结算的整页：back（底图、环、标题、金蜡、两个大数、掉落排）→ sprites（小人，像素图最近邻）→ front（名字、经验条、升级小标、详单、提示）
class VictoryView extends Control:
	var v: XVictoryScreen
	var boss := false
	var motion := 0
	var detail := false
	var hints: XSkinKeyHints
	var base: Control     # 压黑＋本线底图＋径向压暗（开详单时不跟着淡）
	var back: Control
	var sprites: Control
	var front: Control
	var view := Vector2(1280, 720)
	var ox := 0.0
	var _bg: Texture2D
	var _row: Dictionary
	var _sv := {}         # actor → {tex, src, scale} 或 {face}
	var _drag := {}       # 详单里按下：{y, top, moved}
	var _hint_key := ""
	var _off := Vector2.ZERO   # 背层这一帧的震动偏移（缩放、旋转画完回到它）

	func _ready() -> void:
		name = "Skin2CVictory"
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		view = get_viewport_rect().size
		ox = (view.x - 1280.0) / 2.0
		boss = v.boss
		motion = XUiSkin.motion()
		var line := XTianqiLine.current(XState.current) if XState.current != null else ""
		if line != "":
			var p := "res://content/ui_skin/phase01/bg/%s_%s.png" % [line, "1600x720" if view.x > 1281.0 else "1280x720"]
			_bg = load(p) if ResourceLoader.exists(p) else null
		var wide := view.x > 1281.0
		_row = XSkin2C.drop_row(v._drops, (view.x - 112.0) if wide else 1168.0)
		for r in v.rows:
			_sv[r.actor] = _sprite_of(r.actor)
		base = XSkin2C.Layer.new(_paint_base)
		back = XSkin2C.Layer.new(_paint_back)
		add_child(base)
		sprites = XSkin2C.Layer.new(_paint_sprites, true)
		front = XSkin2C.Layer.new(_paint_front)
		add_child(back)
		add_child(sprites)
		add_child(front)
		hints = XSkinKeyHints.new()
		add_child(hints)
		_refresh_hints()

	## 小人：战斗侧视图待机第 0 格，按身高 160 定倍数（整套同一倍数）；没有侧视图用头像圆
	func _sprite_of(a: XActor) -> Dictionary:
		var at := XSkinMainMenu.sv_frame(a, 0)
		if at != null:
			var info := XSkinMainMenu._sv_info(a, XAppearance.look_key(a))
			var used: Rect2 = info.get("used", Rect2(Vector2.ZERO, at.region.size))
			if used.size.y > 0:
				return {"tex": at.atlas, "src": Rect2(at.region.position + used.position, used.size), "scale": XSkin2C.SPRITE_H / used.size.y}
		var d := a.data()
		return {"face": XUiSkin.face(str(d.get("faceName", "")), int(d.get("faceIndex", 0)))}

	func t() -> float:
		return v._elapsed

	func intro_done() -> bool:
		return t() >= XSkin2C.intro_len(boss, motion)

	## 进场段的进度：full＝全部档下的 (a, b)；简化档整体 0.2 秒淡入；关档恒 1
	func p(a: float, b: float) -> float:
		if motion == XUiSkin.Motion.OFF:
			return 1.0
		if motion == XUiSkin.Motion.SIMPLE:
			return XSkin2C.seg(t(), 0.0, XSkin2C.SIMPLE_INTRO)
		return XSkin2C.seg(t(), a, b)

	func _process(_dt: float) -> void:
		_refresh_hints()
		var dim := 0.2 if detail else 1.0
		back.modulate.a = dim
		sprites.modulate.a = dim
		base.queue_redraw()
		back.queue_redraw()
		sprites.queue_redraw()
		front.queue_redraw()

	func _refresh_hints() -> void:
		var arr := []
		if not v._drops.is_empty():
			arr.append(["↑", "收起" if detail else "看全部掉落"])
		var verb := "跳过" if not v._ready_to_close else ("马上继续" if v.automatic else "继续")
		arr.append(["确定", verb])
		var key := str(arr)
		if key == _hint_key:
			return
		_hint_key = key
		hints.set_hints(arr)
		hints.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 点击由结算页 _input 统一判（「↑」不是能发的键）
		hints.position = Vector2(view.x - 56.0 - hints.total_width(), view.y - 36.0 - hints.height())

	# ---- 输入（结算页 _input 先交给这里；返回 true＝吃掉） ----

	func handle(event: InputEvent) -> bool:
		var pt := Vector2.INF
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			pt = event.position   # 触屏靠系统把点按模拟成鼠标（同旧页只认鼠标），不另认 ScreenTouch，免得一下按两次
		if detail:
			return _handle_detail(event, pt)
		if event.is_action_pressed("ui_up", true) and not v._drops.is_empty():
			open_detail(true)
			return true
		if event.is_action_pressed("ui_down", true):
			return true
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			return true
		if pt != Vector2.INF and event.pressed:
			var h: Array = hints.hit(pt - hints.position)
			if int(h[0]) >= 0 and str(hints.hints[int(h[0])][0]) == "↑":
				open_detail(true)
				return true
		return false

	func _detail_rect() -> Rect2:
		return Rect2(XSkin2C.DETAIL.position + Vector2(ox, 0), XSkin2C.DETAIL.size)

	func _handle_detail(event: InputEvent, pt: Vector2) -> bool:
		var mx := XSkin2C.detail_scroll_max(v)
		if event.is_action_pressed("ui_cancel"):
			open_detail(false)
			return true
		if event.is_action_pressed("ui_down", true):
			v._drop_top = clampi(v._drop_top + 1, 0, mx)
			return true
		if event.is_action_pressed("ui_up", true):
			if v._drop_top > 0:
				v._drop_top -= 1
			else:
				open_detail(false)
			return true
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			v._drop_top = clampi(v._drop_top + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, mx)
			return true
		if event is InputEventMouseMotion:
			if not _drag.is_empty():
				var dy: float = event.position.y - float(_drag.y)
				if absf(dy) > XSkin2C.DRAG_SLOP:
					_drag.moved = true
				if _drag.moved:
					v._drop_top = clampi(int(_drag.top) - roundi(dy / XSkin2C.DETAIL_DROP_ROW), 0, mx)
				return true
			return false
		if pt == Vector2.INF:
			return false
		if event.pressed:
			var h: Array = hints.hit(pt - hints.position)
			if int(h[0]) >= 0:
				if str(hints.hints[int(h[0])][0]) == "↑":
					open_detail(false)
				else:
					v._confirm()
				return true
			if _detail_rect().has_point(pt):
				_drag = {"y": pt.y, "top": v._drop_top, "moved": false}
			else:
				open_detail(false)
			return true
		# 松手：没拖动才算点了一下（＝继续）
		var was := _drag
		_drag = {}
		if not was.is_empty() and not bool(was.moved):
			v._confirm()
		return true

	func open_detail(on: bool) -> void:
		detail = on
		_drag = {}
		if on:
			v._drop_top = 0
		_refresh_hints()

	# ---- 画 ----

	func _paint_back(c: Control) -> void:
		var shake := Vector2.ZERO
		var fx := _flash_state()
		if fx.shake > 0.0:
			shake = Vector2(sin(t() * 90.0), cos(t() * 70.0)) * 2.0 * fx.shake
		var title_shake := Vector2.ZERO
		if boss and motion == XUiSkin.Motion.FULL:
			var ts := XSkin2C.seg(t(), 0.34, 0.42)
			if ts > 0.0 and ts < 1.0:
				title_shake = Vector2(0, 3.0 * sin(ts * PI * 3.0))
		_off = shake + title_shake
		c.draw_set_transform(_off)
		var fade := p(0.0, 0.12)
		# 大七印环
		var ctr := XSkin2C.RING_C + Vector2(ox, 0)
		var circle := XUiSkin.circle_texture()
		if circle != null:
			var d := XSkin2C.RING_R * 2.0 - 40.0
			var ca := lerpf(0.12, 0.5, p(0.45, 1.0)) * fade
			c.draw_texture_rect(circle, Rect2(ctr - Vector2(d, d) / 2.0, Vector2(d, d)), false, Color(1, 1, 1, ca))
		c.draw_arc(ctr, XSkin2C.RING_R + 7.0, 0, TAU, 128, Color(XUiSkin.GOLD, 0.04 * fade), 12.0, true)
		c.draw_arc(ctr, XSkin2C.RING_R + 13.5, 0, TAU, 128, Color(XUiSkin.TEXT_2, 0.2 * fade), 1.0, true)
		c.draw_arc(ctr, XSkin2C.RING_R, 0, TAU, 128, Color(XUiSkin.GOLD, lerpf(0.25, 0.7, p(0.1, 0.45)) * fade), 1.5, true)
		for k in 7:
			var a := deg_to_rad(-90.0 + k * 360.0 / 7.0 + 360.0 / 14.0)
			var sc := ctr + Vector2(cos(a), sin(a)) * XSkin2C.RING_R
			var lit := _seal_lit(k)
			XSkin2C._diamond(c, sc, 9.9, Color("2a2b30", fade))
			XSkin2C._diamond_line(c, sc, 9.9, Color(XUiSkin.TEXT_2, 0.4 * fade))
			if lit > 0.0:
				XSkin2C._glow(c, sc, 24.0, Color(XUiSkin.GOLD_LIGHT, 0.8 * lit * fade))
				XSkin2C._diamond(c, sc, 9.9, Color(XUiSkin.GOLD_LIGHT, lit * fade))
		_paint_title(c)
		_paint_rewards(c)
		_paint_drops(c, fx)
		c.draw_set_transform(_off)

	## 底：先压黑，再换上本线底图＋径向压暗（没选线只压黑）
	func _paint_base(c: Control) -> void:
		var fade := p(0.0, 0.12)
		c.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, fade))
		if _bg != null:
			c.draw_texture_rect(_bg, Rect2(Vector2.ZERO, view), false, Color(1, 1, 1, fade))
		_vignette(c, fade)

	func _vignette(c: Control, a: float) -> void:
		# 径向压暗：中间黑 50%、四周 90%（同心椭圆环叠）
		var ctr := view / 2.0
		var rx := view.x * 0.6
		var ry := view.y * 0.7
		c.draw_rect(Rect2(Vector2.ZERO, view), Color(0.02, 0.02, 0.024, 0.5 * a))
		var n := 10
		for i in n:
			var k := float(i + 1) / n
			var pts := PackedVector2Array()
			var outer := PackedVector2Array()
			for s in 33:
				var ang := TAU * s / 32.0
				pts.append(ctr + Vector2(cos(ang) * rx * (k - 1.0 / n), sin(ang) * ry * (k - 1.0 / n)))
			var al := (0.8 / n) * k * a
			for s in 33:
				var ang := TAU * s / 32.0
				outer.append(ctr + Vector2(cos(ang) * rx * k, sin(ang) * ry * k))
			for s in 32:
				c.draw_colored_polygon(PackedVector2Array([pts[s], outer[s], outer[s + 1], pts[s + 1]]), Color(0.02, 0.02, 0.024, al))
		# 椭圆以外的角落：再压到约 90%
		var far := PackedVector2Array()
		for s in 33:
			var ang := TAU * s / 32.0
			far.append(ctr + Vector2(cos(ang) * rx, sin(ang) * ry))
		var big := maxf(view.x, view.y) * 2.0
		for s in 32:
			var ang0 := TAU * s / 32.0
			var ang1 := TAU * (s + 1) / 32.0
			c.draw_colored_polygon(PackedVector2Array([far[s], ctr + Vector2(cos(ang0), sin(ang0)) * big, ctr + Vector2(cos(ang1), sin(ang1)) * big, far[s + 1]]), Color(0.02, 0.02, 0.024, 0.8 * a))

	## 第 k 颗印亮了多少：首领战 0.10 起每颗 0.05 顺时针；小怪战 0.10～0.30 一起亮；简化／关直接亮
	func _seal_lit(k: int) -> float:
		if motion != XUiSkin.Motion.FULL:
			return p(0.0, 0.12)
		if boss:
			return XSkin2C.seg(t(), 0.10 + k * 0.05, 0.15 + k * 0.05)
		return XSkin2C.seg(t(), 0.10, 0.30)

	func _paint_title(c: Control) -> void:
		var f := XSkin2C.serif()
		var fs := 80
		var s := "战斗胜利"
		var w := XSkin2C._tw(s, fs, f) - 22.0   # 末字后面的字距不算
		var cx := 640.0 + ox
		var top := 22.0
		var base := top + (96.0 - (f.get_ascent(fs) + f.get_descent(fs))) / 2.0 + f.get_ascent(fs)
		var a := 1.0
		var sc := 1.0
		if motion == XUiSkin.Motion.FULL:
			if boss:
				var q := XSkin2C.seg(t(), 0.18, 0.34)
				a = minf(1.0, q * 3.0)
				sc = lerpf(1.5, 1.0, XSkin2C.ease_out(q))
			else:
				a = XSkin2C.seg(t(), 0.12, 0.30)
		else:
			a = p(0.0, 0.0)
		if a <= 0.0:
			return
		var ctr := Vector2(cx, top + 48.0)
		c.draw_set_transform(_off + ctr - ctr * sc, 0.0, Vector2(sc, sc))
		var x0 := cx - w / 2.0
		c.draw_string(f, Vector2(x0, base + 4.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * a))
		XSkin2C._glow(c, ctr, 230.0, Color(XUiSkin.GOLD, 0.16 * a))
		XUiSkin.ds(c, f, Vector2(x0, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(XUiSkin.TEXT_HI, a))
		c.draw_set_transform(_off)
		# 标题下一道金线、右上的金蜡
		var la := p(0.30, 0.40) if boss else p(0.12, 0.30)
		XSkin2C._fade_line(c, cx - 220.0, cx + 220.0, 122.0, 2.0, Color(XUiSkin.GOLD, la))
		_paint_wax(c)

	func _paint_wax(c: Control) -> void:
		var wc := Vector2(884.0 + ox + 48.0, 30.0 + 48.0)
		var a := 1.0
		var sc := 1.0
		var burst := -1.0
		if boss and motion != XUiSkin.Motion.OFF:
			var t0 := 0.34 if motion == XUiSkin.Motion.FULL else XSkin2C.SIMPLE_SEAL
			var q := XSkin2C.seg(t(), t0, t0 + 0.12)
			if q <= 0.0:
				return
			a = minf(1.0, q * 2.0)
			sc = lerpf(1.3, 1.0, XSkin2C.ease_out(q))
			if motion == XUiSkin.Motion.FULL:
				burst = XSkin2C.seg(t(), t0 + 0.12, t0 + 0.42)
		elif not boss:
			a = XSkin2C.seg(t(), 0.12, 0.30) if motion == XUiSkin.Motion.FULL else p(0.0, 0.0)
		if a <= 0.0:
			return
		if burst > 0.0 and burst < 1.0:
			c.draw_arc(wc, 48.0 + burst * 60.0, 0, TAU, 64, Color(XUiSkin.GOLD_LIGHT, 0.9 * (1.0 - burst)), 3.0, true)
			XSkin2C._glow(c, wc, 90.0 + burst * 40.0, Color(XUiSkin.GOLD_LIGHT, 0.5 * (1.0 - burst)))
		c.draw_set_transform(_off + wc, deg_to_rad(-10.0), Vector2(sc, sc))
		XSkin2C.draw_wax(c, Vector2.ZERO, 96.0, a)
		c.draw_set_transform(_off)

	func _paint_rewards(c: Control) -> void:
		var a := p(0.30, 0.40)
		if a <= 0.0:
			return
		var roll := 1.0 if motion == XUiSkin.Motion.OFF else XSkin2C.ease_out(XSkin2C.seg(t(), 0.30, 0.70))
		var gold := roundi(float(v.rewards.get("gold", 0)) * roll)
		var exp := roundi(float(v.rewards.get("exp", 0)) * roll)
		var cap_fs := XUiSkin.fs(17)
		var f := XSkin2C._f()
		XSkin2C._text(c, 56.0, 286.0, str(XDB.system().currencyUnit), cap_fs, Color(XUiSkin.TEXT_2, a))
		XSkin2C._text(c, 56.0, 286.0 + 22.0, "+" + XMenu._group(gold), 44, Color(XUiSkin.GOLD_LIGHT, a))
		var rx := view.x - 56.0
		var cap := str(XDB.system().terms.basic[8])
		XSkin2C._text(c, rx - 400.0, 286.0, cap, cap_fs, Color(XUiSkin.TEXT_2, a), HORIZONTAL_ALIGNMENT_RIGHT, 400.0)
		XSkin2C._text(c, rx - 400.0, 286.0 + 22.0, "+" + XMenu._group(exp), 44, Color(XUiSkin.GOLD_LIGHT, a), HORIZONTAL_ALIGNMENT_RIGHT, 400.0, f)

	# ---- 掉落排 ----

	## 每枚章的出现：返回 {k: 0..1 弹出进度}；首领战 0.50～0.90 从左到右，大章最后、最好的最后到；小怪战 0.20～0.45 一起
	func _drop_times() -> Array:
		var order := []
		for e in _row.small:
			order.append(e)
		var bigs: Array = _row.big.duplicate()
		bigs.reverse()   # 摆位是高档在左；出场最好的最后
		for e in bigs:
			order.append(e)
		return order

	func _pop(i: int, n: int) -> float:
		if motion != XUiSkin.Motion.FULL:
			return p(0.0, 0.0)
		if not boss:
			return XSkin2C.seg(t(), 0.20, 0.32)
		var start := 0.50 + (0.28 * i / maxf(n - 1, 1))
		return XSkin2C.seg(t(), start, start + 0.12)

	## 爆光：首领战是档最高那枚大章（史诗以上）到位那一刻；小怪战只有传说以上才有；简化／关没有。shake＝震 2 像素的强度
	func _flash_state() -> Dictionary:
		var out := {"k": -1.0, "shake": 0.0, "drop": null}
		if motion != XUiSkin.Motion.FULL or _row.big.is_empty():
			return out
		var top: Array = _row.big[0]
		var g := XSkin2C.drop_grade(top[0])
		if not boss and g < 4:
			return out
		var arrive := 0.90 if boss else 0.32
		var q := XSkin2C.seg(t(), arrive, arrive + 0.35)
		if q <= 0.0 or q >= 1.0:
			return out
		out.k = q
		out.drop = top[0]
		if boss and g >= 4:
			out.shake = maxf(0.0, 1.0 - q * 4.0)
		return out

	func _paint_drops(c: Control, fx: Dictionary) -> void:
		if v._drops.is_empty():
			return
		var a := p(0.45, 0.55) if boss else p(0.18, 0.25)
		# 底下一层暗渐变：y 500 → 600 到黑 88%
		c.draw_polygon(PackedVector2Array([Vector2(0, 500), Vector2(view.x, 500), Vector2(view.x, 600), Vector2(0, 600)]),
			PackedColorArray([Color(0.02, 0.02, 0.024, 0), Color(0.02, 0.02, 0.024, 0), Color(0.02, 0.02, 0.024, 0.88), Color(0.02, 0.02, 0.024, 0.88)]))
		c.draw_rect(Rect2(0, 600, view.x, view.y - 600), Color(0.02, 0.02, 0.024, 0.88))
		if a <= 0.0:
			return
		var title := "获得物品"
		var cnt := "%d 样" % v._drops.size()
		var tf := XUiSkin.fs(17)
		var cf := XUiSkin.fs(15)
		var tw := XSkin2C._tw(title, tf) + 10.0 + XSkin2C._tw(cnt, cf)
		var tx := view.x / 2.0 - tw / 2.0
		XSkin2C._text(c, tx, 536.0 - 4.0, title, tf, Color(XUiSkin.GOLD, a))
		XSkin2C._text(c, tx + XSkin2C._tw(title, tf) + 10.0, 536.0 - 2.0, cnt, cf, Color(XUiSkin.TEXT_2, a))
		var x0 := view.x / 2.0 - float(_row.width) / 2.0
		var order := _drop_times()
		var times := {}
		for i in order.size():
			times[order[i]] = _pop(i, order.size())
		for e in _row.big:
			_big_medal(c, e[0], Vector2(x0 + float(e[1]), XSkin2C.DROP_ROW_Y + XSkin2C.BIG_D / 2.0), float(times.get(e, 1.0)), fx)
		if float(_row.sep) >= 0.0:
			c.draw_rect(Rect2(x0 + float(_row.sep), XSkin2C.DROP_ROW_Y + 4.0, 1, 64), Color(XUiSkin.TEXT_2, 0.3 * a))
		for e in _row.small:
			_small_medal(c, e[0], Vector2(x0 + float(e[1]), XSkin2C.DROP_ROW_Y + 12.0 + XSkin2C.SMALL_D / 2.0), float(times.get(e, 1.0)))
		if int(_row.more) > 0:
			var mw := XSkin2C.more_w(int(_row.more))
			var r := Rect2(x0 + float(_row.more_x), XSkin2C.DROP_ROW_Y + 22.0, mw, 26.0)
			XSkin2C._pill(c, r, Color(XUiSkin.BG, 0.85 * a), Color(XUiSkin.LINE, 0.8 * a))
			XSkin2C._text(c, r.position.x, r.position.y + (26.0 - cf * 1.25) / 2.0, XSkin2C.more_text(int(_row.more)), cf, Color(XUiSkin.TEXT, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

	func _medal_bg(c: Control, ctr: Vector2, r: float, a: float) -> void:
		c.draw_circle(ctr, r, Color("121315", a))
		c.draw_circle(ctr + Vector2(-0.15, -0.2) * r, r * 0.62, Color("2c2d32", 0.7 * a))

	func _big_medal(c: Control, d: Dictionary, ctr: Vector2, k: float, fx: Dictionary) -> void:
		if k <= 0.0:
			return
		var sc := _pop_scale(k)
		var col := XSkin2C.drop_color(d)
		var rec := XSkin2C.drop_rec(d)
		var flash: bool = fx.drop == d and float(fx.k) >= 0.0
		if flash:
			# 乙的爆光：背后一团品质色放射光
			var q := float(fx.k)
			for i in 18:
				var ang := TAU * i / 18.0 + q * 0.6
				var p0 := ctr + Vector2(cos(ang), sin(ang)) * 30.0
				var p1 := ctr + Vector2(cos(ang - 0.08), sin(ang - 0.08)) * 120.0
				var p2 := ctr + Vector2(cos(ang + 0.08), sin(ang + 0.08)) * 120.0
				c.draw_colored_polygon(PackedVector2Array([p0, p1, p2]), Color(col, 0.45 * (1.0 - q)))
		c.draw_set_transform(_off + ctr - ctr * sc, 0.0, Vector2(sc, sc))
		XSkin2C._glow(c, ctr, XSkin2C.BIG_D / 2.0 + 22.0, Color(col, 0.55 * minf(k * 2.0, 1.0)))
		_medal_bg(c, ctr, XSkin2C.BIG_D / 2.0, 1.0)
		c.draw_arc(ctr, XSkin2C.BIG_D / 2.0, 0, TAU, 64, col, 2.0, true)
		var ic := XUiSkin.icon(int(rec.get("iconIndex", 0)))
		if ic != null:
			c.draw_texture_rect(ic, Rect2(ctr - Vector2(24, 24), Vector2(48, 48)), false)
		if flash:
			c.draw_circle(ctr, XSkin2C.BIG_D / 2.0, Color(1, 1, 1, 0.85 * (1.0 - float(fx.k))))
		c.draw_set_transform(_off)
		var nm := XSkin2C.fit(XQuality.list_name(rec) if rec.has("name") else "?", XUiSkin.fs(15), XSkin2C.BIG_CELL - 8.0)
		XSkin2C._text(c, ctr.x - XSkin2C.BIG_CELL / 2.0, ctr.y + XSkin2C.BIG_D / 2.0 + 4.0, nm, XUiSkin.fs(15), Color(col, minf(k * 2.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, XSkin2C.BIG_CELL)

	func _small_medal(c: Control, d: Dictionary, ctr: Vector2, k: float) -> void:
		if k <= 0.0:
			return
		var sc := _pop_scale(k)
		var col := XSkin2C.drop_color(d)
		var rec := XSkin2C.drop_rec(d)
		c.draw_set_transform(_off + ctr - ctr * sc, 0.0, Vector2(sc, sc))
		_medal_bg(c, ctr, XSkin2C.SMALL_D / 2.0, 1.0)
		c.draw_arc(ctr, XSkin2C.SMALL_D / 2.0, 0, TAU, 48, Color(col, 0.6), 1.5, true)
		var ic := XUiSkin.icon(int(rec.get("iconIndex", 0)))
		if ic != null:
			c.draw_texture_rect(ic, Rect2(ctr - Vector2(16, 16), Vector2(32, 32)), false)
		c.draw_set_transform(_off)
		XSkin2C._text(c, ctr.x - XSkin2C.SMALL_CELL / 2.0, ctr.y + XSkin2C.SMALL_D / 2.0 + 2.0, "×%s" % XMenu._group(int(d.count)), XUiSkin.fs(15), Color(XUiSkin.TEXT_2, minf(k * 2.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, XSkin2C.SMALL_CELL)

	func _pop_scale(k: float) -> float:
		# 弹出：0 → 1.15 → 1
		return 1.15 * XSkin2C.ease_out(k / 0.7) if k < 0.7 else lerpf(1.15, 1.0, (k - 0.7) / 0.3)

	# ---- 小人 ----

	func cell_w() -> float:
		return XSkin2C.CELL_W5 if v.rows.size() >= 5 else XSkin2C.CELL_W

	func cell_x(i: int) -> float:
		return 640.0 + ox - v.rows.size() * cell_w() / 2.0 + i * cell_w()

	## 小人这一格的出现（透明度、上抬）
	func _actor_anim(i: int) -> Vector2:
		if motion != XUiSkin.Motion.FULL:
			return Vector2(p(0.0, 0.0), 0.0)
		if not boss:
			return Vector2(XSkin2C.seg(t(), 0.12, 0.30), 0.0)
		var n := v.rows.size()
		var start := 0.30 + (0.18 * i / maxf(n - 1, 1))
		var q := XSkin2C.seg(t(), start, start + 0.12)
		return Vector2(minf(1.0, XSkin2C.seg(t(), 0.24, 0.32) + q), -14.0 * sin(PI * q) if q > 0.0 and q < 1.0 else 0.0)

	func _paint_sprites(c: Control) -> void:
		for i in v.rows.size():
			var row: Dictionary = v.rows[i]
			var an := _actor_anim(i)
			if an.x <= 0.0:
				continue
			var cx := cell_x(i) + cell_w() / 2.0
			var feet := XSkin2C.FEET_Y + an.y
			if row.notified:
				XSkin2C._glow(c, Vector2(cx, XSkin2C.FEET_Y + 6.0), 64.0, Color(XUiSkin.GOLD_LIGHT, 0.55 * an.x))
			else:
				_ellipse(c, Vector2(cx, XSkin2C.FEET_Y + 6.0), Vector2(50, 11), Color(0, 0, 0, 0.55 * an.x))
			var sv: Dictionary = _sv.get(row.actor, {})
			if sv.has("tex"):
				var src: Rect2 = sv.src
				var size := src.size * float(sv.scale)
				c.draw_texture_rect_region(sv.tex, Rect2(Vector2(cx - size.x / 2.0, feet - size.y), size), src, Color(1, 1, 1, an.x))
			elif sv.get("face") != null:
				var ctr := Vector2(cx, feet - 48.0 - 30.0)
				c.draw_circle(ctr, 50.0, Color(0, 0, 0, 0.5 * an.x))
				XSkinPartyStrip.draw_round_texture(c, sv.face, ctr, 48.0)
				c.draw_arc(ctr, 48.0, 0, TAU, 48, Color(XUiSkin.GOLD, 0.7 * an.x), 1.5, true)

	func _ellipse(c: Control, ctr: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for s in 24:
			var ang := TAU * s / 24.0
			pts.append(ctr + Vector2(cos(ang) * r.x, sin(ang) * r.y))
		c.draw_colored_polygon(pts, col)

	# ---- 前层：名字、经验条、升级小标、提示、详单 ----

	func _paint_front(c: Control) -> void:
		var dim := 0.2 if detail else 1.0
		for i in v.rows.size():
			_paint_cell_text(c, i, dim)
		if v.automatic:
			_paint_auto(c)
		if detail:
			_paint_detail(c)

	func _paint_cell_text(c: Control, i: int, dim: float) -> void:
		var row: Dictionary = v.rows[i]
		var an := _actor_anim(i)
		var a := an.x * dim
		if a <= 0.0:
			return
		var a2: XActor = row.actor
		var x := cell_x(i)
		var w := cell_w()
		var fs := XUiSkin.fs(19)
		var lv := "Lv %s" % XMenu._group(int(row.display_level))
		var lvw := XSkin2C._tw(lv, fs)
		var tag := "助力" if row.get("helper", false) else ""
		var tagw := (XSkin2C._tw(tag, XUiSkin.fs(15)) + 6.0) if tag != "" else 0.0
		var room := w - 28.0 - lvw - 8.0
		# 名字后放不下「助力」（名字至少要留两个字）时，小标挪到经验条下面左边
		var tag_below := tag != "" and room - tagw < XSkin2C._tw(a2.display_name().left(2) + "…", fs)
		var nm := XSkin2C.fit(a2.display_name(), fs, room - (0.0 if tag_below else tagw))
		XSkin2C._text(c, x + 14.0, 406.0 - 4.0, nm, fs, Color(XUiSkin.TEXT, a))
		if tag != "":
			var tp := Vector2(x + 14.0, 448.0) if tag_below else Vector2(x + 14.0 + XSkin2C._tw(nm, fs) + 6.0, 406.0)
			XSkin2C._text(c, tp.x, tp.y, tag, XUiSkin.fs(15), Color(XUiSkin.TEXT_2, a))
		XSkin2C._text(c, x + 14.0, 406.0 - 4.0, lv, fs, Color(XUiSkin.TEXT_2, a), HORIZONTAL_ALIGNMENT_RIGHT, w - 28.0)
		var maxed := int(row.display_level) >= a2.max_level()
		var bar := Rect2(x + 14.0, 436.0, w - 28.0, 8.0)
		XSkin2C._pill(c, bar, Color(1, 1, 1, 0.14 * a))
		var rate := 1.0 if maxed else clampf(float(row.rate), 0.0, 1.0)
		if rate > 0.0:
			var fw := maxf(8.0, bar.size.x * rate)
			var fa := 0.45 if maxed else 1.0
			var r := Rect2(bar.position, Vector2(fw, 8.0))
			c.draw_polygon(PackedVector2Array([r.position + Vector2(2, 0), Vector2(r.end.x - 2, r.position.y), Vector2(r.end.x - 2, r.end.y), Vector2(r.position.x + 2, r.end.y)]),
				PackedColorArray([Color("b8914d", fa * a), Color(XUiSkin.GOLD_LIGHT, fa * a), Color(XUiSkin.GOLD_LIGHT, fa * a), Color("b8914d", fa * a)]))
			c.draw_circle(r.position + Vector2(4, 4), 4.0, Color("b8914d", fa * a))
			c.draw_circle(Vector2(r.end.x - 4, r.position.y + 4), 4.0, Color(XUiSkin.GOLD_LIGHT, fa * a))
		if maxed:
			XSkin2C._text(c, x + 14.0, 448.0, "已满级", XUiSkin.fs(15), Color(XUiSkin.TEXT_3, a), HORIZONTAL_ALIGNMENT_RIGHT if tag_below else HORIZONTAL_ALIGNMENT_CENTER, w - 28.0)
		if row.notified:
			_level_badge(c, row, Vector2(x + w / 2.0, CELL_BADGE_Y), a)

	const CELL_BADGE_Y := 210.0

	## 头顶「等级提升　Lv 6 ▸ 7」（不闪；一次升好几级写起止）
	func _level_badge(c: Control, row: Dictionary, ctr: Vector2, a: float) -> void:
		var from := int(v.snapshots[row.actor].level)
		var to := int(row.display_level)
		var fs := XUiSkin.fs(15)
		var head := "等级提升　Lv %d ▸ " % from
		var tail := str(to)
		var w := XSkin2C._tw(head, fs) + XSkin2C._tw(tail, fs) + 24.0
		var r := Rect2(ctr.x - w / 2.0, ctr.y - 12.0, w, 24.0)
		XSkin2C._pill(c, r, Color(0.06, 0.05, 0.03, 0.88 * a), Color(XUiSkin.GOLD, 0.9 * a))
		XSkin2C._text(c, r.position.x + 12.0, r.position.y + (24.0 - fs * 1.25) / 2.0, head, fs, Color(XUiSkin.GOLD, a))
		XSkin2C._text(c, r.position.x + 12.0 + XSkin2C._tw(head, fs), r.position.y + (24.0 - fs * 1.25) / 2.0, tail, fs, Color(XUiSkin.GOLD_LIGHT, a))

	## 自动战斗：提示左边「自动战斗 · 自动继续」，下面一条 3.4 秒走完的细金线
	func _paint_auto(c: Control) -> void:
		var fs := XUiSkin.fs(15)
		var s := "自动战斗 · 自动继续"
		var right := hints.position.x - 16.0
		var y := hints.position.y + (hints.height() - fs * 1.25) / 2.0 - 3.0
		XSkin2C._text(c, right - 400.0, y, s, fs, XUiSkin.TEXT_2, HORIZONTAL_ALIGNMENT_RIGHT, 400.0)
		var lr := Rect2(right - 168.0, y + fs * 1.25 + 2.0, 168.0, 3.0)
		c.draw_rect(lr, Color(XUiSkin.GOLD, 0.2))
		c.draw_rect(Rect2(lr.position, Vector2(lr.size.x * clampf(t() / XSkin2C.AUTO_CLOSE, 0.0, 1.0), 3.0)), XUiSkin.GOLD)

	func _paint_detail(c: Control) -> void:
		var pr := _detail_rect()
		XUiSkin.draw_panel(c.get_canvas_item(), pr)
		var x := pr.position.x + 24.0
		var w := pr.size.x - 48.0
		var y := pr.position.y + 16.0
		XSkin2C._text(c, x, y, "队伍", XUiSkin.fs(17), XUiSkin.GOLD)
		y = pr.position.y + 52.0
		for row in v.rows:
			_detail_actor(c, row, Rect2(x, y, w, XSkin2C.DETAIL_ROW))
			y += XSkin2C.DETAIL_ROW
		y += 12.0
		XSkin2C._text(c, x, y, "获得物品", XUiSkin.fs(17), XUiSkin.GOLD)
		XSkin2C._text(c, x + XSkin2C._tw("获得物品", XUiSkin.fs(17)) + 10.0, y + 2.0, "%d 样" % v._drops.size(), XUiSkin.fs(15), XUiSkin.TEXT_2)
		y += 32.0
		var n := XSkin2C.detail_rows(v.rows.size())
		var total := v._drops.size()
		var top := clampi(v._drop_top, 0, XSkin2C.detail_scroll_max(v))
		var more := total - (top + n)
		for k in n:
			var i := top + k
			if i >= total:
				break
			var r := Rect2(x, y + k * XSkin2C.DETAIL_DROP_ROW, w - 14.0, XSkin2C.DETAIL_DROP_ROW)
			if k == n - 1 and more > 0:
				XSkin2C._text(c, r.position.x, r.position.y + 8.0, "还有 %d 样 ▾" % (more + 1), XUiSkin.fs(15), XUiSkin.TEXT_2, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
				break
			_detail_drop(c, v._drops[i], r)
		if total > n:
			var track := Rect2(pr.end.x - 24.0 + 6.0, y, 6.0, n * XSkin2C.DETAIL_DROP_ROW)
			XSkin2C._pill(c, track, Color(1, 1, 1, 0.08))
			var hh := maxf(24.0, track.size.y * n / total)
			var ty := track.position.y + (track.size.y - hh) * (float(top) / maxf(XSkin2C.detail_scroll_max(v), 1))
			XSkin2C._pill(c, Rect2(track.position.x, ty, 6.0, hh), Color(XUiSkin.GOLD, 0.7))

	func _detail_actor(c: Control, row: Dictionary, r: Rect2) -> void:
		var a: XActor = row.actor
		if row.notified:
			c.draw_rect(Rect2(r.position + Vector2(-8, 2), r.size + Vector2(16, -4)), Color(XUiSkin.GOLD, 0.1))
		var face: Texture2D = XUiSkin.face(str(a.data().get("faceName", "")), int(a.data().get("faceIndex", 0)))
		var fc := r.position + Vector2(16, r.size.y / 2.0)
		if face != null:
			XSkinPartyStrip.draw_round_texture(c, face, fc, 16.0)
		c.draw_arc(fc, 16.0, 0, TAU, 32, Color(XUiSkin.LINE, 0.6), 1.0, true)
		var fs := XUiSkin.fs(19)
		var ty := r.position.y + (r.size.y - fs * 1.25) / 2.0
		var nx := r.position.x + 44.0
		var nm := XSkin2C.fit(a.display_name(), fs, 150.0)
		XSkin2C._text(c, nx, ty, nm, fs, XUiSkin.TEXT)
		var tx := nx + XSkin2C._tw(nm, fs) + 6.0
		if row.get("helper", false):
			XSkin2C._text(c, tx, ty + 3.0, "助力", XUiSkin.fs(15), XUiSkin.TEXT_2)
		XSkin2C._text(c, nx + 190.0, ty, "Lv %s" % XMenu._group(int(row.display_level)), fs, XUiSkin.TEXT_2)
		if row.notified:
			var lf := XUiSkin.fs(15)
			var lr := Rect2(nx + 256.0, r.position.y + (r.size.y - 22.0) / 2.0, XSkin2C._tw("等级提升", lf) + 16.0, 22.0)
			XSkin2C._pill(c, lr, Color(0.06, 0.05, 0.03, 0.88), Color(XUiSkin.GOLD, 0.9))
			XSkin2C._text(c, lr.position.x, lr.position.y + (22.0 - lf * 1.25) / 2.0, "等级提升", lf, XUiSkin.GOLD, HORIZONTAL_ALIGNMENT_CENTER, lr.size.x)
		var bx := r.position.x + 400.0
		var bw := 100.0
		var maxed := int(row.display_level) >= a.max_level()
		XSkin2C._pill(c, Rect2(bx, r.position.y + r.size.y / 2.0 - 4.0, bw, 8.0), Color(1, 1, 1, 0.14))
		var rate := 1.0 if maxed else clampf(float(row.rate), 0.0, 1.0)
		if rate > 0.0:
			XSkin2C._pill(c, Rect2(bx, r.position.y + r.size.y / 2.0 - 4.0, maxf(8.0, bw * rate), 8.0), Color(XUiSkin.GOLD_LIGHT, 0.45 if maxed else 0.9))
		var nf := XUiSkin.fs(15)
		var right := r.end.x
		if maxed:
			XSkin2C._text(c, right - 140.0, ty + 3.0, "已满级", nf, XUiSkin.TEXT_3, HORIZONTAL_ALIGNMENT_RIGHT, 140.0)
		else:
			var lv := int(row.display_level)
			var base := a.exp_for_level(lv)
			var tail := " / " + XMenu._group(a.exp_for_level(lv + 1) - base)
			var cur := XMenu._group(int(row.exp) - base)
			XSkin2C._text(c, right - 140.0, ty + 3.0, tail, nf, XUiSkin.TEXT_2, HORIZONTAL_ALIGNMENT_RIGHT, 140.0)
			XSkin2C._text(c, right - 140.0 - XSkin2C._tw(tail, nf), ty + 3.0, cur, nf, XUiSkin.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 140.0)

	func _detail_drop(c: Control, d: Dictionary, r: Rect2) -> void:
		var rec := XSkin2C.drop_rec(d)
		var g := XSkin2C.drop_grade(d)
		var col := XSkin2C.drop_color(d)
		var x := r.position.x
		if g >= 3:
			c.draw_rect(Rect2(x - 8.0, r.position.y + 6.0, 3.0, r.size.y - 12.0), col)
		var ic := XUiSkin.icon(int(rec.get("iconIndex", 0)))
		if ic != null:
			c.draw_texture_rect(ic, Rect2(x, r.position.y + 4.0, 32, 32), false)
		x += 42.0
		var fs := XUiSkin.fs(19)
		var ty := r.position.y + (r.size.y - fs * 1.25) / 2.0
		if g >= 3:
			for k in (g - 2):
				XSkin2C._diamond(c, Vector2(x + 4.0, r.position.y + r.size.y / 2.0), 4.0, col)
				x += 10.0
			x += 4.0
		var cnt := "×%s" % XMenu._group(int(d.count))
		var cw := XSkin2C._tw(cnt, fs)
		XSkin2C._text(c, x, ty, XSkin2C.fit(XQuality.list_name(rec) if rec.has("name") else "?", fs, r.end.x - x - cw - 16.0), fs, XGear.color(rec))
		XSkin2C._text(c, r.position.x, ty, cnt, fs, XUiSkin.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x)


## ---- 全灭：灭印 ----

const GO_INTRO_FULL := 60      # 1.0 秒（按 60 帧）
const GO_INTRO_SIMPLE := 24    # 0.4 秒淡入
const GO_HINT_DELAY := 12      # NULL 全显后 0.2 秒出提示
const GO_RING_C := Vector2(640, 360)
const GO_RING_R := 250.0


static func gameover_intro_frames() -> int:
	match XUiSkin.motion():
		XUiSkin.Motion.OFF:
			return 0
		XUiSkin.Motion.SIMPLE:
			return GO_INTRO_SIMPLE
	return GO_INTRO_FULL


static func gameover_view(g: XGameOverScreen, shot: Texture2D, summary: Array) -> Control:
	var view := GameOverView.new()
	view.g = g
	view.shot = shot
	view.summary = summary
	view.intro = gameover_intro_frames()
	view.simple = XUiSkin.motion() == XUiSkin.Motion.SIMPLE
	return view


## 全灭 B 版两行：[「第 31 层 · 艰险 · 战争线」, 「倒在【守层者】里德面前」（没有首领为空）]；GAMEOVER_SUMMARY 关、不是天启篇时空数组
static func gameover_summary(s: XState, troop_id: int) -> Array:
	if not GAMEOVER_SUMMARY or s == null:
		return []
	var parts := []
	var fl := XDungeon.boss_floor(s.map_id)
	if fl > 0:
		parts.append("第 %d 层" % fl)
	var diff := XTianqiTrim.difficulty_name(s)
	if diff != "":
		parts.append(diff)
	var line := XTianqiLine.current(s)
	if line != "":
		parts.append(XTianqiRewards.line_name(line))
	if parts.is_empty():
		return []
	var who := ""
	if troop_id > 0:
		for m in XDB.rec("Troops", troop_id).get("members", []):
			var eid := int(m.get("enemyId", 0))
			if eid > 0 and XBossHpBar.is_listed(eid):
				who = str(XDB.rec("Enemies", eid).get("name", ""))
				break
	return [" · ".join(parts), ("倒在%s面前" % who) if who != "" else ""]


const GRAY_SHADER := """
shader_type canvas_item;
uniform float gray = 1.0;
uniform float bright = 1.0;
void fragment() {
	vec4 c = COLOR;   // Godot 4：COLOR 进来已经是贴图×调色
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(l), gray) * bright;
	COLOR = c;
}
"""

const BURN_SHADER := """
shader_type canvas_item;
uniform float radius = 2.0;
uniform float aspect = 1.7778;
void fragment() {
	vec4 c = COLOR;   // Godot 4：COLOR 进来已经是贴图×调色
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float d = length(p);
	float m = 1.0 - smoothstep(radius - 0.08, radius, d);
	float rim = smoothstep(radius - 0.10, radius - 0.03, d) * m;
	c.rgb = mix(c.rgb, vec3(1.0, 0.35, 0.12), rim * 0.55);
	c.a *= m;
	COLOR = c;
}
"""


## 全灭页新画法：去色定住的战场＋七印环一颗颗灭＋NULL 从正中烧开；20:9 字图按 1280×720 居中、两边用边上那一列接出去
class GameOverView extends Control:
	var g: XGameOverScreen
	var shot: Texture2D
	var summary: Array = []
	var intro := 60
	var simple := false
	var frame := 0           # 进场第几帧（灭印）
	var shown_at := -1       # NULL 全显那一帧（提示从这起 0.2 秒淡入）
	var _field: TextureRect
	var _null: TextureRect
	var _edges: Control
	var _top: Control
	var _gray: ShaderMaterial
	var _burn: ShaderMaterial
	var view := Vector2(1280, 720)

	func _ready() -> void:
		name = "Skin2CGameOver"
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		view = get_viewport_rect().size
		_gray = ShaderMaterial.new()
		var gs := Shader.new()
		gs.code = XSkin2C.GRAY_SHADER
		_gray.shader = gs
		_field = TextureRect.new()
		_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_field.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_field.stretch_mode = TextureRect.STRETCH_SCALE
		_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_field.texture = shot
		_field.material = _gray
		add_child(_field)
		var ring := XSkin2C.Layer.new(_paint_ring)
		add_child(ring)
		_edges = XSkin2C.Layer.new(_paint_edges)
		add_child(_edges)
		_burn = ShaderMaterial.new()
		var bs := Shader.new()
		bs.code = XSkin2C.BURN_SHADER
		_burn.shader = bs
		_null = TextureRect.new()
		_null.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_null.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_null.stretch_mode = TextureRect.STRETCH_SCALE
		_null.texture = g._tex.texture
		_null.material = _burn
		var w := minf(view.x, view.y * 16.0 / 9.0)
		_null.position = Vector2((view.x - w) / 2.0, 0)
		_null.size = Vector2(w, view.y)
		add_child(_null)
		_top = XSkin2C.Layer.new(_paint_top)
		add_child(_top)
		apply()

	func shown() -> bool:
		return frame >= intro

	func skip() -> void:
		frame = intro
		shown_at = frame
		apply()

	func advance() -> void:
		if frame < intro:
			frame += 1
		if shown() and shown_at < 0:
			shown_at = frame
		apply()

	func hint_alpha() -> float:
		if not shown():
			return 0.0
		return clampf(float(_since_extra) / XSkin2C.GO_HINT_DELAY, 0.0, 1.0)

	var _since_extra := 0

	## 全显之后提示的 0.2 秒淡入按帧走（step 每帧调）
	func tick_after_shown() -> void:
		if shown():
			_since_extra = mini(_since_extra + 1, XSkin2C.GO_HINT_DELAY)

	func secs() -> float:
		return float(frame) / 60.0

	func apply() -> void:
		var s := secs()
		var full := not simple and intro > 0
		# 战场：0～0.3 去色、压到 38%；0.3～0.7 压到 16%
		if full:
			_gray.set_shader_parameter("gray", XSkin2C.seg(s, 0.0, 0.3))
			var b := lerpf(1.0, 0.38, XSkin2C.seg(s, 0.0, 0.3)) if s < 0.3 else lerpf(0.38, 0.16, XSkin2C.seg(s, 0.3, 0.7))
			_gray.set_shader_parameter("bright", b)
			_field.visible = shot != null
		else:
			_field.visible = false
		# NULL：0.6～1.0 圆形遮罩从 20% 涨到盖满；简化档整张 0.4 秒淡入；关档直接全显
		var aspect := _null.size.x / maxf(_null.size.y, 1.0)
		var cover := sqrt(aspect * aspect / 4.0 + 0.25) + 0.1
		if full:
			var q := XSkin2C.seg(s, 0.6, 1.0)
			_burn.set_shader_parameter("radius", lerpf(0.2 * cover, cover, q) if q > 0.0 else 0.0)
			_null.modulate.a = 1.0 if q > 0.0 else 0.0
		else:
			_burn.set_shader_parameter("radius", cover)
			_null.modulate.a = 1.0 if intro <= 0 else clampf(float(frame) / intro, 0.0, 1.0)
		_burn.set_shader_parameter("aspect", aspect)
		_edges.modulate.a = _null.modulate.a * (XSkin2C.seg(s, 0.85, 1.0) if full else 1.0)
		for n in get_children():
			if n is CanvasItem:
				(n as CanvasItem).queue_redraw()

	func _paint_ring(c: Control) -> void:
		if simple or intro <= 0 or shown():
			return
		var s := secs()
		var a := XSkin2C.seg(s, 0.0, 0.3) * (1.0 - XSkin2C.seg(s, 0.6, 1.0))
		if a <= 0.0:
			return
		var ctr := XSkin2C.GO_RING_C + Vector2((view.x - 1280.0) / 2.0, 0)
		c.draw_arc(ctr, XSkin2C.GO_RING_R, 0, TAU, 128, Color(XUiSkin.GOLD, 0.6 * a), 1.5, true)
		for k in 7:
			var ang := deg_to_rad(-90.0 + k * 360.0 / 7.0)
			var sc := ctr + Vector2(cos(ang), sin(ang)) * XSkin2C.GO_RING_R
			# 0.3 起从最后一颗逆时针一颗颗灭（每颗 0.06）
			var off := 0.3 + (6 - k) * 0.06
			var lit := 1.0 - XSkin2C.seg(s, off, off + 0.06)
			XSkin2C._diamond(c, sc, 11.3, Color("1c1c20", a))
			XSkin2C._diamond_line(c, sc, 11.3, Color(XUiSkin.TEXT_2, 0.3 * a))
			if lit > 0.0:
				XSkin2C._glow(c, sc, 26.0, Color(XUiSkin.GOLD_LIGHT, 0.8 * lit * a))
				XSkin2C._diamond(c, sc, 11.3, Color(XUiSkin.GOLD_LIGHT, lit * a))

	## 20:9：字图左右空出的地方用字图最边上那一列横向接出去
	func _paint_edges(c: Control) -> void:
		var tex := _null.texture
		if tex == null or _null.position.x <= 0.5:
			return
		var ts := tex.get_size()
		var lw := _null.position.x
		c.draw_texture_rect_region(tex, Rect2(0, 0, lw + 1.0, view.y), Rect2(0, 0, 1, ts.y))
		c.draw_texture_rect_region(tex, Rect2(_null.position.x + _null.size.x - 1.0, 0, view.x - _null.position.x - _null.size.x + 1.0, view.y), Rect2(ts.x - 1, 0, 1, ts.y))

	func _paint_top(c: Control) -> void:
		var a := hint_alpha()
		if a <= 0.0:
			return
		var cx := view.x / 2.0
		if summary.size() >= 1 and str(summary[0]) != "":
			var fs := XUiSkin.fs(19)
			var s0 := str(summary[0])
			var w0 := XSkin2C._tw(s0, fs)
			XSkin2C._text(c, cx - 400.0, 468.0, s0, fs, Color(XUiSkin.TEXT_2, a), HORIZONTAL_ALIGNMENT_CENTER, 800.0)
			var ly := 468.0 + fs * 0.65
			for side in [-1.0, 1.0]:
				var x0: float = cx + side * (w0 / 2.0 + 16.0)
				var x1: float = x0 + side * 120.0
				var col := Color(XUiSkin.SEL_FILL, 0.8 * a)
				c.draw_polygon(PackedVector2Array([Vector2(x0, ly), Vector2(x1, ly), Vector2(x1, ly + 1), Vector2(x0, ly + 1)]),
					PackedColorArray([col, Color(col, 0), Color(col, 0), col]))
			if summary.size() >= 2 and str(summary[1]) != "":
				XSkin2C._text(c, cx - 400.0, 502.0, str(summary[1]), XUiSkin.fs(15), Color(XUiSkin.TEXT_3, a), HORIZONTAL_ALIGNMENT_CENTER, 800.0)
		var touch := XSkinKeyHints.touch_mode()
		var fs := XUiSkin.fs(15)
		var key := "点一下" if touch else "确定"
		var desc := "回到标题"
		var kw := XSkin2C._tw(key, fs) + (0.0 if touch else 16.0)
		var w := kw + 8.0 + XSkin2C._tw(desc, fs) + 28.0
		var h := 32.0
		var r := Rect2(cx - w / 2.0, view.y - 56.0 - h, w, h)
		XSkin2C._pill(c, r, Color(0.02, 0.02, 0.024, 0.6 * a), Color(XUiSkin.LINE, 0.6 * a))
		var ty := r.position.y + (h - fs * 1.25) / 2.0
		var x := r.position.x + 14.0
		if touch:
			XSkin2C._text(c, x, ty, key, fs, Color(XUiSkin.TEXT_2, a))
		else:
			XSkin2C._pill(c, Rect2(x - 4.0, r.position.y + 6.0, kw, h - 12.0), Color(0, 0, 0, 0), Color(XUiSkin.TEXT_2, 0.8 * a))
			XSkin2C._text(c, x + 4.0, ty, key, fs, Color(XUiSkin.TEXT, a))
		XSkin2C._text(c, x + kw + 8.0, ty, desc, fs, Color(XUiSkin.TEXT, a))
