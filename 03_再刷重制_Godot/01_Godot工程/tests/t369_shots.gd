extends Node
## 工具（不是专项）：T369 更新页九种状态＋强制更新＋旧样式对照＋20:9＋字体 130% 截图。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t369_shots.tscn -- --out=<目录> [--only=名,名]
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var out_dir := ""
var only: PackedStringArray = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7).split(",")
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


func _patch(extra := {}) -> Dictionary:
	var r := {"state": XUpdateCheck.PATCH, "current": "v0.01.09", "version": "v0.01.10", "date": "2026-11-22",
		"notes": PackedStringArray(["修了地图横幅在雪地上看不清", "装备检索换了新版式", "异化工坊按钮分了主次", "更新页换了新样式"]),
		"patch": {"size": 3460300}, "download_url": "https://example.invalid/download"}
	r.merge(extra, true)
	return r


func _backdrop() -> void:
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color("2a1a18")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _clear_pages() -> void:
	for n in get_children():
		if n is CanvasLayer:
			n.queue_free()


func _states(skin: bool, tag: String, rb := false) -> void:
	XUpdateInstall.BootPatchScript.result["loaded"] = rb
	var page := XUpdatePage.open(self, skin)
	await _frames(4)
	var seq := [
		["1_checking", {"state": "checking"}],
		["2_latest", {"state": XUpdateCheck.LATEST, "current": "v0.01.10"}],
		["3_patch", _patch()],
		["4_downloading", {"state": XUpdatePage.DOWNLOADING, "done": 1500000, "total": 3460300, "source": _patch()}],
		["5_ready", {"state": XUpdatePage.READY, "version": "v0.01.10"}],
		["6_failed", {"state": XUpdatePage.FAILED, "version": "v0.01.10", "message": "网络不通或空间不够。", "source": _patch()}],
		["7_bad", {"state": XUpdateCheck.BAD, "current": "v0.01.09"}],
		["8_full", _patch({"state": XUpdateCheck.FULL})],
		["9_rolled", {"state": XUpdatePage.ROLLED}],
	]
	for it in seq:
		page.show_result(it[1])
		await _shot("%s_%s" % [tag, it[0]])
	page._notice = "上次的更新 v0.01.08 没能用上（启动失败），已退回。\n"
	page.show_result({"state": XUpdateCheck.LATEST, "current": "v0.01.09"})
	await _shot("%s_notice" % tag)
	page.get_parent().queue_free()
	await _frames(3)


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	TestEnv.isolate("t369_shots")
	XSplashScreen.shown = true
	XConfig.ensure_loaded()
	XConfig._values["codexUiSkin"] = true
	XUpdateClient.ENABLED = false
	XState.current = null
	_backdrop()
	await _frames(3)
	await _states(true, "new")
	await _states(false, "old")
	# 主图：有新版本＋正在用补丁（带退回链接）、点一下后的退回
	XUpdateInstall.BootPatchScript.result["loaded"] = true
	var page := XUpdatePage.open(self, true)
	await _frames(4)
	page.show_result(_patch())
	await _shot("new_patch_with_rollback")
	page._rollback.pressed.emit()
	await _shot("new_rollback_armed")
	page.get_parent().queue_free()
	await _frames(3)
	XUpdateInstall.BootPatchScript.result["loaded"] = false
	# 强制更新（新、旧）：三种
	for skin in [true, false]:
		var tag := "new" if skin else "old"
		var fp := XUpdatePage.open_forced(self, _patch({"forced": true}), skin)
		await _shot("%s_forced_patch" % tag)
		fp.show_result({"state": XUpdatePage.FAILED, "version": "v0.01.10", "message": "网络不通或空间不够。", "source": _patch({"forced": true})})
		await _shot("%s_forced_failed" % tag)
		fp.show_result(_patch({"state": XUpdateCheck.FULL, "forced": true}))
		await _shot("%s_forced_full" % tag)
		fp.get_parent().queue_free()
		await _frames(3)
	# 20:9
	get_window().content_scale_size = Vector2i(1600, 720)
	get_window().size = Vector2i(1600, 720)
	await _frames(6)
	var p2 := XUpdatePage.open(self, true)
	await _frames(4)
	p2.show_result(_patch())
	await _shot("new_patch_20x9")
	p2.get_parent().queue_free()
	await _frames(3)
	var f2 := XUpdatePage.open_forced(self, _patch({"forced": true}), true)
	await _shot("new_forced_patch_20x9")
	f2.get_parent().queue_free()
	await _frames(3)
	get_window().content_scale_size = Vector2i(1280, 720)
	get_window().size = Vector2i(1280, 720)
	await _frames(6)
	# 字体 130%：长说明
	XConfig._values[XFontScale.KEY] = {"global": 130, "toast": 100}
	var notes := PackedStringArray()
	for i in range(14):
		notes.append("第 %d 条：这一批修了几个小问题，写得稍微长一点用来看折行和滚动" % (i + 1))
	var p3 := XUpdatePage.open(self, true)
	await _frames(4)
	p3.show_result(_patch({"notes": notes}))
	await _shot("new_patch_font130")
	p3.get_parent().queue_free()
	XConfig._values.erase(XFontScale.KEY)
	print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
	get_tree().quit.call_deferred(0)
