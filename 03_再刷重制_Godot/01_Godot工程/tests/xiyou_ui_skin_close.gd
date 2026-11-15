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
	await _repair()
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
		["武器种类:剑\n一把普通的剑。", 16, "rgba(170,215,245,1)", false, 0], ["攻击速度+4", 16, "#fff", false, 0], ["购买价格：150", 16, "rgba(255,255,0,1)", false, 0], ["出售价格：21000", 16, "rgba(255,255,0,1)", false, 0]]
	var rows := XSkinTemplatePage.help_rows(raw)
	var texts := rows.map(func(r): return str(r.text))
	check("core_drop_rows", not texts.any(func(t): return t.begins_with("品质") or t.begins_with("武器种类") or t.contains("价格")), texts)
	check("core_row_colors", rows[0].color == XUiSkin.TEXT and rows[1].color == XUiSkin.TEXT, rows)
	var secs := XSkinTemplatePage.help_sections(rows)
	check("core_sections", secs.map(func(x): return x.title) == ["自带", "词条", "套装", "说明"] and secs[0].rows.size() == 3 and secs[3].rows[0].text == "一把普通的剑。", secs.map(func(x): return [x.title, x.rows.size()]))
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
	check("d45_default_face", XUiSkin.CENTER_STYLE == XUiSkin.CenterStyle.FACE)
	var s0 := _state()
	check("d45_sv_frame", XSkinMainMenu.sv_frame(s0.members()[0]) != null and XSkinMainMenu.sv_frame(s0.members()[0], 2).region.position.x > XSkinMainMenu.sv_frame(s0.members()[0]).region.position.x)
	XState.current = null
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


