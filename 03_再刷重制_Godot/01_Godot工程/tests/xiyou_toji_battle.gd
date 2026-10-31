extends Node
## 甚尔 171 战斗内机制（XToji 第二期：形态与切换、复活回游云、战斗中技能列表、切换豁免类别封印、多段与追加次数、
## 万里锁溅射、天逆鉾封印、黑闪觉醒游云额外一击）：与 mv_oracle/toji_battle_probe.cjs 的冻结 v0.28 参照
## （generated/oracle/toji_battle.json）逐步比。每步比命中（技能、出手者、目标、生命伤害、暴击）与快照。
## 生命伤害比参照的比值：55 级专属角色重制恒为原版的 0.96079 倍（五乘区差，Kyo 10-27 定不移植，同宿傩），每例取第一段的比值，
## 其余各段（多段、第 2 段起 ×0.8、溅射、觉醒 ×1.2）都要与它相同。另有本地断言：反向——别的角色不吃甚尔的包装、
## 开战前没学切换不设形态、没打中不溅射不封印。
const ORACLE := "oracle/toji_battle.json"
const SKILLS := [10212, 10213, 10214, 10215, 10216, 10217, 10218, 10219]
const GAP := 0.96079
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail).left(800))
	return ok


func _ready() -> void:
	_run.call_deferred()


class HalfStream extends XRandomStream:
	var flash: Array = []  # 黑闪判定（reason black_flash）依次取，用完回 0.5，同参照 B.random
	var toji: Array = []  # 'rng' 步给的随机数：只给甚尔武器库的三次掷（reason toji_*），同参照
	func _take(kind: String, reason: String, _event_key: String):
		draws += 1
		if kind == "float" and reason == "black_flash" and not flash.is_empty():
			return float(flash.pop_front())
		if kind == "float" and reason.begins_with("toji_") and not toji.is_empty():
			return float(toji.pop_front())
		return 0.5 if kind == "float" else 2147483648


## 同参照 battle()：新局、开 2494、队伍 [171, 1] 各 55 级；敌人生命加 1e18；规则流全取 0.5
func _battle(flash := [], rank := 0) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [171, 1]:
		s.actor(id).change_level_mv(55)
	if rank > 0:
		s.actor_advance[171] = rank
		XToji.repair(s.actor(171))
	s.add_actor(171)
	s.add_actor(1)
	for id in [171, 1]:
		s.actor(id).refresh_passive()
	s.actor(1).add_param(0, 1e18)  # 敌人行动只打 1 号（夹在 99999999）
	var rand := XBattleRandom.create("0000000000000171")
	rand.rule = HalfStream.new()
	rand.rule.flash = flash.duplicate()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e18
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	s.actor(171).tp = 100.0
	return [logic, s.actor(171)]


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _snap(logic: XBattleLogic, a: XActor) -> Dictionary:
	var f := XBlackFlash.status(a)
	return {"shapes": XToji.SHAPES.filter(func(id): return a.state_ids.has(id)), "attack": a.attack_skill_id(), "alive": a.is_alive(),
		"meets": SKILLS.map(func(id): return logic.can_use(a, XDB.rec("Skills", id))),
		"listed": logic.battle_skills(a).map(func(s): return int(s.id)).filter(func(id): return SKILLS.has(id)),
		"awake": a.state_ids.has(XBlackFlash.STATE),
		"flash": {"focus": int(f.focus), "chain": int(f.chain), "awake": bool(f.awake)},
		"foes": logic.enemies.map(func(t): return {"seal": t.state_ids.has(XToji.SEAL), "charges": XToji.seal_count(t)})}


