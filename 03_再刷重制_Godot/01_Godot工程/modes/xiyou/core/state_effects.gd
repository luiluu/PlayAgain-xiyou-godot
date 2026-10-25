class_name XStateEffects
extends RefCounted
## YEP/BSC phase dispatcher. KRZ cached lists and direct lifecycle slots share
## one execution path, including native-measured constant bonus steps.
## JS remains diagnostic-only. OTB action_end and unknown crit stay unfired.

const BATTLER_PHASES := ["battle", "turn_start", "turn_end", "regenerate", "action_start", "victory", "escape", "defeat"]
const ACTION_PHASES := ["initiate", "select", "deselect", "conclude", "confirm", "react", "respond", "establish"]
## 原来分散在 damage.gd 与 battle_logic.gd 的两个 op，统一在本类执行。
const SUPPORTED_OPS := ["mul", "user_param_damage", "value_steps", "value_program", "value_query", "gain_resource", "param_add"]
## 冻结版不触发的 phase：数据里有块但运行时从不调用
const NEVER_FIRED := {"action_end": "OTB 行动结束绕过 YEP_BuffsStatesCore 的 endAction 包装", "crit": "冻结版没有触发 crit 的插件"}
const DIAGNOSTIC_LIMIT := 500

## 测试观察者：每次某状态在某 phase 被分发时调用 (phase, state_id, holder, ctx)；ctx 是该状态这次调用的完整上下文
static var observer := Callable()
## 正在执行的上下文栈：每个状态每次调用压一层、返回后弹出（嵌套分发时外层上下文原样恢复，不用静态 acting 代替 user／origin）
static var _stack: Array = []
## 未翻译清单：{phase, state, holder, op}，同键只记一次
static var diagnostics: Array = []
static var _seen := {}


## Private value-only adapter: current signed phase input, without the damage
## entry's zero initial value, nonnegative clamp or healing sign conversion.
class PhaseValueProgram:
	extends XFormulaProgram
	var _battlers := {}
	var _random: XRandomStream
	var _tag := ""

	func run_phase(program: Dictionary, ctx: Dictionary, value: float, execute: bool) -> Dictionary:
		if program.get("version") != 1 or program.get("status") != "pure":
			return {"available": false, "value": value}
		var a: XBattler = ctx.user if execute else XFormulaContext.clone_battler(ctx.user)
		var b: XBattler = a if ctx.user == ctx.target else (ctx.target if execute else XFormulaContext.clone_battler(ctx.target))
		if a == null or b == null:
			return {"available": false, "value": value}
		_battlers = {"a": a, "b": b}
		var variables = ctx.variables if ctx.has("variables") else (XState.current.variable_array() if XState.current else {})
		_context = {"v": variables, "s": ctx.get("switches", {})}
		_random = ctx.get("random") if execute else null
		_tag = "%s:%s" % [ctx.phase, ctx.state_id]
		for name in program.locals:
			_locals[str(name)] = UNDEFINED
		var item: Dictionary = ctx.get("item", {})
		_locals.merge({"value": value, "se_hp": int(item.get("damage", {}).get("type", 0)) in [1, 3, 5],
			"se_magic": int(item.get("hitType", 0)) == 2, "se_physical": int(item.get("hitType", 0)) == 1,
			"se_critical": bool(ctx.get("critical", false))}, true)
		for step in program.steps:
			_step(step)
			if not _error.is_empty():
				break
		return {"available": _error.is_empty(), "value": _number(_locals.value), "diagnostic": _error}

	func _expr(node: Dictionary):
		var value = super._expr(node)
		# These measured blocks use Game_Variables.value(), whose missing value is 0.
		# Keep the general formula VM's raw v[index]/undefined behavior unchanged.
		if node.get("op") == "lookup" and node.get("pool") == "v" and value is StringName and value == UNDEFINED:
			return 0.0
		return value

	func _property(receiver: String, name: String):
		return _battlers[receiver].get(name) if name in XFormulaContext.PROPERTIES.split(" ") else _fail("unknown_property")

	func _read(node: Dictionary):
		var b: XBattler = _battlers[node.receiver]
		match str(node.name):
			"states_count": return b.states().size()
			"hp_rate": return _divide(b.hp, b.mhp)
		return _fail("unsupported_phase_read")

	func _math(node: Dictionary):
		if node.name == "random" and _random != null:
			_draws += 1
			var value := _random.next_float("state_effect", _tag)
			return value if _random.error.is_empty() else _fail(_random.error)
		return super._math(node)


