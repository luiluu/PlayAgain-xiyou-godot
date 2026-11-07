extends Node
## 【cc·哪吒·未经审查】难度 7～9 角色侧对冻结 v0.28 参照 generated/oracle/difficulty_actor.json（mv_oracle/difficulty_actor_probe.cjs）：
## 两边跑同一段原版事件——天灾开局（Map001 EV1 选天灾那一支＋天道使者变量＋大厅 EV20 增减技能＋CE1319），再按用例跑大厅
## Map004 EV41 第 2 页（进灭世）、第 6 页（再开洪荒＋CE1442 选诅咒）、EV62 第 4 页（31 层后：关难度开关、改怪物属性到混沌，可选灭世 debuff）。
## 逐例比：每段跑完与应答数、难度号、难度开关与相关变量、样本角色的全部技能、状态、1 级能力（被动刷新后）、开战加的 StartPushState
## 与开战能力（加完再刷新被动）。选项按 picks 依次应答（宿主同 xiyou_honghuang_curse）。
## floor1：参照已是新源 v0.62.12；每例另有 .tier 变体，样本换成不在队的强者 11、超强者 96 与 148（v0.44 起 <KyoTier> 分强弱），共 12 例。
const ORACLE := "oracle/difficulty_actor.json"
const PARTY := [1, 8, 9, 10]
const ELEMENTS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15]
var checks := 0
var failures: Array = []


