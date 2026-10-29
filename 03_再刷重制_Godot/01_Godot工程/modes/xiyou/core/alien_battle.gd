class_name XAlienBattle
extends RefCounted
## 异化的战斗侧（冻结 v0.28 installAlienationRuntime，CodexAlienation）：遭遇、敌人变体、锁队、腐蚀、镜骸反噬、胜利发放。
## 工坊侧（标记、账本、合成、重抽、分解）在 alienation.gd（XAlienation）；词条效果（installAlienationAffixes／Advanced）
## 期一接逆骨、归墟，期二①接疫囊、囚厄、绝缘、舍身，期二②接空壳、连命、嫁祸（见文末「词条效果」），其余词条未移植。
## 参照 mv_oracle/alien_battle_probe.cjs（generated/oracle/alien_battle.json），专项 tests/xiyou_alien_battle；
## 词条效果参照 mv_oracle/alien_affix_probe.cjs（generated/oracle/alien_affix.json），专项 tests/xiyou_alien_affix。
## - 遭遇（Game_Troop.setup 包装 setupEncounter）：本场敌人按 bossSources 匹配（敌人、地图、敌群，未知存在另看来源地图），
##   几率 min(1%, Σ掉率×0.2)、按掉率加权选本体、随机变体；没有 Boss 来源时按 mobSources（地图＋敌群）随机选一个非 Boss 敌人，
##   几率 1%，按 transition 等权选本体，变体「异化」。命中后立刻 XAlienation.create 出奖励装备（不进背包，账本序号照样加一）。
## - 敌人：XEnemy.alien {variant, boss, shieldGranted, mirrorRound, mirrorCharged, plagueRound, drainRound}；
##   最大生命 ×1.5（小怪 ×1.25，Math.round）、名字前加【异化·X】／【异化】，遭遇时回满生命。
## - 开战（startBattle 包装）：出战角色冻结身上的异化装备（_alienBattle）；蜕壳加 10% 最大生命护盾（直接加，不吃护盾效果加成）；提示。
## - 行动根（startAction／endAction 包装）：烈变与小怪的主动生命伤害 +15%／+10%（反击、反射、派生行动不加）；
##   灾疫每回合第一个生命伤害技能对命中的活目标附加腐蚀；镜骸每回合第一次被角色主动打中时，行动结束反噬
##   min(⌊扣血×5%⌋, ⌊行动者最大生命×8%⌋)。
## - 回合：开始时镜骸重新充能；结束时蚀能（偶数回合，吸 MP 比例最高的活角色 10% 最大法力，按实际比例回 2% 最大生命）、
##   腐蚀（每回合末扣 2% 最大生命、经护盾，到期自然消失）。
## - 胜利（gainDropItems／endBattle(0) 包装）：异化敌人倒下才发，放进背包，账本 recent 头插、留 30 条，提示「获得 …」；每场一次。
## 原版行动外的 gainHp／setHp（公式副作用等）也按帧加成与记镜骸；这里只接 executeHpDamage，其余未移植。
## 未知存在的来源地图（Leviathan 的 Game_Map.setup 包装）记在 XState.unknown_origin（进 Map152／176 时记上一张图）。

static var _logic_ref: WeakRef
## 测试用：非空时下一次 setup 遭遇照 A.setupEncounter(force)（{enemy: 序号, kind, baseId, origin, variant, affix}），用后清空
static var force := {}


static func config() -> Dictionary:
	return XAlienation.config()


static func corrosion_id() -> int:
	return int(config().ids.corrosion)


static func _store(logic) -> Dictionary:
	if not logic.has_meta("xalien"):
		logic.set_meta("xalien", {"encounter": null, "root": null, "party": {}, "lastEnd": -1, "toasts": [], "serial": 0})
	return logic.get_meta("xalien")


static func active_logic():
	return _logic_ref.get_ref() if _logic_ref != null else null


## A.round：max(1, 回合数)
static func round_of(logic) -> int:
	return maxi(1, int(logic.turn)) if logic != null else 1


static func _live(b) -> bool:
	return b != null and b.is_alive()


static func _toast(logic, text: String) -> void:
	_store(logic).toasts.append(text)
	XToast.show_text(text)


static func encounter(logic):
	return _store(logic).encounter if logic != null and logic.has_meta("xalien") else null


## Leviathan Game_Map.setup 包装：进未知存在（152／176）时记上一张图（同图重进保留），去别处清掉
static func on_map_setup(s: XState, previous: int, id: int) -> void:
	if id == 152 or id == 176:
		if previous != id:
			s.unknown_origin = previous
	else:
		s.unknown_origin = null


# ---- 遭遇 ----

## JSON 读进来的数是浮点，按整数比
static func _has(list: Array, n: int) -> bool:
	return list.any(func(v): return int(v) == n)


static func _route_matches(src: Dictionary, e: XEnemy, s: XState, troop: int) -> bool:
	if int(src.enemyId) != e.enemy_id or not _has(src.mapIds, s.map_id) or not _has(src.troopIds, troop):
		return false
	if (src.origins as Array).is_empty():
		return true
	return s.unknown_origin != null and _has(src.origins, int(s.unknown_origin))


## Game_Enemy.dropItemRate（EliteEnemy 最终式 × Codex 全队掉率，同怪物图鉴）
static func drop_item_rate(s: XState, e: XEnemy) -> float:
	return (1.0 if XMapTransfer.has_drop_item_double(s) else 0.2) * e.drop_rate_bonus() * XMapTransfer.team_drop_factor(s)


static func _choose(xs: Array, rng: XRandomStream, reason: String):
	var r := rng.next_float(reason, "alien")
	return xs[mini(floori(r * xs.size()), xs.size() - 1)]


static func _weighted(xs: Array, rng: XRandomStream) -> Dictionary:
	var total := 0.0
	for x in xs:
		total += float(x.weight)
	var r := rng.next_float("alien_weighted", "alien") * total
	for x in xs:
		r -= float(x.weight)
		if r < 0.0:
			return x
	return xs[xs.size() - 1]


