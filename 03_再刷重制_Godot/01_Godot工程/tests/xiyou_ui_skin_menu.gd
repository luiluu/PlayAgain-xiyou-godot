extends Node
## 新界面第 1A 批：主菜单（XSkinMainMenu，盘点清册 #21）。
## - 开关：天启篇存档（XUiSkin.on()）走新布局、旧三个窗口不建；ENABLED＝false 时回旧菜单（与 main 逐像素一致另由 皮肤关闭对照.py 验）；
## - 组：读 XUiSkin.GROUPS（天启篇 6 组、环 6 球）；子项都有一句话说明、都有旧菜单符号；异化隐藏时工坊少一项；
## - 列表：没选中的组收成一行、选中的组展开（组名＋子项 56）、只剩一项的组不展开；总高不超中块；上下跨组、到头循环、按住不循环；
##   左右／Q／E 换组、环跟着转；
## - 直接进：物品组确定直接进物品页；装备、技能、状态先到队伍条选人，取消回列表、确定进页；不可用的（反馈）蜂鸣不进；
## - 本局条：「第 N 层 · 难度 · 线」、七印进度（首通 2、揭开 1、没揭开 0）、货币（精魂；能进祭坛另有印屑）；
## - 按键提示不压右下角版本号；进子页时还原窗口拉伸方式、回来再铺满；
## 加 -- --out=<目录> 且有窗口时，存 16:9（1280×720）与 20:9（1600×720）两张截图。
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


func _press(m: XSkinMainMenu, action: String, echo := false) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	m._unhandled_input(e)
	if echo:
		pass