class PickHost:
	extends "res://tests/xiyou_event_compare.gd".EventHost
	var picks: Array = []
	var at := 0

	func show_message(msg: Dictionary) -> int:
		if msg.has("choices"):
			var pick: int = int(picks[at]) if at < picks.size() else 0
			at += 1
			return pick
		return 0


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 30:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1200))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameApp.fast_headless_frames()
	XMessageBox.auto = true
	var d = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + ORACLE))
	if not (d is Dictionary and d.cases.size() == 12):
		check("oracle", false, ORACLE)
		return finish()
	check("source", d.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	var host := PickHost.new()
	add_child(host)
	for c in d.cases:
		check(c.id + ".oracle", c.errors.is_empty(), c.errors)
		if c.errors.is_empty():
			# floor1：.tier 例（强者 11、超强者 96／148）的样本写在用例 setup.sample 里
			await run_case(c, host, Array(c.setup.get("sample", d.sample)))
	XState.current = null
	finish()


func _event_page(map_id: int, event_id: int, page: int) -> Array:
	for ev in XDB.map(map_id).get("events", []):
		if ev is Dictionary and int(ev.id) == event_id:
			return ev.pages[page - 1].list
	return []


## 取一段命令，缩进整体左移到 0，末尾补结束命令（同探针 seg）
func _seg(list: Array, from: int, to: int) -> Array:
	var out := []
	var base := int(list[from].indent)
	for i in range(from, to + 1):
		var c: Dictionary = list[i].duplicate(true)
		c.indent = int(c.indent) - base
		out.append(c)
	out.append({"code": 0, "indent": 0, "parameters": []})
	return out


func _find(list: Array, code: int, pred: Callable, after := -1) -> int:
	for i in range(after + 1, list.size()):
		if int(list[i].code) == code and pred.call(list[i].parameters):
			return i
	return -1


func _opening() -> Array:
	var m1 := _event_page(1, 1, 1)
	var ev20 := _event_page(4, 20, 1)
	var tz0 := _find(m1, 402, func(p): return str(p[1]) == "天灾难度") + 1
	var tz1 := _find(m1, 404, func(_p): return true, tz0) - 1
	var c0 := _find(m1, 122, func(p): return int(p[0]) == 8)
	var c1 := _find(m1, 122, func(p): return int(p[0]) == 14)
	var e0 := _find(ev20, 318, func(p): return int(p[1]) == 1 and int(p[3]) == 2571)
	return [_seg(m1, tz0, tz1), _seg(m1, c0, c1), _seg(ev20, e0, ev20.size() - 2), XDB.rec("CommonEvents", 1319).get("list", [])]


func _interp(host: PickHost, map_id: int, event_id: int, list: Array, picks: Array) -> Dictionary:
	host.picks = picks
	host.at = 0
	var interp := MVInterpreter.new(host, map_id, event_id, list.duplicate(true))
	await interp.run()
	return {"usedPicks": host.at, "skipped": interp.skipped}


func run_case(c: Dictionary, host: PickHost, sample: Array) -> void:
	var o: Dictionary = c.observed
	var s := XState.new_game_blank()
	for id in PARTY:
		s.add_actor(id)
	s.map_id = 4
	s.actor_max_level = 99
	XState.current = s
	XHonghuang.offer = null
	XHonghuang.picked = null
	var got := []
	for list in _opening():
		got.append(await _interp(host, 1, 1, list, []))
	for st in c.setup.stages:
		if st.has("v20"):
			s.set_variable(20, int(st.v20))
		got.append(await _interp(host, 4, int(st.ev), _event_page(4, int(st.ev), int(st.page)), st.picks))
	check(c.id + ".runs", got.size() == o.runs.size(), [got.size(), o.runs.size()])
	for i in mini(got.size(), o.runs.size()):
		check("%s.run%d.picks" % [c.id, i], int(got[i].usedPicks) == int(o.runs[i].usedPicks), [got[i].usedPicks, o.runs[i].usedPicks])
		check("%s.run%d.skipped" % [c.id, i], got[i].skipped.is_empty(), got[i].skipped)
	check(c.id + ".difficulty", s.difficulty == int(o.difficultyId), [s.difficulty, o.difficultyId])
	for sw in o.switches:
		check("%s.sw%s" % [c.id, sw], s.switch(int(sw)) == bool(o.switches[sw]), [s.switch(int(sw)), o.switches[sw]])
	for v in o.vars:
		check("%s.var%s" % [c.id, v], int(s.variable(int(v))) == int(o.vars[v]), [s.variable(int(v)), o.vars[v]])
	for id in sample:
		var want: Dictionary = o.actors[str(int(id))]
		var a: XActor = s.actor(int(id))
		var tag := "%s.actor%d" % [c.id, int(id)]
		a.refresh_passive()
		var skills: Array = Array(a.skill_ids)
		skills.sort()
		check(tag + ".skills", skills == _ints(want.skills), {"godot": skills, "mv": want.skills, "missing": _ints(want.skills).filter(func(x): return not skills.has(x)), "extra": skills.filter(func(x): return not _ints(want.skills).has(x))})
		var states: Array = Array(a.state_ids)
		states.sort()
		check(tag + ".states", states == _ints(want.states), [states, want.states])
		_compare_snap(tag + ".lv1", _snap(a), want.lv1)
		var added := []
		for t in a.battle_start_state_tags():
			if str(t[0]) == "StartPushState" and 50.0 < float(t[2]):
				a.add_state(int(t[1]))
				added.append(int(t[1]))
		a.refresh_resources()
		a.refresh_passive()
		check(tag + ".startStates", added == _ints(want.startStates), [added, want.startStates])
		var bstates: Array = Array(a.state_ids)
		bstates.sort()
		check(tag + ".battleStates", bstates == _ints(want.battleStates), [bstates, want.battleStates])
		_compare_snap(tag + ".battle", _snap(a), want.battle)


func _ints(a: Array) -> Array:
	return a.map(func(v): return int(v))


func _snap(b: XBattler) -> Dictionary:
	return {"param": range(8).map(func(i): return b.param(i)),
		"xparam": range(10).map(func(i): return b.xparam(i)),
		"sparam": range(10).map(func(i): return b.sparam(i)),
		"elementRates": ELEMENTS.map(func(e): return b.element_rate(e))}


func _compare_snap(tag: String, mine: Dictionary, theirs: Dictionary) -> void:
	for k in ["param", "xparam", "sparam", "elementRates"]:
		var ok: bool = mine[k].size() == theirs[k].size()
		for i in mini(mine[k].size(), theirs[k].size()):
			ok = ok and absf(float(mine[k][i]) - float(theirs[k][i])) <= 1e-4 * maxf(1.0, absf(float(theirs[k][i])))
		check("%s.%s" % [tag, k], ok, {"godot": mine[k], "mv": theirs[k]})


func finish() -> void:
	var passed := checks - failures.size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": checks}))
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)
