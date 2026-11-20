class_name XTianqiXinmoTraits
extends RefCounted
## 天启篇心魔特点（T316 设计 v0.3「特点本身越往后越异化」，Kyo 11-20「245按推荐」；T318 建框架＋前三条，T319 接后三条）。
## 只管天启篇闭关开的烙印心魔试炼：XGuardianRework.xinmo_setup 末尾经钩子 XGuardianRework.xinmo_traits(logic, s) 调 setup，
## 按 XZhenqi.battle.trial.target（1～6：不染、铸骨、砥柱、真形、迎劫、逆命）挂唯一一条本段特点，不叠前场的。
## 底盘（血量、双防、出伤倍率、招式池）照 T315 跟同层守层者，本模块只在上面加特点；不碰选目标、不加闪避／回血／吸血／护盾／即死。
## 已实装（DONE）：1 沾尘、2 透骨、3 逆流（T318）；4 盗形、5 影劫、6 同堕（T319）。
## 挂点（BattleLogic）：setup 开场报特点（take_logs）、act／_forced_run 开头 act_begin（一次行动对同一人最多判一次、记是不是发作行动、影劫记挑战者的招）、
## start_turn 末尾（盗形双数回合剥增益、影劫蓄势、同堕重算队伍烙印）、decide 敌人分支（影劫重演回合换成【影·原招】）、
## execute_hp_damage 开头 hp_damage（book_heal 之后、七印殉印／灰印、临终、号卷四号这些保命之前）、末尾 after_hp、
## 生命回复 heal（各线与虚不受补之后；ResourceContext._gain 同）、end_turn 回合末、end_battle 收尾 end；
## XTianqiBrand 印纹满槽（sear_add）与自发发作（_start_fit，source 不是 sear）通知 on_brand_resonance（同堕叠堕势）。
## 本场状态挂在 BattleLogic 的 meta 上，不进存档。回退：ENABLED = false（回到 T315 只对齐、无特点）。

const PATH := "res://modes/xiyou/tianqi_data/xinmo_traits.json"
const META := "tianqi_xinmo_traits"
## 已经实装的特点键（其余段这一场不挂特点、战前也不提示）
const DONE := ["zhanchen", "tougu", "niliu", "daoxing", "yingjie", "tongduo"]
const DEATH_STATE := 1
const GUARD_STATE := 2
## 盗形第一类：标准能力值正增益（物攻、物防、魔攻、魔防、敏捷、幸运）
const BUFF_PARAMS := [2, 3, 4, 5, 6, 7]
const PARAM_NAMES := {2: "物攻", 3: "物防", 4: "魔攻", 5: "魔防", 6: "敏捷", 7: "幸运"}
## 盗形第二类状态：备注里有这些标签的一律不剥（不区分大小写；<Custom 排除一切自定义脚本状态）
const STEAL_BANNED_TAGS := ["<permanent>", "<passive state>", "<cannot dispel>", "<custom"]
## 【影·原招】合成技能号（r3 P1-1）：不用普攻号 1，is_attack 为假，不吃普攻追加次数（特性 34），只打 1 段；
## 也不会按 1 号去查 CodexDamageElements 的 mode（r3 P3-2），物魔照 hitType。不用 0：别处有「没记技能＝0」的默认值（云裳派生帧 mastery_skill），
## 0 会撞上；99319 不在技能表里（表到 10633，天启篇新技能在 11xxx），按号查表都是空、照默认走
const YING_SKILL_ID := 99319
const YING_KEY := "_xinmo_trait"

static var ENABLED := true
## 测试用：>= 0 时沾尘几率掷点固定为这个百分数（0 必中，100 必不中）；-1 走本场随机流
static var force_roll := -1.0
## 测试用：>= 0 时沾尘挑第几个候选能力值（debuff_params 的下标）
static var force_param := -1

static var _data: Dictionary = {}
static var _logic_ref: WeakRef = null


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiXinmoTraits: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiXinmoTraits: JSON 解析失败 " + PATH)
	return _data


static func clear_cache() -> void:
	_data = {}


## 段位 target（1～6）那一行；没有为空
static func row(target: int) -> Dictionary:
	return data().get("traits", {}).get(str(target), {})


