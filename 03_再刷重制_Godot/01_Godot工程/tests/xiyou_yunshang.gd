extends Node
## 【cc·白龙_9·未经审查】174 云裳第一期（XYunshang：sync／param／passive_cache／formula／damage_ops／sure／cri／repeats／targets／meets，招募）：
## 与 mv_oracle/yunshang_probe.cjs 的冻结 v0.28 参照（tests/fixtures/yunshang_oracle.json）逐例比。
## - skills.*／relic.*：新建角色写进阶次数后升到各级（含 35→20 降级）的专属技能、八项能力值、被动缓存的暴伤／终伤（戴织神天梭终伤 +3）；
## - formula：五个伤害技能与御风在目标魔防 19／37519 下的公式值（战斗外，1e-9 相对误差）；
## - recruit：入队、背包一件织神天梭、第二次不再给；
## - battle.*：钉影、拆神、普通攻击各打一次——每段的技能、目标、暴击逐条比（必中、戴织神天梭必暴击、双针两段、云丝展幅打全体），
##   每段伤害比绝对值（双针 ×0.555、展幅非主目标 ×0.5／0.66／0.77、织神天梭结算 ×1.99 与暴伤、魔法路线对物防 +5000 的敌人；
##   参照关了五乘区 CodexZones（重制不移植，O-050），之前按比值比是因为没关；伤害是整数，容差 1）；
##   每步后六个技能能不能用（没解锁、冷却、敕衣点神要有人穿天衣、收针要有人觉醒、被动不能用）。
## - p2.*（第二期 A 批，参照 battle2：开战＋第一回合，只给敌人加生命）：觉醒（敕衣点神、天衣无缝、神纹自鸣随机唤醒、到期）、收针（按所选觉醒者剩余回合、消耗觉醒）、
##   余辉、符针（千丝成阵种针、敌人行动前全部引爆、钉影虚弱 ×0.67、觉醒伤害引爆一根）、御风（敏捷 ×1.33）、赠行（每回合 3 次、觉醒免费赠 2）、
##   储行（收存、放行、觉醒每回合加份、放行翻倍）、六衡裁身、万法同裳（双攻取高、物魔两路）、七曜流霞（元素）；每步比回合、觉醒、战斗数据、
##   行动来源标签、队列里 174 与 1 号的行动数（比开局的增减）、余辉，以及各例的能力值、敏捷、符针数、能不能用；角色出手的伤害比绝对值。
const FIXTURE := "res://tests/fixtures/yunshang_oracle.json"
const DAMAGE_TOLERANCE := 1.0  # 伤害是整数，两边各自取整
const MEETS := [10270, 10271, 10272, 10273, 10274, 10277]
var results := []


## 规则流全取 0.5；整数照 Math.randomInt 取中点（同 xiyou_jingliu）
class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648
	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return floori(n * value) if n > 0 else 0
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return lo + floori((hi - lo + 1) * value)


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _ints(v) -> Array:
	return (v as Array).map(func(x): return int(x))


func _new_game() -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	return s


func _skills(a: XActor) -> Array:
	var out := a.skill_ids.filter(func(i): return i >= 10270 and i <= 10287)
	out.sort()
	return out


func _params(a: XActor) -> Array:
	return range(8).map(func(i): return a.param(i))


## 同参照 grow()：写进阶次数，再升到 level 级
func _grow(s: XState, level: int, stage: int) -> XActor:
	s.actor_advance[XYunshang.ACTOR] = stage
	var a := s.actor(XYunshang.ACTOR)
	a.change_level_mv(level)
	return a


func _wear_relic(s: XState, a: XActor) -> void:
	s.gain_gear("armor", XYunshang.RELIC, 1)
	XEquipment.change(s, a, a.equip_slots().find(int(XDB.rec("Armors", XYunshang.RELIC).etypeId)), s.gear[s.gear.size() - 1])


func _relics(s: XState) -> int:
	return s.gear.filter(func(e): return e.kind == "armor" and int(e.base) == XYunshang.RELIC).size()


func _cache(a: XActor) -> Array:
	a.refresh_passive()
	var c := a.passive_cache()
	return [float(c.get("critHarmRi", 0.0)), float(c.get("globalHarmRi", 0.0))]


func _close(x: float, y: float) -> bool:
	return absf(x - y) <= 1e-9 * maxf(1.0, absf(y))


