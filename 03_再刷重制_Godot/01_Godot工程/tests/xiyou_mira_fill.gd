extends Node
## T212（O-586，XMira.FILL_ON_LIFT）：米拉解放·黑龙加上 2592 时，生命上限、魔法上限各涨多少，当前生命、魔法就补多少。
## 西游档（2592 生命上限 ×2）与天启篇档（2592 倍率清空，灾厄苏醒 10163 黑龙形态生命上限 +20%）各测：
## - <档>.direct.*：半血半蓝直接调 XMira.liberate，当前生命／魔法的增量＝上限的增量，且生命上限确实涨了；
## - <档>.full.*：满血满蓝变身后仍是满的（补完不超新上限）；
## - <档>.act.*：真实行动放解放·黑龙，开关开比关多出的生命、魔法正好是上限差值（行动其余部分两边一样）；
## - <档>.revert.*：变回人形（解除 2592）照原版夹到上限，不额外扣；
## - <档>.rollback：FILL_ON_LIFT＝false 当前生命、魔法不变（原版）；
## - <档>.other_state：别的加生命上限状态（不经解放）当前生命不变。
var results := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


class HalfStream extends XRandomStream:
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return 0.5 if kind == "float" else 2147483648

	func next_index_mod(n: int, reason: String, event_key := "") -> int:
		next_uint(reason, event_key)
		return n / 2 if n > 0 else 0

	func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
		next_uint(reason, event_key)
		return lo + (hi - lo + 1) / 2


## 新局、米拉进阶 3、队伍 [168, 1] 60 级（灾厄苏醒 10163 要 60 级）；tianqi＝把这档标成天启篇规则并开角色卡
func _battle(tianqi: bool) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [8])
	XState.current = s
	XTianqiSkills.CARDS = tianqi
	if tianqi:
		s.flags["tianqi"] = {"rules": 1}
	s.set_switch(2494, true)
	s.actor_max_level = 99
	s.party.clear()
	s.battle_slots.clear()
	s.actor_advance[XMira.ACTOR] = 3
	for id in [XMira.ACTOR, 1]:
		s.actor(id).change_level_mv(60)
	var a := s.actor(XMira.ACTOR)
	XSkillProgression.sync(a)
	a.skill_ids.erase(10167)
	XTianqi._joining = true  # 天启篇档入队要走招募口，这里直接放进队伍（同 xiyou_tianqi_skills）
	s.add_actor(XMira.ACTOR)
	s.add_actor(1)
	XTianqi._joining = false
	a.refresh_passive()
	check(("tianqi" if tianqi else "xiyou") + ".setup.party", s.party.has(XMira.ACTOR), s.party)
	check(("tianqi" if tianqi else "xiyou") + ".setup.skills", [XMira.LIBERATE, 10161, 10163].all(func(id): return a.skill_ids.has(id)), a.skill_ids)
	var rand := XBattleRandom.create("0000000000000212")
	rand.rule = HalfStream.new()
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
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
		b.warmups.clear()
	a.tp = a.max_tp()
	return [logic, a]


func _half(a: XActor) -> void:
	a.hp = floorf(a.mhp * 0.5)
	a.mp = floorf(a.mmp * 0.5)


