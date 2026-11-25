extends Node
## T481 元素效果 C 卡：人数档与全员重测（设计稿《天启篇_元素独特效果_v0.3》§5.1、§7.1）。不是专项（不在 tests/ 顶层）；单独跑：
##   HOME=<临时目录> 07_开发环境/godot --headless --audio-driver Dummy --path 01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/vp_elem_c.tscn -- --mode=count --out=<json>
var args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	_run.call_deferred()


func arg(k: String, d := "") -> String:
	return str(args.get(k, d))


func _run() -> void:
	XTianqiBase.PHASE4 = false
	var res := {}
	match arg("mode", "count"):
		"count":
			res = _count()
		"solo":
			res = _solo()
		"scan":
			res = _scan()
		"pick3":
			res = _pick3()
		"par":
			_neutral()
			var lg := XBattleLogic.new()
			lg.setup(21, dress_state(2, 60), XBattleRandom.create(_seed_hex(0)))
			var e: XEnemy = lg.enemies[0]
			for add in [0.0, 1.0e3, 1.0e6, 1.0e9, 1.0e12]:
				e.added_params[0] = add
				e.param_mark_dirty()
				print("PAR ", add, " ", e.param(0), " ", e.mhp)
		"one":
			_neutral()
			level = 60
			for hp in [1.0e7]:
				var r := fight(dress_state(int(arg("id", "2")), 60), int(arg("fix", "21")), false, 0, {"turns": 3, "enemy_mhp": hp, "atk_mult": float(arg("atk", "1"))})
				r.erase("stats")
				print("ONE ", hp, " ", JSON.stringify(r))
				var st := dress_state(int(arg("id", "2")), 60)
				var a0 := st.actor(int(arg("id", "2")))
				print("ONEINFO members=", st.battle_members().map(func(x): return x.actor_id), " hp=", a0.hp, "/", a0.mhp, " dead=", a0.is_dead(), " lv=", a0.level)
		"team":
			res = _team()
		"floor":
			res = _floor()
		"immune":
			res = _immune()
		"holy":
			res = _holy()
		"dark":
			res = _dark()
		"mix":
			res = _mix()
		"dark2":
			res = _dark2()
		"fix":
			print(JSON.stringify(_fixture_candidates().slice(0, 12)))
	if arg("out") != "":
		var f := FileAccess.open(arg("out"), FileAccess.WRITE)
		f.store_string(JSON.stringify(res, "\t"))
	print("RESULT_DONE")
	get_tree().quit(0)


static func usable_ids() -> Array:
	var out := []
	for rec in XDB.table("Actors"):
		if rec is Dictionary and str(rec.get("name", "")) != "":
			var id := int(rec.id)
			if not XImportedBalance.is_disabled_actor(id):
				out.append(id)
	out.sort()
	return out


const BASE := [2, 3, 4, 5, 6, 7, 8, 9, 14, 15]


static func dress_state(id: int, lv := 81) -> XState:
	var s := XState.new_game(XTianqi.legacy_of("lianyu"), id, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "lianyu", "lineup": [id]}
	if not s.battle_members().any(func(x): return int(x.actor_id) == id):
		# 新局以他为首位进不了出战栏（强者／超强者等）：用天启篇的入队路径（_joining）加进来再放到第 1 格
		s = XState.new_game(XTianqi.legacy_of("lianyu"), 2, [])
		s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "lianyu", "lineup": [2]}
		XTianqi._joining = true
		s.add_actor(id)
		XTianqi._joining = false
		s.set_battle_slot(0, id)
		for i in range(1, s.battle_slots.size()):
			s.set_battle_slot(i, 0)
	s.actor_max_level = lv
	var a := s.actor(id)
	a.change_level_mv(lv)
	a.recover_all()
	XState.current = s
	return s


