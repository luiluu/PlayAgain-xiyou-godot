extends Node
## 天启篇掉落重构第一期（XTianqiDrop）：
## 一、掉率加成：原值落档、技能重构定过的照它的值、相加后递减、寻宝猎人 +30、原版档不受影响。
## 二、难度倍率五档。
## 三、通用掉落：门槛档跟层走、品质权重、件数（第 1 层翻倍）、只管 1～30 层、挑出来的装备品质和等级对、不出专属和删除栏位。
## 四、怪物表：精良及以下的装备不掷，史诗以上和材料照掷；倍率不再有 ×5。
## 五、开关：ENABLED／GENERIC／BONUS／DIFFICULTY 各自回退。

var results: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	_bonus()
	_difficulty()
	_generic()
	_table_rows()
	_battle()
	_switches()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _tianqi_state(diff := "xunchang") -> XState:
	var s := XState.new_game_blank()
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": diff, "lineup": []}
	XState.current = s
	return s


func _near(a: float, b: float, eps := 0.001) -> bool:
	return absf(a - b) < eps


func _bonus() -> void:
	var s := _tianqi_state()
	_check("nice_numbers", XTianqiDrop.nice_number_violations().is_empty(), XTianqiDrop.nice_number_violations())
	_check("tier_steps", [3.0, 15.0, 18.0, 45.0, 50.0, 100.0, 150.0, 300.0, 1000.0].map(XTianqiDrop.tier) == [5.0, 5.0, 10.0, 10.0, 15.0, 15.0, 20.0, 20.0, 30.0],
		[3.0, 15.0, 18.0, 45.0, 50.0, 100.0, 150.0, 300.0, 1000.0].map(XTianqiDrop.tier))
	_check("tier_negative", XTianqiDrop.tier(-28.0) == -10.0 and XTianqiDrop.tier(0.0) == 0.0, XTianqiDrop.tier(-28.0))
	_check("effective_curve", _near(XTianqiDrop.effective(100.0), 66.667, 0.01) and _near(XTianqiDrop.effective(200.0), 100.0) and _near(XTianqiDrop.effective(300.0), 120.0)
		and _near(XTianqiDrop.effective(0.0), 0.0) and XTianqiDrop.effective(100000.0) < 200.0, XTianqiDrop.effective(100.0))
	_check("effective_negative", _near(XTianqiDrop.effective(-20.0), -20.0) and _near(XTianqiDrop.effective(-500.0), -90.0), XTianqiDrop.effective(-500.0))
	var a := s.actor(1)
	var base := XTianqiDrop.party_bonus(s, [a])
	a.learn_skill(509)  # 寻宝猎人 10% → 落档 5
	var with_plain := XTianqiDrop.party_bonus(s, [a])
	_check("plain_source_tiered", _near(with_plain - base, 5.0), [base, with_plain])
	_check("rework_value", XTianqiDrop.rework_value(2575) == 10.0 and is_nan(XTianqiDrop.rework_value(509)), XTianqiDrop.rework_value(2575))
	a.learn_skill(2575)  # 敛资：技能重构只对孙权生效；别人学到的还是原值 3% → 落档 5，孙权读到 10% 就照 10
	var with_reworked := XTianqiDrop.party_bonus(s, [a])
	var seen := XActor._num(a.skills().filter(func(k): return int(k.id) == 2575)[0].meta["passiveIRUP"])
	_check("reworked_source_kept", _near(with_reworked - with_plain, 10.0 if seen == 10.0 else 5.0), [with_plain, with_reworked, seen])
	a.learn_skill(5548)  # 普通难度被动：不算
	_check("difficulty_passive_ignored", _near(XTianqiDrop.party_bonus(s, [a]), with_reworked), XTianqiDrop.party_bonus(s, [a]))
	a.learn_skill(7198)  # 气运昌隆 5000% → 30
	_check("huge_source_capped", _near(XTianqiDrop.party_bonus(s, [a]) - with_reworked, 30.0), XTianqiDrop.party_bonus(s, [a]))
	_check("party_mult_below_three", XTianqiDrop.party_mult(s, [a]) < 3.0 and XTianqiDrop.party_mult(s, [a]) > 1.0, XTianqiDrop.party_mult(s, [a]))
	var old := XState.new_game_blank()
	XState.current = old
	_check("legacy_off", not XTianqiDrop.on(old) and not XTianqiDrop.generic_on(old) and XTianqiDrop.keeps_row(old, 2, 1))


