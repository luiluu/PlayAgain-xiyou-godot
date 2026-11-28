extends Node
## T586 西游档徐凤年（152）剑一·龙蛇、剑二·并蒂莲、剑三·三斤、剑九·六千里主动战技专项（XXufeng.JIAN9，Kyo 11-27 事项 95）：
## 1) 数据：四招西游副本是战技（stypeId 1、战斗中用）、段数／对象／冷却／消耗对；剑一～剑三原被动加成标签照留并真生效；
##    9995 去掉 1704／Hide in Battle／2538；卡面不写内部系数、不写存档模式名；共享原表不被改；
## 2) 战斗：剑九第 1 回合不能用、第 2 回合能用；放出九段有伤害；放完本回合不能再行动（收剑 19502），
##    下一回合能行动但全属性 −50%（力竭 19503），再下一回合恢复；冷却 2；剑一命中回 TP；剑三能眩晕；
## 3) 老档：存档读回后四招可用（不改存档结构）；
## 4) 天启篇零改动：开关开／关天启篇 9987～9996 记录逐项相等，19502／19503 读不到；
## 5) 开关 JIAN9 = false 回 T585 口径；
## 6) 量数附报（不判线，判线在 xiyou_xufeng_rework 的 D272 五种子均值）：3 种子中位比、10 回合冷却 2／3、
##    剑九一击（暴击／不暴击）对狂刀最强单招、三敌木桩、TP 不补满。
var passed := 0
var total := 0
const CARD_BANNED := ["西游档", "天启", "启封", "a.atk", "skillMasteryLevel", "361000", "69000", "184000", "368000"]


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var was_rel := XImportedBalance.RELEASE_XUFENG
	var was_xf := XXufeng.REWORK
	var was_fix := XXufeng.LOCK_FIX
	var was_j9 := XXufeng.JIAN9
	var was_p4 := XTianqiBase.PHASE4
	XMessageBox.auto = true
	XImportedBalance.RELEASE_XUFENG = true
	XXufeng.REWORK = true
	XXufeng.LOCK_FIX = true
	XXufeng.JIAN9 = true
	XXufeng.clear_cache()
	_check_data_on()
	_check_battle_flow()
	_check_lijie_fullset()
	_check_jian9_two_enemies()
	_check_sword1_sword3()
	_check_old_save()
	_check_off()
	_check_tianqi_untouched()
	if OS.get_environment("T586_BENCH") != "0":
		_bench_report()

	XImportedBalance.RELEASE_XUFENG = was_rel
	XXufeng.REWORK = was_xf
	XXufeng.LOCK_FIX = was_fix
	XXufeng.JIAN9 = was_j9
	XXufeng.clear_cache()
	XTianqiBase.PHASE4 = was_p4
	XTianqiSkills.reload_table()
	XStateEffects.force_critical = false
	XState.current = null
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _make_xiyou_state(lv: int) -> XState:
	var s := XState.new_game_blank()
	s.random_master = XRandomStream.hex64(20261127)
	s.set_switch(2494, true)
	s.set_variable(20, 30)
	XState.current = s
	s.add_actor(152)
	for i in 5:
		s.set_battle_slot(i, 152 if i == 0 else 0)
	var a: XActor = s.actor(152)
	a.change_level(lv)
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	return s


func _equip_in_slot(a: XActor, item: Dictionary) -> void:
	for i in a.equip_slots().size():
		if int(a.equip_slots()[i]) == int(item.etypeId):
			a.equips[i] = item
			return


func _card(sk: Dictionary) -> String:
	return "\n".join(PackedStringArray(XHelpCard.content(sk, "skill").map(func(r): return XHelpCard.plain(str(r[0])).replace("\\lock[1]", ""))))


func _has_effect(sk: Dictionary, code: int, data_id: int) -> bool:
	for e in sk.get("effects", []):
		if int(e.get("code", 0)) == code and int(e.get("dataId", 0)) == data_id:
			return true
	return false


