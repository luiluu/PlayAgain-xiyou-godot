class_name XRaceBattle
extends RefCounted
## 种族祝福的能力值与战斗效果（冻结 v0.28 installNativeRaceRuntime 的规则侧；菜单侧在 race.gd）。参照 mv_oracle/race_battle_probe.cjs
## → generated/oracle/race_battle.json，测试 tests/xiyou_race_battle。q＝CodexRaces.rates[阶−1]。
## - 能力值（Game_Actor.param 包装，Math.round）：人族八项 ×1.03；鬼族最大法力 ×(1+q)；蛮族最大生命 ×(1+q)。
##   灵族 paramPlus 加每把武器本体值（去掉宝珠镶嵌行的固定加值，不低于 0）×q/2。鬼族技能 MP／TP 消耗 ×(1−q/2) 向上取整、至少 1。
## - 行动根（BattleManager.startAction 起、endAction 止；行动外的 Game_Action.apply 自成一根）：记本次对各目标的有效伤害、回复，
##   妖族猎物、神族本回合首次魔法、魔族血契、鬼族残响、蛮族反攻目标；反击、魔法反射和种族自己的结算（derived）不算原行动。
## - 伤害钩子 race-blessings（CodexDamageHooks 第 20 个，build → order 41）：只对技能、非 percent／fixed／settled 伤害：
##   神族治疗 ×(1+q)、魔法 ×(1+q)，本回合首次魔法无视 q/2 魔防；魔族物理 ×(1+q)、暴击倍率 +q/2，血契 ×(1+q/2)；
##   灵族匹配兵器的技能（普通攻击总匹配）终伤 ×(1+q)；妖族对猎物双防与固定减伤 ×(1−q)、终伤 ×(1+q/2)（猎物生命≤30% 时 ×(1+q)）；
##   蛮族对反攻目标终伤 ×(1+1.5q)。
## - 回合末（BattleManager.endTurn）：人族毒鸡汤按记下的有效伤害 ×q/2 结算并去掉毒鸡汤状态；鬼族把本回合的技能组交给下回合。
## - 蛮族：敌人行动对本人的直接伤害每回合首个行动最多扣开战最大生命 ×(0.75−2q)（0.45 记 0.5）；受伤≥10% 后下回合内反攻来源。
## - 人族九九六：每回合 q/2 概率在 OTB 行动顺序里该角色最后一次之后再插一次（规则随机数，Math.random）。
## - 战力预演（power_*，XPower 调）、选敌帮助的毒鸡汤说明（poison_info）；种族补给在 XDungeon.race_supply，learnSkill 包装在 XRace.learn。
## - 妖族群攻手选猎物（needs_prey_selection／set_manual_prey）、战斗指令「血契：开／关」（blood_command_text，切换在 XRace.toggle_blood）：
##   画面在 battle_scene.gd。旧道具合并与商店在 XItemMarks／XState.gain_item。
## 不移植：状态说明 R.status（冻结源里没有调用处）。

static func config() -> Dictionary:
	return XRace.config()


## 不迁移、不改技能的读取（原版 data(a)：角色建出时就有，重制在 XState.actor 建出时补，见 XRace.on_actor_created）
static func data_of(a) -> Dictionary:
	if not a is XActor or XState.current == null or config().is_empty():
		return {}
	var all = XState.current.race.get("actors", {})
	return all.get(str(a.actor_id), {}) if all is Dictionary else {}


static func rate_of(a) -> float:
	var d := data_of(a)
	return float(config().rates[int(d.rank) - 1]) if not d.is_empty() and int(d.race) >= 0 else 0.0


static func race_of(a) -> int:
	var d := data_of(a)
	return int(d.race) if not d.is_empty() else -1


static func js_round(v: float) -> float:
	return floorf(v + 0.5)


# ---- 能力值 ----
## Game_Actor.param 包装：有种族数据且已选族时整体 Math.round
static func param(a: XActor, i: int, v: float) -> float:
	var d := data_of(a)
	if d.is_empty() or int(d.race) < 0:
		return v
	var q := rate_of(a)
	var r := int(d.race)
	if r == 2:
		v *= 1.03
	if r == 4 and i == 1:
		v *= 1.0 + q
	if r == 6 and i == 0:
		v *= 1.0 + q
	return js_round(v)


const BODY_NAMES := ["(?:max\\s*hp|mhp|hp)", "(?:max\\s*mp|mmp|mp)", "(?:atk|attack)", "(?:def|defense)", "(?:mat|magic attack)",
	"(?:mdf|magic defense)", "(?:agi|agility)", "(?:luk|luck)"]

