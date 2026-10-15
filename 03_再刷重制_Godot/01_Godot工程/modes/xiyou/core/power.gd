class_name XPower
extends RefCounted
## 战力：移植自正式版 js/codex/runtime/installCombatPowerRuntime.js（CodexCombatPower v2）。
## 只是派生显示，不改任何数据。参照：mv_oracle/power_probe.cjs → generated/oracle/power.json（xiyou_power 逐例比对）。
##
## 装备评分 equipment(装备)：与穿戴者无关，按公共参照属性（生命 1000、魔法 300、其余 100）把基础属性、特性、
## 战力相关备注与被动状态折成「输出／生存／辅助」三项分数，再加「命中 / 暴击与伤害乘区」（三档参照的伤害预演增益）。
## 法宝（<Magic Weapon>）按等级×每级属性另加「法宝成长」；法宝升级未做，等级取 CP_MagicWeapon 的初始等级。
## 未移植：渡鸦／米拉／甚尔／狂妄／心钢的专属装备加成（对应角色未接入）。

const NAMES := ["生命", "魔法", "物攻", "物防", "魔攻", "魔防", "敏捷", "幸运"]
## 公共参照属性：装备评分与穿戴者无关
const REFERENCE := [1000.0, 300.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0]
const WEIGHTS := [[0, 0.08, 0], [0, 0, 0.06], [3, 0, 0], [0, 2, 0], [3, 0, 0], [0, 2, 0], [0.8, 0.2, 0.5], [0.2, 0, 0.2]]
const X_WEIGHTS := [[1000, 0, 0], [0, 1200, 0], [1500, 0, 0], [0, 800, 0], [0, 1000, 0], [0, 1200, 0], [1200, 0, 0], [0, 2000, 0], [0, 0, 600], [0, 0, 400]]
const X_NAMES := ["命中", "闪避", "暴击", "暴击闪避", "魔法闪避", "魔法反射", "反击", "生命再生", "魔法再生", "怒气再生"]
const LABELS := ["输出", "生存", "辅助"]
## 前／中／后期参照：命中、暴击率、暴击倍率、终伤倍率与权重
const GEAR_REFERENCES := [{"weight": 0.1, "hit": 0.95, "crit": 0.25, "critical": 1.5, "final": 1.0},
	{"weight": 0.2, "hit": 1.0, "crit": 0.75, "critical": 3.0, "final": 3.0},
	{"weight": 0.7, "hit": 1.0, "crit": 1.0, "critical": 5.0, "final": 8.0}]
const ABNORMAL := "毒|诅咒|灼伤|流血|封印|沉默|眩晕|麻痹|虚弱"

static var _gear_cache := {}
static var _ref_cache := {}


## 设置页「战力显示与估算」（ConfigManager.codexPowerEnabled，默认开）
static func enabled() -> bool:
	return XConfig.flag("codexPowerEnabled")


## format：≥1 万用「万／亿／万亿」两位小数，其余取整
static func format(v: float) -> String:
	v = js_round(v)
	var a := absf(v)
	if a >= 1e12:
		return "%.2f万亿" % (v / 1e12)
	if a >= 1e8:
		return "%.2f亿" % (v / 1e8)
	if a >= 1e4:
		return "%.2f万" % (v / 1e4)
	return str(int(v))


## JS Math.round：.5 向正无穷
static func js_round(v: float) -> float:
	return floorf(v + 0.5)


## 背包实例（kind）或数据库基础记录（wtypeId／atypeId）
static func _is_gear(item: Dictionary) -> bool:
	return XItemMarks.is_gear(item) or item.has("wtypeId") or item.has("atypeId")


static func _is_weapon(item: Dictionary) -> bool:
	return str(item.get("kind", "")) == "weapon" if XItemMarks.is_gear(item) else item.has("wtypeId")


static func _empty() -> Dictionary:
	return {"parts": [0.0, 0.0, 0.0], "rows": []}


static func _add(s: Dictionary, label: String, values: Array) -> void:
	if not values.any(func(v): return float(v) != 0.0):
		return
	var total := 0.0
	for i in range(3):
		s.parts[i] += float(values[i])
		total += float(values[i])
	s.rows.append({"label": label, "parts": values.map(func(v): return float(v)), "value": total})


## 物防／魔防按 CodexDamage.defenseRate 折成「承伤减少」后再乘权重
static func _attribute(s: Dictionary, id: int, value: float, label := "") -> void:
	if id == 3 or id == 5:
		var d: float = REFERENCE[id]
		value = (XDamage.defense_rate(100, d) / XDamage.defense_rate(100, maxf(0.0, d + value)) - 1.0) * 200.0
	_add(s, label if label != "" else NAMES[id], WEIGHTS[id].map(func(w): return value * w))


