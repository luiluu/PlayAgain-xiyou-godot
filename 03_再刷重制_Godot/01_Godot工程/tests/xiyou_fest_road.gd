extends Node
## 冠军庆典·冠军之路（XFest＋XFestRoad）专项：
## 一、四关顺序与队名、五人敌群站位放得下、敌人记录（名字、图、能力值逐关变强、不掉东西、不变神话）、辅助「应援」；
## 二、实建战斗（XBattleLogic.setup）五只敌人都在；
## 三、流程：四关顺序开战、不能逃、可输、势如破竹层数 0→1→2→3 与伤害倍率、场间暂停一次（三成、复活）、输了回满可接着打；
## 四、奖励：每关首胜 30 币只发一次、四关全胜「冠军之路」、一次不败「一穿四」＋100 币只发一次、接着打的不算不败；
## 五、活动外不可进（开始前、结束后、收尾期）；开关关掉无痕（表外记录、称号表、伤害加成、入口都没了）。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit


class MockHost:
	extends RefCounted
	var texts: Array = []
	var choices_queue: Array = []
	var battle_results: Array = []
	var battles: Array = []
	var kill_on_battle := -1  # 第几场开战前把第一个人打死（看带入与暂停复活）

	func show_text(face: String, idx: int, lines: Array) -> void:
		texts.append({"face": face, "idx": idx, "lines": lines})

	func show_text_with_choices(face: String, idx: int, lines: Array, options: Array, _cancel_type: int) -> int:
		texts.append({"face": face, "idx": idx, "lines": lines, "options": options})
		if choices_queue.is_empty():
			return 0
		return int(choices_queue.pop_front())

	func start_battle(troop_id: int, can_escape: bool, can_lose: bool, _random := false) -> int:
		var a = XState.current.battle_members()[0]
		battles.append({"troop": troop_id, "escape": can_escape, "lose": can_lose, "streak": XFestRoad.battle_streak,
			"in_road": XFestRoad.in_road_battle, "mul": _mul(a), "hp0": float(a.hp), "alive0": a.is_alive()})
		if kill_on_battle == battles.size() - 1:
			a.hp = 0.0
			a.add_state(1)
		return int(battle_results.pop_front()) if not battle_results.is_empty() else 0

	func _mul(a) -> float:
		var ops := XFestRoad.damage_ops(a)
		return float(ops[0].value) if not ops.is_empty() else 1.0


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	kit = Kit.new("xiyou_fest_road")
	XFest.TODAY_OVERRIDE = "2026-11-16"
	_records()
	_battle_setup()
	await _real_damage()
	await _flow_flawless()
	await _flow_loss_resume()
	await _pause_and_quit()
	await _small_party()
	await _two_tiers()
	await _closed_outside_event()
	await _switch_off()
	XFest.TODAY_OVERRIDE = ""
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state() -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	for id in [1, 2, 3, 4, 5]:
		if not s.party.has(id):
			s.add_actor(id)
	s.init_battle_slots()
	for i in 5:
		s.set_battle_slot(i, [1, 2, 3, 4, 5][i])
	for a in s.members():
		a.recover_all()
	return s


func _reset_config() -> void:
	var n := XConfig.designations()
	for id in [XFest.TITLE_ROAD, XFest.TITLE_ONE_FOUR]:
		n.erase(str(id))
	XConfig.save_designations()


