extends Node
## 状态效果 js 再翻译（云端车道）：逐项对照 mv_oracle/state_js_probe.cjs。
## 叠毒 _stackingPoison：Apply 加层／Remove 清零／Regenerate 按来源能力扣血，持有者共用层数。
var results := []


class FixedActor:
	extends XActor
	var fixed := {}
	func param(i: int) -> float:
		var name: String = ["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"][i]
		return float(fixed[name]) if fixed.has(name) else super(i)
	func _level() -> int:
		return int(fixed.level) if fixed.has("level") else super()


class FixedEnemy:
	extends XEnemy
	var fixed := {}
	func param(i: int) -> float:
		var name: String = ["mhp", "mmp", "atk", "def", "mat", "mdf", "agi", "luk"][i]
		return float(fixed[name]) if fixed.has(name) else super(i)
	func _level() -> int:
		return int(fixed.level) if fixed.has("level") else super()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(900))


func _ready() -> void:
	_run.call_deferred()


func _profile(p: Array) -> Dictionary:
	return {"atk": p[0], "mat": p[1], "agi": p[2], "luk": p[3], "mhp": p[4], "mmp": p[5], "level": p[7]}


func _holder(kind: String) -> XBattler:
	if kind == "actor":
		return FixedActor.new().setup(1)
	return FixedEnemy.new().setup(XDB.rec("Troops", 2).members[0].enemyId, 3, 100.0)


func _run() -> void:
	var ref = XDB.load_json("oracle/state_js.json")
	if not (ref is Dictionary and ref.has("cases")):
		check("oracle_present", false)
		return finish()
	var cases := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		cases[c.id] = c
	# 原文本身报错的块（106／732 读装备等级、551 变量名拼错）不翻译，参照里的报错只许来自这些状态
	var bad: Array = ref.get("nativeErrors", []).filter(func(e): return _translated_message(str(e.message)))
	check("native_errors_untranslated_only", bad.is_empty(), bad)
	_poison_translated(cases["poison.inventory"].observed)
	_poison_lifecycle(cases["poison.lifecycle"].observed, cases["poison.shared_counter"].observed)
	_poison_tick(cases["poison.tick"].observed, cases["poison.tick"].setup)
	_poison_turn_end(cases["poison.turn_end"])
	_save_round_trip()
	_batch2_translated(cases)
	_add_state_self(cases["add_state.self"].observed)
	_add_state_critical(cases["add_state.critical"].observed)
	_gain_self(cases["gain.self"].observed)
	_set_variable(cases["set_variable.battle"].observed)
	_battle_start_order(cases["battle.start_order"])
	_syntax_errors(cases["syntax_error.blocks"].observed)
	_counter_init(cases["counter.init"].observed)
	_counter_carry(cases["counter.carry"].observed)
	_counter_battle(cases["counter.battle"].observed)
	_counter_save()
	finish()


## 每个叠毒状态的 Apply／Remove 都译成 poison_stack；Regenerate 译成 poison_tick（原文有错或读法装备等级的留 js）
func _poison_translated(o: Dictionary) -> void:
	for row in o.states:
		var st := XDB.rec("States", int(row.id))
		var ops := {}
		for e in st.get("effects", []):
			ops[str(e.phase)] = str(e.op)
		check("poison.translated.%d.apply" % row.id, ops.get("apply") == "poison_stack", ops)
		check("poison.translated.%d.remove" % row.id, ops.get("remove") == "poison_stack", ops)
		if ops.has("regenerate") and ops.regenerate != "poison_tick":
			print("叠毒 Regenerate 未翻译 ", row.id)


func _translated_message(message: String) -> bool:
	var m := RegEx.create_from_string("CUSTOM STATE (\\d+) CODE ERROR").search(message)
	if m == null:
		return true
	return XDB.rec("States", int(m.get_string(1))).get("effects", []).all(func(e): return str(e.op) != "js")


func _stacks(b: XBattler):
	return b.state_data.get("_stackingPoison")


