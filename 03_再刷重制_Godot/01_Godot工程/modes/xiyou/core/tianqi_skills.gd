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
## 开关：ENABLED＝false 整套回原版（O-361）；CARDS 角色卡（第二期加，属 O-361）、MASTERY 熟练度（O-362）先默认关，等数值线一起开；ACTION_CAP 行动次数（O-363）、TIERS 档位名单（O-364）默认开。

const PATH := "res://modes/xiyou/tianqi_data/skill_rework.json"
const MODULE := "tianqi_skill"
const HIDDEN := "不开放"
const STATS := ["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"]

static var ENABLED := true
## 角色卡（技能表改写：伤害、费用、被动、状态、追加、变招、击杀成长）。卡上的系数按新数值线（本体标准线、敌人重做）写，
## 现在的属性和敌人还是原版量级，没有固定底数时前期伤害只剩原来的十分之一左右，所以先默认关，等数值线那一轮一起开（Kyo 定）
static var CARDS := false
static var MASTERY := false
static var ACTION_CAP := true
static var TIERS := true

static var _data: Dictionary = {}
static var _skills: Dictionary = {}  # int 技能号 → 改写规格
static var _states: Dictionary = {}  # int 状态号 → 改写规格
static var _recs: Dictionary = {}  # int 技能号 → 改写后的记录（按原记录缓存）
static var _state_recs: Dictionary = {}
static var _tier: Dictionary = {}  # int 角色号 → 名单档位（含「不开放」）
static var _gear: Dictionary = {}  # "armor:底号"／"weapon:底号" → 专属装备改写规格
static var _gear_cache: Dictionary = {}  # 同上键 → [原备注, 原特性数组, 新备注, 新 meta, 新特性]


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
		_gear = {}
		for k in _data.get("gear", {}):
			if str(k).contains(":"):
				_gear[str(k)] = _data.gear[k]
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
	_gear = {}
	_gear_cache = {}
	_new_recs = {}
	_new_state_recs = {}


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
static func cards_on(s = null) -> bool:
	return CARDS and on(s)


static func rec(id: int, base: Dictionary) -> Dictionary:
	if base.is_empty() or not has(id) or not cards_on():
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
	if sp.has("tp_gain"):
		r.tpGain = int(sp.tp_gain)
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


## 行动序列（yepSeq，转换器预编译）：段数在这里。drop_if 删掉条件段（match 是条件里的子串，空＝所有条件段）、if_keep 条件段只留前 n 段（cmd 换成别的命令前缀，如 "Add State"）、replace_cmd 整条换命令名、
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
			"if_keep":  # 条件段留着（运行时照判），段里只留前 n 段（天蓬银河钉锤：净世诀额外 3 段 → 1 段）
				var res2 := []
				var i2 := 0
				while i2 < out.size():
					var nm := str(out[i2][0])
					res2.append(out[i2])
					i2 += 1
					if nm.begins_with("if ") and nm.contains(str(op.get("match", ""))):
						var kept := 0
						while i2 < out.size() and str(out[i2][0]) != "end":
							if str(out[i2][0]).to_lower().begins_with(str(op.get("cmd", "action effect")).to_lower()):
								if kept < int(op.get("n", 1)):
									res2.append(out[i2])
								kept += 1
							else:
								res2.append(out[i2])
							i2 += 1
				out = res2
			"replace_cmd":  # 命令名整条替换（曹操枭雄霸气 Hp -3% → Hp -1%）
				for c in out:
					if str(c[0]) == str(op.get("match", "")):
						c[0] = str(op.get("to", ""))
			"drop_area_effects":  # 删掉带参数（action effect: enemies 这类打全体）的段（莉娜炎帝：全体那段改成另放一招）
				out = out.filter(func(c): return not (str(c[0]) == "action effect" and not (c[1] as Array).is_empty()))
			"drop_cmd":  # 删掉某条命令（劲夫乱打开头的 Add State 942：印记要先挂上才引爆）
				out = out.filter(func(c): return str(c[0]) != str(op.get("match", "")))
			"keep_effects":  # 整条序列只留前 n 段（迪昂普攻版狂乱·灭：一段）
				var kept2 := 0
				var res3 := []
				for c in out:
					if str(c[0]) == "action effect":
						kept2 += 1
						if kept2 > int(op.get("n", 1)):
							continue
					res3.append(c)
				out = res3
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


