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
## - 期二：改等级后报技能升级通告（XSkillNotice）；XEquipment.clone 带上熟练度（战力、装备预览的伤害预演照原版 JsonEx 深拷贝读到熟练度）。
## - 存档：角色的 _skillMasteryLevels／_skillMasteryUses（XState.to_dict 的 masteryLevels／masteryUses；旧档没有就是 0 级）。
## - 期三（参照 mv_oracle/skill_mastery3_probe）：
##   - 渡鸦 10122～10139 的设定是运行时改写的（installNativeRavenRuntime）：所需次数 8＋4×级、伤害每级 +8%、MP 每级 −3%、TP 每级 −2%（向下取整、不低于 0），
##     HP、冷却不变；上限 10122～10126 跟变量 8（R.masteryCap：0 当 8、最多 999），其余 0（没有 CodexRavenDamage）。
##   - 角色的 skillMasteryLevel 包装链（effective；main.js 装的先后：渡鸦 → 宿傩 → 饿狼 → 异化）：渡鸦 10122～10126 夹 R.masteryCap；
##     宿傩 10229～10238 读来源技能的等级、夹变量 8（0 时取来源上限）；饿狼借主拳（O-待定 o_garou_borrow）；异化无面／百相取 min（O-待定 o_alien_object）。
##     原版凡是读等级的地方（满级判断、onAllActionsEnd 比较升级、通告、技能窗）都读包装后的；所需次数、已用次数读原始的。
##   - 费用、冷却（YEP skillMpCost／TpCost／HpCost、applyCooldownMods 包装，在 YEP_SkillCore 之上、dsPassiveSkill 减耗之内）：
##     费用为正时 ⌊公式⌋、不低于 Minimum（1）；冷却为正时 ⌊公式⌋、不低于 Minimum Cooldown（1）。正式西游只有渡鸦的公式不是原样。

const ANIMATION_DEFAULT := 742
const RAVEN_FIRST := 10122
const RAVEN_CAPPED_LAST := 10126
const RAVEN_LAST := 10139
const SUKUNA_FIRST := 10229
const SUKUNA_LAST := 10238
static var _cache := {}

## O-待定（优化登记）：饿狼追击／反击借主拳熟练度（G.trigger 设 _garouMasterySource）包在 Game_BattlerBase.skillMasteryLevel 上，
## 可渡鸦先在 Game_Actor 上装了自有的包装，角色从来读不到它（参照 garou.borrow：角色读 0、BattlerBase 那层读 3）。
## true＝追击／反击照设计读主拳等级；false＝照原版读自己的（追击技能没人练，恒 0）
static var o_garou_borrow := true
## O-待定（优化登记）：异化无面／百相的取 min（Affixes:23）拿参数直接和技能编号比，原版伤害、费用、技能窗传的是技能对象，对不上，
## 只有传编号的地方（满级判断、升级比较、通告）取到 min（参照 alien.faceless：编号 10、对象 50）。
## true＝传对象也取 min；false＝照原版（伤害、费用、技能窗用自己的等级）
static var o_alien_object := true


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
	if skill_id >= RAVEN_FIRST and skill_id <= RAVEN_LAST:  # finishRavenDatabaseCompatibility 改写（上限见 max_level）
		d.merge({"exp": "8 + level * 4", "damage": "value * (1 + level * 0.08)", "mp": "max(0, floor(cost * (1 - level * 0.03)))",
			"tp": "max(0, floor(cost * (1 - level * 0.02)))", "hp": "cost", "cooldown": "turns"}, true)
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
	if skill_id >= RAVEN_FIRST and skill_id <= RAVEN_LAST:
		return raven_cap() if skill_id <= RAVEN_CAPPED_LAST else 0  # refreshMasteryLimit 只刷 10122～10126；其余没有 CodexRavenDamage，是 0
	return int(data(skill_id).max)


## R.masteryCap：变量 8 向下取整，0 以下当 8，最多 999
static func raven_cap() -> int:
	var s := XState.current
	var v := float(s.variable(8)) if s != null else 0.0
	return mini(999, floori(v) if v > 0.0 else 8)


## masteryFormula(level)：从 level−1 级升到 level 级要用几次
static func usage_max(b, skill_id: int) -> float:
	return eval(str(data(skill_id).exp), 0.0, float(level(b, skill_id) + 1), 0.0, 0.0)


static func level(b, skill_id: int) -> int:
	return int(b.mastery_levels.get(skill_id, 0))


static func uses(b, skill_id: int) -> float:
	return float(b.mastery_uses.get(skill_id, 0))


## 包装后的 skillMasteryLevel（只有角色有包装；敌人是原始等级）。obj：原版这处传的是技能对象（伤害、费用、甚尔、技能窗），见 o_alien_object
static func effective(b, skill_id: int, obj := false) -> int:
	if not b is XActor:
		return level(b, skill_id)
	var own := _native(b, skill_id)
	if obj and not o_alien_object:
		return own
	var d := XAlienation.for_actor(b)
	if d.is_empty():
		return own
	if str(d.affix) == "faceless":
		for p in d.config.get("pairs", []):
			if int(p.get("skillId", 0)) == skill_id and XState.current != null:
				var owner := XState.current.actor(int(p.get("ownerId", 0)))
				return mini(mini(own, int(b.level)), mini(int(owner.level), _native(owner, skill_id)))
		return own
	if str(d.affix) == "mimic" and (d.get("observed", []) as Array).has(skill_id):
		return mini(own, int(b.level))
	return own


