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


class WeaponActor:
	extends XActor
	var weapon_type := 0
	func first_weapon_type() -> int:
		return weapon_type


class ReviveLogic:
	extends ShieldLogic
	var stream: XRandomStream
	func _rule() -> XRandomStream:
		return stream if stream != null else super()


## 记下开战时交给公共事件单槽的预约（rules9 P3-5）
class ReserveLogic:
	extends ReviveLogic
	var seen := []
	func _take_state_reserves() -> void:
		for id in XStateEffects._reserves:
			seen.append(int(id))
		super._take_state_reserves()


## 记下强制行动执行时的防连锁深度（rules9 P3-6）
class DepthLogic:
	extends ReviveLogic
	var depths := []
	func execute(u, skill, target = null, forced := false):
		depths.append(XStateEffects.chain_depth)
		return []


## 每执行一条强制行动就再排一条，直到排满 chain 条（模拟多代追加）
class ChainLogic:
	extends ReviveLogic
	var chain := 3
	var ran := 0
	func _force_action(p: Array, first_subject: XBattler) -> Array:
		ran += 1
		if ran < chain:
			XStateEffects.queue_force_quiet(actors[0], 1, 0)
		return super._force_action(p, first_subject)


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
	_fixes_off()
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
	check("effect.oracle_present", cases.has("effect.blocks"))
	if cases.has("effect.blocks"):
		_effect_blocks(cases["effect.blocks"].observed, 1440, 60, "effect")
	check("effect2.oracle_present", cases.has("effect2.blocks"))
	if cases.has("effect2.blocks"):
		_effect_blocks(cases["effect2.blocks"].observed, 4032, 56, "effect2")
	check("hook.oracle_present", cases.has("hook.blocks"))
	if cases.has("hook.blocks"):
		_hook_blocks(cases["hook.blocks"].observed)
	check("rest.oracle_present", cases.has("rest.blocks"))
	if cases.has("rest.blocks"):
		_rest_blocks(cases["rest.blocks"].observed)
	check("poison.oracle_present", cases.has("poison.blocks"))
	if cases.has("poison.blocks"):
		_poison_blocks(cases["poison.blocks"].observed)
	check("rest2.oracle_present", cases.has("rest2.blocks"))
	if cases.has("rest2.blocks"):
		_rest2_blocks(cases["rest2.blocks"].observed)
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
	# BEC apply 在 deselect 之内：这一击的数字先弹，复活块的弹字在后；没清结果的块（1164、1837）也不多弹一次回血
	var hp_rows: Array = r.popupQueue.filter(func(p): return p.hpAffected)
	var want_hp_rows: Array = row.popups.filter(func(p): return bool(p.hpAffected))
	check(label + ".hp_popup_count", hp_rows.size() == want_hp_rows.size(), [info, want_hp_rows, hp_rows])
	if want_hp_rows.size() == 2:
		check(label + ".hit_first", float(hp_rows[0].hpDamage) > 0.0 and float(hp_rows[1].hpDamage) < 0.0 and float(r.shown.hp) > 0.0, [info, hp_rows, r.shown])


## 伤害 react／confirm 一族（rules4）：单块逐行比（value、两边资源、护盾、字段、状态、随机次数、弹字、变量）；实战比结局。
func _effect_blocks(o: Dictionary, want_rows: int, want_applies: int, tag: String) -> void:
	XStateEffects.observer = Callable()
	check(tag + ".rows", o.rows.size() == want_rows and o.applies.size() == want_applies, [o.rows.size(), o.applies.size()])
	var seen := {}
	for index in range(o.rows.size()):
		var row: Dictionary = o.rows[index]
		var sid := int(row.state)
		var st := XDB.rec("States", sid)
		var key := "%d.%s" % [sid, row.phase]
		if not seen.has(key):
			seen[key] = true
			check(tag + ".translated." + key, st.effects.any(func(e): return e.phase == row.phase and e.op in ["effect_program", "noop"])
				and not st.effects.any(func(e): return e.phase == row.phase and e.op == "js"), st.effects)
		var s := XState.new_game_blank()
		XState.current = s
		s.set_variable(1174, float(row.v1174))
		var extra: Dictionary = row.get("x", {})
		if extra.has("v206"):
			s.set_variable(206, float(extra.v206))
		var f: Dictionary = row.before
		var a := ValueBattler.new()
		a.values = {"mhp": float(f.amhp), "mmp": float(f.ammp), "atk": float(f.aatk), "mat": float(f.amat)}
		var e := ValueBattler.new()
		e.values = {"mhp": float(f.emhp), "mmp": float(f.emmp), "atk": float(f.eatk), "mat": float(f.emat)}
		a.hp = float(f.ahp); a.mp = float(f.amp); a.tp = 20.0; a.state_data["_Shield"] = float(f.ashield)
		e.hp = float(f.ehp); e.mp = float(f.emp); e.tp = 20.0; e.state_data["_Shield"] = float(f.eshield)
		if row.xmxIn != null:
			e.state_data["_xmx"] = float(row.xmxIn)
		var holder: XBattler = e if row.phase in ["react", "respond"] else a
		holder.state_ids.append(sid)
		if e.hp <= 0.0:
			e.state_ids.append(1)
		var stream := SeqStream.new()
		stream.seq = row.seq
		var resources := XResourceContext.new()
		var ctx := {"attacker": a, "defender": e, "target": e, "item": {"id": 1, "hitType": row.hitType, "damage": {"type": row.dmgType, "elementId": 0}},
			"value": float(row.value), "execute": true, "resources": resources, "record": {}, "random": stream, "critical": bool(extra.get("crit", false))}
		var got := XStateEffects.run_one(str(row.phase), holder, st, ctx)
		var pops := []
		for b in [a, e]:
			pops += resources.started_popups.get(b, []).map(_pop_row)
		var want_pops := []
		for who in ["a", "e"]:
			want_pops += _want_pops(row.popups.filter(func(p): return p.who == who), sid)
		var left := {"value": got, "ahp": a.hp, "amp": a.mp, "atp": a.tp, "ehp": e.hp, "emp": e.mp, "etp": e.tp, "ashield": a.state_data._Shield, "eshield": e.state_data._Shield,
			"xmx": e.state_data.get("_xmx"), "astates": _sorted(a.state_ids), "estates": _sorted(e.state_ids), "draws": stream.floats, "pops": pops, "v": s.variable(1174)}
		var right := {"value": float(row.got), "ahp": float(row.a.hp), "amp": float(row.a.mp), "atp": float(row.a.tp), "ehp": float(row.e.hp), "emp": float(row.e.mp), "etp": float(row.e.tp),
			"ashield": float(row.a.shield), "eshield": float(row.e.shield), "xmx": row.e.xmx, "astates": _sorted(row.a.states), "estates": _sorted(row.e.states),
			"draws": int(row.draws), "pops": want_pops, "v": float(row.vars[0])}
		for name in ["ahp", "amp", "ehp", "emp"]:  # 参照测量已按 6 位小数取整（host.cjs round）；小数血量（1407 按当前血 0.15%）这边按同样位数比
			left[name] = "%.6f" % float(left[name])
			right[name] = "%.6f" % float(right[name])
		for side in [left, right]:  # 弹字里的小数同样按 6 位比
			side["pops"] = side.pops.map(func(p): return p.map(func(x): return "%.6f" % x if x is float else x))
		check("%s.row.%d" % [tag, index], left == right, {"row": [sid, row.phase, row.dmgType, row.hitType, row.value, row.hpIn, row.seq], "want": right, "got": left})
	var starter := ValueBattler.new()
	starter.values = {"mhp": 100.0, "mmp": float(o.actionStart[0].mmp)}
	starter.state_ids.append(1450)
	XState.current = XState.new_game_blank()
	XState.current.set_variable(1174, 9.0)
	XStateEffects.run_one("action_start", starter, XDB.rec("States", 1450), {"execute": true, "resources": XResourceContext.new()})
	check(tag + ".action_start_1450", XState.current.variable(1174) == float(o.actionStart[0].v), [o.actionStart, XState.current.variable(1174)])
	for index in range(o.applies.size()):
		_effect_apply(index, o.applies[index], tag)
	XState.current = null


