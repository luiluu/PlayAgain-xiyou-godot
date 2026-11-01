extends Node
## 异化战斗侧（XAlienBattle）：逐例对照 mv_oracle/alien_battle_probe.cjs（generated/oracle/alien_battle.json）。
## - config：alienation.json 的 bossSources／mobSources／transition 与五种变体照参照。
## - encounter.*：新局队伍 1／8／9／10，设地图与未知存在来源，开战（随机数全 0.5，不触发）后用排好的随机数序列再调一次
##   setup_encounter（序列用完取 0.5，奖励词条 XAlienation.force_roll 0.5），比遭遇结果、未遭遇时取随机数的次数、账本序号、
##   各敌人名字、最大生命、生命与是否 Boss。
## - battle.*：角色 1＋8，敌群 2（敌人生命加 1e12），指定变体遭遇；每步比双方生命、法力、护盾、腐蚀与到期回合、敌人名字与异化数据、提示。
## - lock：带异化装备开战时冻结词条。
const ORACLE := "oracle/alien_battle.json"
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))
	return ok


func _ready() -> void:
	_run.call_deferred()


static func _norm(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = _norm(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is float or v is int:
		return snappedf(float(v), 1e-6)
	return v


func _run() -> void:
	var ref = XDB.load_json(ORACLE)
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		get_tree().quit.call_deferred(1)
		return
	var cfg := XAlienation.config()
	for k in ["bossSources", "mobSources", "transition"]:
		check("config." + k, _norm(cfg.get(k)) == _norm(ref.config[k]), [cfg.get(k), ref.config[k]])
	var vs := (cfg.variants as Array) + [cfg.mobVariant]
	check("config.variants", _norm(cfg.variants) == _norm(ref.config.variants), [cfg.variants, ref.config.variants])
	check("config.mobVariant", str(cfg.mobVariant.name) == "异化" and vs.size() == 6, cfg.mobVariant)
	for c in ref.cases:
		if not check(str(c.id) + ".oracle_clean", (c.errors as Array).is_empty(), c.errors):
			continue
		var id := str(c.id)
		if id.begins_with("encounter."):
			_encounter(c)
		elif id.begins_with("battle."):
			_battle(c)
		elif id == "lock":
			_lock(c)
	XAlienation.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648

	## 参照里 Math.random 恒为 0.5：整数取法是 floor(0.5×n)＝n÷2，不是原始 uint 2^31 对 n 取模（同 xiyou_alien_affix）
	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		next_uint(reason, event_key)
		return n / 2 if n > 0 else 0

	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		next_uint(reason, event_key)
		return lo + (hi - lo + 1) / 2


## 排好的随机数：用完取 0.5
class SeqStream extends XRandomStream:
	var seq: Array = []
	func _take(kind: String, _reason: String, _event_key: String):
		var v := float(seq[draws]) if draws < seq.size() else 0.5
		draws += 1
		return v if kind == "float" else int(v * 4294967296.0)


func _logic(s: XState, troop: int) -> XBattleLogic:
	var rand := XBattleRandom.create("0000000000000176")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(troop, s, rand)
	return logic


func _encounter(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var st: Dictionary = c.setup
	var s := XState.new_game_blank()
	XState.current = s
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.map_id = int(st.map)
	s.unknown_origin = int(st.origin) if st.has("origin") else null
	XAlienation.force_roll = 0.5
	# 奖励本体的前后缀与属性浮动（XGear.create）：参照里序列用完后 Math.random 一律 0.5；重制原来走新局的装备随机流（种子每局不同），
	# 偶尔掷出前后缀（boss_150 名字成了「天外天·灼烂歼鬼小李飞刀」，累计偶发 5 次，tools30）。这里同参照固定 0.5
	XGear.force_roll = 0.5
	var logic := _logic(s, int(st.troop))
	var tag := str(c.id)
	check(tag + ".start_miss", XAlienBattle.encounter(logic) == null)
	var seq0 := int(XAlienation.ledger(s).sequence)
	var rng := SeqStream.new()
	rng.seq = st.get("random", [])
	var x = XAlienBattle.setup_encounter(logic, rng)
	var want = o.encounter
	if want == null:
		check(tag + ".encounter", x == null, x)
		check(tag + ".draws", rng.draws == int(o.draws), [rng.draws, o.draws])
	elif check(tag + ".encounter", x != null, want):
		var m := XAlienation.mark(x.reward)
		var got := {"enemyIndex": logic.enemies.find(x.enemy), "variant": str(x.variant.key), "boss": bool(x.enemy.alien.boss),
			"origin": str(m.origin), "affix": str(m.affix), "uid": str(m.uid), "kind": XAlienation.kind(x.reward), "baseId": int(x.reward.base)}
		var exp := {"enemyIndex": int(want.enemyIndex), "variant": str(want.variant), "boss": bool(want.boss), "origin": str(want.reward.origin),
			"affix": str(want.reward.affix), "uid": str(want.reward.uid), "kind": str(want.reward.kind), "baseId": int(want.reward.baseId)}
		check(tag + ".encounter", got == exp, [got, exp])
		check(tag + ".probability", absf(float(x.probability) - float(want.probability)) < 1e-12, [x.probability, want.probability])
		check(tag + ".plainName", str(m.plainName) == str(want.reward.plainName), [m.plainName, want.reward.plainName])
	check(tag + ".sequence", int(XAlienation.ledger(s).sequence) - seq0 == int(o.sequenceGain), [int(XAlienation.ledger(s).sequence) - seq0, o.sequenceGain])
	var got_e := logic.enemies.map(func(e): return {"id": e.enemy_id, "name": e.display_name(), "mhp": e.mhp, "hp": e.hp, "boss": XZhenqi.is_boss_enemy(e)})
	check(tag + ".enemies", _norm(got_e) == _norm(o.enemies), [got_e, o.enemies])
	XGear.force_roll = -1.0
	XState.current = null


func _unit(x) -> Dictionary:
	var id := XAlienBattle.corrosion_id()
	var has: bool = x.state_ids.has(id)
	return {"hp": x.hp, "mp": x.mp, "mhp": x.mhp, "shield": x.shield, "corrosion": has, "corrosionTurns": int(x.state_turns.get(id, 0)) if has else null,
		"corrosionUntil": XAlienBattle.corrosion_until(x)}


func _alien(e: XEnemy):
	if e.alien.is_empty():
		return null
	var out := {}
	for k in ["variant", "boss", "shieldGranted", "mirrorRound", "mirrorCharged", "plagueRound", "drainRound"]:
		out[k] = e.alien[k]
	return out


func _reading(enemies: Array, a, b) -> Dictionary:
	return {"enemies": enemies.map(func(e):
			var u := _unit(e)
			u.name = e.display_name()
			u.alien = _alien(e)
			return u), "a": _unit(a), "b": _unit(b)}


func _same_reading(step: String, got: Dictionary, row: Dictionary) -> void:
	for k in ["a", "b"]:
		check(step + "." + k, _norm(got[k]) == _norm(row[k]), [got[k], row[k]])
	for i in got.enemies.size():
		check(step + ".e%d" % i, _norm(got.enemies[i]) == _norm(row.enemies[i]), [got.enemies[i], row.enemies[i]])


func _battle(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var st: Dictionary = c.setup
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	XState.current = s
	var a := s.actor(1)
	var b := s.actor(8)
	a.change_level_mv(30)
	b.change_level_mv(30)
	s.party.clear()
	s.battle_slots.clear()
	s.add_actor(1)
	s.add_actor(8)
	XAlienation.force_roll = 0.5
	var logic := _logic(s, int(st.troop))
	var enemies: Array = logic.enemies
	for e in enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		p[2] += float(st.get("enemyAtkPlus", 0))
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
	var toasts: Array = XAlienBattle._store(logic).toasts
	toasts.clear()
	if st.has("variant"):
		var mob := str(st.variant) == "mob"
		XAlienBattle.setup_encounter(logic, logic._rule(), {"enemy": int(st.get("enemy", 0)), "kind": "w", "baseId": 3980,
			"origin": "mob" if mob else "boss", "variant": null if mob else str(st.variant), "affix": str(st.get("affix", "inversebone"))})
	for x in [a, b] + enemies:
		x.param_mark_dirty()
		x.param_refresh()
		x.recover_all()
	XAlienBattle.open(logic)
	var tag := str(c.id)
	check(tag + ".startToasts", toasts == o.startToasts, [toasts, o.startToasts])
	var locked := [a, b].map(func(x):
		var l = XAlienBattle.locked(x)
		return {"affix": l.affix} if l != null else null)
	check(tag + ".locked", _norm(locked) == _norm(o.locked), [locked, o.locked])
	var x = XAlienBattle.encounter(logic)
	var enc = {"enemyIndex": enemies.find(x.enemy), "variant": str(x.variant.key), "probability": x.probability} if x != null else null
	check(tag + ".encounter", _norm(enc) == _norm(o.encounter), [enc, o.encounter])
	var got_e := enemies.map(func(e): return {"id": e.enemy_id, "mhp": e.mhp, "name": e.display_name()})
	check(tag + ".enemies", _norm(got_e) == _norm(o.enemies), [got_e, o.enemies])
	for i in o.rows.size():
		var row: Dictionary = o.rows[i]
		var step := "%s.%d" % [tag, i]
		toasts.clear()
		if row.has("roundStart"):
			logic.turn = int(row.roundStart)
			XAlienBattle.start_turn(logic)
		elif row.has("roundEnd"):
			logic.turn = int(row.roundEnd)
			XAlienBattle.round_end(logic)
		elif row.has("set"):
			var set: Dictionary = row.set
			if set.has("enemyHpRate"):
				var e: XEnemy = enemies[int(set.get("enemy", 0))]
				e.hp = floorf(e.mhp * float(set.enemyHpRate))
			if set.has("actorMpRate"):
				a.mp = floorf(a.mmp * float(set.actorMpRate))
			if set.has("allyMpRate"):
				b.mp = floorf(b.mmp * float(set.allyMpRate))
			if set.has("kill"):
				var e: XEnemy = enemies[int(set.kill)]
				e.hp = 0.0
				e.add_state(1)
		elif row.has("grant"):
			var before := s.gear.filter(func(g): return str(g.kind) == "weapon").size()
			var ok := XAlienBattle.grant(logic)
			check(step + ".grant", ok == bool(row.ok), [ok, row.ok])
			check(step + ".weapons", s.gear.filter(func(g): return str(g.kind) == "weapon").size() - before == int(row.weapons))
			var recent := (XAlienation.ledger(s).recent as Array).map(func(v): return {"origin": v.origin, "uid": v.uid, "kind": v.kind})
			check(step + ".recent", _norm(recent) == _norm(row.recent), [recent, row.recent])
			check(step + ".granted", bool(XAlienBattle.encounter(logic).granted) == bool(row.granted))
		else:
			var sp: Dictionary = row.step
			logic.turn = int(sp.round)
			var user: XBattler = a
			var who := str(sp.get("user", "a"))
			if who == "b":
				user = b
			elif who.begins_with("e"):
				user = enemies[int(who.substr(1))]
			user.tp = 100.0
			user.mp = user.mmp
			var skill := XDB.rec("Skills", int(sp.skill))
			var ti := int(sp.get("target", 0))
			var target: XBattler = (enemies if user is XActor else logic.actors)[ti]
			for l in logic.act(user, skill, target):
				if l.type == "toast":
					toasts.append(l.text)
		_same_reading(step, _reading(enemies, a, b), row)
		if row.has("toasts"):
			check(step + ".toasts", toasts == row.toasts, [toasts, row.toasts])
	XAlienBattle.end(logic, -1)
	XState.current = null


func _lock(c: Dictionary) -> void:
	var s := XState.new_game_blank()
	XState.current = s
	s.party.clear()
	s.battle_slots.clear()
	s.add_actor(1)
	s.add_actor(8)
	var a := s.actor(1)
	var made := XAlienation.create(s, "w", 1042, "mob", "inversebone")
	a.equips[0] = made.ok
	var logic := XBattleLogic.new()
	logic.actors = [a, s.actor(8)]
	XAlienBattle.lock_party(logic)
	XAlienBattle._logic_ref = weakref(logic)
	var got := [1, 8].map(func(id):
		var l = XAlienBattle.locked(s.actor(id))
		return {"affix": l.affix, "uid": XAlienation.mark(l.item).uid, "config": l.config, "selected": l.selected} if l != null else null)
	check("lock.locked", _norm(got) == _norm(c.observed.locked), [got, c.observed.locked])
	check("lock.for_actor", str(XAlienation.for_actor(a).get("affix", "")) == "inversebone")
	XAlienBattle.end(logic, -1)
	check("lock.after_end", XAlienBattle.locked(a) == null)
	XState.current = null
