extends Node
## 【cc·悟空·未经审查】渡鸦魔法反射支＋饿狼 critical 0 伤：与 mv_oracle/raven_reflect_probe.cjs 的冻结 v0.28 参照
## （tests/fixtures/raven_reflect_oracle.json，真实 BattleManager）逐例比。
## - reflect.*：目标 mrf 强设 1，渡鸦技能（hitType 2 魔法，不是必中）被反射回渡鸦自己；原版 Game_Action.apply 的渡鸦包装照样记帧：
##   鸦啄回 MP、二阶盛宴／万魂归鸦附加黑暗侵蚀、狩猎（×1）与神话回响（×0.85）的追加伤害落在渡鸦自己身上（会倒下）；
## - noreflect.*／edge.*：同技能不反射的对照；mrf 0.5（随机 0.5 不小于 0.5）不反射，0.51 反射；
## - garouzero.*：饿狼拳法基伤为 0（出手者攻魔强设 0）、暴击率 1 时伤害 0、暴击标记假（applyCritical v===0 返回 0 在原版链里与普通链一致）。
## 数值比本例第一段命中的比值；结构（谁挨打、直接扣血的目标与次序）、MP、神话回合、残响、狩猎、倒下、侵蚀逐项比。
const FIXTURE := "res://tests/fixtures/raven_reflect_oracle.json"
const PROGRAMS := "res://tests/fixtures/formula_effect_programs.json"
const RATIO_TOLERANCE := 1e-6
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 30:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _fake_state(xparam_id: int, value: float, code := 22) -> int:
	var t: Array = XDB.table("States")
	var id := t.size()
	t.append({"id": id, "name": "测试状态%d" % xparam_id, "traits": [{"code": code, "dataId": xparam_id, "value": value}],
		"note": "", "meta": {}, "iconIndex": 0, "restriction": 0, "autoRemovalTiming": 0, "removeAtBattleEnd": true})
	return id


func _logic(s: XState, domain: String) -> XBattleLogic:
	var rand := XBattleRandom.create(domain)
	rand.rule = FixedMidStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e12
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	return logic


## 同参照 battle()：渡鸦阶 rank、level 级、招募、队伍 [167, 1]，生命各加 1e12
func _raven(rank: int, level: int) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	s.actor_advance[XRaven.ACTOR] = rank
	var a := s.actor(XRaven.ACTOR)
	a.change_level_mv(level)
	check("setup.recruit", XRaven.recruit(s))
	s.add_actor(1)
	for id in s.party:
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
	var logic := _logic(s, "0000000000000167")
	for id in s.party:
		var b := s.actor(id)
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	logic.start_turn()
	return [logic, a]


func _garou(stage: int, level: int) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	s.actor_advance[XGarou.ACTOR] = stage
	var a := s.actor(XGarou.ACTOR)
	a.change_level_mv(level)
	check("setup.recruit_garou", XGarou.recruit(s))
	s.add_actor(1)
	for id in [XGarou.ACTOR, 1]:
		s.actor(id).add_param(0, 1e12)
		s.actor(id).refresh_passive()
	var logic := _logic(s, "0000000000000173")
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	return [logic, a]


