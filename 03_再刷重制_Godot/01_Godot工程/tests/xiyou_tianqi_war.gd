extends Node
## 天启篇战争线专项（XTianqiWarLine、XTianqiWarAlien、war_line.json，四骑士 horsemen.json 的 survival／shadow）。
## 一、数据：数字避开 4、台词和敌群齐全。
## 二、选线与门：通关 5 层才出；选战争线后开场三节依次跑，输了回大厅、走门接着打；没选线、开场没打完门不放人去 6 层。
## 三、楼层节点：10／20／30 层守层者开战前变使徒（只在开场打完后）；15、25 层第一次到说一次；36 层决战赢了记通关和可轮回。
## 四、异化战斗：侵染·战狂的属性、火花满 10 全体再动、交锋、蚀骨·战意满 5 层再动、号令官加成与再动、烟火师。
## 五、生存战：骑士生命锁住、援军第 1／3／5 回合、撑过 6 回合算赢；影子每回合一招。
## 六、原版档、没选战争线、开关关掉：一处都不动。
## 数字避开 4（Kyo 11-11）：用例里的种子、层号照实写。

## 地图场景的替身：文字记下，选项依次取 answers（取完选最后一个），换图记下，开战按 results 依次给结果并记下当时预约的异化／骑士
class FakeHost extends RefCounted:
	var answers: Array = []
	var asked: Array = []
	var said: Array = []
	var moves: Array = []
	var battles: Array = []
	var results: Array = []
	var map_id := 4
	func show_text(_f: String, _i: int, lines: Array) -> void:
		said.append_array(lines)
	func show_text_with_choices(_f: String, _i: int, _lines: Array, options: Array, _cancel: int) -> int:
		asked.append(options)
		return int(answers.pop_front()) if not answers.is_empty() else options.size() - 1
	func transfer(id: int, x: int, y: int, d: int, _fade := 0) -> void:
		moves.append([id, x, y, d])
		map_id = id
		XState.current.map_id = id
	func start_battle(troop: int, can_escape: bool, can_lose: bool, _random := false) -> int:
		battles.append({"troop": troop, "escape": can_escape, "lose": can_lose, "alien": XTianqiWarAlien.pending(),
			"knight": XTianqiHorsemen.pending(), "mode": XTianqiHorsemen._pending_mode})
		XTianqiWarAlien._pending = ""
		XTianqiHorsemen._pending = ""
		XTianqiHorsemen._pending_mode = "body"
		return int(results.pop_front()) if not results.is_empty() else 0


var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a: float, b: float, eps := 1e-6) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


## 天启篇存档、5 个弱者、已通关 5 层；tough＞0 时每人加厚生命和防御（好看几回合的规则）
func _state(tough := 0.0, line := "") -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, 6)
	XState.current = s
	if tough > 0.0:
		for id in lineup:
			var a := s.actor(id)
			a.add_param(0, tough)
			a.add_param(3, 10000.0)
			a.add_param(5, 10000.0)
			a.recover_all()
	if line != "":
		s.flags.tianqi["line"] = line
	return s


func _done(s: XState) -> void:
	XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE


func _guard_all(lg: XBattleLogic) -> Dictionary:
	var c := {}
	for a in lg.actors:
		c[a] = [XDB.rec("Skills", 2), null]
	return c


func _texts(logs: Array) -> Array:
	return logs.filter(func(l): return l.type == "battle_text").map(func(l): return str(l.text))


