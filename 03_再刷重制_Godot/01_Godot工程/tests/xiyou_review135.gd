extends Node
## dev.135 P2 regressions; compare new native rows and exercise actual host paths.
var results := []

class ReservationState:
	extends XState
	var writes := []
	func set_variable(id: int, value: float) -> void:
		if id == 4998:
			writes.append([value, peek_common_event()])
			if value == 1:
				reserve_common_event(10)
		super.set_variable(id, value)

class ReservationMap:
	extends XMapScene
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func refresh_events() -> void: pass
	func play_se(_data: Dictionary) -> void: pass

func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok: print("FAIL ", name, " ", detail)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var ref = XDB.load_json("oracle/review135.json")
	if ref is Dictionary and ref.get("cases", []).size() == 3:
		var cases := {}
		for c in ref.cases:
			check(c.id + ".native_clean", c.errors.is_empty())
			cases[c.id] = c.observed
		_variables(cases["preview.variables"])
		_power_context()
		await _reservations(cases["reservation.shared_slot"], cases["reservation.session_reset"])
	else:
		check("oracle_present", false)
	# Actual menu confirmation plays the system sound; stop and let audio settle.
	for p in XSound._players:
		if is_instance_valid(p): p.stop()
	await get_tree().create_timer(0.5, true, false, true).timeout
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)

func _variables(o: Dictionary) -> void:
	var s := XState.new_game(3, 1, [])
	var a := s.actor(1)
	var b := XEnemy.new().setup(1, 3, 100.0)
	for row in o.rows:
		s.variables.clear()
		if row.mode != "unset": s.set_variable(int(row.variable), float(row.getter))
		var ctx := {"attacker": a, "defender": b, "item": {"damage": {"type": 1}, "hitType": 1}, "value": 100.0, "execute": false}
		var before := [s.to_dict(), a.param_cells.duplicate(), a.effect_lists.duplicate(true),
			a.param_dirty, a.effect_dirty, XStateEffects.diagnostics.duplicate(true), s.runtime_random_snapshot()]
		var got := XStateEffects.run_one("confirm", a, XDB.rec("States", int(row.state)), ctx)
		check("variables.fallback.%d.%s" % [row.state, row.mode], is_finite(got) and absf(got - float(row.value)) < 1e-9, got)
		var after := [s.to_dict(), a.param_cells, a.effect_lists, a.param_dirty, a.effect_dirty,
			XStateEffects.diagnostics, s.runtime_random_snapshot()]
		check("variables.preview_unchanged.%d.%s" % [row.state, row.mode], before == after)
		# Explicit sparse pools use Game_Variables.value defaults and override current state.
		ctx.variables = {str(int(row.variable)): float(row.getter)} if row.mode == "set" else {}
		got = XStateEffects.run_one("confirm", a, XDB.rec("States", int(row.state)), ctx)
		check("variables.explicit.%d.%s" % [row.state, row.mode], is_finite(got) and absf(got - float(row.value)) < 1e-9, got)
		if row.mode == "zero":
			s.set_variable(int(row.variable), 7)
			ctx.variables = []
			got = XStateEffects.run_one("confirm", a, XDB.rec("States", int(row.state)), ctx)
			check("variables.explicit_overrides_current.%d" % row.state, absf(got - float(row.value)) < 1e-9)
			ctx.erase("variables")
			XState.current = null
			got = XStateEffects.run_one("confirm", a, XDB.rec("States", int(row.state)), ctx)
			check("variables.no_session.%d" % row.state, is_finite(got) and absf(got - float(row.value)) < 1e-9, got)
			XState.current = s

