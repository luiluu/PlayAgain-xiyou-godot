extends Node
## 工具（不是专项）：T288 卡 S 长说明卡分节，新旧画法对照截图。要真窗口：
##   godot --audio-driver Dummy --path 01_Godot工程 res://tests/t288_card_shots.tscn -- --out=<目录> [--only=名字前缀]
## 每张存 1280×720 原图和 800×450 缩图（_s.png）。「旧」＝ XHelpCard.SECTIONS 关（现行画法）；详情牌的旧画法＝页面现在喂的一节无标题行。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
var out_dir := ""
var only := ""
## 技能页右牌的位置（XSkinLayout 右块，1280×720 下）
const RIGHT := Rect2(856, 72, 392, 596)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7)
	_run.call_deferred()


func _frames(n := 20) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	var small := img.duplicate() as Image
	small.resize(800, 450, Image.INTERPOLATE_LANCZOS)
	small.save_png(out_dir.path_join(name + "_s.png"))
	print("SHOT ", name)


func _want(n: String) -> bool:
	return only == "" or n.begins_with(only)


func _bg() -> Control:
	var bg := ColorRect.new()
	bg.color = XUiSkin.BG
	bg.size = Vector2(1280, 720)
	add_child(bg)
	return bg


## 技能页右牌（现在的喂法：一节无标题，XSkinTemplatePage.help_rows）
func _old_card(parent: Control, obj: Dictionary, rows: Array, sub: String) -> XSkinCard:
	var c := XSkinCard.new()
	c.position = RIGHT.position
	c.size = RIGHT.size
	parent.add_child(c)
	var icon_i := int(obj.get("iconIndex", 0))
	c.setup({"icon": XUiSkin.icon(icon_i) if icon_i > 0 else null, "title": str(obj.get("name", "")), "title_color": XQuality.list_color(obj),
		"subtitle": sub, "sections": [{"title": "", "rows": XSkinTemplatePage.help_rows(rows)}]})
	return c


## 新画法：XHelpCard.skin_card_data 分节，fold 开
func _new_card(parent: Control, obj: Dictionary, rows: Array, sub: String) -> XSkinCard:
	var c := XSkinCard.new()
	c.fold = true
	c.position = RIGHT.position
	c.size = RIGHT.size
	parent.add_child(c)
	var d := XHelpCard.skin_card_data(rows, obj)
	if sub != "":
		d.subtitle = sub
	c.setup(d)
	return c


func _pair(name: String, obj: Dictionary, rows: Array, sub: String) -> void:
	if not _want(name):
		return
	var bg := _bg()
	_old_card(bg, obj, rows, sub).position.x = RIGHT.position.x - RIGHT.size.x - 420
	var n := _new_card(bg, obj, rows, sub)
	_label(bg, "旧（现行）", Vector2(RIGHT.position.x - RIGHT.size.x - 420, 50))
	_label(bg, "新（T288）", Vector2(RIGHT.position.x, 50))
	await _frames(5)
	await _shot(name)
	print("  overflow=", n.can_expand(), " natural=", n.natural_height(n.size.x))
	bg.queue_free()
	await _frames(2)


