class_name XStateEffects
extends RefCounted
## YEP/BSC phase dispatcher. KRZ cached lists and direct lifecycle slots share
## one execution path, including native-measured constant bonus steps.
## JS remains diagnostic-only. OTB action_end and unknown crit stay unfired.

const BATTLER_PHASES := ["battle", "turn_start", "turn_end", "regenerate", "action_start", "victory", "escape", "defeat"]
const ACTION_PHASES := ["initiate", "select", "deselect", "conclude", "confirm", "react", "respond", "establish"]
## 原来分散在 damage.gd 与 battle_logic.gd 的两个 op，统一在本类执行。
const SUPPORTED_OPS := ["mul", "user_param_damage", "value_steps", "value_program", "value_query", "poison_stack", "poison_tick",
	"add_state", "gain_steps", "set_variable", "syntax_error", "counter_init", "counter_set"]
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

	func run_phase(program: Dictionary, ctx: Dictionary, value: float, execute: bool, extra := {}) -> Dictionary:
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
		_locals.merge(extra, true)
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
	var execute := bool(ctx.get("execute", true))
	# processStateEval uses states directly; typestates owns all action/turn lists.
	var rows: Array = holder.states().duplicate() if phase in ["battle", "victory", "escape", "defeat"] else holder.effect_states(phase, execute).duplicate()
	for st in rows:
		var next := ctx.duplicate()
		next.value = value
		value = run_one(phase, holder, st, next)
	return value

## Lifecycle slots execute even after the state has left the current list.
static func run_one(phase: String, holder: XBattler, st: Dictionary, ctx := {}) -> float:
	var c := context_for(phase, holder, int(st.id), ctx)
	c.value = float(ctx.get("value", 0.0))
	var execute := bool(ctx.get("execute", true))
	var effects: Array = st.get("effects", []).filter(func(e): return str(e.get("phase", "")) == phase)
	if effects.is_empty():
		return c.value
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
		elif op == "poison_stack":
			# Apply：x = x || 0; x += n。Remove：x = 0。层数挂在持有者身上，所有叠毒状态共用
			holder.state_data["_stackingPoison"] = (_truthy_number(holder.state_data.get("_stackingPoison")) + float(e.n)) if e.mode == "add" else 0.0
		elif op == "poison_tick" and execute:
			_poison_tick(e, holder, c, ctx)
		elif op == "add_state" and execute:
			# 暴击后加状态（Establish）：只看这个目标的结果槽 critical；addState 的回合参数原版不认
			if not e.get("criticalOnly", false) or c.get("critical", false):
				_add_state(c.get(str(e.who)), int(e.id), ctx)
		elif op == "gain_steps" and execute:
			_gain_steps(e, holder, c, ctx)
		elif op == "set_variable" and execute:
			# Game_Variables.setValue：编号不在 1..System.variables 长度-1 内的写入原版直接忽略（如 1683 号脚本）
			var vid := int(e.id)
			if XState.current != null and vid > 0 and vid < XDB.system().get("variables", []).size():
				XState.current.set_variable(vid, float(e.value))
		elif op == "counter_init" and execute:
			# 计数 = 计数 || $gameVariables.value(V)：已有的（移除后也留着）不改
			var counters: Dictionary = c.user.state_data.get("_stateCounter", {})
			if _truthy_number(counters.get(str(e.state))) == 0.0:
				counters[str(e.state)] = XState.current.variable(int(e.variable)) if XState.current != null else 0.0
			c.user.state_data["_stateCounter"] = counters
		elif op == "counter_set" and execute:
			var out := PhaseValueProgram.new().run_phase(e.program, c, 0.0, true)
			if out.available:
				var counters: Dictionary = c.user.state_data.get("_stateCounter", {})
				counters[str(e.state)] = out.value
				c.user.state_data["_stateCounter"] = counters
			else:
				_diagnose(phase, int(st.id), holder, "counter_set_unavailable")
		elif op == "syntax_error":
			pass  # 原版这块解析失败（SyntaxError），customEffectEval 只报错，什么都不改
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
	return c.value