static func variant_info(key: String) -> Dictionary:
	for v in config().variants:
		if str(v.key) == key:
			return v
	return config().mobVariant if key == "mob" else {}


## A.setupEncounter：返回遭遇记录或 null。rng 取本场规则随机数（同 Math.random 的取用顺序：选小怪、判几率、加权、变体）；
## 奖励的词条随机走 XAlienation.choose
static func setup_encounter(logic, rng: XRandomStream, forced := {}):
	var st := _store(logic)
	st.encounter = null
	var s: XState = logic.state
	var enemies: Array = logic.enemies
	var candidates := []
	for e in enemies:
		for src in config().get("bossSources", []):
			if _route_matches(src, e, s, int(logic.troop_id)):
				var rate := maxf(0.0, drop_item_rate(s, e))
				for d in src.drops:
					candidates.append({"enemy": e, "kind": str(d.kind), "baseId": int(d.baseId), "weight": minf(1.0, float(d.chance) * rate)})
	var total := 0.0
	for x in candidates:
		total += float(x.weight)
	var boss := total > 0.0
	var prob := minf(0.01, total * 0.2) if boss else 0.01
	if not boss:
		var mob = null
		for m in config().get("mobSources", []):
			if int(m.mapId) == s.map_id and _has(m.troopIds, int(logic.troop_id)):
				mob = m
				break
		if mob == null and forced.is_empty():
			return null
		var es := enemies.filter(func(x): return not XZhenqi.is_boss_enemy(x))
		if es.is_empty() and forced.is_empty():
			return null
		var chosen_enemy = enemies[int(forced.enemy)] if forced.has("enemy") else _choose(es, rng, "alien_enemy")
		candidates = (config().get("transition", []) as Array).map(func(t): return {"enemy": chosen_enemy, "kind": str(t.kind), "baseId": int(t.baseId), "weight": 1.0})
	if forced.has("enemy"):
		candidates = [{"enemy": enemies[int(forced.enemy)], "kind": str(forced.kind), "baseId": int(forced.baseId), "weight": 1.0}]
		boss = str(forced.get("origin", "boss")) != "mob"
	if forced.is_empty() and rng.next_float("alien_encounter", "alien") >= prob:
		return null
	var chosen := _weighted(candidates, rng)
	var variant: Dictionary = _choose(config().variants, rng, "alien_variant") if boss else config().mobVariant
	if forced.get("variant") != null and not variant_info(str(forced.variant)).is_empty():
		variant = variant_info(str(forced.variant))
	var made := XAlienation.create(s, str(chosen.kind), int(chosen.baseId), "boss" if boss else "mob", str(forced.get("affix", "")))
	if made.has("error"):
		push_warning("异化奖励创建失败：" + str(made.error))
		return null
	var e: XEnemy = chosen.enemy
	e.alien = {"variant": str(variant.key), "boss": boss, "shieldGranted": false, "mirrorRound": -1, "mirrorCharged": true,
		"plagueRound": -1, "drainRound": -1}
	e.param_mark_dirty()
	e.param_refresh()
	e.hp = e.mhp
	st.serial = int(st.serial) + 1
	st.encounter = {"id": st.serial, "enemy": e, "variant": variant, "reward": made.ok, "granted": false, "settled": false, "probability": prob}
	return st.encounter


## Game_Enemy.param 包装：异化敌人最大生命 ×1.5（小怪 ×1.25）
static func hp_param(e: XEnemy, i: int, v: float) -> float:
	if i != 0 or e.alien.is_empty():
		return v
	return XRaceBattle.js_round(v * (1.5 if bool(e.alien.boss) else 1.25))


## Game_Enemy.name 包装
static func name_prefix(e: XEnemy) -> String:
	if e.alien.is_empty():
		return ""
	var v := variant_info(str(e.alien.variant))
	return "【异化" + ("·" + str(v.name) if str(e.alien.variant) != "mob" and not v.is_empty() else "") + "】"


# ---- 开战、结束 ----

## Game_Troop.setup 包装＋startBattle 包装（BattleManager.setup 之后）：遭遇、锁队、蜕壳护盾、提示
static func start(logic) -> void:
	logic.set_meta("xalien", {"encounter": null, "root": null, "party": {}, "lastEnd": -1, "toasts": [], "serial": 0})
	_logic_ref = weakref(logic)
	var forced := force
	force = {}
	setup_encounter(logic, logic._rule(), forced)
	open(logic)


## startBattle 包装：锁队（原 startBattle 之前）、蜕壳护盾与提示（之后）
static func open(logic) -> void:
	lock_party(logic)
	var x = encounter(logic)
	if x != null:
		var e: XEnemy = x.enemy
		if str(e.alien.variant) == "shell" and not bool(e.alien.shieldGranted):
			e.alien.shieldGranted = true
			e.shield = e.shield + floorf(e.mhp * 0.1)
		_toast(logic, e.display_name() + "：" + str(x.variant.description) + " 胜利保证异化装备。")


## A.lockParty：出战角色各冻结身上第一件异化装备（原版多于一件时抛错）
static func lock_party(logic) -> void:
	var st := _store(logic)
	st.party = {}
	st.battling = true
	for a in logic.actors:
		var d := XAlienation.for_actor(a)
		st.party[a] = null if d.is_empty() else {"item": d.item, "affix": d.affix, "config": (d.config as Dictionary).duplicate(true), "observed": [], "selected": 0}
	st.status = st.party.values().any(func(d): return d != null and STATUS_AFFIXES.has(str(d.affix)))
	st.life = false
	if st.status:
		setup_life(logic)


## 战斗中的 A.forActor：开战时冻结的那份；不在战斗中返回 null
static func locked(a):
	var logic = active_logic()
	if logic == null or not logic.has_meta("xalien") or not _store(logic).party.has(a):
		return null
	return _store(logic).party[a]