## R.weaponBody：武器的该项属性减去宝珠镶嵌行（<Augment Attach>）的固定加减，不低于 0
static func weapon_body(eq: Dictionary, p: int) -> float:
	if eq.is_empty() or str(eq.get("kind", "")) != "weapon":
		return 0.0
	var value := float(eq.params[p])
	var slots: Array = eq.get("augmentSlots", [])
	var held: Array = eq.get("augmentSlotItems", [])
	var re := RegEx.create_from_string("(?i)^" + BODY_NAMES[p] + "\\s*:\\s*([+-]\\d+)$")
	for i in held.size():
		var gem := XOrbs.gem_in_slot(eq, i)
		var type := str(slots[i] if i < slots.size() else "").to_upper().strip_edges()
		if gem.is_empty() or type == "":
			continue
		for line in XOrbs.parse(gem).attach.get(type, []):
			var m := re.search(str(line).strip_edges())
			if m:
				value -= float(m.get_string(1))
	return maxf(0.0, value)


## Game_Actor.paramPlus 包装：灵族加每把武器本体值 ×q/2
static func param_plus(a: XActor, i: int) -> float:
	if race_of(a) != 5:
		return 0.0
	var q := rate_of(a)
	var v := 0.0
	for e in a.equip_list():
		if str(e.get("kind", "")) == "weapon":
			v += weapon_body(e, i) * q / 2.0
	return v


## skillMpCost／skillTpCost 包装：鬼族 n>0 时 max(1, ceil(n×(1−q/2)))
static func cost(a, n: int) -> int:
	if n > 0 and race_of(a) == 4:
		return maxi(1, ceili(n * (1.0 - rate_of(a) / 2.0)))
	return n


# ---- 战斗数据 ----
static var _logic_ref: WeakRef


static func _store(logic) -> Dictionary:
	if not logic.has_meta("xrace"):
		logic.set_meta("xrace", {"actors": {}, "current": null, "hit": null, "derived": 0, "lastEnd": -1, "serial": 0, "pending": [], "manual": {}})
	return logic.get_meta("xrace")


static func active_logic():
	return _logic_ref.get_ref() if _logic_ref != null else null


static func turn(logic) -> int:
	return maxi(1, int(logic.turn))


## R.battleState：每场一份，建出时记下最大生命
static func state(logic, a) -> Dictionary:
	var st := _store(logic)
	if not st.actors.has(a):
		st.actors[a] = {"maxHp": a.mhp, "godTurn": -1, "bloodTurn": -1, "capTurn": -1, "gainTurn": -1, "spendTurn": -1,
			"echoTurn": -1, "humanTurn": -1, "humanExtra": false, "humanInserted": -1, "ghostPrevious": null, "ghostCurrent": null,
			"poison": [], "counter": null, "cap": null, "lastPrey": null}
	return st.actors[a]


## BattleManager.startBattle 包装：清本场数据，出战成员建数据
static func start(logic) -> void:
	logic.set_meta("xrace", {"actors": {}, "current": null, "hit": null, "derived": 0, "lastEnd": -1, "serial": 0, "pending": [], "manual": {}})
	_logic_ref = weakref(logic)
	for a in logic.actors:
		state(logic, a)


static func _live(b) -> bool:
	return b != null and b.is_alive() and b.hp > 0.0


static func _toast(logs: Array, text: String) -> void:
	logs.append({"type": "toast", "text": text})


static func _is_skill(item: Dictionary) -> bool:
	return not item.is_empty() and not XBattleLogic.is_item(item)


static func _damage_spec(item: Dictionary) -> Dictionary:
	return XDamage.elements_data().skills.get(str(int(item.get("id", 0))), {})


static func _mixed(item: Dictionary) -> bool:
	return str(_damage_spec(item).get("mode", "")) == "mixed"


## eligible：技能、不在种族自己的结算里；有行动根时只认根本身的行动（ended 后只有 finish 认）
static func eligible(logic, root, item: Dictionary, finishing := false) -> bool:
	if not _is_skill(item):
		return false
	var st := _store(logic)
	if int(st.derived) > 0:
		return false
	var cur = st.current
	if cur != null and (cur != root or (bool(cur.ended) and not finishing)):
		return false
	return true


static func group(item: Dictionary) -> int:
	var id := int(item.get("id", 0))
	return int(config().get("skillGroups", {}).get(str(id), id))


## R.weaponMatches：普通攻击总匹配；兵器授予技能（weaponGrants，按武器本体编号）；技能要求的武器类型（weaponSkills）
static func weapon_matches(a, item: Dictionary) -> bool:
	if not a is XActor or not _is_skill(item):
		return false
	var weapons: Array = a.equip_list().filter(func(e): return str(e.get("kind", "")) == "weapon")
	if weapons.is_empty():
		return false
	var id := int(item.id)
	if a.is_attack(item):  # x.isAttack()||id===attackSkillId
		return true
	for e in weapons:
		var base := int(e.get("base", e.get("id", 0)))
		if (config().get("weaponGrants", {}).get(str(base), []) as Array).has(id):
			return true
	for t in config().get("weaponSkills", {}).get(str(id), []):
		if weapons.any(func(e): return int(e.get("wtypeId", 0)) == int(t)):
			return true
	return false