static func _norm(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[k] = _norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	return v


func _hits(logic: XBattleLogic, logs: Array) -> Array:
	var out := []
	for l in logs:
		if l.get("type") != "hit" or bool(l.missed) or bool(l.evaded) or not int(l.skill.get("damage", {}).get("type", 0)) in [1, 3, 5]:
			continue
		out.append({"skill": int(l.skill.id), "user": _key(logic, l.user), "target": _key(logic, l.target), "hp": float(l.hp), "critical": bool(l.critical)})
	return out


func _script(c: Dictionary) -> void:
	var r := _battle(c.setup.get("draws", []), int(c.setup.get("rank", 0)))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var steps: Array = c.observed.steps
	var gap := [0.0]
	for i in steps.size():
		var want: Dictionary = steps[i]
		var st: Array = want.step
		var name := "%s.%d.%s" % [c.id, i, str(st[0])]
		var logs := []
		match str(st[0]):
			"start":
				pass
			"act":
				logs = logic.act(a, XDB.rec("Skills", int(st[1])), logic.enemies[int(st[2])] if int(st[1]) >= 10216 else a)
			"end":
				logs = logic.end_turn()
			"state":
				logic._state_add(a, int(st[1]))
			"unstate":
				logic._state_remove(a, int(st[1]))
			"rng":
				logic.random.rule.toji = (st[1] as Array).duplicate()
			"foe":
				logs = logic.act(logic.enemies[int(st[1])], XDB.rec("Skills", int(st[2])), logic.actors[int(st[3])])
			"die":
				logic._state_add(a, XBattleLogic.DEATH_STATE)
			"revive":
				logic._state_remove(a, XBattleLogic.DEATH_STATE)
				a.hp = a.mhp
			"endBattle":
				logic.end_battle(0)
			"forget":
				a.forget_skill(int(st[1]))
			"foehp":
				for k in logic.enemies.size():
					logic.enemies[k].hp = float(st[1][k])
			"foestate":  # 同参照 addState 后 refresh
				var e: XBattler = logic.enemies[int(st[1])]
				logic._state_add(e, int(st[2]))
				e.param_mark_dirty()
				e.param_refresh()
			"ai":
				_ai(logic, a, want.ai, name)
		if want.has("hits"):
			var got := _hits(logic, logs)
			var exp: Array = want.hits
			var same := got.size() == exp.size()
			for k in got.size():
				if same:
					var e: Dictionary = exp[k]
					var w := float(e.hp)
					if gap[0] == 0.0 and w > 0.0 and str(e.user) == "a171":
						gap[0] = got[k].hp / w
					var hp_ok: bool = absf(got[k].hp - w) <= 1.0 if str(e.user) != "a171" else absf(got[k].hp / w - gap[0]) < 1e-6  # 敌人打我方照原值比
					if int(e.skill) == XToji.REFLECT:
						hp_ok = absf(got[k].hp - w * GAP) <= 1.0  # 反弹基数来自敌人那下（个位数），比值受取整影响：按固定比值换算后差 1 以内
					same = got[k].skill == int(e.skill) and got[k].user == str(e.user) and got[k].target == str(e.target) \
						and hp_ok and got[k].critical == bool(e.critical)
			check(name + ".hits", same, [got, exp])
		var snap: Dictionary = _norm(_snap(logic, a))
		var ws: Dictionary = _norm(want.snap)
		for k in ws:
			check(name + "." + k, snap[k] == ws[k], [snap[k], ws[k]])
	if not str(c.id).begins_with("script.ai") or gap[0] != 0.0:  # 智能 AI 段只有切换、没有甚尔的伤害行
		check(c.id + ".gap", absf(gap[0] - GAP) < 1e-4, gap[0])


func _target_index(logic: XBattleLogic, t) -> int:
	if t == null:
		return -1
	var i := logic.enemies.find(t)
	return i if i >= 0 else logic.actors.find(t)


## 智能 AI 档案（第四期，参照 aiSnap）：各技能 profile（参照只记数值项）、主技能对各敌人的 safeDamage、choose 的选择与前 6 名候选。
## 参照是原版：档案段数再乘 numRepeats（O-待定 o_profile_hits 关）
func _ai(logic: XBattleLogic, a: XActor, want: Dictionary, name: String) -> void:
	var keep := XSmartAI.o_profile_hits
	XSmartAI.o_profile_hits = false
	check(name + ".extra", a.attack_times_add() == float(want.extra), [a.attack_times_add(), want.extra])
	var power: Array = logic.enemies.map(func(t): return snappedf(t.atk + t.mat + t.agi * 0.3, 1e-6))
	check(name + ".power", power == want.power.map(func(v): return snappedf(float(v), 1e-6)), [power, want.power])  # 威胁度读的能力
	var ai := XSmartAI.new(logic, a)
	for id in SKILLS:
		var rec := XDB.rec("Skills", id)
		var got := XSmartAI.profile(a, rec)
		got.erase("extra")
		var exp: Dictionary = want.profile[str(id)]
		var same := got.size() == exp.size()
		for k in exp:
			same = same and got.has(k) and absf(float(got[k]) - float(exp[k])) <= 1e-9 * maxf(1.0, absf(float(exp[k])))
		check(name + ".profile.%d" % id, same, [got, exp])
		if id >= 10216:
			var dmg := []
			for t in logic.enemies:
				dmg.append(ai.safe_damage(a, t, rec))
			var ok := true
			for k in dmg.size():
				ok = ok and absf(dmg[k] - float(want.damage[str(id)][k])) <= maxf(1.0, absf(float(want.damage[str(id)][k])) * 1e-9)
			check(name + ".damage.%d" % id, ok, [dmg, want.damage[str(id)]])
	var r := XSmartAI.choose(logic, a)
	var wc = want.choice
	check(name + ".choice", wc != null and r.has("skill") and int(r.skill.id) == int(wc.id) and _target_index(logic, r.target) == int(wc.target),
		[int(r.skill.id) if r.has("skill") else null, _target_index(logic, r.get("target")), wc])
	var cands: Array = r.get("candidates", [])
	var exp_c: Array = want.candidates
	var same := cands.size() == exp_c.size()
	for k in cands.size():
		if same:
			same = int(cands[k].id) == int(exp_c[k].id) and absf(float(cands[k].score) - float(exp_c[k].score)) <= maxf(1.0, absf(float(exp_c[k].score)) * 1e-4)
	check(name + ".candidates", same, [cands.map(func(x): return [x.id, x.score]), exp_c.map(func(x): return [x.id, x.score])])
	XSmartAI.o_profile_hits = keep


## 命中／闪避／暴击（参照 rates）：忘暴君、e0 加暴击闪避＋60%，再依次忘五感、天与咒缚
func _rates(c: Dictionary) -> void:
	var r := _battle()
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var e: XEnemy = logic.enemies[0]
	a.forget_skill(XToji.TYRANT)
	a.refresh_passive()
	logic._state_add(e, int(c.setup.foeState))
	var rows: Array = c.observed.rows
	var i := 0
	for tag in ["base", "noSenses", "noBond"]:
		if tag == "noSenses":
			a.forget_skill(XToji.SENSES)
		elif tag == "noBond":
			a.forget_skill(XToji.NO_MP)
		a.refresh_passive()
		for sid in [10216, 10220, 10224, 3]:
			_rate_row(logic, a, e, sid, rows[i])
			i += 1
		_rate_row(logic, e, a, 3, rows[i])
		i += 1
	check("rates.covers", i == rows.size(), [i, rows.size()])
	logic.end_battle(0)


func _rate_row(logic: XBattleLogic, u: XBattler, t: XBattler, sid: int, want: Dictionary) -> void:
	var sk := XDB.rec("Skills", sid)
	var cri := clampf(u.cri * (1.0 - t.cev * XToji.cev_rate(u, sk)), 0.0, 1.0) if bool(sk.damage.critical) else 0.0  # 同 _apply 的暴击率
	var got := [logic.item_hit(u, sk, t), logic.item_eva(u, sk, t), cri]
	var exp := [float(want.hit), float(want.eva), float(want.cri)]
	check("rates.%s.%s.%d" % [want.tag, want.user, sid], range(3).all(func(k): return absf(got[k] - exp[k]) < 1e-9), [got, exp])


## 暴君（参照 tyrant）：挡负面状态与弱化；忘掉后照常加；学回时清负面状态。弱化：原版清到一半抛错留着（CLEAR_DEBUFFS＝false 照原版），
## 重制默认清掉（O-待定）
func _tyrant(c: Dictionary) -> void:
	var r := _battle()
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var ids: Array = c.setup.states
	var has := func(): return ids.filter(func(id): return a.state_ids.has(int(id))).map(func(id): return int(id))
	var add := func():
		for id in ids:
			logic._state_add(a, int(id))
		for p in c.setup.debuffs:
			logic.sequence_buff(a, int(p), true, false, 3)
	var o: Dictionary = c.observed
	add.call()
	check("tyrant.with", has.call() == _norm(o.withTyrant.states) and _norm(a.buffs) == _norm(o.withTyrant.buffs), [has.call(), a.buffs])
	a.forget_skill(XToji.TYRANT)
	add.call()
	check("tyrant.without", has.call() == _norm(o.without.states) and _norm(a.buffs) == _norm(o.without.buffs), [has.call(), a.buffs])
	XToji.CLEAR_DEBUFFS = false
	a.learn_skill(XToji.TYRANT)
	XToji.CLEAR_DEBUFFS = true
	check("tyrant.relearned_original", has.call() == _norm(o.relearned.states) and _norm(a.buffs) == _norm(o.relearned.buffs) and bool(o.relearned.learned) and a.skill_ids.has(XToji.TYRANT), [has.call(), a.buffs])
	a.learn_skill(XToji.TYRANT)
	check("tyrant.relearned_cleared", not a.buffs.any(func(v): return v < 0), a.buffs)
	logic.end_battle(0)


func _local() -> void:
	# 反向：1 号主角普攻不收单目标、不溅射、不封印，甚尔的行动帧不动
	var r := _battle()
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var hero: XActor = logic.state.actor(1)
	logic.act(a, XDB.rec("Skills", 10215), a)
	var logs := logic.act(hero, XDB.rec("Skills", 1), logic.enemies[0])
	check("local.other_actor", _hits(logic, logs).size() >= 1 and _hits(logic, logs).all(func(h): return h.user == "a1" and h.target == "e0")
		and not logic.enemies[0].state_ids.has(XToji.SEAL) and XToji.action.is_empty(), _hits(logic, logs))
	# 反向：没学天逆鉾切换时切换技能不能用、不换形态
	a.forget_skill(10215)
	check("local.unlearned_switch", not logic.can_use(a, XDB.rec("Skills", 10215)) and not XToji.set_shape(logic, a, 3))
	logic.end_battle(0)
	check("local.end_clears", not XToji.SHAPES.any(func(id): return a.state_ids.has(id)) and not XToji.battling)


## 智能 AI 档案的本地断言：O-待定 o_profile_hits 开（默认）时追加＋1 的游云估伤是关时的一半（关时多乘 numRepeats 2）；
## 藏兵咒灵倍率 ×1.11；别的角色、甚尔的非主技能与当前形态的切换没有档案；档案只读（不换形态、不动随机数）
func _local_ai() -> void:
	var r := _battle()
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var yun := XDB.rec("Skills", 10216)
	logic._state_add(a, 1541)
	var ai := XSmartAI.new(logic, a)
	var keep := XSmartAI.o_profile_hits
	XSmartAI.o_profile_hits = true
	var on := ai.safe_damage(a, logic.enemies[0], yun)
	XSmartAI.o_profile_hits = false
	var off := ai.safe_damage(a, logic.enemies[0], yun)
	XSmartAI.o_profile_hits = keep
	check("local_ai.profile_hits", on > 0.0 and absf(off / on - 2.0) < 1e-9, [on, off])
	var plain := float(XSmartAI.profile(a, yun).multiplier)
	var slot := a.equip_slots().find(int(XDB.rec("Armors", XToji.ARMOR).get("etypeId", 0)))
	logic.state.gain_gear("armor", XToji.ARMOR, 1)  # 同 recruit：生成一件装进它的槽
	a.equips[slot] = logic.state.gear.pop_back()
	a.refresh_passive()
	check("local_ai.weapon", XToji.weapon(a) and absf(XSmartAI.profile(a, yun).multiplier / plain - 1.11) < 1e-9, [plain, XSmartAI.profile(a, yun)])
	var hero: XActor = logic.state.actor(1)
	check("local_ai.other_actor", XSmartAI.profile(hero, yun).is_empty() and XSmartAI.profile(hero, XDB.rec("Skills", 10213)).is_empty()
		and ai.safe_damage(hero, logic.enemies[0], yun) == 0.0)
	check("local_ai.no_profile", XSmartAI.profile(a, XDB.rec("Skills", 10212)).is_empty() and XSmartAI.profile(a, XDB.rec("Skills", 10220)).is_empty()
		and XSmartAI.profile(a, XDB.rec("Skills", 1)).is_empty())
	var draws := logic.random.rule.draws
	XSmartAI.choose(logic, a)
	check("local_ai.readonly", logic.random.rule.draws == draws and XToji.current_shape(a) == 0 and not XToji.SHAPES.any(func(id): return a.state_ids.has(id))
		and XToji.action.is_empty(), [logic.random.rule.draws, draws, XToji.action])
	logic.end_battle(0)


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := 0
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if c.errors.is_empty():
			seen += 1
			if c.id == "rates":
				_rates(c)
			elif c.id == "tyrant":
				_tyrant(c)
			else:
				_script(c)
	check("covers_all", seen == 11, seen)
	_local()
	_local_ai()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_toji_battle", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
