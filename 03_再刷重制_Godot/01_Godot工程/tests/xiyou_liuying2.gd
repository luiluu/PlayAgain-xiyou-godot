extends Node
## 【cc·悟空·未经审查】179 流萤第二期（XLiuying 第二期）：与 mv_oracle/liuying2_probe.cjs 的新源 v0.62.12 参照（tests/fixtures/liuying2_oracle.json）逐步比。
## 每步比：流萤生命／最大生命／原生护盾／状态／燃烧可用回合／回合数／萤火层数／两招能不能用／战斗图；每只敌人生命（相对 1e-9）、存活、印记层数、状态、眩晕锁；
## 施放步另比扣血段数。
## - form.*：开战萨姆形态、负面免疫、免死；负面状态加不上；不戴法宝不变身、没学飞萤不免疫；结束清掉；
## - cast.*：天火付费转护盾、印记、扩散；燃烧消耗护盾回满、冷却 4 回合；三阶加盾（上限 50%）冷却 3；单目标 ×1.2／×1.5 与额外 4 段；再释放（随机 0.1）；
## - mark.*：12 层引爆（真伤＋强制眩晕＋2 回合锁）、不可驱散与清状态、减疗；易伤比值；firefly：萤火叠层、终伤比值、30 层封顶。
## 燃烧后免死刷新：参照是原版（O-296 关），开着时另查负面免疫与免死还在。
const FIXTURE := "res://tests/fixtures/liuying2_oracle.json"
const NEG := 32
var results := []
var stream_value := 0.5


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
	if not ok and results.filter(func(r): return not r.passed).size() <= 40:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _ints(v) -> Array:
	return (v as Array).map(func(x): return int(x))


func _sorted(ids: Array) -> Array:
	var out := ids.map(func(x): return int(x))
	out.sort()
	return out


func _battle(level: int, rank: int, no_armor := false) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.party.clear()
	s.battle_slots.clear()
	s.set_switch(2494, true)
	var a := s.actor(XLiuying.ACTOR)
	s.actor_advance[a.actor_id] = rank
	a.change_level_mv(level)
	XLiuying.recruit(s)
	if no_armor:
		XEquipment.change(s, a, a.equip_slots().find(int(XDB.rec("Armors", XLiuying.ARMOR).etypeId)), null)
	s.add_actor(1)
	s.actor(1).add_param(0, 1e12)
	for id in s.party:
		s.actor(id).refresh_passive()
	var rand := XBattleRandom.create("0000000000001792")
	var fs := FixedStream.new()
	fs.value = stream_value
	rand.rule = fs
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for id in s.party:
		var b := s.actor(id)
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	XLiuying.start_battle(logic)  # 同参照：recoverAll 清了状态，onBattleStart 包装再变身、给免疫免死
	logic.start_turn()
	return [logic, a]


func _snap(logic: XBattleLogic, a: XActor) -> Dictionary:
	return {"hp": a.hp, "mhp": a.mhp, "shield": a.shield, "states": _sorted(a.state_ids), "rsReady": int(a.state_data.get("_codexLbRsReady", 0)),
		"turn": logic.turn, "firefly": XLiuying.firefly,
		"meets": [10622, 10623].map(func(id): return logic.can_use(a, XDB.rec("Skills", id))),
		"battler": XCostumes.battler_name(XState.current, a, true),
		"foes": logic.enemies.map(func(e): return {"hp": e.hp, "alive": e.is_alive(), "marks": XLiuying.mark_count(e), "states": _sorted(e.state_ids),
			"lock": e.state_data.get("_codexLbStunLock")})}


func _cast(logic: XBattleLogic, a: XActor, id: int, t: int) -> Dictionary:
	a.mp = a.mmp
	a.tp = a.max_tp()
	var logs := logic.act(a, XDB.rec("Skills", id), logic.enemies[t])
	var hits := logs.filter(func(l): return l.get("type") == "hit" and l.get("user") == a and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)))
	return _snap(logic, a).merged({"cast": id, "count": hits.size()}, true)


func _step(logic: XBattleLogic, a: XActor, name: String, out = null) -> Dictionary:
	return _snap(logic, a).merged({"step": name, "out": out}, true)


func _near(x, y) -> bool:
	return absf(float(x) - float(y)) <= 1e-9 * maxf(1.0, absf(float(y)))