func _skills_case(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_game()
	var a: XActor
	if c.id == "skills.down":
		a = _grow(s, int(c.setup.from), int(c.setup.stage))
		a.change_level_mv(int(c.setup.level))
	else:
		a = _grow(s, int(c.setup.level), int(c.setup.stage))
	if str(c.id).begins_with("relic"):
		_wear_relic(s, a)
	check(c.id + ".skills", _skills(a) == _ints(o.skills), [_skills(a), o.skills])
	check(c.id + ".params", _params(a) == (o.params as Array).map(func(v): return float(v)), [_params(a), o.params])
	var got := _cache(a)
	check(c.id + ".cache", _close(got[0], float(o.cache.crit)) and _close(got[1], float(o.cache.final)), [got, o.cache])


func _formula(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_game()
	var a := _grow(s, int(c.setup.level), int(c.setup.stage))
	check("formula.params", [a.mat, a.def, a.mdf] == [float(o.mat), float(o.def), float(o.mdf)], [a.mat, a.def, a.mdf, o])
	var bad := 0
	for row in o.rows:
		var v := XYunshang.formula(a, {"mdf": float(row.mdf)}, XDB.rec("Skills", int(row.id)), false)  # 参照在伤害计算外调，防取目标魔防
		if not _close(v, float(row.value)):
			bad += 1
			if bad <= 3:
				check("formula.%d.%d" % [int(row.id), int(row.mdf)], false, [v, row.value])
	check("formula.rows", bad == 0 and (o.rows as Array).size() == 12, [bad, (o.rows as Array).size()])
	check("formula.calculating", XYunshang.formula(a, {"mdf": 37519.0}, XDB.rec("Skills", 10270)) == 66.66 * a.mat)


func _recruit(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_game()
	s.switches[2494] = true  # 同参照：超强者门槛在公共事件那一层（mv_script 的 _recruit_blocked）
	XYunshang.recruit(s)
	var a := s.actor(XYunshang.ACTOR)
	var worn := a.equip_list().map(func(e): return int(e.get("base", 0)))
	check("recruit.first", [s.party.has(XYunshang.ACTOR), _relics(s), worn] == [true, int(o.first.relics), _ints(o.first.worn)], [s.party, _relics(s), worn, o.first])
	XYunshang.recruit(s)
	check("recruit.again", [s.party.has(XYunshang.ACTOR), _relics(s)] == [true, int(o.again.relics)], [s.party, _relics(s), o.again])
	check("recruit.skills", _skills(a) == _ints(o.skills), [_skills(a), o.skills])


## 同参照 battle()：挑战开关 2494、level 级 stage 进阶、队伍 174、1、8、9、10，可选戴织神天梭；全队与敌群 3 生命加 1e12、敌人物防 +5000
func _battle(level: int, stage: int, relic: bool) -> Array:
	var s := _new_game()
	s.switches[2494] = true
	var a := _grow(s, level, stage)
	s.party.clear()
	s.battle_slots.clear()
	for id in [XYunshang.ACTOR, 1, 8, 9, 10]:
		s.add_actor(id)
	if relic:
		_wear_relic(s, a)
	for id in s.party:
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
	var rand := XBattleRandom.create("0000000000000174")
	rand.rule = FixedStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		p[3] += 5000
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	logic.start_turn()
	return [logic, a]


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _snap(logic: XBattleLogic, a: XActor) -> Dictionary:
	a.mp = a.mmp
	a.tp = a.max_tp()
	return {"meets": MEETS.map(func(id): return logic.can_use(a, XDB.rec("Skills", id)))}


func _cast(logic: XBattleLogic, a: XActor, id: int, target: int) -> Dictionary:
	a.mp = a.mmp
	a.tp = a.max_tp()
	a.cooldowns.clear()  # 参照 clearCooldowns
	var logs := logic.act(a, XDB.rec("Skills", id), logic.enemies[target])
	var hits := []
	for l in logs:
		if l.get("type") == "hit" and l.get("user") == a and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)):
			hits.append({"skill": int(l.skill.id), "target": _key(logic, l.target), "value": float(l.hp), "critical": bool(l.critical)})
	return _snap(logic, a).merged({"cast": id, "log": hits}, true)


func _battle_case(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var level := int(c.setup.level)
	var r := _battle(level, int(c.setup.stage), bool(c.setup.relic))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	check(c.id + ".party", logic.actors.map(func(b): return int(b.actor_id)) == _ints(o.party), [logic.actors.map(func(b): return b.actor_id), o.party])
	check(c.id + ".skills", _skills(a) == _ints(o.skills), [_skills(a), o.skills])
	var steps := [_snap(logic, a)]
	steps.append(_cast(logic, a, 10270, 1))
	if level >= 10:
		steps.append(_cast(logic, a, 10271, 0))
	steps.append(_cast(logic, a, 1, 2))
	logic.end_battle(0)
	check(c.id + ".steps", steps.size() == (o.steps as Array).size(), [steps.size(), (o.steps as Array).size()])
	for i in mini(steps.size(), (o.steps as Array).size()):
		var g: Dictionary = steps[i]
		var w: Dictionary = o.steps[i]
		var sid := "%s.%d" % [c.id, i]
		check(sid + ".meets", g.meets == (w.meets as Array).map(func(v): return bool(v)), [g.meets, w.meets])
		if not w.has("log"):
			continue
		var gl: Array = g.log
		var wl: Array = w.log
		var gs := gl.map(func(l): return [l.skill, l.target, l.critical])
		var ws := wl.map(func(l): return [int(l.skill), str(l.target), bool(l.critical)])
		check(sid + ".log", gs == ws, [gs, ws])
		if gs != ws:
			continue
		for k in gs.size():
			check("%s.abs%d" % [sid, k], absf(float(gl[k].value) - float(wl[k].value)) <= DAMAGE_TOLERANCE, [gl[k].value, wl[k].value])


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	check("slice_has_174", not XDB.rec("Actors", XYunshang.ACTOR).is_empty())
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match kind:
			"skills", "relic":
				_skills_case(c)
			"formula":
				_formula(c)
			"recruit":
				_recruit(c)
			"battle":
				_battle_case(c)
			"p2":
				_p2_case(c)
			"p3":
				_p3_case(c)
			"p4":
				_p4_case(c)
			"p5":
				_p5_case(c)
			"p6", "p7", "p8", "p9":
				pass  # 战斗指令窗 xiyou_yunshang_ui、天衣铺一二期与显示 xiyou_yunshang_shop 比
	check("covers_all", seen.keys().size() == 13, seen.keys())
	_copy_turns()
	finish()


## O-135：stateCopy 的来源身上没有这个状态、又没给回合数时（一身两世复演复制技能附加的状态），默认保留附加时掷出的回合数，
## 回退（o_copy_turns = false）照原版写成永不到期
func _copy_turns() -> void:
	for keep in [true, false]:
		var r := _battle(20, 0, false)
		var logic: XBattleLogic = r[0]
		var a: XActor = r[1]
		var foe = logic.enemies[0]
		if keep:
			XYunshang.o_copy_turns = true
		else:
			XYunshang.o_copy_turns = false
		var id := -1
		for sid in XYunshang.TRANSFER_DEBUFFS:
			if not a.state_ids.has(int(sid)) and XYunshang.state_copy(logic, a, foe, int(sid)):
				id = int(sid)
				break
		check("copy_turns.%s.added" % keep, id > 0)
		if id > 0:
			var turns := int(foe.state_turns.get(id, -1))
			if keep:
				check("copy_turns.true", turns > 0 and turns < XYunshang.NEVER_EXPIRES, turns)
			else:
				check("copy_turns.false", turns == XYunshang.NEVER_EXPIRES, turns)
		logic.end_battle(-1)
	XYunshang.o_copy_turns = true



# ---- 第二期 A 批（p2.*，参照 battle2）----
func _wear_robe(s: XState, a: XActor, k: int) -> void:
	s.gain_gear("armor", XYunshang.ROBE_FIRST + k, 1)
	XEquipment.change(s, a, a.equip_slots().find(4), s.gear[s.gear.size() - 1])


## 同参照 battle2()：挑战开关、云裳 level 级 stage 进阶（可戴织神天梭、天衣），1 号 55 级（可穿天衣）；队伍 174、1、8、9、10；只给敌人加生命；开战再开第一回合
func _battle2(o: Dictionary) -> Array:
	var s := _new_game()
	s.switches[2494] = true
	var a := _grow(s, int(o.level), int(o.stage))
	s.party.clear()
	s.battle_slots.clear()
	for id in [XYunshang.ACTOR, 1, 8, 9, 10]:
		s.add_actor(id)
	var ally := s.actor(1)
	ally.change_level_mv(55)
	if bool(o.get("relic", false)):
		_wear_relic(s, a)
	if o.get("robe") != null:
		_wear_robe(s, a, int(o.robe))
	if o.get("allyRobe") != null:
		_wear_robe(s, ally, int(o.allyRobe))
	var rand := XBattleRandom.create("0000000000000174")
	rand.rule = FixedStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		p[2] += float(o.get("foeAtk", 0))
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	if o.has("allyHp"):
		ally.add_param(0, float(o.allyHp))
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	_turn(logic)
	return [logic, a, ally]


## 参照 bm.startTurn()：OTB 开回合时最快的行动者（174）已取走，不在 _actionBattlers 里；重制照样取一次
func _turn(logic: XBattleLogic) -> void:
	logic.start_turn()
	logic.next_subject()


func _yd(b) -> Variant:
	var d := XYunshang.data(b)
	return null if d.is_empty() else [int(d.key), int(d.wake_until), int(d.stored), int(d.gifts)]


func _ys(logic: XBattleLogic, a: XActor, ally: XActor) -> Dictionary:
	var tags := {}
	for id in XYunshang._gift_sources:
		tags[str(id)] = (XYunshang._gift_sources[id] as Array).map(func(t): return str(t))
	return {"round": XYunshang.round, "awake": [XYunshang.awake(a), XYunshang.awake(ally)], "data": [_yd(a), _yd(ally)], "tags": tags,
		"q174": logic.current_order.count(a), "q1": logic.current_order.count(ally), "afterglow": bool(XYunshang.afterglow.get(a, false))}


func _w_ys(w: Dictionary) -> Dictionary:
	var d := []
	for x in w.data:
		d.append(null if x == null else [int(x.key), int(x.wakeUntil), int(x.stored), int(x.gifts)])
	var tags := {}
	for k in w.tags:
		tags[str(k)] = (w.tags[k] as Array).map(func(t): return str(t))
	return {"round": int(w.round), "awake": (w.awake as Array).map(func(v): return bool(v)), "data": d, "tags": tags,
		"q174": int(w.queue.get("a174", 0)), "q1": int(w.queue.get("a1", 0)), "afterglow": bool(w.afterglow)}


func _target(logic: XBattleLogic, u, skill: Dictionary, idx: int):
	var friend := int(skill.get("scope", 1)) in [7, 8, 9, 10, 11]
	var mine: Array = logic.actors if u is XActor else logic.enemies
	var theirs: Array = logic.enemies if u is XActor else logic.actors
	var list: Array = mine if friend else theirs
	return list[idx] if idx < list.size() else null


func _cast2(logic: XBattleLogic, u, id: int, idx: int, clear_cd := true) -> Dictionary:
	u.mp = u.mmp
	u.tp = u.max_tp()
	if clear_cd:
		u.cooldowns.clear()
	var skill := XDB.rec("Skills", id)
	var logs := logic.act(u, skill, _target(logic, u, skill, idx))
	var hits := []
	for l in logs:
		var derived: bool = l.get("type") == "yunshang_derived"
		if (l.get("type") == "hit" and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)) and int(l.skill.get("damage", {}).get("type", 0)) > 0) or derived:
			hits.append({"user": _key(logic, l.user), "skill": int(l.skill.id), "target": _key(logic, l.target), "value": float(l.hp), "critical": bool(l.critical)})
	return {"log": hits}


