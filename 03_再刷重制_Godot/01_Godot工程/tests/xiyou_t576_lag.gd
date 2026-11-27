extends Node
## 【cc·未经审查】T576 西游档战斗卡顿续（T574 余项，小o 核 T572＋T574 的 P1-1）：XActor.SKILLS_HOLD（O-684）
## 技能 id 表在战斗里跨「轻写入」保留：HP／MP／TP 写入、gain 末尾标脏、refresh 末尾被动缓存换新、不带技能的状态增减之后照用上一次的 id 表，
## 这些写入也不再让技能记录换代；学／忘技能、换装、STATE_HARD 状态、行动开头等照旧全部作废，本人的等级、职业、装备、状态、陈旧状态、
## 学会的技能、背包件数、异化借装备标记取用时逐项比；谷雨、穿空袖藏星天衣的、异化词条角色不保留。
## 断言：
## - 单元：各种写入之后保留的 id 表与现算逐项相同；轻写入之后确实命中；易变角色不留；end_battle 关掉；回退支每次现算；
## - 无界面整场：同种子开关两态逐字相同（西游档敌群 2／70、预约公共事件 1222 连续两次强制行动、天启篇档），开着时 READ_VERIFY 零差异；
##   1222 那一次 id 表现算次数开着远少于关着；
## - 带场景：同种子四倍速、一倍速各一遍，开关两态演出的全部记录（逐条序列化）、战斗结果相同。
var results := []
const DORIA := 96
const CE_ZHULANG := 1222  # 朵莉亚「逐浪」预约的公共事件：接连强制放 8151（打敌全体）、8153（奶我方全体 HP／MP／TP）
const SKILL_STATE := 971  # 破阵——天眷之雾：特性 43 加技能 5525（STATE_HARD）
const SKILL_STATE_ADD := 5525


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
		out.append([l.stable_id(b), b.hp, b.mp, b.tp, b.state_ids.duplicate(), b.buffs.duplicate()])
	out.append(l.random.snapshot())
	out.append([l.is_won(), l.is_lost(), l.turn])
	return JSON.stringify(out)


func _hold(on: bool) -> void:
	if on:
		XActor.SKILLS_HOLD = true
	else:  # 回退支（回退开关覆盖.py 认字面量）
		XActor.SKILLS_HOLD = false


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_t576_lag"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	_unit()
	_volatile()
	_rollback()
	_battles()
	_forced()
	_tianqi()
	await _scenes()
	_hold(true)
	XActor.READ_VERIFY = false
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


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
	if not d.skill_ids.has(8152):
		d.learn_skill(8152)
	return s


## 一个只带特性、不加技能、没有挂上／拿掉效果的状态（STATE_TRAITS）
func _traits_state() -> int:
	for id in range(2, 3000):
		if not XDB.rec("States", id).is_empty() and XBattler.state_class(id) == XBattler.STATE_TRAITS:
			return id
	return -1


## 保留的 id 表与现算的一致（取一次保留的，再现算一次）
func _same_now(a: XActor) -> bool:
	return a._ids_held() == a._skill_ids_now()


