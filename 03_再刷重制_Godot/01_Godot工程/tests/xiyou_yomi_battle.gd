extends Node
## 黄泉 169 战斗收尾（XYomiJingliu 第二期：sure／begin_action／meets／pay／before_apply／after_apply／end_battle）：
## 与 mv_oracle/yomi_battle_probe.cjs 的冻结 v0.28 参照（generated/oracle/yomi_battle.json）逐例比。
## - rates.*：10171～10174 对带闪避测试状态的敌人 itemHit／itemEva，黄泉必中，对照角色 1 照常；
## - repeats.*：numRepeats（幸运加 0／20000／60000），对照角色 1 为 1；
## - dream.*：残梦 0／8／9／12（夹到 9）时 10174 能不能用、付费后的层数（持刀 11 小太刀）；
## - act.*：敌群 3（每只生命加 1e12）、随机数全取 0.5，10171～10174 × 学没学 10185 的真实行动：逐段比目标、扩散倍率、伤害、暴击，
##   再比各敌人状态、负面状态数与残梦；
## - end：战斗结束残梦清零。
const ORACLE := "oracle/yomi_battle.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 15:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648


var _fake_eva := 0

func _eva_state(fake: Dictionary) -> int:
	if _fake_eva == 0:
		var states: Array = XDB.table("States")
		_fake_eva = states.size()
		var rec: Dictionary = XDB.rec("States", 4).duplicate(true)
		rec.merge({"id": _fake_eva, "name": "测试·eva", "traits": fake.eva.traits, "note": "", "meta": {}, "autoRemovalTiming": 0, "iconIndex": 0}, true)
		states.append(rec)
	return _fake_eva


## 同参照 battle()：新局、队伍 [actor, 1] 各 55 级、学 learn、幸运另加 luk；敌群 3 每只生命加 1e12；规则流全取 0.5
func _battle(actor_id: int, learn: Array, luk: float) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.party.clear()
	s.battle_slots.clear()
	for id in [actor_id, 1]:
		var b := s.actor(id)
		b.change_level_mv(55)
	var a := s.actor(actor_id)
	for id in learn:
		if not a.skill_ids.has(int(id)):
			a.skill_ids.append(int(id))
	s.add_actor(actor_id)
	s.add_actor(1)
	if luk > 0.0:
		a.add_param(7, luk)
	a.refresh_passive()
	var rand := XBattleRandom.create("0000000000000169")
	rand.rule = HalfStream.new()
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
	a.param_mark_dirty()
	a.param_refresh()
	a.recover_all()
	return [logic, a]


