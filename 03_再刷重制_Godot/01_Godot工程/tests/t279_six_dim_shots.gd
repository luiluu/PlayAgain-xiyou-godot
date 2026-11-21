extends Node
## 工具（不是专项）：T279 六维雷达图截图（怪物图鉴、战斗内首领详情「六维」页签）。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t279_six_dim_shots.tscn -- --out=<目录> [--only=book,boss]
## 图鉴：天启篇存档，已登记几只敌人＋一只未登记各一张；首领详情：四骑士各一张（展开、切到「六维」页签）＋原「异常」页签一张。
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
	TestEnv.isolate("t279_six_dim_shots")
	XSplashScreen.shown = true
	XUiSkin.FORCE = true
	if _want("book"):
		var s := XState.new_game(3, 8, [9])
		s.actor_name = "k"
		s.flags["tianqi"] = {"rules": 1}
		XState.current = s
		var ids: Array = XEnemyBook.ids()
		var picks: Array = []
		for id in XTianqiSixDim.data().get("enemies", {}):
			if ids.has(int(id)) and picks.size() < 5:
				picks.append(int(id))
		for i in picks.size() - 1:   # 最后一只不登记，看「？？？」遮罩
			XEnemyBook.add(s, picks[i])
		var b := XEnemyBookPage.new()
		add_child(b)
		await _frames(3)
		for id in picks:
			b.select(b.ids.find(id))
			await _frames(5)
			await _shot("book_%d" % id)
		b.queue_free()
		await _frames(3)
	if _want("boss"):
		for line in ["death", "war", "famine", "plague"]:
			var s2 := XTianqi.start_new_game(3, "jianxian", [9])
			XTianqi.take_pending()
			XState.current = s2
			s2.party.assign([9])
			XTianqiHorsemen.prepare(line, s2)
			var sc := XBattleScene.new()
			sc.setup(2, true, false, XDB.map(5))
			add_child(sc)
			await _frames(40)
			var panel: XBossStatusPanel = sc.boss_panel
			for e in sc.logic.enemies:
				print("ENEMY ", e.display_name(), " boss=", e.boss_difficulty_boss, " hid=", e.hidden, " knight=", e.horseman.get("knight", null))
			print("PANEL ", line, " vis=", panel.visible, " six=", panel.six_tab_on())
			await _shot("boss_%s_bar" % line)
			panel.click_bar()
			await _frames(5)
			panel.filter = "Debuff"
			panel.refresh(true)
			await _shot("boss_%s_debuff" % line)
			panel.click_detail(Vector2(420, 58))
			await _frames(5)
			await _shot("boss_%s_six" % line)
			sc.queue_free()
			await _frames(5)
	get_tree().quit.call_deferred(0)