# ---- 补招（第四节第 5、9 条：四小强 30 级爆发技、克莱德单体治疗、玛莎全体风技、维利百式观音挪到 30 级）----
## new_skills {新号: {from: 底号}}：表里没有的技能号，XDB.rec 时按底号复制一条（换 id、名字），再照常走 rec 改写；号段 10701 起，
## 不往 Skills 表里插（遍历全表的原版对照不受影响）。learn {角色号: [[等级, 技能号]…]}：天启篇卡开着时多学的技能（按角色，不按职业）。
static var _new_recs: Dictionary = {}


static func has_new(id: int) -> bool:
	return data().get("new_skills", {}).has(str(id))


## new_states {新号: {from: 底号}}：卡里要的新状态（签弟忏悔的长恨、流离这类原版没有状态的），号段 10801 起，同 new_skills 不插表；
## 改写规格照常写在 states 表里
static var _new_state_recs: Dictionary = {}


static func has_new_state(id: int) -> bool:
	return data().get("new_states", {}).has(str(id))


static func new_state_rec(id: int, t: Array) -> Dictionary:
	if not _new_state_recs.has(id):
		var from := int(data().get("new_states", {}).get(str(id), {}).get("from", 0))
		if from <= 0 or from >= t.size() or not t[from] is Dictionary:
			return {}
		var r: Dictionary = t[from].duplicate(true)
		r.id = id
		r.name = str(_states.get(id, {}).get("name", r.get("name", "")))
		r.erase("dot")
		_new_state_recs[id] = r
	return rec_state(id, _new_state_recs[id])


static func new_rec(id: int, t: Array) -> Dictionary:
	if _new_recs.has(id):
		return rec(id, _new_recs[id])
	var ns: Dictionary = data().get("new_skills", {}).get(str(id), {})
	var from := int(ns.get("from", 0))
	if from <= 0 or from >= t.size() or not t[from] is Dictionary:
		return {}
	var r: Dictionary = t[from].duplicate(true)
	r.id = id
	r.name = str(spec(id).get("name", r.get("name", "")))
	r.description = ""
	r["_tianqi_new"] = true
	_new_recs[id] = r
	return rec(id, r)


## XActor 的职业技能表（升级、改等级、新建时学技能）：天启篇卡开着时加上 learn 里这名角色的
static func learnings(a, list: Array) -> Array:
	if not CARDS or not (a is XActor) or not cards_on():
		return list
	var extra = data().get("learn", {}).get(str(int(a.actor_id)), [])
	if not extra is Array or extra.is_empty():
		return list
	var out := list.duplicate()
	for e in extra:
		out.append({"level": int(e[0]), "skillId": int(e[1]), "note": ""})
	return out


## 开卡之前已经过了等级的老存档：开战时把够等级的补学上
static func sync_learn(a) -> void:
	if not (a is XActor):
		return
	for e in data().get("learn", {}).get(str(int(a.actor_id)), []):
		if int(a.level) >= int(e[0]) and not a.skill_ids.has(int(e[1])):
			a.learn_skill(int(e[1]))


# ---- 专属装备（法宝、武器）：按底号换成改写视图（第二期之二）----
## 表 gear 的键是「armor:底号」或「weapon:底号」，规格：note_remove／note_sub／note_add 改备注（独有技能增伤、承伤、开战状态等标签），
## traits_remove [[code, dataId]…]、traits_set [{code, dataId, value}…]（有就改值、没有就加）改特性，desc 换「\\c[1]」效果行。
## 实例上的成长（等级、经验、法宝升级特性）不动：XMagicWeapon 读原实例。接在 XTianqiGear.stat_list（能力值、特性、被动缓存、开战状态）
## 和物品说明（XHelpCard._content）上；原版档、卡没开时原样返回。
static func gear_key(item) -> String:
	if not (item is Dictionary) or item.is_empty():
		return ""
	return "%s:%d" % [str(item.get("kind", "")), int(item.get("base", item.get("id", 0)))]


