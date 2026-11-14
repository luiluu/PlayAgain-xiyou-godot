class_name XTianqiAffixBattle
extends RefCounted
## 【cc·未经审查】天启篇词条的战斗结算（天启篇词条重构设计稿 v0.3 第 3.7、4～7、8.4 节；数值一律读 XTianqiAffixTable 的 affix_table.json）。
##
## 生效条件：ENABLED（O-335）且是天启篇存档，发行构建另要 XTianqi.RELEASE_OPEN（同七印装备）。原版档、关着时一条都不跑。
## 认装备：装备实例上的
##   tianqi_affixes：[{key, tier, grade, extra}…]（通用装备掷词条接线后用这个键，tier 1～4）；
##   qiyin.affixes：[{key, grade, extra}…]（七印祭坛装备，一律四阶）。
## 叠法（表里 stack）：sum 同名相加；multiply 每条相乘（叠不到 0）；max_per_actor 一人同名只取最高；max_party 全队（上场＋助力位）同名只取最高。
## 记进哪里（表里 pool）：
##   stat → XActor.param_rate（×(1＋合计%)）；xparam／regen → XActor.xparam（加百分点）；
##   final_damage（伤害加成、先声、背水、猎首）→ 伤害帧 finalAdd（和别的伤害加成同一个加法池）；crit_multiplier → criticalAdd；
##   skill_damage → skillMultiplier（只算非普攻）；element_damage → elementAdd[系]；damage_taken → incomingMultiplier（每条相乘）；
##   target_vulnerability（破绽）→ 目标 incomingMultiplier；target_debuff（压制）→ XEnemy.xparam；heal_* → healingMultiplier；
##   lifesteal、on_kill、heal_overflow → 每次 apply 之后；battle_start → 开战；target_rate → XActor.sparam(0)；skill_cost → 技能消耗；
##   state_rate → 有害状态的附加几率；recast → 行动结束；attack_times → XActor.attack_times_add；extra_action → XActor.action_plus_set；
##   drop_rate、exp_gold → 奖励（全队相加，助力位也算）。
## 接法（各一行）：battle_logic 的 start／begin_action／after_apply／end_action／end_turn／finish、_skill_cost、state_rate、drop_chances、rewards、
## _calculate_damage（记这一击暴击没有，给「坚韧」）；actor.gd 的 param_rate／xparam／sparam／attack_times_add／action_plus_set；
## enemy.gd 的 xparam；actor_damage_hooks 的 capture。

## 开关（O-335）：false＝天启篇词条在战斗里没有任何效果（只显示在装备说明里）
static var ENABLED := true

const PARAM_KEYS := ["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"]
const XPARAM_INDEX := {"hit": 0, "eva": 1, "cri": 2, "hrg": 7, "mrg": 8}
const DEFAULT_TIER := 4
const DEATH_STATE := 1

## 这一击是不是暴击（battle_logic._calculate_damage 记、算完清；伤害钩子里拿不到 options）
static var crit_now := false


static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release())


# ---- 认装备、汇总 ----

## 装备实例上的天启篇词条 [{key, tier, grade, extra}…]
static func item_affixes(e) -> Array:
	var out := []
	if not (e is Dictionary):
		return out
	var list = e.get("tianqi_affixes", null)
	if list is Array:
		for x in list:
			if x is Dictionary:
				out.append(x)
	var m = e.get("qiyin", null)
	if m is Dictionary and m.get("affixes", null) is Array:
		for x in m.affixes:
			if x is Dictionary:
				var d: Dictionary = x.duplicate()
				d.tier = int(x.get("tier", DEFAULT_TIER))
				out.append(d)
	return out


static func _equips(a) -> Array:
	return (a as XActor).equip_list() if a is XActor else []


## 词条的汇总键：随机系、变体各自分开（元素增伤:fire、引敌／避敌:draw）
static func _key_of(x: Dictionary) -> String:
	var k := str(x.get("key", ""))
	var extra = x.get("extra", {})
	if extra is Dictionary:
		if extra.has("element"):
			k += ":" + str(extra.element)
		if extra.has("variant"):
			k += ":" + str(extra.variant)
	return k


