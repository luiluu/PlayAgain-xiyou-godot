extends Node
## 新界面第 4B 批（ui-skin-4b）专项：
## - 对话框 XMessageBox、选项窗 XChoiceWindow
## - 提示条与通知 XToast / XAutosaveNotice / XPowerNotice / XPrestigeNotice / XSkillNotice、成就弹窗 XAchievementPopup
## - 难度横幅 XDifficultyNoticeCanvas（含 2B 遗留：首领血弧让位、地图快照隐藏）、地名横幅 MapNamePlate、拾取浮字 XTreasurePopup、称号铭牌 XDesignationPlate
## - 传送页 XMapTransferScene（含 20:9 宽屏适配与按键提示）
## - 顺带 1：物品页 item_bag_return「已生效…」提示条放进 XSkinCard、XHelpCard 暗底可读配色与 20:9 让位
## - 顺带 2：挂机设置主/子页 ON/OFF/YES/NO/Open/open 仅在天启篇新皮肤下汉化，重制版／皮肤关闭保持原样
## 加 -- --out=<目录> 且有窗口时保存新旧并排对比截图（全部 16:9 + 2 页 20:9）。
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


func pframes(n := 2) -> void:
	for i in range(n):
		await get_tree().physics_frame


func windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func _capture() -> Image:
	if not windowed():
		return null
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _save_side_by_side(name: String, old_img: Image, new_img: Image) -> void:
	if not windowed() or old_img == null or new_img == null:
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var gap := 4
	var w := old_img.get_width() + gap + new_img.get_width()
	var h := maxi(old_img.get_height(), new_img.get_height())
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.05, 0.06, 1.0))
	out.blit_rect(old_img, Rect2i(Vector2i.ZERO, old_img.get_size()), Vector2i(0, 0))
	out.fill_rect(Rect2i(old_img.get_width(), 0, gap, h), Color(0.89, 0.74, 0.45, 1.0))
	out.blit_rect(new_img, Rect2i(Vector2i.ZERO, new_img.get_size()), Vector2i(old_img.get_width() + gap, 0))
	check("shot_" + name, out.save_png(out_dir.path_join(name + ".png")) == OK, out.get_size())


