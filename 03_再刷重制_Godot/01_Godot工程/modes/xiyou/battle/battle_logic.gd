class_name XBattleLogic
extends RefCounted
## 战斗规则（不含画面）：MV 回合制——全员选好行动后按速度排序依次执行。
## 伤害交给 XDamage（与正式版对照过），这里负责命中/闪避/会心、技能消耗、效果、状态回合、敌人 AI、奖励。
## 每次行动返回一组记录（log），画面层按记录播放；无界面测试也直接用这些记录。
## 另含：技能冷却/预热（YEP_X_SkillCooldowns）、战斗中用物品、反击/魔法反射（MV invokeAction）、神话敌人（XEnemy）。
## 行动顺序按 Olivia_BattleSysOTB（见「回合」一节）。

const DEATH_STATE := 1
const GUARD_SKILL := 2
const ATTACK_SKILL := 1

var troop_id := 0
var actors: Array = []          # XActor（出战）
var enemies: Array = []         # XEnemy
var turn := 0
var can_escape := true
var escaped := false
var auto := false
var state: XState
## 测试用：>= 0 时固定神话判定（0 必为神话，100 必不是）
var elite_roll := -1.0


const TRAIT_SPECIAL_FLAG := 62
const FLAG_PRESERVE_TP := 3

func setup(troop: int, s: XState) -> void:
	turn = 0
	escaped = false
	current_order.clear()
	next_order.clear()
	_acted.clear()
	_speed.clear()
	_orders_made = false
	state = s
	troop_id = troop
	actors = s.battle_members()
	enemies.clear()
	var letters := {}
	var t := XDB.rec("Troops", troop)
	for m in t.get("members", []):
		if bool(m.get("hidden", false)):
			continue
		var e := XEnemy.new().setup(int(m.enemyId), s.difficulty, elite_roll)
		e.set_meta("x", float(m.x))
		e.set_meta("y", float(m.y))
		enemies.append(e)
		letters[e.enemy_id] = letters.get(e.enemy_id, 0) + 1
	# 同名敌人加 Ａ Ｂ Ｃ（MV makeUniqueNames）
	var seen := {}
	for e in enemies:
		if letters[e.enemy_id] > 1:
			e.letter = "ＡＢＣＤＥＦＧＨＩＪ"[seen.get(e.enemy_id, 0)]
			seen[e.enemy_id] = seen.get(e.enemy_id, 0) + 1
	for a in actors:
		for sid in a.state_ids.duplicate():
			if not bool(XDB.rec("States", sid).get("removeAtBattleEnd", false)):
				continue
			a.remove_state(sid)
	_battle_start_states()
	# MV Game_Battler.onBattleStart：没有「保留 TP」（特殊旗标 3）时 TP 随机 0～24
	for b in actors + enemies:
		if not b.traits_set(TRAIT_SPECIAL_FLAG).has(FLAG_PRESERVE_TP):
			b.tp = float(randi() % 25)
	for b in actors + enemies:
		b.start_warmups()
	_escape_ratio = 0.5 * _avg_agi(actors) / maxf(_avg_agi(enemies), 1.0)


## dsPassiveSkill Scene_Battle.start：每个出战角色依次处理开战状态标签——自己、随机队友、随机敌人、随机任一目标、
## 全体敌人、全队；之后刷新所有角色的被动缓存。
func _battle_start_states() -> void:
	for a in actors:
		for tag in a.battle_start_state_tags():
			if randf() * 100.0 >= float(tag[2]):
				continue
			var sid := int(tag[1])
			match str(tag[0]):
				"StartPushState":
					a.add_state(sid)
				"StartRomActPushState":
					var others := actors.filter(func(x): return x != a)
					if not others.is_empty():
						others[randi() % others.size()].add_state(sid)
				"StartRomEmePushState":
					var foes := alive(enemies)
					if not foes.is_empty():
						foes[randi() % foes.size()].add_state(sid)
				"StartRomPushState":
					var all: Array = actors + alive(enemies)
					all[randi() % all.size()].add_state(sid)
				"StartAEPushState":
					for e in alive(enemies):
						e.add_state(sid)
				"StartWTPushState":
					for x in actors:
						x.add_state(sid)
	for a in actors:
		a.refresh_passive()
	for e in enemies:
		e.refresh_passive()


func alive(list: Array) -> Array:
	return list.filter(func(b): return b.is_alive())

func is_won() -> bool:
	return alive(enemies).is_empty()

func is_lost() -> bool:
	return alive(actors).is_empty()

func vars() -> Array:
	return state.variable_array()


# ---- 技能可用 ----
static func is_item(rec: Dictionary) -> bool:
	return rec.has("itypeId")

