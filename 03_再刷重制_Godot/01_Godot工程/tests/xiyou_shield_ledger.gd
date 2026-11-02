extends Node
## 【cc·白龙_14·未经审查】共用来源护盾账本 XShieldLedger：照参照 shield_ledger_probe（tests/fixtures/shield_ledger_oracle.json）逐步比——
## grant（护盾效果加成、同源取较高、期限、opts）、gainHp／setHp 两处吸收（走 XResourceContext 的真钩子）、absorbRaceDamage、
## 回合末到期与衰减、撤销类；每步后比两人的生命、原生护盾、合计、累计挡下与账本各行。
## 参照是原版行为，所以比对时 O-144 开关 o_skip_unshielded 设回退值 false；另测默认开时 skip 行不再白挡。
## 另：战斗外不记、setup／end_battle／读档清空。
const FIXTURE := "res://tests/fixtures/shield_ledger_oracle.json"
var checks := 0
var failures: Array = []
var skip_flag := false


class BigActor extends XActor:
	func param(i: int) -> float:
		return 10000.0 if i == 0 else super.param(i)


class FakeLogic extends RefCounted:
	var turn := 1


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(600))


func _skip() -> bool:
	return skip_flag


func _actor(id: int) -> XActor:
	var a := BigActor.new()
	a.setup(id)
	a.hp = 5000.0
	a.shield = 0.0
	return a


func _row_view(r: Dictionary) -> Array:
	return [r.source, float(r.amount), int(r.until), int(r.owner), bool(r.noDecay), bool(r.noHalve), float(r.lastAbsorbed), float(r.absorbed)]


func _snap(actors: Dictionary) -> Dictionary:
	var out := {}
	for id in actors:
		var a: XActor = actors[id]
		out[str(id)] = {"hp": a.hp, "shield": a.shield, "total": XShieldLedger.total(a),
			"absorbed": float(XShieldLedger.absorbed_total.get(a.get_instance_id(), 0.0)), "rows": XShieldLedger.rows(a).map(_row_view)}
	return out


func _want(after: Dictionary) -> Dictionary:
	var out := {}
	for id in after:
		var v: Dictionary = after[id]
		out[id] = {"hp": float(v.hp), "shield": float(v.shield), "total": float(v.total), "absorbed": float(v.absorbed),
			"rows": (v.rows as Array).map(func(r): return [r.source, float(r.amount), int(r.until), int(r.owner) if r.owner != null else 0,
				bool(r.noDecay), bool(r.noHalve), float(r.lastAbsorbed), float(r.absorbed)])}
	return out


## 按参照的步骤跑一遍，返回每步后的快照（want 给了就逐步比）
func run(tag: String, steps: Array, want = null) -> Array:
	var logic := FakeLogic.new()
	XShieldLedger.setup(logic)
	skip_flag = false
	var actors := {1: _actor(1), 8: _actor(8)}
	var out := []
	for i in steps.size():
		var st: Array = steps[i]
		var op: String = st[0]
		var a: XActor = actors.get(int(st[1])) if st.size() > 1 and (st[1] is float or st[1] is int) else null
		var ret = null
		match op:
			"grant":
				var o: Dictionary = (st[6] if st.size() > 6 else {}).duplicate()
				if bool(o.get("skip", false)):
					o.skip = _skip
				ret = XShieldLedger.grant(a, str(st[2]), float(st[3]), float(st[4]), int(st[5]), o)
			"hurt":
				XResourceContext.new().gain(a, "hp", -float(st[2]))
			"set":
				XResourceContext.new().set_resource(a, "hp", float(st[2]))
			"race":
				ret = XShieldLedger.absorb_race(a, float(st[2]))
			"native":
				a.shield = float(st[2])
			"turn":
				logic.turn = int(st[1])
			"end":
				XShieldLedger.round_end()
			"revoke":
				ret = XShieldLedger.revoke(a, str(st[2]))
			"owner":
				XShieldLedger.revoke_owner(int(st[1]))
			"clear":
				XShieldLedger.clear(a)
			"skip":
				skip_flag = bool(st[1])
			"state":
				a.add_state(int(st[2]))
		var snap := _snap(actors)
		out.append(snap)
		if want != null:
			var w: Dictionary = want[i]
			check("%s.%d.%s" % [tag, i, op], snap == _want(w.after), [st, snap, _want(w.after)])
			if w.ret is Dictionary:
				check("%s.%d.ret" % [tag, i], ret is Dictionary and float(ret.remaining) == float(w.ret.remaining) and float(ret.absorbed) == float(w.ret.absorbed), [ret, w.ret])
			elif w.ret != null:
				check("%s.%d.ret" % [tag, i], ret != null and float(ret) == float(w.ret), [ret, w.ret])
	XShieldLedger.end_battle()
	return out


func _ready() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("oracle", ref.cases.size() == 11 and ref.cases.all(func(c): return (c.errors as Array).is_empty()))
	var obs := {}
	var setups := {}
	for c in ref.cases:
		obs[str(c.id)] = c.observed
		setups[str(c.id)] = c.setup
	check("params", XShieldLedger.decay_rate() == float(obs.params.decayRate) and XShieldLedger.reduction() == float(obs.params.reduction),
		[XShieldLedger.decay_rate(), XShieldLedger.reduction(), obs.params])
	# 参照是原版：回退值
	XShieldLedger.o_skip_unshielded = false
	for id in ["bonus", "same", "order", "native", "nohalve", "skip", "round", "race", "revoke"]:
		run(id, setups[id].steps, obs[id])
	# 默认开：skip 跳过的行不替角色挡；第一次 250：x 挡 100、剩 150 减半 75，生命 4925（原版 5000），花荫行不动
	XShieldLedger.o_skip_unshielded = true
	var snaps := run("skip.opt", setups.skip.steps)
	check("skip.opt.hp", snaps[3]["1"].hp == 4925.0 and snaps[3]["1"].rows.size() == 1 and float(snaps[3]["1"].rows[0][1]) == 300.0, snaps[3])
	check("skip.opt.after", snaps[5]["1"].hp == 4925.0 and float(snaps[5]["1"].rows[0][1]) == 50.0, snaps[5])
	# 默认开时别的例照旧（没有 skip 行）
	for id in ["order", "native", "nohalve", "race"]:
		run(id + ".opt", setups[id].steps, obs[id])
	# 战斗外不记
	var a := _actor(1)
	check("outside", XShieldLedger.grant(a, "x", 100.0, 2.0, 8) == float(obs.outside.ret) and XShieldLedger.rows(a).is_empty())
	# setup／end_battle／读档清空
	var logic := FakeLogic.new()
	XShieldLedger.setup(logic)
	XShieldLedger.grant(a, "x", 100.0, 2.0, 8)
	XShieldLedger.setup(logic)
	check("clear.setup", XShieldLedger.amount(a) == 0.0)
	XShieldLedger.grant(a, "x", 100.0, 2.0, 8)
	XShieldLedger.end_battle()
	check("clear.end", XShieldLedger.amount(a) == 0.0 and not XShieldLedger.active)
	XShieldLedger.setup(logic)
	XShieldLedger.grant(a, "x", 100.0, 2.0, 8)
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("clear.load", XShieldLedger.amount(a) == 0.0)
	XShieldLedger.end_battle()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_shield_ledger", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