## 段位 target 已实装的特点键；没实装、没有为 ""
static func trait_key(target: int) -> String:
	var k := str(row(target).get("key", ""))
	return k if DONE.has(k) else ""


## 开关开着、天启篇存档、心魔对齐开着（特点挂在对齐过的心魔上）
static func on(s = null) -> bool:
	return ENABLED and XGuardianRework.XINMO and XTianqiBrand.on(s)


## XZhenqi._brand_trial 战前提示：「心魔特点【沾尘】：……」；不挂特点为 ""
static func trial_line(s, target: int) -> String:
	if not on(s) or trait_key(target) == "":
		return ""
	var r := row(target)
	return "\\C[2]心魔特点【%s】\\C[0]：%s" % [str(r.get("name", "")), str(r.get("desc", ""))]


## 本场的特点状态（不是心魔特点战为空）
static func fight(logic) -> Dictionary:
	return logic.get_meta(META) if logic != null and logic.has_meta(META) else {}


static func active_logic():
	var l = _logic_ref.get_ref() if _logic_ref != null else null
	return l if l != null and l.has_meta(META) else null


## 本场挂的特点键（没挂为 ""）
static func key_of(logic) -> String:
	return str(fight(logic).get("key", ""))


# ---- 开战 ----

## XGuardianRework.xinmo_traits 转调（xinmo_setup 末尾：对齐、重标血量之后）
static func setup(logic, s) -> void:
	if logic != null and logic.has_meta(META):
		logic.remove_meta(META)  # T318 核查 P2-2：同一个战斗对象重开时先清旧状态
	_logic_ref = null
	if logic == null or not on(s) or not XGuardianRework.xinmo_on(logic):
		return
	var trial: Dictionary = XZhenqi.battle.get("trial", {})
	if not bool(trial.get("brand", false)):
		return  # 西游档真气瓶颈之战不挂
	var target := int(trial.get("target", 0))
	var key := trait_key(target)
	if key == "":
		return
	var xm := []
	for e in logic.enemies:
		if not e.hidden and XGuardianRework.xinmo_floor(e) > 0:
			xm.append(e)
	if xm.is_empty():
		return
	var r := row(target)
	var c := {"key": key, "target": target, "p": r.get("params", {}), "texts": r.get("texts", {}), "xinmo": xm,
		"challenger": int(trial.get("actorId", 0)), "seen": {}, "fracture": {}, "surge": 0, "queue": [],
		"act_u": null, "act_fit": false, "act_hit": false, "dealt": {},
		"stacks": 0, "turns": 0,  # 盗形
		"mirror": {}, "ying": 0, "charge_turn": -99, "cast_turn": -99,  # 影劫
		"avg": 0, "res": 0, "fall": 0, "fall_turns": 0, "gain_turn": -99, "gained": 0, "suppress_to": -99}  # 同堕
	var open := str(r.get("open", ""))
	if key == "tongduo":
		_resonance(logic, c)
		open = open % [int(c.avg), int(c.res)]
	c.queue.append({"type": "battle_text", "text": open})
	logic.set_meta(META, c)
	_logic_ref = weakref(logic)


## BattleLogic.setup 开场、act／_forced_run 收尾：把攒着的战报交出去
static func take_logs(logic) -> Array:
	var c := fight(logic)
	if c.is_empty():
		return []
	var out: Array = c.queue
	c.queue = []
	return out


## BattleLogic.end_battle：清本场状态
static func end(logic) -> void:
	if logic != null and logic.has_meta(META):
		logic.remove_meta(META)
	if _logic_ref != null and _logic_ref.get_ref() == logic:
		_logic_ref = null


# ---- 行动 ----

## act／_forced_run 开头（紧邻 XTianqiBrand.act_begin，在发作替换之前）：开一次新的行动，同一行动对同一人最多判一次；
## 记这次是谁、是不是发作行动（发作的不算「清醒出手」）；影劫：挑战者非发作的伤害招记进映照
static func act_begin(logic, u = null, skill = null) -> void:
	var c := fight(logic)
	if c.is_empty():
		return
	c.seen = {}
	c.dealt = {}
	c.act_u = u
	c.act_fit = XTianqiBrand.is_fit_command(skill)
	c.act_hit = false
	if str(c.key) == "yingjie" and not c.act_fit:
		_mirror_note(c, u, skill)


