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
	func _take(kind: String, reason: String, _event_key: String):
		draws += 1
		if kind == "float" and reason == "black_flash" and not flash.is_empty():
			return float(flash.pop_front())
		return 0.5 if kind == "float" else 2147483648


## 同参照 battle()：新局、开 2494、队伍 [171, 1] 各 55 级；敌人生命加 1e18；规则流全取 0.5
func _battle(flash := []) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [171, 1]:
		s.actor(id).change_level_mv(55)
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
	var r := _battle(c.setup.get("draws", []))
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
			"foe":
				logs = logic.act(logic.enemies[int(st[1])], XDB.rec("Skills", int(st[2])), logic.actors[int(st[3])])
			"die":
				logic._state_add(a, XBattleLogic.DEATH_STATE)
			"revive":
				logic._state_remove(a, XBattleLogic.DEATH_STATE)
				a.hp = a.mhp
			"endBattle":
				logic.end_battle(0)
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
					same = got[k].skill == int(e.skill) and got[k].user == str(e.user) and got[k].target == str(e.target) \
						and hp_ok and got[k].critical == bool(e.critical)
			check(name + ".hits", same, [got, exp])
		var snap: Dictionary = _norm(_snap(logic, a))
		var ws: Dictionary = _norm(want.snap)
		for k in ws:
			check(name + "." + k, snap[k] == ws[k], [snap[k], ws[k]])
	check(c.id + ".gap", absf(gap[0] - GAP) < 1e-4, gap[0])


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
	check("local.end_clears", not XToji.SHAPES.any(func(id): return a.state_ids.has(id)) and XToji._logic == null)


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
	check("covers_all", seen == 7, seen)
	_local()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_toji_battle", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
