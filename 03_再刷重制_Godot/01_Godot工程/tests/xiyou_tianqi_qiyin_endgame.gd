extends Node
## 天启篇七印终局收口专项（cc/tianqi-qiyin-endgame，Kyo 11-14 拍板；小A 评审 v0.1 P1 第 3、4 条、第三节第 6 点）。
## 一、随机流存档派生（O-待定-5）：种子由 orb_seed 派生、老档补得出同一个；读档（还原存档里的祭坛记录）后掷出一样的；计数前进；
##    龙、首杀招募也走存档；开关关掉回到每次现开。
## 二、七印掉率接掉率加成（O-待定-1）：drop_mult 和常规掉落 party_mult 一致、词条「物品掉落」抬得动、结算真用上；开关关掉按 1。
## 三、神器保底 333 次＋防重（O-待定-2）：332→333 必出且出了清零、不到 333 不出、只从没有的里出、五件齐了不掷不计、
##    里副本结算和七首之龙共用一个计数、老档补 0；开关关掉回到没有保底、可重复。
## 四、七印书卷（O-待定-3）：七条规则逐条看佩戴者自己也受、其余队友不受；文案；代价开关关掉回到只对敌方；
##    天启四骑士、34 层鸿钧的战斗里不揭（说一句），豁免开关关掉照揭。
## 五、默印 5 件「万籁俱寂」（O-待定-4）：技能号 10777、5 件才进战斗技能列表、放了敌方沉默、每场 1 次；开关关掉不给。
## （再动间隔 6／5／3／2 在 xiyou_tianqi_alien_affix 里验。）
## 数字避开 4（Kyo 11-11）：用例里的层号、敌群号照实写。

class FakeHost extends RefCounted:
	var answers: Array = []
	var asked: Array = []
	var said: Array = []
	func show_text(_f: String, _i: int, lines: Array) -> void:
		said.append_array(lines)
	func show_text_with_choices(_f: String, _i: int, lines: Array, options: Array, _cancel: int) -> int:
		said.append_array(lines)
		asked.append(options)
		return int(answers.pop_front()) if not answers.is_empty() else options.size() - 1
	func transfer(id: int, _x: int, _y: int, _d: int, _fade := 0) -> void:
		XState.current.map_id = id


## 按抽取原因喂值的随机流（同 xiyou_tianqi_qiyin_drop 的 Tape）：没写的原因给 fallback（浮点）／0（下标）
class Tape extends XRandomStream:
	var queues: Dictionary = {}
	var fallback := 0.999
	var seen: Array = []

	func _init(q := {}, fb := 0.999) -> void:
		queues = q.duplicate(true)
		fallback = fb

	func _pop(reason: String):
		seen.append(reason)
		draws += 1
		var q = queues.get(reason, [])
		if q is Array and not q.is_empty():
			return q.pop_front()
		return null

	func next_float(reason: String, _event_key := "") -> float:
		var v = _pop(reason)
		return fallback if v == null else float(v)

	func next_index_mod(n: int, reason: String, _event_key := "") -> int:
		var v = _pop(reason)
		return 0 if v == null else int(v) % n

	func count(reason: String) -> int:
		return seen.count(reason)


const ARMOR_ID := 1
const WEAPON_ID := 1

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


## 天启篇存档、5 个弱者、战争线开场已打完、变量 20 = floor；不注入随机流（存档派生要真走）
func _state(floor := 36) -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, floor)
	XState.current = s
	s.flags.tianqi["line"] = "war"
	XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	XTianqiQiyin.set_current("")
	XTianqiQiyin.rng_override = null
	XTianqiQiyinDragonRun.rng_override = null
	XTianqiQiyinShow.played = []
	return s


func _has(host: FakeHost, text: String) -> bool:
	return host.said.any(func(t): return str(t).contains(text))


func _run() -> void:
	XMessageBox.auto = true
	seed(20261114 + 1)
	XSave.dir_override = "user://test_xiyou_tianqi_qiyin_endgame"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	DirAccess.remove_absolute(XSave.dir_override.path_join("global.json"))
	await _seed()
	await _drop_mult()
	await _artifact_pity()
	await _artifact_dragon()
	_scroll_cost()
	_scroll_cost_bench()
	_scroll_exempt()
	_silence_skill()
	XTianqiQiyin.rng_override = null
	XTianqiQiyinDragonRun.rng_override = null
	DirAccess.remove_absolute(XGlobalVars.path())
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 一、随机流存档派生 ----

