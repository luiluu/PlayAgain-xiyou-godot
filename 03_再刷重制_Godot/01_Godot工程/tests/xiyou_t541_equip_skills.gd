extends Node
## 【小A·未经审查】T541 漏改写的装备主动招 4 个（3624/1968/3549/995）＋baseline_dps._clone 深拷贝＋西游档零改动专项：
## 1) 四招逐招新旧对照（天启篇改写后 vs 关闭 XTianqiSkills 改写前的原版公式，同角色、同装备、同敌、同种子）：
##    - 3624 三眼神光*极（Armor 3774 天眼之冠 <ShareLearnSkill:3624>）：3 段 mat×1（合计 3），耗魔 10%、冷却 3
##    - 1968 极寒之触（Weapon 1371 蒂阿兹之石 <Replace Attack: 1968>）：1 段 mat×1，0 蓝耗可用，保留冰冷V(26)与冰封血脉(72)
##    - 3549 白夜叉（Weapon 1539 洞爷湖 特性 43）：6 段 atk/agi 各×25%（合计 3），清末段全体，耗 TP 35、冷却 3
##    - 995 汲血斩（Weapon 1105 尸山血海 <Replace Attack: 995>）：2 段 atk×50%（合计 1），去血月条件段与固定回 500 血
## 2) baseline_dps._clone 深拷贝夹具：克隆后对副本执行 _relineup（卸装＋重配）不得串改原状态或其他副本的 equips/gear/flags。
## 3) 西游档零改动回归：四招在西游档保留原版公式、原版消耗、原版段数与无额外冷却。

const BaselineDps = preload("res://tests/virtual_player/baseline_dps.gd")

var passed := 0
var total := 0


func _ready() -> void:
	_run.call_deferred()


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func _make_tianqi(lineup: Array, floor_no := 25) -> XState:
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		if not s.party.has(int(id)):
			XTianqi._joining = true
			s.add_actor(int(id))
			XTianqi._joining = false
	s.battle_slots = [0, 0, 0, 0]
	for i in range(mini(4, lineup.size())):
		s.battle_slots[i] = int(lineup[i])
	s.set_variable(20, floor_no)
	s.map_id = 4
	XState.current = s
	return s


func _make_xiyou(actor_ids: Array, floor_no := 25) -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	s.set_variable(20, floor_no)
	s.party = []
	s.battle_slots = [0, 0, 0, 0]
	for i in range(actor_ids.size()):
		var aid := int(actor_ids[i])
		s.actor(aid)
		s.party.append(aid)
		if i < 4:
			s.battle_slots[i] = aid
	return s


func _equip_armor(a: XActor, armor_id: int) -> Dictionary:
	var item := XGear.template("armor", armor_id)
	var slots := a.equip_slots()
	var idx := slots.find(int(item.get("etypeId", 0)))
	if idx >= 0:
		if a.equips.size() < slots.size():
			a.equips.resize(slots.size())
		a.equips[idx] = item
	return item


func _equip_weapon(a: XActor, weapon_id: int) -> Dictionary:
	var item := XGear.template("weapon", weapon_id)
	var slots := a.equip_slots()
	var idx := slots.find(1)
	if idx >= 0:
		if a.equips.size() < slots.size():
			a.equips.resize(slots.size())
		a.equips[idx] = item
	return item


func _make_dummy_battle(s: XState, troop_id := 2, seed_hex := "0000000000000541") -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.elite_roll = 100.0
	lg.setup(troop_id, s, XBattleRandom.create(seed_hex))
	for e in lg.enemies:
		e.add_param(0, 1e9)
		e.param_refresh()
		e.hp = e.mhp
	lg.start_turn()
	return lg


func _sum_hits(logs: Array, target: XEnemy = null) -> Dictionary:
	var dmg := 0.0
	var count := 0
	var added_states := []
	for r in logs:
		if r is Dictionary and r.get("type") == "hit":
			if target != null and not is_same(r.get("target"), target):
				continue
			count += 1
			dmg += maxf(0.0, float(r.get("hp", 0.0)))
			for st in r.get("added", []):
				if not added_states.has(int(st)):
					added_states.append(int(st))
	return {"hits": count, "dmg": dmg, "added": added_states}


