extends Node
## 【小A·T530】天启篇总账改造核心（预算稿 v0.16 五／六.2～4／九.1·7甲·8·9甲·19·21②／附表一二四＋D290＋T529 核 P2-1）：
## 1. 九线分池（旧顶 CAP_NINE 留给 T536 拆）＋老装备按来源重建（宝珠／符文之语／强化／法宝／固定残余）＋系别法宝拆记
## 2. 词条减伤 −25%／回复 15%／抗性 −40%／再释 20% 先封再并套、回复套只算一套（5%）、守套 −15%（两套 −19%）不折、
##    自带回 ≤10%、吸血单次施放 20%、随机词条进攻面例外不封（九.8）
## 3. 4 件整系免疫武器（94/2021/2022/2023）折 −30%、固定抗性每系 −30%、限时无敌保留、双系抗并各自一系取大
## 4. 旧百分比穿透 4:1 转无视防御 ≤15%（仅牌局开打敌）、无视防御合计上限 40%（杰作无我 45%，含狂妄穿透 21②，不截角色技能自带无视防）、
##    固定穿透改文案（help_card／guide）、首领机制免伤不吃穿透（附表二 6 情形＋四格＋西游档）
## 5. 每回合自动回复各线合计 81%（词条 15＋长生宝珠 45［Kyo 11-26 事项81］＋回复套 5＋光环 6＋自带 10），负再生不折
## 6. 五个搭配中的 1（不死队）／3（单件四步）／4（双动多段斩杀）／5（词条配法）实跑记录
## 7. 只改天启篇，西游档零改动（XTianqi.active 守卫）
## 8. T529 核 P2-1：suit_mult 记进 breakdown.row.suit、XTianqiLedger.pools residual.suitMultiplier 与 audit

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a, b: float, eps := 1e-4) -> bool:
	return a != null and absf(float(a) - b) <= eps


func _ids() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(tianqi := true) -> XState:
	var w := _ids()
	var lineup := [w[0], w[1], w[2], w[3], w[4]]
	var s: XState
	if tianqi:
		s = XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
	else:
		s = XState.new()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in lineup:
		s.actor(id).recover_all()
	return s


func _logic(tianqi := true) -> XBattleLogic:
	var s := _state(tianqi)
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	return lg


func _x(key: String, tier := 4, grade := "perfect", extra := {}) -> Dictionary:
	return {"key": key, "tier": tier, "grade": grade, "extra": extra}


func _skill(id := 99530, elem := 2, hit_type := 2, formula := "10000", extra_elems: Array = [], stype := 1) -> Dictionary:
	var sk := {"id": id, "scope": 1, "hitType": hit_type, "stypeId": stype, "mpCost": 0, "tpCost": 0,
		"damage": {"type": 1, "elementId": elem, "critical": false, "variance": 0, "formula": formula},
		"effects": [], "note": "", "meta": {"SkillTypes": "[\"A\"]"}}
	if not extra_elems.is_empty():
		sk["yep"] = {"multipleElements": extra_elems}
	return sk


func _clear_equips(a: XActor) -> void:
	a.keep_unequippable = true
	for i in range(a.equips.size()):
		a.equips[i] = {}
	a.read_touch()
	a.param_mark_dirty()
	a.refresh_passive()


func _put_equips(a: XActor, items: Array) -> void:
	a.keep_unequippable = true
	for i in range(a.equips.size()):
		a.equips[i] = {}
	for i in range(items.size()):
		if i < a.equips.size():
			a.equips[i] = items[i]
		else:
			a.equips.append(items[i])
	a.read_touch()
	a._pm_base = {}
	a.param_mark_dirty()
	a.param_refresh()
	a.refresh_passive()


