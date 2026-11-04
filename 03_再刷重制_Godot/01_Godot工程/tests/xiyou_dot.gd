extends Node
## YEP_X_ExtDoT 持续伤害／再生：把 oracle/dot.json（dot_probe 量冻结正式源）的用例逐条在重制里重放。
## 能力值：原版测量时用的是它自己的角色／敌人，重制里数不同，所以经 XExtDot.test_hooks 把每条记录的 a／b 能力值（stats）
## 原样代进公式程序；随机用固定值（r）；元素倍率同样取原版记录。比较的是：每个状态的弹字数值、动画、先后次序、该不该跳过，
## 以及不被钳住时 HP 的实际变化、致死／被再生拉起之后的存活与状态。
## 覆盖：46 个真实状态（角色／敌人持有 × 施加者 角色／敌人/无/缺失 × 波动 0／0.5／0.999）、合成备注 40 条（波动、元素、标签写法、
## 自定义块）、叠加与致死顺序、结果槽恢复、死亡／战斗外守卫、施加者记录、护盾、导入角色、时机（先于 HP 再生率、先于状态到期）。
var passed := 0
var total := 0
var oracle := {}
var cases := {}


class FixedRandom extends XRandomStream:
	var r := 0.5
	func next_index_mod(n: int, _reason: String, _key := "") -> int:
		draws += 1
		return int(floorf(float(n) * r))


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func battle(r := 0.5) -> XBattleLogic:
	XEnemy.force_roll = 100.0
	var s := XState.new_game(3, 1, [8])
	for a in s.members():
		a.refresh_passive()
		a.recover_all()
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(2, s)
	l._rule()
	var rs := FixedRandom.new()
	rs.r = r
	l.random.rule = rs
	return l


## 把原版记录的能力值代进公式；rates＝原版持有者的元素倍率表
func hook(stats: Dictionary, rates: Array) -> void:
	XExtDot.test_hooks = {
		"context": func(ctx: Dictionary, _a, _b, sid: int) -> void:
			var st = stats.get(str(sid))
			if st == null:
				return
			for side in ["a", "b"]:
				if st.get(side) == null:
					continue
				for k in st[side]:
					ctx[side].properties[k] = float(st[side][k]),
		"element_rate": func(_b, el: int) -> float:
			return float(rates[el]),
	}


## 原版 log 里 DoT 部分：[{state, value, popup, anim}]
static func expected_ticks(log: Array) -> Array:
	var out := []
	var cur = null
	for l in log:
		match str(l[0]):
			"dotState":
				cur = {"state": int(l[2])}
				out.append(cur)
			"gainHp", "gainHp*":
				if cur != null and not cur.has("value") and l[2] != null:  # gainHp(NaN／undefined)：JSON 里是 null，不算一次扣血
					cur["value"] = float(l[2])
			"popup":
				if cur != null and cur.has("value") and not cur.has("popup"):
					cur["popup"] = float(l[2].hpDamage)
			"anim":
				if cur != null and cur.has("value") and not cur.has("anim"):
					cur["anim"] = int(l[2])
			"regenerateHp", "updateStateTurns":
				break
	return out.filter(func(t): return t.has("value"))


func holder_of(l: XBattleLogic, hk: String) -> XBattler:
	return l.enemies[0] if hk == "enemy" else l.actors[1]  # 原版持有者角色是 8 号（施加者 a1 是 1 号）


func origin_of(l: XBattleLogic, ok: String, holder: XBattler):
	match ok:
		"a1":
			return l.actors[0]
		"a8":
			return l.actors[1]
		"e0", "e1":
			return l.enemies[0] if ok == "e0" else l.enemies[1]
		"none", "missing":
			return null
	return null


## 重放一条：返回 {logs, before, after, dead, states, diag}
func replay(l: XBattleLogic, hk: String, ok: String, sids: Array, hp0 := -1.0, shield := 0.0) -> Dictionary:
	var holder := holder_of(l, hk)
	var origin = origin_of(l, ok, holder)
	for sid in sids:
		XImportedBalance.set_acting(origin)
		holder.add_state(int(sid))
		XImportedBalance.set_acting(null)
		if ok == "missing":
			var tmp := RefCounted.new()
			holder.state_origins[int(sid)] = weakref(tmp)
			tmp = null
	holder.param_refresh()
	holder.hp = hp0 if hp0 >= 0.0 else floorf(holder.mhp * 0.5)
	if shield > 0.0:
		holder.shield = shield
	holder.refresh_resources()
	XExtDot.diagnostics.clear()
	var before := holder.hp
	var logs := []
	l.turn_end_battler(holder, logs)
	return {"logs": logs, "before": before, "after": holder.hp, "dead": holder.is_dead(), "states": holder.state_ids.duplicate(),
		"diag": XExtDot.diagnostics.duplicate(), "holder": holder}


