extends Node
## 队伍技能刷新（XPartySkills／XSkillShare）：逐步对照冻结 v0.28 参照 tests/fixtures/party_skills_oracle.json
## （mv_oracle/party_skills_probe.cjs：新游戏、开超强角色开关 2494；整队完成、仓库退出、开战、读档四种刷新）。
## - <场景>.<步>：O-095 关掉（照原版内存记录）逐步比相关角色的已学技能（参照里羁绊技能是字符串 ID，按数值比）、
##   本次弹出的提示（参照记录的是插件原样提示，照 codex 包装去掉逐条「技能共享：X 激活！」）、共享／羁绊／领袖三套记录。
## - exact.*：O-095 开着：角色本来就会的共享／羁绊／领袖技能不被忘掉；读档后存档前已失效的共享技能会被忘掉（原版留着）；记录随存档往返。
##   另把参照各场景在开着时再跑一遍，只比技能（读档那步提示不同：开着时记录没丢，不重弹）；EXACT_DIFF 是开着时按设计不同的步：
##   羁绊仍激活、但某人离开出战栏时，原版那人留着该羁绊技能，开着时忘掉（他已不在任何成立的组合里）。
## - hooks.*：整队完成、仓库退出、读档三处挂点确实调到刷新（开战挂在 map_scene.start_battle，由 battle_start 的参照步覆盖）；领袖旗标判定。
const FIXTURE := "res://tests/fixtures/party_skills_oracle.json"
var results := []
## O-095 开着时与原版按设计不同的步：{"场景.步": {"角色": [开着时没有的技能]}}
const EXACT_DIFF := {"bond.mygo.2": {"130": [5607, 5642], "131": [5607, 5642]}}


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(1500))
	return ok


func _ready() -> void:
	XSave.dir_override = "user://test_xiyou_party_skills"
	XConfig.path_override = ""
	_run.call_deferred()


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not (ref is Dictionary and ref.has("cases")):
		check("fixture_present", false)
		return finish()
	for c in ref.cases:
		check(str(c.id) + ".oracle_clean", (c.errors as Array).is_empty(), c.errors)
		_scenario(c, false)
		_scenario(c, true)
	_exact()
	await _hooks()
	XPartySkills.EXACT = true
	finish()


func _fresh(actors: Array, battle: Array) -> XState:
	XPartySkills.reset_session()
	var s := XState.new_game_blank()
	XState.current = s
	_party(s, actors, battle)
	return s


func _party(s: XState, actors: Array, battle: Array) -> void:
	s.party.assign(actors.map(func(v): return int(v)))
	s.battle_slots = (battle + [0, 0, 0, 0, 0]).slice(0, 5).map(func(v): return int(v))
	for id in actors:
		s.actor(int(id))


func _equip(s: XState, actor_id: int, kind: String, id: int) -> Array:
	var a := s.actor(actor_id)
	var e := XGear.template(kind, id)
	var slot := a.equip_slots().find(int(e.etypeId))
	a.equips[slot] = e
	a.refresh_passive()
	return [actor_id, slot]


## 参照的 _skills（字符串 ID 写成 "s5594"）→ 整数
func _ids(raw: Array) -> Array:
	var out := raw.map(func(v): return int(str(v).trim_prefix("s")))
	out.sort()
	return out


func _mine(a: XActor) -> Array:
	var out := Array(a.skill_ids)
	out.sort()
	return out


## 照 codex 包装：逐条「技能共享：X 激活！」不弹
func _toasts(raw: Array) -> Array:
	return raw.filter(func(t): return not RegEx.create_from_string("^技能共享：.+ 激活！$").search(str(t)))


func _ints(v) -> Array:
	return (v as Array).map(func(x): return int(x)) if v is Array else []


func _act(s: XState, what: String) -> Array:
	match what:
		"finish", "warehouse":
			return XPartySkills.finish(s)
		"battle":
			return XPartySkills.battle_start(s)
		"load":
			var d = JSON.parse_string(JSON.stringify(s.to_dict()))
			XPartySkills.reset_session()  # 参照：清内存记录再恢复
			var s2 := XState.from_dict(d)
			XState.current = s2
			return XPartySkills.loaded(s2)
	return []


func _scenario(c: Dictionary, exact: bool) -> void:
	XPartySkills.EXACT = exact
	var st: Dictionary = c.setup
	var s := _fresh(st.actors, st.battle)
	var slots := {}
	var rows: Array = c.observed.rows
	for i in rows.size():
		var step: Dictionary = st.steps[i]
		var r: Dictionary = rows[i]
		var got := []
		match str(step.do):
			"party":
				_party(s, step.actors, step.battle)
			"equip":
				slots[str(step.as)] = _equip(s, int(step.actor), str(step.kind), int(step.id))
			"unequip":
				var at: Array = slots[str(step.ref)]
				s.actor(at[0]).equips[at[1]] = null
				s.actor(at[0]).refresh_passive()
			_:
				got = _act(s, str(step.do))
				s = XState.current
		var tag := "%s%s.%d.%s" % ["exact." if exact else "", c.id, i, step.do]
		var bad := {}
		var diff: Dictionary = EXACT_DIFF.get("%s.%d" % [c.id, i], {}) if exact else {}
		for k in r.skills:
			var mine := _mine(s.actor(int(k)))
			var want := _ids(r.skills[k]).filter(func(v): return not (diff.get(k, []) as Array).has(v))
			if mine != want:
				bad[k] = [mine, want]
		check(tag + ".skills", bad.is_empty(), bad)
		if exact:
			continue
		check(tag + ".toasts", got == _toasts(r.toasts), [got, r.toasts])
		var rec := XPartySkills.records(s)
		var mine := [_ints(XSkillShare.shared_ids(rec)), XBonds.active_ids(rec), XLeadActor.ranks(rec), _ints(rec.get("lead", {}).get("learners", []))]
		var theirs := [_ints(r.shared), _ints(r.bonds), _ints(r.lead), _ints(r.leadLearners)]
		check(tag + ".records", mine == theirs, [mine, theirs])


