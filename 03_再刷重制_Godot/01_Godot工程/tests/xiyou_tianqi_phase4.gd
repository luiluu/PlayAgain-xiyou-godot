extends Node
## 【cc·T081】天启篇期四暗装接线（XTianqiBase.PHASE4，基础数值重构 v0.4 第七节第 2 条、第十节 T012-b）：
## 一、总开关默认关；关着每一行都是「关着」那一套（本体 NAN、K 1、U 1、守层者旧表、治疗照乘、绝对值原数、单段不封、九线爆伤不封、秘籍读旧键、面板没有天启注视）。
## 二、开着、天启篇存档：每一行都和总开关一致（rows_state），本体读标准线×职责×速度档，K＝表里的 0.088、进 dealt_parts，面板一行「天启注视　伤害 ×0.088」。
## 三、开着但是西游档：一律走关着那一套。
## 四、单段有效系数上限：开着时卡面系数×权重×条件超过档位上限压回上限，关着不封；全部卡在上限以内（数据校验同口径）。
## 五、角色卡跟着总开关开（CARDS 本身不动）。
## 六、端到端（核查 R2 P2-1，开、关各跑一遍）：双回复药走 _effect 生命、魔法各认自己那一行；持续伤害走 XExtDot.tick；
##     确认阶段治疗不乘 ×5（confirm_rows 的 skipTypes）；九线爆伤封顶走 apply_nine_cap；伤害详情 gaze 行；骑士 U 进 stats／shadow_stats；表外角色回落职业曲线。
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
	_e2e(true)
	_e2e(false)
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
	_check("off.abs", XTianqiBase.abs_value("item_fixed_heal", 1, 500.0, a, "mhp") == 500.0)
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
	var heal := XTianqiBase.abs_value("item_fixed_heal", 1, 500.0, a, "mhp")
	_check("on.abs_item", heal == floorf(float(a.mhp) * 7.2 / 100.0), [heal, a.mhp])
	_check("on.abs_dot_sign", XTianqiBase.abs_value("state_dot", 33, -300.0, a) == -floorf(float(a.mhp) * 4.3 / 100.0))
	_check("on.abs_unknown", XTianqiBase.abs_value("item_fixed_heal", 999999, 77.0, a, "mhp") == 77.0)
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
	_check("xiyou.abs", XTianqiBase.abs_value("item_fixed_heal", 1, 500.0, a, "mhp") == 500.0)
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


