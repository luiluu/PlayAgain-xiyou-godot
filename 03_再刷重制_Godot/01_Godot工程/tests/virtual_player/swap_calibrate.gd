extends Node
## 【cc·T183】发作真换人量数（设计稿《天启篇_发作真换人 v0.2》第八节六步，T086-d）：定锁定回合（1～3，整数）。
## 不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑：
##   godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/swap_calibrate.tscn -- \
##     [--games=300] [--lines=death,war,famine,plague] [--teams=strong,mid,weak] [--seed=20261118] [--max-turns=40] [--trigger-turn=3] \
##     [--conds=base,blackout,lock1,lock2,lock3] [--shard=i/n] [--out=<json>]
##
## 做法（照 zhengdao_scenarios 的阵容和骑士本体战）：每局种子固定，同一种子下各条件用同一支队、同一随机主种；自动战斗（decide，auto 开着，自动换回开着）。
## 条件：base 不出第六种；blackout 第 trigger-turn 回合点名头一个上场的人「换人」、REAL_SWAP 关＝按断片；lockN 同一人同一回合点名、REAL_SWAP 开、锁定 N 回合。
## 触发用 XTianqiBrand.TEST_FIT（不掷）；烙印 0，不会自己疯。
## 每局记：胜负、回合数、倒下人数、第六种实际是什么（fit_log）、真换了没有（tianqi_swap 记录）、被换上来的人倒没倒、
## 逐回合断言（超强者不超上限；换人后写档的出战栏＝留底；打完出战栏＝开战前）。

const Z := preload("res://tests/virtual_player/zhengdao_scenarios.gd")
const S := XTier.SUPER
const G := XTier.STRONG
const W := XTier.WEAK

var games := 300
var lines: Array = ["death", "war", "famine", "plague"]
var team_keys: Array = ["strong", "mid", "weak"]
var conds: Array = ["base", "blackout", "lock1", "lock2", "lock3"]
var seed_base := 20261118
var max_turns := 40
var trigger_turn := 3
var shard_i := 0
var shard_n := 1
var out_path := ""
var z


## 队伍表：key 是难度档（决定超强者上限和候选池），slots 是 5 格 [档位, 沉淀]
static func teams() -> Dictionary:
	return {
		"strong": {"label": "最强队（证道 2超＋2强｜超，养满）", "key": "zhengdao", "slots": [[S, 1.0], [S, 1.0], [G, 1.0], [G, 1.0], [S, 1.0]]},
		"mid": {"label": "中位队（艰险 1超＋4弱，沉淀 50%）", "key": "jianxian", "slots": [[S, 0.5], [W, 0.5], [W, 0.5], [W, 0.5], [W, 0.5]]},
		"weak": {"label": "全弱者队（艰险 5弱，沉淀 90%）", "key": "jianxian", "slots": [[W, 0.9], [W, 0.9], [W, 0.9], [W, 0.9], [W, 0.9]]},
	}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--games="):
			games = maxi(1, int(a.substr(8)))
		elif a.begins_with("--lines="):
			lines = Array(a.substr(8).split(","))
		elif a.begins_with("--teams="):
			team_keys = Array(a.substr(8).split(","))
		elif a.begins_with("--conds="):
			conds = Array(a.substr(8).split(","))
		elif a.begins_with("--seed="):
			seed_base = int(a.substr(7))
		elif a.begins_with("--max-turns="):
			max_turns = int(a.substr(12))
		elif a.begins_with("--trigger-turn="):
			trigger_turn = int(a.substr(15))
		elif a.begins_with("--shard="):
			var p := a.substr(8).split("/")
			shard_i = int(p[0])
			shard_n = maxi(1, int(p[1]))
		elif a.begins_with("--out="):
			out_path = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	z = Z.new()
	var t0 := Time.get_ticks_msec()
	var rows := []
	var tm := teams()
	for tk in team_keys:
		for line in lines:
			var per_cond := {}
			for c in conds:
				per_cond[c] = []
			for g in games:
				if g % shard_n != shard_i:
					continue
				var seed := seed_base + g * 7919 + hash(tk + str(line)) % 1000
				for c in conds:
					per_cond[c].append(_game(tm[tk], str(line), seed, str(c)))
			for c in conds:
				rows.append({"team": tk, "line": line, "cond": c, "games": per_cond[c]})
			print("PROGRESS %s %s done %.0fs" % [tk, line, (Time.get_ticks_msec() - t0) / 1000.0])
	var rep := {"version": 1, "games": games, "seed": seed_base, "shard": [shard_i, shard_n], "max_turns": max_turns, "trigger_turn": trigger_turn,
		"lines": lines, "teams": team_keys, "conds": conds, "rows": rows, "seconds": (Time.get_ticks_msec() - t0) / 1000.0}
	if out_path != "":
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(rep))
		f.close()
	var bad := 0
	for r in rows:
		for gm in r.games:
			bad += int(gm.get("violations", 0)) + int(gm.get("save_bad", 0)) + int(gm.get("restore_bad", 0)) + (1 if gm.has("error") else 0)
	print("SWAP_CALIBRATE=" + JSON.stringify({"rows": rows.size(), "bad": bad, "seconds": rep.seconds}))
	get_tree().quit.call_deferred(0)