func _cast_compare(skill_id: int, setup_fn: Callable, seed_hex: String, troop_id := 2) -> Dictionary:
	# 旧口径：临时关闭 XTianqiSkills.ENABLED 测原版公式（同角色、同装备、同敌、同种子）
	var was_en := XTianqiSkills.ENABLED
	XTianqiSkills.ENABLED = false
	XTianqiSkills.reload_table()
	var s_old := _make_tianqi([3, 1, 2, 4], 25)
	var a_old: XActor = setup_fn.call(s_old)
	var lg_old := _make_dummy_battle(s_old, troop_id, seed_hex)
	var sk_old := XDB.rec("Skills", skill_id)
	var logs_old := lg_old.act(a_old, sk_old, lg_old.enemies[0])
	var res_old := _sum_hits(logs_old, lg_old.enemies[0])

	# 新口径：开启 XTianqiSkills.ENABLED 测改写后公式
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()
	var s_new := _make_tianqi([3, 1, 2, 4], 25)
	var a_new: XActor = setup_fn.call(s_new)
	var lg_new := _make_dummy_battle(s_new, troop_id, seed_hex)
	var sk_new := XDB.rec("Skills", skill_id)
	var hp_before_new := a_new.hp
	var mp_before_new := a_new.mp
	var tp_before_new := a_new.tp
	var logs_new := lg_new.act(a_new, sk_new, lg_new.enemies[0])
	var res_new := _sum_hits(logs_new, lg_new.enemies[0])
	var res_new_all := _sum_hits(logs_new, null)
	var other_dmg := 0.0
	for i in range(1, lg_new.enemies.size()):
		other_dmg += _sum_hits(logs_new, lg_new.enemies[i]).dmg

	XTianqiSkills.ENABLED = was_en
	XTianqiSkills.reload_table()
	return {
		"old": res_old,
		"new": res_new,
		"new_all": res_new_all,
		"other_dmg": other_dmg,
		"sk_old": sk_old,
		"sk_new": sk_new,
		"actor_new": a_new,
		"enemy0_new": lg_new.enemies[0],
		"lg_new": lg_new,
		"hp_delta": a_new.hp - hp_before_new,
		"mp_delta": mp_before_new - a_new.mp,
		"tp_delta": tp_before_new - a_new.tp,
	}


