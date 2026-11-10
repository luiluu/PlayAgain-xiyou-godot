extends Node
## 战斗画面像素对照（rules-battle-pixel，八戒）：与原版参照 ui_reference/battle_pixel_ref.cjs 同一场面——难度 3、队伍 1/8/9/10
## （学夹具技能 6168/5980/5548，1 号另学 2571/2786）、敌群 4（【守层者】里德，敌人 6 在 MOG_BossHP 名单里）。两边都把战斗背景
## 涂黑（原版背景是上一场景快照、Godot 是地图快照，不能比）。截图名同原版：
## bp_boss_input（指令窗出现后 60 帧）→ bp_states（Boss 沉默 6、1 号黑暗 5，回合都定 4；90 帧后）→ bp_enemy_select（普通攻击选敌 40 帧）
## → 取消 30 帧 → 伤害数字（Boss 12345、1 号 321、2 号暴击 4567）bp_popup_f6／f20／f40。
## 无头时只核场面能走到；窗口模式加 -- --out=<目录> 截图并写 bp_nodes.json，再用 ui_reference/battle_pixel_compare.py 比。
## 二期（rules-battle-pixel2）：敌群 2（三只嘤嘤怪）四个场面，各开一场新战斗，同 battle_pixel_ref.cjs 的 layout／anim／victory／defeat：
## bp2_layout（站位，指令窗出现后 60 帧）；bp2_anim_f4／f12／f24（敌人 1 号放动画 14、1 号角色放动画 1）；
## bp2_victory_zoom_f60／bp2_victory_win_f40／f300（敌人全灭、藏起后直接走胜利）；bp2_defeat_f30／f90（全员 0 血后走全灭）。
## 内存新游戏，不写任何存档。

