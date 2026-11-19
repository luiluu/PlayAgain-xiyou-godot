extends Node
## T287 卡 E「往里一层的环」专项（R5、R6、R7、R13、R15、R21）：
## - R5 设置分类球里写一个字（常战敌画声挂他）、环心写分类名；R6 技能类型球写字、环心是像素小人；R7 装备空栏位画压暗图标不写「空」；
## - R13 技能名品质色走 XUiSkin.quality_color；R15 队伍条不在战斗里不显示 TP；R21 技能页右上不放精魂；
## - 开关 XSkinRingNav.INNER_V2＝false 时全部回旧画法。
## 带 -- --out=<目录> 且有窗口时截图（16:9 800×450、20:9 1000×450；字体 130%；旧画法对照）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []
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


func shot(name: String) -> void:
	if not windowed():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK, img.get_size())
	if name.ends_with("_20x9"):   # P1-1：20:9 必须真是 1000×450，不是 16:9 的复本
		check("shot_size_" + name, img.get_size() == Vector2i(1000, 450), img.get_size())
	elif name.ends_with("_16x9"):
		check("shot_size_" + name, img.get_size() == Vector2i(800, 450), img.get_size())


## 16:9（800×450）拍一张，wide 时再拍 20:9（1000×450）
func shots(name: String, wide := true) -> void:
	if not windowed():
		return
	var win := get_window()
	var old := win.size
	var old_aspect := win.content_scale_aspect
	win.size = Vector2i(800, 450)
	await frames(14)
	await shot(name + "_16x9")
	if wide:
		win.unresizable = false
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
		win.size = Vector2i(1000, 450)
		DisplayServer.window_set_size(Vector2i(1000, 450))
		await get_tree().create_timer(0.6).timeout
		await frames(12)
		await shot(name + "_20x9")
	win.content_scale_aspect = old_aspect
	win.size = old
	await frames(4)


