extends Node
## 守层者基准伤害（法宝与积分重构 v0.2 第五节，cc 11-13）：弱阵容基准队对每层守层者每回合打多少。
## 不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑：
##   godot --headless --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/baseline_dps.tscn -- [--out=<json>] [--floors=1-33] [--teams=8] [--turns=8] [--difficulty=jianxian]
##
## 基准队（每层重新建）：
## - 天启篇存档（难度默认艰险，五档敌人防御一样、只差血量与攻击，所以伤害量一次就够）；弱者 4 人上场，从本难度候选池的弱者里按种子抽 teams 队；
## - 等级＝这一层的等级上限（原版守层者打赢后 maxlevel equal 的那张表：1～4 层 10、5 层 15……30 层 75）；
## - 装备＝每个栏位从「这一层能穿上的（需求等级 ≤ 等级上限）、精良及以下品质、不是专属」里挑主属性最高的一件（--no-gear 只留开局自带，
##   --quality=N 放宽品质）＋一件法宝，等级＝这一层的法宝上限 min(99, 9＋3×层)：兑换大厅有本人专属法宝就穿专属的，
##   没有就穿通用的「破攻」（物攻 +20／级）或「尊魔」（魔攻 +20／级），看本人物攻、魔攻哪个高；
## - 不算真气、宝珠、种族、技能书这些养成（「最弱的正常玩家」口径）。
## 敌人：这一层守层者那场敌群（不是神话），血量用真值、每回合开始补满（状态不动），自动战斗打 turns 回合，量我方每次行动让敌方掉的血（敌人回血不抵扣，
## 回合末的持续伤害不算），按回合平均；
## 我方全灭或敌人被打死就按打了几回合算（打死那回合按掉的血算，偏低，表里记 won）。
## 输出：每层各队伍的每回合伤害、中位数、我方全灭的队伍数，以及按目标回合（寻常 6／艰险 8／九死 10／炼狱 12／证道 15）乘出来的血量。

const LEVEL_CAP := [[1, 10], [5, 15], [6, 20], [8, 25], [10, 30], [12, 33], [13, 35], [14, 38], [15, 40], [16, 43], [17, 45],
	[18, 48], [19, 50], [21, 55], [23, 60], [25, 65], [29, 75], [31, 80]]
## 每层守层者那场的敌群号（地图事件里「战斗后变量 20 加一」的那一场；5 层取群狼森林、7 层取科维努斯镇）
const GUARDIAN := {1: 4, 2: 5, 3: 8, 4: 22, 5: 28, 6: 39, 7: 52, 8: 53, 9: 67, 10: 69, 11: 109, 12: 110, 13: 111, 14: 118, 15: 138,
	16: 172, 17: 173, 18: 174, 19: 333, 20: 456, 21: 457, 22: 458, 23: 459, 24: 460, 25: 461, 26: 462, 27: 463, 28: 464, 29: 465,
	30: 466, 31: 467, 32: 468, 33: 469}
const TARGET_TURNS := {"xunchang": 6, "jianxian": 8, "jiusi": 10, "lianyu": 12, "zhengdao": 15}
const GENERAL_ATK := 3557   # 破攻
const GENERAL_MAT := 3556   # 尊魔

var floors: Array = range(1, 34)
var teams := 8
var turns := 8
var difficulty := "jianxian"
var out_path := ""
var seed := 20261113
var no_fabao := false
var gear := true
var debug := false
var atk_search := false
var atk_target := 10.0   # --atk-search：找让基准队中位数撑到这么多回合团灭的攻击倍率
var atk_scale := 1.0
var iters := 7
var max_quality := 3   # UnifiedQuality：0、1 普通，2 优秀，3 精良，4 史诗
var skipped_ids: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--teams="):
			teams = int(a.substr(8))
		elif a.begins_with("--turns="):
			turns = int(a.substr(8))
		elif a.begins_with("--difficulty="):
			difficulty = a.substr(13)
		elif a.begins_with("--iters="):
			iters = int(a.substr(8))
		elif a == "--atk-search":
			atk_search = true
		elif a.begins_with("--atk-target="):
			atk_target = float(a.substr(13))
		elif a == "--debug":
			debug = true
		elif a == "--no-gear":
			gear = false
		elif a.begins_with("--quality="):
			max_quality = int(a.substr(10))
		elif a == "--no-fabao":
			no_fabao = true
		elif a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a.begins_with("--floors="):
			var p := a.substr(9).split("-")
			floors = range(int(p[0]), int(p[p.size() - 1]) + 1)
	_run.call_deferred()