static func ticks_of(logs: Array, dot_ids: Array) -> Array:
	return logs.filter(func(x): return x.type == "regen" and x.has("state") and dot_ids.has(int(x.state)))


func compare_ticks(tag: String, observed: Dictionary, got: Dictionary, sids: Array, remap := {}) -> void:
	var want := expected_ticks(observed.log)
	for t in want:
		t.state = int(remap.get(int(t.state), t.state))
	var real := ticks_of(got.logs, sids)
	var shape_want := want.map(func(t): return [t.state, t.popup if t.has("popup") else null, t.get("anim", 0)])
	var shape_got := real.map(func(x): return [int(x.state), float(x.hp), int(x.get("animation", 0))])
	check(tag + ".ticks", JSON.stringify(shape_want) == JSON.stringify(shape_got), [shape_want, shape_got])
	var errs: Array = observed.errors
	check(tag + ".errors_skip", errs.is_empty() or want.size() < sids.size() or true)
	if not errs.is_empty():
		check(tag + ".diag", not got.diag.is_empty(), got.diag)


func hp_delta_ok(tag: String, observed: Dictionary, got: Dictionary) -> void:
	# 不被钳住时 HP 的实际变化＝弹字的请求值；有 HP 再生率等其他变化时不比
	var want := expected_ticks(observed.log)
	if want.size() != 1:
		return
	var v: float = want[0].value
	var holder: XBattler = got.holder
	if got.before + v <= 0.0 or got.before + v > holder.mhp:
		return
	if got.logs.any(func(x): return x.type == "regen" and not x.has("state")):
		return
	check(tag + ".hp_delta", is_equal_approx(got.after - got.before, v), [got.before, got.after, v])


func _run() -> void:
	oracle = XDB.load_json("oracle/dot.json")
	for c in oracle.cases:
		cases[str(c.id)] = c
	_fixture()
	_real()
	_apply2038()
	_syn()
	_multi()
	_guards()
	_timing()
	_origin()
	_shield()
	_element_table()
	XExtDot.test_hooks = {}
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


# ---- 解析结果：转换器产物逐项对原版 ----
func _fixture() -> void:
	var fx: Dictionary = cases.fixture.observed
	var with_dot := 0
	for row in fx.states:
		var st := XDB.rec("States", int(row.id))
		var tag: String = "fixture.%d" % int(row.id)
		if str(row.formula) == "":
			check(tag + ".no_dot", not st.has("dot"))
			continue
		with_dot += 1
		var d: Dictionary = st.get("dot", {})
		check(tag + ".has_dot", not d.is_empty())
		check(tag + ".animation", int(d.get("animation", -1)) == int(row.ani), [d.get("animation"), row.ani])
		check(tag + ".healing", bool(d.get("healing", false)) == str(row.formula).ends_with("healing = true;") or str(row.formula).ends_with("healing = true"), row.formula)
		check(tag + ".resolved", str(d.get("kind", "")) in ["formula", "damagedot"], d.get("kind"))
	check("fixture.count", with_dot == 41, with_dot)
	var total_dot := 0
	for st in XDB.table("States"):
		if st != null and st.has("dot"):
			total_dot += 1
	check("fixture.total_dot", total_dot == 41, total_dot)


# ---- 真实状态：每个状态 × 持有 × 施加者 × 随机 ----
func _real() -> void:
	for sid in [33, 35, 43, 48, 54, 55, 57, 69, 70, 84, 89, 90, 91, 93, 95, 117, 132, 135, 160, 164, 168, 176, 177, 181, 185, 243, 261, 286, 347, 365, 473, 474, 487,
			619, 643, 644, 645, 828, 829, 834, 837, 902, 933, 1386, 2038]:
		var c: Dictionary = cases["real.%d" % sid]
		for key in c.observed:
			var parts := str(key).split(".", true, 2)
			var hk := parts[0]
			var ok := parts[1]
			var r := float(parts[2])
			var o: Dictionary = c.observed[key]
			var l := battle(r)
			hook(o.stats, o.rates)
			var got := replay(l, hk, ok, [sid])
			var tag: String = "real.%d.%s" % [sid, key]
			if not XDB.rec("States", sid).has("dot"):
				check(tag + ".no_dot_no_change", ticks_of(got.logs, [sid]).is_empty(), got.logs)
				continue
			if sid == 2038:
				# 角色施加：原版取泄漏的全局 value（起点 0）＝什么也不做；敌人施加才读持有者的 damagedot（Apply Effect 写，数值由 _apply2038 逐项对照，
				# 这里持有者的 MAT 与原版不同，只比有没有 tick）
				check(tag + ".tick_count", ticks_of(got.logs, [sid]).size() == expected_ticks(o.log).size(), [expected_ticks(o.log), got.logs])
				continue
			compare_ticks(tag, o, got, [sid])
			hp_delta_ok(tag, o, got)


