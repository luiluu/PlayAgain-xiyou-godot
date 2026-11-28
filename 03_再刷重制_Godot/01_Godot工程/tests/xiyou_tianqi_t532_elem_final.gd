extends Node
## T532（预算稿 v0.16 九.2／附表四，D290）：固定词条元素伤终态。
## 一、过渡：武器全额；普通防具（副手～戒指）本体那份全身合计每一系 ≤ +20%，超了等比缩；宝珠等增量不缩；法宝／神器栏不进。
## 二、晶石（每孔 +5%）、神文（每孔 +1%）在账本强化桶里按孔拆单记（enhanceSplit），enhance 合计不变。
## 三、终态：ARMOR_FINAL 开时防具单件读 final（默认关，待 Kyo 定），卡面同步；合计上限仍兜底。
## 四、开关回退；西游档零改动。

var results: Array = []
const ELEM := "2"  # 火：避开 DECK 物理转换


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _tq_state() -> XState:
	var w := XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var lineup := [w[0], w[1], w[2], w[3], w[5]]
	var s := XTianqi.start_new_game(3, "lianyu", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _west_state() -> XState:
	var s := XState.new_game_blank()
	s.difficulty = 3
	s.add_actor(1)
	s.map_id = 4
	XState.current = s
	return s


## 表里四档以上、带火、各占一个副手～戒指栏的防具（最多 n 件）
func _armors(n: int) -> Array:
	var seen := {}
	var out := []
	var rows: Dictionary = XTianqiGear.elem_amp_table().get("armors", {})
	var keys := rows.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in keys:
		var r: Dictionary = rows[k]
		if int(r.get("tier", 0)) < 4 or not (r.get("amp", {}) as Dictionary).has(ELEM):
			continue
		var t := XGear.template("armor", int(k))
		var et := int(t.get("etypeId", 0))
		if et < 2 or et > 10 or seen.has(et):
			continue
		seen[et] = true
		out.append(t)
		if out.size() >= n:
			break
	return out


func _amp(e: Dictionary, k := ELEM) -> float:
	return float(e.get("yep", {}).get("elementAmplify", {}).get(k, 0.0))


func _armor_sum(list: Array, k := ELEM) -> float:
	var t := 0.0
	for e in list:
		if e is Dictionary and XTianqiGear._kind(e) == "armor":
			t += _amp(e, k)
	return t


func _raw_sum(list: Array, k := ELEM) -> float:
	var t := 0.0
	for e in list:
		t += float(XTianqiGear.elem_amp_table().armors[str(int(e.get("base", e.id)))].amp.get(k, 0)) / 100.0
	return t


func _touch(a: XActor) -> void:
	a.read_touch()
	a._pm_base = {}
	a.refresh_passive()


func _run() -> void:
	var s := _tq_state()
	var arm := _armors(3)
	var w := XGear.template("weapon", 1826)  # 通用武器（T451：物理 +30%）
	var raw := _raw_sum(arm)

	# 一、过渡：防具合计封 20、武器全额
	var capped := XTianqiGear.stat_list([w] + arm)
	var wv: Dictionary = capped[0]
	var one := XTianqiGear.stat_list([arm[0]])
	_check("t532_armor_cap_combined",
		arm.size() == 3 and raw > 0.20 + 1e-6
		and absf(_armor_sum(capped) - 0.20) < 1e-6
		and absf(_amp(wv, "1") - 0.30) < 1e-6
		and absf(_amp(one[0]) - _raw_sum([arm[0]])) < 1e-6,
		[raw, _armor_sum(capped), _amp(wv, "1"), _amp(one[0])])

	# 各件等比缩；原实例不被改写
	var ratio_ok := true
	for i in arm.size():
		var want := _raw_sum([arm[i]]) * 0.20 / raw
		ratio_ok = ratio_ok and absf(_amp(capped[i + 1]) - want) < 1e-6 and bool(capped[i + 1].get("_tq_ea_capped", false))
	_check("t532_armor_cap_proportional_no_mutation", ratio_ok and _amp(arm[0]) > 0.5,
		[capped.slice(1).map(func(e): return _amp(e)), _amp(arm[0])])

	# 宝珠等增量不进合计、不缩
	var a0_orb: Dictionary = arm[0].duplicate(true)
	a0_orb.yep.elementAmplify[ELEM] = _amp(a0_orb) + 0.12
	var capped_orb := XTianqiGear.stat_list([a0_orb, arm[1], arm[2]])
	_check("t532_armor_cap_keeps_extras", absf(_armor_sum(capped_orb) - 0.32) < 1e-6, _armor_sum(capped_orb))

	# 法宝／神器栏不进合计（神器 4536 在表里，etype 17）
	var art := XGear.template("armor", 4536)
	var capped_art := XTianqiGear.stat_list(arm + [art])
	var art_v: Dictionary = capped_art[3]
	_check("t532_armor_cap_skips_artifact", int(art.get("etypeId", 0)) == 17
		and absf(_amp(art_v, "1") - float(XTianqiGear.elem_amp_table().armors["4536"].amp.get("1", 0)) / 100.0) < 1e-6
		and absf(_armor_sum(capped_art.slice(0, 3)) - 0.20) < 1e-6,
		[_amp(art_v, "1"), _armor_sum(capped_art.slice(0, 3))])

	# 实战：角色穿上后账本 equip 桶（武器全额＋防具 20）＝ 0.30＋0.20（物理一系）
	var a: XActor = s.actor(s.party[0])
	a.equips[0] = w
	for e in arm:
		a.equips[int(e.etypeId) - 1] = e
	_touch(a)
	var by := XTianqiLedger.passive_buckets(a, [])
	var eq_fire := 0.0
	for b in by.elementAmplify.get(int(ELEM), {}):
		if b in ["equip", "tianqi"]:
			eq_fire += float(by.elementAmplify[int(ELEM)][b])
	XTianqiGear.ARMOR_ELEM_CAP = false
	_touch(a)
	var by_off := XTianqiLedger.passive_buckets(a, [])
	var eq_fire_off := 0.0
	for b in by_off.elementAmplify.get(int(ELEM), {}):
		if b in ["equip", "tianqi"]:
			eq_fire_off += float(by_off.elementAmplify[int(ELEM)][b])
	var off_list := XTianqiGear.stat_list(arm)
	XTianqiGear.ARMOR_ELEM_CAP = true
	_touch(a)
	var w_fire := _amp(wv)
	_check("t532_armor_cap_in_ledger_and_switch",
		absf(eq_fire - (w_fire + 0.20)) < 1e-6 and absf(eq_fire_off - (w_fire + raw)) < 1e-6
		and absf(_armor_sum(off_list) - raw) < 1e-6,
		[eq_fire, eq_fire_off, w_fire, raw, by.elementAmplify.get(int(ELEM))])

	# 二、晶石／神文按孔拆单记
	var wu: Dictionary = w.duplicate(true)
	XGearUpgrade.apply_effects(wu, XDB.rec("Items", 1026), false)  # 晶石:辣椒 火 +5%
	XGearUpgrade.apply_effects(wu, XDB.rec("Items", 1026), false)
	XGearUpgrade.apply_effects(wu, XDB.rec("Items", 310), false)  # 神文:霹 雷 +1%
	var holes := XTianqiLedger.upgrade_holes(wu)
	var hole_ok := holes.size() == 3 and str(holes[0].src) == "crystal" and str(holes[2].src) == "rune" \
		and int(holes[0].hole) == 0 and int(holes[1].hole) == 1 and int(holes[2].hole) == 2 \
		and absf(float(holes[0].value) - 0.05) < 1e-9 and absf(float(holes[2].value) - 0.01) < 1e-9
	var amp_all := XTianqiLedger.upgrade_amplify(wu)
	var amp_cr := XTianqiLedger.upgrade_amplify(wu, "crystal")
	var amp_ru := XTianqiLedger.upgrade_amplify(wu, "rune")
	a.equips[0] = wu
	_touch(a)
	var by2 := XTianqiLedger.passive_buckets(a, [])
	var sp: Dictionary = by2.get("enhanceSplit", {})
	_check("t532_crystal_rune_split_per_hole",
		hole_ok and absf(float(amp_all.get("2", 0)) - 0.10) < 1e-9 and absf(float(amp_all.get("5", 0)) - 0.01) < 1e-9
		and absf(float(amp_cr.get("2", 0)) - 0.10) < 1e-9 and not amp_cr.has("5")
		and absf(float(amp_ru.get("5", 0)) - 0.01) < 1e-9 and not amp_ru.has("2")
		and absf(float(by2.elementAmplify[2].get("enhance", 0)) - 0.10) < 1e-9
		and absf(float(sp.get(2, {}).get("crystal", 0)) - 0.10) < 1e-9
		and absf(float(sp.get(5, {}).get("rune", 0)) - 0.01) < 1e-9
		and absf(float(by2.elementAmplify[5].get("enhance", 0)) - 0.01) < 1e-9,
		[holes, amp_all, by2.elementAmplify.get(2), sp])
	a.equips[0] = w
	_touch(a)

	# 三、终态：默认关；开了读 final、卡面同步、合计兜底
	var a4535 := XGear.template("armor", 4535)
	var off_v: Dictionary = XTianqiGear.elem_amp_view(a4535)
	XTianqiGear.ARMOR_FINAL = true
	var fin_v: Dictionary = XTianqiGear.elem_amp_view(a4535)
	var card := "\n".join(XHelpCard._content(a4535).map(func(r): return str(r[0])))
	var fin_list := XTianqiGear.stat_list(arm)
	var fin_raw := 0.0
	for e in arm:
		fin_raw += float(XTianqiGear.elem_amp_table().armors[str(int(e.id))].final.amp.get(ELEM, 0)) / 100.0
	var w_fin := _amp(XTianqiGear.stat_list([w])[0], "1")
	XTianqiGear.ARMOR_FINAL = false
	var back_v: Dictionary = XTianqiGear.elem_amp_view(a4535)
	_check("t532_armor_final_switch",
		XTianqiGear.ARMOR_FINAL == false
		and absf(_amp(off_v, "1") - 0.20) < 1e-6 and absf(_amp(fin_v, "1") - 0.03) < 1e-6
		and card.contains("所有伤害+3%") and not card.contains("所有伤害+20%")
		and absf(_armor_sum(fin_list) - minf(fin_raw, 0.20)) < 1e-6
		and absf(w_fin - 0.30) < 1e-6 and absf(_amp(back_v, "1") - 0.20) < 1e-6,
		[_amp(off_v, "1"), _amp(fin_v, "1"), card, _armor_sum(fin_list), fin_raw])

	# 五、小o 核 P1-1：实际七印生成件与普通防具混穿——七印不进合计、不被缩，终态开关也不读 final
	var rng := XRandomStream.create("5325325325325325", "t532")
	var qy := []
	var qy_et := {}
	for seal in XTianqiQiyinDrop.seals():
		for pc in XTianqiQiyinGear.parts():
			if qy.size() >= 2:
				break
			var it := XTianqiQiyinEquip.make({"kind": "set", "seal": seal, "part": str(pc.key), "true_seal": false, "grades": ["putong", "putong", "putong"]}, "jianxian", rng)
			if it.is_empty() or qy_et.has(int(it.etypeId)):
				continue
			var vv = XTianqiGear.elem_amp_view(it)
			if vv is Dictionary and _amp(vv) > 0.0:
				qy.append(it)
				qy_et[int(it.etypeId)] = true
		if qy.size() >= 2:
			break
	var plain := []
	for e in _armors(9):
		if not qy_et.has(int(e.etypeId)):
			plain.append(e)
			break
	var mix := XTianqiGear.stat_list(qy + plain)
	var qy_alone := qy.map(func(e): return _amp(XTianqiGear.elem_amp_view(e)))
	var plain_raw := _raw_sum(plain)
	XTianqiGear.ARMOR_FINAL = true
	var mix_fin := XTianqiGear.stat_list(qy + plain)
	XTianqiGear.ARMOR_FINAL = false
	var fin_plain := float(XTianqiGear.elem_amp_table().armors[str(int(plain[0].id))].final.amp.get(ELEM, 0)) / 100.0
	_check("t532_qiyin_not_capped",
		qy.size() == 2 and plain.size() == 1 and not XTianqiGear.plain_armor(qy[0]) and XTianqiGear.plain_armor(plain[0])
		and absf(_amp(mix[0]) - float(qy_alone[0])) < 1e-6 and absf(_amp(mix[1]) - float(qy_alone[1])) < 1e-6
		and absf(_amp(mix[2]) - minf(plain_raw, 0.20)) < 1e-6
		and absf(_amp(mix_fin[0]) - float(qy_alone[0])) < 1e-6 and absf(_amp(mix_fin[2]) - fin_plain) < 1e-6,
		[qy_alone, mix.map(func(e): return _amp(e)), mix_fin.map(func(e): return _amp(e)), plain_raw, fin_plain])

	# 六、小o 核 P1-2／P1-3：正常镶嵌入口（XGearUpgrade.apply）在已建缓存的角色上即时进账，逐孔带实例与孔位
	var b: XActor = s.actor(s.party[1])
	var wb := XGear.template("weapon", 1826)
	wb["instanceId"] = "t532_w"
	wb.upgradeSlots = 6
	wb.originalUpgradeSlots = 6
	b.equips[0] = wb
	b.refresh_passive()
	var by_before: Dictionary = b.passive_cache().get("bySource", {})
	s.gain_item(1026, 2)
	s.gain_item(310, 1)
	var ok1 := XGearUpgrade.apply(s, wb, 1026)
	var ok2 := XGearUpgrade.apply(s, wb, 1026)
	var ok3 := XGearUpgrade.apply(s, wb, 310)
	b.refresh_passive()
	var byb: Dictionary = b.passive_cache().get("bySource", {})
	var rows: Array = byb.get("enhanceHoles", []).filter(func(r): return str(r.instance) == "t532_w")
	var fire_rows := rows.filter(func(r): return int(r.element) == 2)
	_check("t532_holes_live_via_apply",
		ok1 and ok2 and ok3 and (by_before.get("enhanceHoles", []) as Array).is_empty()
		and rows.size() == 3 and fire_rows.size() == 2 and int(fire_rows[0].hole) == 0 and int(fire_rows[1].hole) == 1
		and absf(float(fire_rows[0].value) - 0.05) < 1e-9 and absf(float(fire_rows[1].value) - 0.05) < 1e-9
		and str(rows[2].src) == "rune" and int(rows[2].hole) == 2 and absf(float(rows[2].value) - 0.01) < 1e-9
		and absf(float(byb.elementAmplify.get(2, {}).get("enhance", 0)) - 0.10) < 1e-9
		and absf(float(byb.get("enhanceSplit", {}).get(2, {}).get("crystal", 0)) - 0.10) < 1e-9,
		[ok1, ok2, ok3, rows, byb.elementAmplify.get(2)])

	# 同一角色缓存已建，同进程切 ARMOR_ELEM_CAP 两向，走正常 refresh_passive，账本与九线裁切跟着变
	for e in arm:
		b.equips[int(e.etypeId) - 1] = e
	b.equips[0] = w
	b.refresh_passive()
	var probe := XDB.rec("Skills", 1).duplicate(true)
	probe["damage"] = probe.get("damage", {}).duplicate(true)
	probe["damage"]["elementId"] = 2
	var foe := XEnemy.new()
	foe.setup(int(XDB.table("Troops")[int(XGuardianRework.TROOPS[12])].members[0].enemyId), 3)
	var eq_of := func() -> float:
		var t := 0.0
		var row: Dictionary = b.passive_cache().get("bySource", {}).get("elementAmplify", {}).get(2, {})
		for k in ["equip", "tianqi"]:
			t += float(row.get(k, 0.0))
		return t
	var cut_of := func() -> float:
		var r := XDamage.calculate(probe, b, foe, {"critical": false, "variance": false})
		return float(r.breakdown.row.get("nineCap", {}).get("element", {}).get(2, 0.0))
	var on1: float = eq_of.call()
	var cut_on1: float = cut_of.call()
	XTianqiGear.ARMOR_ELEM_CAP = false
	b.refresh_passive()
	var off1: float = eq_of.call()
	var cut_off: float = cut_of.call()
	XTianqiGear.ARMOR_ELEM_CAP = true
	b.refresh_passive()
	var on2: float = eq_of.call()
	var cut_on2: float = cut_of.call()
	_check("t532_switch_live_cache",
		absf(on1 - 0.20) < 1e-6 and absf(off1 - raw) < 1e-6 and absf(on2 - 0.20) < 1e-6
		and cut_off > cut_on1 + 0.1 and absf(cut_on1 - cut_on2) < 1e-9,
		[on1, off1, on2, cut_on1, cut_off, cut_on2])

	# 七、小o 核 R2 P1-3：同底板、同镶嵌的两件武器，走装备页的 XEquipment.change 正常换装（不手清缓存），逐孔账指向新实例
	# 找一个能正常穿上的组合：先试通用武器 1826，不行就用该角色开局武器的底板
	var c: XActor = null
	var wbase := 0
	for aid in s.party:
		var cand: XActor = s.actor(aid)
		var cur = cand.equips[0]
		for bid in [1826, int(cur.get("base", cur.get("id", 0))) if cur is Dictionary else 0]:
			if bid > 0 and XEquipment.can_change(cand, 0) and XEquipment.fits(cand, 0, XGear.template("weapon", bid)):
				c = cand
				wbase = bid
				break
		if c != null:
			break
	var twins := []
	var up_all := true
	for tag in ["t532_wa", "t532_wb"]:
		var wt := XGear.template("weapon", wbase)
		wt["instanceId"] = tag
		wt.upgradeSlots = 6
		wt.originalUpgradeSlots = 6
		s.gain_item(1026, 2)
		s.gain_item(310, 1)
		s.gear.append(wt)  # 先进背包：XGearUpgrade.apply 只镶自己持有的装备
		up_all = up_all and XGearUpgrade.apply(s, wt, 1026) and XGearUpgrade.apply(s, wt, 1026) and XGearUpgrade.apply(s, wt, 310)
		twins.append(wt)
	var inst_of := func() -> Array:
		var hs: Array = c.passive_cache().get("bySource", {}).get("enhanceHoles", [])
		return hs.map(func(r): return str(r.instance))
	var ch1 := XEquipment.change(s, c, 0, twins[0])
	var ins_a: Array = inst_of.call()
	var ch2 := XEquipment.change(s, c, 0, twins[1])
	var ins_b: Array = inst_of.call()
	var ch3 := XEquipment.change(s, c, 0, twins[0])
	var ins_a2: Array = inst_of.call()
	_check("t532_holes_follow_equip_change",
		up_all and ch1 and ch2 and ch3 and is_same(c.equips[0], twins[0])
		and ins_a == ["t532_wa", "t532_wa", "t532_wa"] and ins_b == ["t532_wb", "t532_wb", "t532_wb"]
		and ins_a2 == ins_a,
		[wbase, up_all, ch1, ch2, ch3, ins_a, ins_b, ins_a2])

	# 四、西游档零改动
	XState.current = null
	var ws := _west_state()
	var west_list := XTianqiGear.stat_list([w] + arm)
	var same := west_list.size() == 4
	for i in west_list.size():
		same = same and is_same(west_list[i], ([w] + arm)[i])
	_check("t532_west_unchanged", same and absf(_armor_sum(west_list) - _armor_sum(arm)) < 1e-9 and ws != null, _armor_sum(west_list))

	XState.current = null
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		print("%s:%s -> %s" % ["PASS" if x.passed else "FAIL", x.name, str(x.detail)])
	print("TEST_RESULT=%s" % JSON.stringify({"total": results.size(), "passed": passed}))
	get_tree().quit(0 if passed == results.size() else 1)
