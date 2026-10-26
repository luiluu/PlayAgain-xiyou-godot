extends Node
## 种族祝福的能力值与战斗效果（XRaceBattle）：逐例对照 mv_oracle/race_battle_probe.cjs（generated/oracle/race_battle.json）。
## - params.*：角色 1（练习剑）30 级，七族 × 1／4／7 阶与无祝福，比种族数据、种族技能、q、八项 param／paramPlus、
##   技能 8／9／10／72／101 的 MP／TP 消耗、武器本体值。
## - battle.*：角色 1＋8 出战，敌群 2／6（敌人生命加 1e12），随机数全取 0.5（同参照 Math.random）；每步按回合号行动（行动前 TP 100、
##   法力回满），回合末直接调 XRaceBattle.round_end；比各敌人生命与毒鸡汤状态、角色生命／法力／TP、队友生命、角色的本场种族数据、提示。
const ORACLE := "oracle/race_battle.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _close(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(float(a[i]) - float(b[i])) > maxf(1e-6, absf(float(b[i])) * 1e-9):
			return false
	return true


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		get_tree().quit.call_deferred(1)
		return
	for c in ref.cases:
		if not check(str(c.id) + ".oracle_clean", (c.errors as Array).is_empty(), c.errors):
			continue
		if str(c.id).begins_with("params."):
			_params(c)
		else:
			_battle(c)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


static func _set_race(s: XState, a: XActor, race: int, rank: int, blood := false) -> void:
	XRace.data(s, a)
	s.race.actors[str(a.actor_id)] = {"race": race, "rank": rank, "free": race < 0, "blood": blood, "legacy": []}
	XRace.sync(s, a)


static func _race_skills(a: XActor) -> Array:
	return a.skill_ids.filter(func(id): return not XRace.skill_info(id).is_empty())


