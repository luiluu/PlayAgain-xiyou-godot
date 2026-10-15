extends Node
## 敌群事件（条件分支／公共事件、强制行动 339、更改状态）与轮回困难 Establish：对照 mv_oracle troop_event_probe（真实 BattleManager 跑两回合）。
## 场景：普通难度、开局队伍 1/8/9/10（1 级）、敌群 4/5/8/28/39/52/53/67/109/110（一至三、五至九、十一至十二层守层者，第 1 回合强制使用 8111 → 状态 1460）、
## 69（十层守层者：第 1 回合强制 500、给自己加状态 44、再强制 8111）、111／118／138／172／173（十三至十七层守层者：条件分支里调公共事件 1398，再强制 6069／6105／8111）。
## 十三至十七层另测已交见面礼（变量 842＝1）：跳过开场领域与强制行动。
## 比较：第 1 回合强制行动排在最前且清掉守层者本回合的普通行动、敌方行动者、状态 1460 与第 1 回合加上的其余状态、
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


func setup(troop: int, paid := false) -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.set_variable(842, 1 if paid else 0)
	var logic := XBattleLogic.new()
	logic.level_roll = 0.99  # 参照：敌群生成时 Math.random=0.99
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
	var name := "troop%d.paid%s.r%d" % [int(c.troop), str(c.get("paid", false)), round]
	seed(1000 + round)
	var logic := setup(int(c.troop), bool(c.get("paid", false)))
	var e0: XBattler = logic.enemies[0]
	var logs := []
	var t1_states: Array = []
	# 每回合单独记录 [行动者, 技能]（多敌人的敌群里角色可能在行动前被打倒，行动者集合随随机数变，只比敌方）
	var got := {1: [], 2: []}
	var first_cleared := false
	for t in range(2):
		if logic.is_won() or logic.is_lost():
			break
		var cmds := {}
		for a in logic.actors:
			cmds[a] = [XDB.rec("Skills", 1), e0]
		var turn_logs := logic.run_turn(cmds)
		logs.append_array(turn_logs)
		for l in turn_logs:
			if l.type == "action":
				got[t + 1].append([key(l.user, logic), int(l.skill.id)])
		if t == 0:
			first_cleared = logic.cleared_action(e0)
			t1_states = e0.state_ids.duplicate()
			check(name + ".state1460", e0.state_ids.has(1460) == c.battlers.e0.states.has(1460.0), e0.state_ids)
			check(name + ".atk_mat", int(e0.atk) == int(c.battlers.e0.atk) and int(e0.mat) == int(c.battlers.e0.mat),
				[e0.atk, e0.mat, c.battlers.e0.atk, c.battlers.e0.mat])
	check(name + ".skipped", logic.troop_event_skipped.is_empty(), logic.troop_event_skipped)
	var want := {1: [], 2: []}
	var forced := 0
	for a in c.actions:
		want[int(a.turn)].append([a.subject, int(a.skill)])
		if int(a.turn) == 1 and a.subject == "e0" and a.forced:
			forced += 1
	# 第 1 回合守层者最后一次行动后的状态（参照记在 invoke 的 userStates）：Godot 第 1 回合结束时都应还在
	var want_states: Array = []
	for inv in c.invokes:
		if int(inv.turn) == 1 and inv.subject == "e0":
			want_states = inv.userStates
	check(name + ".t1_states", want_states.all(func(id): return t1_states.has(int(id))), [t1_states, want_states])
	var enemies_of := func(list: Array) -> Array:
		var keys := {}
		for x in list:
			if str(x[0]).begins_with("e"):
				keys[x[0]] = true
		var out := keys.keys()
		out.sort()
		return out
	# 第 1 回合：强制行动最先；守层者是回合首位时本回合的普通行动被清掉（参照即此情形），
	# 不是首位时轮到它还会再行动一次（OTB 轮到时才 makeActions）。敌方行动者一致
	check(name + ".t1_forced_first", (not first_cleared) if forced == 0 else (not got[1].is_empty() and got[1][0] == want[1][0]), [got[1], want[1]])
	check(name + ".t1_enemy_actions", got[1].filter(func(x): return x[0] == "e0").size() == forced + (0 if first_cleared else 1), [forced, first_cleared, got[1]])
	check(name + ".t1_enemy_set", enemies_of.call(got[1]) == enemies_of.call(want[1]), [got[1], want[1]])
	# 第 2 回合（战斗没结束时）：守层者照常行动一次（技能随机，不比）
	if not got[2].is_empty():
		check(name + ".t2_enemy_once", got[2].filter(func(x): return x[0] == "e0").size() == 1, got[2])
	# 附加伤害：守层者用过 8111（加上 1460）之后，每次命中活着的目标都按 [攻击, 魔攻] 附加
	# （十层守层者第 1 回合先强制 500，那时还没有 1460，不附加）
	var extras := []
	var established := false
	for l in logs:
		if l.type == "action" and l.user == e0 and int(l.skill.id) == 8111:
			established = true
		if established and l.type == "hit" and l.user == e0 and not l.missed and not l.evaded and l.target != e0:
			extras.append(l.get("extra", []))
	var want_extra := []
	for inv in c.invokes:
		if inv.subject == "e0" and inv.target != "e0" and float(inv.hpBefore) > 0.0 and inv.userStates.has(1460.0):
			want_extra = [float(inv.userAtk), float(inv.userMat)]
	check(name + ".extra", extras.is_empty() if want_extra.is_empty() else (not extras.is_empty() and extras.all(func(x): return x == want_extra)), [extras, want_extra])


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
