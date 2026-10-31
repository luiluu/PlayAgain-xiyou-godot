extends Node
## 【cc·白龙_7·未经审查】173 饿狼第三期：战斗内被动（XGarou：begin／damage_ops／applied／finish／trigger／meets／turn_end）：
## 与 mv_oracle/garou_battle_probe.cjs 的冻结 v0.28 参照（tests/fixtures/garou_battle_oracle.json，真实 BattleManager）逐例比。
## - chain.*：主拳连打 5 次——每次命中的行动者、技能、追击／反击、目标、暴击逐条比；伤害按行动者分组比对第一段的比值
##   （进化增伤、解析减防、追击都体现在比值里；绝对值另有与本期无关的伤害链差，不比）；每次后的进化层、各敌人解析层、TP；
## - water.s0：流水岩碎拳命中回 20 TP；aoe.s3：全体拳每个目标各加一层解析、进化只加一层；
## - enemy.*：敌人打饿狼——每回合只进化一次、给出手的敌人加解析，随机 0.1 时反击（反击命中再加一层），回合结束清；
## - cnt：饿狼不被原生反击；meets.*：未到形态的拳法、追击不能用，认真一拳要琦玉模式，打出后与回合结束清；end：结束战斗清数据。
const FIXTURE := "res://tests/fixtures/garou_battle_oracle.json"
## 比值容差：星空混合拳（物攻＋魔攻）的解析减防在比值里只占约万分之一，重制伤害链绝对值本就与原版有固定差（另案），
## 这部分在比值里差约 3e-6；其余形态在 1e-6 以内
const RATIO_TOLERANCE := 1e-5
var results := []


class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


## 同参照 battle()：新局、挑战开关 2494、形态 stage、level 级、招募（装上法宝；relic 假时卸下）、队伍 [173, 1]、生命各加 1e12；
## 敌群 3 每只生命加 1e12；规则流全取 0.5
func _battle(stage: int, level: int, relic: bool) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	s.actor_advance[XGarou.ACTOR] = stage
	var a := s.actor(XGarou.ACTOR)
	a.change_level_mv(level)
	check("setup.recruit", XGarou.recruit(s))
	if not relic:
		XEquipment.change(s, a, a.equip_slots().find(13), null)
	s.add_actor(1)
	for id in [XGarou.ACTOR, 1]:
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
	var rand := XBattleRandom.create("0000000000000173")
	rand.rule = FixedStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	return [logic, a]


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


## 一次行动里实际扣血的各段（同原版 executeHpDamage）
func _hits(logic: XBattleLogic, logs: Array) -> Array:
	var out := []
	for l in logs:
		if l.get("type") != "hit" or bool(l.get("missed", false)) or bool(l.get("evaded", false)) or not l.has("user"):
			continue
		var kind := "followup" if l.get("followup", false) else ("counter" if l.get("counter", false) and XGarou.own(l.user) else "")
		out.append({"user": _key(logic, l.user), "skill": int(l.skill.id), "kind": kind, "target": _key(logic, l.target), "value": float(l.hp), "critical": bool(l.critical)})
	return out


func _snap(logic: XBattleLogic, a: XActor) -> Dictionary:
	return {"evolution": XGarou.evolution, "analysis": logic.enemies.map(func(e): return XGarou.layers(e)), "tp": a.tp, "received": XGarou.received, "saitama": XGarou.saitama}


## 逐条比结构；伤害按行动者分组，比对本组第一段的比值
func _compare(id: String, got_steps: Array, want_steps: Array, with_tp := true) -> void:
	check(id + ".steps", got_steps.size() == want_steps.size(), [got_steps.size(), want_steps.size()])
	var first := {}
	var first_want := {}
	for i in mini(got_steps.size(), want_steps.size()):
		var g: Dictionary = got_steps[i]
		var w: Dictionary = want_steps[i]
		var sid := "%s.%d" % [id, i]
		var gs: Array = g.get("log", []).map(func(l): return [l.user, l.skill, l.kind, l.target, l.critical])
		var ws: Array = w.get("log", []).map(func(l): return [str(l.user), int(l.skill), str(l.kind), str(l.target), bool(l.critical)])
		check(sid + ".log", gs == ws, [gs, ws])
		if gs == ws:
			for k in gs.size():
				var u: String = gs[k][0]
				if not first.has(u):
					first[u] = float(g.log[k].value)
					first_want[u] = float(w.log[k].value)
				var rg: float = float(g.log[k].value) / float(first[u])
				var rw: float = float(w.log[k].value) / float(first_want[u])
				check("%s.ratio%d" % [sid, k], absf(rg - rw) <= RATIO_TOLERANCE * maxf(1.0, absf(rw)), [g.log[k].value, w.log[k].value, rg, rw])
		var want := [int(w.evolution), (w.analysis as Array).map(func(v): return int(v)), float(w.tp) if with_tp else 0.0, bool(w.received), bool(w.saitama)]
		var got := [int(g.evolution), g.analysis, float(g.tp) if with_tp else 0.0, bool(g.received), bool(g.saitama)]
		check(sid + ".state", got == want, [got, want])


