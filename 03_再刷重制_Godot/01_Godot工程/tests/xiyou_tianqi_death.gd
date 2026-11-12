extends Node
## 天启篇死亡线专项（XTianqiDeathLine、XTianqiDeathAlien、death_line.json，四骑士 horsemen.json 的死亡 survival／shadow；流程走 XTianqiLine）。
## 一、数据：数字避开 4、台词和敌群齐全、种类五种。
## 二、选线与开场：选死亡线后开场三节（勇者之塔一层 → 二层训犬 → 三层罗奇 → 王座 → 天外天生存战），输了回大厅、走门接着打。
## 三、楼层节点：10／20／30 层使徒；15、25 层；35 层影子、36 层决战。
## 四、异化战斗：宣判者挂死期（回合结束带走，打倒它解开）、收尸人（倒下一人变强，化形锁复活）、替身、骑士队长（逃跑失败、化形当场结算）、丧钟。
## 五、生存战（每 3 回合死期、撑过 6 回合）和影子（神圣剑／挂死期，死者不能复活）。
## 六、原版档、别的线、开关关掉：一处都不动。
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
		battles.append({"troop": troop, "escape": can_escape, "lose": can_lose, "alien": XTianqiDeathAlien.pending(),
			"knight": XTianqiHorsemen.pending(), "mode": XTianqiHorsemen._pending_mode})
		XTianqiDeathAlien._pending = ""
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
	XTianqiDeathLine.progress(s)["stage"] = XTianqiDeathLine.STAGE_DONE


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
	await _choose_and_opening()
	await _beats()
	_alien_verdict()
	_alien_reaper()
	_alien_double()
	_alien_captain_knell()
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
	_check("nice_numbers_death_line", XTianqiLine.nice_number_violations("death").is_empty(), XTianqiLine.nice_number_violations("death"))
	_check("nice_numbers_horsemen", XTianqiHorsemen.nice_number_violations().is_empty(), XTianqiHorsemen.nice_number_violations())
	var keys := ["choose", "omen_before", "omen_arrive", "omen_dogs", "omen_win", "spread_before", "spread_win", "lose_retry",
		"rift_before", "rift_survived", "rift_lost", "rift_after", "rift_home", "apostle10", "apostle20", "apostle30", "echo15", "rumor25",
		"shadow_before", "final_before", "final_win", "final_lost"]
	var miss := keys.filter(func(k): return XTianqiLine.scene("death", k).is_empty())
	_check("scenes_all", miss.is_empty(), miss)
	for k in ["omen", "spread", "apostle10", "apostle20", "apostle30"]:
		var p := XTianqiDeathAlien.preset(k)
		_check("preset_troop_" + k, not XDB.rec("Troops", int(p.troop)).is_empty() and not XTianqiDeathAlien.tier_info(str(p.tier)).is_empty()
			and not XTianqiDeathAlien.kind_info(str(p.kind)).is_empty(), p)
	for k in ["omen", "spread"]:
		_check("stats_from_" + k, not XDB.rec("Enemies", int(XTianqiDeathAlien.preset(k).stats_from)).is_empty())
	var kinds := XTianqiDeathAlien.kinds()
	kinds.sort()
	_check("kinds_five", kinds == ["captain", "double", "knell", "reaper", "verdict"], kinds)
	_check("stage_done", XTianqiLine.stage_done("death") == XTianqiDeathLine.STAGE_DONE)
	_check("death_card", XTianqi.line_playable("death") and XTianqi.line_playable("war") and XTianqi.line_playable("famine")
		and XTianqi.line_playable("plague"))


func _death_index() -> int:
	for i in XTianqi.LINES.size():
		if str(XTianqi.LINES[i].key) == "death":
			return i
	return -1


