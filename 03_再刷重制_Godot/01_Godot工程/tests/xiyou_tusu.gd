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
	# 审查第 22 期 P3-1：本体没建过时（原版 $gameActors._data[本体] 为空）别人的专属技能全滤、不能用，系数按 1 级，且不顺手建出本体
	for id in [XTusuXuan.TUSU, XTusuXuan.XUAN]:
		var s := fresh()
		s.actors.erase(id)
		var other := s.actor(1)
		var sid := XTusuXuan.skill_id(id, str(XTusuXuan.keys(id).values()[0]))
		other.learn_skill(sid)
		check("no_owner.%d.filtered" % id, not other.skills().any(func(x): return int(x.id) == sid))
		check("no_owner.%d.meets" % id, not XTusuXuan.meets(other, XDB.rec("Skills", sid)))
		var key := str(XTusuXuan.DAMAGE[id].keys()[0])
		check("no_owner.%d.coef" % id, XTusuXuan.coefficient(id, key) == floori(XGuyu.curve(1, XTusuXuan.DAMAGE[id][key], XTusuXuan.LEVELS)))
		check("no_owner.%d.not_created" % id, not s.actors.has(id), s.actors.keys())
	# 审查第 24 期 P3-1：开机后没打过仗（屠苏种类没登记）就读档，屠苏身上的武具／空形态状态也要清掉（原版模块装入时就登记）
	var s9 := fresh()
	var t9 := s9.actor(XTusu.ACTOR)
	var forms := [XTusu.state_id("armed"), XTusu.state_id("empty")]
	for sid in forms:
		t9.state_ids.append(sid)
		t9.state_turns[sid] = 0
	var dump := JSON.stringify(s9.to_dict())
	XBinding.kinds.erase("tusu")
	var loaded9 := XState.from_dict(JSON.parse_string(dump))
	check("load_forms.cleared", not forms.any(func(sid): return loaded9.actor(XTusu.ACTOR).state_ids.has(sid)), loaded9.actor(XTusu.ACTOR).state_ids)
	check("load_forms.kind", XBinding.kinds.has("tusu"))
	# 器谱开刃（tusu5，照原版 T.forgeRows／setKairen／syncKairenSkills 逐行写的例，没有参照）
	var sf := fresh()
	XTusuXuan.recruit(sf, XTusu.ACTOR)
	var tf := sf.actor(XTusu.ACTOR)
	var kid := func(w): return XTusu.skill_id("kairen." + w)
	check("forge.rows0", XTusu.forge_rows(sf).map(func(r): return r.label) == ["器谱　开刃 0/3", "（未开放）第1道铭文：未开刃", "（未开放）第2道铭文：未开刃", "（未开放）第3道铭文：未开刃"], XTusu.forge_rows(sf))
	check("forge.locked", XTusu.set_kairen(sf, 0, "bow") == "invalid")
	sf.actor_advance[XTusu.ACTOR] = 2
	check("forge.set0", XTusu.set_kairen(sf, 0, "bow") == "" and tf.skill_ids.has(kid.call("bow")))
	check("forge.dup", XTusu.set_kairen(sf, 1, "bow") == "invalid")
	check("forge.set1", XTusu.set_kairen(sf, 1, "hammer") == "" and tf.skill_ids.has(kid.call("hammer")))
	check("forge.slot2_closed", XTusu.set_kairen(sf, 2, "book") == "invalid")
	check("forge.reforge_cost", XTusu.set_kairen(sf, 0, "sword").begins_with("重新开刃需要"), XTusu.set_kairen(sf, 0, "sword"))
	sf.gain_item(XTusu.REFORGE_ITEM, 12)
	check("forge.reforge", XTusu.set_kairen(sf, 0, "sword") == "" and sf.item_count(XTusu.REFORGE_ITEM) == 2 and tf.skill_ids.has(kid.call("sword")) and not tf.skill_ids.has(kid.call("bow")))
	check("forge.same_free", XTusu.set_kairen(sf, 0, "sword") == "" and sf.item_count(XTusu.REFORGE_ITEM) == 2)
	check("forge.rows2", XTusu.forge_rows(sf).map(func(r): return r.label) == ["器谱　开刃 2/3", "第1道铭文：开刃·剑", "第2道铭文：开刃·锤", "（未开放）第3道铭文：未开刃"], XTusu.forge_rows(sf))
	sf.actor_advance[XTusu.ACTOR] = 1  # 读档时按阶数同步：第二道超出阶数，开刃·锤忘掉
	var lf := XState.from_dict(JSON.parse_string(JSON.stringify(sf.to_dict())))
	check("forge.load_sync", lf.actor(XTusu.ACTOR).skill_ids.has(kid.call("sword")) and not lf.actor(XTusu.ACTOR).skill_ids.has(kid.call("hammer")), lf.actor(XTusu.ACTOR).skill_ids)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_tusu", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
