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
	_signature()
	_guardian_and_dungeon()
	_filter_and_book()
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


## 招牌掉落：品质范围、材料概率不变、递增概率的长期平均、存档记账、读档重打结果一样
func _signature() -> void:
	var s := _tianqi_state()
	var by_grade := {}
	for t in ["Weapons", "Armors"]:
		for rec in XDB.table(t):
			if rec is Dictionary and str(rec.get("name", "")) != "" and not by_grade.has(XQuality.grade(rec)):
				by_grade[XQuality.grade(rec)] = [2 if t == "Weapons" else 3, int(rec.id)]
	var got := []
	for g in [3, 4, 5, 6]:
		var k: Array = by_grade[g]
		got.append([XTianqiDrop.signature_base(k[0], k[1], 0.0001), XTianqiDrop.signature_base(k[0], k[1], 0.5), XTianqiDrop.signature_base(k[0], k[1], 1.0)])
	_check("gear_ranges", got == [[0.03, 0.1, 1.0], [0.02, 0.06, 1.0], [0.01, 0.03, 1.0], [0.005, 0.02, 1.0]], got)
	var epic: Array = by_grade[3]
	_check("gear_in_range_kept", _near(XTianqiDrop.signature_base(epic[0], epic[1], 0.05), 0.05))
	_check("item_unchanged", _near(XTianqiDrop.signature_base(1, 1, 0.1), 0.02) and _near(XTianqiDrop.signature_base(1, 1, 1.0), 0.2) and _near(XTianqiDrop.signature_base(1, 1, 0.001), 0.005),
		[XTianqiDrop.signature_base(1, 1, 0.1), XTianqiDrop.signature_base(1, 1, 0.001)])
	# 递增步长：0.25 → 约 0.0847，0.05 → 约 0.0038（Dota 2 的表）
	_check("prd_step", absf(XTianqiDrop.prd_step(0.25) - 0.0847) < 0.001 and absf(XTianqiDrop.prd_step(0.05) - 0.0038) < 0.0002 and XTianqiDrop.prd_step(1.0) == 1.0,
		[XTianqiDrop.prd_step(0.25), XTianqiDrop.prd_step(0.05)])
	_check("chance_grows", XTianqiDrop.signature_chance(0.1, 0) < 0.1 and XTianqiDrop.signature_chance(0.1, 20) > 0.1 and XTianqiDrop.signature_chance(0.1, 1000) == 1.0)
	# 长期平均：10% 掷 6000 次，命中率在 10% 上下；最长连黑不超过步长的倒数
	XTianqiDrop.store(s)["seed"] = 20261113
	var hits := 0
	var streak := 0
	var worst := 0
	for i in 6000:
		if XTianqiDrop.roll_signature(s, "9:2:9", 0.1):
			hits += 1
			streak = 0
		else:
			streak += 1
			worst = maxi(worst, streak)
	_check("prd_mean", absf(float(hits) / 6000.0 - 0.1) < 0.01, float(hits) / 6000.0)
	_check("prd_bounded", worst <= ceili(1.0 / XTianqiDrop.prd_step(0.1)), worst)
	_check("pity_saved", (XTianqiDrop.store(s).pity["9:2:9"] as Array)[1] == 6000 and s.flags.tianqi.drop is Dictionary)
	# 读档重打：同样的账本，同一次掷结果相同
	var snap: Dictionary = s.flags.tianqi.drop.duplicate(true)
	var first := range(30).map(func(_i): return XTianqiDrop.roll_signature(s, "7:3:7", 0.2))
	s.flags.tianqi["drop"] = snap
	var again := range(30).map(func(_i): return XTianqiDrop.roll_signature(s, "7:3:7", 0.2))
	_check("reload_same", first == again and first.has(true) and first.has(false), first)
	_check("fails_view", XTianqiDrop.signature_fails(s, "7:3:7") >= 0 and XTianqiDrop.signature_fails(s, "nope") == 0)
	# 返修 P2：没有掉落账的旧档，首次的种子由存档派生，读同一个档再掷结果一样（不用手设种子）
	var old_s := _tianqi_state()
	old_s.flags.tianqi.erase("drop")
	var save_d := old_s.to_dict()
	var first_rolls := []
	var first_seeds := []
	for _k in 2:
		var ld := XState.from_dict(save_d.duplicate(true))
		XState.current = ld
		_check("legacy_no_drop", not ld.flags.tianqi.has("drop"))
		first_rolls.append(range(20).map(func(_i): return XTianqiDrop.roll_signature(ld, "5:3:5", 0.3)))
		first_seeds.append(int(ld.flags.tianqi.drop.seed))
	_check("legacy_reload_same", first_rolls[0] == first_rolls[1] and first_seeds[0] == first_seeds[1] and first_rolls[0].has(true), [first_seeds, first_rolls[0]])
	XTianqiDrop.SEED_FROM_SAVE = false
	var ld_off := XState.from_dict(save_d.duplicate(true))
	XTianqiDrop.store(ld_off)
	XTianqiDrop.SEED_FROM_SAVE = true
	_check("legacy_seed_switch", int(ld_off.flags.tianqi.drop.seed) != first_seeds[0], [ld_off.flags.tianqi.drop.seed, first_seeds[0]])
	XState.current = s
	# 返修 P2：必掉也算出了——同一键先累计连败，再 p＝1 必掉，连败清零、总次数推进，回到低概率从 0 起
	var pk := "6:2:6"
	XTianqiDrop.store(s).pity[pk] = [7, 7]
	_check("sure_hit", XTianqiDrop.roll_signature(s, pk, 1.0))
	_check("sure_resets_fails", (XTianqiDrop.store(s).pity[pk] as Array) == [0, 8], XTianqiDrop.store(s).pity[pk])
	var r_low := XTianqiDrop.roll_signature(s, pk, 0.01)
	var row_low: Array = XTianqiDrop.store(s).pity[pk]
	_check("low_after_sure_from_zero", int(row_low[1]) == 9 and int(row_low[0]) == (0 if r_low else 1), row_low)
	_check("sure_no_new_row", XTianqiDrop.roll_signature(s, "nope:1:1", 1.0) and not XTianqiDrop.store(s).pity.has("nope:1:1"))
	XTianqiDrop.PITY_RESET_ON_SURE = false
	XTianqiDrop.store(s).pity[pk] = [5, 5]
	XTianqiDrop.roll_signature(s, pk, 1.0)
	_check("sure_switch_off", (XTianqiDrop.store(s).pity[pk] as Array) == [5, 5])
	XTianqiDrop.PITY_RESET_ON_SURE = true
	# 接进战斗：留下的行带 sig 键、概率不再乘 0.2
	s.map_id = 5
	var lg := XBattleLogic.new()
	lg.setup(int(XDB.map(5).encounterList[0].troopId), s)
	var rows: Array = lg.drop_chances(lg.enemies[0], true)
	_check("rows_have_sig", not rows.is_empty() and rows.all(func(r): return r.has("sig") and float(r.chance) > 0.0 and float(r.chance) <= 1.0), rows)
	XTianqiDrop.SIGNATURE = false
	_check("switch_signature", lg.drop_chances(lg.enemies[0], true).all(func(r): return not r.has("sig")))
	XTianqiDrop.SIGNATURE = true
	lg.end_battle(1)


