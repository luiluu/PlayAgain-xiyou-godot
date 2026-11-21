extends Node
## 【cc·T338·未经审查】界面细节 D2 行内图标实量（私密仓 重制设定/界面细节规范_v0.1.md 规范 4.1「实量流程」）：
## 在 100% 与 130% 字号下，对物品列表行（XSkinList）、提示道主句（XSkinNoticeLane.Chip）、Boss 状态胶囊（照 skin_boss_status._paint_bar 的 state 画法）
## 各排几行，真窗口截图，逐像素量「图标墨迹中心」与「文字墨迹中心」的纵向差，叠行中线（绿）／文字墨迹中心线（红）／图标墨迹中心线（青）出 2× 放大对照图。
## 必须带窗口跑，带 --out=<目录>：
##   godot --audio-driver Dummy --path <工程> res://tests/xiyou_icon_measure.tscn -- --out=<目录>
## 无窗口（headless）时只断言 ICON_DY_K 在 0～0.06 内、inline_icon_rect 出口几何。
## 差值约定：dy＝图标墨迹中心 y − 文字墨迹中心 y（正＝图标比文字低）；实量均值 |dy| < 0.5px → ICON_DY_K 保持 0.0；图标偏高 ≥ 1px → 填 −dy／字号。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const SHOT := Vector2i(1280, 720)
const ICON_IDS := [100, 101, 102, 103]
const SAMPLE := "装备名称永"

var results: Array = []
var out_dir := ""
var report: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func _run() -> void:
	TestEnv.isolate("xiyou_icon_measure")
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XUiSkin._clock_ms = 100000
	check("icon_dy_k_range", XUiSkin.ICON_DY_K >= 0.0 and XUiSkin.ICON_DY_K <= 0.06, XUiSkin.ICON_DY_K)
	var r := XUiSkin.inline_icon_rect(10.4, 100.0, 24.0, 16)
	check("inline_icon_rect_geometry", r.size == Vector2(24, 24) and r.position.x == 10.0 and r.position.y == roundf(88.0 + roundf(16.0 * XUiSkin.ICON_DY_K)), r)
	if out_dir != "" and DisplayServer.get_name() != "headless":
		get_window().size = SHOT
		get_viewport().gui_disable_input = true
		for pct in [100, 130]:
			XFontScale.set_value("global", pct)
			await _scene_list(pct)
			await _scene_chip(pct)
			await _scene_capsule(pct)
		_write_report()
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XUiSkin._clock_ms = -1
	XFontScale.set_value("global", 100)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _grab() -> Image:
	await frames(6)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _bg() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color("090808")
	bg.size = Vector2(SHOT)
	return bg


func _differs(a: Color, b: Color) -> bool:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) > 0.12


## 区域内与参照色不同的像素的纵向范围，返回 [最小 y, 最大 y]（含），没有返回 []
func _ink_y(img: Image, rect: Rect2i, ref: Color) -> Array:
	var y0 := 99999
	var y1 := -1
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if _differs(img.get_pixel(x, y), ref):
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	return [] if y1 < 0 else [y0, y1]


func _mid(b: Array) -> float:
	return (float(b[0]) + float(b[1]) + 1.0) / 2.0


## 记一行：scene 名、字号、行中线、图标 rect、文字 rect（都是截图像素坐标）
func _measure(img: Image, scene: String, pct: int, fs: int, row_cy: float, icon_r: Rect2i, text_r: Rect2i, ref: Color) -> Dictionary:
	var ib := _ink_y(img, icon_r, ref)
	var tb := _ink_y(img, text_r, ref)
	var row := {"scene": scene, "pct": pct, "fs": fs, "row_cy": row_cy, "icon": ib, "text": tb}
	if not ib.is_empty() and not tb.is_empty():
		row["icon_cy"] = _mid(ib)
		row["text_cy"] = _mid(tb)
		row["dy"] = _mid(ib) - _mid(tb)
		row["icon_vs_row"] = _mid(ib) - row_cy
		row["text_vs_row"] = _mid(tb) - row_cy
	report.append(row)
	check("measured_%s_%d_%d" % [scene, pct, report.size()], not ib.is_empty() and not tb.is_empty(), row)
	return row