## 端到端：每一处结算点开、关各断一次（只改测试里的临时数据，结束复原）
func _e2e(on: bool) -> void:
	var tag := "e2e_on." if on else "e2e_off."
	XTianqiBase.PHASE4 = on
	XTianqiBase.clear_cache()
	var s := _state()
	var a: XActor = s.actor(XIAOYAO)
	a.change_level(81)
	a.param_mark_dirty()
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	# （1）双回复药 28：11 回生命认 mhp 那一行、12 回魔法认 mmp 那一行（原来按 id 建索引，mmp 覆盖 mhp）
	var item := XDB.rec("Items", 28)
	var e_hp := XTianqiBase.abs_entry("item_fixed_heal", 28, "mhp")
	var e_mp := XTianqiBase.abs_entry("item_fixed_heal", 28, "mmp")
	_check(tag + "abs_two_rows", not e_hp.is_empty() and not e_mp.is_empty() and float(e_hp.new.pct) != float(e_mp.new.pct), [e_hp, e_mp])
	var seen := {}
	for eff in item.get("effects", []):
		var code := int(eff.code)
		if not code in [11, 12] or float(eff.value2) == 0.0:
			continue
		a.hp = 1.0
		a.mp = 0.0
		var r := {"skill": item}
		lg._effect(a, a, eff, r)
		var got := -float(r.get("hp" if code == 11 else "mp", 0.0))
		var cap := float(a.mhp if code == 11 else a.mmp)
		var v2 := float(eff.value2)
		if on:
			v2 = floorf(cap * float((e_hp if code == 11 else e_mp).new.pct) / 100.0)
		var want := floorf((cap * float(eff.value1) + v2) * a.rec * a.pha)
		seen[code] = true
		_check(tag + "item28_code%d" % code, got == want, [got, want, cap, eff])
	_check(tag + "item28_both", seen.has(11) and seen.has(12), seen)
	# （2）持续伤害 33（常数 300）：开着扣持有者生命上限 4.3%（关波动、元素倍率 1）
	var st := XDB.rec("States", 33)
	var dot: Dictionary = st.get("dot", {})
	var keep_var = dot.get("variance")
	dot["variance"] = 0
	XExtDot.test_hooks = {"element_rate": func(_b, _e): return 1.0}
	a.hp = a.mhp
	a.add_state(33)
	var logs := []
	XExtDot.tick(lg, a, logs)
	var dmg := float(logs[0].hp) if not logs.is_empty() else -1.0
	var want_dot := floorf(float(a.mhp) * 4.3 / 100.0) if on else 300.0
	_check(tag + "ext_dot", dmg == want_dot, [dmg, want_dot, a.mhp, logs.size()])
	a.remove_state(33)
	XExtDot.test_hooks = {}
	if keep_var == null:
		dot.erase("variance")
	else:
		dot["variance"] = keep_var
	# （3）确认阶段：开着回复（3、4）也跳过 ×5
	var rows := XTianqiNoDiffPassive.confirm_rows(a, [])
	var skip_ok := not rows.is_empty()
	for row in rows:
		var sk: Array = row.effects[0].skipTypes
		skip_ok = skip_ok and (sk.has(3) and sk.has(4)) == on
	_check(tag + "confirm_heal_x5", skip_ok, rows)
	# （4）九线爆伤合计封顶：装备 0.5＋宝珠 0.2＝0.7，开着封到 0.3（扣 0.4），关着不封
	var by := {"SkETypeHarmRi": {}, "skillTypeDvup": {}, "skillPass": {}, "elementAmplify": {}, "passiveELUP": {}, "globalHarmRi": {},
		"critHarmRi": {"equip": 0.5, "orb": 0.2}, "books": {"globalHarmRi": {}, "critHarmRi": {}, "skillTypeDvup": {}, "SkETypeHarmRi": {}, "skillPass": {}, "elementAmplify": {}, "passiveELUP": {}}}
	var frame := {"normalAdd": 0.0, "finalAdd": 0.0, "criticalAdd": 0.7, "elementAdd": {}}
	var cut := XTianqiLedger.apply_nine_cap(XDB.rec("Skills", 1), a, frame, {"bySource": by}, {})
	var crit_cut := float(cut.get("crit", 0.0))
	_check(tag + "nine_crit_cap", is_equal_approx(crit_cut, 0.4) if on else crit_cut == 0.0, [cut, frame])
	_check(tag + "nine_crit_frame", is_equal_approx(float(frame.criticalAdd), 0.3 if on else 0.7), frame)
	# （5）伤害详情：开着带 gaze（K 本身），关着没有
	var res := XDamage.calculate(XDB.rec("Skills", 1), a, XEnemy.new().setup(1, 3, 100.0), {"critical": false, "variance": false})
	var g = res.breakdown.row.get("gaze")
	_check(tag + "damage_gaze", (g is Dictionary and is_equal_approx(float(g.k), 0.088) and str(g.name) == "天启注视") if on else g == null, g)
	# （6）骑士 U：表里先填 1，临时改成 crit 2／no_crit 3 看本体、影子血量跟着乘
	var cr: Dictionary = XTianqiBalance.data().combat_rules
	var keep_u = cr.get("boss_hp_temp_unit")
	var line := "plague"
	var key := "zhengdao"
	XTianqiBase.PHASE4 = false
	var hp0 := float(XTianqiHorsemen.stats(line, key).hp)
	var sh0 := float(XTianqiHorsemen.shadow_stats(line, key).hp)
	XTianqiBase.PHASE4 = on
	cr["boss_hp_temp_unit"] = {"crit": 2.0, "no_crit": 3.0}
	var u := 3.0 if bool(XTianqiHorsemen.knight(line).get("crit_immune", false)) else 2.0
	var hp1 := float(XTianqiHorsemen.stats(line, key).hp)
	var sh1 := float(XTianqiHorsemen.shadow_stats(line, key).hp)
	_check(tag + "knight_u", hp1 == (roundf(hp0 * u) if on else hp0) and sh1 == (roundf(sh0 * u) if on else sh0), [hp0, hp1, sh0, sh1, u])
	if keep_u == null:
		cr.erase("boss_hp_temp_unit")
	else:
		cr["boss_hp_temp_unit"] = keep_u
	# （7）表外角色：开着也回落职业曲线
	var out_id := 0
	for id in range(1, 400):
		if not XDB.rec("Actors", id).is_empty() and str(XDB.rec("Actors", id).get("name", "")) != "" and not XTianqiBase.has_actor(id):
			out_id = id
			break
	if out_id > 0:
		XTianqi._joining = true
		s.add_actor(out_id)
		XTianqi._joining = false
		var o: XActor = s.actor(out_id)
		o.change_level(50)
		_check(tag + "out_of_table", is_nan(XTianqiBase.param_base(o, 2)) and is_equal_approx(o.param_base_direct(2), float(o.class_data().params[2][o.level])), [out_id, o.param_base_direct(2)])
	else:
		_check(tag + "out_of_table_found", false, "表外角色没找到")
	XTianqiBase.PHASE4 = false
