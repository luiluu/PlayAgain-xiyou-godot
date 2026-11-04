class_name XPowerEnemy
extends RefCounted
## 怪物战力（installCombatPowerRuntime v2 的 enemyPower，HOLD-003）：与角色同一刻度。Boss 状态面板用它画「战力 N」，
## 面板开关 XBossStatusPanel.SHOW_POWER 默认关（Kyo 2026-11-04：要重构战力系统，做好的显示留着等换上新战力再开）。
## - 输出：行动表里伤害类型 1／2／5／6 的行动，取评分不低于最高分−2 的，按「评分−(最高分−3)」加权；每回合行动数 = 1 + 各「追加行动」几率夹到 0～1。
##   对三档中性靶（防御 100／1 万／100 万，权重 0.3／0.4／0.3）各预演：普通与暴击伤害按暴击率混合 × 命中 × 重复次数，单体外按范围乘（群体 ×1.8，随机 N 体 ×(范围−2)）。
## - 有效生命 = 最大生命 × 防御折算 ÷ 受伤率（物魔平均，× (1−闪避平均)）；分项 [输出, 生存, 0] 各按曲线 round(权重 × (值/参照)^指数) 折分。
## - 随机：预演里随机数一律取 0.5。不改敌人、不加状态。
## 取数与显示分开：以后换新战力，只替换 enemy()，面板那边不用动。

const DAMAGE_TYPES := [1, 2, 5, 6]

static var _cache := {}  # 敌人实例 id → {key, value}


static func clear_cache() -> void:
	_cache.clear()


## enemySignature：编号、八项能力（四舍五入）、状态表
static func signature(e: XEnemy) -> String:
	var params := []
	for i in range(8):
		params.append(int(XPower.js_round(e.param(i))))
	var states: Array = e.state_ids.duplicate()
	states.sort()
	return JSON.stringify([e.enemy_id, params, states])


static func _curve(value: float, reference: float, weight: float, exponent: float) -> float:
	return XPower.js_round(weight * pow(maxf(0.0, value) / reference, exponent))


## cachedEnemy：只读缓存，没算过或签名变了是 {}
static func cached(e: XEnemy) -> Dictionary:
	if e == null or not XPower.enabled():
		return {}
	var c: Dictionary = _cache.get(e.get_instance_id(), {})
	return c.value if not c.is_empty() and c.key == signature(e) else {}


## enemy：{total, parts, output, effectiveHp}；战力显示关掉时 {}
static func enemy(e: XEnemy) -> Dictionary:
	if e == null or not XPower.enabled():
		return {}
	var key := signature(e)
	var c: Dictionary = _cache.get(e.get_instance_id(), {})
	if not c.is_empty() and c.key == key:
		return c.value
	var logic := XBattleLogic.new()
	logic.state = XState.current
	var acts: Array = []
	for a in e.data().get("actions", []):
		var s := XDB.rec("Skills", int(a.skillId))
		if not s.is_empty() and DAMAGE_TYPES.has(int(s.get("damage", {}).get("type", 0))):
			acts.append(a)
	var top := 0.0
	for a in acts:
		top = maxf(top, float(a.rating))
	var pool: Array = acts.filter(func(a): return float(a.rating) >= top - 2.0)
	var weights := pool.map(func(a): return float(a.rating) - (top - 3.0))
	var actions := 1.0
	for v in e.action_plus_set():
		actions += clampf(float(v), 0.0, 1.0)
	var output := 0.0
	for profile in XPower.PROFILES:
		var target := XPower.NeutralEnemy.new(float(profile.def))
		var total := 0.0
		var wsum := 0.0
		for i in range(pool.size()):
			var skill := XDB.rec("Skills", int(pool[i].skillId))
			total += _expected(logic, e, target, skill) * weights[i]
			wsum += weights[i]
		output += float(profile.weight) * (total / wsum if wsum > 0.0 else 0.0) * actions
	var avoidance := (clampf(e.eva, 0.0, 0.8) + clampf(e.mev, 0.0, 0.8)) / 2.0
	var rate := maxf(0.02, (maxf(0.0, e.pdr) + maxf(0.0, e.mdr)) / 2.0) * (1.0 - avoidance)
	var defense := 1.0 / ((XDamage.defense_rate(10000, e.def) + XDamage.defense_rate(10000, e.mdf)) / 2.0)
	var ehp := maxf(0.0, e.mhp) * defense / rate
	var parts := [_curve(output, 1000, 600, 0.35), _curve(ehp, 1000, 300, 0.5), 0.0]
	var value := {"total": parts[0] + parts[1], "parts": parts, "output": output, "effectiveHp": ehp}
	_cache[e.get_instance_id()] = {"key": key, "value": value}
	return value


## 单个行动的期望伤害（makeDamageValue 普通／暴击按 itemCri 混合 × itemHit × 重复，范围倍数）
static func _expected(logic: XBattleLogic, e: XEnemy, t: XBattler, skill: Dictionary) -> float:
	var item := XPower._preview_skill(skill)
	var vars := XPower._vars()
	var opts := {"critical": false, "variance": false, "vars": vars, "battleRound": 1, "preview": true}
	var normal := XDamage.finish(XDamage.calculate(item, e, t, opts), item, e, t, false, {"variables": vars})
	var critical := normal
	if bool(item.damage.get("critical", false)):
		var crit_opts := opts.duplicate()
		crit_opts.critical = true
		critical = XDamage.finish(XDamage.calculate(item, e, t, crit_opts), item, e, t, false, {"variables": vars})
	var p := clampf(logic.item_cri(e, item, t), 0.0, 1.0)
	var h := clampf(logic.item_hit(e, item, t), 0.0, 1.0)
	var value := maxf(0.0, normal * (1.0 - p) + critical * p) * h * maxf(1.0, float(skill.get("repeats", 1)))
	var scope := int(skill.get("scope", 1))
	if scope == 2:
		value *= 1.8
	elif scope >= 3 and scope <= 6:
		value *= scope - 2
	return value
