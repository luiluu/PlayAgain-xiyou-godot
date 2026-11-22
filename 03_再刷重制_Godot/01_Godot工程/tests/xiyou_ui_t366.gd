extends Node
## T366 卡 H 零碎返修专项（R10～R12、R16～R20 与带进来的 P3）；开关 XSkinList.T366_V1。
## 无头：只跑断言；有窗口且带 -- --out=<目录> [--old] 时存图（--old＝开关关，拍改前画法）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []
var out_dir := ""
var old := false
var only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg == "--old":
			old = true
		elif arg.begins_with("--only="):
			only = arg.substr(7)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 3) -> void:
	for i in range(n):
		await get_tree().process_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func shot(name: String) -> void:
	if not windowed() or (only != "" and not name.begins_with(only)):
		return
	await frames(14)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ("_改前" if old else "_改后") + ".png"))


func _state() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.flags["tianqi"] = {"rules": 1}
	return s


func _run() -> void:
	TestEnv.isolate("xiyou_ui_t366")
	XUiSkin.FORCE = true
	XUiSkin.DETAIL_V1 = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XUiSkin.input_mode = XUiSkin.InputMode.KEYBOARD
	XSkinList.T366_V1 = not old
	if windowed():
		get_window().size = Vector2i(1280, 720)
	_pure()
	await _item()
	await _skill()
	await _status()
	await _menu()
	await _lines()
	await _title()
	await _altar()
	await _p3()
	await _book()
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	XUiSkin.input_mode = -1
	XSkinList.T366_V1 = true
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _potion() -> Dictionary:
	for id in range(1, 400):
		var rec := XDB.rec("Items", id)
		if rec.is_empty() or not bool(rec.get("consumable", false)) or int(rec.get("occasion", 0)) != 0:
			continue
		for e in rec.get("effects", []):
			if int(e.get("code", 0)) == 11 and int(rec.get("scope", 0)) == 7:
				return rec
	return {}


func _item() -> void:
	var s := _state()
	var rec := _potion()
	check("potion_found", not rec.is_empty())
	s.gain_item(int(rec.id), 5)
	for a in s.members():
		a.hp = maxi(1, int(a.mhp * 0.4))
	var page := XItemScene.new()
	add_child(page)
	await frames()
	page._cat = 1
	page._mode = "list"
	var es := page.entries()
	for i in es.size():
		if int(es[i].rec.id) == int(rec.id):
			page._index = i
	page._refresh()
	await shot("R10_物品页_给谁用")
	if page.skin != null:
		var y_on: float = page.skin.targets.position.y
		XSkinList.T366_V1 = false
		page.skin._place_targets()
		var y_off: float = page.skin.targets.position.y
		XSkinList.T366_V1 = not old
		page.skin._place_targets()
		check("r10_targets_up", y_on < y_off - 20.0 or old, [y_on, y_off])
	# R16：背包里有没看过的东西，光标停在别处，看「新」标记（物品页消耗品＋武器）
	var s2 := XState.current
	for id in range(1, 60):
		var r2 := XDB.rec("Items", id)
		if not r2.is_empty() and bool(r2.get("consumable", false)) and int(r2.id) != int(rec.id) and XItemRow.new_tracked(r2):
			s2.gain_item(id, 2)
			break
	page._index = 0
	page._refresh()
	var es2 := page.entries()
	check("item_list_has_new", es2.any(func(d): return XItemRow.shows_new(s2, d.rec)), es2.size())
	page._cat = 2
	page._index = 0
	page._refresh()
	await shot("R16_物品页_武器列表新标记")
	page.queue_free()
	await frames()


## 技能页：找一个选中后用不了的技能（战斗专用／消耗不足），选中它
func _skill() -> void:
	var s := _state()
	var page := XSkillScene.new()
	add_child(page)
	await frames()
	var pick := -1
	var ti := 0
	for t in page.types().size():
		page.type_index = t
		page.index = 0
		page._refresh()
		var es := page.entries()
		for i in es.size():
			if not page.usable(es[i]):
				pick = i
				ti = t
				break
		if pick >= 0:
			break
	check("skill_has_unusable", pick >= 0)
	page.type_index = ti
	page.mode = "list"
	page.index = maxi(pick, 0)
	page._refresh()
	if page.skin != null and pick >= 0:
		var row: Dictionary = page.skin.list.items[page.skin.list.index]
		check("r12_row_has_reason", bool(row.disabled) and str(row.get("reason", "")) != "" or old, row)
		check("r12_reason_fixed_text", page.skin.skill_reason(page.actor(), page.entries()[pick]) != "", page.entries()[pick].get("name"))
	await shot("R12_技能页_选中用不了的行")
	page.queue_free()
	await frames()


