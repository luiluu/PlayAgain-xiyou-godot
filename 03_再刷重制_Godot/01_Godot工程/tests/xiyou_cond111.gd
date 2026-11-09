extends Node
## 【cc·八戒·未经审查】条件分支 111 类型 4（角色）：在队／技能／状态，地图上与战斗中（interp7 盘点）。
## 原版取值见 tests/fixtures/cond111_oracle.json（mv_oracle/cond111_probe.cjs 实跑冻结正式引擎）：队伍 6 人、出战栏 [1,8,10,9,0]，
## 13、14 在后备；command111 的「在队」用 $gameParty.members()，战斗中只算出战成员（重制原来查全队，后备的人在战斗里也算在队）。
## 地图上用 MVInterpreter，战斗中用 XBattleEventRunner（_party_members＝出战成员），同一组条件逐项对。
var passed := 0
var total := 0

func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))

func _ready() -> void:
	_run.call_deferred()

var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/cond111_oracle.json"))

func _case(id: String) -> Dictionary:
	for c in oracle.cases:
		if str(c.id) == id:
			return c
	return {}

func ask(interp: MVEventCore) -> Dictionary:
	var out := {}
	for k in oracle.queries:
		out[k] = interp._condition(Array(oracle.queries[k]))
	return out

func _run() -> void:
	var map_case := _case("map")
	var party: Array = Array(map_case.setup.party).map(func(v): return int(v))
	var s := XState.new_game(3, party[0], party.slice(1))
	XState.current = s
	s.battle_slots = Array(map_case.setup.slots).map(func(v): return int(v))
	for id in [1, 13]:
		s.actor(id).learn_skill(319)
		s.actor(id).add_state(692)
	check("party_members", s.party.size() == party.size() and party.all(func(id): return s.party.has(id)), s.party)
	# 地图
	var interp := MVInterpreter.new(null, 4, 0, [])
	var on_map := ask(interp)
	check("map", on_map == map_case.observed.answers, [on_map, map_case.observed.answers])
	check("map_no_skip", interp.skipped.is_empty(), interp.skipped)
	# 战斗中
	var battle_case := _case("battle")
	XEnemy.force_roll = 100.0
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(1, s)
	var ids: Array = l.actors.map(func(a): return a.actor_id)
	var want: Array = Array(battle_case.observed.members).map(func(v): return int(v))
	ids.sort()
	want.sort()
	check("battle_members", ids == want, [ids, want])
	# 692 带 removeAtBattleEnd，本版 startBattle 开战时从出战成员身上移除（探针只把 _inBattle 设真、没真开战）：按「战斗中又挂上」再挂一次
	check("start_removed_692", not s.actor(1).is_state_affected(692), null)
	s.actor(1).add_state(692)
	var runner := XBattleEventRunner.new(l, [])
	var in_battle := ask(runner)
	check("battle", in_battle == battle_case.observed.answers, [in_battle, battle_case.observed.answers])
	check("battle_no_skip", runner.skipped.is_empty(), runner.skipped)
	# 后备的 13 在战斗里不算在队，地图上算（原版的分歧点，两边都要有）
	check("reserve_differs", bool(map_case.observed.answers.party13) and not bool(battle_case.observed.answers.party13), null)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