func _sorted(ids: Array) -> Array:
	var out: Array = ids.map(func(x): return int(x))
	out.sort()
	return out


## 实战：Godot 这边生命、攻击都和参照不同，只比结局：状态、目标死没死、计数字段、变量、谁掉血。
func _effect_apply(index: int, row: Dictionary, tag := "effect") -> void:
	var sid := int(row.state)
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	s.random_master = XRandomStream.hex64(4600 + index)
	XState.current = s
	s.set_variable(1174, 2.0)
	var logic := ReviveLogic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	var a: XBattler = logic.actors[0]
	var e: XBattler = logic.enemies[0]
	var holder: XBattler = e if row.phase in ["react", "respond"] else a
	e.state_data["_Shield"] = float(row.shield)
	var ctx := {"resources": XResourceContext.new(), "execute": true}
	holder.add_state_with_context(sid, null, ctx)
	if sid == 1060:
		check("%s.apply.%d.shield_added" % [tag, index], e.state_data._Shield == float(row.shield) + e.mhp * 10.0 and float(row.before.eshield) > float(row.shield), [e.state_data._Shield, e.mhp])
	holder.param_refresh()
	if bool(row.low):
		e.hp = 1.0
	var a_hp := a.hp
	var e_hp := e.hp
	var shield := float(e.state_data._Shield)
	var r := logic.apply(a, XDB.rec("Skills", 1), e)
	var label := "%s.apply.%d" % [tag, index]
	var info := [sid, row.phase, row.shield, row.low]
	check(label + ".e_states", _sorted(e.state_ids) == _sorted(row.e.states), [info, row.e.states, e.state_ids])
	check(label + ".e_dead", e.is_dead() == bool(row.e.dead), [info, row.e.dead, e.is_dead()])
	check(label + ".xmx", e.state_data.get("_xmx") == row.e.xmx, [info, row.e.xmx, e.state_data.get("_xmx")])
	check(label + ".var", s.variable(1174) == float(row.vars[0]), [info, row.vars, s.variable(1174)])
	check(label + ".e_hp_dir", signf(e.hp - e_hp) == signf(float(row.e.hp) - float(row.before.ehp)), [info, row.before.ehp, row.e.hp, e_hp, e.hp])
	check(label + ".a_hp_dir", signf(a.hp - a_hp) == signf(float(row.a.hp) - float(row.before.ahp)), [info, row.before.ahp, row.a.hp, a_hp, a.hp])
	check(label + ".shield_dir", signf(float(e.state_data._Shield) - shield) == signf(float(row.e.shield) - float(row.before.eshield)), [info, row.e.shield, shield, e.state_data._Shield])
	var user_hit: bool = row.popups.any(func(p): return p.who == "a" and bool(p.hpAffected))
	check(label + ".user_popups", r.user_popups.any(func(p): return p.hpAffected) == user_hit, [info, row.popups, r.user_popups])
	if sid == 1061:
		check(label + ".user_died", bool(r.user_died) and bool(row.a.dead) and int(row.collapses) == 1, [info, r.user_died, row.a.dead, row.collapses])
	check(label + ".result_sign", signf(float(r.result.hpDamage)) == signf(float(row.e.result.hpDamage)), [info, row.e.result.hpDamage, r.result.hpDamage])


## 其它／回合行动钩子两族（rules5）。
func _hook_blocks(o: Dictionary) -> void:
	XStateEffects.observer = Callable()
	for pair in [[1067, "apply"], [1067, "remove"], [1068, "apply"], [1068, "remove"], [1068, "crit"], [1072, "react"], [2548, "confirm"]]:
		var effects: Array = XDB.rec("States", pair[0]).effects.filter(func(e): return e.phase == pair[1])
		check("hook.noop.%d.%s" % pair, effects.size() == 1 and effects[0].op == "noop", effects)
	# 这些 noop 的依据：标记、基础防御都没人读，def 赋值无效，isDamageAffected 直接报错，Custom Damage Formula 不改伤害
	check("hook.no_effect_basis", o.s1067[0].e.marked == true and o.s1068[1].e.def == o.s1068[1].def0 and float(o.s1072.got) == 7.0 and not o.s1072.sourceErrors.is_empty()
		and o.customFormula[0].v == o.customFormula[1].v and o.customFormula[2].v == o.customFormula[3].v, [o.s1067, o.s1072.sourceErrors, o.customFormula])
	XState.current = XState.new_game_blank()
	_hook_83(o.s83)
	_hook_1452(o.s1452)
	_hook_turn_start(o.turnStart)
	_hook_weapon(o.weapon)
	_hook_2574(o.s2574)
	_hook_1301(o.s1301flow)
	_hook_1306(o.s1306)
	XState.current = null
	XStateEffects.battle_units = {}


func _action_ctx(a: XBattler, t: XBattler, value: float, item := {}) -> Dictionary:
	return {"attacker": a, "defender": t, "target": t, "item": item if not item.is_empty() else {"id": 1, "damage": {"type": 1, "elementId": 0}}, "value": value, "execute": true,
		"resources": XResourceContext.new(), "record": {}, "random": SeqStream.new()}


func _plain(hp := 1000.0) -> ValueBattler:
	var b := ValueBattler.new()
	b.values = {"mhp": 100000.0, "mmp": 100.0}
	b.hp = hp
	b.mp = 10.0
	b.tp = 20.0
	return b


func _hook_83(rows: Array) -> void:
	var rate := _state("测试·死亡率0", [], {"traits": [{"code": 13, "dataId": 1, "value": 0.0}]})
	var resist := _state("测试·死亡抵抗", [], {"traits": [{"code": 14, "dataId": 1, "value": 1.0}]})
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var a := _plain()
		var e := _plain(float(row.tHp))
		e.state_ids.append(83)
		if row.extra == "rate":
			a.state_ids.append(rate)
		elif row.extra == "resist":
			a.state_ids.append(resist)
		var ctx := _action_ctx(a, e, 7.0)
		var got := XStateEffects.run_one("respond", e, XDB.rec("States", 83), ctx)
		var anims: Array = ctx.record.get("state_anims", []).map(func(p): return [p[1] == a, int(p[0])])
		var want_anims: Array = row.anims.map(func(p): return [p[0] == "a", int(p[1])])
		check("hook.83.%d" % index, got == float(row.got) and a.hp == float(row.a.hp) and a.is_dead() == bool(row.a.dead) and e.state_ids.has(83) == row.e.states.has(83.0) and anims == want_anims,
			{"row": row, "got": [got, a.hp, a.is_dead(), e.state_ids, anims]})


func _hook_1452(rows: Array) -> void:
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var a := _plain()
		var b := _plain()
		var e := _plain(float(row.tHp))
		e.resource_death_blocked = true
		e.state_ids.append(1452)
		a.state_ids.append(1451)
		b.state_ids.append(1451)
		XStateEffects.battle_units = {"enemies": [a, b]}
		var ctx := _action_ctx(a, e, 7.0)
		var got := XStateEffects.run_one("respond", e, XDB.rec("States", 1452), ctx)
		check("hook.1452.%d" % index, got == float(row.got) and _sorted(a.state_ids) == _sorted(row.a.states) and _sorted(b.state_ids) == _sorted(row.b.states), {"row": row, "got": [a.state_ids, b.state_ids]})


func _hook_turn_start(rows: Array) -> void:
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var sid := int(row.sid)
		var h := _plain()
		h.state_ids.append_array([sid, 1713, 1718])
		var unit := [h]
		for i in range(int(row.alive) - (0 if row.holderDead else 1)):
			unit.append(_plain())
		if row.holderDead:
			h.hp = 0.0
			h.state_ids.append(1)
		XStateEffects.battle_units = {"enemies": unit}
		XStateEffects.run_one("turn_start", h, XDB.rec("States", sid), {"execute": true, "resources": XResourceContext.new()})
		var want: Array = row[row.holder].states
		check("hook.turn_start.%d" % index, _sorted(h.state_ids) == _sorted(want), {"row": [sid, row.holder, row.alone, row.holderDead, row.alive], "want": want, "got": h.state_ids})