## 异化以内的一段：饿狼借主拳（修好后在最里层换编号）→ 渡鸦夹上限 → 宿傩读来源
static func _native(b, skill_id: int) -> int:
	var id := skill_id
	if o_garou_borrow and XGarou.mastery_source != 0 and XGarou.own(b):
		id = XGarou.mastery_source
	var v := level(b, id)
	if XRaven.own(b) and id >= RAVEN_FIRST and id <= RAVEN_CAPPED_LAST:
		v = mini(v, raven_cap())
	if XSukuna.own(b) and id >= SUKUNA_FIRST and id <= SUKUNA_LAST:
		var src := int(XSukuna.MASTERY_SOURCE.get(id, id))
		var s := XState.current
		var cap := int(s.variable(8)) if s != null else 0
		v = mini(level(b, src), cap if cap != 0 else max_level(src))
	return v


## isMaxedSkillMasteryLevel：包装后的等级（传编号）≥ 上限
static func is_maxed(b, skill_id: int) -> bool:
	return effective(b, skill_id) >= max_level(skill_id)


## skillMasteryRate：满级 1，否则 本级已用÷本级所需
static func rate(b, skill_id: int) -> float:
	if is_maxed(b, skill_id):
		return 1.0
	var m := usage_max(b, skill_id)
	return uses(b, skill_id) / m if m != 0.0 else 0.0


## setSkillMasteryLevel：夹到 [0, 上限]，已用次数归 0
static func set_level(b, skill_id: int, value: int) -> void:
	if XDB.rec("Skills", skill_id).is_empty():
		return
	var before := effective(b, skill_id)
	b.mastery_levels[skill_id] = clampi(value, 0, max_level(skill_id))
	b.mastery_uses[skill_id] = 0
	XSkillNotice.report(b, skill_id, before, effective(b, skill_id))  # installSkillLevelNoticeRuntime 包装：前后都读包装后的等级


## gainSkillMasteryLevel：先夹上限，变量 13 为 1 时再夹变量 8（0 当 100000）；已用次数归 0
static func gain_level(b, skill_id: int, value: int) -> void:
	var lv := clampi(level(b, skill_id) + value, 0, max_level(skill_id))
	var s := XState.current
	if s != null and int(s.variable(13)) == 1:
		var cap := int(s.variable(8))
		lv = clampi(lv, 0, 100000 if cap == 0 else cap)
	var before := effective(b, skill_id)
	b.mastery_levels[skill_id] = lv
	b.mastery_uses[skill_id] = 0
	XSkillNotice.report(b, skill_id, before, effective(b, skill_id))  # installSkillLevelNoticeRuntime 包装：前后都读包装后的等级


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
		var before := effective(b, id)
		set_uses(b, id, uses(b, id) + 1)
		if effective(b, id) > before:
			up = true
	return int(XDB.plugin("YEP_SkillMasteryLevels").get("Level Up Animation", ANIMATION_DEFAULT)) if up else 0


## installDamageElementRuntime 的 mastered：技能才乘 masteryDamage(initial, 等级)；算不出时照原样（number(…, initial)）
static func damage(item: Dictionary, a, initial: float) -> float:
	if item.is_empty() or XBattleLogic.is_item(item) or not item.has("id"):
		return initial
	var id := int(item.id)
	var f := str(data(id).damage)
	var cat := float(XCat.mastery(a)) if f.contains("CodexCat.mastery") else 0.0
	var lv: int = a.skillMasteryLevelOf(id) if a.has_method("skillMasteryLevelOf") else a.skillMasteryLevel(id)  # 原版传 f.item（技能对象）
	if int(XYunshang.derived_frame.get("mastery_skill", 0)) == id:
		lv = int(XYunshang.derived_frame.mastery)  # 云裳派生伤害（nativeDamage 里临时换掉 subject.skillMasteryLevel）
	var v := eval(f, initial, float(lv), cat)
	return initial if is_nan(v) or is_inf(v) else v


## YEP skillMpCost／TpCost／HpCost 包装：kind 是 mp／tp／hp；费用为正时 ⌊公式(cost, 包装后等级)⌋，不低于 Minimum（算不出照原值）
static func cost(b, skill: Dictionary, kind: String, value: int) -> int:
	if value <= 0 or skill.is_empty() or XBattleLogic.is_item(skill):
		return value
	var id := int(skill.id)
	var v := eval(str(data(id)[kind]), float(value), float(effective(b, id, true)), 0.0, float(value))
	var lo := int(XDB.plugin("YEP_SkillMasteryLevels").get("Minimum %s Cost" % kind.to_upper(), "1"))
	return maxi(floori(v) if not (is_nan(v) or is_inf(v)) else value, lo)


## applyCooldownMods 包装：冷却为正时 ⌊公式(turns, 包装后等级)⌋，不低于 Minimum Cooldown
static func cooldown(b, skill_id: int, turns: float) -> float:
	if turns <= 0.0:
		return turns
	var v := eval(str(data(skill_id).cooldown), turns, float(effective(b, skill_id, true)), 0.0, turns)
	var lo := float(XDB.plugin("YEP_SkillMasteryLevels").get("Minimum Cooldown", "1"))
	return maxf(lo, floorf(v) if not (is_nan(v) or is_inf(v)) else turns)


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
