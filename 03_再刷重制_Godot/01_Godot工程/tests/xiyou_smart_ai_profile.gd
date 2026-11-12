extends Node
## 【cc·未经审查】智能 AI 里写在插件自己身上的五个角色（XSmartAIProfiles：黄泉 169、流萤 179、宿傩 172、渡鸦 167、米拉 168）：
## 与 mv_oracle/smart_ai_profile_probe.cjs 的冻结 v0.62.12 参照（tests/fixtures/smart_ai_profile_oracle.json，真实 BattleManager）逐步比。
## 每个 ai 步比：候选技能、能用的技能、各技能的档案、铺垫后的角色视图（能力值、能用的技能、估伤）、各伤害技能对各敌人的 safeDamage、
## 命中／闪避／暴击、choose 的选择与前 6 名候选分数。对照时三个开关都按原版（o_profile_hits、o_profile_chain、o_future_real 关）。
## 本地断言（local.*）：反例——别的角色没有这条档案、不吃估算与 boosts；神话形态中、领域中不再给铺垫档案；急需时神灶：开不压 0；
## 两个优化开关开关两态；choose 只读（不改状态、能力值、资源、随机数）。
const FIXTURE := "res://tests/fixtures/smart_ai_profile_oracle.json"
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


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 30:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _new_state() -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.set_switch(2494, true)
	s.party.clear()
	s.battle_slots.clear()
	return s


func _enter(s: XState, seed_text: String, sync_on_start := true) -> XBattleLogic:
	var rand := XBattleRandom.create(seed_text)
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	XSkillProgression.SYNC_ON_BATTLE_START = sync_on_start
	logic.setup(3, s, rand)
	XSkillProgression.SYNC_ON_BATTLE_START = true
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
	return logic


## 各角色的搭法同参照 BATTLES（照各自的战斗专项：xiyou_yomi_battle／xiyou_liuying2／xiyou_sukuna_battle／xiyou_raven_battle／xiyou_mira_battle）
func _battle(actor_id: int) -> Array:
	var s := _new_state()
	var a := s.actor(actor_id)
	var logic: XBattleLogic
	match actor_id:
		169:
			for id in [169, 1]:
				s.actor(id).change_level_mv(55)
			for id in [10171, 10172, 10173, 10174]:
				if not a.skill_ids.has(id):
					a.skill_ids.append(id)
			s.add_actor(169)
			s.add_actor(1)
			for id in [169, 1]:
				s.actor(id).add_param(0, BIG_HP)
				s.actor(id).refresh_passive()
			logic = _enter(s, "0000000000000169")
			a.tp = 0.0  # 参照不走 startBattle，没有开战 TP
		179:
			s.actor_advance[179] = 2
			a.change_level_mv(60)
			XLiuying.recruit(s)
			s.add_actor(1)
			s.actor(1).add_param(0, BIG_HP)
			for id in s.party:
				s.actor(id).refresh_passive()
			logic = _enter(s, "0000000000001792")
			XLiuying.start_battle(logic)
			logic.start_turn()
		172:
			s.actor_advance[172] = 2
			for id in [172, 1]:
				s.actor(id).change_level_mv(55)
			s.add_actor(172)
			s.add_actor(1)
			XSukuna.sync(a)
			for id in [172, 1]:
				s.actor(id).add_param(0, BIG_HP)
				s.actor(id).refresh_passive()
			logic = _enter(s, "0000000000000172")
			a.tp = 100.0
		167:
			s.actor_advance[167] = 5
			a.change_level_mv(60)
			check("setup.raven_recruit", XRaven.recruit(s))
			s.add_actor(1)
			for id in s.party:
				s.actor(id).add_param(0, BIG_HP)
				s.actor(id).refresh_passive()
			logic = _enter(s, "0000000000000167")
			a.tp = 0.0  # 参照不走 startBattle，没有开战 TP
			logic.start_turn()
		168:
			s.actor_advance[168] = 3
			for id in [168, 1]:
				s.actor(id).change_level_mv(70)
			XSkillProgression.sync(a)
			s.add_actor(168)
			s.add_actor(1)
			a.refresh_passive()
			logic = _enter(s, "0000000000000168", false)
			for b in logic.actors:
				b.warmups.clear()
			a.tp = a.max_tp()
		170:
			s.actor_advance[170] = 2
			a.change_level_mv(60)
			for id in [10200, 10201, 10202]:
				a.learn_skill(id)
			XYomiJingliu.recruit(s, XYomiJingliu.JINGLIU)
			s.gain_gear("weapon", 2, 1)
			XEquipment.change(s, a, 0, s.gear[s.gear.size() - 1])
			s.add_actor(1)
			for id in s.party:
				s.actor(id).add_param(0, BIG_HP)
				s.actor(id).refresh_passive()
			logic = _enter(s, "0000000000000170")
			XYomiJingliu._blood.clear()
			a.tp = 0.0  # 参照不走 startBattle，没有开战 TP
			logic.start_turn()
		173:
			s.actor_advance[173] = 4
			a.change_level_mv(60)
			check("setup.garou_recruit", XGarou.recruit(s))
			s.add_actor(1)
			for id in [173, 1]:
				s.actor(id).add_param(0, BIG_HP)
				s.actor(id).refresh_passive()
			logic = _enter(s, "0000000000000173")
			XGarou.sync(a)
			XGarou.clear_battle()
			a.tp = a.max_tp()
	return [logic, a]