func _card_clean(tag: String, card: String) -> void:
	var bad := []
	for w in CARD_BANNED:
		if card.contains(w):
			bad.append(w)
	check(tag, bad.is_empty() and card.length() > 0, [bad, card])


func _check_data_on() -> void:
	var s := _make_xiyou_state(80)
	var a: XActor = s.actor(152)
	var raw9995: Dictionary = XDB.table("Skills")[9995]
	var raw9987: Dictionary = XDB.table("Skills")[9987]
	var want := {
		9987: [6, 0, 0, 0, 5, 1],
		9988: [2, 2, 0, 20, 0, 2],
		9989: [1, 3, 0, 30, 0, 1],
	}  # scope, cooldown, mp, tp, tpGain, yepEffects
	for sid in want:
		var w: Array = want[sid]
		var sk := XDB.rec("Skills", sid)
		var cfg: Array = XXufeng.SWORDS[sid]
		var card := _card(sk)
		var cd_ok: bool = (int(w[1]) == 0 and not sk.meta.has("Cooldown")) or str(sk.meta.get("Cooldown", "")).strip_edges() == str(w[1])
		check("on.active.%d" % sid, int(sk.stypeId) == 1 and int(sk.occasion) == 1 and int(sk.scope) == int(w[0]) and cd_ok
			and int(sk.mpCost) == int(w[2]) and int(sk.tpCost) == int(w[3]) and int(sk.tpGain) == int(w[4]) and int(sk.yepEffects) == int(w[5])
			and sk.yepSeq is Dictionary and str(sk.damage.formulaGd).contains("a.atk*%d" % XXufeng.sword_atk_mul(sid)),
			[sk.stypeId, sk.occasion, sk.scope, sk.meta.get("Cooldown"), sk.mpCost, sk.tpCost, sk.tpGain, sk.yepEffects, sk.damage.formulaGd])
		check("on.active.%d.passive_kept" % sid, str(sk.meta.get("passiveELUP01", "")) == "%d%%" % cfg[0]
			and str(sk.meta.get("DepassiveHarmRe01", "")).strip_edges() == "%d%%" % cfg[1]
			and card.contains("物理/寒冰伤害+%d%% 无视敌人物理/寒冰抗性+%d%%" % [cfg[0], cfg[1]]), card)
		_card_clean("on.active.%d.card" % sid, card)
		check("on.active.%d.in_battle_list" % sid, XBattleLogic.new().battle_skills(a).any(func(x): return int(x.id) == sid))
	check("on.9989.stun", _has_effect(XDB.rec("Skills", 9989), 21, 29))
	# 被动加成真生效：剑一～剑八八招物理伤合计
	var sum_el := 0.0
	for v in a.passive_values("passiveELUP01"):
		sum_el += float(v)
	var exp_sum := 0
	for sid in XXufeng.SWORDS:
		exp_sum += int(XXufeng.SWORDS[sid][0])
	check("on.passive_sum", sum_el > 0.0, [sum_el, exp_sum])
	var s9 := XDB.rec("Skills", 9995)
	var c9 := _card(s9)
	check("on.9995.data", int(s9.stypeId) == 1 and int(s9.occasion) == 1 and int(s9.scope) == 1 and int(s9.tpCost) == XXufeng.JIAN9_TP
		and int(s9.yepEffects) == XXufeng.JIAN9_HITS and not _has_effect(s9, 44, 1704) and not s9.meta.has("Hide in Battle")
		and not s9.meta.has("StartPushState2538") and str(s9.meta.get("Warmup", "")).strip_edges() == str(XXufeng.JIAN9_WARMUP)
		and str(s9.meta.get("Cooldown", "")).strip_edges() == str(XXufeng.JIAN9_COOLDOWN),
		[s9.stypeId, s9.occasion, s9.effects, s9.meta.keys()])
	check("on.9995.card", c9.contains("剑九") or c9.contains("九段剑气"), c9)
	check("on.9995.card_cost", c9.contains("力竭") and c9.contains("全属性降低50%") and c9.contains("冷却2回合") and c9.contains("第2回合"), c9)
	_card_clean("on.9995.card_clean", c9)
	print("CARD 9995 ", JSON.stringify(c9))
	for sid in [9987, 9988, 9989]:
		print("CARD %d " % sid, JSON.stringify(_card(XDB.rec("Skills", sid))))
	var st2 := XDB.rec("States", XXufeng.ST_SHOUJIAN)
	var st3 := XDB.rec("States", XXufeng.ST_LIJIE)
	check("on.states", str(st2.get("name", "")) == "收剑" and int(st2.restriction) == 4 and int(st2.maxTurns) == 1
		and str(st3.get("name", "")) == "力竭" and int(st3.restriction) == 0 and int(st3.maxTurns) == 2 and st3.traits.is_empty(),
		[st2.get("name"), st3.get("name")])
	check("on.table_pure", int(raw9995.occasion) == 2 and _has_effect(raw9995, 44, 1704) and int(raw9987.stypeId) == 4 and int(raw9987.occasion) == 1,
		[raw9995.occasion, raw9987.stypeId])


