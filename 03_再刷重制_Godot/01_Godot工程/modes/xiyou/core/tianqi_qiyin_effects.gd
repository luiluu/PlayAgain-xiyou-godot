class_name XTianqiQiyinEffects
extends RefCounted
## 【cc·未经审查】天启篇「七印祭坛」装备的战斗效果：七套套装 2／3／5 件、13 把毕业武器的流派印记与独有效果、
## 真印追加、5 件神器的效果与代价（七印祭坛方案 v0.4 第 4.2、5.2、5.3、6.4 节；数据与参数一律读 XTianqiQiyinGear 的 qiyin_gear.json）。
##
## 生效条件：ENABLED（O-331）且是天启篇存档（XTianqi.active），发行构建另要 XTianqi.RELEASE_OPEN。原版档、关着时一条都不跑。
## 认装备：装备实例上的 qiyin 标记（与异化的 alien 标记同一种做法），由祭坛／掉落接入时用 mark() 打上：
##   套装件 {"kind": "set", "seal", "part", "true_seal"}；毕业武器 {"kind": "weapon", "seal", "key"（表里武器键）, "true_seal", "unique"（不立文字刻的那把武器的键）}；
##   神器 {"kind": "artifact", "key"}。专属武器刻印（方案 6.5 第 2 条）在专属武器上打 {"kind": "engrave", "key"}，只带独有效果。
## 叠加：同一个效果码在一人身上只生效一条（取第一条，和词条「同名只生效一条」一致）；判决按触发方式分开算（被攻击／攻击时）。
## 神器：全队同时只生效一件（出战顺序里第一个戴神器的人）。
##
## 接法（battle_logic 里各一行）：开战 start；行动 begin_action／plan_hits／end_action；每次 apply 前后 before_apply／after_apply；
## 连击段数 repeats；目标死了转段 redirect；扣血入口 hp_damage（替队友挡、免死）；回合开始 start_turn、回合结束 end_turn；
## 技能消耗 cost；暴击率 cri；复活 blocks_revive。伤害乘区走 XActorDamageHooks（damage_ops，只做加和乘），最大生命走 XActor.param_rate（param_rate）。
## 数值是占位（表头 draft），表里没有的手感参数集中在 TUNE。

## 开关（O-331）：false＝七印装备在战斗里没有任何效果（只是带词条的装备）
static var ENABLED := true

## 表里没有的参数（占位，数字避开 4）
const TUNE := {
	"aoe_scopes": [2, 3, 4, 5, 6],         # 群体技能：敌方全体、随机敌方 1～4 体（RPG Maker scope 号，不是设计数）
	"plague_crit_mult": 1.5,               # 「疫」暴击倍率
	"chain_max": 9,                        # 送行连斩最多连几次（防死循环）
	"sacrifice_min_hp_pct": 50,            # 以身饲虎：自己生命高于这个比例才献
	"star_elements": [2, 3, 5, 6, 7, 8, 9], # 落星随机的元素号（不含物理 1）
	"followup_max_per_action": 2,          # 补刀：一次队友行动最多跟几刀
	"silence_skill_id": 10777,             # 默印 5 件附带技能「万籁俱寂」的技能号（天启篇表外号段，skill_rework.json new_skills 按 6065 复制）
	"rift_rules": ["bai", "hong", "hei", "hui", "xun", "zhen", "mo"],  # 七印书卷能揭的里副本规则（键同印）
}
const ARTIFACT_ETYPE := 17

## 开关（O-426）：true＝默印 5 件在战斗技能列表里多出「万籁俱寂」（TUNE.silence_skill_id），放了就 use_silence_all；false＝不给
static var SILENCE_SKILL := true

## 七印书卷：开战揭的规则（只对敌方）。里副本规则由祭坛车道（cc/qiyin-altar）实现，读 enemy_only_rule(logic)。
## 免死对这个即死无效：死期（终焉规则）结算时由实现方把它置真、结算完置假。
static var doom_kill := false


# ---- 开关与认装备 ----

static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release())


static func mark_of(e) -> Dictionary:
	var m = e.get("qiyin", {}) if e is Dictionary else {}
	return m if m is Dictionary else {}


## 给装备实例打七印标记（掉落描述 {kind, seal, part|wtype, true_seal} 或直接给标记）。毕业武器按 seal＋wtype（类键或中文名）找武器键；
## 不立文字没给 unique 时用 rng 从另外 12 把里刻一条（rng 为空取第一把）。返回标记。
static func mark(inst: Dictionary, desc: Dictionary, rng: XRandomStream = null) -> Dictionary:
	var m := {"kind": str(desc.get("kind", "")), "seal": str(desc.get("seal", "")), "true_seal": bool(desc.get("true_seal", false))}
	match m.kind:
		"set":
			m.part = str(desc.get("part", ""))
		"weapon":
			var key := str(desc.get("key", ""))
			if key.is_empty():
				key = _weapon_key(m.seal, str(desc.get("wtype", "")))
			m.key = key
			if m.seal == "mo":
				var u := str(desc.get("unique", ""))
				if u.is_empty():
					var pool := unique_pool()
					u = str(pool[rng.next_int_inclusive(0, pool.size() - 1, "qiyin_unique")] if rng != null and not pool.is_empty() else (pool[0] if not pool.is_empty() else ""))
				m.unique = u
		"artifact", "engrave":
			m.key = str(desc.get("key", ""))
	inst.qiyin = m
	return m


## 不立文字能刻的独有效果：另外 12 把的键
static func unique_pool() -> Array:
	return XTianqiQiyinGear.weapons().filter(func(w): return str(w.get("seal", "")) != "mo").map(func(w): return str(w.key))


static func _weapon_key(seal: String, wtype: String) -> String:
	for w in XTianqiQiyinGear.weapons_of_seal(seal):
		if seal == "mo":
			return str(w.key)
		var t := str(w.get("type", ""))
		if t == wtype:
			return str(w.key)
		for wt in XTianqiQiyinGear.weapon_types():
			if str(wt.get("key", "")) == t and str(wt.get("name", "")) == wtype:
				return str(w.key)
	return ""


