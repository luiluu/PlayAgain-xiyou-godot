class_name XSkinSealDial
extends Control
## 【cc·天启篇·未经审查】新界面 2C 卡 B（T267，照 T254 1.3「印盘」、1.4「连击坐进环心」，Kyo D232）：
## 本线计量＋连击合成一只 128×128 的环，左上角在自动／变速圆钮正下方（16:9 x 20、y 142；20:9 跟左安全边距 x 52），
## 环右边挂读数「小签」，别的线一条一枚签挂在下面。
## 只读：计量读 XTianqiMeter（rows、doomed、dial、flash_left），连击读 XComboCounter（shown_hits、hold_frac、num_scale、num_alpha）；
## 计数、读数、0.1 秒刷新、闪 0.6 秒、连击停 90 帧一行不动。
## 开关：XSkin2C.METER（关＝旧计量条；连击仍可用素环）、XSkin2C.COMBO（关＝旧图片数字，接在环下 y 276）、XSkin2C.EDGE_FLASH。

const RING := 128.0
const C := Vector2(64, 64)
const DISC_R := 52.0          # 盘面直径 104（环的外框各让 12）
const ARC_R := 60.0           # 连击金弧
const POS := Vector2(20, 142)
const TAG_X := 130.0
const TAG_H := 30.0
const MAX_DIAMONDS := 14
const LIGHT_UP := 0.12
const HALO := 0.3
const TIER_UP := 0.2
const BADGE := "res://content/tianqi/qiyin/icons/badge_%s.png"

var meter: XTianqiMeter
var combo: XComboCounter
var line := ""                # 本线（玩家这一局选的线）；没选为空
var _now := 0.0
var _lit_at := {}             # 线 → [每颗亮起的时刻]
var _flash_was := {}          # 线 → 上一帧在不在闪
var _halo_at := -9.0          # 环满那一下光环、四边一闪开始的时刻
var _edge_at := -9.0
var _tier := 0
var _tier_at := -9.0
## 测试读：上一帧画了什么
var last := {}
## T273 卡 U：胜利那一刻冻结（freeze 拍快照；之后不读计量、连击，画面停在那一帧）；tag_alpha＝小签淡出
var frozen := {}
var tag_alpha := 1.0

static var _num_font: Font = null
static var _badges := {}


## 卡 B 印盘：计量或连击任一走新画法才建
static func make(m: XTianqiMeter, c: XComboCounter) -> XSkinSealDial:
	if not (XSkin2C.meter_on() or XSkin2C.combo_on()):
		return null
	var d := XSkinSealDial.new()
	d.meter = m
	d.combo = c
	d.line = XTianqiLine.current(XState.current) if XState.current != null else ""
	return d


## 左上角：贴自动／变速那组圆钮的左缘再往左 4（16:9 是 20，20:9 是 52），y 142（战斗画面坐标）
static func place(d: Control, toggles: Control, origin: Vector2) -> void:
	if d == null:
		return
	var x := POS.x
	if toggles != null and is_instance_valid(toggles):
		x = toggles.position.x - 4.0
	d.position = Vector2(x, origin.y + POS.y)


func _ready() -> void:
	name = "SealDial"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(420, RING)
	if combo != null:
		combo.under_dial = true


func _process(dt: float) -> void:
	_now += dt
	queue_redraw()


static func num_font() -> Font:
	if _num_font == null:
		var path: String = XUiSkin.FONT_DIR + str(XUiSkin.FONT_FILES.title)
		var base: Font = load(path) if ResourceLoader.exists(path) else null
		var fv := FontVariation.new()
		fv.base_font = base if base != null else GameFont.current()
		_num_font = fv
	return _num_font


static func badge(key: String) -> Texture2D:
	if not _badges.has(key):
		var p := BADGE % key
		_badges[key] = load(p) if key != "" and ResourceLoader.exists(p) else null
	return _badges[key]


## ---- 冻结（T273 卡 U：战斗→结算衔接） ----