## raven2：云裳／饿狼的魔法技能被反射（refx.*）：同参照 xbattle()（队伍 [id, 1] 各 55 级、全员生命 +1e12）
func _refx(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var id := int(setup.actor)
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	var a: XActor = s.actor(id)
	a.change_level_mv(55)
	s.add_actor(id)  # 参照不招募（直接设队伍），所以不走 recruit（会换装备）
	s.add_actor(1)
	for pid in s.party:
		s.actor(pid).add_param(0, 1e12)
		s.actor(pid).refresh_passive()
	var logic := _logic(s, "%016d" % id)
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	logic.start_turn()
	a.learn_skill(int(setup.skill))
	a.mp = a.mmp
	a.tp = 0.0
	var mrf_state := -1
	if bool(setup.reflect):
		mrf_state = _fake_state(5, 1.0)
		for e in logic.enemies:
			e.add_state(mrf_state)
	var logs := _log(logic, logic.act(a, XDB.rec("Skills", int(setup.skill)), logic.enemies[0]))
	var want: Dictionary = c.observed
	var gs: Array = logs.map(func(l): return [l.kind, l.target, snappedf(l.value, 1.0)])
	var ws: Array = (want.log as Array).map(func(l): return [str(l.kind), str(l.target), snappedf(float(l.value), 1.0)])
	check(c.id + ".hits", gs == ws, [gs, ws])
	check(c.id + ".hp", absf(a.hp - float(want.hp)) <= 1.0, [a.hp, want.hp])
	check(c.id + ".mp", absf(a.mp - float(want.mp)) <= 1.0, [a.mp, want.mp])
	var st_got := a.state_ids.duplicate()
	st_got.sort()
	var st_want: Array = (want.states as Array).map(func(v): return int(v))
	st_want.sort()
	check(c.id + ".states", st_got == st_want, [st_got, st_want])
	var fs: Array = logic.enemies.map(func(e): var ids = e.state_ids.filter(func(v): return v != mrf_state); ids.sort(); return ids)
	var fw: Array = (want.foeStates as Array).map(func(l): var ids = (l as Array).map(func(v): return int(v)); ids.sort(); return ids)
	check(c.id + ".foeStates", fs == fw, [fs, fw])


## raven2→3：普通角色（8 号）被自己的「全体魔法加黑暗侵蚀」反射：借 10124 的数据槽（同参照改写），tcr 强设 0.01／2
func _refstate(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	var a: XActor = s.actor(8)
	a.change_level_mv(60)
	s.add_actor(8)
	s.add_actor(1)
	for pid in s.party:
		s.actor(pid).add_param(0, 1e12)
		s.actor(pid).refresh_passive()
	var logic := _logic(s, "refstate")
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	logic.start_turn()
	var sk: Dictionary = XDB.rec("Skills", 10124).duplicate(true)
	sk.damage.formula = "10000000"
	sk.damage.elementId = 9
	sk["effects"] = [{"code": 21, "dataId": 1663, "value1": 1.0, "value2": 0.0}]
	sk.scope = 2
	sk.repeats = 1
	sk.hitType = 2
	sk.mpCost = 0
	sk.tpCost = 0
	sk["meta"] = {}
	sk["note"] = ""
	a.mp = a.mmp
	a.tp = 0.0
	a.add_state(_fake_state(5, float(setup.tcr), 23))
	var mrf_state := -1
	if bool(setup.reflect):
		mrf_state = _fake_state(5, 1.0)
		for e in logic.enemies:
			e.add_state(mrf_state)
	var logs := _log(logic, logic.act(a, sk, logic.enemies[0]))
	var want: Dictionary = c.observed
	# 这个槽的伤害公式是转换器编好的程序，改写字符串公式不生效，所以只比结构与相对第一击的比值（一击 ×1 还是 ×1.555 正是要看的）
	var gs: Array = logs.map(func(l): return [l.kind, l.target])
	var ws: Array = (want.log as Array).map(func(l): return [str(l.kind), str(l.target)])
	check(c.id + ".hits", gs == ws, [gs, ws])
	if logs.size() == (want.log as Array).size() and not logs.is_empty():
		for k in logs.size():
			var rg: float = float(logs[k].value) / float(logs[0].value)
			var rw: float = float(want.log[k].value) / float(want.log[0].value)
			check("%s.ratio%d" % [c.id, k], absf(rg - rw) <= 1e-3 * maxf(1.0, rw), [rg, rw])
	var st_got := a.state_ids.filter(func(v): return v != 0 and XDB.rec("States", v).get("name", "").begins_with("测试状态") == false)
	st_got.sort()
	var st_want: Array = (want.states as Array).map(func(v): return int(v))
	st_want.sort()
	check(c.id + ".states", st_got == st_want, [st_got, st_want])


## raven4：嵌套 apply 用（同参照在第一段的 applyItemUserEffect 之后对同一目标再 apply 一次）
class NestLogic extends XBattleLogic:
	var hook := Callable()
	func _apply_core(u: XBattler, skill: Dictionary, t: XBattler) -> Dictionary:
		var r := super(u, skill, t)
		if hook.is_valid():
			var h := hook
			hook = Callable()
			h.call(u, skill, t)
		return r


## 常量公式程序（借 formula_effect_programs 的 constant100 模板改字面量）
func _const_program(v: float) -> Dictionary:
	var p: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(PROGRAMS))["runtime.constant100"].program as Dictionary).duplicate(true)
	p.steps[0].value.value = v
	return p