func _target_index(logic: XBattleLogic, a: XActor, t, self_index: int) -> int:
	if t == null:
		return -1
	if t == a:
		return self_index
	var i := logic.enemies.find(t)
	return i if i >= 0 else logic.actors.find(t)


static func _near(got: float, want: float, rel := 1e-9) -> bool:
	return absf(got - want) <= maxf(1e-6, absf(want) * rel)


func _skills(a: XActor) -> Array:
	return a.skills().filter(func(s): return XSukuna.listed(a, s))


func _ids(a: XActor) -> Array:
	var ids := [int(a.attack_skill().id)]
	for s in _skills(a):
		if XSmartAI.scope_of(s) > 0 and not ids.has(int(s.id)):
			ids.append(int(s.id))
	ids.sort()
	return ids


func _plain_profile(a: XActor, rec: Dictionary) -> Dictionary:
	var out := {}
	var p := XSmartAI.profile(a, rec)
	for k in p:
		if k == "future":
			out.future = true
		elif p[k] is float or p[k] is int or p[k] is bool:
			out[k] = p[k]
	return out


func _same_dict(got: Dictionary, want: Dictionary) -> bool:
	if got.size() != want.size():
		return false
	for k in want:
		if not got.has(k):
			return false
		if want[k] is bool or got[k] is bool:
			if bool(got[k]) != bool(want[k]):
				return false
		elif not _near(float(got[k]), float(want[k])):
			return false
	return true


func _damage_rows(ai: XSmartAI, a: XActor, logic: XBattleLogic, ids: Array) -> Dictionary:
	var out := {}
	for id in ids:
		var rec := XDB.rec("Skills", int(id))
		if int(rec.get("damage", {}).get("type", 0)) in [1, 2, 5, 6]:
			out[int(id)] = logic.enemies.map(func(t): return ai.safe_damage(a, t, rec))
	return out


func _same_damage(got: Dictionary, want: Dictionary) -> bool:
	if got.size() != want.size():
		return false
	for id in got:
		var w = want.get(str(id))
		if not w is Array or w.size() != got[id].size():
			return false
		for k in w.size():
			if not _near(float(got[id][k]), float(w[k])):
				return false
	return true