## A.grant：异化敌人倒下才发
static func grant(logic) -> bool:
	var x = encounter(logic)
	if x == null or bool(x.granted) or not x.enemy.is_dead():
		return false
	var s: XState = logic.state
	var i: Dictionary = x.reward
	if not s.gear.any(func(g): return is_same(g, i)):
		s.gear.append(i)
	x.granted = true
	var l := XAlienation.ledger(s)
	var m := XAlienation.mark(i)
	(l.recent as Array).push_front({"name": str(i.name), "origin": str(m.origin), "uid": str(m.uid), "kind": XAlienation.kind(i), "id": str(i.get("instanceId", ""))})
	l.recent = (l.recent as Array).slice(0, 30)
	_toast(logic, "获得 " + str(i.name))
	return true


## endBattle 包装：胜利时补发；结算一次；未发的奖励原版删掉独立装备（这里没放进背包，不用删）；清锁队
static func end(logic, result: int) -> void:
	if not logic.has_meta("xalien"):
		return
	var x = encounter(logic)
	if x != null and not bool(x.settled):
		if result == 0:
			grant(logic)
		x.settled = true
	if bool(_store(logic).get("status", false)):
		end_life(logic)
	for a in logic.actors:  # endBattle 包装：清囚厄接收标记
		for k in ["xalien_jail", "xalien_jail_buff"]:
			if a.has_meta(k):
				a.remove_meta(k)
	_store(logic).party = {}
	_store(logic).root = null
	_store(logic).battling = false
	_store(logic).status = false


# ---- 回合 ----

## startTurn 包装（回合数加一之后）：镜骸在新回合重新充能
static func start_turn(logic) -> void:
	var r := round_of(logic)
	for e in logic.enemies:
		var d: Dictionary = e.alien
		if not d.is_empty() and str(d.variant) == "mirror" and int(d.mirrorRound) != r:
			d.mirrorRound = r
			d.mirrorCharged = true


## endTurn 包装（每回合一次）：蚀能、腐蚀结算
static func round_end(logic) -> Array:
	var logs := []
	var st := _store(logic)
	var r := round_of(logic)
	if int(st.lastEnd) == r:
		return logs
	st.lastEnd = r
	for e in logic.enemies:
		drain(logic, e)
	for t in logic.actors + logic.enemies:
		tick_corrosion(logic, t, r, logs)
	return logs


## A.drain：偶数回合，吸 MP 比例最高的活角色（同比例取先到的）10% 最大法力，按实际吸取比例回 2% 最大生命
static func drain(logic, e: XEnemy) -> float:
	var d: Dictionary = e.alien
	var r := round_of(logic)
	if not _live(e) or d.is_empty() or str(d.variant) != "drain" or r % 2 != 0 or int(d.drainRound) == r:
		return 0.0
	d.drainRound = r
	var t = null
	for a in logic.actors:
		if _live(a) and a.mmp > 0.0 and a.mp > 0.0 and (t == null or a.mp / a.mmp > t.mp / t.mmp):
			t = a
	if t == null:
		return 0.0
	var planned := floorf(t.mmp * 0.1)
	if planned < 1.0:
		return 0.0
	var before: float = t.mp
	t.mp = maxf(0.0, t.mp - minf(before, planned))
	var actual := maxf(0.0, before - t.mp)
	if actual > 0.0:
		e.hp = minf(e.mhp, e.hp + floorf(e.mhp * 0.02 * minf(1.0, actual / planned)))
	return actual


## resetStateCounts 包装：腐蚀（新加或续上）按状态回合定到期回合
static func sync_corrosion(t) -> void:
	var id := corrosion_id()
	if not t.state_ids.has(id):
		return
	var remaining := maxi(1, int(t.state_turns.get(id, 2)))
	t.set_meta("xalien_corrosion", {"until": round_of(active_logic()) + remaining - 1, "tick": -1})
	t.state_turns[id] = remaining


static func corrosion_until(t):
	return t.get_meta("xalien_corrosion").until if t.has_meta("xalien_corrosion") else null


## A.tickCorrosion：扣 2% 最大生命（经护盾），回合数改为剩余，到期自然去掉
static func tick_corrosion(logic, t, r: int, logs: Array) -> void:
	var id := corrosion_id()
	if not t.state_ids.has(id) or not _live(t):
		return
	var c: Dictionary = t.get_meta("xalien_corrosion") if t.has_meta("xalien_corrosion") else {"until": r, "tick": -1}
	if int(c.tick) == r:
		return
	c.tick = r
	t.set_meta("xalien_corrosion", c)
	_lose_hp(logic, t, floorf(t.mhp * 0.02), logs)
	var until := int(c.until)
	t.state_turns[id] = maxi(0, until - r)
	if r >= until:
		natural_removal = true
		t.remove_state(id)
		natural_removal = false


## gainHp(-n) 的伤害（ShieldSystem 护盾先吸收），弹字、倒下
static func _lose_hp(logic, t, n: float, logs: Array) -> void:
	var before: float = t.hp
	if not gain_hp_outside(t, -n):  # 期二②：生命池、嫁祸的角色照 gainHp 包装结算
		var v: float = t.absorb_shield(n)
		t.hp = maxf(0.0, t.hp - v)
		t.refresh_resources()
	logs.append({"type": "regen", "target": t, "hp": before - t.hp, "views": logic.views([t])})
	if t.is_dead():
		logs.append({"type": "collapse", "target": t, "views": logic.views([t])})


# ---- 行动根 ----

## A.beginAction（startAction 包装）：灾疫敌人本回合第一个生命伤害技能
static func begin(logic, u, item: Dictionary) -> void:
	var st := _store(logic)
	var root := {"subject": u, "item": item, "mirror": [], "plagueTargets": [], "plague": false, "ended": false}
	st.root = root
	if u is XEnemy and not u.alien.is_empty():
		var d: Dictionary = u.alien
		if str(d.variant) == "plague" and _live(u) and not XBattleLogic.is_item(item) and int(item.get("damage", {}).get("type", 0)) == 1 \
				and int(d.plagueRound) != round_of(logic):
			d.plagueRound = round_of(logic)
			root.plague = true


static func _derived(logic) -> bool:
	return logic.has_meta("xrace") and int(logic.get_meta("xrace").derived) > 0