# ---- 单元：各种写入之后与现算相同；轻写入之后命中 ----
func _unit() -> void:
	_hold(true)
	var s := _doria_state()
	var a := s.actor(DORIA)
	var b := s.actor(8)
	var light := _traits_state()
	check("fixture.traits_state", light > 0, light)
	check("fixture.skill_state_hard", XBattler.state_class(SKILL_STATE) == XBattler.STATE_HARD)
	XActor.read_reset()  # 行动开头：打开保留
	check("unit.on_after_read_reset", XActor._hold_on)
	var first := a._ids_held()
	b._ids_held()
	# 轻写入：HP／MP／TP、gain 标脏、被动缓存换新、不带技能的状态（别人身上）
	var hits := XActor.skills_hold_hits
	a.hp = maxf(1.0, a.hp - 1.0)
	a.mp = maxf(0.0, a.mp - 1.0)
	a.tp = 0.0
	a.param_mark_dirty_resource()
	XActor.passive_touch()
	b.add_state(light)
	check("unit.light_hit", a._ids_held() == first and XActor.skills_hold_hits == hits + 1, [XActor.skills_hold_hits, hits])
	check("unit.light_same", _same_now(a))
	check("unit.light_self_state_same", _same_now(b) and b.state_ids.has(light), b.state_ids)
	# 特性 43 的状态：加上就列出加的技能，拿掉就没有
	a.add_state(SKILL_STATE)
	var with_state := a._ids_held()
	check("unit.hard_state_add", with_state.has(SKILL_STATE_ADD) and _same_now(a), with_state.has(SKILL_STATE_ADD))
	a.remove_state(SKILL_STATE)
	check("unit.hard_state_remove", not a._ids_held().has(SKILL_STATE_ADD) and _same_now(a))
	# 绕过加减状态直接写状态表（没有已知写入）：本人状态表逐项比
	a._ids_held()
	a.state_ids.append(SKILL_STATE)
	check("unit.direct_state_append", a._ids_held().has(SKILL_STATE_ADD) and _same_now(a))
	# 陈旧状态（渡鸦时序：在身上但特性暂读不到）
	a.stale_state_ids.append(SKILL_STATE)
	check("unit.stale_state", not a._ids_held().has(SKILL_STATE_ADD) and _same_now(a))
	a.stale_state_ids.clear()
	a.state_ids.erase(SKILL_STATE)
	check("unit.direct_state_erase", not a._ids_held().has(SKILL_STATE_ADD) and _same_now(a))
	# 学／忘技能
	var extra := 5525
	a.learn_skill(extra)
	check("unit.learn", a._ids_held().has(extra) and _same_now(a))
	a.forget_skill(extra)
	check("unit.forget", not a._ids_held().has(extra) and _same_now(a))
	a.skill_ids.append(extra)  # 绕过学技能
	check("unit.direct_learn", a._ids_held().has(extra) and _same_now(a))
	a.skill_ids.erase(extra)
	# 装备：直接换格子里的对象（不走 XEquipment.change）
	var slot := -1
	for i in a.equips.size():
		if a.equips[i] != null:
			slot = i
			break
	if slot >= 0:
		a._ids_held()
		var keep = a.equips[slot]
		a.equips[slot] = null
		check("unit.equip_direct", _same_now(a))
		a.equips[slot] = keep
		check("unit.equip_back", _same_now(a))
	# 等级、背包件数、异化借装备标记
	var lv := a.level
	var gen := XActor._hold_gen
	a.change_level(maxi(1, lv - 30))
	check("unit.level_touch", XActor._hold_gen != gen and _same_now(a))
	a.change_level(lv)
	a._ids_held()
	hits = XActor.skills_hold_hits
	s.gear.append({"kind": "weapon", "base": 1, "id": 1, "name": "背包里多一件"})
	a._ids_held()
	check("unit.gear_miss", XActor.skills_hold_hits == hits and _same_now(a))
	s.gear.pop_back()
	a.set_meta("xalien_ghosts", [])
	check("unit.alien_meta_miss", _same_now(a) and a._hold_volatile())
	a.remove_meta("xalien_ghosts")
	# 法宝升级
	gen = XActor._hold_gen
	var fb := {}
	for nm in ["Weapons", "Armors"]:
		var t: Array = XDB.table(nm)
		for i in range(1, t.size()):
			if t[i] is Dictionary and XMagicWeapon.is_magic(t[i]):
				fb = (t[i] as Dictionary).duplicate(true)
				fb["kind"] = "weapon" if nm == "Weapons" else "armor"
				fb["base"] = i
				fb["level"] = 1.0
				fb["exp"] = 0.0
				break
		if not fb.is_empty():
			break
	XMagicWeapon.level_up(fb)
	check("unit.magic_weapon_touch", XMagicWeapon.is_magic(fb) and XActor._hold_gen != gen, fb.get("base"))
	# 全体作废：read_touch、batch_begin、skills_touch、STATE_HARD 状态
	for nm in ["read_touch", "batch_begin", "skills_touch", "hard_state"]:
		a._ids_held()
		gen = XActor._hold_gen
		match nm:
			"read_touch": XActor.read_touch()
			"batch_begin":
				XActor.batch_begin()
				XActor.batch_end()
			"skills_touch": XActor.skills_touch()
			"hard_state": XActor.state_touch(SKILL_STATE)
		check("unit.global_%s" % nm, XActor._hold_gen != gen)
	# 记录：轻写入不换代、STATE_HARD 换代
	var ep := XActor._skills_epoch
	XActor.state_touch(light)
	XActor.passive_touch()
	b.param_mark_dirty_resource()
	check("unit.epoch_light_kept", XActor._skills_epoch == ep, [XActor._skills_epoch, ep])
	XActor.state_touch(SKILL_STATE)
	check("unit.epoch_hard_bumped", XActor._skills_epoch != ep)
	# 出战斗关掉
	var l := XBattleLogic.new()
	l.setup(2, s)
	check("unit.setup_off", not XActor._hold_on)
	XActor.read_reset()
	l.end_battle(-1)
	check("unit.end_battle_off", not XActor._hold_on and XActor._hold_store.is_empty())
	var builds := XActor.skill_ids_builds
	a._ids_held()
	a._ids_held()
	check("unit.off_outside_battle", XActor.skill_ids_builds == builds + 2)
	XState.current = null