func _check_battle_flow() -> void:
	var s := _make_xiyou_state(80)
	var a: XActor = s.actor(152)
	var sk9 := XDB.rec("Skills", 9995)
	var logic := XBattleLogic.new()
	logic.setup(70, s, XBattleRandom.create(str(s.random_master)))
	var foe: XEnemy = logic.enemies[0]
	foe.param_refresh()
	foe.recover_all()
	a.tp = 100.0
	logic.start_turn()
	check("flow.t1.cannot", not logic.can_use(a, sk9), a.warmups)
	logic.end_turn()
	logic.start_turn()
	a.tp = 100.0
	check("flow.t2.can", logic.can_use(a, sk9), [a.warmups, a.cooldowns])
	var atk0 := a.atk
	var p0 := _params8(a)
	var hits := 0
	var dmg := 0.0
	for e in logic.act(a, sk9, foe):
		if e is Dictionary and str(e.get("type", "")) == "hit" and is_same(e.get("target"), foe):
			hits += 1
			dmg += maxf(0.0, float(e.get("hp", 0.0)))
	foe.hp = foe.mhp
	check("flow.t2.nine_hits", hits == 9 and dmg > 0.0, [hits, dmg])
	check("flow.t2.tp_paid", is_equal_approx(a.tp, 100.0 - XXufeng.JIAN9_TP) or a.tp < 100.0, a.tp)
	check("flow.t2.shoujian", a.is_state_affected(XXufeng.ST_SHOUJIAN) and not logic.can_move(a), a.state_ids)
	# P2-1：卡面写「下一回合力竭」→ 施放当回合八项属性不变
	a.param_mark_dirty()
	check("flow.t2.params_unchanged", a.is_state_affected(XXufeng.ST_LIJIE) and _params8(a) == p0, [p0, _params8(a)])
	logic.end_turn()
	logic.start_turn()
	a.tp = 100.0
	check("flow.t3.lijie", logic.can_move(a) and not a.is_state_affected(XXufeng.ST_SHOUJIAN) and a.is_state_affected(XXufeng.ST_LIJIE), a.state_ids)
	check("flow.t3.atk_half", a.atk < atk0 * 0.6 and a.atk > atk0 * 0.4, [atk0, a.atk])
	var p3 := _params8(a)
	var halved := true
	for i in 8:
		if not (float(p3[i]) < float(p0[i]) * 0.6 and float(p3[i]) > float(p0[i]) * 0.4):
			halved = false
	check("flow.t3.params_half", halved, [p0, p3])
	check("flow.t3.cooldown", not logic.can_use(a, sk9), a.cooldowns)
	logic.end_turn()
	logic.start_turn()
	a.tp = 100.0
	check("flow.t4.recovered", not a.is_state_affected(XXufeng.ST_LIJIE) and is_equal_approx(a.atk, atk0), [a.state_ids, atk0, a.atk])
	check("flow.t4.can_again", logic.can_use(a, sk9), a.cooldowns)
	logic.act(a, sk9, foe)
	logic.end_battle(0)
	check("flow.after_battle_clean", not a.is_state_affected(XXufeng.ST_SHOUJIAN) and not a.is_state_affected(XXufeng.ST_LIJIE)
		and a.cooldown_left(9995) == 0, [a.state_ids, a.cooldowns])