## 按叠法把一串词条折成 {汇总键: 数值}。multiply 存的是乘数（两条 5% → 0.9025），其余存百分数。
## 光环带第二个数（暴怒的爆伤）另存 "<键>#2"。
static func fold(entries: Array) -> Dictionary:
	var p := {}
	for x in entries:
		var key := str(x.get("key", ""))
		var a := XTianqiAffixTable.affix(key)
		if a.is_empty():
			continue
		var tier := int(x.get("tier", DEFAULT_TIER))
		var grade := str(x.get("grade", "normal"))
		var v = XTianqiAffixTable.value(key, tier, grade)
		if v == null:
			continue
		var k := _key_of(x)
		match str(a.get("stack", "sum")):
			"multiply":
				p[k] = float(p.get(k, 1.0)) * maxf(0.0, 1.0 - float(v) / 100.0)
			"max_per_actor", "max_party":
				p[k] = maxf(float(p.get(k, 0.0)), float(v))
			_:
				p[k] = float(p.get(k, 0.0)) + float(v)
		var sv = XTianqiAffixTable.secondary_value(key, tier, grade)
		if sv != null:
			p[k + "#2"] = maxf(float(p.get(k + "#2", 0.0)), float(sv))
	return p


## 一人身上的词条（不含光环）
static func personal(a) -> Dictionary:
	var list := []
	for e in _equips(a):
		for x in item_affixes(e):
			if str(XTianqiAffixTable.affix(str(x.get("key", ""))).get("layer", "")) != "aura":
				list.append(x)
	return fold(list)


## 一人身上的光环
static func auras_of(a) -> Dictionary:
	var list := []
	for e in _equips(a):
		for x in item_affixes(e):
			if str(XTianqiAffixTable.affix(str(x.get("key", ""))).get("layer", "")) == "aura":
				list.append(x)
	return fold(list)


## 吃光环、算全队掉落阅历的人：出战栏上场格＋助力位（只取已建好的角色，不在这里新建）
static func members(s = null) -> Array:
	if s == null:
		s = XState.current
	var out := []
	if s == null:
		return out
	for i in range(mini(XTianqi.HELPER_SLOT + 1, s.battle_slots.size())):
		var id := int(s.battle_slots[i])
		if id > 0 and s.party.has(id) and s.actors.has(id):
			out.append(s.actors[id])
	return out


## 全队光环：同名取最高
static func party_aura(list: Array) -> Dictionary:
	var out := {}
	for m in list:
		var p := auras_of(m)
		for k in p:
			out[k] = maxf(float(out.get(k, 0.0)), float(p[k]))
	return out


## 全队相加的词条（物品掉落、阅历；助力位也算）
static func party_sum(list: Array, key: String) -> float:
	var n := 0.0
	for m in list:
		n += float(personal(m).get(key, 0.0))
	return n


## 由词条汇总算出的属性：{param: [8 个 %], xparam: {下标: 百分点}, crit_add: %}
static func derive(p: Dictionary, aura: Dictionary) -> Dictionary:
	var param := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var xp := {}
	var crit_add := 0.0
	for src in [p, aura]:
		for k in src:
			var ks := str(k)
			if ks.ends_with("#2"):
				if str(XTianqiAffixTable.affix(ks.trim_suffix("#2")).get("secondary", {}).get("pool", "")) == "crit_multiplier":
					crit_add += float(src[k])
				continue
			var a := XTianqiAffixTable.affix(ks.get_slice(":", 0))
			var pool := str(a.get("pool", ""))
			if not pool in ["stat", "xparam", "regen", "crit_multiplier"]:
				continue
			if pool == "crit_multiplier":
				crit_add += float(src[k])
				continue
			var stats: Array = a.get("stats", [a.get("stat", "")])
			for st in stats:
				if pool == "stat":
					var i := PARAM_KEYS.find(str(st))
					if i >= 0:
						param[i] += float(src[k])
				elif XPARAM_INDEX.has(str(st)):
					var j := int(XPARAM_INDEX[str(st)])
					xp[j] = float(xp.get(j, 0.0)) + float(src[k])
	return {"param": param, "xparam": xp, "crit_add": crit_add}


# ---- 本场数据 ----

static func _store(logic) -> Dictionary:
	if logic == null or not logic.has_meta("xaffix"):
		return {}
	return logic.get_meta("xaffix")


static func _active(logic) -> bool:
	return logic != null and logic.has_meta("xaffix")


static func _logic():
	return XAlienBattle.active_logic()


