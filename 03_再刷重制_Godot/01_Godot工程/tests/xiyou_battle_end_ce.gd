extends Node
## GD5 Boss 输分支：战斗结束后预约的公共事件 1308「战斗结束变量清除」与可输战斗的复活，对照原版参照 tests/fixtures/battle_end_ce_oracle.json
## （BattleManager.endBattle＋updateBattleEnd；CE1308 在 Game_Interpreter 里跑完）。
## - end.*：真实 XBattleScene 打完（胜利用 force_auto 打敌群 2；全灭先把出战者打倒）看预约槽与出战者 HP；逃跑走 reserve_battle_end_event(…, 1)。
## - ce1308.*：同样的初始状态在 MVInterpreter 里跑 CE1308，比变量、开关、物品、角色技能与状态。
## - BATTLE_END_COMMON_EVENT = 0（回到不预约）时胜利不预约。
## - 审查第 75 期：双方同时倒下先判输（checkBattleEnd 先 isAllDead 我方）；事件 353 置的 game_over 在可输战斗里不复活；
##   事件 340 置的 aborted 结果 1、预约 1308，先于全灭；340 所在页同一帧跑完时原版 checkBattleEnd 接着判全灭（结果改写成 2，
##   仍预约 1308、不复活）、全歼（结果 0）；340 之后本页照常往下跑到第一条等待（GB13）。

const ORACLE := "res://tests/fixtures/battle_end_ce_oracle.json"
const EventCompare := preload("res://tests/xiyou_event_compare.gd")
const V := [1204, 1212, 1282, 1283, 1284, 1285, 1286, 1287, 1565, 1566, 1573, 1175, 965, 966, 372, 373, 980]
const SW := [2261, 2262, 2263, 2264, 2265, 2266, 2220, 1558]
const PARTY := [1, 8, 9, 10]

class QuickBattle extends XBattleScene:
	func _defeat_message() -> void:
		await get_tree().process_frame

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)
	return ok


func _fresh() -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in PARTY:
		s.add_actor(id)
	s.map_id = 4
	XState.current = s
	return s


func _battle(troop: int, can_lose: bool, dead: bool, prep := Callable()) -> Dictionary:
	var s := _fresh()
	if dead:
		for x in s.battle_members():
			x.add_state(1)
			x.hp = 0.0
	var scene := QuickBattle.new()
	scene.setup(troop, true, can_lose, XDB.map(4))
	if prep.is_valid():
		prep.call(scene.logic)
	get_tree().root.add_child(scene)
	var result: int = await scene.finished
	var out := {"result": result, "reserved": s.peek_common_event(), "hp": s.battle_members().map(func(x): return x.hp),
		"dead": s.battle_members().map(func(x): return x.is_dead())}
	scene.bgm.stop()
	scene.se.stop()
	scene.queue_free()
	await get_tree().create_timer(0.3, true, false, true).timeout
	return out


func _ce(o: Dictionary, host) -> Dictionary:
	var s := _fresh()
	for v in V:
		s.set_variable(v, 7)
	for w in SW:
		s.set_switch(w, w >= 2261 and w <= 2266)
	for id in o.get("party", []):
		if not s.party.has(int(id)):
			s.party.append(int(id))
	for k in o.get("vars", {}):
		s.set_variable(int(k), float(o.vars[k]))
	for k in o.get("sw", {}):
		s.set_switch(int(k), bool(o.sw[k]))
	for pair in o.get("learn", []):
		s.actor(int(pair[0])).learn_skill(int(pair[1]))
	for pair in o.get("items", []):
		s.gain_item(int(pair[0]), int(pair[1]))
	var list: Array = XDB.rec("CommonEvents", 1308).get("list", []).duplicate(true)
	MVInterpreter.max_steps = 20000
	MVInterpreter.fixed_random = 0.5
	MVInterpreter.steps = 0
	MVInterpreter.aborted = false
	var interp := MVInterpreter.new(host, 4, 0, list)
	host.trace = []
	host.start_frames(s)
	await interp.run()
	var ids: Array = (o.get("party", []) as Array).map(func(x): return int(x)) + [1]
	var actors := {}
	for a in ids:
		var x := s.actor(a)
		var st: Array = x.state_ids.duplicate()
		st.sort()
		actors[str(a)] = {"skills": [6136, 8091, 5519].filter(func(k): return x.skill_ids.has(k)), "states": st}
	var vars := {}
	for v in V:
		vars[str(v)] = int(s.variable(v))
	var sws := {}
	for w in SW:
		sws[str(w)] = s.switch(w)
	return {"finished": not MVInterpreter.aborted and interp.skipped.is_empty(), "vars": vars, "switches": sws,
		"items": {"1914": s.item_count(1914), "1982": s.item_count(1982)}, "actors": actors}


