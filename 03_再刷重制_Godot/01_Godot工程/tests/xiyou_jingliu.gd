extends Node
## 【cc·白龙_8·未经审查】170 镜流第一期（XYomiJingliu 的镜流部分：setup／param_base／j_formula／j_damage_ops／sure／begin_action／meets／pay／
## j_applied／j_finish／start_turn／end_battle，招募）：与 mv_oracle/jingliu_probe.cjs 的冻结 v0.28 参照（tests/fixtures/jingliu_oracle.json）逐例比。
## - skills.*：新建角色升到各级后的已学技能、八项能力值、最大生命与攻击的 paramBase（星魂 20／35／40 级）；params.no10194：忘掉命途：毁灭不吃星魂；
## - formula：七个剑技 × 月魄 0～3 × 目标霜痕／裂隙，公式值逐条比（1e-9 相对误差，伤害计算外、含守势项）；别人用为 0；
## - recruit：入队、月魄剑匣装进槽、已在队返回否；
## - battle.*：开回合月魄 3、强化剑技扣 1、10187／10189／10191 命中与 10193 回月魄（45 级 +2、20 级 +1）、霜痕／裂隙、月魄 0 时强化剑技不能用、
##   结束战斗清零；剑技段数与必中（扣血段逐条比目标，数值比本例第一段的比值）；
## - hook.lv45：卸下剑匣、忘掉命途：毁灭前后的伤害比值（剑匣普通伤害 +0.25、星魂寒冰加成与 ×2）。
## 强化剑技的伤害不比（放血、追加段是第二期）。
const FIXTURE := "res://tests/fixtures/jingliu_oracle.json"
const RATIO_TOLERANCE := 1e-6
const ENHANCED := [10188, 10190, 10192]
var results := []


## 规则流全取 0.5；整数照 Math.randomInt 取中点（同 xiyou_raven_battle）
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
	var out := a.skill_ids.filter(func(i): return i >= 10187 and i <= 10202)
	out.sort()
	return out


func _params(a: XActor) -> Array:
	return range(8).map(func(i): return a.param(i))


## 同参照 battle()：level 级、招募、给编号 weapon 的剑、再入队 1；全队与敌群 3 生命加 1e12；开第一回合
func _battle(level: int, weapon: int) -> Array:
	var s := _new_game()
	s.party.clear()
	s.battle_slots.clear()
	var a := s.actor(XYomiJingliu.JINGLIU)
	a.change_level_mv(level)
	check("setup.recruit", XYomiJingliu.recruit(s, XYomiJingliu.JINGLIU).size() == 2)
	if weapon > 0:
		s.gain_gear("weapon", weapon, 1)
		XEquipment.change(s, a, 0, s.gear[s.gear.size() - 1])
	s.add_actor(1)
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
	logic.start_turn()
	return [logic, a]


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _snap(logic: XBattleLogic, a: XActor) -> Dictionary:
	a.mp = a.mmp
	a.tp = a.max_tp()
	return {"moon": XYomiJingliu.moon(a), "frost": logic.enemies.map(func(e): return e.state_ids.has(XYomiJingliu.J_FROST)),
		"gap": logic.enemies.map(func(e): return e.state_ids.has(XYomiJingliu.J_GAP)),
		"meets": ENHANCED.map(func(id): return logic.can_use(a, XDB.rec("Skills", id)))}


func _cast(logic: XBattleLogic, a: XActor, id: int, target: int) -> Dictionary:
	a.mp = a.mmp
	a.tp = a.max_tp()
	var logs := logic.act(a, XDB.rec("Skills", id), logic.enemies[target])
	var hits := []
	for l in logs:
		if l.get("type") == "hit" and l.get("user") == a and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)):
			hits.append({"skill": int(l.skill.id), "target": _key(logic, l.target), "value": float(l.hp), "critical": bool(l.critical)})
	return _snap(logic, a).merged({"cast": id, "log": hits}, true)


func _compare(id: String, got_steps: Array, want_steps: Array) -> void:
	check(id + ".steps", got_steps.size() == want_steps.size(), [got_steps.size(), want_steps.size()])
	var base := [0.0, 0.0]
	for i in mini(got_steps.size(), want_steps.size()):
		var g: Dictionary = got_steps[i]
		var w: Dictionary = want_steps[i]
		var sid := "%s.%d" % [id, i]
		if w.has("log") and not ENHANCED.has(int(w.get("cast", 0))):
			var gl: Array = g.get("log", [])
			var wl: Array = w.log
			var gs := gl.map(func(l): return [l.skill, l.target, l.critical])
			var ws := wl.map(func(l): return [int(l.skill), str(l.target), bool(l.critical)])
			check(sid + ".log", gs == ws, [gs, ws])
			if gs == ws:
				for k in gs.size():
					if base[0] == 0.0:
						base = [float(gl[k].value), float(wl[k].value)]
					var rg: float = float(gl[k].value) / base[0]
					var rw: float = float(wl[k].value) / base[1]
					check("%s.ratio%d" % [sid, k], absf(rg - rw) <= RATIO_TOLERANCE * maxf(1.0, absf(rw)), [gl[k].value, wl[k].value, rg, rw])
		var got := [int(g.moon), g.frost, g.gap, g.meets]
		var want := [int(w.moon), (w.frost as Array).map(func(v): return bool(v)), (w.gap as Array).map(func(v): return bool(v)), (w.meets as Array).map(func(v): return bool(v))]
		check(sid + ".state", got == want, [got, want])


