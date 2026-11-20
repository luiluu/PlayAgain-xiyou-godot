extends Node
## 【cc·T162】期四丙档标尺（基础数值重构 v0.3 第九节第 1 条「丙 中位队」、第 2 条第 4、6 步）：
## 艰险第 36 层的常见队（3 强者＋1 弱者），自然掉落装备取中位（掉落表掷 100 套取中位那套），对木桩量每回合全队伤害和常规一下。
## 不是专项（不在 tests/ 顶层，检查.sh 不跑）；专项在 tests/xiyou_tianqi_c_tier.gd（只测纯函数，不量数）。单独跑：
##   godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/c_tier.tscn -- \
##     [--teams=4（每个模板）] [--templates=A,B,C,D] [--shape=old] [--sets=100] [--battles=10] [--turns=5] [--foes=1,3] [--seed=20261118] [--out=<json>] [--rebuild] [--gear-file=<res 路径>] [--no-wine]
##
## 口径（稿第九节第 1 条，能做到的）：
## - 队伍：艰险候选池里随机抽 3 强者＋1 弱者（种子定住），共 teams 队；每队各自造一套「中位装备」，最后取各队的中位。
## - 装备：一套＝从第 1 层打到第 30 层（31 层起归七印祭坛，不掉通用装备）每层 battles 场通用掉落（XTianqiDrop.pieces／roll_grade／pick，同游戏）＋每层守层者首杀固定掉落
##   （guardian_grades），攒成一堆；4 人按顺序、每栏取本人主属性权重最高的一件（一件只给一个人）。掷 sets 套，按全队装备得分之和取中位那一套，存进 gear-file，
##   以后每次重量读同一份（--rebuild 才重掷）。不掷词条、不挑词条（词条是甲档「掷满」那一半；丙档「自然」＝没挑过的，这一版没做）。
## - 法宝：本人专属，没有就破攻／尊魔（同甲档），等级＝第 36 层的法宝上限 min(99, 9＋3×层)。
## - 等级 81（第 36 层的等级上限）；不进阶、不喂熟练度、不带号卷／秘籍／黑印（31 层起才出现的东西，「按层数自然拿到的」这一版取没有）。
## - 酒：天平酒喝上（XTianqiMoney 的 scale 记录，--no-wine 不喝）；助力位空；烙印：职责＝输出的刻印、立到逆命、生效 75%（--brand=N），坦克、辅助不签（T220 后烙印开关默认开）。
## - 木桩：物防魔防 8200（K 脚本的 _pin_def）、元素中性、不免暴击；另备免暴击木桩（给 U 的第二个数，挂 XTianqiCombat.META_CRIT_IMMUNE，同死亡骑士在 item_cri 最前面拦；T285 r3 起不再加暴击回避特性——那会被天启篇暴闪底子封顶夹掉）；生命每回合补满、我方每回合回满；
##   木桩的攻击压到 1，只量我方每次行动让木桩掉的血。--foes=1,3：单敌、多敌（缺省各量一次，多敌＝3 个木桩）。

const K := preload("res://tests/virtual_player/k_calibrate.gd")
const TB := preload("res://tests/virtual_player/team_builder.gd")
const DIFFICULTY := "jianxian"
const FLOOR := 36
const LEVEL := 81
const DEFAULT_GEAR_FILE := "res://tests/virtual_player/c_tier_gear.json"
const NO_CRIT_TRAIT := {"code": 22, "dataId": 3, "value": 10.0}  # 旧做法（暴击回避 +1000%），T285 r3 起不用；留着给专项查「敌人数据没被改」

var teams_n := 4
var templates: Array = ["A", "B", "C", "D"]
var shape_old := false
var sets_n := 100
var battles := 10
var turns := 5
var foes_list: Array = [1, 3]
var seed_v := 20261118
var out_path := ""
var rebuild := false
var gear_file := DEFAULT_GEAR_FILE
var wine := true
var brand_pct := 75.0  # 输出职责签约、生效烙印（T073 中位起点 75%）；坦克、辅助不签。--brand=0 关烙印


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--teams="):
			teams_n = int(a.substr(8))
		elif a.begins_with("--templates="):
			templates = Array(a.substr(12).split(","))
		elif a == "--shape=old":
			shape_old = true
		elif a.begins_with("--sets="):
			sets_n = int(a.substr(7))
		elif a.begins_with("--battles="):
			battles = int(a.substr(10))
		elif a.begins_with("--turns="):
			turns = int(a.substr(8))
		elif a.begins_with("--foes="):
			foes_list = Array(a.substr(7).split(",")).map(func(x): return int(x))
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a == "--rebuild":
			rebuild = true
		elif a.begins_with("--gear-file="):
			gear_file = a.substr(12)
		elif a.begins_with("--brand="):
			brand_pct = clampf(float(a.substr(8)), 0.0, 100.0)
		elif a == "--no-wine":
			wine = false
	_run.call_deferred()


