extends Node
## State effects phase 2a: native lifecycle, KRZ hot lists, and existing-op migration.
## Compare the complete action chain, including confirm/react/respond/establish,
## misses/reflections/counters/guard/forced actions, natural expiry and origins.
## Phase 2b also compares all native constant-bonus rows. OTB action_end remains absent.
var results := []
var trace := []
const PHASES := {"battle": "battle", "turnStartState": "turn_start", "turnEndState": "turn_end", "regenerateState": "regenerate",
	"actionStartState": "action_start", "initiateState": "initiate", "selectState": "select", "deselectState": "deselect",
	"concludeState": "conclude", "confirmState": "confirm", "reactState": "react", "respondState": "respond", "establishState": "establish", "victory": "victory", "escape": "escape", "defeat": "defeat", "actionEndState": "action_end"}
var T := 0
var T2 := 0
var EXPIRE := 0
var MRF := 0
var CNT := 0
var EVA := 0
## 参照测试状态编号 → Godot 测试状态编号（按参照 fixture 的名字对应）
var ids := {}


class FixedDamageLogic:
	extends XBattleLogic
	func _calculate_damage(_u: XBattler, _skill: Dictionary, _t: XBattler, critical: bool) -> Dictionary:
		return {"value": 7.0, "critical": critical}
	func _float(reason: String) -> float:
		return 0.0 if reason == "critical" else super._float(reason)


class ValueBattler:
	extends XBattler
	var values := {}
	func _level() -> int:
		return int(values.get("level", 1))
	func param(i: int) -> float:
		return float(values.get(["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"][i], 1.0))


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))


func _ready() -> void:
	_run.call_deferred()


func _state(name: String, phases: Array, extra := {}) -> int:
	var t: Array = XDB.table("States")
	var id := t.size()
	var rec := {"id": id, "name": name, "traits": [], "note": "", "meta": {}, "iconIndex": 0, "restriction": 0, "priority": 50,
		"autoRemovalTiming": 0, "minTurns": 1, "maxTurns": 1, "removeAtBattleEnd": false,
		"effects": phases.map(func(p): return {"phase": p, "op": "js", "code": "// 记录"})}
	rec.merge(extra, true)
	t.append(rec)
	return id


func _key(b: XBattler, logic: XBattleLogic) -> String:
	return "a%d" % (b as XActor).actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _observe(logic: XBattleLogic) -> void:
	trace.clear()
	XStateEffects.observer = func(phase: String, sid: int, holder: XBattler, ctx: Dictionary) -> void:
		if phase in ["apply", "remove", "leave"]:
			return
		var row := [phase, sid, _key(holder, logic)]
		if ctx.has("attacker"):
			row.append_array([_key(ctx.attacker, logic), _key(ctx.defender, logic)])
		trace.append(row)


## 参照序列：fx 行换成 Godot phase 名；Action 版带 [a, b]。热缓存行（持有者已 remove 该状态后又触发）单列
func _want(o: Dictionary) -> Dictionary:
	var rows := []
	var stale := []
	var removed := {}
	for r in o.log:
		if r[0] != "fx":
			continue
		var phase := str(r[1])
		var sid := int(ids.get(int(r[2]), int(r[2])))
		var holder := str(r[3])
		if phase == "removeState":
			removed["%d|%s" % [sid, holder]] = true
		elif phase == "addState":
			removed.erase("%d|%s" % [sid, holder])
		if not PHASES.has(phase):
			continue
		var g: String = PHASES[phase]
		var row := [g, sid]
		if g in XStateEffects.ACTION_PHASES:
			# Action 版持有者：initiate／conclude 是行动者 a，select／deselect 是目标 b
			row.append(str(r[3]) if g in ["initiate", "conclude", "confirm", "establish"] else str(r[4]))
			row.append_array([str(r[3]), str(r[4])])
		else:
			row.append(holder)
		if removed.has("%d|%s" % [sid, row[2]]):
			stale.append(row)
		rows.append(row)
	return {"rows": rows, "stale": stale}


func _new_logic(ref_seed: int) -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	s.random_master = XRandomStream.hex64(ref_seed)
	for a in s.members():
		a.refresh_passive()
		a.recover_all()
	var logic := XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	return logic


func _compare(name: String, o: Dictionary, extra_check := Callable()) -> void:
	var w := _want(o)
	check(name + ".sequence", trace == w.rows, {"godot": trace, "mv": w.rows})
	# 到期后旧热列表里的效果仍触发，逐条对照原版。
	for row in w.stale:
		check(name + ".stale_preserved.%s" % JSON.stringify(row), trace.has(row), row)
	if not w.stale.is_empty():
		print("热缓存已对照 ", name, " ", JSON.stringify(w.stale))
	if extra_check.is_valid():
		extra_check.call()


