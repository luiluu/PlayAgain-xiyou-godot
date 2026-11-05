extends Node
## 【cc·weak1·未经审查】弱者挑战一期（XWeakChallenge）与 mv_oracle/weak_challenge_probe.cjs 的冻结 v0.28 参照
## （generated/oracle/weak_challenge.json）逐例比：弱者分类、新局开／关全局标记时 10357 与八项属性、承伤率、HP／MP 回满、
## 试学 10357；存读档后按本局标记学／忘；弱者 2 号普攻敌群 3 与敌人普攻 2 号的伤害（随机数 0.5）；最终战（Map157 敌群 469、混沌）
## 十种情形的本局／全局标记、成就 142、全员学技能；通关后新局弱者带技能回满。最后验回退开关 ENABLED=false 回到移植前。
const ORACLE := "oracle/weak_challenge.json"
const DIR := "user://test_weak_challenge"
const KEY := "codexWeakFiveClearV2"
var results := []


class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648
	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		_take("uint32", reason, event_key)
		return lo + floori((hi - lo + 1) * value)


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XSave.dir_override = DIR
	XConfig.path_override = ""
	XAchievement.time_override = "2026年1月1日 0:0:0"
	var popup_sound := str(XAchievementPopup.settings().get("Popup Sound", ""))
	XSound._cache[popup_sound] = null
	var d = JSON.parse_string(FileAccess.get_file_as_string(XDB.BASE + ORACLE))
	if not check("oracle", d is Dictionary and d.cases.size() >= 20 and d.cases.all(func(c): return c.errors.is_empty()), ORACLE):
		finish()
		return
	for c in d.cases:
		var id := str(c.id)
		if id == "classify":
			_classify(c)
		elif id.begins_with("newgame."):
			_newgame(c)
		elif id.begins_with("load."):
			_load(c)
		elif id.begins_with("damage."):
			_damage(c)
		elif id.begins_with("final."):
			_final(c, c.setup)
		elif id == "after.newgame":
			_after(c)
		elif id.begins_with("help."):
			_help(c)
		elif id == "battle.sync":
			_battle_sync(c)
	var by_id := {}
	for c in d.cases:
		by_id[str(c.id)] = c
	_rollback(by_id)
	XState.current = null
	XWeakChallenge.ENABLED = true
	finish()


## 同探针 newGame(clear)：全局配置标记、成就清空、难度取初始、队伍 1／8／9／10
func _new_game(clear: bool) -> XState:
	XConfig.set_flag(KEY, clear)
	var g := XConfig.achievements()
	g.erase("142")
	g.erase("142Time")
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8, 9, 10])
	XState.current = s
	return s


static func _num(v) -> float:
	return snappedf(float(v), 0.000001)


func _snap(a: XActor) -> Dictionary:
	a.param_mark_dirty()
	a.param_refresh()
	return {"id": a.actor_id, "learned": a.skill_ids.has(XWeakChallenge.SKILL), "param": range(8).map(func(i): return _num(a.param(i))),
		"pdr": _num(a.sparam(6)), "mdr": _num(a.sparam(7)), "hp": _num(a.hp), "mhp": _num(a.mhp), "mp": _num(a.mp), "mmp": _num(a.mmp)}


static func _want_snap(r: Dictionary) -> Dictionary:
	return {"id": int(r.id), "learned": bool(r.learned), "param": (r.param as Array).map(func(v): return _num(v)),
		"pdr": _num(r.pdr), "mdr": _num(r.mdr), "hp": _num(r.hp), "mhp": _num(r.mhp), "mp": _num(r.mp), "mmp": _num(r.mmp)}


func _rows(name: String, s: XState, want: Array) -> void:
	for r in want:
		var got := _snap(s.actor(int(r.id)))
		check("%s.a%d" % [name, int(r.id)], got == _want_snap(r), [got, r])


func _flags(name: String, s: XState, want: Dictionary) -> void:
	var got := {"config": XConfig.flag(KEY), "system": s.flags.get(XWeakChallenge.FLAG) == true,
		"acGlobal": XAchievement.global_has(142), "acParty": XAchievement.party_has(s, 142)}
	var w := {"config": bool(want.config), "system": bool(want.system), "acGlobal": bool(want.acGlobal), "acParty": bool(want.acParty)}
	check(name + ".flags", got == w, [got, w])


func _classify(c: Dictionary) -> void:
	_new_game(false)
	var weak: Array = (c.observed.weak as Array).map(func(v): return int(v))
	var strong: Array = (c.observed.strong as Array).map(func(v): return int(v))
	var bad := []
	var seen := 0
	for id in weak + strong:
		if XDB.rec("Actors", id).is_empty():
			continue
		seen += 1
		var a := XActor.new().setup(id)
		if XWeakChallenge.is_weak(a) != weak.has(id):
			bad.append(id)
	check("classify", bad.is_empty() and seen >= 150, [bad, seen])


