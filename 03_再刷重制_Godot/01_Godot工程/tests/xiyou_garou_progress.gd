extends Node
## 【cc·白龙_7·未经审查】173 饿狼第二期（XGarou：param_rate／action_times／reason／advance／evolve_relic／credit_victory／boss_meter，存档 codexGarou）：
## 与 mv_oracle/garou_progress_probe.cjs 的冻结 v0.28 参照（tests/fixtures/garou_progress_oracle.json，正式引擎）逐例比。
## - module：形态表（倍率、行动、等级、累计突破门槛、法宝模板）；
## - rate.*：各形态 60 级能力倍率、行动次数、能力值，忘掉 10269 后回到人类形态；
## - reason.*：进阶条件文字；advance.chain：人类招募后改动法宝实例，逐阶进阶到星空（作废确认、技能、形态状态、触媒、法宝进化）；
##   advance.blocked：缺神之触媒不进阶；equip.evolve：螺旋形态换上人类法宝即进化、法宝只给饿狼；
## - victory.*：胜利得累计突破与神之触媒；boss.meter：有 Boss 血条的敌人编号；sync.*：同步夹累计突破。
## - 另核 XAdvance 分派（missing／advance）、战斗里的行动次数与胜利结算挂点、存档往返（codexGarou）与旧档没有该键。
const FIXTURE := "res://tests/fixtures/garou_progress_oracle.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


## 同参照 setup()：新局、等级上限 99、饿狼形态 stage、level 级，再同步一次
func _setup(stage: int, level: int) -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.actor_advance[XGarou.ACTOR] = stage
	var a := s.actor(XGarou.ACTOR)
	a.change_level_mv(level)
	XGarou.sync(a)
	return s


func _learned(a: XActor) -> Array:
	var out := a.skill_ids.filter(func(i): return i >= 10250 and i <= 10269)
	out.sort()
	return out


func _forms(a: XActor) -> Array:
	return XGarou.STATES.filter(func(i): return a.state_ids.has(i))


func _ints(v: Array) -> Array:
	return v.map(func(x): return int(x))


