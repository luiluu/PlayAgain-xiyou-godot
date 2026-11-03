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
	check("complete", f.cases.size() == 23, f.cases.size())
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
	for id in [XUAN, A1, A8]:
		s.add_actor(id)
	var a: XActor = s.actor(XUAN)
	a.change_level(int(spec.get("level", 60)))
	var chart := XTusuXuan.chart(s)
	if spec.has("stage"):
		s.actor_advance[XUAN] = int(spec.stage)
	if spec.has("roster"):
		chart.roster = spec.roster.map(func(v): return int(v))
	XTusuXuan.sync_marks(s, a)
	a.recover_all()
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
