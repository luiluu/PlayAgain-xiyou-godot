extends Node
## T296 战斗提速②：公式帧（XAlienBattle.push／pop_formula、XHubris.push／pop_formula）进出只在「改得了能力值读法」时
## 作废只读窗口（O-348），开关 XAlienBattle.FRAME_TOUCH_LAZY。
## 一、作废时机：双方都没逆骨／空壳／饕餮时 calculate、eval_formula 进出不换代（窗口里记的值留着）；行动者或目标带其一就换代；
##    栈顶从「改得了」换到「改不了」（嵌套）也换代；影子克隆按本体算；狂妄只在物理公式且穿着时换代；开关关掉每次换代。
## 二、读数对：窗口里逆骨的物防（目标、物理帧读 0）、物攻（行动者、逆骨技能帧读物防），嵌套帧进出时都等于即时重算。
## 三、XEquipment.change 在只读窗口里调：换装后当场换代，release_unequippable 读到新特性表（T293 核查带来）。
## 四、整场同种子：西游档（无词条、逆骨、空壳、饕餮各一场）与天启篇 4 人，开关开／关逐位一致；全程 READ_VERIFY（窗口命中都重算比对）无不一致。
var results := []


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	seed(20261120)
	_check("defaults_on", XAlienBattle.FRAME_TOUCH_LAZY)
	XActor.READ_VERIFY = true  # 窗口命中都重算比对，不一致记进 read_mismatches（环境变量 XIYOU_READ_VERIFY=1 时还当场崩）
	XActor.read_mismatches.clear()
	_gen_plain()
	_gen_affix()
	_reads_nested()
	_clone_and_kinds()
	_hubris()
	_equip_change_in_window()
	_whole_battles()
	_check("read_verify_clean", XActor.read_mismatches.is_empty(), XActor.read_mismatches.slice(0, 5))
	XAlienBattle.FRAME_TOUCH_LAZY = true
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail).left(600))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 夹具 ----

## 西游档：角色 1（99 级，穿本体 1044 的异化武器，affix 为空时不带标记）＋角色 8，敌群 2（生命加 1e12），开战锁队
func _xiyou(affix: String, rand_seed := "0000000000000296") -> XBattleLogic:
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	s.random_master = XRandomStream.hex64(20261120)
	XState.current = s
	var a := s.actor(1)
	var b := s.actor(8)
	a.change_level_mv(99)
	b.change_level_mv(30)
	s.party.clear()
	s.battle_slots.clear()
	s.add_actor(1)
	s.add_actor(8)
	if affix != "":
		XAlienation.force_roll = 0.5
		XGear.force_roll = 0.5
		a.equips[0] = XAlienation.create(s, "w", 1044, "boss", affix).ok
		XGear.force_roll = -1.0
		XAlienation.force_roll = -1.0
	else:
		a.equips[0] = XGear.template("weapon", 1044)
	a.refresh_passive()
	a.recover_all()
	b.recover_all()
	var logic := XBattleLogic.new()
	logic.setup(2, s, XBattleRandom.create(rand_seed))
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	return logic


func _tianqi(rand_seed := "0000000000000296") -> XBattleLogic:
	var group := [1, 100, 131, 107]
	var s := XTianqi.start_new_game(3, "lianyu", group.slice(0, 3))
	XTianqi.take_pending()
	for id in group:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in group:
		var a: XActor = s.actor(id)
		a.change_level(60)
		for sid in XTianqiSkills.data().skills:
			if int(XTianqiSkills.spec(int(sid)).get("actor", 0)) == id:
				a.learn_skill(int(sid))
		a.refresh_passive()
	s.battle_slots = group.duplicate()
	while s.battle_slots.size() < 5:
		s.battle_slots.append(0)
	var logic := XBattleLogic.new()
	logic.setup(394, s, XBattleRandom.create(rand_seed))
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	return logic


func _phys_skill(a: XActor) -> Dictionary:
	for s in a.skills():
		if int(s.get("hitType", 0)) == 1 and int(s.get("damage", {}).get("type", 0)) == 1:
			return s
	for id in range(2, 3000):  # 技能 1（攻击）在这套数据里是必中（hitType 2），另找一个物理伤害技
		var r := XDB.rec("Skills", id)
		if not r.is_empty() and int(r.get("hitType", 0)) == 1 and int(r.get("damage", {}).get("type", 0)) == 1:
			return r
	return {}


func _magic_skill(a: XActor) -> Dictionary:
	for s in a.skills():
		if int(s.get("hitType", 0)) == 2 and int(s.get("damage", {}).get("type", 0)) == 1:
			return s
	return {}


