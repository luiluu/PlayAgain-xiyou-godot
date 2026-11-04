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


class ShieldLogic:
	extends FixedDamageLogic
	func _float(reason: String) -> float:
		return 0.0 if reason == "hit" else 1.0  # 必中、不闪、不暴击（参照 Math.random 0.5、无暴击）


## 按序给随机数，用完后 0.5（同参照），记用掉几个。
class SeqStream:
	extends XRandomStream
	var seq := []
	var floats := 0
	func next_float(_reason: String, _event_key := "") -> float:
		floats += 1
		return float(seq[floats - 1]) if floats <= seq.size() else 0.5


## deselect 的 revive 抽取固定成给定值、单独记数；别的抽取（命中等）照 0.5。
class FixedRule:
	extends XRandomStream
	var value := 0.5
	var floats := 0
	func next_float(_reason: String, event_key := "") -> float:
		if event_key == "revive":
			floats += 1
			return value
		return 0.5


class ReviveLogic:
	extends ShieldLogic
	var stream: XRandomStream
	func _rule() -> XRandomStream:
		return stream if stream != null else super()


class ValueBattler:
	extends XBattler
	var values := {}
	func _level() -> int:
		return int(values.get("level", 1))
	func param(i: int) -> float:
		return float(values.get(["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"][i], 1.0))
	func passive_cache() -> Dictionary:
		return {"damageElement": values.get("damageElement", 0)}
	func attack_elements() -> Array:
		return values.get("attackElements", [])
	func trait_objects() -> Array:
		return [{"note": "<ELEMENT NULL>"}] if values.get("nullElement", false) else super()


class QueryEnemy:
	extends XEnemy
	func param(_i: int) -> float:
		return 100.0


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
	check("query.oracle_present", cases.has("query.native_blocks"))
	if not cases.has("query.native_blocks"):
		return finish()
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
	_query_blocks(cases["query.native_blocks"].observed)
	check("shield.oracle_present", cases.has("query.shield_blocks"))
	if cases.has("query.shield_blocks"):
		_shield_blocks(cases["query.shield_blocks"].observed)
	check("revive.oracle_present", cases.has("revive.blocks"))
	if cases.has("revive.blocks"):
		_revive_blocks(cases["revive.blocks"].observed)
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


