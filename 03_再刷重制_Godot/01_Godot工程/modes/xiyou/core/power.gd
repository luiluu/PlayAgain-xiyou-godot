class_name XPower
extends RefCounted
## 战力：移植自正式版 js/codex/runtime/installCombatPowerRuntime.js（CodexCombatPower v2）。
## 只是派生显示，不改任何数据。参照：mv_oracle/power_probe.cjs → generated/oracle/power.json（xiyou_power 逐例比对）。
##
## 装备评分 equipment(装备)：与穿戴者无关，按公共参照属性（生命 1000、魔法 300、其余 100）把基础属性、特性、
## 战力相关备注与被动状态折成「输出／生存／辅助」三项分数，再加「命中 / 暴击与伤害乘区」（三档参照的伤害预演增益）。
## 法宝（<Magic Weapon>）按等级×每级属性另加「法宝成长」；等级取实例等级（XMagicWeapon 升级后写在实例上，缺省 CP_MagicWeapon 的初始等级）。
## 种族祝福（CodexRaces.powerAdjust 等，见 XRaceBattle.power_*）：参照 race_battle_probe.cjs 的 power.*，测试 xiyou_race_battle。
## 狂妄／心钢的成长加成见 _growth_gear，渡鸦／米拉／甚尔的专属装备加成见 _exclusive_gear。

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


static func clear_cache() -> void:
	_gear_cache.clear()
	_actor_cache.clear()


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


## JS Math.round：.5 向正无穷。先取 floor 再按小数部分进位，不对原值先加 0.5——大整数（如 ±2^52 以上的奇数）
## 加 0.5 会在双精度里先被舍入改值（-4503599627370497 + 0.5 得 -4503599627370496），floor 再也还原不了。
## NaN／±Infinity 原样返回；负零（Math.round(-0.4)＝-0）不区分。
static func js_round(v: float) -> float:
	var f := floorf(v)
	return f + 1.0 if v - f >= 0.5 else f


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


## 专属法宝（认底子）：渡鸦 4001 加专属固定属性（ARTIFACT_BASE_BONUS，物攻 0 不记行）、米拉 4577 元素 2 增伤＋20%、甚尔 4580 物理池 ×1.11。
## 参照 growth_help_probe 的 powerOnly，专项 xiyou_growth_help。
static func _exclusive_gear(s: Dictionary, item: Dictionary) -> void:
	if _is_weapon(item):
		return
	match XHeartsteel.base_id(item):
		XRaven.ARTIFACT:
			for i in range(XRaven.ARTIFACT_BASE_BONUS.size()):
				_attribute(s, i, float(XRaven.ARTIFACT_BASE_BONUS[i]), "专属固定 · " + NAMES[i])
		XMira.ARMOR:
			_pools(s).elements[2] = float(_pools(s).elements.get(2, 0.0)) + 0.2
		XToji.ARMOR:
			_pools(s).physical *= 1.11


## gearEffects：三档参照下「装上 vs 不装」的期望伤害之比（命中、暴击、暴伤、终伤、元素、武器类型、穿透、独立乘区），
## 乘 (2000 + 已有输出分)；另把附加能力 1、3～9 按有效值（0.05 起算）折分
## 成长装备按当前阶数（2026-10-08 原版）：狂妄／无我物理池 ×(1＋(扬名倍率−1)×0.6)；心钢／利维坦生命按参照
## ×(生命倍率−1) 记一行、回合末回复（x[7]）＋3%／5%。参照 growth_help_probe 的 power，专项 xiyou_growth_help。
static func _growth_gear(s: Dictionary, item: Dictionary) -> void:
	if _is_weapon(item):
		return
	if XHubris.is_gear(item):
		_pools(s).physical *= 1.0 + (XHubris.rate_for(item, XHubris.growth(item)) - 1.0) * 0.6
	if XHeartsteel.is_gear(item):
		var rate := XHeartsteel.hp_rate(item)
		if rate != 1.0:
			_attribute(s, 0, REFERENCE[0] * (rate - 1.0), "心钢 · 生命×%.1f（层数%d，第%d阶）" % [rate, XHeartsteel.stacks(item), XHeartsteel.stage(item)])
		_pools(s).x[7] += 0.05 if XHeartsteel.is_leviathan(item) else 0.03


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
	# 缓存键含全部输入：正式版按物品对象缓存，Godot 用一张表，故另加种类与武器／防具类型（_is_weapon、武器类型乘区要用）
	var sig := JSON.stringify([item.get("kind"), item.get("wtypeId"), item.get("atypeId"), item.get("params"), item.get("traits"),
		item.get("note"), item.get("level"), item.get(XHeartsteel.STACKS), item.get(XHubris.FAME), item.get("base")])
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
	_exclusive_gear(s, item)
	_growth_gear(s, item)
	_gear_effects(s, item)
	s.level = level
	s = _finish(s)
	_gear_cache[sig] = s
	return s