func _near(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= 1e-9 * maxf(1.0, absf(float(b)))
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _near(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in b:
			if not a.has(k) or not _near(a[k], b[k]):
				return false
		return true
	return a == b


## 参照 noteLines：去掉 <CodexGarouHelp> 说明块后的非空行
static func _note_lines(n) -> Array:
	var t := RegEx.create_from_string("<CodexGarouHelp>[\\s\\S]*?</CodexGarouHelp>\\s*").sub(str(n if n != null else ""), "", true)
	return Array(t.replace("\r\n", "\n").split("\n")).filter(func(l): return l.strip_edges() != "")


func _relic(item) -> Variant:
	if item == null:
		return null
	var lines := _note_lines(item.note)
	var out := {"base": int(item.base), "name": str(item.name), "params": item.params.map(func(v): return float(v)),
		"traits": item.traits.map(func(t): return {"code": int(t.code), "dataId": int(t.dataId), "value": float(t.value)}),
		"noteTemplate": _note_lines(XDB.rec("Armors", int(item.base)).get("note", "")).all(func(l): return lines.has(l)),
		"noteExtra": str(item.note).contains("<GarouProbeExtra>"), "level": float(XEquipmentView.level(item)),
		"exp": float(XMagicWeapon.exp_of(item)), "iconIndex": int(item.iconIndex)}
	if item.has("garouStage"):  # 没进化过的实例原版没有 _garouStage（JSON 里省掉）
		out.stage = int(item.garouStage)
	return out


func _relic_same(got, want) -> bool:
	if got == null or want == null:
		return got == want
	var w: Dictionary = want.duplicate()
	w.erase("note")
	return _near(got, w)


func _module(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var ok := _ints(o.relics) == XGarou.RELICS and int(o.material) == XGarou.CATALYST
	for i in 7:
		var st: Dictionary = o.stages[i]
		var m: Dictionary = st.multiplier
		var rate := [m.mhp, m.mmp, m.atk, m.defense, m.mat, m.mdf, m.agi, m.luk]
		ok = ok and _near(XGarou.STAGES[i].rate, rate) and int(st.actions) == XGarou.STAGES[i].actions and int(st.level) == XGarou.STAGES[i].level \
			and int(st.breakthroughs) == XGarou.STAGES[i].breakthroughs and int(st.relic) == XGarou.RELICS[i]
	check("module", ok, o)


func _rate(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _setup(int(c.setup.stage), int(c.setup.level))
	var a := s.actor(XGarou.ACTOR)
	var logic := XBattleLogic.new()
	var read := func():
		var rate := []
		var param := []
		for i in 8:
			rate.append(a.param_rate(i))
			param.append(a.param(i))
		return {"rate": rate, "actions": logic.make_action_times(a), "param": param}
	var full: Dictionary = read.call()
	a.forget_skill(XGarou.GROWTH)
	var none: Dictionary = read.call()
	check(c.id + ".skills", _learned(a) == _ints(o.skills), [_learned(a), o.skills])
	for pair in [["full", full], ["noGrowth", none]]:
		var w: Dictionary = o[pair[0]]
		var g: Dictionary = pair[1]
		check(c.id + "." + pair[0] + ".rate", _near(g.rate, w.rate), [g.rate, w.rate])
		check(c.id + "." + pair[0] + ".actions", int(g.actions) == int(w.actions), [g.actions, w.actions])
		check(c.id + "." + pair[0] + ".param", _near(g.param, w.param), [g.param, w.param])


func _reason(c: Dictionary) -> void:
	var s := _setup(int(c.setup.stage), int(c.setup.level))
	s.garou["breakthroughs"] = float(c.setup.bt)
	if c.setup.has("cat"):
		s.gain_item(XGarou.CATALYST, int(c.setup.cat))
	var got := XGarou.reason(s, s.actor(XGarou.ACTOR))
	check(c.id, got == str(c.observed.reason), [got, c.observed.reason])
	# XAdvance.missing 分派：有原因就只给原因
	var lack := XAdvance.missing(s, s.actor(XGarou.ACTOR))
	check(c.id + ".missing", lack == ([got] if got != "" else []), lack)


func _chain(c: Dictionary) -> void:
	var steps: Array = c.observed.steps
	var setup: Dictionary = c.setup
	var s := _setup(0, 20)
	check(c.id + ".recruit", XGarou.recruit(s))
	var a := s.actor(XGarou.ACTOR)
	var item: Dictionary = XGarou.gear(a)
	item.level = float(setup.relicLevel)
	item.exp = float(setup.relicExp)
	for i in 8:
		item.params[i] = float(item.params[i]) + float(setup.paramDelta[i])
	for t in setup.extraTraits:
		item.traits.append({"code": int(t.code), "dataId": int(t.dataId), "value": float(t.value)})
	item.note = str(item.note) + "\n" + str(setup.extraNote)
	check(c.id + ".start", XGarou.stage(a) == int(steps[0].stage) and _relic_same(_relic(item), steps[0].relic), [_relic(item), steps[0].relic])
	for st in 6:
		var w: Dictionary = steps[st + 1]
		var next: Dictionary = XGarou.STAGES[st + 1]
		a.change_level_mv(int(next.level))
		s.garou["breakthroughs"] = float(next.breakthroughs)
		if st == 5:
			s.gain_item(XGarou.CATALYST, 2)
		var stale := XGarou.advance(s, a, st + 1)
		var result := XGarou.advance(s, a, st)
		var id := "%s.s%d" % [c.id, st + 1]
		check(id + ".stale", _near(stale, w.stale), [stale, w.stale])
		check(id + ".result", _near(result, w.result), [result, w.result])
		check(id + ".stage", XGarou.stage(a) == int(w.stage) and _forms(a) == _ints(w.forms), [XGarou.stage(a), _forms(a), w.forms])
		check(id + ".skills", _learned(a) == _ints(w.skills), [_learned(a), w.skills])
		check(id + ".catalysts", s.item_count(XGarou.CATALYST) == int(w.catalysts) and XGarou.breakthroughs(a) == int(w.bt), [s.item_count(XGarou.CATALYST), XGarou.breakthroughs(a), w])
		var g = XGarou.gear(a)
		check(id + ".same", is_same(g, item) == bool(w.same))
		check(id + ".relic", _relic_same(_relic(g), w.relic), [_relic(g), w.relic])
	var again := XGarou.advance(s, a, 6)
	check(c.id + ".again", _near(again, steps[7].again), [again, steps[7].again])


func _blocked(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _setup(int(c.setup.stage), int(c.setup.level))
	var a := s.actor(XGarou.ACTOR)
	s.garou["breakthroughs"] = float(c.setup.bt)
	var result := XGarou.advance(s, a, int(c.setup.stage))
	check(c.id, _near(result, o.result) and XGarou.stage(a) == int(o.stage) and _learned(a) == _ints(o.skills) and s.item_count(XGarou.CATALYST) == int(o.catalysts),
		[result, XGarou.stage(a), _learned(a), o])
	check(c.id + ".xadvance", not XAdvance.advance(s, a) and XGarou.stage(a) == int(o.stage))


func _equip(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _setup(int(c.setup.stage), int(c.setup.level))
	var a := s.actor(XGarou.ACTOR)
	s.gain_gear("armor", 7904, 1)
	var item: Dictionary = s.gear.back()
	check(c.id + ".before", _relic_same(_relic(item), o.before), [_relic(item), o.before])
	var other := s.actor(1)
	check(c.id + ".can_equip", other.can_equip(item) == bool(o.canOther) and a.can_equip(item) == bool(o.canGarou), [other.can_equip(item), a.can_equip(item)])
	check(c.id + ".changed", XEquipment.change(s, a, a.equip_slots().find(13), item))
	check(c.id + ".after", _relic_same(_relic(XGarou.gear(a)), o.after), [_relic(XGarou.gear(a)), o.after])


func _victory(c: Dictionary) -> void:
	var o: Dictionary = c.observed.first
	var setup: Dictionary = c.setup
	var s := _setup(int(setup.stage), int(setup.level))
	var a := s.actor(XGarou.ACTOR)
	s.garou["breakthroughs"] = float(setup.bt)
	if setup.get("granted", false):
		s.garou["catalyst"] = true
	var text := XGarou.credit_victory(s, a, bool(setup.boss))
	var texts := [text] if text != "" else []
	var got := [XGarou.breakthroughs(a), s.item_count(XGarou.CATALYST), bool(s.garou.get("catalyst", false)), texts]
	check(c.id, got == [int(o.bt), int(o.catalysts), bool(o.granted), o.texts], [got, o])


func _boss(c: Dictionary) -> void:
	var want := {}
	for id in c.observed.ids:
		want[int(id)] = true
	var wrong := []
	for id in range(1, int(c.observed.total) + 1):
		if XGarou.boss_meter(id) != want.has(id):
			wrong.append(id)
	check(c.id, wrong.is_empty(), wrong.slice(0, 20))


func _sync(c: Dictionary) -> void:
	var s := _setup(int(c.setup.stage), int(c.setup.level))
	var a := s.actor(XGarou.ACTOR)
	s.garou["breakthroughs"] = float(c.setup.bt)
	XGarou.sync(a)
	var got := [int(s.garou.breakthroughs), XGarou.breakthrough_cap(a)]
	check(c.id, got == [int(c.observed.bt), int(c.observed.cap)], [got, c.observed])


## 战斗挂点：开战记下出战的饿狼与 Boss 战，胜利结算（grant）只记一次突破；行动次数不掷追加行动
func _battle_hooks() -> void:
	var s := _setup(5, 50)
	s.set_switch(2494, true)
	XGarou.recruit(s)
	var a := s.actor(XGarou.ACTOR)
	s.garou["breakthroughs"] = 330.0
	var boss_troop := 0
	for t in XDB.table("Troops"):
		if t is Dictionary and not t.is_empty() and (t.get("members", []) as Array).any(func(m): return XGarou.boss_meter(int(m.enemyId))):
			boss_troop = int(t.id)
			break
	check("battle.boss_troop", boss_troop > 0)
	var logic := XBattleLogic.new()
	logic.setup(boss_troop, s)
	check("battle.start", logic.actors.has(a) and is_same(logic._garou, a) and logic._garou_boss, [logic.actors.map(func(b): return b.actor_id), logic._garou_boss])
	check("battle.actions", logic.make_action_times(a) == 2)
	logic.grant(logic.rewards())
	logic.grant(logic.rewards())
	var expect := 333 if logic.actors.has(a) else 330
	check("battle.grant", XGarou.breakthroughs(a) == expect and (logic.victory_texts == [XGarou.CATALYST_TEXT]) == logic.actors.has(a), [XGarou.breakthroughs(a), logic.victory_texts])


## XAdvance.advance 分派：星空只扣 1 个神之触媒（表里另有 2939×1，不重扣）
func _xadvance() -> void:
	var s := _setup(5, 60)
	var a := s.actor(XGarou.ACTOR)
	s.garou["breakthroughs"] = 333.0
	s.gain_item(XGarou.CATALYST, 3)
	check("xadvance.missing", XAdvance.missing(s, a).is_empty(), XAdvance.missing(s, a))
	check("xadvance.advance", XAdvance.advance(s, a) and XGarou.stage(a) == 6 and s.item_count(XGarou.CATALYST) == 2, [XGarou.stage(a), s.item_count(XGarou.CATALYST)])


func _save_roundtrip() -> void:
	var s := _setup(2, 30)
	s.garou = {"breakthroughs": 77.0, "catalyst": true}
	var d := s.to_dict()
	check("save.key", d.get("codexGarou") == {"breakthroughs": 77.0, "catalyst": true}, d.get("codexGarou"))
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(d)))
	check("save.roundtrip", int(back.garou.get("breakthroughs", -1)) == 77 and back.garou.get("catalyst") == true, back.garou)
	d.erase("codexGarou")
	var old := XState.from_dict(JSON.parse_string(JSON.stringify(d)))
	XState.current = old
	check("save.old", int(old.garou.get("breakthroughs", 0)) == 0 and not old.garou.get("catalyst", false) and XGarou.breakthroughs(old.actor(XGarou.ACTOR)) == 0, old.garou)
	# 读档同步（extractSaveContents 包装）：清战斗内进化／琦玉，并把缺的形态状态补回来
	var s2 := _setup(2, 30)
	var d2 := s2.to_dict()
	XGarou.evolution = 2
	XGarou.saitama = true
	var loaded := XState.from_dict(JSON.parse_string(JSON.stringify(d2)))
	check("save.load_clear", XGarou.evolution == 0 and not XGarou.saitama, [XGarou.evolution, XGarou.saitama])
	check("save.load_sync", _forms(loaded.actor(XGarou.ACTOR)) == [XGarou.STATES[2]], _forms(loaded.actor(XGarou.ACTOR)))


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match kind:
			"module":
				_module(c)
			"rate":
				_rate(c)
			"reason":
				_reason(c)
			"advance":
				_chain(c) if c.id == "advance.chain" else _blocked(c)
			"equip":
				_equip(c)
			"victory":
				_victory(c)
			"boss":
				_boss(c)
			"sync":
				_sync(c)
	check("covers_all", seen.keys().size() == 8, seen.keys())
	_battle_hooks()
	_xadvance()
	_save_roundtrip()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_garou_progress", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
