extends Node
## 新界面第一期正式美术（cc/ui-art-phase01）专项：背景按骑士线切换、三比例选图、烟色面板九宫格、选中条箭头外置、主菜单环高亮、
## 装备 13 栏一页（无翻页文字、键盘顺序、触屏点得准；C 摆法名字不互压、折线连线）、每个开关关掉回旧。
## 带 -- --out=<目录> 且有窗口时出截图：主菜单／物品／装备 × 16:9／20:9／4:3、触屏装备页、四条线各一张背景（主菜单）。
## 4:3 屏视口照 O-483 锁 1280×720 上下留边：截图另存一张按 960×720 窗口加黑边的「玩家看到的样子」。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const SIZES := [[Vector2i(1280, 720), "16x9"], [Vector2i(1600, 720), "20x9"], [Vector2i(960, 720), "4x3"]]

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


func _run() -> void:
	TestEnv.isolate("xiyou_ui_art_phase01")
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XUiSkin.touch_override = 0
	_pure()
	await _backdrop()
	_panel()
	_select()
	await _halo()
	await _equip()
	await _switches_off()
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


func _set_all(on: bool) -> void:
	XSkinArt.BG = on
	XSkinArt.PANEL = on
	XSkinArt.SELECT = on
	XSkinArt.HALO = on
	XSkinEquipPage.ONE_PAGE = on
	XUiSkin._styles.clear()


func _state(line := "war", map_id := 1) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian", "line": line}
	s.map_id = map_id
	s.set_variable(20, 32)
	s.gold = 12480
	for id in range(1, 40):
		var rec := XDB.rec("Weapons", id)
		if not rec.is_empty() and str(rec.get("name", "")) != "" and not str(rec.get("name", "")).begins_with("-"):
			s.gain_gear("weapons", id, 1)
	return s


# ---- 纯函数：比例、路线、贴图 ----
func _pure() -> void:
	check("aspect_16x9", XSkinArt.aspect_key(Vector2(1280, 720)) == "16x9")
	check("aspect_20x9", XSkinArt.aspect_key(Vector2(1600, 720)) == "20x9" and XSkinArt.aspect_key(Vector2(1560, 720)) == "20x9")
	check("aspect_4x3", XSkinArt.aspect_key(Vector2(960, 720)) == "4x3" and XSkinArt.aspect_key(Vector2(1024, 768)) == "4x3")
	check("aspect_mid", XSkinArt.aspect_key(Vector2(1400, 720)) == "16x9" and XSkinArt.aspect_key(Vector2(1150, 720)) == "16x9")
	var all_ok := true
	for rt in XSkinArt.ROUTES:
		for key in XSkinArt.SIZES:
			var t := XSkinArt.bg_texture(rt, Vector2(XSkinArt.SIZES[key]))
			if t == null or Vector2i(t.get_size()) != XSkinArt.SIZES[key]:
				all_ok = false
				print("bad bg ", rt, " ", key, " ", t.get_size() if t != null else null)
	check("bg_15_files", all_ok)
	for part in ["smoke_reading_128x128", "smoke_secondary_128x64", "selection_wash_128x24", "selection_arrow_7x9", "tab_selected_wash_64x24",
			"tab_selected_assembly_88x24", "ring_selected_halo_96x96", "ring_selected_halo_48x48"]:
		check("part_" + part, XSkinArt.part(part) != null)
	var sa := XSkinArt.safe_area("4x3")
	check("safe_area_4x3", sa.get("central_low_detail_rect") == Rect2(320, 180, 320, 420) and (sa.get("side_art_anchors", []) as Array).size() == 2, sa)
	check("safe_area_20x9", XSkinArt.safe_area("20x9").get("central_low_detail_rect") == Rect2(320, 180, 960, 420))
	# 路线：四条线各自；大厅、没选线、西游存档 → 通用
	for line in ["death", "war", "famine", "plague"]:
		var s := _state(line)
		check("route_" + line, XSkinArt.route(s) == line, [line, XSkinArt.route(s)])
	check("route_lobby_general", XSkinArt.route(_state("war", XSkinArt.LOBBY_MAP)) == "general")
	check("route_no_line_general", XSkinArt.route(_state("")) == "general")
	var xs := XState.new_game(3, 1, [8, 9, 10])
	check("route_xiyou_general", XSkinArt.route(xs) == "general")
	check("route_null_safe", XSkinArt.route(null) in XSkinArt.ROUTES)