## 一人的词条视图 {p, aura, d, member}：战斗中按开战时缓存，战斗外现算
static func view(a) -> Dictionary:
	if not (a is XActor):
		return {}
	var st := _store(_logic())
	if not st.is_empty():
		if not st.views.has(a) or not _same_equips(st.views[a].eq, (a as XActor).equips):
			var member: bool = st.members.has(a)
			var p := personal(a)
			var aura: Dictionary = st.aura if member else {}
			st.views[a] = {"p": p, "aura": aura, "d": derive(p, aura), "member": member, "eq": (a as XActor).equips.duplicate()}
		return st.views[a]
	if not on():
		return {}
	var ms := members()
	var member := ms.has(a)
	var p := personal(a)
	var aura: Dictionary = party_aura(ms) if member else {}
	return {"p": p, "aura": aura, "d": derive(p, aura), "member": member}


## 战斗中换了装备（同一格换了实例）就重算这个人的视图（光环按开战时的全队算）
static func _same_equips(x: Array, y: Array) -> bool:
	if x.size() != y.size():
		return false
	for i in x.size():
		if not is_same(x[i], y[i]):
			return false
	return true


static func _pv(a, key: String) -> float:
	var v := view(a)
	return float(v.get("p", {}).get(key, 0.0)) if not v.is_empty() else 0.0


static func _unit(logic, b) -> Dictionary:
	var st := _store(logic)
	if not st.units.has(b):
		st.units[b] = {"first_turn": -1, "expose": 0.0, "expose_turns": 0, "suppress": 0.0, "suppress_turns": 0}
	return st.units[b]


## 开战（startBattle 之后，开场 TP 已掷）：建本场数据、开场护盾、初始 TP
static func start(logic) -> void:
	XTianqiAlienAffix.start(logic)  # 天启篇新异化词条（临终、再动、节俭、带毒）
	if logic.has_meta("xaffix"):
		logic.remove_meta("xaffix")
	if not on(logic.state):
		return
	var ms: Array = logic.actors.duplicate()
	for m in members(logic.state):
		if not ms.has(m):
			ms.append(m)
	logic.set_meta("xaffix", {"members": ms, "aura": party_aura(ms), "views": {}, "units": {}, "act": {}, "depth": 0})
	for a in logic.actors:
		if not (a is XActor) or not a.is_alive():
			continue
		var sh := _pv(a, "opening_shield")
		if sh > 0.0:
			a.add_shield(floorf(a.mhp * sh / 100.0))
		var tp := _pv(a, "initial_tp")
		if tp > 0.0:
			a.tp = minf(a.max_tp(), a.tp + tp)


static func finish(logic) -> void:
	XTianqiAlienAffix.finish(logic)
	if logic != null and logic.has_meta("xaffix"):
		logic.remove_meta("xaffix")


# ---- 面板（XActor／XEnemy 调） ----

static func param_rate(a, i: int) -> float:
	return _param_rate(a, i) * XTianqiAlienAffix.param_rate(a, i)  # 新异化词条「临终」：攻击、魔攻


static func _param_rate(a, i: int) -> float:
	if not ENABLED or not (a is XActor) or i < 0 or i > 7:
		return 1.0
	var v := view(a)
	if v.is_empty():
		return 1.0
	return maxf(0.0, 1.0 + float(v.d.param[i]) / 100.0)


static func xparam(a, i: int, value: float) -> float:
	if not ENABLED or not (a is XActor):
		return value
	var v := view(a)
	if v.is_empty():
		return value
	return value + float(v.d.xparam.get(i, 0.0)) / 100.0


## 被选为目标的几率（sparam 0）：引敌 ×(1＋%)、避敌 ×(1－%)
static func target_rate(a) -> float:
	if not ENABLED or not (a is XActor):
		return 1.0
	return maxf(0.0, (1.0 + _pv(a, "target_rate:draw") / 100.0) * (1.0 - _pv(a, "target_rate:avoid") / 100.0))


## 连击：攻击次数 +1（一人最多 +1）
static func attack_times(a) -> float:
	if not ENABLED or not (a is XActor):
		return 0.0
	return 1.0 if _pv(a, "combo") > 0.0 else 0.0


## 再动：追加一项行动几率（同名只取最高；追加出来的行动不会再掷，MV makeActionTimes 本来就只掷一轮）
static func action_plus_set(a, rates: Array) -> void:
	XTianqiAlienAffix.action_plus_set(a, rates)  # 新异化词条「再动」
	if not ENABLED or not (a is XActor):
		return
	var r := _pv(a, "reaction")
	if r > 0.0:
		rates.append(r / 100.0)


