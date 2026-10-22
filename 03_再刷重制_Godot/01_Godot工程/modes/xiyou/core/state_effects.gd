class_name XStateEffects
extends RefCounted
## YEP/BSC phase dispatcher. KRZ cached lists and direct lifecycle slots share
## one execution path, including native-measured constant bonus steps.
## JS remains diagnostic-only. OTB action_end and unknown crit stay unfired.

const BATTLER_PHASES := ["battle", "turn_start", "turn_end", "regenerate", "action_start", "victory", "escape", "defeat"]
const ACTION_PHASES := ["initiate", "select", "deselect", "conclude", "confirm", "react", "respond", "establish"]
## 原来分散在 damage.gd 与 battle_logic.gd 的两个 op，统一在本类执行。
const SUPPORTED_OPS := ["mul", "user_param_damage", "value_steps"]
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
	for key in ["item", "critical", "resources", "record", "random", "variables", "switches"]:
		if ctx.has(key):
			c[key] = ctx[key]
	return c


## 当前正在执行的上下文（栈顶）；不在分发中时为空字典
static func current() -> Dictionary:
	return _stack.back() if not _stack.is_empty() else {}


## 一个单位（我方含后备或敌群）逐成员分发 Battler 版 phase
static func run_unit(phase: String, members: Array) -> void:
	for b in members:
		run(phase, b)


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