# ---- 妖族猎物 ----
## prey：活着的敌方目标；只有一个就是它；有 Boss 时只在 Boss 里挑；否则逐个预演（不含种族加成），取最高、并列取靠前
static func prey(logic, u, item: Dictionary, targets: Array, manual = null):
	var list := []
	for t in targets:
		if _live(t) and t is XEnemy and not list.has(t):
			list.append(t)
	if list.is_empty():
		return null
	if manual != null and list.has(manual):  # 群攻时玩家在选敌窗指定的（_codexRacePreyIndex），还活着且在目标里才算
		return manual
	var boss := list.filter(func(t): return XZhenqi.is_boss_enemy(t))
	if not boss.is_empty():
		list = boss
	if list.size() == 1:
		return list[0]
	var best = list[0]
	var score := -INF
	for t in list:
		var v := float(XDamage.calculate(item, u, t, {"preview": true, "raceProbe": true, "vars": logic.vars()}).get("value", 0.0))
		if v > score:
			best = t
			score = v
	return best


## Game_Action.needsSelection 包装：妖族用对全体敌人（scope 2）的伤害（类型 1／5）技能或物品时也要选一名敌人当猎物
static func needs_prey_selection(a, item: Dictionary) -> bool:
	return race_of(a) == 1 and int(item.get("scope", 0)) == 2 and int(item.get("damage", {}).get("type", 0)) in [1, 5]


## Scene_Battle.onEnemyOk 包装：记下这次行动手选的猎物（原版记在行动上；重制按角色＋技能暂存，下一个行动根取走）
static func set_manual_prey(logic, a, item: Dictionary, t) -> void:
	_store(logic).manual[a] = {"item": int(item.get("id", 0)), "target": t}


static func _take_manual(logic, u, item: Dictionary):
	var manual: Dictionary = _store(logic).get("manual", {})
	if not manual.has(u):
		return null
	var m: Dictionary = manual[u]
	manual.erase(u)
	return m.target if int(m.item) == int(item.get("id", 0)) else null


## 战斗指令「血契：开／关」（Window_ActorCommand.makeCommandList 包装，魔族才有）；没有返回空
static func blood_command_text(a) -> String:
	if race_of(a) != 3:
		return ""
	return "血契：" + ("开" if bool(data_of(a).blood) else "关")


# ---- 行动根 ----
## R.begin（startAction 包装＋makeTargets 包装的合并）：建根，妖族定猎物，蛮族取未过期的反攻目标
static func begin(logic, u, item: Dictionary, targets: Array, logs: Array = []) -> Dictionary:
	var pending: Array = _store(logic).pending
	if not pending.is_empty():
		logs.append_array(pending)
		pending.clear()
	var a_state = state(logic, u) if u is XActor else null
	var r := {"subject": u, "item": item, "targets": targets.duplicate(), "records": [], "incoming": [], "ended": false,
		"prey": null, "low": false, "divine": a_state != null and int(a_state.godTurn) != turn(logic), "blood": false, "echo": false,
		"counter": null, "counterUsed": false}
	var manual = _take_manual(logic, u, item)
	if race_of(u) == 1:
		r.prey = prey(logic, u, item, targets, manual)
		r.low = r.prey != null and r.prey.hp / maxf(r.prey.mhp, 1.0) <= 0.3
	if a_state != null and a_state.counter != null:
		if not _live(a_state.counter.target) or int(a_state.counter.until) < turn(logic):
			a_state.counter = null
		elif int(a_state.spendTurn) != turn(logic):
			r.counter = a_state.counter.target
	_activate(logic, r, logs)
	return r


