extends Node
## 新界面第 3A 批（ui-skin-3a）专项：七印祭坛页 XTianqiSkinAltar（#80、#81）、号卷与七印装备展示 XTianqiSkinShow（#82）。
## - 七印行：三种状态（未开启／可揭开／已揭开）对上 1A 的七印进度、开启条件、躁动、本印封存件数；
## - 入口：揭印／再进里副本、没开启的不能按、祭坛别的入口照列、离开不列；
## - 页：初始停在可揭开的、左右换印首尾相接、上下换入口、Y 开关规则（开着时别的键不动）、确定交回 {id, seal}、取消＝离开、鼠标点印／点入口；
##   锚点：牌贴右（16:9 边 24、20:9 边 56）、上下沿 72／668、印和字不进牌、按键提示让出版本号；
## - 接到流程：真地图宿主（Node）开着新界面走页面不问「七印祭坛。」那句；揭印带上环上的印、不再问选哪一印；返回后回到页面；离开回大厅；
##   新界面关掉、假宿主都照旧问对话框选单；
## - #82：七印装备牌写印·类别·真印、成色；号卷牌写第几卷、效果代价获得限制；「给谁学」写已学几卷／已学会；关掉时不动；
## - #81：戴着七印外观的人，角色条带上本印；关掉时不带。
## 带 -- --out=<目录> 且有窗口时截图（16:9、20:9）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")


class NodeHost extends Node:
	var answers: Array = []
	var asked: Array = []
	var said: Array = []
	var moves: Array = []
	func show_text(_f: String, _i: int, lines: Array) -> void:
		said.append_array(lines)
		await get_tree().process_frame
	func show_text_with_choices(_f: String, _i: int, lines: Array, options: Array, _cancel: int) -> int:
		said.append_array(lines)
		asked.append(options)
		await get_tree().process_frame
		return int(answers.pop_front()) if not answers.is_empty() else options.size() - 1
	func transfer(id: int, x: int, y: int, d: int, _fade := 0) -> void:
		moves.append([id, x, y, d])
		XState.current.map_id = id
		await get_tree().process_frame
	func start_battle(_troop: int, _e: bool, _l: bool, _r := false) -> int:
		return 1


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


func shots(name: String) -> void:
	if not windowed():
		return
	await frames(20)
	await shot(name + "_16x9")
	var win := get_window()
	var old := win.size
	win.size = Vector2i(1600, 720)
	await frames(12)
	await shot(name + "_20x9")
	win.size = old
	await frames(8)