## 本次结算算不算「主动」（帧 active，且就是行动根本身的行动）：反击、反射、别的行动派生的结算不算
static func _active(logic, u, item: Dictionary) -> bool:
	if _derived(logic):
		return false
	var root = _store(logic).root
	return root == null or (is_same(root.subject, u) and root.item == item)


## executeHpDamage 包装（outgoing）：烈变 ×1.15、小怪异化 ×1.1，只算异化敌人的主动正伤害
static func outgoing(logic, u, item: Dictionary, value: float) -> float:
	if value <= 0.0 or not u is XEnemy or u.alien.is_empty() or not logic.has_meta("xalien") or not _active(logic, u, item):
		return value
	var d: Dictionary = u.alien
	if str(d.variant) == "flare" or not bool(d.boss):
		return floorf(value * (1.15 if bool(d.boss) else 1.1))
	return value


## recordDamage：镜骸被行动根的角色打掉生命（不含反击、反射）
static func record(logic, u, t, loss: float) -> void:
	if not logic.has_meta("xalien") or loss <= 0.0 or not t is XEnemy or t.alien.is_empty() or str(t.alien.variant) != "mirror":
		return
	var root = _store(logic).root
	if root == null or not root.subject is XActor or not is_same(u, root.subject) or _derived(logic):
		return
	var d: Dictionary = t.alien
	if bool(d.mirrorCharged):
		d.mirrorCharged = false
		root.mirror.append({"target": t, "loss": 0.0})
	for x in root.mirror:
		if is_same(x.target, t):
			x.loss = float(x.loss) + loss
			return


## Game_Action.apply 包装（原 apply 之后）：灾疫的行动根命中活目标时附加腐蚀（每个目标一次）
static func after_apply(logic, u, item: Dictionary, t, r: Dictionary) -> void:
	if not logic.has_meta("xalien"):
		return
	var root = _store(logic).root
	if root == null or not bool(root.plague) or not is_same(root.subject, u) or root.item != item or _derived(logic):
		return
	if not _live(t) or bool(r.get("missed", false)) or bool(r.get("evaded", false)) or (root.plagueTargets as Array).any(func(x): return is_same(x, t)):
		return
	root.plagueTargets.append(t)
	logic._effect(u, t, {"code": 21, "dataId": corrosion_id(), "value1": 1.0, "value2": 0.0}, {"skill": item, "added": [], "removed": []})


## A.finishAction（endAction 包装，原 endAction 之后）：镜骸反噬
static func finish(logic, logs: Array) -> void:
	if not logic.has_meta("xalien"):
		return
	var st := _store(logic)
	sync_relations(logic)  # endAction 包装（Adv:185）：同步生命池与嫁祸者
	var root = st.root
	st.root = null
	if root == null or bool(root.ended):
		return
	root.ended = true
	for x in root.mirror:
		if not _live(x.target) or not _live(root.subject):
			continue
		var n := minf(floorf(float(x.loss) * 0.05), floorf(root.subject.mhp * 0.08))
		if n > 0.0:
			_lose_hp(logic, root.subject, n, logs)


# ---- 词条效果（installAlienationAffixes／Advanced，期一：逆骨、归墟） ----

## 公式帧（A.formulaFrames）：evalDamageFormula 压 {physical: 物理技能或逆骨技能}，伤害钩子 enter 压 {physical: false}（整次伤害计算）
static var _formula_frames: Array = []
## 行动帧（A.frames 里 Game_Action.apply 压的那层）：{source, item}；归墟据此拦截攻击期间对他人附加的状态
static var _action_frames: Array = []


## A.has：战斗中按开战冻结的词条，战斗外按身上的异化装备（敌人恒为否）
static func has(b, key: String) -> bool:
	return b is XActor and str(XAlienation.for_actor(b).get("affix", "")) == key


static func _in_template(key: String, id: int) -> bool:
	return XAlienation._in(key, id)


## 影子克隆（预演公式）与本体同一角色
static func _same(x, y) -> bool:
	return is_same(x, y) or (x is XActor and y is XActor and x.actor_id == y.actor_id)


static func push_formula(item: Dictionary, a, b, formula: bool) -> void:
	_formula_frames.append({"item": item, "subject": a, "target": b,
		"physical": formula and (XDamage.is_physical(item) or _in_template("inversebone", int(item.get("id", 0))))})


static func pop_formula() -> void:
	_formula_frames.pop_back()


## Game_Actor.param 包装（逆骨）：帧内的目标是物理（或逆骨技能）时物防读 0；行动者用逆骨技能时物攻改读物防。
## inner 是包装之内的取值（原版 old.call(this, 3)）
static func param(a: XActor, i: int, v: float) -> float:
	if i == 0:
		return hollow_param(a, v)
	if _formula_frames.is_empty() or (i != 2 and i != 3):
		return v
	var f: Dictionary = _formula_frames[_formula_frames.size() - 1]
	if i == 3 and bool(f.physical) and _same(a, f.target) and has(a, "inversebone"):
		return 0.0
	if i == 2 and _same(a, f.subject) and has(a, "inversebone") and _in_template("inversebone", int(f.item.get("id", 0))):
		return a.param_before_alien(3)
	return v


## 攻击类伤害（A.isAttackDamage：伤害类型 1／2／5／6）
static func attack_damage(item: Dictionary) -> bool:
	return int(item.get("damage", {}).get("type", 0)) in [1, 2, 5, 6]


## 伤害钩子的事实：目标逆骨、行动者归墟的攻击
static func capture(item: Dictionary, a: XBattler, b: XBattler) -> Dictionary:
	return {"inversebone": has(b, "inversebone"), "void": has(a, "void") and attack_damage(item)}


static func descriptor() -> Dictionary:
	# 原版 alienation 钩子 unshift 到最前（order 1）；alienation-void 在 installAlienationAdvanced 时 push（小猫 19 之后、宝珠 39 之前）
	return {"id": "alienation", "version": "1", "capabilities": ["damage.alienation"], "contexts": ["facts"], "hooks": [
		{"point": "damage.before", "order": 1, "reads": ["facts.alienation"], "writes": ["physicalDefenseRate"], "handler": _build},
		{"point": "damage.before", "order": 21, "reads": ["facts.alienation"], "writes": ["noElement", "elements"], "handler": _build_void}]}