## 同参照 stateSkill：借 10124 的槽，必中、黑暗、常量伤害，可选加黑暗侵蚀
func _state_skill(o: Dictionary) -> Dictionary:
	var sk: Dictionary = XDB.rec("Skills", 10124).duplicate(true)
	var v := float(o.get("formula", 100.0 if o.get("small", false) else 1000000.0))
	sk["damage"] = {"type": 0 if o.get("dmg", true) == false else 1, "elementId": 9, "formula": str(v), "formulaGd": str(v),
		"formulaProgram": _const_program(v), "variance": 0, "critical": false}
	sk["effects"] = [{"code": 21, "dataId": 1663, "value1": 1.0, "value2": 0.0}] if o.get("state", false) else []
	sk.scope = int(o.get("scope", 1))
	sk.repeats = int(o.get("repeats", 1))
	sk.hitType = 0
	sk.successRate = 100
	sk.mpCost = 0
	sk.tpCost = 0
	sk.tpGain = 0
	sk["meta"] = {}
	sk["note"] = ""
	sk.erase("yepSeq")  # 参照这两个槽是 YEP 默认序列（运行时改的 repeats 照样生效）；重制的序列路径段数写死在序列里，走普通路径（同默认序列）
	return sk


## 同参照 seqBattle：队伍 [8, 1] 60 级，1 号与敌人生命 +1e12，8 号生命上限 2e6、TP 0、tcr 强设
func _seq_battle(tcr: float, nest := false) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [8, 1]:
		s.actor(id).change_level_mv(60)
		s.add_actor(id)
	s.actor(1).add_param(0, 1e12)
	for pid in s.party:
		s.actor(pid).refresh_passive()
	var rand := XBattleRandom.create("refseq")
	rand.rule = FixedMidStream.new()
	rand.rule.domain = "rule"
	var logic: XBattleLogic = NestLogic.new() if nest else XBattleLogic.new()
	logic.setup(3, s, rand)
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
	var a: XActor = s.actor(8)
	a.add_param(0, 2e6 - a.mhp)
	a.param_mark_dirty()
	a.param_refresh()
	a.recover_all()
	a.tp = 0.0
	logic.start_turn()
	a.add_state(_fake_state(5, tcr, 23))
	return [logic, a]


func _hits(logic: XBattleLogic, logs: Array) -> Array:
	return _log(logic, logs).filter(func(l): return l.kind == "hit")


func _ratio_check(id: String, got: Array, want: Array) -> void:
	var gs: Array = got.map(func(l): return str(l.target))
	var ws: Array = want.map(func(l): return str(l.target))
	check(id + ".targets", gs == ws, [gs, ws])
	if gs != ws or got.is_empty():
		return
	for k in got.size():
		var rg: float = float(got[k].value) / float(got[0].value)
		var rw: float = float(want[k].value) / float(want[0].value)
		check("%s.ratio%d" % [id, k], absf(rg - rw) <= 1e-3 * maxf(1.0, rw), [got.map(func(l): return l.value), want.map(func(l): return l.value)])


