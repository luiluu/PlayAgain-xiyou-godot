class_name XAlienBattle
extends RefCounted
## 异化的战斗侧（冻结 v0.28 installAlienationRuntime，CodexAlienation）：遭遇、敌人变体、锁队、腐蚀、镜骸反噬、胜利发放。
## 工坊侧（标记、账本、合成、重抽、分解）在 alienation.gd（XAlienation）；词条效果（installAlienationAffixes／Advanced）
## 期一接逆骨、归墟，期二①接疫囊、囚厄、绝缘、舍身，期二②接空壳、连命、嫁祸，③接祸祝、恶愿、逆祷、缄默、饕餮、百相、无面、蚀术，④接吞器、献器
## （见文末「词条效果」），其余词条未移植。
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
## 原版行动外的 gainHp／setHp（公式副作用等）也按帧加成与记镜骸；这里只接 executeHpDamage，其余未移植（帧里逆祷的阻断另接，见 frame_blocks_hp）。
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
	restore_gear(logic)  # 重新锁队（测试夹具）前先还原上次空出的装备栏，免得把空栏当成原装备存下
	eject_invalid(logic)
	st.party = {}
	st.battling = true
	for a in logic.actors:
		var d := XAlienation.for_actor(a)
		st.party[a] = null if d.is_empty() else {"item": d.item, "affix": d.affix, "config": (d.config as Dictionary).duplicate(true), "observed": [], "selected": 0}
	st.status = st.party.values().any(func(d): return d != null and STATUS_AFFIXES.has(str(d.affix)))
	st.life = false
	if st.status:
		setup_life(logic)
	else:
		for a in logic.actors:
			setup_gear(logic, a, st.party[a])


## lockParty 包装（Adv:62）：配置失效的异化装备（A.ready 不过；绑定词条的队友不在场、已倒下或已被前面的人绑定）
## 卸下放回背包并提示，本场不生效
static func eject_invalid(logic) -> void:
	var s: XState = logic.state
	var claimed := []
	for a in logic.actors:
		var slot := -1
		for i in a.equips.size():
			var e = a.equips[i]
			if e is Dictionary and not XAlienation.mark(e).is_empty():
				slot = i
				break
		if slot < 0:
			continue
		var item: Dictionary = a.equips[slot]
		var m := XAlienation.mark(item)
		var bad := not XAlienation.ready(s, a, item)
		if Array(XAlienation.config().get("boundKeys", [])).has(str(m.affix)):
			var p = null
			for x in logic.actors:
				if x.actor_id == int(m.get("config", {}).get("partnerId", 0)):
					p = x
			bad = bad or p == null or not _live(p) or claimed.any(func(c): return is_same(c, p))
			if not bad:
				claimed.append(p)
		if bad:
			a.equips[slot] = null
			s.gear.append(item)
			a.refresh_passive()
			a.param_mark_dirty()
			a.refresh_resources()
			_toast(logic, a.display_name() + "的异化配置失效，" + str(item.name) + "已放回背包，请在工坊重新配置。")


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
	restore_gear(logic)
	if bool(_store(logic).get("status", false)):
		end_life(logic)
	# endBattle 包装：清囚厄接收、恶愿代价标记；生命池与保护者也再清一次（重锁时卸下了生命类配置、本场不算状态类时，
	# 上一次锁队留下的池仍互相引用）
	for a in logic.actors:
		for k in ["xalien_jail", "xalien_jail_buff", "xalien_wish", "xalien_wish_buff", "xalien_life", "xalien_protector"]:
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


## A.finishAction（endAction 包装，原 endAction 之后）：镜骸反噬、百相记录
static func finish(logic, logs: Array) -> void:
	if not logic.has_meta("xalien"):
		return
	var st := _store(logic)
	sync_relations(logic)  # endAction 包装（Adv:185）：同步生命池与嫁祸者
	release_seals(logic)  # endAction 包装（Adv:185）：蚀术解封本次原有合法行动窗口列出的封印
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
	observe(logic, root)  # 百相记录敌人展示的技能（finishAction 末尾）


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
	_formula_frames.append({"item": item, "subject": a, "target": b, "formula": formula,
		"physical": formula and (XDamage.is_physical(item) or _in_template("inversebone", int(item.get("id", 0))))})


static func pop_formula() -> void:
	_formula_frames.pop_back()


## Game_Actor.param 包装（逆骨）：帧内的目标是物理（或逆骨技能）时物防读 0；行动者用逆骨技能时物攻改读物防。
## inner 是包装之内的取值（原版 old.call(this, 3)）
static func param(a: XActor, i: int, v: float) -> float:
	if i == 0:
		return silence_param(a, hollow_param(a, v))
	if i == 1:
		return glutton_param(a, v)
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


# ---- 词条效果第③批：行动道具投影（祸祝、恶愿、逆祷） ----

## A.project（Aff:41-47，原版换掉 Game_Action.item）：角色的行动技能换成投影。重制在 execute 里武器解放之后、付费之前换一次，
## 之后费用、目标、命中、伤害、效果、战斗记录的名字都读投影；投影保留原 id，_alienOriginal／_alienMode 记原技能与词条。
## 选目标界面与自动战斗要先投影再看 scope（battle_scene._pick_target、XBattleLogic.decide）。
static func project(u, skill: Dictionary) -> Dictionary:
	if skill.is_empty() or skill.has("_alienMode") or not (u is XActor) or XBattleLogic.is_item(skill):
		return skill
	var affix := str(XAlienation.for_actor(u).get("affix", ""))
	if affix == "blessing" and _in_template("blessing", int(skill.id)):
		return _project_blessing(skill)
	if affix == "prayer" and _in_template("attack", int(skill.id)):
		return _project_prayer(skill)
	if affix == "wish" and _in_template("wish", int(skill.id)):
		# 恶愿（Adv:176）：除自己外的全体友方（makeTargets 再去掉自己，Adv:177）
		var v := skill.duplicate(true)
		v.scope = 8
		v._alienOriginal = int(skill.id)
		v._alienMode = "wish"
		return v
	return skill


