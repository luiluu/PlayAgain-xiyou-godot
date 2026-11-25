extends Node
## T472 西游档阿夜专属装备「元素之王的赐福」（XElementalKing）专项验证与数值木桩对照。
## 覆盖：数据库定义、全职业穿戴与 60 级需求、定稿图标、爆出随机八大元素＋头顶式随机词条、
## 存档读回持久化（含 XSaveSlim）、60/80/99 级成长面板、流萤式双元素战斗伤害、
## 二层深渊全部【未知存在】固定 1/888 掉落（不吃掉率加成、不吃屏蔽、drop_lock 放行）、
## 天启篇零改动、回退开关 ENABLED=false，以及与同栏顶级「特殊[泰坦]」5203 的 60/80/99 级木桩对照。
## 加 `-- --out=<目录>`（窗口模式）可另输出实机详情卡与装备页截图。
const TestEnv = preload("res://tests/xiyou_test_env.gd")


class DummyTarget:
	extends XEnemy
	var custom_rates := {}

	func element_rate(e: int) -> float:
		if custom_rates.has(e):
			return float(custom_rates[e])
		return 1.0


var checks := 0
var failures: Array = []
var out_dir := ""
var print_bench := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg == "--bench":
			print_bench = true
	_run.call_deferred()


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 30:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(600))


func _new_xiyou_state() -> XState:
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	s.actor_max_level = 99
	return s


func _make_dummy(rates := {}) -> DummyTarget:
	var d := DummyTarget.new()
	d.setup(1, 2, 100.0)
	d.custom_rates = rates
	return d


func _make_blessing(s: XState, elem_id: int, force_affix_id := 0, variance_roll := 0.5) -> Dictionary:
	var item := XGear.template("armor", XElementalKing.ARMOR)
	if force_affix_id > 0:
		var af := XDB.rec("Armors", force_affix_id)
		XGear.combine(item, af, "prefix")
		item.affixIds.append({"table": "Armors", "id": force_affix_id, "kind": "prefix"})
	XGear._apply_note_params(item)
	var v := int(item.get("meta", {}).get("Random Variance", XElementalKing.PARAM_VARIANCE))
	for i in range(8):
		if float(item.params[i]) != 0.0:
			item.params[i] = maxf(0.0, float(item.params[i]) + floorf(variance_roll * (v * 2 + 1) - v))
	item.upgradeSlots = 6
	item.originalUpgradeSlots = 6
	item.baseName = str(item.name)
	XElementalKing.assign_element(item, elem_id)
	s.register_gear(item)
	return item


func _make_titan(s: XState, prefix_id: int, variance_roll := 0.5) -> Dictionary:
	var item := XGear.template("armor", 5203)
	var af := XDB.rec("Armors", prefix_id)
	XGear.combine(item, af, "prefix")
	item.affixIds.append({"table": "Armors", "id": prefix_id, "kind": "prefix"})
	XGear._apply_note_params(item)
	var v := int(item.get("meta", {}).get("Random Variance", 5000))
	for i in range(8):
		if float(item.params[i]) != 0.0:
			item.params[i] = maxf(0.0, float(item.params[i]) + floorf(variance_roll * (v * 2 + 1) - v))
	item.upgradeSlots = 6
	item.originalUpgradeSlots = 6
	item.baseName = str(item.name)
	s.register_gear(item)
	return item


func _equip_form(a: XActor, item) -> void:
	var slot := a.equip_slots().find(XElementalKing.ETYPE)
	if slot >= 0:
		a.equips[slot] = item
		a.refresh_passive()
		a.param_mark_dirty()


