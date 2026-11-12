extends Node
## 天启篇瘟疫线专项（XTianqiPlagueLine、XTianqiPlagueAlien、plague_line.json，四骑士 horsemen.json 的瘟疫 survival／shadow）。
## 一、数据：数字避开 4、台词和敌群齐全。
## 二、选线与开场：选瘟疫线后开场三节（七层猪猪农场 → 农场深处 → 天外天生存战），输了回大厅、走门接着打。
## 三、楼层节点：10／20／30 层使徒；15、25 层；25 层捡盾碎片（36 层打碎盾要的伤害降低）。
## 四、异化战斗：毒腺中毒（化形叠层）、病弱、病灶爆发、混乱者、挑衅者（只能打它、不服、坦克、化形群攻减半）、传染者、疫源（延长、净化失败、化形染上）。
## 五、生存战（开场即疫病、撑过 6 回合）和影子（不服来打我）。
## 六、原版档、没选瘟疫线、开关关掉：一处都不动；按段异化入口 kinds／apply。
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
		battles.append({"troop": troop, "escape": can_escape, "lose": can_lose, "alien": XTianqiPlagueAlien.pending(),
			"knight": XTianqiHorsemen.pending(), "mode": XTianqiHorsemen._pending_mode})
		XTianqiPlagueAlien._pending = ""
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
	XTianqiPlagueLine.progress(s)["stage"] = XTianqiPlagueLine.STAGE_DONE


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
	_gland()
	_focus()
	_chaos()
	_taunt()
	_contagion()
	_source()
	_survival()
	_shadow()
	_segment()
	await _plain()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _data() -> void:
	XTianqiLine.reload()
	XTianqiHorsemen.reload()
	_check("nice_numbers_plague_line", XTianqiLine.nice_number_violations("plague").is_empty(), XTianqiLine.nice_number_violations("plague"))
	_check("nice_numbers_horsemen", XTianqiHorsemen.nice_number_violations().is_empty(), XTianqiHorsemen.nice_number_violations())
	var keys := ["choose", "omen_before", "omen_arrive", "omen_win", "spread_before", "spread_win", "lose_retry",
		"rift_before", "rift_survived", "rift_lost", "rift_after", "rift_home", "apostle10", "apostle20", "apostle30", "echo15", "rumor25",
		"shard_offer", "shard_take", "shadow_before", "final_before", "final_win", "final_lost"]
	var miss := keys.filter(func(k): return XTianqiLine.scene("plague", k).is_empty())
	_check("scenes_all", miss.is_empty(), miss)
	for k in ["omen", "spread", "apostle10", "apostle20", "apostle30"]:
		var p := XTianqiPlagueAlien.preset(k)
		_check("preset_troop_" + k, not XDB.rec("Troops", int(p.troop)).is_empty() and not XTianqiPlagueAlien.tier_info(str(p.tier)).is_empty()
			and not XTianqiPlagueAlien.kind_info(str(p.kind)).is_empty(), p)
	_check("stage_done", XTianqiLine.stage_done("plague") == XTianqiPlagueLine.STAGE_DONE)
	_check("plague_card", XTianqi.line_info("plague").pick == "「不服来打我。」" and XTianqi.line_playable("plague") and XTianqi.line_playable("war")
		and XTianqi.line_playable("famine") and XTianqi.line_playable("death"))
	_check("kinds_five", XTianqiPlagueAlien.kinds().size() == 5 and ["gland", "chaos", "taunt", "contagion", "source"].all(func(k): return XTianqiPlagueAlien.kinds().has(k)))


func _plague_index() -> int:
	for i in XTianqi.LINES.size():
		if str(XTianqi.LINES[i].key) == "plague":
			return i
	return -1


