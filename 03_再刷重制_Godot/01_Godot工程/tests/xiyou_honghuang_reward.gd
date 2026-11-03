extends Node
## 洪荒二期（XHonghuang＋battle_logic 开战／结束钩子＋MVScript）对原版参照 tests/fixtures/honghuang_reward_oracle.json
## （mv_oracle/honghuang_reward_probe.cjs）：判定口径（只看开关）、诅咒加成券、不朽存在权能掉落（rand 用给定序列）、指引 powerLine、真公共事件 1445。
## 再跑一遍真公共事件 1439 的头三句，确认发券、熟练度、权能判定都接上了（解释器不跳过这三句）。
const FIXTURE := "res://tests/fixtures/honghuang_reward_oracle.json"
const PARTY := [1, 8, 9, 10]
const POWER_ITEMS := [1654, 1655, 1656, 1657, 1658, 1659, 1667, 1674, 1683, 1718]
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 30:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameApp.fast_headless_frames()
	XMessageBox.auto = true
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("source", f.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("complete", f.cases.size() == 44, f.cases.size())
	for c in f.cases:
		check(c.id + ".oracle", c.errors.is_empty(), c.errors)
		var kind := str(c.id).get_slice(".", 0)
		match kind:
			"gate", "ticket":
				_ticket(c)
			"power":
				_power(c)
			"guide":
				_guide(c)
			"ce1445":
				await _ce1445(c)
	await _ce1439()
	check("fixed1", ["2.3", "2.8", "4.0", "1.4", "7.6", "1.0"] == [2.25, 2.75, 4.05, 1.44, 7.59375, 1.0].map(func(v): return XHonghuang._fixed1(v)))
	var passed := checks - failures.size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": checks}))
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)


func _fresh(spec: Dictionary) -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	s.difficulty = int(spec.get("difficulty", 2))
	for id in PARTY:
		s.add_actor(id)
	for sw in spec.get("switches", {}):
		s.set_switch(int(sw), bool(spec.switches[sw]))
	return s


## 用例的诅咒写法有两种：{角色: [技能]}，或（权能）直接 [技能] 给队首
func _learn(s: XState, curses) -> void:
	if curses is Array:
		curses = {"1": curses}
	for id in curses:
		for sk in curses[id]:
			s.actor(int(id)).learn_skill(int(sk))


func _hh_toasts(list: Array) -> Array:
	return list.filter(func(t): return str(t).begins_with("洪荒"))


func _ticket(c: Dictionary) -> void:
	var spec: Dictionary = c.setup
	var o: Dictionary = c.observed
	var s := _fresh(spec if str(c.id).begins_with("gate") else {"switches": {"2483": true}})
	if str(c.id).begins_with("gate"):
		s.actor(1).learn_skill(7201)
		if spec.has("difficulty"):
			s.difficulty = int(spec.difficulty)
		check(c.id + ".is", XHonghuang.is_honghuang(s) == bool(o.isHonghuang))
	else:
		_learn(s, spec.curses)
		check(c.id + ".bonus", absf(XHonghuang.party_bonus(s) - float(o.bonus)) < 1e-5, [o.bonus, XHonghuang.party_bonus(s)])
	var before := s.item_count(XHonghuang.TICKET)
	var t := XHonghuang.grant_ticket_bonus(s)
	check(c.id + ".ticket", s.item_count(XHonghuang.TICKET) - before == int(o.ticket), [o.ticket, s.item_count(XHonghuang.TICKET) - before])
	check(c.id + ".toasts", t == o.toasts, [o.toasts, t])


