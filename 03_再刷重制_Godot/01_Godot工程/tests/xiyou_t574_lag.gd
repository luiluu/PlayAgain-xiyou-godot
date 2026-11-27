extends Node
## 【cc·未经审查】T574 西游档战斗卡顿续（T572 余项＋小o 核 T572 的发行口径长帧）：
## - XBattleLogic.FORCE_YIELD（O-681）：敌群事件／预约公共事件里每次 339 强制行动之后解释器停住，战斗画面演完这一次再续（一帧最多算一次）；
## - XActor.ABSORB_SCAN_FAST（O-682）：技能 id 表里「本人开放专武在不在」先查有没有专武写了本人，再逐处找、不拼表；
## - XDB.XIYOU_REC_FAST（O-683）：西游档取表内记录跳过只管天启篇档的改写层。
## 断言：开关两态结果逐项相同——取记录全表逐号同一个对象（西游档、没有存档、天启篇档）；专武判断各种摆法相同；
## 强制行动：无界面逐条续上与一次跑完、run_events 三种走法日志与战斗状态相同（连续两次／三次 339、第一次强制行动就打完战斗）；
## 带场景：同种子四倍速、一倍速各一遍，开关两态演出的记录次序、战斗结果相同。
var results := []
const DORIA := 96
const ZHULANG := 8152  # 朵莉亚「逐浪」：效果 44 预约公共事件 1222
const CE_ZHULANG := 1222  # 接连强制放 8151 欢歌·再释放（打敌全体）、8153 逐浪·再释放（奶我方全体）


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail).left(800))


func _plain(v, logic: XBattleLogic):
	if v is XBattler:
		return logic.stable_id(v)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(_plain(k, logic))] = _plain(v[k], logic)
		return out
	if v is Array:
		return v.map(func(x): return _plain(x, logic))
	if v is Object:
		return "<%s>" % v.get_class()
	if v is Callable:
		return "<callable>"
	return v


func _sig(l: XBattleLogic) -> String:
	var out := []
	for b in l.actors + l.enemies:
		out.append([l.stable_id(b), b.hp, b.mp, b.tp, b.state_ids.duplicate()])
	out.append(l.random.snapshot())
	out.append([l.is_won(), l.is_lost(), l.turn])
	return JSON.stringify(out)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_t574_lag"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	_rec_fast()
	_absorb()
	_force_headless()
	await _force_scene()
	XDB.XIYOU_REC_FAST = true
	XActor.ABSORB_SCAN_FAST = true
	XBattleLogic.FORCE_YIELD = true
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- O-683：XDB.rec 西游档快路，全表逐号比对 ----
const REC_TABLES := ["Actors", "Classes", "Skills", "Items", "Weapons", "Armors", "Enemies", "Troops", "States", "Animations", "CommonEvents"]

func _rec_all(tag: String) -> void:
	var bad := []
	var total := 0
	for nm in REC_TABLES:
		var t: Array = XDB.table(nm)
		for i in range(-1, t.size() + 2):
			XDB.XIYOU_REC_FAST = true
			var a := XDB.rec(nm, i)
			XDB.XIYOU_REC_FAST = false
			var b := XDB.rec(nm, i)
			total += 1
			if not is_same(a, b) and a != b:
				bad.append([nm, i])
	XDB.XIYOU_REC_FAST = true
	print("T574 rec %s total=%d bad=%d" % [tag, total, bad.size()])
	check("rec.%s_same" % tag, bad.is_empty() and total > 30000, [total, bad.slice(0, 10)])


func _rec_fast() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	_rec_all("xiyou")
	# 西游档快路命中时返回同一个对象（不另建副本）：表内一条普通技能就是底表那一条
	var sk: Array = XDB.table("Skills")
	check("rec.xiyou_identity", is_same(XDB.rec("Skills", 1), sk[1]))
	XState.current = null
	_rec_all("no_save")
	var tq := XTianqi.start_new_game(3, "jianxian", [21, 23, 3, 1, 2])
	XTianqi.take_pending()
	XState.current = tq
	_rec_all("tianqi")  # 天启篇档不走快路，两态本来就一样（守住快路的判档）
	# 快路确实省了：同一批技能号，开着比关着快
	XState.current = s
	var ids := range(1, mini(sk.size(), 3000))
	var t0 := Time.get_ticks_usec()
	for i in ids:
		XDB.rec("Skills", i)
	var fast := Time.get_ticks_usec() - t0
	XDB.XIYOU_REC_FAST = false
	t0 = Time.get_ticks_usec()
	for i in ids:
		XDB.rec("Skills", i)
	var slow := Time.get_ticks_usec() - t0
	XDB.XIYOU_REC_FAST = true
	print("T574 rec 3000 skills fast=%dus slow=%dus" % [fast, slow])
	check("rec.faster", fast < slow, [fast, slow])