func _meets_of(logic: XBattleLogic, a: XActor) -> Array:
	a.mp = a.mmp
	a.tp = a.max_tp()
	return MEETS.map(func(id): return logic.can_use(a, XDB.rec("Skills", id)))


func _p2_compare(id: String, steps: Array, want: Array) -> void:
	check(id + ".steps", steps.size() == want.size(), [steps.size(), want.size()])
	var q0 := [0, 0, 0, 0]
	for i in mini(steps.size(), want.size()):
		var g: Dictionary = steps[i]
		var w: Dictionary = want[i]
		var sid := "%s.%d" % [id, i]
		var gs: Dictionary = g.ys
		var ws := _w_ys(w)
		if i == 0:
			q0 = [gs.q174, gs.q1, ws.q174, ws.q1]
		gs.q174 -= q0[0]
		gs.q1 -= q0[1]
		ws.q174 -= q0[2]
		ws.q1 -= q0[3]
		check(sid + ".state", gs == ws, [gs, ws])
		for k in ["meets", "giftMeets", "storeMeets", "free", "again", "release", "cut", "skills"]:
			if w.has(k):
				var wv = w[k]
				var gv = g.get(k)
				if wv is Array:
					wv = (wv as Array).map(func(v): return int(v) if (v is float) else v)
				check("%s.%s" % [sid, k], gv == wv, [gv, wv])
		for k in ["params", "agi", "needles"]:
			if w.has(k):
				check("%s.%s" % [sid, k], g.get(k) == (w[k] as Array).map(func(v): return float(v)), [g.get(k), w[k]])
		if not w.has("log"):
			continue
		var gl: Array = g.log
		var wl: Array = w.log
		var gk := gl.map(func(l): return [l.user, l.skill, l.target, l.critical])
		var wk := wl.map(func(l): return [str(l.user), int(l.skill), str(l.target), bool(l.critical)])
		check(sid + ".log", gk == wk, [gk, wk])
		if gk != wk:
			continue
		for k in gk.size():
			check("%s.abs%d" % [sid, k], absf(float(gl[k].value) - float(wl[k].value)) <= DAMAGE_TOLERANCE, [gl[k].value, wl[k].value])