## 逆祷（Aff:42-43）：照治愈（技能 8）的副本，保留原技能的 id、名字、图标、说明、费用、技能类型、武器要求与连击次数；
## 伤害改为 0 的生命恢复（元素 10、不暴击），没有效果，必中；原 scope 1→7（友方单体），其余→8（3～6 另按随机友方，见 targets）
static func _project_prayer(s: Dictionary) -> Dictionary:
	var v: Dictionary = XDB.rec("Skills", 8).duplicate(true)
	for k in ["id", "name", "iconIndex", "description", "mpCost", "tpCost", "stypeId", "requiredWtypeId1", "requiredWtypeId2", "repeats"]:
		if s.has(k):
			v[k] = s[k]
	v.damage = {"critical": false, "elementId": 10, "formula": "0", "type": 3, "variance": 0}
	v.effects = []
	v.scope = 7 if int(s.get("scope", 0)) == 1 else 8
	v.hitType = 0
	v.name = "逆祷·" + str(s.get("name", ""))
	v._alienOriginal = int(s.id)
	v._alienMode = "prayer"
	v._alienOriginalScope = int(s.get("scope", 0))
	return v


static func _mode(skill: Dictionary) -> String:
	return str(skill.get("_alienMode", ""))


## makeTargets 包装：逆祷原 scope 3～6 改为随机友方 n 个（Aff:49，random 由 logic 掷）；恶愿去掉自己（Adv:177）。返回 null＝照原目标
static func prayer_random_count(skill: Dictionary) -> int:
	var o := int(skill.get("_alienOriginalScope", 0))
	return o - 2 if _mode(skill) == "prayer" and o >= 3 and o <= 6 else 0


static func filter_targets(u, skill: Dictionary, list: Array) -> Array:
	return list.filter(func(t): return not is_same(t, u)) if _mode(skill) == "wish" else list


## 逆祷治疗分摊的目标数（Aff:49 _alienHealTargets：makeTargets 之后、含连击重复）
static func set_heal_targets(skill: Dictionary, n: int) -> void:
	if _mode(skill) == "prayer":
		skill._alienHealTargets = maxi(1, n)


## makeDamageValue 包装（Aff:50）：按原技能面板 MP 费用选治疗技能（≥125 治疗术 166，≥75 次级治疗术 135，否则治愈 8），
## 对这名目标算一次不暴击的治疗值当预算，平分给本次行动的目标数。原版另把治疗技能的熟练度借成原技能的，重制熟练度统一为 0，不涉及
static func prayer_heal(logic, u, skill: Dictionary, t) -> float:
	if o_prayer_counter and t is XEnemy:
		return 0.0  # O-待定：反击打到敌人身上的逆祷治疗不生效
	var budget := absf(logic._damage_value(u, prayer_healer(logic, u, skill), t, false))
	var count := int(skill.get("_alienHealTargets", 1))
	return -floorf(budget / maxf(1.0, float(count)))


## 逆祷借用的治疗技能：按原技能面板 MP 费用，≥125 治疗术 166，≥75 次级治疗术 135，否则治愈 8
static func prayer_healer(logic, u, skill: Dictionary) -> Dictionary:
	var cost := float(logic.skill_cost(u, XDB.rec("Skills", int(skill._alienOriginal))).mp)
	return XDB.rec("Skills", 166 if cost >= 125.0 else 135 if cost >= 75.0 else 8)


## O-待定（优化登记）：逆祷者的反击照原版也读投影（invokeCounterAttack 的 setAttack 走 item()），变成「治愈」打在出手的敌人身上，
## 把它刚打掉的生命补回去。true＝打在敌人身上的逆祷治疗为 0（反击仍挡下敌人这次行动，同普通反击）；false＝照原版治疗敌人
static var o_prayer_counter := true


## meetsSkillConditions 包装（Aff:22）：逆祷者不能用 templates.attack 以外的伤害技能（伤害类型 1／2／5／6）
static func blocks_skill(a, skill: Dictionary) -> bool:
	return has(a, "prayer") and not skill.has("_alienMode") and int(skill.get("damage", {}).get("type", 0)) in [1, 2, 5, 6] \
		and not _in_template("attack", int(skill.get("id", 0)))


## A.blocksDamage（Aff:51）：逆祷者对敌人的生命伤害全部阻断（executeHpDamage 正值归零）
static func blocks_damage(u, t) -> bool:
	return u is XActor and t is XEnemy and has(u, "prayer")


## Runtime gainHp／setHp 包装（A.blocksDamage 在帧里）：当前帧的来源是逆祷者、目标是敌人时，扣血无效。
## 帧：行动 apply、舍身等转移、自定义状态效果（customEffectEval，来源是状态来源）
static func frame_blocks_hp(b) -> bool:
	return not _action_frames.is_empty() and blocks_damage(_action_frames[_action_frames.size() - 1].source, b)


## regenerateHp 包装（Aff:55-62）：敌人身上来源是逆祷者的状态，其负生命再生（特性 22-7）不算；返回要从 hrg 里扣掉的量（≤0）
static func prayer_regen_block(b) -> float:
	if not b is XEnemy:
		return 0.0
	var blocked := 0.0
	for st in b.states():
		var src = XImportedBalance.origin(b, int(st.id))
		if src == null or not has(src, "prayer"):
			continue
		for tr in st.get("traits", []):
			if int(tr.code) == XBattler.TRAIT_XPARAM and int(tr.dataId) == 7 and float(tr.value) < 0.0:
				blocked += float(tr.value)
	return blocked


