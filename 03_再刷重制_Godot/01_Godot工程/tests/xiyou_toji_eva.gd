extends Node
## 【cc·悟空·未经审查】黄泉 169／镜流 170 必中物理技能打甚尔 171 的闪避（审查第 18 期 P3②，XBattleLogic.item_eva）：
## 与 mv_oracle/toji_eva_probe.cjs 的冻结 v0.28 参照（generated/oracle/toji_eva.json）逐例比双方敏捷、itemEva、itemHit。
## 原版镜流黄泉的 itemEva 包装在甚尔里面：必中只把内层闪避压成 0，甚尔再加目标天与咒缚的影速（至多 0.3）。
const ORACLE := "oracle/toji_eva.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + ORACLE))
	if not check("oracle", d is Dictionary and d.cases.size() >= 6 and d.cases.all(func(c): return c.errors.is_empty()), ORACLE):
		finish()
		return
	for c in d.cases:
		_case(c)
	XState.current = null
	finish()


func _case(c: Dictionary) -> void:
	var st: Dictionary = c.setup
	var o: Dictionary = c.observed
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	for id in [169, 170, 171]:
		s.add_actor(id)
		s.actor(id).change_level_mv(int(st.level))
	var a := s.actor(int(st.user))
	var t := s.actor(int(st.target))
	if int(st.target) == 171 and not t.skill_ids.has(10203):
		t.learn_skill(10203)
	a.add_param(6, float(st.userAgiPlus))
	for b in [a, t]:
		b.refresh_passive()
		b.param_mark_dirty()
	var agi := [a.param(6), t.param(6)]
	check(c.id + ".agi", agi == (o.agi as Array).map(func(x): return float(x)), [agi, o.agi])
	var logic := XBattleLogic.new()
	logic.state = s
	var skill := XDB.rec("Skills", int(st.skill))
	check(c.id + ".eva", is_equal_approx(snappedf(logic.item_eva(a, skill, t), 0.000001), float(o.eva)), [logic.item_eva(a, skill, t), o.eva])
	check(c.id + ".hit", is_equal_approx(logic.item_hit(a, skill, t), float(o.hit)), [logic.item_hit(a, skill, t), o.hit])


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
