extends Node
## 175 谷雨第二期 A 战斗内机制（XGuyu：生命周期、生命储备与上限、回血记储备、生未央、花期与冷却、绽放、终结、我即万物之春不付、
## 胜利掉谷种金缮石）：与 mv_oracle/guyu_battle_probe.cjs 的冻结 v0.28 参照（generated/oracle/guyu_battle.json）逐步比。
## 每步比命中（技能、出手者、目标、生命伤害，治疗为负）与快照（回合、花期、冷却、花期序号、种子、两人储备／上限／最大生命／
## 不含储备的最大生命／生命、技能条件、累计）。技能条件只比治疗、花期、终结（花荫、转移第二期 B，重制恒不能用）。
## 另有本地断言（反向）：谷雨不在队不记储备、战斗外不加最大生命、不在花期不绽放、物品不绽放、别的角色用花期不生效。
const ORACLE := "oracle/guyu_battle.json"
const DIFFICULTY := 2
const ACTIVE := [10288, 10289, 10290, 10291, 10292]
const MEETS_COMPARED := [0, 1, 4]
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 25:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func _ready() -> void:
	_run.call_deferred()


class HalfStream extends XRandomStream:
	var stone: Array = []  # 'stone' 例给的随机数：只给谷雨掉石（reason guyu_stone），同参照只喂谷雨运行时
	func _take(kind: String, reason: String, _event_key: String):
		draws += 1
		if kind == "float" and reason == "guyu_stone" and not stone.is_empty():
			return float(stone.pop_front())
		return 0.5 if kind == "float" else 2147483648


