extends Node
## 天启篇元素独特效果（XTianqiElementEffects，设计稿《天启篇_元素独特效果_v0.3》，T480＝B 卡「我方打敌」）固定断言：
## §3.1 两条（双属性只掷胜出系、多段按段胜出元素分系各掷一次且基数取合格段合计）＋护盾全吸／未命中不掷；
## §3.4 四例（旧已挂、新被旧顶掉、同次出手、提前净化）；§3.6 三条（两个行动位只少一个、旧眩晕解除后先放行一次、待生效时被上旧眩晕）＋共用冷却 5 次；
## §4.3 首领表（感电、只迟缓、最终持续、不再减半）；§3.3 高等回归两条（高等不掷十系、高等打首领弱点暴露照旧；敌人高等打我方按受击者原倍率）；
## 圣护（己方单体、群体人人都给、对敌给施放者、盾挡对方减益）、冰冻、体质免疫、子流不动主流、开关关与西游档不回归。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _tq_state(diff := "lianyu") -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var lineup := [w[0], w[1], w[2], w[3], w[5]]
	var s := XTianqi.start_new_game(3, diff, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		s.actor(id).recover_all()
	return s


func _stub(id: int, elem: int, formula := "5", dtype := 1, scope := 1, multi := [], effects := []) -> Dictionary:
	var val := float(formula)
	var prog := {"version": 1, "status": "pure", "locals": ["value"], "source": {"sha256": "t480_%d" % id},
		"steps": [{"op": "set", "name": "value", "value": {"op": "literal", "value": val}}], "result": "value"}
	var sk := {"id": id, "name": "T480_%d" % id, "scope": scope, "hitType": 2, "stypeId": 1, "mpCost": 0, "tpCost": 0,
		"effects": effects, "note": "", "meta": {},
		"damage": {"type": dtype, "elementId": elem, "critical": false, "variance": 0, "formula": formula, "formulaProgram": prog}}
	if not multi.is_empty():
		sk["yep"] = {"multipleElements": multi}
	return sk


## 几率拨满（首领 ×1、敌方同拨；拨满时敌方给 2.0 盖过角色 SSS 韧性 ×0.90，免随机抖动）：只改缓存里的表，收尾 reload
func _force(chance := 1.0, boss_rate := 1.0) -> void:
	var d := XTianqiElements.data()
	for k in d.effect_tiers:
		d.effect_tiers[k].chance = chance
	d.effect_rules.boss_chance_rate = boss_rate
	d.enemy_effect_rules.base_chance = 2.0 if chance >= 1.0 else chance


func _natures(map: Dictionary) -> void:
	var en := {}
	for k in map:
		en[str(k)] = {"natures": map[k]}
	XTianqiNature._enemy = {"special": {"hongjun": {"natures": []}, "knight": {"natures": []}}, "enemies": en}
	XTianqiNature._enemy_failed = false


func _actor_natures(map: Dictionary) -> void:
	var ac := {}
	for k in map:
		ac[str(k)] = {"natures": map[k]}
	XTianqiNature._actor = {"actors": ac}
	XTianqiNature._actor_failed = false


var _plain_troop := -1

## 找一个首位不是首领的普通敌群
func _normal_logic(s: XState) -> XBattleLogic:
	if _plain_troop < 0:
		var troops: Array = XDB.table("Troops")
		for i in range(1, mini(troops.size(), 400)):
			var t = troops[i]
			if not t is Dictionary or (t.get("members", []) as Array).is_empty():
				continue
			var eid := int(t.members[0].enemyId)
			if eid <= 0 or XEnemy.boss_id(eid) or XGuardianRework.floor_of(eid) > 0:
				continue
			_plain_troop = i
			break
	var lg := XBattleLogic.new()
	lg.setup(_plain_troop, s)
	for e in lg.enemies:
		e.recover_all()
	return lg


func _boss_logic(s: XState, floor_no := 14) -> XBattleLogic:
	XTianqiElements.ensure_deck(s, 66223)
	var lg := XBattleLogic.new()
	lg.setup(int(XGuardianRework.TROOPS[floor_no]), s)
	lg.enemies[0].recover_all()
	return lg


func _hit(lg: XBattleLogic, a, sk: Dictionary, t) -> Dictionary:
	t.hp = t.mhp  # 夹具：普通怪血少，每段前回满，只看效果
	XTianqiElementEffects.frame_begin(lg, a)
	var r := lg.apply(a, sk, t)
	XTianqiElementEffects.frame_end(lg, a)
	return r


func _st(lg, elem: int, what: String) -> int:
	return int(XTianqiElementEffects.stats(lg).get(str(elem), {}).get(what, 0))


func _run() -> void:
	XTianqiBase.PHASE4 = false
	XTianqiSkills.MASTERY = false
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	seed(20261125)
	_test_states_and_data()
	_test_contract()
	_test_merge()
	_test_stop_slots()
	_test_freeze_immune()
	_test_boss_table()
	_test_higher_regression()
	_test_holy()
	_test_holy_real_db()
	_test_r2_table_and_shield()
	_test_b2_enemy_to_actor_and_nature()
	_test_b2_actor_judgment_and_slots()
	_test_b2_enemy_budgets_and_holy()
	_test_b2_higher_no_expand_and_guard()
	_test_stream_and_switch()
	XTianqiElements.EFFECTS = true
	XTianqiElements.reload_table()
	XTianqiNature.reload_table()
	XState.current = null
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL:%s -> %s" % [r.name, str(r.detail)])
	print("TEST_RESULT=%s" % JSON.stringify({"total": results.size(), "passed": passed}))
	get_tree().quit(0 if passed == results.size() else 1)


func _reset() -> void:
	XTianqiElements.reload_table()
	XTianqiNature.reload_table()
	XTianqiElements.EFFECTS = true


func _test_states_and_data() -> void:
	_reset()
	var size: int = (XDB.table("States") as Array).size()
	var ok := true
	for id in XTianqiElementEffects.STATE_IDS:
		var rec := XDB.rec("States", id)
		if id < size or rec.is_empty() or int(rec.restriction) != 0 or XTianqiSkills.has_new_state(id):
			ok = false
	_check("states_out_of_table_restriction0_no_clash", ok, size)
	var boss_tags := [XTianqiElementEffects.ST_SHOCK, XTianqiElementEffects.ST_SLOW, XTianqiElementEffects.ST_BURN, XTianqiElementEffects.ST_VEIL]
	_check("boss_versions_no_control_tag", not boss_tags.any(func(id): return XEnemy.boss_control_state(id)))
	_check("tier_chances_trial", is_equal_approx(XTianqiElementEffects.tier_chance(2), 0.11) and is_equal_approx(XTianqiElementEffects.tier_chance(3), 0.15)
		and is_equal_approx(XTianqiElementEffects.tier_chance(5), 0.15) and is_equal_approx(XTianqiElementEffects.tier_chance(14), 0.22) and is_equal_approx(XTianqiElementEffects.tier_chance(8), 0.11))
	var s := _tq_state()
	var lg := _normal_logic(s)
	var a: XActor = s.battle_members()[0]
	var e: XEnemy = lg.enemies[0]
	_check("nature_reads_tables", XTianqiNature.of(a) == XTianqiNature.actor_table().get("actors", {}).get(str(a.actor_id), {}).get("natures", []).map(func(x): return int(x)))
	_check("fx_meta_started_in_tianqi", lg.has_meta(XTianqiElementEffects.META) and XTianqiElementEffects.seed_of(lg) != "")
	_natures({e.enemy_id: [14]})
	_check("nature_override_enemy", XTianqiNature.of(e) == [14])


## §3.1 固定断言 1、2，加反例
func _test_contract() -> void:
	_reset()
	_force()
	var s := _tq_state()
	var a: XActor = s.battle_members()[0]
	# 固定断言 1：火／X 双属性打「火无效」的首领，X 胜出扣血 → 只掷 X
	var lb := _boss_logic(s)
	var boss: XEnemy = lb.enemies[0]
	_natures({})
	var prof := XTianqiElements.enemy_profile(boss, lb, s)
	var imm := -1
	for x in prof.immune:
		if XTianqiElements.BASE_ELEMENTS.has(int(x)):
			imm = int(x)
	var other := -1
	for x in [2, 3, 4, 5, 6, 7, 9, 14, 15]:
		if x != imm and not (prof.immune as Array).has(x):
			other = x
			break
	var r1 := _hit(lb, a, _stub(98480, imm, "1000", 1, 1, [imm, other]), boss)
	_check("contract_1_dual_only_winner_rolls", imm > 0 and int(r1.get("best_row", {}).get("element", 0)) == other
		and _st(lb, other, "eligible") == 1 and _st(lb, imm, "eligible") == 0, [imm, other, r1.get("best_row", {}).get("element"), XTianqiElementEffects.stats(lb)])
	# 固定断言 2：同一行动三段：段 1 火扣血、段 2 火全被护盾吸掉（0）、段 3 雷扣血 → 火一次（基数＝段 1）、雷一次
	var lg := _normal_logic(s)
	var e: XEnemy = lg.enemies[0]
	_natures({})
	XTianqiElementEffects.frame_begin(lg, a)
	var s1 := lg.apply(a, _stub(98481, 2, "800"), e)
	e.shield = 99999999.0
	var s2 := lg.apply(a, _stub(98482, 2, "800"), e)
	e.shield = 0.0
	var s3 := lg.apply(a, _stub(98483, 5, "800"), e)
	XTianqiElementEffects.frame_end(lg, a)
	var un: Dictionary = lg.get_meta(XTianqiElementEffects.META).units.get(e, {})
	var tick := float(un.get("dot", {}).get("burn", {}).get("tick", -1.0))
	var want := minf(floorf(float(s1.hp_loss) * 0.11), floorf(e.mhp * 0.05))
	_check("contract_2_per_element_once_base_sum", float(s2.get("hp_loss", 0.0)) == 0.0 and float(s1.hp_loss) > 0.0 and float(s3.hp_loss) > 0.0
		and _st(lg, 2, "eligible") == 1 and _st(lg, 5, "eligible") == 1
		and e.state_ids.has(XTianqiElementEffects.ST_BURN) and e.state_ids.has(XTianqiElementEffects.ST_PARALYZE) and tick == want,
		[s1.get("hp_loss"), s2.get("hp_loss"), s3.get("hp_loss"), tick, want, XTianqiElementEffects.stats(lg)])
	# 反例：全被护盾吸掉不掷
	var lg2 := _normal_logic(s)
	var e2: XEnemy = lg2.enemies[0]
	e2.shield = 99999999.0
	_hit(lg2, a, _stub(98484, 4, "800"), e2)
	_check("contract_shield_all_absorbed_no_roll", _st(lg2, 4, "eligible") == 0 and not e2.state_ids.has(XTianqiElementEffects.ST_SHATTER))
	e2.shield = 0.0
	# 灼烧跳伤：回合末按 tick 扣血、不再掷
	var hp0 := e.hp
	var logs := []
	XTianqiElementEffects.tick_dot(lg, e, logs)
	_check("burn_tick_at_turn_end_no_retrigger", is_equal_approx(hp0 - e.hp, tick) and _st(lg, 2, "eligible") == 1, [hp0 - e.hp, tick])
	# 散段（没开帧的 apply）在 act 收尾补掷
	var lg3 := _normal_logic(s)
	var e3: XEnemy = lg3.enemies[0]
	lg3.apply(a, _stub(98485, 4, "800"), e3)
	var before := e3.state_ids.has(XTianqiElementEffects.ST_SHATTER)
	XTianqiElementEffects.flush(lg3)
	_check("loose_segments_roll_at_flush", not before and e3.state_ids.has(XTianqiElementEffects.ST_SHATTER)
		and int(e3.state_turns.get(XTianqiElementEffects.ST_SHATTER, 0)) == 2)


## §3.4 四例
func _test_merge() -> void:
	_reset()
	_force()
	var s := _tq_state()
	var a: XActor = s.battle_members()[0]
	_natures({})
	var B := XTianqiElementEffects.ST_BURN
	# ① 已挂旧灼伤 → 新灼烧落空，不耗冷却（撤掉旧的同回合再掷就能挂）
	var lg := _normal_logic(s)
	var e: XEnemy = lg.enemies[0]
	lg._state_add(e, 17)
	_hit(lg, a, _stub(98490, 2), e)
	var miss1 := not e.state_ids.has(B)
	lg._state_remove(e, 17)
	_hit(lg, a, _stub(98491, 2), e)
	_check("merge_1_old_present_new_misses_no_cd", e.state_ids.has(17) == false and miss1 and e.state_ids.has(B))
	# ② 新已挂，旧技能挂上旧灼伤 → 顶掉新的；新冷却从此刻起算（同回合再掷挂不上）
	lg._state_add(e, 18)
	var kicked := not e.state_ids.has(B) and e.state_ids.has(18)
	lg._state_remove(e, 18)
	_hit(lg, a, _stub(98492, 2), e)
	var cd_block := not e.state_ids.has(B)
	lg.turn += 2
	_hit(lg, a, _stub(98493, 2), e)
	_check("merge_2_old_overrides_new_cd_starts", kicked and cd_block and e.state_ids.has(B))
	# ③ 同一次出手：旧状态（技能效果）与新效果都成功 → 旧的先结算，新的见旧已挂落空
	var lg2 := _normal_logic(s)
	var e2: XEnemy = lg2.enemies[0]
	var sk3 := _stub(98494, 2, "1000", 1, 1, [], [{"code": 21, "dataId": 17, "value1": 1.0, "value2": 0.0}])
	sk3.hitType = 0
	_hit(lg2, a, sk3, e2)
	_check("merge_3_same_action_old_first", e2.state_ids.has(17) and not e2.state_ids.has(B), e2.state_ids)
	# ④ 新效果被提前净化 → 视为到期，冷却照常起算
	var lg3 := _normal_logic(s)
	var e3: XEnemy = lg3.enemies[0]
	_hit(lg3, a, _stub(98495, 2), e3)
	var had := e3.state_ids.has(B)
	lg3._state_remove(e3, B)
	_hit(lg3, a, _stub(98496, 2), e3)
	var blocked := not e3.state_ids.has(B)
	lg3.turn += 2
	_hit(lg3, a, _stub(98497, 2), e3)
	_check("merge_4_purged_counts_as_expired", had and blocked and e3.state_ids.has(B))
	# 麻痹归并：旧麻痹（停手）挂着 → 元素麻痹落空
	var lg4 := _normal_logic(s)
	var e4: XEnemy = lg4.enemies[0]
	lg4._state_add(e4, 100)
	_hit(lg4, a, _stub(98498, 5), e4)
	_check("merge_old_paralysis_blocks_new", e4.state_ids.has(100) and not e4.state_ids.has(XTianqiElementEffects.ST_PARALYZE))


func _skip_logs(logs: Array) -> bool:
	return logs.any(func(x): return x is Dictionary and str(x.get("type", "")) == "skip")


## §3.6 三条＋共用冷却
func _test_stop_slots() -> void:
	_reset()
	_force()
	var s := _tq_state()
	var a: XActor = s.battle_members()[0]
	var P := XTianqiElementEffects.ST_PARALYZE
	# ① 同回合两个行动位：只少一个
	var lg := _normal_logic(s)
	var e: XEnemy = lg.enemies[0]
	_natures({})
	_hit(lg, a, _stub(98500, 5), e)
	var marked := e.state_ids.has(P)
	var l1 := lg.act(e, e.attack_skill(), a)
	var l2 := lg.act(e, e.attack_skill(), a)
	_check("stop_1_two_slots_only_one_lost", marked and _skip_logs(l1) and not _skip_logs(l2) and not e.state_ids.has(P)
		and XTianqiElementEffects.skip_count(lg, e) == 1)
	# 共用冷却：吃位后要完成 5 次行动
	_hit(lg, a, _stub(98501, 5), e)
	var cd_block := not e.state_ids.has(P)
	lg.turn += 3
	for i in 3:  # 吃位后第二个行动位已完成 1 次，再 3 次＝4 次，还差 1 次
		lg.act(e, e.attack_skill(), a)
	_hit(lg, a, _stub(98502, 5), e)
	var still := not e.state_ids.has(P)
	lg.act(e, e.attack_skill(), a)
	_hit(lg, a, _stub(98503, 5), e)
	_check("stop_shared_cooldown_5_actions", cd_block and still and e.state_ids.has(P))
	# ② 旧眩晕回合末解除后、出手前掷中元素麻痹 → 挂不上、不耗冷却；完成 1 次行动后才可挂
	var lg2 := _normal_logic(s)
	var e2: XEnemy = lg2.enemies[0]
	lg2._state_add(e2, 29)
	var stunned := e2.state_ids.has(29)
	lg2._state_remove(e2, 29)
	_hit(lg2, a, _stub(98504, 5), e2)
	var no_mark := not e2.state_ids.has(P)
	var no_cd: bool = not (lg2.get_meta(XTianqiElementEffects.META).units[e2].until as Dictionary).has("paralyze")
	lg2.act(e2, e2.attack_skill(), a)
	_hit(lg2, a, _stub(98505, 5), e2)
	_check("stop_2_after_old_stun_one_action_first", stunned and no_mark and no_cd and e2.state_ids.has(P))
	# ③ 元素麻痹待生效时被上旧眩晕 → 旧眩晕生效，标记移除，只计旧眩晕的失行动
	var lg3 := _normal_logic(s)
	var e3: XEnemy = lg3.enemies[0]
	_hit(lg3, a, _stub(98506, 5), e3)
	var m3 := e3.state_ids.has(P)
	lg3._state_add(e3, 29)
	var l3 := lg3.act(e3, e3.attack_skill(), a)
	_check("stop_3_pending_then_old_stun", m3 and e3.state_ids.has(29) and not e3.state_ids.has(P) and _skip_logs(l3)
		and XTianqiElementEffects.skip_count(lg3, e3) == 0)


func _test_freeze_immune() -> void:
	_reset()
	_force()
	var s := _tq_state()
	var a: XActor = s.battle_members()[0]
	var lg := _normal_logic(s)
	var e: XEnemy = lg.enemies[0]
	_natures({})
	_hit(lg, a, _stub(98510, 3), e)
	var slow1 := e.state_ids.has(XTianqiElementEffects.ST_SLOW) and int(e.state_turns[XTianqiElementEffects.ST_SLOW]) == 2
	lg._state_remove(e, XTianqiElementEffects.ST_SLOW)
	XTianqiElementEffects.end_turn(lg)
	lg.turn += 2
	_hit(lg, a, _stub(98511, 3), e)
	var frozen := e.state_ids.has(XTianqiElementEffects.ST_FREEZE)
	lg.act(e, e.attack_skill(), a)
	lg.turn += 2
	for i in 5:
		lg.act(e, e.attack_skill(), a)
	_hit(lg, a, _stub(98512, 3), e)
	_check("ice_second_slow_freezes_once_per_battle", slow1 and frozen and not e.state_ids.has(XTianqiElementEffects.ST_FREEZE) and e.state_ids.has(XTianqiElementEffects.ST_SLOW))
	# 水体质：第一次迟缓即冻；浸湿中被挂迟缓也直接冻
	var lw := _normal_logic(s)
	var ew: XEnemy = lw.enemies[0]
	_natures({ew.enemy_id: [14]})
	_hit(lw, a, _stub(98513, 3), ew)
	_check("water_nature_first_slow_freezes", ew.state_ids.has(XTianqiElementEffects.ST_FREEZE))
	var ls := _normal_logic(s)
	var es: XEnemy = ls.enemies[0]
	_natures({})
	_hit(ls, a, _stub(98514, 14), es)
	_hit(ls, a, _stub(98515, 3), es)
	_check("soaked_slow_freezes", es.state_ids.has(XTianqiElementEffects.ST_SOAK) and es.state_ids.has(XTianqiElementEffects.ST_FREEZE))
	# 体质免疫（地、雷不吃麻痹）与种族（亡灵、机械不吃寄生）
	var li := _normal_logic(s)
	var ei: XEnemy = li.enemies[0]
	_natures({ei.enemy_id: [4]})
	_hit(li, a, _stub(98516, 5), ei)
	_hit(li, a, _stub(98517, 2), ei)
	_check("constitution_immune_no_cd", not ei.state_ids.has(XTianqiElementEffects.ST_PARALYZE) and not ei.state_ids.has(XTianqiElementEffects.ST_BURN)
		and _st(li, 5, "immune") == 1 and _st(li, 2, "immune") == 1)
	_check("matrix_reads_race_column", (XTianqiElements.data().effect_immunity["6"].race as Array).map(func(x): return int(x)).has(2) and (XTianqiElements.data().effect_immunity["15"].race as Array).map(func(x): return int(x)).has(7))
	# 浸湿：出手方伤害 −11%；遮蔽锋芒：暴击多出 −33%
	_check("soak_out_mult_and_veil_crit", is_equal_approx(XTianqiElementEffects.out_mult(es), 0.89) and is_equal_approx(XTianqiElementEffects.out_mult(a), 1.0)
		and is_equal_approx(XTianqiElementEffects.crit_mult(a, 2.0), 2.0))
	var lv := _normal_logic(s)
	var ev: XEnemy = lv.enemies[0]
	_hit(lv, a, _stub(98518, 9), ev)
	_check("veil_crit_extra_minus_33", ev.state_ids.has(XTianqiElementEffects.ST_VEIL) and is_equal_approx(XTianqiElementEffects.crit_mult(ev, 2.0), 1.67))


## §4.3 首领表
func _test_boss_table() -> void:
	_reset()
	_force()
	var s := _tq_state()
	var a: XActor = s.battle_members()[0]
	var want := {2: [XTianqiElementEffects.ST_BURN, 2], 3: [XTianqiElementEffects.ST_SLOW, 1], 4: [XTianqiElementEffects.ST_SHATTER, 1],
		5: [XTianqiElementEffects.ST_SHOCK, 1], 6: [XTianqiElementEffects.ST_PARASITE, 2], 7: [XTianqiElementEffects.ST_ARCANE, 1],
		9: [XTianqiElementEffects.ST_VEIL, 1], 14: [XTianqiElementEffects.ST_SOAK, 1], 15: [XTianqiElementEffects.ST_GUST, 1]}
	var bad := []
	for elem in want:
		var lb := _boss_logic(s)
		var boss: XEnemy = lb.enemies[0]
		_natures({})
		var prof := XTianqiElements.enemy_profile(boss, lb, s)
		if (prof.immune as Array).has(elem):
			lb = _boss_logic(s, 20)
			boss = lb.enemies[0]
			prof = XTianqiElements.enemy_profile(boss, lb, s)
			if (prof.immune as Array).has(elem):
				continue
		_hit(lb, a, _stub(98520 + elem, elem, "3000"), boss)
		var sid: int = want[elem][0]
		if not boss.state_ids.has(sid) or int(boss.state_turns.get(sid, 0)) != int(want[elem][1]) or boss.state_ids.has(XTianqiElementEffects.ST_PARALYZE) or boss.state_ids.has(XTianqiElementEffects.ST_FREEZE):
			bad.append([elem, boss.state_ids.has(sid), boss.state_turns.get(sid)])
		if elem == 5 and not is_equal_approx(XTianqiElements.combined_exposure_pct(lb, boss, 0.0), 11.0):
			bad.append(["shock_exposure", XTianqiElements.combined_exposure_pct(lb, boss, 0.0)])
		if elem == 3:
			lb._state_remove(boss, XTianqiElementEffects.ST_SLOW)
			XTianqiElementEffects.end_turn(lb)
			lb.turn += 3
			_hit(lb, a, _stub(98540, 3, "3000"), boss)
			if boss.state_ids.has(XTianqiElementEffects.ST_FREEZE) or not boss.state_ids.has(XTianqiElementEffects.ST_SLOW):
				bad.append(["boss_no_freeze"])
	_check("boss_table_versions_and_final_turns", bad.is_empty(), bad)
	# 首领到期冷却 2 回合；几率 ×0.5（拨到 0 时首领掷 1.0×0.5 仍可能中，只验冷却）
	var lb2 := _boss_logic(s)
	var b2: XEnemy = lb2.enemies[0]
	var ok_elem := 4 if not (XTianqiElements.enemy_profile(b2, lb2, s).immune as Array).has(4) else 7
	var sid2 := XTianqiElementEffects.ST_SHATTER if ok_elem == 4 else XTianqiElementEffects.ST_ARCANE
	_hit(lb2, a, _stub(98541, ok_elem, "3000"), b2)
	lb2._state_remove(b2, sid2)
	_hit(lb2, a, _stub(98542, ok_elem, "3000"), b2)
	var c0 := b2.state_ids.has(sid2)
	lb2.turn += 2
	_hit(lb2, a, _stub(98543, ok_elem, "3000"), b2)
	var c2 := b2.state_ids.has(sid2)
	lb2._state_remove(b2, sid2)
	XTianqiElementEffects.end_turn(lb2)
	lb2.turn += 3
	_hit(lb2, a, _stub(98544, ok_elem, "3000"), b2)
	_check("boss_cooldown_2_turns", not c0 and not c2 and b2.state_ids.has(sid2))
	_check("effect_boss_predicate", XTianqiElementEffects.effect_boss(lb2, b2) and not XTianqiElementEffects.effect_boss(lb2, a))


## §3.3 高等回归两条
func _test_higher_regression() -> void:
	_reset()
	_force()
	var s := _tq_state()
	var a: XActor = s.battle_members()[0]
	var lb := _boss_logic(s)
	var boss: XEnemy = lb.enemies[0]
	_natures({})
	var bad := []
	for h in [11, 12, 13]:
		var r := _hit(lb, a, _stub(98550 + h, h, "2000"), boss)
		if h == 11 and not bool(r.get("void_engulfed", false)):
			bad.append("void")
		if h == 13 and float(r.get("space_erosion", 0.0)) <= 0.0:
			bad.append("space")
	var any_state := XTianqiElementEffects.STATE_IDS.any(func(id): return boss.state_ids.has(id))
	_check("higher_1_no_ten_effects_and_old_behaviour", bad.is_empty() and not any_state and XTianqiElementEffects.stats(lb).is_empty()
		and XTianqiElements.has_weak_exposure(lb, boss), [bad, XTianqiElementEffects.stats(lb)])
	var er := XTianqiElements.element_rate_for(a, 11, false, lb)
	_check("higher_2_enemy_higher_on_actor_uses_own_rate", str(er.kind) == "neutral" and is_equal_approx(float(er.rate), a.element_rate(11)), er)


func _test_holy() -> void:
	_reset()
	_force()
	var s := _tq_state()
	var mem: Array = s.battle_members()
	var a: XActor = mem[0]
	var H := XTianqiElementEffects.ST_HOLY
	var lg := _normal_logic(s)
	var e: XEnemy = lg.enemies[0]
	_natures({})
	(XTianqiElements.data().holy_ally.skills as Array).append_array([98560, 98561])  # 夹具技能进白名单（只改缓存，_reset 重读）
	# 己方单体：先驱散 1 个可解除减益，再给盾（给技能目标）
	var b: XActor = mem[1]
	lg._state_add(b, 12)
	var heal := _stub(98560, 8, "10", 3, 7)
	_hit(lg, a, heal, b)
	_check("holy_ally_target_dispel_then_shield", b.state_ids.has(H) and not b.state_ids.has(12) and not a.state_ids.has(H))
	# 群体己方：一次行动只掷一次，中了目标人人都给（D285 补）
	var lg2 := _normal_logic(s)
	XTianqiElementEffects.frame_begin(lg2, a)
	var grp := mem.slice(1)
	for m in grp:
		m.remove_state(H)
	for m in grp:
		lg2.apply(a, _stub(98561, 8, "10", 3, 8), m)
	XTianqiElementEffects.frame_end(lg2, a)
	_check("holy_group_allies_everyone", grp.size() >= 2 and grp.all(func(m): return m.state_ids.has(H)) and _st(lg2, 8, "rolled") == 1, grp.size())
	# 对敌：给施放者自己（D285 补），敌人不得
	for m in mem:
		m.remove_state(H)
	var lg3 := _normal_logic(s)
	var e3: XEnemy = lg3.enemies[0]
	XTianqiElementEffects.frame_begin(lg3, a)
	lg3.apply(a, _stub(98562, 8, "800", 1, 2), e3)
	lg3.apply(a, _stub(98562, 8, "800", 1, 2), lg3.enemies[-1])
	XTianqiElementEffects.frame_end(lg3, a)
	_check("holy_vs_enemy_to_caster_once", a.state_ids.has(H) and not e3.state_ids.has(H) and _st(lg3, 8, "rolled") == 1)
	# 盾挡对方施加的可解除减益（一次就碎）；没有出手者（脚本／阶段状态）不挡
	XImportedBalance.set_acting(e3)
	a.add_state(12)
	var blocked := not a.state_ids.has(12) and not a.state_ids.has(H)
	a.add_state(13)
	XImportedBalance.set_acting(null)
	_check("holy_shield_blocks_one_enemy_debuff", blocked and a.state_ids.has(13))
	_hit(lg3, a, heal, b)
	var lg4 := _normal_logic(s)
	var c: XActor = mem[mem.size() - 1]
	c.remove_state(H)
	_hit(lg4, a, heal, c)
	XImportedBalance.set_acting(null)
	c.add_state(14)
	_check("holy_shield_ignores_scripted_states", c.state_ids.has(14) and c.state_ids.has(H))
	# 冷却记在持盾人身上：盾在不重给；盾没后 1 回合内不给
	c.remove_state(H)
	c.remove_state(14)
	_hit(lg4, a, heal, c)
	var cd := not c.state_ids.has(H)
	lg4.turn += 2
	_hit(lg4, a, heal, c)
	_check("holy_cooldown_on_holder", cd and c.state_ids.has(H))


## §5.5 子流不动主流；开关关、西游档零改动
func _test_stream_and_switch() -> void:
	_reset()
	var s := _tq_state()
	var a: XActor = s.battle_members()[0]
	var snaps := []
	for mode in ["off", "on0"]:
		_reset()
		if mode == "off":
			XTianqiElements.EFFECTS = false  # 回退支（O-664）：关着时不记账、不取子流
		_force(0.0, 0.0)
		var lg := XBattleLogic.new()
		lg.setup(_plain_troop if _plain_troop > 0 else 1, s, XBattleRandom.create(XRandomStream.hex64(4801234)))
		for en in lg.enemies:
			en.recover_all()
		var hp := []
		for i in 3:
			for en in lg.enemies:
				if en.is_alive():
					lg.execute(a, _stub(98570 + i, 2, "300", 1, 1, [2, 5]), en)
		for en in lg.enemies:
			hp.append(en.hp)
		snaps.append([JSON.stringify(lg.random.rule.snapshot()), hp, lg.has_meta(XTianqiElementEffects.META)])
	_check("substream_leaves_main_stream_identical", snaps[0][0] == snaps[1][0] and snaps[0][1] == snaps[1][1], [snaps[0][1], snaps[1][1]])
	_check("switch_off_no_meta", not snaps[0][2] and snaps[1][2])
	# 西游档：没有记账，钩子全不生效
	_reset()
	_force()
	var w := XState.new_game_blank()
	w.difficulty = 3
	w.add_actor(1)
	w.map_id = 4
	XState.current = w
	var lw := XBattleLogic.new()
	lw.setup(_plain_troop if _plain_troop > 0 else 1, w)
	var we: XEnemy = lw.enemies[0]
	we.recover_all()
	lw.execute(w.battle_members()[0], _stub(98580, 5, "100"), we)
	lw.execute(w.battle_members()[0], _stub(98581, 2, "100"), we)
	_check("west_save_untouched", not lw.has_meta(XTianqiElementEffects.META) and not XTianqiElementEffects.STATE_IDS.any(func(id): return we.state_ids.has(id))
		and is_equal_approx(XTianqiElementEffects.out_mult(we), 1.0))


## R2 P1-1：真实库神圣己方技（体质口径＋白名单＋排除），转换书不误触发；P1-2：神圣攻击被反射打回自己不挂圣护
func _test_holy_real_db() -> void:
	_reset()
	_force()
	var s := _tq_state()
	var mem: Array = s.battle_members()
	var a: XActor = mem[0]
	var H := XTianqiElementEffects.ST_HOLY
	_natures({})
	var yes := [2317, 2318, 2320, 5511, 5571, 5779, 6274, 680, 3968]  # 拉尔／阿语按体质；云霄、绯红蔷薇、伊莉雅、敌方圣光术按白名单
	var no := [749, 5513, 357, 73, 306, 1]  # 窃格瓦拉冷血、阿语仪式:转化（T480 遗留①排除）、治疗波、PUA、痛饮、普攻
	var bad := []
	for id in yes:
		if not XTianqiElementEffects.holy_ally_skill(XDB.rec("Skills", id)):
			bad.append(id)
	for id in no:
		if XTianqiElementEffects.holy_ally_skill(XDB.rec("Skills", id)):
			bad.append(-id)
	_check("holy_ally_real_skill_list", bad.is_empty(), bad)
	XTianqiElements.data().holy_ally.by_nature = false
	var off_nature := not XTianqiElementEffects.holy_ally_skill(XDB.rec("Skills", 2318)) and XTianqiElementEffects.holy_ally_skill(XDB.rec("Skills", 5571))
	XTianqiElements.data().holy_ally.by_nature = true
	_check("holy_ally_by_nature_switch", off_nature)
	# 实战：拉尔 2318 圣光净化（体质口径）、云霄 5571 黄庭圣经（白名单）、拉尔 2320 天堂光辉（无伤害类型的增益）对队友各给圣护
	var got := []
	var i := 1
	for id in [2318, 5571, 2320]:
		var lg := _normal_logic(s)
		var b: XActor = mem[i % mem.size()]
		i += 1
		b.remove_state(H)
		_hit(lg, a, XDB.rec("Skills", id), b)
		got.append(b.state_ids.has(H))
		b.remove_state(H)
	_check("holy_ally_real_skills_give_shield", got == [true, true, true], got)
	# 转换书（被动缓存 damageElement＝神圣）放非神圣治疗：不给圣护
	var c: XActor = mem[mem.size() - 1]
	c.remove_state(H)
	var lc := _normal_logic(s)
	var pc: Dictionary = a.passive_cache()
	var old_conv := int(pc.get("damageElement", 0))
	pc["damageElement"] = 8
	var conv_on := XDamage.action_elements(XDB.rec("Skills", 357), a) == [8]  # 前提：转换书确实把这招读成神圣
	_hit(lc, a, XDB.rec("Skills", 357), c)
	a.passive_cache()["damageElement"] = old_conv
	_check("holy_convert_book_no_ally_shield", conv_on and not c.state_ids.has(H) and _st(lc, 8, "eligible") == 0, [conv_on, XTianqiElementEffects.stats(lc)])
	# 反射反例（T480 P3-3）：用真实神圣伤害技 2704（阿语「仪式:神光」，holy_ally_skill 为真）经属性反射打回自己，不挂圣护、不记合格段；末尾 pop_back 还原全局 States 表
	var lr := _normal_logic(s)
	var foe: XEnemy = lr.enemies[0]
	var sk2704 := XDB.rec("Skills", 2704)
	var pre_2704 := XTianqiElementEffects.holy_ally_skill(sk2704)
	var st: Array = XDB.table("States")
	var mrf_id := st.size()
	st.append({"id": mrf_id, "name": "T485反射", "traits": [{"code": 22, "dataId": 5, "value": 1.0}],
		"yep": {"elementReflect": {"8": 1.0}}, "note": "", "meta": {},
		"iconIndex": 0, "restriction": 0, "autoRemovalTiming": 0, "removeAtBattleEnd": true})
	foe.add_state(mrf_id)
	a.remove_state(H)
	a.hp = a.mhp
	XTianqiElementEffects.frame_begin(lr, a)
	var rs := lr._invoke(a, sk2704, foe)
	XTianqiElementEffects.frame_end(lr, a)
	XTianqiElementEffects.flush(lr)
	foe.remove_state(mrf_id)
	st.pop_back()
	var reflected := rs.any(func(x): return str(x.get("type", "")) == "reflect")
	_check("holy_reflected_no_shield_no_segment", pre_2704 and reflected and not a.state_ids.has(H) and not foe.state_ids.has(H) and _st(lr, 8, "eligible") == 0,
		[pre_2704, reflected, XTianqiElementEffects.stats(lr)])
	# T480 P3-3 补：直接测 note_hit 在 r.reflected 或 logic._reflecting 为真时，跨边合格伤害段也不记账
	var ld := _normal_logic(s)
	var fe: XEnemy = ld.enemies[0]
	var fire_sk := _stub(98591, 2, "50", 1, 1)
	XTianqiElementEffects.frame_begin(ld, fe)
	XTianqiElementEffects.note_hit(ld, fe, fire_sk, a, {"hp_loss": 50.0, "best_row": {"element": 2, "tianqiKind": ""}, "reflected": true})
	var segs_flag: int = (ld.get_meta(XTianqiElementEffects.META).frames.back().segs as Array).size()
	ld._reflecting = true
	XTianqiElementEffects.note_hit(ld, fe, fire_sk, a, {"hp_loss": 50.0, "best_row": {"element": 2, "tianqiKind": ""}})
	ld._reflecting = false
	var segs_state: int = (ld.get_meta(XTianqiElementEffects.META).frames.back().segs as Array).size()
	XTianqiElementEffects.note_hit(ld, fe, fire_sk, a, {"hp_loss": 50.0, "best_row": {"element": 2, "tianqiKind": ""}})
	var segs_ctrl: int = (ld.get_meta(XTianqiElementEffects.META).frames.back().segs as Array).size()
	XTianqiElementEffects.frame_end(ld, fe)
	_check("reflected_segment_not_recorded", segs_flag == 0 and segs_state == 0 and segs_ctrl == 1, [segs_flag, segs_state, segs_ctrl])


## R2 P2-1（数值读表）、P2-2（反击帧的出手者）、P2-3（续回合也挡、受限时 removeByRestriction 不耗盾）、P2-4（迟缓不借 61）
func _test_r2_table_and_shield() -> void:
	_reset()
	var d := XTianqiElements.data()
	d.element_effects["3"].value = 0.30
	d.element_effects["15"].value = 0.2
	XTianqiElementEffects.clear_cache()
	var slow := XTianqiElementEffects.state_rec(XTianqiElementEffects.ST_SLOW)
	var gust := XTianqiElementEffects.state_rec(XTianqiElementEffects.ST_GUST)
	_check("state_values_from_table", is_equal_approx(float(slow.traits[0].value), 0.7) and str(slow.note).contains("敏捷 −30%")
		and is_equal_approx(float(gust.traits[1].value), -0.2), [slow.traits, gust.traits])
	_reset()
	_check("reload_rebuilds_state_rec", is_equal_approx(float(XTianqiElementEffects.state_rec(XTianqiElementEffects.ST_SLOW).traits[0].value), 0.78))
	_check("slow_no_borrow_61", not XTianqiElements.data().element_effects["3"].has("borrow"))
	var s := _tq_state()
	var mem: Array = s.battle_members()
	var a: XActor = mem[0]
	var H := XTianqiElementEffects.ST_HOLY
	var lg := _normal_logic(s)
	var e: XEnemy = lg.enemies[0]
	XTianqiElements.data().element_effects["5"].boss.value = 0.2
	lg._state_add(e, XTianqiElementEffects.ST_SHOCK)
	_check("shock_pct_from_table", is_equal_approx(XTianqiElements.combined_exposure_pct(lg, e, 5.0), 20.0), XTianqiElements.combined_exposure_pct(lg, e, 5.0))
	_reset()
	# 反击：我方出手（acting＝a）中敌人反击开帧，反击附带的减益算对方施加，盾挡
	lg._state_add(a, H)
	XImportedBalance.set_acting(a)
	XTianqiElementEffects.frame_begin(lg, e)
	a.add_state(12)
	XTianqiElementEffects.frame_end(lg, e)
	XImportedBalance.set_acting(null)
	_check("shield_blocks_enemy_counter_debuff", not a.state_ids.has(12) and not a.state_ids.has(H))
	# 已挂着的减益被对方重施（续回合）：照样挡
	var b: XActor = mem[1]
	b.add_state(12)
	lg._state_add(b, H)
	XImportedBalance.set_acting(e)
	b.add_state(12)
	XImportedBalance.set_acting(null)
	_check("shield_blocks_refresh_of_existing_debuff", b.state_ids.has(12) and not b.state_ids.has(H))
	# 盾碎日志带持盾者名字
	var logs := XTianqiElementEffects.flush(lg)
	_check("shield_log_names_holder", logs.any(func(l): return str(l.get("text", "")).begins_with(b.display_name() + " 的")), logs)
	# T480 复核 P3-4：外层我方 execute 帧仍在栈上时，敌人反击在 frame_end→_settle→_add 挂元素减益，我方圣护盾必须挡住（不能误读外层帧主漏挡）
	_reset()
	_force()
	_actor_natures({})
	var lcp := _normal_logic(s)
	var ec: XEnemy = lcp.enemies[0]
	var ac: XActor = mem[0]
	ac.recover_all()
	lcp._state_add(ac, H)
	XTianqiElementEffects.frame_begin(lcp, ac)
	XTianqiElementEffects.frame_begin(lcp, ec)
	lcp.apply(ec, _stub(98600, 2, "500"), ac)
	var counter_logs := XTianqiElementEffects.frame_end(lcp, ec)
	var outer_ok := not (lcp.get_meta(XTianqiElementEffects.META).frames as Array).is_empty() and is_same(lcp.get_meta(XTianqiElementEffects.META).frames.back().src, ac)
	XTianqiElementEffects.frame_end(lcp, ac)
	_check("p3_4_enemy_counter_element_debuff_blocked_by_actor_shield", not ac.state_ids.has(XTianqiElementEffects.ST_BURN) and not ac.state_ids.has(H)
		and outer_ok and counter_logs.any(func(l): return str(l.get("text", "")).contains("抵挡了")), [ac.state_ids, outer_ok, counter_logs])


## B2（T485）：敌打我方记账入口、共用事件契约与状态接口、我方体质（§4.4，读 actor_nature.json、不读种族、转换书不改体质）
func _test_b2_enemy_to_actor_and_nature() -> void:
	_reset()
	_force()
	var s := _tq_state()
	var mem: Array = s.battle_members()
	var a: XActor = mem[0]
	var b: XActor = mem[1]
	_natures({})
	_actor_natures({})
	# ① 敌打我方基础十系状态（灼烧＋5% 生命上限封顶、寄生回合末回血给敌方血量比例最低者、浸湿、遮蔽锋芒、碎甲、乱流、魔蚀）
	var lg := _normal_logic(s)
	var e: XEnemy = lg.enemies[0]
	a.recover_all()
	var r_cap := _hit(lg, e, _stub(98610, 2, "750"), a)  # 过防后扣血 ~290：活着且 11% > 5% mhp 封顶
	var burn_un: Dictionary = lg.get_meta(XTianqiElementEffects.META).units.get(a, {})
	var burn_tick := float(burn_un.get("dot", {}).get("burn", {}).get("tick", -1.0))
	var burn_cap := floorf(a.mhp * 0.05)
	_check("b2_enemy_burn_and_5pct_cap", a.is_alive() and float(r_cap.hp_loss) * 0.11 > burn_cap
		and a.state_ids.has(XTianqiElementEffects.ST_BURN)
		and int(a.state_turns.get(XTianqiElementEffects.ST_BURN, 0)) == 3 and is_equal_approx(burn_tick, burn_cap),
		[a.hp, r_cap.hp_loss, burn_tick, burn_cap])
	# 寄生：回合末扣我方血，并给敌方血量比例最低者回等量血
	a.recover_all()
	var lpar := _normal_logic(s)
	var ep: XEnemy = lpar.enemies[0]
	ep.hp = floorf(ep.mhp * 0.5)
	var ep_hp0 := ep.hp
	_hit(lpar, ep, _stub(98611, 6, "500"), a)
	var a_hp0 := a.hp
	var par_logs := []
	XTianqiElementEffects.tick_dot(lpar, a, par_logs)
	var par_lost := a_hp0 - a.hp
	_check("b2_enemy_parasite_heals_lowest_enemy", a.state_ids.has(XTianqiElementEffects.ST_PARASITE) and par_lost > 0.0
		and is_equal_approx(ep.hp - ep_hp0, minf(par_lost, ep.mhp - ep_hp0)), [par_lost, ep.hp - ep_hp0])
	# 其余减益共用接口：浸湿 out_mult、遮蔽锋芒 crit_mult、碎甲、乱流、魔蚀
	var lrest := _normal_logic(s)
	var er: XEnemy = lrest.enemies[0]
	a.recover_all()
	for el in [4, 7, 9, 14, 15]:
		_hit(lrest, er, _stub(98612 + el, el, "200"), a)
	_check("b2_enemy_debuffs_shared_interface", a.state_ids.has(XTianqiElementEffects.ST_SHATTER)
		and a.state_ids.has(XTianqiElementEffects.ST_ARCANE) and a.state_ids.has(XTianqiElementEffects.ST_VEIL)
		and a.state_ids.has(XTianqiElementEffects.ST_SOAK) and a.state_ids.has(XTianqiElementEffects.ST_GUST)
		and is_equal_approx(XTianqiElementEffects.out_mult(a), 0.89)
		and is_equal_approx(XTianqiElementEffects.crit_mult(a, 2.0), 1.67))
	# 共用事件契约（敌打我方多段＋护盾全吸不计基数）
	var lcon := _normal_logic(s)
	var econ: XEnemy = lcon.enemies[0]
	b.recover_all()
	XTianqiElementEffects.frame_begin(lcon, econ)
	var d1 := lcon.apply(econ, _stub(98630, 2, "100"), b)
	b.shield = 99999999.0
	var d2 := lcon.apply(econ, _stub(98631, 2, "500"), b)
	b.shield = 0.0
	var d3 := lcon.apply(econ, _stub(98632, 4, "100"), b)
	XTianqiElementEffects.frame_end(lcon, econ)
	var b_tick := float(lcon.get_meta(XTianqiElementEffects.META).units.get(b, {}).get("dot", {}).get("burn", {}).get("tick", -1.0))
	var b_want := minf(floorf(float(d1.hp_loss) * 0.11), floorf(b.mhp * 0.05))
	_check("b2_enemy_contract_multi_segment_and_shield", float(d2.hp_loss) == 0.0 and _st(lcon, 2, "eligible") == 1
		and _st(lcon, 4, "eligible") == 1 and b.state_ids.has(XTianqiElementEffects.ST_BURN)
		and b.state_ids.has(XTianqiElementEffects.ST_SHATTER) and is_equal_approx(b_tick, b_want), [d1.hp_loss, d2.hp_loss, b_tick, b_want])
	# ② 我方体质免疫与增幅（§4.4）：火/地/水免灼烧、自然受灼烧 ×1.5（仍封顶）、地/雷免麻痹和感电、水首次迟缓即冻（每场仅 1 次）、圣/暗免遮蔽锋芒、不读种族
	var lnat := _normal_logic(s)
	var enat: XEnemy = lnat.enemies[0]
	a.recover_all()
	_actor_natures({a.actor_id: [2]})
	_hit(lnat, enat, _stub(98635, 2, "200"), a)
	_hit(lnat, enat, _stub(98636, 3, "200"), a)
	var fire_imm := not a.state_ids.has(XTianqiElementEffects.ST_BURN) and not a.state_ids.has(XTianqiElementEffects.ST_SLOW) and _st(lnat, 2, "immune") == 1 and _st(lnat, 3, "immune") == 1
	_actor_natures({a.actor_id: [6]})
	var r_nat := _hit(lnat, enat, _stub(98637, 2, "80"), a)
	var nat_tick := float(lnat.get_meta(XTianqiElementEffects.META).units.get(a, {}).get("dot", {}).get("burn", {}).get("tick", 0.0))
	a.recover_all()
	var lnat2 := _normal_logic(s)
	_actor_natures({a.actor_id: []})
	var r_plain := _hit(lnat2, lnat2.enemies[0], _stub(98638, 2, "80"), a)
	var plain_tick := float(lnat2.get_meta(XTianqiElementEffects.META).units.get(a, {}).get("dot", {}).get("burn", {}).get("tick", 0.0))
	var nat_boost_ok := nat_tick > plain_tick and is_equal_approx(nat_tick, minf(floorf(floorf(float(r_nat.hp_loss) * 0.11) * 1.5), floorf(a.mhp * 0.05)))
	# 地体质：免麻痹也免首领感电；圣体质：免遮蔽锋芒；不读种族
	var lboss := _boss_logic(s)
	a.recover_all()
	_actor_natures({a.actor_id: [4]})
	_hit(lnat2, lnat2.enemies[0], _stub(98639, 5, "200"), a)
	_hit(lboss, lboss.enemies[0], _stub(98640, 5, "200"), a)
	var earth_imm_shock := not a.state_ids.has(XTianqiElementEffects.ST_PARALYZE) and not a.state_ids.has(XTianqiElementEffects.ST_SHOCK)
	_actor_natures({a.actor_id: [8]})
	_hit(lnat2, lnat2.enemies[0], _stub(98641, 9, "200"), a)
	var holy_imm_veil := not a.state_ids.has(XTianqiElementEffects.ST_VEIL)
	# 水体质我方：普通怪首次迟缓即冰冻，且每场最多冻 1 次（第 2 次退回迟缓）
	var lw := _normal_logic(s)
	var ew: XEnemy = lw.enemies[0]
	b.recover_all()
	_actor_natures({b.actor_id: [14]})
	_hit(lw, ew, _stub(98642, 3, "200"), b)
	var w_froze1 := b.state_ids.has(XTianqiElementEffects.ST_FREEZE)
	lw.act(b, b.attack_skill(), ew)
	for i in 5:
		lw.act(b, b.attack_skill(), ew)
	lw.turn += 3
	_hit(lw, ew, _stub(98643, 3, "200"), b)
	var w_slow2 := not b.state_ids.has(XTianqiElementEffects.ST_FREEZE) and b.state_ids.has(XTianqiElementEffects.ST_SLOW)
	# 转换书不改我方体质（§4.4）：无体质角色装火转换书，照样吃灼烧
	var lcv := _normal_logic(s)
	a.recover_all()
	_actor_natures({a.actor_id: []})
	var pc: Dictionary = a.passive_cache()
	var old_conv := int(pc.get("damageElement", 0))
	pc["damageElement"] = 2
	_hit(lcv, lcv.enemies[0], _stub(98644, 2, "200"), a)
	a.passive_cache()["damageElement"] = old_conv
	var conv_no_imm := a.state_ids.has(XTianqiElementEffects.ST_BURN) and XTianqiNature.races(a).is_empty()
	_check("b2_actor_nature_immunity_boost_and_no_conv", fire_imm and nat_boost_ok and earth_imm_shock and holy_imm_veil
		and w_froze1 and w_slow2 and conv_no_imm, [fire_imm, nat_boost_ok, earth_imm_shock, holy_imm_veil, w_froze1, w_slow2, conv_no_imm])


## B2（T485）：§4.4 我方判定顺序（硬免疫 → 体质 → 状态有效度 → 停手类六维韧性只乘一次）、必中不绕过、§3.6 我方行动位跳过与冷却
func _test_b2_actor_judgment_and_slots() -> void:
	_reset()
	_force()
	var s := _tq_state()
	var mem: Array = s.battle_members()
	var a: XActor = mem[0]
	var b: XActor = mem[1]
	_natures({})
	_actor_natures({})
	var st: Array = XDB.table("States")
	# ① 硬免疫（装备／被动 TRAIT_STATE_RESIST）＋必中（hitType == 0）不绕过；且硬免疫先于体质免疫（记 blocked 不记 immune）
	var lg := _normal_logic(s)
	var e: XEnemy = lg.enemies[0]
	var res_id := st.size()
	st.append({"id": res_id, "name": "T485硬免灼伤", "traits": [{"code": XBattler.TRAIT_STATE_RESIST, "dataId": 17, "value": 1.0}],
		"note": "", "meta": {}, "iconIndex": 0, "restriction": 0, "autoRemovalTiming": 0, "removeAtBattleEnd": true})
	a.recover_all()
	a.add_state(res_id)
	_actor_natures({a.actor_id: [2]})  # 同时有火体质，验硬免疫在体质之前
	var sure_fire := _stub(98650, 2, "200")
	sure_fire.hitType = 0  # 必中
	_hit(lg, e, sure_fire, a)
	var hard_first := not a.state_ids.has(XTianqiElementEffects.ST_BURN) and _st(lg, 2, "blocked") == 1 and _st(lg, 2, "immune") == 0
	a.remove_state(res_id)
	st.pop_back()
	# ② 状态有效度 0% 挡住、不耗冷却
	var rate0_id := st.size()
	st.append({"id": rate0_id, "name": "T485有效度0", "traits": [{"code": XBattler.TRAIT_STATE_RATE, "dataId": 100, "value": 0.0}],
		"note": "", "meta": {}, "iconIndex": 0, "restriction": 0, "autoRemovalTiming": 0, "removeAtBattleEnd": true})
	_actor_natures({})
	var lg2 := _normal_logic(s)
	var e2: XEnemy = lg2.enemies[0]
	a.recover_all()
	a.add_state(rate0_id)
	var sure_par := _stub(98651, 5, "200")
	sure_par.hitType = 0
	_hit(lg2, e2, sure_par, a)
	var rate0_blocked := not a.state_ids.has(XTianqiElementEffects.ST_PARALYZE) and _st(lg2, 5, "blocked") == 1 and _st(lg2, 5, "rolled") == 0
	a.remove_state(rate0_id)
	st.pop_back()
	# 撤掉 0% 有效度后同回合可挂（证明上次没耗冷却）
	_hit(lg2, e2, sure_par, a)
	var no_cd_after_rate0 := a.state_ids.has(XTianqiElementEffects.ST_PARALYZE)
	_check("b2_actor_hard_immune_order_sure_hit_and_state_rate0", hard_first and rate0_blocked and no_cd_after_rate0,
		[hard_first, rate0_blocked, no_cd_after_rate0])
	# ③ 六维韧性只乘一次且仅管停手类（E＝×1.10，SSS＝×0.90）：用确定性子流首值检验边界
	_reset()
	_actor_natures({})
	var old_sd := XTianqiSixDim._data.duplicate(true)
	var sd := XTianqiSixDim.data().duplicate(true)
	if not sd.has("actors"):
		sd["actors"] = {}
	sd.actors[str(a.actor_id)] = {"output": "C", "survive": "C", "speed": "C", "wit": "C", "resolve": "E", "support": "C"}
	sd.actors[str(b.actor_id)] = {"output": "C", "survive": "C", "speed": "C", "wit": "C", "resolve": "SSS", "support": "C"}
	XTianqiSixDim._data = sd
	var r_e := XTianqiSixDim.control_state_rate(a, XTianqiElementEffects.ST_PARALYZE, lg2)
	var r_sss := XTianqiSixDim.control_state_rate(b, XTianqiElementEffects.ST_PARALYZE, lg2)
	# 选固定种子使 u0 落在 (0.2, 0.85)，四场共用同一个 seed_i
	var seed_i := 48500
	var lres_e := XBattleLogic.new()
	lres_e.setup(_plain_troop, s, XBattleRandom.create(XRandomStream.hex64(seed_i)))
	var u0: float = XRandomStream.create(XTianqiElementEffects.seed_of(lres_e), "elem_effects").next_float("tianqi_elem_effect", "5")
	while u0 < 0.2 or u0 > 0.85:
		seed_i += 1
		lres_e = XBattleLogic.new()
		lres_e.setup(_plain_troop, s, XBattleRandom.create(XRandomStream.hex64(seed_i)))
		u0 = XRandomStream.create(XTianqiElementEffects.seed_of(lres_e), "elem_effects").next_float("tianqi_elem_effect", "5")
	var lres_sss := XBattleLogic.new()
	lres_sss.setup(_plain_troop, s, XBattleRandom.create(XRandomStream.hex64(seed_i)))
	var lres_once := XBattleLogic.new()
	lres_once.setup(_plain_troop, s, XBattleRandom.create(XRandomStream.hex64(seed_i)))
	var lres_shat := XBattleLogic.new()
	lres_shat.setup(_plain_troop, s, XBattleRandom.create(XRandomStream.hex64(seed_i)))
	# case A: base = u0 / 0.95 → E: u0*1.10/0.95 > u0 (必中); SSS: u0*0.90/0.95 < u0 (必不中)
	XTianqiElements.data().enemy_effect_rules.base_chance = u0 / 0.95
	a.recover_all()
	b.recover_all()
	_hit(lres_e, lres_e.enemies[0], _stub(98652, 5, "200"), a)
	_hit(lres_sss, lres_sss.enemies[0], _stub(98653, 5, "200"), b)
	var e_hit_sss_miss := a.state_ids.has(XTianqiElementEffects.ST_PARALYZE) and not b.state_ids.has(XTianqiElementEffects.ST_PARALYZE)
	# case B（验只乘一次不乘两次）: base = u0 / 0.85 → SSS 乘一次＝0.90/0.85*u0 > u0 (必中)；若误乘两次＝0.81/0.85*u0 < u0 (会不中)
	XTianqiElements.data().enemy_effect_rules.base_chance = u0 / 0.85
	b.recover_all()
	_hit(lres_once, lres_once.enemies[0], _stub(98654, 5, "200"), b)
	var sss_mult_once := b.state_ids.has(XTianqiElementEffects.ST_PARALYZE)
	# case C（非停手类碎甲不吃六维韧性）: 取 elem 4 的 u4，设 base = u4 / 0.95 → SSS 若误吃 0.90 会落空，不吃则 1/0.95*u4 > u4 必中
	var u4: float = XRandomStream.create(XTianqiElementEffects.seed_of(lres_shat), "elem_effects").next_float("tianqi_elem_effect", "4")
	var base4 := (u4 / 0.95) if u4 > 0.05 else 0.5
	XTianqiElements.data().enemy_effect_rules.base_chance = minf(1.0, base4)
	b.recover_all()
	_hit(lres_shat, lres_shat.enemies[0], _stub(98655, 4, "200"), b)
	var shatter_no_resolve := b.state_ids.has(XTianqiElementEffects.ST_SHATTER)
	XTianqiSixDim._data = old_sd
	_check("b2_actor_six_dim_resolve_once_stop_only", is_equal_approx(r_e, 1.1) and is_equal_approx(r_sss, 0.9)
		and e_hit_sss_miss and sss_mult_once and shatter_no_resolve, [r_e, r_sss, e_hit_sss_miss, sss_mult_once, shatter_no_resolve])
	# ④ §3.6 我方行动位跳过（只跳一位、同回合第二位照常、pending_skip 同步、5 次共用冷却）
	_reset()
	_force()
	_actor_natures({})
	var lsl := _normal_logic(s)
	var esl: XEnemy = lsl.enemies[0]
	a.recover_all()
	_hit(lsl, esl, _stub(98656, 5, "200"), a)
	var pend_before := XTianqiElementEffects.pending_skip(lsl, a)
	var la1 := lsl.act(a, a.attack_skill(), esl)
	var pend_after := XTianqiElementEffects.pending_skip(lsl, a)
	var la2 := lsl.act(a, a.attack_skill(), esl)
	_check("b2_actor_stop_slot_only_one_lost", pend_before and not pend_after and _skip_logs(la1) and not _skip_logs(la2)
		and XTianqiElementEffects.skip_count(lsl, a) == 1)


## B2（T485）：§5.3 敌方几率与施效预算（普通一次最多 1 停手、精英／化形每场同角最多 2 停手、首领每行动最多 1 效果／麻痹换感电＋实伤 +11%／不冻我方／首领一侧圣护每场 3 次）
func _test_b2_enemy_budgets_and_holy() -> void:
	_reset()
	var s := _tq_state()
	var mem: Array = s.battle_members()
	var a: XActor = mem[0]
	var b: XActor = mem[1]
	var c: XActor = mem[2]
	_natures({})
	_actor_natures({})
	# ① 敌方默认基准几率 11%（不套我方 22% 档）
	_check("b2_enemy_default_chance_11pct", is_equal_approx(float(XTianqiElements.data().enemy_effect_rules.base_chance), 0.11))
	_force()
	# ② 普通怪：群体雷打 3 人最多 1 人被麻痹；群体冰打 2 个浸湿目标最多 1 人冰冻、第 2 人退回迟缓
	var ln := _normal_logic(s)
	var en: XEnemy = ln.enemies[0]
	en.elite = false
	for m in [a, b, c]:
		m.recover_all()
	XTianqiElementEffects.frame_begin(ln, en)
	for m in [a, b, c]:
		ln.apply(en, _stub(98660, 5, "200", 1, 2), m)
	XTianqiElementEffects.frame_end(ln, en)
	var par_cnt := [a, b, c].filter(func(m): return m.state_ids.has(XTianqiElementEffects.ST_PARALYZE)).size()
	_check("b2_normal_enemy_max_1_stop_per_action", par_cnt == 1, par_cnt)
	var ln2 := _normal_logic(s)
	var en2: XEnemy = ln2.enemies[0]
	en2.elite = false
	for m in [a, b]:
		m.recover_all()
		ln2._state_add(m, XTianqiElementEffects.ST_SOAK)
	XTianqiElementEffects.frame_begin(ln2, en2)
	ln2.apply(en2, _stub(98661, 3, "200", 1, 2), a)
	ln2.apply(en2, _stub(98661, 3, "200", 1, 2), b)
	XTianqiElementEffects.frame_end(ln2, en2)
	_check("b2_normal_enemy_aoe_ice_1_freeze_1_slow", a.state_ids.has(XTianqiElementEffects.ST_FREEZE)
		and not b.state_ids.has(XTianqiElementEffects.ST_FREEZE) and b.state_ids.has(XTianqiElementEffects.ST_SLOW))
	# ③ 精英／化形：每场对同一角色最多 2 次停手（第 3 次落空；另一角色仍可被停手）
	var le := _normal_logic(s)
	var ee: XEnemy = le.enemies[0]
	ee.elite = true
	var elite_pred := XTianqiElementEffects.effect_elite(le, ee)
	a.recover_all()
	b.recover_all()
	var got_stops := []
	for round_i in 3:
		_hit(le, ee, _stub(98662 + round_i, 5, "200"), a)
		got_stops.append(a.state_ids.has(XTianqiElementEffects.ST_PARALYZE))
		if a.state_ids.has(XTianqiElementEffects.ST_PARALYZE):
			le.act(a, a.attack_skill(), ee)  # 吃位
			for k in 5:
				le.act(a, a.attack_skill(), ee)  # 走完 5 次共用冷却
		le.turn += 3
	_hit(le, ee, _stub(98666, 5, "200"), b)
	_check("b2_elite_max_2_stops_per_actor", elite_pred and got_stops == [true, true, false]
		and b.state_ids.has(XTianqiElementEffects.ST_PARALYZE), [elite_pred, got_stops, b.state_ids])
	# ④ 首领（含终焉）：每次行动最多 1 个新效果；被体质免疫的目标不占预算，下一人照挂
	var lb := _boss_logic(s)
	var boss: XEnemy = lb.enemies[0]
	for m in [a, b, c]:
		m.recover_all()
	_actor_natures({a.actor_id: [2], b.actor_id: [], c.actor_id: []})
	XTianqiElementEffects.frame_begin(lb, boss)
	for m in [a, b, c]:
		lb.apply(boss, _stub(98670, 2, "300", 1, 2), m)
	XTianqiElementEffects.frame_end(lb, boss)
	_check("b2_boss_per_action_cap_1_immune_free", not a.state_ids.has(XTianqiElementEffects.ST_BURN)
		and b.state_ids.has(XTianqiElementEffects.ST_BURN) and not c.state_ids.has(XTianqiElementEffects.ST_BURN),
		[a.state_ids.has(XTianqiElementEffects.ST_BURN), b.state_ids.has(XTianqiElementEffects.ST_BURN), c.state_ids.has(XTianqiElementEffects.ST_BURN)])
	# 首领雷打我方：一律换软版「感电」（1 回合，且实伤真 +11%），不挂麻痹
	_actor_natures({})
	var lb2 := _boss_logic(s)
	var boss2: XEnemy = lb2.enemies[0]
	a.recover_all()
	var dmg_sk := _stub(98671, 0, "1000")
	var d_before := float(XDamage.calculate(dmg_sk, boss2, a, {"variance": false, "tianqi_logic": lb2}).value)
	_hit(lb2, boss2, _stub(98672, 5, "300"), a)
	var d_after := float(XDamage.calculate(dmg_sk, boss2, a, {"variance": false, "tianqi_logic": lb2}).value)
	_check("b2_boss_thunder_gives_shock_plus_11pct", a.state_ids.has(XTianqiElementEffects.ST_SHOCK)
		and not a.state_ids.has(XTianqiElementEffects.ST_PARALYZE)
		and int(a.state_turns.get(XTianqiElementEffects.ST_SHOCK, 0)) == 1
		and is_equal_approx(d_after, roundf(d_before * 1.11)), [d_before, d_after, a.state_turns.get(XTianqiElementEffects.ST_SHOCK)])
	# 首领冰打我方：水体质＋浸湿也不冻，只挂迟缓（2 回合）
	var lb3 := _boss_logic(s)
	var boss3: XEnemy = lb3.enemies[0]
	b.recover_all()
	_actor_natures({b.actor_id: [14]})
	lb3._state_add(b, XTianqiElementEffects.ST_SOAK)
	_hit(lb3, boss3, _stub(98673, 3, "300"), b)
	_check("b2_boss_ice_never_freezes_actor", not b.state_ids.has(XTianqiElementEffects.ST_FREEZE)
		and b.state_ids.has(XTianqiElementEffects.ST_SLOW)
		and int(b.state_turns.get(XTianqiElementEffects.ST_SLOW, 0)) == 2)
	# ⑤ 敌方圣护镜像（§3.5）：对敌打我方给施放敌人自己、对己方用 680 圣光术给目标敌人、盾挡我方减益、首领一侧每场最多 3 次
	_actor_natures({})
	var H := XTianqiElementEffects.ST_HOLY
	var lh := _boss_logic(s)
	var hb: XEnemy = lh.enemies[0]
	a.recover_all()
	lh._state_add(hb, 12)
	_hit(lh, hb, _stub(98674, 8, "300"), a)
	var got1 := hb.state_ids.has(H) and not hb.state_ids.has(12) and not a.state_ids.has(H)
	# 敌方圣护盾挡我方施加的减益
	XImportedBalance.set_acting(a)
	hb.add_state(12)
	XImportedBalance.set_acting(null)
	var enemy_shield_blocked := not hb.state_ids.has(12) and not hb.state_ids.has(H)
	# 敌方对己方用 680 圣光术给目标圣护，并且首领一侧每场最多 3 次（前面已 1 次，再中 2 次到顶，第 4 次落空）
	var sk680 := XDB.rec("Skills", 680)
	var holy_seq := [got1]
	for k in 3:
		hb.remove_state(H)
		XTianqiElementEffects.end_turn(lh)
		lh.turn += 3
		_hit(lh, hb, sk680, hb)
		holy_seq.append(hb.state_ids.has(H))
	_check("b2_enemy_holy_mirror_and_boss_cap_3", enemy_shield_blocked and holy_seq == [true, true, true, false],
		[enemy_shield_blocked, holy_seq, lh.get_meta(XTianqiElementEffects.META).get("holy_boss")])
	# 敌方圣体质按 by_nature 放非白名单治疗技（906 治愈之歌）也触发圣护；普通怪没有首领 3 次上限
	var ln_h := _normal_logic(s)
	var eh: XEnemy = ln_h.enemies[0]
	_natures({eh.enemy_id: [8]})
	var sk906 := XDB.rec("Skills", 906)
	var nat_holy_ok := XTianqiElementEffects.holy_ally_skill(sk906, eh)
	eh.remove_state(H)
	_hit(ln_h, eh, sk906, eh)
	var got_by_nat := eh.state_ids.has(H)
	_natures({eh.enemy_id: []})
	var no_nat_holy := not XTianqiElementEffects.holy_ally_skill(sk906, eh)
	_check("b2_enemy_holy_by_nature_ally_skill", nat_holy_ok and got_by_nat and no_nat_holy, [nat_holy_ok, got_by_nat, no_nat_holy])


## B2（T485）：D285③ 高等三系不扩到敌打我方；开关关与西游档敌打我方零改动
func _test_b2_higher_no_expand_and_guard() -> void:
	_reset()
	_force()
	var s := _tq_state()
	var a: XActor = s.battle_members()[0]
	_natures({})
	_actor_natures({})
	var lg := _normal_logic(s)
	var e: XEnemy = lg.enemies[0]
	var bad := []
	for h in [11, 12, 13]:
		a.recover_all()
		var r := _hit(lg, e, _stub(98680 + h, h, "300"), a)
		if bool(r.get("void_engulfed", false)) or float(r.get("space_erosion", 0.0)) > 0.0:
			bad.append(["higher_proc", h])
		var row: Dictionary = r.get("best_row", {})
		if not is_equal_approx(float(row.get("resistance", -1.0)), a.element_rate(h)):
			bad.append(["rate", h, row.get("resistance"), a.element_rate(h)])
	var any_st := XTianqiElementEffects.STATE_IDS.any(func(id): return a.state_ids.has(id))
	_check("b2_higher_not_expanded_enemy_to_actor", bad.is_empty() and not any_st and XTianqiElementEffects.stats(lg).is_empty(),
		[bad, XTianqiElementEffects.stats(lg)])
	# 回退开关（EFFECTS = false）与子流隔离：敌打我方时开关关不建 meta、主流一致
	var snaps := []
	for mode in ["off", "on0"]:
		_reset()
		if mode == "off":
			XTianqiElements.EFFECTS = false
		_force(0.0, 0.0)
		a.recover_all()
		var lsw := XBattleLogic.new()
		lsw.setup(_plain_troop, s, XBattleRandom.create(XRandomStream.hex64(4851234)))
		var esw: XEnemy = lsw.enemies[0]
		esw.recover_all()
		lsw.execute(esw, _stub(98690, 5, "200"), a)
		lsw.execute(esw, _stub(98691, 2, "200"), a)
		snaps.append([JSON.stringify(lsw.random.rule.snapshot()), a.hp, lsw.has_meta(XTianqiElementEffects.META)])
	_check("b2_switch_off_enemy_to_actor_identical", snaps[0][0] == snaps[1][0] and is_equal_approx(float(snaps[0][1]), float(snaps[1][1]))
		and not snaps[0][2] and snaps[1][2], [snaps[0][1], snaps[1][1], snaps[0][2], snaps[1][2]])
	# 西游档敌打我方零改动
	_reset()
	_force()
	var w := XState.new_game_blank()
	w.difficulty = 3
	w.add_actor(1)
	w.map_id = 4
	XState.current = w
	var wa: XActor = w.battle_members()[0]
	wa.recover_all()
	var lw := XBattleLogic.new()
	lw.setup(_plain_troop, w)
	var we: XEnemy = lw.enemies[0]
	we.recover_all()
	lw.execute(we, _stub(98692, 5, "50"), wa)
	lw.execute(we, _stub(98693, 2, "50"), wa)
	lw.execute(we, _stub(98694, 8, "50"), wa)
	_check("b2_west_save_enemy_to_actor_untouched", not lw.has_meta(XTianqiElementEffects.META)
		and not XTianqiElementEffects.STATE_IDS.any(func(id): return wa.state_ids.has(id) or we.state_ids.has(id)))