func _test_definition_and_icon() -> void:
	var s := _new_xiyou_state()
	var rec := XDB.rec("Armors", XElementalKing.ARMOR)
	check("def_exists", not rec.is_empty(), rec.size())
	check("def_name", str(rec.get("name", "")) == "元素之王的赐福", rec.get("name"))
	check("def_desc_exact", str(rec.get("description", "")) == "形态\n纪念群友大手子首通洪荒的特殊装备。\n他亲自为大家向元素之王争取来的福利。", rec.get("description"))
	check("def_etype_form", int(rec.get("etypeId", 0)) == 19, rec.get("etypeId"))
	check("def_atype_universal", int(rec.get("atypeId", 0)) == 5, rec.get("atypeId"))
	check("def_req_level_60", int(rec.get("meta", {}).get("req_level", 0)) == 60, rec.get("meta", {}).get("req_level"))
	check("def_quality_12", XQuality.legacy(rec) == 12 and XQuality.grade_name(rec) == "神话", [XQuality.legacy(rec), XQuality.grade_name(rec)])
	check("def_variance_nonzero", int(rec.get("equipment", {}).get("variance", 0)) == XElementalKing.PARAM_VARIANCE, rec.get("equipment", {}).get("variance"))
	var crown := XDB.rec("Armors", XDemonCrown.ARMOR)
	var b_aff: Array = rec.get("equipment", {}).get("affixes", [])
	var c_aff: Array = crown.get("equipment", {}).get("affixes", [])
	var affix_same: bool = b_aff.size() == 1 and c_aff.size() == 1 and str(b_aff[0].kind) == str(c_aff[0].kind) and (b_aff[0].choices as Array).size() == (c_aff[0].choices as Array).size()
	if affix_same:
		for ci in range(b_aff[0].choices.size()):
			var bc: Dictionary = b_aff[0].choices[ci]
			var cc: Dictionary = c_aff[0].choices[ci]
			if int(bc.chance) != int(cc.chance) or (bc.ids as Array).map(func(x): return int(x)) != (cc.ids as Array).map(func(x): return int(x)):
				affix_same = false
	check("def_affixes_match_crown", affix_same, [b_aff.size(), c_aff.size()])
	var tex := XUI.icon_texture(XElementalKing.ICON)
	check("icon_32_loaded", tex != null and tex.get_size() == Vector2(32, 32), tex.get_size() if tex != null else null)
	var large := XItemStatusPainter.large_icon(XElementalKing.ICON)
	check("icon_128_loaded", large != null and large.get_size() == Vector2(128, 128), large.get_size() if large != null else null)
	var inst := _make_blessing(s, 2)
	for aid in [1, 29, 55]:
		var a: XActor = s.actor(aid)
		a._lv = 59
		a.refresh_passive()
		check("req_lv59_blocked_%d" % aid, not a.can_equip(inst), [aid, a._lv])
		a._lv = 60
		a.refresh_passive()
		check("req_lv60_allowed_%d" % aid, a.can_equip(inst), [aid, a._lv])


