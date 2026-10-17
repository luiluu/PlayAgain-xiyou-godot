extends Node
## 同一测试在编辑器与导出包中运行；HOME 由验证脚本隔离。无真实玩家存档。
signal interactive_done
var results := []
var _interactive_active := false
var _compositions: Array[String] = []
var _audio_verified := false
var _output_dir := ""

func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", detail)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_output_dir = arg.substr(6)
	var font := XUI.font()
	check("authored_font", font is FontFile and ResourceLoader.exists(GameFont.PATH), font.get_font_name())
	check("power_panel_text_width", absf(font.get_string_size("雷电承伤 90%", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x - 84.15) < 0.5)
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
	var isolated := OS.get_user_data_dir().begins_with(OS.get_environment("HOME")) and (OS.get_environment("HOME").get_file().begins_with("xiyou_test_home_") or OS.get_environment("HOME").get_file().begins_with("xiyou_export_home_"))
	# 只允许验证运行器新建的 HOME，绝不向日常目录写入。
	check("isolated_home", isolated)
	if not isolated:
		print("TEST_RESULT=" + JSON.stringify({"passed": results.size() - 1, "total": results.size()}))
		get_tree().quit(1)
		return
	XState.new_game(3, 1, [8])
	check("save_namespace", XSave.dir() == "user://modes/xiyou")
	check("save_write", XSave.save(1))
	XState.current.gold = 4321
	check("save_reload", XSave.load_slot(1) and XState.current.gold != 4321)
	XSave.remove(1)
	var input := LineEdit.new()
	input.position = Vector2(80, 400)
	input.size = Vector2(700, 50)
	input.text = "中文输入验收"
	input.add_theme_font_override("font", font)
	add_child(input)
	check("unicode_text", input.text == "中文输入验收")
	var label := Label.new()
	label.position = Vector2(80, 80)
	label.size = Vector2(360, 260)
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
	if OS.get_cmdline_user_args().has("--interactive") and DisplayServer.get_name() != "headless":
		await _interactive(input, se)
	print("MAC_EXPORT_INFO=" + JSON.stringify({"editor": OS.has_feature("editor"), "display": DisplayServer.get_name(),
		"ime_supported": DisplayServer.has_feature(DisplayServer.FEATURE_IME), "saveDirectory": OS.get_user_data_dir(),
		"font": font.get_font_name(), "authoredFont": font is FontFile,
		"chineseLines": paragraph.get_line_count(), "fullscreen": fullscreen, "version": Engine.get_version_info().string}))
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	await get_tree().create_timer(0.5, true, false, true).timeout
	get_tree().quit(0 if passed == results.size() else 1)


func _process(_delta: float) -> void:
	if not _interactive_active:
		return
	var composition := DisplayServer.ime_get_text()
	if not composition.is_empty() and not _compositions.has(composition):
		_compositions.append(composition)
		print("IME_COMPOSITION=" + JSON.stringify({"text": composition, "selection": str(DisplayServer.ime_get_selection())}))

func _interactive(input: LineEdit, se: String) -> void:
	get_window().title = "西游 Mac 输入与音频验收（隔离存档）"
	var instruction := Label.new()
	instruction.position = Vector2(80, 355)
	instruction.text = "请用拼音候选词输入：中文测试；播放音效后记录结果。"
	instruction.add_theme_font_override("font", XUI.font())
	add_child(instruction)
	var play := Button.new()
	play.position = Vector2(80, 480)
	play.size = Vector2(300, 50)
	play.text = "播放菜单音效并记录音频"
	add_child(play)
	var finish := Button.new()
	finish.position = Vector2(420, 480)
	finish.size = Vector2(260, 50)
	finish.text = "记录结果并退出"
	add_child(finish)
	play.pressed.connect(func():
		play.disabled = true
		finish.disabled = true
		await _record_audio(se)
		finish.disabled = false
		play.text = "音频记录已完成"
	)
	finish.pressed.connect(func(): interactive_done.emit())
	_interactive_active = true
	input.text_changed.connect(func(value): print("IME_COMMITTED=" + JSON.stringify(value)))
	input.grab_focus()
	print("INTERACTIVE_READY=true")
	await interactive_done
	_interactive_active = false
	check("ime_composition_observed", not _compositions.is_empty(), _compositions)
	check("ime_committed_text", input.text == "中文测试", input.text)
	check("native_audio_pcm", _audio_verified)
	var result := {"text": input.text, "compositions": _compositions, "audioVerified": _audio_verified,
		"audioDriver": AudioServer.get_driver_name(), "display": DisplayServer.get_name()}
	print("INTERACTIVE_RESULT=" + JSON.stringify(result))
	if not _output_dir.is_empty():
		FileAccess.open(_output_dir.path_join("输入与音频结果.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "  ") + "\n")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_output_dir.path_join("Mac候选词输入完成.png"))

func _record_audio(se: String) -> void:
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "ExportVerification")
	AudioServer.set_bus_send(bus, "Master")
	var recording := AudioEffectRecord.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, recording)
	var player := AudioStreamPlayer.new()
	player.bus = "ExportVerification"
	player.volume_db = -12.0
	player.stream = load(se)
	add_child(player)
	recording.set_recording_active(true)
	player.play()
	await player.finished
	await get_tree().create_timer(0.2, true, false, true).timeout
	recording.set_recording_active(false)
	var wav := recording.get_recording()
	var peak := 0
	if wav != null:
		for i in range(0, wav.data.size() - 1, 2):
			peak = maxi(peak, absi(wav.data.decode_s16(i)))
		if not _output_dir.is_empty():
			wav.save_to_wav(_output_dir.path_join("Mac菜单音效.wav"))
	_audio_verified = wav != null and wav.data.size() > 0 and peak > 0 and AudioServer.get_driver_name() != "Dummy"
	print("NATIVE_AUDIO=" + JSON.stringify({"driver": AudioServer.get_driver_name(), "bytes": wav.data.size() if wav else 0, "peak": peak}))
	player.stop()
	player.stream = null
	player.queue_free()
	AudioServer.remove_bus(bus)
	await get_tree().create_timer(0.5, true, false, true).timeout
