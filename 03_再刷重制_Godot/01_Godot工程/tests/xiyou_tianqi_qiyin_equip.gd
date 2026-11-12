extends Node
## 天启篇七印装备专项（XTianqiQiyinEquip、qiyin_equip.json，cc/qiyin-equip）。
## 一、数据：数字避开 4；六个部位、12 类武器的底子在；wtype_id 对上原版。
## 二、生成：套装件（部位、栏位、底子、真印 ×1.1、守层者首杀 75 级、三条词条、成色、神话）、毕业武器（类型、武器键、×1.1、说明）、神器。
## 三、打标记：生成的件 XTianqiQiyinEffects 认得（穿两件算 2 件套）；套装件谁都能穿；神器进神器栏。
## 四、揭开：揭开生成装备进背包、印库只留封着的；守层者首杀那件 75 级；神器回祭坛时进背包；已有部位认背包和身上。
## 五、熔、分解、兑换：判定、花费、词条换过去、副件没了；同名词条不给选；身上的不分解。
## 六、献武器：菜单里出、进副本拿掉那一把、几率翻倍那一场带上；没有那把进不去。
## 七、开关：ENABLED＝false 回到只亮成色、菜单没有熔炼、不分甲种失效。

class FakeHost extends RefCounted:
	var answers: Array = []
	var asked: Array = []
	var said: Array = []
	var battles: Array = []
	func show_text(_f: String, _i: int, lines: Array) -> void:
		said.append_array(lines)
	func show_text_with_choices(_f: String, _i: int, lines: Array, options: Array, _cancel: int) -> int:
		said.append_array(lines)
		asked.append(options)
		return int(answers.pop_front()) if not answers.is_empty() else options.size() - 1
	func transfer(id: int, _x: int, _y: int, _d: int, _fade := 0) -> void:
		XState.current.map_id = id
	func start_battle(troop: int, _e: bool, _l: bool, _random := false) -> int:
		battles.append({"troop": troop, "rule": XTianqiQiyinRule.pending().duplicate(true)})
		XTianqiQiyinRule._pending = {}
		return 0


var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(floor := 32, line := "war") -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, floor)
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
		XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	XTianqiQiyin.set_current("")
	XTianqiQiyin.rng_override = XRandomStream.create("0123012301230123", "qiyin")
	return s


func _rng() -> XRandomStream:
	return XRandomStream.create("5a5a5a5a5a5a5a5a", "qiyin_equip_test")


func _has(host: FakeHost, text: String) -> bool:
	return host.said.any(func(t): return str(t).contains(text))


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XSave.dir_override = "user://test_xiyou_tianqi_qiyin_equip"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	DirAccess.remove_absolute(XSave.dir_override.path_join("global.json"))
	_data()
	_make_sets()
	_make_weapons()
	_make_artifact()
	_marks()
	_reveal()
	_melt()
	_dismantle_exchange()
	await _forge_menu()
	await _offer_weapon()
	await _switch_off()
	DirAccess.remove_absolute(XGlobalVars.path())
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 一、数据 ----

func _data() -> void:
	XTianqiQiyinEquip.reload()
	_check("nice_numbers", XTianqiQiyinEquip.nice_number_violations().is_empty(), XTianqiQiyinEquip.nice_number_violations())
	var parts: Dictionary = XTianqiQiyinEquip.data().armor.parts
	_check("six_parts", parts.keys().size() == 6 and XTianqiQiyinDrop.parts().all(func(p): return parts.has(p)), parts.keys())
	for p in parts:
		_check("armor_base_%s" % p, not XDB.rec("Armors", int(parts[p].base_id)).is_empty() and parts[p].params.size() == 8, parts[p])
	var ws: Dictionary = XTianqiQiyinEquip.data().weapons
	for t in XTianqiQiyinGear.weapon_types():
		var row: Dictionary = ws.get(str(t.key), {})
		_check("weapon_base_%s" % t.key, not row.is_empty() and not XDB.rec("Weapons", int(row.base_id)).is_empty() and row.params.size() == 8, row)
	_check("artifact_base", not XDB.rec("Armors", int(XTianqiQiyinEquip.data().artifact.base_id)).is_empty())


