extends Node
## 技能表跨调用缓存（T546，XActor.SKILLS_XCALL）：
## - 每个会改技能表的输入各一条：改了之后要重建（builds 加一）、结果与关掉缓存现算的逐项相同（技能表、按标签取的被动值）；
## - 什么都没改时连读命中、不重建；
## - 影子克隆（装备预览）各算各的；改写了 skills() 的子类 passive_values 照旧读改写版；
## - 回退开关 SKILLS_XCALL = false 两态逐项相同；全程比对（命中时现算）零不一致。
var results := []
const TAGS := ["passivePBST", "passivePBSTEX", "passiveELUP1", "passiveEXTTP"]


class TaggedActor extends XActor:
	var tagged := []
	func skills() -> Array:
		return tagged


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(600))


## 关掉缓存现算一遍（技能表＋几个标签的被动值）
func fresh(a: XActor) -> Array:
	XActor.SKILLS_XCALL = false
	var out := [a.skills(), TAGS.map(func(t): return a.passive_values(t))]
	XActor.SKILLS_XCALL = true
	return out


func cached(a: XActor) -> Array:
	return [a.skills(), TAGS.map(func(t): return a.passive_values(t))]


func ids_of(a: XActor) -> Array:
	return a.skills().map(func(s): return int(s.id))


