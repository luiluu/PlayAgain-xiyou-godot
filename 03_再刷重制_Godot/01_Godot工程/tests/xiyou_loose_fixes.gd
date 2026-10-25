extends Node
## 四零散：原版消耗与死亡入口逐例对照，敌人元素扫描边界，F31证据不被前阶段挤占。
const FIXTURE := "res://tests/fixtures/loose_fixes_oracle.json"
var passed := 0
var total := 0
var rows := {}

class CostActor extends XActor:
	func sparam(i: int) -> float:
		return 0.63 if i == 4 else super(i)

func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))

func _ready() -> void:
	_run.call_deferred()

func _state(note: String) -> int:
	var states: Array = XDB.table("States")
	var id := states.size()
	var meta := {}
	for m in RegEx.create_from_string("<([^<>:]+):([^<>]*)>").search_all(note):
		meta[m.get_string(1)] = m.get_string(2)
	states.append({"id": id, "name": "四零散参照", "note": note, "meta": meta, "traits": [], "effects": [],
		"restriction": 0, "priority": 50, "minTurns": 1, "maxTurns": 1})
	return id

func _costs() -> void:
	var s := XState.new_game_blank()
	var actor := CostActor.new().setup(1)
	actor.equips.clear()
	actor.skill_ids.clear()
	var logic := XBattleLogic.new()
	for id in rows:
		var c: Dictionary = rows[id]
		if not str(id).begins_with("cost.") or id == "cost.enemyNotReduced":
			continue
		actor.state_ids.clear()
		for note in c.setup.notes:
			actor.state_ids.append(_state(note))
		actor.param_mark_dirty()
		actor.param_refresh()
		actor.refresh_passive()
		var value := logic.skill_cost(actor, c.setup.skill)
		check(id, value.mp == int(c.observed.mp) and value.tp == int(c.observed.tp), [value, c.observed])
	var e := XEnemy.new().setup(1, 2, 100)
	e.state_ids.append(_state("<ConsumeReduceAll:100>"))
	e.param_mark_dirty()
	e.param_refresh()
	e.refresh_passive()
	var observed: Dictionary = rows["cost.enemyNotReduced"].observed
	var value := logic.skill_cost(e, {"id": 12, "stypeId": 1, "mpCost": 37, "tpCost": 19})
	check("cost.enemyNotReduced", value.mp == int(observed.mp) and value.tp == int(observed.tp), value)
	check("cost.item", logic.skill_cost(actor, {"itypeId": 1, "mpCost": 9, "tpCost": 9}) == {"mp": 0, "tp": 0})
	XState.current = s

func _battle() -> XBattleLogic:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	var logic := XBattleLogic.new()
	logic.elite_roll = 100
	logic.setup(2, s)
	XEnemyBook.on_battle_start(s, 2, {"displayName": ""}, logic.enemies)
	return logic

func _number(logic: XBattleLogic, e: XEnemy) -> int:
	return XEnemyBook.defeat_number(logic.state, e.enemy_id)

func _deaths() -> void:
	var logic := _battle()
	var e: XEnemy = logic.enemies[0]
	var shadow := XFormulaContext.clone_battler(e)
	check("death.preview_clone", shadow != null)
	if shadow != null:
		var preview := XResourceContext.new()
		preview.preview = true
		preview.gain(shadow, "hp", -shadow.hp)
		check("death.preview_no_book_write", _number(logic, e) == 0)
	XResourceContext.new().gain(e, "hp", -e.hp)
	var o: Dictionary = rows["death.hpAndQueries"].observed
	check("death.hp_first", _number(logic, e) == int(o.first), _number(logic, e))
	for i in range(8):
		e.is_dead()
		e.is_alive()
	check("death.queries_do_not_recount", _number(logic, e) == int(o.afterQueries))
	e.remove_state(1)
	e.hp = 1
	XResourceContext.new().gain(e, "hp", -1)
	check("death.second_after_revive", _number(logic, e) == int(o.second), _number(logic, e))
	XEnemyBook.on_battle_end(logic.state, [], logic.enemies)
	check("death.end_does_not_recount", _number(logic, e) == int(o.second))
	logic = _battle()
	e = logic.enemies[0]
	e.add_state(1)
	o = rows["death.explicitState"].observed
	check("death.explicit_first", _number(logic, e) == int(o.first))
	e.add_state(1)
	check("death.reapply_does_not_recount", _number(logic, e) == int(o.afterReapply))
	XEnemyBook.on_battle_end(logic.state, [], logic.enemies)
	logic = _battle()
	e = logic.enemies[0]
	o = rows["death.refreshAndTransform"].observed
	XResourceContext.new().gain(e, "hp", -e.hp)
	e.refresh_resources()
	check("death.refresh_does_not_recount", _number(logic, e) == int(o.afterRefresh))
	logic.enemy_transform(0, int(o.otherId))
	check("death.transform_current_state", XEnemyBook.defeat_number(logic.state, int(o.enemyId)) == int(o.original) and _number(logic, e) == int(o.transformed))
	XEnemyBook.on_battle_end(logic.state, [], logic.enemies)

func _bonuses() -> void:
	for id in rows:
		if not str(id).begins_with("bonus."):
			continue
		var c: Dictionary = rows[id]
		var e := XEnemy.new().setup(int(c.setup.enemyId), 2, 100)
		for note in c.setup.notes:
			e.state_ids.append(_state(note))
		e.param_mark_dirty()
		e.param_refresh()
		e.refresh_passive()
		for element in range(1, 16):
			var expected := float(c.observed.values[element - 1])
			check("%s.%d" % [id, element], absf(XDamage.element_bonus(e, element) - expected) < 1e-12, [XDamage.element_bonus(e, element), expected])

func _f31_limits() -> void:
	var s := XState.new_game_blank()
	s.add_actor(8)
	var runner = load("res://tests/xiyou_floor_run.gd").new()
	var fixture: Dictionary = runner._f31_fixture(s)
	var holder := XEnemy.new().setup(1, 2, 100)
	for i in range(100):
		XStateEffects.observer.call("react", 1047, holder, {"item": {"id": 12}, "value": i})
	for i in range(100):
		XStateEffects.observer.call("react", 1048, holder, {"item": {"id": 12}, "value": i})
	check("F31.first_phase_capped", fixture.stage_counts[1047] == 64)
	check("F31.second_phase_not_starved", fixture.stage_counts[1048] == 64 and fixture.stages.size() == 128)
	runner._restore_f31_fixture(s, fixture)
	runner.free()

func _run() -> void:
	var ref = XDB.load_json(FIXTURE)
	if ref is Dictionary:
		for c in ref.get("cases", []):
			check(str(c.id) + ".oracle_clean", c.errors.is_empty())
			if c.errors.is_empty():
				rows[c.id] = c
	check("oracle_complete", rows.size() == 34)
	if rows.size() == 34:
		_costs()
		_deaths()
		_bonuses()
		_f31_limits()
	print("TEST_RESULT=", JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
