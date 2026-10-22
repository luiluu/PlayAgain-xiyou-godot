extends Node
## 178 哈基米第一期（XCat）：逐例对照 mv_oracle/cat_probe.cjs（generated/oracle/cat.json）。
## - slots：刚生成的 178 去掉副手、不能双持，已学技能一致。
## - recruit：CodexCat.recruit()——入队、学 6216、装上新生成的法宝 7999 与练习剑 2（背包不留）、第二次返回 false、招募后能力值。
## - stats.*：武器槽放各种剑／斧（不卸，同参照）、法宝 7999，1／9／10／35／65／99 级逐级比 param、paramPlus、xparam、sparam、
##   元素增幅（持剑 671 例外：剑视图里已翻倍，伤害读元素增幅走 damage.gd 的 _yep_objects，待沙僧挂接，这里比视图本身）、攻击次数加值。
## - formula.*：五个剑技 × 10 个等级，未持剑与持剑＋法宝，比 CodexCat.formula 与成长。
## - chain.*：剑技连携（CAT BEGIN／CAT STRIKE）。敌群 2 第一个敌人（生命加 1e12，部分例加速度），随机数全取 0.5（同参照 Math.random）；
##   每步逐段比剑技 key、是否连携段、命中、暴击、CodexCat.formula 原值与伤害，再比剑心层数与状态、目标标记与状态、至圣斩冷却、喵铃回合。
const ORACLE := "oracle/cat.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(700))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _close(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(float(a[i]) - float(b[i])) > maxf(1e-6, absf(float(b[i])) * 1e-6):
			return false
	return true


func _equip_rows(a: XActor) -> Array:
	var out := []
	var slots := a.equip_slots()
	for i in a.equips.size():
		var e = a.equips[i]
		if e is Dictionary and not e.is_empty():
			out.append({"slot": i, "etype": int(slots[i]), "kind": str(e.kind), "base": int(e.base), "level": XEquipmentView.level(e)})
	return out


func _same_equips(mine: Array, theirs: Array) -> bool:
	if mine.size() != theirs.size():
		return false
	for i in mine.size():
		var m: Dictionary = mine[i]
		var t: Dictionary = theirs[i]
		if m.slot != int(t.slot) or m.etype != int(t.etype) or m.kind != t.kind or m.base != int(t.base) or float(m.level) != float(t.level):
			return false
	return true


func _compare_stats(tag: String, a: XActor, o: Dictionary, element := true) -> void:
	a.refresh_passive()
	check(tag + ".param", _close(range(8).map(func(i): return a.param(i)), o.param), [range(8).map(func(i): return a.param(i)), o.param])
	check(tag + ".paramPlus", _close(range(8).map(func(i): return a.param_plus(i)), o.paramPlus), [range(8).map(func(i): return a.param_plus(i)), o.paramPlus])
	check(tag + ".xparam", _close(range(10).map(func(i): return a.xparam(i)), o.xparam), [range(10).map(func(i): return a.xparam(i)), o.xparam])
	check(tag + ".sparam", _close(range(10).map(func(i): return a.sparam(i)), o.sparam), [range(10).map(func(i): return a.sparam(i)), o.sparam])
	if element:
		var bonus := [1, 2, 3, 8].map(func(e): return XDamage.element_bonus(a, e))
		check(tag + ".elementBonus", _close(bonus, o.elementBonus), [bonus, o.elementBonus])
	check(tag + ".attackTimesAdd", _close([a.attack_times_add()], [o.attackTimesAdd]), [a.attack_times_add(), o.attackTimesAdd])


func _put(a: XActor, g: String) -> void:
	if g == "relic":
		a.equips[a.equip_slots().find(13)] = XGear.template("armor", XCat.RELIC)
	else:
		a.equips[0] = XGear.template("weapon", int(g.trim_prefix("sword").trim_prefix("weapon")))


func _fresh(gear: Array) -> XActor:
	var a := XActor.new().setup(XCat.ACTOR)
	a.keep_unequippable = true
	for g in gear:
		_put(a, str(g))
	a.refresh_passive()
	return a


