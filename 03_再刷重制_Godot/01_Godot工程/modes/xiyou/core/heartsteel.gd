class_name XHeartsteel
extends RefCounted
## 【cc·八戒·未经审查】成长装备期一：心之钢 7900／杰作利维坦 7901（installNativeHeartsteelRuntime，冻结 v0.28 modules.json 第 15 个；
## 掉落在第 16 个 installNativeLeviathanForge 的 endBattle 包装里）。参照 heartsteel_probe（tests/fixtures/heartsteel_oracle.json），专项 xiyou_heartsteel。
## - 层数存在装备实例 _codexHeartsteelStacks（随存档；旧档没有这个字段按 0），旧版累计生命 _codexHeartsteelHp 平加最大生命（paramPlus 包装）。
## - 阶数 n＝⌊(√(1+8k/100)−1)/2⌋，第 n 阶要 50n(n+1) 层；最大生命 ×(利维坦 1.1、心钢 1)＋0.1n（param 包装：取整、夹上限）。
## - 技能：穿着时技能表里的巨人吞噬换成对应的一招（心钢 10227、利维坦 10228）；战斗外、蓄力没满（开战行动 2 次、施放后 3 次）、错配都不能用。
##   蓄力按行动计：带着它的人每次行动结束（不是巨人吞噬、活着、不是强制行动）减 1。
## - 巨人吞噬：施放时按常态最大生命定基础 ⌊(700／1000＋常态最大生命×6%／8%)×(1＋0.1n)⌋，公式值＝基础−min(max(0, 物防), 基础一半)；
##   一次行动只结算一次；命中且打前活着，按敌人权重（未知存在 10、首领／被封印者 5、其余 1；分身、召唤物、木桩等 0，1 号敌群 0）记本场待结算，胜利才加进层数。
## - 回合末（每个全局回合一次）出战且活着的回复最大生命 3%／5%。
## - 掉落：Map152 的不朽来源（来源地图 38，没记来源按变量 107＝1）敌群 454／455 胜利，10% 得心之钢，每场一次。
## 未做（期二／尾项）：利维坦锻造配方与解锁、智能 AI 与战力里的心钢分支、甚尔抑制行动（_tojiSuppressed）不减蓄力。

const ARMOR := 7900
const LEVIATHAN := 7901
const SKILL := 10227
const LEV_SKILL := 10228
const STACKS := "_codexHeartsteelStacks"
const LEGACY_HP := "_codexHeartsteelHp"
const REWARD_MAP := 152
const REWARD_ORIGIN := 38
const REWARD_TROOPS := [454, 455]
const REWARD_RATE := 0.10

## 战斗中的数据（原版存在角色、行动与 BattleManager 上，不随存档）
static var in_battle := false
static var _ledger: Array = []  # [{item, gain}] 本场待结算
static var _wait := {}  # 角色号 → 蓄力剩余行动数（没有＝2）
static var _casted := {}  # 角色号 → 施放过
static var _started := {}  # 角色号 → 本次行动开始时带着它（_codexHeartsteelStarted）
static var _cast := {}  # 角色号 → 本次巨人吞噬 {gear, valid, base, grown, applied}
static var _healed_turn = null
static var _reward_rolled := false


static func base_id(item) -> int:
	return int(item.get("base", item.get("id", 0))) if item is Dictionary and not item.is_empty() else 0

static func is_heart(item) -> bool:
	return base_id(item) == ARMOR

static func is_leviathan(item) -> bool:
	return base_id(item) == LEVIATHAN

static func is_gear(item) -> bool:
	return is_heart(item) or is_leviathan(item)

static func is_skill(skill) -> bool:
	return skill is Dictionary and int(skill.get("id", 0)) in [SKILL, LEV_SKILL]

static func skill_for(item) -> int:
	return LEV_SKILL if is_leviathan(item) else SKILL

## H.gear：角色第一件心钢／利维坦；没有为空字典
static func gear(a) -> Dictionary:
	if a is XActor:
		for e in a.equip_list():
			if is_gear(e):
				return e
	return {}

static func _count(item, field: String) -> int:
	return maxi(0, floori(float(item.get(field, 0)))) if item is Dictionary else 0

static func stacks(item) -> int:
	return _count(item, STACKS)

static func growth(item) -> int:
	return _count(item, LEGACY_HP)

