extends Node
## 【cc·悟空·未经审查】108 奈叶共享击杀（XNanoha）：与 mv_oracle/nanoha_kill_probe.cjs 的冻结 v0.28 参照
## （tests/fixtures/nanoha_kill_oracle.json，真实 Game_Action.apply／BattleManager.endAction）逐例比。
## - learn：新局奈叶 1 级就会并肩适应 10168、适应 5683；
## - kill.*：队伍 [1, 108]（或只有 1）各 10 级、敌群 2 三只（血量按例）、开挑战开关 2494（locked 不开，奈叶去替补）；
##   行动后比奈叶永久加成（生命、魔法）、各敌死活、出战成员与两项技能：队友每杀一只 +10／+30，打不死、奈叶不在队／阵亡／缺技能不给，
##   奈叶自己的击杀只由状态 1768 Conclude 给（不重复）；twice：已死的敌人第二次行动不再算。
const FIXTURE := "res://tests/fixtures/nanoha_kill_oracle.json"
const BIG_HP := 1e9
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _new_state() -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	return s


## 同参照 battle()：新局、开关 2494（locked 不开）、队伍 party 各 10 级、敌群 2，敌血 hp[i]；
## 参照不跑 startBattle，开战状态 1768／1708 这里去掉，conclude 例再加 1768
func _battle(setup: Dictionary) -> Array:
	var s := _new_state()
	s.switches[2494] = not bool(setup.get("locked", false))
	s.party.clear()
	s.battle_slots.clear()
	for id in setup.party:
		s.actor(int(id)).change_level_mv(10)
		s.add_actor(int(id))
	var n := s.actor(XNanoha.ACTOR)
	if setup.has("forget"):
		n.forget_skill(int(setup.forget))
	var rand := XBattleRandom.create("0000000000000108")
	rand.rule = FixedMidStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(2, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += BIG_HP
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	for i in range(logic.enemies.size()):
		logic.enemies[i].hp = float(setup.hp[i])
	for sid in [1768, 1708]:
		n.remove_state(sid)
	if bool(setup.get("nanohaDead", false)):
		n.add_state(1)
	if bool(setup.get("conclude", false)):
		n.add_state(1768)
	return [logic, s, n]


func _snap(logic: XBattleLogic, s: XState, n: XActor) -> Dictionary:
	var row: Array = s.mv_param_plus.get(str(XNanoha.ACTOR), [0, 0])
	return {"members": s.battle_members().map(func(a): return a.actor_id), "plus": [float(row[0]), float(row[1])],
		"dead": logic.enemies.map(func(e): return e.is_dead()),
		"learned": [XNanoha.SHARED, XNanoha.ADAPT].map(func(id): return n.skill_ids.has(id))}


func _same(a: Dictionary, o: Dictionary) -> bool:
	var ints := func(v): return (v as Array).map(func(x): return int(x))
	return ints.call(a.members) == ints.call(o.members) and ints.call(a.plus) == ints.call(o.plus) \
		and a.dead == o.dead and a.learned == o.learned


func _act(logic: XBattleLogic, s: XState, who: int, skill: int) -> void:
	logic.act(s.actor(who), XDB.rec("Skills", skill), logic.enemies[0])


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases") and ref.cases.size() == 13):
		return finish()
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		var o: Dictionary = c.observed
		if c.id == "learn":
			var n := _new_state().actor(XNanoha.ACTOR)
			var learned := [XNanoha.SHARED, XNanoha.ADAPT].map(func(id): return n.skill_ids.has(id))
			check("learn", learned == o.learned, [learned, o])
		elif c.id == "kill.mate.twice":
			var b := _battle(c.setup)
			var steps := []
			_act(b[0], b[1], 1, 1)
			steps.append(_snap(b[0], b[1], b[2]))
			_act(b[0], b[1], 1, 160)
			steps.append(_snap(b[0], b[1], b[2]))
			check(c.id, _same(steps[0], o.steps[0]) and _same(steps[1], o.steps[1]), [steps, o.steps])
		else:
			var b := _battle(c.setup)
			var before := _snap(b[0], b[1], b[2])
			_act(b[0], b[1], int(c.setup.user), int(c.setup.skill))
			var after := _snap(b[0], b[1], b[2])
			check(c.id + ".before", _same(before, o.before), [before, o.before])
			check(c.id + ".after", _same(after, o.after), [after, o.after])
	_field()
	# 本地断言：追击等 execute 之外的 apply 不记（目标表在 execute 结束时关闭）
	var b := _battle({"party": [1, 108], "hp": [1, BIG_HP, BIG_HP]})
	var logic: XBattleLogic = b[0]
	XNanoha.begin(logic)
	XNanoha.end_execute(logic)
	logic.apply(b[1].actor(1), XDB.rec("Skills", 1), logic.enemies[0])
	XNanoha.finish(logic, b[1].actor(1))
	check("local.closed_frame", _snap(logic, b[1], b[2]).plus == [0.0, 0.0], _snap(logic, b[1], b[2]))
	finish()


## nanoha2_oracle field.flow：真实开战后奈叶带 1708／1768／1774／1780；开战只预约 1320（领域 1774 的 battle 效果在被动状态之前跑过，
## 原版从不预约 2478）；奈叶行动开始预约 2481（身经百战防转换），队友行动、回合结束不预约（1780 的 action_end 2480 在 OTB 下不触发）
func _field() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/nanoha2_oracle.json"))
	if not check("field.oracle_present", ref is Dictionary and ref.cases.size() == 1 and ref.cases[0].errors.is_empty()):
		return
	var o: Array = ref.cases[0].observed.steps
	var s := _new_state()
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 108]:
		s.actor(id).change_level_mv(10)
		s.add_actor(id)
	var rand := XBattleRandom.create("0000000000000108")
	rand.rule = FixedMidStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(2, s, rand)
	var n := s.actor(108)
	var taken := func() -> Array:
		var id := XBattleCommonEvent.reserved(logic)
		XBattleCommonEvent.take(logic)
		return [] if id <= 0 else [id]
	var states: Array = n.state_ids.filter(func(id): return id in o[0].states)
	states.sort()
	var ints := func(v): return (v as Array).map(func(x): return int(x))
	check("field.startBattle", taken.call() == ints.call(o[0].reserved) and states == ints.call(o[0].states), [states, o[0]])
	logic.act(n, XDB.rec("Skills", 1), logic.enemies[0])
	check("field.nanoha.attack", taken.call() == ints.call(o[1].reserved), o[1])
	logic.act(s.actor(1), XDB.rec("Skills", 1), logic.enemies[0])
	check("field.mate.attack", taken.call() == ints.call(o[2].reserved), o[2])
	logic.end_turn()
	check("field.endTurn", taken.call() == ints.call(o[3].reserved), o[3])


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_nanoha", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
