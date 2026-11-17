extends Node
## 【cc·天启篇】T096 战斗界面对齐 v0.7 定稿专项：同样稿 battle 的场面（难度 3、队伍 1/8/9/10、敌群 4【守层者】里德、系统默认战斗背景），
## XUiSkin.FORCE 强开新皮肤；内存新游戏，不写存档。
## 核：指令环铺开（球逐个长出）、选中闪一下、确定后环淡出＋列表从环那边展开、关列表收起（残影淡出后释放）、回合提示（旧金圈＋胶囊）、
## 伤害数字（窄体数字、千分位、「暴击」小字在上）、首领血弧拖尾白色、行动条大圆、界面动效「关」时全部直接到位。
## 窗口模式加 -- --out=<目录> 截图（同样稿四个时刻：指令环、战技列表、暴击数字、换人回合）；再加 --wide 时整窗改 1600×720＋KEEP_HEIGHT。

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


## 按时间等（屏幕 120Hz 时 30 帧只有 0.25 秒）
func _secs(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _until(cond: Callable, n := 900) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _shot(name: String, settle := 20) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(settle)
	RenderingServer.force_draw(false)
	var suffix := "_20x9" if wide else ""
	_check("screenshot_" + name + suffix, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + suffix + ".png")) == OK)


func _press(action: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		get_viewport().push_input(e)
		await _frames(2)


func _run() -> void:
	if wide and DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1600, 720)
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
		await _frames(5)
	XUiSkin.FORCE = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	XSave.dir_override = "user://test_xiyou_ui_skin_battle_v07"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.set_flag("CombatDamageShow", true)
	XEnemy.force_roll = 100.0
	seed(20261110)
	var s := XState.new_game(3, 1, [8, 9, 10])
	for a in s.members():
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	s.random_master = XRandomStream.hex64(20261110)
	var b := XBattleScene.new()
	b.setup(4, true, false, {})
	add_child(b)
	await _frames(1)
	_check("hud_fading_in", b.otb.modulate.a < 1.0 and b.boss_panel.modulate.a < 1.0, [b.otb.modulate.a, b.boss_panel.modulate.a])
	var ok := await _until(func(): return b.cmd_win != null and b.cmd_win.active)
	_check("command_shown", ok)
	if not ok:
		_finish()
		return
	await _secs(0.3)
	_check("hud_in_done", b.otb.modulate.a == 1.0 and b.boss_panel.modulate.a == 1.0 and b.tianqi_meter.modulate.a == 1.0, [b.otb.modulate.a, b.boss_panel.modulate.a])
	for a in b.logic.actors:
		a.tp = 12.0
	var boss: XBattler = b.logic.enemies[0]
	boss.add_state(6)
	boss.state_turns[6] = 4
	b._refresh_status()
	await _ring(b)
	await _boss_t125(b, boss)
	await _skill_list(b)
	await _popup(b, boss)
	await _turn_cue(b)
	await _motion_off(b)
	b.bgm.stop()
	_finish()


