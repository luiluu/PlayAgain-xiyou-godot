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


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
