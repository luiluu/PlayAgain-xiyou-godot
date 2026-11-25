extends Node
## 工具（不是专项）：T482 元素效果 D 卡截图（战斗状态栏图标＋头顶跳字、怪物图鉴／人物图鉴／状态页的「角色属性」一行）。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t482_shots.tscn -- --out=<目录> [--only=battle,book,status]
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
	await _frames(2)
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
	TestEnv.isolate("t482_shots")
	XSplashScreen.shown = true
	XUiSkin.FORCE = true
	var s := XTianqi.start_new_game(3, "jianxian", [9])
	XTianqi.take_pending()
	XState.current = s
	s.party.assign([9, 10, 11])
	if _want("battle"):
		var sc := XBattleScene.new()
		sc.setup(2, true, false, XDB.map(5))
		add_child(sc)
		await _frames(40)
		var a: XActor = s.battle_members()[0]
		var e: XEnemy = sc.logic.enemies[0]
		for id in XTianqiElementEffects.STATE_IDS:
			if id != XTianqiElementEffects.ST_FREEZE:
				a.add_state(id)
		for id in [XTianqiElementEffects.ST_BURN, XTianqiElementEffects.ST_FREEZE, XTianqiElementEffects.ST_SOAK, XTianqiElementEffects.ST_HOLY, XTianqiElementEffects.ST_GUST]:
			e.add_state(id)
		a.add_state(XTianqiElementEffects.ST_HOLY)
		await _frames(30)
		await _shot("battle_state_bar")
		# 头顶跳字：走真实的 battle_text.pop 通道（战斗画面 _play）
		var pops := [[e, "灼烧", 2, "popup_burn_enemy"], [a, "免疫灼烧", 2, "popup_immune_burn"], [a, "圣佑抵挡", 1, "popup_holy_block"]]
		for p in pops:
			sc._play([{"type": "battle_text", "text": "x", "pop": {"target": p[0], "text": p[1], "format": p[2]}}])
			await _frames(5)
			await _shot(p[3])
			await _frames(70)
		sc.queue_free()
		await _frames(5)
	if _want("icons"):
		var host := Control.new()
		host.size = Vector2(1280, 720)
		add_child(host)
		var bg := ColorRect.new()
		bg.color = Color("#14100f")
		bg.size = host.size
		host.add_child(bg)
		var y := 20.0
		for id in XTianqiElementEffects.STATE_IDS:
			var rec := XTianqiElementEffects.state_rec(id)
			var tex := XUiSkin.icon(int(rec.iconIndex))
			var tr := TextureRect.new()
			tr.texture = tex
			tr.position = Vector2(30, y)
			tr.size = Vector2(32, 32)
			host.add_child(tr)
			var lb := Label.new()
			lb.text = "%s　%s" % [rec.name, str(rec.note).split("\n")[2]]
			lb.position = Vector2(80, y + 2)
			lb.add_theme_font_override("font", XUiSkin.font("body"))
			lb.add_theme_font_size_override("font_size", 20)
			host.add_child(lb)
			y += 48.0
		await _frames(4)
		await _shot("state_icons_all")
		host.queue_free()
		await _frames(3)
	if _want("book"):
		XEnemyBook.add(s, 1)
		var ids: Array = XEnemyBook.ids()
		for id in ids.slice(0, 40):
			XEnemyBook.add(s, id)
		var b := XEnemyBookPage.new()
		add_child(b)
		await _frames(3)
		b.select(1)
		await _frames(8)
		await _shot("book_enemy_nature")
		b.queue_free()
		await _frames(3)
		var ab := XActorBook.new()
		add_child(ab)
		await _frames(5)
		await _shot("book_actor_nature")
		ab.queue_free()
		await _frames(3)
	if _want("status"):
		var st := XStatusPage.new()
		add_child(st)
		await _frames(8)
		await _shot("status_nature")
		st.queue_free()
		await _frames(3)
	get_tree().quit.call_deferred(0)
