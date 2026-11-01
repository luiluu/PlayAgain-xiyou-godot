extends Node
## 【cc·白龙_8·未经审查】167 渡鸦第三期：战斗内机制（XRaven：begin／applied／finish／repeats／start_turn／end_turn／end_battle，
## 神话之力进伤害钩子与魔防穿透）：与 mv_oracle/raven_battle_probe.cjs 的冻结 v0.28 参照（tests/fixtures/raven_battle_oracle.json，
## 真实 BattleManager）逐例比。
## - myth.*：神话封解开 3 回合、形态中再放不重置、回合结束减一、敌人倒下续期到 5、结束战斗与升级清零、到期后可再开；
## - power.*：开形态前后、忘掉神话余响后的伤害比值（神话之力的增伤）与回响；
## - residue.*：无人倒下的回合结束 +1、敌人倒下 +1、满 3 进狩猎（要学三羽成环）、本回合有人倒下回合结束不加、没学死亡残响不计、
##   渡鸦在后备不计；residue.sync：升级时没学的清掉；
## - hunt.*／echo.*：冥界收割（×1，神话之力 ×1.5）、回响 ×0.85、全体技能逐目标、普通攻击不消耗狩猎、收割打倒目标（得魂、残响、续期）；
## - peck.*：鸦啄回 2% 最大 MP；erosion.*：黑暗侵蚀（二阶盛宴普通附加、学了夜蚀余烬直接附加）；repeats.*：冥羽连葬吃额外攻击次数。
## 每次施放的扣血逐段比（命中段 hit、直接扣血 direct 的目标与次序）；数值比本例第一段命中的比值（伤害链绝对值另有与本期无关的差，不比）；
## 每步之后的神话回合、残响、狩猎、灵魂、MP、敌人倒下与侵蚀逐项比。另核残响／狩猎存档往返、旧档没有这两个键。
const FIXTURE := "res://tests/fixtures/raven_battle_oracle.json"
const RATIO_TOLERANCE := 1e-6
var results := []


## 规则流全取 0.5；整数同参照 Math.randomInt（floor(n×0.5)），伤害浮动才与参照同为中点（取原始 uint 时浮动随数量级乱跳）
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


## 同参照 battle()：新局、挑战开关 2494、阶 rank、level 级、招募、再入队 1（reserve：先入 1、8、9、10，渡鸦排第 5，仍在出战成员里）；
## 全队生命加 1e12；敌群 3 每只生命加 1e12；规则流全取 0.5；开第一回合
func _battle(rank: int, level: int, reserve := false) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	s.actor_advance[XRaven.ACTOR] = rank
	var a := s.actor(XRaven.ACTOR)
	a.change_level_mv(level)
	if reserve:
		for id in [1, 8, 9, 10]:
			s.add_actor(id)
	check("setup.recruit", XRaven.recruit(s))
	if not reserve:
		s.add_actor(1)
	for id in s.party:
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
	var rand := XBattleRandom.create("0000000000000167")
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
	for id in s.party:
		var b := s.actor(id)
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	logic.start_turn()
	return [logic, a]


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


## 一次行动里实际扣血的各段（同参照 record：executeHpDamage 的命中段、不经伤害计算的直接扣血）
func _log(logic: XBattleLogic, logs: Array) -> Array:
	var out := []
	for l in logs:
		if l.get("type") == "hit" and l.has("user") and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)) \
				and int(l.skill.get("damage", {}).get("type", 0)) in [1, 5]:
			out.append({"kind": "hit", "skill": int(l.skill.id), "target": _key(logic, l.target), "value": float(l.hp), "critical": bool(l.critical)})
		elif l.get("type") == "regen" and l.has("raven"):
			out.append({"kind": "direct", "skill": null, "target": _key(logic, l.target), "value": float(l.hp), "critical": null})
	return out


func _snap(logic: XBattleLogic, a: XActor) -> Dictionary:
	return {"myth": XRaven.myth_turns(a), "residue": XRaven.residue(a), "hunter": XRaven.hunter(a), "soul": XRaven.soul(a), "mp": a.mp,
		"dead": logic.enemies.map(func(e): return e.is_dead()), "erosion": logic.enemies.map(func(e): return e.state_ids.has(XRaven.EROSION))}


func _cast(logic: XBattleLogic, a: XActor, id: int, target = 0) -> Dictionary:
	a.mp = a.mmp
	var t = target if target is XBattler else logic.enemies[int(target)]
	return _snap(logic, a).merged({"cast": id, "log": _log(logic, logic.act(a, XDB.rec("Skills", id), t))}, true)


func _turn(logic: XBattleLogic, a: XActor) -> Dictionary:
	logic.end_turn()
	var out := _snap(logic, a).merged({"turnEnd": true}, true)
	logic.start_turn()
	return out


