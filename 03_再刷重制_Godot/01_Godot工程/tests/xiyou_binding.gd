extends Node
## 【cc·白龙_14·未经审查】形态绑定与行动充能框架 XBinding：照参照 binding_probe（tests/fixtures/binding_oracle.json）逐步比。
## 同参照登记一个只给测试用的种类 probe（本体 9 号，形态状态 367、充能耗尽状态 654），回调只记事件；队伍新局的 1、8、9、10，
## 打 3 号敌群（敌人生命加 1e9），规则流全取 0.5，推进到第一回合。每步比：返回值、事件、命中（技能、出手者、目标、生命伤害）、
## 四人的绑定数据、两个状态、生命、存活、不可命中、宿主，回合数，出战成员。
const FIXTURE := "res://tests/fixtures/binding_oracle.json"
const OWNER := 9
const FORM := 367
const EMPTY := 654
const PARTY := [1, 8, 9, 10]
var checks := 0
var failures: Array = []
var events: Array = []
var opt := {"manual": false, "deny": 0}
var logic: XBattleLogic


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(900))


## 同参照 Math.random 0.5；整数照 Math.randomInt 取中点（直接返回 2147483648 时伤害浮动会乱跳，见 xiyou_raven_battle）
class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648
	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return floori(n * 0.5) if n > 0 else 0
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return lo + floori((hi - lo + 1) * 0.5)


func _key(b) -> Variant:
	if b == null:
		return null
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _register() -> void:
	XBinding.register("probe", {
		"is_owner": func(a): return a.actor_id == OWNER, "form_state": FORM, "empty_state": EMPTY,
		"manual": func(_a): return bool(opt.manual),
		"can_host": func(_o, t): return t.actor_id != int(opt.deny),
		"on_bind": func(o, t, reason, prev): events.append(["bind", _key(o), _key(t), reason, _key(prev)]),
		"on_unbind": func(o, h, reason): events.append(["unbind", _key(o), _key(h), reason]),
		"on_round_start": func(a, n): events.append(["roundStart", _key(a), n]),
		"on_round_end": func(a): events.append(["roundEnd", _key(a), XBinding.charges(a)]),
		"on_round_close": func(a): events.append(["roundClose", _key(a), XBinding.charges(a)]),
		"on_clear": func(a): events.append(["clear", _key(a)]),
	})


func _battle() -> XBattleLogic:
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	for id in PARTY:
		s.actor(id).recover_all()
	var l := XBattleLogic.new()
	l.elite_roll = 99.0
	l.level_roll = 0.99
	var rand := XBattleRandom.create("0000000000000009")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	l.setup(3, s, rand)
	for e in l.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e9
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
	l.start_turn()
	for b in l.actors + l.enemies:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	return l


func _who(x):
	if x is String and x.begins_with("e"):
		return logic.enemies[int(x.substr(1))]
	return logic.state.actor(int(x))


func _snap() -> Dictionary:
	var party := {}
	for id in PARTY:
		var a: XActor = logic.state.actor(id)
		var d = XBinding.data(a)
		party["a%d" % id] = {"data": null if d == null else {"charges": int(d.charges), "hostId": int(d.host_id), "boundRound": int(d.bound_round),
			"returnedRound": int(d.returned_round)}, "form": a.is_state_affected(FORM), "empty": a.is_state_affected(EMPTY), "hp": a.hp,
			"alive": a.is_alive(), "untargetable": XBinding.untargetable(a), "host": _key(XBinding.host(a)), "bound": XBinding.is_bound(a)}
	return {"round": XBinding.current_round(), "party": party, "members": logic.actors.map(func(b): return _key(b))}


func _hits(logs: Array) -> Array:
	var out := []
	for l in logs:
		if l is Dictionary and l.get("type") == "hit" and not bool(l.get("unused", false)) and not bool(l.missed) and not bool(l.evaded) \
				and int(l.skill.get("damage", {}).get("type", 0)) in [1, 3, 5]:
			out.append(["hp", _key(l.user), _key(l.target), float(l.hp)])
	return out


func _set_hp(a, v: float) -> void:
	var rc := logic._operation_resources(a)
	rc.set_resource(a, "hp", v)
	logic._finish_lifecycle_operation(rc, a)