## 人数（§5.1）：能打出该系伤害的可用角色。口径 A＝原生（技能卡、被动里天然带该系，不算转换书）；B＝A 再加「装合法转换书后」（有攻击技能的人都能转成任何一系）。
func _count() -> Dictionary:
	var ids := usable_ids()
	var native := {}
	var detail := {}
	var attackers := []
	for id in ids:
		var s := dress_state(int(id))
		var a := s.actor(int(id))
		var deployable := s.battle_members().any(func(x): return int(x.actor_id) == int(id))   # 新局以他为首位建队，他能进出战栏（同 baseline_dps 的筛法）
		var els := {}
		var has_attack := false
		for sk in a.skills():
			if not sk is Dictionary or not int(sk.get("damage", {}).get("type", 0)) in [1, 5]:
				continue
			has_attack = true
			for e in XDamage.action_elements(sk, a):
				if int(e) in BASE:
					els[int(e)] = int(els.get(int(e), 0)) + 1
		if has_attack and deployable:
			attackers.append(int(id))
		var nm := str(XDB.rec("Actors", int(id)).get("name", ""))
		detail[str(id)] = {"name": nm, "elements": els, "attack": has_attack and deployable, "deployable": deployable, "has_attack_skill": has_attack}
		for e in els:
			if not deployable:
				break
			if not native.has(e):
				native[e] = []
			native[e].append(int(id))
	var tiers: Dictionary = XTianqiElements.data().effect_tiers
	var out := {"usable": ids.size(), "attackers": attackers.size(), "native": {}, "detail": detail}
	for e in BASE:
		var n := (native.get(e, []) as Array).size()
		var tier := "few"
		for k in ["many", "mid"]:
			if n >= int(tiers[k].min):
				tier = k
				break
		out.native[str(e)] = {"n": n, "tier": tier, "chance": tiers[tier].chance, "table_tier": str(XTianqiElements.data().effect_tier_of.get(str(e), ""))}
	return out


func _fixture_candidates() -> Array:
	var out := []
	var enemies: Array = XDB.table("Enemies")
	var troops: Array = XDB.table("Troops")
	for i in range(1, troops.size()):
		var t = troops[i]
		if not t is Dictionary or (t.get("members", []) as Array).size() != 1:
			continue
		var eid := int(t.members[0].enemyId)
		if eid <= 0 or XEnemy.boss_id(eid) or XGuardianRework.floor_of(eid) > 0:
			continue
		var r = enemies[eid]
		out.append([i, eid, float(r.params[0]), str(r.get("name", ""))])
	out.sort_custom(func(a, b): return a[2] > b[2])
	return out


# ---- 战斗夹具 ----

var level := 60
var turns := 8
var seeds := 5
var base_seed := 20261125
var fixture_troop := 0
var fixture_hp := 2.0e9


func _neutral() -> void:
	XTianqiNature._enemy = {"special": {"hongjun": {"natures": []}, "knight": {"natures": []}}, "enemies": {}}
	XTianqiNature._enemy_failed = false


func _real_nature() -> void:
	XTianqiNature.reload_table()


func _pick_fixture() -> int:
	if int(arg("fix", "0")) > 0:
		fixture_troop = int(arg("fix", "0"))
	if fixture_troop > 0:
		return fixture_troop
	var troops: Array = XDB.table("Troops")
	for i in range(1, troops.size()):
		var t = troops[i]
		if not t is Dictionary or (t.get("members", []) as Array).size() != 1:
			continue
		var eid := int(t.members[0].enemyId)
		if eid <= 0 or XEnemy.boss_id(eid) or XGuardianRework.floor_of(eid) > 0 or str(XDB.rec("Enemies", eid).get("name", "")) == "":
			continue
		fixture_troop = i
		return i
	return 1


func _seed_hex(i: int) -> String:
	return XRandomStream.hex64(base_seed + i * 7919)


static func _hp_sum(list: Array) -> float:
	var t := 0.0
	for b in list:
		if not (b is XEnemy and b.hidden) and b.is_alive():
			t += maxf(0.0, float(b.hp))
	return t


