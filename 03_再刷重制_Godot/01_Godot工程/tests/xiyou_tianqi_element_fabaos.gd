extends Node
## 【小A·T442 / T013-1a】人族首领漏网三件下架＋12 把系别法宝归法宝线（补水/风）＋CARDS 注释同步专项：
## 一、EV054 21/28 层页真地图数据下架 4553、4540、1981；NO_HONGHUANG=false 可回退；西游档不变。
## 二、12 把系别法宝（4543～4552＋表外水 8101／风 8102）去原版特性 21/22/61/34/11 与爆炸增伤/终伤/爆伤/穿透，
##     仅留本系或治疗 +10%、FABAO_TABLE 成长与 1 条通用法宝光环；4548 改名「森罗灵剑」。
## 三、老天启篇存档已持有的 4543／4552 旧实例穿戴后同样按新视图生效。
## 四、ELEMENT_FABAOS=false 完整回退；西游档零变化；CARDS 默认值保持 false 且 cards_flag() 为 true。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
const EXPECTED_ELEMENTS := {
	4543: 1, 4544: 2, 4545: 3, 4546: 4, 4547: 5, 4548: 6,
	4549: 7, 4550: 8, 4551: 9, 4552: 10, 8101: 14, 8102: 15,
}
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a: float, b: float, eps := 0.001) -> bool:
	return absf(a - b) <= eps


func _tianqi_state() -> XState:
	var s := Kit.new_game("jiusi")
	s.set_variable(20, 20)  # 20 层（法宝上限 69 级）
	return s


func _legacy_state() -> XState:
	var s := XState.new_game_blank()
	s.add_actor(1)
	XState.current = s
	return s


func _equip_fabao(a: XActor, item: Dictionary) -> void:
	var slot := a.equip_slots().find(13)
	a.equips[slot] = item
	a.refresh_passive()
	a.param_mark_dirty()


func _unequip_fabao(a: XActor) -> void:
	var slot := a.equip_slots().find(13)
	a.equips[slot] = null
	a.refresh_passive()
	a.param_mark_dirty()


func _run() -> void:
	XTianqi.JOIN_GIFTS = false
	XMessageBox.auto = true
	seed(20261123)
	XTianqiGear.reload_table()
	XTianqiGear.clear_effective_cache()
	_check("defaults", XTianqiTrim.NO_HONGHUANG and XTianqiGear.ELEMENT_FABAOS and XTianqiGear.FABAO_TABLE
		and not XTianqiSkills.CARDS and XTianqiBase.PHASE4 and XTianqiSkills.cards_flag(),
		[XTianqiTrim.NO_HONGHUANG, XTianqiGear.ELEMENT_FABAOS, XTianqiSkills.CARDS, XTianqiBase.PHASE4])
	_ev54_delist()
	_records_12()
	_equip_and_damage()
	_legacy_instance_view()
	_rollback_and_xiyou()
	XState.current = null
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 从 Map004 EV054 解析所有商店货单（302 + 紧跟的 605）
func _ev54_shops() -> Array:
	var ev54: Dictionary = XDB.map(4).get("events", [])[54]
	var shops := []
	for page in ev54.get("pages", []):
		var list: Array = page.get("list", [])
		var i := 0
		while i < list.size():
			var cmd: Dictionary = list[i]
			if int(cmd.get("code", 0)) == 302:
				var goods := [cmd.parameters]
				var j := i + 1
				while j < list.size() and int(list[j].get("code", 0)) == 605:
					goods.append(list[j].parameters)
					j += 1
				shops.append(goods)
				i = j
				continue
			i += 1
	return shops


func _has_good(goods: Array, kind: int, id: int) -> bool:
	return goods.any(func(g): return int(g[0]) == kind and int(g[1]) == id)


