extends Node
## 璇第二期（XXuanBattle 的绑定与手动附身）对原版参照 tests/fixtures/xuan_bind_oracle.json（mv_oracle/xuan_bind_probe.cjs）：
## 寄星、转移、回身、星纹标记、默契结算、同轨、宿主与本体倒下、附身不掉血、战斗结束清理。随机固定 0.5，手动模式。
const FIXTURE := "res://tests/fixtures/xuan_bind_oracle.json"
const XUAN := 177
const A1 := 1
const A8 := 8
const KEYS := ["jixing", "jixing.possess", "huiguang", "libi", "lengguang", "liexing", "return"]
var checks := 0
var failures: Array = []
var lines: Array = []


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
	check("complete", f.cases.size() == 42, f.cases.size())
	for c in f.cases:
		check(c.id + ".oracle", c.errors.is_empty(), c.errors)
		if c.errors.is_empty():
			_case(c)
	var passed := checks - failures.size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": checks}))
	get_tree().quit.call_deferred(0 if failures.is_empty() else 1)


func _setup(spec: Dictionary) -> Dictionary:
	var s := XState.new_game_blank()
	XState.current = s
	s.switches[2494] = true
	s.actor_max_level = 99
	for id in spec.get("party", [XUAN, A1, A8]):
		s.add_actor(int(id))
	var a: XActor = s.actor(XUAN)
	a.change_level(int(spec.get("level", 60)))
	var chart := XTusuXuan.chart(s)
	if spec.has("stage"):
		s.actor_advance[XUAN] = int(spec.stage)
	if spec.has("roster"):
		chart.roster = spec.roster.map(func(v): return int(v))
	for m in spec.get("marks", {}):
		chart.level[m] = int(spec.marks[m])
		chart.slots[XTusuXuan.SLOT_OF[m]] = m
	XTusuXuan.sync_marks(s, a)
	a.recover_all()
	if spec.get("json", false):
		# 审查第 34 期 P2-2：存读档往返（JSON）后名册读回成 [8.0]，不点名册直接进战斗
		s = XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
		XState.current = s
		a = s.actor(XUAN)
		check("roster_json.raw_float", (s.flags["_codexXuanChart"].roster as Array).all(func(v): return v is float), s.flags["_codexXuanChart"].roster)
	var stream := FixedStream.new()
	stream.domain = "rule"
	var rand := XBattleRandom.create("0000000000000177")
	rand.rule = stream
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.hp = e.mhp
	logic.start_turn()
	lines = []
	return {"s": s, "logic": logic, "a": a, "t": s.actor(A1), "t2": s.actor(A8), "e": logic.enemies[0]}


func _use(c: Dictionary, key: String, target: XBattler) -> void:
	c.logic.apply(c.a, XDB.rec("Skills", XTusuXuan.skill_id(XUAN, key)), target)
	_drain()


func _drain() -> void:
	for l in XXuanBattle.take_logs():
		lines.append(str(l.text))


func _next(c: Dictionary) -> void:
	c.logic.end_turn()
	_drain()
	c.logic.start_turn()
	_drain()


func _snap(tag: String, want: Dictionary, c: Dictionary) -> void:
	_drain()
	var a: XActor = c.a
	var h = XBinding.host(a)
	var d := XXuanBattle.data
	check(tag + ".round", XBinding.current_round() == int(want.round), [want.round, XBinding.current_round()])
	check(tag + ".host", (int(h.actor_id) if h != null else 0) == int(want.host), [want.host, h])
	check(tag + ".charges", XBinding.charges(a) == int(want.charges), [want.charges, XBinding.charges(a)])
	if want.tacit != null:
		check(tag + ".tacit", int(d.get("tacit", -1)) == int(want.tacit), [want.tacit, d.get("tacit")])
		check(tag + ".tonggui", bool(d.get("tonggui", false)) == bool(want.tonggui), [want.tonggui, d.get("tonggui")])
	check(tag + ".used", d.get("used", {}).has("jixing") == bool(want.jixingUsed))
	check(tag + ".form", a.state_ids.has(XXuanBattle.state_id("possess")) == bool(want.form), a.state_ids)
	check(tag + ".empty", a.state_ids.has(XTusu.state_id("empty")) == bool(want.empty), a.state_ids)
	check(tag + ".tongguiState", a.state_ids.has(XXuanBattle.state_id("tonggui")) == bool(want.tongguiState), a.state_ids)
	var marks := [A1, A8, XUAN].filter(func(id): return c.s.actor(id).state_ids.has(XXuanBattle.state_id("hostmark")))
	check(tag + ".marks", marks == want.marks.map(func(v): return int(v)), [want.marks, marks])
	var meets := KEYS.filter(func(k):
		var skill := XDB.rec("Skills", XTusuXuan.skill_id(XUAN, k))
		return XXuanBattle.meets(a, skill) and XTusuXuan.meets(a, skill) and logic_alive(a))
	check(tag + ".meets", meets == want.meets, [want.meets, meets])
	check(tag + ".lines", lines == want.lines, [want.lines, lines])