func _label(p: Control, t: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = t
	l.position = at
	l.add_theme_color_override("font_color", Color.WHITE)
	p.add_child(l)


func _key_y() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_Y
		e.physical_keycode = KEY_Y
		e.pressed = down
		get_viewport().push_input(e)
		await _frames(2)


func _click(at: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.global_position = at
		e.pressed = down
		get_viewport().push_input(e)
		await _frames(2)


func _growth_gear() -> Dictionary:
	var fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/growth_help_oracle.json"))
	var c: Dictionary = fx.cases[0]
	for cc in fx.cases:
		if int(cc.pending) > 0:
			c = cc
			break
	var base := XDB.rec("Armors", int(c.base))
	var meta: Dictionary = base.get("meta", {}).duplicate()
	meta.quality = str(int(c.quality))
	var o := {"kind": "armor", "base": int(c.base), "id": 9000 + int(c.base), "etypeId": int(base.get("etypeId", 0)), "atypeId": int(base.get("atypeId", 0)), "name": c.name,
		"note": c.note0, "description": c.description0, "params": c.params, "price": c.price, "traits": c.traits, "meta": meta, "yep": {}, "iconIndex": int(base.get("iconIndex", 0))}
	for k in c.fields:
		o[k] = c.fields[k]
	(XHeartsteel._ledger if XHeartsteel.is_gear(o) else XHubris._ledger).append({"item": o, "gain": int(c.pending)})
	return o


func _run() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		print("SKIP 工具场景，没给参数")
		print("TEST_RESULT=" + JSON.stringify({"passed": 1, "total": 1}))
		get_tree().quit.call_deferred(0)
		return
	TestEnv.isolate("t288_card_shots")
	XSplashScreen.shown = true
	XUiSkin.FORCE = true
	XUiSkin.touch_override = 0
	var s := XState.new_game(3, 8, [9])
	s.actor_name = "k"
	XState.current = s
	for n in get_tree().root.get_children():
		if n is XToast:
			n.queue_free()
	var raven: Dictionary = XDB.rec("Skills", 10122)
	await _pair("01_raven_10122", raven, XHelpCard.content(raven, "skill", false, 300.0), "法术 · 25MP")
	var gear := _growth_gear()
	await _pair("02_growth_gear_now", gear, XHelpCard.detail_rows(gear, 300.0), "")
	var plain: Dictionary = XDB.rec("Skills", 3760)
	await _pair("03_plain_3760", plain, XHelpCard.content(plain, "skill", false, 300.0), "魔法 · 1500MP")
	var lb: Dictionary = XDB.rec("Skills", 10622)
	var lb_rows := XHelpCard.content(lb, "skill", false, 300.0)
	await _pair("04_liuying_collapsed", lb, lb_rows, "战技 · 5%当前生命")
	# 流萤：Y 展开、触屏点开、展开后滚到底（130%）
	if _want("05"):
		var bg := _bg()
		var c := _new_card(bg, lb, lb_rows, "战技 · 5%当前生命")
		await _frames(5)
		await _key_y()
		await _frames(5)
		print("  Y expanded=", c.expanded)
		await _shot("05_liuying_y_expanded")
		await _key_y()
		await _frames(3)
		print("  Y again expanded=", c.expanded)
		bg.queue_free()
		await _frames(2)
	if _want("06"):
		XUiSkin.touch_override = 1
		var bg := _bg()
		var c := _new_card(bg, lb, lb_rows, "战技 · 5%当前生命")
		await _frames(5)
		await _shot("06a_liuying_touch_collapsed")
		var sr := c.strip_rect()
		await _click(c.global_position + sr.get_center())
		await _frames(5)
		print("  touch expanded=", c.expanded)
		await _shot("06b_liuying_touch_expanded")
		bg.queue_free()
		XUiSkin.touch_override = 0
		await _frames(2)
	if _want("07"):
		XFontScale.set_value("global", 130)
		XFontScale.set_value("popup", 130)
		var lb2 := XDB.rec("Skills", 10623)
		var rows2 := XHelpCard.content(lb2, "skill", false, 300.0)
		await _pair("07a_font130_liuying_10623", lb2, rows2, "战技 · 当前全部护盾")
		var bg := _bg()
		var c := _new_card(bg, lb2, rows2, "战技 · 当前全部护盾")
		await _frames(5)
		c.set_expanded(true)
		await _frames(5)
		await _shot("07b_font130_expanded_top")
		c.scroll_by(99999)
		await _frames(5)
		print("  max_scroll=", c._max_scroll, " scroll=", c.scroll)
		await _shot("07c_font130_expanded_bottom")
		bg.queue_free()
		XFontScale.set_value("global", 100)
		XFontScale.set_value("popup", 100)
		await _frames(2)
	# 浮动说明卡（旧页、战斗里）：SECTIONS 关／开
	if _want("08"):
		for on in [false, true]:
			XHelpCard.SECTIONS = on
			var bg := _bg()
			var hc := XHelpCard.new()
			bg.add_child(hc)
			hc.show_for(raven)
			hc.position = Vector2(80, 60)
			var hc2 := XHelpCard.new()
			bg.add_child(hc2)
			hc2.show_for(gear)
			hc2.position = Vector2(700, 60)
			await _frames(5)
			await _shot("08_floating_%s" % ("new" if on else "old"))
			bg.queue_free()
			await _frames(2)
		XHelpCard.SECTIONS = true
	if _want("10"):
		await _skill_page()
	if _want("09") or only.begins_with("09"):
		await _battle()
	XUiSkin.FORCE = false
	get_tree().quit(0)


## 战斗里：米拉（168）的战技列表，「详情」展开的说明卡；SECTIONS 关／开各一张
func _battle() -> void:
	var s := XState.current
	s.flags["tianqi"] = {"rules": 1}
	for on in [only != "09old"]:   # 一次只开一场（同一进程连开两场，第二场指令窗收不到键）：--only=09old／--only=09new
		XHelpCard.SECTIONS = on
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
			await _frames(80)
			XSkinBattle.help_open = true
			for act in ["ui_down", "ui_accept"]:
				for down in [true, false]:
					var e := InputEventAction.new()
					e.action = act
					e.pressed = down
					Input.parse_input_event(e)
					await _frames(4)
				await _frames(20)
			await _frames(30)
			print("  list_win=", b.list_win != null, " help visible=", b.help_card != null and b.help_card.visible)
			XSkinBattle.help_open = true
			await _frames(10)
			await _shot("09_battle_%s" % ("new" if on else "old"))
		b.queue_free()
		XEnemy.force_roll = -1.0
		await _frames(5)
	XHelpCard.SECTIONS = true


## 技能页（真页面 XSkillScene 新皮肤）：让当前角色学会渡鸦 10122、流萤 10622、普通 3760，逐个选中右牌；SECTIONS 关／开
func _skill_page() -> void:
	var s := XState.current
	var a: XActor = s.actor(int(s.party[0]))
	for id in [10122, 10622, 3760]:
		a.learn_skill(id)
	for on in [false, true]:
		XHelpCard.SECTIONS = on
		var page := XSkillScene.new()
		add_child(page)
		await _frames(5)
		for id in [10122, 10622, 3760]:
			for ti in page.types().size():
				page.type_index = ti
				var es := page.entries()
				var k := es.map(func(e): return int(e.get("id", 0))).find(id)
				if k >= 0:
					page.mode = "list"
					page.index = k
					page._refresh()
					break
			await _frames(5)
			await _shot("10_skillpage_%d_%s" % [id, "new" if on else "old"])
			if on and id == 10622 and page.skin != null:
				await _key_y()
				await _frames(5)
				print("  skill page Y expanded=", page.skin.card.expanded)
				await _shot("10_skillpage_10622_expanded")
				await _key_y()
		page.queue_free()
		await _frames(3)
	XHelpCard.SECTIONS = true