func skill_cost(a: XBattler, skill: Dictionary) -> Dictionary:
	if is_item(skill):
		return {"mp": 0, "tp": 0}
	return {"mp": floori(float(skill.get("mpCost", 0)) * a.mcr), "tp": int(skill.get("tpCost", 0))}

func can_use(a: XBattler, skill: Dictionary) -> bool:
	if skill.is_empty():
		return false
	var occ := int(skill.get("occasion", 0))
	if occ != 0 and occ != 1:
		return false
	if is_item(skill):
		return a.is_actor() and state.items.get(int(skill.id), 0) > 0
	if a.cooldown_left(int(skill.id)) > 0:
		return false
	if a.is_actor() and int(skill.stypeId) > 0:
		if not a.traits_set(XBattler.TRAIT_STYPE_ADD).has(int(skill.stypeId)) or a.traits_set(XBattler.TRAIT_STYPE_SEAL).has(int(skill.stypeId)):
			return false
	if a.traits_set(XBattler.TRAIT_SKILL_SEAL).has(int(skill.id)):
		return false
	var c := skill_cost(a, skill)
	return a.mp >= c.mp and a.tp >= c.tp

## 角色的可用主动技能（隐藏的被动不列出）
func usable_skills(a: XActor) -> Array:
	return battle_skills(a).filter(func(s): return can_use(a, s))

## 技能列表里显示的全部主动技能（含冷却中/魔法不足的，画面上显示为灰色）
func battle_skills(a: XActor) -> Array:
	var out := []
	for s in a.skills():
		if int(s.id) > GUARD_SKILL and int(s.stypeId) != 4 and not s.get("meta", {}).has("Hide in Battle"):
			out.append(s)
	return out

## 战斗中可用的物品（MV Window_BattleItem：场合为「总是」或「战斗中」且持有）
func battle_items() -> Array:
	var out := []
	for id in state.items.keys():
		var rec := XDB.rec("Items", int(id))
		if not rec.is_empty() and int(state.items[id]) > 0 and [0, 1].has(int(rec.get("occasion", 3))):
			out.append(rec)
	out.sort_custom(func(x, y): return int(x.id) < int(y.id))
	return out


# ---- 目标 ----
func targets_for(a: XBattler, skill: Dictionary, chosen: XBattler = null) -> Array:
	var foes := enemies if a.is_actor() else actors
	var friends := actors if a.is_actor() else enemies
	var scope := int(skill.get("scope", 1))
	match scope:
		1:
			if chosen and chosen.is_alive() and foes.has(chosen):
				return [chosen]
			return [_random_target(alive(foes))] if not alive(foes).is_empty() else []
		2:
			return alive(foes)
		3, 4, 5, 6:
			var out := []
			for i in range(scope - 2):
				if not alive(foes).is_empty():
					out.append(_random_target(alive(foes)))
			return out
		7:
			if chosen and chosen.is_alive() and friends.has(chosen):
				return [chosen]
			var low := alive(friends)
			low.sort_custom(func(x, y): return x.hp_rate() < y.hp_rate())
			return low.slice(0, 1)
		8:
			return alive(friends)
		9:
			if chosen and chosen.is_dead() and friends.has(chosen):
				return [chosen]
			return friends.filter(func(b): return b.is_dead()).slice(0, 1)
		10:
			return friends.filter(func(b): return b.is_dead())
		11:
			return [a]
	return []

## MV：按目标的 tgr（受击率）加权随机
func _random_target(list: Array) -> XBattler:
	var total := 0.0
	for b in list:
		total += b.tgr
	var r := randf() * total
	for b in list:
		r -= b.tgr
		if r <= 0.0:
			return b
	return list[0]


# ---- 敌人 AI（MV Game_Enemy.selectAllActions）----
func enemy_action(e: XEnemy) -> Dictionary:
	var list: Array = e.data().get("actions", []).filter(func(act): return _meets(e, act) and can_use(e, XDB.rec("Skills", int(act.skillId))))
	if list.is_empty():
		return XDB.rec("Skills", ATTACK_SKILL)
	var rmax := 0
	for act in list:
		rmax = maxi(rmax, int(act.rating))
	var zero := rmax - 3
	list = list.filter(func(act): return int(act.rating) > zero)
	var sum := 0
	for act in list:
		sum += int(act.rating) - zero
	var r := randi_range(0, sum - 1)
	for act in list:
		r -= int(act.rating) - zero
		if r < 0:
			return XDB.rec("Skills", int(act.skillId))
	return XDB.rec("Skills", int(list[0].skillId))

