extends Node
## 天启篇原版套装模板引擎（XTianqiSuits 模板部分，T515 养成线二期 2B；设计仓《原版养成线重做方案 v0.3》第三节第 3 条「模板套」）：
## 一、五套样板按「类型 × 件数档 × 阶」取表：14 高阶火焰（火系伤）、23 所有伤害板甲（伤害）、9 勇士（生命）、188 战魂（技能消耗）、
##     143 xx套装（掉率，进掉落线加成池、不落档、单件封顶 10）；原效果（被动技能、状态、固定值）不再生效。
## 二、阶＝身上部件最低那一阶；件数档只取够到的最高一档、不超过原套最高件数、原套最低多件档没穿够不算成套。
## 三、混合套（143 有 1 件档）的 1 件档照原样；没归类的套装照原样。
## 四、和 2A 名额同台：三套模板套只生效两套。
## 五、开关 TEMPLATE 关、西游档：全部回到原效果。
## 套装件直接造实例（{equipment: {suits: [号]}, meta: {req_level}}），req_level 70＝四阶、1＝一阶、30＝二阶。

var results: Array = []

const FIRE := 14
const FINAL := 23
const HP := 9
const COST := 188
const DROP := 143


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


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
	return s


func _piece(sid: int, lv := 70) -> Dictionary:
	return {"kind": "armor", "name": "测试套装件%d" % sid, "params": [0, 0, 0, 0, 0, 0, 0, 0], "traits": [], "etypeId": 3,
		"meta": {"req_level": str(lv)}, "equipment": {"suits": [sid]}}


## 穿上：list＝[[套装号, 件数, 等级需求]…]
func _wear(a: XActor, list: Array) -> void:
	a.keep_unequippable = true
	var items := []
	for row in list:
		for i in int(row[1]):
			items.append(_piece(int(row[0]), int(row[2]) if row.size() > 2 else 70))
	for i in range(a.equips.size()):
		a.equips[i] = {}
	for i in range(items.size()):
		if i + 1 < a.equips.size():
			a.equips[i + 1] = items[i]
		else:
			a.equips.append(items[i])
	a.param_mark_dirty()
	a.param_refresh()


func _tpl(a: XActor) -> Array:
	return XEquipSuits.active(a).filter(func(b): return b.has("tqTemplate")).map(func(b): return b.tqTemplate)


func _p(a: XActor) -> Dictionary:
	return XTianqiAffixBattle.personal(a)


func _drop_suit_src(a: XActor) -> Array:
	return XTianqiDrop.sources_of(a).filter(func(x): return str(x.name) == "套装").map(func(x): return float(x.value))


