class_name XSkillShare
extends RefCounted
## 技能共享（Star_SkilsShare 1.37 的 refreshAllSkills／collectEquipLearnSkills／hasEquipLearnSkillsChanged），由 XPartySkills 调用。
## - 出战成员＝出战栏 5 格原样（$gameParty._battleMembers，空位 0 跳过）。
## - 刷新：① 上次共享的技能从上次出战成员身上忘掉；② 上次装备学的技能从各自角色身上忘掉；
##   ③ 出战成员装备备注里的 <ShareLearnSkill:n>，没有（skills() 含特性、套装给的）就学；
##   ④ 出战成员 skills() 里 meta Share＝ShareSkill 的技能：它自己和它备注里 <ShareSkill:n> 的 n 进「可共享」；
##      出战成员全部技能备注与装备备注里的 <ShareSkill:n> 进「被点名」；两者交集（按可共享的先后）学给全体出战成员（已有不学）。
## - 装备备注取实例的 note（宝珠 <继承词缀> 接在里面），没有就取数据库备注。
## - 提示（codex installV019UsabilityRuntime 包装）：逐条「技能共享：X 激活！」吞掉，结束时本次共享里上次没有的合成一条「技能共享激活：a、b」。
## 记录 rec.share：{"members": [出战栏], "shared": [技能], "equip": {"角色": [技能]}}；O-095（XPartySkills.EXACT）另记
##   "sharedBy"／"equipBy" {"角色": [技能]}——只记本次真正学会的，遗忘时只忘这些。

const TAG_RE := "<ShareSkill:(\\d+)>"
const LEARN_RE := "<ShareLearnSkill:(\\d+)>"
static var _tag_re := RegEx.create_from_string(TAG_RE)
static var _learn_re := RegEx.create_from_string(LEARN_RE)


static func _rec(rec: Dictionary) -> Dictionary:
	if not rec.has("share") or not rec.share is Dictionary:
		rec.share = {}
	return rec.share


static func shared_ids(rec: Dictionary) -> Array:
	return _rec(rec).get("shared", [])


## 出战栏原样 5 格
static func slots(s: XState) -> Array:
	s.battle_members()  # _ensure_slots
	return s.battle_slots.map(func(v): return int(v))


static func _actor(s: XState, id: int) -> XActor:
	return s.actor(id) if id > 0 and XDB.rec("Actors", id).size() > 0 else null


static func _ids(re: RegEx, note: String) -> Array:
	return re.search_all(note).map(func(m): return int(m.get_string(1)))


static func _note(e: Dictionary) -> String:
	if e.has("note"):
		return str(e.note)
	return str(XDB.rec("Weapons" if str(e.get("kind", "")) == "weapon" else "Armors", int(e.get("base", e.get("id", 0)))).get("note", ""))


static func _equips(a: XActor) -> Array:
	return a.equips.filter(func(e): return e is Dictionary and not e.is_empty())


static func _has(a: XActor, id: int) -> bool:
	return a.skills().any(func(k): return int(k.get("id", 0)) == id)


## collectEquipLearnSkills：{"角色": [技能…]}，只列有的
static func equip_learn(s: XState) -> Dictionary:
	var out := {}
	for id in slots(s):
		var a := _actor(s, id)
		if a == null:
			continue
		var list := []
		for e in _equips(a):
			list.append_array(_ids(_learn_re, _note(e)))
		if not list.is_empty():
			out[str(id)] = list
	return out


## hasEquipLearnSkillsChanged：角色集合或任一角色的技能列表（排序后）不同
static func equip_changed(s: XState, rec: Dictionary) -> bool:
	var cur := equip_learn(s)
	var last: Dictionary = _rec(rec).get("equip", {})
	if cur.size() != last.size():
		return true
	for k in cur:
		var a: Array = (cur[k] as Array).duplicate()
		var b: Array = (last.get(k, []) as Array).duplicate()
		a.sort()
		b.sort()
		if a.map(func(v): return int(v)) != b.map(func(v): return int(v)):
			return true
	return false


## refreshAllSkills；返回要弹的提示
static func refresh(s: XState, rec: Dictionary) -> Array:
	var r := _rec(rec)
	var exact := XPartySkills.EXACT
	var members := slots(s)
	var old: Array = r.get("members", [])
	var before: Array = (r.get("shared", []) as Array).map(func(v): return int(v))
	var touched := {}
	# ① 忘上次共享的
	if exact:
		var by: Dictionary = r.get("sharedBy", {})
		for k in by:
			var a := _actor(s, int(k))
			if a != null:
				touched[a] = true
				for id in by[k]:
					a.forget_skill(int(id))
	else:
		for id in before:
			for aid in old:
				var a := _actor(s, int(aid))
				if a != null:
					touched[a] = true
					a.forget_skill(id)
	# ② 忘上次装备学的
	var last_equip: Dictionary = r.get("equipBy" if exact else "equip", {})
	for k in last_equip:
		var a := _actor(s, int(k))
		if a != null:
			touched[a] = true
			for id in last_equip[k]:
				a.forget_skill(int(id))
	# ③ 学装备的
	var learn := equip_learn(s)
	var equip_by := {}
	for k in learn:
		var a := _actor(s, int(k))
		touched[a] = true
		for id in learn[k]:
			if not _has(a, int(id)):
				a.learn_skill(int(id))
				if not equip_by.has(k):
					equip_by[k] = []
				equip_by[k].append(int(id))
	r.equip = learn
	r.equipBy = equip_by
	r.members = members
	# ④ 共享
	var marked := []
	var tagged := {}
	for aid in members:
		var a := _actor(s, aid)
		if a == null:
			continue
		for k in a.skills():
			if str(k.get("meta", {}).get("Share", "")) == "ShareSkill":
				for id in [int(k.id)] + _ids(_tag_re, str(k.get("note", ""))):
					if not marked.has(id):
						marked.append(id)
	for aid in members:
		var a := _actor(s, aid)
		if a == null:
			continue
		for k in a.skills():
			for id in _ids(_tag_re, str(k.get("note", ""))):
				tagged[id] = true
		for e in _equips(a):
			for id in _ids(_tag_re, _note(e)):
				tagged[id] = true
	var shared := marked.filter(func(id): return tagged.has(id))
	var shared_by := {}
	for id in shared:
		for aid in members:
			var a := _actor(s, aid)
			if a != null and not _has(a, id):
				touched[a] = true
				a.learn_skill(id)
				if not shared_by.has(str(aid)):
					shared_by[str(aid)] = []
				shared_by[str(aid)].append(id)
	r.shared = shared
	r.sharedBy = shared_by
	for a in touched:
		a.refresh_passive()
	for aid in members:
		var a := _actor(s, aid)
		if a != null and not touched.has(a):
			a.refresh_passive()
	var fresh := shared.filter(func(id): return not before.has(id) and XDB.rec("Skills", id).size() > 0)
	if fresh.is_empty():
		return []
	return ["技能共享激活：" + "、".join(fresh.map(func(id): return str(XDB.rec("Skills", id).get("name", ""))))]
