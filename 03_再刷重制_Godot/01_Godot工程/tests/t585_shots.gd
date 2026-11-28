extends Node
## 工具（不是专项）：T585 西游档徐凤年 九阶基因锁／剑一 卡面，开关关（左，原样）与开（右，T585）对照截图。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t585_shots.tscn -- --out=<目录>
const TestEnv = preload("res://tests/xiyou_test_env.gd")
var out_dir := ""
const RIGHT := Rect2(856, 72, 392, 596)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _frames(n := 20) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _card(parent: Control, sid: int, x: float, sub: String) -> void:
	XXufeng.clear_cache()
	var obj := XDB.rec("Skills", sid)
	var c := XSkinCard.new()
	c.fold = true
	c.position = Vector2(x, RIGHT.position.y)
	c.size = RIGHT.size
	parent.add_child(c)
	var d := XHelpCard.skin_card_data(XHelpCard.content(obj, "skill", false, 300.0), obj)
	d.subtitle = sub + "（菜单：%s）" % ("战斗专用" if int(obj.occasion) == 1 else "不可用" if int(obj.occasion) == 3 else "可点")
	c.setup(d)


func _label(p: Control, t: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = t
	l.position = at
	l.add_theme_color_override("font_color", Color.WHITE)
	p.add_child(l)


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	TestEnv.isolate("t585_shots")
	XSplashScreen.shown = true
	XUiSkin.FORCE = true
	XImportedBalance.RELEASE_XUFENG = true
	var s := XState.new_game_blank()
	s.set_switch(2494, true)
	XState.current = s
	s.add_actor(152)
	for n in get_tree().root.get_children():
		if n is XToast:
			n.queue_free()
	for pair in [[9996, "01_genelock_9996"], [9987, "02_sword1_9987"]]:
		var bg := ColorRect.new()
		bg.color = XUiSkin.BG
		bg.size = Vector2(1280, 720)
		add_child(bg)
		XXufeng.LOCK_FIX = false
		_card(bg, pair[0], 60, "被动")
		XXufeng.LOCK_FIX = true
		_card(bg, pair[0], 560, "被动")
		_label(bg, "开关关（原样）", Vector2(60, 40))
		_label(bg, "T585 开", Vector2(560, 40))
		await _frames(8)
		await _shot(pair[1])
		bg.queue_free()
		await _frames(2)
	get_tree().quit(0)