func _query_blocks(o: Dictionary) -> void:
	XStateEffects.observer = Callable()
	check("query.native_rows", o.rows.size() == 3060, o.rows.size())
	check("query.native_party_scope", o.party[0].members == [1.0, 8.0] and o.party[4].members == [1.0, 8.0, 9.0], o.party)
	var a := ValueBattler.new()
	var b := ValueBattler.new()
	var enemy := QueryEnemy.new()
	var executed := 0
	for index in range(o.rows.size()):
		var row: Dictionary = o.rows[index]
		var sid := int(row.state)
		if sid in [2544, 2545]:
			continue # Native evidence retained; attack replacement is outside this small phase.
		var item := {"id": 1, "damage": {"type": row.type, "elementId": 0}}
		var ctx := {"attacker": a, "defender": b, "item": item, "value": row.before}
		var phase := "confirm"
		if sid in [1047, 1048]:
			phase = "react"
			var p: Array = o.elements[int(row.profile)]
			a.values = {"attackElements": p[2], "damageElement": p[3], "nullElement": p[4]}
			item.damage.elementId = p[0]
			item.yep = {"multipleElements": p[1]}
			ctx.added_elements = p[6]
			if p[5] != null:
				ctx.forced_elements = p[5]
			check("query.elements.%d" % index, XStateEffects._query_elements(ctx, a) == row.elements.map(func(e): return int(e)))
		elif sid == 1834:
			var p: Dictionary = o.party[int(row.profile)]
			ctx.party_members = []
			for id in p.members:
				var member := ValueBattler.new()
				member.hp = 0.0 if p.hpZero else 100.0
				if p.dead.has(id):
					member.state_ids.append(1)
				ctx.party_members.append(member)
			if row.enemyUser:
				ctx.attacker = enemy
				ctx.defender = a
		else:
			var p: Dictionary = o.defenders[int(row.profile)]
			ctx.defender = enemy if p.enemy else b
			ctx.defender.hp = float(p.hp)
			b.values = {"mhp": p.mhp}
		var st := XDB.rec("States", sid)
		var holder: XBattler = ctx.attacker if phase == "confirm" else ctx.defender
		var got := XStateEffects.run_one(phase, holder, st, ctx)
		check("query.execute.%d" % index, got == float(row.after), {"row": row, "got": got})
		ctx.execute = false
		got = XStateEffects.run_one(phase, holder, st, ctx)
		check("query.preview.%d" % index, got == float(row.after), {"row": row, "got": got})
		executed += 1
	check("query.supported_rows", executed == 2772, executed)
	# Production action context uses actual battle actors, independent of attacker.
	var logic := XBattleLogic.new()
	logic.state = XState.new()
	var live := ValueBattler.new()
	live.hp = 0.0 # Native aliveMembers still includes it without death state.
	logic.actors = [live]
	var c := logic._state_context(enemy, {"damage": {"type": 1}}, b)
	c.value = 7.0
	check("query.party.action_context", XStateEffects.run_one("confirm", enemy, XDB.rec("States", 1834), c) == 10.0)
	# Preview fallback reads resolved battle slots; reserves do not increase count,
	# and no slot initialization, actor creation, RNG or parameter cache writes occur.
	var saved := XState.current
	var state := XState.new()
	state.party.assign([1, 8, 9])
	state.battle_slots = [1, 8, 0, 0, 0]
	var dead := ValueBattler.new()
	dead.state_ids.append(1)
	state.actors = {1: live, 8: dead, 9: ValueBattler.new()}
	XState.current = state
	var random := XRandomStream.scripted([])
	var resources := XResourceContext.new()
	var before := [state.battle_slots.duplicate(), state.actors.keys(), live.param_cells.duplicate(), live.effect_lists.duplicate(true),
		live.param_dirty, live.effect_dirty, random.snapshot(), XStateEffects.diagnostics.duplicate(true)]
	c = {"attacker": enemy, "defender": b, "item": {"damage": {"type": 1}}, "value": 7.0,
		"execute": false, "random": random, "resources": resources}
	check("query.party.preview_fallback", XStateEffects.run_one("confirm", enemy, XDB.rec("States", 1834), c) == 10.0)
	var after := [state.battle_slots, state.actors.keys(), live.param_cells, live.effect_lists,
		live.param_dirty, live.effect_dirty, random.snapshot(), XStateEffects.diagnostics]
	check("query.preview.no_mutation", before == after and resources.slots.is_empty() and resources.journal.is_empty())
	XState.current = saved


