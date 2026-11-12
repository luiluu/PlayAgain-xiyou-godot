class_name XTianqiSkills
extends RefCounted
## 【cc·天启篇·未经审查】天启篇全角色技能重构（设计仓库《天启篇_全角色技能重构_v0.1》，Kyo 11-12 全部确认）。只对天启篇存档（XTianqi.active）生效，原版档不变。
## 数据：modes/xiyou/tianqi_data/skill_rework.json（只读）。分期补卡，第一期：全局规则、档位名单、狗逍遥与绿司机两张卡、共用的超越极限 I～IV。
##
## 怎么接：
## - 技能记录：XDB.rec("Skills", id) 遇到表里有的技能、且当前是天启篇存档时，换成改写后的副本（rec）。改写只动表里写的字段：
##   伤害换成模块公式（damage.formulaProgram.module＝"tianqi_skill"，XFormulaExecution 分派到 formula）、TP、MP（按最大魔法比例写成
##   <MP Cost: x%>）、冷却（<Cooldown: n>）、效果（按 code＋dataId 改值）、被动标签（note_remove／note_add），再按新备注重建 meta、
##   改写说明行（desc／header）。被动、领袖、费用、冷却都照原来读备注的路子生效，不用另接。
## - 伤害：Σ(权重×己方属性)×满级系数×等级缩放×条件；等级缩放 1 级是满级的一半、99 级满（rules.level1_ratio、level_max），敌人用这些技能按满级。
##   不留固定底数，熟练度不再乘进公式（formula 里的 skillMasteryLevel 读 0，见 XFormulaExecution）。
## - 熟练度：每级 +3%、上限 10 级（XSkillMastery.damage／max_level 读 mastery_bonus／mastery_cap）。
## - 再动、追加行动：角色每回合最多多 1 次（XBattleLogic.make_action_times 读 cap_actions）。
## - 档位：天启篇按 tiers 名单（超强者 18、强者 52、其余有名字的弱者，不开放的不进候选池）；三笠跟锻炼和进阶、饿狼跟形态升档，
##   只影响战斗里的档位加成和弱者协力（battle_tier），抽阵容、超强者上限按名单（tier_of）。
## 开关：ENABLED＝false 整套回原版（O-待定-1）；MASTERY 熟练度（O-待定-2）、ACTION_CAP 行动次数（O-待定-3）、TIERS 档位名单（O-待定-4）各管一条全局规则。

const PATH := "res://modes/xiyou/tianqi_data/skill_rework.json"
const MODULE := "tianqi_skill"
const HIDDEN := "不开放"
const STATS := ["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"]

static var ENABLED := true
static var MASTERY := true
static var ACTION_CAP := true
static var TIERS := true

static var _data: Dictionary = {}
static var _skills: Dictionary = {}  # int 技能号 → 改写规格
static var _recs: Dictionary = {}  # int 技能号 → 改写后的记录（按原记录缓存）
static var _tier: Dictionary = {}  # int 角色号 → 名单档位（含「不开放」）


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiSkills: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if not parsed is Dictionary:
			push_error("XTianqiSkills: JSON 解析失败 " + PATH)
			return {}
		_data = parsed
		_skills = {}
		for k in _data.get("skills", {}):
			_skills[int(k)] = _data.skills[k]
		_tier = {}
		for t in _data.get("tiers", {}):
			if _data.tiers[t] is Array:
				for id in _data.tiers[t]:
					_tier[int(id)] = str(t)
	return _data


## 测试用：清掉缓存，下次重新读文件
static func reload() -> void:
	_data = {}
	_skills = {}
	_recs = {}
	_tier = {}


static func rules() -> Dictionary:
	return data().get("rules", {})


static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s)


# ---- 技能记录 ----

## 表里有没有这个技能（XDB.rec 的快路径，先查这个再查存档）
static func has(id: int) -> bool:
	data()
	return _skills.has(id)


static func spec(id: int) -> Dictionary:
	data()
	var v = _skills.get(id)
	return v if v is Dictionary else {}


## XDB.rec 包装：天启篇存档里换成改写后的记录
static func rec(id: int, base: Dictionary) -> Dictionary:
	if base.is_empty() or not has(id) or not on():
		return base
	var hit = _recs.get(id)
	if hit is Array and is_same(hit[0], base):
		return hit[1]
	var out := build(id, base)
	_recs[id] = [base, out]
	return out


