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
	RenderingServer.force_draw(false)
	_check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func _until(cond: Callable, n := 900) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		get_viewport().push_input(e)
		await _frames(2)


## AB_EnemyBook v1.28：指令窗按 Shift 打开「怪物信息」（本场敌人；没登记的写「？？？」），取消回到指令窗
func _battle_book(b: XBattleScene) -> void:
	await _key(KEY_SHIFT)
	await _frames(3)
	var p := b.book_page
	_check("shift_opens_battle_book", p != null and p.in_battle and p.ids == [1] and not b.cmd_win.active
		and p._status_ops.any(func(o): return o[0] == "t" and o[1] == "？？？"), null if p == null else p.ids)
	await _shot("battle_42_enemy_book")
	# 窗口读数：与 ui_reference/review_system_pages.js 的 battle_book 同态，review_system_pages_compare.py 核对
	if p != null and out_dir != "" and DisplayServer.get_name() != "headless":
		var data := {"shot": "battle_42_enemy_book", "windows": {}}
		for k in ["index_win", "status_win"]:
			var w: Control = p.get(k)
			data.windows[k] = {"rect": [w.position.x, w.position.y, w.size.x, w.size.y], "visible": w.is_visible_in_tree()}
		FileAccess.open(out_dir.path_join("battle_42_enemy_book.json"), FileAccess.WRITE).store_string(JSON.stringify(data, "  "))
	await _press("ui_cancel")
	await _frames(3)
	_check("battle_book_cancel_back", b.book_page == null and b.cmd_win != null and b.cmd_win.active and b.list_win == null)


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
	s.actor(10).change_level_mv(10)  # 原版 req_level:10；一级会在 refresh 卸回背包。
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
	await _shield_side(b, s)
	await _message_101(b)
	await _race_ui(b, s)
	await _select_confirm(b, s)
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
	await _battle_book(b)
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
	await _prey_pick(b, s)
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


## 护盾侧栏（ShieldSystem 钩 Window_BattleSideHP.refresh）：原版参照 battle_shield_side（ui_reference 战斗夹具四人，
## 美娜在输入左移 48；狗逍遥 242/485＋盾 100 蓝段在条内，修 450/450＋盾 225 按 max(上限, HP＋盾) 折算，
## 罗琳 300/525＋盾 123456 写「盾12.3万」，美娜 120/480＋盾 2.5 亿写「盾2.5亿」）。原版 HP 窗口 (1080＋8, 序号×121＋28)，内边距 4。
func _shield_side(b: XBattleScene, s) -> void:
	var cfg := [[1, 242.0, 100.0, 1171, 1204, "盾100"], [8, 450.0, 225.0, 1198, 1252, "盾225"],
		[9, 300.0, 123456.0, 1092, 1252, "盾12.3万"], [10, 120.0, 250000000.0, 1044, 1204, "盾2.5亿"]]
	var keep := []
	for c in cfg:
		var a: XActor = s.actor(c[0])
		keep.append([a, a.hp, a.shield])
		a.hp = c[1]
		a.shield = c[2]
	for row in b.status_rows.values():
		row.refresh()
	await _frames(20)
	for i in cfg.size():
		var c: Array = cfg[i]
		var row: XSideStatus = b.status_rows[s.actor(c[0])]
		var seg := XSideStatus.shield_segment(row.actor.hp, row.actor.mhp, row.actor.shield, row.position.x + 8 + XSideStatus.PAD)
		_check("shield_seg_%d" % c[0], seg == Vector2i(c[3], c[4]), [seg, row.position.x])
		_check("shield_label_%d" % c[0], "盾" + XSideStatus.shield_text(c[2]) == c[5], XSideStatus.shield_text(c[2]))
	_check("shield_label_style", XSideStatus.SHIELD_COLOR == Color8(0x88, 0xcc, 0xff) and XSideStatus.SHIELD_OUTLINE == Color(0, 0, 0, 0.7)
		and XSideStatus.SHIELD_SEG == Color8(0, 136, 255, 179), [XSideStatus.SHIELD_COLOR, XSideStatus.SHIELD_OUTLINE])
	await _shot("battle_50_shield_side")
	# 窗口模式：截图上蓝段的起止列与原版 battle_shield_side 逐像素一致（行 y＝序号×121＋28＋16～21）
	if out_dir != "" and DisplayServer.get_name() != "headless":
		var img := get_viewport().get_texture().get_image()
		var blue := func(px: Color) -> bool: return px.b8 > 150 and px.r8 < 80 and px.b8 - px.g8 > 40
		for i in cfg.size():
			var c: Array = cfg[i]
			var cols := []
			for x in range(c[3] - 3, c[4] + 3):
				if blue.call(img.get_pixel(x, i * 121 + 28 + 18)):
					cols.append(x)
			_check("shield_pixels_%d" % c[0], not cols.is_empty() and cols.min() == c[3] and cols.max() == c[4] - 1, [cols.min() if cols else null, cols.max() if cols else null])
	for k in keep:
		k[0].hp = k[1]
		k[0].shield = k[2]
	for row in b.status_rows.values():
		row.refresh()