## 第三期：守层者固定给、副本档位品质上移、商店货不能喂
func _guardian_and_dungeon() -> void:
	var s := _tianqi_state()
	s.set_variable(20, 2)
	var g = XTianqiDrop.guardian_grades(s, 5)  # 敌群 5＝二层守层者；还没过二层 → 首杀
	_check("guardian_first", g is Array and g[0] == 2 and g[1] == [1, 0, 0, 0], g)
	s.set_variable(20, 3)
	_check("guardian_repeat", XTianqiDrop.guardian_grades(s, 5)[1] == [0, 0], XTianqiDrop.guardian_grades(s, 5))
	_check("not_guardian", XTianqiDrop.guardian_grades(s, 1) == null)
	var late := 0
	for t in XZhenqi.GUARDIANS:
		if int(XZhenqi.GUARDIANS[t]) == 29:
			late = int(t)
	s.set_variable(20, 33)
	_check("guardian_late_repeat", late > 0 and (XTianqiDrop.guardian_grades(s, late)[1] as Array).size() == 6, late)
	s.set_variable(20, 2)
	var got: Array = XTianqiDrop.roll(s, [], func(): return 0.5, 5)
	_check("guardian_roll_fixed", got.size() == 4, got)
	# 副本档位：王者档高一档、高两档权重翻倍（12：6 → 24：6，合计 115）
	_check("dungeon_up_outside", XTianqiDrop.dungeon_up(s) == 1.0)
	s.set_variable(XDungeon.VAR_INSIDE, 1)
	s.set_variable(XDungeon.VAR_TIER, 4)
	_check("dungeon_up_king", XTianqiDrop.dungeon_up(s) == 2.0, XTianqiDrop.dungeon_up(s))
	_check("dungeon_grade_shift", XTianqiDrop.roll_grade(12, 0.75, 2.0) == 3 and XTianqiDrop.roll_grade(12, 0.75) == 2 and XTianqiDrop.roll_grade(12, 0.73, 2.0) == 2,
		[XTianqiDrop.roll_grade(12, 0.75, 2.0), XTianqiDrop.roll_grade(12, 0.75)])
	s.set_variable(XDungeon.VAR_INSIDE, 0)
	# 商店货不能喂
	var before := s.gear.size()
	s.gain_gear("weapon", 1, 2)
	XTianqiDrop.mark_bought(s, before + 1)
	_check("bought_marked", not XTianqiDrop.feed_blocked(s, s.gear[before]) and XTianqiDrop.feed_blocked(s, s.gear[before + 1]))
	XTianqiDrop.NO_FEED_BOUGHT = false
	_check("switch_feed_bought", not XTianqiDrop.feed_blocked(s, s.gear[before + 1]))
	XTianqiDrop.NO_FEED_BOUGHT = true
	var old := XState.new_game_blank()
	XState.current = old
	var ob := old.gear.size()
	old.gain_gear("weapon", 1, 1)
	XTianqiDrop.mark_bought(old, ob)
	_check("legacy_not_marked", not old.gear[ob].has("tq_bought"))