## A.payWish（Adv:178-179）：恶愿第一次 apply 时先付代价，同一行动只判一次；付不起整次行动对谁都不生效。
## 代价：技能的增益（效果 31）变成自己的减益（直接 −1 级，回合取较长）；状态（效果 21 等）换成 statePairs 的诅咒挂到自己身上，
## 回合照原状态的最少回合。付得起的条件：减益不到 −2 级；诅咒存在，且它的每条参数倍率特性对应的参数现在 >1。
## 自己身上的这些减益与诅咒照囚厄接收的规矩（不能抵抗、驱散，清状态时保留，自然到期才去掉，Adv:155-175）
static func pay_wish(u, skill: Dictionary) -> bool:
	if skill.has("_alienWishPaid"):
		return bool(skill._alienWishPaid)
	var pairs := _pairs()
	var okay := wish_affordable(u, skill)
	skill._alienWishPaid = okay
	if not okay:
		return false
	for e in skill.get("effects", []):
		var pid := int(e.dataId)
		if int(e.code) == 31:
			u.buffs[pid] -= 1
			u.buff_turns[pid] = maxi(int(u.buff_turns[pid]), int(e.value1))
			var wb: Dictionary = u.get_meta("xalien_wish_buff", {})
			wb[pid] = true
			u.set_meta("xalien_wish_buff", wb)
		else:
			var id := int(pairs.get(str(pid), -1))
			var w: Dictionary = u.get_meta("xalien_wish", {})
			w[id] = true
			u.set_meta("xalien_wish", w)
			_state_routing += 1
			u.add_state(id)
			_state_routing -= 1
			u.state_turns[id] = int(XDB.rec("States", pid).get("minTurns", 0))
		u.param_mark_dirty()
	u.param_refresh()
	return true


## pay_wish 的「付得起」判断（不付）：智能 AI 估值用（O-待定 o_smart_ai_projection）
static func wish_affordable(u, skill: Dictionary) -> bool:
	var pairs := _pairs()
	for e in skill.get("effects", []):
		if int(e.code) == 31:
			if u.buffs[int(e.dataId)] <= -2:
				return false
		else:
			var st := XDB.rec("States", int(pairs.get(str(int(e.dataId)), -1)))
			if st.is_empty() or not (st.get("traits", []) as Array).all(func(tr): return int(tr.code) != XBattler.TRAIT_PARAM or u.param(int(tr.dataId)) > 1.0):
				return false
	return true


## 祸祝（Aff:44）：敌方（原 scope 8→2，其余→1）；增益（效果 31）改减益，其余效果的 dataId 换成 statePairs 的诅咒。
## 没有配对的 dataId 原版是 NaN（什么也不附加），重制记 -1；templates.blessing 只有 7100（附加 2421 幻日虹）
static func _project_blessing(s: Dictionary) -> Dictionary:
	var v := s.duplicate(true)
	var pairs := _pairs()
	v.scope = 2 if int(s.get("scope", 0)) == 8 else 1
	v.effects = (s.get("effects", []) as Array).map(func(e):
		var n: Dictionary = e.duplicate(true)
		if int(n.code) == 31:
			n.code = 32
		else:
			n.dataId = int(pairs.get(str(int(n.dataId)), -1))
		return n)
	v.name = "祸祝·" + str(s.get("name", ""))
	v._alienOriginal = int(s.id)
	v._alienMode = "blessing"
	v._alienOriginalScope = int(s.get("scope", 0))
	return v


# ---- 词条效果期二①：疫囊、囚厄、绝缘、舍身（状态类） ----

## A.naturalRemoval：自然到期（removeStatesAuto、腐蚀到期、囚厄转移后原主身上去掉）时放行受保护状态的移除
static var natural_removal := false
## O-106（优化登记）：原版 installNativeTojiRuntime.js:150-154（模块 9）先截下了 Game_Actor.addDebuff，installAlienationAdvanced
## 后包的 Game_Battler.addDebuff 对角色走不到，囚厄「接收队友减益」、绝缘「免疫外来减益」对角色失效（只有疫囊者经
## Game_Battler.prototype.addDebuff 走得到）。true＝照词条说明对所有角色生效；false＝照原版
static var o106_actor_debuffs := true
const STATUS_AFFIXES := ["pest", "jail", "insulation", "sacrifice", "hollow", "lifelink", "scapegoat", "wish", "prayer", "silence", "glutton"]
static var _state_routing := 0
static var _support_routing := 0
## 正在 die（阵亡状态还没加上）的战斗者：原版 isAlive 只看阵亡状态，这时疫囊者仍算活着，清状态时保留 pestStates
static var dying = null


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
	return status_battle() and has(b, "pest") and (_live(b) or is_same(b, dying)) and _in_template("pestStates", id)


## 囚厄 receiving：转移给囚厄者的状态；恶愿者为代价挂上的诅咒（_alienWish）同样保护（Adv:155-170 两者并列）
static func receiving(b, id: int) -> bool:
	return status_battle() and ((b.has_meta("xalien_jail") and bool(b.get_meta("xalien_jail").get(id, false)))
		or (b.has_meta("xalien_wish") and bool(b.get_meta("xalien_wish").get(id, false))))


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
	if positive and _affix_of(b) == "glutton":  # 饕餮（Adv:160）：登记增益不挂上，吞成饥饿储备
		feed(b, id, int(XDB.rec("States", id).get("minTurns", 0)))
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
	if (natural or natural_removal) and not b.state_ids.has(id):
		for k in ["xalien_jail", "xalien_wish"]:
			if b.has_meta(k):
				b.get_meta(k).erase(id)