## 胜利那一刻拍快照：计量各线、死期、连击都抄一份，之后照这份画；时间也停（光环、四边一闪、升档那一下不再放）
func freeze() -> void:
	var rows := _rows().duplicate(true)
	var fl := {}
	for r in rows:
		fl[str(r.key)] = _flash(str(r.key))
	var cs := combo_shown()
	frozen = {"rows": rows, "doomed": _doomed().duplicate(), "dial": _dial_info().duplicate(true), "flash": fl,
		"combo": {"shown": cs, "hits": combo.shown_hits if cs else 0, "hold": combo.hold_frac() if cs else 0.0,
			"alpha": combo.num_alpha() if cs else 0.0}}
	_halo_at = -9.0
	_edge_at = -9.0
	_tier_at = -9.0
	set_process(false)
	queue_redraw()


func _doomed() -> Array:
	if not frozen.is_empty():
		return frozen.doomed
	return meter.doomed if meter != null and is_instance_valid(meter) else []


func _dial_info() -> Dictionary:
	if not frozen.is_empty():
		return frozen.dial
	return meter.dial if meter != null and is_instance_valid(meter) else {}


func _c_hits() -> int:
	return int(frozen.combo.hits) if not frozen.is_empty() else combo.shown_hits


func _c_alpha() -> float:
	return float(frozen.combo.alpha) if not frozen.is_empty() else combo.num_alpha()


func _c_hold() -> float:
	return float(frozen.combo.hold) if not frozen.is_empty() else combo.hold_frac()


func _c_scale() -> float:
	return 1.0 if not frozen.is_empty() else combo.num_scale()   # 冻结时砸那一下已经放完


## ---- 读数据 ----

func _rows() -> Array:
	if not frozen.is_empty():
		return frozen.rows
	if meter == null or not is_instance_valid(meter) or not XSkin2C.meter_on():
		return []
	return meter.rows


## 环给哪条线：先本线，再照旧顺序（rows 已按战争、死亡、饥荒、瘟疫排）
func ring_row() -> Dictionary:
	var rs := _rows()
	for r in rs:
		if str(r.key) == line:
			return r
	return rs[0] if not rs.is_empty() else {}


## 签的顺序：环那条线的签在最上，别的线照旧顺序
func tag_rows() -> Array:
	var rr := ring_row()
	if rr.is_empty():
		return []
	var out := [rr]
	for r in _rows():
		if r != rr:
			out.append(r)
	return out


func combo_shown() -> bool:
	if not frozen.is_empty():
		return bool(frozen.combo.shown)
	if combo == null or not is_instance_valid(combo) or not XSkin2C.combo_on():
		return false
	if combo.shown_hits <= 0 or combo.num_alpha() <= 0.0:
		return false
	if XUiSkin.motion() == XUiSkin.Motion.OFF and combo.timer <= 0:
		return false   # 关档：断了直接消失
	return true


## 环上几颗菱形（0＝不放菱形；-1＝上限超过 14 改弧形条）、亮几颗
func diamonds(r: Dictionary) -> Vector2i:
	match str(r.get("key", "")):
		"war", "plague":
			var full := int(r.full)
			return Vector2i(-1 if full > MAX_DIAMONDS else full, clampi(int(r.value), 0, maxi(full, 0)))
		"death":
			var n := int(_dial_info().get("death_slots", 0))
			return Vector2i(n, mini(_doomed().size(), n))
	return Vector2i(0, 0)


func _flash(key: String) -> float:
	if not frozen.is_empty():
		return float(frozen.flash.get(key, 0.0))
	return meter.flash_left(key) if meter != null and is_instance_valid(meter) else 0.0


## ---- 画 ----

