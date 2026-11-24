extends Node
## T449（D280）：天启篇 DECK 开着时物理 1 转成无属性 0，原物理招的攻击方增伤改读物理那份（elementAmplify["1"]、passiveELUP01）。
## 一、DECK 开：物理招吃物理增伤；真无属性招（elementId 0）不吃；普攻（elementId -1、武器属性 1）也吃。
## 二、装备 4543（物理 +10%）实物；skill_rework 被动 <passiveELUP01:10%>（技能 41）实物。
## 三、回退开关 PHYS_AMP_ON_DECK=false 回到修前（物理增伤白写）；DECK=false、西游档行为不变。

var results: Array = []


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
	for id in lineup:
		s.actor(id).recover_all()
	return s


func _west_state() -> XState:
	var s := XState.new_game_blank()
	s.difficulty = 3
	s.add_actor(1)
	s.map_id = 4
	XState.current = s
	return s


func _stub(id: int, elem: int, hit_type := 1) -> Dictionary:
	var prog := {
		"version": 1, "status": "pure", "locals": ["value"],
		"source": {"sha256": "t449_%d" % id},
		"steps": [{"op": "set", "name": "value", "value": {"op": "literal", "value": 100000.0}}],
		"result": "value",
	}
	return {
		"id": id, "name": "T449_%d" % id, "scope": 1, "hitType": hit_type,
		"stypeId": 1, "mpCost": 0, "tpCost": 0, "effects": [], "note": "", "meta": {},
		"damage": {"type": 1, "elementId": elem, "critical": false, "variance": 0, "formula": "100000", "formulaProgram": prog},
	}


func _enemy() -> XEnemy:
	var eid := int(XDB.table("Troops")[int(XGuardianRework.TROOPS[12])].members[0].enemyId)
	var e := XEnemy.new()
	e.setup(eid, 3)
	return e


func _touch(a: XActor) -> void:
	a.read_touch()
	a._pm_base = {}
	a.refresh_passive()


func _hit(item: Dictionary, a: XBattler, b: XBattler) -> float:
	return XDamage.preview_hit(item, a, b)


## 往角色本体（YEP 增幅来源之一：角色）挂 elementAmplify {"1": amp}，量三招（物理 1、无属性 0、普攻 -1）挂前挂后比值
func _ratios(a: XActor, b: XEnemy, amp: float) -> Array:
	var phys := _stub(98491, 1, 1)
	var none := _stub(98492, 0, 1)
	var atk := _stub(98493, -1, 1)
	_touch(a)
	var p0 := _hit(phys, a, b)
	var n0 := _hit(none, a, b)
	var k0 := _hit(atk, a, b)
	var eq0: Dictionary = a.data()
	var had := eq0.has("yep")
	var keep = eq0.get("yep", {}).duplicate(true)
	var yep: Dictionary = eq0.get("yep", {}).duplicate(true)
	var pool: Dictionary = yep.get("elementAmplify", {}).duplicate()
	pool["1"] = float(pool.get("1", 0.0)) + amp
	yep["elementAmplify"] = pool
	eq0["yep"] = yep
	_touch(a)
	var p1 := _hit(phys, a, b)
	var n1 := _hit(none, a, b)
	var k1 := _hit(atk, a, b)
	if had:
		eq0["yep"] = keep
	else:
		eq0.erase("yep")
	_touch(a)
	return [p1 / p0 if p0 != 0.0 else 0.0, n1 / n0 if n0 != 0.0 else 0.0, k1 / k0 if k0 != 0.0 else 0.0, [p0, p1, n0, n1, k0, k1]]