## 改动 change 之后：要重建、结果与现算相同；want_changed＝结果确实变了（这个输入真的会改技能表）
func entry(name: String, a: XActor, change: Callable, want_changed := true) -> void:
	var before := cached(a)
	cached(a)
	var b0 := XActor.skills_xcall_builds
	change.call()
	var after := cached(a)
	var built := XActor.skills_xcall_builds > b0
	var f := fresh(a)
	check(name + ".rebuilt", built, {"builds": XActor.skills_xcall_builds - b0})
	check(name + ".same_as_fresh", after == f, {"after": after[0].map(func(s): return s.id), "fresh": f[0].map(func(s): return s.id)})
	if want_changed:
		check(name + ".changed", after != before, {"ids": after[0].map(func(s): return s.id)})


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_skills_xcall"
	XActor.read_mismatches.clear()
	var verify_was := XActor.READ_VERIFY
	XActor.READ_VERIFY = true  # 命中时现算比对（不一致记进 read_mismatches）
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var a := s.actor(1)
	for k in [6168, 5980, 5548, 2571, 2786]:
		a.learn_skill(k)
	a.change_level(30)
	a.refresh_passive()

	# 命中：什么都没改，连读不重建
	cached(a)
	var b0 := XActor.skills_xcall_builds
	var h0 := XActor.skills_xcall_hits
	for i in 5:
		cached(a)
	check("hit.no_rebuild", XActor.skills_xcall_builds == b0, XActor.skills_xcall_builds - b0)
	check("hit.counted", XActor.skills_xcall_hits > h0)
	check("hit.same_as_fresh", cached(a) == fresh(a))
	check("hit.returns_copy", not is_same(a.skills(), a.skills()))

	# 1 学会技能（learn_skill，带 read_touch）
	entry("learn_skill", a, func(): a.learn_skill(10398))
	# 2 遗忘技能
	entry("forget_skill", a, func(): a.forget_skill(10398))
	# 3 直接改 skill_ids（不经 learn_skill、没有 read_touch：靠 id 表比对）
	entry("skill_ids_direct", a, func(): a.skill_ids.append(5941); a.skill_ids.sort())
	a.skill_ids.erase(5941)
	cached(a)
	# 4 装备变化：直接换上带「增加技能」特性的武器（464 狂战 → 330；不经换装流程，靠 id 表比对）
	a.keep_unequippable = true
	var old_w = a.equips[0]
	entry("equip_direct", a, func(): a.equips[0] = XActor.make_equip("weapon", 464))
	check("equip_direct.skill_added", ids_of(a).has(330), ids_of(a))
	entry("unequip_direct", a, func(): a.equips[0] = old_w)
	a.keep_unequippable = false
	# 5 加状态（带特性加技能：686 天道祝福 → 6101…）、6 去状态
	entry("add_state", a, func(): a.add_state(686))
	check("add_state.skill_added", ids_of(a).has(6101), ids_of(a))
	entry("remove_state", a, func(): a.remove_state(686))
	# 7 直接改 state_ids（不经 add_state）
	entry("state_ids_direct", a, func(): a.state_ids.append(686); a.param_mark_dirty())
	a.state_ids.erase(686)
	a.param_mark_dirty()
	cached(a)
	# 8 等级（屠苏专属技能按等级解锁；直接改 _lv，没有任何作废调用）
	var tusu := s.actor(XTusuXuan.TUSU)
	var hengsao := 0
	var keys: Dictionary = XTusuXuan.keys(XTusuXuan.TUSU)
	for id in keys:
		if str(keys[id]) == "arm.hengsao":
			hengsao = int(id)
	tusu.change_level(5)
	tusu.learn_skill(hengsao)
	check("level.fixture", hengsao > 0 and not ids_of(tusu).has(hengsao), [hengsao, ids_of(tusu)])
	entry("level_direct", tusu, func(): tusu._lv = 10)
	check("level_direct.unlocked", ids_of(tusu).has(hengsao), ids_of(tusu))
	entry("change_level", tusu, func(): tusu.change_level(5))
	# 9 真气境界（道法技能说明按境界缩放；记录这一步的输入）
	a.learn_skill(10398)
	a.zhenqi = {"realm": 2}
	cached(a)
	entry("zhenqi_realm", a, func(): a.zhenqi = {"realm": 5})
	# 10 当前存档换了（对象）：同一个角色对象，XState.current 指向另一档
	var s2 := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s  # new_game 自己会把当前档换成新档
	cached(a)
	entry("state_current", a, func(): XState.current = s2, false)
	XState.current = s
	cached(a)
	# 11 天启篇档（rules）：技能记录换成天启篇改写版
	entry("tianqi_mode", a, func(): s.flags["tianqi"] = {"rules": 1})
	# 12 回退开关（XTianqiSkills.ENABLED：天启篇技能重构改写）
	entry("switch_toggle", a, func(): XTianqiSkills.ENABLED = false)
	XTianqiSkills.ENABLED = true
	cached(a)
	# 12b（T546 R1 P1-2）自然物攻技能单／双属性开关（XTianqiElements.PHYSICAL_DUAL_KEEP_NEUTRAL，天启篇档；86 的 elementId 14 → 0）
	a.learn_skill(86)
	cached(a)
	entry("switch.physical_dual_keep_neutral", a, func(): XTianqiElements.PHYSICAL_DUAL_KEEP_NEUTRAL = true)
	XTianqiElements.PHYSICAL_DUAL_KEEP_NEUTRAL = false
	a.forget_skill(86)
	cached(a)
	# 12c（P1-3）发行（ReleaseEntry.is_release：天启篇各层 on() 认 RELEASE_OPEN or not is_release；7238 号卷改写 → 原版）
	XTianqi.RELEASE_OPEN = false
	a.learn_skill(7238)
	cached(a)
	entry("switch.release", a, func(): ReleaseEntry.simulate_release = true)
	ReleaseEntry.simulate_release = false
	a.forget_skill(7238)
	cached(a)
	# 12d（P3-1）天启篇各模块数据表重载（reload_table 里调 skills_touch；测试切 TUNE_D* 后重载用）
	for pair in [["tianqi_skills", func(): XTianqiSkills.reload_table()], ["tianqi_elements", func(): XTianqiElements.reload_table()],
			["tianqi_general_books", func(): XTianqiGeneralBooks.reload_table()], ["tianqi_secrets", func(): XTianqiSecrets.reload_table()],
			["tianqi_weak_affix", func(): XTianqiWeakAffix.reload_table()]]:
		entry("reload." + str(pair[0]), a, pair[1], false)
	# 13 秘籍封印（天启篇档；直接写原始封印表，不经 seal）
	var secret := 0
	for id in range(1, XDB.table("Skills").size()):
		if XTianqiSecrets.occupies_slot(id) and not XDB.rec("Skills", id).is_empty():
			secret = id
			break
	a.learn_skill(secret)
	check("seal.fixture", secret > 0 and ids_of(a).has(secret), secret)
	entry("seal_raw", a, func(): XTianqiSecrets._write_actor(s, a.actor_id)["sealed"].append(secret))
	check("seal_raw.hidden", not ids_of(a).has(secret), ids_of(a))
	entry("unseal_raw", a, func(): XTianqiSecrets._write_actor(s, a.actor_id)["sealed"].erase(secret))
	# 14 弱者专属词条投影（天启篇档、角色卡开：本人装着、条目开着时技能记录换成投影版）
	var w := s.actor(17)
	w.learn_skill(188)
	var e: Dictionary = XTianqiWeakAffix.data().get("entries", {}).get("w17", {}).duplicate(true)
	e.enabled = true
	w.keep_unequippable = true
	var inst: Dictionary = (w.equips[0] if w.equips[0] is Dictionary else XActor.make_equip("weapon", 1)).duplicate(true)
	inst[XTianqiWeakAffix.ITEM_KEY] = {"key": "w17"}
	w.equips[0] = inst
	cached(w)
	entry("weak_affix_on", w, func(): XTianqiWeakAffix.test_entries["w17"] = e)
	entry("weak_affix_off", w, func(): XTianqiWeakAffix.test_entries["w17"].enabled = false)
	XTianqiWeakAffix.test_entries.erase("w17")
	s.flags.erase("tianqi")
	cached(a)
	# 15 已有的写入点都换代（宁可多建）：read_touch、state_touch、passive_touch、read_reset、batch_begin、skills_touch
	for pair in [["read_touch", func(): XActor.read_touch()], ["state_touch", func(): XActor.state_touch(4)],
			["passive_touch", func(): XActor.passive_touch()], ["read_reset", func(): XActor.read_reset()],
			["batch_begin", func(): XActor.batch_begin(); XActor.batch_end()], ["skills_touch", func(): XActor.skills_touch()]]:
		entry("epoch." + str(pair[0]), a, pair[1], false)
	# 16（P1-1）徐凤年 9998 系数（XMagicWeapon.SCALE_99_TO_888，西游档：130000 ↔ 209000）
	var xf := s.actor(152)
	xf.learn_skill(9998)
	cached(xf)
	entry("switch.scale_99_to_888", xf, func(): XMagicWeapon.SCALE_99_TO_888 = false)
	XMagicWeapon.SCALE_99_TO_888 = true
	cached(xf)
	# 17（P1-4）底表 Skills 整张换过（XDB._tables.erase 重载，不调任何作废）：苍龙重做开关、贝吉特按原版
	a.learn_skill(10093)
	cached(a)
	entry("table.canglong", a, func(): XCanglong.REWORK = false; XCanglong.clear_cache())
	XCanglong.REWORK = true
	XCanglong.clear_cache()
	a.forget_skill(10093)
	a.learn_skill(9942)
	cached(a)
	entry("table.vegeta", a, func(): XVegetaTune.original_data())
	XVegetaTune.ENABLED = true
	for n in ["Skills", "States", "CommonEvents"]:
		XDB._tables.erase(n)
	a.forget_skill(9942)
	cached(a)
	entry("table.erase_plain", a, func(): XDB._tables.erase("Skills"), false)

	# 影子克隆（装备预览）：各算各的，本体的缓存不受影响
	var item := XActor.make_equip("weapon", 464)
	var clone := XEquipment.preview(a, 0, item)
	check("clone.same_as_fresh", cached(clone) == fresh(clone))
	var hb := XActor.skills_xcall_builds
	cached(a)
	cached(a)
	check("clone.origin_still_cached", XActor.skills_xcall_builds - hb <= 1, XActor.skills_xcall_builds - hb)
	check("clone.origin_same_as_fresh", cached(a) == fresh(a))

	# 改写了 skills() 的子类：passive_values 照旧读改写版
	var t := TaggedActor.new()
	t.actor_id = 1
	t.tagged = [{"id": 1, "meta": {"passivePBST": "x"}}]
	check("subclass.passive_values", t.passive_values("passivePBST") == ["x"], t.passive_values("passivePBST"))

	# 回退两态：学很多被动、在战斗读数路径上逐项相同
	var pool := []
	var rows: Array = XDB.table("Skills")
	for i in range(1, rows.size()):
		var r = rows[i]
		if r is Dictionary and int(r.get("stypeId", 0)) == 4 and str(r.get("name", "")) != "" and not XTianqiSkills.is_shell(i):
			pool.append(i)
	for k in 120:
		a.learn_skill(pool[(k * 7919) % pool.size()])
	a.refresh_passive()
	var on_vals := _reads(a)
	XActor.SKILLS_XCALL = false
	var off_vals := _reads(a)
	XActor.SKILLS_XCALL = true
	check("rollback.two_state_equal", on_vals == off_vals, {"on": str(on_vals).left(200), "off": str(off_vals).left(200)})
	check("verify.no_mismatch", XActor.read_mismatches.is_empty(), XActor.read_mismatches)

	XActor.READ_VERIFY = verify_was
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _reads(a: XActor) -> Array:
	var out := [a.skills().map(func(s): return s.id)]
	for i in 8:
		out.append(a.param(i))
	out.append(a.mcr)
	out.append(a.max_tp())
	for t in TAGS:
		out.append(a.passive_values(t))
	return out