func _draw() -> void:
	last = {}
	var rr := ring_row()
	var cs := combo_shown()
	var motion := XUiSkin.motion()
	var full_m := motion == XUiSkin.Motion.FULL
	var ring_a := 1.0
	if rr.is_empty():
		if not cs:
			_tier = 0
			return
		ring_a = _c_alpha()   # 素环跟着连击淡出
	var key := str(rr.get("key", ""))
	var main := XTianqiLook.main_color(key, XUiSkin.GOLD) if key != "" else XUiSkin.GOLD
	var bright := XSkin2C.line_bright(key) if key != "" else XUiSkin.GOLD_LIGHT
	var fl := _flash(key) if key != "" else 0.0
	var started := fl > 0.0 and not bool(_flash_was.get(key, false))
	if key != "":
		_flash_was[key] = fl > 0.0
	if started and full_m:
		_halo_at = _now
		if key == "war" and XSkin2C.EDGE_FLASH:
			_edge_at = _now
	var flk := clampf(fl / 0.6, 0.0, 1.0)
	# 连击档
	var tier := XComboCounter.tier(_c_hits()) if cs else 0
	if cs and tier > _tier and _tier > 0:
		_tier_at = _now
	_tier = tier if cs else 0
	var tier_k := clampf((_now - _tier_at) / TIER_UP, 0.0, 1.0) if full_m else 1.0
	var line_hi := bright if line != "" else XUiSkin.GOLD_LIGHT
	var line_main := XTianqiLook.main_color(line, XUiSkin.GOLD) if line != "" else XUiSkin.GOLD
	# 呼吸：快满（最后三颗）、有人被挂死期
	var d := diamonds(rr) if not rr.is_empty() else Vector2i.ZERO
	var near_full := (key in ["war", "plague"]) and int(rr.full) > 0 and int(rr.value) >= int(rr.full) - 3 and int(rr.value) > 0
	var doom := key == "death" and d.y > 0
	if (near_full or doom) and full_m:
		var b := 0.5 + 0.5 * sin(_now * TAU / XUiSkin.TARGET_PULSE)
		XSkin2C._glow(self, C, 86.0, Color(main, (0.18 + 0.22 * b) * ring_a))
	# 外圈的晕＋盘面
	draw_circle(C, DISC_R + 7.0, Color(0, 0, 0, 0.55 * ring_a))
	draw_arc(C, DISC_R + 7.0, 0, TAU, 64, Color(0, 0, 0, 0.7 * ring_a), 1.0, true)
	draw_circle(C, DISC_R, Color(XUiSkin.PANEL, 0.92 * ring_a))
	var border := XUiSkin.GOLD
	var bw := 1.5
	match tier:
		2: border = XUiSkin.GOLD_LIGHT
		3: border = XUiSkin.GOLD_LIGHT
		4:
			border = line_main
			bw = 2.5
	if tier >= 3:
		XSkin2C._glow(self, C, DISC_R + 26.0, Color(XUiSkin.GOLD_LIGHT if tier == 3 else line_main, 0.30 * ring_a))
		draw_circle(C, DISC_R, Color(XUiSkin.PANEL, 0.92 * ring_a))
	if fl > 0.0:
		border = border.lerp(main, flk)
	draw_arc(C, DISC_R, 0, TAU, 72, Color(border, ring_a), bw, true)
	# 计量点（菱形）／弧形条／七颗小圆
	var rot := 0.0
	if fl > 0.0 and full_m and d.x > 0:
		rot = (1.0 - flk) * PI / d.x   # 环转半格
	last.ring_key = key
	last.diamonds = d.x
	last.lit = d.y
	last.circles = 0
	if d.x > 0:
		_draw_diamonds(key, d, main, bright, fl > 0.0, rot, full_m, ring_a)
	elif d.x < 0:
		_draw_arc_bar(rr, main, bright, fl > 0.0, ring_a)
	else:
		_draw_seven(ring_a)
		last.circles = 7
	# 光环（满的那一下，半径散到 116，0.3 秒，只一次）
	var hk := (_now - _halo_at) / HALO
	if hk >= 0.0 and hk < 1.0:
		draw_arc(C, lerpf(DISC_R, 116.0, hk), 0, TAU, 72, Color(main, 0.75 * (1.0 - hk)), 3.0 * (1.0 - hk) + 1.0, true)
	# 外圈金弧：连击还剩多久
	if cs:
		var hf := _c_hold()
		if hf > 0.0:
			draw_arc(C, ARC_R, -PI / 2.0, -PI / 2.0 + TAU * hf, 64, Color(XUiSkin.GOLD_LIGHT, _c_alpha()), 4.0, true)
		if tier_k < 1.0:
			draw_arc(C, DISC_R + 3.0, 0, TAU, 72, Color(XUiSkin.GOLD_LIGHT, 0.8 * (1.0 - tier_k)), 6.0 * (1.0 - tier_k) + 1.0, true)
	# 环心：连击数字或本线蜡封
	if cs:
		_draw_combo(tier, tier_k, line_hi, line_main, motion)
	elif key != "":
		var sc := 1.0
		if fl > 0.0 and full_m:
			sc = 1.0 + 0.18 * sin(flk * PI)
		draw_line_wax(self, C, 68.0 * sc, line if line != "" else key, ring_a, fl > 0.0)
		last.center = "wax"
	# 小签（冻结后由衔接层淡出）
	if not rr.is_empty() and tag_alpha > 0.0:
		_draw_tags(full_m)
	# 四边一闪（火花满的那一下，0.3 秒，只一次）
	var ek := (_now - _edge_at) / HALO
	if ek >= 0.0 and ek < 1.0:
		_draw_edge_flash(XTianqiLook.main_color("war"), 0.7 * sin((1.0 - ek) * PI * 0.5))
		last.edge = true