# ---- 二、生成 ----

func _desc_set(seal: String, part: String, true_seal := false, grades := ["putong", "shangpin", "ji"]) -> Dictionary:
	return {"kind": "set", "seal": seal, "part": part, "true_seal": true_seal, "grades": grades}


func _make_sets() -> void:
	var rng := _rng()
	var all_ok := true
	var bad := []
	for seal in XTianqiQiyinDrop.seals():
		for pc in XTianqiQiyinGear.set_of(seal).pieces:
			var it := XTianqiQiyinEquip.make(_desc_set(seal, str(pc.part)), "jianxian", rng)
			var m := XTianqiQiyinEffects.mark_of(it)
			var ok: bool = not it.is_empty() and str(it.kind) == "armor" and int(it.etypeId) == int(pc.etype) and str(it.name) == str(pc.name) \
				and str(m.kind) == "set" and str(m.seal) == seal and str(m.part) == str(pc.part) and m.affixes.size() == 3
			if not ok:
				all_ok = false
				bad.append([seal, pc.part, it.get("name"), m])
	_check("sets_all_42", all_ok, bad)
	var row: Dictionary = XTianqiQiyinEquip.data().armor.parts.body
	var a := XTianqiQiyinEquip.make(_desc_set("bai", "body"), "jianxian", rng)
	_check("set_params", a.params == row.params.map(func(v): return int(v)), [a.params, row.params])
	_check("set_level_80", int(a.meta.req_level) == 80, a.meta)
	_check("set_quality_mythic", XQuality.grade_name(a) == "神话", XQuality.grade_name(a))
	_check("set_no_orig_affix", a.affixIds.is_empty() and a.traits.is_empty() and a.equipment.affixes.is_empty())
	var m := XTianqiQiyinEffects.mark_of(a)
	_check("set_grades_kept", m.grades == ["putong", "shangpin", "ji"] and m.affixes.map(func(x): return x.grade) == ["normal", "fine", "perfect"], m)
	var keys: Array = m.affixes.map(func(x): return str(x.key))
	var uniq := {}
	for k in keys:
		uniq[k] = true
	_check("set_affix_unique", uniq.size() == 3, keys)
	_check("set_affix_group", keys.all(func(k): return XTianqiAffixTable.candidates(str(XTianqiAffixTable.affix(k).layer), "fangju").has(k)), keys)
	_check("set_desc", str(a.description).contains("胜而又胜") and str(a.description).contains("2 件") and str(a.description).contains("5 件"), a.description)
	var t := XTianqiQiyinEquip.make(_desc_set("bai", "body", true, ["ji", "ji", "ji"]), "jianxian", rng)
	_check("true_set_params", t.params == row.params.map(func(v): return roundi(float(v) * 1.1)), t.params)
	_check("true_set_name", str(t.name).begins_with("【真印】"), t.name)
	var d75 := _desc_set("hong", "head")
	d75["level"] = 75
	_check("first_kill_level_75", int(XTianqiQiyinEquip.make(d75, "jianxian", rng).meta.req_level) == 75)
	# 词条层：一千件里特效不超过 2、传说不超过 1，证道比寻常出传说多
	var over := 0
	var leg := {"xunchang": 0, "zhengdao": 0}
	for dk in leg:
		for i in 300:
			var g := XTianqiQiyinEquip.roll_affixes("fangju", ["putong", "putong", "putong"], dk, rng)
			var sp := g.filter(func(x): return str(XTianqiAffixTable.affix(x.key).layer) == "special").size()
			var lg := g.filter(func(x): return str(XTianqiAffixTable.affix(x.key).layer) == "legendary").size()
			if sp > 2 or lg > 1 or g.size() != 3:
				over += 1
			leg[dk] += lg
	_check("affix_layer_caps", over == 0, over)
	_check("affix_legendary_by_difficulty", leg.xunchang == 0 and leg.zhengdao > 20, leg)
	var el := 0
	for i in 200:
		for x in XTianqiQiyinEquip.roll_affixes("bingqi", ["ji", "ji", "ji"], "zhengdao", rng):
			if XTianqiAffixTable.affix(x.key).get("random_element", false):
				el += 1 if str(x.extra.get("element", "")) != "" else -1000
	_check("affix_element_rolled", el > 0, el)
	_check("affix_line", XTianqiQiyinEquip.affix_line(m.affixes[0]) != "", m.affixes[0])
	_check("bad_desc_empty", XTianqiQiyinEquip.make({"kind": "set", "seal": "bai", "part": "ring"}, "jianxian", rng).is_empty()
		and XTianqiQiyinEquip.make({"kind": "weapon", "seal": "bai", "wtype": "笛子"}, "jianxian", rng).is_empty())