static func _p(c: Dictionary, k: String) -> int:
	return int(c.p.get(k, 0))


## 心魔打我方出战的人
static func _xinmo_hits(logic, c: Dictionary, u, t) -> bool:
	return c.xinmo.has(u) and t is XActor and logic.actors.has(t)


## 目标身上的减益项数：负的能力值档＋减益类状态（不算阵亡）
static func debuff_count(t) -> int:
	var n := 0
	for v in t.buffs:
		if int(v) < 0:
			n += 1
	for id in t.state_ids:
		if int(id) != DEATH_STATE and XBossStatus.kind_of(XDB.rec("States", int(id))) == "Debuff":
			n += 1
	return n


## 透骨：目标身上的骨裂层数
static func fracture(logic, t) -> int:
	return int(fight(logic).get("fracture", {}).get(t, {}).get("stacks", 0))


## 我方打心魔（盗形、同堕的承伤减免用）
static func _hits_xinmo(logic, c: Dictionary, u, t) -> bool:
	return c.xinmo.has(t) and u is XActor and logic.actors.has(u)


static func _is_ying(item) -> bool:
	return item is Dictionary and str(item.get(YING_KEY, "")) == "yingjie"


## 同堕：这一回合在不在逆命镇压里
static func suppressed(logic) -> bool:
	return int(logic.turn) <= int(fight(logic).get("suppress_to", -99))


## BattleLogic.execute_hp_damage 开头（book_heal 之后、保命之前）：心魔打我方的出伤倍率、我方打心魔的承伤倍率（整数百分比）。
## 只处理正伤害；回复（负值）原样返回；不带 item 的脚本伤害按普通出手一样乘（不会是影劫）。
## 影劫：按影势分档乘，并对同一目标按整次行动累计封顶（r3 P1-1）
static func hp_damage(logic, u, t, value: float, item := {}) -> float:
	var c := fight(logic)
	if c.is_empty() or value <= 0.0:
		return value
	if _hits_xinmo(logic, c, u, t):
		var taken := 100
		match str(c.key):
			"daoxing":
				taken = 100 - int(c.stacks) * _p(c, "per_stack_taken_reduce_pct")
			"tongduo":
				if not suppressed(logic):
					taken = 100 - int(c.fall) * _p(c, "per_stack_taken_reduce_pct")
		return value if taken == 100 else floorf(value * taken / 100.0)
	if not _xinmo_hits(logic, c, u, t):
		return value
	if str(c.key) == "yingjie" and _is_ying(item):
		return _ying_value(c, t, value, item)
	var pct := 100
	match str(c.key):
		"zhanchen":
			if debuff_count(t) >= _p(c, "need_debuffs"):
				pct = _p(c, "bonus_dmg_pct")
		"tougu":
			pct = 100 + fracture(logic, t) * _p(c, "per_stack_pct")
		"niliu":
			pct = 100 + int(c.surge)
		"daoxing":
			pct = 100 + int(c.stacks) * _p(c, "per_stack_dealt_pct")
		"tongduo":
			var res := int(c.res)
			if suppressed(logic):
				res = res / 2  # 逆命镇压：共鸣减半（整数向下）
			pct = mini(100 + res + int(c.fall) * _p(c, "per_stack_dealt_pct"), _p(c, "total_dealt_cap_pct"))
	if pct == 100:
		return value
	return floorf(value * pct / 100.0)