## 一场：我方打 turns 回合。我方每次出手前补满敌方血（baseline 的 raw 口径），敌方出手前补满我方（不死、只记承伤）。
## 返回：out（我方出手让敌方掉的血）、dot（回合末持续伤害）、inc（敌方出手我方掉的血）、eskip（敌方被元素停手吃掉的行动位）、eact（敌方实际出手次数）、stats
func fight(s: XState, troop: int, on: bool, seed_i: int, opts := {}) -> Dictionary:
	XTianqiElements.EFFECTS = on
	var logic := XBattleLogic.new()
	logic.setup(troop, s, XBattleRandom.create(_seed_hex(seed_i)))
	logic.auto = true
	var hp_target := float(opts.get("enemy_mhp", 0.0))
	for e in logic.enemies:
		if hp_target > 0.0:
			set_param(e, 0, hp_target)
		e.recover_all()
	var rev_e := 0
	var rev_a := 0
	var out := 0.0
	var dot := 0.0
	var inc := 0.0
	var eact := 0
	var aact := 0
	var done := 0
	var blocks := 0
	var dispels := 0
	var refill: bool = bool(opts.get("refill", true))
	for r in int(opts.get("turns", turns)):
		logic.start_turn()
		logic.take_turn_start_logs()
		var guard := 0
		while guard < 80:
			var u := logic.next_subject()
			if u == null:
				break
			guard += 1
			var cmd := logic.decide(u)
			var logs = null
			if u is XActor:
				if refill:
					for e in logic.enemies:
						if e.is_alive():
							e.hp = e.mhp
				var before := _hp_sum(logic.enemies)
				logs = logic.act(u, cmd[0], cmd[1])
				out += maxf(0.0, before - _hp_sum(logic.enemies))
				aact += 1
				if logic.enemies.all(func(e): return e.is_dead() or e.hidden):
					rev_e += 1   # 过杀：一个动作把夹具打死，复活补满继续（这类角色的增益量不出来，单列）
					for e in logic.enemies:
						if e.is_dead():
							e.remove_state(1)
							e.hp = e.mhp
			else:
				if refill:
					for a in logic.actors:
						if a.is_alive():
							a.hp = a.mhp
				var before2 := _hp_sum(logic.actors)
				logs = logic.act(u, cmd[0], cmd[1])
				inc += maxf(0.0, before2 - _hp_sum(logic.actors))
				eact += 1
				if logic.actors.all(func(a): return a.is_dead()):
					rev_a += 1
					for a in logic.actors:
						a.remove_state(1)
						a.hp = a.mhp
			if on and logs != null:
				var txt := JSON.stringify(logs)
				blocks += txt.count("圣护抵挡了")
				dispels += txt.count("净化了")
			if logic.is_over():
				break
		if logic.is_over():
			break
		var eb := _hp_sum(logic.enemies)
		var ab := _hp_sum(logic.actors)
		logic.end_turn()
		dot += maxf(0.0, eb - _hp_sum(logic.enemies))
		inc += maxf(0.0, ab - _hp_sum(logic.actors))
		done += 1
	var eskip := 0
	for e in logic.enemies:
		eskip += XTianqiElementEffects.skip_count(logic, e)
	var askip := 0
	for a in logic.actors:
		askip += XTianqiElementEffects.skip_count(logic, a)
	var res := {"out": out, "dot": dot, "inc": inc, "eskip": eskip, "askip": askip, "blocks": blocks, "dispels": dispels, "max_frozen": _max_frozen(logic), "rev_e": rev_e, "rev_a": rev_a, "eact": eact, "aact": aact, "turns": done,
		"won": logic.is_won(), "lost": logic.is_lost(), "stats": XTianqiElementEffects.stats(logic).duplicate(true),
		"ehp_left": _hp_sum(logic.enemies), "ehp_max": float(logic.enemies.map(func(e): return e.mhp).reduce(func(x, y): return x + y, 0.0))}
	logic.end_battle(0)
	return res



static func _max_frozen(logic) -> int:
	var m := 0
	if logic.has_meta(XTianqiElementEffects.META):
		for b in logic.get_meta(XTianqiElementEffects.META).units:
			m = maxi(m, int(logic.get_meta(XTianqiElementEffects.META).units[b].get("frozen", 0)))
	return m


static func base_param(e: XEnemy, i: int) -> float:
	var keep: float = float(e.added_params.get(i, 0.0))
	e.added_params[i] = 0.0
	e.param_mark_dirty()
	var v := float(e.param(i))
	e.added_params[i] = keep
	e.param_mark_dirty()
	return v


## 敌人第 i 项能力值加上 add（必须在这个敌人第一次读能力值之前设，读过一次就缓存了；最终值约 200 倍，难度倍率）
static func set_param(e: XEnemy, i: int, add: float) -> void:
	e.added_params[i] = add
	e.param_mark_dirty()


