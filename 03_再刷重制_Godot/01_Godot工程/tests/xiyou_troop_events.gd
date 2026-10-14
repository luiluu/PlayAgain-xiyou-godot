extends Node
## 敌群事件（强制行动 339）与轮回困难 Establish：对照 mv_oracle troop_event_probe（真实 BattleManager 跑两回合）。
## 场景：普通难度、开局队伍 1/8/9/10（1 级）、敌群 4/5/8（一至三层守层者，第 1 回合强制使用 8111 → 状态 1460）。
## 比较：第 1 回合强制行动排在最前且清掉守层者本回合的普通行动、行动者集合、状态 1460、
## 守层者攻击/魔攻、第 2 回合守层者每次命中的附加伤害（行动者正的攻击/魔攻各一次）。伤害浮动由 Godot 随机，不比 HP。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func key(b: XBattler, logic: XBattleLogic) -> String:
	return "a%d" % int((b as XActor).data().id) if b is XActor else "e%d" % logic.enemies.find(b)


func setup(troop: int) -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8, 9, 10])
	var logic := XBattleLogic.new()
	logic.setup(troop, s)
	for a in logic.actors:
		for sk in [6168, 5980, 5548] + ([2571, 2786] if int(a.data().id) in [1, 2, 3, 4, 5, 6, 7, 52] else []):
			a.learn_skill(sk)
		a.refresh_passive()
		a.recover_all()
	return logic


func _run() -> void:
	var ref = XDB.load_json("oracle/troop_events.json")
	if not (ref is Dictionary and ref.has("cases")):
		check("oracle_present", false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	for c in ref.cases:
		check("troop%d.oracle_clean" % int(c.troop), c.errors.is_empty(), c.errors)
		for round in range(5):
			_case(c, round)
	_unit_checks()
	finish()


func _case(c: Dictionary, round: int) -> void:
	var name := "troop%d.r%d" % [int(c.troop), round]
	seed(1000 + round)
	var logic := setup(int(c.troop))
	var e0: XBattler = logic.enemies[0]
	var logs := []
	for t in range(2):
		var cmds := {}
		for a in logic.actors:
			cmds[a] = [XDB.rec("Skills", 1), e0]
		logs.append_array(logic.run_turn(cmds))
		if t == 0:
			check(name + ".state1460", e0.state_ids.has(1460), e0.state_ids)
			check(name + ".atk_mat", int(e0.atk) == int(c.battlers.e0.atk) and int(e0.mat) == int(c.battlers.e0.mat),
				[e0.atk, e0.mat, c.battlers.e0.atk, c.battlers.e0.mat])
	check(name + ".skipped", logic.troop_event_skipped.is_empty(), logic.troop_event_skipped)
	# 行动序列：每回合 [行动者, 技能]
	var got := {1: [], 2: []}
	var turn := 1
	var seen := {}
	for l in logs:
		if l.type == "action":
			var k := key(l.user, logic)
			if seen.has(k) and turn == 1:
				turn = 2
				seen.clear()
			seen[k] = true
			got[turn].append([k, int(l.skill.id)])
	var want := {1: [], 2: []}
	for a in c.actions:
		want[int(a.turn)].append([a.subject, int(a.skill)])
	# 第 1 回合：强制行动最先，守层者没有别的行动；角色集合一致
	check(name + ".t1_forced_first", not got[1].is_empty() and got[1][0] == want[1][0], [got[1], want[1]])
	check(name + ".t1_no_extra_enemy", got[1].filter(func(x): return x[0] == "e0").size() == 1, got[1])
	check(name + ".t1_actor_set", _sorted(got[1]) == _sorted(want[1]), [got[1], want[1]])
	# 第 2 回合：守层者照常行动一次（技能随机，不比）
	check(name + ".t2_enemy_once", got[2].filter(func(x): return x[0] == "e0").size() == 1, got[2])
	# 附加伤害：守层者每次命中活着的目标都按 [攻击, 魔攻] 附加
	var extras := []
	for l in logs:
		if l.type == "hit" and l.user == e0 and not l.missed and not l.evaded and l.target != e0:
			extras.append(l.get("extra", []))
	var want_extra := []
	for inv in c.invokes:
		if inv.subject == "e0" and inv.target != "e0" and float(inv.hpBefore) > 0.0:
			want_extra = [float(inv.userAtk), float(inv.userMat)]
	check(name + ".extra", not extras.is_empty() and extras.all(func(x): return x == want_extra), [extras, want_extra])


func _sorted(list: Array) -> Array:
	var keys := list.map(func(x): return x[0])
	keys.sort()
	return keys


## 条件与目标的细项（不依赖参照数据）
func _unit_checks() -> void:
	var logic := setup(4)
	var page := {"conditions": {"turnEnding": false, "turnValid": true, "turnA": 1, "turnB": 0, "enemyValid": false,
		"actorValid": false, "switchValid": false}, "span": 0, "list": []}
	logic.turn = 0
	check("cond.turn_a_only_miss", not logic._page_meets(page, false))
	logic.turn = 1
	check("cond.turn_a_only_hit", logic._page_meets(page, false))
	page.conditions.turnA = 0
	page.conditions.turnB = 2
	logic.turn = 0
	check("cond.turn_ab_zero", not logic._page_meets(page, false))
	logic.turn = 4
	check("cond.turn_ab_every2", logic._page_meets(page, false))
	logic.turn = 3
	check("cond.turn_ab_odd", not logic._page_meets(page, false))
	page.conditions.turnEnding = true
	logic.turn = 4
	check("cond.turn_ending", not logic._page_meets(page, false) and logic._page_meets(page, true))
	var empty := {"conditions": {}, "span": 0, "list": []}
	check("cond.no_condition_never", not logic._page_meets(empty, false))
	# 强制行动的目标：序号阵亡时取第一个活着的
	var skill := XDB.rec("Skills", 1)
	var e0: XBattler = logic.enemies[0]
	logic.actors[0].hp = 0
	check("target.smooth", logic._forced_target(e0, skill, 0) == logic.actors[1])
	check("target.random", logic._forced_target(e0, skill, -1) == null)
	# Establish：负能力值不附加
	var t: XBattler = logic.actors[1]
	e0.add_state(1460)
	var r := {}
	var hp0 := t.hp
	logic._establish(e0, t, r)
	check("establish.hp", is_equal_approx(t.hp, maxf(0.0, hp0 - e0.atk - e0.mat)), [hp0, t.hp, e0.atk, e0.mat])
	check("establish.extra", r.get("extra", []) == [float(e0.atk), float(e0.mat)], r)


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