## T586 R2（小o P2-1）：80 级全套（装备有 +100% 最大魔法等比率）力竭也是八项实际属性减半；状态详情施放当回合不列力竭，下一回合列「力竭·1回合」
func _check_lijie_fullset() -> void:
	var s := _setup_actor(152, TIERS[3], 1)
	var a: XActor = s.actor(152)
	var sk9 := XDB.rec("Skills", 9995)
	var logic := XBattleLogic.new()
	logic.setup(70, s, XBattleRandom.create(str(s.random_master)))
	var foe: XEnemy = logic.enemies[0]
	foe.param_refresh()
	foe.recover_all()
	logic.start_turn()
	logic.end_turn()
	logic.start_turn()
	a.tp = 100.0
	a.param_mark_dirty()
	var p0 := _params8(a)
	check("full.rate_stacked", a.param_rate(1) > 1.5, a.param_rate(1))  # 夹具确有装备比率，加算会把 −50% 稀释
	logic.act(a, sk9, foe)
	foe.hp = foe.mhp
	a.param_mark_dirty()
	check("full.t2.params_unchanged", a.is_state_affected(XXufeng.ST_LIJIE) and _params8(a) == p0, [p0, _params8(a)])
	var rows2 := XPartyStatusPanel.rows_for(a)
	var ids2 := rows2.map(func(r): return int(r.id))
	var sj := rows2.filter(func(r): return int(r.id) == XXufeng.ST_SHOUJIAN)
	check("full.t2.panel", not ids2.has(XXufeng.ST_LIJIE) and sj.size() == 1 and str(sj[0].description).contains("下一回合力竭"), rows2)
	logic.end_turn()
	logic.start_turn()
	a.param_mark_dirty()
	var p3 := _params8(a)
	var exact := true
	for i in 8:
		if absf(float(p3[i]) - roundf(float(p0[i]) * XXufeng.LIJIE_PARAM_PCT / 100.0)) > 1.0:
			exact = false
	check("full.t3.params_exact_half", exact, [p0, p3])
	var lj := XPartyStatusPanel.rows_for(a).filter(func(r): return int(r.id) == XXufeng.ST_LIJIE)
	check("full.t3.panel", lj.size() == 1 and str(lj[0].duration) == "1回合" and str(lj[0].description).contains("全属性-50%"), lj)
	print("LIJIE_FULL ", JSON.stringify({"p0": p0, "p3": p3}))
	logic.end_turn()
	logic.start_turn()
	a.param_mark_dirty()
	check("full.t4.recovered", not a.is_state_affected(XXufeng.ST_LIJIE) and _params8(a) == p0, [p0, _params8(a)])
	logic.end_battle(0)
	# 回退开关：LIJIE_MUL=false 回到 R1（力竭挂八项 −50% 比率特性、收剑 +50% 抵消、状态栏不藏）
	XXufeng.LIJIE_MUL = false
	XXufeng.clear_cache()
	var off3 := XDB.rec("States", XXufeng.ST_LIJIE)
	var off2 := XDB.rec("States", XXufeng.ST_SHOUJIAN)
	check("full.switch_off", off3.traits.size() == 8 and (off2.traits as Array).filter(func(t): return int(t.code) == 21).size() == 8
		and not XXufeng.lijie_active(a) and not XXufeng.lijie_hidden(a, XXufeng.ST_LIJIE), [off3.traits.size(), off2.traits.size()])
	XXufeng.LIJIE_MUL = true
	XXufeng.clear_cache()


