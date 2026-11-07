extends Node
## 【cc·白龙·未经审查】至尊宝 36 真火印记追击（XZhenhuo）：与 mv_oracle/zhenhuo_probe.cjs 的新源 v0.62.12 参照
## （tests/fixtures/zhenhuo_oracle.json）逐例比。
## - mark.*：1083／1086 学没学 1089：命中目标序列、各敌人印记与回合数、至尊宝 109、排队的强制行动；
## - chase.*：0 号先挂印记（来源至尊宝），至尊宝／角色 1 放 1086（火）或普攻（无火）：排队的强制行动；
## - scale.*：1090 学 1089 与否逐段伤害之比＝0.6＋1%×等级；
## - state109：角色能不能挂 109。
## 原版 109 屏蔽没生效（O-234，XZhenhuo.FIX_OLD_CHASE）：开关关着逐项比原版（旧自动施法的目标＝至尊宝我方队位，
## 原版队伍 5 人在 4 号、重制在 0 号，换算后比）；开着时比「去掉 109 与旧自动施法」后的原版。
const FIXTURE := "res://tests/fixtures/zhenhuo_oracle.json"
const ZZB := 36
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 15:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648

	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		next_uint(reason, event_key)
		return n / 2 if n > 0 else 0

	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		next_uint(reason, event_key)
		return lo + (hi - lo + 1) / 2


## 同参照 battle()：新局、队伍 [36, 1] 各 55 级、生命加 1e12；至尊宝先忘 1089 再学 learn；敌群 3 每只生命加 1e12；规则流全取 0.5
func _battle(learn: Array) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.party.clear()
	s.battle_slots.clear()
	for id in [ZZB, 1]:
		var b := s.actor(id)
		b.change_level_mv(55)
		b.add_param(0, 1e12)
	var a := s.actor(ZZB)
	a.skill_ids.erase(XZhenhuo.PASSIVE)
	for id in learn:
		if not a.skill_ids.has(int(id)):
			a.skill_ids.append(int(id))
	s.add_actor(ZZB)
	s.add_actor(1)
	a.refresh_passive()
	var rand := XBattleRandom.create("0000000000000036")
	rand.rule = HalfStream.new()
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
	XStateEffects.take_forces()
	XZhenhuo.reset()
	return [logic, a, s.actor(1)]


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _view(logic: XBattleLogic, a: XActor) -> Dictionary:
	return {"marks": logic.enemies.map(func(e): return e.is_state_affected(XZhenhuo.MARK)),
		"turns": logic.enemies.map(func(e): return int(e.state_turns.get(XZhenhuo.MARK, 0)) if e.is_state_affected(XZhenhuo.MARK) else 0),
		"owner109": a.is_state_affected(XZhenhuo.OLD_CHASE),
		"forces": XStateEffects.take_forces().map(func(f): return (f as Array).map(func(v): return int(v)))}


## 参照的期望：fix 开着时去掉 109 与按队位排的旧自动施法；关着时旧自动施法目标换成重制的队位
func _want(o: Dictionary, logic: XBattleLogic, a: XActor, fix: bool) -> Dictionary:
	var old_index := int(o.ownerIndex)
	var forces := []
	for f in o.forces:
		var g: Array = (f as Array).map(func(v): return int(v))
		if g[3] == old_index:
			if fix:
				continue
			g[3] = logic.actors.find(a)
		forces.append(g)
	return {"marks": o.marks.map(func(v): return bool(v)), "turns": o.turns.map(func(v): return int(v)),
		"owner109": bool(o.owner109) and not fix, "forces": forces}


func _compare(id: String, got: Dictionary, want: Dictionary) -> void:
	for k in want:
		check(id + "." + k, got[k] == want[k], [got[k], want[k]])


func _mark(c: Dictionary, fix: bool) -> void:
	XZhenhuo.FIX_OLD_CHASE = fix
	var o: Dictionary = c.observed
	var r := _battle(c.setup.learn)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var logs := logic.execute(a, XDB.rec("Skills", int(c.setup.skill)), logic.enemies[0])
	var hits := logs.filter(func(l): return l.get("type") == "hit" and l.get("user") == a).map(func(l): return _key(logic, l.target))
	var id := "%s.%s" % [c.id, "fix" if fix else "orig"]
	check(id + ".log", hits == o.log.map(func(v): return str(v)), [hits, o.log])
	_compare(id, _view(logic, a), _want(o, logic, a, fix))


