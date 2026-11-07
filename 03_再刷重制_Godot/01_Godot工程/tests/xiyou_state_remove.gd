extends Node
## 受伤解除与受限解除（审查报告第 8、9 项），对照 tests/fixtures/state_remove_oracle.json（mv_oracle/state_remove_probe.cjs）：
## - 第 8 项：正 HP 伤害后，带 removeByDamage 的状态（15 个，睡眠、眩晕等）按 states() 顺序各掷一次 randomInt(100) < chanceByDamage 就解除；
##   伤害 0 或回复不掷。原版这条照常生效，重制漏了（逐例比参照）。
## - 第 9 项：addNewState 从「未受限」变「受限」时 onRestrict 去掉 removeByRestriction 的状态（防御 2／170／235、凌波舞 525、鸣贝 569／580）。
##   原版 krz_state_re 的 states() 缓存让加状态后的 isRestricted 读到旧值，onRestrict 从不触发（参照里全是「没去掉」），
##   O-待定-3 `XBattler.FIX_RESTRICT_REMOVE` 默认修成触发；关着时逐例比参照。已受限时这些状态加不上（isStateRestrict），原版照常生效、不挂开关。
const FIXTURE := "res://tests/fixtures/state_remove_oracle.json"
var results := []


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


func _battle() -> XBattleLogic:
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
	for b in l.actors + l.enemies:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
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
		b._sort_states()
	b.state_turns[id] = turns
	b.param_mark_dirty()
	b.param_refresh()


func _sorted(a: Array) -> Array:
	var out := a.map(func(v): return int(v))
	out.sort()
	return out


func _unit(l: XBattleLogic, side: String) -> XBattler:
	return l.actors[0] if side == "actor" else l.enemies[0]


func _foe(l: XBattleLogic, side: String) -> XBattler:
	return l.enemies[0] if side == "actor" else l.actors[0]


## 一次 HP 伤害：execute_hp_damage（与原版 executeHpDamage 同一层）
func _hit(l: XBattleLogic, side: String, value: float, seq: Array) -> Dictionary:
	var t := _unit(l, side)
	var ctx := l._new_lifecycle_resources()
	l._action_resources = ctx
	var rs := _stream(l, seq)
	l.execute_hp_damage(_foe(l, side), t, value, false)
	l._action_resources = null
	return {"draws": rs.draws, "states": _sorted(t.state_ids), "removed": _sorted(ctx.result(t).removedStates)}


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("oracle", ref is Dictionary and ref.cases.size() == 106 and ref.cases.all(func(c): return (c.errors as Array).is_empty()))
	var census: Dictionary = ref.cases[0].observed
	_census(census)
	XBattler.FIX_RESTRICT_REMOVE = false  # 参照是原版：O-待定-3 关着逐例比
	for c in ref.cases:
		var id := str(c.id)
		if id.begins_with("damage."):
			_damage(c)
		elif id.begins_with("restrict."):
			_restrict(c)
	XBattler.FIX_RESTRICT_REMOVE = true
	_restrict_fixed(census)
	_change_state_tag()
	finish()


## 数据普查与参照一致（15 个受伤解除、6 个受限解除）
func _census(o: Dictionary) -> void:
	var dmg := []
	var res := []
	for st in XDB.table("States"):
		if not st is Dictionary or st.is_empty():
			continue
		if bool(st.get("removeByDamage", false)):
			dmg.append([int(st.id), int(st.chanceByDamage), int(st.restriction)])
		if bool(st.get("removeByRestriction", false)):
			res.append([int(st.id), int(st.restriction)])
	check("census.damage", dmg == _ints(o.damage) and dmg.size() == 15, [dmg, o.damage])
	check("census.restriction", res == _ints(o.restriction), [res, o.restriction])


func _ints(rows: Array) -> Array:
	return rows.map(func(r): return (r as Array).map(func(v): return int(v)))


func _damage(c: Dictionary) -> void:
	var id := str(c.id)
	var parts := id.split(".")
	var side := parts[1]
	var l := _battle()
	var t := _unit(l, side)
	var value := 100.0
	var seq: Array = [float(c.setup.get("v", 0.0))]
	if parts[2].contains("+"):
		_add(t, 10)
		_add(t, 742)
		seq = c.setup.seq
	else:
		_add(t, int(parts[2]))
		if parts.size() > 3 and parts[3].begins_with("value"):
			value = float(c.setup.value)
			seq = [0.0]
	var got := _hit(l, side, value, seq)
	var o: Dictionary = c.observed
	check(id + ".states", got.states == _sorted(o.states), [got, o])
	check(id + ".removed", got.removed == _sorted(o.removed), [got, o])
	check(id + ".draws", got.draws == int(o.draws), [got, o])
	l.end_battle(0)


