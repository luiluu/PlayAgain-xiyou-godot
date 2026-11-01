class_name XSkillMastery
## 【cc·八戒·未经审查】技能熟练度 YEP_SkillMasteryLevels v1.00（期一：解析、涨熟练度、伤害、存档；参照 mv_oracle/skill_mastery_probe）。
## - 每个技能（DataManager.processSkillMasteryLevelsNotetags1）：上限 masteryMaxLevel（插件 Default Max Mastery，备注 <Max Mastery Level: n>）、
##   升级所需次数 masteryFormula(level)（插件 Level Formula，备注 <Custom EXP Mastery Formula: …>）、伤害 masteryDamage(value, level)
##   （插件 Damage Formula，备注 <Custom Damage Mastery Formula: …>、<Mastery Effect: ±n Damage Per Level>、<Mastery Effect: ±n% …>、
##   <No Damage Mastery Effect>）；费用、冷却的公式同样解析存着（正式西游插件参数都原样，期三渡鸦用）。
##   备注逐行按原版的 if／else 顺序匹配；<CUSTOM (.*) MASTERY FORMULA: (.*)> 是贪婪的，两个标签写在同一行时类型对不上任何一种，整行不生效（照原版）。
##   公式是 JS 表达式，正式西游只用到 value、level、四则运算与 CodexCat.mastery(this.subject())（小猫剑圣剑技等级，换成 cat）；
##   插件参数里 // 之后是注释。
## - 涨熟练度：战斗里 paySkillCost 记下技能（action_mastery），onAllActionsEnd 逐个：没满级的已用次数 +1，够 masteryFormula(等级＋1)
##   就升一级、已用次数归 0；有升级就放动画 742（Level Up Animation）。等级先夹到 masteryMaxLevel，变量 13 为 1 时再夹到变量 8（0 当 100000）。
##   不在战斗里付费不记；敌人也涨（每场新建，从 0 起）。
## - 伤害：installDamageElementRuntime 在 raw＋flatSkill 之后乘 masteryDamage（只对技能；治疗、settled 不走），masteryRate 也乘进元素固定增伤
##   （XDamage._calculate）。
## - 存档：角色的 _skillMasteryLevels／_skillMasteryUses（XState.to_dict 的 masteryLevels／masteryUses；旧档没有就是 0 级）。

const ANIMATION_DEFAULT := 742
static var _cache := {}


## 一个技能的熟练度设定（备注解析结果，按技能编号缓存）
static func data(skill_id: int) -> Dictionary:
	if _cache.has(skill_id):
		return _cache[skill_id]
	var p := XDB.plugin("YEP_SkillMasteryLevels")
	var d := {"max": int(p.get("Default Max Mastery", "100000")), "exp": _strip(str(p.get("Level Formula", "1"))),
		"damage": _strip(str(p.get("Damage Formula", "value"))), "mp": _strip(str(p.get("MP Cost Formula", "cost"))),
		"tp": _strip(str(p.get("TP Cost Formula", "cost"))), "hp": _strip(str(p.get("HP Cost Formula", "cost"))),
		"cooldown": _strip(str(p.get("Cooldown Formula", "turns")))}
	var rec := XDB.rec("Skills", skill_id)
	var keys := {"DAMAGE": "damage", "MP COST": "mp", "TP COST": "tp", "HP COST": "hp", "COOLDOWN": "cooldown"}
	var vars := {"damage": "value", "mp": "cost", "tp": "cost", "hp": "cost", "cooldown": "turns"}
	for line in RegEx.create_from_string("[\\r\\n]+").sub(str(rec.get("note", "")), "\n", true).split("\n"):
		var m := _re("<(?:MAX MASTERY LEVEL):[ ](\\d+)>").search(line)
		if m:
			d.max = int(m.get_string(1))
			continue
		m = _re("<MASTERY EFFECT: ([\\+\\-]\\d+)[ ](.*)[ ]PER LEVEL>").search(line)
		if m:
			var k = keys.get(m.get_string(2).to_upper())
			if k != null:
				d[k] = "%s + (level * %d)" % [vars[k], int(m.get_string(1))]
			continue
		m = _re("<MASTERY EFFECT: ([\\+\\-]\\d+)([%％])[ ](.*)[ ]PER LEVEL>").search(line)
		if m:
			var k = keys.get(m.get_string(3).to_upper())
			if k != null:
				d[k] = "%s * (1.00 + (level * %s))" % [vars[k], str(float(m.get_string(1)) * 0.01)]
			continue
		m = _re("<NO[ ](.*)[ ]MASTERY EFFECT>").search(line)
		if m:
			var k = keys.get(m.get_string(1).to_upper())
			if k != null:
				d[k] = vars[k]
			continue
		m = _re("<CUSTOM (.*) MASTERY FORMULA: (.*)>").search(line)
		if m:
			var t := m.get_string(1).to_upper()
			var k = "exp" if t == "EXP" else keys.get(t)
			if k != null:
				d[k] = m.get_string(2)
	_cache[skill_id] = d
	return d


