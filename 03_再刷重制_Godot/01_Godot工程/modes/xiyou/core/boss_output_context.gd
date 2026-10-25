class_name XBossOutputContext
extends RefCounted
## 行动显式来源域；只在同一战斗的嵌套 resources 间共享，无静态／BattleManager 来源。
## 翻译宿主用诊断返回；with_action 恢复正常／受控返回，不承诺捕获 GDScript 致命错误。
var frames: Array = []
var settled: Array = []
var direct: Array = []

func enter_action(source: XBattler, target: XBattler) -> void:
	frames.append({"source": source, "target": target})

func leave_action() -> void:
	frames.pop_back()

func with_action(source: XBattler, target: XBattler, body: Callable):
	enter_action(source, target)
	var out = body.call()
	leave_action()
	return out

func is_empty() -> bool:
	return frames.is_empty() and settled.is_empty() and direct.is_empty()

func marked(list: Array, target: XBattler, kind: String) -> bool:
	return list.any(func(row): return row.target == target and row.kind == kind)

func is_settled(target: XBattler, kind: String) -> bool:
	return marked(settled, target, kind)

func enter_settled(target: XBattler, kind: String) -> void:
	settled.append({"target": target, "kind": kind})

func leave_settled() -> void:
	settled.pop_back()

func enter_direct(target: XBattler, kind: String) -> void:
	direct.append({"target": target, "kind": kind})

func leave_direct() -> void:
	direct.pop_back()

func loss_value(target: XBattler, kind: String, loss: float) -> float:
	if loss <= 0.0 or not kind in ["hp", "mp"] or frames.is_empty() or is_settled(target, kind) or marked(direct, target, kind):
		return loss
	var ctx: Dictionary = frames[-1]
	var source: XBattler = ctx.source
	if target == source or target != ctx.target or not source is XEnemy:
		return loss
	var rate: float = (source as XEnemy).boss_output_rate()
	return floorf(loss * rate) if rate > 1.0 else loss