# ---- 纯函数（专项测它们）----

## 偶数个取中间两个的平均
static func median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return (float(b[(b.size() - 1) / 2]) + float(b[b.size() / 2])) / 2.0


## 取中位的下标：按值排序后第 (n−1)/2 个（偶数个取靠前的那个：要一套真实存在的装备，不能取平均）
static func median_index(scores: Array) -> int:
	var idx := range(scores.size())
	idx.sort_custom(func(x, y): return float(scores[x]) < float(scores[y]) or (float(scores[x]) == float(scores[y]) and int(x) < int(y)))
	return int(idx[(idx.size() - 1) / 2]) if not idx.is_empty() else -1


## 艰险候选池里按种子抽 n 队：每队 strong_n 强者＋weak_n 弱者（缺省 3 强＋1 弱；上不了场的不要，同 baseline_dps）。返回 [[强…, 弱…], ...]
static func pick_teams(n: int, seed_val: int, strong_n := 3, weak_n := 1) -> Array:
	var pool: Dictionary = XTianqi.pool(DIFFICULTY)
	var ok := func(id):
		var t := XState.new_game(XTianqi.legacy_of(DIFFICULTY), int(id), [])
		return t.battle_members().map(func(x): return int(x.actor_id)).has(int(id))
	var strong: Array = (pool[XTier.STRONG] as Array).duplicate()
	strong.sort()
	strong = strong.filter(ok)
	var weak: Array = (pool[XTier.WEAK] as Array).duplicate()
	weak.sort()
	weak = weak.filter(ok)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var out := []
	for _t in n:
		var bag := strong.duplicate()
		var team := []
		for _i in strong_n:
			team.append(bag.pop_at(rng.randi_range(0, bag.size() - 1)))
		var wbag := weak.duplicate()
		for _i in weak_n:
			team.append(wbag.pop_at(rng.randi_range(0, wbag.size() - 1)))
		out.append(team)
	return out


## 掷这一层的掉落：battles_per_floor 场通用掉落＋守层者首杀固定掉落（31 层起不掉通用装备，返回空）。返回 [{kind, id}, ...]（kind 2 武器、3 防具）
static func roll_floor(s: XState, members: Array, f: int, battles_per_floor: int, rng: RandomNumberGenerator) -> Array:
	var out := []
	var g: Dictionary = XTianqiDrop.table().get("generic", {})
	var range_: Array = g.get("floors", [1, 30])
	if f < int(range_[0]) or f > int(range_[1]):
		return out
	s.set_variable(20, f)
	for _b in battles_per_floor:
		var n := XTianqiDrop.pieces(s, f, members)
		var count := floori(n)
		if rng.randf() < n - float(count):
			count += 1
		for _i in count:
			var d := XTianqiDrop.pick(s, f, XTianqiDrop.roll_grade(f, rng.randf()), members, rng.randf(), rng.randf())
			if not d.is_empty():
				out.append({"kind": int(d.kind), "id": int(d.id)})
	var gate := XTianqiDrop.gate_grade(f)
	var top := int(g.get("top_grade", 5))
	var gd: Dictionary = XTianqiDrop.table().get("guardian", {})
	var first: Array = gd.get("first", [1, 3])
	var grades := []
	for _i in int(first[0]):
		grades.append(mini(gate + 1, top))
	for _i in int(first[1]):
		grades.append(gate)
	for gr in grades:
		var d := XTianqiDrop.pick(s, f, int(gr), members, rng.randf(), rng.randf())
		if not d.is_empty():
			out.append({"kind": int(d.kind), "id": int(d.id)})
	return out


## 掷一堆装备：从第 1 层到第 30 层（roll_floor 逐层累加）
static func roll_pile(s: XState, members: Array, battles_per_floor: int, rng: RandomNumberGenerator) -> Array:
	var out := []
	var range_: Array = XTianqiDrop.table().get("generic", {}).get("floors", [1, 30])
	for f in range(int(range_[0]), int(range_[1]) + 1):
		out.append_array(roll_floor(s, members, f, battles_per_floor, rng))
	return out


## （人、等级、装备）→ [栏位类型, 穿不穿得上, 得分]，assign 反复用，不缓存每掷一套都要重算几百件
static var _cache := {}
static func clear_cache() -> void:
	_cache.clear()


