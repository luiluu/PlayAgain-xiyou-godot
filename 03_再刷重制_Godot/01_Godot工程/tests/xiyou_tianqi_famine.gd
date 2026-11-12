extends Node
## 天启篇饥荒线专项（XTianqiLine 四线共用流程、XTianqiFamineLine、XTianqiFamineAlien、famine_line.json，四骑士 horsemen.json 的饥荒 survival／shadow）。
## 一、数据：数字避开 4、台词和敌群齐全、开场步骤能走。
## 二、选线与开场：选饥荒线后开场三节（三层训练场 → 伐木者小屋 → 天外天生存战），输了回大厅、走门接着打。
## 三、序幕与楼层节点：三层吕茂的序幕（不分线，一次）、通关后的一句；10／20／30 层使徒；15、25 层；25 层模拟考记分。
## 四、异化战斗：饥饿（消耗×、回复×）、口粮（零消耗技能扣 MP，不够扣生命，攻击／防御不扣）、荒年者、掠夺者、熬夜者、透支者、化形效果。
## 五、生存战（开场即绝粮、饿出来的小怪、撑过 6 回合）和影子（题海战术、没有小怪）。
## 六、原版档、没选饥荒线、开关关掉：一处都不动。
## 数字避开 4（Kyo 11-11）：用例里的种子、层号照实写。

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
		battles.append({"troop": troop, "escape": can_escape, "lose": can_lose, "alien": XTianqiFamineAlien.pending(),
			"knight": XTianqiHorsemen.pending(), "mode": XTianqiHorsemen._pending_mode})
		XTianqiFamineAlien._pending = ""
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
	XTianqiFamineLine.progress(s)["stage"] = XTianqiFamineLine.STAGE_DONE


func _guard_all(lg: XBattleLogic) -> Dictionary:
	var c := {}
	for a in lg.actors:
		c[a] = [XDB.rec("Skills", 2), null]
	return c


func _texts(logs: Array) -> Array:
	return logs.filter(func(l): return l.type == "battle_text").map(func(l): return str(l.text))


## 找一个技能：只看 MP／TP 字段、备注里不写消耗、不是攻击防御
func _skill(want_mp: bool) -> Dictionary:
	var all = XDB.table("Skills")
	for rec in all:
		if not rec is Dictionary or int(rec.get("id", 0)) <= 2 or str(rec.get("name", "")) == "":
			continue
		if str(rec.get("note", "")).to_lower().contains("cost"):
			continue
		var mp := int(rec.get("mpCost", 0))
		var tp := int(rec.get("tpCost", 0))
		if want_mp and mp >= 11 and tp == 0:
			return rec
		if not want_mp and mp == 0 and tp == 0 and int(rec.get("stypeId", 0)) > 0:
			return rec
	return {}


func _run() -> void:
	XMessageBox.auto = true
	seed(20261111)
	_data()
	await _choose_and_opening()
	await _prologue()
	await _beats()
	_alien_omen()
	_alien_lean()
	_alien_plunder()
	_alien_night_overdraw()
	_survival()
	_shadow()
	await _plain()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _data() -> void:
	XTianqiLine.reload()
	_check("nice_numbers_famine_line", XTianqiLine.nice_number_violations("famine").is_empty(), XTianqiLine.nice_number_violations("famine"))
	_check("nice_numbers_war_line", XTianqiLine.nice_number_violations("war").is_empty(), XTianqiLine.nice_number_violations("war"))
	_check("nice_numbers_horsemen", XTianqiHorsemen.nice_number_violations().is_empty(), XTianqiHorsemen.nice_number_violations())
	var keys := ["prologue", "after_clear", "choose", "omen_before", "omen_arrive", "omen_win", "spread_before", "spread_win", "lose_retry",
		"rift_before", "rift_survived", "rift_lost", "rift_after", "rift_home", "apostle10", "apostle20", "apostle30", "echo15", "rumor25",
		"quiz_offer", "quiz_done", "shadow_before", "final_before", "final_win", "final_lost"]
	var miss := keys.filter(func(k): return XTianqiLine.scene("famine", k).is_empty())
	_check("scenes_all", miss.is_empty(), miss)
	for k in ["omen", "spread", "apostle10", "apostle20", "apostle30"]:
		var p := XTianqiFamineAlien.preset(k)
		_check("preset_troop_" + k, not XDB.rec("Troops", int(p.troop)).is_empty() and not XTianqiFamineAlien.tier_info(str(p.tier)).is_empty()
			and not XTianqiFamineAlien.kind_info(str(p.kind)).is_empty(), p)
	_check("stage_done", XTianqiLine.stage_done("famine") == XTianqiFamineLine.STAGE_DONE and XTianqiLine.stage_done("war") == XTianqiWarLine.STAGE_DONE)
	_check("famine_card", XTianqi.line_info("famine").pick == "「噫~我中了！」" and XTianqi.line_playable("famine") and XTianqi.line_playable("war")
		and XTianqi.line_playable("plague"))
	_check("quiz_three", XTianqiFamineLine.data().quiz.questions.size() == 3)


