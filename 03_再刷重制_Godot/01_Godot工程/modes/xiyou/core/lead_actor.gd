class_name XLeadActor
extends RefCounted
## 领袖技能（Star_LeadActor 的 Star_GetLeadOpt／getLeadSkiId／LearnSkill），由 XPartySkills 调用；整队出战栏的领袖旗标见 XPartyScene。
## - 表：插件参数「Lead i」（i=1～200）：LeadActId 角色、LeadSkiId 技能。同一角色取第一条。
## - 刷新：首位（出战栏第 0 格原样，空位 0）没有领袖技能、且没有上次记录时什么都不做；否则先从上次学的人身上忘掉上次的领袖技能；
##   首位有领袖技能时给出战栏全体学（空位跳过）并记下。首位没有时记录不清（下次再忘一次，无害）。
## 记录 rec.lead：{"ranks": [首位, 技能] 或 [], "learners": [角色]}；O-095（XPartySkills.EXACT）时 learners 只记真正学会的（学之前已有不记）。

const MAX := 200
static var _rows: Array = []


static func rows() -> Array:
	if _rows.is_empty():
		var p := XDB.plugin("Star_LeadActor")
		for i in range(1, MAX + 1):
			var raw := str(p.get("Lead %d" % i, ""))
			var d = JSON.parse_string(raw) if raw.strip_edges() != "" else null
			if d is Dictionary:
				_rows.append({"id": i, "actor": int(str(d.get("LeadActId", "0")).to_float()), "skill": int(str(d.get("LeadSkiId", "0")).to_float())})
	return _rows


## getLeadSkiId：没有为 0
static func skill_of(actor_id: int) -> int:
	for r in rows():
		if int(r.actor) == actor_id:
			return int(r.skill)
	return 0


## 整队出战栏的领袖旗标：该角色是领袖角色且在出战栏第 0 格
static func is_leader(s: XState, actor_id: int) -> bool:
	return skill_of(actor_id) != 0 and not s.battle_slots.is_empty() and int(s.battle_slots[0]) == actor_id


static func _rec(rec: Dictionary) -> Dictionary:
	if not rec.has("lead") or not rec.lead is Dictionary:
		rec.lead = {}
	return rec.lead


static func ranks(rec: Dictionary) -> Array:
	return (_rec(rec).get("ranks", []) as Array).map(func(v): return int(v))


## LearnSkill（不弹提示）
static func refresh(s: XState, rec: Dictionary) -> Array:
	var r := _rec(rec)
	var slots := XSkillShare.slots(s)
	var leader: int = slots[0] if not slots.is_empty() else 0
	var skill := skill_of(leader)
	var old := ranks(rec)
	if skill == 0 and old.is_empty():
		return []
	var touched := {}
	if old.size() > 1 and old[1] != 0:
		for id in r.get("learners", []):
			var a := s.actor(int(id))
			a.forget_skill(old[1])
			touched[a] = true
	if skill != 0:
		var learners := []
		r.ranks = [leader, skill]
		for id in slots:
			if id <= 0 or XDB.rec("Actors", id).is_empty():
				continue
			var a := s.actor(id)
			if XPartySkills.EXACT and a.skill_ids.has(skill):
				continue
			a.learn_skill(skill)
			touched[a] = true
			learners.append(id)
		r.learners = learners
	for a in touched:
		a.refresh_passive()
	return []