static func _build(context: Dictionary, _frame: Dictionary) -> Dictionary:
	return {"ops": [{"op": "set", "field": "physicalDefenseRate", "value": 0.0}] if bool(context.facts.alienation.inversebone) else []}


static func _build_void(context: Dictionary, _frame: Dictionary) -> Dictionary:
	if not bool(context.facts.alienation.void):
		return {"ops": []}
	return {"ops": [{"op": "set", "field": "noElement", "value": true}, {"op": "set", "field": "elements", "value": [0]}]}


static func push_action(u, item: Dictionary) -> void:
	_action_frames.append({"source": u, "item": item})


static func pop_action() -> void:
	_action_frames.pop_back()


## applyItemEffect 包装（归墟）：攻击类伤害技能不附加状态、增益、减益（效果 21／31／32）
static func skips_effect(u, item: Dictionary, eff: Dictionary) -> bool:
	return int(eff.get("code", 0)) in [21, 31, 32] and attack_damage(item) and has(u, "void")


## addState 包装（归墟）：归墟者的攻击行动期间，别人身上不能被附加状态（自定义命中效果等）
static func blocks_state(b) -> bool:
	if _action_frames.is_empty():
		return false
	var f: Dictionary = _action_frames[_action_frames.size() - 1]
	return not is_same(f.source, b) and attack_damage(f.item) and has(f.source, "void")


# ---- 词条效果期二①：疫囊、囚厄、绝缘、舍身（状态类） ----

## A.naturalRemoval：自然到期（removeStatesAuto、腐蚀到期、囚厄转移后原主身上去掉）时放行受保护状态的移除
static var natural_removal := false
## O-106（优化登记）：原版 installNativeTojiRuntime.js:150-154（模块 9）先截下了 Game_Actor.addDebuff，installAlienationAdvanced
## 后包的 Game_Battler.addDebuff 对角色走不到，囚厄「接收队友减益」、绝缘「免疫外来减益」对角色失效（只有疫囊者经
## Game_Battler.prototype.addDebuff 走得到）。true＝照词条说明对所有角色生效；false＝照原版
static var o106_actor_debuffs := true
const STATUS_AFFIXES := ["pest", "jail", "insulation", "sacrifice", "hollow", "lifelink", "scapegoat"]
static var _state_routing := 0
static var _support_routing := 0


## $gameParty.inBattle()：开战锁队后到结束之间
static func battling() -> bool:
	var logic = active_logic()
	return logic != null and logic.has_meta("xalien") and bool(_store(logic).get("battling", false))


## 战斗中且有出战角色带期二①的状态类词条（开战锁队时定）：下面的钩子都先看它，普通战斗一步早退
static func status_battle() -> bool:
	var logic = active_logic()
	return logic != null and logic.has_meta("xalien") and bool(_store(logic).get("status", false))


static func _pairs() -> Dictionary:
	return XAlienation.templates().get("statePairs", {})


## statePairs 的键是登记的数值增益状态（祸祝把它换成对应诅咒）
static func positive_state(id: int) -> bool:
	return _pairs().has(str(id))


## A.source：当前帧的来源，没有帧时取行动根的行动者（原版 BattleManager._subject），都没有就是目标自己
static func source_of(t):
	if not _action_frames.is_empty():
		return _action_frames[_action_frames.size() - 1].source
	var logic = active_logic()
	if logic != null and logic.has_meta("xalien") and _store(logic).root != null:
		return _store(logic).root.subject
	return t


## A.external：战斗中来源不是自己
static func external(t) -> bool:
	return status_battle() and not is_same(source_of(t), t)


static func _insulated(t) -> bool:
	return has(t, "insulation") and external(t)


## 疫囊 protectedState：疫囊者活着时，pestStates 必中、不可抵抗、不可驱散
static func pest_state(b, id: int) -> bool:
	return status_battle() and has(b, "pest") and _live(b) and _in_template("pestStates", id)


## 囚厄 receiving：转移给囚厄者的状态
static func receiving(b, id: int) -> bool:
	return status_battle() and b.has_meta("xalien_jail") and bool(b.get_meta("xalien_jail").get(id, false))


## stateRate 1、isStateResist 否（疫囊、囚厄接收）
static func forced_state(b, id: int) -> bool:
	return pest_state(b, id) or receiving(b, id)


## A.supportTarget：舍身者的收益改给绑定队友（队友倒下作废，返回 null）；其他人返回自己
static func support_target(t):
	if not status_battle() or not t is XActor:
		return t
	var d = locked(t)
	if d == null or str(d.affix) != "sacrifice":
		return t
	var p = partner_of(d)
	return p if _live(p) else null


static func partner_of(d):
	var logic = active_logic()
	var id := int(d.get("config", {}).get("partnerId", 0))
	for a in logic.actors:
		if a.actor_id == id:
			return a
	return null


static func _jail_receiver(b):
	if not b is XActor or has(b, "jail"):
		return null
	for a in active_logic().actors:
		if not is_same(a, b) and has(a, "jail") and _live(a):
			return a
	return null


static func _support(t, src, fn: Callable) -> void:
	_support_routing += 1
	push_action(src, {})  # A.withFrame(null, target, 'support', fn, A.source(this))：来源不变
	fn.call()
	pop_action()
	_support_routing -= 1


## addState 包装（installAlienationAdvanced 159-167，原版之前那段）：绝缘拒收外来登记增益与囚厄状态；舍身把登记增益转给队友。
## 返回真＝本次不在 b 身上附加
static func route_state(b, id: int) -> bool:
	if not status_battle():
		return false
	var positive := positive_state(id)
	if _insulated(b) and (positive or _in_template("jailStates", id)):
		return true
	if _state_routing > 0 or not positive:
		return false
	var t = support_target(b)
	if is_same(t, b):
		return false
	if t != null:
		_state_routing += 1
		_support(t, source_of(b), func(): t.add_state(id))
		_state_routing -= 1
	return true