## 护盾一族（rules2）：105、112、612、614、641、647、1039 的 React（不含本盾元素清零；HP 伤害>0 就播动画、移除自身）与 Remove 空操作。
func _shield_blocks(o: Dictionary) -> void:
	XStateEffects.observer = Callable()
	check("shield.rows", o.rows.size() == 441 and o.pairs.size() == 15 and o.applies.size() == 7, [o.rows.size(), o.pairs.size(), o.applies.size()])
	var a := ValueBattler.new()
	a.values = {"attackElements": [], "damageElement": 0}
	var shields := {}
	for index in range(o.rows.size()):
		var row: Dictionary = o.rows[index]
		var sid := int(row.state)
		var st := XDB.rec("States", sid)
		var react: Array = st.effects.filter(func(e): return e.phase == "react")
		var remove: Array = st.effects.filter(func(e): return e.phase == "remove")
		if not shields.has(sid):
			shields[sid] = true
			check("shield.translated.%d" % sid, react.size() == 1 and react[0].op == "value_query" and react[0].get("remove_self", false)
				and int(react[0].element) == int(row.element) and remove.size() == 1 and remove[0].op == "noop"
				and not st.effects.any(func(e): return e.op == "js"), st.effects)
		var item := {"id": 1, "damage": {"type": row.type, "elementId": row.elementId}}
		for execute in [true, false]:
			var b := ValueBattler.new()
			b.state_ids.append(sid)
			var resources := XResourceContext.new()
			var record := {}
			var ctx := {"attacker": a, "defender": b, "item": item, "value": row.before, "execute": execute, "resources": resources, "record": record}
			if index == 0 and execute:
				check("shield.elements", XStateEffects._query_elements(ctx, a) == row.elements.map(func(e): return int(e)))
			var got := XStateEffects.run_one("react", b, st, ctx)
			var kept := b.state_ids.has(sid)
			var anims: Array = record.get("state_anims", []).map(func(p): return int(p[0]))
			var removed: Array = resources.result(b).removedStates if resources.slots.has(b) else []
			if execute:
				check("shield.execute.%d" % index, got == float(row.after) and kept == row.states.has(float(sid))
					and anims == row.anims.map(func(x): return int(x)) and removed == row.removedStates.map(func(x): return int(x)),
					{"row": row, "got": [got, kept, anims, removed]})
			else:
				check("shield.preview.%d" % index, got == float(row.after) and kept and anims.is_empty(), {"row": row, "got": [got, kept, anims]})
	# 两盾同挂：按状态顺序逐个 React；前一个清零后 value 为 0，后一个不触发
	for index in range(o.pairs.size()):
		var p: Dictionary = o.pairs[index]
		var b := ValueBattler.new()
		b.values = {"mhp": 100.0}
		b.hp = 100.0
		for sid in p.pair:
			b.add_state(int(sid))
		b.param_refresh()
		var resources := XResourceContext.new()
		var record := {}
		var item := {"id": 1, "damage": {"type": 1, "elementId": p.elementId}}
		var got := XStateEffects.run("react", b, {"attacker": a, "defender": b, "item": item, "value": p.before, "resources": resources, "record": record})
		var left: Array = p.pair.filter(func(sid): return b.state_ids.has(int(sid)))
		var anims: Array = record.get("state_anims", []).map(func(q): return int(q[0]))
		check("shield.pair.%d" % index, got == float(p.after) and left == p.states and anims == p.anims.map(func(x): return int(x))
			and resources.result(b).removedStates == p.removedStates.map(func(x): return int(x)),
			{"want": p, "got": [got, left, anims, resources.result(b).removedStates]})
	# 实战：真实 apply 两下，第一下被挡（0 伤害、破盾动画、移除）、第二下照常
	for row in o.applies:
		var sid := int(row.state)
		XEnemy.force_roll = 100.0
		var s := XState.new_game(3, 1, [8])
		s.random_master = XRandomStream.hex64(4400 + sid)
		var logic := ShieldLogic.new()
		logic.elite_roll = 100.0
		logic.setup(2, s)
		var u: XBattler = logic.actors[0]
		var e: XBattler = logic.enemies[0]
		e.add_state(sid)
		# 参照的前置态：热列表已建（typestates）、addState 之后 krz 又标了 dirty（hits[0].dirty）
		e.param_refresh()
		e.param_mark_dirty()
		check("shield.apply.%d.dirty_before" % sid, bool(row.hits[0].dirty) and e.effect_dirty)
		check("shield.apply.%d.added" % sid, e.state_ids.has(sid), e.state_ids)
		var skill := XDB.rec("Skills", 1)
		var first := logic.apply(u, skill, e)
		var hp := e.hp
		var second := logic.apply(u, skill, e)
		var want_anim := int(row.hits[0].anims[0])
		check("shield.apply.%d.blocked" % sid, float(first.hp) == 0.0 and first.removed.has(sid) and not e.state_ids.has(sid)
			and first.get("state_anims", []).size() == 1 and int(first.state_anims[0][0]) == want_anim and first.state_anims[0][1] == e,
			[first.hp, first.removed, first.get("state_anims")])
		check("shield.apply.%d.after" % sid, float(second.hp) == 7.0 and e.hp == hp - 7.0 and not second.has("state_anims")
			and second.removed.is_empty(), [second.hp, second.get("state_anims"), second.removed])


