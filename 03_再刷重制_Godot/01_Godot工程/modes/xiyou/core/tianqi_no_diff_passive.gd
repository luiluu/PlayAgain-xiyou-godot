class_name XTianqiNoDiffPassive
extends RefCounted
## 【cc·天启篇·未经审查】天启篇开局不发难度被动（天启篇设计总览 v0.2 第二节，Kyo 11-08 定；影响审查 v0.6 第二节前三行）。
## 只对天启篇存档（XTianqi.active）生效，西游档一个字不改。
##
## 原来天启篇借原版「普通」开局，全员学三个被动：
## - 普通难度 5548（开战挂 1631：正伤害 ceil(×1.5)；passiveIRUP／GRUP 各 +10）
## - 难度适应 5980（开战挂 1691：非零的伤害和治疗都 ceil(×5)；封宝宝、坐骑、圣器、形态）
## - 天道诅咒 6168（开战挂 995：正伤害 ceil(×0.8)、敏捷特性 ×0.8；passiveXPBST2 暴击率 +50%）
## 现在不学（拦在 XActor.learn_skill），老档读档时剥掉，净效果改读数值表 balance_table.json 的 legacy_passive 一节，玩家强度不变：
## - 结算伤害：确认阶段（攻击方 Confirm）照三个状态在状态表里的位置插入同样的「ceil 乘」三步，和因果丝线等别的确认乘区照旧逐个连乘
##   （不并成 ×6 放进出伤乘区：那样取整、治疗 ×5、和别的确认效果的先后都会变）。
## - 敏捷：战斗中（param_cache_on，开战挂状态到战后）能力倍率特性加 agi_rate（CP_StateFloor 下特性 21 是加算：1＋Σ(值−1)）。
## - 暴击率：在 passiveXPBST 被动同一位置加 crit_add（原版是学会的被动，战斗内外都算）。
## - 掉率、金钱：天启篇早就不算这几个被动（drop_table／金钱表 ignore_skills），改由难度奖励倍率 scaling.reward；这里不再动。
## - 封印：坐骑封印天启篇本来不认（XTianqiGear），宝宝、圣器、形态三栏天启篇已删，没被动也封不上，无需替代。
## 已知差别（交付单写明）：身上少三个状态，按状态个数算的效果（三重气元拳 user.states().length≥5、虚无按目标状态数增伤）少算 3 个；
## 开战少掷三次「开战状态」随机数，同一种子后面的随机流会错位；战斗外的敏捷不再 ×0.8（原版首战后状态留在身上，影响先制判定）。
##
## 开关（O-待定）：ENABLED＝false 回到原来（照学三个被动，不加等价项，读档不剥）。

static var ENABLED := true

const SKILLS := [5548, 5980, 6168]
const STATES := [1631, 1691, 995]
const AGI := 6
const CRIT := 2
const TRAIT_PARAM := 21


static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s)


static func table() -> Dictionary:
	var t = XTianqiBalance.data().get("legacy_passive", {})
	return t if t is Dictionary else {}


## XActor.learn_skill：天启篇存档里这三个被动不学
static func blocks_learn(id: int) -> bool:
	return SKILLS.has(id) and on()


## 读档（XState.sync_difficulty_after_load 开头）：剥掉老天启篇存档里已学的三个被动和它们挂上的状态；返回剥掉了几项
static func strip(s: XState) -> int:
	if not on(s):
		return 0
	var n := 0
	for aid in s.actors.keys():
		var a: XActor = s.actors[aid]
		if a == null:
			continue
		var before := n
		for sid in SKILLS:
			if a.skill_ids.has(sid):
				a.forget_skill(sid)
				n += 1
		for st in STATES:
			if a.state_ids.has(st):
				a.state_ids.erase(st)
				a.state_turns.erase(st)
				n += 1
		if n > before:
			a.refresh_passive()
	return n


## XState._difficulty_profile：按难度开关取基础被动时，天启篇不再给这三个（开关 2491 照旧开着，事件分支照读）
static func filter_profile_skills(s: XState, skills: Array) -> Array:
	if not on(s):
		return skills
	return skills.filter(func(sid): return not SKILLS.has(int(sid)))


# ---- 等价项 ----

## 确认阶段（XStateEffects.run "confirm"）：持有者是天启篇角色时，把 legacy_passive.settle 的三步按状态顺序插进 rows。
## 身上真带着那个状态的（老档还没剥、或测试手挂）不插，免得叠两遍。
static func confirm_rows(holder: XBattler, rows: Array) -> Array:
	if not holder is XActor or not on():
		return rows
	var settle: Array = table().get("settle", [])
	if settle.is_empty():
		return rows
	var out := rows
	for row in settle:
		var sid := int(row.get("state", 0))
		if sid <= 0 or holder.is_state_affected(sid):
			continue
		var prio := int(XDB.rec("States", sid).get("priority", 0))
		var syn := {"id": sid, "priority": prio, "name": "天启篇·难度被动等价", "effects": [{"phase": "confirm", "op": "mul",
			"cond": str(row.get("cond", "positive")), "hpOnly": false, "k": float(row.get("k", 1.0)), "round": str(row.get("round", "ceil"))}]}
		var at := out.size()
		for i in out.size():
			var p := int(out[i].get("priority", 0))
			if p < prio or (p == prio and int(out[i].get("id", 0)) > sid):
				at = i
				break
		if out == rows:
			out = rows.duplicate()
		out.insert(at, syn)
	return out


## XActor.traits_pi：战斗中敏捷的能力倍率加 agi_rate（加算，同 CP_StateFloor 的 1＋Σ(值−1)）
static func traits_pi(a: XActor, code: int, id: int, v: float) -> float:
	if code != TRAIT_PARAM or id != AGI or not a.param_cache_on or not on():
		return v
	var add := float(table().get("agi_rate", 0.0))
	if add == 0.0 or a.is_state_affected(995):
		return v
	return maxf(0.0, v + add)


## XActor._xparam_now：暴击率加 crit_add（passiveXPBST2 同位置）
static func xparam_add(a: XActor, i: int) -> float:
	if i != CRIT or not on() or a.skill_ids.has(6168):
		return 0.0
	return float(table().get("crit_add", 0.0))
