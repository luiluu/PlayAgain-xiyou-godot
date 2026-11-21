extends Node
## 【cc·T239 第 6 轮】守层者集火招单独倍率（XGuardianRework.FOCUS，D248 C，协调 11-21）：
## 一、表里 guardian_phase4.focus[20] ＝ {skill, scale} 时，20 层守层者 focus_skill／focus_scale 照表，output_scale 照 atk_scale；
##     skill_scale：集火招取 focus_scale、别的招取 output_scale。
## 二、实算：同一招对同一角色的预览伤害，集火招 ÷ 不是集火招（把 focus 指到别的招）＝ focus_scale ÷ atk_scale。
## 三、同场不是守层者的敌人、量数（measure_atk ≥ 0）时不认集火。
## 四、回退：FOCUS=false 时 focus_skill 为 0、那招照 atk_scale。五、表里没有 focus：照旧。

const TROOP := 456   # 20 层守层者那场
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	MVInterpreter.fixed_random = 0.5
	seed(20261121)
	var data := XTianqiBalance.data()
	var had: bool = data.has("guardian_phase4")
	var old = data.get("guardian_phase4")
	var was_focus := XGuardianRework.FOCUS
	var s := _state(19)
	var probe := XBattleLogic.new()
	probe.setup(TROOP, s)
	var g := _guardian(probe)
	_check("has_guardian", g != null)
	if g == null:
		_finish(had, old, was_focus)
		return
	var sk := _single_skill(g)
	_check("has_single_skill", sk > 0, sk)
	var other := _other_skill(g, sk)
	data["guardian_phase4"] = {"atk_scale": {"20": 0.1}, "focus": {"20": {"skill": sk, "scale": 2.0}}}
	# 一、照表
	var logic := XBattleLogic.new()
	logic.setup(TROOP, _state(19))
	g = _guardian(logic)
	_check("focus_fields", g.focus_skill == sk and is_equal_approx(g.focus_scale, 2.0) and is_equal_approx(g.output_scale, 0.1), [g.focus_skill, g.focus_scale, g.output_scale])
	_check("skill_scale", is_equal_approx(g.skill_scale({"id": sk}), 2.0) and is_equal_approx(g.skill_scale({"id": sk + 100000}), 0.1))
	# 二、实算：同一招，集火与否只差倍率
	var a: XBattler = logic.actors[0]
	var item: Dictionary = XDB.rec("Skills", sk)
	var hit_focus := XDamage.preview_hit(item, g, a)
	g.focus_skill = other if other > 0 else sk + 100000
	var hit_plain := XDamage.preview_hit(item, g, a)
	_check("damage_ratio", hit_plain > 0.0 and absf(hit_focus / hit_plain - 20.0) < 0.5, [hit_focus, hit_plain])
	# 三、同场别的敌人、量数时不认
	for e in logic.enemies:
		if not is_same(e, g) and XGuardianRework.guardian_floor(e) <= 0:
			_check("non_guardian_no_focus", e.focus_skill == 0, e.enemy_id)
			break
	XGuardianRework.measure_atk = 0.5
	_check("measure_no_focus", XGuardianRework.focus(g).is_empty())
	XGuardianRework.measure_atk = -1.0
	# 四、回退
	XGuardianRework.FOCUS = false
	var off := XBattleLogic.new()
	off.setup(TROOP, _state(19))
	var go := _guardian(off)
	_check("rollback", go.focus_skill == 0 and is_equal_approx(go.skill_scale({"id": sk}), 0.1), [go.focus_skill, go.skill_scale({"id": sk})])
	XGuardianRework.FOCUS = true
	# 五、表里没有 focus
	data["guardian_phase4"] = {"atk_scale": {"20": 0.1}}
	var nf := XBattleLogic.new()
	nf.setup(TROOP, _state(19))
	_check("no_focus_table", _guardian(nf).focus_skill == 0)
	_finish(had, old, was_focus)


func _finish(had: bool, old, was_focus: bool) -> void:
	if had:
		XTianqiBalance.data()["guardian_phase4"] = old
	else:
		XTianqiBalance.data().erase("guardian_phase4")
	XGuardianRework.FOCUS = was_focus
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _state(passed_floor: int) -> XState:
	var lineup := [1, 2, 8, 9, 10]
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, passed_floor + 1)
	XState.current = s
	return s


func _guardian(logic: XBattleLogic) -> XEnemy:
	for e in logic.enemies:
		if XGuardianRework.guardian_floor(e) == 20:
			return e
	return null


## 守层者行动表里第一招单体伤害招（scope 1、类型 1）
func _single_skill(e: XEnemy) -> int:
	for act in XDB.rec("Enemies", e.enemy_id).get("actions", []):
		var sk: Dictionary = XDB.rec("Skills", int(act.skillId))
		if int(sk.get("scope", 0)) == 1 and int(sk.get("damage", {}).get("type", 0)) == 1:
			return int(act.skillId)
	return 0


func _other_skill(e: XEnemy, not_this: int) -> int:
	for act in XDB.rec("Enemies", e.enemy_id).get("actions", []):
		if int(act.skillId) != not_this:
			return int(act.skillId)
	return 0