## 先算 x 再取 v（GDScript 的 a().merged(b()) 先求参数，读数会落在行动之前）
func _with(x: Dictionary, k: String, v) -> Dictionary:
	x[k] = v
	return x


func _p2_case(c: Dictionary) -> void:
	var o: Dictionary = c.setup
	var r := _battle2(o)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var ally: XActor = r[2]
	var steps := []
	var snap := func(extra := {}) -> void:
		steps.append(extra.merged({"ys": _ys(logic, a, ally)}, true))
	match str(c.id):
		"p2.wake":
			snap.call()
			var x := _cast2(logic, a, 10273, 0)
			x.meets = _meets_of(logic, a)
			snap.call(x)
			_turn(logic)
			snap.call()
			_turn(logic)
			snap.call()
		"p2.seamless":
			snap.call({"params": _params(a)})
			snap.call(_cast2(logic, a, 10270, 1))
			snap.call(_cast2(logic, ally, 1, 2))
		"p2.gather":
			snap.call({"meets": _meets_of(logic, a)})
			snap.call(_cast2(logic, a, 10270, 1))
			XYunshang.wake_target = ally
			var x := _cast2(logic, a, 10274, 1)
			x.meets = _meets_of(logic, a)
			snap.call(x)
		"p2.afterglow":
			snap.call()
			snap.call(_cast2(logic, a, 10270, 1))
			snap.call(_cast2(logic, a, 10270, 1))
		"p2.needle":
			var count := func() -> Array: return logic.enemies.map(func(e): return float((XYunshang.needles.get(e, []) as Array).size()))
			snap.call({"needles": count.call()})
			snap.call(_with(_cast2(logic, a, 10270, 1), "needles", count.call()))
			snap.call(_with(_cast2(logic, a, 10271, 0), "needles", count.call()))
			snap.call(_with(_cast2(logic, logic.enemies[1], 1, 1), "needles", count.call()))
			snap.call(_with(_cast2(logic, logic.enemies[1], 1, 1), "needles", count.call()))
		"p2.wind":
			var agi := func() -> Array: return logic.actors.map(func(b): return b.agi)
			snap.call({"agi": agi.call()})
			snap.call(_with(_cast2(logic, a, 10272, 0), "agi", agi.call()))
			_turn(logic)
			snap.call({"agi": agi.call()})
			_turn(logic)
			snap.call({"agi": agi.call()})
		"p2.gift":
			var gm := func() -> bool:
				ally.mp = ally.mmp
				return logic.can_use(ally, XDB.rec("Skills", XYunshang.GIFT))
			snap.call({"skills": ally.skills().map(func(sk): return int(sk.id)).filter(func(i): return i >= 10270), "giftMeets": gm.call()})
			for i in range(3):
				snap.call(_with(_cast2(logic, ally, XYunshang.GIFT, 0), "giftMeets", gm.call()))
			XYunshang.wake(logic, ally)
			var free := XYunshang.free_gift(logic, ally, a)
			snap.call({"free": free, "again": XYunshang.free_gift(logic, ally, a)})
		"p2.store":
			snap.call({"storeMeets": logic.can_use(ally, XDB.rec("Skills", XYunshang.STORE))})
			snap.call(_cast2(logic, ally, XYunshang.STORE, 0))
			var rel := XYunshang.release(logic, ally)
			snap.call({"release": rel, "again": XYunshang.release(logic, ally)})
			XYunshang.wake(logic, ally)
			_turn(logic)
			snap.call()
			snap.call({"release": XYunshang.release(logic, ally)})
		"p2.cut":
			snap.call({"params": _params(ally).map(func(v): return float(v))})
			var ok := XYunshang.cut(ally, [4])
			snap.call({"cut": ok, "params": _params(ally).map(func(v): return float(v))})
			XYunshang.wake(logic, ally)
			snap.call({"params": _params(ally).map(func(v): return float(v))})
		_:  # p2.seven.*
			snap.call()
			snap.call(_cast2(logic, a, 10270, 1))
			snap.call(_cast2(logic, a, 1, 2))
	logic.end_battle(0)
	_p2_compare(str(c.id), steps, c.observed.steps)