func _test_roll_and_save_persistence() -> void:
	var s := _new_xiyou_state()
	var seen_elems := {}
	var seen_q := {}
	var seen_params := {}
	XGear.force_roll = -1.0
	XGear.roll_seq = []
	for k in range(320):
		var it := XGear.create("armor", XElementalKing.ARMOR, s)
		var eid := XElementalKing.element_of(it)
		check("roll_elem_valid_%d" % k, XElementalKing.ELEMENTS.has(eid), eid)
		seen_elems[eid] = true
		seen_q[XQuality.legacy(it)] = true
		seen_params[int(it.params[2])] = true
		check("roll_note_has_elem_%d" % k, str(it.note).contains("赐福元素：" + XElementalKing.element_name(eid)) and not str(it.note).contains(XElementalKing.ELEM_PLACEHOLDER), str(it.note).left(240))
		check("roll_name_kept_%d" % k, str(it.name) == "元素之王的赐福", it.name)
	check("roll_covers_all_13_elements", seen_elems.size() == 13, seen_elems.keys())
	check("roll_excludes_phys_and_heal", not seen_elems.has(1) and not seen_elems.has(10), seen_elems.keys())
	check("roll_has_mythic_or_chaos_tiers", seen_q.has(12) and seen_q.has(14) and seen_q.has(15), seen_q.keys())
	check("roll_has_param_variance", seen_params.size() > 10, seen_params.size())

	var bag_fire := _make_blessing(s, 2, 4801, 0.25)
	var worn_void := _make_blessing(s, 11, 4900, 0.75)  # 虚空(11) + 混沌词条 4900
	s.gear.append(bag_fire)
	var a: XActor = s.actor(1)
	a._lv = 60
	a.refresh_passive()
	_equip_form(a, worn_void)
	var save_path := XSave.path(29)
	XSave.save(29)
	var orig_bag_params: Array = bag_fire.params.duplicate()
	var orig_worn_params: Array = worn_void.params.duplicate()
	var orig_worn_note := str(worn_void.note)
	XState.current = null
	var ok := XSave.load_slot(29)
	check("save_load_ok", ok, save_path)
	if not ok:
		return
	var loaded := XState.current
	var found_bag := {}
	for g in loaded.gear:
		if XElementalKing.is_blessing(g):
			found_bag = g
			break
	var la: XActor = loaded.actor(1)
	var form_slot := la.equip_slots().find(XElementalKing.ETYPE)
	var found_worn: Dictionary = la.equips[form_slot] if form_slot >= 0 and la.equips[form_slot] is Dictionary else {}
	check("save_bag_elem_kept", XElementalKing.element_of(found_bag) == 2 and XQuality.legacy(found_bag) == 14, [XElementalKing.element_of(found_bag), XQuality.legacy(found_bag)])
	check("save_bag_params_kept", found_bag.get("params") == orig_bag_params, [found_bag.get("params"), orig_bag_params])
	check("save_worn_elem_kept", XElementalKing.element_of(found_worn) == 11 and XQuality.legacy(found_worn) == 15, [XElementalKing.element_of(found_worn), XQuality.legacy(found_worn)])
	check("save_worn_params_kept", found_worn.get("params") == orig_worn_params, [found_worn.get("params"), orig_worn_params])
	check("save_worn_note_kept", str(found_worn.get("note", "")) == orig_worn_note, "note_mismatch")
	DirAccess.remove_absolute(save_path)


func _test_level_growth() -> void:
	var s := _new_xiyou_state()
	var a: XActor = s.actor(1)
	for i in range(a.equips.size()):
		a.equips[i] = null
	var inst := _make_blessing(s, 2, 0, 0.5)
	for lv in [60, 80, 99]:
		a._lv = lv
		_equip_form(a, null)
		var base_plus := []
		for i in range(8):
			base_plus.append(a.param_plus(i))
		_equip_form(a, inst)
		for i in range(8):
			var delta := a.param_plus(i) - float(base_plus[i])
			var expected := float(inst.params[i]) + float(XElementalKing.GROWTH_PER_LEVEL[i]) * float(lv)
			check("growth_lv%d_p%d" % [lv, i], absf(delta - expected) < 0.01, [delta, expected])