# ---- 物品列表行 ----
func _scene_list(pct: int) -> void:
	var root := Control.new()
	root.size = Vector2(SHOT)
	root.add_child(_bg())
	var l := XSkinList.new()
	l.position = Vector2(40, 60)
	l.size = Vector2(520, XUiSkin.ROW_H * 4.0)
	l.active = false
	root.add_child(l)
	var items := []
	for id in ICON_IDS:
		items.append({"text": SAMPLE, "icon": id})
	l.set_items(items)
	add_child(root)
	var img := await _grab()
	var fs := l.font_size
	var rows := []
	for i in ICON_IDS.size():
		var cr := l.cell_rect(i)
		var gy := l.position.y + cr.position.y
		var ix := int(l.position.x + cr.position.x + 14.0)
		var cy := gy + cr.size.y / 2.0
		var ref := img.get_pixel(ix + l.icon_size + 3, int(cy))
		var row := _measure(img, "list", pct, fs, cy, Rect2i(ix, int(gy), l.icon_size, int(cr.size.y)),
			Rect2i(ix + l.icon_size + 8, int(gy), int(fs * SAMPLE.length() * 1.1), int(cr.size.y)), ref)
		rows.append(row)
	_overlay(img, "list_%d" % pct, Rect2i(int(l.position.x), int(l.position.y), 300, int(XUiSkin.ROW_H * 2.0)), rows.slice(0, 2), int(l.position.x), int(l.position.y))
	root.queue_free()
	await frames(2)


# ---- 提示道主句 ----
func _scene_chip(pct: int) -> void:
	var root := Control.new()
	root.size = Vector2(SHOT)
	root.add_child(_bg())
	var rows := []
	var chips := []
	for i in 2:
		var chip := XSkinNoticeLane.Chip.new()
		chip.layout_for({"title": SAMPLE + "已获得", "icon": ICON_IDS[i]}, Vector2(SHOT))
		chip.position = Vector2(40, 60 + i * 70)
		root.add_child(chip)
		chips.append(chip)
	add_child(root)
	var img := await _grab()
	for chip in chips:
		var fs: int = chip.title_fs()
		var ix := int(chip.position.x + XSkinNoticeLane.PAD_X)
		var cy: float = chip.position.y + chip.size.y / 2.0
		var ref := img.get_pixel(ix + int(XSkinNoticeLane.ICON) + 3, int(cy))
		var x0 := ix + int(XSkinNoticeLane.ICON + XSkinNoticeLane.GAP)
		rows.append(_measure(img, "notice", pct, fs, cy, Rect2i(ix, int(chip.position.y) + 5, int(XSkinNoticeLane.ICON), int(chip.size.y) - 10),
			Rect2i(x0, int(chip.position.y) + 5, int(fs * SAMPLE.length() * 1.1), int(chip.size.y) - 10), ref))
	_overlay(img, "notice_%d" % pct, Rect2i(40, 50, 300, 150), rows, 40, 50)
	root.queue_free()
	await frames(2)