static func gear_view(item):
	if not CARDS or not (item is Dictionary) or item.is_empty() or not cards_on():
		return item
	data()
	var key := gear_key(item)
	if not _gear.has(key):
		return item
	var src_note := str(item.get("note", ""))
	var src_traits = item.get("traits", [])
	var c = _gear_cache.get(key)
	if not (c is Array and is_same(c[1], src_traits) and c[0] == src_note):
		var sp: Dictionary = _gear[key]
		var note := _note_edit(src_note, sp) + str(sp.get("note_add", ""))
		note = _rewrite_desc(note, sp)
		var traits: Array = (src_traits as Array).duplicate(true) if src_traits is Array else []
		for e in sp.get("traits_remove", []):
			traits = traits.filter(func(t): return not (int(t.get("code", -1)) == int(e[0]) and int(t.get("dataId", -1)) == int(e[1])))
		for e in sp.get("traits_set", []):
			var hit := false
			for t in traits:
				if int(t.get("code", -1)) == int(e.code) and int(t.get("dataId", -1)) == int(e.dataId):
					t.value = float(e.value)
					hit = true
			if not hit:
				traits.append({"code": int(e.code), "dataId": int(e.dataId), "value": float(e.value)})
		c = [src_note, src_traits, note, parse_meta(note), traits]
		_gear_cache[key] = c
	var v: Dictionary = item.duplicate(false)
	v.note = c[2]
	v.meta = c[3]
	v.traits = c[4]
	return v


## 条件里的「要有」：数字是学会的技能号，"e底号" 是身上装着这件（法宝、武器）
static func owns(u, key) -> bool:
	if not (u is XActor):
		return false
	if key is String and key.begins_with("e"):
		var base := int(key.substr(1))
		return u.equip_list().any(func(e): return int(e.get("base", e.get("id", 0))) == base)
	return u.skill_ids.has(int(key))


## rate_with {要有: 几率} 取最大、rate_add_with {要有: 加} 累加
static func _rate(u, r: Dictionary) -> float:
	var rate := float(r.get("rate", 0.0))
	for k in r.get("rate_with", {}):
		if owns(u, k):
			rate = maxf(rate, float(r.rate_with[k]))
	for k in r.get("rate_add_with", {}):
		if owns(u, k):
			rate += float(r.rate_add_with[k])
	return rate


# ---- 状态记录 ----

static func has_state(id: int) -> bool:
	data()
	return _states.has(id)


## XDB.rec("States") 包装：天启篇存档里换成改写后的状态（减益、领域按比例写）
static func rec_state(id: int, base: Dictionary) -> Dictionary:
	if base.is_empty() or not has_state(id) or not cards_on():
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
	if sp.get("dot_remove", false):  # 固定量的持续伤害／回复改成按比例（traits 里的再生率），原来的公式去掉
		r.erase("dot")
	if sp.get("effects_remove", false):  # 状态脚本（Custom Apply／Regenerate…）整段去掉，改用下面的 dot（曹操霸道真气）
		r.erase("effects")
	if sp.has("dot"):  # 层数持续伤害：XExtDot 遇到 kind＝tianqi 时读 dot_value
		var d: Dictionary = (sp.dot as Dictionary).duplicate(true)
		d.kind = "tianqi"
		d.state = id
		r.dot = d
	_state_recs[id] = [base, r]
	return r


