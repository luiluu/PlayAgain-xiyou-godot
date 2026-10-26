extends Node
## 开战公共事件 1320「战斗开始时调整变量」（XBattleCommonEvent.START_EVENT）：对照冻结 v0.28 参照
## tests/fixtures/battle_start_event_oracle.json（mv_oracle/battle_start_event_probe.cjs，真实 BattleManager 推进到第一次输入）。
## 各例比 1320 及子事件 1315／1372／1373／1375 读写的变量、角色 79 的状态 1044（见钱眼开）；子事件里的 355 脚本
## （1373 血脉数量、1375 半人马数量）由 XBattleEventRunner 翻译，不能有跳过的指令。

const FIXTURE := "res://tests/fixtures/battle_start_event_oracle.json"
var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func _case(c: Dictionary) -> void:
	var id := str(c.id)
	var setup: Dictionary = c.setup
	var party: Array = setup.party.map(func(x): return int(x))
	var s := XState.new_game(3, party[0], party.slice(1))
	XState.current = s
	for k in setup.get("vars", {}):
		s.set_variable(int(k), float(setup.vars[k]))
	for k in setup.get("items", {}):
		s.gain_item(int(k), int(setup.items[k]))
	for sw in setup.get("switches", []):
		s.set_switch(int(sw), true)
	for k in setup.get("learn12", []):
		s.actor(12).learn_skill(int(k))
	for k in setup.get("learn79", []):
		s.actor(79).learn_skill(int(k))
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(2, s)
	check(id + ".reserved", XBattleCommonEvent.reserved(l) == XBattleCommonEvent.START_EVENT, XBattleCommonEvent.reserved(l))
	l.common_event_skipped.clear()
	l.run_events()
	check(id + ".no_skipped", l.common_event_skipped.is_empty(), l.common_event_skipped)
	check(id + ".consumed", XBattleCommonEvent.reserved(l) == 0)
	var want: Dictionary = c.observed.vars
	var got := {}
	var diff := {}
	for k in want:
		got[k] = s.variable(int(k))
		if float(got[k]) != float(want[k]):
			diff[k] = [got[k], want[k]]
	check(id + ".vars", diff.is_empty(), diff)
	var want79: bool = (c.observed.actor79States as Array).has(1044.0) or (c.observed.actor79States as Array).has(1044)
	check(id + ".state1044", s.actor(79).is_state_affected(1044) == want79, [s.actor(79).is_state_affected(1044), want79])


func _run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var manifest = XDB.load_json("manifest.json")
	var inputs: Dictionary = manifest.get("inputs", {}) if manifest is Dictionary else {}
	var runtime: Dictionary = manifest.get("runtimeInputs", {}) if manifest is Dictionary else {}
	check("fixture_matches_common_events", inputs.get(ref.source) == ref.sha256, [ref.sha256, inputs.get(ref.source)])
	check("fixture_matches_managers", runtime.get("js/rpg_managеrs.js") == ref.managers, [ref.managers, runtime.get("js/rpg_managеrs.js")])
	for c in ref.cases:
		check("oracle_ok." + str(c.id), c.errors.is_empty() and c.observed.ran == [1320.0], [c.errors, c.observed.get("ran") if c.observed else null])
		_case(c)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
