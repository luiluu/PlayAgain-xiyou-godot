extends Node
## 【cc·T081】天启篇期四暗装接线（XTianqiBase.PHASE4，基础数值重构 v0.4 第七节第 2 条、第十节 T012-b）：
## 一、总开关默认关；关着每一行都是「关着」那一套（本体 NAN、K 1、U 1、守层者旧表、治疗照乘、绝对值原数、单段不封、九线爆伤不封、秘籍读旧键、面板没有天启注视）。
## 二、开着、天启篇存档：每一行都和总开关一致（rows_state），本体读标准线×职责×速度档，K＝表里的 0.088、进 dealt_parts，面板一行「天启注视　伤害 ×0.088」。
## 三、开着但是西游档：一律走关着那一套。
## 四、单段有效系数上限：开着时卡面系数×权重×条件超过档位上限压回上限，关着不封；全部卡在上限以内（数据校验同口径）。
## 五、角色卡跟着总开关开（CARDS 本身不动）。
## 读的表：tianqi_data/base_line.json、abs_rescale.json、balance_table.json（combat_rules）、damage_ledger.json（phase4）、skill_rework.json（rules.single_hit_cap）。

const XIAOYAO := 1  # 狗逍遥：强者、输出、慢
const LVSIJI := 2

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	seed(20261117)
	XTianqiSkills.reload()
	XTianqiBase.clear_cache()
	XGojo.unlock_override = 0
	_check("default_off", not XTianqiBase.PHASE4 and not XTianqiSkills.CARDS)
	_off()
	_on()
	_xiyou()
	_hit_cap()
	XTianqiBase.PHASE4 = false
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _weak_ids() -> Array:
	return XTianqiSkills.ids(XTier.WEAK, true)


func _state(tianqi := true) -> XState:
	var w := _weak_ids().filter(func(id): return id != LVSIJI)
	var lineup := [XIAOYAO, LVSIJI, w[0], w[1], w[2]]
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


func _all_rows(want: bool) -> bool:
	var st := XTianqiBase.rows_state()
	for k in st:
		if bool(st[k]) != want:
			return false
	return true


## 关着：天启篇存档也照现在
func _off() -> void:
	XTianqiBase.PHASE4 = false
	var s := _state()
	var a: XActor = s.actor(XIAOYAO)
	a.change_level(81)
	_check("off.on", not XTianqiBase.on())
	_check("off.rows", _all_rows(false), XTianqiBase.rows_state())
	_check("off.base_nan", is_nan(XTianqiBase.param_base(a, 2)))
	var cls: Array = a.class_data().params
	_check("off.base_curve", is_equal_approx(a.param_base_direct(2), float(cls[2][a.level])), [a.param_base_direct(2), cls[2][a.level]])
	_check("off.k", XTianqiBase.k_for(a) == 1.0 and float(XTianqiCombat.dealt_parts(a, s).get("k", 0.0)) == 1.0)
	_check("off.u", XTianqiBase.boss_hp_unit(false) == 1.0 and XTianqiBase.boss_hp_unit(true) == 1.0)
	var old := {1: 2.0}
	_check("off.guardian_old", is_same(XTianqiBase.guardian_table("hp_base", old), old))
	_check("off.heal_x5", XTianqiBase.heal_skip_types().is_empty())
	_check("off.nine_crit", XTianqiBase.nine_crit_cap() < 0.0)
	_check("off.secret", XTianqiBase.secret_slot(0.123) == 0.123)
	_check("off.abs", XTianqiBase.abs_value("item_fixed_heal", 1, 500.0, a) == 500.0)
	_check("off.hit_cap", XTianqiBase.single_hit_cap(a) == 0.0)
	_check("off.gaze", XTianqiBase.gaze_row().is_empty())
	_check("off.cards", not XTianqiSkills.cards_on() and XDB.rec("Skills", 3632).get("_tianqi_new") == null and not str(XDB.rec("Skills", 3632).get("damage", {}).get("formula", "")).contains("XTianqiSkills"))