static func _rate(a: XActor, d: Dictionary, w: Dictionary) -> Array:
	var key := "%d:%d:%d:%d" % [int(a.actor_id), int(a.level), int(d.kind), int(d.id)]
	if not _cache.has(key):
		var item := item_of(d, "c_rate")
		var ok: bool = a.can_equip(item) and XTianqiGear.applies(item)
		_cache[key] = [int(item.get("etypeId", 0)), ok, K._wscore(XTianqiGear.effective_params(item), w) if ok else 0.0]
	return _cache[key]


## 4 人按顺序、每栏从堆里挑本人主属性权重最高的一件（一件只给一个人）。返回 {actor_id: [{slot, kind, id}], "score": 总分}
static func assign(members: Array, pile: Array) -> Dictionary:
	var left: Array = pile.duplicate()
	var out := {}
	var total := 0.0
	for a in members:
		var w := K.main_weights(a)
		var slots: Array = a.equip_slots()
		var rows := []
		for i in slots.size():
			var et := int(slots[i])
			if et == 13 or not XTianqiGear.open_type(et):
				continue
			var best := -1
			var best_score := -1.0
			for j in left.size():
				var r := _rate(a, left[j], w)
				if int(r[0]) != et or not bool(r[1]):
					continue
				var sc := float(r[2])
				if sc > best_score:
					best_score = sc
					best = j
			if best >= 0:
				rows.append({"slot": i, "kind": int(left[best].kind), "id": int(left[best].id)})
				total += best_score
				left.remove_at(best)
		out[int(a.actor_id)] = rows
	out["score"] = total
	return out


static func item_of(d: Dictionary, instance: String) -> Dictionary:
	var item := XGear.template("weapon" if int(d.kind) == 2 else "armor", int(d.id))
	item["instanceId"] = instance
	return item


# ---- 建档与量数 ----

func _state(team: Array, gear: Dictionary) -> XState:
	return build_state(team, gear, FLOOR, LEVEL, mini(XMagicWeapon.CAP_TOP, 9 + 3 * FLOOR), seed_v, brand_pct, wine)


## 建一队的档：第 floor 层、等级 level、本人专属法宝（没有就破攻／尊魔）fabao_level 级、输出职责刻印烙印 brand_pct%、天平酒
static func build_state(team: Array, gear: Dictionary, floor_no: int, level: int, fabao_level: int, seed_val: int, brand: float, drink: bool) -> XState:
	var s := XState.new_game(XTianqi.legacy_of(DIFFICULTY), int(team[0]), team.slice(1))
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": DIFFICULTY, "lineup": team.duplicate()}
	s.random_master = XRandomStream.hex64(seed_val + int(team[0]) + floor_no)
	s.orb_seed = seed_val * 1000 + int(team[0]) + floor_no
	seed(seed_val * 1000 + int(team[0]) + floor_no)
	s.set_variable(20, floor_no)
	s.actor_max_level = level
	XState.current = s
	for id in team:
		var a := s.actor(int(id))
		a.change_level_mv(level)
		for r in gear.get(int(id), gear.get(str(id), [])):
			a.equips[int(r.slot)] = item_of(r, "c_%d_%d" % [int(id), int(r.slot)])
		var fid := K._own_fabao(int(id))
		if fid == 0:
			var mw := K.main_weights(a)
			fid = K.GENERAL_ATK if float(mw.get("atk", 0.0)) >= float(mw.get("mat", 0.0)) else K.GENERAL_MAT
		var f := XGear.template("armor", fid)
		f.level = float(mini(fabao_level, int(XMagicWeapon.max_level(f))))
		var slot := a.equip_slots().find(int(f.etypeId))
		if slot >= 0:
			a.equips[slot] = f
		if brand > 0.0 and str(XTianqiBase.line_data().get("actors", {}).get(str(id), {}).get("role", "")) == "输出":
			XZhenqi.data(a)
			a.zhenqi["brand_carved"] = 1
			a.zhenqi["brand_realm"] = XTianqiBrand.last_realm()
			a.zhenqi["brand"] = roundi(brand * XTianqiBrand.scale())
		a.param_mark_dirty()
		a.refresh_passive()
		a.recover_all()
	if drink:
		XTianqiMoney.money(s)["scale"] = {"floor": floor_no, "goods": ["wine"], "buys": 1}
	XState.current = s
	return s


