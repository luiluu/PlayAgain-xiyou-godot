extends Node
## 【cc·白龙_8·未经审查】170 镜流第二期（XYomiJingliu：j_before／_pay_blood／j_finish 追加段／queue_extra／enemy_param／element_rate／
## start_battle／after_load）与渡鸦逆祷收割：与 mv_oracle/jingliu2_probe.cjs 的冻结 v0.28 参照（tests/fixtures/jingliu2_oracle.json）逐例比。
## - seq.*：霜痕→霜痕尽裂、裂隙→碎月穿霜、裂隙→寒川映月、昙华生灭→寒川映月，进阶 0／1：扣血段（含追加段标记）逐条比目标，数值比本例第一段的比值；
##   每步后月魄、绽放、放血累计、队友生命、霜痕／裂隙、敌人防御与寒冰抗性（裂隙演化）、行动队里镜流的个数（追加行动）、两种追加行动的本回合标记；
## - blood.empty.r1：队友生命 1 扣不动，不加倍率、不给放血追加行动；extra.moon：月魄涨到 2 插队、同回合不再插、新回合重置、结束战斗清；
## - load.*：读档整理技能（进阶 ≥1 学 10200～10202）、放血累计清零；raven.*：渡鸦穿逆祷异化武器时主伤害与收割都扣不动血（审查第 14 期 P3）。
const FIXTURE := "res://tests/fixtures/jingliu2_oracle.json"
const RATIO_TOLERANCE := 1e-6
var results := []


## 规则流全取 0.5；整数照 Math.randomInt 取中点（同 xiyou_raven_battle）
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


func _new_game() -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	return s


func _logic(s: XState) -> XBattleLogic:
	for id in s.party:
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
	var rand := XBattleRandom.create("0000000000000170")
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
	return logic


## 同参照 battle()：镜流 level 级、进阶 rank（≥1 直接学 10200～10202）、招募、给剑 2；队伍是新局的 1、8、9、10 加镜流
## （参照里 eval 清队伍没生效，出战五人，放血扣四个队友）；队友 1 生命可另设
func _battle(level: int, rank: int, ally_hp := -1.0) -> Array:
	var s := _new_game()
	s.actor_advance[XYomiJingliu.JINGLIU] = rank
	var a := s.actor(XYomiJingliu.JINGLIU)
	a.change_level_mv(level)
	if rank >= 1:
		for id in [10200, 10201, 10202]:
			a.learn_skill(id)
	for id in [1, 8, 9, 10]:
		s.add_actor(id)  # 参照 newGame 的队伍
	XYomiJingliu.recruit(s, XYomiJingliu.JINGLIU)
	s.gain_gear("weapon", 2, 1)
	XEquipment.change(s, a, 0, s.gear[s.gear.size() - 1])
	s.add_actor(1)
	var logic := _logic(s)
	if ally_hp >= 0.0:
		s.actor(1).hp = ally_hp
	XYomiJingliu._blood.clear()
	logic.start_turn()
	return [logic, a, s.actor(1)]


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _snap(logic: XBattleLogic, a: XActor, one: XActor) -> Dictionary:
	var k = a.get_instance_id()
	return {"moon": XYomiJingliu.moon(a), "bloom": bool(XYomiJingliu._bloom.get(k, false)), "blood": float(XYomiJingliu._blood.get(k, 0.0)), "allyHp": one.hp,
		"frost": logic.enemies.map(func(e): return e.state_ids.has(XYomiJingliu.J_FROST)), "gap": logic.enemies.map(func(e): return e.state_ids.has(XYomiJingliu.J_GAP)),
		"def": logic.enemies.map(func(e): return e.def), "ice": logic.enemies.map(func(e): return snappedf(e.element_rate(3), 1e-9)),
		"queued": logic.current_order.count(a), "moonExtra": bool(XYomiJingliu._moon_extra.get(k, false)), "bloodExtra": bool(XYomiJingliu._blood_extra.get(k, false))}


func _hits(logic: XBattleLogic, a, logs: Array) -> Array:
	var out := []
	for l in logs:
		if l.get("type") == "hit" and l.get("user") == a and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)) and int(l.skill.get("damage", {}).get("type", 0)) in [1, 5]:
			out.append({"skill": int(l.skill.id), "target": _key(logic, l.target), "value": float(l.hp), "extra": bool(l.get("supplemental", false))})
	return out


func _cast(logic: XBattleLogic, a: XActor, one: XActor, id: int, target: int) -> Dictionary:
	a.mp = a.mmp
	a.tp = a.max_tp()
	var q0 := logic.current_order.count(a)
	var log := _hits(logic, a, logic.act(a, XDB.rec("Skills", id), logic.enemies[target]))
	var out := _snap(logic, a, one).merged({"cast": id, "log": log}, true)
	out["queuedAdded"] = int(out.queued) - q0
	return out


const STATE_KEYS := ["moon", "bloom", "blood", "allyHp", "frost", "gap", "def", "ice", "queued", "moonExtra", "bloodExtra", "queuedAdded"]


func _norm(v):
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float or v is int:
		return snappedf(float(v), 1e-9)
	return v


