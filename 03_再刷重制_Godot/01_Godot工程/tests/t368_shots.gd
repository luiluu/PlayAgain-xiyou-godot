extends Node
## 工具（不是专项）：T368 卡 G 装备检索「筛选小块」验收截图。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t368_shots.tscn -- --out=<目录>
## 16:9 拍在 800×450 窗口（视口 1280×720），20:9 拍在 1000×450（同 xiyou_ui_skin_card_e 的拍法）。
## 张：默认；两个品质一个部位；光标在部位图标上预览名字（R1）；搜词条点之前／点之后（输入框出来、写了字）；没有结果；挑选框；20:9；对照：T361 版（SKIN_PAGE_R9 关）、皮肤关（网页版）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const R9Test = preload("res://tests/xiyou_t368_gear_r9.gd")

var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _frames(n := 20) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _win(w: int, h: int, wide: bool) -> void:
	var win := get_window()
	win.unresizable = false
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT if wide else Window.CONTENT_SCALE_ASPECT_KEEP
	win.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	await get_tree().create_timer(0.6).timeout
	await _frames(12)


func _chip(p: XSkinGearSearch, group: String, key := "") -> int:
	for i in p.chips.size():
		if str(p.chips[i].group) == group and (key == "" or str(p.chips[i].key) == key):
			return i
	return -1


## 挑一个部位，它有两档以上品质的件：[品质a, 品质b, 部位]
func _pick_two(gs: XGearSearch) -> Array:
	var by := {}
	for r in gs.source:
		var t := XGearQuery.type_key(r.item)
		if not by.has(t):
			by[t] = {}
		by[t][str(XQuality.grade_of(XGearQuery.quality(r.item)))] = true
	var best := ""
	for t in by:
		if best == "" or by[t].size() > by[best].size():
			best = t
	var qs: Array = by[best].keys()
	return [qs[0], qs[1] if qs.size() > 1 else qs[0], best]


func _open(s: XState) -> Array:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	XGearSearch.reset_session()
	var gs := XGearSearch.open(host, XGearQuery.collection(s))
	await _frames()
	return [host, gs]


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	TestEnv.isolate("t368_shots")
	XSplashScreen.shown = true
	XConfig.path_override = "user://t368_shots_options.json"
	XConfig.ensure_loaded()
	XUpdateClient.ENABLED = false
	XUiSkin.FORCE = true
	var s := R9Test._state()
	await _win(800, 450, false)
	var hg: Array = await _open(s)
	var gs: XGearSearch = hg[1]
	var p: XSkinGearSearch = gs.page
	await _shot("1_default_16x9")
	# 两个品质一个部位
	p.set_focus("filters")
	var pick := _pick_two(gs)
	p.press_chip(_chip(p, "quality", pick[0]))
	p.press_chip(_chip(p, "quality", pick[1]))
	p.press_chip(_chip(p, "type", pick[2]))
	await _shot("2_two_quality_one_type")
	p.press_chip(_chip(p, "reset"))
	# R1 P3-2：光标停在没选中的部位图标上，「部位」旁预览名字
	p.set_focus("filters")
	p.cursor = _chip(p, "type", pick[2])
	p.filters.queue_redraw()
	await _shot("c_type_cursor_preview")
	# 搜词条：点之前（光标停在按钮上）、点之后
	p.set_focus("filters")
	p.cursor = _chip(p, "search")
	p.filters.queue_redraw()
	await _shot("3_search_before")
	p.press_chip(_chip(p, "search"))
	p.search_edit.text = "暴击"
	p.search_edit.text_changed.emit("暴击")
	await _shot("4_search_after_typing")
	p.search_edit.text_submitted.emit("暴击")
	await _shot("5_search_done")
	# 没有结果
	gs._on_field("这词不存在", "query")
	await _shot("6_no_result")
	gs._on_field("", "query")
	# 挑选框（更多排序）
	p.press_chip(_chip(p, "sort", "more"))
	await _shot("7_picker_sort")
	p.close_picker()
	# 20:9
	await _win(1000, 450, true)
	await _shot("8_default_20x9")
	p.press_chip(_chip(p, "quality", pick[0]))
	p.press_chip(_chip(p, "quality", pick[1]))
	p.press_chip(_chip(p, "type", pick[2]))
	await _shot("9_two_quality_one_type_20x9")
	(hg[0] as Node).queue_free()
	await _win(800, 450, false)
	# 对照：T361 版、皮肤关
	XGearSearch.SKIN_PAGE_R9 = false
	hg = await _open(s)
	await _shot("a_before_t361")
	(hg[0] as Node).queue_free()
	XGearSearch.SKIN_PAGE_R9 = true
	XUiSkin.FORCE = false
	XUiSkin.ENABLED = false
	hg = await _open(s)
	await _shot("b_skin_off")
	(hg[0] as Node).queue_free()
	XUiSkin.ENABLED = true
	print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
	get_tree().quit.call_deferred(0)
