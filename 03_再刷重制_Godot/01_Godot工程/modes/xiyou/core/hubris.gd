class_name XHubris
extends RefCounted
## 【cc·八戒·未经审查】成长装备期一：狂妄 7902／杰作无我 7903（installNativeHubrisRuntime，冻结 v0.28 modules.json 第 17 个）。
## 参照 heartsteel_probe（tests/fixtures/heartsteel_oracle.json），专项 xiyou_heartsteel。
## - 盛名存在装备实例 _codexHubrisFame（随存档；旧档没有按 0），阶数同心钢的平方根曲线；扬名倍率 (无我 1.2、狂妄 1.1)＋0.1×阶。
## - 物防穿透 18%／27%：物理且伤害类型 1／5 的公式里目标物防 ×(1−穿透)（evalDamageFormula 包装），伤害钩子 hubris 另把物防率 ×0.82／0.73。
## - 扬名：开场名单里的敌人（权重同心钢）被本方打倒时，2 次行动内打掉过它生命、此刻活着、还穿着同一件的狂妄者各得一次；
##   首领（权重 ≥5）每掉到新的一成生命，按新跨过的段数给打过它的人。每次得扬名：盛名待结算＋权重（或段数），物攻 ×倍率（倍率按已存＋待结算算），
##   持续 3／4 个完整回合（触发回合不计，刷新不叠加）；死亡、卸装、战斗结束清除；胜利才把待结算加进盛名。
## - 掉落：同心钢（Map152 不朽来源、敌群 454／455、胜利 10%、每场一次），在心钢掉落之后再掷。
## O-150 KILL_FIX：原版倒下状态在行动结束后才挂（YEP 延后），executeHpDamage 包装里 isDead() 还是假，击杀永远记不上，只有首领分段能触发；
##   默认按「生命打到 0 由本方打的」算击杀（参照 hubris.fix.*），设 false 回到原版（击杀不给扬名，参照 hubris.battle.*）。
## 未做（期二／尾项）：杰作无我锻造（配方 458、200 人道意志碎片＋5 锻造锤）与解锁、敌人复活（revive）重开贡献只在下一次受击时重置。

const ARMOR := 7902
const ATARAXIA := 7903
const FAME := "_codexHubrisFame"
const REWARD_RATE := 0.10

static var KILL_FIX := true

static var _running := false
static var _ledger: Array = []  # [{item, gain}]
static var _buff := {}  # 角色号 → {item, rate, round, remaining}
static var _moves := {}  # 角色号 → 本场有效行动数
static var _started := {}  # 角色号 → 本次行动已开始（_codexHubrisStarted）
static var _round = null
static var _original: Array = []  # 开场敌人（U._originalEnemies）
static var _excluded := {}  # 开场隐藏的敌人
static var _contrib := {}  # 敌人 → [{actor, item, moves}]
static var _counted := {}
static var _killed := {}
static var _seg := {}
static var _reward_rolled := false
## 公式帧（evalDamageFormula 包装）：目标与穿透
static var _logic: WeakRef = null  # 说明卡要当前回合与出战名单（不直接存战斗对象）
static var _frame_target = null
static var _frame_rate := 0.0


static func is_hubris(item) -> bool:
	return XHeartsteel.base_id(item) == ARMOR

static func is_ataraxia(item) -> bool:
	return XHeartsteel.base_id(item) == ATARAXIA

static func is_gear(item) -> bool:
	return is_hubris(item) or is_ataraxia(item)

static func gear(a) -> Dictionary:
	if a is XActor:
		for e in a.equip_list():
			if is_gear(e):
				return e
	return {}

static func growth(item) -> int:
	return maxi(0, floori(float(item.get(FAME, 0)))) if item is Dictionary else 0

static func rate_for(item, k: float) -> float:
	return (1.2 if is_ataraxia(item) else 1.1) + 0.1 * XHeartsteel.stage_of(k)

static func pending(item) -> int:
	for r in _ledger:
		if is_same(r.item, item):
			return int(r.gain)
	return 0

## 当前扬名（不显示用；数据或条件失效时顺手清掉，同 U.activeBonus）
static func buff(a) -> Variant:
	return _buff.get(a.actor_id) if active_bonus(a) > 0.0 else null

static func active_bonus(a) -> float:
	var b = _buff.get(a.actor_id)
	if b == null:
		return 0.0
	if not XHeartsteel.in_battle or a.is_dead() or not is_same(gear(a), b.item) or float(b.rate) == 0.0:
		_buff.erase(a.actor_id)
		return 0.0
	return float(b.rate)


