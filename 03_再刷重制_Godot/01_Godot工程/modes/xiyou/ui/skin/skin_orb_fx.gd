class_name XSkinOrbFx
extends RefCounted
## 【cc·天启篇·未经审查】球框四档特效（D113，T047）：小o 小样 gpt/orb-fx-dirs 9bae3eea8 的 generate.py 移植成程序绘制。
## - glint 微光扫框（小样 01）：沿框一段约 60° 的渐亮短弧（两像素宽、骑在淡框描边上），3 秒一圈；神话及以上武器（只槽位 0、1），叠在 T044 的淡框上；
## - seal7 七印封缄（小样 02）：七枚 3×3 微型符印沿半径 26 换位、内圈四颗小点反转，3 秒一轮；毕业武器；
## - flame 灵焰外溢（小样 04）：16 根青紫焰舌从半径 22 往外错峰起伏，1.44 秒一周；刻过七印的专属武器、刻了终焉级异化核的武器；
## - stars 双星巡轨（小样 05）：两条倾斜椭圆虚线轨道各挂一颗亮星带拖尾，1.44 秒一周；传家宝、专属武器、独特物件，不论哪一栏。
## 画法照小样：64×64 原生像素画布（中心 32）、二值 alpha、半径 > 28 的像素一律剪掉（不压栏位名），最近邻贴到球心、乘选中放大倍数。
## 每档 FRAMES 帧按需生成一次、缓存成贴图，之后每帧每颗球只多一次贴图绘制（13 栏全亮也只是 13 次 add_texture_rect）。
## 【T062·D121】seal7、stars 两支改用小o 加亮版（gpt/orb-fx-bright e8095236d）：七印 3×3 源字形每像素放 2×2、中心半径 23.5、七色提亮 22%、深蓝 171c32 四邻域 1px 描边、内圈四点半径 20 色 e2fff6；双星轨道 2px（96 采样、12 取 7）、拖尾提亮 25%、5×5 菱形星头、全部深蓝 1px 描边。微光、灵焰不动。
## 小样是 12 帧，这里每圈 36 帧（小样交付单「正式版建议升采样」），像素位置仍取整。动效档不是「全部」时停在 STILL 那一帧（小样静帧的相位）。

const KINDS := ["flame", "seal7", "stars", "glint"]
## 多档同时命中取高（D113）：灵焰 > 七印封缄 > 双星 > 微光
const RANK := {"flame": 4, "seal7": 3, "stars": 2, "glint": 1}
const PERIOD := {"glint": 3.0, "seal7": 3.0, "flame": 1.44, "stars": 1.44}
const FRAMES := 36
## 静止时用的帧（小样静帧取第 4 帧／12 ＝ 相位 0.25）
const STILL := 9
const SIZE := 64
const C := 32
const CLIP_R := 28.0
## 微光默认半径（小样按 T044 的扫框 24.5）；淡框上按球半径另生成
const GLINT_R := 24.5

const GLINT_COLS := ["817447", "a59559", "c4b570", "e7d28c", "fff0b6", "fff9dc"]
## 七枚符印的颜色沿用小样（亮色、避开正红）；没按七印 seal_tints 重映射：其中红印、震印、灰印偏暗，3×3 小符在 1 倍下看不清（交付单写明）
const SEAL7_COLS := ["7de6d0", "e6d183", "a0adff", "b58ced", "84d7ed", "bde593", "e8b88a"]
const SEAL7_GLYPHS := [
	[[0, -1], [0, 0], [-1, 1], [1, 1]], [[-1, -1], [1, -1], [0, 0], [0, 1]], [[-1, 0], [0, -1], [1, 0], [0, 1]],
	[[-1, -1], [-1, 0], [0, 1], [1, 0]], [[-1, 1], [0, -1], [1, 1]], [[-1, -1], [0, 0], [1, -1], [0, 1]], [[-1, 0], [0, 0], [1, 0], [1, -1]]]
const STAR_TRAIL := ["506783", "7295c3", "a9ddf5", "e8faff"]

static var _cache := {}
## 测试看：生成过几张帧贴图
static var built := 0


static func rank(kind: String) -> int:
	return int(RANK.get(kind, 0))


## 两档里取高的
static func higher(a: String, b: String) -> String:
	return a if rank(a) >= rank(b) else b


## 第几帧：t 秒、phase 是 0～1 的错相（相邻球错半周，免得 13 颗齐步走）；still 时固定 STILL
static func frame_of(kind: String, t: float, phase: float, still: bool) -> int:
	if still:
		return STILL
	var p := fposmod(t / float(PERIOD.get(kind, 3.0)) + phase, 1.0)
	return mini(FRAMES - 1, int(floor(p * FRAMES)))


## 某档某帧的贴图（64×64，中心 32）。glint 带半径（淡框按球半径画，0.5 取整进缓存键）
static func texture(kind: String, frame: int, glint_r := GLINT_R) -> Texture2D:
	if not RANK.has(kind):
		return null
	var gr := snappedf(clampf(glint_r, 8.0, CLIP_R - 1.0), 0.5)
	var key := "%s:%d:%.1f" % [kind, frame, gr if kind == "glint" else 0.0]
	if _cache.has(key):
		return _cache[key]
	var img := image(kind, frame, gr)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	built += 1
	return t