func _act(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _state(tianqi := true) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.map_id = 4
	XState.current = s
	if tianqi:
		s.flags["tianqi"] = {"rules": 1}
	s.gain_item(532, 3)
	for rec in XDB.table("Items"):
		if rec is Dictionary and rec.get("effects", []).any(func(e): return int(e.get("code", 0)) == 11):
			s.gain_item(int(rec.id), 2)
			break
	s.gain_gear("weapon", 5, 1)
	return s


func _backdrop() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.14, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	return bg


func _run() -> void:
	TestEnv.isolate("xiyou_ui_skin_4b")
	XUiSkin.ENABLED = true
	XUiSkin.motion_override = XUiSkin.Motion.FULL
	await _test_message_box()
	await _test_choice_window()
	await _test_notices()
	await _test_achievement_popup()
	await _test_map_overlays()
	await _test_map_transfer()
	await _test_item_notice_and_help_card()
	await _test_hangup_options()
	XUiSkin.ENABLED = true
	XUiSkin.motion_override = -1
	XState.current = null
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
	await frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 1. 对话框 XMessageBox ----

func _run_msg_sample(skinned: bool, wide := false) -> Image:
	XUiSkin.ENABLED = skinned
	_state(true)
	var win := get_window()
	var old_sz := win.size
	var bg := _backdrop()
	if skinned and wide:
		XSkinLayout.request_wide(bg)
	if windowed() and wide:
		win.size = Vector2i(1600, 720)
		await frames(4)
	var box := XMessageBox.new()
	add_child(box)
	await frames(2)
	var msg := {
		"face": "Actor1",
		"index": 0,
		"background": 0,
		"position": 2,
		"lines": ["\\n<五条悟>无下限术式已展开。", "\\c[14]精魂\\c[0]与印屑准备就绪，准备出发吧？"],
		"choices": ["立刻出发", "再整备一下", "查看状态"],
		"cancel": 1,
		"default": 0,
	}
	box.run(msg)
	await pframes(28)
	await frames(2)
	var tag := ("new" if skinned else "old") + ("_20x9" if wide else "_16x9")
	check("msg_busy_" + tag, box.is_busy() and box.win.openness == 255 and box.choice_win.openness == 255, [box.is_busy(), box.win.openness, box.choice_win.openness])
	check("msg_font_" + tag, box.win.canvas.clean_text == skinned and box.choice_win.canvas.clean_text == skinned)
	check("msg_hints_" + tag, box._hints.visible == skinned)
	if skinned:
		var vs := box._view_size()
		var expected_w := minf(vs.x - XSkinLayout.margin_for(vs.x) * 2.0, 1200.0)
		var expected_x := roundf((vs.x - expected_w) / 2.0)
		check("msg_margin_" + tag, absf(box.win.position.x - expected_x) <= 1.0, [box.win.position, expected_x])
	else:
		check("msg_old_rect_" + tag, is_equal_approx(box.win.position.x, 0.0) and is_equal_approx(box.win.size.x, 1280.0))
	var img := await _capture()
	box.get_viewport().push_input(_act("ui_accept"))
	await pframes(16)
	box.queue_free()
	bg.queue_free()
	if windowed() and wide:
		win.size = old_sz
		await frames(4)
	await frames(2)
	return img


func _test_message_box() -> void:
	var old_16 := await _run_msg_sample(false, false)
	var new_16 := await _run_msg_sample(true, false)
	await _save_side_by_side("01_message_box_16x9", old_16, new_16)
	var old_20 := await _run_msg_sample(false, true)
	var new_20 := await _run_msg_sample(true, true)
	await _save_side_by_side("01_message_box_20x9", old_20, new_20)


# ---- 2. 选项窗 XChoiceWindow ----

func _run_choice_sample(skinned: bool) -> Image:
	XUiSkin.ENABLED = skinned
	_state(true)
	var bg := _backdrop()
	var cw := XChoiceWindow.new()
	add_child(cw)
	await frames(2)
	cw.open([
		{"name": "锻造赤影宝珠（消耗精魂 × 30）", "enabled": true},
		{"name": "强化天启护符 +1", "enabled": true},
		{"name": "解封远古词条（材料不足）", "enabled": false},
		{"name": "返回", "enabled": true},
	], func(_i): pass, func(): pass, ["请选择要进行的操作：", "当前持有精魂：120"])
	await frames(8)
	var tag := "new" if skinned else "old"
	check("choice_clean_" + tag, cw.win.canvas.clean_text == skinned and cw._hints.visible == skinned)
	check("choice_width_" + tag, cw.win.size.x == (780.0 if skinned else XChoiceWindow.WIDTH), cw.win.size)
	var img := await _capture()
	cw.queue_free()
	bg.queue_free()
	await frames(2)
	return img


func _test_choice_window() -> void:
	var old_img := await _run_choice_sample(false)
	var new_img := await _run_choice_sample(true)
	await _save_side_by_side("02_choice_window_16x9", old_img, new_img)


# ---- 3. 提示条与通知 ----

func _run_notices_sample(skinned: bool) -> Image:
	XUiSkin.ENABLED = skinned
	var s := _state(true)
	var bg := _backdrop()
	XToast.shown.clear()
	XToast.show_text("已生效：能量药剂（检测到角色或背包变化）", true)
	var toast := get_tree().root.get_node_or_null("XToast") as XToast
	var auto := XAutosaveNotice.new()
	auto.name = "TestAutosave"
	add_child(auto)
	auto.reveal(XAutosaveNotice.MSG_SAVE)
	auto.contents_opacity = 255
	auto.win.canvas.modulate.a = 1.0
	var pwr := XPowerNotice.new()
	add_child(pwr)
	pwr.show_text("孙悟空 · 战力提升 +1.25万\n当前总战力：8.40万")
	var pre := XPrestigeNotice.new()
	add_child(pre)
	XTreasureBatch._sync_owner(s)
	XTreasureBatch.queue = {
		"w1": {"name": "太虚裂空剑", "icon": 160, "count": 1},
		"a1": {"name": "星渊护腕", "icon": 9, "count": 2},
		"a2": {"name": "天启圣戒", "icon": 100, "count": 1},
	}
	pre.step()
	pre.flash.color.a = 0.0
	var sk := XSkillNotice.new()
	add_child(sk)
	XSkillNotice.queue = [{"actorId": 8, "skillId": 1, "actorName": "孙悟空", "skillName": "如意金箍棒", "from": 2, "to": 3}]
	sk.pump()
	await frames(10)
	var tag := "new" if skinned else "old"
	check("toast_shown_" + tag, toast != null and XToast.shown.size() == 1 and toast.stack.get_child_count() == 1)
	check("autosave_skin_" + tag, auto.win.canvas.clean_text == skinned and (auto.win.size.y == 38.0 if skinned else auto.win.size == XAutosaveNotice.RECT.size))
	check("power_notice_" + tag, pwr.box.visible and pwr.box.skinned == skinned)
	check("prestige_notice_" + tag, pre.win.visible and pre.win.canvas.clean_text == skinned)
	check("skill_notice_" + tag, not XSkillNotice.shown.is_empty() and sk.host.get_child_count() == 1)
	var img := await _capture()
	for n in [toast, auto, pwr, pre, sk, bg]:
		if is_instance_valid(n):
			n.queue_free()
	XSkillNotice.shown.clear()
	XSkillNotice.queue.clear()
	XTreasureBatch.queue.clear()
	await frames(4)
	return img


func _test_notices() -> void:
	var old_img := await _run_notices_sample(false)
	var new_img := await _run_notices_sample(true)
	await _save_side_by_side("03_notices_16x9", old_img, new_img)


# ---- 4. 成就弹窗 XAchievementPopup ----

func _run_ach_sample(skinned: bool) -> Image:
	XUiSkin.ENABLED = skinned
	_state(true)
	var bg := _backdrop()
	var layer := CanvasLayer.new()
	layer.layer = 85
	add_child(layer)
	var p1 := XAchievementPopup.new()
	p1.item = {"id": 1, "name": "初入西游", "icon": 100}
	p1.position = Vector2(roundf((1280.0 - p1.plan_width()) / 2.0), 220.0)
	p1.base_y = p1.position.y
	layer.add_child(p1)
	var p2 := XAchievementPopup.new()
	p2.item = {"id": 142, "name": "本质高手", "icon": 240201}
	p2.position = Vector2(roundf((1280.0 - p2.plan_width()) / 2.0), 320.0)
	p2.base_y = p2.position.y
	layer.add_child(p2)
	await frames(2)
	p1.set_physics_process(false)
	p2.set_physics_process(false)
	p1._apply(1.0)
	p2._apply(1.0)
	await frames(4)
	var tag := "new" if skinned else "old"
	check("ach_size_" + tag, p1.plan_width() == (340.0 if skinned else XAchievementPopup.WIDTH) and p1.plan_height() == (62.0 if skinned else XAchievementPopup.HEIGHT))
	check("ach_font_" + tag, p1.win.canvas.clean_text == skinned)
	var img := await _capture()
	layer.queue_free()
	bg.queue_free()
	await frames(2)
	return img


func _test_achievement_popup() -> void:
	var old_img := await _run_ach_sample(false)
	var new_img := await _run_ach_sample(true)
	await _save_side_by_side("04_achievement_popup_16x9", old_img, new_img)


# ---- 5. 难度横幅、2B 首领血弧让位、地名横幅、拾取浮字、称号铭牌 ----

func _run_overlays_sample(skinned: bool) -> Image:
	XUiSkin.ENABLED = skinned
	var s := _state(true)
	s.actor_name = "天命行者"
	s.designation = {"name": "万象破妄", "icon": 100, "color": "#f2d08a"}
	var bg := _backdrop()
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	# 地名横幅（复用 map_scene 的 _paint_map_name 等价布局，并用真实 XMapScene 验 _snapshot）
	var map := XMapScene.new()
	add_child(map)
	await frames(6)
	map._show_map_name("青丘秘境 · 试炼之巅")
	var plate: XMVCanvas = map.hud.find_child("MapNamePlate", true, false)
	if plate != null:
		map._map_name_tween.kill()
		plate.position.y = 48.0
		plate.modulate.a = 1.0
		plate.queue_redraw()
	# 难度横幅 + 模拟 2B 首领血弧让位验证
	var dn: XDifficultyNoticeCanvas = map.difficulty_notice
	dn.clock.set_physics_process(false)
	dn.clock.text = "当前难度：炼狱 · 属性 ×200%"
	dn.clock.color = Color("#ff7878")
	dn.clock.showing = true
	dn.clock.opacity = 255
	dn.clock.bounce_y = 112.0
	dn.refresh()
	# 拾取浮字
	var item_rec := XDB.rec("Items", 532)
	var pop := XTreasurePopup.new()
	pop.setup(item_rec, 2, Vector2(640, 360), 0, 1)
	pop._wait_in = 0
	pop._wait_hold = 60
	pop._alpha = 255.0
	pop.set_physics_process(false)
	host.add_child(pop)
	# 称号铭牌
	var des := XDesignationPlate.new()
	des.position = Vector2(640 - XDesignationPlate.W / 2.0, 440.0)
	des.refresh(s)
	host.add_child(des)
	await frames(4)
	var tag := "new" if skinned else "old"
	check("map_plate_" + tag, plate != null and plate.clean_text == skinned)
	check("diff_notice_height_" + tag, dn.size.y == (36.0 if skinned else 80.0) and dn.clean_text == skinned, dn.size)
	check("treasure_text_contract_" + tag, pop.text() == "%s x 2" % str(item_rec.get("name", "")))
	check("treasure_display_" + tag, pop._display_text() == ("%s × 2" % str(item_rec.get("name", "")) if skinned else pop.text()))
	check("designation_redraw_" + tag, true)
	# 真实构造含 XSkinBossArc 的节点验证 _boss_arc_bottom()
	var fake_battle := XBattleScene.new()
	fake_battle.setup(2, true, false, XDB.map(5))
	fake_battle.visible = true
	map.ui.add_child(fake_battle)
	await frames(2)
	if skinned and fake_battle.boss_hp is XSkinBossArc:
		fake_battle.boss_hp.battler = fake_battle.logic.enemies[0]
		fake_battle.boss_hp.layout_alpha = 255
		fake_battle.boss_hp.visible = true
	dn.refresh()
	if skinned:
		check("diff_yields_to_boss_arc", dn.position.y >= XSkinBossArc.arc_bottom() + 48.0 - 0.5, [dn.position.y, XSkinBossArc.arc_bottom()])
	else:
		check("diff_off_no_yield", is_equal_approx(dn.position.y, dn.clock.bounce_y), [dn.position.y, dn.clock.bounce_y])
	fake_battle.queue_free()
	await frames(2)
	dn.refresh()
	await frames(3)
	var img := await _capture()
	map.queue_free()
	host.queue_free()
	bg.queue_free()
	await frames(4)
	return img


func _test_map_overlays() -> void:
	var old_img := await _run_overlays_sample(false)
	var new_img := await _run_overlays_sample(true)
	await _save_side_by_side("05_map_overlays_16x9", old_img, new_img)


# ---- 6. 传送页 XMapTransferScene ----

func _run_transfer_sample(skinned: bool, wide := false) -> Image:
	XUiSkin.ENABLED = skinned
	_state(true)
	var win := get_window()
	var old_sz := win.size
	if windowed() and wide:
		win.size = Vector2i(1600, 720)
		await frames(4)
	var tr := XMapTransferScene.new()
	add_child(tr)
	await frames(8)
	var tag := ("new" if skinned else "old") + ("_20x9" if wide else "_16x9")
	check("tr_chrome_" + tag, (tr._header != null and tr._hints != null) if skinned else (tr._header == null and tr._hints == null))
	if skinned:
		var m := XSkinLayout.margin_for(tr._view_size().x)
		check("tr_list_margin_" + tag, is_equal_approx(tr.list_win.position.x, m), [tr.list_win.position.x, m])
		check("tr_rows_dynamic_" + tag, tr._list_rows() >= 10, tr._list_rows())
	else:
		check("tr_old_rect_" + tag, tr.list_win.get_rect() == XMapTransferScene.LIST_RECT)
	tr.confirm_map()
	await frames(4)
	if skinned:
		check("tr_hints_drops_" + tag, tr._hints.hints.size() >= 3)
	var img := await _capture()
	tr.queue_free()
	if windowed() and wide:
		win.size = old_sz
		await frames(4)
	await frames(3)
	return img


func _test_map_transfer() -> void:
	var old_16 := await _run_transfer_sample(false, false)
	var new_16 := await _run_transfer_sample(true, false)
	await _save_side_by_side("06_map_transfer_16x9", old_16, new_16)
	var old_20 := await _run_transfer_sample(false, true)
	var new_20 := await _run_transfer_sample(true, true)
	await _save_side_by_side("06_map_transfer_20x9", old_20, new_20)


# ---- 7. 顺带 1：物品袋提示条 & XHelpCard ----

func _run_item_help_sample(skinned: bool) -> Image:
	XUiSkin.ENABLED = skinned
	var s := _state(true)
	var sc := XItemScene.new()
	add_child(sc)
	await frames(4)
	sc._cat = 0
	sc._mode = "list"
	sc._index = 0
	var notice_msg := "已生效：能量药剂（检测到角色或背包变化）"
	sc.show_notice(notice_msg)
	await frames(4)
	var tag := "new" if skinned else "old"
	if skinned:
		check("item_skin_notice_shown", sc.skin != null and sc.skin.card.notice == notice_msg and not sc.help_card.visible, [sc.skin.card.notice, sc.help_card.visible])
	else:
		check("item_old_notice_help", sc.skin == null and sc.help_card.visible)
	# 在左侧/底部叠加展示一张装备 XHelpCard 验证配色与边框
	var hc := XHelpCard.new()
	add_child(hc)
	var wp: Dictionary = s.gear[0]
	hc.show_for(wp)
	hc.place_near(Rect2(60, 120, 200, 48), "right")
	await frames(4)
	check("help_card_skin_" + tag, hc.skinned() == skinned and hc.canvas.clean_text == skinned)
	if skinned:
		var c_blue := XHelpCard._skin_color(Color(0.3, 0.3, 1.0, 1.0))
		var c_yel := XHelpCard._skin_color(Color(1.0, 1.0, 0.0, 1.0))
		check("help_card_colors", c_blue == XUiSkin.MP_TEXT and c_yel == XUiSkin.GOLD_LIGHT)
	var img := await _capture()
	hc.queue_free()
	sc.queue_free()
	await frames(3)
	return img


func _test_item_notice_and_help_card() -> void:
	var old_img := await _run_item_help_sample(false)
	var new_img := await _run_item_help_sample(true)
	await _save_side_by_side("07_item_notice_help_card_16x9", old_img, new_img)


# ---- 8. 顺带 2：挂机设置主/子页 ON/OFF 汉化（仅天启篇） ----

func _run_hangup_main(skinned: bool) -> Image:
	XUiSkin.ENABLED = skinned
	_state(true)
	var page := XHangUpOptionsScene.new()
	add_child(page)
	await frames(4)
	var tag := "new" if skinned else "old"
	var st_bool := page.status_text(1)
	var st_sub := page.status_text(8)
	if skinned:
		check("hu_main_cn", st_bool in ["是", "否"] and st_sub == "进入", [st_bool, st_sub])
	else:
		check("hu_main_en", st_bool in ["YES", "NO"] and st_sub == "open", [st_bool, st_sub])
	var img := await _capture()
	page.queue_free()
	await frames(2)
	return img


func _run_hangup_sub(skinned: bool) -> Image:
	XUiSkin.ENABLED = skinned
	_state(true)
	var med := XHangUpSubPage.new().setup("medication")
	add_child(med)
	await frames(2)
	var mrows := med.rows()
	med.queue_free()
	await frames(2)
	var sub := XHangUpSubPage.new().setup("hp")
	add_child(sub)
	await frames(4)
	var rs := sub.rows()
	if skinned:
		check("hu_sub_cn", str(mrows[0][1]) == "进入" and not rs.is_empty() and str(rs[0][1]) in ["开", "关"], [mrows, rs])
	else:
		check("hu_sub_en", str(mrows[0][1]) == "Open" and not rs.is_empty() and str(rs[0][1]) in ["ON", "OFF"], [mrows, rs])
	var img := await _capture()
	sub.queue_free()
	await frames(2)
	return img


func _test_hangup_options() -> void:
	var m_old := await _run_hangup_main(false)
	var m_new := await _run_hangup_main(true)
	await _save_side_by_side("08_hangup_options_16x9", m_old, m_new)
	var s_old := await _run_hangup_sub(false)
	var s_new := await _run_hangup_sub(true)
	await _save_side_by_side("09_hangup_subpage_16x9", s_old, s_new)