func _act(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.flags["tianqi"] = {"rules": 1}
	return s


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_card_e")
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	await _options()
	await _skill()
	await _equip()
	await _strip_tp()
	await _rollback()
	XUiSkin.motion_override = -1
	XState.current = null
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- R5 设置分类环 ----
func _options() -> void:
	_state()
	var page := XOptionsScene.new()
	add_child(page)
	await frames(3)
	var sk := page.skin
	if not check("opt_built", sk != null):
		page.queue_free()
		return
	var glyphs := sk.ring.items.map(func(it): return str(it.get("glyph", "")))
	check("opt_glyphs", glyphs == ["常", "战", "敌", "画", "声", "挂", "他"], glyphs)
	check("opt_glyph_no_other_char", not glyphs.has("其"))
	check("opt_ring_center_empty", sk.ring_center.is_empty(), sk.ring_center)
	for k in sk.cats.size():
		check("opt_cur_%d" % k, sk.cur == k and sk.ring.index == k, [sk.cur, sk.ring.index])
		await shots("card_e_options_%d_%s" % [k + 1, sk.cats[k].key])
		sk.step_category(1)
		await frames(3)
	# 字体 130%：设置里字体调到最大
	XFontScale.set_value("global", 130)
	sk.sync()
	await frames(3)
	await shots("card_e_options_font130", false)
	XFontScale.set_value("global", 100)
	page.queue_free()
	await frames(3)


# ---- R6、R13、R21 技能页 ----
func _skill() -> void:
	var s := _state()
	var page := XSkillScene.new()
	add_child(page)
	await frames(3)
	var sk := page.skin
	if not check("skill_built", sk != null):
		page.queue_free()
		return
	var best := 0
	for i in s.members().size():
		page.actor_index = i
		page.type_index = 0
		page._refresh()
		await frames(2)
		if page.types().size() > best:
			best = page.types().size()
	var pick := 0
	for i in s.members().size():
		page.actor_index = i
		page._refresh()
		await frames(2)
		if page.types().size() == best:
			pick = i
			break
	page.actor_index = pick
	page.type_index = 0
	page._refresh()
	await frames(3)
	check("skill_types_ge3", page.types().size() >= 3, page.types())
	check("skill_strip_keeps_tp", sk.party.show_tp == true)
	check("skill_no_currency", sk.currencies is Array and sk.currencies.is_empty() and sk.currency_pairs().is_empty(), sk.currencies)
	var used := []
	for k in page.types().size():
		var nm := page.type_name(int(page.types()[k]))
		var g := XSkinSkillPage.glyph_of(nm, used)
		used.append(g)
		check("skill_glyph_%d" % k, str(sk.ring.items[k].get("glyph", "")) == g and nm != "", [sk.ring.items[k], nm])
	check("skill_glyphs_unique", used.size() == used.duplicate().filter(func(x): return used.count(x) == 1).size(), used)
	# P2-1：专有类型显式映射＋撞字避让
	check("skill_glyph_special", XSkinSkillPage.glyph_of("鬼灭呼吸法") == "呼" and XSkinSkillPage.glyph_of("伊莉雅被动") == "专"
		and XSkinSkillPage.glyph_of("光环") == "环" and XSkinSkillPage.glyph_of("呼吸法") == "呼" and XSkinSkillPage.glyph_of("被动") == "被")
	check("skill_glyph_collide", XSkinSkillPage.glyph_of("鬼灭呼吸法", ["呼"]) == "灭" and XSkinSkillPage.glyph_of("伊莉雅被动", ["专"]) == "莉")
	check("skill_glyph_unmapped_first_char", XSkinSkillPage.glyph_of("奇术") == "奇")
	check("skill_glyph_other", XSkinSkillPage.glyph_of("其他") == "他" and XSkinSkillPage.glyph_of("魔法") == "魔" and XSkinSkillPage.glyph_of("功法") == "功")
	check("skill_center_sprite", sk._use_sprite(page.actor()) and sk._sprite_layer != null and sk._sprite_layer.visible, XSkinMainMenu.sv_frame(page.actor()))
	for k in page.types().size():
		page.type_index = k
		page.index = 0
		page._refresh()
		await frames(2)
		await shots("card_e_skill_type%d" % (k + 1))
	# 品质色：有品质标记的技能走皮肤品质色（优秀＝调柔后的绿，不是荧光绿 #80ff1c）
	var good := {"meta": {"quality": "2"}, "id": 1}
	check("skill_color_quality", XSkinSkillPage.name_color(good) == XUiSkin.quality_color(XQuality.show_grade(good)), XSkinSkillPage.name_color(good))
	check("skill_color_not_neon", XSkinSkillPage.name_color(good) != Color("80ff1c"), XSkinSkillPage.name_color(good))
	var plain := {"meta": {}, "id": 1}
	check("skill_color_plain_unchanged", XSkinSkillPage.name_color(plain) == XQuality.list_color(plain))
	# 列表行的名字色与详情牌标题色同源
	page.type_index = 0
	page.mode = "list"
	page._refresh()
	await frames(2)
	if page.entries().size() > 0:
		check("skill_row_color", sk.list.items[0].color == XSkinSkillPage.name_color(page.entries()[0]), sk.list.items[0].color)
	XFontScale.set_value("global", 130)
	page._refresh()
	await frames(3)
	await shots("card_e_skill_font130", false)
	XFontScale.set_value("global", 100)
	page.queue_free()
	await frames(3)


# ---- R7 装备空栏位 ----
func _equip() -> void:
	var s := _state()
	var a: XActor = s.members()[0]
	for slot in XTianqiGear.view(a):
		XEquipment.change(s, a, int(slot), null)
	var page := XEquipScene.new()
	add_child(page)
	await frames(3)
	var sk := page.skin
	if not check("equip_built", sk != null):
		page.queue_free()
		return
	check("equip_13_one_ring", sk.ring.items.size() == 13, sk.ring.items.size())
	var dim := sk.ring.items.filter(func(it): return bool(it.get("icon_dim", false)) and int(it.icon) > 0 and bool(it.empty))
	check("equip_13_silhouettes", dim.size() == 13, dim.map(func(it): return [it.key, it.icon]))
	check("equip_silhouette_weapon", XSkinEquipPage.silhouette_icon(1) > 0 and XSkinEquipPage.silhouette_icon(3) > 0)
	check("equip_no_currency", sk.currency_pairs().is_empty())
	check("equip_strip_no_tp", sk.actor_strip.show_tp == false)
	await shots("card_e_equip_empty13")
	XFontScale.set_value("global", 130)
	sk.sync()
	await frames(3)
	await shots("card_e_equip_font130", false)
	XFontScale.set_value("global", 100)
	page.queue_free()
	await frames(3)


# ---- R15 队伍条 TP ----
func _strip_tp() -> void:
	var s := _state()
	var strip := XSkinPartyStrip.new()
	check("strip_default_shows_tp", strip.show_tp == true)   # P2-2：别处（战斗内我方状态详情等）保持显示 TP
	strip.size = Vector2(400, 80)
	add_child(strip)
	strip.set_members([XSkinPartyStrip.from_actor(s.members()[0])])
	await frames(2)
	# 主菜单上的队伍条：不显示 TP
	var xm := XMenu.new()
	add_child(xm)
	await frames(3)
	var menu = xm.skin
	check("menu_built", menu != null)
	check("menu_party_no_tp", menu != null and menu.party != null and not menu.party.show_tp)   # 认祖先 XSkinMainMenu 自动关
	await shots("card_e_menu_no_tp")
	xm.queue_free()
	strip.queue_free()
	await frames(2)


# ---- 开关回退 ----
func _rollback() -> void:
	XSkinRingNav.INNER_V2 = false
	var s := _state()
	var opt := XOptionsScene.new()
	add_child(opt)
	await frames(3)
	var o := opt.skin
	check("rb_opt_center_count", o != null and o.ring_center == [str(o.cats[0].idx.size()), "项"], o.ring_center if o != null else null)
	await shots("card_e_old_options", false)
	opt.queue_free()
	await frames(2)
	var sp := XSkillScene.new()
	add_child(sp)
	await frames(3)
	check("rb_skill_currency_default", sp.skin != null and sp.skin.currencies == null)
	check("rb_skill_no_sprite", not sp.skin._use_sprite(sp.actor()))
	check("rb_skill_color_old", XSkinSkillPage.name_color({"meta": {"quality": "2"}}) == XQuality.list_color({"meta": {"quality": "2"}}))
	await shots("card_e_old_skill", false)
	sp.queue_free()
	await frames(2)
	var a: XActor = s.members()[0]
	for slot in XTianqiGear.view(a):
		XEquipment.change(s, a, int(slot), null)
	var eq := XEquipScene.new()
	add_child(eq)
	await frames(3)
	check("rb_equip_no_dim", eq.skin.ring.items.all(func(it): return not it.has("icon_dim") and int(it.icon) == 0), eq.skin.ring.items[0])
	await shots("card_e_old_equip", false)
	eq.queue_free()
	await frames(2)
	XSkinRingNav.INNER_V2 = true
