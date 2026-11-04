extends Node
## Boss 状态面板（Codex_BossStatusSummary v0.4.0，XBossStatus／XBossStatusPanel）：分类、回合文字、排序、Boss 判定、
## 点击翻页、Esc、点击不穿透、接进真战斗画面。原版读数来自 ?battle_ref=1 夹具（敌 6 当 Boss，状态 4、5、10，
## 强化物攻 5 回合、弱化物防 5 回合）：异常 4（黑暗 4回合、睡眠 4回合、物防弱化 1层·5回合、中毒 本场战斗），增益 1（物攻强化 1层·5回合）。
## 位置：折叠栏 (105,131.5) 440×96，详情在折叠栏下 6 格 480×400。窗口模式加 -- --out=<目录> 截图。
var checks := 0
var failures: Array = []
var out_dir := ""


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw(false)
	check("screenshot_" + name, get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png")) == OK)


func key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		get_viewport().push_input(e)
		await frames(2)


func click(c: Control, p: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = p
		e.global_position = c.global_position + p
		c.gui_input.emit(e)
	await frames(2)


func names(rows: Array) -> Array:
	return rows.map(func(r): return r.name)


func _run() -> void:
	XMessageBox.auto = true
	var s := XState.new_game_blank()
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 2]:
		s.add_actor(id)
		s.actor(id).recover_all()
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	add_child(b)
	await frames(30)
	var foes: Array = b.logic.enemies
	var boss: XEnemy = foes[0]
	var other: XEnemy = foes[1] if foes.size() > 1 else null

	# 1. Boss 判定：身份、现身、存活
	check("is_boss_flag", not XBossStatus.is_boss(boss) or boss.boss_difficulty_boss)
	boss.boss_difficulty_boss = true
	check("is_boss_true", XBossStatus.is_boss(boss))
	boss.hidden = true
	check("is_boss_hidden_false", not XBossStatus.is_boss(boss))
	boss.hidden = false
	check("is_boss_non_enemy", not XBossStatus.is_boss(s.actor(1)) and not XBossStatus.is_boss(null))
	if other != null:
		other.boss_difficulty_boss = false
		check("is_boss_normal_enemy", not XBossStatus.is_boss(other))

	# 2. 分类、回合文字、排序（原版读数）
	for id in [4, 5, 10]:
		boss.add_state(id)
	boss.state_turns[10] = 4
	boss.state_turns[5] = 4
	boss.buffs[2] = 1
	boss.buff_turns[2] = 5
	boss.buffs[3] = -1
	boss.buff_turns[3] = 5
	var rows := XBossStatus.entries(boss)
	var got := rows.map(func(r): return [r.kind, r.name, r.stack, r.turns])
	check("entries_order", got == [["Debuff", "黑暗", "", "4回合"], ["Debuff", "睡眠", "", "4回合"], ["Debuff", "物防弱化", "1层", "5回合"],
		["Debuff", "中毒", "", "本场战斗"], ["Buff", "物攻强化", "1层", "5回合"]], got)
	check("buff_description", rows[2].description == "物防-" + str(absf(snappedf((boss.param_buff_rate(3) - 1.0) * 100.0, 0.1))).trim_suffix(".0") + "%"
		or rows[2].description.begins_with("物防"), rows[2].description)
	check("state_id1_hidden", not XBossStatus.entries(boss).any(func(r): return str(r.id) == "1"))
	check("entries_null", XBossStatus.entries(null).is_empty())
	check("duration_helpers", XBossStatus.duration(0, {"autoRemovalTiming": 1}) == "行动后结束"
		and XBossStatus.duration(0, {"autoRemovalTiming": 2}) == "回合末结束"
		and XBossStatus.duration(null, {"note": "<Permanent>"}) == "常驻"
		and XBossStatus.duration(null, {}) == "持续" and XBossStatus.percent(-0.25) == "-25%" and XBossStatus.percent(0.5) == "+50%")
	check("clean_escape", XBossStatus.clean("\\c[4]黑暗<x>") == "黑暗")

	# 3. 面板接进战斗画面
	var panel: XBossStatusPanel = b.boss_panel
	check("panel_wired", panel != null and panel.is_inside_tree() and panel.position == b._origin and panel.enemies_source.is_valid())
	await frames(10)
	check("panel_visible_with_boss", panel.visible and panel.battler == boss, panel.battler)
	check("bar_position", panel.bar.position == Vector2(105, 131.5) and panel.bar.size == Vector2(440, 96), [panel.bar.position, panel.bar.size])
	check("starts_collapsed", not panel.open and not panel.detail.visible)
	check("rows_default_debuff", names(panel.rows()) == ["黑暗", "睡眠", "物防弱化", "中毒"], names(panel.rows()))
	shot("boss_status_bar")

	# 4. 点击展开、位置、标签、翻页
	await click(panel.bar, Vector2(100, 40))
	check("click_bar_opens", panel.open and panel.detail.visible)
	check("detail_position", panel.detail.position == Vector2(105, 233.5) and panel.detail.size == Vector2(480, 400), [panel.detail.position, panel.detail.size])
	check("page_size", panel.page_size() == 4, panel.page_size())
	await click(panel.detail, Vector2(240, 58))  # 第二个标签（增益）
	check("tab_buff", panel.filter == "Buff" and names(panel.rows()) == ["物攻强化"], [panel.filter, names(panel.rows())])
	await click(panel.detail, Vector2(450, 58))
	check("tab_all", panel.filter == "All" and panel.rows().size() == 5, panel.rows().size())
	# 翻页：页大小 4，全部 5 条 → 2 页
	await click(panel.detail, Vector2(400, 380))
	check("page_next", panel.page == 1, panel.page)
	await click(panel.detail, Vector2(400, 380))
	check("page_clamped_end", panel.page == 1, panel.page)
	await click(panel.detail, Vector2(40, 380))
	check("page_prev", panel.page == 0, panel.page)
	await click(panel.detail, Vector2(40, 380))
	check("page_clamped_start", panel.page == 0, panel.page)
	# 点条目看说明，页脚中间回列表
	await click(panel.detail, Vector2(240, 82 + 68 * 1 + 20))
	check("pick_item", panel.selected != null and str(panel.selected) == str(panel.rows()[1].id), panel.selected)
	shot("boss_status_detail")
	await click(panel.detail, Vector2(240, 380))
	check("back_to_list", panel.selected == null)
	# × 关闭
	await click(panel.detail, Vector2(450, 20))
	check("close_button", not panel.open and not panel.detail.visible)

	# 5. Esc 关闭
	await click(panel.bar, Vector2(100, 40))
	check("reopen", panel.open)
	await key(KEY_ESCAPE)
	check("esc_closes", not panel.open and not panel.detail.visible)
	await key(KEY_ESCAPE)
	check("esc_closed_noop", not panel.open)

	# 6. 点击不穿透：面板画布吃掉点击
	check("canvas_stop", panel.bar.mouse_filter == Control.MOUSE_FILTER_STOP and panel.detail.mouse_filter == Control.MOUSE_FILTER_STOP and panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	# 7. 多个 Boss：选目标优先，再是上一个掉血的
	if other != null:
		other.boss_difficulty_boss = true
		await frames(10)
		check("two_bosses_default_first", panel.battler == boss, panel.battler)
		b._target_mode = "enemy"
		b._hover = other
		await frames(10)
		check("target_wins", panel.battler == other and not panel.open)
		b._target_mode = ""
		b._hover = null
		await frames(10)
		other.hp = maxi(1, other.hp - 1)
		boss.hp = boss.hp
		await frames(10)
		check("last_hit_kept", panel.battler == other, panel.battler)
		other.boss_difficulty_boss = false

	# 8. 说明卡挡住折叠栏时上移
	panel.help_source = func(): return Rect2(100, 120, 300, 200)
	await frames(10)
	check("bar_moves_up", panel.bar.position.y == maxf(12.0, 120.0 - 96.0 - 8.0), panel.bar.position)
	panel.help_source = Callable()

	# 8b. 战力显示（CodexCombatPower.enemy）：已做、默认关。关时布局不变；开时展开才现算，折叠只读缓存
	check("power_default_off", not XBossStatusPanel.SHOW_POWER and panel.power_of().is_empty() and panel.power_total() == -1.0)
	XPowerEnemy.clear_cache()
	var pw := XPowerEnemy.enemy(boss)
	var jr := func(v: float): return XPower.js_round(v)
	check("power_enemy_shape", not pw.is_empty() and pw.total > 0.0 and pw.total == pw.parts[0] + pw.parts[1] and pw.parts[2] == 0.0 and pw.output > 0.0, pw)
	var avoid := (clampf(boss.eva, 0.0, 0.8) + clampf(boss.mev, 0.0, 0.8)) / 2.0
	var rate := maxf(0.02, (maxf(0.0, boss.pdr) + maxf(0.0, boss.mdr)) / 2.0) * (1.0 - avoid)
	var ehp := boss.mhp / ((XDamage.defense_rate(10000, boss.def) + XDamage.defense_rate(10000, boss.mdf)) / 2.0) / rate
	check("power_ehp_formula", absf(pw.effectiveHp - ehp) < 1e-6 * ehp and pw.parts[1] == jr.call(300.0 * pow(ehp / 1000.0, 0.5)), [pw.effectiveHp, ehp])
	check("power_output_curve", pw.parts[0] == jr.call(600.0 * pow(pw.output / 1000.0, 0.35)), pw)
	check("power_cache_hit", XPowerEnemy.enemy(boss) == pw and XPowerEnemy.cached(boss) == pw)
	var saved_hp := boss.mhp
	boss.state_ids.append(2)  # 签名含状态表：变了缓存失效
	check("power_cache_signature", XPowerEnemy.cached(boss).is_empty())
	boss.state_ids.erase(2)
	check("power_cache_back", XPowerEnemy.cached(boss) == pw and saved_hp == boss.mhp)
	check("power_format", XPower.format(pw.total).length() > 0)
	XBossStatusPanel.SHOW_POWER = true
	XPowerEnemy.clear_cache()
	panel.open = false
	check("power_closed_reads_cache_only", panel.power_of().is_empty())
	panel.open = true
	var shown := panel.power_of()
	check("power_open_computes", not shown.is_empty() and shown.total == pw.total, shown)
	panel.open = false
	check("power_closed_after_open_cached", panel.power_of().total == pw.total)
	check("power_stamp_changes", panel.power_total() == pw.total)
	XBossStatusPanel.SHOW_POWER = false
	check("power_off_again_empty", panel.power_of().is_empty() and panel.power_total() == -1.0)

	# 战力显示截图（只在窗口模式、给人看）
	XBossStatusPanel.SHOW_POWER = true
	panel.open = false
	XPowerEnemy.enemy(boss)
	panel.refresh(true)
	await frames(3)
	shot("boss_status_bar_power")
	XBossStatusPanel.SHOW_POWER = false
	panel.refresh(true)

	# 9. 死亡后消失
	boss.hp = 0
	await frames(10)
	check("hidden_when_dead", not panel.visible and panel.battler == null)

	b.queue_free()
	await frames(3)
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks}))
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)
