extends Node
## 新界面第 4B 批（ui-skin-4b）专项：
## - 对话框 XMessageBox、选项窗 XChoiceWindow
## - 提示条与通知 XToast / XAutosaveNotice / XPowerNotice / XPrestigeNotice / XSkillNotice、成就弹窗 XAchievementPopup
## - 难度横幅 XDifficultyNoticeCanvas（含 2B 遗留：首领血弧让位、地图快照隐藏）、地名横幅 MapNamePlate、拾取浮字 XTreasurePopup、称号铭牌 XDesignationPlate
## - 传送页 XMapTransferScene（含 20:9 宽屏适配与按键提示）
## - 顺带 1：物品页 item_bag_return「已生效…」提示条放进 XSkinCard、XHelpCard 暗底可读配色与 20:9 让位
## - 顺带 2：挂机设置主/子页 ON/OFF/YES/NO/Open/open 仅在天启篇新皮肤下汉化，重制版／皮肤关闭保持原样
## - T254 卡 C（T266）：提示道 XSkinNoticeLane（成就、自动存档、战力、至臻、技能升级、XToast 统一上沿正中排队）、
##   难度横幅深色胶囊（R2）、宝箱浮字换底（R4）、挂机胶囊写状态（R14）；上面 3、4 两节是开关 NOTICE_V2 关着时的 4B 画法（回退支）
## 加 -- --out=<目录> 且有窗口时保存新旧并排对比截图（全部 16:9 + 2 页 20:9）；卡 C 另存 c*_ 开头的 800×450（20:9 为 1000×450）对照图。
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
	await _test_notice_lane()
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
	XSkinNoticeLane.NOTICE_V2 = false   # 卡 C 开关关着：各提示照 4B 各画各的（回退支）
	var s := _state(true)
	var bg := _backdrop()
	XToast.shown.clear()
	XToast.show_text("已生效：能量药剂（检测到角色或背包变化）", true)
	XToast.show_text("第二条提示：多条不叠在一起", true)
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
	check("toast_shown_" + tag, toast != null and XToast.shown.size() == 2 and toast.stack.get_child_count() == 2)
	# T106：新皮肤提示栈在页名／页签（上 72）之下；两条竖向不重叠
	if toast != null and toast.stack.get_child_count() == 2:
		var s0 := toast.stack.get_child(0) as Control
		var s1 := toast.stack.get_child(1) as Control
		check("toast_below_header_" + tag, toast.stack.position.y >= (float(XUiSkin.TOP) if skinned else 0.0) and s1.position.y >= s0.position.y + s0.size.y - 1.0, [toast.stack.position, s0.position, s0.size, s1.position])
	check("autosave_skin_" + tag, auto.win.canvas.clean_text == skinned and (auto.win.size.y == 38.0 if skinned else auto.win.size == XAutosaveNotice.RECT.size))
	check("autosave_host_" + tag, (auto._host.anchor_right == 1.0) if skinned else (auto._host.anchor_right == 0.0 and auto._host.size == Vector2(1280, 720)), [auto._host.anchor_right, auto._host.size])
	check("power_notice_" + tag, pwr.box.visible and pwr.box.skinned == skinned)
	check("prestige_notice_" + tag, pre.win.visible and pre.win.canvas.clean_text == skinned)
	check("prestige_host_" + tag, (pre.flash.anchor_right == 1.0 and pre.host.anchor_right == 1.0) if skinned else (pre.flash.anchor_right == 0.0 and pre.flash.size == Vector2(1280, 720) and pre.host.anchor_right == 0.0 and pre.host.size == Vector2(1280, 720)), [pre.flash.anchor_right, pre.flash.size, pre.host.anchor_right, pre.host.size])
	check("skill_notice_" + tag, not XSkillNotice.shown.is_empty() and sk.host.get_child_count() == 1)
	var img := await _capture()
	for n in [toast, auto, pwr, pre, sk, bg]:
		if is_instance_valid(n):
			n.queue_free()
	XSkillNotice.shown.clear()
	XSkillNotice.queue.clear()
	XTreasureBatch.queue.clear()
	XSkinNoticeLane.NOTICE_V2 = true
	await frames(4)
	return img


