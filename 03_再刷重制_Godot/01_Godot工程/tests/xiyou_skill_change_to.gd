extends Node
## 技能替换（skill_change_to_probe.cjs）：行动开始时按技能备注 <ChangeTo[id]: 条件> 逐条求值，第一条为真就换，不看能不能用、不递归。
## 每例照参照摆好行动者（角色 1 或敌群 1 第一只，设 hp／tp／mp），开一场敌群 1，走 BattleLogic.act，比：
## 解析出的条件（id 与原文）、真正开始的行动技能、ChangeTo 取数次数（rule 流 reason changeto）。
## 参照的 ChangeTo 取数换成脚本流磁带（同值、同次序），其后的取数垫 0.5。

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
	var ref = XDB.load_json("oracle/skill_change_to.json")
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return _finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	check("oracle_clean", ref.cases.all(func(c): return c.errors.is_empty()), ref.cases.filter(func(c): return not c.errors.is_empty()).map(func(c): return c.id))
	# 正式数据里带 ChangeTo 的技能全集一致
	var skills := []
	for rec in XDB.table("Skills"):
		if rec is Dictionary and not XBattleLogic.change_to_conditions(rec).is_empty():
			skills.append(int(rec.id))
	check("skills", norm(skills) == norm(ref.skills), {"got": skills, "want": ref.skills})
	XGear.force_roll = 0.5
	var changed := 0
	for c in ref.cases:
		if c.observed == null:
			continue
		var want: Dictionary = norm(c.observed)
		want.erase("otherRolls")  # 别的 startAction 包装的取数，不归本功能
		var got := _measure(c.setup, c.observed)
		if want.started != [want.before]:
			changed += 1
		for k in want:
			check(str(c.id) + "." + str(k), norm(got.get(k)) == want[k], {"got": got.get(k), "want": want[k]})
	check("some_changed", changed > 0, changed)  # 参照里确有换出技能的例，免得全比「不换」也过
	_finish()


func _measure(spec: Dictionary, observed: Dictionary) -> Dictionary:
	var s := XState.new_game_blank()
	s.add_actor(1)
	var logic := XBattleLogic.new()
	logic.elite_roll = 50.0  # 参照新局 Math.random 恒 0.5：神话掷 50，不小于 50，不变神话
	logic.setup(1, s)
	var a: XBattler = logic.enemies[0] if bool(spec.get("enemy", false)) else s.actor(1)
	a.recover_all()
	a.hp = float(observed.hp)
	a.tp = float(observed.tp)
	a.mp = float(observed.mp)
	var out := {"enemy": a.enemy_id if a is XEnemy else 0, "hp": a.hp, "mhp": a.mhp, "mp": a.mp, "tp": a.tp}
	var skill: Dictionary
	if int(spec.get("item", 0)) > 0:
		s.items[int(spec.item)] = 1
		skill = XDB.rec("Items", int(spec.item))
	else:
		skill = XDB.rec("Skills", int(spec.skill))
	out.before = int(skill.id)
	out.isItem = XBattleLogic.is_item(skill)
	out.conditions = [] if out.isItem else XBattleLogic.change_to_conditions(skill).map(func(e): return {"id": e[0], "condition": str(e[1]).strip_edges()})
	var tape := []
	for i in int(observed.rolls):
		tape.append({"kind": "float", "reason": "changeto", "value": float(spec.rolls[i])})
	for i in 400:
		tape.append({"kind": "float", "value": 0.5})
	logic.random.rule = XRandomStream.scripted(tape)
	var target: XBattler = s.actor(1) if a is XEnemy else logic.enemies[0]
	var logs := logic.act(a, skill, target)
	out.started = logs.filter(func(r): return r.get("type") == "action").map(func(r): return -int(r.skill.id) if XBattleLogic.is_item(r.skill) else int(r.skill.id))
	out.rolls = logic.random.rule.journal.filter(func(j): return j.reason == "changeto").size()
	return out


func _finish() -> void:
	XGear.force_roll = -1.0
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
