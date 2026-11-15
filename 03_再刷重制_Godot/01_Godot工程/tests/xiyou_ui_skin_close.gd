extends Node
## 收口批（cc/ui-skin-close）专项：换芯（旧颜色对照表、详情牌分节、去价格行、战斗说明卡让开行动条）、字号与触屏（字号倍率、提示胶囊、
## 左上返回、列表拖动、全屏菜单收虚拟键、指令环右下）、舒适（见 _comfort）、D45／D44 方案图；每个开关关掉＝回 p1fix 的断言。
## 带 -- --out=<目录> 且有窗口时出改前改后对照图：收口批开关全关（＝p1fix）／全开（键盘）／全开＋触屏，16:9、20:9、4:3 各一组。
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


## 左右拼：左改前、右改后（触屏），中间 16px 灰缝
func save_compare(a: Image, b: Image, name: String) -> void:
	var gap := 16
	var img := Image.create(a.get_width() + gap + b.get_width(), maxi(a.get_height(), b.get_height()), false, a.get_format())
	img.fill(Color(0.35, 0.35, 0.35))
	img.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	img.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width() + gap, 0))
	save(img, name)




func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_close")
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	_core()
	_font()
	await _touch()
	_comfort()
	if windowed():
		await _shots()
	_set_all(true)
	XUiSkin.touch_override = -1
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XState.current = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 收口批开关一起开关（截图「改前」＝全关＝p1fix）
func _set_all(on: bool) -> void:
	XUiSkin.CORE_V2 = on
	XUiSkin.FONT_V2 = on
	XUiSkin.TOUCH_V2 = on
	XUiSkin.COMFORT_V2 = on
	XUiSkin._styles.clear()
	XUiSkin._tex.clear()


func _state(tianqi := true) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	if tianqi:
		s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian", "line": "war"}
	s.set_variable(20, 32)
	s.gold = 12480
	for id in range(1, 40):   # 几把武器：物品页武器类、装备页候选列表有东西
		var rec := XDB.rec("Weapons", id)
		if not rec.is_empty() and str(rec.get("name", "")) != "" and not str(rec.get("name", "")).begins_with("-"):
			s.gain_gear("weapons", id, 1)
	return s


# ---- 1 换芯 ----
func _core() -> void:
	XUiSkin.CORE_V2 = true
	check("legacy_yellow_gold", XUiSkin.legacy_color(Color8(255, 255, 0)) == XUiSkin.GOLD_LIGHT)
	check("legacy_red_text", XUiSkin.legacy_color(Color8(255, 128, 128)) == XUiSkin.TEXT and XUiSkin.legacy_color(Color8(255, 76, 76)) == XUiSkin.TEXT)
	check("legacy_blue_cyan_aux", XUiSkin.legacy_color(Color8(76, 76, 255)) == XUiSkin.TEXT_2 and XUiSkin.legacy_color(Color8(170, 215, 245)) == XUiSkin.TEXT_2)
	check("legacy_green_text", XUiSkin.legacy_color(Color8(128, 255, 28)) == XUiSkin.TEXT)
	check("legacy_white_text", XUiSkin.legacy_color(Color8(235, 240, 247)) == XUiSkin.TEXT)
	var raw := [["名字", 20, "#fff", false, 0], ["品质：精良", 17, "rgba(57,185,255,1)", false, 0], ["武器种类:刀/剑", 16, "#fff", false, 0],
		["最大生命值：50", 16, "rgba(255,128,128,1)", false, 0], ["攻击力：45", 16, "rgba(255,76,76,1)", false, 0],
		["特效：暴击率+5%", 16, "rgba(128,255,128,1)", false, 0], ["龙鳞套装（2/4）", 16, "rgba(255,255,0,1)", false, 0],
		["一把普通的剑。", 16, "rgba(170,215,245,1)", false, 0], ["购买价格：150", 16, "rgba(255,255,0,1)", false, 0], ["出售价格：21000", 16, "rgba(255,255,0,1)", false, 0]]
	var rows := XSkinTemplatePage.help_rows(raw)
	var texts := rows.map(func(r): return str(r.text))
	check("core_drop_rows", not texts.any(func(t): return t.begins_with("品质") or t.begins_with("武器种类") or t.contains("价格")), texts)
	check("core_row_colors", rows[0].color == XUiSkin.TEXT and rows[1].color == XUiSkin.TEXT, rows)
	var secs := XSkinTemplatePage.help_sections(rows)
	check("core_sections", secs.map(func(x): return x.title) == ["自带", "词条", "套装", "说明"] and secs[0].rows.size() == 2, secs.map(func(x): return [x.title, x.rows.size()]))
	check("core_battle_card_above_otb", XSkinBattle.help_card_pos(Vector2(400, 500), Vector2(412, 310)).y + 310 <= XSkinOTBBar.POS.y - 12.0 \
		and XSkinBattle.help_card_pos(Vector2(400, 100), Vector2(412, 310)).y == 100.0)
	XUiSkin.CORE_V2 = false
	var old := XSkinTemplatePage.help_rows(raw)
	check("core_off_keeps_rows", old.size() == raw.size() - 1 and old[0].text == "品质：精良" and old.any(func(r): return str(r.text).begins_with("购买价格")), old.map(func(r): return r.text))
	check("core_off_keeps_color", old[2].color == Color8(255, 128, 128))
	check("core_off_one_section", XSkinTemplatePage.help_sections(old).size() == 1 and XSkinTemplatePage.help_sections(old)[0].title == "")
	check("core_off_legacy_identity", XUiSkin.legacy_color(Color8(255, 255, 0)) == Color8(255, 255, 0))
	XUiSkin.CORE_V2 = true


