extends Node
## 天启篇金钱重构专项（XTianqiMoney，金钱重构方案 v0.2，表 tianqi_data/money_table.json）。
## 场钱与标价（避开 4、各档价格倍数、难度奖励倍率）、装备卖价按品质、战斗金钱加成相加递减、重铸涨价／封顶／锁一条、
## 进阶四阶价、修炼八项全队共享与开放层、天平三样（价格翻倍、上限、饥荒线、换层清掉、出伤承伤、开战回满）、原版档与开关不变。

const CONFIG := "user://xiyou_tianqi_money_config.json"
var results: Array = []


class FakeEnemy:
	extends RefCounted
	var hidden := false
	var g := 0
	func gold_reward() -> int:
		return g


class FakeLogic:
	extends Object
	var state: XState
	var enemies: Array = []
	var actors: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(diff := "jianxian") -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, diff, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	XState.current = s
	return s


func _weapon_of_grade(g: int) -> int:
	for r in XDB.table("Weapons"):
		if r is Dictionary and str(r.get("name", "")) != "" and XQuality.grade(r) == g and not XEquipment.is_exclusive(r):
			return int(r.id)
	return 0


func _run() -> void:
	XMessageBox.auto = true
	seed(20261114)
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig._loaded_path = "<unloaded>"
	var M := XTianqiMoney
	# ---- 表与取整 ----
	_check("table", not M.data().is_empty() and (M.data().field_gold.by_floor as Array).size() == 36)
	var bad := []
	for n in [1, 4, 14, 40, 44, 45, 140, 1449, 3960, 41000, 99600, 123456]:
		var v := M.nice(n)
		if str(v).contains("4") or v <= 0:
			bad.append([n, v])
	_check("nice_no_four", bad.is_empty(), bad)
	_check("nice_values", M.nice(3300) == 3300 and M.nice(3349) == 3300 and M.nice(1449) == 1500 and M.nice(41000) == 50000 and M.nice(99600) == 100000, [M.nice(3349), M.nice(1449), M.nice(41000), M.nice(99600)])
	var tbl_bad := []
	for v in M.data().field_gold.by_floor:
		if str(int(v)).contains("4"):
			tbl_bad.append(v)
	_check("field_table_no_four", tbl_bad.is_empty(), tbl_bad)
	# ---- 场钱、难度 ----
	var s := _state("jianxian")
	_check("on", M.on(s))
	_check("reward_jianxian", is_equal_approx(XTianqiBalance.reward_mult(s), 1.1), XTianqiBalance.reward_mult(s))
	_check("reward_keys", is_equal_approx(XTianqiBalance.reward_of("xunchang"), 1.0) and is_equal_approx(XTianqiBalance.reward_of("zhengdao"), 1.8))
	s.set_variable(20, 10)
	_check("field_floor10", is_equal_approx(M.field_money(s), 3300.0 * 1.1), M.field_money(s))
	_check("price_mult_jianxian", is_equal_approx(M.price_mult(s), 0.8))
	_check("price_units", M.price(s, 3) == M.nice(3.0 * 3300.0 * 1.1 * 0.8), M.price(s, 3))
	s.set_variable(20, 99)
	_check("field_clamp_top", is_equal_approx(M.field_base(99), 390000.0))
	s.set_variable(20, 10)
	# 证道同一样东西更贵：场钱 ×1.8、价格倍数 1.7
	var z := _state("zhengdao")
	z.set_variable(20, 10)
	var x := _state("xunchang")
	x.set_variable(20, 10)
	_check("zhengdao_dearer", M.price(z, 30) > M.price(x, 30) * 4, [M.price(z, 30), M.price(x, 30)])
	XState.current = s
	# ---- 卖价 ----
	var w_hi := _weapon_of_grade(4)
	var w_lo := _weapon_of_grade(0)
	_check("found_weapons", w_hi > 0 and w_lo > 0, [w_hi, w_lo])
	var hi := XGear.create("weapon", w_hi, s)
	var lo := XGear.create("weapon", w_lo, s)
	var g_hi := XFabaoFeed.grade_of(hi)
	var exp_hi := M.nice(float(M.data().sell.by_grade[g_hi]) * M.field_money(s))
	_check("sell_by_grade", XItemMarks.selling_price(hi) == exp_hi and XItemMarks.selling_price(lo) < exp_hi, [XItemMarks.selling_price(hi), exp_hi, XItemMarks.selling_price(lo), g_hi])
	var potion := XDB.rec("Items", 1).duplicate()
	potion["price"] = 100
	_check("item_unchanged", XItemMarks.selling_price(potion) == 50)
	M.SELL = false
	_check("sell_off", XItemMarks.selling_price(hi) == int(hi.get("price", 0)) / 2 or hi.has("sellPrice"))
	M.SELL = true
	# ---- 战斗金钱 ----
	_check("effective_200", is_equal_approx(M.effective(200.0), 100.0) and is_equal_approx(M.effective(-150.0), -90.0) and M.effective(10000.0) < 200.0)
	var lg := FakeLogic.new()
	lg.state = s
	var e1 := FakeEnemy.new()
	e1.g = 100
	var e2 := FakeEnemy.new()
	e2.g = 999
	e2.hidden = true
	lg.enemies = [e1, e2]
	var bonus := M.income_bonus(XTianqiAffixBattle.members(s), s)
	var out := {"gold": 1}
	M.battle_gold(lg, out)
	var want := int(floorf(100.0 * (1.0 + M.effective(bonus) / 100.0) * 1.1)) * 5
	_check("battle_gold", int(out.gold) == want, [out.gold, want, bonus])
	var zero := {"gold": 0}
	M.battle_gold(lg, zero)
	_check("battle_gold_zero_stays", int(zero.gold) == 0)
	M.INCOME = false
	var keep := {"gold": 7}
	M.battle_gold(lg, keep)
	_check("income_off", int(keep.gold) == 7)
	M.INCOME = true
	lg.free()
	# ---- 重铸 ----
	var it := XGear.create("weapon", w_hi, s)
	it["tianqi_affixes"] = [{"key": "a", "tier": 1}, {"key": "b", "tier": 4}]
	var p0 := M.reforge_price(s, it, it.tianqi_affixes[1])
	_check("reforge_tier_coef", p0 == M.price(s, 3 * 5), [p0, M.price(s, 15)])
	it["tq_reforges"] = 1
	_check("reforge_step", M.reforge_price(s, it, it.tianqi_affixes[1]) == M.price(s, 15 * 1.3))
	it["tq_reforges"] = 50
	_check("reforge_cap", is_equal_approx(M.reforge_escalation(it), 10.0))
	it["tq_reforges"] = 0
	_check("lock_price", M.lock_price(s, it, 1) == M.price(s, 3 * 1 * 3), M.lock_price(s, it, 1))
	# 真装备：单条重铸记次数涨价；锁一条洗其余，锁住的不变、扣锁价
	var real := XGear.create("weapon", w_hi, s)
	var bl := XTianqiAffixRoll.layer_candidates(real, "base")
	_check("base_layer", bl.size() >= 5, bl)
	if bl.size() < 5:
		bl = ["", "", ""]
	XTianqiAffixRoll.set_affixes(real, [{"key": str(bl[0]), "tier": 2, "grade": "normal", "extra": {}},
		{"key": str(bl[1]), "tier": 2, "grade": "normal", "extra": {}},
		{"key": str(bl[2]), "tier": 2, "grade": "normal", "extra": {}}])
	s.register_gear(real)
	s.gear.append(real)
	s.gold = 100000000
	var gp := XTianqiReforge.price_of(s, real, 0)
	var gb := s.gold
	var rr := XTianqiReforge.reforge(s, real, 0, func(): return 0.3)
	_check("reforge_counts", rr.has("ok") and s.gold == gb - gp and int(real.get("tq_reforges", 0)) == 1 and XTianqiReforge.price_of(s, real, 0) > gp, [rr, gp, s.gold])
	var kept: Dictionary = (real.tianqi_affixes as Array)[1].duplicate(true)
	var lp := M.lock_price(s, real, 1)
	gb = s.gold
	var rl := XTianqiReforge.reforge_locked(s, real, 1, func(): return 0.7)
	_check("lock_keeps", rl.has("ok") and str(real.tianqi_affixes[1].key) == str(kept.key) and s.gold == gb - lp and int(real.tq_reforges) == 2, [rl, lp])
	var keys: Array = (real.tianqi_affixes as Array).map(func(q): return str(q.key))
	_check("lock_no_dup", keys.size() == 3 and keys[0] != keys[2] and keys[0] != keys[1], keys)
	# ---- 进阶 ----
	var row0 = null
	for r in XAdvance.rows():
		if int(r.num) == 1 and XAdvance.rows().any(func(q): return int(q.actor) == int(r.actor) and int(q.num) == 0):
			row0 = r
			break
	_check("advance_row_found", row0 != null)
	if row0 != null:
		var aid := int(row0.actor)
		s.actor_advance.erase(aid)
		var r0 = XAdvance.row(s, aid)
		s.actor_advance[aid] = 1
		var r1 = XAdvance.row(s, aid)
		_check("advance_gold", int(r0.gold) == 100000 and int(r1.gold) == 300000, [r0.gold, r1.gold])
		M.ADVANCE = false
		_check("advance_off", int(XAdvance.row(s, aid).gold) == int(row0.gold))
		M.ADVANCE = true
		s.actor_advance.erase(aid)
	# ---- 修炼 ----
	s.set_variable(20, 2)
	_check("train_closed_low", M.training_open(s) == 0 and M.train(s, 2).begins_with("本层只开放"))
	s.set_variable(20, 7)
	_check("train_open_7", M.training_open(s) == 2)
	_check("listed_eight", XTraining.listed().size() == 8 and XTraining.listed()[0].get("tianqi", false))
	var a: XActor = s.members()[0]
	var b: XActor = s.members()[1]
	var atk0 := a.param_base(2)
	s.gold = 100000000
	var g0 := s.gold
	var msg := XTraining.confirm(s, a.actor_id, 2)
	_check("train_ok", msg == "修炼成功" and M.training_level(s, 2) == 1 and s.gold == g0 - M.training_price(s, 1), [msg, s.gold])
	_check("train_shared", XTraining.level(s, b.actor_id, 2) == 1)
	var want_bonus := floorf(a.param_base_direct(2) * 0.01)
	_check("train_bonus", is_equal_approx(XTraining.param_bonus(a, 2), want_bonus), [XTraining.param_bonus(a, 2), want_bonus, atk0])
	M.train(s, 2)
	_check("train_capped_by_floor", M.train(s, 2).begins_with("本层只开放") and M.training_level(s, 2) == 2)
	_check("train_price_step", M.training_price(s, 2) == M.price(s, 30 * 1.3))
	_check("train_line", XTraining.lines(s, a.actor_id)[0].contains("下一级费用"), XTraining.lines(s, a.actor_id)[0])
	s.set_variable(20, 10)
	# ---- 天平 ----
	s.gold = 100000000
	var sp1 := M.scale_price(s)
	var r1 := M.buy_good(s, "oil")
	var sp2 := M.scale_price(s)
	_check("scale_buy", r1.has("ok") and sp1 == M.price(s, 30) and sp2 == M.price(s, 60), [r1, sp1, sp2])
	_check("scale_no_twice", M.buy_good(s, "oil").has("error"))
	_check("scale_taken", is_equal_approx(M.scale_taken_mult(s), 0.9) and is_equal_approx(M.scale_dealt_mult(s), 1.0))
	M.buy_good(s, "wine")
	_check("scale_dealt", is_equal_approx(M.scale_dealt_mult(s), 1.1))
	var r3 := M.buy_good(s, "wheat")
	_check("scale_three", r3.has("ok") and int(M.scale_state(s).buys) == 3)
	# 麦：开战回满
	var lg2 := FakeLogic.new()
	lg2.actors = [a]
	a.hp = 1
	M.battle_setup(lg2, s)
	_check("wheat_heal", a.hp == a.mhp)
	lg2.free()
	# 出伤承伤进了 XTianqiCombat
	_check("combat_parts", is_equal_approx(float(XTianqiCombat.dealt_parts(a, s).get("scale", 0.0)), 1.1) and is_equal_approx(float(XTianqiCombat.taken_parts(a, s).get("scale", 0.0)), 0.9))
	# 换层清掉
	s.set_variable(20, 11)
	_check("scale_reset", not M.has_good(s, "oil") and int(M.scale_state(s).buys) == 0 and is_equal_approx(M.scale_taken_mult(s), 1.0))
	# 饥荒线贵五成
	var base_p := M.scale_price(s)
	s.flags.tianqi["line"] = "famine"
	_check("scale_famine", M.scale_price(s) == M.price(s, 45), [M.scale_price(s), base_p])
	s.flags.tianqi.erase("line")
	_check("scale_intercepts", M.intercepts(s, 4, 43) and not M.intercepts(s, 4, 42) and not M.intercepts(s, 5, 43))
	# ---- 原版档、总开关 ----
	var plain := XState.new_game(3, 1, [8, 9, 10])
	XState.current = plain
	_check("plain_off", not M.on(plain) and M.sell_price(hi, plain) == -1 and M.advance_gold(plain, 0) == -1 and not M.training_on(plain) and not M.intercepts(plain, 4, 43))
	_check("plain_reward", is_equal_approx(XTianqiBalance.reward_mult(plain), 1.0))
	XState.current = s
	M.ENABLED = false
	_check("all_off", not M.on(s) and XItemMarks.selling_price(potion) == 50 and not M.training_on(s) and is_equal_approx(M.scale_dealt_mult(s), 1.0))
	M.ENABLED = true
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig.path_override = ""
	XConfig._loaded_path = "<unloaded>"
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