## 压制：敌人暴击率、闪避率减百分点（不低于 0）
static func enemy_xparam(e, i: int, value: float) -> float:
	if not ENABLED or not (i == 1 or i == 2):
		return value
	var logic = _logic()
	if not _active(logic) or not _store(logic).units.has(e):
		return value
	var u: Dictionary = _store(logic).units[e]
	if int(u.suppress_turns) <= 0:
		return value
	return maxf(0.0, value - float(u.suppress) / 100.0)


# ---- 伤害、治疗（XActorDamageHooks.capture 调；只做加和乘） ----

static func damage_ops(item: Dictionary, a, b) -> Array:
	return _damage_ops(item, a, b) + XTianqiAlienAffix.damage_ops(item, a, b)  # 新异化词条「再动」承伤、「节俭」受到的回复


static func _damage_ops(item: Dictionary, a, b) -> Array:
	var logic = _logic()
	if not _active(logic) or a == null or b == null:
		return []
	var ops := []
	var type := int(item.get("damage", {}).get("type", 0))
	if type == 3:
		var hm := 1.0
		if a is XActor:
			hm *= 1.0 + _pv(a, "heal_dealt") / 100.0
		if b is XActor:
			hm *= 1.0 + _pv(b, "heal_received") / 100.0
		if hm != 1.0:
			ops.append({"op": "mul", "field": "healingMultiplier", "value": hm})
		return ops
	if not type in [1, 5]:
		return ops
	var st := _store(logic)
	if a is XActor and not (b is XActor):
		var v := view(a)
		var p: Dictionary = v.p
		var fin := float(p.get("final_damage", 0.0))
		var f: Dictionary = st.act
		if not f.is_empty() and is_same(f.u, a) and bool(f.get("first", false)):
			fin += float(p.get("first_strike", 0.0))
		var ls: Dictionary = XTianqiAffixTable.affix("last_stand").get("condition", {})
		if p.has("last_stand") and a.mhp > 0.0 and a.hp < a.mhp * float(ls.get("rate", 30)) / 100.0:
			fin += float(p.last_stand)
		if p.has("headhunter") and _ranked(b):
			fin += float(p.headhunter)
		if fin != 0.0:
			ops.append({"op": "add", "field": "finalAdd", "value": fin / 100.0})
		if float(v.d.crit_add) != 0.0:
			ops.append({"op": "add", "field": "criticalAdd", "value": float(v.d.crit_add) / 100.0})
		if not a.is_attack(item) and float(p.get("skill_damage", 0.0)) != 0.0:
			ops.append({"op": "add", "field": "skillMultiplier", "value": float(p.skill_damage) / 100.0})
		for k in p:
			if str(k).begins_with("element_damage:"):
				var eid := element_id(str(k).get_slice(":", 1))
				if eid > 0:
					ops.append({"op": "add", "field": "elementAdd", "element": eid, "value": float(p[k]) / 100.0})
	if b is XActor:
		var m := _taken_mult(logic, item, a, b)
		if m != 1.0:
			ops.append({"op": "mul", "field": "incomingMultiplier", "value": m})
	else:
		var affix_expose := float(st.units[b].expose) if st.units.has(b) and int(st.units[b].expose_turns) > 0 else 0.0
		var total_expose := XTianqiElements.combined_exposure_pct(logic, b, affix_expose)
		if total_expose > 0.0:
			ops.append({"op": "mul", "field": "incomingMultiplier", "value": 1.0 + total_expose / 100.0})
	return ops


## 打到角色身上的承伤乘数：减伤、元素抗性（打来的系对得上）、磐石、不屈、坚韧（这一击暴击）、庇护光环，每条相乘
static func _taken_mult(_logic_ref, item: Dictionary, a, b) -> float:
	var v := view(b)
	if v.is_empty():
		return 1.0
	var p: Dictionary = v.p
	var m := float(p.get("damage_reduction", 1.0))
	var es: Array = XDamage.action_elements(item, a) if a != null else []
	for k in p:
		if str(k).begins_with("element_resist:") and es.has(element_id(str(k).get_slice(":", 1))):
			m *= float(p[k])
	if p.has("bulwark") and b.mhp > 0.0 and b.hp > b.mhp * float(XTianqiAffixTable.affix("bulwark").get("condition", {}).get("rate", 70)) / 100.0:
		m *= 1.0 - float(p.bulwark) / 100.0
	if p.has("unyielding") and b.mhp > 0.0 and b.hp < b.mhp * float(XTianqiAffixTable.affix("unyielding").get("condition", {}).get("rate", 30)) / 100.0:
		m *= 1.0 - float(p.unyielding) / 100.0
	if p.has("tenacity") and crit_now:
		m *= 1.0 - float(p.tenacity) / 100.0
	if v.aura.has("aura_shelter"):
		m *= 1.0 - float(v.aura.aura_shelter) / 100.0
	return maxf(0.0, m)


