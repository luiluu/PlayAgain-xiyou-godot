extends Node
## 称号头顶名牌画面（XDesignationPlate）与原版位图逐像素比（白龙 ui-pixel4）：
## 原版：ui_reference/review_system_pages.js 的 px4_designation（地图 5 玩家精灵的 _nameSpriteOL，180×78，
## 称号表第 1 条「征服者」图标 1468 颜色 #7b68ee，开局名「测试名」），位图存成 tests/fixtures/designation_plate_ref.png。
## Godot：名牌单独画进透明 SubViewport，逐像素比 RGBA（只能窗口模式；headless 不渲染，只查画布尺寸）。
## 窗口模式加 -- --out=<目录> 另存 Godot 图与差值图。
const REF := "res://tests/fixtures/designation_plate_ref.png"
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	s.actor_name = "测试名"
	var d: Dictionary = XDesignation.table()[0]
	s.designation = {"name": d.name, "icon": d.icon, "color": d.color}
	check("designation_1", d.name == "征服者" and int(d.icon) == 1468 and str(d.color).to_lower() == "#7b68ee", d)
	var vp := SubViewport.new()
	vp.size = Vector2i(180, 78)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var plate := XDesignationPlate.new()
	vp.add_child(plate)
	plate.refresh(s)
	check("plate_size", plate.size == Vector2(180, 78), plate.size)
	if DisplayServer.get_name() != "headless":
		for i in range(4):
			await RenderingServer.frame_post_draw
		var got := vp.get_texture().get_image()
		got.convert(Image.FORMAT_RGBA8)
		var ref := Image.load_from_file(ProjectSettings.globalize_path(REF))
		ref.convert(Image.FORMAT_RGBA8)
		var diff := Image.create(180, 78, false, Image.FORMAT_RGBA8)
		var big := 0
		var sum := 0.0
		for y in range(78):
			for x in range(180):
				var a := got.get_pixel(x, y)
				var b := ref.get_pixel(x, y)
				# 预乘 alpha 后比（透明处的颜色不算）
				var m := maxf(maxf(absf(a.r * a.a - b.r * b.a), absf(a.g * a.a - b.g * b.a)), maxf(absf(a.b * a.a - b.b * b.a), absf(a.a - b.a))) * 255.0
				sum += m
				if m > 32:
					big += 1
				diff.set_pixel(x, y, Color(m / 255.0, 0, 0, 1))
		# 三段（图标 0～32、称号 32～54、名字 54～76）墨迹框（alpha>0.5），原版与 Godot 各边差不超过 1
		for band in [[0, 32, "icon"], [32, 54, "title"], [54, 78, "name"]]:
			var bg := _ink(got, band[0], band[1])
			var br := _ink(ref, band[0], band[1])
			var dd := [bg.position.x - br.position.x, bg.position.y - br.position.y, bg.end.x - br.end.x, bg.end.y - br.end.y]
			print("墨迹框 %s：Godot %s 原版 %s" % [band[2], bg, br])
			check("ink_" + band[2], dd.all(func(v): return absi(int(v)) <= 1), [bg, br])
		var mean := sum / (180.0 * 78.0)
		print("名牌像素差：平均 %.2f，差>32 的像素 %d／%d" % [mean, big, 180 * 78])
		check("plate_pixels", mean < 5.0 and big < 180 * 78 * 0.06, [mean, big])  # 字形光栅化（Chrome 合成粗体与 Godot embolden）差，墨迹框另比
		if out_dir != "":
			got.save_png(out_dir.path_join("designation_plate_godot.png"))
			diff.save_png(out_dir.path_join("designation_plate_diff.png"))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit.call_deferred(0 if passed == total else 1)


static func _ink(img: Image, y0: int, y1: int) -> Rect2i:
	var x0 := 9999
	var x1 := -1
	var ya := 9999
	var yb := -1
	for y in range(y0, y1):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.5:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				ya = mini(ya, y)
				yb = maxi(yb, y)
	return Rect2i(x0, ya, x1 - x0 + 1, yb - ya + 1) if x1 >= 0 else Rect2i()