var results := []
var out_dir := ""
var nodes := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _physics(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _until(cond: Callable, n := 900) -> bool:
	for i in range(n):
		if cond.call():
			return true
		await get_tree().physics_frame
	return false


func _press(action: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		get_viewport().push_input(e)
		await _physics(3)


func _shot(name: String, b: XBattleScene) -> void:
	nodes[name] = _dump(b)
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	_check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


## 读数：Boss 血条位置与数字、状态格当前图标、伤害数字（位置、文字）
func _dump(b: XBattleScene) -> Dictionary:
	var d := {"popups": []}
	if b.boss_hp != null:
		d.boss = {"pos": [b.boss_hp.global_position.x, b.boss_hp.global_position.y], "alpha": b.boss_hp.layout_alpha, "red": b.boss_hp.hp_red}
	d.enemy_icons = []
	for e in b.gauges:
		var g: Dictionary = b.gauges[e]
		d.enemy_icons.append({"shown": XEnemyStateIcon.shown(g.icons), "alpha": g.name_alpha, "group": XEnemyStateIcon.group(e)})
	for bt in b._popups.keys():
		for p in b._popups[bt]:
			if is_instance_valid(p):
				d.popups.append({"pos": [p.global_position.x, p.global_position.y], "text": str(p.get("text")), "scale": [p.scale.x, p.scale.y], "alpha": p.modulate.a})
	return d


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_battle_pixel"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.set_flag("CombatDamageShow", true)
	XConfig.set_flag("CombatSkillAnimation", true)
	XEnemy.force_roll = 100.0
	seed(20261110)
	var b := await _open(4)
	if b == null:
		_finish()
		return
	_check("boss_bar_built", b.boss_hp != null and b.boss_hp.battler != null and int(b.boss_hp.battler.data().id) == 6)
	# 名字难度色（EnemyNameColorByDifficulty：难度 3 天蓝 #4499ff；原版读数 bp_boss_input 名字像素 (68,153,255)）
	_check("boss_bar_name_color", b.boss_hp.name_color() == Color("#4499ff"), b.boss_hp.name_color().to_html())
	_check("boss_panel_name_color", b.boss_panel.name_ink("【守层者】里德") == Color("#4499ff") and b.boss_panel.name_ink("【守层者】里") == XBossStatusPanel.INK)
	await _physics(60)
	await _shot("bp_boss_input", b)
	var boss: XBattler = b.logic.enemies[0]
	var a1: XBattler = b.logic.actors[0]
	var a2: XBattler = b.logic.actors[1]
	boss.add_state(6)
	boss.state_turns[6] = 4
	a1.add_state(5)
	a1.state_turns[5] = 4
	b._refresh_status()
	_check("states_added", boss.is_state_affected(6) and a1.is_state_affected(5))
	await _physics(90)
	await _shot("bp_states", b)
	await _press("ui_accept")  # 指令窗第一项「攻击」→ 选敌
	await _physics(40)
	_check("enemy_select", b._target_mode == "enemy", b._target_mode)
	await _shot("bp_enemy_select", b)
	await _press("ui_cancel")
	await _physics(30)
	_check("back_to_command", b.cmd_win != null and b.cmd_win.active)
	b._popup(boss, 12345, false)
	b._popup(a1, 321, false)
	b._popup(a2, 4567, true)
	var k0 := Engine.get_physics_frames()
	for f in [6, 20, 40]:
		await _until(func(): return Engine.get_physics_frames() >= k0 + f)
		await _shot("bp_popup_f%d" % f, b)
	_check("popups_shown", nodes.bp_popup_f6.popups.size() == 3, nodes.bp_popup_f6.popups.size())
	# 伤害数字位图宽（O-252 WIDE_TEXT）：原版读数（battle_pixel_ref.cjs info.popups／info.font）位图宽 96／60／192＝28 号字宽＋10，
	# 38 号「1.23万」实宽 117.41。修好时按 38 号量、不压；回退照原版按 28 号量、横向压到位图宽。
	var sample := {"1.23万": 96.0, "321": 60.0, "暴击  4567  ！": 192.0}
	var probe := XDamagePopup.new()
	probe._font = XUI.font()
	var wide := {}
	var narrow := {}
	for txt in sample:
		probe.text = txt
		XDamagePopup.WIDE_TEXT = false
		narrow[txt] = [probe.bitmap_width(), probe.squeeze()]
		XDamagePopup.WIDE_TEXT = true
		wide[txt] = [probe.bitmap_width(), probe.squeeze()]
	probe.free()
	_check("popup_squeeze_original", sample.keys().all(func(k): return absf(floorf(narrow[k][0]) - sample[k]) <= 1.0 and narrow[k][1] < 0.9), narrow)
	_check("popup_wide_fixed", sample.keys().all(func(k): return wide[k][1] == 1.0 and wide[k][0] > sample[k] + 10.0), wide)
	_check("popup_font_width_38", absf(wide["1.23万"][0] - 10.0 - 117.41) <= 2.0, wide["1.23万"][0] - 10.0)
	await _close(b)
	await _layout()
	await _anim()
	await _victory()
	await _defeat()
	if out_dir != "" and DisplayServer.get_name() != "headless":
		FileAccess.open(out_dir.path_join("bp_nodes.json"), FileAccess.WRITE).store_string(JSON.stringify(nodes, "  "))
	_finish()


func _finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 开一场新战斗（难度 3、队伍 1/8/9/10、夹具技能），背景涂黑，等到指令窗；开战 TP 定 12（原版夹具 Math.random 恒 0.5）
func _open(troop: int) -> XBattleScene:
	var s := XState.new_game(3, 1, [8, 9, 10])
	for a in s.members():
		for id in [6168, 5980, 5548] + ([2571, 2786] if a.actor_id in [1, 2, 3, 4, 5, 6, 7, 52] else []):
			a.learn_skill(id)
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	s.random_master = XRandomStream.hex64(20261110)
	var b := XBattleScene.new()
	b.setup(troop, true, false, {})
	add_child(b)
	# 背景涂黑：底色 ColorRect 改纯黑，背景图藏起
	for c in b.get_children():
		if c is ColorRect:
			c.color = Color.BLACK
		elif c is TextureRect:
			c.visible = false
	var ok := await _until(func(): return b.cmd_win != null and b.cmd_win.active)
	_check("command_shown", ok)
	if not ok:
		return null
	for a in b.logic.actors:
		a.tp = 12.0
	b._refresh_status()
	return b


func _close(b: XBattleScene) -> void:
	b.bgm.stop()
	b.queue_free()
	await _physics(2)


## 精灵读数：位置（原点在脚下中点，同 MV Sprite_Battler x/y）、原位
func _sprites(b: XBattleScene) -> Dictionary:
	var d := {"enemies": [], "actors": []}
	for e in b.logic.enemies:
		var sp: XBattlerSprite = b.sprites[e]
		d.enemies.append({"pos": [sp.global_position.x, sp.global_position.y], "home": [sp.home.x, sp.home.y], "visible": sp.visible})
	for a in b.logic.actors:
		var sp: XBattlerSprite = b.sprites[a]
		d.actors.append({"pos": [sp.global_position.x, sp.global_position.y], "home": [sp.home.x, sp.home.y], "motion": sp.motion})
	return d


## 右侧状态格轮换的图标（同原版读数 _cqRows 的图标列）
func _cq(b: XBattleScene) -> Array:
	var out := []
	for a in b.status_rows:
		out.append({"actor": a.actor_id, "icons": b.status_rows[a]._icons()})
	return out


## 站位：敌群 2 三只嘤嘤怪（原版 home (262,331)／(353,409)／(201,463)），角色 x 819、y 230／329／427／526
func _layout() -> void:
	var b := await _open(2)
	if b == null:
		return
	await _physics(60)
	await _shot("bp2_layout", b)
	var sp := _sprites(b)
	nodes.bp2_layout_sprites = sp
	nodes.bp2_layout_cq = _cq(b)
	# 状态格轮换内容与顺序：原版读数 _cqRows 图标 1035→579→4210（破阵——天道诅咒〔异常〕、难度适应、普通难度·结算伤害〔常驻，拼音序〕；
	# rules-passive-order1 起比顺序，原来只比集合）
	_check("cell_icons_layout", nodes.bp2_layout_cq[0].icons == [1035, 579, 4210], nodes.bp2_layout_cq[0])
	# visibleState：越战越勇（34，有图标没说明）原版不进状态格；强化接在后面、层数＝等级
	var a1: XActor = b.logic.actors[0]
	a1.add_state(34)
	a1.buffs[2] = 2
	var rows := XSideStatus.cell_rows(a1)
	var ids: Array = rows.map(func(r): return r.icon)
	_check("cell_hides_no_description", int(XDB.rec("States", 34).iconIndex) > 0 and not ids.has(int(XDB.rec("States", 34).iconIndex)), ids)
	# 强化按类别「增益」排在常驻前（rules-passive-order1），不再是最后一行
	_check("cell_buff_stack", rows.has({"icon": XEnemyStateIcon.buff_icon(2, 2), "stack": 2}), rows)
	XSideStatus.CELL_FILTER = false
	var raw: Array = XSideStatus.cell_rows(a1).map(func(r): return r.icon)
	XSideStatus.CELL_FILTER = true
	_check("cell_filter_rollback", raw.has(int(XDB.rec("States", 34).iconIndex)) and not raw.has(XEnemyStateIcon.buff_icon(2, 2)), raw)
	a1.remove_state(34)
	a1.buffs[2] = 0
	# 原版读数按精灵绘制顺序列出，这里按敌群成员顺序，比集合
	var homes: Array = sp.enemies.map(func(x): return x.home)
	_check("layout_enemies", homes.size() == 3 and [[262.0, 331.0], [353.0, 409.0], [201.0, 463.0]].all(func(h): return h in homes), sp.enemies)
	_check("layout_actors", sp.actors.map(func(x): return x.home) == [[819.0, 230.0], [819.0, 329.0], [819.0, 427.0], [819.0, 526.0]], sp.actors)
	await _close(b)


## 技能动画层：敌人 1 号放动画 14（突刺/冰）、1 号角色放动画 1（打击/物理），第 4／12／24 帧截图
func _anim() -> void:
	var b := await _open(2)
	if b == null:
		return
	await _physics(10)
	var ae := b._start_animation(14, b.logic.enemies[0])
	var aa := b._start_animation(1, b.logic.actors[0])
	_check("anim_started", ae != null and aa != null)
	if ae == null or aa == null:
		await _close(b)
		return
	# 截图时刻按动画自己推进的帧数对齐（原版读数 f4／f12／f24 时动画 14 剩余 45／37／25 帧、动画 1 剩余 17／9），
	# 动画改成手动推进，不受截图等待里多走的物理帧影响
	ae.external = true
	aa.external = true
	var done := 0
	var durs := {}
	for f in [4, 12, 24]:
		while done < f:
			for a in [ae, aa]:
				if is_instance_valid(a):
					a.tick()
			done += 1
		durs[f] = [ae.duration if is_instance_valid(ae) else -1, aa.duration if is_instance_valid(aa) else -1]
		await _shot("bp2_anim_f%d" % f, b)
	_check("anim_durations", durs[4] == [45, 17] and durs[12] == [37, 9] and durs[24][0] == 25, durs)
	await _close(b)


## 胜利：敌人全灭、放倒下效果（原版 performCollapse），直接走胜利（镜头 300 帧放大到 2 倍、结算画面）
func _victory() -> void:
	var b := await _open(2)
	if b == null:
		return
	await _physics(30)
	# 原版夹具 Math.random 恒 0.5：三只嘤嘤怪都不掉东西；重制的掉落抽签不同，这里先定成不掉。
	# 难度经验／金钱倍率 O-130（默认开）原版没有，比画面时关掉：原版读数 精魄 580、经验值 480
	var o130 := XBattleLogic.o_difficulty_reward
	XBattleLogic.o_difficulty_reward = false
	for e in b.logic.enemies:
		b.logic._treasure[b.logic.stable_id(e)] = []
		e.hp = 0.0
		e.add_state(1)
		b._collapse_visual(e)  # 同原版 performCollapse
	b._victory()
	XBattleLogic.o_difficulty_reward = o130
	var k0 := Engine.get_physics_frames()
	await _until(func(): return Engine.get_physics_frames() >= k0 + 60)
	await _shot("bp2_victory_zoom_f60", b)
	var ok := await _until(func(): return b.ui.get_children().any(func(c): return c is XVictoryScreen), 600)
	_check("victory_screen", ok)
	nodes.bp2_victory_window_at = Engine.get_physics_frames() - k0
	await _physics(40)
	await _shot("bp2_victory_win_f40", b)
	# 结算画面的动画按画面出现后的帧数走：两边都在出现后第 40、300 帧截（原版出现时刻靠 setTimeout 真实时间，无头时帧数不准）
	await _physics(260)
	await _shot("bp2_victory_win_f300", b)
	nodes.bp2_victory_sprites = _sprites(b)
	_check("victory_zoom_done", is_equal_approx(b._camera.get("scale", 0.0), 2.0) and int(b._camera.get("t", 0)) >= 300, b._camera.get("t", null))
	await _close(b)


## 全灭：全员 0 血、倒下，走 processDefeat（消息窗「狗逍遥的队伍被击败了。」等按键）
func _defeat() -> void:
	var b := await _open(2)
	if b == null:
		return
	await _physics(30)
	for a in b.logic.actors:
		a.hp = 0.0
		a.add_state(1)
	b._refresh_status()
	b._defeat()
	await _physics(30)
	await _shot("bp2_defeat_f30", b)
	_check("defeat_text", b.defeat_text() == "狗逍遥的队伍被击败了。", b.defeat_text())
	_check("defeat_message_shown", b.message.visible and b.message._busy)
	await _physics(60)
	await _shot("bp2_defeat_f90", b)
	_check("defeat_otb_hidden", not b.otb.visible or b.otb.modulate.a == 0.0, b.otb.modulate.a)
	nodes.bp2_defeat_sprites = _sprites(b)
	nodes.bp2_defeat_cq = _cq(b)
	await _close(b)