## 自动复活一族（rules3）：切片可达 11 块＋同模板 6 块的 Deselect。单块：按序给随机数，比用掉几个、三种资源、状态、动画、变量、弹字、结果槽；
## 实战：真实 apply 打死持有者，dirty 与否决定非 <Permanent> 的状态（死亡清掉）还跑不跑。
func _revive_blocks(o: Dictionary) -> void:
	XStateEffects.observer = Callable()
	check("revive.rows", o.rows.size() == 552 and o.applies.size() == 136, [o.rows.size(), o.applies.size()])
	var seen := {}
	var variables: Array = XDB.system().get("variables", [])
	for index in range(o.rows.size()):
		var row: Dictionary = o.rows[index]
		var sid := int(row.state)
		var st := XDB.rec("States", sid)
		if not seen.has(sid):
			seen[sid] = true
			check("revive.translated.%d" % sid, st.effects.any(func(e): return e.op == "revive") and not st.effects.any(func(e): return e.op == "js" and e.phase == "deselect"), st.effects)
		var s := XState.new_game_blank()
		XState.current = s
		for id in [965, 966, 967, 1597, 1683]:
			if id < variables.size():
				s.set_variable(id, float(row.varv))
		var b := ValueBattler.new()
		b.values = {"mhp": float(row.mhp), "mmp": float(row.mmp)}
		b.state_ids.append(sid)
		b.hp = float(row.mhp) if row.hpMode == "alive" else 0.0
		b.mp = minf(10.0, float(row.mmp))
		b.tp = 20.0
		if row.hpMode == "dead":
			b.state_ids.append(1)
		b.resource_death_blocked = row.hpMode == "zero"  # 血为 0 未倒下（原版 isDead 只看死亡状态）
		var stream := SeqStream.new()
		stream.seq = row.seq
		var resources := XResourceContext.new()
		var record := {}
		var ctx := {"attacker": b, "defender": b, "target": b, "item": {"id": 1, "damage": {"type": 1, "elementId": 0}}, "value": 0.0, "execute": true,
			"resources": resources, "record": record, "random": stream}
		XStateEffects.run_one("deselect", b, st, ctx)
		var states: Array = b.state_ids.duplicate()
		states.sort()
		var result := resources.result(b)
		var pops: Array = resources.started_popups.get(b, []).map(_pop_row)
		var want_pops := _want_pops(row.popups, sid)
		var got := {"hp": b.hp, "mp": b.mp, "tp": b.tp, "dead": b.is_dead(), "states": states, "draws": stream.floats,
			"anims": record.get("state_anims", []).map(func(p): return int(p[0])), "hpDamage": result.hpDamage, "mpDamage": result.mpDamage, "tpDamage": result.tpDamage,
			"added": result.addedStates, "removed": result.removedStates, "pops": pops,
			"vars": [965, 966, 967, 1597, 1683].map(func(id): return s.variable(id))}
		var want := {"hp": float(row.hp), "mp": float(row.mp), "tp": float(row.tp), "dead": row.dead, "states": row.states.map(func(x): return int(x)), "draws": int(row.draws),
			"anims": row.anims.map(func(x): return int(x)), "hpDamage": float(row.result.hpDamage), "mpDamage": float(row.result.mpDamage), "tpDamage": float(row.result.tpDamage),
			"added": row.result.added.map(func(x): return int(x)), "removed": row.result.removed.map(func(x): return int(x)), "pops": want_pops,
			"vars": row.vars.map(func(x): return float(x))}
		check("revive.row.%d" % index, got == want, {"row": [sid, row.hpMode, row.seq, row.varv], "want": want, "got": got})
	for index in range(o.applies.size()):
		_revive_apply(index, o.applies[index])
	XState.current = null