func _norm(v):
	return JSON.parse_string(JSON.stringify(v))


func _run() -> void:
	GameApp.fast_headless_frames()
	XSave.dir_override = "user://test_xiyou_battle_end_ce"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	var data = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	if not check("oracle_loaded", data is Dictionary and data.has("cases")):
		_finish()
		return
	var host = EventCompare.EventHost.new()
	add_child(host)
	var seen := 0
	for c in data.cases:
		if not check("oracle_ok_" + c.id, (c.errors as Array).is_empty(), c.errors):
			continue
		var want: Dictionary = c.observed
		var o: Dictionary = c.setup
		if c.id.begins_with("ce1308."):
			seen += 1
			var got := await _ce(o, host)
			check(c.id, _norm(got) == _norm(want), {"got": got, "want": want})
		elif c.id == "end.escape":
			seen += 1
			var s := _fresh()
			XBattleScene.reserve_battle_end_event(s, 1)
			check(c.id, s.peek_common_event() == int(want.reserved), s.peek_common_event())
		elif c.id.begins_with("end."):
			seen += 1
			var dead := bool(o.dead)
			var got := await _battle(770 if dead else 2, bool(o.canLose), dead)
			check(c.id + "_result", got.result == int(o.result), got.result)
			check(c.id + "_reserved", got.reserved == int(want.reserved), got)
			if dead:
				check(c.id + "_hp", _norm(got.hp) == _norm(want.hp) and _norm(got.dead) == _norm(want.dead), [got, want])
	check("all_cases_seen", seen == data.cases.size(), [seen, data.cases.size()])
	# 回退：设 0 不预约（重制原来的样子）
	XBattleScene.BATTLE_END_COMMON_EVENT = 0
	var off := await _battle(2, false, false)
	check("rollback_no_reserve", off.result == 0 and off.reserved == 0, off)
	XBattleScene.BATTLE_END_COMMON_EVENT = 1308
	await _end_order_checks()
	_finish()