## 按规格改写一条技能记录（不改原记录）
static func build(id: int, base: Dictionary) -> Dictionary:
	var sp := spec(id)
	var r: Dictionary = base.duplicate(true)
	var note := str(r.get("note", ""))
	for tag in sp.get("note_remove", []):
		note = RegEx.create_from_string("<\\s*(?:%s)\\s*(?::[^>]*)?>" % str(tag)).sub(note, "", true)
	if sp.has("tp"):
		r.tpCost = int(sp.tp)
		note = RegEx.create_from_string("(?i)<TP COST:[^>]*>").sub(note, "", true)
	if sp.has("mp_pct"):
		r.mpCost = 0
		note = RegEx.create_from_string("(?i)<MP COST:[^>]*>").sub(note, "", true)
		note += "\n<MP Cost: %s%%>" % _num(float(sp.mp_pct))
	elif sp.has("mp"):
		r.mpCost = int(sp.mp)
		note = RegEx.create_from_string("(?i)<MP COST:[^>]*>").sub(note, "", true)
	if sp.has("cooldown"):
		note = RegEx.create_from_string("(?i)<COOLDOWN:[^>]*>").sub(note, "", true)
		note += "\n<Cooldown: %d>" % int(sp.cooldown)
	note += str(sp.get("note_add", ""))
	note = _rewrite_desc(note, sp)
	r.note = note
	r.meta = parse_meta(note)
	if sp.has("damage") or sp.has("heal"):
		var dmg: Dictionary = r.get("damage", {}).duplicate(true)
		dmg.formula = "XTianqiSkills.formula(a,b,%d)" % id
		dmg.formulaGd = dmg.formula
		dmg.formulaProgram = {"version": 1, "status": "module", "module": MODULE}
		if sp.has("element"):
			dmg.elementId = int(sp.element)
		r.damage = dmg
	for e in sp.get("effects", []):
		for row in r.get("effects", []):
			if int(row.get("code", -1)) == int(e.code) and int(row.get("dataId", -1)) == int(e.get("dataId", 0)):
				for k in ["value1", "value2"]:
					if e.has(k):
						row[k] = e[k]
	return r


## 说明行：desc 换掉全部「\c[1]」开头的效果行，header 改表头（冷却时间、对象…）的值；样式照原来第一行
static func _rewrite_desc(note: String, sp: Dictionary) -> String:
	var style := " size=18 color=rgba(255,255,255,1) line=false align=0"
	var m := RegEx.create_from_string("<pos=APs text=[^>]*?( size=[^>]*)>").search(note)
	if m != null:
		style = m.get_string(1)
	for key in sp.get("header", {}):
		note = RegEx.create_from_string("<pos=APs text=%s:[^>]*?( size=[^>]*)>" % str(key)).sub(note, "<pos=APs text=%s:%s$1>" % [key, sp.header[key]], true)
	if sp.has("desc"):
		note = RegEx.create_from_string("<pos=APs text=\\\\c\\[1\\][^>]*>").sub(note, "", true)
		for line in sp.desc:
			note += "\n<pos=APs text=\\c[1]%s%s>" % [str(line), style]
	return note


## MV DataManager.extractMetadata：<键:值> → 值，<键> → true
static func parse_meta(note: String) -> Dictionary:
	var out := {}
	for m in RegEx.create_from_string("<([^<>:]+)(:?)([^>]*)>").search_all(note):
		out[m.get_string(1)] = m.get_string(3) if m.get_string(2) == ":" else true
	return out


static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)


# ---- 伤害公式 ----

## 等级缩放：1 级 level1_ratio，满级 1；角色以外按满级
static func level_scale(a) -> float:
	if not a is XActor:
		return 1.0
	var r := rules()
	var top := float(r.get("level_max", 99))
	var lo := float(r.get("level1_ratio", 0.5))
	var t := clampf((float(a.level) - 1.0) / maxf(1.0, top - 1.0), 0.0, 1.0)
	return lo + (1.0 - lo) * t


