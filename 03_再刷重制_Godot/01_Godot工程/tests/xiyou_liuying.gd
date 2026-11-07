extends Node
## 【cc·悟空·未经审查】179 流萤第一期（XLiuying）：与 mv_oracle/liuying_probe.cjs 的新源 v0.62.12 参照（tests/fixtures/liuying_oracle.json）逐例比。
## - skills.*：新建角色（不同步）、changeLevel 到各级 × 进阶 0～3 后的已学技能；rankdown：降阶后 levelUp 忘掉越阶的；learnZhuiLuo：连带学梦应；
## - params.*：60 级、不戴／戴专武与法宝 × 六组被动的八项能力值、paramPlus(0/2/6)、shieldEffectBonus、actionPlusSet；rank1：一阶再动；
## - ember.*：逐火两场与卸下专武后一场（含缺胜场字段只估一次、已有胜场不被改写、2000 场后递减）；另查逐火随存档往返；
## - formula：两招 × 护盾 × 施放前快照的公式值、别的技能 0、别人用也照算、AI 估值；
## - recruit：入队、专武／法宝装进槽、已在队返回否；recruit.locked：超强者门槛；
## - battle.basics：必中、不闪避、段数、天火要剑；hook.*：每例新开一场，天火（燃烧）第一段伤害对 hook.base 的比值。
const FIXTURE := "res://tests/fixtures/liuying_oracle.json"
const RATIO_TOLERANCE := 1e-6
var results := []
var base_first := [0.0, 0.0]


class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648
	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return floori(n * value) if n > 0 else 0
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return lo + floori((hi - lo + 1) * value)


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 30:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _ints(v) -> Array:
	return (v as Array).map(func(x): return int(x))


func _floats(v) -> Array:
	return (v as Array).map(func(x): return float(x))


func _list() -> Array:
	return [10622, 10623, 10624, 10625, 10626, 10627, 10628, 10629, 10630, 10631, 10632, XLiuying.meng_ying_id()]


func _skills(a: XActor) -> Array:
	var l := _list()
	var out := a.skill_ids.filter(func(i): return l.has(i))
	out.sort()
	return out


func _params(a: XActor) -> Array:
	a.param_mark_dirty()
	return range(8).map(func(i): return a.param(i))


func _fresh() -> XActor:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.party.clear()
	s.battle_slots.clear()
	s.set_switch(2494, true)  # 流萤是超强者：开挑战才能入队（同参照）
	return s.actor(XLiuying.ACTOR)


func _rank(a: XActor, r: int) -> void:
	XState.current.actor_advance[a.actor_id] = r


func _set_passives(a: XActor, on: Array) -> void:
	for id in [XLiuying.GUO_ZAI, XLiuying.ZI_XIAN, XLiuying.CHI_RAN, XLiuying.ZHUI_LUO, XLiuying.XING_HE, XLiuying.FEI_YING, XLiuying.CHANG_YE, XLiuying.MING_TIAN]:
		if on.has(id):
			if not a.skill_ids.has(id):
				a.skill_ids.append(id)
		else:
			a.skill_ids.erase(id)
	a.skill_ids.sort()
	a.refresh_passive()
	a.param_mark_dirty()


func _slot(a: XActor, kind: String, base: int) -> int:
	return a.equip_slots().find(int(XDB.rec("Weapons" if kind == "weapon" else "Armors", base).etypeId))


func _worn(a: XActor, kind: String, base: int) -> int:
	var e = a.equips[_slot(a, kind, base)]
	return int(e.get("base", 0)) if e is Dictionary else 0


