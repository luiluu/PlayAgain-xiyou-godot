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
static var _states: Dictionary = {}  # int 状态号 → 改写规格
static var _recs: Dictionary = {}  # int 技能号 → 改写后的记录（按原记录缓存）
static var _state_recs: Dictionary = {}
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
		_states = {}
		for k in _data.get("states", {}):
			if str(k).is_valid_int():
				_states[int(k)] = _data.states[k]
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
	_states = {}
	_recs = {}
	_state_recs = {}
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
	note = _note_edit(note, sp)
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
		if sp.has("dmg_type"):
			dmg.type = int(sp.dmg_type)
		if sp.has("variance"):
			dmg.variance = int(sp.variance)
		if sp.has("critical"):
			dmg.critical = bool(sp.critical)
		r.damage = dmg
	if sp.has("seq") and r.get("yepSeq") is Dictionary:
		for ph in ["target", "whole"]:
			if r.yepSeq.get(ph) is Array:
				r.yepSeq[ph] = _seq_edit(r.yepSeq[ph], sp.seq)
	if sp.has("hit_type"):
		r.hitType = int(sp.hit_type)
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


## 行动序列（yepSeq，转换器预编译）：段数在这里。drop_if 删掉条件段（match 是条件里的子串，空＝所有条件段）、
## if_to_effects 把条件段换成固定 n 段、add_effects 在最后一段后面再加 n 段、clear_effect_args 把「action effect: enemies」改成只打目标
static func _seq_edit(cmds: Array, ops: Array) -> Array:
	var out: Array = cmds.duplicate(true)
	for op in ops:
		match str(op.get("op", "")):
			"drop_if", "if_to_effects":
				var res := []
				var i := 0
				while i < out.size():
					var name := str(out[i][0])
					if name.begins_with("if ") and name.contains(str(op.get("match", ""))):
						var depth := 1
						i += 1
						while i < out.size() and depth > 0:
							var n2 := str(out[i][0])
							if n2.begins_with("if "):
								depth += 1
							elif n2 == "end":
								depth -= 1
							i += 1
						if str(op.op) == "if_to_effects":
							for k in int(op.get("n", 1)):
								res.append(["action effect", []])
						continue
					res.append(out[i])
					i += 1
				out = res
			"add_effects":
				var last := -1
				for i in out.size():
					if str(out[i][0]) == "action effect":
						last = i
				for k in int(op.get("n", 1)):
					out.insert(last + 1, ["action effect", []])
			"clear_effect_args":
				for c in out:
					if str(c[0]) == "action effect":
						c[1] = []
	return out


## 备注：note_remove 删标签（名字是正则）、note_sub [[正则, 换成]] 逐条替换（动作序列里的条件段数之类）
static func _note_edit(note: String, sp: Dictionary) -> String:
	for tag in sp.get("note_remove", []):
		note = RegEx.create_from_string("<\\s*(?:%s)\\s*(?::[^>]*)?>" % str(tag)).sub(note, "", true)
	for pair in sp.get("note_sub", []):
		note = RegEx.create_from_string("(?s)" + str(pair[0])).sub(note, str(pair[1]), true)
	return note


# ---- 状态记录 ----

static func has_state(id: int) -> bool:
	data()
	return _states.has(id)


## XDB.rec("States") 包装：天启篇存档里换成改写后的状态（减益、领域按比例写）
static func rec_state(id: int, base: Dictionary) -> Dictionary:
	if base.is_empty() or not has_state(id) or not on():
		return base
	var hit = _state_recs.get(id)
	if hit is Array and is_same(hit[0], base):
		return hit[1]
	var sp: Dictionary = _states[id]
	var r: Dictionary = base.duplicate(true)
	var note := _note_edit(str(r.get("note", "")), sp)
	note += str(sp.get("note_add", ""))
	if sp.has("state_note"):
		note = RegEx.create_from_string("(?s)<StateNote>.*?</StateNote>").sub(note, "<StateNote>\n%s\n</StateNote>" % str(sp.state_note))
	r.note = note
	r.meta = parse_meta(note)
	if sp.has("traits"):
		r.traits = (sp.traits as Array).duplicate(true)
	for t in sp.get("traits_add", []):
		r.traits.append((t as Dictionary).duplicate())
	if sp.has("turns"):
		r.minTurns = int(sp.turns)
		r.maxTurns = int(sp.turns)
	_state_recs[id] = [base, r]
	return r


