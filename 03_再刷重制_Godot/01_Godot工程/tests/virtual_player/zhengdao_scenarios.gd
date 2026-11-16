extends Node
## 证道验收场景（全弱者证道资格 v0.4.4 第三节 11 个场景＋第二节验收口径，D80／D83；cc/zhengdao-rules-fill，T019）。
## 不是专项（不在 tests/ 顶层，检查.sh 不跑）；单独跑：
##   godot --headless --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/zhengdao_scenarios.tscn -- \
##     [--scenario=all|1,3,4] [--games=300] [--lines=death,war,famine,plague] [--seed=20261116] [--max-turns=40] [--out=<目录>]
##
## 做法：每局照场景的档位和沉淀比例建一支队（角色从本档候选池按种子抽，每局不同），直接开 36 层本线骑士本体战（XTianqiHorsemen.prepare），
## 双方自动战斗（BattleLogic.decide，固定一套打法；不换人、不逃跑），打到分出胜负或 max-turns 回合（算输）。
## 养满＝等级上限 81、每栏精良及以下最好的一件、法宝 99 级（同 baseline_dps 36 层）。
## 「沉淀 p」暂用代理：养满以后生命、攻击、防御、魔攻、魔防、敏捷都乘 p（模型里沉淀就是出伤、承伤的比例）。
## T014 接虚拟玩家真存档后换成真实沉淀；那之前这里出的数只说明「场景能跑、规则接上了」，不作验收结论。
##
## 每个场景报：每位骑士的胜率、95% 区间（Wilson）、赢的局回合中位数、平均死几个人、违规次数（每回合上场超强者 > 本档上限，应为 0），
## 再按第二节口径判（D80：九成队每位骑士胜率点估计 ≥80%；八成队 95% 上界 ≤20%；D56／D83：平时最强队每位骑士 ≥75%，勇者约 75%）。
## 每格样本不到 300 局时判定写「样本不足」，只作冒烟。挑数用的种子和验收种子分开：--seed 换一个起点即可。
##
## 还没接上的（场景照跑，报告里注明）：
## - 『真 · 无名者之路』开关和它的补偿（九死 +33%／−22%、炼狱 +66%／−33%、证道 +111%／−66%）还没实装（v0.4.4 第六节第 6 条，没派），
##   场景 3～6、10 的全弱者队现在只吃弱者协力，比设计里弱得多；开关实装后这里改 _nameless()。
## - 场景 7「治疗开销」要能指定打法里治疗的贵贱，自动战斗还做不到；现在只跑默认打法一格并注明。

const KEY := "zhengdao"
const LEVEL := 81
const FABAO := 99
const GENERAL_ATK := 3557   # 破攻
const GENERAL_MAT := 3556   # 尊魔
const S := XTier.SUPER
const G := XTier.STRONG
const W := XTier.WEAK
const MIN_GAMES := 300

var games := 20
var lines: Array = ["death", "war", "famine", "plague"]
var seed_base := 20261116
var max_turns := 40
var out_dir := ""
var picked: Array = []
var verbose := false
var report := {}


