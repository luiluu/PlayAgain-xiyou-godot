extends Node
## 【cc·白龙·未经审查】沙僧二审 S2-1-03：云裳 Game_Action.apply 包装（modules.json 第 31 个）包在黄泉（9）、甚尔（10）、宿傩（18）外层。
## 与 mv_oracle/yunshang_wraps_probe.cjs 的冻结 v0.28 参照（tests/fixtures/yunshang_wraps_oracle.json）逐步比：
## 云裳先种针，唤醒（或清醒）穿天衣的专属角色，专属角色对敌人 1 放专属技能两次；比每段扣血（出手者、技能、目标、暴击、绝对值）、各敌人剩余针数、是否觉醒。
## 覆盖：觉醒中主行动只引爆一次（黄泉溅射、重复两次都只一根）；宿傩追斩 10236（S.perform 子行动）、甚尔万里锁溅射（子行动）各自再引爆自己目标一根；没醒不引爆。

const FIXTURE := "res://tests/fixtures/yunshang_wraps_oracle.json"
const DAMAGE_TOLERANCE := 1.0  # 伤害是整数，两边各自取整
const ROBE := 9
var results := []


## 规则流全取 0.5；整数照 Math.randomInt 取中点（同 xiyou_yunshang）
class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648
	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return floori(n * value) if n > 0 else 0
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return lo + floori((hi - lo + 1) * value)


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 20:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


## 同参照 battle()：云裳 45 级进阶 1 第一位、x 55 级第二位穿天衣 9；开 2494；敌人生命加 1e18；开战再开第一回合
func _battle(x: int, learn: Array) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.actor_advance[XYunshang.ACTOR] = 1
	s.actor(XYunshang.ACTOR).change_level_mv(45)
	s.party.clear()
	s.battle_slots.clear()
	for id in [XYunshang.ACTOR, x, 1, 8, 9]:
		s.add_actor(id)
	var b := s.actor(x)
	b.change_level_mv(55)
	for id in learn:
		b.learn_skill(int(id))
	if x == XSukuna.ACTOR:
		XSukuna.sync(b)
	s.gain_gear("armor", XYunshang.ROBE_FIRST + ROBE, 1)
	XEquipment.change(s, b, b.equip_slots().find(4), s.gear[s.gear.size() - 1])
	var rand := XBattleRandom.create("0000000000000174")
	rand.rule = FixedStream.new()
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
	for m in logic.actors:
		m.param_mark_dirty()
		m.param_refresh()
		m.recover_all()
	logic.start_turn()
	logic.next_subject()
	return [logic, s.actor(XYunshang.ACTOR), b]


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _needles(logic: XBattleLogic) -> Array:
	return logic.enemies.map(func(e): return (XYunshang.needles.get(e, []) as Array).size())


func _cast(logic: XBattleLogic, u, id: int, idx: int) -> Dictionary:
	u.mp = u.mmp
	u.tp = u.max_tp()
	u.cooldowns.clear()
	var logs := logic.act(u, XDB.rec("Skills", id), logic.enemies[idx])
	var hits := []
	for l in logs:
		var derived: bool = l.get("type") == "yunshang_derived"
		if (l.get("type") == "hit" and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)) and int(l.skill.get("damage", {}).get("type", 0)) > 0) or derived:
			hits.append({"user": _key(logic, l.user), "skill": int(l.skill.id), "target": _key(logic, l.target), "value": float(l.hp), "critical": bool(l.critical)})
	return {"log": hits}


func _case(c: Dictionary) -> void:
	var o: Dictionary = c.setup
	XYomiJingliu.CRIT_FIX = false  # 原版 10185 暴击＋9.99 不生效（O-098）：比原版时关掉（同 xiyou_yomi_battle）
	var r := _battle(int(o.actor), o.learn)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var b: XActor = r[2]
	var steps := []
	var snap := func(x: Dictionary) -> void:
		x.needles = _needles(logic)
		x.awake = XYunshang.awake(b)
		steps.append(x)
	var own_skills := b.skill_ids.duplicate()
	own_skills.sort()
	snap.call({"cri": b.cri, "luk": b.luk, "skills": own_skills})
	snap.call(_cast(logic, a, 10270, 1))
	if bool(o.woke):
		XYunshang.wake(logic, b)
	else:
		XYunshang.data(b).wake_until = 0
	snap.call({})
	for i in 2:
		snap.call(_cast(logic, b, int(o.skill), 1))
	var want: Array = c.observed.steps
	check(c.id + ".steps", steps.size() == want.size(), [steps.size(), want.size()])
	for i in mini(steps.size(), want.size()):
		var g: Dictionary = steps[i]
		var w: Dictionary = want[i]
		var sid := "%s.%d" % [c.id, i]
		check(sid + ".needles", g.needles == (w.needles as Array).map(func(v): return int(v)), [g.needles, w.needles])
		check(sid + ".awake", g.awake == bool(w.awake), [g.awake, w.awake])
		for k in ["cri", "luk"]:
			if w.has(k):
				check("%s.%s" % [sid, k], is_equal_approx(float(g.get(k, -1)), float(w[k])), [g.get(k), w[k]])
		if w.has("skills"):
			check(sid + ".skills", g.skills == (w.skills as Array).map(func(v): return int(v)), [g.skills, w.skills])
		if not w.has("log"):
			continue
		var gl: Array = g.log
		var wl: Array = w.log
		var gk := gl.map(func(l): return [l.user, l.skill, l.target, l.critical])
		var wk := wl.map(func(l): return [str(l.user), int(l.skill), str(l.target), bool(l.critical)])
		check(sid + ".log", gk == wk, [gk, wk])
		if gk != wk:
			continue
		for k in gk.size():
			check("%s.abs%d" % [sid, k], absf(float(gl[k].value) - float(wl[k].value)) <= DAMAGE_TOLERANCE * maxf(1.0, absf(float(wl[k].value)) * 1e-9), [gl[k].value, wl[k].value])


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if c.errors.is_empty():
			_case(c)
	check("covers_all", ref.cases.size() == 6, ref.cases.size())
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_yunshang_wraps", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