static func level_cap(f: int) -> int:
	var cap := 10
	for row in LEVEL_CAP:
		if f >= int(row[0]):
			cap = int(row[1])
	return cap


static func fabao_cap(f: int) -> int:
	return mini(99, 9 + 3 * maxi(1, f))


## 兑换大厅有卖、备注 <req_actors> 含本人的法宝
static var _own := {}
static func own_fabao(actor_id: int) -> int:
	if _own.is_empty():
		for r in XDB.table("Armors"):
			if r is Dictionary and r.get("meta", {}).has("Magic Weapon") and r.meta.has("req_actors"):
				for x in str(r.meta.req_actors).split(","):
					if str(x).strip_edges().is_valid_int():
						var aid := int(str(x).strip_edges())
						if not _own.has(aid):
							_own[aid] = int(r.id)
		_own[-1] = 0
	return int(_own.get(actor_id, 0))


func _teams() -> Array:
	var weak: Array = XTianqi.pool(difficulty)[XTier.WEAK].duplicate()
	weak.sort()
	# 上不了场的不要（如 156：建了队也不进出战成员）
	weak = weak.filter(func(id):
		var t := XState.new_game(XTianqi.legacy_of(difficulty), int(id), [])
		return t.battle_members().map(func(x): return int(x.actor_id)).has(int(id)))
	skipped_ids = XTianqi.pool(difficulty)[XTier.WEAK].filter(func(id): return not weak.has(id))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := []
	for t in teams:
		var pick := []
		var bag := weak.duplicate()
		for i in 4:
			pick.append(bag.pop_at(rng.randi_range(0, bag.size() - 1)))
		out.append(pick)
	return out


func _state(team: Array, f: int) -> XState:
	var s := XState.new_game(XTianqi.legacy_of(difficulty), int(team[0]), team.slice(1))
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": difficulty, "lineup": team.duplicate()}
	s.random_master = XRandomStream.hex64(seed + f)
	s.set_variable(20, f)
	s.actor_max_level = level_cap(f)
	for id in team:
		var a := s.actor(int(id))
		a.change_level_mv(level_cap(f))
		if gear:
			_dress(a)
		var fid := own_fabao(int(id))
		var how := "own"
		if fid == 0:
			fid = GENERAL_ATK if a.param(2) >= a.param(4) else GENERAL_MAT
			how = "general"
		var item := XGear.template("armor", fid)
		item.level = float(mini(fabao_cap(f), int(XMagicWeapon.max_level(item))))
		item.exp = 0.0
		var slot := a.equip_slots().find(int(item.etypeId))
		if slot >= 0 and not no_fabao:
			a.equips[slot] = item
		a.set_meta("baseline_fabao", [fid, how, int(item.level)])
		a.refresh_passive()
		a.recover_all()
	return s


## 栏位逐个挑：武器看物攻、魔攻里高的那项（按本人物攻、魔攻哪个高），防具看四项之和；法宝栏另外处理
static var _pool := {}
func _dress(a: XActor) -> void:
	var slots := a.equip_slots()
	var physical := a.param(2) >= a.param(4)
	for i in slots.size():
		var et := int(slots[i])
		if et == 13:
			continue
		var best := {}
		var best_score := -1.0
		for rec in _candidates(et):
			var item := XGear.template("weapon" if et == 1 else "armor", int(rec.id))
			if not a.can_equip(item):
				continue
			var p: Array = rec.params
			var score := float(p[2] if physical else p[4]) if et == 1 else float(p[2]) + float(p[3]) + float(p[4]) + float(p[5]) + float(p[0]) / 10.0
			if score > best_score:
				best_score = score
				best = item
		if not best.is_empty():
			a.equips[i] = best


