extends Node
## 【cc·八戒·未经审查】米拉／渡鸦数值池二期（XNumberBoost.item_cri、XBattleLogic.item_hit／item_eva／item_cri）：
## 与 mv_oracle/mira_raven_hit_probe.cjs 的参照（generated/oracle/mira_raven_hit.json）逐例比面板暴击、行动者命中、目标闪避／暴击闪避、
## itemHit、itemEva、itemCri。归属技能（168 米拉攻击表、167 渡鸦攻击表，打敌人）必中、不闪避；渡鸦不归属的动作不借魂海暴击。
const ORACLE := "oracle/mira_raven_hit.json"
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
	if not check("oracle", d is Dictionary and d.cases.size() >= 30 and d.cases.all(func(c): return c.errors.is_empty()), ORACLE):
		finish()
		return
	for c in d.cases:
		_case(c)
	# 反向：渡鸦普攻读面板时没有残留压制（包装结束后恢复）
	check("suppress.reset", not XNumberBoost.suppress_raven)
	XState.current = null
	finish()


func _near(a: float, b) -> bool:
	return absf(snappedf(a, 0.000001) - float(b)) < 0.00001


func _case(c: Dictionary) -> void:
	var st: Dictionary = c.setup
	var o: Dictionary = c.observed
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.add_actor(int(st.user))
	var a := s.actor(int(st.user))
	a.change_level_mv(int(st.level))
	if not a.skill_ids.has(int(st.panel)):
		a.learn_skill(int(st.panel))
	s.raven["soul"] = float(st.soul)
	a.add_state(int(st.userState))
	a.refresh_passive()
	a.param_mark_dirty()
	var target := str(st.target)
	var t: XBattler = s.actor(1) if target == "actor" else XEnemy.new().setup(int(target.substr(1)), s.difficulty)
	if target == "actor":
		t.add_state(int(st.state))
	var logic := XBattleLogic.new()
	logic.state = s
	var skill := XDB.rec("Skills", int(st.skill))
	var got := {"cri": a.cri, "uHit": a.hit, "tEva": t.eva, "tCev": t.cev,
		"hit": logic.item_hit(a, skill, t), "eva": logic.item_eva(a, skill, t), "itemCri": logic.item_cri(a, skill, t)}
	for k in got:
		check("%s.%s" % [c.id, k], _near(got[k], o[k]), [got[k], o[k]])


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