func _test_dual_element_combat() -> void:
	var s := _new_xiyou_state()
	var a: XActor = s.actor(1)
	a._lv = 60
	a.refresh_passive()
	var fire_blessing := _make_blessing(s, 2, 0, 0.5)
	_equip_form(a, fire_blessing)

	var phys_skill := XDB.rec("Skills", 72)  # 仁义剑法（真实物理技能，hitType=1, elementId=1, pure 公式）
	check("elem_phys_adds_fire", XDamage.action_elements(phys_skill, a) == [1, 2], XDamage.action_elements(phys_skill, a))
	check("orig_phys_adds_fire", XDamage.original_elements(phys_skill, a) == [1, 2], XDamage.original_elements(phys_skill, a))

	var normal_atk := XDB.rec("Skills", 1)
	var na_es := XDamage.action_elements(normal_atk, a)
	check("elem_normal_atk_dual", na_es.has(1) and na_es.has(2), na_es)

	var ice_skill := {"id": 999002, "name": "测试冰攻", "stypeId": 1, "hitType": 2, "damage": {"type": 1, "elementId": 3, "formula": "a.mat * 4", "variance": 0, "critical": false}}
	check("elem_ice_adds_fire", XDamage.action_elements(ice_skill, a) == [3, 2], XDamage.action_elements(ice_skill, a))

	var fire_skill := {"id": 999003, "name": "测试火攻", "stypeId": 1, "hitType": 2, "damage": {"type": 1, "elementId": 2, "formula": "a.mat * 4", "variance": 0, "critical": false}}
	check("elem_fire_dedup", XDamage.action_elements(fire_skill, a) == [2], XDamage.action_elements(fire_skill, a))

	var non_elem_skill := {"id": 999004, "name": "测试无属", "stypeId": 1, "hitType": 1, "damage": {"type": 1, "elementId": 0, "formula": "a.atk * 4", "variance": 0, "critical": false}}
	check("elem_none_keeps_zero", XDamage.action_elements(non_elem_skill, a) == [0, 2], XDamage.action_elements(non_elem_skill, a))

	var heal_skill := {"id": 999005, "name": "测试治疗", "stypeId": 1, "hitType": 0, "damage": {"type": 3, "elementId": 10, "formula": "a.mat * 2", "variance": 0, "critical": false}}
	check("elem_heal_untouched", XDamage.action_elements(heal_skill, a) == [10], XDamage.action_elements(heal_skill, a))

	var dummy := _make_dummy({1: 0.25, 2: 1.0})
	var res_dual := XDamage.calculate(phys_skill, a, dummy, {"variance": false, "preview": true})
	check("combat_picks_fire_over_phys_resist", int(res_dual.breakdown.row.element) == 2, res_dual.breakdown.row)
	XElementalKing.ENABLED = false
	var res_off := XDamage.calculate(phys_skill, a, dummy, {"variance": false, "preview": true})
	XElementalKing.ENABLED = true
	check("rollback_disables_dual", int(res_off.breakdown.row.element) == 1 and float(res_dual.value) > float(res_off.value) * 1.5, [res_dual.value, res_off.value, res_off.breakdown.row.element])

	var fire_immune := _make_dummy({2: 0.0})
	var res_immune := XDamage.calculate(non_elem_skill, a, fire_immune, {"variance": false, "preview": true, "rawValue": a.atk * 10.0})
	check("non_elem_safe_vs_fire_immune", float(res_immune.value) > 0.0 and int(res_immune.breakdown.row.element) == 0, [res_immune.value, res_immune.breakdown.row.element])

	# 特殊活跃元素（风 15）同样生效流萤式双元素
	var wind_blessing := _make_blessing(s, 15, 0, 0.5)
	_equip_form(a, wind_blessing)
	check("elem_phys_adds_wind", XDamage.action_elements(phys_skill, a) == [1, 15], XDamage.action_elements(phys_skill, a))
	var res_wind := XDamage.calculate(phys_skill, a, _make_dummy({1: 0.2, 15: 1.0}), {"variance": false, "preview": true})
	check("combat_picks_wind_over_phys_resist", int(res_wind.breakdown.row.element) == 15, res_wind.breakdown.row)