func _state(rank: int) -> XState:
	var s := XState.new_game(DIFFICULTY, 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	s.actor_advance[XGuyu.ACTOR] = rank
	s.add_actor(XGuyu.ACTOR)
	s.add_actor(1)
	return s


func _random(stone := []) -> XBattleRandom:
	var rand := XBattleRandom.create("0000000000000175")
	rand.rule = HalfStream.new()
	rand.rule.stone = stone.duplicate()
	rand.rule.domain = "rule"
	return rand


## 同参照 battle()：新局、开 2494、队伍 [175, 1] 同级；敌人生命加 1e9；规则流全取 0.5；推进到第一回合（round 1）
func _battle(level: int, rank: int) -> XBattleLogic:
	var s := _state(rank)
	for id in [XGuyu.ACTOR, 1]:
		s.actor(id).change_level_mv(level)
	XGuyu.sync(s.actor(XGuyu.ACTOR))
	for id in [XGuyu.ACTOR, 1]:
		s.actor(id).refresh_passive()
		s.actor(id).recover_all()
	var logic := XBattleLogic.new()
	logic.elite_roll = 99.0  # 参照开战时 Math.random 0.99：不出神话、等级浮动取高端
	logic.level_roll = 0.99
	logic.setup(3, s, _random())
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e9
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
	logic.start_turn()
	for b in logic.actors + logic.enemies:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	return logic


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _row(b: XActor) -> Dictionary:
	return {"e": XGuyu.reserve(b), "cap": null if XGuyu.own(b) else (XGuyu.cap(b) if XGuyu.active_battle else 0.0), "mhp": b.mhp,
		"base": XGuyu.base_mhp(b), "hp": b.hp}


func _snap(logic: XBattleLogic) -> Dictionary:
	var s := logic.state
	return {"round": XGuyu.round, "flowerUntil": XGuyu.flower_until, "openAt": XGuyu.open_at, "serial": XGuyu.flower_serial,
		"seed": XGuyu.seed if XGuyu.seed >= 0 else null, "battle": XGuyu.active_battle,
		"party": [_row(s.actor(XGuyu.ACTOR)), _row(s.actor(1))],
		"meets": MEETS_COMPARED.map(func(i): return XGuyu.meets(s.actor(XGuyu.ACTOR), XDB.rec("Skills", ACTIVE[i]))),
		"totals": XGuyu.totals.duplicate()}


static func _norm(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = _norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	return v


func _hits(logic: XBattleLogic, logs: Array) -> Array:
	var out := []
	for l in logs:
		if not l is Dictionary or l.get("type") != "hit" or bool(l.missed) or bool(l.evaded) or not int(l.skill.get("damage", {}).get("type", 0)) in [1, 3, 5]:
			continue
		out.append({"skill": int(l.skill.id), "user": _key(logic, l.user), "target": _key(logic, l.target), "hp": float(l.hp)})
	return out


func _target(logic: XBattleLogic, skill: Dictionary, i: int) -> XBattler:
	var scope := int(skill.get("scope", 0))
	return logic.enemies[i] if scope >= 1 and scope <= 6 else logic.actors[i]


func _script(c: Dictionary) -> void:
	var logic := _battle(int(c.setup.level), int(c.setup.rank))
	var s := logic.state
	var who := func(x): return s.actor(XGuyu.ACTOR) if str(x) == "g" else s.actor(1)
	var steps: Array = c.observed.steps
	for i in steps.size():
		var want: Dictionary = steps[i]
		var st: Array = want.step
		var name := "%s.%d.%s" % [c.id, i, str(st[0])]
		var logs := []
		match str(st[0]):
			"start":
				pass
			"act":
				var skill := XDB.rec("Skills", int(st[2]))
				logs = logic.act(who.call(st[1]), skill, _target(logic, skill, int(st[3])))
			"turn":
				logs = logic.end_turn()
				logic.start_turn()
			"hp":
				who.call(st[1]).hp = float(st[2])
			"mp":
				var a: XActor = s.actor(XGuyu.ACTOR)
				a.mp = a.mmp
			"foehp":
				logic.enemies[int(st[1])].hp = float(st[2])
			"endBattle":
				logic.end_battle(0)
		if want.has("hits"):
			var got := _hits(logic, logs)
			var exp: Array = (want.hits as Array).map(func(h): return {"skill": int(h.skill), "user": str(h.user), "target": str(h.target), "hp": float(h.hp)})
			check(name + ".hits", got == exp, [got, exp])
		if want.has("foes"):
			var foes := logic.enemies.map(func(t): return t.is_alive())
			check(name + ".foes", foes == want.foes.map(func(v): return bool(v)), [foes, want.foes])
		var snap: Dictionary = _norm(_snap(logic))
		var ws: Dictionary = _norm(want.snap)
		ws.meets = MEETS_COMPARED.map(func(k): return bool(ws.meets[k]))
		for k in ws:
			check(name + "." + k, snap[k] == ws[k], [snap[k], ws[k]])
	if XGuyu.active_battle:
		logic.end_battle(0)


func _stone(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var s := _state(int(setup.rank))
	if int(setup.have) > 0:
		s.gain_item(XGuyu.STONE, int(setup.have))
	var logic := XBattleLogic.new()
	logic.setup(3, s, _random([float(setup.draw)]))
	logic.end_battle(0)
	var got := {"stones": s.item_count(XGuyu.STONE), "battle": XGuyu.active_battle}
	check(c.id, got.stones == int(c.observed.stones) and got.battle == bool(c.observed.battle), [got, c.observed])


## 反向：谷雨不在出战（只有 1 号）时治疗不记储备、战斗外不加最大生命、物品与不在花期不绽放、别人用不了花期也不生效
func _local() -> void:
	var logic := _battle(35, 0)
	var s := logic.state
	var a: XActor = s.actor(XGuyu.ACTOR)
	var hero: XActor = s.actor(1)
	logic.act(a, XDB.rec("Skills", 10288), a)
	var e := XGuyu.reserve(hero)
	check("local.reserve_in_mhp", e > 0.0 and hero.mhp == XGuyu.base_mhp(hero) + e, [e, hero.mhp])
	var logs := logic.act(hero, XDB.rec("Skills", 1), logic.enemies[0])
	check("reverse.no_bloom_outside_flower", not _hits(logic, logs).any(func(h): return h.skill == XGuyu.BLOOM) and XGuyu.reserve(hero) == e)
	logic.act(a, XDB.rec("Skills", 10289), logic.enemies[1])
	var potion := -1
	for id in range(1, 40):
		var it := XDB.rec("Items", id)
		if not it.is_empty() and int(it.get("damage", {}).get("type", 0)) == 3 and int(it.get("scope", 0)) == 7:
			potion = id
			break
	if potion > 0:
		s.gain_item(potion, 1)
		logs = logic.act(hero, XDB.rec("Items", potion), hero)
		check("reverse.item_no_bloom", not _hits(logic, logs).any(func(h): return h.skill == XGuyu.BLOOM), potion)
	logs = logic.act(hero, XDB.rec("Skills", 10289), logic.enemies[0])
	check("reverse.other_open", XGuyu.flower_serial == 1 and XGuyu.seed == 1, [XGuyu.flower_serial, XGuyu.seed])
	logic.end_battle(0)
	check("local.after_battle", not XGuyu.active_battle and XGuyu.reserve(hero) == 0.0 and hero.mhp == XGuyu.base_mhp(hero) and hero.hp <= hero.mhp)
	# 谷雨不在出战：只有 1 号
	var s2 := XState.new_game(DIFFICULTY, 1, [8])
	XState.current = s2
	var solo := XBattleLogic.new()
	solo.setup(3, s2, _random())
	solo.start_turn()
	var h2: XActor = s2.actor(s2.party[0])
	h2.hp = 1.0
	solo.act(h2, XDB.rec("Skills", 1), solo.enemies[0])
	var rc := XResourceContext.new()
	rc.gain(h2, "hp", 50.0)
	check("reverse.no_guyu_no_reserve", XGuyu.reserve(h2) == 0.0 and XGuyu.active() == null)
	solo.end_battle(1)


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := 0
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if c.errors.is_empty():
			seen += 1
			if str(c.id).begins_with("stone."):
				_stone(c)
			else:
				_script(c)
	check("covers_all", seen == 9, seen)
	_local()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_guyu_battle", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