func _ai(logic: XBattleLogic, a: XActor, want: Dictionary, name: String) -> void:
	var ids := _ids(a)
	check(name + ".ids", ids == want.ids.map(func(v): return int(v)), [ids, want.ids])
	var usable := ids.filter(func(id): return logic.can_use(a, XDB.rec("Skills", id)))
	check(name + ".usable", usable == want.usable.map(func(v): return int(v)), [usable, want.usable])
	var ws: Dictionary = want.self
	var me := [a.hp, a.mhp, a.mp, a.mmp, a.tp, a.atk, a.mat, a.def, a.mdf, a.agi, a.luk, float(a.passive_cache().get("globalHarmRi", 0.0))]
	var wme := [ws.hp, ws.mhp, ws.mp, ws.mmp, ws.tp, ws.atk, ws.mat, ws.def, ws.mdf, ws.agi, ws.luk, ws.harm]
	check(name + ".self", range(me.size()).all(func(i): return _near(float(me[i]), float(wme[i]))), [me, wme])  # 行动者的资源与能力值（代价倍率、估伤的输入）
	var foes_ok := true
	for k in logic.enemies.size():
		var e: XBattler = logic.enemies[k]
		var wf: Dictionary = want.foes[k]
		foes_ok = foes_ok and _near(e.hp, float(wf.hp)) and e.is_alive() == bool(wf.alive) and _near(e.atk + e.mat + e.agi * 0.3, float(wf.power)) \
			and _near(e.pdr, float(wf.pdr)) and _near(e.mdr, float(wf.mdr)) and _near(e.def, float(wf.def)) and _near(e.mdf, float(wf.mdf))
	check(name + ".foes", foes_ok, [logic.enemies.map(func(e): return [e.hp, e.def, e.mdf]), want.foes])
	var ai := XSmartAI.new(logic, a)
	ai.context = {"friends": logic.actors, "foes": logic.alive(logic.enemies), "urgent": false, "longFight": true, "damageScale": 0.0}
	for id in ids:
		var rec := XDB.rec("Skills", id)
		var got := _plain_profile(a, rec)
		var exp: Dictionary = want.profile.get(str(id), {})
		check(name + ".profile.%d" % id, _same_dict(got, exp), [got, exp])
		var p := XSmartAI.profile(a, rec)
		if p.has("future") and want.future.has(str(id)):
			var wf: Dictionary = want.future[str(id)]
			var saved := [a.hp, a.mp, a.tp]
			var token := XSmartAIProfiles.enter(a, str(p.future))
			ai._view = 99
			var params := [a.mhp, a.mmp, a.atk, a.def, a.mat, a.mdf, a.agi, a.luk]
			var f_usable: Array = _skills(a).filter(func(s): return XSmartAI.scope_of(s) > 0 and logic.can_use(a, s)).map(func(s): return int(s.id))
			f_usable.sort()
			var f_damage := _damage_rows(ai, a, logic, _skills(a).filter(func(s): return XSmartAI.scope_of(s) > 0).map(func(s): return int(s.id)))
			ai._view = 0
			XSmartAIProfiles.leave(token)
			check(name + ".future.%d.params" % id, range(8).all(func(i): return _near(params[i], float(wf.params[i]))), [params, wf.params])
			check(name + ".future.%d.usable" % id, f_usable == wf.usable.map(func(v): return int(v)), [f_usable, wf.usable])
			check(name + ".future.%d.damage" % id, _same_damage(f_damage, wf.damage), [f_damage, wf.damage])
			check(name + ".future.%d.restored" % id, [a.hp, a.mp, a.tp] == saved)
	var dmg := _damage_rows(ai, a, logic, ids)
	check(name + ".damage", _same_damage(dmg, want.damage), [dmg, want.damage])
	var rates_ok := true
	var rates := {}
	for id in dmg:
		var rec := XDB.rec("Skills", id)
		rates[id] = logic.enemies.map(func(t): return [logic.item_hit(a, rec, t), logic.item_eva(a, rec, t),
			logic.item_cri(a, rec, t) if bool(rec.damage.get("critical", false)) else 0.0])
		var w: Array = want.rates.get(str(id), [])
		rates_ok = rates_ok and w.size() == logic.enemies.size()
		for k in w.size():
			for j in 3:
				rates_ok = rates_ok and _near(float(rates[id][k][j]), float(w[k][j]), 1e-9)
	check(name + ".rates", rates_ok, [rates, want.rates])
	var r := XSmartAI.choose(logic, a)
	var wc = want.choice
	var got_choice := [int(r.skill.id) if r.has("skill") else 0, _target_index(logic, a, r.get("target"), int(want.selfIndex))]
	check(name + ".choice", wc != null and got_choice == [int(wc.id), int(wc.target)], [got_choice, wc])
	check(name + ".score", absf(float(r.get("score", 0.0)) - float(want.score)) <= maxf(1.0, absf(float(want.score)) * 1e-6), [r.get("score"), want.score])
	var cands: Array = r.get("candidates", [])
	var exp_c: Array = want.candidates
	var same := cands.size() == exp_c.size()
	for k in cands.size():
		if same:
			same = int(cands[k].id) == int(exp_c[k].id) and absf(float(cands[k].score) - float(exp_c[k].score)) <= maxf(1.0, absf(float(exp_c[k].score)) * 1e-6)
	check(name + ".candidates", same, [cands.map(func(x): return [x.id, x.score]), exp_c.map(func(x): return [x.id, x.score])])