# ---- 2 字号 ----
func _font() -> void:
	XUiSkin.FONT_V2 = true
	XUiSkin.touch_override = 0
	XFontScale.set_value("global", 100)
	check("font_base", XUiSkin.FS_LIST == 19 and XUiSkin.FS_AUX == 15 and XUiSkin.FS_MIN == 15, [XUiSkin.FS_LIST, XUiSkin.FS_AUX])
	XUiSkin.touch_override = 1
	check("font_touch_step", XUiSkin.FS_LIST == 21 and XUiSkin.FS_AUX == 17, [XUiSkin.FS_LIST, XUiSkin.FS_AUX])
	XFontScale.set_value("global", 130)
	check("font_cap_130", XUiSkin.FS_LIST == 25 and XUiSkin.FS_AUX_MAX == 22, [XUiSkin.FS_LIST, XUiSkin.FS_AUX_MAX])
	check("font_page_fixed", XUiSkin.FS_PAGE == 34)
	XUiSkin.FONT_V2 = false
	check("font_off", XUiSkin.FS_LIST == 19 and XUiSkin.FS_AUX == 14 and XUiSkin.FS_MIN == 14, [XUiSkin.FS_LIST, XUiSkin.FS_AUX])
	XUiSkin.FONT_V2 = true
	XFontScale.set_value("global", 100)
	XUiSkin.touch_override = 0


