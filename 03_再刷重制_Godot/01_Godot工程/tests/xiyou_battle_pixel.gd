extends Node
## 战斗画面像素对照（rules-battle-pixel，八戒）：与原版参照 ui_reference/battle_pixel_ref.cjs 同一场面——难度 3、队伍 1/8/9/10
## （学夹具技能 6168/5980/5548，1 号另学 2571/2786）、敌群 4（【守层者】里德，敌人 6 在 MOG_BossHP 名单里）。两边都把战斗背景
## 涂黑（原版背景是上一场景快照、Godot 是地图快照，不能比）。截图名同原版：
## bp_boss_input（指令窗出现后 60 帧）→ bp_states（Boss 沉默 6、1 号黑暗 5，回合都定 4；90 帧后）→ bp_enemy_select（普通攻击选敌 40 帧）
## → 取消 30 帧 → 伤害数字（Boss 12345、1 号 321、2 号暴击 4567）bp_popup_f6／f20／f40。
## 无头时只核场面能走到；窗口模式加 -- --out=<目录> 截图并写 bp_nodes.json，再用 ui_reference/battle_pixel_compare.py 比。
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
	XEnemy.force_roll = 100.0
	seed(20261110)
	var s := XState.new_game(3, 1, [8, 9, 10])
	for a in s.members():
		for id in [6168, 5980, 5548] + ([2571, 2786] if a.actor_id in [1, 2, 3, 4, 5, 6, 7, 52] else []):
			a.learn_skill(id)
		a.refresh_passive()
		a.param_mark_dirty()
		a.recover_all()
	s.random_master = XRandomStream.hex64(20261110)
	var b := XBattleScene.new()
	b.setup(4, true, false, {})
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
		_finish()
		return
	_check("boss_bar_built", b.boss_hp != null and b.boss_hp.battler != null and int(b.boss_hp.battler.data().id) == 6)
	# 名字难度色（EnemyNameColorByDifficulty：难度 3 天蓝 #4499ff；原版读数 bp_boss_input 名字像素 (68,153,255)）
	_check("boss_bar_name_color", b.boss_hp.name_color() == Color("#4499ff"), b.boss_hp.name_color().to_html())
	_check("boss_panel_name_color", b.boss_panel.name_ink("【守层者】里德") == Color("#4499ff") and b.boss_panel.name_ink("【守层者】里") == XBossStatusPanel.INK)
	# 开战 TP 原版夹具 Math.random 恒 0.5 → 12；这里照抄，右侧状态的数字才一样
	for a in b.logic.actors:
		a.tp = 12.0
	b._refresh_status()
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
	# 伤害数字位图宽（O-待定 WIDE_TEXT）：原版读数（battle_pixel_ref.cjs info.popups／info.font）位图宽 96／60／192＝28 号字宽＋10，
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
