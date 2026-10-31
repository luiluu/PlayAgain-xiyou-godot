extends Node
## 渡鸦 167 灵魂积累与铸印（XRaven 第二期：on_enemy_death／soul_gain／award_seal／after_advance，存档 codexRaven）：
## 与 mv_oracle/raven_soul_probe.cjs 的冻结 v0.28 参照（generated/oracle/raven_soul.json）逐例比。
## - gain.*：七个敌人（经验 0～25000、首领备注 <Boss>）× 神话与否倒下时的经验、得魂，复活再倒下不再计；渡鸦在后备（战斗外仍算）、不在队；
## - seal.*：各阶差 10 魂时倒下一个敌人（30 魂）的铸印、再倒一个不重复；背包已有进阶印不再给；五阶不给；
## - spent.r2：本阶铸过印、印没了再得魂，本阶不再给；
## - advance.*：本阶已铸、灵魂够下一阶时进阶确认：阶、灵魂清零、铸印、进阶印数、专属技能；
## - 另核存档往返（codexRaven）与旧档没有该键。
const ORACLE := "oracle/raven_soul.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


## 同参照 setup()：新局、开挑战开关 2494、入队名单 party、渡鸦进阶 rank、level 级
func _setup(level: int, rank: int, party: Array) -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.set_switch(2494, true)
	s.party.clear()
	s.battle_slots.clear()
	for id in party:
		s.add_actor(int(id))
	s.actor_advance[XRaven.ACTOR] = rank
	s.actor(XRaven.ACTOR).change_level_mv(level)
	return s


func _enemy(s: XState, id: int, elite: bool) -> XEnemy:
	var e := XEnemy.new().setup(id, s.difficulty, 100.0)
	e.elite = elite and not str(e.data().get("note", "")).contains("NoElite")
	return e


func _seals(s: XState) -> int:
	return s.item_count(XRaven.SEAL)


func _gain(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var setup: Dictionary = c.setup
	var s := _setup(int(setup.level), int(setup.rank), setup.party)
	var a := s.actor(XRaven.ACTOR)
	if setup.has("elite"):
		var e := _enemy(s, int(setup.enemy), bool(setup.elite))
		check(c.id + ".exp", XRaven.enemy_exp(e) == int(o.exp) and e.elite == bool(o.isElite), [XRaven.enemy_exp(e), e.elite, o.exp, o.isElite])
		var before := XRaven.soul(a)
		e.add_state(1)
		var once := XRaven.soul(a) - before
		e.remove_state(1)
		e.hp = 1.0
		e.add_state(1)
		check(c.id + ".gain", [once, XRaven.soul(a) - before - once] == [float(o.gain), float(o.again)], [once, XRaven.soul(a), o])
	else:
		var members := s.members().map(func(b): return b.actor_id)
		check(c.id + ".members", members == (o.members as Array).map(func(v): return int(v)), [members, o.members])
		var before := XRaven.soul(a)
		_enemy(s, int(setup.enemy), false).add_state(1)
		check(c.id + ".gain", XRaven.soul(a) - before == float(o.gain), [XRaven.soul(a) - before, o.gain])


func _state_of(s: XState, s0: int) -> Dictionary:
	return {"soul": XRaven.soul(s.actor(XRaven.ACTOR)), "seals": _seals(s) - s0, "forged": XRaven.forged()}


func _same(got: Dictionary, want: Dictionary) -> bool:
	return got.soul == float(want.soul) and got.seals == int(want.seals) and got.forged == int(want.forged)


func _seal(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _setup(int(c.setup.level), int(c.setup.rank), c.setup.party)
	if int(c.setup.preSeals) > 0:
		s.gain_item(XRaven.SEAL, int(c.setup.preSeals))
	check(c.id + ".need", XRaven.REQUIRE[mini(5, int(c.setup.rank) + 1)] == int(o.need))
	s.raven["soul"] = float(o.need) - 10.0
	var s0 := _seals(s)
	_enemy(s, 180, false).add_state(1)
	var first := _state_of(s, s0)
	check(c.id + ".first", _same(first, o.first), [first, o.first])
	_enemy(s, 180, false).add_state(1)
	var second := _state_of(s, s0)
	check(c.id + ".second", _same(second, o.second), [second, o.second])


func _advance(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var rank := int(c.setup.rank)
	var s := _setup(int(c.setup.level), rank, c.setup.party)
	var a := s.actor(XRaven.ACTOR)
	XRaven.sync(a)
	s.raven = {"soul": float(c.setup.soul), "forged": rank}
	var r = XAdvance.row(s, XRaven.ACTOR)
	for p in r.items:
		s.gain_item(int(p[0]), int(p[1]))
	s.gain_gold(int(r.gold))
	var s0 := _seals(s)
	check(c.id + ".advanced", XAdvance.advance(s, a))
	var skills := a.skill_ids.filter(func(i): return (i >= 10122 and i <= 10139) or i == 10170)
	skills.sort()
	var got := {"rank": XAdvance.rank(s, XRaven.ACTOR), "soul": XRaven.soul(a), "forged": XRaven.forged(), "seals": _seals(s) - s0}
	check(c.id + ".state", got.rank == int(o.rank) and _same(got, o), [got, o])
	check(c.id + ".skills", skills == (o.skills as Array).map(func(v): return int(v)), [skills, o.skills])


func _save_roundtrip() -> void:
	var s := _setup(30, 2, [XRaven.ACTOR, 1])
	s.raven = {"soul": 12345.0, "forged": 1}
	var d := s.to_dict()
	check("save.key", d.get("codexRaven") == {"soul": 12345.0, "forged": 1}, d.get("codexRaven"))
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(d)))
	check("save.roundtrip", back.raven == {"soul": 12345.0, "forged": 1}, back.raven)
	d.erase("codexRaven")
	var old := XState.from_dict(JSON.parse_string(JSON.stringify(d)))
	XState.current = old
	check("save.old", old.raven.is_empty() and XRaven.forged() == -1 and XRaven.soul(old.actor(XRaven.ACTOR)) == 0.0, old.raven)


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match kind:
			"module":
				check("module", (c.observed.require as Array).map(func(v): return int(v)) == XRaven.REQUIRE and int(c.observed.seal) == XRaven.SEAL)
			"gain":
				_gain(c)
			"seal":
				_seal(c)
			"advance":
				_advance(c)
			"spent":
				var s := _setup(int(c.setup.level), int(c.setup.rank), c.setup.party)
				s.raven["soul"] = float(XRaven.REQUIRE[3]) - 10.0
				_enemy(s, 180, false).add_state(1)
				var first := _seals(s)
				s.gain_item(XRaven.SEAL, -first)
				_enemy(s, 180, false).add_state(1)
				var got := [first, _seals(s), XRaven.forged(), XRaven.soul(s.actor(XRaven.ACTOR))]
				check(c.id, got == [int(c.observed.first), int(c.observed.after), int(c.observed.forged), float(c.observed.soul)], [got, c.observed])
	check("covers_all", seen.keys().size() == 5, seen.keys())
	_save_roundtrip()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_raven_soul", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