## 指令环（B 金弦浮印）：小一圈半径 104、选中 1.2 倍；开场菱形星旋转收成十字再展开；开关可回退到 T096 球形环
func _ring(b: XBattleScene) -> void:
	var ring := b.cmd_win as XSkinBattleRing
	_check("ring_type", ring != null)
	if ring == null:
		return
	_check("ring_b_radius_smaller_and_peak", XSkinBattleRing.BOWSTRING_B and is_equal_approx(ring.radius, XSkinBattleRing.RADIUS_B) and is_equal_approx(ring.orb_r, XSkinBattleRing.ORB_R_B) and is_equal_approx(XSkinBattleRing.peak(), 1.2), [ring.orb_r, ring.radius, XSkinBattleRing.peak()])
	var apart := true
	for i in ring.entries.size() - 1:
		apart = apart and ring.orb_pos(i).distance_to(ring.orb_pos(i + 1)) >= ring.orb_r * (1.0 + XSkinBattleRing.peak()) + 3.9
	_check("ring_selected_not_touching", apart, ring.radius)
	# 浮字热区高度 > 30（手机可点）且相邻项不重叠
	var hits := range(ring.entries.size()).map(func(i): return ring.hit_rect_b(i))
	var hit_ok := true
	for i in hits.size():
		var hr: Rect2 = hits[i]
		hit_ok = hit_ok and hr.size.y > 30.0 and hr.has_point(ring.orb_pos(i))
		for j in range(i + 1, hits.size()):
			if hr.intersects(hits[j]):
				hit_ok = false
	_check("ring_hit_rects_tall_nonoverlap", hit_ok, hits.map(func(r): return r.size.y))
	# 十字展开动效：先检查未展开态与回退开关
	if XSkinBattleRing.CROSS_INTRO_B:
		_check("ring_cross_intro_total", is_equal_approx(ring._item_intro_dur(), XSkinBattleRing.CROSS_IN_TIME))
	if out_dir != "":
		print("RING_RECT=", Rect2(ring.position, ring.size), " CENTER=", ring.ring_center())
		var saved_elapsed := ring.intro_elapsed
		var intro_ts := [0.02, 0.06, 0.11, 0.15, 0.21, 0.27, 0.34, 0.42, 0.57]
		ring.set_process(false)
		for k in intro_ts.size():
			ring.intro_elapsed = float(intro_ts[k])
			ring.queue_redraw()
			await _shot("ring_intro_%d" % k, 2)
		ring.intro_elapsed = saved_elapsed
		ring.set_process(true)
		ring.queue_redraw()
	await _secs(0.65)
	_check("ring_sel_scale_1_2", is_equal_approx(ring.orb_scale(ring.index), 1.2) and is_equal_approx(ring.orb_scale((ring.index + 1) % ring.entries.size()), 1.0))
	_check("ring_intro_done", ring.intro_elapsed >= ring.intro_total() and ring.intro_of(ring.entries.size() - 1) == 1.0, [ring.intro_elapsed, ring.intro_total()])
	# Kyo 追加②：选中项标记在「菱形星」与「菱形方块」之间来回循环切换
	_check("ring_sel_morph_active", ring.sel_morph_active())
	_check("ring_sel_morph_endpoints", is_equal_approx(ring.sel_morph_factor(0.0), 0.0) and is_equal_approx(ring.sel_morph_factor(XSkinBattleRing.SEL_MORPH_PERIOD * 0.56), 1.0))
	var morph_t0 := ring._sel_morph_t
	await _secs(0.35)
	_check("ring_sel_morph_cycles", not is_equal_approx(ring._sel_morph_t, morph_t0), [morph_t0, ring._sel_morph_t])
	if out_dir != "":
		var morph_ts := [0.0, 0.25, 0.40, 0.55, 0.85, 1.05, 1.25, 1.45]
		var saved_morph := ring._sel_morph_t
		ring.set_process(false)
		for k in morph_ts.size():
			ring._sel_morph_t = float(morph_ts[k])
			ring.queue_redraw()
			await _shot("ring_sel_morph_%d" % k, 2)
		ring._sel_morph_t = saved_morph
		ring.set_process(true)
		ring.queue_redraw()
	XSkinBattleRing.SEL_MORPH_B = false
	_check("ring_sel_morph_rollback", not ring.sel_morph_active() and ring.sel_morph_factor() == 0.0)
	XSkinBattleRing.SEL_MORPH_B = true
	await _shot("v07_ring", 2)
	# 回退开关验证：关闭 BOWSTRING_B / CROSS_INTRO_B 后回到 T096 球形环尺寸与铺开时长
	XSkinBattleRing.BOWSTRING_B = false
	XSkinBattleRing.CROSS_INTRO_B = false
	var old_r := XSkinBattleRing.create_ring(b.ui, [{"text": "攻", "key": "a"}, {"text": "防", "key": "d"}], "测试")
	_check("ring_rollback_t096", is_equal_approx(old_r.orb_r, XSkinBattleRing.ORB_R) and is_equal_approx(old_r._item_intro_dur(), XSkinBattleMotion.RING_ORB_IN), [old_r.orb_r, old_r._item_intro_dur()])
	old_r.queue_free()
	XSkinBattleRing.BOWSTRING_B = true
	XSkinBattleRing.CROSS_INTRO_B = true