## raven4（审查 43 P3-1）：跨行动。行动 N 后 8 号身上的侵蚀陈旧与否，行动 N+1 别人打 8 号第一击读到哪个
func _refseq(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var between := str(setup.between)
	var r := _seq_battle(float(setup.tcr))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var want: Dictionary = c.observed
	var x := _state_skill({"state": true})
	var first: Array
	if between.begins_with("reflect"):
		x.hitType = 2
		var mrf := _fake_state(5, 1.0)
		for e in logic.enemies:
			e.add_state(mrf)
		first = _hits(logic, logic.act(a, x, logic.enemies[0]))
		for e in logic.enemies:
			e.remove_state(mrf)
	else:
		first = _hits(logic, logic.act(logic.enemies[0], x, a))
	check(c.id + ".tp", absf(a.tp - float(want.tp)) <= 1e-6, [a.tp, want.tp])
	if between.ends_with("turn"):
		logic.end_turn()
		logic.start_turn()
	if between.ends_with("self"):
		logic.act(a, XDB.rec("Skills", 1), logic.enemies[0])
	var y := _state_skill({"repeats": 2, "scope": 7, "formula": 100000.0} if between.ends_with("ally") else {"repeats": 2})
	var second: Array
	if between.ends_with("ally"):
		second = _hits(logic, logic.act(s_actor(logic, 1), y, a))
	else:
		second = _hits(logic, logic.act(logic.enemies[1], y, a))
	_ratio_check(c.id + ".second", second, want.second)
	# 第一击读的是不是新状态：出手者同类（都是敌人、非反射）时再比第二次行动第一击对行动 N 那一击的比值
	if not between.begins_with("reflect") and not between.ends_with("ally") and not first.is_empty() and not second.is_empty():
		var rg: float = float(second[0].value) / float(first[0].value)
		var rw: float = float(want.second[0].value) / float(want.first[0].value)
		check(c.id + ".cross", absf(rg - rw) <= 1e-3 * maxf(1.0, rw), [rg, rw])


func s_actor(logic: XBattleLogic, id: int) -> XActor:
	for b in logic.actors:
		if b is XActor and b.actor_id == id:
			return b
	return null


## raven4（审查 43 P3-2）：e0 对 8 号两段加侵蚀，第一段 applyItemUserEffect 之后对 8 号再 apply 一次内层行动；看外层第二段
func _refnest(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var inner := str(setup.inner)
	var r := _seq_battle(float(setup.tcr), true)
	var logic: NestLogic = r[0]
	var a: XActor = r[1]
	var want: Dictionary = c.observed
	var x := _state_skill({"state": true, "repeats": 2})
	var z := _state_skill({"dmg": inner != "none", "small": inner == "small"})
	var inner_hits := []
	logic.hook = func(_u, _sk, t):
		if is_same(t, a):
			inner_hits.append(logic.apply(logic.enemies[1], z, a))
	var outer := _hits(logic, logic.act(logic.enemies[0], x, a))
	var ow: Array = (want.log as Array).filter(func(l): return str(l.user) == "e0")
	_ratio_check(c.id + ".outer", outer, ow)
	check(c.id + ".nested", inner_hits.size() == int(want.nested), [inner_hits.size(), want.nested])
	var iw: Array = (want.log as Array).filter(func(l): return str(l.user) == "e1")
	var ig: Array = inner_hits.filter(func(l): return float(l.get("hp", 0.0)) != 0.0)
	check(c.id + ".inner_hit", ig.size() == iw.size(), [ig.size(), iw.size()])
	check(c.id + ".tp", absf(a.tp - float(want.tp)) <= 1e-6, [a.tp, want.tp])


## 开关回退支：XBattleLogic.STALE_TIMING = false 时回到 raven3（每次行动开头清全体、嵌套不处理）。
## 参照里会因此不一样的两例（refseq.tcr2.reflect 第二次行动第一击、refnest.tcr2.none 外层第二段）此时应读到新状态（比值 ×1.4/0.9 不出现）
func _rollback_branch(ref: Dictionary) -> void:
	XBattleLogic.STALE_TIMING = false
	for c in ref.cases:
		if c.id == "refseq.tcr2.reflect":
			var r := _seq_battle(2.0)
			var logic: XBattleLogic = r[0]
			var a: XActor = r[1]
			var x := _state_skill({"state": true})
			x.hitType = 2
			var mrf := _fake_state(5, 1.0)
			for e in logic.enemies:
				e.add_state(mrf)
			logic.act(a, x, logic.enemies[0])
			for e in logic.enemies:
				e.remove_state(mrf)
			var second := _hits(logic, logic.act(logic.enemies[1], _state_skill({"repeats": 2}), a))
			check("rollback.refseq.reflect", second.size() == 2 and absf(float(second[1].value) / float(second[0].value) - 1.0) <= 1e-6,
				second.map(func(l): return l.value))
		elif c.id == "refnest.tcr2.none":
			var r := _seq_battle(2.0, true)
			var logic: NestLogic = r[0]
			var a: XActor = r[1]
			var z := _state_skill({"dmg": false})
			logic.hook = func(_u, _sk, t):
				if is_same(t, a):
					logic.apply(logic.enemies[1], z, a)
			var outer := _hits(logic, logic.act(logic.enemies[0], _state_skill({"state": true, "repeats": 2}), a))
			check("rollback.refnest.none", outer.size() == 2 and absf(float(outer[1].value) / float(outer[0].value) - 1.4 / 0.9) <= 1e-3,
				outer.map(func(l): return l.value))
	XBattleLogic.STALE_TIMING = true


func _key(logic: XBattleLogic, b) -> String:
	return "a%d" % b.actor_id if b is XActor else "e%d" % logic.enemies.find(b)


func _log(logic: XBattleLogic, logs: Array) -> Array:
	var out := []
	for l in logs:
		if l.get("type") == "hit" and l.has("user") and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)) \
				and int(l.skill.get("damage", {}).get("type", 0)) in [1, 5]:
			out.append({"kind": "hit", "target": _key(logic, l.target), "value": float(l.hp), "critical": bool(l.critical)})
		elif l.get("type") == "regen" and l.has("raven"):
			out.append({"kind": "direct", "target": _key(logic, l.target), "value": float(l.hp), "critical": null})
	return out


