extends "res://tests/virtual_player/baseline_dps.gd"
## 冠军之路实测探针（冠军庆典，cc 11-15）：不是专项。用守层者基准队（见 baseline_dps.gd 头注释）在某层连打冠军之路四关，
## 血量带入、势如破竹照实，各队记每关回合数、输赢、剩几人；另跑一场同层守层者作对照。单独跑：
##   godot --headless --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/fest_road_probe.tscn -- [--floor=20] [--teams=6] [--max-turns=30] [--difficulty=jianxian] [--pause] [--tier=0] [--ring=-1] [--vs=0] [--guard-fixed]
## --tier：冠军之路的档（0 欢庆、1 天灾、2 洪荒）；--ring：再跑一遍前三人戴这一档冠军戒指的，对照回合数与每回合伤害（v0.3.1 2.2 实测）

var floor_n := 20
var max_turns := 30
var use_pause := false
var tier := 0
var ring := -1
var vs := 0   # --vs=<防具号>：「不戴」那一遍改戴这件同品质对照戒指（史诗 245 悲伤之戒、传说 1732 昂扬徽记、不朽 2969 盘龙）
var guard_fixed := false
var remake := false
var all_stages := false   # --all-stages：输了也回满接着量下一关（只为量四关各自的相对强度，不是玩家能做的）   # --remake：基准队建好后去掉天启篇标记，当重制版存档打（天启篇存档会重算守层者、缩我方伤害，冠军之路对不上）   # --guard-fixed：对照的守层者也固定吃本档难度倍率（和冠军之路敌人同一口径）


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
		elif a.begins_with("--tier="):
			tier = int(a.substr(7))
		elif a.begins_with("--ring="):
			ring = int(a.substr(7))
		elif a.begins_with("--vs="):
			vs = int(a.substr(5))
		elif a == "--all-stages":
			all_stages = true
		elif a == "--remake":
			remake = true
		elif a == "--guard-fixed":
			guard_fixed = true
	_go.call_deferred()


func _to_end(s: XState, troop: int) -> Dictionary:
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	logic.auto = true
	if guard_fixed and not XFestRoad.is_road_troop(troop):
		var rates := XEnemy.difficulty_rates(int(XFestRoad.TIERS[tier].difficulty))
		for e in logic.enemies:
			e._rates = rates
			e.set_meta("fest_road", true)
			e.recover_all()
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
		"left": snappedf(_enemy_hp(logic) / maxf(hp0, 1.0), 0.01), "perTurn": dealt / maxf(1.0, float(r)),
		"ttk": snappedf(hp0 / maxf(1.0, dealt / maxf(1.0, float(r))), 0.1)}


## 一个队伍状态；ring>=0 时给前三个人戴上这一档的冠军戒指（v0.3.1：一个存档三枚，队里最多三人戴）
func _st(team: Array, ring_tier: int) -> XState:
	var s := _state(team, floor_n)
	if remake:
		s.flags.erase("tianqi")
		for a in s.members():
			a.refresh_passive()
			a.recover_all()
	XState.current = s
	var ring_id := XFestRing.armor_id(ring_tier) if ring_tier >= 0 else vs
	if ring_id > 0:
		var n := 0
		for id in team:
			if n >= 3:
				break
			var a := s.actor(int(id))
			var slot := a.equip_slots().find(XFestRing.ETYPE)
			if slot >= 0:
				a.equips[slot] = XGear.create("armor", ring_id, s)
				a.refresh_passive()
				n += 1
	return s


func _road(team: Array, ring_tier: int) -> Array:
	var s := _st(team, ring_tier)
	XFestRoad.begin_run(s, tier)
	var stages := []
	for st in XFestRoad.TEAMS.size():
		XFestRoad.battle_streak = int(XFestRoad.progress(s, tier).streak)
		XFestRoad.in_road_battle = true
		var res := _to_end(s, XFestRoad.troop_id(tier, st))
		XFestRoad.in_road_battle = false
		res["streak"] = XFestRoad.battle_streak
		stages.append(res)
		XFestRoad.settle(s, st, 0 if res.won else 2, tier)
		if not res.won:
			if not all_stages:
				break
			for a in s.members():
				a.recover_all()
		if use_pause and st == 1:
			XFestRoad.use_pause(s, tier)
	return stages