## 夹具校准：敌人总血量＝我方每回合出伤的 mult 倍；敌人攻击（物攻、魔攻同乘）让敌人每次出手打掉我方平均血量的 want_pct
## 返回 {"enemy_mhp", "atk_mult"}（关效果、seed 0 量；不改游戏数据）
func calib(mk: Callable, troop: int, _mult := 10.0, _want := 0.0) -> Dictionary:
	# 先用很大的血量（2e13）关效果打 3 回合量每回合出伤 d，再把敌人血量定成 d 的约 10 倍（避免一个动作打死；added_params 最终约 190 倍）
	var r := fight(mk.call(), troop, false, 0, {"turns": 3, "enemy_mhp": 1.0e11})
	var d := float(r.out) / 3.0
	return {"enemy_mhp": clampf(d * 10.0 / 190.0, 1.0e4, 1.0e11), "atk_mult": 1.0}


func neutral_state_for(ids: Array, lv: int) -> XState:
	var s := XState.new_game(XTianqi.legacy_of("lianyu"), 2, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "lianyu", "lineup": ids.duplicate()}
	for id in ids:
		if int(id) != 2:
			XTianqi._joining = true
			s.add_actor(int(id))
			XTianqi._joining = false
	for i in s.battle_slots.size():
		s.set_battle_slot(i, int(ids[i]) if i < ids.size() else 0)
	s.actor_max_level = lv
	for id in ids:
		var a := s.actor(int(id))
		a.change_level_mv(lv)
		a.recover_all()
	XState.current = s
	return s


const CONV_SKILL := {2: 5068, 3: 5069, 4: 5070, 5: 5071, 6: 5072, 7: 5073, 8: 5074, 9: 5075, 14: 11201, 15: 11202, 11: 11203, 12: 11204, 13: 11205}


func convert_all(s: XState, elem: int) -> void:
	for a in s.battle_members():
		a.learn_skill(int(CONV_SKILL[elem]))
		a.read_touch()
		a.refresh_passive()


func attack_elems(a: XActor) -> Array:
	var out := []
	for sk in a.skills():
		if sk is Dictionary and int(sk.get("damage", {}).get("type", 0)) in [1, 5]:
			for e in XDamage.action_elements(sk, a):
				if not out.has(int(e)):
					out.append(int(e))
	out.sort()
	return out


# ---- 场景 1：单人 ----

func _solo() -> Dictionary:
	level = int(arg("level", "60"))
	seeds = int(arg("seeds", "5"))
	turns = int(arg("turns", "8"))
	var shard := arg("shard", "0/1").split("/")
	var si_ := int(shard[0])
	var sn := int(shard[1])
	var count: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arg("count")))
	var only := arg("ids", "")
	var ids := []
	for k in count.detail:
		if count.detail[k].attack:
			ids.append(int(k))
	ids.sort()
	if only != "":
		ids = Array(only.split(",")).map(func(x): return int(x))
	var rows := []
	var tr := _pick_fixture()
	_neutral()
	var bi := 0
	for idx in ids.size():
		if idx % sn != si_:
			continue
		var id: int = ids[idx]
		var d: Dictionary = count.detail.get(str(id), {})
		var native: Array = (d.get("elements", {}) as Dictionary).keys().map(func(x): return int(x))
		var builds := ["native"]
		if native.is_empty():
			builds.append("book")
		for build in builds:
			var elem := 0
			if build == "book":
				elem = XTianqiElements.BASE_ELEMENTS[(idx + bi) % 10]
				bi += 1
			var mk := func() -> XState:
				var s := dress_state(id, level)
				if elem > 0:
					convert_all(s, elem)
				return s
			var cal := calib(mk, tr)
			var tgt := float(cal.enemy_mhp)
			var runs := []
			for si in seeds:
				for on in [false, true]:
					var r := fight(mk.call(), tr, on, id * 100 + si, {"enemy_mhp": tgt, "atk_mult": cal.atk_mult, "turns": turns})   # 种子随角色错开：同一个种子序列对所有人一样时，前几次掷点同生同灭
					r["seed"] = si
					r["on"] = on
					runs.append(r)
			var conv_ok := true
			if elem > 0:
				conv_ok = attack_elems(dress_state_conv(id, elem)).has(elem)
			rows.append({"id": id, "name": str(d.get("name", "")), "build": build, "elem": elem, "native": native, "natures": actor_natures(id),
				"conv_ok": conv_ok, "mhp": tgt, "atk_mult": cal.atk_mult, "runs": runs})
			print("solo ", id, " ", build, " ", elem)
	return {"rows": rows, "level": level, "turns": turns, "seeds": seeds, "troop": tr}