# ---- 第二期 B 批前一半（p3.*）：赊账、幽灵、山河作骨、百厄成锦、逆命换锦、一身两世 ----
const P3_TOLERANCE := 0.002


func _st3(b) -> Array:
	return b.state_ids.filter(func(i): return int(i) != 1).map(func(i): return [int(i), int(b.state_turns.get(i, 0))])


func _v3(logic: XBattleLogic, a: XActor, ally: XActor) -> Dictionary:
	var d := XYunshang.data(ally)
	var yd = null
	if not d.is_empty():
		yd = {"debt": XYunshang.debt_total(d), "due": (d.debts as Array).map(func(x): return int(x.due)), "bank": float(d.bank), "ghost": int(d.ghost),
			"ghostDone": int(d.ghost_done), "ghostUsed": bool(d.ghost_used), "revived": bool(d.revived),
			"captured": (d.captured as Array).map(func(x): return [int(x.id), int(x.turns) if x.turns != null else -1, bool(x.cleaned)])}
	var st := [_st3(a), _st3(ally)]
	for e in logic.enemies:
		st.append(_st3(e))
	return {"hp": [a.mhp - a.hp, ally.mhp - ally.hp], "alive": [a.is_alive(), ally.is_alive()], "mp": ally.mp / ally.mmp, "d": yd, "st": st}


func _w_v3(w: Dictionary) -> Dictionary:
	var yd = null
	if w.d != null:
		yd = {"debt": float(w.d.debt), "due": (w.d.due as Array).map(func(v): return int(v)), "bank": float(w.d.bank), "ghost": int(w.d.ghost),
			"ghostDone": int(w.d.ghostDone), "ghostUsed": bool(w.d.ghostUsed), "revived": bool(w.d.revived),
			"captured": (w.d.captured as Array).map(func(x): return [int(x[0]), int(x[1]) if x[1] != null else -1, bool(x[2])])}
	var st := (w.st as Array).map(func(l): return (l as Array).map(func(x): return [int(x[0]), int(x[1]) if x[1] != null else 0]))
	return {"hp": (w.hp as Array).map(func(v): return float(v)), "alive": (w.alive as Array).map(func(v): return bool(v)), "mp": float(w.mp), "d": yd, "st": st}


func _near(g: float, w: float) -> bool:
	return absf(g - w) <= P3_TOLERANCE * maxf(1.0, absf(w)) + 1.0


func _p3_case(c: Dictionary) -> void:
	var o: Dictionary = c.setup
	var r := _battle2(o)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var ally: XActor = r[2]
	var foes: Array = logic.enemies
	var steps := []
	var at := func(x := {}) -> void:
		x.ys = _ys(logic, a, ally)
		x.v = _v3(logic, a, ally)
		steps.append(x)
	var robe_skills := func() -> Array: return ally.skills().map(func(sk): return int(sk.id)).filter(func(i): return i >= 10270)
	var id := str(c.id)
	if id.ends_with(".awake"):
		XYunshang.wake(logic, ally)
	match id:
		"p3.debt":
			at.call({"skills": robe_skills.call()})
			at.call(_cast2(logic, foes[1], 1, 1))
			at.call(_cast2(logic, ally, 1, 2))
			at.call(_cast2(logic, foes[1], 1, 1))
			XYunshang.wake(logic, ally)
			at.call(_cast2(logic, ally, 1, 2))
			at.call(_cast2(logic, foes[1], 1, 1))
			logic.end_battle(0)
			at.call()
		"p3.debt.due":
			at.call(_cast2(logic, foes[1], 1, 1))
			logic.end_turn()
			at.call()
			_turn(logic)
			at.call()
			logic.end_turn()
			at.call()
		"p3.ghost", "p3.ghost.awake":
			at.call()
			at.call(_cast2(logic, foes[1], 1, 1))
			at.call(_cast2(logic, ally, 1, 2))
			at.call(_cast2(logic, ally, 1, 2))
			at.call(_cast2(logic, foes[1], 1, 2))
		"p3.mountain":
			XYunshang.wake(logic, ally)
			at.call({"skills": robe_skills.call()})
			at.call(_cast2(logic, foes[1], 1, 2))
			at.call(_cast2(logic, ally, XYunshang.MOUNTAIN, 1))
			at.call(_cast2(logic, foes[1], 1, 1))
			at.call(_cast2(logic, foes[1], 1, 1))
		"p3.hundred", "p3.hundred.awake":
			at.call()
			for sid in [5, 6, 55]:
				logic._state_add(ally, sid)
			at.call()
			at.call(_cast2(logic, ally, 1, 1))
		"p3.exchange", "p3.exchange.awake":
			logic._state_add(ally, 5)
			logic._state_add(a, 6)
			logic._state_add(foes[1], 55)
			logic._state_add(foes[2], 43)
			at.call({"skills": robe_skills.call()})
			XYunshang.exchange_pick = [5, 55]
			at.call(_cast2(logic, ally, XYunshang.EXCHANGE, 1))
			XYunshang.exchange_pick = [5, 43]
			at.call(_cast2(logic, ally, XYunshang.EXCHANGE, 2))
		"p3.clone":
			at.call()
			at.call(_cast2(logic, ally, 1, 1))
			at.call(_cast2(logic, ally, 1, 1))
			XYunshang.wake(logic, ally)
			at.call(_cast2(logic, ally, 1, 1))
		"p4.sleeve":
			at.call()
			at.call(_cast2(logic, ally, 160, 0))
			XYunshang.sleeve[ally] = true
			at.call(_cast2(logic, ally, 160, 0))
			XYunshang.wake(logic, ally)
			foes[0].hp = 1000.0
			at.call(_cast2(logic, ally, 160, 0))
			XYunshang.sleeve.erase(ally)
		"p4.borrow":
			XYunshang.setting(a).borrow = [{"owner": 1, "skill": 311}, {"owner": 1, "skill": 160}]
			at.call(_borrow_view(logic, a))
			at.call(_cast2(logic, a, 311, 1))
			XYunshang.wake(logic, a)
			at.call(_borrow_view(logic, a))
			at.call(_cast2(logic, a, 311, 1))
			at.call(_cast2(logic, a, 160, 1))
		"p4.eye":
			XYunshang.setting(a).eye = XYunshang.CUT
			at.call(_eye_view(logic, a))
			at.call(_eye_view(logic, a, _cast2(logic, a, XYunshang.CUT, 1, false)))
			XYunshang.wake(logic, a)
			at.call(_eye_view(logic, a))
			for sid in [XYunshang.CUT, XYunshang.CUT, XYunshang.PIN, XYunshang.PIN, 1, XYunshang.CUT]:
				at.call(_eye_view(logic, a, _cast2(logic, a, sid, 1, false)))
			_turn(logic)  # 第 2 回合（觉醒到本回合末）：针眼冷却 1，本回合还没越过
			at.call(_eye_view(logic, a))
			at.call(_eye_view(logic, a, _cast2(logic, a, XYunshang.CUT, 1, false)))
	if XYunshang.battle != 0:
		logic.end_battle(0)
	XState.current.flags.erase(XYunshang.SETTINGS_FLAG)
	_p3_compare(id, steps, c.observed.steps)