func _actor(logic: XBattleLogic, id: int) -> XActor:
	for x in logic.actors:
		if int(x.actor_id) == id:
			return x
	return null


# ---- 一、作废时机 ----

## 做 f 前后只读窗口有没有换代（窗口外层由这里开）
func _bumps(f: Callable) -> bool:
	XActor.read_begin()
	var g := XActor._read_gen
	f.call()
	var out := XActor._read_gen != g
	XActor.read_end()
	return out


func _gen_plain() -> void:
	var logic := _xiyou("")
	var a := _actor(logic, 1)
	var b := _actor(logic, 8)
	var e: XEnemy = logic.enemies[0]
	var sk := _phys_skill(a)
	var V: Array = logic.vars()
	_check("plain_frame_reads_false", not XAlienBattle._frame_reads(a, e) and not XAlienBattle._frame_reads(b, e) and not XAlienBattle._frame_reads(e, a))
	_check("plain_calc_no_bump", not _bumps(func(): XDamage.calculate(sk, a, e, {"vars": V, "rawValue": 1000.0})))
	_check("plain_eval_no_bump", not _bumps(func(): XDamage.eval_formula(sk, a, e, V)))
	_check("plain_enemy_calc_no_bump", not _bumps(func(): XDamage.calculate(e.attack_skill(), e, a, {"vars": V, "rawValue": 1000.0})))
	# 窗口里记的值留着：先读物攻，calculate 之后再读是同一代的记忆
	XActor.read_begin()
	var v := a.param(2)
	XDamage.calculate(sk, a, e, {"vars": V, "rawValue": 1000.0})
	var key := ("pa1:" if a._cat_bare else "pa0:") + "2"
	_check("plain_memo_survives", a._read_memo().has(key) and a.param(2) == v and v == a._param_now(2), [v, a._param_now(2)])
	XActor.read_end()
	XAlienBattle.FRAME_TOUCH_LAZY = false
	_check("off_calc_bumps", _bumps(func(): XDamage.calculate(sk, a, e, {"vars": V, "rawValue": 1000.0})))
	_check("off_eval_bumps", _bumps(func(): XDamage.eval_formula(sk, a, e, V)))
	XAlienBattle.FRAME_TOUCH_LAZY = true
	_check("frames_empty_plain", XAlienBattle._formula_frames.is_empty())
	logic.end_battle(0)


func _gen_affix() -> void:
	for affix in ["inversebone", "hollow", "glutton"]:
		var logic := _xiyou(affix)
		var a := _actor(logic, 1)
		var b := _actor(logic, 8)
		var e: XEnemy = logic.enemies[0]
		var V: Array = logic.vars()
		var locked = XAlienBattle.locked(a)
		_check(affix + ".locked", locked != null and str(locked.affix) == affix, locked)
		var sk := _phys_skill(b)
		_check(affix + ".subject_bumps", _bumps(func(): XDamage.calculate(_phys_skill(a), a, e, {"vars": V, "rawValue": 1000.0})))
		_check(affix + ".target_bumps", _bumps(func(): XDamage.calculate(e.attack_skill(), e, a, {"vars": V, "rawValue": 1000.0})))
		_check(affix + ".other_no_bump", not _bumps(func(): XDamage.calculate(sk, b, e, {"vars": V, "rawValue": 1000.0})))
		# 嵌套：外层帧改得了（行动者 1），里层改不了（8 打敌人）：进出里层都要换代（栈顶换了）
		XActor.read_begin()
		XAlienBattle.push_formula(sk, a, e, false)
		var g := XActor._read_gen
		XAlienBattle.push_formula(sk, b, e, true)
		var g2 := XActor._read_gen
		XAlienBattle.pop_formula()
		var g3 := XActor._read_gen
		XAlienBattle.pop_formula()
		XActor.read_end()
		_check(affix + ".nested_push_bumps", g2 != g)
		_check(affix + ".nested_pop_bumps", g3 != g2)
		logic.end_battle(0)
	_check("frames_empty_affix", XAlienBattle._formula_frames.is_empty())


# ---- 二、读数对 ----