# ---- 易变角色不保留 ----
func _volatile() -> void:
	_hold(true)
	var s := _doria_state()
	s.add_actor(XGuyu.ACTOR)
	var g := s.actor(XGuyu.ACTOR)
	XActor.read_reset()
	g._ids_held()
	check("volatile.guyu", g._hold_volatile() and not XActor._hold_store.has(g.get_instance_id()))
	var a := s.actor(8)
	var robe: Dictionary = XDB.rec("Armors", XYunshang.ROBE_FIRST + XYunshang.BORROW_KEY).duplicate(true)
	robe["kind"] = "armor"
	robe["base"] = XYunshang.ROBE_FIRST + XYunshang.BORROW_KEY
	var slot := -1
	for i in a.equips.size():
		if a.equips[i] == null or str(a.equips[i].get("kind", "")) == "armor":
			slot = i
	if slot < 0:
		slot = a.equips.size() - 1
	var keep = a.equips[slot]
	a.equips[slot] = robe
	check("volatile.yunshang_borrow_robe", XYunshang.key(a) == XYunshang.BORROW_KEY and a._hold_volatile(), XYunshang.key(a))
	a.equips[slot] = keep
	check("volatile.plain_actor", not a._hold_volatile())
	XActor.hold_off()
	XState.current = null


# ---- 回退支：每次现算；加减状态、被动缓存换新、gain 标脏照旧换代 ----
func _rollback() -> void:
	_hold(false)
	var s := _doria_state()
	var a := s.actor(DORIA)
	XActor.read_reset()
	var builds := XActor.skill_ids_builds
	a._ids_held()
	a._ids_held()
	check("rollback.every_time", XActor.skill_ids_builds == builds + 2)
	var light := _traits_state()
	for nm in ["state", "passive", "gain_dirty"]:
		var ep := XActor._skills_epoch
		var wg := XActor._write_gen
		match nm:
			"state": XActor.state_touch(light)
			"passive": XActor.passive_touch()
			"gain_dirty": a.param_mark_dirty_resource()
		check("rollback.%s_epoch" % nm, XActor._skills_epoch != ep and XActor._write_gen != wg)
	_hold(true)
	XActor.hold_off()
	XState.current = null


# ---- 无界面整场：开关两态逐字相同 ----
func _new_state(seed_no: int) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.random_master = XRandomStream.hex64(seed_no)
	for a in s.members():
		a.change_level_mv(80)
		a.refresh_passive()
		a.recover_all()
	return s


func _battle(make: Callable, troop: int, rounds: int, reserve := 0) -> Dictionary:
	seed(20261127)
	var s: XState = make.call()
	var logic := XBattleLogic.new()
	logic.setup(troop, s, XBattleRandom.create("0000000000576576"))
	logic.auto = true
	var journal := []
	var builds := XActor.skill_ids_builds
	if reserve > 0:
		XBattleCommonEvent.reserve(logic, reserve, s.actor(DORIA))
		journal.append(_plain(logic.run_events(null), logic))
	var acts := 0
	for r in rounds:
		logic.start_turn()
		journal.append(_plain(logic.take_turn_start_logs(), logic))
		journal.append(_plain(logic.run_events(null), logic))
		var count := 0
		while count < 40 and not logic.is_over():
			var u := logic.next_subject()
			if u == null:
				break
			count += 1
			var cmd := logic.decide(u)
			journal.append([logic.stable_id(u), int(cmd[0].id) if cmd[0] != null else 0, _plain(logic.act(u, cmd[0], cmd[1]), logic)])
			journal.append(_plain(logic.run_events(u), logic))
			acts += 1
		if logic.is_over():
			break
		journal.append(_plain(logic.end_turn(), logic))
	journal.append(_sig(logic))
	var won := logic.is_won()
	logic.end_battle(0 if won else -1)
	journal.append([s.members().map(func(a): return [a.actor_id, a.level, a.hp, a.mp, a.tp, a.state_ids.duplicate(), a.exp_total]), s.gear.size()])
	var text := JSON.stringify(journal)
	XState.current = null
	return {"sig": text.sha256_text(), "size": text.length(), "acts": acts, "builds": XActor.skill_ids_builds - builds, "won": won}


