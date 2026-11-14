extends Node
## 【cc·Pro·未经审查】技能共享 XSkillShare 的单元分支（cc pro-test-gaps 2026-11-14）。
## xiyou_party_skills 用原版参照（party_skills_oracle.json）跑了整队完成、仓库退出、开战、读档四种刷新的整体结果；这里直接调
## equip_learn／equip_changed／refresh，用装备实例备注（_note 优先取实例 note）造标签，核 core/skill_share.gd 文件头的
## Star_SkilsShare 1.37 规则：
## - 出战栏 5 格原样，空位、不在出战栏的队员不算；<ShareLearnSkill:n> 学给装备的人，换下就忘；
## - hasEquipLearnSkillsChanged：角色集合或任一角色技能列表（排序后）不同才算变了，顺序不同不算；
## - 共享：出战成员 skills() 里 meta Share＝ShareSkill 的技能（「可共享」）与备注里 <ShareSkill:n>（「被点名」）的交集学给全体出战成员；
## - 提示：本次共享里上次没有的，「光环生效：」名字取前 4 个、多于 4 个加「 等N项」；再加一条「技能共享激活：」全列；没新增不弹；
## - O-095（XPartySkills.EXACT）开：只忘本系统学会的，角色本来就会的不忘；关：照原版不分来源遗忘。

var results := []
var auras := []      # meta Share＝ShareSkill 的技能
var plain := []      # 普通技能（给 ShareLearnSkill 用）


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(1500))
	return ok


func _ready() -> void:
	_run.call_deferred()


func _fresh() -> XState:
	XPartySkills.reset_session()
	var s := XState.new_game_blank()
	s.set_switch(2494, true)  # 同 xiyou_party_skills：三霄不被超强者出战限制清出
	XState.current = s
	s.party.assign([1, 8, 9, 10])
	s.battle_slots = [1, 8, 0, 9, 0]
	for id in s.party:
		s.actor(id)
	return s


## 给角色武器槽放一件装备实例，备注换成 note
func _tag(s: XState, actor_id: int, note: String) -> void:
	var a := s.actor(actor_id)
	var weapon_id := 0
	for r in XDB.table("Weapons"):
		if r is Dictionary and str(r.get("name", "")) != "" and not str(r.get("note", "")).contains("<Share"):
			weapon_id = int(r.id)
			break
	var e: Dictionary = XGear.template("weapon", weapon_id).duplicate(true)
	e.note = note
	var slot := a.equip_slots().find(int(e.etypeId))
	a.equips[slot] = e


func _untag(s: XState, actor_id: int) -> void:
	var a := s.actor(actor_id)
	for i in a.equips.size():
		if a.equips[i] is Dictionary and str(a.equips[i].get("note", "")).contains("<Share"):
			a.equips[i] = null


func _has(s: XState, actor_id: int, skill: int) -> bool:
	return s.actor(actor_id).skill_ids.has(skill)


func _pick() -> void:
	var ids := []
	for r in XDB.table("Skills"):
		if not r is Dictionary or str(r.get("name", "")).strip_edges() == "":
			continue
		var note := str(r.get("note", ""))
		if str(r.get("meta", {}).get("Share", "")) == "ShareSkill" and not note.contains("<ShareSkill:") and auras.size() < 5:
			auras.append(int(r.id))
		elif int(r.id) > 100 and r.get("meta", {}).is_empty() and note.strip_edges() == "" and plain.size() < 2:
			plain.append(int(r.id))
		if auras.size() == 5 and plain.size() == 2:
			break