func _reads_nested() -> void:
	var logic := _xiyou("inversebone")
	var a := _actor(logic, 1)
	var b := _actor(logic, 8)
	var e: XEnemy = logic.enemies[0]
	var phys := _phys_skill(b)
	var tmpl_ids: Array = XAlienation.templates().get("inversebone", [])
	var tmpl: Dictionary = {}
	for id in tmpl_ids:
		var r := XDB.rec("Skills", int(id))
		if not r.is_empty():
			tmpl = r
			break
	_check("inv_template_found", not tmpl.is_empty(), tmpl_ids.slice(0, 5))
	XActor.read_begin()
	var def0 := a.param(3)
	var atk0 := a.param(2)
	# 目标逆骨＋物理公式帧：物防读 0；弹出读回原值
	XAlienBattle.push_formula(phys, e, a, true)
	var def_in := a.param(3)
	XAlienBattle.pop_formula()
	var def_out := a.param(3)
	_check("inv_target_def0", def_in == 0.0 and def0 > 0.0 and def_out == def0, [def0, def_in, def_out])
	# 行动者逆骨＋逆骨技能：物攻改读物防（param_before_alien(3)）；里层换成别人打敌人（改不了）时物攻读回原值；弹出里层又读物防
	XAlienBattle.push_formula(tmpl, a, e, false)
	var atk_outer := a.param(2)
	XAlienBattle.push_formula(phys, b, e, true)
	var atk_inner := a.param(2)
	var fresh_inner := a._param_now(2)
	XAlienBattle.pop_formula()
	var atk_back := a.param(2)
	var fresh_back := a._param_now(2)
	XAlienBattle.pop_formula()
	var atk_end := a.param(2)
	XActor.read_end()
	_check("inv_subject_atk_reads_def", atk_outer == a.param_before_alien(3) and atk_outer != atk0, [atk0, atk_outer, a.param_before_alien(3)])
	_check("inv_nested_inner_fresh", atk_inner == fresh_inner and atk_inner == atk0, [atk_inner, fresh_inner, atk0])
	_check("inv_nested_back_fresh", atk_back == fresh_back and atk_back == atk_outer, [atk_back, fresh_back, atk_outer])
	_check("inv_end_atk", atk_end == atk0, [atk_end, atk0])
	logic.end_battle(0)


func _clone_and_kinds() -> void:
	var logic := _xiyou("hollow")
	var a := _actor(logic, 1)
	var c := XFormulaContext.clone_battler(a)
	var e: XEnemy = logic.enemies[0]
	_check("clone_reads", XAlienBattle._frame_reads(c, e) and XAlienBattle._frame_reads(e, c), XAlienation.for_actor(c))
	# 克隆身上卸掉异化武器（不在锁队表里），按 actor_id 仍认本体冻结的词条
	(c as XActor).equips[0] = XGear.template("weapon", 1044)
	_check("clone_stripped_reads_by_id", XAlienBattle._frame_reads(c, e))
	_check("hollow_other_false", not XAlienBattle._frame_reads(_actor(logic, 8), e))
	logic.end_battle(0)
	var lg := _xiyou("silence")
	_check("silence_not_frame", not XAlienBattle._frame_reads(_actor(lg, 1), lg.enemies[0]))  # 缄默不看公式帧
	lg.end_battle(0)


func _hubris() -> void:
	var logic := _xiyou("")
	var b := _actor(logic, 8)
	var a := _actor(logic, 1)
	var e: XEnemy = logic.enemies[0]
	var armor := XGear.create("armor", XHubris.ARMOR, logic.state)
	var slot := b.equip_slots().find(int(armor.get("etypeId", 0)))
	_check("hubris_slot", slot >= 0, armor.get("etypeId"))
	b.keep_unequippable = true
	b.equips[slot] = armor
	b.refresh_passive()
	var phys := _phys_skill(b)
	_check("hubris_wearing", not XHubris.gear(b).is_empty() and XHubris._pierce(phys, b) > 0.0, [armor.get("base"), armor.get("id"), armor.get("etypeId"), slot, b.equip_slots(), b.equips[slot] == null, XHubris.gear(b).get("base"), phys.get("hitType"), phys.get("damage", {}).get("type")])
	var hp := func(item, u, t):
		XHubris.push_formula(item, u, t)
		XHubris.pop_formula()
	_check("hubris_phys_bumps", _bumps(hp.bind(phys, b, e)))
	_check("hubris_none_no_bump", not _bumps(hp.bind(phys, a, e)))
	var mag := _magic_skill(b)
	if not mag.is_empty():
		_check("hubris_magic_no_bump", not _bumps(hp.bind(mag, b, e)))
	XAlienBattle.FRAME_TOUCH_LAZY = false
	_check("hubris_off_bumps", _bumps(hp.bind(phys, a, e)))
	XAlienBattle.FRAME_TOUCH_LAZY = true
	# 只进不出也换代（进帧那一下）
	XActor.read_begin()
	var g0 := XActor._read_gen
	XHubris.push_formula(phys, b, e)
	var push_bumped := XActor._read_gen != g0
	XHubris.pop_formula()
	XActor.read_end()
	_check("hubris_push_bumps", push_bumped)
	# 读数：穿透帧里目标物防打折，弹出读回（目标用角色：敌人能力值不进窗口记忆，角色的才进）
	XActor.read_begin()
	var d0 := a.param(3)
	XHubris.push_formula(phys, b, a)
	var d1 := a.param(3)
	var f1 := a._param_now(3)
	XHubris.pop_formula()
	var d2 := a.param(3)
	XActor.read_end()
	_check("hubris_reads", d1 < d0 and d1 == f1 and d2 == d0, [d0, d1, f1, d2])
	logic.end_battle(0)