func _test_abyss_drops_and_tianqi_guard() -> void:
	var unk_count := 0
	for e in XDB.table("Enemies"):
		if e is Dictionary and str(e.get("name", "")).contains("【未知存在】"):
			unk_count += 1
			var xe := XEnemy.new().setup(int(e.id), 2, 100.0)
			check("unk_enemy_recog_%d" % int(e.id), XElementalKing.is_unknown_enemy(xe), e.name)
	check("unk_enemy_total_53", unk_count == 53, unk_count)
	for mid in XYunshangOrders.UNKNOWN.keys():
		check("unk_map_recog_%d" % int(mid), XElementalKing.is_unknown_abyss_map(int(mid)), mid)
	for bad_mid in [4, 87, 92, 93, 94, 105]:
		check("non_abyss_map_excluded_%d" % bad_mid, not XElementalKing.is_unknown_abyss_map(bad_mid), bad_mid)

	var s := _new_xiyou_state()
	s.map_id = 152
	var hits := 0
	var hit_seed := ""
	# 轻量构造一次战斗后复用敌人列表、仅切换 random_context 统计 8880 次掷骰（毫秒级完成）
	var base_logic := XBattleLogic.new()
	base_logic.setup(454, s, XBattleRandom.create("t472_base"))
	for en in base_logic.enemies:
		en.hp = 0.0
	for i in range(8880):
		base_logic.random = XBattleRandom.create("t472_drop_%d" % i)
		var ds := XElementalKing.battle_drops(base_logic)
		if not ds.is_empty():
			hits += ds.size()
			if hit_seed == "":
				hit_seed = "t472_drop_%d" % i
	check("drop_rate_statistical_1_in_888", hits >= 3 and hits <= 25, [hits, 8880])
	check("drop_found_hit_seed", hit_seed != "", hit_seed)

	if hit_seed != "":
		var s2 := _new_xiyou_state()
		s2.map_id = 152
		s2.pingbi_quality = [true, true, true, true, true, true, true, true]
		# 找一个经完整 rewards() 流程命中 1/888 的种子（验证 pingbi/drop_lock 不吞掉落）
		var rw_hit_seed := ""
		var rw_logic: XBattleLogic = null
		var rw_res := {}
		for k in range(8880):
			var cand_seed := "t472_rw_%d" % k
			var lg := XBattleLogic.new()
			lg.setup(454, s2, XBattleRandom.create(cand_seed))
			for en in lg.enemies:
				en.hp = 0.0
			var r := lg.rewards()
			if (r.drops as Array).any(func(d): return int(d.get("kind", 0)) == 3 and int(d.get("id", 0)) == XElementalKing.ARMOR):
				rw_hit_seed = cand_seed
				rw_logic = lg
				rw_res = r
				break
		check("drop_in_rewards_despite_pingbi", rw_hit_seed != "", rw_hit_seed)
		if rw_logic != null:
			rw_logic.drop_lock = true
			var before_cnt := s2.gear.size()
			rw_logic.grant(rw_res)
			var gained := s2.gear.slice(before_cnt).filter(func(g): return XElementalKing.is_blessing(g))
			check("drop_granted_under_drop_lock", gained.size() == 1 and XElementalKing.ELEMENTS.has(XElementalKing.element_of(gained[0])), gained.size())

		s2.map_id = 87
		var logic_bad := XBattleLogic.new()
		logic_bad.setup(454, s2, XBattleRandom.create(hit_seed))
		for en in logic_bad.enemies:
			en.hp = 0.0
		check("drop_blocked_non_abyss_map", XElementalKing.battle_drops(logic_bad).is_empty(), s2.map_id)

		s2.map_id = 152
		XElementalKing.ENABLED = false
		var logic_off := XBattleLogic.new()
		logic_off.setup(454, s2, XBattleRandom.create(hit_seed))
		for en in logic_off.enemies:
			en.hp = 0.0
		check("drop_blocked_when_disabled", XElementalKing.battle_drops(logic_off).is_empty(), true)
		XElementalKing.ENABLED = true

		var tq := XState.new_game(2, 1, [8, 9, 10])
		tq.flags["tianqi"] = {"rules": 1}
		tq.map_id = 152
		XState.current = tq
		var logic_tq := XBattleLogic.new()
		logic_tq.setup(454, tq, XBattleRandom.create(hit_seed))
		for en in logic_tq.enemies:
			en.hp = 0.0
		check("tianqi_zero_drop", XElementalKing.battle_drops(logic_tq).is_empty(), true)
		var ta: XActor = tq.actor(1)
		ta._lv = 60
		ta.refresh_passive()
		var inst_tq := _make_blessing(tq, 2, 0, 0.5)
		check("tianqi_cannot_equip_form", not ta.can_equip(inst_tq), true)
		if ta.equips.size() > 0:
			ta.equips[0] = inst_tq
		var phys := {"id": 999001, "stypeId": 1, "hitType": 1, "damage": {"type": 1, "elementId": 1, "formula": "a.atk * 4", "variance": 0, "critical": false}}
		check("tianqi_zero_dual_element", XElementalKing.extra_element(phys, ta) == 0, XElementalKing.extra_element(phys, ta))


