extends Node
## 洪荒诅咒自选（公共事件 1442，XHonghuang＋MVScript._honghuang_curse）对原版参照 tests/fixtures/honghuang_curse_oracle.json
## （mv_oracle/honghuang_curse_probe.cjs，12 例：直接跑 CE1442 与大厅 Map004 EV41 第 3／5 页，选项按 picks 依次应答）。
## 宿主用 xiyou_event_compare 的记录替身，只把选项应答换成用例的 picks。逐例比：每次运行的文字与选项（含取消类型、默认项）、
## 跑没跑完、变量 9／20／1468～1472／1482、开关 2461～2463／2483、样本角色（队伍四人＋2、50）学到的诅咒、候选是否清掉、curseBonus；
## 另比「每种学到的诅咒都给了全部有名字的角色」（原版 166 名，重制切片里的角色少，只比全员这一点，不比人数）。
## 再查 1442 这几段脚本都认得（解释器 skipped 为空）。
const FIXTURE := "res://tests/fixtures/honghuang_curse_oracle.json"
const PARTY := [1, 8, 9, 10]
var checks := 0
var failures: Array = []


class PickHost:
	extends "res://tests/xiyou_event_compare.gd".EventHost
	var picks: Array = []
	var at := 0
	var messages: Array = []

	func show_message(msg: Dictionary) -> int:
		var e := {"face": str(msg.get("face", "")), "index": int(msg.get("index", 0)), "lines": msg.get("lines", [])}
		if msg.has("choices"):
			var pick: int = int(picks[at]) if at < picks.size() else 0
			at += 1
			e.choices = msg.choices
			e.cancel = int(msg.get("cancel", 0))
			e.default = int(msg.get("default", 0))
			e.pick = pick
			messages.append(e)
			return pick
		if not e.lines.is_empty():
			messages.append(e)
		return 0


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1500))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameApp.fast_headless_frames()
	XMessageBox.auto = true
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("source", f.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("complete", f.cases.size() == 12)
	check("label.first", XHonghuang.curse_label(1) == "【重·×1.5】万法俱衰（全属性*0.5）", XHonghuang.curse_label(1))
	check("label.zwsp", XHonghuang.curse_label(12) == "【重·×1.5】武能溃散（物理属性伤害*0.1）", XHonghuang.curse_label(12))
	check("label.light", XHonghuang.curse_label(3) == "【轻】残魂苟存（敌人免死0~1回合）", XHonghuang.curse_label(3))
	var host := PickHost.new()
	add_child(host)
	for c in f.cases:
		check(c.id + ".oracle", c.errors.is_empty(), c.errors)
		if c.errors.is_empty():
			await run_case(c, host)
	var passed := checks - failures.size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": checks}))
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)


func run_case(c: Dictionary, host: PickHost) -> void:
	var spec: Dictionary = c.setup
	var o: Dictionary = c.observed
	var s := XState.new_game_blank()
	s.difficulty = 3
	for id in PARTY:
		s.add_actor(id)
	s.map_id = 4
	XState.current = s
	XHonghuang.offer = null
	XHonghuang.picked = null
	for id in spec.get("pre", {}):
		for sk in spec.pre[id]:
			s.actor(int(id)).learn_skill(int(sk))
	var list: Array
	var event_id := 0
	if spec.has("map"):
		s.set_variable(20, int(spec.map.v20))
		s.set_switch(2489, true)
		if spec.map.get("on2483", false):
			s.set_switch(2483, true)
		for ev in XDB.map(4).get("events", []):
			if ev is Dictionary and int(ev.id) == 41:
				list = ev.pages[int(spec.map.page)].list
		event_id = 41
	else:
		list = XDB.rec("CommonEvents", 1442).get("list", [])
	var got_runs := []
	var skipped := []
	for picks in spec.runs:
		if not spec.has("map"):
			s.set_variable(1482, int(spec.v1482))
		host.picks = picks
		host.at = 0
		host.messages = []
		var interp := MVInterpreter.new(host, 4, event_id, list.duplicate(true))
		await interp.run()
		skipped.append_array(interp.skipped)
		got_runs.append({"messages": host.messages.duplicate(true), "usedPicks": host.at})
	check(c.id + ".skipped", skipped.is_empty(), skipped)
	for i in o.runs.size():
		var want: Dictionary = o.runs[i]
		var got: Dictionary = got_runs[i]
		check("%s.run%d.finished" % [c.id, i], bool(want.finished))
		check("%s.run%d.picks" % [c.id, i], int(want.usedPicks) == int(got.usedPicks), [want.usedPicks, got.usedPicks])
		check("%s.run%d.count" % [c.id, i], want.messages.size() == got.messages.size(), [want.messages.size(), got.messages.size()])
		for k in mini(want.messages.size(), got.messages.size()):
			var w: Dictionary = want.messages[k]
			var g: Dictionary = got.messages[k]
			for key in w:
				var same: bool = str(w[key]) == str(g.get(key)) if not (w[key] is float) else int(w[key]) == int(g.get(key, -99))
				check("%s.run%d.msg%d.%s" % [c.id, i, k, key], same, [w[key], g.get(key)])
	for v in o.vars:
		check("%s.var%s" % [c.id, v], int(o.vars[v]) == int(s.variable(int(v))), [o.vars[v], s.variable(int(v))])
	for sw in o.switches:
		check("%s.sw%s" % [c.id, sw], bool(o.switches[sw]) == s.switch(int(sw)), [o.switches[sw], s.switch(int(sw))])
	for id in o.actors:
		check("%s.actor%s" % [c.id, id], _curses(s.actor(int(id))) == o.actors[id].map(func(v): return int(v)), [o.actors[id], _curses(s.actor(int(id)))])
	var named := []
	for rec in XDB.table("Actors"):
		if rec != null and str(rec.get("name", "")) != "":
			named.append(int(rec.id))
	var learners := {}
	for id in named:
		for sk in _curses(s.actor(id)):
			learners[sk] = int(learners.get(sk, 0)) + 1
	var want_learned: Array = o.learners.keys().map(func(k): return int(k))
	want_learned.sort()
	var got_learned: Array = learners.keys()
	got_learned.sort()
	check(c.id + ".learned_kinds", want_learned == got_learned, [want_learned, got_learned])
	check(c.id + ".learned_all", learners.values().all(func(n): return n == named.size()), [learners, named.size()])
	check(c.id + ".temp_cleared", (XHonghuang.offer != null or XHonghuang.picked != null) == bool(o.tempLeft))
	var bonus := XHonghuang.curse_bonus(s.members()[0])
	check(c.id + ".bonus", absf(bonus - float(o.curseBonus)) < 1e-6, [o.curseBonus, bonus])


func _curses(a: XActor) -> Array:
	return XHonghuang.curse_ids(a)
