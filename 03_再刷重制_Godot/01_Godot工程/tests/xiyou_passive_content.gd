extends Node
## 定向静态被动内容：253本书、90项科技；通用解析与物品43入口严格对照。
var checks := 0
var failures: Array = []
var samples: Array = []
var fixture: Dictionary

func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if samples.size() < 12:
			samples.append({"tag": tag, "detail": detail})
			print("FAIL ", tag, " ", JSON.stringify(detail).left(1000))

func compare(tag: String, got, want) -> void:
	if want is Array:
		check(tag + ".size", got is Array and got.size() == want.size())
		for i in mini(got.size(), want.size()):
			compare(tag + ".%d" % i, got[i], want[i])
	elif want is bool:
		check(tag, got == want, [got, want])
	else:
		check(tag, absf(float(got) - float(want)) <= 1e-8, [got, want])

func snapshot(a: XActor) -> Dictionary:
	var e := XEnemy.new()
	e.setup(int(fixture.target.enemy), int(fixture.difficulty), 100.0)
	var damage := []
	for id in fixture.damageSkills:
		var item := XDB.rec("Skills", int(id)).duplicate(true)
		item.damage.variance = 0
		for critical in [false, true]:
			damage.append(XDamage.calculate(item, a, e, {"variance": false, "critical": critical, "preview": true}).value)
	return {"base": range(8).map(func(i): return a.param_base(i)), "param": range(8).map(func(i): return a.param(i)),
		"xparam": range(10).map(func(i): return a.xparam(i)), "sparam": range(10).map(func(i): return a.sparam(i)),
		"elements": range(1,16).map(func(i): return XDamage.element_bonus(a,i)), "maxTp": a.max_tp(), "preserveTp": a.is_preserve_tp(),
		"actionPlus": a.action_plus_set(), "weapons": range(1,13).map(func(i): return a.can_equip({"kind":"weapon","etypeId":1,"wtypeId":i})),
		"armors": range(1,4).map(func(i): return a.can_equip({"kind":"armor","etypeId":2,"atypeId":i})), "damage": damage}

func compare_row(tag: String, a: XActor, want: Dictionary) -> void:
	var got := snapshot(a)
	for key in want:
		compare(tag + "." + key, got[key], want[key])

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/passive_content_oracle.json"))
	check("fixture", fixture.cases.size() == 343)
	check("source", fixture.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	var s := XState.new_game_blank()
	s.party.assign([1])
	s.battle_slots = [1, 0, 0, 0, 0]
	var a := s.actor(1)
	a._lv = 37
	a.equips.fill(null)
	a.skill_ids.clear()
	a.state_ids.clear()
	a.refresh_passive()
	a.recover_all()
	var target := XEnemy.new()
	target.setup(int(fixture.target.enemy), int(fixture.difficulty), 100.0)
	compare("target.param", range(8).map(func(i): return target.param(i)), fixture.target.param)
	compare_row("baseline", a, fixture.baseline)
	var battle := XBattleLogic.new()
	battle.state = s
	battle.actors = [a]
	for c in fixture.cases:
		check(c.id + ".oracle", c.errors.is_empty())
		if not c.errors.is_empty():
			continue
		a.skill_ids.clear()
		a.state_ids.clear()
		a.refresh_passive()
		a.recover_all()
		a.runtime_result = XResourceContext.empty_result()
		if c.setup.has("item"):
			battle.apply(a, XDB.rec("Items", int(c.setup.item)), a)
		else:
			a.learn_skill(int(c.setup.skill))
		a.refresh_passive()
		a.recover_all()
		check(c.id + ".learned", a.skill_ids.has(int(c.setup.skill)) == c.observed.learned)
		compare_row(c.id + ".full", a, c.observed.full)
		a.learn_skill(int(c.setup.skill))
		a.refresh_passive()
		compare_row(c.id + ".repeat", a, c.observed.repeat)
		a.hp = floorf(a.mhp * 0.25)
		a.mp = floorf(a.mmp * 0.25)
		a.refresh_passive()
		compare_row(c.id + ".low", a, c.observed.low)
		a.forget_skill(int(c.setup.skill))
		a.refresh_passive()
		a.recover_all()
		compare_row(c.id + ".forgot", a, c.observed.forgot)
	print("TEST_RESULT=" + JSON.stringify({"total":checks,"passed":checks-failures.size(),"failures":failures,"samples":samples}))
	get_tree().quit(0 if failures.is_empty() else 1)