func _power(c: Dictionary) -> void:
	var spec: Dictionary = c.setup
	var o: Dictionary = c.observed
	var s := _fresh(spec)
	XHonghuang.power_battle = {}
	var used := [0]
	var rolls: Array = spec.get("rolls", [0, 0])
	var rand := func():
		used[0] += 1
		return float(rolls[used[0] - 1]) if used[0] <= rolls.size() else 0.99
	if str(c.id) == "power.no_battle":
		s.set_switch(2483, true)
		check(c.id + ".got", XHonghuang.roll_power(s, rand).got.is_empty())
		return
	_learn(s, spec.curses)
	for t in spec.get("mastery", {}):
		s.boss_mastery[str(t)] = int(spec.mastery[t])
	if spec.has("v107"):
		s.set_variable(107, int(spec.v107))
	s.map_id = int(spec.map)
	if spec.origin != null:
		s.flags[XYunshangOrders.ORIGIN_FLAG] = int(spec.origin)
		s.unknown_origin = int(spec.origin)
	var logic := XBattleLogic.new()
	logic.setup(int(spec.troop), s)
	logic.end_battle(int(spec.result))
	var r := XHonghuang.roll_power(s, rand)
	var again = XHonghuang.roll_power(s, rand).got if bool(spec.get("twice", false)) else null
	check(c.id + ".got", r.got == o.got.map(func(v): return int(v)), [o.got, r.got])
	if o.again != null:
		check(c.id + ".again", again == o.again.map(func(v): return int(v)), [o.again, again])
	check(c.id + ".used", used[0] == int(o.used), [o.used, used[0]])
	check(c.id + ".toasts", r.toasts == _hh_toasts(o.toasts), [o.toasts, r.toasts])
	var have := []
	for id in POWER_ITEMS:
		if s.item_count(id) > 0:
			have.append([id, s.item_count(id)])
	check(c.id + ".powers", JSON.stringify(have) == JSON.stringify(o.powers), [o.powers, have])
	check(c.id + ".floor", XDungeon.boss_floor(s.map_id) == int(o.floor), [o.floor, XDungeon.boss_floor(s.map_id)])
	check(c.id + ".segment", XHonghuang.segment(int(o.floor)) == int(o.segment))
	check(c.id + ".chance", absf(XHonghuang.power_chance(s) - float(o.chance)) < 1e-5, [o.chance, XHonghuang.power_chance(s)])
	check(c.id + ".factor", XDungeon.power_factor(s, int(spec.troop)) == float(o.factor))


## 只比 powerLine 那一句：区段简介等别的段落有已登记的不移植项（XGuide.milestone_intro）
func _guide(c: Dictionary) -> void:
	var s := _fresh(c.setup)
	_learn(s, c.setup.curses)
	var re := RegEx.create_from_string("\\\\C\\[4\\]洪荒权能.*$")
	for seg in XGuide.atlas():
		var want := ""
		for t in c.observed.texts[str(seg.key)]:
			var m := re.search(str(t))
			if m:
				want = m.get_string()
		check("%s.%s" % [c.id, seg.key], XGuide._power_line(seg) == want, [want, XGuide._power_line(seg)])


class Host:
	extends "res://tests/xiyou_event_compare.gd".EventHost
	var toasts: Array = []

	func toast(t) -> void:
		toasts.append(str(t))


func _ce1445(c: Dictionary) -> void:
	var s := _fresh({"switches": {"2463": bool(c.setup.on)}})
	s.map_id = 4
	var host := Host.new()
	add_child(host)
	var interp := MVInterpreter.new(host, 4, 0, XDB.rec("CommonEvents", 1445).list.duplicate(true))
	await interp.run()
	check(c.id + ".skipped", interp.skipped.is_empty(), interp.skipped)
	for id in c.observed.actors:
		if XDB.rec("Actors", int(id)).is_empty():
			continue
		var got := [10300, 5972, 5973].filter(func(k): return s.actor(int(id)).skill_ids.has(k))
		check("%s.actor%s" % [c.id, id], got == c.observed.actors[id].map(func(v): return int(v)), [c.observed.actors[id], got])
	var named := 0
	var learned := 0
	for rec in XDB.table("Actors"):
		if rec != null and str(rec.get("name", "")) != "":
			named += 1
			if s.actor(int(rec.id)).skill_ids.has(10300):
				learned += 1
	check(c.id + ".all", learned == (named if bool(c.setup.on) else 0), [learned, named])
	host.queue_free()


## 真公共事件 1439：发券在熟练度之前、权能判定在之后，三句都不进 skipped
func _ce1439() -> void:
	var s := _fresh({"switches": {"2483": true}})
	s.actor(1).learn_skill(7201)
	s.map_id = 162
	s.flags[XYunshangOrders.ORIGIN_FLAG] = 57
	var logic := XBattleLogic.new()
	logic.setup(539, s)
	logic.end_battle(0)
	XDungeon.battle_finished(539, 0, s.map_id)
	var before := s.item_count(XHonghuang.TICKET)
	var host := Host.new()
	add_child(host)
	var interp := MVInterpreter.new(host, 162, 0, XDB.rec("CommonEvents", 1439).list.duplicate(true))
	await interp.run()
	var bad: Array = interp.skipped.filter(func(e): return str(e.text).contains("Honghuang"))
	check("ce1439.skipped", bad.is_empty(), bad)
	check("ce1439.toast", host.toasts.has("洪荒诅咒加成（×1.5）：肝帝积分抽奖券额外+3"), host.toasts)
	check("ce1439.mastery", int(s.boss_mastery.get("539", 0)) == 1)
	check("ce1439.ticket", s.item_count(XHonghuang.TICKET) - before >= 3, s.item_count(XHonghuang.TICKET) - before)
	check("ce1439.rolled", bool(XHonghuang.power_battle.rolled))
	host.queue_free()
