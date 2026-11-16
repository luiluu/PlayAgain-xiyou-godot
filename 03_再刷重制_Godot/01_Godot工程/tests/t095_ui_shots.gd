extends Node
## 工具（不是专项）：T095 界面小毛病修前修后截图。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t095_ui_shots.tscn -- --out=<目录> [--only=名,名]
## 两档：tq（天启篇存档、新界面开）、xy（西游存档、旧界面）。
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
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		# 工具不是专项：整轮测试（并行测试.py 跑 tests/ 下全部场景）里没给参数时报跳过、算通过
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	TestEnv.isolate("t095_ui_shots")
	XSplashScreen.shown = true
	for sc in ["tq", "xy"]:
		var s := XState.new_game(3, 8, [9])
		s.actor_name = "k"
		XState.current = s
		XUiSkin.FORCE = sc == "tq"
		s.flags["tianqi"] = {"rules": 1}   # 天启篇获取不限难度：先借它把米拉、小铃兰加进来
		s.add_actor(168)
		s.add_actor(127)
		s.party.assign([168, 127, 8, 9])
		if sc != "tq":
			s.flags.erase("tianqi")
		if _want("status"):
			var p := XStatusPage.new()
			add_child(p)
			await _frames()
			p.set_page(1)
			await _frames()
			await _shot(sc + "_01_status_resist")
			p.queue_free()
			await _frames(3)
		if _want("menu"):
			var m := XMenu.new()
			add_child(m)
			await _frames(30)
			await _shot(sc + "_03_menu_mira")
			if m.skin != null:
				m._selected_actor = 1
				m.skin.refresh()
				await _frames(10)
				await _shot(sc + "_04_menu_linglan")
				m._selected_actor = 0
				var sk := m.skin
				for g in range(sk.groups.size()):
					if str(sk.groups[g].key) == "workshop":
						sk.gi = g
				sk.level = 1
				sk.ii = 1
				sk.refresh()
				await _frames(20)
				await _shot(sc + "_02_menu_orb_selected")
				sk.ii = 2
				sk.refresh()
				await _frames(20)
				await _shot(sc + "_02_menu_alien_selected")
			m.queue_free()
			await _frames(3)
		if _want("plate"):
			var bg := ColorRect.new()
			bg.color = Color("d8d8d8")
			bg.size = Vector2(1280, 720)
			add_child(bg)
			var holder := Node2D.new()
			holder.position = Vector2(640, 400)
			bg.add_child(holder)
			var pl := XDesignationPlate.new()
			holder.add_child(pl)
			pl.place(6.0)
			pl.refresh(s)
			await _frames(5)
			await _shot(sc + "_05_plate")
			bg.queue_free()
		if _want("toast"):
			XToast.show_text("存档成功，储存到了2号存档！")
			await _frames(60)
			await _shot(sc + "_06_toast")
			var t := get_tree().root.get_node_or_null("XToast")
			if t != null:
				t.queue_free()
			await _frames(3)
		if _want("choice"):
			var box := XMessageBox.new()
			add_child(box)
			var go := func(): await box.choose(["借积分", "感到怀疑，离开"], 1)
			go.call()
			await _frames(40)
			await _shot(sc + "_09_choice")
			box.queue_free()
			await _frames(3)
			XConfig.set_font_size_percent("global", 130)   # 字体大小调到最大档
			var box2 := XMessageBox.new()
			add_child(box2)
			var go2 := func(): await box2.choose(["借积分", "感到怀疑，离开"], 1)
			go2.call()
			await _frames(40)
			await _shot(sc + "_09_choice_font130")
			box2.queue_free()
			XConfig.set_font_size_percent("global", 100)
			await _frames(3)
		if _want("slot"):
			s.map_id = 4   # 摘要带地图名（方桌大厅），跟 Kyo 截图一样长
			XSave.save(1)
			XSave.save(2)
			var e: Node = load("res://modes/xiyou/entry.tscn").instantiate()
			add_child(e)
			await _frames(10)
			e._tq_slot()
			await _frames(5)
			for n in [1, 3, 4]:
				var b: Control = e.find_child("TianqiSlot%d" % n, true, false)
				b.grab_focus()
				await _frames(10)
				await _shot(sc + "_08_slot%d" % n)
			e.queue_free()
			await _frames(3)
	XUiSkin.FORCE = false
	get_tree().quit(0)
