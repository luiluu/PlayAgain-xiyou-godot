extends SceneTree
## 应用图标整理（BI 正式入口，2026-11-05）：由 生成应用图标.py 调用，别单独跑。
## godot --headless --script 生成应用图标.gd -- --in=<原图> --out=<目录> [--trim] [--android-scale=0.85]
## 1. 读原图（png/jpg/webp 都行）；--trim 时把贴着边的近白外边和圆角从四周灌成暗底（洪水填充，只吃和边相连的亮像素）。
## 2. 居中裁成正方形，补成 1024×1024 满版 → icon_source_1024.png（各平台都从它生成）。
## 3. 导出各尺寸 PNG：icon_<N>.png（16…1024，给 icns／ico 用）、android_main_192.png、
##    android_foreground_432.png（画面缩到 android-scale 居中、四周补暗底，主体留在安全区里）、android_background_432.png（纯暗底）。
## 暗底颜色取原图（去外边后）四条边一圈像素的平均值。

const SIZES := [16, 32, 48, 64, 128, 256, 512, 1024]


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var src := str(args.get("in", ""))
	var out := str(args.get("out", ""))
	if src == "" or out == "":
		push_error("要 --in=<原图> --out=<目录>")
		quit(2)
		return
	var img := Image.load_from_file(src)
	if img == null or img.is_empty():
		push_error("读不了原图：" + src)
		quit(2)
		return
	img.convert(Image.FORMAT_RGBA8)
	if args.has("trim"):
		img = _trim_light_border(img)
	var bg := _edge_color(img)
	img = _square(img, bg)
	img.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(out)
	img.save_png(out.path_join("icon_source_1024.png"))
	for n in SIZES:
		var s := img.duplicate() as Image
		s.resize(n, n, Image.INTERPOLATE_LANCZOS)
		s.save_png(out.path_join("icon_%d.png" % n))
	# macOS 版：照系统图标规格，画面缩到 824 居中、圆角（半径 185）外透明，和 Dock 里别的图标一样大。
	var mac := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	mac.fill(Color(0, 0, 0, 0))
	var body := img.duplicate() as Image
	body.resize(824, 824, Image.INTERPOLATE_LANCZOS)
	_round_corners(body, 185.0)
	mac.blit_rect(body, Rect2i(0, 0, 824, 824), Vector2i(100, 100))
	for n in SIZES:
		var m := mac.duplicate() as Image
		m.resize(n, n, Image.INTERPOLATE_LANCZOS)
		m.save_png(out.path_join("icon_mac_%d.png" % n))
	var main := img.duplicate() as Image
	main.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	main.save_png(out.path_join("android_main_192.png"))
	var scale := clampf(float(args.get("android-scale", "0.85")), 0.4, 1.0)
	var inner := int(round(432 * scale))
	var art := img.duplicate() as Image
	art.resize(inner, inner, Image.INTERPOLATE_LANCZOS)
	var fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	fg.fill(bg)
	var off := (432 - inner) / 2
	fg.blit_rect(art, Rect2i(0, 0, inner, inner), Vector2i(off, off))
	fg.save_png(out.path_join("android_foreground_432.png"))
	var back := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	back.fill(bg)
	back.save_png(out.path_join("android_background_432.png"))
	print("ICON_OK bg=%s" % bg.to_html(false))
	quit(0)


## 和图边相连的近白／透明像素（外边、圆角外的角）灌成邻近的暗色，再裁掉整行整列都被灌过的边。
func _trim_light_border(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var hit := PackedByteArray()
	hit.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in range(w):
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in range(h):
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var i := p.y * w + p.x
		if hit[i] == 1:
			continue
		var c := img.get_pixelv(p)
		if c.a > 0.5 and c.get_luminance() < 0.8:
			continue
		hit[i] = 1
		stack.append(p + Vector2i(1, 0))
		stack.append(p + Vector2i(-1, 0))
		stack.append(p + Vector2i(0, 1))
		stack.append(p + Vector2i(0, -1))
	# 外边和画面之间有一两圈抗锯齿的灰边，灌不进去；把灌到的区域向里多吃约 0.3% 边长。
	for _k in range(maxi(2, int(ceil(maxi(w, h) / 320.0)))):
		var grow := PackedInt32Array()
		for y in range(h):
			for x in range(w):
				var i := y * w + x
				if hit[i] == 0 and ((x > 0 and hit[i - 1] == 1) or (x < w - 1 and hit[i + 1] == 1) or (y > 0 and hit[i - w] == 1) or (y < h - 1 and hit[i + w] == 1)):
					grow.append(i)
		for i in grow:
			hit[i] = 1
	# 内容外框：没被灌到的像素的包围盒。
	var r := Rect2i()
	var first := true
	for y in range(h):
		for x in range(w):
			if hit[y * w + x] == 0:
				if first:
					r = Rect2i(x, y, 1, 1)
					first = false
				else:
					r = r.expand(Vector2i(x, y))
	if first:
		return img
	r.size += Vector2i.ONE
	var fill := Color(0, 0, 0, 1)
	var n := 0
	var acc := Color(0, 0, 0, 0)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if hit[y * w + x] == 0 and (x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1):
				acc += img.get_pixel(x, y)
				n += 1
	if n > 0:
		fill = Color(acc.r / n, acc.g / n, acc.b / n, 1)
	for y in range(h):
		for x in range(w):
			if hit[y * w + x] == 1:
				img.set_pixel(x, y, fill)
	return img.get_region(r)


## 圆角外的像素改透明，边上一像素做抗锯齿。
func _round_corners(img: Image, r: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var cx := clampf(x + 0.5, r, w - r)
			var cy := clampf(y + 0.5, r, h - r)
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d > r - 1.0:
				var c := img.get_pixel(x, y)
				c.a *= clampf(r - d, 0.0, 1.0)
				img.set_pixel(x, y, c)


func _edge_color(img: Image) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var acc := Color(0, 0, 0, 0)
	var n := 0
	for x in range(w):
		acc += img.get_pixel(x, 0) + img.get_pixel(x, h - 1)
		n += 2
	for y in range(h):
		acc += img.get_pixel(0, y) + img.get_pixel(w - 1, y)
		n += 2
	return Color(acc.r / n, acc.g / n, acc.b / n, 1)


## 居中补成正方形（长边为准，短边两侧补暗底），不拉伸。
func _square(img: Image, bg: Color) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	if w == h:
		return img
	var s := maxi(w, h)
	var out := Image.create(s, s, false, Image.FORMAT_RGBA8)
	out.fill(bg)
	out.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((s - w) / 2, (s - h) / 2))
	return out