static func revision(b, id: int) -> int:
	return int(b.get_meta("xalien_rev", {}).get(id, 0))


## resetStateCounts 包装：记附加次数（A.tryState 据此判成功）；疫囊重复附加时回合取较长
static func on_reset_state(b, id: int, before) -> void:
	if not status_battle():
		return  # 附加次数只给囚厄转移、疫囊传播比较用
	var rev: Dictionary = b.get_meta("xalien_rev", {})
	rev[id] = int(rev.get(id, 0)) + 1
	b.set_meta("xalien_rev", rev)
	if before != null and pest_state(b, id):
		b.state_turns[id] = maxi(int(before), int(b.state_turns[id]))


## addState 包装（原版之后那段）：其他角色实际获得 jailStates 时转给囚厄者（回合取较长），自己身上按自然移除去掉
static func after_add_state(b, id: int, before_rev: int) -> void:
	if not status_battle() or _state_routing > 0 or revision(b, id) <= before_rev or not _in_template("jailStates", id):
		return
	var r = _jail_receiver(b)
	if r == null:
		return
	var turns := int(b.state_turns.get(id, 0))
	var jail: Dictionary = r.get_meta("xalien_jail", {})
	jail[id] = true
	r.set_meta("xalien_jail", jail)
	_state_routing += 1
	r.add_state(id)
	if r.state_ids.has(id):
		r.state_turns[id] = maxi(int(r.state_turns.get(id, 0)), turns)
		if id == corrosion_id():
			sync_corrosion(r)
		r.param_refresh()
		natural_removal = true
		b.remove_state(id)
		natural_removal = false
	_state_routing -= 1


## removeState／eraseState 包装：疫囊、囚厄接收的状态只能自然到期；绝缘拒绝外来驱散登记增益与复活
static func blocks_removal(b, id: int, natural: bool) -> bool:
	if not status_battle() or natural or natural_removal:
		return false
	return pest_state(b, id) or receiving(b, id) or (_insulated(b) and (positive_state(id) or id == 1))


## 自然移除后清囚厄接收标记
static func after_removal(b, id: int, natural: bool) -> void:
	if (natural or natural_removal) and not b.state_ids.has(id) and b.has_meta("xalien_jail"):
		b.get_meta("xalien_jail").erase(id)


## clearStates 包装：受保护的状态保留
static func keeps_state(b, id: int) -> bool:
	return status_battle() and (pest_state(b, id) or receiving(b, id) or (_insulated(b) and (positive_state(id) or id == 1)))


## addBuff／addDebuff 包装：返回真＝已处理（拒收或转给别人）
static func route_buff(logic, t, pid: int, buff: bool, turns: int) -> bool:
	if not status_battle() or pid < 2 or pid > 7:
		return false
	if not buff and not o106_actor_debuffs and t is XActor and not has(t, "pest"):
		return false
	if _insulated(t):
		return true
	if buff:
		var p = support_target(t)
		if is_same(p, t):
			return false
		if p != null and _support_routing == 0:
			_support(p, source_of(t), func(): logic.sequence_buff(p, pid, true, true, turns))
		return true
	var r = _jail_receiver(t)
	if r == null:
		return false
	var before: int = t.buffs[pid]
	logic.sequence_buff(t, pid, true, false, turns, true)
	if t.buffs[pid] < before:
		var jb: Dictionary = r.get_meta("xalien_jail_buff", {})
		jb[pid] = maxi(int(jb.get(pid, 0)), turns)
		r.set_meta("xalien_jail_buff", jb)
		r.buffs[pid] = mini(r.buffs[pid], t.buffs[pid])
		r.buff_turns[pid] = maxi(r.buff_turns[pid], turns)
		t.buffs[pid] = before
		if before == 0:
			t.buff_turns[pid] = 0
		r.param_mark_dirty()
		t.param_mark_dirty()
	return true


## removeBuff 包装：疫囊者的减益（回合未尽）、囚厄接收的减益不可驱散；绝缘拒绝外来驱散增益
static func blocks_buff_removal(t, pid: int) -> bool:
	if not status_battle() or natural_removal:
		return false
	if has(t, "pest") and _live(t) and t.buffs[pid] < 0 and t.buff_turns[pid] > 0:
		return true
	if t.buffs[pid] < 0 and bool(t.get_meta("xalien_jail_buff", {}).get(pid, 0)):
		return true
	return t.buffs[pid] > 0 and _insulated(t)


## gainHp／gainMp 包装：绝缘拒收外来恢复；舍身的生命恢复改给队友。返回真＝不在 b 身上结算
static func route_gain(ctx, b, resource: String, amount: float) -> bool:
	if amount <= 0.0 or resource == "tp" or not status_battle():
		return false
	if _insulated(b):
		return true
	if resource != "hp":
		return false
	var t = support_target(b)
	if is_same(t, b):
		return false
	if t != null and _support_routing == 0:
		_support(t, source_of(b), func(): ctx.gain(t, "hp", amount))
	return true


## addShield 包装：绝缘拒收外来护盾；舍身的护盾按给予者的护盾效果加成转给队友。返回真＝已处理
static func route_shield(b, value: float) -> bool:
	if not status_battle() or not b is XActor:
		return false
	if _insulated(b):
		return true
	var t = support_target(b)
	if is_same(t, b):
		return false
	if t != null and _support_routing == 0:
		var v: float = value * (1.0 + b.shield_effect_bonus()) if value > 0.0 else value
		_support_routing += 1
		push_action(source_of(b), {})
		if not _insulated(t):
			t.shield = maxf(0.0, t.shield + v)
		pop_action()
		_support_routing -= 1
	return true


