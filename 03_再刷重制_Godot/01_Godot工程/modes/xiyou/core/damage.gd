class_name XDamage
extends RefCounted
## 伤害结算：移植自正式版 js/codex/runtime/installDamageElementRuntime.js v3（CodexDamage.calculate）。
## 首期精简：
## - 成长修正 growth 固定为 1（正式版的「五乘区预算软上限」/真气钩子未移植，见首期规格）。
## - 模块数值经 XModuleRegistry 的 damage.before；现有 orb-sets 仅走注册表。
## - 其余专属模块保持 pending，测试注入表不代表开放角色。damage.after 尚无资源提交宿主。
## - 混合模式（spec.mode == "mixed"）的物理/魔法权重按公式对 atk/mat 的偏导数估算，与原版相同。

const ACTIVE := [2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15]
static var _formulas := {}


static func elements_data() -> Dictionary:
	var d = XDB.table("CodexDamageElements")
	return d if d is Dictionary else {"names": [], "affinities": {"actors": {}, "enemies": {}}, "edges": [], "skills": {}}


# ---- Structured formula entry; previews never own live mutation capabilities. ----
static func eval_formula(item: Dictionary, a: XBattler, b: XBattler, vars: Array) -> float:
	var program: Dictionary = item.damage.get("formulaProgram", {})
	if program.get("status") == "pure":
		return XImportedBalance.formula_value(XFormulaProgram.evaluate(program, XFormulaContext.capture(a, b, vars, {}, int(item.id), program), int(item.damage.type)).value, a, item)
	var out := XFormulaExecution.run_item(item, a, b, vars)  # run_item 里已按导入效果平衡缩放
	return float(out.value)


static func is_physical(item: Dictionary) -> bool:
	return int(item.get("hitType", 0)) == 1

static func is_magical(item: Dictionary) -> bool:
	return int(item.get("hitType", 0)) == 2


# ---- 元素 ----
static func affinity(b: XBattler) -> Array:
	var aff: Dictionary = elements_data().affinities
	var ids = null
	if b is XActor:
		ids = aff.actors.get(str((b as XActor).actor_id))
	elif b is XEnemy:
		ids = aff.enemies.get(str((b as XEnemy).enemy_id))
	var out := []
	for e in (ids if ids is Array else []):
		if ACTIVE.has(int(e)) and not out.has(int(e)):
			out.append(int(e))
	return out.slice(0, 2)

static func matchup(element: int, body: Array) -> float:
	if not ACTIVE.has(element) or body.is_empty():
		return 1.0
	var edges: Array = elements_data().edges
	var product := 1.0
	for e in body:
		var forward := edges.any(func(p): return int(p[0]) == element and int(p[1]) == e)
		var backward := edges.any(func(p): return int(p[0]) == e and int(p[1]) == element)
		product *= 1.5 if forward else (0.75 if backward else 1.0)
	return pow(product, 1.0 / body.size())

static func action_elements(item: Dictionary, a: XBattler) -> Array:
	# installDamageElementRuntime：先取被动缓存的属性覆盖（dsPassiveSkill <DamageElements>），没有才用技能自带属性
	var id := int(a.passive_cache().get("damageElement", 0))
	if id == 0:
		id = int(item.damage.elementId)
	var es: Array = a.attack_elements() if id < 0 else ([id] if id > 0 else [])
	es = es.duplicate()
	es.append_array(item.get("yep", {}).get("multipleElements", []))
	var out := []
	for e in es:
		if int(e) >= 1 and int(e) <= 15 and not out.has(int(e)):
			out.append(int(e))
	return out

## 战斗者相关的全部对象：特性对象＋技能（角色已学、敌人行动表）
static func objects(b: XBattler) -> Array:
	var out := []
	for o in b.trait_objects() + b.skills():
		if not out.has(o):
			out.append(o)
	return out

static func _sum_yep(b: XBattler, field: String, e: int, objs: Array) -> float:
	var v := 0.0
	for o in objs:
		v += float(o.get("yep", {}).get(field, {}).get(str(e), 0.0))
	return v