# ---- 小A乙档核查返修（939675d1d）----
func _repair() -> void:
	XUiSkin.TOUCH_V2 = true
	XUiSkin.FONT_V2 = true
	XUiSkin.touch_override = 1
	# P1-2：「Y / 取消」是单键（发取消、不画 ‹ ›）；「上下」是两向键
	check("r_y_cancel_single", not XSkinKeyHints.is_pair("Y / 取消") and XSkinKeyHints.key_events("Y / 取消") == [["ui_cancel", true]])
	check("r_updown_pair", XSkinKeyHints.is_pair("上下") and XSkinKeyHints.key_events("上下") == [["ui_up", true], ["ui_down", true]])
	var h := XSkinKeyHints.new()
	h.set_hints([["Y / 取消", "收起"], ["上下", "滚动"], ["← / →", "切换印"]])
	check("r_chip_texts", h._chip_text(h.hints[0]) == "收起" and h._chip_text(h.hints[1]) == "‹ 滚动 ›" and h._chip_text(h.hints[2]) == "‹ 切换印 ›")
	h.free()
	# 发出去的事件真能到：点「Y / 取消」胶囊＝一次 ui_cancel 按下
	var got := []
	var probe := _Probe.new()
	probe.seen = got
	add_child(probe)
	XSkinKeyHints.fire("Y / 取消")
	XSkinKeyHints.fire("上下", 1)
	await frames(2)
	check("r_fire_reaches", got.has("ui_cancel") and got.has("ui_down"), got)
	probe.queue_free()
	# P1-1：祭坛触屏胶囊整颗在画面里
	var s := _altar_state()
	var page := XTianqiSkinAltar.new()
	page.setup(s, XTianqiQiyin.altar_options(s))
	add_child(page)
	await frames(4)
	var vh := page.view().y
	check("r_altar_hints_inside", page.hints.height() == XSkinKeyHints.TOUCH_H and page.hints.position.y + page.hints.height() <= vh - XUiSkin.HINT_BOTTOM + 0.5,
		[page.hints.position, vh])
	# P2-1：祭坛左上有返回，页名在它右边；P3：环心说明不带 ◆
	check("r_altar_back", page.back_button != null and page.back_button.is_visible_in_tree())
	check("r_ring_done_text", XTianqiSkinAltar.RING_DONE_TEXT == "已揭开")
	page.queue_free()
	await frames(2)
	XTianqiQiyin.set_current("")
	XTianqiQiyin.rng_override = null
	# P2-1：主菜单有返回；模板页右上货币不跟着返回钮挪
	_state()
	var menu := XMenu.new()
	add_child(menu)
	await frames(4)
	check("r_menu_back", menu.skin != null and menu.skin.back_button != null and menu.skin.back_button.is_visible_in_tree())
	menu.queue_free()
	await frames(2)
	check("r_back_place", XSkinBackButton.place(null, 24.0) == 24.0)
	# P2-2：拖动小件；状态页、战技列表接了
	var d := XSkinDrag.new()
	d.press(Vector2(0, 100), 36.0)
	check("r_drag_slop", is_nan(d.motion(Vector2(0, 95))) and d.motion(Vector2(0, 40)) == 96.0 and not d.release())
	d.press(Vector2(0, 100), 0.0)
	check("r_drag_tap", d.release())
	var bl := XSkinBattleSkillList.create_list(Control.new(), range(20).map(func(i): return {"text": "技能 %d" % i, "enabled": true}), "技能")
	bl.active = true
	add_child(bl.get_parent())
	await frames(2)
	var r0 := bl.row_rect(0) if bl.has_method("row_rect") else Rect2()
	var p0 := bl.position + Vector2(bl.size.x / 2.0, XSkinBattleSkillList.HEAD_H + 10.0)
	bl._unhandled_input(_mb(p0, true))
	check("r_battle_press_no_select", bl.index == 0)
	bl._unhandled_input(_mm(p0 - Vector2(0, XSkinBattleSkillList.ROW_H * 3)))
	bl._unhandled_input(_mb(p0 - Vector2(0, XSkinBattleSkillList.ROW_H * 3), false))
	check("r_battle_drag_scrolls", bl.top == 3 and bl.index == 0, [bl.top, bl.index, r0])
	XUiSkin.TOUCH_V2 = false
	bl._unhandled_input(_mb(p0 + Vector2(0, XSkinBattleSkillList.ROW_H), true))
	check("r_battle_off_press_selects", bl.index != 0, bl.index)
	XUiSkin.TOUCH_V2 = true
	bl.get_parent().queue_free()
	# P2-2：子页／检索开着也算全屏页
	var host := Control.new()
	add_child(host)
	var gs := XGearSearch.open(host, [])
	await frames(2)
	check("r_search_in_fullscreen", gs.is_in_group(XUiSkin.FULLSCREEN_GROUP) and XUiSkin.fullscreen_menu_open(get_tree()))
	host.queue_free()
	await frames(2)
	# P2-3：130%＋触屏左环标签不越界；战技名缩字
	XFontScale.set_value("global", 130)
	var ring := XSkinRingNav.new()
	ring.size = Vector2(300, 400)
	var ring0 := XSkinRingNav.new()
	check("r_ring_label_room", ring.label_room(Vector2(258, 100)) == 76.0 and is_inf(ring0.label_room(Vector2(10, 10))))
	ring.free()
	ring0.free()
	var fit := XSkinList.fit_text(XUiSkin.font("body"), "非常非常长的技能名字一二三四五", 120.0, XUiSkin.FS_LIST, XUiSkin.FS_MIN)
	check("r_fit_shrinks", int(fit[1]) <= XUiSkin.FS_LIST and XUiSkin.font("body").get_string_size(str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1])).x <= 120.5, fit)
	var lst := XSkinList.new()
	check("r_list_font_follows", lst.font_size == XUiSkin.FS_LIST and lst.font_size == 25)
	XFontScale.set_value("global", 100)
	check("r_list_font_follows_back", lst.font_size == XUiSkin.FS_LIST and lst.font_size == 21)
	lst.font_size = 30
	check("r_list_font_override", lst.font_size == 30)
	lst.free()
	XUiSkin.touch_override = 0