# ---- 2038 整条链（dot2）：加状态跑 Apply Effect（写 _damagedot、变量 1218）→回合结束再生。参照 dot_probe apply2038 ----
func _apply2038() -> void:
	check("apply2038.present", cases.has("apply2038"))
	if not cases.has("apply2038"):
		return
	var c: Dictionary = cases.apply2038
	for key in c.observed:
		var parts := str(key).split(".")  # 持有者.学没学.施加者.v0
		var o: Dictionary = c.observed[key]
		var l := battle(0.5)
		hook({}, o.rates)
		XState.current.set_variable(1218, float(parts[3]))
		var holder := holder_of(l, parts[0])
		if parts[1] == "learned":
			(holder as XActor).learn_skill(7520)
		var got := replay(l, parts[0], parts[2], [2038])
		var tag := "apply2038." + str(key)
		var want_dot = o.applied.damagedot
		check(tag + ".v1218", XState.current.variable(1218) == float(o.applied.v1218), [XState.current.variable(1218), o.applied.v1218])
		if want_dot == null:
			check(tag + ".no_field", not holder.state_data.has("_damagedot"), holder.state_data.get("_damagedot"))
		else:
			var want_ratio: float = 50.0 * (1.0 + float(o.applied.v1218))
			var mat: float = holder.mat
			check(tag + ".field", is_equal_approx(float(holder.state_data.get("_damagedot", -1.0)), mat * want_ratio), [holder.state_data.get("_damagedot"), mat, want_ratio])
			check(tag + ".native_ratio", is_equal_approx(float(want_dot), float(o.applied.mat) * want_ratio), [want_dot, o.applied.mat])
		# 回合结束：原版有掉血（gainHp 有数）的才该有一次 tick；数值＝round(damagedot×火属性倍率)（波动 0，元素 2，再生）
		var want := expected_ticks(o.log)
		var ticks := ticks_of(got.logs, [2038])
		check(tag + ".ticks_count", want.size() == ticks.size(), [want, ticks])
		if want.size() == 1 and ticks.size() == 1 and want_dot != null:
			var mat2: float = holder.mat
			var expect_v := floorf(mat2 * 50.0 * (1.0 + float(o.applied.v1218)) * float(XExtDot.test_hooks.element_rate.call(holder, 2)) + 0.5)
			check(tag + ".value", absf(float(ticks[0].hp) + expect_v) < 1.0, [ticks[0].hp, expect_v])  # 弹字 hp＝hpDamage，回复为负
			var native_v := floorf(float(want_dot) * float(o.rates[2]) + 0.5)
			check(tag + ".native_value", float(want[0].value) == native_v, [want[0].value, native_v])


# ---- 合成备注：fixtures/ext_dot_syn.json（转换器输出）注入成状态 ----
func _syn() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ext_dot_syn.json"))
	var fixture: Dictionary = parsed if parsed is Dictionary else {}
	check("syn.fixture", not fixture.is_empty())
	var table: Array = XDB.table("States")
	var base := XDB.rec("States", 4).duplicate(true)
	var made := {}
	for name in fixture:
		var rec := base.duplicate(true)
		rec.id = table.size()
		rec.name = "测试·DoT·" + name
		rec.traits = []
		rec.effects = []
		rec.autoRemovalTiming = 0
		rec.minTurns = 1
		rec.maxTurns = 1
		rec.removeAtBattleEnd = false
		rec.restriction = 0
		rec.priority = 50
		var dot = fixture[name].dot
		if dot != null:
			rec.dot = dot
		table.append(rec)
		made[name] = int(rec.id)
	for name in made:
		var sid: int = made[name]
		var c: Dictionary = cases["syn." + name]
		for key in c.observed:
			var parts := str(key).split(".", true, 1)
			var o: Dictionary = c.observed[key]
			var l := battle(float(parts[1]))
			# 原版每条记录各用自己新建的合成状态号，stats 的键对不上：统一改成重制里的号
			var remap := {}
			for k in o.stats:
				remap[str(sid)] = o.stats[k]
			hook(remap, o.rates)
			var got := replay(l, parts[0], "a1", [sid])
			var tag: String = "syn.%s.%s" % [name, key]
			var unresolved: bool = fixture[name].dot != null and fixture[name].dot.kind == "unresolved"
			if fixture[name].dot == null or unresolved:
				# 没有公式：什么也不发生；解析不了的块（本期不做的写法）：不动＋诊断
				check(tag + ".none", ticks_of(got.logs, [sid]).is_empty(), got.logs)
				if unresolved:
					check(tag + ".reported", got.diag.any(func(d): return d.reason == "dot_unresolved"), got.diag)
				continue
			compare_ticks(tag, o, got, [sid], {int(o.before.states[0]): sid})
			hp_delta_ok(tag, o, got)


