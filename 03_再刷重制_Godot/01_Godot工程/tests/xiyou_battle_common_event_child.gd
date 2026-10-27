extends Node
## 事件运行中行动序列 COMMON EVENT（XBattleCommonEvent.run_or_reserve → MVEventCore.setup_child）：对照冻结 v0.28 参照
## tests/fixtures/battle_common_event_child_oracle.json（mv_oracle/battle_common_event_child_probe.cjs，真实 BattleManager）。
## 合成公共事件强制角色 8 用 292 踏地（目标动作 Common event: 375），375 再强制 83 用 5989；变量 V 当时间戳。
## 比：每次强制行动的行动者、技能与当时的 V（子事件先于父事件后续指令）、父事件跑完后的 V（117 子事件被换掉后剩下的不跑）、
## 不在事件里时照常预约。

const FIXTURE := "res://tests/fixtures/battle_common_event_child_oracle.json"
var results := []
var ref: Dictionary


class ProbeLogic extends XBattleLogic:
	var forced := []
	var v := 0

	func _force_action(p: Array, first_subject: XBattler) -> Array:
		var who := ("a%d" % int(p[1])) if int(p[0]) == 1 else ("e%d" % int(p[1]))
		forced.append({"subject": who, "skill": int(p[2]), "v": int(state.variable(v))})
		return super(p, first_subject)


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func _case(id: String) -> Dictionary:
	for c in ref.cases:
		if c.id == id:
			return c
	return {}


func battle() -> ProbeLogic:
	var party: Array = ref.party
	var s := XState.new_game(3, int(party[0]), party.slice(1).map(func(x): return int(x)))
	XState.current = s
	var l := ProbeLogic.new()
	l.v = int(ref.variable)
	l.elite_roll = 100.0
	l.setup(2, s)
	for e in l.enemies:
		e.capture = false
	s.actor(83).learn_skill(5997)
	s.set_variable(l.v, 0)
	return l


static func _forced(c: Dictionary) -> Array:
	return c.observed.actions.filter(func(x): return bool(x.forcing)).map(func(x): return {"subject": x.subject, "skill": int(x.skill), "v": int(x.v)})


## 合成公共事件追加在表尾（与探针同结构，117 指向重制这边的编号）；返回 {top, call}
func _inject() -> Dictionary:
	var t: Array = XDB.table("CommonEvents")
	var called := t.size()
	var top_c := _case("top_level")
	var call_c := _case("inside_call")
	var call_list: Array = call_c.setup.list.duplicate(true)
	for cmd in call_list:
		if int(cmd.code) == 117:
			cmd.parameters = [called]
	t.append({"id": called, "name": "探针:被叫", "list": call_c.setup.called.duplicate(true)})
	t.append({"id": called + 1, "name": "探针:顶层", "list": top_c.setup.list.duplicate(true)})
	t.append({"id": called + 2, "name": "探针:叫起", "list": call_list})
	return {"base": called, "top": called + 1, "call": called + 2}


func _in_event(id: String, ce: int) -> void:
	var c := _case(id)
	var l := battle()
	XBattleCommonEvent.reserve(l, ce)
	l.run_events()
	var want := _forced(c)
	check(id + ".forced_in_order", JSON.stringify(l.forced) == JSON.stringify(want), [l.forced, want])
	check(id + ".parent_after_child", int(l.state.variable(l.v)) == int(c.observed.finalV), [l.state.variable(l.v), c.observed.finalV])
	check(id + ".not_reserved", XBattleCommonEvent.reserved(l) == 0 and c.observed.reserved.size() == 1, XBattleCommonEvent.reserved(l))


func _no_event() -> void:
	var c := _case("no_event")
	var l := battle()
	l.act(l.state.actor(8), XDB.rec("Skills", 292), l.enemies[0])
	check("no_event.reserved", XBattleCommonEvent.reserved(l) == 375 and str(c.observed.reserved[0].id) == "375", XBattleCommonEvent.reserved(l))
	l.run_events()
	var want := _forced(c)
	check("no_event.forced", JSON.stringify(l.forced) == JSON.stringify(want), [l.forced, want])


## 解释器单元：外部装上的子游标跑完接在本层下一条；换掉 117 子游标时照常前进；先后两次外部装上沿用标记
func _core() -> void:
	var mark := func(k): return {"code": 122, "indent": 0, "parameters": [1600, 1600, 1, 0, k]}
	var end := {"code": 0, "indent": 0, "parameters": []}
	var s := XState.new_game(3, 8, [])
	XState.current = s
	s.set_variable(1600, 0)
	var r := MVEventCore.new()
	r.list = [mark.call(1), mark.call(10), end]
	r._execute(r.list[0])
	r.index = 1
	r.setup_child([mark.call(100), end])
	r.setup_child([mark.call(1000), end])
	var out := r.advance()
	check("core.resume_here", out.kind == "done" and int(s.variable(1600)) == 1011, [out, s.variable(1600)])


func _run() -> void:
	ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var manifest = XDB.load_json("manifest.json")
	var sha = manifest.get("runtimeInputs", {}).get(ref.source) if manifest is Dictionary else null
	check("fixture_matches_current_plugin", sha == ref.sha256, [ref.sha256, sha])
	for c in ref.cases:
		check("oracle_ok." + str(c.id), c.errors.is_empty(), c.errors)
	var t: Array = XDB.table("CommonEvents")
	var size := t.size()
	var ids := _inject()
	_in_event("top_level", int(ids.top))
	_in_event("inside_call", int(ids.call))
	_no_event()
	_core()
	t.resize(size)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
