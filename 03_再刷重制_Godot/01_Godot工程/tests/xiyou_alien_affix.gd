extends Node
## 异化词条效果（XAlienBattle 文末「词条效果」，期一：逆骨、归墟）：逐例对照 mv_oracle/alien_affix_probe.cjs（generated/oracle/alien_affix.json）。
## - config：alienation.json 的 templates.inversebone／attack 长度与头尾照参照。
## - battle.*：角色 1（99 级）穿本体 1044 的异化武器（none 为不带标记的本体）＋角色 8，敌群 2（敌人生命加 1e12、攻击加 300），开战锁队；
##   每步比双方生命、法力、护盾、状态、增减益，以及战斗帧外角色 1 的物攻／物防。
## - frames：每步之后公式帧与行动帧都已弹空。
const ORACLE := "oracle/alien_affix.json"
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
	var t := XAlienation.templates()
	for k in ["inversebone", "attack"]:
		var list: Array = t.get(k, [])
		var got := {"size": list.size(), "head": list.slice(0, 5), "tail": list.slice(-5)}
		check("config." + k, _norm(got) == _norm(ref.config[k]), [got, ref.config[k]])
	for c in ref.cases:
		if check(str(c.id) + ".oracle_clean", (c.errors as Array).is_empty(), c.errors):
			_battle(c)
	XAlienation.force_roll = -1.0
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648


func _logic(s: XState, troop: int) -> XBattleLogic:
	var rand := XBattleRandom.create("0000000000000176")
	rand.rule = HalfStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(troop, s, rand)
	return logic


func _unit(x) -> Dictionary:
	var states := Array(x.state_ids)
	states.sort()
	return {"hp": x.hp, "mp": x.mp, "shield": x.shield, "states": states, "buffs": Array(x.buffs).slice(2, 8)}


func _reading(enemies: Array, a, b) -> Dictionary:
	var ra := _unit(a)
	ra.atk = a.atk
	ra.def = a.def
	return {"enemies": enemies.map(func(e): return _unit(e)), "a": ra, "b": _unit(b)}


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
	a.change_level_mv(99)
	b.change_level_mv(30)
	s.party.clear()
	s.battle_slots.clear()
	s.add_actor(1)
	s.add_actor(8)
	XAlienation.force_roll = 0.5
	if st.has("affix"):
		XGear.force_roll = 0.5  # 同参照 Math.random 0.5：属性浮动与词缀随机
		a.equips[0] = XAlienation.create(s, "w", int(st.weapon), "boss", str(st.affix)).ok
		XGear.force_roll = -1.0
	else:
		a.equips[0] = XGear.template("weapon", int(st.weapon))
	var logic := _logic(s, int(st.troop))
	var enemies: Array = logic.enemies
	for e in enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		p[2] += 300.0
		e.zq_ref = {"p": p, "k": 1.0}
	for x in [a, b] + enemies:
		x.param_mark_dirty()
		x.param_refresh()
		x.recover_all()
	XAlienBattle.open(logic)
	var tag := str(c.id)
	var locked := [a, b].map(func(x):
		var l = XAlienBattle.locked(x)
		return {"affix": l.affix} if l != null else null)
	check(tag + ".locked", _norm(locked) == _norm(o.locked), [locked, o.locked])
	_same_reading(tag + ".start", _reading(enemies, a, b), o.start)
	for i in o.rows.size():
		var row: Dictionary = o.rows[i]
		var sp: Dictionary = row.step
		var step := "%s.%d" % [tag, i]
		logic.turn = 1
		var user: XBattler = a
		var who := str(sp.get("user", "a"))
		if who == "b":
			user = b
		elif who.begins_with("e"):
			user = enemies[int(who.substr(1))]
		user.tp = 100.0
		user.mp = user.mmp
		var skill := XDB.rec("Skills", int(sp.skill))
		var target: XBattler = (enemies if user is XActor else logic.actors)[int(sp.get("target", 0))]
		logic.act(user, skill, target)
		_same_reading(step, _reading(enemies, a, b), row)
		check(step + ".frames", XAlienBattle._formula_frames.is_empty() and XAlienBattle._action_frames.is_empty(),
			[XAlienBattle._formula_frames.size(), XAlienBattle._action_frames.size()])
	XAlienBattle.end(logic, -1)
	XState.current = null
