extends Node
## 【cc·天启篇】新界面 2B 专项：右侧队伍条（XSkinSideStatus）、行动顺序（XSkinOTBBar）、首领血弧（XSkinBossArc）与状态胶囊／详情
## （XSkinBossStatus）、我方状态详情（XSkinPartyStatusPanel），以及开关关着时 XSkinBattle 都给原来的类。
## 同 xiyou_ui_skin_battle 的场面（地图 5、敌群 2、队伍 8/9/10、美娜先手），XUiSkin.FORCE 强开；首领是把第一只敌人换成名单里的 6 号。
## 内存新游戏，不写存档。窗口模式加 -- --out=<目录> 截图；再加 --wide 时整窗改 1600×720＋KEEP_HEIGHT。

const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
var results := []
var out_dir := ""
var wide := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		if arg == "--wide":
			wide = true
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _until(cond: Callable, n := 900) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(20)
	RenderingServer.force_draw(false)
	var suffix := "_20x9" if wide else "_16x9"
	_check("screenshot_" + name + suffix, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + suffix + ".png")) == OK)


func _battle(map: XMapScene) -> XBattleScene:
	for c in map.ui.get_children():
		if c is XBattleScene:
			return c
	return null


## 有回合数、有图标、有名字的状态（给首领挂一个看胶囊）
func _timed_state(kind: String) -> int:
	for st in XDB.table("States"):
		if not (st is Dictionary) or st.is_empty():
			continue
		var id := int(st.get("id", 0))
		if id <= 1 or int(st.get("iconIndex", 0)) <= 0 or int(st.get("autoRemovalTiming", 0)) <= 0 or str(st.get("name", "")) == "":
			continue
		if str(st.get("name", "")).length() > 6 or XBossStatus.kind_of(st) != kind:
			continue
		return id
	return 0


func _run() -> void:
	if wide and DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1600, 720)
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
		await _frames(5)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	seed(20261013)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = "2026101300000001"
	s.gain_item(1, 5)
	s.actor(10).change_level_mv(10)
	s.actor(10).equips[0] = XGear.create("weapon", 14)
	s.actor(10).refresh_passive()
	s.map_id = 5
	s.x = 10
	s.y = 10
	s.direction = 2
	get_tree().change_scene_to_file(MAP_SCENE)
	var ok := await _until(func(): return get_tree().current_scene is XMapScene and get_tree().current_scene.player != null and not get_tree().current_scene.busy)
	_check("map5_loaded", ok)
	var map: XMapScene = get_tree().current_scene
	await _frames(10)
	XMessageBox.auto = false
	map._set_busy(true)
	var go := func(): await map.start_battle(2, true, false)
	go.call()
	ok = await _until(func(): return _battle(map) != null and _battle(map).cmd_win != null)
	_check("command_shown", ok)
	var b: XBattleScene = _battle(map)
	if b == null:
		_finish()
		return
	await _frames(30)
	var a: XActor = b._active
	_check("fixture_actor", a == s.actor(10), null if a == null else a.actor_id)
	_party(b, a)
	_check("toggles_moved", b.auto_btn.get_parent().position == b._origin + XSkinBattle.TOGGLE_POS and b.auto_btn.custom_minimum_size == Vector2(104, 40), b.auto_btn.get_parent().position)
	_otb(b, a)
	await _boss(b)
	await _shot("battle_2b_hud")
	await _boss_detail(b)
	await _status_panel(b, a)
	await _party_click(b, a)
	_boss_no_arc(b)
	await _skin_off(b)
	_finish()