func _make_weapons() -> void:
	var rng := _rng()
	var names: Array = XDB.system().weaponTypes
	var bad := []
	for seal in XTianqiQiyinDrop.seals():
		for wt in XTianqiQiyinDrop.weapon_classes(seal):
			var it := XTianqiQiyinEquip.make({"kind": "weapon", "seal": seal, "wtype": wt, "true_seal": false, "grades": ["putong", "putong", "ji"]}, "jianxian", rng)
			var m := XTianqiQiyinEffects.mark_of(it)
			var w := XTianqiQiyinGear.weapon(str(m.get("key", "")))
			if it.is_empty() or str(it.kind) != "weapon" or str(names[int(it.wtypeId)]) != wt or str(w.seal) != seal or str(it.name) != str(w.name) \
					or str(m.wtype) != wt or (seal == "mo" and str(m.get("unique", "")) == ""):
				bad.append([seal, wt, it.get("name"), m])
	_check("weapons_all_classes", bad.is_empty(), bad)
	var w := XTianqiQiyinEquip.make({"kind": "weapon", "seal": "hong", "wtype": "剑", "true_seal": true, "grades": ["ji", "ji", "ji"]}, "jianxian", rng)
	var row: Dictionary = XTianqiQiyinEquip.data().weapons.sword
	_check("weapon_params_x11", w.params == row.params.map(func(v): return roundi(float(v) * 1.1)), w.params)
	var sc := XTianqiQiyinGear.school("hong")
	var desc := str(w.description)
	_check("weapon_desc_mark", desc.contains(str(sc.mark[0].text)) and desc.contains(str(sc.true_extra[0].text)), desc)
	_check("weapon_desc_unique", desc.contains(str(XTianqiQiyinGear.weapon(str(XTianqiQiyinEffects.mark_of(w).key)).effects[0].text)), desc)
	_check("weapon_true_name", str(w.name).begins_with("【真印】") and str(w.name).contains("止戈"), w.name)
	var keys: Array = XTianqiQiyinEffects.mark_of(w).affixes.map(func(x): return str(x.key))
	_check("weapon_affix_group", keys.size() == 3 and keys.all(func(k): return XTianqiAffixTable.candidates(str(XTianqiAffixTable.affix(k).layer), "bingqi").has(k)), keys)
	var mo := XTianqiQiyinEquip.make({"kind": "weapon", "seal": "mo", "wtype": "书", "true_seal": false, "grades": ["putong", "putong", "putong"]}, "jianxian", rng)
	_check("mo_engraved", str(mo.description).contains("不立文字刻下"), mo.description)


