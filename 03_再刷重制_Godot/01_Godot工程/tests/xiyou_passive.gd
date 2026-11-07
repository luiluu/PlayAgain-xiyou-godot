extends Node
## dsPassiveSkill 三处补齐（passive1），对照 oracle/passive.json（mv_oracle/passive_probe.cjs 量冻结正式源）：
## ① <passiveGUARD>（技能 10089 苍龙*破晓）：isGuard 恒真（不看能不能行动），受伤折减 ÷(2×grd)
## ② <passiveXPBSTEXn:上升量,条件,判定值>（技能 968 暴击率、3886 TP 回复率）：条件满足才加追加能力值
## ③ passivePBSTEX 的 TPUP／TPLW 条件（技能 3219、4924）。
## ④ <passiveSTREG状态编号> 状态无效化（rules-gaps1）：学技能后的抵抗表、addState 挂不挂、状态 686 经特性 43 给 5500、防具 4088 备注不读。
## ⑤ <SkillCriPush…: n%> 暴击率增加：原版正则对不上 %、恒 0（FIX_CRIT_PUSH = false 对原版）；默认修好后按标签加；v0.62.12 暴击下限（攻击方 ≤0 记 0）。能力值基数与原版不同，所以比「有没有加成、加成随条件的开关」与可由重制自己的基数算出的数。
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
	_streg(cases.streg)
	_cripush(cases.cripush.observed)
	_state_rebuild()
	_finish()


## v0.62 dsPassiveSkill：状态增删后按签名重建被动缓存（角色、敌人都是）。七星续命 252 带 passiveHarmRe01～09:500。
func _state_rebuild() -> void:
	var l := battle()
	for b: XBattler in [l.actors[0], l.enemies[0]]:
		var tag := "state_rebuild.%s" % ("actor" if b is XActor else "enemy")
		b.state_ids.clear()
		b.refresh_passive()
		check(tag + ".before", float(b.passive_cache().harmRe.get(1, 0.0)) == 0.0, b.passive_cache().harmRe)
		b.add_state(252)
		check(tag + ".added", b.state_ids.has(252) and float(b.passive_cache().harmRe.get(1, 0.0)) == 500.0, b.passive_cache().harmRe)
		b.remove_state(252)
		check(tag + ".removed", float(b.passive_cache().harmRe.get(1, 0.0)) == 0.0, b.passive_cache().harmRe)


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
	# 原版 isGuard = specialFlag(GUARD) && canMove()：防御后被挂不能行动状态，防御指令那支不再减伤（passiveGUARD 那支不看 canMove，上面已对原版比过）
	b.add_state(rs)
	check("guard.command_needs_can_move", not l2.can_move(b) and not b.is_guard())
	var res3: Dictionary = XDamage.calculate(skill, l2.enemies[0], b, {"variance": false, "critical": false, "vars": l2.vars()})
	check("guard.command_factor_stunned", is_equal_approx(float(res3.breakdown.row.guard), 1.0), res3.breakdown.row.guard)


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


func _streg(c: Dictionary) -> void:
	var ids: Array = c.setup.stateIds
	for note in c.observed.notes:
		var keys: Array = XDB.rec("Skills", int(note.id)).get("meta", {}).keys().filter(func(k): return str(k).begins_with("passiveSTREG"))
		keys.sort()
		var want: Array = note.keys.duplicate()
		want.sort()
		check("streg.meta.%d" % int(note.id), keys == want, [keys, want])
	for row in c.observed.rows:
		var l := battle()
		var a: XActor = l.actors[0]
		var tag := "streg.%s.%s" % [row.kind, "+".join(row.ids.map(func(x): return str(int(x))))]
		for id in row.ids:
			a.learn_skill(int(id))
		if row.kind == "state686":
			a.add_state(686)
			check(tag + ".has5500", a.skills().any(func(s): return int(s.id) == 5500) == bool(row.has5500))
		elif row.kind == "armor4088":
			var arm := XDB.rec("Armors", 4088)
			var slot := a.equip_slots().find(int(arm.etypeId))
			check(tag + ".slot", slot == int(row.slot), [slot, row.slot])
			a.equips[slot] = arm
			check(tag + ".equipped", a.equips.has(arm) == bool(row.equipped))
		var got := ids.filter(func(i): return a.traits_set(XBattler.TRAIT_STATE_RESIST).has(int(i))).map(func(i): return int(i))
		var want := (row.resist as Array).map(func(i): return int(i))
		check(tag + ".resist", got == want, [got, want])
		for st in row.get("added", {}):
			l.sequence_add_state(a, int(st))  # Game_Battler.addState（查 isStateAddable／抵抗）；重制 add_state 本身不查抵抗
			check(tag + ".added.%s" % st, a.state_ids.has(int(st)) == bool(row.added[st]), [a.state_ids, row.added])
			a.remove_state(int(st))