func _famine_index() -> int:
	for i in XTianqi.LINES.size():
		if str(XTianqi.LINES[i].key) == "famine":
			return i
	return -1


func _choose_and_opening() -> void:
	var s := _state()
	var host := FakeHost.new()
	host.answers = [_famine_index(), 0]
	host.results = [2]
	await XTianqi.run_line_choice(host, s)
	_check("chosen_famine", XTianqi.line_of(s) == "famine" and XTianqiFamineLine.allowed(s) and not XTianqiWarLine.allowed(s))
	_check("card_shown", host.said.any(func(t): return str(t).contains("储备")))
	_check("choose_said", host.said.any(func(t): return str(t).contains("批改") or str(t).contains("红笔叉")))
	_check("omen_battle", host.battles.size() == 1 and host.battles[0].troop == 11 and host.battles[0].alien == "omen" and host.battles[0].lose, host.battles)
	_check("omen_went_field", not host.moves.is_empty() and host.moves[0] == [6, 6, 21, 6], host.moves)
	_check("omen_taught", host.said.any(func(t): return str(t).contains("口粮")))
	_check("omen_lost_home", XTianqiLine.stage("famine", s) == 0 and host.moves[-1][0] == 4)
	_check("door_resumes", XTianqiLine.door_blocked(s) and XTianqiLine.due("famine", s))
	host.battles.clear()
	host.moves.clear()
	host.said.clear()
	host.results = [0, 0, 0]
	_check("run_door_true", await XTianqiLine.run_door(host, s))
	_check("opening_three_battles", host.battles.size() == 3 and host.battles[1].troop == 430 and host.battles[1].alien == "spread"
		and host.battles[2].knight == "famine" and host.battles[2].mode == "survival", host.battles)
	_check("opening_moves", host.moves.map(func(m): return int(m[0])) == [6, 126, 158, 4], host.moves)
	_check("opening_done", XTianqiLine.opening_done("famine", s) and bool(XTianqiFamineLine.progress(s).get("survived", false)))
	_check("rift_said", host.said.any(func(t): return str(t).contains("答题卡")) and host.said.any(func(t): return str(t).contains("出题的")))
	_check("door_open", not XTianqiLine.door_blocked(s))
	var back := XState.from_dict(s.to_dict())
	_check("progress_saved", XTianqiLine.opening_done("famine", back) and XTianqi.line_of(back) == "famine")