## U.helpView 的「当前增益」：穿着这件、扬名还有效的出战者 {rate, remaining, same_round}；没有为 null
static func wearer_buff(item: Dictionary) -> Variant:
	var logic = _logic.get_ref() if _logic != null else null
	if logic == null or not XHeartsteel.in_battle:
		return null
	for a in logic.state.members():
		if is_same(gear(a), item) and active_bonus(a) > 0.0:
			var b: Dictionary = _buff[a.actor_id]
			return {"rate": b.rate, "remaining": b.remaining, "same_round": int(logic.turn) == int(b.round)}
	return null


# ---- 角色包装 ----
## Game_Actor.param 包装：扬名时物攻 ×倍率，取整、夹上限
static func param(a, i: int, v: float) -> float:
	if i != 2:
		return v
	var r := active_bonus(a)
	return roundf(minf(a.param_max(2), v * r)) if r > 0.0 else v

static func _physical(item: Dictionary) -> bool:
	return int(item.get("hitType", 0)) == 1 and int(item.get("damage", {}).get("type", 0)) in [1, 5]

static func _pierce(item: Dictionary, a) -> float:
	var g := gear(a)
	if g.is_empty() or not _physical(item):
		return 0.0
	return 0.27 if is_ataraxia(g) else 0.18

## evalDamageFormula 包装：公式求值期间目标物防 ×(1−穿透)
static func push_formula(item: Dictionary, a, b) -> void:
	var rate := _pierce(item, a)
	_frame_target = b if rate > 0.0 else null
	_frame_rate = rate

static func pop_formula() -> void:
	_frame_target = null
	_frame_rate = 0.0

## 目标的 param 在公式帧里读到的物防
static func formula_param(b, i: int, v: float) -> float:
	return v * (1.0 - _frame_rate) if i == 3 and _frame_target != null and is_same(b, _frame_target) else v

## 伤害钩子 hubris：物防率 ×0.82／0.73
static func damage_ops(item: Dictionary, a) -> Array:
	var rate := _pierce(item, a)
	return [{"op": "mul", "field": "physicalDefenseRate", "value": 1.0 - rate}] if rate > 0.0 else []


# ---- 战斗包装 ----
## BattleManager.setup＋startBattle 包装：开场名单、清本场数据，全队清扬名、行动数归 0
static func start_battle(logic) -> void:
	_logic = weakref(logic)
	_running = true
	_ledger.clear()
	_started.clear()
	_round = null
	_reward_rolled = false
	_original = (logic.enemies as Array).duplicate()
	_excluded.clear()
	_contrib.clear()
	_counted.clear()
	_killed.clear()
	_seg.clear()
	for e in _original:
		_excluded[e] = bool(e.hidden)
	for a in logic.state.members():
		_buff.erase(a.actor_id)
		_moves[a.actor_id] = 0

static func enemy_weight(logic, e) -> int:
	if not XHeartsteel.in_battle or logic == null or int(logic.troop_id) == 1 or not _original.has(e) or bool(_excluded.get(e, false)):
		return 0
	return XHeartsteel.name_weight(e)

static func _new_life(e) -> void:
	_counted.erase(e)
	_contrib.erase(e)
	_killed.erase(e)
	_seg.erase(e)

static func _note_damage(logic, u, t, before: float) -> void:
	var g := gear(u)
	if not _running or g.is_empty() or u.is_dead() or not (t is XEnemy) or before <= 0.0 or t.hp >= before or enemy_weight(logic, t) == 0:
		return
	var rows: Array = (_contrib.get(t, []) as Array).filter(func(r): return r.actor != u.actor_id)
	rows.append({"actor": u.actor_id, "item": g, "moves": int(_moves.get(u.actor_id, 0))})
	_contrib[t] = rows

## 2 次行动内打过、活着、还穿着同一件
static func _qualified(logic, e) -> Array:
	var out := []
	for r in _contrib.get(e, []):
		var a = logic.state.actor(int(r.actor))
		if a != null and not a.is_dead() and is_same(gear(a), r.item) and int(_moves.get(a.actor_id, 0)) - int(r.moves) <= 2:
			out.append([a, r.item])
	return out

