class_name XBonds
extends RefCounted
## 羁绊（Star_JiBanSiklls 的 Star_GetJiBanOpt／hasBattleMembersChanged／GetActors／SkillsNew／handleSingleMemberCase），由 XPartySkills 调用。
## - 表：插件参数「JiBan i」（i=1～200）：JiBanActId 角色组、JiBanActNum 人数、JiBanNeceActId 必要角色（空＝不要求）、
##   JiBanSkiId 技能（JSON 数组，组合里第 i 人取第 i%长度 个；不是数组时整数）。每条预先生成角色组的全部 JiBanActNum 人组合（按下标顺序）。
##   原版把组合缓存进 RpgJibanDateLoaded.rpgsave，只是缓存，不写。
## - 出战成员（battle_members()）集合与上次不同才刷新。刷新：不足 2 人时上次激活的羁绊全部遗忘（组合内各人）、清空、不提示；
##   否则取出战成员的 2～5 人组合，某羁绊的某组合在里面（且含必要角色）就给组合内各人学技能、记为激活；
##   上次激活本次没有的：提示「羁绊：名字失效！」、该羁绊所有组合内各人遗忘；最后每个激活的提示「羁绊：名字激活！」（每次刷新都重播）。
## - 原版把字符串技能 ID 推进 _skills（"5594"），这里按整数学（只影响按数值查 isLearnedSkill 的地方，羁绊技能都是纯被动）。
## - 「三霄羁绊」人数 1：只生成 2～5 人组合，永远不成立，照原版。
## 记录 rec.bond：{"members": [角色] 或没有（＝null）, "active": [羁绊编号]}；O-095（XPartySkills.EXACT）另记 "by" {"角色": [技能]}，
##   只忘本系统学会的。

const MAX := 200
static var _rows: Array = []


static func rows() -> Array:
	if _rows.is_empty():
		var p := XDB.plugin("Star_JiBanSiklls")
		for i in range(1, MAX + 1):
			var raw := str(p.get("JiBan %d" % i, ""))
			var d = JSON.parse_string(raw) if raw.strip_edges() != "" else null
			if not d is Dictionary:
				continue
			var ids = JSON.parse_string(str(d.get("JiBanActId", "[]")))
			var acts: Array = (ids if ids is Array else []).map(func(v): return int(str(v).to_float()))
			var sk = JSON.parse_string(str(d.get("JiBanSkiId", "")))
			var skills: Array = (sk as Array).map(func(v): return int(str(v).to_float())) if sk is Array else [int(str(d.get("JiBanSkiId", "")).to_float())]
			var nece := int(str(d.get("JiBanNeceActId", "")).to_float())
			var n := int(str(d.get("JiBanActNum", "0")).to_float())
			_rows.append({"id": i, "name": str(d.get("JiBanName", "")), "acts": acts, "nece": nece, "num": n, "skills": skills, "combos": combos(acts, n)})
	return _rows


## getRandomArrUp：按下标顺序的全部 n 人组合
static func combos(arr: Array, n: int) -> Array:
	var out := []
	_back(arr, n, 0, [], out)
	return out


static func _back(arr: Array, n: int, start: int, cur: Array, out: Array) -> void:
	if cur.size() == n:
		out.append(cur.duplicate())
		return
	for i in range(start, arr.size()):
		cur.append(arr[i])
		_back(arr, n, i + 1, cur, out)
		cur.pop_back()


static func _rec(rec: Dictionary) -> Dictionary:
	if not rec.has("bond") or not rec.bond is Dictionary:
		rec.bond = {}
	return rec.bond


static func _members(s: XState) -> Array:
	return s.battle_members().map(func(a): return int(a.actor_id))


## 记录为 null（本会话还没刷新过）
static func never(rec: Dictionary) -> bool:
	return _rec(rec).get("members") == null


static func active_ids(rec: Dictionary) -> Array:
	return (_rec(rec).get("active", []) as Array).map(func(v): return int(v))


## hasBattleMembersChanged：按集合比
static func changed(s: XState, rec: Dictionary) -> bool:
	var cur := {}
	for id in _members(s):
		cur[id] = true
	var last := {}
	for id in (_rec(rec).get("members", []) if _rec(rec).get("members") != null else []):
		last[int(id)] = true
	return cur.size() != last.size() or cur.keys().any(func(id): return not last.has(id))


static func _key(c: Array) -> String:
	var k := c.duplicate()
	k.sort()
	return "-".join(k.map(func(v): return str(v)))


## 组合里第 i 人的技能
static func _skill(row: Dictionary, i: int) -> int:
	return int(row.skills[i % row.skills.size()]) if not row.skills.is_empty() else 0


static func _row(id: int):
	for r in rows():
		if int(r.id) == id:
			return r
	return null


## GetActors；返回要弹的提示
static func refresh(s: XState, rec: Dictionary) -> Array:
	var r := _rec(rec)
	var members := _members(s)
	r.members = members
	var last := active_ids(rec)
	var exact := XPartySkills.EXACT
	var touched := {}
	var out := []
	var active := []
	var want := {}   # EXACT：本次应有的 {角色: {技能: true}}
	if members.size() >= 2:
		var set := {}
		for n in range(2, mini(members.size(), 5) + 1):
			for c in combos(members, n):
				set[_key(c)] = true
		for row in rows():
			for c in row.combos:
				if not set.has(_key(c)) or (int(row.nece) != 0 and not c.has(int(row.nece))):
					continue
				if not active.has(int(row.id)):
					active.append(int(row.id))
				for i in c.size():
					var a := s.actor(int(c[i]))
					var id := _skill(row, i)
					if exact:
						if not want.has(a.actor_id):
							want[a.actor_id] = {}
						want[a.actor_id][id] = true
					else:
						a.learn_skill(id)
						touched[a] = true
	if exact:
		# 先忘记录里本次不该有的，再学本次该有的（学之前已有的不记）
		var by: Dictionary = r.get("by", {})
		var next := {}
		for k in by:
			var a := s.actor(int(k))
			for id in by[k]:
				if want.has(a.actor_id) and want[a.actor_id].has(int(id)):
					if not next.has(k):
						next[k] = []
					next[k].append(int(id))
				else:
					a.forget_skill(int(id))
					touched[a] = true
		for aid in want:
			var a := s.actor(int(aid))
			for id in want[aid]:
				if not a.skill_ids.has(int(id)):
					a.learn_skill(int(id))
					touched[a] = true
					if not next.has(str(aid)):
						next[str(aid)] = []
					next[str(aid)].append(int(id))
		r.by = next
	for id in last:
		if active.has(id) or members.size() < 2:
			continue
		var row = _row(id)
		if row == null:
			continue
		out.append("羁绊：" + str(row.name) + "失效！")
		if not exact:
			_forget_all(s, row, touched)
	if members.size() < 2 and not exact:
		for id in last:
			var row = _row(id)
			if row != null:
				_forget_all(s, row, touched)
	if members.size() >= 2:
		for id in active:
			out.append("羁绊：" + str(_row(id).name) + "激活！")
	r.active = active
	for a in touched:
		a.refresh_passive()
	return out


static func _forget_all(s: XState, row: Dictionary, touched: Dictionary) -> void:
	for c in row.combos:
		for i in c.size():
			var a := s.actor(int(c[i]))
			a.forget_skill(_skill(row, i))
			touched[a] = true
