extends Node
## 【cc·白龙_9·未经审查】174 云裳第一期（XYunshang：sync／param／passive_cache／formula／damage_ops／sure／cri／repeats／targets／meets，招募）：
## 与 mv_oracle/yunshang_probe.cjs 的冻结 v0.28 参照（tests/fixtures/yunshang_oracle.json）逐例比。
## - skills.*／relic.*：新建角色写进阶次数后升到各级（含 35→20 降级）的专属技能、八项能力值、被动缓存的暴伤／终伤（戴织神天梭终伤 +3）；
## - formula：五个伤害技能与御风在目标魔防 19／37519 下的公式值（战斗外，1e-9 相对误差）；
## - recruit：入队、背包一件织神天梭、第二次不再给；
## - battle.*：钉影、拆神、普通攻击各打一次——每段的技能、目标、暴击逐条比（必中、戴织神天梭必暴击、双针两段、云丝展幅打全体），
##   伤害比本例第一段的比值（双针 ×0.555、展幅非主目标 ×0.5／0.66／0.77、织神天梭结算 ×1.99 与暴伤、魔法路线对物防 +5000 的敌人；
##   伤害是整数、等级低时只有几百到几万，容差加上取整误差；绝对值另有与本期无关的伤害链差约 4%，同 xiyou_garou_battle 不比）；
##   每步后六个技能能不能用（没解锁、冷却、敕衣点神要有人穿天衣、收针要有人觉醒、被动不能用）。
const FIXTURE := "res://tests/fixtures/yunshang_oracle.json"
const RATIO_TOLERANCE := 1e-6
const MEETS := [10270, 10271, 10272, 10273, 10274, 10277]
var results := []


## 规则流全取 0.5；整数照 Math.randomInt 取中点（同 xiyou_jingliu）
class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648
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
	var base := [0.0, 0.0]
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
			if base[0] == 0.0:
				base = [float(gl[k].value), float(wl[k].value)]
			var rg: float = float(gl[k].value) / base[0]
			var rw: float = float(wl[k].value) / base[1]
			# 伤害是整数：容差加上两边取整（各 ±0.5）带来的比值误差
			var round_err: float = rw * (1.0 / float(wl[k].value) + 1.0 / base[1])
			check("%s.ratio%d" % [sid, k], absf(rg - rw) <= RATIO_TOLERANCE * maxf(1.0, absf(rw)) + round_err, [gl[k].value, wl[k].value, rg, rw])


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
	check("covers_all", seen.keys().size() == 5, seen.keys())
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_yunshang", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