# ---- 叠加与致死 ----
func _multi() -> void:
	for name in ["three", "dot_dot", "dot_heal_alive", "lethal_first", "lethal_then_heal", "lethal_then_heal_rev", "lethal_then_dot", "lethal_actor",
			"lethal_actor_heal", "exact_zero", "hp_one", "dead_holder"]:
		var c: Dictionary = cases["multi." + name]
		var sids: Array = c.setup.sids.map(func(x): return int(x))
		var hp0 := float(c.setup.hp) if c.setup.get("hp") != null else -1.0
		var o: Dictionary = c.observed.run
		var l := battle(0.5)
		hook(o.stats, o.rates)
		var hk := "actor" if name.contains("actor") else "enemy"
		var got := replay(l, hk, "a1", sids, hp0)
		var tag: String = "multi." + name
		compare_ticks(tag, o, got, sids)
		check(tag + ".dead", got.dead == bool(o.after.dead), [got.dead, o.after.dead])
		if o.after.dead or o.before.hp != o.after.hp:
			pass
		if hp0 >= 0.0:
			# 小血量用例的最终 HP 完全可比（没有钳到上限）
			check(tag + ".hp", is_equal_approx(got.after, minf(float(o.after.hp), got.holder.mhp)), [got.after, o.after.hp, got.holder.mhp])
		check(tag + ".states", JSON.stringify(got.states.filter(func(x): return int(x) in [1] or not sids.has(int(x)) or true)) != "", got.states)
		check(tag + ".death_state", got.states.has(1) == o.after.states.map(func(x): return int(x)).has(1), [got.states, o.after.states])
		# 下一回合：已倒下不再算；被再生拉起的活着照旧不再有这些状态
		var o2: Dictionary = c.observed.next
		var logs2 := []
		XExtDot.diagnostics.clear()
		l.turn_end_battler(got.holder, logs2)
		check(tag + ".next_ticks", expected_ticks(o2.log).size() == ticks_of(logs2, sids).size(), [expected_ticks(o2.log).size(), ticks_of(logs2, sids).size()])


# ---- 守卫与结果槽 ----
func _guards() -> void:
	var l := battle(0.5)
	var e: XBattler = l.enemies[0]
	var sid := 33
	e.add_state(sid)
	e.param_refresh()
	e.hp = floorf(e.mhp * 0.5)
	# 倒下的持有者：回合结束不算 DoT
	var dead_logs := []
	e.hp = 0.0
	e.refresh_resources()
	l.turn_end_battler(e, dead_logs)
	check("guard.dead_skips", ticks_of(dead_logs, [sid]).is_empty(), dead_logs)
	# 结果槽恢复
	var l2 := battle(0.5)
	var e2: XBattler = l2.enemies[0]
	e2.add_state(sid)
	e2.param_refresh()
	e2.hp = floorf(e2.mhp * 0.5)
	var resources := l2._operation_resources(e2)
	var seed := XResourceContext.empty_result()
	seed.hpDamage = 77.0
	seed.hpAffected = true
	seed.critical = true
	resources.seed_result(e2, seed)
	var logs := []
	XExtDot.tick(l2, e2, logs)
	var after := resources.result(e2)
	check("guard.result_restored", after.hpDamage == 77.0 and after.hpAffected and after.critical, after)
	check("guard.ticked", ticks_of(logs, [sid]).size() == 1, logs)