func _apply(logic: XBattleLogic, a: XActor, st: Array) -> void:
	match str(st[0]):
		"act":
			var rec := XDB.rec("Skills", int(st[1]))
			logic.act(a, rec, logic.enemies[int(st[2])] if XSmartAI.for_opponent(rec) else a)
		"end":
			logic.end_turn()
		"foehp":
			for k in logic.enemies.size():
				var e: XBattler = logic.enemies[k]
				e.hp = float(st[1][k])
				if e.hp <= 0.0 and not e.is_dead():
					logic._state_add(e, XBattleLogic.DEATH_STATE)
		"allyrate":
			var b: XActor = XState.current.actor(1)
			b.hp = maxf(1.0, floorf(b.mhp * float(st[1])))
		"tp":
			a.tp = float(st[1])
		"mp":
			a.mp = float(st[1])
		"forget":
			a.forget_skill(int(st[1]))
		"weapon":
			a.equips[0] = XGear.template("weapon", int(st[1]))
			a.param_mark_dirty()
			a.refresh_passive()
		"dream":
			XYomiJingliu.set_dream(a, int(st[1]))


func _script(c: Dictionary) -> void:
	var r := _battle(int(c.setup.actor))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var steps: Array = c.observed.steps
	for i in steps.size():
		var st: Array = steps[i].step
		if str(st[0]) == "ai":
			_ai(logic, a, steps[i].snap, "%s.%d" % [c.id, i])
		else:
			_apply(logic, a, st)


func _fingerprint(logic: XBattleLogic) -> Array:
	var out := [logic.random.rule.draws, XSukuna.cast.size(), XRaven._store().get("myth", 0)]
	for b in logic.actors + logic.enemies:
		out.append([b.hp, b.mp, b.tp, b.state_ids.duplicate(), b.mhp, b.mmp, b.atk, b.def, b.mat, b.mdf, b.agi, b.luk])
	return out


