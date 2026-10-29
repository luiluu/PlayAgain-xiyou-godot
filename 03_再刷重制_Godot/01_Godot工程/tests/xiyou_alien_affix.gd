extends Node
## 异化词条效果（XAlienBattle 文末「词条效果」，期一：逆骨、归墟）：逐例对照 mv_oracle/alien_affix_probe.cjs（generated/oracle/alien_affix.json）。
## - config：alienation.json 的 templates.inversebone／attack 长度与头尾照参照。
## - battle.*：角色 1（99 级）穿本体 1044 的异化武器（none 为不带标记的本体）＋角色 8，敌群 2（敌人生命加 1e12、攻击加 300），开战锁队；
##   每步比双方生命、法力、护盾、状态、增减益，以及战斗帧外角色 1 的物攻／物防。
## - frames：每步之后公式帧与行动帧都已弹空。
## - 期二① battle.pest／jail／insulation／sacrifice：合成技能（空白技能 13 照参照的 def 填 scope／hitType／效果）、set、
##   roundEnd（XAlienBattle.spread_pest）、expire（自然移除）逐步对照；对照时 O-106 关（照原版）。
## - o106.*：O-106 开时角色身上的减益也走囚厄接收、绝缘拒收（原版对角色失效）。
## - 期二② battle.hollow／lifelink／scapegoat：步骤另有 regen（turn_end_battler，照 onTurnEnd）、revive（去阵亡状态）；对照时 O-108 关。
## - 生命池补漏 battle.*.corrosion：tick 照 endTurn 包装结算腐蚀（行动外 gainHp）；*.event 照事件「增减生命」（MVEventCore 311）。
## - o108.*：O-108 开时连命复活把池回到 10%（两人都起来），嫁祸的保护者倒下时不能复活。
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
	XAlienBattle.o106_actor_debuffs = false
	XAlienBattle.o108_life_revive = false
	var by_id := {}
	for c in ref.cases:
		by_id[str(c.id)] = c
		if check(str(c.id) + ".oracle_clean", (c.errors as Array).is_empty(), c.errors):
			_battle(c)
	XAlienBattle.o106_actor_debuffs = true
	XAlienBattle.o108_life_revive = true
	if by_id.has("battle.lifelink"):
		var rows := _battle(by_id["battle.lifelink"], false)
		var last: Dictionary = rows[rows.size() - 1]
		check("o108.lifelink_revive_pool", last.a.hp > 1.0 and last.b.hp > 0.0 and not (last.b.states as Array).has(1), [last.a, last.b])
	if by_id.has("battle.scapegoat"):
		var rows := _battle(by_id["battle.scapegoat"], false)
		check("o108.scapegoat_no_revive", (rows[rows.size() - 1].a.states as Array).has(1), rows[rows.size() - 1].a)
	if by_id.has("battle.jail"):
		var rows := _battle(by_id["battle.jail"], false)
		check("o106.jail_debuff_moved", rows[1].a.buffs[1] == -1 and rows[1].b.buffs[1] == 0, [rows[1].a.buffs, rows[1].b.buffs])
		check("o106.jail_debuff_kept", rows[3].a.buffs[1] == -1, rows[3].a.buffs)
	if by_id.has("battle.insulation"):
		var rows := _battle(by_id["battle.insulation"], false)
		check("o106.insulation_debuff_blocked", rows[7].a.buffs[0] == 0, rows[7].a.buffs)
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


## 只比参照有的键（帧外物攻／物防只在期一的用例里记）
func _same_reading(step: String, got: Dictionary, row: Dictionary) -> void:
	for k in ["a", "b"]:
		var mine := {}
		for key in row[k]:
			mine[key] = got[k].get(key)
		check(step + "." + k, _norm(mine) == _norm(row[k]), [mine, row[k]])
	for i in got.enemies.size():
		check(step + ".e%d" % i, _norm(got.enemies[i]) == _norm(row.enemies[i]), [got.enemies[i], row.enemies[i]])


## 合成技能：空白技能 13 填 def（同参照 synth）
static func _synth(def: Dictionary) -> Dictionary:
	var sk := XDB.rec("Skills", 13).duplicate(true)
	sk.scope = int(def.scope)
	sk.hitType = int(def.hitType)
	sk.effects = (def.effects as Array).map(func(e): return {"code": int(e[0]), "dataId": int(e[1]), "value1": float(e[2]), "value2": 0.0})
	return sk