func _seed() -> void:
	var s := _state()
	var p := XTianqiQiyin.progress(s)
	var want := XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "qiyin")
	_check("seed_from_orb", str(p.seed) == want and int(p.rng_n) == 0, [p.seed, want])
	p.erase("seed")
	_check("seed_old_save_same", str(XTianqiQiyin.progress(s).seed) == want)
	var saved: Dictionary = p.duplicate(true)  # 「存档」
	var a1 := XTianqiQiyin._rng(s).next_float("t")
	var a2 := XTianqiQiyin._rng(s).next_float("t")
	_check("seed_counter_moves", int(XTianqiQiyin.progress(s).rng_n) == 2 and a1 != a2, [a1, a2])
	s.flags.tianqi["qiyin"] = saved.duplicate(true)  # 「读档」
	var b1 := XTianqiQiyin._rng(s).next_float("t")
	var b2 := XTianqiQiyin._rng(s).next_float("t")
	_check("seed_reload_same", a1 == b1 and a2 == b2, [a1, b1, a2, b2])
	s.flags.tianqi["qiyin"] = saved.duplicate(true)
	var d1 := XTianqiQiyinDragonRun._rng(s).next_float("t")
	s.flags.tianqi["qiyin"] = saved.duplicate(true)
	var d2 := XTianqiQiyinDragonRun._rng(s).next_float("t")
	_check("seed_dragon_reload_same", d1 == d2 and d1 != a1, [d1, d2, a1])
	# 首杀招募候选：读档后同一组
	s.flags.tianqi["qiyin"] = saved.duplicate(true)
	var o1 := XTianqiQiyinDragonRun.recruit_offer(s)
	s.flags.tianqi["qiyin"] = saved.duplicate(true)
	var o2 := XTianqiQiyinDragonRun.recruit_offer(s)
	_check("seed_recruit_reload_same", o1 == o2, [o1, o2])
	# 里副本结算整段：同一份存档结算两次，掉的一样
	s.flags.tianqi["qiyin"] = saved.duplicate(true)
	var g1: Array = await _settle_items(s)
	s.flags.tianqi["qiyin"] = saved.duplicate(true)
	var g2: Array = await _settle_items(s)
	_check("seed_settle_reload_same", g1 == g2 and int(XTianqiQiyin.progress(s).rng_n) > 0, [g1, g2])
	# 完整磁盘存读档：存档写盘再读回，种子、计数、神器保底计数、已得神器都在，读回后掷出和存档前一样
	s.flags.tianqi["qiyin"] = saved.duplicate(true)
	var pq := XTianqiQiyin.progress(s)
	pq.artifact_miss = 217
	pq.artifacts = ["scales"]
	pq["artifacts_got"] = ["bow_crown"]
	XTianqiQiyin._rng(s)
	var disk_ok := XSave.save(1)
	var before := XTianqiQiyin._rng(s).next_float("t")
	var orb0 := int(s.orb_seed)
	var loaded := XSave.load_slot(1)
	var s2 := XState.current
	var q2 := XTianqiQiyin.progress(s2)
	var after := XTianqiQiyin._rng(s2).next_float("t")
	_check("seed_disk_roundtrip", disk_ok and loaded and s2 != s and int(s2.orb_seed) == orb0 and str(q2.seed) == want
		and int(q2.rng_n) == 2 and int(q2.artifact_miss) == 217 and q2.artifacts == ["scales"] and q2.artifacts_got == ["bow_crown"]
		and before == after and not XTianqiQiyin.artifact_pool(s2).has("scales") and not XTianqiQiyin.artifact_pool(s2).has("bow_crown"),
		[disk_ok, loaded, q2.get("rng_n"), q2.get("artifact_miss"), q2.get("artifacts"), before, after])
	XSave.remove(1)
	s = s2
	# 开关关掉：每次现开，读档后不一样、计数不动
	XTianqiQiyin.SEED_FROM_SAVE = false
	s.flags.tianqi["qiyin"] = saved.duplicate(true)
	var c1 := XTianqiQiyin._rng(s).next_float("t")
	s.flags.tianqi["qiyin"] = saved.duplicate(true)
	var c2 := XTianqiQiyin._rng(s).next_float("t")
	_check("seed_off_fresh", c1 != c2 and int(XTianqiQiyin.progress(s).rng_n) == 0, [c1, c2])
	XTianqiQiyin.SEED_FROM_SAVE = true