func _run_dummy_benchmarks() -> void:
	var s := _new_xiyou_state()
	var a: XActor = s.actor(1)
	# 模拟西游档后期典型主 C 基准（其余 18 部位＋法宝＋修炼＋常规终伤/增伤）：
	# 60 级：基础 ATK 18,000、终伤 +400%、物伤 +350%、火伤 +250%；
	# 80 级：基础 ATK 35,000、终伤 +800%、物伤 +500%、火伤 +350%；
	# 99 级：基础 ATK 60,000、终伤 +1200%、物伤 +650%、火伤 +450%。
	var profiles := {
		60: {"atk_plus": 18000.0, "harm_ri": 400, "phys_amp": 3.5, "fire_amp": 2.5},
		80: {"atk_plus": 35000.0, "harm_ri": 800, "phys_amp": 5.0, "fire_amp": 3.5},
		99: {"atk_plus": 60000.0, "harm_ri": 1200, "phys_amp": 6.5, "fire_amp": 4.5},
	}
	# 挑一条代表性增伤神话词条（从 4800..4896 里选终伤/物伤档）
	var dmg_mythic_id := 0
	var dmg_mythic_desc := ""
	for id in range(4800, 4897):
		var rec := XDB.rec("Armors", id)
		var nt := str(rec.get("note", ""))
		if nt.contains("<passiveHarmRi:") and not nt.contains("passiveCrHarmRi"):
			dmg_mythic_id = id
			dmg_mythic_desc = nt.strip_edges()
			break
	if dmg_mythic_id == 0:
		for id in range(4800, 4897):
			var rec := XDB.rec("Armors", id)
			if str(rec.get("note", "")).contains("<Element Amplify 1:"):
				dmg_mythic_id = id
				dmg_mythic_desc = str(rec.get("note", "")).strip_edges()
				break
	if dmg_mythic_id == 0:
		dmg_mythic_id = 4801

	var phys_skill := XDB.rec("Skills", 72)  # 仁义剑法（真实物理技能，hitType=1, elementId=1, 1500 + a.atk * 18.2）
	var neutral_dummy := _make_dummy({})
	var resist_dummy := _make_dummy({1: 0.5, 2: 1.25})

	if print_bench:
		print("=== BENCH_START (dmg_mythic_id=%d) ===" % dmg_mythic_id)
		print("MYTHIC_NOTE:", dmg_mythic_desc.replace("\n", " | "))
	for lv in [60, 80, 99]:
		var p: Dictionary = profiles[lv]
		a._lv = lv
		for i in range(a.equips.size()):
			a.equips[i] = null
		var base_gear := {
			"kind": "armor", "base": 1, "id": 1, "etypeId": 2, "atypeId": 5,
			"params": [0, 0, p.atk_plus, 0, 0, 0, 0, 0],
			"traits": [], "note": "<passiveHarmRi:%d>" % int(p.harm_ri), "meta": {},
			"yep": {"elementAmplify": {"1": p.phys_amp, "2": p.fire_amp}},
		}
		var off_slot := a.equip_slots().find(2)
		if off_slot >= 0:
			a.equips[off_slot] = base_gear
		a.refresh_passive()

		_equip_form(a, null)
		var dmg_none_n := float(XDamage.calculate(phys_skill, a, neutral_dummy, {"variance": false, "preview": true}).value)
		var dmg_none_r := float(XDamage.calculate(phys_skill, a, resist_dummy, {"variance": false, "preview": true}).value)

		var titan_avg := _make_titan(s, 4348, 0.5)
		titan_avg.params = [3225.0, 1805.0, 1512.0, 1512.0, 1512.0, 1512.0, 1512.0, 1512.0]
		_equip_form(a, titan_avg)
		var dmg_tavg_n := float(XDamage.calculate(phys_skill, a, neutral_dummy, {"variance": false, "preview": true}).value)
		var dmg_tavg_r := float(XDamage.calculate(phys_skill, a, resist_dummy, {"variance": false, "preview": true}).value)

		var titan_max := _make_titan(s, 4348, 0.9999)
		_equip_form(a, titan_max)
		var dmg_tmax_n := float(XDamage.calculate(phys_skill, a, neutral_dummy, {"variance": false, "preview": true}).value)
		var dmg_tmax_r := float(XDamage.calculate(phys_skill, a, resist_dummy, {"variance": false, "preview": true}).value)

		var ek_plain := _make_blessing(s, 2, 0, 0.5)
		_equip_form(a, ek_plain)
		var dmg_ek0_n := float(XDamage.calculate(phys_skill, a, neutral_dummy, {"variance": false, "preview": true}).value)
		var dmg_ek0_r := float(XDamage.calculate(phys_skill, a, resist_dummy, {"variance": false, "preview": true}).value)

		var ek_mythic := _make_blessing(s, 2, dmg_mythic_id, 0.5)
		_equip_form(a, ek_mythic)
		var dmg_ekm_n := float(XDamage.calculate(phys_skill, a, neutral_dummy, {"variance": false, "preview": true}).value)
		var dmg_ekm_r := float(XDamage.calculate(phys_skill, a, resist_dummy, {"variance": false, "preview": true}).value)

		var ek_chaos := _make_blessing(s, 2, 4900, 0.5)
		_equip_form(a, ek_chaos)
		var dmg_ekc_n := float(XDamage.calculate(phys_skill, a, neutral_dummy, {"variance": false, "preview": true}).value)
		var dmg_ekc_r := float(XDamage.calculate(phys_skill, a, resist_dummy, {"variance": false, "preview": true}).value)

		check("bench_lv%d_plain_below_matched_titan_neutral" % lv, dmg_ek0_n < dmg_tavg_n, [dmg_ek0_n, dmg_tavg_n])
		check("bench_lv%d_plain_beats_titan_on_resist" % lv, dmg_ek0_r > dmg_tmax_r, [dmg_ek0_r, dmg_tmax_r])

		if print_bench:
			print("BENCH lv=%d | none=(%.0f, %.0f) | titan_avg=(%.0f, %.0f) | titan_max=(%.0f, %.0f) | ek_plain=(%.0f, %.0f) | ek_mythic=(%.0f, %.0f) | ek_chaos=(%.0f, %.0f)" % [
				lv, dmg_none_n, dmg_none_r, dmg_tavg_n, dmg_tavg_r, dmg_tmax_n, dmg_tmax_r,
				dmg_ek0_n, dmg_ek0_r, dmg_ekm_n, dmg_ekm_r, dmg_ekc_n, dmg_ekc_r
			])
	if print_bench:
		print("=== BENCH_END ===")