static func _finish(s: Dictionary) -> Dictionary:
	var sum := 0.0
	var positive := 0.0
	for v in s.parts:
		sum += v
		positive += maxf(0.0, v)
	var total := maxf(0.0, js_round(sum))
	var ratio := total / positive if positive != 0.0 else 0.0
	var p: Array = s.parts.map(func(v): return maxf(0.0, v) * ratio)
	p[0] = minf(total, js_round(p[0]))
	p[1] = minf(total - p[0], js_round(p[1]))
	p[2] = total - p[0] - p[1]
	s.parts = p
	s.total = total
	return s


static func _pools(s: Dictionary) -> Dictionary:
	if not s.has("effects"):
		s.effects = {"x": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "critical": 0.0, "final": 0.0, "elements": {}, "magnify": {},
			"penetrate": {"fixed": {}, "percent": {}}, "weapons": {}, "physical": 1.0, "magical": 1.0}
	return s.effects


static func _clamp01(v: float) -> float:
	return clampf(v, 0.0, 1.0)


## 特性：21 能力倍率（attributesIncluded 时不计）、22 附加能力进池、23 特殊能力、11 元素抗性、13 状态抵抗、14 状态免疫、
## 32 攻击附加状态、33 攻击速度、34 攻击次数、61 额外行动、62 保护队友、64 先制/防偷袭
static func _traits(s: Dictionary, obj: Dictionary, attributes_included: bool) -> void:
	for t in obj.get("traits", []):
		var code := int(t.code)
		var id := int(t.dataId)
		var v := float(t.value)
		var a := [0.0, 0.0, 0.0]
		var label := ""
		if code == 21 and not attributes_included and id >= 0 and id < 8:
			_attribute(s, id, REFERENCE[id] * (v - 1.0), NAMES[id] + "倍率")
			continue
		if code == 22 and id >= 0 and id < 10:
			_pools(s).x[id] += v
			continue
		if code == 23:
			match id:
				1:
					a[1] = (v - 1.0) * 400.0; label = "防御效果"
				2:
					a[2] = (v - 1.0) * 800.0; label = "治疗效果"
				3:
					a[2] = (v - 1.0) * 150.0; label = "药品效果"
				4:
					a[2] = (1.0 - v) * 600.0; label = "魔法减耗"
				5:
					a[2] = (v - 1.0) * 400.0; label = "怒气获得"
				6, 7:
					a[1] = (1.0 - v) * 1200.0; label = "物理减伤" if id == 6 else "魔法减伤"
		if code == 11:
			a[1] = (1.0 - v) * 120.0; label = "元素抗性"
		if code == 13:
			a[1] = (1.0 - v) * 60.0; label = "状态抵抗"
		if code == 14:
			var st := XDB.rec("States", id)
			if not st.is_empty() and (int(st.get("restriction", 0)) > 0 or RegEx.create_from_string(ABNORMAL).search(str(st.get("name", ""))) != null):
				a[1] = 80.0; label = "异常免疫"
		if code == 32:
			a[2] = _clamp01(v) * 100.0; label = "攻击附加状态"
		if code == 33:
			a[0] = v * 2.0; label = "攻击速度"
		if code == 34:
			a[0] = v * 600.0; label = "额外攻击次数"
		if code == 61:
			a[0] = _clamp01(v) * 600.0; a[2] = _clamp01(v) * 200.0; label = "额外行动"
		if code == 62 and id == 2:
			a[1] = 150.0; a[2] = 150.0; label = "保护队友"
		if code == 64 and (id == 2 or id == 3):
			a[2] = 80.0; label = "先制" if id == 3 else "防偷袭"
		if label != "":
			_add(s, label, a)


static func _matches(note: String, pattern: String) -> Array:
	return RegEx.create_from_string("(?i)" + pattern).search_all(note)


## YEP_AutoPassiveStates：<Passive State: a, b> 与 <Passive State: a to b>
static func passive_states(obj: Dictionary) -> Array:
	var out := []
	var one := RegEx.create_from_string("(?i)<(?:PASSIVE STATE):[ ]*(\\d+(?:\\s*,\\s*\\d+)*)>")
	var range_re := RegEx.create_from_string("(?i)<(?:PASSIVE STATE):[ ](\\d+)[ ](?:THROUGH|to)[ ](\\d+)>")
	for line in str(obj.get("note", "")).split("\n"):
		var m := one.search(line)
		if m:
			for n: RegExMatch in RegEx.create_from_string("\\d+").search_all(m.get_string(1)):
				out.append(int(n.get_string()))
			continue
		m = range_re.search(line)
		if m:
			for i in range(int(m.get_string(1)), int(m.get_string(2)) + 1):
				out.append(i)
	return out