func _records() -> void:
	var names := []
	var troop_ok := true
	var pos_ok := true
	var sprite_ok := true
	var hp_sum := []
	var atk_sum := []
	var recs_ok := true
	for st in 4:
		var t := XDB.rec("Troops", XFestRoad.troop_id(0, st))
		names.append(str(t.get("name", "")))
		var ms: Array = t.get("members", [])
		troop_ok = troop_ok and ms.size() == 5
		# 站位放得下：都在战场左半边、彼此至少隔 100 像素（帧宽 64），且和 853 号五人敌群同一范围
		for i in ms.size():
			var x := float(ms[i].x)
			var y := float(ms[i].y)
			pos_ok = pos_ok and x >= 150 and x <= 640 and y >= 200 and y <= 470
			for j in range(i + 1, ms.size()):
				pos_ok = pos_ok and Vector2(x, y).distance_to(Vector2(float(ms[j].x), float(ms[j].y))) >= 100.0
		var hp := 0.0
		var atk := 0.0
		for r in 5:
			var e := XDB.rec("Enemies", int(ms[r].enemyId))
			recs_ok = recs_ok and str(e.get("name", "")) == XFestRoad.enemy_name(st, r) and (e.dropItems as Array).is_empty() \
				and int(e.exp) == 0 and int(e.gold) == 0 and str(e.note).contains("NoElite") and not str(e.note).contains("<hp:")
			var m := RegEx.create_from_string("<Sideview Battler:\\s*([^>]+)>").search(str(e.note))
			var sp := m.get_string(1).strip_edges() if m != null else ""
			var img := XDB.img_path("sv_actors", sp)
			var tex = load(img) if img != "" and ResourceLoader.exists(img) else null
			sprite_ok = sprite_ok and tex != null and tex.get_width() / 9 <= 96 and tex.get_height() / 6 <= 96
			hp += float(e.params[0])
			atk += float(e.params[2]) + float(e.params[4])
		hp_sum.append(hp)
		atk_sum.append(atk)
	_check("four_teams_in_order", names == ["冠军之路·网吧队", "冠军之路·银河战舰队", "冠军之路·大魔王队", "冠军之路·内战幻神队"], names)
	_check("enemy_names_team_role", str(XDB.rec("Enemies", XFestRoad.enemy_id(0, 0, 0)).name) == "网吧队·上单"
		and str(XDB.rec("Enemies", XFestRoad.enemy_id(0, 3, 4)).name) == "内战幻神队·辅助")
	_check("troops_have_five", troop_ok)
	_check("five_fit_positions", pos_ok)
	_check("sprites_small_and_present", sprite_ok)
	_check("enemy_records_clean", recs_ok)
	_check("teams_get_stronger", hp_sum[0] < hp_sum[1] and hp_sum[1] < hp_sum[2] and hp_sum[2] < hp_sum[3]
		and atk_sum[0] < atk_sum[1] and atk_sum[1] < atk_sum[2] and atk_sum[2] < atk_sum[3], [hp_sum, atk_sum])
	var top := XDB.rec("Enemies", XFestRoad.enemy_id(0, 1, 0))
	var bot := XDB.rec("Enemies", XFestRoad.enemy_id(0, 1, 3))
	var jg := XDB.rec("Enemies", XFestRoad.enemy_id(0, 1, 1))
	_check("role_shapes", float(top.params[0]) > float(bot.params[0]) and float(top.params[3]) > float(bot.params[3])
		and float(bot.params[2]) > float(top.params[2]) and float(jg.params[6]) > float(top.params[6]))
	var heal := XDB.rec("Skills", XFestRoad.HEAL_SKILL)
	_check("support_heal_skill", str(heal.get("name", "")) == "应援" and int(heal.scope) == 8 and int(heal.damage.type) == 3
		and str(heal.damage.formula).contains("b.mhp"), heal.get("damage"))
	var sup := XDB.rec("Enemies", XFestRoad.enemy_id(0, 0, 4))
	_check("support_uses_heal", (sup.actions as Array).any(func(a): return int(a.skillId) == XFestRoad.HEAL_SKILL))
	# 原表不动：表外号段，表长不变
	_check("generated_tables_untouched", XDB.table("Enemies").size() < XFestRoad.ENEMY_BASE and XDB.table("Troops").size() < XFestRoad.TROOP_BASE)