func _prologue() -> void:
	# 天启篇存档还没选线：第一次到三层说一次；别的图不说
	var s := _state()
	var host := FakeHost.new()
	_check("prologue_beat", XTianqiLine.arrival_beat(s, 6) == "prologue" and XTianqiLine.arrival_beat(s, 5) == "")
	await XTianqiLine.run_arrival(host, s, 6)
	_check("prologue_said", host.said.any(func(t): return str(t).contains("再刷一套")))
	_check("prologue_once", XTianqiLine.arrival_beat(s, 6) == "")
	# 战争线存档也有序幕（不分线）
	var w := _state(0.0, "war")
	_check("prologue_war_save", XTianqiLine.arrival_beat(w, 6) == "prologue")
	# 饥荒线通关后再到三层：这次我慢慢做
	var f := _state(0.0, "famine")
	_done(f)
	XTianqiFamineLine.progress(f)["cleared"] = true
	await XTianqiLine.run_arrival(host, f, 6)
	host.said.clear()
	_check("after_clear_beat", XTianqiLine.arrival_beat(f, 6) == "after_clear")
	await XTianqiLine.run_arrival(host, f, 6)
	_check("after_clear_said", host.said.any(func(t): return str(t).contains("慢慢做")) and XTianqiLine.arrival_beat(f, 6) == "")
	XTianqiFamineLine.ENABLED = false
	_check("prologue_switch_off", XTianqiLine.arrival_beat(_state(), 6) == "")
	XTianqiFamineLine.ENABLED = true


func _beats() -> void:
	var s := _state(0.0, "famine")
	var host := FakeHost.new()
	await XTianqiLine.before_battle(host, s, 69)
	_check("apostle_before_opening", XTianqiFamineAlien.pending() == "" and host.said.is_empty())
	_done(s)
	for pair in [[69, "apostle10"], [456, "apostle20"], [466, "apostle30"]]:
		host.said.clear()
		await XTianqiLine.before_battle(host, s, int(pair[0]))
		_check(str(pair[1]), XTianqiFamineAlien.pending() == str(pair[1]) and host.said.any(func(t): return str(t).contains("饥荒骑士的声音")), [XTianqiFamineAlien.pending(), host.said])
		XTianqiFamineAlien._pending = ""
	_check("war_alien_untouched", XTianqiWarAlien.pending() == "")
	host.said.clear()
	await XTianqiLine.run_arrival(host, s, 32)
	_check("echo15", host.said.any(func(t): return str(t).contains("红叉")) and XTianqiLine.arrival_beat(s, 32) == "")
	host.said.clear()
	host.answers = [0, 0, 1, 2]
	await XTianqiLine.run_arrival(host, s, 147)
	_check("rumor25", host.said.any(func(t): return str(t).contains("放烟火")))
	_check("quiz_full", int(XTianqiFamineLine.progress(s).get("quiz", -1)) == 3 and host.said.any(func(t): return str(t).contains("答对了 3 道")), XTianqiFamineLine.progress(s))
	var s2 := _state(0.0, "famine")
	_done(s2)
	var h2 := FakeHost.new()
	h2.answers = [1]
	await XTianqiLine.run_arrival(h2, s2, 147)
	_check("quiz_skip", not XTianqiFamineLine.progress(s2).has("quiz") and h2.asked.size() == 1)
	host.battles.clear()
	host.results = [0, 0]
	_check("shadow_result", await XTianqiFamineLine.run_shadow(host, s) == 0 and host.battles[0].knight == "famine" and host.battles[0].mode == "shadow", host.battles)
	host.said.clear()
	_check("final_win", await XTianqiFamineLine.run_final(host, s) == 0 and bool(XTianqiFamineLine.progress(s).cleared)
		and host.said.any(func(t): return str(t).contains("改卷子")), host.battles)


func _alien_logic(preset: String, troop: int, tough := 20000000.0) -> XBattleLogic:
	var s := _state(tough, "famine")
	_check("prepare_" + preset, XTianqiFamineAlien.prepare(preset, s))
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	return lg


func _plain_logic(troop: int) -> XBattleLogic:
	var s := _state(20000000.0, "famine")
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	return lg