func _skills_case(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var a := _fresh()
	if c.id == "skills.new":
		check(c.id, [a.level, _skills(a)] == [int(o.level), _ints(o.skills)], [a.level, _skills(a), o])
		return
	if c.id == "skills.learnZhuiLuo":
		a.learn_skill(XLiuying.ZHUI_LUO)
		check(c.id, _skills(a) == _ints(o.skills) and XLiuying.meng_ying_id() == int(o.meng), [_skills(a), XLiuying.meng_ying_id(), o])
		return
	if c.id == "skills.rankdown":
		_rank(a, 3)
		a.change_level_mv(59)
		var before := _skills(a)
		_rank(a, 0)
		a.change_level_mv(60)
		check(c.id, [before, _skills(a), a.level] == [_ints(o.before), _ints(o.after), int(o.level)], [before, _skills(a), o])
		return
	_rank(a, int(c.setup.rank))
	a.change_level_mv(int(c.setup.level))
	check(c.id, _skills(a) == _ints(o.skills), [_skills(a), o.skills])


## 读档同步：存档里技能表是空的旧档，读回后按等级、进阶补齐（extractSaveContents 包装）
func _load_sync() -> void:
	var a := _fresh()
	a.change_level_mv(60)
	_rank(a, 2)
	var s := XState.current
	s.add_actor(XLiuying.ACTOR)
	var d := s.to_dict()
	d.actors[str(XLiuying.ACTOR)].skills = [10625, 10631]
	var s2 := XState.from_dict(d)
	var b: XActor = s2.actors[XLiuying.ACTOR]
	XState.current = s2
	check("load.sync", _skills(b) == [10622, 10623, 10624, 10625, 10626, 10627, 10628, 10629, 10630, XLiuying.meng_ying_id()], _skills(b))


func _params_case(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var a := _fresh()
	if c.id == "params.rank1":
		_rank(a, 1)
		a.change_level_mv(60)
		check(c.id, [_floats(a.action_plus_set()), _skills(a)] == [_floats(o.actionPlus), _ints(o.skills)], [a.action_plus_set(), _skills(a), o])
		return
	a.change_level_mv(60)
	if str(c.setup.gear) == "both":
		check(c.id + ".recruit", XLiuying.recruit(XState.current).size() == 3)
	check(c.id + ".gear", [_worn(a, "weapon", XLiuying.WEAPON), _worn(a, "armor", XLiuying.ARMOR)] == [int(o.weapon), int(o.armor)], [o.weapon, o.armor])
	for k in (o.rows as Array).size():
		var row: Dictionary = o.rows[k]
		_set_passives(a, _ints(row.on))
		var got := [_params(a), [0, 2, 6].map(func(i): return a._param_plus(i)), a.shield_effect_bonus(), _floats(a.action_plus_set())]
		var want := [_floats(row.params), _floats(row.plus), float(row.shieldBonus), _floats(row.actionPlus)]
		check("%s.%d" % [c.id, k], got == want, [row.on, got, want])


func _ember_case(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var a := _fresh()
	a.change_level_mv(10)
	XLiuying.recruit(XState.current)
	a.state_data["_codexLbEmber"] = float(c.setup.ember)
	if c.setup.wins == null:
		a.state_data.erase("_codexLbEmberWins")
	else:
		a.state_data["_codexLbEmberWins"] = float(c.setup.wins)
	for i in 2:
		XLiuying.gain_rewards([a])
		var w: Dictionary = o.steps[i]
		var got := [float(a.state_data._codexLbEmber), float(a.state_data._codexLbEmberWins), a._param_plus(0)]
		check("%s.%d" % [c.id, i], _near(got, [float(w.ember), float(w.wins), float(w.plus0)]), [got, w])
	XEquipment.change(XState.current, a, _slot(a, "weapon", XLiuying.WEAPON), null)
	XLiuying.gain_rewards([a])
	var w2: Dictionary = o.steps[2]
	check(c.id + ".unequipped", _near([float(a.state_data._codexLbEmber), float(a.state_data._codexLbEmberWins)], [float(w2.ember), float(w2.wins)]), [a.state_data, w2])


func _near(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in got.size():
		if absf(float(got[i]) - float(want[i])) > 1e-9 * maxf(1.0, absf(float(want[i]))):
			return false
	return true


## 逐火随存档往返；已有胜场的读回后再胜一场不重估
func _ember_save() -> void:
	var a := _fresh()
	a.change_level_mv(10)
	var s := XState.current
	XLiuying.recruit(s)
	a.state_data["_codexLbEmber"] = 20000.0
	a.state_data["_codexLbEmberWins"] = 4000.0
	var s2 := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	XState.current = s2
	var b: XActor = s2.actors[XLiuying.ACTOR]
	check("ember.save", _near([float(b.state_data.get("_codexLbEmber", 0)), float(b.state_data.get("_codexLbEmberWins", 0))], [20000.0, 4000.0]), b.state_data)
	XLiuying.gain_rewards([b])
	check("ember.save.keep_wins", _near([float(b.state_data._codexLbEmber), float(b.state_data._codexLbEmberWins)], [20005.0, 4001.0]), b.state_data)


func _formula(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var a := _fresh()
	a.change_level_mv(60)
	XLiuying.recruit(XState.current)
	a.param_mark_dirty()
	check("formula.params", [a.mhp, a.atk, a.agi] == [float(o.mhp), float(o.atk), float(o.agi)], [a.mhp, a.atk, a.agi, o.mhp, o.atk, o.agi])
	var e := XEnemy.new().setup(3, XState.current.difficulty, 100.0)
	var bad := 0
	for row in o.rows:
		a.shield = float(row.shield)
		if row.cast == null:
			a.remove_meta("liuying_cast_shield")
		else:
			a.set_meta("liuying_cast_shield", float(row.cast))
		var v := XLiuying.formula(a, e, XDB.rec("Skills", int(row.id)))
		if v != float(row.value):
			bad += 1
			check("formula.%d.%s.%s" % [int(row.id), str(row.shield), str(row.cast)], false, [v, row.value])
	check("formula.rows", bad == 0 and (o.rows as Array).size() == 27, [bad, (o.rows as Array).size()])
	a.shield = 0.0
	a.remove_meta("liuying_cast_shield")
	check("formula.other", XLiuying.formula(XState.current.actor(1), e, XDB.rec("Skills", 10622)) == float(o.other), [o.other])
	check("formula.none", XLiuying.formula(null, e, XDB.rec("Skills", 10622)) == float(o.none))
	check("formula.ai", (o.est as Array).size() == 1 and XLiuying.ai_raw(a, e, XDB.rec("Skills", 10622)) == float(o.est[0]), [o.est])
	var exec := XFormulaExecution.run_item(XDB.rec("Skills", 10622), a, e, {})
	check("formula.module", bool(exec.get("available", false)) and float(exec.get("value", 0)) == float(o.rows[0].value), exec)


func _recruit(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var a := _fresh()
	var s := XState.current
	if c.id == "recruit.locked":
		s.set_switch(2494, false)
		check(c.id, XItemMarks.can_acquire_actor(s, XLiuying.ACTOR) == false and not bool(o.first), [o])
		return
	var first := XLiuying.recruit(s)
	check(c.id, [not first.is_empty(), XLiuying.recruit(s).is_empty(), _slot(a, "weapon", XLiuying.WEAPON), _slot(a, "armor", XLiuying.ARMOR),
		_worn(a, "weapon", XLiuying.WEAPON), _worn(a, "armor", XLiuying.ARMOR), _skills(a)]
		== [bool(o.first), not bool(o.again), int(o.weaponSlot), int(o.armorSlot), int(o.weapon), int(o.armor), _ints(o.skills)], [first, o])
	check(c.id + ".party", s.party.has(XLiuying.ACTOR))
	check(c.id + ".texts", first == XLiuying.RECRUIT_TEXT, first)
	check(c.id + ".horn", XItemMarks.recruit_actor_id(XDB.rec("Items", XLiuying.HORN)) == XLiuying.ACTOR)


## 同参照 battle()：level 级、进阶 rank、招募、按 gear 卸下专武／法宝、设被动；再入队 1；全队与敌群 3 生命加 1e12；开第一回合
func _battle(level: int, rank: int, on, gear: Dictionary) -> Array:
	var a := _fresh()
	var s := XState.current
	_rank(a, rank)
	a.change_level_mv(level)
	XLiuying.recruit(s)
	if not bool(gear.weapon):
		XEquipment.change(s, a, _slot(a, "weapon", XLiuying.WEAPON), null)
	if not bool(gear.armor):
		XEquipment.change(s, a, _slot(a, "armor", XLiuying.ARMOR), null)
	if on != null:
		_set_passives(a, _ints(on))
	s.add_actor(1)
	for id in s.party:
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
	var rand := XBattleRandom.create("0000000000000179")
	rand.rule = FixedStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for id in s.party:
		var b := s.actor(id)
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	logic.start_turn()
	return [logic, a]


func _hits(logic: XBattleLogic, a: XActor, logs: Array) -> Array:
	var out := []
	for l in logs:
		if l.get("type") == "hit" and l.get("user") == a and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)):
			out.append({"skill": int(l.skill.id), "target": "a%d" % l.target.actor_id if l.target is XActor else "e%d" % logic.enemies.find(l.target),
				"value": float(l.hp), "critical": bool(l.critical)})
	return out


func _basics(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(60, 2, null, {"weapon": true, "armor": true})
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var t: XEnemy = logic.enemies[0]
	var th := XDB.rec("Skills", 10622)
	var rs := XDB.rec("Skills", 10623)
	check("basics.hit", [logic.item_hit(a, th, t), logic.item_hit(a, rs, t)] == _floats(o.hit), [o.hit])
	check("basics.eva", [logic.item_eva(a, th, t), logic.item_eva(a, rs, t)] == _floats(o.eva), [o.eva])
	check("basics.repeats", [XLiuying.repeats(a, th, 1), XLiuying.repeats(a, rs, 1)] == _ints(o.repeats), [o.repeats])
	check("basics.canUse", [logic.can_use(a, th), logic.can_use(a, rs)] == (o.canUse as Array).map(func(v): return bool(v)), [o.canUse])
	_set_passives(a, [XLiuying.GUO_ZAI, XLiuying.ZI_XIAN, XLiuying.CHI_RAN, XLiuying.ZHUI_LUO, XLiuying.FEI_YING])
	check("basics.repeatsNoXingHe", XLiuying.repeats(a, th, 1) == int(o.repeatsNoXingHe))
	# 胜利发奖（BattleManager.gainRewards 包装）走到逐火：出战且戴专武，+10、胜场 1
	logic.grant({"gold": 0, "exp": 0, "drops": []})
	check("basics.grant_ember", [float(a.state_data.get("_codexLbEmber", 0)), float(a.state_data.get("_codexLbEmberWins", 0))] == [10.0, 1.0], a.state_data)
	XEquipment.change(XState.current, a, _slot(a, "weapon", XLiuying.WEAPON), null)
	check("basics.unarmed", logic.can_use(a, th) == bool(o.unarmed.canUse), [o.unarmed])
	logic.end_battle(0)


func _hook(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var setup: Dictionary = c.setup
	var is_rs: bool = c.id == "hook.ranshao"
	var r := _battle(60, int(setup.get("rank", 0)), setup.get("on"), setup.get("gear", {"weapon": true, "armor": true}))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	if not is_rs and not bool(setup.gear.weapon):  # 天火要剑：编号最小的能装的剑（不是专武）
		var wt := int(XDB.rec("Skills", 10622).requiredWtypeId1)
		for w in XDB.table("Weapons"):
			if w is Dictionary and int(w.get("wtypeId", 0)) == wt and int(w.id) != XLiuying.WEAPON and a.can_equip(w.merged({"kind": "weapon"})):
				XState.current.gain_gear("weapon", int(w.id), 1)
				XEquipment.change(XState.current, a, 0, XState.current.gear[XState.current.gear.size() - 1])
				break
	a.param_mark_dirty()
	if o.has("stats"):
		check(c.id + ".stats", [a.mhp, a.atk, a.agi] == [float(o.stats.mhp), float(o.stats.atk), float(o.stats.agi)], [a.mhp, a.atk, a.agi, o.stats])
	var hits := _hits(logic, a, logic.act(a, XDB.rec("Skills", 10623 if is_rs else 10622), logic.enemies[0]))
	logic.end_battle(0)
	if not check(c.id + ".first", not hits.is_empty() and o.first != null and [hits[0].skill, hits[0].target, hits[0].critical] == [int(o.first.skill), str(o.first.target), bool(o.first.critical)], [hits.slice(0, 1), o.first]):
		return
	if c.id == "hook.base":
		base_first = [float(hits[0].value), float(o.first.value)]
		return
	if is_rs or base_first[0] == 0.0:
		return
	var rg: float = float(hits[0].value) / base_first[0]
	var rw: float = float(o.first.value) / base_first[1]
	check(c.id + ".ratio", absf(rg - rw) <= RATIO_TOLERANCE * maxf(1.0, absf(rw)), [hits[0].value, o.first.value, rg, rw])


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	check("slice_has_179", not XDB.rec("Actors", XLiuying.ACTOR).is_empty())
	check("formula_module", str(XDB.rec("Skills", 10622).damage.get("formulaProgram", {}).get("module", "")) == "liuying")
	check("power_formula_ok", XPower.formula_ok(XDB.rec("Skills", 10622)))
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match kind:
			"skills":
				_skills_case(c)
			"params":
				_params_case(c)
			"ember":
				_ember_case(c)
			"formula":
				_formula(c)
			"recruit":
				_recruit(c)
			"battle":
				_basics(c)
			"hook":
				_hook(c)
	check("covers_all", seen.keys().size() == 7, seen.keys())
	_load_sync()
	_ember_save()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_liuying", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
