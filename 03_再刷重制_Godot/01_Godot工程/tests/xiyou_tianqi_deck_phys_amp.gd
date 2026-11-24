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

	XState.current = null
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		print("%s:%s -> %s" % ["PASS" if x.passed else "FAIL", x.name, str(x.detail)])
	print("TEST_RESULT=%s" % JSON.stringify({"total": results.size(), "passed": passed}))
	get_tree().quit(0 if passed == results.size() else 1)