func _stats(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var a := _fresh(c.setup.gear)
	check(c.id + ".equips", _same_equips(_equip_rows(a), o.equips), [_equip_rows(a), o.equips])
	for lv in [1, 9, 10, 35, 65, 99]:
		var row: Dictionary = o.rows[str(lv)]
		a.change_level(lv)
		var tag := "%s.lv%d" % [c.id, lv]
		var skills := a.skill_ids.duplicate()
		check(tag + ".skills", skills == (row.skills as Array).map(func(v): return int(v)), [skills, row.skills])
		check(tag + ".flags", XCat.enabled_sword(a) == bool(row.sword) and XCat.has_relic(a) == bool(row.relic), [XCat.enabled_sword(a), row.sword, XCat.has_relic(a), row.relic])
		var doubled_element: bool = XCat.enabled_sword(a) and not a.equips[0].get("yep", {}).get("elementAmplify", {}).is_empty()
		_compare_stats(tag, a, row, not doubled_element)
		if doubled_element:
			var view := XCat.sword_view(a.equips[0])
			var amp := [1, 2, 3, 8].map(func(e): return float(view.yep.elementAmplify.get(str(e), 0.0)))
			check(tag + ".swordViewAmplify", _close(amp, row.elementBonus), [amp, row.elementBonus])


func _formula(c: Dictionary) -> void:
	var a := _fresh(c.setup.gear)
	for r in c.observed.rows:
		a.change_level(int(r.level))
		var tag := "%s.lv%d.s%d" % [c.id, int(r.level), int(r.skill)]
		var v := XCat.formula(a, XDB.rec("Skills", int(r.skill)))
		check(tag, _close([v, XCat.growth(a), XCat.mastery(a), a.atk, a.agi], [r.value, r.growth, r.mastery, r.atk, r.agi]),
			[[v, XCat.growth(a), XCat.mastery(a), a.atk, a.agi], r])
		# 伤害公式走转换器的 module 程序（XFormulaExecution.run_item → XCat.formula）
		var out := XFormulaExecution.run_item(XDB.rec("Skills", int(r.skill)), a, XEnemy.new().setup(1, 3, 100.0), [])
		check(tag + ".program", out.available and _close([out.value], [r.value]), [out, r.value])


func _recruit(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := XState.new_game(3, 1, [8, 9, 10])
	var first := XCat.recruit(s)
	var second := XCat.recruit(s)
	check("recruit.result", first == bool(o.first) and second == bool(o.second), [first, second, o.first, o.second])
	check("recruit.party", s.party == (o.party as Array).map(func(v): return int(v)), [s.party, o.party])
	var a := s.actor(XCat.ACTOR)
	check("recruit.skills", a.skill_ids == (o.skills as Array).map(func(v): return int(v)), [a.skill_ids, o.skills])
	check("recruit.equips", _same_equips(_equip_rows(a), o.equips), [_equip_rows(a), o.equips])
	check("recruit.flags", bool(s.flags.get("_codexCatRelicGranted")) == bool(o.relicGranted) and bool(s.flags.get("_codexCatStarterGranted")) == bool(o.starterGranted))
	check("recruit.inventory", s.gear.map(func(e): return int(e.base)) == o.inventory.weapons + o.inventory.armors, [s.gear.map(func(e): return int(e.base)), o.inventory])
	_compare_stats("recruit.stats", a, o.stats)
	# 法宝只给一次：离队再招不再生成第二件
	s.remove_actor(XCat.ACTOR)
	a.equips[a.equip_slots().find(13)] = null
	XCat.recruit(s)
	check("recruit.relic_once", a.equip_list().filter(func(e): return int(e.base) == XCat.RELIC).is_empty() and s.gear.is_empty(), _equip_rows(a))


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not (ref is Dictionary and ref.has("cases")):
		check("oracle_present", false)
		return finish()
	var manifest: Dictionary = XDB.load_json("manifest.json")
	check("same_source", ref.sourceIdentity.runtimeInputs == manifest.runtimeInputs)
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match kind:
			"module":
				var ids: Dictionary = c.observed.ids
				check("module", int(ids.actor) == XCat.ACTOR and int(ids.relic) == XCat.RELIC and int(ids.skill.sword) == XCat.SKILL_SWORD
					and int(ids.skill.speed) == XCat.SKILL_SPEED and int(ids.icon) == XCat.ICON and XCat.ACTIVE == [ids.skill.slash, ids.skill.cross, ids.skill.flurry, ids.skill.holy].map(func(v): return int(v)), ids)
			"slots":
				var a := XActor.new().setup(XCat.ACTOR)
				check("slots", a.equip_slots() == (c.observed.slots as Array).map(func(v): return int(v)) and a.is_dual_wield() == bool(c.observed.dual)
					and a.skill_ids == (c.observed.skills as Array).map(func(v): return int(v)) and _equip_rows(a).is_empty(), [a.equip_slots(), a.skill_ids, c.observed])
			"recruit":
				_recruit(c)
			"stats":
				_stats(c)
			"formula":
				_formula(c)
			"chain":
				_chain(c)
	check("covers_all", seen.keys().size() == 6, seen.keys())
	finish()


## 参照的 Math.random 恒 0.5：浮点取 0.5，整数取 2^31
class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648


func _chain(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var st: Dictionary = c.setup
	# 参照：新局（难度取 Init Difficulty ID）、等级上限放开到 99、队伍只有 178 与 1
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	s.actor_max_level = 99
	s.party.clear()
	s.battle_slots.clear()
	var a := s.actor(XCat.ACTOR)
	a.change_level_mv(int(st.level))
	a.equips[0] = XGear.template("weapon", int(st.sword))
	if bool(st.relic):
		a.equips[a.equip_slots().find(13)] = XGear.template("armor", XCat.RELIC)
	a.skill_ids.assign((o.skills as Array).map(func(v): return int(v)))
	a.refresh_passive()
	s.add_actor(XCat.ACTOR)
	s.add_actor(1)
	var rand := XBattleRandom.create("0000000000000178")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(int(st.troop), s, rand)
	var t: XEnemy = logic.enemies[int(st.target)]
	var p: Array = (t.data().params as Array).map(func(v): return float(v))
	p[0] += float(st.bigHp)
	p[6] += float(st.enemyAgiPlus)
	t.zq_ref = {"p": p, "k": 1.0}
	for b in [a, t]:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	var tag := str(c.id)
	check(tag + ".actor", a.atk == float(o.atk) and a.agi == float(o.agi) and a.skill_ids == (o.skills as Array).map(func(v): return int(v)),
		[a.atk, a.agi, o.atk, o.agi])
	var ep := range(8).map(func(i): return t.param(i))
	check(tag + ".enemy", _close(ep, o.enemy.params), [ep, o.enemy.params])
	for i in o.rows.size():
		var row: Dictionary = o.rows[i]
		var step := "%s.%d" % [tag, i]
		logic.turn = int(row.round)
		a.tp = 100.0
		XCat.trace = []
		var hp0 := t.hp
		logic.act(a, XDB.rec("Skills", int(row.skill)), t)
		var got: Array = XCat.trace
		XCat.trace = null
		var keys := got.map(func(x): return [str(x.key), bool(x.hit), bool(x.critical), bool(x.chain)])
		var want := (row.trace as Array).map(func(x): return [str(x.key), bool(x.hit), bool(x.critical), bool(x.chain)])
		check(step + ".segments", keys == want, [keys, want])
		var raw := got.map(func(x): return float(x.raw))
		check(step + ".raw", _close(raw, row.raw), [raw, row.raw])
		var dmg := got.map(func(x): return float(x.damage))
		check(step + ".damage", _close(dmg, (row.trace as Array).map(func(x): return float(x.damage))), [dmg, row.trace.map(func(x): return x.damage)])
		check(step + ".hp_lost", absf((hp0 - t.hp) - float(row.hpLost)) <= maxf(1.0, absf(float(row.hpLost)) * 1e-9), [hp0 - t.hp, row.hpLost])
		var d := XCat.battle_data(logic, a)
		check(step + ".heart", XCat.heart_of(logic, a) == int(row.heart) and _cat_states(a) == (row.actorStates as Array).map(func(v): return int(v)),
			[XCat.heart_of(logic, a), _cat_states(a), row.heart, row.actorStates])
		var marks := {}
		var mine: Dictionary = XCat.marks_of(logic, t)
		for id in mine:
			marks[str(id)] = {}
			for k in mine[id]:
				marks[str(id)][k] = float(mine[id][k])
		check(step + ".marks", marks == row.marks and _cat_states(t) == (row.targetStates as Array).map(func(v): return int(v)),
			[marks, _cat_states(t), row.marks, row.targetStates])
		check(step + ".holy_bell", int(d.holyReady) == int(row.holyReady if row.holyReady != null else 0)
			and int(d.bellRound) == int(row.bellRound if row.bellRound != null else 0), [d.holyReady, d.bellRound, row.holyReady, row.bellRound])
		if int(row.skill) != XBattleLogic.GUARD_SKILL:  # 防御的 TP 获得（技能 2 tpGain）Godot 通用防御分支没有，另报，不在本模块
			check(step + ".tp", a.tp == float(row.tp), [a.tp, row.tp])


static func _cat_states(b: XBattler) -> Array:
	return [2713, 2714, 2715, 2716, 2717].filter(func(id): return b.is_state_affected(id))


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
