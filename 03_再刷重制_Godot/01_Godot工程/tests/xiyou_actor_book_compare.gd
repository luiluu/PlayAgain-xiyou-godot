extends Node
## 【cc·白龙·未经审查】人物图鉴立绘逐张比（raven6；工具，不进检查）：读 mv_oracle/real/actor_book_real.cjs 在无头 Chrome 量的冻结正式源结果，
## 逐个在重制 XActorBook 里选中同一角色，比状态窗立绘：用的图、整张图大小、可见帧（按原版那一刻的格号取同一格）、画出来的矩形
## （窗口坐标）、平滑（XActorBook 状态窗画布最终的 texture_filter）；再把两边用到的图逐像素比（原版 app.nw 的 PNG 与 generated 的源 PNG）。
## 饿狼 173 原版代码里有呼吸，实机被多帧插件的图鉴包装盖掉（量到不呼吸），竖直方向仍放宽 1% 防相位。
## 环境变量：XIYOU_BOOK_REAL＝result.json，XIYOU_APP＝…/app.nw，XIYOU_BOOK_OUT＝输出前缀（写 .json 与 .md，只列有差异的）。
## 跑法：godot --headless --path . tests/xiyou_actor_book_compare.tscn
const EPS_PX := 0.6


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	if OS.get_environment("XIYOU_BOOK_REAL") == "":
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1, "skipped": "工具场景：设 XIYOU_BOOK_REAL 才比"}))
		get_tree().quit.call_deferred(0)
		return
	var real = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("XIYOU_BOOK_REAL")))
	var app := OS.get_environment("XIYOU_APP")
	var out_prefix := OS.get_environment("XIYOU_BOOK_OUT")
	var ids: Array = real.actors.map(func(v): return int(v))
	XState.current = XState.new_game_blank()
	XState.current.switches[2494] = true
	var book := XActorBook.new()
	add_child(book)
	await get_tree().process_frame
	var rows := []
	var table := []
	var measured := 0
	for id in ids:
		var w = real.result.get(str(id), {})
		var g := _snap(book, id, w)
		if not g.has("error"):
			measured += 1
		var diffs := _compare(id, w, g, app)
		rows.append({"actor": id, "name": XDB.rec("Actors", id).get("name", ""), "real": w, "remake": g, "diffs": diffs})
		for d in diffs:
			table.append("| %d %s | %s | %s | %s |" % [id, XDB.rec("Actors", id).get("name", ""), d.image, d.what, d.verdict])
	var f := FileAccess.open(out_prefix + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, " "))
	f.close()
	f = FileAccess.open(out_prefix + ".md", FileAccess.WRITE)
	f.store_string("| 角色 | 图 | 差异 | 判定 |\n| --- | --- | --- | --- |\n" + "\n".join(table) + "\n")
	f.close()
	print("BOOK_COMPARE=" + JSON.stringify({"actors": ids.size(), "measured": measured, "diffRows": table.size(),
		"actorsWithDiff": rows.filter(func(r): return not r.diffs.is_empty()).size()}))
	get_tree().quit.call_deferred(0)


## 重制：选中该角色后状态窗立绘画在哪（窗口坐标）。格号取原版那一刻的格（frame.x ÷ 格宽），这样两边比的是同一格
func _snap(book: XActorBook, id: int, w) -> Dictionary:
	var i := XActorBook.index_ids().find(id)
	if i < 0:
		return {"error": "不在目录"}
	book.index = i
	book._select_actor()
	if book._sprite_tex == null:
		return {"none": true}
	var tex_size := Vector2(book._sprite_tex.get_size())
	var pattern := 0
	if w is Dictionary and w.has("frame") and not book._sprite_spec.get("multi", false):
		pattern = roundi(float(w.frame[0]) / (tex_size.x / 9.0))
	var r: Array = XActorBook.sprite_rect(id, book._sprite_spec, tex_size, pattern)
	var dst: Rect2 = r[0]
	var src: Rect2 = r[1]
	var pad := XMVWindow.PADDING
	var node: CanvasItem = book.status_win.canvas
	var filt := node.texture_filter
	while filt == CanvasItem.TEXTURE_FILTER_PARENT_NODE and node.get_parent() is CanvasItem:
		node = node.get_parent()
		filt = node.texture_filter
	if filt == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
		filt = int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", 1)) as CanvasItem.TextureFilter
	return {"tex": book._sprite_tex.resource_path.replace("res://modes/xiyou/generated/", ""), "bmp": [tex_size.x, tex_size.y],
		"src": [src.position.x, src.position.y, src.size.x, src.size.y], "rect": [dst.position.x + pad, dst.position.y + pad, dst.size.x, dst.size.y],
		"smooth": filt in [CanvasItem.TEXTURE_FILTER_LINEAR, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS], "pattern": pattern}


