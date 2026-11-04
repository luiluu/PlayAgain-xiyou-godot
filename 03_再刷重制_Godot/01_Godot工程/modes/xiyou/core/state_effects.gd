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
	"reserve_common_event", "noop", "revive", "effect_program", "costume_image", "costume_restore"]
## 冻结版不触发的 phase：数据里有块但运行时从不调用
const NEVER_FIRED := {"action_end": "OTB 行动结束绕过 YEP_BuffsStatesCore 的 endAction 包装", "crit": "冻结版没有触发 crit 的插件"}
const DIAGNOSTIC_LIMIT := 500
const JS_TYPE_ERROR := "js_type_error"

## 测试观察者：每次某状态在某 phase 被分发时调用 (phase, state_id, holder, ctx)；ctx 是该状态这次调用的完整上下文
static var observer := Callable()
## 正在执行的上下文栈：每个状态每次调用压一层、返回后弹出（嵌套分发时外层上下文原样恢复，不用静态 acting 代替 user／origin）
static var _stack: Array = []
## 未翻译清单：{phase, state, holder, op}，同键只记一次
static var diagnostics: Array = []
static var _seen := {}
## $gameTemp.reserveCommonEvent 的编号（只存整数），由战斗逻辑在分发后 take_reserves 交给 XBattleCommonEvent.reserve
static var _reserves: Array[int] = []
## fix1：原版笔误的修正，默认开，设 false 回原版
## 优化 O-155：不灭之躯 2554 RemoveState 笔误，复活不消耗状态
static var FIX_UNDYING_2554 := true
## 优化 O-156：护体罡气 2562 MP 归零时移除的是 1662 不是自己
static var FIX_QI_GUARD_2562 := true
## 优化 O-157：永世乐土 1302 说明写每个队友减伤 4%（最高 13%），原版累进一个没人读的字段
static var FIX_ELYSIA_GUARD_1302 := true
## 优化 O-158：剑道争锋 2575 叠层增伤，原版累进一个没人读的字段
static var FIX_SWORD_2575 := true
## 优化 O-159：挨打反击 1072 isDamageAffected 不存在，永远不反击
static var FIX_SCALE_COUNTER_1072 := true
## 优化 O-160：金剪追加 1068 crit 阶段冻结版不触发，暴击不追加
static var FIX_SCISSORS_CRIT_1068 := true
## 优化 O-161：往世乐土 1301 说明写不会死亡并放一株莲，原版倒下后强制行动放不出来
static var FIX_ELYSIUM_1301 := true
## 优化 O-162：秩序 1711、同谐 1716 else if 从小到大写，人多的分支永远到不了
static var FIX_ORDER_TIERS := true
## 优化 O-163：戮仙印记 1067 加成写在不生效的 Custom Damage Formula 里
static var FIX_MARK_5576 := true
## 优化 O-164：鼬被动 1318 !v == 1 写法，改成本意 v != 1
static var FIX_ITACHI_1318 := true
## 优化 O-165：绯红之夜 1683 变量号超范围写不进，永远不触发
static var FIX_CRIMSON_1683 := true
## BattleManager.queueForceAction 的 339 参数，由战斗逻辑在事件阶段取走（take_forces）
static var _forces: Array = []
## 战斗双方（friendsUnit 用），XBattleLogic 开战时设
static var battle_units := {}
## YEP_X_CriticalControl 的 $gameSystem._forceCritical（必爆 541、755）；force_previous 是 Game_Action._prevForcedCriticalHit，每次 apply 清
static var force_critical := false
static var force_previous = null


