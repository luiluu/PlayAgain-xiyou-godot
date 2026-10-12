class_name XBattleLogic
extends RefCounted
## 战斗规则（不含画面）：MV 回合制——全员选好行动后按速度排序依次执行。
## 伤害交给 XDamage（与正式版对照过），这里负责命中/闪避/会心、技能消耗、效果、状态回合、敌人 AI、奖励。
## 每次行动返回一组记录（log），画面层按记录播放；无界面测试也直接用这些记录。
## 首期精简：OTB 行动顺序条、追加行动、反击/反射、技能冷却、精英变体不做。

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


func setup(troop: int, s: XState) -> void:
	state = s
	troop_id = troop
	actors = s.battle_members()
	enemies.clear()
	var letters := {}
	var t := XDB.rec("Troops", troop)
	for m in t.get("members", []):
		if bool(m.get("hidden", false)):
			continue
		var e := XEnemy.new().setup(int(m.enemyId), s.difficulty)
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
		a.on_battle_start()


func alive(list: Array) -> Array:
	return list.filter(func(b): return b.is_alive())

func is_won() -> bool:
	return alive(enemies).is_empty()

func is_lost() -> bool:
	return alive(actors).is_empty()

func vars() -> Array:
	return state.variable_array()


# ---- 技能可用 ----
func skill_cost(a: XBattler, skill: Dictionary) -> Dictionary:
	return {"mp": floori(float(skill.get("mpCost", 0)) * a.mcr), "tp": int(skill.get("tpCost", 0))}

func can_use(a: XBattler, skill: Dictionary) -> bool:
	if skill.is_empty():
		return false
	var occ := int(skill.get("occasion", 0))
	if occ != 0 and occ != 1:
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
	var out := []
	for s in a.skills():
		if int(s.id) > GUARD_SKILL and int(s.stypeId) != 4 and not s.get("meta", {}).has("Hide in Battle") and can_use(a, s):
			out.append(s)
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


## 自动战斗：选对当前目标伤害最高的可用技能（不含治疗），HP 低于 35% 时优先治疗技能。
func auto_action(a: XActor) -> Array:
	var target: XBattler = alive(enemies).reduce(func(x, y): return x if x.hp <= y.hp else y) if not alive(enemies).is_empty() else null
	var best: Dictionary = XDB.rec("Skills", ATTACK_SKILL)
	var best_v := -1.0
	var low_ally = null
	for b in alive(actors):
		if b.hp_rate() < 0.35 and (low_ally == null or b.hp_rate() < low_ally.hp_rate()):
			low_ally = b
	for s in [XDB.rec("Skills", ATTACK_SKILL)] + usable_skills(a):
		var t := int(s.damage.type)
		if low_ally != null and t == 3 and [7, 8, 11].has(int(s.scope)):
			return [s, low_ally]
		if target == null or not [1, 5].has(t) or not [1, 2, 3, 4, 5, 6].has(int(s.scope)):
			continue
		var v: float = XDamage.calculate(s, a, target, {"variance": false, "vars": vars()}).value
		if int(s.scope) == 2:
			v *= alive(enemies).size()
		if v > best_v:
			best_v = v
			best = s
	return [best, target]


# ---- 回合 ----
## commands: actor -> [skill, target]；返回本回合按顺序的行动记录。
func run_turn(commands: Dictionary) -> Array:
	turn += 1
	var order := []
	for a in alive(actors):
		var cmd: Array = commands.get(a, auto_action(a) if auto else [XDB.rec("Skills", ATTACK_SKILL), null])
		if cmd[0] == null:
			continue  # 本回合不行动（如逃跑失败）
		order.append({"user": a, "skill": cmd[0], "target": cmd[1]})
	for e in alive(enemies):
		order.append({"user": e, "skill": enemy_action(e), "target": null})
	for o in order:
		var u: XBattler = o.user
		o.speed = u.agi + randi_range(0, floori(5 + u.agi / 4.0)) + int(o.skill.get("speed", 0))
		if int(o.skill.id) == ATTACK_SKILL:
			o.speed += u.traits_sum_all(XBattler.TRAIT_ATTACK_SPEED)
	order.sort_custom(func(x, y): return x.speed > y.speed)
	var logs := []
	for o in order:
		var u: XBattler = o.user
		if u.is_dead() or is_won() or is_lost():
			continue
		if _restricted(u):
			logs.append({"type": "skip", "user": u})
			continue
		if int(o.skill.id) == GUARD_SKILL:
			u.guarding = true
			logs.append({"type": "guard", "user": u})
			continue
		logs.append_array(execute(u, o.skill, o.target))
		_tick_states(u, 1)
	for b in actors + enemies:
		b.guarding = false
		if b.is_alive():
			_tick_states(b, 2)
			_regenerate(b, logs)
	return logs

