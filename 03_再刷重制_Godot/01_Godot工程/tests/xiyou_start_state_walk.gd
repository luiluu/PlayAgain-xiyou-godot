extends Node
## 开战标签状态跨场：胜利／逃跑后连战、走一步再战，逐场与原版 start_state_walk 探针一致。
## onBattleEnd 首句 clearResult；地图走一步 onPlayerWalk 全队 clearResult。
var passed := 0
var total := 0
func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))
func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func fresh(group: Dictionary) -> XState:
	var s := XState.new_game_blank()
	s.difficulty = 3
	s.party.assign([1, 8])
	s.battle_slots = [1, 8, 0, 0, 0]
	for id in [1, 8]:
		var a: XActor = s.actor(id)
		a._lv = 37
		for sid in group.skills.get(str(id), []):
			a.skill_ids.append(int(sid))
	XState.current = s
	return s

func snap(s: XState, ids: Array) -> Array:
	return s.members().map(func(a): return {"id": a.actor_id, "has": ids.filter(func(i): return a.is_state_affected(int(i))),
		"removed": a.runtime_result.removedStates.filter(func(i): return ids.has(i)).map(func(i): return int(i))})

func compare(tag: String, got: Array, row: Dictionary) -> void:
	check(tag + ".members", got.size() == row.members.size(), [got.size(), row.members.size()])
	for i in mini(got.size(), row.members.size()):
		var m: Dictionary = row.members[i]
		var g: Dictionary = got[i]
		var who := "%s.%d" % [tag, int(m.id)]
		check(who + ".id", int(g.id) == int(m.id), [g.id, m.id])
		var has: Array = g.has.duplicate(); has.sort()
		var want: Array = m.has.duplicate(); want.sort()
		check(who + ".has", same(has, want), [has, want])
		var removed: Array = g.removed.duplicate(); removed.sort()
		check(who + ".removed", same(removed, m.removed), [removed, m.removed])

func run_case(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var s := fresh(setup.group)
	var ids: Array = setup.group.ids.map(func(i): return int(i))
	var rows: Array = c.observed.rows
	var k := 0
	for n in [1, 2, 3]:
		if n == 3 and setup.plan == "walk":
			XMapScene.on_player_walk(s)
			compare(c.id + ".walk", snap(s, ids), rows[k]); k += 1
		var b := XBattleLogic.new()
		b.elite_roll = 100.0
		b.level_roll = 0.5
		b.setup(2, s)
		compare(c.id + ".battle%d_start" % n, snap(s, ids), rows[k]); k += 1
		b.end_battle(0 if setup.end == "victory" else 1)
		compare(c.id + ".battle%d_end" % n, snap(s, ids), rows[k]); k += 1
	check(c.id + ".rows_used", k == rows.size(), [k, rows.size()])

## 真实地图入口：_on_player_step 一步对全队（含后备）清结果槽。
func map_step() -> void:
	var s := XState.new_game_blank()
	s.party.assign([1, 8, 9])
	s.battle_slots = [1, 8, 0, 0, 0]
	XState.current = s
	for a in s.members():
		a.runtime_result = XResourceContext.empty_result()
		a.runtime_result.removedStates = [114]
	var map := XMapScene.new()
	add_child(map)
	await map.load_map(5, 11, 13, 2)
	s.encounter_enabled = false
	await map._on_player_step()
	for a in s.members():
		check("map_step.%d" % a.actor_id, a.runtime_result.removedStates.is_empty(), a.runtime_result)
	map.queue_free()

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/start_state_walk_oracle.json"))
	check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("cases", ref.cases.size() == 8, ref.cases.size())
	for c in ref.cases:
		check(c.id + ".native_clean", c.errors.is_empty(), c.errors)
		run_case(c)
	await map_step()
	print("TEST_RESULT=" + JSON.stringify({"total": total, "passed": passed}))
	get_tree().quit(0 if passed == total else 1)
