class_name XDamage
extends RefCounted
## 伤害结算：移植自正式版 js/codex/runtime/installDamageElementRuntime.js v3（CodexDamage.calculate）。
## 首期精简：
## - 成长修正 growth 固定为 1（正式版的「五乘区预算软上限」/真气钩子未移植，见首期规格）。
## - 其余 CodexDamageHooks（角色专属机制）未移植；首期角色不依赖它们。已接：orb-sets（宝珠套装通用效果，见 orb_set_multiplier）。
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
		return XFormulaProgram.evaluate(program, XFormulaContext.capture(a, b, vars, {}, int(item.id)), int(item.damage.type)).value
	var out := XFormulaExecution.run_item(item, a, b, vars)
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
	var id := int(item.damage.elementId)
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
		objs = objs + x.equip_list() + [x.data(), x.class_data()]
	return objs

static func own_bonus(a: XBattler, e: int) -> float:
	var objs := _yep_objects(a)
	var value: float = _sum_yep(a, "elementAmplify", e, objs)
	if a.is_actor():
		for m in a.passive_values("passiveELUP%02d" % e):
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
	if dmg_type == 3 or dmg_type == 4:
		return _healing(item, a, b, options, vars)

	var raw := maxf(0.0, float(options.rawValue) if options.has("rawValue") else eval_formula(item, a, b, vars))
	var basis := maxf(0.0, raw + float(skill_pass.get("flat", 0.0))) * maxf(0.0, 1.0 + float(skill_pass.get("rate", 0.0)))
	var weights := [0.0, 1.0] if mode == "magical" else [1.0, 0.0]
	if mode == "mixed":
		weights = _mixed_weights(item, a, b, vars)
	var defense := 1.0
	if not ["true", "fixed", "percent"].has(kind):
		defense = weights[0] * defense_rate(a.atk, b.def) + weights[1] * defense_rate(a.mat, b.mdf)

	var critical: bool = options.get("critical", false)
	var critical_base := 1.5 + critical_multiplier_bonus(a)
	var critical_mult := maxf(1.0, critical_base + critical_add) if critical else 1.0
	var final_mult := maxf(0.0, 1.0 + final_add) * maxf(0.0, orb_set_multiplier(item, a))
	var normal_mult := maxf(0.0, 1.0 + normal_add)
	var race := _race_factors(a, b)
	var es := action_elements(item, a)
	if es.is_empty():
		es = [0]
	var physical := is_physical(item)
	var magical := is_magical(item)
	var incoming := 1.0
	if kind != "true":
		incoming = maxf(0.0, b.pdr) if physical else (maxf(0.0, b.mdr) if magical else 1.0)
	var guard := 1.0 if kind == "true" else (1.0 / (2.0 * b.grd) if b.guarding else 1.0)
	var growth := 1.0
	var best := {}
	var cands := []
	for e in es:
		var resistance: float = 1.0 if kind == "true" or e == 0 else b.element_rate(e)
		var absorb := resistance < 0.0
		var match_rate: float = 1.0 if kind == "true" else matchup(e, affinity(b))
		var bonus: float = maxf(0.0, 1.0 + element_bonus(a, e))
		var flat_element := _sum_yep(a, "elementAmplifyN", e, _yep_objects(a))
		var multiplied: float = (basis + flat_element * (1.0 + float(skill_pass.get("rate", 0.0)))) * normal_mult * bonus * race.multiplier * final_mult * (1.0 if absorb else growth)
		var crit: float = 1.0 if absorb else critical_mult
		var before_fixed: float = multiplied * defense * match_rate * absf(resistance) * incoming * crit
		var flat: float = 0.0 if kind == "true" else _flat_mitigation(a, b, e) + race.flat
		var independent: float = 1.0 if absorb else _independent(a, item, e)
		var gross: float = 0.0 if resistance == 0.0 else maxf(0.0, before_fixed) * independent * guard
		# 固定减伤（harmRe、种族减免）在 Confirm 之后、React 之前扣（apply_fixed_mitigation），这里只算扣之前的；吸收时照原版先扣
		var value: float = -maxf(0.0, before_fixed - flat) * guard if absorb else gross
		cands.append({"gross": value, "flat": flat, "resistance": resistance})
		var row := {"element": e, "bonus": bonus, "defense": defense, "matchup": match_rate, "resistance": resistance,
			"incoming": incoming, "terminal": final_mult, "normal": normal_mult, "race": race.multiplier, "growth": growth,
			"critical": crit, "independent": independent, "guard": guard, "fixedMitigation": flat, "beforeFixed": gross, "value": value}
		if best.is_empty() or value > best.value:
			best = row
	var settled: float = best.value
	if options.get("variance", true):
		settled = apply_variance(settled, int(item.damage.variance), options.get("random"))
	var out_value := roundf(settled)
	if settled > 0.0 and out_value == 0.0:
		out_value = 1.0
	return {"value": out_value, "settled": settled, "critical": critical, "breakdown": {"base": raw, "basis": basis, "weights": weights, "row": best, "candidates": cands}}