func _poison_lifecycle(o: Dictionary, shared: Dictionary) -> void:
	for row in o.rows:
		var e := _holder("enemy")
		var a := _holder("actor")
		XImportedBalance.set_acting(a)
		var seen := []
		var sid := int(row.state)
		e.add_state(sid)
		seen.append(_stacks(e))
		e.add_state(sid)
		seen.append(_stacks(e))
		e.remove_state(sid)
		seen.append(_stacks(e))
		e.state_data["_stackingPoison"] = 5.0  # 原版这里先 clearResult（刚去掉的状态同一结果槽里不能再加）
		e.add_state(sid)
		seen.append(_stacks(e))
		XImportedBalance.set_acting(null)
		check("poison.lifecycle.%d" % sid, _same(seen, row.stacks) and e.is_state_affected(sid) == row.affected, {"godot": seen, "mv": row.stacks})
	var e := _holder("enemy")
	e.add_state(460)
	e.add_state(504)
	var both = _stacks(e)
	e.remove_state(460)
	check("poison.shared_counter", _same([both, _stacks(e), e.is_state_affected(504)], [shared.both, shared.afterRemove, shared.stillSecond]),
		[both, _stacks(e)])


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if (a[i] == null) != (b[i] == null):
			return false
		if a[i] != null and (a[i] is bool) != (b[i] is bool):
			return false
		if a[i] is bool:
			if a[i] != b[i]:
				return false
		elif a[i] != null and absf(float(a[i]) - float(b[i])) > 1e-9:
			return false
	return true


func _poison_tick(o: Dictionary, setup: Dictionary) -> void:
	var count := 0
	for row in o.rows:
		var sid := int(row[0])
		if not XDB.rec("States", sid).get("effects", []).any(func(e): return str(e.op) == "poison_tick"):
			continue
		var holder_kind := str(row[1])
		var holder := _holder(holder_kind)
		var other: XBattler = _holder("enemy" if holder_kind == "actor" else "actor")
		var st := XDB.rec("States", sid)
		holder.state_ids.append(sid)
		var origin: XBattler = holder
		if row[2] == "other":
			holder.state_origins[sid] = weakref(other)
			origin = other
		# 「另一方」来源时持有者 HP 上限：原版 _paramPlus +1e9，角色再被 YEP 能力上限夹到 99999999
		holder.fixed = {"mhp": 99999999.0 if holder_kind == "actor" else 2e9}
		if row[4] != null:
			holder.state_data["_stackingPoison"] = float(row[4])
		holder.hp = minf(float(row[5]), holder.mhp)  # setHp 立即按上限 refresh
		holder.shield = float(row[6])
		var p: Dictionary = _profile(setup.origins[int(row[3])])
		origin.fixed = p
		origin.tp = float(setup.origins[int(row[3])][6])
		var logs := []
		var ctx := {"random": XRandomStream.create(XRandomStream.hex64(17), "battle"),
			"emit": func(entry): logs.append(entry)}
		XStateEffects.run_one("regenerate", holder, st, ctx)
		var popup_hp = logs[0].hp if not logs.is_empty() else null
		var want_popup = row[10][0][2] if not row[10].is_empty() and row[10][0][1] else null
		var got := [_stacks(holder), holder.hp, holder.is_state_affected(1), popup_hp, holder.shield]
		var want := [row[7], row[8], row[9], want_popup]
		# 原版护盾吸收小数伤害后余量有 3e-9 的误差（吸收链里的取值精度），护盾只比到 1e-6
		check("poison.tick.%d" % count, _same(got.slice(0, 4), want) and absf(holder.shield - float(row[13])) < 1e-6 and (logs.is_empty() or int(logs[0].animation) == int(row[11][0][1])),
			{"row": row, "godot": got})
		count += 1
	check("poison.tick.rows", count > 0, count)


