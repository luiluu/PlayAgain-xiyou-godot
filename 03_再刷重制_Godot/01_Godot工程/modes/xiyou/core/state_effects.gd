class_name XStateEffects
extends RefCounted
## YEP/BSC phase dispatcher. KRZ cached lists and direct lifecycle slots share
## one execution path, including native-measured constant bonus steps.
## JS remains diagnostic-only. OTB action_end and unknown crit stay unfired.

const BATTLER_PHASES := ["battle", "turn_start", "turn_end", "regenerate", "action_start", "victory", "escape", "defeat"]
const ACTION_PHASES := ["initiate", "select", "deselect", "conclude", "confirm", "react", "respond", "establish"]
## 原来分散在 damage.gd 与 battle_logic.gd 的两个 op，统一在本类执行。
const SUPPORTED_OPS := ["mul", "user_param_damage", "value_steps", "value_program", "value_query", "gain_resource", "param_add",
	"poison_stack", "poison_tick", "add_state", "gain_steps", "set_variable", "syntax_error", "counter_init", "counter_set",
	"reserve_common_event", "noop", "revive"]
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
## $gameTemp.reserveCommonEvent 的编号（只存整数），由战斗逻辑在分发后 take_reserves 交给 XBattleCommonEvent.reserve
static var _reserves: Array[int] = []


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
	var owns_resources := execute and resources == null and effects.any(func(e): return e.get("op") in ["poison_tick", "gain_steps", "add_state"])
	if owns_resources:
		resources = XResourceContext.new()
		resources.random = c.get("random")
		for key in ["variables", "switches", "party_members", "emit"]:
			if c.has(key):
				resources.lifecycle_inputs[key] = c[key]
		resources.seed_result(holder, holder.runtime_result)
		c.resources = resources
	var special_react := phase == "react" and int(st.id) in [1341, 2550]
	var origin_domain := execute and resources != null and (not phase in ACTION_PHASES or special_react)
	if origin_domain:
		var source: XBattler = holder if special_react and int(st.id) == 2550 else c.origin
		var victim: XBattler = (c.user if int(st.id) == 2550 else c.target) if special_react else holder
		resources.boss_output.enter_action(source, victim)
	_stack.push_back(c)
	var alien_frame := execute and XAlienBattle.status_battle()
	if alien_frame:
		XAlienBattle.push_action(c.origin, {})  # 异化 customEffectEval 包装：来源是状态来源的帧（逆祷阻断其中对敌人的扣血）
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
			# 护盾一族：HP 伤害>0 就破盾（先判，清零后 value 已是 0）；元素只决定这一击挡不挡
			var breaks: bool = e.get("remove_self", false) and _active({"cond": "positive", "hpOnly": true}, c)
			c.value = _query_value(e, c, execute)
			if breaks and execute:
				_break_shield(e, holder, int(st.id), c)
		elif op == "param_add" and execute:
			_add_params(e, c)
		elif op == "gain_resource" and execute:
			if resources == null:
				_diagnose(phase, int(st.id), holder, "resource_context_missing")
			else:
				resources.gain(c.user, str(e.resource), float(e.amount))
				if not resources.error.is_empty():
					_diagnose(phase, int(st.id), holder, resources.error)
		elif op == "poison_stack" and execute:
			# Apply：x = x || 0; x += n。Remove：x = 0。层数挂在持有者身上，所有叠毒状态共用
			holder.state_data["_stackingPoison"] = (_truthy_number(holder.state_data.get("_stackingPoison")) + float(e.n)) if e.mode == "add" else 0.0
		elif op == "poison_tick" and execute:
			_poison_tick(e, holder, c, c)
		elif op == "add_state" and execute:
			# 暴击后加状态（Establish）：只看这个目标的结果槽 critical；addState 的回合参数原版不认
			if not e.get("criticalOnly", false) or c.get("critical", false):
				_add_state(c.get(str(e.who)), int(e.id), c)
		elif op == "gain_steps" and execute:
			_gain_steps(e, holder, c, c)
		elif op == "reserve_common_event" and execute:
			_reserves.append(int(e.id))
		elif op == "set_variable" and execute:
			var vid := int(e.id)
			if XState.current != null and _variable_writable(vid):
				XState.current.set_variable(vid, float(e.value))
		elif op == "counter_init" and execute:
			# 计数 = 计数 || $gameVariables.value(V)：已有的（移除后也留着）不改
			var counters: Dictionary = c.user.state_data.get("_stateCounter", {})
			if _truthy_number(counters.get(str(int(e.state)))) == 0.0:
				counters[str(int(e.state))] = XState.current.variable(int(e.variable)) if XState.current != null else 0.0
			c.user.state_data["_stateCounter"] = counters
		elif op == "counter_set" and execute:
			var out := PhaseValueProgram.new().run_phase(e.program, c, 0.0, true)
			if out.available:
				var counters: Dictionary = c.user.state_data.get("_stateCounter", {})
				counters[str(int(e.state))] = out.value
				c.user.state_data["_stateCounter"] = counters
			else:
				_diagnose(phase, int(st.id), holder, "counter_set_unavailable")
		elif op == "revive":
			if execute:
				_revive(e, holder, int(st.id), c)
		elif op == "syntax_error":
			pass  # 原版这块解析失败（SyntaxError），customEffectEval 只报错，什么都不改
		elif op == "noop":
			pass  # 护盾 Remove 的 user._bubbleWrapCooldown = 3：冻结源 js 里没有任何地方读这个字段
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
	if alien_frame:
		XAlienBattle.pop_action()
	_stack.pop_back()
	if origin_domain:
		resources.boss_output.leave_action()
	if owns_resources:
		resources.publish()
	return c.value