static func _equips(a) -> Array:
	if a == null or not (a is XActor):
		return []
	return (a as XActor).equip_list()


## 各印穿了几件套装件
static func set_counts(a) -> Dictionary:
	var out := {}
	for e in _equips(a):
		var m := mark_of(e)
		if str(m.get("kind", "")) == "set":
			out[str(m.seal)] = int(out.get(str(m.seal), 0)) + 1
	return out


## 一人身上的七印效果（不含神器；神器看全队，见 effects）：[{code, …参数, src}]，按套装（2→3→5）、武器（印记、真印追加、独有）、刻印的顺序
static func gear_effects(a) -> Array:
	var out := []
	var counts := set_counts(a)
	for seal in XTianqiQiyinGear.seal_keys():
		var n := int(counts.get(seal, 0))
		for c in [2, 3, 5]:
			if n >= c:
				for fx in XTianqiQiyinGear.set_bonus(seal, c):
					out.append(_tag(fx, "set:%s:%d" % [seal, c]))
	for e in _equips(a):
		var m := mark_of(e)
		match str(m.get("kind", "")):
			"weapon":
				var sc := XTianqiQiyinGear.school(str(m.seal))
				for fx in sc.get("mark", []):
					out.append(_tag(fx, "mark:" + str(m.seal)))
				if bool(m.get("true_seal", false)):
					for fx in sc.get("true_extra", []):
						out.append(_tag(fx, "true:" + str(m.seal)))
				var key := str(m.get("unique", "")) if str(m.seal) == "mo" else str(m.get("key", ""))
				for fx in XTianqiQiyinGear.weapon(key).get("effects", []):
					if str(fx.get("code", "")) != "random_unique":
						out.append(_tag(fx, "unique:" + key))
			"engrave":
				for fx in XTianqiQiyinGear.weapon(str(m.get("key", ""))).get("effects", []):
					if str(fx.get("code", "")) != "random_unique":
						out.append(_tag(fx, "engrave:" + str(m.key)))
	return out


static func artifact_key(a) -> String:
	for e in _equips(a):
		var m := mark_of(e)
		if str(m.get("kind", "")) == "artifact" or int(e.get("etypeId", 0)) == ARTIFACT_ETYPE and m.has("key"):
			return str(m.get("key", ""))
	return ""


static func _tag(fx: Dictionary, src: String) -> Dictionary:
	var d := fx.duplicate(true)
	d.erase("text")
	d.src = src
	return d


## 效果码 → 参数（同码只取第一条；判决按 trigger 拆成 judgment:on_hit／judgment:on_attack）
static func fold(list: Array) -> Dictionary:
	var out := {}
	for fx in list:
		var code := str(fx.get("code", ""))
		if code == "judgment":
			code += ":" + str(fx.get("trigger", "on_attack"))
		if not out.has(code):
			out[code] = fx
	return out


# ---- 战斗数据 ----

static func _store(logic) -> Dictionary:
	if logic == null:
		return {}
	if not logic.has_meta("xqiyin"):
		logic.set_meta("xqiyin", {"fx": {}, "artifact_owner": null, "units": {}, "act": {}, "logs": [], "scroll_rule": "", "scale": 1.0, "depth": 0})
	return logic.get_meta("xqiyin")


static func _unit(logic, b) -> Dictionary:
	var st := _store(logic)
	if not st.units.has(b):
		st.units[b] = {"plague": 0, "plague_turns": 0, "plague_src": null, "weights": 0, "kills": 0, "cheat_used": 0, "cheat_turns": 0,
			"last_element": -1, "switch": 0, "hits": 0, "burst": 0, "stars": 0, "pages": [], "resist_down": 0, "ward": 0,
			"lose_next": 0, "lose_used": false, "followups": 0, "extra_used": 0, "idle": false, "acted": 0, "double_armed": false,
			"silence_used": 0, "silenced": 0, "free_skill": 0}
	return st.units[b]


## 本场某人生效的效果（含全队那一件神器）
static func effects(logic, a) -> Dictionary:
	var st := _store(logic)
	if st.is_empty():
		return fold(gear_effects(a))
	if not st.fx.has(a):
		var list := gear_effects(a)
		if is_same(st.artifact_owner, a):
			var art := XTianqiQiyinGear.artifact(artifact_key(a))
			for fx in art.get("effects", []) + art.get("costs", []):
				list.append(_tag(fx, "artifact:" + str(art.get("key", ""))))
		st.fx[a] = fold(list)
	return st.fx[a]


static func _has(logic, a, code: String) -> bool:
	return a is XActor and effects(logic, a).has(code)


static func _p(logic, a, code: String) -> Dictionary:
	return effects(logic, a).get(code, {}) if a is XActor else {}


## 开战（startBattle 之后）：建本场数据、定全队那一件神器、七印书卷揭规则
static func start(logic) -> void:
	if logic.has_meta("xqiyin"):
		logic.remove_meta("xqiyin")
	if not on(logic.state):
		return
	var st := _store(logic)
	for a in logic.actors:
		if not artifact_key(a).is_empty():
			st.artifact_owner = a
			break
	var owner = st.artifact_owner
	if owner != null and _has(logic, owner, "reveal_rift_rule"):
		if XTianqiQiyinRule.scroll_exempt(logic):  # 天启四骑士、34～36 层首领：不揭、不付代价（O-425）
			st["scroll_exempt"] = true
			return
		var rules: Array = TUNE.rift_rules
		st.scroll_rule = str(rules[int(logic._int(0, rules.size() - 1, "qiyin_scroll"))])


## 战斗结束：清本场数据（之后的面板、预览不再读到本场的层数）
static func finish(logic) -> void:
	if logic != null and logic.has_meta("xqiyin"):
		logic.remove_meta("xqiyin")