func _choose_and_opening() -> void:
	var s := _state()
	var host := FakeHost.new()
	host.answers = [_plague_index(), 0]
	host.results = [2]
	await XTianqi.run_line_choice(host, s)
	_check("chosen_plague", XTianqi.line_of(s) == "plague" and XTianqiPlagueLine.allowed(s) and not XTianqiFamineLine.allowed(s) and not XTianqiWarLine.allowed(s))
	_check("choose_said", host.said.any(func(t): return str(t).contains("病绿")))
	_check("omen_battle", host.battles.size() == 1 and host.battles[0].troop == 247 and host.battles[0].alien == "omen" and host.battles[0].lose, host.battles)
	_check("omen_went_farm", not host.moves.is_empty() and host.moves[0] == [61, 4, 16, 8], host.moves)
	_check("omen_taught", host.said.any(func(t): return str(t).contains("病灶")) and host.said.any(func(t): return str(t).contains("漩涡")))
	_check("omen_lost_home", XTianqiLine.stage("plague", s) == 0 and host.moves[-1][0] == 4)
	_check("door_resumes", XTianqiLine.door_blocked(s) and XTianqiLine.due("plague", s))
	host.battles.clear()
	host.moves.clear()
	host.said.clear()
	host.results = [0, 0, 0]
	_check("run_door_true", await XTianqiLine.run_door(host, s))
	_check("opening_three_battles", host.battles.size() == 3 and host.battles[1].troop == 248 and host.battles[1].alien == "spread"
		and host.battles[2].knight == "plague" and host.battles[2].mode == "survival", host.battles)
	_check("opening_moves", host.moves.map(func(m): return int(m[0])) == [61, 61, 158, 4] and host.moves[1] == [61, 22, 20, 8], host.moves)
	_check("opening_done", XTianqiLine.opening_done("plague", s) and bool(XTianqiPlagueLine.progress(s).get("survived", false)))
	_check("rift_said", host.said.any(func(t): return str(t).contains("不服来打我")) and host.said.any(func(t): return str(t).contains("也不服")))
	_check("door_open", not XTianqiLine.door_blocked(s))
	var back := XState.from_dict(s.to_dict())
	_check("progress_saved", XTianqiLine.opening_done("plague", back) and XTianqi.line_of(back) == "plague")


func _beats() -> void:
	var s := _state(0.0, "plague")
	var host := FakeHost.new()
	await XTianqiLine.before_battle(host, s, 69)
	_check("apostle_before_opening", XTianqiPlagueAlien.pending() == "" and host.said.is_empty())
	_done(s)
	for pair in [[69, "apostle10"], [456, "apostle20"], [466, "apostle30"]]:
		host.said.clear()
		await XTianqiLine.before_battle(host, s, int(pair[0]))
		_check(str(pair[1]), XTianqiPlagueAlien.pending() == str(pair[1]) and host.said.any(func(t): return str(t).contains("瘟疫骑士的声音")), [XTianqiPlagueAlien.pending(), host.said])
		XTianqiPlagueAlien._pending = ""
	_check("other_aliens_untouched", XTianqiWarAlien.pending() == "" and XTianqiFamineAlien.pending() == "")
	host.said.clear()
	await XTianqiLine.run_arrival(host, s, 32)
	_check("echo15", host.said.any(func(t): return str(t).contains("越往里越歪")) and XTianqiLine.arrival_beat(s, 32) == "")
	_check("shard_none", _near(XTianqiPlagueLine.shield_need_mult(s), 1.0))
	host.said.clear()
	host.answers = [0]
	await XTianqiLine.run_arrival(host, s, 147)
	_check("rumor25", host.said.any(func(t): return str(t).contains("放烟火")))
	_check("shard_taken", bool(XTianqiPlagueLine.progress(s).get("shard", false)) and _near(XTianqiPlagueLine.shield_need_mult(s), 0.67, 1e-3))
	var s2 := _state(0.0, "plague")
	_done(s2)
	var h2 := FakeHost.new()
	h2.answers = [1]
	await XTianqiLine.run_arrival(h2, s2, 147)
	_check("shard_skip", not XTianqiPlagueLine.progress(s2).has("shard") and h2.asked.size() == 1)
	# 盾碎片在 36 层：盾要的累计伤害 ×0.67
	XState.current = s
	_check("shard_body_prepare", XTianqiHorsemen.prepare("plague", s))
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var f := XTianqiHorsemen.fight(lg)
	f.shield_open = true
	var need := float(f.knight.mhp) * float(XTianqiHorsemen.knight("plague").shield.break)
	XTianqiHorsemen._shield_hit(f, need * 0.7, 2)
	_check("shard_shield_breaks_early", int(f.broken_turn) == 2, [need, f.shield_acc])
	lg.end_battle(0)
	host.battles.clear()
	host.results = [0, 0]
	_check("shadow_result", await XTianqiPlagueLine.run_shadow(host, s) == 0 and host.battles[0].knight == "plague" and host.battles[0].mode == "shadow", host.battles)
	host.said.clear()
	_check("final_win", await XTianqiPlagueLine.run_final(host, s) == 0 and bool(XTianqiPlagueLine.progress(s).cleared)
		and host.said.any(func(t): return str(t).contains("你也不服")), host.battles)