## 猎首的目标：神话（精英）敌人、首领
static func _ranked(b) -> bool:
	return b is XEnemy and (bool(b.elite) or bool(b.boss_difficulty_boss) or bool(XEnemy.boss_id(int(b.enemy_id))))


## 系键 → 属性号（表里 elements 的顺序就是数据库属性 1～9）
static func element_id(key: String) -> int:
	var els: Array = XTianqiAffixTable.data().get("elements", [])
	for i in els.size():
		if str(els[i].get("key", "")) == key:
			return i + 1
	return 0


# ---- 行动 ----

static func _is_damage(skill) -> bool:
	return skill is Dictionary and not skill.is_empty() and int(skill.get("damage", {}).get("type", 0)) in [1, 5]


## 行动开始：记先声（本回合第一次造成伤害的行动）、清本次行动的击杀与目标
static func begin_action(logic, u, skill: Dictionary) -> void:
	if not _active(logic):
		return
	var st := _store(logic)
	if int(st.depth) > 0:
		return
	var f := {"u": u, "skill": skill, "first": false, "harvested": false, "targets": [], "before": {}}
	st.act = f
	if u is XActor and _is_damage(skill) and _pv(u, "first_strike") > 0.0:
		var un := _unit(logic, u)
		if int(un.first_turn) != int(logic.turn):
			un.first_turn = int(logic.turn)
			f.first = true


static func before_apply(logic, u, _skill: Dictionary, t) -> void:
	if not _active(logic) or t == null:
		return
	var f: Dictionary = _store(logic).act
	if not f.is_empty() and is_same(f.u, u):
		f.before[t] = t.hp


## 每次 apply 之后：吸血、斩获、破绽、压制、回春
static func after_apply(logic, u, skill: Dictionary, t, r: Dictionary) -> void:
	XTianqiAlienAffix.after_apply(logic, u, skill, t, r)  # 新异化词条「带毒」
	if not _active(logic) or not (u is XActor) or t == null:
		return
	var st := _store(logic)
	var f: Dictionary = st.act
	var mine := not f.is_empty() and is_same(f.u, u)
	if mine and not f.targets.has(t):
		f.targets.append(t)
	var hit := not bool(r.get("missed", false)) and not bool(r.get("evaded", false))
	var dmg := float(r.get("hp", 0.0))
	var p: Dictionary = view(u).get("p", {})
	if p.is_empty():
		return
	if hit and dmg > 0.0 and not (t is XActor):
		var ls := float(p.get("lifesteal", 0.0))
		if ls > 0.0 and u.is_alive():
			var cap := float(XTianqiAffixTable.affix("lifesteal").get("cap_per_hit_mhp", 10))
			var heal := floorf(minf(dmg * ls / 100.0, u.mhp * cap / 100.0))
			u.hp = minf(u.mhp, u.hp + heal)
		if p.has("expose"):
			var tu := _unit(logic, t)
			tu.expose = maxf(float(tu.expose) if int(tu.expose_turns) > 0 else 0.0, float(p.expose))
			tu.expose_turns = int(XTianqiAffixTable.affix("expose").get("turns", 2))
		if p.has("suppress"):
			var tu := _unit(logic, t)
			tu.suppress = maxf(float(tu.suppress) if int(tu.suppress_turns) > 0 else 0.0, float(p.suppress))
			tu.suppress_turns = int(XTianqiAffixTable.affix("suppress").get("turns", 2))
			t.param_mark_dirty()
		if p.has("harvest") and mine and not bool(f.harvested) and t.is_dead() and float(f.before.get(t, 0.0)) > 0.0 and u.is_alive():
			f.harvested = true
			u.hp = minf(u.mhp, u.hp + floorf(u.mhp * float(p.harvest) / 100.0))
			u.mp = minf(u.mmp, u.mp + floorf(u.mmp * float(p.harvest) / 100.0))
	if dmg < 0.0 and t is XActor and p.has("rejuvenate") and mine and f.before.has(t):
		var overflow := -dmg - maxf(0.0, t.hp - float(f.before[t]))
		var cap := floorf(t.mhp * float(p.rejuvenate) / 100.0)
		var add := minf(overflow, maxf(0.0, cap - t.shield))
		if add > 0.0:
			t.add_shield(floorf(add))


