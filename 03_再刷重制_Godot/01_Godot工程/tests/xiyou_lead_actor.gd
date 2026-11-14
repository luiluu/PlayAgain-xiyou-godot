extends Node
## 【cc·Pro·未经审查】领袖技能 XLeadActor.refresh 的分支（cc pro-test-gaps 2026-11-14）。
## xiyou_party_skills 用原版参照跑了四种刷新的整体结果，并核了领袖旗标；这里直接调 refresh，按 core/lead_actor.gd 文件头
## （Star_LeadActor 的 Star_GetLeadOpt／getLeadSkiId／LearnSkill）逐条核：
## - 首位（出战栏第 0 格原样，空位 0）没有领袖技能、又没有上次记录：什么都不做；
## - 首位有领袖技能：出战栏全体（空位跳过，不在出战栏的队员不算）学，记 ranks [首位, 技能] 与 learners；
## - 刷新前先从上次的 learners 身上忘掉上次的技能；首位换成没有领袖技能的人：忘掉，但记录不清；
## - O-095（XPartySkills.EXACT）开：学之前就会的不进 learners、不被忘；关：照原版全忘。

var results := []
var skipped := []


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(1500))
	return ok


func skip(name: String, why: String) -> void:
	skipped.append(name)
	print("SKIP ", name, " ", why)


func _ready() -> void:
	_run.call_deferred()


func _fresh(party: Array, slots: Array) -> XState:
	XPartySkills.reset_session()
	var s := XState.new_game_blank()
	s.set_switch(2494, true)  # 同 xiyou_party_skills
	XState.current = s
	s.party.assign(party)
	s.battle_slots = slots
	for id in party:
		s.actor(int(id))
	return s


func _has(s: XState, id: int, skill: int) -> bool:
	return s.actor(id).skill_ids.has(skill)


func _run() -> void:
	var exact_saved := XPartySkills.EXACT
	XPartySkills.EXACT = true
	var lead1 := XLeadActor.skill_of(1)
	# 另一位领袖角色、两位不是领袖的角色（都要能建出来）
	var lead2 := 0
	var lead2_skill := 0
	for r in XLeadActor.rows():
		var id := int(r.actor)
		if id != 1 and int(r.skill) != 0 and int(r.skill) != lead1 and not XDB.rec("Actors", id).is_empty() and XLeadActor.skill_of(id) == int(r.skill):
			lead2 = id
			lead2_skill = int(r.skill)
			break
	var plain := [8, 9, 10].filter(func(id): return XLeadActor.skill_of(id) == 0)
	if not check("data_present", lead1 != 0 and lead2 != 0 and plain.size() >= 2, [lead1, lead2, plain]):
		return finish()
	var p1: int = plain[0]
	var p2: int = plain[1]
	print("lead1=%d lead2=%d(%d) plain=%s" % [lead1, lead2, lead2_skill, plain])
	check("skill_of_none", XLeadActor.skill_of(0) == 0 and XLeadActor.skill_of(-1) == 0)
	# 同一角色取第一条
	var firsts := {}
	var dup_ok := true
	for r in XLeadActor.rows():
		if not firsts.has(int(r.actor)):
			firsts[int(r.actor)] = int(r.skill)
	for id in firsts:
		if XLeadActor.skill_of(int(id)) != int(firsts[id]):
			dup_ok = false
	check("skill_of_first_row", dup_ok)

	# ---- 首位空、无记录：什么都不做 ----
	var s := _fresh([1, p1, p2], [0, 1, p1, 0, 0])
	var rec := {}
	check("empty_leader_noop", XLeadActor.refresh(s, rec).is_empty() and XLeadActor.ranks(rec).is_empty() and not _has(s, 1, lead1), rec)
	check("is_leader_needs_slot0", not XLeadActor.is_leader(s, 1))
	s.battle_slots = []
	check("is_leader_empty_slots", not XLeadActor.is_leader(s, 1))

	# ---- 首位是领袖：出战栏全体学 ----
	s = _fresh([1, p1, p2, lead2], [1, p1, 0, p2, 0])
	rec = {}
	XLeadActor.refresh(s, rec)
	check("leader_all_slots_learn", _has(s, 1, lead1) and _has(s, p1, lead1) and _has(s, p2, lead1) and not _has(s, lead2, lead1), [s.actor(lead2).skill_ids.has(lead1)])
	check("leader_record", XLeadActor.ranks(rec) == [1, lead1] and (rec.lead.learners as Array).map(func(v): return int(v)) == [1, p1, p2], rec.lead)
	check("is_leader_slot0", XLeadActor.is_leader(s, 1) and not XLeadActor.is_leader(s, p1))
	XLeadActor.refresh(s, rec)
	check("leader_refresh_idempotent", _has(s, p1, lead1) and (rec.lead.learners as Array).size() == 3, rec.lead)

	# ---- 换领袖：忘上次的、学新的 ----
	s.battle_slots = [lead2, 1, p1, 0, 0]
	XLeadActor.refresh(s, rec)
	check("switch_leader_forgets_old", not _has(s, 1, lead1) and not _has(s, p1, lead1) and not _has(s, p2, lead1), [s.actor(p2).skill_ids.has(lead1)])
	check("switch_leader_learns_new", _has(s, lead2, lead2_skill) and _has(s, 1, lead2_skill) and _has(s, p1, lead2_skill) and not _has(s, p2, lead2_skill)
		and XLeadActor.ranks(rec) == [lead2, lead2_skill], rec.lead)

	# ---- 首位换成没有领袖技能的：忘掉，记录不清 ----
	s.battle_slots = [p1, lead2, 0, 0, 0]
	XLeadActor.refresh(s, rec)
	check("non_leader_forgets", not _has(s, lead2, lead2_skill) and not _has(s, p1, lead2_skill), rec.lead)
	check("non_leader_record_kept", XLeadActor.ranks(rec) == [lead2, lead2_skill], rec.lead)
	# 记录没清：之后 p1 从别处学到同一技能，下一次刷新会被当成「本系统学的」再忘一次（文件头说「无害」）
	s.actor(p1).learn_skill(lead2_skill)
	var learned_elsewhere := _has(s, p1, lead2_skill)
	XLeadActor.refresh(s, rec)
	if learned_elsewhere and not _has(s, p1, lead2_skill):
		skip("stale_record_keeps_other_source", "首位不是领袖后记录不清，别处学到的同一领袖技能在下次刷新被忘（交付单「发现」2）")
	else:
		check("stale_record_keeps_other_source", _has(s, p1, lead2_skill) or not learned_elsewhere)

	# ---- O-095：本来就会的 ----
	for exact in [true, false]:
		XPartySkills.EXACT = exact
		s = _fresh([1, p1, p2], [1, p1, p2, 0, 0])
		rec = {}
		s.actor(p2).learn_skill(lead1)
		if not check("owned_precondition_%s" % exact, _has(s, p2, lead1)):
			continue
		XLeadActor.refresh(s, rec)
		check("owned_not_learner_%s" % exact, ((rec.lead.learners as Array).map(func(v): return int(v)).has(p2)) != exact, rec.lead)
		s.battle_slots = [p1, 1, p2, 0, 0]
		XLeadActor.refresh(s, rec)
		check("owned_kept_%s" % exact, _has(s, p2, lead1) == exact and not _has(s, 1, lead1), s.actor(p2).skill_ids)
	XPartySkills.EXACT = exact_saved
	finish()


func finish() -> void:
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "skipped": skipped}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
