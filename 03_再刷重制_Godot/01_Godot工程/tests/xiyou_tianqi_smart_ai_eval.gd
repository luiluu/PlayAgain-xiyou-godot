extends Node
## T282 天启篇智能 AI ② 统一预览引擎（XSmartAI.o_tianqi_preview_damage）＋敌我共用估值底座 XBattleEval 专项：
## 一、统一预览开着：重构伤害技、治疗技、五条悟茈估值非 0，选招不是平 A；开关关回卡 1 手抄乘区（值不同、仍非 0）；总开关关回 0。
## 二、元素牌组：弱点技估伤高于无属性、免疫技估 0，AI 打分同序；低战商 opts.check_weakness 关时不看元素。
## 三、烙印破防 ×1.3：敌方用 XBattleEval 估我方破防角色，伤害 ×1.3，打分更高（给 T277 集火用）。
## 四、零副作用：选招前后 HP／MP／TP／状态／护盾／账本／印记／烙印／随机流／全局 randf／总账违规表／_cur_skill 一致，总账守卫开关复原。
## 五、性能：4v5 满技能列表一次 choose 的耗时（打印 PERF 行，交付单抄），粗上限防退化。
## 六、敌方用法：XBattleEval.create_for(logic, enemy).score_skill 对我方出分、目标是我方角色。
## 七、西游档不进统一预览。
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
	seed(20261120)
	XTianqiSkills.reload_table()
	XGojo.unlock_override = 1
	_check("default_preview_on", XSmartAI.o_tianqi_preview_damage)
	_preview_values()
	_elements()
	_brand_break()
	_readonly()
	_enemy_side()
	_perf()
	_xiyou_untouched()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail).left(600))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 天启篇存档：group 进战斗栏（最多 4 个），学会各自全部重构技；敌人血加厚
func _setup(group: Array, troop := 2, difficulty := "lianyu", level := 60) -> Array:
	var s := XTianqi.start_new_game(3, difficulty, group.slice(0, 3))
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
	if group.has(XGojo.ACTOR):
		for id in XGojo.ADV:
			s.actor(XGojo.ACTOR).learn_skill(id)
	s.battle_slots = group.duplicate()
	while s.battle_slots.size() < 5:
		s.battle_slots.append(0)
	var rand := XBattleRandom.create("0000000000000282")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(troop, s, rand)
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


## 一、统一预览开着的估值；开关关回卡 1
func _preview_values() -> void:
	var logic: XBattleLogic = _setup([1, 100, 131])[1]
	var hero := _actor(logic, 1)
	var t: XBattler = logic.enemies[0]
	var rec := XDB.rec("Skills", 4749)
	_check("previewed_on", XSmartAI.previewed(rec))
	var on := XSmartAI.new(logic, hero).safe_damage(hero, t, rec)
	var exp_on := XSmartAI.new(logic, hero).expected_damage(hero, t, rec)
	_check("preview_damage_nonzero", on > 0.0, on)
	_check("preview_expected_nonzero", exp_on > 0.0, exp_on)
	# 每段值就是 XDamage.preview_hit（同正式乘区链）；段数另乘
	var ai := XSmartAI.new(logic, hero)
	var parts := ai._parts(hero, t, rec)
	var direct := XDamage.preview_hit(rec, hero, t, {"vars": logic.vars(), "rawValue": float(parts.raw), "battleRound": 1, "tianqi_logic": logic})
	_check("preview_is_preview_hit", is_equal_approx(on, direct * float(parts.repeats)), [on, direct, parts.repeats])
	var pick := XSmartAI.choose(logic, hero)
	_check("preview_pick_main", int(pick.skill.id) != int(hero.attack_skill().id), pick.get("skill", {}).get("id"))
	# 治疗：云霄对残血队友的治疗量非 0、急救选治疗技
	var yx := _actor(logic, 100)
	var hurt := _actor(logic, 131)
	hurt.hp = hurt.mhp * 0.2
	var heal := XSmartAI.new(logic, yx).healing_amount(hurt, XDB.rec("Skills", 5571), false, false)
	_check("preview_heal_nonzero", heal > 0.0, heal)
	var pick2 := XSmartAI.choose(logic, yx)
	_check("preview_heal_pick", int(pick2.skill.id) in [5567, 5571, 5572, 5574], pick2.get("skill", {}).get("id"))
	hurt.recover_all()
	# 开关：关统一预览 → 卡 1 手抄乘区（非 0、和预览值不同）；关总开关 → 0
	XSmartAI.o_tianqi_preview_damage = false
	_check("preview_off_not_previewed", not XSmartAI.previewed(rec))
	var off := XSmartAI.new(logic, hero).safe_damage(hero, t, rec)
	_check("preview_off_card1_nonzero", off > 0.0 and not is_equal_approx(off, on), [off, on])
	var pick_off := XSmartAI.choose(logic, hero)
	_check("preview_off_pick_main", int(pick_off.skill.id) != int(hero.attack_skill().id), pick_off.get("skill", {}).get("id"))
	XSmartAI.o_tianqi_preview_damage = true
	XSmartAI.o_tianqi_smart_ai = false
	_check("master_off_zero", XSmartAI.new(logic, hero).safe_damage(hero, t, rec) == 0.0 and not XSmartAI.previewed(rec))
	XSmartAI.o_tianqi_smart_ai = true
	# 五条悟茈：有印才有值；预览不写印记
	var lg: XBattleLogic = _setup([180, 1, 100])[1]
	var g := _actor(lg, XGojo.ACTOR)
	if g != null:
		var tmp := XGojo.temp(g)
		tmp.blue = 2
		tmp.red = 2
		var d := XSmartAI.new(lg, g).safe_damage(g, lg.enemies[0], XDB.rec("Skills", 10640))
		_check("preview_gojo_purple", d > 0.0 and int(tmp.blue) == 2 and int(tmp.red) == 2 and not XGojo.ai_preview, d)
		tmp.blue = 0
		tmp.red = 0
	else:
		_check("preview_gojo_in_battle", false)


