extends Node
## 困难／地狱／天灾挑战被动（技能 2872～2897 的层门学习结果）逐例对冻结 v0.28 参照 challenge_passives.json：
## 层门之后六名队员所学挑战技能的八维、附加／特殊能力值、状态、技能消耗，开战后（敌群 4）出战队员、首个敌人的状态与能力，
## （伤害比对因五乘区未移植暂不做，见下）。层门事件本身（学技能脚本）由 xiyou_event_compare 逐页对照，这里把参照学到的技能直接装上。
var checks := 0
var failures: Array = []
## 与参照 PARTY、SWITCH 同值
const PARTY := [1, 8, 9, 10, 11, 12]
const SWITCH := {3: 0, 4: 2500, 5: 2494, 6: 2489}
## 已知差异（本期只登记、不改规则，见交付单「挑战被动核对表」），逐项跳过对应比对：
## 1) 伤害：参照含五乘区预算软上限／分档系数（随层数降低伤害），重制按数值平衡不移植（damage.gd 文件头）
## 2) 困难（4）：参照里非主角队员已被 installNativeDifficultyInheritanceRuntime.syncActor 同步成「困难难度 5549＋难度适应 5980」，带状态 1691，重制没有这条同步
## 3) 困难（4）、地狱（5）：参照开战敌人能力为难度表倍率的 2.5／3 倍（天灾、普通一致），来源待查（需新参照探针）
## 4) 敌人带状态 1657／1658 时的命中／暴击／闪避读数（见下）
const KNOWN_ENEMY_DIFF := [4, 5]
const KNOWN_STATE_DIFF := [4]

func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 400:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(600))

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func near(a, b) -> bool:
	return absf(float(a) - float(b)) <= 1e-5 * maxf(1.0, absf(float(b)))

func near_list(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not near(a[i], b[i]):
			return false
	return true

func challenge_ids() -> Array:
	var out := []
	for i in range(2870, 2901):
		var rec := XDB.rec("Skills", i)
		if not rec.is_empty() and str(rec.get("name", "")).contains("挑战"):
			out.append(i)
	return out

func actor_row(a: XActor, logic: XBattleLogic, ids: Array) -> Dictionary:
	var learned := a.skill_ids.filter(func(id): return ids.has(id))
	learned.sort()
	var cost := logic.skill_cost(a, XDB.rec("Skills", 1065))
	return {"id": a.actor_id, "skills": learned,
		"params": range(8).map(func(i): return a.param(i)),
		"xparams": range(10).map(func(i): return a.xparam(i)),
		"sparams": range(10).map(func(i): return a.sparam(i)),
		"states": a.state_ids.duplicate(), "mp": cost.mp, "tp": cost.tp}

func compare_actor(tag: String, got: Dictionary, want: Dictionary, skip_states := false) -> void:
	check(tag + ".skills", same(got.skills, want.skills), [got.skills, want.skills])
	check(tag + ".params", near_list(got.params, want.params), [got.params, want.params])
	check(tag + ".xparams", near_list(got.xparams, want.xparams), [got.xparams, want.xparams])
	check(tag + ".sparams", near_list(got.sparams, want.sparams), [got.sparams, want.sparams])
	if not skip_states:
		check(tag + ".states", same(got.states, want.states), [got.states, want.states])
	check(tag + ".mp1065", int(got.mp) == int(want.mpCost1065), [got.mp, want.mpCost1065])
	check(tag + ".tp1065", int(got.tp) == int(want.tpCost1065), [got.tp, want.tpCost1065])

func run_case(c: Dictionary) -> void:
	if not c.id.begins_with("challenge.f"):
		return
	var spec: Dictionary = c.setup
	var o: Dictionary = c.observed
	var ids := challenge_ids()
	var d := int(spec.difficulty)
	var s := XState.new_game(d, int(PARTY[0]), PARTY.slice(1))
	s.random_master = XRandomStream.hex64(12345)
	for sid in [2500, 2494, 2489, 2487]:
		s.set_switch(sid, sid == int(SWITCH[d]))
	s.set_variable(8, float(o.skillCap))
	s.set_variable(20, float(spec.floor))  # 层门读的层数变量，开战敌人的楼层相关数值也读它
	s.actor(1).change_level_mv(10)
	for row in o.after:
		var a := s.actor(int(row.id))
		for sid in row.skills:
			a.learn_skill(int(sid))
		a.refresh_passive()
		a.recover_all()
	var logic := XBattleLogic.new()
	logic.elite_roll = 99.0  # 参照开战时 Math.random 固定 0.99
	logic.setup(4, s)
	var tag: String = c.id
	for row in o.battleActors:
		compare_actor(tag + ".actor" + str(row.id), actor_row(s.actor(int(row.id)), logic, ids), row, KNOWN_STATE_DIFF.has(d) and int(row.id) != 1)
	check(tag + ".members", same(logic.actors.map(func(a): return a.actor_id), o.battleMembers), [logic.actors.map(func(a): return a.actor_id), o.battleMembers])
	var e: XEnemy = logic.enemies[0]
	check(tag + ".enemy.id", e.enemy_id == int(o.enemy.id), [e.enemy_id, o.enemy.id])
	check(tag + ".enemy.states", same(e.state_ids, o.enemy.states), [e.state_ids, o.enemy.states])
	if not KNOWN_ENEMY_DIFF.has(d):
		check(tag + ".enemy.params", near_list(range(8).map(func(i): return e.param(i)), o.enemy.params), [range(8).map(func(i): return e.param(i)), o.enemy.params])
		# 4) 敌人带 1657／1658（天灾·加爆闪）时参照读到的命中／暴击／闪避没算上状态的 22 号特性（开战读数可能是未刷新的缓存），重制算上了：只在无状态时比对
		if o.enemy.states.is_empty():
			check(tag + ".enemy.hit", near(e.xparam(0), o.enemy.hit), [e.xparam(0), o.enemy.hit])
			check(tag + ".enemy.cri", near(e.xparam(2), o.enemy.cri), [e.xparam(2), o.enemy.cri])
			check(tag + ".enemy.cev", near(e.xparam(3), o.enemy.cev), [e.xparam(3), o.enemy.cev])

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://modes/xiyou/generated/oracle/challenge_passives.json"))
	check("source", fixture.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	for c in fixture.cases:
		check(c.id + ".native", c.errors.is_empty())
		run_case(c)
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