## 叠毒 Regenerate 整块：层数 = 层数 || 1（写回）；伤害式按来源能力算；target.gainHp(-伤害) 走护盾吸收与死亡结算。
## regenerateStateEffects 每个状态先 clearResult，所以每次用新的结果槽。弹字与动画经 ctx.emit 交给战斗记录。
static func _poison_tick(e: Dictionary, holder: XBattler, c: Dictionary, ctx: Dictionary) -> void:
	var stacks := _truthy_number(holder.state_data.get("_stackingPoison"))
	if stacks == 0.0:
		stacks = 1.0
	holder.state_data["_stackingPoison"] = stacks
	var run_ctx := c.duplicate()
	run_ctx.user = c.origin
	run_ctx.target = holder
	run_ctx.item = {}
	var out := PhaseValueProgram.new().run_phase(e.program, run_ctx, 0.0, true, {"stacks": stacks})
	if not out.available:
		_diagnose("regenerate", int(c.state_id), holder, "poison_tick_unavailable")
		return
	var rc := XResourceContext.new()
	rc.random = ctx.get("random")
	rc.gain(holder, "hp", -float(out.value))
	var r := rc.result(holder)
	if ctx.get("emit") is Callable and ctx.emit.is_valid():
		ctx.emit.call({"type": "regen", "target": holder, "hp": r.hpDamage, "animation": int(e.animation), "state": int(c.state_id)})


## Game_Battler.addState：isStateAddable（活着、未抵抗、本结果槽没刚去掉它）才加；已有的只续回合，都记入 addedStates
static func _add_state(b: XBattler, id: int, ctx: Dictionary) -> void:
	if b == null or not b.is_alive() or b.traits_set(XBattler.TRAIT_STATE_RESIST).has(id):
		return
	var rc = ctx.get("resources")
	if rc != null and rc.result(b).removedStates.has(id):
		return
	b.add_state(id, ctx.get("random"))
	if rc != null and not rc.result(b).addedStates.has(id):
		rc.result(b).addedStates.append(id)


## user.gainHp/Mp/Tp(式) 逐句：式子按持有者（a）算，经原生 gain（护盾、结果槽、refresh）。
## 战斗外层没有行动结果槽时每块用新的（Battle／Victory 脚本前原版结果槽为空）。
static func _gain_steps(e: Dictionary, holder: XBattler, c: Dictionary, ctx: Dictionary) -> void:
	var rc = ctx.get("resources")
	if rc == null:
		rc = XResourceContext.new()
		rc.random = ctx.get("random")
	for step in e.steps:
		var out := PhaseValueProgram.new().run_phase(step.program, c, 0.0, true)
		if not out.available:
			_diagnose(str(c.phase), int(c.state_id), holder, "gain_steps_unavailable")
			return
		rc.gain(holder, str(step.resource), float(out.value))


## JS「x || 默认」里 undefined／0／NaN 都算假
static func _truthy_number(v) -> float:
	if v == null:
		return 0.0
	var f := float(v)
	return 0.0 if is_nan(f) else f


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
	var origin: XBattler = holder
	var ref = holder.state_origins.get(state_id)
	if ref is WeakRef and ref.get_ref() != null:
		origin = ref.get_ref()
	var c := {"phase": phase, "state_id": state_id, "holder": holder, "origin": origin}
	if phase in ACTION_PHASES:
		c.merge({"attacker": ctx.get("attacker"), "defender": ctx.get("defender"), "item": ctx.get("item"),
			"user": ctx.get("attacker"), "target": ctx.get("defender")})
	else:
		c.merge({"user": holder, "target": holder})
	for key in ["item", "critical", "resources", "record", "random", "variables", "switches", "party_members", "forced_elements", "added_elements", "emit"]:
		if ctx.has(key):
			c[key] = ctx[key]
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