func _difficulty() -> void:
	var got := ["xunchang", "jianxian", "jiusi", "lianyu", "zhengdao"].map(func(k): return XTianqiDrop.difficulty_mult(_tianqi_state(k)))
	_check("difficulty_mults", got == [1.0, 1.1, 1.3, 1.5, 1.8], got)


func _generic() -> void:
	var s := _tianqi_state()
	_check("gate_by_floor", [1, 5, 6, 11, 12, 18, 19, 25, 26, 30].map(XTianqiDrop.gate_grade) == [0, 0, 1, 1, 2, 2, 3, 3, 4, 4], [1, 5, 6, 11, 12, 18, 19, 25, 26, 30].map(XTianqiDrop.gate_grade))
	# 品质权重 30／55／12／3：门槛 2（12 层）时 → 1、2、3、4
	_check("grade_weights", [0.0, 0.29, 0.31, 0.84, 0.86, 0.96, 0.98, 0.999].map(func(r): return XTianqiDrop.roll_grade(12, r)) == [1, 1, 2, 2, 3, 3, 4, 4],
		[0.0, 0.29, 0.31, 0.84, 0.86, 0.96, 0.98, 0.999].map(func(r): return XTianqiDrop.roll_grade(12, r)))
	_check("grade_floor_clamped", XTianqiDrop.roll_grade(1, 0.0) == 0 and XTianqiDrop.roll_grade(1, 0.999) == 2, XTianqiDrop.roll_grade(1, 0.999))
	_check("grade_top_clamped", XTianqiDrop.roll_grade(30, 0.999) == 5 and XTianqiDrop.roll_grade(30, 0.9) == 5, XTianqiDrop.roll_grade(30, 0.999))
	_check("pieces", _near(XTianqiDrop.pieces(s, 2, []), 0.9) and _near(XTianqiDrop.pieces(s, 1, []), 1.8), [XTianqiDrop.pieces(s, 2, []), XTianqiDrop.pieces(s, 1, [])])
	_check("pieces_difficulty", _near(XTianqiDrop.pieces(_tianqi_state("lianyu"), 2, []), 1.35), XTianqiDrop.pieces(XState.current, 2, []))
	s = _tianqi_state()
	_check("level_by_floor", [1, 5, 7, 10, 29, 30].map(XTianqiDrop.level_of) == [10, 15, 23, 30, 75, 75], [1, 5, 7, 10, 29, 30].map(XTianqiDrop.level_of))
	for g in range(6):
		_check("pool_grade_%d" % g, not XTianqiDrop.pool(g).is_empty(), XTianqiDrop.pool(g).size())
	# 挑出来的：品质对、等级不超过这一层、不是专属、不是删除栏位
	var bad := []
	for floor_no in [1, 6, 12, 19, 26, 30]:
		for i in 40:
			var r := float(i) / 40.0
			var want := XTianqiDrop.roll_grade(floor_no, r)
			var d := XTianqiDrop.pick(s, floor_no, want, [s.actor(1)], 0.9, r)
			if d.is_empty():
				bad.append([floor_no, want, "empty"])
				continue
			var rec := XDB.rec("Weapons" if int(d.kind) == 2 else "Armors", int(d.id))
			if XQuality.grade(rec) > want or int(rec.get("meta", {}).get("req_level", 0)) > XTianqiDrop.level_of(floor_no) \
					or XEquipment._req_actors_re.search(str(rec.get("note", ""))) != null or (int(d.kind) == 3 and XTianqiGear.deleted_armor(int(d.id))) or not d.get("generic", false):
				bad.append([floor_no, want, d])
	_check("picks_valid", bad.is_empty(), bad.slice(0, 5))
	# 一场的件数：0.9 件 → 随机数 0.5 掷中 1 件、0.95 掷中 0 件
	s.map_id = 3  # 二层
	_check("floor_of_map", XTianqiDrop.floor_of(s) == 2, XTianqiDrop.floor_of(s))
	_check("roll_one", XTianqiDrop.roll(s, [], func(): return 0.5).size() == 1, XTianqiDrop.roll(s, [], func(): return 0.5))
	_check("roll_none", XTianqiDrop.roll(s, [], func(): return 0.95).is_empty())
	s.map_id = 148  # 31 层：归七印祭坛
	_check("floor_31_off", XTianqiDrop.floor_of(s) == 0 and XTianqiDrop.roll(s, [], func(): return 0.1).is_empty(), XTianqiDrop.floor_of(s))
	# 期望件数：固定种子掷 4000 场，二层寻常应在 0.9 上下
	s.map_id = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	var total := 0
	var by_grade := {}
	for i in 4000:
		for d in XTianqiDrop.roll(s, [], func(): return rng.randf()):
			total += 1
			var gr := XQuality.grade(XDB.rec("Weapons" if int(d.kind) == 2 else "Armors", int(d.id)))
			by_grade[gr] = int(by_grade.get(gr, 0)) + 1
	_check("mean_pieces", absf(float(total) / 4000.0 - 0.9) < 0.05, float(total) / 4000.0)
	_check("mostly_gate_or_below", float(int(by_grade.get(0, 0))) / float(maxi(1, total)) > 0.8, by_grade)