func _params(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var st: Dictionary = c.setup
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	XState.current = s
	var a := s.actor(1)
	a.change_level_mv(int(st.level))
	_set_race(s, a, int(st.race), int(st.rank))
	a.param_mark_dirty()
	a.refresh_passive()
	var tag := str(c.id)
	check(tag + ".race", _race_skills(a) == (o.raceSkills as Array).map(func(v): return int(v)) and is_equal_approx(XRaceBattle.rate_of(a), float(o.rate)),
		[_race_skills(a), XRaceBattle.rate_of(a), o.raceSkills, o.rate])
	var got := range(8).map(func(i): return a.param(i))
	check(tag + ".param", _close(got, o.param), [got, o.param])
	got = range(8).map(func(i): return a.param_plus(i))
	check(tag + ".paramPlus", _close(got, o.paramPlus), [got, o.paramPlus])
	var w = a.equips[0] if a.equips.size() > 0 and a.equips[0] is Dictionary else {}
	got = range(8).map(func(i): return XRaceBattle.weapon_body(w, i))
	check(tag + ".weaponBody", _close(got, o.weaponBody), [got, o.weaponBody])
	var logic := XBattleLogic.new()
	var mp := []
	var tp := []
	for id in st.skills:
		var cost := logic.skill_cost(a, XDB.rec("Skills", int(id)))
		mp.append(cost.mp)
		tp.append(cost.tp)
	check(tag + ".cost", _close(mp, o.mpCost) and _close(tp, o.tpCost), [mp, tp, o.mpCost, o.tpCost])


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648


func _label(x, a, b, enemies: Array):
	if x == null:
		return null
	var i := enemies.find(x)
	if i >= 0:
		return "e%d" % i
	if x == a:
		return "a"
	if x == b:
		return "b"
	return "?"


func _race_state(logic, a, b, enemies: Array) -> Dictionary:
	var s: Dictionary = XRaceBattle.state(logic, a)
	var out := {}
	for k in ["godTurn", "bloodTurn", "capTurn", "gainTurn", "spendTurn", "echoTurn"]:
		out[k] = int(s[k])
	out.humanExtra = bool(s.humanExtra)
	for k in ["ghostPrevious", "ghostCurrent"]:
		out[k] = {"group": int(s[k].group), "turn": int(s[k].turn)} if s[k] != null else null
	out.counter = {"target": _label(s.counter.target, a, b, enemies), "until": int(s.counter.until)} if s.counter != null else null
	out.cap = {"spent": float(s.cap.spent)} if s.cap != null else null
	out.poison = (s.poison as Array).map(func(p): return {"target": _label(p.target, a, b, enemies), "id": int(p.id), "amount": snappedf(float(p.amount), 1e-6), "turn": int(p.turn)})
	out.lastPrey = _label(s.lastPrey, a, b, enemies)
	return out


static func _norm(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = _norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float or v is int:
		return snappedf(float(v), 1e-6)
	return v


func _battle(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var st: Dictionary = c.setup
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	XState.current = s
	var a := s.actor(1)
	var b := s.actor(8)
	a.change_level_mv(30)
	b.change_level_mv(30)
	_set_race(s, a, int(st.race), int(st.rank), bool(st.get("blood", false)))
	s.party.clear()
	s.battle_slots.clear()
	s.add_actor(1)
	s.add_actor(8)
	var rand := XBattleRandom.create("0000000000000176")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(int(st.troop), s, rand)
	var enemies: Array = logic.enemies
	for e in enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		p[2] += float(st.get("enemyAtkPlus", 0))
		e.zq_ref = {"p": p, "k": 1.0}
	for x in [a, b] + enemies:
		x.param_mark_dirty()
		x.param_refresh()
		x.recover_all()
	XRaceBattle.start(logic)  # 参照在调好敌人与回满之后才建本场数据（startBattle 的最后一步）
	var tag := str(c.id)
	check(tag + ".actor", a.atk == float(o.atk) and a.mat == float(o.mat) and a.mhp == float(o.mhp), [a.atk, a.mat, a.mhp, o.atk, o.mat, o.mhp])
	var ep := []
	for i in enemies.size():
		ep.append(_close(range(8).map(func(k): return enemies[i].param(k)), o.enemies[i].params))
	check(tag + ".enemies", ep.all(func(x): return x), [range(8).map(func(k): return enemies[0].param(k)), o.enemies[0].params])
	var poisons: Array = XRace.config().poisons
	for i in o.rows.size():
		var row: Dictionary = o.rows[i]
		var step := "%s.%d" % [tag, i]
		var toasts := []
		if row.has("roundEnd"):
			logic.turn = int(row.roundEnd)
			for l in XRaceBattle.round_end(logic):
				if l.type == "toast":
					toasts.append(l.text)
		elif row.has("set"):
			var set: Dictionary = row.set
			if set.has("blood"):
				s.race.actors["1"].blood = bool(set.blood)
			if set.has("enemyHpRate"):
				var e: XEnemy = enemies[int(set.get("enemy", 0))]
				e.hp = floorf(e.mhp * float(set.enemyHpRate))
			if set.has("allyHpRate"):
				b.hp = floorf(b.mhp * float(set.allyHpRate))
			continue
		else:
			var sp: Dictionary = row.step
			logic.turn = int(sp.round)
			var user: XBattler = a
			var who := str(sp.get("user", "a"))
			if who == "b":
				user = b
			elif who.begins_with("e"):
				user = enemies[int(who.substr(1))]
			user.tp = 100.0
			user.mp = user.mmp
			var skill := XDB.rec("Skills", int(sp.skill))
			var ti := int(sp.get("target", 0))
			var target: XBattler
			if int(skill.scope) in [7, 8, 9, 10, 11]:
				target = (logic.actors if user is XActor else enemies)[ti]
			else:
				target = (enemies if user is XActor else logic.actors)[ti]
			for l in logic.act(user, skill, target):
				if l.type == "toast":
					toasts.append(l.text)
		var hp := enemies.map(func(e): return e.hp)
		var want_hp: Array = (row.enemies as Array).map(func(e): return float(e.hp))
		check(step + ".enemy_hp", _close(hp, want_hp), [hp, want_hp, row.get("step")])
		var pz := enemies.map(func(e): return poisons.filter(func(id): return e.state_ids.has(int(id))).map(func(id): return int(id)))
		var want_pz: Array = (row.enemies as Array).map(func(e): return (e.poisons as Array).map(func(v): return int(v)))
		check(step + ".poisons", pz == want_pz, [pz, want_pz])
		check(step + ".actor", _close([a.hp, a.mp, b.hp], [row.a.hp, row.a.mp, row.b.hp]), [[a.hp, a.mp, b.hp], [row.a.hp, row.a.mp, row.b.hp]])
		check(step + ".tp", _close([a.tp], [row.a.tp]), [a.tp, row.a.tp])
		var rs = _norm(_race_state(logic, a, b, enemies))
		var want_rs = _norm(row.race)
		check(step + ".race_state", rs == want_rs, [rs, want_rs])
		check(step + ".toasts", toasts == row.toasts, [toasts, row.toasts])
	XState.current = null