## 开着、天启篇存档
func _on() -> void:
	XTianqiBase.PHASE4 = true
	XTianqiBase.clear_cache()
	var s := _state()
	_check("on.survives_new_game", XTianqiBase.PHASE4)
	var a: XActor = s.actor(XIAOYAO)
	a.change_level(81)
	a.param_mark_dirty()
	_check("on.on", XTianqiBase.on(), [XTianqiBase.PHASE4, XTianqi.active(XState.current)])
	_check("on.rows", _all_rows(true), XTianqiBase.rows_state())
	_check("on.cards_follow", XTianqiSkills.cards_on() and not XTianqiSkills.CARDS and str(XDB.rec("Skills", 3632).damage.formula).contains("XTianqiSkills"))
	# 本体：标准线 20＋20×81＝1640；输出 hp/def ×0.9、慢速 ×0.8
	var lv := 81.0
	var atk := floorf(20.0 + 20.0 * lv)
	_check("on.base_atk", a.param_base_direct(2) == atk, [a.param_base_direct(2), atk])
	_check("on.base_mhp", a.param_base_direct(0) == floorf((20.0 + 20.0 * lv) * 25.0 * 0.9), a.param_base_direct(0))
	_check("on.base_def", a.param_base_direct(3) == floorf((20.0 + 20.0 * lv) * 0.9), a.param_base_direct(3))
	_check("on.base_agi", a.param_base_direct(6) == floorf((20.0 + 20.0 * lv) * 0.8), a.param_base_direct(6))
	_check("on.base_not_curve", a.param_base_direct(2) != float(a.class_data().params[2][a.level]))
	# K
	_check("on.k_table", is_equal_approx(XTianqiBase.k_base(), 0.088), XTianqiBase.k_base())
	var on_parts := XTianqiCombat.dealt_parts(a, s)
	XTianqiBase.PHASE4 = false
	var off_parts := XTianqiCombat.dealt_parts(a, s)
	XTianqiBase.PHASE4 = true
	_check("on.k_dealt", is_equal_approx(float(on_parts.mult), float(off_parts.mult) * 0.088) and is_equal_approx(float(on_parts.k), 0.088), [on_parts, off_parts])
	_check("on.gaze_row", XTianqiBase.gaze_row() == ["天启注视", "伤害 ×0.088"], XTianqiBase.gaze_row())
	var rows := XStatusPage.global_bonuses(a)
	_check("on.gaze_panel", not rows.is_empty() and rows[0] == ["天启注视", "伤害 ×0.088"], rows.slice(0, 2))
	# U、守层者、治疗、九线、秘籍、绝对值、单段上限
	_check("on.u", XTianqiBase.boss_hp_unit(false) == 1.0 and XTianqiBase.boss_hp_unit(true) == 1.0)  # 表里先填 1
	var old := {1: 2.0}
	_check("on.guardian_fallback", is_same(XTianqiBase.guardian_table("hp_base", old), old))  # guardian_phase4 由 T012-c 补，缺就退回旧表
	_check("on.heal_x5_off", XTianqiBase.heal_skip_types() == [3, 4])
	_check("on.nine_crit", is_equal_approx(XTianqiBase.nine_crit_cap(), 0.3))
	_check("on.secret", is_equal_approx(XTianqiBase.secret_slot(0.123), 0.08))
	var heal := XTianqiBase.abs_value("item_fixed_heal", 1, 500.0, a)
	_check("on.abs_item", heal == floorf(float(a.mhp) * 7.2 / 100.0), [heal, a.mhp])
	_check("on.abs_dot_sign", XTianqiBase.abs_value("state_dot", 33, -300.0, a) == -floorf(float(a.mhp) * 4.3 / 100.0))
	_check("on.abs_unknown", XTianqiBase.abs_value("item_fixed_heal", 999999, 77.0, a) == 77.0)
	_check("on.hit_cap_strong", XTianqiBase.single_hit_cap(a) == 11.0)
	_check("on.hit_cap_weak", XTianqiBase.single_hit_cap(s.actor(LVSIJI)) == float(XTianqiSkills.data().rules.single_hit_cap.get(XTianqiSkills.tier_of(s.actor(LVSIJI)), 0)))
	_check("on.hit_cap_enemy", XTianqiBase.single_hit_cap(null) == 0.0)
	XTianqiBase.PHASE4 = false


## 开着但是西游档：全走关着
func _xiyou() -> void:
	XTianqiBase.PHASE4 = true
	var s := _state(false)
	var a: XActor = s.actor(XIAOYAO)
	a.change_level(81)
	_check("xiyou.off", not XTianqiBase.on())
	_check("xiyou.base_curve", is_nan(XTianqiBase.param_base(a, 2)) and is_equal_approx(a.param_base_direct(2), float(a.class_data().params[2][a.level])))
	_check("xiyou.k", XTianqiBase.k_for(a) == 1.0 and XTianqiBase.gaze_row().is_empty())
	_check("xiyou.abs", XTianqiBase.abs_value("item_fixed_heal", 1, 500.0, a) == 500.0)
	_check("xiyou.cards", not XTianqiSkills.cards_on())
	XTianqiBase.PHASE4 = false


## 单段上限：开着压回上限、关着不封
func _hit_cap() -> void:
	XTianqiBase.PHASE4 = true
	var s := _state()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var a: XActor = s.actor(XIAOYAO)
	a.change_level(99)
	a.param_mark_dirty()
	var b: XBattler = lg.enemies[0]
	var sk := XDB.rec("Skills", 3632)
	var slow := 1.3 if a.agi < b.agi else 1.0
	_check("cap.within", is_equal_approx(XTianqiSkills.formula(a, b, sk), a.atk * 3.6 * slow), [XTianqiSkills.formula(a, b, sk), a.atk])
	var row: Dictionary = XTianqiSkills.data().skills["3632"].damage
	var keep := float(row.coef)
	row.coef = 30.0
	_check("cap.clamped", is_equal_approx(XTianqiSkills.formula(a, b, sk), a.atk * 11.0), [XTianqiSkills.formula(a, b, sk), a.atk * 11.0])
	XTianqiBase.PHASE4 = false
	XTianqiSkills.CARDS = true  # 只开卡、总开关关：不封（本体回到职业曲线，敏捷变了，条件重判）
	a.param_mark_dirty()
	var slow2 := 1.3 if a.agi < b.agi else 1.0
	_check("cap.off_unclamped", is_equal_approx(XTianqiSkills.formula(a, b, sk), a.atk * 30.0 * slow2), [XTianqiSkills.formula(a, b, sk), a.atk, slow2])
	XTianqiSkills.CARDS = false
	row.coef = keep
	# 权重口径：寒锋（物攻 1.8＋敏捷 1.8）权重 3.6，和数据校验同口径
	_check("cap.weight", is_equal_approx(XTianqiSkills.hit_weight(XTianqiSkills.data().skills["3645"].damage), 3.6) and is_equal_approx(XTianqiSkills.hit_weight({"stats": {"atk": 1, "mhp": 0.007}}), 1.175))
