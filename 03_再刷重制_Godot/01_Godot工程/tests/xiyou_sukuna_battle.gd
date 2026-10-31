extends Node
## 宿傩 172 战斗内机制（XSukuna 第二期：begin／finish／end_round、apply 包装、看破、终式、伤口、捌两段、领域、神灶、追斩、
## 适应、技能条件、TP 消耗、战斗中技能列表）：与 mv_oracle/sukuna_battle_probe.cjs 的冻结 v0.28 参照
## （generated/oracle/sukuna_battle.json）逐步比。每步比命中（技能、出手者、目标、结果生命伤害）与快照。
## 生命伤害比对参照的比值：55 级宿傩各技能重制恒为原版的 0.96079 倍（同黄泉 xiyou_yomi_battle 记的 55 级约 3.9% 固定差，
## 出在伤害链／能力值，与本期机制无关，交付单记着留给伤害链核查），所以每例取第一段的比值，其余各段（含终式、冲击段、领域斩击、
## 神灶：开）都要与它相同；为 0 的段（护盾吸收）两边都要为 0。
## 另有本地断言（参照不调 startBattle）：开战 TP 至少 60；反向——别的角色不吃宿傩的包装、没伤口时治疗不减半。
const ORACLE := "oracle/sukuna_battle.json"
const MARKS := [2636, 2637, 2638, 2639, 2640, 2641, 2642]
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648


## 同参照 battle()：新局、开 2494（超强角色可出战）、队伍 [172, 1] 各 55 级、宿傩进阶 rank；双方生命加 1e12；规则流全取 0.5
func _battle(rank: int, tp := 100.0) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	s.actor_advance[172] = rank
	for id in [172, 1]:
		s.actor(id).change_level_mv(55)
	s.add_actor(172)
	s.add_actor(1)
	var a := s.actor(172)
	XSukuna.sync(a)
	for id in [172, 1]:
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
	var rand := XBattleRandom.create("0000000000000172")
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
	if tp >= 0.0:
		a.tp = tp
	return [logic, a]


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _marks(b) -> Array:
	var out: Array = b.state_ids.filter(func(x): return MARKS.has(int(x)))
	out.sort()
	return out


func _snap(logic: XBattleLogic, a: XActor) -> Dictionary:
	var d := XSukuna.temp(a)
	return {"round": XSukuna.round, "tp": a.tp,
		"sukuna": {"domain": int(d.domain), "prep": int(d.prep), "available": int(d.available), "adapt": int(d.adapt), "chase": int(d.chase), "states": _marks(a)},
		"foes": logic.enemies.map(func(t): var q := XSukuna.target_data(t); return {"layers": int(q.layers), "charged": bool(q.charged), "states": _marks(t)}),
		"meets": [10229, 10230, 10231, 10232, 10233].map(func(id): return logic.can_use(a, XDB.rec("Skills", id))),
		"tpCost": [10229, 10230, 10231].map(func(id): return int(logic.skill_cost(a, XDB.rec("Skills", id)).tp)),
		"listed": a.skills().filter(func(s): return int(s.id) >= 10229 and int(s.id) <= 10249 and XSukuna.listed(a, s)).map(func(s): return int(s.id))}


static func _norm(v):
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


func _hits(logic: XBattleLogic, logs: Array) -> Array:
	var out := []
	for l in logs:
		if l.get("type") != "hit" or bool(l.missed) or bool(l.evaded) or not int(l.skill.get("damage", {}).get("type", 0)) in [1, 3, 5]:
			continue
		out.append({"skill": int(l.skill.id), "user": _key(logic, l.user), "target": _key(logic, l.target), "hp": float(l.hp)})
	return out