static func stage_of(k: float) -> int:
	k = maxf(0.0, k)
	return maxi(0, floori((sqrt(1.0 + 8.0 * k / 100.0) - 1.0) / 2.0 + 1e-9))

static func stage_need(n: int) -> int:
	return 50 * n * (n + 1)

static func stage(item) -> int:
	return stage_of(stacks(item))

static func hp_rate(item) -> float:
	return (1.1 if is_leviathan(item) else 1.0) + 0.1 * stage(item)

static func cast_scale(a) -> float:
	var g := gear(a)
	return 1.0 + 0.1 * stage(g) if not g.is_empty() else 1.0

static func remaining(a) -> int:
	return maxi(0, int(_wait.get(a.actor_id, 2)))

static func pending(item) -> int:
	for r in _ledger:
		if is_same(r.item, item):
			return int(r.gain)
	return 0

static func _add_pending(item: Dictionary, gain: int) -> void:
	for r in _ledger:
		if is_same(r.item, item):
			r.gain = int(r.gain) + gain
			return
	_ledger.append({"item": item, "gain": gain})


## H.enemyWeight（狂妄同一张表，另看开场名单）
static func name_weight(e) -> int:
	var name := str(e.data().get("name", ""))
	if RegEx.create_from_string("分身|复制|召唤物|练习|训练|木桩").search(name) != null:
		return 0
	if name.contains("【未知存在】"):
		return 10
	return 5 if RegEx.create_from_string("【首领】|【被封印者】").search(name) != null else 1

static func enemy_weight(logic, e) -> int:
	if not (e is XEnemy) or not in_battle or logic == null or int(logic.troop_id) == 1:
		return 0
	return name_weight(e)


# ---- 角色包装 ----
## Game_Actor.paramPlus 包装：旧版累计生命
static func param_plus(a, i: int, v: float) -> float:
	return v + growth(gear(a)) if i == 0 else v

## Game_Actor.param 包装：阶数倍率乘自己的最大生命（不叠乘），取整、夹上限
static func param(a, i: int, v: float) -> float:
	if i != 0:
		return v
	var g := gear(a)
	if g.is_empty():
		return v
	var rate := hp_rate(g)
	return v if rate == 1.0 else roundf(minf(a.param_max(0), v * rate))

## Game_Actor.skills 包装：先拿掉两招，穿着时补上对应的一招
static func skill_ids(a, ids: Array[int]) -> Array[int]:
	var out: Array[int] = ids.filter(func(id): return not id in [SKILL, LEV_SKILL])
	var g := gear(a)
	if not g.is_empty():
		out.append(skill_for(g))
	return out

## Game_Actor.meetsSkillConditions 包装（假＝不能用）
static func meets(a, skill: Dictionary) -> bool:
	if not is_skill(skill):
		return true
	var g := gear(a)
	return not g.is_empty() and int(skill.id) == skill_for(g) and in_battle and remaining(a) == 0

## H.effectiveHp：常态最大生命（去掉生命强化与战斗结束会解除的状态，同一套能力值框架）
static func effective_hp(a) -> float:
	var buffed: bool = float(a.buffs[0]) != 0.0
	var temp := (a.state_ids as Array).filter(func(id): return bool(XDB.rec("States", int(id)).get("removeAtBattleEnd", false)))
	if not buffed and temp.is_empty():
		return maxf(0.0, a.mhp)
	var keep_buff = a.buffs[0]
	var keep_states: Array = (a.state_ids as Array).duplicate()
	a.buffs[0] = 0
	for id in temp:
		a.state_ids.erase(id)
	a.param_mark_dirty()
	var hp := maxf(0.0, a.mhp)
	a.buffs[0] = keep_buff
	a.state_ids.assign(keep_states)
	a.param_mark_dirty()
	return hp


# ---- 战斗包装 ----
## BattleManager.setup／startBattle 包装：清本场账，全队（含后备）蓄力 2
static func start_battle(logic) -> void:
	in_battle = true
	_ledger.clear()
	_cast.clear()
	_started.clear()
	_healed_turn = null
	_reward_rolled = false
	for a in logic.state.members():
		_wait[a.actor_id] = 2
		_casted[a.actor_id] = false