func dress_state_conv(id: int, elem: int) -> XActor:
	var s := dress_state(id, level)
	convert_all(s, elem)
	return s.actor(id)


func actor_natures(id: int) -> Array:
	return XTianqiNature.actor_table().get("actors", {}).get(str(id), {}).get("natures", [])


## 找夹具敌人：单敌非首领的敌群里，对几个参照角色（60 级）每次出手打掉我方血量 8%～20% 的
func _scan() -> Dictionary:
	level = int(arg("level", "60"))
	_neutral()
	var refs := [2, 3, 28, 1]
	var troops: Array = XDB.table("Troops")
	var rows := []
	var seen := {}
	for i in range(1, troops.size()):
		var t = troops[i]
		if not t is Dictionary or (t.get("members", []) as Array).size() != int(arg("size", "1")):
			continue
		var eid := int(t.members[0].enemyId)
		if eid <= 0 or seen.has(eid) or XEnemy.boss_id(eid) or XGuardianRework.floor_of(eid) > 0 or str(XDB.rec("Enemies", eid).get("name", "")) == "":
			continue
		seen[eid] = true
		var pers := []
		for id in refs:
			var s := dress_state(id, level)
			var r := fight(s, i, false, 0, {"turns": 2, "enemy_mhp": 1.0e7})
			pers.append(snappedf(float(r.inc) / maxf(1.0, float(r.eact)) / float(s.actor(id).mhp), 0.001))
		rows.append({"troop": i, "enemy": eid, "name": str(XDB.rec("Enemies", eid).get("name", "")), "per": pers})
	return {"rows": rows}


# ---- 场景 3、3b、5、圣护、暗补偿 ----

func _count_json() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(arg("count")))


func _natives_of(count: Dictionary, elem: int) -> Array:
	var out := []
	for k in count.detail:
		if (count.detail[k].elements as Dictionary).has(str(elem)) or (count.detail[k].elements as Dictionary).has(elem):
			out.append(int(k))
	out.sort()
	return out