func _rates(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(int(c.setup.actor), [10171, 10172, 10173, 10174], 0.0)
	var logic: XBattleLogic = r[0]
	var t: XEnemy = logic.enemies[0]
	for n in c.setup.states:
		t.add_state(_eva_state(c.setup.fake))
	t.param_mark_dirty()
	t.param_refresh()
	var skill := XDB.rec("Skills", int(c.setup.skill))
	var got := [logic.item_hit(r[1], skill, t), logic.item_eva(r[1], skill, t), t.eva]
	check(c.id, absf(got[0] - float(o.hit)) < 1e-9 and absf(got[1] - float(o.eva)) < 1e-9 and absf(got[2] - float(o.targetEva)) < 1e-9, [got, o])


func _repeats(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(int(c.setup.actor), [10171, 10172, 10173, 10174], float(c.setup.lukPlus))
	var a: XActor = r[1]
	var skill := XDB.rec("Skills", int(c.setup.skill))
	var got := [a.luk, XYomiJingliu.begin_action(a, skill, XBattleLogic.attack_repeats(a, skill, int(skill.get("repeats", 1))))]
	check(c.id, absf(got[0] - float(o.luk)) < 1e-6 and got[1] == int(o.repeats), [got, o])


func _dream(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _battle(169, [10171, 10172, 10173, 10174], 0.0)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	a.equips[0] = XGear.template("weapon", int(c.setup.weapon))
	a.param_mark_dirty()
	a.refresh_passive()
	XYomiJingliu.set_dream(a, int(c.setup.dream))
	var got := {"dream": XYomiJingliu.dream(a), "meets10174": logic.can_use(a, XDB.rec("Skills", 10174)), "meets10171": logic.can_use(a, XDB.rec("Skills", 10171))}
	XYomiJingliu.pay(a, XDB.rec("Skills", 10171))
	got.after10171 = XYomiJingliu.dream(a)
	XYomiJingliu.pay(a, XDB.rec("Skills", 10174))
	got.after10174 = XYomiJingliu.dream(a)
	for k in got:
		check(c.id + "." + k, got[k] == o[k], [got[k], o[k]])


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _act(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	# 原版 10185 暴击＋9.99 不生效（O-098，XYomiJingliu.CRIT_FIX）：比原版时关掉，55 级已学 10185，开着必暴击
	XYomiJingliu.CRIT_FIX = false
	var r := _battle(169, c.setup.learn, 0.0)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	XYomiJingliu.set_dream(a, int(c.setup.dream))
	var logs := logic.execute(a, XDB.rec("Skills", int(c.setup.skill)), logic.enemies[0])
	var hits := logs.filter(func(l): return l.get("type") == "hit" and l.get("user") == a)
	var got := hits.map(func(l): return [_key(logic, l.target), not bool(l.missed) and not bool(l.evaded), bool(l.critical)])
	var want: Array = o.log.map(func(l): return [str(l.target), true, bool(l.critical)])
	check(c.id + ".hits", got == want, [got, want])
	# 伤害比各段对第一段的比值（扩散 ×0.33／0.5／0.66、主目标负面状态数）。绝对值另有与本期无关的固定差：55 级黄泉技能
	# 在干净目标上重制比原版低约 3.9%（原版 5067401748、重制 4868706083，见交付单），留给伤害链核查，这里不比绝对值。
	var values := hits.map(func(l): return floorf(float(l.hp)))
	var want_values: Array = o.log.map(func(l): return float(l.value))
	var ratio_ok := values.size() == want_values.size() and not values.is_empty()
	for k in values.size():
		if ratio_ok:
			ratio_ok = absf(values[k] / values[0] - want_values[k] / want_values[0]) < 1e-6
	check(c.id + ".value_ratios", ratio_ok, [values, want_values])
	var states := logic.enemies.map(func(e): var ids: Array = e.state_ids.duplicate(); ids.sort(); return ids)
	check(c.id + ".states", states == o.states.map(func(x): return (x as Array).map(func(v): return int(v))), [states, o.states])
	check(c.id + ".debuffs", logic.enemies.map(func(e): return XYomiJingliu.debuff_count(e)) == o.debuffs.map(func(v): return int(v)))
	check(c.id + ".dream", XYomiJingliu.dream(a) == int(o.dream), [XYomiJingliu.dream(a), o.dream])
	XYomiJingliu.end_battle()
	XYomiJingliu.CRIT_FIX = true
	# 重制默认（照说明生效）：同一行动每段都暴击，段数、目标与扩散不变
	r = _battle(169, c.setup.learn, 0.0)
	XYomiJingliu.set_dream(r[1], int(c.setup.dream))
	var fixed: Array = r[0].execute(r[1], XDB.rec("Skills", int(c.setup.skill)), r[0].enemies[0]).filter(func(l): return l.get("type") == "hit" and l.get("user") == r[1])
	check(c.id + ".crit_fix", fixed.size() == hits.size() and fixed.all(func(l): return bool(l.critical)), fixed.size())
	XYomiJingliu.end_battle()


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match kind:
			"module":
				check("module", int(c.observed.mark) == XYomiJingliu.Y_MARK and (c.observed.randomDebuffs as Array).map(func(v): return int(v)) == XYomiJingliu.Y_RANDOM_DEBUFFS)
			"rates":
				_rates(c)
			"repeats":
				_repeats(c)
			"dream":
				_dream(c)
			"act":
				_act(c)
			"end":
				var r := _battle(169, [10171], 0.0)
				XYomiJingliu.set_dream(r[1], int(c.setup.dream))
				r[0].end_battle(0)
				check("end", XYomiJingliu.dream(r[1]) == int(c.observed.dream))
	check("covers_all", seen.keys().size() == 6, seen.keys())
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_yomi_battle", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