static func _award(logic, a, item: Dictionary, gain: int) -> void:
	var row = null
	for r in _ledger:
		if is_same(r.item, item):
			row = r
	if row == null:
		row = {"item": item, "gain": 0}
		_ledger.append(row)
	row.gain = int(row.gain) + gain
	var k := growth(item) + int(row.gain)
	_buff[a.actor_id] = {"item": item, "rate": rate_for(item, k), "round": int(logic.turn), "remaining": 4 if is_ataraxia(item) else 3}
	a.param_mark_dirty()

## 首领分段：每新跨过一成生命算一次
static func _note_segments(logic, e) -> void:
	if not _running or e.is_dead() or e.hp <= 0.0 or enemy_weight(logic, e) < 5 or e.mhp <= 0.0:
		return
	var s := mini(9, floori((1.0 - e.hp / e.mhp) * 10.0 + 1e-9))
	var prev := int(_seg.get(e, 0))
	if s <= prev:
		return
	_seg[e] = s
	for p in _qualified(logic, e):
		_award(logic, p[0], p[1], s - prev)

## Game_Action.executeHpDamage 包装（原扣血之后）
static func after_hp(logic, u, t, value: float, before: float) -> void:
	if value <= 0.0 or not _running:
		return
	if t is XEnemy and _counted.has(t) and t.hp > 0.0 and not t.is_dead():
		_new_life(t)  # 复活的敌人重新算一条命（原版包在 revive／refresh 上）
	_note_damage(logic, u, t, before)
	if t is XEnemy and before > 0.0 and t.hp <= 0.0:
		if KILL_FIX:
			_killed[t] = u is XActor
	elif t is XEnemy and u is XActor:
		_note_segments(logic, t)

## U.settleDeaths：倒下的开场敌人各结算一次
static func settle_deaths(logic) -> void:
	if not _running:
		return
	for e in _original:
		if _counted.has(e) or (e.hp > 0.0 and not e.is_dead()):
			continue
		_counted[e] = true
		var w := enemy_weight(logic, e)
		if w == 0 or not bool(_killed.get(e, false)):
			continue
		for p in _qualified(logic, e):
			_award(logic, p[0], p[1], w)

static func start_action(u) -> void:
	if u is XActor:
		_started[u.actor_id] = true

## 甚尔封印让这次行动失效（_tojiSuppressed）：endAction 不计有效行动
static func suppressed(u) -> void:
	if u is XActor:
		_started.erase(u.actor_id)

## BattleManager.endAction 包装：先结算倒下的，再给有效行动计数（活着、不是强制行动）
static func end_action(logic, u, forcing: bool) -> void:
	settle_deaths(logic)
	if u is XActor and _started.has(u.actor_id):
		_started.erase(u.actor_id)
		if not u.is_dead() and not forcing:
			_moves[u.actor_id] = int(_moves.get(u.actor_id, 0)) + 1

## BattleManager.endTurn 包装（原 endTurn 之后）：每个全局回合一次，触发回合之后的回合扬名减 1
static func end_turn(logic) -> void:
	settle_deaths(logic)
	var turn := int(logic.turn)
	if _round == turn:
		return
	_round = turn
	for a in logic.state.members():
		var b = _buff.get(a.actor_id)
		if b != null and turn > int(b.round):
			b.remaining = int(b.remaining) - 1
			if int(b.remaining) <= 0:
				_buff.erase(a.actor_id)
				a.param_mark_dirty()

## BattleManager.endBattle 包装：胜利存盛名，清扬名与本场数据
static func end_battle(logic, result: int) -> void:
	settle_deaths(logic)
	if result == 0:
		for r in _ledger:
			r.item[FAME] = growth(r.item) + int(r.gain)
	_running = false
	_ledger.clear()
	_started.clear()
	for a in logic.state.members():
		if _buff.has(a.actor_id):
			_buff.erase(a.actor_id)
			a.param_mark_dirty()

## U.clearReward（原 endBattle 之后，心钢掉落之后）
static func clear_reward(logic, result: int) -> bool:
	var s: XState = logic.state
	if result != 0 or s == null or s.map_id != XHeartsteel.REWARD_MAP or XHeartsteel.unknown_origin(s) != XHeartsteel.REWARD_ORIGIN \
			or not int(logic.troop_id) in XHeartsteel.REWARD_TROOPS or _reward_rolled:
		return false
	_reward_rolled = true
	if logic._rule().next_float("hubris.reward") >= REWARD_RATE:
		return false
	s.gain_gear("armor", ARMOR, 1)
	XToast.show_text("获得神武：狂妄！")
	return true
