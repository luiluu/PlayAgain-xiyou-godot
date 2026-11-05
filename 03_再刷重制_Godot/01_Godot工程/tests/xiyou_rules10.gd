extends Node
## 【cc·八戒·未经审查】rules10（Kyo 11-04「说明与代码不符一律按说明走」）三条，每条开关开／关两支都跑：
## 1. 隐月叠层（XBattler.FLOOR_YINYUE）：剑饮空月 PushsubState 命中已带着的隐月再加一层，每层同单层（暴击 +x），不限层；关回原版恒 1 层。
## 2. 数据错误:暴击 1749（XStateEffects.FIX_CRIT_1749）：暴击时伤害 + ceil(伤害 × 最终暴击率)；关回原版无效果。
## 3. 万古青天一株莲 7303（XStateEffects.LOTUS_DAMAGE_7303）：对敌方全体造成回复总量 50% × 属性 6 有效度的伤害，不暴击；关回原版只回复。
## 打印 MEASURE 行：隐月 6 个状态叠 1／5／20 层的暴击率，一株莲开关前后的敌方伤害（交付单记数字）。
var passed := 0
var total := 0
const FLOOR_SKILLS := {7489: 1323, 7503: 1324, 7504: 1325, 7505: 1326, 7506: 1327, 10119: 2521}

## 命中、闪避、挂状态固定；暴击按 crit 定
class FixedLogic extends XBattleLogic:
	var crit := false
	func _float(reason: String) -> float:
		match reason:
			"hit":
				return 0.0
			"evade":
				return 0.99
			"push_state", "push_self_state":
				return 0.0
			"reflection", "counter":
				return 0.99
			"critical":
				return 0.0 if crit else 0.99
		return super(reason)


func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _battle(skills: Array, troop := 1) -> Dictionary:
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	var a: XActor = s.actor(1)
	a.equips.clear()
	a.skill_ids.clear()
	a.state_ids.clear()
	for i in a.equip_slots().size():
		a.equips.append({})
	for id in skills:
		a.learn_skill(int(id))
	for m in s.members():
		m.param_mark_dirty()
		m.refresh_passive()
		m.recover_all()
	var logic := FixedLogic.new()
	logic.elite_roll = 100.0
	logic.setup(troop, s)
	a.refresh_passive()
	return {"s": s, "a": a, "logic": logic}


func _hit_skill(critical := false) -> Dictionary:
	var sk: Dictionary = XDB.rec("Skills", 1).duplicate(true)
	sk.damage.formula = "1000"
	sk.damage.variance = 0
	sk.damage.critical = critical
	return sk


## 1. 隐月：命中 n 次后的层数与暴击率
func _floor_run(skill_id: int, hits: int) -> Dictionary:
	var b := _battle([skill_id])
	var a: XActor = b.a
	var logic: FixedLogic = b.logic
	var foe: XEnemy = logic.enemies[0]
	var base := a.cri
	var sk := _hit_skill()
	for i in hits:
		foe.hp = foe.mhp
		logic.apply(a, sk, foe)
	return {"a": a, "foe": foe, "logic": logic, "floor": a.state_floor(int(FLOOR_SKILLS[skill_id])), "base": base, "cri": a.cri,
		"count": a.state_ids.count(int(FLOOR_SKILLS[skill_id]))}