func _params8(a: XActor) -> Array:
	var out := []
	for i in 8:
		out.append(a.param(i))
	return out


## P1-1：两个敌人时剑九只打所选的那个（选中 9 段、未选中 0 段、未选中不掉血）
func _check_jian9_two_enemies() -> void:
	var s := _make_xiyou_state(80)
	var a: XActor = s.actor(152)
	var sk9 := XDB.rec("Skills", 9995)
	var troops: Array = XDB.table("Troops")
	var members_bak: Array = troops[70].members
	var m2 := []
	for i in 2:
		var m: Dictionary = members_bak[0].duplicate(true)
		m.x = int(m.get("x", 400)) + i * 60
		m2.append(m)
	troops[70].members = m2
	var logic := XBattleLogic.new()
	logic.setup(70, s, XBattleRandom.create(str(s.random_master)))
	troops[70].members = members_bak
	check("two.setup", logic.enemies.size() == 2, logic.enemies.size())
	if logic.enemies.size() != 2:
		return
	for foe in logic.enemies:
		foe.param_refresh()
		foe.recover_all()
	var picked: XEnemy = logic.enemies[1]
	var other: XEnemy = logic.enemies[0]
	logic.start_turn()
	logic.end_turn()
	logic.start_turn()
	a.tp = 100.0
	var hp_other := other.hp
	var n_picked := 0
	var n_other := 0
	for e in logic.act(a, sk9, picked):
		if e is Dictionary and str(e.get("type", "")) == "hit":
			if is_same(e.get("target"), picked):
				n_picked += 1
			elif is_same(e.get("target"), other):
				n_other += 1
	print("TWO_ENEMIES jian9 picked=%d other=%d" % [n_picked, n_other])
	check("two.jian9_9_0", n_picked == 9 and n_other == 0 and other.hp == hp_other, [n_picked, n_other, hp_other, other.hp])
	logic.end_battle(0)


func _check_sword1_sword3() -> void:
	var s := _make_xiyou_state(80)
	var a: XActor = s.actor(152)
	var logic := XBattleLogic.new()
	logic.setup(70, s, XBattleRandom.create(str(s.random_master)))
	var foe: XEnemy = logic.enemies[0]
	foe.param_refresh()
	foe.recover_all()
	logic.start_turn()
	a.tp = 0.0
	a.mp = a.mmp
	var hits := 0
	for e in logic.act(a, XDB.rec("Skills", 9987), foe):
		if e is Dictionary and str(e.get("type", "")) == "hit":
			hits += 1
	check("s1.hits_and_tp", hits == 4 and a.tp >= 4.0 * 5.0 * 0.99, [hits, a.tp])
	foe.hp = foe.mhp
	a.tp = 100.0
	var dmg := 0.0
	for e in logic.act(a, XDB.rec("Skills", 9988), foe):
		if e is Dictionary and str(e.get("type", "")) == "hit":
			dmg += maxf(0.0, float(e.get("hp", 0.0)))
	check("s2.damage", dmg > 0.0, dmg)
	check("s2.cooldown", a.cooldown_left(9988) == 2, a.cooldowns)
	foe.hp = foe.mhp
	logic.act(a, XDB.rec("Skills", 9989), foe)
	check("s3.cooldown", a.cooldown_left(9989) == 3, a.cooldowns)
	logic.end_battle(0)