## 七印书卷揭开的里副本规则（对敌方和佩戴者生效，见 XTianqiQiyinRule）；没有为空
static func enemy_only_rule(logic) -> String:
	return str(_store(logic).get("scroll_rule", "")) if logic != null and logic.has_meta("xqiyin") else ""


## 七印书卷这场被豁免了（有天启四骑士或 34～36 层首领）
static func scroll_exempted(logic) -> bool:
	return logic != null and logic.has_meta("xqiyin") and bool(_store(logic).get("scroll_exempt", false))


## 本场生效的那件神器的佩戴者（没有为 null）
static func artifact_owner(logic):
	return _store(logic).get("artifact_owner") if logic != null and logic.has_meta("xqiyin") else null


static func _active(logic) -> bool:
	return logic != null and logic.has_meta("xqiyin")


# ---- 回合 ----

## 回合开始（_make_action_orders 之后）：砝码、震印 5 件计数、少动一次、本回合计数清零
static func start_turn(logic) -> void:
	if not _active(logic):
		return
	for a in logic.actors:
		if not a.is_alive():
			continue
		var u := _unit(logic, a)
		u.followups = 0
		u.extra_used = 0
		var w := _p(logic, a, "weight_stack")
		if not w.is_empty():
			u.weights = mini(int(w.max_stacks), int(u.weights) + int(w.per_turn) + (int(w.on_guard) if bool(u.idle) else 0))
		var d := _p(logic, a, "skill_double_cast")
		if not d.is_empty() and int(logic.turn) % maxi(1, int(d.every_turns)) == 0:
			u.double_armed = true
	for e in logic.enemies:
		var u := _unit(logic, e)
		if int(u.lose_next) > 0 and logic.current_order.has(e):
			logic.current_order.erase(e)
			u.lose_next = int(u.lose_next) - 1


## 回合结束（各人 onTurnEnd 之后）：疫结算（含白印 5 件再结算、传染）、免死后加伤与庇护、元素抗性降低倒数、防御记「上回合没出手」
static func end_turn(logic) -> Array:
	var logs := []
	if not _active(logic):
		return logs
	var spread := []
	for e in logic.enemies:
		var u := _unit(logic, e)
		if int(u.plague) <= 0 or not e.is_alive():
			continue
		var src = u.plague_src
		var times := 1 + (int(_p(logic, src, "dot_extra_tick").get("times", 0)) if src != null else 0)
		for i in times:
			if e.is_alive():
				_lose_hp(logic, e, plague_tick(logic, src, e, int(u.plague)), logs)
		if src != null and _has(logic, src, "plague_spread"):
			spread.append([e, src, int(_p(logic, src, "plague_spread").per_turn)])
		u.plague_turns = int(u.plague_turns) - 1
		if int(u.plague_turns) <= 0:
			u.plague = 0
			u.plague_src = null
	for row in spread:
		var i: int = logic.enemies.find(row[0])
		for j in [i - 1, i + 1]:
			if j >= 0 and j < logic.enemies.size() and logic.enemies[j].is_alive():
				add_plague(logic, row[1], logic.enemies[j], int(row[2]))
	for b in logic.actors + logic.enemies:
		var u := _unit(logic, b)
		for k in ["cheat_turns", "resist_down", "ward", "silenced", "free_skill"]:
			u[k] = maxi(0, int(u[k]) - 1)
		if b in logic.actors:
			u.idle = b.is_alive() and int(u.acted) == 0  # 防御、没出手都不进 begin_action（只有 execute 才进），算「上回合没出手」
			u.acted = 0
	return logs


## 一次疫的伤害：攻击者物攻 × atk_pct% × 层数 × 白印 2 件；真印「疫」可以暴击
static func plague_tick(logic, src, _t, stacks: int) -> float:
	if src == null:
		return 0.0
	var p := _p(logic, src, "plague_stack")
	var v: float = float(src.atk) * float(p.get("atk_pct", 0)) / 100.0 * stacks
	v *= 1.0 + float(_p(logic, src, "dot_dealt_pct").get("value", 0)) / 100.0
	if _has(logic, src, "plague_can_crit") and logic._float("qiyin_plague_crit") < clampf(float(src.cri), 0.0, 1.0):
		v *= float(TUNE.plague_crit_mult)
	return floorf(v)


static func add_plague(logic, src, t, n: int) -> void:
	var p := _p(logic, src, "plague_stack")
	if p.is_empty() or n <= 0 or not t.is_alive():
		return
	var u := _unit(logic, t)
	u.plague = mini(int(p.max_stacks), int(u.plague) + n)
	u.plague_turns = int(p.turns)
	u.plague_src = src


static func plague_of(logic, t) -> int:
	return int(_unit(logic, t).plague) if _active(logic) else 0


# ---- 行动 ----