func _ev54_delist() -> void:
	var shops := _ev54_shops()
	var raw_4553 := shops.any(func(g): return _has_good(g, 2, 4553))
	var raw_4540 := shops.any(func(g): return _has_good(g, 2, 4540))
	var raw_1981 := shops.any(func(g): return _has_good(g, 0, 1981))
	_check("ev54_raw_has_three", raw_4553 and raw_4540 and raw_1981, [raw_4553, raw_4540, raw_1981])
	var s := _tianqi_state()
	var tq_4553 := false
	var tq_4540 := false
	var tq_1981 := false
	var tq_xiandao := false
	for g in shops:
		var out := XTianqiTrim.shop_goods(s, 4, 54, g)
		if _has_good(out, 2, 4553): tq_4553 = true
		if _has_good(out, 2, 4540): tq_4540 = true
		if _has_good(out, 0, 1981): tq_1981 = true
		if _has_good(out, 2, 4279) and _has_good(out, 2, 5198): tq_xiandao = true
	_check("ev54_tq_delisted_three", not tq_4553 and not tq_4540 and not tq_1981, [tq_4553, tq_4540, tq_1981])
	_check("ev54_tq_keeps_xiandao", tq_xiandao)
	XTianqiTrim.NO_HONGHUANG = false
	var rb_4553 := shops.any(func(g): return _has_good(XTianqiTrim.shop_goods(s, 4, 54, g), 2, 4553))
	var rb_4540 := shops.any(func(g): return _has_good(XTianqiTrim.shop_goods(s, 4, 54, g), 2, 4540))
	var rb_1981 := shops.any(func(g): return _has_good(XTianqiTrim.shop_goods(s, 4, 54, g), 0, 1981))
	XTianqiTrim.NO_HONGHUANG = true
	_check("ev54_switch_rollback", rb_4553 and rb_4540 and rb_1981, [rb_4553, rb_4540, rb_1981])
	var leg := _legacy_state()
	var lg_4553 := shops.any(func(g): return _has_good(XTianqiTrim.shop_goods(leg, 4, 54, g), 2, 4553))
	var lg_4540 := shops.any(func(g): return _has_good(XTianqiTrim.shop_goods(leg, 4, 54, g), 2, 4540))
	var lg_1981 := shops.any(func(g): return _has_good(XTianqiTrim.shop_goods(leg, 4, 54, g), 0, 1981))
	_check("ev54_legacy_untouched", lg_4553 and lg_4540 and lg_1981, [lg_4553, lg_4540, lg_1981])


func _records_12() -> void:
	_tianqi_state()
	var ids := XTianqiGear.element_fabao_ids()
	var want_ids := EXPECTED_ELEMENTS.keys()
	want_ids.sort()
	_check("efabao_ids_12", ids == want_ids, [ids, want_ids])
	var bad := []
	for id in want_ids:
		var rec := XDB.rec("Armors", int(id))
		var e := int(EXPECTED_ELEMENTS[id])
		var note := str(rec.get("note", ""))
		var amp: Dictionary = rec.get("yep", {}).get("elementAmplify", {})
		var ok := not rec.is_empty() and int(rec.get("etypeId", 0)) == 13 \
			and (rec.get("traits", []) as Array).is_empty() \
			and amp.size() == 1 and _near(float(amp.get(str(e), 0.0)), 0.10) \
			and XMagicWeapon.is_magic(rec) \
			and not note.contains("passiveHarmRi") and not note.contains("passiveCrHarmRi") \
			and not note.contains("DepassiveHarmRe") and not note.contains("+300%") and not note.contains("+500%") \
			and note.contains("<Element Amplify %d: +10%%>" % e)
		if not ok:
			bad.append({"id": id, "traits": rec.get("traits"), "amp": amp, "name": rec.get("name")})
	_check("efabao_12_records_clean", bad.is_empty(), bad)
	var r4548 := XDB.rec("Armors", 4548)
	var r8101 := XDB.rec("Armors", 8101)
	var r8102 := XDB.rec("Armors", 8102)
	_check("efabao_rename_and_new_names",
		str(r4548.get("name", "")) == "森罗灵剑" and str(r8101.get("name", "")) == "沧澜水剑" and str(r8102.get("name", "")) == "青岚风剑"
		and int(r8101.get("iconIndex", 0)) > 0 and int(r8102.get("iconIndex", 0)) > 0,
		[r4548.get("name"), r8101.get("name"), r8102.get("name")])
	var items: Array = XTianqiGear.table().get("element_fabaos", {}).get("items", [])
	var pending_ok := [4548, 8101, 8102].all(func(nid):
		return items.any(func(row): return int(row.get("id", 0)) == nid and str(row.get("text_review", "")) == "pending"))
	_check("efabao_text_review_pending", pending_ok)


func _synth_skill(elem: int, dmg_type := 1) -> Dictionary:
	return {
		"id": 99900 + elem, "name": "test_%d" % elem, "stypeId": 2, "hitType": 2,
		"damage": {"type": dmg_type, "elementId": elem, "formula": "1000", "variance": 0, "critical": false,
			"formulaProgram": {"status": "pure", "kind": "const", "value": 1000.0}},
		"effects": [], "meta": {}, "note": "", "yep": {},
	}