## 状态缓存的键：被改写的状态在天启篇存档里用负号，免得和原版档的缓存混用
static func state_key(id: int) -> int:
	return -id if has_state(id) and on() else id


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

static var _cur_skill := 0  # 正在算的技能号（条件里的 skills 过滤用）

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
	_cur_skill = int(item.get("id", 0))
	var base := 0.0
	var stats: Dictionary = d.get("stats", {"atk": 1})
	for k in stats:
		base += float(stats[k]) * float(a.param(STATS.find(str(k))))
	var v := base * float(d.get("coef", 0.0)) * level_scale(a) * follow_scale
	for c in d.get("conds", []):
		v *= _cond(c, a, b)
	if a is XActor:
		for c in data().get("actors", {}).get(str(int(a.actor_id)), {}).get("conds", []):
			v *= _cond(c, a, b)
	v = maxf(0.0, v)
	return -v if kind in [3, 4] else v


## 一条伤害条件成立时的倍率，不成立为 1。
## 累计类（加成按量、有封顶）：var_bonus 变量×per 封顶 cap；target_states 目标异常状态数×per；self_mp_lost 已耗魔法比例×per；self_mp_rate 当前魔法比例×per
static func _cond(c: Dictionary, a, b) -> float:
	if c.has("need_skill") and not (a is XActor and (a as XActor).skill_ids.has(int(c.need_skill))):
		return 1.0
	if c.has("skills") and not (c.skills as Array).has(float(_cur_skill)) and not (c.skills as Array).has(_cur_skill):
		return 1.0
	var cap := float(c.get("cap", 0.0))
	var per := float(c.get("per", 0.0))
	match str(c.get("if", "")):
		"var_bonus":
			var s := XState.current
			var v := float(s.variable(int(c["var"]))) if s != null else 0.0
			return 1.0 + clampf(v * per, 0.0, cap)
		"target_states":
			var n := 0
			for id in b.state_ids:
				if XSmartAI.harmful_state(int(id)):
					n += 1
			return 1.0 + clampf(n * per, 0.0, cap)
		"self_mp_lost":
			return 1.0 + clampf((1.0 - float(a.mp) / maxf(1.0, float(a.mmp))) * per, 0.0, cap)
		"self_mp_rate":
			return 1.0 + clampf(float(a.mp) / maxf(1.0, float(a.mmp)) * per, 0.0, cap)
		"skills_learned":  # 学会了列表里的几个技能，每个 +per
			var n := 0
			if a is XActor:
				for id in c.ids:
					if a.skill_ids.has(int(id)):
						n += 1
			return 1.0 + clampf(n * per, 0.0, cap)
		"allies":  # 上场的这些角色（不算自己）每人 +per
			var s := XState.current
			var n := 0
			if s != null and a is XActor:
				for i in mini(XTianqi.FIGHTERS, s.battle_slots.size()):
					var id := int(s.battle_slots[i])
					if id != int(a.actor_id) and (c.ids as Array).has(float(id)):
						n += 1
			return 1.0 + clampf(n * per, 0.0, cap)
	var ok := false
	match str(c.get("if", "")):
		"always":
			ok = true
		"agi_below_target":
			ok = float(a.agi) < float(b.agi)
		"target_state":
			ok = b.is_state_affected(int(c.state))
		"self_state_any":
			ok = (c.states as Array).any(func(id): return a.is_state_affected(int(id)))
		"target_state_any":
			ok = (c.states as Array).any(func(id): return b.is_state_affected(int(id)))
		"target_hp_above":
			ok = float(b.hp) >= float(b.mhp) * float(c.get("rate", 1.0))
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


# ---- 追加释放（技能放完按几率追加另一招或再放一次）----
## 规格：技能行 follow [{cast 追加的技能号（缺省＝本招）, rate 几率, need_skill 学了才有, rate_with {技能号: 学了它时的几率}, scale 伤害倍率（暂不用）}]；
## 角色行 follow 同上，另有 on [技能号…]（缺省＝任意非普攻的伤害技）。
## 每名角色每回合最多追加 1 次（第一节第 6 条），追加出来的那次不再触发追加；目标是这次行动打到的、还活着的目标。

