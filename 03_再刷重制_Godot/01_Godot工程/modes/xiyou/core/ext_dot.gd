class_name XExtDot
extends RefCounted
## YEP_X_ExtDoT（持续伤害／再生）：回合结束 Game_Battler.regenerateAll 开头的 processDamageOverTimeStates。
## 状态备注 <DoT Formula: 式>／<Regen Formula: 式>／<Custom DoT／Regen Formula> 由转换器解析成状态记录的 `dot`
## （xiyou_export.parse_ext_dot）；这里按 dot_probe（oracle/dot.json）量到的原版次序执行：
## - 时机：持有者活着时，在 HP／MP／TP 再生（regenerateHp）与状态回合递减之前；每个带 dot 的状态按 states() 顺序各算一次
##   （名单在开头定下来：前一个状态把持有者打倒后，后面的仍然照算——倒下后挨扣、被再生拉起都发生）。
## - 数值：value = max(0, 式)，伤害取负、再生取正；波动 v = 随机(amp+1)+随机(amp+1)−amp（amp＝⌊|值|×波动%⌋，波动 0 不抽）；
##   元素非 0 再乘持有者对该元素的倍率；JS 的 Math.round（x+0.5 取整）；结果为 0 不动。
## - 公式里 a／origin＝状态施加者，b／user／target＝持有者；没有施加者记录（开战被动等）时 a＝持有者；记录存在但对象已不在＝公式报错，本状态本回合跳过。
## - 走资源上下文的 gainHp（护盾吸收、绑定、导入角色等都在那一层）；每次先清、后清结果槽，全部算完把原结果槽放回；
##   弹字与动画放进 regen 记录（hp＝结果槽 hpDamage，animation＝备注里的动画，没写按插件默认 59／46）。
## - 不做 maxSlipDamage（可以把持有者扣到 0，和 HP 再生率不同）；不播倒下（插件里 performCollapse 被注释掉），倒下由回合末结算统一演。
## 没做：2038 的自定义再生公式里「施加者是角色」的分支（原版读全局泄漏的 value，实测起点 0＝什么也不做）；NaN 结果（原版把角色扣到 0，数据里没有）。
static var diagnostics: Array = []  ## 测试用：[{state, holder, reason}]
## 测试接缝（生产里为空）：context＝Callable(context, a, b, state_id) 改公式读到的能力值；element_rate＝Callable(b, element) -> float
static var test_hooks := {}


static func tick(logic: XBattleLogic, b: XBattler, logs: Array) -> void:
	if not b.is_alive():
		return
	var rows := []
	for st in b.states():
		if st.has("dot"):
			rows.append(st)
	if rows.is_empty():
		return
	var resources: XResourceContext = logic._operation_resources(b)
	var saved := resources.result(b).duplicate(true)
	for st in rows:
		_one(logic, resources, b, st, logs)
	resources.seed_result(b, saved)
	logic._finish_lifecycle_operation(resources, b)


## 程序有没有读 a（状态施加者）：节点里 receiver 为 "a"。按程序摘要缓存。
static var _reads_origin_cache := {}
static func _reads_origin(program: Dictionary) -> bool:
	var key := str(program.get("source", {}).get("sha256", ""))
	if not _reads_origin_cache.has(key):
		_reads_origin_cache[key] = _mentions_a(program.get("steps", []))
	return _reads_origin_cache[key]


static func _mentions_a(node) -> bool:
	if node is Dictionary:
		if str(node.get("receiver", "")) == "a":
			return true
		for k in node:
			if _mentions_a(node[k]):
				return true
	elif node is Array:
		for child in node:
			if _mentions_a(child):
				return true
	return false


static func _diag(st: Dictionary, holder: XBattler, reason: String) -> void:
	diagnostics.append({"state": int(st.get("id", 0)), "holder": holder, "reason": reason})


static func _one(logic: XBattleLogic, rc: XResourceContext, b: XBattler, st: Dictionary, logs: Array) -> void:
	var d: Dictionary = st.dot
	var id := int(st.id)
	var kind := str(d.get("kind", ""))
	if kind == "unresolved":
		_diag(st, b, "dot_unresolved")
		return
	# 施加者：无记录＝持有者自己（stateOrigin 的兜底）；有记录但对象没了＝原版读属性报错，跳过
	var a: XBattler = b
	var origin_missing := false
	if b.state_origins.has(id):
		var w = b.state_origins[id]
		a = w.get_ref() if w is WeakRef else null
		origin_missing = a == null
		if origin_missing:
			a = b
	if origin_missing and (kind == "damagedot" or _reads_origin(d.get("program", {}))):
		_diag(st, b, "origin_missing")  # 原版：a 是 undefined，读属性报错，本状态跳过；公式不碰 a（常数）就照算
		return
	var value := 0.0
	if kind == "damagedot":
		# 2038：施加者是角色→原版取全局泄漏值，起点 0＝什么也不做；否则读持有者的 damagedot（Apply Effect 写入）
		if a is XActor or not b.state_data.has("damagedot"):
			if not a is XActor:
				_diag(st, b, "damagedot_unset")
			return
		value = maxf(0.0, float(b.state_data.damagedot))
	else:
		var program: Dictionary = d.program
		var context := XFormulaContext.capture(a, b, logic.vars(), {}, 0, program)
		if test_hooks.has("context"):
			test_hooks.context.call(context, a, b, id)
		var out := XFormulaProgram.evaluate(program, context, 1)
		if not out.available or str(out.get("sourceValueKind", "finite")) != "finite":
			_diag(st, b, "formula_unavailable" if not out.available else "formula_" + str(out.sourceValueKind))
			return
		value = float(out.value)
	var healing := bool(d.healing)
	value = value if healing else -value
	var variance := int(d.get("variance", 20))
	if variance != 0:
		value = _variance(logic, value, variance)
	var element := int(d.get("element", 0))
	if element != 0:
		value *= float(test_hooks.element_rate.call(b, element)) if test_hooks.has("element_rate") else b.element_rate(element)
	value = floorf(value + 0.5)  # Math.round
	if value == 0.0:
		return
	rc.seed_result(b, XResourceContext.empty_result())
	rc.gain(b, "hp", value)
	var r := rc.result(b)
	var entry := {"type": "regen", "target": b, "hp": float(r.hpDamage), "state": id, "views": logic.views([b])}
	var animation := int(d.get("animation", 0))
	if animation > 0:
		entry["animation"] = animation
	logs.append(entry)
	rc.seed_result(b, XResourceContext.empty_result())


## applyDamageOverTimeVariance：两次 Math.randomInt(amp+1) 相加再减 amp，符号随伤害方向
static func _variance(logic: XBattleLogic, damage: float, variance: int) -> float:
	var amp := floorf(maxf(absf(damage) * variance / 100.0, 0.0))
	var v := float(logic._mod(int(amp) + 1, "ext_dot_variance") + logic._mod(int(amp) + 1, "ext_dot_variance")) - amp
	return damage + v if damage >= 0.0 else damage - v