func _meets(e: XEnemy, act: Dictionary) -> bool:
	var p1 := float(act.conditionParam1)
	var p2 := float(act.conditionParam2)
	match int(act.conditionType):
		1:
			var n := turn
			return n == int(p1) if p2 == 0 else (n > 0 and n >= p1 and int(n - p1) % int(p2) == 0)
		2:
			return e.hp_rate() >= p1 and e.hp_rate() <= p2
		3:
			return e.mp / maxf(e.mmp, 1.0) >= p1 and e.mp / maxf(e.mmp, 1.0) <= p2
		4:
			return e.is_state_affected(int(p1))
		5:
			return actors.any(func(a): return a.level >= p1)
		6:
			return state.switch(int(p1))
	return true


## 自动战斗（挂机或自动按钮）一次行动，照正式版 Game_Actor.makeAction 链：
## 智能AI开着（默认）——技能顺序表排了且能用就照表（XdRs_HangUp makeAction），否则 XSmartAI 选；没有可选的退回普通攻击。
## 智能AI关着——照表，否则普通攻击（XdRs_HangUp 的 makeAction 不再走 MV 原生评估）。
func auto_battle_action(a: XActor) -> Array:
	var planned := XHangUpAuto.scheduled_skill(state, self, a, turn)
	if not planned.is_empty():
		return [planned, null]
	if XConfig.smart_ai():
		var r := XSmartAI.choose(self, a)
		if r.has("skill"):
			return [r.skill, r.target]
	return [XDB.rec("Skills", ATTACK_SKILL), null]



# ---- 回合（Olivia_BattleSysOTB：行动顺序回合制）----
## 正式版强制使用 OTB（Force Battle System = true）。与 MV 默认回合制不同：
## - 不再「全员先选指令再统一执行」，而是按行动顺序轮到谁、谁当场选指令并立即行动。
## - 每回合开始时同时排好「当前回合」和「下个回合」两条顺序；下一回合直接沿用已排好的顺序。
##   速度 = 敏捷 + 随机(0 ~ 5+敏捷/4 - 1)（Static AGI Calculation = false）；不能行动者速度为无穷大（醒来后排最前）。
## - 技能速度不再参与排序，而是使用后把自己在下个回合的位置前移「速度」格（Action Speed Convert）：
##   攻击速度 -1 → 后移 1 格；防御速度 2000 → 移到最前。物品不移位（只有技能付费时触发）。
## - 增加敏捷增益的技能命中后，目标下个回合前移 1 格（Buff/Debuff AGI Convert；正式版减益判断写错，不移位，照搬）。
## - 追加行动（特性 61）：同一人在顺序中连续出现多次；正式版改为每回合最多 5 次（文件末尾的修复段）。
## - 无法行动（死亡、行动限制）的人从当前回合移除；下个回合若一回合后仍不能动也移除；恢复行动时补回顺序末尾。
## 未移植：正式版超过上限的追加行动换算成永久伤害加成（_actionDMG，只累加不清零），见 数值平衡.md。

const OTB_MAX_ACTIONS := 5
const AGI_PARAM := 6

var current_order: Array = []   # 本回合尚未行动的顺序（XBattler，可重复）
var next_order: Array = []      # 下个回合的顺序
var _orders_made := false
var _acted := {}                # XBattler -> 本回合已行动次数（_otbTimesActedThisTurn）
var _speed := {}                # XBattler -> 最近一次排序时的速度
var _escape_ratio := -1.0


## 回合开始（YEP startTurn）：回合数 +1、冷却 -1、排顺序。
func start_turn() -> void:
	turn += 1
	# YEP_X_SkillCooldowns：Game_Troop.increaseTurn 时双方冷却/预热各减 1
	for b in actors + enemies:
		b.update_cooldowns()
	_make_action_orders()


## 取出下一位行动者；本回合结束时返回 null。
func next_subject() -> XBattler:
	while not current_order.is_empty():
		var b: XBattler = current_order.pop_front()
		if b.is_alive() and (actors.has(b) or enemies.has(b)):
			return b
	return null


## 行动者当场决定的行动：敌人按 AI，角色在自动战斗时按自动规则，否则普通攻击。返回 [技能, 目标]。
func decide(b: XBattler) -> Array:
	if b is XEnemy:
		return [enemy_action(b), null]
	return auto_battle_action(b) if auto else [XDB.rec("Skills", ATTACK_SKILL), null]


## 执行一位行动者的一次行动，返回记录。skill 为 null 表示放弃本次行动（逃跑失败）。
func act(u: XBattler, skill, target) -> Array:
	var logs := []
	var before := _movable_snapshot()
	if is_won() or is_lost() or u.is_dead():
		return logs
	if not can_move(u):
		logs.append({"type": "skip", "user": u})
	elif skill == null:
		pass
	elif int(skill.id) == GUARD_SKILL and not is_item(skill):
		u.guarding = true
		_otb_user_shift(u, skill)
		logs.append({"type": "guard", "user": u})
	else:
		logs.append_array(execute(u, skill, target))
	_acted[u] = int(_acted.get(u, 0)) + 1
	_tick_states(u, 1)
	_sync_orders(before, true)
	return logs