## 行动开始（付费之后、选目标之前）：建行动帧；用掉砝码、倾囊一枪的魔法、震印换系层、以身饲虎、蓄势
static func begin_action(logic, u, skill: Dictionary) -> void:
	if not _active(logic):
		return
	var st := _store(logic)
	if int(st.depth) > 0:
		return
	var damage := _is_damage(skill)
	var f := {"u": u, "skill": skill, "hits": 0, "per_target": {}, "planned": 1, "weight": 0, "mp_bonus": 0.0, "idle": false,
		"judged": {}, "star": false, "killed": [], "targets": [], "sacrifice": false, "double": false, "hit_on_holder": {}}
	st.act = f
	if not (u is XActor) or not u.is_alive():
		return
	var un := _unit(logic, u)
	un.acted = int(un.acted) + 1
	if is_silence_skill(skill) and use_silence_all(logic, u):  # 默印 5 件附带技能
		st.logs.append({"type": "battle_text", "text": "万籁俱寂：敌方全体沉默，我方下一回合技能不耗魔法和 TP。"})
	if not damage:
		return
	if _has(logic, u, "weight_stack") and int(un.weights) > 0:
		f.weight = int(un.weights)
		un.weights = 0
	var dump := _p(logic, u, "mp_dump")
	if not dump.is_empty() and float(u.mp) > 0.0 and float(u.mmp) > 0.0:
		f.mp_bonus = floorf(float(u.mp) / float(u.mmp) * 100.0 / float(dump.per_mp_pct)) * float(dump.dmg_pct) / 100.0
		u.mp = 0.0
	if _has(logic, u, "idle_charge") and bool(un.idle):
		f.idle = true
	if _has(logic, u, "element_switch_stack"):
		var es := _elements(skill, u)
		var e := int(es[0]) if not es.is_empty() else 0
		var sw := _p(logic, u, "element_switch_stack")
		if e > 1:
			un.switch = mini(int(sw.max_stacks), int(un.switch) + 1) if int(un.last_element) > 1 and int(un.last_element) != e else 0
			un.last_element = e
	var sac := _p(logic, u, "sacrifice_hp")
	if not sac.is_empty() and u.hp > u.mhp * float(TUNE.sacrifice_min_hp_pct) / 100.0:
		var cost := floorf(u.hp * float(sac.hp_pct) / 100.0)
		if cost > 0.0:
			u.hp -= cost
			f.sacrifice = true
			var low = _lowest(logic.actors)
			if low != null:
				low.add_shield(cost)
	if bool(un.double_armed) and not u.is_attack(skill):
		un.double_armed = false
		f.double = true


## 非连段序列的段数（每个目标）：战流派攻击次数 +1；最后一段记给大刀阔斧
static func repeats(logic, u, skill: Dictionary, n: int) -> int:
	if not _active(logic) or not (u is XActor) or not _is_damage(skill) or int(_store(logic).depth) > 0:
		return n
	n += int(_p(logic, u, "extra_hits").get("value", 0))
	_store(logic).act.planned = maxi(1, n)
	return n


## 目标死了还剩段：战真印把剩下的段转给另一个活着的敌人；没有返回 null
static func redirect(logic, u, skill: Dictionary, dead):
	if not _active(logic) or not _has(logic, u, "overflow_hits_redirect") or not (dead is XEnemy):
		return null
	var alive: Array = logic.enemies.filter(func(e): return e.is_alive() and not is_same(e, dead))
	return alive[0] if not alive.is_empty() else null


static func before_apply(logic, u, skill: Dictionary, t) -> void:
	if not _active(logic):
		return
	var f: Dictionary = _store(logic).act
	if f.is_empty() or not is_same(f.u, u):
		return
	f.cur_hp = t.hp


## 每次 apply 之后：段数、疫、判决、落星、击杀记录、补疫穿透、处决、普攻回血、默印 3 件庇护
static func after_apply(logic, u, skill: Dictionary, t, r: Dictionary) -> void:
	if not _active(logic) or u == null or t == null:
		return
	var st := _store(logic)
	var f: Dictionary = st.act
	var hit := not bool(r.get("missed", false)) and not bool(r.get("evaded", false))
	var hp_dmg := float(r.get("hp", 0.0))
	# 被攻击时的判决（殉印 5 件）：敌人这次行动打中持有者，反击一次
	if u is XEnemy and t is XActor and hit and hp_dmg > 0.0 and _has(logic, t, "judgment:on_hit") and t.is_alive():
		if not f.is_empty() and not f.hit_on_holder.has(t):
			f.hit_on_holder[t] = true
			_lose_hp(logic, u, floorf(t.mhp * float(_p(logic, t, "judgment:on_hit").max_hp_pct) / 100.0), st.logs)
	if not (u is XActor) or f.is_empty() or not is_same(f.u, u):
		return
	if t is XActor:
		if hit and _has(logic, u, "support_ally_dmg_taken_pct") and not is_same(t, u) and (int(skill.get("damage", {}).get("type", 0)) == 3 or _adds_buff(skill)):
			_unit(logic, t).ward = int(_p(logic, u, "support_ally_dmg_taken_pct").turns) + 1
		return
	if not hit or not _is_damage(skill):
		return
	f.hits = int(f.hits) + 1
	f.per_target[t] = int(f.per_target.get(t, 0)) + 1
	if not f.targets.has(t):
		f.targets.append(t)
	var un := _unit(logic, u)
	un.hits = int(un.hits) + 1
	var burst := _p(logic, u, "hit_count_burst")
	if not burst.is_empty() and int(un.hits) % int(burst.every_hits) == 0:
		un.burst = int(un.burst) + 1
	var tu := _unit(logic, t)
	# 疫：满层时白虹贯日穿到下一个敌人，带过去一半
	if _has(logic, u, "plague_stack"):
		var pierce := _p(logic, u, "plague_pierce")
		if not pierce.is_empty() and int(tu.plague) >= int(pierce.at_stacks):
			var nx = _next_enemy(logic, t)
			if nx != null:
				add_plague(logic, u, nx, int(floorf(int(tu.plague) * float(pierce.carry_pct) / 100.0)))
		add_plague(logic, u, t, int(_p(logic, u, "plague_stack").per_hit))
	# 攻击时的判决（殉流派）：每次行动对每个目标一次
	var jp := _p(logic, u, "judgment:on_attack")
	if not jp.is_empty() and not f.judged.has(t) and t.is_alive():
		f.judged[t] = true
		_lose_hp(logic, t, judgment_value(logic, u, f), st.logs)
	# 落星（震流派）：每次行动掷一次
	var star := _p(logic, u, "star_fall")
	if not star.is_empty() and not bool(f.star) and hp_dmg > 0.0 and not u.is_attack(skill):
		f.star = true
		if logic._float("qiyin_star") < float(star.chance_pct) / 100.0:
			_star_fall(logic, u, hp_dmg * float(star.dmg_pct) / 100.0)
	# 一力降十会：蓄势这一击让目标下回合少动一次（每个目标每场一次）
	if bool(f.idle) and _has(logic, u, "target_lose_action") and not bool(tu.lose_used) and t.is_alive():
		tu.lose_used = true
		tu.lose_next = int(tu.lose_next) + int(_p(logic, u, "target_lose_action").get("count", 1))
	# 灰镰：普通敌人低于线直接处决
	var ex := _p(logic, u, "execute_normal")
	if not ex.is_empty() and t.is_alive() and not XBossStatus.is_boss(t) and t.hp < t.mhp * float(ex.below_pct) / 100.0:
		_lose_hp(logic, t, t.hp, st.logs)
	# 无字：普攻后给生命最低的队友回这次伤害的一成
	var heal := _p(logic, u, "normal_attack_heal_lowest")
	if not heal.is_empty() and u.is_attack(skill) and hp_dmg > 0.0:
		var low = _lowest(logic.actors)
		if low != null:
			logic.gain_hp(low, floorf(hp_dmg * float(heal.heal_pct) / 100.0 * heal_mult(logic, u, low)))
	if t.is_dead() and not f.killed.has(t):
		f.killed.append(t)
		f.overflow = maxf(0.0, float(r.get("state_value", 0.0)) - float(f.get("cur_hp", 0.0)))