func _run() -> void:
	XMessageBox.auto = true
	seed(20261111)
	_data()
	_choose_and_opening()
	_door()
	_beats()
	_alien_omen()
	_alien_fervor()
	_alien_commander()
	_alien_pyro()
	_survival()
	_shadow()
	_plain()
	_review_berserk()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _data() -> void:
	XTianqiWarLine.reload()
	XTianqiHorsemen.reload()
	_check("nice_numbers_war_line", XTianqiWarLine.nice_number_violations().is_empty(), XTianqiWarLine.nice_number_violations())
	_check("nice_numbers_horsemen", XTianqiHorsemen.nice_number_violations().is_empty(), XTianqiHorsemen.nice_number_violations())
	var keys := ["choose", "omen_before", "omen_arrive", "omen_win", "spread_before", "spread_win", "lose_retry", "rift_before",
		"rift_survived", "rift_lost", "rift_after", "rift_home", "apostle10", "apostle20", "apostle30", "echo15", "rumor25",
		"shadow_before", "final_before", "final_win", "final_lost"]
	_check("scenes_all", keys.all(func(k): return not XTianqiWarLine.scene(k).is_empty()), keys.filter(func(k): return XTianqiWarLine.scene(k).is_empty()))
	for k in ["omen", "spread", "apostle10", "apostle20", "apostle30"]:
		var p := XTianqiWarAlien.preset(k)
		_check("preset_troop_" + k, not XDB.rec("Troops", int(p.troop)).is_empty() and not XTianqiWarAlien.tier_info(str(p.tier)).is_empty()
			and not XTianqiWarAlien.kind_info(str(p.kind)).is_empty(), p)
	_check("war_card", XTianqi.line_info("war").pick == "「烟火大会，开始啦！」" and XTianqi.line_playable("war") and XTianqi.line_playable("death"))  # 饥荒、瘟疫线做好后能选（cc 饥荒线、瘟疫线车道），死亡还没有


func _choose_and_opening() -> void:
	var s := _state()
	_check("line_ready_after_5", XTianqi.line_ready(s))
	s.set_variable(20, 5)
	_check("line_not_before_5", not XTianqi.line_ready(s))
	s.set_variable(20, 6)
	var host := FakeHost.new()
	# 选战争线：卡片、小小鱼一句、确认；接着跑开场，第 1 节输了回大厅
	host.answers = [0, 0]
	host.results = [2]
	await XTianqi.run_line_choice(host, s)
	_check("chosen_war", XTianqi.line_of(s) == "war" and XTianqiWarLine.allowed(s))
	_check("card_shown", host.said.any(func(t): return str(t).contains("便不再停歇")), host.said.slice(0, 3))
	_check("choose_line_said", host.said.any(func(t): return str(t).contains("你帮我验收")))
	_check("omen_battle", host.battles.size() == 1 and host.battles[0].troop == 30 and host.battles[0].alien == "omen" and host.battles[0].lose, host.battles)
	_check("omen_went_tribe", host.moves.size() >= 1 and host.moves[0] == [13, 27, 24, 8], host.moves)
	_check("omen_lost_home", XTianqiWarLine.stage(s) == 0 and host.moves[-1][0] == 4, [XTianqiWarLine.stage(s), host.moves])
	_check("door_resumes", XTianqiWarLine.door_blocked(s) and XTianqiWarLine.due(s))
	# 走门：从第 1 节接着打，三节都过（生存战输了剧情照走）
	host.battles.clear()
	host.moves.clear()
	host.said.clear()
	host.results = [0, 0, 2]
	_check("run_door_true", await XTianqiWarLine.run_door(host, s))
	_check("opening_three_battles", host.battles.size() == 3 and host.battles[1].troop == 35 and host.battles[1].alien == "spread"
		and host.battles[2].knight == "war" and host.battles[2].mode == "survival" and not host.battles[2].escape, host.battles)
	_check("opening_moves", host.moves.map(func(m): return int(m[0])) == [13, 13, 158, 4], host.moves)
	_check("opening_done", XTianqiWarLine.opening_done(s) and not XTianqiWarLine.due(s) and not bool(XTianqiWarLine.progress(s).get("survived", true)))
	_check("rift_lost_said", host.said.any(func(t): return str(t).contains("拖着你")) and host.said.any(func(t): return str(t).contains("烟火大会")))
	_check("door_open", not XTianqiWarLine.door_blocked(s))
	_check("no_change_line", not XTianqi.choose_line(s, "war") and not XTianqi.line_ready(s))
	# 生存战撑过：记 survived
	var s2 := _state(0.0, "war")
	XTianqiWarLine.progress(s2)["stage"] = 2
	var h2 := FakeHost.new()
	h2.results = [0]
	await XTianqiWarLine.run_due(h2, s2)
	_check("rift_survived_flag", bool(XTianqiWarLine.progress(s2).survived) and XTianqiWarLine.opening_done(s2) and h2.said.any(func(t): return str(t).contains("第六声")))
	# 存档来回
	var back := XState.from_dict(s2.to_dict())
	_check("progress_saved", XTianqiWarLine.opening_done(back) and bool(XTianqiWarLine.progress(back).survived))


