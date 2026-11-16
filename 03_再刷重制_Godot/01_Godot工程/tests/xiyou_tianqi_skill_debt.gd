extends Node
## 天启篇技能重构欠账（T016）专项：探索版

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _state(lineup: Array) -> XState:
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _run() -> void:
	XMessageBox.auto = true
	seed(20261116)
	XTianqiSkills.reload()
	XGojo.unlock_override = 0
	XTianqiSkills.CARDS = true
	_probe_follow()
	_probe_counter()
	_probe_guard()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		print(("PASS " if r.passed else "FAIL "), r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _hits(logs: Array, u) -> int:
	var n := 0
	for l in logs:
		if l is Dictionary and l.get("type") == "hit" and is_same(l.get("user"), u) and not l.get("counter", false) and not l.get("reflected", false):
			n += 1
	return n


func _per_target(logs: Array, lg) -> Array:
	var out := []
	for e in lg.enemies:
		out.append(logs.filter(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("target"), e)).size())
	return out


func _probe_follow() -> void:
	var s := _state([3, 23, 1, 2, 64])
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var u: XActor = s.actor(3)
	u.change_level(99)
	for e in lg.enemies:
		e.add_param(0, 1e12)
		e.hp = e.mhp
	var rows := []
	for c in [533, 4370, 533, 1799, 3713, 1073, 1114, 2011, 5424, 1205, 2086]:
		var cast := XDB.rec("Skills", c)
		var t = lg.enemies[0]
		# 正常整次行动打几段（不让它再触发追加）
		XTianqiSkills._fstore(lg).used[u] = int(lg.turn)
		var full := _hits(lg.execute(u, cast, t, true), u)
		XTianqiSkills._fstore(lg).used.erase(u)
		# 追加出来打几段
		XTianqiSkills._skills[506] = XTianqiSkills._skills[506].duplicate(true)
		XTianqiSkills._skills[506].follow = [{"cast": c, "rate": 1.0}]
		var dunk := XDB.rec("Skills", 506)
		XTianqiSkills.begin_action(lg, u, dunk)
		XTianqiSkills.after_apply(lg, u, dunk, t)
		var fll := XTianqiSkills.end_action(lg, u, dunk)
		var fl := _hits(fll, u)
		if c == 4370:
			var hs := []
			for l in fll:
				if l is Dictionary and l.get("type") == "hit":
					hs.append([lg.enemies.find(l.target), int(l.skill.id), float(l.hp)])
			print("DBG4370 hits ", hs)
			print("DBG4370 follow ", _per_target(fll, lg), " full ", _per_target(lg.execute(u, cast, t, true), lg), " n_enemies ", lg.enemies.size())
		XTianqiSkills._fstore(lg).used.erase(u)
		rows.append([c, str(cast.get("name", "")), int(cast.get("scope", 0)), XActionSequence.has_sequence(cast), full, fl])
		for e in lg.enemies:
			e.hp = e.mhp
			if e.is_state_affected(1):
				e.remove_state(1)
		u.hp = u.mhp
		u.mp = u.mmp
	XTianqiSkills.reload()
	_check("follow_measure", true, rows)
	lg.end_battle(0)


func _probe_counter() -> void:
	var s := _state([42, 1, 2, 3, 23])
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var b: XActor = s.actor(42)
	b.change_level(99)
	b.learn_skill(1162)
	b.param_mark_dirty()
	b.add_param(0, 1e12)
	b.hp = b.mhp
	var e = lg.enemies[0]
	e.add_param(0, 1e12)
	e.hp = e.mhp
	var atk: Dictionary = XDB.rec("Skills", 1153)  # 物理单体（敌群 2 的普攻是魔法，不吃原生反击）
	var n := 300
	var counters := 0
	var swallowed := 0
	var cdmg := 0.0
	for i in range(n):
		var logs: Array = lg._invoke(e, atk, b)
		var got_hit := logs.any(func(l): return l is Dictionary and l.get("type") == "hit" and is_same(l.get("target"), b))
		var c := logs.filter(func(l): return l is Dictionary and l.get("counter", false) and l.get("type") == "hit")
		if not c.is_empty():
			counters += 1
			cdmg += float(c[0].hp)
			if not got_hit:
				swallowed += 1
		e.hp = e.mhp
		b.hp = b.mhp
	var direct := 0.0
	for i in range(100):
		direct += float(lg.apply(b, b.attack_skill(), e).hp)
		e.hp = e.mhp
	_check("counter_measure", true, {"phys": XDamage.is_physical(atk), "atk_id": int(atk.id), "hitType": atk.get("hitType"), "sure": lg.certain_hit(e, atk), "restricted": lg._restricted(b), "cnt": b.cnt, "counters": counters, "of": n, "swallowed": swallowed, "counter_avg": cdmg / maxf(1, counters), "direct_avg": direct / 100.0, "atk_skill": b.attack_skill_id()})
	lg.end_battle(0)


func _probe_guard() -> void:
	var s := _state([86, 1, 2, 3, 23])
	var lg := XBattleLogic.new()
	lg.setup(2, s)
	var z: XActor = s.actor(86)
	z.change_level(99)
	var ally: XActor = s.actor(1)
	ally.add_param(0, 1e12)
	ally.hp = ally.mhp
	var e = lg.enemies[0]
	e.add_param(0, 1e12)
	e.hp = e.mhp
	lg._battle_start_states()
	var st := []
	for a in lg.actors:
		st.append([a.actor_id, a.is_state_affected(2007)])
	XStateEffects.take_reserves()
	var logs: Array = lg._invoke(e, XDB.rec("Skills", 1153), ally)
	var res := XStateEffects.take_reserves()
	var kinds := []
	for l in logs:
		if l is Dictionary:
			kinds.append([str(l.get("type")), (l.user.actor_id if l.get("user") is XActor else -1), int(l.skill.id) if l.get("skill") is Dictionary else 0])
	_check("guard_measure", true, {"states": st, "logs": kinds, "reserved": res})
	lg.end_battle(0)