func _ring_point(i: int, n: int, rot: float, r := DISC_R) -> Vector2:
	var a := -PI / 2.0 + TAU * i / n + rot
	return C + Vector2(cos(a), sin(a)) * r


func _draw_diamonds(key: String, d: Vector2i, main: Color, bright: Color, flashing: bool, rot: float, full_m: bool, a: float) -> void:
	var big := key == "death"
	var half := 6.0 if big else 4.5
	var lit_list: Array = _lit_at.get(key, [])
	lit_list.resize(d.x)
	for i in d.x:
		var p := _ring_point(i, d.x, rot)
		var lit := i < d.y or (flashing and key != "death")   # 满的那一下：计量点全部换成白金色
		if lit and lit_list[i] == null:
			lit_list[i] = _now
		elif not lit:
			lit_list[i] = null
		var k := 1.0
		if lit and full_m and lit_list[i] != null:
			k = clampf((_now - float(lit_list[i])) / LIGHT_UP, 0.0, 1.0)
		XSkin2C._diamond(self, p, half + 1.0, Color(0, 0, 0, 0.8 * a))
		if not lit or k < 1.0:
			XSkin2C._diamond(self, p, half, Color(0.2, 0.2, 0.22, a))
			XSkin2C._diamond_line(self, p, half, Color(XUiSkin.LINE, 0.9 * a), 1.0)
		if lit:
			var col := main
			var glow := 6.0
			if big:
				col = XTianqiLook.main_color("death")
				glow = 8.0
			elif i >= d.x - 3:
				col = bright
				glow = 9.0
			if flashing:
				col = Color("fff4d6")   # 满的那一下：全部换成白金色
			XSkin2C._glow(self, p, (half + glow) * 1.6, Color(XTianqiLook.accent_color("death") if big else col, 0.55 * k * a))
			XSkin2C._diamond(self, p, half, Color(col, k * a))
	_lit_at[key] = lit_list