## Private value-only adapter: current signed phase input, without the damage
## entry's zero initial value, nonnegative clamp or healing sign conversion.
class PhaseValueProgram:
	extends XFormulaProgram
	var _battlers := {}
	var _random: XRandomStream
	var _tag := ""

	func run_phase(program: Dictionary, ctx: Dictionary, value: float, execute: bool, extra := {}) -> Dictionary:
		if program.get("version") != 1 or not (program.get("status") == "pure" or (program.get("status") == "effectful" and not effects.is_empty())):
			return {"available": false, "value": value}
		var a: XBattler = ctx.user if execute else XFormulaContext.clone_battler(ctx.user)
		var b: XBattler = a if ctx.user == ctx.target else (ctx.target if execute else XFormulaContext.clone_battler(ctx.target))
		if a == null or b == null:
			return {"available": false, "value": value}
		_battlers = {"a": a, "b": b}
		_battlers.merge(effects.get("battlers", {}), true)
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
		if node.get("op") == "phase_call":
			return _phase_call(node)
		var value = super._expr(node)
		# These measured blocks use Game_Variables.value(), whose missing value is 0.
		# Keep the general formula VM's raw v[index]/undefined behavior unchanged.
		if node.get("op") == "lookup" and node.get("pool") == "v" and value is StringName and value == UNDEFINED:
			return 0.0
		return value

	## 状态块 effect_program（rules4）：副作用只在 execute 时做，经行动资源上下文（结果槽、护盾、死亡结算）；预览只算 value。
	var effects := {}

	func _step(n: Dictionary) -> void:
		if n.get("op") == "members_loop":
			for member in XStateEffects._alive_friends(_battlers[n.receiver]):
				if not _error.is_empty():
					break
				_battlers["t"] = member
				_step(n.body)
			return
		if n.get("op") != "loop":
			super._step(n)
			return
		var name := str(n.name)
		while _error.is_empty() and _number(_locals[name]) <= _number(_expr(n.limit)):
			_step(n.body)
			_locals[name] = _number(_locals[name]) + 1.0

	func _gain(receiver: String, resource: String, amount: float):
		if effects.get("execute", false):
			(effects.resources as XResourceContext).gain(_battlers[receiver], resource, amount)
		return UNDEFINED

	func _phase_call(n: Dictionary):
		var b: XBattler = _battlers[n.receiver]
		var args: Array = n.args.map(func(a): return _expr(a))
		if not _error.is_empty():
			return UNDEFINED
		match str(n.name):
			"is_dead":
				return b.is_dead()
			"is_alive":
				return b.is_alive()
			"is_actor":
				return b is XActor
			"is_battle_member":
				return not b is XActor or XStateEffects.battle_units.get("actors", []).has(b)
			"alive_friends":
				return float(XStateEffects._alive_friends(b).size())
			"death_state_id":
				return 1.0
			"state_rate":
				return 1.0 if XAlienBattle.forced_state(b, int(_number(args[0]))) else b.traits_pi(XBattler.TRAIT_STATE_RATE, int(_number(args[0])))
			"state_resist":
				return b.traits_set(XBattler.TRAIT_STATE_RESIST).has(int(_number(args[0])))
			"troop_size":
				return float(XStateEffects.battle_units.get("enemies", []).size())
			"enemies_alive":
				return XStateEffects.battle_units.get("enemies", []).any(XStateEffects._counts_alive)
			"not_origin":
				return b != effects.context.origin
			"first_weapon_type":
				return float(b.first_weapon_type()) if b is XActor else 0.0
			"has_skill":
				if not b is XActor:
					return _fail(JS_TYPE_ERROR)  # 敌人没有 hasSkill：TypeError，eval 外层接住
				return b.skills().any(func(sk): return int(sk.id if sk is Dictionary else sk) == int(_number(args[0])))
		if n.name == "throw":
			return _fail(JS_TYPE_ERROR)  # target.RemoveState 原版没有这个方法：TypeError，eval 外层接住，前面做过的留着、value 照常返回
		if not effects.get("execute", false):
			return UNDEFINED
		var resources: XResourceContext = effects.resources
		match str(n.name):
			"popup":
				resources.start_damage_popup(b)
				XStateEffects._emit_result(b, resources, effects.context)
			"clear_result":
				resources.seed_result(b, XResourceContext.empty_result())
			"remove_state":
				resources.remove_state(b, int(_number(args[0])))
			"set_variable":
				if XState.current != null and XStateEffects._variable_writable(int(_number(args[0]))):
					XState.current.set_variable(int(_number(args[0])), _number(args[1]))
			"add_state":
				XStateEffects._add_state(b, int(_number(args[0])), effects.context)
			"animation":
				XStateEffects._note_anim(int(_number(args[0])), b, effects.context)
			"reserve":
				XStateEffects._reserves.append(int(_number(args[0])))
			"gain_gold":
				if XState.current != null:
					XState.current.gain_gold(int(_number(args[0])))
			"set_tp":
				resources.set_resource(b, "tp", _number(args[0]))
			"add_param":
				b.add_param(int(_number(args[0])), _number(args[1]))
				resources.refresh(b)
			"force_critical_on":
				XStateEffects.force_previous = XStateEffects.force_critical
				XStateEffects.force_critical = true
			"force_critical_restore":
				if XStateEffects.force_previous != null:
					XStateEffects.force_critical = XStateEffects.force_previous
			"set_hp":
				resources.set_resource(b, "hp", _number(args[0]))
			"queue_counter":
				var foe: XBattler = effects.context.user
				XStateEffects.queue_force_quiet(b, int(_number(args[0])), XStateEffects._unit_of(foe).find(foe))
			"queue_force_quiet":
				XStateEffects.queue_force_quiet(b, int(_number(args[0])), int(_number(args[1])))
			"queue_force":
				XStateEffects.queue_force(b, int(_number(args[0])), int(_number(args[1])), resources)
			"set_counter":
				XStateEffects._set_counter(b, int(_number(args[0])), _number(args[1]))
			"add_actor_counter_level":
				XStateEffects._add_actor_counter_level(int(_number(args[0])), int(_number(args[1])))
			"collapse":
				pass  # performCollapse 只放倒下动画和音效：战斗场景看到死亡状态自己播
			_:
				return _fail("unknown_phase_call")
		return UNDEFINED

	func _property(receiver: String, name: String):
		return _battlers[receiver].get(name) if name in XFormulaContext.PROPERTIES.split(" ") else _fail("unknown_property")

	func _read(node: Dictionary):
		var b: XBattler = _battlers[node.receiver]
		match str(node.name):
			"states_count": return b.states().size()
			"hp_rate": return _divide(b.hp, b.mhp)
			"element": return b.element_rate(int(_number(_expr(node.args[0]))))
			"has_state": return b.is_state_affected(int(_number(_expr(node.args[0]))))
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
	var owns_resources := execute and resources == null and effects.any(func(e): return e.get("op") in ["poison_tick", "gain_steps", "add_state", "effect_program"])
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
	for raw in effects:
		var e: Dictionary = raw
		if e.has("fix") and fix_on(str(e.fix)):
			e = {"phase": e.phase, "op": "effect_program", "program": e.fixed}
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
		elif op == "costume_image" and execute:
			_costume_image(e, int(st.id), holder)
		elif op == "costume_restore" and execute:
			_costume_restore(int(st.id), holder)
		elif op == "effect_program":
			c.value = _effect_program(e, phase, int(st.id), holder, c, execute)
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
			pass  # 只写没人读的字段（user._bubbleWrapCooldown、_zuizhongshanghai、jqsbt）：冻结源 js 里没有任何地方读它们
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