## BattleLogic.execute_hp_damage 末尾（读 hubris_before）：沾尘挂弱化、透骨叠／消骨裂、影劫高势额外印纹、同堕双数引纹；
## 我方这次行动（本人的、非发作的，每行动一次）打中心魔：盗形震碎、影劫削势、同堕镇压
static func after_hp(logic, u, t, value: float, hp_before: float, item := {}) -> void:
	var c := fight(logic)
	if c.is_empty() or value <= 0.0:
		return
	if _hits_xinmo(logic, c, u, t):
		if c.act_hit or c.act_fit or not is_same(c.act_u, u):
			return  # 反击、发作行动不算；多段只算一次
		c.act_hit = true
		var me := int(u.actor_id) == int(c.challenger)
		match str(c.key):
			"daoxing":
				if me:
					_daoxing_break(c, u, t)
			"yingjie":
				_ying_shed(logic, c, me)
			"tongduo":
				if me:
					_tongduo_suppress(logic, c, u)
		return
	if not _xinmo_hits(logic, c, u, t):
		return
	if c.seen.has(t):
		return
	c.seen[t] = true
	if t.is_dead():
		return  # T318 核查 P2-1：这一下打死了不叠骨裂、不挂弱化、不加印纹、不播报
	match str(c.key):
		"zhanchen":
			_zhanchen(logic, c, u, t)
		"tougu":
			_tougu(logic, c, t, hp_before)
		"yingjie":
			if _is_ying(item) and bool(item.get("_ying_heavy", false)) and int(item.get("_ying_stacks", 0)) >= _p(c, "sear_min_stacks") and t.hp < hp_before:
				XTianqiBrand.sear_add(logic, t, _p(c, "sear_aoe_add") if bool(item.get("_ying_aoe", false)) else _p(c, "sear_single_add"))
		"tongduo":
			if int(logic.turn) % 2 == 0 and not t.is_guard() and t.hp < hp_before:
				XTianqiBrand.sear_add(logic, t, _p(c, "even_turn_sear_add"))


static func _zhanchen(logic, c: Dictionary, u, t) -> void:
	var roll: float = force_roll if force_roll >= 0.0 else logic._float("xinmo_zhanchen") * 100.0
	if roll >= float(_p(c, "chance_pct")):
		return
	var cands: Array = c.p.get("debuff_params", [])
	if cands.is_empty():
		return
	var i: int = force_param if force_param >= 0 else logic._mod(cands.size(), "xinmo_zhanchen_param")
	var pid := int(cands[i % cands.size()])
	var turns := _p(c, "debuff_turns")
	if t.buffs[pid] < 0:
		# 已是弱化：只刷新回合，不往下压（上限 −1 级）；刷新也照常吃减益有效度、幸运差（T318 P3，同 add_debuff_effect 的掷法）
		if logic._float("add_debuff") < t.debuff_rate(pid) * XBattleLogic._luk_rate(u, t):
			t.buff_turns[pid] = maxi(t.buff_turns[pid], turns)
		return
	logic.add_debuff_effect(u, t, pid, turns)  # 照常吃减益有效度、幸运差


static func _tougu(logic, c: Dictionary, t, hp_before: float) -> void:
	var fr: Dictionary = c.fracture
	var cur: Dictionary = fr.get(t, {"stacks": 0, "turns": 0})
	var name: String = t.display_name()
	if not t.is_guard() and t.hp < hp_before:
		var cap := _p(c, "max_stacks")
		cur.stacks = mini(int(cur.stacks) + 1, cap)
		cur.turns = _p(c, "turns")
		fr[t] = cur
		c.queue.append({"type": "battle_text", "text": str(c.texts.get("stack", "")) % [name, int(cur.stacks), cap]})
	elif int(cur.stacks) > 0:
		var shed := mini(_p(c, "block_shed"), int(cur.stacks))
		cur.stacks = int(cur.stacks) - shed  # 防御或护盾完全挡下：不叠层并消层
		if int(cur.stacks) <= 0:
			fr.erase(t)
		else:
			fr[t] = cur
		c.queue.append({"type": "battle_text", "text": str(c.texts.get("shed", "")) % [name, shed]})  # T318 P3：层数读实际消掉的


# ---- 治疗 ----

## 生命回复（BattleLogic 再生、ResourceContext._gain 的 hp，紧跟 XTianqiBrand.heal）：逆流高血受疗减半（已被虚不受补减过的不再减）、低血受疗提高
static func heal(b, amount: float) -> float:
	if amount <= 0.0 or not b is XActor:
		return amount
	var logic = active_logic()
	var c := fight(logic)
	if c.is_empty() or str(c.key) != "niliu" or not logic.actors.has(b):
		return amount
	if b.hp * 100.0 > b.mhp * _p(c, "heal_split_pct"):
		if _weak_healed(b):
			return amount  # 虚不受补这一下已经减半了，不叠乘成 25%
		return floorf(amount * _p(c, "high_hp_heal_pct") / 100.0)
	return floorf(amount * _p(c, "low_hp_heal_pct") / 100.0)


