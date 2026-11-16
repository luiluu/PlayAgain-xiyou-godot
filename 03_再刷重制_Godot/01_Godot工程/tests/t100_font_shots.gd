extends Node
## 工具（不是专项）：T100 界面字体修前修后截图。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t100_font_shots.tscn -- --out=<目录> [--old]
## --old：把 XUiSkin.FONT_V00300 关掉（＝修前：思源宋体／黑体／Barlow 三款）；不给＝修后（玩家版 GameFont）。
## 拍：主菜单（天启篇存档、新界面开）、工坊页签（选中两项）、战斗指令窗与战技列表、选择难度（entry）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var out_dir := ""
var old := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg == "--old":
			old = true
	_run.call_deferred()


func _frames(n := 20) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(("old_" if old else "new_") + name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	TestEnv.isolate("t100_font_shots")
	XSplashScreen.shown = true
	XUiSkin.FONT_V00300 = not old
	XUiSkin.FORCE = true
	var s := XState.new_game(3, 8, [9])
	s.actor_name = "k"
	XState.current = s
	s.flags["tianqi"] = {"rules": 1}
	s.add_actor(168)
	s.add_actor(127)
	s.party.assign([168, 127, 8, 9])
	# 主菜单、工坊页签
	var m := XMenu.new()
	add_child(m)
	await _frames(30)
	await _shot("01_menu")
	var sk := m.skin
	if sk != null:
		for g in range(sk.groups.size()):
			if str(sk.groups[g].key) == "workshop":
				sk.gi = g
		sk.level = 1
		sk.ii = 1
		sk.refresh()
		await _frames(20)
		await _shot("02_workshop_tab_a")
		sk.ii = 2
		sk.refresh()
		await _frames(20)
		await _shot("03_workshop_tab_b")
	m.queue_free()
	await _frames(3)
	# 战斗：指令窗、战技列表
	seed(20261013)
	s.random_master = "2026101300000001"
	XEnemy.force_roll = 100.0
	XMessageBox.auto = true
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	add_child(b)
	for i in range(600):
		if b.cmd_win != null:
			break
		await get_tree().process_frame
	XMessageBox.auto = false
	if b.cmd_win != null:
		await _frames(40)
		await _shot("04_battle_cmd")
		for act in ["ui_down", "ui_accept"]:
			for down in [true, false]:
				var e := InputEventAction.new()
				e.action = act
				e.pressed = down
				get_viewport().push_input(e)
				await _frames(2)
		await _frames(40)
		await _shot("05_battle_skills")
	b.queue_free()
	XEnemy.force_roll = -1.0
	await _frames(5)
	# 选择难度
	var ent: Node = load("res://modes/xiyou/entry.tscn").instantiate()
	add_child(ent)
	await _frames(10)
	ent._tq_difficulty(1)
	await _frames(15)
	await _shot("06_difficulty")
	ent.queue_free()
	XUiSkin.FORCE = false
	await _frames(3)
	get_tree().quit(0)
