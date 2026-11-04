extends Node
## 混乱类状态（restriction 1～3）对照 tests/fixtures/confusion_oracle.json（mv_oracle/confusion_probe.cjs）：
## 敌人行动换成普通攻击、目标按等级走（1 对方／2 掷 randomInt(2) 选一侧／3 己方）、全体技能整侧存活者、随机数取用次数、
## 已倒下的人不会被选中、强制行动绕过、自动战斗保留技能只改目标、状态回合行动结束 -1、13 个状态的等级。
const FIXTURE := "res://tests/fixtures/confusion_oracle.json"
const STATES_ALL := [7, 8, 9, 124, 1045, 1113, 1567, 1830, 2046, 2504, 2505, 2506, 2580]
var results := []


## 按给定序列循环取值的随机流（每次取 1 个；float／int／mod 都按 [0,1) 比例映射），与参照探针的 Math.random 序列同用法
class SeqStream extends XRandomStream:
	var seq: Array = [0.5]
	var pos := 0
	func _next() -> float:
		var v := float(seq[pos % seq.size()])
		pos += 1
		draws += 1
		return v
	func next_float(_reason: String, _event_key := "") -> float:
		return _next()
	func next_uint(_reason: String, _event_key := "") -> int:
		return floori(_next() * 4294967296.0)
	func next_index_mod(n: int, _reason: String, _event_key := "") -> int:
		return floori(n * _next()) if n > 0 else 0
	func next_int_inclusive(lo: int, hi: int, _reason: String, _event_key := "") -> int:
		return lo + floori((hi - lo + 1) * _next())


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(700))


func _ready() -> void:
	_run.call_deferred()


func _battle(kill_second := false) -> XBattleLogic:
	var s := XState.new_game_blank()
	XState.current = s
	s.switches[2494] = true
	s.actor_max_level = 99
	for m in [1, 8, 9, 10]:
		s.add_actor(m)
	for m in s.battle_members():
		m.change_level(60)
		m.refresh_passive()
		m.recover_all()
	var l := XBattleLogic.new()
	var rand := XBattleRandom.create("0000000000000042")
	rand.rule = SeqStream.new()
	rand.rule.domain = "rule"
	l.setup(3, s, rand)
	for e in l.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e9
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
	l.start_turn()
	for b in l.actors + l.enemies:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	if kill_second:
		for b in [l.actors[1], l.enemies[1]]:
			b.hp = 0.0
			b.param_mark_dirty()
			b.param_refresh()
	return l


func _stream(l: XBattleLogic, seq: Array) -> SeqStream:
	var r: SeqStream = l.random.rule
	r.seq = seq
	r.pos = 0
	r.draws = 0
	return r


func _add(b, id: int, turns := 3) -> void:
	if not b.state_ids.has(id):
		b.state_ids.append(id)
	b.state_turns[id] = turns
	b.param_mark_dirty()
	b.param_refresh()


## [阵营, 序号]，与参照探针的 tag 一致（a＝我方、e＝敌方）
func _tag(l: XBattleLogic, b) -> Array:
	return ["a", l.actors.find(b)] if b is XActor else ["e", l.enemies.find(b)]


func _tags(l: XBattleLogic, list: Array) -> Array:
	return list.map(func(b): return _tag(l, b))


func _norm(v):
	return JSON.parse_string(JSON.stringify(v))


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("oracle", ref is Dictionary and ref.cases.size() == 53 and ref.cases.all(func(c): return (c.errors as Array).is_empty()))
	for c in ref.cases:
		var id := str(c.id)
		var o = c.observed
		if id == "states.flags":
			_states_flags(o)
		elif id.ends_with(".sweep"):
			_sweep(c)
		elif id.contains(".auto."):
			_auto(c)
		elif id.ends_with(".forceAction"):
			_force(c)
		elif id.ends_with(".noPreset") or id.contains(".preset."):
			_basic(c)
	_prepare_enemy()
	_act_flow(ref)
	_execute_paths()
	_enemy_decide()
	finish()