## clearStates 包装：受保护的状态保留
static func keeps_state(b, id: int) -> bool:
	return status_battle() and (pest_state(b, id) or receiving(b, id) or (_insulated(b) and (positive_state(id) or id == 1)))


## clearBuffs 包装（Adv:175，阵亡时）：囚厄接收、恶愿代价的减益保留；绝缘者被外来清掉的增益保留
static func keeps_buff(b, pid: int) -> bool:
	if pid < 2 or pid > 7 or not status_battle():
		return false
	if b.buffs[pid] < 0:
		return bool(b.get_meta("xalien_jail_buff", {}).get(pid, 0)) or bool(b.get_meta("xalien_wish_buff", {}).get(pid, false))
	return b.buffs[pid] > 0 and _insulated(b)


## addBuff／addDebuff 包装：返回真＝已处理（拒收或转给别人）
static func route_buff(logic, t, pid: int, buff: bool, turns: int) -> bool:
	if not status_battle() or pid < 2 or pid > 7:
		return false
	if not buff and not o106_actor_debuffs and t is XActor and not has(t, "pest"):
		return false
	if _insulated(t):
		return true
	if buff and _affix_of(t) == "glutton":  # 饕餮（Adv:172）：增益不留在身上，按 1 层吞掉
		feed_buff(t, turns, 1)
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
	if bool(t.get_meta("xalien_wish_buff", {}).get(pid, false)):
		return true  # 恶愿代价的减益（Adv:181：不看是不是还在减益）
	return t.buffs[pid] > 0 and _insulated(t)


## gainHp／gainMp 包装：绝缘拒收外来恢复；舍身的生命恢复改给队友。返回真＝不在 b 身上结算
static func route_gain(ctx, b, resource: String, amount: float) -> bool:
	if resource == "mp" and amount != 0.0 and _affix_of(b) == "glutton" and status_battle():
		return true  # 饕餮（Adv:111）：gainMp 一律无效（回蓝、扣蓝都不结算）
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
		d.capLock = 0.0
		d.hunger = 0.0
		if str(d.affix) in ["lifelink", "scapegoat", "sacrifice"]:
			d.partner = partner_of(d)
	for a in logic.actors:
		var d = st.party.get(a)
		setup_gear(logic, a, d)  # Adv:68-71 在同一轮里、各人的生命类处理之前
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
			"glutton":
				# 饕餮（Adv:76）：MP 清零；身上的登记增益状态与增益按剩余回合吞掉
				a.mp = 0.0
				for id in a.state_ids.duplicate():
					if positive_state(id):
						feed(a, id, int(a.state_turns.get(id, 0)))
						a.remove_state(id)
				for j in range(2, 8):
					if a.buffs[j] > 0:
						feed_buff(a, a.buff_turns[j], a.buffs[j])
						a.buffs[j] = 0
						a.buff_turns[j] = 0
				a.param_mark_dirty()
				a.refresh_resources()
	st.life = logic.actors.any(func(x): return x.has_meta("xalien_life") or x.has_meta("xalien_protector"))


## endBattle 包装（Adv:196）：空壳按剩余护盾还原生命，解除生命池与保护者
static func end_life(logic) -> void:
	for a in logic.actors:
		var d = locked(a)
		if d != null and str(d.affix) == "hollow":
			a.hp = 0.0 if a.is_dead() else maxf(1.0, minf(float(d.get("referenceHp", a.hp)), maxf(0.0, a.shield)))
			a.shield = 0.0
		if d != null and str(d.affix) == "glutton":
			a.mp = minf(float(d.originalMp), float(d.referenceMp))  # Adv:196：饕餮的 MP 还原（不超过开场上限）
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


## 事件「增减 MP」（command312：actor.gainMp）：空壳、饕餮、绝缘的角色改走资源上下文的 gain，照 gainMp 包装结算
## （空壳回蓝变护盾、饕餮无效、绝缘拒收外来回蓝；事件里没有行动根，来源是自己）。返回真＝已结算
static func gain_mp_outside(b, value: float) -> bool:
	if value == 0.0 or not status_battle() or not _affix_of(b) in ["hollow", "glutton", "insulation"]:
		return false
	var logic = active_logic()
	var res: XResourceContext = logic._operation_resources(b)
	res.gain(b, "mp", value)
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


# ---- 词条效果③：缄默、饕餮（MP 费用类，installAlienationAdvanced 56-59、76、86、130-153、161、171-172、196） ----

static func _locked_affix(a, key: String):
	if not a is XActor or not battling():
		return null
	var d = locked(a)
	return d if d != null and str(d.affix) == key else null


## Game_Actor.param 包装（Adv:58）：缄默的生命上限按已锁定的比例缩小，至少 1
static func silence_param(a: XActor, v: float) -> float:
	var d = _locked_affix(a, "silence")
	return v if d == null else maxf(1.0, floorf(v * (1.0 - float(d.get("capLock", 0.0)))))


## Game_Actor.param 包装（Adv:59）：饕餮的实际 MP 上限为 0；evalDamageFormula 包装（Adv:129）里行动者、目标读开场 MP 上限
static func glutton_param(a: XActor, v: float) -> float:
	var d = _locked_affix(a, "glutton")
	if d == null:
		return v
	if not _formula_frames.is_empty():
		var f: Dictionary = _formula_frames[_formula_frames.size() - 1]
		if bool(f.get("formula", false)) and (_same(a, f.subject) or _same(a, f.target)):
			return float(d.referenceMp)
	return 0.0


## skillMpCost 包装（Adv:132）：缄默选定的技能 MP 费用为 0（面板费用 A.panelMpCost 照算）
static func silence_skill(a, skill: Dictionary) -> bool:
	var d = _locked_affix(a, "silence")
	return d != null and not XBattleLogic.is_item(skill) and int(d.config.get("skillId", 0)) == int(skill.get("id", 0))