func _alien_logic(preset: String, troop: int, tough := 20000000.0) -> XBattleLogic:
	var s := _state(tough, "plague")
	_check("prepare_" + preset, XTianqiPlagueAlien.prepare(preset, s))
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	return lg


## 把敌群 troop 里第 i 只按 tier／kind 变成异化怪（走按段异化的 apply 入口）
func _kind_logic(troop: int, rows: Array) -> XBattleLogic:
	var s := _state(20000000.0, "plague")
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	var list := rows.map(func(r): return {"enemy": lg.enemies[int(r[0])], "tier": str(r[1]), "kind": str(r[2])})
	_check("apply_%d_%s" % [troop, str(rows[0][2])], XTianqiPlagueAlien.apply(lg, s, "test", list))
	return lg


func _gland() -> void:
	var lg := _alien_logic("omen", 247)
	var e: XEnemy = lg.enemies[2]
	_check("omen_one_alien", XTianqiPlagueAlien.is_alien(lg, e) and not XTianqiPlagueAlien.is_alien(lg, lg.enemies[0]))
	_check("omen_name", e.display_name().begins_with("侵染·") and e.display_name().contains("野猪头目"), e.display_name())
	_check("omen_hp", _near(e.mhp, e.param_base(0) * 1.25, 1e-3) and _near(e.hp, e.mhp), [e.mhp, e.param_base(0)])
	var a: XActor = lg.actors[0]
	XTianqiPlagueAlien.refresh(lg)
	var atk0 := a.param(2)
	var def0 := a.param(3)
	XTianqiPlagueAlien.hp_damage(lg, e, a, 100.0)
	_check("gland_poison", XTianqiPlagueAlien.mark_of(lg, a).poison == [3], XTianqiPlagueAlien.mark_of(lg, a))
	XTianqiPlagueAlien.hp_damage(lg, e, a, 100.0)
	_check("gland_no_stack_low", XTianqiPlagueAlien.mark_of(lg, a).poison.size() == 1)
	XTianqiPlagueAlien.hp_damage(lg, lg.enemies[0], a, 100.0)
	_check("plain_enemy_no_poison", XTianqiPlagueAlien.mark_of(lg, a).poison.size() == 1)
	XTianqiPlagueAlien.refresh(lg)
	_check("frail_one", int(XTianqiPlagueAlien.fight(lg).debuffs[a]) == 1 and _near(a.param(2), roundf(atk0 * 0.97), 1e-3)
		and _near(a.param(3), roundf(def0 * 0.97), 1e-3), [atk0, a.param(2), def0, a.param(3)])
	a.hp = floorf(a.mhp * 0.5)
	var hp0 := a.hp
	var logs := XTianqiPlagueAlien.end_turn(lg)
	_check("gland_tick", _near(a.hp, hp0 - floorf(a.mhp * 0.03)) and XTianqiPlagueAlien.mark_of(lg, a).poison == [2], [hp0, a.hp, a.mhp])
	_check("gland_logged", logs.any(func(l): return l.type == "regen" and is_same(l.target, a)))
	XTianqiPlagueAlien.unit(lg, e).idx = 2
	for i in 3:
		XTianqiPlagueAlien.hp_damage(lg, e, a, 100.0)
	_check("gland_huaxing_stack", XTianqiPlagueAlien.mark_of(lg, a).poison.size() == 3, XTianqiPlagueAlien.mark_of(lg, a))
	XTianqiPlagueAlien.refresh(lg)
	_check("frail_poison_counts_once", int(XTianqiPlagueAlien.fight(lg).debuffs[a]) == 1)
	# 异化怪倒下：病弱散去
	e.hp = 0.0
	e.refresh_resources()
	lg._die(e)
	XTianqiPlagueAlien.refresh(lg)
	_check("frail_gone", _near(a.param(2), atk0) and XTianqiPlagueAlien.focus_text(lg) == "瘟疫散去了。", [atk0, a.param(2)])
	lg.end_battle(0)
	_check("end_clears", not XTianqiPlagueAlien.active(lg) and XTianqiPlagueAlien.active_logic() == null)