func _floors() -> void:
	for on in [true, false]:
		if on:
			XBattler.FLOOR_YINYUE = true
		else:
			XBattler.FLOOR_YINYUE = false  # 回退支：原版
		for skill_id in FLOOR_SKILLS:
			var st: int = int(FLOOR_SKILLS[skill_id])
			var per: float = float(XBattler.state_rec(st).traits[0].value)
			for n in [1, 5, 10, 11, 20]:
				var r := _floor_run(skill_id, n)
				var layers: int = mini(n, XBattler.FLOOR_YINYUE_MAX) if on else 1  # rules10b 封顶 10 层
				check("floor.%s.%d.%d" % [on, st, n], r.floor == layers and r.count == 1 and is_equal_approx(r.cri, r.base + per * layers), [r.floor, r.count, r.base, r.cri])
				if on:
					print("MEASURE floor %d 层数 %d 暴击率 %.4f → %.4f" % [st, n, r.base, r.cri])
	XBattler.FLOOR_YINYUE = true
	# rules10b 回退支：上限设 0 回到不限层
	XBattler.FLOOR_YINYUE_MAX = 0
	var unl := _floor_run(7506, 20)
	check("floor.unlimited", unl.floor == 20 and is_equal_approx(unl.cri, unl.base + 2.0), [unl.floor, unl.cri])
	XBattler.FLOOR_YINYUE_MAX = 10
	# rules10b：10119 的隐月 2521 按说明每层 +2%；回退支原版 0.2%
	for fix in [true, false]:
		if fix:
			XBattler.FIX_YINYUE_2521 = true
		else:
			XBattler.FIX_YINYUE_2521 = false  # 回退支：原版 0.2%
		for n in [1, 5, 10]:
			var y := _floor_run(10119, n)
			check("floor.2521.%s.%d" % [fix, n], is_equal_approx(y.cri, y.base + (0.02 if fix else 0.002) * n), [y.cri, y.base])
			print("MEASURE 2521 %s 层数 %d 暴击率 %.4f → %.4f" % ["按说明 2%" if fix else "原版 0.2%", n, y.base, y.cri])
	XBattler.FIX_YINYUE_2521 = true
	check("floor.2521.db_untouched", is_equal_approx(float(XDB.rec("States", 2521).traits[0].value), 0.002))
	# 解除后重新附加从 1 层算起；阵亡清状态后同样
	var r := _floor_run(7506, 5)
	var a: XActor = r.a
	a.remove_state(1327)
	check("floor.removed", a.state_floor(1327) == 0 and is_equal_approx(a.cri, r.base), [a.state_floor(1327), a.cri])
	var foe: XEnemy = r.foe
	foe.hp = foe.mhp
	r.logic.apply(a, _hit_skill(), foe)
	check("floor.readd", a.state_floor(1327) == 1 and is_equal_approx(a.cri, r.base + 0.1), [a.state_floor(1327), a.cri])
	# 只有隐月 6 个叠层：其它已带着的状态照旧不重挂
	check("floor.only_yinyue", not XBattler.floor_stackable(1328) and XBattler.floor_stackable(2521))
	# 复制战斗者（预览、AI）带着层数
	var r2 := _floor_run(7489, 3)
	var shadow := XFormulaContext.clone_battler(r2.a)
	check("floor.clone", shadow != null and shadow.state_floor(1323) == 3 and is_equal_approx(shadow.cri, r2.cri), [shadow.state_floor(1323) if shadow else null])


## 2. 1749：持有者打暴击时 + ceil(伤害 × cri)
func _crit_1749() -> void:
	var out := {}
	for on in [true, false]:
		if on:
			XStateEffects.FIX_CRIT_1749 = true
		else:
			XStateEffects.FIX_CRIT_1749 = false  # 回退支：原版
		for crit in [true, false]:
			var b := _battle([])
			var a: XActor = b.a
			var logic: FixedLogic = b.logic
			logic.crit = crit
			var foe: XEnemy = logic.enemies[0]
			foe.state_ids.clear()
			foe.mhp  # 读一次缓存
			foe.hp = foe.mhp
			if on or crit:
				a.add_state(1749)
			a.param_mark_dirty()
			a.param_refresh()
			var hp0 := foe.hp
			var r := logic.apply(a, _hit_skill(true), foe)
			out["%s.%s" % [on, crit]] = {"dealt": hp0 - foe.hp, "critical": r.critical, "cri": a.cri, "has": a.is_state_affected(1749)}
	XStateEffects.FIX_CRIT_1749 = true
	var off: Dictionary = out["false.true"]
	var on_c: Dictionary = out["true.true"]
	check("1749.has", on_c.has and off.has, out)
	check("1749.crit_flag", on_c.critical and off.critical and not out["true.false"].critical, out)
	check("1749.cri", on_c.cri > 0.0, on_c.cri)
	check("1749.on", on_c.dealt == off.dealt + ceilf(off.dealt * on_c.cri), [on_c, off])
	check("1749.no_crit", out["true.false"].dealt < off.dealt, out)
	print("MEASURE 1749 暴击率 %.4f 暴击伤害 关 %d → 开 %d" % [on_c.cri, off.dealt, on_c.dealt])