func _door() -> void:
	var s := _state()
	_check("door_no_line_blocked", XTianqiWarLine.is_door(4, 36) and XTianqiWarLine.door_blocked(s) and not XTianqiWarLine.due(s))
	var host := FakeHost.new()
	_check("door_hint", await XTianqiWarLine.run_door(host, s) and host.said.any(func(t): return str(t).contains("先去方桌")) and host.battles.is_empty())
	s.set_variable(20, 5)
	_check("door_floor5_free", not XTianqiWarLine.door_blocked(s))
	s.set_variable(20, 6)
	XTianqi.LINE_EVENT_OPEN = false
	_check("door_switch_off_free", not XTianqiWarLine.door_blocked(s))
	XTianqi.LINE_EVENT_OPEN = true
	XTianqiWarLine.ENABLED = false
	XTianqiFamineLine.ENABLED = false  # 门锁看有没有能选的线：饥荒、瘟疫、死亡线也关掉才等于「没有能选的线」
	XTianqiPlagueLine.ENABLED = false
	XTianqiDeathLine.ENABLED = false
	_check("door_war_off_free", not XTianqiWarLine.door_blocked(s) and not XTianqi.line_playable("war") and not XTianqi.line_ready(s))
	XTianqiWarLine.ENABLED = true
	XTianqiFamineLine.ENABLED = true
	XTianqiPlagueLine.ENABLED = true
	XTianqiDeathLine.ENABLED = true
	_check("door_other_event", not XTianqiWarLine.is_door(4, 35) and not XTianqiWarLine.is_door(13, 36))


func _beats() -> void:
	var s := _state(0.0, "war")
	var host := FakeHost.new()
	# 开场没打完：使徒不变、节点不出
	await XTianqiWarLine.before_battle(host, s, 69)
	_check("apostle_before_opening", XTianqiWarAlien.pending() == "" and host.said.is_empty())
	_check("beat_before_opening", XTianqiWarLine.arrival_beat(s, 32) == "")
	_done(s)
	for pair in [[69, "apostle10"], [456, "apostle20"], [466, "apostle30"]]:
		host.said.clear()
		await XTianqiWarLine.before_battle(host, s, int(pair[0]))
		_check(str(pair[1]), XTianqiWarAlien.pending() == str(pair[1]) and host.said.any(func(t): return str(t).contains("莉co的声音")), [XTianqiWarAlien.pending(), host.said])
		XTianqiWarAlien._pending = ""
	await XTianqiWarLine.before_battle(host, s, 30)
	_check("not_apostle_troop", XTianqiWarAlien.pending() == "")
	host.said.clear()
	await XTianqiWarLine.run_arrival(host, s, 32)
	_check("echo15", host.said.any(func(t): return str(t).contains("火药配方")) and XTianqiWarLine.arrival_beat(s, 32) == "")
	host.said.clear()
	await XTianqiWarLine.run_arrival(host, s, 32)
	_check("echo15_once", host.said.is_empty())
	await XTianqiWarLine.run_arrival(host, s, 147)
	_check("rumor25", host.said.any(func(t): return str(t).contains("丧钟")))
	_check("no_beat_other_map", XTianqiWarLine.arrival_beat(s, 17) == "")
	# 35 层影子、36 层决战
	host.battles.clear()
	host.results = [0, 2, 0]
	_check("shadow_result", await XTianqiWarLine.run_shadow(host, s) == 0 and host.battles[0].knight == "war" and host.battles[0].mode == "shadow", host.battles)
	_check("final_lost", await XTianqiWarLine.run_final(host, s) == 2 and not bool(XTianqiWarLine.progress(s).get("cleared", false)))
	host.said.clear()
	_check("final_win", await XTianqiWarLine.run_final(host, s) == 0 and bool(XTianqiWarLine.progress(s).cleared) and bool(s.flags.tianqi.reincarnate)
		and host.battles[2].mode == "body" and host.said.any(func(t): return str(t).contains("未经姐姐复核")), host.battles)


func _alien_logic(preset: String, troop: int, tough := 20000000.0) -> XBattleLogic:
	var s := _state(tough, "war")
	_check("prepare_" + preset, XTianqiWarAlien.prepare(preset, s))
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	return lg