## 状态缓存的键：被改写的状态在天启篇存档里用负号，免得和原版档的缓存混用
static func state_key(id: int) -> int:
	return -id if has_state(id) and cards_on() else id


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
	if d.has("max_of"):  # 取几项里最高的那项（露丝：物攻、魔攻取高）
		var hi := 0.0
		for k in d.max_of:
			hi = maxf(hi, float(a.param(STATS.find(str(k)))))
		base += hi
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
	if c.has("need_skill") and not owns(a, c.need_skill):
		return 1.0
	if c.has("need") and not owns(a, c.need):
		return 1.0
	if c.has("skills") and not (c.skills as Array).has(float(_cur_skill)) and not (c.skills as Array).has(_cur_skill):
		return 1.0
	var cap := float(c.get("cap", 0.0))
	var per := float(c.get("per", 0.0))
	for k in c.get("cap_with", {}):  # 专属法宝提高封顶（玛莎风息）
		if owns(a, k):
			cap = maxf(cap, float(c.cap_with[k]))
	for k in c.get("per_with", {}):  # 专属法宝提高每层（维利魂骨）
		if owns(a, k):
			per = maxf(per, float(c.per_with[k]))
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
		"target_states_in":  # 目标身上有列表里的几种状态，每种 +per（艾瑞塔毁灭弹数诅咒）
			var n := 0
			for id in c.states:
				if b.is_state_affected(int(id)):
					n += 1
			return 1.0 + clampf(n * per, 0.0, cap)
		"self_states":  # 自己身上状态数（增益减益都算），每个 +per（迪昂狂乱·灭）
			return 1.0 + clampf(float(a.state_ids.size()) * per, 0.0, cap)
		"self_tp":  # 当前 TP×per（天蓬神霄净世诀：每 10 点 +3%，最多 +30%；配 tp_drain 放完耗光）
			return 1.0 + clampf(float(a.tp) * per, 0.0, cap)
		"cast_count":  # 本场放过列表里的技能几次（begin_action 记、开战清零），每次 +per：签弟的忏悔
			var n := 0
			if a is Object and a.has_meta("xtq_casts"):
				var m: Dictionary = a.get_meta("xtq_casts")
				for id in c.of:
					n += int(m.get(int(id), 0))
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
		"agi_above_target":
			ok = float(a.agi) > float(b.agi)
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
	if not cards_on() or not (u is XActor) or not (skill is Dictionary):
		return
	var st := _fstore(logic)
	if int(st.depth) > 0:
		return
	st.act = {"u": u, "skill": skill, "targets": []}
	var casts: Dictionary = u.get_meta("xtq_casts") if u.has_meta("xtq_casts") else {}
	casts[int(skill.get("id", 0))] = int(casts.get(int(skill.get("id", 0)), 0)) + 1
	u.set_meta("xtq_casts", casts)


static func after_apply(logic, u, skill, t) -> void:
	if t == null or not logic.has_meta("xtqs"):
		return
	var f: Dictionary = _fstore(logic).act
	if not f.is_empty() and is_same(f.u, u) and not f.targets.has(t):
		f.targets.append(t)
	_kill_grow(logic, u, skill, t)
	_on_hit(logic, u, skill, t, f)


