extends Node
## 工具（不是专项）：T361 页面级去网页味修前修后截图（装备检索、更新页、更新说明页、异化工坊、地图横幅、成就旧弹窗）。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t361_shots.tscn -- --out=<目录> [--bg=<亮图背景 png/jpg>] [--only=名,名]
## 每页拍两张：before（各页回退开关关掉）、after（默认）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var out_dir := ""
var bg_path := ""
var only: PackedStringArray = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--bg="):
			bg_path = arg.substr(5)
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


func _tq_state(line := "") -> XState:
	var ids := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 4)
	var s := XTianqi.start_new_game(3, "jianxian", ids)
	XTianqi.take_pending()
	for id in ids:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
	return s


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	TestEnv.isolate("t361_shots")
	XSplashScreen.shown = true
	XConfig.ensure_loaded()
	XConfig._values["codexUiSkin"] = true
	XUpdateClient.ENABLED = false
	for v2 in [false, true]:
		var tag := "after" if v2 else "before"
		XGearSearch.SKIN_PAGE_V2 = v2
		XUpdatePage.FRAME_V2 = v2
		XAlienWorkshop.LAYOUT_V2 = v2
		XDifficultyNoticeCanvas.BACKDROP_V2 = v2
		XMapScene.MAP_NAME_BACKDROP_V2 = v2
		XAchievementPopup.LANE_TAKEOVER = v2
		if _want("gear"):
			var s := _tq_state()
			for id in [1, 2, 3, 4, 5, 6]:
				s.gain_gear("weapon", id, 1)
			for id in [1, 2, 3]:
				s.gain_gear("armor", id, 1)
			XGearSearch.reset_session()
			XGearSearch.filters_open = false
			var gh := Control.new()
			gh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(gh)
			var gs := XGearSearch.open(gh, XGearQuery.collection(s))
			await _frames()
			await _shot("gear_" + tag)
			if v2:
				gs._toggle_filters()
				await _frames(6)
				await _shot("gear_filters_" + tag)
				gs._toggle_filters()
			gh.queue_free()
			await _frames(3)
		if _want("update"):
			XState.current = null
			var up := XUpdatePage.open(self)
			await _frames(6)
			up.show_result({"state": "latest"})
			await _frames(6)
			await _shot("update_" + tag)
			up.get_parent().queue_free()
			await _frames(3)
			var rec := {"code": 1, "version": "v0.01.10", "date": "2026-11-21", "notes": ["修了地图横幅在雪地上看不清", "装备检索换了新版式", "异化工坊按钮分了主次"]}
			var wn := XWhatsNewPage.open(self, rec, false)
			await _frames(6)
			await _shot("whats_new_" + tag)
			if wn.get_parent() is CanvasLayer:
				wn.get_parent().queue_free()
			else:
				wn.queue_free()
			await _frames(3)
		if _want("workshop"):
			var s := _tq_state("plague")
			s.gain_item(XAlienation.stone_id(), 3)
			var i: Dictionary = XTianqiAlienGear.create(s, "armor", 52, "plague", "huaxing", "mimic").ok
			s.gear.append(i)
			XTianqiAlienGear.add_core(s, "plague", "insulation", "shigu", "test")
			s.gain_gear("armor", 53, 1)
			XAlienWorkshop.selected = ""
			var ws := XAlienWorkshop.new()
			ws.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(ws)
			await _frames(10)
			await _shot("workshop_" + tag)
			ws.queue_free()
			await _frames(3)
		if _want("map"):
			_tq_state()
			var map := XMapScene.new()
			add_child(map)
			await _frames(6)
			var layer := CanvasLayer.new()
			layer.layer = -50
			var bg := TextureRect.new()
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bg.stretch_mode = TextureRect.STRETCH_SCALE
			if bg_path != "" and FileAccess.file_exists(bg_path):
				bg.texture = ImageTexture.create_from_image(Image.load_from_file(bg_path))
			else:
				var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
				img.fill(Color.WHITE)
				bg.texture = ImageTexture.create_from_image(img)
			layer.add_child(bg)
			map.add_child(layer)
			map._show_map_name("雪原的小镇")
			var plate: XMVCanvas = map.hud.find_child("MapNamePlate", true, false)
			var dn: XDifficultyNoticeCanvas = map.difficulty_notice
			dn.clock.set_physics_process(false)
			dn.clock.text = "当前难度：普通"
			dn.clock.color = Color.WHITE
			dn.clock.showing = true
			for op in [255, 128]:
				map._map_name_tween.kill()
				plate.position.y = 48.0
				plate.modulate.a = op / 255.0
				plate.queue_redraw()
				dn.clock.remaining = 120 if op == 255 else 21   # 21×6＝126：淡出一半
				dn.clock.paint()
				dn.refresh()
				await _frames(6)
				await _shot("map_%s_%d" % [tag, op])
			map.queue_free()
			await _frames(3)
		if _want("ach"):
			# 新皮肤还没开时触发的成就（旧弹窗），进了天启篇存档（新皮肤开）以后
			XState.current = null
			var host := Control.new()
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(host)
			get_tree().current_scene = host if get_tree().current_scene == null else get_tree().current_scene
			XAchievementPopup.show_for({"id": 1, "name": "1W预约量达成！", "icon": 100})
			XAchievementPopup.show_for({"id": 2, "name": "西游MOD", "icon": 101})
			await _frames(30)
			_tq_state()
			await _frames(40)
			await _shot("ach_" + tag)
			for p in XAchievementPopup._stack:
				if is_instance_valid(p):
					p.queue_free()
			XAchievementPopup._stack.clear()
			host.queue_free()
			await _frames(200)
	print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
	get_tree().quit.call_deferred(0)