# ---- 2 触屏 ----
func _touch() -> void:
	XUiSkin.TOUCH_V2 = true
	XUiSkin.touch_override = 1
	var h := XSkinKeyHints.new()
	h.set_hints([["确定", "选择"], ["取消", "返回"], ["Q / E", "换人"], ["X", "检索排序"]])
	add_child(h)
	check("hints_touch_chips", h.mouse_filter == Control.MOUSE_FILTER_STOP and h.size.y == XSkinKeyHints.TOUCH_H and h.chip_rect(1).size.y >= 44.0)
	check("hints_hit_pair_halves", h.hit(h.chip_rect(2).position + Vector2(4, 20)) == [2, 0] and h.hit(h.chip_rect(2).end - Vector2(4, 20)) == [2, 1])
	check("hints_key_events", XSkinKeyHints.key_events("Q / E") == [[KEY_Q, false], [KEY_E, false]] and XSkinKeyHints.key_events("取消") == [["ui_cancel", true]] \
		and XSkinKeyHints.key_events("键盘 C") == [[KEY_C, false]] and XSkinKeyHints.key_events("X") == [[KEY_X, false]])
	XUiSkin.touch_override = 0
	h.set_hints(h.hints)
	check("hints_keyboard_plain", h.mouse_filter == Control.MOUSE_FILTER_IGNORE and h.size.y == XSkinKeyHints.H)
	XUiSkin.touch_override = 1
	XUiSkin.TOUCH_V2 = false
	h.set_hints(h.hints)
	check("hints_touch_off", h.mouse_filter == Control.MOUSE_FILTER_IGNORE and h.size.y == XSkinKeyHints.H)
	h.queue_free()
	# 列表：拖动滚、不选；松手才算点
	XUiSkin.TOUCH_V2 = true
	var l := XSkinList.new()
	l.size = Vector2(400, 46 * 5)
	add_child(l)
	var items := []
	for i in 30:
		items.append({"text": "第 %d 行" % i})
	l.set_items(items)
	await frames(2)
	l._gui_input(_mb(Vector2(100, 200), true))
	check("list_press_no_select", l.index == 0)
	l._gui_input(_mm(Vector2(100, 200 - 46 * 3)))
	l._gui_input(_mb(Vector2(100, 200 - 46 * 3), false))
	check("list_drag_scrolls", l.top_row == 3 and l.index == 0, [l.top_row, l.index])
	l._gui_input(_mb(Vector2(100, 70), true))
	l._gui_input(_mb(Vector2(100, 70), false))
	check("list_tap_selects", l.index == 3 * l.columns + 1, l.index)
	check("list_scroll_w", l.scroll_w() == 8.0)
	XUiSkin.TOUCH_V2 = false
	l.scroll_to(0)
	l._gui_input(_mb(Vector2(100, 70), true))
	check("list_off_press_selects", l.index == 1 and l.scroll_w() == XSkinList.SCROLL_W, l.index)
	l.queue_free()
	XUiSkin.TOUCH_V2 = true
	# 全屏菜单收虚拟键；模板页左上返回
	_state()
	var page := XSkinTemplatePage.new()
	add_child(page)
	await frames(3)
	check("fullscreen_open", XUiSkin.fullscreen_menu_open(get_tree()))
	check("back_button", page.back_button != null and page.back_button.get_parent() == page)
	XUiSkin.TOUCH_V2 = false
	check("fullscreen_off", not XUiSkin.fullscreen_menu_open(get_tree()))
	XUiSkin.TOUCH_V2 = true
	page.queue_free()
	await frames(2)
	check("fullscreen_closed", not XUiSkin.fullscreen_menu_open(get_tree()))
	# 指令环：触屏固定右下，键盘跟角色
	var holder := Control.new()
	add_child(holder)
	var ring := XSkinBattleRing.create_ring(holder, [{"text": "攻击"}, {"text": "技能"}, {"text": "防御"}, {"text": "物品"}], "美娜")
	ring.place_for_actor(Vector2(500, 300), XBattleScene.BOX)
	check("ring_touch_corner", ring.position + ring.size == XBattleScene.BOX - Vector2(XSkinBattleRing.MARGIN, XSkinBattleRing.MARGIN), ring.position)
	XUiSkin.touch_override = 0
	ring.place_for_actor(Vector2(500, 300), XBattleScene.BOX)
	check("ring_keyboard_follows", ring.position + ring.size != XBattleScene.BOX - Vector2(XSkinBattleRing.MARGIN, XSkinBattleRing.MARGIN))
	holder.queue_free()
	await frames(1)