func _capture_shots() -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var s := _new_xiyou_state()
	var a: XActor = s.actor(1)
	a._lv = 60
	a.refresh_passive()
	var fire_plain := _make_blessing(s, 2, 0, 0.5)
	var ice_mythic := _make_blessing(s, 3, 4806, 0.65)
	s.gear.append(fire_plain)
	s.gear.append(ice_mythic)
	for pair in [["detail_fire_plain", fire_plain], ["detail_ice_mythic", ice_mythic]]:
		var bg := ColorRect.new()
		bg.color = Color("181a24")
		bg.size = Vector2(1280, 720)
		add_child(bg)
		var d := XGearDetail.new(bg, Rect2(160, 20, 960, 680), XUI.MENU_WINDOW_OPACITY, ["装备详情"], [0])
		d.set_item(pair[1])
		d.set_mode(0)
		for _f in range(6):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var p := out_dir.path_join("t472_%s.png" % pair[0])
		check("shot_" + pair[0], get_viewport().get_texture().get_image().save_png(p) == OK, p)
		bg.queue_free()
		for _f in range(3):
			await get_tree().process_frame
	_equip_form(a, fire_plain)
	var eq_scene := XEquipScene.new()
	add_child(eq_scene)
	eq_scene._mode = "slot"
	var form_slot := a.equip_slots().find(XElementalKing.ETYPE)
	if form_slot >= 0:
		eq_scene._slot = form_slot
		eq_scene._slot_top = maxi(0, form_slot - 10)
	eq_scene._refresh()
	for _f in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var p_eq := out_dir.path_join("t472_equip_scene_lv60.png")
	check("shot_equip_scene_lv60", get_viewport().get_texture().get_image().save_png(p_eq) == OK, p_eq)
	eq_scene.queue_free()
	for _f in range(3):
		await get_tree().process_frame


func _run() -> void:
	TestEnv.isolate("xiyou_elemental_king")
	_test_definition_and_icon()
	_test_roll_and_save_persistence()
	_test_level_growth()
	_test_dual_element_combat()
	_test_abyss_drops_and_tianqi_guard()
	_run_dummy_benchmarks()
	await _capture_shots()
	var passed := checks - failures.size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": checks}))
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)