func _draw_arc_bar(r: Dictionary, main: Color, bright: Color, flashing: bool, a: float) -> void:
	draw_arc(C, DISC_R, 0, TAU, 72, Color(0.2, 0.2, 0.22, a), 4.0, true)
	var k := clampf(float(r.value) / maxf(float(r.full), 1.0), 0.0, 1.0)
	if flashing:
		k = 1.0   # T273（T267 核查 P3-3）：满的那一下计量已归零，整圈照菱形版一样全换白金色，不是整圈暗着
	if k > 0.0:
		var col := Color("fff4d6") if flashing else (bright if int(r.value) >= int(r.full) - 3 else main)
		draw_arc(C, DISC_R, -PI / 2.0, -PI / 2.0 + TAU * k, 72, Color(col, a), 4.0, true)
	last.arc_bar = k


## 七颗 7px 小圆：七印装饰，不是读数，不亮
func _draw_seven(a: float) -> void:
	for i in 7:
		var p := _ring_point(i, 7, 0.0)
		draw_circle(p, 4.5, Color(0, 0, 0, 0.8 * a))
		draw_circle(p, 3.5, Color(0.22, 0.21, 0.2, a))
		draw_arc(p, 3.5, 0, TAU, 12, Color(XUiSkin.GOLD, 0.45 * a), 1.0, true)


## 连击大数字（环心与结算飞光共用）：D1c 开着时逐位定宽居中（1／7 不晃，宋体 Heavy 不等宽），pos＝旧画法的左起落笔点（x＝-整串宽/2），
## 这里只取它的基线 y、以 x＝0 为中心；DETAIL_V1＝false 回旧画法（整串居中＋8px 描边＋ds）。描边 8px 同旧。
static func draw_combo_digits(ci: CanvasItem, f: Font, pos: Vector2, s: String, fs: int, fill: Color, outline: Color) -> void:
	if XUiSkin.detail_on():
		XUiSkin.draw_mono_digits(ci, f, 0.0, pos.y, s, fs, fill, HORIZONTAL_ALIGNMENT_CENTER, 8, outline)
		return
	ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, outline)
	XUiSkin.ds(ci, f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fill)


func _draw_combo(tier: int, tier_k: float, line_hi: Color, line_main: Color, motion: int) -> void:
	var n := _c_hits()
	var s := str(n)
	var fs := 50 if s.length() <= 2 else (40 if s.length() == 3 else 34)
	var col := XUiSkin.TEXT_HI
	match tier:
		2, 3: col = XUiSkin.GOLD_LIGHT
		4: col = line_hi
	var sc := 1.0
	if motion == XUiSkin.Motion.FULL:
		sc = _c_scale()
		if tier_k < 1.0:
			sc = maxf(sc, lerpf(1.45, 1.0, tier_k))
	var a := _c_alpha()
	if tier >= 3:
		XSkin2C._glow(self, C + Vector2(0, -6), 40.0, Color(XUiSkin.GOLD_LIGHT if tier == 3 else line_main, 0.45 * a))
	var f := num_font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := C.y - 6.0 + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0
	draw_set_transform(C + Vector2(0, -6), 0.0, Vector2(sc, sc))
	var pos := Vector2(-w / 2.0, base - (C.y - 6.0))
	draw_combo_digits(self, f, pos, s, fs, Color(col, a), Color(0, 0, 0, 0.9 * a))
	draw_set_transform(Vector2.ZERO)
	XSkin2C._text(self, C.x - 40.0, C.y + 22.0, "连击", XUiSkin.fs(15), Color(XUiSkin.TEXT_2, a), HORIZONTAL_ALIGNMENT_CENTER, 80.0)
	last.center = "combo"
	last.combo = n
	last.combo_fs = fs
	last.tier = tier