func _hook_weapon(rows: Array) -> void:
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var item: Dictionary = XDB.rec("Skills", int(row.skill))
		var u: XBattler
		if row.who == "a":
			var actor := WeaponActor.new()
			actor.setup(1)
			actor.weapon_type = int(row.wt)
			u = actor
		else:
			u = _plain()
		var t := _plain()
		var st := XDB.rec("States", int(row.sid))
		var got := [XStateEffects.run_one("confirm", u, st, _action_ctx(u, t, 7.0, item)), XStateEffects.run_one("confirm", u, st, _action_ctx(u, t, 99.0, item))]
		check("hook.weapon.%d" % index, got == [float(row.got7), float(row.got99)], {"row": row, "got": got})


func _hook_2574(rows: Array) -> void:
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		XState.current = XState.new_game_blank()
		var a108: XActor = XState.current.actor(108)
		var u := _plain()
		u.state_data["_stateCounter"] = {}
		a108.state_data["_stateCounter"] = {}
		if row.has("c") and row.c != null:
			u.state_data._stateCounter["2401"] = float(row.c)
		if row.has("c108") and row.c108 != null:
			a108.state_data._stateCounter["2401"] = float(row.c108)
		XStateEffects.run_one("apply", u, XDB.rec("States", 2574), {"execute": true, "resources": XResourceContext.new()})
		var after108 = a108.state_data._stateCounter.get("2401")
		var ok: bool = u.state_data._stateCounter["2401"] == float(row.after)
		if str(row.after108) == "NaN":
			ok = ok and after108 == null  # 原版 NaN，读的地方当 0；这边不写 NaN
		else:
			ok = ok and after108 == float(row.c108) + float(a108.level) and float(row.after108) == float(row.c108) + float(row.level)
		check("hook.2574.%d" % index, ok, {"row": row, "got": [u.state_data, after108]})
	XState.current = XState.new_game_blank()


func _hook_1301(rows: Array) -> void:
	var row: Dictionary = rows[0]
	var e := _plain(0.0)
	e.resource_death_blocked = true  # 序列 immortal：血为 0 未倒下
	e.state_ids.append(1301)
	var a := _plain()
	XStateEffects.battle_units = {"enemies": [e, a]}
	var ctx := _action_ctx(a, e, 0.0)
	XStateEffects.take_forces()
	XStateEffects.run_one("deselect", e, XDB.rec("States", 1301), ctx)
	var forces := XStateEffects.take_forces()
	var want: Array = row.queue[0].parameters.map(func(x): return int(x))
	check("hook.1301.queue", forces == [want], [want, forces])
	check("hook.1301.removed", not e.state_ids.has(1301) and ctx.resources.result(e).removedStates == row.e.removed.map(func(x): return int(x)) and not ctx.resources.result(e).hpAffected, [e.state_ids, ctx.resources.result(e), row.e])
	# 解除 immortal 后才判定，倒下了 339 不行动（参照 after_event 没有强制行动）
	check("hook.1301.after_event", rows[2].forced == null and bool(rows[1].e.dead), rows[2].forced)
	var alive := _plain()
	alive.state_ids.append(1301)
	XStateEffects.run_one("deselect", alive, XDB.rec("States", 1301), _action_ctx(a, alive, 0.0))
	check("hook.1301.alive_no_queue", XStateEffects.take_forces().is_empty() and alive.state_ids.has(1301))


func _hook_1306(rows: Array) -> void:
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		XEnemy.force_roll = 100.0
		var s := XState.new_game(3, 1, [8])
		s.random_master = XRandomStream.hex64(4700 + index)
		XState.current = s
		var logic := ReviveLogic.new()
		logic.elite_roll = 100.0
		logic.setup(2, s)
		var a: XActor = logic.actors[0]
		var b: XBattler = logic.actors[1]
		var e: XBattler = logic.enemies[0]
		for id in row.learned:
			a.learn_skill(int(id))
		var h: XBattler = a if row.holder == "a" else e
		h.state_ids.append(1306)
		var want_loss := ceilf(float(row.hp) * 0.13)
		check("hook.1306.%d.formula" % index, row.sourceErrors.size() > 0 or float(row.hp) - float(row.a.hp) == want_loss, [row.hp, row.a.hp])
		var hp := minf(float(row.hp), a.mhp)
		a.hp = hp
		if row.alone:
			b.hp = 0.0
			b.state_ids.append(1)
		var ctx := {"execute": true, "resources": XResourceContext.new()}
		XStateEffects.run_one("turn_end", h, XDB.rec("States", 1306), ctx)
		if row.holder == "e":
			check("hook.1306.%d.enemy_throws" % index, a.hp == hp and not row.sourceErrors.is_empty() and row.popups.is_empty(), [a.hp, row.sourceErrors])
			continue
		var pops: Array = ctx.resources.started_popups.get(a, [])
		var wanted: Array = row.a.states.filter(func(x): return int(x) in [1307, 1312]).map(func(x): return int(x))
		var has: Array = a.state_ids.filter(func(x): return int(x) in [1307, 1312])
		has.sort()
		check("hook.1306.%d.a" % index, a.hp == hp - ceilf(hp * 0.13) and has == wanted and pops.size() >= 1 and float(pops[0].hpDamage) == ceilf(hp * 0.13), [a.hp, hp, has, wanted, pops])
		check("hook.1306.%d.b" % index, (b.is_dead() == bool(row.alone)) and (row.alone or b.hp < b.mhp or b.hp == 0.0), [b.hp, row.alone])


## 切片可达剩余几族（rules6）：换装、必爆、公共事件预约、再生、改属性。
func _rest_blocks(o: Dictionary) -> void:
	XStateEffects.observer = Callable()
	_rest_costume(o)
	_rest_crit(o.crit)
	_rest_reserve(o)
	_rest_regen(o.regen)
	_rest_attrs(o)
	XState.current = null
	XStateEffects.battle_units = {}
	XStateEffects.force_critical = false


func _rest_costume(o: Dictionary) -> void:
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	var a: XActor = s.actor(1)
	var base := str(a.data().get("battlerName", ""))
	var steps := {}
	for row in o.costume:
		steps[row.step] = row
	var run := func(sid: int, phase: String): XStateEffects.run_one(phase, a, XDB.rec("States", sid), {"execute": true, "resources": XResourceContext.new()})
	var look := func() -> String: return str(a.data().get("battlerName", ""))
	check("rest.costume.base_note", str(steps.apply66.prev) == str(o.costumeBase) and str(steps.apply226.prev) == str(o.costumeBase) and steps.remove226.prev == null, steps)
	run.call(66, "apply")
	check("rest.costume.apply66", look.call() == str(steps.apply66.battlerName) and str(a.state_data.get("_prevBattlerName")) == base, [look.call(), a.state_data])
	run.call(226, "apply")
	check("rest.costume.apply226", look.call() == str(steps.apply226.battlerName) and str(a.state_data.get("_prevBattlerName")) == base, [look.call(), a.state_data])
	run.call(226, "remove")
	check("rest.costume.remove226", look.call() == base and not a.state_data.has("_prevBattlerName"), [look.call(), a.state_data])
	# 原版这时把图设成 undefined（remove66、remove_only 的 battlerName 都没了），显示不出来；这边保留现状
	check("rest.costume.undefined_note", not steps.remove66.has("battlerName") and not steps.remove_only.has("battlerName"), steps)
	run.call(66, "remove")
	check("rest.costume.remove_without_prev", look.call() == base, look.call())
	# 敌人：apply 什么都不做；remove TypeError，也什么都不做
	check("rest.costume.enemy_note", steps.enemy_apply.enemy == steps.enemy_remove.enemy and not steps.enemy_remove.sourceErrors.is_empty(), steps)
	var enemy := _plain()
	XStateEffects.run_one("apply", enemy, XDB.rec("States", 66), {"execute": true, "resources": XResourceContext.new()})
	XStateEffects.run_one("remove", enemy, XDB.rec("States", 66), {"execute": true, "resources": XResourceContext.new()})
	check("rest.costume.enemy", enemy.state_data.is_empty(), enemy.state_data)
	# 换装卡状态归 XCostumes，这里不动外观
	var card: int = XCostumes.registry().keys()[0]
	check("rest.costume.card_translated", XDB.rec("States", card).effects.any(func(e): return e.op == "costume_image"))
	run.call(card, "apply")
	check("rest.costume.card_skipped", look.call() == base and not a.state_data.has("_prevBattlerName"), [look.call(), a.state_data])
	# 切片可达的 6 个状态，图都在切片素材里
	for sid in [66, 226, 270, 283, 284, 1223]:
		var image := str(XDB.rec("States", sid).effects.filter(func(e): return e.op == "costume_image")[0].image)
		check("rest.costume.asset.%d" % sid, ResourceLoader.exists("res://modes/xiyou/generated/img/sv_actors/%s.png" % image), image)