func _candidates(et: int) -> Array:
	var key := "%d:%d" % [et, max_quality]
	if not _pool.has(key):
		var out := []
		for rec in XDB.table("Weapons" if et == 1 else "Armors"):
			if not rec is Dictionary or str(rec.get("name", "")) == "" or (et != 1 and int(rec.get("etypeId", 0)) != et):
				continue
			var m: Dictionary = rec.get("meta", {})
			if m.has("Magic Weapon") or m.has("req_actors") or not str(m.get("quality", "0")).strip_edges().is_valid_int():
				continue
			if int(str(m.get("quality", "0")).strip_edges()) > max_quality:
				continue
			out.append(rec)
		_pool[key] = out
	return _pool[key]


## 敌方现存血量（死了按 0）
static func _enemy_hp(logic: XBattleLogic) -> float:
	var t := 0.0
	for e in logic.enemies:
		t += maxf(0.0, float(e.hp)) if e.is_alive() else 0.0
	return t


func _fight(s: XState, troop: int) -> Dictionary:
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	if atk_scale != 1.0:
		for e in logic.enemies:
			e.output_scale = atk_scale   # 守层者有不少固定伤害技能（如 771 固定 15000），只调能力值没用，整体乘出伤
	logic.auto = true
	var total := 0.0
	var done := 0
	var hp0 := 0.0
	for e in logic.enemies:
		hp0 += float(e.mhp) if e.is_alive() else 0.0
	for r in turns:
		# 每回合开始把敌人血量补满（不动状态），这一回合掉的血就是这一回合的伤害；血量用真值，按比例扣血的技能才不失真
		for e in logic.enemies:
			if e.is_alive():
				e.hp = e.mhp
		var turn_dmg := 0.0
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		while count < 80:
			var u := logic.next_subject()
			if u == null:
				break
			count += 1
			var cmd := logic.decide(u)
			var hp_before := _enemy_hp(logic)
			var logs = logic.act(u, cmd[0], cmd[1])
			if u is XActor:
				turn_dmg += maxf(0.0, hp_before - _enemy_hp(logic))
			if debug:
				print("DBG t%d %s skill=%s enemyHp=%s logs=%s" % [r, logic.stable_id(u), str(int(cmd[0].id)) if cmd[0] != null else "-",
					str(logic.enemies.map(func(e): return int(e.hp))), JSON.stringify(logs).left(300)])
		if not logic.is_over():
			logic.end_turn()
		total += turn_dmg
		done += 1
		if logic.is_over():
			break
	var alive := logic.actors.filter(func(a): return a.hp > 0).size()
	return {"dmg": total / maxf(1.0, float(done)), "turns": done, "alive": alive, "won": logic.is_won(), "lost": logic.is_lost(),
		"aborted": logic.aborted, "enemyHp": hp0, "enemyAtk": logic.enemies.map(func(e): return int(e.param(2))), "enemyDef": logic.enemies.map(func(e): return [int(e.param(3)), int(e.param(5))]),
		"partyAtk": logic.actors.map(func(a): return [int(a.param(2)), int(a.param(4))]),
		"party": logic.actors.map(func(a): return int(a.actor_id)), "members": s.battle_members().map(func(a): return int(a.actor_id)), "partyHp": logic.actors.map(func(a): return int(a.mhp))}


## 撑到第几回合团灭（没团灭记 turns＋1）
func _survive(r: Dictionary) -> float:
	return float(r.turns) if bool(r.lost) else float(turns + 1)