## 虚不受补这一下真的减过（有这条代价且血线在它的 hp_above 之上）：分界调到 50% 以下时，
## 在分界和 50% 之间的人虚不受补不减，逆流照减（T318 P3 边界）
static func _weak_healed(b) -> bool:
	if not XTianqiBrand.has_cost(b, "weak_heal"):
		return false
	return b.hp > b.mhp * float(XTianqiBrand.cost_row("weak_heal").get("hp_above", 0.5))


# ---- 回合开始 ----

## BattleLogic.start_turn 末尾：盗形双数回合剥增益、影劫蓄势预告、同堕重算队伍烙印；连同回合开始这段攒的战报（同堕叠势）一起交出
static func start_turn(logic) -> Array:
	var c := fight(logic)
	if c.is_empty():
		return []
	var turn := int(logic.turn)
	var alive: bool = c.xinmo.any(func(e): return e.is_alive())
	match str(c.key):
		"daoxing":
			if alive and turn % maxi(1, _p(c, "steal_interval")) == 0:
				_steal(logic, c)
		"yingjie":
			var first := _p(c, "first_warn_turn")
			if alive and turn >= first and (turn - first) % maxi(1, _p(c, "cycle_turns")) == 0:
				_ying_charge(logic, c, turn)
		"tongduo":
			_resonance(logic, c)
	return take_logs(logic)


# ---- 4 盗形 ----

## 盗形第二类：安全可驱散的临时正面状态（稿 3.4 细则 1 的六条全满足）
static func steal_safe_state(a, id: int) -> bool:
	if id == DEATH_STATE or id == GUARD_STATE:
		return false
	var st := XDB.rec("States", id)
	if st.is_empty() or XBossStatus.kind_of(st) != "Buff" or int(st.get("iconIndex", 0)) <= 0:
		return false
	if int(st.get("autoRemovalTiming", 0)) <= 0 or float(a.state_turns.get(id, 0)) <= 0.0:
		return false
	if not bool(st.get("removeAtBattleEnd", true)):
		return false
	var note := str(st.get("note", "")).to_lower()
	return not STEAL_BANNED_TAGS.any(func(tag): return note.contains(tag))


## a 身上能剥的项：[["buff", 能力值号] …先，["state", 状态号] …后]
static func stealables(a) -> Array:
	var out := []
	for pid in BUFF_PARAMS:
		if a.buffs[pid] > 0 and not XAlienBattle.blocks_buff_removal(a, pid):
			out.append(["buff", pid])
	for id in a.state_ids:
		if steal_safe_state(a, int(id)):
			out.append(["state", int(id)])
	return out


## 双数回合开头：按可剥项数从多到少（同数按站位）最多剥 max_steal_count 项、每人 1 项；先剥能力值增益，没有才剥状态。
## 剥下来的只折成盗形层数，不往心魔身上贴任何东西
static func _steal(logic, c: Dictionary) -> void:
	var cands := []
	for i in logic.actors.size():
		var a = logic.actors[i]
		if a.is_alive():
			var l := stealables(a)
			if not l.is_empty():
				cands.append([a, l, i])
	cands.sort_custom(func(x, y): return x[1].size() > y[1].size() or (x[1].size() == y[1].size() and x[2] < y[2]))
	var names := []
	for e in cands.slice(0, maxi(0, _p(c, "max_steal_count"))):
		var a = e[0]
		var it: Array = e[1][0]
		if str(it[0]) == "buff":
			logic.sequence_buff(a, int(it[1]), false, true, 0)
			names.append("%s的「%s强化」" % [a.display_name(), PARAM_NAMES.get(int(it[1]), "能力")])
		else:
			var st_name := str(XDB.rec("States", int(it[1])).get("name", ""))
			logic._state_remove(a, int(it[1]), false)
			names.append("%s的「%s」" % [a.display_name(), st_name])
	var cap := _p(c, "max_stacks")
	var gain := names.size() * _p(c, "stacks_per_steal") if not names.is_empty() else _p(c, "fallback_stacks")
	c.stacks = mini(int(c.stacks) + gain, cap)
	c.turns = _p(c, "turns")
	if names.is_empty():
		c.queue.append({"type": "battle_text", "text": str(c.texts.get("fallback", "")) % [int(c.stacks), cap]})
	else:
		c.queue.append({"type": "battle_text", "text": str(c.texts.get("steal", "")) % ["、".join(names), int(c.stacks), cap]})