## 角色行 on_hit [{skills, need, extend [状态], turns, state, rate, pick [状态…], tp}]：放表里的技能打中目标时（专属法宝效果）——
## extend：目标身上刚挂上（剩余回合等于状态原回合）的这些状态多持续 turns 回合；state＋rate：按几率给目标挂状态；pick：随机挂其中一个；tp：每段回 TP。
## extend、state 每次行动每个目标只算一次
static func _on_hit(logic, u, skill, t, f: Dictionary) -> void:
	if not (u is XActor) or not (skill is Dictionary) or not cards_on():
		return
	var rows = data().get("actors", {}).get(str(int(u.actor_id)), {}).get("on_hit", [])
	if not rows is Array or rows.is_empty():
		return
	var sid := int(skill.get("id", 0))
	var done: Array = f.get("on_hit_done", []) if not f.is_empty() else []
	for i in rows.size():
		var r: Dictionary = rows[i]
		var list: Array = r.get("skills", [])
		if not (list.has(float(sid)) or list.has(sid)) or (r.has("need") and not owns(u, r.need)):
			continue
		if r.has("tp"):
			u.tp = float(u.tp) + float(r.tp)
		var tag := [i, t]
		if done.any(func(x): return x[0] == i and is_same(x[1], t)):
			continue
		done.append(tag)
		for st in r.get("extend", []):
			var id := int(st)
			var base := int(XDB.rec("States", id).get("maxTurns", 0))
			if t.is_state_affected(id) and int(t.state_turns.get(id, 0)) == base:
				t.state_turns[id] = base + int(r.get("turns", 1))
		if r.has("state") and t.is_alive() and logic._float("tianqi_skill_on_hit") < float(r.get("rate", 0.0)):
			t.add_state(int(r.state))
		if r.has("stack") and t.is_alive():  # 叠层（曹操霸道真气）：层数记在目标 state_data，封顶 cap（cap_with 专属物提高）
			var sk: Dictionary = r.stack
			var cap := int(sk.get("cap", 1))
			for k in sk.get("cap_with", {}):
				if owns(u, k):
					cap = maxi(cap, int(sk.cap_with[k]))
			var key := "_tq_stack_%d" % int(sk.state)
			if not t.is_state_affected(int(sk.state)):
				t.state_data[key] = 0
			t.state_data[key] = mini(cap, int(t.state_data.get(key, 0)) + int(sk.get("add", 1)))
			t.add_state(int(sk.state))
		if r.has("pick") and t.is_alive() and not (r.pick as Array).is_empty() and logic._float("tianqi_skill_on_hit") < float(r.get("rate", 1.0)):
			var pick: Array = r.pick  # 从几个状态里随机挂一个（晴明尸鬼尽封随机封一项属性）
			t.add_state(int(pick[mini(pick.size() - 1, int(logic._float("tianqi_skill_on_hit") * pick.size()))]))
	if not f.is_empty():
		f.on_hit_done = done


## 层数持续伤害（XExtDot kind＝tianqi）：施加者 stat×per×层数×等级缩放，层数是 on_hit stack 记的
static func dot_value(a, b, d: Dictionary) -> float:
	var n := int(b.state_data.get("_tq_stack_%d" % int(d.get("state", 0)), 1))
	var stat := STATS.find(str(d.get("stat", "atk")))
	return float(a.param(stat)) * float(d.get("per", 0.0)) * float(maxi(1, n)) * level_scale(a)


## 开战状态挂完之后（XBattleLogic._battle_start_states）：角色行 start_turns [{need, state, turns}] 改这件专属物开局状态的回合数，
## start_tp [{need, tp}] 开场 TP 至少这么多
## （状态本身还被技能用，不改状态记录）
static func start_turns(list: Array) -> void:
	if not CARDS or not cards_on():
		return
	for a in list:
		if not (a is XActor):
			continue
		a.set_meta("xtq_casts", {})  # 本场放技能次数（cast_count 条件）
		sync_learn(a)
		for r in data().get("actors", {}).get(str(int(a.actor_id)), {}).get("start_tp", []):  # 开场 TP（天蓬吞云）
			if not r.has("need") or owns(a, r.need):
				a.tp = maxf(float(a.tp), float(r.tp))
		for r in data().get("actors", {}).get(str(int(a.actor_id)), {}).get("start_turns", []):
			if (not r.has("need") or owns(a, r.need)) and a.is_state_affected(int(r.state)):
				a.state_turns[int(r.state)] = int(r.turns)


## 伤害钩子（XActorDamageHooks.capture）：技能行 pierce {rate, need} 无视目标一部分双防；角色行 heal_mult [{need, mult}] 治疗量
static func damage_ops(item: Dictionary, a, b) -> Array:
	if not CARDS or not cards_on():
		return []
	var ops := []
	var id := int(item.get("id", 0))
	if has(id):
		var p: Dictionary = spec(id).get("pierce", {})
		if not p.is_empty() and (not p.has("need") or owns(a, p.need)):
			var keep := 1.0 - float(p.get("rate", 0.0))
			ops.append({"op": "mul", "field": "physicalDefenseRate", "value": keep})
			ops.append({"op": "mul", "field": "magicalDefenseRate", "value": keep})
	if a is XActor and int(item.get("damage", {}).get("type", 0)) in [3, 4]:
		for h in data().get("actors", {}).get(str(int(a.actor_id)), {}).get("heal_mult", []):
			if not h.has("need") or owns(a, h.need):
				ops.append({"op": "mul", "field": "healingMultiplier", "value": float(h.mult)})
	return ops