static func _median(a: Array) -> float:
	var b := a.duplicate()
	b.sort()
	return (float(b[(b.size() - 1) / 2]) + float(b[b.size() / 2])) / 2.0


func _measure(list: Array, f: int) -> Dictionary:
	var per := []
	for team in list:
		per.append(_fight(_state(team, f), int(GUARDIAN[f])))
	return {"survive": _median(per.map(func(r): return _survive(r))), "dmg": _median(per.map(func(r): return float(r.dmg))), "per": per}


## 每层按对数二分找攻击倍率：中位数撑到 atk_target 回合左右团灭；倍率上限 4（前几层原版就偏弱时可以加）
func _search(list: Array) -> void:
	XEnemy.force_roll = 100.0
	turns = int(atk_target) + 4
	var rows := []
	for f in floors:
		var lo := log(1.0e-5)
		var hi := log(8.0)
		var best := {}
		var best_k := 1.0
		for it in iters:
			var mid := (lo + hi) / 2.0
			atk_scale = exp(mid)
			var m := _measure(list, f)
			if best.is_empty() or absf(float(m.survive) - atk_target) <= absf(float(best.survive) - atk_target):
				best = m
				best_k = atk_scale
			if float(m.survive) < atk_target:
				hi = mid   # 死得太快：降攻击
			else:
				lo = mid
		atk_scale = 1.0
		rows.append({"floor": f, "level": level_cap(f), "fabao": fabao_cap(f), "atkScale": best_k, "survive": best.survive, "median": best.dmg,
			"teams": best.per.map(func(r): return {"dmg": r.dmg, "turns": r.turns, "lost": r.lost, "partyHp": r.partyHp, "enemyAtk": r.enemyAtk})})
		print("ATKSEARCH floor=%d atk_scale=%.5f survive=%.1f median=%.0f" % [f, best_k, float(best.survive), float(best.dmg)])
	XEnemy.force_roll = -1.0
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify({"mode": "atk-search", "target": atk_target, "turns": turns, "teams": list, "rows": rows}, "\t"))
	print("BASELINE_DONE")
	get_tree().quit(0)


func _run() -> void:
	XEnemy.force_roll = 100.0   # 守层者不按神话
	var list := _teams()
	var rows := []
	if atk_search:
		_search(list)
		return
	for f in floors:
		var per := []
		for team in list:
			var s := _state(team, f)
			var r := _fight(s, int(GUARDIAN[f]))
			r["team"] = team
			r["fabao"] = team.map(func(id): return s.actor(int(id)).get_meta("baseline_fabao"))
			r["equips"] = team.map(func(id): return s.actor(int(id)).equips.map(func(e): return str(e.get("name", "")) if e is Dictionary else ""))
			per.append(r)
		var dmg: Array = per.map(func(r): return float(r.dmg))
		dmg.sort()
		var median: float = (dmg[(dmg.size() - 1) / 2] + dmg[dmg.size() / 2]) / 2.0
		var hp := {}
		for k in TARGET_TURNS:
			hp[k] = median * float(TARGET_TURNS[k])
		var wiped := per.filter(func(r): return int(r.alive) == 0).size()
		rows.append({"floor": f, "troop": GUARDIAN[f], "level": level_cap(f), "fabao": fabao_cap(f), "median": median,
			"min": dmg[0], "max": dmg[-1], "wiped": wiped, "hp": hp, "teams": per})
		print("BASELINE floor=%d level=%d fabao=%d median=%.0f min=%.0f max=%.0f wiped=%d/%d" % [f, level_cap(f), fabao_cap(f), median, dmg[0], dmg[-1], wiped, per.size()])
	XEnemy.force_roll = -1.0
	var out := {"gear": gear, "maxQuality": max_quality, "skippedActors": skipped_ids, "noFabao": no_fabao, "difficulty": difficulty, "teams": list, "turns": turns, "seed": seed, "rows": rows}
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify(out, "\t"))
	print("BASELINE_DONE")
	get_tree().quit(0)