func _equip_and_damage() -> void:
	var s := _tianqi_state()
	var a: XActor = s.actor(s.party[0])
	a.change_level(50)
	for i in a.equips.size():
		a.equips[i] = null
	a.refresh_passive()
	a.param_mark_dirty()
	var bare_cri := a.cri
	var bare_hit := a.hit
	var bare_rates := []
	for p in 8:
		bare_rates.append(a.param_rate(p))
	var bare_act := a.action_plus_set().duplicate()
	var bare_er := {}
	var bare_own := {}
	for e in EXPECTED_ELEMENTS.values():
		bare_er[int(e)] = a.element_rate(int(e))
		bare_own[int(e)] = XDamage.own_bonus(a, int(e))

	var all_clean := true
	var bad_wear := []
	for id in XTianqiGear.element_fabao_ids():
		var e := int(EXPECTED_ELEMENTS[id])
		var item := XGear.create("armor", int(id), s)
		# 保证不带随机光环干扰裸值比对（光环另外专测）
		item.erase("tianqi_affixes")
		_equip_fabao(a, item)
		var pr_ok := true
		for p in 8:
			if not _near(a.param_rate(p), float(bare_rates[p])):
				pr_ok = false
		var pc := a.passive_cache()
		var own_e := XDamage.own_bonus(a, e) - float(bare_own[e])
		var other_e := 2 if e != 2 else 3
		var own_other := XDamage.own_bonus(a, other_e) - float(bare_own[other_e])
		var fb_ok := XTianqiGear.fabao_applies(item) and XTianqiGear.fabao_param(item, 0) > 0.0 and XTianqiGear.fabao_param(item, 2) > 0.0
		var aura_ok := XTianqiAffixRoll.general_artifact(item)
		var ok := XTianqiGear.allows(item) and pr_ok \
			and _near(a.cri, bare_cri) and _near(a.hit, bare_hit) \
			and a.action_plus_set() == bare_act \
			and _near(float(pc.get("globalHarmRi", 0.0)), 0.0) \
			and _near(float(pc.get("critHarmRi", 0.0)), 0.0) \
			and (pc.get("penetratePercent", {}) as Dictionary).is_empty() \
			and _near(a.element_rate(e), float(bare_er[e])) \
			and _near(own_e, 0.10) and _near(own_other, 0.0) \
			and fb_ok and aura_ok
		if not ok:
			all_clean = false
			bad_wear.append({"id": id, "pr_ok": pr_ok, "cri": [a.cri, bare_cri], "hit": [a.hit, bare_hit],
				"harm": pc.get("globalHarmRi"), "crit_harm": pc.get("critHarmRi"), "own": [own_e, own_other],
				"er": [a.element_rate(e), bare_er[e]], "fb_ok": fb_ok, "aura_ok": aura_ok})
		_unequip_fabao(a)
	_check("efabao_12_wear_clean_and_10pct", all_clean, bad_wear)

	# 端到端伤害/治疗验证：火(4544)、水(8101)、风(8102)、治疗(4552) 均精确 +10%
	var dummy := XEnemy.new()
	dummy.setup(1, 0)
	var prev_deck := XTianqiElements.DECK
	XTianqiElements.DECK = false  # 排除牌组随机抗性，纯测元素增幅倍率
	for pair in [[4544, 2, 1], [8101, 14, 1], [8102, 15, 1], [4552, 10, 3]]:
		var fid := int(pair[0])
		var el := int(pair[1])
		var dtype := int(pair[2])
		var sk := _synth_skill(el, dtype)
		_unequip_fabao(a)
		var target: XBattler = a if dtype == 3 else dummy
		var raw_v := -1000.0 if dtype == 3 else 1000.0
		var base_v := float(XDamage.calculate(sk, a, target, {"rawValue": raw_v, "variance": false, "preview": true, "mode": "magical", "kind": "fixed"}).value)
		var it := XGear.template("armor", fid)
		_equip_fabao(a, it)
		var with_v := float(XDamage.calculate(sk, a, target, {"rawValue": raw_v, "variance": false, "preview": true, "mode": "magical", "kind": "fixed"}).value)
		_unequip_fabao(a)
		var ratio := with_v / base_v if base_v != 0.0 else 0.0
		_check("e2e_ratio_%d_elem%d" % [fid, el], _near(ratio, 1.10, 0.01), [base_v, with_v, ratio])
	XTianqiElements.DECK = prev_deck

	# FABAO_TABLE 成长随等级提升 & 1 条通用法宝光环掷骰（含新水/风法宝）
	var water := XGear.template("armor", 8101)
	var hp1 := XTianqiGear.fabao_param(water, 0)
	var atk1 := XTianqiGear.fabao_param(water, 2)
	water["level"] = 30
	var hp30 := XTianqiGear.fabao_param(water, 0)
	var atk30 := XTianqiGear.fabao_param(water, 2)
	_check("fabao_table_growth_water", hp30 > hp1 and atk30 > atk1 and XTianqiGear.fabao_param(water, 4) > 0.0, [hp1, hp30, atk1, atk30])
	var aura_cnt := 0
	for id in [4543, 4548, 4552, 8101, 8102]:
		var inst := XGear.template("armor", int(id))
		XTianqiAffixRoll.apply(inst, s, func(): return 0.1)  # <0.5 必出 1 条法宝光环
		var aff: Array = inst.get("tianqi_affixes", [])
		if aff.size() == 1 and bool(aff[0].get("growth", false)):
			aura_cnt += 1
	_check("fabao_aura_roll_1_line", aura_cnt == 5, aura_cnt)


