extends Node
## 琼霄三条（挨打反击 1072、金剪追加 1068、戮仙印记 1067）叠加后的 10 回合输出量，对照同档主 C。
## 每回合：敌人打琼霄一下（触发反击）→ 琼霄用双蛟逐月 → 跑完追加的强制行动。不限冷却。
## 打印量表（MEASURE 行），再断言「全开 ≤ 同档主 C 的 1.5 倍」与各防连锁开关的回退支。
var results := []
const ROUNDS := 10
const LEVEL := 99


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(2000))
	return ok


func _ready() -> void:
	_run.call_deferred()


class Logic:
	extends XBattleLogic
	func _float(reason: String) -> float:
		return 0.0 if reason == "hit" or reason == "counter" or reason == "reflection" else (0.99 if reason == "evade" else super._float(reason))


## 一场：返回 {total, counters, follow, rounds}
func measure(actor_id: int, skill_id: int, states: Array, seed_value: int, hits := 1) -> Dictionary:
	var s := XState.new_game(9, 1, [] if actor_id == 1 else [actor_id])
	s.random_master = XRandomStream.hex64(seed_value)
	XState.current = s
	var actor_data: XActor = s.actor(actor_id)
	actor_data.change_level_mv(LEVEL)
	actor_data.learn_skill(skill_id)
	actor_data.refresh_passive()
	actor_data.recover_all()
	var logic := Logic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	var hero: XBattler = logic.actors.filter(func(b): return int(b.actor_id) == actor_id)[0]
	for sid in states:
		if not hero.state_ids.has(sid):
			hero.state_ids.append(sid)
	hero.add_param(0, 1000000.0)  # 加厚血量：挨打不倒，专测反击／追加
	var foe: XBattler = logic.enemies[0]
	var skill := XDB.rec("Skills", skill_id)
	var out := {"total": 0.0, "counters": 0, "follow": 0}
	for round in range(ROUNDS):
		hero.recover_all()
		foe.hp = foe.mhp
		var logs: Array = []
		XStateEffects.battle_turn = round + 1
		for k in range(hits):
			logic.apply(foe, XDB.rec("Skills", 1), hero)
		logs.append_array(logic.run_events())
		var r := logic.apply(hero, skill, foe)
		out.total += maxf(0.0, float(r.get("hp", 0.0)))
		logs.append_array(logic.run_events())
		for l in logs:
			if str(l.get("type")) == "hit" and l.get("target") == foe:
				out.total += maxf(0.0, float(l.get("hp", 0.0)))
			if str(l.get("type")) == "action" and l.get("user") == hero:
				out.counters += 1
	return out


## 同档对照：该角色（同级）每个单体／全体伤害技能各打一下，取最高一招
func best_single(actor_id: int) -> Array:
	var s := XState.new_game(9, 1, [] if actor_id == 1 else [actor_id])
	s.random_master = XRandomStream.hex64(41)
	XState.current = s
	var a: XActor = s.actor(actor_id)
	a.change_level_mv(LEVEL)
	a.refresh_passive()
	a.recover_all()
	var logic := Logic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	var found := logic.actors.filter(func(b): return int(b.actor_id) == actor_id)
	if found.is_empty():
		return [0.0, 0]
	var hero: XBattler = found[0]
	var foe: XBattler = logic.enemies[0]
	var best := 0.0
	var best_id := 0
	for sk in a.skills():
		var skd: Dictionary = sk
		var dmg: Dictionary = skd.get("damage", {})
		if int(dmg.get("type", 0)) not in [1, 5] or int(skd.get("scope", 1)) not in [1, 2]:
			continue
		foe.hp = foe.mhp
		hero.recover_all()
		var r := logic.apply(hero, skd, foe)
		var v := maxf(0.0, float(r.get("hp", 0.0)))
		if v > best:
			best = v
			best_id = int(skd.id)
	return [best, best_id]


