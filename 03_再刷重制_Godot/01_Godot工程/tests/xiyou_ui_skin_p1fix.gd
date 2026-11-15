extends Node
## 小A审 v0.7 P1 三条必改（cc/ui-skin-p1fix）的截图与少量断言：
## - 选中条前后对比（v0.7 打磨版 ↔ 加厚版 SELECT_V2）：陈列板（列表含神话红行、弹窗选项、按钮悬停／焦点／按下）、主菜单、装备页；16:9 与 20:9；
##   每组存「_v07」「_v2」两张和左右拼好的「_compare」一张；
## - 平板 4:3（1024×768 窗口）：主菜单、装备页、七印祭坛视口仍 1280×720（上下黑边、不重排），各存一张。
## 无头模式只跑断言（视口相关的断言要窗口，截图也要窗口）：加 -- --out=<目录> 且有窗口时出图。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func save(img: Image, name: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK, img.get_size())


## 左右拼：左 v0.7、右加厚版，中间 16px 灰缝
func save_compare(a: Image, b: Image, name: String) -> void:
	var gap := 16
	var img := Image.create(a.get_width() + gap + b.get_width(), maxi(a.get_height(), b.get_height()), false, a.get_format())
	img.fill(Color(0.35, 0.35, 0.35))
	img.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	img.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width() + gap, 0))
	save(img, name)


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_p1fix")
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF   # 呼吸、滑动关掉，两张对比图同一帧状态
	check("view_for_43", XSkinLayout.view_for(Vector2(1024, 768)) == Vector2(1280, 720) and XSkinLayout.view_for(Vector2(1600, 720)) == Vector2(1600, 720))
	if windowed():
		for size in [Vector2i(1280, 720), Vector2i(1600, 720)]:
			get_window().size = size
			await frames(6)
			var tag := "16x9" if size.x == 1280 else "20x9"
			await _pair("p1_select_board_" + tag, _board)
			await _pair("p1_select_menu_" + tag, _menu)
			await _pair("p1_select_equip_" + tag, _equip)
			await _u4_shots(tag)
			await _two_level_shots(tag)
		get_window().size = Vector2i(1024, 768)
		await frames(8)
		await _tablet()
		get_window().size = Vector2i(1280, 720)
		await frames(4)
	XUiSkin.SELECT_V2 = true
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XState.current = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 同一画面 v0.7、加厚版各拍一张，再拼一张
func _pair(name: String, build: Callable) -> void:
	var imgs := []
	for v2 in [false, true]:
		XUiSkin.SELECT_V2 = v2
		XUiSkin._styles.clear()   # Button 主题里缓存的选中样式按新开关重建
		var node: Node = await build.call()
		await frames(4)
		var img: Image = await grab()
		imgs.append(img)
		save(img, name + ("_v2" if v2 else "_v07"))
		node.queue_free()
		await frames(2)
	check("differs_" + name, imgs[0].get_data() != imgs[1].get_data())   # 前后图必须不一样（小A核 P3-1）
	if name.ends_with("20x9"):
		check("wide_" + name, absf(float(imgs[0].get_width()) / imgs[0].get_height() - 20.0 / 9.0) < 0.02, imgs[0].get_size())
	save_compare(imgs[0], imgs[1], name + "_compare")


func _state(tianqi := true) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	if tianqi:
		s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian", "line": "war"}
	s.set_variable(20, 32)
	s.gold = 12480
	return s