## 判决：最大生命 × max_hp_pct%（＋当头棒喝按已损生命加），生命高于线 ×（殉真印），以身饲虎这次 ×
static func judgment_value(logic, u, f: Dictionary) -> float:
	var pct := float(_p(logic, u, "judgment:on_attack").get("max_hp_pct", 0))
	var ramp := _p(logic, u, "judgment_lost_hp_ramp")
	if not ramp.is_empty() and u.mhp > 0.0:
		pct += floorf((1.0 - u.hp / u.mhp) * 100.0 / float(ramp.per_lost_pct)) * float(ramp.add_max_hp_pct)
	var v: float = u.mhp * pct / 100.0
	var high := _p(logic, u, "judgment_mult_high_hp")
	if not high.is_empty() and u.hp > u.mhp * float(high.above_pct) / 100.0:
		v *= float(high.mult)
	if bool(f.get("sacrifice", false)):
		v *= float(_p(logic, u, "sacrifice_hp").get("judgment_mult", 1))
	return floorf(v)


## 落星：敌方全体，随机元素（真印打弱点系），危楼每第 n＋1 颗换陨月，天书集页
static func _star_fall(logic, u, base: float) -> void:
	var st := _store(logic)
	var un := _unit(logic, u)
	un.stars = int(un.stars) + 1
	var moon := _p(logic, u, "star_moon")
	if not moon.is_empty() and int(un.stars) % (int(moon.every_stars) + 1) == 0:
		base *= float(moon.mult)
	var els: Array = TUNE.star_elements
	var e := int(els[int(logic._int(0, els.size() - 1, "qiyin_star_element"))])
	var weak := _has(logic, u, "star_fall_weakness")
	var targets: Array = logic.enemies.filter(func(x): return x.is_alive())
	for t in targets:
		var ee := e
		if weak:
			ee = _weakest(t, els)
		_lose_hp(logic, t, floorf(base * maxf(0.0, t.element_rate(ee))), st.logs)
	var pages := _p(logic, u, "star_pages")
	if not pages.is_empty():
		if not un.pages.has(e):
			un.pages.append(e)
		if un.pages.size() >= int(pages.kinds):
			un.pages = []
			for t in logic.enemies:
				_unit(logic, t).resist_down = int(pages.turns) + 1


static func _weakest(t, els: Array) -> int:
	var best := int(els[0])
	for e in els:
		if t.element_rate(int(e)) > t.element_rate(best):
			best = int(e)
	return best


## 行动结束（act 收尾）：击倒后再动、连斩、溢出、攒段横扫、弓与冠再射、震印放两次、补刀
static func end_action(logic, u, skill) -> Array:
	var logs := []
	if not _active(logic):
		return logs
	var st := _store(logic)
	var f: Dictionary = st.act
	st.act = {}
	if f.is_empty() or not is_same(f.u, u) or not (u is XActor) or skill == null or skill.is_empty():
		logs.append_array(take_logs(logic))
		return logs
	var un := _unit(logic, u)
	st.depth = int(st.depth) + 1
	# 击倒相关
	if not f.killed.is_empty() and u.is_alive():
		un.kills = int(un.kills) + f.killed.size()
		if _has(logic, u, "overkill_carry") and float(f.get("overflow", 0.0)) > 0.0:
			var nx = _next_enemy(logic, f.killed[-1])
			if nx != null:
				_lose_hp(logic, nx, floorf(float(f.overflow)), st.logs)
		var chain := _p(logic, u, "kill_chain_slash")
		if not chain.is_empty():
			var n := 0
			var again := true
			while again and n < int(TUNE.chain_max) and u.is_alive():
				var nx = _random_enemy(logic)
				if nx == null:
					break
				n += 1
				logs.append_array(_derived(logic, u, u.attack_skill(), nx, float(chain.dmg_pct) / 100.0))
				again = bool(chain.get("chain", false)) and nx.is_dead()
	# 攒段横扫
	if int(un.burst) > 0 and _has(logic, u, "hit_count_burst") and u.is_alive():
		var b := _p(logic, u, "hit_count_burst")
		un.burst = int(un.burst) - 1
		for e in logic.enemies.filter(func(x): return x.is_alive()):
			for i in int(b.bonus_hits):
				if e.is_dead():
					break
				logs.append_array(_derived(logic, u, u.attack_skill(), e, 1.0))
	# 弓与冠：单体技能再射一次
	var rep := _p(logic, u, "single_skill_repeat")
	if not rep.is_empty() and int(skill.get("scope", 0)) == 1 and not u.is_attack(skill) and _is_damage(skill) and not f.targets.is_empty():
		if logic._float("qiyin_repeat") < float(rep.chance_pct) / 100.0:
			var t = f.targets[0] if f.targets[0].is_alive() else _random_enemy(logic)
			if t != null:
				logs.append_array(_derived(logic, u, skill, t, float(rep.dmg_pct) / 100.0))
	# 震印 5 件：这个技能再放一次（不付费）
	if bool(f.double) and u.is_alive():
		for t in f.targets:
			if t.is_alive():
				logs.append_array(_derived(logic, u, skill, t, 1.0))
	st.depth = int(st.depth) - 1
	# 击倒后再行动一次（红印 5 件、灰真印、夺和大刀；同名只算一条，每回合 per_turn 次）
	var ka := _p(logic, u, "kill_extra_action")
	if not ka.is_empty() and not f.killed.is_empty() and u.is_alive() and int(un.extra_used) < int(ka.per_turn):
		un.extra_used = int(un.extra_used) + 1
		logic.current_order.push_front(u)
	# 补刀：队友这次行动打到的目标低于线，持有者追一刀
	for h in logic.actors:
		if is_same(h, u) or not h.is_alive() or not h.can_move():
			continue
		var fu := _p(logic, h, "ally_followup_execute")
		if fu.is_empty():
			continue
		var hu := _unit(logic, h)
		var n := 0
		for t in f.targets:
			if int(hu.followups) >= int(fu.per_turn) or n >= int(TUNE.followup_max_per_action):
				break
			if t.is_alive() and t.hp < t.mhp * float(fu.below_pct) / 100.0:
				hu.followups = int(hu.followups) + 1
				n += 1
				st.depth = int(st.depth) + 1
				logs.append_array(_derived(logic, h, h.attack_skill(), t, 1.0))
				st.depth = int(st.depth) - 1
	logs.append_array(take_logs(logic))
	return logs