func _case(tag: String, tianqi: bool) -> void:
	var skill := XDB.rec("Skills", XMira.LIBERATE)
	# direct：半血半蓝变身
	var r := _battle(tianqi)
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	logic.start_turn()
	_half(a)
	var cap0 := [a.mhp, a.mmp]
	var res0 := [a.hp, a.mp]
	XMira.liberate(logic, a, skill)
	var dcap := [a.mhp - cap0[0], a.mmp - cap0[1]]
	var dres := [a.hp - res0[0], a.mp - res0[1]]
	check(tag + ".direct.dragon", XMira.dragon(a) and a.state_ids.has(XMira.DRAGON), a.state_ids)
	check(tag + ".direct.mhp_up", dcap[0] > 0.0, [cap0, dcap])
	check(tag + ".direct.hp_delta", dres[0] == dcap[0], [res0, dres, cap0, dcap])
	check(tag + ".direct.mp_delta", dres[1] == maxf(0.0, dcap[1]), [res0, dres, cap0, dcap])
	print(tag, " 上限 ", cap0, " → ", [a.mhp, a.mmp], "；当前 ", res0, " → ", [a.hp, a.mp])
	# revert：解除 2592 照原版夹上限、不额外扣
	var hp_pre := a.hp
	var mp_pre := a.mp
	logic._state_remove(a, XMira.DRAGON)
	check(tag + ".revert.caps_back", a.mhp == cap0[0] and a.mmp == cap0[1], [[a.mhp, a.mmp], cap0])
	check(tag + ".revert.clamp_only", a.hp == minf(hp_pre, a.mhp) and a.mp == minf(mp_pre, a.mmp), [[hp_pre, mp_pre], [a.hp, a.mp], [a.mhp, a.mmp]])
	logic.end_battle(0)
	# full：满血满蓝变身后仍满
	r = _battle(tianqi)
	logic = r[0]
	a = r[1]
	logic.start_turn()
	a.hp = a.mhp
	a.mp = a.mmp
	XMira.liberate(logic, a, skill)
	check(tag + ".full.still_full", a.hp == a.mhp and a.mp == a.mmp, [[a.hp, a.mhp], [a.mp, a.mmp]])
	logic.end_battle(0)
	# rollback：开关关掉＝原版不补
	XMira.FILL_ON_LIFT = false
	r = _battle(tianqi)
	logic = r[0]
	a = r[1]
	logic.start_turn()
	_half(a)
	res0 = [a.hp, a.mp]
	XMira.liberate(logic, a, skill)
	check(tag + ".rollback", [a.hp, a.mp] == res0 and a.state_ids.has(XMira.DRAGON), [res0, [a.hp, a.mp]])
	logic.end_battle(0)
	XMira.FILL_ON_LIFT = true
	# act：真实行动，开关开／关两次比
	var got := {}
	for fill in [true, false]:
		XMira.FILL_ON_LIFT = fill
		r = _battle(tianqi)
		logic = r[0]
		a = r[1]
		logic.start_turn()
		_half(a)
		a.tp = a.max_tp()
		cap0 = [a.mhp, a.mmp]
		logic.act(a, skill, logic.enemies[0])
		got[fill] = {"hp": a.hp, "mp": a.mp, "dh": a.mhp - cap0[0], "dm": a.mmp - cap0[1], "dragon": XMira.dragon(a)}
		logic.end_battle(0)
	XMira.FILL_ON_LIFT = true
	var on: Dictionary = got[true]
	var off: Dictionary = got[false]
	check(tag + ".act.dragon", on.dragon and off.dragon, got)
	check(tag + ".act.hp_extra", on.hp - off.hp == on.dh and on.dh > 0.0, got)
	check(tag + ".act.mp_extra", on.mp - off.mp == maxf(0.0, on.dm), got)
	# other_state：别的加生命上限状态（直接加，不经解放）不补
	var other := _other_mhp_state()
	if check(tag + ".other_state.found", other > 0, other):
		r = _battle(tianqi)
		logic = r[0]
		a = r[1]
		logic.start_turn()
		_half(a)
		cap0 = [a.mhp, a.mmp]
		res0 = [a.hp, a.mp]
		logic._state_add(a, other)
		check(tag + ".other_state", a.mhp > cap0[0] and [a.hp, a.mp] == res0, [other, cap0, [a.mhp, a.mmp], res0, [a.hp, a.mp]])
		logic.end_battle(0)


## 找一个特性里生命上限倍率 >1 的普通状态（不是 2592）
func _other_mhp_state() -> int:
	for id in range(2, 3000):
		if id == XMira.DRAGON:
			continue
		var st := XDB.rec("States", id)
		if st.is_empty():
			continue
		for t in st.get("traits", []):
			if int(t.get("code", 0)) == 21 and int(t.get("dataId", -1)) == 0 and float(t.get("value", 1.0)) >= 1.2:
				return id
	return 0


func _run() -> void:
	XMira.FILL_ON_LIFT = true
	_case("xiyou", false)
	_case("tianqi", true)
	XTianqiSkills.CARDS = false
	XState.current = null
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_mira_fill", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
