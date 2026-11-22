extends Node
## T367 专项（T254 R8、卡 F）：异化工坊套模板页补齐（XAlienWorkshop.LAYOUT_V3，画法 ui/skin/skin_alien_workshop.gd）。
## - 页名白字；四个页签（异化装备、异化核、装备重铸、本线图鉴）；
## - 分解、取核、重抽、净化、刻到有词条的装备都先弹统一确认弹窗（XSkinConfirm：danger、光标停在「取消」），详情里不再嵌确认框；
##   取消键关弹窗、不动存档；确定才做；
## - 空列表：列表区正中一句 19 号 TEXT_3，右牌照旧「如何获得」；
## - 异化核、装备重铸：下拉框换成左列表（当前那件红乙选中），点一下换件，右牌是其余内容；
## - 旧页每项新页都取得到：节点树里每个有字的节点（含下拉选项、确认框）在新页某一页签或弹窗里都找得到；
## - 20:9（1600 宽）：左列表贴安全边、详情不出右安全边；
## - 回退 LAYOUT_V3 = false：页名旧金、确认框嵌回详情、下拉框回来；新皮肤关：旧画法、没有弹窗。
const TestEnv = preload("res://tests/xiyou_test_env.gd")

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func _tq_state(line := "plague") -> XState:
	var ids := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id)).slice(0, 4)
	var s := XTianqi.start_new_game(3, "jianxian", ids)
	XTianqi.take_pending()
	for id in ids:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
	return s


## 满配：一件异化护甲、一颗核、一件能刻的护甲、一件能重铸的武器、3 颗异化石、钱够
func _full_state() -> XState:
	var s := _tq_state()
	s.gain_item(XAlienation.stone_id(), 3)
	s.gold = 500000
	var i: Dictionary = XTianqiAlienGear.create(s, "armor", 52, "plague", "huaxing", "mimic").ok
	s.gear.append(i)
	XTianqiAlienGear.add_core(s, "plague", "insulation", "shigu", "test")
	s.gain_gear("armor", 53, 1)
	var wid := 0
	for r in XDB.table("Weapons"):
		if wid == 0 and r is Dictionary and str(r.get("name", "")) != "":
			var tpl := XGear.template("weapon", int(r.id))
			if XQuality.grade(tpl) == 6 and XTianqiAffixRoll.tier_of(tpl) == 4 and not XEquipment.is_exclusive(tpl):
				wid = int(r.id)
	var it := XGear.create("weapon", wid, s)
	XTianqiAffixRoll.set_affixes(it, [{"key": str(XTianqiAffixRoll.layer_candidates(it, "base")[0]), "tier": 4, "grade": "normal", "extra": {}},
		{"key": str(XTianqiAffixRoll.layer_candidates(it, "special")[0]), "tier": 4, "grade": "normal", "extra": {}}])
	s.register_gear(it)
	s.gear.append(it)
	return s


func _all(n: Node, pred: Callable, out := []) -> Array:
	for c in n.get_children():
		if pred.call(c):
			out.append(c)
		_all(c, pred, out)
	return out


func _open(host: Node = null) -> XAlienWorkshop:
	XAlienWorkshop.selected = ""
	var ws := XAlienWorkshop.new()
	ws.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(host if host != null else self).add_child(ws)
	await frames(4)
	return ws


func _btn(ws: Node, pred: Callable) -> Button:
	var hit := _all(ws, func(c): return c is Button and c.is_visible_in_tree() and pred.call(c))
	return hit[0] if not hit.is_empty() else null