func _compare(id: int, w, g: Dictionary, app: String) -> Array:
	var out := []
	if not (w is Dictionary) or w.has("error") or w.is_empty():
		return [{"image": "立绘", "what": "原版没量到：" + str(w.get("error", "") if w is Dictionary else w), "verdict": "待查"}]
	if g.has("error"):
		return [{"image": "立绘", "what": "重制没量到：" + str(g.error), "verdict": "待查"}]
	if w.get("none", false) or g.get("none", false):
		if not (w.get("none", false) and g.get("none", false)):
			out.append({"image": "立绘", "what": "一边没画：原版 %s，重制 %s" % [not w.get("none", false), not g.get("none", false)], "verdict": "会改变显示"})
		return out
	var wu := str(w.url).trim_prefix("img/").uri_decode()
	var gu := str(g.tex).trim_prefix("img/")
	var img := wu.get_file()
	if wu != gu:
		out.append({"image": img, "what": "图不同：原版 %s，重制 %s" % [wu, gu], "verdict": "待查"})
	if absf(float(w.bmp[0]) - float(g.bmp[0])) > 0.01 or absf(float(w.bmp[1]) - float(g.bmp[1])) > 0.01:
		out.append({"image": img, "what": "整张图 %s×%s→%s×%s" % [w.bmp[0], w.bmp[1], g.bmp[0], g.bmp[1]], "verdict": "待查"})
	var wf: Array = w.frame
	var bad_src := false
	for k in 4:
		if absf(float(wf[k]) - float(g.src[k])) > 0.01:
			bad_src = true
	if bad_src:
		out.append({"image": img, "what": "取图范围 %s→%s" % [_fmt(wf), _fmt(g.src)], "verdict": "会改变显示"})
	var sx := float(w.scale[0])
	var sy := float(w.scale[1])
	var wr := [float(w.pos[0]) - float(w.anchor[0]) * float(wf[2]) * sx, float(w.pos[1]) - float(w.anchor[1]) * float(wf[3]) * sy, float(wf[2]) * sx, float(wf[3]) * sy]
	var bad := false
	for k in 4:
		var eps := EPS_PX
		if id == 173 and k in [1, 3]:
			eps = maxf(EPS_PX, float(wr[3]) * 0.01)
		if absf(wr[k] - float(g.rect[k])) > eps:
			bad = true
	if bad:
		out.append({"image": img, "what": "画出的矩形（左,上,宽,高）%s→%s" % [_fmt(wr), _fmt(g.rect)], "verdict": "会改变显示"})
	var scaled := absf(sx - 1.0) > 0.0001 or absf(sy - 1.0) > 0.0001 or absf(wr[0] - roundf(wr[0])) > 0.01 or absf(wr[1] - roundf(wr[1])) > 0.01
	if bool(w.smooth) != bool(g.smooth) and scaled:
		out.append({"image": img, "what": "平滑 %s→%s（缩放或落在半像素上）" % [w.smooth, g.smooth], "verdict": "会改变显示"})
	_pixels(out, app, wu)
	return out


func _pixels(out: Array, app: String, name: String) -> void:
	var img := name.get_file()
	var src := _load_by_content(app.path_join("img").path_join(name))
	var dst := Image.load_from_file(ProjectSettings.globalize_path("res://modes/xiyou/generated/img/" + name))
	if src == null or dst == null:
		out.append({"image": img, "what": "读不出图（原版 %s，重制 %s）" % [src != null, dst != null], "verdict": "待查"})
	elif src.get_size() != dst.get_size():
		out.append({"image": img, "what": "图尺寸 %s→%s" % [src.get_size(), dst.get_size()], "verdict": "待查"})
	else:
		src.convert(Image.FORMAT_RGBA8)
		dst.convert(Image.FORMAT_RGBA8)
		if src.get_data() != dst.get_data():
			var n := 0
			for y in src.get_height():
				for x in src.get_width():
					if src.get_pixel(x, y) != dst.get_pixel(x, y):
						n += 1
			out.append({"image": img, "what": "像素不同 %d 个（共 %d）" % [n, src.get_width() * src.get_height()], "verdict": "待查"})


## 原版有 .png 扩展名、内容是 JPEG／WebP 的图（162 诛仙 guanxi7_1）：NW.js 按内容解码，这里也按内容读
func _load_by_content(path: String) -> Image:
	var buf := FileAccess.get_file_as_bytes(path)
	if buf.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if buf[0] == 0xFF and buf[1] == 0xD8:
		err = img.load_jpg_from_buffer(buf)
	elif buf.slice(0, 4).get_string_from_ascii() == "RIFF" and buf.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(buf)
	else:
		err = img.load_png_from_buffer(buf)
	return img if err == OK else null


func _fmt(v: Array) -> String:
	return "(" + ",".join(v.map(func(x): return str(snappedf(float(x), 0.01)))) + ")"