## YEP_ElementCore：增幅来自状态；角色另加装备、角色、职业。
static func _yep_objects(b: XBattler) -> Array:
	var objs := b.states()
	if b is XActor:
		var x := b as XActor
		# The actor lane supplies stat_equips for scoped weapon views (178).
		# Before that lane is merged, the legacy actor exposes only equip_list.
		var equips: Array = x.call("stat_equips") if x.has_method("stat_equips") else x.equip_list()
		objs = objs + equips + [x.data(), x.class_data()]
	return objs

static func own_bonus(a: XBattler, e: int) -> float:
	var objs := _yep_objects(a)
	var value: float = _sum_yep(a, "elementAmplify", e, objs)
	if a.is_actor():
		for m in a.passive_values("passiveELUP%02d" % e):
			value += XActor._num(m) / 100.0
	elif a is XEnemy:
		# 敌人没有 iteratePassiveSkill（dsPassiveSkill 只挂 Game_Actor）：原版 ownBonus 扫状态、敌人本身与行动表技能的备注（如 932 草中炎的 428「火焰增幅」）
		var seen := {}
		for o in a.states() + [(a as XEnemy).data()] + (a as XEnemy).skills():
			if seen.has(o):
				continue
			seen[o] = true
			var m = o.get("meta", {}).get("passiveELUP%02d" % e)
			if m != null:
				value += XActor._num(m) / 100.0
	return value + (1.0 + _sum_yep(a, "elementMagnify", e, objs)) - 1.0

## 虚空～风（11–15）：取 max(自身, 火～暗中最低的一项)
static func element_bonus(a: XBattler, e: int) -> float:
	var own := own_bonus(a, e)
	if e >= 11 and e <= 15:
		var common := INF
		for c in [2, 3, 4, 5, 6, 7, 8, 9]:
			common = minf(common, own_bonus(a, c))
		return maxf(own, common)
	return own

## CodexDamageHooks「orb-sets」（installNativeOrbRuntime）：角色用技能（含普通攻击）时，宝珠套装通用效果只取最高一套，
## 全部伤害 ×(1＋general%)，乘在 finalMultiplier 上；恢复类（伤害类型 3/4）在前面已分流，不受影响。
## 套装的技能专属加成（set.skills／rate）当前数据全为空，未接。
static func orb_set_multiplier(item: Dictionary, a: XBattler) -> float:
	if not (a is XActor) or not item.has("stypeId"):
		return 1.0
	var g := XOrbs.general_set((a as XActor).equips)
	return 1.0 + float(g.get("general", 0.0)) / 100.0 if not g.is_empty() else 1.0

static func defense_rate(attack: float, defense: float) -> float:
	var a := maxf(0.0, attack)
	var d := maxf(0.0, defense)
	return 1.0 if a + d == 0.0 else maxf(0.05, a / (a + d))

static func critical_multiplier_bonus(b: XBattler) -> float:
	var v := 0.0
	for o in _yep_objects(b):
		v += float(o.get("yep", {}).get("critMultBonus", 0.0))
	return maxf(0.0, v) if not b.is_actor() else v