func _restricted(b: XBattler) -> bool:
	for s in b.states():
		if int(s.restriction) >= 4:
			return true
	return false


## 执行一次行动：消耗、目标、连击、命中、伤害、效果。
func execute(u: XBattler, skill: Dictionary, chosen: XBattler) -> Array:
	var logs := []
	if not can_use(u, skill):
		skill = XDB.rec("Skills", ATTACK_SKILL)
	var c := skill_cost(u, skill)
	u.mp -= c.mp
	u.tp -= c.tp
	logs.append({"type": "action", "user": u, "skill": skill})
	var repeats := int(skill.get("repeats", 1))
	if int(skill.id) == ATTACK_SKILL:
		repeats += int(u.traits_sum_all(XBattler.TRAIT_ATTACK_TIMES))
	for t in targets_for(u, skill, chosen):
		for i in range(maxi(1, repeats)):
			if t.is_dead() and not [9, 10].has(int(skill.scope)):
				break
			logs.append(apply(u, skill, t))
	return logs


func apply(u: XBattler, skill: Dictionary, t: XBattler) -> Dictionary:
	var r := {"type": "hit", "user": u, "target": t, "skill": skill, "missed": false, "evaded": false, "critical": false,
		"hp": 0.0, "mp": 0.0, "added": [], "removed": [], "died": false}
	var dmg: Dictionary = skill.damage
	var physical := XDamage.is_physical(skill)
	var magical := XDamage.is_magical(skill)
	var hit_rate := float(skill.get("successRate", 100)) * 0.01 * (u.hit if physical else 1.0)
	var eva_rate := t.eva if physical else (t.mev if magical else 0.0)
	if u.is_actor() == t.is_actor():
		eva_rate = 0.0
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
			var v := (t.mhp * v1 + v2) * t.rec
			t.hp = minf(t.mhp, t.hp + v)
			r.hp -= v
		12:
			var v := (t.mmp * v1 + v2) * t.rec
			t.mp = minf(t.mmp, t.mp + v)
			r.mp -= v
		13:
			t.tp = minf(100.0, t.tp + v1)
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


func state_rate(b: XBattler, id: int) -> float:
	return b.traits_pi(XBattler.TRAIT_STATE_RATE, id)


func _die(b: XBattler) -> void:
	b.hp = 0.0
	b.state_ids.clear()
	b.state_turns.clear()
	b.state_ids.append(DEATH_STATE)
	for i in range(8):
		b.buffs[i] = 0


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


func try_escape() -> bool:
	var ratio := 0.5 * _avg_agi(actors) / maxf(_avg_agi(enemies), 1.0)
	escaped = randf() < ratio
	return escaped

func _avg_agi(list: Array) -> float:
	var l := alive(list)
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
	for a in actors:
		gold_up = maxf(gold_up, _passive_sum(a, "passiveGRUP"))
		item_up = maxf(item_up, _passive_sum(a, "passiveIRUP"))
	for e in enemies:
		var d: Dictionary = e.data()
		exp += float(d.exp) * rates[0]
		gold += float(d.gold) * rates[1] * (1.0 + gold_up / 100.0)
		var di: Array = d.get("dropItems", [])
		for i in range(di.size()):
			var drop: Dictionary = di[i]
			if int(drop.kind) > 0 and int(drop.denominator) > 0:
				var rate := float(rates[2 + i]) if 2 + i < rates.size() else 1.0
				if randf() * int(drop.denominator) < rate * (1.0 + item_up / 100.0):
					drops.append({"kind": int(drop.kind), "id": int(drop.dataId)})
		for extra in _extra_drops(d):
			if randf() < extra.rate * (1.0 + item_up / 100.0):
				drops.append({"kind": extra.kind, "id": extra.id})
	return {"exp": roundi(exp), "gold": roundi(gold), "drops": drops}

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
	var ups := []
	for a in actors:
		if a.is_alive():
			var n: int = a.gain_exp(r.exp)
			if n > 0:
				ups.append({"actor": a, "levels": n})
	return ups


func end_battle() -> void:
	for b in actors:
		b.guarding = false
		for id in b.state_ids.duplicate():
			if bool(XDB.rec("States", id).get("removeAtBattleEnd", false)):
				b.remove_state(id)
		b.refresh_passive()