## 伤害 react／confirm 一族（rules4）：整块小程序。字段 target._xmx 等读进局部量、跑完写回；origin.属性块开头读好。
static func _effect_program(e: Dictionary, phase: String, _state_id: int, holder: XBattler, c: Dictionary, execute: bool) -> float:
	var vm := PhaseValueProgram.new()
	vm.effects = {"execute": execute, "resources": c.get("resources"), "context": c}
	vm.effects.battlers = {"o": c.origin}
	var regenerating: bool = phase == "regenerate" and execute
	if regenerating:
		(c.resources as XResourceContext).seed_result(holder, XResourceContext.empty_result())  # regenerateStateEffects 每个状态先 clearResult
	var extra := {}
	var receivers := {"a": c.user, "b": c.target}
	for local in e.program.locals:
		var name := str(local)
		if name.begins_with("f_"):
			extra[name] = _field_read(receivers[name[2]], name.substr(4))
		elif name.begins_with("o_"):
			extra[name] = float(c.origin.get(name.substr(2)))
		elif name == "se_state_id":
			extra[name] = float(_state_id)
		elif name == "se_attack":
			extra[name] = c.user.is_attack(c.get("item", {}))
		elif name == "se_can_crit":
			extra[name] = bool(c.get("item", {}).get("damage", {}).get("critical", false))
	var out := vm.run_phase(e.program, c, c.value, execute, extra)
	if regenerating:
		_emit_result(holder, c.resources, c)  # 块后外层 startDamagePopup，这才是目标掉血的弹字
		(c.resources as XResourceContext).seed_result(holder, XResourceContext.empty_result())
	if execute:
		for name in extra:
			if str(name).begins_with("f_"):
				_field_write(receivers[str(name)[2]], str(name).substr(4), vm._locals[name])
	if out.available or out.get("diagnostic") == JS_TYPE_ERROR:
		return out.value
	if execute:
		_diagnose(phase, _state_id, holder, "effect_program_unavailable")
	return c.value


static func _alive_friends(b: XBattler) -> Array:
	var unit: Array = battle_units.get("actors" if b is XActor else "enemies", [])
	return unit.filter(_counts_alive)


## Game_Battler.isAlive：isAppeared 且血不为 0；还没出现的隐藏敌人不算
static func _counts_alive(m: XBattler) -> bool:
	return m.is_alive() and not (m is XEnemy and (m as XEnemy).hidden)


## 回合、再生这些阶段没有命中记录：弹字走 ctx.emit 进战斗记录
static func _emit_result(b: XBattler, resources: XResourceContext, c: Dictionary) -> void:
	if c.get("emit") is Callable and c.emit.is_valid():
		var r := resources.result(b)
		c.emit.call({"type": "regen", "target": b, "hp": r.hpDamage if r.hpAffected else 0.0, "mp": r.mpDamage, "state": int(c.get("state_id", 0))})