func _skills_case(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_game()
	var a := s.actor(XYomiJingliu.JINGLIU)
	a.change_level_mv(int(c.setup.level))
	if c.id == "params.no10194":
		a.forget_skill(10194)
		a.refresh_passive()
	check(c.id + ".skills", _skills(a) == _ints(o.skills), [_skills(a), o.skills])
	check(c.id + ".params", _params(a) == (o.params as Array).map(func(v): return float(v)), [_params(a), o.params])
	if o.has("mhpBase"):
		check(c.id + ".base", [a.param_base(0), a.param_base(2)] == [float(o.mhpBase), float(o.atkBase)], [a.param_base(0), a.param_base(2), o.mhpBase, o.atkBase])


func _formula(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_game()
	var a := s.actor(XYomiJingliu.JINGLIU)
	a.change_level_mv(45)
	check("formula.params", [a.atk, a.mhp] == [float(o.atk), float(o.mhp)], [a.atk, a.mhp, o.atk, o.mhp])
	var e := XEnemy.new().setup(3, s.difficulty, 100.0)
	var bad := 0
	for row in o.rows:
		e.state_ids.clear()
		for sid in row.marks:
			e.state_ids.append(int(sid))
		XYomiJingliu._moon[a.get_instance_id()] = int(row.moon)
		var v := XYomiJingliu.j_formula(a, e, XDB.rec("Skills", int(row.id)), false)  # 参照在伤害计算外调，含守势项
		if absf(v - float(row.value)) > 1e-9 * maxf(1.0, absf(float(row.value))):
			bad += 1
			if bad <= 3:
				check("formula.%d.%d.%s" % [int(row.id), int(row.moon), str(row.marks)], false, [v, row.value])
	check("formula.rows", bad == 0 and (o.rows as Array).size() == 112, [bad, (o.rows as Array).size()])
	XYomiJingliu._moon.clear()
	check("formula.other", XYomiJingliu.j_formula(s.actor(1), e, XDB.rec("Skills", 10187)) == float(o.other))


func _recruit(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_game()
	s.party.clear()
	s.battle_slots.clear()
	var first := XYomiJingliu.recruit(s, XYomiJingliu.JINGLIU)
	var a := s.actor(XYomiJingliu.JINGLIU)
	var slot := a.equip_slots().find(int(XDB.rec("Armors", XYomiJingliu.J_ARMOR).etypeId))
	var worn = a.equips[slot]
	check("recruit", [not first.is_empty(), XYomiJingliu.recruit(s, XYomiJingliu.JINGLIU).is_empty(), slot, int(worn.get("base", 0)) if worn is Dictionary else 0]
		== [bool(o.first), not bool(o.again), int(o.slot), int(o.worn)], [first, slot, worn, o])
	check("recruit.party", s.party.has(XYomiJingliu.JINGLIU))


func _battle_case(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var level := int(c.setup.level)
	var r := _battle(level, int(o.weapon))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	check(c.id + ".skills", _skills(a) == _ints(o.skills), [_skills(a), o.skills])
	var steps := [_snap(logic, a)]
	steps.append(_cast(logic, a, 10190, 0))
	XYomiJingliu._moon[a.get_instance_id()] = 0
	steps.append(_cast(logic, a, 10187, 1))
	steps.append(_cast(logic, a, 10189, 2))
	if level >= 30:
		steps.append(_cast(logic, a, 10191, 0))
	if level >= 45:
		steps.append(_cast(logic, a, 10193, 0))
	XYomiJingliu._moon[a.get_instance_id()] = 0
	steps.append(_snap(logic, a))
	logic.end_battle(0)
	steps.append(_snap(logic, a))
	_compare(c.id, steps, o.steps)


func _hook(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(45, int(o.weapon))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var s := XState.current
	var steps := [_cast(logic, a, 10187, 0), _cast(logic, a, 10191, 0)]
	XEquipment.change(s, a, a.equip_slots().find(int(XDB.rec("Armors", XYomiJingliu.J_ARMOR).etypeId)), null)
	steps.append(_cast(logic, a, 10187, 0))
	a.forget_skill(10194)
	a.refresh_passive()
	a.param_mark_dirty()
	a.param_refresh()
	steps.append(_cast(logic, a, 10187, 0))
	_compare(c.id, steps, o.steps)


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	check("slice_has_170", not XDB.rec("Actors", XYomiJingliu.JINGLIU).is_empty())
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match kind:
			"skills", "params":
				_skills_case(c)
			"formula":
				_formula(c)
			"recruit":
				_recruit(c)
			"battle":
				_battle_case(c)
			"hook":
				_hook(c)
	check("covers_all", seen.keys().size() == 6, seen.keys())
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_jingliu", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