## 接线：真实战斗回合结束，敌人身上的 460（角色 1 施加）连跑两回合，弹字在 regen 记录里
func _poison_turn_end(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	for a in s.members():
		a.refresh_passive()
		a.recover_all()
	var logic := XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.setup(int(c.setup.troop), s)
	var a: XBattler = logic.actors[0]
	var e: XBattler = logic.enemies[0]
	var hp0 := e.hp  # 原版敌人 HP 上限另加了 1e9，只比每回合扣量
	XImportedBalance.set_acting(a)
	e.add_state(int(c.setup.state))
	XImportedBalance.set_acting(null)
	check("poison.turn_end.origin_params", [a.atk, a.mat] == [float(o.atk), float(o.mat)], [a.atk, a.mat, o.atk, o.mat])
	logic.start_turn()
	var logs1 := logic.end_turn()
	var hp1 := e.hp
	logic.start_turn()
	logic.end_turn()
	check("poison.turn_end.hp", _same([hp0 - hp1, _stacks(e), hp1 - e.hp], [float(o.hp0) - float(o.hp1), o.s1, float(o.hp1) - float(o.hp2)]),
		[hp0, hp1, _stacks(e), e.hp, o])
	var dot := logs1.filter(func(l): return l.type == "regen" and l.target == e and l.has("state"))
	check("poison.turn_end.popup", dot.size() == 1 and float(dot[0].hp) == float(o.hp0) - float(o.hp1), dot.map(func(l): return l.hp))


## 角色身上的状态私有字段随存档（原版 Game_Actor._stackingPoison 在局内存档里）；空的不写
func _save_round_trip() -> void:
	var s := XState.new_game(3, 1, [8])
	var a: XActor = s.members()[0]
	a.state_data["_stackingPoison"] = 4.0
	var d := s.to_dict()
	var row: Dictionary = d.actors[str(a.actor_id)]
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(d)))
	check("save.state_data", float(back.actors[a.actor_id].state_data.get("_stackingPoison", 0)) == 4.0, row.get("stateData"))
	var other: XActor = s.members()[1]
	check("save.state_data_absent_when_empty", not d.actors[str(other.actor_id)].has("stateData"), d.actors[str(other.actor_id)].keys())


# ---- 第二批 ----
const SLOT_PHASE := {"battle": "battle", "turnStartState": "turn_start", "victory": "victory", "addState": "apply", "establishState": "establish"}
const BATCH2 := {"add_state.self": "add_state", "add_state.critical": "add_state", "gain.self": "gain_steps", "set_variable.battle": "set_variable"}


func _ops(sid: int, phase: String) -> Array:
	return XDB.rec("States", sid).get("effects", []).filter(func(e): return str(e.phase) == phase).map(func(e): return str(e.op))


## 原版探针按代码形状扫出的每一块都已翻译（扫描与转换各自独立，数目对不上就说明某一边漏了）
func _batch2_translated(cases: Dictionary) -> void:
	for id in BATCH2:
		var blocks: Array = cases[id].setup.blocks
		var bad := blocks.filter(func(b): return _ops(int(b[0]), SLOT_PHASE[str(b[1])]) != [BATCH2[id]])
		check("batch2.translated.%s" % id, not blocks.is_empty() and bad.is_empty(), bad)


func _state_view(b: XBattler) -> Array:
	var ids := b.state_ids.duplicate()
	ids.sort()
	return ids


## 开战／回合开始 user.addState(N)：持有者活着才加；倒下的（isStateAddable）不加
func _add_state_self(o: Dictionary) -> void:
	for row in o.rows:
		var a := _holder("actor")
		var sid := int(row.state)
		a.add_state(sid)
		if row.dead:
			a.hp = 0.0
			XResourceContext.new().refresh(a)  # setHp(0)＋refresh：倒下
		XStateEffects.run_one(str(row.phase), a, XDB.rec("States", sid), {"random": XRandomStream.create(XRandomStream.hex64(5), "battle")})
		var want: Array = row.after.states.map(func(x): return int(x))
		want.sort()
		var turns_ok := true
		for k in row.after.turns:
			var st := XDB.rec("States", int(k))
			if int(st.minTurns) == int(st.maxTurns) and int(a.state_turns.get(int(k), -1)) != int(row.after.turns[k]):
				turns_ok = false
		check("add_state.self.%d.%s" % [sid, row.dead], _state_view(a) == want and turns_ok and a.is_dead() == row.dead,
			{"godot": [_state_view(a), a.state_turns], "mv": row.after})