## A.lockFee（Adv:133）：未减耗面板 MP 费用（mcr 记 1）／开场 MP 上限 × 20%
static func lock_fee(logic, a, skill: Dictionary) -> float:
	if not silence_skill(a, skill):
		return 0.0
	var d = locked(a)
	return float(logic.skill_cost(a, skill, true).mp) / maxf(1.0, float(d.referenceMp)) * 0.2


## canPaySkillCost 包装（Adv:134）：缄默锁满（累计 ≥100%）或锁后生命上限不到 1 时付不起
static func silence_blocks(logic, a, skill: Dictionary) -> bool:
	var fee := lock_fee(logic, a, skill)
	if fee <= 0.0:
		return false
	var lock := float(locked(a).get("capLock", 0.0))
	return lock + fee >= 1.0 or floorf(a.param_before_alien(0) * (1.0 - lock - fee)) < 1.0


## paySkillCost 包装（Adv:143-144）缄默段：锁定生命上限，生命截到新上限。返回假＝付不起，整次不付费
static func pay_silence(logic, a, skill: Dictionary) -> bool:
	var fee := lock_fee(logic, a, skill)
	if fee <= 0.0:
		return true
	if silence_blocks(logic, a, skill):
		return false
	var d = locked(a)
	d.capLock = float(d.get("capLock", 0.0)) + fee
	a.param_mark_dirty()
	a.hp = minf(a.hp, a.mhp)
	return true


## 饕餮的 MP 费用读、扣饥饿储备（canPaySkillCost／paySkillCost 包装把 _mp 临时换成储备，Adv:135、144）。不是饕餮返回 null
static func glutton_mp(a):
	var d = _locked_affix(a, "glutton")
	return null if d == null else float(d.get("hunger", 0.0))


static func pay_glutton(a, mp: float) -> void:
	var d = locked(a)
	d.hunger = maxf(0.0, float(d.hunger) - mp)
	a.mp = 0.0


## O-113（优化登记）：原版 installNativeTojiRuntime.js:362-366（模块 9）自己定义了 Game_Actor.prototype.isSkillTypeSealed，
## installAlienationAdvanced 后包的 Game_BattlerBase.isSkillTypeSealed 对角色走不到，缄默「绕过魔法沉默」永远不生效
## （alien_affix_probe silence 例第 3 步沉默中不能用）。true＝照词条说明绕过；false＝照原版
static var o113_silence_bypass := true


## meetsSkillConditions／isSkillTypeSealed 包装（Adv:145-149）：缄默选定的技能不受魔法沉默状态封印技能类型；
## 其他来源（别的状态、装备、职业）封的照样封
static func silence_bypass(a, skill: Dictionary) -> bool:
	if not o113_silence_bypass or not silence_skill(a, skill):
		return false
	var stype := int(skill.get("stypeId", 0))
	for o in a.trait_objects():
		if o.has("restriction") and magic_silence(o, stype):
			continue
		for t in o.get("traits", []):
			if int(t.code) == XBattler.TRAIT_STYPE_SEAL and int(t.dataId) == stype:
				return false
	return true


## A.magicSilence：名字或备注带「沉默／silence」、不限制行动、不是自定义／阶段／变身，且特性全是封这个技能类型
static func magic_silence(st: Dictionary, stype: int) -> bool:
	var text := str(st.get("name", "")) + " " + str(st.get("note", ""))
	var traits: Array = st.get("traits", [])
	return RegEx.create_from_string("(?i)沉默|silence").search(text) != null and int(st.get("restriction", 0)) == 0 \
		and RegEx.create_from_string("Custom|阶段|变身").search(str(st.get("note", ""))) == null and not traits.is_empty() \
		and traits.all(func(t): return int(t.code) == XBattler.TRAIT_STYPE_SEAL and int(t.dataId) == stype)


## A.feed（Adv:150）：吞一个登记增益状态，储备 +max(1, ⌊开场MP×min(15%, 强度×10%)×回合/2⌋)，回合夹在 1～5，储备不超过开场 MP 两倍。
## 强度＝各特性 |值−(参数／特殊参数倍率时 1)| 之和
static func feed(a, id: int, turns: int) -> float:
	var d = _locked_affix(a, "glutton")
	var st := XDB.rec("States", id)
	if d == null or st.is_empty():
		return 0.0
	var strength := 0.0
	for t in st.get("traits", []):
		strength += absf(float(t.value) - (1.0 if int(t.code) in [21, 23] else 0.0))
	var duration := clampi(turns if turns != 0 else (int(st.get("minTurns", 0)) if int(st.get("minTurns", 0)) != 0 else 1), 1, 5)
	var n := maxf(1.0, floorf(float(d.referenceMp) * minf(0.15, strength * 0.1) * duration / 2.0))
	d.hunger = minf(float(d.referenceMp) * 2.0, float(d.get("hunger", 0.0)) + n)
	return n


## A.feedBuff（Adv:151）：吞增益，储备 +max(1, ⌊开场MP×2.5%×回合(1～5)×层数⌋)
static func feed_buff(a, turns: int, level: int) -> float:
	var d = _locked_affix(a, "glutton")
	if d == null:
		return 0.0
	var n := maxf(1.0, floorf(float(d.referenceMp) * 0.025 * clampi(turns, 1, 5) * maxi(1, level)))
	d.hunger = minf(float(d.referenceMp) * 2.0, float(d.get("hunger", 0.0)) + n)
	return n


static func devour_id() -> int:
	return int(config().ids.devour)