## activate：妖族报猎物；魔族血契（每回合首次物理技能，手动生命≥30%、自动或挂机≥50% 开战最大生命）付 3%；鬼族残响判定
static func _activate(logic, r: Dictionary, logs: Array) -> void:
	var a = r.subject
	var item: Dictionary = r.item
	_store(logic).current = r
	if not a is XActor or not eligible(logic, r, item):
		return
	var d := data_of(a)
	if d.is_empty():
		return
	var s := state(logic, a)
	if int(d.race) == 1 and r.prey != null:
		s.lastPrey = r.prey
		_toast(logs, a.display_name() + "·猎物：" + r.prey.display_name())
	var dmg_type := int(item.get("damage", {}).get("type", 0))
	if int(d.race) == 3 and bool(d.blood) and int(s.bloodTurn) != turn(logic) and dmg_type == 1 and (XDamage.is_physical(item) or _mixed(item)):
		var threshold := 0.5 if (logic.auto or XHangUp.is_active(XState.current)) else 0.3
		if a.hp >= float(s.maxHp) * threshold:
			s.bloodTurn = turn(logic)
			r.blood = true
			a.hp = maxf(1.0, a.hp - maxf(1.0, ceilf(float(s.maxHp) * 0.03)))
			a.refresh_resources()
			_toast(logs, a.display_name() + "发动血契")
	var prev = s.ghostPrevious
	r.echo = int(d.race) == 4 and int(s.echoTurn) != turn(logic) and prev != null and int(prev.turn) == turn(logic) - 1 \
		and int(prev.group) == group(item) and not a.is_attack(item) and dmg_type in [1, 3, 4, 5]


static func current(logic):
	return _store(logic).current if logic != null else null


## 直接伤害（executeHpDamage 记有效伤害、蛮骨上限用）：钩子认得的技能，伤害类型 1／5，不是 percent／settled
static func _direct(logic, r, item: Dictionary) -> bool:
	return eligible(logic, r, item) and not str(_damage_spec(item).get("kind", "")) in ["percent", "settled"] \
		and int(item.get("damage", {}).get("type", 0)) in [1, 5]


static func _record(r: Dictionary, t) -> Dictionary:
	for row in r.records:
		if is_same(row.target, t):
			return row
	var row := {"target": t, "damage": 0.0, "hpHeal": 0.0, "mpHeal": 0.0}
	r.records.append(row)
	return row


## executeHpDamage 进入：设好蛮骨上限用的结算上下文，返回交给 after_hp 的记录
static func before_hp(logic, u, item: Dictionary, t) -> Dictionary:
	var r = current(logic)
	var st := _store(logic)
	var prior = st.hit
	var ctx = null
	if r != null and _direct(logic, r, item):
		ctx = {"root": r, "source": u, "item": item, "limited": false}
		st.hit = ctx
	return {"prior": prior, "ctx": ctx, "hp": t.hp, "shield": t.shield, "root": r}


## executeHpDamage 结束（finally）：恢复上下文，记有效伤害（扣血＋扣盾）／回复，神族记本回合已用魔法，反攻已用，敌人对我方的来伤
static func after_hp(logic, u, item: Dictionary, t, mark: Dictionary) -> void:
	var st := _store(logic)
	st.hit = mark.prior
	var r = mark.root
	var loss := maxf(0.0, float(mark.hp) - t.hp)
	var used := maxf(0.0, float(mark.shield) - t.shield)
	var healed := maxf(0.0, t.hp - float(mark.hp))
	if r == null:
		return
	if eligible(logic, r, item) and int(st.derived) == 0:
		var row := _record(r, t)
		if _direct(logic, r, item):
			row.damage += loss + used
		if int(item.damage.type) == 3:
			row.hpHeal += healed
		if loss + used > 0.0 and r.subject is XActor and race_of(r.subject) == 0 and (XDamage.is_magical(item) or _mixed(item)):
			state(logic, r.subject).godTurn = turn(logic)
		if loss + used > 0.0 and r.counter != null and is_same(r.counter, t):
			state(logic, r.subject).spendTurn = turn(logic)
			r.counterUsed = true
	if _direct(logic, r, item) and r.subject is XEnemy and t is XActor and loss + used > 0.0:
		for inc in r.incoming:
			if is_same(inc.target, t):
				inc.loss += loss + used
				return
		r.incoming.append({"target": t, "loss": loss + used})


## executeMpDamage 结束：MP 回复（伤害类型 4）记进回复
static func after_mp(logic, item: Dictionary, t, before_mp: float) -> void:
	var r = current(logic)
	if r != null and eligible(logic, r, item) and int(item.damage.type) == 4:
		_record(r, t).mpHeal += maxf(0.0, t.mp - before_mp)


## R.limitHp（YEP setHp 里调）：蛮族受敌人直接伤害时，每回合第一个这样的行动最多扣开战最大生命 ×(0.75−2q)；返回本次能扣的量
static func limit_loss(logic, t, loss: float) -> float:
	if logic == null or loss <= 0.0:
		return loss
	var st := _store(logic)
	var hit = st.hit
	if hit == null or int(st.derived) > 0 or not t is XActor or race_of(t) != 6 or not hit.source is XEnemy or not eligible(logic, hit.root, hit.item):
		return loss
	var s := state(logic, t)
	if int(s.capTurn) != turn(logic):
		s.capTurn = turn(logic)
		s.cap = {"root": hit.root, "spent": 0.0}
	var cap = s.cap
	if cap == null or not is_same(cap.root, hit.root):
		return loss
	var cap_rate := 0.75 - 2.0 * rate_of(t)
	if absf(cap_rate - 0.45) < 1e-9:
		cap_rate = 0.5
	var most := floorf(float(s.maxHp) * cap_rate)
	var allowed := minf(loss, maxf(0.0, most - float(cap.spent)))
	cap.spent = float(cap.spent) + minf(t.hp, allowed)
	if allowed < loss:
		hit.limited = true
	return allowed