func _kill(logic: XBattleLogic, a: XActor, i: int) -> Dictionary:
	logic.enemies[i].add_state(1)
	return _snap(logic, a).merged({"kill": "e%d" % i}, true)


## 逐步比：扣血段的结构逐条、数值比本例第一段命中的比值；状态逐项
func _compare(id: String, got_steps: Array, want_steps: Array) -> void:
	check(id + ".steps", got_steps.size() == want_steps.size(), [got_steps.size(), want_steps.size()])
	var base := [0.0, 0.0]  # [重制, 参照] 本例第一段命中
	for i in mini(got_steps.size(), want_steps.size()):
		var g: Dictionary = got_steps[i]
		var w: Dictionary = want_steps[i]
		var sid := "%s.%d" % [id, i]
		var gl: Array = g.get("log", [])
		var wl: Array = w.get("log", [])
		var gs: Array = gl.map(func(l): return [l.kind, l.skill, l.target, l.critical])
		var ws: Array = wl.map(func(l): return [str(l.kind), null if l.get("skill") == null else int(l.skill), str(l.target), null if l.get("critical") == null else bool(l.critical)])
		check(sid + ".log", gs == ws, [gs, ws])
		if gs == ws:
			for k in gs.size():
				if base[0] == 0.0 and gs[k][0] == "hit":
					base = [float(gl[k].value), float(wl[k].value)]
				if base[0] == 0.0:
					continue
				var rg: float = float(gl[k].value) / base[0]
				var rw: float = float(wl[k].value) / base[1]
				check("%s.ratio%d" % [sid, k], absf(rg - rw) <= RATIO_TOLERANCE * maxf(1.0, absf(rw)), [gl[k].value, wl[k].value, rg, rw])
		var keys := ["myth", "residue", "hunter", "soul", "mp", "dead", "erosion"]
		var got := keys.map(func(k): return g[k])
		var want := [int(w.myth), int(w.residue), bool(w.hunter), float(w.soul), float(w.mp), (w.dead as Array).map(func(v): return bool(v)), (w.erosion as Array).map(func(v): return bool(v))]
		got[0] = int(got[0]); got[1] = int(got[1]); got[3] = float(got[3]); got[4] = float(got[4])
		check(sid + ".state", got == want, [keys, got, want])


func _myth(c: Dictionary) -> void:
	var r := _battle(5, 60)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var steps := [_cast(logic, a, XRaven.MYTH, a)]
	if c.id == "myth.r5":
		var learned := a.skill_ids.filter(func(i): return i >= 10122)
		learned.sort()
		check(c.id + ".skills", learned == (c.observed.skills as Array).map(func(v): return int(v)), [learned, c.observed.skills])
		steps.append(_turn(logic, a))
		steps.append(_cast(logic, a, XRaven.MYTH, a))
		for i in logic.enemies.size():
			steps.append(_kill(logic, a, i))
		steps.append(_turn(logic, a))
		logic.end_battle(0)
		steps.append(_snap(logic, a).merged({"endBattle": true}, true))
	else:
		for i in 3:
			steps.append(_turn(logic, a))
		steps.append(_cast(logic, a, XRaven.MYTH, a))
		a._level_up()
		# 升级后原版 MP 回满（升级回复不在本期，重制直接调 _level_up 不回），这一步不比 MP
		steps.append(_snap(logic, a).merged({"levelUp": true, "mp": float(c.observed.steps[steps.size()].mp)}, true))
	_compare(c.id, steps, c.observed.steps)


func _power(c: Dictionary) -> void:
	var id := int(c.setup.skill)
	var r := _battle(5, 60)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var steps := [_cast(logic, a, id)]
	steps.append(_cast(logic, a, XRaven.MYTH, a))
	steps.append(_cast(logic, a, id))
	a.forget_skill(XRaven.MYTH_PASSIVE)
	steps.append(_cast(logic, a, id))
	_compare(c.id, steps, c.observed.steps)


