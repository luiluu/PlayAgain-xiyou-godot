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


## 读表失败过（发行包排除了 tianqi_data/，见 07_开发环境/发行内容审计.py）：记下来不再重读、不再报错。
## XGojo.patch_skills 每次建技能表都要问 has()，不记的话发行包里一场挂机战斗就要重试开文件、报错几千次。
static var _load_failed := false


static func data() -> Dictionary:
	if _data.is_empty():
		if _load_failed:
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			_load_failed = true
			push_error("XTianqiSkills: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if not parsed is Dictionary:
			_load_failed = true
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
	for k in sp.get("fields", {}):  # 记录上的其他字段直接改（奈叶自定义魔法消耗 mpCostCurrentRate／postDamageCostRepeat 关掉）
		r[k] = sp.fields[k]
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
				if last < 0:  # 这一段（多半是默认 whole）没有小写段：不加（以前会插到开头，多打一段）
					continue
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
## learn 的条目 [等级, 技能号]，或 ["s技能号", 技能号]：学了那个技能（进阶给的被动）后开战时补学。
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
		if not e[0] is String:  # "s技能号" 的条目按已学技能补（sync_learn），不进等级表
			out.append({"level": int(e[0]), "skillId": int(e[1]), "note": ""})
	return out


## 开卡之前已经过了等级的老存档：开战时把够等级的补学上
static func sync_learn(a) -> void:
	if not (a is XActor):
		return
	for e in data().get("learn", {}).get(str(int(a.actor_id)), []):
		var ok: bool = a.skill_ids.has(int(str(e[0]).substr(1))) if e[0] is String else int(a.level) >= int(e[0])
		if ok and not a.skill_ids.has(int(e[1])):  # "s技能号"：学了那个技能（进阶给的被动）就补学（小青剑破万光）
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
	if sp.has("auto"):  # 解除时机（0 不自动、1 行动结束、2 回合结束）：原版「整场」的状态改成按回合
		r.autoRemovalTiming = int(sp.auto)
	if sp.get("dot_remove", false):  # 固定量的持续伤害／回复改成按比例（traits 里的再生率），原来的公式去掉
		r.erase("dot")
	if sp.get("effects_remove", false):  # 状态脚本（Custom Apply／Regenerate…）整段去掉，改用下面的 dot（曹操霸道真气）
		r.erase("effects")
	if sp.has("revive") and r.get("effects") is Array:  # 自动复活（rules3 的 revive 块）：rate 回血比例（不再回满魔法、TP）、chance 几率、once 复活后自己去掉（每场一次）
		var rv: Dictionary = sp.revive
		for e in r.effects:
			if not (e is Dictionary) or str(e.get("op", "")) != "revive":
				continue
			var steps: Array = []
			var removed := false
			for st in e.steps:
				if str(st.get("do", "")) == "gain" and str(st.get("resource", "")) in ["mp", "tp"] and rv.has("rate"):
					continue
				if str(st.get("do", "")) == "gain" and str(st.get("resource", "")) == "hp" and rv.has("rate") and not st.has("amount"):
					st.rate = float(rv.rate)
					st.round = "floor"
				removed = removed or str(st.get("do", "")) == "remove_self"
				steps.append(st)
			if bool(rv.get("once", false)) and not removed:
				steps.push_front({"do": "remove_self"})
			e.steps = steps
			if rv.has("chance"):
				if str(e.cond.get("kind", "")) == "down_each":
					e.cond.above = 1.0 - float(rv.chance)
				elif str(e.cond.get("kind", "")) == "down":
					e.cond.below = float(rv.chance)
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
			v += float(c.get("offset", 0.0))  # offset：变量的起点挪一挪（町甄纯真值原版开局就有 6 点，按稿子从 2 点算）
			for k in c.get("offset_with", {}):  # 带着这件再加（阿语寰怨：开局就有 2 滴仪式之血）
				if owns(a, k):
					v += float(c.offset_with[k])
			return 1.0 + clampf(v * per, 0.0, cap)
		"var_sum":  # 几个变量按权重相加（vars {变量号: 权重}）×per（非天吞剑：十把剑各一个变量）
			var s2 := XState.current
			var v2 := 0.0
			if s2 != null:
				for k in c.get("vars", {}):
					v2 += float(s2.variable(int(k))) * float(c.vars[k])
			return 1.0 + clampf(v2 * per, 0.0, cap)
		"target_hp_lost":  # 目标已损生命比例×per（渡鸦黑翼裁决：最多 +50%）
			return 1.0 + clampf((1.0 - float(b.hp) / maxf(1.0, float(b.mhp))) * per, 0.0, cap)
		"raven_soul":  # 渡鸦灵魂进度（满 15 万为 1）×cap
			return 1.0 + (cap * XRaven.progress(a) + 0.05 * XRaven.tq_over(a)) if XRaven.own(a) else 1.0
		"stat_ratio":  # 自己两项属性之比（num／den）到了 steps [[比, 倍率]…] 里的线取最高一档（黄泉幸运加段：幸运达到物攻一半、等于物攻）
			var r := float(a.param(STATS.find(str(c.num)))) / maxf(1.0, float(a.param(STATS.find(str(c.den)))))
			var m := 1.0
			for st in c.get("steps", []):
				if r >= float(st[0]):
					m = maxf(m, float(st[1]))
			return m
		"battle_turn":  # 本场已过的回合数×per（拳一无限超越：每回合 +3%，最多 10 回合；offset_with 带着这件开局就算几层）
			var nt := maxi(0, int(a.get_meta("xtq_turn", 0)) - 1) if a is Object else 0
			for k in c.get("offset_with", {}):
				if owns(a, k):
					nt += int(c.offset_with[k])
			return 1.0 + clampf(nt * per, 0.0, cap)
		"target_states":
			var n := 0
			for id in b.state_ids:
				if XSmartAI.harmful_state(int(id)):
					n += 1
			return 1.0 + clampf(n * per, 0.0, cap)
		"self_mp_lost":
			return 1.0 + clampf((1.0 - float(a.mp) / maxf(1.0, float(a.mmp))) * per, 0.0, cap)
		"self_mp_frac":  # 当前魔法占上限的比例本身当倍率（封顶 cap，缺省 1）：奈叶厄临星爆，配 mp_drain 放完耗光
			return clampf(float(a.mp) / maxf(1.0, float(a.mmp)), 0.0, float(c.get("cap", 1.0)))
		"self_hp_lost":  # 已损生命比例×per（牢大死亡坠机：每 10% +5%，最多 +30%）
			return 1.0 + clampf((1.0 - float(a.hp) / maxf(1.0, float(a.mhp))) * per, 0.0, cap)
		"target_hp_rate":  # 目标当前生命比例×per（南宫恨武痴执念：满血 +20%，随血量线性降到 0）
			return 1.0 + clampf(float(b.hp) / maxf(1.0, float(b.mhp)) * per, 0.0, cap)
		"self_shield":  # 护盾占「满盾」（自身生命上限×full）的比例×cap（钟离岩脊、立希震鼓：护盾满时 +30%）
			return 1.0 + cap * clampf(float(a.shield) / maxf(1.0, float(a.mhp) * float(c.get("full", 0.2))), 0.0, 1.0)
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
		"target_stack":  # 目标身上某状态的层数（on_hit stack 记的）×per（白晶晶毒爆：每层骨毒 +1.2／3.6）
			var n := int(b.state_data.get("_tq_stack_%d" % int(c.state), 0)) if b.is_state_affected(int(c.state)) else 0
			return 1.0 + clampf(n * per, 0.0, cap)
		"self_states":  # 自己身上状态数（增益减益都算），每个 +per（迪昂狂乱·灭）
			return 1.0 + clampf(float(a.state_ids.size()) * per, 0.0, cap)
		"self_cri_over":  # 暴击率超过 from（缺省 100%）的部分×per（紫霞剑气：每超 10% +3%，最多 +30%）
			return 1.0 + clampf((float(a.cri) - float(c.get("from", 1.0))) * per, 0.0, cap)
		"self_tp":  # 当前 TP×per（天蓬神霄净世诀：每 10 点 +3%，最多 +30%；配 tp_drain 放完耗光）
			return 1.0 + clampf(float(a.tp) * per, 0.0, cap)
		"cast_count":  # 本场放过列表里的技能几次（begin_action 记、开战清零），每次 +per：签弟的忏悔
			var n := 0
			if a is Object and a.has_meta("xtq_casts"):
				var m: Dictionary = a.get_meta("xtq_casts")
				for id in c.of:
					n += int(m.get(int(id), 0))
			for k in c.get("offset_with", {}):  # 带着这件开局就有几层（十三娘心绕：缠意 2 层）
				if owns(a, k):
					n += int(c.offset_with[k])
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
		"var_at_least":  # 变量（按 cap 封顶）至少 n（白起断天休：杀气 6 点时变大招）
			var vs := XState.current
			ok = vs != null and mini(int(c.get("cap", 999999)), int(vs.variable(int(c["var"])))) >= int(c.n)
		"agi_below_target":
			ok = float(a.agi) < float(b.agi)
		"agi_above_target":
			ok = float(a.agi) > float(b.agi)
		"atk_above_target":  # 大羿大力出奇迹：自己物攻（scale_with {要有: 倍数} 判定时放大，追星 1.3）高于目标物攻
			var k := 1.0
			for key in c.get("scale_with", {}):
				if owns(a, key):
					k = maxf(k, float(c.scale_with[key]))
			ok = float(a.atk) * k > float(b.atk)
		"target_state":
			ok = b.is_state_affected(int(c.state))
		"self_state_any":
			ok = (c.states as Array).any(func(id): return a.is_state_affected(int(id)))
		"target_state_any":
			ok = (c.states as Array).any(func(id): return b.is_state_affected(int(id)))
		"target_hp_above":
			ok = float(b.hp) >= float(b.mhp) * float(c.get("rate", 1.0))
		"target_hp_below":  # rate_with／rate_add_with {要有: 线}：专属物提高残血线（病娇巴雷特 25% → 35%）
			ok = float(b.hp) < float(b.mhp) * _rate(a, c)
		"self_hp_above":  # 自己生命不低于 rate（玉面狐狸朔月依依）
			ok = float(a.hp) >= float(a.mhp) * float(c.get("rate", 1.0))
		"self_hp_below":
			ok = float(a.hp) < float(a.mhp) * float(c.get("rate", 0.0))
		"target_full_hp":
			ok = float(b.hp) >= float(b.mhp)
		"raven_myth":  # 渡鸦神话形态里
			ok = XRaven.own(a) and XRaven.is_myth(a)
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
	if id == XGojo.ACTOR and XGojo.locked(id):
		return ""  # 五条悟没解锁最强之名
	if XTier.tier_of(id) == "" and id != XGojo.ACTOR:  # XTier 在原版档不算五条悟，天启篇名单照表
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
	if XGojo.ENABLED and not out.has(XGojo.ACTOR) and tier_of(XGojo.ACTOR, true) == tier:
		out.append(XGojo.ACTOR)  # 五条悟：XTier 在当前不是天启篇存档时不列他（开新局抽阵容时）
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
	if not (logic.has_meta("xtqs") and int(_fstore(logic).depth) > 0):
		_act_skill = int(skill.get("id", 0)) if u is XActor and skill is Dictionary else 0
	if not cards_on() or not (u is XActor) or not (skill is Dictionary):
		return
	var st := _fstore(logic)
	if int(st.depth) > 0:
		return
	st.act = {"u": u, "skill": skill, "targets": []}
	var casts: Dictionary = u.get_meta("xtq_casts") if u.has_meta("xtq_casts") else {}
	casts[int(skill.get("id", 0))] = int(casts.get(int(skill.get("id", 0)), 0)) + 1
	u.set_meta("xtq_casts", casts)
	u.set_meta("xtq_turn", int(logic.get("turn")) if logic is Object and logic.get("turn") != null else 0)  # 本场第几回合（battle_turn 条件）


static func after_apply(logic, u, skill, t, r := {}) -> void:
	_reflect(u, t, r)
	if t == null or not logic.has_meta("xtqs"):
		return
	var f: Dictionary = _fstore(logic).act
	if not f.is_empty() and is_same(f.u, u) and not f.targets.has(t):
		f.targets.append(t)
	if not f.is_empty() and is_same(f.u, u) and bool(r.get("critical", false)):
		f.crit = true  # 这次行动打出过暴击（charge.gain_crit）
	_kill_grow(logic, u, skill, t)
	_kill_tp(logic, u, skill, t, f)
	_on_hit(logic, u, skill, t, f)


## 状态行 reflect 比例：带这个状态的角色受到敌人伤害时反弹这么多（首领减半；云霄阵眼不灭、张楚岚进阶、南宫恨五绝神功）。
## 原版这类状态是 React 脚本按（伤害＋属性）×几十倍反弹，天启篇改成比例（effects_remove 去掉原脚本）
static func _reflect(u, t, r: Dictionary) -> void:
	if not CARDS or not (t is XActor) or u == null or u is XActor or not u.is_alive() or not cards_on():
		return
	var dmg := float(r.get("hp", 0.0))
	if dmg <= 0.0 or bool(r.get("missed", false)) or bool(r.get("evaded", false)):
		return
	var pct := 0.0
	for id in t.state_ids:
		var sp: Dictionary = _states.get(int(id), {})
		if sp.has("reflect"):
			var v := float(sp.reflect)
			for k in sp.get("reflect_with", {}):  # 带着这件反弹更多（张楚岚雷符：金光在时 30%）
				if owns(t, k):
					v = maxf(v, float(sp.reflect_with[k]))
			if sp.has("reflect_var") and XState.current != null:  # 按变量加成（马宝国肝帝积分：每 10 分 +1%，最多 +30%）
				var rv: Dictionary = sp.reflect_var
				v *= 1.0 + minf(float(rv.get("cap", 0.0)), maxf(0.0, float(XState.current.variable(int(rv.var)))) * float(rv.get("per", 0.0)))
			pct = maxf(pct, v)
	if pct <= 0.0:
		return
	if u is XEnemy and u.boss_difficulty_boss:  # 首领（开战时按 boss_id 记）
		pct *= 0.5
	u.hp = maxf(0.0, float(u.hp) - floorf(dmg * pct))
	if u.hp <= 0.0:
		u.add_state(1)


## 首领减半（稿子第一节「控制 1～2 回合，对首领减半或无效」；各期待办里的通用项）：卡开着时，角色给首领（boss_difficulty_boss）挂的
## 控制状态（XEnemy.boss_control_state）回合数减半、向下取整，1 回合的控制无效；其余减益（XBossStatus.kind_of＝Debuff：属性降低、持续伤害等）
## 回合数减半、向上取整、至少 1 回合。整场的状态（autoRemovalTiming 0）、敌人自己挂的不动。
## 技能行 boss {"状态号": "immune"／"half"／"ceil"／"full"／换成的状态号} 按招覆盖默认（申公豹神来之笔、碧霄伏龙击的眩晕在首领身上换成伤害 −30%）。
## 接在 XEnemy.add_state（无效、替换）和 XEnemy.reset_state_counts（回合数）
static var BOSS_RULE := true
static var _act_skill := 0  # 角色正在放的技能号（begin_action 记、end_action 清）


static func boss_rule(e, id: int):
	if not BOSS_RULE or not CARDS or not (e is XEnemy) or not e.boss_difficulty_boss or not cards_on():
		return ""
	if XImportedBalance.acting_battler() is XEnemy:
		return ""
	if _act_skill > 0:
		var o = spec(_act_skill).get("boss", {}).get(str(id))
		if o != null:
			return o if o is String else int(o)
	var st := XDB.rec("States", id)
	if st.is_empty() or int(st.get("autoRemovalTiming", 0)) == 0:
		return ""
	if XEnemy.boss_control_state(id):
		var u = XImportedBalance.acting_battler()
		var need = data().get("actors", {}).get(str(int(u.actor_id)), {}).get("boss_control", "") if u is XActor else ""
		return "ceil" if need != "" and owns(u, need) else "half"  # 角色行 boss_control：带着这件时控制按向上取整减半（唐三昊天锤：1 回合的也有效）
	var dot = st.get("dot")
	if XBossStatus.kind_of(st) == "Debuff" or (dot is Dictionary and not bool(dot.get("healing", false))):  # 持续伤害（卡里的 dot 状态没有减益标记）
		return "ceil"
	return ""


## 双持副手只算一半属性（稿子町甄悬胆、紫霞紫青缠绕、张三丰太极剑、艾琳幽璇、三笠红色围巾、夜隐重霞等，统一做）：
## 卡开着时，XActor._param_plus 里第二把武器的属性（含武器类型放大、法宝成长、自定义属性）×0.5；特性、被动照算
static var OFFHAND_HALF := true


static func offhand_half() -> bool:
	return OFFHAND_HALF and CARDS and cards_on()


## 百分比生命伤害对首领无效（第一节）：表里的技能在行动序列里按目标生命上限比例扣血（Hp -n%）时，首领不扣
static func boss_pct_immune(u, t, skill_id: int) -> bool:
	return BOSS_RULE and CARDS and u is XActor and t is XEnemy and t.boss_difficulty_boss and has(skill_id) and cards_on()


## add_state 之前：返回 -1 不挂、0 照常、>0 换成这个状态
static func boss_add(e, id: int) -> int:
	var r = boss_rule(e, id)
	if r is int:
		return r
	if r == "immune" or (r == "half" and int(XDB.rec("States", id).get("maxTurns", 1)) <= 1):
		return -1
	return 0


static func boss_turns(e, id: int, n: int) -> int:
	match boss_rule(e, id):
		"half":
			return maxi(1, n / 2)
		"ceil":
			return maxi(1, ceili(n / 2.0))
	return n


## 技能行 shield {pct, self}：放这招时给目标（self：给自己）加施放者生命上限这个比例的护盾（钟离、立希、云霄；只在正式结算时加）
static func after_formula(a, b, item: Dictionary) -> void:
	if not CARDS or not cards_on():
		return
	var sh: Dictionary = spec(int(item.get("id", 0))).get("shield", {})
	if sh.is_empty() or a == null:
		return
	var t = a if bool(sh.get("self", false)) or b == null else b
	t.add_shield(floorf(float(a.mhp) * float(sh.get("pct", 0.0))))


## 技能行 kill_tp {tp, need_skill}：这招打倒敌人时回 TP（孙权气吞万里），每次行动一次
static func _kill_tp(logic, u, skill, t, f: Dictionary) -> void:
	if not (u is XActor) or not (skill is Dictionary) or t.is_alive() or t.is_actor() or not cards_on():
		return
	var k: Dictionary = spec(int(skill.get("id", 0))).get("kill_tp", {})
	if k.is_empty() or (k.has("need_skill") and not owns(u, k.need_skill)) or f.is_empty() or f.get("kill_tp_done", false):
		return
	f.kill_tp_done = true
	u.tp = float(u.tp) + float(k.get("tp", 0.0))


## 角色行 on_hit [{skills, need, extend [状态], turns, state, rate, pick [状态…], tp}]：放表里的技能打中目标时（专属法宝效果）——
## extend：目标身上刚挂上（剩余回合等于状态原回合）的这些状态多持续 turns 回合；state＋rate：按几率给目标挂状态；pick：随机挂其中一个；tp：每段回 TP；tp_once：每次行动每个目标回一次。
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
		if r.has("tp_once"):  # 每次行动每个目标回一次 TP（花木兰战场经验：用大厅战技后回 TP）
			u.tp = float(u.tp) + float(r.tp_once)
		for st in r.get("extend", []):
			var id := int(st)
			var base := int(XDB.rec("States", id).get("maxTurns", 0))
			if t.is_state_affected(id) and int(t.state_turns.get(id, 0)) == base:
				t.state_turns[id] = base + int(r.get("turns", 1))
		if r.has("state") and t.is_alive() and logic._float("tianqi_skill_on_hit") < float(r.get("rate", 0.0)):
			t.add_state(int(r.state))
		if r.has("stack") and t.is_alive() and (not r.stack.has("rate") or logic._float("tianqi_skill_on_hit") < float(r.stack.rate)):  # 叠层（曹操霸道真气）：层数记在目标 state_data，封顶 cap（cap_with 专属物提高）；rate 按几率多叠（白晶晶毒吻）
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
## start_tp [{need, tp}] 开场 TP 至少这么多，foe_turns [{need, state, turns}] 改开局挂给敌人的状态的回合数
## （状态本身还被技能用，不改状态记录）
static func start_turns(list: Array, foes: Array = []) -> void:
	if not CARDS or not cards_on():
		return
	for a in list:
		if not (a is XActor):
			continue
		for r in data().get("actors", {}).get(str(int(a.actor_id)), {}).get("foe_turns", []):  # 开局挂给敌人的状态的回合数（拉尔垂恤：安抚多 1 回合）
			if not r.has("need") or owns(a, r.need):
				for e in foes:
					if e.is_state_affected(int(r.state)):
						e.state_turns[int(r.state)] = int(r.turns)
		var ch: Dictionary = data().get("actors", {}).get(str(int(a.actor_id)), {}).get("charge", {})
		if not ch.is_empty() and XState.current != null:  # 积攒点数开战归零（白起杀气不跨战斗累计），专属物给起始点数
			var n0 := 0
			for r in ch.get("start", []):
				if owns(a, r.need):
					n0 = maxi(n0, int(r.n))
			XState.current.set_variable(int(ch["var"]), n0)
			a.set_meta("xtq_charge_again", false)
		a.set_meta("xtq_casts", {})  # 本场放技能次数（cast_count 条件）
		XTianqiModules.battle_start(a, list, foes)  # 专属模块角色的天启篇开战处理（第七期）
		a.set_meta("xtq_turn", 0)
		sync_learn(a)
		for r in data().get("actors", {}).get(str(int(a.actor_id)), {}).get("start_tp", []):  # 开场 TP（天蓬吞云）
			if not r.has("need") or owns(a, r.need):
				a.tp = maxf(float(a.tp), float(r.tp))
		for r in data().get("actors", {}).get(str(int(a.actor_id)), {}).get("start_turns", []):
			if not r.has("need") or owns(a, r.need):
				for x in (list if r.get("party", false) else [a]):  # party：开局挂给全队的状态（花木兰念乡：振奋多 1 回合）
					if x is XBattler and x.is_state_affected(int(r.state)):
						x.state_turns[int(r.state)] = int(r.turns)


## 专属角色模块（渡鸦、米拉、黄泉、镜流、甚尔、宿傩、饿狼、云裳、璇、屠苏、流萤等）的伤害帧操作收口（第六期）：天启篇卡开着、放的是表里改写过的技能时，
## 模块自己的增伤乘区（终伤／技能／结算倍率 >1、终伤／普通／元素／暴击加成 >0）去掉，增伤改由卡里的被动和条件按预算给；
## 无视双防最多 30%（防御率乘数不低于 0.7），抗性穿透最多 10%；承伤、治疗、伤害种类这些照旧。原版档、卡没开、别的技能原样返回。
static var MODULE_CAP := true


static func module_ops(item: Dictionary, a, ops: Array) -> Array:
	if not MODULE_CAP or not (a is XActor) or not has(int(item.get("id", 0))) or not cards_on():
		return ops
	var out := []
	for o in ops:
		var f := str(o.get("field", ""))
		var kind := str(o.get("op", ""))
		if kind == "mul" and f in ["finalMultiplier", "skillMultiplier", "settlementMultiplier"] and float(o.get("value", 1.0)) > 1.0:
			continue
		if kind == "add" and f in ["finalAdd", "normalAdd", "elementAdd", "criticalAdd"] and float(o.get("value", 0.0)) > 0.0:
			continue
		if kind == "mul" and f in ["magicalDefenseRate", "physicalDefenseRate"]:
			o = o.duplicate()
			o.value = maxf(float(o.value), 0.7)
		elif kind == "add" and f == "resistancePierce":
			o = o.duplicate()
			o.value = minf(float(o.value), 0.1)
		out.append(o)
	return out


## 伤害钩子（XActorDamageHooks.capture）：技能行 pierce {rate, need} 无视目标一部分双防；角色行 heal_mult [{need, mult}] 治疗量
static func damage_ops(item: Dictionary, a, b) -> Array:
	if not CARDS or not cards_on():
		return []
	var ops := []
	var id := int(item.get("id", 0))
	if has(id):
		var p: Dictionary = spec(id).get("pierce", {})
		if not p.is_empty() and (not p.has("need") or owns(a, p.need)) and (not p.has("when") or _when(p.when, a, b)):
			var keep := 1.0 - float(p.get("rate", 0.0))
			ops.append({"op": "mul", "field": "physicalDefenseRate", "value": keep})
			ops.append({"op": "mul", "field": "magicalDefenseRate", "value": keep})
	if a is XActor and int(item.get("damage", {}).get("type", 0)) in [3, 4]:
		for h in data().get("actors", {}).get(str(int(a.actor_id)), {}).get("heal_mult", []):
			if not h.has("need") or owns(a, h.need):
				ops.append({"op": "mul", "field": "healingMultiplier", "value": float(h.mult)})
	return ops


## 一条伤害条件当开关用：成立为真（pierce.when：三笠后颈斩目标生命低于 30% 才无视物防）
static func _when(c: Dictionary, a, b) -> bool:
	var probe := c.duplicate()
	probe.mult = 2.0
	return _cond(probe, a, b) > 1.0


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


## 技能行 hp_equalize 加成比例：放完把己方活着的人生命比例拉平到平均值再加这么多（孙权制衡；原版 Before/After Eval 没移植）
static func _hp_equalize(logic, u, skill: Dictionary) -> void:
	var sp := spec(int(skill.get("id", 0)))
	if not sp.has("hp_equalize") or not u.is_alive():
		return
	var mates: Array = logic.alive(logic.actors) if u.is_actor() else logic.alive(logic.enemies)
	if mates.is_empty():
		return
	var avg := 0.0
	for m in mates:
		avg += float(m.hp) / maxf(1.0, float(m.mhp))
	avg = minf(1.0, avg / mates.size() + float(sp.hp_equalize))
	for m in mates:
		m.hp = clampi(floori(avg * float(m.mhp)), 1, int(m.mhp))


## 技能行 self_heal {pct, need_skill, pct_with {要有: 比例}}：放完自己回生命上限的这个比例（陈醉拳打完回 10%，酒仙 20%）
static func _self_heal(u, skill: Dictionary) -> void:
	var h: Dictionary = spec(int(skill.get("id", 0))).get("self_heal", {})
	if h.is_empty() or not u.is_alive() or (h.has("need_skill") and not owns(u, h.need_skill)):
		return
	var pct := float(h.get("pct", 0.0))
	for k in h.get("pct_with", {}):
		if owns(u, k):
			pct = maxf(pct, float(h.pct_with[k]))
	u.hp = minf(float(u.mhp), float(u.hp) + floorf(float(u.mhp) * pct))


## 技能行 consume [状态…]：放完把打到的目标身上这些状态去掉（劲夫乱打引爆怒拳）；consume_keep_with {要有: 几率} 有几率不去
## 角色行 charge（白起杀气，第四期待办）：{var, cap, gain {技能号: 点}, gain_crit {need, n}, spend {技能号: [低档, 高档]}, refund_kill {need, rate}, start [{need, n}], full_again 技能号}。
## 卡开着时原版的凝聚／释放公共事件（422／423）从技能上去掉，由这里接管：放 gain 里的招得点（这次行动暴击过、学了 gain_crit.need 再多 n），封顶 cap；
## spend 里的招够高档耗高档、不然耗低档（不够低档不能放，技能行 need_var，见 meets）；这招打倒了目标、学了 refund_kill.need 时返还耗掉的 rate；
## 开战点数归零，专属物 start 给起始点数；学了 full_again 的，点数第一次攒满 cap 的那次行动之后本回合再动一次（每场一次）。伤害的高档加成写在技能的 var_at_least 条件里
static func _charge(logic, u, f: Dictionary) -> void:
	if not (u is XActor) or XState.current == null:
		return
	var ch: Dictionary = data().get("actors", {}).get(str(int(u.actor_id)), {}).get("charge", {})
	if ch.is_empty():
		return
	var s := XState.current
	var vid := int(ch["var"])
	var cap := int(ch.get("cap", 6))
	var sid := str(int(f.skill.get("id", 0)))
	var v := mini(cap, int(s.variable(vid)))
	var before := v
	if ch.get("gain", {}).has(sid):
		v += int(ch.gain[sid])
		var gc: Dictionary = ch.get("gain_crit", {})
		if bool(f.get("crit", false)) and not gc.is_empty() and owns(u, gc.need):
			v += int(gc.get("n", 1))
	if ch.get("spend", {}).has(sid):
		var tiers: Array = ch.spend[sid]
		var cost := int(tiers[1]) if tiers.size() > 1 and v >= int(tiers[1]) else int(tiers[0])
		cost = mini(cost, v)
		v -= cost
		var rk: Dictionary = ch.get("refund_kill", {})
		if not rk.is_empty() and owns(u, rk.need) and (f.targets as Array).any(func(t): return t is XBattler and not t.is_alive()):
			v += int(floorf(cost * float(rk.get("rate", 0.5))))
	v = clampi(v, 0, cap)
	s.set_variable(vid, v)
	if ch.has("full_again") and v >= cap and before < cap and owns(u, ch.full_again) and not bool(u.get_meta("xtq_charge_again", false)) and u.is_alive():
		u.set_meta("xtq_charge_again", true)
		logic.current_order.append(u)


## 技能行 ally_state {need, state}：学了 need 时，放完再给生命比例最低的一个队友挂这个状态（诸葛逆天改命：七星续命给队友）
static func _ally_state(u, skill: Dictionary) -> void:
	var r: Dictionary = spec(int(skill.get("id", 0))).get("ally_state", {})
	if r.is_empty() or not (u is XActor) or not owns(u, r.need) or XState.current == null:
		return
	var best = null
	for x in XState.current.battle_members():
		if x != u and x is XActor and x.is_alive() and not x.is_state_affected(int(r.state)) and (best == null or float(x.hp) / maxf(1.0, float(x.mhp)) < float(best.hp) / maxf(1.0, float(best.mhp))):
			best = x
	if best != null:
		best.add_state(int(r.state))


## 技能行 foe_drain：放完敌人全体各掉当前生命的这个比例（首领无效；唐三寄生 0.03）
static func _foe_drain(logic, u, skill: Dictionary) -> void:
	var pct := float(spec(int(skill.get("id", 0))).get("foe_drain", 0.0))
	if pct <= 0.0 or not (u is XActor):
		return
	for e in logic.enemies:
		if e is XEnemy and e.is_alive() and not e.hidden and not (BOSS_RULE and e.boss_difficulty_boss):
			e.hp = maxf(1.0, float(e.hp) - floorf(float(e.hp) * pct))


## BattleLogic.battle_skills：角色行 battle_extra [{need, skill}]：带着这件时战斗技能列表多出这一招（诸葛命星：战斗中的五行移位）
static func battle_extra(a) -> Array:
	if not CARDS or not (a is XActor) or not cards_on():
		return []
	var out := []
	for r in data().get("actors", {}).get(str(int(a.actor_id)), {}).get("battle_extra", []):
		if owns(a, r.need):
			var rec := XDB.rec("Skills", int(r.skill))
			if not rec.is_empty():
				out.append(rec)
	return out


## BattleLogic.can_use：技能行 need_var {var, min}：变量不够不能放（白起断天休要 3 点杀气）
static func meets(a, skill: Dictionary) -> bool:
	if not (a is XActor) or not CARDS:
		return true
	var nv: Dictionary = spec(int(skill.get("id", 0))).get("need_var", {})
	if nv.is_empty() or not cards_on() or XState.current == null:
		return true
	return int(XState.current.variable(int(nv["var"]))) >= int(nv.get("min", 0))


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
	if not g is Dictionary or not (g.get("params", [g.get("param", -1)]) as Array).any(func(x): return int(x) == i) or not cards_on():  # params：一次涨几项（白晶晶敏捷、幸运）
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
	if int(st.depth) == 0:
		_act_skill = 0
	if int(st.depth) == 0 and not f.is_empty() and is_same(f.u, u):
		_var_add(u, f.skill)
		_foe_states(logic, u, f.skill)
		if bool(spec(int(f.skill.get("id", 0))).get("tp_drain", false)):
			u.tp = 0.0  # 技能行 tp_drain：放完耗光 TP（天蓬神霄净世诀）
		_consume(logic, u, f)
		_charge(logic, u, f)
		_ally_state(u, f.skill)
		_foe_drain(logic, u, f.skill)
		if bool(spec(int(f.skill.get("id", 0))).get("free_action", false)) and u.is_alive():
			logic.current_order.push_front(u)  # 技能行 free_action：不占行动，放完马上再动一次（诸葛命星：战斗中切五行）
		_hp_equalize(logic, u, f.skill)
		_self_heal(u, f.skill)
		if u.is_alive():
			for sid in spec(int(f.skill.get("id", 0))).get("self_states", []):  # 技能行 self_states：放完给自己挂状态（高松灯碧天独行：之后 2 回合暴击 +20%、承伤 +20%）
				u.add_state(int(sid))
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