# ---- 主流程 ----
## 返回 {value, critical, breakdown}。options: critical(bool)、variance(bool，默认 true)、vars(Array)
static func calculate(item: Dictionary, a: XBattler, b: XBattler, options := {}) -> Dictionary:
	var vars: Array = options.get("vars", [])
	var spec: Dictionary = elements_data().skills.get(str(int(item.id)), {})
	var cache: Dictionary = a.passive_cache()
	var mode := str(spec.get("mode", "magical" if is_magical(item) else "physical"))
	var kind := str(options.get("kind", spec.get("kind", "normal")))
	var skill_pass: Dictionary = cache.get("skillPass", {}).get(int(item.id), {})
	var final_add := float(cache.get("globalHarmRi", 0.0))
	var critical_add := float(cache.get("critHarmRi", 0.0))
	if not a.is_actor():
		for o in objects(a):
			for m in XActor._scan(str(o.get("note", "")), "(?i)<(passiveHarmRi|passiveCrHarmRi)\\s*:\\s*([+-]?[\\d.]+)%?\\s*>"):
				if m[0].to_lower() == "passiveharmri":
					final_add += float(m[1]) / 100.0
				else:
					critical_add += float(m[1]) / 100.0
	var normal_add := 0.0
	for wt in cache.get("SkETypeHarmRi", {}):
		if a is XActor and (a as XActor).equip_list().any(func(e): return e.kind == "weapon" and int(e.wtypeId) == int(wt)):
			normal_add += float(cache.SkETypeHarmRi[wt])
	var item_types = item.get("meta", {}).get("SkillTypes")
	if item_types != null:
		var parsed = JSON.parse_string(str(item_types))
		for t in (parsed if parsed is Array else []):
			normal_add += float(cache.get("skillTypeDvup", {}).get(str(t), 0.0))

	var dmg_type := int(item.damage.type)
	var initial := {"mode": mode, "kind": kind, "skillMultiplier": maxf(0.0, 1.0 + float(skill_pass.get("rate", 0.0))),
		"flatSkill": float(skill_pass.get("flat", 0.0)), "normalAdd": normal_add, "criticalAdd": critical_add,
		"elementAdd": {}, "elementMultiplier": {}, "flatMitigationAdd": {}, "finalAdd": final_add,
		"finalMultiplier": 1.0, "growthMultiplier": 1.0, "settlementMultiplier": 1.0,
		"physicalDefenseRate": 1.0, "magicalDefenseRate": 1.0, "physicalDamageMultiplier": 1.0, "magicalDamageMultiplier": 1.0,
		"flatMitigationRate": 1.0, "healingMultiplier": 1.0, "physicalIncomingPierce": 0.0, "magicalIncomingPierce": 0.0,
		"resistancePierce": 0.0, "incomingMultiplier": 1.0, "elements": null, "noElement": false, "categoryMax": false}
	var registry: XModuleRegistry = options.get("moduleRegistry", XModuleRegistry.standard())
	var facts := {"orbMultiplier": orb_set_multiplier(item, a) if not dmg_type in [3, 4] else 1.0}
	# Extra module facts are explicitly supplied value snapshots. The registered
	# orb fact belongs to this boundary and cannot be replaced by an option.
	var extras = XModuleRegistry.value_copy(options.get("moduleFacts", {}))
	if not extras is Dictionary:
		return _module_failure({"trace": [], "diagnostics": ["invalid_module_facts"]})
	facts.merge(extras)
	facts.merge(registry.capture_facts(item, a, b, options, facts))
	var context := {"item": item, "subject": _module_snapshot(a), "target": _module_snapshot(b),
		"options": {"critical": options.get("critical", false), "preview": options.get("preview", not options.has("random"))},
		"facts": facts, "operationId": str(options.get("operationId", ""))}
	var report := registry.dispatch("damage.before", context, initial)
	if not report.available:
		return _module_failure(report)
	var frame: Dictionary = report.frame
	mode = str(options.get("mode", frame.mode))  # Native explicit mode wins after hooks.
	frame.mode = mode
	kind = str(frame.kind)
	if dmg_type == 3 or dmg_type == 4:
		var healing := _healing(item, a, b, options, vars, frame)
		healing.moduleTrace = report.trace
		return healing

	var raw := maxf(0.0, float(options.rawValue) if options.has("rawValue") else eval_formula(item, a, b, vars))
	if kind == "settled":
		return {"value": XPower.js_round(raw), "critical": false, "breakdown": {"base": raw}, "moduleTrace": report.trace}
	var basis := maxf(0.0, (raw + float(frame.flatSkill)) * float(frame.skillMultiplier))
	var weights := [0.0, 1.0] if mode == "magical" else [1.0, 0.0]
	if mode == "mixed":
		weights = _mixed_weights(item, a, b, vars)
	var defense := 1.0
	if not ["true", "fixed", "percent"].has(kind):
		defense = weights[0] * defense_rate(a.atk, b.def * maxf(0.0, frame.physicalDefenseRate)) + weights[1] * defense_rate(a.mat, b.mdf * maxf(0.0, frame.magicalDefenseRate))
	if mode == "mixed" and kind == "normal":
		defense = weights[0] * defense_rate(a.atk, b.def * maxf(0.0, frame.physicalDefenseRate)) * float(frame.physicalDamageMultiplier) + weights[1] * defense_rate(a.mat, b.mdf * maxf(0.0, frame.magicalDefenseRate)) * float(frame.magicalDamageMultiplier)
	else:
		defense *= weights[0] * float(frame.physicalDamageMultiplier) + weights[1] * float(frame.magicalDamageMultiplier)

	var critical: bool = options.get("critical", false)
	var critical_base := 1.5 + critical_multiplier_bonus(a)
	var critical_mult := maxf(1.0, critical_base + float(frame.criticalAdd)) if critical else 1.0
	var final_mult := maxf(0.0, 1.0 + float(frame.finalAdd)) * maxf(0.0, float(frame.finalMultiplier))
	var normal_mult := maxf(0.0, 1.0 + float(frame.normalAdd))
	var race := _race_factors(a, b)
	var es: Array = options.get("elements", frame.elements if frame.elements != null else action_elements(item, a))
	if frame.noElement: es = [0]
	if es.is_empty():
		es = [0]
	var physical := mode == "physical" if options.has("mode") else is_physical(item)
	var magical := mode == "magical" if options.has("mode") else is_magical(item)
	var incoming := 1.0
	if kind != "true":
		incoming = maxf(0.0, b.pdr) if physical else (maxf(0.0, b.mdr) if magical else 1.0)
	var pierce: float = frame.physicalIncomingPierce if physical else frame.magicalIncomingPierce
	if incoming > 0.0 and incoming < 1.0:
		incoming = 1.0 - (1.0 - incoming) * (1.0 - clampf(pierce, 0.0, 1.0))
	incoming *= maxf(0.0, frame.incomingMultiplier)
	var guard := 1.0 if kind == "true" else (1.0 / (2.0 * b.grd) if b.guarding else 1.0)
	var growth := maxf(0.0, frame.growthMultiplier)
	var best := {}
	var cands := []
	for e in es:
		var resistance: float = 1.0 if kind == "true" or e == 0 else b.element_rate(e)
		var absorb := resistance < 0.0
		if resistance > 0.0 and resistance < 1.0:
			resistance = 1.0 - (1.0 - resistance) * (1.0 - clampf(frame.resistancePierce, 0.0, 1.0))
		var match_rate: float = 1.0 if kind == "true" else matchup(e, affinity(b))
		var bonus: float = 1.0 if frame.noElement else _module_element_bonus(a, e, frame)
		var flat_element := 0.0 if frame.noElement else _sum_yep(a, "elementAmplifyN", e, _yep_objects(a))
		var multiplied: float = (basis + flat_element * float(frame.skillMultiplier)) * normal_mult * bonus * race.multiplier * final_mult * (1.0 if absorb else growth)
		var crit: float = 1.0 if absorb else critical_mult
		var before_fixed: float = multiplied * defense * match_rate * absf(resistance) * incoming * crit
		var flat: float = 0.0 if kind == "true" else _flat_mitigation(a, b, e, frame) + race.flat
		var independent: float = 1.0 if absorb else _independent(a, item, e, frame)
		var gross: float = 0.0 if resistance == 0.0 else maxf(0.0, before_fixed) * independent * guard
		# 固定减伤（harmRe、种族减免）在 Confirm 之后、React 之前扣（apply_fixed_mitigation），这里只算扣之前的；吸收时照原版先扣
		var value: float = -maxf(0.0, before_fixed - flat) * guard if absorb else gross
		cands.append({"gross": value, "flat": flat, "resistance": resistance})
		var row := {"element": e, "bonus": bonus, "defense": defense, "matchup": match_rate, "resistance": resistance,
			"incoming": incoming, "terminal": final_mult, "normal": normal_mult, "race": race.multiplier, "growth": 1.0 if absorb else growth,
			"critical": crit, "independent": independent, "guard": guard, "fixedMitigation": flat, "beforeFixed": gross, "value": value}
		if best.is_empty() or value > best.value:
			best = row
	var settled: float = best.value
	if options.get("variance", true) and not options.get("preview", false):
		settled = apply_variance(settled, int(item.damage.variance), options.get("random"))
	var out_value := XPower.js_round(settled)  # JS Math.round：负数的 .5 往大取整（roundf 会远离零）
	if settled > 0.0 and out_value == 0.0:
		out_value = 1.0
	return {"value": out_value, "settled": settled, "critical": critical, "moduleTrace": report.trace, "breakdown": {"base": raw, "basis": basis, "weights": weights, "row": best, "candidates": cands}}


