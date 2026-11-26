extends Node
## 天启篇原版套装模板引擎（XTianqiSuits 模板部分，T515 2B＋T529 2B 续；预算稿 v0.16 六.3／九.6 甲／附表一 2B＋D290）：
## 一、五套样板按「类型 × 件数档 × 阶」取表：14 高阶火焰（攻·本系，独立乘，3 件四阶 12）、23 所有伤害板甲（攻·伤害，独立乘，3 件四阶 10）、
##     9 勇士（守·生命，词条池）、188 战魂（功能·技能消耗，词条池）、143 xx套装（掉率，掉落池单件封顶 10）；原效果不再生效。
## 二、攻类单独乘＋同一乘区相加＋混穿逐招（基准配与极品最优配各验一次，恒不稀释）：
##     攻·伤害 5 件 ×1.15／5+2 ×1.20；攻·本系 5 件 ×1.20／5+2 ×1.26；
##     混穿：本系 5＋通用 2（本系 ×1.25、别系 ×1.05）、通用 5＋本系 2（本系 ×1.21、别系 ×1.15）、本系 5＋另一系 2（×1.20／×1.06）；
##     双系招逐候选、属性转换招按转换前原系；MP 伤／治疗／打队友不乘；不触总账守卫。
## 三、验 5 件、5+2 及 2/3 件逐档增、四阶逐阶增；阶取最低；1 件档与未归类照原样；与 2A 名额同台。
## 四、T515 P2 解耦：ENABLED=false 不关模板；XTianqiAffixBattle.ENABLED=false 时词条通道类别保留原效果防白板，掉率与独立乘攻类照常模板生效。
## 五、回退开关 ATTACK_STANDALONE=false 退回 T515 词条池与默认排；TEMPLATE=false 退回原效果；西游档零改动（XTianqi.active 守卫）。

var results: Array = []

const FIRE := 14
const FINAL := 23
const HP := 9
const COST := 188
const DROP := 143
## 真实库中多件档含 2 且最高 ≥5 的套装（EquipSuits.json：[2, 4, 6]），用于验 2/3/5 件与 5+2 组合
const SUIT5_A := 120
const SUIT5_B := 164
const SUIT5_C := 167


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids() -> Array:
	return XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _logic(tianqi := true) -> XBattleLogic:
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
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	return lg


func _piece(sid: int, lv := 70) -> Dictionary:
	return {"kind": "armor", "name": "测试套装件%d" % sid, "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3,
		"meta": {"req_level": str(lv)}, "equipment": {"suits": [sid]}}


func _affix_item(affixes: Array, note := "") -> Dictionary:
	return {"kind": "armor", "name": "测试词条件", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3,
		"note": note, "tianqi_affixes": affixes}


## 穿上：list＝[[套装号, 件数, 等级需求]…]；extra_items＝额外装备实例（词条、属性转换等）
func _wear(a: XActor, list: Array, extra_items: Array = []) -> void:
	a.keep_unequippable = true
	var items := []
	for row in list:
		for i in int(row[1]):
			items.append(_piece(int(row[0]), int(row[2]) if row.size() > 2 else 70))
	for ex in extra_items:
		items.append(ex)
	for i in range(a.equips.size()):
		a.equips[i] = {}
	for i in range(items.size()):
		if i + 1 < a.equips.size():
			a.equips[i + 1] = items[i]
		else:
			a.equips.append(items[i])
	a.param_mark_dirty()
	a.param_refresh()
	a.refresh_passive()


func _skill(element := 0, dmg_type := 1, id := 99991) -> Dictionary:
	return {"id": id, "scope": 1, "hitType": 2, "damage": {"type": dmg_type, "elementId": element, "critical": false, "variance": 0, "formula": "10000"},
		"effects": [], "stypeId": 1, "mpCost": 0, "tpCost": 0, "note": ""}


func _calc(a: XActor, target: XBattler, skill: Dictionary, opts := {}) -> Dictionary:
	var o := {"critical": false, "variance": false, "rawValue": 10000.0}
	o.merge(opts, true)
	return XDamage.calculate(skill, a, target, o)


