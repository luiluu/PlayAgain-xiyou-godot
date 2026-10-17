extends Node
## 同一测试在编辑器与导出包中运行；HOME 由验证脚本隔离。无真实玩家存档。
var results := []

func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", detail)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var font := XUI.font()
	var text := "中文自动换行验证：天地玄黄宇宙洪荒。"
	check("chinese_glyphs", font.has_char("中".unicode_at(0)) and font.has_char("文".unicode_at(0)))
	var paragraph := TextParagraph.new()
	paragraph.width = 120
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	paragraph.add_string(text, font, 26, "zh")
	check("chinese_line_breaks", paragraph.get_line_count() > 1, paragraph.get_line_count())
	check("skin_texture", XUI.skin() != null)
	check("actor_texture", XDB.img_path("sv_actors", str(XDB.rec("Actors", 1).battlerName)) != "")
	var se := XDB.audio_path("se", str(XDB.system().sounds[0].name))
	check("audio_resource", se != "" and load(se) is AudioStream)
	GameApp.current_mode = "xiyou"
	XState.new_game(3, 1, [8])
	check("save_namespace", XSave.dir() == "user://modes/xiyou")
	check("save_write", XSave.save(1))
	XState.current.gold = 4321
	check("save_reload", XSave.load(1) and XState.current.gold != 4321)
	XSave.remove(1)
	var input := LineEdit.new()
	input.position = Vector2(80, 220)
	input.size = Vector2(700, 50)
	input.text = "中文输入验收"
	input.add_theme_font_override("font", font)
	add_child(input)
	check("unicode_text", input.text == "中文输入验收")
	var label := Label.new()
	label.position = Vector2(80, 80)
	label.size = Vector2(360, 120)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 26)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text.repeat(3)
	add_child(label)
	var fullscreen := false
	if DisplayServer.get_name() != "headless":
		var window := get_window()
		window.mode = Window.MODE_FULLSCREEN
		for i in 5:
			await get_tree().process_frame
		fullscreen = window.mode == Window.MODE_FULLSCREEN
		check("fullscreen", fullscreen)
		window.mode = Window.MODE_WINDOWED
		for i in 5:
			await get_tree().process_frame
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--out="):
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(arg.substr(6).path_join("Mac导出_字体与输入.png"))
	print("MAC_EXPORT_INFO=" + JSON.stringify({"editor": OS.has_feature("editor"), "display": DisplayServer.get_name(),
		"ime_supported": DisplayServer.has_feature(DisplayServer.FEATURE_IME), "saveDirectory": OS.get_user_data_dir(),
		"chineseLines": paragraph.get_line_count(), "fullscreen": fullscreen, "version": Engine.get_version_info().string}))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