func _alien_omen() -> void:
	var plain := _plain_logic(11)
	var a0: XActor = plain.actors[0]
	var sk := _skill(true)
	var zero := _skill(false)
	_check("found_skills", not sk.is_empty() and not zero.is_empty(), [sk.get("id"), zero.get("id")])
	var c0 := plain.skill_cost(a0, sk)
	plain.end_battle(0)
	var lg := _alien_logic("omen", 11)
	var e: XEnemy = lg.enemies[0]
	_check("omen_one_alien", XTianqiFamineAlien.is_alien(lg, e) and not XTianqiFamineAlien.is_alien(lg, lg.enemies[1]))
	_check("omen_name", e.display_name().begins_with("侵染·") and e.display_name().contains("哥布林巫师"), e.display_name())
	_check("omen_hp", _near(e.mhp, e.param_base(0) * 1.25, 1e-3) and _near(e.hp, e.mhp), [e.mhp, e.param_base(0)])
	var a: XActor = lg.actors[0]
	var c := lg.skill_cost(a, sk)
	_check("exhaust_cost", int(c.mp) == floori(int(c0.mp) * 1.3) and int(c.mp) > int(c0.mp), [c0, c])
	_check("exhaust_panel_untouched", int(lg.skill_cost(a, sk, true).mp) == int(plain.skill_cost(a0, sk, true).mp))
	_check("hunger_text", XTianqiFamineAlien.hunger_text(lg).contains("×1.3") and XTianqiFamineAlien.hunger_text(lg).contains("3%"), XTianqiFamineAlien.hunger_text(lg))
	# 口粮：零消耗技能扣最大 MP 的 3%；攻击、防御不扣；MP 不够扣当前生命的 3%
	a.mp = a.mmp
	var need := floorf(a.mmp * 0.03)
	lg.pay_skill_cost(a, zero)
	_check("ration_mp", _near(a.mp, a.mmp - need) and need > 0.0, [a.mp, a.mmp, need])
	a.mp = a.mmp
	lg.pay_skill_cost(a, XDB.rec("Skills", 1))
	lg.pay_skill_cost(a, XDB.rec("Skills", 2))
	_check("ration_attack_guard_free", _near(a.mp, a.mmp))
	a.mp = 0.0
	var hp0 := a.hp
	lg.pay_skill_cost(a, zero)
	_check("ration_hp", _near(a.hp, hp0 - floorf(hp0 * 0.03)), [hp0, a.hp])
	var logs := XTianqiFamineAlien.take_logs(lg)
	_check("ration_logged", _texts(logs).any(func(t): return t.contains("口粮")), _texts(logs))
	# 有资源消耗的技能不交口粮
	a.mp = a.mmp
	var mp_before := a.mp
	lg.pay_skill_cost(a, sk)
	_check("ration_not_for_cost_skill", _near(a.mp, mp_before - float(c.mp)), [mp_before, a.mp, c.mp])
	# 化形枯竭者：生命消耗也提高
	XTianqiFamineAlien.unit(lg, e).idx = 2
	_check("exhaust_huaxing_hp_cost", XTianqiFamineAlien.hp_cost(a, 100) == 180 and _near(XTianqiFamineAlien.cost_mult(lg), 1.8))
	XTianqiFamineAlien.unit(lg, e).idx = 0
	# 每回合开始报饥饿
	var tl := lg.run_turn(_guard_all(lg))
	_check("hunger_each_turn", _texts(tl).any(func(t): return t.contains("饥饿")), _texts(tl))
	# 异化怪倒下：饥饿散去、不再交口粮
	e.hp = 0.0
	e.refresh_resources()
	lg._die(e)
	a.mp = a.mmp
	lg.pay_skill_cost(a, zero)
	_check("ration_gone", _near(a.mp, a.mmp) and not XTianqiFamineAlien.hungry(lg) and _near(XTianqiFamineAlien.cost_mult(lg), 1.0))
	lg.end_battle(0)
	_check("omen_end_clears", not XTianqiFamineAlien.active(lg) and not e.has_meta("tianqi_prefix") and XTianqiFamineAlien.active_logic() == null)


