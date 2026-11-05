extends Node
## 【cc·哪吒·未经审查】难度 6～9 整敌群对冻结 v0.28 参照 generated/oracle/difficulty_troop.json（mv_oracle/difficulty_troop_probe.cjs）：
## 原版走 BattleManager.setup（Math.random 0.99）＋startBattle＋dsPassiveSkill 开战加状态；重制走 XBattleLogic.setup（elite_roll 100、level_roll 0.99）。
## 队伍 [1,8,9,10] 1 级。逐成员比：敌人号（含替换后的）、隐藏、神话、等级、HP／MP、状态、最终能力值（param／xparam／sparam／属性）、行动表。
## 原版随机目标的开战加状态（StartRom*）参照只记不加，这里要求为空（有了就得另行对照）。
const ORACLE := "oracle/difficulty_troop.json"
const ELEMENTS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15]
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 30:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1200))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + ORACLE))
	if not (d is Dictionary and d.cases.size() == 40 and d.troops.size() == 10):
		check("oracle", false, ORACLE)
		return finish()
	check("source", d.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	var members := 0
	for c in d.cases:
		check(c.id + ".oracle", c.errors.is_empty(), c.errors)
		if c.errors.is_empty():
			members += _case(c)
	check("members_compared", members >= 70, members)
	XState.current = null
	finish()


func _case(c: Dictionary) -> int:
	var o: Dictionary = c.observed
	var diff := int(c.setup.difficulty)
	var s := XState.new_game(diff, 1, [8, 9, 10])
	XState.current = s
	var logic := XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.level_roll = 0.99
	logic.setup(int(c.setup.troop), s)
	check(c.id + ".random_target_tags", (o.randomTargetTags as Array).is_empty(), o.randomTargetTags)
	check(c.id + ".count", logic.enemies.size() == o.members.size(), [logic.enemies.size(), o.members.size()])
	for i in mini(logic.enemies.size(), o.members.size()):
		var e: XEnemy = logic.enemies[i]
		var m: Dictionary = o.members[i]
		var tag := "%s.m%d" % [c.id, i]
		check(tag + ".id", e.enemy_id == int(m.id), [e.enemy_id, m.id])
		check(tag + ".hidden", e.hidden == bool(m.hidden), [e.hidden, m.hidden])
		check(tag + ".elite", e.elite == bool(m.elite), [e.elite, m.elite])
		check(tag + ".level", e.level == int(m.level), [e.level, m.level])
		check(tag + ".hp", _near(e.hp, m.hp), [e.hp, m.hp])
		check(tag + ".mp", _near(e.mp, m.mp), [e.mp, m.mp])
		var states: Array = Array(e.state_ids)
		states.sort()
		check(tag + ".states", states == (m.states as Array).map(func(v): return int(v)), [states, m.states])
		var mine := {"param": range(8).map(func(k): return e.param(k)), "xparam": range(10).map(func(k): return e.xparam(k)),
			"sparam": range(10).map(func(k): return e.sparam(k)), "elementRates": ELEMENTS.map(func(k): return e.element_rate(k))}
		for k in ["param", "xparam", "sparam", "elementRates"]:
			var ok: bool = mine[k].size() == m[k].size()
			for j in mini(mine[k].size(), m[k].size()):
				ok = ok and _near(mine[k][j], m[k][j])
			check("%s.%s" % [tag, k], ok, {"godot": mine[k], "mv": m[k]})
		var acts: Array = e.data().get("actions", []).map(func(a): return [int(a.skillId), int(a.rating), int(a.conditionType), float(a.conditionParam1), float(a.conditionParam2)])
		var want: Array = (m.actions as Array).map(func(a): return [int(a[0]), int(a[1]), int(a[2]), float(a[3]), float(a[4])])
		check(tag + ".actions", str(acts) == str(want), [acts, want])
	return mini(logic.enemies.size(), o.members.size())


func _near(a, b) -> bool:
	return absf(float(a) - float(b)) <= 1e-4 * maxf(1.0, absf(float(b)))


func finish() -> void:
	var passed := checks - failures.size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": checks}))
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)