## 本线蜡封：本线色的蜡＋骑士徽记（content/tianqi/qiyin/icons/badge_<线>.png）；没选线用通用金蜡
static func draw_line_wax(ci: CanvasItem, c: Vector2, sz: float, key: String, alpha := 1.0, hot := false) -> void:
	if key == "" or not XTianqiLook.LOOK.has(key):
		XSkin2C.draw_wax(ci, c, sz, alpha)
		return
	var r := sz / 2.0
	var main := XTianqiLook.main_color(key)
	var dark := XTianqiLook.dark_color(key)
	if key == "death":
		main = XTianqiLook.accent_color(key).darkened(0.25)   # 骨白蜡看不出是蜡，死亡线用冷蓝
	ci.draw_circle(c + Vector2(0, 2.5), r * 0.98, Color(0, 0, 0, 0.5 * alpha))
	var steps := 12
	for i in steps:
		var k := float(i) / (steps - 1)
		var col := dark.lerp(main.darkened(0.15), minf(k / 0.5, 1.0)) if k < 0.5 else main.darkened(0.15).lerp(main.lightened(0.18), (k - 0.5) / 0.5)
		ci.draw_circle(c + Vector2(-0.12, -0.16) * r * k, r * (1.0 - k * 0.9), Color(col, alpha))
	ci.draw_arc(c, r * 0.78, 0, TAU, 48, Color(dark, 0.55 * alpha), maxf(1.0, sz * 0.03), true)
	if hot:
		XSkin2C._glow(ci, c, r * 1.4, Color(main.lightened(0.3), 0.5 * alpha))
	var t := badge(key)
	if t != null:
		var bs := sz * 0.62
		ci.draw_texture_rect(t, Rect2(c - Vector2(bs, bs) / 2.0, Vector2(bs, bs)), false, Color(1, 1, 1, alpha))


## ---- 小签 ----

func tag_step(n: int) -> float:
	return 32.0 if n >= 4 else 36.0


func _draw_tags(full_m: bool) -> void:
	var tags := tag_rows()
	var n := tags.size()
	var step := tag_step(n)
	var top := C.y - ((n - 1) * step + TAG_H) / 2.0
	last.tags = []
	for i in n:
		var r: Dictionary = tags[i]
		var y := top + i * step
		last.tags.append({"key": str(r.key), "y": y, "text": _draw_tag(r, Vector2(TAG_X, y), i == 0)})


## 一枚签：签头本线蜡封 24、计量名 15 号本线主色、读数；返回签上读得出的字（测试读）
func _draw_tag(r: Dictionary, at: Vector2, on_ring: bool) -> String:
	var key := str(r.key)
	var main := XTianqiLook.main_color(key)
	var fl := _flash(key)
	var flk := clampf(fl / 0.6, 0.0, 1.0)
	var f15 := XUiSkin.fs(15)
	var f17 := XUiSkin.fs(17)
	var label := str(r.label)
	var segs := []   # [字, 字号, 颜色]
	var bar := -1.0
	match key:
		"war", "plague":
			if fl > 0.0:
				segs = [["全体再动" if key == "war" else "爆发", f17, XUiSkin.TEXT_HI]]
			else:
				if not on_ring:
					bar = clampf(float(r.value) / maxf(float(r.full), 1.0), 0.0, 1.0)
				segs = [[str(int(r.value)), f17, XUiSkin.TEXT], [" / %d" % int(r.full), f15, XUiSkin.TEXT_2]]
		"death":
			var names := PackedStringArray(_doomed().map(func(a): return a.display_name()))
			if names.is_empty():
				segs = [["暂无", f15, XUiSkin.TEXT_3]]
			elif names.size() > 2:
				segs = [["%s 等 %d 人　回合结束时死" % ["、".join(names.slice(0, 2)), names.size()], f15, XUiSkin.DOWN]]
			else:
				segs = [["、".join(names) + "　回合结束时死", f15, XUiSkin.DOWN]]
		"famine":
			var m: Array = _dial_info().get("famine", [1.0, 1.0])
			segs = [["消耗", f15, XUiSkin.TEXT_2], [" ×" + _num(float(m[0])) + "　", f17, _mult_color(float(m[0]), true)],
				["回复", f15, XUiSkin.TEXT_2], [" ×" + _num(float(m[1])), f17, _mult_color(float(m[1]), false)]]
	var f := XUiSkin.font("body")
	var w := 4.0 + 24.0 + 6.0 + XSkin2C._tw(label, f15) + 8.0
	if bar >= 0.0:
		w += 56.0 + 8.0
	for sg in segs:
		w += XSkin2C._tw(str(sg[0]), int(sg[1]))
	w += 12.0
	var rect := Rect2(at, Vector2(w, TAG_H))
	var ta := tag_alpha
	var fill := Color(XUiSkin.PANEL_LOW, 0.88)
	if fl > 0.0:
		fill = fill.lerp(Color(main.darkened(0.2), 0.95), flk)
	XSkin2C._pill(self, rect, Color(fill, fill.a * ta), Color(main, 0.55 * ta))
	draw_line_wax(self, at + Vector2(4.0 + 12.0, TAG_H / 2.0), 24.0, key, ta)   # 签头是这枚签自己那条线的蜡封
	var x := at.x + 4.0 + 24.0 + 6.0
	var tc := main if fl <= 0.0 else XUiSkin.TEXT_HI
	XSkin2C._text(self, x, at.y + (TAG_H - f15 * 1.25) / 2.0, label, f15, Color(tc, ta))
	x += XSkin2C._tw(label, f15) + 8.0
	if bar >= 0.0:
		var br := Rect2(x, at.y + TAG_H / 2.0 - 2.0, 56.0, 4.0)
		draw_rect(br, Color(0.18, 0.18, 0.2, ta))
		draw_rect(Rect2(br.position, Vector2(56.0 * bar, 4.0)), Color(main, ta))
		x += 56.0 + 8.0
	var out := label
	for sg in segs:
		var fs := int(sg[1])
		var col: Color = sg[2]
		XSkin2C._text(self, x, at.y + (TAG_H - fs * 1.25) / 2.0, str(sg[0]), fs, Color(col, col.a * ta))
		x += XSkin2C._tw(str(sg[0]), fs)
		out += str(sg[0])
	return out