func _rest_crit(rows: Array) -> void:
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		XEnemy.force_roll = 100.0
		var s := XState.new_game(3, 1, [8])
		s.random_master = XRandomStream.hex64(4800 + index)
		XState.current = s
		var logic := ReviveLogic.new()
		logic.elite_roll = 100.0
		logic.setup(2, s)
		var e: XBattler = logic.enemies[0]
		e.state_ids.append(int(row.sid))
		if int(row.extra) != 0:
			e.state_ids.append(int(row.extra))
		e.param_mark_dirty()
		e.param_refresh()
		var r := logic.apply(logic.actors[0], XDB.rec("Skills", int(row.skill)), e)
		check("rest.crit.%d" % index, bool(r.critical) == bool(row.critical) and XStateEffects.force_critical == bool(row.forceAfter), [row, r.critical, XStateEffects.force_critical])
	# 没有状态就不暴击（ShieldLogic 的暴击随机数是 1）
	var s2 := XState.new_game(3, 1, [8])
	XState.current = s2
	var plain := ReviveLogic.new()
	plain.elite_roll = 100.0
	plain.setup(2, s2)
	check("rest.crit.none", not bool(plain.apply(plain.actors[0], XDB.rec("Skills", 1), plain.enemies[0]).critical))


func _rest_reserve(o: Dictionary) -> void:
	var troop: Array = []
	for i in range(int(o.troopSize)):
		troop.append(_plain())
	for index in range(o.reserve.size()):
		var row: Dictionary = o.reserve[index]
		var sid := int(row.sid)
		var phase := str(row.phase).trim_suffix("State")
		phase = {"turnStart": "turn_start", "deselect": "deselect", "react": "react", "confirm": "confirm", "remove": "remove"}[phase]
		var s := XState.new_game_blank()
		XState.current = s
		s.set_variable(901, 7.0)
		s.set_variable(1163, 1.0 if sid == 1318 and int(row.reserved) == 0 else 0.0)  # 参照 1、2 都不预约
		s.set_variable(1584, 9999.0 if bool(row.e.dead) and sid == 2568 else 9998.0)
		for m in troop:
			m.hp = 0.0 if row.has("deadTroop") else 1000.0
			m.state_ids.clear()
			if row.has("deadTroop"):
				m.state_ids.append(1)
		XStateEffects.battle_units = {"enemies": troop}
		var a := _plain()
		a.values.mmp = float(o.mmpA)
		a.mp = 50.0
		var e := _plain(float(row.e.hp) if sid == 1317 else 1000.0)
		e.resource_death_blocked = sid == 1317 and e.hp == 0.0
		var holder: XBattler = a if not row.a.states.is_empty() or (sid == 1306 and row.popups[0].who == "a") else e
		holder.state_ids.append(sid)
		var ctx := _action_ctx(a, e, float(row.value))
		XStateEffects.take_reserves()
		var got := XStateEffects.run_one(phase, holder, XDB.rec("States", sid), ctx)
		var taken := XStateEffects.take_reserves()
		check("rest.reserve.%d" % index, (taken.back() if not taken.is_empty() else 0) == int(row.reserved) and (row.got == null or got == float(row.got)) and (row.has("deadTroop") or e.is_dead() == bool(row.e.dead)),
			{"row": [sid, row.phase, row.value, row.reserved], "got": [taken, got, e.is_dead()]})
		if sid == 1306:
			check("rest.reserve.1306.%d" % index, s.variable(901) == float(row.v901) and (holder != a or a.mp == float(row.a.mp)), [s.variable(901), a.mp, row.a.mp])


func _rest_regen(rows: Array, tag := "rest") -> void:
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var sid := int(row.sid)
		var f: Dictionary = row.before
		var a := _plain(float(f.ahp))
		a.values.mhp = float(f.amhp)
		a.values.mat = float(f.amat)
		if row.mode == "deadOrigin":
			a.state_ids.append(1)
		var e := _plain(float(f.ehp))
		e.values.mhp = 100000000.0
		e.state_ids.append(sid)
		if row.hp207:
			e.state_ids.append(207)
		if row.mode != "self":
			e.state_origins[sid] = weakref(a)
		var logs := []
		var ctx := {"execute": true, "resources": XResourceContext.new(), "emit": func(entry): logs.append(entry)}
		XStateEffects.run_one("regenerate", e, XDB.rec("States", sid), ctx)
		var anims: Array = logs.filter(func(l): return l.has("animation")).map(func(l): return ["a" if l.target == a else "e", int(l.animation)])
		var want_anims: Array = row.anims.map(func(p): return [p[0], int(p[1])])
		var pops: Array = logs.filter(func(l): return not l.has("animation") and float(l.hp) != 0.0).map(func(l): return ["a" if l.target == a else "e", float(l.hp)])
		# 参照是直调块，没有外层 regenerateStateEffects 的目标弹字；这边多一条目标掉血
		var want_pops: Array = row.popups.map(func(p): return [p.who, float(p.hpDamage)])
		if float(row.e.hp) != float(f.ehp):
			var damage := float(f.amat) * (5.0 if sid == 260 else 100.0)  # 元素率 1
			if sid == 224:
				damage = float(f.amat) * 5.0
			elif sid in [566, 577]:
				damage = float(f.amhp) * (1.0 if sid == 566 else 5.0)
			want_pops.append(["e", -damage * 3.0 if row.hp207 and sid != 1006 and not bool(row.e.dead) else damage])  # 打死后 207 随死亡清掉，不再补那一笔  # 结果槽记最后一次 gainHp，不截血量
		check("%s.regen.%d" % [tag, index], a.hp == float(row.a.hp) and e.hp == float(row.e.hp) and e.is_dead() == bool(row.e.dead) and anims == want_anims and pops == want_pops,
			{"row": [sid, row.mode, row.hp207], "want": [row.a.hp, row.e.hp, want_anims, want_pops], "got": [a.hp, e.hp, anims, pops]})