## 种族祝福（installNativeRaceRuntime；原版参照 race_blood_cmd_off／on、race_select_poison，ui_reference 战斗夹具同一场面，美娜设为魔族）：
## 魔族指令窗在「逃跑」后加「血契：关」，窗高 196→225（7 行）；确定后变「血契：开」、光标停在该行（记忆指令开）。
## 选敌时该敌人本回合记有毒鸡汤：说明卡两行「敌人名」「毒鸡汤（回合末） 名字：量」（12 号白字、品质 0 外框）；没有就不显示。
## 卡片位置照 O-107 贴在敌人旁（原版从上一张卡位置漂移）。做完把种族、毒鸡汤与指令记忆恢复，后面的流程不受影响。
func _race_ui(b: XBattleScene, s: XState) -> void:
	var a := s.actor(10)
	var before: Dictionary = XRace.data(s, a).duplicate()
	s.race.actors["10"] = {"race": 3, "rank": 7, "free": false, "blood": false, "legacy": []}
	XRace.sync(s, a)
	b._picked.emit("back")  # 重新进指令（_command 重画指令窗）
	await _frames(5)
	var cw: XBattleList = b.cmd_win
	_check("race_blood_entries", cw != null and cw.entries.map(func(e): return e.text) == ["攻击", "战技", "魔法", "防御", "物品", "逃跑", "血契：关"],
		null if cw == null else cw.entries.map(func(e): return e.text))
	_check("race_blood_rect", cw != null and [cw.position, cw.size] == [Vector2(851, 462), Vector2(220, 225)], null if cw == null else [cw.position, cw.size])
	await _shot("battle_51_race_blood_off")
	for i in range(6):
		await _press("ui_down")
	await _press("ui_accept")
	await _frames(5)
	cw = b.cmd_win
	_check("race_blood_on", cw != null and str(cw.entries[6].text) == "血契：开" and cw.index == 6 and bool(XRace.data(s, a).blood),
		null if cw == null else [cw.entries[6].text, cw.index])
	await _shot("battle_51b_race_blood_on")
	# 毒鸡汤说明卡：在最右的敌人身上记一笔本回合的毒鸡汤（狗逍遥 115）
	var e: XEnemy = b.logic.enemies.filter(func(x): return b.sprites[x].home.x == 353)[0]
	var pid := int(XRace.config().poisons[0])
	e.state_ids.append(pid)
	var owner := s.actor(1)
	XRaceBattle.state(b.logic, owner).poison.append({"target": e, "id": pid, "amount": 115.0, "turn": XRaceBattle.turn(b.logic)})
	a.last_command = "attack"  # 光标回到「攻击」
	b._picked.emit("back")
	await _frames(5)
	await _press("ui_accept")  # 攻击 → 选敌（默认最右）
	await _frames(10)
	var hc: XHelpCard = b.help_card
	var want := e.display_name() + "\n毒鸡汤（回合末） " + owner.display_name() + "：115"
	_check("race_poison_card", hc != null and hc.visible and hc.rows.size() == 1 and str(hc.rows[0][0]) == want and int(hc.rows[0][1]) == 12,
		null if hc == null else [hc.visible, hc.rows])
	if hc:
		_check("race_poison_card_beside_enemy", not Rect2(hc.position, hc.size).intersects(Rect2(b._origin + b.sprites[e].position - Vector2(88, 40), Vector2(176, 60))),
			[hc.position, hc.size, b.sprites[e].position])
	await _shot("battle_51c_race_poison_card")
	await _press("ui_left")
	_check("race_poison_card_hides", b._hover != e and not b.help_card.visible)
	await _press("ui_cancel")
	await _frames(5)
	# 恢复
	XRaceBattle.state(b.logic, owner).poison.clear()
	e.state_ids.erase(pid)
	s.race.actors["10"] = before
	XRace.sync(s, a)
	a.last_command = ""
	b._picked.emit("back")
	await _frames(5)


## 指令窗光标移到某技能类型，打开列表并确定该技能（列表顺序同 battle_skills 按类型筛）。
## 返回列表里的序号（确定后列表就关了，要先记下）；没找到返回 -1。
func _choose_skill(b: XBattleScene, a: XActor, id: int) -> int:
	var sk := XDB.rec("Skills", id)
	var keys: Array = b._command_entries(a).map(func(e): return str(e.key))
	var ci := keys.find("stype:%d" % int(sk.stypeId))
	if ci < 0 or b.cmd_win == null:
		return -1
	b.cmd_win.select(ci)
	await _press("ui_accept")
	await _frames(3)
	var list := b.logic.battle_skills(a).filter(func(x): return int(x.stypeId) == int(sk.stypeId))
	var idx := list.find_custom(func(x): return int(x.id) == id)
	if b.list_win == null or idx < 0:
		return -1
	b.list_win.select(idx)
	await _press("ui_accept")
	await _frames(5)
	return idx


