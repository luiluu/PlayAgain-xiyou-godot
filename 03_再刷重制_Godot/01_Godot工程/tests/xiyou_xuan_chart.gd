extends Node
## 【cc·哪吒·未经审查】xuan1 璇的星谱（XXuanChart、XXuanChartPage、XTusuXuan.chart／sync_marks）：照参照 mv_oracle/xuan_chart_probe.cjs
## （tests/fixtures/xuan_chart_oracle.json，冻结 v0.28）逐例比——学习／强化／回收／配槽的返回值、报错原文、星砂、等级、已学星纹技能、markLevel；
## 各等级放行；胜利星砂（普通＋3、含 Boss 的敌群＋12、逃跑失败不加、后备不加）；星谱页各页行文与点选结果。
## 另有本地断言：存档往返、公共事件 9015 的脚本由地图解释器认下、技能页可用。
const FIXTURE := "res://tests/fixtures/xuan_chart_oracle.json"
const XUAN := 177
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(900))


## 数字统一成整数、字典按键排序后比字符串
func norm(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return norm(x))
	if v is float and v == floorf(v):
		return int(v)
	return v


func same(a, b) -> bool:
	return JSON.stringify(norm(a), "", true) == JSON.stringify(norm(b), "", true)


func setup(level: int, sand: int, adv := 0) -> XState:
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	s.actor_max_level = 99
	s.set_switch(XItemMarks.SUPER_SWITCHES[0], true)
	XTusuXuan.recruit(s, XUAN)
	var a: XActor = s.actor(XUAN)
	a.change_level_mv(level)
	XXuanChart.chart(s).sand = sand
	if adv:
		s.actor_advance[XUAN] = adv
	return s


func mark_ids() -> Array:
	return XTusuXuan.MARKS.map(func(m): return XTusuXuan.skill_id(XUAN, "mark." + m))


func snap(s: XState) -> Dictionary:
	var a: XActor = s.actor(XUAN)
	var ids := mark_ids()
	var marks := a.skill_ids.filter(func(i): return ids.has(i))
	marks.sort()
	var c := XXuanChart.chart(s)
	return {"chart": c.duplicate(true), "marks": marks, "markLevel": XTusuXuan.MARKS.map(func(m): return XXuanChart.mark_level(s, a, m)),
		"control": XXuanChart.control(s) if XXuanChart.control(s) != "" else null}


func op(s: XState, name: String, m: String) -> Dictionary:
	var a: XActor = s.actor(XUAN)
	match name:
		"learn":
			return XXuanChart.learn(s, a, m)
		"refund":
			return XXuanChart.refund(s, a, m)
	return XXuanChart.equip(s, a, m)


## 参照里 ret 缺（抛错）时记 error
func step_view(s: XState, name: String, m: String) -> Dictionary:
	var r := op(s, name, m)
	var out := snap(s)
	if str(r.error) != "":
		out["why"] = r.error
	else:
		out["ret"] = r.ret
	return out


func _ops(c: Dictionary) -> void:
	var s := setup(int(c.setup.level), int(c.setup.sand))
	check(c.id + ".start", same(snap(s), c.observed.start), [snap(s), c.observed.start])
	for i in c.observed.steps.size():
		var st: Dictionary = c.observed.steps[i]
		var got := step_view(s, str(st.op), str(st.m))
		var want := st.duplicate(true)
		want.erase("op")
		want.erase("m")
		check("%s.%d.%s.%s" % [c.id, i, st.op, st.m], same(got, want), [got, want])


func _gate(c: Dictionary) -> void:
	for row in c.observed.rows:
		var s := setup(int(row.level), 1000)
		var learn := {}
		var equip := {}
		for m in XTusuXuan.MARKS:
			learn[m] = step_ret(op(s, "learn", m))
		for m in XTusuXuan.MARKS:
			equip[m] = step_ret(op(s, "equip", m))
		var got := snap(s)
		got["learn"] = learn
		got["equip"] = equip
		check("gate.%d" % int(row.level), same({"learn": got.learn, "equip": got.equip, "chart": got.chart, "marks": got.marks, "lv": got.markLevel},
			{"learn": row.learn, "equip": row.equip, "chart": row.chart, "marks": row.marks, "lv": row.markLevel}), got)


func step_ret(r: Dictionary) -> Dictionary:
	return {"why": r.error} if str(r.error) != "" else {"ret": r.ret}


## 一场战斗：璇按 front 站位，troop 打胜（result 0）走 grant，别的结果不发奖励
func fight(s: XState, troop: int, result: int) -> Dictionary:
	var l := XBattleLogic.new()
	l.setup(troop, s, XBattleRandom.create("0000000000000177"))
	var before := int(XXuanChart.chart(s).sand)
	var in_battle := l.actors.any(func(x): return int(x.actor_id) == XUAN)
	if result == 0:
		l.grant(l.rewards())
	l.end_battle(result)
	return {"troop": troop, "result": result, "inBattle": in_battle, "before": before, "after": int(XXuanChart.chart(s).sand)}