## 第四期：挂机屏蔽掉落时低于门槛的折成钱；图鉴掉率用招牌面板概率、不列交给通用掉落的行
func _filter_and_book() -> void:
	var s := _tianqi_state()
	s.map_id = 13  # 六层：门槛优秀，低一档是普通
	s.set_variable(20, 6)
	var troop := int(XDB.map(13).encounterList[0].troopId)
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	var low := XTianqiDrop.pick(s, 6, 0, [], 0.9, 0.3)
	var ok := XTianqiDrop.pick(s, 6, 1, [], 0.9, 0.3)
	_check("filter_idle_keeps_all", XTianqiDrop._auto_sell(lg, [low, ok]).size() == 2)
	s.hang_up_active = true
	s.hang_up_origin = Vector2i(1, 1)
	s.flags.erase("HangUpProhibited")
	XHangUp.settings(s)["DropShield"] = true
	var kept: Array = XTianqiDrop._auto_sell(lg, [low, ok])
	var price := XTianqiMoney.sell_price_grade(s, XQuality.grade(XDB.rec("Weapons" if int(low.kind) == 2 else "Armors", int(low.id))))  # 金钱重构：按品质的卖价
	_check("auto_sell_uses_money_price", price > 0, price)
	_check("filter_sells_below_gate", XHangUp.is_active(s) and kept.size() == 1 and kept[0] == ok and int(lg.get_meta("tianqi_generic_gold", -1)) == price, [kept, lg.get_meta("tianqi_generic_gold", -1), price])
	var gold := s.gold
	_check("filter_gold_granted", XTianqiDrop.grant_sold(lg) == price and s.gold == gold + price and XTianqiDrop.grant_sold(lg) == 0)
	s.hang_up_active = false
	lg.end_battle(1)
	# 图鉴：一只带低品质装备的怪，列表里不出现那些行；概率等于招牌面板概率
	var enemy: Dictionary = {}
	for e in XDB.table("Enemies"):
		if not e is Dictionary:
			continue
		var all: Array = (e.get("dropItems", []) as Array).filter(func(d): return int(d.kind) > 0 and float(d.denominator) > 0).map(func(d): return [int(d.kind), int(d.dataId)])
		all.append_array(XBattleLogic._extra_drops(e).map(func(x): return [int(x.kind), int(x.id)]))
		if (e.get("dropItems", []) as Array).any(func(d): return int(d.kind) == 1 and float(d.denominator) > 1) and all.any(func(r): return not XTianqiDrop.keeps_row(s, r[0], r[1])):
			enemy = e
			break
	var rows: Array = XMapTransfer.drops(s, enemy)
	_check("book_rows_cut", not enemy.is_empty() and not rows.is_empty() and rows.all(func(r): return XTianqiDrop.keeps_row(s, int(r.kind), int(r.id))), rows.size())
	var item_row: Dictionary = rows.filter(func(r): return int(r.kind) == 1)[0]
	var raw := 0.0
	for d in enemy.dropItems:
		if int(d.kind) == 1 and int(d.dataId) == int(item_row.id):
			raw = 1.0 / float(d.denominator)
			break
	_check("book_rate_signature", absf(float(item_row.rate) - minf(100.0, XTianqiDrop.signature_base(1, int(item_row.id), raw) * XTianqiDrop.party_mult(s) * 100.0)) < 0.002, [item_row.rate, raw])
	XTianqiDrop.roll_signature(s, "%d:1:%d" % [int(enemy.id), int(item_row.id)], 0.0001)
	_check("book_fails_shown", int(XMapTransfer.drops(s, enemy).filter(func(r): return int(r.kind) == 1 and int(r.id) == int(item_row.id))[0].fails) >= 0)


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