# ======================================================================
# 角色战力（CodexCombatPower.actor）：只读的整套配置评估，不改真实角色
# ======================================================================
## 三档中性敌人（防御、权重）：先评中档，再评低、高档
const PROFILES := [{"def": 100.0, "weight": 0.3}, {"def": 10000.0, "weight": 0.4}, {"def": 1000000.0, "weight": 0.3}]
const NANO_STATES := [1522, 1708, 1709, 1763, 1765, 1768, 1769, 1770, 1771, 1772, 1773, 1774, 1775, 1776, 1777, 1778, 1780, 1781, 1782,
	1783, 1784, 1785, 1786, 1789, 1792, 1793, 1794, 1795, 1796, 1797, 1798, 1799, 1800, 1801, 1802, 1803, 1804, 1805, 1806, 1807]
const ENVIRONMENT := "^(?:轮回模式|灭世挑战|天灾难度|强者增强.*洪荒|天道诅咒|强者压制)"
const DAMAGE_TYPES := [1, 2, 5, 6]

static var _actor_cache := {}
static var _formula_ok := {}


## 中性敌人：生命 100 万、攻击类 1 万、防御按档位、敏捷幸运 100；命中 1、其余附加能力 0、特殊能力 1、属性有效度 1、无属性体质
class NeutralEnemy extends XBattler:
	var params := []

	func _init(defense: float) -> void:
		params = [1000000.0, 10000.0, 10000.0, defense, 10000.0, defense, 100.0, 100.0]
		hp = params[0]
		mp = params[1]

	func param(i: int) -> float:
		return params[i]

	func param_base(i: int) -> float:
		return params[i]

	func xparam(i: int) -> float:
		return 1.0 if i == 0 else 0.0

	func sparam(_i: int) -> float:
		return 1.0

	func element_rate(_e: int) -> float:
		return 1.0

	func passive_cache() -> Dictionary:
		return {"harmRe": {}, "penetrateFixed": {}, "penetratePercent": {}, "globalHarmRi": 0.0, "critHarmRi": 0.0}


static var _CUSTOM_FORMULA := RegEx.create_from_string("(?im)^.*<damage formula>")


static func _js_formula(f: String) -> String:
	var re := RegEx.create_from_string("Math\\.(floor|ceil)\\(Math\\.random\\(\\)\\s*\\*\\s*(\\d+)\\)")
	var m := re.search(f)
	while m:
		var n := int(m.get_string(2))
		f = f.substr(0, m.get_start()) + "(%s/2)" % str(n - 1 if m.get_string(1) == "floor" else n + 1) + f.substr(m.get_end())
		m = re.search(f)
	return f.replace("Math.random()", "0.5")