## 13 个状态：等级＝restriction、可行动、不是不能行动
func _states_flags(o: Array) -> void:
	for r in o:
		var l := _battle()
		var a: XActor = l.actors[0]
		_add(a, int(r.id))
		var want_level: int = int(r.actor[1])
		check("flags.%d.level" % int(r.id), XConfusion.level(a) == want_level and bool(r.actor[0]) == XConfusion.confused(a), [XConfusion.level(a), r.actor])
		check("flags.%d.can_move" % int(r.id), l.can_move(a) == bool(r.actor[2]), r.actor)
		l.end_battle(0)
	# 不能行动（restriction 4）不算混乱；活着才算
	var l2 := _battle()
	_add(l2.actors[0], 10)
	check("flags.stun_not_confused", not XConfusion.confused(l2.actors[0]))
	_add(l2.actors[1], 8)
	l2.actors[1].hp = 0.0
	check("flags.dead_not_confused", not XConfusion.confused(l2.actors[1]))
	l2.end_battle(0)


## noPreset／preset：固定随机下的目标与随机数取用次数（makeTargets 那一步）。敌人行动换成普通攻击
func _basic(c: Dictionary) -> void:
	var id := str(c.id)
	var o: Dictionary = c.observed
	var is_actor := id.begins_with("actor.")
	var l := _battle()
	var u = l.actors[0] if is_actor else l.enemies[0]
	_add(u, int(c.setup.state))
	var seq: Array = [0.5]
	if id.contains(".low."):
		seq = [0.0]
	elif id.contains(".high."):
		seq = [0.99]
	var rs := _stream(l, seq)
	var dec: Array = l.decide(u)
	if not is_actor:
		check(id + ".attack", dec[0] != null and int(dec[0].id) == 1, dec[0])
	var d0 := rs.draws
	var list := l.targets_for(u, dec[0] if dec[0] != null else u.attack_skill(), null, true)
	var want = o.makeTargets
	var skill_override: Dictionary = {}
	if c.setup.has("skill"):
		skill_override = XDB.rec("Skills", 1)  # 参照里被换成普通攻击（scope 1）
	check(id + ".targets", _norm(_tags(l, list)) == _norm(want.targets), [_tags(l, list), want.targets])
	check(id + ".draws", rs.draws - d0 == int(want.draws), [rs.draws - d0, want.draws])
	l.end_battle(0)


## 扫描：随机值 v／second 的序列，已倒下的 1 号不会被选中；敌人行动选择先取 1 个
func _sweep(c: Dictionary) -> void:
	var id := str(c.id)
	var is_actor := id.begins_with("actor.")
	for r in c.observed:
		var l := _battle(true)
		var u = l.actors[0] if is_actor else l.enemies[0]
		_add(u, int(c.setup.state))
		var rs := _stream(l, [r.v, r.second])
		var dec: Array = l.decide(u)
		var d0 := rs.draws
		var list := l.targets_for(u, dec[0] if dec[0] != null else u.attack_skill(), null, true)
		var tag := "%s.%s/%s" % [id, str(r.v), str(r.second)]
		check(tag + ".targets", _norm(_tags(l, list)) == _norm(r.r.targets), [_tags(l, list), r.r.targets])
		check(tag + ".draws", rs.draws - d0 == int(r.r.draws), [rs.draws - d0, r.r.draws])
		l.end_battle(0)


## 自动战斗：技能保持自动选的，目标走混乱；单体取一个，全体（scope 2）取整侧存活
func _auto(c: Dictionary) -> void:
	var id := str(c.id)
	var o: Dictionary = c.observed
	var skill := XDB.rec("Skills", int(o.skill))
	for r in o.runs:
		var l := _battle()
		var u: XActor = l.actors[0]
		_add(u, int(c.setup.state))
		var rs := _stream(l, [r.v, 0.3])
		var list := l.targets_for(u, skill, null, true)
		check("%s.%s.targets" % [id, str(r.v)], _norm(_tags(l, list)) == _norm(r.makeTargets.targets), [_tags(l, list), r.makeTargets.targets])
		check("%s.%s.draws" % [id, str(r.v)], rs.draws == int(r.makeTargets.draws), [rs.draws, r.makeTargets.draws])
		l.end_battle(0)


## 强制行动绕过混乱：不改目标，不掷随机数
func _force(c: Dictionary) -> void:
	var id := str(c.id)
	var is_actor := id.begins_with("actor.")
	var l := _battle()
	var u = l.actors[0] if is_actor else l.enemies[0]
	_add(u, 8)
	var rs := _stream(l, [0.5])
	var skill := XDB.rec("Skills", 2)
	var list := l.targets_for(u, skill, u, false)
	check(id + ".targets", _norm(_tags(l, list)) == _norm(c.observed.makeTargets.targets) or list == [u], _tags(l, list))
	check(id + ".no_confusion_draw", rs.draws == 0, rs.draws)
	l.end_battle(0)