func _focus() -> void:
	var lg := _alien_logic("omen", 247)
	var e: XEnemy = lg.enemies[2]
	XTianqiPlagueAlien.unit(lg, e).idx = 2
	XTianqiPlagueAlien.refresh(lg)
	_check("focus_text", XTianqiPlagueAlien.focus_text(lg).contains("病灶 0／12"), XTianqiPlagueAlien.focus_text(lg))
	var hp := {}
	for a in lg.actors:
		for i in 3:
			XTianqiPlagueAlien.hp_damage(lg, e, a, 100.0)
		hp[a] = a.hp
	XTianqiPlagueAlien.take_logs(lg)
	XTianqiPlagueAlien.refresh(lg)
	var f := XTianqiPlagueAlien.fight(lg)
	var texts := _texts(XTianqiPlagueAlien.take_logs(lg))
	_check("focus_burst", int(f.layers) >= 12 and bool(f.burst) and texts.any(func(t): return t.contains("病灶爆发")), [f.layers, texts])
	var a0: XActor = lg.actors[0]
	_check("focus_burst_ticks", _near(a0.hp, hp[a0] - floorf(a0.mhp * 0.08 * 3)), [hp[a0], a0.hp])
	XTianqiPlagueAlien.refresh(lg)
	_check("focus_burst_once", _texts(XTianqiPlagueAlien.take_logs(lg)).is_empty())
	lg.end_battle(0)


func _chaos() -> void:
	var lg := _alien_logic("spread", 248)
	var e: XEnemy = lg.enemies[2]
	_check("spread_name", e.display_name().begins_with("蚀骨·") and e.display_name().contains("拉布"), e.display_name())
	var k := XTianqiPlagueAlien.kind_info("chaos")
	var keep: Array = k.chance
	k.chance = [1.0, 1.0, 1.0, 1.0]
	var a: XActor = lg.actors[0]
	var cid := int(XTianqiPlagueAlien.data().confusion_state)
	XTianqiPlagueAlien.hp_damage(lg, e, a, 100.0)
	_check("chaos_confuse", a.is_state_affected(cid) and int(a.state_turns.get(cid, 0)) == 1, a.state_turns.duplicate())
	XTianqiPlagueAlien.refresh(lg)
	_check("chaos_counts_debuff", int(XTianqiPlagueAlien.fight(lg).debuffs[a]) >= 1)
	k.chance = [0.0, 0.0, 0.0, 0.0]
	var b: XActor = lg.actors[1]
	XTianqiPlagueAlien.hp_damage(lg, e, b, 100.0)
	_check("chaos_miss", not b.is_state_affected(cid))
	k.chance = keep
	lg.end_battle(0)