## 派生的一击（连斩、横扫、再射、放两次、补刀）：直接 apply，伤害 × scale，不付费、不再触发派生
static func _derived(logic, u, skill: Dictionary, t, scale: float) -> Array:
	var st := _store(logic)
	var prev := float(st.scale)
	var prev_act: Dictionary = st.act
	st.scale = scale
	st.act = {"u": u, "skill": skill, "hits": 0, "per_target": {}, "planned": 1, "weight": 0, "mp_bonus": 0.0, "idle": false,
		"judged": {}, "star": true, "killed": [], "targets": [], "sacrifice": false, "double": false, "hit_on_holder": {}, "derived": true}
	var r: Dictionary = logic.apply(u, skill, t)
	st.act = prev_act
	st.scale = prev
	return [{"type": "action", "user": u, "skill": skill, "views": logic.views()}, r]


static func take_logs(logic) -> Array:
	if not _active(logic):
		return []
	var st := _store(logic)
	var out: Array = st.logs
	st.logs = []
	return out


# ---- 伤害乘区（XActorDamageHooks.capture 调；只做加和乘） ----

static func damage_ops(item: Dictionary, a, b) -> Array:
	var logic = XAlienBattle.active_logic()
	if not _active(logic) or a == null or b == null:
		return []
	var ops := []
	var type := int(item.get("damage", {}).get("type", 0))
	if type == 3:
		var hm := heal_mult(logic, a, b)
		if hm != 1.0:
			ops.append({"op": "mul", "field": "healingMultiplier", "value": hm})
		return ops
	if not type in [1, 5]:
		return ops
	var st := _store(logic)
	var mult := 1.0
	if a is XActor and b is XEnemy:
		var f: Dictionary = st.act if not st.act.is_empty() and is_same(st.act.u, a) else {}
		mult *= float(st.scale)
		var attack: bool = a.is_attack(item)
		var skillish := not attack or _has(logic, a, "normal_attack_as_skill")
		var es := _elements(item, a)
		var elemental := es.any(func(e): return int(e) > 1)
		var un := _unit(logic, a)
		var bu := _unit(logic, b)
		var lost_b: float = 1.0 - b.hp / b.mhp if b.mhp > 0.0 else 0.0
		mult *= 1.0 + minf(float(_p(logic, a, "dmg_per_target_debuff_pct").get("max", 0)), debuff_count(logic, b) * float(_p(logic, a, "dmg_per_target_debuff_pct").get("value", 0))) / 100.0
		if int(item.get("scope", 0)) in TUNE.aoe_scopes and skillish:
			mult *= 1.0 + float(_p(logic, a, "aoe_skill_dmg_pct").get("value", 0)) / 100.0
		var ks := _p(logic, a, "kill_stack_dmg_pct")
		if not ks.is_empty():
			mult *= 1.0 + mini(int(un.kills), int(ks.max_stacks)) * float(ks.value) / 100.0
		if not f.is_empty() and int(f.weight) > 0:
			mult *= 1.0 + int(f.weight) * float(_p(logic, a, "weight_stack").per_stack_pct) / 100.0
			var full := _p(logic, a, "weight_full_crit")
			if not full.is_empty() and int(f.weight) >= int(full.stacks):
				ops.append({"op": "add", "field": "criticalAdd", "value": float(full.crit_dmg_pct) / 100.0})
		var lt := _p(logic, a, "low_hp_target_dmg_pct")
		if not lt.is_empty() and b.hp < b.mhp * float(lt.below_pct) / 100.0:
			mult *= 1.0 + float(lt.value) / 100.0
		var ls := _p(logic, a, "low_self_hp_dmg_pct")
		if not ls.is_empty() and a.mhp > 0.0:
			mult *= 1.0 + float(ls.max) / 100.0 * clampf(1.0 - a.hp / a.mhp, 0.0, 1.0)
		if int(un.cheat_turns) > 0:
			mult *= 1.0 + float(_p(logic, a, "cheat_death").get("dmg_pct", 0)) / 100.0
		if elemental:
			mult *= 1.0 + float(_p(logic, a, "element_dmg_pct").get("value", 0)) / 100.0
			mult *= 1.0 + int(un.switch) * float(_p(logic, a, "element_switch_stack").get("per_stack_pct", 0)) / 100.0
			if int(bu.resist_down) > 0:
				ops.append({"op": "mul", "field": "incomingMultiplier", "value": 1.0 - float(_p_any(logic, "star_pages").get("value", 0)) / 100.0})
		var sa := _p(logic, a, "single_action_dmg_pct")
		if not sa.is_empty() and not f.is_empty() and not f.has("derived") and int(un.acted) <= 1 and not logic.current_order.has(a):
			mult *= 1.0 + float(sa.value) / 100.0
		var er := _p(logic, a, "execute_ramp")
		if not er.is_empty():
			mult *= 1.0 + floorf(lost_b * 100.0 / float(er.per_lost_pct)) * float(er.value) / 100.0
		if skillish:
			mult *= 1.0 + float(_p(logic, a, "skill_dmg_pct").get("value", 0)) / 100.0
		var bl := _p(logic, a, "boss_low_hp_dmg_pct")
		if not bl.is_empty() and XBossStatus.is_boss(b) and b.hp < b.mhp * float(bl.below_pct) / 100.0:
			mult *= 1.0 + float(bl.value) / 100.0
		if not f.is_empty():
			mult *= 1.0 + float(f.mp_bonus)
			if bool(f.idle):
				mult *= 1.0 + float(_p(logic, a, "idle_charge").get("dmg_pct", 0)) / 100.0
			var idx := int(f.per_target.get(b, 0))
			mult *= 1.0 + int(f.hits) * float(_p(logic, a, "combo_hit_ramp_pct").get("value", 0)) / 100.0
			var lh := _p(logic, a, "last_hit_mult")
			if not lh.is_empty() and idx == int(f.planned) - 1:
				mult *= float(lh.mult)
		if attack and not a.traits_set(XBattler.TRAIT_STYPE_SEAL).is_empty():
			mult *= 1.0 + float(_p(logic, a, "silenced_normal_attack_dmg_pct").get("value", 0)) / 100.0
		var ig := _p(logic, a, "ignore_def_pct")
		if not ig.is_empty():
			var keep := 1.0 - float(ig.value) / 100.0
			ops.append({"op": "mul", "field": "physicalDefenseRate", "value": keep})
			ops.append({"op": "mul", "field": "magicalDefenseRate", "value": keep})
	if b is XActor:
		mult *= 1.0 + float(_p(logic, b, "dmg_taken_pct").get("value", 0)) / 100.0
		if int(_unit(logic, b).ward) > 0:
			mult *= 1.0 + float(_p_any(logic, "support_ally_dmg_taken_pct").get("value", 0)) / 100.0
	if mult != 1.0:
		ops.append({"op": "mul", "field": "finalMultiplier", "value": mult})
	return ops