func _rest_attrs(o: Dictionary) -> void:
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	s.set_variable(980, 3.0)
	s.gold = 1000
	var u := _plain()
	XStateEffects.run_one("victory", u, XDB.rec("States", 1423), {"execute": true, "resources": XResourceContext.new()})
	check("rest.gold", s.gold == 1000 + int(o.gold.after) - int(o.gold.g0), [s.gold, o.gold])
	for index in range(o.tp.size()):
		var row: Dictionary = o.tp[index]
		var b := _plain()
		b.tp = float(row.tp)
		XStateEffects.run_one("apply", b, XDB.rec("States", 1840), {"execute": true, "resources": XResourceContext.new()})
		check("rest.tp.%d" % index, b.tp == float(row.after), [row, b.tp])
	s.set_variable(1204, 2.0)
	var logic := ReviveLogic.new()
	logic.elite_roll = 100.0
	XEnemy.force_roll = 100.0
	logic.setup(2, s)
	for index in range(o.params.size()):
		var row: Dictionary = o.params[index]
		var t: XBattler = logic.actors[0] if row.who == "a" else logic.enemies[0]
		var before := t.param_plus(3)
		XStateEffects.run_one("apply", t, XDB.rec("States", 2003), {"execute": true, "resources": XResourceContext.new()})
		check("rest.param.%s.mid" % row.who, t.param_plus(3) - before == float(row.mid[2]) - float(row.raw3) and t.param_plus(5) - before == float(row.mid[3]) - float(row.raw3), [row, t.param_plus(3)])
		XStateEffects.run_one("remove", t, XDB.rec("States", 2003), {"execute": true, "resources": XResourceContext.new()})
		check("rest.param.%s.end" % row.who, t.param_plus(3) == before and float(row.end[2]) == float(row.raw3) and s.variable(1204) == float(row.v), [row, t.param_plus(3)])
	# 真实战斗的回合、再生阶段不带 resources：块自己建（只传 resources 的单块例测不出这条）
	var bare: XActor = logic.actors[0]
	bare.hp = bare.mhp
	bare.state_ids.append(1306)
	bare.param_mark_dirty()
	bare.param_refresh()
	var bare_hp := bare.hp
	XStateEffects.run("turn_end", bare, {"emit": func(_entry): pass})
	check("rest.bare_turn_end", bare.hp < bare_hp, [bare_hp, bare.hp])
	var victim: XBattler = logic.enemies[0]
	victim.state_ids.append(260)
	victim.state_origins[260] = weakref(bare)
	victim.param_mark_dirty()
	victim.param_refresh()
	var victim_hp := victim.hp
	var bare_logs := []
	XStateEffects.run("regenerate", victim, {"random": logic._rule(), "variables": logic.vars(), "emit": func(entry): bare_logs.append(entry)})
	check("rest.bare_regen", victim.hp < victim_hp and bare_logs.any(func(l): return l.target == victim and float(l.hp) > 0.0), [victim_hp, victim.hp, bare_logs.size()])
	bare.state_ids.erase(1306)
	victim.state_ids.erase(260)
	# 回合开始的弹字经 ctx.emit 交给调用方（小爱莉被动扣蓝）
	var a: XActor = logic.actors[0]
	a.mp = a.mmp
	XStateEffects.run_one("turn_start", a, XDB.rec("States", 1306), {"execute": true, "resources": XResourceContext.new(), "emit": logic._turn_start_emit})
	var logs := logic.take_turn_start_logs()
	check("rest.turn_start_emit", logs.size() == 1 and logs[0].target == a and float(logs[0].mp) > 0.0 and logic.take_turn_start_logs().is_empty(), logs)


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


## 所有参照对比比的是原版，跑之前把 fix1 的修正关掉（这也是回退支的测试）；修正支在 _fix_blocks
func _fixes_off() -> void:
	XStateEffects.FIX_UNDYING_2554 = false
	XStateEffects.FIX_QI_GUARD_2562 = false
	XStateEffects.FIX_ELYSIA_GUARD_1302 = false
	XStateEffects.FIX_SWORD_2575 = false
	XStateEffects.FIX_SCALE_COUNTER_1072 = false
	XStateEffects.FIX_SCISSORS_CRIT_1068 = false
	XStateEffects.FIX_ELYSIUM_1301 = false
	XStateEffects.FIX_ORDER_TIERS = false
	XStateEffects.FIX_MARK_5576 = false
	XStateEffects.FIX_ITACHI_1318 = false
	XStateEffects.FIX_CRIMSON_1683 = false
	XStateEffects.FIX_QI_RATE_2562 = false
	XStateEffects.FIX_SWORD_RATE_2575 = false
	XStateEffects.FIX_FORCE_CRIT_STACK = false
	XStateEffects.FIX_LOTUS_7303 = false


func _fixes_on() -> void:
	XStateEffects.FIX_UNDYING_2554 = true
	XStateEffects.FIX_QI_GUARD_2562 = true
	XStateEffects.FIX_ELYSIA_GUARD_1302 = true
	XStateEffects.FIX_SWORD_2575 = true
	XStateEffects.FIX_SCALE_COUNTER_1072 = true
	XStateEffects.FIX_SCISSORS_CRIT_1068 = true
	XStateEffects.FIX_ELYSIUM_1301 = true
	XStateEffects.FIX_ORDER_TIERS = true
	XStateEffects.FIX_MARK_5576 = true
	XStateEffects.FIX_ITACHI_1318 = true
	XStateEffects.FIX_CRIMSON_1683 = true
	XStateEffects.FIX_QI_RATE_2562 = false  # fix1 的旧断言按 1%／层数，新的 9.9%／3.5% 例单独开
	XStateEffects.FIX_SWORD_RATE_2575 = false
	XStateEffects.FIX_FORCE_CRIT_STACK = true
	XStateEffects.FIX_LOTUS_7303 = true