## 两态各跑一遍（开着那遍带 READ_VERIFY：每次命中都现算比对）
func _pair(tag: String, make: Callable, troop: int, rounds: int, reserve := 0, min_acts := 3) -> Dictionary:
	_hold(false)
	var off := _battle(make, troop, rounds, reserve)
	_hold(true)
	var hits := XActor.skills_hold_hits
	XActor.READ_VERIFY = true
	XActor.read_mismatches.clear()
	var on := _battle(make, troop, rounds, reserve)
	XActor.READ_VERIFY = false
	var on_hits := XActor.skills_hold_hits - hits
	var plain := _battle(make, troop, rounds, reserve)  # 不带比对再跑一遍：量现算次数
	print("T576 %s off acts=%d builds=%d size=%d / on hits=%d builds=%d" % [tag, off.acts, off.builds, off.size, on_hits, plain.builds])
	check(tag + ".same_log", off.sig == on.sig and on.sig == plain.sig and int(off.acts) >= min_acts, [off, on, plain])
	check(tag + ".verify_clean", XActor.read_mismatches.is_empty(), XActor.read_mismatches.slice(0, 3))
	check(tag + ".hold_used", on_hits > 0, on_hits)
	check(tag + ".closed", not XActor._hold_on and XActor._read_depth == 0 and XActor._batch_depth == 0)
	return {"off": off, "on": plain}


func _battles() -> void:
	for troop in [2, 70]:
		_pair("battle%d" % troop, _new_state.bind(20261100 + troop), troop, 3)


func _forced() -> void:
	# 预约 1222：两次强制行动，第二次 8153 给我方全体回 HP／MP／TP（玩家档长帧那一次）
	var r := _pair("ce1222", _doria_state, 2, 2, CE_ZHULANG, 1)  # 第二次强制行动就打完（两次 339 都演）
	check("ce1222.fewer_builds", int(r.on.builds) * 3 < int(r.off.builds) * 2, [r.on.builds, r.off.builds])


func _tianqi() -> void:
	var mk := func() -> XState:
		var lineup := [21, 23, 3, 1, 2]
		var tq := XTianqi.start_new_game(3, "jianxian", lineup)
		XTianqi.take_pending()
		for id in lineup:
			XTianqi._joining = true
			tq.add_actor(int(id))
			XTianqi._joining = false
		tq.map_id = 4
		XState.current = tq
		tq.random_master = XRandomStream.hex64(20261176)
		for a in tq.members():
			a.change_level(60)
			a.refresh_passive()
			a.recover_all()
		return tq
	_pair("tianqi", mk, 2, 3)


# ---- 带场景：同种子四倍速、一倍速，开关两态 ----
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
	XState.current = null
	return out


func _scenes() -> void:
	for speed in [1, 4]:  # 1＝四倍速，4＝一倍速（OFF）
		for c in [["t70", 70, _new_state.bind(20261170), false, 0], ["ce1222", 2, _doria_state, false, CE_ZHULANG]]:
			var res := {}
			for on in [true, false]:
				_hold(on)
				res[on] = await _scene(speed, int(c[1]), c[2], bool(c[3]), int(c[4]))
			_hold(true)
			var tag := "scene.%s_x%d" % [c[0], speed]
			print("T576 %s on n=%d frames=%d result=%d / off n=%d frames=%d result=%d" % [tag, res[true].n, res[true].frames, res[true].result, res[false].n, res[false].frames, res[false].result])
			check(tag + ".played", int(res[true].n) > 0, res[true])
			check(tag + ".same_order", res[true].rec == res[false].rec, [res[true].rec.left(400), res[false].rec.left(400)])
			check(tag + ".same_result", res[true].sig == res[false].sig and res[true].result == res[false].result, [res[true].sig.left(300), res[false].sig.left(300), res[true].result, res[false].result])  # 总帧数不比：无头不定帧率时演出按真实帧耗推进，同一态两遍也会差一帧