func _run() -> void:
	var exact_saved := XPartySkills.EXACT
	XPartySkills.EXACT = true
	_pick()
	if not check("data_present", auras.size() == 5 and plain.size() == 2, [auras, plain]):
		return finish()
	var l1: int = plain[0]
	var l2: int = plain[1]
	print("auras=%s plain=%s" % [auras, plain])

	# ---- 出战栏原样 ----
	var s := _fresh()
	check("slots_raw", XSkillShare.slots(s) == [1, 8, 0, 9, 0], XSkillShare.slots(s))
	var rec := {}
	check("equip_learn_empty", XSkillShare.equip_learn(s).is_empty() and not XSkillShare.equip_changed(s, rec))

	# ---- 装备学技能 ----
	_tag(s, 8, "<ShareLearnSkill:%d><ShareLearnSkill:%d>" % [l1, l2])
	_tag(s, 10, "<ShareLearnSkill:%d>" % l1)  # 10 不在出战栏
	check("equip_learn_members_only", XSkillShare.equip_learn(s) == {"8": [l1, l2]}, XSkillShare.equip_learn(s))
	check("equip_changed_new", XSkillShare.equip_changed(s, rec))
	var toasts := XSkillShare.refresh(s, rec)
	check("equip_learned", _has(s, 8, l1) and _has(s, 8, l2) and not _has(s, 10, l1) and not _has(s, 1, l1) and toasts.is_empty(), toasts)
	check("equip_record", rec.share.equip == {"8": [l1, l2]} and rec.share.equipBy == {"8": [l1, l2]}, rec.share)
	check("equip_unchanged_after_refresh", not XSkillShare.equip_changed(s, rec))
	_tag(s, 8, "<ShareLearnSkill:%d><ShareLearnSkill:%d>" % [l2, l1])
	check("equip_order_not_change", not XSkillShare.equip_changed(s, rec))
	_tag(s, 8, "<ShareLearnSkill:%d>" % l1)
	check("equip_changed_list", XSkillShare.equip_changed(s, rec))
	_untag(s, 8)
	check("equip_changed_removed", XSkillShare.equip_changed(s, rec))
	XSkillShare.refresh(s, rec)
	check("equip_forgot", not _has(s, 8, l1) and not _has(s, 8, l2) and rec.share.equip == {}, s.actor(8).skill_ids)

	# ---- O-095：本来就会的不忘（开）／照原版忘（关）----
	for exact in [true, false]:
		XPartySkills.EXACT = exact
		s = _fresh()
		rec = {}
		s.actor(9).learn_skill(l1)
		_tag(s, 9, "<ShareLearnSkill:%d>" % l1)
		XSkillShare.refresh(s, rec)
		check("equipBy_skips_owned_%s" % exact, not (rec.share.get("equipBy", {}) as Dictionary).has("9"), rec.share)
		_untag(s, 9)
		XSkillShare.refresh(s, rec)
		check("owned_kept_%s" % exact, _has(s, 9, l1) == exact, s.actor(9).skill_ids)
	XPartySkills.EXACT = true

	# ---- 共享 ----
	s = _fresh()
	rec = {}
	for id in auras:
		s.actor(1).learn_skill(id)
	check("aura_owner_learned", auras.all(func(id): return _has(s, 1, id)), s.actor(1).skill_ids)
	toasts = XSkillShare.refresh(s, rec)
	check("share_needs_tag", XSkillShare.shared_ids(rec).is_empty() and toasts.is_empty() and not _has(s, 8, auras[0]), [rec.share, toasts])
	var n0 := str(XDB.rec("Skills", auras[0]).name)
	_tag(s, 1, "<ShareSkill:%d>" % auras[0])
	toasts = XSkillShare.refresh(s, rec)
	check("share_one", XSkillShare.shared_ids(rec) == [auras[0]] and _has(s, 8, auras[0]) and _has(s, 9, auras[0]) and not _has(s, 10, auras[0]), [rec.share, toasts])
	check("share_one_toasts", toasts == ["光环生效：" + n0, "技能共享激活：" + n0], toasts)
	check("share_sharedBy_excludes_owner", (rec.share.sharedBy as Dictionary).keys().map(func(k): return int(k)) == [8, 9], rec.share.sharedBy)
	toasts = XSkillShare.refresh(s, rec)
	check("share_again_quiet", toasts.is_empty() and XSkillShare.shared_ids(rec) == [auras[0]], toasts)
	# 9 离开出战栏：忘掉共享来的
	s.battle_slots = [1, 8, 0, 0, 0]
	XSkillShare.refresh(s, rec)
	check("share_left_slot_forgets", not _has(s, 9, auras[0]) and _has(s, 8, auras[0]) and _has(s, 1, auras[0]), [s.actor(9).skill_ids])
	s.battle_slots = [1, 8, 0, 9, 0]
	# 点名的不是「可共享」技能：交集为空，上次共享的忘掉
	_tag(s, 1, "<ShareSkill:%d>" % l1)
	XSkillShare.refresh(s, rec)
	check("share_tag_not_marked", XSkillShare.shared_ids(rec).is_empty() and not _has(s, 8, auras[0]) and _has(s, 1, auras[0]), rec.share)
	# 五个一起：前 4 个名字加「等5项」
	var tags := ""
	for id in auras:
		tags += "<ShareSkill:%d>" % id
	_tag(s, 8, tags)
	_untag(s, 1)
	toasts = XSkillShare.refresh(s, rec)
	var order: Array = XSkillShare.shared_ids(rec).map(func(v): return int(v))
	var sorted_order := order.duplicate()
	sorted_order.sort()
	check("share_five_set", sorted_order == auras, order)
	var names: Array = order.map(func(id): return str(XDB.rec("Skills", id).name))
	check("share_five_toasts", toasts == ["光环生效：" + "、".join(names.slice(0, 4)) + " 等5项", "技能共享激活：" + "、".join(names)], toasts)
	check("share_five_all_members", auras.all(func(id): return _has(s, 8, id) and _has(s, 9, id)), s.actor(9).skill_ids)
	_untag(s, 8)
	XSkillShare.refresh(s, rec)
	check("share_untag_forgets_but_owner_keeps", auras.all(func(id): return not _has(s, 8, id) and not _has(s, 9, id) and _has(s, 1, id)), [s.actor(8).skill_ids, s.actor(9).skill_ids])

	XPartySkills.EXACT = exact_saved
	finish()


func finish() -> void:
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