# ---- 3 舒适 ----
func _comfort() -> void:
	XUiSkin.COMFORT_V2 = true
	check("comfort_text", XUiSkin.TEXT == Color("e6e2dc") and XUiSkin.TEXT_3 == Color("8e8982") and XUiSkin.QUALITY[1] == Color("8fdc5a"))
	check("comfort_hp_bar", XUiSkin.bar_h("hp") == 8.0 and XUiSkin.bar_h("mp") == 5.0)
	var sb := StyleBoxFlat.new()
	XUiSkin.primary_button_style(sb, false)
	check("comfort_button_idle_gold", sb.bg_color == XUiSkin.BTN_IDLE_FILL and sb.border_color.is_equal_approx(Color(XUiSkin.GOLD, 0.85)))
	XUiSkin.primary_button_style(sb, true)
	check("comfort_button_focus_red", sb.bg_color == XUiSkin.SEL_FILL)
	# 去急闪：一秒内亮度最多升降一次（原来 sin·TAU 绝对值一秒两峰）
	var peaks := 0
	var prev := XUiSkin.target_pulse(0.0)
	var up := true
	for k in range(1, 101):
		var v := XUiSkin.target_pulse(k / 100.0)
		if up and v < prev:
			peaks += 1
		up = v >= prev
		prev = v
	check("comfort_pulse_slow", peaks == 0, peaks)
	check("comfort_altar_shapes", XTianqiSkinAltar.STATE_TEXT[2].begins_with("◆") and XTianqiSkinAltar.STATE_TEXT[1].begins_with("◇"))
	check("warm_bg_default_off", not XUiSkin.WARM_BG and XUiSkin.BG == Color("050506"))
	XUiSkin.COMFORT_V2 = false
	check("comfort_off", XUiSkin.TEXT == Color("f0f0ee") and XUiSkin.TEXT_3 == Color("7d8086") and XUiSkin.QUALITY[1] == Color("80ff1c") and XUiSkin.bar_h("hp") == 5.0 \
		and XTianqiSkinAltar.STATE_TEXT[0] == "未开启")
	XUiSkin.primary_button_style(sb, false)
	check("comfort_off_button_red", sb.bg_color == XUiSkin.SEL_FILL)
	var p2 := 0.0
	for k in range(0, 100):
		p2 = maxf(p2, absf(XUiSkin.target_pulse(k / 100.0) - XUiSkin.target_pulse(k / 100.0 + 0.25)))
	check("comfort_off_old_pulse", p2 > 0.3)
	XUiSkin.COMFORT_V2 = true
	XUiSkin.WARM_BG = true
	check("warm_bg_on", XUiSkin.BG == Color("080708") and XUiSkin.LINE == Color("b0a79b"))
	XUiSkin.WARM_BG = false


func _mb(p: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	return e


func _mm(p: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	return e


# ---- 改前改后对照图 ----
const VARIANTS := [["before", false, 0], ["after", true, 0], ["after_touch", true, 1]]
const SIZES := [[Vector2i(1280, 720), "16x9"], [Vector2i(1600, 720), "20x9"], [Vector2i(960, 720), "4x3"]]


func _shots() -> void:
	for sz in SIZES:
		get_window().size = sz[0]
		await frames(6)
		for page in ["items", "equip", "skill", "menu", "altar"]:
			var imgs := []
			for v in VARIANTS:
				_set_all(bool(v[1]))
				XUiSkin.touch_override = int(v[2])
				var node: Node = await call("_build_" + page)
				await frames(6)
				var img: Image = await grab()
				imgs.append(img)
				save(img, "%s_%s_%s" % [page, sz[1], v[0]])
				node.queue_free()
				await frames(3)
				XTianqiQiyin.set_current("")
				XTianqiQiyin.rng_override = null
			check("differs_%s_%s" % [page, sz[1]], imgs[0].get_data() != imgs[2].get_data())
			save_compare(imgs[0], imgs[2], "%s_%s_compare" % [page, sz[1]])
	get_window().size = Vector2i(1280, 720)
	await frames(4)
	_set_all(true)


func _key(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _build_items() -> Node:
	_state()
	var page := XItemScene.new()
	add_child(page)
	await frames(4)
	page._unhandled_input(_key("ui_right"))
	page._unhandled_input(_key("ui_right"))   # 环：物品、消耗品、武器
	page._unhandled_input(_key("ui_accept"))
	await frames(2)
	return page


func _build_equip() -> Node:
	_state()
	var page := XEquipScene.new()
	add_child(page)
	await frames(4)
	page._unhandled_input(_key("ui_accept"))
	await frames(4)
	return page


func _build_skill() -> Node:
	_state()
	var page := XSkillScene.new()
	add_child(page)
	await frames(4)
	page._unhandled_input(_key("ui_accept"))
	await frames(2)
	return page


func _build_menu() -> Node:
	_state()
	var menu := XMenu.new()
	add_child(menu)
	await frames(4)
	if menu.skin != null:
		menu.skin.level = 0
		menu.skin._set_group(2, 0)
		menu.skin.enter()
		menu.skin._set_group(2, 2)
		await frames(3)
	return menu


func _build_altar() -> Node:
	var s := _altar_state()
	var page := XTianqiSkinAltar.new()
	page.setup(s, XTianqiQiyin.altar_options(s))
	add_child(page)
	await frames(4)
	return page


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