static func _fstore(logic) -> Dictionary:
	if not logic.has_meta("xtqs"):
		logic.set_meta("xtqs", {"act": {}, "depth": 0, "used": {}})
	return logic.get_meta("xtqs")


static func begin_action(logic, u, skill) -> void:
	if not on() or not (u is XActor) or not (skill is Dictionary):
		return
	var st := _fstore(logic)
	if int(st.depth) > 0:
		return
	st.act = {"u": u, "skill": skill, "targets": []}


static func after_apply(logic, u, skill, t) -> void:
	if t == null or not logic.has_meta("xtqs"):
		return
	var f: Dictionary = _fstore(logic).act
	if not f.is_empty() and is_same(f.u, u) and not f.targets.has(t):
		f.targets.append(t)
	_kill_grow(logic, u, skill, t)


## 放了这招给变量加数（var_add {var, add, need_skill}：曼德斯给白起加杀气）
static func _var_add(u, skill: Dictionary) -> void:
	var va: Dictionary = spec(int(skill.get("id", 0))).get("var_add", {})
	if va.is_empty() or not (u is XActor) or (va.has("need_skill") and not u.skill_ids.has(int(va.need_skill))):
		return
	var s := XState.current
	if s != null:
		s.set_variable(int(va["var"]), float(s.variable(int(va["var"]))) + float(va.add))


## 上场（出战栏前 4 格）的某名角色学了某技能
static func _ally_has(actor_id: int, skill_id: int) -> bool:
	var s := XState.current
	if s == null:
		return false
	for i in mini(XTianqi.FIGHTERS, s.battle_slots.size()):
		if int(s.battle_slots[i]) == actor_id and s.party.has(actor_id):
			return s.actor(actor_id).skill_ids.has(skill_id)
	return false


# ---- 击杀成长（关羽物攻、张飞生命：每次击杀 +per，封顶 cap；存档 flags.tianqi.skill_grow）----
## 技能行 kill_grow＝成长键；角色行 grow {key, param 能力号, per, cap, need_skill}

static func grow_count(key: String, s = null) -> int:
	if s == null:
		s = XState.current
	if s == null or not s.flags.get("tianqi") is Dictionary:
		return 0
	return int(s.flags.tianqi.get("skill_grow", {}).get(key, 0))


static func _kill_grow(logic, u, skill, t) -> void:
	if not (u is XActor) or not (skill is Dictionary) or t.is_alive() or t.is_actor() or not on():
		return
	var key := str(spec(int(skill.get("id", 0))).get("kill_grow", ""))
	var g: Dictionary = data().get("actors", {}).get(str(int(u.actor_id)), {}).get("grow", {})
	if key == "" or str(g.get("key", "")) != key:
		return
	var st := _fstore(logic)
	var seen: Array = st.get("killed", [])
	if seen.has(t):
		return
	seen.append(t)
	st.killed = seen
	if g.has("need_skill") and not u.skill_ids.has(int(g.need_skill)):
		return
	var s := XState.current
	var cap := roundi(float(g.get("cap", 0.0)) / maxf(0.0001, float(g.get("per", 0.01))))
	var tq: Dictionary = s.flags.tianqi
	if not tq.get("skill_grow") is Dictionary:
		tq.skill_grow = {}
	tq.skill_grow[key] = mini(cap, int(tq.skill_grow.get(key, 0)) + 1)
	u.param_mark_dirty()


## XActor.param_rate 包装：击杀成长的能力比率
static func param_rate(a, i: int) -> float:
	if not ENABLED:
		return 1.0
	var g = data().get("actors", {}).get(str(int(a.actor_id)), {}).get("grow")
	if not g is Dictionary or int(g.get("param", -1)) != i or not on():
		return 1.0
	if g.has("need_skill") and not a.skill_ids.has(int(g.need_skill)):
		return 1.0
	return 1.0 + minf(float(g.cap), float(grow_count(str(g.key))) * float(g.per))