func _script(c: Dictionary) -> void:
	var r := _battle(int(c.setup.rank))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var steps: Array = c.observed.steps
	var gap := [0.0]
	for i in steps.size():
		var want: Dictionary = steps[i]
		var st: Array = want.step
		var name := "%s.%d.%s" % [c.id, i, str(st[0])]
		var logs := []
		match str(st[0]):
			"act":
				logs = logic.act(a, XDB.rec("Skills", int(st[1])), logic.enemies[int(st[2])])
			"foe":
				logs = logic.act(logic.enemies[int(st[1])], XDB.rec("Skills", 1), a)
			"end":
				logs = logic.end_turn()
			"shield":
				logic.enemies[int(st[1])].shield = float(st[2])
			"heal":
				var t: XEnemy = logic.enemies[int(st[1])]
				t.hp = 1.0
				var rc := logic._operation_resources(t)
				rc.gain(t, "hp", float(st[2]))
				logic._finish_lifecycle_operation(rc, t)
				check(name + ".healed", is_equal_approx(t.hp - 1.0, float(want.healed)), [t.hp - 1.0, want.healed])
		if want.has("hits"):
			var got := _hits(logic, logs)
			var exp: Array = want.hits
			var same := got.size() == exp.size()
			for k in got.size():
				if same:
					var e: Dictionary = exp[k]
					var w := float(e.hp)
					if gap[0] == 0.0 and w > 0.0 and str(e.user) == "a172":
						gap[0] = got[k].hp / w
					var hp_ok: bool = got[k].hp == 0.0 if w == 0.0 else (str(e.user).begins_with("e") and absf(got[k].hp - w) <= 1.0) or absf(got[k].hp / w - gap[0]) < 1e-6
					same = got[k].skill == int(e.skill) and got[k].user == str(e.user) and got[k].target == str(e.target) and hp_ok
			check(name + ".hits", same, [got, exp])
		var snap: Dictionary = _norm(_snap(logic, a))
		var ws: Dictionary = _norm(want.snap)
		for k in ws:
			check(name + "." + k, snap[k] == ws[k], [snap[k], ws[k]])
		if str(st[0]) == "heal":
			logic.enemies[int(st[1])].recover_all()
	check(c.id + ".gap", absf(gap[0] - 0.96079) < 1e-4, gap[0])
	logic.end_battle(0)


func _local() -> void:
	# 开战 TP 至少 60（startBattle 包装之后）：开战前 0 → 60；超过 60 的照留（不保留 TP 时开战另给 0～24，不会超过 60）
	var r := _battle(0, -1.0)
	check("local.start_tp", is_equal_approx(r[1].tp, 60.0), r[1].tp)
	r[0].end_battle(0)
	# 反向：1 号主角打有三层看破、带伤口的目标——不加层、不转终式、不附伤口，结束后状态不变；没伤口的目标治疗不减半
	r = _battle(0)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var hero: XActor = logic.state.actor(1)
	for i in 3:
		logic.act(a, XDB.rec("Skills", 10229), logic.enemies[0])
		if i == 1:
			logic.end_turn()
	var t: XEnemy = logic.enemies[0]
	var before := [int(XSukuna.target_data(t).layers), _marks(t)]
	logic.act(hero, XDB.rec("Skills", 1), t)
	check("local.other_actor_no_hooks", [int(XSukuna.target_data(t).layers), _marks(t)] == before and XSukuna.cast.is_empty(), [before, XSukuna.target_data(t)])
	var u: XEnemy = logic.enemies[1]
	u.hp = 1.0
	var rc := logic._operation_resources(u)
	rc.gain(u, "hp", 100000.0)
	logic._finish_lifecycle_operation(rc, u)
	check("local.heal_unwounded_full", is_equal_approx(u.hp, 100001.0), u.hp)
	# 反向：神灶打没蓄力的目标不结算（apply 不跑），神灶：开直接施放不结算
	var logs := logic.act(a, XDB.rec("Skills", 10232), logic.enemies[2])
	check("local.flame_uncharged_noop", _hits(logic, logs).is_empty(), _hits(logic, logs))
	logic.end_battle(0)
	check("local.end_battle_clears", XSukuna._temp.is_empty() and XSukuna._target.is_empty() and not a.state_ids.has(XSukuna.DOMAIN))


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		seen[c.id] = true
		if c.id == "module":
			var o: Dictionary = c.observed
			check("module", int(o.domain) == XSukuna.DOMAIN and int(o.wound) == XSukuna.WOUND and int(o.maho) == XSukuna.MAHO and int(o.awake) == XSukuna.AWAKE)
		else:
			_script(c)
	check("covers_all", seen.size() == 5, seen.keys())
	_local()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_sukuna_battle", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