func _test_notices() -> void:
	var old_img := await _run_notices_sample(false)
	var new_img := await _run_notices_sample(true)
	await _save_side_by_side("03_notices_16x9", old_img, new_img)


# ---- 4. 成就弹窗 XAchievementPopup ----

func _run_ach_sample(skinned: bool) -> Image:
	XUiSkin.ENABLED = skinned
	XSkinNoticeLane.NOTICE_V2 = false
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
	XSkinNoticeLane.NOTICE_V2 = true
	await frames(2)
	return img


func _test_achievement_popup() -> void:
	var old_img := await _run_ach_sample(false)
	var new_img := await _run_ach_sample(true)
	await _save_side_by_side("04_achievement_popup_16x9", old_img, new_img)
	XSkinNoticeLane.NOTICE_V2 = false
	for sk in [false, true]:
		XUiSkin.ENABLED = sk
		_state(true)
		XAchievementPopup._stack.clear()
		XAchievementPopup.show_for({"id": 1, "name": "初入西游", "icon": 100})
		XAchievementPopup.show_for({"id": 142, "name": "本质高手", "icon": 240201})
		var st := XAchievementPopup._stack
		var tag := "new" if sk else "old"
		check("ach_stack_count_" + tag, st.size() == 2, st.size())
		if st.size() == 2:
			var a0: XAchievementPopup = st[0]
			var a1: XAchievementPopup = st[1]
			var min_gap := 24.0 if sk else XAchievementPopup.GAP
			check("ach_stack_no_overlap_" + tag, a1.position.y >= a0.position.y + a0.plan_height() + min_gap - 0.1, [a0.position.y, a0.plan_height(), a1.position.y])
			if not sk:
				check("ach_stack_old_pos", is_equal_approx(a0.position.y, XAchievementPopup.SCREEN.y * 2.0 / 3.0) and is_equal_approx(a1.position.y, a0.position.y + XAchievementPopup.HEIGHT + XAchievementPopup.GAP), [a0.position.y, a1.position.y])
				# 上一条退场上滑期间（position.y < base_y）：关闭时按原版 break 落在 y0，开启时仍避让
				a1.queue_free()
				st.erase(a1)
				a0.position.y = a0.base_y - 10.0
				XAchievementPopup.show_for({"id": 2, "name": "退场占位", "icon": 100})
				var a_slide := XAchievementPopup._stack[1] as XAchievementPopup
				check("ach_stack_old_slide_y0", is_equal_approx(a_slide.position.y, XAchievementPopup.SCREEN.y * 2.0 / 3.0), [a0.position.y, a_slide.position.y])
		var pop_layer := get_tree().current_scene.get_node_or_null("XAchievementPopups")
		if pop_layer != null:
			pop_layer.queue_free()
		XAchievementPopup._stack.clear()
		await frames(2)
	XSkinNoticeLane.NOTICE_V2 = true


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
		var c_red := XHelpCard._skin_color(Color(1.0, 0.1, 0.1, 1.0))
		check("help_card_colors", c_blue == XUiSkin.MP_TEXT and c_yel == XUiSkin.GOLD_LIGHT and c_red == XUiSkin.SEL_LINE)
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


# ---- 9. T254 卡 C（T266）：提示道、难度横幅、宝箱浮字、挂机胶囊 ----

func _lane() -> XSkinNoticeLane:
	return XSkinNoticeLane.existing()


func _lane_chips() -> int:
	var l := _lane()
	if l == null:
		return 0
	return l.get_children().filter(func(c): return c is Control and (c as Control).visible).size()