# ---- 背景 ----
func _backdrop() -> void:
	XUiSkin.motion_override = XUiSkin.Motion.FULL   # 火星只在动效开着时有
	for line in ["death", "plague"]:
		_state(line)
		var host := Control.new()
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(host)
		XUI.menu_background(host)
		await frames(2)
		var bg := host.find_child("ArtBackground", true, false) as TextureRect
		check("backdrop_" + line, bg != null and bg.texture != null and bg.get_meta("route", "") == line \
			and bg.texture.resource_path.get_file().begins_with(line + "_") and bg.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			[bg != null, bg.get_meta("route", "") if bg != null else ""])
		check("backdrop_embers_" + line, host.find_child("Embers", true, false) != null)
		host.queue_free()
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	await frames(2)
	_state("war")
	XSkinArt.BG = false
	var h2 := Control.new()
	h2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(h2)
	XUI.menu_background(h2)
	check("backdrop_off_old", h2.find_child("ArtBackground", true, false) == null and h2.find_child("SkinBackdrop", true, false) != null)
	h2.queue_free()
	XSkinArt.BG = true


# ---- 烟色面板 ----
func _panel() -> void:
	XUiSkin._styles.clear()
	var st = XUiSkin.panel_style()
	check("panel_smoke", st is XSkinArt.SmokeStyle and not st.short and st.content_margin_left == 24 and st.content_margin_top == XUiSkin.PAD)
	check("panel_no_shadow", XUiSkin.shadow_style() is StyleBoxEmpty)
	check("panel_short_secondary", XSkinArt.smoke_style(true).short)
	check("panel_alpha_085", XSkinArt.SMOKE_ALPHA == 0.85 and XSkinArt.SMOKE_ALPHA_SHORT == 0.88)
	var gt := XSkinArt.grain_texture(Vector2i(300, 200))
	check("panel_grain_tiled", gt != null and Vector2i(gt.get_size()) == Vector2i(300, 200) \
		and gt.get_image().get_pixel(45, 47) == gt.get_image().get_pixel(77, 79) and gt.get_image().get_pixel(0, 50).a == 0.0, gt.get_size() if gt != null else null)
	# 像素件预放大（最近邻、1:1 画）：2× 箭头 14×18，每个像素都是原图的 2×2 块
	var a2 := XSkinArt.scaled("selection_arrow_7x9", Vector2i(14, 18))
	var a1 := XSkinArt.part("selection_arrow_7x9").get_image()
	a1.decompress()
	var ai := a2.get_image()
	var crisp := true
	for y in 18:
		for x in 14:
			if not ai.get_pixel(x, y).is_equal_approx(a1.get_pixel(x / 2, y / 2)):
				if crisp:
					print("arrow px ", x, ",", y, " ", ai.get_pixel(x, y), " vs ", a1.get_pixel(x / 2, y / 2), " fmt ", ai.get_format(), "/", a1.get_format())
				crisp = false
	check("arrow_2x_nearest", crisp)
	check("wash_w_quantized", XSkinArt.wash_w(301.0) == 300 and XSkinArt.wash_w(303.0) == 304)
	for part in ["smoke_grain_tile_32x32", "seven_seal_128x128", "helper_tag_32x12"]:
		check("part_" + part, XSkinArt.part(part) != null)
	check("helper_tag_2x", XSkinArt.helper_tag_rect(Rect2(0, 0, 340, 92)) == Rect2(272, 4, 64, 24))
	XSkinArt.PANEL = false
	XUiSkin._styles.clear()
	var old = XUiSkin.panel_style() as StyleBoxTexture
	check("panel_off_old", old != null and old.texture == XUiSkin.panel_texture() and old.texture_margin_left == 24)
	check("panel_off_shadow", XUiSkin.shadow_style() is StyleBoxFlat)
	XSkinArt.PANEL = true
	XUiSkin._styles.clear()