## 种族自己的伤害（毒鸡汤、残响）：对目标免疫（死了、没毒鸡汤状态、对应伤害率 0、全部属性有效度 ≤0）不算；
## 先过护盾（CodexShieldLedger.absorbRaceDamage：账本再原生护盾），扣血、刷新、倒下；返回扣血＋扣盾
static func settled_damage(logic, t, n: float, item: Dictionary, poison: int, logs: Array, u = null) -> float:
	if n <= 0.0 or _immune(t, item, poison, u):
		return 0.0
	var st := _store(logic)
	st.derived = int(st.derived) + 1
	var before: float = t.hp
	var ab := XShieldLedger.absorb_race(t, floorf(n))  # 账本静默先扣，再扣原生护盾
	var remaining: float = ab.remaining
	var absorbed: float = ab.absorbed
	t.hp = maxf(0.0, t.hp - remaining)
	t.refresh_resources()
	logs.append({"type": "regen", "target": t, "hp": before - t.hp, "views": logic.views([t])})
	if t.is_dead():
		logs.append({"type": "collapse", "target": t, "views": logic.views([t])})
	st.derived = int(st.derived) - 1
	return before - t.hp + absorbed


static func _immune(t, item: Dictionary, poison: int, u) -> bool:
	if not _live(t):
		return true
	if poison > 0:
		return not t.state_ids.has(poison) or t.traits_set(XBattler.TRAIT_STATE_RESIST).has(poison)
	if item.is_empty():
		return false
	var rate: float = t.pdr if XDamage.is_physical(item) else (t.mdr if XDamage.is_magical(item) else 1.0)
	if rate == 0.0:
		return true
	var es: Array = XDamage.action_elements(item, u) if u != null else []
	return not es.is_empty() and es.all(func(e): return t.element_rate(int(e)) <= 0.0)


static func _heal_echo(logic, t, n: float, mp: bool, logs: Array) -> float:
	if not _live(t) or n <= 0.0:
		return 0.0
	var st := _store(logic)
	st.derived = int(st.derived) + 1
	var before: float = t.mp if mp else t.hp
	if mp:
		t.mp = minf(t.mmp, t.mp + floorf(n))
	else:
		t.hp = minf(t.mhp, t.hp + floorf(n))
	t.refresh_resources()
	if not mp:
		logs.append({"type": "regen", "target": t, "hp": before - t.hp, "views": logic.views([t])})
	st.derived = int(st.derived) - 1
	return (t.mp if mp else t.hp) - before


## R.finish（endAction 包装）：人族给受到伤害的活目标上毒鸡汤（照技能效果附加状态的掷骰）并累计有效伤害 ×q/2；
## 鬼族记本次技能组、残响时对各目标再结算 q 倍伤害与回复；反攻用掉就清；敌人来伤≥10% 开战最大生命时蛮族准备反攻
static func finish(logic, logs: Array = []) -> void:
	var st := _store(logic)
	var r = st.current
	st.current = null
	st.hit = null
	if r == null or bool(r.ended):
		return
	r.ended = true
	var a = r.subject
	var item: Dictionary = r.item
	var d := data_of(a)
	var q := rate_of(a)
	var total := 0.0
	for v in r.records:
		total += float(v.damage) + float(v.hpHeal) + float(v.mpHeal)
	st.current = r
	if not d.is_empty() and eligible(logic, r, item, true):
		var s := state(logic, a)
		if int(d.race) == 2:
			var id := int(config().poisons[int(d.rank) - 1])
			for v in r.records:
				if float(v.damage) <= 0.0 or not _live(v.target):
					continue
				logic._effect(a, v.target, {"code": 21, "dataId": id, "value1": 1.0, "value2": 0.0}, {"skill": item, "added": [], "removed": []})
				if v.target.state_ids.has(id):
					var found := false
					for p in s.poison:
						if is_same(p.target, v.target) and int(p.id) == id and int(p.turn) == turn(logic):
							p.amount = float(p.amount) + float(v.damage) * q / 2.0
							found = true
							break
					if not found:
						s.poison.append({"target": v.target, "id": id, "amount": float(v.damage) * q / 2.0, "turn": turn(logic)})
		var dmg_type := int(item.damage.type)
		if int(d.race) == 4 and total > 0.0 and not a.is_attack(item) and dmg_type in [1, 3, 4, 5]:
			s.ghostCurrent = {"group": group(item), "turn": turn(logic)}
			if bool(r.echo):
				s.echoTurn = turn(logic)
				for v in r.records:
					if float(v.damage) > 0.0:
						settled_damage(logic, v.target, float(v.damage) * q, item, 0, logs, a)
					if float(v.hpHeal) > 0.0:
						_heal_echo(logic, v.target, float(v.hpHeal) * q, false, logs)
					if float(v.mpHeal) > 0.0:
						_heal_echo(logic, v.target, float(v.mpHeal) * q, true, logs)
		if bool(r.counterUsed):
			s.counter = null
	for v in r.incoming:
		var t = v.target
		if not _live(t) or race_of(t) != 6:
			continue
		var s := state(logic, t)
		if s.counter == null and int(s.gainTurn) != turn(logic) and float(v.loss) >= float(s.maxHp) * 0.1 and _live(a):
			s.gainTurn = turn(logic)
			s.counter = {"target": a, "until": turn(logic) + 1}
			_toast(logs, t.display_name() + "准备反攻" + a.display_name())
	st.current = null


