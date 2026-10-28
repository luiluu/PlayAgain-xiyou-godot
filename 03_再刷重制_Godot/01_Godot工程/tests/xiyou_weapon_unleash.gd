extends Node
## 武器解放（weapon_unleash_probe.cjs）：普攻行动开始时按 <Weapon Unleash x%: 技能> 逐条试，技能此刻能用才掷，掷数不大于几率就换。
## 每例照参照摆好角色（升到武器需求等级、卸下全部装备、装武器、卸下不能装备的、设 TP），开一场敌群 1，走 BattleLogic.act，比：
## attackSkillId、canAttack、每条解放的技能／几率／canUse、真正开始的行动技能、解放取数次数（rule 流 reason unleash）。
## 参照的解放取数换成脚本流磁带（同值、同次序），其后的取数垫 0.5。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


static func norm(v):
	if v is int or v is float:
		return float(v)
	if v is Array:
		return v.map(func(x): return norm(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = norm(v[k])
		return out
	return v


func _run() -> void:
	var ref = XDB.load_json("oracle/weapon_unleash.json")
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return _finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	check("oracle_clean", ref.cases.all(func(c): return c.errors.is_empty()), ref.cases.filter(func(c): return not c.errors.is_empty()).map(func(c): return c.id))
	XGear.force_roll = 0.5
	var triggered := 0
	for c in ref.cases:
		if c.observed == null:
			continue
		var want: Dictionary = norm(c.observed)
		want.erase("otherRolls")  # 别的 startAction 包装的取数，不归本功能
		var got := _measure(c.setup, c.observed)
		if want.started != [want.before]:
			triggered += 1
		for k in want:
			check(str(c.id) + "." + str(k), norm(got.get(k)) == want[k], {"got": got.get(k), "want": want[k]})
	check("some_triggered", triggered > 0, triggered)  # 参照里确有换出技能的例，免得全比「不换」也过
	_finish()


func _measure(spec: Dictionary, observed: Dictionary) -> Dictionary:
	var s := XState.new_game_blank()
	s.actor_max_level = 99  # 参照把等级上限提到 99，再按武器的需求等级 changeLevel
	s.set_switch(XItemMarks.SUPER_SWITCHES[0], true)  # 超强者（154、166 专属武器）出战要开超强；参照直接 addActor 进队
	var aid := int(observed.actor)
	s.add_actor(aid)
	var a := s.actor(aid)
	if a.level < int(observed.level):
		a.change_level_mv(int(observed.level))
	for n in a.equips.size():
		a.equips[n] = null
	a.refresh_passive()
	a.recover_all()
	if int(spec.get("weapon", 0)) > 0:
		a.equips[0] = XGear.create("weapon", int(spec.weapon), s)
	a.release_unequippable()  # Game_Actor.refresh：卸下不能装备的
	a.refresh_passive()
	var logic := XBattleLogic.new()
	logic.setup(1, s)
	a.tp = float(spec.get("tp", 0))
	var out := {"actor": aid, "level": a.level, "tp": a.tp, "attackSkillId": a.attack_skill_id(), "canAttack": logic.can_use(a, a.attack_skill())}
	out.equips = a.equips.map(func(e): return 0 if e == null or e.is_empty() else int(e.base))
	out.unleashes = a.weapon_unleashes().map(func(u): return {"skill": u[0], "rate": u[1], "canUse": logic.can_use(a, XDB.rec("Skills", int(u[0])))})
	var skill := a.attack_skill()
	var act = spec.get("act", "attack")
	if str(act) == "item1":
		s.items[1] = 1
		skill = XDB.rec("Items", 1)
	elif str(act) == "skill1":
		skill = XDB.rec("Skills", 1)
	elif act is int or act is float:
		skill = XDB.rec("Skills", int(act))
	out.before = int(skill.id)
	out.isItem = XBattleLogic.is_item(skill)
	var tape := []
	for i in int(observed.rolls):
		tape.append({"kind": "float", "reason": "unleash", "value": float(spec.rolls[i])})
	for i in 400:
		tape.append({"kind": "float", "value": 0.5})
	logic.random.rule = XRandomStream.scripted(tape)
	var logs := logic.act(a, skill, logic.enemies[0])
	out.started = logs.filter(func(r): return r.get("type") == "action").map(func(r): return int(r.skill.id))
	out.rolls = logic.random.rule.journal.filter(func(j): return j.reason == "unleash").size()
	return out


func _finish() -> void:
	XGear.force_roll = -1.0
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