## 模块公式（XFormulaExecution 分派）：伤害为正，回复为负
static func formula(a, b, item: Dictionary) -> float:
	var sp := spec(int(item.get("id", 0)))
	var kind := int(item.get("damage", {}).get("type", 1))
	if sp.has("heal"):
		var h: Dictionary = sp.heal
		var v := float(b.mhp) * float(h.get("mhp_pct", 0.0)) + float(b.mmp) * float(h.get("mmp_pct", 0.0))
		return -v if kind in [3, 4] else v
	var d: Dictionary = sp.get("damage", {})
	var base := 0.0
	var stats: Dictionary = d.get("stats", {"atk": 1})
	for k in stats:
		base += float(stats[k]) * float(a.param(STATS.find(str(k))))
	var v := base * float(d.get("coef", 0.0)) * level_scale(a)
	for c in d.get("conds", []):
		v *= _cond(c, a, b)
	if a is XActor:
		for c in data().get("actors", {}).get(str(int(a.actor_id)), {}).get("conds", []):
			v *= _cond(c, a, b)
	v = maxf(0.0, v)
	return -v if kind in [3, 4] else v


## 一条伤害条件成立时的倍率，不成立为 1
static func _cond(c: Dictionary, a, b) -> float:
	if c.has("need_skill") and not (a is XActor and (a as XActor).skill_ids.has(int(c.need_skill))):
		return 1.0
	var ok := false
	match str(c.get("if", "")):
		"agi_below_target":
			ok = float(a.agi) < float(b.agi)
		"target_state":
			ok = b.is_state_affected(int(c.state))
		"target_hp_below":
			ok = float(b.hp) < float(b.mhp) * float(c.get("rate", 0.0))
		"self_hp_below":
			ok = float(a.hp) < float(a.mhp) * float(c.get("rate", 0.0))
		"target_full_hp":
			ok = float(b.hp) >= float(b.mhp)
	return float(c.get("mult", 1.0)) if ok else 1.0


# ---- 熟练度 ----

static func mastery_on(s = null) -> bool:
	return MASTERY and on(s)


static func mastery_cap() -> int:
	return int(rules().get("mastery_cap", 10))


## 熟练度伤害：每级 +3%，最多算到上限级
static func mastery_damage(initial: float, level: int) -> float:
	return initial * (1.0 + float(rules().get("mastery_per_level", 0.03)) * float(clampi(level, 0, mastery_cap())))


# ---- 再动、追加行动 ----

## 角色每回合的行动次数封顶：本来 1 次＋最多多 max_extra_actions 次
static func cap_actions(b, n: int) -> int:
	if not ACTION_CAP or not b is XActor or not on():
		return n
	return mini(n, 1 + int(rules().get("max_extra_actions", 1)))


# ---- 档位 ----

static func tiers_on(s = null) -> bool:
	return TIERS and on(s)


## 名单档位（抽阵容、超强者上限读这个）；不开放的角色返回空串。force：不看当前存档（开新档、抽阵容时当前存档还不是天启篇）
static func tier_of(actor_or_id, force := false) -> String:
	var id := int(actor_or_id.actor_id) if actor_or_id is Object else int(actor_or_id)
	if not (TIERS and ENABLED and (force or on())):
		return XTier.tier_of(id)
	data()
	if XTier.tier_of(id) == "":
		return ""
	var t := str(_tier.get(id, XTier.WEAK))
	return "" if t == HIDDEN else t


static func is_super(x, force := false) -> bool: return tier_of(x, force) == XTier.SUPER
static func is_weak(x, force := false) -> bool: return tier_of(x, force) == XTier.WEAK


## 名单里某一档的角色号（升序）；天启篇以外照 XTier
static func ids(tier: String, force := false) -> Array:
	if not (TIERS and ENABLED and (force or on())):
		return XTier.ids(tier)
	var out := []
	for t in [XTier.WEAK, XTier.STRONG, XTier.SUPER]:
		for id in XTier.ids(t):
			if tier_of(id, true) == tier:
				out.append(int(id))
	out.sort()
	return out


## 战斗里的档位（档位加成、弱者协力读这个）：成长型角色按当前进度，其余同名单
static func battle_tier(actor_or_id, s = null) -> String:
	var id := int(actor_or_id.actor_id) if actor_or_id is Object else int(actor_or_id)
	if s == null:
		s = XState.current
	if not tiers_on(s):
		return XTier.tier_of(id)
	var g = data().get("tiers", {}).get("growth", {}).get(str(id))
	if not g is Dictionary:
		return tier_of(id)
	var rank := XAdvance.rank(s, id)
	if g.has("training_var"):
		if float(s.variable(int(g.training_var))) < float(g.training_strong):
			return XTier.WEAK
		return XTier.SUPER if rank >= int(g.advance_super) else XTier.STRONG
	if rank >= int(g.get("super_from", 99)):
		return XTier.SUPER
	return XTier.STRONG if rank >= int(g.get("strong_from", 99)) else XTier.WEAK