func _real_damage() -> void:
	# 势如破竹真的乘进伤害：同一下普攻（打队友，避开敌人的伤害抵抗被动），3 层比 0 层多三成
	var s := _state()
	var lg := XBattleLogic.new()
	lg.setup(XFestRoad.troop_id(0, 0), s)
	var u = lg.actors[0]
	var t = lg.actors[1]
	var sk := XDB.rec("Skills", 1)
	XFestRoad.in_road_battle = true
	XFestRoad.battle_streak = 0
	var d0 := float(lg._damage_value(u, sk, t, false))
	XFestRoad.battle_streak = 3
	var d3 := float(lg._damage_value(u, sk, t, false))
	XFestRoad.in_road_battle = false
	XFestRoad.battle_streak = 0
	var d_off := float(lg._damage_value(u, sk, t, false))
	_check("streak_reaches_real_damage", d0 > 0.0 and absf(d3 / d0 - 1.3) < 0.02 and absf(d_off - d0) / d0 < 0.02, [d0, d3, d_off])
	# 辅助「应援」按目标最大生命 4% 回复
	var sup = lg.enemies[4]
	var tgt = lg.enemies[0]
	var hv := float(lg._damage_value(sup, XDB.rec("Skills", XFestRoad.HEAL_SKILL), tgt, false))
	_check("support_heal_4pct", absf(absf(hv) / float(tgt.mhp) - XFestRoad.HEAL_RATE) < 0.005, [hv, tgt.mhp])
	# 天启篇档不开
	var tq := Kit.new_game()
	var h := MockHost.new()
	h.choices_queue = [0]
	await XFestRoad.talk(h, tq)
	_check("tianqi_save_closed", h.battles.is_empty())


func _battle_setup() -> void:
	var s := _state()
	var ok := true
	var detail := []
	for st in 4:
		var lg := XBattleLogic.new()
		lg.setup(XFestRoad.troop_id(0, st), s)
		var names: Array = lg.enemies.map(func(e): return str(e.data().name))
		ok = ok and lg.enemies.size() == 5 and lg.enemies.all(func(e): return not e.elite and not e.hidden and e.hp > 0)
		detail.append(names)
	_check("battle_setup_five_enemies", ok, detail)


func _flow_flawless() -> void:
	_reset_config()
	var s := _state()
	var h := MockHost.new()
	h.choices_queue = [0, 0, 0, 0, 0]  # 从第一关开始；三次两关之间都选「继续」
	await XFestRoad.talk(h, s)
	var troops := h.battles.map(func(b): return int(b.troop))
	_check("road_order", troops == [9300, 9301, 9302, 9303], troops)
	_check("no_escape_can_lose", h.battles.all(func(b): return not b.escape and b.lose and b.in_road))
	var streaks := h.battles.map(func(b): return int(b.streak))
	var muls := h.battles.map(func(b): return snappedf(float(b.mul), 0.001))
	_check("streak_0_1_2_3", streaks == [0, 1, 2, 3], streaks)
	_check("damage_mult_by_streak", muls == [1.0, 1.1, 1.2, 1.3], muls)
	_check("streak_off_after_run", not XFestRoad.in_road_battle and XFestRoad.damage_ops(s.battle_members()[0]).is_empty())
	_check("flawless_rewards", XFest.coins(s) == 4 * XFestRoad.COIN_FIRST_WIN + XFestRoad.COIN_FLAWLESS
		and XDesignation.unlocked(XFest.TITLE_ROAD) and XDesignation.unlocked(XFest.TITLE_ONE_FOUR), XFest.coins(s))
	var p := XFestRoad.progress(s)
	_check("flawless_flags", bool(p.cleared) and bool(p.flawless_done) and int(p.next) == 4)
	# 再打一趟：庆典币不再发
	var h2 := MockHost.new()
	h2.choices_queue = [0, 0, 0, 0, 0]
	await XFestRoad.talk(h2, s)
	_check("rewards_only_once", h2.battles.size() == 4 and XFest.coins(s) == 4 * XFestRoad.COIN_FIRST_WIN + XFestRoad.COIN_FLAWLESS, XFest.coins(s))
	# 称号表列庆典称号
	var ids := XDesignation.table().map(func(d): return int(d.id))
	_check("titles_in_table", ids.has(XFest.TITLE_ROAD) and ids.has(XFest.TITLE_ONE_FOUR))
	# 活动结束后：拿到的照列，没拿到的（观赛团、全勤）不再列成 ???
	XFest.TODAY_OVERRIDE = "2027-01-01"
	var ids_after := XDesignation.table().map(func(d): return int(d.id))
	XFest.TODAY_OVERRIDE = "2026-11-16"
	_check("titles_after_event_only_owned", ids_after.has(XFest.TITLE_ROAD) and ids_after.has(XFest.TITLE_ONE_FOUR)
		and not ids_after.has(XFest.TITLE_WATCH) and not ids_after.has(XFest.TITLE_ATTEND), ids_after.slice(-4))
	# 存档里进度能存能读（flags 走 JSON）
	XState.current = s
	var back = kit.roundtrip() if kit.has_method("roundtrip") else null
	_check("progress_survives_save", back != null and XFest.coins(back) == XFest.coins(s) and bool(XFestRoad.progress(back).flawless_done),
		null if back == null else back.flags.get(XFest.FLAG_KEY))


