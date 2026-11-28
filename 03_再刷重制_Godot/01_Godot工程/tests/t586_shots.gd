extends Node
## 工具（不是专项）：T586 西游档徐凤年 剑一·龙蛇／剑二·并蒂莲／剑三·三斤／剑九·六千里 截图。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t586_shots.tscn -- --out=<目录> [--old]（--old 只出 08 老档那张）
## 出：01～04 四招卡面；05 第 2 回合战技列表（剑九可用）；06 第 2 回合放出剑九（九段伤害、收剑）；
## 07 第 3 回合力竭（全属性 −50%）；08 老档（关开关时存的档）读回后同样能放剑九。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const CARD := Rect2(0, 72, 392, 596)
## 战斗截图用敌群 746（单个高血敌人、没有战斗事件）。战斗画面里木桩（敌群 70）每挨一下掉约 27% 血、746 也一帧倒下
## （开关关着同样如此，原有表现，另开卡查），所以第 1 回合手动防御、第 2 回合手动放剑九
const SHOT_TROOP := 746
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _frames(n := 20) -> void:
	for i in range(n):
		await get_tree().process_frame


func _secs(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _until(cond: Callable, n := 3600) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _shot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _equip_in_slot(a: XActor, item: Dictionary) -> void:
	for i in a.equip_slots().size():
		if int(a.equip_slots()[i]) == int(item.etypeId):
			a.equips[i] = item
			return


func _make_state() -> XState:
	var s := XState.new_game_blank()
	s.random_master = XRandomStream.hex64(20261128)
	s.set_switch(2494, true)
	s.set_variable(20, 30)
	XState.current = s
	s.add_actor(152)
	for i in 5:
		s.set_battle_slot(i, 152 if i == 0 else 0)
	var a: XActor = s.actor(152)
	a.change_level(80)
	var art: Dictionary = a.make_equip("armor", 143)
	art["level"] = 99
	_equip_in_slot(a, art)
	a.equips[0] = a.make_equip("weapon", 76)
	_equip_in_slot(a, a.make_equip("armor", 129))
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	a.tp = 100.0
	return s


func _cards() -> void:
	_make_state()  # 西游档存档在场，开关才分派（xiyou_save_on）
	var i := 1
	for pair in [[9987, "剑一"], [9988, "剑二"], [9989, "剑三"], [9995, "剑九"]]:
		var bg := ColorRect.new()
		bg.color = XUiSkin.BG
		bg.size = Vector2(1280, 720)
		add_child(bg)
		for side in [[false, 60, "开关关（T585 口径）"], [true, 560, "T586 开"]]:
			XXufeng.JIAN9 = side[0]
			XXufeng.clear_cache()
			var obj := XDB.rec("Skills", int(pair[0]))
			var c := XSkinCard.new()
			c.fold = true
			c.position = Vector2(side[1], CARD.position.y)
			c.size = CARD.size
			bg.add_child(c)
			var d := XHelpCard.skin_card_data(XHelpCard.content(obj, "skill", false, 300.0), obj)
			c.setup(d)
			var l := Label.new()
			l.text = side[2]
			l.position = Vector2(side[1], 40)
			l.add_theme_color_override("font_color", Color.WHITE)
			bg.add_child(l)
		XXufeng.JIAN9 = true
		XXufeng.clear_cache()
		await _frames(8)
		await _shot("%02d_card_%d" % [i, int(pair[0])])
		bg.queue_free()
		await _frames(2)
		i += 1


func _cmd_ready(b: XBattleScene) -> bool:
	return await _until(func():
		for m in b.logic.actors:
			if m.is_alive():
				m.hp = m.mhp  # 截图工具：不让我方在第 2 回合前被打倒
		return b.cmd_win != null and b.cmd_win.active, 3600)


## 手动操作：第 1 回合防御（不出手，免得画面里敌人第 2 回合前就倒，见文件头）；第 2 回合打开战技列表截图，选剑九打出去
func _battle(s: XState, tag: String, list_shot: bool) -> void:
	XState.current = s
	var a: XActor = s.actor(152)
	var b := XBattleScene.new()
	b.setup(SHOT_TROOP, true, false, {})
	add_child(b)
	await _cmd_ready(b)
	await _secs(0.5)
	while b.logic.turn < 2:  # 每回合能动好几次：第 1 回合的每次行动都防御
		b._picked.emit("guard")
		await _frames(2)
		await _cmd_ready(b)
	var t2 := b.logic.turn == 2
	a.tp = 100.0
	a.hp = a.mhp
	print("TURN2 ", tag, " ", t2, " turn=", b.logic.turn, " can_use=", b.logic.can_use(a, XDB.rec("Skills", 9995)))
	b._picked.emit("stype:1")
	await _until(func(): return b.list_win != null and b.list_win.is_visible_in_tree())
	await _secs(0.4)
	if list_shot:
		await _shot("05_skill_list_turn2")
	b._picked.emit(XDB.rec("Skills", 9995))
	await _secs(0.3)
	b._picked.emit(b.logic.enemies[0])
	var cast := await _until(func(): return a.is_state_affected(XXufeng.ST_SHOUJIAN), 1800)
	print("CAST ", tag, " ", cast)
	await _secs(0.4)
	await _shot("%s_jian9_cast" % ("06" if tag == "new" else "08_oldsave"))
	if tag == "new":
		while b.logic.turn < 3:
			await _cmd_ready(b)
			if b.logic.turn < 3:
				b._picked.emit("guard")
				await _frames(2)
		var t3 := b.logic.turn == 3
		print("LIJIE ", t3, " ", a.is_state_affected(XXufeng.ST_LIJIE), " atk=", a.atk)
		await _secs(0.5)
		await _shot("07_lijie_turn3")
	b.bgm.stop()
	b.queue_free()
	await _frames(5)


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	get_window().size = Vector2i(1280, 720)
	TestEnv.isolate("t586_shots")
	XSplashScreen.shown = true
	XUiSkin.FORCE = true
	XImportedBalance.RELEASE_XUFENG = true
	XXufeng.JIAN9 = true
	XXufeng.clear_cache()
	for n in get_tree().root.get_children():
		if n is XToast:
			n.queue_free()
	if not OS.get_cmdline_user_args().has("--old"):  # 两场连跑第二场会卡住：老档那场单独跑（加 --old）
		await _cards()
		await _battle(_make_state(), "new", true)
		get_tree().quit(0)
		return
	# 老档：关着开关时存的档，读回（开关开）照样能放
	XXufeng.JIAN9 = false
	XXufeng.clear_cache()
	var data: Dictionary = XSaveSlim.as_reloaded(_make_state().to_dict())
	XXufeng.JIAN9 = true
	XXufeng.clear_cache()
	XState.current = null
	var s2 := XState.from_dict(data)
	s2.actor(152).tp = 100.0
	await _battle(s2, "old", false)
	get_tree().quit(0)