func _battle(c: Dictionary, compare := true) -> Array:
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
		var item: Dictionary = XAlienation.create(s, "a" if st.has("armor") else "w", int(st.get("armor", st.weapon)), "boss", str(st.affix)).ok
		XGear.force_roll = -1.0
		if st.has("config"):
			XAlienation.mark(item).config = (st.config as Dictionary).duplicate(true)
			for k in item.alien.config:
				item.alien.config[k] = int(item.alien.config[k])
		if st.has("armor"):
			a.equips[0] = XGear.template("weapon", int(st.weapon))
			a.equips[a.equip_slots().find(int(item.etypeId))] = item
		else:
			a.equips[0] = item
	else:
		a.equips[0] = XGear.template("weapon", int(st.weapon))
	var logic := _logic(s, int(st.troop))
	var enemies: Array = logic.enemies
	for e in enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		p[2] += 300.0
		e.zq_ref = {"p": p, "k": 1.0}
	# setup 已锁过一次队；参照是回满后才 lockParty，先解锁（不然空壳的生命上限 1 会让回满只回到 1）
	XAlienBattle._store(logic).party = {}
	XAlienBattle._store(logic).status = false
	for x in [a, b] + enemies:
		x.param_mark_dirty()
		x.param_refresh()
		x.recover_all()
	XAlienBattle.open(logic)
	var tag := str(c.id)
	var locked := [a, b].map(func(x):
		var l = XAlienBattle.locked(x)
		return {"affix": l.affix} if l != null else null)
	if compare:
		check(tag + ".locked", _norm(locked) == _norm(o.locked), [locked, o.locked])
		_same_reading(tag + ".start", _reading(enemies, a, b), o.start)
	var who := func(k: String) -> XBattler:
		return b if k == "b" else enemies[int(k.substr(1))] if k.begins_with("e") else a
	var got := []
	for i in o.rows.size():
		var row: Dictionary = o.rows[i]
		var sp: Dictionary = row.step
		var step := "%s.%d" % [tag, i]
		logic.turn = int(sp.get("round", 1))
		if sp.has("set"):
			for k in ["a", "b"]:
				var x: XBattler = who.call(k)
				if sp.set.has(k + "Hp"):
					x.hp = floorf(x.mhp * float(sp.set[k + "Hp"]))
				if sp.set.has(k + "Mp"):
					x.mp = floorf(x.mmp * float(sp.set[k + "Mp"]))
		elif sp.has("roundEnd"):
			logic.turn = int(sp.roundEnd)
			XAlienBattle.spread_pest(logic)
		elif sp.has("regen"):
			logic.turn_end_battler(who.call(str(sp.regen)), [])
		elif sp.has("tick"):
			logic.turn = int(sp.tick)
			for x in logic.actors + logic.enemies:
				XAlienBattle.tick_corrosion(logic, x, int(sp.tick), [])
		elif sp.has("event"):
			MVEventCore.new()._change_resource(who.call(str(sp.event.who)), 311, float(sp.event.value), bool(sp.event.get("death", false)))
		elif sp.has("revive"):
			logic._state_remove(who.call(str(sp.revive)), 1)
		elif sp.has("expire"):
			logic._state_remove(who.call(str(sp.expire.who)), int(sp.expire.id), true)
		else:
			var user: XBattler = who.call(str(sp.get("user", "a")))
			user.tp = 100.0
			user.mp = user.mmp
			var skill := _synth(sp.def) if sp.has("def") else XDB.rec("Skills", int(sp.skill))
			var friends := int(skill.scope) in [7, 8, 9, 10, 11]
			var side: Array = logic.actors if (user is XActor) == friends else enemies
			logic.act(user, skill, side[int(sp.get("target", 0))])
		var reading := _reading(enemies, a, b)
		got.append(reading)
		if compare:
			_same_reading(step, reading, row)
			check(step + ".frames", XAlienBattle._formula_frames.is_empty() and XAlienBattle._action_frames.is_empty(),
				[XAlienBattle._formula_frames.size(), XAlienBattle._action_frames.size()])
	XAlienBattle.end(logic, -1)
	XState.current = null
	return got