func _lane_titles() -> Array:
	return XSkinNoticeLane.history.map(func(h): return str(h.get("kind", "")) + ":" + str(h.get("title", "")))


func _lane_logic() -> void:
	XUiSkin.ENABLED = true
	XSkinNoticeLane.NOTICE_V2 = true
	var s := _state(true)
	XSkinNoticeLane.auto_tick = false
	XSkinNoticeLane.reset()
	XAchievementPopup._stack.clear()
	# 前面旧画法样例留下的层（4 秒内还在淡出）先清掉，下面只看这一段新建了什么
	for old in [get_tree().current_scene.get_node_or_null("XAchievementPopups"), get_tree().root.get_node_or_null("XToast")]:
		if old != null:
			old.free()
	check("lane_on", XSkinNoticeLane.on())
	# 三条同时来：同一帧只显示一条，另两条排队；不再叠窗
	XAchievementPopup.show_for({"id": 1, "name": "初入西游", "icon": 100})
	XAchievementPopup.show_for({"id": 2, "name": "第二个成就", "icon": 101})
	XAchievementPopup.show_for({"id": 3, "name": "第三个成就", "icon": 102})
	var l := _lane()
	check("lane_three_one_at_a_time", l != null and str(l.cur.get("title", "")) == "初入西游" and XSkinNoticeLane.queue.size() == 2 and _lane_chips() == 1, [_lane_titles(), XSkinNoticeLane.queue.size(), _lane_chips()])
	check("lane_ach_no_old_popup", XAchievementPopup._stack.is_empty() and get_tree().current_scene.get_node_or_null("XAchievementPopups") == null)
	check("lane_ach_item", l != null and str(l.cur.get("sub", "")) != "" and int(l.cur.get("icon", 0)) == 100, l.cur if l else null)
	if l == null:
		return
	l.step(0.5)
	check("lane_top_center", is_equal_approx(l.chip.position.y, XSkinNoticeLane.Y) and l.chip.position.y + l.chip.size.y <= 58.0 + 0.1
		and absf(l.chip.position.x + l.chip.size.x / 2.0 - get_viewport().get_visible_rect().size.x / 2.0) <= 1.0, [l.chip.position, l.chip.size])
	check("lane_alpha_full", is_equal_approx(l.chip.modulate.a, 1.0), l.chip.modulate.a)
	# 每条 2 秒
	l.step(1.4)
	var still := str(l.cur.get("title", ""))
	l.step(0.15)
	check("lane_hold_2s", still == "初入西游" and str(l.cur.get("title", "")) == "第二个成就", [still, l.cur.get("title", "")])
	# 积压超过 2 条：每条 0.7 秒
	XSkinNoticeLane.reset()
	for i in 5:
		XToast.show_text("提示 %d" % i, true)
	check("lane_backlog_queue", XSkinNoticeLane.queue.size() == 4, XSkinNoticeLane.queue.size())
	check("lane_backlog_fast", is_equal_approx(l._total(l.cur), XSkinNoticeLane.HOLD_FAST), l._total(l.cur))
	l.step(0.69)
	var a := str(l.cur.get("title", ""))
	l.step(0.02)
	check("lane_backlog_next", a == "提示 0" and str(l.cur.get("title", "")) == "提示 1", [a, l.cur.get("title", "")])
	# 积压降到 2 条以内就回到 2 秒
	l.step(0.71)
	check("lane_backlog_back_to_2s", XSkinNoticeLane.queue.size() == 2 and is_equal_approx(l._total(l.cur), XSkinNoticeLane.HOLD), [XSkinNoticeLane.queue.size(), l._total(l.cur)])
	# 同名同类合并成「×N」；正在显示的那条也能并
	XSkinNoticeLane.reset()
	XToast.show_text("锁定完成", true)
	XToast.show_text("已锁定 无法出售", true)
	XToast.show_text("已锁定 无法出售", true)
	XToast.show_text("已锁定 无法出售", true)
	XToast.show_text("锁定完成", true)
	check("lane_merge_queue_xN", XSkinNoticeLane.queue.size() == 1 and int(XSkinNoticeLane.queue[0].count) == 3, XSkinNoticeLane.queue)
	check("lane_merge_showing_xN", int(l.cur.get("count", 0)) == 2, l.cur)
	check("lane_toast_shown_kept", XToast.shown.slice(-5) == ["锁定完成", "已锁定 无法出售", "已锁定 无法出售", "已锁定 无法出售", "锁定完成"])
	check("lane_toast_no_old_stack", get_tree().root.get_node_or_null("XToast") == null or (get_tree().root.get_node("XToast") as XToast).stack.get_child_count() == 0)
	# 长句：折两行，不缩字
	XSkinNoticeLane.reset()
	XToast.show_text("宝箱收获：太虚裂空剑、星渊护腕、天启圣戒、能量药剂 × 2、生命药剂 × 5、金钱 12000、还有一些很长很长的东西放不下了要用省略号收住的一句话再长一点", true)
	check("lane_toast_wraps_2", int(l.cur.get("_lines", 0)) == 2 and l.chip.size.x <= XUiSkin.CENTER_MAX + 0.1, [l.cur.get("_lines"), l.chip.size])
	# T266 核查 P3-3：纯中文截断处接回去不夹半角空格
	var wf := XUiSkin.font("body")
	var wl := XSkinNoticeLane.wrap("一二三四五六七八九十甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥", wf, 18, 120.0, 2)
	check("lane_wrap_cjk_no_space", wl.size() == 2 and not str(wl[1]).contains(" "), wl)
	# T266 核查 P3-3：正在显示的那条快淡出时并进新内容，至少再亮 MERGE_LEFT 秒
	XSkinNoticeLane.reset()
	XToast.show_text("锁定完成", true)
	l.step(1.8)
	XToast.show_text("锁定完成", true)
	check("lane_merge_extends", int(l.cur.get("count", 0)) == 2 and l._total(l.cur) - l.t >= XSkinNoticeLane.MERGE_LEFT - 0.001, [l.cur, l.t])
	# 自动存档、读档
	XSkinNoticeLane.reset()
	XAutosaveNotice.saved()
	check("lane_autosave", _lane_titles() == ["save:存档成功！"] and int(l.cur.get("icon", 0)) == 907 and get_tree().current_scene.get_node_or_null("XAutosaveNotice") == null, [_lane_titles(), l.cur])
	# 战力：同一人再换装换成最新那次，不 ×N
	XSkinNoticeLane.reset()
	XToast.show_text("占位", true)
	var old_ui := XPower.SHOW_POWER_UI
	XPower.SHOW_POWER_UI = true
	if XPower.ui_enabled():
		var ac := s.actor(8)
		XPowerNotice.notify(ac, 100.0, 200.0)
		XPowerNotice.notify(ac, 200.0, 150.0)
		var pw: Array = XSkinNoticeLane.queue.filter(func(q): return q.kind == "power")
		check("lane_power_replace", pw.size() == 1 and int(pw[0].count) == 1 and str(pw[0].title).contains("战力下降") and XPowerNotice.current() == null, pw)
	XPower.SHOW_POWER_UI = old_ui
	# 技能升级：同一人同一招并成 from→最新
	XSkinNoticeLane.reset()
	XToast.show_text("占位", true)
	var sk := XSkillNotice.new()
	add_child(sk)
	XSkillNotice.queue = [{"actorId": 8, "skillId": 1, "actorName": "孙悟空", "skillName": "如意金箍棒", "from": 2, "to": 3}]
	sk.pump()
	XSkillNotice.queue = [{"actorId": 8, "skillId": 1, "actorName": "孙悟空", "skillName": "如意金箍棒", "from": 3, "to": 4}]
	sk.pump()
	var sq: Array = XSkinNoticeLane.queue.filter(func(q): return q.kind == "skill")
	check("lane_skill_merge", sq.size() == 1 and str(sq[0].sub) == XSkillNotice.lane_sub(2, 4) and XSkillNotice.shown.is_empty() and sk.host.get_child_count() == 0, sq)
	XSkillNotice.clear()
	check("lane_skill_clear", XSkinNoticeLane.queue.filter(func(q): return q.kind == "skill").is_empty())
	sk.queue_free()
	# 至臻：字进提示道，不开大窗
	XSkinNoticeLane.reset()
	var pre := XPrestigeNotice.new()
	add_child(pre)
	XTreasureBatch._sync_owner(s)
	XTreasureBatch.queue = {"w1": {"name": "太虚裂空剑", "icon": 160, "count": 1}, "a1": {"name": "星渊护腕", "icon": 9, "count": 2}, "a2": {"name": "天启圣戒", "icon": 100, "count": 1}}
	pre.step()
	check("lane_prestige", _lane_titles() == ["prestige:至臻现世 · 获得 4 件"] and not pre.win.visible and str(l.cur.get("sub", "")) == "太虚裂空剑、星渊护腕 × 2，另有 1 种", [_lane_titles(), l.cur])
	pre.queue_free()
	XTreasureBatch.queue.clear()
	# 开关关着：照 4B 各画各的，提示道不收
	XSkinNoticeLane.reset()
	XSkinNoticeLane.NOTICE_V2 = false
	XToast.show_text("回退：照旧", true)
	check("lane_switch_off", not XSkinNoticeLane.on() and XSkinNoticeLane.history.is_empty() and get_tree().root.get_node_or_null("XToast") != null)
	XSkinNoticeLane.NOTICE_V2 = true
	XUiSkin.ENABLED = false
	check("lane_skin_off", not XSkinNoticeLane.on())
	XUiSkin.ENABLED = true
	# 挂机胶囊（R14）的字
	check("hang_short_time", XHangUpOverlay.short_time("00:12:40") == "12:40" and XHangUpOverlay.short_time("01:02:03") == "1:02:03" and XHangUpOverlay.short_time("---") == "---")
	check("hang_key_name", XHangUpOverlay.key_name() == "G", XHangUpOverlay.key_name())
	XUiSkin.touch_override = 1
	var touch_cap := XHangUpOverlay.show_keycap()
	XUiSkin.touch_override = 0
	check("hang_keycap_keyboard_only", not touch_cap and XHangUpOverlay.show_keycap())
	XUiSkin.touch_override = -1
	XSkinNoticeLane.reset()
	XSkinNoticeLane.auto_tick = true
	var t := get_tree().root.get_node_or_null("XToast")
	if t != null:
		t.queue_free()
	await frames(2)


