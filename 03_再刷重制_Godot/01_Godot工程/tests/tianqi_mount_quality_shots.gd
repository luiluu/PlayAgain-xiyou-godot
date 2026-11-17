extends Node
## 工具（不是专项）：T112 稀有坐骑显示品质截图——详情页（说明卡）和获得提示（XTreasurePopup）的品质色，天启篇对西游档。
## 用法（要真窗口，不能 --headless；带窗口一律静音）：
##   godot --path 01_Godot工程 res://tests/tianqi_mount_quality_shots.tscn --audio-driver Dummy -- --out=<目录>
const Kit := preload("res://tests/lib/tq_save_kit.gd")
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _phys(n := 1) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _shot(name: String) -> void:
	await _phys(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _scene(title: String) -> Array:
	var holder := Node2D.new()
	add_child(holder)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.16)
	bg.size = Vector2(1280, 720)
	holder.add_child(bg)
	var lab := Label.new()
	lab.text = title
	lab.position = Vector2(20, 10)
	lab.add_theme_font_size_override("font_size", 28)
	holder.add_child(lab)
	var ids := [7997, 7998, 4483]
	for i in ids.size():
		var rec := XDB.rec("Armors", ids[i])
		var card := XHelpCard.new()
		holder.add_child(card)
		card.place_original(Rect2(i * 425 - 432, 110, 400, 36))  # 卡片落在矩形右侧约 440px 处
		card.show_for(rec, "armor")
		var pop := XTreasurePopup.new()
		holder.add_child(pop)
		pop.setup(rec, 1, Vector2(500 + i * 260, 120), 0, 1)
		pop._wait_in = 0
		pop._wait_hold = 100000
		pop._alpha = 255.0
	return [holder]


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数或无窗口")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var kit = Kit.new("tianqi_mount_quality_shots")
	XMessageBox.auto = false
	var s: XState = Kit.new_game("xunchang")
	var a := _scene("天启篇：稀有坐骑显示品质")
	await _shot("天启篇_详情页与获得提示")
	a[0].queue_free()
	await _phys(2)
	XState.current = XState.new()
	var b := _scene("西游档：照数据（普通）")
	await _shot("西游档_详情页与获得提示")
	b[0].queue_free()
	XState.current = s
	kit.teardown()
	print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
	get_tree().quit.call_deferred(0)