# ---- O-682：本人开放专武在不在 ----
func _absorb() -> void:
	XActor.absorb_owners(0)
	var wid := -1
	var owner := -1
	for w in XActor._absorb_owners:
		wid = int(w)
		owner = int(XActor._absorb_owners[w][0])
		break
	check("absorb.fixture", wid > 0 and owner > 0, [wid, owner])
	if wid <= 0:
		return
	var s := XState.new_game(3, 1, [8, 9])
	XState.current = s
	s.set_switch(int(XItemMarks.SUPER_SWITCHES[0]), true)  # 开放超强者（高难度下没开放时 add_actor 会被拦、出战栏会被清）
	s.add_actor(owner)
	var holder: XActor = s.actor(8)
	var weapon := {"kind": "weapon", "base": wid, "id": wid, "name": "测试专武"}
	var other := {"kind": "weapon", "base": 1, "id": 1, "name": "普通兵器"}
	var cases := {
		"none": func(): pass,
		"bag_other_only": func(): s.gear.append(other),
		"in_bag": func(): s.gear.append(weapon),
		"on_other": func(): holder.equips[0] = weapon,
		"on_self": func(): s.actor(owner).equips[0] = weapon,
	}
	for name in cases:
		var keep_gear := s.gear.duplicate()
		var keep_holder = holder.equips[0]
		var keep_self = s.actor(owner).equips[0]
		cases[name].call()
		var res := {}
		for on in [true, false]:
			if on:
				XActor.ABSORB_SCAN_FAST = true
			else:  # 回退支（回退开关覆盖.py 认字面量）
				XActor.ABSORB_SCAN_FAST = false
			res[on] = s.party.map(func(id): return s.actor(id).has_absorb_weapon())
		XActor.ABSORB_SCAN_FAST = true
		check("absorb.%s_same" % name, res[true] == res[false], [res[true], res[false]])
		if name in ["in_bag", "on_other", "on_self"]:
			check("absorb.%s_owner_true" % name, bool(res[true][s.party.find(owner)]), res[true])
		s.gear = keep_gear
		holder.equips[0] = keep_holder
		s.actor(owner).equips[0] = keep_self
	XState.current = null


# ---- O-681：强制行动之后停顿（无界面）----
func _doria_state() -> XState:
	var s := XState.new_game(3, 1, [8, 9])
	XState.current = s
	s.random_master = XRandomStream.hex64(20261127)
	s.set_switch(int(XItemMarks.SUPER_SWITCHES[0]), true)  # 开放超强者（高难度下没开放时 add_actor 会被拦、出战栏会被清）
	s.add_actor(DORIA)
	for id in s.party:
		var a := s.actor(id)
		a.change_level_mv(60)
		a.refresh_passive()
		a.recover_all()
	var d := s.actor(DORIA)
	if not d.skill_ids.has(ZHULANG):
		d.learn_skill(ZHULANG)
	return s


## 走法：whole＝关停顿（同原来一次跑完）；step＝开停顿、逐次 resume_event；run＝开停顿、run_events
func _events(make: Callable, troop: int, kill: bool, mode: String, reserve: int, turns: int) -> Dictionary:
	seed(20261127)
	var s: XState = make.call()
	var l := XBattleLogic.new()
	l.yield_forced = mode != "whole"
	l.setup(troop, s, XBattleRandom.create("0000000000574574"))
	l.auto = true
	if kill:
		for e in l.enemies:
			e.hp = 1.0
	var logs := []
	var yields := 0
	if reserve > 0:
		XBattleCommonEvent.reserve(l, reserve, s.actor(DORIA))
	for t in turns:
		if t > 0:
			l.start_turn()
		if mode == "run":
			logs.append_array(l.run_events(l.next_subject() if t > 0 else null))
		else:
			logs.append_array(l.troop_events(l.next_subject() if t > 0 else null))
			while l.is_event_waiting():
				var w := l.event_waiting()
				if not bool(w.get("yield", false)):
					logs.append_array(l.resume_event(int(w.token), w.msg.get("default", null)))
					continue
				yields += 1
				logs.append_array(l.resume_event(int(w.token)))
		if l.is_over():
			break
	var forced := logs.filter(func(x): return x is Dictionary and str(x.get("type", "")) == "action").size()
	return {"logs": JSON.stringify(_plain(logs, l)).sha256_text(), "sig": _sig(l), "yields": yields, "forced": forced, "won": l.is_won(), "size": logs.size()}