## 白印 Boss 打赢结算一次（首通已过，先多空几次让套装件有机会掉），返回掉的东西
func _settle_items(s: XState) -> Array:
	var p := XTianqiQiyin.progress(s)
	p.drop.first_clear["bai"] = true
	p.drop.set_miss["bai"] = 13
	var got: Array = await XTianqiQiyin.settle(null, s, "bai", {}, {"shards": 0})
	return got.map(func(i): return [i.kind, i.get("part", i.get("wtype", "")), i.true_seal, i.grades])


# ---- 二、七印掉率接掉率加成 ----

func _drop_mult() -> void:
	var s := _state()
	var base := XTianqiQiyin.drop_mult(s)
	_check("drop_mult_same_curve", is_equal_approx(base, XTianqiDrop.party_mult(s)), [base, XTianqiDrop.party_mult(s)])
	# 给上场第一人 6 件「物品掉落」极品词条
	var a: XActor = XTianqiAffixBattle.members(s)[0]
	a.keep_unequippable = true
	var aff := []
	for i in 6:
		aff.append({"key": "drop_rate", "tier": 4, "grade": "perfect"})
	a.equips.append({"kind": "armor", "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3, "tianqi_affixes": aff})
	var add := XTianqiAffixBattle.party_sum(XTianqiAffixBattle.members(s), "drop_rate")
	var m := XTianqiQiyin.drop_mult(s)
	_check("drop_mult_affix_up", add > 0.0 and m > base and is_equal_approx(m, XTianqiDrop.party_mult(s)), [add, base, m])
	var total := XTianqiDrop.party_bonus(s)
	_check("drop_mult_diminish", is_equal_approx(m, 1.0 + total * 200.0 / (total + 200.0) / 100.0) and m < 3.0, [total, m])
	# 结算真用上：Boss 套装件当次几率 5%（没空过），喂 base 和 base×m 之间的值
	var p := XTianqiQiyin.progress(s)
	p.drop.first_clear["bai"] = true
	var mid := 0.05 * (1.0 + m) / 2.0
	XTianqiQiyin.rng_override = Tape.new({"qiyin_boss_set": [mid]})
	var got: Array = await XTianqiQiyin.settle(null, s, "bai", {}, {"shards": 0})
	_check("drop_mult_in_settle", got.any(func(i): return str(i.kind) == "set"), [mid, got])
	XTianqiQiyin.DROP_BONUS = false
	_check("drop_mult_off", XTianqiQiyin.drop_mult(s) == 1.0)
	XTianqiQiyin.rng_override = Tape.new({"qiyin_boss_set": [mid]})
	var got2: Array = await XTianqiQiyin.settle(null, s, "bai", {}, {"shards": 0})
	_check("drop_mult_off_settle", not got2.any(func(i): return str(i.kind) == "set"), got2)
	XTianqiQiyin.DROP_BONUS = true
	XTianqiQiyin.rng_override = null
	# 真印、神器不吃加成（roll_boss 只把 drop_mult 乘到套装件、武器）
	var r := XTianqiQiyinDrop.roll_boss(XTianqiQiyinDrop.new_state(), "bai", "jianxian", [], {}, 3.0,
		Tape.new({"qiyin_boss_set": [0.0], "qiyin_true_seal": [0.11]}), false)
	_check("drop_mult_not_true_seal", r.set_pieces.size() == 1 and not bool(r.set_pieces[0].true_seal), r.set_pieces)


# ---- 三、神器保底＋防重 ----

func _artifact_pity() -> void:
	var s := _state()
	var p := XTianqiQiyin.progress(s)
	_check("pity_after_333", XTianqiQiyin.artifact_pity_after() == 333)
	p.erase("artifact_miss")
	_check("pity_old_save_zero", int(XTianqiQiyin.progress(s).artifact_miss) == 0)
	# 331 → 332：几率 0，不到保底不出
	p.artifact_miss = 331
	var t1 := Tape.new()
	_check("pity_331_miss", XTianqiQiyin.roll_artifact(s, 0.0, t1) == "" and int(p.artifact_miss) == 332 and t1.count("qiyin_artifact") == 1, p.artifact_miss)
	# 332 → 第 333 次必出，不抽浮点数，出了清零
	var t2 := Tape.new({"qiyin_artifact_pick": [2]})
	var got := XTianqiQiyin.roll_artifact(s, 0.0, t2)
	_check("pity_333_hit", got == "scales" and int(p.artifact_miss) == 0 and t2.count("qiyin_artifact") == 0, [got, p.artifact_miss])
	# 平时照几率：中了也清零
	p.artifact_miss = 50
	_check("pity_chance_hit", XTianqiQiyin.roll_artifact(s, 0.001, Tape.new({"qiyin_artifact": [0.0009]})) != "" and int(p.artifact_miss) == 0)
	# 防重：只从没有的里出
	p.artifacts = ["bow_crown"]
	p["artifacts_got"] = ["great_sword", "grey_scythe"]
	_check("pity_pool", XTianqiQiyin.artifact_pool(s) == ["scales", "seven_seal_scroll"], XTianqiQiyin.artifact_pool(s))
	var outs := []
	for i in 2:
		outs.append(XTianqiQiyin.roll_artifact(s, 1.0, Tape.new({"qiyin_artifact_pick": [i]})))
	_check("pity_no_dup", outs == ["scales", "seven_seal_scroll"], outs)
	# 背包里的神器也算有
	p.artifacts = []
	p.artifacts_got = []
	s.gear.append(XTianqiQiyinEquip.make_artifact("scales"))
	_check("pity_pool_bag", not XTianqiQiyin.artifact_pool(s).has("scales"), XTianqiQiyin.artifact_pool(s))
	# 只剩一件：直接是它，不抽下标
	p.artifacts = ["bow_crown", "great_sword", "grey_scythe"]
	var t3 := Tape.new()
	_check("pity_last_one", XTianqiQiyin.roll_artifact(s, 1.0, t3) == "seven_seal_scroll" and t3.count("qiyin_artifact_pick") == 0)
	# 五件齐了：不掷不计
	p.artifacts.append("seven_seal_scroll")
	p.artifact_miss = 332
	var t4 := Tape.new()
	_check("pity_full_stop", XTianqiQiyin.roll_artifact(s, 1.0, t4) == "" and t4.draws == 0 and int(p.artifact_miss) == 332, [t4.draws, p.artifact_miss])
	# 里副本结算：到保底那次进印库的神器栏，计数清零
	var s2 := _state()
	var p2 := XTianqiQiyin.progress(s2)
	p2.drop.first_clear["hong"] = true
	p2.artifact_miss = 332
	XTianqiQiyin.rng_override = Tape.new()
	await XTianqiQiyin.settle(null, s2, "hong", {}, {"shards": 0})
	_check("pity_settle", p2.artifacts.size() == 1 and int(p2.artifact_miss) == 0, [p2.artifacts, p2.artifact_miss])
	XTianqiQiyin.rng_override = Tape.new()
	await XTianqiQiyin.settle(null, s2, "hong", {}, {"shards": 0})
	_check("pity_settle_count", int(p2.artifact_miss) == 1 and p2.artifacts.size() == 1, p2.artifact_miss)
	XTianqiQiyin.rng_override = null
	# 开关关掉：没有保底，可以掉已有的
	XTianqiQiyin.ARTIFACT_PITY = false
	p.artifact_miss = 332
	_check("pity_off_no_pity", XTianqiQiyin.roll_artifact(s, 0.0, Tape.new()) == "")
	_check("pity_off_dup", XTianqiQiyin.roll_artifact(s, 1.0, Tape.new({"qiyin_artifact_pick": [0]})) == "bow_crown")
	var s3 := _state()
	var p3 := XTianqiQiyin.progress(s3)
	p3.drop.first_clear["hong"] = true
	p3.artifact_miss = 332
	XTianqiQiyin.rng_override = Tape.new()
	await XTianqiQiyin.settle(null, s3, "hong", {}, {"shards": 0})
	_check("pity_off_settle", p3.artifacts.is_empty() and int(p3.artifact_miss) == 332, [p3.artifacts, p3.artifact_miss])
	XTianqiQiyin.rng_override = null
	XTianqiQiyin.ARTIFACT_PITY = true


## 七首之龙和里副本共用计数
func _artifact_dragon() -> void:
	var s := _state()
	var p := XTianqiQiyin.progress(s)
	p.artifact_miss = 332
	XTianqiQiyinDragonRun.state(s)["rift"] = "fighting"
	var chance0 = XTianqiQiyinDragon.data().reward.artifact_chance
	XTianqiQiyinDragon.data().reward.artifact_chance = 0.0
	var h := FakeHost.new()
	h.answers = [0, 1]
	await XTianqiQiyinDragonRun.settle(h, s, Tape.new())
	_check("pity_dragon_shared", p.artifacts.size() == 1 and int(p.artifact_miss) == 0 and _has(h, "神器"), [p.artifacts, p.artifact_miss])
	XTianqiQiyinDragonRun.state(s)["rift"] = "fighting"
	var h2 := FakeHost.new()
	h2.answers = [0, 1]
	await XTianqiQiyinDragonRun.settle(h2, s, Tape.new())
	_check("pity_dragon_count", int(p.artifact_miss) == 1 and p.artifacts.size() == 1, p.artifact_miss)
	# 纯函数：with_artifact false 时龙的奖励不掷神器
	var tp := Tape.new({}, 0.0)
	var r := XTianqiQiyinDragon.reward(XTianqiQiyinDragon.enter_rift(XTianqiQiyinDragon.store_rift(XTianqiQiyinDragon.new_state()).state).state, "bai", tp, false)
	_check("pity_dragon_pure_skip", tp.count("qiyin_dragon.artifact") == 0 and r.get("artifact") == null, r)
	XTianqiQiyinDragon.data().reward.artifact_chance = chance0


# ---- 四、七印书卷 ----

## 一场书卷战：owner 是佩戴者（下标），规则 key
func _scroll_fight(s: XState, key: String, troop: int, owner := 0) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	var st := XTianqiQiyinEffects._store(lg)
	st.scroll_rule = key
	st.artifact_owner = lg.actors[owner] if owner >= 0 else null
	return lg


func _scroll_cost() -> void:
	var s := _state()
	var sk := {"id": 99999, "occasion": 0}
	# 星坠：佩戴者也掉 33%，别的队友不掉
	var sf := _scroll_fight(s, "zhen", 187)
	var logs := XTianqiQiyinRule.take_logs(sf)
	var o: XActor = sf.actors[0]
	var mate: XActor = sf.actors[1]
	_check("cost_announced", logs.any(func(l): return str(l.get("text", "")).contains("对敌方和" + o.display_name())), logs)
	sf.start_turn()
	sf.start_turn()
	var ohp := o.hp
	var mhp := mate.hp
	sf.start_turn()
	_check("cost_star", is_equal_approx(o.hp, maxf(1.0, ohp - floorf(ohp * 0.33))) and mate.hp == mhp, [ohp, o.hp, mhp, mate.hp])
	sf.end_battle(0)
	# 寂静：双数回合佩戴者只能普攻、防御、用物品；队友照常
	var si := _scroll_fight(s, "mo", 216)
	si.start_turn()
	si.start_turn()
	_check("cost_silence", not XTianqiQiyinRule.can_use(si, si.actors[0], sk) and XTianqiQiyinRule.can_use(si, si.actors[1], sk)
		and XTianqiQiyinRule.can_use(si, si.actors[0], si.actors[0].attack_skill()))
	si.end_battle(0)
	# 魔塔：佩戴者不能暴击
	var mt := _scroll_fight(s, "hui", 291)
	mt.start_turn()
	_check("cost_tower", XTianqiQiyinRule.no_crit(mt, mt.actors[0]) and not XTianqiQiyinRule.no_crit(mt, mt.actors[1]))
	mt.end_battle(0)
	# 杀声：打在佩戴者身上的也加
	var wc := _scroll_fight(s, "hong", 33)
	wc.start_turn()
	wc._die(wc.enemies[1])
	_check("cost_war_cry", is_equal_approx(XTianqiQiyinRule.hp_damage(wc, wc.enemies[0], wc.actors[0], 1000.0), 1050.0)
		and is_equal_approx(XTianqiQiyinRule.hp_damage(wc, wc.enemies[0], wc.actors[1], 1000.0), 1000.0))
	wc.end_battle(0)
	# 限时：佩戴者自己 5 个技能、不回魔法 TP；敌方合计另算；队友不限
	var ex := _scroll_fight(s, "hei", 10)
	ex.start_turn()
	for i in 5:
		XTianqiQiyinRule.on_act(ex, ex.actors[0], sk)
	_check("cost_exam_owner", not XTianqiQiyinRule.can_use(ex, ex.actors[0], sk) and XTianqiQiyinRule.can_use(ex, ex.enemies[0], sk)
		and XTianqiQiyinRule.can_use(ex, ex.actors[1], sk))
	_check("cost_exam_regen", XTianqiQiyinRule.no_regen(ex, ex.actors[0]) and not XTianqiQiyinRule.no_regen(ex, ex.actors[1]))
	ex.start_turn()
	_check("cost_exam_reset", XTianqiQiyinRule.can_use(ex, ex.actors[0], sk))
	ex.end_battle(0)
	# 不愈：佩戴者身上的减益不到期
	var nc := _scroll_fight(s, "bai", 33)
	nc.start_turn()
	var bad := -1
	for id in range(1, 200):
		if not XDB.rec("States", id).is_empty() and XTianqiQiyinRule.debuff_state(id):
			bad = id
			break
	_check("cost_no_cure", XTianqiQiyinRule.keeps_state(nc, bad, nc.actors[0]) and not XTianqiQiyinRule.keeps_state(nc, bad, nc.actors[1])
		and XTianqiQiyinRule.keeps_debuff(nc, -1, nc.actors[0]) and not XTianqiQiyinRule.keeps_debuff(nc, -1, nc.actors[1]))
	nc.end_battle(0)
	# 献祭：敌方最高那只照扣，佩戴者自己也扣 10%（不加伤），队友不扣
	var sc := _scroll_fight(s, "xun", 122)
	var top = null
	for b in sc.enemies:
		if b.is_alive() and (top == null or b.hp > top.hp):
			top = b
	var e0: float = top.hp
	var so: XActor = sc.actors[0]
	var o0 := so.hp
	var m0: float = sc.actors[1].hp
	sc.start_turn()
	_check("cost_sacrifice", is_equal_approx(top.hp, e0 - floorf(e0 * 0.1)) and is_equal_approx(so.hp, maxf(1.0, o0 - floorf(o0 * 0.1)))
		and sc.actors[1].hp == m0 and is_equal_approx(XTianqiQiyinRule.hp_damage(sc, so, sc.enemies[0], 1000.0), 1000.0), [e0, top.hp, o0, so.hp])
	sc.end_battle(0)
	# 文案：代价写成真实的
	var art := XTianqiQiyinGear.artifact("seven_seal_scroll")
	_check("cost_text", art.costs.size() == 1 and str(art.costs[0].code) == "reveal_self" and str(art.costs[0].text).contains("佩戴者自己也受")
		and XTianqiQiyinGear.effect_codes().has("reveal_self") and not XTianqiQiyinGear.effect_codes().has("reveal_luck"), art.costs)
	# 代价开关关掉：回到只对敌方
	XTianqiQiyinRule.SCROLL_COST = false
	var off := _scroll_fight(s, "zhen", 187)
	off.start_turn()
	off.start_turn()
	var f0: float = off.actors[0].hp
	off.start_turn()
	_check("cost_off", off.actors[0].hp == f0 and not XTianqiQiyinRule.no_crit(off, off.actors[0]))
	off.end_battle(0)
	XTianqiQiyinRule.SCROLL_COST = true


## 代价跟着佩戴者走（gpt 核查 P2）：换到助力位照付、阵亡后停；每段用新存档（换人、阵亡会改出战栏）
func _scroll_cost_bench() -> void:
	# 代价跟着佩戴者走：第 3 回合前被换到助力位，星坠照扣（敌方照挨）；献祭同
	var s := _state()
	var sw := _scroll_fight(s, "zhen", 187)
	var wo: XActor = sw.actors[0]
	sw.start_turn()
	sw.start_turn()
	var h0 := s.helper()
	var swapped = sw.tianqi_swap(wo)
	var w0 := wo.hp
	var we0: float = sw.enemies[0].hp
	sw.start_turn()
	_check("cost_star_bench", swapped != null and not sw.actors.has(wo) and is_equal_approx(wo.hp, maxf(1.0, w0 - floorf(w0 * 0.33)))
		and sw.enemies[0].hp < we0, [h0 != null, swapped != null, w0, wo.hp])
	sw.end_battle(0)
	s = _state()
	var sb := _scroll_fight(s, "xun", 122)
	var bo: XActor = sb.actors[0]
	sb.tianqi_swap(bo)
	var b0 := bo.hp
	sb.start_turn()
	_check("cost_sacrifice_bench", not sb.actors.has(bo) and is_equal_approx(bo.hp, maxf(1.0, b0 - floorf(b0 * 0.1))), [b0, bo.hp])
	sb.end_battle(0)
	# 佩戴者阵亡：代价停，敌方照挨星坠
	s = _state()
	var sd := _scroll_fight(s, "zhen", 187)
	var dd: XActor = sd.actors[0]
	sd.start_turn()
	sd.start_turn()
	dd.hp = 0.0
	sd._die(dd)
	var dh := dd.hp
	var de0: float = sd.enemies[0].hp
	sd.start_turn()
	_check("cost_dead_stops", dd.is_dead() and dd.hp == dh and sd.enemies[0].hp < de0, [dh, dd.hp, de0, sd.enemies[0].hp])
	sd.end_battle(0)


## 第一个人戴上七印书卷（直接塞实例，同 xiyou_tianqi_qiyin_effects 的 _wear）
func _wear_scroll(s: XState) -> XActor:
	var a: XActor = s.actor(int(s.battle_slots[0]))
	a.keep_unequippable = true
	a.equips.append(XTianqiQiyinEquip.make_artifact("seven_seal_scroll"))
	a.param_mark_dirty()
	a.param_refresh()
	return a


func _scroll_exempt() -> void:
	var s := _state()
	var a := _wear_scroll(s)
	_check("exempt_wearing", XTianqiQiyinEffects.artifact_key(a) == "seven_seal_scroll")
	# 普通战斗照揭
	var n := XBattleLogic.new()
	n.setup(33, s)
	XTianqiQiyinRule.take_logs(n)
	_check("exempt_plain_reveals", XTianqiQiyinEffects.enemy_only_rule(n) != "" and XTianqiQiyinRule.rule_of(n) != "", XTianqiQiyinEffects.enemy_only_rule(n))
	n.end_battle(0)
	# 骑士本体战：不揭，说一句
	var ok_prep := XTianqiHorsemen.prepare("war", s, "body")
	var k := XBattleLogic.new()
	k.setup(int(XTianqiSummit.data().shell_troop), s)
	var logs: Array = k.turn_start_logs + XTianqiQiyinRule.take_logs(k)  # 开场 setup 里已经取进 turn_start_logs
	_check("exempt_knight", ok_prep and XTianqiHorsemen.active(k) and XTianqiQiyinEffects.enemy_only_rule(k) == ""
		and XTianqiQiyinRule.rule_of(k) == "" and logs.any(func(l): return str(l.get("text", "")).contains("沉寂")), [ok_prep, logs])
	k.start_turn()
	k.start_turn()
	k.start_turn()
	_check("exempt_knight_no_effect", XTianqiQiyinRule.scroll_owner(k) == null and not XTianqiQiyinRule.no_crit(k, k.enemies[0])
		and not XTianqiQiyinRule.no_crit(k, a))
	k.end_battle(1)
	# 34 层鸿钧
	var ok_h := XTianqiSummit.prepare_hongjun(s)
	var hj := XBattleLogic.new()
	hj.setup(int(XTianqiSummit.data().hongjun.troop), s)
	XTianqiQiyinRule.take_logs(hj)
	_check("exempt_hongjun", ok_h and XTianqiQiyinEffects.scroll_exempted(hj) and XTianqiQiyinEffects.enemy_only_rule(hj) == "")
	hj.end_battle(1)
	# 豁免开关关掉：骑士战照揭
	XTianqiQiyinRule.SCROLL_BOSS_EXEMPT = false
	XTianqiHorsemen.prepare("war", s, "body")
	var k2 := XBattleLogic.new()
	k2.setup(int(XTianqiSummit.data().shell_troop), s)
	XTianqiQiyinRule.take_logs(k2)
	_check("exempt_off", XTianqiQiyinEffects.enemy_only_rule(k2) != "" and not XTianqiQiyinEffects.scroll_exempted(k2))
	k2.end_battle(1)
	XTianqiQiyinRule.SCROLL_BOSS_EXEMPT = true


# ---- 五、默印 5 件「万籁俱寂」 ----

func _wear_mo(a: XActor, n: int) -> void:
	a.keep_unequippable = true
	var parts := ["head", "body", "hands", "waist", "legs", "feet"]
	for i in n:
		var inst := XGear.create("armor", ARMOR_ID, XState.current)
		if inst.is_empty():
			inst = {"kind": "armor", "name": "测试", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3}
		XTianqiQiyinEffects.mark(inst, {"kind": "set", "seal": "mo", "part": parts[i], "true_seal": false})
		a.equips.append(inst)
	a.param_mark_dirty()
	a.param_refresh()


func _silence_skill() -> void:
	var id := int(XTianqiQiyinEffects.TUNE.silence_skill_id)
	var rec := XDB.rec("Skills", id)
	_check("silence_id", id == 10777 and str(rec.get("name", "")) == "万籁俱寂" and int(rec.get("scope", 0)) == 2
		and int(rec.get("damage", {}).get("type", -1)) == 0, rec.get("name", ""))
	var s := _state()
	var lg := XBattleLogic.new()
	lg.setup(33, s)
	var a: XActor = lg.actors[0]
	var b: XActor = lg.actors[1]
	_wear_mo(a, 5)
	_wear_mo(b, 3)
	XTianqiQiyinEffects.start(lg)
	var has_a := lg.battle_skills(a).any(func(x): return int(x.id) == id)
	var has_b := lg.battle_skills(b).any(func(x): return int(x.id) == id)
	_check("silence_listed_5", has_a and not has_b, [has_a, has_b])
	_check("silence_usable", lg.can_use(a, rec) and not lg.can_use(b, rec))
	XTianqiQiyinEffects.begin_action(lg, a, rec)
	var en: XEnemy = lg.enemies[0]
	var logs := XTianqiQiyinEffects.end_action(lg, a, rec)
	_check("silence_cast", XTianqiQiyinEffects.silenced(lg, en) and logs.any(func(l): return str(l.get("text", "")).contains("万籁俱寂")), logs)
	_check("silence_once_per_battle", not lg.can_use(a, rec))
	_check("silence_free_skill", is_equal_approx(XTianqiQiyinEffects.cost_mult(b, {"id": 1}), 0.0) or int(XTianqiQiyinEffects._unit(lg, b).free_skill) > 0)
	lg.end_battle(0)
	# 开关关掉：不进列表
	XTianqiQiyinEffects.SILENCE_SKILL = false
	var lg2 := XBattleLogic.new()
	lg2.setup(33, s)
	XTianqiQiyinEffects.start(lg2)
	_check("silence_off", not lg2.battle_skills(lg2.actors[0]).any(func(x): return int(x.id) == id))
	lg2.end_battle(0)
	XTianqiQiyinEffects.SILENCE_SKILL = true
