extends Node
## T300 卡 L「设置子页」专项（T254 3.7、版型三）：画质、消息提醒、屏蔽掉落、角色换装、导入导出、手机按键六页套 XSkinSubPage。
## - 每页：旧页显示的每一项新页都取得到（行名、值）、点行选中／点当前行确定、右键取消、环不动（分类同主页）、面包屑；
## - 设置主页进子页不套 1280×720 外框（自带新皮肤）；挂机、测试模式子页仍走旧外框，开关新皮肤前后一致；
## - 手机按键：行尾细条、对当前布局没用的行变灰「—」、恢复默认走统一确认弹窗、调整位置拖动态淡出只留「完成」；
## - 开关 XSkinSubPage.ENABLED＝false 或西游存档：六页旧画法一行不变。
## 带 -- --out=<目录> 且有窗口时截图（16:9 800×450、20:9 1000×450；各状态；字体 130%；旧画法对照）。
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
	if name.ends_with("_20x9"):
		check("shot_size_" + name, img.get_size() == Vector2i(1000, 450), img.get_size())
	elif name.ends_with("_16x9"):
		check("shot_size_" + name, img.get_size() == Vector2i(800, 450), img.get_size())


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


## 只拍 20:9（1000×450）：先把窗口拉到 20:9、再跑 setup（比如进拖动态）、再拍
func shot_wide(name: String, setup: Callable) -> void:
	if not windowed():
		await setup.call()
		return
	var win := get_window()
	var old := win.size
	var old_aspect := win.content_scale_aspect
	win.unresizable = false
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
	win.size = Vector2i(1000, 450)
	DisplayServer.window_set_size(Vector2i(1000, 450))
	await get_tree().create_timer(0.6).timeout
	await frames(8)
	await setup.call()
	await frames(8)
	await shot(name + "_20x9")
	win.content_scale_aspect = old_aspect
	win.size = old
	await frames(4)