## ---- 右侧队伍条 ----
func _party(b: XBattleScene, a: XActor) -> void:
	var rows: Array = b.logic.actors.map(func(m): return b.status_rows.get(m))
	_check("party_rows_skin", rows.all(func(r): return r is XSkinSideStatus), rows.map(func(r): return r.get_class() if r else null))
	var holder: Node = rows[0].get_parent()
	var backs := holder.get_children().filter(func(c): return c is XSkinSideStatus.Back)
	_check("party_backdrop", backs.size() == 1 and backs[0].count == rows.size() and backs[0].get_index() < rows[0].get_index(), backs.size())
	if not backs.is_empty():
		var bk: Control = backs[0]
		_check("party_backdrop_rect", bk.position == Vector2(1280 - 16 - 290, 12) and bk.size == Vector2(290, rows.size() * 58 + 4), [bk.position, bk.size])
	for i in rows.size():
		var r: XSkinSideStatus = rows[i]
		_check("party_row_pos_%d" % i, r.position == XSkinSideStatus.row_pos(i) and r.size == Vector2(290, 58), [r.position, r.size])
		_check("party_row_button_%d" % i, r.cell_button.position == Vector2.ZERO and r.cell_button.size == r.size, [r.cell_button.position, r.cell_button.size])
	var ra: XSkinSideStatus = b.status_rows[a]
	_check("party_active_flag", ra.active and rows.filter(func(r): return r.active).size() == 1)
	_check("party_active_no_shift", ra.position.x == XSkinSideStatus.panel_x(), ra.position)
	_check("party_right_edge", ra.position.x + ra.size.x == 1280 - XSkinSideStatus.RIGHT)
	var info := ra.info_text()
	var cls := str(a.class_data().get("name", ""))
	_check("party_info_lv_cls", info.begins_with("Lv %d" % a.level) and (cls == "" or info.contains(" · " + cls)), info)
	_check("party_face", ra.face_tex != null)
	a.shield = 1234.0
	_check("party_shield_text", ra.info_text().contains("盾 1234"), ra.info_text())
	a.shield = 0.0
	_check("party_rows_same_as_cells", ra._rows() == XSideStatus.cell_rows(a))
	# 演出中的快照读数（view）优先
	ra.view = {"hp": 1, "mhp": 100, "mp": 2, "mmp": 50, "tp": 3, "mtp": 100, "dead": false, "cell_rows": []}
	_check("party_view_first", ra._v().hp == 1 and ra._rows().is_empty())
	ra.view = {}


## ---- 行动顺序 ----
func _otb(b: XBattleScene, a: XActor) -> void:
	var o := b.otb
	_check("otb_skin", o is XSkinOTBBar, o.get_class())
	if not (o is XSkinOTBBar):
		return
	var so := o as XSkinOTBBar
	_check("otb_pos", so.position == b._origin + XSkinOTBBar.POS, so.position)
	var s: XOTBBar.Icon = so._nodes.get("s")
	_check("otb_subject", s != null and s.battler == a and s.big and s.get_meta("tx", -1.0) == XOTBBar.LH, null if s == null else [s.battler, s.position])
	_check("otb_subject_name", s != null and XSkinOTBBar.name_of(s) == a.display_name())
	_check("otb_subject_radius", s != null and XSkinOTBBar.radius_of(s) == XSkinOTBBar.R_NOW)
	var cur := []
	var nxt := []
	for k in so._nodes:
		var n: XOTBBar.Icon = so._nodes[k]
		_check("otb_painter_" + k, n.painter.is_valid() and not n.face.visible)
		if k.begins_with("c|"):
			cur.append(n)
		elif k.begins_with("n|"):
			nxt.append(n)
	_check("otb_has_rows", nxt.size() > 0, [cur.size(), nxt.size()])
	var names_ok := true
	for n in cur + nxt:
		var want: String = n.battler.display_name() if n.battler is XEnemy and (so.step_px >= XSkinOTBBar.R_ROW * 2.0 or n.selected) else ""
		if XSkinOTBBar.name_of(n) != want:
			names_ok = false
	_check("otb_names_only_now_and_enemy", names_ok)
	# 不挤时敌人都标名字
	var saved := so.step_px
	so.step_px = XSkinOTBBar.STEP_MAX
	var enemy_icon = (cur + nxt).filter(func(n): return n.battler is XEnemy)
	_check("otb_enemy_named_when_room", enemy_icon.is_empty() or XSkinOTBBar.name_of(enemy_icon[0]) == enemy_icon[0].battler.display_name())
	so.step_px = saved
	var xs_c := cur.map(func(n): return n.get_meta("tx", n.position.x))
	var xs_n := nxt.map(func(n): return n.get_meta("tx", n.position.x))
	var all_x := xs_c + xs_n
	_check("otb_in_width", all_x.all(func(x): return x >= so.x1 - 0.5 and x <= XSkinOTBBar.WIDTH - XSkinOTBBar.R_ROW + 0.5), all_x)
	if not xs_c.is_empty() and not xs_n.is_empty():
		_check("otb_separator_between", so.sep_x > xs_c.max() and so.sep_x < xs_n.min(), [xs_c, so.sep_x, xs_n])
	else:
		_check("otb_separator_between", true)
	_check("otb_subject_clear_of_row", so.x1 - XSkinOTBBar.R_ROW >= XOTBBar.LH + XSkinOTBBar.R_NOW, so.x1)
	# 挤：12＋12 人时间距缩小、最后一个仍在宽度里
	so.layout_for(12, 12)
	var last := so.x2 + 11 * so.step_px
	_check("otb_squeeze", so.step_px < XSkinOTBBar.STEP_MAX and last <= XSkinOTBBar.WIDTH - XSkinOTBBar.R_ROW + 0.5, [so.step_px, last])
	so.layout_for(xs_c.size(), xs_n.size())
	# 选为目标：放大
	so.set_selected([cur[0].battler] if not cur.is_empty() else [])
	_check("otb_selected_radius", cur.is_empty() or XSkinOTBBar.radius_of(cur[0]) == XSkinOTBBar.R_SELECTED)
	so.set_selected([])