## 反击、魔法反射：独立数值来源，不是原行动（current 暂时清空、derived +1）
static func derived_begin(logic) -> Variant:
	var st := _store(logic)
	var prev = st.current
	st.current = null
	st.derived = int(st.derived) + 1
	return prev


static func derived_end(logic, prev) -> void:
	var st := _store(logic)
	st.derived = int(st.derived) - 1
	st.current = prev


## R.roundEnd（endTurn 包装，每回合一次）：结算本回合的毒鸡汤；鬼族本回合技能组交给下回合；过期反攻清掉；全场去掉毒鸡汤状态
static func round_end(logic) -> Array:
	var logs := []
	var st := _store(logic)
	var r := turn(logic)
	if int(st.lastEnd) == r:
		return logs
	st.lastEnd = r
	for a in st.actors.keys():
		var s: Dictionary = st.actors[a]
		var list: Array = s.poison
		s.poison = []
		for p in list:
			if int(p.turn) == r:
				settled_damage(logic, p.target, float(p.amount), {}, int(p.id), logs)
		var cur = s.ghostCurrent
		s.ghostPrevious = cur if cur != null and int(cur.turn) == r else null
		s.ghostCurrent = null
		if s.counter != null and int(s.counter.until) <= r:
			s.counter = null
	for id in config().get("poisons", []):
		for t in logic.enemies + logic.actors:
			if t.state_ids.has(int(id)):
				t.remove_state(int(id))
	return logs


## eraseState／clearStates／removeState 毒鸡汤：清掉该目标（该状态）的待结算记录
static func on_state_removed(t, id: int) -> void:
	var logic = active_logic()
	if logic == null or not logic.has_meta("xrace") or not (config().get("poisons", []) as Array).has(id) or t.state_ids.has(id):
		return
	for s in _store(logic).actors.values():
		s.poison = (s.poison as Array).filter(func(p): return not is_same(p.target, t) or int(p.id) != id)


## die 包装：倒下的人的反攻清掉，以它为反攻目标的也清掉
static func on_death(t) -> void:
	var logic = active_logic()
	if logic == null or not logic.has_meta("xrace"):
		return
	var st := _store(logic)
	if st.actors.has(t):
		st.actors[t].counter = null
	for s in st.actors.values():
		if s.counter != null and is_same(s.counter.target, t):
			s.counter = null


## 人族九九六（OTB makeActionOrders 包装）：每回合每名出战角色掷一次，中了就在本回合顺序里它最后一次之后再插一次
static func human_extra(logic, a) -> bool:
	var s := state(logic, a)
	var r := turn(logic)
	if int(s.humanTurn) != r:
		s.humanTurn = r
		s.humanExtra = _live(a) and logic.can_move(a) and race_of(a) == 2 and logic._float("race_human") < rate_of(a) / 2.0
	return bool(s.humanExtra)


## logs 不给时（battle_logic 排行动顺序处没有提示列表）提示先暂存，下一个行动根开始时（begin）补出
static func insert_human(logic, order: Array, logs = null) -> void:
	var out: Array = logs if logs is Array else _store(logic).pending
	for a in logic.actors:
		var s := state(logic, a)
		var r := turn(logic)
		if int(s.humanInserted) == r:
			continue
		s.humanInserted = r
		if human_extra(logic, a) and order.has(a):
			var last := order.rfind(a)
			order.insert(last + 1, a)
			_toast(out, a.display_name() + "九九六：额外行动")