## A.spreadPest（endTurn 包装，原 endTurn 之前）：疫囊者把身上的 pestStates 与减益传给全体活着的敌人
static func spread_pest(logic) -> void:
	if not status_battle():
		return
	var r := round_of(logic)
	var attack := XDB.rec("Skills", 1)
	for a in logic.actors:
		if not _live(a) or not has(a, "pest"):
			continue
		var d = locked(a)
		if int(d.get("spreadRound", -1)) == r:
			continue
		d.spreadRound = r
		var states: Array = a.state_ids.filter(func(id): return _in_template("pestStates", id))
		for e in logic.enemies:
			if not _live(e):
				continue
			for id in states:
				var before: bool = e.state_ids.has(id)
				var turn = e.state_turns.get(id, 0)
				var expiry = corrosion_until(e)
				var rev := revision(e, id)
				push_action(a, attack)
				logic._effect(a, e, {"code": 21, "dataId": id, "value1": 1.0, "value2": 0.0}, {"skill": attack, "added": [], "removed": []})
				pop_action()
				if revision(e, id) <= rev or not e.state_ids.has(id):
					continue
				var mine := int(a.state_turns.get(id, 0))
				e.state_turns[id] = maxi(int(turn), mine) if before else mine
				if a.state_origins.has(id):
					e.state_origins[id] = a.state_origins[id]
				if id == corrosion_id():
					var own = corrosion_until(a)
					var until: int = maxi(int(expiry if expiry != null else 0), int(own if own != null else r)) if before else int(own if own != null else r)
					e.state_turns[id] = maxi(1, until - r + 1)
					sync_corrosion(e)
			for p in range(2, 8):
				if a.buffs[p] >= 0:
					continue
				logic.sequence_buff(e, p, true, false, a.buff_turns[p])
				if e.buffs[p] < 0:
					e.buffs[p] = mini(e.buffs[p], a.buffs[p])
					e.buff_turns[p] = maxi(e.buff_turns[p], a.buff_turns[p])


# ---- 词条效果期二②：空壳、连命、嫁祸（生命池类，installAlienationAdvanced 50-75、94-109、114-129、195-196） ----

## O-108（优化登记）：原版复活包装挂在 Game_BattlerBase.revive（Adv:195），Olivia_BattleSysOTB.js:2164 另定义了
## Game_Battler.prototype.revive 盖过它，对角色从不生效：连命者复活后生命池仍是 0、人却 1 血活着；嫁祸者的保护者倒下也照样复活。
## true＝照词条说明（连命复活把池回到 10%，嫁祸的保护者倒下时不能复活）；false＝照原版
static var o108_life_revive := true
static var _hp_resolving := 0
static var _death_sync := 0


static func _affix_of(b) -> String:
	if not b is XActor:
		return ""
	var d = locked(b)
	return "" if d == null else str(d.affix)


## lockParty 包装（Adv:62-75）：记开场参照生命／法力，空壳换护盾，连命合池，嫁祸绑保护者
static func setup_life(logic) -> void:
	var st := _store(logic)
	for a in logic.actors:
		var d = st.party.get(a)
		if d == null:
			continue
		d.referenceHp = a.param_before_alien(0)
		d.referenceMp = a.param_before_alien(1)
		d.originalHp = a.hp
		d.originalMp = a.mp
		if str(d.affix) in ["lifelink", "scapegoat", "sacrifice"]:
			d.partner = partner_of(d)
	for a in logic.actors:
		var d = st.party.get(a)
		if d == null:
			continue
		var p = d.get("partner")
		match str(d.affix):
			"lifelink":
				if p != null:
					var pool := {"members": [a, p], "max": a.mhp + p.mhp,
						"current": minf(float(d.originalHp), float(d.referenceHp)) + minf(p.hp, p.mhp)}
					a.set_meta("xalien_life", pool)
					p.set_meta("xalien_life", pool)
					sync_pools(logic)
			"scapegoat":
				if p != null:
					a.set_meta("xalien_protector", p)
					a.shield = 0.0
					a.hp = maxf(1.0, floorf(a.mhp * p.hp / p.mhp)) if p.hp > 0.0 else 0.0
			"hollow":
				a.param_mark_dirty()
				a.shield = minf(float(d.referenceHp), maxf(0.0, float(d.originalHp)))
				a.hp = 1.0 if float(d.originalHp) > 0.0 else 0.0
	st.life = logic.actors.any(func(x): return x.has_meta("xalien_life") or x.has_meta("xalien_protector"))


## endBattle 包装（Adv:196）：空壳按剩余护盾还原生命，解除生命池与保护者
static func end_life(logic) -> void:
	for a in logic.actors:
		var d = locked(a)
		if d != null and str(d.affix) == "hollow":
			a.hp = 0.0 if a.is_dead() else maxf(1.0, minf(float(d.get("referenceHp", a.hp)), maxf(0.0, a.shield)))
			a.shield = 0.0
		for k in ["xalien_life", "xalien_protector"]:
			if a.has_meta(k):
				a.remove_meta(k)
		a.param_mark_dirty()


## Game_Actor.param 包装（Adv:56-59）：空壳的生命上限读 1；公式帧内（evalDamageFormula 包装）读开场参照
static func hollow_param(a: XActor, v: float) -> float:
	if _affix_of(a) != "hollow" or not status_battle():
		return v
	if not _formula_frames.is_empty():
		var f: Dictionary = _formula_frames[_formula_frames.size() - 1]
		if _same(a, f.subject) or _same(a, f.target):
			return v
	return 1.0


## A.syncPools：池上限＝成员上限之和，各成员按自己的上限比例显示（池未空时至少 1）
static func sync_pools(logic) -> void:
	var seen := []
	for a in logic.actors:
		if not a.has_meta("xalien_life"):
			continue
		var p: Dictionary = a.get_meta("xalien_life")
		if seen.any(func(x): return is_same(x, p)):
			continue
		seen.append(p)
		var mx := 0.0
		for b in p.members:
			mx += b.mhp
		p.current = minf(float(p.current), mx)
		p.max = mx
		for b in p.members:
			b.hp = maxf(1.0, floorf(b.mhp * float(p.current) / maxf(1.0, mx))) if float(p.current) > 0.0 else 0.0


