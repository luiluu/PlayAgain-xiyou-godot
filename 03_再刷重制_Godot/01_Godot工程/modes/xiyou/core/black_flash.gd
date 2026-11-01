class_name XBlackFlash
extends RefCounted
## 黑闪（正式 js/codex/runtime/installNativeBlackFlashRuntime.js，W.CodexBlackFlash），甚尔 171 与宿傩 172 共用。
## - 角色学了 10225 黑闪、活着才算启用（valid）；觉醒要学了觉醒技能（宿傩 10242）、带觉醒状态（宿傩 2639，甚尔 2635）、
##   且 expires ≥ round。每人战斗数据：集中 focus（0～4）、连闪 chain、觉醒到期 expires。
## - begin（startAction 之后、宿傩包装之前）：只认战斗中的主行动（不在反击／反射里、不是宿傩内部行动或强制行动），
##   建施放帧：概率 min(0.45, 0.1＋0.05×集中＋觉醒 0.15)，触发技能（宿傩 10230／10238，甚尔 10216～10219）、单体敌人、
##   生命伤害才 eligible。宿傩终式（三层转空间斩／次元斩）把 eligible 关掉（XSukuna.begin）。
## - evalDamageFormula 包装（formula）：本帧的这次 apply、目标是本次 apply 的目标且原值为正时，觉醒且技能在 awake 表里 ×1.2；
##   eligible、宿傩 canRoll（10238 或捌冲击段）、本帧还没判过、目标是施放时的第一个敌人且活着，就判一次：
##   随机 < 概率×(1−目标暴击闪避) 即黑闪，强制暴击（modifyCritical）、CodexDamage 暴伤加成 +[1, 1.2, 1.4, 1.6][min(连闪, 3)]。
## - executeHpDamage 包装：本次 apply 对敌人扣了血就记 damage；黑闪那次记 success（宣告「黑闪！」等，画面未接）。
## - finish（endAction，宿傩包装之后）：成功则集中归 0、连闪 +1、觉醒 3 回合（有觉醒技能才加状态），宿傩 onSuccess（学了 10242）
##   斩击强化 emp＝max(emp, min(连闪, 4))；失败则连闪归 0，eligible 且打出伤害时集中 +1（至 4）。
## - endRound（endTurn 之前，宿傩包装之后）：不再启用的清空；觉醒到期（round ≥ expires）去状态。round +1。
## - 不能行动（processTurn／OTB 判不能动）、逃跑时连闪归 0；开战、战斗结束、阵亡清空。
## 甚尔的额外一击（extraHitSkill 10216 觉醒时 _tojiHitCount＋1）在 XToji 的段数里（toji.gd「黑闪觉醒中的游云多 1 段」）。
## 未移植：遗忘 10225／觉醒技时清空、
## 说明框里的实时状态行、宣告的弹字与日志（画面）。旧档 unlock（学 10225／觉醒技）宿傩由 XSukuna.sync 管。

const SKILL := 10225
const STATE := 2635
const CONFIGS := {
	171: {"trigger": [10216, 10217, 10218, 10219], "awake": [10216, 10217, 10218, 10219], "awakening_skill": 10226, "state": STATE},
	172: {"trigger": [10230, 10238], "awake": [10229, 10230, 10231, 10232, 10233, 10234, 10235, 10238], "awakening_skill": 10242, "state": 2639},
}
const INCREMENT := [1.0, 1.2, 1.4, 1.6]

static var round := 0
static var serial := 0
static var nested := 0
static var cast := {}
static var hit := {}
static var _temp := {}


static func config(a) -> Dictionary:
	return CONFIGS.get(int(a.actor_id), {}) if a is XActor else {}


static func valid(a) -> bool:
	return not config(a).is_empty() and a.is_alive() and a.skill_ids.has(SKILL)


static func temp(a) -> Dictionary:
	if not _temp.has(a):
		_temp[a] = {"focus": 0, "chain": 0, "expires": -1}
	return _temp[a]


static func awake(a) -> bool:
	if not valid(a):
		return false
	var c := config(a)
	return a.skill_ids.has(int(c.awakening_skill)) and a.state_ids.has(int(c.state)) and int(temp(a).expires) >= round


static func probability(a, is_awake: bool) -> float:
	return minf(0.45, 0.1 + 0.05 * int(temp(a).focus) + (0.15 if is_awake else 0.0))


## B.status
static func status(a) -> Dictionary:
	if not valid(a):
		return {"unlocked": false, "focus": 0, "chain": 0, "awake": false, "probability": 0.0}
	var w := awake(a)
	return {"unlocked": true, "focus": int(temp(a).focus), "chain": int(temp(a).chain), "awake": w, "probability": probability(a, w),
		"remaining": maxi(0, int(temp(a).expires) - round) if w else 0}


static func _drop_awake(logic, a) -> void:
	var sid := int(config(a).state)
	if a.state_ids.has(sid):
		logic._state_remove(a, sid)


static func clear(logic, a) -> void:
	_temp.erase(a)
	if logic != null:
		_drop_awake(logic, a)


static func start_battle(logic) -> void:
	round = 0
	serial = 0
	nested = 0
	cast = {}
	hit = {}
	for a in logic.state.members():
		if not config(a).is_empty():
			clear(logic, a)