## 行动结束：再释放（技能放完有几率对还活着的目标再放一次，不付费；再放出来的那次不会再触发）
static func end_action(logic, u, skill) -> Array:
	var logs := []
	if not _active(logic):
		return logs
	var st := _store(logic)
	var f: Dictionary = st.act
	st.act = {}
	if int(st.depth) > 0 or f.is_empty() or not is_same(f.u, u) or not (u is XActor) or not (skill is Dictionary) or skill.is_empty():
		return logs
	if u.is_attack(skill) or not u.is_alive():
		return logs
	var rc := _pv(u, "recast")
	if rc <= 0.0 or f.targets.is_empty():
		return logs
	if logic._float("tianqi_affix_recast") >= rc / 100.0:
		return logs
	st.depth = int(st.depth) + 1
	for t in f.targets:
		if t.is_alive():
			logs.append({"type": "action", "user": u, "skill": skill, "views": logic.views()})
			logs.append(logic.apply(u, skill, t))
	st.depth = int(st.depth) - 1
	return logs


## 回合结束：破绽、压制计时
static func end_turn(logic) -> void:
	XTianqiAlienAffix.end_turn(logic)  # 新异化词条：临终必死、带毒续毒
	if not _active(logic):
		return
	for b in _store(logic).units:
		var u: Dictionary = _store(logic).units[b]
		if int(u.expose_turns) > 0:
			u.expose_turns = int(u.expose_turns) - 1
		if int(u.suppress_turns) > 0:
			u.suppress_turns = int(u.suppress_turns) - 1
			if int(u.suppress_turns) == 0 and is_instance_valid(b):
				b.param_mark_dirty()


# ---- 消耗、异常、奖励 ----

## 技能消耗：全身合计最多 −cap_total%
static func cost(a, skill: Dictionary, c: Dictionary) -> Dictionary:
	return XTianqiAlienAffix.cost(a, skill, _cost(a, skill, c))  # 新异化词条「节俭」在别的减耗之后再乘


static func _cost(a, skill: Dictionary, c: Dictionary) -> Dictionary:
	if not ENABLED or not (a is XActor) or skill == null or skill.is_empty():
		return c
	var pct := minf(_pv(a, "skill_cost"), float(XTianqiAffixTable.affix("skill_cost").get("cap_total", 50)))
	if pct <= 0.0:
		return c
	var m := 1.0 - pct / 100.0
	return {"mp": maxi(0, floori(float(c.mp) * m)), "tp": maxi(0, floori(float(c.tp) * m))}


## 异常抵抗：角色被附加有害状态（不含战斗不能）的几率乘数
static func state_rate(b, id: int) -> float:
	if not ENABLED or not (b is XActor) or id == DEATH_STATE:
		return 1.0
	var m := _pv(b, "state_resist")
	if m == 0.0 or m == 1.0 or not XSmartAI.harmful_state(id):
		return 1.0
	return m


## 物品掉落：全队（上场＋助力位）相加
static func drop_mult(logic) -> float:
	var ms := _reward_members(logic)
	return 1.0 + party_sum(ms, "drop_rate") / 100.0 if not ms.is_empty() else 1.0


## 本场全队（开战时记的上场＋助力位）；本场数据已清时按出战栏现算
static func _reward_members(logic) -> Array:
	if _active(logic):
		return _store(logic).members
	if logic != null and on(logic.state):
		return members(logic.state)
	return []


## 阅历：经验、金钱 ×(1＋全队合计%)
static func rewards(logic, out: Dictionary) -> void:
	var pct := party_sum(_reward_members(logic), "exp_gold")
	if pct <= 0.0:
		return
	out.exp = int(floorf(float(out.exp) * (1.0 + pct / 100.0)))
	out.gold = int(floorf(float(out.gold) * (1.0 + pct / 100.0)))
