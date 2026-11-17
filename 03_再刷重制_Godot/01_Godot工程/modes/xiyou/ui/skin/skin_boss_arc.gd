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
const SEAL_SIZE := 76.0
const COPPER_SEAL_PATH := "res://content/tianqi/qiyin/seals/hong.png"

## T125 可回退开关：
## CLEAN_FACE=false 回到 T096 整张贴图裁圆（带原版菱形金框、无头像不画章）；
## INK_TEXT=false 回到 T096 深色胶囊底板（XSkin4A.draw_text_backing）。
static var CLEAN_FACE := true
static var INK_TEXT := true

static var _copper_seal_tex: Texture2D
static var _seal_loaded := false
static var _crop_cache := {}
var _last_face_mode := ""
var _last_ink_text := true
var _last_backing_draws := 0


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


static func copper_seal_texture() -> Texture2D:
	if not _seal_loaded:
		_seal_loaded = true
		if ResourceLoader.exists(COPPER_SEAL_PATH):
			_copper_seal_tex = load(COPPER_SEAL_PATH)
	return _copper_seal_tex


static func _opaque_bbox(img: Image) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var max_x := -1
	var min_y := h
	var max_y := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.12:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < min_x:
		return Rect2i(0, 0, w, h)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func _center_cutout_texture(src: Image, bbox: Rect2i) -> Texture2D:
	var side := maxi(ceili(maxf(float(bbox.size.x), float(bbox.size.y)) * 1.16), 32)
	var out := Image.create(side, side, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var dst := Vector2i((side - bbox.size.x) / 2, (side - bbox.size.y) / 2)
	out.blit_rect(src, bbox, dst)
	return ImageTexture.create_from_image(out)


## MOG 85×85 菱形头像统一的黄/金渐变底色（345 张全量拟合，纯底色最大 RGB 偏差 0.012）
static func _diamond_bg_pred(x: int, y: int) -> Vector3:
	var c0 := Vector3(192.0 / 255.0, 142.0 / 255.0, 23.0 / 255.0)
	var c1 := Vector3(228.0 / 255.0, 206.0 / 255.0, 154.0 / 255.0)
	var dv := c1 - c0
	var fx := (float(x) - 42.0) / 42.0
	var fy := (float(y) - 42.0) / 42.0
	var t := clampf(0.343702 + 0.620474 * fx + 0.049286 * fy + 0.145368 * fx * fx + 0.035060 * fx * fy - 0.018461 * fy * fy, 0.0, 1.0)
	return c0 + dv * t


static func _is_diamond_frame_pixel(c: Color, x: int, y: int) -> bool:
	var m := absi(x - 42) + absi(y - 42)
	if m < 39:
		return false
	if c.a < 0.85:
		return true
	var h := c.h * 360.0
	if m == 39:
		return h >= 38.0 and h <= 48.0 and c.s <= 0.30 and c.v >= 0.70
	return h >= 33.0 and h <= 51.0 and c.s >= 0.08 and c.v <= 0.945


## 识别原版 MOG 85×85 菱形金框头像：结合理论渐变拟合与相邻像素平滑度从边缘漫水剥离外框与黄底，
## 再清理封闭纯底空腔；若扣除比例或中心区域破坏超阈值，兜底退回「圆形裁内框、保留原底色」。
static func face_crop(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {"center": Vector2(0.5, 0.5), "uv_r": 0.5, "diamond": false, "fallback": false, "tex": null}
	var key := tex.get_rid().get_id()
	if _crop_cache.has(key):
		return _crop_cache[key]
	var sz := tex.get_size()
	var res := {"center": Vector2(0.5, 0.5), "uv_r": 0.46, "diamond": false, "fallback": false, "tex": tex}
	var img := tex.get_image()
	if img != null and sz.x >= 80.0 and sz.y >= 80.0:
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		var corner_clear := img.get_pixel(2, 2).a < 0.1 and img.get_pixel(w - 3, 2).a < 0.1 and img.get_pixel(2, h - 3).a < 0.1 and img.get_pixel(w - 3, h - 3).a < 0.1
		if corner_clear and w == 85 and h == 85:
			var work := img.duplicate() as Image
			if work.get_format() != Image.FORMAT_RGBA8:
				work.convert(Image.FORMAT_RGBA8)
			var bg := PackedByteArray()
			bg.resize(85 * 85)
			var q: Array[Vector2i] = []
			for i in 85:
				for pt: Vector2i in [Vector2i(i, 0), Vector2i(i, 84), Vector2i(0, i), Vector2i(84, i)]:
					var idx: int = pt.y * 85 + pt.x
					var c0 := work.get_pixel(pt.x, pt.y)
					if bg[idx] == 0 and (c0.a < 0.12 or _is_diamond_frame_pixel(c0, pt.x, pt.y)):
						bg[idx] = 1
						q.append(pt)
			var head := 0
			while head < q.size():
				var p := q[head]
				head += 1
				var pc := work.get_pixel(p.x, p.y)
				var p_is_inner := pc.a >= 0.12 and absi(p.x - 42) + absi(p.y - 42) <= 38
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = p.x + d.x
					var ny: int = p.y + d.y
					if nx < 0 or nx >= 85 or ny < 0 or ny >= 85:
						continue
					var nidx: int = ny * 85 + nx
					if bg[nidx] != 0:
						continue
					var nc := work.get_pixel(nx, ny)
					var is_bg := false
					if nc.a < 0.12 or _is_diamond_frame_pixel(nc, nx, ny):
						is_bg = true
					else:
						var bdist := Vector3(nc.r, nc.g, nc.b).distance_to(_diamond_bg_pred(nx, ny))
						if bdist <= 0.038:
							if not p_is_inner or bdist <= 0.022 or Vector3(nc.r - pc.r, nc.g - pc.g, nc.b - pc.b).length() <= 0.045:
								is_bg = true
					if is_bg:
						bg[nidx] = 1
						q.append(Vector2i(nx, ny))
			# 封闭纯黄底空腔（被头发/角/翅围住且与理论渐变一致 >= 14px 的区域）
			var pocket_vis := PackedByteArray()
			pocket_vis.resize(85 * 85)
			for py in 85:
				for px in 85:
					var pidx := py * 85 + px
					if bg[pidx] != 0 or pocket_vis[pidx] != 0 or absi(px - 42) + absi(py - 42) > 38:
						continue
					var pc0 := work.get_pixel(px, py)
					if pc0.a < 0.12 or Vector3(pc0.r, pc0.g, pc0.b).distance_to(_diamond_bg_pred(px, py)) > 0.016:
						continue
					var comp: Array[Vector2i] = [Vector2i(px, py)]
					pocket_vis[pidx] = 1
					var ch := 0
					while ch < comp.size():
						var cp := comp[ch]
						ch += 1
						for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							var cx: int = cp.x + d.x
							var cy: int = cp.y + d.y
							if cx < 0 or cx >= 85 or cy < 0 or cy >= 85 or absi(cx - 42) + absi(cy - 42) > 38:
								continue
							var cidx := cy * 85 + cx
							if bg[cidx] != 0 or pocket_vis[cidx] != 0:
								continue
							var cc := work.get_pixel(cx, cy)
							if cc.a >= 0.12 and Vector3(cc.r, cc.g, cc.b).distance_to(_diamond_bg_pred(cx, cy)) <= 0.024:
								pocket_vis[cidx] = 1
								comp.append(Vector2i(cx, cy))
					if comp.size() >= 14:
						for cp in comp:
							bg[cp.y * 85 + cp.x] = 1
			var cleared_in := 0
			var rem_in := 0
			var ctr_cleared := 0
			for y in 85:
				for x in 85:
					var m := absi(x - 42) + absi(y - 42)
					if bg[y * 85 + x] != 0:
						work.set_pixel(x, y, Color(0, 0, 0, 0))
						if m <= 38:
							cleared_in += 1
							if (x - 42) * (x - 42) + (y - 42) * (y - 42) <= 64:
								ctr_cleared += 1
					elif m <= 38 and work.get_pixel(x, y).a >= 0.12:
						rem_in += 1
			var bbox := _opaque_bbox(work)
			var cleared_ratio := float(cleared_in) / 2965.0
			var ctr_ratio := float(ctr_cleared) / 197.0
			if cleared_ratio > 0.90 or rem_in < 200 or ctr_ratio > 0.72 or bbox.size.x < 16 or bbox.size.y < 16:
				# 保留率兜底：退回「圆形裁内框、保留原底色」，宁可留黄底也不吃掉主体
				res = {"center": Vector2(0.5, 0.5), "uv_r": 0.30, "diamond": false, "fallback": true, "tex": tex}
			else:
				var clean_tex := _center_cutout_texture(work, bbox)
				res = {"center": Vector2(0.5, 0.5), "uv_r": 0.49, "diamond": true, "fallback": false, "tex": clean_tex}
		elif corner_clear:
			var bbox := _opaque_bbox(img)
			var clean_tex := _center_cutout_texture(img, bbox)
			res = {"center": Vector2(0.5, 0.5), "uv_r": 0.49, "diamond": false, "fallback": false, "tex": clean_tex}
	_crop_cache[key] = res
	return res


static func draw_cropped_round_texture(ci: CanvasItem, tex: Texture2D, c: Vector2, r: float, center_uv := Vector2(0.5, 0.5), uv_r := 0.5, segments := 40, alpha := 1.0) -> void:
	var src := Rect2(Vector2.ZERO, tex.get_size())
	var base: Texture2D = tex
	if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
		base = (tex as AtlasTexture).atlas
		src = (tex as AtlasTexture).region
	var full := base.get_size()
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for k in segments:
		var d := Vector2.from_angle(TAU * k / segments)
		pts.append(c + d * r)
		uvs.append((src.position + src.size * (center_uv + d * uv_r)) / full)
	ci.draw_polygon(pts, PackedColorArray([Color(1, 1, 1, alpha)]), uvs, base)


static func draw_ink_mist(ci: CanvasItem, cx: float, cy: float, rx: float, ry: float, alpha: float) -> void:
	if alpha <= 0.0 or rx <= 0.0 or ry <= 0.0:
		return
	var g := XUiSkin.glow_texture()
	ci.draw_texture_rect(g, Rect2(cx - rx, cy - ry, rx * 2.0, ry * 2.0), false, Color(0.025, 0.018, 0.02, alpha))


func _boss_race_id() -> int:
	if battler == null or not battler.has_method("race_ids"):
		return 0
	var ids: Array = battler.race_ids()
	return int(ids[0]) if not ids.is_empty() else 0


## 没头像首领的种族小印：画在红铜章右下（4 点钟方向），暗褐底＋旧金细圈＋程序矢量族徽（1..12 对应 Star_EnemyRace）
func _draw_race_badge(c: Vector2, race_id: int, al: float) -> void:
	var r := 13.0
	draw_circle(c + Vector2(0, 1.5), r + 1.5, Color(0, 0, 0, 0.65 * al))
	draw_circle(c, r, Color(0.075, 0.048, 0.045, 0.95 * al))
	draw_arc(c, r, 0.0, TAU, 32, Color(XUiSkin.GOLD, 0.92 * al), 1.3, true)
	draw_arc(c, r - 2.2, 0.0, TAU, 28, Color(XUiSkin.GOLD_LIGHT, 0.25 * al), 0.7, true)
	_draw_race_glyph(c, 7.2, race_id, al)


func _draw_race_glyph(c: Vector2, s: float, race_id: int, al: float) -> void:
	var fg := Color(XUiSkin.GOLD_LIGHT, 0.96 * al)
	var accent := Color(XUiSkin.GOLD, 0.85 * al)
	match race_id:
		1:  # 野兽：双爪斜划 + 尖牙
			for ox in [-3.2, 0.0, 3.2]:
				draw_line(c + Vector2(ox - 2.0, -s * 0.75), c + Vector2(ox + 2.0, s * 0.75), fg, 1.5, true)
		2:  # 亡灵：骷髅轮廓
			draw_circle(c + Vector2(0, -1.5), s * 0.58, fg)
			draw_rect(Rect2(c + Vector2(-s * 0.36, s * 0.15), Vector2(s * 0.72, s * 0.45)), fg)
			draw_circle(c + Vector2(-2.0, -1.5), 1.3, Color(0.07, 0.04, 0.04, al))
			draw_circle(c + Vector2(2.0, -1.5), 1.3, Color(0.07, 0.04, 0.04, al))
		3:  # 人形：人像肩颈剪影
			draw_circle(c + Vector2(0, -s * 0.42), s * 0.34, fg)
			var body := PackedVector2Array([
				c + Vector2(-s * 0.62, s * 0.72), c + Vector2(-s * 0.46, s * 0.05),
				c + Vector2(s * 0.46, s * 0.05), c + Vector2(s * 0.62, s * 0.72)
			])
			draw_colored_polygon(body, fg)
		4:  # 龙族：双角龙首菱纹
			var horn_l := PackedVector2Array([c + Vector2(-s * 0.72, -s * 0.82), c + Vector2(-s * 0.15, -s * 0.15), c + Vector2(-s * 0.48, s * 0.05)])
			var horn_r := PackedVector2Array([c + Vector2(s * 0.72, -s * 0.82), c + Vector2(s * 0.15, -s * 0.15), c + Vector2(s * 0.48, s * 0.05)])
			draw_colored_polygon(horn_l, fg)
			draw_colored_polygon(horn_r, fg)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.45), c + Vector2(s * 0.48, s * 0.1), c + Vector2(0, s * 0.78), c + Vector2(-s * 0.48, s * 0.1)]), accent)
		5:  # 元素：四芒星辉
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s * 0.9), c + Vector2(s * 0.25, -s * 0.25),
				c + Vector2(s * 0.9, 0), c + Vector2(s * 0.25, s * 0.25),
				c + Vector2(0, s * 0.9), c + Vector2(-s * 0.25, s * 0.25),
				c + Vector2(-s * 0.9, 0), c + Vector2(-s * 0.25, -s * 0.25)
			]), fg)
		6:  # 恶魔：弯角 + 倒三角印
			draw_arc(c + Vector2(-s * 0.45, -s * 0.35), s * 0.48, deg_to_rad(-110), deg_to_rad(30), 10, fg, 1.8, true)
			draw_arc(c + Vector2(s * 0.45, -s * 0.35), s * 0.48, deg_to_rad(150), deg_to_rad(290), 10, fg, 1.8, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.45, -s * 0.05), c + Vector2(s * 0.45, -s * 0.05), c + Vector2(0, s * 0.78)]), accent)
		7:  # 巨人：重冠山岳
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.7, s * 0.65), c + Vector2(-s * 0.7, -s * 0.3),
				c + Vector2(-s * 0.3, s * 0.05), c + Vector2(0, -s * 0.75),
				c + Vector2(s * 0.3, s * 0.05), c + Vector2(s * 0.7, -s * 0.3),
				c + Vector2(s * 0.7, s * 0.65)
			]), fg)
		8:  # 灵魂：浮焰魂火
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s * 0.9), c + Vector2(s * 0.55, s * 0.1),
				c + Vector2(s * 0.3, s * 0.75), c + Vector2(-s * 0.3, s * 0.75),
				c + Vector2(-s * 0.55, s * 0.1)
			]), fg)
			draw_circle(c + Vector2(0, s * 0.15), s * 0.22, Color(0.07, 0.04, 0.04, al))
		9:  # 植物：双叶芽
			draw_line(c + Vector2(0, s * 0.75), c + Vector2(0, -s * 0.4), fg, 1.5, true)
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(-s * 0.75, -s * 0.5), c + Vector2(-s * 0.2, -s * 0.75)]), fg)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.15), c + Vector2(s * 0.75, -s * 0.35), c + Vector2(s * 0.25, -s * 0.6)]), accent)
		10: # 妖精：双翅蝶印
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(-s * 0.8, -s * 0.65), c + Vector2(-s * 0.65, s * 0.35)]), fg)
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(s * 0.8, -s * 0.65), c + Vector2(s * 0.65, s * 0.35)]), fg)
			draw_line(c + Vector2(0, -s * 0.6), c + Vector2(0, s * 0.7), accent, 1.4, true)
		11: # 机械：齿轮环
			draw_arc(c, s * 0.45, 0.0, TAU, 18, fg, 2.0, true)
			for k in 6:
				var a := TAU * k / 6.0
				draw_line(c + Vector2.from_angle(a) * (s * 0.45), c + Vector2.from_angle(a) * (s * 0.82), fg, 1.8, true)
		12: # 外神：竖瞳魔眼
			draw_arc(c + Vector2(0, s * 0.45), s * 0.95, deg_to_rad(-145), deg_to_rad(-35), 14, fg, 1.6, true)
			draw_arc(c + Vector2(0, -s * 0.45), s * 0.95, deg_to_rad(35), deg_to_rad(145), 14, fg, 1.6, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.38), c + Vector2(s * 0.16, 0), c + Vector2(0, s * 0.38), c + Vector2(-s * 0.16, 0)]), fg)
		_:  # 默认／未知：四点星印
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.68), c + Vector2(s * 0.45, 0), c + Vector2(0, s * 0.68), c + Vector2(-s * 0.45, 0)]), fg)