func _compare(id: String, got_steps: Array, want_steps: Array) -> void:
	check(id + ".steps", got_steps.size() == want_steps.size(), [got_steps.size(), want_steps.size()])
	var base := [0.0, 0.0]
	for i in mini(got_steps.size(), want_steps.size()):
		var g: Dictionary = got_steps[i]
		var w: Dictionary = want_steps[i]
		var sid := "%s.%d" % [id, i]
		if w.has("log"):
			var gl: Array = g.get("log", [])
			var wl: Array = w.log
			var gs := gl.map(func(l): return [l.skill, l.target, l.extra])
			var ws := wl.map(func(l): return [int(l.skill), str(l.target), bool(l.extra)])
			check(sid + ".log", gs == ws, [gs, ws])
			if gs == ws:
				for k in gs.size():
					if base[0] == 0.0:
						base = [float(gl[k].value), float(wl[k].value)]
					var rg: float = float(gl[k].value) / base[0]
					var rw: float = float(wl[k].value) / base[1]
					check("%s.ratio%d" % [sid, k], absf(rg - rw) <= RATIO_TOLERANCE * maxf(1.0, absf(rw)), [gl[k].value, wl[k].value, rg, rw])
		var keys := STATE_KEYS.filter(func(k): return w.has(k))
		var got := keys.map(func(k): return _norm(g.get(k)))
		var want := keys.map(func(k): return _norm(w[k]))
		check(sid + ".state", got == want, [keys, got, want])


func _seq(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(60, int(c.setup.rank))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var learned := a.skill_ids.filter(func(i): return i >= 10187)
	learned.sort()
	check(c.id + ".skills", learned == (o.skills as Array).map(func(v): return int(v)), [learned, o.skills])
	check(c.id + ".mhp", [a.mhp, r[2].mhp] == [float(o.mhp), float(o.allyMhp)], [a.mhp, r[2].mhp, o.mhp, o.allyMhp])
	var steps := [_snap(logic, a, r[2])]
	for st in c.setup.script:
		XYomiJingliu._moon[a.get_instance_id()] = 3
		steps.append(_cast(logic, a, r[2], int(st[0]), int(st[1])))
	_compare(c.id, steps, o.steps)


func _extra(c: Dictionary) -> void:
	var r := _battle(60, 0)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var k = a.get_instance_id()
	var steps := []
	XYomiJingliu._moon[k] = 0
	steps.append(_cast(logic, a, r[2], 10189, 0))
	XYomiJingliu._moon[k] = 1
	steps.append(_cast(logic, a, r[2], 10189, 0))
	logic.end_turn()
	logic.start_turn()
	steps.append(_snap(logic, a, r[2]))
	XYomiJingliu._moon[k] = 0
	steps.append(_cast(logic, a, r[2], 10187, 1))
	logic.end_battle(0)
	steps.append(_snap(logic, a, r[2]))
	_compare(c.id, steps, c.observed.steps)


func _load(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_game()
	var a := s.actor(XYomiJingliu.JINGLIU)
	a.change_level_mv(30)
	s.actor_advance[XYomiJingliu.JINGLIU] = int(c.setup.rank)
	XYomiJingliu._blood[a.get_instance_id()] = 123.0
	var before := a.skill_ids.filter(func(i): return i >= 10187)
	before.sort()
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	var b := back.actor(XYomiJingliu.JINGLIU)
	var after := b.skill_ids.filter(func(i): return i >= 10187)
	after.sort()
	check(c.id, [before, after, float(XYomiJingliu._blood.get(b.get_instance_id(), 0.0))] == [(o.before as Array).map(func(v): return int(v)), (o.after as Array).map(func(v): return int(v)), float(o.blood)], [before, after, o])


func _raven(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_game()
	s.actor_advance[XRaven.ACTOR] = 5
	var a := s.actor(XRaven.ACTOR)
	a.change_level_mv(60)
	XRaven.recruit(s)
	s.add_actor(1)
	if c.setup.affix != null:
		var made := XAlienation.create(s, "w", int(o.base), "boss", str(c.setup.affix))
		a.equips[0] = made.ok
	else:
		s.gain_gear("weapon", int(o.base), 1)
		XEquipment.change(s, a, 0, s.gear[s.gear.size() - 1])
	var logic := _logic(s)
	XAlienBattle.lock_party(logic)
	logic.start_turn()
	var e = logic.enemies[0]
	var st: Dictionary = XState.current.raven
	for i in (o.steps as Array).size():
		var w: Dictionary = o.steps[i]
		if bool(w.myth):
			a.mp = a.mmp
			logic.act(a, XDB.rec("Skills", XRaven.MYTH), a)
		st["residue"] = 3
		st["hunter"] = true
		a.mp = a.mmp
		var hp0: float = e.hp
		var logs := logic.act(a, XDB.rec("Skills", XRaven.PECK), e)
		var lost: float = hp0 - e.hp
		var hits := logs.filter(func(l): return l.get("type") == "hit" and l.get("user") == a and int(l.skill.id) == XRaven.PECK)
		var locked = XAlienBattle.locked(a)
		var got := [lost == 0.0, hits.size(), XRaven.hunter(a), locked.affix if locked != null else null]
		var want := [float(w.lost) == 0.0, (w.log as Array).size(), bool(w.hunter), w.locked]
		check("%s.%d" % [c.id, i], got == want, [got, want, lost, w.lost])


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
			"seq":
				_seq(c)
			"blood":
				var r := _battle(60, 1, 1.0)
				XYomiJingliu._moon[r[1].get_instance_id()] = 3
				_compare(c.id, [_cast(r[0], r[1], r[2], 10192, 0)], c.observed.steps)
			"extra":
				_extra(c)
			"load":
				_load(c)
			"raven":
				_raven(c)
	check("covers_all", seen.keys().size() == 5, seen.keys())
	# 开战清放血累计（startBattle 包装；参照没量，读码）
	var r := _battle(60, 1)
	XYomiJingliu._blood[r[1].get_instance_id()] = 99.0
	XYomiJingliu.start_battle(r[0])
	check("start_battle.blood", not XYomiJingliu._blood.has(r[1].get_instance_id()))
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_jingliu2", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