func _check_old_save() -> void:
	XXufeng.JIAN9 = false
	XXufeng.clear_cache()
	var s0 := _make_xiyou_state(80)
	var data: Dictionary = XSaveSlim.as_reloaded(s0.to_dict())
	XXufeng.JIAN9 = true
	XXufeng.clear_cache()
	XState.current = null
	var s := XState.from_dict(data)
	XState.current = s
	var a: XActor = s.actor(152)
	a.param_mark_dirty()
	var ids: Array = XBattleLogic.new().battle_skills(a).map(func(x): return int(x.id))
	check("old_save.skills", a.skill_ids.has(9995) and ids.has(9995) and ids.has(9987) and ids.has(9988) and ids.has(9989) and ids.has(9998), ids)
	var logic := XBattleLogic.new()
	logic.setup(70, s, XBattleRandom.create(str(s.random_master)))
	logic.start_turn()
	logic.end_turn()
	logic.start_turn()
	a.tp = 100.0
	var dmg := 0.0
	for e in logic.act(a, XDB.rec("Skills", 9995), logic.enemies[0]):
		if e is Dictionary and str(e.get("type", "")) == "hit":
			dmg += maxf(0.0, float(e.get("hp", 0.0)))
	check("old_save.jian9_fires", dmg > 0.0, dmg)
	logic.end_battle(0)


func _check_off() -> void:
	XXufeng.JIAN9 = false
	XXufeng.clear_cache()
	_make_xiyou_state(80)
	var s9 := XDB.rec("Skills", 9995)
	var s1 := XDB.rec("Skills", 9987)
	check("off.9995", int(s9.stypeId) == 4 and int(s9.occasion) == 2 and _has_effect(s9, 44, 1704), [s9.stypeId, s9.occasion])
	check("off.9987", int(s1.stypeId) == 4 and int(s1.occasion) == 3, [s1.stypeId, s1.occasion])
	check("off.states", XDB.rec("States", XXufeng.ST_SHOUJIAN).is_empty() and XDB.rec("States", XXufeng.ST_LIJIE).is_empty())
	XXufeng.JIAN9 = true
	XXufeng.clear_cache()


func _tq_recs() -> Array:
	var out := []
	for sid in range(9987, 9997):
		out.append(JSON.stringify(XDB.rec("Skills", sid)))
	return out


func _check_tianqi_untouched() -> void:
	XTianqiBase.PHASE4 = true
	XTianqiSkills.reload_table()
	var s := XState.new_game(XTianqi.legacy_of("zhengdao"), 152, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "zhengdao", "lineup": [152]}
	XState.current = s
	XXufeng.JIAN9 = true
	XXufeng.clear_cache()
	var on := _tq_recs()
	check("tq.states_unreadable", XDB.rec("States", XXufeng.ST_SHOUJIAN).is_empty() and XDB.rec("States", XXufeng.ST_LIJIE).is_empty())
	XXufeng.JIAN9 = false
	XXufeng.clear_cache()
	var off := _tq_recs()
	var diff := []
	for i in on.size():
		if on[i] != off[i]:
			diff.append(9987 + i)
	check("tq.records_equal", diff.is_empty(), diff)
	XXufeng.JIAN9 = true
	XXufeng.clear_cache()
	XState.current = null


# ---- 量数附报（同 D272 木桩：Troop 70、熟练 32、全暴击、每次行动补满 MP/TP、狂刀固定优先序、徐凤年 XSmartAI 选招）----

const TIERS := [
	["lv50", 50, 99, 0, 0, 0],
	["lv70_main", 70, 99, 0, 0, 0],
	["lv75_fullset", 75, 99, 2019, 76, 129],
	["lv80_fullset", 80, 99, 2019, 76, 129],
]