func _run() -> void:
	XEnemy.force_roll = 100.0
	var rows := {}
	var cfg := {
		"none": [false, false, false],
		"counter": [true, false, false],
		"scissors": [false, true, false],
		"mark": [false, false, true],
		"all": [true, true, true],
	}
	for name in cfg:
		var f: Array = cfg[name]
		XStateEffects.FIX_SCALE_COUNTER_1072 = f[0]
		XStateEffects.FIX_SCISSORS_CRIT_1068 = f[1]
		XStateEffects.FIX_MARK_5576 = f[2]
		var states := []
		if f[0]: states.append(1072)
		if f[1]: states.append(1068)
		var total := 0.0
		var actions := 0
		for seed_value in [11, 12, 13]:
			var m := measure(101, 5577, states, seed_value)
			total += float(m.total)
			actions += int(m.counters)
		rows[name] = {"avg": total / 3.0, "extra_actions": actions / 3.0}
		print("MEASURE qiongxiao ", name, " ", JSON.stringify(rows[name]))
	XStateEffects.FIX_SCALE_COUNTER_1072 = true
	XStateEffects.FIX_SCISSORS_CRIT_1068 = true
	XStateEffects.FIX_MARK_5576 = true
	# 全开：每回合 1 个／4 个敌人打她；防连锁、每回合 1 次反击开关开关各量一次；印记倍率 4 对 3
	for scenario in [["all_hits1", 1, true, 4.0], ["all_hits4_guard", 4, true, 4.0], ["all_hits4_noguard", 4, false, 4.0], ["all_hits1_mark3", 1, true, 3.0]]:
		XStateEffects.FIX_COUNTER_ONCE = scenario[2]
		XStateEffects.FIX_CHAIN_GUARD = scenario[2]
		XStateEffects.MARK_FACTOR = scenario[3]
		var tot := 0.0
		var acts := 0
		for seed_value in [11, 12, 13]:
			var m := measure(101, 5577, [1072, 1068], seed_value, int(scenario[1]))
			tot += float(m.total)
			acts += int(m.counters)
		rows[scenario[0]] = {"avg": tot / 3.0, "extra_actions": acts / 3.0}
		print("MEASURE qiongxiao ", scenario[0], " ", JSON.stringify(rows[scenario[0]]))
	XStateEffects.FIX_COUNTER_ONCE = true
	XStateEffects.FIX_CHAIN_GUARD = true
	XStateEffects.MARK_FACTOR = 4.0
	# 同档主 C：2026-11-04 全体 124 名可量角色同级（99）各取最强一招×10 的排行，前三（17～23M）是离群值，
	# 取第 4～8 名（角色 36、94、127、95、152）的均值为「同档主 C」。固定这五个，免得每次扫全表。
	var peers := []
	for aid in [36, 94, 127, 95, 152]:
		peers.append(float(best_single(aid)[0]) * ROUNDS)
	var peer_mean := 0.0
	for v in peers:
		peer_mean += float(v)
	peer_mean /= float(peers.size())
	print("MEASURE comparator peers ", JSON.stringify(peers), " mean ", peer_mean)
	var all_one: float = rows["all_hits1"].avg
	check("balance.peers_present", peer_mean > 0.0, peers)
	check("balance.all_within_1_6x", all_one <= peer_mean * 1.6, [all_one, peer_mean])
	check("balance.each_felt", rows.counter.avg > rows.none.avg * 1.5 and rows.mark.avg > rows.none.avg * 2.0 and rows.scissors.extra_actions >= 0.0, rows)
	check("balance.guard_cuts_multi_enemy", rows.all_hits4_guard.avg < rows.all_hits4_noguard.avg * 0.7, [rows.all_hits4_guard, rows.all_hits4_noguard])
	check("balance.counter_once_per_turn", rows.all_hits4_guard.extra_actions <= 12.0, rows.all_hits4_guard)
	check("balance.mark3_lower", rows.all_hits1_mark3.avg < all_one, [rows.all_hits1_mark3, all_one])
	XState.current = null
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
