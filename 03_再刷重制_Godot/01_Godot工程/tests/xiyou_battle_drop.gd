extends Node
## 【cc·悟空·未经审查】战斗里敌人的掉落概率（XBattleLogic.drop_chances／_roll_drops）：
## 与 mv_oracle/battle_drop_probe.cjs 的冻结 v0.28 参照（generated/oracle/battle_drop.json）逐例比。
## 每例：新局、难度、队伍（渡鸦 30 级会亡魂汲取）、敌人神话与否；比 dropItemRate（XAlienBattle.drop_item_rate）与各件概率（从大到小，夹到 1）。
## 覆盖：数据库分母 1／2／20、<Enemy Drops> 的 x%、神话 ×5、难度 2 与 5 一样、亡魂汲取 +1、套装与 passiveIRUP。
## 反向：drop_chances 不再按难度表「Drop Rate」乘（难度 5 的倍率 10.0 与难度 2 的 3.0 不同，结果相同）。
const ORACLE := "oracle/battle_drop.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + ORACLE))
	if not check("oracle", d is Dictionary and d.cases.size() >= 6 and d.cases.all(func(c): return c.errors.is_empty()), ORACLE):
		finish()
		return
	for c in d.cases:
		_case(c)
	XState.current = null
	finish()


func _case(c: Dictionary) -> void:
	var st: Dictionary = c.setup
	var o: Dictionary = c.observed
	var s := XState.new_game(int(st.difficulty), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.set_switch(2494, true)
	s.party.clear()
	s.battle_slots.clear()
	for id in st.party:
		s.add_actor(int(id))
	if (st.party as Array).has(167.0) or (st.party as Array).has(167):
		s.actor(167).change_level_mv(int(st.ravenLevel))
	var e := XEnemy.new().setup(int(st.enemy), s.difficulty, 100.0)
	e.elite = bool(st.elite)
	var members := s.battle_members().map(func(b): return b.actor_id)
	check(c.id + ".members", members == (o.members as Array).map(func(x): return int(x)), [members, o.members])
	var rate := XAlienBattle.drop_item_rate(s, e)
	check(c.id + ".rate", is_equal_approx(snappedf(rate, 0.000001), float(o.dropItemRate)), [rate, o.dropItemRate])
	var logic := XBattleLogic.new()
	logic.state = s
	var got: Array = logic.drop_chances(e).map(func(x): return snappedf(minf(1.0, x.chance), 0.000001))
	got.sort()
	got.reverse()
	var want: Array = (o.chances as Array).map(func(x): return float(x))
	var same := got.size() == want.size()
	for i in mini(got.size(), want.size()):
		same = same and absf(got[i] - want[i]) <= 0.000002
	check(c.id + ".chances", same, [got, want])


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
