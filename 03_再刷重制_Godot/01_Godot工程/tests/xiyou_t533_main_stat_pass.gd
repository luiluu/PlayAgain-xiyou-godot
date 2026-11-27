extends Node
## 【cc·T533】天启篇防御通过率按这一招的主属性算（预算稿 v0.16 七.4／九.17，D290；协调 11-27 定口径 A）：
## 1. 纯物攻／纯魔攻卡招：通过率用的攻击值＝物攻／魔攻，开关开关结果一样（零变化）
## 2. 吃物防的卡招（5647）：通过率＝defense_rate(物防, 目标那一防)；开关关回物攻
## 3. 吃生命的卡招（5673）：主属性值＝生命上限 ÷25（标准线 hp_mult）
## 4. 露丝 max_of（1177）：主属性值＝物攻魔攻取高；多属性（1094 物攻魔攻各半）A＝加权平均、B＝取最大项（只给对照表）
## 5. 我方 1 号普攻（T553 ATTACK1_SPEC）＝物攻；原版公式招（非卡）、开关关、西游档一律 []（照旧）
## 6. 正式结算 XDamage.calculate 的 breakdown.row.defense 跟着变；无视防御（T530 def_ignore）那一路也用主属性值

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a, b: float, eps := 1e-4) -> bool:
	return a != null and absf(float(a) - b) <= eps


func _state(tianqi := true) -> XState:
	var w: Array = XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))
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
		s.actor(id).change_level(81)
		s.actor(id).recover_all()
	return s


func _actor(s: XState) -> XActor:
	return s.actor(int(s.party[0])) if "party" in s and not s.party.is_empty() else s.actor(int(XTier.ids(XTier.WEAK)[0]))


func _row_def(item: Dictionary, a: XBattler, e: XBattler) -> float:
	var r := XDamage.calculate(item, a, e, {"critical": false, "variance": false, "rawValue": 10000.0})
	return float(r.get("breakdown", {}).get("row", {}).get("defense", NAN))


func _expect(mode: String, v: float, e: XBattler) -> float:
	return XDamage.defense_rate(v, e.mdf if mode == "magical" else e.def)