## 元素号 ei（牌组里的）对应的数据库属性号
func _raw_element(ei: int) -> int:
	for e in range(1, 40):
		if XTianqiElements.map_element_id(e) == ei:
			return e
	return -1


func _with_element(rec: Dictionary, e: int) -> Dictionary:
	var r := rec.duplicate(true)
	r.damage.elementId = e
	return r


## 二、元素牌组：弱点 > 无属性 > 免疫(0)
func _elements() -> void:
	var found := false
	for troop in [2, 394, 853, 824, 10, 20, 30]:
		var logic: XBattleLogic = _setup([1, 100, 131], troop)[1]
		var hero := _actor(logic, 1)
		var rec := XDB.rec("Skills", 4749)
		for t in logic.enemies:
			var prof := XTianqiElements.enemy_profile(t, logic)
			if (prof.weak as Array).is_empty():
				continue
			var weak_e := _raw_element(int(prof.weak[0]))
			var neutral_e := -1
			for ei in XTianqiElements.BASE_ELEMENTS:
				if not (prof.weak as Array).has(ei) and not (prof.resist as Array).has(ei) and not (prof.immune as Array).has(ei):
					neutral_e = _raw_element(int(ei))
					break
			if weak_e <= 0 or neutral_e <= 0:
				continue
			found = true
			var w := _with_element(rec, weak_e)
			var n := _with_element(rec, neutral_e)
			var dw := XSmartAI.new(logic, hero).safe_damage(hero, t, w)
			var dn := XSmartAI.new(logic, hero).safe_damage(hero, t, n)
			_check("elem_weak_gt_neutral", dw > dn * 1.2 and dn > 0.0, [dw, dn, troop, prof])
			var ctx := {"friends": logic.actors, "foes": [t], "urgent": false, "longFight": true, "damageScale": 0.0, "noSetup": true}
			var sw := float(XSmartAI.new(logic, hero).score_candidate(w, false, ctx).score)
			var sn := float(XSmartAI.new(logic, hero).score_candidate(n, false, ctx).score)
			_check("elem_weak_scores_higher", sw > sn and sn > 0.0, [sw, sn])
			var kind := XBattleEval.create_for(logic, hero).element_kind(t, w)
			_check("elem_kind_weak", kind in ["weak", "converted_weak"], kind)
			# 低战商：不看元素时弱点和无属性一样
			var low := XBattleEval.create_for(logic, hero, {"check_weakness": false})
			var parts := XSmartAI.new(logic, hero)._parts(hero, t, w)
			var lw := low.hit_value(hero, t, w, float(parts.raw))
			var ln := XBattleEval.create_for(logic, hero, {"check_weakness": false}).hit_value(hero, t, n, float(parts.raw))
			_check("elem_low_iq_flat", is_equal_approx(lw, ln) and lw > 0.0, [lw, ln])
			if not (prof.immune as Array).is_empty():
				var im := _with_element(rec, _raw_element(int(prof.immune[0])))
				var di := XSmartAI.new(logic, hero).safe_damage(hero, t, im)
				_check("elem_immune_zero", di == 0.0, di)
				var si := float(XSmartAI.new(logic, hero).score_candidate(im, false, ctx).score)
				_check("elem_immune_score_zero", si < sn, [si, sn])
			if not (prof.resist as Array).is_empty():
				var rs := _with_element(rec, _raw_element(int(prof.resist[0])))
				var dr := XSmartAI.new(logic, hero).safe_damage(hero, t, rs)
				_check("elem_resist_lt_neutral", dr < dn and dr > 0.0, [dr, dn])
			break
		if found:
			break
	_check("elem_enemy_with_weakness_found", found)
	# 免疫没碰到时补一条：随手造一个只有免疫的牌（敌人的 meta 不改，只比 element_rate_for 的免疫口径）
	var rates: Dictionary = XTianqiElements.data().get("rates", {})
	_check("elem_immune_rate_zero", float(rates.get("immune", 0.0)) == 0.0, rates.get("immune"))