func _make_artifact() -> void:
	var s := _state(32)
	var a := XTianqiQiyinEquip.make({"kind": "artifact", "key": "scales"}, "jianxian", _rng())
	_check("artifact_made", str(a.name) == "天平" and int(a.etypeId) == 17 and str(XTianqiQiyinEffects.mark_of(a).kind) == "artifact", [a.get("name"), a.get("etypeId")])
	_check("artifact_allowed", XTianqiGear.allows(a))
	_check("artifact_desc_cost", str(a.description).contains("代价"), a.description)
	_check("artifact_bad_key", XTianqiQiyinEquip.make_artifact("nope").is_empty())
	var p := XTianqiQiyin.progress(s)
	p.artifacts = ["grey_scythe"]
	var got := XTianqiQiyin.claim(s)
	_check("artifact_claimed", got.size() == 1 and p.artifacts.is_empty() and p.artifacts_got == ["grey_scythe"]
		and XTianqiQiyinEquip.in_bag(s, "artifact").size() == 1, [p.artifacts, p.get("artifacts_got")])


# ---- 三、打标记、穿上 ----

func _equip(a: XActor, item: Dictionary) -> bool:
	var slots := a.equip_slots()
	var i := slots.find(int(item.etypeId))
	if i < 0:
		return false
	a.equips[i] = item
	return true


func _marks() -> void:
	var s := _state(32)
	var rng := _rng()
	var a: XActor = s.actors.values()[0]
	a._lv = 90  # 套装件要 80 级
	var h := XTianqiQiyinEquip.make(_desc_set("hei", "head"), "jianxian", rng)
	var b := XTianqiQiyinEquip.make(_desc_set("hei", "feet"), "jianxian", rng)
	_check("any_class", XTianqiQiyinEquip.any_class(h) and not XTianqiQiyinEquip.any_class({}))
	_check("can_equip_set", a.can_equip(h), [a.actor_id, h.get("atypeId")])
	var ok := _equip(a, h) and _equip(a, b)
	_check("set_counts_two", ok and int(XTianqiQiyinEffects.set_counts(a).get("hei", 0)) == 2, XTianqiQiyinEffects.set_counts(a))
	_check("worn_listed", XTianqiQiyinEquip.worn(s).size() == 2)
	_check("owned_parts_worn", XTianqiQiyinEquip.owned_parts(s).get("hei", []).size() == 2, XTianqiQiyinEquip.owned_parts(s))
	# 甲种改成没有职业能穿的 99：不分甲种照样能穿；开关关掉就穿不上
	var odd := h.duplicate(true)
	odd.atypeId = 99
	_check("any_class_odd_atype", a.can_equip(odd))
	XTianqiQiyinEquip.ENABLED = false
	_check("any_class_off", not a.can_equip(odd))
	XTianqiQiyinEquip.ENABLED = true


# ---- 四、揭开 ----

func _reveal() -> void:
	var s := _state(33)
	XTianqiQiyin.sync(s)
	var p := XTianqiQiyin.progress(s)
	var n: int = p.bag.size()
	_check("floor_kill_items", n >= 3, n)
	var lv75: Array = p.bag.filter(func(i): return int(i.get("level", 80)) == 75)
	_check("floor_kill_31_32_level_75", lv75.size() == 3, p.bag)
	var it := XTianqiQiyin.reveal(s, 0)
	var gid := str(it.get("gear", ""))
	var gear: Array = s.gear.filter(func(e): return str(e.instanceId) == gid)
	_check("reveal_makes_gear", gid != "" and gear.size() == 1 and XTianqiQiyinEquip.is_qiyin(gear[0]), it)
	_check("reveal_gear_level_75", gear.size() == 1 and int(gear[0].meta.req_level) == 75, gear[0].meta if gear.size() == 1 else null)
	_check("reveal_grades_match", gear.size() == 1 and XTianqiQiyinEffects.mark_of(gear[0]).grades == it.grades)
	_check("revealed_label_affixes", XTianqiQiyin.revealed_label(it).count("\n") == 3, XTianqiQiyin.revealed_label(it))
	_check("reveal_twice_same", XTianqiQiyin.reveal(s, 0).gear == gid and s.gear.filter(func(e): return XTianqiQiyinEquip.is_qiyin(e)).size() == 1)
	_check("owned_parts_from_gear", XTianqiQiyin._owned_by_seal(s).get(str(it.seal), []).has(str(it.part)))
	XTianqiQiyin.claim(s)
	_check("claim_compacts_bag", p.bag.size() == n - 1 and XTianqiQiyin.sealed_items(s).size() == n - 1, p.bag.size())
	_check("equip_ready", XTianqiQiyin.equip_ready())