func _run() -> void:
	var s := _state(true)
	var a := _actor(s)
	var e := XEnemy.new().setup(1, 3, 100.0)
	_check("setup", a != null and XTianqi.active(s) and XTianqiSkills.cards_on() and (e.def > 0.0 or e.mdf > 0.0), {"def": e.def, "mdf": e.mdf})
	var hp_mult := float(XTianqiBase.line_data().get("line", {}).get("hp_mult", 25))
	_check("hp_mult_25", _near(hp_mult, 25.0), hp_mult)
	# 1. 纯物攻／纯魔攻
	for pair in [[101, "atk"], [102, "mat"]]:
		var it: Dictionary = XDB.rec("Skills", pair[0])
		var want: float = a.atk if pair[1] == "atk" else a.mat
		var pa := XDamage.pass_attack(it, a)
		var on := _row_def(it, a, e)
		XDamage.MAIN_STAT_PASS = false
		var off := _row_def(it, a, e)
		XDamage.MAIN_STAT_PASS = true
		_check("g1_pure_%s_%d" % [pair[1], pair[0]], pa.size() == 2 and _near(pa[0], want) and _near(on, off), {"pa": pa, "want": want, "on": on, "off": off, "mode": XDamage.item_mode(it)})
	# 2. 吃物防
	var it_def: Dictionary = XDB.rec("Skills", 5647)
	var md := XDamage.item_mode(it_def)
	var pa_def := XDamage.pass_attack(it_def, a)
	var on_def := _row_def(it_def, a, e)
	XDamage.MAIN_STAT_PASS = false
	var off_def := _row_def(it_def, a, e)
	XDamage.MAIN_STAT_PASS = true
	_check("g2_def_skill_uses_def", pa_def.size() == 2 and _near(pa_def[0], a.def) and _near(on_def, _expect(md, a.def, e)), {"pa": pa_def, "def": a.def, "on": on_def, "mode": md})
	_check("g2_switch_off_back_to_atk", _near(off_def, _expect(md, a.atk if md != "magical" else a.mat, e)), {"off": off_def})
	# 3. 吃生命
	var it_hp: Dictionary = XDB.rec("Skills", 5673)
	var pa_hp := XDamage.pass_attack(it_hp, a)
	_check("g3_mhp_skill_div25", pa_hp.size() == 2 and _near(pa_hp[0], a.mhp / 25.0), {"pa": pa_hp, "mhp": a.mhp})
	_check("g3_row_defense", _near(_row_def(it_hp, a, e), _expect(XDamage.item_mode(it_hp), a.mhp / 25.0, e)))
	# 4. max_of、多属性 A／B
	var it_mo: Dictionary = XDB.rec("Skills", 1177)
	var d_mo := XDamage.card_damage_spec(it_mo, a)
	_check("g4_max_of", _near(XDamage.main_stat_value(d_mo, a, "A"), maxf(a.atk, a.mat)) and _near(XDamage.main_stat_value(d_mo, a, "B"), maxf(a.atk, a.mat)), d_mo)
	var it_am: Dictionary = XDB.rec("Skills", 1094)
	var d_am := XDamage.card_damage_spec(it_am, a)
	_check("g4_atk_mat_half_A_avg", _near(XDamage.main_stat_value(d_am, a, "A"), 0.5 * a.atk + 0.5 * a.mat), d_am)
	_check("g4_atk_mat_half_B_atk", _near(XDamage.main_stat_value(d_am, a, "B"), a.atk))
	var mix := {"stats": {"atk": 1.5, "def": 0.8, "mdf": 0.8}}
	_check("g4_weighted_formula", _near(XDamage.main_stat_value(mix, a, "A"), (1.5 * a.atk + 0.8 * a.def + 0.8 * a.mdf) / 3.1)
		and _near(XDamage.main_stat_value(mix, a, "B"), a.atk))
	var hpmix := {"stats": {"atk": 1, "mhp": 0.02}}
	_check("g4_hp_weight_folded", _near(XDamage.main_stat_value(hpmix, a, "A"), (a.atk + 0.02 * a.mhp) / 1.5)
		and _near(XDamage.main_stat_value(hpmix, a, "B"), a.atk))
	# 5. 普攻、非卡招、开关、西游档
	var it1: Dictionary = XDB.rec("Skills", 1)
	var pa1 := XDamage.pass_attack(it1, a)
	_check("g5_attack1_atk", XTianqiSkills.attack1_applies(it1, a) == (pa1.size() == 2) and (pa1.is_empty() or _near(pa1[0], a.atk)), pa1)
	var raw := {"id": 99533, "scope": 1, "hitType": 1, "stypeId": 1, "mpCost": 0, "tpCost": 0,
		"damage": {"type": 1, "elementId": -1, "critical": false, "variance": 0, "formula": "a.def * 4"}, "effects": [], "note": ""}
	_check("g5_non_card_unchanged", XDamage.pass_attack(raw, a).is_empty())
	_check("g5_enemy_raw_unchanged", XDamage.pass_attack(raw, e).is_empty())
	XDamage.MAIN_STAT_PASS = false
	_check("g5_switch_off_empty", XDamage.pass_attack(it_def, a).is_empty() and XDamage.pass_attack(it_hp, a).is_empty())
	XDamage.MAIN_STAT_PASS = true
	# 6. 西游档零改动
	var sx := _state(false)
	var ax := _actor(sx)
	var it_def_x: Dictionary = XDB.rec("Skills", 5647)
	_check("g6_xiyou_empty", not XTianqi.active(sx) and XDamage.pass_attack(it_def_x, ax).is_empty() and XDamage.pass_attack(XDB.rec("Skills", 5673), ax).is_empty())
	var on_x := _row_def(it_def_x, ax, e)
	XDamage.MAIN_STAT_PASS = false
	var off_x := _row_def(it_def_x, ax, e)
	XDamage.MAIN_STAT_PASS = true
	_check("g6_xiyou_row_same", _near(on_x, off_x), {"on": on_x, "off": off_x})
	var passed := 0
	for r in results:
		if r.passed:
			passed += 1
		else:
			print("FAIL %s %s" % [r.name, JSON.stringify(r.detail)])
	print("TEST_RESULT=%s" % JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