func _newgame(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_game(bool(c.setup.clear))
	for id in c.setup.join:
		s.add_actor(int(id))
	_flags(c.id, s, o.flags)
	_rows(c.id, s, o.rows)
	for id_s in o.learn:
		var a := s.actor(int(id_s))
		a.forget_skill(XWeakChallenge.SKILL)
		a.learn_skill(XWeakChallenge.SKILL)
		check("%s.learn%s" % [c.id, id_s], a.skill_ids.has(XWeakChallenge.SKILL) == bool(o.learn[id_s]), [id_s, o.learn[id_s]])


func _load(c: Dictionary) -> void:
	var st: Dictionary = c.setup
	var s := _new_game(bool(st.clear))
	s.add_actor(2)
	s.actor(2).hp = 1.0
	if bool(st.system):
		s.flags[XWeakChallenge.FLAG] = true
	else:
		s.flags.erase(XWeakChallenge.FLAG)
	var dump := JSON.stringify(s.to_dict())
	XConfig.set_flag(KEY, bool(st.config))
	var loaded := XState.from_dict(JSON.parse_string(dump))
	XState.current = loaded
	_flags(c.id, loaded, c.observed.flags)
	_rows(c.id, loaded, c.observed.rows)


func _damage(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var s := _new_game(bool(c.setup.clear))
	s.party.clear()
	s.battle_slots.clear()
	for id in c.setup.party:
		s.add_actor(int(id))
	for id in s.party:
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
	var rand := XBattleRandom.create("0000000000000001")
	rand.rule = FixedStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(int(c.setup.troop), s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	logic.start_turn()
	var a: XActor = s.actor(2)
	var e: XEnemy = logic.enemies[0]
	var members := logic.actors.map(func(b): return b.actor_id)
	check(c.id + ".members", members == (o.members as Array).map(func(x): return int(x)), [members, o.members])
	var got := _snap(a)
	check(c.id + ".a", got == _want_snap(o.a), [got, o.a])
	var ep := range(8).map(func(i): return _num(e.param(i)))
	check(c.id + ".e", ep == (o.e as Array).map(func(v): return _num(v)), [ep, o.e])
	a.mp = a.mmp
	a.tp = a.max_tp()
	var hits := []
	for pair in [[a, e], [e, a]]:
		for l in logic.act(pair[0], XDB.rec("Skills", 1), pair[1]):
			if l.get("type") == "hit" and l.get("user") == pair[0] and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)):
				hits.append([_num(l.hp), bool(l.critical)])
	var want := (o.log as Array).map(func(l): return [_num(l.value), bool(l.critical)])
	check(c.id + ".damage", hits == want, [hits, want])


func _final(c: Dictionary, st: Dictionary) -> XState:
	var o: Dictionary = c.observed
	var s := _new_game(false)
	s.difficulty = int(st.difficulty)
	s.party.clear()
	s.battle_slots.clear()
	for id in st.party:
		s.add_actor(int(id))
	s.map_id = 157
	if bool(st.get("already", false)):
		s.achievements["142"] = true
	var rand := XBattleRandom.create("0000000000000001")
	rand.rule = FixedStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(int(st.get("troop", 469)), s, rand)
	if st.has("visit"):
		s.add_actor(int(st.visit))
		s.remove_actor(int(st.visit))
	if st.has("leave"):
		s.remove_actor(int(st.leave))
	if st.has("back"):
		s.add_actor(int(st.back))
	if st.has("swap"):
		for id in st.swap:
			s.battle_slots[4] = int(id)
			s.rearrange_actors()
	if st.has("diff"):
		for n in st.diff:
			XDungeon.set_difficulty(s, int(n), null)
	if st.has("dead"):
		s.actor(int(st.dead)).add_new_state(1)
	if int(st.result) == 0:
		for e in logic.enemies:
			e.add_new_state(1)
	var members := s.battle_members().map(func(b): return b.actor_id)
	if o.has("members"):
		check(c.id + ".members", members == (o.members as Array).map(func(x): return int(x)), [members, o.members])
	logic.end_battle(int(st.result))
	if o.has("learned"):
		_flags(c.id, s, o.flags)
		var got := (st.party as Array).map(func(id): return [int(id), s.actor(int(id)).skill_ids.has(XWeakChallenge.SKILL)])
		var want := (o.learned as Array).map(func(r): return [int(r[0]), bool(r[1])])
		check(c.id + ".learned", got == want, [got, want])
	return s


func _after(c: Dictionary) -> void:
	_final({"id": "after.final", "observed": {}}, {"party": [2, 3, 4, 5, 6], "difficulty": 9, "result": 0})
	var cleared := XConfig.flag(KEY)
	var g := XConfig.achievements()
	g.erase("142")
	g.erase("142Time")
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8, 9, 10])
	XState.current = s
	check("after.cleared", cleared, cleared)
	s.add_actor(2)
	_flags(c.id, s, c.observed.flags)
	_rows(c.id, s, c.observed.rows)