func _taunt() -> void:
	var s := _state(20000000.0, "plague")
	var lg := XBattleLogic.new()
	lg.setup(246, s)
	var e: XEnemy = lg.enemies[0]
	var atk0 := e.param(2)
	var def0 := e.param(3)
	_check("apply_taunt", XTianqiPlagueAlien.apply(lg, s, "test", [{"enemy": e, "tier": "qinran", "kind": "taunt"}]))
	_check("taunt_tank", _near(e.param(2), atk0 * 0.67, 1e-2) and _near(e.param(3), def0 * 1.2, 1e-2), [atk0, e.param(2), def0, e.param(3)])
	var a: XActor = lg.actors[0]
	var single := XDB.rec("Skills", 1)
	_check("taunt_single_forced", lg.targets_for(a, single, lg.enemies[1]) == [e], lg.targets_for(a, single, lg.enemies[1]))
	var group := single.duplicate(true)
	group.scope = 2
	_check("taunt_group_free", XTianqiPlagueAlien.filter_targets(lg, a, group, [lg.enemies[1], lg.enemies[2]]) == [lg.enemies[1], lg.enemies[2]])
	var atk_a := a.param(2)
	_check("taunt_hit_full", _near(XTianqiPlagueAlien.hp_damage(lg, a, e, 100.0, group), 100.0))
	XTianqiPlagueAlien.refresh(lg)
	_check("defy_mark", int(XTianqiPlagueAlien.mark_of(lg, a).defy) == 2 and _near(a.param(2), roundf(atk_a * 0.97 * 0.8), 1e-3), [atk_a, a.param(2)])
	XTianqiPlagueAlien.unit(lg, e).idx = 2
	_check("taunt_huaxing_group_cut", _near(XTianqiPlagueAlien.hp_damage(lg, a, e, 100.0, group), 50.0)
		and _near(XTianqiPlagueAlien.hp_damage(lg, a, e, 100.0, single), 100.0))
	XTianqiPlagueAlien.end_turn(lg)
	XTianqiPlagueAlien.end_turn(lg)
	_check("defy_expires", int(XTianqiPlagueAlien.mark_of(lg, a).defy) == 0)
	e.hp = 0.0
	e.refresh_resources()
	lg._die(e)
	_check("taunt_dead_free", XTianqiPlagueAlien.filter_targets(lg, a, single, [lg.enemies[1]]) == [lg.enemies[1]])
	lg.end_battle(0)


func _contagion() -> void:
	var lg := _kind_logic(246, [[0, "qinran", "contagion"], [1, "qinran", "gland"]])
	var a: XActor = lg.actors[0]
	XTianqiPlagueAlien.hp_damage(lg, lg.enemies[1], a, 100.0)
	XTianqiPlagueAlien.take_logs(lg)
	var texts := _texts(XTianqiPlagueAlien.end_turn(lg))
	var others: Array = lg.actors.filter(func(x): return not is_same(x, a) and not XTianqiPlagueAlien.mark_of(lg, x).get("poison", []).is_empty())
	_check("contagion_spread", others.size() == 1 and texts.any(func(t): return t.contains("传染")), texts)
	_check("contagion_turns", others.size() == 1 and XTianqiPlagueAlien.mark_of(lg, others[0]).poison == [2], others.map(func(x): return XTianqiPlagueAlien.mark_of(lg, x)))
	lg.end_battle(0)


func _source() -> void:
	var lg := _kind_logic(246, [[0, "huaxing", "source"], [1, "qinran", "gland"]])
	var a: XActor = lg.actors[0]
	_check("source_extend", XTianqiPlagueAlien.extend_turns(lg) == 2)
	XTianqiPlagueAlien.hp_damage(lg, lg.enemies[1], a, 100.0)
	_check("source_poison_longer", XTianqiPlagueAlien.mark_of(lg, a).poison == [5], XTianqiPlagueAlien.mark_of(lg, a))
	# 敌人给我方挂的减益多 2 回合；我方给自己挂的不动
	var cid := int(XTianqiPlagueAlien.data().confusion_state)
	lg._state_add(a, cid)
	a.state_turns[cid] = 1
	XTianqiPlagueAlien.on_state_added(lg, lg.enemies[0], a, cid)
	_check("source_state_longer", int(a.state_turns[cid]) == 3, a.state_turns)
	XTianqiPlagueAlien.on_state_added(lg, lg.actors[1], a, cid)
	_check("source_own_untouched", int(a.state_turns[cid]) == 3)
	# 净化失败（化形 33%）：强制失败一次；成功时施放者染上
	var k := XTianqiPlagueAlien.kind_info("source")
	var keep: Array = k.purge_fail
	k.purge_fail = [1.0, 1.0, 1.0, 1.0]
	_check("purge_fail", XTianqiPlagueAlien.purge_blocked(lg, lg.actors[1], a, cid))
	k.purge_fail = [0.0, 0.0, 0.0, 0.0]
	var b: XActor = lg.actors[1]
	_check("purge_ok", not XTianqiPlagueAlien.purge_blocked(lg, b, a, cid) and b.is_state_affected(cid))
	k.purge_fail = keep
	lg.end_battle(0)