# ---- 五、熔、分解、兑换 ----

func _pair(s: XState, seal := "zhen", part := "hands", true_seal := false) -> Array:
	var rng := _rng()
	var a := XTianqiQiyinEquip.give(s, XTianqiQiyinEquip.make({"kind": "set", "seal": seal, "part": part, "true_seal": true_seal, "grades": ["putong", "putong", "putong"],
		"affixes": [{"key": "atk", "grade": "normal", "extra": {}}, {"key": "def", "grade": "normal", "extra": {}}, {"key": "mhp", "grade": "normal", "extra": {}}]}, "jianxian", rng))
	var b := XTianqiQiyinEquip.give(s, XTianqiQiyinEquip.make({"kind": "set", "seal": seal, "part": part, "true_seal": true_seal, "grades": ["ji", "ji", "ji"],
		"affixes": [{"key": "def", "grade": "perfect", "extra": {}}, {"key": "cri", "grade": "perfect", "extra": {}}, {"key": "mdf", "grade": "perfect", "extra": {}}]}, "jianxian", rng))
	return [a, b]


func _melt() -> void:
	var s := _state(36)
	var p := XTianqiQiyin.progress(s)
	var ab := _pair(s)
	var a: Dictionary = ab[0]
	var b: Dictionary = ab[1]
	_check("affix_keys_exist", ["atk", "def", "mhp", "cri", "mdf"].all(func(k): return not XTianqiAffixTable.affix(k).is_empty()))
	var other := XTianqiQiyinEquip.give(s, XTianqiQiyinEquip.make(_desc_set("zhen", "feet"), "jianxian", _rng()))
	_check("partners", XTianqiQiyinEquip.melt_partners(s, a) == [b], XTianqiQiyinEquip.melt_partners(s, a).map(func(e): return e.name))
	_check("partners_not_other_part", not XTianqiQiyinEquip.melt_partners(s, a).has(other))
	# 换主件第 0 条（atk）：副件的 def 主件第 1 条有了，不给选
	_check("melt_choices_skip_dup", XTianqiQiyinEquip.melt_choices(a, b, 0) == [1, 2], XTianqiQiyinEquip.melt_choices(a, b, 0))
	_check("melt_choices_same_slot_ok", XTianqiQiyinEquip.melt_choices(a, b, 1) == [0, 1, 2], XTianqiQiyinEquip.melt_choices(a, b, 1))
	p.shards = 2
	_check("melt_no_shards", str(XTianqiQiyinEquip.melt(s, a, b, 0, 1).reason) == "no_shards" and s.gear.has(b))
	p.shards = 5
	_check("melt_bad_affix", str(XTianqiQiyinEquip.melt(s, a, b, 0, 0).reason) == "bad_affix" and XTianqiQiyin.shards(s) == 5)
	var r := XTianqiQiyinEquip.melt(s, a, b, 0, 1)
	var am: Dictionary = XTianqiQiyinEffects.mark_of(a)
	_check("melt_ok", r.ok and XTianqiQiyin.shards(s) == 2 and str(am.affixes[0].key) == "cri" and str(am.affixes[0].grade) == "perfect", [r, am.affixes])
	_check("melt_sub_gone", not s.gear.any(func(e): return is_same(e, b)))
	_check("melt_desc_updated", str(a.description).contains(XTianqiQiyinEquip.affix_line(am.affixes[0])))
	_check("melt_grades_untouched", am.grades == ["putong", "putong", "putong"])
	var tp := _pair(s, "zhen", "hands", true)
	p.shards = 9
	_check("melt_true_mismatch", str(XTianqiQiyinEquip.melt(s, a, tp[0], 0, 1).reason) == "true_mismatch")
	_check("melt_true_with_true", XTianqiQiyinEquip.melt_partners(s, tp[0]) == [tp[1]])
	# 主件穿在身上也能熔
	var act: XActor = s.actors.values()[0]
	s.lose_gear(tp[0], false)
	_equip(act, tp[0])
	_check("melt_main_worn", XTianqiQiyinEquip.melt_mains(s).has(tp[0]) and bool(XTianqiQiyinEquip.melt(s, tp[0], tp[1], 2, 1).ok), XTianqiQiyin.shards(s))