## 二期：说明卡行（文字、字号、颜色、对齐，与 xiyou_help_card 同口径；战力行参照没有就不比）
func _help(c: Dictionary) -> void:
	_new_game(bool(c.setup.clear))
	XState.current.difficulty = 3
	var got := XHelpCard.content(XDB.rec("Skills", int(c.setup.skill)), "")
	var want: Array = c.observed.rows
	if not want.any(func(r): return str(r[0]).begins_with("战力")):
		got = got.filter(func(r): return not str(r[0]).begins_with("战力"))
	var g := got.map(func(r): return [str(r[0]), int(r[1]), str(r[2]), null if r[4] == null else int(r[4])])
	var w := want.map(func(r): return [str(r[0]), int(r[1]), str(r[2]), null if r[4] == null else int(r[4])])
	check(c.id + ".rows", g == w, [g, w])


func _battle_sync(c: Dictionary) -> void:
	var s := _new_game(true)
	s.add_actor(2)
	var a := s.actor(2)
	a.forget_skill(XWeakChallenge.SKILL)
	a.refresh_passive()
	a.param_refresh()
	a.hp = 1.0
	a.mp = minf(a.mp, a.mmp)  # 探针 setHp(1) 走 Game_Battler.refresh，MP 夹回忘掉后的上限
	var got := _snap(a)
	check(c.id + ".before", got == _want_snap(c.observed.before), [got, c.observed.before])
	var logic := XBattleLogic.new()
	logic.setup(3, s)
	got = _snap(a)
	check(c.id + ".after", got == _want_snap(c.observed.after), [got, c.observed.after])


## 回退：ENABLED=false 时标记开着也不发 10357、承伤与终伤不变，最终战胜利不给成就（移植前的样子）
## 零影响：全局标记开着、ENABLED=false 时，新局与伤害逐项等于参照的「关」支；试学 10357 不拦（移植前谁都能学）；
## 带着本局标记与已学技能的存档读进来：没学的不补、学了的不忘，但承伤率、终伤不变；最终战胜利不写任何标记；说明卡原样。
func _rollback(by_id: Dictionary) -> void:
	XWeakChallenge.ENABLED = false
	for pair in [["newgame.on", "newgame.off"], ["damage.on", "damage.off"]]:
		var c: Dictionary = by_id[pair[0]].duplicate(true)
		c.id = "rollback." + str(pair[0])
		var off: Dictionary = by_id[pair[1]].observed.duplicate(true)
		if pair[0] == "newgame.on":
			off.flags.config = true  # 全局标记本身照写（只是没人读）
			for k in off.learn:
				off.learn[k] = true
		c.observed = off
		if pair[0] == "newgame.on":
			_newgame(c)
		else:
			_damage(c)
	var sl := _new_game(true)
	sl.add_actor(2)
	sl.add_actor(3)
	sl.actor(3).learn_skill(XWeakChallenge.SKILL)
	sl.flags[XWeakChallenge.FLAG] = true
	var loaded := XState.from_dict(JSON.parse_string(JSON.stringify(sl.to_dict())))
	XState.current = loaded
	var a3 := loaded.actor(3)
	check("rollback.load", not loaded.actor(2).skill_ids.has(XWeakChallenge.SKILL) and a3.skill_ids.has(XWeakChallenge.SKILL), [loaded.actor(2).skill_ids, a3.skill_ids])
	check("rollback.load.pdr", is_equal_approx(a3.sparam(6), 1.0) and is_equal_approx(a3.sparam(7), 1.0), [a3.sparam(6), a3.sparam(7)])
	check("rollback.load.ops", XWeakChallenge.damage_ops(a3).is_empty(), XWeakChallenge.damage_ops(a3))
	var rec := XDB.rec("Skills", XWeakChallenge.SKILL)
	check("rollback.help", XWeakChallenge.quality_label(rec, "品质：传说") == "品质：传说", XWeakChallenge.quality_label(rec, "品质：传说"))
	var s := _new_game(true)
	s.add_actor(2)
	var a := s.actor(2)
	check("rollback.no_skill", not a.skill_ids.has(XWeakChallenge.SKILL) and not s.flags.has(XWeakChallenge.FLAG), a.skill_ids)
	check("rollback.pdr", is_equal_approx(a.sparam(6), 1.0), a.sparam(6))
	XConfig.set_flag(KEY, false)
	_final({"id": "rollback.final", "observed": {}}, {"party": [2, 3, 4, 5, 6], "difficulty": 9, "result": 0})
	check("rollback.final", not XConfig.flag(KEY) and not XAchievement.global_has(142) and XWeakChallenge.final_battle == null,
		[XConfig.flag(KEY), XAchievement.global_has(142), XWeakChallenge.final_battle])
	XWeakChallenge.ENABLED = true
	# 开着时说明卡包装只认 10357＋标签（品质表改了也写神话），别的技能原样
	check("help.label", XWeakChallenge.quality_label(rec, "品质：传说") == "品质：神话"
		and XWeakChallenge.quality_label(XDB.rec("Skills", 10356), "品质：传说") == "品质：传说", null)


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