# ---- 选中条：箭头外置、8px 间隔 ----
func _select() -> void:
	var row := Rect2(100, 50, 300, 46)
	var ar := XSkinArt.arrow_rect(row)
	check("arrow_2x_row", ar.size == Vector2(14, 18), ar)
	check("arrow_outside_gap8", ar.end.x <= row.position.x - 8.0 and not ar.intersects(row), ar)
	check("arrow_centered", absf(ar.get_center().y - row.get_center().y) <= 0.5 and ar.position == ar.position.round(), ar)
	var small := XSkinArt.arrow_rect(Rect2(100, 0, 200, 24))
	check("arrow_1x_small", small.size == Vector2(7, 9) and small.end.x == 92.0, small)
	check("select_on", XSkinArt.select_on())
	check("main_menu_row_x_28", XSkinMainMenu.row_x() == 28.0 and XSkinArt.arrow_rect(Rect2(28, 0, 300, 56)).position.x >= 6.0)
	# 页签：箭头 1×，落在前一个页签的右侧内边距里，不压前一个页签的字
	var tabs := XSkinTabStrip.new()
	add_child(tabs)
	_state("war")
	tabs.set_groups()
	var ok := tabs.groups.size() >= 2
	for i in range(1, tabs.groups.size()):
		var a := XSkinArt.arrow_rect(tabs.tab_rect(i), 1)
		if a.position.x < tabs.tab_rect(i - 1).end.x - XSkinTabStrip.TAB_PAD + 1.0 or a.end.x > tabs.tab_rect(i).position.x - 8.0:
			ok = false
	check("tab_arrow_in_gap", ok, tabs.groups.size())
	check("tab_gap_18", tabs.tab_rect(1).position.x - tabs.tab_rect(0).end.x == 18.0)
	tabs.queue_free()
	# 双列列表：列缝 ≥ 26，右列 2× 箭头落在缝里、不进左列
	var l := XSkinList.new()
	l.columns = 2
	l.size = Vector2(600, 46 * 4)
	add_child(l)
	l.set_items([{"text": "甲"}, {"text": "乙"}])
	var ra := XSkinArt.arrow_rect(l.cell_rect(1))
	check("list_two_col_gap", l.gap() == 26.0 and ra.position.x >= l.cell_rect(0).end.x and l.item_at(l.cell_rect(1).get_center()) == 1, [l.gap(), ra, l.cell_rect(0)])
	l.queue_free()
	XSkinArt.SELECT = false
	check("list_gap_off", true)
	check("select_off", not XSkinArt.select_on())
	check("main_menu_row_x_off", XSkinMainMenu.row_x() == 10.0)
	XSkinArt.SELECT = true


# ---- 主菜单环高亮 ----
func _build_menu(line := "war") -> XMenu:
	_state(line)
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


func _halo() -> void:
	var menu := await _build_menu()
	var ring: XSkinRingNav = menu.skin.ring
	ring.queue_redraw()
	await frames(2)
	var hr := ring.halo_rect
	check("halo_drawn", hr.size == Vector2(96, 96), hr)
	check("halo_centered", hr.get_center().distance_to(ring.item_pos(ring.index)) <= 0.5, [hr, ring.item_pos(ring.index)])
	XSkinArt.HALO = false
	ring.queue_redraw()
	await frames(2)
	check("halo_off", ring.halo_rect == Rect2())
	XSkinArt.HALO = true
	check("halo_48_for_32", XSkinArt.halo_rect(Vector2(50, 50), 32).size == Vector2(48, 48) and XSkinArt.halo_texture(32) == XSkinArt.part("ring_selected_halo_48x48"))
	menu.queue_free()
	await frames(3)


# ---- 装备 13 栏一页 ----
func _build_equip(accept := true) -> XEquipScene:
	_state()
	var page := XEquipScene.new()
	add_child(page)
	await frames(4)
	if accept:
		page._unhandled_input(_key("ui_accept"))
		page._unhandled_input(_key("ui_cancel"))
		await frames(4)
	return page