func _residue(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	if c.id == "residue.sync":
		var r := _battle(3, 60)
		var logic: XBattleLogic = r[0]
		var a: XActor = r[1]
		var st: Dictionary = XState.current.raven
		st["residue"] = 3
		st["hunter"] = true
		a._level_up()
		var kept := _snap(logic, a)
		a.change_level_mv(20)
		st["residue"] = 2
		st["hunter"] = true
		a._level_up()
		var learned := a.skill_ids.filter(func(i): return i >= 10122)
		learned.sort()
		check(c.id + ".skills", learned == (c.observed.skills as Array).map(func(v): return int(v)), [learned, c.observed.skills])
		_compare(c.id, [kept, _snap(logic, a)], [c.observed.kept, c.observed.lv21])
		return
	var reserve := bool(setup.get("reserve", false))
	var r := _battle(int(setup.rank), int(setup.level), reserve)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var steps := [_turn(logic, a)]
	if reserve:
		var members := XState.current.members().map(func(b): return b.actor_id)
		check(c.id + ".members", members == (c.observed.members as Array).map(func(v): return int(v)), [members, c.observed.members])
		check(c.id + ".fighting", logic.actors.has(a))  # 第 5 位仍出战（参照 members 五人都在）
		steps.append(_kill(logic, a, 0))
	else:
		steps.append(_turn(logic, a))
		steps.append(_kill(logic, a, 0))
		steps.append(_turn(logic, a))
		steps.append(_turn(logic, a))
		steps.append(_kill(logic, a, 1))
	_compare(c.id, steps, c.observed.steps)


func _hunt(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var r := _battle(int(setup.get("rank", 5)), int(setup.get("level", 60)))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var st: Dictionary = XState.current.raven
	var steps := []
	if bool(setup.get("myth", false)) or c.id == "echo.r5":
		steps.append(_cast(logic, a, XRaven.MYTH, a))
	if c.id == "echo.r5":
		steps.append(_cast(logic, a, XRaven.PECK))
	elif c.id == "hunt.kill":
		var probe := _cast(logic, a, XRaven.PECK, 1)
		steps.append(probe)
		var first: float = probe.log.filter(func(l): return l.kind == "hit")[0].value
		logic.enemies[0].hp = first + 1.0
		logic.enemies[0].refresh_resources()
		st["residue"] = 3
		st["hunter"] = true
		steps.append(_cast(logic, a, XRaven.PECK, 0))
	else:
		st["residue"] = 3
		st["hunter"] = true
		steps.append(_cast(logic, a, int(setup.skill)))
		steps.append(_cast(logic, a, int(setup.skill)))
	_compare(c.id, steps, c.observed.steps)


func _peck(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(0, 10)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	a.mp = a.mmp
	var before := a.mp
	var log := _log(logic, logic.act(a, XDB.rec("Skills", XRaven.PECK), logic.enemies[0]))
	check(c.id + ".mp", [a.mmp, before, a.mp, log.size()] == [float(o.mmp), float(o.before), float(o.after), (o.log as Array).size()], [a.mmp, before, a.mp, log, o])


func _erosion(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var o: Dictionary = c.observed
	var id := int(setup.skill)
	var r := _battle(int(setup.rank), int(setup.level))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	check(c.id + ".learned", [a.skill_ids.has(id), a.skill_ids.has(XRaven.EMBER)] == [bool(o.learned), bool(o.has10134)], [a.skill_ids.has(id), a.skill_ids.has(XRaven.EMBER), o])
	_compare(c.id, [_cast(logic, a, id)], [o.step])


func _repeats(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(1, 20)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	for sid in c.setup.states:
		a.add_state(int(sid))
	a.param_mark_dirty()
	a.param_refresh()
	check(c.id + ".attackTimesAdd", is_equal_approx(a.attack_times_add(), float(o.attackTimesAdd)), [a.attack_times_add(), o.attackTimesAdd])
	_compare(c.id, [_cast(logic, a, XRaven.FEATHER)], [o.step])


## 存档往返：残响、狩猎存档，神话回合不存；旧档没有这两个键＝0／否
func _save() -> void:
	var r := _battle(3, 60)
	var a: XActor = r[1]
	var s := XState.current
	s.raven["residue"] = 2
	s.raven["hunter"] = true
	s.raven["myth"] = 3
	var back := XRaven.from_save(JSON.parse_string(JSON.stringify(XRaven.to_save(s.raven))))
	check("save.roundtrip", int(back.residue) == 2 and bool(back.hunter) and not back.has("myth"), back)
	var old := XRaven.from_save({"soul": 10.0, "forged": 1})
	check("save.old", int(old.residue) == 0 and not bool(old.hunter) and float(old.soul) == 10.0, old)
	check("save.myth_runtime", XRaven.myth_turns(a) == 3)


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
				var r := _battle(5, 60)
				check("module", (c.observed.require as Array).map(func(v): return int(v)) == XRaven.REQUIRE and r[0].enemies.size() == int(c.observed.foes), c.observed)
			"myth":
				_myth(c)
			"power":
				_power(c)
			"residue":
				_residue(c)
			"hunt", "echo":
				_hunt(c)
			"peck":
				_peck(c)
			"erosion":
				_erosion(c)
			"repeats":
				_repeats(c)
	check("covers_all", seen.keys().size() == 9, seen.keys())
	_save()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_raven_battle", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