## 审查第 75 期 P2-1／P3-1（没有参照用例：原版的次序直接读 rpg_managers.js checkBattleEnd／updateBattleEnd、command340／353）
func _end_order_checks() -> void:
	var kill_enemies := func(lg: XBattleLogic) -> void:
		for e in lg.enemies:
			e.add_state(1)
			e.hp = 0.0
	# 我方全灭、敌群也全灭：算输（结果 2、不预约 1308、可输时复活 1 血）
	var both := await _battle(2, true, true, kill_enemies)
	check("both_dead.lose", both.result == 2 and both.reserved == 0, both)
	check("both_dead.revive", both.hp.all(func(h): return h == 1.0), both)
	# 353 游戏结束（logic.game_over）在可输战斗里：结果 2，不复活（原版 goto Scene_Gameover，不走 updateBattleEnd）
	var go := await _battle(2, true, false, func(lg: XBattleLogic) -> void:
		lg.game_over = true
		lg.actors[0].add_state(1)
		lg.actors[0].hp = 0.0)
	check("game_over.can_lose_no_revive", go.result == 2 and go.reserved == 0 and go.hp[0] == 0.0 and go.dead[0], go)
	# 340 中止战斗（logic.aborted）停在等待上（abort_yield，下一帧起只走 checkAbort）：结果 1、预约 1308；全灭了也先判中止
	var ab := await _battle(2, false, true, func(lg: XBattleLogic) -> void:
		lg.aborted = true
		lg.abort_yield = true)
	check("abort.result", ab.result == 1 and ab.reserved == 1308, ab)
	# 340 所在页同一帧跑完、我方全灭（可输）：checkAbort 之后接着 processDefeat，结果改写成 2；_escaped 已置，预约 1308、不复活
	var ad := await _battle(2, true, true, func(lg: XBattleLogic) -> void: lg.aborted = true)
	check("abort.same_frame_dead", ad.result == 2 and ad.reserved == 1308 and ad.hp.all(func(h): return h == 0.0), ad)
	# 同上、敌群全灭：processVictory，结果 0
	var aw := await _battle(2, false, false, func(lg: XBattleLogic) -> void:
		kill_enemies.call(lg)
		lg.aborted = true)
	check("abort.same_frame_won", aw.result == 0 and aw.reserved == 1308, aw)
	# 只中止（谁也没全灭）：结果 1
	var a1 := await _battle(2, false, false, func(lg: XBattleLogic) -> void: lg.aborted = true)
	check("abort.plain", a1.result == 1 and a1.reserved == 1308, a1)
	# 敌群事件里的 340：command340 只 abort()，本页后面的 121 同一帧照常执行；事件检查与无界面回合随即停下
	var s := _fresh()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var list := [{"code": 340, "indent": 0, "parameters": []}, {"code": 121, "indent": 0, "parameters": [2261, 2261, 0]},
		{"code": 0, "indent": 0, "parameters": []}]
	s.set_switch(2261, false)
	var r := XBattleEventRunner.new(lg, list, null)
	r.advance()
	check("abort.runner", lg.aborted and lg.is_over() and s.switch(2261) and lg.abort_checks_end(), [lg.aborted, s.switch(2261), lg.abort_yield])
	# 340 之后遇到 230 等待：解释器停在等待上，之后不再更新，后面的 121 不执行；不再判全灭／全歼
	var lw := XBattleLogic.new()
	lw.setup(2, s)
	s.set_switch(2261, false)
	var wait_list := [{"code": 340, "indent": 0, "parameters": []}, {"code": 230, "indent": 0, "parameters": [10]},
		{"code": 121, "indent": 0, "parameters": [2261, 2261, 0]}, {"code": 0, "indent": 0, "parameters": []}]
	XBattleEventRunner.new(lw, wait_list, null).advance()
	check("abort.wait_stops", lw.aborted and not s.switch(2261) and lw.abort_yield and not lw.abort_checks_end(), [s.switch(2261), lw.abort_yield])
	# 340 之后的文字照常显示，确认后本页后面的 121 不执行
	var lm := XBattleLogic.new()
	lm.setup(2, s)
	s.set_switch(2261, false)
	var msg_list := [{"code": 340, "indent": 0, "parameters": []}, {"code": 101, "indent": 0, "parameters": ["", 0, 0, 2]},
		{"code": 401, "indent": 0, "parameters": ["中止"]}, {"code": 121, "indent": 0, "parameters": [2261, 2261, 0]},
		{"code": 0, "indent": 0, "parameters": []}]
	lm._check = {"first": null, "turn_end": false, "moment": {}, "guard": 0}
	lm._runner = XBattleEventRunner.new(lm, msg_list, null)
	lm._drive_events()
	var waited := lm.event_waiting()
	check("abort.message_shown", not waited.is_empty() and lm.abort_yield, waited)
	if not waited.is_empty():
		lm.resume_event(int(waited.token))
	check("abort.message_then_stop", not s.switch(2261) and not lm.is_event_waiting(), s.switch(2261))
	var ctl := XBattleEventRunner.new(lg, list.slice(1), null)
	s.set_switch(2261, false)
	ctl.advance()
	check("abort.runner_control", s.switch(2261), "没有 340 时 121 应该执行")
	s.set_switch(2261, false)
	var acts: Array = lg.run_turn({}).filter(func(l): return l.type == "action")
	check("abort.run_turn_stops", acts.is_empty(), acts.size())


func _finish() -> void:
	XBattleScene.force_auto = false
	XBattleScene.BATTLE_END_COMMON_EVENT = 1308
	MVInterpreter.max_steps = 0
	MVInterpreter.fixed_random = -1.0
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