func _key(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await frames(3)


func _goto_tab(ws: XAlienWorkshop, prefix: String) -> bool:
	for i in ws.skin_tabs.size():
		if str(ws.skin_tabs[i][0]).begins_with(prefix):
			ws.skin_tab = i
			ws._skin_tab_name = str(ws.skin_tabs[i][0])
			ws.render(true)
			await frames(3)
			return true
	return false


func _run() -> void:
	TestEnv.isolate("xiyou_t367_workshop")
	XMessageBox.auto = true
	XConfig.ensure_loaded()
	XConfig._values["codexUiSkin"] = true
	XUiSkin.ENABLED = true
	check("v3_default_on", XAlienWorkshop.LAYOUT_V3)
	await _tabs_and_title()
	await _dismantle_dialog()
	await _reroll_dialog()
	await _core_dialog_and_purify()
	await _empty_list()
	await _core_tab()
	await _reforge_tab()
	await _parity()
	await _wide()
	await _rollback()
	await _skin_off()
	XState.current = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _tabs_and_title() -> void:
	_full_state()
	var ws := await _open()
	var names: Array = ws.skin_tabs.map(func(x): return str(x[0]))
	check("tabs_four", names.size() == 4 and names[0] == "异化装备" and names[1].begins_with("异化核") and names[2] == "装备重铸" and names[3].begins_with("本线异化图鉴"), names)
	var head: Node = _all(ws, func(c): return c.name == "SkinHeader").front()
	var title: Label = _all(head, func(c): return c is Label and c.text == "异化工坊").front()
	check("title_white", title.label_settings.font_color == XUiSkin.TEXT, title.label_settings.font_color)
	check("title_page_size", title.label_settings.font_size == XUiSkin.FS_PAGE)
	ws.queue_free()
	await frames(2)


func _dismantle_dialog() -> void:
	var s := _full_state()
	var ws := await _open()
	var n0 := s.gear.filter(func(e): return XTianqiAlienGear.is_tq(e)).size()
	var dis := _btn(ws, func(b): return b.text.begins_with("分解为"))
	dis.pressed.emit()
	await frames(4)
	var dlg := ws.skin_dialog()
	check("dismantle_dialog", dlg != null and dlg.danger and ws.confirming)
	check("dismantle_cursor_cancel", dlg != null and dlg.index == 1 and str(dlg.buttons[1].text) == "取消", dlg.buttons if dlg else null)
	check("dismantle_title", dlg != null and dlg.title.begins_with("分解 ") and dlg.title.ends_with("？") and dlg.body.contains("全部销毁"), [dlg.title, dlg.body] if dlg else null)
	check("dismantle_not_inline", _btn(ws.root, func(b): return b.text == "确认分解") == null)
	check("dismantle_tree_same", XAlienWorkshop.flatten(ws.tree).any(func(r): return str(r.get("text", "")) == "确认分解"))
	check("dismantle_focus_released", not (get_viewport().gui_get_focus_owner() is Button))
	# 取消键：关弹窗、确认状态清掉、东西还在
	await _key("ui_cancel")
	check("dismantle_cancel", ws.skin_dialog() == null and not ws.confirming and s.gear.filter(func(e): return XTianqiAlienGear.is_tq(e)).size() == n0)
	check("cancel_not_close_page", is_instance_valid(ws) and ws.is_inside_tree())
	# 再按一次，光标挪到「分解」确定
	dis = _btn(ws, func(b): return b.text.begins_with("分解为"))
	dis.pressed.emit()
	await frames(4)
	await _key("ui_left")
	check("dismantle_cursor_moved", ws.skin_dialog() != null and ws.skin_dialog().index == 0)
	await _key("ui_accept")
	check("dismantle_done", s.gear.filter(func(e): return XTianqiAlienGear.is_tq(e)).size() == n0 - 1 and not ws.confirming and ws.skin_dialog() == null)
	ws.queue_free()
	await frames(2)


func _reroll_dialog() -> void:
	var s := _full_state()
	var ws := await _open()
	var stones := s.item_count(XAlienation.stone_id())
	var rr := _btn(ws, func(b): return b.text.begins_with("使用1颗异化石重抽"))
	rr.pressed.emit()
	await frames(3)
	var dlg := ws.skin_dialog()
	check("reroll_dialog", dlg != null and dlg.danger and dlg.index == 1 and dlg.title.contains("重抽"), [dlg.title, dlg.index] if dlg else null)
	dlg.activate(1)   # 取消
	await frames(3)
	check("reroll_cancel_kept", ws.skin_dialog() == null and s.item_count(XAlienation.stone_id()) == stones and XAlienation.ledger(s).pending == null)
	rr = _btn(ws, func(b): return b.text.begins_with("使用1颗异化石重抽"))
	rr.pressed.emit()
	await frames(3)
	ws.skin_dialog().activate(0)
	await frames(4)
	check("reroll_done", s.item_count(XAlienation.stone_id()) == stones - 1 and XAlienation.ledger(s).pending != null and ws.skin_dialog() == null)
	# 待选两张卡：不是毁东西的操作，直接点（不弹窗）
	var keep := _btn(ws, func(b): return b.text == "保留旧异化")
	keep.pressed.emit()
	await frames(4)
	check("pending_no_dialog", ws.skin_dialog() == null and XAlienation.ledger(s).pending == null)
	ws.queue_free()
	await frames(2)


func _core_dialog_and_purify() -> void:
	var s := _full_state()
	var ws := await _open()
	var core := _btn(ws, func(b): return b.text == "取核")
	core.pressed.emit()
	await frames(4)
	var dlg := ws.skin_dialog()
	check("core_dialog", dlg != null and dlg.danger and ws.confirming_core and dlg.title.begins_with("取核 ") and str(dlg.buttons[0].text) == "取核", [dlg.title, dlg.buttons] if dlg else null)
	dlg.cancelled.emit()
	await frames(3)
	check("core_cancel", ws.skin_dialog() == null and not ws.confirming_core)
	var pu := _btn(ws, func(b): return b.text.begins_with("使用1颗异化石净化"))
	pu.pressed.emit()
	await frames(3)
	dlg = ws.skin_dialog()
	check("purify_dialog", dlg != null and dlg.danger and dlg.index == 1 and dlg.title.begins_with("净化"), [dlg.title] if dlg else null)
	dlg.cancelled.emit()
	await frames(3)
	check("purify_cancel_kept", ws.skin_dialog() == null and s.gear.any(func(e): return XTianqiAlienGear.is_tq(e) and not XAlienation.mark(e).is_empty()))
	ws.queue_free()
	await frames(2)


func _empty_list() -> void:
	_tq_state()
	var ws := await _open()
	var lst: Node = _all(ws, func(c): return c.name == "SkinList").front()
	var em: Array = _all(lst, func(c): return c.name == "SkinEmpty")
	check("empty_label", em.size() == 1 and (em[0] as Label).text == "尚未获得异化装备。", em.map(func(l): return l.text))
	if not em.is_empty():
		var ls: LabelSettings = (em[0] as Label).label_settings
		check("empty_style", ls.font_color == XUiSkin.TEXT_3 and ls.font_size == XUiSkin.fs(19) and (em[0] as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	var dp: Node = _all(ws, func(c): return c.name == "SkinDetail").front()
	check("empty_guide_kept", not _all(dp, func(c): return c is Label and c.text == "如何获得异化装备").is_empty())
	# 空的异化核页（没有核）：整块一句空状态
	check("empty_core_tab", await _goto_tab(ws, "异化核"))
	var ce: Array = _all(ws, func(c): return c.name == "SkinSectionEmpty")
	check("empty_core_one_line", ce.size() == 1 and not _all(ce[0], func(c): return c.name == "SkinEmpty" and c.text.contains("异化核")).is_empty())
	ws.queue_free()
	await frames(2)


func _core_tab() -> void:
	var s := _full_state()
	var plain: Dictionary = s.gear.filter(func(e): return int(e.get("base", 0)) == 53 and str(e.get("kind", "")) == "armor")[0]
	var ws := await _open()
	check("core_tab", await _goto_tab(ws, "异化核"))
	var lst: Array = _all(ws, func(c): return c.name == "SkinList")
	check("core_list", lst.size() == 1 and _all(ws, func(c): return c is OptionButton).is_empty())
	var opts: Array = XTianqiAlienGear.engrave_targets(s)
	var rows: Array = _all(lst[0], func(c): return c is Button)
	check("core_list_rows", rows.size() == opts.size() and rows.size() >= 2, [rows.size(), opts.size()])
	var cur: Array = rows.filter(func(b): return b.has_meta("current"))
	check("core_list_current", cur.size() == 1 and cur[0].get_theme_stylebox("normal") is XSkinSelectStyle)
	check("core_list_title", not _all(lst[0], func(c): return c is Label and c.text == "刻到哪件").is_empty())
	check("core_focus_current", get_viewport().gui_get_focus_owner() == cur[0] if not cur.is_empty() else false)
	# 点另一件：选中跟过去
	var other: Button = rows.filter(func(b): return b.text == str(plain.name))[0]
	other.pressed.emit()
	await frames(4)
	check("core_pick", str(ws.cfg_vals.get("engrave")) == str(plain.instanceId))
	var dp: Node = _all(ws, func(c): return c.name == "SkinDetail").front()
	check("core_card_engrave", _btn(dp, func(b): return b.text == "刻上（1颗异化石）") != null)
	# 刻到已有词条的那件：先弹确认
	var alien: Dictionary = s.gear.filter(func(e): return XTianqiAlienGear.is_tq(e) and not XAlienation.mark(e).is_empty())[0]
	if check("engrave_alien_listed", _all(ws, func(c): return c is Button and c.text == str(alien.name)).size() > 0):
		ws.set_value("engrave", str(alien.instanceId))
		await frames(4)
		_btn(ws, func(b): return b.text == "刻上（1颗异化石）").pressed.emit()
		await frames(3)
		var dlg := ws.skin_dialog()
		check("engrave_replace_dialog", dlg != null and dlg.danger and dlg.title.contains(str(alien.name)), [dlg.title] if dlg else null)
		dlg.cancelled.emit()
		await frames(3)
		check("engrave_replace_cancel", XTianqiAlienGear.cores(s).size() == 1)
	# 刻到没词条的：直接刻
	ws.set_value("engrave", str(plain.instanceId))
	await frames(4)
	_btn(ws, func(b): return b.text == "刻上（1颗异化石）").pressed.emit()
	await frames(4)
	check("engrave_plain_direct", ws.skin_dialog() == null and XTianqiAlienGear.cores(s).is_empty() and str(XTianqiAlienGear.tq(plain).get("level", "")) == "shigu")
	ws.queue_free()
	await frames(2)


func _reforge_tab() -> void:
	var s := _full_state()
	var ws := await _open()
	check("reforge_tab", await _goto_tab(ws, "装备重铸"))
	var lst: Array = _all(ws, func(c): return c.name == "SkinList")
	var rows: Array = _all(lst[0], func(c): return c is Button) if not lst.is_empty() else []
	check("reforge_list_rows", rows.size() == XTianqiReforge.targets(s).size() and rows.size() >= 1, rows.size())
	var dp: Node = _all(ws, func(c): return c.name == "SkinDetail").front()
	var g0 := s.gold
	var rf := _btn(dp, func(b): return b.text.begins_with("重铸第1条"))
	check("reforge_card_btn", rf != null)
	if rf != null:
		rf.pressed.emit()
		await frames(4)
		check("reforge_direct", ws.skin_dialog() == null and s.gold < g0)
	ws.queue_free()
	await frames(2)


## 屏上（各页签＋弹窗）能读到的字，去掉折行
func _screen_texts(ws: XAlienWorkshop) -> Dictionary:
	var out := {}
	for c in _all(ws, func(c): return (c is Label or c is Button) and c.is_visible_in_tree()):
		out[str(c.text).replace("\n", "")] = true
		for k in str(c.text).split("　"):
			out[k] = true
	for c in _all(ws, func(c): return c is OptionButton):
		for i in (c as OptionButton).item_count:
			out[(c as OptionButton).get_item_text(i)] = true
	var dlg := ws.skin_dialog()
	if dlg != null:
		out[dlg.title] = true
		out[dlg.body] = true
		for b in dlg.buttons:
			out[str(b.text)] = true
	return out


func _found(text: String, seen: Dictionary) -> bool:
	if seen.has(text) or text == "返回":   # 「返回」框换成左上「‹」（T361）
		return true
	if text.begins_with("确认") and text.length() > 2:   # 确认框标题／钮：弹窗里写成「分解 X？」「分解」
		var rest := text.substr(2)
		for k in seen:
			if str(k).begins_with(rest):
				return true
	for k in seen:   # 页签名去掉了括号里的数（重画时按名字留住），按前缀认
		if str(k).length() > 2 and text.begins_with(str(k).get_slice("（", 0)) and str(k).contains("（") == text.contains("（"):
			return true
	return false


func _parity() -> void:
	var s := _full_state()
	XAlienation.ledger(s).recent.append({"name": "测试异化甲", "origin": "mob"})
	for mode in ["plain", "dismantle", "core"]:
		var ws := await _open()
		if mode == "dismantle":
			_btn(ws, func(b): return b.text.begins_with("分解为")).pressed.emit()
			await frames(4)
		elif mode == "core":
			_btn(ws, func(b): return b.text == "取核").pressed.emit()
			await frames(4)
		var want := []
		for r in XAlienWorkshop.flatten(ws.tree):
			if r.has("text") and not r.get("hidden", false):
				want.append(str(r.text))
			if r.has("options"):
				want.append_array(r.options)
		var seen := {}
		var dlg_seen := _screen_texts(ws)
		seen.merge(dlg_seen)
		for i in ws.skin_tabs.size():
			ws.skin_tab = i
			ws._skin_tab_name = str(ws.skin_tabs[i][0])
			ws.render(true)
			await frames(3)
			seen.merge(_screen_texts(ws))
		var miss := want.filter(func(t): return not _found(t, seen))
		check("parity_%s" % mode, miss.is_empty() and want.size() > 10, miss)
		ws.queue_free()
		await frames(2)


func _wide() -> void:
	_full_state()
	var host := Control.new()
	host.size = Vector2(1600, 720)
	add_child(host)
	var ws := await _open(host)
	var m := XSkinLayout.margin_for(1600)
	var lp: Control = _all(ws, func(c): return c.name == "SkinList").front()
	var dp: Control = _all(ws, func(c): return c.name == "SkinDetail").front()
	check("wide_list_left", is_equal_approx(lp.position.x, m), [lp.position, m])
	check("wide_detail_right", dp.position.x + dp.size.x <= 1600 - m + 0.5 and dp.position.x > lp.position.x + lp.size.x, [dp.position, dp.size])
	host.queue_free()
	await frames(2)


func _rollback() -> void:
	XAlienWorkshop.LAYOUT_V3 = false
	_full_state()
	var ws := await _open()
	var head: Node = _all(ws, func(c): return c.name == "SkinHeader").front()
	var title: Label = _all(head, func(c): return c is Label and c.text == "异化工坊").front()
	check("rb_title_gold", title.label_settings.font_color == XUiSkin.GOLD)
	_btn(ws, func(b): return b.text.begins_with("分解为")).pressed.emit()
	await frames(4)
	check("rb_inline_confirm", ws.skin_dialog() == null and _btn(ws.root, func(b): return b.text == "确认分解") != null)
	ws._cancel_confirm()
	await frames(3)
	_btn(ws, func(b): return b.text.begins_with("使用1颗异化石重抽")).pressed.emit()
	await frames(4)
	check("rb_reroll_direct", ws.skin_dialog() == null and XAlienation.ledger(XState.current).pending != null)
	ws.queue_free()
	await frames(2)
	_full_state()
	ws = await _open()
	await _goto_tab(ws, "异化核")
	check("rb_core_select", not _all(ws, func(c): return c is OptionButton).is_empty())
	ws.queue_free()
	XAlienWorkshop.LAYOUT_V3 = true
	await frames(2)


func _skin_off() -> void:
	_full_state()
	XUiSkin.ENABLED = false
	var ws := await _open()
	check("off_old", not ws.skin and ws.skin_dialog() == null and _all(ws, func(c): return c is PanelContainer and c.get_theme_stylebox("panel") is XAlienWorkshop.PaneFrame).size() > 0)
	var dis := _btn(ws, func(b): return b.text.begins_with("分解为"))
	dis.pressed.emit()
	await frames(4)
	check("off_inline_confirm", ws.skin_dialog() == null and _btn(ws, func(b): return b.text == "确认分解") != null)
	ws.queue_free()
	XUiSkin.ENABLED = true
	await frames(2)