## run_turn 打到结束（最多 8 回合），原始日志不做摘要以外的处理（保留 message.token）
func _run_turns(make: Callable, troop: int) -> Dictionary:
	seed(572001)
	var s: XState = make.call()
	var l := XBattleLogic.new()
	l.yield_forced = true
	l.setup(troop, s, XBattleRandom.create(XRandomStream.hex64(572001)))
	l.auto = true
	l.enemies[0].hp = maxf(1.0, floorf(l.enemies[0].mhp * 0.19))
	var logs := []
	var rounds := 0
	while rounds < 8 and not l.is_over():
		rounds += 1
		logs.append_array(l.run_turn({}))
	var tokens := logs.filter(func(x): return x is Dictionary and str(x.get("type", "")) == "message").map(func(x): return int(x.token))
	var text := JSON.stringify(_plain(logs, l))
	return {"logs": text.sha256_text(), "size": text.length(), "sig": _sig(l), "tokens": tokens, "yields": -l._yield_token, "rounds": rounds}


func _force_headless() -> void:
	# 预约公共事件 1222：接连两次 339（8151 打敌全体、8153 奶我方全体）
	for kill in [false, true]:
		var tag := "ce1222" + ("_battle_end" if kill else "")
		var res := {}
		for mode in ["whole", "step", "run"]:
			res[mode] = _events(_doria_state, 2, kill, mode, CE_ZHULANG, 1)
		print("T574 %s whole=%s step=%s" % [tag, JSON.stringify(res.whole).left(200), JSON.stringify(res.step).left(200)])
		check(tag + ".two_forced", int(res.whole.forced) >= 2, res.whole)
		check(tag + ".step_yields", int(res.step.yields) == 2 and int(res.whole.yields) == 0, [res.step.yields, res.whole.yields])
		check(tag + ".step_same", res.step.logs == res.whole.logs and res.step.sig == res.whole.sig, [res.step, res.whole])
		check(tag + ".run_same", res.run.logs == res.whole.logs and res.run.sig == res.whole.sig, [res.run, res.whole])
		if kill:
			check(tag + ".won_mid_event", bool(res.whole.won), res.whole)
	# 敌群 776 第 1 回合页：接连三次 339（霸者领域／回归／放逐）
	var mk := func() -> XState:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		s.random_master = XRandomStream.hex64(20261117)
		for a in s.members():
			a.change_level_mv(99)
			a.refresh_passive()
			a.recover_all()
		return s
	var r776 := {}
	for mode in ["whole", "step", "run"]:
		r776[mode] = _events(mk, 776, false, mode, 0, 2)
	check("t776.three_yields", int(r776.step.yields) == 3, r776.step)
	check("t776.step_same", r776.step.logs == r776.whole.logs and r776.step.sig == r776.whole.sig, [r776.step, r776.whole])
	check("t776.run_same", r776.run.logs == r776.whole.logs and r776.run.sig == r776.whole.sig, [r776.run, r776.whole])
	# 敌群 830（小o 合包核 P1-2）：首名敌人 19% 生命，敌群页先 339 强制行动再 101 文字。run_turn（无界面宿主，开着 yield_forced）
	# 打到结束，开关两态原始日志（含 message.token）逐字相同；停顿走自己的负数 token，不推进消息的 token
	var t830 := {}
	for on in [true, false]:
		if on:
			XBattleLogic.FORCE_YIELD = true
		else:
			XBattleLogic.FORCE_YIELD = false
		t830[on] = _run_turns(mk, 830)
	XBattleLogic.FORCE_YIELD = true
	print("T574 t830 on=%s off=%s" % [JSON.stringify(t830[true]).left(300), JSON.stringify(t830[false]).left(300)])
	check("t830.has_message_after_yield", int(t830[true].yields) > 0 and (t830[true].tokens as Array).size() > 0, t830[true])
	check("t830.tokens_same", t830[true].tokens == t830[false].tokens, [t830[true].tokens, t830[false].tokens])
	check("t830.raw_same", t830[true].logs == t830[false].logs and t830[true].sig == t830[false].sig, [t830[true].size, t830[false].size])
	# 回退：FORCE_YIELD 关着时开了 yield_forced 也不停
	XBattleLogic.FORCE_YIELD = false
	var off := _events(_doria_state, 2, false, "step", CE_ZHULANG, 1)
	XBattleLogic.FORCE_YIELD = true
	check("rollback.no_yield", int(off.yields) == 0, off)