func _bench_report() -> void:
	XStateEffects.force_critical = true
	# 1) 5 回合，种子 1～5：逐种子、均值比（D272 判法）、前 3 种子中位比（卡上附报）；徐凤年选招次数
	for row in TIERS:
		var kd := []
		var xf := []
		var picks := {}
		for sd in [1, 2, 3, 4, 5]:
			kd.append(_bench(122, row, sd, 5, true, 1).total)
			var r := _bench(152, row, sd, 5, true, 1)
			xf.append(r.total)
			for k in r.picks:
				picks[k] = int(picks.get(k, 0)) + int(r.picks[k])
		var ratios := []
		for i in 5:
			ratios.append(snappedf(float(xf[i]) / maxf(1e-9, float(kd[i])), 0.001))
		var r3: Array = ratios.slice(0, 3)
		r3.sort()
		print("BENCH5 ", row[0], " ", JSON.stringify({
			"mean_ratio": snappedf(_mean(xf) / maxf(1e-9, _mean(kd)), 0.0001), "median3": r3[1],
			"kd": kd.map(func(v): return snappedf(v, 0.01)), "xf": xf.map(func(v): return snappedf(v, 0.01)),
			"ratios": ratios, "picks": picks}))
	# 2) 10 回合（剑九冷却 2 现值／冷却 3 对照），种子 1～5 均值比
	for row in [TIERS[1], TIERS[3]]:
		var out := {}
		for cd in [2, 3]:
			var kd := []
			var xf := []
			for sd in [1, 2, 3, 4, 5]:
				kd.append(_bench(122, row, sd, 10, true, 1, cd).total)
				xf.append(_bench(152, row, sd, 10, true, 1, cd).total)
			out["cd%d" % cd] = snappedf(_mean(xf) / maxf(1e-9, _mean(kd)), 0.0001)
		print("BENCH10 ", row[0], " ", JSON.stringify(out))
	# 3) 三敌木桩（群战，附报）
	for row in [TIERS[1], TIERS[3]]:
		var kd := []
		var xf := []
		for sd in [1, 2, 3]:
			kd.append(_bench(122, row, sd, 5, true, 3).total)
			xf.append(_bench(152, row, sd, 5, true, 3).total)
		print("BENCH3E ", row[0], " ", JSON.stringify({"ratio": snappedf(_mean(xf) / maxf(1e-9, _mean(kd)), 0.0001)}))
	# 4) TP 不补满（只补 MP；剑一回 TP 的实际作用），5 回合
	for row in [TIERS[1], TIERS[3]]:
		var kd := []
		var xf := []
		for sd in [1, 2, 3]:
			kd.append(_bench(122, row, sd, 5, false, 1).total)
			xf.append(_bench(152, row, sd, 5, false, 1).total)
		print("BENCHTP ", row[0], " ", JSON.stringify({"ratio": snappedf(_mean(xf) / maxf(1e-9, _mean(kd)), 0.0001)}))
	# 5) 一击：剑九、9998 对狂刀最强单招 6039（暴击／不暴击）
	for row in [TIERS[1], TIERS[3]]:
		var o := {}
		for crit in [true, false]:
			XStateEffects.force_critical = crit
			var tag := "crit" if crit else "nocrit"
			o["jian9_" + tag] = snappedf(_one_hit(152, row, 9995), 0.01)
			o["g9998_" + tag] = snappedf(_one_hit(152, row, 9998), 0.01)
			o["kd6039_" + tag] = snappedf(_one_hit(122, row, 6039), 0.01)
		o["jian9_vs_kd_crit"] = snappedf(o.jian9_crit / maxf(1e-9, o.kd6039_crit), 0.001)
		o["jian9_vs_9998_crit"] = snappedf(o.jian9_crit / maxf(1e-9, o.g9998_crit), 0.001)
		print("ONEHIT ", row[0], " ", JSON.stringify(o))
	XStateEffects.force_critical = true


func _mean(arr: Array) -> float:
	var s := 0.0
	for v in arr:
		s += float(v)
	return s / float(arr.size())


func _setup_actor(aid: int, row: Array, sd: int) -> XState:
	var s := XState.new_game_blank()
	s.random_master = XRandomStream.hex64(1000003 + aid * 7919 + int(sd))
	s.set_switch(2494, true)
	s.set_variable(20, 30)
	XState.current = s
	s.add_actor(aid)
	for i in 5:
		s.set_battle_slot(i, aid if i == 0 else 0)
	var a: XActor = s.actor(aid)
	a.change_level(int(row[1]))
	var art: Dictionary = a.make_equip("armor", 4575 if aid == 122 else 143)
	art["level"] = int(row[2])
	_equip_in_slot(a, art)
	var wpn := int(row[3]) if aid == 122 else int(row[4])
	if wpn > 0:
		a.equips[0] = a.make_equip("weapon", wpn)
	if aid == 152 and int(row[5]) > 0:
		_equip_in_slot(a, a.make_equip("armor", int(row[5])))
	a.param_mark_dirty()
	a.refresh_passive()
	for sid in a.skill_ids:
		a.mastery_levels[sid] = 32
	a.recover_all()
	return s