func _alien_lean() -> void:
	var lg := _alien_logic("spread", 430)
	var boss: XEnemy = lg.enemies[0]
	_check("spread_name", boss.display_name().begins_with("蚀骨·") and boss.display_name().contains("光头强"), boss.display_name())
	var a: XActor = lg.actors[0]
	_check("lean_gain_hp", _near(XTianqiFamineAlien.gain(a, "hp", 100.0), 70.0) and _near(XTianqiFamineAlien.gain(a, "mp", 100.0), 70.0))
	_check("lean_gain_tp_free", _near(XTianqiFamineAlien.gain(a, "tp", 100.0), 100.0))
	_check("lean_enemy_free", _near(XTianqiFamineAlien.gain(boss, "hp", 100.0), 100.0))
	_check("lean_loss_free", _near(XTianqiFamineAlien.gain(a, "hp", -100.0), -100.0))
	var r := XTianqiFamineAlien.regen(lg, a, 100.0, 100.0, 10.0)
	_check("lean_regen", _near(r[0], 70.0) and _near(r[1], 70.0) and _near(r[2], 10.0), r)
	# 真的回血：资源上下文走一次
	a.hp = a.mhp - 1000.0
	lg._action_resources = lg._new_lifecycle_resources()
	lg._action_resources.gain(a, "hp", 1000.0)
	lg._action_resources = null
	_check("lean_real_heal", _near(a.hp, a.mhp - 300.0), [a.hp, a.mhp])
	XTianqiFamineAlien.unit(lg, boss).idx = 2
	r = XTianqiFamineAlien.regen(lg, a, 100.0, 100.0, 10.0)
	_check("lean_huaxing_regen_off", _near(r[0], 0.0) and _near(r[1], 0.0) and _near(r[2], 10.0), r)
	_check("lean_huaxing_heal", _near(XTianqiFamineAlien.gain(a, "hp", 100.0), 50.0))
	lg.end_battle(0)


func _alien_plunder() -> void:
	var lg := _alien_logic("apostle20", 456)
	var g: XEnemy = lg.enemies[0]
	_check("apostle20_alien", XTianqiFamineAlien.is_alien(lg, g) and g.display_name().begins_with("蚀骨·") and str(XTianqiFamineAlien.unit(lg, g).kind) == "plunder", g.display_name())
	var a: XActor = lg.actors[0]
	a.mp = 100.0
	a.tp = 50.0
	XTianqiFamineAlien.hp_damage(lg, g, a, 10.0)
	_check("plunder_steal", _near(a.mp, 90.0) and _near(a.tp, 45.0), [a.mp, a.tp])
	XTianqiFamineAlien.hp_damage(lg, a, g, 10.0)
	_check("plunder_only_enemy_hits", _near(a.mp, 90.0))
	XTianqiFamineAlien.unit(lg, g).idx = 2
	var sh := float(g.shield)
	a.mp = 100.0
	a.tp = 100.0
	XTianqiFamineAlien.hp_damage(lg, g, a, 10.0)
	_check("plunder_huaxing_shield", _near(float(g.shield) - sh, 30.0), [g.shield, sh])
	lg.end_battle(0)


func _alien_night_overdraw() -> void:
	var lg := _alien_logic("apostle30", 466)
	var boss: XEnemy = lg.enemies.filter(func(x): return XTianqiFamineAlien.is_alien(lg, x))[0]
	_check("apostle30_name", boss.display_name().begins_with("化形·") and str(XTianqiFamineAlien.unit(lg, boss).kind) == "overdraw", boss.display_name())
	var a: XActor = lg.actors[0]
	var sk := _skill(true)
	a.mp = a.mmp
	var hp0 := a.hp
	lg.pay_skill_cost(a, sk)
	_check("overdraw_huaxing_mhp", _near(a.hp, hp0 - floorf(a.mhp * 0.06)), [hp0, a.hp, a.mhp])
	hp0 = a.hp
	lg.pay_skill_cost(a, XDB.rec("Skills", 2))
	_check("overdraw_guard_free", _near(a.hp, hp0))
	# 熬夜者（按段异化才出，这里把同一只临时换成熬夜者看规则）
	var u := XTianqiFamineAlien.unit(lg, boss)
	u.kind = "night"
	u.idx = 1
	_check("night_tp", _near(XTianqiFamineAlien.gain(a, "tp", 100.0), 50.0) and _near(XTianqiFamineAlien.tp_gain(lg, a, 100.0), 50.0)
		and _near(XTianqiFamineAlien.regen(lg, a, 0.0, 0.0, 10.0)[2], 5.0))
	a.tp = 50.0
	XTianqiFamineAlien.end_turn(lg)
	_check("night_shigu_no_drain", _near(a.tp, 50.0))
	u.idx = 2
	XTianqiFamineAlien.end_turn(lg)
	_check("night_huaxing_drain", _near(a.tp, 40.0), a.tp)
	lg.end_battle(0)