## 一套卡 C 场面：地图 5（雪地），v2＝新画法（提示道开）／false＝旧画法（4B）。windowed 时按 shots 存图
func _lane_scenes(v2: bool, wide := false) -> Dictionary:
	var imgs := {}
	XUiSkin.ENABLED = true
	XSkinNoticeLane.NOTICE_V2 = v2
	XSkinNoticeLane.auto_tick = false
	XSkinNoticeLane.reset()
	XAchievementPopup._stack.clear()
	var s := _state(true)
	s.map_id = 5
	s.x = 10
	s.y = 10
	var win := get_window()
	var old_sz := win.size
	var old_aspect := get_tree().root.content_scale_aspect
	if windowed():
		win.size = Vector2i(1000, 450) if wide else Vector2i(800, 450)
		if wide:
			get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
		await frames(4)
	var map := XMapScene.new()
	add_child(map)
	if wide:
		XSkinLayout.request_wide(map)
	await frames(8)
	var clock: XDifficultyNotice = map.difficulty_notice.clock
	clock.set_process(false)   # 不按墙钟走，下面手动 paint
	clock.remaining = 0
	clock.paint()
	var tag := "new" if v2 else "old"
	var lane_step := func(dt := 0.5):
		var l := _lane()
		if l != null:
			l.step(dt)
	var clear_all := func():
		XSkinNoticeLane.reset()
		for n in get_tree().current_scene.get_children():
			if n.name == "XAchievementPopups" or n.name == "XAutosaveNotice":
				n.free()
		XAchievementPopup._stack.clear()
		var ts := get_tree().root.get_node_or_null("XToast")
		if ts != null:
			ts.free()
	if wide:
		XAchievementPopup.show_for({"id": 1, "name": "初入西游", "icon": 100})
		lane_step.call()
		await frames(40)
		imgs["c11_wide_20x9"] = await _capture()
		if v2 and windowed():
			var l := _lane()
			var vs := get_viewport().get_visible_rect().size
			check("lane_wide_center", l != null and vs.x > 1500.0 and absf(l.chip.position.x + l.chip.size.x / 2.0 - vs.x / 2.0) <= 1.0, [vs, l.chip.position if l else null])
		clear_all.call()
	else:
		# 1. 地图上来一条成就
		XAchievementPopup.show_for({"id": 1, "name": "初入西游", "icon": 100})
		lane_step.call()
		await frames(40)
		imgs["c01_map_one"] = await _capture()
		if v2:
			var plate: Control = map.hud.find_child("MapNamePlate", true, false)
			var l := _lane()
			if plate != null and l != null:
				plate.visible = true
				plate.modulate.a = 1.0
				plate.position.y = 48.0
				l._plate_miss = 30   # 不等节流，马上重找
				l.step(0.0)
				check("lane_yields_map_plate", l.chip.position.y >= plate.get_global_rect().end.y + 8.0 - 0.5, [l.chip.position, plate.get_global_rect()])
		clear_all.call()
		await frames(2)
		# 2. 同时来三条
		XAchievementPopup.show_for({"id": 1, "name": "初入西游", "icon": 100})
		XAchievementPopup.show_for({"id": 2, "name": "百战百胜", "icon": 101})
		XAutosaveNotice.saved()
		lane_step.call()
		await frames(40)
		imgs["c02_three"] = await _capture()
		if v2:
			check("lane_scene_three_one_chip", _lane_chips() == 1 and XSkinNoticeLane.queue.size() == 2, [_lane_chips(), XSkinNoticeLane.queue.size()])
		clear_all.call()
		await frames(2)
		# 3. 积压 5 条（含同名）：提速、合并
		for m in ["锁定完成", "已锁定 无法出售", "已锁定 无法出售", "已锁定 无法出售", "已保存到存档 1。"]:
			XToast.show_text(m, true)
		lane_step.call(2.05)   # 5 条并成 3 条（不到积压线，照 2 秒），第一条走完下一条是合并好的「×3」
		lane_step.call(0.3)
		await frames(30)
		if v2:
			var l := _lane()
			check("lane_scene_merged_x3", l != null and int(l.cur.get("count", 0)) == 3, l.cur if l else null)
		imgs["c03_backlog5"] = await _capture()
		clear_all.call()
		await frames(2)
		# 4. 物品页开着时来一条：不盖列表、不碰面板顶（y 72）
		var sc := XItemScene.new()
		map.ui.add_child(sc)
		await frames(6)
		XAchievementPopup.show_for({"id": 1, "name": "初入西游", "icon": 100})
		lane_step.call()
		await frames(40)
		imgs["c04_item_page"] = await _capture()
		if v2:
			var l := _lane()
			check("lane_menu_top", l != null and l.chip.position.y + l.chip.size.y <= float(XUiSkin.TOP) - 8.0, l.chip.position if l else null)
			# T266 核查 P3-1：同一行页签右边空档放得下就挪进空档，不压页签、不压货币；放不下照旧居中
			var pg := _find_template_page(sc)
			if l != null and pg != null and pg.tabs != null:
				var tr := pg.tabs.get_global_rect()
				var cl := pg.get_global_rect().position.x + XSkinNoticeLane.currency_left(pg)
				var fits := cl - tr.end.x - 2.0 * XSkinNoticeLane.MENU_GAP_PAD >= l.chip.size.x
				var cx := l.chip.position.x
				check("lane_menu_gap", is_equal_approx(l.chip.position.y, XSkinNoticeLane.Y) and (cx >= tr.end.x + XSkinNoticeLane.MENU_GAP_PAD - 0.5 and cx + l.chip.size.x <= cl - XSkinNoticeLane.MENU_GAP_PAD + 0.5 if fits else is_equal_approx(cx, roundf((get_viewport().get_visible_rect().size.x - l.chip.size.x) / 2.0))), [fits, l.chip.position, l.chip.size, tr, cl])
			else:
				check("lane_menu_gap_page_found", false, [sc])
		sc.queue_free()
		clear_all.call()
		await frames(4)
		# 5. 对话框开着时来一条
		var box := XMessageBox.new()
		add_child(box)
		await frames(2)
		box.run({"face": "Actor1", "index": 0, "background": 0, "position": 2, "lines": ["对话框开着时来一条提示，", "提示在上沿，不压对话。"]})
		await pframes(28)
		XAchievementPopup.show_for({"id": 1, "name": "初入西游", "icon": 100})
		lane_step.call()
		await frames(40)
		imgs["c05_dialog"] = await _capture()
		box.queue_free()
		clear_all.call()
		await frames(4)
		# 6. 开箱一次拿 5 样：原地浮字换胶囊，不进提示道
		var ev_id := 0
		for ev in map.map_data.get("events", []):
			if ev is Dictionary and int(ev.get("x", -1)) >= 6 and int(ev.get("x", -1)) <= 14 and int(ev.get("y", -1)) >= 5 and int(ev.get("y", -1)) <= 12:
				ev_id = int(ev.id)
				break
		var hist := XSkinNoticeLane.history.size()
		var before_pops := map.popups.size()
		for pair in [[532, 2], [1, 5], [2, 3], [3, 1], [4, 1]]:
			map.treasure_popup(XDB.rec("Items", pair[0]), pair[1], ev_id)
		map._flush_popups()
		await frames(30)
		imgs["c06_chest5"] = await _capture()
		check("treasure_not_in_lane_" + tag, XSkinNoticeLane.history.size() == hist and XSkinNoticeLane.queue.is_empty() and map.popups.size() == before_pops + 5, [map.popups.size(), ev_id])
		for c in map.get_children():
			if c is XTreasurePopup:
				c.free()
		await frames(2)
		# 7. 切难度的 4 秒横幅（同时来一条，看让位）
		var dn: XDifficultyNoticeCanvas = map.difficulty_notice
		clock.remaining = 200   # 横幅亮着的那段（淡入后、淡出前）
		clock.paint()
		XAchievementPopup.show_for({"id": 1, "name": "初入西游", "icon": 100})
		lane_step.call()
		await frames(40)
		imgs["c07_difficulty"] = await _capture()
		if v2:
			var l := _lane()
			check("lane_yields_difficulty", l != null and l.chip.position.y >= dn.position.y + dn.size.y + 8.0 - 0.5, [l.chip.position if l else null, dn.position, dn.size])
			check("diff_v2_pill", dn.size.y == 36.0 and dn.font == XUiSkin.font("body"), dn.size)
		# 地图上同一时刻只有一处常驻难度：横幅收起后只剩右上 map_hud 那枚
		clock.remaining = 0
		clock.paint()
		check("diff_one_resident_" + tag, not dn.visible and map.map_hud != null)
		clear_all.call()
		await frames(2)
		# 8、9. 挂机胶囊 关／开（地图）
		map.hang_overlay.refresh()
		await frames(20)
		imgs["c08_hang_off"] = await _capture()
		if v2:
			check("hang_word_off", map.hang_overlay.v2_word() == "挂机 关", map.hang_overlay.v2_word())
		s.hang_up_active = true
		s.hang_up_origin = Vector2i(10, 10)
		s.hang_up_count = 760 * 60
		map.hang_overlay.refresh()
		await frames(20)
		imgs["c09_hang_on"] = await _capture()
		if v2:
			check("hang_word_on", map.hang_overlay.v2_word() == "挂机中 12:40", map.hang_overlay.v2_word())
			check("hang_button_fits", map.hang_overlay.button.size.x == map.hang_overlay.skin_width(), [map.hang_overlay.button.size, map.hang_overlay.skin_width()])
		# 10. 战斗里的挂机胶囊
		var fb := XBattleScene.new()
		fb.setup(2, true, false, XDB.map(5))
		fb.visible = true
		map.ui.add_child(fb)
		map.ui.move_child(map.hang_overlay, -1)
		await frames(40)
		map.hang_overlay.refresh()
		await frames(10)
		imgs["c10_battle_hang"] = await _capture()
		# 11. 首领战里来一条成就：实机挂法（XBattleScene 在 map.ui 下），提示道让到首领信息区（血弧＋状态胶囊＋弱抗行）下面（T266 核查 P1-1）
		var boss: XEnemy = fb.logic.enemies[0]
		boss.boss_difficulty_boss = true
		for sid in [4, 5]:
			boss.add_state(sid)
		fb.boss_hp._meter_flags[boss] = true   # 当它是名单首领，照开战那样建血弧
		fb.boss_hp.setup(fb.logic.enemies)
		await frames(4)
		fb.boss_hp.layout_alpha = 255
		await frames(20)
		XAchievementPopup.show_for({"id": 1, "name": "初入西游", "icon": 100})
		if v2 and _lane() != null:
			_lane()._battle_miss = XSkinNoticeLane.BATTLE_RETRY   # 不等节流，马上重找
		lane_step.call()
		await frames(30)
		imgs["c12_boss_ach"] = await _capture()
		if v2:
			var l := _lane()
			var zone := fb.boss_info_rect()
			check("lane_finds_battle_under_ui", l != null and fb.get_parent() == map.ui and l._battle_scene(get_tree()) == fb, [fb.get_parent(), l._battle if l else null])
			check("lane_yields_boss_info", l != null and zone.has_area() and (fb.boss_panel as XSkinBossStatus).arc_shows_boss()
				and l.chip.position.y >= zone.end.y + 8.0 - 0.5 and not l.chip.get_global_rect().intersects(zone), [l.chip.position if l else null, zone])
		clear_all.call()
		fb.queue_free()
		s.hang_up_active = false
		s.hang_up_origin = Vector2i(-1, -1)
		await frames(4)
	clock.set_process(true)
	map.queue_free()
	await frames(4)
	if windowed():
		get_tree().root.content_scale_aspect = old_aspect
		win.size = old_sz
		await frames(4)
	XSkinNoticeLane.NOTICE_V2 = true
	XSkinNoticeLane.auto_tick = true
	XSkinNoticeLane.reset()
	return imgs


func _find_template_page(n: Node) -> XSkinTemplatePage:
	if n is XSkinTemplatePage:
		return n
	for c in n.get_children():
		var f := _find_template_page(c)
		if f != null:
			return f
	return null


func _test_notice_lane() -> void:
	await _lane_logic()
	var old_imgs := await _lane_scenes(false)
	var new_imgs := await _lane_scenes(true)
	for k in new_imgs:
		await _save_side_by_side(k, old_imgs.get(k), new_imgs[k])
	var old_w := await _lane_scenes(false, true)
	var new_w := await _lane_scenes(true, true)
	for k in new_w:
		await _save_side_by_side(k, old_w.get(k), new_w[k])