func _kd_pick(logic: XBattleLogic, a: XActor):
	for cand in [6039, 6028, 6026, 6025, 6024]:
		if a.skill_ids.has(cand) and logic.can_use(a, XDB.rec("Skills", cand)):
			return XDB.rec("Skills", cand)
	return null


## troop_n > 1：临时把 Troop 70 的木桩复制成 troop_n 个（跑完还原）
func _bench(aid: int, row: Array, sd: int, rounds: int, tp_refill: bool, troop_n: int, cd := -1) -> Dictionary:
	var s := _setup_actor(aid, row, sd)
	var a: XActor = s.actor(aid)
	var troops: Array = XDB.table("Troops")
	var members_bak: Array = troops[70].members
	if troop_n > 1:
		var m2 := []
		for i in troop_n:
			var m: Dictionary = members_bak[0].duplicate(true)
			m.x = int(m.get("x", 400)) + i * 60
			m2.append(m)
		troops[70].members = m2
	var logic := XBattleLogic.new()
	var rng := XBattleRandom.create(str(s.random_master))
	logic.setup(70, s, rng)
	troops[70].members = members_bak
	for foe in logic.enemies:
		foe.param_refresh()
		foe.recover_all()
	if not tp_refill:
		a.tp = 0.0
	var total := 0.0
	var picks := {}
	for _t in rounds:
		logic.start_turn()
		var n_act := 1
		for p in a.action_plus_set():
			if rng.rule_now().next_float("action_plus") < float(p):
				n_act += 1
		for _k in n_act:
			if not logic.can_move(a):
				continue
			a.mp = a.mmp
			if tp_refill:
				a.tp = 100.0
			var sk = null
			var target: XBattler = logic.enemies[0]
			if aid == 122:
				sk = _kd_pick(logic, a)
			else:
				var pick := XSmartAI.choose(logic, a)
				sk = pick.get("skill")
				if pick.get("target") is XBattler:
					target = pick.target
			if sk == null:
				continue
			picks[str(int(sk.id))] = int(picks.get(str(int(sk.id)), 0)) + 1
			for e in logic.act(a, sk, target):
				if e is Dictionary and str(e.get("type", "")) == "hit" and logic.enemies.has(e.get("target")):
					total += maxf(0.0, float(e.get("hp", 0.0)))
			for foe in logic.enemies:
				foe.hp = foe.mhp
			if aid == 152 and cd > 0 and sk is Dictionary and int(sk.id) == 9995:
				a.cooldowns[9995] = float(cd)
		logic.end_turn()
	logic.end_battle(0)
	return {"total": total / 1.0e12, "picks": picks}


func _one_hit(aid: int, row: Array, sid: int) -> float:
	var s := _setup_actor(aid, row, 1)
	var a: XActor = s.actor(aid)
	var logic := XBattleLogic.new()
	logic.setup(70, s, XBattleRandom.create(str(s.random_master)))
	var foe: XEnemy = logic.enemies[0]
	foe.param_refresh()
	foe.recover_all()
	logic.start_turn()
	a.warmups.clear()
	a.cooldowns.clear()
	a.mp = a.mmp
	a.tp = 100.0
	var sum := 0.0
	for e in logic.act(a, XDB.rec("Skills", sid), foe):
		if e is Dictionary and str(e.get("type", "")) == "hit" and is_same(e.get("target"), foe):
			sum += maxf(0.0, float(e.get("hp", 0.0)))
	logic.end_battle(0)
	return sum / 1.0e12