func _choose_and_opening() -> void:
	var s := _state()
	var host := FakeHost.new()
	host.answers = [_death_index(), 0]
	host.results = [2]
	await XTianqi.run_line_choice(host, s)
	_check("chosen_death", XTianqi.line_of(s) == "death" and XTianqiDeathLine.allowed(s) and not XTianqiFamineLine.allowed(s) and not XTianqiWarLine.allowed(s))
	_check("card_shown", host.said.any(func(t): return str(t).contains("尽快结束战斗")))
	_check("choose_said", host.said.any(func(t): return str(t).contains("骨白色")))
	_check("omen_battle", host.battles.size() == 1 and host.battles[0].troop == 291 and host.battles[0].alien == "omen" and host.battles[0].lose, host.battles)
	_check("omen_went_tower", host.moves.size() >= 2 and host.moves[0] == [82, 15, 25, 8] and host.moves[1][0] == 83, host.moves)
	_check("omen_taught", host.said.any(func(t): return str(t).contains("死期")))
	_check("omen_lost_home", XTianqiLine.stage("death", s) == 0 and host.moves[-1][0] == 4)
	_check("door_resumes", XTianqiLine.door_blocked(s) and XTianqiLine.due("death", s))
	host.battles.clear()
	host.moves.clear()
	host.said.clear()
	host.results = [0, 0, 0]
	_check("run_door_true", await XTianqiLine.run_door(host, s))
	_check("opening_three_battles", host.battles.size() == 3 and host.battles[1].troop == 294 and host.battles[1].alien == "spread"
		and host.battles[2].knight == "death" and host.battles[2].mode == "survival", host.battles)
	_check("opening_moves", host.moves.map(func(m): return int(m[0])) == [82, 83, 84, 85, 158, 4], host.moves)
	_check("opening_done", XTianqiLine.opening_done("death", s) and bool(XTianqiDeathLine.progress(s).get("survived", false)))
	_check("throne_said", host.said.any(func(t): return str(t).contains("现在一切结束了")) and host.said.any(func(t): return str(t).contains("来收尾")))
	_check("door_open", not XTianqiLine.door_blocked(s))
	var back := XState.from_dict(s.to_dict())
	_check("progress_saved", XTianqiLine.opening_done("death", back) and XTianqi.line_of(back) == "death")


func _beats() -> void:
	var s := _state(0.0, "death")
	var host := FakeHost.new()
	await XTianqiLine.before_battle(host, s, 69)
	_check("apostle_before_opening", XTianqiDeathAlien.pending() == "" and host.said.is_empty())
	_done(s)
	for pair in [[69, "apostle10"], [456, "apostle20"], [466, "apostle30"]]:
		host.said.clear()
		await XTianqiLine.before_battle(host, s, int(pair[0]))
		_check(str(pair[1]), XTianqiDeathAlien.pending() == str(pair[1]) and host.said.any(func(t): return str(t).contains("死亡骑士的声音")), [XTianqiDeathAlien.pending(), host.said])
		XTianqiDeathAlien._pending = ""
	_check("other_aliens_untouched", XTianqiWarAlien.pending() == "" and XTianqiFamineAlien.pending() == "")
	host.said.clear()
	await XTianqiLine.run_arrival(host, s, 32)
	_check("echo15", host.said.any(func(t): return str(t).contains("值班表")) and XTianqiLine.arrival_beat(s, 32) == "")
	host.said.clear()
	await XTianqiLine.run_arrival(host, s, 147)
	_check("rumor25", host.said.any(func(t): return str(t).contains("放烟火")) and host.asked.is_empty())
	host.battles.clear()
	host.results = [0, 0]
	_check("shadow_result", await XTianqiDeathLine.run_shadow(host, s) == 0 and host.battles[0].knight == "death" and host.battles[0].mode == "shadow", host.battles)
	host.said.clear()
	_check("final_win", await XTianqiDeathLine.run_final(host, s) == 0 and bool(XTianqiDeathLine.progress(s).cleared)
		and host.said.any(func(t): return str(t).contains("我是来改的")), host.battles)


func _alien_logic(preset: String, troop: int, tough := 20000000.0) -> XBattleLogic:
	var s := _state(tough, "death")
	_check("prepare_" + preset, XTianqiDeathAlien.prepare(preset, s))
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	return lg


func _plain_logic(troop: int) -> XBattleLogic:
	var s := _state(20000000.0, "death")
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	return lg