func _compare(id: String, got: Array, want: Array) -> void:
	check(id + ".steps", got.size() == want.size(), [got.size(), want.size()])
	for i in mini(got.size(), want.size()):
		var g: Dictionary = got[i]
		var w: Dictionary = want[i]
		var sid := "%s.%d.%s" % [id, i, str(w.get("step", w.get("cast", "")))]
		var end: bool = str(w.get("step", "")) == "end"
		var fs := XLiuying.firefly_state_id()
		var gst: Array = g.states.filter(func(x): return not (end and x == fs))
		var wst: Array = _sorted(w.states).filter(func(x): return not (end and x == fs))
		var gm := [_near(g.hp, w.hp), _near(g.mhp, w.mhp), end or _near(g.shield, w.shield), gst, int(g.rsReady), int(g.turn), int(g.firefly), g.meets, str(g.battler)]
		var wm := [true, true, true, wst, int(w.rsReady), int(w.turn), int(w.firefly), (w.meets as Array).map(func(v): return bool(v)), str(w.battler)]
		check(sid + ".self", gm == wm, [[g.hp, g.mhp, g.shield] + gm.slice(3), [w.hp, w.mhp, w.shield] + wm.slice(3)])
		for k in mini((g.foes as Array).size(), (w.foes as Array).size()):
			var gf: Dictionary = g.foes[k]
			var wf: Dictionary = w.foes[k]
			var a1 := [_near(gf.hp, wf.hp), bool(gf.alive), int(gf.marks), gf.states, null if gf.lock == null else int(gf.lock)]
			var b1 := [true, bool(wf.alive), int(wf.marks), _sorted(wf.states), null if wf.lock == null else int(wf.lock)]
			check("%s.foe%d" % [sid, k], a1 == b1, [[gf.hp] + a1.slice(1), [wf.hp] + b1.slice(1)])
		if w.has("log"):
			check(sid + ".count", int(g.get("count", -1)) == (w.log as Array).size(), [g.get("count"), (w.log as Array).size()])
		if w.get("out") != null and str(w.get("step", "")) in ["dispel", "clear", "heal", "healPlain", "addNeg", "addable", "removeStun"]:
			check(sid + ".out", JSON.stringify(g.out) == JSON.stringify(w.out) or _near_out(g.out, w.out), [g.out, w.out])


func _near_out(g, w) -> bool:
	if g is Array and w is Array and g.size() == w.size():
		for i in g.size():
			if not (str(g[i]) == str(w[i]) or ((g[i] is float or g[i] is int) and _near(g[i], w[i]))):
				return false
		return true
	return (g is float or g is int) and (w is float or w is int) and _near(g, w)


func _hit_value(logs: Array, u) -> float:
	for l in logs:
		if l.get("type") == "hit" and l.get("user") == u:
			return float(l.hp)
	return 0.0