## 每层的中位装备（T162 守层者三表，同丙档口径）：每掷一套就是一次从第 1 层打到第 f 层的累计（逐层掷、每层按当层等级的队伍挑能穿的），
## 每层把 sets 套按得分取中位那一套。返回 {层: {actor_id: [{slot, kind, id}]}}。level_of：层→等级（baseline_dps.level_cap）
static func floor_gears(team: Array, floors: Array, sets: int, battles_per_floor: int, seed_val: int, level_of: Callable) -> Dictionary:
	var states := {}
	for f in floors:
		var lv := int(level_of.call(f))
		states[f] = build_state(team, {}, f, lv, 0, seed_val, 0.0, false)
	var top := int(floors.max())
	var scores := {}
	var assigned := {}
	for f in floors:
		scores[f] = []
		assigned[f] = []
	var rng := RandomNumberGenerator.new()
	for i in sets:
		rng.seed = seed_val + int(team[0]) * 7919 + i * 104729
		var pile := []
		for f in range(1, top + 1):
			var st: XState = states[f] if states.has(f) else states[_floor_at_or_after(floors, f)]
			pile.append_array(roll_floor(st, st.battle_members(), f, battles_per_floor, rng))
			if states.has(f):
				var asg := assign(st.battle_members(), pile)
				scores[f].append(float(asg.score))
				assigned[f].append(asg)
	var out := {}
	for f in floors:
		var chosen: Dictionary = assigned[f][median_index(scores[f])]
		var g := {}
		for id in team:
			g[int(id)] = chosen[int(id)]
		out[f] = g
	return out


static func _floor_at_or_after(floors: Array, f: int) -> int:
	for x in floors:
		if int(x) >= f:
			return int(x)
	return int(floors[-1])


## 木桩敌群：第一个敌人往后 foes 个都不是守层者、不是首领
static func dummy_troop(foes: int) -> int:
	if foes <= 1:
		return K._troop(null)
	for t in range(K.TROOP, K.TROOP + 600):
		var tr := XDB.rec("Troops", t)
		var ms: Array = tr.get("members", []) if not tr.is_empty() else []
		if ms.size() < foes:
			continue
		var ok := true
		for m in ms:
			var eid := int(m.get("enemyId", 0))
			if eid <= 0 or XGuardianRework.floor_of(eid) > 0 or XEnemy.boss_id(eid):
				ok = false
				break
		if ok:
			return t
	return K._troop(null)


## 一场：turns 回合，每回合开始木桩补满、钉防御，我方回满；量我方每次行动让木桩掉的血。返回 {team, per_turn, hits}
func _fight(s: XState, foes: int, crit_immune: bool) -> Dictionary:
	var logic := XBattleLogic.new()
	logic.setup(dummy_troop(foes), s, null)
	logic.auto = true
	var dummies: Array = logic.alive(logic.enemies).slice(0, foes)
	for e in dummies:
		e.add_param(0, 1.0e9)
		e.add_param(2, 1.0 - float(e.param(2)))  # 攻击压到 1，不打死我方
		e.add_param(4, 1.0 - float(e.param(4)))
		if crit_immune:
			e.set_meta(XTianqiCombat.META_CRIT_IMMUNE, true)  # 免暴击：同死亡骑士，不经暴击闪避（T285 r3）
		e.param_mark_dirty()
	var per_turn := []
	var hits := []
	for _r in turns:
		for e in dummies:
			K._pin_def(e)
			e.hp = e.mhp
		for a in logic.actors:
			a.recover_all()
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
			var before := _hp(dummies)
			logic.act(u, cmd[0], cmd[1])
			if u is XActor:
				var d := maxf(0.0, before - _hp(dummies))
				turn_dmg += d
				if d > 0.0:
					hits.append(d)
		if not logic.is_over():
			logic.end_turn()
		per_turn.append(turn_dmg)
	logic.end_battle(0)
	return {"per_turn": per_turn, "hits": hits}


static func _hp(list: Array) -> float:
	var t := 0.0
	for e in list:
		t += float(e.hp) if e.is_alive() else 0.0
	return t


## 一队的中位装备：读 gear-file 里这一队的记录，没有（或 --rebuild）就掷 sets 套取中位
func _team_gear(team: Array, cache: Dictionary) -> Dictionary:
	var key := ",".join(team.map(func(x): return str(x)))
	if not rebuild and cache.has(key):
		return cache[key]
	var base := _state(team, {})
	var members: Array = base.battle_members()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v + int(team[0]) * 7919
	var all := []
	var scores := []
	for _i in sets_n:
		var assigned := assign(members, roll_pile(base, members, battles, rng))
		all.append(assigned)
		scores.append(float(assigned.score))
	var mid := median_index(scores)
	var chosen: Dictionary = all[mid]
	var rec := {"team": team, "sets": sets_n, "battles": battles, "seed": seed_v, "score": float(chosen.score),
		"score_min": scores.min(), "score_max": scores.max(), "score_median": median(scores), "gear": {}}
	for a in members:
		rec.gear[str(int(a.actor_id))] = chosen[int(a.actor_id)]
	cache[key] = rec
	return rec