func _alien_omen() -> void:
	# 对照：同一敌群不异化
	var s0 := _state(20000000.0, "war")
	var plain := XBattleLogic.new()
	plain.setup(30, s0)
	var p0: XEnemy = plain.enemies[0]
	var lg := _alien_logic("omen", 30)
	var e: XEnemy = lg.enemies[0]
	_check("omen_all_alien", lg.enemies.all(func(x): return XTianqiWarAlien.is_alien(lg, x)), lg.enemies.size())
	_check("omen_name", e.display_name().begins_with("侵染·") and e.display_name().contains("火焰哥布林"), e.display_name())
	_check("omen_berserk_atk", _near(float(e.added_params.get(2, 0.0)), e.param_base_unscaled(2) * 0.5, 1e-3) and e.atk > e.param_base(2), [e.added_params, e.param_base_unscaled(2)])
	_check("omen_hp", _near(float(e.added_params.get(0, 0.0)), e.param_base_unscaled(0) * (1.5 * 1.25 - 1.0), 1e-3) and _near(e.mhp, e.param_base(0) * 1.875, 1e-3) and _near(e.hp, e.mhp), [e.mhp, e.param_base(0)])
	_check("omen_plain_name", not p0.display_name().contains("·"), p0.display_name())
	# 交锋：第 3 回合起每回合 +10%，上限 +100%
	lg.turn = 2
	var c2 := XTianqiWarAlien.clash_mult(lg)
	lg.turn = 3
	var c3 := XTianqiWarAlien.clash_mult(lg)
	lg.turn = 30
	var c30 := XTianqiWarAlien.clash_mult(lg)
	lg.turn = 0
	_check("clash", _near(c2, 1.0) and _near(c3, 1.1) and _near(c30, 2.0), [c2, c3, c30])
	# 火花：异化怪每行动 +1，满 10 全体再动、归零
	var f := XTianqiWarAlien.fight(lg)
	var fired := false
	var extra_turn := false
	for i in range(6):
		var logs := lg.run_turn(_guard_all(lg))
		var acts := logs.filter(func(l): return l.type == "action" and l.user is XEnemy).size()
		if _texts(logs).any(func(t): return t.contains("火花满了")):
			fired = true
			extra_turn = acts > lg.alive(lg.enemies).size()
			break
		if lg.is_over():
			break
	_check("spark_fire", fired, f.sparks)
	_check("spark_extra_actions", extra_turn)
	_check("spark_reset", int(f.sparks) < 10, f.sparks)
	lg.end_battle(0)
	_check("omen_end_clears", not XTianqiWarAlien.active(lg) and not e.has_meta("tianqi_prefix"))


func _alien_fervor() -> void:
	var lg := _alien_logic("spread", 35)
	var chief: XEnemy = lg.enemies[0]
	_check("spread_name", chief.display_name().begins_with("蚀骨·") and chief.display_name().contains("帕斯诺夫"), chief.display_name())
	_check("spread_hp", _near(float(chief.added_params.get(0, 0.0)), chief.param_base_unscaled(0) * 0.5, 1e-3), [chief.added_params, chief.param_base_unscaled(0)])
	var a: XActor = lg.actors[0]
	var u := XTianqiWarAlien.unit(lg, chief)
	var attack := XDB.rec("Skills", 1)
	# 打中一次叠一层（没打中不算）；第 5 次打中满层：归零、立刻再动
	var hits := 0
	var counts := []
	var fired := false
	for i in range(30):
		lg.current_order.clear()
		var logs := lg.act(a, attack, chief)
		hits += logs.filter(func(l): return l.type == "hit" and is_same(l.target, chief) and float(l.get("hp", 0.0)) > 0.0).size()
		counts.append(int(u.fervor))
		if _texts(logs).any(func(t): return t.contains("战意满了")):
			fired = lg.current_order.size() >= 1 and is_same(lg.current_order[0], chief) and int(u.fervor) == 0
			break
	_check("fervor_full_again", fired and hits == 5, [hits, counts])
	lg.end_battle(0)