## 本地断言：反例与开关两态
func _local() -> void:
	# 别的角色：没有这条档案；学了黄泉的技能也不吃估算（XYomiJingliu.formula 只认黄泉）、不吃 boosts 与暴击增量
	var r := _battle(169)
	var logic: XBattleLogic = r[0]
	var yomi: XActor = r[1]
	var hero: XActor = XState.current.actor(1)
	var ai := XSmartAI.new(logic, hero)
	var blade := XDB.rec("Skills", 10173)
	check("local.other.profile", XSmartAIProfiles.profile(hero, blade).is_empty() and XSmartAIProfiles.profile(hero, XDB.rec("Skills", 10231)).is_empty()
		and XSmartAIProfiles.profile(hero, XDB.rec("Skills", 10127)).is_empty() and XSmartAIProfiles.profile(hero, XDB.rec("Skills", 10146)).is_empty()
		and XSmartAIProfiles.profile(hero, XDB.rec("Skills", 10622)).is_empty())
	check("local.other.damage", ai.safe_damage(hero, logic.enemies[0], blade) == 0.0)
	# 镜流、饿狼的估算只认本人（j_formula／_garou_raw 对别人是 0）
	check("local.other.jingliu_garou", ai.safe_damage(hero, logic.enemies[0], XDB.rec("Skills", 10187)) == 0.0
		and ai.safe_damage(hero, logic.enemies[0], XDB.rec("Skills", 10255)) == 0.0)
	check("local.other.boosts", XSmartAIProfiles.boosts(hero, XDB.rec("Skills", 10140)) == 1.0 and XSmartAIProfiles.boosts(hero, XDB.rec("Skills", 10126)) == 1.0
		and XSmartAIProfiles.crit_bonus(hero, XDB.rec("Skills", 10126)) == 0.0 and XSmartAIProfiles.expected_rate(hero, XDB.rec("Skills", 10126)) == 1.0)
	check("local.yomi.item", XSmartAIProfiles.raw(yomi, logic.enemies[0], XDB.rec("Items", 1)) == null and XSmartAIProfiles.boosts(yomi, XDB.rec("Items", 1)) == 1.0)
	# O-316（o_profile_chain）：黄泉的档案只有溅射；开着时后面的档案（云裳天衣）接着问，关掉照原版到此为止
	var keep_chain := XSmartAIProfiles.o_profile_chain
	XSmartAIProfiles.o_profile_chain = true
	var on := XSmartAI.profile(yomi, blade)
	XSmartAIProfiles.o_profile_chain = false
	var off := XSmartAI.profile(yomi, blade)
	XSmartAIProfiles.o_profile_chain = keep_chain
	check("local.chain.splash", float(on.get("splash", 0.0)) == 0.5 and off == {"splash": 0.5}, [on, off])
	check("local.chain.plain", XSmartAI.profile(yomi, XDB.rec("Skills", 1)).get("splash", -1.0) == 0.0)
	# choose 只读：五个角色各在最常见的战况下选一次，前后指纹不变（含铺垫后的角色视图还原），两个开关两态都查
	var keep_real := XSmartAIProfiles.o_future_real
	for real in [false, true]:
		XSmartAIProfiles.o_future_real = real
		for id in [169, 179, 172, 167, 168]:
			var b := _battle(id)
			var before := _fingerprint(b[0])
			var pick := XSmartAI.choose(b[0], b[1])
			check("local.readonly.%d.%s" % [id, real], _fingerprint(b[0]) == before and pick.has("skill"), [before, _fingerprint(b[0])])
	# O-317（o_future_real）：米拉黑龙视图的能力值——关掉是原版的旧值（攻击比人形还低），开着是真黑龙（攻击、生命上限都涨）
	var m := _battle(168)
	var mira: XActor = m[1]
	var human := [mira.atk, mira.mhp]
	XSmartAIProfiles.o_future_real = false
	var t := XSmartAIProfiles.enter(mira, "mira")
	var stale := [mira.atk, mira.mhp]
	XSmartAIProfiles.leave(t)
	XSmartAIProfiles.o_future_real = true
	t = XSmartAIProfiles.enter(mira, "mira")
	var real_view := [mira.atk, mira.mhp]
	XSmartAIProfiles.leave(t)
	check("local.real.mira", stale[0] < human[0] and stale[1] == human[1] and real_view[0] > human[0] and real_view[1] > human[1]
		and [mira.atk, mira.mhp] == human and not mira.state_ids.has(XMira.DRAGON), [human, stale, real_view])
	# 同一开关：宿傩领域视图——关掉领域回合数不动（斩击不吃领域 ×1.3），开着领域生效；御厨子·斩击 10237 关掉估 0、开着按公式
	var k := _battle(172)
	var sukuna: XActor = k[1]
	var slash := XDB.rec("Skills", 10229)
	var kai := XSmartAI.new(k[0], sukuna)
	var foe: XBattler = k[0].enemies[0]
	var base := kai._safe_damage(sukuna, foe, slash)
	XSmartAIProfiles.o_future_real = false
	t = XSmartAIProfiles.enter(sukuna, "sukuna")
	var view_off := kai._safe_damage(sukuna, foe, slash)
	var ongoing_off := kai._safe_damage(sukuna, foe, XDB.rec("Skills", 10237))
	XSmartAIProfiles.leave(t)
	XSmartAIProfiles.o_future_real = true
	t = XSmartAIProfiles.enter(sukuna, "sukuna")
	var view_on := kai._safe_damage(sukuna, foe, slash)
	var ongoing_on := kai._safe_damage(sukuna, foe, XDB.rec("Skills", 10237))
	XSmartAIProfiles.leave(t)
	check("local.real.sukuna", base > 0.0 and _near(view_off, base) and _near(view_on, base * 1.3) and ongoing_off == 0.0 and ongoing_on > 0.0
		and int(XSukuna.temp(sukuna).domain) == 0 and not sukuna.state_ids.has(XSukuna.DOMAIN), [base, view_off, view_on, ongoing_off, ongoing_on])
	# 开着时伏魔御厨子的分数不低于关掉时（多算了领域加成与每回合的斩击）
	XSmartAIProfiles.o_future_real = false
	var s_off := float(XSmartAI.choose(k[0], sukuna).candidates.filter(func(x): return int(x.id) == 10231)[0].score)
	XSmartAIProfiles.o_future_real = true
	var s_on := float(XSmartAI.choose(k[0], sukuna).candidates.filter(func(x): return int(x.id) == 10231)[0].score)
	XSmartAIProfiles.o_future_real = keep_real
	check("local.real.sukuna_score", s_on > s_off and s_off > 0.0, [s_off, s_on])


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var keep := [XSmartAI.o_profile_hits, XSmartAIProfiles.o_profile_chain, XSmartAIProfiles.o_future_real, XYomiJingliu.CRIT_FIX]
	XYomiJingliu.CRIT_FIX = false  # O-098：原版黄泉 10185 的暴击 +9.99 不生效
	XSmartAI.o_profile_hits = false
	XSmartAIProfiles.o_profile_chain = false
	XSmartAIProfiles.o_future_real = false
	for c in ref.cases:
		if check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors):
			_script(c)
	XSmartAI.o_profile_hits = keep[0]
	XSmartAIProfiles.o_profile_chain = keep[1]
	XSmartAIProfiles.o_future_real = keep[2]
	XYomiJingliu.CRIT_FIX = keep[3]
	_local()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_smart_ai_profile", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