## O-095：本来就会的不被忘掉；读档后失效的共享技能被忘掉；记录随存档往返
func _exact() -> void:
	for exact in [false, true]:
		XPartySkills.EXACT = exact
		var tag := "exact.%s" % ("on" if exact else "off")
		# 角色 9 自己学会 1000；角色 1 穿 1583 共享 1000；脱下后刷新
		var s := _fresh([1, 8, 9, 10], [1, 8, 9, 10])
		s.actor(9).learn_skill(1000)
		var at := _equip(s, 1, "armor", 1583)
		XPartySkills.finish(s)
		s.actor(1).equips[at[1]] = null
		XPartySkills.finish(s)
		check(tag + ".own_skill_kept", s.actor(9).skill_ids.has(1000) == exact and not s.actor(8).skill_ids.has(1000), Array(s.actor(9).skill_ids))
		# 共享后把 10 移出出战栏（不刷新）就存档；读档后 10 是否还留着 1000
		s = _fresh([1, 8, 9, 10], [1, 8, 9, 10])
		_equip(s, 1, "armor", 1583)
		XPartySkills.finish(s)
		_party(s, [1, 8, 9, 10], [1, 8, 9])
		var d = JSON.parse_string(JSON.stringify(s.to_dict()))
		check(tag + ".saved_record", d.partySkills.has("share") == exact, d.partySkills)
		XPartySkills.reset_session()
		var s2 := XState.from_dict(d)
		XState.current = s2
		XPartySkills.loaded(s2)
		check(tag + ".stale_after_load", s2.actor(10).skill_ids.has(1000) != exact and s2.actor(8).skill_ids.has(1000),
			[Array(s2.actor(10).skill_ids).has(1000), Array(s2.actor(8).skill_ids).has(1000)])
	# 羁绊：101 自己学会 5594，三霄两人成立后再拆散；领袖：8 自己学会 717，首位 1 换成 9
	for exact in [false, true]:
		XPartySkills.EXACT = exact
		var tag := "exact.%s" % ("on" if exact else "off")
		var s := _fresh([100, 101, 1, 8, 9], [1, 100, 101, 8])
		s.actor(101).learn_skill(5594)
		s.actor(8).learn_skill(717)
		XPartySkills.finish(s)
		var mid := [s.actor(100).skill_ids.has(5594), s.actor(9).skill_ids.has(717), s.actor(1).skill_ids.has(717)]
		_party(s, [100, 101, 1, 8, 9], [9, 100, 1, 8])
		XPartySkills.finish(s)
		check(tag + ".bond_own_kept", mid[0] and not s.actor(100).skill_ids.has(5594) and s.actor(101).skill_ids.has(5594) == exact,
			[mid, Array(s.actor(100).skill_ids).has(5594), Array(s.actor(101).skill_ids).has(5594)])
		check(tag + ".lead_own_kept", mid[2] and not s.actor(1).skill_ids.has(717) and s.actor(8).skill_ids.has(717) == exact,
			[mid, Array(s.actor(1).skill_ids).has(717), Array(s.actor(8).skill_ids).has(717)])
	# 旧档没有 partySkills
	XPartySkills.EXACT = true
	var old := XState.new_game_blank().to_dict()
	old.erase("partySkills")
	check("exact.old_save", XState.from_dict(old).party_skills == {})


class Page extends Node:
	signal closed


## 挂点：整队页「完成」、指令窗取消，仓库页退出，读档页读档（XSaveScene._perform；XSave.load_slot 本身不刷新，读档往返测试不受影响）
func _hooks() -> void:
	XPartySkills.EXACT = true
	for how in ["party_finish", "party_cancel", "warehouse"]:
		var s := _fresh([1, 8, 9, 10], [1, 8, 9, 10])
		_equip(s, 1, "armor", 1583)
		var page: Node = XActorWarehouseScene.new() if how == "warehouse" else XPartyScene.new()
		add_child(page)
		await get_tree().process_frame
		page.set("mode", "command")
		if how == "party_finish":
			page.set("cmd_index", 3)
			page.call("ok")
		else:
			page.call("cancel")
		check("hooks." + how, s.actor(8).skill_ids.has(1000), Array(s.actor(8).skill_ids))
		page.queue_free()
	var s := _fresh([1, 8, 9, 10], [1, 8, 9, 10])
	_equip(s, 1, "armor", 1583)
	XSave.save(1)
	var page := XSaveScene.new()
	page.mode = "load"
	page.index = 0
	add_child(page)
	await get_tree().process_frame
	page.call("_perform", "load")
	page.queue_free()
	check("hooks.load", XState.current.actor(8).skill_ids.has(1000), Array(XState.current.actor(8).skill_ids))
	# 领袖旗标：首格是领袖角色才画
	s = _fresh([1, 8, 9], [8, 1, 9])
	var flags := [XLeadActor.is_leader(s, 8), XLeadActor.is_leader(s, 1)]
	_party(s, [1, 8, 9], [1, 8, 9])
	flags.append(XLeadActor.is_leader(s, 1))
	check("hooks.leader_flag", flags == [false, false, true] and XLeadActor.skill_of(1) == 717 and XLeadActor.rows().size() == 29, flags)


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