func _fix_blocks() -> void:
	_fixes_on()
	XStateEffects.observer = Callable()
	XState.current = XState.new_game_blank()
	var res := func(): return {"execute": true, "resources": XResourceContext.new()}
	var st := func(id: int) -> Dictionary: return XDB.rec("States", id)
	# 不灭之躯：复活一次，状态用掉
	var a := _plain(0.0)
	var e := _plain(0.0)
	e.state_ids.append_array([1, 2554])
	XStateEffects.run_one("respond", e, st.call(2554), _action_ctx(a, e, 7.0))
	check("fix.2554", e.hp == e.mhp and not e.state_ids.has(2554) and not e.is_dead(), [e.hp, e.state_ids])
	# 护体罡气：蓝打空，状态去掉
	e = _plain(1000.0)
	e.mp = 1.0
	e.state_ids.append(2562)
	var got := XStateEffects.run_one("react", e, st.call(2562), _action_ctx(a, e, 200.0))
	check("fix.2562", got == 199.0 and e.mp == 0.0 and not e.state_ids.has(2562), [got, e.mp, e.state_ids])
	# fix2 护体罡气说明：9.9% 伤害由蓝代替
	XStateEffects.FIX_QI_RATE_2562 = true
	e = _plain(1000.0)
	e.mp = 100.0
	e.state_ids.append(2562)
	got = XStateEffects.run_one("react", e, st.call(2562), _action_ctx(a, e, 1000.0))
	check("fix2.2562.rate", got == 901.0 and e.mp == 1.0 and e.state_ids.has(2562), [got, e.mp, e.state_ids])
	e.mp = 50.0
	got = XStateEffects.run_one("react", e, st.call(2562), _action_ctx(a, e, 1000.0))
	check("fix2.2562.empty", got == 950.0 and e.mp == 0.0 and not e.state_ids.has(2562), [got, e.mp, e.state_ids])
	XStateEffects.FIX_QI_GUARD_2562 = false
	e = _plain(1000.0)
	e.mp = 100.0
	got = XStateEffects.run_one("react", e, st.call(2562), _action_ctx(a, e, 1000.0))
	check("fix2.2562.dep_off", got == 990.0, got)  # fix1 开关关了，第二份跟着不用，回原版 1%
	XStateEffects.FIX_QI_GUARD_2562 = true
	XStateEffects.FIX_QI_RATE_2562 = false
	# 永世乐土：每个存活队友减 4%，最高 13%
	for row in [[1, 100.0], [2, 96.0], [3, 92.0], [4, 88.0], [6, 87.0]]:
		e = _plain()
		e.state_ids.append(1302)
		var unit := [e]
		for i in range(int(row[0]) - 1):
			unit.append(_plain())
		XStateEffects.battle_units = {"enemies": unit}
		got = XStateEffects.run_one("react", e, st.call(1302), _action_ctx(a, e, 100.0))
		check("fix.1302.%d" % row[0], got == row[1], [row, got])
	# 剑道争锋：获得 1 层，回合结束加 1 最多 10，每层 0.5%
	var u := _plain()
	XStateEffects.run_one("apply", u, st.call(2575), res.call())
	got = XStateEffects.run_one("confirm", u, st.call(2575), _action_ctx(u, a, 1000.0))
	check("fix.2575.one", got == 1005.0, got)
	for i in range(12):
		XStateEffects.run_one("turn_end", u, st.call(2575), res.call())
	got = XStateEffects.run_one("confirm", u, st.call(2575), _action_ctx(u, a, 1000.0))
	check("fix.2575.ten", got == 1050.0, got)
	XStateEffects.run_one("remove", u, st.call(2575), res.call())
	got = XStateEffects.run_one("confirm", u, st.call(2575), _action_ctx(u, a, 1000.0))
	check("fix.2575.removed", got == 1000.0, got)
	# fix2 剑道争锋说明：用剑（武器类型 2）时伤害 +3.5%，不看层数
	XStateEffects.FIX_SWORD_RATE_2575 = true
	for row in [[2, 1035.0], [11, 1000.0], [0, 1000.0]]:
		var sw := WeaponActor.new()
		sw.setup(1)
		sw.weapon_type = int(row[0])
		XStateEffects.run_one("apply", sw, st.call(2575), res.call())
		got = XStateEffects.run_one("confirm", sw, st.call(2575), _action_ctx(sw, a, 1000.0))
		check("fix2.2575.wt%d" % row[0], got == row[1], [row, got])
	XStateEffects.FIX_SWORD_RATE_2575 = false
	# 必爆 541、755 同时挂：先后解除后回到最初值（原版笔误：被第二个盖成 true）
	for on in [true, false]:
		XStateEffects.FIX_FORCE_CRIT_STACK = on
		XStateEffects.force_critical = false
		XStateEffects.force_depth = 0
		XStateEffects.force_previous = null
		var fc := _plain()
		var crit_item := {"id": 1, "damage": {"type": 1, "elementId": 0, "critical": true}}
		var cctx := _action_ctx(a, fc, 0.0, crit_item)
		for sid in [541, 755]:
			XStateEffects.run_one("select", fc, st.call(sid), cctx)
		check("fix2.crit_stack.during.%s" % on, XStateEffects.force_critical)
		for sid in [541, 755]:
			XStateEffects.run_one("deselect", fc, st.call(sid), cctx)
		check("fix2.crit_stack.%s" % on, XStateEffects.force_critical == (not on), XStateEffects.force_critical)
	XStateEffects.FIX_FORCE_CRIT_STACK = true
	XStateEffects.force_critical = false
	# 挨打反击：受伤 50% 持有者打回去，不清这一击的结果
	var hero := _plain()
	var foe := _plain()
	XStateEffects.battle_units = {"enemies": [foe, hero]}
	for row in [[0.25, 7.0, true], [0.75, 7.0, false], [0.25, 0.0, false]]:
		var ctx := _action_ctx(hero, foe, float(row[1]))
		ctx.random.seq = [row[0]]
		XStateEffects.take_forces()
		got = XStateEffects.run_one("react", foe, st.call(1072), ctx)
		var forces := XStateEffects.take_forces()
		check("fix.1072.%s.%s" % [row[0], row[1]], got == float(row[1]) and forces == ([[0, 0, 5577, 1]] if row[2] else []), [row, forces])
	# 往世乐土：不死，放一株莲，状态用掉
	foe = _plain(0.0)
	foe.resource_death_blocked = true
	foe.state_ids.append(1301)
	XStateEffects.battle_units = {"enemies": [foe, hero]}
	var ctx1301 := _action_ctx(hero, foe, 0.0)
	XStateEffects.take_forces()
	XStateEffects.run_one("deselect", foe, st.call(1301), ctx1301)
	check("fix.1301", foe.hp == 1.0 and not foe.is_dead() and not foe.state_ids.has(1301) and XStateEffects.take_forces() == [[0, 0, 7303, -2]], [foe.hp, foe.state_ids])
	# 秩序、同谐：人数分档
	for row in [[1711, 1, []], [1711, 2, [1712]], [1711, 3, [1713]], [1711, 4, [1714]], [1716, 1, [1717]], [1716, 2, [1718]], [1716, 3, [1719]], [1716, 4, [1720]]]:
		var h := _plain()
		var unit := [h]
		for i in range(int(row[1]) - 1):
			unit.append(_plain())
		XStateEffects.battle_units = {"enemies": unit}
		XStateEffects.run_one("turn_start", h, st.call(int(row[0])), res.call())
		check("fix.tiers.%d.%d" % [row[0], row[1]], h.state_ids == row[2], [row, h.state_ids])
	# 鼬被动：变量不是 1 就预约
	for row in [[0.0, [1513]], [1.0, []], [2.0, [1513]]]:
		XState.current.set_variable(1163, row[0])
		XStateEffects.take_reserves()
		XStateEffects.run_one("turn_start", _plain(), st.call(1318), res.call())
		check("fix.1318.%d" % row[0], XStateEffects.take_reserves() == row[1], row)
	# 绯红之夜 1683：开战写 10，抗 10 次
	XState.current.set_variable(1683, 0.0)
	var c := _plain(0.0)
	c.resource_death_blocked = true
	XStateEffects.run_one("battle", c, st.call(1683), res.call())
	check("fix.1683.battle", XState.current.variable(1683) == 10.0, XState.current.variable(1683))
	XStateEffects.run_one("deselect", c, st.call(1683), _action_ctx(a, c, 0.0))
	check("fix.1683.revive", c.hp == 1.0 and XState.current.variable(1683) == 9.0, [c.hp, XState.current.variable(1683)])
	# 金剪追加、戮仙印记走真实 apply
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	s.random_master = XRandomStream.hex64(4900)
	XState.current = s
	var logic := ReviveLogic.new()
	logic.elite_roll = 100.0
	logic.setup(2, s)
	var actor: XBattler = logic.actors[0]
	var foe2: XBattler = logic.enemies[0]
	actor.state_ids.append(1068)
	XStateEffects.force_critical = true
	XStateEffects.take_forces()
	logic.apply(actor, XDB.rec("Skills", 1), foe2)
	check("fix.1068.crit", XStateEffects.take_forces() == [[1, int(actor.actor_id), 5576, 0]])
	XStateEffects.force_critical = false
	logic.apply(actor, XDB.rec("Skills", 1), foe2)
	check("fix.1068.no_crit", XStateEffects.take_forces().is_empty())
	actor.state_ids.erase(1068)
	var plain_hit := logic.apply(actor, XDB.rec("Skills", 5576), foe2)
	foe2.state_ids.append(1067)
	var marked_hit := logic.apply(actor, XDB.rec("Skills", 5576), foe2)
	check("fix.5576", float(marked_hit.state_value) == float(plain_hit.state_value) * 4.0, [plain_hit.state_value, marked_hit.state_value])
	XStateEffects.FIX_MARK_5576 = false
	check("fix.5576.off", float(logic.apply(actor, XDB.rec("Skills", 5576), foe2).state_value) == float(plain_hit.state_value))
	XStateEffects.FIX_MARK_5576 = true
	foe2.state_ids.erase(1067)
	# 排到的强制行动真能跑（一株莲）：逻辑取得走、有记录
	var forced: Array = logic._force_action([1, int(actor.actor_id), 7303, -2], null)
	check("fix.1301.force_runs", not forced.is_empty(), forced.size())
	# fix2 一株莲说明：回复所有队友（包括死亡）
	for on in [true, false]:
		XStateEffects.FIX_LOTUS_7303 = on
		var mate: XBattler = logic.actors[1]
		mate.hp = 0.0
		if not mate.state_ids.has(1):
			mate.state_ids.append(1)
		var lotus_logs: Array = logic._force_action([1, int(actor.actor_id), 7303, -2], null)
		check("fix2.lotus.%s" % on, mate.is_alive() == on, [mate.hp, mate.state_ids, lotus_logs.size(), logic.targets_for(actor, XDB.rec("Skills", 7303)).size(), actor.is_dead()])
	XStateEffects.FIX_LOTUS_7303 = true
	# 琼霄平衡：追加／反击打出的招不再触发追加；每回合最多反击 1 次
	XStateEffects.clear_queues()
	XStateEffects.chain_depth = 1
	XStateEffects.queue_force_quiet(actor, 5576, 0)
	XStateEffects.queue_force_quiet(actor, 7303, -2)
	check("fix2.chain_guard.on", XStateEffects.take_forces() == [[1, int(actor.actor_id), 7303, -2]])
	XStateEffects.FIX_CHAIN_GUARD = false
	XStateEffects.queue_force_quiet(actor, 5576, 0)
	check("fix2.chain_guard.off", XStateEffects.take_forces().size() == 1)
	XStateEffects.FIX_CHAIN_GUARD = true
	XStateEffects.chain_depth = 0
	# rules9 审查 39 P3-6：只有 5576／5577 自己打出的一击才算防连锁，别的强制行动命中琼霄时反击照常排队
	var dl := DepthLogic.new()
	dl.elite_roll = 100.0
	dl.setup(2, s)
	dl._forced_run(actor, XDB.rec("Skills", 7303), null, null)
	dl._forced_run(actor, XDB.rec("Skills", 5577), null, null)
	check("rules9.chain_depth.only_chain_skills", dl.depths == [0, 1] and XStateEffects.chain_depth == 0, [dl.depths, XStateEffects.chain_depth])
	var holder := _plain()
	XStateEffects.battle_units = {"enemies": [foe, holder]}
	for flag in [true, false]:
		XStateEffects.FIX_COUNTER_ONCE = flag
		XStateEffects._counter_turn.clear()
		XStateEffects.battle_turn = 1
		XStateEffects.take_forces()
		for i in range(3):
			var cctx := _action_ctx(foe, holder, 7.0)
			cctx.random.seq = [0.25]
			XStateEffects.run_one("react", holder, st.call(1072), cctx)
		check("fix2.counter_once.%s" % flag, XStateEffects.take_forces().size() == (1 if flag else 3))
		XStateEffects.battle_turn = 2
		var nctx := _action_ctx(foe, holder, 7.0)
		nctx.random.seq = [0.25]
		XStateEffects.run_one("react", holder, st.call(1072), nctx)
		check("fix2.counter_next_turn.%s" % flag, XStateEffects.take_forces().size() == 1)
	XStateEffects.FIX_COUNTER_ONCE = true
	# 审查 38 P2-1：上一场残留的强制行动／预约不进下一场
	XStateEffects.queue_force_quiet(actor, 5576, 0)
	XStateEffects._reserves.append(2)
	var next_logic := ReviveLogic.new()
	next_logic.elite_roll = 100.0
	next_logic.setup(2, s)
	check("fix.queue_clear.forces", XStateEffects.take_forces().is_empty())
	check("fix.queue_clear.reserves", not XStateEffects._reserves.has(2), XStateEffects._reserves)
	XStateEffects.FIX_QUEUE_CLEAR = false
	XStateEffects.queue_force_quiet(actor, 5576, 0)
	next_logic = ReviveLogic.new()
	next_logic.elite_roll = 100.0
	next_logic.setup(2, s)
	check("fix.queue_clear.off_keeps", XStateEffects.take_forces().size() == 1)
	XStateEffects.FIX_QUEUE_CLEAR = true
	# rules9 审查 39 P3-5：开战时带着 1307 崩坏能，它 remove 阶段预约的 CE1505 要进预约流（先清上一场遗留再移除状态）；
	# 公共事件是单槽，随后开战预约的 1320 照原版盖掉它，所以只看预约流
	XStateEffects._reserves.append(2)
	actor.state_ids.append(1307)
	var rl := ReserveLogic.new()
	rl.elite_roll = 100.0
	rl.setup(2, s)
	check("rules9.queue_clear.keeps_remove_reserve", not actor.state_ids.has(1307) and rl.seen.has(1505) and not rl.seen.has(2), [actor.state_ids, rl.seen])
	XStateEffects.clear_queues()
	# 追加跑到队列空；关开关回到一次检查只走一代
	for on in [true, false]:
		XStateEffects.FIX_FORCE_DRAIN = on
		XStateEffects.clear_queues()
		var cl := ChainLogic.new()
		cl.elite_roll = 100.0
		cl.setup(2, s)
		XStateEffects.queue_force_quiet(cl.actors[0], 1, 0)
		cl.run_events()
		check("fix.force_drain.%s" % on, (cl.ran == 3) if on else (cl.ran < 3), cl.ran)
		XStateEffects.clear_queues()
	XStateEffects.FIX_FORCE_DRAIN = true
	XState.current = null
	XStateEffects.battle_units = {}