func _flow_loss_resume() -> void:
	_reset_config()
	var s := _state()
	var h := MockHost.new()
	h.battle_results = [0, 2]  # 赢第一关，输第二关
	h.choices_queue = [0, 0, 0]
	var a = s.battle_members()[0]
	await XFestRoad.talk(h, s)
	_check("loss_stops_run", h.battles.size() == 2, h.battles.size())
	var p := XFestRoad.progress(s)
	_check("loss_resume_point", int(p.next) == 1 and not bool(p.flawless) and int(p.streak) == 0 and XFestRoad.resume_stage(s) == 1, p)
	_check("loss_party_recovered", s.members().all(func(m): return m.is_alive() and m.hp == m.mhp))
	_check("loss_first_win_coin", XFest.coins(s) == XFestRoad.COIN_FIRST_WIN)
	# 接着打：从第二关起、势如破竹从 0 起；打完给「冠军之路」不给「一穿四」
	var h2 := MockHost.new()
	h2.choices_queue = [0, 1, 0, 0]  # 接着打第 2 关；两关之间继续
	await XFestRoad.talk(h2, s)
	var troops := h2.battles.map(func(b): return int(b.troop))
	_check("resume_from_lost_stage", troops == [9301, 9302, 9303], troops)
	_check("resume_streak_restarts", h2.battles.map(func(b): return int(b.streak)) == [0, 1, 2])
	_check("resume_gives_road_not_one_four", XDesignation.unlocked(XFest.TITLE_ROAD) and not XDesignation.unlocked(XFest.TITLE_ONE_FOUR)
		and XFest.coins(s) == 4 * XFestRoad.COIN_FIRST_WIN and not bool(XFestRoad.progress(s).flawless_done), XFest.coins(s))
	_check("resume_offered_only_after_loss", XFestRoad.resume_stage(s) == 0)
	a = a


