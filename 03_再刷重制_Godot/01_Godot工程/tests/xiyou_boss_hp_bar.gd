extends Node
## Boss 血条（MOG_BossHP v2.3，XBossHpBar）：Boss 名单与头像、数字格式、淡入淡出、红条拖尾、数字追赶、震动、换目标、死亡与结束淡出、
## 接进真战斗画面、状态面板对齐。原版读数（插件参数 / 源码）：固定框 (105,45.5) 图 507×78；生命条 (22,28)；数字 (320,42) 间距 20；
## 名 (30,47) 字号 18；头像 (−50,−8)；流动 4px/帧；红条每帧 1+差/160；数字每帧 1+⌊差/30⌋；震动 80 帧 y∈[−3,+2]；淡出 −5/帧。
## 窗口模式加 -- --out=<目录> 截图。
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


func make_bar(enemies: Array) -> XBossHpBar:
	var bar := XBossHpBar.new()
	bar.set_physics_process(false)
	add_child(bar)
	bar.setup(enemies)
	return bar


func steps(bar: XBossHpBar, n: int) -> void:
	for i in n:
		bar.step()


func _run() -> void:
	# 1. 名单与头像（plugins.js：boss-1=敌6 头像 SL_TX_62；boss-17=敌21 BOSS_1；boss-16=敌28 BOSS_12）
	check("listed_6", XBossHpBar.is_listed(6))
	check("listed_21", XBossHpBar.is_listed(21) and XBossHpBar.is_listed(28))
	check("not_listed_1", not XBossHpBar.is_listed(1) and not XBossHpBar.is_listed(0))
	check("face_names", XBossHpBar.face_name(6) == "SL_TX_62" and XBossHpBar.face_name(21) == "BOSS_1" and XBossHpBar.face_name(28) == "BOSS_12")
	check("face_none_for_unlisted", XBossHpBar.face_name(1) == "")
	# 2. 位置：框 (105,45.5) 高 78，面板贴在下方 8
	check("layout_pos", XBossHpBar.layout_pos() == Vector2(105, 45.5), XBossHpBar.layout_pos())
	check("layout_bottom", XBossHpBar.layout_bottom() == 123.5)
	check("panel_anchor", XBossHpBar.layout_bottom() + 8.0 == 131.5)
	# 3. 数字格式（refresh_hp_number 的单位与小数位规则）
	var cases := {0.0: "0", 1.0: "1", 9999.0: "9999", 10000.0: "1万", 12345.0: "1.23万", 123456.0: "12.35万", 1234567.0: "123.5万",
		12345678.0: "1235万", 99999999.0: "10000万", 100000000.0: "1亿", 150000000.0: "1.5亿", 1234500000.0: "12.35亿",
		1000000000000.0: "1兆", 5.0e16: "5京", 1.0e20: "10000京", 11250.0: "1.13万", 20000.0: "2万", 100500.0: "10.05万"}
	for v in cases:
		check("fmt_%s" % v, XBossHpBar.format_number(v) == cases[v], [v, XBossHpBar.format_number(v)])
	var frames_map := {"0": 0, "9": 9, "万": 10, "亿": 11, "兆": 12, "京": 13, ".": 14}
	for ch in frames_map:
		check("frame_%s" % ch, XBossHpBar.digit_frame(ch) == frames_map[ch])

	# 4. 单个 Boss 的整条时间线
	var back := ColorRect.new()
	back.color = Color("#2b2f3a")
	back.size = Vector2(1280, 720)
	add_child(back)
	var boss := XEnemy.new().setup(6, 1)
	var minion := XEnemy.new().setup(1, 1)
	var bar := make_bar([minion, boss])
	check("picks_listed_boss", bar.battler == boss)
	check("starts_transparent_until_first_step", bar.layout_alpha == 0)
	bar.step()
	check("first_frame_full", bar.layout_alpha == 255)
	var mhp := float(boss.mhp)
	check("red_starts_full", boss.hp == mhp and bar.hp_red == mhp, [bar.hp_red, mhp])
	check("number_climbs_from_zero", bar.hp_number > 0.0 and bar.hp_number < mhp, bar.hp_number)
	steps(bar, 400)
	check("number_reaches_hp", bar.hp_number == boss.hp, [bar.hp_number, boss.hp])
	check("digits_match_number", "".join(bar.digits) == XBossHpBar.format_number(boss.hp), bar.digits)
	var f0 := bar.flow
	bar.step()
	check("flow_4px", absf(bar.flow - f0 - 4.0) < 0.001 or bar.flow == 0.0, [f0, bar.flow])
	for i in 300:
		bar.step()
		if bar.flow == 0.0:
			break
	check("flow_wraps_at_928", bar.flow == 0.0)
	# 扣血：红条拖尾（每帧 1+差/160）、蓝条即时、数字追赶（1+⌊差/30⌋）——原版节奏先关掉 O-188 的拖尾封顶量
	XBossHpBar.RED_TRAIL_CAP = false
	XBossHpBar.NUMBER_CAP = false
	var before := float(boss.hp)
	var cut := floorf(boss.mhp * 0.4)
	boss.hp -= cut
	bar.applied(boss, boss.hp)
	check("hit_sets_shake", bar._temp_shake == 80)
	var red0 := bar.hp_red
	var num0 := bar.hp_number
	bar.step()
	var expect_red := red0 - (1.0 + (red0 - boss.hp) / 160.0)
	check("red_drain_step", absf(bar.hp_red - expect_red) < 0.001, [bar.hp_red, expect_red])
	var expect_num := num0 - (1.0 + floorf((num0 - boss.hp) / 30.0))
	check("number_chase_step", bar.hp_number == expect_num, [bar.hp_number, expect_num])
	check("shake_started", bar.shake == 79)
	steps(bar, 12)
	await frames(2)
	shot("bar_hit_trail")
	var in_range := true
	for i in 40:
		bar.step()
		in_range = in_range and bar.position.y >= XBossHpBar.layout_pos().y - 3.0 and bar.position.y <= XBossHpBar.layout_pos().y + 2.0
	check("shake_y_range", in_range)
	steps(bar, 60)
	check("shake_ends_and_y_resets", bar.shake == 0 and bar.position.y == XBossHpBar.layout_pos().y, [bar.shake, bar.position.y])
	steps(bar, 4000)  # 红条指数式追，尾巴长（每帧 1+差/160）
	await frames(2)
	shot("bar_settled")
	check("red_catches_up", bar.hp_red == boss.hp and bar.hp_number == boss.hp, [bar.hp_red, bar.hp_number, boss.hp])
	# ui11 拖尾封顶：原版大差值要上千帧；开着时 90 帧内追上，小差值仍按原版（更快）
	var big := floorf(boss.hp * 0.5)
	var slow := 0
	var r := float(boss.hp)
	var tgt := r - big
	while r > tgt and slow < 100000:
		r = maxf(r - (1.0 + (r - tgt) / 160.0), tgt)
		slow += 1
	XBossHpBar.RED_TRAIL_CAP = true
	XBossHpBar.NUMBER_CAP = true
	boss.hp -= big
	bar.applied(boss, boss.hp)
	steps(bar, XBossHpBar.RED_CAP_FRAMES)
	check("red_cap_90_frames", bar.hp_red == boss.hp and slow > 600, [bar.hp_red, boss.hp, slow])
	check("number_cap_with_red", bar.hp_number == boss.hp, [bar.hp_number, boss.hp])
	# ui5 数字封顶：千万级差值原版要滚 400 帧上下；开着时 NUMBER_CAP_FRAMES 帧内到位、每帧都是整数；小差值照原版每帧 1+⌊差/30⌋
	var hi := 30000000.0
	var lo := 10000000.0
	var orig_frames := 0
	var x := hi
	while x > lo:
		x = maxf(x - (1.0 + floorf((x - lo) / 30.0)), lo)
		orig_frames += 1
	bar.hp_number = hi
	var cap_frames := 0
	var all_int := true
	while bar.hp_number > lo and cap_frames < 1000:
		bar.hp_number = maxf(bar.hp_number - bar.number_step(lo), lo)
		all_int = all_int and bar.hp_number == floorf(bar.hp_number)
		cap_frames += 1
	check("number_cap_10m", cap_frames <= XBossHpBar.NUMBER_CAP_FRAMES and orig_frames > 300 and all_int, [cap_frames, orig_frames, all_int])
	bar.hp_number = lo + 20.0
	check("number_small_diff_orig_pace", bar.number_step(lo + 10.0) == 1.0, bar.number_step(lo + 10.0))
	XBossHpBar.NUMBER_CAP = false
	bar.hp_number = hi
	check("number_cap_off_orig", bar.number_step(lo) == 1.0 + floorf((hi - lo) / 30.0))
	XBossHpBar.NUMBER_CAP = true
	steps(bar, 400)
	var r1 := bar.hp_red
	boss.hp -= 50
	bar.applied(boss, boss.hp)
	bar.step()
	check("red_cap_small_hit_original", absf(bar.hp_red - (r1 - (1.0 + 50.0 / 160.0))) < 0.001, [bar.hp_red, r1])
	# 回血不震动
	boss.hp += 100
	bar.applied(boss, boss.hp)
	check("heal_no_shake", bar._temp_shake == 0)
	boss.hp -= 100
	# 对话忙：淡出 −5/帧，松开后 +5/帧
	var busy := [true]
	bar.busy_source = func(): return busy[0]
	bar.step()
	check("fade_out_5", bar.layout_alpha == 250, bar.layout_alpha)
	steps(bar, 100)
	check("fade_out_floor_0", bar.layout_alpha == 0)
	busy[0] = false
	bar.step()
	check("fade_in_5", bar.layout_alpha == 5)
	steps(bar, 100)
	check("fade_in_cap_255", bar.layout_alpha == 255)
	# 战斗结束淡出
	bar.ended()
	steps(bar, 60)
	check("ended_fades", bar.layout_alpha == 0)
	bar.queue_free()

	# 5. Boss 死亡：淡出，之后不再出现
	var b2 := XEnemy.new().setup(6, 1)
	var bar2 := make_bar([b2])
	steps(bar2, 5)
	b2.hp = 0
	bar2.applied(b2, 0.0)
	steps(bar2, 60)
	check("dead_fades_out", bar2.layout_alpha == 0)
	bar2.queue_free()

	# 6. 没有 Boss / Boss 隐藏：不建条
	var plain := make_bar([XEnemy.new().setup(1, 1)])
	check("no_boss_no_bar", plain.battler == null and not plain.visible)
	plain.step()
	check("no_boss_step_safe", plain.layout_alpha == 0)
	plain.queue_free()
	var hid := XEnemy.new().setup(6, 1)
	hid.hidden = true
	var bh := make_bar([hid])
	check("hidden_boss_no_bar", bh.battler == null)
	bh.queue_free()

	# 7. 多个 Boss：开战取最后一个；被命中的 Boss 把条抢过去，红条／数字从命中前血量起算
	var first := XEnemy.new().setup(6, 1)
	var second := XEnemy.new().setup(28, 1)
	var bar3 := make_bar([first, second])
	check("multi_picks_last", bar3.battler == second)
	steps(bar3, 400)
	var first_hp := float(first.hp)
	first.hp -= 1000
	bar3.applied(first, first.hp)
	bar3.step()
	check("switch_target", bar3.battler == first)
	check("switch_start_from_pre_hit_hp", bar3.hp_red <= first_hp and bar3.hp_red > first_hp - 1000.0, [bar3.hp_red, first_hp])
	check("switch_name_and_face", bar3._name_text == first.original_name())
	# 非名单敌人被打不抢条
	var small := XEnemy.new().setup(1, 1)
	var bar4 := make_bar([small, first])
	bar4.applied(small, 0.0)
	bar4.step()
	check("non_boss_hit_ignored", bar4.battler == first)
	bar3.queue_free()
	bar4.queue_free()

	# 8. 接进真战斗画面
	XMessageBox.auto = true
	var s := XState.new_game_blank()
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 2]:
		s.add_actor(id)
		s.actor(id).recover_all()
	back.queue_free()
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	add_child(b)
	await frames(10)
	check("scene_has_bar", b.boss_hp != null and b.boss_hp is XBossHpBar)
	check("scene_bar_hooked", b.boss_hp.hp_source.is_valid() and b.boss_hp.busy_source.is_valid())
	check("panel_aligned_with_bar", b.boss_panel.bar.position.y == XBossHpBar.layout_bottom() + 8.0 or b.boss_panel.bar.position.y < XBossHpBar.layout_bottom() + 8.0, b.boss_panel.bar.position)
	b.queue_free()
	await frames(3)

	# 9. 战斗里有名单 Boss：条随画面出现（把敌群第一只换成名单里的敌人后重建条）
	var b3 := XBattleScene.new()
	b3.setup(2, true, false, XDB.map(5))
	add_child(b3)
	await frames(5)
	var target: XEnemy = b3.logic.enemies[0]
	target.enemy_id = 6
	target.hp = target.mhp * 0.6  # 换了敌人编号，血量跟着设成 6 成
	var holder: Node = b3.boss_hp.get_parent()
	b3.boss_hp.queue_free()
	b3.boss_hp = XBossHpBar.new()
	b3.boss_hp.hp_source = func(e): return b3.view(e)
	b3.boss_hp.busy_source = func(): return b3.message._busy
	holder.add_child(b3.boss_hp)
	b3.boss_hp.setup(b3.logic.enemies)
	await frames(120)
	check("scene_bar_shows_listed_boss", b3.boss_hp.battler == target and b3.boss_hp.layout_alpha == 255, [b3.boss_hp.battler, b3.boss_hp.layout_alpha])
	var face_file := XDB.img_path("bosshp", "SL_TX_62")
	var frame_file := XDB.img_path("bosshp", "Boss_HP_A")
	check("assets_exported", frame_file != "" and XDB.img_path("bosshp", "Boss_HP_B") != "" and XDB.img_path("bosshp", "Boss_HP_C2") != "", frame_file)
	check("face_loaded_if_exported", (b3.boss_hp._face_tex != null) == (face_file != ""), face_file)
	shot("boss_hp_bar")
	b3.queue_free()
	await frames(3)

	# 10. 冻结后跟进 v0.37 的血条范围（RANGE_V037；换源集成分支默认开（O-203），关＝v0.28 只认插件名单）
	var ext_ids := []
	for wid in XZhenqi.WEAPON_BOSS:
		if not XBossHpBar.is_listed(int(wid)):
			ext_ids.append(int(wid))
	for tid in [XZhenqi.TRIAL_TROOP["心魔"], XZhenqi.TRIAL_TROOP["天劫"], XZhenqi.HEART_TROOP[1]]:
		for m in XDB.rec("Troops", int(tid)).get("members", []):
			var mid := int(m.enemyId)
			if not XBossHpBar.is_listed(mid) and not ext_ids.has(mid):
				ext_ids.append(mid)
	check("v037_candidates_exist", not ext_ids.is_empty(), ext_ids)
	var ext_id: int = ext_ids[0]
	check("v037_default_on", XBossHpBar.RANGE_V037)
	XBossHpBar.RANGE_V037 = false
	XBossHpBar._ext_cache.clear()
	var ext_e := XEnemy.new().setup(ext_id, 1)
	var listed_e := XEnemy.new().setup(6, 1)
	var plain_e := XEnemy.new().setup(1, 1)
	check("v037_off_not_extended", not XBossHpBar.is_extended(ext_id))
	check("v037_off_no_bar", make_bar([plain_e, ext_e]).battler == null)
	check("v037_off_gauge_kept", XBossHpBar.small_gauge_visible(ext_e) == ext_e.hp_gauge_visible())
	XBossHpBar.RANGE_V037 = true
	XBossHpBar._ext_cache.clear()
	check("v037_on_extended", XBossHpBar.is_extended(ext_id))
	check("v037_on_listed_not_extended", not XBossHpBar.is_extended(6) and not XBossHpBar.is_extended(1))
	var vbar2 := make_bar([plain_e, ext_e])
	check("v037_on_picks_extended", vbar2.battler == ext_e)
	check("v037_on_face_empty", XBossHpBar.face_name(ext_id) == "" and vbar2._face_tex == null)
	check("v037_on_gauge_hidden", not XBossHpBar.small_gauge_visible(ext_e) and XBossHpBar.small_gauge_visible(plain_e) == plain_e.hp_gauge_visible())
	var vbar3 := make_bar([ext_e, listed_e, plain_e])
	check("v037_listed_wins", vbar3.battler == listed_e)
	var vbar4 := make_bar([listed_e, ext_e])
	check("v037_listed_wins_even_if_first", vbar4.battler == listed_e)
	ext_e.hidden = true
	check("v037_hidden_skipped", make_bar([plain_e, ext_e]).battler == null)
	ext_e.hidden = false
	var ext2 := XEnemy.new().setup(ext_ids[ext_ids.size() - 1], 1)
	check("v037_last_extended", make_bar([ext_e, ext2]).battler == ext2)
	vbar2.applied(ext_e, ext_e.hp - 1.0)
	check("v037_apply_tracks_extended", vbar2._temp_target == ext_e and vbar2._temp_shake == 80)
	XBossHpBar.RANGE_V037 = false
	XBossHpBar._ext_cache.clear()
	check("v037_off_again", not XBossHpBar.is_extended(ext_id) and make_bar([plain_e, ext_e]).battler == null)
	XBossHpBar.RANGE_V037 = true
	XBossHpBar._ext_cache.clear()

	# 原版缺陷修好（rules-bugfix1 照搬清单第 2 条，O-228）：变身换名字头像；开战没有 Boss、之后现身时补建条
	for rebuild in [true, false]:
		XBossHpBar.REBUILD = rebuild
		var tag := "rebuild" if rebuild else "rebuild_off"
		var tb := XEnemy.new().setup(6, 1)
		var tbar := make_bar([tb])
		tb.enemy_id = 21  # 同 battle_logic.enemy_transform
		steps(tbar, 1)
		var new_name := tb.original_name()
		check(tag + "_transform_name", (tbar._name_text == new_name) == rebuild, [tbar._name_text, new_name])
		check(tag + "_transform_face", (tbar._face_tex == XBossHpBar._tex("bosshp", "BOSS_1")) == rebuild)
		var late := XEnemy.new().setup(6, 1)
		late.hidden = true
		var plain_late := XEnemy.new().setup(1, 1)
		var lbar := make_bar([plain_late, late])
		check(tag + "_no_boss_at_start", lbar.battler == null and not lbar.visible)
		late.hidden = false  # 敌人现身（Game_Enemy.appear）
		steps(lbar, 2)
		check(tag + "_late_boss_builds", (lbar.battler == late and lbar.visible and lbar._name_text == late.original_name()) == rebuild, [lbar.battler != null, lbar.visible])
		tbar.queue_free()
		lbar.queue_free()
	XBossHpBar.REBUILD = true

	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks}))
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)