## 回合结束（MV onTurnEnd）：解除防御、再生、状态回合 -1；恢复行动的人只补进下个回合。
func end_turn() -> Array:
	var logs := []
	var before := _movable_snapshot()
	_acted.clear()
	for b in actors + enemies:
		b.guarding = false
		if b.is_alive():
			_tick_states(b, 2)
			_regenerate(b, logs)
	_sync_orders(before, false)
	return logs


## 无界面测试用：跑完一整个回合。commands: actor -> [技能, 目标]（[null, null] 表示放弃）。
func run_turn(commands: Dictionary) -> Array:
	start_turn()
	var logs := []
	while true:
		var u := next_subject()
		if u == null or is_won() or is_lost():
			break
		var cmd: Array = commands.get(u, decide(u)) if u is XActor else decide(u)
		logs.append_array(act(u, cmd[0], cmd[1]))
	if not is_won() and not is_lost():
		logs.append_array(end_turn())
	return logs


func can_move(b: XBattler) -> bool:
	return b.is_alive() and not _restricted(b)

func _restricted(b: XBattler) -> bool:
	for s in b.states():
		if int(s.restriction) >= 4:
			return true
	return false


## OTB makeActionOrdersOTB：当前回合 = 上回合排好的「下个回合」；再排新的「下个回合」。
## 首回合另排一次当前回合（速度重新随机）。排序稳定，同速时我方在前（JS sort 稳定）。
func _make_action_orders() -> void:
	if _orders_made:
		current_order = next_order
	next_order = _sorted_by_speed(alive(actors) + alive(enemies))
	if not _orders_made:
		current_order = _sorted_by_speed(actors + enemies)
		_action_times_modification(current_order)
	_clear_unable()
	_action_times_modification(next_order)
	_orders_made = true


func _sorted_by_speed(list: Array) -> Array:
	var keyed := []
	for i in range(list.size()):
		var b: XBattler = list[i]
		var sp := INF
		if can_move(b):
			var a := b.agi
			sp = a + randi_range(0, maxi(floori(5 + a / 4.0), 1) - 1)
		_speed[b] = sp
		keyed.append([sp, i, b])
	keyed.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and x[1] < y[1]))
	return keyed.map(func(k): return k[2])


## 追加行动：按 MV makeActionTimes 掷骰，在此人第一次出现的位置连续插入；每回合总数不超过 5。
func _action_times_modification(order: Array) -> void:
	for b in actors + enemies:
		if not order.has(b):
			continue
		var existing := order.count(b)
		var max_extra := OTB_MAX_ACTIONS - existing
		if max_extra <= 0:
			continue
		var n := mini(make_action_times(b) - 1, max_extra)
		var at := order.find(b)
		for i in range(n):
			order.insert(at, b)


## MV makeActionTimes：每个「追加行动」特性按几率各加 1 次。
func make_action_times(b: XBattler) -> int:
	var n := 1
	for t in b.all_traits():
		if int(t.code) == 61 and int(t.dataId) == 0 and randf() < float(t.value):
			n += 1
	return n


## otbClearActionOrdersOfUnableBattlers
func _clear_unable() -> void:
	var members := actors + enemies
	current_order = current_order.filter(func(b): return members.has(b) and can_move(b))
	next_order = next_order.filter(func(b): return members.has(b) and b.is_alive() and (can_move(b) or _movable_after_turn_end(b)))


## 下个回合是否能动：模拟一次回合结束的状态回合递减（YEP updateStateTurns 会移除到期的回合结束型状态）。
func _movable_after_turn_end(b: XBattler) -> bool:
	if b.is_dead():
		return false
	for id in b.state_ids:
		var st := XDB.rec("States", id)
		if int(st.get("restriction", 0)) < 4:
			continue
		if int(st.get("autoRemovalTiming", 0)) == 2 and int(b.state_turns.get(id, 1)) <= 1:
			continue
		return false
	return true


func _movable_snapshot() -> Dictionary:
	var out := {}
	for b in actors + enemies:
		out[b] = can_move(b)
	return out


## 行动/回合结束后：刚失去行动能力的移出顺序；刚恢复的补回（otbInsertRevivalActionOrders）。
## 回合结束时只补下个回合（正式版 onTurnEnd 临时关闭 Current Turn Wakeup）。
func _sync_orders(before: Dictionary, allow_current: bool) -> void:
	var lost := false
	for b in before:
		var now := can_move(b)
		if before[b] and not now:
			lost = true
		elif not before[b] and now:
			if allow_current and mini(make_action_times(b), OTB_MAX_ACTIONS) > int(_acted.get(b, 0)):
				_insert_orders(b, current_order)
			_insert_orders(b, next_order)
	if lost:
		_clear_unable()