## T125 首领块：按颜色剥离原版菱形金框与黄底、多首领复核、无头像用红铜章＋种族小印、底板改柔墨韵、回退开关可复原
func _boss_t125(b: XBattleScene, boss: XBattler) -> void:
	var arc := b.boss_hp as XSkinBossArc
	var e := boss as XEnemy
	_check("boss_arc_present", arc != null and e != null)
	if arc == null or e == null:
		return
	var reed_tex: Texture2D = XBossHpBar._tex("bosshp", XBossHpBar.face_name(e.enemy_id))
	var crop := XSkinBossArc.face_crop(reed_tex)
	var clean_tex: Texture2D = crop.get("tex")
	var cim := clean_tex.get_image() if clean_tex != null else null
	var bbox := XSkinBossArc._opaque_bbox(cim) if cim != null else Rect2i()
	_check("boss_face_diamond_stripped_full_head", bool(crop.get("diamond", false)) and cim != null and cim.get_pixel(0, 0).a < 0.05 and bbox.size.x >= 36 and bbox.size.y >= 34, [crop.get("diamond"), bbox])
	# 多首领 MOG 头像复核：里德（SL_TX_62）及另外 4 名首领均无黄底残渣
	var multi_ok := true
	var multi_detail := {}
	for fn: String in ["SL_TX_62", "BOSS_TX_18", "SL_TX_63", "BOSS_12", "BOSS_1"]:
		var t := XBossHpBar._tex("bosshp", fn)
		var cr := XSkinBossArc.face_crop(t)
		var ct: Texture2D = cr.get("tex")
		var im := ct.get_image() if ct != null else null
		if not bool(cr.get("diamond", false)) or im == null or im.get_pixel(0, 0).a >= 0.05:
			multi_ok = false
			multi_detail[fn] = "invalid_crop"
			continue
		var yellow_hits := 0
		var edge_yellow := 0
		for y in im.get_height():
			for x in im.get_width():
				var c := im.get_pixel(x, y)
				if c.a < 0.12:
					continue
				var hue := c.h * 360.0
				var is_yel := hue >= 35.0 and hue <= 49.0 and c.s >= 0.28 and c.v >= 0.65
				if is_yel:
					yellow_hits += 1
					for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var xx: int = x + d.x
						var yy: int = y + d.y
						if xx < 0 or xx >= im.get_width() or yy < 0 or yy >= im.get_height() or im.get_pixel(xx, yy).a < 0.12:
							edge_yellow += 1
							break
		if edge_yellow > 0 or (fn == "SL_TX_62" and yellow_hits > 0):
			multi_ok = false
		multi_detail[fn] = [yellow_hits, edge_yellow]
		if out_dir != "":
			var rim := t.get_image()
			if rim != null:
				if rim.is_compressed():
					rim.decompress()
				rim.save_png(out_dir.path_join("face_raw_" + fn + ".png"))
			im.save_png(out_dir.path_join("face_clean_" + fn + ".png"))
	_check("boss_faces_hsv_clean_no_yellow_residue", multi_ok, multi_detail)
	_check("boss_copper_seal_loaded", XSkinBossArc.copper_seal_texture() != null)
	# CLEAN_FACE / INK_TEXT 回退开关实际行为验证（有头像首领）
	XSkinBossArc.CLEAN_FACE = false
	XSkinBossArc.INK_TEXT = false
	var bak0 := XSkin4A.backing_count
	arc.queue_redraw()
	await _frames(2)
	_check("boss_clean_face_off_faced", arc._last_face_mode == "t096_round", arc._last_face_mode)
	_check("boss_ink_text_off_backing", not arc._last_ink_text and (not XSkin4A.text_on() or (arc._last_backing_draws == 2 and XSkin4A.backing_count >= bak0 + 2)), [arc._last_ink_text, arc._last_backing_draws, XSkin4A.backing_count - bak0])
	XSkinBossArc.CLEAN_FACE = true
	XSkinBossArc.INK_TEXT = true
	arc.queue_redraw()
	await _frames(2)
	_check("boss_clean_face_on_faced", arc._last_face_mode == "clean_crop", arc._last_face_mode)
	_check("boss_ink_text_on_no_backing", arc._last_ink_text and arc._last_backing_draws == 0, [arc._last_ink_text, arc._last_backing_draws])
	# 无头像首领（例如天劫/神兵扩展首领）：换红铜章＋种族印并截图对照
	var faceless_id := 0
	var cands := []
	for wid in XZhenqi.WEAPON_BOSS:
		cands.append(int(wid))
	for tid in [XZhenqi.TRIAL_TROOP["心魔"], XZhenqi.TRIAL_TROOP["天劫"], XZhenqi.HEART_TROOP[1]]:
		for m in XDB.rec("Troops", int(tid)).get("members", []):
			cands.append(int(m.enemyId))
	for id in cands:
		if not XBossHpBar.is_listed(id) and XBossHpBar.face_name(id) == "":
			var probe := XEnemy.new().setup(id, 1)
			if not probe.race_ids().is_empty():
				faceless_id = id
				break
	_check("boss_faceless_fixture_found", faceless_id > 0, faceless_id)
	if faceless_id > 0:
		var saved_id := e.enemy_id
		var saved_name := arc._name_text
		var saved_face := arc._face_tex
		var saved_shown := arc._shown_id
		e.enemy_id = faceless_id
		arc._shown_id = faceless_id
		arc._face_tex = null
		arc._name_text = e.display_name()
		arc.queue_redraw()
		await _frames(4)
		_check("boss_faceless_race_id", arc._boss_race_id() > 0 and arc._last_face_mode == "copper_seal", [arc._boss_race_id(), arc._last_face_mode])
		await _shot("v07_boss_faceless", 6)
		XSkinBossArc.CLEAN_FACE = false
		arc.queue_redraw()
		await _frames(2)
		_check("boss_clean_face_off_faceless", arc._last_face_mode == "", arc._last_face_mode)
		XSkinBossArc.CLEAN_FACE = true
		e.enemy_id = saved_id
		arc._shown_id = saved_shown
		arc._face_tex = saved_face
		arc._name_text = saved_name
		arc.queue_redraw()
		await _frames(2)