## 这次行动可以追加的候选：[[技能记录, 几率, 伤害倍率]…]，按表里顺序逐个掷，第一个掷中的追加
static func _follow_of(u: XActor, skill: Dictionary) -> Array:
	var rows: Array = spec(int(skill.get("id", 0))).get("follow", []).duplicate()
	var arow: Dictionary = data().get("actors", {}).get(str(int(u.actor_id)), {})
	for r in arow.get("follow", []):
		var ons: Array = r.get("on", [])
		if ons.is_empty() and (u.is_attack(skill) or not int(skill.get("damage", {}).get("type", 0)) in [1, 5]):
			continue
		if not ons.is_empty() and not ons.has(float(skill.get("id", 0))) and not ons.has(int(skill.get("id", 0))):
			continue
		rows.append(r)
	var out := []
	for r in rows:
		if r.has("need_skill") and not u.skill_ids.has(int(r.need_skill)):
			continue
		if r.has("need_ally_skill") and not _ally_has(int(r.need_ally_skill[0]), int(r.need_ally_skill[1])):
			continue
		var rate := float(r.get("rate", 0.0))
		for k in r.get("rate_with", {}):
			if u.skill_ids.has(int(k)):
				rate = maxf(rate, float(r.rate_with[k]))
		if rate <= 0.0:
			continue
		var cast := XDB.rec("Skills", int(r.get("cast", skill.get("id", 0))))
		if not cast.is_empty():
			out.append([cast, rate, float(r.get("scale", 1.0)), r.get("then", {})])
	return out


## 追加出来的那次伤害倍率（formula 读）
static var follow_scale := 1.0


static func end_action(logic, u, skill) -> Array:
	var logs := []
	if not logic.has_meta("xtqs"):
		return logs
	var st := _fstore(logic)
	var f: Dictionary = st.act
	st.act = {}
	if int(st.depth) == 0 and not f.is_empty() and is_same(f.u, u):
		_var_add(u, f.skill)
	if int(st.depth) > 0 or f.is_empty() or not is_same(f.u, u) or not (u is XActor) or not u.is_alive() or not on():
		return logs
	if int(st.used.get(u, -1)) == int(logic.turn):
		return logs
	var alive: Array = f.targets.filter(func(t): return t.is_alive())
	if alive.is_empty():
		return logs
	var hit := []
	for c in _follow_of(u, f.skill):
		if logic._float("tianqi_skill_follow") < float(c[1]):
			hit = c
			break
	if hit.is_empty():
		return logs
	st.used[u] = int(logic.turn)
	st.depth = int(st.depth) + 1
	var cast: Dictionary = hit[0]
	var targets: Array = alive if int(cast.get("scope", 1)) in [2, 8] or alive.size() == 1 else [alive[0]]
	follow_scale = float(hit[2])
	for t in targets:
		logs.append({"type": "action", "user": u, "skill": cast, "views": logic.views()})
		logs.append(logic.apply(u, cast, t))
	follow_scale = 1.0
	# 追加之后再接一招（then：{cast, rate, need_skill}，比如兽魂之力后心无旁羁的苍龙之力）
	var then: Dictionary = hit[3] if hit[3] is Dictionary else {}
	if not then.is_empty() and (not then.has("need_skill") or u.skill_ids.has(int(then.need_skill))) and u.is_alive():
		var nxt := XDB.rec("Skills", int(then.get("cast", 0)))
		var left: Array = targets.filter(func(t): return t.is_alive())
		if not nxt.is_empty() and not left.is_empty() and logic._float("tianqi_skill_follow") < float(then.get("rate", 0.0)):
			logs.append({"type": "action", "user": u, "skill": nxt, "views": logic.views()})
			logs.append(logic.apply(u, nxt, left[0]))
	st.depth = int(st.depth) - 1
	return logs



# ---- 变招（替换这次放的技能：克比六式这类按几率换招；原版的 ChangeTo 在表里删掉时用）----
## 技能行 variants [{cast, rate, need_skill, rate_with}]：按顺序逐个掷，第一个掷中的换掉
static func change_to(logic, u, skill):
	if not (skill is Dictionary) or skill.is_empty() or not (u is XActor) or not on():
		return skill
	var rows: Array = spec(int(skill.get("id", 0))).get("variants", [])
	for r in rows:
		if r.has("need_skill") and not u.skill_ids.has(int(r.need_skill)):
			continue
		var rate := float(r.get("rate", 0.0))
		for k in r.get("rate_with", {}):
			if u.skill_ids.has(int(k)):
				rate = maxf(rate, float(r.rate_with[k]))
		if rate > 0.0 and logic._float("tianqi_skill_variant") < rate:
			var cast := XDB.rec("Skills", int(r.cast))
			if not cast.is_empty():
				return cast
	return skill