func _sand(obs: Dictionary) -> void:
	var T: Dictionary = obs["sand.troops"]
	check("sand.troops_boss", int(T.boss) > 0 and int(T.plain) > 0, T)
	for k in ["plain.win", "boss.win", "plain.escape", "plain.lose", "boss.escape", "plain.win.bench"]:
		var o: Dictionary = obs["sand." + k]
		var s := setup(60, 0)
		s.party.clear()
		s.battle_slots.clear()
		var ids := [1, 8, 9, 10, 2, 3, 4, 5, 6, 7, XUAN] if k.ends_with("bench") else [XUAN, 1, 8, 9]
		for id in ids:
			s.add_actor(id)
		var got := fight(s, int(o.troop), int(o.result))
		check("sand." + k, same(got, o), [got, o])
	var s2 := setup(60, 0)
	s2.party.clear()
	s2.battle_slots.clear()
	for id in [XUAN, 1, 8, 9]:
		s2.add_actor(id)
	var rows := []
	for t in [T.plain, T.boss, T.plain]:
		fight(s2, int(t), 0)
		rows.append(int(XXuanChart.chart(s2).sand))
	check("sand.twice", same(rows, obs["sand.twice"].rows), rows)


func drive(page: XXuanChartPage, steps: Array) -> void:
	for st in steps:
		var ch: XChoiceWindow = page.choice
		if str(st) == "<":
			ch._cancel.call()
		elif str(st).begins_with("@"):
			ch._ok.call(ch.rows[int(str(st).substr(1))])
		else:
			var i := ch.rows.find_custom(func(r): return str(r.label) == str(st))
			if i < 0:
				check("flow.row_missing", false, [st, ch.rows.map(func(r): return r.label)])
				return
			ch._ok.call(ch.rows[i])


func _flow(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := setup(int(c.setup.level), int(c.setup.sand), int(c.setup.adv))
	if c.id == "flow.not-in-party":
		s.party.erase(XUAN)
		check(c.id, XXuanChart.xuan(s) == null and not o.homed)
		return
	var page := XXuanChartPage.new()
	add_child(page)
	page.closed.connect(func(): page.log.append({"popped": true}))
	drive(page, o.steps)
	var shown := page.log.map(func(e): return e if e.has("popped") else {"info": e.info, "rows": e.rows})
	check(c.id + ".screens", same(shown, o.screens), [shown.size(), o.screens.size()])
	var view := snap(s)
	check(c.id + ".state", same({"marks": view.marks, "markLevel": view.markLevel, "control": view.control, "chart": view.chart},
		{"marks": o.marks, "markLevel": o.markLevel, "control": o.control, "chart": o.chart}), [view, o.chart])
	page.queue_free()


func _local() -> void:
	# 存档往返：星谱记在 s.flags 里，读回来一样
	var s := setup(60, 100, 3)
	XXuanChart.learn(s, s.actor(XUAN), "yuhui")
	XXuanChart.set_control(s, s.actor(XUAN), "auto")
	XXuanChart.set_element(s, 3)
	var copy = JSON.parse_string(JSON.stringify(s.flags))
	check("save.roundtrip", same(copy._codexXuanChart, XXuanChart.chart(s)) and str(copy._codexXuanControl) == "auto", copy)
	# 反向：不够条件不能开自律；战斗外之外（模式写错）也不改
	var t := setup(60, 0, 2)
	check("reverse.control_locked", not XXuanChart.set_control(t, t.actor(XUAN), "auto") and XXuanChart.control(t) == "")
	check("reverse.control_bad_mode", not XXuanChart.set_control(s, s.actor(XUAN), "x") and XXuanChart.control(s) == "auto")
	# 名册只留最后 stage 人
	var r := setup(60, 0, 2)
	for id in [1, 8, 9]:
		XXuanChart.toggle_roster(r, id)
	check("roster.cap", XXuanChart.chart(r).roster == [8, 9], XXuanChart.chart(r).roster)
	# 公共事件 9015：技能页可用（MENU_UNBUILT 里已没有）
	check("skill.not_unbuilt", not XSkillScene.MENU_UNBUILT.has(10349))


func _ready() -> void:
	_go.call_deferred()


func _go() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("oracle", ref is Dictionary and ref.cases.size() == 25)
	var obs := {}
	for c in ref.cases:
		check(str(c.id) + ".clean", c.errors.is_empty(), c.errors)
		obs[str(c.id)] = c.observed
		if str(c.id).begins_with("ops."):
			_ops(c)
		elif str(c.id) == "gate.levels":
			_gate(c)
		elif str(c.id).begins_with("flow."):
			_flow(c)
	_sand(obs)
	_local()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_xuan_chart", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