## compileFormula：只认受限写法（能力值、熟练度、状态、变量、Math 函数与常数运算），其余技能不计入（coverage.unknown）。
## 备注里有 <damage formula> 段的技能，正式版载入时 YEP_DamageCore 把 damage.custom 设为真，一律不计入。
static func formula_ok(skill: Dictionary) -> bool:
	var d: Dictionary = skill.get("damage", {})
	var custom := bool(d.get("custom", false)) or _CUSTOM_FORMULA.search(str(skill.get("note", ""))) != null
	var key := str(d.get("formula", "0")) + "|" + str(custom)
	if _formula_ok.has(key):
		return _formula_ok[key]
	var ok := false
	if not custom:
		var s := _js_formula(str(d.get("formula", "0")))
		for p in ["Codex(?:Raven\\.(?:legionStrikeRate|skillCoefficient|defenseFactor|defenseDeduction)|Mira\\.damage|Yomi\\.damage|Jingliu\\.damage|Toji\\.damage|Sukuna\\.damage|Garou\\.base)\\b",
				"CodexYunshang\\.formula\\b", "Codex(?:Tusu|Xuan)\\.(?:damage|heal)\\(a,\\s*b(?:,\\s*'\\w+')?\\)",
				"(?:a|b|user|target|subject)\\.(?:skillMasteryLevel|isStateAffected|hpRate|mpRate|tpRate|param|xparam|sparam)\\b",
				"(?:a|b|user|target|subject)\\.(?:mhp|mmp|hp|mp|tp|atk|def|mat|mdf|agi|luk|level|hit|cri|pdr|mdr|rec)\\b",
				"Math\\.(?:floor|ceil|round|max|min|abs|pow|sqrt|log)\\b", "item\\.id", "v\\[\\d+\\]", "\\b(?:a|b|user|target|subject|this|true|false)\\b"]:
			s = RegEx.create_from_string(p).sub(s, "1", true)
		ok = RegEx.create_from_string("^[\\d\\s.eE+*/()%\\-,?:<>=!&|]+$").search(s) != null \
			and RegEx.create_from_string("[;{}\\[\\]'\"`]").search(s) == null \
			and RegEx.create_from_string("(?<![<>=!])=(?!=)").search(s) == null
	_formula_ok[key] = ok
	return ok


## 预演用的技能副本：公式里的随机数固定为 0.5（正式版评估期间 Math.random 恒为 0.5）
static func _preview_skill(skill: Dictionary) -> Dictionary:
	var item := skill.duplicate()
	item.damage = skill.damage.duplicate()
	if item.damage.get("formulaGd") is String:
		item.damage.formulaGd = str(item.damage.formulaGd).replace("randf()", "0.5")
	return item


static func _environment(rec: Dictionary) -> bool:
	return not rec.is_empty() and RegEx.create_from_string(ENVIRONMENT).search(str(rec.get("name", ""))) != null


## isolatedActor：复制角色（naked 时不穿装备），去掉环境技能/状态与战斗中状态，增减益清零，生命魔法补满
static func _isolated(actor: XActor, naked: bool) -> XActor:
	var a := XEquipment.clone(actor)
	var learned: Array[int] = []
	for id in a.skill_ids:
		if not _environment(XDB.rec("Skills", id)):
			learned.append(id)
	a.skill_ids = learned
	var kept: Array[int] = []
	for id in a.state_ids:
		var st := XDB.rec("States", id)
		if not st.is_empty() and id != 1 and not _environment(st) and not bool(st.get("removeAtBattleEnd", false)) \
				and int(st.get("autoRemovalTiming", 0)) == 0 and not NANO_STATES.has(id):
			kept.append(id)
	a.state_ids = kept
	a.buffs = [0, 0, 0, 0, 0, 0, 0, 0]
	a.buff_turns = [0, 0, 0, 0, 0, 0, 0, 0]
	a.cooldowns = {}
	a.warmups = {}
	if naked:
		for i in range(a.equips.size()):
			a.equips[i] = null
	a.refresh_passive()
	# prepare：装备与技能上 <StartPushStateN: ≥100%> 的状态
	for tag in a.battle_start_state_tags():
		if tag[0] == "StartPushState" and float(tag[2]) >= 100.0 and not a.state_ids.has(int(tag[1])) and int(tag[1]) != 1:
			a.add_state(int(tag[1]), XRandomStream.create("123456789abcdef0", "preview"))
	a.refresh_passive()
	a.hp = a.mhp
	a.mp = a.mmp
	a.tp = 0.0
	return a


static func _attack_skill(a: XActor) -> Dictionary:
	return a.attack_skill()  # $dataSkills[a.attackSkillId()]


static func _vars() -> Array:
	var v: Array = XState.current.variable_array().duplicate() if XState.current else []
	while v.size() <= 20:
		v.append(0)
	v[20] = 0
	return v