## G_StateParam：<G_ShuXing> … </G_ShuXing> 之间「名字 = ±数」，ALL 加到全部 8 项
static func state_params(state: Dictionary) -> Array:
	var out := [0, 0, 0, 0, 0, 0, 0, 0]
	var on := false
	var line_re := RegEx.create_from_string("(.*)[ ]=[ ]([\\+\\-]\\d+)")
	for line in str(state.get("note", "")).split("\n"):
		if RegEx.create_from_string("(?i)<G_ShuXing>").search(line):
			on = true
		elif RegEx.create_from_string("(?i)</G_ShuXing>").search(line):
			on = false
		elif on:
			var m := line_re.search(line)
			if m:
				var id := _shuxing(m.get_string(1).to_upper().strip_edges())
				if id == 8:
					for j in range(8):
						out[j] += int(m.get_string(2))
				elif id >= 0:
					out[id] += int(m.get_string(2))
	return out


static func _shuxing(s: String) -> int:
	for pair in [[["MHP", "MAXHP", "MAX HP", "HP"], 0], [["MMP", "MAXMP", "MAX MP", "MP"], 1], [["ATK", "ATTACK"], 2], [["DEF", "DEFENSE"], 3],
			[["MAT", "MAGIC ATTACK", "M.ATTACK", "INT"], 4], [["MDF", "MAGIC DEFENSE", "M.DEFENSE", "RES"], 5], [["AGI", "AGILITY", "SPD"], 6], [["LUK"], 7], [["ALL"], 8]]:
		if pair[0].has(s):
			return pair[1]
	return -1


## 战力相关备注：伤害乘区进池（终伤、暴伤、元素、武器类型、穿透、独立乘区），其余直接折分；被动状态递归（状态的特性、G_ShuXing、备注）
static func _notes(s: Dictionary, obj: Dictionary, visited := {}, is_state := false) -> void:
	var note := str(obj.get("note", ""))
	var p := _pools(s)
	for m: RegExMatch in _matches(note, "<(passiveHarmRi|passiveCrHarmRi|passiveELUP\\d+|passiveHEUP|passiveAPLUS|passiveHarmRe\\d+|SkillCriPush(?:All|Mf|Zj)|SkETypeHarmRi\\d+|DBHPLSteal)\\s*:\\s*([+-]?\\d+(?:\\.\\d+)?)\\s*%?\\s*>"):
		var key := m.get_string(1).to_lower()
		var v := float(m.get_string(2))
		if key == "passiveharmri":
			p.final += v / 100.0
		elif key == "passivecrharmri":
			p.critical += v / 100.0
		elif key.begins_with("passiveelup"):
			var e := int(key.trim_prefix("passiveelup"))
			p.elements[e] = float(p.elements.get(e, 0.0)) + v / 100.0
		elif key.begins_with("sketypeharmri"):
			var wt := int(key.trim_prefix("sketypeharmri"))
			p.weapons[wt] = float(p.weapons.get(wt, 0.0)) + v / 100.0
		elif key == "passiveheup":
			_add(s, "治疗增幅", [0, 0, v * 8])
		elif key == "passiveaplus":
			_add(s, "再行动", [clampf(v, 0, 100) * 6, 0, clampf(v, 0, 100) * 2])
		elif key.begins_with("passiveharmre"):
			_add(s, "固定减伤", [0, v * 0.1, 0])
		elif key.begins_with("skillcripush"):
			p.x[2] += v / 100.0
		elif key == "dbhplsteal":
			_add(s, "生命吸取", [0, v * 6, 0])
	for m: RegExMatch in _matches(note, "<Element Amplify (\\d+):\\s*([+-]?[\\d.]+)%\\s*>"):
		var e := int(m.get_string(1))
		p.elements[e] = float(p.elements.get(e, 0.0)) + float(m.get_string(2)) / 100.0
	for m: RegExMatch in _matches(note, "<Element Magnify (\\d+):\\s*([+-]?[\\d.]+)%\\s*>"):
		var e := int(m.get_string(1))
		p.magnify[e] = float(p.magnify.get(e, 0.0)) + float(m.get_string(2)) / 100.0
	for m: RegExMatch in _matches(note, "<DepassiveHarmRe(\\d+):\\s*([+-]?[\\d.]+)(%?)\\s*>"):
		var pool := "percent" if m.get_string(3) != "" else "fixed"
		var e := int(m.get_string(1))
		p.penetrate[pool][e] = float(p.penetrate[pool].get(e, 0.0)) + float(m.get_string(2))
	for m: RegExMatch in _matches(note, "<passivePBST([0-7]):\\s*([+-]?\\d+(?:\\.\\d+)?)(%?)\\s*>"):
		var id := int(m.get_string(1))
		_attribute(s, id, float(m.get_string(2)) * (REFERENCE[id] / 100.0 if m.get_string(3) != "" else 1.0), "被动属性 · " + NAMES[id])
	for m: RegExMatch in _matches(note, "<passiveXPBST([0-9]):\\s*([+-]?\\d+(?:\\.\\d+)?)%?\\s*>"):
		p.x[int(m.get_string(1))] += float(m.get_string(2)) / 100.0
	for m: RegExMatch in _matches(note, "<passiveSPBST([0-9]):\\s*([+-]?\\d+(?:\\.\\d+)?)%?\\s*>"):
		_traits(s, {"traits": [{"code": 23, "dataId": int(m.get_string(1)), "value": 1.0 + float(m.get_string(2)) / 100.0}]}, true)
	for m: RegExMatch in _matches(note, "<AgainUse(?:All|Mf|Zj|\\d+):\\s*([+-]?\\d+(?:\\.\\d+)?)%?\\s*>"):
		_add(s, "额外释放", [clampf(float(m.get_string(1)), 0, 100) * 6, 0, 0])
	var phys := RegEx.create_from_string("(?i)<SelfPhysRate:([\\d.]+)>").search(note)
	if phys:
		p.physical *= float(phys.get_string(1))
	var elem := RegEx.create_from_string("(?i)<SelfElemRate:([\\d.]+)>").search(note)
	if elem:
		p.magical *= float(elem.get_string(1))
	# 状态没有 passiveStates（YEP_AutoPassiveStates 只处理角色、职业、装备、敌人、技能）
	for id in ([] if is_state else passive_states(obj)):
		if visited.has(id):
			continue
		visited[id] = true
		var st := XDB.rec("States", id)
		if st.is_empty():
			continue
		_traits(s, st, false)
		var sx := state_params(st)
		for i in range(8):
			_attribute(s, i, float(sx[i]), "装备被动 · " + NAMES[i])
		_notes(s, st, visited, true)