func _dismantle_exchange() -> void:
	var s := _state(36)
	var p := XTianqiQiyin.progress(s)
	var rng := _rng()
	var a := XTianqiQiyinEquip.give(s, XTianqiQiyinEquip.make(_desc_set("bai", "legs"), "jianxian", rng))
	var t := XTianqiQiyinEquip.give(s, XTianqiQiyinEquip.make(_desc_set("bai", "legs", true), "jianxian", rng))
	var w := XTianqiQiyinEquip.give(s, XTianqiQiyinEquip.make({"kind": "weapon", "seal": "bai", "wtype": "弓弩", "true_seal": false, "grades": ["putong", "putong", "putong"]}, "jianxian", rng))
	p.shards = 0
	_check("dismantle_set_2", XTianqiQiyinEquip.dismantle(s, a) == 2 and XTianqiQiyin.shards(s) == 2)
	_check("dismantle_true_10", XTianqiQiyinEquip.dismantle(s, t) == 10 and XTianqiQiyin.shards(s) == 12)
	_check("dismantle_weapon_10", XTianqiQiyinEquip.dismantle(s, w) == 10 and XTianqiQiyin.shards(s) == 22)
	_check("dismantle_gone", XTianqiQiyinEquip.in_bag(s).is_empty())
	var worn := XTianqiQiyinEquip.make(_desc_set("bai", "head"), "jianxian", rng)
	_equip(s.actors.values()[0], worn)
	_check("dismantle_worn_refused", XTianqiQiyinEquip.dismantle(s, worn) == 0 and XTianqiQiyin.shards(s) == 22)
	var n0: int = p.bag.size()
	var r := XTianqiQiyinEquip.exchange(s, "set", "hong", rng)
	_check("exchange_set", r.ok and XTianqiQiyin.shards(s) == 2 and p.bag.size() == n0 + 1 and not bool(p.bag[-1].revealed) and str(p.bag[-1].seal) == "hong", [r, XTianqiQiyin.shards(s)])
	_check("exchange_no_shards", str(XTianqiQiyinEquip.exchange(s, "set", "hong", rng).reason) == "no_shards" and p.bag.size() == n0 + 1)
	p.shards = 100
	var rw := XTianqiQiyinEquip.exchange(s, "weapon", "xun", rng)
	_check("exchange_weapon", rw.ok and XTianqiQiyin.shards(s) == 0 and str(rw.item.kind) == "weapon" and XTianqiQiyinDrop.weapon_classes("xun").has(str(rw.item.wtype)), rw)