## 3. 一株莲：琼霄（101）放 7303，队友各掉一半血、一人倒下；敌方各受回复总量 50% × 属性 6 有效度
func _lotus() -> void:
	for lv in [1, 60]:
		_lotus_at(lv)
	check("lotus.sequence", XActionSequence.has_sequence(XDB.rec("Skills", 7303)))  # 走行动序列那支


func _lotus_at(lv: int) -> void:
	var rows := {}
	for on in [true, false]:
		if on:
			XStateEffects.LOTUS_DAMAGE_7303 = true
		else:
			XStateEffects.LOTUS_DAMAGE_7303 = false  # 回退支：原版
		XEnemy.force_roll = 100.0
		var s := XState.new_game(3, 101, [1, 8])
		s.random_master = XRandomStream.hex64(4900)
		XState.current = s
		for m in s.members():
			m.change_level(lv)
			m.param_mark_dirty()
			m.refresh_passive()
			m.recover_all()
		var logic := FixedLogic.new()
		logic.elite_roll = 100.0
		logic.setup(2, s)
		var q: XBattler = logic.actors[0]
		for e in logic.enemies:
			e.hp = e.mhp
		var expect_heal := 0.0
		for i in logic.actors.size():
			var m: XBattler = logic.actors[i]
			if i == logic.actors.size() - 1 and i > 0:  # 最后一位倒下（一株莲拉起来，回复量算满血）
				m.hp = 0.0
				if not m.state_ids.has(1):
					m.state_ids.append(1)
				expect_heal += m.mhp
			else:
				m.hp = floorf(m.mhp * 0.5)
				expect_heal += m.mhp - m.hp
		var before := logic.enemies.map(func(e): return e.hp)
		q.mp = q.mmp
		var logs: Array = logic.execute(q, XDB.rec("Skills", 7303), null, true)
		var dealt := []
		for i in logic.enemies.size():
			dealt.append(float(before[i]) - logic.enemies[i].hp)
		var strikes := logs.filter(func(l): return l is Dictionary and l.get("lotus", false))
		var want := []
		for e in logic.enemies:
			want.append(floorf(floorf(expect_heal * 0.5) * e.element_rate(6)) if on else 0.0)
		rows[on] = {"dealt": dealt, "want": want, "heal": expect_heal, "strikes": strikes.size(), "mates": logic.actors.map(func(m): return m.hp == m.mhp)}
		check("lotus.%d.%s.healed" % [lv, on], logic.actors.all(func(m): return m.is_alive() and m.hp == m.mhp), rows[on])
		check("lotus.%d.%s.damage" % [lv, on], dealt == want, rows[on])
		check("lotus.%d.%s.logs" % [lv, on], strikes.size() == (logic.enemies.size() if on else 0) and strikes.all(func(l): return not l.critical), rows[on])
		print("MEASURE lotus %s 琼霄等级 %d 魔攻 %d 回复总量 %d 敌方各受 %s（敌方最大生命 %s）" % [on, int(q.level), int(q.mat), int(expect_heal), str(dealt), str(logic.enemies.map(func(e): return int(e.mhp)))])
	XStateEffects.LOTUS_DAMAGE_7303 = true
	XEnemy.force_roll = -1.0


func _run() -> void:
	_floors()
	_crit_1749()
	_lotus()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total and total > 0 else 1)