## ---- 首领血弧与状态胶囊 ----
func _boss(b: XBattleScene) -> void:
	_check("boss_arc_skin", b.boss_hp is XSkinBossArc, b.boss_hp.get_class())
	_check("boss_panel_skin", b.boss_panel is XSkinBossStatus and (b.boss_panel as XSkinBossStatus).arc == b.boss_hp)
	if not (b.boss_hp is XSkinBossArc) or not (b.boss_panel is XSkinBossStatus):
		return
	var arc := b.boss_hp as XSkinBossArc
	var e: XEnemy = b.logic.enemies[0]
	e.enemy_id = 6   # 名单里的首领（同 xiyou_boss_hp_bar）
	e.boss_difficulty_boss = true
	var bad := _timed_state("Debuff")
	var good := _timed_state("Buff")
	_check("boss_fixture_states", bad > 0 and good > 0, [bad, good])
	for id in [bad, good]:
		if id > 0:
			e.add_state(id)
			e.state_turns[id] = 4
	var ok := await _until(func(): return arc.battler == e and arc.layout_alpha == 255, 120)
	_check("boss_arc_tracks", ok, [arc.battler, arc.layout_alpha])
	_check("boss_arc_origin", arc.position == Vector2.ZERO and arc._name_canvas != null and not arc._name_canvas.visible, arc.position)
	_check("boss_arc_range", XSkinBossArc.arc_range() == Vector2(27, 153) and XSkinBossArc.angle_at(1.0) == 27.0 and XSkinBossArc.angle_at(0.0) == 153.0)
	_check("boss_arc_bottom", XSkinBossArc.arc_bottom() == 132.0)
	_check("boss_arc_full", is_equal_approx(arc.rates().x, e.hp / e.mhp))
	_check("boss_max_text", arc.max_text() == XBossHpBar.format_number(e.mhp), arc.max_text())
	e.hp = floorf(e.mhp * 0.5)
	await _frames(2)
	var k := arc.rates()
	_check("boss_arc_half", is_equal_approx(k.x, e.hp / e.mhp), k)
	_check("boss_arc_lag_orange", k.y > k.x, k)
	await _until(func(): return is_equal_approx(arc.rates().y, arc.rates().x) and arc.number_text() == XBossHpBar.format_number(e.hp), 900)
	k = arc.rates()
	_check("boss_arc_lag_caught", is_equal_approx(k.y, k.x), k)
	_check("boss_number_caught", arc.number_text() == XBossHpBar.format_number(e.hp), [arc.number_text(), e.hp])
	var p := b.boss_panel as XSkinBossStatus
	await _until(func(): return p.battler == e and p.visible, 60)
	await _frames(10)
	_check("boss_panel_tracks", p.battler == e and p.visible)
	_check("boss_panel_under_arc", p.arc_shows_boss() and p.bar.position.y == XSkinBossArc.arc_bottom() + 40.0, p.bar.position)
	_check("boss_panel_centered", absf(p.bar.position.x + p.bar.size.x / 2.0 - 640.0) <= 1.0, [p.bar.position, p.bar.size])
	var kinds := p._caps.map(func(c): return str(c.kind))
	_check("boss_caps_kinds", not kinds.has("name") and kinds.back() == "detail" and kinds.count("state") == 2, kinds)
	var bad_cap = p._caps.filter(func(c): return c.kind == "state" and c.bad)
	_check("boss_cap_bad_first", not bad_cap.is_empty() and p._caps[0].kind == "state" and p._caps[0].bad, kinds)
	if not bad_cap.is_empty():
		var nm := XBossStatus.clean(XDB.rec("States", bad).name)
		_check("boss_cap_text", str(bad_cap[0].text).begins_with(nm) and str(bad_cap[0].text).contains("4 回合"), bad_cap[0].text)
	_check("boss_detail_text", p._caps.back().text == "详情 ▾")
	_check("spaced_units", XSkinBossStatus.spaced("异常 · 3回合 · 2层") == "异常 · 3 回合 · 2 层")
	_check("boss_turns_text", XSkinBossStatus.turns_text({"turns": "12回合"}) == "12 回合" and XSkinBossStatus.turns_text({"turns": "常驻"}) == "常驻")