func _survival() -> void:
	var s := _state(20000000.0, "famine")
	_check("survival_prepare", XTianqiHorsemen.prepare("famine", s, "survival"))
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var kn: XEnemy = lg.enemies[0]
	var f := XTianqiHorsemen.fight(lg)
	var st := XTianqiHorsemen.survival_stats("famine", "jianxian")
	_check("survival_mode", XTianqiHorsemen.mode_of(lg) == "survival" and _near(kn.atk, float(st.atk)), [kn.atk, st.atk])
	var adds: Array = f.adds
	var row := XTianqiBalance.difficulty("jianxian")
	var shell := XDB.rec("Enemies", 514)
	_check("survival_adds", adds.size() == 3 and lg.alive(adds).size() == 3 and adds[0].display_name().begins_with("饿出来的小怪")
		and _near(adds[0].mhp, roundf(float(shell.params[0]) * float(row.enemy_hp))), [adds.size(), adds[0].display_name(), adds[0].mhp])
	# 绝粮：MP、TP 不能恢复
	var a: XActor = lg.actors[0]
	_check("survival_starved", XTianqiHorsemen.starved(a, "mp", 10.0) and XTianqiHorsemen.starved(a, "tp", 10.0))
	var devoured := false
	for t in range(6):
		var logs := lg.run_turn(_guard_all(lg))
		devoured = devoured or _texts(logs).any(func(x): return x.contains("资历"))
		if lg.is_lost():
			break
	_check("survival_devour", devoured)
	_check("survival_no_phase", int(f.phase) == 1)
	_check("survival_win", XTianqiHorsemen.survived(lg) and lg.is_won() and not lg.is_lost(), [lg.turn, lg.alive(lg.actors).size()])
	lg.end_battle(0)


func _shadow() -> void:
	var s := _state(20000000.0, "famine")
	_check("shadow_prepare", XTianqiHorsemen.prepare("famine", s, "shadow"))
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var kn: XEnemy = lg.enemies[0]
	_check("shadow_no_adds", XTianqiHorsemen.fight(lg).adds.is_empty() and lg.enemies.size() == 1)
	var kinds := {}
	for t in range(3):
		var logs := lg.run_turn(_guard_all(lg))
		for l in logs:
			if l.type == "action" and is_same(l.user, kn):
				kinds[str(l.skill.get("tianqi_horseman", ""))] = true
	_check("shadow_moves", kinds.keys() == ["sea"], kinds.keys())
	lg.end_battle(0)


func _plain() -> void:
	# 原版档：不收、敌群不变、门不锁、没有序幕
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var p := XState.new_game_blank()
	for id in lineup:
		p.add_actor(int(id))
	p.set_variable(20, 6)
	XState.current = p
	_check("plain_no_prepare", not XTianqiFamineAlien.prepare("omen", p) and not XTianqiHorsemen.prepare("famine", p, "survival"))
	var lg := XBattleLogic.new()
	lg.setup(11, p)
	_check("plain_battle", not XTianqiFamineAlien.active(lg) and not lg.enemies[0].display_name().contains("·"))
	_check("plain_door", not XTianqiLine.door_blocked(p) and XTianqiLine.arrival_beat(p, 6) == "")
	lg.end_battle(0)
	# 战争线存档：饥荒的异化不收
	var w := _state(0.0, "war")
	_check("other_line", not XTianqiFamineLine.allowed(w) and not XTianqiFamineAlien.prepare("omen", w))
	# 饥荒线开关关掉：选线里不能选、使徒不变
	var s2 := _state(0.0, "famine")
	_done(s2)
	XTianqiFamineLine.ENABLED = false
	var host := FakeHost.new()
	await XTianqiLine.before_battle(host, s2, 69)
	_check("switch_off", not XTianqiFamineLine.allowed(s2) and XTianqiFamineAlien.pending() == "" and host.said.is_empty() and not XTianqi.line_playable("famine"))
	XTianqiFamineLine.ENABLED = true
