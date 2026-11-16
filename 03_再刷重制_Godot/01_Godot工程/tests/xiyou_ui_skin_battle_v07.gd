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
	var ok := await _until(func(): return b.cmd_win != null and b.cmd_win.active)
	_check("command_shown", ok)
	if not ok:
		_finish()
		return
	for a in b.logic.actors:
		a.tp = 12.0
	var boss: XBattler = b.logic.enemies[0]
	boss.add_state(6)
	boss.state_turns[6] = 4
	b._refresh_status()
	await _ring(b)
	await _skill_list(b)
	await _popup(b, boss)
	await _turn_cue(b)
	await _motion_off(b)
	b.bgm.stop()
	_finish()


## 指令环：球直径 64、选中 1.2 倍（Kyo 11-16）；新建时球从 0.6 长到 1、逐个错开（FULL 档）
func _ring(b: XBattleScene) -> void:
	var ring := b.cmd_win as XSkinBattleRing
	_check("ring_type", ring != null)
	if ring == null:
		return
	_check("ring_orb_64", is_equal_approx(ring.orb_r, 32.0) and XSkinBattleRing.peak() == 1.2, [ring.orb_r, ring.radius])
	var apart := true
	for i in ring.entries.size() - 1:
		apart = apart and ring.orb_pos(i).distance_to(ring.orb_pos(i + 1)) >= ring.orb_r * (1.0 + XSkinBattleRing.peak()) + 3.9
	_check("ring_selected_not_touching", apart, ring.radius)
	await _secs(0.6)
	_check("ring_sel_scale_1_2", is_equal_approx(ring.orb_scale(ring.index), 1.2) and is_equal_approx(ring.orb_scale((ring.index + 1) % ring.entries.size()), 1.0))
	_check("ring_intro_done", ring.intro_elapsed >= ring.intro_total() and ring.intro_of(ring.entries.size() - 1) == 1.0, [ring.intro_elapsed, ring.intro_total()])
	await _secs(0.5)
	await _shot("v07_ring", 2)


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