## 正式 executeDamage 的顺序：攻击方 Confirm → 固定减伤（onPreDamageStateEffects 的包装）→ 目标 React。
static func finish(res: Dictionary, item: Dictionary, a: XBattler, b: XBattler) -> float:
	# installDamageElementRuntime：HP 伤害／吸取被元素吸收时跳过攻击方 Confirm（普通回复仍照常）。
	var absorbed: bool = float(res.value) < 0.0 and int(item.damage.type) in [1, 5]
	var confirmed: float = res.value if absorbed else apply_state_effects(res.value, item, a, b, [], "confirm")
	return apply_state_effects(apply_fixed_mitigation(confirmed, res), item, a, b, [], "react")


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


static func _healing(item: Dictionary, a: XBattler, b: XBattler, options: Dictionary, vars: Array) -> Dictionary:
	var base := float(options.rawValue) if options.has("rawValue") else eval_formula(item, a, b, vars)
	var es := action_elements(item, a)
	var mult := 1.0
	if not es.is_empty():
		mult = 0.0
		for e in es:
			mult += maxf(0.0, 1.0 + element_bonus(a, e))
		mult /= es.size()
	var value: float = base * mult * maxf(0.0, b.rec)
	# installDamageElementRuntime.healing：治疗被动在浮动与取整之前相乘。
	if value < 0.0 and a is XActor:
		for bonus in a.passive_values("passiveHEUP"):
			value *= 1.0 + float(bonus) * 0.01
	if options.get("variance", true):
		value = apply_variance(value, int(item.damage.variance), options.get("random"))
	return {"value": roundf(minf(0.0, value)), "settled": value, "critical": false, "breakdown": {"base": base, "elementMultiplier": mult}}


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


static func _flat_mitigation(a: XBattler, b: XBattler, e: int) -> float:
	var target: Dictionary = b.passive_cache()
	var source: Dictionary = a.passive_cache()
	var value: float = float(target.get("harmRe", {}).get(e, 0.0))
	value = maxf(0.0, value - float(source.get("penetrateFixed", {}).get(e, 0.0)))
	return value * (1.0 - clampf(float(source.get("penetratePercent", {}).get(e, 0.0)), 0.0, 100.0) / 100.0)


static func _independent(a: XBattler, item: Dictionary, e: int) -> float:
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
	return maxf(0.0, (pr if e == 1 else 1.0) * (er if ACTIVE.has(e) else 1.0))


# ---- 状态脚本（YEP BuffsStatesCore）：Confirm = 行动者的状态，React = 目标的状态 ----
## 转换器已把常见写法变成 {op: "mul", cond, k, round}；op == "js" 的尚未翻译，跳过并计数。
static func apply_state_effects(value: float, item: Dictionary, a: XBattler, b: XBattler, untranslated: Array = [], phase := "") -> float:
	var is_hp := [1, 3, 5].has(int(item.damage.type))
	for pair in [["confirm", a], ["react", b]]:
		if phase != "" and pair[0] != phase:
			continue
		for s in pair[1].states():
			for eff in s.get("effects", []):
				if eff.phase != pair[0]:
					continue
				if eff.op != "mul":
					untranslated.append({"state": int(s.id), "phase": eff.phase})
					continue
				if eff.get("hpOnly", false) and not is_hp:
					continue
				var ok := false
				match str(eff.cond):
					"nonzero": ok = value != 0.0
					"positive": ok = value > 0.0
					"nonnegative": ok = value >= 0.0
				if ok:
					var x := value * float(eff.k)
					match str(eff.round):
						"ceil": value = ceilf(x)
						"floor": value = floorf(x)
						_: value = roundf(x)
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