func _run() -> void:
	XMessageBox.auto = true
	XTianqiBase.PHASE4 = true
	XTianqiSkills.MASTERY = true
	XTianqiBrand.ENABLED = brand_pct > 0.0
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	XTianqiGear.clear_effective_cache()
	XEnemy.force_roll = 100.0
	var cache := {}
	if not rebuild and FileAccess.file_exists(gear_file):
		var p = JSON.parse_string(FileAccess.get_file_as_string(gear_file))
		if p is Dictionary:
			cache = p
	# T162（Kyo 11-18）：队伍用配队器——每个职责模板 teams_n 支合理随机队（量中位）＋每个模板一支最强队（量上限）。--shape=old 回到原来的随机 3 强＋1 弱
	var list := []
	if shape_old:
		for team in pick_teams(teams_n, seed_v):
			list.append({"label": "old", "kind": "random", "team": team})
	else:
		for tpl in templates:
			for team in TB.random_teams(tpl, teams_n, seed_v, DIFFICULTY):
				list.append({"label": tpl, "kind": "random", "team": team})
			var best := TB.strongest(tpl, DIFFICULTY)
			if not best.is_empty():
				list.append({"label": tpl, "kind": "strongest", "team": best})
	var rows := []
	for item in list:
		var team: Array = item.team
		var rec := _team_gear(team, cache)
		var row := {"label": item.label, "kind": item.kind, "team": team, "gear_score": float(rec.score), "foes": {}}
		for foes in foes_list:
			var normal := _fight(_state(team, rec.gear), int(foes), false)
			var immune := _fight(_state(team, rec.gear), int(foes), true)
			row.foes[str(foes)] = {"dmg": median(normal.per_turn), "common_hit": median(normal.hits), "dmg_no_crit": median(immune.per_turn), "common_hit_no_crit": median(immune.hits),
				"turns": normal.per_turn, "turns_no_crit": immune.per_turn}
		rows.append(row)
		print("C_TEAM %s" % JSON.stringify(row))
	var summary := {}
	for foes in foes_list:
		var k := str(foes)
		var groups := {"random_all": rows.filter(func(r): return r.kind == "random")}
		for tpl in templates:
			groups["random_" + tpl] = rows.filter(func(r): return r.kind == "random" and r.label == tpl)
			groups["strongest_" + tpl] = rows.filter(func(r): return r.kind == "strongest" and r.label == tpl)
		groups["strongest_all"] = rows.filter(func(r): return r.kind == "strongest")
		summary[k] = {}
		for g in groups:
			var rs: Array = groups[g]
			if rs.is_empty():
				continue
			var pick_max: bool = str(g).begins_with("strongest_all")
			var f := func(key): return rs.map(func(r): return float(r.foes[k][key]))
			summary[k][g] = {"n": rs.size(), "dmg": (f.call("dmg").max() if pick_max else median(f.call("dmg"))), "common_hit": median(f.call("common_hit")),
				"dmg_no_crit": (f.call("dmg_no_crit").max() if pick_max else median(f.call("dmg_no_crit"))), "common_hit_no_crit": median(f.call("common_hit_no_crit"))}
		print("C_SUMMARY foes=%s %s" % [k, JSON.stringify(summary[k])])
	var report := {"difficulty": DIFFICULTY, "floor": FLOOR, "level": LEVEL, "wine": wine, "turns": turns, "seed": seed_v, "teams": rows.size(),
		"k": float(XTianqiBalance.data().get("combat_rules", {}).get("base_damage", 1.0)), "summary": summary, "rows": rows, "team_report": TB.report(DIFFICULTY),
		"brand_pct": brand_pct, "missing": ["词条", "进阶", "熟练度", "号卷／秘籍／黑印"]}
	if out_path != "":
		var fh := FileAccess.open(out_path, FileAccess.WRITE)
		fh.store_string(JSON.stringify(report, "\t"))
	if (rebuild or not FileAccess.file_exists(gear_file)) and gear_file != "":
		var gh := FileAccess.open(gear_file, FileAccess.WRITE)
		if gh != null:
			gh.store_string(JSON.stringify(cache, "\t"))
	XEnemy.force_roll = -1.0
	print("C_TIER_DONE")
	get_tree().quit(0)