## Establish：目标这次 critical 才给行动者／目标加状态；返回值原样
func _add_state_critical(o: Dictionary) -> void:
	for row in o.rows:
		var a := _holder("actor")
		var e := _holder("enemy")
		var sid := int(row.state)
		var rc := XResourceContext.new()
		var ctx := {"attacker": a, "defender": e, "item": XDB.rec("Skills", 1), "critical": row.critical, "resources": rc, "value": 7.0,
			"random": XRandomStream.create(XRandomStream.hex64(5), "battle")}
		var value := XStateEffects.run_one("establish", a, XDB.rec("States", sid), ctx)
		var wu: Array = row.user.states.map(func(x): return int(x))
		var wt: Array = row.target.states.map(func(x): return int(x))
		var added: Array = rc.result(a).addedStates + rc.result(e).addedStates
		check("add_state.critical.%d.%s" % [sid, row.critical], value == float(row.value) and _state_view(a) == wu and _state_view(e) == wt
			and added == (row.user.added + row.target.added).map(func(x): return int(x)),
			{"godot": [value, _state_view(a), _state_view(e), added], "mv": row})


## 开战／胜利／附加时 user.gainHp/Mp/Tp：HP 1000、MP 300 固定，三种起点；结果槽同原版
func _gain_self(o: Dictionary) -> void:
	var starts := [[500, 100, 10], [1, 0, 95], [1000, 300, 0]]
	for row in o.rows:
		var a := _holder("actor")
		a.fixed = {"mhp": 1000.0, "mmp": 300.0}
		var start: Array = starts[int(row.start)]
		a.hp = float(start[0])
		a.mp = float(start[1])
		a.tp = float(start[2])
		var rc := XResourceContext.new()
		XStateEffects.run_one(str(row.phase), a, XDB.rec("States", int(row.state)), {"resources": rc})
		var r := rc.result(a)
		var got := [a.hp, a.mp, a.tp, r.hpDamage, r.mpDamage, r.tpDamage, r.hpAffected]
		var want: Array = [row.hp, row.mp, row.tp] + row.slot
		check("gain.self.%d.%d" % [row.state, row.start], _same(got, want), {"godot": got, "mv": want})


## 开战 $gameVariables.setValue：编号超出 System.variables 的写入被原版忽略
func _set_variable(o: Dictionary) -> void:
	var s := XState.new_game(3, 1, [8])
	for row in o.rows:
		# 原版探针先 setValue(编号, 7)：超出范围的那次同样被忽略
		if int(row.variable) < XDB.system().variables.size():
			s.set_variable(int(row.variable), 7.0)
		XStateEffects.run_one("battle", s.members()[0], XDB.rec("States", int(row.state)), {})
		check("set_variable.%d" % row.state, s.variable(int(row.variable)) == float(row.value), [s.variable(int(row.variable)), row])


## 接线：真实开战，607（开战 TP+200）在初始随机 TP 之后跑，TP 为 200
func _battle_start_order(c: Dictionary) -> void:
	var sid := int(c.setup.state)
	var st := XDB.rec("States", sid)
	# 607 是战斗结束解除的状态，Godot 开战前会先清掉上一场遗留的这类状态；原版探针直接给开战前的角色加上，这里临时关掉该旗标
	var keep = st.removeAtBattleEnd
	st.removeAtBattleEnd = false
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	var a: XActor = s.members()[0]
	a.add_state(sid)
	var logic := XBattleLogic.new()
	logic.elite_roll = 100.0
	logic.setup(int(c.setup.troop), s)
	st.removeAtBattleEnd = keep
	check("battle.start_order", logic.actors[0].tp == float(c.observed.tp) and logic.actors[0].max_tp() == float(c.observed.maxTp),
		[logic.actors[0].tp, c.observed])