func _snap(logic: XBattleLogic, a: XActor, log: Array) -> Dictionary:
	return {"log": log, "myth": XRaven.myth_turns(a), "residue": XRaven.residue(a), "hunter": XRaven.hunter(a), "mp": a.mp,
		"dead": logic.enemies.map(func(e): return e.is_dead()), "erosion": logic.enemies.map(func(e): return e.state_ids.has(XRaven.EROSION)),
		"self": {"dead": a.is_dead(), "erosion": a.state_ids.has(XRaven.EROSION)}}


func _cast(logic: XBattleLogic, a: XActor, id: int, target := 0) -> Dictionary:
	a.mp = a.mmp
	return _snap(logic, a, _log(logic, logic.act(a, XDB.rec("Skills", id), logic.enemies[target])))


## 逐项比：扣血段结构逐条，数值比本例第一段命中的比值
func _compare(id: String, got: Dictionary, want: Dictionary, with_state := true) -> void:
	var gl: Array = got.log
	var wl: Array = want.log
	var gs: Array = gl.map(func(l): return [l.kind, l.target, l.critical])
	var ws: Array = wl.map(func(l): return [str(l.kind), str(l.target), null if l.get("critical") == null else bool(l.critical)])
	check(id + ".log", gs == ws, [gs, ws, gl])
	if gs == ws:
		var base_g := 0.0
		var base_w := 0.0
		for k in gs.size():
			if base_g == 0.0 and float(wl[k].value) != 0.0:
				base_g = float(gl[k].value)
				base_w = float(wl[k].value)
			if base_w == 0.0:
				check("%s.zero%d" % [id, k], float(gl[k].value) == 0.0 and float(wl[k].value) == 0.0, [gl[k].value, wl[k].value])
				continue
			check("%s.abs%d" % [id, k], absf(float(gl[k].value) - float(wl[k].value)) <= 1e-6 * maxf(1.0, absf(float(wl[k].value))), [gl[k].value, wl[k].value])  # 绝对值（raven2）
			var rg: float = float(gl[k].value) / base_g
			var rw: float = float(wl[k].value) / base_w
			check("%s.ratio%d" % [id, k], absf(rg - rw) <= RATIO_TOLERANCE * maxf(1.0, absf(rw)), [gl[k].value, wl[k].value, rg, rw])
	if not with_state:
		return
	var keys := ["myth", "residue", "hunter", "mp", "dead", "erosion", "self"]
	var g := [int(got.myth), int(got.residue), bool(got.hunter), float(got.mp), got.dead, got.erosion, got.self]
	var w := [int(want.myth), int(want.residue), bool(want.hunter), float(want.mp), (want.dead as Array).map(func(v): return bool(v)),
		(want.erosion as Array).map(func(v): return bool(v)), {"dead": bool(want.self.dead), "erosion": bool(want.self.erosion)}]
	check(id + ".state", g == w, [keys, g, w])