## repeatCount：(重复次数＋普攻追加次数＋再次使用概率) × 行动序列里 ACTION EFFECT 段数
static func _repeat_count(a: XActor, item: Dictionary) -> float:
	var base := float(item.get("repeats", 1))
	if int(item.id) == a.attack_skill_id():
		base += a.attack_times_add()
	var chance := 0.0
	var by := "Zj" if int(item.get("stypeId", 0)) == 1 else "Mf" if int(item.get("stypeId", 0)) == 2 else ""
	for o in a.equip_list() + a.skills() + a.states():
		for m: RegExMatch in RegEx.create_from_string("<AgainUse(All|Mf|Zj|\\d+):\\s*([+-]?\\d+(?:\\.\\d+)?)%?\\s*>").search_all(str(o.get("note", ""))):
			var k := m.get_string(1)
			if k == "All" or k == by or (k.is_valid_int() and int(k) == int(item.id)):
				chance += float(m.get_string(2))
	# 正式版只数整体/逐目标序列里大写的「ACTION EFFECT」（小写写法的序列算 1 段），与实战段数 yepEffects 不同
	var hits := 0
	var seq: Dictionary = item.get("yepSeq", {}) if item.get("yepSeq") is Dictionary else {}
	for cmd in seq.get("whole", []) + seq.get("target", []):
		if cmd is Array and not cmd.is_empty() and str(cmd[0]) == "ACTION EFFECT":
			hits += 1
	return (maxf(1.0, base) + clampf(chance / 100.0, 0.0, 1.0)) * maxf(1.0, float(hits))


## expected：先扣费用再预演普通与暴击伤害（含状态 Confirm/React），× 命中 ×(1−闪避) × 段数，群体按 60% 单体／40% 三体
## power：种族的本路线状态（XRaceBattle.power_cycle），血契与神族首魔、残响据此判
static func _expected(logic: XBattleLogic, a: XActor, t: XBattler, skill: Dictionary, cost: Dictionary, power: Dictionary = {}) -> float:
	if power.is_empty():
		power = XRaceBattle.power_cycle()  # 不在 _cycle 里调（测试直接预演）时自开一轮
	var item := _preview_skill(skill)
	var saved := [a.mp, a.hp, a.tp]
	a.mp = maxf(0.0, a.mp - float(cost.mp))
	a.hp = maxf(1.0, a.hp - float(cost.get("hp", 0.0)))
	a.tp = maxf(0.0, a.tp - float(cost.tp))
	var vars := _vars()
	# battleRound：同实战传自然回合（哈基米巨龙减伤钩子缺它会返回 unavailable）
	var opts := {"critical": false, "variance": false, "vars": vars, "battleRound": maxi(1, logic.turn), "racePower": power,
		"racePowerBlood": bool(cost.get("raceBlood", false))}
	var normal := XDamage.finish(XDamage.calculate(item, a, t, opts), item, a, t, false, {"variables": vars})
	var critical := normal
	if bool(item.damage.get("critical", false)):
		var crit_opts := opts.duplicate()
		crit_opts.critical = true
		critical = XDamage.finish(XDamage.calculate(item, a, t, crit_opts), item, a, t, false, {"variables": vars})
	var p := _clamp01(a.cri * (1.0 - t.cev)) if bool(item.damage.get("critical", false)) else 0.0
	var hit := _clamp01(logic.item_hit(a, item, t)) * (1.0 - _clamp01(logic.item_eva(a, item, t)))
	a.mp = saved[0]
	a.hp = saved[1]
	a.tp = saved[2]
	var value := maxf(0.0, normal * (1.0 - p) + critical * p) * hit * _repeat_count(a, skill)
	var scope := int(skill.get("scope", 1))
	if scope == 2:
		value *= 1.8
	elif scope >= 3 and scope <= 6:
		value *= scope - 2
	# CodexRaces.powerAdjust：妖族群攻要拿有／无种族的单次预演之比
	value = XRaceBattle.power_adjust(a, skill, value, power, func(suppress: bool) -> float:
		var o := opts.duplicate()
		o.preview = true
		if suppress:
			o.raceSuppress = true
		return float(XDamage.calculate(item, a, t, o).get("value", 0.0)))
	return maxf(0.0, value)