## 倒下的角色 meetsSkillConditions 全否（原版 canMove 那层）
func logic_alive(a: XActor) -> bool:
	return a.is_alive()


func _case(k: Dictionary) -> void:
	var id := str(k.id)
	var o: Dictionary = k.observed
	var c := _setup(k.setup)
	var tag := id.get_slice(".", 0)
	if tag in ["yiguang", "relay", "gongsu", "binggui", "liuhui", "liexing"]:
		_part2(id, tag, o, c)
		return
	match id:
		"jixing.ally":
			_snap(id + ".s0", o.s0, c)
			_use(c, "jixing", c.t)
			_snap(id + ".s1", o.s1, c)
		"jixing.roster", "jixing.roster_stage0":
			_use(c, "jixing", c.t)
			_snap(id, o, c)
		"jixing.self":
			_use(c, "jixing", c.a)
			_snap(id, o, c)
		"jixing.dead":
			c.logic.gain_hp(c.t, -c.t.hp)
			_use(c, "jixing", c.t)
			_snap(id, o, c)
		"possess.same_target":
			_use(c, "jixing", c.t)
			XXuanBattle.data.tacit = 31
			_use(c, "jixing.possess", c.t)
			_snap(id, o, c)
		"return.plain":
			_use(c, "jixing", c.t)
			XXuanBattle.data.tacit = 100
			XXuanBattle.data.tonggui = true
			_snap(id + ".s0", o.s0, c)
			_use(c, "return", c.a)
			_snap(id + ".s1", o.s1, c)
			_next(c)
			_snap(id + ".s2", o.s2, c)
		"mark.remove":
			_use(c, "jixing", c.t)
			c.logic._state_remove(c.t, XXuanBattle.state_id("hostmark"))
			_snap(id, o, c)
		"host.dies":
			_use(c, "jixing", c.t)
			c.logic.gain_hp(c.t, -c.t.hp)
			XBinding.validate()
			_snap(id, o, c)
		"owner.dies":
			_use(c, "jixing", c.t)
			c.a.hp = 0.0
			c.logic._state_add(c.a, 1)
			XBinding.validate()
			_snap(id, o, c)
		"owner.poison":
			# 审查第 34 期 P2-1：附身期间回合末中毒不扣（护盾、弹字都不走），没绑定的照扣，回身后再扣
			c.a.add_state(4)
			c.t2.add_state(4)
			_use(c, "jixing", c.t)
			var a0: float = c.a.hp
			var o0: float = c.t2.hp
			_next(c)
			check(id + ".a1", [a0, c.a.hp] == [float(o.a[0]), float(o.a[1])], [o.a, a0, c.a.hp])
			check(id + ".o1", [o0, c.t2.hp] == [float(o.o[0]), float(o.o[1])], [o.o, o0, c.t2.hp])
			check(id + ".poisoned", c.a.state_ids.has(4) == bool(o.poisoned))
			_use(c, "return", c.a)
			_next(c)
			check(id + ".a2", c.a.hp == float(o.a[2]), [o.a, c.a.hp])
			check(id + ".o2", c.t2.hp == float(o.o[2]), [o.o, c.t2.hp])
			check(id + ".poisoned_after", c.a.state_ids.has(4) == bool(o.poisonedAfter))
		"owner.hp_loss":
			_use(c, "jixing", c.t)
			var before: float = c.a.hp
			c.logic.gain_hp(c.a, -100.0)
			check(id + ".held", c.a.hp == float(o.held), [o.held, c.a.hp])
			_use(c, "return", c.a)
			c.logic.gain_hp(c.a, -100.0)
			check(id + ".after", c.a.hp == float(o.after), [before, o.after, c.a.hp])
		"tacit.transfer_round":
			_use(c, "jixing", c.t)
			_next(c)
			check(id + ".t1", int(XXuanBattle.data.tacit) == int(o.t1))
			_use(c, "jixing.possess", c.t2)
			check(id + ".t2", int(XXuanBattle.data.tacit) == int(o.t2))
			_next(c)
			check(id + ".t3", int(XXuanBattle.data.tacit) == int(o.t3))
			_next(c)
			check(id + ".t4", int(XXuanBattle.data.tacit) == int(o.t4), [o.t4, XXuanBattle.data.tacit])
		"tacit.unbound_round":
			_next(c)
			check(id + ".t1", int(XXuanBattle.data.tacit) == int(o.t1))
			_use(c, "lengguang", c.e)
			_next(c)
			check(id + ".t2", int(XXuanBattle.data.tacit) == int(o.t2), [o.t2, XXuanBattle.data.tacit])
		"end.clear":
			_use(c, "jixing", c.t)
			c.logic.end_battle(0)
			check(id + ".data", XXuanBattle.data.is_empty() == not bool(o.data))
			check(id + ".form", c.a.state_ids.has(XXuanBattle.state_id("possess")) == bool(o.form))
			check(id + ".mark", c.t.state_ids.has(XXuanBattle.state_id("hostmark")) == bool(o.mark))
			check(id + ".bound", XBinding.is_bound(c.a) == bool(o.bound))
		_:
			if tag == "possess":
				_use(c, "jixing", c.t)
				XXuanBattle.data.tacit = 31
				_snap(id + ".s0", o.s0, c)
				_use(c, "jixing.possess", c.t2)
				_snap(id + ".s1", o.s1, c)
				_use(c, "jixing.possess", c.t)
				_snap(id + ".s2", o.s2, c)
				_next(c)
				_snap(id + ".s3", o.s3, c)
			elif tag == "tacit":
				_use(c, "jixing", c.t)
				var act: String = {"protect20": "huiguang", "protect60": "huiguang", "assist60": "lengguang", "libi60": "libi"}.get(id.get_slice(".", 1), "")
				for row in o.seq:
					if act != "":
						_use(c, act, c.e if act == "lengguang" else c.t)
					_next(c)
					var label := "%s.r%d" % [id, int(row.round)]
					check(label + ".tacit", int(XXuanBattle.data.tacit) == int(row.tacit), [row.tacit, XXuanBattle.data.tacit])
					check(label + ".tonggui", bool(XXuanBattle.data.tonggui) == bool(row.tonggui))
					check(label + ".state", c.a.state_ids.has(XXuanBattle.state_id("tonggui")) == bool(row.state))