func _alien_commander() -> void:
	# 20 层使徒：守层者石日天（敌群里只有它一只）
	var lg0 := _alien_logic("apostle20", 456)
	var g: XEnemy = lg0.enemies[0]
	_check("apostle20_alien", XTianqiWarAlien.is_alien(lg0, g) and g.display_name().begins_with("蚀骨·") and str(XTianqiWarAlien.unit(lg0, g).kind) == "commander", g.display_name())
	lg0.end_battle(0)
	# 号令官带着别的怪（测试临时预设：火焰哥布林三只里第一只当号令官）
	var presets: Dictionary = XTianqiWarLine.data().presets
	for tier in ["shigu", "huaxing"]:
		presets["_test_cmd"] = {"troop": 30, "units": [0], "tier": tier, "kind": "commander"}
		var lg := _alien_logic("_test_cmd", 30)
		var boss: XEnemy = lg.enemies[0]
		var others := lg.enemies.filter(func(x): return not is_same(x, boss))
		var rate := 0.2 if tier == "shigu" else 0.3
		_check("commander_buff_" + tier, others.size() == 2 and others.all(func(x): return _near(float(x.added_params.get(2, 0.0)), x.param_base_unscaled(2) * rate, 1e-3)),
			others.map(func(x): return [x.added_params.get(2, 0.0), x.param_base_unscaled(2)]))
		_check("commander_extra_" + tier, others.all(func(x): return XTianqiWarAlien.extra_actions(lg, x) == 1) and XTianqiWarAlien.extra_actions(lg, boss) == 1)
		boss.hp = 0.0
		boss.refresh_resources()
		lg._die(boss)
		lg.current_order.clear()
		var logs := lg.act(lg.actors[0], XDB.rec("Skills", 2), null)
		_check("commander_down_" + tier, others.all(func(x): return _near(float(x.added_params.get(2, 0.0)), 0.0)) and XTianqiWarAlien.extra_actions(lg, others[0]) == 0
			and _texts(logs).any(func(t): return t.contains("号令官倒下")), others.map(func(x): return x.added_params.get(2, 0.0)))
		# 蚀骨：倒下时其他怪不立刻行动；化形起其他怪各立刻行动一次
		var want := 0 if tier == "shigu" else 2
		_check("commander_rush_" + tier, lg.current_order.size() == want, lg.current_order.size())
		lg.end_battle(0)
	presets.erase("_test_cmd")


func _alien_pyro() -> void:
	var lg := _alien_logic("apostle30", 466)
	var boss: XEnemy = lg.enemies.filter(func(x): return XTianqiWarAlien.is_alien(lg, x))[0]
	_check("pyro_name_hp", boss.display_name().begins_with("化形·") and _near(float(boss.added_params.get(0, 0.0)), boss.param_base_unscaled(0), 1e-3), [boss.display_name(), boss.added_params])
	var f := XTianqiWarAlien.fight(lg)
	lg.current_order.clear()
	lg.act(boss, XDB.rec("Skills", 2), null)
	_check("pyro_spark_two", int(f.sparks) == 2, f.sparks)
	f.sparks = 9
	lg.current_order.clear()
	lg.act(boss, XDB.rec("Skills", 2), null)
	_check("pyro_huaxing_twice", int(f.sparks) == 0 and lg.current_order.count(boss) == 2, lg.current_order.size())
	lg.end_battle(0)


func _survival() -> void:
	var s := _state(20000000.0, "war")
	_check("survival_prepare", XTianqiHorsemen.prepare("war", s, "survival"))
	_check("survival_other_line_no", not XTianqiHorsemen.prepare("nope", s, "survival") and XTianqiHorsemen.pending() == "")
	XTianqiHorsemen.prepare("war", s, "survival")
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var kn: XEnemy = lg.enemies[0]
	var f := XTianqiHorsemen.fight(lg)
	var st := XTianqiHorsemen.survival_stats("war", "jianxian")
	_check("survival_mode", XTianqiHorsemen.mode_of(lg) == "survival" and _near(kn.mat, float(st.mat)), [kn.mat, st.mat])
	var adds: Array = f.adds
	var row := XTianqiBalance.difficulty("jianxian")
	var goblin := XDB.rec("Enemies", 31)
	_check("survival_add_stats", _near(adds[0].mhp, roundf(float(goblin.params[0]) * float(row.enemy_hp))) and adds[0].display_name().begins_with("兵临的援军"), [adds[0].mhp, adds[0].display_name()])
	_check("survival_wave1", lg.alive(adds).size() == 3, lg.alive(adds).size())
	# 生命锁住：一下打过最大生命也留 1 点
	lg._action_resources = lg._new_lifecycle_resources()
	lg.execute_hp_damage(lg.actors[0], kn, kn.mhp * 2.0, false)
	lg._action_resources = null
	_check("survival_hp_lock", kn.is_alive() and _near(kn.hp, 1.0), kn.hp)
	# 援军第 1（开战，日志随第 1 回合开始出）、3、5 回合；第 6 回合结束骑士退场算赢
	var waves := []
	var spark_fired := false
	for t in range(6):
		for e in adds:
			if e.is_alive():
				e.hp = 0.0
				e.refresh_resources()
				lg._die(e)
		var logs := lg.run_turn(_guard_all(lg))
		waves.append(_texts(logs).filter(func(x): return x.contains("援军到了")).size())
		spark_fired = spark_fired or _texts(logs).any(func(x): return x.contains("敌方全体再动"))
		if lg.is_lost():
			break
	_check("survival_waves", waves == [1, 0, 1, 0, 1, 0], waves)
	_check("survival_spark", spark_fired, f.sparks)
	_check("survival_win", XTianqiHorsemen.survived(lg) and lg.is_won() and not lg.is_lost(), [lg.turn, lg.alive(lg.actors).size()])
	lg.end_battle(0)


