extends Node
## 【cc·未经审查】五河琴里（159）火力值（变量 1510）：原版 YEP_X_ActSeqPack1 actionChangeVariable 在技能序列 target 段里改变量。
## - 连珠炮 10055／炎舞 10058：每个目标打完 change variable 1510 += 100，再跑公共事件 1712／1709（≥500 夹到 500、正好 500 学爆发技）；
## - 聚合炮 10056／毁灭之炎 10057：change variable 1510 -= 500；
## - 开关 XActionSequence.CHANGE_VARIABLE = false 回到旧重制（跳过，火力值永远 0）。
## v0.01.07 玩家反馈「琴里攒不了火力值」：旧重制把 CHANGE VARIABLE 当成画面指令跳过。
const KOTORI := 159
const FIRE := 1510
var results := []


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func setup() -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [KOTORI])
	XState.current = s
	var logic := XBattleLogic.new()
	logic.setup(222, s)
	logic.turn = 1
	for a in logic.actors:
		a.change_level(10)
		a.refresh_passive()
		a.recover_all()
	return logic


func _seq(logic: XBattleLogic, skill: int) -> XActionSequence:
	var u: XBattler = logic.state.actor(KOTORI)
	var rec := XDB.rec("Skills", skill)
	var seq := XActionSequence.create(logic, u, rec, logic.targets_for(u, rec, logic.enemies[0]))
	seq.run()
	return seq


func _run() -> void:
	# 序列里写的就是原版那几行
	for id in [10055, 10058]:
		check("seq_has_add_%d" % id, JSON.stringify(XDB.rec("Skills", id).yepSeq.target).contains("change variable 1510 += 100"))
	for id in [10056, 10057]:
		check("seq_has_sub_%d" % id, JSON.stringify(XDB.rec("Skills", id).yepSeq.target).contains("change variable 1510 -= 500"))

	# 炎舞（全体，target 段每个目标一次）：三个敌人＝+300
	var logic := setup()
	var n := logic.alive(logic.enemies).size()
	check("enemies_three", n == 3, n)
	var seq := _seq(logic, 10058)
	check("yanwu_adds_per_target", logic.state.variable(FIRE) == 100.0 * n, logic.state.variable(FIRE))
	check("no_unknown", seq.unknown.is_empty(), seq.unknown)

	# 连珠炮同样 +100／目标
	logic = setup()
	_seq(logic, 10055)
	check("lianzhu_adds_per_target", logic.state.variable(FIRE) == 100.0 * logic.enemies.size(), logic.state.variable(FIRE))

	# 聚合炮（单体）-500
	logic = setup()
	logic.state.set_variable(FIRE, 500)
	_seq(logic, 10056)
	check("juhe_subtracts", logic.state.variable(FIRE) == 0.0, logic.state.variable(FIRE))

	# 写法：= *= /= %= 与 VARIABLE Y
	logic = setup()
	var probe := XActionSequence.create(logic, logic.state.actor(KOTORI), XDB.rec("Skills", 10058), [])
	logic.state.set_variable(FIRE, 7)
	logic.state.set_variable(11, 3)
	probe._change_variable("CHANGE VARIABLE 1510 *= VARIABLE 11")
	check("op_mul_var", logic.state.variable(FIRE) == 21.0, logic.state.variable(FIRE))
	probe._change_variable("CHANGE VARIABLE 1510 /= 2")
	check("op_div_floor", logic.state.variable(FIRE) == 10.0, logic.state.variable(FIRE))
	probe._change_variable("CHANGE VARIABLE 1510 %= 4")
	check("op_mod", logic.state.variable(FIRE) == 2.0, logic.state.variable(FIRE))
	probe._change_variable("CHANGE VARIABLE 1510 = 42")
	check("op_set", logic.state.variable(FIRE) == 42.0, logic.state.variable(FIRE))
	probe._change_variable("CHANGE VARIABLE 1510 += a.atk")
	check("op_eval_unknown", logic.state.variable(FIRE) == 42.0 and probe.unknown.size() == 1, probe.unknown)

	# 完整行动：act 后公共事件 1709 跑过（toaster 之外：≥500 夹 500、正好 500 学 10559）
	logic = setup()
	var k: XActor = logic.state.actor(KOTORI)
	logic.state.set_variable(FIRE, 400)
	logic.act(k, XDB.rec("Skills", 10058), logic.enemies[0])
	check("act_adds_before_event", logic.state.variable(FIRE) == 400.0 + 100.0 * n, logic.state.variable(FIRE))
	logic.run_events(k)
	check("ce1709_caps_500", logic.state.variable(FIRE) == 500.0, logic.state.variable(FIRE))
	check("ce1709_learns_10559", k.skill_ids.has(10559), k.skill_ids.filter(func(x): return x >= 10050 and x < 10600))

	# 回退：旧重制跳过
	XActionSequence.CHANGE_VARIABLE = false
	logic = setup()
	_seq(logic, 10058)
	check("rollback_skips", logic.state.variable(FIRE) == 0.0, logic.state.variable(FIRE))
	XActionSequence.CHANGE_VARIABLE = true
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
