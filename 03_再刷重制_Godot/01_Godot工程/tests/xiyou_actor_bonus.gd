extends Node
## 定向冻结参照 actor_bonus_probe.cjs：永久加算／宠物属性／特性层与整队 TeamA 迁移。
const FIXTURE := "res://tests/fixtures/actor_bonus_oracle.json"
const IDS := [1, 8, 9, 10, 11]
const SKILLS := [1365, 1475]
var results := []

func _ready() -> void:
	_run.call_deferred()

func check(name: String, ok: bool, detail = null) -> void:
	results.append(ok)
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(1200))

func fresh() -> XState:
	var s := XState.new_game_blank()
	s.party.assign([1, 8, 9, 10])
	s.battle_slots = [1, 8, 9, 10, 0]
	s.saved_actors.assign([11])
	for id in IDS:
		var a := s.actor(id)
		a.equips.fill(null)
		a.skill_ids.clear()
		a.state_ids.clear()
		a.refresh_passive()
		a.recover_all()
	return s

func compare(tag: String, a: XActor, row: Dictionary) -> void:
	var got := {"base": range(8).map(func(i): return a.param_base(i)),
		"plus": range(8).map(func(i): return a.param_plus(i)), "param": range(8).map(func(i): return a.param(i)),
		"traits": range(10).map(func(i): return a.traits_sum(22, i)), "xparam": range(10).map(func(i): return a.xparam(i)),
		"skills": SKILLS.filter(func(id): return a.skill_ids.has(id)), "hp": a.hp, "mp": a.mp}
	for k in got:
		var ok := true
		if got[k] is Array:
			ok = got[k].size() == row[k].size()
			for i in mini(got[k].size(), row[k].size()):
				ok = ok and absf(float(got[k][i]) - float(row[k][i])) < 1e-8
		else:
			ok = absf(float(got[k]) - float(row[k])) < 1e-8
		check(tag + "." + k, ok, [got[k], row[k]])

func compare_party(s: XState, row: Dictionary) -> void:
	for a in row.actors:
		compare(str(row.name) + "." + str(int(a.id)), s.actor(int(a.id)), a)

func _run() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("fixture", fixture is Dictionary and fixture.cases.size() == 3)
	for c in fixture.cases:
		check(str(c.id) + ".oracle", c.errors.is_empty())
	var s := fresh()
	var a := s.actor(1)
	var rows: Array = fixture.cases[0].observed.rows
	compare("permanent.before", a, rows[0])
	var changes := [[0, 10], [2, 12.5], [2, -1.25], [0, -15]]
	for i in changes.size():
		a.add_param(int(changes[i][0]), float(changes[i][1]))
		compare("permanent.%d" % i, a, rows[i + 1])
	a.recover_all()
	compare("permanent.recover", a, rows[5])
	s = XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	compare("permanent.save", s.actor(1), rows[6])
	check("permanent.fraction", XParamPlus.bonus(s.actor(1), 2) == 11.25)
	var legacy: Dictionary = s.to_dict()
	legacy.erase("mvParamPlus")
	s = XState.from_dict(legacy)
	check("permanent.legacy", XParamPlus.bonus(s.actor(1), 2) == 0.0)
	# 事件 317 与 addParam 复用同一账本，不再截断已有小数。
	XParamPlus.add(s, 1, 2, 2.5)
	XParamPlus.add(s, 1, 2, 1)
	check("permanent.shared_ledger", s.actor(1).param_plus(2) == 3.5)
	var setup: Dictionary = fixture.cases[1].setup
	s = fresh()
	for push in setup.pushes:
		s.pets.list.append({"enemy": 1, "push": push, "skills": SKILLS.duplicate(), "lv_skills": {}, "exp": 0, "ls": 0, "ls_max": 3})
	rows = fixture.cases[1].observed.rows
	compare_party(s, rows[0])
	XPets.go_to_war(s, 0)
	compare_party(s, rows[1])
	for id in IDS:
		s.actor(id).recover_all()
	compare_party(s, rows[2])
	XPets.refresh_war(s)
	compare_party(s, rows[3])
	# 同整队界面的槽位变更→rearrange_actors，不直接调用宠物 helper。
	s.battle_slots = [8, 1, 9, 10, 0]
	s.rearrange_actors()
	compare_party(s, rows[4])
	XPets.set_team_a(s, 1)
	compare_party(s, rows[5])
	# 有宠物的存档往返不能把临时加成重复写入永久字段；读后整队仍能迁移旧接收者。
	s = XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	compare_party(s, rows[5])
	check("pet.no_permanent", s.mv_param_plus.is_empty())
	s.battle_slots = [1, 8, 9, 10, 0]
	s.rearrange_actors()
	check("pet.loaded_swap", s.actor(8).skill_ids.has(1475) and not s.actor(1).skill_ids.has(1475))
	s.battle_slots = [8, 1, 9, 10, 0]
	s.rearrange_actors()
	XPets.go_to_war(s, 1)
	compare_party(s, rows[6])
	XPets.rest(s, 1)
	compare_party(s, rows[7])
	# traitsSum 是全体角色可读；宠物属性仅队伍及仓库拥有，敌人无特性加成。
	s = fresh()
	var o: Dictionary = fixture.cases[2].observed
	compare("mapping.before", s.actor(1), o.before)
	s.pets.list = [{"enemy": 1, "push": setup.pushes[0], "skills": []}]
	s.pets.war = 0
	# 原版 mapping 只设 GTWar，没有执行出战前八项加算：这里只比 traits／xparam。
	for key in ["traits", "xparam"]:
		var got := range(10).map(func(i): return s.actor(1).traits_sum(22, i) if key == "traits" else s.actor(1).xparam(i))
		check("mapping." + key, range(10).all(func(i): return absf(float(got[i]) - float(o.after[key][i])) < 1e-8), [got, o.after[key]])
	var enemy := XEnemy.new().setup(1, 1)
	var before := range(10).map(func(i): return enemy.traits_sum(22, i))
	s.pets.war = -1
	check("mapping.enemy", range(10).all(func(i): return enemy.traits_sum(22, i) - before[i] == float(o.enemyDelta[i])))
	var passed := results.count(true)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