## 治疗倍率：施放者默印 2 件；目标弓与冠代价、病从口入满疫
static func heal_mult(logic, a, b) -> float:
	var m := 1.0
	if a is XActor:
		m *= 1.0 + float(_p(logic, a, "heal_shield_pct").get("value", 0)) / 100.0
	if b is XActor:
		m *= 1.0 + float(_p(logic, b, "heal_taken_pct").get("value", 0)) / 100.0
	if b is XEnemy and int(_unit(logic, b).plague) > 0:
		var src = _unit(logic, b).plague_src
		var fp := _p(logic, src, "full_plague_heal_taken_pct") if src != null else {}
		if not fp.is_empty() and int(_unit(logic, b).plague) >= int(_p(logic, src, "plague_stack").get("max_stacks", 10)):
			m *= 1.0 + float(fp.value) / 100.0
	return maxf(0.0, m)


## 全队里谁有这个效果就取谁的参数（庇护、元素抗性降低这类挂在目标身上的）
static func _p_any(logic, code: String) -> Dictionary:
	for a in logic.actors:
		var p := _p(logic, a, code)
		if not p.is_empty():
			return p
	return {}


## 目标身上的减益种数（占位口径）：能力减益每项一种，疫一种，元素抗性降低一种，少动一次一种
static func debuff_count(logic, b) -> int:
	var n := 0
	for lv in b.buffs:
		if int(lv) < 0:
			n += 1
	var u := _unit(logic, b)
	for k in ["plague", "resist_down", "lose_next"]:
		if int(u[k]) > 0:
			n += 1
	return n


# ---- 扣血、消耗、暴击、复活 ----

## executeHpDamage 最外层：殉印 3 件替生命最低的队友挡一半；灰印 5 件免死（死期无效）
static func hp_damage(logic, u, t, value: float) -> float:
	if not _active(logic) or value <= 0.0 or not (t is XActor) or not t.is_alive():
		return value
	var st := _store(logic)
	if int(st.get("guarding", 0)) == 0:
		var low = _lowest(logic.actors)
		if is_same(low, t):
			for g in logic.actors:
				var gp := _p(logic, g, "guard_lowest_ally")
				if not is_same(g, t) and g.is_alive() and not gp.is_empty():
					var share := floorf(value * float(gp.share_pct) / 100.0)
					st.guarding = 1
					_lose_hp(logic, g, share, st.logs)
					st.guarding = 0
					value -= share
					break
	var cd := _p(logic, t, "cheat_death")
	var un := _unit(logic, t)
	if not cd.is_empty() and not doom_kill and int(un.cheat_used) < int(cd.per_battle) and value >= t.hp + t.shield and not XTianqiDeathAlien.breaks_saves(logic):  # 骑士队长：保命失效
		un.cheat_used = int(un.cheat_used) + 1
		un.cheat_turns = int(cd.turns) + 1
		value = maxf(0.0, t.hp + t.shield - float(cd.hp))
	return value


## 技能消耗倍率（黑印 2 件 −15%、天平 ×2）
static func cost_mult(a, skill: Dictionary) -> float:
	var logic = XAlienBattle.active_logic()
	if not (a is XActor) or not on():
		return 1.0
	var fx: Dictionary = effects(logic if _active(logic) else null, a)
	var m := 1.0 + float(fx.get("skill_cost_pct", {}).get("value", 0)) / 100.0
	m *= float(fx.get("skill_cost_mult", {}).get("mult", 1.0))
	if _active(logic) and int(_unit(logic, a).free_skill) > 0:
		m = 0.0
	return maxf(0.0, m)