## R.poisonInfo（Window_BattleEnemy.updateHelp 包装）：选敌时帮助窗第二行——本回合各人记在该敌人身上、还挂着毒鸡汤的待结算量
static func poison_info(logic, t) -> String:
	if logic == null or not logic.has_meta("xrace"):
		return ""
	var rows := []
	var r := turn(logic)
	var st := _store(logic)
	var owners: Array = st.actors.keys().filter(func(x): return x is XActor)
	owners.sort_custom(func(x, y): return x.actor_id < y.actor_id)  # allActors：按角色编号
	for a in owners:
		for p in st.actors[a].poison:
			if is_same(p.target, t) and int(p.turn) == r and t.state_ids.has(int(p.id)):
				rows.append(a.display_name() + "：" + str(int(floorf(float(p.amount)))))
	return "毒鸡汤（回合末） " + "；".join(rows) if not rows.is_empty() else ""


# ---- 伤害钩子 ----
static func descriptor() -> Dictionary:
	return {"id": "race-blessings", "version": "2", "capabilities": ["damage.race_blessings"],
		"contexts": ["item", "facts"], "hooks": [{"point": "damage.before", "order": 41, "reads": ["facts.race"],
			"writes": ["healingMultiplier", "magicalDamageMultiplier", "magicalDefenseRate", "physicalDamageMultiplier", "criticalAdd",
				"finalMultiplier", "physicalDefenseRate", "flatMitigationRate"], "handler": build}]}


## 宿主取当下的事实：种族、q、行动根（猎物、首次魔法、血契、反攻）、兵器是否匹配
static func capture(item: Dictionary, a: XBattler, b: XBattler, options: Dictionary) -> Dictionary:
	var out := {"race": -1}
	var d := data_of(a)
	if d.is_empty() or int(d.race) < 0 or bool(options.get("raceProbe", false)):
		return out
	if bool(options.get("raceSuppress", false)):
		return out
	var power = options.get("racePower", null)
	if power is Dictionary:
		return _capture_power(item, a, b, options, power, d)
	var logic = active_logic()
	var r = current(logic) if logic != null and logic.has_meta("xrace") else null
	if logic != null and logic.has_meta("xrace"):
		# 有行动根时只有本次行动的结算算数（预演、别处的计算视为其他行动）
		if not eligible(logic, r if bool(options.get("raceAction", false)) else null, item):
			return out
	elif not _is_skill(item):
		return out
	if not bool(options.get("raceAction", false)):
		r = null
	var in_battle: bool = logic != null and logic.has_meta("xrace")
	var s = state(logic, a) if in_battle else null
	out.race = int(d.race)
	out.q = rate_of(a)
	out.divine = bool(r.divine) if r != null else (s == null or int(s.godTurn) != turn(logic))
	out.blood = r != null and bool(r.blood)
	out.weapon = weapon_matches(a, item)
	var hunter = r.prey if r != null else b
	out.hunter = hunter != null and is_same(hunter, b)
	out.low = bool(r.low) if r != null else b.hp / maxf(b.mhp, 1.0) <= 0.3
	out.counter = r != null and r.counter != null and is_same(r.counter, b)
	return out


## 战力预演（action._codexPowerPreview＋a._codexRacePower）：不在战斗、没有行动根；神族首魔看本回合 godUsed，
## 魔族血契看费用里的 raceBlood 或当下 powerBlood，妖族猎物就是预演目标
static func _capture_power(item: Dictionary, a, b, options: Dictionary, p: Dictionary, d: Dictionary) -> Dictionary:
	if not _is_skill(item):
		return {"race": -1}
	return {"race": int(d.race), "q": rate_of(a), "divine": not bool(p.godUsed),
		"blood": bool(options.get("racePowerBlood", false)) or power_blood(a, item, p), "weapon": weapon_matches(a, item),
		"hunter": b != null, "low": b != null and b.hp / maxf(b.mhp, 1.0) <= 0.3, "counter": false}


# ---- 战力预演（installCombatPowerRuntime 调的 R.resetPowerCycle／startPowerTurn／powerBlood／powerCost／powerAdjust／commitPowerRoot） ----
## resetPowerCycle：每条 10 回合路线一份
static func power_cycle() -> Dictionary:
	return {"turn": 0, "godUsed": false, "bloodUsed": false, "echoUsed": false, "previous": null, "last": null}


## startPowerTurn：上回合最后一次鬼族技能组交给本回合，各「本回合一次」清掉
static func power_turn(p: Dictionary, t: int) -> void:
	p.previous = p.last if p.last != null and int(p.last.turn) == t - 1 else null
	p.last = null
	p.turn = t
	p.godUsed = false
	p.bloodUsed = false
	p.echoUsed = false