static func _skills_for(a: XActor, coverage: Dictionary) -> Array:
	# 模型不施放强化/变身/切换类技能；条件当前不满足的伤害技能也不会出手，逐项披露（coverage 带 unmodeled 时）
	if coverage.has("unmodeled"):
		for s in a.skills():
			if int(s.get("occasion", 0)) >= 2 or int(s.get("stypeId", 0)) == 4 or not s.has("damage"):
				continue
			var type := int(s.damage.get("type", 0))
			if type == 0 and int(s.id) != XBattleLogic.GUARD_SKILL:
				var scope := int(s.get("scope", 0))
				coverage.unmodeled.append({"id": int(s.id), "name": s.name, "reason": "队友辅助" if scope >= 7 and scope <= 10 else "强化/变身/切换"})
			elif DAMAGE_TYPES.has(type) and formula_ok(s) and not _meets_ignoring_cost(a, s):
				coverage.unmodeled.append({"id": int(s.id), "name": s.name, "reason": "当前条件不可用"})
	var list: Array = a.skills().filter(func(s): return int(s.get("occasion", 0)) < 2 and DAMAGE_TYPES.has(int(s.get("damage", {}).get("type", 0))))
	var attack := _attack_skill(a)
	if not attack.is_empty() and not list.any(func(s): return int(s.id) == int(attack.id)):
		list.append(attack)
	var out := []
	var seen := {}
	for s in list:
		if seen.has(int(s.id)):
			continue
		seen[int(s.id)] = true
		if not formula_ok(s):
			coverage.unknown.append({"id": int(s.id), "name": s.name})
			continue
		coverage.known += 1
		out.append(s)
	return out


## meetsIgnoringCost：判断角色/形态条件时暂时补满魔法与 TP，判断后恢复
static func _meets_ignoring_cost(a: XActor, s: Dictionary) -> bool:
	var mp := a.mp
	var tp := a.tp
	a.mp = a.mmp
	a.tp = a.max_tp()
	var logic := XBattleLogic.new()
	logic.state = XState.current
	var ok := logic.can_use(a, s)
	a.mp = mp
	a.tp = tp
	return ok


static func _meta_int(skill: Dictionary, key: String) -> int:
	return int(str(skill.get("meta", {}).get(key, "0")).strip_edges().to_int())