## itemCri 包装：技能行 crit_if（一条伤害条件，成立时必暴：小痔坐忘痔霄①）
static func item_cri(u, skill: Dictionary, t, cri: float) -> float:
	if not CARDS or not has(int(skill.get("id", 0))) or not cards_on():
		return cri
	var c: Dictionary = spec(int(skill.id)).get("crit_if", {})
	if c.is_empty():
		return cri
	var probe := c.duplicate()
	probe.mult = 2.0
	_cur_skill = int(skill.id)
	return 1.0 if _cond(probe, u, t) > 1.0 else cri


## 技能行 hp_free_with 技能号：学了它这招不扣生命（晴明两仪四象②尸鬼尽封）
static func hp_free(u, skill: Dictionary) -> bool:
	if not CARDS or not has(int(skill.get("id", 0))) or not cards_on():
		return false
	var k = spec(int(skill.id)).get("hp_free_with")
	return k != null and owns(u, int(k))


## 放了这招给变量加数（var_add {var, add, need_skill}：曼德斯给白起加杀气）
static func _var_add(u, skill: Dictionary) -> void:
	var va: Dictionary = spec(int(skill.get("id", 0))).get("var_add", {})
	if va.is_empty() or not (u is XActor) or (va.has("need_skill") and not owns(u, va.need_skill)):
		return
	var s := XState.current
	if s != null:
		s.set_variable(int(va["var"]), float(s.variable(int(va["var"]))) + float(va.add))


## 技能行 consume [状态…]：放完把打到的目标身上这些状态去掉（劲夫乱打引爆怒拳）；consume_keep_with {要有: 几率} 有几率不去
static func _consume(logic, u, f: Dictionary) -> void:
	var sp := spec(int(f.skill.get("id", 0)))
	if not sp.has("consume"):
		return
	var keep := 0.0
	for k in sp.get("consume_keep_with", {}):
		if owns(u, k):
			keep = maxf(keep, float(sp.consume_keep_with[k]))
	for t in f.targets:
		for id in sp.consume:
			if t.is_state_affected(int(id)) and not (keep > 0.0 and logic._float("tianqi_skill_on_hit") < keep):
				t.remove_state(int(id))


## 技能行 foe_states [{state, rate}]：对己方放的技能顺带给所有活着的敌人挂状态（签弟忏悔的流离）
static func _foe_states(logic, u, skill: Dictionary) -> void:
	if not (u is XActor) or not u.is_alive():
		return
	for r in spec(int(skill.get("id", 0))).get("foe_states", []):
		for e in logic.alive(logic.enemies):
			if logic._float("tianqi_skill_on_hit") < float(r.get("rate", 1.0)):
				e.add_state(int(r.state))


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
	if not (u is XActor) or not (skill is Dictionary) or t.is_alive() or t.is_actor() or not cards_on():
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
	var cap := roundi(_grow_cap(g, u) / maxf(0.0001, float(g.get("per", 0.01))))
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
	if not g is Dictionary or int(g.get("param", -1)) != i or not cards_on():
		return 1.0
	if g.has("need_skill") and not a.skill_ids.has(int(g.need_skill)):
		return 1.0
	return 1.0 + minf(_grow_cap(g, a), float(grow_count(str(g.key))) * float(g.per))