## 三、烙印破防：敌方估我方破防角色 ×1.3
func _brand_break() -> void:
	var logic: XBattleLogic = _setup([1, 100, 131], 2, "lianyu")[1]
	var c := XTianqiBrand.fight(logic)
	if c.is_empty():
		_check("brand_fight_on", false, "XTianqiBrand 这一场没开")
		return
	var e: XEnemy = logic.enemies[0]
	var victim := _actor(logic, 131)
	var atk := XDB.rec("Skills", e.attack_skill_id())
	var ev := XBattleEval.create_for(logic, e)
	var raw := maxf(ev.raw_value(e, victim, atk), 1e6)  # 杂兵普攻打 60 级角色只有个位数，取整吃掉比例：公式值抬到 1e6 量比例
	var before := ev.hit_value(e, victim, atk, raw)
	if not c.has("guard_break"):
		c["guard_break"] = {}
	c.guard_break[victim] = logic.turn + 1
	var ev2 := XBattleEval.create_for(logic, e)
	var after := ev2.hit_value(e, victim, atk, raw)
	_check("brand_break_x13", before > 0.0 and absf(after / before - 1.3) < 0.02, [before, after])
	var other := _actor(logic, 100)
	var hp_same := victim.hp
	other.hp = hp_same
	var s_victim := ev2.damage_utility(victim, ev2.expected_damage(e, victim, atk, raw))
	_check("brand_break_scores_higher", s_victim > 0.0 and after > before, [s_victim, before, after])
	c.guard_break.erase(victim)


## 四、零副作用（统一预览开着）
func _readonly() -> void:
	for group in [[180, 107, 94, 1], [168, 172, 167, 100], [176, 170, 173, 131]]:
		var r := _setup(group, 394)
		var logic: XBattleLogic = r[1]
		for g in logic.actors:
			if XGojo.own(g):
				XGojo.temp(g).blue = 2
				XGojo.temp(g).red = 2
				XGojo.temp(g).last = "red"
		XShieldLedger.active = true
		XShieldLedger.grant(logic.actors[1], "T282", 500.0, 3.0, 0, {"noBonus": true})
		var c := XTianqiBrand.fight(logic)
		if not c.is_empty():
			if not c.has("guard_break"):
				c["guard_break"] = {}
			c.guard_break[logic.actors[0]] = logic.turn + 1
		XTianqiSkills._cur_skill = 4242
		var violations := XTianqiLedger.violations.size()
		var before := _fingerprint(logic)
		seed(777)
		for a in logic.actors:
			XSmartAI.choose(logic, a)
		for e in logic.enemies:
			var ev := XBattleEval.create_for(logic, e)
			for act in e.data().get("actions", []):
				ev.score_skill(XDB.rec("Skills", int(act.skillId)), {"long_fight": true})
		var anchor := randf()
		seed(777)
		var tag := "%d" % int(group[0])
		_check("readonly_global_rng_" + tag, is_equal_approx(anchor, randf()), anchor)
		_check("readonly_fingerprint_" + tag, before == _fingerprint(logic), before.length())
		_check("readonly_ledger_violations_" + tag, XTianqiLedger.violations.size() == violations, [violations, XTianqiLedger.violations.size()])
		_check("readonly_ledger_guard_" + tag, XTianqiLedger.GUARD)
		_check("readonly_cur_skill_" + tag, XTianqiSkills._cur_skill == 4242, XTianqiSkills._cur_skill)
		XShieldLedger.active = false