## 原版：pre 先挂好，再 addState(add)
func _restrict_run(side: String, pre: Array, add: int, then_remove := 0) -> Dictionary:
	var l := _battle()
	var b := _unit(l, side)
	for p in pre:
		if int(p) == 2:
			b.guarding = true  # 防御指令：重制用 guarding 代替原版的防御状态 2
		else:
			_add(b, int(p))
	var ctx := l._new_lifecycle_resources()
	l._action_resources = ctx
	var rs := _stream(l, [0.5])
	ctx.add_state(b, add)
	var out := {"states": _sorted(b.state_ids), "guard": b.is_guard(), "removed": _sorted(ctx.result(b).removedStates), "draws": rs.draws, "restricted": b.is_restricted()}
	if then_remove > 0:
		b.remove_state(then_remove)
		out.after_guard = b.is_guard()
	l._action_resources = null
	l.end_battle(0)
	return out


## 参照的状态表把防御 2 写进 states；重制的防御是 guarding，比较时把 2 换成 guard 标记
func _strip2(a: Array) -> Array:
	return _sorted(a.filter(func(v): return int(v) != 2))


func _restrict(c: Dictionary) -> void:
	var id := str(c.id)
	var side: String = c.setup.side
	var pre: Array = c.setup.pre
	var add := int(c.setup.add)
	var o: Dictionary = c.observed
	var got := _restrict_run(side, pre, add, 10 if id.ends_with("thenRemove10") else 0)
	check(id + ".states", _strip2(got.states) == _strip2(o.states), [got, o])
	check(id + ".removed", got.removed == _strip2(o.removed), [got, o])
	# 原版加完状态后 isGuard 读缓存；重制 is_guard 看 canMove，晕住时为假（原版重算后同样为假），只比没晕住的
	if not got.states.has(10):
		check(id + ".guard", got.guard == bool(o.guard), [got, o])
	if o.has("afterRemove"):
		check(id + ".after_remove_guard", got.after_guard == bool(o.afterRemove.guard), [got, o])
	# 已受限时 removeByRestriction 的状态加不上、不掷回合数
	if pre.has(8.0) and add in [2, 525]:
		check(id + ".not_addable", got.states == _sorted(o.states) and got.draws == int(o.draws), [got, o])


## O-待定-3 开：第一次受限时去掉 removeByRestriction 的状态、防御失效；已受限再加不触发；普通状态不触发
func _restrict_fixed(census: Dictionary) -> void:
	for side in ["actor", "enemy"]:
		for row in census.restriction:
			var r := int(row[0])
			for add in [10, 8, 7]:
				var tag := "fixed.%s.%d+%d" % [side, r, add]
				var got := _restrict_run(side, [r], add)
				check(tag + ".removed", not got.states.has(r) and got.states.has(add) and (r == 2 or got.removed.has(r)), got)
				check(tag + ".no_guard", not got.guard, got)
		var g := _restrict_run(side, [2], 10, 10)
		check("fixed.%s.guard_gone_after_wake" % side, not g.after_guard, g)
		var k := _restrict_run(side, [8, 525], 10)
		check("fixed.%s.already_restricted_keeps" % side, k.states.has(525), k)
		var n := _restrict_run(side, [2, 525], 3)
		check("fixed.%s.plain_state_keeps" % side, n.guard and n.states.has(525), n)


## StateChangeIfRemove「SC受伤解除」：受伤解除后换状态、不弹「解除」（数据里没有这种标签，临时给睡眠 10 写一条验证通路）
func _change_state_tag() -> void:
	var st := XDB.rec("States", 10)
	var meta: Dictionary = st.get("meta", {})
	var had := meta.duplicate()
	meta["SC受伤解除"] = "1329"
	st["meta"] = meta
	var l := _battle()
	var t := _unit(l, "enemy")
	_add(t, 10)
	var got := _hit(l, "enemy", 100.0, [0.0])
	check("sc.damage_changes", got.states.has(1329) and not got.states.has(10) and not got.removed.has(10), got)
	l.end_battle(0)
	st["meta"] = had
	# 行动限制解除的 SC 标签：onRestrict 在 addState 里面，_Fix_StackOverflow 的全局锁挡住嵌套 addState，换不上（与原版锁一致；数据里也没有这种标签）

func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=", JSON.stringify({"name": "xiyou_state_remove", "passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