func _run() -> void:
	seed(20261124)
	var s := _tq_state()
	var a: XActor = s.battle_members()[0]
	var b := _enemy()
	b.recover_all()
	_check("deck_on_in_tianqi", XTianqiElements.deck_on())
	_check("weapon_attack_has_physical", a.attack_elements().has(1), a.attack_elements())

	# 一、DECK 开（修后）
	var r := _ratios(a, b, 0.5)
	_check("deck_phys_skill_gets_amp", absf(float(r[0]) - 1.5) < 0.02, r)
	_check("deck_true_none_skill_no_amp", absf(float(r[1]) - 1.0) < 1e-6, r)
	_check("deck_normal_attack_gets_amp", absf(float(r[2]) - 1.5) < 0.02, r)
	_check("deck_physical_flag", XDamage.deck_physical(_stub(1, 1), a) and not XDamage.deck_physical(_stub(2, 0), a) and XDamage.deck_physical(_stub(3, -1), a))

	# 回退开关：修前（物理增伤白写）
	XDamage.PHYS_AMP_ON_DECK = false
	var r_off := _ratios(a, b, 0.5)
	_check("switch_off_phys_amp_lost", absf(float(r_off[0]) - 1.0) < 1e-6 and absf(float(r_off[2]) - 1.0) < 1e-6, r_off)
	XDamage.PHYS_AMP_ON_DECK = true

	# 二、实物：装备 4543、技能 41 被动 <passiveELUP01:10%>
	var arm := XDB.rec("Armors", 4543)
	var kind := "armor" if not arm.is_empty() else "weapon"
	var base := arm if not arm.is_empty() else XDB.rec("Weapons", 4543)
	var amp4543 := float(base.get("yep", {}).get("elementAmplify", {}).get("1", 0.0))
	_check("item_4543_has_phys_amp", amp4543 > 0.0, [kind, amp4543, base.get("name", "")])
	var gear := XGear.template(kind, 4543)
	var slot := -1
	var slots := a.equip_slots()
	for i in range(slots.size()):
		if (kind == "weapon" and int(slots[i]) == 1) or (kind == "armor" and int(slots[i]) == int(gear.get("etypeId", -9))):
			slot = i
			break
	if slot >= 0 and amp4543 > 0.0:
		var p_item := _stub(98496, 1, 1)
		var n_item := _stub(98497, 0, 1)
		var keep_eq = a.equips[slot]
		_touch(a)
		var p0 := _hit(p_item, a, b)
		var n0 := _hit(n_item, a, b)
		a.equips[slot] = gear
		_touch(a)
		var p1 := _hit(p_item, a, b)
		var n1 := _hit(n_item, a, b)
		XDamage.PHYS_AMP_ON_DECK = false
		var p_old := _hit(p_item, a, b)
		XDamage.PHYS_AMP_ON_DECK = true
		a.equips[slot] = keep_eq
		_touch(a)
		print("T449_4543 yep=%s phys %s -> %s (old path %s) none %s -> %s" % [JSON.stringify(gear.get("yep", {})), p0, p1, p_old, n0, n1])
		# 4543 同时加攻击，无属性招也会涨；判据：修前物理招＝无属性招（物理增伤白写），修后物理招比无属性招多出物理增伤那份
		_check("item_4543_old_path_equals_none", absf(p_old - n1) < 1e-6 * maxf(1.0, n1), [p_old, n1])
		_check("item_4543_amp_applies_on_deck", p1 > n1 * 1.01, [amp4543, p1, n1, p1 / n1 if n1 != 0.0 else 0.0])
	else:
		_check("item_4543_slot_found", false, [kind, slots, gear.get("etypeId")])
	var phys := _stub(98494, 1, 1)
	var none := _stub(98495, 0, 1)
	_touch(a)
	var pb := _hit(phys, a, b)
	var nb := _hit(none, a, b)
	var before_elup := a.passive_values("passiveELUP01").size()
	a.learn_skill(41)
	_touch(a)
	var elup := a.passive_values("passiveELUP01")
	var pa := _hit(phys, a, b)
	var na := _hit(none, a, b)
	_check("passive_41_elup01_applies_on_deck", elup.size() > before_elup and pa > pb * 1.05 and absf(na - nb) < 1e-6, [elup, pb, pa, nb, na])

	# 三、DECK=false：行为不变（物理照原版吃物理增伤，跟修前一样）
	XTianqiElements.DECK = false
	var r_df := _ratios(a, b, 0.5)
	XDamage.PHYS_AMP_ON_DECK = false
	var r_df_old := _ratios(a, b, 0.5)
	XDamage.PHYS_AMP_ON_DECK = true
	XTianqiElements.DECK = true
	# 此时已学技能 41（物理 +10%），挂 +50% 后比值＝1.6/1.1
	_check("deck_off_unchanged", absf(float(r_df[0]) - 1.6 / 1.1) < 0.02 and JSON.stringify(r_df) == JSON.stringify(r_df_old), [r_df, r_df_old])

	# 西游档：行为不变
	var ws := _west_state()
	var wa: XActor = ws.battle_members()[0]
	var wb := _enemy()
	wb.recover_all()
	_check("west_deck_off", not XTianqiElements.deck_on())
	var r_w := _ratios(wa, wb, 0.5)
	XDamage.PHYS_AMP_ON_DECK = false
	var r_w_old := _ratios(wa, wb, 0.5)
	XDamage.PHYS_AMP_ON_DECK = true
	_check("west_unchanged", JSON.stringify(r_w) == JSON.stringify(r_w_old) and absf(float(r_w[1]) - 1.0) < 1e-6, [r_w, r_w_old])
	# 西游档下 T451 全部新视图与扩展 passiveELUP 恒不生效
	var w87_west := XGear.template("weapon", 87)
	var w87_want := float(XXiyouNerf.KOTORI_WPN_EL_AMP) / 100.0 if XXiyouNerf.ENABLED else 12.0  # T465：西游档琴里专武 87 已下调至 +200%
	var w1826_west := XGear.template("weapon", 1826)
	var a4535_west := XGear.template("armor", 4535)
	_check("west_t451_views_noop",
		is_equal_approx(float(XTianqiSkills.gear_view(w87_west).get("yep", {}).get("elementAmplify", {}).get("1", 0.0)), w87_want)
		and is_equal_approx(float(XTianqiGear.elem_amp_view(w1826_west).get("yep", {}).get("elementAmplify", {}).get("1", 0.0)), 3.0)
		and is_equal_approx(float(XTianqiGear.elem_amp_view(a4535_west).get("yep", {}).get("elementAmplify", {}).get("1", 0.0)), 2.5)
		and is_equal_approx(float(XDB.rec("States", 2719).get("yep", {}).get("elementAmplify", {}).get("1", 0.0)), 5.0))

	# 四、T449 核 P3-1：属性转换＋原物理招、目标挂物理抗/免两条路径（切回天启档）
	XState.current = s
	# 4a) 属性转换（DamageElements:2 火）＋原物理招（elementId=1）：攻击方侧按原属性 1 吃物理增伤，目标侧按转换后属性 2 结算
	var conv_ring := {"kind": "armor", "id": 99991, "base": 99991, "etypeId": 10, "name": "T451_conv_fire",
		"params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "note": "<DamageElements: 2>", "meta": {"DamageElements": "2"}, "yep": {}}
	var ring_slot := 9
	var keep_ring = a.equips[ring_slot]
	a.equips[ring_slot] = conv_ring
	var eq0_conv: Dictionary = a.data()
	var yep_conv_keep = eq0_conv.get("yep", {}).duplicate(true)
	var had_yep_conv := eq0_conv.has("yep")
	var ny_conv: Dictionary = eq0_conv.get("yep", {}).duplicate(true)
	var pool_conv: Dictionary = ny_conv.get("elementAmplify", {}).duplicate()
	pool_conv["1"] = float(pool_conv.get("1", 0.0)) + 0.5
	ny_conv["elementAmplify"] = pool_conv
	eq0_conv["yep"] = ny_conv
	_touch(a)
	var conv_phys_item := _stub(98501, 1, 1)
	var conv_res_on := XDamage.calculate(conv_phys_item, a, b, {"preview": true, "variance": false})
	XDamage.PHYS_AMP_ON_DECK = false
	var conv_res_off := XDamage.calculate(conv_phys_item, a, b, {"preview": true, "variance": false})
	XDamage.PHYS_AMP_ON_DECK = true
	a.equips[ring_slot] = keep_ring
	if had_yep_conv:
		eq0_conv["yep"] = yep_conv_keep
	else:
		eq0_conv.erase("yep")
	_touch(a)
	var conv_on_v := float(conv_res_on.get("value", 0.0))
	var conv_off_v := float(conv_res_off.get("value", 0.0))
	var conv_elem := int(conv_res_on.get("breakdown", {}).get("row", {}).get("element", -1))
	# 注意 a 已学技能 41 (+10% 物理)，挂 +50% 后物理共 +60%，修前转换后按原属性无物理读 1.0 → 比值 1.60
	_check("p3_conv_plus_orig_phys",
		conv_elem == 2 and conv_off_v > 0.0 and absf(conv_on_v / conv_off_v - 1.6) < 0.02,
		[conv_elem, conv_off_v, conv_on_v, conv_on_v / conv_off_v if conv_off_v > 0.0 else 0.0])

	# 4b) 目标挂物理免疫/抗性（trait code=11, dataId=1, value=0.0）：DECK 开下目标侧按无属性 0 结算（不免疫），攻击方照吃物理增伤
	var b_traits_keep: Array = b.data().get("traits", []).duplicate(true)
	var b_traits_imm: Array = b_traits_keep.duplicate(true)
	b_traits_imm.append({"code": 11, "dataId": 1, "value": 0.0})
	b.data()["traits"] = b_traits_imm
	_touch(a)
	var r_imm := _ratios(a, b, 0.5)
	b.data()["traits"] = b_traits_keep
	_touch(a)
	# 已学 41 (+10%)，再加 +50% → 1.6/1.1 ≈ 1.4545，且基础伤害非 0（未吃物理免疫）
	_check("p3_target_phys_immune_ignored_on_deck",
		float(r_imm[3][0]) > 100.0 and float(r_imm[3][1]) > float(r_imm[3][0]) * 1.4 and absf(float(r_imm[0]) - 1.6 / 1.1) < 0.02,
		r_imm)

	# 五、T451 验收 6：gear_view 60 件专武/防具＋weapon:2222＋armor:4518/4519/4520/4521/4579＋rec_state 36 状态重算 yep（含宝珠增量保留与回退开关）
	var w87 := XGear.template("weapon", 87)  # 琴里 物/火 +1200%
	var w91 := XGear.template("weapon", 91)  # 贝吉特 物 +300%
	var w85 := XGear.template("weapon", 85)  # 病娇 无属性 +300%
	var w2222 := XGear.template("weapon", 2222)  # 爱莉 全15系 +1000%
	var a4518 := XGear.template("armor", 4518)  # 赤染樱 原 火/冰/雷 +150%（R1 Opus P2-1）
	var a4519 := XGear.template("armor", 4519)  # 戒指朱 原 4系 +50%
	var a4521 := XGear.template("armor", 4521)  # 命运骰子 原 7系 +100%
	var a4579 := XGear.template("armor", 4579)  # 月魄剑匣 原 冰 +30%（R1 Opus P2-1）
	var w1698 := XGear.template("weapon", 1698)  # 心澜 原 治疗+20%/+450、自然+40%
	var v87: Dictionary = XTianqiSkills.gear_view(w87)
	var v91: Dictionary = XTianqiSkills.gear_view(w91)
	var v85: Dictionary = XTianqiSkills.gear_view(w85)
	var v2222: Dictionary = XTianqiSkills.gear_view(w2222)
	var v4518: Dictionary = XTianqiSkills.gear_view(a4518)
	var v4519: Dictionary = XTianqiSkills.gear_view(a4519)
	var v4521: Dictionary = XTianqiSkills.gear_view(a4521)
	var v4579: Dictionary = XTianqiSkills.gear_view(a4579)
	var v1698: Dictionary = XTianqiSkills.gear_view(w1698)
	_check("t451_gear_view_clears_residual_yep",
		v87.get("yep", {}).get("elementAmplify", {}).is_empty()
		and v91.get("yep", {}).get("elementAmplify", {}).is_empty()
		and v85.get("yep", {}).get("elementAmplify", {}).is_empty()
		and v2222.get("yep", {}).get("elementAmplify", {}).is_empty()
		and v4518.get("yep", {}).get("elementAmplify", {}).is_empty()
		and v4519.get("yep", {}).get("elementAmplify", {}).is_empty()
		and v4521.get("yep", {}).get("elementAmplify", {}).is_empty()
		and v4579.get("yep", {}).get("elementAmplify", {}).is_empty()
		and v1698.get("yep", {}).get("elementAmplify", {}).is_empty()
		and v1698.get("yep", {}).get("elementAmplifyN", {}).is_empty(),
		[v87.get("yep"), v91.get("yep"), v85.get("yep"), v2222.get("yep"), v4518.get("yep"), v4519.get("yep"), v4579.get("yep"), v1698.get("yep")])

	# 宝珠增量保留（gear_view 不误删镶嵌宝珠加的 elementAmplify）
	var w87_orb := w87.duplicate(true)
	w87_orb.yep.elementAmplify["1"] = float(w87_orb.yep.elementAmplify["1"]) + 0.15
	var v87_orb: Dictionary = XTianqiSkills.gear_view(w87_orb)
	_check("t451_gear_view_preserves_orb_delta",
		absf(float(v87_orb.get("yep", {}).get("elementAmplify", {}).get("1", 0.0)) - 0.15) < 1e-6,
		v87_orb.get("yep"))

	# rec_state 重算 yep：2719 燃血 +500%→清零、2768 封印斧 +200%→+10%、710 猛士无双 +100%→+10%
	var st2719 := XDB.rec("States", 2719)
	var st2768 := XDB.rec("States", 2768)
	var st710 := XDB.rec("States", 710)
	_check("t451_rec_state_recomputes_yep",
		st2719.get("yep", {}).get("elementAmplify", {}).is_empty()
		and absf(float(st2768.get("yep", {}).get("elementAmplify", {}).get("1", 0.0)) - 0.10) < 1e-6
		and absf(float(st710.get("yep", {}).get("elementAmplify", {}).get("1", 0.0)) - 0.10) < 1e-6,
		[st2719.get("yep"), st2768.get("yep"), st710.get("yep")])

	# YEP_RECOMPUTE 回退开关
	XTianqiSkills.YEP_RECOMPUTE = false
	var v87_off: Dictionary = XTianqiSkills.gear_view(w87)
	var st2719_off := XDB.rec("States", 2719)
	XTianqiSkills.YEP_RECOMPUTE = true
	_check("t451_yep_recompute_switch_off",
		is_equal_approx(float(v87_off.get("yep", {}).get("elementAmplify", {}).get("1", 0.0)), 12.0)
		and is_equal_approx(float(st2719_off.get("yep", {}).get("elementAmplify", {}).get("1", 0.0)), 5.0),
		[v87_off.get("yep"), st2719_off.get("yep")])

	# 六、T451 验收 5（T449 核 P2-1）：6 装备＋2 状态 passiveELUP 读取＋原版废标签不误激活＋回退开关
	var ca: XActor = s.battle_members()[1]
	for i in ca.equips.size():
		ca.equips[i] = null
	_touch(ca)
	var p2_ok := true
	var p2_detail := []
	var p2_cases := [
		["armor", 4995, "passiveELUP01", "20%"],
		["armor", 4519, "passiveELUP02", "10%"],
		["weapon", 2023, "passiveELUP01", "20%"],
		["weapon", 1698, "passiveELUP10", "5%"],
		["weapon", 1699, "passiveELUP10", "10%"],
		["weapon", 1700, "passiveELUP10", "15%"],
	]
	for pc in p2_cases:
		var it := XGear.template(str(pc[0]), int(pc[1]))
		var sl := 0 if str(pc[0]) == "weapon" else int(it.get("etypeId", 1)) - 1
		ca.equips[sl] = it
		_touch(ca)
		var got := ca.passive_values(str(pc[2]))
		var hit := got.has(str(pc[3]))
		p2_ok = p2_ok and hit
		p2_detail.append([pc[0], pc[1], pc[2], got])
		ca.equips[sl] = null
	ca.add_state(173)
	_touch(ca)
	var st173_hit := ca.passive_values("passiveELUP01").has("10%")
	ca.remove_state(173)
	ca.add_state(2733)
	_touch(ca)
	var st2733_hit := ca.passive_values("passiveELUP02").has("10%") and not ca.passive_values("passiveELUP01").has("50%")
	ca.remove_state(2733)
	# 未改写原版法宝 armor:124 (一拳 passiveELUP01:333%) 与原版状态 1149 (passiveELUP03:1000%) 不应被误读
	var a124 := XGear.template("armor", 124)
	var sl124 := int(a124.get("etypeId", 13)) - 1
	ca.equips[sl124] = a124
	ca.add_state(1149)
	_touch(ca)
	var no_leak := not ca.passive_values("passiveELUP01").has("333%") and not ca.passive_values("passiveELUP03").has("1000%")
	ca.equips[sl124] = null
	ca.remove_state(1149)
	# PASSIVE_ELUP_EXT 回退开关
	var a4995 := XGear.template("armor", 4995)
	ca.equips[int(a4995.get("etypeId", 13)) - 1] = a4995
	XTianqiSkills.PASSIVE_ELUP_EXT = false
	_touch(ca)
	var ext_off_ok := not ca.passive_values("passiveELUP01").has("20%")
	XTianqiSkills.PASSIVE_ELUP_EXT = true
	ca.equips[int(a4995.get("etypeId", 13)) - 1] = null
	_touch(ca)
	_check("t451_p2_1_passive_elup_ext", p2_ok and st173_hit and st2733_hit and no_leak and ext_off_ok,
		[p2_detail, st173_hit, st2733_hit, no_leak, ext_off_ok])

	# 七、T451 验收 3：通用武器（5～50%）＋保留防具（5～20%）分档重调＋卡面同步＋宝珠保留＋回退开关
	var w2011 := XGear.template("weapon", 2011)  # +1300% -> +50%
	var w2025 := XGear.template("weapon", 2025)  # +500% -> +36%
	var w1826 := XGear.template("weapon", 1826)  # +300% -> +30%
	var w1408 := XGear.template("weapon", 1408)  # 物+250%/元+125% -> 物+22%/元+15%
	var w1681 := XGear.template("weapon", 1681)  # 治+4565% -> 治+35%
	var a4535 := XGear.template("armor", 4535)   # 全+250% -> +20%
	var a4282 := XGear.template("armor", 4282)   # 全+160% -> +17%
	var a4313 := XGear.template("armor", 4313)   # 物/暗+160% -> +17%
	var a4541 := XGear.template("armor", 4541)   # 全+1000% -> +20%
	var vw2011: Dictionary = XTianqiGear.elem_amp_view(w2011)
	var vw2025: Dictionary = XTianqiGear.elem_amp_view(w2025)
	var vw1826: Dictionary = XTianqiGear.elem_amp_view(w1826)
	var vw1408: Dictionary = XTianqiGear.elem_amp_view(w1408)
	var vw1681: Dictionary = XTianqiGear.elem_amp_view(w1681)
	var va4535: Dictionary = XTianqiGear.elem_amp_view(a4535)
	var va4282: Dictionary = XTianqiGear.elem_amp_view(a4282)
	var va4313: Dictionary = XTianqiGear.elem_amp_view(a4313)
	var va4541: Dictionary = XTianqiGear.elem_amp_view(a4541)
	_check("t451_gear_elem_rescale_values",
		absf(float(vw2011.yep.elementAmplify["1"]) - 0.50) < 1e-6
		and absf(float(vw2011.yep.elementAmplify["2"]) - 0.50) < 1e-6
		and absf(float(vw2025.yep.elementAmplify["1"]) - 0.36) < 1e-6
		and absf(float(vw1826.yep.elementAmplify["1"]) - 0.30) < 1e-6
		and absf(float(vw1408.yep.elementAmplify["1"]) - 0.22) < 1e-6
		and absf(float(vw1408.yep.elementAmplify["2"]) - 0.15) < 1e-6
		and absf(float(vw1681.yep.elementAmplify["10"]) - 0.35) < 1e-6
		and absf(float(va4535.yep.elementAmplify["1"]) - 0.20) < 1e-6
		and absf(float(va4282.yep.elementAmplify["1"]) - 0.17) < 1e-6
		and absf(float(va4313.yep.elementAmplify["9"]) - 0.17) < 1e-6
		and absf(float(va4541.yep.elementAmplify["1"]) - 0.20) < 1e-6,
		[vw2011.yep.elementAmplify["1"], vw1826.yep.elementAmplify["1"], vw1408.yep.elementAmplify, va4535.yep.elementAmplify["1"]])

	# 卡面说明同步（XHelpCard 不留旧 +300% / +250% / +1300% 元素增伤，显示新整数；含 R1 返修代表件）
	var card_w1826 := "\n".join(XHelpCard._content(w1826).map(func(r): return str(r[0])))
	var card_a4535 := "\n".join(XHelpCard._content(a4535).map(func(r): return str(r[0])))
	var card_w1099 := "\n".join(XHelpCard._content(XGear.template("weapon", 1099)).map(func(r): return str(r[0])))
	var card_w1673 := "\n".join(XHelpCard._content(XGear.template("weapon", 1673)).map(func(r): return str(r[0])))
	var card_w1674 := "\n".join(XHelpCard._content(XGear.template("weapon", 1674)).map(func(r): return str(r[0])))
	var card_w1748 := "\n".join(XHelpCard._content(XGear.template("weapon", 1748)).map(func(r): return str(r[0])))
	var card_a4107 := "\n".join(XHelpCard._content(XGear.template("armor", 4107)).map(func(r): return str(r[0])))
	_check("t451_help_card_text_synced",
		card_w1826.contains("物伤+30%") and not card_w1826.contains("物伤+300%")
		and card_a4535.contains("所有伤害+20%") and not card_a4535.contains("所有伤害+250%")
		and card_w1099.contains("所有伤害提高13%") and not card_w1099.contains("55%")
		and card_w1673.contains("电伤+25%") and card_w1673.contains("电伤+30%") and not card_w1673.contains("150%")
		and card_w1674.contains("自然伤+20%") and card_w1674.contains("治疗效果+20%") and not card_w1674.contains("100%")
		and card_w1748.contains("治疗效果增加10%") and not card_w1748.contains("15%")
		and card_a4107.contains("黑暗伤害+15%") and not card_a4107.contains("治疗效果+25%"),
		[card_w1826, card_a4535, card_w1099, card_w1673, card_w1674, card_w1748, card_a4107])

	# 宝珠增量保留＋幂等＋回退开关
	var w1826_orb := w1826.duplicate(true)
	w1826_orb.yep.elementAmplify["1"] = float(w1826_orb.yep.elementAmplify["1"]) + 0.12
	var vw1826_orb: Dictionary = XTianqiGear.elem_amp_view(w1826_orb)
	var vw1826_idem: Dictionary = XTianqiGear.elem_amp_view(vw1826_orb)
	XTianqiGear.GEAR_ELEM_RESCALE = false
	var vw1826_off: Dictionary = XTianqiGear.elem_amp_view(w1826)
	XTianqiGear.GEAR_ELEM_RESCALE = true
	_check("t451_gear_elem_rescale_orb_idem_switch",
		absf(float(vw1826_orb.yep.elementAmplify["1"]) - 0.42) < 1e-6
		and absf(float(vw1826_idem.yep.elementAmplify["1"]) - 0.42) < 1e-6
		and absf(float(vw1826_off.yep.elementAmplify["1"]) - 3.0) < 1e-6,
		[vw1826_orb.yep, vw1826_idem.yep, vw1826_off.yep])

	XState.current = null
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		print("%s:%s -> %s" % ["PASS" if x.passed else "FAIL", x.name, str(x.detail)])
	print("TEST_RESULT=%s" % JSON.stringify({"total": results.size(), "passed": passed}))
	get_tree().quit(0 if passed == results.size() else 1)