## p4.borrow 每步另比：云裳的普通技能（借来的，没醒 1 个、醒 3 个）与两个借来的技能能不能用
func _borrow_view(logic: XBattleLogic, a: XActor) -> Dictionary:
	return {"skills": a.skills().map(func(sk): return int(sk.id)).filter(func(i): return i < XYunshang.PIN),
		"meets": [311, 160].map(func(i): return logic.can_use(a, XDB.rec("Skills", i)))}


## p4.eye 每步另比：钉影／拆神／御风的冷却、针眼（拆神）能不能用（参照 castKeep：施放不清冷却）
func _eye_view(logic: XBattleLogic, a: XActor, x := {}) -> Dictionary:
	x.cds = [XYunshang.PIN, XYunshang.CUT, XYunshang.WIND].map(func(i): return float(a.cooldowns.get(i, 0.0)))
	a.mp = a.mmp
	x.meets = [logic.can_use(a, XDB.rec("Skills", XYunshang.CUT))]
	return x


## p4.*（B 批后一半）：千军入袖、空袖藏星、九曲回针照 p3 的步骤比（_p3_case）；孤灯照众逐步比全队状态。
## 千军入袖的溢出原版打不出（O-136，行动中目标 IMMORTAL）：先关开关照参照比，再开开关另比溢出（_sleeve_overflow）
func _p4_case(c: Dictionary) -> void:
	if str(c.id) == "p4.sleeve":
		XYunshang.o_sleeve_overflow = false
		_p3_case(c)
		XYunshang.o_sleeve_overflow = true
		_sleeve_overflow(c)
		return
	if str(c.id) != "p4.lamp":
		_p3_case(c)
		return
	var r := _battle2(c.setup)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var ally: XActor = r[2]
	var party := func() -> Array: return logic.actors.map(func(b): return _st3(b))
	var got := [party.call()]
	logic._state_add(ally, 55)
	got.append(party.call())
	logic._state_add(ally, 43)
	got.append(party.call())
	logic._state_add(a, 64)
	got.append(party.call())
	XYunshang.wake(logic, ally)
	logic._state_add(logic.enemies[1], 65)
	got.append(party.call())
	logic._state_add(a, 72)
	logic._state_add(a, 78)
	got.append(party.call())
	logic._state_add(ally, 82)
	got.append(party.call())
	logic.end_battle(0)
	var want: Array = c.observed.steps.map(func(st): return (st.party as Array).map(func(l): return (l as Array).map(func(x): return [int(x[0]), int(x[1])])))
	check("p4.lamp.steps", got.size() == want.size(), [got.size(), want.size()])
	for i in mini(got.size(), want.size()):
		check("p4.lamp.%d.party" % i, got[i] == want[i], [got[i], want[i]])


## O-136 开着：觉醒收袖打倒目标（生命 1000）时，第一段溢出＝这段伤害−1000，之后各段打在生命 0 的目标上整段溢出，依次传给 1 号敌人
func _sleeve_overflow(c: Dictionary) -> void:
	var r := _battle2(c.setup)
	var logic: XBattleLogic = r[0]
	var ally: XActor = r[2]
	var foes: Array = logic.enemies
	XYunshang.sleeve[ally] = true
	XYunshang.wake(logic, ally)
	foes[0].hp = 1000.0
	var before: float = foes[1].hp
	var got: Array = _cast2(logic, ally, 160, 0).log
	XYunshang.sleeve.erase(ally)
	var hits := got.filter(func(l): return l.target == "e0")
	var flows := got.filter(func(l): return l.target == "e1")
	var want := hits.map(func(l): return float(l.value))
	if not want.is_empty():
		want[0] -= 1000.0
	check("p4.sleeve.overflow.hits", hits.size() == 4 and got.size() == 8, got)
	check("p4.sleeve.overflow.values", flows.map(func(l): return float(l.value)) == want, [flows, want])
	check("p4.sleeve.overflow.hp", is_equal_approx(before - foes[1].hp, want.reduce(func(s, v): return s + v, 0.0)) and foes[0].is_dead(), [before - foes[1].hp, foes[0].hp])
	logic.end_battle(0)


