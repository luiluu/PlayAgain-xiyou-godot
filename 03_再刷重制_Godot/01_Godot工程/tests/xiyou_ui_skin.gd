extends Node
## 新界面第 0 期（XUiSkin 皮肤层＋ui/skin/ 通用组件，界面风格提案 v0.7 红乙）：
## - 颜色、字号四级、间距、行高、选中条参数与稿（第二、三节）一致；
## - 开关：ENABLED（O-467）、调试强开 FORCE／--ui-skin=、只在天启篇存档开（发行门照 XTianqiLine.open_for）、西游存档与标题不开；
## - 选中条：0.09 秒滑动、连按不排队（从当前位置重新出发）、动效关时直接跳、呼吸 0.75～1（简化／关时恒 1）；
## - 组配置：天启篇宠物组随 XTianqiPetHide 整组隐藏（6 组）、放开后 7 组；只剩一项的组直接进；
## - 组件能实例化：直列表（一列／两列、循环、滚动）、环（选中、光弧转到位）、页签（Q／E 循环）、弧形量条、角色条、详情牌、按键提示；
## - 横屏锚点：1280（16:9）边距 24、1600（20:9）边距 56、中间块最宽 720、三块不重叠；
## - 挂钩：开着时菜单底换黑底、关着时照旧；GLOBAL_FONT 默认关、旧页面字体不变；三款字体能载入、常用字在裁过的字里；
## 加 -- --out=<目录> 且有窗口时，存组件陈列页 16:9、20:9 两张和旧菜单强开新皮肤的截图。
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


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	check("screenshot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK, img.get_size())


func _key(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin")
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	_tokens()
	_switch()
	_select_bar()
	_groups()
	await _components()
	_layout()
	await _hooks()
	_fonts()
	await _showcase()
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XState.current = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## ---- 常量与稿一致（第二、三节）----
func _tokens() -> void:
	var want := {"BG": "050506", "PANEL": "18191c", "LINE": "a2a5ab", "TEXT": "f0f0ee", "TEXT_2": "a8aaaf", "TEXT_3": "7d8086",
		"SEL_LINE": "ff5a48", "SEL_FILL": "cf2a1f", "GOLD": "e3bd72", "GOLD_LIGHT": "f2d08a", "HP": "ff78b0", "MP": "4d8dff",
		"TP": "46e0b0", "UP": "6fe3a1", "DOWN": "ffa35c"}
	var bad := []
	var consts := (load("res://modes/xiyou/ui/skin/ui_skin.gd") as Script).get_script_constant_map()
	for k in want:
		if (consts[k] as Color).to_html(false) != want[k]:
			bad.append([k, (consts[k] as Color).to_html(false)])
	check("colors", bad.is_empty(), bad)
	check("quality", XUiSkin.QUALITY.map(func(c): return (c as Color).to_html(false))
		== ["ebf0f7", "80ff1c", "39b9ff", "9d88ff", "ffa040", "ffd65a", "ff483c"] and XUiSkin.QUALITY_NAMES.size() == 7)
	check("font_tiers", XUiSkin.FONT_TIERS == {"page": [34, 34], "card": [26, 38], "list": [19, 24], "aux": [14, 17]}
		and XUiSkin.FS_PAGE == 34 and XUiSkin.FS_CARD == 26 and XUiSkin.FS_CARD_MAX == 38 and XUiSkin.FS_LIST == 19
		and XUiSkin.FS_LIST_MAX == 24 and XUiSkin.FS_AUX == 14 and XUiSkin.FS_AUX_MAX == 17 and XUiSkin.FS_MIN == 14)
	var eights := [XUiSkin.GRID, XUiSkin.TOP, XUiSkin.PANEL_GAP, XUiSkin.PAD, XUiSkin.PAD_LG, XUiSkin.EDGE, XUiSkin.SAFE_X, XUiSkin.CENTER_MAX]
	check("spacing_x8", eights.all(func(v): return v % 8 == 0) and XUiSkin.TOP == 72 and XUiSkin.BOTTOM == 668
		and XUiSkin.PANEL_GAP == 16 and XUiSkin.SAFE_X == 56 and XUiSkin.CENTER_MAX == 720 and XUiSkin.HINT_BOTTOM == 10, eights)
	check("row_heights", XUiSkin.ROW_H == 46 and XUiSkin.ROW_H_ITEMS == 48 and XUiSkin.ROW_H_MENU == 56 and XUiSkin.ROW_H_SKILL == 44)
	check("select_params", XUiSkin.BAR_W == 4.0 and XUiSkin.BAR_INSET == 5.0 and XUiSkin.OUTLINE_ALPHA == 0.45
		and XUiSkin.FILL_ALPHA == 0.40 and XUiSkin.SLIDE_TIME == 0.09 and XUiSkin.BREATH_TIME == 1.6)
	# p1fix（小A审 P1-1）：加厚版默认开；v0.7 的值留着可切回
	check("select_v2_params", XUiSkin.SELECT_V2 and XUiSkin.SEL2_BAR_W == 6.0 and XUiSkin.SEL2_BAR_INSET == 2.0 and XUiSkin.SEL2_OUTLINE_W == 2
		and XUiSkin.SEL2_OUTLINE_ALPHA == 1.0 and XUiSkin.SEL2_FILL_ALPHA >= 0.9 and XUiSkin.SEL2_FILL_R.a == 1.0)
	check("select_v2_red_text", XUiSkin.sel_text(XUiSkin.QUALITY[6]) == XUiSkin.SEL2_RED_TEXT and XUiSkin.sel_text(XUiSkin.SEL_LINE) == XUiSkin.SEL2_RED_TEXT
		and XUiSkin.sel_text(XUiSkin.QUALITY[4]) == XUiSkin.QUALITY[4] and XUiSkin.sel_text(XUiSkin.TEXT) == XUiSkin.TEXT and XUiSkin.sel_text(XUiSkin.HP) == XUiSkin.HP)
	XUiSkin.SELECT_V2 = false
	check("select_v2_off_keeps_text", XUiSkin.sel_text(XUiSkin.QUALITY[6]) == XUiSkin.QUALITY[6])
	XUiSkin.SELECT_V2 = true
	_select_pixels()
	check("snap", XUiSkin.snap(1) == 8 and XUiSkin.snap(16) == 16 and XUiSkin.snap(17) == 24)


## ---- 开关 ----
func _switch() -> void:
	XState.current = null
	check("off_no_state", not XUiSkin.on())
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	check("off_xiyou_save", not XUiSkin.on())
	s.flags["tianqi"] = {"rules": 1}
	check("on_tianqi_save", XUiSkin.on())
	ReleaseEntry.simulate_release = true
	check("off_release_gate", not XUiSkin.on())   # 天启篇没对玩家开放（RELEASE_OPEN）时发行构建不开
	ReleaseEntry.simulate_release = false
	XUiSkin.ENABLED = false
	check("off_switch", not XUiSkin.on())
	XUiSkin.FORCE = true
	check("off_switch_beats_force", not XUiSkin.on())
	XUiSkin.ENABLED = true
	s.flags.erase("tianqi")
	check("force_on_xiyou", XUiSkin.on())
	XUiSkin.FORCE = false
	check("cli_parse", XUiSkin.parse_cli(PackedStringArray(["--ui-skin=new"]), false) == 1
		and XUiSkin.parse_cli(PackedStringArray(["--ui-skin=old"]), false) == 0
		and XUiSkin.parse_cli(PackedStringArray(["--ui-skin=new"]), true) == -1
		and XUiSkin.parse_cli(PackedStringArray([]), false) == -1)
	XUiSkin._cli_mode = 1
	check("cli_force_on", XUiSkin.on())
	XUiSkin._cli_mode = -1
	check("cli_unset_off", not XUiSkin.on())
	XUiSkin._cli_mode = -2
	# 动效档：省电模式按简化
	XUiSkin.motion_override = -1
	check("motion_default_full", XUiSkin.motion() == XUiSkin.Motion.FULL)
	XGraphics.set_value("low", true)
	check("motion_low_power_simple", XUiSkin.motion() == XUiSkin.Motion.SIMPLE and not XUiSkin.breathing() and XUiSkin.slide_time() == 0.09)
	XGraphics.set_value("low", false)
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	check("motion_off", XUiSkin.slide_time() == 0.0 and XUiSkin.breath_alpha(0.8) == 1.0)
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	var lo := 1.0
	var hi := 0.0
	for k in range(64):
		var a := XUiSkin.breath_alpha(k * 0.05)
		lo = minf(lo, a)
		hi = maxf(hi, a)
	check("breath_range", is_equal_approx(XUiSkin.breath_alpha(0.0), 0.75) and is_equal_approx(XUiSkin.breath_alpha(1.6), 1.0)
		and is_equal_approx(XUiSkin.breath_alpha(3.2), 0.75) and lo >= 0.75 - 0.0001 and hi <= 1.0001, [lo, hi])


## ---- 选中条：滑动、连按不排队、动效关直接跳 ----
func _select_bar() -> void:
	var b := XSkinSelectBar.new()
	var r0 := Rect2(0, 0, 300, 46)
	var r1 := Rect2(0, 46, 300, 46)
	var r2 := Rect2(0, 92, 300, 46)
	b.move_to(r0)
	check("bar_first_instant", b.current_rect() == r0 and not b.moving() and b.slides == 0)
	b.move_to(r1)
	check("bar_starts", b.moving() and b.current_rect() == r0 and b.slides == 1)
	b.advance(0.045)
	var mid := b.current_rect().position.y
	check("bar_mid", mid > 0.0 and mid < 46.0, mid)
	b.move_to(r2)   # 连按：从 mid 出发直奔 r2，不先回到 r1
	check("bar_no_queue_start", is_equal_approx(b.current_rect().position.y, mid) and b.target == r2 and b.slides == 2)
	b.advance(0.03)
	check("bar_no_queue_path", b.current_rect().position.y > mid and b.current_rect().position.y < 92.0)
	b.advance(0.06)
	check("bar_arrives_009", not b.moving() and b.current_rect() == r2 and b.position == r2.position and b.size == r2.size)
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	b.move_to(r0)
	check("bar_motion_off_jump", not b.moving() and b.current_rect() == r0 and b.slides == 2)
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	b.free()


## ---- 组：宠物整组隐藏、只剩一项直接进 ----
func _groups() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.flags["tianqi"] = {"rules": 1}
	XState.current = s
	var keys := XUiSkin.visible_groups(XUiSkin.GROUPS, s).map(func(g): return g.key)
	check("groups_tianqi_6", keys == ["items", "equip", "actor", "workshop", "codex", "system"], keys)
	var actor: Dictionary = XUiSkin.GROUPS[2]
	check("actor_has_formation", XUiSkin.visible_items(actor, s).map(func(i): return i.key) == ["status", "skill", "zhenqi", "race", "formation"])
	check("direct_single", XUiSkin.direct_item(XUiSkin.GROUPS[0], s) == "item" and XUiSkin.direct_item(XUiSkin.GROUPS[1], s) == "equip"
		and XUiSkin.direct_item(actor, s) == "" and XUiSkin.direct_item(XUiSkin.GROUPS[3], s) == "")
	var total := 0
	for g in XUiSkin.visible_groups(XUiSkin.GROUPS, s):
		total += (g.items as Array).size()
	check("items_17", total == 17, total)
	XTianqiPetHide.ENABLED = false   # 宠物放开：第 7 组自动出现，不用改布局
	keys = XUiSkin.visible_groups(XUiSkin.GROUPS, s).map(func(g): return g.key)
	check("groups_pets_back_7", keys.size() == 7 and keys[3] == "pets" and XUiSkin.direct_item(XUiSkin.GROUPS[3], s) == "pets", keys)
	XTianqiPetHide.ENABLED = true
	var xi := XState.new_game(3, 1, [8, 9, 10])
	check("groups_xiyou_7", XUiSkin.visible_groups(XUiSkin.GROUPS, xi).size() == 7)
	# 子项隐藏：一组只剩一项时直接进
	var custom := [{"key": "a", "name": "甲", "items": [{"key": "x", "name": "子一"}, {"key": "y", "name": "子二", "hidden": true}]},
		{"key": "b", "name": "乙", "hidden": true, "items": [{"key": "z", "name": "子三"}]}]
	var vg := XUiSkin.visible_groups(custom, s)
	check("custom_hidden", vg.size() == 1 and (vg[0].items as Array).size() == 1 and XUiSkin.direct_item(custom[0], s) == "x")


## ---- 组件 ----
func _components() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	# 直列表
	var l := XSkinList.new()
	l.size = Vector2(400, 46 * 4)
	host.add_child(l)
	var rows := []
	for i in range(10):
		rows.append({"text": "第%d项" % i, "icon": 100, "right": str(i)})
	l.set_items(rows)
	await frames()
	check("list_rows", l.visible_rows() == 4 and l.rows_total() == 10 and l.scrollable())
	check("list_up_wraps", l.move(0, -1) and l.index == 9 and l.top_row == 6, [l.index, l.top_row])
	check("list_down_wraps", l.move(0, 1) and l.index == 0 and l.top_row == 0)
	l.handle_input(_key("ui_down"))
	check("list_key_down", l.index == 1 and l.bar.target == l.cell_rect(1))
	var hits := []
	l.activated.connect(func(i): hits.append(i))
	l.handle_input(_key("ui_accept"))
	check("list_accept", hits == [1])
	rows[2]["disabled"] = true
	l.set_items(rows, true)
	l.select(2)
	l.handle_input(_key("ui_accept"))
	check("list_disabled_no_activate", hits == [1])
	l.row_height = 56
	check("list_row_height", l.cell_rect(0).size.y == 56 and l.visible_rows() == 3)
	var l2 := XSkinList.new()
	l2.columns = 2
	l2.row_height = 48
	l2.size = Vector2(400, 48 * 2)
	host.add_child(l2)
	l2.set_items(rows)
	await frames()
	check("list2_cells", l2.cell_rect(1).position.x > l2.cell_rect(0).end.x and l2.cell_rect(1).position.y == 0 and l2.rows_total() == 5)
	check("list2_right", l2.move(1, 0) and l2.index == 1 and not l2.move(1, 0))
	check("list2_down", l2.move(0, 1) and l2.index == 3 and l2.top_row == 0)
	check("list2_down_scroll", l2.move(0, 1) and l2.index == 5 and l2.top_row == 1)
	var empty := XSkinList.new()
	host.add_child(empty)
	empty.set_items([])
	check("list_empty", not empty.move(0, 1) and not empty.bar.visible)
	# 环
	var ring := XSkinRingNav.new()
	ring.size = Vector2(416, 416)
	host.add_child(ring)
	var items := XUiSkin.visible_groups().map(func(g): return {"key": g.key, "name": g.name, "icon": int(g.get("icon", 0))})
	ring.set_items(items)
	check("ring_first_top", is_equal_approx(ring.item_deg(0), -90.0) and ring.item_pos(0).distance_to(Vector2(208, 208 - ring.radius)) < 0.01)
	check("ring_even", is_equal_approx(ring.item_deg(1) - ring.item_deg(0), 360.0 / items.size()))
	ring.select(2)
	ring.advance(0.07)
	check("ring_arc_moving", ring.arc_deg > -90.0 and ring.arc_deg != ring.item_deg(2))
	ring.advance(0.2)
	check("ring_arc_settles", is_equal_approx(ring.arc_deg, ring.item_deg(2)))
	ring.select(items.size() - 1)   # 走近路：从 2 号逆时针转过去不绕远
	ring.advance(1.0)
	check("ring_short_way", absf(fposmod(ring.arc_deg, 360.0) - fposmod(ring.item_deg(items.size() - 1), 360.0)) < 0.01)
	var got := []
	ring.activated.connect(func(i): got.append(i))
	ring.handle_input(_key("ui_accept"))
	check("ring_activate", got == [items.size() - 1])
	check("ring_notches_7", XSkinRingNav.NOTCHES == 7 and is_equal_approx(ring.notch_deg(0), -90.0 + 360.0 / 14.0))
	# 页签
	var tabs := XSkinTabStrip.new()
	host.add_child(tabs)
	tabs.set_groups()
	check("tabs_count", tabs.groups.size() == XUiSkin.visible_groups().size())
	tabs.prev()
	check("tabs_wrap", tabs.index == tabs.groups.size() - 1)
	check("tabs_direct", tabs.select_key("items") and tabs.current_direct() == "item" and tabs.select_key("actor") and tabs.current_direct() == "")
	check("tabs_rects", tabs.tab_rect(1).position.x > tabs.tab_rect(0).end.x and tabs.total_width() > 0)
	# 弧形量条
	var g := XSkinArcGauge.new()
	g.size = Vector2(120, 120)
	host.add_child(g)
	g.set_value(100, 100, true)
	g.set_value(40)
	check("gauge_eases", is_equal_approx(g.shown, 1.0) and is_equal_approx(g.rate(), 0.4))
	for i in range(30):
		g.advance(1.0 / 60.0)
	check("gauge_catches", absf(g.shown - 0.4) < 0.01, g.shown)
	check("gauge_colors", XSkinArcGauge.color_of("hp") == XUiSkin.HP and XSkinArcGauge.color_of("mp") == XUiSkin.MP and XSkinArcGauge.color_of("boss") == XUiSkin.HP)
	# 角色条
	var ps := XSkinPartyStrip.new()
	ps.size = Vector2(360, 292)
	ps.title = "队伍"
	ps.selectable = true
	host.add_child(ps)
	var s := XState.current
	ps.set_members(s.members().slice(0, 4).map(func(a): return XSkinPartyStrip.from_actor(a)))
	var m0: Dictionary = ps.members[0]
	check("party_from_actor", ps.members.size() == 4 and str(m0.name) == s.members()[0].display_name() and float(m0.mhp) > 0 and m0.face is Texture2D, m0.keys())
	ps.select(2)
	check("party_select", ps.index == 2 and ps.bar.visible and ps.bar.target == ps.row_rect(2).grow(-2))
	ps.handle_input(_key("ui_down"))
	ps.handle_input(_key("ui_down"))
	check("party_wrap", ps.index == 0)
	# 详情牌
	var c := XSkinCard.new()
	c.size = Vector2(360, 300)
	host.add_child(c)
	c.setup({"title": "演示", "desc": "说明文字", "sections": [{"title": "分节", "lines": [{"left": "攻击力", "right": "+35"}]}],
		"buttons": [{"text": "确定", "primary": true}, {"text": "取消"}]})
	var pressed := []
	c.button_pressed.connect(func(i): pressed.append(i))
	c.handle_input(_key("ui_right"))
	c.handle_input(_key("ui_accept"))
	check("card_buttons", pressed == [0] and c.button_rect(1).position.x > c.button_rect(0).end.x and c.button_rect(0).end.y <= c.size.y - XUiSkin.PAD_LG + 0.01, pressed)
	# 按键提示
	var h := XSkinKeyHints.new()
	host.add_child(h)
	h.set_hints([["确定", "进入"], ["Q / E", "换组"]])
	h.place(Vector2(1600, 720))
	# 右边：安全边距 56，且让出右下角版本号（ui-skin-3b 把 1A 主菜单的让位收进 place）；版本号关掉时就是安全边距
	check("hints_place", is_equal_approx(h.position.x + h.total_width(), XSkinKeyHints.right_edge(Vector2(1600, 720))) and h.position.x + h.total_width() <= 1600 - 56
		and is_equal_approx(h.position.y, 720 - 10 - XSkinKeyHints.H))
	var keep_show := XVersionLabel.SHOW
	XVersionLabel.SHOW = false
	h.place(Vector2(1600, 720))
	check("hints_place_no_version", is_equal_approx(h.position.x + h.total_width(), 1600 - 56))
	XVersionLabel.SHOW = keep_show
	await frames()
	host.queue_free()
	await frames()


## ---- 横屏锚点 ----
func _layout() -> void:
	var a := XSkinLayout.compute(Vector2(1280, 720))
	check("layout_169_margin", a.margin == 24.0 and (a.left as Rect2).position == Vector2(24, 72) and is_equal_approx((a.right as Rect2).end.x, 1256.0), a)
	check("layout_169_center", (a.center as Rect2).position.x >= (a.left as Rect2).end.x + 16 and (a.center as Rect2).end.x <= (a.right as Rect2).position.x - 16
		and (a.center as Rect2).size.x == 424.0, (a.center as Rect2))
	check("layout_lines", is_equal_approx((a.left as Rect2).position.y, 72.0) and is_equal_approx((a.left as Rect2).end.y, 668.0) and is_equal_approx((a.center as Rect2).end.y, 668.0))
	var b := XSkinLayout.compute(Vector2(1600, 720))
	check("layout_209_margin", b.margin == 56.0 and (b.left as Rect2).position.x == 56.0 and is_equal_approx((b.right as Rect2).end.x, 1544.0)
		and (b.safe as Rect2) == Rect2(56, 0, 1488, 720), b)
	check("layout_209_center_grows", (b.center as Rect2).size.x == 680.0 and (b.center as Rect2).position.x == 488.0, b.center)
	var w := XSkinLayout.compute(Vector2(1720, 720))
	check("layout_center_cap", (w.center as Rect2).size.x == 720.0 and is_equal_approx((w.center as Rect2).get_center().x,
		((w.left as Rect2).end.x + (w.right as Rect2).position.x) / 2.0), w.center)
	# p1fix（小A审 P1-2）：比 16:9 窄的屏 KEEP（视口 1280×720、上下黑边），宽的 KEEP_HEIGHT；开关关掉回一律 KEEP_HEIGHT
	check("aspect_43_letterbox", XSkinLayout.aspect_for(Vector2(1024, 768)) == Window.CONTENT_SCALE_ASPECT_KEEP and XSkinLayout.view_for(Vector2(1024, 768)) == Vector2(1280, 720)
		and XSkinLayout.view_for(Vector2(2048, 1536)) == Vector2(1280, 720) and XSkinLayout.view_for(Vector2(2732, 2048)) == Vector2(1280, 720))
	check("aspect_169_keep", XSkinLayout.aspect_for(Vector2(1280, 720)) == Window.CONTENT_SCALE_ASPECT_KEEP and XSkinLayout.aspect_for(Vector2(1920, 1080)) == Window.CONTENT_SCALE_ASPECT_KEEP
		and XSkinLayout.view_for(Vector2(1920, 1080)) == Vector2(1280, 720))
	check("aspect_209_wide", XSkinLayout.aspect_for(Vector2(2400, 1080)) == Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT and XSkinLayout.view_for(Vector2(2400, 1080)) == Vector2(1600, 720))
	var c43 := XSkinLayout.compute(XSkinLayout.view_for(Vector2(1024, 768)))
	check("layout_43_not_squeezed", (c43.center as Rect2).size.x == 424.0 and (c43.right as Rect2).end.x <= 1256.0, c43.center)
	XSkinLayout.NARROW_LETTERBOX = false
	check("aspect_switch_off_old", XSkinLayout.aspect_for(Vector2(1024, 768)) == Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT)
	XSkinLayout.NARROW_LETTERBOX = true
	check("layout_margin_ramp", XSkinLayout.margin_for(1280) == 24.0 and XSkinLayout.margin_for(1312) == 40.0 and XSkinLayout.margin_for(1344) == 56.0
		and XSkinLayout.margin_for(2000) == 56.0 and XSkinLayout.margin_for(960) == 24.0)
	var node := XSkinLayout.new()
	node.view_override = Vector2(1600, 720)
	add_child(node)
	node.relayout()
	check("layout_node_blocks", node.left.position == Vector2(56, 72) and node.right.position.x + node.right.size.x == 1544.0 and node.center.size.x == 680.0)
	node.free()


## ---- 挂钩：菜单底、旧页面字体 ----
func _hooks() -> void:
	var s: XState = XState.current
	s.flags["tianqi"] = {"rules": 1}
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	XUI.menu_background(host)
	check("backdrop_on", host.get_node_or_null("SkinBackdrop") != null and host.get_child_count() == 1)
	check("old_font_kept", XUI.font() == GameFont.current())   # GLOBAL_FONT 第 0 期默认关
	XUiSkin.GLOBAL_FONT = true
	check("global_font_switch", XUI.font() == XUiSkin.font("body"))
	XUiSkin.GLOBAL_FONT = false
	XUiSkin.ENABLED = false
	var host2 := Control.new()
	add_child(host2)
	XUI.menu_background(host2)
	check("backdrop_off", host2.get_node_or_null("SkinBackdrop") == null and host2.get_child_count() >= 1)
	XUiSkin.ENABLED = true
	# 宽屏拉伸方式：页面进树时 KEEP_HEIGHT，离开还原
	var root := get_tree().root
	var before := root.content_scale_aspect
	var page := Control.new()
	add_child(page)
	XSkinLayout.window_override = Vector2(2400, 1080)
	XSkinLayout.request_wide(page)
	check("wide_on", root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT and XSkinLayout.wide_active())
	# 窗口换成 4:3（平板）：跟着换 KEEP，上下留边
	XSkinLayout.window_override = Vector2(1024, 768)
	root.size_changed.emit()
	check("wide_43_follows_window", root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP)
	page.queue_free()
	await frames()
	XSkinLayout.window_override = Vector2.ZERO
	check("wide_restored", root.content_scale_aspect == before and not XSkinLayout.wide_active())
	XUiSkin.ENABLED = false
	var page2 := Control.new()
	add_child(page2)
	XSkinLayout.request_wide(page2)
	check("wide_skin_off_noop", root.content_scale_aspect == before and not XSkinLayout.wide_active())
	XUiSkin.ENABLED = true
	page2.queue_free()
	host.queue_free()
	host2.queue_free()
	await frames()


## ---- 字体 ----
func _fonts() -> void:
	var ok := true
	for k in ["title", "body", "num"]:
		ok = ok and XUiSkin.has_font(k) and XUiSkin.font(k) is FontFile and XUiSkin.font(k) != GameFont.current()
	check("fonts_load", ok)
	var body := XUiSkin.font("body") as FontFile
	var title := XUiSkin.font("title") as FontFile
	var miss := []
	for ch in "菜单物品装备角色工坊图鉴系统精魂印屑确定取消整队宠物已装备攻击力":
		if not body.has_char(ch.unicode_at(0)):
			miss.append(ch)
	check("body_chars", miss.is_empty(), miss)
	check("title_chars", title.has_char("菜".unicode_at(0)) and title.has_char("魂".unicode_at(0)))
	var raw_num := load(XUiSkin.FONT_DIR + XUiSkin.FONT_FILES.num) as FontFile   # 原资源（不带落回字体）
	check("num_chars", raw_num.has_char("8".unicode_at(0)) and raw_num.has_char("%".unicode_at(0)) and not raw_num.has_char("菜".unicode_at(0)))
	check("fallback_to_game_font", body.fallbacks.has(GameFont.current()))


## ---- 陈列页（加 --out 时截图 16:9、20:9）----
func _showcase() -> void:
	var s: XState = XState.current
	s.flags["tianqi"] = {"rules": 1}
	var page := XSkinShowcase.new()
	add_child(page)
	await frames(3)
	check("showcase_built", page.ring.items.size() == 6 and page.tabs.groups.size() == 6 and page.party.members.size() == 4 and page.list2.scrollable())
	check("showcase_blocks", page.layout.left.position.x == XSkinLayout.margin_for(page.layout.view_size().x) and page.layout.center.size.x <= 720.0)
	for i in range(40):
		await get_tree().process_frame
	await shot("ui_skin_showcase_16x9")
	if out_dir != "" and DisplayServer.get_name() != "headless":
		var win := get_window()
		var old := win.size
		win.size = Vector2i(1600, 720)
		await frames(10)
		check("showcase_wide_view", absf(page.layout.view_size().x / page.layout.view_size().y - 20.0 / 9.0) < 0.01, page.layout.view_size())
		check("showcase_wide_margin", page.layout.left.position.x == 56.0, page.layout.left.position)
		await shot("ui_skin_showcase_20x9")
		win.size = old
		await frames(5)
	page.queue_free()
	await frames()
	# 旧页面强开新皮肤（不改布局，只换黑面板＋细线、红乙光标、黑底）
	if out_dir != "" and DisplayServer.get_name() != "headless":
		var m := XMenu.new()
		add_child(m)
		await frames(20)
		await shot("ui_skin_old_menu_skinned")
		XUiSkin.ENABLED = false
		m.queue_free()
		await frames(2)
		var m2 := XMenu.new()
		add_child(m2)
		await frames(20)
		await shot("ui_skin_old_menu_off")
		XUiSkin.ENABLED = true
		m2.queue_free()
		await frames(2)


## 选中条三态（p1fix）：按钮的悬停／按下／焦点各是各的样式，按下字下沉 1px；按住时焦点换成按下态（Godot 把 focus 叠在上面画）；
## 列表点一下按下态停 SEL2_PRESS_TIME 秒；SELECT_V2 关时回到三态同一个（v0.7）
func _select_pixels() -> void:
	var b := Button.new()
	b.text = "确定"
	XSkinButton.apply(b)
	var hv := b.get_theme_stylebox("hover") as XSkinSelectStyle
	var pr := b.get_theme_stylebox("pressed") as XSkinSelectStyle
	var fc := b.get_theme_stylebox("focus") as XSkinSelectStyle
	var nm := b.get_theme_stylebox("normal")
	check("button_three_states", hv != null and pr != null and fc != null and hv.state == XUiSkin.SelState.HOVER
		and pr.state == XUiSkin.SelState.PRESSED and fc.state == XUiSkin.SelState.FOCUS and hv != fc and pr != fc)
	check("button_pressed_sinks", pr != null and pr.content_margin_top == nm.content_margin_top + 1 and pr.content_margin_bottom == nm.content_margin_bottom - 1)
	b.button_down.emit()
	var held := b.get_theme_stylebox("focus")
	b.button_up.emit()
	check("button_focus_swaps_while_held", held == pr and b.get_theme_stylebox("focus") == fc)
	b.free()
	XUiSkin.SELECT_V2 = false
	var b2 := Button.new()
	XSkinButton.apply(b2)
	check("button_v07_one_style", b2.get_theme_stylebox("hover") == b2.get_theme_stylebox("pressed") and b2.get_theme_stylebox("hover") == b2.get_theme_stylebox("focus")
		and not b2.has_meta("skin_press_wired"))
	b2.free()
	XUiSkin.SELECT_V2 = true
	var t := XUiSkin.theme()
	check("theme_three_states", (t.get_stylebox("hover", "Button") as XSkinSelectStyle).state == XUiSkin.SelState.HOVER
		and (t.get_stylebox("pressed", "Button") as XSkinSelectStyle).state == XUiSkin.SelState.PRESSED
		and (t.get_stylebox("focus", "Button") as XSkinSelectStyle).state == XUiSkin.SelState.FOCUS)
	var bar := XSkinSelectBar.new()
	XUiSkin._clock_ms = 100000
	bar.press()
	var on_now := bar.pressed_now()
	XUiSkin._clock_ms = 100000 + int(XUiSkin.SEL2_PRESS_TIME * 1000) + 1
	bar.advance(0.016)
	check("bar_press_flash", on_now and not bar.pressed_now() and bar.presses == 1)
	XUiSkin._clock_ms = -1
	bar.free()
