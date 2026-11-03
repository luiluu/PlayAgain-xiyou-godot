extends Node
## 【cc·八戒·未经审查】成长装备期一 XHeartsteel／XHubris：照参照 heartsteel_probe（tests/fixtures/heartsteel_oracle.json）逐例比。
## 新装备实例的随机词条照参照记下的实例属性与特性设（重制自己的词条掷法另有专项）。
## 战斗例：新局队伍 [1, 8, 9, 10]，角色 1 穿上；打 3 号敌群（敌人生命加 1e9），规则流全取 0.5，推进到第一回合，照参照的步骤逐步比。
## hubris.battle.* 是原版口径（KILL_FIX 关：击杀记不上），hubris.fix.* 是修复口径（O-150，默认开）。
const FIXTURE := "res://tests/fixtures/heartsteel_oracle.json"
const PARTY := [1, 8, 9, 10]
## 参照里量了、不在这里比的（draws 由各掉落例自己比）。recipes／unlocked 期二锻造解锁已做，掉落例里比；desc 胜利后的说明（describe）在胜利行比
const PENDING_FIELDS := ["draws"]
var checks := 0
var failures: Array = []
var logic: XBattleLogic


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 30:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1200))


class HalfStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648
	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return floori(n * 0.5) if n > 0 else 0
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return lo + floori((hi - lo + 1) * 0.5)


## 掉落例用：只要 state、troop_id、_rule
class RewardLogic extends RefCounted:
	var state: XState
	var troop_id := 0
	var stream := HalfStream.new()
	func _rule() -> XRandomStream:
		return stream


func _num(a, b) -> bool:
	return absf(float(a) - float(b)) < 1e-6


func _new_state() -> XState:
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	return s


## 入包一件、照参照设实例（属性、特性、成长字段），穿到角色身上
func _gear(s: XState, a: XActor, base: int, inst: Dictionary, fields: Dictionary) -> Dictionary:
	# 不掷词条（词条除特性外还会并入备注、元数据、套装），实例的特性直接照参照设
	var tpl := XGear.template("armor", base)
	tpl.equipment = (tpl.equipment as Dictionary).duplicate(true)
	tpl.equipment.affixes = []
	var it := XGear.roll_item(tpl, s)
	s.register_gear(it)
	s.gear.append(it)
	it.params = (inst.params as Array).map(func(v): return float(v))
	it.traits = (inst.traits as Array).map(func(t): return {"code": int(t[0]), "dataId": int(t[1]), "value": float(t[2])})
	for k in fields:
		it[k] = fields[k]
	var slot := a.equip_slots().find(17)
	XEquipment.change(s, a, slot, it)
	a.refresh_passive()
	a.param_mark_dirty()
	return it


func _listed(a: XActor) -> Array:
	return a.skills().map(func(x): return int(x.id)).filter(func(id): return id in [XHeartsteel.SKILL, XHeartsteel.LEV_SKILL])


func _meets(a: XActor) -> Array:
	return [XHeartsteel.SKILL, XHeartsteel.LEV_SKILL].map(func(id): return XHeartsteel.meets(a, XDB.rec("Skills", id)))