func _power_context() -> void:
	var s := XState.new_game(3, 1, [])
	var a := s.actor(1)
	var b := XEnemy.new().setup(1, 3, 100.0)
	var logic := XBattleLogic.new()
	var skill := XDB.rec("Skills", 1).duplicate(true)
	skill.damage.critical = true
	skill.damage.formulaProgram = {"version": 1, "status": "pure", "locals": [],
		"source": {"sha256": "review135-constant100"}, "result": "completion",
		"steps": [{"op": "expr", "value": {"op": "literal", "value": 100.0}}]}
	a.state_ids.assign([2676]) # Native variable-20 modifier: power deliberately evaluates with v[20] = 0.
	a.param_refresh()
	s.set_variable(20, 0)
	var first := XPower._expected(logic, a, b, skill, {"mp": 0.0, "tp": 0.0})
	s.set_variable(20, 30)
	var second := XPower._expected(logic, a, b, skill, {"mp": 0.0, "tp": 0.0})
	check("power.normal_and_critical_use_preview_variables", first > 0.0 and is_finite(second) and absf(first - second) < 1e-9, [first, second])
	for sid in [1421, 1422, 1424, 1259, 1726, 1733]:
		a.state_ids.assign([sid])
		a.param_refresh()
		var got := XPower._expected(logic, a, b, skill, {"mp": 0.0, "tp": 0.0})
		check("power.finite.%d" % sid, is_finite(got), got)

func _reservations(o: Dictionary, reset: Dictionary) -> void:
	var s := ReservationState.new()
	XState.current = s
	var map := ReservationMap.new()
	add_child(map)
	var menu := XMenu.new()
	menu.event_state = s
	var rows := []
	menu.closed.connect(func(): rows.append(["menu_closed", s.peek_common_event()]))
	menu._cmd_index = menu.COMMANDS.find(["存档", "save", true])
	menu._ok()
	rows.append(["save", s.peek_common_event()])
	map.busy = true
	await map.return_to_hub()
	rows.append(["maple", s.peek_common_event()])
	menu._cmd_index = menu.COMMANDS.find(["成就", "achievement", true])
	menu._ok()
	rows.append(["achievement", s.peek_common_event()])
	check("reservation.busy_keeps_last", s.peek_common_event() == 431 and map.busy)
	map.busy = false
	var ce := XDB.rec("CommonEvents", 431)
	var original: Array = ce.list
	# A short host fixture, not the achievement page: observe clear before first command,
	# and make a new reservation inside the running interpreter before its wait resumes.
	ce.list = [{"code": 122, "indent": 0, "parameters": [4998, 4998, 0, 0, 1]},
		{"code": 230, "indent": 0, "parameters": [2]},
		{"code": 122, "indent": 0, "parameters": [4998, 4998, 0, 0, 2]}, {"code": 0, "indent": 0, "parameters": []}]
	rows.append(["before_setup", s.peek_common_event()])
	map.run_reserved_common_event(s)
	check("reservation.clear_before_execute", s.writes == [[1.0, 0]], s.writes)
	rows.append(["after_setup", s.writes[0][1] if not s.writes.is_empty() else -1])
	rows.append(["while_running", s.peek_common_event()])
	# JSON numbers are float Variants; event IDs from the runtime API are ints.
	var native_rows := []
	var integer_ids := true
	for row in o.rows:
		integer_ids = integer_ids and float(row[1]) == floorf(float(row[1]))
		native_rows.append([str(row[0]), int(row[1])])
	check("reservation.native_shared_sequence", integer_ids and rows == native_rows, {"got": rows, "want": native_rows})
	check("reservation.running_after_clear", map.busy and bool(o.running))
	for i in range(120):
		if not map.busy: break
		await get_tree().process_frame
	check("reservation.new_request_survives_completion", not map.busy and s.peek_common_event() == 10 and s.variable(4998) == 2 and s.writes == [[1.0, 0], [2.0, 10]], s.writes)
	ce.list = original
	s.reserve_common_event(int(reset.before))
	var saved := s.to_dict()
	var loaded := XState.from_dict(saved)
	var other := XState.new()
	check("reservation.saved_slot_omitted", not saved.has("reserved_common_event_id") and not saved.has("_reserved_common_event_id"))
	check("reservation.load_new_and_other_empty", loaded.peek_common_event() == int(reset.loaded) and other.peek_common_event() == int(reset.independent) and XState.new_game_blank().peek_common_event() == int(reset.newGame))
	XState.current = other
	menu._ok()
	await map.run_reserved_common_event(s)
	check("reservation.stale_menu_keeps_owner", s.peek_common_event() == 431 and other.peek_common_event() == 0)
	menu.free()
	map.queue_free()
	await get_tree().process_frame