## gearEffects：三档参照下「装上 vs 不装」的期望伤害之比（命中、暴击、暴伤、终伤、元素、武器类型、穿透、独立乘区），
## 乘 (2000 + 已有输出分)；另把附加能力 1、3～9 按有效值（0.05 起算）折分
static func _gear_effects(s: Dictionary, item: Dictionary) -> void:
	var p := _pools(s)
	var weapon := 0.0
	if _is_weapon(item):
		weapon = float(p.weapons.get(int(item.get("wtypeId", 0)), 0.0))
	else:
		for k in p.weapons:
			weapon = maxf(weapon, float(p.weapons[k]))
		weapon *= 0.5
	var gain := 0.0
	for r in GEAR_REFERENCES:
		var key := JSON.stringify(r)
		if not _ref_cache.has(key):
			_ref_cache[key] = _reference_damage(r, p, weapon, false)
		var before: float = _ref_cache[key]
		var after := _reference_damage(r, p, weapon, true)
		gain += float(r.weight) * (after / before - 1.0 if before != 0.0 else 0.0)
	_add(s, "命中 / 暴击与伤害乘区", [(2000.0 + maxf(0.0, s.parts[0])) * gain, 0, 0])
	for i in range(1, 10):
		if i == 2:
			continue
		var effective := _clamp01(0.05 + float(p.x[i])) - 0.05
		_add(s, X_NAMES[i], X_WEIGHTS[i].map(func(w): return effective * w))