## 陈列板：列表（神话红行选中／普通行选中）、弹窗选项、按钮三态
func _board() -> Node:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	XSkinLayout.request_wide(root)   # 小A核 P3-1：陈列板也按新页面铺满（20:9 原来截成 1280 宽）
	await frames(3)
	XUiSkin.menu_backdrop(root)
	var view := get_viewport().get_visible_rect().size
	var title := Label.new()
	title.text = "选中条：%s" % ("加厚版（SELECT_V2）" if XUiSkin.SELECT_V2 else "v0.7 打磨版（旧）")
	title.add_theme_font_override("font", XUiSkin.font("title"))
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", XUiSkin.GOLD)
	title.position = Vector2(XSkinLayout.margin_for(view.x), 20)
	root.add_child(title)
	var items := [
		{"text": "天罚·终焉之刃", "icon": 97, "color": XUiSkin.QUALITY[6], "right": "+1,280", "sub": "神话"},
		{"text": "破晓长弓", "icon": 98, "color": XUiSkin.QUALITY[4], "right": "+640"},
		{"text": "治疗药水", "icon": 176, "right": "×15"},
		{"text": "封印石", "icon": 190, "color": XUiSkin.QUALITY[3], "right": "×3"},
		{"text": "（用不了）", "icon": 0, "right": "—", "disabled": true},
	]
	var x0 := XSkinLayout.margin_for(view.x)
	var col_w := (view.x - x0 * 2.0 - 32.0) / 3.0
	for k in 2:
		var panel := Control.new()
		panel.position = Vector2(x0 + k * (col_w + 16.0), 80)
		panel.size = Vector2(col_w, 300)
		panel.draw.connect(func(): XUiSkin.draw_panel(panel.get_canvas_item(), Rect2(Vector2.ZERO, panel.size)))
		root.add_child(panel)
		var list := XSkinList.new()
		list.position = Vector2(12, 16)
		list.size = Vector2(col_w - 24, XUiSkin.ROW_H * 5)
		panel.add_child(list)
		list.set_items(items)
		list.select(0 if k == 0 else 2, false)
	# 弹窗选项（MV 窗口换皮的画法：XWindowStyle → draw_select）
	var choice := Control.new()
	choice.position = Vector2(x0 + 2 * (col_w + 16.0), 80)
	choice.size = Vector2(col_w, 300)
	var opts := ["继续挑战", "回到大厅", "保存并退出"]
	choice.draw.connect(func():
		var ci := choice.get_canvas_item()
		XUiSkin.draw_panel(ci, Rect2(Vector2.ZERO, choice.size))
		for i in opts.size():
			var r := Rect2(12, 16 + i * 46, choice.size.x - 24, 46)
			if i == 1:
				XUiSkin.draw_select(ci, r)
			choice.draw_string(XUiSkin.font("body"), Vector2(r.position.x + 18, r.position.y + 30), opts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_LIST, XUiSkin.TEXT))
	root.add_child(choice)
	# 按钮：常态、悬停、焦点、按下（直接画对应样式；v0.7 后三者同一个）
	var btns := Control.new()
	btns.position = Vector2(x0, 410)
	btns.size = Vector2(view.x - x0 * 2.0, 200)
	var names := ["常态", "悬停", "焦点", "按下"]
	btns.draw.connect(func():
		var ci := btns.get_canvas_item()
		var bw := 200.0
		for i in 4:
			var r := Rect2(i * (bw + 24.0), 30, bw, 48)
			match i:
				0: XSkinButton.style().draw(ci, r)
				1: XUiSkin.select_style_for(XUiSkin.SelState.HOVER).draw(ci, r)
				2: XUiSkin.select_style_for(XUiSkin.SelState.FOCUS).draw(ci, r)
				3: XUiSkin.select_style_for(XUiSkin.SelState.PRESSED).draw(ci, r)
			var dy := 1.0 if i == 3 and XUiSkin.SELECT_V2 else 0.0
			btns.draw_string(XUiSkin.font("body"), Vector2(r.position.x, r.position.y + 31 + dy), "确定", HORIZONTAL_ALIGNMENT_CENTER, bw, XUiSkin.FS_LIST, XUiSkin.TEXT)
			btns.draw_string(XUiSkin.font("body"), Vector2(r.position.x, r.end.y + 26), names[i], HORIZONTAL_ALIGNMENT_CENTER, bw, XUiSkin.FS_AUX, XUiSkin.TEXT_2))
	root.add_child(btns)
	return root


func _menu() -> Node:
	_state()
	var menu := XMenu.new()
	add_child(menu)
	await frames(4)
	if menu.skin != null:   # 小A核 P3-1：进第二级、选中「真气」，选中条才画出来（原来停在第一级、前后图一样）
		menu.skin.level = 0
		menu.skin._set_group(2, 0)
		menu.skin.enter()
		menu.skin._set_group(2, 2)
		await frames(3)
	return menu


func _equip() -> Node:
	_state()
	var page := XEquipScene.new()
	add_child(page)
	await frames(4)
	# 小A核 P3-1：确定进候选列表（列表有焦点才画选中条；原来停在左环、前后图一样）
	var e := InputEventAction.new()
	e.action = "ui_accept"
	e.pressed = true
	page._unhandled_input(e)
	await frames(4)
	return page