## 对持有者当前的状态（快照、按状态顺序）分发一个 phase。ctx：Action 版给 {"attacker", "defender", "item"}；Battler 版可空。
static func run(phase: String, holder: XBattler, ctx := {}) -> float:
	var value := float(ctx.get("value", 0.0))
	if holder == null:
		return value
	var execute := _execution_requested(holder, ctx)
	# processStateEval uses states directly; typestates owns all action/turn lists.
	var rows: Array = holder.states().duplicate() if phase in ["battle", "victory", "escape", "defeat"] else holder.effect_states(phase, execute).duplicate()
	for st in rows:
		var next := ctx.duplicate()
		next.execute = execute
		next.value = value
		value = run_one(phase, holder, st, next)
	return value

## Lifecycle slots execute even after the state has left the current list.
static func run_one(phase: String, holder: XBattler, st: Dictionary, ctx := {}) -> float:
	var c := context_for(phase, holder, int(st.id), ctx)
	c.value = float(ctx.get("value", 0.0))
	var effects: Array = st.get("effects", []).filter(func(e): return str(e.get("phase", "")) == phase)
	if effects.is_empty():
		return c.value
	# A cloned actor has no persistent capability. Keep this invocation silent,
	# including observer/diagnostics, even when its caller forgot execute=false.
	if effects.any(func(e): return e.get("op") == "param_add") and c.user is XActor and not c.user.can_add_param():
		c.execute = false
	var execute := bool(c.execute)
	# Game_Battler.customEffectEval always shadows the enclosing action domain,
	# including non-Boss/missing origins. Only native react1341/2550 override Action.
	var resources: XResourceContext = c.get("resources")
	var special_react := phase == "react" and int(st.id) in [1341, 2550]
	var origin_domain := execute and resources != null and (not phase in ACTION_PHASES or special_react)
	if origin_domain:
		var source: XBattler = holder if special_react and int(st.id) == 2550 else c.origin
		var victim: XBattler = (c.user if int(st.id) == 2550 else c.target) if special_react else holder
		resources.boss_output.enter_action(source, victim)
	_stack.push_back(c)
	if execute and observer.is_valid():
		observer.call(phase, int(st.id), holder, c)
	for e in effects:
		var op := str(e.get("op", ""))
		if op == "mul":
			if _active(e, c):
				c.value = _rounded(c.value * float(e.k), str(e.round))
		elif op == "value_steps":
			for group in e.groups:
				if not _active(group, c):
					continue
				for step in group.steps:
					if step.get("criticalOnly", false) and not c.get("critical", false):
						continue
					var amount := _rounded(c.value * float(step.k), str(step.round))
					c.value = c.value + amount if step.kind == "add" else amount
		elif op == "value_program":
			var out := PhaseValueProgram.new().run_phase(e.program, c, c.value, execute)
			if out.available:
				c.value = out.value
			elif execute:
				_diagnose(phase, int(st.id), holder, "value_program_unavailable")
		elif op == "value_query":
			c.value = _query_value(e, c, execute)
		elif op == "param_add" and execute:
			_add_params(e, c)
		elif op == "gain_resource" and execute:
			if resources == null:
				_diagnose(phase, int(st.id), holder, "resource_context_missing")
			else:
				resources.gain(c.user, str(e.resource), float(e.amount))
				if not resources.error.is_empty():
					_diagnose(phase, int(st.id), holder, resources.error)
		elif op == "user_param_damage" and execute and ctx.get("resources") != null:
			var r: Dictionary = ctx.record
			for p in e.params:
				var amount := float(c.user.get(str(p)))
				if amount > 0.0:
					ctx.resources.gain(c.target, "hp", -amount)
					r.extra = r.get("extra", []) + [amount]
					r.record_hp = float(r.get("record_hp", 0.0)) + floorf(amount)
		elif not SUPPORTED_OPS.has(op):
			if ctx.has("untranslated"):
				ctx.untranslated.append({"state": int(st.id), "phase": phase})
			if execute:
				_diagnose(phase, int(st.id), holder, op)
	_stack.pop_back()
	if origin_domain:
		resources.boss_output.leave_action()
	return c.value