func finish() -> void:
	_fix_blocks()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## rules8 第二批：regenerate、回合／行动钩子、变量与计数器、公共事件预约（state_effects_probe rest2.blocks）。
func _rest2_blocks(o: Dictionary) -> void:
	XStateEffects.observer = Callable()
	check("rest2.rows", o.regen.size() == 15 and o.hooks.size() == 70, [o.regen.size(), o.hooks.size()])
	_rest_regen(o.regen, "rest2")
	var phases := {"addState": "apply", "removeState": "remove", "leaveState": "leave", "turnStartState": "turn_start", "turnEndState": "turn_end", "actionStartState": "action_start",
		"initiateState": "initiate", "confirmState": "confirm", "deselectState": "deselect", "battle": "battle"}
	var vars := [320, 1129, 1130, 1136, 1138, 1139, 1140, 1214]
	var seen := {}
	for index in range(o.hooks.size()):
		var row: Dictionary = o.hooks[index]
		var sid := int(row.sid)
		var phase: String = phases[row.phase]
		if sid == 2018:
			continue  # 2018 用真战斗对象（有 param_plus），放在循环后面单测
		var st := XDB.rec("States", sid)
		var key := "%d.%s" % [sid, phase]
		if not seen.has(key) and st.effects.any(func(e): return e.phase == phase):
			seen[key] = true
			check("rest2.translated." + key, st.effects.any(func(e): return e.phase == phase and e.op in ["effect_program", "noop"]) and not st.effects.any(func(e): return e.phase == phase and e.op == "js"), st.effects)
		var s := XState.new_game_blank()
		XState.current = s
		var a := _plain()
		var e := _plain()
		var who: Dictionary = row[row.holder]
		var holder: XBattler = a if row.holder == "a" else e
		holder.values.mmp = float(row.pre[row.holder].mmp)
		holder.values.mhp = float(row.pre[row.holder].mhp)
		holder.hp = minf(1000.0, float(row.pre[row.holder].mhp))
		holder.mp = minf(50.0, float(row.pre[row.holder].mmp))
		var label := str(row.label)
		# 起始状态：探针 setup 的值从 label 还原
		if label.begins_with("v1136="):
			var parts := label.split(",")
			s.set_variable(1136, float(parts[0].substr(6)))
			var pre := parts[1].substr(4)
			if pre != "null":
				holder.state_data["_stateCounter"] = {str(sid): float(pre)}
		if label.begins_with("v="):
			s.set_variable(1214, float(label.substr(2)))
		if sid == 49 and label == "prev":
			holder.state_data["_lastUsedSkill"] = 5.0
		if sid == 102 and label in ["rev80", "rev20"]:
			a.state_data["_reverenceMp"] = 80.0 if label == "rev80" else 20.0
			if row.holder == "e":
				a.state_data["_reverenceMp"] = null  # Action 版 initiate 的 user 是行动者 a；探针里字段设在了持有者 e，行动者没有
				a.state_data.erase("_reverenceMp")
		holder.state_ids.append(sid)
		var units := [a, e]
		XStateEffects.battle_units = {"enemies": [e], "actors": [a]}
		var ctx: Dictionary = {"execute": true, "resources": XResourceContext.new()}
		if phase in ["initiate", "confirm", "deselect"]:
			ctx = _action_ctx(a, e, 7.0)
		XStateEffects.take_reserves()
		XStateEffects.run_one(phase, holder, st, ctx)
		var taken := XStateEffects.take_reserves()
		var info := [sid, row.phase, row.holder, label]
		check("rest2.hook.%d.reserve" % index, (taken.back() if not taken.is_empty() else 0) == int(row.reserved), [info, row.reserved, taken])
		check("rest2.hook.%d.vars" % index, vars.map(func(v): return s.variable(v)) == row.vars.map(func(x): return float(x)), [info, row.vars, vars.map(func(v): return s.variable(v))])
		var want_counter := {}
		for k in who.counter:
			want_counter[str(k)] = float(who.counter[k])
		var got_counter := {}
		for k in holder.state_data.get("_stateCounter", {}):
			got_counter[str(k)] = float(holder.state_data._stateCounter[k])
		if sid in [1778, 1776]:
			check("rest2.hook.%d.counter_keys" % index, got_counter.keys().filter(func(k): return want_counter.has(k)).size() >= 1 or want_counter.is_empty(), [info, want_counter, got_counter])
		for k in want_counter:
			if k in [str(sid)] or sid in [1769, 1772, 1776]:
				check("rest2.hook.%d.counter.%s" % [index, k], got_counter.get(k, 0.0) == want_counter[k] or (sid == 1776 and k == "1775"), [info, want_counter, got_counter])
		var want_states: Array = who.states.map(func(x): return int(x))
		want_states.sort()
		check("rest2.hook.%d.states" % index, _sorted(holder.state_ids) == want_states, [info, want_states, holder.state_ids])
		var rev = holder.state_data.get("_reverenceMp", null)
		if sid == 102:
			var rev_user: XBattler = a if phase in ["initiate"] else holder
			var want_rev = who.rev
			var user_rev = rev_user.state_data.get("_reverenceMp", null)
			if phase == "action_start":
				check("rest2.hook.%d.rev" % index, user_rev == (null if want_rev == null else float(want_rev)) or (want_rev != null and user_rev != null and float(user_rev) == holder.mp), [info, want_rev, user_rev, holder.mp])
			else:
				check("rest2.hook.%d.rev_cleared" % index, user_rev == null or row.holder == "e", [info, user_rev])
				var heal: int = ctx.resources.started_popups.get(a, []).size()
				var want_heal: int = row.popups.size()
				check("rest2.hook.%d.heal_popup" % index, heal == want_heal or row.holder == "e", [info, heal, want_heal])
		if sid == 49:
			check("rest2.hook.%d.noop" % index, not holder.state_data.has("_lastUsedSkill") or label == "prev", info)
	# 2018 狠活状态：addParam 两项（真战斗对象才有 param_plus）
	var plus_rows: Array = o.hooks.filter(func(r): return int(r.sid) == 2018)
	var logic := ReviveLogic.new()
	logic.elite_roll = 100.0
	XEnemy.force_roll = 100.0
	var sp := XState.new_game(3, 1, [8])
	XState.current = sp
	logic.setup(2, sp)
	for index in range(plus_rows.size()):
		var row: Dictionary = plus_rows[index]
		var t: XBattler = logic.actors[0] if row.holder == "a" else logic.enemies[0]
		var v := float(str(row.label).substr(2))
		sp.set_variable(1214, v)
		var before2 := t.param_plus(2)
		var before4 := t.param_plus(4)
		XStateEffects.run_one(phases[row.phase], t, XDB.rec("States", 2018), {"execute": true, "resources": XResourceContext.new()})
		check("rest2.param.%d" % index, t.param_plus(2) - before2 == float(row.get(row.holder).plus[2]) and t.param_plus(4) - before4 == float(row.get(row.holder).plus[4]), [row.phase, v, t.param_plus(2) - before2, row.get(row.holder).plus])
		# 回到 0：remove／leave 的差是负的，apply 的是正的，下一行的起点不同；把 base 归位
		t.add_param(2, before2 - t.param_plus(2))
		t.add_param(4, before4 - t.param_plus(4))
	XState.current = null
	XStateEffects.battle_units = {}