## A.setLife：池归零两人倒下，否则去掉阵亡
static func set_life(logic, p: Dictionary, value: float) -> void:
	p.current = maxf(0.0, minf(float(p.max), value))
	sync_pools(logic)
	_death_sync += 1
	for b in p.members:
		if float(p.current) == 0.0:
			b.add_state(1)
			b.hp = 0.0
		elif b.state_ids.has(1):
			b.remove_state(1)
	_death_sync -= 1


## A.syncRelations：池同步；嫁祸者的生命按保护者比例，保护者倒下自己也倒下
static func sync_relations(logic = null) -> void:
	if logic == null:
		logic = active_logic()
	if logic == null or not status_battle() or not bool(_store(logic).get("life", false)):
		return
	sync_pools(logic)
	for a in logic.actors:
		if not a.has_meta("xalien_protector"):
			continue
		var p = a.get_meta("xalien_protector")
		a.shield = 0.0
		a.hp = maxf(1.0, floorf(a.mhp * p.hp / maxf(1.0, p.mhp))) if p.hp > 0.0 else 0.0
		if not _live(p) and not a.is_dead():
			_death_sync += 1
			a.add_state(1)
			_death_sync -= 1


## shieldLoss（Adv:94）：扣血先吃护盾，剩余减半
static func _shield_loss(b, value: float) -> float:
	if value < 0.0 and b.shield > 0.0:
		var take := minf(b.shield, -value)
		b.shield -= take
		var rest := -value - take
		return -floorf(rest * 0.5) if rest > 0.0 else 0.0
	return value


## gainHp 包装（hpChange，Adv:95-101）的生命池部分：空壳、嫁祸不吃治疗；嫁祸的扣血由保护者付；连命结算到池。返回真＝已处理
static func route_life_gain(ctx, b, amount: float) -> bool:
	if _hp_resolving > 0 or not status_battle():
		return false
	var k := _affix_of(b)
	if amount > 0.0 and k in ["hollow", "scapegoat"]:
		return true
	if amount < 0.0 and b.has_meta("xalien_protector"):
		var p = b.get_meta("xalien_protector")
		if _live(p):
			_hp_resolving += 1
			ctx.gain(p, "hp", amount)
			_hp_resolving -= 1
			sync_relations()
		return true
	if b.has_meta("xalien_life"):
		var p: Dictionary = b.get_meta("xalien_life")
		var delta := _shield_loss(b, amount)
		var r: Dictionary = ctx.result(b)
		r.hpDamage = -delta
		r.hpAffected = true
		set_life(active_logic(), p, float(p.current) + delta)
		b.param_mark_dirty()
		return true
	return false


## 一般 gainHp 之后（hpChange 末尾 finally）：同步生命池与嫁祸者
static func after_gain(b, resource: String) -> void:
	if resource == "hp" and _hp_resolving == 0:
		sync_relations()


## setHp 包装（Adv:107）：生命池、嫁祸、空壳、舍身、绝缘按 gainHp(差值) 走。返回真＝改走 gain
static func routes_set_hp(b) -> bool:
	if _hp_resolving > 0 or _death_sync > 0 or not status_battle():
		return false
	return b.has_meta("xalien_life") or b.has_meta("xalien_protector") or _affix_of(b) in ["hollow", "sacrifice", "insulation"]


## 行动外的 gainHp（腐蚀、镜骸反噬、事件「增减生命」）：生命池、嫁祸、空壳、舍身、绝缘的角色改走资源上下文的 gain，
## 照 hpChange 结算（连命扣池、嫁祸由保护者付、空壳不吃治疗）。返回真＝已结算
static func gain_hp_outside(b, value: float) -> bool:
	if value == 0.0 or not routes_set_hp(b):
		return false
	var logic = active_logic()
	var res: XResourceContext = logic._operation_resources(b)
	res.gain(b, "hp", value)
	logic._finish_lifecycle_operation(res, b)
	return true


## regenerateHp 包装（Adv:108-109）：再生量改走 gainHp（空壳、嫁祸不回、舍身转队友、连命进池）。返回真＝已处理
static func routes_regen(b) -> bool:
	return routes_set_hp(b)


## gainMp 包装（Adv:111-112）：空壳的回蓝按开场生命／法力比例变护盾。返回真＝已处理
static func route_hollow_mp(b, amount: float) -> bool:
	if amount <= 0.0 or _affix_of(b) != "hollow" or not status_battle():
		return false
	var d = locked(b)
	b.add_shield(floorf(amount * float(d.referenceHp) / maxf(1.0, float(d.referenceMp))))
	return true


## addShield 包装（Adv:114-115）：嫁祸拒收；空壳的护盾不超过开场参照生命上限。返回真＝拒收
static func blocks_life_shield(b) -> bool:
	return status_battle() and _affix_of(b) == "scapegoat"


static func clamp_hollow_shield(b) -> void:
	if _affix_of(b) == "hollow" and status_battle():
		b.shield = minf(b.shield, float(locked(b).referenceHp))


## A.damageTarget（Adv:117）：敌人对嫁祸者的生命伤害（类型 1／5）改由活着的保护者承受（命中、闪避、暴击、伤害都按保护者）
static func damage_target(u, skill: Dictionary, t):
	if not status_battle() or t == null or not t.has_meta("xalien_protector") or not u is XEnemy:
		return t
	var p = t.get_meta("xalien_protector")
	if not _live(p) or not int(skill.get("damage", {}).get("type", 0)) in [1, 5]:
		return t
	return p


## revive 包装（Adv:195，O-108）：嫁祸的保护者倒下时不能复活；连命复活把池回到复活者上限的 10%。返回真＝已处理（不走原复活）
static func route_revive(b) -> bool:
	if not o108_life_revive or not status_battle() or _death_sync > 0 or _hp_resolving > 0:
		return false
	if b.has_meta("xalien_protector") and not _live(b.get_meta("xalien_protector")):
		return true
	if b.has_meta("xalien_life"):
		set_life(active_logic(), b.get_meta("xalien_life"), maxf(1.0, b.mhp * 0.1))
		return true
	return false