func _insert_orders(b: XBattler, order: Array) -> void:
	if order.has(b):
		return
	var times := maxi(mini(make_action_times(b), OTB_MAX_ACTIONS) - int(_acted.get(b, 0)), 1)
	for i in range(times):
		order.append(b)


## otbNextTurnChange：把 b 在顺序中的每个位置前移 change 格（负数后移），不越过速度无穷大的人。
func _shift(b: XBattler, change: int, current: bool) -> void:
	var order := current_order if current else next_order
	var idx := []
	for i in range(order.size()):
		if order[i] == b:
			idx.append(i)
	if idx.is_empty():
		return
	for i in range(idx.size() - 1, -1, -1):
		order.remove_at(idx[i])
	var minimum := order.size()
	for i in range(order.size()):
		if _speed.get(order[i], 0.0) != INF:
			minimum = i
			break
	for i in idx:
		order.insert(clampi(i - change, minimum, order.size()), b)


## 技能付费时：下个回合位置按技能速度前移（Action Speed Convert）。
func _otb_user_shift(u: XBattler, skill: Dictionary) -> void:
	var change := int(skill.get("speed", 0)) + _note_int(skill, "OTB User Next Turn")
	if change != 0:
		_shift(u, change, false)


## 命中后对目标：OTB Target Current/Next/Follow Turn 备注，及敏捷增益换算的「下个回合 +1」。
func _otb_target_shift(skill: Dictionary, t: XBattler) -> void:
	var cur := _note_int(skill, "OTB Target Current Turn")
	var nxt := _note_int(skill, "OTB Target Next Turn")
	var follow := _note_int(skill, "OTB Target Follow Turn")
	if follow != 0:
		if current_order.has(t):
			cur += follow
		else:
			nxt += follow
	if not str(skill.get("note", "")).contains("<OTB Target Next Turn:"):
		for eff in skill.get("effects", []):
			if int(eff.code) == 31 and int(eff.dataId) == AGI_PARAM:
				nxt += 1
				break
	if cur != 0:
		_shift(t, cur, true)
	if nxt != 0:
		_shift(t, nxt, false)


static func _note_int(rec: Dictionary, tag: String) -> int:
	var m := RegEx.create_from_string("(?i)<" + tag + ":\\s*([+-]\\d+)>").search(str(rec.get("note", "")))
	return int(m.get_string(1)) if m else 0


## 执行一次行动：消耗、目标、连击、命中、伤害、效果。
func execute(u: XBattler, skill: Dictionary, chosen: XBattler) -> Array:
	var logs := []
	if not can_use(u, skill):
		skill = XDB.rec("Skills", ATTACK_SKILL)
	if is_item(skill):
		if bool(skill.get("consumable", true)):
			state.gain_item(int(skill.id), -1)
	else:
		var c := skill_cost(u, skill)
		u.mp -= c.mp
		u.tp -= c.tp
		u.pay_cooldown(skill)
		_otb_user_shift(u, skill)
	logs.append({"type": "action", "user": u, "skill": skill})
	var repeats := int(skill.get("repeats", 1))
	if not is_item(skill) and int(skill.id) == ATTACK_SKILL:
		repeats += int(u.traits_sum_all(XBattler.TRAIT_ATTACK_TIMES))
	for t in targets_for(u, skill, chosen):
		for i in range(maxi(1, repeats)):
			if t.is_dead() and not [9, 10].has(int(skill.scope)):
				break
			if u.is_dead():
				break
			logs.append_array(_invoke(u, skill, t))
	return logs


## YEP_BattleEngineCore 的 invokeAction：先判魔法反射（魔法、几率 mrf），再判反击（物理、目标能行动、几率 cnt），否则正常生效。
## 反射：行动作用到行动者自己。反击：目标对行动者普通攻击，原行动对该目标无效。
## dsPassiveSkill 必中（角色的 SkillCertainHit 被动）时不会被反射/反击。MV 不区分敌我。
func _invoke(u: XBattler, skill: Dictionary, t: XBattler) -> Array:
	var sure := certain_hit(u, skill)
	var mrf := t.mrf if XDamage.is_magical(skill) and not sure else 0.0
	if randf() < mrf:
		var r := apply(u, skill, u)
		r.reflected = true
		return [{"type": "reflect", "user": u, "target": t}, r]
	var cnt := t.cnt if XDamage.is_physical(skill) and t.is_alive() and not _restricted(t) and not sure else 0.0
	if randf() < cnt:
		var r := apply(t, XDB.rec("Skills", ATTACK_SKILL), u)
		r.counter = true
		return [{"type": "counter", "user": t, "target": u}, r]
	return [apply(u, skill, t)]