## BattleManager.startAction 包装：带着它的人开始行动；巨人吞噬记下这一次的施放（基础伤害按此刻常态最大生命），放得出就进冷却 3
static func start_action(u, skill: Dictionary) -> void:
	var g := gear(u)
	if g.is_empty() or _started.has(u.actor_id):
		return
	_started[u.actor_id] = true
	if not is_skill(skill):
		return
	var lev := is_leviathan(g)
	var valid: bool = int(skill.id) == skill_for(g) and remaining(u) == 0
	var base := floorf(((1000.0 if lev else 700.0) + effective_hp(u) * (0.08 if lev else 0.06)) * cast_scale(u))
	_cast[u.actor_id] = {"gear": g, "valid": valid, "base": base, "grown": false, "applied": false}
	if valid:
		_wait[u.actor_id] = 3
		_casted[u.actor_id] = true

## Game_Action.apply 包装：巨人吞噬没放成、或这次行动已结算过，整次 apply 不生效（真＝拦下）
static func blocks_apply(u, skill: Dictionary) -> bool:
	if not is_skill(skill):
		return false
	var cast = _cast.get(u.actor_id) if u is XActor else null
	if cast == null or not cast.valid or cast.applied:
		return true
	cast.applied = true
	return false

## Game_Action.apply 包装（原 apply 之后）：命中、打前活着，按权重记本场待结算（每次施放一次）
static func after_apply(logic, u, skill: Dictionary, t, hp_before: float, r: Dictionary) -> void:
	if not is_skill(skill) or not (u is XActor):
		return
	var cast = _cast.get(u.actor_id)
	if cast == null or cast.grown or hp_before <= 0.0 or bool(r.get("missed", false)) or bool(r.get("evaded", false)):
		return
	var w := enemy_weight(logic, t)
	if w > 0:
		cast.grown = true
		_add_pending(cast.gear, w)

## 公式 CodexHeartsteel.damage(a,b,this)
static func formula(a, b) -> float:
	var cast = _cast.get(a.actor_id) if a is XActor else null
	if cast == null or not cast.valid:
		return 0.0
	var base := float(cast.base)
	return base - minf(maxf(0.0, b.def), base * 0.5)

## BattleManager.endAction 包装：不是巨人吞噬的行动结束减 1 蓄力（强制行动不减）
static func end_action(u, forcing: bool) -> void:
	if not (u is XActor) or not _started.has(u.actor_id):
		return
	_started.erase(u.actor_id)
	var cast = _cast.get(u.actor_id)
	_cast.erase(u.actor_id)
	if cast == null and not gear(u).is_empty() and not u.is_dead() and not forcing:
		_wait[u.actor_id] = maxi(0, remaining(u) - 1)

## BattleManager.endTurn 包装（原 endTurn 之后）：每个全局回合一次，出战且活着的回复最大生命 3%／5%
static func end_turn(logic) -> void:
	if _healed_turn == logic.turn:
		return
	_healed_turn = logic.turn
	for a in logic.actors:
		var g := gear(a)
		if not g.is_empty() and not a.is_dead():
			logic.gain_hp(a, floorf(a.mhp * (0.05 if is_leviathan(g) else 0.03)))

## BattleManager.endBattle 包装：胜利把待结算层数加进装备；之后清本场数据
static func end_battle(result: int) -> void:
	var rows := _ledger.duplicate()
	_ledger.clear()
	if result == 0:
		for r in rows:
			r.item[STACKS] = stacks(r.item) + int(r.gain)
	in_battle = false
	_cast.clear()
	_started.clear()


## H.unknownHeartOrigin：记了来源地图用它，没记按变量 107（1＝不朽 38，否则 37）
static func unknown_origin(s: XState) -> int:
	if s.unknown_origin != null:
		return int(s.unknown_origin)
	return 38 if int(s.variables.get(107, 0)) == 1 else 37

## H.clearReward（Leviathan endBattle 包装，原 endBattle 之后）：不朽未知存在胜利，10% 得心之钢，每场一次
static func clear_reward(logic, result: int) -> bool:
	var s: XState = logic.state
	if result != 0 or s == null or s.map_id != REWARD_MAP or unknown_origin(s) != REWARD_ORIGIN or not int(logic.troop_id) in REWARD_TROOPS or _reward_rolled:
		return false
	_reward_rolled = true
	if logic._rule().next_float("heartsteel.reward") >= REWARD_RATE:
		return false
	s.gain_gear("armor", ARMOR, 1)
	return true