func _run() -> void:
	var was_en := XTianqiSkills.ENABLED
	var was_force := XEnemy.force_roll
	var was_auto := XMessageBox.auto
	XEnemy.force_roll = 100.0
	XMessageBox.auto = true
	XTianqiSkills.ENABLED = true
	XTianqiSkills.reload_table()

	_test_skill_3624()
	_test_skill_1968()
	_test_skill_3549()
	_test_skill_995()
	_test_baseline_dps_clone_deep_copy()
	_test_xiyou_untouched()

	XTianqiSkills.ENABLED = was_en
	XTianqiSkills.reload_table()
	XEnemy.force_roll = was_force
	XMessageBox.auto = was_auto
	XState.current = null
	print("TEST_RESULT=" + JSON.stringify({"test": "xiyou_t541_equip_skills", "passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


const SEEDS := ["0000000000000001", "0000000000000002", "0000000000000003"]


func _cast_compare_3seeds(skill_id: int, setup_fn: Callable, troop_id := 2) -> Dictionary:
	var per_seed := []
	var last := {}
	for idx in SEEDS.size():
		var cmp := _cast_compare(skill_id, setup_fn, SEEDS[idx], troop_id)
		per_seed.append({
			"seed": idx + 1,
			"old_dmg": cmp.old.dmg,
			"old_hits": cmp.old.hits,
			"new_dmg": cmp.new.dmg,
			"new_hits": cmp.new.hits,
			"other_dmg": cmp.other_dmg,
			"hp_delta": cmp.hp_delta,
		})
		print("T541_SEED skill=%d seed=%d old_dmg=%.1f old_hits=%d new_dmg=%.1f new_hits=%d other_dmg=%.1f hp_delta=%.1f ratio=%.2fx" % [
			skill_id, idx + 1, cmp.old.dmg, cmp.old.hits, cmp.new.dmg, cmp.new.hits, cmp.other_dmg, cmp.hp_delta,
			cmp.old.dmg / maxf(1.0, cmp.new.dmg)])
		last = cmp
	last["per_seed"] = per_seed
	return last


func _test_skill_3624() -> void:
	var setup := func(s: XState) -> XActor:
		var a: XActor = s.actor(3)
		a.change_level(75)
		_equip_armor(a, 3774)  # 天眼之冠 <ShareLearnSkill:3624>
		a.refresh_passive()
		XPartySkills.finish(s)
		a.recover_all()
		return a

	var cmp := _cast_compare_3seeds(3624, setup)
	var a_new: XActor = cmp.actor_new
	var sk_new: Dictionary = cmp.sk_new

	check("t541.3624.in_skill_rework", XTianqiSkills.has(3624), sk_new.get("damage"))
	check("t541.3624.shared_learned", a_new.skills().any(func(k): return int(k.get("id", 0)) == 3624))
	check("t541.3624.module_formula", str(sk_new.get("damage", {}).get("formulaProgram", {}).get("module", "")) == "tianqi_skill", sk_new.get("damage"))
	check("t541.3624.cost_cd_desc",
		int(sk_new.get("mpCost", -1)) == 0
		and str(sk_new.get("note", "")).contains("<MP Cost: 10%>")
		and str(sk_new.get("note", "")).contains("<Cooldown: 3>")
		and not str(sk_new.get("note", "")).contains("1375+"),
		{"mpCost": sk_new.get("mpCost"), "cd": a_new.cooldowns.get(3624, 0)})
	check("t541.3624.three_hits_and_cd_applied",
		int(cmp.new.hits) == 3 and float(a_new.cooldowns.get(3624, 0.0)) >= 3.0 and float(cmp.mp_delta) > 0.0,
		{"hits": cmp.new.hits, "cd": a_new.cooldowns.get(3624, 0.0), "mp_delta": cmp.mp_delta})
	check("t541.3624.all_3seeds_reworked_far_below_old",
		(cmp.per_seed as Array).all(func(r): return int(r.new_hits) == 3 and float(r.new_dmg) > 0.0 and float(r.old_dmg) > float(r.new_dmg) * 10.0),
		cmp.per_seed)


func _test_skill_1968() -> void:
	var setup := func(s: XState) -> XActor:
		# 45 东方教主（同 r6 22 层实测角色）可装备 wtype 3 杖类 1371 蒂阿兹之石
		if not s.party.has(45):
			XTianqi._joining = true
			s.add_actor(45)
			XTianqi._joining = false
		s.battle_slots[0] = 45
		var a: XActor = s.actor(45)
		a.change_level(70)
		_equip_weapon(a, 1371)  # 蒂阿兹之石 <Replace Attack: 1968>
		a.refresh_passive()
		a.recover_all()
		return a

	var cmp := _cast_compare_3seeds(1968, setup)
	var a_new: XActor = cmp.actor_new
	var sk_new: Dictionary = cmp.sk_new
	var e0: XEnemy = cmp.enemy0_new
	var lg_new: XBattleLogic = cmp.lg_new

	check("t541.1968.in_skill_rework", XTianqiSkills.has(1968), sk_new.get("damage"))
	check("t541.1968.replaces_attack", a_new.attack_skill_id() == 1968, a_new.attack_skill_id())
	check("t541.1968.module_formula_zero_mp",
		str(sk_new.get("damage", {}).get("formulaProgram", {}).get("module", "")) == "tianqi_skill"
		and int(sk_new.get("mpCost", -1)) == 0 and int(sk_new.get("tpCost", -1)) == 0,
		{"mp": sk_new.get("mpCost"), "tp": sk_new.get("tpCost")})
	a_new.mp = 0.0
	check("t541.1968.usable_at_zero_mp", lg_new.can_use(a_new, sk_new), {"mp": a_new.mp, "mpCost": sk_new.get("mpCost")})
	check("t541.1968.yep1_and_states_preserved",
		int(sk_new.get("yepEffects", -1)) == 1 and int(cmp.new.hits) == int(cmp.old.hits) and int(cmp.new.hits) >= 1
		and e0.is_state_affected(72) and e0.is_state_affected(26),
		{"yepEffects": sk_new.get("yepEffects"), "hits": cmp.new.hits, "old_hits": cmp.old.hits, "states": e0.state_ids})
	check("t541.1968.all_3seeds_reworked_far_below_old",
		(cmp.per_seed as Array).all(func(r): return float(r.new_dmg) > 0.0 and float(r.old_dmg) > float(r.new_dmg) * 20.0),
		cmp.per_seed)


func _test_skill_3549() -> void:
	var setup := func(s: XState) -> XActor:
		var a: XActor = s.actor(3)
		a.change_level(75)
		_equip_weapon(a, 1539)  # 洞爷湖 trait 43 -> 3549
		a.refresh_passive()
		a.recover_all()
		a.tp = 100.0
		return a

	var cmp := _cast_compare_3seeds(3549, setup, 2)  # troop 2 有多只敌人，顺便验清末段全体
	var a_new: XActor = cmp.actor_new
	var sk_new: Dictionary = cmp.sk_new
	var lg_new: XBattleLogic = cmp.lg_new

	check("t541.3549.in_skill_rework", XTianqiSkills.has(3549), sk_new.get("damage"))
	check("t541.3549.granted_by_trait43", a_new.skills().any(func(k): return int(k.get("id", 0)) == 3549))
	check("t541.3549.module_tp_cd_hits",
		str(sk_new.get("damage", {}).get("formulaProgram", {}).get("module", "")) == "tianqi_skill"
		and int(sk_new.get("tpCost", -1)) == 35
		and int(sk_new.get("yepEffects", -1)) == 6
		and str(sk_new.get("note", "")).contains("<Cooldown: 3>"),
		{"tp": sk_new.get("tpCost"), "yepEffects": sk_new.get("yepEffects")})
	var cd_after := float(a_new.cooldowns.get(3549, 0.0))
	a_new.cooldowns.erase(3549)
	a_new.tp = 34.0
	var blocked_34 := not lg_new.can_use(a_new, sk_new)
	a_new.tp = 35.0
	var allowed_35 := lg_new.can_use(a_new, sk_new)
	check("t541.3549.six_hits_single_target_cd_and_tp35",
		int(cmp.new.hits) == 6 and is_equal_approx(float(cmp.other_dmg), 0.0)
		and cd_after >= 3.0 and blocked_34 and allowed_35,
		{"hits": cmp.new.hits, "other_dmg": cmp.other_dmg, "cd": cd_after, "blocked_34": blocked_34, "allowed_35": allowed_35})
	check("t541.3549.all_3seeds_reworked_far_below_old",
		(cmp.per_seed as Array).all(func(r): return int(r.new_hits) == 6 and is_equal_approx(float(r.other_dmg), 0.0) and float(r.new_dmg) > 0.0 and float(r.old_dmg) > float(r.new_dmg) * 20.0),
		cmp.per_seed)


func _test_skill_995() -> void:
	var setup := func(s: XState) -> XActor:
		var a: XActor = s.actor(3)
		a.change_level(70)
		_equip_weapon(a, 1105)  # 尸山血海 <Replace Attack: 995>
		# 同时穿上原版条件段依赖的血月三件套 1568/1569/1570，证实 drop_if 已去掉额外两段
		_equip_armor(a, 1568)
		_equip_armor(a, 1569)
		_equip_armor(a, 1570)
		a.mastery_levels[995] = 10
		a.refresh_passive()
		a.recover_all()
		a.hp = floorf(a.mhp * 0.5)  # 留出回血空间，验证 Hp +500 已被移除
		return a

	var cmp := _cast_compare_3seeds(995, setup)
	var a_new: XActor = cmp.actor_new
	var sk_new: Dictionary = cmp.sk_new

	check("t541.995.in_skill_rework", XTianqiSkills.has(995), sk_new.get("damage"))
	check("t541.995.replaces_attack", a_new.attack_skill_id() == 995, a_new.attack_skill_id())
	check("t541.995.module_two_hits_no_fixed_heal",
		str(sk_new.get("damage", {}).get("formulaProgram", {}).get("module", "")) == "tianqi_skill"
		and int(sk_new.get("yepEffects", -1)) == 2
		and int(cmp.new.hits) == 2
		and float(cmp.hp_delta) <= 0.0,
		{"yepEffects": sk_new.get("yepEffects"), "hits": cmp.new.hits, "hp_delta": cmp.hp_delta})
	check("t541.995.old_had_conditional_4_hits", int(cmp.old.hits) == 4, {"old_hits": cmp.old.hits})
	check("t541.995.all_3seeds_reworked_far_below_old",
		(cmp.per_seed as Array).all(func(r): return int(r.new_hits) == 2 and float(r.hp_delta) <= 0.0 and float(r.new_dmg) > 0.0 and float(r.old_dmg) > float(r.new_dmg) * 20.0),
		cmp.per_seed)


func _test_baseline_dps_clone_deep_copy() -> void:
	var st := _make_tianqi([3, 32, 115, 45, 19, 49, 53], 25)
	for aid in [3, 32, 115, 45, 19, 49, 53]:
		st.actor(aid).change_level(70)
	_equip_weapon(st.actor(32), 1105)
	_equip_armor(st.actor(32), 3774)
	_equip_weapon(st.actor(115), 1371)
	_equip_armor(st.actor(115), 2525)
	_equip_weapon(st.actor(45), 1539)
	for aid in [32, 115, 45]:
		st.actor(aid).refresh_passive()
		st.actor(aid).recover_all()

	var mhp32_orig := st.actor(32).mhp
	var mhp115_orig := st.actor(115).mhp
	var eq32_orig := st.actor(32).equip_list().size()
	var eq115_orig := st.actor(115).equip_list().size()

	var c1: XState = BaselineDps._clone(st)
	var c2: XState = BaselineDps._clone(st)

	check("t541.clone.equips_array_not_shared",
		not is_same(st.actor(32).equips, c1.actor(32).equips)
		and not is_same(c1.actor(32).equips, c2.actor(32).equips)
		and not is_same(st.gear, c1.gear)
		and not is_same(st.flags, c1.flags))

	var eq_item_orig = st.actor(32).equip_list()[0]
	var eq_item_c1 = c1.actor(32).equip_list()[0]
	check("t541.clone.equip_dict_not_shared", not is_same(eq_item_orig, eq_item_c1))

	# 模拟 --lineups > 1：c2 换人 [3, 19, 49, 53] 会对 32/115/45 调 XEquipment.clear
	BaselineDps._relineup(c2, [3, 19, 49, 53], 0)
	st.actor(32).refresh_passive()
	c1.actor(32).refresh_passive()
	c1.actor(115).refresh_passive()

	check("t541.clone.relineup_does_not_strip_orig",
		st.actor(32).equip_list().size() == eq32_orig
		and st.actor(115).equip_list().size() == eq115_orig
		and is_equal_approx(st.actor(32).mhp, mhp32_orig),
		{"eq32": st.actor(32).equip_list().size(), "eq115": st.actor(115).equip_list().size(), "mhp32": st.actor(32).mhp})
	check("t541.clone.relineup_does_not_strip_sibling_clone",
		c1.actor(32).equip_list().size() == eq32_orig
		and c1.actor(115).equip_list().size() == eq115_orig
		and is_equal_approx(c1.actor(32).mhp, mhp32_orig)
		and is_equal_approx(c1.actor(115).mhp, mhp115_orig),
		{"c1_eq32": c1.actor(32).equip_list().size(), "c1_eq115": c1.actor(115).equip_list().size(), "c1_mhp32": c1.actor(32).mhp, "c1_mhp115": c1.actor(115).mhp})
	check("t541.clone.c2_actually_cleared_benched",
		c2.actor(32).equip_list().is_empty() and c2.actor(115).equip_list().is_empty(),
		{"c2_eq32": c2.actor(32).equip_list().size(), "c2_eq115": c2.actor(115).equip_list().size()})


func _test_xiyou_untouched() -> void:
	var s := _make_xiyou([3, 1, 2, 4], 25)
	var sk3624 := XDB.rec("Skills", 3624)
	var sk1968 := XDB.rec("Skills", 1968)
	var sk3549 := XDB.rec("Skills", 3549)
	var sk995 := XDB.rec("Skills", 995)

	check("t541.xiyou.3624_original",
		str(sk3624.get("damage", {}).get("formula", "")) == "1375 + a.mat * 20 - (0 * 2) + a.mhp"
		and int(sk3624.get("mpCost", 0)) == 500
		and not str(sk3624.get("note", "")).contains("<Cooldown: 3>"),
		{"formula": sk3624.get("damage", {}).get("formula"), "mpCost": sk3624.get("mpCost")})
	check("t541.xiyou.1968_original",
		str(sk1968.get("damage", {}).get("formula", "")) == "(3350 + a.mat * 27 - (0 * 2))*1.65"
		and int(sk1968.get("mpCost", 0)) == 300,
		{"formula": sk1968.get("damage", {}).get("formula"), "mpCost": sk1968.get("mpCost")})
	check("t541.xiyou.3549_original",
		str(sk3549.get("damage", {}).get("formula", "")) == "(3000+a.atk * 20 +a.agi * 20 - (0 * 2))*1.5"
		and int(sk3549.get("tpCost", 0)) == 45
		and int(sk3549.get("yepEffects", 0)) == 8,
		{"formula": sk3549.get("damage", {}).get("formula"), "tpCost": sk3549.get("tpCost"), "yepEffects": sk3549.get("yepEffects")})
	check("t541.xiyou.995_original",
		str(sk995.get("damage", {}).get("formula", "")).contains("skillMasteryLevel")
		and int(sk995.get("yepEffects", 0)) == 4,
		{"formula": sk995.get("damage", {}).get("formula"), "yepEffects": sk995.get("yepEffects")})