func _chain(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(int(c.setup.stage), int(c.setup.level), bool(c.setup.relic))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var skill := XDB.rec("Skills", int(o.skill))
	check(c.id + ".main", XGarou.MAIN[XGarou.stage(a)] == int(o.skill))
	var learned := a.skill_ids.filter(func(i): return i >= 10250 and i <= 10269)
	learned.sort()
	check(c.id + ".skills", learned == (o.skills as Array).map(func(v): return int(v)), [learned, o.skills])
	var steps := []
	for i in 5:
		a.tp = 100.0
		a.mp = a.mmp
		var hits := _hits(logic, logic.act(a, skill, logic.enemies[0]))
		steps.append(_snap(logic, a).merged({"log": hits}))
	_compare(c.id, steps, o.steps)


func _simple(c: Dictionary, skill_id: int, tp_each: float) -> void:
	var r := _battle(int(c.setup.stage), int(c.setup.level), true)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	if tp_each < 0.0:
		a.tp = 0.0
	var steps := []
	for i in int(c.setup.casts):
		if tp_each >= 0.0:
			a.tp = tp_each
		steps.append(_snap(logic, a).merged({"log": _hits(logic, logic.act(a, XDB.rec("Skills", skill_id), logic.enemies[0]))}))
	_compare(c.id, steps, c.observed.steps)


func _enemy(c: Dictionary) -> void:
	var r := _battle(int(c.setup.stage), int(c.setup.level), true)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	logic.random.rule.value = float(c.setup.random)
	var steps := []
	var hit := func(): steps.append(_snap(logic, a).merged({"log": _hits(logic, logic.act(logic.enemies[0], XDB.rec("Skills", 1), a))}))
	hit.call()
	hit.call()
	logic.turn_end_battler(a, [])
	steps.append(_snap(logic, a).merged({"turnEnd": true}))
	hit.call()
	logic.random.rule.value = 0.5
	# 敌人那一段的伤害值随难度与防御另算，只比结构；反击段比比值。饿狼受击得的 TP 跟开战 TP、受击充能有关，与本期无关，不比
	_compare(c.id, steps, c.observed.steps, false)


func _meets(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(int(c.setup.stage), int(c.setup.level), true)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var meets := func():
		a.tp = 100.0
		a.mp = a.mmp
		var out := []
		for id in range(10250, 10264):
			if logic.can_use(a, XDB.rec("Skills", id)):
				out.append(id)
		return out
	var ints := func(v): return (v as Array).map(func(x): return int(x))
	check(c.id + ".plain", meets.call() == ints.call(o.plain), [meets.call(), o.plain])
	if int(c.setup.stage) == 6:
		a.tp = 100.0
		logic.act(a, XDB.rec("Skills", XGarou.MODE), a)
		check(c.id + ".afterMode", XGarou.saitama == bool(o.afterMode.saitama) and meets.call() == ints.call(o.afterMode.meets), [XGarou.saitama, meets.call(), o.afterMode])
		a.tp = 100.0
		var hits := _hits(logic, logic.act(a, XDB.rec("Skills", XGarou.SERIOUS), logic.enemies[0]))
		check(c.id + ".afterSerious", XGarou.saitama == bool(o.afterSerious.saitama) and hits.size() == int(o.afterSerious.hits) and meets.call() == ints.call(o.afterSerious.meets),
			[XGarou.saitama, hits.size(), meets.call(), o.afterSerious])
		logic.act(a, XDB.rec("Skills", XGarou.MODE), a)
		logic.turn_end_battler(a, [])
		check(c.id + ".afterTurn", XGarou.saitama == bool(o.afterTurn.saitama))


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match kind:
			"module":
				var ok: bool = (c.observed.main as Array).map(func(v): return int(v)) == XGarou.MAIN and (c.observed.relicEvolution as Array).map(func(v): return int(v)) == XGarou.RELIC_EVOLUTION
				for i in 7:
					var p: Dictionary = c.observed.passives[i]
					var f: Array = XGarou.FORM_PASSIVES[i]
					ok = ok and bool(p.evolution_enabled) == f[0] and int(p.evolution_base_per_stack_percent) == f[1] and bool(p.analysis_enabled) == f[2] \
						and int(p.analysis_defense_ignore_percent_per_stack) == f[3] and int(p.analysis_magic_defense_ignore_percent_per_stack) == f[4] \
						and bool(p.followup_enabled) == (i >= 4) and bool(p.counter_enabled)
				check("module", ok, c.observed)
			"chain":
				_chain(c)
			"water":
				_simple(c, XGarou.WATER, -1.0)
			"aoe":
				_simple(c, 10254, 100.0)
			"enemy":
				_enemy(c)
			"cnt":
				var r := _battle(2, 60, true)
				var a: XActor = r[1]
				check("cnt", XGarou.no_counter(a) and not XGarou.no_counter(r[0].state.actor(1)) and is_equal_approx(a.cnt, float(c.observed.garouCnt)), a.cnt)
			"meets":
				_meets(c)
			"end":
				var r := _battle(2, 60, true)
				var logic: XBattleLogic = r[0]
				var a: XActor = r[1]
				a.tp = 100.0
				logic.act(a, XDB.rec("Skills", XGarou.MAIN[2]), logic.enemies[0])
				var b: Dictionary = c.observed.before
				check("end.before", [XGarou.evolution, logic.enemies.map(func(e): return XGarou.layers(e))] == [int(b.evolution), (b.analysis as Array).map(func(v): return int(v))])
				logic.end_battle(0)
				check("end.after", XGarou.evolution == 0 and XGarou.analysis.is_empty() and not XGarou.saitama)
	check("covers_all", seen.keys().size() == 8, seen.keys())
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_garou_battle", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