func _revive_apply(index: int, row: Dictionary) -> void:
	var sid := int(row.state)
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	s.random_master = XRandomStream.hex64(4500 + index)
	XState.current = s
	var variables: Array = XDB.system().get("variables", [])
	for id in [965, 966, 967, 1597, 1683]:
		if id < variables.size():
			s.set_variable(id, 2.0)
	var logic := ReviveLogic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	logic.stream = FixedRule.new()
	logic.stream.value = float(row.r)
	var u: XBattler = logic.actors[0] if row.who == "enemy" else logic.enemies[0]
	var t: XBattler = logic.enemies[0] if row.who == "enemy" else logic.actors[0]
	t.state_ids.clear()
	t.add_state(sid)
	t.param_refresh()
	if bool(row.dirtyBefore):
		t.param_mark_dirty()
	t.hp = 1.0
	t.mp = minf(10.0, t.mmp)
	t.tp = 20.0
	var mhp := t.mhp
	var r := logic.apply(u, XDB.rec("Skills", 1), t)
	var states: Array = t.state_ids.duplicate()
	states.sort()
	var want_states: Array = row.states.map(func(x): return int(x))
	var label := "revive.apply.%d" % index
	var info := [sid, row.who, row.r, row.dirtyBefore]
	check(label + ".states", states == want_states, [info, want_states, states])
	check(label + ".dead", t.is_dead() == bool(row.dead) and bool(r.died) == bool(row.dead), [info, row.dead, t.is_dead(), r.died])
	check(label + ".draws", logic.stream.floats == int(row.draws), [info, row.draws, logic.stream.floats])
	check(label + ".anims", r.get("state_anims", []).map(func(p): return int(p[0])) == row.anims.map(func(x): return int(x)), [info, row.anims, r.get("state_anims", [])])
	var hp_ok: bool = t.hp == float(row.hp) if float(row.hp) <= 1.0 else absf(t.hp / mhp - float(row.hp) / float(row.mhp)) <= 2.0 / mhp  # 血量上限不同（参照 1e8），比例对、取整差一点
	check(label + ".hp", hp_ok, [info, row.hp, row.mhp, t.hp, mhp])
	check(label + ".tp", t.tp == float(row.tp), [info, row.tp, t.tp])
	check(label + ".vars", [965, 966, 967, 1597, 1683].map(func(id): return s.variable(id)) == row.vars.map(func(x): return float(x)), [info, row.vars])
	check(label + ".result", r.result.addedStates == row.result.added.map(func(x): return int(x)) and r.result.removedStates == row.result.removed.map(func(x): return int(x))
		and r.result.hpAffected == bool(row.result.hpAffected), [info, row.result, r.result])
	# 复活块的弹字：回血（以及回蓝、TP）按结果槽拆行（命中那两次弹字原版在 apply 里、这边另走 popupQueue，不比）
	var pops: Array = r.started_popups.map(_pop_row)
	var revived: Array = row.popups.filter(func(p): return float(p.hpDamage) < 0.0 or float(p.mpDamage) != 0.0 or float(p.tpDamage) != 0.0)
	check(label + ".popups", pops.size() == _want_pops(revived, sid).size(), [info, revived, pops])


func _pop_row(p: Dictionary) -> Array:
	return [p.hpAffected, p.hpDamage if p.hpAffected else 0.0, p.mpDamage, p.tpDamage]


## 参照记的是 startDamagePopup 那一刻的结果；运行时按种类拆行（血、蓝、TP、状态），状态行不弹数字。
func _want_pops(rows: Array, _sid: int) -> Array:
	var out := []
	for p in rows:
		if bool(p.hpAffected):
			out.append([true, float(p.hpDamage), 0.0, 0.0])
		if float(p.mpDamage) != 0.0:
			out.append([false, 0.0, float(p.mpDamage), 0.0])
		if float(p.tpDamage) != 0.0:
			out.append([false, 0.0, 0.0, float(p.tpDamage)])
		if not p.added.is_empty() or not p.removed.is_empty():
			out.append([false, 0.0, 0.0, 0.0])
	return out


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