func _key(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _keycode(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	return e


func _click(p: Vector2, b := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = b
	e.pressed = true
	e.position = p
	return e


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


## 天启篇存档、5 个弱者、战争线开场已打完、变量 20 = floor（同 xiyou_tianqi_qiyin_altar）
func _state(floor := 33) -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, floor)
	XState.current = s
	s.flags.tianqi["line"] = "war"
	XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	XTianqiQiyin.set_current("")
	XTianqiQiyin.rng_override = XRandomStream.create("0123012301230123", "qiyin")
	XTianqiSkinAltar.last_seal = ""
	return s


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_3a")
	DirAccess.remove_absolute(XGlobalVars.path())
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XMessageBox.auto = true
	_rows()
	_buttons()
	await _page()
	await _page_layout()
	await _flow()
	await _flow_off()
	_gear_card()
	_trumpet()
	_look()
	_name_fit()
	await _shots_82()
	XUiSkin.ENABLED = true
	XUiSkin.motion_override = -1
	XState.current = null
	XTianqiQiyin.set_current("")
	XTianqiQiyin.rng_override = null
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	DirAccess.remove_absolute(XGlobalVars.path())
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 七印行 ----

func _rows() -> void:
	var s := _state(33)   # 打过 31、32 层：白、红、黑揭开
	XTianqiQiyin.sync(s)
	var p := XTianqiQiyin.progress(s)
	p.drop["first_clear"] = {"bai": true}
	p.drop["restless"] = "hong"
	p.bag = [{"kind": "set", "seal": "hei", "part": "head", "revealed": false}, {"kind": "set", "seal": "hei", "part": "feet", "revealed": false},
		{"kind": XTianqiQiyinDrop.KIND_WEAPON, "seal": "hei", "wtype": "剑", "revealed": false}, {"kind": "set", "seal": "hei", "part": "legs", "revealed": true}]
	var rows := XTianqiSkinAltar.seal_rows(s)
	check("rows_seven", rows.size() == 7 and rows.map(func(r): return r.key) == XTianqiQiyin.seal_keys(), rows.map(func(r): return r.key))
	check("rows_states", rows.map(func(r): return int(r.state)) == [2, 1, 1, 0, 0, 0, 0], rows.map(func(r): return r.state))
	check("rows_same_as_menu", rows.map(func(r): return int(r.state)) == XSkinMainMenu.seal_states(s))
	check("rows_seal_names", str(rows[0].seal) == str(XTianqiQiyin.seal_info("bai").seal) and str(rows[0].place) == str(XTianqiQiyin.seal_info("bai").name))
	check("rows_cond_floor", rows[0].cond == "打过第 31 层开启" and rows[2].cond == "打过第 32 层开启" and rows[3].cond == "打过第 33 层开启", rows.map(func(r): return r.cond))
	check("rows_cond_mo", rows[6].cond == "前六印的首领都打过后开启", rows[6].cond)
	check("rows_restless", rows[1].restless and not rows[0].restless)
	check("rows_sealed_counts", int(rows[2].set) == 2 and int(rows[2].weapon) == 1 and int(rows[0].set) == 0, [rows[2].set, rows[2].weapon])
	check("sealed_lines", XTianqiSkinAltar.sealed_lines(rows[2]) == [["封着的套装件", 2], ["封着的毕业武器", 1]] and XTianqiSkinAltar.sealed_lines(rows[0]).is_empty())
	var lines := XTianqiSkinAltar._card_lines(rows[1])
	check("card_lines", lines[0][0] == "可揭开" and lines[1][0] == "打过第 31 层开启" and lines[2][0] == "躁动中", lines.map(func(l): return l[0]))
	check("state_texts", XTianqiSkinAltar.STATE_TEXT == ["未开启", "可揭开", "已揭开"])


func _buttons() -> void:
	var s := _state(33)
	XTianqiQiyin.sync(s)
	XTianqiQiyin.progress(s).drop["first_clear"] = {"bai": true}
	var opts := XTianqiQiyin.altar_options(s)
	var rows := XTianqiSkinAltar.seal_rows(s)
	var b2 := XTianqiSkinAltar.card_buttons(rows[0], opts)
	check("btn_again", b2[0].id == "enter" and b2[0].text == "再进里副本" and b2[0].primary and not b2[0].disabled, b2[0])
	var b1 := XTianqiSkinAltar.card_buttons(rows[1], opts)
	check("btn_reveal", b1[0].text == "揭印（进里副本）" and b1[0].primary and not b1[0].disabled, b1[0])
	var b0 := XTianqiSkinAltar.card_buttons(rows[5], opts)
	check("btn_locked_disabled", b0[0].disabled and not b0[0].primary, b0[0])
	var ids: Array = b1.map(func(b): return b.id)
	var want: Array = opts.map(func(o): return o.id).filter(func(i): return i != "leave")
	check("btn_rest_of_menu", ids == want and not ids.has("leave"), [ids, want])
	check("btn_labels_from_menu", b1.slice(1).map(func(b): return b.text) == opts.filter(func(o): return o.id != "enter" and o.id != "leave").map(func(o): return o.label))


# ---- 页 ----

func _page() -> void:
	var s := _state(33)
	XTianqiQiyin.sync(s)
	XTianqiQiyin.progress(s).drop["first_clear"] = {"bai": true}
	var opts := XTianqiQiyin.altar_options(s)
	var page := XTianqiSkinAltar.new()
	page.setup(s, opts)
	var got := []
	page.chosen.connect(func(r): got.append(r))
	add_child(page)
	await frames(3)
	check("page_start_first_open", page.index == 1, page.index)   # 第一枚「可揭开」的（红）
	check("page_wide", XSkinLayout.wide_active())
	check("page_hints", page.hint_list() == [["← / →", "切换印"], ["↑ / ↓", "选入口"], ["确定", "选择"], ["Y", "看规则"], ["取消", "离开"]])
	check("page_currencies", page.currency_pairs().map(func(p): return p[0]) == ["印钥", "印屑", "印库"] and page.currency_pairs()[0][1] == str(XTianqiQiyin.keys(s)), page.currency_pairs())
	page.handle_input(_key("ui_right"))
	check("page_right", page.index == 2 and XTianqiSkinAltar.last_seal == "hei")
	page.handle_input(_key("ui_left"))
	page.handle_input(_key("ui_left"))
	page.handle_input(_key("ui_left"))
	check("page_left_wraps", page.index == 6, page.index)
	page.handle_input(_key("ui_right"))
	check("page_right_wraps", page.index == 0)
	check("page_buttons_follow", page.buttons[0].text == "再进里副本")
	var n: int = page.buttons.size()
	page.handle_input(_key("ui_down"))
	check("page_down", page.button == (1 if n > 1 else 0), [page.button, n])
	page.handle_input(_key("ui_up"))
	page.handle_input(_key("ui_up"))
	check("page_up_wraps", page.button == n - 1, [page.button, n])
	page.handle_input(_key("ui_right"))
	check("page_seal_change_resets_button", page.button == 0 and page.index == 1)
	# Y：规则
	page.handle_input(_keycode(KEY_Y))
	check("rules_open", page.rules_open and page.rules.visible and page.hint_list() == [["Y / 取消", "关闭"]])
	check("rules_lines", page.rules_lines().size() == 6 and str(page.rules_lines()[0][1]).begins_with("打过对应的层"), page.rules_lines())
	page.handle_input(_key("ui_right"))
	page.handle_input(_key("ui_accept"))
	check("rules_swallow", page.index == 1 and got.is_empty())
	page.handle_input(_key("ui_cancel"))
	check("rules_close_cancel", not page.rules_open and got.is_empty())
	page.handle_input(_keycode(KEY_Y))
	page.handle_input(_keycode(KEY_Y))
	check("rules_close_y", not page.rules_open)
	# 没开启的印：确定不交回
	page.select(5)
	page.handle_input(_key("ui_accept"))
	check("locked_no_enter", got.is_empty())
	# 鼠标：点印、点入口
	page.handle_input(_key("ui_left"))
	page._gui_input(_click(page.seal_pos(2)))
	check("click_seal", page.index == 2, page.index)
	var br: Rect2 = page.button_rect(0)
	page._gui_input(_click(page.card_rect().position + br.get_center()))
	check("click_enter", got.size() == 1 and got[0] == {"id": "enter", "seal": "hei"}, got)
	page.queue_free()
	await frames(2)
	check("wide_released", not XSkinLayout.wide_active())
	# 记住上次的印；取消＝离开
	var page2 := XTianqiSkinAltar.new()
	page2.setup(s, opts)
	page2.chosen.connect(func(r): got.append(r))
	add_child(page2)
	await frames(2)
	check("page_remembers", page2.index == 2)
	page2.handle_input(_key("ui_down"))
	var second: Dictionary = page2.buttons[page2.button]
	page2.handle_input(_key("ui_accept"))
	check("accept_other_entry", got.size() == 2 and got[1].id == second.id, [got, second])
	page2.queue_free()
	var page3 := XTianqiSkinAltar.new()
	page3.setup(s, opts)
	page3.chosen.connect(func(r): got.append(r))
	add_child(page3)
	await frames(2)
	page3.handle_input(_key("ui_cancel"))
	check("cancel_leave", got.size() == 3 and got[2].id == "leave")
	page3.handle_input(_key("ui_cancel"))
	check("emit_once", got.size() == 3)
	page3.queue_free()
	var page4 := XTianqiSkinAltar.new()
	page4.setup(s, opts)
	page4.chosen.connect(func(r): got.append(r))
	add_child(page4)
	await frames(2)
	page4._gui_input(_click(Vector2(10, 10), MOUSE_BUTTON_RIGHT))
	check("right_click_leave", got.size() == 4 and got[3].id == "leave")
	page4.queue_free()
	await frames(2)


func _page_layout() -> void:
	var s := _state(33)
	XTianqiQiyin.sync(s)
	XTianqiQiyin.progress(s).drop["first_clear"] = {"bai": true}
	var page := XTianqiSkinAltar.new()
	page.setup(s, XTianqiQiyin.altar_options(s))
	add_child(page)
	await frames(3)
	var v := page.view()
	var cr := page.card_rect()
	check("card_right_edge", is_equal_approx(cr.end.x, v.x - XSkinLayout.margin_for(v.x)) and cr.size.x == XTianqiSkinAltar.CARD_W, [cr, v])
	check("card_top_bottom", cr.position.y == XUiSkin.TOP and cr.end.y == XUiSkin.BOTTOM, cr)
	var ok := true
	for i in 7:
		var p := page.seal_pos(i)
		if p.x + XTianqiSkinAltar.SEAL_SIZE * 0.6 > cr.position.x or p.x - XTianqiSkinAltar.SEAL_SIZE * 0.6 < XSkinLayout.margin_for(v.x) or p.y - 56 < XUiSkin.TOP - 24 or p.y + 56 > v.y:
			ok = false
	check("seals_inside_left", ok)
	var lab := page.ring_center() + Vector2.from_angle(deg_to_rad(page._deg(2))) * (XTianqiSkinAltar.RING_R + 92.0)
	check("labels_left_of_card", lab.x + 40 < cr.position.x, [lab, cr.position.x])
	check("buttons_in_card", page.button_rect(page.buttons.size() - 1).end.y <= cr.size.y - XUiSkin.PAD_LG + 0.5 and page.button_rect(0).position.y > 300, [page.button_rect(0), page.buttons.size()])
	check("hints_clear_version", page.hints.position.x + page.hints.total_width() <= XSkinMainMenu.hint_right(v) + 0.5)
	await shots("altar")
	page.select(2)
	await shots("altar_hei")
	page.toggle_rules()
	await shots("altar_rules")
	page.toggle_rules()
	if windowed():
		var win := get_window()
		var old := win.size
		win.size = Vector2i(1600, 720)
		await frames(10)
		var v2 := page.view()
		check("wide_margin_56", is_equal_approx(page.card_rect().end.x, v2.x - 56.0) and v2.x > 1500, [v2, page.card_rect()])
		win.size = old
		await frames(6)
	page.queue_free()
	await frames(2)


# ---- 接到流程 ----

func _wait_page(host: Node, max_frames := 120) -> XTianqiSkinAltar:
	for i in max_frames:
		for c in host.get_children():
			if c is XTianqiSkinAltar and not c.is_queued_for_deletion():
				return c
		await get_tree().process_frame
	return null


func _flow() -> void:
	var s := _state(33)
	var host := NodeHost.new()
	add_child(host)
	host.answers = [2]   # 揭印后「打满三场／直取／返回」或献的那一问：都选最后（返回）
	var done := {"v": false}
	var run := func():
		await XTianqiQiyin.run_altar(host, s)
		done.v = true
	run.call()
	var page := await _wait_page(host)
	check("flow_page_shown", page != null)
	if page == null:
		return
	check("flow_no_head_question", not host.asked.any(func(o): return o.has("离开")), host.asked)
	check("flow_sync_said", host.said.any(func(t): return str(t).contains("印钥")))   # 第一次开送印钥的话照旧
	page.select(2)   # 黑
	page.handle_input(_key("ui_accept"))
	page = await _wait_page(host)
	check("flow_back_to_page", page != null)
	var seal_labels: Array = XTianqiQiyin.seal_options(s).map(func(o): return o.label)
	check("flow_no_pick_seal", not host.asked.any(func(o): return o.has(seal_labels[0])), host.asked)
	check("flow_enter_hei", host.said.any(func(t): return str(t).contains(str(XTianqiQiyin.seal_info("hei").name))), host.said.slice(-4))
	check("flow_page_keeps_seal", page != null and page.index == 2)
	if page == null:
		return
	var keys_before := XTianqiQiyin.keys(s)
	page.handle_input(_key("ui_cancel"))
	for i in 60:
		if done.v:
			break
		await get_tree().process_frame
	check("flow_leave_home", done.v and host.moves.size() >= 2 and int(host.moves[-1][0]) == XTianqi.HALL_MAP, host.moves)
	check("flow_keys_untouched", XTianqiQiyin.keys(s) == keys_before)
	check("flow_said_leave", host.said.any(func(t): return str(t).contains(_line("leave"))), host.said.slice(-3))
	host.queue_free()
	await frames(2)


func _line(key: String) -> String:
	var rows := XTianqiQiyin.scene(key)
	return str(rows[0][1]) if not rows.is_empty() else "<none>"


func _flow_off() -> void:
	# 新界面关掉：照旧问对话框选单（第一个答案选「离开」）
	var s := _state(33)
	XUiSkin.ENABLED = false
	var host := NodeHost.new()
	add_child(host)
	host.answers = []   # 没给答案时选最后一项（离开）
	check("off_no_use", not XTianqiSkinAltar.use(host))
	await XTianqiQiyin.run_altar(host, s)
	check("off_head_question", host.asked.size() == 1 and (host.asked[0] as Array).has("离开") and (host.asked[0] as Array).has("揭印（进里副本）"), host.asked)
	check("off_no_page", not host.get_children().any(func(c): return c is XTianqiSkinAltar))
	XUiSkin.ENABLED = true
	host.queue_free()
	# 假宿主（不是 Node）：照旧
	check("fake_host_no_use", not XTianqiSkinAltar.use(RefCounted.new()))
	await frames(2)


# ---- #82 ----

func _set_item(s: XState, true_seal := true) -> Dictionary:
	return XTianqiQiyinEquip.give(s, XTianqiQiyinEquip.make({"kind": "set", "seal": "bai", "part": "head", "true_seal": true_seal, "grades": ["ji", "shangpin", "putong"]},
		"jianxian", XRandomStream.create("0123012301230123", "qiyin")))


func _gear_card() -> void:
	var s := _state(33)
	var it := _set_item(s)
	check("gear_made", XTianqiQiyinEquip.is_qiyin(it), it.keys())
	var d := XSkinItemPage.card_data(it)
	check("gear_subtitle", str(d.subtitle).begins_with("白印 · 七印套装 · 真印"), d.subtitle)
	check("gear_subtitle_quality", str(d.subtitle).contains(" · 神话"), d.subtitle)
	check("gear_grades", str(d.sections[0].rows[0].text) == "成色　极／上品／普通", d.sections[0])
	check("gear_no_quality_row", not d.sections.any(func(sec): return (sec.get("rows", []) as Array).any(func(r): return str(r.text).begins_with("品质："))), d.sections)
	check("gear_rows_kept", d.sections.size() >= 2 and not (d.sections[1].rows as Array).is_empty())
	var w := XTianqiQiyinEquip.give(s, XTianqiQiyinEquip.make({"kind": XTianqiQiyinDrop.KIND_WEAPON, "seal": "hong", "wtype": "剑", "true_seal": false, "grades": ["putong", "putong", "putong"]},
		"jianxian", XRandomStream.create("0123012301230123", "qiyin")))
	if XTianqiQiyinEquip.is_qiyin(w):
		var dw := XSkinItemPage.card_data(w)
		check("weapon_subtitle", str(dw.subtitle).begins_with("红印 · 七印毕业武器") and not str(dw.subtitle).contains("真印"), dw.subtitle)
	var art := XTianqiQiyinEquip.make_artifact(str(XTianqiQiyinDrop.artifact_keys()[0]))
	var da := XSkinItemPage.card_data(art)
	check("artifact_subtitle", str(da.subtitle).begins_with("七印神器"), da.subtitle)
	var plain := XSkinItemPage.card_data(XDB.rec("Weapons", 1))
	check("plain_gear_untouched", not str(plain.subtitle).contains("七印"), plain.subtitle)
	XUiSkin.ENABLED = false
	var off := XSkinItemPage.card_data(it)
	check("gear_off_untouched", not str(off.subtitle).contains("七印") and not str(off.sections[0].rows[0].text).begins_with("成色"), off.subtitle)
	XUiSkin.ENABLED = true


func _trumpet() -> void:
	var s := _state(33)
	var id := int(XTianqiTrumpet.scroll(1).item)
	s.gain_item(id, 2)
	var rec := XDB.rec("Items", id)
	check("trumpet_no", XTianqiSkinShow.trumpet_no(rec) == 1 and XTianqiSkinShow.trumpet_no(XDB.rec("Items", 1)) == 0)
	var d := XSkinItemPage.card_data(rec)
	check("trumpet_subtitle", d.subtitle == "号卷 · 第 1 卷 · 持有 2", d.subtitle)
	check("trumpet_lore", d.desc == str(XTianqiTrumpet.scroll(1).lore), d.desc)
	var texts: Array = []
	for sec in d.sections:
		for r in sec.get("rows", []):
			texts.append(str(r.text))
	check("trumpet_sweet_bitter", texts.any(func(t): return t.contains(str(XTianqiTrumpet.scroll(1).sweet))) and texts.any(func(t): return t.contains(str(XTianqiTrumpet.scroll(1).bitter))), texts)
	check("trumpet_limit_line", texts.any(func(t): return t.contains("弱者最多")), texts)
	check("trumpet_no_quality_row", not texts.any(func(t): return t.begins_with("品质：")), texts)
	check("trumpet_no_dup_intro", not texts.any(func(t): return t.begins_with("天启号卷")), texts)
	check("trumpet_no_dup_lore", not texts.any(func(t): return t.ends_with(str(XTianqiTrumpet.scroll(1).lore))), texts)
	var a: XActor = s.members()[0]
	var row := {"right": "", "right_color": XUiSkin.TEXT_3}
	XTianqiSkinShow.dress_target(rec, a, row)
	check("target_learned_count", row.right == "已学 0 / %d" % XTianqiTrumpet.limit(a), row)
	a.skill_ids.append(int(XTianqiTrumpet.scroll(1).skill))
	var row2 := {"right": "", "right_color": XUiSkin.TEXT_3}
	XTianqiSkinShow.dress_target(rec, a, row2)
	check("target_has", row2.right == "已学会", row2)
	XUiSkin.ENABLED = false
	var off := XSkinItemPage.card_data(rec)
	check("trumpet_off_untouched", not str(off.subtitle).begins_with("号卷"), off.subtitle)
	var row4 := {"right": "x", "right_color": XUiSkin.TEXT_3}
	XTianqiSkinShow.dress_target(rec, a, row4)
	check("target_off_untouched", row4.right == "x")
	XUiSkin.ENABLED = true


func _name_fit() -> void:
	var f := XUiSkin.font("body")
	var avail := 160.0
	var fit: Array = XSkinPartyStrip.name_fit(f, "窃格瓦拉·周的超长名字", 99, avail)
	var lv := f.get_string_size("Lv 99", HORIZONTAL_ALIGNMENT_LEFT, -1, XUiSkin.FS_AUX).x
	var nw := f.get_string_size(fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1]).x
	check("strip_name_keeps_lv", nw + 8 + lv <= avail + 0.5 and str(fit[0]).ends_with("…"), [fit, nw, lv])
	var short: Array = XSkinPartyStrip.name_fit(f, "修", 1, avail)
	check("strip_short_name_same", short == ["修", 18], short)


func _look() -> void:
	var s := _state(33)
	for part in XTianqiQiyinArt.PARTS:
		XConfig.tianqi_qiyin_part_mark("bai:%s" % part)
	var a: XActor = s.members()[0]
	check("look_wear", XTianqiQiyinLook.wear(s, a.actor_id, "bai"))
	check("look_strip", XSkinPartyStrip.from_actor(a).get("look") == "bai")
	check("look_other_none", XSkinPartyStrip.from_actor(s.members()[1]).get("look") == "")
	check("look_color", XTianqiSkinShow.look_color("bai") == XTianqiQiyinShow.seal_color("bai"))
	XUiSkin.ENABLED = false
	check("look_off", XSkinPartyStrip.from_actor(a).get("look") == "")
	XUiSkin.ENABLED = true


func _shots_82() -> void:
	if not windowed():
		return
	var s := _state(33)
	var it := _set_item(s)
	for part in XTianqiQiyinArt.PARTS:
		XConfig.tianqi_qiyin_part_mark("bai:%s" % part)
	XTianqiQiyinLook.wear(s, s.members()[0].actor_id, "bai")
	var id := int(XTianqiTrumpet.scroll(1).item)
	s.gain_item(id, 1)
	var page := XSkinTemplatePage.new()
	page.title = "物品"
	page.group_key = "items"
	page.show_ring = false
	page.columns = 1
	add_child(page)
	var strip := XSkinPartyStrip.new()
	strip.size = Vector2(page.left_w, 320)
	page.layout.left.add_child(strip)
	strip.set_members(s.members().map(func(a): return XSkinPartyStrip.from_actor(a)))
	page.set_items([{"text": XQuality.list_name(it), "icon": int(it.get("iconIndex", 0)), "color": XGear.color(it)}, {"text": str(XDB.rec("Items", id).name), "icon": int(XDB.rec("Items", id).get("iconIndex", 0))}], 0)
	page.set_card(XSkinItemPage.card_data(it))
	await shots("gear_card")
	page.set_items([{"text": XQuality.list_name(it), "icon": int(it.get("iconIndex", 0)), "color": XGear.color(it)}, {"text": str(XDB.rec("Items", id).name), "icon": int(XDB.rec("Items", id).get("iconIndex", 0))}], 1)
	page.set_card(XSkinItemPage.card_data(XDB.rec("Items", id)))
	await shots("trumpet_card")
	page.queue_free()
	await frames(2)