# ---- O-681：带场景（同种子；四倍速、一倍速各一遍；开关两态）----
class P extends XBattleScene:
	var rec := []
	var result := -1
	var inputs := 0
	var max_inputs := 2
	func _command(u: XBattler):
		inputs += 1
		if inputs > max_inputs:
			await get_tree().create_timer(100).timeout
			return [null, null]
		return await super._command(u)
	func _play(logs: Array) -> void:
		for l in logs:
			rec.append(JSON.stringify(_pl(l)))
		await super._play(logs)
	func _pl(v):
		if v is XBattler:
			return logic.stable_id(v)
		if v is Dictionary:
			var out := {}
			for k in v:
				out[str(_pl(k))] = _pl(v[k])
			return out
		if v is Array:
			return v.map(func(x): return _pl(x))
		if v is Object or v is Callable:
			return "<obj>"
		return v


func _scene(speed: int, troop: int, make: Callable, kill: bool, reserve: int) -> Dictionary:
	XConfig.set_battle_speed(speed)
	XConfig.set_flag("CombatSkillAnimation", false)
	seed(20261127)
	var s: XState = make.call()
	var scene := P.new()
	scene.force_auto = true
	scene.setup(troop, true, true, {})
	if kill:
		for e in scene.logic.enemies:
			e.hp = 1.0
	if reserve > 0:
		XBattleCommonEvent.reserve(scene.logic, reserve, s.actor(DORIA))
	scene.finished.connect(func(r): scene.result = r)
	var t0 := Engine.get_physics_frames()
	add_child(scene)
	while scene.result < 0 and scene.inputs <= scene.max_inputs and Engine.get_physics_frames() - t0 < 6000:
		await get_tree().physics_frame
	var out := {"rec": JSON.stringify(scene.rec), "n": scene.rec.size(), "sig": _sig(scene.logic), "result": scene.result, "frames": Engine.get_physics_frames() - t0}
	scene.queue_free()
	await get_tree().physics_frame
	return out


func _force_scene() -> void:
	var mk776 := func() -> XState:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		s.random_master = XRandomStream.hex64(20261117)
		for a in s.members():
			a.change_level_mv(99)
			a.refresh_passive()
			a.recover_all()
		return s
	for speed in [1, 4]:  # 1＝四倍速，4＝一倍速（OFF）
		for c in [["t776", 776, mk776, false, 0], ["ce1222_end", 2, _doria_state, true, CE_ZHULANG]]:
			var res := {}
			for on in [true, false]:
				if on:
					XBattleLogic.FORCE_YIELD = true
				else:
					XBattleLogic.FORCE_YIELD = false
				res[on] = await _scene(speed, int(c[1]), c[2], bool(c[3]), int(c[4]))
			XBattleLogic.FORCE_YIELD = true
			var tag := "scene.%s_x%d" % [c[0], speed]
			print("T574 %s on n=%d frames=%d result=%d / off n=%d frames=%d result=%d" % [tag, res[true].n, res[true].frames, res[true].result, res[false].n, res[false].frames, res[false].result])
			check(tag + ".played", int(res[true].n) > 0, res[true])
			check(tag + ".same_order", res[true].rec == res[false].rec, [res[true].rec.left(400), res[false].rec.left(400)])
			check(tag + ".same_result", res[true].sig == res[false].sig and res[true].result == res[false].result, [res[true].sig.left(300), res[false].sig.left(300), res[true].result, res[false].result])
			if c[0] == "ce1222_end":
				check(tag + ".won", int(res[true].result) == 0, res[true].result)