# ---- 自动战斗（p5.*，参照 aiSnap）----
const CLOUD_AI := [10270, 10271, 10272, 10273, 10274, 1]
const ROBE_AI := [10282, 10283, 10284, 10285, 10273, 1, 311]
const CTXS := [[true, false], [false, false], [true, true]]  # [longFight, urgent]


func _target_index(logic: XBattleLogic, t) -> int:
	if t == null:
		return -1
	var i := logic.enemies.find(t)
	return i if i >= 0 else logic.actors.find(t)


## 同参照 aiSnap：档案的数值项、targetAllowed／targetUtility（三种情境 × 各目标，不许的记 null）、云裳伤害技能的 safeDamage、choose 与前 6 名候选
func _ai_snap(logic: XBattleLogic, u: XActor, ids: Array, name: String, want: Dictionary) -> void:
	u.param_mark_dirty()
	u.param_refresh()
	u.mp = u.mmp
	u.tp = 50.0
	_order(logic, want.queue)  # 行动队列照参照排（重制开局的 OTB 顺序与参照不同；御风的收益看队列）
	var ai := XSmartAI.new(logic, u)
	var friends: Array = logic.actors
	var foes: Array = logic.alive(logic.enemies)
	for id in ids:
		var rec := XDB.rec("Skills", id)
		var p := XSmartAI.profile(u, rec)
		var nums := {}
		for k in p:
			if p[k] is float or p[k] is int:
				nums[k] = float(p[k])
		var wp: Dictionary = want.profile[str(id)]
		var same := nums.size() == wp.size()
		for k in wp:
			same = same and nums.has(k) and absf(nums[k] - float(wp[k])) <= 1e-9 * maxf(1.0, absf(float(wp[k])))
		check("%s.profile.%d" % [name, id], same, [nums, wp])
		if want.util.has(str(id)):
			var targets: Array = foes if XSmartAI.for_opponent(rec) else [u] if XSmartAI.for_user(rec) \
				else friends.filter(func(t): return t.is_dead() if XSmartAI.for_dead_friend(rec) else t.is_alive())
			check("%s.util_targets.%d" % [name, id], targets.map(func(t): return _key(logic, t)) == want.util[str(id) + "k"], [targets.size(), want.util[str(id) + "k"]])
			var got := []
			for cx in CTXS:
				var ctx := {"friends": friends, "foes": foes, "longFight": cx[0], "urgent": cx[1]}
				got.append(targets.map(func(t):
					if p.has("targetAllowed") and not p.targetAllowed.call(t, ctx, ai):
						return null
					return float(p.targetUtility.call(t, ctx, ai)) if p.has("targetUtility") else 0.0))
			var wu: Array = want.util[str(id)].map(func(row): return row.map(func(v): return null if v == null else float(v)))
			check("%s.util.%d" % [name, id], str(got) == str(wu), [got, wu])
		if want.damage.has(str(id)):
			var dmg: Array = foes.map(func(t): return ai.safe_damage(u, t, rec))
			var ok: bool = dmg.size() == want.damage[str(id)].size()
			for k in mini(dmg.size(), want.damage[str(id)].size()):
				ok = ok and absf(dmg[k] - float(want.damage[str(id)][k])) <= maxf(1.0, absf(float(want.damage[str(id)][k])) * 1e-6)
			check("%s.damage.%d" % [name, id], ok, [dmg, want.damage[str(id)]])
	var r := XSmartAI.choose(logic, u)
	var wc = want.choice
	check(name + ".choice", wc != null and r.has("skill") and int(r.skill.id) == int(wc.id) and _target_index(logic, r.target) == int(wc.target),
		[int(r.skill.id) if r.has("skill") else null, _target_index(logic, r.get("target")), wc])
	var cands: Array = r.get("candidates", [])
	var exp_c: Array = want.candidates
	var same := cands.size() == exp_c.size()
	for k in cands.size():
		if same:
			same = int(cands[k].id) == int(exp_c[k].id) and absf(float(cands[k].score) - float(exp_c[k].score)) <= maxf(1.0, absf(float(exp_c[k].score)) * 1e-4)
	check(name + ".candidates", same, [cands.map(func(x): return [x.id, x.score]), exp_c.map(func(x): return [x.id, x.score])])


func _order(logic: XBattleLogic, keys: Array) -> void:
	var order := []
	for k in keys:
		order.append(logic.state.actor(int(str(k).substr(1))) if str(k).begins_with("a") else logic.enemies[int(str(k).substr(1))])
	logic.current_order.assign(order)