## 原版解析失败的块：译成 syntax_error，执行时什么都不改、返回值原样
func _syntax_errors(o: Dictionary) -> void:
	for row in o.rows:
		var sid := int(row.state)
		var st := XDB.rec("States", sid)
		var effects: Array = st.get("effects", []).filter(func(e): return str(e.op) == "syntax_error")
		var ok: bool = effects.size() >= 1 and row.unchanged and float(row.value) == 7.0
		for e in effects:
			var a := _holder("actor")
			var t := _holder("enemy")
			var before := [_state_view(a), a.hp, a.mp, a.tp, _state_view(t), t.hp]
			var value := XStateEffects.run_one(str(e.phase), a, st, {"attacker": a, "defender": t, "item": XDB.rec("Skills", 1), "value": 7.0})
			ok = ok and value == 7.0 and before == [_state_view(a), a.hp, a.mp, a.tp, _state_view(t), t.hp]
		check("syntax_error.%d.%s" % [sid, row.slot], ok, [effects, row])


# ---- 第三批：状态计数 ----
func _params(b: XBattler) -> Array:
	b.param_mark_dirty()
	b.param_refresh()
	return range(8).map(func(i): return b.param(i))


func _minus(x: Array, y: Array) -> Array:
	return range(x.size()).map(func(i): return float(x[i]) - float(y[i]))


func _counter(b: XBattler, sid: int):
	return b.state_data.get("_stateCounter", {}).get(str(sid))


## 附加时 计数 = 计数 || 变量：能力值按计数乘；变量为 0 时计数 0（层数按 1）；移除后计数留着，再附加不改
func _counter_init(o: Dictionary) -> void:
	for row in o.rows:
		var s := XState.new_game(3, 1, [8])
		var b := FixedActor.new().setup(8)
		var sid := int(row.state)
		var p0 := _params(b)
		s.set_variable(int(row.variable), float(row.value))
		b.add_state(sid)
		var counter = _counter(b, sid)
		var p1 := _params(b)
		b.remove_state(sid)
		var after_remove = _counter(b, sid)
		s.set_variable(int(row.variable), 99.0)
		b.add_state(sid)
		var got := [counter, after_remove, _counter(b, sid)] + _minus(p1, p0) + _minus(_params(b), p0)
		var want: Array = [row.counter, row.get("afterRemove"), row.readd] + _minus(row.refreshed, row.p0) + _minus(row.readdParams, row.p0)
		check("counter.init.%d.%d" % [sid, row.value], _same(got, want), {"godot": got, "mv": want})


## 层数沿用：排在计数状态后面的普通状态也乘计数，前面的不乘
func _counter_carry(o: Dictionary) -> void:
	for row in o.rows:
		var s := XState.new_game(3, 1, [8])
		var b := FixedActor.new().setup(8)
		var A := XDB.rec("States", int(row.counterState))
		s.set_variable(int(A.effects.filter(func(e): return e.op == "counter_init")[0].variable), 12.0)
		var p0 := _params(b)
		b.add_state(int(row.plain))
		var pb := _params(b)
		b.add_state(int(row.counterState))
		var pab := _params(b)
		var got := _minus(pb, p0) + _minus(pab, p0) + [b.state_ids.duplicate()]
		var want: Array = _minus(row.pB, row.p0) + _minus(row.pAB, row.p0) + [row.states.map(func(x): return int(x))]
		check("counter.carry.%d.%d" % [row.counterState, row.plain], _same(got.slice(0, 16), want.slice(0, 16)) and got[16] == want[16],
			{"godot": got, "mv": want})


## 开战 1763：计数 = floor(MP×0.3)。原版只写计数不 refresh，战斗中 krz 能力值缓存到下次标 dirty 才变（探针 p1 与 p0 相同），这里只比计数
func _counter_battle(o: Dictionary) -> void:
	for row in o.rows:
		XState.new_game(3, 1, [8])
		var b := FixedActor.new().setup(8)
		b.add_state(1763)
		b.mp = float(row.mp)
		XStateEffects.run_one("battle", b, XDB.rec("States", 1763), {})
		check("counter.battle.%d" % row.mp, _same([_counter(b, 1763)], [row.counter]), [_counter(b, 1763), row])


## 角色的计数随存档（原版 Game_Actor._stateCounter 在存档里）
func _counter_save() -> void:
	var s := XState.new_game(3, 1, [8])
	var a: XActor = s.members()[0]
	a.state_data["_stateCounter"] = {"1781": 37.0}
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("save.state_counter", float(back.actors[a.actor_id].state_data.get("_stateCounter", {}).get("1781", 0)) == 37.0)


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