func _run() -> void:
	var ref = XDB.load_json("oracle/state_effects.json")
	if not (ref is Dictionary and ref.has("cases")):
		check("oracle_present", false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	var cases := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		cases[c.id] = c
	var all_phases: Array = PHASES.values() + ["apply", "remove", "leave"]
	T = _state("测试·阶段记录", all_phases)
	T2 = _state("测试·阶段记录二", all_phases)
	EXPIRE = _state("测试·一回合到期", all_phases, {"autoRemovalTiming": 2})
	MRF = _state("测试·魔法反射", [], {"traits": [{"code": 22, "dataId": 5, "value": 1.0}]})
	CNT = _state("测试·反击", [], {"traits": [{"code": 22, "dataId": 6, "value": 1.0}]})
	EVA = _state("测试·魔法回避", [], {"traits": [{"code": 22, "dataId": 4, "value": 1.0}]})
	for st in cases["fixture"].observed.states:
		var mine := {"测试·阶段记录": T, "测试·阶段记录二": T2, "测试·一回合到期": EXPIRE, "测试·魔法反射": MRF, "测试·反击": CNT, "测试·魔法回避": EVA}
		if mine.has(str(st.name)):
			ids[int(st.id)] = mine[str(st.name)]
	var o: Dictionary
	var logic: XBattleLogic
	# ---- 开战：我方 a1、a8 带 T；Godot 敌人在 setup 内才建，只比我方部分 ----
	o = cases["battle.start"].observed
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	s.random_master = XRandomStream.hex64(4301)
	for a in s.members():
		a.learn_skill(6168)  # 天道诅咒：开战标签加 995
		a.refresh_passive()
		a.add_state(T)
	logic = XBattleLogic.new()
	trace.clear()
	XStateEffects.observer = func(phase, sid, holder, ctx): trace.append([phase, sid, "a%d" % holder.actor_id if holder is XActor else "e"])
	logic.setup(2, s)
	var party_want: Array = _want(o).rows.filter(func(r): return str(r[2]).begins_with("a"))
	check("battle.start.party", trace.filter(func(r): return str(r[2]).begins_with("a")) == party_want, {"godot": trace, "mv": party_want})
	check("battle.start.ds_after", logic.actors[0].state_ids.has(995) and not trace.any(func(r): return int(r[1]) == 995), trace)
	# ---- 行动链 ----
	for id in ["action.attack", "action.miss", "action.reflect", "action.guard", "action.forced", "action.counter"]:
		o = cases[id].observed
		logic = _new_logic(4302)
		var a: XBattler = logic.actors[0]
		var e: XBattler = logic.enemies[0]
		a.add_state(T)
		e.add_state(T)
		var skill := XDB.rec("Skills", 1)
		match id:
			"action.miss":
				e.add_state(EVA)
			"action.reflect":
				e.add_state(MRF)
			"action.counter":
				e.add_state(CNT)
				skill = skill.duplicate(true)
				skill.hitType = 1
			"action.guard":
				skill = XDB.rec("Skills", 2)
		a.param_refresh()
		e.param_refresh()  # same pre-action refresh as the native fixture
		_observe(logic)
		if id == "action.forced":
			logic.execute(a, skill, e, true)
		else:
			logic.act(a, skill, e)
		_compare(id, o)
		check(id + ".no_action_end", not trace.any(func(r): return r[0] == "action_end")
			and not o.log.any(func(r): return r[0] == "fx" and r[1] == "actionEndState"), trace)
	# ---- 回合开始／结束（含一回合到期的 EXPIRE）----
	o = cases["turn.start_end"].observed
	logic = _new_logic(4303)
	logic.actors[0].add_state(T)
	logic.enemies[0].add_state(T)
	logic.enemies[0].add_state(EXPIRE)
	logic.actors[0].param_refresh()
	logic.enemies[0].param_refresh()
	_observe(logic)
	logic.start_turn()
	logic.end_turn()
	_compare("turn.start_end", o, func(): check("turn.expired", not logic.enemies[0].state_ids.has(EXPIRE), logic.enemies[0].state_ids))
	# ---- 胜／逃／败：只我方，原 endBattle 之前 ----
	for pair in [["end.victory", 0], ["end.escape", 1], ["end.defeat", 2]]:
		o = cases[pair[0]].observed
		logic = _new_logic(4304)
		for a in logic.actors:
			a.add_state(T)
		logic.enemies[0].add_state(T)
		_observe(logic)
		logic.end_battle(int(pair[1]))
		_compare(pair[0], o)
	# ---- 未翻译诊断：上面分发到的 js 块都已登记 ----
	check("diagnostics.recorded", XStateEffects.diagnostics.any(func(d): return int(d.state) == T and d.kind == "untranslated"), XStateEffects.diagnostics.slice(0, 5))
	check("never_fired_listed", XStateEffects.NEVER_FIRED.has("action_end") and XStateEffects.NEVER_FIRED.has("crit"))
	# ---- 上下文：两套 user／target、origin 回退、嵌套分发后外层上下文恢复 ----
	logic = _new_logic(4305)
	var ua: XBattler = logic.actors[0]
	var te: XBattler = logic.enemies[0]
	ua.add_state(T)
	te.add_state(T)
	ua.param_refresh()
	te.param_refresh()
	te.state_origins[T] = weakref(ua)
	var seen := []
	XStateEffects.observer = func(phase, sid, holder, ctx):
		seen.append(ctx)
		if phase == "select":
			XStateEffects.run("turn_start", ua)  # 嵌套一层
			check("ctx.restored_after_nested", XStateEffects.current() == ctx, XStateEffects.current().get("phase"))
	XStateEffects.run("select", te, {"attacker": ua, "defender": te, "item": XDB.rec("Skills", 1)})
	XStateEffects.run("turn_end", ua)
	check("ctx.observed", seen.size() >= 2)
	if seen.size() < 2:
		return finish()
	var sel: Dictionary = seen[0]
	check("ctx.action", sel.user == ua and sel.target == te and sel.holder == te and sel.origin == ua, sel.keys())
	var ts: Dictionary = seen[1]
	check("ctx.battler", ts.phase == "turn_start" and ts.user == ua and ts.target == ua and ts.origin == ua and not ts.has("attacker"), ts.keys())
	check("ctx.stack_empty", XStateEffects.current().is_empty())
	_lifecycle(cases)
	_bonus_blocks(cases["bonus.native_blocks"].observed.rows)
	_damage_chain(cases["damage.full_chain"].observed)
	_value_blocks(cases["value.native_blocks"].observed)
	XStateEffects.observer = Callable()
	finish()


func _lifecycle(cases: Dictionary) -> void:
	for kind in ["actor", "enemy"]:
		var logic := _new_logic(4310)
		var h: XBattler = logic.actors[0] if kind == "actor" else logic.enemies[0]
		var origin: XBattler = logic.enemies[0] if kind == "actor" else logic.actors[0]
		var rows := []
		var stage := [""]
		XImportedBalance.set_acting(origin)
		XStateEffects.observer = func(phase, sid, holder, ctx):
			if phase not in ["apply", "remove", "leave"]:
				return
			rows.append([phase, sid, _key(holder, logic), _key(ctx.origin, logic), holder.is_state_affected(sid)])
			if sid == T and stage[0] == "nested add" and phase == "apply":
				h.add_state(T2)  # FIX rejects nested add
			if sid == T and stage[0] == "nested leave" and phase == "remove":
				h.remove_state(T2)  # inherits the outer natural-expiry scope
		h.add_state(T)
		h.add_state(T)
		h.remove_state(T)
		h.remove_state(T)
		h.add_state(EXPIRE)
		h.remove_state_auto(EXPIRE)
		stage[0] = "nested add"
		h.add_state(T)
		check("lifecycle." + kind + ".nested_suppressed", not h.is_state_affected(T2))
		h.remove_state(T)
		stage[0] = "nested leave"
		h.add_state(T)
		h.add_state(T2)
		h.remove_state_auto(T)
		var want := []
		var phases := {"addState": "apply", "removeState": "remove", "leaveState": "leave"}
		for row in cases["lifecycle." + kind].observed.log:
			if row[0] == "life":
				want.append([phases[row[1]], ids[int(row[2])], row[3], row[4], row[5]])
		check("lifecycle." + kind + ".sequence_origin", rows == want, {"godot": rows, "mv": want})
		check("lifecycle." + kind + ".origin_cleared", not h.state_origins.has(T) and not h.state_origins.has(T2) and not h.state_origins.has(EXPIRE))
	XImportedBalance.set_acting(null)
	# KRZ: warm -> add without dirty-refresh -> refresh -> remove without
	# dirty-refresh -> refresh. Compare every native turnStart slot, including T
	# after it has been removed.
	var logic := _new_logic(4311)
	var h: XBattler = logic.actors[0]
	h.add_state(T)
	h.param_refresh()
	h.effect_states("turn_start")
	_observe(logic)
	h.add_state(T2)
	XStateEffects.run("turn_start", h)
	h.param_refresh()
	XStateEffects.run("turn_start", h)
	h.remove_state(T)
	XStateEffects.run("turn_start", h)
	h.param_refresh()
	XStateEffects.run("turn_start", h)
	_compare("krz.hot_cache", cases["krz.hot_cache"].observed)
	var before := JSON.stringify([h.effect_snapshot, h.effect_lists, h.state_ids])
	var observations := [0]
	XStateEffects.observer = func(_p, _s, _h, _c): observations[0] += 1
	XDamage.apply_state_effects(17.0, XDB.rec("Skills", 1), h, logic.enemies[0])
	check("preview.no_cache_or_observer_write", observations[0] == 0 and before == JSON.stringify([h.effect_snapshot, h.effect_lists, h.state_ids]))

	# Native Math.round(-0.5) is zero, not Godot roundf's -1.
	var sid := _state("测试·乘数负半整数", [], {"effects": [{"phase": "confirm", "op": "mul", "cond": "nonzero", "k": 0.5, "round": "round"}]})
	h.add_state(sid)
	h.param_refresh()
	XStateEffects.observer = Callable()
	for pair in cases["mul.round_boundaries"].observed["values"]:
		var value := XStateEffects.run("confirm", h, {"attacker": h, "defender": logic.enemies[0], "item": XDB.rec("Skills", 1), "value": pair[0]})
		check("mul.round." + str(pair[0]), value == pair[1], value)


func _bonus_blocks(rows: Array) -> void:
	var logic := _new_logic(4312)
	var a: XBattler = logic.actors[0]
	var b: XBattler = logic.enemies[0]
	XStateEffects.observer = Callable()
	check("bonus.native_rows", rows.size() == 1568, rows.size())
	for row in rows:
		var skill := XDB.rec("Skills", 1).duplicate(true)
		skill.damage.type = row.type
		var st := XDB.rec("States", int(row.state))
		var ctx := {"attacker": a, "defender": b, "item": skill, "critical": row.critical, "value": row.before}
		var got := XStateEffects.run_one("confirm", a, st, ctx)
		check("bonus.%d.%d.%s.%s" % [row.state, row.type, row.critical, row.before], got == row.after, [got, row.after])
	# Unwarmed caches and live capabilities must remain untouched by a preview.
	a.add_state(1522)
	a.param_refresh()
	a.effect_lists.clear()
	b.effect_lists.clear()
	var resources := XResourceContext.new()
	var stream := logic._rule()
	var before := [a.hp, b.hp, a.effect_lists.duplicate(true), b.effect_lists.duplicate(true),
		a.effect_snapshot.duplicate(true), b.effect_snapshot.duplicate(true), a.param_cells.duplicate(), b.param_cells.duplicate(),
		a.effect_dirty, b.effect_dirty, a.param_dirty, b.param_dirty, stream.snapshot(), XStateEffects.diagnostics.duplicate(true)]
	var vars := [1, 2]
	var switches := {2: true}
	var skill := XDB.rec("Skills", 1)
	var got := XDamage.finish({"value": 7.0, "critical": true}, skill, a, b, false,
		{"resources": resources, "random": stream, "variables": vars, "switches": switches})
	check("preview.bonus_value", got == 17.0, got)
	var after := [a.hp, b.hp, a.effect_lists, b.effect_lists, a.effect_snapshot, b.effect_snapshot, a.param_cells, b.param_cells,
		a.effect_dirty, b.effect_dirty, a.param_dirty, b.param_dirty, stream.snapshot(), XStateEffects.diagnostics]
	check("preview.no_live_mutation", before == after and resources.slots.is_empty() and resources.journal.is_empty()
		and vars == [1, 2] and switches == {2: true})


func _damage_chain(o: Dictionary) -> void:
	var logic := FixedDamageLogic.new()
	var state := XState.new_game(3, 1, [8])
	state.random_master = XRandomStream.hex64(4313)
	logic.elite_roll = 100.0
	logic.setup(2, state)
	state.variables[27] = 314
	state.switches[28] = true
	var a: XBattler = logic.actors[0]
	var b: XBattler = logic.enemies[0]
	var effects := []
	for pair in [["confirm", 2.0], ["react", 0.5], ["respond", 3.0], ["establish", 0.5]]:
		effects.append({"phase": pair[0], "op": "mul", "cond": "nonzero", "k": pair[1], "round": "round"})
	var sid := _state("测试·完整伤害链", [], {"effects": effects})
	a.add_state(sid)
	b.add_state(sid)
	a.param_refresh()
	b.param_refresh()
	var log := []
	XStateEffects.observer = func(phase, id, _holder, ctx):
		if id == sid:
			log.append([phase, ctx.value, ctx.critical, float(ctx.variables[27]), ctx.switches[28]])
			check("damage.ctx." + phase, ctx.resources != null and ctx.random == logic._rule()
				and ctx.record.target == b and ctx.resources.result(b).critical == ctx.critical)
	var skill := XDB.rec("Skills", 1).duplicate(true)
	skill.damage.critical = true
	var hp := b.hp
	var r := logic.apply(a, skill, b)
	check("damage.full_chain.values", log == o.log, [log, o.log])
	check("damage.full_chain.settlement", b.hp - hp == o.hpDelta and r.result.hpDamage == o.hpDamage
		and r.critical == o.critical, r)
	# The existing resource opcode also needs the same live capability before settlement.
	var resource_sid := _state("测试·确认阶段资源", [], {"effects": [{"phase": "confirm", "op": "user_param_damage", "params": ["atk"]}]})
	a.add_state(resource_sid)
	a.param_refresh()
	XStateEffects.observer = Callable()
	r = logic.apply(a, skill, b)
	check("damage.confirm_resource", r.get("extra", []).size() == 1 and r.effectJournal.any(func(e):
		return e.resource == "hp" and e.requestedDelta == -a.atk), r.get("effectJournal", []))


func _value_blocks(o: Dictionary) -> void:
	XStateEffects.observer = Callable()
	var a := ValueBattler.new()
	var b := ValueBattler.new()
	var variables := {}
	var profile := -1
	check("value.native_rows", o.rows.size() == 11235, o.rows.size())
	for index in range(o.rows.size()):
		var row: Array = o.rows[index]
		if int(row[2]) != profile:
			profile = int(row[2])
			var p: Array = o.profiles[profile]
			a.values = {"level": p[0], "mhp": p[1]}
			b.values = {"mhp": p[3], "def": p[4]}
			b.hp = float(p[2])
			b.state_ids.assign(range(4, 4 + int(p[5])))
			for i in range(o.variables.size()):
				variables[str(int(o.variables[i]))] = p[6][i]
		var skill := {"damage": {"type": row[3]}, "hitType": row[4]}
		var stream := XRandomStream.scripted([{"kind": "float", "value": row[7], "reason": "state_effect", "event": "%s:%d" % [row[1], row[0]]}])
		var ctx := {"attacker": a, "defender": b, "item": skill, "critical": row[5], "value": row[6],
			"variables": variables, "random": stream}
		var st := XDB.rec("States", int(row[0]))
		var got := XStateEffects.run_one(str(row[1]), a if row[1] == "confirm" else b, st, ctx)
		check("value.%d.%d" % [row[0], index], absf(got - float(row[8])) < 0.0000000001
			and stream.draws == int(row[9]) and stream.error.is_empty(), {"row": row, "got": got, "draws": stream.draws})
	# Preview a random block with unwarmed parameter/state caches and live resources.
	var stream := XRandomStream.scripted([{"kind": "float", "value": 0.9}])
	var resources := XResourceContext.new()
	var before := [a.hp, b.hp, a.effect_lists.duplicate(true), b.effect_lists.duplicate(true),
		a.effect_snapshot.duplicate(true), b.effect_snapshot.duplicate(true), a.param_cells.duplicate(), b.param_cells.duplicate(),
		a.effect_dirty, b.effect_dirty, a.param_dirty, b.param_dirty, stream.snapshot(), XStateEffects.diagnostics.duplicate(true)]
	var vars_before := variables.duplicate(true)
	var ctx := {"attacker": a, "defender": b, "item": {"damage": {"type": 1}, "hitType": 1}, "critical": false,
		"value": -3.0, "variables": variables, "random": stream, "resources": resources, "execute": false}
	var got := XStateEffects.run_one("react", b, XDB.rec("States", 1540), ctx)
	check("value.preview.signed_unconditional", got == -1.0, got)
	ctx.value = 7.0
	got = XStateEffects.run_one("confirm", a, XDB.rec("States", 1441), ctx)
	check("value.preview.random", got == 7.0, got)
	var after := [a.hp, b.hp, a.effect_lists, b.effect_lists, a.effect_snapshot, b.effect_snapshot, a.param_cells, b.param_cells,
		a.effect_dirty, b.effect_dirty, a.param_dirty, b.param_dirty, stream.snapshot(), XStateEffects.diagnostics]
	check("value.preview.isolated", before == after and variables == vars_before and resources.slots.is_empty() and resources.journal.is_empty())


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