func _key(m: XSkinMainMenu, code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	m._unhandled_input(e)


func _state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.flags["tianqi"] = {"rules": 1, "difficulty": "jianxian", "line": "war"}
	s.set_variable(20, 32)
	s.gold = 12480
	return s


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_menu")
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	var s := _state()
	XState.current = s
	_data(s)
	XState.current = s   # XState.new_game 会把 current 换成新建的档
	# 旧一级操作、旧队伍条的断言照旧跑（开关关着），两级＋助力位卡另测
	XSkinMainMenu.TWO_LEVEL = false
	XSkinMainMenu.HELPER_CARD = false
	await _menu(s)
	XSkinMainMenu.TWO_LEVEL = true
	XSkinMainMenu.HELPER_CARD = true
	XState.current = s
	await _two_level(s)
	await _helper_card(s)
	await _off(s)
	if out_dir != "" and DisplayServer.get_name() != "headless":
		await _shots(s)
	XUiSkin.motion_override = -1
	XState.current = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## ---- 组配置、本局条数据 ----
func _data(s: XState) -> void:
	var syms := XMenu.COMMANDS.map(func(c): return c[1])
	var bad := []
	for g in XUiSkin.GROUPS:
		for it in g.items:
			if str(it.get("desc", "")) == "" or not syms.has(str(it.get("cmd", ""))):
				bad.append(it.key)
	check("groups_desc_cmd", bad.is_empty(), bad)
	# 18 个旧指令都有新入口（宠物组现在藏着）
	var cmds := []
	for g in XUiSkin.GROUPS:
		for it in g.items:
			cmds.append(str(it.cmd))
	cmds.sort()
	syms.sort()
	check("groups_cover_old_commands", cmds == syms, cmds)
	XAlienBattle.HIDDEN_V058 = true
	var ws: Dictionary = XUiSkin.GROUPS.filter(func(g): return g.key == "workshop")[0]
	check("alien_hidden", XUiSkin.visible_items(ws, s).map(func(i): return i.key) == ["crafting", "orb_shop"])
	XAlienBattle.HIDDEN_V058 = false
	check("alien_shown", XUiSkin.visible_items(ws, s).size() == 3)
	check("run_text", XSkinMainMenu.run_text(s) == "第 32 层 · 艰险 · 战争线", XSkinMainMenu.run_text(s))
	var xi := XState.new_game(3, 1, [8, 9, 10])
	xi.set_variable(20, 5)
	check("run_text_xiyou", XSkinMainMenu.run_text(xi) == "第 5 层", XSkinMainMenu.run_text(xi))
	check("seals_xiyou_none", XSkinMainMenu.seal_states(xi).is_empty() and XSkinMainMenu.currencies(xi).size() == 1)
	XTianqiQiyin.progress(s).drop["first_clear"] = {"bai": true}
	XTianqiQiyin.progress(s)["shards"] = 126
	var st := XSkinMainMenu.seal_states(s)
	check("seal_states", st == [2, 1, 0, 0, 0, 0, 0], st)
	check("seals_cleared", XSkinMainMenu.seals_cleared(st) == 1)
	check("currencies", XSkinMainMenu.currencies(s) == [["精魂", "12,480"], ["印屑", "126"]], XSkinMainMenu.currencies(s))
	# 按键提示让出右下角版本号
	var vw := GameFont.current().get_string_size(XVersionLabel.version_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, XVersionLabel.FONT_SIZE).x
	for view in [Vector2(1280, 720), Vector2(1600, 720)]:
		var right := XSkinMainMenu.hint_right(view)
		check("hint_clear_of_version_%d" % int(view.x), right <= view.x - XVersionLabel.MARGIN.x - vw - 16.0 + 0.01 and right <= view.x - XSkinLayout.margin_for(view.x), [right, vw])


## ---- 新主菜单 ----
func _menu(s: XState) -> void:
	var root := get_tree().root
	var aspect := root.content_scale_aspect
	var menu := XMenu.new()
	add_child(menu)
	await frames(3)
	var m := menu.skin
	check("skin_built", m != null and menu.cmd_win == null and menu.status_win == null)
	if m == null:
		menu.queue_free()
		return
	check("ring_6", m.ring.items.size() == 6 and m.groups.size() == 6, m.ring.items.map(func(i): return i.name))
	await _u4_icons(m)
	check("wide_on", root.content_scale_aspect == XSkinLayout.aspect_for(Vector2(root.size)))
	check("party_rows", m.party.members.size() == menu._members().size(), [m.party.members.size(), menu._members().size()])
	check("blocks", m.layout.center.size.x <= 720.0 and m.run_panel.size.y == XSkinMainMenu.RUN_H)
	# 第一组物品：只一项，不展开（没有组名行），列表里其余五组各一行
	var kinds := m.rows().map(func(r): return r.kind)
	check("rows_first_direct", kinds == ["item", "group", "group", "group", "group", "group"], kinds)
	# 每组展开时都不超出中块
	var over := []
	for g in m.groups.size():
		m.gi = g
		m.ii = 0
		m._layout_rows()
		var last: Rect2 = m.rows()[-1].rect
		if last.end.y > m.pane.size.y - XUiSkin.PAD + 0.5:
			over.append([g, last.end.y, m.pane.size.y])
	check("rows_fit", over.is_empty(), over)
	m.gi = 2
	m.ii = 0
	m.refresh()
	kinds = m.rows().map(func(r): return r.kind)
	check("rows_actor_open", kinds == ["group", "group", "header", "item", "item", "item", "item", "item", "group", "group", "group"], kinds)
	check("row_heights", m.rows()[3].rect.size.y == 56.0 and m.rows()[2].rect.size.y == 46.0)
	check("bar_on_row", m.bar.visible and m.bar.target == m.rows()[3].rect)
	# 上下跨组
	_press(m, "ui_up")
	check("up_cross", m.gi == 1 and m.ii == 0 and m.ring.index == 1)
	_press(m, "ui_down")
	_press(m, "ui_down")
	check("down_in_group", m.gi == 2 and m.ii == 1)
	m.ii = 4
	_press(m, "ui_down")
	check("down_cross", m.gi == 3 and m.ii == 0 and m.current_item().key == "crafting")
	_press(m, "ui_up")
	check("up_cross_last", m.gi == 2 and m.ii == 4 and m.current_item().key == "formation")
	m._set_group(5, 3)
	m.move_item(1, false)
	check("hold_no_wrap", m.gi == 5 and m.ii == 3)
	m.move_item(1, true)
	check("wrap_to_first", m.gi == 0 and m.ii == 0)
	# 左右、Q／E 换组
	_press(m, "ui_right")
	check("right_group", m.gi == 1 and m.ring.index == 1)
	_key(m, KEY_Q)
	_key(m, KEY_Q)
	check("q_wraps", m.gi == 5 and m.ring.index == 5)
	_key(m, KEY_E)
	check("e_wraps", m.gi == 0)
	# 环上点别的组：列表跟着
	m.ring.select(4)
	check("ring_drives_list", m.gi == 4 and m.ii == 0)
	# 直接进：物品组
	m._set_group(0, 0)
	_press(m, "ui_accept")
	await frames(2)
	var page: Node = _child_of(menu, "XItemScene")
	check("direct_item_page", menu._mode == "page" and page != null and not m.visible)
	# 1B 起物品页按新稿排好、自己 request_wide（XSkinItemPage）：主菜单让出后由物品页接着铺满，计数不乱
	check("wide_held_by_new_item_page", page != null and page.get("skin") != null and root.content_scale_aspect == XSkinLayout.aspect_for(Vector2(root.size)) and XSkinLayout._wide_users == 1)
	if page != null:
		page.closed.emit()
	await frames(2)
	check("back_from_page", menu._mode == "command" and m.visible and m.gi == 0)
	check("wide_back", root.content_scale_aspect == XSkinLayout.aspect_for(Vector2(root.size)))
	# 装备：先选人
	m._set_group(1, 0)
	_press(m, "ui_accept")
	check("equip_actor_mode", menu._mode == "actor" and menu._pending == "equip" and m.party.selectable and m.party.index == 0)
	check("hints_actor", m.hints.hints == [["确定", "进入"], ["取消", "返回"]])
	_press(m, "ui_down")
	check("actor_down", menu._actor_index == 1 and m.party.index == 1)
	var gi_before := m.gi
	m.ring.select(4)
	check("actor_ring_locked", m.gi == gi_before and m.ring.index == gi_before and m.ring.mouse_filter == Control.MOUSE_FILTER_IGNORE and menu._mode == "actor")
	_press(m, "ui_cancel")
	check("actor_cancel", menu._mode == "command" and not m.party.selectable and m.hints.hints.size() == 3)
	check("ring_mouse_back", m.ring.mouse_filter == Control.MOUSE_FILTER_STOP)
	_press(m, "ui_accept")
	check("actor_resets_to_selected", menu._actor_index == 0)   # 同旧菜单：重进选人从上次进过页的人开始
	_press(m, "ui_down")
	_press(m, "ui_accept")
	await frames(2)
	page = _child_of(menu, "XEquipScene")
	check("equip_page", menu._mode == "page" and page != null and menu._selected_actor == 1, [menu._mode, page != null, menu._selected_actor])
	if page != null:
		page.closed.emit()
	await frames(2)
	# 收起行：单项组写说明、不重复名字（小A P2）；多项组列子项名
	check("collapsed_single_desc", XSkinMainMenu.collapsed_text(m.groups[0]) == "使用和查看随身物品" and XSkinMainMenu.collapsed_text(m.groups[1]) == "更换角色装备")
	check("collapsed_multi_names", XSkinMainMenu.collapsed_text(m.groups[3]) == "制作　宝珠坊　异化工坊", XSkinMainMenu.collapsed_text(m.groups[3]))
	check("system_names", m.groups[5].items.map(func(i): return i.name) == ["存档", "设置", "反馈", "返回标题"])
	# 被隐藏的子项按符号问也不可用（宠物天启篇隐藏；异化隐藏时工坊）
	XAlienBattle.HIDDEN_V058 = true
	check("hidden_symbol_disabled", not menu.symbol_enabled("pet") and not menu.symbol_enabled("alienation") and menu.symbol_enabled("orbs"))
	XAlienBattle.HIDDEN_V058 = false
	check("alien_symbol_back", menu.symbol_enabled("alienation"))
	# 不可用：反馈（没做）蜂鸣不进；整队至少 2 人
	m._set_group(5, 2)
	check("feedback_item", m.current_item().key == "feedback" and not m.item_enabled(m.current_item()))
	_press(m, "ui_accept")
	check("feedback_disabled", menu._mode == "command")
	# 鼠标：点收起的组行＝换组；点子项先选中、再点确定
	m._set_group(2, 0)
	var grp_row: Dictionary = m.rows().filter(func(r): return r.kind == "group" and r.g == 4)[0]
	_click(m, (grp_row.rect as Rect2).get_center())
	check("click_group", m.gi == 4 and m.ii == 0)
	var item_row: Dictionary = m.rows().filter(func(r): return r.kind == "item" and r.i == 1)[0]
	_click(m, (item_row.rect as Rect2).get_center())
	check("click_item_select", m.gi == 4 and m.ii == 1 and menu._mode == "command")
	# 只剩一项的组（自定义）：不展开，确定直接进
	m.groups = XUiSkin.visible_groups([{"key": "a", "name": "甲", "items": [{"key": "x", "name": "子一", "cmd": "item", "desc": "说明"},
		{"key": "y", "name": "子二", "cmd": "skill", "hidden": true}]}], s)
	m.gi = 0
	m.ii = 0
	m._layout_rows()
	check("custom_single_direct", m.rows().size() == 1 and m.rows()[0].kind == "item")
	# 取消关菜单
	m.groups = XUiSkin.visible_groups(XUiSkin.GROUPS, s)
	var closed := [false]
	menu.closed.connect(func(): closed[0] = true)
	_press(m, "ui_cancel")
	check("cancel_closes", closed[0])
	menu.queue_free()
	await frames(2)
	check("wide_restored", root.content_scale_aspect == aspect)


func _click(m: XSkinMainMenu, p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	m._pane_input(e)


func _child_of(menu: Node, cls: String) -> Node:
	for c in menu.get_children():
		var sc: Script = c.get_script()
		if sc != null and sc.get_global_name() == cls:
			return c
	return null


## ---- 关掉：回旧菜单 ----
func _off(s: XState) -> void:
	XState.current = s
	XUiSkin.ENABLED = false
	var menu := XMenu.new()
	add_child(menu)
	await frames(2)
	check("off_old_menu", menu.skin == null and menu.cmd_win != null and menu.command_names().size() == XMenu.commands().size())
	menu.queue_free()
	XUiSkin.ENABLED = true
	var xi := XState.new_game(3, 1, [8, 9, 10])
	XState.current = xi
	var m2 := XMenu.new()
	add_child(m2)
	await frames(2)
	check("xiyou_old_menu", m2.skin == null and m2.cmd_win != null)
	m2.queue_free()
	XState.current = s
	await frames(2)


func _shots(s: XState) -> void:
	XState.current = s
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	var menu := XMenu.new()
	add_child(menu)
	await frames(5)
	menu.skin._set_group(2, 2)
	for i in range(40):
		await get_tree().process_frame
	await shot("ui_skin_1a_menu_16x9")
	var win := get_window()
	var old := win.size
	win.size = Vector2i(1600, 720)
	await frames(10)
	check("wide_view_20x9", absf(menu.skin.layout.view_size().x / menu.skin.layout.view_size().y - 20.0 / 9.0) < 0.01, menu.skin.layout.view_size())
	check("wide_margin_56", menu.skin.layout.left.position.x == 56.0, menu.skin.layout.left.position)
	for i in range(20):
		await get_tree().process_frame
	await shot("ui_skin_1a_menu_20x9")
	win.size = old
	await frames(5)
	menu.queue_free()
	await frames(2)
	XUiSkin.motion_override = XUiSkin.Motion.OFF


## 组入口图标 u4（p1fix 追加）：28 张都在、六个可见组都有贴图、原生 64 整数位置、选中只换贴图不缩放；开关关掉回旧图标号
func _u4_icons(m: XSkinMainMenu) -> void:
	var missing := []
	for k in ["items", "equipment", "character", "party", "workshop", "codex", "system"]:
		for st in ["normal", "selected"]:
			for px in [64, 32]:
				var path := "%s%s_%s_%d.png" % [XUiSkin.GROUP_ICON_DIR, k, st, px]
				if not ResourceLoader.exists(path) or (load(path) as Texture2D).get_size() != Vector2(px, px):
					missing.append(path)
	check("u4_files", missing.is_empty(), missing)
	var ring := m.ring
	check("u4_all_groups_art", range(ring.items.size()).all(func(i): return ring.has_art(i)), ring.items.map(func(i): return i.key))
	ring.queue_redraw()
	await frames(2)
	var bad := []
	for d in ring.art_drawn:
		var r: Rect2 = d.rect
		if r.size != Vector2(64, 64) or r.position != r.position.round():
			bad.append(d)
		if (d.i == ring.index) != (d.tex == ring.items[d.i].art_selected):
			bad.append(["state", d.i])
	check("u4_native_64_integer", ring.art_drawn.size() == ring.items.size() and bad.is_empty(), bad)
	var before := ring.index
	ring.select((before + 1) % ring.items.size(), false)
	ring.queue_redraw()
	await frames(2)
	var sel_d: Array = ring.art_drawn.filter(func(d): return d.i == ring.index)
	var old_d: Array = ring.art_drawn.filter(func(d): return d.i == before)
	check("u4_select_swaps_texture", sel_d.size() == 1 and sel_d[0].tex == ring.items[ring.index].art_selected and (sel_d[0].rect as Rect2).size == Vector2(64, 64)
		and old_d.size() == 1 and old_d[0].tex == ring.items[before].art_normal)
	ring.select(before, false)
	XUiSkin.GROUP_ICONS_U4 = false
	var it := XSkinRingNav.group_item(XUiSkin.GROUPS[0])
	check("u4_switch_off_old_icon", not it.has("art_normal") and int(it.icon) == 100)
	XUiSkin.GROUP_ICONS_U4 = true
	check("u4_pets_no_art", not XSkinRingNav.group_item(XUiSkin.GROUPS.filter(func(g): return g.key == "pets")[0]).has("art_normal"))


## 两级操作（p1fix 追加，Kyo 11-15）：环→子项→打开→返回→环→回地图；换组时中块只列该组；触屏；记忆
func _two_level(s: XState) -> void:
	XSkinMainMenu._mem = {}
	var menu := XMenu.new()
	add_child(menu)
	await frames(3)
	var m := menu.skin
	check("two_start_ring", m.level == 0 and m.gi == 0 and not m.bar.visible)
	check("two_hints_l0", m.hints.hints == [["确定", "进入"], ["取消", "回地图"], ["Q / E", "换组"]])
	# 单项组：中块组名＋说明
	check("two_single_note", m.rows().map(func(r): return r.kind) == ["header", "note"])
	# 移到角色：中块只列角色的子项
	_press(m, "ui_right")
	_press(m, "ui_right")
	var keys := m.rows().filter(func(r): return r.kind == "item").map(func(r): return m.group_items(m.current_group())[r.i].key)
	check("two_actor_children", m.gi == 2 and m.ring.index == 2 and keys == ["status", "skill", "zhenqi", "race", "formation"] and m.rows()[0].kind == "header", keys)
	check("two_preview_no_bar", not m.bar.visible)
	_press(m, "ui_down")   # 第一级上下也是换组
	check("two_l0_down_group", m.gi == 3 and m.level == 0)
	_press(m, "ui_up")
	_press(m, "ui_accept")
	check("two_enter", m.level == 1 and m.ii == 0 and m.bar.visible and m.bar.target == m.selected_row_rect())
	check("two_hints_l1", m.hints.hints == [["确定", "打开"], ["取消", "返回"], ["Q / E", "换组"]])
	_press(m, "ui_down")
	_press(m, "ui_down")
	check("two_l1_down", m.gi == 2 and m.ii == 2 and m.current_item().key == "zhenqi")
	_press(m, "ui_up")
	_press(m, "ui_up")
	_press(m, "ui_up")
	check("two_l1_wrap", m.gi == 2 and m.ii == 4)
	_press(m, "ui_cancel")
	check("two_cancel_to_ring", m.level == 0 and menu._mode == "command" and not m.bar.visible and m.gi == 2)
	# 记忆：再进第二级回到刚才的子项
	_press(m, "ui_accept")
	check("two_mem_item", m.level == 1 and m.ii == 4, m.ii)
	_press(m, "ui_cancel")
	# 第二级里打开页面、返回后仍在第二级
	m._set_group(3, 0)
	m.level = 0
	_press(m, "ui_accept")
	_press(m, "ui_down")
	check("two_workshop_l1", m.level == 1 and m.current_item().key == "orb_shop")
	_press(m, "ui_accept")
	await frames(2)
	check("two_open_page", menu._mode == "page" and not m.visible)
	var page: Node = _child_of(menu, "XOrbShop")
	if page != null and page.has_signal("closed"):
		page.closed.emit()
	await frames(2)
	check("two_back_from_page", menu._mode == "command" and m.level == 1 and m.gi == 3 and m.ii == 1)
	_press(m, "ui_cancel")
	# 小A核 P2-1：第二级用 Q／E 切到单项组＝回第一级（不留幽灵第二级）
	m._set_group(2, 0)
	m.level = 0
	_press(m, "ui_accept")
	check("two_qe_setup", m.level == 1 and m.gi == 2)
	_key(m, KEY_Q)
	_key(m, KEY_Q)
	check("two_qe_single_drops_level", m.gi == 0 and m.level == 0 and m.hints.hints[0] == ["确定", "进入"], [m.gi, m.level])
	_key(m, KEY_E)
	_key(m, KEY_E)
	check("two_qe_multi_keeps_ring", m.gi == 2 and m.level == 0)
	# 小A核 P1-1：右键／两指＝取消：选人→列表、第二级→环、第一级→回地图（最后一步在下面重开菜单里测）
	_press(m, "ui_accept")
	_right(m)
	check("two_right_l1_to_ring", m.level == 0 and menu._mode == "command")
	m._set_group(1, 0)
	_press(m, "ui_accept")
	check("two_right_setup_actor", menu._mode == "actor")
	_right(m)
	check("two_right_actor_back", menu._mode == "command" and not m.party.selectable)
	# 单项组确定直接打开（物品）
	m._set_group(0, 0)
	_press(m, "ui_accept")
	await frames(2)
	page = _child_of(menu, "XItemScene")
	check("two_single_direct", menu._mode == "page" and page != null)
	if page != null:
		page.closed.emit()
	await frames(2)
	# 触屏：点环上别的组＝进第二级；点中块子项＝直接打开
	m.level = 0
	m._set_group(0, 0)
	_click_ring(m, 4)
	check("two_tap_ring_enters", m.gi == 4 and m.level == 1)
	var row: Dictionary = m.rows().filter(func(r): return r.kind == "item" and r.i == 2)[0]
	var closed := [false]
	menu.closed.connect(func(): closed[0] = true)
	_click(m, (row.rect as Rect2).get_center())
	await frames(2)
	check("two_tap_item_opens", closed[0] or menu._mode == "page", [menu._mode, m.current_item().get("key")])
	check("two_mem_saved", str(XSkinMainMenu._mem.get("g", "")) == "codex")
	menu.queue_free()
	await frames(2)
	# 重开菜单：停在上次的大类、第一级
	var menu2 := XMenu.new()
	add_child(menu2)
	await frames(3)
	check("two_reopen_mem", menu2.skin.gi == 4 and menu2.skin.ring.index == 4 and menu2.skin.level == 0 and menu2.skin.ii == 2, [menu2.skin.gi, menu2.skin.ii])
	# 第一级取消＝回地图
	var closed2 := [false]
	menu2.closed.connect(func(): closed2[0] = true)
	_press(menu2.skin, "ui_cancel")
	check("two_cancel_closes", closed2[0])
	var closed3 := [false]
	menu2.closed.connect(func(): closed3[0] = true)
	_right(menu2.skin)
	check("two_right_l0_closes", closed3[0])
	menu2.queue_free()
	await frames(2)
	XSkinMainMenu._mem = {}


func _right(m: XSkinMainMenu) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	m._input(e)


func _click_ring(m: XSkinMainMenu, i: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = m.ring.item_pos(i)
	m.ring._gui_input(e)


## 右栏助力位卡（p1fix 追加，Kyo 11-15）：天启篇第 5 张卡；空时占位；队伍框底边对齐中间栏；选人时跳过空位、助力的人可选
func _helper_card(s: XState) -> void:
	var menu := XMenu.new()
	add_child(menu)
	await frames(3)
	var m := menu.skin
	var n := menu._members().size()
	var on := m.helper_card_on()
	check("helper_on_tianqi", on, XTianqi.active(s))
	var last: Dictionary = m.party.members[-1]
	check("helper_empty_card", m.party.members.size() == n + 1 and bool(last.get("placeholder", false)) and str(last.name) == "助力位 · 空", m.party.members.size())
	var pb := m.party.position.y + m.party.size.y
	var cb := m.pane.size.y
	check("helper_aligned_bottom", absf(pb - cb) <= m.party.members.size() + 1.0, [pb, cb, m.party.row_height])
	# 选人：跳过空位
	m._set_group(1, 0)
	_press(m, "ui_accept")
	for k in n + 2:
		_press(m, "ui_down")
	check("helper_skip_empty", menu._mode == "actor" and menu._actor_index >= 0 and menu._actor_index < n)
	_press(m, "ui_cancel")
	# 小A核 P3-2：助力卡的状态图标（最多 4 个）在行高 60～120 时都不压「助力」角标
	var head := XUiSkin.font("title")
	var hit := []
	for rh in [60.0, 64.0, 72.0, 86.0, 120.0]:
		var r := Rect2(4, 44, 352, rh)
		var tag := XSkinPartyStrip.helper_tag_rect(r, head)
		for k in 4:
			if m.party.state_icon_rect(r, k, true).intersects(tag):
				hit.append([rh, k])
	check("helper_tag_clear_of_states", hit.is_empty() and m.party.state_icon_rect(Rect2(4, 44, 352, 60), 0, false).intersects(XSkinPartyStrip.helper_tag_rect(Rect2(4, 44, 352, 60), head)), hit)
	XSkinMainMenu.HELPER_CARD = false
	m.refresh()
	check("helper_switch_off", m.party.members.size() == n and m.party.row_height == XUiSkin.MEMBER_H)
	XSkinMainMenu.HELPER_CARD = true
	m.refresh()
	menu.queue_free()
	await frames(2)
	# 有助力：第 4 个人放进第 5 格，卡挪到最后、带助力标
	if s.battle_slots.size() > XTianqi.HELPER_SLOT and n >= 4:
		var keep: Array = s.battle_slots.duplicate()
		var hid := int(s.party[3])
		for k in s.battle_slots.size():
			if int(s.battle_slots[k]) == hid:
				s.battle_slots[k] = 0
		s.battle_slots[XTianqi.HELPER_SLOT] = hid
		var menu2 := XMenu.new()
		add_child(menu2)
		await frames(3)
		var m2 := menu2.skin
		var l2: Dictionary = m2.party.members[-1]
		check("helper_filled_card", s.helper() != null and m2.party.members.size() == n and bool(l2.get("helper", false)) and not l2.has("placeholder")
			and str(l2.name) == s.actor(hid).display_name(), [m2.party.members.size(), l2.get("name")])
		menu2.queue_free()
		await frames(2)
		s.battle_slots = keep