static func _strip(formula: String) -> String:
	var i := formula.find("//")
	return formula.substr(0, i) if i >= 0 else formula


static var _res := {}
static func _re(p: String) -> RegEx:
	if not _res.has(p):
		_res[p] = RegEx.create_from_string("(?i)" + p)
	return _res[p]


static var _exprs := {}
## 算一个熟练度公式：x 是 value／cost／turns，cat 是小猫剑圣剑技等级。算不出（原版会弹错）返回 fallback
static func eval(formula: String, x: float, level: float, cat := 0.0, fallback := NAN) -> float:
	var src := formula.replace("CodexCat.mastery(this.subject())", "cat")
	var e: Expression = _exprs.get(src)
	if e == null:
		e = Expression.new()
		if e.parse(src, ["value", "cost", "turns", "level", "cat"]) != OK:
			push_warning("熟练度公式解析失败：" + formula)
			return fallback
		_exprs[src] = e
	var v = e.execute([x, x, x, level, cat], null, false)
	if e.has_execute_failed() or not (v is float or v is int):
		return fallback
	return float(v)


static func max_level(skill_id: int) -> int:
	return int(data(skill_id).max)


## masteryFormula(level)：从 level−1 级升到 level 级要用几次
static func usage_max(b, skill_id: int) -> float:
	return eval(str(data(skill_id).exp), 0.0, float(level(b, skill_id) + 1), 0.0, 0.0)


static func level(b, skill_id: int) -> int:
	return int(b.mastery_levels.get(skill_id, 0))


static func uses(b, skill_id: int) -> float:
	return float(b.mastery_uses.get(skill_id, 0))


static func is_maxed(b, skill_id: int) -> bool:
	return level(b, skill_id) >= max_level(skill_id)


## setSkillMasteryLevel：夹到 [0, 上限]，已用次数归 0
static func set_level(b, skill_id: int, value: int) -> void:
	if XDB.rec("Skills", skill_id).is_empty():
		return
	b.mastery_levels[skill_id] = clampi(value, 0, max_level(skill_id))
	b.mastery_uses[skill_id] = 0


## gainSkillMasteryLevel：先夹上限，变量 13 为 1 时再夹变量 8（0 当 100000）；已用次数归 0
static func gain_level(b, skill_id: int, value: int) -> void:
	var lv := clampi(level(b, skill_id) + value, 0, max_level(skill_id))
	var s := XState.current
	if s != null and int(s.variable(13)) == 1:
		var cap := int(s.variable(8))
		lv = clampi(lv, 0, 100000 if cap == 0 else cap)
	b.mastery_levels[skill_id] = lv
	b.mastery_uses[skill_id] = 0


## setSkillMasteryUses：够数就升一级
static func set_uses(b, skill_id: int, value: float) -> void:
	if XDB.rec("Skills", skill_id).is_empty():
		return
	b.mastery_levels[skill_id] = level(b, skill_id)
	b.mastery_uses[skill_id] = maxf(0.0, value)
	if float(b.mastery_uses[skill_id]) >= usage_max(b, skill_id):
		gain_level(b, skill_id, 1)


## paySkillCost 包装：战斗里记下这次付费的技能
static func record(b, skill: Dictionary) -> void:
	if not skill.is_empty() and not XBattleLogic.is_item(skill):
		b.action_mastery.append(int(skill.id))


## onAllActionsEnd 包装（原 onAllActionsEnd 之后）：逐个计一次使用；有升级返回升级动画编号，否则 0
static func all_actions_end(b) -> int:
	var up := false
	while not b.action_mastery.is_empty():
		var id: int = b.action_mastery.pop_front()
		if XDB.rec("Skills", id).is_empty() or is_maxed(b, id):
			continue
		var before := level(b, id)
		set_uses(b, id, uses(b, id) + 1)
		if level(b, id) > before:
			up = true
	return int(XDB.plugin("YEP_SkillMasteryLevels").get("Level Up Animation", ANIMATION_DEFAULT)) if up else 0


## installDamageElementRuntime 的 mastered：技能才乘 masteryDamage(initial, 等级)；算不出时照原样（number(…, initial)）
static func damage(item: Dictionary, a, initial: float) -> float:
	if item.is_empty() or XBattleLogic.is_item(item) or not item.has("id"):
		return initial
	var id := int(item.id)
	var f := str(data(id).damage)
	var cat := float(XCat.mastery(a)) if f.contains("CodexCat.mastery") else 0.0
	var v := eval(f, initial, float(a.skillMasteryLevel(id)), cat)
	return initial if is_nan(v) or is_inf(v) else v


static func to_save(b) -> Array:
	return [_keys_to_str(b.mastery_levels), _keys_to_str(b.mastery_uses)]


static func _keys_to_str(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = d[k]
	return out


static func from_save(b, levels, used) -> void:
	b.mastery_levels.clear()
	b.mastery_uses.clear()
	if levels is Dictionary:
		for k in levels:
			b.mastery_levels[int(k)] = int(levels[k])
	if used is Dictionary:
		for k in used:
			b.mastery_uses[int(k)] = float(used[k])
