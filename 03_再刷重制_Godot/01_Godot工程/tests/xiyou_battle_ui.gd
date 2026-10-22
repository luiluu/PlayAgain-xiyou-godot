extends Node
## 战斗画面验收：与原版参照（04_验证/本地结果/原版参照/40～43，地图 5、队伍 狗逍遥/修/罗琳/美娜、敌群 2）同一场面，
## 核对站位、窗口矩形与操作流程。内存新游戏，不写任何存档。窗口模式加 -- --out=<目录> 截图。

const MAP_SCENE := "res://modes/xiyou/map/map_scene.tscn"
var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
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


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func _until(cond: Callable, n := 900) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	get_viewport().push_input(e)
	await _frames(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	get_viewport().push_input(r)
	await _frames(2)


func _run() -> void:
	XMessageBox.auto = true
	XEnemy.force_roll = 100.0
	seed(20261013)
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.random_master = "2026101300000001"
	s.gain_item(1, 5)
	# 战斗物品窗口与物品页共用 XItemMarks.apply_list：置顶的在最前、名字带标记；不记看过（item_list_oracle.json）
	s.gain_item(5, 2)
	s.flags.TopItem = [5]
	s.flags.ItemSpLock = [1]
	# 先手美娜的唯一战技「寒锋」要求武器类型 1，默认水果刀（类型 0）在正式版也放不了（wtype_probe）；换成类型 1 的剃须刀
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
	var res := {"value": null}
	var go := func(): res.value = await map.start_battle(2, true, false)
	go.call()
	ok = await _until(func(): return _battle(map) != null and _battle(map).cmd_win != null)
	_check("command_shown", ok)
	var b: XBattleScene = _battle(map)
	if b == null:
		_finish()
		return
	# 此夹具要操作美娜的寒锋（需 5 TP）；开战 TP 是本场 rule 的 0～24 随机，显式补足操作前提。
	var cold := XDB.rec("Skills", 3644)
	_check("skill_fixture_user", b._active == s.actor(10), null if b._active == null else b._active.actor_id)
	s.actor(10).tp = maxf(s.actor(10).tp, float(b.logic.skill_cost(s.actor(10), cold).tp))
	_check("skill_fixture_usable", b.logic.can_use(s.actor(10), cold), {"tp": s.actor(10).tp, "cost": b.logic.skill_cost(s.actor(10), cold)})
	# 站位（原版运行时：角色 x 819，y 230/329/427/526；敌人 = 敌群坐标 y + 48）
	var homes := b.logic.actors.map(func(a): return b.sprites[a].home)
	_check("actor_column", homes == [Vector2(819, 230), Vector2(819, 329), Vector2(819, 427), Vector2(819, 526)], homes)
	var ehomes := b.logic.enemies.map(func(e): return b.sprites[e].home)
	_check("enemy_reposition", ehomes == [Vector2(262, 331), Vector2(201, 463), Vector2(353, 409)], ehomes)
	_check("five_layout", XBattleScene.party_layout(5) == [Vector2(769, 216), Vector2(869, 297), Vector2(769, 378), Vector2(869, 459), Vector2(769, 540)], XBattleScene.party_layout(5))
	_check("actor_scale", is_equal_approx(b.sprites[b.logic.actors[0]].body_scale, 0.75))
	await _frames(30)
	await _shot("battle_40_input")
	await _message_101(b)
	# 指令窗（原版：851,462,220,196；6 条居中）
	var cw: XBattleList = b.cmd_win
	_check("command_rect", [cw.position, cw.size] == [Vector2(851, 462), Vector2(220, 196)], [cw.position, cw.size])
	_check("command_entries", cw.entries.map(func(e): return e.text) == ["攻击", "战技", "魔法", "防御", "物品", "逃跑"], cw.entries.map(func(e): return e.text))
	# 战技 → 技能列表（原版：830,478,450,51）
	await _press("ui_down")
	await _press("ui_accept")
	await _frames(5)
	var lw: XBattleList = b.list_win
	_check("skill_list_open", lw != null)
	if lw:
		_check("skill_list_rect", lw.position.x == 830.0 and lw.size == Vector2(450, 29 * lw.rows + 22), [lw.position, lw.size, lw.rows])
		# HelpExtend 说明卡：选中技能的卡在列表左侧，不盖住列表（原版参照 41：卡右边 ≈ 列表左边 −28）
		var hc: XHelpCard = b.help_card
		_check("skill_help_card", hc != null and hc.visible and hc.rows.size() > 0 and str(hc.rows[0][0]) == str(lw.entries[lw.index].text), null if hc == null else hc.rows.slice(0, 1))
		if hc:
			_check("skill_help_card_left_of_list", hc.position.x + hc.size.x + 10 <= lw.position.x and hc.position.y >= 0 and hc.position.y + hc.size.y <= 720, [hc.position, hc.size])
	await _shot("battle_41_skill")
	await _press("ui_cancel")
	await _frames(3)
	_check("list_cancel_back_to_command", b.list_win == null and b.cmd_win != null and b.cmd_win.active)
	await _press("ui_up")
	await _press("ui_accept")
	await _frames(10)
	_check("target_mode", b._target_mode == "enemy")
	var target: XEnemy = b._hover
	_check("target_defaults_to_rightmost", target != null and b.sprites[target].home.x == 353)
	_check("only_selected_cursor", b.sprites.values().filter(func(v): return v.selected).size() == 1 and b.sprites[target].cursor != null)
	_check("target_hides_help_card", b.help_card == null or not b.help_card.visible)
	_check("auto_controls_clear_of_otb", b.auto_btn.get_global_rect().end.y < b.otb.position.y)
	await _shot("battle_42_target")
	await _press("ui_left")
	_check("keyboard_target_changes", b._hover != target and b.sprites[b._hover].selected and not b.sprites[target].selected)
	await _press("ui_cancel")
	_check("target_cancel_returns", b._target_mode == "" and b.cmd_win != null and b.cmd_win.visible and b.sprites.values().all(func(v): return not v.selected))
	await _press("ui_down")
	await _press("ui_accept")
	await _press("ui_accept")
	_check("skill_opens_target", b._target_mode == "enemy")
	await _press("ui_cancel")
	_check("skill_target_cancel_to_list", b._target_mode == "" and b.list_win != null and b.list_win.active and not b.cmd_win.active)
	await _press("ui_cancel")
	_check("skill_list_second_cancel_to_command", b.list_win == null and b.cmd_win != null and b.cmd_win.active)
	# 物品列表 → 我方目标；取消不消耗药水，目标状态条左移 24。
	for i in range(3):
		await _press("ui_down")
	await _press("ui_accept")
	_check("item_list_open", b.list_win != null)
	if b.list_win:
		var texts: Array = b.list_win.entries.map(func(e): return e.text)
		_check("item_list_marks_order", texts.size() == 2 and texts[0] == "止血草[置顶]" and texts[1] == "治疗药水(小)[锁定]" and b.list_win.index == 0, texts)
		_check("item_list_not_marked_seen", s.is_new(XDB.rec("Items", 5)) and s.is_new(XDB.rec("Items", 1)))
	await _shot("battle_43_item")
	await _press("ui_accept")
	_check("item_targets_ally", b._target_mode == "ally" and b.sprites[b._hover].cursor != null and b.status_rows[b._hover].selected)
	await _shot("battle_43b_ally_target")
	await _press("ui_cancel")
	_check("item_target_cancel_to_list", b.list_win != null and b.list_win.active and s.item_count(1) == 5)
	await _press("ui_cancel")
	for i in range(4):
		await _press("ui_up")
	await _press("ui_accept")
	target = b._hover
	var hp := target.hp
	await _press("ui_accept")
	ok = await _until(func(): return b._target_mode == "" and target.hp < hp)
	_check("keyboard_target_confirm_attacks", ok, [hp, target.hp])
	await _frames(4)
	await _shot("battle_48_attack")
	await _frames(16)
	await _shot("battle_48b_popup")
	_check("action_log_shown", b._log_lines.size() == 1 and b._log_lines[0].simple)
	# MOG_ComboCounter：打中显示「N 击中」（参照 48_attack_f42「1 击中」），数字中心 (115−30×位数+30×i, 135)、底图 (118,124)
	ok = await _until(func(): return b.combo.hits >= 1 and b.combo.layout_alpha == 255 and b.combo.digits.size() == 1)
	_check("combo_counts_in_battle", ok and b.combo.position == b._origin and b.combo.digits[0].dx == -30.0, [b.combo.hits, b.combo.digits])
	_combo_rules()
	# 真实打完这一战（同原版参照 45～47：敌人 HP 设为 1 后普通攻击），截取胜利镜头与结算
	# 循环上限只是防死循环；美娜装上武器后约需 62 轮，留足余量
	for i in range(200):
		for e in b.logic.enemies:
			if e.is_alive():
				e.hp = 1.0
		if b.logic.is_won():
			break
		if b.cmd_win != null and b.cmd_win.active and b._target_mode == "":
			await _press("ui_accept")
			await _frames(3)
			if b._target_mode != "":
				await _press("ui_accept")
		await _frames(10)
	ok = await _until(func(): return b.ui.get_children().any(func(c): return c is XVictoryScreen), 900)
	_check("real_victory_screen", ok)
	await get_tree().create_timer(0.5).timeout
	await _shot("battle_46_victory_window")
	await get_tree().create_timer(4.0).timeout
	await _shot("battle_47_victory_later")
	var vs: XVictoryScreen = b.ui.get_children().filter(func(c): return c is XVictoryScreen)[0] if ok else null
	if vs:
		vs.queue_free()
	# 五人结算与空掉落：第五行仍在画面内，不画虚构的「没有获得物品」。
	var members: Array = s.battle_members().duplicate()
	members.append(s.actor(2))
	var before := {}
	for a in members:
		before[a] = {"exp": a.exp_total, "level": a.level}
	var victory := XVictoryScreen.new()
	victory.setup({"gold":1234,"exp":5678,"drops":[]}, before, members, false)
	b.hide()
	map.ui.add_child(victory)
	await get_tree().create_timer(3.1).timeout
	_check("victory_five_fit", victory.rows.size() == 5 and XVictoryScreen.ROW_Y + 4 * XVictoryScreen.ROW_STEP + 72 <= 720)
	_check("victory_empty_drop_list", victory._drops.is_empty())
	await _shot("battle_44_victory_5_empty")
	_check("victory_sorted_drops", XVictoryScreen.grouped_drops([{ "kind":3,"id":2},{"kind":1,"id":2},{"kind":1,"id":1},{"kind":1,"id":2}]) == [{"kind":1,"id":1,"count":1},{"kind":1,"id":2,"count":2},{"kind":3,"id":2,"count":1}])
	_finish()


## XComboCounter 逐帧规则（不依赖战斗随机）
func _combo_rules() -> void:
	var c := XComboCounter.new()
	add_child(c)
	c.set_physics_process(false)
	var a := XActor.new()
	var e := XEnemy.new()
	c.action_started()
	for i in range(12):
		c.applied(a, e, true, 1, 100.0)
	c.step()
	var hold := c.timer == 90 and c.hits == 12 and c.total == 1200.0 and c.digits.size() == 2 and c.digits.map(func(g): return [g.n, g.dx]) == [[1, -60.0], [2, -30.0]]
	for i in range(30):
		c.step()
	hold = hold and c.timer == 90 and is_equal_approx(c.digits[0].scale, 1.0)   # 行动中不倒数；10 帧缩回 1 倍
	c.action_ended()
	for i in range(89):
		c.step()
	var counting := c.timer == 1 and c.hits == 12
	c.step()
	var reset := c.timer == 0 and c.hits == 0 and c.layout_alpha == 255
	var frames := 0
	while c.layout_alpha > 0 and frames < 100:
		c.step()
		frames += 1
	_check("combo_hold_and_fade", hold and counting and reset and frames == 26 and c.slide == 26 and c.digits.all(func(g): return g.alpha == 0), [hold, counting, reset, frames, c.slide])
	# 不带伤害类型不算；角色打敌人未命中、敌人打中角色都会打断
	c.applied(a, e, true, 0, 0.0)
	c.step()
	var no_damage := c.timer == 0 and c.hits == 0
	c.applied(a, e, true, 1, 5.0)
	c.step()
	c.applied(a, e, false, 1, 0.0)
	c.step()
	var miss_breaks := c.timer == 0 and c.hits == 0
	c.action_started()
	c.applied(a, e, true, 1, 5.0)
	c.step()
	c.applied(e, a, true, 1, 5.0)
	c.step()
	_check("combo_breaks", no_damage and miss_breaks and c.timer == 0 and c.hits == 0 and not c.acting, [no_damage, miss_breaks, c.timer, c.acting])
	c.queue_free()


func _battle(map: XMapScene) -> XBattleScene:
	for c in map.ui.get_children():
		if c is XBattleScene:
			return c
	return null


func _finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 战斗里的 101（十六层敌群 165 第 4 回合）：原版参照 battle_msg_101_formal（ui_reference 战斗夹具加同一条消息，无头像、背景 0、
## 位置 2）：消息窗 0,548,1280,172；名字框 \\n<海拉的幻影> 左对齐 0,484,298,64，黄字（\\c[6]）；右侧状态与行动顺序条照常显示。
## 另三种切片里真有的写法（八戒_45 用同一夹具截 battle_msg_101_face／_middle／_bigfont，读数见各行）：
## 带头像（三十层敌群 466 玉皇大帝，QY touxiang 2）：正文从 168 起（newLineX），名字框 0,484,272,64；
## 中间位置（敌群 825 圣劫使，位置 1）：消息窗 0,274,1280,172，无名字框；
## 放大字（敌群 831 魇脑，KH06-2_faces_MV_03 4，\\{\\{…\\}\\}\\!）：名字框 0,484,220,64，正文 168 起。
## 敌群事件只在回合里跑（没有指令窗），这里先收起指令窗模拟回合中，确认后再放回。
func _message_101(b: XBattleScene) -> void:
	# 原版窗口层 Window_Message 在 Window_OTBDisplay 之后：消息窗压在行动顺序条上（头像盖住条左端），也在敌人血条（z 5）之上
	_check("msg101_above_otb", b.message.z_index >= b.otb.z_index and b.message.get_index() > b.otb.get_index() and b.message.get_parent() == b.otb.get_parent(),
		[b.message.z_index, b.otb.z_index, b.message.get_index(), b.otb.get_index()])
	# 伤害数字在战斗图（z 0）与敌人血条（z 5）之上、窗口层（消息窗 8、帮助卡 10）之下：弹出时消息窗不被数字盖住
	_check("popup_below_windows", XBattleScene.POPUP_Z > 5 and XBattleScene.POPUP_Z < b.message.z_index, [XBattleScene.POPUP_Z, b.message.z_index])
	await _message_case(b, "msg101", {"face": "", "index": 0, "background": 0, "position": 2, "lines": ["\\n<海拉的幻影>很久没有打的这么尽兴了，哈哈哈。"]},
		Rect2(0, 548, 1280, 172), Rect2(0, 484, 298, 64), 0.0, "battle_49_message_101")
	await _message_case(b, "msg101_face", {"face": "QY touxiang", "index": 2, "background": 0, "position": 2, "lines": ["\\n<玉皇大帝>你确实很强，不过到此为止了！"]},
		Rect2(0, 548, 1280, 172), Rect2(0, 484, 272, 64), 168.0, "battle_49b_message_101_face")
	await _message_case(b, "msg101_middle", {"face": "", "index": 0, "background": 0, "position": 1, "lines": ["天空中的圣雷积攒到了极限"]},
		Rect2(0, 274, 1280, 172), Rect2(), 0.0, "battle_49c_message_101_middle")
	await _message_case(b, "msg101_bigfont", {"face": "KH06-2_faces_MV_03", "index": 4, "background": 0, "position": 2, "lines": ["\\n<魇脑>\\{\\{前所未有的兴奋！\\}\\}\\!"]},
		Rect2(0, 548, 1280, 172), Rect2(0, 484, 220, 64), 168.0, "battle_49d_message_101_bigfont")


## name_rect 为空时应没有名字框；left 是正文起点（有头像时 168）
func _message_case(b: XBattleScene, tag: String, msg: Dictionary, rect: Rect2, name_rect: Rect2, left: float, shot: String) -> void:
	var cw: XBattleList = b.cmd_win
	cw.active = false
	cw.hide()
	var done := {"v": false}
	var go := func():
		await b.message.run(msg)
		done.v = true
	go.call()
	var shown := await _until(func(): return b.message.win.openness >= 255 and (b.message._state == null or b.message.win.pause))
	await _frames(40)
	var w := b.message.win
	var nw := b.message.name_win
	var origin: Vector2 = b.message.global_position
	_check(tag + "_shown", shown)
	_check(tag + "_rect", Rect2(origin + w.position, w.size) == rect, [origin + w.position, w.size])
	if name_rect.has_area():
		_check(tag + "_name_rect", nw.visible and nw.openness >= 255 and Rect2(origin + nw.position, nw.size) == name_rect, [origin + nw.position, nw.size, nw.openness])
	else:
		_check(tag + "_no_name", not nw.visible or nw.openness == 0, [nw.visible, nw.openness])
	if left > 0.0:
		var xs: Array = b.message._page_glyphs.filter(func(g): return g.has("t")).map(func(g): return float(g.x))
		_check(tag + "_text_left", not xs.is_empty() and xs.min() == left, xs.slice(0, 3))
	await _shot(shot)
	# \\! 停住时按一次继续，文字完再按一次关闭
	for i in range(3):
		if done.v:
			break
		await _press("ui_accept")
		await _until(func(): return done.v or b.message.win.pause, 120)
	_check(tag + "_closed", await _until(func(): return done.v and w.openness == 0 and nw.openness == 0, 120), [done.v, w.openness, nw.openness])
	cw.show()
	cw.active = true
	await _frames(2)