## 饥饿倍率的颜色：消耗大于 1、回复小于 1 是对我方不利（橙），反过来有利（绿），等于 1 照常
static func _mult_color(v: float, cost: bool) -> Color:
	if is_equal_approx(v, 1.0):
		return XUiSkin.TEXT
	var bad := v > 1.0 if cost else v < 1.0
	return XUiSkin.DOWN if bad else XUiSkin.UP


## ---- 四边一闪 ----

## 只在屏幕边上：最边上 a（最浓七成），离边 22% 以内淡到 0，正中六成不染
func _draw_edge_flash(col: Color, a: float) -> void:
	var vr := get_viewport_rect().size
	var o := -global_position
	var bw := vr.x * 0.22
	var bh := vr.y * 0.22
	var c0 := Color(col, a)
	var c1 := Color(col, 0.0)
	var quads := [
		[Vector2(0, 0), Vector2(vr.x, 0), Vector2(vr.x, bh), Vector2(0, bh), [c0, c0, c1, c1]],
		[Vector2(0, vr.y - bh), Vector2(vr.x, vr.y - bh), Vector2(vr.x, vr.y), Vector2(0, vr.y), [c1, c1, c0, c0]],
		[Vector2(0, 0), Vector2(bw, 0), Vector2(bw, vr.y), Vector2(0, vr.y), [c0, c1, c1, c0]],
		[Vector2(vr.x - bw, 0), Vector2(vr.x, 0), Vector2(vr.x, vr.y), Vector2(vr.x - bw, vr.y), [c1, c0, c0, c1]],
	]
	for q in quads:
		draw_polygon(PackedVector2Array([o + q[0], o + q[1], o + q[2], o + q[3]]), PackedColorArray(q[4]))


## 倍率写法（同 XTianqiMeter._num：两位小数去掉末尾 0）；抄一份，免得印盘依赖计量条的私有函数
static func _num(v: float) -> String:
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.left(s.length() - 1)
	return s.trim_suffix(".")