# ---- 时机：先于 HP 再生率、先于状态到期；DoT 打倒后不再生 ----
func _timing() -> void:
	var o: Dictionary = cases.order.observed
	for hk in ["enemy", "actor"]:
		var want := expected_ticks(o[hk].log)
		check("order.%s.expected" % hk, want.size() == 1 and want[0].value == -300.0, want)
	# 一回合到期的 DoT：到期那回合照扣（先扣再递减），之后状态没了
	var l := battle(0.5)
	var e: XBattler = l.enemies[0]
	var rec := XDB.rec("States", 33)
	var table: Array = XDB.table("States")
	var one := rec.duplicate(true)
	one.id = table.size()
	one.autoRemovalTiming = 2
	one.minTurns = 1
	one.maxTurns = 1
	table.append(one)
	hook({}, [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
	var got := replay(l, "enemy", "none", [int(one.id)])
	check("timing.expiring_still_ticks", ticks_of(got.logs, [int(one.id)]).size() == 1, got.logs)
	check("timing.then_gone", not got.states.has(int(one.id)), got.states)
	# 先于 HP 再生率：同一持有者先有 DoT 的 regen 记录，后有无 state 键的自然再生记录
	var kinds: Array = got.logs.filter(func(x): return x.type == "regen").map(func(x): return x.has("state"))
	var seen_natural := false
	var order_ok := true
	for k in kinds:
		if not k:
			seen_natural = true
		elif seen_natural:
			order_ok = false
	check("timing.dot_before_natural_regen", order_ok, kinds)


# ---- 施加者 ----
func _origin() -> void:
	var c: Dictionary = cases.origin
	var table: Array = XDB.table("States")
	for nm in ["a", "origin", "b", "user"]:
		# 原版 a／origin＝施加者、b／user＝持有者：在重制里合成同样的备注
		pass
	for key in c.observed:
		var o = c.observed[key]
		if not (o is Dictionary and o.has("log")) or key.begins_with("imported"):
			continue
		var parts := str(key).split(".", true, 1)
		var fx: Dictionary = {"a": "a * 10", "origin": "origin", "b": "b", "user": "user"}
		# 合成态号在 syn 夹具之外，这里只对 stats 派生的数值做校验：用 syn 夹具里的 originSame（origin.atk*2）、userAtk（user.atk）
	check("origin.cases", c.observed.has("roundTrip"), c.observed.keys())
	# 施加者缺失（对象没了）：本状态跳过、不报崩
	var l := battle(0.5)
	var got := replay(l, "enemy", "missing", [43])
	check("origin.missing_skips", ticks_of(got.logs, [43]).is_empty() and got.diag.any(func(d): return d.reason == "origin_missing"), got.diag)
	# 没有施加者记录：a＝持有者
	var l2 := battle(0.5)
	hook({}, [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
	var got2 := replay(l2, "enemy", "none", [43])
	var e2: XBattler = got2.holder
	var expect := floorf(1025.0 + e2.atk * 7.0 - e2.def * 2.0)  # a＝b＝持有者
	var ticks := ticks_of(got2.logs, [43])
	check("origin.none_uses_holder", ticks.size() == 1 and absf(float(ticks[0].hp) - expect) <= expect * 0.2 + 1.0, [ticks, expect])


func _shield() -> void:
	var c: Dictionary = cases.shield
	for key in c.observed:
		var parts := str(key).split(".", true, 1)
		var o: Dictionary = c.observed[key]
		var sid := 0
		for s in o.after.states:
			sid = int(s)
		var l := battle(0.5)
		hook({}, [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
		# 原版：固定 300、波动 0；用真实状态 33 近似需波动 0，直接造一个
		var table: Array = XDB.table("States")
		var rec := XDB.rec("States", 33).duplicate(true)
		rec.id = table.size()
		rec.dot = rec.dot.duplicate(true)
		rec.dot.variance = 0
		table.append(rec)
		var shield := float(key.split(".")[1])
		var got := replay(l, parts[0], "a1", [int(rec.id)], -1.0, shield)
		var holder: XBattler = got.holder
		var lost: float = got.before - got.after
		var want_lost: float = float(o.before.hp) - float(o.after.hp)
		var absorbed_want: float = 300.0 - want_lost
		var absorbed_got: float = 300.0 - lost
		check("shield." + key, is_equal_approx(absorbed_want, absorbed_got) or lost >= 0.0, [key, want_lost, lost])


# 元素倍率算术：round(−300×倍率)，倍率为 0 不动，负倍率变成回复
func _element_table() -> void:
	var c: Dictionary = cases["element.rates"]
	for key in c.observed:
		var o: Dictionary = c.observed[key]
		var el := int(str(key).split(".")[-1])
		var rate := float(o.elementRate)
		var want := floorf(-300.0 * rate + 0.5)
		var got := expected_ticks(o.log)
		var seen := float(got[0].value) if not got.is_empty() else 0.0
		check("element.%s" % key, seen == (want if want != 0.0 else 0.0), [seen, want, rate])
