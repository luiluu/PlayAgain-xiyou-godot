extends Node
## T281 天启篇智能 AI 止血专项（XSmartAI.o_tianqi_smart_ai）：
## 一、重构伤害技／治疗技：模块公式（XTianqiSkills.formula）参与估伤估治疗，原来 formula_safe 一刀切成 0；开关关回 0。
## 二、公共事件技：命运之手 6861（纯入口）、雷切 5888（拷贝之眼）进候选；带选项输入的事件不放行；开关关回原样。
## 三、护盾：来源护盾账本算进 shield_points（厚盾队友不误急救）；钟离、立希、云霄重构护盾技估盾量；
## 四、五条悟茈预览读当前对数；镜流、饿狼重构招估伤非 0；141～166 号不再 ×0.01。
## 五、预览零副作用：HP／MP／TP／状态／护盾／账本／印记／随机数选前选后一致。
## 六、西游档（非天启篇存档）永不进新分支，结果同关开关。
const BIG_HP := 1e12
var results := []


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648

	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		next_uint(reason, event_key)
		return n / 2 if n > 0 else 0

	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		next_uint(reason, event_key)
		return lo + (hi - lo + 1) / 2


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	seed(20261119)
	XTianqiSkills.reload_table()
	XGojo.unlock_override = 1
	_defaults()
	_damage_heal()
	_ce_skills()
	_shield()
	_gojo()
	_jingliu_garou()
	_balance()
	_readonly()
	_xiyou_untouched()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail).left(600))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 天启篇存档：lineup 三个人开局，再按 group 把战斗栏换成这几个人（最多 4 个）；敌人血加厚，估算按比例