func _status() -> void:
	_state()
	var p := XStatusPage.new()
	add_child(p)
	await frames()
	await shot("R11_状态页_第1页")
	p.set_page(1)
	await frames()
	await shot("R11_状态页_第2页")
	p.set_page(0)
	XFontScale.set_value("global", 130)
	p.skin.sync()
	await frames()
	await shot("R11_状态页_字体130")
	XFontScale.set_value("global", 100)
	p.queue_free()
	await frames()


func _menu() -> void:
	_state()
	var m := XMenu.new()
	add_child(m)
	await frames()
	var sk: XSkinMainMenu = m.skin
	for k in sk.groups.size():
		if str(sk.groups[k].key) == "actor":
			sk.gi = k
	sk.level = 1
	sk.refresh()
	await shot("R19_主菜单")
	m.queue_free()
	await frames()


func _lines() -> void:
	_state()
	var page := XTianqiLineCards.new()
	page.set("lines", XTianqi.LINES)
	page.set("playable", [true, true, false, true])
	add_child(page)
	await frames(30)
	page.set_process(false)
	page.set("_t", 0.0)
	page.call("_process", 0.0)
	var cards: Array = page.get("_cards")
	if cards.size() >= 3 and not old:
		var c3: Control = cards[2]
		check("r17_closed_card_dim", is_equal_approx(c3.modulate.r, 0.45) and is_equal_approx((cards[1] as Control).modulate.r, XTianqiLineCards.UNSELECTED.r), [c3.modulate, (cards[1] as Control).modulate])
	await shot("R17_选线卡")
	page.queue_free()
	await frames()


func _title() -> void:
	_state()
	var noop := func(): pass
	var t := XTianqiTitle.new()
	t.setup({"new_game": noop, "load": noop, "options": noop, "achievements": noop, "check_update": noop, "back_to_menu": noop}, [])
	add_child(t)
	var b := Button.new()
	b.name = "ContinueAuto"
	b.text = "继续（切后台时自动存的档）"
	b.position = Vector2(8, 8)
	b.size = Vector2(280, 40)
	b.add_theme_font_size_override("font_size", 16)
	b.focus_mode = Control.FOCUS_NONE
	t.extras.add_child(b)
	await frames(40)
	t.call("_layout")
	if not old:
		var bb: Button = t.back_button
		var sbx := bb.get_theme_stylebox("normal") as StyleBoxFlat
		check("r18_capsule_radius", sbx != null and sbx.corner_radius_top_left >= int(bb.size.y / 2.0) - 1, [sbx.corner_radius_top_left if sbx != null else -1, bb.size])
		var cb: Button = t.extras.get_node("ContinueAuto")
		check("r18_continue_capsule", (cb.get_theme_stylebox("normal") as StyleBoxFlat).corner_radius_top_left >= int(cb.size.y / 2.0) - 1)
	await shot("R18_标题页角钮")
	t.queue_free()
	await frames()


func _altar() -> void:
	var lineup: Array = XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 5)
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
	XTianqiSkinAltar.last_seal = ""
	XTianqiQiyin.sync(s)
	var opts := XTianqiQiyin.altar_options(s)
	var a := XTianqiSkinAltar.new()
	a.setup(s, opts)
	add_child(a)
	await frames(20)
	if not old:
		var rows_b: Array = a.btn_rows()
		var ids: Array = a.buttons.map(func(b): return str(b.id))
		check("r20_rows", rows_b.size() == ids.size() - 1 and (rows_b[rows_b.size() - 1] as Array).size() == 2, [ids, rows_b])
		var r2: Rect2 = a.button_rect((rows_b[rows_b.size() - 1] as Array)[0])
		var r3: Rect2 = a.button_rect((rows_b[rows_b.size() - 1] as Array)[1])
		check("r20_pair_same_row", is_equal_approx(r2.position.y, r3.position.y) and r3.position.x > r2.end.x and r2.size.y < a.button_rect(0).size.y, [r2, r3])
		a.button = 1
		a.step_button(1)
		check("r20_down_to_pair", a.button == (rows_b[rows_b.size() - 1] as Array)[0], a.button)
		a.step_button(1)
		check("r20_down_wraps", a.button == 0, a.button)
	await shot("R20_七印祭坛")
	a.queue_free()
	await frames()