## Execute-only permanent writes. Native refresh runs after EVERY addParam,
## in the enclosing operation's resource domain (including nested death hooks).
static func _add_params(effect: Dictionary, ctx: Dictionary) -> void:
	var target: XBattler = ctx.target
	if effect.get("when") == "target_dead":
		if target == null:
			return
		# Native isDead also requires isAppeared. HP<=0 is an independent
		# short-circuit, so hidden HP0 still grants the permanent bonus.
		var death_state: bool = target.state_ids.has(1) and (not target is XEnemy or not (target as XEnemy).hidden)
		if not (target.hp <= 0.0 or death_state):
			return
	if not ctx.user is XActor:
		_diagnose(ctx.phase, int(ctx.state_id), ctx.holder, "param_add_actor_required")
		return
	var user: XActor = ctx.user
	if not user.can_add_param():
		return
	var previous := user.lifecycle_context
	user.lifecycle_context = ctx
	for step in effect.steps:
		var amount := float(step.amount)
		if effect.scale == "level":
			amount *= user.level
		user.add_param(int(step.param), amount)
	user.lifecycle_context = previous


## Explicit preview markers cannot be overridden by execute=true. Resolve this
## before typestates, observer and diagnostics, as well as before mutation.
static func _execution_requested(holder: XBattler, ctx: Dictionary) -> bool:
	for inputs in [holder.lifecycle_context, ctx]:
		var resources: XResourceContext = inputs.get("resources")
		if bool(inputs.get("preview", false)) or (resources != null and resources.preview):
			return false
	return bool(ctx.get("execute", holder.lifecycle_context.get("execute", true)))


## Four complete measured blocks. Preserve each native short circuit; queries
## never run on the other branch. In particular, party is the player party even
## for enemy attackers, and aliveMembers tests death-state membership, not HP.
static func _query_value(effect: Dictionary, ctx: Dictionary, execute: bool) -> float:
	var value := float(ctx.value)
	if effect.query == "defender_hp":
		if value <= 0.0 or not ctx.target is XEnemy:
			return value
		var target: XBattler = ctx.target if execute else XFormulaContext.clone_battler(ctx.target)
		return ceilf(value * 2.0) if target != null and target.hp / target.mhp < 0.2 else value
	if not _active({"cond": "positive", "hpOnly": true}, ctx):
		return value
	if effect.query == "element_contains":
		var user: XBattler = ctx.user if execute else XFormulaContext.clone_battler(ctx.user)
		if user != null and _query_elements(ctx, user).has(int(effect.element)) == bool(effect.present):
			return 0.0
	elif effect.query == "party_alive":
		var party: Array = ctx.get("party_members", [])
		if not ctx.has("party_members") and XState.current != null:
			# Read already resolved members only: preview must not initialize slots
			# or lazily create real actors via XState.actor()/battle_members().
			for id in XState.current.battle_slots:
				var member = XState.current.actors.get(int(id))
				if member != null and XState.current.party.has(int(id)):
					party.append(member)
		if party.filter(func(member): return not member.state_ids.has(1)).size() == 1:
			return floorf(value * 1.5)
	return value