func _p5_case(c: Dictionary) -> void:
	XSave.dir_override = "user://test_xiyou_yunshang"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var r := _battle2(c.setup)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var ally: XActor = r[2]
	var foes: Array = logic.enemies
	var id := str(c.id)
	var want: Array = c.observed.steps
	var snap := func(i: int, u: XActor, ids: Array) -> void: _ai_snap(logic, u, ids, "%s.%d" % [id, i], want[i])
	match id:
		"p5.cloud":
			snap.call(0, a, CLOUD_AI)
			snap.call(1, ally, ROBE_AI)
			XYunshang.wake(logic, ally)
			snap.call(2, a, CLOUD_AI)
			snap.call(3, ally, ROBE_AI)
		"p5.gather":
			snap.call(0, a, CLOUD_AI)
		"p5.robe0", "p5.robe4", "p5.robe9", "p5.robe11":
			if id == "p5.robe4":
				logic._state_add(ally, 5)
				logic._state_add(a, 6)
				logic._state_add(foes[1], 55)
				logic._state_add(foes[2], 43)
			snap.call(0, ally, ROBE_AI)
			if id == "p5.robe4":  # prepareTarget：选中换锦时记下要换的一对（自己的减益 5、目标 1 号敌人的增益 55）
				check(id + ".exchange_pick", str(XYunshang.exchange_pick) == str([5, 55]), XYunshang.exchange_pick)
				XYunshang.exchange_pick = null
			XYunshang.wake(logic, ally)
			snap.call(1, ally, ROBE_AI)
		"p5.wake":
			XYunshang.data(ally).wake_until = 0  # 参照把 8 号挪到队尾，_ai_snap 照参照的队列排
			snap.call(0, a, CLOUD_AI)
			XYunshang.wake(logic, ally)
			XYunshang.wind_until[a] = XYunshang.round
			snap.call(1, a, CLOUD_AI)
		_:  # p5.auto*：makeAutoBattleActions 包装
			var k := int(id.trim_prefix("p5.auto"))
			_order(logic, ["a1", "a8", "a9", "a10", "e0", "e1", "e2"])  # 参照 battle2 开局的队列（174 已取走）；重制的开局顺序不同，赠行／放行加在队尾
			if k == 9:
				XYunshang.data(ally).stored = 2
			if k == 11:
				XYunshang.wake(logic, ally)
			var choice: Array = logic.auto_battle_action(ally)
			var d := XYunshang.data(ally)
			var w: Dictionary = want[0]
			var tags := {}
			for t in XYunshang._gift_sources:
				tags[str(t)] = (XYunshang._gift_sources[t] as Array).map(func(x): return str(x))
			var got := {"sleeve": bool(XYunshang.sleeve.get(ally, false)), "choice": int(choice[0].id),
				"cut": d.cut_choices if int(d.cut_round) == XYunshang.round else null, "stored": int(d.stored), "freeGift": int(d.free_gift_round),
				"queue": logic.current_order.map(func(b): return _key(logic, b)), "tags": tags,
				"received": logic.actors.map(func(b): return int(XYunshang.gift_received.get(b, 0))), "params": _params(ally).map(func(v): return float(v))}
			var exp := {"sleeve": bool(w.sleeve), "choice": int(w.choice[0]), "cut": null if w.cut == null else (w.cut as Array).map(func(v): return int(v)),
				"stored": int(w.stored), "freeGift": int(w.freeGift), "queue": w.queue, "tags": w.tags, "received": (w.received as Array).map(func(v): return int(v)),
				"params": (w.params as Array).map(func(v): return float(v))}
			for key in exp:
				check("%s.%s" % [id, key], str(got[key]) == str(exp[key]), [got[key], exp[key]])
			XYunshang.sleeve.erase(ally)
	logic.end_battle(0)


func _p3_compare(id: String, steps: Array, want: Array) -> void:
	check(id + ".steps", steps.size() == want.size(), [steps.size(), want.size()])
	for i in mini(steps.size(), want.size()):
		var g: Dictionary = steps[i]
		var w: Dictionary = want[i]
		var sid := "%s.%d" % [id, i]
		var gv: Dictionary = g.v
		var wv := _w_v3(w)
		check(sid + ".awake", g.ys.awake == (w.awake as Array).map(func(v): return bool(v)), [g.ys.awake, w.awake])
		check(sid + ".alive", gv.alive == wv.alive, [gv.alive, wv.alive])
		check(sid + ".st", gv.st == wv.st, [gv.st, wv.st])
		check(sid + ".hp", _near(gv.hp[0], wv.hp[0]) and _near(gv.hp[1], wv.hp[1]), [gv.hp, wv.hp])
		check(sid + ".mp", absf(gv.mp - wv.mp) < 1e-6, [gv.mp, wv.mp])
		if wv.d != null and gv.d != null:
			var gd: Dictionary = gv.d
			var wd: Dictionary = wv.d
			check(sid + ".debt", _near(gd.debt, wd.debt) and _near(gd.bank, wd.bank) and gd.due == wd.due, [gd, wd])
			for k in ["ghost", "ghostDone", "ghostUsed", "revived", "captured"]:
				check("%s.%s" % [sid, k], gd[k] == wd[k], [gd[k], wd[k]])
		else:
			check(sid + ".d", (wv.d == null) == (gv.d == null), [gv.d, wv.d])
		if w.has("skills"):
			check(sid + ".skills", g.get("skills") == (w.skills as Array).map(func(v): return int(v)), [g.get("skills"), w.skills])
		if w.has("meets"):
			check(sid + ".meets", g.get("meets") == (w.meets as Array).map(func(v): return bool(v)), [g.get("meets"), w.meets])
		if w.has("cds"):
			# YEP 回合开始把所有冷却都减 1（0 变 −1），重制减到 0 就删掉；≤0 都是没在冷却
			check(sid + ".cds", g.get("cds") == (w.cds as Array).map(func(v): return maxf(0.0, float(v))), [g.get("cds"), w.cds])
		if not w.has("log"):
			continue
		var gl: Array = g.log
		var wl: Array = w.log
		var gk := gl.map(func(l): return [l.user, l.skill, l.target, l.critical])
		var wk := wl.map(func(l): return [str(l.user), int(l.skill), str(l.target), bool(l.critical)])
		check(sid + ".log", gk == wk, [gk, wk])
		if gk != wk:
			continue
		# 角色出手的伤害比绝对值（参照关了五乘区；之前 1 号差约 0.9% 就是它）；敌人出手的数值看生命、债、bank
		# （原版记的是包装外层 executeHpDamage 的入参，重制记的是分担／记债之后的）
		for k in gk.size():
			var who: String = gl[k].user
			if not who.begins_with("a"):
				continue
			check("%s.abs%d" % [sid, k], absf(float(gl[k].value) - float(wl[k].value)) <= DAMAGE_TOLERANCE, [gl[k].value, wl[k].value])




func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_yunshang", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