func _run() -> void:
	XMessageBox.auto = true
	seed(20261125)
	XTianqiSuits.reload_template()
	var tbl := XTianqiSuits.template_table()
	_check("table_loaded", not tbl.is_empty() and tbl.get("suits", {}).size() == 5, tbl.get("suits", {}).keys())
	var defs: Array = XDB.table("EquipSuits")
	var s := _state()
	var a: XActor = s.actor(_ids()[0])

	# 一、样板：高阶火焰 3 件四阶 → 火系伤 10（3 件档四阶）；原被动技能 576 不再生效
	_wear(a, [[FIRE, 3]])
	_check("fire_value", is_equal_approx(float(_p(a).get("element_damage:fire", 0.0)), 10.0), _p(a))
	_check("fire_orig_gone", not XEquipSuits.ids(a, "skills").has(576), XEquipSuits.ids(a, "skills"))
	_check("fire_kind", _tpl(a).size() == 1 and int(_tpl(a)[0].step) == 3 and int(_tpl(a)[0].tier) == 4, _tpl(a))
	# 所有伤害板甲 → 伤害加成 10
	_wear(a, [[FINAL, 3]])
	_check("final_value", is_equal_approx(float(_p(a).get("final_damage", 0.0)), 10.0), _p(a))
	_check("final_orig_gone", not XEquipSuits.ids(a, "skills").has(585))
	# 勇士 2 件 → 生命 +5%；原「生命 +500」「状态 41」不再有
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
	# 掉率：143 两件四阶 → 2 件档四阶 5，进掉落线加成池按表值（原值落档会变成 5 档表的 5）；1 件档（经验 +10）照旧
	_wear(a, [[DROP, 2]])
	_check("drop_value", _drop_suit_src(a) == [5.0], XTianqiDrop.sources_of(a))
	var one_tier := XEquipSuits.active(a).filter(func(b): return int(b.requirePieces) == 1 and not b.has("tqTemplate"))
	_check("drop_one_piece_kept", one_tier.size() == 1 and float(one_tier[0].bResultPlus[0]) == 10.0, one_tier)
	var orig2: Dictionary = defs[DROP].bonuses.filter(func(x): return int(x.requirePieces) == 2)[0]
	_check("drop_orig_two_gone", not XEquipSuits.active(a).any(func(b): return b == orig2) and not XEquipSuits.ids(a, "skills").has(1983), XEquipSuits.ids(a, "skills"))
	_check("drop_not_affix", not _p(a).has("drop_rate"))
	# 掉率单件封顶：表里 2 件档换成 15 也只给 10
	var t2: Dictionary = tbl.duplicate(true)
	t2.values["2"] = [8, 10, 12, 15]
	XTianqiSuits.reload_template(t2)
	_check("drop_cap10", _drop_suit_src(a) == [10.0], XTianqiDrop.sources_of(a))
	XTianqiSuits.reload_template()

	# 二、阶取最低：3 件火焰里一件一阶 → 3 件档一阶 5；全二阶 → 6
	_wear(a, [[FIRE, 2], [FIRE, 1, 1]])
	_check("tier_lowest", is_equal_approx(float(_p(a).get("element_damage:fire", 0.0)), 5.0) and XTianqiSuits.suit_tier(a, FIRE) == 1, _p(a))
	_wear(a, [[FIRE, 3, 30]])
	_check("tier_2", is_equal_approx(float(_p(a).get("element_damage:fire", 0.0)), 6.0), _p(a))
	_check("step_fn", XTianqiSuits.template_step(COST, 2) == 0 and XTianqiSuits.template_step(COST, 4) == 3 and XTianqiSuits.template_step(HP, 5) == 2
		and XTianqiSuits.template_step(FIRE, 3) == 3)
	_check("value_fn", XTianqiSuits.template_value("atk_final", 2, 1) == 1.0 and XTianqiSuits.template_value("atk_final", 5, 4) == 15.0
		and XTianqiSuits.template_value("func_regen", 5, 4) == 5.0)

	# 三、没归类的套装照原样（表里没有的第一套多件套）
	var plain := 0
	for i in range(1, defs.size()):
		if defs[i] != null and XTianqiSuits.template_of(i).is_empty() and XTianqiSuits._multi_low(i) >= 2 and not XTianqiSuits._has_one(i):
			plain = i
			break
	_wear(a, [[plain, int(XTianqiSuits._tiers(plain)[-1])]])
	var act := XEquipSuits.active(a)
	_check("plain_unchanged", plain > 0 and act == defs[plain].bonuses and not act.any(func(b): return b.has("tqTemplate")), [plain, act.size()])

	# 四、和 2A 名额同台：火焰 3＋伤害 3＋勇士 2 → 件数多的两套（勇士退）
	_wear(a, [[FIRE, 3], [FINAL, 3], [HP, 2]])
	var p := _p(a)
	_check("cap_two", _tpl(a).size() == 2 and p.has("element_damage:fire") and p.has("final_damage") and not p.has("mhp"), [_tpl(a), p])
	_check("cap_crowded", XTianqiSuits.crowded_out(a, HP))

	# 五、开关关：原效果回来
	_wear(a, [[FIRE, 3]])
	XTianqiSuits.TEMPLATE = false
	a.read_touch()
	_check("off_orig_back", XEquipSuits.ids(a, "skills").has(576) and _tpl(a).is_empty() and not _p(a).has("element_damage:fire"), XEquipSuits.ids(a, "skills"))
	XTianqiSuits.TEMPLATE = true
	a.read_touch()
	_check("on_again", not XEquipSuits.ids(a, "skills").has(576))

	# 西游档：原效果
	var x := _state(false)
	_check("xiyou_inactive", not XTianqi.active(x))
	var b: XActor = x.actor(_ids()[0])
	_wear(b, [[FIRE, 3], [HP, 2]])
	_check("xiyou_orig", XEquipSuits.ids(b, "skills").has(576) and XEquipSuits.ids(b, "states").has(41) and _tpl(b).is_empty(), XEquipSuits.ids(b, "skills"))
	_check("xiyou_bonuses_of_passthrough", XTianqiSuits.bonuses_of(b, FIRE, 3, defs[FIRE].bonuses) == defs[FIRE].bonuses)

	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
