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
					if gap[0] == 0.0 and w > 0.0:
						gap[0] = got[k].hp / w
					same = got[k].skill == int(e.skill) and got[k].user == str(e.user) and got[k].target == str(e.target) \
						and absf(got[k].hp / w - gap[0]) < 1e-6 and got[k].critical == bool(e.critical)
			check(name + ".hits", same, [got, exp])
		var snap: Dictionary = _norm(_snap(logic, a))
		var ws: Dictionary = _norm(want.snap)
		for k in ws:
			check(name + "." + k, snap[k] == ws[k], [snap[k], ws[k]])
	check(c.id + ".gap", absf(gap[0] - GAP) < 1e-4, gap[0])


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
			_script(c)
	check("covers_all", seen == 4, seen)
	_local()
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_toji_battle", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
