extends Node
## 【cc·白龙_13·未经审查】176 屠苏、177 璇第一期（XTusuXuan）：照参照 tusu_growth_probe（tests/fixtures/tusu_growth_oracle.json）——
## 标签查表、招募（入队、法宝只送一次、璇的星谱初值与星纹技能）、23 个等级升上去再降回来逐级比学会的技能、列出的技能、
## 各伤害键系数与各解锁键；归形战斗外不能用；别人身上的专属技能按本体等级滤；读档同步。
const FIXTURE := "res://tests/fixtures/tusu_growth_oracle.json"
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(400))


func ints(a) -> Array:
	return (a as Array).map(func(v): return int(v))


func sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort()
	return out


func fresh() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.actor_max_level = 99
	s.set_switch(XItemMarks.SUPER_SWITCHES[0], true)  # 超强者可获取（原版的门槛在 recruit 外层 D.recruitments，参照里直接调模块）
	return s


## 只比专属技能与参照里出现过的：开超强者开关后难度被动（地狱难度 5562 等）会进来，参照的新游戏没有
func listed(a) -> Array:
	return own_only(a.skills().map(func(x): return int(x.id)))


func own_only(ids: Array) -> Array:
	return sorted(ids.filter(func(v): return XTusuXuan.owner_of(int(v))[0] != 0))


func _ready() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("oracle", ref.cases.size() == 10)
	var obs := {}
	for c in ref.cases:
		obs[str(c.id)] = c.observed
	for id in [XTusuXuan.TUSU, XTusuXuan.XUAN]:
		var o: Dictionary = obs["ids.%d" % id]
		var keys := XTusuXuan.keys(id)
		check("ids.%d.skills" % id, keys.size() == o.skill.size() and o.skill.keys().all(func(k): return XTusuXuan.skill_id(id, k) == int(o.skill[k])), [keys.size(), o.skill.size()])
		check("ids.%d.relic" % id, int(XTusuXuan.RELICS[id]) == int(o.relic) and ints(o.levels) == XTusuXuan.LEVELS)
		check("ids.%d.unlock" % id, o.unlock.keys().all(func(k): return int(XTusuXuan.UNLOCK[id].get(k, -1)) == int(o.unlock[k])) and o.unlock.size() == XTusuXuan.UNLOCK[id].size())
		# 招募
		o = obs["recruit.%d" % id]
		var s := fresh()
		var a := s.actor(id)
		check("recruit.%d.before" % id, own_only(a.skill_ids) == own_only(ints(o.before)), [sorted(a.skill_ids), o.before])
		var first := XTusuXuan.recruit(s, id)
		var slot := a.equip_slots().find(13)
		var worn = a.equips[slot] if slot >= 0 else null
		check("recruit.%d" % id, first == bool(o.first) and s.party == ints(o.party) and own_only(a.skill_ids) == own_only(ints(o.skills)), [first, s.party, own_only(a.skill_ids), o])
		check("recruit.%d.relic" % id, worn is Dictionary and int(worn.get("base", 0)) == int(o.equips[0].base) and slot == int(o.equips[0].slot) \
			and s.gear.is_empty(), [slot, worn, s.gear])
		if o.chart != null:
			var c := XTusuXuan.chart(s)
			check("recruit.%d.chart" % id, JSON.stringify(JSON.parse_string(JSON.stringify(c)), "", true) == JSON.stringify(o.chart, "", true), [c, o.chart])
		check("recruit.%d.second" % id, XTusuXuan.recruit(s, id) == bool(o.second))
		s.remove_actor(id)
		s.gear.append(a.equips[slot])
		a.equips[slot] = null
		check("recruit.%d.third" % id, XTusuXuan.recruit(s, id) == bool(o.third) and s.gear.map(func(e): return int(e.base)) == ints(o.armorsAfter) \
			and (a.equips[slot] == null or (a.equips[slot] is Dictionary and a.equips[slot].is_empty())), [s.gear, a.equips[slot]])
		# 等级
		o = obs["levels.%d" % id]
		s = fresh()
		a = s.actor(id)
		XTusuXuan.recruit(s, id)
		var i := 0
		for row in o.rows:
			a.change_level_mv(int(row.level))
			var coef := (o.keys as Array).map(func(k): return XTusuXuan.coefficient(id, k))
			var unl := (o.ukeys as Array).map(func(k): return 1 if XTusuXuan.unlocked(id, a, k) else 0)
			check("levels.%d.%d.learned" % [id, i], own_only(a.skill_ids) == own_only(ints(row.learned)), [row.level, own_only(a.skill_ids), row.learned])
			check("levels.%d.%d.listed" % [id, i], listed(a) == own_only(ints(row.listed)), [row.level, listed(a), row.listed])
			check("levels.%d.%d.coef" % [id, i], coef == ints(row.coef) and unl == ints(row.unlocked), [row.level, coef, row.coef, unl, row.unlocked])
			i += 1
		# 归形战斗外不能用
		o = obs["return.%d" % id]
		a.change_level_mv(60)
		var logic := XBattleLogic.new()
		logic.state = s
		check("return.%d" % id, XTusuXuan.skill_id(id, "return") == int(o.sid) and logic.can_use(a, XDB.rec("Skills", int(o.sid))) == bool(o.meets))
		# 别人身上的专属技能按本体等级滤
		o = obs["shared.%d" % id]
		var other := s.actor(1)
		for sid in o.skills:
			other.learn_skill(int(sid))
		for row in o.rows:
			a.change_level_mv(int(row.level))
			var got := listed(other).filter(func(v): return XTusuXuan.keys(id).has(v))
			check("shared.%d.%d" % [id, int(row.level)], got == ints(row.listed), [got, row.listed])
		# 不能用没解锁的（在本体 1 级时用别人身上的 support／growth 技能）
		a.change_level_mv(1)
		var locked := int(o.skills[0])
		check("shared.%d.meets" % id, not XTusuXuan.meets(other, XDB.rec("Skills", locked)))
		# 读档同步：存档里 60 级却没学高阶技能，读回来补上
		a.change_level_mv(60)
		var full := sorted(a.skill_ids)
		var high := (a.class_data().learnings as Array).filter(func(l): return XTusuXuan.keys(id).has(int(l.skillId)) and int(l.level) > 1)
		for l in high:
			a.forget_skill(int(l.skillId))
		var loaded := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
		XTusuXuan.after_load(loaded)
		check("load.%d" % id, not high.is_empty() and sorted(loaded.actor(id).skill_ids) == full, [high.size(), sorted(loaded.actor(id).skill_ids), full])
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_tusu", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