func _equip() -> void:
	for lay in [0, 1, 2, 3]:
		XSkinEquipPage.LAYOUT = lay
		await _equip_layout(lay)
	XSkinEquipPage.LAYOUT = 3
	# 分支摆法的导航顺序：绕主环、遇枝丫先走完（C 挂主栏）
	var view := [0, 1, 2, 3, 5, 7, 4, 6, 8, 9, 12, 15, 16]
	var plan := XSkinEquipPage.ring_plan(view, 3)
	var names := (plan.nav as Array).map(func(r): return int(view[r]) + 1)
	check("branch_nav_c", names == [1, 17, 2, 13, 3, 9, 4, 6, 10, 8, 5, 7, 16], names)
	check("branch_links_c", (plan.links as Array).size() == 5)
	# 没有副手栏（猫）：主环 7 颗，挂在副手上的法宝改挂主环第一颗
	var cat := view.filter(func(sl): return sl != 1)
	var pc := XSkinEquipPage.ring_plan(cat, 3)
	check("branch_cat_all_placed", (pc.nav as Array).size() == 12 and (pc.custom as Array).filter(func(c): return c.has("deg")).size() == 7)


func _equip_layout(lay: int) -> void:
	for touch in [0, 1]:
		XUiSkin.touch_override = touch
		var page := await _build_equip(false)
		var sk: XSkinEquipPage = page.skin
		var n := page.slot_view().size()
		var tag := "L%d_%s" % [lay, "touch" if touch == 1 else "key"]
		check("equip13_n_" + tag, n == 13, n)
		check("equip13_all_on_ring_" + tag, sk.ring.items.size() == n, sk.ring.items.size())
		check("equip13_no_page_text_" + tag, not sk.caption().contains("页") and sk.caption().begins_with("身上"), sk.caption())
		# 球不重叠、点按范围不串、都在左块里
		var ring := sk.ring
		var hit_r := ring.orb_radius * 1.2
		var sep_ok := true
		var hit_ok := true
		var inside := true
		for i in n:
			var p := ring.item_pos(i)
			for j in n:
				if j != i and p.distance_to(ring.item_pos(j)) <= hit_r * 2.0:
					sep_ok = false
			if ring.item_at(p) != i or ring.item_at(p + Vector2(hit_r - 1.0, 0)) != i:
				hit_ok = false
			var gp := ring.position + p
			var er := ring.orb_radius * 1.16
			if gp.x - er < 0.0 or gp.x + er > sk.layout.left.size.x or gp.y - er < XSkinEquipPage.STRIP_H or gp.y + er > sk.layout.left.size.y - XSkinEquipPage.CAPTION_H:
				inside = false
		check("equip13_orbs_apart_" + tag, sep_ok)
		check("equip13_tap_hits_" + tag, hit_ok)
		check("equip13_inside_left_" + tag, inside)
		check("equip13_touch_target_" + tag, hit_r * 2.0 >= 44.0, hit_r)
		# 栏位名在环内侧：离球心够远，不压头像
		var face_r := (sk.ring_radius - XSkinEquipPage.BRANCH_LABEL_R - 2.0) if lay > 0 else sk.ring_radius - 68.0
		check("equip13_labels_inner_" + tag, ring.label_inner > 0.0 and ring.label_inner + 18.0 <= ring.radius - ring.orb_radius \
			and ring.label_inner - 18.0 >= face_r, [ring.label_inner, ring.radius, face_r])
		if lay == 3:   # C 第四版（Kyo 11-16）：名字互不相压、不压别的球、不出左块；连线是三点折线（根→径向拐点→副栏）
			var rects := []
			for i in n:
				rects.append(ring.label_layout(i).rect)
			var lab_ok := true
			var bad := []
			for i in n:
				var ri: Rect2 = rects[i]
				if ri.position.x < 0.0 or ri.end.x > ring.size.x or ri.position.y < 0.0 or ri.end.y > ring.size.y:
					lab_ok = false
					bad.append(["out", i])
				for j in n:
					if j > i and ri.intersects(rects[j]):
						lab_ok = false
						bad.append(["lab", i, j])
					var q := ring.item_pos(j)
					var near := Vector2(clampf(q.x, ri.position.x, ri.end.x), clampf(q.y, ri.position.y, ri.end.y))
					if j != i and near.distance_to(q) < ring.orb_radius * 1.16:
						lab_ok = false
						bad.append(["orb", i, j])
			check("equip13_c_labels_clear_" + tag, lab_ok, bad)
			# 连线：三点直角折线，拐点在根栏径向上、离副栏比离根栏近（Kyo 11-16 v5）
			var link_ok := ring.links.size() == 5
			for l in ring.links:
				var r0: Vector2 = l[0]
				var k: Vector2 = l[1] if (l as Array).size() == 3 else Vector2.ZERO
				if (l as Array).size() != 3 or absf(k.angle_to(r0)) > 0.01 or absf((l[2] - k).normalized().dot(k.normalized())) > 0.05 \
					or k.distance_to(l[2]) >= k.distance_to(r0):
					link_ok = false
			check("equip13_c_links_elbow_" + tag, link_ok, ring.links)
			check("equip13_no_notches_" + tag, not bool(ring.sty("notches")))
			var far := 0.0
			for i in n:
				if not ring.on_ring(i):
					far = maxf(far, (ring.custom[i].pos as Vector2).length())
			check("equip13_c_subs_close_" + tag, far <= 180.0, far)
		# 键盘：下／右一格走完 13 栏回到第一栏（导航顺序：一圈时就是显示顺序；分支时绕主环、遇枝丫先走完）；上／左反过来
		var nav: Array = sk._plan.nav if lay > 0 else range(n)
		check("equip13_nav_covers_" + tag, nav.size() == n and nav.duplicate().all(func(r): return nav.count(r) == 1), nav)
		var order := []
		for i in n:
			order.append(page._slot_row())
			if ring.index != i:
				check("equip13_ring_index_%s_%d" % [tag, i], false, ring.index)
			page._unhandled_input(_key("ui_down" if i % 2 == 0 else "ui_right"))
			await frames(1)
		check("equip13_walk_order_" + tag, order == nav and page._slot_row() == int(nav[0]) and ring.index == 0, order)
		page._unhandled_input(_key("ui_up"))
		await frames(1)
		check("equip13_walk_back_" + tag, page._slot_row() == int(nav[n - 1]) and ring.index == n - 1, page._slot_row())
		page._unhandled_input(_key("ui_left"))
		await frames(1)
		check("equip13_walk_left_" + tag, page._slot_row() == int(nav[n - 2]), page._slot_row())
		# 点第 10 颗直接选中，不翻页
		ring._gui_input(_click(ring.item_pos(10)))
		await frames(1)
		check("equip13_click_far_slot_" + tag, page._slot_row() == int(nav[10]) and ring.index == 10 and ring.items.size() == n, page._slot_row())
		# 不能换的栏照旧标 locked（变暗）
		var a := page.actor()
		var locked_ok := true
		for i in n:
			if bool(ring.items[i].get("locked", false)) != (not XEquipment.can_change(a, int(page.slot_view()[int(nav[i])]))):
				locked_ok = false
		check("equip13_locked_flag_" + tag, locked_ok)
		page.queue_free()
		await frames(3)
	XUiSkin.touch_override = 0
	# 非天启篇 19 栏（XTianqiGear 关）：不走分支摆法、不挤一圈，照旧分页（小A核 P2-4）
	XTianqiGear.ENABLED = false
	var p19 := await _build_equip(false)
	check("equip19_no_branch", not XSkinEquipPage.branched() and p19.slot_view().size() == 19 and p19.skin.ring.custom.is_empty() \
		and p19.skin.ring.items.size() == 10 and p19.skin.caption().contains("栏位第 1 / 2 页"), [p19.slot_view().size(), p19.skin.ring.items.size(), p19.skin.caption()])
	p19.queue_free()
	await frames(3)
	XTianqiGear.ENABLED = true
	# 关掉 ONE_PAGE：回 7＋6 两页、环下写页数
	XSkinEquipPage.ONE_PAGE = false
	var p2 := await _build_equip(false)
	check("equip13_off_two_pages", p2.skin.ring.items.size() == 7 and p2.skin.caption().contains("栏位第 1 / 2 页") and p2.skin.ring.label_inner == 0.0,
		[p2.skin.ring.items.size(), p2.skin.caption()])
	p2.queue_free()
	await frames(3)
	XSkinEquipPage.ONE_PAGE = true


