extends Node
## T578 内存探针（只量不改）：玩家存档载入后，量进技能页前、技能页里逛一圈（五人各切被动页、移动、翻页）、关掉技能页之后的
## 静态内存（OS.get_static_memory_usage／峰值）与显存纹理（Performance RENDER_TEXTURE_MEM_USED，要带窗口跑才有渲染器）。
## 跑法同 t578_skill_page_probe.gd，参数 --save=… [--release] [--set=res://modes/xiyou/ui/xui.gd:KEEP_ICON_SHEETS=false]；带窗口时加 --audio-driver Dummy。

var save_path := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="): save_path = arg.substr(7)
		elif arg == "--release": ReleaseEntry.simulate_release = true
		elif arg.begins_with("--set=res://modes/xiyou/ui/xui.gd:KEEP_ICON_SHEETS="):
			XUI.KEEP_ICON_SHEETS = arg.ends_with("=true")
	_run.call_deferred()


func mb(v) -> String:
	return "%.1f" % (float(v) / 1048576.0)


func report(tag: String) -> void:
	print("MEM %s static=%s static_peak=%s tex=%s vmem=%s sheets=%d" % [tag, mb(OS.get_static_memory_usage()), mb(OS.get_static_memory_peak_usage()),
		mb(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)), mb(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)), XUI._icon_sheets.size()])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	XSave.dir_override = "user://t578_probe"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	XSave._load_data(d, 1, JSON.stringify(d))
	var s := XState.current
	print("KEEP_ICON_SHEETS=%s release=%s" % [str(XUI.KEEP_ICON_SHEETS), str(ReleaseEntry.simulate_release)])
	await _frames(10)
	report("before")
	var page := XSkillScene.new()
	add_child(page)
	await _frames(3)
	report("open")
	for ai in s.party.size():
		var types := page.types()
		page.type_index = maxi(types.find(4), 0)
		page.mode = "list"
		page.index = 0
		page._refresh()
		await _frames(2)
		for i in 10:
			page._move(1, false, false)
			await _frames(1)
		page._page(1)
		await _frames(2)
		page.mode = "type"
		page.change_actor(1)
		await _frames(2)
	report("in_page")
	# 像素：取一格图标，看渲染器能不能读回图（专项里两态逐像素比对要靠它）
	var t: AtlasTexture = XUI.icon_texture(100)
	var img: Image = t.atlas.get_image() if t != null and t.atlas != null else null
	print("PIXELS_READABLE=%s fmt=%s" % [str(img != null and not img.is_empty()), str(img.get_format()) if img != null else "-"])
	page.queue_free()
	await _frames(10)
	report("closed")
	get_tree().quit(0)