func _boss_detail(b: XBattleScene) -> void:
	var p := b.boss_panel as XSkinBossStatus
	if p == null or p.battler == null:
		_check("boss_detail_ready", false)
		return
	p.click_bar()
	await _frames(3)
	_check("boss_detail_open", p.open and p.detail.visible, [p.open, p.detail.visible])
	_check("boss_detail_pos", p.detail.position == Vector2(640 - XBossStatusPanel.DETAIL_W / 2.0, p.bar.position.y + p.bar.size.y + 8.0), p.detail.position)
	_check("boss_detail_caption", p._caps.back().text == "收起 ▴")
	p.click_detail(Vector2(12 + (XBossStatusPanel.DETAIL_W - 24) / 3.0 * 2 + 10, 50))   # 「全部」页签
	_check("boss_detail_tab_all", p.filter == "All")
	await _shot("battle_2b_boss_detail")
	p.click_detail(Vector2(100, XBossStatusPanel.BODY_Y + 10))   # 点第一条
	_check("boss_detail_pick", p.selected != null)
	await _shot("battle_2b_boss_state")
	p.click_detail(Vector2(XBossStatusPanel.DETAIL_W / 2.0, XBossStatusPanel.DETAIL_H - 10))   # 返回列表
	_check("boss_detail_back", p.selected == null)
	p.click_detail(Vector2(XBossStatusPanel.DETAIL_W - 20, 10))   # ×
	await _frames(2)
	_check("boss_detail_closed", not p.open and not p.detail.visible)


## 没有首领血弧（名单外的首领）：胶囊行在画面顶上，第一枚是名字
func _boss_no_arc(b: XBattleScene) -> void:
	var e: XEnemy = b.logic.enemies[0]
	var p := XSkinBossStatus.new()
	p.enemies_source = func(): return [e]
	p.position = b._origin
	b.ui.add_child(p)
	p._process(0.0)
	_check("boss_noarc_top", p.visible and p.bar.position.y == XSkinBossStatus.TOP_NO_ARC, p.bar.position)
	_check("boss_noarc_name_first", not p._caps.is_empty() and p._caps[0].kind == "name" and str(p._caps[0].text) == XBossStatus.clean(e.display_name()))
	p.queue_free()