static func certain_hit(u: XBattler, skill: Dictionary) -> bool:
	if not u.is_actor():
		return false
	var ch: Dictionary = u.passive_cache().get("certainHit", {})
	return bool(ch.get("global", false)) or ch.get("bySkill", {}).has(int(skill.id))


## Game_Action.itemHit 正式版链：dsPassiveSkill 必中被动 → 1；否则 YEP_HitAccuracy 的命中公式
##（参数「Accuracy Formula」，西游为 skillHitRate * (userHitRate - targetEvadeRate) * 1.2；
## userHitRate 物理 user.hit、魔法 user.hit*1.1、必中 10000000；targetEvadeRate 物理 target.eva、魔法 target.mev、必中 0）；
## 最后 installDamageElementRuntime 夹到 0～1。Olivia_AntiPlayerStress 的命中修正在西游关闭（Hit Rate Stacking=false）。
func item_hit(u: XBattler, skill: Dictionary, t: XBattler) -> float:
	if certain_hit(u, skill):
		return 1.0
	return clampf(_hit_formula("Accuracy Formula", "skillHitRate * (userHitRate - targetEvadeRate)", u, skill, t), 0.0, 1.0)


## itemEva：YEP「Evade Formula」（西游为 0）夹到 0～1。原版闪避已并入命中公式。
func item_eva(u: XBattler, skill: Dictionary, t: XBattler) -> float:
	return clampf(_hit_formula("Evade Formula", "0", u, skill, t), 0.0, 1.0)


static var _hit_exprs := {}

func _hit_formula(key: String, fallback: String, u: XBattler, skill: Dictionary, t: XBattler) -> float:
	var p := XDB.plugin("YEP_HitAccuracy")
	var kind := "Physical" if XDamage.is_physical(skill) else "Magical" if XDamage.is_magical(skill) else "Certain"
	var user_rate := _eval_hit(str(p.get("User %s Hit" % kind, "user.hit")), u, t, {})
	var target_rate := _eval_hit(str(p.get("Target %s Evade" % kind, "0")), u, t, {})
	return _eval_hit(str(p.get(key, fallback)), u, t, {"skillHitRate": float(skill.get("successRate", 100)) * 0.01,
		"userHitRate": user_rate, "targetEvadeRate": target_rate})


func _eval_hit(code: String, u: XBattler, t: XBattler, extra: Dictionary) -> float:
	var names := ["user", "target", "a", "b", "subject"] + extra.keys()
	var key := code + "|" + ",".join(names)
	if not _hit_exprs.has(key):
		var e := Expression.new()
		_hit_exprs[key] = e if e.parse(code, names) == OK else null
	var expr: Expression = _hit_exprs[key]
	if expr == null:
		return 0.0
	var v = expr.execute([u, t, u, t, u] + extra.values(), null, false)
	return float(v) if not expr.has_execute_failed() and (v is float or v is int) else 0.0


func apply(u: XBattler, skill: Dictionary, t: XBattler) -> Dictionary:
	var r := {"type": "hit", "user": u, "target": t, "skill": skill, "missed": false, "evaded": false, "critical": false,
		"hp": 0.0, "mp": 0.0, "added": [], "removed": [], "died": false}
	var dmg: Dictionary = skill.damage
	var physical := XDamage.is_physical(skill)
	var magical := XDamage.is_magical(skill)
	var hit_rate := item_hit(u, skill, t)
	var eva_rate := item_eva(u, skill, t)
	if randf() >= clampf(hit_rate, 0.0, 1.0):
		r.missed = true
		return r
	if randf() < clampf(eva_rate, 0.0, 1.0):
		r.evaded = true
		return r
	var type := int(dmg.type)
	if type > 0:
		var cri := u.cri * (1.0 - t.cev) if bool(dmg.critical) else 0.0
		r.critical = randf() < clampf(cri, 0.0, 1.0)
		var res := XDamage.calculate(skill, u, t, {"critical": r.critical, "vars": vars()})
		var value := XDamage.apply_state_effects(res.value, skill, u, t)
		match type:
			1, 3:
				r.hp = value
				t.hp = clampf(t.hp - value, 0.0, t.mhp)
			2, 4:
				r.mp = value
				t.mp = clampf(t.mp - value, 0.0, t.mmp)
			5:
				r.hp = minf(value, t.hp)
				t.hp -= r.hp
				u.hp = minf(u.mhp, u.hp + r.hp)
			6:
				r.mp = minf(value, t.mp)
				t.mp -= r.mp
				u.mp = minf(u.mmp, u.mp + r.mp)
		if value > 0.0 and [1, 5].has(type):
			t.tp = minf(100.0, t.tp + floorf(50.0 * value / maxf(t.mhp, 1.0) * t.tcr))
	for eff in skill.get("effects", []):
		_effect(u, t, eff, r)
	_otb_target_shift(skill, t)
	u.tp = minf(100.0, u.tp + float(skill.get("tpGain", 0)) * u.tcr)
	if t.hp <= 0.0 and t.is_dead():
		_die(t)
		r.died = true
	return r