## 挑战者本人清醒命中：震碎 1 层；心魔身上带减益时震碎 2 层
static func _daoxing_break(c: Dictionary, u, t) -> void:
	if int(c.stacks) <= 0:
		return
	var n := _p(c, "break_when_debuffed") if debuff_count(t) >= 1 else _p(c, "break_normal")
	var gone := mini(n, int(c.stacks))
	c.stacks = int(c.stacks) - gone
	if int(c.stacks) <= 0:
		c.turns = 0
	c.queue.append({"type": "battle_text", "text": str(c.texts.get("break", "")) % [u.display_name(), gone, int(c.stacks)]})


# ---- 5 影劫 ----

static func _mirror_of(u, sk: Dictionary) -> Dictionary:
	var nm := str(sk.get("name", ""))
	return {"name": nm if nm != "" else "本源一击", "hit_type": int(sk.get("hitType", 1)),
		"element_id": maxi(int(sk.get("damage", {}).get("elementId", 0)), 0),  # 普攻属性（−1）归成无属性
		"is_aoe": [2, 3, 4, 5, 6].has(int(sk.get("scope", 1))),
		"is_heavy": int(sk.get("id", 1)) != 1 and not u.is_attack(sk), "user": u.display_name()}


## 挑战者本人非发作的生命伤害／吸取招（不算物品、防御）：记进映照（蓄势回合里再出手就以最新的为准＝控招诱影）
static func _mirror_note(c: Dictionary, u, skill) -> void:
	if not u is XActor or int(u.actor_id) != int(c.challenger) or not skill is Dictionary or skill.is_empty():
		return
	if XBattleLogic.is_item(skill) or int(skill.get("id", 0)) == XBattleLogic.GUARD_SKILL:
		return
	if not [1, 5].has(int(skill.get("damage", {}).get("type", 0))):
		return
	c.mirror = _mirror_of(u, skill)


static func _challenger(logic, c: Dictionary):
	for a in logic.actors:
		if a is XActor and int(a.actor_id) == int(c.challenger):
			return a
	return null


## 蓄势回合开头：满层影势、明牌下回合的招；挑战者还没出过伤害招就取他第一个伤害类主动技能，再没有按普攻
static func _ying_charge(logic, c: Dictionary, turn: int) -> void:
	if c.mirror.is_empty():
		var a = _challenger(logic, c)
		if a != null:
			for sk in XAlienation.original_active(a):
				if [1, 5].has(int(sk.get("damage", {}).get("type", 0))):
					c.mirror = _mirror_of(a, sk)
					break
			if c.mirror.is_empty():
				c.mirror = {"name": "普通攻击", "hit_type": 1, "element_id": 0, "is_aoe": false, "is_heavy": false, "user": a.display_name()}
	if c.mirror.is_empty():
		return  # 挑战者不在出战里（换下去了）：这一轮不蓄
	c.ying = _p(c, "max_stacks")
	c.charge_turn = turn
	var m: Dictionary = c.mirror
	c.queue.append({"type": "battle_text", "text": str(c.texts.get("charge", "")) % [str(m.user), str(m.name), int(c.ying), str(m.name)]})


## 蓄势回合里我方行动命中心魔：挑战者削 challenger_shed、队友削 ally_shed
static func _ying_shed(logic, c: Dictionary, me: bool) -> void:
	if int(logic.turn) != int(c.charge_turn) or int(c.ying) <= 0:
		return
	c.ying = maxi(int(c.ying) - (_p(c, "challenger_shed") if me else _p(c, "ally_shed")), 0)
	c.queue.append({"type": "battle_text", "text": str(c.texts.get("shed", "")) % int(c.ying)})