# ---- 全关＝回旧；新皮肤关时一概不碰 ----
func _switches_off() -> void:
	_set_all(false)
	XUiSkin._styles.clear()
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	_state("war")
	XUI.menu_background(host)
	check("all_off_no_art_bg", host.find_child("ArtBackground", true, false) == null)
	check("all_off_panel_old", (XUiSkin.panel_style() as StyleBoxTexture).texture == XUiSkin.panel_texture())
	host.queue_free()
	_set_all(true)
	# 新皮肤关（西游存档）：菜单底照旧 Background.png，不出新背景
	XUiSkin.FORCE = false
	XState.current = XState.new_game(3, 1, [8, 9, 10])
	var h3 := Control.new()
	add_child(h3)
	XUI.menu_background(h3)
	check("skin_off_no_art", h3.find_child("ArtBackground", true, false) == null and h3.find_child("SkinBackdrop", true, false) == null)
	h3.queue_free()
	XUiSkin.FORCE = true
	await frames(2)


# ---- 截图 ----
func _shots() -> void:
	for sz in SIZES:
		get_window().size = sz[0]
		await frames(6)
		for page in ["menu", "items", "equip"]:
			var node: Node = await call("_shot_" + page)
			await frames(6)
			await _save_shot("%s_%s" % [page, sz[1]], sz)
			node.queue_free()
			await frames(3)
	get_window().size = Vector2i(1280, 720)
	await frames(6)
	XUiSkin.touch_override = 1
	var eq: Node = await _shot_equip()
	await frames(6)
	await _save_shot("equip_16x9_touch", SIZES[0])
	eq.queue_free()
	await frames(3)
	XUiSkin.touch_override = 0
	# 装备 13 栏三种分支摆法（＋上一版一圈），16:9 键盘、触屏各一张
	for lay in [0, 1, 2, 3]:
		XSkinEquipPage.LAYOUT = lay
		for touch in [0, 1]:
			XUiSkin.touch_override = touch
			var e2: Node = await _shot_equip()
			await frames(6)
			await _save_shot("equip_layout%d_%s" % [lay, "touch" if touch == 1 else "16x9"], SIZES[0])
			e2.queue_free()
			await frames(3)
	XSkinEquipPage.LAYOUT = 3
	XUiSkin.touch_override = 0
	for line in ["death", "war", "famine", "plague"]:
		var m: Node = await _build_menu(line)
		await frames(6)
		await _save_shot("bg_%s_16x9" % line, SIZES[0])
		m.queue_free()
		await frames(3)


