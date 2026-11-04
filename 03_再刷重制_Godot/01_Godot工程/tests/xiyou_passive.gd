extends Node
## dsPassiveSkill 三处补齐（passive1），对照 oracle/passive.json（mv_oracle/passive_probe.cjs 量冻结正式源）：
## ① <passiveGUARD>（技能 10089 苍龙*破晓）：isGuard 恒真（不看能不能行动），受伤折减 ÷(2×grd)
## ② <passiveXPBSTEXn:上升量,条件,判定值>（技能 968 暴击率、3886 TP 回复率）：条件满足才加追加能力值
## ③ passivePBSTEX 的 TPUP／TPLW 条件（技能 3219、4924）。能力值基数与原版不同，所以比「有没有加成、加成随条件的开关」与可由重制自己的基数算出的数。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func battle() -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(2, s)
	return l


func _run() -> void:
	var ref = XDB.load_json("oracle/passive.json")
	check("oracle_present", ref is Dictionary and ref.has("cases"))
	if not (ref is Dictionary and ref.has("cases")):
		return _finish()
	var cases := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		cases[c.id] = c
		for row in c.observed.get("rows", []):
			check(c.id + ".no_source_errors", row.get("sourceErrors", []).is_empty(), row)
	_guard(cases.guard.observed)
	_xpbstex(cases.xpbstex.observed)
	_tp(cases.pbstex_tp.observed)
	_finish()


func _restrict_state() -> int:
	for st in XDB.table("States"):
		if st is Dictionary and int(st.get("restriction", 0)) == 4 and int(st.get("autoRemovalTiming", 0)) == 0 and st.get("dot", null) == null:
			return int(st.id)
	return 0


func _guard(o: Dictionary) -> void:
	var skill := XDB.rec("Skills", 1)
	var rs := _restrict_state()
	check("guard.restrict_state", rs > 0)
	var base_damage := {}
	for row in o.rows:
		if not row.learned:
			base_damage["%s.%s" % [row.inBattle, row.stun]] = float(row.damage)
	for row in o.rows:
		var tag := "guard.%s.%s.%s" % [row.inBattle, row.learned, row.stun]
		var l := battle()
		var a: XActor = l.actors[0]
		if row.learned:
			a.learn_skill(10089)
		if row.stun:
			a.add_state(rs)
			check(tag + ".cannot_move", not l.can_move(a))
		check(tag + ".is_guard", a.is_guard() == bool(row.isGuard), [a.is_guard(), row.isGuard])
		var res: Dictionary = XDamage.calculate(skill, l.enemies[0], a, {"variance": false, "critical": false, "vars": l.vars()})
		var guard: float = res.breakdown.row.guard
		var want_ratio: float = float(row.damage) / float(base_damage["%s.%s" % [row.inBattle, row.stun]])  # 原版 grd＝1：学了＝0.5
		check(tag + ".ratio", is_equal_approx(guard * float(a.grd) * 2.0 if row.learned else guard, 1.0 if row.learned else 1.0) and is_equal_approx(want_ratio, 0.5 if row.learned else 1.0), [guard, a.grd, want_ratio])
	# 没学的角色用防御指令（guarding）照旧
	var l2 := battle()
	var b: XActor = l2.actors[0]
	b.guarding = true
	check("guard.command_still_works", b.is_guard())
	var res2: Dictionary = XDamage.calculate(skill, l2.enemies[0], b, {"variance": false, "critical": false, "vars": l2.vars()})
	check("guard.command_factor", is_equal_approx(float(res2.breakdown.row.guard), 1.0 / (2.0 * b.grd)), res2.breakdown.row.guard)


func _set_rates(a: XActor, hr: float, mr: float) -> void:
	a.hp = hr * a.mhp
	a.mp = mr * a.mmp


func _xpbstex(o: Dictionary) -> void:
	for note in o.notes:
		var skill := XDB.rec("Skills", int(note.id))
		check("xpbstex.meta.%d" % int(note.id), skill.meta.has("passiveXPBSTEX2" if int(note.id) == 968 else "passiveXPBSTEX9"), skill.meta)
	var baseline := {}
	for row in o.rows:
		if row.ids.is_empty():
			baseline["%s.%s.%s" % [row.inBattle, row.hr, row.mr]] = row
	for row in o.rows:
		var key := "%s.%s.%s" % [row.inBattle, row.hr, row.mr]
		var want: Dictionary = baseline[key]
		var l := battle()
		var a: XActor = l.actors[0]
		_set_rates(a, float(row.hr), float(row.mr))
		var base2 := a.xparam(2)
		var base9 := a.xparam(9)
		for id in row.ids:
			a.learn_skill(int(id))
		_set_rates(a, float(row.hr), float(row.mr))
		var tag := "xpbstex.%s.%s.hr%.2f.mr%.2f" % [row.inBattle, "+".join(row.ids.map(func(x): return str(int(x)))), float(row.hr), float(row.mr)]
		check(tag + ".xparam2", is_equal_approx(a.xparam(2) - base2, float(row.xparam2) - float(want.xparam2)), [a.xparam(2) - base2, row.xparam2, want.xparam2])
		check(tag + ".xparam9", is_equal_approx(a.xparam(9) - base9, float(row.xparam9) - float(want.xparam9)), [a.xparam(9) - base9, row.xparam9, want.xparam9])


func _tp(o: Dictionary) -> void:
	var baseline := {}
	for row in o.rows:
		if row.ids.is_empty():
			baseline[int(row.tp)] = float(row.atk)
	for row in o.rows:
		var l := battle()
		var a: XActor = l.actors[0]
		var base := a.param(2)
		for id in row.ids:
			a.learn_skill(int(id))
		a.tp = float(row.tpRate) * a.max_tp()
		var gain: float = float(row.atk) - float(baseline[int(row.tp)])
		var got: float = a.param(2) - base
		var tag := "tp.%s.%.2f" % ["+".join(row.ids.map(func(x): return str(int(x)))), float(row.tpRate)]
		check(tag + ".gain_on_off", (got > 0.0) == (gain > 0.0), [got, gain])
		if gain > 0.0:
			check(tag + ".gain_value", is_equal_approx(got, floorf(a.param_base_direct(2) * 0.5)) and is_equal_approx(got, gain), [got, gain, a.param_base_direct(2)])


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