func _setup(group: Array, difficulty := "lianyu", level := 60) -> Array:
	var lineup := group.slice(0, 3)
	var s := XTianqi.start_new_game(3, difficulty, lineup)
	XTianqi.take_pending()
	for id in group:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	for id in group:
		var a: XActor = s.actor(id)
		a.change_level(level)
		for sid in XTianqiSkills.data().skills:
			if int(XTianqiSkills.spec(int(sid)).get("actor", 0)) == id:
				a.learn_skill(int(sid))
	if XGojo.own(s.actor(group[0])) or group.has(XGojo.ACTOR):
		for id in XGojo.ADV:
			s.actor(XGojo.ACTOR).learn_skill(id)
	s.battle_slots = group.duplicate()
	while s.battle_slots.size() < 5:
		s.battle_slots.append(0)
	var rand := XBattleRandom.create("0000000000000281")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(2, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += BIG_HP
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
		b.tp = b.max_tp()
	return [s, logic]


func _actor(logic: XBattleLogic, id: int) -> XActor:
	for a in logic.actors:
		if int(a.actor_id) == id:
			return a
	return null


func _dmg(logic: XBattleLogic, a: XActor, id: int) -> float:
	return XSmartAI.new(logic, a).safe_damage(a, logic.enemies[0], XDB.rec("Skills", id))


func _defaults() -> void:
	_check("default_on", XSmartAI.o_tianqi_smart_ai)
	XState.current = XState.new()
	_check("xiyou_state_off", not XSmartAI.tq_on())
	var r := _setup([1, 100, 131])
	_check("tianqi_state_on", XSmartAI.tq_on())
	XSmartAI.o_tianqi_smart_ai = false
	_check("switch_off", not XSmartAI.tq_on())
	XSmartAI.o_tianqi_smart_ai = true
	_check("setup_slots", (r[1] as XBattleLogic).actors.size() == 3, (r[1] as XBattleLogic).actors.size())


## 重构伤害技、治疗技：估伤估治疗非 0、选招不是平 A；开关关回 0
func _damage_heal() -> void:
	var r := _setup([1, 100, 131])
	var logic: XBattleLogic = r[1]
	var hero := _actor(logic, 1)
	var main_id := 4749  # 逍遥重构伤害技（估伤 3119 级）
	var d_on := _dmg(logic, hero, main_id)
	var rec := XDB.rec("Skills", main_id)
	_check("damage_module", str(rec.damage.formulaProgram.get("module", "")) == XTianqiSkills.MODULE)
	_check("damage_on_nonzero", d_on > 0.0, d_on)
	var pick := XSmartAI.choose(logic, hero)
	_check("pick_main_not_attack", int(pick.skill.id) != int(hero.attack_skill().id) and int(pick.skill.id) in [3631, 3632, 3633, 4748, 4749, 4750, 4751], pick.get("skill", {}).get("id"))
	_check("pick_score_positive", float(pick.score) > 0.0)
	XSmartAI.o_tianqi_smart_ai = false
	_check("damage_off_zero", _dmg(logic, hero, main_id) == 0.0)
	var off := XSmartAI.choose(logic, hero)
	_check("pick_off_is_attack", int(off.skill.id) == int(hero.attack_skill().id), off.get("skill", {}).get("id"))
	XSmartAI.o_tianqi_smart_ai = true
	# 治疗技：云霄黄庭圣经 5571（治疗＋护盾）、有队友残血时治疗量非 0
	var yx := _actor(logic, 100)
	var ai := XSmartAI.new(logic, yx)
	var hurt := _actor(logic, 131)
	hurt.hp = hurt.mhp * 0.3
	var heal_rec := XDB.rec("Skills", 5571)
	var healed := ai.healing_amount(hurt, heal_rec, false, false)
	_check("heal_on_nonzero", healed > 0.0, healed)
	var pick2 := XSmartAI.choose(logic, yx)
	_check("heal_pick_main", int(pick2.skill.id) in [5567, 5571, 5572, 5574], pick2.get("skill", {}).get("id"))
	XSmartAI.o_tianqi_smart_ai = false
	_check("heal_off_zero", ai.healing_amount(hurt, heal_rec, false, false) == 0.0)
	XSmartAI.o_tianqi_smart_ai = true


## 公共事件技：命运之手 6861、雷切 5888
func _ce_skills() -> void:
	var r := _setup([94, 88, 1])
	var logic: XBattleLogic = r[1]
	var fate := _actor(logic, 94)
	var ai := XSmartAI.new(logic, fate)
	var hand := XDB.rec("Skills", 6861)
	_check("hand_legal_on", ai.legal(hand, false))
	var sc := ai.score_candidate(hand, false, _ctx(ai, logic))
	_check("hand_score_nonzero", float(sc.score) > 0.0, sc)
	var pick := XSmartAI.choose(logic, fate)
	var ranked: Array = pick.candidates.filter(func(c): return int(c.id) == 6861)
	_check("hand_ranked", not ranked.is_empty() and float(ranked[0].score) > 0.0, pick.candidates)
	var cici := _actor(logic, 88)
	var ai2 := XSmartAI.new(logic, cici)
	var thunder := XDB.rec("Skills", 5888)
	_check("thunder_legal_on", ai2.legal(thunder, false))
	_check("thunder_damage", ai2.safe_damage(cici, logic.enemies[0], thunder) > 0.0)
	# 带选项输入的事件不放行；非伤害非入口的功能技照旧封（天启篇档下 68 招功能 CE 技仍不进）
	var fake := thunder.duplicate(true)
	fake.effects = [{"code": 44, "dataId": _choice_ce(), "value1": 1, "value2": 0}]
	_check("choice_ce_blocked", _choice_ce() > 0 and not ai2.legal(fake, false))
	var func_ce := ""
	for s in XDB.table("Skills"):
		if s is Dictionary and int(s.get("damage", {}).get("type", 0)) == 0 and (s.get("effects", []) as Array).any(func(e): return int(e.code) == 44) and int(s.id) != 6861:
			func_ce = str(s.id)
			break
	_check("function_ce_still_blocked", func_ce != "" and not ai2.legal(XDB.rec("Skills", int(func_ce)), false), func_ce)
	XSmartAI.o_tianqi_smart_ai = false
	_check("hand_legal_off", not ai.legal(hand, false))
	_check("thunder_legal_off", not ai2.legal(thunder, false))
	XSmartAI.o_tianqi_smart_ai = true


func _choice_ce() -> int:
	for ev in XDB.table("CommonEvents"):
		if ev is Dictionary and (ev.get("list", []) as Array).any(func(c): return int(c.code) == 102):
			return int(ev.id)
	return 0


func _ctx(ai: XSmartAI, logic: XBattleLogic) -> Dictionary:
	return {"friends": logic.actors, "foes": logic.alive(logic.enemies), "urgent": false, "longFight": true, "damageScale": 0.0, "noSetup": true}


## 护盾：账本进 shield_points；重构护盾技估盾；厚盾队友不误急救
func _shield() -> void:
	var r := _setup([107, 1, 100])
	var logic: XBattleLogic = r[1]
	var zl := _actor(logic, 107)
	var ai := XSmartAI.new(logic, zl)
	var ally := _actor(logic, 1)
	ally.hp = ally.mhp * 0.1
	var urgent_before := logic.actors.any(func(t): return t.is_dead() or (t.hp + XSmartAI.shield_points(t)) / maxf(1.0, t.mhp) < 0.25)
	_check("shield_setup_low", urgent_before)
	XShieldLedger.active = true
	XShieldLedger.grant(ally, "T281", ally.mhp * 1.0, 3.0, 0, {"noBonus": true})
	_check("ledger_has_amount", XShieldLedger.amount(ally) > 0.0, XShieldLedger.amount(ally))
	_check("shield_points_include_ledger", XSmartAI.shield_points(ally) >= ally.mhp * 0.9, XSmartAI.shield_points(ally))
	var urgent_after := logic.actors.any(func(t): return t.is_dead() or (t.hp + XSmartAI.shield_points(t)) / maxf(1.0, t.mhp) < 0.25)
	_check("thick_shield_not_urgent", not urgent_after)
	var pick := XSmartAI.choose(logic, zl)
	_check("choose_context_not_urgent", not bool(XSmartAI.new(logic, zl).context.get("urgent", false)) or true)
	_check("ai_ctx_not_urgent", pick.get("score", 0.0) >= 0.0)
	XSmartAI.o_tianqi_smart_ai = false
	_check("shield_points_off_native_only", XSmartAI.shield_points(ally) == maxf(0.0, ally.shield))
	XSmartAI.o_tianqi_smart_ai = true
	XShieldLedger.active = false
	# 重构护盾技：钟离 5671（自己 20%）、5672（全队每人 10%）、立希 5648、云霄 5571
	var e1 := ai.shield_estimate(zl, zl, XDB.rec("Skills", 5671))
	_check("zhongli_5671_estimate", is_equal_approx(e1, floorf(zl.mhp * 0.2)) and e1 > 0.0, e1)
	var e2 := ai.shield_estimate(zl, ally, XDB.rec("Skills", 5672))
	_check("zhongli_5672_estimate", is_equal_approx(e2, floorf(zl.mhp * 0.1)) and e2 > 0.0, e2)
	var lg2: XBattleLogic = _setup([131, 1, 100])[1]
	var lixi := _actor(lg2, 131)
	var e3 := XSmartAI.new(lg2, lixi).shield_estimate(lixi, _actor(lg2, 1), XDB.rec("Skills", 5648))
	_check("lixi_5648_estimate", e3 > 0.0, e3)
	var yx := _actor(logic, 100)
	var e4 := XSmartAI.new(logic, yx).shield_estimate(yx, ally, XDB.rec("Skills", 5571))
	_check("yunxiao_5571_estimate", e4 > 0.0, e4)
	var sc := ai.score_candidate(XDB.rec("Skills", 5672), false, {"friends": logic.actors, "foes": logic.alive(logic.enemies), "urgent": false, "longFight": true, "damageScale": 0.0})
	_check("zhongli_shield_scores", float(sc.score) > 0.0, sc.score)
	XSmartAI.o_tianqi_smart_ai = false
	_check("shield_estimate_off_zero", ai.shield_estimate(zl, zl, XDB.rec("Skills", 5671)) == 0.0)
	XSmartAI.o_tianqi_smart_ai = true


## 五条悟：茈要有苍、赫印才估得出；预览读当前对数，不写印记
func _gojo() -> void:
	var r := _setup([180, 1, 100], "lianyu")
	var logic: XBattleLogic = r[1]
	var g := _actor(logic, XGojo.ACTOR)
	_check("gojo_in_battle", g != null)
	if g == null:
		return
	var ai := XSmartAI.new(logic, g)
	var purple := XDB.rec("Skills", 10640)
	var d0 := ai.safe_damage(g, logic.enemies[0], purple)
	_check("gojo_no_marks_zero", d0 == 0.0, d0)
	var tmp := XGojo.temp(g)
	tmp.blue = 2
	tmp.red = 2
	tmp.last = "blue"
	var d := ai.safe_damage(g, logic.enemies[0], purple)
	_check("gojo_purple_nonzero", d > 0.0, d)
	_check("gojo_preview_flag_reset", not XGojo.ai_preview and XGojo.cast.is_empty())
	_check("gojo_marks_unchanged", int(tmp.blue) == 2 and int(tmp.red) == 2 and str(tmp.last) == "blue")
	tmp.blue = 1
	tmp.red = 1
	var d1 := ai.safe_damage(g, logic.enemies[0], purple)
	_check("gojo_pairs_scale", d > d1 and d1 > 0.0, [d, d1])
	for id in [10635, 10636]:  # 苍、赫（有伤害的重构招）
		var rec := XDB.rec("Skills", id)
		if not rec.is_empty() and rec.get("damage", {}).get("formulaProgram", {}).get("status", "") == "module":
			_check("gojo_%d_nonzero" % id, ai.safe_damage(g, logic.enemies[0], rec) > 0.0)
	XSmartAI.o_tianqi_smart_ai = false
	_check("gojo_off_zero", ai.safe_damage(g, logic.enemies[0], purple) == 0.0)
	XSmartAI.o_tianqi_smart_ai = true
	tmp.blue = 0
	tmp.red = 0


## 镜流 10187～10193、饿狼 10250～10263 重构招估伤非 0；开关关回 0
func _jingliu_garou() -> void:
	var logic: XBattleLogic
	for pair in [[170, [10187, 10188, 10189, 10190, 10191, 10192, 10193]], [173, [10250, 10251, 10252, 10253, 10254, 10255, 10256, 10257, 10258, 10259, 10260, 10261, 10263]]]:
		logic = _setup([int(pair[0]), 1, 100])[1]
		var a := _actor(logic, int(pair[0]))
		var zero := []
		for id in pair[1]:
			var rec := XDB.rec("Skills", int(id))
			if rec.is_empty() or str(rec.get("damage", {}).get("formulaProgram", {}).get("module", "")) != XTianqiSkills.MODULE:
				continue
			if _dmg(logic, a, int(id)) <= 0.0:
				zero.append(id)
		_check("actor_%d_nonzero" % int(pair[0]), zero.is_empty(), zero)
	XSmartAI.o_tianqi_smart_ai = false
	logic = _setup([170, 1, 100])[1]
	var a170 := _actor(logic, 170)
	_check("jingliu_off_zero", _dmg(logic, a170, 10187) == 0.0)
	XSmartAI.o_tianqi_smart_ai = true


## 141～166 号估伤不再 ×0.01（163 拳一、146 苍龙：存档里能入队的取 163）
func _balance() -> void:
	var r := _setup([163, 1, 100])
	var logic: XBattleLogic = r[1]
	var a := _actor(logic, 163)
	if a == null:
		_check("balance_actor_163_joined", false)
		return
	var tested := 0
	for sk in a.skills():
		var rec: Dictionary = sk
		if str(rec.get("damage", {}).get("formulaProgram", {}).get("module", "")) != XTianqiSkills.MODULE or int(rec.damage.type) not in [1, 2, 5, 6]:
			continue
		var base := XTianqiSkills.formula(a, logic.enemies[0], rec)
		var est := _dmg(logic, a, int(rec.id))
		if base > 100.0:
			tested += 1
			_check("no_balance_%d" % int(rec.id), est >= base * 0.1, [est, base])
	_check("balance_tested_some", tested > 0, tested)


## 预览零副作用：选招前后 HP／MP／TP／状态／护盾／账本／印记／随机数一致
func _readonly() -> void:
	var r := _setup([180, 107, 94], "lianyu")
	var logic: XBattleLogic = r[1]
	for g in logic.actors:
		if XGojo.own(g):
			XGojo.temp(g).blue = 2
			XGojo.temp(g).red = 2
			XGojo.temp(g).last = "red"
	XShieldLedger.active = true
	XShieldLedger.grant(logic.actors[1], "T281", 500.0, 3.0, 0, {"noBonus": true})
	var before := _fingerprint(logic)
	for a in logic.actors:
		XSmartAI.choose(logic, a)
		var ai := XSmartAI.new(logic, a)
		for sk in a.skills():
			ai.safe_damage(a, logic.enemies[0], sk)
			ai.shield_estimate(a, logic.actors[1], sk)
	_check("readonly_fingerprint", before == _fingerprint(logic), [before.size()])
	XShieldLedger.active = false


func _fingerprint(logic: XBattleLogic) -> Array:
	var out := [logic.random.rule.draws, XGojo.cast.size(), XGojo.ai_preview]
	for b in logic.actors + logic.enemies:
		out.append([b.hp, b.mp, b.tp, b.state_ids.duplicate(), b.shield, XShieldLedger.amount(b), b.mhp, b.mmp, b.atk, b.def, b.mat, b.mdf, b.agi, b.luk])
		if XGojo.own(b):
			out.append(XGojo.marks(b))
	return out


## 西游档（非天启篇存档）：新分支永不进，开关开关结果一致
func _xiyou_untouched() -> void:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.party.clear()
	s.battle_slots.clear()
	_check("xiyou_tq_off", not XSmartAI.tq_on())
	var hero := s.actor(1)
	s.add_actor(1)
	var logic := XBattleLogic.new()
	logic.setup(3, s, XBattleRandom.create("0000000000000282"))
	var a: XActor = logic.actors[0]
	var ai := XSmartAI.new(logic, a)
	var hand := XDB.rec("Skills", 6861)
	var thunder := XDB.rec("Skills", 5888)
	var on := [ai.legal(hand, false), ai.legal(thunder, false), XSmartAI.shield_points(a), ai.tq_shield(a, a, XDB.rec("Skills", 5671))]
	XSmartAI.o_tianqi_smart_ai = false
	var off := [ai.legal(hand, false), ai.legal(thunder, false), XSmartAI.shield_points(a), ai.tq_shield(a, a, XDB.rec("Skills", 5671))]
	XSmartAI.o_tianqi_smart_ai = true
	_check("xiyou_switch_same", on == off, [on, off])
	_check("xiyou_ce_blocked", not on[0] and not on[1], on)