## 不用窗口的纯函数／状态断言
func _pure() -> void:
	check("switch_default_on", XSkinList.T366_V1 == true or old)
	# R11 短名：开＝去掉「率」，关＝原名；别的名字不动
	XSkinList.T366_V1 = true
	check("r11_short_on", XSkinStatusPage.short_name("生命自动回复率") == "生命自动回复" and XSkinStatusPage.short_name("能量自动回复率") == "能量自动回复" and XSkinStatusPage.short_name("暴击率") == "暴击率")
	XSkinList.T366_V1 = false
	check("r11_short_off", XSkinStatusPage.short_name("生命自动回复率") == "生命自动回复率")
	# R19 行高
	check("r19_row_off", XSkinMainMenu.row_item() == XSkinMainMenu.ROW_ITEM)
	XSkinList.T366_V1 = true
	check("r19_row_on", XSkinMainMenu.row_item() == 72.0)
	# T367 P3：净化确认正文补两句
	var spec := XSkinAlienWorkshop.ask_spec("使用1颗异化石净化", "测试装备")
	check("t367_purify_body", str(spec.get("body", "")).contains("会用掉 1 颗异化石") and str(spec.body).contains("装备保留"), spec)
	XSkinList.T366_V1 = not old


func _p3() -> void:
	var s := _state()
	# 取消键归弹窗：弹窗开着时底层返回钮不亮环
	var host := Control.new()
	add_child(host)
	var back := XSkinBackButton.new()
	host.add_child(back)
	await frames()
	check("p3_back_not_covered", not back._covered_by_dialog())
	var dlg := XSkinConfirm.open(host, {"title": "x", "body": "y", "buttons": ["好", "取消"]})
	await frames()
	check("p3_back_covered", back._covered_by_dialog())
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	back._input(ev)
	check("p3_back_no_ring_under_dialog", not back.focused)
	dlg.free()
	await frames()
	check("p3_back_uncovered_after", not back._covered_by_dialog())
	host.queue_free()
	await frames()
	# T367 P3：有异化核、没有能刻的装备＝整节一句空状态（不再是空下拉）
	var w := XAlienWorkshop.new()
	var tq := XTianqi.start_new_game(3, "jianxian", XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 4))
	XTianqi.take_pending()
	XState.current = tq
	tq.flags.tianqi["line"] = "plague"
	XTianqiAlienGear.add_core(tq, "plague", "insulation", "shigu", "test")
	add_child(w)
	await frames()
	var sec: Dictionary = w._core_section(tq, 0)
	var kinds: Array = (sec.children as Array).map(func(k): return str(k.tag))
	check("t367_core_empty_no_select", not kinds.has("label") and not kinds.has("select") and (sec.children as Array).any(func(k): return str(k.get("class", "")) == "alien-note"), kinds)
	w.queue_free()
	await frames()


## T364 P3：怪物图鉴（能力格行高随 130%、备注超 4 行可滚）。找一只备注最长的已登记怪
func _book() -> void:
	var s := _state()
	var best := 0
	var best_n := 0
	for id in XEnemyBook.ids():
		var n := str(XDB.rec("Enemies", int(id)).get("note", "")).length()
		if n > best_n:
			best_n = n
			best = int(id)
	XEnemyBook.add(s, best)
	var b := XEnemyBookPage.new()
	add_child(b)
	await frames(3)
	b.select(b.ids.find(best))
	await frames(6)
	var sk = b.get("skin")
	check("book_built", sk != null)
	if sk != null:
		await shot("T364_怪物图鉴_备注")
		XFontScale.set_value("global", 130)
		b.select(b.ids.find(best))
		await frames(6)
		await shot("T364_怪物图鉴_字体130")
		check("book_cell_h_130", XSkinBookPage.cell_h() > XSkinBookPage.CELL_H, XSkinBookPage.cell_h())
		XFontScale.set_value("global", 100)
		check("book_cell_h_100", XSkinBookPage.cell_h() == XSkinBookPage.CELL_H, XSkinBookPage.cell_h())
		# 备注超过 4 行：塞一份长备注，看能滚、滚了内容变
		var long_note := []
		for i in 9:
			long_note.append("第 %d 条：远古就存在的奇异种族，他们生活在平原之上，大多都粗野，狂暴，不讲道理。" % (i + 1))
		sk.info.note = long_note
		sk.right_panel.queue_redraw()
		await frames(4)
		if not old:
			check("book_note_scrolls", sk._note_max > 0.0, sk._note_max)
		await shot("T364_怪物图鉴_备注超4行")
		sk.scroll_note(sk._note_max)
		await frames(3)
		if not old:
			check("book_note_scrolled_to_end", is_equal_approx(sk.note_scroll, sk._note_max), [sk.note_scroll, sk._note_max])
		await shot("T364_怪物图鉴_备注滚到底")
	b.queue_free()
	await frames()