## BattleLogic.decide 敌人分支：重演回合心魔的头一次行动换成【影·原招】（[合成技能, null]，目标照常选）；不是就 []
static func decide(logic, b) -> Array:
	var c := fight(logic)
	if c.is_empty() or str(c.key) != "yingjie" or not c.xinmo.has(b):
		return []
	var turn := int(logic.turn)
	if int(c.charge_turn) != turn - 1 or int(c.cast_turn) == turn or c.mirror.is_empty():
		return []
	c.cast_turn = turn
	var stacks := int(c.ying)
	c.ying = 0  # 影势这一下用掉
	return XConfusion.prepare_enemy(b, [ying_skill(c, stacks), null])


## 【影·原招】：心魔普攻 1 号复制一份（保留编好的公式，出伤是心魔自己的底子），借原招的名字、物魔必中、元素、单群；
## 技能号换成 YING_SKILL_ID（不算普攻、不吃追加次数），只打 1 段，纯生命伤害，清掉连击、效果、备注、脚本
static func ying_skill(c: Dictionary, stacks: int) -> Dictionary:
	var m: Dictionary = c.mirror
	var sk: Dictionary = XDB.rec("Skills", 1).duplicate(true)
	sk["id"] = YING_SKILL_ID
	sk["name"] = str(c.texts.get("skill", "%s")) % str(m.name)
	sk["hitType"] = int(m.hit_type)
	sk["scope"] = 2 if bool(m.is_aoe) else 1
	var dmg: Dictionary = sk.get("damage", {}).duplicate(true)
	dmg["type"] = 1
	dmg["elementId"] = int(m.element_id)
	sk["damage"] = dmg
	sk["repeats"] = 1
	sk["effects"] = []
	sk["note"] = ""
	sk["meta"] = {}
	sk["yep"] = {}
	sk[YING_KEY] = "yingjie"
	sk["_ying_stacks"] = stacks
	sk["_ying_aoe"] = bool(m.is_aoe)
	sk["_ying_heavy"] = bool(m.is_heavy)
	return sk


## 影劫这一下的数：按出手时的影势分档（单体乘档位；全体先乘 aoe_scale 再乘档位），对同一目标按整次行动累计不超过最大生命的护栏
static func _ying_value(c: Dictionary, t, value: float, item: Dictionary) -> float:
	var i := clampi(int(item.get("_ying_stacks", 0)), 0, 3)
	var v: float
	var cap_pct: int
	if bool(item.get("_ying_aoe", false)):
		v = floorf(value * _p(c, "aoe_scale_pct") * int(c.p.aoe_tier_pcts[i]) / 10000.0)
		cap_pct = int(c.p.aoe_hp_cap_pcts[i])
	else:
		v = floorf(value * int(c.p.single_tier_pcts[i]) / 100.0)
		cap_pct = int(c.p.single_hp_cap_pcts[i])
	var used := float(c.dealt.get(t, 0.0))
	v = clampf(v, 0.0, maxf(floorf(t.mhp * cap_pct / 100.0) - used, 0.0))
	c.dealt[t] = used + v
	return v


# ---- 6 同堕 ----

## 存活出战成员的烙印百分数（向下取整）求整数平均，折成共鸣增伤（封顶）
static func _resonance(logic, c: Dictionary) -> void:
	var live: Array = logic.actors.filter(func(a): return a is XActor and a.is_alive())
	var sum := 0
	for a in live:
		sum += int(floorf(XTianqiBrand.pct(a)))
	c.avg = sum / live.size() if not live.is_empty() else 0
	c.res = mini(int(c.avg) * _p(c, "brand_scale_pct") / 100, _p(c, "resonance_cap_pct"))


