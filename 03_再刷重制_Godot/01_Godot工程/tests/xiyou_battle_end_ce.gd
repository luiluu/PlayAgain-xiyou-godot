extends Node
## GD5 Boss 输分支：战斗结束后预约的公共事件 1308「战斗结束变量清除」与可输战斗的复活，对照原版参照 tests/fixtures/battle_end_ce_oracle.json
## （BattleManager.endBattle＋updateBattleEnd；CE1308 在 Game_Interpreter 里跑完）。
## - end.*：真实 XBattleScene 打完（胜利用 force_auto 打敌群 2；全灭先把出战者打倒）看预约槽与出战者 HP；逃跑走 reserve_battle_end_event(…, 1)。
## - ce1308.*：同样的初始状态在 MVInterpreter 里跑 CE1308，比变量、开关、物品、角色技能与状态。
## - BATTLE_END_COMMON_EVENT = 0（回到不预约）时胜利不预约。

const ORACLE := "res://tests/fixtures/battle_end_ce_oracle.json"
const EventCompare := preload("res://tests/xiyou_event_compare.gd")
const V := [1204, 1212, 1282, 1283, 1284, 1285, 1286, 1287, 1565, 1566, 1573, 1175, 965, 966, 372, 373, 980]
const SW := [2261, 2262, 2263, 2264, 2265, 2266, 2220, 1558]
const PARTY := [1, 8, 9, 10]

class QuickBattle extends XBattleScene:
	func _say(_text: String, _seconds: float) -> void:
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


func _battle(troop: int, can_lose: bool, dead: bool) -> Dictionary:
	var s := _fresh()
	if dead:
		for x in s.battle_members():
			x.add_state(1)
			x.hp = 0.0
	var scene := QuickBattle.new()
	scene.setup(troop, true, can_lose, XDB.map(4))
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
	_finish()


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