## ---- 我方状态详情 ----
func _status_panel(b: XBattleScene, a: XActor) -> void:
	var bad := _timed_state("Debuff")
	if bad > 0:
		a.add_state(bad)
	b._refresh_status()
	_check("status_inputting", b.inputting)
	b._open_status(a)
	await _frames(5)
	var sp = b.status_panel
	_check("status_skin", sp is XSkinPartyStatusPanel, null if sp == null else sp.get_class())
	if not (sp is XSkinPartyStatusPanel):
		return
	var p: XSkinPartyStatusPanel = sp
	var mem: Array = b.logic.actors.filter(func(m): return m is XActor)
	_check("status_members", p.party.members.size() == mem.size() and p.index == mem.find(a), [p.party.members.size(), p.index])
	_check("status_cmd_inactive", not b.cmd_win.active)
	_check("status_tab_all", p.tab == "全部" and p.list.items.size() == XPartyStatusPanel.rows_for(a).size(), [p.tab, p.list.items.size()])
	var rows := XPartyStatusPanel.rows_for(a)
	if not rows.is_empty():
		_check("status_card_first", p.state_card.title == str(rows[0].name) and p.state_card.subtitle == XSkinPartyStatusPanel.meta_text(rows[0]), [p.state_card.title, p.state_card.subtitle])
	_check("status_card_attr", not p.state_card.sections.is_empty() and p.state_card.sections[0].title == "人物属性" and str(p.state_card.sections[0].text).contains("承伤"))
	var d := XSkinLayout.compute(p.view_size(), XSkinPartyStatusPanel.LEFT_W, XSkinPartyStatusPanel.RIGHT_W)
	_check("status_layout", p.party.position == (d.left as Rect2).position and p.state_card.position == (d.right as Rect2).position, [p.party.position, p.state_card.position])
	await _shot("battle_2b_status")
	p.step_tab(-1)   # 全部 → 常驻
	_check("status_tab_step", p.tab == "常驻" and p.list.items.size() == rows.filter(func(r): return r.kind == "常驻").size())
	p.step_tab(-1)   # → 增益
	p.step_tab(-1)   # → 异常
	_check("status_tab_bad", p.tab == "异常" and p.list.items.size() == rows.filter(func(r): return r.kind == "异常").size())
	p.step_actor(1)
	await _frames(2)
	var other: XActor = mem[(mem.find(a) + 1) % mem.size()]
	_check("status_step_actor", p.actor() == other and p.party.index == p.index, [p.index])
	_check("status_keep_tab", p.tab == "异常")
	_check("status_empty_text", p.list.empty_text == "没有异常状态")
	p.close()
	await _frames(3)
	_check("status_closed", b.status_panel == null and b.cmd_win.active)
	if bad > 0:
		a.remove_state(bad)


## 点右侧整行打开状态详情
func _party_click(b: XBattleScene, a: XActor) -> void:
	var r: XSkinSideStatus = b.status_rows[a]
	r.cell_button.pressed.emit()
	await _frames(3)
	_check("party_click_opens", b.status_panel is XSkinPartyStatusPanel)
	if b.status_panel != null:
		b.status_panel.close()
		await _frames(2)


## ---- 开关关着 ----
func _skin_off(b: XBattleScene) -> void:
	XUiSkin.FORCE = false
	XUiSkin.ENABLED = false
	var side := XSkinBattle.side_status()
	_check("off_side_plain", not (side is XSkinSideStatus))
	side.free()
	var holder := Control.new()
	_check("off_no_backdrop", XSkinBattle.side_backdrop(holder, 3) == null and holder.get_child_count() == 0)
	holder.free()
	var o := XSkinBattle.otb()
	_check("off_otb_plain", not (o is XSkinOTBBar))
	o.free()
	var bh := XSkinBattle.boss_hp()
	_check("off_boss_plain", not (bh is XSkinBossArc))
	var bp := XSkinBattle.boss_panel(bh)
	_check("off_panel_plain", not (bp is XSkinBossStatus))
	bh.free()
	bp.free()
	var top := CanvasLayer.new()
	add_child(top)
	var sp := XSkinBattle.status_panel(top, b.logic.actors.filter(func(m): return m is XActor), b.logic.actors[0])
	_check("off_status_plain", not (sp is XSkinPartyStatusPanel) and sp is XPartyStatusPanel)
	sp.close()
	top.queue_free()
	# 原 XOTBBar 的图标没有换画法
	var plain := XOTBBar.new()
	var ic := plain._icon(b.logic.actors[0])
	_check("off_otb_icon_plain", not ic.painter.is_valid())
	ic.free()
	plain.free()
	XUiSkin.ENABLED = true


func _finish() -> void:
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
