extends Node
## 队伍技能刷新（XPartySkills／XSkillShare）：逐步对照冻结 v0.28 参照 tests/fixtures/party_skills_oracle.json
## （mv_oracle/party_skills_probe.cjs：新游戏、开超强角色开关 2494；整队完成、仓库退出、开战、读档四种刷新）。
## - <场景>.<步>：O-095 关掉（照原版内存记录）逐步比相关角色的已学技能（参照里羁绊技能是字符串 ID，按数值比）、
##   本次弹出的提示（参照记录的是插件原样提示，照 codex 包装去掉逐条「技能共享：X 激活！」）、共享记录。
##   还没移植的系统（PENDING：羁绊、领袖）的技能与提示先不比，场景里只跑已有的。
## - exact.*：O-095 开着：角色本来就会的共享技能不被忘掉；读档后存档前已失效的共享技能会被忘掉（原版留着）；记录随存档往返。
## - hooks.*：整队完成、仓库退出、开战、读档四处挂点确实调到刷新。
const FIXTURE := "res://tests/fixtures/party_skills_oracle.json"
## 已移植的场景前缀
const SCENARIOS := ["share."]
var results := []
var pending := {}


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(1500))
	return ok


func _ready() -> void:
	XSave.dir_override = "user://test_xiyou_party_skills"
	XConfig.path_override = ""
	_run.call_deferred()


## 还没移植的两套的技能 ID：领袖 LeadSkiId、羁绊 JiBanSkiId
func _pending() -> Dictionary:
	var out := {}
	var lead := XDB.plugin("Star_LeadActor")
	for k in lead:
		var d = JSON.parse_string(str(lead[k])) if str(k).begins_with("Lead ") and str(lead[k]) != "" else null
		if d is Dictionary:
			out[int(d.get("LeadSkiId", 0))] = true
	var bond := XDB.plugin("Star_JiBanSiklls")
	for k in bond:
		var d = JSON.parse_string(str(bond[k])) if str(k).begins_with("JiBan ") and str(bond[k]) != "" else null
		if d is Dictionary:
			for v in JSON.parse_string(str(d.get("JiBanSkiId", "[]"))):
				out[int(v)] = true
	return out


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not (ref is Dictionary and ref.has("cases")):
		check("fixture_present", false)
		return finish()
	pending = _pending()
	check("pending_ids", pending.has(717) and pending.has(5594))
	for c in ref.cases:
		check(str(c.id) + ".oracle_clean", (c.errors as Array).is_empty(), c.errors)
		if SCENARIOS.any(func(p): return str(c.id).begins_with(p)):
			_scenario(c)
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


## 参照的 _skills（字符串 ID 写成 "s5594"）→ 整数，去掉还没移植的
func _ids(raw: Array) -> Array:
	var out := raw.map(func(v): return int(str(v).trim_prefix("s"))).filter(func(v): return not pending.has(v))
	out.sort()
	return out


func _mine(a: XActor) -> Array:
	var out := Array(a.skill_ids).filter(func(v): return not pending.has(v))
	out.sort()
	return out


## 照 codex 包装：逐条「技能共享：X 激活！」不弹；还没移植的系统的提示不比
func _toasts(raw: Array) -> Array:
	return raw.filter(func(t): return not RegEx.create_from_string("^技能共享：.+ 激活！$").search(str(t)) and str(t).begins_with("技能共享"))


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


func _scenario(c: Dictionary) -> void:
	XPartySkills.EXACT = false
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
		var tag := "%s.%d.%s" % [c.id, i, step.do]
		var bad := {}
		for k in r.skills:
			var mine := _mine(s.actor(int(k)))
			if mine != _ids(r.skills[k]):
				bad[k] = [mine, _ids(r.skills[k])]
		check(tag + ".skills", bad.is_empty(), bad)
		check(tag + ".toasts", got == _toasts(r.toasts), [got, r.toasts])
		var shared := XSkillShare.shared_ids(XPartySkills.records(s)).map(func(v): return int(v))
		check(tag + ".shared", shared == (r.shared as Array).map(func(v): return int(v)), [shared, r.shared])


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
	# 旧档没有 partySkills
	XPartySkills.EXACT = true
	var old := XState.new_game_blank().to_dict()
	old.erase("partySkills")
	check("exact.old_save", XState.from_dict(old).party_skills == {})


class Page extends Node:
	signal closed


## 挂点：整队页「完成」、指令窗取消，仓库页退出，读档 XSave.load_slot
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
	XSave.load_slot(1)
	check("hooks.load", XState.current.actor(8).skill_ids.has(1000), Array(XState.current.actor(8).skill_ids))


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
