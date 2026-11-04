extends Node
## YEP_AbsorptionBarrier（吸收屏障）可达性守卫（dot2，参照 oracle/barrier.json＝mv_oracle/barrier_probe.cjs 量冻结正式源）。
## 结论：全游戏数据里只有技能 10032 月之庇佑带 <Custom User Barrier>，它是 occasion 3（永不可用）的被动，原版里学会之后
## 战斗开始、再生、回合结束屏障点数始终是 0，所以重制不做屏障系统。本专项守住这个前提：
## 数据里出现第二个屏障标签、10032 变得可用、或原版参照不再成立，就报失败，提醒回来补屏障。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var ref = XDB.load_json("oracle/barrier.json")
	check("oracle_present", ref is Dictionary and ref.has("cases"))
	if not (ref is Dictionary and ref.has("cases")):
		return _finish()
	var cases := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		cases[c.id] = c
	# 原版：谁带屏障字段
	var census: Dictionary = cases.census.observed
	check("census.skill_only_10032", census.skills.size() == 1 and int(census.skills[0].id) == 10032, census.skills)
	for table in ["items", "actors", "classes", "enemies", "weapons", "armors", "states"]:
		check("census.%s_empty" % table, census[table].is_empty(), census[table])
	check("census.params", int(census.params.state) == 0 and census.params.clearPerBattle == true, census.params)
	check("census.skill_never", int(census.skill.occasion) == 3 and int(census.skill.scope) == 0 and int(census.skill.effects) == 0, census.skill)
	# 原版：学会 10032 之后不可用、屏障点数一直是 0
	var reach: Dictionary = cases["reach.10032"].observed
	for where in ["menu", "battle"]:
		var r: Dictionary = reach[where]
		check("reach.%s.unusable" % where, not r.canUse and not r.occasionOk and not r.listed and not r.valid, r)
	for step in reach.track:
		check("reach.track.%s" % step.tag, int(step.barrier) == 0 and int(step.perm) == 0, step)
	# 重制：同一张表——只有 10032 的备注带屏障标签；它同样不可用
	var tagged := []
	for table in ["Skills", "Items", "Actors", "Classes", "Enemies", "Weapons", "Armors", "States"]:
		for rec in XDB.table(table):
			if rec is Dictionary and str(rec.get("note", "")).to_lower().contains("barrier"):
				tagged.append("%s#%d" % [table, int(rec.id)])
	check("remake.tagged_only_10032", tagged == ["Skills#10032"], tagged)
	var skill := XDB.rec("Skills", 10032)
	check("remake.skill_never", int(skill.occasion) == 3 and int(skill.scope) == 0, [skill.occasion, skill.scope])
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(2, s)
	var a: XActor = l.actors[0]
	a.learn_skill(10032)
	check("remake.cannot_use", not l.can_use(a, skill))
	_finish()


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
