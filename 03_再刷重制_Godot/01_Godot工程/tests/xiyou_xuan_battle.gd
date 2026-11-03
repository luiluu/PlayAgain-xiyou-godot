extends Node
## 璇战斗效果第一期（XXuanBattle）对原版参照 tests/fixtures/xuan_battle_oracle.json（mv_oracle/xuan_battle_probe.cjs）：
## 净化口径全表、MP 费用、回光（治疗、净化、余辉实测不生效）、定星、璃壁、棱光、蚀辉、未绑定的技能条件、战斗结束清标记。随机固定 0.5，开第一回合。
const FIXTURE := "res://tests/fixtures/xuan_battle_oracle.json"
const XUAN := 177
const ALLY := 1
const HARD := 10
const HARD2 := 8
var checks := 0
var failures: Array = []


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


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 30:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(600))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameApp.fast_headless_frames()
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("source", f.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	check("complete", f.cases.size() == 37, f.cases.size())
	for c in f.cases:
		check(c.id + ".oracle", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		call("_c_" + kind, c)
	var passed := checks - failures.size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": checks}))
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)


func _setup(level := 60, marks := {}) -> Dictionary:
	var s := XState.new_game_blank()
	XState.current = s
	s.switches[2494] = true
	s.actor_max_level = 99
	s.add_actor(XUAN)
	s.add_actor(ALLY)
	var a: XActor = s.actor(XUAN)
	a.change_level(level)
	var chart := XTusuXuan.chart(s)
	for m in marks:
		chart.level[m] = int(marks[m])
		chart.slots[XTusuXuan.SLOT_OF[m]] = m
	XTusuXuan.sync_marks(s, a)
	a.recover_all()
	var stream := FixedStream.new()
	stream.domain = "rule"
	var rand := XBattleRandom.create("0000000000000177")
	rand.rule = stream
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	logic.start_turn()
	var t: XActor = s.actor(ALLY)
	t.recover_all()
	return {"s": s, "logic": logic, "a": a, "t": t, "e": logic.enemies[0]}


func _use(c: Dictionary, key: String, target: XBattler) -> Dictionary:
	return c.logic.apply(c.a, XDB.rec("Skills", XTusuXuan.skill_id(XUAN, key)), target)


func _close(a, b) -> bool:
	return absf(float(a) - float(b)) < 1e-5


func _ints(list) -> Array:
	return list.map(func(v): return int(v))


func _states(b: XBattler) -> Array:
	return b.states().map(func(st): return int(st.id))


func _c_cleanse(c: Dictionary) -> void:
	var hard := []
	var soft := []
	for st in XDB.table("States"):
		if st is Dictionary:
			if XXuanBattle.is_cleanse_state(st, true):
				hard.append(int(st.id))
			if XXuanBattle.is_cleanse_state(st, false):
				soft.append(int(st.id))
	check("cleanse.hard", hard == _ints(c.observed.hard), [c.observed.hard.size(), hard.size()])
	check("cleanse.soft", soft == _ints(c.observed.soft), [c.observed.soft.size(), soft.size()])


func _c_mp(c: Dictionary) -> void:
	var r := _setup(int(c.setup.level))
	var o: Dictionary = c.observed
	check(c.id + ".mmp", _close(r.a.mmp, o.mmp), [o.mmp, r.a.mmp])
	for k in ["huiguang", "libi", "lengguang", "liexing", "jixing"]:
		var cost: int = XXuanBattle.mp_cost(r.a, XDB.rec("Skills", XTusuXuan.skill_id(XUAN, k)), 0)
		check("%s.%s" % [c.id, k], cost == int(o[k]), [o[k], cost])
	check(c.id + ".attack", XXuanBattle.mp_cost(r.a, XDB.rec("Skills", 1), 0) == int(o.attack))


func _c_huiguang(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	if str(c.id) == "huiguang.self":
		var q := _setup(60, {"yuhui": 3})
		var h: Dictionary = _use(q, "huiguang", q.a)
		check(c.id + ".hp", float(h.hp) == float(o.hp), [o.hp, h.hp])
		check(c.id + ".after", _close(q.a.hp, o.after), [o.after, q.a.hp])
		check(c.id + ".shield", XShieldLedger.rows(q.a).is_empty())
		return
	var r := _setup(int(c.setup.level), c.setup.marks)
	r.t.hp = maxf(1.0, floorf(r.t.mhp * float(c.setup.hurt)))
	var hit: Dictionary = _use(r, "huiguang", r.t)
	check(c.id + ".mat", _close(r.a.mat, o.mat), [o.mat, r.a.mat])
	check(c.id + ".before", true)
	check(c.id + ".hp", float(hit.hp) == float(o.hp), [o.hp, hit.hp])
	check(c.id + ".after", _close(r.t.hp, o.after), [o.after, r.t.hp])
	check(c.id + ".shield", XShieldLedger.rows(r.t).size() == o.shields.size(), XShieldLedger.rows(r.t))
	check(c.id + ".mark", XXuanChart.mark_level(r.s, r.a, str(c.setup.marks.keys()[0])) == int(o.markLevel))


func _c_dingxing(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var id := str(c.id)
	if id in ["dingxing.resist_effect", "dingxing.resist_direct", "dingxing.effect_line", "dingxing.benched"]:
		_c_dingxing_extra(c)
		return
	if id == "dingxing.expired":
		var q := _setup(60, {"dingxing": 2})
		q.logic._state_add(q.t, HARD)
		_use(q, "huiguang", q.t)
		XXuanBattle.data.dingxing[ALLY].until = XBinding.current_round() - 1
		q.t.runtime_result = XResourceContext.empty_result()  # 同参照 clearResult：本次结果里刚移除的状态加不上
		q.logic._state_add(q.t, HARD)
		check(id + ".stun", q.t.state_ids.has(HARD) == bool(o.stun), q.t.state_ids)
		check(id + ".mark", q.t.state_ids.has(XXuanBattle.state_id("dingxing")) == bool(o.mark))
		check(id + ".guard", XXuanBattle.data.dingxing.has(ALLY) == bool(o.guard))
		return
	if id == "dingxing.enemy_user":
		var q := _setup(60, {"dingxing": 2})
		q.logic._state_add(q.t, HARD)
		q.logic.apply(q.t, XDB.rec("Skills", 1), q.e)
		check(id + ".guard", XXuanBattle.data.dingxing.has(ALLY) == bool(o.guard))
		check(id + ".stun", q.t.state_ids.has(HARD) == bool(o.stun))
		return
	if id == "dingxing.two_hard":
		var q := _setup(60, {"dingxing": 2})
		q.logic._state_add(q.t, HARD2)
		q.logic._state_add(q.t, HARD)
		check(id + ".order", _states(q.t) == _ints(o.order), [o.order, _states(q.t)])
		_use(q, "huiguang", q.t)
		check(id + ".after", _states(q.t) == _ints(o.after), [o.after, _states(q.t)])
		return
	if id == "dingxing.self":
		var q := _setup(60, {"dingxing": 2})
		q.logic._state_add(q.a, HARD)
		_use(q, "huiguang", q.a)
		check(id + ".guard", XXuanBattle.data.dingxing.has(XUAN))
		check(id + ".mark", q.a.state_ids.has(XXuanBattle.state_id("dingxing")) == bool(o.mark))
		q.a.runtime_result = XResourceContext.empty_result()
		q.logic._state_add(q.a, HARD)
		check(id + ".blocked", not q.a.state_ids.has(HARD) == bool(o.blocked))
		return
	var r := _setup(60, c.setup.marks)
	if bool(c.setup.liexing):
		XXuanBattle.data.liexingUntil = XBinding.current_round() + 1
	r.logic._state_add(r.t, HARD)
	r.logic._state_add(r.t, 5)
	check(id + ".before", _states(r.t) == _ints(o.beforeStates), [o.beforeStates, _states(r.t)])
	_use(r, "huiguang", r.t)
	check(id + ".after", _states(r.t) == _ints(o.after), [o.after, _states(r.t)])
	var guard = XXuanBattle.data.dingxing.get(ALLY)
	check(id + ".guard", (guard == null) == (o.guard == null), [o.guard, guard])
	if guard != null and o.guard != null:
		check(id + ".until", int(guard.until) == int(o.guard.until) and bool(guard.numeric) == bool(o.guard.numeric), [o.guard, guard])
	r.t.runtime_result = XResourceContext.empty_result()
	r.logic._state_add(r.t, 6)
	check(id + ".soft", r.t.state_ids.has(6) == bool(o.softOn))
	r.logic._state_add(r.t, HARD)
	check(id + ".blocked", (not r.t.state_ids.has(HARD)) == bool(o.blocked), r.t.state_ids)
	check(id + ".markAfter", r.t.state_ids.has(XXuanBattle.state_id("dingxing")) == bool(o.markAfter))


## 审查 33 P3-3／P3-4：抗性挡下的硬控也先消耗定星（技能附加、事件直接加），挡下不写台词，璇下场后不挡
func _c_dingxing_extra(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var id := str(c.id)
	var q := _setup(60, {"dingxing": 2})
	q.logic._state_add(q.t, HARD)
	_use(q, "huiguang", q.t)
	XXuanBattle.take_logs()
	q.t.runtime_result = XResourceContext.empty_result()
	var traits: Array = XDB.rec("Actors", ALLY).traits
	var resist := {"code": XBattler.TRAIT_STATE_RESIST, "dataId": HARD, "value": 1.0}
	if id.begins_with("dingxing.resist"):
		traits.append(resist)
		q.t.param_mark_dirty()
		check(id + ".resists", q.t.traits_set(XBattler.TRAIT_STATE_RESIST).has(HARD))
	if id == "dingxing.resist_effect" or id == "dingxing.effect_line":
		# 敌人技能的状态附加（itemEffectAddNormalState，必中、100%）
		var sk := XDB.rec("Skills", 1).duplicate(true)
		sk.effects = [{"code": 21, "dataId": HARD, "value1": 1.0, "value2": 0.0}]
		sk.damage = {"type": 0, "formula": "0", "elementId": 0, "variance": 0, "critical": false}
		sk.hitType = 0
		q.logic.apply(q.e, sk, q.t)
	elif id == "dingxing.benched":
		q.logic.actors.erase(q.a)
		q.logic.sequence_add_state(q.t, HARD)
	else:
		q.logic.sequence_add_state(q.t, HARD)  # 事件「更改状态」
	traits.erase(resist)
	var lines := XXuanBattle.take_logs().map(func(l): return str(l.text))
	check(id + ".guard", XXuanBattle.data.dingxing.has(ALLY) == bool(o.guard), XXuanBattle.data.dingxing)
	check(id + ".mark", q.t.state_ids.has(XXuanBattle.state_id("dingxing")) == bool(o.mark), q.t.state_ids)
	check(id + ".stun", q.t.state_ids.has(HARD) == bool(o.stun), q.t.state_ids)
	check(id + ".lines", lines == (o.lines as Array), [o.lines, lines])


func _c_libi(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _setup(int(c.setup.level))
	_use(r, "libi", r.t)
	check(c.id + ".amount", _close(XXuanBattle.shield_amount(r.a, r.t), o.amount), [o.amount, XXuanBattle.shield_amount(r.a, r.t)])
	check(c.id + ".weight", _close(XXuanBattle.weight(r.a), o.weight))
	var rows: Array = XShieldLedger.rows(r.t)
	check(c.id + ".rows", rows.size() == 1 and rows[0].source == "xuan.libi" and _close(rows[0].amount, o.shields[0].amount) and int(rows[0].until) == int(o.shields[0].until) and int(rows[0].owner) == XUAN, [o.shields, rows])
	check(c.id + ".total", _close(XShieldLedger.amount(r.t), o.total), [o.total, XShieldLedger.amount(r.t)])


func _tough(e: XBattler) -> void:
	var p: Array = (e.data().params as Array).map(func(v): return float(v))
	p[0] += 1e12
	e.zq_ref = {"p": p, "k": 1.0}
	e.param_mark_dirty()
	e.param_refresh()
	e.hp = e.mhp


func _c_lengguang(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _setup()
	if str(c.id) == "lengguang.dead":
		r.e.hp = 1.0
		var h: Dictionary = _use(r, "lengguang", r.e)
		check(c.id + ".hp", float(h.hp) == float(o.hp), [o.hp, h.hp])
		check(c.id + ".alive", r.e.is_alive() == bool(o.alive))
		check(c.id + ".buffs", _ints(r.e.buffs) == _ints(o.buffs), [o.buffs, r.e.buffs])
		return
	_tough(r.e)
	var hit: Dictionary = _use(r, "lengguang", r.e)
	check(c.id + ".hp", float(hit.hp) == float(o.hp), [o.hp, hit.hp])
	check(c.id + ".buffs", _ints(r.e.buffs) == _ints(o.buffs), [o.buffs, r.e.buffs])
	check(c.id + ".turns", [r.e.buff_turns[3], r.e.buff_turns[5]] == _ints(o.turns), [o.turns, r.e.buff_turns])
	check(c.id + ".record", bool(XXuanBattle.data.record.get("assist", false)) == bool(o.record.assist))


func _c_shihui(c: Dictionary) -> void:
	var lv := int(c.setup.lv)
	var r := _setup(60, {"shihui": lv} if lv > 0 else {"tongdiao": 1})
	_tough(r.e)
	for i in [2, 4, 6, 7]:
		r.logic.sequence_buff(r.e, i, true, true, 5)
	var seq: Array = c.observed.seq
	for k in seq.size():
		_use(r, "lengguang", r.e)
		check("%s.%d.buffs" % [c.id, k], _ints(r.e.buffs) == _ints(seq[k].buffs), [seq[k].buffs, r.e.buffs])
		check("%s.%d.last" % [c.id, k], int(XXuanBattle.data.shihuiRound) == int(seq[k].last), [seq[k].last, XXuanBattle.data.shihuiRound])
		if k % 2 == 1:
			XXuanBattle.data.shihuiRound -= 1


func _c_meets(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _setup()
	check(c.id + ".auto", XXuanBattle.auto_enabled() == bool(o.auto))
	check(c.id + ".qualified", XXuanChart.auto_qualified(r.s, r.a) == bool(o.qualified))
	for k in ["jixing", "jixing.possess", "huiguang", "libi", "lengguang", "liexing", "return", "menu.starchart"]:
		var skill := XDB.rec("Skills", XTusuXuan.skill_id(XUAN, k))
		var got: bool = XXuanBattle.meets(r.a, skill) and XTusuXuan.meets(r.a, skill)
		check("%s.%s" % [c.id, k], got == bool(o[k]), [o[k], got])


func _c_endbattle(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var r := _setup(60, {"dingxing": 2})
	r.logic._state_add(r.t, HARD)
	_use(r, "huiguang", r.t)
	check(c.id + ".before", r.t.state_ids.has(XXuanBattle.state_id("dingxing")) == (o.before.size() > 0))
	r.logic.end_battle(0)
	check(c.id + ".after", not r.t.state_ids.has(XXuanBattle.state_id("dingxing")), r.t.state_ids)
	check(c.id + ".data", XXuanBattle.data.is_empty())