## 参照的 JSON 数字都是 float：整数值转 int 再比
func _norm(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = _norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	return v


func _step(st: Array):
	var op: String = st[0]
	var ret = null
	var logs := []
	match op:
		"bind":
			ret = XBinding.bind(_who(st[1]), _who(st[2]), str(st[3]) if st.size() > 3 else "bind")
		"unbind":
			ret = XBinding.unbind(_who(st[1]), str(st[2]))
		"spend":
			ret = XBinding.spend(_who(st[1]), int(st[2]))
		"gain":
			XBinding.gain(_who(st[1]), int(st[2]))
		"turn":
			logs = logic.end_turn()
			logic.start_turn()
		"act":
			logs = logic.act(_who(st[1]), XDB.rec("Skills", int(st[2])), logic.enemies[int(st[3])])
		"foe":
			var e = logic.enemies[int(st[1])]
			logs = logic.act(e, XDB.rec("Skills", int(st[2])), logic.actors[int(st[3])] if int(st[3]) >= 0 else null)
		"kill":
			_set_hp(_who(st[1]), 0.0)
		"revive":
			var a: XActor = _who(st[1])
			a.remove_state(1)
			_set_hp(a, a.mhp)
		"leave":
			logic.actors = logic.actors.filter(func(b): return b.actor_id != int(st[1]))
		"back":
			logic.actors = PARTY.map(func(id): return logic.state.actor(id))
		"canHost":
			ret = PARTY.map(func(id): return XBinding.can_host(_who(OWNER), _who(id))) + [XBinding.can_host(_who(OWNER), logic.enemies[0])]
		"defaultHost":
			ret = _key(XBinding.default_host(_who(OWNER)))
		"manual":
			opt.manual = bool(st[1])
		"deny":
			opt.deny = int(st[1])
		"during":
			var e = logic.enemies[int(st[1])]
			XBinding.start_action(e)
			ret = []
			for sub in st[2]:
				var a: XActor = _who(sub[1])
				match str(sub[0]):
					"hurt":
						logic.gain_hp(a, -float(sub[2]))
					"set":
						_set_hp(a, float(sub[2]))
					"state":
						logic._state_add(a, int(sub[2]))
				ret.append({"hp": a.hp, "state": a.is_state_affected(int(sub[2])) if str(sub[0]) == "state" else null})
			XBinding.end_action()
			logs = logic.act(e, XDB.rec("Skills", 1), null)
		"pick":
			var e = logic.enemies[int(st[1])]
			XBinding.start_action(e)
			ret = _key(logic._random_target(logic.alive(logic.actors)))
			XBinding.end_action()
			logs = logic.act(e, XDB.rec("Skills", 1), null)
		"apply":
			var t: XActor = _who(st[2])
			var r := logic.apply(logic.enemies[int(st[1])], XDB.rec("Skills", 1), t)
			ret = {"hp": t.hp, "used": not bool(r.get("unused", false))}
			logs = [r]
		"end":
			logic.end_battle(0)
	return [ret, logs]


func _ready() -> void:
	_go.call_deferred()


func _go() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("oracle", ref.cases.size() == 8 and ref.cases.all(func(c): return (c.errors as Array).is_empty()))
	_register()
	for c in ref.cases:
		logic = _battle()
		opt = {"manual": false, "deny": 0}
		var steps: Array = c.observed
		check(c.id + ".start", _norm(_snap()) == _norm(steps[0].snap), [_snap(), steps[0].snap])
		for i in range(1, steps.size()):
			var want: Dictionary = steps[i]
			var st: Array = want.step
			var tag := "%s.%d.%s" % [c.id, i, str(st[0])]
			events.clear()
			var out: Array = _step(st)
			if want.ret != null or out[0] != null:
				check(tag + ".ret", _norm(out[0]) == _norm(want.ret), [out[0], want.ret])
			check(tag + ".events", _norm(events) == _norm(want.events), [events, want.events])
			var hits := _hits(out[1])
			check(tag + ".hits", _norm(hits) == _norm(want.hits), [hits, want.hits])
			var got := _snap()
			var ws: Dictionary = want.snap.duplicate()
			if str(st[0]) == "end":
				ws.erase("round")  # 战斗结束后原版 turnCount 还在，重制没有战斗了回 1：不比
				got.erase("round")
			check(tag + ".snap", _norm(got) == _norm(ws), [got, ws])
		if XBinding.in_battle():
			logic.end_battle(0)
	XBinding.kinds.erase("probe")
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_binding", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