## 挑战者本人清醒命中：消堕势、逆命镇压本回合与下回合（可刷新）
static func _tongduo_suppress(logic, c: Dictionary, u) -> void:
	var had := int(c.fall) > 0
	c.fall = maxi(int(c.fall) - _p(c, "suppress_shed"), 0)
	if int(c.fall) <= 0:
		c.fall_turns = 0
	c.suppress_to = int(logic.turn) + _p(c, "suppress_rounds") - 1
	c.queue.append({"type": "battle_text", "text": str(c.texts.get("suppress" if had else "suppress_only", "")) % u.display_name()})


## XTianqiBrand 通知：印纹满槽（kind "sear"）或自发发作（kind "fit"，_start_fit 里 source 不是 sear 才发，满槽当场引发的发作不重复数）。
## 同堕叠 1 层堕势（封顶、刷新回合），一回合全队最多 max_gain_per_turn 层。不是同堕心魔战 O(1) 返回
static func on_brand_resonance(logic, a, _kind: String) -> void:
	if logic == null or not logic.has_meta(META):
		return
	var c := fight(logic)
	if str(c.key) != "tongduo" or not a is XActor or not a.is_alive() or not logic.actors.has(a):
		return
	var turn := int(logic.turn)
	if int(c.gain_turn) != turn:
		c.gain_turn = turn
		c.gained = 0
	if int(c.gained) >= _p(c, "max_gain_per_turn"):
		return
	c.gained = int(c.gained) + 1
	var cap := _p(c, "max_stacks")
	c.fall = mini(int(c.fall) + 1, cap)
	c.fall_turns = _p(c, "stack_turns")
	c.queue.append({"type": "battle_text", "text": str(c.texts.get("stack", "")) % [int(c.fall), cap]})


# ---- 回合末 ----

## BattleLogic.end_turn 末尾：骨裂、盗形、堕势倒计时；影劫重演回合过了散影势；逆流冲刷高血的人（直接改血蓝，不算受到伤害、不涨印纹、不致死）并定下一回合增伤
static func end_turn(logic) -> Array:
	var c := fight(logic)
	if c.is_empty():
		return []
	var logs := []
	match str(c.key):
		"tougu":
			var fr: Dictionary = c.fracture
			for t in fr.keys():
				fr[t].turns = int(fr[t].turns) - 1
				if int(fr[t].turns) <= 0:
					fr.erase(t)
		"niliu":
			logs.append_array(_niliu_wash(logic, c))
		"daoxing":
			if int(c.stacks) > 0:
				c.turns = int(c.turns) - 1
				if int(c.turns) <= 0:
					c.stacks = 0
					c.turns = 0
		"yingjie":
			if int(logic.turn) == int(c.charge_turn) + 1:
				c.ying = 0  # 重演回合过了（心魔被控没出手也一样）：影势消散，不囤
		"tongduo":
			if int(c.fall) > 0:
				c.fall_turns = int(c.fall_turns) - 1
				if int(c.fall_turns) <= 0:
					c.fall = 0
					c.fall_turns = 0
	logs.append_array(take_logs(logic))
	return logs


static func _niliu_wash(logic, c: Dictionary) -> Array:
	c.surge = 0
	if not c.xinmo.any(func(e): return e.is_alive()):
		return []
	var logs := []
	var count := 0
	for a in logic.actors:
		if not a.is_alive() or a.hp * 100.0 <= a.mhp * _p(c, "wash_hp_pct"):
			continue
		count += 1
		var hp_loss := minf(floorf(a.hp * _p(c, "hp_loss_pct") / 100.0), a.hp - 1.0)
		var mp_loss := minf(floorf(a.mmp * _p(c, "mp_loss_pct") / 100.0), a.mp)
		if hp_loss > 0.0:
			a.hp -= hp_loss
		if mp_loss > 0.0:
			a.mp -= mp_loss
		if hp_loss > 0.0 or mp_loss > 0.0:
			a.refresh_resources()
			logs.append({"type": "regen", "target": a, "hp": maxf(hp_loss, 0.0), "mp": maxf(mp_loss, 0.0), "views": logic.views([a])})
	if count > 0:
		c.surge = mini(count * _p(c, "per_washed_dmg_pct"), _p(c, "max_surge_pct"))
		logs.append({"type": "battle_text", "text": str(c.texts.get("wash", "")) % [count, int(c.surge)]})
	return logs