func _pause_and_quit() -> void:
	var s := _state()
	var h := MockHost.new()
	h.kill_on_battle = 0  # 第一关里打死一号位
	# 从第一关开始；第一关后选暂停，再选继续；第二关后（暂停已用，选项只剩继续／退出）选退出
	h.choices_queue = [0, 0, 1, 0, 1]
	var a = s.battle_members()[0]
	var b = s.battle_members()[1]
	b.hp = floorf(b.mhp * 0.5)
	b.mp = 0.0
	await XFestRoad.talk(h, s)
	_check("pause_then_quit_battles", h.battles.size() == 2, h.battles.size())
	# 暂停后第二关开战时：一号位复活到三成，二号位从五成到八成
	var hp_at_2 := float(h.battles[1].hp0) if h.battles.size() > 1 else -1.0
	_check("pause_revives_30pct", absf(hp_at_2 - floorf(a.mhp * 0.3)) < 1.0 and h.battles.size() > 1 and bool(h.battles[1].alive0), [hp_at_2, a.mhp])
	var opts_after_2: Array = h.texts[h.texts.size() - 1].get("options", [])
	_check("pause_only_once", opts_after_2.size() == 2 and not str(opts_after_2).contains("暂停"), opts_after_2)
	var p := XFestRoad.progress(s)
	_check("quit_resets_streak", int(p.streak) == 0 and not bool(p.flawless) and int(p.next) == 2, p)
	_check("quit_recovers_party", s.members().all(func(m): return m.is_alive() and m.hp == m.mhp))
	# 直接调：用过就不能再用
	var s2 := _state()
	XFestRoad.begin_run(s2)
	_check("use_pause_once_api", XFestRoad.use_pause(s2) and not XFestRoad.use_pause(s2))
	# 新开一趟重置暂停
	XFestRoad.begin_run(s2)
	_check("new_run_resets_pause", not bool(XFestRoad.progress(s2).pause))
	b = b