func _shadow() -> void:
	var s := _state(20000000.0, "war")
	_check("shadow_prepare", XTianqiHorsemen.prepare("war", s, "shadow"))
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var kn: XEnemy = lg.enemies[0]
	var st := XTianqiHorsemen.shadow_stats("war", "jianxian")
	_check("shadow_hp", _near(kn.mhp, float(st.hp)), [kn.mhp, st.hp])
	# 一招＋兵临再动（开场 3 只援军 → +1）
	_check("shadow_actions", lg.make_action_times(kn) == 2, lg.make_action_times(kn))
	var kinds := {}
	for t in range(3):
		var logs := lg.run_turn(_guard_all(lg))
		for l in logs:
			if l.type == "action" and is_same(l.user, kn):
				kinds[str(l.skill.get("tianqi_horseman", ""))] = true
	_check("shadow_moves", kinds.keys().all(func(k): return ["wave", "crackle"].has(k)) and not kinds.is_empty(), kinds.keys())
	_check("shadow_no_layers", int(XTianqiHorsemen.fight(lg).layer) == 1)
	lg.end_battle(0)


func _plain() -> void:
	# 原版档：不收、敌群不变、门不锁
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var p := XState.new_game_blank()
	for id in lineup:
		p.add_actor(int(id))
	p.set_variable(20, 6)
	XState.current = p
	_check("plain_no_prepare", not XTianqiWarAlien.prepare("omen", p) and not XTianqiHorsemen.prepare("war", p, "survival"))
	var lg := XBattleLogic.new()
	lg.setup(30, p)
	_check("plain_battle", not XTianqiWarAlien.active(lg) and not lg.enemies[0].display_name().contains("·"))
	_check("plain_door", not XTianqiWarLine.door_blocked(p) and not XTianqiWarLine.allowed(p) and XTianqiWarLine.arrival_beat(p, 32) == "")
	lg.end_battle(0)
	# 天启篇存档没选战争线（选别的线时）：战争线内容不出
	var s := _state(0.0, "famine")
	_check("other_line", not XTianqiWarLine.allowed(s) and not XTianqiWarAlien.prepare("omen", s))
	# 战争线开关关掉
	var s2 := _state(0.0, "war")
	_done(s2)
	XTianqiWarLine.ENABLED = false
	var host := FakeHost.new()
	await XTianqiWarLine.before_battle(host, s2, 69)
	_check("switch_off", not XTianqiWarLine.allowed(s2) and XTianqiWarAlien.pending() == "" and host.said.is_empty())
	XTianqiWarLine.ENABLED = true


## 评审 v0.1 第 2 条（cc/tianqi-review-fixes）核实：化形战狂受伤加攻，伤害结算末尾的 refresh 已让缓存格变冷，打完这一下就读到新攻（误报，钉住）
func _review_berserk() -> void:
	var lg := _alien_logic("omen", 30)
	var e: XEnemy = lg.enemies[0]
	XTianqiWarAlien.unit(lg, e).idx = 2
	var atk1 := e.atk  # 读一次：缓存格变热
	var a: XActor = lg.actors[0]
	var hit := false
	for i in range(10):
		lg.current_order.clear()
		var logs := lg.act(a, XDB.rec("Skills", 1), e)
		if logs.any(func(l): return l.type == "hit" and is_same(l.target, e) and float(l.get("hp", 0.0)) > 0.0):
			hit = true
			break
	var atk2 := e.atk
	_check("review2_berserk_hit", hit)
	_check("review2_berserk_atk_after_hit", atk2 > atk1, [atk1, atk2])
	lg.end_battle(0)