func _game(team: Dictionary, line: String, seed: int, cond: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lineup: Array = z._lineup({"slots": team.slots}, str(team.key), rng)
	if lineup.filter(func(x): return int(x[0]) > 0).size() < 5:
		return {"error": "阵容凑不齐"}
	var s: XState = z._state(lineup, str(team.key), seed, line)
	XState.current = s
	if not XTianqiHorsemen.prepare(line, s, "body"):
		return {"error": "骑士战没开"}
	var before: Array = s.battle_slots.map(func(v): return int(v))
	var helper_id := int(before[4])
	var front_id := int(before[0])
	var logic := XBattleLogic.new()
	logic.setup(int(XTianqiLine.data(line).shell_troop), s, XBattleRandom.create(str(s.random_master)))
	logic.auto = true
	var kn = XTianqiHorsemen.fight(logic).get("knight")
	if kn == null:
		return {"error": "没换成骑士"}
	var fc := XTianqiBrand.fight(logic)
	if fc.is_empty():
		return {"error": "烙印没认这一场"}
	fc["ripe"] = false  # 首通：生的
	XTianqiBrand.TEST_FIT = {}
	if cond == "base":
		XTianqiBrand.REAL_SWAP = false
	elif cond == "blackout":
		XTianqiBrand.REAL_SWAP = false
		XTianqiBrand.TEST_FIT = {front_id: [trigger_turn, "swap"]}
	else:
		XTianqiBrand.REAL_SWAP = true
		XTianqiBrand.fit_row("swap")["lock_rounds"] = int(cond.substr(4))
		XTianqiBrand.TEST_FIT = {front_id: [trigger_turn, "swap"]}
	var cap := XTianqi.super_cap(s)
	var violations := 0
	var save_bad := 0
	var swapped := 0
	var swap_back := 0
	var helper_dead := false
	var ever_dead := {}
	var turns := 0
	var kn_hp0 := float(kn.mhp)
	var swapped_turn := -1
	while turns < max_turns and not logic.is_over():
		logic.start_turn()
		logic.take_turn_start_logs()
		turns = int(logic.turn)
		var supers := logic.actors.filter(func(a): return a is XActor and XTianqiSkills.is_super(a.actor_id, true)).size()
		if cap >= 0 and supers > cap:
			violations += 1
		var guard := 0
		while guard < 200:
			var u := logic.next_subject()
			if u == null:
				break
			guard += 1
			var fit := logic.brand_forced(u)
			var cmd := fit if not fit.is_empty() else logic.decide(u)
			var alog = logic.act(u, cmd[0], cmd[1])
			for l in alog:
				if str(l.get("type", "")) == "tianqi_swap":
					if bool(l.get("auto", false)):
						swap_back += 1
					else:
						swapped += 1
						if swapped_turn < 0:
							swapped_turn = turns
			for a in logic.actors:
				if a is XActor and a.is_dead():
					ever_dead[int(a.actor_id)] = true
			if logic.is_over():
				break
		if swapped > 0:
			var d: Dictionary = {"battleSlots": s.battle_slots.duplicate()}
			XTianqiBrand.patch_save(logic, d)
			if Array(d.battleSlots).map(func(v): return int(v)) != before:
				save_bad += 1
		if not logic.is_over():
			logic.end_turn()
	var won := logic.is_won()
	var deaths := ever_dead.size()
	if ever_dead.has(helper_id):
		helper_dead = true
	var kn_hp_left := float(kn.hp) / maxf(1.0, kn_hp0)
	var fit_kinds: Array = XTianqiBrand.fight(logic).get("fit_log", []).map(func(r): return str(r.kind))
	logic.end_battle(0 if won else 2)
	var after: Array = s.battle_slots.map(func(v): return int(v))
	return {"won": won, "turns": turns, "deaths": deaths, "violations": violations, "save_bad": save_bad,
		"restore_bad": 0 if (swapped == 0 or after == before) else 1, "swapped": swapped, "swap_back": swap_back, "swapped_turn": swapped_turn,
		"helper_dead": helper_dead, "knight_left": snappedf(kn_hp_left, 0.001), "fits": fit_kinds}