## YEP Select Help Window（原版参照 selhelp_all_enemies／random_enemy／user／all_allies，ui_reference 战斗夹具同一场面）：技能／物品确定后，
## 除 scope 0 外都先进选目标（onSelectAction 的 forceSelection）。全体／随机敌人：选敌、光标可移动、默认最右、只亮光标那只；
## 自身：锁在行动者；全体我方：锁在第 1 位。帮助窗不出字（说明卡没有 setBattler，YEP 抛错被吞），取消回技能列表原位。
## 攻击指令（YEP_WeaponUnleash commandAttack）先判 needsSelection，不受强制。做完恢复技能与 MP。
func _select_confirm(b: XBattleScene, s: XState) -> void:
	var a := s.actor(10)
	var ids := a.skill_ids.duplicate()
	var mp := a.mp
	var last := [a.last_command, a.last_battle_skill]
	for id in [10, 306, 108]:
		a.learn_skill(id)
	a.mp = a.mmp
	b._picked.emit("back")
	await _frames(5)
	for c in [[10, "enemy", "all_enemies"], [306, "ally", "user"], [108, "ally", "all_allies"]]:
		var tag: String = c[2]
		var idx := await _choose_skill(b, a, c[0])
		var ok := idx >= 0
		_check("selhelp_%s_mode" % tag, ok and b._target_mode == c[1], [ok, b._target_mode])
		_check("selhelp_%s_no_help_text" % tag, b.help_card == null or not b.help_card.visible)
		_check("selhelp_%s_one_cursor" % tag, b.sprites.values().filter(func(v): return v.selected).size() == 1)
		var first = b._hover
		match tag:
			"all_enemies":
				_check("selhelp_all_enemies_rightmost", first is XEnemy and b.sprites[first].home.x == 353)
				await _shot("battle_52_selhelp_all_enemies")
				await _press("ui_left")
				_check("selhelp_all_enemies_cursor_moves", b._hover is XEnemy and b._hover != first)
			"user":
				_check("selhelp_user_self", first == a)
				await _shot("battle_52b_selhelp_user")
			"all_allies":
				_check("selhelp_all_allies_first", first == b.logic.actors[0])
				await _shot("battle_52c_selhelp_all_allies")
		if tag != "all_enemies":
			await _press("ui_down")
			_check("selhelp_%s_locked" % tag, b._hover == first)
		await _press("ui_cancel")
		await _frames(3)
		_check("selhelp_%s_cancel_to_list" % tag, b._target_mode == "" and b.list_win != null and b.list_win.active and b.list_win.index == idx,
			[b._target_mode, null if b.list_win == null else b.list_win.index, idx])
		await _press("ui_cancel")
		await _frames(3)
	# 攻击指令：全体范围的攻击技能也不进选目标
	var r = await b._pick_target({"id": 0, "scope": 2, "damage": {"type": 1}}, a, false)
	_check("selhelp_attack_not_forced", r == a and b._target_mode == "")
	a.skill_ids = ids
	a.mp = mp
	a.last_command = last[0]  # 选过技能类型会记进指令记忆，不恢复的话后面的指令窗光标会停在「魔法」
	a.last_battle_skill = last[1]
	b._picked.emit("back")
	await _frames(5)


## 妖族群攻手选猎物（种族 R:258／259）：妖族放全体伤害技能（闪电）时进选敌，默认最右；换一只确定后，行动打全体、猎物就是选中的那只。
## 用此刻轮到的角色，做完把种族改回。
func _prey_pick(b: XBattleScene, s: XState) -> void:
	var ok := await _until(func(): return b.cmd_win != null and b.cmd_win.active and b._target_mode == "" and b._active is XActor)
	_check("prey_pick_ready", ok)
	if not ok:
		return
	var a: XActor = b._active
	var key := str(a.actor_id)
	var before = s.race.actors.get(key)
	var last := [a.last_command, a.last_battle_skill]
	s.race.actors[key] = {"race": 1, "rank": 7, "free": false, "blood": false, "legacy": []}
	XRace.sync(s, a)
	a.learn_skill(10)
	a.mp = a.mmp
	b._picked.emit("back")
	await _frames(5)
	ok = (await _choose_skill(b, a, 10)) >= 0
	var first = b._hover
	_check("prey_pick_enemy_mode", ok and b._target_mode == "enemy" and first is XEnemy and b.sprites[first].home.x == b.logic.alive(b.logic.enemies).map(func(e): return b.sprites[e].home.x).max(),
		[ok, b._target_mode])
	await _press("ui_left")
	var chosen = b._hover
	_check("prey_pick_moves", chosen is XEnemy and chosen != first)
	await _shot("battle_53_prey_pick")
	await _press("ui_accept")
	ok = await _until(func(): return XRaceBattle.state(b.logic, a).lastPrey != null)
	_check("prey_pick_is_chosen", ok and XRaceBattle.state(b.logic, a).lastPrey == chosen,
		[ok, null if chosen == null else chosen.display_name()])
	await _until(func(): return b.logic.is_won() or (b.cmd_win != null and b.cmd_win.active))
	if before == null:
		s.race.actors.erase(key)
	else:
		s.race.actors[key] = before
	XRace.sync(s, a)
	a.last_command = last[0]  # 后面的胜利循环按「攻击」确定
	a.last_battle_skill = last[1]