func _effect(u: XBattler, t: XBattler, eff: Dictionary, r: Dictionary) -> void:
	var v1 := float(eff.value1)
	var v2 := float(eff.value2)
	match int(eff.code):
		11:
			var v := (t.mhp * v1 + v2) * t.rec * (u.pha if is_item(r.skill) else 1.0)
			v = floorf(v)
			t.hp = clampf(t.hp + v, 0.0, t.mhp)
			# MV gainHp → refresh：负值恢复也要同步阵亡状态。
			if t.hp <= 0:
				t.add_state(DEATH_STATE)
			else:
				t.remove_state(DEATH_STATE)
			r.hp -= v
		12:
			var v := (t.mmp * v1 + v2) * t.rec * (u.pha if is_item(r.skill) else 1.0)
			v = floorf(v)
			t.mp = clampf(t.mp + v, 0.0, t.mmp)
			r.mp -= v
		13:
			t.tp = clampf(t.tp + floorf(v1), 0.0, 100.0)
		21:
			var sid := int(eff.dataId)
			var ids := u.traits_set(XBattler.TRAIT_ATTACK_STATE) if sid == 0 else [sid]
			for id in ids:
				var chance := v1 * state_rate(t, id) * maxf(1.0 + (u.luk - t.luk) * 0.001, 0.0)
				if t.traits_set(XBattler.TRAIT_STATE_RESIST).has(id):
					chance = 0.0
				if randf() < chance:
					if id == DEATH_STATE:
						t.hp = 0.0
					else:
						t.add_state(id)
						r.added.append(id)
		22:
			if randf() < v1:
				t.remove_state(int(eff.dataId))
				r.removed.append(int(eff.dataId))
		31:
			t.buffs[int(eff.dataId)] = mini(2, t.buffs[int(eff.dataId)] + 1)
			t.buff_turns[int(eff.dataId)] = int(v1)
		32:
			t.buffs[int(eff.dataId)] = maxi(-2, t.buffs[int(eff.dataId)] - 1)
			t.buff_turns[int(eff.dataId)] = int(v1)
		33, 34:
			var id := int(eff.dataId)
			if (int(eff.code) == 33 and t.buffs[id] > 0) or (int(eff.code) == 34 and t.buffs[id] < 0):
				t.buffs[id] = 0
				t.buff_turns[id] = 0
		43:
			if t is XActor:
				t.learn_skill(int(eff.dataId))
				t.refresh_passive()


func state_rate(b: XBattler, id: int) -> float:
	return b.traits_pi(XBattler.TRAIT_STATE_RATE, id)


func _die(b: XBattler) -> void:
	b.hp = 0.0
	b.state_ids.clear()
	b.state_turns.clear()
	b.state_ids.append(DEATH_STATE)
	for i in range(8):
		b.buffs[i] = 0
		b.buff_turns[i] = 0
	b.mp = minf(b.mp, b.mmp)


## timing 1 = 行动结束，2 = 回合结束（MV autoRemovalTiming）
func _tick_states(b: XBattler, timing: int) -> void:
	for id in b.state_ids.duplicate():
		var s := XDB.rec("States", id)
		if int(s.get("autoRemovalTiming", 0)) != timing or id == DEATH_STATE:
			continue
		b.state_turns[id] = int(b.state_turns.get(id, 1)) - 1
		if b.state_turns[id] <= 0:
			b.remove_state(id)
	if timing == 2:
		for i in range(8):
			if b.buff_turns[i] > 0:
				b.buff_turns[i] -= 1
				if b.buff_turns[i] == 0:
					b.buffs[i] = 0


func _regenerate(b: XBattler, logs: Array) -> void:
	var dh := floorf(b.mhp * b.hrg)
	var dm := floorf(b.mmp * b.mrg)
	if dh != 0.0:
		b.hp = clampf(b.hp + dh, 1.0, b.mhp) if dh < 0.0 else minf(b.mhp, b.hp + dh)
		logs.append({"type": "regen", "target": b, "hp": -dh})
	if dm != 0.0:
		b.mp = clampf(b.mp + dm, 0.0, b.mmp)
	b.tp = minf(100.0, b.tp + 100.0 * b.trg)


## MV：逃跑率在战斗开始时算一次（0.5×我方平均敏捷/敌方平均敏捷），每失败一次 +0.1。
## 逃跑失败在 OTB 下只消耗这名角色的本次行动（由画面层调用 act(u, null, null)）。
func try_escape() -> bool:
	escaped = randf() < _escape_ratio
	if not escaped:
		_escape_ratio += 0.1
	return escaped