func _battler_print(b: XBattler) -> Dictionary:
	var params := []
	for i in range(8):
		params.append(b.param(i))
	var meta := {}
	for k in b.get_meta_list():
		meta[str(k)] = str(b.get_meta(k))
	var out := {"hp": b.hp, "mp": b.mp, "tp": b.tp, "states": b.state_ids.duplicate(), "stateTurns": b.state_turns.duplicate(true),
		"stateData": b.state_data.duplicate(true), "stateOrigins": b.state_origins.duplicate(true), "buffs": b.buffs.duplicate(),
		"buffTurns": b.buff_turns.duplicate(), "guarding": b.guarding, "cooldowns": b.cooldowns.duplicate(true),
		"warmups": b.warmups.duplicate(true), "shield": b.shield, "ledger": XShieldLedger.rows(b), "absorbed": XShieldLedger.absorbed_total.get(b.get_instance_id(), 0.0),
		"params": params, "xparams": [b.hit, b.eva, b.cri, b.cev, b.mev, b.mrf, b.cnt, b.hrg, b.mrg, b.trg, b.tgr, b.grd, b.rec, b.pha, b.mcr], "meta": meta}
	if b is XActor:
		out.skills = (b as XActor).skill_ids.duplicate()
		if XGojo.own(b):
			out.gojo = XGojo.temp(b).duplicate(true)
	return out


## 全套指纹：双方战斗者全字段（含 meta）＋随机流快照＋变量／开关／物品＋五条悟施放状态＋烙印这一场的记录
func _fingerprint(logic: XBattleLogic) -> String:
	var st := logic.state
	var brand := {}
	var c := XTianqiBrand.fight(logic)
	for k in c:
		brand[str(k)] = str(c[k])
	return JSON.stringify({"actors": logic.actors.map(_battler_print), "enemies": logic.enemies.map(_battler_print), "turn": logic.turn,
		"random": logic.random.snapshot(), "draws": logic.random.rule.draws, "items": st.items, "variables": st.variables, "switches": st.switches,
		"cast": XGojo.cast.duplicate(true), "preview": XGojo.ai_preview, "brand": brand})


## 六、敌方用法
func _enemy_side() -> void:
	var logic: XBattleLogic = _setup([1, 100, 131], 394)[1]
	var scored := 0
	var bad_target := []
	for i in logic.enemies.size():
		var e: XEnemy = logic.enemies[i]
		var ev := XBattleEval.create_for(logic, e)
		_check("enemy_eval_foes_are_actors_%d" % i, ev.foes.all(func(f): return f is XActor) and ev.allies.has(e))
		for act in e.data().get("actions", []):
			var rec := XDB.rec("Skills", int(act.skillId))
			if rec.is_empty():
				continue
			var r := ev.score_skill(rec, {"long_fight": false})
			if float(r.score) > 0.0 and int(rec.get("damage", {}).get("type", 0)) in [1, 5]:
				scored += 1
				if r.target != null and not r.target is XActor:
					bad_target.append(int(rec.id))
	_check("enemy_scores_some", scored > 0, scored)
	_check("enemy_targets_actors", bad_target.is_empty(), bad_target)


## 五、性能：4v5、四人各学全部重构技
func _perf() -> void:
	var logic: XBattleLogic = _setup([1, 100, 131, 107], 394)[1]
	_check("perf_4v5", logic.actors.size() == 4 and logic.enemies.size() == 5, [logic.actors.size(), logic.enemies.size()])
	var counts := logic.actors.map(func(a): return a.skills().size())
	for mode in ["preview", "card1"]:
		XSmartAI.o_tianqi_preview_damage = mode == "preview"
		XSmartAI.choose(logic, logic.actors[0])  # 预热（表、正则、静态缓存）
		var worst := 0
		var total := 0
		XBattleEval.stat_calls = 0
		XBattleEval.stat_hits = 0
		for a in logic.actors:
			var t0 := Time.get_ticks_usec()
			XSmartAI.choose(logic, a)
			var dt := Time.get_ticks_usec() - t0
			total += dt
			worst = maxi(worst, dt)
		print("PERF mode=%s skills=%s avg_ms=%.1f worst_ms=%.1f chain_calls=%d cache_hits=%d" % [mode, str(counts), total / 4000.0, worst / 1000.0, XBattleEval.stat_calls, XBattleEval.stat_hits])
		_check("perf_%s_under_ceiling" % mode, worst < 3000000, worst)  # 粗上限 3 秒（防退化；电脑上实测见 PERF 行）
	XSmartAI.o_tianqi_preview_damage = true


## 七、西游档
func _xiyou_untouched() -> void:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	_check("xiyou_not_previewed", not XSmartAI.preview_on() and not XSmartAI.previewed(XDB.rec("Skills", 4749)))