static func clear_cache() -> void:
	_cache.clear()


## 生成一帧（测试也直接量这张图：二值 alpha、半径 ≤ 28、没有正红）
static func image(kind: String, frame: int, glint_r := GLINT_R) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var p := float(frame) / FRAMES
	match kind:
		"glint":
			# 小样是半径 24.5 一像素；接进来叠在 2px 淡框上一像素看不出（截图实看），改成以球半径为中线、内外各一像素，正好盖住那段描边
			for j in 48:
				var t := TAU * p - PI / 3.0 + j * PI / 144.0
				_pt(img, _at(glint_r - 0.5, t), Color(GLINT_COLS[j >> 3]))
				_pt(img, _at(glint_r + 0.5, t), Color(GLINT_COLS[j >> 3]))
		"seal7":
			for i in 7:
				var c := _at(23.5, TAU * (i / 7.0 + p / 7.0))
				var mask := {}
				for d in SEAL7_GLYPHS[i]:
					for yy in 2:
						for xx in 2:
							mask[c + Vector2i(d[0] * 2 + xx, d[1] * 2 + yy)] = true
				for q in mask:
					for off in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						_pt(img, q + off, Color("171c32"))
				for q in mask:
					_pt(img, q, Color(SEAL7_COLS[i]).lightened(0.22))
			for i in 4:
				var q := _at(20.0, TAU * (i / 4.0 - p))
				_pt(img, q, Color("e2fff6"))
		"flame":
			for i in 16:
				var t := TAU * i / 16.0
				var h := 2 + int(3.0 * (0.5 + 0.5 * sin(TAU * p + i * 2.1)))
				var tip := _at(22.0 + h, t + 0.025 * sin(i + TAU * p))
				var poly := [_at(22.0, t - 0.07), _at(24.0, t - 0.04), tip, _at(22.0, t + 0.07)]
				_poly(img, poly, Color("9870cf" if i % 2 else "53b9c0"))
				_line(img, _at(22.0, t), _at(22.0 + h - 1, t), Color("d1adff" if i % 2 else "a3f2dc"))
		"stars":
			for k in 2:
				var mask := {}
				for j in 96:
					if j % 12 < 7:
						var q := _orbit(k, TAU * j / 96.0)
						mask[q] = Color("96d9ec" if k else "c2abf0")
						mask[q + Vector2i(0, 1)] = Color("96d9ec" if k else "c2abf0")
				var head := TAU * (p if k else -p)
				for j in 16:
					var q := _orbit(k, head - 0.8 + j * 0.05)
					mask[q] = Color(STAR_TRAIL[j >> 2]).lightened(0.25)
					mask[q + Vector2i(0, 1)] = mask[q]
				var star := _orbit(k, head)
				for y in range(-2, 3):
					for x in range(-2, 3):
						if absi(x) + absi(y) <= 2:
							mask[star + Vector2i(x, y)] = Color("e5faff" if k else "efe3ff")
				mask[star] = Color("fff7d6")
				for q in mask:
					for off in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						_pt(img, q + off, Color("171c32"))
				for q in mask:
					_pt(img, q, mask[q])
	# 剪到半径 28（欧氏，和小样一样按像素整数坐标量）
	for y in SIZE:
		for x in SIZE:
			if (x - C) * (x - C) + (y - C) * (y - C) > CLIP_R * CLIP_R:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img


static func _at(r: float, t: float) -> Vector2i:
	return Vector2i(int(round(C + r * cos(t))), int(round(C + r * sin(t))))


static func _orbit(k: int, t: float) -> Vector2i:
	var x := 25.0 * cos(t)
	var y := 17.0 * sin(t)
	var ang := -0.55 if k else 0.55
	return Vector2i(int(round(C + x * cos(ang) - y * sin(ang))), int(round(C + x * sin(ang) + y * cos(ang))))


static func _pt(img: Image, q: Vector2i, col: Color) -> void:
	if q.x >= 0 and q.y >= 0 and q.x < SIZE and q.y < SIZE:
		img.set_pixel(q.x, q.y, col)


## Bresenham 一像素宽（同 PIL line width=1）
static func _line(img: Image, a: Vector2i, b: Vector2i, col: Color) -> void:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var q := a
	while true:
		_pt(img, q, col)
		if q == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			q.x += sx
		if e2 <= dx:
			err += dx
			q.y += sy


## 实心多边形（硬边：像素整数坐标落在多边形里就填，再描一圈边，同 PIL polygon fill）
static func _poly(img: Image, pts: Array, col: Color) -> void:
	var poly := PackedVector2Array()
	var lo := Vector2i(SIZE, SIZE)
	var hi := Vector2i(-1, -1)
	for q in pts:
		poly.append(Vector2(q))
		lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
		hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), poly):
				_pt(img, Vector2i(x, y), col)
	for i in pts.size():
		_line(img, pts[i], pts[(i + 1) % pts.size()], col)