## 正式 executeDamage 的顺序：攻击方 Confirm → 固定减伤（onPreDamageStateEffects 的包装）→ 目标 React。
static func finish(res: Dictionary, item: Dictionary, a: XBattler, b: XBattler, execute := false, ctx := {}) -> float:
	# installDamageElementRuntime：HP 伤害／吸取被元素吸收时跳过攻击方 Confirm（普通回复仍照常）。
	var absorbed: bool = float(res.value) < 0.0 and int(item.damage.type) in [1, 5]
	var confirmed: float = res.value if absorbed else apply_state_effects(res.value, item, a, b, [], "confirm", execute, bool(res.get("critical", false)), ctx)
	return apply_state_effects(apply_fixed_mitigation(confirmed, res), item, a, b, [], "react", execute, bool(res.get("critical", false)), ctx)


## 正式 installDamageElementRuntime 的 entered 阶段：Confirm 之后的伤害按比例摊回各属性候选，各减固定减伤，取最大；
## 抗性 0 为 0，结果四舍五入。吸收（负值）与回复不在此扣（吸收已在 calculate 里扣过）。
static func apply_fixed_mitigation(amount: float, res: Dictionary) -> float:
	var row: Dictionary = res.get("breakdown", {}).get("row", {})
	var cands: Array = res.get("breakdown", {}).get("candidates", [])
	if row.is_empty() or cands.is_empty() or amount < 0.0 or float(row.get("resistance", 1.0)) < 0.0:
		return amount
	var picked := float(row.get("value", 0.0))
	var scale := amount / picked if picked > 0.0 else 1.0
	var best := -INF
	for c in cands:
		if float(c.gross) < 0.0:
			continue
		var gross: float = float(c.gross) * scale if picked > 0.0 else amount
		var v: float = 0.0 if float(c.resistance) == 0.0 else maxf(0.0, gross - float(c.flat))
		best = maxf(best, v)
	return roundf(best) if best > -INF else amount