# ---- Boss 状态胶囊（照 skin_boss_status._paint_bar 的 state 分支）----
func _scene_capsule(pct: int) -> void:
	var root := Control.new()
	root.size = Vector2(SHOT)
	root.add_child(_bg())
	var cap := Control.new()
	cap.position = Vector2(40, 60)
	cap.size = Vector2(300, 40)
	var f := XUiSkin.font("body")
	var fs := XSkinBossStatus.CAP_FS
	cap.draw.connect(func() -> void:
		var x := 4.0
		var r := Rect2(x, 3.0, 220.0, XSkinBossStatus.ROW_H - 6.0)
		XSkinBossStatus._capsule(cap.get_canvas_item(), r, Color(XUiSkin.line_c(), 0.5))
		var tex := XUiSkin.icon(ICON_IDS[0])
		cap.draw_texture_rect(tex, XUiSkin.inline_icon_rect(x + 7.0, 20.0, 24.0, XSkinBossStatus.CAP_FS) if XUiSkin.detail_on() else Rect2(x + 7.0, 8.0, 24.0, 24.0), false)
		XSkinBossStatus._txt(cap, f, SAMPLE, x + 36.0, 0, 170.0, "left", XUiSkin.TEXT, XSkinBossStatus.CAP_FS, XSkinBossStatus.ROW_H))
	root.add_child(cap)
	add_child(root)
	var img := await _grab()
	var cy := cap.position.y + 20.0
	var ix := int(cap.position.x + 4.0 + 7.0)
	var ref := img.get_pixel(ix + 24 + 2, int(cy))
	var row := _measure(img, "capsule", pct, fs, cy, Rect2i(ix, int(cap.position.y) + 5, 24, 30),
		Rect2i(ix + 29, int(cap.position.y) + 5, int(fs * SAMPLE.length() * 1.1), 30), ref)
	_overlay(img, "capsule_%d" % pct, Rect2i(40, 50, 260, 60), [row], 40, 50)
	root.queue_free()
	await frames(2)


## 2× 放大对照图：绿＝行中线，红＝文字墨迹中心，青＝图标墨迹中心
func _overlay(img: Image, name: String, crop: Rect2i, rows: Array, ox: int, oy: int) -> void:
	var sub := img.get_region(crop)
	sub.resize(crop.size.x * 2, crop.size.y * 2, Image.INTERPOLATE_NEAREST)
	for row in rows:
		if not row.has("icon_cy"):
			continue
		_hline(sub, (float(row.row_cy) - crop.position.y) * 2.0, Color(0.2, 1.0, 0.2, 0.9), 0)
		_hline(sub, (float(row.text_cy) - crop.position.y) * 2.0, Color(1.0, 0.2, 0.2, 0.9), 1)
		_hline(sub, (float(row.icon_cy) - crop.position.y) * 2.0, Color(0.2, 0.9, 1.0, 0.9), 2)
	DirAccess.make_dir_recursive_absolute(out_dir)
	sub.save_png(out_dir.path_join("measure_%s_2x.png" % name))


func _hline(img: Image, y: float, col: Color, x_off: int) -> void:
	var yy := clampi(int(y), 0, img.get_height() - 1)
	for x in range(x_off, img.get_width(), 3):
		img.set_pixel(x, yy, col)


func _write_report() -> void:
	var by := {}
	for r in report:
		if not r.has("dy"):
			continue
		var k := "%s_%d" % [r.scene, r.pct]
		if not by.has(k):
			by[k] = {"n": 0, "dy_sum": 0.0, "fs": r.fs, "icon_vs_row": 0.0, "text_vs_row": 0.0}
		by[k].n += 1
		by[k].dy_sum += float(r.dy)
		by[k].icon_vs_row += float(r.icon_vs_row)
		by[k].text_vs_row += float(r.text_vs_row)
	var summary := {}
	var total := 0.0
	var cnt := 0
	for k in by:
		var s: Dictionary = by[k]
		summary[k] = {"fs": s.fs, "rows": s.n, "dy_mean": s.dy_sum / s.n, "icon_vs_row_mean": s.icon_vs_row / s.n, "text_vs_row_mean": s.text_vs_row / s.n}
		total += s.dy_sum
		cnt += s.n
	var out := {"ICON_DY_K": XUiSkin.ICON_DY_K, "summary": summary, "dy_mean_all": total / maxf(cnt, 1.0), "rows": report}
	var fa := FileAccess.open(out_dir.path_join("measure.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, "  "))
	fa.close()
	print("SUMMARY=" + JSON.stringify(summary) + " dy_mean_all=" + str(total / maxf(cnt, 1.0)))