## 自动复活一族（rules3，state_effects_probe revive.blocks）：Deselect 块的条件＋按原顺序的几步。
## 没 clearResult 的块（1164、1837）结果槽留着这次回血与状态变化；clearResult 的先弹字再清，这一击不显示、不算击杀（见 XBattleLogic.apply）。
static func _revive(e: Dictionary, holder: XBattler, state_id: int, c: Dictionary) -> void:
	var t: XBattler = c.target
	if not _revive_cond(e.cond, t, c):
		return
	var resources: XResourceContext = c.resources
	for step in e.steps:
		match str(step.do):
			"animation":
				_note_anim(int(step.id), holder, c)
			"remove_self":
				resources.remove_state(t, state_id)
			"remove_state":
				resources.remove_state(t, int(step.id))
			"add_state":
				_add_state(t, int(step.id), c)
			"gain":
				resources.gain(t, str(step.resource), _revive_amount(step, t))
			"popup":
				resources.start_damage_popup(t)
			"clear_result":
				resources.seed_result(t, XResourceContext.empty_result())
			"add_variable":
				if XState.current != null and _variable_writable(int(step.id)):
					XState.current.set_variable(int(step.id), XState.current.variable(int(step.id)) + float(step.delta))


## 条件按原文短路：抽几次随机数与原版相同（down_each 真实倒下时最多抽两次）。
static func _revive_cond(cond: Dictionary, t: XBattler, c: Dictionary) -> bool:
	var random: XRandomStream = c.get("random")
	match str(cond.kind):
		"down":
			if not (t.hp <= 0.0 or t.is_dead()):
				return false
			return not cond.has("below") or (random != null and random.next_float("state_effect", "revive") < float(cond.below))
		"down_each":
			if random == null:
				return false
			if t.hp <= 0.0 and random.next_float("state_effect", "revive") > float(cond.above):
				return true
			return t.is_dead() and random.next_float("state_effect", "revive") > float(cond.above)
		"hp_zero_variable":
			return t.hp <= 0.0 and XState.current != null and XState.current.variable(int(cond.variable)) > float(cond.above)
	return false


static func _revive_amount(step: Dictionary, t: XBattler) -> float:
	if step.has("amount"):
		return float(step.amount)
	var value := float(t.get(str(step.param))) * float(step.rate)
	match str(step.get("round", "")):
		"floor":
			return floorf(value)
		"ceil":
			return ceilf(value)
	return value


## target.startAnimation：记进命中记录 state_anims [[动画, 持有者]]，由 battle_scene 在本次弹字前播。
static func _note_anim(animation: int, holder: XBattler, c: Dictionary) -> void:
	var record = c.get("record")
	if record is Dictionary:
		record["state_anims"] = record.get("state_anims", []) + [[animation, holder]]


## Game_Variables.setValue：编号不在 1..System.variables 长度-1 内的写入原版直接忽略（如 1683 号脚本）
static func _variable_writable(id: int) -> bool:
	return id > 0 and id < XDB.system().get("variables", []).size()


## 护盾 React 后半段：target.startAnimation(动画)＋target.removeState(stateId)。动画记进命中记录 state_anims
## [[动画, 持有者]]，由 battle_scene 在本次弹字前播；移除走行动的资源上下文（removedStates 进结果槽，Remove 块随之触发）。
static func _break_shield(e: Dictionary, holder: XBattler, state_id: int, c: Dictionary) -> void:
	_note_anim(int(e.animation), holder, c)
	var resources: XResourceContext = c.get("resources")
	if resources != null:
		resources.remove_state(holder, state_id)
	else:
		holder.remove_state(state_id)


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
	var rc: XResourceContext = ctx.resources
	# regenerateStateEffects clears this holder's result, while retaining the source domain.
	rc.seed_result(holder, XResourceContext.empty_result())
	rc.gain(holder, "hp", -float(out.value))
	var r := rc.result(holder)
	if ctx.get("emit") is Callable and ctx.emit.is_valid():
		ctx.emit.call({"type": "regen", "target": holder, "hp": r.hpDamage, "animation": int(e.animation), "state": int(c.state_id)})
	# The translated original460-style block calls clearResult after its popup.
	rc.seed_result(holder, XResourceContext.empty_result())


## Game_Battler.addState：isStateAddable（活着、未抵抗、本结果槽没刚去掉它）才加；已有的只续回合，都记入 addedStates
static func _add_state(b: XBattler, id: int, ctx: Dictionary) -> void:
	var rc: XResourceContext = ctx.resources
	rc.add_state(b, id, ctx)


## user.gainHp/Mp/Tp(式) 逐句：式子按持有者（a）算，经原生 gain（护盾、结果槽、refresh）。
## 战斗外层没有行动结果槽时每块用新的（Battle／Victory 脚本前原版结果槽为空）。
static func _gain_steps(e: Dictionary, holder: XBattler, c: Dictionary, ctx: Dictionary) -> void:
	var rc: XResourceContext = ctx.resources
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
	for key in ["item", "critical", "resources", "record", "random", "variables", "switches", "party_members", "forced_elements", "added_elements", "emit"]:
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


## 取走分发期间预约的公共事件（原版 $gameTemp 单槽，按次序交给 XBattleCommonEvent.reserve，后一个盖前一个）
static func take_reserves() -> Array[int]:
	var out := _reserves.duplicate()
	_reserves.clear()
	return out