## 成长封顶：cap_with {要有: 封顶} 取最大（齐格鲁德平波 +20% → +30%）
static func _grow_cap(g: Dictionary, a) -> float:
	var cap := float(g.get("cap", 0.0))
	for k in g.get("cap_with", {}):
		if owns(a, k):
			cap = maxf(cap, float(g.cap_with[k]))
	return cap


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
		if r.has("need_skill") and not owns(u, r.need_skill):
			continue
		if r.has("need_ally_skill") and not _ally_has(int(r.need_ally_skill[0]), int(r.need_ally_skill[1])):
			continue
		var rate := _rate(u, r)
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
		_foe_states(logic, u, f.skill)
		if bool(spec(int(f.skill.get("id", 0))).get("tp_drain", false)):
			u.tp = 0.0  # 技能行 tp_drain：放完耗光 TP（天蓬神霄净世诀）
		_consume(logic, u, f)
		if spec(int(f.skill.get("id", 0))).has("mp_drain"):  # 技能行 mp_drain：放完扣掉当前魔法的这个比例（莉娜炎帝 0.5）
			u.mp = float(u.mp) * (1.0 - float(spec(int(f.skill.id)).mp_drain))
	if int(st.depth) > 0 or f.is_empty() or not is_same(f.u, u) or not (u is XActor) or not u.is_alive() or not cards_on():
		return logs
	if int(st.used.get(u, -1)) == int(logic.turn):
		return logs
	var alive: Array = f.targets.filter(func(t): return t.is_alive())
	var hit := []
	for c in _follow_of(u, f.skill):
		if logic._float("tianqi_skill_follow") < float(c[1]):
			hit = c
			break
	if hit.is_empty():
		return logs
	var cast: Dictionary = hit[0]
	# 追加的是全体技（敌方全体 2、我方全体 8）时打全场（单体治疗后接全体治疗、炎帝打倒目标后的余焰）；否则打这次行动打到、还活着的目标
	var targets: Array = alive if alive.size() <= 1 else [alive[0]]
	match int(cast.get("scope", 1)):
		2:
			targets = logic.alive(logic.enemies)
		8:
			targets = logic.alive(logic.actors)
	if targets.is_empty():
		return logs
	st.used[u] = int(logic.turn)
	st.depth = int(st.depth) + 1
	follow_scale = float(hit[2])
	for t in targets:
		logs.append({"type": "action", "user": u, "skill": cast, "views": logic.views()})
		logs.append(logic.apply(u, cast, t))
	follow_scale = 1.0
	# 追加之后再接一招（then：{cast, rate, need_skill}，比如兽魂之力后心无旁羁的苍龙之力）
	var then: Dictionary = hit[3] if hit[3] is Dictionary else {}
	var on_kill := bool(then.get("on_kill", false))  # then.on_kill：这次行动打倒过目标才接（莉娜最后的丸子），目标改成还活着的敌人
	if on_kill and not (f.targets as Array).any(func(t): return not t.is_alive()):
		then = {}
	if not then.is_empty() and (not then.has("need_skill") or owns(u, then.need_skill)) and u.is_alive():
		var nxt := XDB.rec("Skills", int(then.get("cast", 0)))
		var left: Array = logic.alive(logic.enemies) if on_kill else targets.filter(func(t): return t.is_alive())
		if not nxt.is_empty() and not left.is_empty() and logic._float("tianqi_skill_follow") < float(then.get("rate", 0.0)):
			logs.append({"type": "action", "user": u, "skill": nxt, "views": logic.views()})
			logs.append(logic.apply(u, nxt, left[0]))
	st.depth = int(st.depth) - 1
	return logs



# ---- 变招（替换这次放的技能：克比六式这类按几率换招；原版的 ChangeTo 在表里删掉时用）----
## 技能行 variants [{cast, rate, need_skill, rate_with}]：按顺序逐个掷，第一个掷中的换掉
static func change_to(logic, u, skill):
	if not (skill is Dictionary) or skill.is_empty() or not (u is XActor) or not cards_on():
		return skill
	var rows: Array = spec(int(skill.get("id", 0))).get("variants", [])
	for r in rows:
		if r.has("need_skill") and not owns(u, r.need_skill):
			continue
		var rate := _rate(u, r)
		if rate > 0.0 and logic._float("tianqi_skill_variant") < rate:
			var cast := XDB.rec("Skills", int(r.cast))
			if not cast.is_empty():
				return cast
	return skill