class PinnedActor extends XActor:
	var pin := {}
	func xparam(i: int) -> float:
		return float(pin[i]) if pin.has(i) else super.xparam(i)


func _cri_setup(l: XBattleLogic, a: XActor, objs: Array, which: String) -> void:
	if which == "armor":
		var arm := XDB.rec("Armors", int(objs[0].id))
		a.equips[a.equip_slots().find(int(arm.etypeId))] = arm
	elif which == "mf":
		a.learn_skill(int(objs[1].id))
	elif which == "id":
		a.learn_skill(int(objs[2].id))
	a.refresh_passive()


func _cripush(o: Dictionary) -> void:
	var objs: Array = o.objs
	# 原版（FIX_CRIT_PUSH = false）：critPush 恒 0，itemCri 就是面板暴击率
	XActor.FIX_CRIT_PUSH = false
	for row in o.rows:
		var l := battle()
		var a: XActor = l.actors[0]
		_cri_setup(l, a, objs, row.which)
		var c: Dictionary = a.passive_cache().critPush
		var tag := "cripush.original.%s" % row.which
		check(tag + ".cache", float(c.all) == float(row.critPush.all) and float(c.byType.Zj) == float(row.critPush.byType.Zj) and float(c.byType.Mf) == float(row.critPush.byType.Mf) and c.bySkill.size() == row.critPush.bySkill.size(), [c, row.critPush])
		check(tag + ".push0", a.crit_push(XDB.rec("Skills", 1)) == 0.0 and a.crit_push(XDB.rec("Skills", int(objs[1].id))) == 0.0)
		var e: XBattler = l.enemies[0]
		check(tag + ".itemCri1", is_equal_approx(l.item_cri(a, XDB.rec("Skills", 1), e), clampf(a.cri * (1.0 - e.cev), 0.0, 1.0)))
	# 默认修好：按标签加
	XActor.FIX_CRIT_PUSH = true
	var want := {"armor": [0.0, 0.0, 15.0, {}], "mf": [0.0, 10.0, 0.0, {}], "id": [0.0, 0.0, 0.0, {1339: 20.0, 1347: 20.0, 1687: 20.0}]}
	for which in want:
		var l := battle()
		var a: XActor = l.actors[0]
		_cri_setup(l, a, objs, which)
		var c: Dictionary = a.passive_cache().critPush
		var w: Array = want[which]
		check("cripush.fixed.%s.cache" % which, float(c.byType.Zj) == w[0] and float(c.byType.Mf) == w[1] and float(c.all) == w[2] and c.bySkill == w[3], c)
		var attack := XDB.rec("Skills", 1)
		var magic := {"id": 999999, "stypeId": 2}
		check("cripush.fixed.%s.push" % which, is_equal_approx(a.crit_push(attack), w[2] / 100.0) and is_equal_approx(a.crit_push(magic), (w[1] + w[2]) / 100.0) and is_equal_approx(a.crit_push({"id": 1339, "stypeId": 0}), (float(w[3].get(1339, 0.0)) + w[2]) / 100.0), [a.crit_push(attack), a.crit_push(magic)])
		var e: XBattler = l.enemies[0]
		check("cripush.fixed.%s.itemCri1" % which, is_equal_approx(l.item_cri(a, attack, e), clampf((a.cri + w[2] / 100.0) * (1.0 - e.cev), 0.0, 1.0)))
	# 暴击下限：攻击方暴击率 ≤0 时记 0（负负得正不再成立）
	for row in o.floor:
		var l := battle()
		var u := PinnedActor.new()
		var t := PinnedActor.new()
		u.setup(1)
		t.setup(8)
		u.pin[2] = float(row.cri)
		t.pin[3] = float(row.cev)
		var got := l.item_cri(u, XDB.rec("Skills", 1), t)
		check("cripush.floor.%.2f.%.2f" % [float(row.cri), float(row.cev)], is_equal_approx(got, float(row.itemCri)), [got, row.itemCri])


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