func _survival() -> void:
	var s := _state(20000000.0, "plague")
	_check("survival_prepare", XTianqiHorsemen.prepare("plague", s, "survival"))
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var kn: XEnemy = lg.enemies[0]
	var f := XTianqiHorsemen.fight(lg)
	var st := XTianqiHorsemen.survival_stats("plague", "jianxian")
	_check("survival_mode", XTianqiHorsemen.mode_of(lg) == "survival" and _near(kn.atk, float(st.atk)), [kn.atk, st.atk])
	_check("survival_plague_on", lg.actors.all(func(x): return bool(XTianqiHorsemen.mark_of(lg, x).get("plague", false))) and bool(f.taunt))
	for t in range(6):
		lg.run_turn(_guard_all(lg))
		if lg.is_lost():
			break
	_check("survival_no_phase", int(f.phase) == 1)
	_check("survival_win", XTianqiHorsemen.survived(lg) and lg.is_won() and not lg.is_lost(), [lg.turn, lg.alive(lg.actors).size()])
	lg.end_battle(0)


func _shadow() -> void:
	var s := _state(20000000.0, "plague")
	_check("shadow_prepare", XTianqiHorsemen.prepare("plague", s, "shadow"))
	var lg := XBattleLogic.new()
	lg.setup(30, s)
	var kn: XEnemy = lg.enemies[0]
	var kinds := {}
	for t in range(3):
		var logs := lg.run_turn(_guard_all(lg))
		for l in logs:
			if l.type == "action" and is_same(l.user, kn):
				kinds[str(l.skill.get("tianqi_horseman", ""))] = true
		if lg.is_lost():
			break
	_check("shadow_moves", kinds.keys() == ["defy_cry"], kinds.keys())
	_check("shadow_defiance", lg.actors.any(func(x): return int(XTianqiHorsemen.mark_of(lg, x).get("defiance", 0)) > 0 or x.is_state_affected(124)))
	lg.end_battle(0)


func _segment() -> void:
	# 按段异化入口：apply 收 {enemy, tier, kind}，不认识的种类跳过
	var s := _state(20000000.0, "plague")
	var lg := XBattleLogic.new()
	lg.setup(246, s)
	_check("segment_unknown_kind", not XTianqiPlagueAlien.apply(lg, s, "segment", [{"enemy": lg.enemies[0], "tier": "qinran", "kind": "nope"}]))
	_check("segment_apply", XTianqiPlagueAlien.apply(lg, s, "segment", [{"enemy": lg.enemies[0], "tier": "shigu", "kind": "gland"}])
		and lg.enemies[0].display_name().begins_with("蚀骨·"))
	lg.end_battle(0)


func _plain() -> void:
	# 原版档：不收、敌群不变、门不锁
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var p := XState.new_game_blank()
	for id in lineup:
		p.add_actor(int(id))
	p.set_variable(20, 6)
	XState.current = p
	_check("plain_no_prepare", not XTianqiPlagueAlien.prepare("omen", p) and not XTianqiHorsemen.prepare("plague", p, "survival"))
	var lg := XBattleLogic.new()
	lg.setup(247, p)
	_check("plain_battle", not XTianqiPlagueAlien.active(lg) and not lg.enemies[2].display_name().contains("·"))
	_check("plain_apply_refused", not XTianqiPlagueAlien.apply(lg, p, "segment", [{"enemy": lg.enemies[0], "tier": "qinran", "kind": "gland"}]))
	_check("plain_door", not XTianqiLine.door_blocked(p))
	lg.end_battle(0)
	# 饥荒线存档：瘟疫的异化不收
	var w := _state(0.0, "famine")
	_check("other_line", not XTianqiPlagueLine.allowed(w) and not XTianqiPlagueAlien.prepare("omen", w))
	# 瘟疫线开关关掉：选线里不能选、使徒不变
	var s2 := _state(0.0, "plague")
	_done(s2)
	XTianqiPlagueLine.ENABLED = false
	var host := FakeHost.new()
	await XTianqiLine.before_battle(host, s2, 69)
	_check("switch_off", not XTianqiPlagueLine.allowed(s2) and XTianqiPlagueAlien.pending() == "" and host.said.is_empty() and not XTianqi.line_playable("plague"))
	XTianqiPlagueLine.ENABLED = true