func _alien_verdict() -> void:
	var plain := _plain_logic(291)
	var hp_plain: float = plain.enemies[0].mhp
	plain.end_battle(0)
	var lg := _alien_logic("omen", 291)
	var e: XEnemy = lg.enemies[0]
	_check("omen_one_alien", XTianqiDeathAlien.is_alien(lg, e) and not XTianqiDeathAlien.is_alien(lg, lg.enemies[1]))
	_check("omen_name", e.display_name().begins_with("侵染·") and e.display_name().contains("恶魔训犬"), e.display_name())
	_check("omen_stats_from", e.mhp < hp_plain / 10.0 and lg.enemies[1].mhp < hp_plain / 10.0 and _near(e.hp, e.mhp), [e.mhp, lg.enemies[1].mhp, hp_plain])
	var plain_e: XEnemy = lg.enemies[1]
	var hp_rate := plain_e.mhp / maxf(1.0, float(XDB.rec("Enemies", 31).params[0]))
	_check("omen_others_borrowed", lg.enemies.slice(1).all(func(x): return _near(x.mhp, plain_e.mhp)) and _near(plain_e.mhp, 200000.0), [plain_e.mhp, hp_rate])  # 火焰哥布林 2000 × 艰险敌人血量 100
	_check("omen_hp_tier", _near(e.mhp, plain_e.mhp * 1.25, 1e-2), [e.mhp, plain_e.mhp])
	# 侵染：每 5 回合挂一次
	lg.turn = 3
	XTianqiDeathAlien.start_turn(lg)
	_check("verdict_not_yet", XTianqiDeathAlien.fight(lg).doom.is_empty())
	lg.turn = 5
	var logs := XTianqiDeathAlien.start_turn(lg)
	var f := XTianqiDeathAlien.fight(lg)
	_check("verdict_marked", f.doom.size() == 1 and _texts(logs).any(func(t): return t.contains("现在一切结束了")), _texts(logs))
	var t = f.doom.keys()[0]
	# 打倒宣判者：死期解开
	e.hp = 0.0
	e.refresh_resources()
	lg._die(e)
	XTianqiDeathAlien.after_action(lg, lg.actors[0])
	_check("verdict_lifted", f.doom.is_empty() and t.is_alive())
	XTianqiDeathAlien.end_turn(lg)
	_check("lifted_survives", t.is_alive())
	lg.end_battle(0)
	# 没打倒：回合结束带走
	var lg2 := _alien_logic("omen", 291)
	lg2.turn = 5
	XTianqiDeathAlien.start_turn(lg2)
	var f2 := XTianqiDeathAlien.fight(lg2)
	var t2 = f2.doom.keys()[0]
	_check("doomed_query", XTianqiDeathAlien.doomed(lg2, t2))
	var el := XTianqiDeathAlien.end_turn(lg2)
	_check("doom_kills", t2.is_dead() and f2.doom.is_empty() and _texts(el).any(func(x): return x.contains("死期")), _texts(el))
	_check("doom_revivable_qinran", not XTianqiDeathAlien.blocks_revive(t2))
	# 终焉：一次两人、死者不能复活
	var u := XTianqiDeathAlien.unit(lg2, lg2.enemies[0])
	u.idx = 3
	u.last = 0
	lg2.turn = 6
	XTianqiDeathAlien.start_turn(lg2)
	_check("verdict_zhongyan_two", f2.doom.size() == 2, f2.doom.size())
	var victims: Array = f2.doom.keys()
	XTianqiDeathAlien.end_turn(lg2)
	_check("zhongyan_no_revive", victims.all(func(a): return a.is_dead() and XTianqiDeathAlien.blocks_revive(a)))
	victims[0].remove_state(1)
	_check("zhongyan_remove_state_blocked", victims[0].is_dead())
	lg2.end_battle(0)
	_check("end_clears", not XTianqiDeathAlien.active(lg2) and XTianqiDeathAlien.active_logic() == null and not lg2.enemies[0].has_meta("tianqi_prefix"))