static func end_battle(logic) -> void:
	for a in logic.state.members():
		if not config(a).is_empty():
			clear(logic, a)
	cast = {}
	hit = {}


## B.begin：forcing／internal 不算主行动
static func begin(u, skill: Dictionary, targets: Array, forcing := false) -> void:
	cast = {}
	hit = {}
	if config(u).is_empty() or forcing or nested > 0 or XSukuna.internal or skill.is_empty():
		return
	var c := config(u)
	var t := temp(u)
	var target = null
	for e in targets:
		if e is XEnemy and e.is_alive():
			target = e
			break
	var active := valid(u)
	var w := active and awake(u)
	serial += 1
	cast = {"id": serial, "actor": u, "skill": int(skill.get("id", 0)), "target": target, "focus": int(t.focus), "chain": int(t.chain),
		"awake": w, "probability": probability(u, w), "attempted": false, "success": false, "damage": false, "hits": 0,
		"eligible": active and not XBattleLogic.is_item(skill) and (c.trigger as Array).has(int(skill.get("id", 0))) and int(skill.get("scope", 0)) == 1 and int(skill.get("damage", {}).get("type", 0)) == 1}


static func _cast_for(u, skill: Dictionary) -> Dictionary:
	if cast.is_empty() or nested > 0 or XSukuna.internal or cast.actor != u or not valid(u) or int(cast.skill) != int(skill.get("id", 0)):
		return {}
	return cast


## Game_Action.apply 包装：返回上一层的 hit，apply 结束时 apply_end 放回
static func apply_begin(u, skill: Dictionary, t) -> Dictionary:
	var prev := hit
	var c := _cast_for(u, skill)
	hit = {}
	if not c.is_empty():
		c.hits = int(c.hits) + 1
		hit = {"target": t, "boost": false, "increment": 0.0}
	return prev


static func apply_end(prev: Dictionary) -> void:
	hit = prev


## evalDamageFormula 包装
static func formula(logic, u, skill: Dictionary, t, value: float) -> float:
	var c := _cast_for(u, skill)
	if c.is_empty() or hit.is_empty() or hit.target != t or value <= 0.0:
		return value
	var cfg := config(u)
	if bool(c.awake) and (cfg.awake as Array).has(int(c.skill)):
		value *= 1.2
	var can_roll := true
	if int(u.actor_id) == XSukuna.ACTOR:
		can_roll = int(skill.get("id", 0)) == 10238 or XSukuna.part == "impact"
	if bool(c.eligible) and can_roll and not bool(c.attempted) and t is XEnemy and t.is_alive() and t == c.target:
		c.attempted = true
		c.candidate_hit = int(c.hits)
		var rate := float(c.probability) * (1.0 - clampf(float(t.cev), 0.0, 1.0))
		hit.boost = logic._float("black_flash") < rate
		if hit.boost:
			hit.increment = INCREMENT[mini(int(c.chain), 3)]
	return value


static func boosted(t) -> bool:
	return not hit.is_empty() and hit.target == t and bool(hit.boost)


## 伤害钩子（CodexDamage：黑闪那次暴伤加成 +increment）
static func damage_ops(b) -> Array:
	return [{"op": "add", "field": "criticalAdd", "value": float(hit.increment)}] if boosted(b) else []


## executeHpDamage 包装
static func after_hp(u, t, loss: float, skill: Dictionary) -> void:
	var c := _cast_for(u, skill)
	if c.is_empty() or hit.is_empty() or hit.target != t or not t is XEnemy or loss <= 0.0:
		return
	c.damage = true
	if bool(hit.boost) and not bool(c.success):
		c.success = true
		c.hp_loss = loss


## B.finish
static func finish(logic, u, skill) -> void:
	var c := cast
	cast = {}
	hit = {}
	if c.is_empty() or c.actor != u:
		return
	if not valid(u) or not skill is Dictionary or int(c.skill) != int(skill.get("id", 0)):
		clear(logic, u)
		return
	var t := temp(u)
	if bool(c.success):
		t.focus = 0
		t.chain = int(c.chain) + 1
		t.expires = round + 3
		var cfg := config(u)
		if u.skill_ids.has(int(cfg.awakening_skill)):
			logic._state_add(u, int(cfg.state))
		if int(u.actor_id) == XSukuna.ACTOR and XSukuna.knows(u, 10242):
			XSukuna.temp(u).emp = maxi(int(XSukuna.temp(u).emp), mini(int(t.chain), 4))  # onSuccess
	else:
		t.chain = 0
		if bool(c.eligible) and bool(c.damage):
			t.focus = mini(4, int(c.focus) + 1)


## B.endRound
static func end_round(logic) -> void:
	for a in logic.state.members():
		if config(a).is_empty():
			continue
		if not valid(a):
			clear(logic, a)
			continue
		if a.state_ids.has(int(config(a).state)) and round >= int(temp(a).expires):
			_drop_awake(logic, a)
	round += 1


## 不能行动（processTurn／OTB）、逃跑：连闪归 0
static func break_chain(a) -> void:
	if _temp.has(a):
		_temp[a].chain = 0


static func escape(logic) -> void:
	for a in logic.state.members():
		break_chain(a)


## Game_BattlerBase.die 包装（阵亡时状态已由 die 清掉，只清数据）
static func on_death(b) -> void:
	_temp.erase(b)