func _pick4(pool: Array, seed_i: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed + seed_i * 31
	var bag := pool.duplicate()
	var out := []
	while out.size() < 4 and not bag.is_empty():
		out.append(bag.pop_at(rng.randi_range(0, bag.size() - 1)))
	return out


## 一支队、一个敌群，开／关各 5 种子；敌人总血量按这支队关效果出伤校准，不动攻击
func run_team(ids: Array, troop: int, opts := {}) -> Dictionary:
	var lv := int(opts.get("level", level))
	var mk := func() -> XState:
		var s := neutral_state_for(ids, lv)
		if bool(opts.get("deck", false)):
			XTianqiElements.ensure_deck(s, 66223)
		if opts.has("convert"):
			for a in s.battle_members():
				var el: int = int(opts.convert.get(int(a.actor_id), 0))
				if el > 0:
					a.learn_skill(int(CONV_SKILL[el]))
					a.read_touch()
					a.refresh_passive()
		return s
	var fo := {"turns": int(opts.get("turns", 12)), "refill": bool(opts.get("refill", true)), "atk_mult": float(arg("atk", "1"))}
	if bool(opts.get("calib", true)):
		fo["enemy_mhp"] = _calib_hp(mk, troop)
	var runs := []
	for si in seeds:
		for on in [false, true]:
			var r := fight(mk.call(), troop, on, si, fo)
			r["seed"] = si
			r["on"] = on
			runs.append(r)
	return {"ids": ids, "runs": runs}


func _calib_hp(mk: Callable, troop: int) -> float:
	return float(calib(mk, troop).enemy_mhp)


## 场景 3：每系单系队（该系原生的角色里抽 4 人，不足 4 人全上）＋ 5 支混搭队，打 3 只普通怪 12 回合
func _team() -> Dictionary:
	level = int(arg("level", "60"))
	seeds = int(arg("seeds", "5"))
	var count := _count_json()
	var troop := int(arg("troop", "0"))
	_neutral()
	var rows := []
	for e in XTianqiElements.BASE_ELEMENTS:
		var pool := _natives_of(count, e)
		if pool.is_empty():
			continue
		var ids := _pick4(pool, 1)
		var r := run_team(ids, troop)
		r["kind"] = "single"
		r["elem"] = e
		rows.append(r)
		print("team single ", e, " ", ids)
	var attackers := []
	for k in count.detail:
		if count.detail[k].attack:
			attackers.append(int(k))
	attackers.sort()
	for m in 5:
		var ids2 := _pick4(attackers, 100 + m)
		var r2 := run_team(ids2, troop)
		r2["kind"] = "mixed"
		r2["elem"] = 0
		rows.append(r2)
		print("team mixed ", ids2)
	return {"rows": rows, "troop": troop, "level": level}


const LEVEL_CAP := [[1, 10], [5, 15], [6, 20], [8, 25], [10, 30], [12, 33], [13, 35], [14, 38], [15, 40], [16, 43], [17, 45], [18, 48], [19, 50], [21, 55], [23, 60], [25, 65], [29, 75], [31, 80], [36, 81]]


static func level_cap(f: int) -> int:
	var cap := 10
	for row in LEVEL_CAP:
		if f >= int(row[0]):
			cap = int(row[1])
	return cap


func _attackers(count: Dictionary) -> Array:
	var out := []
	for k in count.detail:
		if count.detail[k].attack:
			out.append(int(k))
	out.sort()
	return out


## 场景 5：标准队（弱者 4 人，两支）打 6、13、20、28、33 层守层者，真体质＋首领固定阶段，不补血，12 回合，开／关各 5 种子
func _floor() -> Dictionary:
	seeds = int(arg("seeds", "5"))
	var count := _count_json()
	var weak := XTier.ids(XTier.WEAK).filter(func(id): return count.detail.has(str(id)) and count.detail[str(id)].attack)
	var floors := Array(arg("floors", "6,13,20,28,33").split(",")).map(func(x): return int(x))
	var rows := []
	_real_nature()
	for ti in 2:
		var team := _pick4(weak, 500 + ti)
		for f in floors:
			var troop := int(XGuardianRework.TROOPS[f])
			var r := run_team(team, troop, {"level": level_cap(f), "turns": 12, "refill": arg("refill", "0") == "1", "calib": false, "deck": true})
			r["floor"] = f
			r["team_i"] = ti
			rows.append(r)
			print("floor ", f, " team ", ti)
	return {"rows": rows, "refill": arg("refill", "0") == "1"}


## 场景 3b：合法混搭队（2 个装高等转换书＋2 个基础原生）对同规模纯基础队（2 个同一批基础原生＋2 个别的基础原生），打 13 层守层者，不补血
func _mix() -> Dictionary:
	seeds = int(arg("seeds", "5"))
	var count := _count_json()
	var base_natives := []
	for e in XTianqiElements.BASE_ELEMENTS:
		base_natives.append_array(_natives_of(count, e))
	var pool := []
	for id in base_natives:
		if not pool.has(id):
			pool.append(id)
	pool.sort()
	var f := int(arg("floor", "13"))
	var troop := int(XGuardianRework.TROOPS[f])
	_real_nature()
	var rows := []
	for ti in 4:
		var four := _pick4(pool, 700 + ti)
		var conv := {int(four[0]): 11, int(four[1]): 12}
		var mixed := run_team(four, troop, {"level": level_cap(f), "turns": 12, "refill": arg("refill", "0") == "1", "calib": false, "deck": true, "convert": conv})
		mixed["kind"] = "mixed_higher"
		mixed["team_i"] = ti
		rows.append(mixed)
		var pure := run_team(four, troop, {"level": level_cap(f), "turns": 12, "refill": arg("refill", "0") == "1", "calib": false, "deck": true})
		pure["kind"] = "pure_base"
		pure["team_i"] = ti
		rows.append(pure)
		print("mix ", ti, " ", four)
	return {"rows": rows, "floor": f, "refill": arg("refill", "0") == "1"}


## 场景 6：每系被挡比例（普通敌人按各图遇敌权重，首领＝33 个守层者），读体质表＋种族
func _immune() -> Dictionary:
	var imm: Dictionary = XTianqiElements.data().effect_immunity
	var weights := {}
	for map_id in range(1, 400):
		var m := XDB.map(map_id)
		if m.is_empty():
			continue
		for e in m.get("encounterList", []):
			if e is Dictionary and int(e.get("troopId", 0)) > 0 and int(e.get("weight", 0)) > 0:
				var tr = XDB.table("Troops")[int(e.troopId)]
				var members: Array = tr.get("members", [])
				for mem in members:
					var eid := int(mem.enemyId)
					weights[eid] = float(weights.get(eid, 0.0)) + float(e.weight) / maxf(1.0, float(members.size()))
	var blocked := {}
	var total := 0.0
	var nat_hist := {}
	for eid in weights:
		if XEnemy.boss_id(int(eid)):
			continue
		var en := XEnemy.new()
		en.setup(int(eid), 3)
		total += float(weights[eid])
		for e in XTianqiElements.BASE_ELEMENTS:
			if e != 8 and e != 14 and not imm.has(str(e)):
				continue
			if imm.has(str(e)) and _blocked(en, imm[str(e)]):
				blocked[e] = float(blocked.get(e, 0.0)) + float(weights[eid])
		for n in XTianqiNature.of(en):
			nat_hist[str(n)] = float(nat_hist.get(str(n), 0.0)) + float(weights[eid])
	var boss_blocked := {}
	var boss_n := 0
	var boss_rows := []
	for f in XGuardianRework.TROOPS:
		var tr2 = XDB.table("Troops")[int(XGuardianRework.TROOPS[f])]
		var en2 := XEnemy.new()
		en2.setup(int(tr2.members[0].enemyId), 3)
		boss_n += 1
		var hit := []
		for e in XTianqiElements.BASE_ELEMENTS:
			if imm.has(str(e)) and _blocked(en2, imm[str(e)]):
				boss_blocked[e] = int(boss_blocked.get(e, 0)) + 1
				hit.append(e)
		boss_rows.append({"floor": int(f), "natures": XTianqiNature.of(en2), "blocked_elems": hit})
	var out := {"normal_total_weight": total, "normal": {}, "boss_n": boss_n, "boss": {}, "boss_rows": boss_rows, "nature_weight": nat_hist}
	for e in XTianqiElements.BASE_ELEMENTS:
		out.normal[str(e)] = snappedf(float(blocked.get(e, 0.0)) / maxf(1.0, total), 0.0001)
		out.boss[str(e)] = snappedf(float(boss_blocked.get(e, 0)) / maxf(1.0, float(boss_n)), 0.0001)
	return out


static func _blocked(t, rule: Dictionary) -> bool:
	var natures := XTianqiNature.of(t)
	for c in rule.get("constitution", []):
		if natures.has(int(c)):
			return true
	var races := XTianqiNature.races(t)
	for rc in rule.get("race", []):
		if races.has(int(rc)):
			return true
	return false


## 神圣：群体圣护给每个目标；几率 15%（中档）对 11%（降一档，现表）各量一遍。队伍＝3 个有神圣己方技的角色＋1 个输出，打 13 层守层者与普通敌群，补血口径同场景 3
func _holy() -> Dictionary:
	seeds = int(arg("seeds", "5"))
	level = int(arg("level", "60"))
	var count := _count_json()
	var healers := []
	for k in count.detail:
		var id := int(k)
		var s0 := dress_state(id, level)
		var a := s0.actor(id)
		for sk in a.skills():
			if sk is Dictionary and XTianqiElementEffects.holy_ally_skill(sk):
				healers.append(id)
				break
	healers.sort()
	var attackers := _attackers(count).filter(func(id): return not healers.has(id))
	var rows := []
	var troop := int(arg("troop", "0"))
	_real_nature()
	for variant in ["mid_15", "many_11"]:
		for ti in 6:
			var team := _pick4(healers, 900 + ti).slice(0, 3) + _pick4(attackers, 950 + ti).slice(0, 1)
			XTianqiElements.reload_table()
			XTianqiElements.data().effect_tier_of["8"] = "mid" if variant == "mid_15" else "many"
			var r := run_team(team, troop, {"level": level, "turns": 12, "refill": true})
			r["variant"] = variant
			r["team_i"] = ti
			rows.append(r)
			print("holy ", variant, " ", team)
	XTianqiElements.reload_table()
	return {"healers": healers, "rows": rows}


## 暗：首领线遮蔽锋芒补偿前后（boss_chance_rate 0.5 → 1.0）。四个暗原生角色打 5 个守层者，真体质，补血口径
func _dark() -> Dictionary:
	seeds = int(arg("seeds", "5"))
	var count := _count_json()
	var dark := _natives_of(count, 9)
	var floors := Array(arg("floors", "6,13,20,28,33").split(",")).map(func(x): return int(x))
	var rows := []
	_real_nature()
	for variant in ["before_0.5", "after_1.0"]:
		for f in floors:
			var team := _pick4(dark, 3)
			XTianqiElements.reload_table()
			XTianqiElements.data().effect_rules["boss_chance_rate"] = 0.5 if variant == "before_0.5" else 1.0
			var r := run_team(team, int(XGuardianRework.TROOPS[f]), {"level": level_cap(f), "turns": 12, "refill": true, "calib": false, "deck": true})
			r["variant"] = variant
			r["floor"] = f
			rows.append(r)
			print("dark ", variant, " ", f)
	XTianqiElements.reload_table()
	return {"rows": rows}


## 找三只普通怪的夹具敌群：成员都不是首领，对 60 级参照角色每次出手打掉 5%～30%，取前 3 个
func _pick3() -> Dictionary:
	_neutral()
	var troops: Array = XDB.table("Troops")
	var out := []
	for i in range(1, troops.size()):
		var t = troops[i]
		if not t is Dictionary or (t.get("members", []) as Array).size() != 3:
			continue
		var ok := true
		for m in t.members:
			var eid := int(m.enemyId)
			if eid <= 0 or XEnemy.boss_id(eid) or XGuardianRework.floor_of(eid) > 0:
				ok = false
		if not ok:
			continue
		var s := dress_state(2, 60)
		var r := fight(s, i, false, 0, {"turns": 2, "enemy_mhp": 1.0e7})
		var per := float(r.inc) / maxf(1.0, float(r.eact)) / float(s.actor(2).mhp)
		if per >= 0.05 and per <= 0.3 and r.eact >= 4:
			out.append({"troop": i, "per": per, "eact": r.eact})
			if out.size() >= 3:
				break
	return {"rows": out}


func _stub(id: int, elem: int, formula := "1000") -> Dictionary:
	var val := float(formula)
	var prog := {"version": 1, "status": "pure", "locals": ["value"], "source": {"sha256": "t481_%d" % id},
		"steps": [{"op": "set", "name": "value", "value": {"op": "literal", "value": val}}], "result": "value"}
	return {"id": id, "name": "T481_%d" % id, "scope": 1, "hitType": 2, "stypeId": 1, "mpCost": 0, "tpCost": 0, "effects": [], "note": "", "meta": {},
		"damage": {"type": 1, "elementId": elem, "critical": false, "variance": 0, "formula": formula, "formulaProgram": prog}}


## 暗·首领档直接量：33 个守层者各开 rolls 场新战斗，每场用一个暗元素伤害招打首领一下，看遮蔽锋芒的有资格／被体质挡／挂上。
## boss_chance_rate 0.5（补偿前）对 1.0（补偿后，首领暗系几率 7.5%→15%）。同一批种子配对。
func _dark2() -> Dictionary:
	var rolls := int(arg("rolls", "20"))
	_real_nature()
	XTianqiElements.EFFECTS = true
	var rows := []
	for variant in ["before_0.5", "after_1.0"]:
		XTianqiElements.reload_table()
		XTianqiElements.data().effect_rules["boss_chance_rate"] = 0.5 if variant == "before_0.5" else 1.0
		for f in range(1, 34):
			var s := neutral_state_for([2], level_cap(f))
			XTianqiElements.ensure_deck(s, 66223)
			var tot := {"eligible": 0, "immune": 0, "blocked": 0, "rolled": 0, "applied": 0}
			for k in rolls:
				var lg := XBattleLogic.new()
				lg.setup(int(XGuardianRework.TROOPS[f]), s, XBattleRandom.create(_seed_hex(f * 1000 + k)))
				var a: XActor = s.battle_members()[0]
				var t: XEnemy = lg.enemies[0]
				t.recover_all()
				t.hp = t.mhp
				XTianqiElementEffects.frame_begin(lg, a)
				lg.apply(a, _stub(98481, 9, "2000000"), t)
				XTianqiElementEffects.frame_end(lg, a)
				var st: Dictionary = XTianqiElementEffects.stats(lg).get("9", {})
				for kk in tot:
					tot[kk] += int(st.get(kk, 0))
				lg.end_battle(0)
			tot["floor"] = f
			tot["variant"] = variant
			rows.append(tot)
			print("dark2 ", variant, " ", f, " ", tot)
	XTianqiElements.reload_table()
	return {"rows": rows, "rolls": rolls}