func _sh(b) -> Array:
	var out := XShieldLedger.rows(b).filter(func(r): return str(r.source).begins_with("xuan.")).map(func(r): return {"source": str(r.source), "amount": roundf(float(r.amount)), "until": int(r.until)})
	out.sort_custom(func(x, y): return x.source < y.source)
	return out


func _same_sh(tag: String, got: Array, want: Array) -> void:
	var w := want.map(func(r): return {"source": str(r.source), "amount": float(r.amount), "until": int(r.until)})
	check(tag, JSON.stringify(got) == JSON.stringify(w), [want, got])


func _dm(tag: String, b: XActor, want: Dictionary) -> void:
	check(tag, roundf(b.def) == float(want.def) and roundf(b.mdf) == float(want.mdf), [want, [b.def, b.mdf]])


## 第二期续：移光、接力、留辉、共宿、并轨 3 级、列星
func _part2(id: String, tag: String, o: Dictionary, c: Dictionary) -> void:
	var t3: XActor = c.s.actor(2) if c.s.party.has(2) else null
	if t3 != null:
		t3.hp = floorf(t3.mhp / 2.0)
	match tag:
		"yiguang", "relay":
			_use(c, "jixing", c.t)
			_use(c, "libi", c.t)
			_same_sh(id + ".s0", _sh(c.t), o.s0)
			_use(c, "jixing.possess", c.t2)
			_same_sh(id + ".prev", _sh(c.t), o.prev)
			_same_sh(id + ".next", _sh(c.t2), o.next)
			if o.has("third"):
				_same_sh(id + ".third", _sh(t3), o.third)
		"gongsu":
			_dm(id + ".base.t", c.t, o.base.t)
			_use(c, "jixing", c.t)
			_dm(id + ".bound.t", c.t, o.bound.t)
			_dm(id + ".bound.t2", c.t2, o.bound.t2)
			_dm(id + ".xuan", c.a, o.xuan)
			check(id + ".defRate", is_equal_approx(XXuanBattle.gongsu_defense_rate(c.a), float(o.defRate)), [o.defRate, XXuanBattle.gongsu_defense_rate(c.a)])
			var ops: Array = XXuanBattle.damage_ops(XDB.rec("Skills", 1), c.t)
			var rate: float = float(ops[0].value) - 1.0 if not ops.is_empty() else 0.0
			check(id + ".rate", is_equal_approx(rate, float(o.rate)), [o.rate, rate])
			check(id + ".rate2", XXuanBattle.damage_ops(XDB.rec("Skills", 1), c.t2).is_empty() == (float(o.rate2) == 0.0))
		"binggui":
			XXuanChart.chart(c.s).partner = A8
			_dm(id + ".base", c.t2, o.base)
			_use(c, "jixing", c.t)
			_dm(id + ".partner", c.t2, o.partner)
			_dm(id + ".host", c.t, o.host)
		"liuhui":
			_use(c, "jixing", c.t)
			_dm(id + ".0", c.t, o.seq[0])
			_use(c, "jixing.possess", c.t2)
			_dm(id + ".1", c.t, o.seq[1])
			for i in range(2, o.seq.size()):
				_next(c)
				_dm("%s.r%d" % [id, int(o.seq[i].round)], c.t, o.seq[i])
		"liexing":
			_use(c, "jixing", c.t)
			_use(c, "liexing", c.a)
			var d := XXuanBattle.data
			var w: Dictionary = o.s0
			check(id + ".until", int(d.liexingUntil) == int(w.until), [w.until, d.liexingUntil])
			check(id + ".shadows", d.shadows == w.shadows.map(func(v): return int(v)), [w.shadows, d.shadows])
			_shadow_state(id, c, w)
			var cover: Array = XXuanBattle.beneficiaries(c.a).list.map(func(b): return int(b.actor_id))
			check(id + ".cover", cover == w.cover.map(func(v): return int(v)), [w.cover, cover])
			for p in [["heal", "huiguang", c.t], ["wall", "libi", c.t], ["prism", "lengguang", c.e]]:
				var got: Array = c.logic.targets_for(c.a, XDB.rec("Skills", XTusuXuan.skill_id(XUAN, p[1])), p[2]).map(func(b): return int(b.actor_id) if b is XActor else -c.logic.enemies.find(b) - 1)
				check(id + "." + p[0], got == w[p[0]].map(func(v): return int(v)), [w[p[0]], got])
			var ops: Array = XXuanBattle.damage_ops(XDB.rec("Skills", 1), t3)
			check(id + ".rate3", not ops.is_empty() and is_equal_approx(float(ops[0].value) - 1.0, float(w.rate3)), [w.rate3, ops])
			_dm(id + ".def3", t3, w.def3)
			for row in o.seq:
				_next(c)
				var label := "%s.r%d" % [id, int(row.round)]
				check(label + ".until", int(d.liexingUntil) == int(row.until), [row.until, d.liexingUntil])
				check(label + ".shadows", d.shadows == row.shadows.map(func(v): return int(v)), [row.shadows, d.shadows])
				_shadow_state(label, c, row)


func _shadow_state(tag: String, c: Dictionary, w: Dictionary) -> void:
	var got := [A1, A8, 2].filter(func(id): return c.s.party.has(id) and c.s.actor(id).state_ids.has(XXuanBattle.state_id("shadow")))
	var want: Array = w.shadowState.map(func(v): return int(v))
	want.sort()
	got.sort()
	check(tag + ".shadowState", got == want, [w.shadowState, got])
	check(tag + ".self", c.a.state_ids.has(XXuanBattle.state_id("liexing")) == bool(w.self))