## cycle：10 回合，每次行动在候选里挑当前能用（冷却、预热、费用）且期望伤害最高的技能；回合末按再生率回复、TP +5
static func _cycle(logic: XBattleLogic, a: XActor, t: XBattler, skills: Array) -> Dictionary:
	var damage := 0.0
	var first := 0.0
	var schedule := []
	var used := {}
	var cooldowns := {}
	var warmups := {}
	var cache := {}
	var power := XRaceBattle.power_cycle()  # CodexRaces.resetPowerCycle
	var raced := XRaceBattle.race_of(a) >= 0
	var cost_for := func(s: Dictionary) -> Dictionary:
		var c := logic.skill_cost(a, s)
		return XRaceBattle.power_cost(a, s, {"mp": float(c.mp), "tp": float(c.tp), "hp": 0.0}, power)
	var damage_for := func(s: Dictionary, c: Dictionary) -> float:
		var f := str(s.damage.get("formula", ""))
		# 同正式版：有种族时键带本路线种族状态（含回合号，每回合重算），不带生命（血契的生命门槛随缓存沿用）；
		# 没选种族时预演与种族状态无关，键不带它（省得每回合重算）
		var key := "%d|%s|%s|%s|%s" % [int(s.id), str(a.mp) if RegEx.create_from_string("\\.(?:mp|mpRate)").search(f) else "0",
			str(a.hp) if RegEx.create_from_string("\\.(?:hp|hpRate)").search(f) else "0", str(a.tp) if RegEx.create_from_string("\\.(?:tp|tpRate)").search(f) else "0",
			JSON.stringify(power) if raced else ""]
		if not cache.has(key):
			cache[key] = _expected(logic, a, t, s, c, power)
		return cache[key]
	for s in skills:
		warmups[int(s.id)] = maxi(0, _meta_int(s, "Warmup"))
	# screen：按期望伤害取前 8 个（同分保持原顺序），普攻保底
	var scored := []
	for i in range(skills.size()):
		scored.append([skills[i], damage_for.call(skills[i], cost_for.call(skills[i])), i])
	scored.sort_custom(func(x, y): return x[1] > y[1] or (x[1] == y[1] and x[2] < y[2]))
	var candidates: Array = scored.slice(0, 8).map(func(r): return r[0])
	var fallback = skills.filter(func(s): return int(s.id) == a.attack_skill_id())
	if not fallback.is_empty() and not candidates.has(fallback[0]):
		candidates.append(fallback[0])
	var actions := 1.0
	if XRaceBattle.race_of(a) == 2:
		actions += XRaceBattle.rate_of(a) / 2.0  # 人族九九六：期望多 q/2 次行动
	for tr in a.all_traits():
		if int(tr.code) == 61:
			actions += _clamp01(float(tr.value))
	for turn in range(1, 11):
		XRaceBattle.power_turn(power, turn)  # CodexRaces.startPowerTurn
		for index in range(ceili(actions)):
			var weight := minf(1.0, actions - index)
			var best := {}
			for s in candidates:
				var c: Dictionary = cost_for.call(s)
				var ready: bool = not (int(cooldowns.get(int(s.id), 0)) > 0 or int(warmups.get(int(s.id), 0)) > 0) \
					and c.mp <= a.mp and c.tp <= a.tp and c.hp < a.hp and logic.can_use(a, s)
				if not ready:
					continue
				used[int(s.id)] = true
				var v: float = damage_for.call(s, c)
				if best.is_empty() or v > best.value:
					best = {"skill": s, "cost": c, "value": v}
			if not best.is_empty():
				used[int(best.skill.id)] = true
				XRaceBattle.power_commit(a, best.skill, best.value, power)  # CodexRaces.commitPowerRoot
				damage += best.value * weight
				a.mp = maxf(0.0, a.mp - best.cost.mp * weight)
				a.tp = maxf(0.0, a.tp - best.cost.tp * weight)
				a.hp = maxf(1.0, a.hp - best.cost.hp * weight)
				cooldowns[int(best.skill.id)] = maxi(0, _meta_int(best.skill, "Cooldown"))
				schedule.append({"turn": turn, "id": int(best.skill.id), "damage": best.value * weight})
		a.mp = minf(a.mmp, a.mp + maxf(0.0, a.mmp * a.mrg))
		a.hp = minf(a.mhp, a.hp + maxf(0.0, a.mhp * a.hrg))
		a.tp = minf(a.max_tp(), a.tp + maxf(0.0, a.max_tp() * a.trg) + 5.0)
		for k in cooldowns:
			cooldowns[k] = maxi(0, int(cooldowns[k]) - 1)
		for k in warmups:
			warmups[k] = maxi(0, int(warmups[k]) - 1)
		if turn == 3:
			first = damage / 3.0
	return {"burst": first, "sustained": damage / 10.0, "schedule": schedule, "used": used}


static func _curve(value: float, reference: float, weight: float, exponent: float) -> float:
	return js_round(weight * pow(maxf(0.0, value) / reference, exponent))