func _forge_menu() -> void:
	var s := _state(36)
	var p := XTianqiQiyin.progress(s)
	_check("altar_has_forge", XTianqiQiyin.altar_options(s).any(func(o): return o.id == "forge"))
	XTianqiQiyinEquip.give(s, XTianqiQiyinEquip.make(_desc_set("bai", "legs"), "jianxian", _rng()))
	p.shards = 0
	var h := FakeHost.new()
	h.answers = [1, 0, 0]  # 分解 → 第一件 → 确认；然后返回
	await XTianqiQiyinEquip.run_forge(h, s)
	_check("forge_dismantle", XTianqiQiyin.shards(s) == 2 and XTianqiQiyinEquip.in_bag(s).is_empty() and _has(h, "得到印屑 2"), [XTianqiQiyin.shards(s), h.said])
	p.shards = 20
	var n0: int = p.bag.size()
	var h2 := FakeHost.new()
	h2.answers = [2, 0, 0]  # 兑换 → 套装件 → 第一个印
	await XTianqiQiyinEquip.run_forge(h2, s)
	_check("forge_exchange", p.bag.size() == n0 + 1 and XTianqiQiyin.shards(s) == 0 and _has(h2, "换到了"), h2.said)
	var ab := _pair(s, "hong", "waist")
	p.shards = 3
	var h3 := FakeHost.new()
	h3.answers = [0, 0, 0, 0, 0]  # 熔 → 主件 → 副件 → 换第 0 条 → 选项第 1 个（def 主件有了不给选，第一个是 cri）
	await XTianqiQiyinEquip.run_forge(h3, s)
	var am := XTianqiQiyinEffects.mark_of(ab[0])
	_check("forge_melt", XTianqiQiyin.shards(s) == 0 and str(am.affixes[0].key) == "cri" and _has(h3, "熔好了"), [am.affixes, h3.said])
	var h4 := FakeHost.new()
	h4.answers = [0]
	await XTianqiQiyinEquip.run_forge(h4, s)
	_check("forge_melt_none", _has(h4, "没有能熔的"))


# ---- 六、献武器 ----

func _offer_weapon() -> void:
	var s := _state(32)
	XTianqiQiyin.sync(s)
	var p := XTianqiQiyin.progress(s)
	p.keys = 5
	p.shards = 0
	var rng := _rng()
	var w := XTianqiQiyinEquip.give(s, XTianqiQiyinEquip.make({"kind": "weapon", "seal": "bai", "wtype": "暗器", "true_seal": false, "grades": ["putong", "putong", "putong"]}, "jianxian", rng))
	_check("offer_weapons_listed", XTianqiQiyinEquip.offer_weapons(s, "bai") == [w] and XTianqiQiyinEquip.offer_weapons(s, "hong").is_empty())
	var off := XTianqiQiyinEquip.weapon_offering(w)
	_check("offering_valid", bool(XTianqiQiyinDrop.offering_check("bai", off).ok) and int(XTianqiQiyinDrop.offering_check("bai", off).weapons) == 1, off)
	var h := FakeHost.new()
	h.answers = [0, 1, 0, 1]  # 选 bai → 献武器（印屑不够，只有「不献」「献一把」「返回」）→ 第一把 → 结算先收着
	var r: int = await XTianqiQiyin.choose_and_run(h, s)
	_check("offer_weapon_asked", h.asked.any(func(o): return o.any(func(x): return str(x).begins_with("献一把"))), h.asked)
	_check("offer_weapon_consumed", r == 0 and not s.gear.any(func(e): return is_same(e, w)) and h.battles.size() == 3, [r, h.battles.size()])
	var keys_before := XTianqiQiyin.keys(s)
	var r2 := await XTianqiQiyin.run_dungeon(FakeHost.new(), s, "bai", false, off)
	_check("offer_weapon_missing_refused", r2 == -1 and XTianqiQiyin.keys(s) == keys_before, r2)


# ---- 七、开关 ----

func _switch_off() -> void:
	var s := _state(32)
	XTianqiQiyin.sync(s)
	XTianqiQiyinEquip.ENABLED = false
	var it := XTianqiQiyin.reveal(s, 0)
	_check("off_no_gear", str(it.get("gear", "")) == "" and bool(it.revealed) and not s.gear.any(func(e): return XTianqiQiyinEquip.is_qiyin(e)))
	_check("off_no_forge", not XTianqiQiyin.altar_options(s).any(func(o): return o.id == "forge"))
	var h := XTianqiQiyinEquip.make(_desc_set("hei", "head"), "jianxian", _rng())
	_check("off_no_any_class", not XTianqiQiyinEquip.any_class(h))
	_check("off_equip_not_ready", not XTianqiQiyin.equip_ready())
	XTianqiQiyin.progress(s).artifacts = ["scales"]
	_check("off_artifact_kept", XTianqiQiyin.claim(s).is_empty() and XTianqiQiyin.progress(s).artifacts == ["scales"])
	XTianqiQiyinEquip.ENABLED = true
