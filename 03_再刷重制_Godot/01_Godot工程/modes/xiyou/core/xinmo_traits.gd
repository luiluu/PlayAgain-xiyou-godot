class_name XTianqiXinmoTraits
extends RefCounted
## 天启篇心魔特点（T316 设计 v0.3「特点本身越往后越异化」，Kyo 11-20「245按推荐」；T318 建框架＋前三条）。
## 只管天启篇闭关开的烙印心魔试炼：XGuardianRework.xinmo_setup 末尾经钩子 XGuardianRework.xinmo_traits(logic, s) 调 setup，
## 按 XZhenqi.battle.trial.target（1～6：不染、铸骨、砥柱、真形、迎劫、逆命）挂唯一一条本段特点，不叠前场的。
## 底盘（血量、双防、出伤倍率、招式池）照 T315 跟同层守层者，本模块只在上面加特点；不碰选目标、不加闪避／回血／吸血／护盾／即死。
## 已实装（DONE）：1 沾尘、2 透骨、3 逆流；4 盗形、5 影劫、6 同堕的参数与文字已在表里，等 T316-a2 接（没接的段这一场不挂特点）。
## 挂点（BattleLogic）：setup 开场报特点（take_logs）、act／_forced_run 开头 act_begin（一次行动对同一人最多判一次）、
## execute_hp_damage 开头 hp_damage（book_heal 之后、七印殉印／灰印、临终、号卷四号这些保命之前）、末尾 after_hp、
## 生命回复 heal（各线与虚不受补之后；ResourceContext._gain 同）、end_turn 回合末、end_battle 收尾 end。
## 本场状态挂在 BattleLogic 的 meta 上，不进存档。回退：ENABLED = false（回到 T315 只对齐、无特点）。

const PATH := "res://modes/xiyou/tianqi_data/xinmo_traits.json"
const META := "tianqi_xinmo_traits"
## 已经实装的特点键（其余段这一场不挂特点、战前也不提示）
const DONE := ["zhanchen", "tougu", "niliu"]
const DEATH_STATE := 1

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
		"seen": {}, "fracture": {}, "surge": 0, "queue": [{"type": "battle_text", "text": str(r.get("open", ""))}]}
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

## act／_forced_run 开头（紧邻 XTianqiBrand.act_begin）：开一次新的行动，同一行动对同一人最多判一次
static func act_begin(logic) -> void:
	var c := fight(logic)
	if not c.is_empty():
		c.seen = {}


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


## BattleLogic.execute_hp_damage 开头（book_heal 之后、保命之前）：心魔打我方的出伤倍率（整数百分比）。
## 只处理正伤害；回复（负值）、不是心魔打我方的原样返回；不带 item 的脚本伤害按普通出手一样乘
static func hp_damage(logic, u, t, value: float, _item := {}) -> float:
	var c := fight(logic)
	if c.is_empty() or value <= 0.0 or not _xinmo_hits(logic, c, u, t):
		return value
	var pct := 100
	match str(c.key):
		"zhanchen":
			if debuff_count(t) >= _p(c, "need_debuffs"):
				pct = _p(c, "bonus_dmg_pct")
		"tougu":
			pct = 100 + fracture(logic, t) * _p(c, "per_stack_pct")
		"niliu":
			pct = 100 + int(c.surge)
	if pct == 100:
		return value
	return floorf(value * pct / 100.0)


## BattleLogic.execute_hp_damage 末尾（读 hubris_before）：沾尘挂弱化、透骨叠／消骨裂
static func after_hp(logic, u, t, value: float, hp_before: float, _item := {}) -> void:
	var c := fight(logic)
	if c.is_empty() or value <= 0.0 or not _xinmo_hits(logic, c, u, t):
		return
	if c.seen.has(t):
		return
	c.seen[t] = true
	match str(c.key):
		"zhanchen":
			if not t.is_dead():
				_zhanchen(logic, c, u, t)
		"tougu":
			_tougu(logic, c, t, hp_before)


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
		t.buff_turns[pid] = maxi(t.buff_turns[pid], turns)  # 已是弱化：只刷新回合，不往下压（上限 −1 级）
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
		cur.stacks = maxi(int(cur.stacks) - _p(c, "block_shed"), 0)  # 防御或护盾完全挡下：不叠层并消层
		if int(cur.stacks) <= 0:
			fr.erase(t)
		else:
			fr[t] = cur
		c.queue.append({"type": "battle_text", "text": str(c.texts.get("shed", "")) % name})


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
		if XTianqiBrand.has_cost(b, "weak_heal"):
			return amount  # 虚不受补已经减半了，不叠乘成 25%
		return floorf(amount * _p(c, "high_hp_heal_pct") / 100.0)
	return floorf(amount * _p(c, "low_hp_heal_pct") / 100.0)


# ---- 回合末 ----

## BattleLogic.end_turn 末尾：骨裂倒计时；逆流冲刷高血的人（直接改血蓝，不算受到伤害、不涨印纹、不致死）并定下一回合增伤
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