## Game_Actor.skills 包装（Adv:86）：饕餮在战斗中多一个吞噬技能
static func devours(a) -> bool:
	return _locked_affix(a, "glutton") != null


## Game_Action.apply 包装（Adv:152）：吞噬先吞目标第一个登记增益状态，没有就吞第一个增益（2～7）；结果只记已使用、成功。
## 返回 null＝不是吞噬，照原 apply
static func devour(u, skill: Dictionary, t):
	if int(skill.get("id", 0)) != devour_id() or skill.has("_alienMode"):
		return null
	if not devours(u):
		return {}
	var id := -1
	for x in t.state_ids:
		if positive_state(x):
			id = x
			break
	if id >= 0:
		var turns := int(t.state_turns.get(id, 0))
		t.remove_state(id)
		if not t.state_ids.has(id):
			feed(u, id, turns)
	else:
		for i in range(2, 8):
			if t.buffs[i] > 0:
				var n: int = t.buffs[i]
				var r: int = t.buff_turns[i]
				t.buffs[i] = 0
				t.buff_turns[i] = 0
				t.param_mark_dirty()
				feed_buff(u, r, n)
				break
	return {"success": true}


# ---- 词条效果③：百相、无面（借技能，installAlienationAffixes 8-26、Runtime 74、91） ----
# 技能熟练度的包装（Affixes:23：借来的、仿形的取 min(自己、等级、来源)）没移植：重制熟练度恒 0（XBattler.skillMasteryLevel），取 min 不变。
# 百相切换窗口（Workshop:32-34，Window_AlienMimic）归界面：选了的仿形用 choose_mimic 写进去，没选时照 Affixes:26 的缺省。
# 没移植：原版 canEquip 包装（Runtime）带 A.ready，战斗中配置失效（无面来源忘掉技能、百相替换的技能被忘）后下一次 useItem 的 refresh
# 就把异化装备卸回背包（锁队数据仍在）；重制 can_equip 不带异化就绪、refresh 也不卸装，装备留着，下一场开战 eject_invalid 再卸。

## O-115（优化登记）：原版切换仿形没在窗口里选时换成「第一个不是当前仿形的记录」，记满 3 项时第三项永远轮不到
## （挂机、自动战斗只会在前两项之间来回）。true＝按记录顺序换到当前仿形的下一项（末项回到第一项）；false＝照原版
static var o115_mimic_cycle := true


static func switch_id() -> int:
	return int(config().ids.switch)


## A.blockedSkills：百相替换的技能、无面各对被替换的技能
static func blocked_skills(d: Dictionary) -> Array:
	match str(d.get("affix", "")):
		"mimic":
			return [int(d.get("config", {}).get("replace", 0))]
		"faceless":
			return (d.get("config", {}).get("pairs", []) as Array).map(func(p): return int(p.get("replaceId", 0)))
	return []


## Game_Actor.skills 包装（Affixes:21，战斗内外都生效）：拿掉被替换的技能；无面加借来的（可借才加、不重复）；
## 百相在战斗中加当前仿形（可借才加、不重复），记录两项以上再加切换仿形
static func skill_ids(a: XActor, ids: Array) -> Array:
	var d := XAlienation.for_actor(a)
	if d.is_empty() or not str(d.affix) in ["mimic", "faceless"]:
		return ids
	var blocked := blocked_skills(d)
	var out := ids.filter(func(id): return not blocked.has(int(id)))
	if str(d.affix) == "faceless":
		for p in d.config.get("pairs", []):
			var id := int(p.get("skillId", 0))
			if XAlienation.borrowable(XDB.rec("Skills", id)) and not out.has(id):
				out.append(id)
	elif battling():
		var sel := int(d.get("selected", 0))
		if sel != 0 and XAlienation.borrowable(XDB.rec("Skills", sel)) and not out.has(sel):
			out.append(sel)
		if (d.get("observed", []) as Array).size() > 1:
			out.append(switch_id())
	return out


## meetsSkillConditions 包装（Affixes:22）：被替换的技能不能用（当前仿形除外）；切换仿形要记录两项以上
## （原版另要求不是云裳赠行／储行的行动，重制没有这两种行动来源）；记录了但不是当前仿形、又不是自己本来会的不能用；
## 借来的技能要来源队友还在队伍里且仍会
static func blocks_borrowed(s: XState, a, skill: Dictionary) -> bool:
	if not a is XActor or XBattleLogic.is_item(skill):
		return false
	var d := XAlienation.for_actor(a)
	if d.is_empty() or not str(d.affix) in ["mimic", "faceless"]:
		return false
	var id := int(skill.get("id", 0))
	var blocked := blocked_skills(d)
	var mimic := str(d.affix) == "mimic"
	if blocked.has(id) and not (mimic and battling() and int(d.get("selected", 0)) == id):
		return true
	if mimic:
		var observed: Array = d.get("observed", [])
		if id == switch_id():
			return observed.size() <= 1
		if observed.has(id) and id != int(d.get("selected", 0)) and not (a.native_skill_ids().has(id) and not blocked.has(id)):
			return true
		return false
	for p in d.config.get("pairs", []):
		if int(p.get("skillId", 0)) == id:
			var owner := XAlienation._member(s, p.get("ownerId"))
			return owner == null or not owner.skill_ids.has(id)
	return false


## A.observe（finishAction 末尾，Affixes:24）：敌人行动根用的可借技能，记进每个活着的百相出战者（不重复、最多 3 项），第一项自动成为仿形
static func observe(logic, root: Dictionary) -> void:
	var u = root.subject
	var item: Dictionary = root.item
	if not u is XEnemy or XBattleLogic.is_item(item) or not XAlienation.borrowable(XDB.rec("Skills", int(item.get("id", 0)))):
		return
	var id := int(item.id)
	for a in logic.actors:
		var d = _locked_affix(a, "mimic")
		if d == null or not _live(a) or (d.observed as Array).has(id) or (d.observed as Array).size() >= 3:
			continue
		d.observed.append(id)
		if int(d.selected) == 0:
			d.selected = id
		_toast(logic, a.display_name() + "的百相记录了 " + str(item.get("name", "")))


