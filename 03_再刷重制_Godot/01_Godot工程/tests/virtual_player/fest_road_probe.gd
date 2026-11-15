extends "res://tests/virtual_player/baseline_dps.gd"
## 冠军之路实测探针（冠军庆典，cc 11-15）：不是专项。用守层者基准队（见 baseline_dps.gd 头注释）在某层连打冠军之路四关，
## 血量带入、势如破竹照实，各队记每关回合数、输赢、剩几人；另跑一场同层守层者作对照。单独跑：
##   godot --headless --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/fest_road_probe.tscn -- [--floor=20] [--teams=6] [--max-turns=30] [--difficulty=jianxian] [--pause]

var floor_n := 20
var max_turns := 30
var use_pause := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--floor="):
			floor_n = int(a.substr(8))
		elif a.begins_with("--teams="):
			teams = int(a.substr(8))
		elif a.begins_with("--max-turns="):
			max_turns = int(a.substr(12))
		elif a.begins_with("--difficulty="):
			difficulty = a.substr(13)
		elif a == "--pause":
			use_pause = true
	_go.call_deferred()


func _to_end(s: XState, troop: int) -> Dictionary:
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	logic.auto = true
	var dealt := 0.0
	var hp0 := 0.0
	for e in logic.enemies:
		hp0 += float(e.mhp)
	var r := 0
	while r < max_turns and not logic.is_over():
		r += 1
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		while count < 120:
			var u := logic.next_subject()
			if u == null:
				break
			count += 1
			var cmd := logic.decide(u)
			var before := _enemy_hp(logic)
			var logs = logic.act(u, cmd[0], cmd[1])
			_drain(logic, logs if logs is Array else [])
			if u is XActor:
				dealt += maxf(0.0, before - _enemy_hp(logic))
			if logic.is_over():
				break
		if not logic.is_over():
			logic.end_turn()
	var won := logic.is_won()
	if logic.is_over():
		logic.end_battle(0 if won else 2)
	return {"won": won, "turns": r, "alive": s.battle_members().filter(func(a): return a.is_alive()).size(),
		"left": snappedf(_enemy_hp(logic) / maxf(hp0, 1.0), 0.01), "perTurn": dealt / maxf(1.0, float(r))}


func _go() -> void:
	XFest.TODAY_OVERRIDE = XFest.START
	var rows := []
	for team in _teams():
		var row := {"team": team}
		var s := _state(team, floor_n)
		XState.current = s
		row["guardian"] = _to_end(s, int(GUARDIAN.get(floor_n, 456)))
		s = _state(team, floor_n)
		XState.current = s
		XFestRoad.begin_run(s)
		var stages := []
		for st in XFestRoad.TEAMS.size():
			XFestRoad.battle_streak = int(XFestRoad.progress(s).streak)
			XFestRoad.in_road_battle = true
			var res := _to_end(s, XFestRoad.troop_id(0, st))
			XFestRoad.in_road_battle = false
			res["streak"] = XFestRoad.battle_streak
			stages.append(res)
			XFestRoad.settle(s, st, 0 if res.won else 2)
			if not res.won:
				break
			if use_pause and st == 1:
				XFestRoad.use_pause(s)
		row["road"] = stages
		rows.append(row)
		print("FEST_ROW " + JSON.stringify(row))
	var wins := rows.filter(func(r): return (r.road as Array).size() == 4 and bool(r.road[3].won)).size()
	var g := rows.filter(func(r): return bool(r.guardian.won)).size()
	print("FEST_SUMMARY floor=%d difficulty=%s teams=%d guardianWins=%d roadClears=%d" % [floor_n, difficulty, rows.size(), g, wins])
	get_tree().quit(0)