func _two_tiers() -> void:
	# 两档基准：普通版＝天灾（难度 6）、困难版＝洪荒（难度 8）的 26 层守层者金角 529；存档难度不影响
	var g: Dictionary = XDB.table("Enemies")[529]
	var r6 := XEnemy.difficulty_rates(6)
	var r8 := XEnemy.difficulty_rates(8)
	_check("tier_bases", XFestRoad.TIERS.size() == 2 and int(XFestRoad.TIERS[0].base) == 529 and int(XFestRoad.TIERS[1].base) == 529
		and int(XFestRoad.TIERS[0].difficulty) == 6 and int(XFestRoad.TIERS[1].difficulty) == 8 and int(XFestRoad.TIERS[0].guard_troop) == 462
		and XEnemy.difficulty_name(6) == "天灾" and XEnemy.difficulty_name(8) == "洪荒")
	# 内战幻神队·上单（×1.5）在两档里的实建能力值＝金角×摊比×位置×1.5×本档倍率；换存档难度（2 简单、5 地狱）结果一样
	var ok := true
	var detail := []
	for diff in [2, 5]:
		var s := _state()
		s.difficulty = diff
		for tier in 2:
			var lg := XBattleLogic.new()
			lg.setup(XFestRoad.troop_id(tier, 3), s)
			var e = lg.enemies[0]
			var rates := r6 if tier == 0 else r8
			var want_hp := floorf(float(g.params[0]) * XFestRoad.HP_SHARE * 1.5 * 1.6) * float(rates[0])
			var want_atk := floorf(float(g.params[2]) * XFestRoad.ATK_SHARE * 1.5 * 0.7) * float(rates[2])
			var got_hp := float(e.mhp)
			var got_atk := float(e.param(2))
			detail.append([diff, tier, got_hp, want_hp, got_atk, want_atk])
			ok = ok and absf(got_hp / want_hp - 1.0) < 0.001 and absf(got_atk / want_atk - 1.0) < 0.02 and e.hp == e.mhp
			ok = ok and absf(got_hp - XFestRoad.effective_param(tier, 3, 0, 0)) / got_hp < 0.001
	_check("tier_effective_params_fixed_difficulty", ok, detail)
	var h6 := XFestRoad.effective_param(1, 0, 0, 0) / XFestRoad.effective_param(0, 0, 0, 0)
	_check("hard_is_honghuang_over_tianzai", absf(h6 - float(r8[0]) / float(r6[0])) < 0.001, h6)
	_check("hard_troops_and_enemies", (XDB.rec("Troops", 9313).members as Array).size() == 5 and str(XDB.rec("Troops", 9313).name) == "冠军之路·内战幻神队"
		and str(XDB.rec("Enemies", 9434).name) == "内战幻神队·辅助" and XDB.rec("Troops", 9320).is_empty() and XDB.rec("Enemies", 9500).is_empty())
	# 两档奖励分开、只发一次、互不顶替
	_reset_config()
	for id in [XFest.TITLE_ROAD_HARD, XFest.TITLE_ONE_FOUR_HARD]:
		XConfig.designations().erase(str(id))
	XConfig.save_designations()
	var s := _state()
	var h := MockHost.new()
	h.choices_queue = [1, 0, 0, 0, 0]  # 困难版 → 从第一关开始 → 继续×3
	await XFestRoad.talk(h, s)
	var hard_troops := h.battles.map(func(b): return int(b.troop))
	var rw: Dictionary = XFestRoad.REWARDS[1]
	var hard_coins := 4 * int(rw.first) + int(rw.clear) + int(rw.flawless)
	_check("hard_run_order", hard_troops == [9310, 9311, 9312, 9313], hard_troops)
	_check("hard_rewards", XFest.coins(s) == hard_coins and XDesignation.unlocked(XFest.TITLE_ROAD_HARD) and XDesignation.unlocked(XFest.TITLE_ONE_FOUR_HARD)
		and not XDesignation.unlocked(XFest.TITLE_ROAD) and not XDesignation.unlocked(XFest.TITLE_ONE_FOUR)
		and XFestRoad.cleared(s, 1) and XFestRoad.flawless_done(s, 1) and not XFestRoad.cleared(s, 0), XFest.coins(s))
	var h2 := MockHost.new()
	h2.choices_queue = [1, 0, 0, 0, 0]
	await XFestRoad.talk(h2, s)
	_check("hard_rewards_once", h2.battles.size() == 4 and XFest.coins(s) == hard_coins, XFest.coins(s))
	# 打完困难还能拿普通的
	var h3 := MockHost.new()
	h3.choices_queue = [0, 0, 0, 0, 0]
	await XFestRoad.talk(h3, s)
	var normal_coins := 4 * XFestRoad.COIN_FIRST_WIN + XFestRoad.COIN_FLAWLESS
	_check("normal_after_hard_still_pays", XFest.coins(s) == hard_coins + normal_coins and XDesignation.unlocked(XFest.TITLE_ROAD)
		and XDesignation.unlocked(XFest.TITLE_ONE_FOUR) and XFestRoad.cleared(s, 0), XFest.coins(s))
	# 一档输了接着打的点不串到另一档
	var s2 := _state()
	var h4 := MockHost.new()
	h4.battle_results = [0, 2]
	h4.choices_queue = [1, 0, 0]
	await XFestRoad.talk(h4, s2)
	_check("resume_per_tier", XFestRoad.resume_stage(s2, 1) == 1 and XFestRoad.resume_stage(s2, 0) == 0
		and int(XFestRoad.progress(s2, 0).next) == 4 and not (XFestRoad.progress(s2, 0).first as Array).has(true))
	# 读档往返：两档进度都在；旧档（只有 road 键）按普通版
	XState.current = s
	var back = kit.roundtrip()
	_check("tiers_survive_save", back != null and XFestRoad.cleared(back, 0) and XFestRoad.cleared(back, 1) and XFestRoad.flawless_done(back, 1)
		and XFest.coins(back) == hard_coins + normal_coins, null if back == null else back.flags.get(XFest.FLAG_KEY))
	var old := _state()
	XFest.data(old)["road"] = {"next": 4, "first": [true, true, true, true], "cleared": true, "flawless_done": false}
	_check("legacy_road_is_normal", XFestRoad.cleared(old, 0) and not XFestRoad.cleared(old, 1))
	# 称号表列 45、46
	var ids := XDesignation.table().map(func(d): return int(d.id))
	_check("hard_titles_in_table", ids.has(XFest.TITLE_ROAD_HARD) and ids.has(XFest.TITLE_ONE_FOUR_HARD))
	# 报名处选档文字写对标难度
	_check("tier_labels", str(XFestRoad.tier_labels()) .contains("天灾") and str(XFestRoad.tier_labels()).contains("洪荒") and str(XFestRoad.tier_labels()).contains("26"))