## 战技列表：确定后环淡出、列表从右边（环那边）由小展开；取消时列表收起成残影、新环重新铺开
func _skill_list(b: XBattleScene) -> void:
	var ring := b.cmd_win as XSkinBattleRing
	if ring == null:
		return
	var i := ring.entries.find_custom(func(e): return str(e.text) == "战技")
	_check("ring_has_skill", i >= 0, ring.entries.map(func(e): return e.text))
	if i < 0:
		return
	ring.select(i)
	await _frames(1)
	_check("ring_flash_on_select", ring._flash_i == i and ring._flash_t < XSkinBattleRing.FLASH_TIME)
	await _frames(20)
	await _press("ui_accept")
	await _until(func(): return b.list_win != null, 60)
	var lw := b.list_win as XSkinBattleSkillList
	_check("list_opened", lw != null)
	if lw == null:
		return
	_check("list_grows_from_right", lw.scale.x < 1.0 and lw.pivot_offset == Vector2(lw.size.x, lw.size.y / 2.0), [lw.scale, lw.pivot_offset])
	_check("ring_fading", ring.vis < 1.0 and ring.vis > 0.0 or ring.vis == 0.0, ring.vis)
	await _shot("v07_skill_opening", 1)
	await _secs(0.4)
	_check("list_open_done", is_equal_approx(lw.scale.x, 1.0) and is_equal_approx(lw.modulate.a, 1.0), [lw.scale, lw.modulate.a])
	_check("ring_faded_out", ring.vis == 0.0, ring.vis)
	_check("list_desc_line", lw.desc_line() != "", lw.desc_line())
	_check("help_card_collapsed", b.help_card == null or not b.help_card.visible)
	await _shot("v07_skill", 10)
	lw.cancelled.emit()   # 同按取消（_press 一来一回 4 帧，慢机器上残影可能已演完）
	await _frames(1)
	var ghost := b.ui.get_children().filter(func(c): return c is XSkinBattleSkillList and XSkinBattleMotion.dismissing(c))
	_check("list_dismiss_ghost", b.list_win == null and ghost.size() == 1 and not (ghost[0] as XBattleList).active, ghost.size())
	await _secs(0.5)
	ghost = b.ui.get_children().filter(func(c): return c is XSkinBattleSkillList)
	_check("list_ghost_freed", ghost.is_empty(), ghost.size())
	_check("ring_back", b.cmd_win != null and b.cmd_win.active and (b.cmd_win as XSkinBattleRing).vis == 1.0)