func _ratio(with_val: float, base_val: float) -> float:
	return with_val / base_val if base_val != 0.0 else 0.0


func _near(x: float, want: float, eps := 0.0005) -> bool:
	return absf(x - want) <= eps


func _tpl(a: XActor) -> Array:
	return XEquipSuits.active(a).filter(func(b): return b.has("tqTemplate")).map(func(b): return b.tqTemplate)


func _p(a: XActor) -> Dictionary:
	return XTianqiAffixBattle.personal(a)


func _drop_suit_src(a: XActor) -> Array:
	return XTianqiDrop.sources_of(a).filter(func(x): return str(x.name) == "套装").map(func(x): return float(x.value))


func _run() -> void:
	XMessageBox.auto = true
	seed(20261126)
	XTianqiSuits.ENABLED = true
	XTianqiSuits.TEMPLATE = true
	XTianqiSuits.ATTACK_STANDALONE = true
	XTianqiAffixBattle.ENABLED = true
	XTianqiSuits.reload_template()
	var tbl := XTianqiSuits.template_table()
	_check("table_loaded", not tbl.is_empty() and tbl.get("suits", {}).size() == 5 and tbl.get("values_by_kind", {}).has("atk_element"),
		[tbl.get("suits", {}).keys(), tbl.get("values_by_kind", {}).keys()])
	var defs: Array = XDB.table("EquipSuits")
	var lg := _logic(true)
	var a: XActor = lg.state.actor(_ids()[0])
	var ally: XActor = lg.state.actor(_ids()[1])
	var e: XEnemy = lg.enemies[0]

	# 一、五套样板：攻类走独立乘（不进词条池），守／功能／掉率照旧
	# 高阶火焰 3 件四阶 → 独立排 3 件四阶 12（火系 ×1.12，非火 ×1.0），不进 element_damage:fire；原被动技能 576 退场
	_wear(a, [[FIRE, 3]])
	_check("fire_standalone_val", is_equal_approx(XTianqiSuits.attack_mult(a, e, 2), 1.12)
		and is_equal_approx(XTianqiSuits.attack_mult(a, e, 3), 1.0) and not _p(a).has("element_damage:fire"),
		[XTianqiSuits.attack_mult(a, e, 2), XTianqiSuits.attack_mult(a, e, 3), _p(a)])
	_check("fire_orig_gone", not XEquipSuits.ids(a, "skills").has(576), XEquipSuits.ids(a, "skills"))
	_check("fire_kind", _tpl(a).size() == 1 and int(_tpl(a)[0].step) == 3 and int(_tpl(a)[0].tier) == 4 and is_equal_approx(float(_tpl(a)[0].value), 12.0), _tpl(a))
	# 所有伤害板甲 3 件四阶 → 独立乘 10（全系 ×1.10），不进 final_damage；原被动技能 585 退场
	_wear(a, [[FINAL, 3]])
	_check("final_standalone_val", is_equal_approx(XTianqiSuits.attack_mult(a, e, 0), 1.10)
		and is_equal_approx(XTianqiSuits.attack_mult(a, e, 2), 1.10) and not _p(a).has("final_damage"),
		[XTianqiSuits.attack_mult(a, e, 0), _p(a)])
	_check("final_orig_gone", not XEquipSuits.ids(a, "skills").has(585))
	# 勇士 2 件 → 守·生命 +5%（词条池不变）；原「生命 +500」「状态 41」不再有
	_wear(a, [])
	var mhp0 := a.mhp
	_wear(a, [[HP, 2]])
	_check("hp_value", is_equal_approx(float(_p(a).get("mhp", 0.0)), 5.0), _p(a))
	_check("hp_rate", is_equal_approx(XTianqiAffixBattle.param_rate(a, 0), 1.05), XTianqiAffixBattle.param_rate(a, 0))
	_check("hp_orig_gone", XEquipSuits.value(a, "param", 0, false) == 0.0 and not XEquipSuits.ids(a, "states").has(41) and not XEquipSuits.ids(a, "skills").has(472))
	_check("hp_panel_up", a.mhp > mhp0, [mhp0, a.mhp])
	# 战魂（原 3／5 件）：2 件不成套、3 件 10、5 件 15、6 件仍按 5 件档
	_wear(a, [[COST, 2]])
	_check("cost_2_none", not _p(a).has("skill_cost") and _tpl(a).is_empty(), _p(a))
	_wear(a, [[COST, 3]])
	_check("cost_3", is_equal_approx(float(_p(a).get("skill_cost", 0.0)), 10.0), _p(a))
	_wear(a, [[COST, 5]])
	_check("cost_5", is_equal_approx(float(_p(a).get("skill_cost", 0.0)), 15.0), _p(a))
	_wear(a, [[COST, 6]])
	_check("cost_6_cap5", is_equal_approx(float(_p(a).get("skill_cost", 0.0)), 15.0), _p(a))
	_check("not_cumulative", _tpl(a).size() == 1, _tpl(a))
	# 掉率：143 两件四阶 → 5；1 件档（经验 +10）照旧；单件封顶 10
	_wear(a, [[DROP, 2]])
	_check("drop_value", _drop_suit_src(a) == [5.0], XTianqiDrop.sources_of(a))
	var one_tier := XEquipSuits.active(a).filter(func(b): return int(b.requirePieces) == 1 and not b.has("tqTemplate"))
	_check("drop_one_piece_kept", one_tier.size() == 1 and float(one_tier[0].bResultPlus[0]) == 10.0, one_tier)
	var orig2: Dictionary = defs[DROP].bonuses.filter(func(x): return int(x.requirePieces) == 2)[0]
	_check("drop_orig_two_gone", not XEquipSuits.active(a).any(func(b): return b == orig2) and not XEquipSuits.ids(a, "skills").has(1983), XEquipSuits.ids(a, "skills"))
	_check("drop_not_affix", not _p(a).has("drop_rate"))
	var t2: Dictionary = tbl.duplicate(true)
	t2.values["2"] = [8, 10, 12, 15]
	XTianqiSuits.reload_template(t2)
	_check("drop_cap10", _drop_suit_src(a) == [10.0], XTianqiDrop.sources_of(a))
	XTianqiSuits.reload_template()

	# 二、阶取最低与全表逐阶／逐档严格递增（含附表一 2B 攻·本系 1/2/4/6、6/7/10/12、11/13/16/20）
	_wear(a, [[FIRE, 2], [FIRE, 1, 1]])
	_check("tier_lowest_elem", is_equal_approx(XTianqiSuits.attack_mult(a, e, 2), 1.06) and XTianqiSuits.suit_tier(a, FIRE) == 1,
		[XTianqiSuits.attack_mult(a, e, 2), XTianqiSuits.suit_tier(a, FIRE)])
	_wear(a, [[FIRE, 3, 30]])
	_check("tier_2_elem", is_equal_approx(XTianqiSuits.attack_mult(a, e, 2), 1.07), XTianqiSuits.attack_mult(a, e, 2))
	_check("step_fn", XTianqiSuits.template_step(COST, 2) == 0 and XTianqiSuits.template_step(COST, 4) == 3 and XTianqiSuits.template_step(HP, 5) == 2
		and XTianqiSuits.template_step(FIRE, 3) == 3)
	var elem_want := {2: [1, 2, 4, 6], 3: [6, 7, 10, 12], 5: [11, 13, 16, 20]}
	var fin_want := {2: [1, 2, 3, 5], 3: [5, 6, 8, 10], 5: [8, 10, 12, 15]}
	var mono_ok := true
	for tier in [1, 2, 3, 4]:
		var e2 := XTianqiSuits.template_value("atk_element", 2, tier)
		var e3 := XTianqiSuits.template_value("atk_element", 3, tier)
		var e5 := XTianqiSuits.template_value("atk_element", 5, tier)
		var f2 := XTianqiSuits.template_value("atk_final", 2, tier)
		var f3 := XTianqiSuits.template_value("atk_final", 3, tier)
		var f5 := XTianqiSuits.template_value("atk_final", 5, tier)
		if e2 != float(elem_want[2][tier - 1]) or e3 != float(elem_want[3][tier - 1]) or e5 != float(elem_want[5][tier - 1]):
			mono_ok = false
		if f2 != float(fin_want[2][tier - 1]) or f3 != float(fin_want[3][tier - 1]) or f5 != float(fin_want[5][tier - 1]):
			mono_ok = false
		if not (e2 < e3 and e3 < e5 and f2 < f3 and f3 < f5):
			mono_ok = false
	for st in [2, 3, 5]:
		for k in ["atk_element", "atk_final"]:
			var v1 := XTianqiSuits.template_value(k, st, 1)
			var v2 := XTianqiSuits.template_value(k, st, 2)
			var v3 := XTianqiSuits.template_value(k, st, 3)
			var v4 := XTianqiSuits.template_value(k, st, 4)
			if not (v1 < v2 and v2 < v3 and v3 < v4):
				mono_ok = false
	_check("table_monotone_and_exact", mono_ok and XTianqiSuits.template_value("func_regen", 5, 4) == 5.0)

	# 三、核心 T529：真实 XDamage.calculate 验 5 件、5+2、2/3 件逐档增、混穿逐招、基准配＋极品最优配不稀释
	var sk_none := _skill(0, 1, 99990)
	var sk_fire := _skill(2, 1, 99991)
	var sk_ice := _skill(3, 1, 99992)
	var sk_thunder := _skill(5, 1, 99993)
	var sk_mp := _skill(2, 2, 99994)
	var sk_heal := _skill(0, 3, 99995)

	# 借真实 [2,4,6] 套号（120/164/167）挂进内存模板表测 5 件与 5+2（不改 suit_template.json 样板名单）
	var t_atk: Dictionary = tbl.duplicate(true)
	t_atk.suits[str(SUIT5_A)] = {"kind": "atk_final"}
	t_atk.suits[str(SUIT5_B)] = {"kind": "atk_final"}
	XTianqiSuits.reload_template(t_atk)

	# 两种配装：基准配（中词条）与极品最优配（重词条：4 件极品终伤＋4 件极品火伤），独立乘下比值必须完全恒定
	var base_gear := [_affix_item([{"key": "final_damage", "tier": 4, "grade": "normal"}, {"key": "element_damage", "tier": 4, "grade": "normal", "extra": {"element": "fire"}}])]
	var peak_gear := [
		_affix_item([{"key": "final_damage", "tier": 4, "grade": "perfect"}, {"key": "element_damage", "tier": 4, "grade": "perfect", "extra": {"element": "fire"}}]),
		_affix_item([{"key": "final_damage", "tier": 4, "grade": "perfect"}, {"key": "element_damage", "tier": 4, "grade": "perfect", "extra": {"element": "fire"}}]),
		_affix_item([{"key": "final_damage", "tier": 4, "grade": "perfect"}, {"key": "element_damage", "tier": 4, "grade": "perfect", "extra": {"element": "fire"}}]),
	]
	for tag in ["base", "peak"]:
		var g: Array = base_gear if tag == "base" else peak_gear
		_wear(a, [], g)
		var r0 := _calc(a, e, sk_none)
		var d0 := float(r0.settled)
		_wear(a, [[SUIT5_A, 2]], g)
		var d2 := float(_calc(a, e, sk_none).settled)
		_wear(a, [[SUIT5_A, 3]], g)
		var d3 := float(_calc(a, e, sk_none).settled)
		_wear(a, [[SUIT5_A, 5]], g)
		var r5 := _calc(a, e, sk_none)
		var d5 := float(r5.settled)
		_wear(a, [[SUIT5_A, 5], [SUIT5_B, 2]], g)
		var d52 := float(_calc(a, e, sk_none).settled)
		var k2 := _ratio(d2, d0)
		var k3 := _ratio(d3, d0)
		var k5 := _ratio(d5, d0)
		var k52 := _ratio(d52, d0)
		_check("atk_final_steps_" + tag, _near(k2, 1.05) and _near(k3, 1.10) and _near(k5, 1.15) and _near(k52, 1.20)
			and not _near(k52, 1.15 * 1.05, 0.002) and d0 < d2 and d2 < d3 and d3 < d5 and d5 < d52
			and is_equal_approx(float(r5.breakdown.row.terminal), float(r0.breakdown.row.terminal)),
			[k2, k3, k5, k52, r0.breakdown.row.terminal, r5.breakdown.row.terminal])

	# 攻·本系（火 5 / 火 5+火 2，基准配＋极品最优配）
	var t_elem: Dictionary = tbl.duplicate(true)
	t_elem.suits[str(SUIT5_A)] = {"kind": "atk_element", "element": "fire"}
	t_elem.suits[str(SUIT5_B)] = {"kind": "atk_element", "element": "fire"}
	XTianqiSuits.reload_template(t_elem)
	for tag in ["base", "peak"]:
		var g: Array = base_gear if tag == "base" else peak_gear
		_wear(a, [], g)
		var rf0 := _calc(a, e, sk_fire)
		var df0 := float(rf0.settled)
		var di0 := float(_calc(a, e, sk_ice).settled)
		_wear(a, [[SUIT5_A, 2]], g)
		var df2 := float(_calc(a, e, sk_fire).settled)
		_wear(a, [[SUIT5_A, 3]], g)
		var df3 := float(_calc(a, e, sk_fire).settled)
		_wear(a, [[SUIT5_A, 5]], g)
		var rf5 := _calc(a, e, sk_fire)
		var df5 := float(rf5.settled)
		var di5 := float(_calc(a, e, sk_ice).settled)
		_wear(a, [[SUIT5_A, 5], [SUIT5_B, 2]], g)
		var df52 := float(_calc(a, e, sk_fire).settled)
		var di52 := float(_calc(a, e, sk_ice).settled)
		var kf2 := _ratio(df2, df0)
		var kf3 := _ratio(df3, df0)
		var kf5 := _ratio(df5, df0)
		var kf52 := _ratio(df52, df0)
		_check("atk_elem_steps_" + tag, _near(kf2, 1.06) and _near(kf3, 1.12) and _near(kf5, 1.20) and _near(kf52, 1.26)
			and not _near(kf52, 1.20 * 1.06, 0.002) and _near(_ratio(di5, di0), 1.0) and _near(_ratio(di52, di0), 1.0)
			and is_equal_approx(float(rf5.breakdown.row.bonus), float(rf0.breakdown.row.bonus)),
			[kf2, kf3, kf5, kf52, _ratio(di5, di0), _ratio(di52, di0)])

	# 混穿逐招：A=火本系、B=通用伤害、C=冰本系
	var t_mix: Dictionary = tbl.duplicate(true)
	t_mix.suits[str(SUIT5_A)] = {"kind": "atk_element", "element": "fire"}
	t_mix.suits[str(SUIT5_B)] = {"kind": "atk_final"}
	t_mix.suits[str(SUIT5_C)] = {"kind": "atk_element", "element": "ice"}
	XTianqiSuits.reload_template(t_mix)
	_wear(a, [], base_gear)
	var b_fire := float(_calc(a, e, sk_fire).settled)
	var b_ice := float(_calc(a, e, sk_ice).settled)
	var b_th := float(_calc(a, e, sk_thunder).settled)
	var b_none := float(_calc(a, e, sk_none).settled)
	# ① 本系 5（火 +20）＋通用 2（+5）：火招 ×1.25（非 1.20*1.05=1.26），冰／无属性招 ×1.05
	_wear(a, [[SUIT5_A, 5], [SUIT5_B, 2]], base_gear)
	var m1_f := _ratio(float(_calc(a, e, sk_fire).settled), b_fire)
	var m1_i := _ratio(float(_calc(a, e, sk_ice).settled), b_ice)
	var m1_n := _ratio(float(_calc(a, e, sk_none).settled), b_none)
	_check("mix_elem5_fin2", _near(m1_f, 1.25) and not _near(m1_f, 1.26, 0.002) and _near(m1_i, 1.05) and _near(m1_n, 1.05), [m1_f, m1_i, m1_n])
	# ② 通用 5（+15）＋本系 2（火 +6）：火招 ×1.21（非 1.15*1.06=1.219），冰／无属性招 ×1.15
	_wear(a, [[SUIT5_B, 5], [SUIT5_A, 2]], base_gear)
	var m2_f := _ratio(float(_calc(a, e, sk_fire).settled), b_fire)
	var m2_i := _ratio(float(_calc(a, e, sk_ice).settled), b_ice)
	var m2_n := _ratio(float(_calc(a, e, sk_none).settled), b_none)
	_check("mix_fin5_elem2", _near(m2_f, 1.21) and not _near(m2_f, 1.219, 0.002) and _near(m2_i, 1.15) and _near(m2_n, 1.15), [m2_f, m2_i, m2_n])
	# ③ 本系 5（火 +20）＋另一系 2（冰 +6）：火招 ×1.20、冰招 ×1.06、雷／无属性 ×1.00
	_wear(a, [[SUIT5_A, 5], [SUIT5_C, 2]], base_gear)
	var m3_f := _ratio(float(_calc(a, e, sk_fire).settled), b_fire)
	var m3_i := _ratio(float(_calc(a, e, sk_ice).settled), b_ice)
	var m3_t := _ratio(float(_calc(a, e, sk_thunder).settled), b_th)
	var m3_n := _ratio(float(_calc(a, e, sk_none).settled), b_none)
	_check("mix_elem5_other2", _near(m3_f, 1.20) and _near(m3_i, 1.06) and _near(m3_t, 1.0) and _near(m3_n, 1.0), [m3_f, m3_i, m3_t, m3_n])
	# ④ 双系招（火＋冰）逐候选：火候选拿 ×1.20，冰候选拿 ×1.06
	var dual_res := _calc(a, e, sk_fire, {"elements": [2, 3]})
	var dual_cands: Array = dual_res.breakdown.candidates
	_wear(a, [], base_gear)
	var dual_base: Array = _calc(a, e, sk_fire, {"elements": [2, 3]}).breakdown.candidates
	var dc0 := _ratio(float(dual_cands[0].gross), float(dual_base[0].gross))
	var dc1 := _ratio(float(dual_cands[1].gross), float(dual_base[1].gross))
	_check("dual_element_per_candidate", dual_cands.size() == 2 and _near(dc0, 1.20) and _near(dc1, 1.06), [dc0, dc1])
	# ⑤ 属性转换招（原火 2 → 转雷 5）：目标侧按雷 5（row.element == 5），攻击方原系按火 2，穿火 5 得 ×1.20，穿雷 5 不吃（×1.00）
	var conv_item := {"kind": "armor", "name": "属性转换件", "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3,
		"meta": {"DamageElements": "5"}, "tianqi_affixes": []}
	_wear(a, [], [conv_item])
	var conv_r0 := _calc(a, e, sk_fire)
	var conv_base := float(conv_r0.settled)
	_wear(a, [[SUIT5_A, 5]], [conv_item])
	var conv_rf := _calc(a, e, sk_fire)
	var conv_fire := _ratio(float(conv_rf.settled), conv_base)
	var t_th: Dictionary = tbl.duplicate(true)
	t_th.suits[str(SUIT5_A)] = {"kind": "atk_element", "element": "thunder"}
	XTianqiSuits.reload_template(t_th)
	_wear(a, [[SUIT5_A, 5]], [conv_item])
	var conv_rt := _calc(a, e, sk_fire)
	var conv_th := _ratio(float(conv_rt.settled), conv_base)
	_check("converted_uses_original_element", int(conv_r0.breakdown.row.element) == 5 and int(conv_rf.breakdown.row.element) == 5
		and _near(conv_fire, 1.20) and _near(conv_th, 1.0),
		[conv_r0.breakdown.row.element, conv_rf.breakdown.row.element, conv_fire, conv_th])
	# ⑥ 非 HP 伤害（MP 伤）、治疗、打队友、总账守卫
	XTianqiSuits.reload_template(t_mix)
	_wear(a, [], base_gear)
	var mp0 := float(_calc(a, e, sk_mp).settled)
	var heal0 := float(_calc(a, ally, sk_heal).value)
	var ally0 := float(_calc(a, ally, sk_fire).settled)
	_wear(a, [[SUIT5_A, 5], [SUIT5_B, 2]], base_gear)
	var mp1 := float(_calc(a, e, sk_mp).settled)
	var heal1 := float(_calc(a, ally, sk_heal).value)
	var ally1 := float(_calc(a, ally, sk_fire).settled)
	var guard_was := XTianqiLedger.GUARD
	XTianqiLedger.GUARD = true
	XTianqiLedger.violations.clear()
	XTianqiLedger._reported.clear()
	var _r_audit := _calc(a, e, sk_fire)
	var viols := XTianqiLedger.violations.duplicate()
	XTianqiLedger.GUARD = guard_was
	_check("non_hp_ally_heal_untouched", is_equal_approx(mp0, mp1) and is_equal_approx(heal0, heal1) and is_equal_approx(ally0, ally1),
		[[mp0, mp1], [heal0, heal1], [ally0, ally1]])
	_check("ledger_guard_clean", viols.is_empty(), viols)
	XTianqiSuits.reload_template()

	# 四、没归类的套装照原样；和 2A 名额同台（三套只两套）
	var plain := 0
	for i in range(1, defs.size()):
		if defs[i] != null and XTianqiSuits.template_of(i).is_empty() and XTianqiSuits._multi_low(i) >= 2 and not XTianqiSuits._has_one(i):
			plain = i
			break
	_wear(a, [[plain, int(XTianqiSuits._tiers(plain)[-1])]])
	var act := XEquipSuits.active(a)
	_check("plain_unchanged", plain > 0 and act == defs[plain].bonuses and not act.any(func(b): return b.has("tqTemplate")), [plain, act.size()])

	_wear(a, [[FIRE, 3], [FINAL, 3], [HP, 2]])
	_check("cap_two", _tpl(a).size() == 2 and is_equal_approx(XTianqiSuits.attack_mult(a, e, 2), 1.22) and not _p(a).has("mhp"),
		[_tpl(a), XTianqiSuits.attack_mult(a, e, 2), _p(a)])
	_check("cap_crowded", XTianqiSuits.crowded_out(a, HP))

	# 五、T515 P2 解耦：
	# 5a. 关 2A 上限 ENABLED=false，模板引擎 template_on 仍开，三套全部按模板生效
	XTianqiSuits.ENABLED = false
	a.read_touch()
	_check("p2_decoupled_from_cap", not XTianqiSuits.on(a) and XTianqiSuits.template_on(a)
		and _tpl(a).size() == 3 and is_equal_approx(float(_p(a).get("mhp", 0.0)), 5.0)
		and is_equal_approx(XTianqiSuits.attack_mult(a, e, 2), 1.22),
		[_tpl(a).size(), _p(a), XTianqiSuits.attack_mult(a, e, 2)])
	XTianqiSuits.ENABLED = true
	a.read_touch()
	# 5b. 关词条战斗层 XTianqiAffixBattle.ENABLED=false：走词条池的守／功能套不替换原效果（防白板），掉率与独立乘攻类仍按模板生效
	XTianqiAffixBattle.ENABLED = false
	_wear(a, [[HP, 2]])
	var hp_fallback_ok := XEquipSuits.value(a, "param", 0, false) == 500.0 and XEquipSuits.ids(a, "states").has(41) and _tpl(a).is_empty()
	_wear(a, [[DROP, 2]])
	var drop_still_tpl := _drop_suit_src(a) == [5.0] and _tpl(a).size() == 1
	_wear(a, [[FIRE, 3], [FINAL, 3]])
	var atk_still_tpl := _tpl(a).size() == 2 and is_equal_approx(XTianqiSuits.attack_mult(a, e, 2), 1.22)
	# 再关 ATTACK_STANDALONE：攻类退回词条池，因词条层关着也保留原效果（576/585 回来，不白板）
	XTianqiSuits.ATTACK_STANDALONE = false
	a.read_touch()
	var atk_fallback_ok := XEquipSuits.ids(a, "skills").has(576) and XEquipSuits.ids(a, "skills").has(585) and _tpl(a).is_empty()
	XTianqiSuits.ATTACK_STANDALONE = true
	XTianqiAffixBattle.ENABLED = true
	a.read_touch()
	_check("p2_affix_off_no_blank", hp_fallback_ok and drop_still_tpl and atk_still_tpl and atk_fallback_ok,
		[hp_fallback_ok, drop_still_tpl, atk_still_tpl, atk_fallback_ok])

	# 六、回退开关 ATTACK_STANDALONE=false 与 TEMPLATE=false
	_wear(a, [[FIRE, 3], [FINAL, 3]], peak_gear)
	XTianqiAffixBattle.start(lg)
	var dmg_standalone := float(_calc(a, e, sk_fire).settled)
	XTianqiSuits.ATTACK_STANDALONE = false
	a.read_touch()
	XTianqiAffixBattle.start(lg)
	var p_rb := _p(a)
	var mult_rb := XTianqiSuits.attack_mult(a, e, 2)
	var dmg_pooled := float(_calc(a, e, sk_fire).settled)
	# 回退后走词条池（高词条稀释，且攻·本系回默认排 10 非 12），独立乘为 1.0，伤害低于独立乘
	_check("rollback_attack_standalone", is_equal_approx(mult_rb, 1.0)
		and is_equal_approx(float(p_rb.get("element_damage:fire", 0.0)) - float(_p_gear_only(a, peak_gear).get("element_damage:fire", 0.0)), 10.0)
		and is_equal_approx(float(p_rb.get("final_damage", 0.0)) - float(_p_gear_only(a, peak_gear).get("final_damage", 0.0)), 10.0)
		and dmg_pooled < dmg_standalone,
		[mult_rb, dmg_pooled, dmg_standalone])
	XTianqiSuits.ATTACK_STANDALONE = true
	a.read_touch()
	_wear(a, [[FIRE, 3], [FINAL, 3]], peak_gear)
	XTianqiAffixBattle.start(lg)
	_check("standalone_on_again", is_equal_approx(XTianqiSuits.attack_mult(a, e, 2), 1.22)
		and is_equal_approx(float(_calc(a, e, sk_fire).settled), dmg_standalone))

	_wear(a, [[FIRE, 3]])
	XTianqiSuits.TEMPLATE = false
	a.read_touch()
	_check("off_orig_back", XEquipSuits.ids(a, "skills").has(576) and _tpl(a).is_empty() and is_equal_approx(XTianqiSuits.attack_mult(a, e, 2), 1.0), XEquipSuits.ids(a, "skills"))
	XTianqiSuits.TEMPLATE = true
	a.read_touch()
	_check("on_again", not XEquipSuits.ids(a, "skills").has(576) and is_equal_approx(XTianqiSuits.attack_mult(a, e, 2), 1.12))

	# 七、西游档：零改动（XTianqi.active 守卫）
	var xlg := _logic(false)
	_check("xiyou_inactive", not XTianqi.active(xlg.state))
	var b: XActor = xlg.state.actor(_ids()[0])
	var xe: XEnemy = xlg.enemies[0]
	_wear(b, [[FIRE, 3], [HP, 2]])
	_check("xiyou_orig", XEquipSuits.ids(b, "skills").has(576) and XEquipSuits.ids(b, "states").has(41) and _tpl(b).is_empty()
		and not XTianqiSuits.template_on(b) and is_equal_approx(XTianqiSuits.attack_mult(b, xe, 2), 1.0), XEquipSuits.ids(b, "skills"))
	_check("xiyou_bonuses_of_passthrough", XTianqiSuits.bonuses_of(b, FIRE, 3, defs[FIRE].bonuses) == defs[FIRE].bonuses)
	var x_dmg_on := float(_calc(b, xe, sk_fire).settled)
	XTianqiSuits.ATTACK_STANDALONE = false
	XTianqiSuits.TEMPLATE = false
	b.read_touch()
	var x_dmg_off := float(_calc(b, xe, sk_fire).settled)
	XTianqiSuits.ATTACK_STANDALONE = true
	XTianqiSuits.TEMPLATE = true
	_check("xiyou_damage_zero_change", is_equal_approx(x_dmg_on, x_dmg_off), [x_dmg_on, x_dmg_off])

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _p_gear_only(a: XActor, gear: Array) -> Dictionary:
	var saved := a.equips.duplicate()
	_wear(a, [], gear)
	var out := _p(a)
	a.equips = saved
	a.param_mark_dirty()
	a.param_refresh()
	a.refresh_passive()
	return out