func _alien_reaper() -> void:
	var lg := _alien_logic("spread", 294)
	var boss: XEnemy = lg.enemies[0]
	_check("spread_name", boss.display_name().begins_with("蚀骨·") and boss.display_name().contains("罗奇") and str(XTianqiDeathAlien.unit(lg, boss).kind) == "reaper", boss.display_name())
	var atk0 := boss.atk
	boss.hp = boss.mhp * 0.5
	var a: XActor = lg.actors[0]
	a.hp = 0.0
	a.refresh_resources()
	lg._die(a)
	var logs := XTianqiDeathAlien.after_action(lg, lg.actors[1])
	_check("reaper_up", boss.atk > atk0 and boss.hp > boss.mhp * 0.5 and _texts(logs).any(func(t): return t.contains("收走")), [atk0, boss.atk, _texts(logs)])
	var atk1 := boss.atk
	XTianqiDeathAlien.after_action(lg, lg.actors[1])
	_check("reaper_once_per_death", _near(boss.atk, atk1))
	_check("reaper_shigu_no_lock", not XTianqiDeathAlien.blocks_revive(a))
	# 化形：倒下的人 2 回合内不能复活
	XTianqiDeathAlien.unit(lg, boss).idx = 2
	var b: XActor = lg.actors[1]
	lg.turn = 3
	b.hp = 0.0
	b.refresh_resources()
	lg._die(b)
	XTianqiDeathAlien.after_action(lg, lg.actors[2])
	_check("reaper_huaxing_lock", XTianqiDeathAlien.blocks_revive(b))
	lg.turn = 5
	_check("reaper_lock_ends", not XTianqiDeathAlien.blocks_revive(b))
	lg.end_battle(0)


func _alien_double() -> void:
	var lg := _alien_logic("apostle20", 456)
	var g: XEnemy = lg.enemies.filter(func(x): return XTianqiDeathAlien.is_alien(lg, x))[0]
	_check("apostle20_double", g.display_name().begins_with("蚀骨·") and str(XTianqiDeathAlien.unit(lg, g).kind) == "double", g.display_name())
	var a: XActor = lg.actors[0]
	# 没人低于 50%：不换
	_check("double_no_victim", _near(XTianqiDeathAlien.hp_damage(lg, a, g, g.hp + 10.0), g.hp + 10.0))
	var low: XActor = lg.actors[2]
	low.hp = floorf(low.mhp * 0.3)
	low.refresh_resources()
	var out := XTianqiDeathAlien.hp_damage(lg, a, g, g.hp + 10.0)
	_check("double_swap", _near(out, 0.0) and low.is_dead() and g.is_alive() and _near(g.hp, maxf(1.0, floorf(g.mhp * 0.3))), [out, g.hp, g.mhp])
	_check("double_not_lethal_passthrough", _near(XTianqiDeathAlien.hp_damage(lg, a, g, 1.0), 1.0))
	var low2: XActor = lg.actors[3]
	low2.hp = 1.0
	low2.refresh_resources()
	_check("double_once_shigu", _near(XTianqiDeathAlien.hp_damage(lg, a, g, g.hp + 10.0), g.hp + 10.0) and low2.is_alive())
	lg.end_battle(0)


func _alien_captain_knell() -> void:
	var lg := _alien_logic("apostle30", 466)
	var c: XEnemy = lg.enemies.filter(func(x): return XTianqiDeathAlien.is_alien(lg, x))[0]
	_check("apostle30_captain", c.display_name().begins_with("化形·") and str(XTianqiDeathAlien.unit(lg, c).kind) == "captain", c.display_name())
	_check("captain_no_escape", not lg.can_escape and not lg.try_escape() and XTianqiDeathAlien.blocks_escape(lg))
	# 化形骑士队长：被挂死期的人行动完立刻结算
	var f := XTianqiDeathAlien.fight(lg)
	var a: XActor = lg.actors[0]
	f.doom[a] = c
	XTianqiDeathAlien.after_action(lg, lg.actors[1])
	_check("captain_not_others", a.is_alive() and f.doom.has(a))
	XTianqiDeathAlien.after_action(lg, a)
	_check("captain_resolve_now", a.is_dead() and not f.doom.has(a))
	# 丧钟（按段异化才出，这里把同一只临时换成丧钟看规则）：倒数归零带走生命比例最低的一人；化形起全体另掉 20%
	var u := XTianqiDeathAlien.unit(lg, c)
	u.kind = "knell"
	u.count = 1
	var low: XActor = lg.actors[2]
	low.hp = floorf(low.mhp * 0.5)
	low.refresh_resources()
	var other: XActor = lg.actors[3]
	var hp_other := other.hp
	var logs := XTianqiDeathAlien.end_turn(lg)
	_check("knell_kills_lowest", low.is_dead() and _texts(logs).any(func(t): return t.contains("钟声")), _texts(logs))
	_check("knell_toll_loss", _near(other.hp, hp_other - floorf(other.mhp * 0.2)), [hp_other, other.hp])
	_check("knell_reset", int(u.count) == 3, u.count)
	_check("captain_gone_escape_ok", not XTianqiDeathAlien.blocks_escape(lg))
	lg.end_battle(0)