## installDamageElementRuntime.getItemElements: forced wins over null, then
## passive/attack/item elements, multiple and added, unique and range 1..15.
## Forced/added inputs are action-owned; future sequence support can pass them
## here without global mutable state. Current battle has no such sequence ops.
static func _query_elements(ctx: Dictionary, user: XBattler) -> Array:
	var item: Dictionary = ctx.item
	if user is XActor and user.actor_id == 172 and int(item.get("id", 0)) in [10234, 10235]:
		return [13]
	var elements: Array
	if ctx.has("forced_elements"):
		elements = ctx.forced_elements
	else:
		if user.trait_objects().any(func(obj): return str(obj.get("note", "")).to_upper().contains("<ELEMENT NULL>")):
			return []
		elements = XDamage.action_elements(item, user)
		elements.append_array(ctx.get("added_elements", []))
	var out := []
	for element in elements:
		if int(element) >= 1 and int(element) <= 15 and not out.has(int(element)):
			out.append(int(element))
	return out


static func _active(effect: Dictionary, ctx: Dictionary) -> bool:
	var hp: bool = int(ctx.get("item", {}).get("damage", {}).get("type", 0)) in [1, 3, 5]
	var cond := str(effect.get("cond", ""))
	var active: bool = ctx.value != 0.0 if cond == "nonzero" else ctx.value > 0.0 if cond == "positive" else ctx.value >= 0.0 if cond == "nonnegative" else false
	return active and (not effect.get("hpOnly", false) or hp)


static func _rounded(value: float, kind: String) -> float:
	return ceilf(value) if kind == "ceil" else floorf(value) if kind == "floor" else XPower.js_round(value)

## 一个状态一次调用的上下文。Battler 版（Game_Battler.customEffectEval）：user＝target＝持有者；
## Action 版（Game_Action.customEffectEval）：user＝attacker、target＝defender，item 为当前行动。
## origin：持有者身上该状态的来源，没有或已失效时回退为持有者（BSC stateOrigin 的无来源回退）。
static func context_for(phase: String, holder: XBattler, state_id: int, ctx := {}) -> Dictionary:
	# Preview cannot borrow real mutation capabilities, even inside a live callback.
	var inputs: Dictionary = holder.lifecycle_context.duplicate() if bool(ctx.get("execute", true)) else {}
	inputs.merge(ctx, true)
	var origin: XBattler = holder
	var ref = holder.state_origins.get(state_id)
	if ref is WeakRef and ref.get_ref() != null:
		origin = ref.get_ref()
	var c := {"phase": phase, "state_id": state_id, "holder": holder, "origin": origin, "execute": _execution_requested(holder, ctx)}
	if phase in ACTION_PHASES:
		c.merge({"attacker": inputs.get("attacker"), "defender": inputs.get("defender"), "item": inputs.get("item"),
			"user": inputs.get("attacker"), "target": inputs.get("defender")})
	else:
		c.merge({"user": holder, "target": holder})
	for key in ["item", "critical", "resources", "record", "random", "variables", "switches", "party_members", "forced_elements", "added_elements"]:
		if inputs.has(key):
			c[key] = inputs[key]
	return c


## 当前正在执行的上下文（栈顶）；不在分发中时为空字典
static func current() -> Dictionary:
	return _stack.back() if not _stack.is_empty() else {}


## 一个单位（我方含后备或敌群）逐成员分发 Battler 版 phase
static func run_unit(phase: String, members: Array, ctx := {}) -> void:
	for b in members:
		run(phase, b, ctx)


static func _diagnose(phase: String, state_id: int, holder: XBattler, op: String) -> void:
	var k := "%s|%d|%s" % [phase, state_id, op]
	if _seen.has(k):
		return
	_seen[k] = true
	diagnostics.append({"phase": phase, "state": state_id, "op": op, "holder": holder.display_name(),
		"kind": "untranslated" if op == "js" else "unknown_op"})
	if diagnostics.size() > DIAGNOSTIC_LIMIT:
		diagnostics.pop_front()


static func clear_diagnostics() -> void:
	diagnostics.clear()
	_seen.clear()