func _run() -> void:
	_test_1_split_rebuild_fabao()
	_test_2_affix_caps_and_suits()
	_test_3_immunity_and_dual_element()
	_test_4_penetration_def_ignore_and_text()
	_test_5_regen_81_pct()
	_test_6_combos_1_3_4_5()
	_test_7_xiyou_untouched()
	_test_8_t529_suit_mult_ledger()
	_test_9_self_cap_t528()
	_test_10_follow_cast_lifesteal()
	_test_11_all_off_fabao_old_cap()
	_test_12_cat_sword_rebuild()
	var passed := 0
	for r in results:
		if r.passed:
			passed += 1
		else:
			print("FAIL %s %s" % [r.name, JSON.stringify(r.detail)])
	print("TEST_RESULT=%s" % JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


# ---- 1. 九线分池（旧顶留给 N13 拆）＋老装备按来源重建＋法宝拆记 ----
func _test_1_split_rebuild_fabao() -> void:
	var s := _state(true)
	var a := s.actor(int(s.battle_slots[0]))
	a.change_level(80)
	var e := XEnemy.new().setup(1, 3, 100.0)
	var sk := _skill(99531, 2, 2, "10000")
	# 1a. 系别法宝 4544 炎阳圣剑拆出 equip 桶单记 fabao；配 +30% 火武器不被旧 30% 九线合用顶吞掉
	var fabao := XActor.make_equip("armor", 4544)
	var w_fire := {"kind": "weapon", "id": 1, "base": 1, "wtypeId": 1, "etypeId": 1,
		"params": [0, 0, 100, 0, 100, 0, 0, 0], "traits": [], "note": "", "meta": {},
		"yep": {"elementAmplify": {"2": 0.30}}}
	_check("t1_fabao_bucket", XTianqiLedger.bucket_of(fabao, a) == "fabao", XTianqiLedger.bucket_of(fabao, a))
	_put_equips(a, [w_fire, fabao])
	var by: Dictionary = a.passive_cache().get("bySource", {})
	var f_amp := float(by.get("elementAmplify", {}).get(2, {}).get("fabao", 0.0))
	var e_amp := float(by.get("elementAmplify", {}).get(2, {}).get("equip", 0.0))
	_check("t1_fabao_separate_from_equip", _near(f_amp, 0.10) and _near(e_amp, 0.30), by.get("elementAmplify", {}).get(2, {}))
	var res_fb := XDamage.calculate(sk, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	_check("t1_fabao_not_eaten_by_nine_cap", _near(float(res_fb.breakdown.row.pools.element), 1.40), res_fb.breakdown.row.pools)
	# 法宝自身超过 10% 时由 SPLIT_CAPS 独立封到 10%
	var fabao_hi := fabao.duplicate(true)
	fabao_hi["_tq_efabao_v"] = 2
	fabao_hi["yep"] = {"elementAmplify": {"2": 0.25}}
	_put_equips(a, [fabao_hi])
	var res_fb_hi := XDamage.calculate(sk, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	_check("t1_fabao_own_cap_10", _near(float(res_fb_hi.breakdown.row.pools.element), 1.10), res_fb_hi.breakdown.row.pools)
	# 1b. 九线分池（SPLIT_CAPS）与旧顶（CAP_NINE）并存且可独立开关：equip 终伤 25% 在 SPLIT_CAPS 下封 10%；关 CAP_NINE 后 SPLIT_CAPS 仍独立管住每线
	var eq_hi := {"kind": "armor", "id": 99001, "etypeId": 3, "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [],
		"note": "<passiveHarmRi:25%><passiveCrHarmRi:35%><SkillTypesDvupA:25%>", "meta": {}, "yep": {}}
	_put_equips(a, [eq_hi])
	var res_both := XDamage.calculate(sk, a, e, {"critical": true, "variance": false, "rawValue": 10000.0})
	XTianqiLedger.CAP_NINE = false
	var res_split_only := XDamage.calculate(sk, a, e, {"critical": true, "variance": false, "rawValue": 10000.0})
	XTianqiLedger.SPLIT_CAPS = false
	var res_none := XDamage.calculate(sk, a, e, {"critical": true, "variance": false, "rawValue": 10000.0})
	XTianqiLedger.CAP_NINE = true
	XTianqiLedger.SPLIT_CAPS = true
	_check("t1_split_caps_equip_quotas",
		_near(float(res_split_only.breakdown.row.pools.skill), 1.12)
		and _near(float(res_split_only.breakdown.row.pools.bonus), 1.10)
		and _near(float(res_none.breakdown.row.pools.skill), 1.25)
		and _near(float(res_none.breakdown.row.pools.bonus), 1.25)
		and _near(float(res_both.breakdown.row.pools.bonus), 1.10),
		{"both": res_both.breakdown.row.pools, "split": res_split_only.breakdown.row.pools, "none": res_none.breakdown.row.pools})
	# 1c. 老装备按来源重建：同一件武器含底子(+35%火) + 符文之语 + 强化元素石 + 宝珠，拆成 equip/runeword/enhance/orb 四桶且各桶相加＝原合计
	var rw_recipe := {}
	for r in XDB.table("Runewords"):
		if r is Dictionary and not (r.get("materials", []) as Array).is_empty() and int(r.get("weapon", 0)) > 0:
			rw_recipe = r
			break
	var elem_stone_id := 0
	for it in XDB.table("Items"):
		if it is Dictionary and it.get("upgrade") is Dictionary:
			for eff in it.upgrade.get("weapon", []):
				if eff is Dictionary and str(eff.get("op", "")) == "element" and float(eff.get("value", 0.0)) > 0.0:
					elem_stone_id = int(it.id)
					break
		if elem_stone_id > 0:
			break
	var orb_gem := {}
	for it in XDB.table("Items"):
		if it is Dictionary and str(it.get("note", "")).to_upper().contains("ELEMENT AMPLIFY 2:"):
			orb_gem = it
			break
	var rebuilt_ok := false
	var rebuilt_detail := {}
	if not rw_recipe.is_empty() and elem_stone_id > 0:
		var wtype := int(rw_recipe.weaponTypes[0])
		var tpl_w := XDB.rec("Weapons", int(rw_recipe.weapon))
		var rw_amp2 := float(tpl_w.get("yep", {}).get("elementAmplify", {}).get("2", 0.0))
		var stone_it := XDB.rec("Items", elem_stone_id)
		var st_e := 0
		var st_v := 0.0
		for eff in XGearUpgrade.rule(stone_it).get("weapon", []):
			if eff is Dictionary and str(eff.get("op", "")) == "element":
				st_e = int(eff.element)
				st_v += float(eff.value)
		var amp_map := {"2": 0.35 + rw_amp2}
		amp_map[str(st_e)] = float(amp_map.get(str(st_e), 0.0)) + st_v
		var old_w := {"kind": "weapon", "id": 99002, "base": 1, "wtypeId": wtype, "etypeId": 1,
			"params": [0, 0, 100, 0, 0, 0, 0, 0], "traits": [], "note": str(tpl_w.get("note", "")),
			"meta": tpl_w.get("meta", {}).duplicate(true), "yep": {"elementAmplify": amp_map},
			"runewords": [int(rw_recipe.id)], "runewordName": str(tpl_w.get("name", "")),
			"upgrades": [{"item": elem_stone_id, "name": str(stone_it.name), "cost": 1}],
			"augmentSlots": ["Weapon"], "augmentSlotItems": []}
		if not orb_gem.is_empty():
			old_w["augmentSlotItems"] = ["item:%d" % int(orb_gem.id)]
			var oa := XTianqiLedger.orb_amplify(old_w)
			for ok_e in oa:
				amp_map[str(ok_e)] = float(amp_map.get(str(ok_e), 0.0)) + float(oa[ok_e])
		_put_equips(a, [old_w])
		var by_r: Dictionary = a.passive_cache().get("bySource", {})
		var ea_st: Dictionary = by_r.get("elementAmplify", {}).get(st_e, {})
		var ea_2: Dictionary = by_r.get("elementAmplify", {}).get(2, {})
		var sum2 := 0.0
		for v in ea_2.values():
			sum2 += float(v)
		rebuilt_ok = _near(float(ea_2.get("equip", 0.0)), 0.35) \
			and _near(float(ea_st.get("enhance", 0.0)), st_v) \
			and _near(sum2, float(amp_map["2"]))
		rebuilt_detail = {"ea_2": ea_2, "ea_st": ea_st, "st_e": st_e, "st_v": st_v, "amp_map": amp_map}
	_check("t1_old_gear_rebuild_sources", rebuilt_ok, rebuilt_detail)


# ---- 2. 词条减伤／回复先封再并套、回复套只算一套、自带回 ≤10%、吸血单次 20%、进攻面例外 ----
func _test_2_affix_caps_and_suits() -> void:
	var lg := _logic(true)
	var a: XActor = lg.actors[0]
	var e: XEnemy = lg.enemies[0]
	a.change_level(80)
	# 2a. 8 条减伤(6%)先封 -25%(0.75)，再并守型模板套 5 件(-15%, 0.85) → 0.75 * 0.85 = 0.6375（守套 -15% 完整不折）
	var def_items := []
	for i in 8:
		def_items.append({"kind": "armor", "id": 99100 + i, "etypeId": 3, "params": [0, 0, 0, 0, 0, 0, 0, 0],
			"traits": [], "note": "", "meta": {"req_level": "75"}, "tianqi_affixes": [
				_x("damage_reduction", 4, "perfect"),
				_x("element_resist", 4, "perfect", {"element": "fire"}),
				_x("hrg", 4, "perfect"),
				_x("recast", 4, "perfect"),
				_x("skill_damage", 4, "perfect"),
				_x("element_damage", 4, "perfect", {"element": "fire"}),
			]})
	_put_equips(a, def_items)
	var p_only := XTianqiAffixBattle.personal_parts(a)
	_check("t2_affix_dr_cap_25", _near(float(p_only.p.get("damage_reduction", 1.0)), 0.75), p_only.p.get("damage_reduction"))
	_check("t2_affix_er_cap_40", _near(float(p_only.p.get("element_resist:fire", 1.0)), 0.60), p_only.p.get("element_resist:fire"))
	_check("t2_affix_hrg_cap_15", _near(float(p_only.affix_hrg), 15.0) and _near(float(p_only.p.get("hrg", 0.0)), 15.0), p_only)
	_check("t2_affix_recast_cap_20", _near(float(p_only.p.get("recast", 0.0)), 20.0), p_only.p.get("recast"))
	# 进攻面例外（九.8）：8 条四阶极品 skill_damage (8×10=80%) 与 element_damage:fire (8×11=88%) 不封顶
	var sd_one := float(XTianqiAffixTable.value("skill_damage", 4, "perfect"))
	var ed_one := float(XTianqiAffixTable.value("element_damage", 4, "perfect"))
	_check("t2_affix_offense_uncapped",
		_near(float(p_only.p.get("skill_damage", 0.0)), sd_one * 8.0)
		and _near(float(p_only.p.get("element_damage:fire", 0.0)), ed_one * 8.0),
		{"sd": p_only.p.get("skill_damage"), "ed": p_only.p.get("element_damage:fire"), "want_sd": sd_one * 8.0, "want_ed": ed_one * 8.0})
	# 并入模板套：1 套守·减承伤 5 件(-15%)＋2 套回复套(5%+5%→只算一套 5%)
	var orig_tpl := XTianqiSuits.template_table().duplicate(true)
	var test_tpl := orig_tpl.duplicate(true)
	test_tpl["suits"]["120"] = {"kind": "def_reduce", "name": "测试守套A"}
	test_tpl["suits"]["164"] = {"kind": "def_reduce", "name": "测试守套B"}
	test_tpl["suits"]["167"] = {"kind": "func_regen", "name": "测试回复套A"}
	test_tpl["suits"]["168"] = {"kind": "func_regen", "name": "测试回复套B"}
	XTianqiSuits.reload_template(test_tpl)
	var items_1def := def_items.duplicate(true)
	for j in 5:
		items_1def[j]["equipment"] = {"suits": [120]}
	_put_equips(a, items_1def)
	var p_1def := XTianqiAffixBattle.personal_parts(a)
	_check("t2_def_suit_15_not_truncated_after_affix_25",
		_near(float(p_1def.p.get("damage_reduction", 1.0)), 0.75 * 0.85),
		p_1def.p.get("damage_reduction"))
	# 两套守套（5件 -15% + 3件 -10% → 0.85*0.90=0.765，两套封顶 -19% = 0.81 → 0.75*0.81=0.6075）
	var items_2def := items_1def.duplicate(true)
	for j in range(5, 8):
		items_2def[j]["equipment"] = {"suits": [164]}
	_put_equips(a, items_2def)
	var p_2def := XTianqiAffixBattle.personal_parts(a)
	_check("t2_def_suit_two_capped_19",
		_near(float(p_2def.p.get("damage_reduction", 1.0)), 0.75 * 0.81),
		p_2def.p.get("damage_reduction"))
	# 两套回复套（各 5%，合计 10%）→ 全身只算一套 5%，词条 15% + 回复套 5% = 20%
	var items_2reg := def_items.duplicate(true)
	for j in 4:
		items_2reg[j]["equipment"] = {"suits": [167]}
	for j in range(4, 8):
		items_2reg[j]["equipment"] = {"suits": [168]}
	_put_equips(a, items_2reg)
	var p_2reg := XTianqiAffixBattle.personal_parts(a)
	_check("t2_regen_suit_only_one_5",
		_near(float(p_2reg.suit_hrg), 5.0) and _near(float(p_2reg.p.get("hrg", 0.0)), 20.0),
		{"affix": p_2reg.affix_hrg, "suit": p_2reg.suit_hrg, "total": p_2reg.p.get("hrg")})
	XTianqiSuits.reload_template({})
	# 2b. 吸血单次施放 20%（跨段／跨目标累计封顶；新一次施放重新计 20%）
	var ls_eq := {"kind": "weapon", "id": 99120, "wtypeId": 1, "etypeId": 1, "params": [0, 0, 100, 0, 0, 0, 0, 0],
		"traits": [], "note": "", "meta": {}, "tianqi_affixes": [_x("lifesteal", 4, "perfect")]}
	_put_equips(a, [ls_eq])
	XTianqiAffixBattle.start(lg)
	a.hp = 1.0
	var sk := _skill(99532, 2, 2, "10000")
	XTianqiAffixBattle.begin_action(lg, a, sk)
	var hit_cap := floorf(a.mhp * 0.10)
	var cast_cap := floorf(a.mhp * 0.20)
	XTianqiAffixBattle.after_apply(lg, a, sk, e, {"hp": 1.0e9})
	var hp1 := a.hp
	XTianqiAffixBattle.after_apply(lg, a, sk, e, {"hp": 1.0e9})
	var hp2 := a.hp
	XTianqiAffixBattle.after_apply(lg, a, sk, e, {"hp": 1.0e9})
	var hp3 := a.hp
	XTianqiAffixBattle.after_apply(lg, a, sk, e, {"hp": 1.0e9})
	var hp3b := a.hp
	XTianqiAffixBattle.end_action(lg, a, sk)
	# 新一次施放可再吸
	XTianqiAffixBattle.begin_action(lg, a, sk)
	XTianqiAffixBattle.after_apply(lg, a, sk, e, {"hp": 1.0e9})
	var hp4 := a.hp
	XTianqiAffixBattle.end_action(lg, a, sk)
	_check("t2_lifesteal_per_cast_20",
		_near(hp1 - 1.0, hit_cap)
		and _near(hp3 - 1.0, cast_cap)
		and _near(hp3b, hp3)
		and _near(hp4 - hp3, hit_cap),
		{"mhp": a.mhp, "hit_cap": hit_cap, "cast_cap": cast_cap, "hps": [hp1, hp2, hp3, hp3b, hp4]})
	lg.end_battle(0)


# ---- 3. 4 件整系免疫武器折单系抗、固定抗性 −30%、限时无敌保留、双系抗并各自一系取大 ----
func _test_3_immunity_and_dual_element() -> void:
	var lg := _logic(true)
	var a: XActor = lg.actors[0]
	var e: XEnemy = lg.enemies[0]
	a.change_level(80)
	_clear_equips(a)
	var bare1 := a.element_rate(1)
	var bare2 := a.element_rate(2)
	var bare3 := a.element_rate(3)
	# 3a. 4 件整系免疫武器 94(物1；skill_rework 已删 94 的免疫，另验原样未删时的折算)、2021(冰3)、2022(物1)、2023(物1+冰3) 折 −30%
	var w94_raw := {"kind": "weapon", "id": 99294, "base": 99294, "wtypeId": 1, "etypeId": 1,
		"params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [{"code": 11, "dataId": 1, "value": 0.0}], "note": "", "meta": {}}
	_put_equips(a, [w94_raw])
	_check("t3_imm_weapon_94_folded_30", _near(bare1 - a.element_rate(1), 0.30), [bare1, a.element_rate(1)])
	_put_equips(a, [XActor.make_equip("weapon", 94)])
	_check("t3_imm_weapon_94_not_immune", a.element_rate(1) > 0.0, a.element_rate(1))
	for pair in [[2021, 3, bare3], [2022, 1, bare1], [2023, 1, bare1], [2023, 3, bare3]]:
		var w := XActor.make_equip("weapon", int(pair[0]))
		_put_equips(a, [w])
		var r := a.element_rate(int(pair[1]))
		_check("t3_imm_weapon_%d_e%d" % [int(pair[0]), int(pair[1])], _near(float(pair[2]) - r, 0.30) and r > 0.0, [pair[2], r])
	# 固定词条多件抗性叠加（4553 混元星河剑 0.05 + 489 护卫大盾 0.85）每系最多减 0.30
	_put_equips(a, [XActor.make_equip("armor", 4553), XActor.make_equip("armor", 489)])
	_check("t3_fixed_resist_cap_30", _near(bare1 - a.element_rate(1), 0.30) and _near(bare2 - a.element_rate(2), 0.30),
		{"bare": [bare1, bare2], "got": [a.element_rate(1), a.element_rate(2)]})
	# 角色主动限时无敌状态（仅火系 code 11 dataId 2 value=0、不带全免 mdr/pdr=0）保留 0.0，且双系招 [火2, 冰3] 仍打出冰伤
	var imm_st_id := 0
	for st in XDB.table("States"):
		if st is Dictionary:
			var has_fire_imm := false
			var has_full_imm := false
			for tr in st.get("traits", []):
				var c := int(tr.get("code", 0))
				var d := int(tr.get("dataId", 0))
				var v := float(tr.get("value", 1.0))
				if c == 11 and d == 2 and v == 0.0:
					has_fire_imm = true
				if (c == 11 and d == 3 and v == 0.0) or (c == 23 and d in [6, 7] and v == 0.0):
					has_full_imm = true
			if has_fire_imm and not has_full_imm:
				imm_st_id = int(st.id)
				break
	if imm_st_id > 0:
		a.add_state(imm_st_id)
		_check("t3_timed_state_immunity_kept", _near(a.element_rate(2), 0.0) and a.element_rate(3) > 0.0, [imm_st_id, a.element_rate(2), a.element_rate(3)])
		a.remove_state(imm_st_id)
	# 3b. 双系招 [火2, 冰3]：固定火抗(-30%)＋词条火抗(-40%, 0.60) → 火 (bare2-0.30)*0.60；词条冰抗(-40%, 0.60) → 冰 bare3*0.60；双系招取大＝冰（不连乘）
	var eq_dual := []
	var shield_fire := {"kind": "armor", "id": 99200, "etypeId": 2, "params": [0, 0, 0, 0, 0, 0, 0, 0],
		"traits": [{"code": 11, "dataId": 2, "value": 0.70}], "note": "", "meta": {},
		"tianqi_affixes": [_x("element_resist", 4, "perfect", {"element": "fire"}), _x("element_resist", 4, "perfect", {"element": "ice"})]}
	eq_dual.append(shield_fire)
	for i in 3:
		eq_dual.append({"kind": "armor", "id": 99201 + i, "etypeId": 3 + i, "params": [0, 0, 0, 0, 0, 0, 0, 0],
			"traits": [], "note": "", "meta": {},
			"tianqi_affixes": [_x("element_resist", 4, "perfect", {"element": "fire"}), _x("element_resist", 4, "perfect", {"element": "ice"})]})
	_put_equips(a, eq_dual)
	XTianqiAffixBattle.start(lg)
	var sk_fire := _skill(99533, 2, 2, "10000")
	var sk_ice := _skill(99534, 3, 2, "10000")
	var sk_dual := _skill(99535, 2, 2, "10000", [3])
	var r_f := XDamage.calculate(sk_fire, e, a, {"critical": false, "variance": false, "rawValue": 10000.0})
	var r_i := XDamage.calculate(sk_ice, e, a, {"critical": false, "variance": false, "rawValue": 10000.0})
	var r_d := XDamage.calculate(sk_dual, e, a, {"critical": false, "variance": false, "rawValue": 10000.0})
	var want_f := (bare2 - 0.30) * 0.60
	var want_i := bare3 * 0.60
	_check("t3_dual_element_pick_max_damage",
		_near(float(r_f.breakdown.row.resistance), want_f)
		and _near(float(r_i.breakdown.row.resistance), want_i)
		and _near(float(r_d.breakdown.row.resistance), want_i)
		and int(r_d.breakdown.row.element) == 3
		and float(r_d.value) == float(r_i.value),
		{"fire": r_f.breakdown.row.resistance, "want_f": want_f, "ice": r_i.breakdown.row.resistance, "want_i": want_i, "dual": r_d.breakdown.row.resistance, "el": r_d.breakdown.row.element})
	# 一系限时免疫 + 另一系正常 → 双系招只免那一系，仍打出冰伤
	if imm_st_id > 0:
		a.add_state(imm_st_id)
		var r_d_imm := XDamage.calculate(sk_dual, e, a, {"critical": false, "variance": false, "rawValue": 10000.0})
		_check("t3_dual_one_immune_other_hits", float(r_d_imm.value) > 0.0 and int(r_d_imm.breakdown.row.element) == 3, r_d_imm.breakdown.row)
		a.remove_state(imm_st_id)
	lg.end_battle(0)


# ---- 4. 旧穿透迁移（附表二 6 情形＋4 格＋西游档）、无视防御上限 40%/45% 含狂妄、固定穿透文案 ----
func _test_4_penetration_def_ignore_and_text() -> void:
	var lg := _logic(true)
	var a: XActor = lg.actors[0]
	var a2: XActor = lg.actors[1]
	var e: XEnemy = lg.enemies[0]
	var e2 := XEnemy.new().setup(1, 3, 100.0)
	a.change_level(80)
	a2.change_level(80)
	# 给敌人挂固定减伤（harmRe = 5000）并给角色装 50% 百分比穿透装备与固定穿透测试装备
	var harm_st := 0
	for st in XDB.table("States"):
		if st is Dictionary and str(st.get("note", "")).contains("<passiveHarmRe02:"):
			harm_st = int(st.id)
			break
	if harm_st > 0:
		e.add_state(harm_st)
		e2.add_state(harm_st)
		a2.add_state(harm_st)
	var w_pen50 := {"kind": "weapon", "id": 99301, "wtypeId": 1, "etypeId": 1, "params": [0, 0, 500, 0, 500, 0, 0, 0],
		"traits": [], "note": "<DepassiveHarmRe02: 50%><DepassiveHarmRe01: 80%>", "meta": {}, "yep": {}}
	var w_penfix := {"kind": "weapon", "id": 99302, "wtypeId": 1, "etypeId": 1, "params": [0, 0, 500, 0, 500, 0, 0, 0],
		"traits": [], "note": "<DepassiveHarmRe02: 500>", "meta": {}, "yep": {}}
	var sk_fire := _skill(99540, 2, 2, "10000")
	var sk_phys := _skill(99541, 1, 1, "10000")
	# 情形 1：我方打普通敌人，牌局开 → 敌人固定减伤清零；50% 百分比穿透 4:1 转 12.5% 无视防御；80% 封顶 15%；固定穿透不折
	_put_equips(a, [w_pen50])
	var r1_fire := XDamage.calculate(sk_fire, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	var r1_phys := XDamage.calculate(sk_phys, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	_check("t4_case1_deck_on_pct_to_def_ignore",
		float(r1_fire.breakdown.row.fixedMitigation) == 0.0
		and _near(float(r1_fire.breakdown.row.defIgnore.pen), 0.125)
		and _near(float(r1_phys.breakdown.row.defIgnore.pen), 0.15),
		{"fire": r1_fire.breakdown.row.get("defIgnore"), "phys": r1_phys.breakdown.row.get("defIgnore"), "flat": r1_fire.breakdown.row.fixedMitigation})
	_put_equips(a, [w_penfix])
	var r1_fix := XDamage.calculate(sk_fire, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	_check("t4_case1_fixed_pen_not_converted",
		float(r1_fix.breakdown.row.fixedMitigation) == 0.0 and _near(float(r1_fix.breakdown.row.defIgnore.pen), 0.0),
		r1_fix.breakdown.row.get("defIgnore"))
	# 情形 2：我方打普通敌人，牌局关 → 敌人固定减伤仍清零，百分比穿透不换算无视防御（免算两遍）
	_put_equips(a, [w_pen50])
	XTianqiElements.DECK = false
	var r2_off := XDamage.calculate(sk_fire, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	XTianqiElements.DECK = true
	_check("t4_case2_deck_off_no_convert",
		float(r2_off.breakdown.row.fixedMitigation) == 0.0 and _near(float(r2_off.breakdown.row.defIgnore.pen), 0.0),
		r2_off.breakdown.row.get("defIgnore"))
	# 情形 3：首领机制免伤（BOSS_MECH_FLAT_STATES / flatMitigationAdd）不吃固定穿透也不吃百分比穿透
	var mech_ok := true
	if harm_st > 0:
		XTianqiLedger.BOSS_MECH_FLAT_STATES = [harm_st]
		_put_equips(a, [w_pen50])
		var flat_pct := XDamage._flat_mitigation(a, e, 2, {"flatMitigationAdd": {"2": 1000.0}, "flatMitigationRate": 0.5})
		_put_equips(a, [w_penfix])
		var flat_fix := XDamage._flat_mitigation(a, e, 2, {"flatMitigationAdd": {"2": 1000.0}, "flatMitigationRate": 0.5})
		var expected_st := XTianqiLedger.boss_mech_state_flat(e, 2)
		XTianqiLedger.BOSS_MECH_FLAT_STATES = []
		mech_ok = expected_st > 0.0 and _near(flat_pct, 1000.0 + expected_st) and _near(flat_fix, 1000.0 + expected_st)
	_check("t4_case3_boss_mech_no_pierce", mech_ok)
	# 情形 4 & 5：敌人打我方 / 我方打我方 → 我方固定减伤不被清
	var flat_e2a := XDamage._flat_mitigation(e, a2, 2, {"flatMitigationAdd": {}, "flatMitigationRate": 1.0})
	var flat_a2a := XDamage._flat_mitigation(a, a2, 2, {"flatMitigationAdd": {}, "flatMitigationRate": 1.0})
	_check("t4_case4_5_actor_target_untouched", flat_e2a > 0.0 and flat_a2a >= 0.0 and (harm_st == 0 or flat_e2a > 0.0), [flat_e2a, flat_a2a])
	# 情形 6：敌人打敌人 → 敌人固定减伤与种族减免一并清
	var r6 := XDamage.calculate(sk_fire, e, e2, {"critical": false, "variance": false, "rawValue": 10000.0})
	_check("t4_case6_enemy_vs_enemy_cleared", float(r6.breakdown.row.fixedMitigation) == 0.0, r6.breakdown.row.fixedMitigation)
	# 四格开关验证：NO_ENEMY_FLAT_MIT 关 × 牌局开/关 → 恢复敌人固定减伤且不换算
	_put_equips(a, [w_pen50])
	XTianqiLedger.NO_ENEMY_FLAT_MIT = false
	var r_off_deck_on := XDamage.calculate(sk_fire, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	XTianqiElements.DECK = false
	var r_off_deck_off := XDamage.calculate(sk_fire, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	XTianqiElements.DECK = true
	XTianqiLedger.NO_ENEMY_FLAT_MIT = true
	_check("t4_rollback_grid_restores_flat_mit",
		float(r_off_deck_on.breakdown.row.fixedMitigation) > 0.0
		and not r_off_deck_on.breakdown.row.has("defIgnore")
		and float(r_off_deck_off.breakdown.row.fixedMitigation) > 0.0,
		[r_off_deck_on.breakdown.row.fixedMitigation, r_off_deck_off.breakdown.row.fixedMitigation])
	# 无视防御合计上限 40%（狂妄记入 21②），杰作无我 45%
	var hub := XActor.make_equip("armor", XHubris.ARMOR)
	var ata := XActor.make_equip("armor", XHubris.ATARAXIA)
	# 80% 物理穿透(→15%) + 妖族猎物 15% + 狂妄(18%) = 48% → 封 40%；换杰作无我(27%) = 57% → 封 45%
	XRace.on_actor_created(XState.current, a)
	var rd: Dictionary = XState.current.race.actors[str(a.actor_id)]
	rd["race"] = 1
	rd["rank"] = XRace.config().rates.size()
	XRaceBattle.start(lg)
	_put_equips(a, [w_pen50, hub])
	var r_hub := XDamage.calculate(sk_phys, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	_put_equips(a, [w_pen50, ata])
	var r_ata := XDamage.calculate(sk_phys, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	_check("t4_def_ignore_cap_40_hubris_45_ataraxia",
		_near(float(r_hub.breakdown.row.defIgnore.cap), 0.40)
		and _near(float(r_hub.breakdown.row.defIgnore.quota_p), 0.40)
		and _near(float(r_hub.breakdown.row.defIgnore.eff_p_rate), 0.60)
		and _near(float(r_ata.breakdown.row.defIgnore.cap), 0.45)
		and _near(float(r_ata.breakdown.row.defIgnore.quota_p), 0.45)
		and _near(float(r_ata.breakdown.row.defIgnore.eff_p_rate), 0.55),
		{"hub": r_hub.breakdown.row.get("defIgnore"), "ata": r_ata.breakdown.row.get("defIgnore")})
	# 非额度技能无视防御（如 50% 技能机制无视防御）不被 40% 误截
	var f_skill := {"physicalDefenseRate": 0.50, "magicalDefenseRate": 0.50}
	var di_skill := XTianqiLedger.def_ignore_summary(a, e, 2, f_skill, [], {})
	_check("t4_non_quota_skill_def_ignore_kept", _near(float(di_skill.eff_p_rate), 0.50 * (1.0 - 0.125)), di_skill)
	# 固定穿透改文案（help_card + guide）
	var lines := []
	XHelpCard._pierce_lines(lines, "<DepassiveHarmRe02: 500><DepassiveHarmRe02: 50%>")
	var txt_card := "\n".join(lines)
	var intro_f := XGuide.milestone_intro({"key": "f", "intro": "旧文案"}, XState.current)
	_check("t4_fixed_pen_text_tianqi",
		txt_card.contains("固定减伤穿透（天启篇对敌无效）")
		and txt_card.contains("牌局开启时，对敌人的旧百分比穿透每 4% 折为 1% 无视防御，换算部分最多 15%。")
		and intro_f.contains("牌局开启时，对敌人的旧百分比穿透每 4% 折为 1% 无视防御，换算部分最多 15%。")
		and intro_f.contains("首领机制免伤不受穿透影响。"),
		{"card": txt_card, "guide": intro_f})
	lg.end_battle(0)


# ---- 5. 每回合自动回复各线合计 81%（九.7甲＋Kyo 11-26 事项81 长生宝珠 45%），负再生不折 ----
func _test_5_regen_81_pct() -> void:
	var lg := _logic(true)
	var s := lg.state
	# 角色 113 黑猫猫自带 +30% hrg（应封到 10%）
	XTianqi._joining = true
	s.add_actor(113)
	XTianqi._joining = false
	var cat_actor := s.actor(113)
	cat_actor.change_level(80)
	s.battle_slots[0] = 113
	_clear_equips(cat_actor)
	_check("t5_actor_innate_hrg_capped_10", _near(cat_actor.hrg, 0.10), cat_actor.hrg)
	# 满五线超配：词条 8×8%=64%(→15%) + 长生宝珠 3×20%=60%(→45%) + 2 回复套 10%(→5%) + 恢复光环 6%(→6%) + 自带 30%(→10%) = 81%
	var orig_tpl := XTianqiSuits.template_table().duplicate(true)
	var test_tpl := orig_tpl.duplicate(true)
	test_tpl["suits"]["167"] = {"kind": "func_regen", "name": "测试回复套A"}
	test_tpl["suits"]["168"] = {"kind": "func_regen", "name": "测试回复套B"}
	XTianqiSuits.reload_template(test_tpl)
	var full_items := []
	for i in 8:
		var it := {"kind": "armor", "id": 99400 + i, "etypeId": 3, "params": [0, 0, 0, 0, 0, 0, 0, 0],
			"traits": [], "note": "", "meta": {"req_level": "75"},
			"tianqi_affixes": [_x("hrg", 4, "perfect")],
			"equipment": {"suits": [167 if i < 4 else 168]}}
		if i < 3:
			it["traits"] = [{"code": 22, "dataId": 7, "value": 0.20, "_codexOrb": "changsheng:%d" % i}]
		full_items.append(it)
	_put_equips(cat_actor, full_items)
	# 给队友装 6% 恢复光环
	var helper: XActor = lg.actors[1]
	_put_equips(helper, [{"kind": "armor", "id": 99410, "etypeId": 9, "params": [0, 0, 0, 0, 0, 0, 0, 0],
		"traits": [], "note": "", "meta": {}, "tianqi_affixes": [_x("aura_recovery", 4, "perfect")]}])
	lg.actors[0] = cat_actor
	XTianqiAffixBattle.start(lg)
	cat_actor.read_touch()
	_check("t5_regen_five_lines_total_81", _near(cat_actor.hrg, 0.81), cat_actor.hrg)
	# 挂中毒状态 4 (-10% hrg) → 0.81 - 0.10 = 0.71（负再生不折）
	cat_actor.add_state(4)
	cat_actor.read_touch()
	_check("t5_neg_regen_preserved", _near(cat_actor.hrg, 0.71), cat_actor.hrg)
	cat_actor.remove_state(4)
	XTianqiSuits.reload_template({})
	lg.end_battle(0)


# ---- 6. 实跑搭配 1、3、4、5（v0.16 第五节） ----
func _test_6_combos_1_3_4_5() -> void:
	# === 搭配 1：不死队 ===
	var lg := _logic(true)
	var a: XActor = lg.actors[0]
	var ally: XActor = lg.actors[1]
	var foe: XEnemy = lg.enemies[0]
	a.change_level(80)
	var orig_tpl := XTianqiSuits.template_table().duplicate(true)
	var test_tpl := orig_tpl.duplicate(true)
	test_tpl["suits"]["120"] = {"kind": "def_reduce", "name": "守套5"}
	XTianqiSuits.reload_template(test_tpl)
	_clear_equips(a)
	var bare_f := a.element_rate(2)
	var bare_i := a.element_rate(3)
	var items_immortal := []
	for i in 8:
		var it := {"kind": "armor", "id": 99600 + i, "etypeId": 3, "params": [0, 0, 0, 0, 0, 0, 0, 0],
			"traits": [{"code": 11, "dataId": 2, "value": 0.70}] if i == 0 else [],
			"note": "", "meta": {"req_level": "75"},
			"tianqi_affixes": [
				_x("damage_reduction", 4, "perfect"),
				_x("element_resist", 4, "perfect", {"element": "fire"}),
				_x("mhp", 4, "perfect"),
			]}
		if i < 5:
			it["equipment"] = {"suits": [120]}
		items_immortal.append(it)
	var hs := XActor.make_equip("armor", XHeartsteel.ARMOR)
	items_immortal.append(hs)
	_put_equips(a, items_immortal)
	_put_equips(ally, [{"kind": "armor", "id": 99620, "etypeId": 9, "params": [0, 0, 0, 0, 0, 0, 0, 0],
		"traits": [], "note": "", "meta": {}, "tianqi_affixes": [_x("aura_shelter", 4, "perfect")]}])
	XTianqiAffixBattle.start(lg)
	a.hp = a.mhp
	var sk_none := _skill(99601, 0, 2, "10000")
	var sk_fire := _skill(99602, 2, 2, "10000")
	var sk_dual := _skill(99603, 2, 2, "10000", [3])
	var sk_sure := _skill(99604, 0, 0, "10000")
	var r_none := XDamage.calculate(sk_none, foe, a, {"critical": false, "variance": false, "rawValue": 10000.0})
	var r_fire := XDamage.calculate(sk_fire, foe, a, {"critical": false, "variance": false, "rawValue": 10000.0})
	var r_dual := XDamage.calculate(sk_dual, foe, a, {"critical": false, "variance": false, "rawValue": 10000.0})
	var r_sure := XDamage.calculate(sk_sure, foe, a, {"critical": false, "variance": false, "rawValue": 10000.0})
	# 不死队净承伤：词条 -25%(0.75) × 守套 -15%(0.85) × 庇护 -6%(0.94) = 0.59925；火对口再 × 固定火抗(bare_f-0.30) × 词条火抗 0.60
	var m_base := 0.75 * 0.85 * 0.94
	var m_fire := m_base * (bare_f - 0.30) * 0.60
	# 对照 2 回复 + 6 生命配
	var items_2h6m := []
	for i in 8:
		items_2h6m.append({"kind": "armor", "id": 99630 + i, "etypeId": 3, "params": [0, 0, 0, 0, 0, 0, 0, 0],
			"traits": [], "note": "", "meta": {"req_level": "75"},
			"tianqi_affixes": [_x("hrg" if i < 2 else "mhp", 4, "perfect")]})
	_put_equips(a, items_2h6m)
	XTianqiAffixBattle.start(lg)
	var hrg_2h6m := a.hrg
	var mhp_2h6m := a.mhp
	print("T530_COMBO1|base_in=%.4f|fire_in=%.4f|dual_in=%.4f|sure_in=%.4f|hrg_2h6m=%.2f%%|mhp_2h6m=%.0f" % [
		float(r_none.breakdown.row.incoming), float(r_fire.breakdown.row.incoming) * float(r_fire.breakdown.row.resistance),
		float(r_dual.breakdown.row.incoming) * float(r_dual.breakdown.row.resistance),
		float(r_sure.breakdown.row.incoming), hrg_2h6m * 100.0, mhp_2h6m])
	_check("t6_combo1_immortal_team",
		_near(float(r_none.breakdown.row.incoming), m_base)
		and _near(float(r_fire.breakdown.row.incoming) * float(r_fire.breakdown.row.resistance), m_fire)
		and _near(float(r_dual.breakdown.row.resistance), bare_i)
		and _near(float(r_sure.breakdown.row.incoming), m_base)
		and _near(hrg_2h6m, 0.15),
		{"none": r_none.breakdown.row.incoming, "fire": float(r_fire.breakdown.row.incoming) * float(r_fire.breakdown.row.resistance), "want_f": m_fire, "hrg_2h6m": hrg_2h6m})
	XTianqiSuits.reload_template({})

	# === 搭配 3：同一件装备四步（裸装 +35% → 做成符文之语 → 镶宝珠 → 换 +50% 武器） ===
	var rw_recipe := {}
	for r in XDB.table("Runewords"):
		if r is Dictionary and not (r.get("materials", []) as Array).is_empty() and int(r.get("weapon", 0)) > 0:
			var tw := XDB.rec("Weapons", int(r.get("weapon", 0)))
			if float(tw.get("yep", {}).get("elementAmplify", {}).get("2", 0.0)) > 0.0:
				rw_recipe = r
				break
	var orb_gem := {}
	for it in XDB.table("Items"):
		if it is Dictionary and str(it.get("note", "")).to_upper().contains("ELEMENT AMPLIFY 2:"):
			orb_gem = it
			break
	var w3 := {"kind": "weapon", "id": 99640, "base": 1, "wtypeId": int(rw_recipe.weaponTypes[0]), "etypeId": 1,
		"params": [0, 0, 200, 0, 200, 0, 0, 0], "traits": [], "note": "", "meta": {},
		"yep": {"elementAmplify": {"2": 0.35}}, "augmentSlots": ["武器宝珠"], "augmentSlotItems": []}
	_put_equips(a, [w3])
	var s3_1 := XDamage.calculate(sk_fire, a, foe, {"critical": false, "variance": false, "rawValue": 10000.0})
	var by3_1: Dictionary = a.passive_cache().get("bySource", {}).get("elementAmplify", {}).get(2, {}).duplicate(true)
	# Step 2: 做成符文之语（如「烛火」+25% 火增伤）
	var tpl_w := XDB.rec("Weapons", int(rw_recipe.weapon))
	var w3_rw := w3.duplicate(true)
	w3_rw["runewords"] = [int(rw_recipe.id)]
	w3_rw["runewordName"] = str(tpl_w.get("name", ""))
	w3_rw["note"] = str(tpl_w.get("note", ""))
	w3_rw["meta"] = tpl_w.get("meta", {}).duplicate(true)
	var rw_e2 := float(tpl_w.get("yep", {}).get("elementAmplify", {}).get("2", 0.0))
	w3_rw["yep"]["elementAmplify"]["2"] = 0.35 + rw_e2
	_put_equips(a, [w3_rw])
	var s3_2 := XDamage.calculate(sk_fire, a, foe, {"critical": false, "variance": false, "rawValue": 10000.0})
	var by3_2: Dictionary = a.passive_cache().get("bySource", {}).get("elementAmplify", {}).get(2, {}).duplicate(true)
	# Step 3: 镶火宝珠（如「诺彼修的烈焰」+2% 火增伤）
	var w3_orb := w3_rw.duplicate(true)
	var orb_e2 := 0.0
	if not orb_gem.is_empty():
		w3_orb["augmentSlotItems"] = ["item %d" % int(orb_gem.id)]
		orb_e2 = float(XTianqiLedger.orb_amplify(w3_orb).get("2", 0.0))
		w3_orb["yep"]["elementAmplify"]["2"] = 0.35 + rw_e2 + orb_e2
	_put_equips(a, [w3_orb])
	var s3_3 := XDamage.calculate(sk_fire, a, foe, {"critical": false, "variance": false, "rawValue": 10000.0})
	var by3_3: Dictionary = a.passive_cache().get("bySource", {}).get("elementAmplify", {}).get(2, {}).duplicate(true)
	# Step 4: 把 +35% 武器换成 +50% 武器（保留符文之语与宝珠）
	var w3_50 := w3_orb.duplicate(true)
	w3_50["yep"]["elementAmplify"]["2"] = 0.50 + rw_e2 + orb_e2
	_put_equips(a, [w3_50])
	var s3_4 := XDamage.calculate(sk_fire, a, foe, {"critical": false, "variance": false, "rawValue": 10000.0})
	var by3_4: Dictionary = a.passive_cache().get("bySource", {}).get("elementAmplify", {}).get(2, {}).duplicate(true)
	print("T530_COMBO3|step1=%s|step2=%s|step3=%s|step4=%s|dmg=[%.0f,%.0f,%.0f,%.0f]" % [
		JSON.stringify(by3_1), JSON.stringify(by3_2), JSON.stringify(by3_3), JSON.stringify(by3_4),
		float(s3_1.value), float(s3_2.value), float(s3_3.value), float(s3_4.value)])
	_check("t6_combo3_four_steps_sources_clean",
		rw_e2 > 0.0 and orb_e2 > 0.0
		and _near(float(by3_1.get("equip", 0.0)), 0.35)
		and _near(float(by3_2.get("equip", 0.0)), 0.35)
		and _near(float(by3_2.get("runeword", 0.0)), rw_e2)
		and _near(float(by3_3.get("equip", 0.0)), 0.35)
		and _near(float(by3_3.get("runeword", 0.0)), rw_e2)
		and _near(float(by3_3.get("orb", 0.0)), orb_e2)
		and _near(float(by3_4.get("equip", 0.0)), 0.50)
		and _near(float(by3_4.get("runeword", 0.0)), rw_e2)
		and _near(float(by3_4.get("orb", 0.0)), orb_e2),
		{"rw_e2": rw_e2, "orb_e2": orb_e2, "s1": by3_1, "s2": by3_2, "s3": by3_3, "s4": by3_4})

	# === 搭配 4：双动多段加斩杀（再释放 20%＋回合预算 1 次＋再动＋连击＋免费行动） ===
	var items_c4 := [{"kind": "weapon", "id": 99650, "wtypeId": 1, "etypeId": 1, "params": [0, 0, 200, 0, 0, 0, 0, 0],
		"traits": [], "note": "", "meta": {},
		"tianqi_affixes": [_x("recast", 4, "perfect"), _x("recast", 4, "perfect"), _x("recast", 4, "perfect"), _x("recast", 4, "perfect"),
			_x("reaction", 4, "perfect"), _x("combo", 4, "perfect"), _x("lifesteal", 4, "perfect")]}]
	_put_equips(a, items_c4)
	XTianqiAffixBattle.start(lg)
	if lg.has_meta(XTianqiLedger.BUDGET_META):
		lg.remove_meta(XTianqiLedger.BUDGET_META)
	lg._acted[a] = 1
	lg.current_order.clear()
	var c4_recast_pct := float(XTianqiAffixBattle.personal(a).get("recast", 0.0))
	var c4_extra1 := XTianqiLedger.take_extra(lg, a, "affix.recast", true)
	var c4_extra2 := XTianqiLedger.take_extra(lg, a, "affix.recast", true)
	var c4_combo := XTianqiAffixBattle.attack_times(a)
	XTianqiLedger.note_free(lg, a)
	print("T530_COMBO4|recast_cap=%.0f%%|extra1=%s|extra2=%s|combo=+%.0f" % [c4_recast_pct, str(c4_extra1), str(c4_extra2), c4_combo])
	_check("t6_combo4_extra_action_budget", _near(c4_recast_pct, 20.0) and c4_extra1 and not c4_extra2 and _near(c4_combo, 1.0))

	# === 搭配 5：词条配法（8 条四阶极品特效：最优 4/1/1/2 vs 均分 2/2/2/2 vs 双押 4/0/0/4 × 敌暴闪 0/20/40% × 传说位） ===
	var eval_build := func(affs: Array, cev: float) -> float:
		_put_equips(a, [{"kind": "armor", "id": 99660, "etypeId": 3, "params": [0, 0, 0, 0, 0, 0, 0, 0],
			"traits": [], "note": "", "meta": {}, "tianqi_affixes": affs}])
		XTianqiAffixBattle.start(lg)
		XTianqiAffixBattle.begin_action(lg, a, sk_fire)
		var r_nc := XDamage.calculate(sk_fire, a, foe, {"critical": false, "variance": false, "rawValue": 10000.0})
		var r_cr := XDamage.calculate(sk_fire, a, foe, {"critical": true, "variance": false, "rawValue": 10000.0})
		XTianqiAffixBattle.end_action(lg, a, sk_fire)
		var cri := clampf(a.cri - cev, 0.0, 1.0)
		return float(r_nc.value) * (1.0 - cri) + float(r_cr.value) * cri
	var opt := [_x("skill_damage"), _x("skill_damage"), _x("skill_damage"), _x("skill_damage"),
		_x("element_damage", 4, "perfect", {"element": "fire"}), _x("final_damage"),
		_x("crit_damage"), _x("crit_damage")]
	var even := [_x("skill_damage"), _x("skill_damage"),
		_x("element_damage", 4, "perfect", {"element": "fire"}), _x("element_damage", 4, "perfect", {"element": "fire"}),
		_x("final_damage"), _x("final_damage"), _x("crit_damage"), _x("crit_damage")]
	var dual2 := [_x("skill_damage"), _x("skill_damage"), _x("skill_damage"), _x("skill_damage"),
		_x("crit_damage"), _x("crit_damage"), _x("crit_damage"), _x("crit_damage")]
	var swap_rc := opt.slice(0, 6) + [_x("recast"), _x("lifesteal")]
	var c5_ok := true
	for cev in [0.0, 0.20, 0.40]:
		var v_opt: float = eval_build.call(opt, cev)
		var v_even: float = eval_build.call(even, cev)
		var v_dual: float = eval_build.call(dual2, cev)
		var v_fs: float = eval_build.call(opt + [_x("first_strike")], cev)
		var v_swap: float = eval_build.call(swap_rc, cev)
		var rc_rate := float(XTianqiAffixTable.value("recast", 4, "perfect")) / 100.0
		var v_swap_exp := v_swap * (1.0 + rc_rate)
		print("T530_COMBO5|cev=%.0f%%|opt=%.0f|even=%.0f|dual=%.0f|opt+fs=%.0f|swap_rc_exp=%.0f" % [
			cev * 100.0, v_opt, v_even, v_dual, v_fs, v_swap_exp])
		if not (v_opt > 0.0 and v_even > 0.0 and v_fs > v_opt):
			c5_ok = false
	_check("t6_combo5_affix_distributions", c5_ok)
	lg.end_battle(0)


# ---- 7. 只改天启篇，西游档零改动（XTianqi.active 守卫） ----
func _test_7_xiyou_untouched() -> void:
	var s := _state(false)
	var a := s.actor(int(s.battle_slots[0]))
	var e := XEnemy.new().setup(1, 3, 100.0)
	# 武器 94 在西游档仍是 0.0（完全免疫）
	_put_equips(a, [XActor.make_equip("weapon", 94)])
	_check("t7_xiyou_weapon94_still_immune", _near(a.element_rate(1), 0.0), a.element_rate(1))
	# 角色 113 黑猫猫在西游档仍是 0.30（自带回复不封 10%）
	s.add_actor(113)
	var cat_x := s.actor(113)
	_clear_equips(cat_x)
	_check("t7_xiyou_actor113_hrg_30", _near(cat_x.hrg, 0.30), cat_x.hrg)
	# 西游档敌人固定减伤不清、不转无视防御、不建 bySource、文案照旧
	var harm_st := 0
	for st in XDB.table("States"):
		if st is Dictionary and str(st.get("note", "")).contains("<passiveHarmRe02:"):
			harm_st = int(st.id)
			break
	if harm_st > 0:
		e.add_state(harm_st)
	var w_pen := {"kind": "weapon", "id": 99701, "wtypeId": 1, "etypeId": 1, "params": [0, 0, 500, 0, 500, 0, 0, 0],
		"traits": [], "note": "<DepassiveHarmRe02: 50%>", "meta": {}, "yep": {}}
	_put_equips(a, [w_pen])
	var sk := _skill(99702, 2, 2, "10000")
	var rx := XDamage.calculate(sk, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	var lines := []
	XHelpCard._pierce_lines(lines, "<DepassiveHarmRe02: 500><DepassiveHarmRe02: 50%>")
	var txt_x := "\n".join(lines)
	_check("t7_xiyou_flat_mit_and_text_untouched",
		not a.passive_cache().has("bySource")
		and not rx.breakdown.row.has("defIgnore")
		and not rx.breakdown.row.has("suit")
		and (harm_st == 0 or float(rx.breakdown.row.fixedMitigation) > 0.0)
		and not txt_x.contains("天启篇")
		and txt_x.contains("穿透合计≥100%才能击破完全免疫"),
		{"flat": rx.breakdown.row.fixedMitigation, "txt": txt_x, "row_keys": rx.breakdown.row.keys()})


# ---- 8. T529 核 P2-1：suit_mult 记入 breakdown.row.suit、pools residual.suitMultiplier 与 audit ----
func _test_8_t529_suit_mult_ledger() -> void:
	var lg := _logic(true)
	var a: XActor = lg.actors[0]
	var foe: XEnemy = lg.enemies[0]
	a.change_level(80)
	# 穿 3 件 23 号「所有伤害板甲」（T529 模板套攻·伤害，3 件四阶 +10% → ×1.10）
	var pieces := []
	for i in 3:
		pieces.append({"kind": "armor", "id": 99800 + i, "etypeId": 3 + i, "params": [0, 0, 0, 0, 0, 0, 0, 0],
			"traits": [], "note": "", "meta": {"req_level": "75"}, "equipment": {"suits": [23]}})
	_put_equips(a, pieces)
	XTianqiLedger.violations.clear()
	var sk := _skill(99801, 2, 2, "10000")
	var res := XDamage.calculate(sk, a, foe, {"critical": false, "variance": false, "rawValue": 10000.0})
	var row: Dictionary = res.breakdown.row
	_check("t8_t529_suit_mult_in_row_and_residual",
		_near(float(row.get("suit", 0.0)), 1.10)
		and _near(float(row.get("residual", {}).get("suitMultiplier", 0.0)), 1.10)
		and XTianqiLedger.violations.is_empty(),
		{"suit": row.get("suit"), "res": row.get("residual"), "viol": XTianqiLedger.violations})
	lg.end_battle(0)


# ---- 9. T530 R2（核查 P1-1／验收 9）：角色自带终伤硬顶 +30%，T528 贝吉特三态同挂兜底；超越极限 I～IV 不算 ----
func _test_9_self_cap_t528() -> void:
	var s := _state(true)
	s.add_actor(164)
	var v := s.actor(164)
	v.change_level(80)
	_clear_equips(v)
	v.clear_states()
	for id in [2770, 2771, 2776]:  # 五十倍界王拳 +15、超赛 1 +10、自我极意功 +10（T528 重标）：正常切形态互斥，这里强挂三态
		v.add_state(id)
	v.refresh_passive()
	var forms := [2770, 2771, 2776].filter(func(id): return v.is_state_affected(id))
	var raw := float(v.passive_cache().get("globalHarmRi", 0.0))
	var e := XEnemy.new().setup(1, 3, 100.0)
	var sk := _skill(99901, 2, 2, "10000")
	var r := XDamage.calculate(sk, v, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	var row: Dictionary = r.breakdown.row
	var sc: Dictionary = row.get("splitCap", {}).get("self", {})
	_check("t9_three_forms_cohang_bonus_capped_30",
		forms.size() == 3 and _near(raw, 0.35) and _near(float(row.pools.bonus), 1.30) and _near(float(sc.get("bonus", 0.0)), 0.05),
		{"forms": forms, "raw": raw, "pools": row.pools, "splitCap": row.get("splitCap")})
	# 超越极限 I（1240，+5% 终伤）单记 advance 桶，不吃自带上限：1.30＋0.05
	v.learn_skill(1240)
	v.refresh_passive()
	var by_g: Dictionary = v.passive_cache().get("bySource", {}).get("globalHarmRi", {})
	var r2 := XDamage.calculate(sk, v, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	_check("t9_shared_advance_outside_self_cap",
		_near(float(by_g.get("advance", 0.0)), 0.05) and _near(float(r2.breakdown.row.pools.bonus), 1.35),
		{"by": by_g, "pools": r2.breakdown.row.pools})
	v.forget_skill(1240)
	# 正常互斥后（超蓝 2774 +20、自我极意功 +10）恰好 30%：不扣
	v.clear_states()
	v.add_state(2776)
	v.add_state(2774)
	v.refresh_passive()
	var r3 := XDamage.calculate(sk, v, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	_check("t9_at_cap_not_cut", _near(float(r3.breakdown.row.pools.bonus), 1.30) and not r3.breakdown.row.get("splitCap", {}).has("self"),
		{"pools": r3.breakdown.row.pools, "splitCap": r3.breakdown.row.get("splitCap")})
	# 开关关＝回到只靠数据重标、不兜底
	v.clear_states()
	for id in [2770, 2771, 2776]:
		v.add_state(id)
	v.refresh_passive()
	XTianqiLedger.SELF_CAP = false
	var r4 := XDamage.calculate(sk, v, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	XTianqiLedger.SELF_CAP = true
	_check("t9_switch_off_rollback", _near(float(r4.breakdown.row.pools.bonus), 1.35), r4.breakdown.row.pools)
	# 爆伤自带 +50%、技能自带 +30%：本体状态备注塞超额时同样兜底
	v.clear_states()
	var fake := {"id": 99902, "name": "t530 自带超额", "note": "<passiveCrHarmRi:70%><SkillTypesDvupA:45%>", "meta": {}, "traits": []}
	var cut := {"skill": 0.0, "bonus": 0.0, "crit": 0.0, "element": {}}
	var by_fake := XTianqiLedger.passive_buckets(v, [fake])
	var hit := {"types": ["A"], "wtypes": [], "skill": 99901, "pass_pooled": false}
	var out := XTianqiLedger._self_cap(by_fake, hit, cut)
	_check("t9_self_cap_crit_50_skill_30", _near(float(out.get("crit", 0.0)), 0.20) and _near(float(out.get("skill", 0.0)), 0.15), out)


# ---- 10. T530 R2（核查 P1-2）：技能追加施放也走吸血单次 20% 预算（跨段、跨目标），新的一次施放另起 ----
func _test_10_follow_cast_lifesteal() -> void:
	var lg := _logic(true)
	var a: XActor = lg.actors[0]
	a.change_level(80)
	var ls_eq := {"kind": "weapon", "id": 99121, "wtypeId": 1, "etypeId": 1, "params": [0, 0, 100, 0, 0, 0, 0, 0],
		"traits": [], "note": "", "meta": {}, "tianqi_affixes": [_x("lifesteal", 4, "perfect")]}
	_put_equips(a, [ls_eq])
	XTianqiAffixBattle.start(lg)
	var foes := []
	for i in 5:
		foes.append(XEnemy.new().setup(1, 3, 100.0))
	var sk := _skill(99903, 2, 2, "10000")
	var cast_cap := floorf(a.mhp * 0.20)
	# 主施放：打 1 段吸到 10%
	a.hp = 1.0
	XTianqiAffixBattle.begin_action(lg, a, sk)
	XTianqiAffixBattle.after_apply(lg, a, sk, foes[0], {"hp": 1.0e9})
	XTianqiAffixBattle.end_action(lg, a, sk)
	var hp_main := a.hp
	# 技能追加窗口（XTianqiSkills.end_action 里 depth+1 → _cast_run → logic.apply）：五个目标各两段
	var fs := XTianqiSkills._fstore(lg)
	fs.depth = int(fs.depth) + 1
	var follow := _skill(99904, 2, 2, "10000")
	a.hp = 1.0
	for t in foes:
		for seg in 2:
			XTianqiAffixBattle.after_apply(lg, a, follow, t, {"hp": 1.0e9})
	var hp_follow := a.hp
	fs.depth = int(fs.depth) - 1
	# 下一次行动的追加另起一份
	lg._acted[a] = int(lg._acted.get(a, 0)) + 1
	fs.depth = int(fs.depth) + 1
	a.hp = 1.0
	XTianqiAffixBattle.after_apply(lg, a, follow, foes[0], {"hp": 1.0e9})
	var hp_next := a.hp
	fs.depth = int(fs.depth) - 1
	var hit_cap := floorf(a.mhp * 0.10)
	_check("t10_follow_cast_lifesteal_capped_20",
		_near(hp_main - 1.0, hit_cap) and _near(hp_follow - 1.0, cast_cap) and _near(hp_next - 1.0, hit_cap),
		{"mhp": a.mhp, "main": hp_main, "follow": hp_follow, "next": hp_next, "cast_cap": cast_cap})
	lg.end_battle(0)


# ---- 11. T530 R2（核查 P2-1）：开关全关时系别法宝回到旧合用顶（＋10% 法宝＋30% 武器封到 30%） ----
func _test_11_all_off_fabao_old_cap() -> void:
	var s := _state(true)
	var a := s.actor(int(s.battle_slots[0]))
	a.change_level(80)
	var e := XEnemy.new().setup(1, 3, 100.0)
	var sk := _skill(99905, 2, 2, "10000")
	var fabao := XActor.make_equip("armor", 4544)
	var w_fire := {"kind": "weapon", "id": 1, "base": 1, "wtypeId": 1, "etypeId": 1,
		"params": [0, 0, 100, 0, 100, 0, 0, 0], "traits": [], "note": "", "meta": {},
		"yep": {"elementAmplify": {"2": 0.30}}}
	XTianqiLedger.SPLIT_CAPS = false
	XTianqiLedger.REBUILD_SOURCES = false
	XTianqiLedger.ELEM_RESIST_CAP = false
	XTianqiLedger.NO_ENEMY_FLAT_MIT = false
	XTianqiLedger.SELF_CAP = false
	XTianqiAffixBattle.CAPS_V16 = false
	XTianqiAffixBattle.RESIST_PER_ELEMENT = false
	_put_equips(a, [w_fire, fabao])
	var r := XDamage.calculate(sk, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	XTianqiLedger.SPLIT_CAPS = true
	XTianqiLedger.REBUILD_SOURCES = true
	XTianqiLedger.ELEM_RESIST_CAP = true
	XTianqiLedger.NO_ENEMY_FLAT_MIT = true
	XTianqiLedger.SELF_CAP = true
	XTianqiAffixBattle.CAPS_V16 = true
	XTianqiAffixBattle.RESIST_PER_ELEMENT = true
	_put_equips(a, [w_fire, fabao])
	var r_on := XDamage.calculate(sk, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	_check("t11_all_off_fabao_back_to_old_cap",
		_near(float(r.breakdown.row.pools.element), 1.30) and _near(float(r_on.breakdown.row.pools.element), 1.40),
		{"off": r.breakdown.row.pools, "on": r_on.breakdown.row.pools})


# ---- 12. T530 R2（核查 P2-2）：小猫持剑翻倍视图里符文之语模板份额按倍数扣，不把翻倍的那份算给装备本体 ----
func _test_12_cat_sword_rebuild() -> void:
	var s := _state(true)
	s.add_actor(XCat.ACTOR)
	var c := s.actor(XCat.ACTOR)
	c.change_level(80)
	if not c.skill_ids.has(XCat.SKILL_SWORD):
		c.learn_skill(XCat.SKILL_SWORD)
	var pick := {}
	var tpl_amp := 0.0
	for r in XDB.table("Runewords"):
		if not r is Dictionary or int(r.get("weapon", 0)) <= 0:
			continue
		var probe := {"kind": "weapon", "id": 99906, "base": 1, "wtypeId": XCat.SWORD_WTYPE, "etypeId": 1, "runewords": [int(r.id)]}
		var tpl := XTianqiLedger._runeword_template(probe)
		var v := float(tpl.get("yep", {}).get("elementAmplify", {}).get("2", 0.0))
		if v > 0.0:
			pick = r
			tpl_amp = v
			break
	if pick.is_empty():
		_check("t12_cat_sword_runeword_doubled", false, "没找到带火系元素增幅模板的符文之语")
		return
	var sword := {"kind": "weapon", "id": 99906, "base": 1, "wtypeId": XCat.SWORD_WTYPE, "etypeId": 1,
		"params": [0, 0, 100, 0, 0, 0, 0, 0], "traits": [], "note": "", "meta": {},
		"yep": {"elementAmplify": {"2": tpl_amp}}, "runewords": [int(pick.id)]}
	_put_equips(c, [sword])
	var by: Dictionary = c.passive_cache().get("bySource", {}).get("elementAmplify", {}).get(2, {})
	_check("t12_cat_sword_runeword_doubled",
		XCat.enabled_sword(c) and _near(float(by.get("runeword", 0.0)), tpl_amp * 2.0) and absf(float(by.get("equip", 0.0))) < 1e-6,
		{"by": by, "tpl": tpl_amp, "sword": XCat.enabled_sword(c)})