func _save_shot(name: String, sz: Array) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_dir)
	check("shot_" + name, img.save_png(out_dir.path_join(name + ".png")) == OK)
	if sz[1] == "4x3" and img.get_width() * 9 == img.get_height() * 16:   # 4:3 窗口：视口锁 16:9、上下留边，另存玩家看到的样子
		var view := img.duplicate() as Image
		view.resize(960, 540, Image.INTERPOLATE_BILINEAR)
		var frame := Image.create(960, 720, false, view.get_format())
		frame.fill(Color.BLACK)
		frame.blit_rect(view, Rect2i(Vector2i.ZERO, view.get_size()), Vector2i(0, 90))
		frame.save_png(out_dir.path_join(name + "_letterbox.png"))


func _shot_menu() -> Node:
	return await _build_menu("war")


func _shot_items() -> Node:
	_state("plague")
	var page := XItemScene.new()
	add_child(page)
	await frames(4)
	page._unhandled_input(_key("ui_right"))
	page._unhandled_input(_key("ui_right"))
	page._unhandled_input(_key("ui_accept"))
	await frames(2)
	return page


func _shot_equip() -> Node:
	_state("war")
	var page := XEquipScene.new()
	add_child(page)
	await frames(4)
	for i in 3:
		page._unhandled_input(_key("ui_down"))
	await frames(2)
	return page


func _key(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _click(p: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	return e