## 参照伤害（CodexDamage.calculate 预演，reference 模式）：攻防各 100、公式 1,000,000、物理一半＋13 种元素均分一半；
## 目标每种元素固定减伤 25000×终伤倍率（扣在四舍五入之后）；结果×命中率
static func _reference_damage(r: Dictionary, p: Dictionary, weapon: float, with_gear: bool) -> float:
	var g := 1.0 if with_gear else 0.0
	var final_mult := maxf(0.0, 1.0 + float(r.final) - 1.0 + g * float(p.final))
	var crit_mult := maxf(1.0, 1.5 + float(r.critical) - 1.5 + g * float(p.critical))
	var normal_mult := maxf(0.0, 1.0 + g * weapon)
	var hit := _clamp01(float(r.hit) + g * float(p.x[0]))
	var cri := _clamp01(float(r.crit) + g * float(p.x[2]))
	var own := func(e: int) -> float:
		return g * (float(p.elements.get(e, 0.0)) + float(p.magnify.get(e, 0.0)))
	var sum := 0.0
	var elements := [1] + XDamage.ACTIVE
	for e in elements:
		var bonus: float = own.call(e)
		if e >= 11 and e <= 15:
			var common := INF
			for c in [2, 3, 4, 5, 6, 7, 8, 9]:
				common = minf(common, own.call(c))
			bonus = maxf(bonus, common)
		var independent := (float(p.physical) if e == 1 else float(p.magical)) if with_gear else 1.0
		var gross := 1000000.0 * normal_mult * maxf(0.0, 1.0 + bonus) * final_mult * 0.5 * independent
		var flat := 25000.0 * float(r.final)
		if with_gear:
			flat = maxf(0.0, flat - float(p.penetrate.fixed.get(e, 0.0))) * (1.0 - clampf(float(p.penetrate.percent.get(e, 0.0)), 0.0, 100.0) / 100.0)
		var normal := _settle(gross, flat)
		var crit := _settle(gross * crit_mult, flat)
		sum += (normal * (1.0 - cri) + crit * cri) * (0.5 if e == 1 else 0.5 / XDamage.ACTIVE.size())
	return sum * hit


## compute 的 Math.round（>0 时至少 1），再 finishSettlement 扣固定减伤并四舍五入
static func _settle(gross: float, flat: float) -> float:
	var v := js_round(gross)
	if gross > 0.0 and v == 0.0:
		v = 1.0
	return js_round(maxf(0.0, v - flat))


## 数据库基础记录的属性：正式版载入时 YEP_CoreEngine 用备注 <atk: +300> 等覆盖 params（背包实例在 XGear.create 已覆盖）
static func base_params(rec: Dictionary) -> Array:
	var params: Array = rec.get("params", []).duplicate()
	for m: RegExMatch in RegEx.create_from_string("(?i)<(HP|MAXHP|MAX HP|MHP|MP|MAXMP|MAX MP|MMP|ATK|STR|DEF|MAT|INT|SPI|MDF|RES|AGI|SPD|LUK):\\s*([+-]\\d+)>").search_all(str(rec.get("note", ""))):
		params[XGear.param_id(m.get_string(1))] = int(m.get_string(2))
	return params


## CP_MagicWeapon：等级（法宝升级未做，取 <Init Level: n>，缺省 1）
static func magic_level(item: Dictionary) -> int:
	if item.has("level"):
		return int(item.level)
	var init := int(roundf(float(str(item.get("meta", {}).get("Init Level", "0")).to_float())))
	return init if init != 0 else 1


## CP_MagicWeapon loadMagicWeaponBaseParam：<atk Param +30 per Level>（三字母小写属性名）
static func magic_growth(item: Dictionary) -> Array:
	var out := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var ids := ["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"]
	for m: RegExMatch in RegEx.create_from_string("<([a-z]{3}) Param ([+-]\\d+(\\.\\d+)*) per Level>").search_all(str(item.get("note", ""))):
		var i := ids.find(m.get_string(1))
		if i >= 0:
			out[i] = m.get_string(2).to_float()
	return out


## 装备评分 {total, parts[输出,生存,辅助], rows[{label, parts, value}]}；关掉战力或不是装备时为 0
static func equipment(item: Dictionary) -> Dictionary:
	if not enabled() or not _is_gear(item):
		return _finish(_empty())
	var sig := JSON.stringify([item.get("params"), item.get("traits"), item.get("note"), item.get("level")])
	if _gear_cache.has(sig):
		return _gear_cache[sig]
	var s := _empty()
	var params: Array = item.get("params", []) if XItemMarks.is_gear(item) else base_params(item)
	for i in range(mini(8, params.size())):
		_attribute(s, i, float(params[i]), "基础属性 · " + NAMES[i])
	var magic := RegEx.create_from_string("(?i)<Magic Weapon>").search(str(item.get("note", ""))) != null
	var level := maxi(0, magic_level(item)) if magic else 0
	if magic:
		var plus := magic_growth(item)
		for i in range(8):
			_attribute(s, i, plus[i] * level, "法宝成长 · " + NAMES[i])
	_traits(s, item, false)
	_notes(s, item)
	_gear_effects(s, item)
	s.level = level
	s = _finish(s)
	_gear_cache[sig] = s
	return s
