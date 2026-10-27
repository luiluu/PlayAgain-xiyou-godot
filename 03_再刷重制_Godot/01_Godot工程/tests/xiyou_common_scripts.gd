extends Node
## 效果型公共事件脚本对照（八戒 2026-10-27）：mv_oracle/common_script_probe.cjs（generated/oracle/common_scripts.json）的每一例，
## 以同样的前提（选中角色与已学技能、变量、开关、物品、所在格、藏宝图预掷池与已挖宝点、更衣解锁表、随机数）在 MVInterpreter 上跑同一公共事件，
## 逐项比较提示／场景、关心的变量与物品数、选中角色的技能、队伍、预约公共事件、预掷池用量、已挖宝点、更衣解锁。
## 覆盖：遗忘技能类（CE637～648、1378～1380、83）、藏宝图（CE117、174～189、1381～1384）、超强者招募（CE2501～2526）、CE367。
## 宿主用事件对照的记录替身（tests/xiyou_event_compare.gd 的 EventHost）。

const ORACLE := "res://modes/xiyou/generated/oracle/common_scripts.json"
const EC := preload("res://tests/xiyou_event_compare.gd")
const PARTY := [1, 8, 9, 10]

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _run() -> void:
	GameApp.fast_headless_frames()
	XSave.dir_override = "user://test_xiyou_common_scripts"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	_check("oracle_loaded", oracle is Dictionary and oracle.get("cases", []).size() > 150)
	if not oracle is Dictionary:
		_finish()
		return
	_check("oracle_no_errors", oracle.cases.all(func(c): return c.errors.is_empty()), oracle.cases.filter(func(c): return not c.errors.is_empty()).map(func(c): return c.id))
	var host = EC.EventHost.new()
	add_child(host)
	var kinds := {}
	for c in oracle.cases:
		if not c.errors.is_empty():
			continue
		var got := await _case(c.setup, host)
		var want: Dictionary = c.observed
		var diffs := []
		for k in want:
			if JSON.stringify(_norm(want[k])) != JSON.stringify(_norm(got.get(k))):
				diffs.append([k, want[k], got.get(k)])
		var kind := str(c.id).get_slice(".", 0)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		_check(str(c.id), diffs.is_empty(), diffs)
	print("COMMON_SCRIPTS ", JSON.stringify(kinds))
	XConfig.clothes_unlocked().clear()
	_finish()


static func _norm(v):
	return JSON.parse_string(JSON.stringify(v)) if v != null else null


func _case(spec: Dictionary, host) -> Dictionary:
	var s := XState.new_game_blank()
	s.difficulty = int(spec.get("difficulty", 3))
	for id in PARTY:
		s.add_actor(id)
	s.map_id = 4
	s.x = 0  # 参照新局玩家在大厅 (0,0)
	s.y = 0
	XState.current = s
	XDungeon.battle = {}
	var lite := XConfig.clothes_unlocked()
	lite.clear()
	for id in spec.get("clothes", []):
		lite.append(int(id))
	if spec.has("target"):
		var a := s.actor(int(spec.target))
		for id in spec.get("learn", []):
			a.learn_skill(int(id))
		s.item_target_actor_id = int(spec.target)
	for k in spec.get("vars", {}):
		s.set_variable(int(k), float(spec.vars[k]))
	for k in spec.get("gainItems", {}):
		s.gain_item(int(k), int(spec.gainItems[k]))
	for k in spec.get("gainWeapons", {}):
		s.gain_gear("weapon", int(k), int(spec.gainWeapons[k]))
	for k in spec.get("gainArmors", {}):
		s.gain_gear("armor", int(k), int(spec.gainArmors[k]))
	for id in spec.get("switches", []):
		s.set_switch(int(id), true)
	if spec.has("at"):
		s.map_id = int(spec.at[0])
		s.x = int(spec.at[1])
		s.y = int(spec.at[2])
	if spec.has("rom"):
		s.rom.g = spec.rom.map(func(v): return int(v))
		s.rom.gn = int(spec.get("romNum", 0))
	if spec.has("dug"):
		s.rom.m = spec.dug.map(func(v): return int(v))
	host.trace = []
	host.seen = {}
	MVInterpreter.fixed_random = float(spec.get("random", 0.5))
	MVInterpreter.max_steps = 20000
	MVInterpreter.steps = 0
	MVInterpreter.aborted = false
	var interp := MVInterpreter.new(host, s.map_id, 0, XDB.rec("CommonEvents", int(spec.common)).get("list", []).duplicate(true))
	await interp.run()
	var watch: Dictionary = spec.get("watch", {})
	var a: XActor = s.actor(int(spec.target)) if spec.has("target") else null
	return {
		"trace": host.trace.duplicate(true),
		"variables": watch.get("vars", []).map(func(id): return s.variable(int(id))),
		"items": watch.get("items", []).map(func(id): return s.item_count(int(id))),
		"weapons": watch.get("weapons", []).map(func(id): return s.gear_count("weapon", int(id))),
		"armors": watch.get("armors", []).map(func(id): return s.gear_count("armor", int(id))),
		"skills": watch.get("skills", []).filter(func(id): return a != null and a.skill_ids.has(int(id))),
		"party": s.party.duplicate(),
		"reserved": s.peek_common_event(),
		"romGetNum": int(s.rom.get("gn", 0)),
		"dug": _sorted(s.rom.get("m", [])),
		"clothes": watch.get("clothes", []).filter(func(id): return XChangeClothes.unlocked(int(id))),
	}


static func _sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort()
	return out


func _finish() -> void:
	MVInterpreter.fixed_random = -1.0
	DirAccess.remove_absolute(XSave.dir().path_join("options.json"))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
