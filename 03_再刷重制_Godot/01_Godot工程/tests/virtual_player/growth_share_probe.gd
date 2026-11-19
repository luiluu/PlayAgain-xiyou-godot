extends Node
## T260 无限成长⑤：三人「一份」实量场数探针（cc，Sonnet）。不是专项（不在 tests/ 顶层，检查.sh 不跑）。
## 单独跑：godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/growth_share_probe.tscn -- \
##   [--floors=20-33] [--per-floor=12] [--seed=1] [--out=<json>] [--team=167,108,179,<第4人>] [--gear]
##
## 做什么：队伍 渡鸦 167、奈叶 108、流萤 179＋一名第 4 人，等级＝该层等级上限、本人法宝；每层按地图遇敌表（权重）抽 per-floor 场敌群，另加该层守层者那场，
## 真打（自动战斗，我方每回合回满血，打到敌人死光或 40 回合）。每场量：
##   渡鸦灵魂＝XRaven.soul 增量（走游戏自己的得魂钩子）；奈叶适应＝flags.codexNanohaAdapt 增量（自己打倒 1、队友打倒 0.5，走游戏自己的钩子）；
##   流萤胜场＝赢了记 1（T257 接线前 gain_rewards 要戴专武才记，这里直接按「出战打赢就记」统计，Q5-A）。
## 不碰 T257 的计数接线，不读真实存档。

const CT := preload("res://tests/virtual_player/c_tier.gd")
const BD := preload("res://tests/virtual_player/baseline_dps.gd")
const NANOHA := 108
const RAVEN := 167
const LIUYING := 179

var floors: Array = range(20, 34)
var per_floor := 12
var seed_v := 1
var out_path := ""
var team: Array = [167, 108, 1, 3]
var use_gear := false
var max_turns := 40
var debug := false
var only_map := 0   # --map=N：遇敌表只取这张地图（如 185 特殊秘境·肝帝之地），层号只当标签
var static_only := false   # --static：不打，只按敌群数据算（赢了每个敌人都死：灵魂＝各敌 XRaven.soul_gain 之和）
var hp_cap := 1500000.0
var difficulty := "lianyu"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--floors="):
			var p := a.substr(9).split("-")
			floors = range(int(p[0]), int(p[p.size() - 1]) + 1)
		elif a.begins_with("--per-floor="):
			per_floor = int(a.substr(12))
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--team="):
			team = Array(a.substr(7).split(",")).map(func(x): return int(x))
		elif a.begins_with("--difficulty="):
			difficulty = a.substr(13)
		elif a.begins_with("--hp-cap="):
			hp_cap = float(a.substr(9))
		elif a.begins_with("--map="):
			only_map = int(a.substr(6))
		elif a == "--static":
			static_only = true
		elif a == "--debug":
			debug = true
		elif a == "--gear":
			use_gear = true
	_run.call_deferred()


## 层 → [[敌群号, 权重]]：所有地图名里层号＝该层、不是深渊的遇敌表
static func field_troops() -> Dictionary:
	var out := {}
	for info in XDB.table("MapInfos"):
		if not info is Dictionary or info.is_empty():
			continue
		var id := int(info.get("id", 0))
		var name := str(info.get("name", ""))
		if id <= 0 or not RegEx.create_from_string("^\\d+层").search(name):
			continue
		var f := XDungeon.map_floor(id)
		if f <= 0:
			continue
		var m := XDB.map(id)
		for en in m.get("encounterList", []):
			var t := int(en.get("troopId", 0))
			if t > 0:
				if not out.has(f):
					out[f] = []
				out[f].append([t, maxi(1, int(en.get("weight", 1)))])
	return out


## 同 c_tier.build_state（装备空、本人法宝、不刻烙印、天平酒），但档位用 difficulty（炼狱：上场最多 2 个超强者），三人才进得了队
func _state(f: int) -> XState:
	var level := BD.level_cap(f)
	var s := XState.new_game(XTianqi.legacy_of(difficulty), int(team[0]), team.slice(1))
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": difficulty, "lineup": team.duplicate()}
	s.random_master = XRandomStream.hex64(seed_v + int(team[0]) + f)
	s.orb_seed = seed_v * 1000 + int(team[0]) + f
	seed(seed_v * 1000 + int(team[0]) + f)
	s.set_variable(20, f)
	s.actor_max_level = level
	XState.current = s
	for id in team:
		if not s.party.has(int(id)):
			s.add_actor(int(id))
	for i in team.size():
		s.set_battle_slot(i, int(team[i]))
	for id in team:
		var a := s.actor(int(id))
		a.change_level_mv(level)
		var fid := CT.K._own_fabao(int(id))
		if fid == 0:
			var mw := CT.K.main_weights(a)
			fid = CT.K.GENERAL_ATK if float(mw.get("atk", 0.0)) >= float(mw.get("mat", 0.0)) else CT.K.GENERAL_MAT
		var fb := XGear.template("armor", fid)
		fb.level = float(mini(BD.fabao_cap(f), int(XMagicWeapon.max_level(fb))))
		var slot := a.equip_slots().find(int(fb.etypeId))
		if slot >= 0:
			a.equips[slot] = fb
		a.param_mark_dirty()
		a.refresh_passive()
		a.recover_all()
	XTianqiMoney.money(s)["scale"] = {"floor": f, "goods": ["wine"], "buys": 1}
	XState.current = s
	var n := s.actor(NANOHA)
	if debug:
		print("SLOTS ", s.battle_slots, " party=", s.party)
	if n != null:
		for sk in [XNanoha.SHARED, XNanoha.ADAPT]:
			if not n.skill_ids.has(sk):
				n.learn_skill(sk)
		n.refresh_passive()
	return s