func _avg_agi(list: Array) -> float:
	var l := list
	var s := 0.0
	for b in l:
		s += b.agi
	return s / maxf(l.size(), 1.0)


# ---- 奖励（难度掉率：经验、金钱、物品1~3）----
func rewards() -> Dictionary:
	var rates: Array = Array(str(XDB.plugin("Vitsuno_Difficulty").get("%d : Drop Rate" % state.difficulty, "1,1,1,1,1")).split(",")).map(func(x): return float(x))
	var exp := 0.0
	var gold := 0.0
	var drops := []
	var gold_up := 0.0
	var item_up := 0.0
	# GT_EquipSuitCore 用 $gameParty.members()，战斗中即出战成员
	var reward_members := actors
	var suit_drop := XEquipSuits.reward(reward_members,1.0,2)
	for a in actors:
		gold_up = maxf(gold_up, _passive_sum(a, "passiveGRUP"))
		item_up = maxf(item_up, _passive_sum(a, "passiveIRUP"))
	for e in enemies:
		var d: Dictionary = e.data()
		exp += float(e.exp_reward()) * rates[0]
		gold += float(e.gold_reward()) * rates[1] * (1.0 + gold_up / 100.0)
		var di: Array = d.get("dropItems", [])
		for i in range(di.size()):
			var drop: Dictionary = di[i]
			if int(drop.kind) > 0 and int(drop.denominator) > 0:
				var rate := float(rates[2 + i]) if 2 + i < rates.size() else 1.0
				if randf() * int(drop.denominator) < rate * e.drop_rate_bonus() * (1.0 + item_up / 100.0) * suit_drop:
					drops.append({"kind": int(drop.kind), "id": int(drop.dataId)})
		for extra in _extra_drops(d):
			if randf() < extra.rate * e.drop_rate_bonus() * (1.0 + item_up / 100.0) * suit_drop:
				drops.append({"kind": extra.kind, "id": extra.id})
	drops = XHangUp.shield_drops(state, drops)
	return {"exp": int(XEquipSuits.reward(reward_members,roundi(exp),0)), "gold": int(XEquipSuits.reward(reward_members,roundi(gold),1)), "drops": drops}

func _passive_sum(a: XActor, tag: String) -> float:
	var v := 0.0
	for m in a.passive_values(tag):
		v += XActor._num(m)
	return v

## YEP_ExtraEnemyDrops：<Enemy Drops> Item/Weapon/Armor x: y% </Enemy Drops>
static func _extra_drops(d: Dictionary) -> Array:
	var out := []
	var m := RegEx.create_from_string("(?is)<Enemy Drops>(.*?)</Enemy Drops>").search(str(d.get("note", "")))
	if m == null:
		return out
	for line in m.get_string(1).split("\n"):
		var lm := RegEx.create_from_string("(?i)(Item|Weapon|Armor)\\s+(\\d+):\\s*([\\d.]+)%").search(line)
		if lm:
			out.append({"kind": {"item": 1, "weapon": 2, "armor": 3}[lm.get_string(1).to_lower()], "id": int(lm.get_string(2)), "rate": float(lm.get_string(3)) / 100.0})
	return out


## 发放奖励，返回升级信息 [{actor, levels}]
func grant(r: Dictionary) -> Array:
	state.gain_gold(r.gold)
	for d in r.drops:
		match int(d.kind):
			1: state.gain_item(d.id, 1)
			2: state.gain_gear("weapon", d.id, 1)
			3: state.gain_gear("armor", d.id, 1)
	# MV BattleManager.gainExp：全队（含阵亡与后备）都得经验；后备按 System「后备成员获得经验」（optExtraExp）
	var ups := []
	var bench_rate := 1.0 if bool(XDB.system().get("optExtraExp", false)) else 0.0
	for a in state.members():
		var n: int = a.gain_exp(r.exp, 1.0 if actors.has(a) else bench_rate)
		if n > 0:
			ups.append({"actor": a, "levels": n})
	return ups


func end_battle() -> void:
	# Game_Unit.onBattleEnd 先退出战斗，再对全队（含后备）调用 onBattleEnd。
	for b in state.members():
		b.guarding = false
		b.buffs.fill(0)
		b.buff_turns.fill(0)
		# MV Game_Battler.onBattleEnd：clearTp（保留 TP 时不清）
		if not b.traits_set(TRAIT_SPECIAL_FLAG).has(FLAG_PRESERVE_TP):
			b.tp = 0.0
		b.end_battle_cooldowns()
		for id in b.state_ids.duplicate():
			if bool(XDB.rec("States", id).get("removeAtBattleEnd", false)):
				b.remove_state(id)
		b.refresh_passive()
		b.hp = minf(b.hp, b.mhp)
		b.mp = minf(b.mp, b.mmp)
