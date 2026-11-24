class_name XTianqiGeneralBooks
extends RefCounted
## 天启篇通用书重标模块（T013-1d / 1e）。
## 范围：教派包丁二（止戈/天怒、深渊六式 24 原技能并 18 口径、五条传承 21 技能、三本极尽升华被动）、
##       EV054 内 4 本主动书（投石问路、百草回春经上下、轮回转生决）、
##       抽奖与秘境被动、其余通用主动／被动／CE 精通书及配套状态。
## 数据：modes/xiyou/tianqi_data/general_books.json（独立于 skill_rework.json，与 T443 功法 50 本零重叠）。
## 规则：
## - 仅在天启篇存档（XTianqi.active）且 ENABLED := true 时生效；西游档零变化。
## - 回退：XTianqiGeneralBooks.ENABLED = false 完整回退到原版数据（并同步切换状态与属性倍率缓存键）。
## - 复用 XTianqiSkills 的备注编辑、说明行改写、行动序列编辑与公式等级缩放／单段上限／条件计算，避免重复实现。

const PATH := "res://modes/xiyou/tianqi_data/general_books.json"
const MODULE := "tianqi_general_book"
const STATS := ["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"]

static var ENABLED := true

static var _data: Dictionary = {}
static var _skills: Dictionary = {}
static var _states: Dictionary = {}
static var _recs: Dictionary = {}
static var _state_recs: Dictionary = {}
static var _load_failed := false


# ---- 数据加载与开关 ----

static func data() -> Dictionary:
	if _data.is_empty() and not _load_failed:
		if XDataFile.missing(PATH):
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			_load_failed = true
			push_error("XTianqiGeneralBooks: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if not parsed is Dictionary:
			_load_failed = true
			push_error("XTianqiGeneralBooks: JSON 解析失败 " + PATH)
			return {}
		_data = parsed
		_skills = {}
		for k in _data.get("skills", {}):
			if str(k).is_valid_int():
				_skills[int(k)] = _data.skills[k]
		_states = {}
		for k in _data.get("states", {}):
			if str(k).is_valid_int():
				_states[int(k)] = _data.states[k]
	return _data


static func reload_table() -> void:
	_data = {}
	_skills = {}
	_states = {}
	_recs = {}
	_state_recs = {}
	_load_failed = false


static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release()) and not data().is_empty()


# ---- 技能记录 ----

static func has(id: int) -> bool:
	if not ENABLED:
		return false
	data()
	return _skills.has(id)


static func spec(id: int) -> Dictionary:
	data()
	var v = _skills.get(id)
	return v if v is Dictionary else {}


## XDB.rec("Skills") 包装：天启篇存档且总开关开着时换成改写后的记录
static func rec(id: int, base: Dictionary) -> Dictionary:
	if base.is_empty() or not has(id) or not on():
		return base
	var hit = _recs.get(id)
	if hit is Array and is_same(hit[0], base):
		return hit[1]
	var out := build(id, base)
	_recs[id] = [base, out]
	return out


## XPowerBooks.param_rate_bonus 缓存键：天启篇通用书改写过的技能用负号隔离，避免跨存档或切开关串缓存
static func rate_key(id: int) -> int:
	if not has(id) or not on():
		return id
	return -id


static func build(id: int, base: Dictionary) -> Dictionary:
	var sp := spec(id)
	if sp.is_empty():
		return base
	var r: Dictionary = base.duplicate(true)
	var note := str(r.get("note", "")).replace("\u200b", "")
	note = XTianqiSkills._note_edit(note, sp)
	if sp.has("tp"):
		r.tpCost = int(sp.tp)
	if sp.has("tp_gain"):
		r.tpGain = int(sp.tp_gain)
		note = RegEx.create_from_string("(?i)<TP COST:[^>]*>").sub(note, "", true)
	if sp.has("mp_pct"):
		r.mpCost = 0
		note = RegEx.create_from_string("(?i)<MP COST:[^>]*>").sub(note, "", true)
		note += "\n<MP Cost: %s%%>" % XTianqiSkills._num(float(sp.mp_pct))
	elif sp.has("mp"):
		r.mpCost = int(sp.mp)
		note = RegEx.create_from_string("(?i)<MP COST:[^>]*>").sub(note, "", true)
	if sp.has("cooldown"):
		note = RegEx.create_from_string("(?i)<COOLDOWN:[^>]*>").sub(note, "", true)
		note += "\n<Cooldown: %d>" % int(sp.cooldown)
	note += str(sp.get("note_add", ""))
	note = XTianqiSkills._rewrite_desc(note, sp)
	r.note = note
	r.meta = XTianqiSkills.parse_meta(note)
	if sp.has("damage") or sp.has("heal"):
		var dmg: Dictionary = r.get("damage", {}).duplicate(true)
		dmg.formula = "XTianqiGeneralBooks.formula(a,b,%d)" % id
		dmg.formulaGd = dmg.formula
		dmg.formulaProgram = {"version": 1, "status": "module", "module": MODULE}
		if sp.has("element"):
			dmg.elementId = int(sp.element)
		if sp.has("dmg_type"):
			dmg.type = int(sp.dmg_type)
		if sp.has("variance"):
			dmg.variance = int(sp.variance)
		if sp.has("critical"):
			dmg.critical = bool(sp.critical)
		r.damage = dmg
	if sp.has("seq") and r.get("yepSeq") is Dictionary:
		var before := XTianqiSkills._seq_effect_count(r.yepSeq)
		for ph in ["target", "whole"]:
			if r.yepSeq.get(ph) is Array:
				r.yepSeq[ph] = XTianqiSkills._seq_edit(r.yepSeq[ph], sp.seq)
		if r.has("yepEffects"):
			r.yepEffects = maxi(1, int(r.yepEffects) + XTianqiSkills._seq_effect_count(r.yepSeq) - before)
	if sp.has("repeats"):
		r.repeats = int(sp.repeats)
	if sp.has("scope"):
		r.scope = int(sp.scope)
	for e in sp.get("effects_remove", []):
		r.effects = (r.get("effects", []) as Array).filter(func(row): return not (int(row.get("code", -1)) == int(e[0]) and int(row.get("dataId", -1)) == int(e[1])))
	for e in sp.get("effects_add", []):
		r.effects.append((e as Dictionary).duplicate())
	for e in sp.get("effects", []):
		for row in r.get("effects", []):
			if int(row.get("code", -1)) == int(e.code) and int(row.get("dataId", -1)) == int(e.get("dataId", 0)):
				for k in ["value1", "value2"]:
					if e.has(k):
						row[k] = e[k]
	return r