static func _healing(item: Dictionary, a: XBattler, b: XBattler, options: Dictionary, vars: Array, frame: Dictionary) -> Dictionary:
	var base := float(options.rawValue) if options.has("rawValue") else eval_formula(item, a, b, vars)
	var es := action_elements(item, a)
	var mult := 1.0
	if not es.is_empty():
		mult = 0.0
		for e in es:
			mult += _module_element_bonus(a, e, frame)
		mult /= es.size()
	var value: float = base * mult * maxf(0.0, frame.healingMultiplier) * maxf(0.0, b.rec)
	# installDamageElementRuntime.healing：治疗被动在浮动与取整之前相乘。
	if value < 0.0 and a is XActor:
		for bonus in a.passive_values("passiveHEUP"):
			value *= 1.0 + float(bonus) * 0.01
	if options.get("variance", true) and not options.get("preview", false):
		value = apply_variance(value, int(item.damage.variance), options.get("random"))
	return {"value": XPower.js_round(minf(0.0, value)), "settled": value, "critical": false, "breakdown": {"base": base, "elementMultiplier": mult}}  # Math.round


static func apply_variance(value: float, variance: int, random: XRandomStream = null) -> float:
	if random == null:
		return value # Preview midpoint; never consume a live/global stream.
	var amp := floorf(maxf(absf(value) * variance / 100.0, 0.0))
	var v := random.next_int_inclusive(0, int(amp), "variance_a") + random.next_int_inclusive(0, int(amp), "variance_b") - amp
	return value + v if value >= 0.0 else value - v


static func _mixed_weights(item: Dictionary, a: XBattler, b: XBattler, vars: Array) -> Array:
	var base := eval_formula(item, a, b, vars)
	var vals := []
	for pid in [2, 4]:
		var proxy := _ParamProxy.new(a, pid)
		vals.append(maxf(0.0, eval_formula(item, proxy, b, vars) - base))
	var s: float = vals[0] + vals[1]
	return [vals[0] / s, vals[1] / s] if s > 0.0 else [0.5, 0.5]


static func _race_factors(a: XBattler, b: XBattler) -> Dictionary:
	var boost := 0.0
	var flat: float = 0.0
	var target_ids: Array = b.race_ids() if not b.is_actor() else []
	var source_ids: Array = a.race_ids() if not a.is_actor() else []
	for o in objects(a):
		for m in XActor._scan(str(o.get("note", "")), "(?i)<EnemyRaceBo(\\d+)\\s*:\\s*([+-]?[\\d.]+)%?\\s*>"):
			if target_ids.has(int(m[0])):
				boost += float(m[1]) / 100.0
	for o in objects(b):
		for m in XActor._scan(str(o.get("note", "")), "(?i)<EnemyRaceRe(\\d+)\\s*:\\s*([+-]?[\\d.]+)\\s*>"):
			if source_ids.has(int(m[0])):
				flat += float(m[1])
	return {"multiplier": maxf(0.0, 1.0 + boost), "flat": maxf(0.0, flat)}