# ---- 三、XEquipment.change 在窗口里 ----

func _equip_change_in_window() -> void:
	var logic := _xiyou("")
	var s: XState = logic.state
	var a := _actor(logic, 1)
	var before: Array = a._all_traits_now()
	var w := {}
	for wid in range(1, 400):  # 找一把能穿、特性表和现在不同的武器
		var t := XGear.create("weapon", wid, s)
		if t.is_empty() or not XEquipment.fits(a, 0, t) or (t.get("traits", []) as Array).is_empty():
			continue
		w = t
		break
	_check("eqc_weapon_found", not w.is_empty())
	s.register_gear(w)
	s.gear.append(w)
	var n0 := XActor.read_mismatches.size()
	XActor.read_begin()
	a.all_traits()  # 先热特性表
	a.skills()
	var ok := XEquipment.change(s, a, 0, w)
	var tr_after: Array = a.all_traits()
	XActor.read_end()
	_check("eqc_changed", ok and is_same(a.equips[0], w))
	_check("eqc_traits_fresh", tr_after == a._all_traits_now() and tr_after != before)
	_check("eqc_no_mismatch", XActor.read_mismatches.size() == n0, XActor.read_mismatches.slice(n0, n0 + 3))
	logic.end_battle(0)


# ---- 四、整场同种子 ----

func _fp(logic: XBattleLogic) -> Array:
	var rows := []
	for b in logic.actors + logic.enemies:
		rows.append([var_to_str(b.hp), var_to_str(b.mp), var_to_str(b.tp), b.state_ids.duplicate(), var_to_str(b.shield) if "shield" in b else ""])
	return [logic.turn, rows, logic.random.snapshot()]


func _plain(v):
	if v is Object:
		if v is XActor:
			return "A%d" % int(v.actor_id)
		if v is XEnemy:
			return "E%d" % int(v.enemy_id)
		return "obj"
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(_plain(k))] = _plain(v[k])
		return out
	if v is Array:
		return (v as Array).map(_plain)
	if v is float:
		return var_to_str(v)
	return v


func _play(make: Callable, turns: int) -> String:
	seed(20261120)
	var logic: XBattleLogic = make.call()
	var out := []
	for t in turns:
		if logic.is_over():
			break
		out.append([_plain(logic.run_turn({})), _fp(logic)])
	out.append(["over", logic.is_over(), logic.turn])
	logic.end_battle(0)
	return JSON.stringify(out)


func _whole_battles() -> void:
	var cases := {"xiyou_plain": func(): return _xiyou(""), "xiyou_inversebone": func(): return _xiyou("inversebone"),
		"xiyou_hollow": func(): return _xiyou("hollow"), "xiyou_glutton": func(): return _xiyou("glutton"), "tianqi": func(): return _tianqi()}
	for k in cases:
		XAlienBattle.FRAME_TOUCH_LAZY = true
		var on := _play(cases[k], 5)
		XAlienBattle.FRAME_TOUCH_LAZY = false
		var off := _play(cases[k], 5)
		XAlienBattle.FRAME_TOUCH_LAZY = true
		_check(k + ".ran", on.length() > 500, on.length())
		_check(k + ".on_eq_off", on == off, [on.sha256_text(), off.sha256_text(), _diff_at(on, off)])
		print("T296 %s fingerprint %s (%d B)" % [k, on.sha256_text().left(12), on.length()])
	_check("frames_empty_end", XAlienBattle._formula_frames.is_empty() and XHubris._frame_target == null)


func _diff_at(x: String, y: String) -> String:
	for i in mini(x.length(), y.length()):
		if x[i] != y[i]:
			return "@%d: %s | %s" % [i, x.substr(maxi(0, i - 80), 160), y.substr(maxi(0, i - 80), 160)]
	return "len %d vs %d" % [x.length(), y.length()]