# ---- 状态记录 ----

static func has_state(id: int) -> bool:
	if not ENABLED:
		return false
	data()
	return _states.has(id)


## XDB.rec("States") 包装：天启篇存档里换成改写后的配套状态（止戈、重岩壁垒、黯灭幻影、抽奖状态等）
static func rec_state(id: int, base: Dictionary) -> Dictionary:
	if base.is_empty() or not has_state(id) or not on():
		return base
	var hit = _state_recs.get(id)
	if hit is Array and is_same(hit[0], base):
		return hit[1]
	var sp: Dictionary = _states[id]
	var r: Dictionary = base.duplicate(true)
	var note := XTianqiSkills._note_edit(str(r.get("note", "")), sp)
	note += str(sp.get("note_add", ""))
	if sp.has("state_note"):
		if RegEx.create_from_string("(?s)<StateNote>.*?</StateNote>").search(note) != null:
			note = RegEx.create_from_string("(?s)<StateNote>.*?</StateNote>").sub(note, "<StateNote>\n%s\n</StateNote>" % str(sp.state_note))
		else:
			note += "\n<StateNote>\n%s\n</StateNote>" % str(sp.state_note)
	r.note = note
	r.meta = XTianqiSkills.parse_meta(note)
	if sp.has("traits"):
		r.traits = (sp.traits as Array).duplicate(true)
	for t in sp.get("traits_add", []):
		r.traits.append((t as Dictionary).duplicate())
	if sp.has("turns"):
		r.minTurns = int(sp.turns)
		r.maxTurns = int(sp.turns)
	if sp.has("auto"):
		r.autoRemovalTiming = int(sp.auto)
	if sp.has("battle_end"):
		r.removeAtBattleEnd = bool(sp.battle_end)
	if sp.get("dot_remove", false):
		r.erase("dot")
	if sp.get("effects_remove", false):
		r.erase("effects")
	_state_recs[id] = [base, r]
	return r


# ---- 伤害与治疗模块公式（XFormulaExecution 分派）----

static func formula(a, b, item: Dictionary) -> float:
	if not on():
		return 0.0
	var sp := spec(int(item.get("id", 0)))
	if sp.is_empty():
		return 0.0
	var kind := int(item.get("damage", {}).get("type", 1))
	if sp.has("heal"):
		var h: Dictionary = sp.heal
		var hv := float(b.mhp) * float(h.get("mhp_pct", 0.0)) + float(b.mmp) * float(h.get("mmp_pct", 0.0))
		return -hv if kind in [3, 4] else hv
	var d: Dictionary = sp.get("damage", {})
	var base := 0.0
	var stats: Dictionary = d.get("stats", {"atk": 1})
	for k in stats:
		var idx := STATS.find(str(k))
		if idx >= 0:
			base += float(stats[k]) * float(a.param(idx))
	var coefficient := float(d.coef_pct) / 100.0 if d.has("coef_pct") else float(d.get("coef", 0.0))
	var v := base * coefficient * XTianqiSkills.level_scale(a)
	var hit_cap := XTianqiBase.single_hit_cap(a)
	var eff := coefficient * (XTianqiSkills.hit_weight(d) if hit_cap > 0.0 else 1.0)
	var prev := XTianqiSkills._cur_skill
	XTianqiSkills._cur_skill = int(item.get("id", 0))
	for c in d.get("conds", []):
		var m := XTianqiSkills._cond(c, a, b)
		v *= m
		eff *= m
	XTianqiSkills._cur_skill = prev
	if hit_cap > 0.0 and eff > hit_cap * XTianqiSkills.cap_hits(d):
		v *= hit_cap * XTianqiSkills.cap_hits(d) / eff
	v = maxf(0.0, v)
	return -v if kind in [3, 4] else v
