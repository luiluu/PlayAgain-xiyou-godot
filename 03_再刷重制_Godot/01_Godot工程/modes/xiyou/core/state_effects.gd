class_name XStateEffects
extends RefCounted
## 状态效果阶段钩子（YEP_BuffsStatesCore 的 Custom X Effect）第一期：战斗边界的统一分发与诊断，不执行新翻译。
## 依据沙僧核查报告（2026-10-21 状态效果提案，结论「需改」）收窄后的第一期，冻结版最后生效链由 state_effects_probe 实测：
## - battle：BattleManager.startBattle → 我方（含后备）再敌方，逐成员；在 dsPassiveSkill 开战标签加状态之前（新加的状态不跑本次 battle）。
## - turn_start：Game_Battler.onTurnStart 内，Unit.refresh（KRZ 消费 dirty）之前。
## - regenerate → turn_end：onTurnEnd 内依次；倒下的也跑（regenerateAll 外层不看存活）。
## - action_start：BattleManager.startAction 之前（防御、强制行动都算）。
## - action_end：OTB 的行动结束绕过 YEP 包装，冻结版不触发（参照 action.* 例），这里不分发，只登记。
## - initiate → select →（原 apply）→ deselect → conclude：每个目标一次 apply；未命中也四段齐全；反射时目标是行动者自己，反击时行动者是反击方。
## - victory／escape／defeat：只对我方（含后备），在原 endBattle 之前。
## 两套上下文：Battler 版（battle、回合、再生、action_start、胜逃败）a＝user＝target＝持有者；Action 版（initiate／select／
## deselect／conclude）a＝user＝行动者、b＝target＝目标、origin 取持有者身上的来源。
## 第一期只分发与诊断：js 记进未翻译清单（不静默跳过）；confirm／react／respond／establish 与 apply／remove／leave 不在本期
## （现有 mul 与 user_param_damage 执行点不动，不双跑）；crit 冻结版无触发插件，不接。
## FIX（_Fix_StackOverflow）的重复施加只续回合、加状态期间再次 addState 被全局锁拒绝：属 apply 生命周期，第二期接 apply 时照它，
## 这里不做递归层数或重复 apply（XBattler.add_state 已有状态只续回合，与 FIX 一致）。
## 未做（停在设计，见交付单）：KRZ typestates 热缓存（同一回合内加状态不 refresh 时仍按旧列表，回合末到期移除后再生／回合结束
## 仍对它触发）要所有战斗者的 dirty 跟踪，在 battler.gd；导出时畸形结束标签漏掉的 13 个状态在转换器。

const BATTLER_PHASES := ["battle", "turn_start", "turn_end", "regenerate", "action_start", "victory", "escape", "defeat"]
const ACTION_PHASES := ["initiate", "select", "deselect", "conclude"]
## 已有执行点的 op（第一期不在这里执行，也不算未翻译）
const HANDLED_ELSEWHERE := ["mul", "user_param_damage"]
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
static func run(phase: String, holder: XBattler, ctx := {}) -> void:
	if holder == null:
		return
	for st in holder.states().duplicate():
		var effs: Array = st.get("effects", []).filter(func(e): return str(e.get("phase", "")) == phase)
		if effs.is_empty():
			continue
		var c := context_for(phase, holder, int(st.id), ctx)
		_stack.push_back(c)
		if observer.is_valid():
			observer.call(phase, int(st.id), holder, c)
		for e in effs:
			var op := str(e.get("op", ""))
			if not HANDLED_ELSEWHERE.has(op):
				_diagnose(phase, int(st.id), holder, op)
		_stack.pop_back()


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