## 百相切换窗口选的仿形（Scene_Battle onSkillOk 包装写的 action._alienChoice）：下一次切换仿形用它
static func choose_mimic(a, id: int) -> void:
	var d = _locked_affix(a, "mimic")
	if d != null:
		d.choice = id


## A.switchMimic：换成记录里的另一项
static func switch_mimic(a, id: int) -> bool:
	var d = _locked_affix(a, "mimic")
	if d == null or not (d.observed as Array).has(id) or id == int(d.selected):
		return false
	d.selected = id
	return true


## Game_Action.apply 包装（Affixes:26）：切换仿形不走原 apply，每次行动只换一次。返回假＝不是切换仿形
static func apply_switch(logic, u, skill: Dictionary) -> bool:
	if XBattleLogic.is_item(skill) or int(skill.get("id", 0)) != switch_id():
		return false
	var root = _store(logic).get("root") if logic.has_meta("xalien") else null
	if root != null and bool(root.get("switched", false)):
		return true
	if root != null:
		root.switched = true
	var d = _locked_affix(u, "mimic")
	if d == null:
		return true
	var id := int(d.get("choice", 0))
	d.erase("choice")
	if id == 0:
		var others := (d.observed as Array).filter(func(v): return int(v) != int(d.selected))
		if o115_mimic_cycle and not others.is_empty():
			var at := (d.observed as Array).find(int(d.selected))
			id = int(d.observed[(at + 1) % d.observed.size()]) if at >= 0 else int(others[0])
		else:
			id = int(others[0]) if not others.is_empty() else 0
	switch_mimic(u, id)
	return true


# ---- 词条效果③：蚀术（installAlienationAdvanced 123-124、145、182-185、190） ----
# 封印、上次用的技能记在本场 logic 的存储里（seals／last，按战斗者），战斗结束随 logic 一起丢掉（原版 endBattle 清 _alienSeals）。
# A.blocksDamage 的蚀术段（Adv:190）与 executeHpDamage 包装（Adv:124）条件相同、只在正伤害时生效，后者在外层先拦下，前者走不到，不另接。

## 蚀术选定的技能（config.skillId）；不是蚀术返回 0
static func erosion_skill(u) -> int:
	var d = _locked_affix(u, "erosion")
	return int(d.config.get("skillId", 0)) if d != null else 0


## executeHpDamage 包装（Adv:124，最外层）：蚀术者用选定技能、或在选定技能的行动根里造成的正生命伤害只扣目标护盾
## （扣到 0 为止），生命不变。返回真＝已处理（结果槽记生命伤害 0、生命受影响）
static func erosion_shield(logic, u, t, value: float, item: Dictionary) -> bool:
	var sid := erosion_skill(u)
	if sid == 0 or value <= 0.0:
		return false
	var root = _store(logic).get("root")
	var own := not item.is_empty() and not XBattleLogic.is_item(item) and int(item.get("id", 0)) == sid
	if not own and not (root != null and not XBattleLogic.is_item(root.item) and int(root.item.get("id", 0)) == sid):
		return false
	t.shield = maxf(0.0, t.shield - value)
	return true


static func _seals(logic, b) -> Dictionary:
	var st := _store(logic)
	if not st.has("seals"):
		st.seals = {}
	if not st.seals.has(b):
		st.seals[b] = {}
	return st.seals[b]


## 判 startAction 的「原有合法行动窗口」时不看异化封印（原版 _alienSealCheck）
static var _seal_check := false

## O-116（优化登记）：原版只在 startAction 判解封，敌人能用的行动全被封（如只会一招模板攻击）时 processTurn 没有有效行动、
## 不 startAction，封印永远解不掉，整场再也不行动。true＝敌人能动却没有有效行动的回合也算一次原有合法行动窗口；false＝照原版
static var o116_idle_release := true


## isSkillSealed／meetsSkillConditions 包装（Adv:145、183）：战斗中被蚀术封印的技能不能用（敌我都算）
static func sealed(logic, b, skill: Dictionary) -> bool:
	if _seal_check or not logic.has_meta("xalien") or not _store(logic).has("seals") or not _store(logic).seals.has(b):
		return false
	return (_store(logic).seals[b] as Dictionary).has(int(skill.get("id", 0)))


## startAction 包装（Adv:184，最外层）：技能行动记行动者上次用的技能（>2）；带封印的这次就是原有合法行动窗口，
## 列出行动结束要解的封印（能动、且不看异化封印也合技能条件的）。原版另排除云裳赠行／储行的行动，重制没有这两种来源
static func start_action(logic, u, skill: Dictionary) -> void:
	if not logic.has_meta("xalien") or skill.is_empty() or XBattleLogic.is_item(skill):
		return
	var st := _store(logic)
	if int(skill.get("id", 0)) > 2:
		if not st.has("last"):
			st.last = {}
		st.last[u] = int(skill.id)
	st.started = u
	_list_release(logic, u)


static func _list_release(logic, u) -> void:
	var st := _store(logic)
	if not st.has("seals") or (st.seals.get(u, {}) as Dictionary).is_empty():
		return
	_seal_check = true
	var ids: Array = (st.seals[u] as Dictionary).keys().filter(func(id): return logic.can_move(u) and logic.can_use(u, XDB.rec("Skills", int(id))))
	_seal_check = false
	st.release = {"subject": u, "ids": ids}


