extends Node
## YEP 行动序列规则：对照 mv_oracle sequence_probe 的 rules（真实 BattleManager 行动机实跑）。
## 场景：普通难度、出战 1/8/9/10、10 级、敌群 222（三只 20 万血）；每个用例比较每次 ACTION EFFECT 打到的目标序列，
## 以及序列里 ADD/REMOVE STATE 指令涉及的状态在各成员身上的增减。另测条件求值与目标写法。
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func key(b: XBattler, logic: XBattleLogic) -> String:
	return "a%d" % int((b as XActor).data().id) if b is XActor else "e%d" % logic.enemies.find(b)


func setup() -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8, 9, 10])
	var logic := XBattleLogic.new()
	logic.setup(222, s)
	logic.turn = 1
	for a in logic.actors:
		for sk in [6168, 5980, 5548] + ([2571, 2786] if int(a.data().id) in [1, 2, 3, 4, 5, 6, 7, 52] else []):
			a.learn_skill(sk)
		a.change_level(10)
		a.refresh_passive()
		a.recover_all()
	return logic


func _refs(rec: Dictionary) -> Dictionary:
	var text := JSON.stringify(rec.yepSeq)
	var skills := []
	for m in RegEx.create_from_string("_skills\\.includes\\((\\d+)\\)|hasSkill\\((\\d+)\\)").search_all(text):
		skills.append(int(m.get_string(1) if m.get_string(1) != "" else m.get_string(2)))
	var states := []
	for m in RegEx.create_from_string("user\\._states\\.includes\\((\\d+)\\)").search_all(text):
		states.append(int(m.get_string(1)))
	var rule := []
	for m in RegEx.create_from_string("(?i)(?:ADD|REMOVE)[ _]STATE[ ](\\d+(?:\\s*,\\s*\\d+)*)").search_all(text):
		for x in m.get_string(1).split(","):
			rule.append(int(x.strip_edges()))
	return {"skills": skills, "states": states, "rule": rule}


func _run() -> void:
	var ref = XDB.load_json("oracle/sequences.json")
	if not (ref is Dictionary and ref.has("rules")):
		check("oracle_present", false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	var ok_count := 0
	var unknown := {}
	for row in ref.rules:
		if row.error != null:
			continue
		var logic := setup()
		var rec := XDB.rec("Skills", int(row.skill))
		var rf := _refs(rec)
		var u: XBattler = logic.enemies[0] if row.user == "e0" else logic.state.actor(int(str(row.user).substr(1)))
		if row.variant == "learned":
			for k in rf.skills:
				if u is XActor:
					(u as XActor).learn_skill(k)
			for k in rf.states:
				u.add_state(k)
		var all: Array = logic.actors + logic.enemies
		var before := {}
		for b in all:
			before[key(b, logic)] = b.state_ids.duplicate()
		var chosen: XBattler = null
		var scope := int(rec.scope)
		if scope in [1, 2]:
			chosen = (logic.enemies if u is XActor else logic.actors)[0]
		elif scope in [7, 8, 9, 10]:
			chosen = (logic.actors if u is XActor else logic.enemies)[0]
		var times := 1 + (int(u.traits_sum_all(XBattler.TRAIT_ATTACK_TIMES)) if int(rec.id) == XBattleLogic.ATTACK_SKILL else 0)
		var list := []
		for t in logic.targets_for(u, rec, chosen):
			for i in maxi(1, times):
				list.append(t)
		var seq := XActionSequence.create(logic, u, rec, list)
		var logs := seq.run()
		for a in seq.unknown:
			unknown[a] = true
		var invoked := []
		for l in logs:
			if l.get("type") == "hit" and not l.get("counter", false) and not l.get("reflected", false):
				invoked.append(key(l.target, logic))
		var changed := {}
		for b in all:
			var k := key(b, logic)
			var add: Array = b.state_ids.filter(func(x): return not before[k].has(x) and rf.rule.has(x))
			var rem: Array = before[k].filter(func(x): return not b.state_ids.has(x) and rf.rule.has(x))
			if not add.is_empty() or not rem.is_empty():
				changed[k] = {"add": add, "rem": rem}
		var want_states := {}
		for k in row.states:
			want_states[k] = {"add": row.states[k].add.map(func(x): return int(x)), "rem": row.states[k].rem.map(func(x): return int(x))}
		var same: bool = invoked == Array(row.invoked) and changed == want_states
		if same:
			ok_count += 1
		check("seq_%s_%d_%s" % [row.user, int(row.skill), row.variant], same, {"godot": [invoked, changed], "mv": [row.invoked, row.states], "types": logs.map(func(l): return str(l.get("type")) + ("C" if l.get("counter", false) else "") + ("R" if l.get("reflected", false) else ""))})
	# 全部技能/物品里的 IF 条件都要能翻译（不认识的写法会当作假）
	var logic := setup()
	var probe := XActionSequence.create(logic, logic.actors[0], XDB.rec("Skills", 1), [logic.enemies[0]])
	probe.targets = [logic.enemies[0]]
	var total := 0
	for table in ["Skills", "Items"]:
		for rec in XDB.table(table):
			if not (rec is Dictionary and rec.get("yepSeq") is Dictionary):
				continue
			for phase in rec.yepSeq:
				for e in rec.yepSeq[phase]:
					var m := RegEx.create_from_string("(?i)IF[ ](.*)").search(str(e[0]))
					if m and not RegEx.create_from_string("(?i)ELSE").search(str(e[0])):
						total += 1
						probe.eval_condition(m.get_string(1))
	var kinds := {}
	for a in probe.unknown:
		kinds[RegEx.create_from_string("\\d+").sub(a, "N", true)] = true
	print("conditions: ", total, " unknown atoms: ", probe.unknown.size(), " kinds: ", kinds.keys())
	check("conditions_translated", probe.unknown.is_empty(), kinds.keys())
	_numeric_checks(ref)
	finish()


func _numeric_checks(ref: Dictionary) -> void:
	check("numeric_oracle_present", ref.has("operations") and ref.has("parseIntNumbers"))
	for row in ref.get("parseIntNumbers", []):
		check("parseInt_%s" % row.value, XActionSequence.js_parse_int(float(row.value)) == float(row.result))
	for row in ref.get("operations", []):
		var logic := setup()
		var t: XBattler = logic.enemies[0]
		t.tp = 0.0
		if row.get("dead", false):
			t.add_state(1)
		if row.has("variable"):
			logic.state.set_variable(20, float(row.variable))
		var rec := {"yepSeq": {"whole": row.commands}}
		XActionSequence.create(logic, logic.actors[0], rec, [t]).run()
		var got := {"hp": t.hp, "mp": t.mp, "tp": t.tp, "states": t.state_ids, "buffs": t.buffs, "buffTurns": t.buff_turns}
		check("numeric_" + str(row.id), JSON.parse_string(JSON.stringify(got)) == row.result, [got, row.result])


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