func _small_party() -> void:
	# 出战 4 人：报名出「建议满五人」提示；选「回去整队」不开打、进度不动，选「仍要出战」照常连打
	var s := _state()
	s.set_battle_slot(4, 0)
	var n := s.battle_members().size()
	var h := MockHost.new()
	h.choices_queue = [0, 0, 1]  # 从第一关开始 → 回去整队
	await XFestRoad.talk(h, s)
	var warned := h.texts.any(func(t): return str(t.get("lines", [])).contains("建议满五人") and str(t.get("options", [])).contains("仍要出战"))
	_check("small_party_warned_and_back", n == 4 and warned and h.battles.is_empty() and int(XFestRoad.progress(s).next) == 4, [n, h.texts.size(), h.battles.size()])
	var h2 := MockHost.new()
	h2.choices_queue = [0, 0, 0, 0, 0, 0]  # 从第一关开始 → 仍要出战 → 两关之间都继续
	await XFestRoad.talk(h2, s)
	_check("small_party_confirm_enters", h2.battles.size() == 4 and int(h2.battles[0].troop) == 9300, h2.battles.size())
	# 满五人不出提示
	var s5 := _state()
	var h3 := MockHost.new()
	h3.choices_queue = [0, 0, 0, 0, 0]
	await XFestRoad.talk(h3, s5)
	_check("full_party_no_warning", not h3.texts.any(func(t): return str(t.get("lines", [])).contains("建议满五人")) and h3.battles.size() == 4)


func _closed_outside_event() -> void:
	var s := _state()
	var closed := true
	for day in ["2026-11-14", "2026-11-30", "2026-12-02", "2027-01-01"]:
		XFest.TODAY_OVERRIDE = day
		var h := MockHost.new()
		h.choices_queue = [0]
		await XFestRoad.talk(h, s)
		closed = closed and h.battles.is_empty() and not XFest.active()
	XFest.TODAY_OVERRIDE = "2026-11-15"
	var first_day := XFest.active()
	XFest.TODAY_OVERRIDE = "2026-11-29"
	var last_day := XFest.active()
	XFest.TODAY_OVERRIDE = "2026-12-01"
	var grace := XFest.in_grace() and not XFest.active() and XFest.visible()
	XFest.TODAY_OVERRIDE = "2026-12-03"
	var gone := not XFest.visible()
	XFest.TODAY_OVERRIDE = "2026-11-16"
	_check("closed_outside_event", closed)
	_check("event_window_15_plus_3", first_day and last_day and grace and gone, [first_day, last_day, grace, gone])


func _switch_off() -> void:
	_reset_config()
	XFest.unlock_title(XFest.TITLE_ROAD)
	XFest.ENABLED = false
	var s := _state()
	var h := MockHost.new()
	h.choices_queue = [0]
	await XFestRoad.talk(h, s)
	XFestRoad.in_road_battle = true
	XFestRoad.battle_streak = 3
	var ops := XFestRoad.damage_ops(s.battle_members()[0])
	XFestRoad.in_road_battle = false
	XFestRoad.battle_streak = 0
	var ids := XDesignation.table().map(func(d): return int(d.id))
	_check("switch_off_no_trace",
		h.battles.is_empty()
		and XDB.rec("Troops", 9300).is_empty()
		and XDB.rec("Enemies", 9300).is_empty()
		and XDB.rec("Skills", XFestRoad.HEAL_SKILL).is_empty()
		and ops.is_empty()
		and not ids.has(XFest.TITLE_ROAD) and not ids.has(XFest.TITLE_ONE_FOUR)
		and not XFest.active() and not XFest.visible(), [h.battles, ids.slice(-3)])
	XFest.ENABLED = true
	XFestRoad.ENABLED = false
	_check("road_switch_off", XDB.rec("Troops", 9300).is_empty() and XFest.active())
	XFestRoad.ENABLED = true
	_check("switch_back_on", not XDB.rec("Troops", 9300).is_empty())