## evaluate：三档防御下的 3 回合爆发／10 回合持续（输出）、有效生命（生存）、最大单次治疗×恢复率（辅助），各按曲线折分
static func evaluate(actor: XActor, naked: bool) -> Dictionary:
	if not enabled():
		return {}
	var logic := XBattleLogic.new()
	logic.state = XState.current
	var coverage := {"known": 0, "unknown": [], "unmodeled": []}
	var results := [null, null, null]
	var ehp := 0.0
	var aux := 0.0
	var params := []
	for index in [1, 0, 2]:
		var profile: Dictionary = PROFILES[index]
		var a := _isolated(actor, naked)
		var t := NeutralEnemy.new(float(profile.def))
		var skills := _skills_for(a, coverage if index == 1 else {"known": 0, "unknown": []})
		var out := _cycle(logic, a, t, skills)
		out.weight = profile.weight
		results[index] = out
		var avoidance := (clampf(a.eva, 0, 0.8) + clampf(a.mev, 0, 0.8)) / 2.0
		var rate := maxf(0.02, (maxf(0.0, a.pdr) + maxf(0.0, a.mdr)) / 2.0) * (1.0 - avoidance)
		var defense := 1.0 / ((XDamage.defense_rate(10000, a.def) + XDamage.defense_rate(10000, a.mdf)) / 2.0)
		ehp += float(profile.weight) * maxf(0.0, a.mhp) * (1.0 + minf(1.0, maxf(0.0, a.hrg) * 3.0)) * defense / rate
		if index == 0:
			for j in range(8):
				params.append(a.param(j))
			var heal := 0.0
			for s in a.skills():
				if not [3, 4].has(int(s.get("damage", {}).get("type", 0))) or not formula_ok(s):
					continue
				if float(logic.skill_cost(a, s).mp) > a.mmp:
					continue
				var amount := maxf(0.0, -XDamage.eval_formula(_preview_skill(s), a, a, _vars()))
				heal = maxf(heal, amount * (3.0 if int(s.scope) == 8 else 1.0) * maxf(0.0, a.rec))
			if XRaceBattle.race_of(a) == 0:
				heal *= 1.0 + XRaceBattle.rate_of(a)  # 神族祝福治疗 ×(1+q)
			aux = heal
	# 已在中档路线里实际可用或施放过的技能不再列为未计入
	coverage.unmodeled = coverage.unmodeled.filter(func(r): return not results[1].used.has(int(r.id)))
	if XRaceBattle.race_of(actor) == 6:
		coverage.unmodeled.append({"id": 0, "name": "蛮骨与反攻", "reason": "需敌方实际攻击，固定参照场景未计入"})
	var burst := 0.0
	var sustained := 0.0
	for r in results:
		burst += r.burst * r.weight
		sustained += r.sustained * r.weight
	var parts := [_curve(burst * 0.4 + sustained * 0.6, 1000, 600, 0.35), _curve(ehp, 1000, 300, 0.5), _curve(aux, 1000, 100, 0.5)]
	return {"total": parts[0] + parts[1] + parts[2], "parts": parts, "burst": burst, "sustained": sustained, "effectiveHp": ehp,
		"auxiliary": aux, "params": params, "coverage": coverage, "schedule": results[1].schedule}


static func _signature(a: XActor) -> String:
	return JSON.stringify([a.actor_id, a.class_id, a.level, a.skill_ids, a.state_ids, a.equips, XState.current.variable(8) if XState.current else 0,
		int(a.zhenqi.get("realm", 0)), XRaceBattle.data_of(a)])   # 突破改道法缩放而技能表可能不变；种族（含血契开关）


## 角色战力 {total, self, gear, gearScore, parts, selfParts, gearParts, equipment[{item, slot, score}], rows, evaluation, ownEvaluation}；关掉时全 0
## rows（自身成长来源明细）正式版恒为空数组，面板只写说明。
static func actor(a: XActor, force := false) -> Dictionary:
	if not enabled() or a == null:
		return {"self": 0, "gear": 0, "total": 0, "parts": [0, 0, 0], "selfParts": [0, 0, 0], "gearParts": [0, 0, 0], "equipment": [], "rows": []}
	var sig := _signature(a)
	if not force and _actor_cache.has(sig):
		return _actor_cache[sig]
	var own := evaluate(a, true)
	var full := evaluate(a, false)
	var gear_score := 0.0
	var worn := []
	for slot in range(a.equips.size()):
		var e = a.equips[slot]
		if e is Dictionary and _is_gear(e):
			var score := equipment(e)
			gear_score += float(score.total)
			worn.append({"item": e, "slot": slot, "score": score})
	var result := {"self": own.total, "gear": full.total - own.total, "gearScore": gear_score, "total": full.total, "parts": full.parts,
		"selfParts": own.parts, "gearParts": [full.parts[0] - own.parts[0], full.parts[1] - own.parts[1], full.parts[2] - own.parts[2]],
		"equipment": worn, "rows": [], "evaluation": full, "ownEvaluation": own}
	_actor_cache[sig] = result
	return result


## drawActorSimpleStatus 的战力行：技能/装备页「战力 N」（按需完整评估）；关掉战力时不画
static func status_text(a: XActor) -> String:
	return "战力 " + format(actor(a).total) if enabled() and a != null else ""


## 主菜单行：有有效缓存「战斗力 N」，否则「战力见状态」；关掉战力时不画
static func menu_text(a: XActor) -> String:
	if not enabled() or a == null:
		return ""
	var p := cached_actor(a)
	return "战力见状态" if p.is_empty() else "战斗力 " + format(p.total)


## 主菜单只读有效缓存（cachedActorPower）：没算过就是 {}，显示「战力见状态」
static func cached_actor(a: XActor) -> Dictionary:
	if not enabled() or a == null:
		return {}
	return _actor_cache.get(_signature(a), {})