func _table_rows() -> void:
	var s := _tianqi_state()
	var cut := []
	var kept := []
	for t in ["Weapons", "Armors"]:
		for rec in XDB.table(t):
			if rec is Dictionary and str(rec.get("name", "")) != "":
				var k := 2 if t == "Weapons" else 3
				if XQuality.grade(rec) <= 2 and cut.size() < 3 and not XTianqiDrop.keeps_row(s, k, int(rec.id)):
					cut.append(int(rec.id))
				if XQuality.grade(rec) >= 3 and kept.size() < 3 and XTianqiDrop.keeps_row(s, k, int(rec.id)):
					kept.append(int(rec.id))
	_check("low_gear_rows_cut", cut.size() == 3, cut)
	_check("high_gear_rows_kept", kept.size() == 3, kept)
	_check("item_rows_kept", XTianqiDrop.keeps_row(s, 1, 1))


## 接进战斗：打赢的奖励里带通用掉落（同一场多次问结果一样）；倒下即发的锁着也照发；原版档没有
func _battle() -> void:
	var s := _tianqi_state()
	s.map_id = 5  # 一层：每场 1.8 件，至少 1 件
	var troop := int(XDB.map(5).encounterList[0].troopId)
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	for e in lg.enemies:
		e.hp = 0
	var first: Array = (lg.rewards().drops as Array).filter(func(d): return d.get("generic", false))
	var again: Array = (lg.rewards().drops as Array).filter(func(d): return d.get("generic", false))
	_check("battle_generic_in_rewards", first.size() >= 1 and first == again, [first, again])
	_check("battle_table_rate", is_equal_approx(XTianqiDrop.table_rate(lg), 0.2 * XTianqiDrop.party_mult(s, XTianqiAffixBattle.members(s))), XTianqiDrop.table_rate(lg))
	var before := s.gear.size()
	lg.drop_lock = true
	lg.grant(lg.rewards())
	_check("battle_generic_granted_when_locked", s.gear.size() - before == first.size(), [before, s.gear.size(), first.size()])
	lg.end_battle(0)
	var old := XState.new_game_blank()
	XState.current = old
	old.map_id = 5
	var lg2 := XBattleLogic.new()
	lg2.setup(troop, old)
	_check("battle_legacy_no_generic", (lg2.rewards().drops as Array).filter(func(d): return d.get("generic", false)).is_empty())
	lg2.end_battle(1)


func _switches() -> void:
	var s := _tianqi_state("lianyu")
	XTianqiDrop.DIFFICULTY = false
	_check("switch_difficulty", XTianqiDrop.difficulty_mult(s) == 1.0)
	XTianqiDrop.DIFFICULTY = true
	XTianqiDrop.GENERIC = false
	s.map_id = 3
	_check("switch_generic", not XTianqiDrop.generic_on(s) and XTianqiDrop.roll(s, [], func(): return 0.1).is_empty() and XTianqiDrop.keeps_row(s, 2, 1))
	XTianqiDrop.GENERIC = true
	XTianqiDrop.BONUS = false
	_check("switch_bonus", not XTianqiDrop.bonus_on(s) and XTianqiDrop.generic_on(s))
	XTianqiDrop.BONUS = true
	XTianqiDrop.ENABLED = false
	_check("switch_all", not XTianqiDrop.on(s) and not XTianqiDrop.generic_on(s) and not XTianqiDrop.bonus_on(s))
	XTianqiDrop.ENABLED = true