func _adapt(s: XState) -> float:
	return float(s.flags.get(XNanoha.ADAPT_FLAG, {}).get(str(NANOHA), 0.0))


func _fight(f: int, troop: int, s: XState) -> Dictionary:
	XState.current = s
	var soul0 := XRaven.soul(s.actor(RAVEN))
	var ad0 := _adapt(s)
	var logic := XBattleLogic.new()
	logic.setup(troop, s, null)
	logic.auto = true
	var foes := logic.enemies.size()
	if hp_cap > 0.0:   # 空装备的队打不动 3000 万血的敌人；当前血量压到 hp_cap（回合数约 6～12），谁打倒谁的分配照自动战斗走
		for e in logic.enemies:
			e.hp = minf(float(e.hp), hp_cap)   # 只压当前血量，最大生命不动
	var turns := 0
	while turns < max_turns and not logic.is_over():
		for a in logic.actors:
			a.recover_all()
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		while count < 80:
			var u := logic.next_subject()
			if u == null:
				break
			count += 1
			var cmd := logic.decide(u)
			logic.act(u, cmd[0], cmd[1])
			if logic.is_over():
				break
		if not logic.is_over():
			logic.end_turn()
		turns += 1
	var won := logic.is_won()
	if debug:
		print("DBG members=", logic.actors.map(func(a): return [a.actor_id, a.hp, a.mhp]), " enemies=", logic.enemies.map(func(e): return [e.hp, e.mhp]), " lost=", logic.is_lost(), " aborted=", logic.aborted)
	var res := {"floor": f, "troop": troop, "foes": foes, "turns": turns, "won": won,
		"soul": XRaven.soul(s.actor(RAVEN)) - soul0, "adapt": _adapt(s) - ad0}
	logic.end_battle(0 if won else 2)
	return res


func _static(f: int, troop: int, s: XState) -> Dictionary:
	XState.current = s
	var logic := XBattleLogic.new()
	logic.setup(troop, s, null)
	var soul := 0
	var exps := []
	for e in logic.enemies:
		soul += XRaven.soul_gain(e)
		exps.append(XRaven.enemy_exp(e))
	logic.end_battle(2)
	return {"floor": f, "troop": troop, "foes": logic.enemies.size(), "soul": soul, "exps": exps, "won": true}


func _run() -> void:
	XMessageBox.auto = true
	XTianqiBase.PHASE4 = true
	XTianqiSkills.MASTERY = true
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	XTianqiGear.clear_effective_cache()
	XEnemy.force_roll = 100.0
	if team.size() < 4:
		team = [167, 108, 1, 3]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var ft := field_troops()
	var rows := []
	for f in floors:
		var pool: Array = ft.get(f, [])
		if only_map > 0:
			pool = []
			for en in XDB.map(only_map).get("encounterList", []):
				pool.append([int(en.get("troopId", 0)), maxi(1, int(en.get("weight", 1)))])
		var picks := []
		var total := 0
		for p in pool:
			total += int(p[1])
		if total > 0:
			for i in per_floor:
				var r := rng.randi_range(0, total - 1)
				for p in pool:
					r -= int(p[1])
					if r < 0:
						picks.append(["field", int(p[0])])
						break
		if BD.GUARDIAN.has(f) and only_map == 0:
			picks.append(["guard", int(BD.GUARDIAN[f])])
		var shared: XState = _state(f) if static_only and not picks.is_empty() else null
		for pk in picks:
			var s: XState = shared if shared != null else _state(f)
			var row := _static(f, int(pk[1]), s) if static_only else _fight(f, int(pk[1]), s)
			row["kind"] = pk[0]
			rows.append(row)
			print("GS_ROW ", JSON.stringify(row))
	XEnemy.force_roll = -1.0
	var rep := {"team": team, "floors": floors, "per_floor": per_floor, "seed": seed_v, "rows": rows}
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify(rep, "\t"))
	print("GS_DONE rows=", rows.size())
	get_tree().quit(0)