func _legacy_instance_view() -> void:
	var s := _tianqi_state()
	# 先关开关模拟老天启篇存档里已经买下的原版 4543、4552 实例
	XTianqiGear.ELEMENT_FABAOS = false
	var old_4543 := XGear.template("armor", 4543)
	var old_4552 := XGear.template("armor", 4552)
	XTianqiGear.ELEMENT_FABAOS = true
	_check("old_inst_has_raw_traits", (old_4543.get("traits", []) as Array).size() > 0 and float(old_4543.get("yep", {}).get("elementAmplify", {}).get("1", 0.0)) == 5.0)
	var a: XActor = s.actor(s.party[0])
	a.change_level(50)
	for i in a.equips.size():
		a.equips[i] = null
	a.refresh_passive()
	a.param_mark_dirty()
	var bare_cri := a.cri
	var bare_hit := a.hit
	var bare_er10 := a.element_rate(10)
	_equip_fabao(a, old_4543)
	var ok4543 := _near(a.param_rate(2), 1.0) and _near(a.cri, bare_cri) and _near(a.hit, bare_hit) \
		and _near(float(a.passive_cache().get("globalHarmRi", 0.0)), 0.0) \
		and _near(XDamage.own_bonus(a, 1), 0.10)
	_check("old_save_4543_cleaned", ok4543, [a.param_rate(2), a.cri, a.hit, a.passive_cache().get("globalHarmRi"), XDamage.own_bonus(a, 1)])
	_equip_fabao(a, old_4552)
	var ok4552 := _near(a.param_rate(0), 1.0) and _near(a.element_rate(10), bare_er10) \
		and _near(XDamage.own_bonus(a, 10), 0.10)
	_check("old_save_4552_cleaned", ok4552, [a.param_rate(0), a.element_rate(10), XDamage.own_bonus(a, 10)])
	_unequip_fabao(a)


func _rollback_and_xiyou() -> void:
	_tianqi_state()
	XTianqiGear.ELEMENT_FABAOS = false
	var rb4543 := XDB.rec("Armors", 4543)
	var rb4548 := XDB.rec("Armors", 4548)
	var rb8101 := XDB.rec("Armors", 8101)
	var rb8102 := XDB.rec("Armors", 8102)
	XTianqiGear.ELEMENT_FABAOS = true
	_check("switch_off_rollback",
		(rb4543.get("traits", []) as Array).size() > 0
		and _near(float(rb4543.get("yep", {}).get("elementAmplify", {}).get("1", 0.0)), 5.0)
		and str(rb4548.get("name", "")) == "御风灵剑"
		and rb8101.is_empty() and rb8102.is_empty(),
		[rb4543.get("traits", []).size(), rb4548.get("name"), rb8101.is_empty(), rb8102.is_empty()])

	_legacy_state()
	var lg4543 := XDB.rec("Armors", 4543)
	var lg4548 := XDB.rec("Armors", 4548)
	var lg4552 := XDB.rec("Armors", 4552)
	var lg8101 := XDB.rec("Armors", 8101)
	var lg8102 := XDB.rec("Armors", 8102)
	_check("xiyou_save_zero_change",
		(lg4543.get("traits", []) as Array).size() > 0
		and _near(float(lg4543.get("yep", {}).get("elementAmplify", {}).get("1", 0.0)), 5.0)
		and _near(float(lg4552.get("yep", {}).get("elementAmplify", {}).get("10", 0.0)), 3.0)
		and str(lg4548.get("name", "")) == "御风灵剑"
		and lg8101.is_empty() and lg8102.is_empty(),
		[lg4543.get("traits", []).size(), lg4548.get("name"), lg8101.is_empty(), lg8102.is_empty()])