## 毒奶 732（rules8，state_effects_probe poison.blocks）：来源者角色的法宝等级与叠毒层数、变量 320 一起算伤害；来源者是敌人整块无效果。
func _poison_blocks(o: Dictionary) -> void:
	XStateEffects.observer = Callable()
	check("poison.rows", o.rows.size() == 40, o.rows.size())
	var logic := ReviveLogic.new()
	logic.elite_roll = 100.0
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	logic.setup(2, s)
	var rec := XDB.rec("States", 732)
	check("poison.translated", rec.effects.any(func(e): return e.phase == "regenerate" and e.op == "effect_program") and not rec.effects.any(func(e): return e.phase == "regenerate" and e.op == "js"), rec.effects)
	for index in range(o.rows.size()):
		var row: Dictionary = o.rows[index]
		var stacks := 1.0 if row.stacks == null else float(row.stacks)
		var v := float(row.v320)
		# 先用参照行自己的数据验证公式：原文 damage = round(层数×0.5×(mmp×8+v320+mat)×(1+等级)×(1+v320/3000)²)
		var native_damage := roundf(stacks * 0.5 * (float(row.pre.ommp) * 8.0 + v + float(row.pre.omat)) * (1.0 + float(row.pre.level)) * (1.0 + v / 3000.0) * (1.0 + v / 3000.0))
		var native_hp_after := float(row.pre.ehp) - native_damage if row.mode != "enemy_origin" else float(row.pre.ehp)
		check("poison.native.%d" % index, maxf(native_hp_after, 0.0) == float(row.ehp), [row, native_damage])
		s.set_variable(320, v)
		var e := ValueBattler.new()
		e.values = {"mhp": 1e12, "mmp": 100.0}
		e.hp = float(row.pre.ehp)
		e.state_ids.append(732)
		if row.stacks != null:
			e.state_data["_stackingPoison"] = float(row.stacks)
		var origin: XBattler = logic.actors[0]
		var equip: Dictionary = XActor.make_equip("armor", 3590).duplicate(true)
		equip["instanceLevel"] = float(row.pre.level)
		var added: bool = row.mode != "actor_none"
		if row.mode == "enemy_origin":
			origin = ValueBattler.new()
			origin.values = {"mhp": 100.0, "mmp": 6.0}
		elif added:
			origin.equips.append(equip)
			origin.param_mark_dirty()
			origin.param_refresh()
		e.state_origins[732] = weakref(origin)
		var logs := []
		XStateEffects.run_one("regenerate", e, rec, {"execute": true, "resources": XResourceContext.new(), "emit": func(entry): logs.append(entry)})
		var damage := float(row.pre.ehp) - e.hp
		var want := 0.0
		if row.mode != "enemy_origin":
			want = roundf(stacks * 0.5 * (origin.mmp * 8.0 + v + origin.mat) * (1.0 + (float(row.pre.level))) * (1.0 + v / 3000.0) * (1.0 + v / 3000.0))
			want = minf(want, float(row.pre.ehp))
		var info := [row.mode, row.level, row.stacks, row.v320, row.ehpIn]
		check("poison.damage.%d" % index, damage == want, [info, damage, want])
		check("poison.dead.%d" % index, e.is_dead() == bool(row.dead), [info, e.hp, row.dead])
		var field = e.state_data.get("_stackingPoison", null)
		check("poison.field.%d" % index, field == (null if row.field == null else float(row.field)), [info, field, row.field])
		var anims: Array = logs.filter(func(l): return l.has("animation")).map(func(l): return int(l.animation))
		check("poison.anim.%d" % index, anims == row.anims.map(func(p): return int(p[1])), [info, anims, row.anims])
		if added and row.mode != "enemy_origin":
			origin.equips.erase(equip)
			origin.param_mark_dirty()
			origin.param_refresh()
	XState.current = null