func _survival() -> void:
	var s := _state(20000000.0, "death")
	_check("survival_prepare", XTianqiHorsemen.prepare("death", s, "survival"))
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var kn: XEnemy = lg.enemies[0]
	var f := XTianqiHorsemen.fight(lg)
	var st := XTianqiHorsemen.survival_stats("death", "jianxian")
	_check("survival_mode", XTianqiHorsemen.mode_of(lg) == "survival" and _near(kn.atk, float(st.atk)) and f.adds.is_empty(), [kn.atk, st.atk])
	var doom_turns := []
	for t in range(6):
		var logs := lg.run_turn(_guard_all(lg))
		if _texts(logs).any(func(x): return x.contains("死期：")):
			doom_turns.append(int(lg.turn))
		if lg.is_lost():
			break
	_check("survival_doom_every_3", doom_turns == [3, 6], doom_turns)
	_check("survival_no_phase", int(f.phase) == 1 and not bool(f.captain))
	_check("survival_win", XTianqiHorsemen.survived(lg) and lg.is_won() and not lg.is_lost(), [lg.turn, lg.alive(lg.actors).size()])
	lg.end_battle(0)


func _shadow() -> void:
	var s := _state(20000000.0, "death")
	_check("shadow_prepare", XTianqiHorsemen.prepare("death", s, "shadow"))
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var kn: XEnemy = lg.enemies[0]
	_check("shadow_alone", lg.enemies.size() == 1 and int(XTianqiHorsemen.fight(lg).base.actions) == 1)
	var kinds := {}
	var sword_hits := 0
	for t in range(2):
		var logs := lg.run_turn(_guard_all(lg))
		var in_sword := false
		for l in logs:
			if l.type == "action":
				in_sword = is_same(l.user, kn) and str(l.skill.get("tianqi_horseman", "")) == "holy_sword"
				if is_same(l.user, kn):
					kinds[str(l.skill.get("tianqi_horseman", ""))] = true
			elif l.type == "hit" and in_sword:
				sword_hits += 1
	var ks := kinds.keys()
	ks.sort()
	_check("shadow_moves", ks == ["doom_cast", "holy_sword"], ks)
	_check("shadow_sword_six", sword_hits == 6, sword_hits)
	var dead := lg.actors.filter(func(a): return a.is_dead())
	_check("shadow_doom_killed", dead.size() == 1, dead.size())
	if not dead.is_empty():
		_check("shadow_no_revive", XTianqiHorsemen.blocks_revive(dead[0]))
	lg.end_battle(0)


func _plain() -> void:
	# 原版档：不收、敌群不变、门不锁
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var p := XState.new_game_blank()
	for id in lineup:
		p.add_actor(int(id))
	p.set_variable(20, 6)
	XState.current = p
	_check("plain_no_prepare", not XTianqiDeathAlien.prepare("omen", p) and not XTianqiHorsemen.prepare("death", p, "survival"))
	var lg := XBattleLogic.new()
	lg.setup(291, p)
	_check("plain_battle", not XTianqiDeathAlien.active(lg) and not lg.enemies[0].display_name().contains("·") and lg.can_escape)
	_check("plain_door", not XTianqiLine.door_blocked(p))
	lg.end_battle(0)
	# 饥荒线存档：死亡的异化不收
	var w := _state(0.0, "famine")
	_check("other_line", not XTianqiDeathLine.allowed(w) and not XTianqiDeathAlien.prepare("omen", w))
	# 死亡线开关关掉：选线里不能选、使徒不变
	var s2 := _state(0.0, "death")
	_done(s2)
	XTianqiDeathLine.ENABLED = false
	var host := FakeHost.new()
	await XTianqiLine.before_battle(host, s2, 69)
	_check("switch_off", not XTianqiDeathLine.allowed(s2) and XTianqiDeathAlien.pending() == "" and host.said.is_empty() and not XTianqi.line_playable("death"))
	XTianqiDeathLine.ENABLED = true