func _reflect(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var r := _raven(5, 60)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	if not str(c.id).begins_with("reflect.edge"):  # 参照的 edge 两例没加魔防
		a.add_param(5, 1e6)  # 同参照：魔防 +1e6，自伤远小于生命上限
		a.param_mark_dirty()
		a.param_refresh()
	var mode := str(setup.get("mode", "plain"))
	var mrf := 1.0
	if c.id == "reflect.edge.0.5":
		mrf = 0.5
	elif c.id == "reflect.edge.0.51":
		mrf = 0.51
	if str(c.id).begins_with("reflect"):
		var st := _fake_state(5, mrf)
		for e in logic.enemies:
			e.add_state(st)
	if setup.has("tcr"):
		a.add_state(_fake_state(5, float(setup.tcr), 23))  # 同参照强设 tcr（sparam 5 ＝ 受伤充 TP 倍率）
	var store: Dictionary = XState.current.raven
	if "myth" in mode:
		store["myth"] = 3
	if "hunt" in mode:
		store["residue"] = 3
		store["hunter"] = true
	var id := int(setup.get("skill", XRaven.PECK))
	_compare(c.id, _cast(logic, a, id), c.observed)


func _garou_zero(c: Dictionary) -> void:
	var setup: Dictionary = c.setup
	var r := _garou(int(setup.stage), 60)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	if bool(setup.zero):
		a.add_param(2, -1e13)  # atk
		a.add_param(4, -1e13)  # mat
		a.param_mark_dirty()
		a.param_refresh()
	var st := _fake_state(2, 1.0)  # cri xparam 2 ＝ +100%
	a.add_state(st)
	var logs := _log(logic, logic.act(a, XDB.rec("Skills", int(setup.skill)), logic.enemies[0]))
	var want: Array = c.observed.log
	var gs: Array = logs.map(func(l): return [l.kind, l.target, l.critical, l.value == 0.0])
	var ws: Array = want.map(func(l): return ["hit", str(l.target), bool(l.critical), float(l.value) == 0.0])
	check(c.id + ".hits", gs == ws, [gs, ws, logs])
	# applyCritical(v) 的直接量：v===0 返回 0（原版链里对饿狼与普通出手者都一样），重制暴击是乘区，0 乘任何倍率仍是 0
	check(c.id + ".direct0", (c.observed.direct as Array)[0] == 0 and (c.observed.direct as Array)[2] == 0)


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match kind:
			"reflect", "noreflect":
				_reflect(c)
			"garouzero":
				_garou_zero(c)
			"refx":
				_refx(c)
			"refstate":
				_refstate(c)
			"refseq":
				_refseq(c)
			"refnest":
				_refnest(c)
	_rollback_branch(ref)
	check("covers_all", seen.keys().size() == 7, seen.keys())
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_raven_reflect", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