func _prepare_enemy() -> void:
	var l := _battle()
	var e: XEnemy = l.enemies[0]
	var sk8 := XDB.rec("Skills", 8)
	check("prepare.plain_unchanged", XConfusion.prepare_enemy(e, [sk8, null])[0] == sk8)
	_add(e, 8)
	var got := XConfusion.prepare_enemy(e, [sk8, null])
	check("prepare.to_attack", int(got[0].id) == 1 and got[1] == null, got)
	check("prepare.no_action_stays", XConfusion.prepare_enemy(e, [null, null])[0] == null)
	l.end_battle(0)


## act 整条链：被混乱的敌人／角色打到的人对上参照；状态回合行动结束 -1（3→2）
func _act_flow(ref: Dictionary) -> void:
	for c in ref.cases:
		var id := str(c.id)
		if not (id.ends_with(".mid.noPreset") and int(c.setup.state) in [7, 8, 9]):
			continue
		var o: Dictionary = c.observed
		var is_actor := id.begins_with("actor.")
		var l := _battle()
		var u = l.actors[0] if is_actor else l.enemies[0]
		_add(u, int(c.setup.state))
		var before := {}
		for b in l.actors + l.enemies:
			before[b] = b.hp
		_stream(l, [0.5])
		var dec: Array = l.decide(u)
		l.act(u, dec[0], dec[1])
		var hit := []
		for b in l.actors + l.enemies:
			if b != u and b.hp != before[b]:
				hit.append(_tag(l, b))
		var want := []
		for t in o.applied:
			if t != _tag(l, u):
				want.append(t)
		check(id + ".act_hit", _norm(hit) == _norm(want), [hit, want])
		var turns_after := int(u.state_turns.get(int(c.setup.state), -1))
		check(id + ".act_state_turns", turns_after == int(o.statesAfter[0][1]), [turns_after, o.statesAfter])
		l.end_battle(0)


func _hits(l: XBattleLogic, logs: Array, user) -> Array:
	var hit := []
	for e in logs:
		if e is Dictionary and str(e.get("type", "")) == "hit" and e.target != user:
			hit.append(_tag(l, e.target))
	return hit


## execute（行动序列路径）：非强制走混乱（魅惑角色打我方），强制不走（打指定的敌人）
func _execute_paths() -> void:
	_battle().end_battle(0)  # 先载入数据表
	# 正式数据里每个技能都带行动序列（连物品里也没有单体敌方的非序列项），普通路径只有同样的 targets_for 调用，不另测
	for sk in [XDB.rec("Skills", 1)]:
		var tag := "exec.%d" % int(sk.get("id", 0))
		for forcing in [false, true]:
			var l := _battle()
			var u: XActor = l.actors[0]
			_add(u, 9)
			_stream(l, [0.5])
			var hit := _hits(l, l.execute(u, sk, l.enemies[0], forcing), u)
			if forcing:
				check(tag + ".forced_goes_to_chosen", hit == [["e", 0]], hit)
			else:
				check(tag + ".confused_hits_own_side", not hit.is_empty() and hit.all(func(t): return t[0] == "a"), hit)
			l.end_battle(0)


## decide 层：敌人本来出别的技能，混乱后换成普通攻击（敌人行动表临时换成只有 8 号技能）
func _enemy_decide() -> void:
	var l := _battle()
	var e: XEnemy = l.enemies[0]
	var d := e.data()
	var old = d.actions
	d.actions = [{"skillId": 8, "rating": 5, "conditionType": 0, "conditionParam1": 0, "conditionParam2": 0}]
	_stream(l, [0.5])
	var plain_dec: Array = l.decide(e)
	check("decide.unconfused_keeps_skill", plain_dec[0] != null and int(plain_dec[0].id) == 8, plain_dec[0])
	_add(e, 8)
	var dec: Array = l.decide(e)
	check("decide.confused_attack", dec[0] != null and int(dec[0].id) == 1, dec[0])
	d.actions = old
	l.end_battle(0)


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=", JSON.stringify({"name": "xiyou_confusion", "passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