static func _flat_mitigation(a: XBattler, b: XBattler, e: int, frame: Dictionary) -> float:
	var target: Dictionary = b.passive_cache()
	var source: Dictionary = a.passive_cache()
	var value: float = float(target.get("harmRe", {}).get(e, 0.0)) + float(frame.flatMitigationAdd.get(str(e), 0.0))
	value = maxf(0.0, value - float(source.get("penetrateFixed", {}).get(e, 0.0)))
	return value * (1.0 - clampf(float(source.get("penetratePercent", {}).get(e, 0.0)), 0.0, 100.0) / 100.0) * maxf(0.0, frame.flatMitigationRate)


static func _independent(a: XBattler, item: Dictionary, e: int, frame: Dictionary) -> float:
	var pr := 1.0
	var er := 1.0
	for o in objects(a):
		var note := str(o.get("note", ""))
		var p := RegEx.create_from_string("(?i)<SelfPhysRate:\\s*([\\d.]+)>").search(note)
		var q := RegEx.create_from_string("(?i)<SelfElemRate:\\s*([\\d.]+)>").search(note)
		if p:
			pr *= float(p.get_string(1))
		if q:
			er *= float(q.get_string(1))
	var physical: bool = frame.mode == "physical" if frame.noElement else e == 1
	var category: float = maxf(pr, er) if frame.categoryMax and not frame.noElement else (pr if physical else 1.0) * (er if ACTIVE.has(e) else 1.0)
	return maxf(0.0, frame.settlementMultiplier * category)


# ---- 状态脚本（YEP BuffsStatesCore）：Confirm = 行动者的状态，React = 目标的状态 ----
## 转换器已把常见写法变成 {op: "mul", cond, k, round}；op == "js" 的尚未翻译，跳过并计数。
static func apply_state_effects(value: float, item: Dictionary, a: XBattler, b: XBattler, untranslated: Array = [], phase := "", execute := false, critical := false, ctx := {}) -> float:
	var c: Dictionary = ctx.duplicate()
	c.merge({"attacker": a, "defender": b, "item": item, "untranslated": untranslated, "execute": execute, "critical": critical}, true)
	for pair in [["confirm", a], ["react", b]]:
		if phase != "" and pair[0] != phase:
			continue
		c.value = value
		value = XStateEffects.run(pair[0], pair[1], c)
	return value


## 混合模式权重用：只把指定能力值放大 0.1%，其余照常。
class _ParamProxy:
	extends XBattler
	var src: XBattler
	var pid: int
	func _init(s: XBattler, p: int) -> void:
		src = s
		pid = p
	func param(i: int) -> float:
		return src.param(i) * (1.001 if i == pid else 1.0)
	func xparam(i: int) -> float:
		return src.xparam(i)
	func sparam(i: int) -> float:
		return src.sparam(i)
	func skillMasteryLevel(id: int) -> int:
		return src.skillMasteryLevel(id)


static func _module_element_bonus(a: XBattler, element: int, frame: Dictionary) -> float:
	return maxf(0.0, 1.0 + element_bonus(a, element) + float(frame.elementAdd.get(str(element), 0.0))) * float(frame.elementMultiplier.get(str(element), 1.0))

static func _module_snapshot(b: XBattler) -> Dictionary:
	return {"kind": "actor" if b.is_actor() else "enemy", "id": b.actor_id if b is XActor else b.enemy_id if b is XEnemy else 0,
		"hp": b.hp, "mp": b.mp, "tp": b.tp, "states": b.state_ids.duplicate()}

static func _module_failure(report: Dictionary) -> Dictionary:
	var diagnostic := ";".join(report.diagnostics)
	push_warning("damage module unavailable: " + diagnostic)
	return {"available": false, "value": NAN, "critical": false, "breakdown": {}, "diagnostic": diagnostic, "moduleTrace": report.trace}