func _case_math(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	check("math.stage", (o.ks as Array).map(func(k): return XHeartsteel.stage_of(float(k))) == (o.stage as Array).map(func(v): return int(v)))
	check("math.need", [0, 1, 2, 3, 10, 50].map(func(n): return XHeartsteel.stage_need(n)) == (o.need as Array).map(func(v): return int(v)))


func _case_heart_param(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_state()
	var a := s.actor(1)
	check(c.id + ".before", _num(a.mhp, o.before.mhp) and _num(a.atk, o.before.atk), [a.mhp, a.atk, o.before])
	var it := _gear(s, a, int(c.setup.base), o.inst, {XHeartsteel.STACKS: int(c.setup.stacks), XHeartsteel.LEGACY_HP: int(c.setup.hp)})
	check(c.id + ".slot", a.equip_slots().find(17) == int(o.slot))
	var got := {"mhp": a.mhp, "atk": a.atk, "def": a.def, "mdf": a.mdf, "rate": XHeartsteel.hp_rate(it), "stage": XHeartsteel.stage(it),
		"castScale": XHeartsteel.cast_scale(a), "effectiveHp": XHeartsteel.effective_hp(a)}
	for k in got:
		check(c.id + "." + k, _num(got[k], o[k]), [got[k], o[k]])
	check(c.id + ".listed", _listed(a) == (o.listed as Array).map(func(v): return int(v)), [_listed(a), o.listed])
	XHeartsteel.in_battle = false
	check(c.id + ".meetsOut", _meets(a) == o.meetsOut, [_meets(a), o.meetsOut])
	XHeartsteel.in_battle = true
	for w in [2, 1, 0]:
		XHeartsteel._wait[1] = w
		check(c.id + ".meets%d" % w, _meets(a) == o["meets%d" % w], [_meets(a), o["meets%d" % w]])
	XHeartsteel._wait.erase(1)
	check(c.id + ".meetsUnset", _meets(a) == o.meetsUnset)
	XHeartsteel.in_battle = false


func _case_hubris_param(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_state()
	var a := s.actor(1)
	var it := _gear(s, a, int(c.setup.base), o.inst, {XHubris.FAME: int(c.setup.fame)})
	check(c.id + ".base", _num(a.mhp, o.mhp) and _num(a.atk, o.atk) and _num(XHubris.rate_for(it, float(c.setup.fame)), o.rate), [a.mhp, a.atk, o])
	check(c.id + ".listed", _listed(a).is_empty())
	XHeartsteel.in_battle = true
	XHubris._buff[1] = {"item": it, "rate": XHubris.rate_for(it, float(c.setup.fame)), "round": 0, "remaining": 3}
	a.param_mark_dirty()
	check(c.id + ".atkBuffed", _num(a.atk, o.atkBuffed), [a.atk, o.atkBuffed])
	XHeartsteel.in_battle = false
	a.param_mark_dirty()
	check(c.id + ".atkOutside", _num(a.atk, o.atkOutside) and XHubris._buff.has(1) == bool(o.buffAfterOutside), [a.atk, o.atkOutside, XHubris._buff.has(1)])


func _case_reward(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var st: Dictionary = c.setup
	var s := _new_state()
	s.map_id = int(st.map)
	s.unknown_origin = int(st.origin) if st.origin != null else null
	s.variables[107] = int(st.v107)
	var l := RewardLogic.new()
	l.state = s
	l.troop_id = int(st.troop)
	l.stream.value = float(st.r)
	XHeartsteel._reward_rolled = false
	XHubris._reward_rolled = false
	var heart := XHeartsteel.clear_reward(l, int(st.result))
	var hubris := XHubris.clear_reward(l, int(st.result))
	var again := [XHeartsteel.clear_reward(l, int(st.result)), XHubris.clear_reward(l, int(st.result))]
	var count := func(id): return s.gear.filter(func(e): return str(e.kind) == "armor" and int(e.base) == id).size()
	var got := {"origin": XHeartsteel.unknown_origin(s), "heart": heart, "hubris": hubris, "again": again, "armors": [count.call(7900), count.call(7902)],
		"recipes": [XCrafting.known(s, XCrafting.recipe(457)), XCrafting.known(s, XCrafting.recipe(458))],
		"unlocked": [bool(s.crafting.get("codexLeviathanUnlocked", false)), bool(s.crafting.get("codexAtaraxiaUnlocked", false))]}
	# 这个探针没建配方表，没学过的 recipeKnown 是 undefined（记成 null），按没学会
	var want := o.duplicate()
	want.recipes = (o.recipes as Array).map(func(v): return v == true)
	for k in got:
		check(c.id + "." + k, JSON.stringify(got[k]) == JSON.stringify(want[k]).replace(".0", ""), [got[k], want[k]])


func _case_weight(c: Dictionary) -> void:
	var names: Array = c.observed.names
	var want: Array = c.observed.out["3"].heart
	var got := names.map(func(n): return XHeartsteel.name_weight(NameStub.new(n)))
	check("weight.names", got == want.map(func(v): return int(v)), [got, want])


class NameStub extends RefCounted:
	var n := ""
	func _init(name: String) -> void:
		n = name
	func data() -> Dictionary:
		return {"name": n}


func _case_damage(c: Dictionary) -> void:
	var s := _new_state()
	var a := s.actor(1)
	for row in c.observed.rows:
		var tgt := DefStub.new(float(row[1]))
		for k in [2, 3]:
			XHeartsteel._cast[1] = {"valid": k == 2, "base": float(row[0])}
			check("damage.%s.%s.%d" % [row[0], row[1], k], _num(XHeartsteel.formula(a, tgt), row[k]), [XHeartsteel.formula(a, tgt), row])
	XHeartsteel._cast.clear()


class DefStub extends RefCounted:
	var def := 0.0
	func _init(v: float) -> void:
		def = v


# ---- 战斗 ----
func _key(b) -> Variant:
	if b == null:
		return null
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _hits(logs: Array) -> Array:
	var out := []
	for l in logs:
		if l is Dictionary and l.get("type") == "hit" and not bool(l.get("unused", false)) and not bool(l.missed) and not bool(l.evaded) \
				and int(l.skill.get("damage", {}).get("type", 0)) in [1, 3, 5]:
			out.append([_key(l.user), _key(l.target), float(l.get("state_value", l.hp))])
	return out


func _set_hp(b, v: float) -> void:
	var rc := logic._operation_resources(b)
	rc.set_resource(b, "hp", v)
	logic._finish_lifecycle_operation(rc, b)


## party／levels／prep：审查第 29 期两例换队伍（同参照 battle2：开 2494、等级上限 99，prep 在排队伍之前）
func _battle(base: int, inst: Dictionary, fields: Dictionary, party: Array = PARTY, levels := {}, prep := Callable()) -> Dictionary:
	var s := _new_state()
	if party != PARTY:
		s.actor_max_level = 99
		s.switches[2494] = true
		if prep.is_valid():
			prep.call(s)
		s.party.clear()
		s.battle_slots.clear()
		for id in party:
			s.add_actor(id)
		for id in levels:
			s.actor(int(id)).change_level_mv(int(levels[id]))
	var a := s.actor(1)
	var it := _gear(s, a, base, inst, fields)
	if party.has(XGuyu.ACTOR):
		XGuyu.sync(s.actor(XGuyu.ACTOR))
	for id in party:
		s.actor(id).refresh_passive()
		s.actor(id).recover_all()
	var l := XBattleLogic.new()
	l.elite_roll = 99.0
	l.level_roll = 0.99
	var rand := XBattleRandom.create("0000000000007900")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	l.setup(3, s, rand)
	for e in l.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e9
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
	l.start_turn()
	for b in l.actors + l.enemies:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	logic = l
	return {"a": a, "it": it}


func _act(u, skill_id: int, target: int) -> Array:
	return _hits(logic.act(u, XDB.rec("Skills", skill_id), logic.enemies[target]))


func _turn() -> void:
	logic.end_turn()
	logic.start_turn()


func _heart_snap(ctx: Dictionary) -> Dictionary:
	var a: XActor = ctx.a
	return {"hp": a.hp, "mhp": a.mhp, "wait": XHeartsteel.remaining(a), "casted": bool(XHeartsteel._casted.get(1, false)), "pending": XHeartsteel.pending(ctx.it),
		"stacks": XHeartsteel.stacks(ctx.it), "meets": [XHeartsteel.SKILL, XHeartsteel.LEV_SKILL].map(func(id): return logic.can_use(a, XDB.rec("Skills", id))), "round": logic.turn}


func _hubris_snap(ctx: Dictionary) -> Dictionary:
	var a: XActor = ctx.a
	var b = XHubris.buff(a)
	return {"atk": a.atk, "buff": {"rate": b.rate, "round": b.round, "remaining": b.remaining} if b != null else null, "pending": XHubris.pending(ctx.it),
		"fame": XHubris.growth(ctx.it), "moves": int(XHubris._moves.get(1, 0)), "round": logic.turn}


func _same(got, want) -> bool:
	if want is Dictionary:
		if not (got is Dictionary):
			return false
		for k in want:
			if k in PENDING_FIELDS:
				continue
			if not got.has(k) or not _same(got[k], want[k]):
				return false
		return true
	if want is Array:
		if not (got is Array) or got.size() != want.size():
			return false
		for i in want.size():
			if not _same(got[i], want[i]):
				return false
		return true
	if want is float or want is int:
		return (got is float or got is int) and _num(got, want)
	return got == want


func _cmp(tag: String, got, want) -> void:
	check(tag, _same(got, want), [got, want])


func _case_heart_battle(c: Dictionary) -> void:
	var rows: Array = c.observed.rows
	var ctx := _battle(int(c.setup.base), rows[0][2].inst, {XHeartsteel.STACKS: int(c.setup.stacks)})
	var a: XActor = ctx.a
	var sid := XHeartsteel.skill_for(ctx.it)
	var want := {}
	for r in rows:
		want[r[0]] = r
	_cmp(c.id + ".start", _heart_snap(ctx), want.start[1])
	_cmp(c.id + ".early", [_act(a, sid, 0), _heart_snap(ctx)], want.early.slice(1))
	_cmp(c.id + ".attack1", [_act(a, 1, 0).size(), _heart_snap(ctx)], want.attack1.slice(1))
	_cmp(c.id + ".attack2", [_act(a, 1, 0).size(), _heart_snap(ctx)], want.attack2.slice(1))
	_cmp(c.id + ".eff", [XHeartsteel.effective_hp(a), a.mhp], want.eff.slice(1))
	_cmp(c.id + ".cast", [_act(a, sid, 0), _heart_snap(ctx)], want.cast.slice(1))
	_cmp(c.id + ".recast", [_act(a, sid, 0), _heart_snap(ctx)], want.recast.slice(1))
	_set_hp(a, 1)
	_turn()
	_cmp(c.id + ".turn", _heart_snap(ctx), want.turn[1])
	_turn()
	_cmp(c.id + ".turn2", _heart_snap(ctx), want.turn2[1])
	for i in 3:
		_act(a, 1, 0)
	_cmp(c.id + ".attacks3", _heart_snap(ctx), want.attacks3[1])
	_cmp(c.id + ".cast2", [_act(a, sid, 0), _heart_snap(ctx)], want.cast2.slice(1))
	logic.end_battle(0)
	_cmp(c.id + ".victory", {"stacks": XHeartsteel.stacks(ctx.it), "pending": XHeartsteel.pending(ctx.it), "mhp": a.mhp,
		"desc": XGrowthHelp.view(ctx.it).description}, want.victory[1])


func _case_heart_escape(c: Dictionary, inst: Dictionary) -> void:
	var ctx := _battle(7900, inst, {XHeartsteel.STACKS: 5})
	var a: XActor = ctx.a
	_act(a, 1, 0)
	_act(a, 1, 0)
	var cast := _act(a, XHeartsteel.SKILL, 0)
	var pending := XHeartsteel.pending(ctx.it)
	logic.end_battle(1)
	_cmp(c.id, {"cast": cast, "pending": pending, "stacks": XHeartsteel.stacks(ctx.it)}, c.observed)


func _case_hubris_battle(c: Dictionary) -> void:
	var rows: Array = c.observed.rows
	XHubris.KILL_FIX = false
	var ctx := _battle(int(c.setup.base), rows[0][2].inst, {XHubris.FAME: int(c.setup.fame)})
	var a: XActor = ctx.a
	var e: Array = logic.enemies
	var want := {}
	for r in rows:
		want[r[0]] = r
	_cmp(c.id + ".start", _hubris_snap(ctx), want.start[1])
	_cmp(c.id + ".attack", [_act(a, 1, 0), _hubris_snap(ctx)], want.attack.slice(1))
	_set_hp(e[0], 1)
	_cmp(c.id + ".kill", [_act(a, 1, 0), _hubris_snap(ctx), e[0].is_dead()], want.kill.slice(1))
	_cmp(c.id + ".attackBuffed", [_act(a, 1, 1), _hubris_snap(ctx)], want.attackBuffed.slice(1))
	for i in 5:
		_turn()
		_cmp(c.id + ".turn%d" % i, _hubris_snap(ctx), want["turn%d" % i][1])
	_set_hp(e[2], 1)
	_act(a, 1, 2)
	_cmp(c.id + ".kill2", _hubris_snap(ctx), want.kill2[1])
	logic.end_battle(0)
	_cmp(c.id + ".victory", {"fame": XHubris.growth(ctx.it), "pending": XHubris.pending(ctx.it), "buff": XHubris._buff.has(1), "atk": a.atk}, want.victory[1])
	XHubris.KILL_FIX = true


func _case_hubris_mode(c: Dictionary) -> void:
	var rows: Array = c.observed.rows
	var mode := str(c.setup.mode)
	XHubris.KILL_FIX = true
	var eid := int((XDB.rec("Troops", 3).members as Array)[0].enemyId)
	var rec := XDB.rec("Enemies", eid)
	var old_name := str(rec.name)
	if mode == "boss":
		rec.name = "【首领】" + old_name
	var ctx := _battle(int(c.setup.base), rows[0][2].inst, {XHubris.FAME: int(c.setup.fame)})
	var a: XActor = ctx.a
	var e: Array = logic.enemies
	var other: XActor = logic.state.actor(8)
	var want := {}
	for r in rows:
		want[r[0]] = r
	_cmp(c.id + ".start", _hubris_snap(ctx), want.start[1])
	if mode == "fix":
		_set_hp(e[0], 1)
		_cmp(c.id + ".kill", [_act(a, 1, 0), _hubris_snap(ctx)], want.kill.slice(1))
		_cmp(c.id + ".attackBuffed", [_act(a, 1, 1), _hubris_snap(ctx)], want.attackBuffed.slice(1))
		_act(other, 1, 1)
		_act(other, 1, 1)
		_set_hp(e[1], 1)
		_cmp(c.id + ".killByOther", [_act(other, 1, 1), _hubris_snap(ctx)], want.killByOther.slice(1))
		for i in 2:
			_turn()
			_cmp(c.id + ".turn%d" % i, _hubris_snap(ctx), want["turn%d" % i][1])
		_act(a, 1, 2)
		_act(other, 1, 2)
		_set_hp(e[2], 1)
		_cmp(c.id + ".assist", [_act(other, 1, 2), _hubris_snap(ctx)], want.assist.slice(1))
		for i in range(2, 6):
			_turn()
			_cmp(c.id + ".turn%d" % i, _hubris_snap(ctx), want["turn%d" % i][1])
	else:
		var b = e[0]
		for step in [["seg", 0.95, a], ["seg2", 0.62, a], ["segOther", 0.50, other]]:
			_set_hp(b, floorf(b.mhp * float(step[1])))
			_cmp(c.id + "." + step[0], [_act(step[2], 1, 0), _hubris_snap(ctx), int(XHubris._seg.get(b, 0))], want[step[0]].slice(1))
		for i in 5:
			_turn()
			_cmp(c.id + ".turn%d" % i, _hubris_snap(ctx), want["turn%d" % i][1])
		_set_hp(b, floorf(b.mhp * 0.05))
		_cmp(c.id + ".seg9", [_act(a, 1, 0), _hubris_snap(ctx), int(XHubris._seg.get(b, 0))], want.seg9.slice(1))
	_set_hp(a, 0)
	_cmp(c.id + ".dead", _hubris_snap(ctx), want.dead[1])
	logic.end_battle(0)
	_cmp(c.id + ".victory", {"fame": XHubris.growth(ctx.it), "pending": XHubris.pending(ctx.it), "buff": XHubris._buff.has(1)}, want.victory[1])
	rec.name = old_name


func _case_pierce(c: Dictionary) -> void:
	for base in ["0", "7902", "7903"]:
		var o: Dictionary = c.observed[base]
		var ctx := _battle(7900 if base == "0" else int(base), o.inst, {})
		var a: XActor = ctx.a
		if base == "0":
			XEquipment.change(logic.state, a, a.equip_slots().find(17), null)
			a.refresh_passive()
			a.param_mark_dirty()
		_cmp(c.id + "." + base, {"atk": a.atk, "def": logic.enemies[1].def, "hits": _act(a, 1, 1)}, {"atk": o.atk, "def": o.def, "hits": o.hits})


## 审查第 29 期 P3-1：屠苏剑气（屠苏 endAction 前半段）打死的敌人，狂妄（里层）在同一次 endAction 结算（击杀按修复口径）
func _case_order_tusu(c: Dictionary) -> void:
	var rows: Array = c.observed.rows
	XHubris.KILL_FIX = true
	var ctx := _battle(7902, rows[0][2].inst, {XHubris.FAME: 0}, [1, 8, XTusu.ACTOR, 10], {XTusu.ACTOR: 60}, func(s): XTusuXuan.recruit(s, XTusu.ACTOR))
	var a: XActor = ctx.a
	var e: Array = logic.enemies
	var tusu: XActor = logic.state.actor(XTusu.ACTOR)
	var want := {}
	for r in rows:
		want[r[0]] = r
	_cmp(c.id + ".start", _hubris_snap(ctx), want.start[1])
	logic.act(tusu, XDB.rec("Skills", XTusu.skill_id("huawu.sword")), a)
	var h = XBinding.host(tusu)
	_cmp(c.id + ".huawu", [_hubris_snap(ctx), "a%d" % h.actor_id if h != null else null], want.huawu.slice(1))
	_cmp(c.id + ".attack", [_act(a, 1, 0), _hubris_snap(ctx)], want.attack.slice(1))
	_set_hp(e[0], 1)
	XBinding.gain(tusu, 3)
	_cmp(c.id + ".zhanfeng", [_act(a, XTusu.skill_id("arm.zhanfeng"), 1), _hubris_snap(ctx), e[0].is_dead()], want.zhanfeng.slice(1))
	_turn()
	_cmp(c.id + ".turn", _hubris_snap(ctx), want.turn[1])


func _guyu_snap(ctx: Dictionary) -> Dictionary:
	var g: XActor = logic.state.actor(XGuyu.ACTOR)
	return {"heart": _heart_snap(ctx), "flowerUntil": XGuyu.flower_until, "seed": XGuyu.seed if XGuyu.seed >= 0 else null,
		"reserve": [XGuyu.reserve(g), XGuyu.reserve(ctx.a)], "blooms": XGuyu.totals.get("blooms", 0), "spent": XGuyu.totals.get("spent", 0)}


## 审查第 29 期 P3-2：花期里穿心之钢的 1 号被强制放没蓄满的巨人吞噬，心钢在谷雨 apply 里层拦下，谷雨已置执行标记，绽放照样触发
func _case_order_guyu(c: Dictionary) -> void:
	var rows: Array = c.observed.rows
	var ctx := _battle(7900, rows[0][2].inst, {XHeartsteel.STACKS: 0}, [XGuyu.ACTOR, 1], {XGuyu.ACTOR: 35, 1: 35})
	var a: XActor = ctx.a
	var g: XActor = logic.state.actor(XGuyu.ACTOR)
	var want := {}
	for r in rows:
		want[r[0]] = r
	_cmp(c.id + ".start", _guyu_snap(ctx), want.start[1])
	_act(g, 10288, 0)
	_act(g, 10288, 0)
	_cmp(c.id + ".heal", _guyu_snap(ctx), want.heal[1])
	_cmp(c.id + ".open", [_act(g, 10289, 0), _guyu_snap(ctx)], want.open.slice(1))
	var logs := logic._force_action([1, 1, XHeartsteel.skill_for(ctx.it), 1], null)
	_cmp(c.id + ".forced", [_hits(logs), _guyu_snap(ctx)], want.forced.slice(1))
	_cmp(c.id + ".attack", [_act(a, 1, 1), _guyu_snap(ctx)], want.attack.slice(1))


## 存档：层数／盛名随实例存读（穿着的和背包里的）；旧档实例没有这两个字段按 0（原版 growth／stacks 缺省 0）
func _case_save(inst: Dictionary) -> void:
	var s := _new_state()
	var a := s.actor(1)
	var worn := _gear(s, a, XHeartsteel.ARMOR, inst, {XHeartsteel.STACKS: 350, XHeartsteel.LEGACY_HP: 7})
	var mhp := a.mhp
	s.gain_gear("armor", XHubris.ARMOR, 1)
	var bag: Dictionary = s.gear[s.gear.size() - 1]
	bag[XHubris.FAME] = 42
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var r := XState.from_dict(d)
	XState.current = r
	var g := XHeartsteel.gear(r.actor(1))
	check("save.worn", XHeartsteel.stacks(g) == 350 and XHeartsteel.growth(g) == 7 and _num(r.actor(1).mhp, mhp), [g.get(XHeartsteel.STACKS), r.actor(1).mhp, mhp])
	var b := r.gear.filter(func(e): return XHubris.is_gear(e))
	check("save.bag", b.size() == 1 and XHubris.growth(b[0]) == 42, b.size())
	worn.erase(XHeartsteel.STACKS)
	worn.erase(XHeartsteel.LEGACY_HP)
	bag.erase(XHubris.FAME)
	var old := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	XState.current = old
	var og := XHeartsteel.gear(old.actor(1))
	check("save.legacy", not og.is_empty() and XHeartsteel.stacks(og) == 0 and XHeartsteel.growth(og) == 0 and _num(XHeartsteel.hp_rate(og), 1.0) \
		and XHubris.growth(old.gear.filter(func(e): return XHubris.is_gear(e))[0]) == 0)


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var heart_inst := {}
	for c in data.cases:
		check(c.id + ".oracle", (c.errors as Array).is_empty(), c.errors)
		var id := str(c.id)
		if id == "math":
			_case_math(c)
		elif id.begins_with("heart.param."):
			_case_heart_param(c)
			if int(c.setup.base) == XHeartsteel.ARMOR:
				heart_inst = c.observed.inst  # 逃跑例穿的是心之钢
		elif id.begins_with("hubris.param."):
			_case_hubris_param(c)
		elif id.begins_with("reward."):
			_case_reward(c)
		elif id == "weight":
			_case_weight(c)
		elif id == "damage":
			_case_damage(c)
		elif id == "heart.battle.escape":
			_case_heart_escape(c, heart_inst)
		elif id.begins_with("heart.battle."):
			_case_heart_battle(c)
		elif id.begins_with("hubris.battle."):
			_case_hubris_battle(c)
		elif id.begins_with("hubris.fix.") or id.begins_with("hubris.boss."):
			_case_hubris_mode(c)
		elif id == "hubris.pierce":
			_case_pierce(c)
		elif id == "order.tusu":
			_case_order_tusu(c)
		elif id == "order.guyu":
			_case_order_guyu(c)
		else:
			check(id + ".unhandled", false)
	_case_save(heart_inst)
	XHeartsteel.in_battle = false
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_heartsteel", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