func _chase(c: Dictionary, fix: bool) -> void:
	XZhenhuo.FIX_OLD_CHASE = fix
	var o: Dictionary = c.observed
	var r := _battle(c.setup.learn)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var t: XEnemy = logic.enemies[0]
	XZhenhuo.mark(logic, t)
	t.state_origins[XZhenhuo.MARK] = weakref(a)  # 参照 Z.mark 时 BattleManager._subject＝至尊宝
	var marked := logic.enemies.map(func(e): return e.is_state_affected(XZhenhuo.MARK))
	var id := "%s.%s" % [c.id, "fix" if fix else "orig"]
	check(id + ".markedBefore", marked == o.markedBefore.map(func(v): return bool(v)), [marked, o.markedBefore])
	XStateEffects.take_forces()
	var u: XActor = a if int(c.setup.user) == ZZB else r[2]
	logic.execute(u, XDB.rec("Skills", int(c.setup.skill)), t)
	# 原版探针不跑事件，排进强制行动公共事件后本次行动就停在第一段，序列末的 Add State 108 与行动结束减回合都没跑，回合数不比
	var want := _want(o, logic, a, fix)
	want.erase("turns")
	_compare(id, _view(logic, a), want)


func _scale(ref: Array) -> void:
	var by := {}
	for c in ref:
		if str(c.id).begins_with("scale.") and c.errors.is_empty():
			by[c.id] = c
	if not check("scale.oracle", by.has("scale.p1089") and by.has("scale.p1089.noscale") and by.has("scale.plain"), by.keys()):
		return
	var got := {}
	for k in ["scale.p1089", "scale.plain"]:
		var r := _battle(by[k].setup.learn)
		var logic: XBattleLogic = r[0]
		var a: XActor = r[1]
		var logs := logic.execute(a, XDB.rec("Skills", XZhenhuo.CHASE), logic.enemies[0])
		got[k] = logs.filter(func(l): return l.get("type") == "hit" and l.get("user") == a).map(func(l): return floorf(float(l.hp)))
		check(k + ".hits", got[k].size() == by[k].observed.log.size(), [got[k], by[k].observed.log])
	var a_level := float(by["scale.p1089"].observed.scale)
	check("scale.factor", absf(XZhenhuo.scale_of(_battle([])[1]) - a_level) < 1e-9, [a_level])
	# 原版 p1089 ÷ p1089.noscale（只差本模块倍率）与重制 p1089 ÷ plain 比；参照关了五乘区，逐段绝对伤害也比
	for i in range(mini(got["scale.p1089"].size(), got["scale.plain"].size())):
		var want_ratio := float(by["scale.p1089"].observed.log[i].value) / float(by["scale.p1089.noscale"].observed.log[i].value)
		var got_ratio: float = got["scale.p1089"][i] / maxf(1.0, got["scale.plain"][i])
		check("scale.ratio.%d" % i, absf(got_ratio - want_ratio) < 1e-6, [got_ratio, want_ratio])
		for k in ["scale.p1089", "scale.plain"]:
			check("%s.value.%d" % [k, i], got[k][i] == float(by[k].observed.log[i].value), [got[k][i], by[k].observed.log[i].value])


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
				check("module", int(c.observed.chase) == XZhenhuo.CHASE)
			"mark":
				_mark(c, false)
				_mark(c, true)
			"chase":
				_chase(c, false)
				_chase(c, true)
			"state109":
				for fix in [false, true]:
					XZhenhuo.FIX_OLD_CHASE = fix
					var r := _battle([XZhenhuo.PASSIVE])
					r[1].add_state(XZhenhuo.OLD_CHASE)
					check("state109." + ("fix" if fix else "orig"), r[1].is_state_affected(XZhenhuo.OLD_CHASE) == (bool(c.observed.owner109) and not fix))
	_scale(ref.cases)
	XZhenhuo.FIX_OLD_CHASE = true
	check("covers_all", seen.keys().size() == 5, seen.keys())
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_zhenhuo", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