## 暴击数字（样稿：「暴击」小字在上、4,567 窄体数字）
func _popup(b: XBattleScene, boss: XBattler) -> void:
	b._popup(boss, 4567, true)
	b._popup(b.logic.actors[1], -321, false)
	await _frames(2)
	var crit: XDamagePopup = null
	var heal: XDamagePopup = null
	for p in b._popups.get(boss, []):
		if is_instance_valid(p):
			crit = p
	for p in b._popups.get(b.logic.actors[1], []):
		if is_instance_valid(p):
			heal = p
	_check("popup_text_unchanged", crit != null and crit.text == "暴击  4,567  ！" or crit != null and crit.text == "暴击  4567  ！", null if crit == null else crit.text)
	_check("popup_skin_parts", crit != null and XSkinDamagePopup.parts(crit) == ["暴击", "4,567"], null if crit == null else XSkinDamagePopup.parts(crit))
	_check("popup_heal_parts", heal != null and XSkinDamagePopup.parts(heal) == ["", "+321"], null if heal == null else XSkinDamagePopup.parts(heal))
	_check("popup_crit_peak", crit != null and XSkinDamagePopup.scale_of(crit) <= XSkinDamagePopup.CRIT_PEAK + 0.001, null if crit == null else XSkinDamagePopup.scale_of(crit))
	_check("popup_big_number", XSkinDamagePopup.number_text(123456) == XDamagePopup.format_number(123456) and XSkinDamagePopup.number_text(1234) == "1,234")
	await _shot("v07_popup", 12)


## 换人回合（样稿：旧金圈从角色身上扩开、头上「某某 的回合」胶囊；指令环上的「某某的行动」等胶囊淡掉才出来）
func _turn_cue(b: XBattleScene) -> void:
	var a: XActor = b.logic.actors[2]
	XSkinBattle.turn_cue(b, a)
	await _frames(1)
	var cues := b.ui.get_children().filter(func(c): return c is XSkinTurnCue)
	_check("turn_cue_shown", cues.size() == 1 and (cues[0] as XSkinTurnCue).who == a.display_name(), cues.size())
	_check("ring_title_waits", XSkinTurnCue.title_alpha() < 1.0)
	await _secs(0.18)
	await _shot("v07_turn", 0)
	await _secs(1.0)
	cues = b.ui.get_children().filter(func(c): return c is XSkinTurnCue)
	_check("turn_cue_freed", cues.is_empty() and XSkinTurnCue.title_alpha() == 1.0, cues.size())


## 界面动效「关」：列表直接到位、关掉直接释放、没有换人提示、环直接收起
func _motion_off(b: XBattleScene) -> void:
	XUiSkin.motion_override = XUiSkin.Motion.OFF
	var ring := b.cmd_win as XSkinBattleRing
	if ring == null:
		return
	var i := ring.entries.find_custom(func(e): return str(e.text) == "战技")
	ring.select(i)
	await _frames(2)
	await _press("ui_accept")
	await _until(func(): return b.list_win != null, 60)
	var lw := b.list_win as XSkinBattleSkillList
	_check("off_list_no_grow", lw != null and lw.scale == Vector2.ONE and lw.modulate.a == 1.0)
	await _frames(1)
	_check("off_ring_hidden_now", ring.vis == 0.0)
	await _press("ui_cancel")
	await _frames(1)
	var left := b.ui.get_children().filter(func(c): return c is XSkinBattleSkillList and not c.is_queued_for_deletion())
	_check("off_list_freed_now", b.list_win == null and left.is_empty(), left.size())
	XSkinBattle.turn_cue(b, b.logic.actors[0])
	_check("off_no_turn_cue", b.ui.get_children().filter(func(c): return c is XSkinTurnCue).is_empty())
	var nr := b.cmd_win as XSkinBattleRing
	_check("off_ring_no_intro", nr != null and nr.intro_of(0) == 1.0 and nr.intro_elapsed >= nr.intro_total())
	_check("off_ring_no_sel_morph", nr != null and not nr.sel_morph_active() and nr.sel_morph_factor() == 0.0)
	var probe := Control.new()
	add_child(probe)
	XSkinBattleMotion.hud_in([probe])
	_check("off_no_hud_fade", probe.modulate.a == 1.0)
	probe.queue_free()
	XUiSkin.motion_override = XUiSkin.Motion.FULL


func _finish() -> void:
	XUiSkin.FORCE = false
	XUiSkin.motion_override = -1
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