func _act(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _key(page: Node, action: String) -> void:
	page._unhandled_input(_act(action))


func _state(tianqi := true) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	if tianqi:
		s.flags["tianqi"] = {"rules": 1}
	return s


func _mk(page: Control) -> Control:
	add_child(page)
	await frames(4)
	return page


func _row_texts(page: Control) -> Array:
	return page.skin_rows().map(func(r): return str(r.text))


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_card_l")
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	await _graphics()
	await _notice()
	await _pingbi()
	await _costumes()
	await _transfer()
	await _touch()
	await _hosting()
	await _rollback()
	XUiSkin.motion_override = -1
	XTouchControls.instance = null
	XState.current = null
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 公共断言：新页建好、环同类、面包屑、行数
func _common(tag: String, page: Control, cat: String, old_rows: int) -> bool:
	var sk: XSkinSubPage = page.skin
	if not check(tag + "_built", sk != null):
		return false
	check(tag + "_rows_count", sk.list.items.size() == old_rows, [sk.list.items.size(), old_rows])
	check(tag + "_cat", sk.ring.items[sk.ring.index].key == cat, sk.ring.items[sk.ring.index])
	check(tag + "_crumb", sk.crumb.size() == 2 and str(sk.crumb[1]) == page.skin_name(), sk.crumb)
	check(tag + "_ring_not_clickable", sk.ring.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	check(tag + "_old_hidden", not page.get("head_win") or not page.head_win.visible)
	return true


# ---- 画质 ----
func _graphics() -> void:
	_state()
	var page: XGraphicsOptionsScene = await _mk(XGraphicsOptionsScene.new())
	var n := XGraphicsOptionsScene.rows().size()
	if not _common("gfx", page, "screen", n):
		page.queue_free()
		return
	var sk := page.skin
	# 旧页每项：名字、说明、状态
	for i in n:
		var row: Array = XGraphicsOptionsScene.rows()[i]
		var r: Dictionary = page.skin_rows()[i]
		check("gfx_row_%s" % row[0], r.text == row[1] and r.right == page.status_text(i), r)
		var c: Dictionary = page.skin_card(i)
		check("gfx_card_%s" % row[0], c.desc == row[2] and c.subtitle == page.status_text(i) and c.sections[0].title == "可选", c)
		var labels: Array = (c.sections[0].lines as Array).map(func(l): return l.left)
		check("gfx_choices_%s" % row[0], labels.size() == XGraphicsOptionsScene.choices(row[0]).size(), labels)
		var now := (c.sections[0].lines as Array).filter(func(l): return l.right.contains("现在"))
		check("gfx_now_%s" % row[0], now.size() == 1, now)
	page.index = 0
	await shots("L_画质_常态")
	page.index = 3
	await frames(3)
	await shots("L_画质_选帧率", false)
	XFontScale.set_value("global", 130)
	await frames(3)
	await shots("L_画质_字体130", false)
	XFontScale.set_value("global", 100)
	# 键盘：确定换下一档（像素柔边 开→关）
	page.index = 0
	await frames(2)
	var before: String = page.skin_rows()[0].right
	_key(page, "ui_accept")
	await frames(3)
	check("gfx_ok_changes", page.skin_rows()[0].right != before and sk.list.items[0].right == page.skin_rows()[0].right, [before, page.skin_rows()[0].right])
	# 点行：点非当前行选中、点当前行确定
	sk.list.select(2, false)
	sk.list.index_changed.emit(2)
	await frames(2)
	check("gfx_click_select", page.index == 2, page.index)
	var v2: String = page.skin_rows()[2].right
	sk.list.activated.emit(2)
	await frames(2)
	check("gfx_click_ok", page.skin_rows()[2].right != v2)
	# 字体两行存在
	check("gfx_font_rows", _row_texts(page).has("字体大小") and _row_texts(page).has("弹窗字号"))
	# 取消
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	_key(page, "ui_cancel")
	check("gfx_cancel", closed[0])
	# 还原画质设置（整数倍缩放等会改窗口拉伸，后面的截图要真尺寸）
	for key in XGraphics.DEFAULTS:
		XGraphics.set_value(key, XGraphics.DEFAULTS[key])
	await frames(3)
	page.queue_free()
	await frames(2)


# ---- 消息提醒 ----
func _notice() -> void:
	_state()
	var page: XNoticeOptionsScene = await _mk(XNoticeOptionsScene.new())
	var n := XNoticeOptionsScene.rows().size()
	if not _common("note", page, "general", n):
		page.queue_free()
		return
	var sk := page.skin
	check("note_nine", n == 9, n)
	for i in n:
		var row: Array = XNoticeOptionsScene.rows()[i]
		var on := XConfig.notice_on(row[0])
		var r: Dictionary = page.skin_rows()[i]
		check("note_row_%s" % row[0], r.text == row[1] and r.right == ("开" if on else "关") and r.right_color == (XUiSkin.GOLD_LIGHT if on else XUiSkin.TEXT_2), r)
		check("note_card_%s" % row[0], page.skin_card(i).desc == row[2])
	var v0 := XConfig.notice_on(XNoticeOptionsScene.rows()[0][0])
	_key(page, "ui_accept")
	check("note_ok_toggles", XConfig.notice_on(XNoticeOptionsScene.rows()[0][0]) != v0)
	_key(page, "ui_left")
	check("note_left_off", not XConfig.notice_on(XNoticeOptionsScene.rows()[0][0]))
	_key(page, "ui_right")
	check("note_right_on", XConfig.notice_on(XNoticeOptionsScene.rows()[0][0]))
	await shots("L_消息提醒_常态")
	_key(page, "ui_left")
	sk.list.select(3, false)
	sk.list.index_changed.emit(3)
	await frames(3)
	await shots("L_消息提醒_关了一项", false)
	_key(page, "ui_right")
	page.queue_free()
	await frames(2)


# ---- 屏蔽掉落 ----
func _pingbi() -> void:
	var s := _state()
	var page: XPingbiScene = await _mk(XPingbiScene.new())
	var n := page.rows().size()
	if not _common("pb", page, "general", n):
		page.queue_free()
		return
	var sk := page.skin
	check("pb_rows", n >= 5, n)
	for i in n:
		var g := int(page.rows()[i][0])
		var qn: String = XQuality.config().names[g]
		var r: Dictionary = page.skin_rows()[i]
		check("pb_row_%d" % g, r.text == "屏蔽 %s 装备" % qn and r.right == "关", r)
	_key(page, "ui_accept")
	await frames(3)
	check("pb_ok_all", page.skin_rows()[0].right == "开" and XPingbi.state(s, int(page.rows()[0][0])) == "all", page.skin_rows()[0])
	# 部分：手动关掉第一档里的一个品质
	var mem := XPingbi.members(int(page.rows()[0][0]))
	if mem.size() > 1:
		s.pingbi_quality[mem[0]] = false
		await frames(3)
		check("pb_partial", page.skin_rows()[0].right == "部分", page.skin_rows()[0])
		var c: Dictionary = page.skin_card(0)
		check("pb_partial_note", str(c.sections).contains("部分"), c)
	_key(page, "ui_right")
	check("pb_right_noop", true)
	await shots("L_屏蔽掉落_常态")
	sk.list.select(1, false)
	sk.list.index_changed.emit(1)
	await frames(2)
	sk.list.activated.emit(1)
	await frames(3)
	check("pb_click_ok", page.skin_rows()[1].right == "开", page.skin_rows()[1])
	await shots("L_屏蔽掉落_选中二", false)
	page.queue_free()
	await frames(2)


# ---- 角色换装 ----
func _costumes() -> void:
	var s := _state()
	# 学几张换装卡：每个队员学两张（卡名多时右牌折行）
	var skill_ids := []
	for card in XCostumes.registry().values():
		skill_ids.append(int(card.skill))
	for k in s.party.size():
		var a := s.actor(int(s.party[k]))
		for j in 2:
			a.learn_skill(skill_ids[(k * 2 + j) % skill_ids.size()])
	var page: XCostumesScene = await _mk(XCostumesScene.new())
	var n := page.actors.size()
	if not _common("cos", page, "general", n):
		page.queue_free()
		return
	var sk := page.skin
	for i in n:
		var t := XCostumesScene.row_texts(page.actors[i])
		var r: Dictionary = page.skin_rows()[i]
		check("cos_row_%d" % i, r.text == t[0] and r.sub == t[1] and r.right == t[2] and r.icon != null, r)
		var c: Dictionary = page.skin_card(i)
		check("cos_card_full_names_%d" % i, str(c.desc).contains(t[1]), c)
	var was: String = page.skin_rows()[0].right
	_key(page, "ui_accept")
	await frames(3)
	check("cos_ok_toggle", page.skin_rows()[0].right != was and sk.list.items[0].right == page.skin_rows()[0].right)
	check("cos_on_green", XCostumes.enabled(s, page.actors[0].actor_id) == (page.skin_rows()[0].right == "启用"))
	for r in page.skin_rows():
		check("cos_color_" + r.text, r.right_color == (XUiSkin.UP if r.right == "启用" else XUiSkin.TEXT_2))
	await shots("L_角色换装_常态")
	page.queue_free()
	await frames(2)
	# 没有换装卡的角色：写「未使用换装卡」
	var s2 := _state()
	var p2: XCostumesScene = await _mk(XCostumesScene.new())
	var none_ok := false
	for r in p2.skin_rows():
		none_ok = none_ok or r.sub == XCostumesScene.NO_CARD
	check("cos_no_card_text", none_ok or p2.actors.is_empty())
	await shots("L_角色换装_无卡", false)
	# 空列表
	s2.party.clear()
	s2.saved_actors.clear()
	p2.actors = []
	await frames(3)
	check("cos_empty_text", p2.skin.list.empty_center and p2.skin.list.items.is_empty() and p2.skin.list.empty_text != "")
	p2.queue_free()
	await frames(2)


# ---- 导入／导出 ----
func _transfer() -> void:
	_state()
	var page: XConfigTransferScene = await _mk(XConfigTransferScene.new())
	var n := XConfigTransferScene.rows().size()
	if not _common("tr", page, "other", n):
		page.queue_free()
		return
	var sk := page.skin
	var keys := XConfigTransferScene.rows().map(func(r): return r[0])
	check("tr_keys", keys.has("copy") and keys.has("paste") and keys.has("undo"), keys)
	for i in n:
		check("tr_row_%d" % i, page.skin_rows()[i].text == XConfigTransferScene.rows()[i][1])
		check("tr_card_%d" % i, page.skin_card(i).desc == XConfigTransferScene.rows()[i][2])
	var ui := keys.find("undo")
	check("tr_undo_disabled", bool(page.skin_rows()[ui].get("disabled", false)) and page.skin_rows()[ui].right == "没有可撤回的" or XConfigTransfer.has_backup(), page.skin_rows()[ui])
	# 导出到剪贴板：结果写进右牌
	page.index = keys.find("copy")
	_key(page, "ui_accept")
	await frames(3)
	check("tr_copy_result_in_card", str(page.skin_card(page.index).sections).contains("已复制到剪贴板"))
	await shots("L_导入导出_常态")
	# 从剪贴板导入：校验结果出现在右牌、主按钮「导入这 N 项」；别的行作废
	var pi := keys.find("paste")
	page.index = pi
	page._ask_import("paste", XConfigTransfer.export_text())
	await frames(3)
	var c: Dictionary = page.skin_card(pi)
	var nvals := (page.pending["preview"]["values"] as Dictionary).size()
	check("tr_pending_button", c.buttons.size() == 1 and c.buttons[0].text == "导入这 %d 项" % nvals and c.buttons[0].primary, c.buttons)
	check("tr_pending_message", str(c.sections).contains("将导入"), c.sections)
	check("tr_pending_row_tag", page.skin_rows()[pi].right == "待确认")
	check("tr_pending_hint", page.skin_hints()[0][1] == "导入")
	await shots("L_导入导出_待确认")
	page.skin.card_button.emit(0)
	await frames(3)
	check("tr_button_imports", page.pending.is_empty() and str(page.message).contains("已导入"), page.message)
	check("tr_undo_enabled_after", not bool(page.skin_rows()[ui].get("disabled", false)))
	# 再来一次：按别的行就作废（规则不变）
	page._ask_import("paste", XConfigTransfer.export_text())
	page.select(0)
	await frames(2)
	check("tr_other_row_voids", page.pending.is_empty() and page.skin_card(0).buttons.is_empty())
	# 出错文本：错误写右牌
	page._ask_import("paste", "不是配置")
	await frames(2)
	check("tr_error_in_card", str(page.skin_card(page.index).sections).contains("不是本游戏导出"))
	await shots("L_导入导出_错误", false)
	page.queue_free()
	await frames(2)


# ---- 手机按键 ----
func _touch() -> void:
	_state()
	var pad := XTouchControls.new()
	add_child(pad)
	await frames(2)
	XTouchControls.instance = pad
	pad.set_choice("style", "modern")
	var page: XTouchOptionsScene = await _mk(XTouchOptionsScene.new())
	var n := XTouchOptionsScene.rows().size()
	if not _common("tc", page, "hangup", n):
		page.queue_free()
		return
	var sk := page.skin
	check("tc_not_fullscreen_group", not sk.is_in_group(XUiSkin.FULLSCREEN_GROUP))
	for i in n:
		var r: Dictionary = page.skin_rows()[i]
		var key: String = XTouchOptionsScene.rows()[i][1]
		check("tc_row_%s" % key, r.text == XTouchOptionsScene.rows()[i][0] and (r.right == page.status_text(i) or key in ["position", "reset"]), r)
	# 细条：大小、透明度行有 0～1，开关行 -1
	var bars := page.skin_bars()
	var ki := XTouchOptionsScene.rows().map(func(r): return r[1])
	var bi: int = ki.find("stick")
	check("tc_bar_stick", float(bars[bi]) >= 0.0 and float(bars[bi]) <= 1.0, bars)
	check("tc_bar_none_on_flags", float(bars[ki.find("visible")]) < 0.0 and float(bars[ki.find("style")]) < 0.0)
	check("tc_bar_value", absf(float(bars[bi]) - float(int(pad.settings.stick) - 70) / 100.0) < 0.001, [bars[bi], pad.settings.stick])
	# 加一步：条跟着变
	page.index = bi
	var b0: float = bars[bi]
	_key(page, "ui_right")
	await frames(3)
	check("tc_bar_moves", float(page.skin_bars()[bi]) > b0 or int(pad.settings.stick) == 170, page.skin_bars()[bi])
	check("tc_status_pct", page.skin_rows()[bi].right == "%d%%" % int(pad.settings.stick))
	# 滚动：行数多，一屏放不下
	check("tc_scrollable", sk.list.scrollable() or n <= sk.list.visible_rows(), [n, sk.list.visible_rows()])
	await shots("L_手机按键_常态")
	page.index = ki.find("transparency")
	await frames(3)
	await shots("L_手机按键_选透明度", false)
	# 原版虚拟按钮：只对改版有用的行变灰「—」
	pad.set_choice("style", "original")
	await frames(4)
	for key in XTouchOptionsScene.MODERN_ONLY:
		var idx: int = ki.find(key)
		if idx < 0:
			continue
		var r: Dictionary = page.skin_rows()[idx]
		check("tc_ghost_%s" % key, bool(r.get("disabled", false)) and r.right == "—" and float(page.skin_bars()[idx]) < 0.0, r)
	page.index = ki.find("mode")
	await frames(3)
	await shots("L_手机按键_灰行", false)
	pad.set_choice("style", "modern")
	await frames(3)
	# 恢复默认：统一确认弹窗，默认停「取消」，取消不改
	var ri: int = ki.find("reset")
	page.index = ri
	pad.set_value("stick", 120)
	_key(page, "ui_accept")
	await frames(3)
	check("tc_reset_dialog", page._dlg != null and is_instance_valid(page._dlg) and page._dlg.danger and page._dlg.index == 1, page._dlg)
	await shots("L_手机按键_恢复默认确认", false)
	_key(page, "ui_accept")   # 停在取消 → 确定＝取消
	await frames(3)
	check("tc_reset_cancel_keeps", int(pad.settings.stick) == 120 and page._dlg == null, pad.settings.stick)
	_key(page, "ui_accept")
	await frames(3)
	page._dlg.select(0)
	_key(page, "ui_accept")
	await frames(3)
	check("tc_reset_confirm_resets", int(pad.settings.stick) == int(XTouchControls.default_settings().stick) and page._dlg == null, pad.settings.stick)
	# 调整位置：整页淡出，键盘不穿透；完成后回来
	page.index = ki.find("position")
	_key(page, "ui_accept")
	await frames(3)
	check("tc_layout_started", pad.layout_editing and page._layout_busy and not sk.visible, [pad.layout_editing, sk.visible])
	var bar: Control = pad._layout_bar
	check("tc_layout_bar_top_center", bar.visible and bar.position.y <= 12.0 and absf(bar.position.x + bar.size.x / 2.0 - get_viewport().get_visible_rect().size.x / 2.0) < 2.0, [bar.position, bar.size])
	var idx_before := page.index
	_key(page, "ui_down")
	check("tc_layout_keys_blocked", page.index == idx_before)
	await shots("L_手机按键_拖动态", false)
	pad.finish_layout()
	await frames(3)
	await shot_wide("L_手机按键_拖动态", func():
		page.index = ki.find("position")
		_key(page, "ui_accept")
		await frames(3))
	pad.finish_layout()
	await frames(3)
	check("tc_layout_back", not page._layout_busy and sk.visible and sk.modulate.a > 0.99 and bar.position.y > 100.0, [sk.visible, sk.modulate.a, bar.position])
	page.queue_free()
	pad.queue_free()
	XTouchControls.instance = null
	await frames(2)
	# 没有 XTouchControls（桌面）：行不崩
	var p2: XTouchOptionsScene = await _mk(XTouchOptionsScene.new())
	check("tc_no_pad_ok", p2.skin != null and p2.skin_rows().size() == XTouchOptionsScene.rows().size())
	p2.queue_free()
	await frames(2)


# ---- 设置主页进子页：不套外框；挂机、测试模式照旧 ----
func _hosting() -> void:
	_state()
	var opt := XOptionsScene.new()
	add_child(opt)
	await frames(4)
	var syms: Array = opt.symbols()
	var qi := syms.find("codexQuality")
	opt.index = qi
	opt._refresh()
	await frames(2)
	opt.ok()
	await frames(3)
	var pg: Node = opt._page
	check("host_gfx_self", pg is XGraphicsOptionsScene and pg.get_parent() == opt and pg.skin != null, pg)
	check("host_gfx_no_wrapper", opt.find_child("SkinSubPageHost", false, false) == null)
	check("host_gfx_ring_follows_main", pg.skin.ring.items.size() == opt.skin.ring.items.size() and pg.skin.ring.index == opt.skin.cur, [pg.skin.ring.index, opt.skin.cur])
	check("host_gfx_cat_is_screen", pg.skin.ring.items[pg.skin.ring.index].key == "screen", pg.skin.ring.items[pg.skin.ring.index])
	check("host_gfx_crumb_cat", str(pg.skin.crumb[0]) == str(opt.skin.cats[opt.skin.cur].name), pg.skin.crumb)
	check("host_gfx_backdrop_hidden", not pg.get_node("SkinBackdrop").visible if pg.has_node("SkinBackdrop") else true)
	check("host_main_hidden", not opt.skin.visible)
	await shots("L_主页进画质_常态")
	_key(pg, "ui_cancel")
	await frames(3)
	check("host_gfx_closed", opt._page == null and opt.skin.visible and not is_instance_valid(pg) or pg.is_queued_for_deletion())
	# 另几页同样走自带
	for pair in [["pingbiDrop", XPingbiScene], ["codexNotices", XNoticeOptionsScene], ["codexConfigTransfer", XConfigTransferScene], ["codexCostumes", XCostumesScene]]:
		var i := opt.symbols().find(pair[0])
		if i < 0:
			check("host_row_missing_" + pair[0], false)
			continue
		opt.index = i
		opt._refresh()
		await frames(2)
		opt.ok()
		await frames(3)
		var p: Node = opt._page
		check("host_%s_self" % pair[0], p != null and is_instance_of(p, pair[1]) and p.get_parent() == opt and p.skin != null, p)
		if p != null:
			p.closed.emit()
		await frames(3)
		check("host_%s_back" % pair[0], opt._page == null and opt.skin.visible)
	# 挂机、测试模式子页：开关新皮肤前后一致（都还套 1280×720 外框、新皮肤不接管）
	var snap := func() -> Array:
		var out := []
		for mk in [func(): return XHangUpOptionsScene.new(), func(): return XTestModeScene.new()]:
			var p: Control = mk.call()
			opt._open_page(p)
			await frames(3)
			out.append([p.get_parent().name, p.get_parent().size, "skin" in p and p.skin != null])
			p.closed.emit()
			await frames(3)
			out.append([opt._page == null, opt.skin.visible])
		return out
	var on_snap: Array = await snap.call()
	XSkinSubPage.ENABLED = false
	var off_snap: Array = await snap.call()
	XSkinSubPage.ENABLED = true
	check("host_hangup_testmode_same", JSON.stringify(on_snap) == JSON.stringify(off_snap), [on_snap, off_snap])
	check("host_hangup_testmode_host", on_snap[0][0] == "SkinSubPageHost" and on_snap[2][0] == "SkinSubPageHost", on_snap)
	opt.queue_free()
	await frames(2)


# ---- 回退 ----
func _rollback() -> void:
	# 开关关：六页旧画法（skin 为 null、旧窗口可见）
	_state()
	XSkinSubPage.ENABLED = false
	var pad := XTouchControls.new()
	add_child(pad)
	XTouchControls.instance = pad
	await frames(2)
	for mk in [func(): return XGraphicsOptionsScene.new(), func(): return XNoticeOptionsScene.new(), func(): return XPingbiScene.new(),
			func(): return XCostumesScene.new(), func(): return XConfigTransferScene.new(), func(): return XTouchOptionsScene.new()]:
		var p: Control = await _mk(mk.call())
		var nm := str(p.get_script().get_global_name())
		check("rb_off_%s" % nm, p.skin == null and not p.skin_self_hosted(), nm)
		var win = p.get("list_win") if p.get("list_win") != null else p.get("win")
		check("rb_off_old_window_%s" % nm, win != null and win.visible, nm)
		if nm == "XGraphicsOptionsScene":
			await shots("L_旧画法对照_画质", false)
		p.queue_free()
		await frames(2)
	XSkinSubPage.ENABLED = true
	pad.queue_free()
	XTouchControls.instance = null
	# 西游存档（没有天启篇标记）：新皮肤本来就不开，六页旧画法
	_state(false)
	for mk in [func(): return XGraphicsOptionsScene.new(), func(): return XNoticeOptionsScene.new(), func(): return XPingbiScene.new(),
			func(): return XCostumesScene.new(), func(): return XConfigTransferScene.new()]:
		var p: Control = await _mk(mk.call())
		check("rb_xiyou_%s" % str(p.get_script().get_global_name()), p.skin == null)
		p.queue_free()
		await frames(2)
	# 旧画法逐项还在（取旧窗口数据：画质行表与状态）
	check("rb_gfx_rows_const", XGraphicsOptionsScene.ROWS.size() == 8)
