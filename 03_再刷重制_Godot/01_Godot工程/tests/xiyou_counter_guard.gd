extends Node
## 【cc·GB·未经审查】v0.53.01 CounterGuard（反击者是敌人、已不在敌群里时跳过反击）：与 mv_oracle/counter_guard_probe.cjs（tests/fixtures/counter_guard_oracle.json，正式引擎）逐例比。
## 每例：新局难度 2，角色 1 清技能／装备／状态、mhp 加 50000；敌群 1 第一只（或另造的同号敌人、或从 enemies 摘掉的那只）mhp 也加 50000；
## 反击者带状态 327（反击率 +100%），技能 1（行动与反击共用）改物理、定值 100、无浮动不暴击；比目标挨的、行动者被反击扣的、守卫跳过次数。
## 另测回退：COUNTER_GUARD = false 时不在敌群的敌人照常反击。
const FIXTURE := "res://tests/fixtures/counter_guard_oracle.json"
var passed := 0
var total := 0

class FixedLogic extends XBattleLogic:
	func _float(reason: String) -> float:
		match reason:
			"hit":
				return 0.0
			"evade", "critical":
				return 0.99
		return 0.5  # 原版 Math.random 固定 0.5：反射率 0 不反射、反击率 1 必反击

func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))

func _ready() -> void:
	_run.call_deferred()

func _case(cfg: Dictionary) -> Dictionary:
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	for a in s.members():
		a.equips.clear()
		a.skill_ids.clear()
		a.state_ids.clear()
	s.mv_param_plus["1"] = [50000.0, 0, 0, 0, 0, 0, 0, 0]
	var a: XActor = s.actor(1)
	for m in s.members():
		m.param_mark_dirty()
		m.param_refresh()
		m.refresh_passive()
		m.recover_all()
	var logic := FixedLogic.new()
	logic.elite_roll = 100.0
	logic.setup(1, s)
	var foe: XEnemy = logic.enemies[0]
	match str(cfg.where):
		"fresh":
			foe = XEnemy.new().setup(foe.enemy_id, s.difficulty, 100.0)
		"removed":
			logic.enemies.erase(foe)
	foe.added_params[0] = 50000.0
	foe.param_mark_dirty()
	foe.refresh_passive()
	foe.recover_all()
	var enemy_user: bool = str(cfg.user) == "enemy"
	var user: XBattler = foe if enemy_user else a
	var target: XBattler = a if enemy_user else foe
	for b in [a, foe]:
		b.state_ids.clear()
		b.state_turns.clear()
	target.state_ids.append(327)
	target.state_turns[327] = 1
	target.param_mark_dirty()
	# 同探针：直接改数据库里的技能 1（反击者 setAttack 用的也是它），本例结束还原
	var sk: Dictionary = XDB.rec("Skills", 1)
	var saved: Dictionary = sk.duplicate(true)
	sk.damage.formula = "100"
	sk.damage.formulaProgram = {"version": 1, "status": "pure", "locals": [], "source": {"sha256": "counter-guard-constant"}, "result": "completion",
		"steps": [{"op": "expr", "value": {"op": "literal", "value": 100.0}}]}
	sk.damage.variance = 0
	sk.damage.critical = false
	sk.hitType = 1
	var u0 := user.hp
	var t0 := target.hp
	var rs := logic._invoke(user, sk, target)
	var countered := rs.any(func(r): return r is Dictionary and r.get("type") == "counter")
	for k in saved:
		sk[k] = saved[k]
	return {"u_delta": user.hp - u0, "t_delta": target.hp - t0, "countered": countered, "skipped": logic.counter_guard_skipped, "in_troop": logic.enemies.has(foe)}

func _run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("cases", ref.cases.size() == 4, ref.cases.size())
	for c in ref.cases:
		check(c.id + ".native", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var o: Dictionary = c.observed
		var got := _case(c.setup)
		check(c.id + ".in_troop", got.in_troop == o.inTroop, [got.in_troop, o.inTroop])
		check(c.id + ".countered", got.countered == (int(o.counterEntered) > 0), [got.countered, o.counterEntered])
		check(c.id + ".skipped", got.skipped == int(o.skipped), [got.skipped, o.skipped])
		check(c.id + ".target", is_equal_approx(got.t_delta, float(o.targetHpDelta)), [got.t_delta, o.targetHpDelta])
		check(c.id + ".user", is_equal_approx(got.u_delta, float(o.userHpDelta)), [got.u_delta, o.userHpDelta])
	# 回退：不看敌群，摘掉的敌人照常反击
	XBattleLogic.COUNTER_GUARD = false
	var off := _case({"user": "actor", "where": "removed"})
	XBattleLogic.COUNTER_GUARD = true
	check("off.countered", off.countered and off.skipped == 0 and off.u_delta < 0.0, off)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