static func _avg(xs: Array) -> float:
	return 0.0 if xs.is_empty() else xs.reduce(func(a, b): return a + b, 0.0) / xs.size()


func _go() -> void:
	XFest.TODAY_OVERRIDE = XFest.START
	XTianqiLedger.QUIET = true   # 基准队是天启篇存档（夹具只有这一种）；冠军之路、戒指的乘区在天启篇总账里是 pooled，探针里照算、不报
	var rows := []
	for team in _teams():
		var row := {"team": team}
		row["guardian"] = _to_end(_st(team, -1), int(GUARDIAN.get(floor_n, 456)))
		row["road"] = _road(team, -1)
		if ring >= 0:
			row["guardian_ring"] = _to_end(_st(team, ring), int(GUARDIAN.get(floor_n, 456)))
			row["road_ring"] = _road(team, ring)
		rows.append(row)
		print("FEST_ROW " + JSON.stringify(row))
	var clear := func(key: String) -> int:
		return rows.filter(func(r): return r.has(key) and (r[key] as Array).size() == 4 and bool(r[key][3].won)).size()
	var g := rows.filter(func(r): return bool(r.guardian.won)).size()
	print("FEST_SUMMARY tier=%d floor=%d difficulty=%s teams=%d guardianWins=%d roadClears=%d guardFixed=%s remake=%s" % [tier, floor_n, difficulty, rows.size(), g, clear.call("road"), guard_fixed, remake])
	# 估算打死要几回合（敌方总血 ÷ 我方每回合伤害），和队伍强弱无关的相对强度：守层者那场 vs 四关各关
	var med := func(xs: Array) -> float:
		if xs.is_empty():
			return 0.0
		var ys := xs.duplicate()
		ys.sort()
		return float(ys[ys.size() / 2])
	var ttk := [med.call(rows.map(func(r): return float(r.guardian.ttk)))]
	for st in XFestRoad.TEAMS.size():
		ttk.append(med.call(rows.filter(func(r): return (r.road as Array).size() > st).map(func(r): return float(r.road[st].ttk))))
	print("FEST_TTK guardian=%.1f stages=%s (中位数，回合)" % [ttk[0], str(ttk.slice(1))])
	if ring >= 0:
		# 戒指效果：同一队戴与不戴，回合数（打赢的场）与每回合伤害之比
		var gt0 := []
		var gt1 := []
		var gd := []
		var rt0 := []
		var rt1 := []
		var rd := []
		for r in rows:
			if bool(r.guardian.won) and bool(r.guardian_ring.won):
				gt0.append(float(r.guardian.turns))
				gt1.append(float(r.guardian_ring.turns))
			if float(r.guardian.perTurn) > 0.0:
				gd.append(float(r.guardian_ring.perTurn) / float(r.guardian.perTurn))
			var n := mini((r.road as Array).size(), (r.road_ring as Array).size())
			for i in n:
				if bool(r.road[i].won) and bool(r.road_ring[i].won):
					rt0.append(float(r.road[i].turns))
					rt1.append(float(r.road_ring[i].turns))
				if float(r.road[i].perTurn) > 0.0:
					rd.append(float(r.road_ring[i].perTurn) / float(r.road[i].perTurn))
		print("FEST_RING ring=%d guardianTurns=%.2f->%.2f (n=%d) guardianDmgRatio=%.3f roadTurns=%.2f->%.2f (n=%d) roadDmgRatio=%.3f roadClearsWithRing=%d" % [
			ring, _avg(gt0), _avg(gt1), gt0.size(), _avg(gd), _avg(rt0), _avg(rt1), rt0.size(), _avg(rd), clear.call("road_ring")])
	get_tree().quit(0)