func _draw() -> void:
	if battler == null or layout_alpha <= 0:
		return
	_last_ink_text = INK_TEXT
	_last_face_mode = ""
	_last_backing_draws = 0
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
		if CLEAN_FACE:
			_last_face_mode = "clean_crop"
			draw_ink_mist(self, FACE_C.x, FACE_C.y + 2.0, FACE_R + 18.0, FACE_R + 18.0, 0.45 * al)
			draw_circle(FACE_C, FACE_R + 1.5, Color(0.06, 0.045, 0.04, 0.92 * al))
			var crop := face_crop(_face_tex)
			var draw_tex: Texture2D = crop.get("tex", _face_tex)
			draw_cropped_round_texture(self, draw_tex, FACE_C, FACE_R - 1.5, crop.center, float(crop.uv_r), 48, al)
			draw_arc(FACE_C, FACE_R + 0.8, 0.0, TAU, 56, Color(0, 0, 0, 0.85 * al), 2.4, true)
			draw_arc(FACE_C, FACE_R, 0.0, TAU, 56, Color(XUiSkin.GOLD, 0.88 * al), 1.4, true)
			draw_arc(FACE_C, FACE_R - 2.4, 0.0, TAU, 56, Color(XUiSkin.GOLD_LIGHT, 0.24 * al), 0.7, true)
		else:
			_last_face_mode = "t096_round"
			draw_circle(FACE_C, FACE_R + 2.0, Color(0, 0, 0, 0.6 * al))
			XSkinPartyStrip.draw_round_texture(self, _face_tex, FACE_C, FACE_R)
			draw_arc(FACE_C, FACE_R, 0.0, TAU, 48, Color(XUiSkin.GOLD, 0.7 * al), 1.5, true)
	elif CLEAN_FACE:
		_last_face_mode = "copper_seal"
		var seal := copper_seal_texture()
		if seal != null:
			draw_ink_mist(self, FACE_C.x, FACE_C.y + 3.0, SEAL_SIZE * 0.72, SEAL_SIZE * 0.72, 0.55 * al)
			draw_texture_rect(seal, Rect2(FACE_C - Vector2(SEAL_SIZE, SEAL_SIZE) * 0.5, Vector2(SEAL_SIZE, SEAL_SIZE)), false, Color(1, 1, 1, al))
		else:
			draw_circle(FACE_C, FACE_R, Color(0.32, 0.11, 0.09, 0.9 * al))
			draw_arc(FACE_C, FACE_R, 0.0, TAU, 48, Color(XUiSkin.GOLD, 0.85 * al), 1.5, true)
		var rid := _boss_race_id()
		if rid > 0:
			_draw_race_badge(FACE_C + Vector2(23.0, 23.0), rid, al)
	var title := XUiSkin.font("title")
	var num := XUiSkin.font("num")
	var nm := _name_text
	var nw := title.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x
	var shadow := Color(0.03, 0.02, 0.02, 0.92 * al) if INK_TEXT else Color(0, 0, 0, 0.75 * al)
	if INK_TEXT:
		draw_ink_mist(self, CENTER.x, NAME_Y + 17.0, nw * 0.5 + 34.0, 24.0, 0.52 * al)
	elif XSkin4A.text_on():  # 新界面 4A（A5）：首领名垫深色胶囊底
		_last_backing_draws += 1
		XSkin4A.draw_text_backing(self, CENTER.x - nw / 2.0, NAME_Y + 27, nw, 27, al)
	draw_string_outline(title, Vector2(CENTER.x - nw / 2.0, NAME_Y + 27), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, 5 if INK_TEXT else 4, shadow)
	XUiSkin.ds(self, title, Vector2(CENTER.x - nw / 2.0, NAME_Y + 27), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(name_color(), al))
	if digits.is_empty():   # 插件参数关了血量数字
		return
	var cur := "".join(PackedStringArray(digits))
	var mx := " / " + max_text()
	var cw := num.get_string_size(cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var mw := num.get_string_size(mx, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var x0 := CENTER.x - (cw + mw) / 2.0
	if INK_TEXT:
		draw_ink_mist(self, CENTER.x, NUM_Y + 18.0, (cw + mw) * 0.5 + 32.0, 24.0, 0.48 * al)
	elif XSkin4A.text_on():  # 新界面 4A（A5）：血量数字垫深色胶囊底
		_last_backing_draws += 1
		XSkin4A.draw_text_backing(self, x0, NUM_Y + 30, cw + mw, 30, al)
	draw_string_outline(num, Vector2(x0, NUM_Y + 30), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 5 if INK_TEXT else 4, shadow)
	XUiSkin.ds(self, num, Vector2(x0, NUM_Y + 30), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(XUiSkin.HP_TEXT, al))
	draw_string_outline(num, Vector2(x0 + cw, NUM_Y + 30), mx, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4 if INK_TEXT else 3, shadow)
	XUiSkin.ds(self, num, Vector2(x0 + cw, NUM_Y + 30), mx, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(XUiSkin.GOLD, al))