## powerBlood：魔族开着血契、本回合还没付、物理（或混合）伤害技能、生命≥最大生命一半
static func power_blood(a, item: Dictionary, p: Dictionary) -> bool:
	var d := data_of(a)
	return not d.is_empty() and int(d.race) == 3 and bool(d.blood) and not bool(p.bloodUsed) \
		and int(item.get("damage", {}).get("type", 0)) == 1 and (int(item.get("hitType", 0)) == 1 or _mixed(item)) and a.hp >= a.mhp * 0.5


## powerCost：血契时费用另加 3% 最大生命（至少 1），并标 raceBlood
static func power_cost(a, item: Dictionary, cost: Dictionary, p: Dictionary) -> Dictionary:
	if power_blood(a, item, p):
		cost = cost.duplicate()
		cost.hp = float(cost.hp) + maxf(1.0, ceilf(a.mhp * 0.03))
		cost.raceBlood = true
	return cost


## powerAdjust：人族 ×(1+q/2)；鬼族上回合同组技能 ×(1+q)（每回合一次，普攻不算）；
## 妖族群攻（scope 2）：参照把一体按 60%、三体按 40% 计（×1.8），猎物加成只给一体——value/1.8×(1+0.8×无种族/有种族)
## calc.call(suppress) 返回不含期望处理的预演伤害（suppress 时不算种族钩子）
static func power_adjust(a, item: Dictionary, value: float, p: Dictionary, calc: Callable) -> float:
	var d := data_of(a)
	if d.is_empty() or value <= 0.0:
		return value
	var q := rate_of(a)
	var race := int(d.race)
	if race == 2:
		value *= 1.0 + q / 2.0
	if race == 4 and not a.is_attack(item) and not bool(p.echoUsed) and p.previous != null and int(p.previous.group) == group(item):
		value *= 1.0 + q
	if race == 1 and int(item.get("scope", 0)) == 2:
		var normal: float = calc.call(false)
		var base: float = calc.call(true)
		if normal > 0.0:
			value = value / 1.8 * (1.0 + 0.8 * base / normal)
	return value


## commitPowerRoot：选定这次行动后记神族本回合已魔法、血契已付、鬼族残响已用与本回合技能组
static func power_commit(a, item: Dictionary, value: float, p: Dictionary) -> void:
	var d := data_of(a)
	if d.is_empty() or value <= 0.0:
		return
	var key := group(item)
	if int(d.race) == 0 and (int(item.get("hitType", 0)) == 2 or _mixed(item)):
		p.godUsed = true
	if power_blood(a, item, p):
		p.bloodUsed = true
	if int(d.race) == 4 and int(item.get("id", 0)) != a.attack_skill_id():
		if p.previous != null and int(p.previous.group) == key:
			p.echoUsed = true
		p.last = {"group": key, "turn": int(p.turn)}


static func _op(field: String, value: float, operation := "mul") -> Dictionary:
	return {"op": operation, "field": field, "value": value}


static func build(context: Dictionary, frame: Dictionary) -> Dictionary:
	var f: Dictionary = context.facts.get("race", {})
	var ops := []
	if int(f.get("race", -1)) < 0 or str(frame.kind) in ["percent", "fixed", "settled"]:
		return {"ops": ops}
	var q := float(f.q)
	var race := int(f.race)
	var heal := int(context.item.get("damage", {}).get("type", 0)) in [3, 4]
	if race == 0:
		if heal:
			ops.append(_op("healingMultiplier", 1.0 + q))
		else:
			ops.append(_op("magicalDamageMultiplier", 1.0 + q))
			if bool(f.divine):
				ops.append(_op("magicalDefenseRate", 1.0 - q / 2.0))
	if heal:
		return {"ops": ops}
	if race == 3:
		ops.append(_op("physicalDamageMultiplier", 1.0 + q))
		ops.append(_op("criticalAdd", q / 2.0, "add"))
		if bool(f.blood):
			ops.append(_op("physicalDamageMultiplier", 1.0 + q / 2.0))
	if race == 5 and bool(f.weapon):
		ops.append(_op("finalMultiplier", 1.0 + q))
	if race == 1 and bool(f.hunter):
		ops.append(_op("physicalDefenseRate", 1.0 - q))
		ops.append(_op("magicalDefenseRate", 1.0 - q))
		ops.append(_op("flatMitigationRate", 1.0 - q))
		ops.append(_op("finalMultiplier", 1.0 + (q if bool(f.low) else q / 2.0)))
	if race == 6 and bool(f.counter):
		ops.append(_op("finalMultiplier", 1.0 + 1.5 * q))
	return {"ops": ops}