## O-116：敌人这次没有走到 startAction（没有有效行动）而能动时，照 startAction 列出要解的封印（行动结束时解）
static func idle_window(logic, u) -> void:
	if not o116_idle_release or not u is XEnemy or not logic.has_meta("xalien") or is_same(_store(logic).get("started"), u) \
			or not logic.can_move(u):
		return
	_list_release(logic, u)


## endAction 包装（Adv:185，原 endAction 之后）：解掉本次行动开始时列出的封印
static func release_seals(logic) -> void:
	var st := _store(logic)
	st.erase("started")
	var rel = st.get("release")
	st.erase("release")
	if rel != null and st.has("seals") and st.seals.has(rel.subject):
		for id in rel.ids:
			(st.seals[rel.subject] as Dictionary).erase(id)


## Game_Action.apply 包装（Adv:123，原 apply 之后）＋A.sealLast（Adv:182）：蚀术者用选定技能命中目标后，封印目标上次用的技能
## （>2 且在 templates.attack 里；目标已有异化封印就不封），封印成功也封印自己的选定技能
static func seal_last(logic, u, skill: Dictionary, t, hit: bool) -> bool:
	var sid := erosion_skill(u)
	if sid == 0 or not hit or XBattleLogic.is_item(skill) or int(skill.get("id", 0)) != sid or not logic.has_meta("xalien"):
		return false
	var id := int(_store(logic).get("last", {}).get(t, 0))
	if id <= 2 or not _in_template("attack", id) or not _seals(logic, t).is_empty():
		return false
	_seals(logic, t)[id] = true
	_seals(logic, u)[sid] = true
	return true


# ---- 词条效果④：吞器、献器（installAlienationAdvanced 28-31、43-44、62、68-71、81-90、196） ----
# 开战锁队时把要空出的装备栏原样记在本场 logic 的存储里（gear，按角色），装备栏直接置空（原版换成空 Game_Item），
# 原生插件读装备栏的部分（能力值、特性、套装、法宝、宝珠、被动缓存、武器类型条件）自然都看不到；借来的登记效果
# 作为额外特性对象接在 traitObjects 末尾（角色 meta：xalien_ghosts 自己吞的、xalien_received 献器队友给的）。
# 战斗结束（胜、逃、败，end_battle 开头，同原版 endBattle 包装在原 endBattle 之前）原样放回；重锁前也先放回。
# 装备实例不复制、不进出背包，存档只在战斗外发生，所以存读档看到的总是原装备栏。

## lockParty（Adv:68-71）：吞器空出衣服栏（装备类型 4），借供体的登记效果；献器空出全部装备栏，
## 每件装备的登记效果（异化装备本身不借）交给绑定队友。最后刷新（A.refreshGear＋refresh：被动缓存、能力值、生命／法力截到上限）
static func setup_gear(logic, a, d) -> void:
	if d == null or not str(d.affix) in ["swallow", "offer"]:
		return
	var st := _store(logic)
	if not st.has("gear"):
		st.gear = {}
	st.gear[a] = a.equips.duplicate()  # 浅拷贝：同一批装备实例
	var ghosts := []
	if str(d.affix) == "swallow":
		var g := XAlienation.effect_ghost(XAlienation._gear_by_id(logic.state, d.config.get("donorId", "")))
		if not g.is_empty():
			ghosts.append(g)
		for i in a.equips.size():
			if a.equips[i] is Dictionary and int(a.equips[i].get("etypeId", 0)) == 4:
				a.equips[i] = null
		a.set_meta("xalien_ghosts", ghosts)
	else:
		for i in a.equips.size():
			var g := XAlienation.effect_ghost(a.equips[i])
			if not g.is_empty():
				ghosts.append(g)
			a.equips[i] = null
		var p = partner_of(d)
		d.partner = p
		if p != null:
			p.set_meta("xalien_received", ghosts)
			p.refresh_passive()
			p.param_mark_dirty()
	a.refresh_passive()
	a.param_mark_dirty()
	a.refresh_resources()


## traitObjects 包装（Adv:81-85）：战斗中吞器者多供体的借用效果，献器的队友多收到的效果
static func gear_effects(a) -> Array:
	if not a.has_meta("xalien_ghosts") and not a.has_meta("xalien_received"):
		return []
	return Array(a.get_meta("xalien_ghosts", [])) + Array(a.get_meta("xalien_received", []))


## changeEquip／forceChangeEquip 包装（Adv:87 的战斗部分）：战斗中吞器、献器者与献器的队友不能换装备
static func gear_locked(a) -> bool:
	var logic = active_logic()
	return battling() and (a.has_meta("xalien_received") or logic.has_meta("xalien") and (_store(logic).get("gear", {}) as Dictionary).has(a))


## endBattle 包装（Adv:196）：装备栏原样放回，去掉借用与收到的效果，刷新。空栏里战斗中若被放进了别的装备（原版没有这种途径，
## 直接覆盖），这里退回背包，不丢件
static func restore_gear(logic) -> void:
	if not logic.has_meta("xalien"):
		return
	var st := _store(logic)
	var touched := []
	for a in st.get("gear", {}):
		var saved: Array = st.gear[a]
		for i in mini(saved.size(), a.equips.size()):
			var now = a.equips[i]
			if now is Dictionary and not now.is_empty() and not is_same(now, saved[i]):
				logic.state.gear.append(now)
			a.equips[i] = saved[i]
		touched.append(a)
	st.gear = {}
	for a in logic.actors:
		for k in ["xalien_ghosts", "xalien_received"]:
			if a.has_meta(k):
				a.remove_meta(k)
				if not touched.has(a):
					touched.append(a)
	for a in touched:
		a.refresh_passive()
		a.param_mark_dirty()
		a.refresh_resources()