## 场景表（v0.4.4 第三节）。groups：每组一支队，slots 是 5 格 [档位, 沉淀]（第 5 格是助力位，null＝空）；
## key 不写就是证道；hp 是骑士血量倍率（场景 8）；gate 是验收口径：ruler（标尺／平时最强：D83 ≥75%）、pass90、fail80、ref（只看）
static func scenarios() -> Array:
	var full := 1.0
	return [
		{"id": 1, "name": "标尺队标血量", "groups": [
			{"label": "2超＋2强｜超，养满", "slots": [[S, full], [S, full], [G, full], [G, full], [S, full]], "gate": "ruler"}]},
		{"id": 2, "name": "对照最强队", "groups": [
			{"label": "2超＋1强＋1弱｜超", "slots": [[S, full], [S, full], [G, full], [W, full], [S, full]], "gate": "ref"},
			{"label": "2超＋2强｜强", "slots": [[S, full], [S, full], [G, full], [G, full], [G, full]], "gate": "ref"},
			{"label": "2超＋2强｜空", "slots": [[S, full], [S, full], [G, full], [G, full], null], "gate": "ref"}]},
		{"id": 3, "name": "九成过", "nameless": true, "groups": [
			{"label": "4弱 90%｜弱 90%", "slots": [[W, 0.9], [W, 0.9], [W, 0.9], [W, 0.9], [W, 0.9]], "gate": "pass90"}]},
		{"id": 4, "name": "八成不过", "nameless": true, "groups": [
			{"label": "4弱 80%｜弱 80%", "slots": [[W, 0.8], [W, 0.8], [W, 0.8], [W, 0.8], [W, 0.8]], "gate": "fail80"}]},
		{"id": 5, "name": "夹在中间（参考）", "nameless": true, "groups": [
			{"label": "4弱 85%｜弱 85%", "slots": [[W, 0.85], [W, 0.85], [W, 0.85], [W, 0.85], [W, 0.85]], "gate": "ref"},
			{"label": "4弱 100%｜弱 100%", "slots": [[W, full], [W, full], [W, full], [W, full], [W, full]], "gate": "ref"}]},
		{"id": 6, "name": "偏科和混搭", "nameless": true, "groups": [
			{"label": "两输出100%＋两辅助0%｜0%", "slots": [[W, full], [W, full], [W, 0.0], [W, 0.0], [W, 0.0]], "gate": "fail80"},
			{"label": "全90%｜助力位0%", "slots": [[W, 0.9], [W, 0.9], [W, 0.9], [W, 0.9], [W, 0.0]], "gate": "ref"},
			{"label": "两输出80%＋两辅助100%｜100%", "slots": [[W, 0.8], [W, 0.8], [W, full], [W, full], [W, full]], "gate": "ref"},
			{"label": "全80%｜助力位100%", "slots": [[W, 0.8], [W, 0.8], [W, 0.8], [W, 0.8], [W, full]], "gate": "fail80"}]},
		{"id": 7, "name": "治疗开销", "note": "自动战斗还不能指定治疗贵贱，只跑默认打法（第 1、3、4 组各一格），T014 补打法参数", "groups": [
			{"label": "标尺队（默认打法）", "slots": [[S, full], [S, full], [G, full], [G, full], [S, full]], "gate": "ruler"},
			{"label": "4弱 90%（默认打法）", "nameless": true, "slots": [[W, 0.9], [W, 0.9], [W, 0.9], [W, 0.9], [W, 0.9]], "gate": "pass90"},
			{"label": "4弱 80%（默认打法）", "nameless": true, "slots": [[W, 0.8], [W, 0.8], [W, 0.8], [W, 0.8], [W, 0.8]], "gate": "fail80"}]},
		{"id": 8, "name": "血量误差 ±3%", "groups": [
			{"label": "标尺队 血量−3%", "hp": 0.97, "slots": [[S, full], [S, full], [G, full], [G, full], [S, full]], "gate": "ruler"},
			{"label": "标尺队 血量+3%", "hp": 1.03, "slots": [[S, full], [S, full], [G, full], [G, full], [S, full]], "gate": "ruler"},
			{"label": "4弱 90% 血量+3%", "hp": 1.03, "nameless": true, "slots": [[W, 0.9], [W, 0.9], [W, 0.9], [W, 0.9], [W, 0.9]], "gate": "pass90"},
			{"label": "4弱 80% 血量−3%", "hp": 0.97, "nameless": true, "slots": [[W, 0.8], [W, 0.8], [W, 0.8], [W, 0.8], [W, 0.8]], "gate": "fail80"}]},
		{"id": 9, "name": "换人和死人", "swap": true, "groups": [
			{"label": "2超＋2强｜超（换人合法性）", "slots": [[S, full], [S, full], [G, full], [G, full], [S, full]], "gate": "ref"}]},
		{"id": 10, "name": "低难度", "nameless": true, "groups": [
			{"label": "炼狱 全弱者中位 50%", "key": "lianyu", "slots": [[W, 0.5], [W, 0.5], [W, 0.5], [W, 0.5], [W, 0.5]], "gate": "ref"},
			{"label": "炼狱 常见队 2超＋2弱｜弱 50%", "key": "lianyu", "nameless": false, "slots": [[S, 0.5], [S, 0.5], [W, 0.5], [W, 0.5], [W, 0.5]], "gate": "ref"},
			{"label": "九死 全弱者中位 50%", "key": "jiusi", "slots": [[W, 0.5], [W, 0.5], [W, 0.5], [W, 0.5], [W, 0.5]], "gate": "ref"},
			{"label": "九死 全弱者满养成", "key": "jiusi", "slots": [[W, full], [W, full], [W, full], [W, full], [W, full]], "gate": "ref"},
			{"label": "九死 常见队 1超＋1强＋2弱｜弱 50%", "key": "jiusi", "nameless": false, "slots": [[S, 0.5], [G, 0.5], [W, 0.5], [W, 0.5], [W, 0.5]], "gate": "ref"}]},
		{"id": 11, "name": "平时不受影响", "groups": [
			{"label": "证道随机中位阵容（合法随机，沉淀 50%）", "random": true, "p": 0.5, "gate": "ref"}]},
	]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--games="):
			games = maxi(1, int(a.substr(8)))
		elif a.begins_with("--lines="):
			lines = Array(a.substr(8).split(","))
		elif a.begins_with("--seed="):
			seed_base = int(a.substr(7))
		elif a.begins_with("--max-turns="):
			max_turns = int(a.substr(12))
		elif a == "--verbose":
			verbose = true
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--scenario="):
			var v := a.substr(11)
			if v != "all":
				picked = Array(v.split(",")).map(func(x): return int(x))
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	var t0 := Time.get_ticks_msec()
	var out := []
	for sc in scenarios():
		if not picked.is_empty() and not picked.has(int(sc.id)):
			continue
		out.append(_scenario(sc))
	report = {"version": 1, "games": games, "seed": seed_base, "max_turns": max_turns, "lines": lines, "min_games": MIN_GAMES,
		"zhengdao_rules": XTianqiHorsemen.zd_table(), "scenarios": out, "seconds": (Time.get_ticks_msec() - t0) / 1000.0,
		"proxy": "沉淀 p＝养满后六项能力 ×p（代理，T014 换真存档）", "nameless_road": "未实装：全弱者队只吃弱者协力"}
	var md := _markdown(report)
	print(md)
	var errs: int = out.reduce(func(acc, s): return acc + int(s.get("errors", 0)), 0)
	var viol: int = out.reduce(func(acc, s): return acc + int(s.get("violations", 0)), 0)
	print("ZD_SCENARIOS=" + JSON.stringify({"scenarios": out.size(), "violations": viol, "errors": errs, "seconds": report.seconds}))
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		var f := FileAccess.open(out_dir.path_join("zhengdao_scenarios.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, " "))
		f.close()
		var m := FileAccess.open(out_dir.path_join("zhengdao_scenarios.md"), FileAccess.WRITE)
		m.store_string(md)
		m.close()
	get_tree().quit.call_deferred(0 if viol == 0 and errs == 0 else 1)


func _scenario(sc: Dictionary) -> Dictionary:
	var rows := []
	var viol := 0
	var errs := 0
	for g in sc.groups:
		var key := str(g.get("key", KEY))
		var nameless := bool(g.get("nameless", sc.get("nameless", false)))
		var per_line := {}
		for line in lines:
			var res := []
			for i in games:
				var seed := seed_base + int(sc.id) * 100000 + rows.size() * 10000 + i
				res.append(_game(sc, g, key, str(line), seed))
			per_line[line] = _stats(res, str(g.gate))
			if verbose and int(per_line[line].errors) > 0:
				print("VP error ", JSON.stringify(per_line[line].error_samples))
			viol += int(per_line[line].violations)
			errs += int(per_line[line].errors)
		rows.append({"label": str(g.label), "key": key, "nameless": nameless, "gate": str(g.gate), "lines": per_line})
	var swap := {}
	if bool(sc.get("swap", false)):
		swap = _swap_checks()
		errs += int(swap.get("failed", 0))
	return {"id": int(sc.id), "name": str(sc.name), "note": str(sc.get("note", "")), "groups": rows, "swap": swap, "violations": viol, "errors": errs}


# ---- 建队 ----

static var _pools := {}
## 本档某档位能上场的角色（候选池里、能进出战成员的；专属模块角色除外）
func _ids(key: String, tier: String) -> Array:
	var k := key + ":" + tier
	if not _pools.has(k):
		var ids: Array = XTianqi.pool(key).get(tier, []).filter(func(id): return not XActorModules.IDS.has(int(id)))
		ids.sort()
		_pools[k] = ids
		if verbose:
			print("VP pool %s %s raw=%d ok=%d" % [key, tier, XTianqi.pool(key).get(tier, []).size(), ids.size()])
	return _pools[k]


## 这一局的 5 格（角色号、沉淀）；不重复。random：按本档上限随机合法阵容（场景 11）
func _lineup(g: Dictionary, key: String, rng: RandomNumberGenerator) -> Array:
	var used := {}
	var out := []
	var slots: Array = g.get("slots", [])
	if bool(g.get("random", false)):
		var cap := XTianqi.super_cap(_dummy(key))
		var n_super := rng.randi_range(0, cap)
		var tiers := []
		for i in 4:
			tiers.append(S if i < n_super else ([G, W][rng.randi_range(0, 1)]))
		tiers.append([S, G, W][rng.randi_range(0, 2)] if XTianqi.helper_super_key(key) else [G, W][rng.randi_range(0, 1)])
		slots = tiers.map(func(t): return [t, float(g.get("p", 0.5))])
	for sl in slots:
		if sl == null:
			out.append([0, 0.0])
			continue
		var bag: Array = _ids(key, str(sl[0])).filter(func(id): return not used.has(id))
		if bag.is_empty():
			out.append([0, 0.0])
			continue
		var id := int(bag[rng.randi_range(0, bag.size() - 1)])
		used[id] = true
		out.append([id, float(sl[1])])
	return out


static var _dummies := {}
static func _dummy(key: String) -> XState:
	if not _dummies.has(key):
		var s := XState.new()
		s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": key}
		_dummies[key] = s
	return _dummies[key]


func _state(lineup: Array, key: String, seed: int, line: String) -> XState:
	var ids := lineup.filter(func(x): return int(x[0]) > 0).map(func(x): return int(x[0]))
	var s := XState.new_game(XTianqi.legacy_of(key), int(ids[0]), ids.slice(1))
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": key, "lineup": ids.duplicate(), "line": line}
	s.random_master = XRandomStream.hex64(seed)
	s.orb_seed = seed
	seed(seed)
	s.set_variable(20, 36)
	s.actor_max_level = LEVEL
	for id in ids:
		if not s.party.has(int(id)):
			XTianqi._joining = true   # 同专项：开局入队那一步（XTianqi.start_new_game 的开局指令）
			s.add_actor(int(id))
			XTianqi._joining = false
	for i in 5:
		s.set_battle_slot(i, int(lineup[i][0]))
	for x in lineup:
		if int(x[0]) <= 0:
			continue
		var a := s.actor(int(x[0]))
		a.change_level_mv(LEVEL)
		_dress(a)
		var fid := _own_fabao(int(x[0]))
		if fid == 0:
			fid = GENERAL_ATK if a.param(2) >= a.param(4) else GENERAL_MAT
		var item := XGear.template("armor", fid)
		item.level = float(mini(FABAO, int(XMagicWeapon.max_level(item))))
		item.exp = 0.0
		var slot := a.equip_slots().find(int(item.etypeId))
		if slot >= 0:
			a.equips[slot] = item
		a.refresh_passive()
		_settle(a, float(x[1]))
		a.recover_all()
	return s


## 兑换大厅有卖、备注 <req_actors> 含本人的法宝（同 baseline_dps.own_fabao）
static var _own := {}
static func _own_fabao(actor_id: int) -> int:
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


## 沉淀代理：六项能力 ×p（p＝1 不动）
static func _settle(a: XActor, p: float) -> void:
	if p >= 1.0:
		return
	a.param_mark_dirty()
	for i in [0, 2, 3, 4, 5, 6]:
		a.add_param(i, -(1.0 - maxf(0.0, p)) * float(a.param(i)))
	a.param_mark_dirty()


static var _gear_pool := {}
static func _dress(a: XActor) -> void:
	var slots := a.equip_slots()
	var physical := a.param(2) >= a.param(4)
	for i in slots.size():
		var et := int(slots[i])
		if et == 13:
			continue
		if not _gear_pool.has(et):
			var list := []
			for rec in XDB.table("Weapons" if et == 1 else "Armors"):
				if not rec is Dictionary or str(rec.get("name", "")) == "" or (et != 1 and int(rec.get("etypeId", 0)) != et):
					continue
				var m: Dictionary = rec.get("meta", {})
				if m.has("Magic Weapon") or m.has("req_actors") or not str(m.get("quality", "0")).strip_edges().is_valid_int():
					continue
				if int(str(m.get("quality", "0")).strip_edges()) > 3:
					continue
				list.append(rec)
			_gear_pool[et] = list
		var best := {}
		var best_score := -1.0
		for rec in _gear_pool[et]:
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


# ---- 一局 ----

func _game(sc: Dictionary, g: Dictionary, key: String, line: String, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lineup := _lineup(g, key, rng)
	if lineup.filter(func(x): return int(x[0]) > 0).size() < 4:
		return {"error": "阵容凑不齐", "lineup": lineup}
	var s := _state(lineup, key, seed, line)
	XState.current = s
	var want := lineup.slice(0, 4).filter(func(x): return int(x[0]) > 0).size()
	if s.battle_members().size() < want:
		return {"error": "上场人数不对", "lineup": lineup, "members": s.battle_members().map(func(a): return int(a.actor_id))}
	if not XTianqiHorsemen.prepare(line, s, "body"):
		return {"error": "骑士战没开（XTianqiHorsemen.prepare 拒绝）"}
	var logic := XBattleLogic.new()
	logic.setup(int(XTianqiLine.data(line).shell_troop), s, XBattleRandom.create(str(s.random_master)))
	logic.auto = true
	var kn = XTianqiHorsemen.fight(logic).get("knight")
	if kn == null:
		return {"error": "没换成骑士"}
	var hp_mult := float(g.get("hp", 1.0))
	if hp_mult != 1.0:
		kn.add_param(0, float(kn.mhp) * (hp_mult - 1.0))
		kn.param_mark_dirty()
		kn.hp = kn.mhp
	var cap := XTianqi.super_cap(s)
	var violations := 0
	var turns := 0
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
			var cmd := logic.decide(u)
			var alog = logic.act(u, cmd[0], cmd[1])
			if verbose and turns <= 1:
				print("VP act %s skill=%s knight=%.0f %s" % [logic.stable_id(u), str(int(cmd[0].id)) if cmd[0] != null else "-", float(kn.hp), JSON.stringify(alog.filter(func(l): return l.type == "hit").map(func(l): return [l.get("hp"), l.get("critical")])).left(300)])
			if logic.is_over():
				break
		if not logic.is_over():
			logic.end_turn()
		if verbose:
			print("VP t%d acts=%d knight=%.0f/%.0f party=%s ms=%d" % [turns, guard, float(kn.hp), float(kn.mhp), str(logic.actors.map(func(a): return int(a.hp))), Time.get_ticks_msec()])
	var won := logic.is_won()
	var deaths := logic.actors.filter(func(a): return a.is_dead()).size()
	var negative := logic.actors.any(func(a): return float(a.hp) < 0.0) or float(kn.hp) < 0.0
	logic.end_battle(0 if won else 2)
	return {"won": won, "turns": turns, "deaths": deaths, "violations": violations, "negative": negative,
		"lineup": lineup.map(func(x): return int(x[0]))}


# ---- 统计 ----

## Wilson 95% 区间
static func wilson(k: int, n: int) -> Array:
	if n <= 0:
		return [0.0, 1.0]
	var z := 1.96
	var p := float(k) / n
	var d := 1.0 + z * z / n
	var c := (p + z * z / (2.0 * n)) / d
	var h := z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / d
	return [maxf(0.0, c - h), minf(1.0, c + h)]


static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return (float(b[(b.size() - 1) / 2]) + float(b[b.size() / 2])) / 2.0


func _stats(res: Array, gate: String) -> Dictionary:
	var ok := res.filter(func(r): return not r.has("error"))
	var n := ok.size()
	var k := ok.filter(func(r): return bool(r.won)).size()
	var ci := wilson(k, n)
	var rate := float(k) / maxf(1.0, float(n))
	var verdict := "参考"
	match gate:
		"pass90":
			verdict = "过" if rate >= 0.8 else "不过"   # D80：点估计 ≥80%
		"fail80":
			verdict = "过" if float(ci[1]) <= 0.2 else "不过"   # 95% 上界 ≤20%
		"ruler":
			verdict = "过" if rate >= 0.75 else "不过"   # D56／D83：平时最强队每位 ≥75%
	if gate != "ref" and n < MIN_GAMES:
		verdict = "未判（样本 %d<%d，冒烟时按点估计会%s）" % [n, MIN_GAMES, verdict]
	return {"n": n, "wins": k, "rate": rate, "ci95": ci, "turns_median_won": _median(ok.filter(func(r): return bool(r.won)).map(func(r): return int(r.turns))), "turns_median_all": _median(ok.map(func(r): return int(r.turns))),
		"deaths_mean": ok.reduce(func(acc, r): return acc + int(r.deaths), 0) / maxf(1.0, float(n)),
		"violations": ok.reduce(func(acc, r): return acc + int(r.violations), 0), "negative": ok.filter(func(r): return bool(r.negative)).size(),
		"errors": res.size() - n, "error_samples": res.filter(func(r): return r.has("error")).slice(0, 2), "verdict": verdict}


# ---- 场景 9：换人合法性（直接问 BattleLogic.can_tianqi_swap） ----

func _swap_checks() -> Dictionary:
	var checks := []
	var sup: Array = _ids(KEY, S)
	var strong: Array = _ids(KEY, G)
	if sup.size() < 3 or strong.size() < 2:
		return {"failed": 1, "checks": [["候选不够", false]]}
	# 场上 2 超＋2 强，助力位超强者
	var line := [[sup[0], 1.0], [sup[1], 1.0], [strong[0], 1.0], [strong[1], 1.0], [sup[2], 1.0]]
	var s := _state(line, KEY, seed_base, "death")
	XState.current = s
	XTianqiHorsemen.prepare("death", s, "body")
	var lg := XBattleLogic.new()
	lg.setup(int(XTianqiLine.data("death").shell_troop), s)
	var a_strong: XActor = s.actor(int(strong[0]))
	var a_super: XActor = s.actor(int(sup[0]))
	checks.append(["满额：助力位超强者换下强者应被拒", not lg.can_tianqi_swap(a_strong)])
	checks.append(["满额：助力位超强者换下超强者可以", lg.can_tianqi_swap(a_super)])
	a_super.hp = 0.0
	a_super.refresh_resources()
	lg._die(a_super)
	checks.append(["倒下的人不能换（不自动补位）", not lg.can_tianqi_swap(a_super) and lg.actors.has(a_super)])
	var h := lg.tianqi_swap(s.actor(int(sup[1])))
	checks.append(["换人照工程原位替换", h != null and lg.actors.find(h) == 1])
	lg.end_battle(0)
	return {"failed": checks.filter(func(c): return not bool(c[1])).size(), "checks": checks}


# ---- 报告 ----

static func _pct(x: float) -> String:
	return "%d%%" % roundi(x * 100.0)


func _markdown(r: Dictionary) -> String:
	var out := PackedStringArray()
	out.append("# 证道验收场景（%d 局／格，种子 %d，上限 %d 回合）" % [int(r.games), int(r.seed), int(r.max_turns)])
	out.append("")
	out.append("沉淀用代理（%s）；%s。不到 %d 局的判定只作冒烟。" % [r.proxy, r.nameless_road, MIN_GAMES])
	for sc in r.scenarios:
		out.append("")
		out.append("## %d %s" % [int(sc.id), str(sc.name)])
		if str(sc.note) != "":
			out.append("注：" + str(sc.note))
		out.append("")
		out.append("| 阵容 | 档 | 口径 | " + " | ".join(lines.map(func(l): return str(XTianqiHorsemen.knight(str(l)).get("name", l)))) + " |")
		out.append("|---|---|---|" + "---|".repeat(lines.size()))
		for g in sc.groups:
			var cells := PackedStringArray()
			for l in lines:
				var st: Dictionary = g.lines[l]
				var extra := ""
				if int(st.violations) > 0:
					extra += "，违规%d" % int(st.violations)
				if int(st.errors) > 0:
					extra += "，出错%d" % int(st.errors)
				cells.append("%s（%s～%s）赢局回合%s／全部%s 死%.1f %s%s" % [_pct(st.rate), _pct(st.ci95[0]), _pct(st.ci95[1]), str(st.turns_median_won) if int(st.wins) > 0 else "—", str(st.turns_median_all), float(st.deaths_mean), str(st.verdict), extra])
			out.append("| %s%s | %s | %s | %s |" % [str(g.label), "（无名者之路）" if bool(g.nameless) else "", str(g.key), str(g.gate), " | ".join(cells)])
		if not sc.swap.is_empty():
			out.append("")
			for c in sc.swap.checks:
				out.append("- %s：%s" % [str(c[0]), "对" if bool(c[1]) else "**错**"])
	return "\n".join(out)