static func _unit_of(b: XBattler) -> Array:
	return battle_units.get("actors" if b is XActor else "enemies", [])


## 修正版的强制行动：只排队，不像 queueForceAction 那样清所有结果（这一击的数字要留着）
static func queue_force_quiet(b: XBattler, skill: int, target_index: int) -> void:
	_forces.append([1 if b is XActor else 0, b.actor_id if b is XActor else _unit_of(b).find(b), skill, target_index])


static func fix_on(name: String) -> bool:
	match name:
		"FIX_UNDYING_2554": return FIX_UNDYING_2554
		"FIX_QI_GUARD_2562": return FIX_QI_GUARD_2562
		"FIX_ELYSIA_GUARD_1302": return FIX_ELYSIA_GUARD_1302
		"FIX_SWORD_2575": return FIX_SWORD_2575
		"FIX_SCALE_COUNTER_1072": return FIX_SCALE_COUNTER_1072
		"FIX_ELYSIUM_1301": return FIX_ELYSIUM_1301
		"FIX_ORDER_TIERS": return FIX_ORDER_TIERS
		"FIX_ITACHI_1318": return FIX_ITACHI_1318
	return false


## 换装（setBattlerImage）：只有角色有；换装卡状态由 XCostumes 管，不走这里。_prevBattlerName 已有就不盖，所以同时两个时记的是最初的图。
static func _costume_image(e: Dictionary, state_id: int, holder: XBattler) -> void:
	if not holder is XActor or XCostumes.registry().has(state_id):
		return
	var a := holder as XActor
	if str(a.state_data.get("_prevBattlerName", "")) == "":
		a.state_data["_prevBattlerName"] = str(a.data().get("battlerName", ""))
	a.set_looks({"battlerName": str(e.image)})


## 敌人没有 setBattlerImage（TypeError，什么都不做）。没有记过旧图时原版把图设成 undefined 显示不出来，这里保留现状。
static func _costume_restore(state_id: int, holder: XBattler) -> void:
	if not holder is XActor or XCostumes.registry().has(state_id):
		return
	var a := holder as XActor
	var prev := str(a.state_data.get("_prevBattlerName", ""))
	if prev != "":
		a.set_looks({"battlerName": prev})
	a.state_data.erase("_prevBattlerName")


## BattleManager.queueForceAction：排进预约（$gameTemp.forceActionQueue，事件阶段跑 339，那时倒下了就不行动），并 clearResults 清所有战斗成员的结果槽。
static func queue_force(b: XBattler, skill: int, target_index: int, resources: XResourceContext) -> void:
	var unit: Array = battle_units.get("actors" if b is XActor else "enemies", [])
	_forces.append([1 if b is XActor else 0, b.actor_id if b is XActor else unit.find(b), skill, target_index])
	for side in ["actors", "enemies"]:
		for m in battle_units.get(side, []):
			resources.seed_result(m, XResourceContext.empty_result())


static func take_forces() -> Array:
	var out := _forces.duplicate()
	_forces.clear()
	return out


static func _set_counter(b: XBattler, state_id: int, value: float) -> void:
	var counters: Dictionary = b.state_data.get("_stateCounter", {})
	counters[str(state_id)] = value
	b.state_data["_stateCounter"] = counters


## $gameActors.actor(n)._stateCounter[s] += 等级。没计数时原版得 NaN，读的地方（paramState）当 0，这里不写 NaN（进存档会坏），留着没有。
static func _add_actor_counter_level(actor_id: int, state_id: int) -> void:
	if XState.current == null:
		return
	var a: XActor = XState.current.actor(actor_id)
	var counters: Dictionary = a.state_data.get("_stateCounter", {})
	if counters.has(str(state_id)):
		counters[str(state_id)] = float(counters[str(state_id)]) + float(a.level)


## _Shield、_xmx 只有这些块自己读写（不是护盾系统的护盾），记在 state_data；没写过时 undefined，回写时跳过。
static func _field_read(b: XBattler, field: String):
	return b.state_data.get("_" + field, XFormulaProgram.UNDEFINED)


static func _field_write(b: XBattler, field: String, value) -> void:
	if not value is StringName:
		b.state_data["_" + field] = value


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
	elif c.get("emit") is Callable and c.emit.is_valid():
		c.emit.call({"type": "regen", "target": holder, "hp": 0.0, "animation": animation, "state": int(c.get("state_id", 0))})  # 再生、回合阶段没有命中记录


## Game_Variables.setValue：编号不在 1..System.variables 长度-1 内的写入原版直接忽略（如 1683 号脚本）
static func _variable_writable(id: int) -> bool:
	return (id > 0 and id < XDB.system().get("variables", []).size()) or (id == 1683 and FIX_CRIMSON_1683)


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