## ---- 组入口图标 u4：常态一张（第一组选中）＋每组选中各一张，左环部分拼成一张；再存整屏 ----
func _u4_shots(tag: String) -> void:
	XUiSkin.SELECT_V2 = true
	XUiSkin._styles.clear()
	_state()
	var menu := XMenu.new()
	add_child(menu)
	await frames(6)
	var ring: XSkinRingNav = menu.skin.ring
	save(await grab(), "u4_menu_" + tag)
	var crops := []
	var gr := ring.get_global_rect()
	var view := get_viewport().get_visible_rect().size
	var img_w := 0
	for i in ring.items.size():
		ring.select(i, false)
		menu.skin._set_group(i, 0)
		await frames(4)
		var img: Image = await grab()
		var k := img.get_width() / view.x
		var cr := Rect2i(Vector2i(gr.position * k), Vector2i(gr.size * k)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		crops.append(img.get_region(cr))
		img_w = cr.size.x
	var cols := 4
	var rows := ceili(crops.size() / float(cols))
	var h: int = crops[0].get_height()
	var sheet := Image.create(img_w * cols, h * rows, false, crops[0].get_format())
	sheet.fill(Color(0.2, 0.2, 0.2))
	for i in crops.size():
		sheet.blit_rect(crops[i], Rect2i(Vector2i.ZERO, crops[i].get_size()), Vector2i((i % cols) * img_w, (i / cols) * h))
	save(sheet, "u4_each_selected_" + tag)
	menu.queue_free()
	await frames(3)


## ---- 主菜单两级＋助力位卡：第一级停角色、停工坊；第二级角色里选中真气；助力位空／有人 ----
func _two_level_shots(tag: String) -> void:
	XSkinMainMenu._mem = {}
	var s := _state()
	var menu := XMenu.new()
	add_child(menu)
	await frames(5)
	var m: XSkinMainMenu = menu.skin
	m.level = 0
	m._set_group(2, 0)
	m.refresh()
	await frames(4)
	save(await grab(), "menu2_l0_actor_helper_empty_" + tag)
	m._set_group(3, 0)
	m.refresh()
	await frames(4)
	save(await grab(), "menu2_l0_workshop_" + tag)
	m._set_group(2, 0)
	m.enter()
	m._set_group(2, 2)
	await frames(6)
	save(await grab(), "menu2_l1_actor_zhenqi_" + tag)
	menu.queue_free()
	await frames(2)
	# 助力位有人：再收一人（5 人），第 5 个人放进第 5 格
	XTianqi._joining = true
	s.add_actor(12)
	XTianqi._joining = false
	var hid := int(s.party[-1])
	for k in s.battle_slots.size():
		if int(s.battle_slots[k]) == hid:
			s.battle_slots[k] = 0
	if s.battle_slots.size() > XTianqi.HELPER_SLOT:
		s.battle_slots[XTianqi.HELPER_SLOT] = hid
	var menu2 := XMenu.new()
	add_child(menu2)
	await frames(6)
	check("shot_helper_filled_" + tag, s.helper() != null)
	save(await grab(), "menu2_helper_filled_" + tag)
	menu2.queue_free()
	await frames(2)
	XSkinMainMenu._mem = {}


## ---- 平板 4:3 ----
func _tablet() -> void:
	XUiSkin.SELECT_V2 = true
	XUiSkin._styles.clear()
	var vis := func(): return get_viewport().get_visible_rect().size
	_state()
	var menu := XMenu.new()
	add_child(menu)
	await frames(6)
	check("tablet_menu_letterbox", get_tree().root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP and vis.call() == Vector2(1280, 720), vis.call())
	check("tablet_menu_center_not_squeezed", menu.skin != null and menu.skin.layout.center.size.x >= 400.0, null if menu.skin == null else menu.skin.layout.center.size)
	save(await grab(), "p1_tablet_4x3_menu")
	menu.queue_free()
	await frames(3)
	_state()
	var eq := XEquipScene.new()
	add_child(eq)
	await frames(6)
	check("tablet_equip_letterbox", vis.call() == Vector2(1280, 720), vis.call())
	save(await grab(), "p1_tablet_4x3_equip")
	eq.queue_free()
	await frames(3)
	var s := _altar_state()
	var page := XTianqiSkinAltar.new()
	page.setup(s, XTianqiQiyin.altar_options(s))
	add_child(page)
	await frames(6)
	check("tablet_altar_letterbox", vis.call() == Vector2(1280, 720), vis.call())
	save(await grab(), "p1_tablet_4x3_altar")
	page.queue_free()
	await frames(3)
	XTianqiQiyin.set_current("")
	XTianqiQiyin.rng_override = null


func _altar_state() -> XState:
	var lineup := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, 33)
	XState.current = s
	s.flags.tianqi["line"] = "war"
	XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	XTianqiQiyin.set_current("")
	XTianqiQiyin.rng_override = XRandomStream.create("0123012301230123", "qiyin")
	XTianqiQiyin.sync(s)
	XTianqiQiyin.progress(s).drop["first_clear"] = {"bai": true}
	return s