func _case(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var setup: Dictionary = c.setup
	var id := str(c.id)
	stream_value = float(setup.get("random", 0.5))
	var r := _battle(int(setup.level), int(setup.rank), id == "form.noArmor") if id != "firefly" else _battle(60, 1)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var foes: Array = logic.enemies
	var steps := []
	match id:
		"form.start":
			steps.append(_step(logic, a, "start"))
			logic._state_add(a, NEG)
			steps.append(_step(logic, a, "addNeg", a.state_ids.has(NEG)))
			steps.append(_step(logic, a, "addable", [not XLiuying.blocks_state(a, NEG), not XLiuying.blocks_state(a, 29)]))
			logic.end_battle(0)
			steps.append(_step(logic, a, "end"))
		"form.noArmor":
			steps.append(_step(logic, a, "start"))
			logic._state_add(a, NEG)
			steps.append(_step(logic, a, "addNeg", a.state_ids.has(NEG)))
		"cast.tianhuo":
			steps.append(_step(logic, a, "start"))
			steps.append(_cast(logic, a, 10622, 0))
			steps.append(_cast(logic, a, 10622, 1))
			logic.end_battle(0)
			steps.append(_step(logic, a, "end"))
		"cast.ranshao":
			steps.append(_cast(logic, a, 10622, 0))
			a.shield += 5000.0
			a.hp = floorf(a.mhp / 2.0)
			steps.append(_step(logic, a, "prep"))
			steps.append(_cast(logic, a, 10623, 0))
			for i in 4:
				logic.turn += 1
				steps.append(_step(logic, a, "turn"))
		"cast.ranshao.r3":
			a.shield = 8000.0
			steps.append(_step(logic, a, "prep"))
			steps.append(_cast(logic, a, 10623, 0))
			a.shield = 9e9
			steps.append(_step(logic, a, "big"))
			a.state_data["_codexLbRsReady"] = 0
			steps.append(_cast(logic, a, 10623, 0))
		"mark.explode":
			var e: XEnemy = foes[0]
			steps.append(_cast(logic, a, 10622, 0))
			e.state_data["_codexLbMark"] = 11
			steps.append(_cast(logic, a, 10622, 0))
			logic._state_remove(e, 29)
			steps.append(_step(logic, a, "removeStun", e.state_ids.has(29)))
			logic._state_add(e, XLiuying.MARK)
			e.state_data["_codexLbMark"] = 11
			steps.append(_cast(logic, a, 10622, 0))
			var f: XEnemy = foes[1]
			logic._state_add(f, XLiuying.MARK)
			f.state_data["_codexLbMark"] = 3
			logic._state_remove(f, XLiuying.MARK)
			f.remove_state(XLiuying.MARK)
			steps.append(_step(logic, a, "dispel", [f.state_ids.has(XLiuying.MARK), XLiuying.mark_count(f)]))
			f.clear_states()
			steps.append(_step(logic, a, "clear", [f.state_ids.has(XLiuying.MARK), XLiuying.mark_count(f)]))
			f.hp = f.mhp - 1e6
			logic.gain_hp(f, 100000.0)
			steps.append(_step(logic, a, "heal", f.mhp - f.hp))
			var g: XEnemy = foes[2]
			g.hp = g.mhp - 1e6
			logic.gain_hp(g, 100000.0)
			steps.append(_step(logic, a, "healPlain", g.mhp - g.hp))
			logic.end_battle(0)
			steps.append(_step(logic, a, "end"))
		"mark.vuln":
			var u: XActor = XState.current.actor(1)
			var v1 := _hit_value(logic.act(u, u.attack_skill(), foes[0]), u)
			logic._state_add(foes[0], XLiuying.MARK)
			foes[0].state_data["_codexLbMark"] = 6
			var v2 := _hit_value(logic.act(u, u.attack_skill(), foes[0]), u)
			check("mark.vuln", v1 > 0.0 and absf(v2 / v1 - float(o.marked.value) / float(o.plain.value)) < 1e-6, [v1, v2, o.plain.value, o.marked.value])
			return
		"cast.single":
			logic._state_add(foes[1], 1)
			logic._state_add(foes[2], 1)
			steps.append(_cast(logic, a, 10622, 0))
			steps.append(_cast(logic, a, 10623, 0))
		"firefly":
			var u: XActor = XState.current.actor(1)
			var v1 := _hit_value(logic.act(u, u.attack_skill(), foes[0]), u)
			for i in 2:
				logic.act(foes[0], foes[0].attack_skill(), a)
				steps.append(_step(logic, a, "hit"))
			var v2 := _hit_value(logic.act(u, u.attack_skill(), foes[0]), u)
			XLiuying.firefly = 30
			XLiuying.add_firefly(logic)
			steps.append(_step(logic, a, "cap"))
			check("firefly.ratio", v1 > 0.0 and absf(v2 / v1 - float(o.boosted.value) / float(o.plain.value)) < 1e-6, [v1, v2, o.plain.value, o.boosted.value])
		"cast.rerelease":
			steps.append(_cast(logic, a, 10622, 0))
	_compare(id, steps, o.steps)


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	check("firefly_state", XLiuying.firefly_state_id() == 2791, XLiuying.firefly_state_id())
	var fix := XLiuying.FIX_UNDYING_REFRESH
	XLiuying.FIX_UNDYING_REFRESH = false  # 参照是原版
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if c.errors.is_empty():
			_case(c)
	# 修正开着：燃烧后负面免疫与免死还在（回合数重置）
	XLiuying.FIX_UNDYING_REFRESH = true
	stream_value = 0.5
	var r := _battle(60, 2)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	logic.act(a, XDB.rec("Skills", 10623), logic.enemies[0])
	check("fix_undying_refresh", a.state_ids.has(XLiuying.IMMUNE) and a.state_ids.has(XLiuying.UNDYING), a.state_ids)
	XLiuying.FIX_UNDYING_REFRESH = fix
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_liuying2", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