static func cost(a, skill: Dictionary, c: Dictionary) -> Dictionary:
	var m := cost_mult(a, skill)
	if m == 1.0:
		return c
	return {"mp": maxi(0, floori(float(c.mp) * m)), "tp": maxi(0, floori(float(c.tp) * m))}


## 暴击率：黑印 5 件一次用掉 5 层必定暴击
static func cri(logic, u, cri_rate: float) -> float:
	if not _active(logic) or not (u is XActor):
		return cri_rate
	var f: Dictionary = _store(logic).act
	var full := _p(logic, u, "weight_full_crit")
	if not f.is_empty() and is_same(f.u, u) and not full.is_empty() and int(f.weight) >= int(full.stacks):
		return 1.0
	return cri_rate


## 灰镰代价：佩戴者不能被复活
static func blocks_revive(b) -> bool:
	var logic = XAlienBattle.active_logic()
	return _active(logic) and b is XActor and _has(logic, b, "no_revive")


## 最大生命倍率（殉印 2 件），XActor.param_rate 用；不在战斗中也算（按身上的套装）
static func param_rate(a, i: int) -> float:
	if i != 0 or not ENABLED or not (a is XActor):
		return 1.0
	var counts := set_counts(a)
	if counts.is_empty() or not on():
		return 1.0
	for seal in counts:
		for c in [2, 3, 5]:
			if int(counts[seal]) >= c:
				for fx in XTianqiQiyinGear.set_bonus(seal, c):
					if str(fx.get("code", "")) == "max_hp_pct":
						return 1.0 + float(fx.value) / 100.0
	return 1.0


static func is_silence_skill(skill) -> bool:
	return SILENCE_SKILL and skill is Dictionary and int(TUNE.silence_skill_id) > 0 and int(skill.get("id", 0)) == int(TUNE.silence_skill_id)


## BattleLogic.battle_skills：默印 5 件的人战斗技能列表多出「万籁俱寂」
static func battle_skills(a) -> Array:
	if not SILENCE_SKILL or not ENABLED or not (a is XActor) or int(TUNE.silence_skill_id) <= 0 or not on():
		return []
	if fold(gear_effects(a)).get("grant_skill_silence_all", {}).is_empty():
		return []
	var rec := XDB.rec("Skills", int(TUNE.silence_skill_id))
	return [] if rec.is_empty() else [rec]


## BattleLogic.can_use（经 XTianqiQiyinRule.can_use）：「万籁俱寂」本场用满 per_battle 次、或没穿满 5 件时不能放
static func skill_usable(logic, a, skill) -> bool:
	if not is_silence_skill(skill):
		return true
	if not (a is XActor):
		return false
	var p: Dictionary = _p(logic, a, "grant_skill_silence_all") if _active(logic) else fold(gear_effects(a)).get("grant_skill_silence_all", {})
	if p.is_empty():
		return false
	return not _active(logic) or int(_unit(logic, a).silence_used) < int(p.get("per_battle", 1))


## 默印 5 件附带技能：敌方全体沉默、我方下一回合技能不耗魔法和 TP（每场 per_battle 次）。放「万籁俱寂」时 begin_action 调
static func use_silence_all(logic, u) -> bool:
	var p := _p(logic, u, "grant_skill_silence_all")
	if p.is_empty():
		return false
	var un := _unit(logic, u)
	if int(un.silence_used) >= int(p.per_battle):
		return false
	un.silence_used = int(un.silence_used) + 1
	for e in logic.enemies:
		_unit(logic, e).silenced = int(p.silence_turns) + 1
	for a in logic.actors:
		_unit(logic, a).free_skill = int(p.free_turns) + 1
	return true


## 沉默中（默印 5 件）：只能普攻、防御、用物品
static func silenced(logic, b) -> bool:
	return _active(logic) and int(_unit(logic, b).silenced) > 0


# ---- 小工具 ----

static func _is_damage(skill: Dictionary) -> bool:
	return skill != null and not skill.is_empty() and int(skill.get("damage", {}).get("type", 0)) in [1, 5]


static func _adds_buff(skill: Dictionary) -> bool:
	for eff in skill.get("effects", []):
		if int(eff.get("code", 0)) in [21, 31]:
			return true
	return false


static func _elements(skill: Dictionary, a) -> Array:
	if skill == null or skill.is_empty() or not skill.has("damage"):
		return []
	return XDamage.action_elements(skill, a)


static func _lowest(list: Array):
	var best = null
	for a in list:
		if a.is_alive() and a.mhp > 0.0 and (best == null or a.hp / a.mhp < best.hp / best.mhp):
			best = a
	return best


static func _next_enemy(logic, t):
	var i: int = logic.enemies.find(t)
	for k in range(1, logic.enemies.size()):
		var e = logic.enemies[(i + k) % logic.enemies.size()]
		if e.is_alive() and not is_same(e, t):
			return e
	return null


static func _random_enemy(logic):
	var alive: Array = logic.enemies.filter(func(e): return e.is_alive())
	if alive.is_empty():
		return null
	return alive[int(logic._int(0, alive.size() - 1, "qiyin_target"))]


## 行动外的生命损失（判决、疫、落星、溢出、处决、替挡）：护盾先吸收，弹字，倒下记阵亡
static func _lose_hp(logic, t, n: float, logs: Array) -> void:
	if n <= 0.0 or t == null or not t.is_alive():
		return
	var before: float = t.hp
	var v: float = t.absorb_shield(n)
	t.hp = maxf(0.0, t.hp - v)
	t.refresh_resources()
	logs.append({"type": "regen", "target": t, "hp": before - t.hp, "views": logic.views([t])})
	if t.hp <= 0.0:
		logic._die(t)
		logs.append({"type": "collapse", "target": t, "views": logic.views([t])})
