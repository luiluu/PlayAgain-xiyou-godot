extends Node
## 工具（不是专项）：T278 六维雷达图截图（角色状态页、人物图鉴）。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t278_six_dim_shots.tscn -- --out=<目录> [--only=status,book]
## 状态页：天启篇存档、新界面开，队伍 180 五条悟／175 谷雨／168 米拉／6 吕布各一张；人物图鉴同四人。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var out_dir := ""
var only: PackedStringArray = []
const IDS := [180, 175, 168, 6]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7).split(",")
	_run.call_deferred()


func _want(n: String) -> bool:
	return only.is_empty() or only.has(n)


func _frames(n := 20) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name, " ", img.get_width(), "x", img.get_height())


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	TestEnv.isolate("t278_six_dim_shots")
	XSplashScreen.shown = true
	var s := XState.new_game(3, 8, [9])
	s.actor_name = "k"
	XState.current = s
	XUiSkin.FORCE = true
	s.flags["tianqi"] = {"rules": 1}
	for id in IDS:
		s.add_actor(id)
	s.party.assign(IDS)
	if _want("status"):
		var p := XStatusPage.new()
		add_child(p)
		await _frames()
		for i in IDS.size():
			p.actor_index = i
			p.skin.sync()
			await _frames(5)
			await _shot("status_%d" % IDS[i])
		p.queue_free()
		await _frames(3)
	if _want("book"):
		var b := XActorBook.new()
		add_child(b)
		await _frames(3)
		for id in IDS:
			b.select(XActorBook.index_ids().find(id))
			await _frames(5)
			await _shot("book_%d" % id)
		b.queue_free()
	get_tree().quit.call_deferred(0)