class _Probe extends Node:
	var seen: Array
	func _input(e: InputEvent) -> void:
		for a in ["ui_cancel", "ui_down", "ui_up"]:
			if e.is_action_pressed(a):
				seen.append(a)


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
## [名字, 收口批开关, 触屏, 字体大小档]；after_touch_130＝触屏＋字号 130%（小A核 P2-3 要看的）
const VARIANTS := [["before", false, 0, 100], ["after", true, 0, 100], ["after_touch", true, 1, 100], ["after_touch_130", true, 1, 130]]
const SIZES := [[Vector2i(1280, 720), "16x9"], [Vector2i(1600, 720), "20x9"], [Vector2i(960, 720), "4x3"]]


func _shots() -> void:
	for sz in SIZES:
		get_window().size = sz[0]
		await frames(6)
		for page in ["items", "equip", "equip_detail", "skill", "status", "menu", "altar"]:
			var imgs := []
			for v in VARIANTS:
				_set_all(bool(v[1]))
				XUiSkin.touch_override = int(v[2])
				XFontScale.set_value("global", int(v[3]))
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
	XFontScale.set_value("global", 100)
	get_window().size = Vector2i(1280, 720)
	await frames(4)
	_set_all(true)
	await _d45()
	await _d44()


## D45：环心三种（现在的大头像／方案 A 小人＋右栏头像／方案 B 小人＋叠放小头像），16:9 与 20:9
func _d45() -> void:
	XUiSkin.touch_override = 0
	for sz in SIZES.slice(0, 2):
		get_window().size = sz[0]
		await frames(6)
		var imgs := []
		for st in [XUiSkin.CenterStyle.FACE, XUiSkin.CenterStyle.SPRITE, XUiSkin.CenterStyle.SPRITE_BADGE]:
			XUiSkin.CENTER_STYLE = st
			var node: Node = await _build_menu()
			await frames(6)
			var img: Image = await grab()
			imgs.append(img)
			save(img, "d45_%s_%s" % [["now_face", "A_sprite", "B_sprite_badge"][st], sz[1]])
			node.queue_free()
			await frames(3)
		check("d45_differs_" + sz[1], imgs[0].get_data() != imgs[1].get_data() and imgs[1].get_data() != imgs[2].get_data())
		save_compare(imgs[1], imgs[2], "d45_A_vs_B_%s" % sz[1])
	XUiSkin.CENTER_STYLE = XUiSkin.CenterStyle.FACE
	get_window().size = Vector2i(1280, 720)
	await frames(4)


## D44：冷黑（默认）对暖炭黑，主菜单、物品、七印祭坛；只出图
func _d44() -> void:
	XUiSkin.touch_override = 0
	for page in ["menu", "items", "altar"]:
		var imgs := []
		for warm in [false, true]:
			XUiSkin.WARM_BG = warm
			XUiSkin._tex.clear()
			XUiSkin._styles.clear()
			var node: Node = await call("_build_" + page)
			await frames(6)
			var img: Image = await grab()
			imgs.append(img)
			save(img, "d44_%s_%s" % [page, "warm" if warm else "cold"])
			node.queue_free()
			await frames(3)
			XTianqiQiyin.set_current("")
			XTianqiQiyin.rng_override = null
		save_compare(imgs[0], imgs[1], "d44_%s_cold_vs_warm" % page)
	XUiSkin.WARM_BG = false
	XUiSkin._tex.clear()
	XUiSkin._styles.clear()


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


func _build_equip_detail() -> Node:
	_state()
	var page := XEquipScene.new()   # 栏位上按 Y：展开身上武器的详情（候选列表第一行是「卸下」，没有详情）
	add_child(page)
	await frames(4)
	var e := InputEventKey.new()
	e.physical_keycode = KEY_Y
	e.keycode = KEY_Y
	e.pressed = true
	page._unhandled_input(e)   # Y：全部属性与词条（展开详情）
	await frames(4)
	return page


func _build_status() -> Node:
	_state()
	var page := XStatusPage.new()
	add_child(page)
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
