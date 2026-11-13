extends Node
## 【cc·未经审查】专武·特效吸取（XAffixAbsorb＋商人页 absorb 模式＋技能页入口），对照 installAbyssMerchantRuntime v0.36 的规则写的手算断言
## （没有 mv_oracle 参照：原版吸取要走界面，探针未做）：开放专武、槽位按所属角色等级、额外特效识别、吸取校验与错误文字、
## 效果视图（equip_list 换视图、raw_equip_list／real 取本体、特性与备注带上吸取的特效、本体改动后视图跟着变）、存档往返、界面行文字。
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func _ready() -> void:
	_run.call_deferred()


## 找一把开放专武和它的一名所属角色
func pick_weapon() -> Array:
	for w in XDB.table("Weapons"):
		if w is Dictionary and not XActor.absorb_owners(int(w.id)).is_empty():
			return [int(w.id), int(XActor.absorb_owners(int(w.id))[0])]
	return []


func material_with(s: XState, base: int, d: Dictionary) -> Dictionary:
	var m := XGear.template("weapon", base)
	XGear.combine(m, XAffixAbsorb.record(d), "prefix")
	m.affixIds.append({"table": str(d.db), "id": int(d.id), "kind": "prefix"})
	s.register_gear(m)
	s.gear.append(m)
	return m


func _run() -> void:
	var wa := pick_weapon()
	check("found weapon", not wa.is_empty())
	if wa.is_empty():
		_finish()
		return
	var wid: int = wa[0]
	var aid: int = wa[1]
	var s := XState.new_game_blank()
	XState.current = s
	s.party.clear()
	s.add_actor(aid)
	var a := s.actor(aid)
	if not s.party.has(aid):
		s.party.append(aid)  # 有的所属角色新局 add_actor 进不了队（天启篇／禁用名单等），测试直接放进队伍
	a.change_level(1)
	var cfg: Dictionary = XAbyssMerchant.config()
	var d1: Dictionary = cfg.affixes.mod[0]
	var d2: Dictionary = cfg.affixes.mythic[0]
	d1 = {"db": str(d1.db), "id": int(d1.id)}
	d2 = {"db": str(d2.db), "id": int(d2.id)}
	var target := XGear.create("weapon", wid, s)
	s.register_gear(target)
	a.equips[0] = target
	var plain := XGear.template("weapon", 1)
	s.register_gear(plain)
	s.gear.append(plain)
	var m1 := material_with(s, 1, d1)
	var m2 := material_with(s, 1, d2)

	# 开放专武、槽位
	check("can_absorb", XAffixAbsorb.can_absorb(target))
	check("not absorb plain", not XAffixAbsorb.can_absorb(plain))
	check("cap lv1", XAffixAbsorb.capacity(target, s) == 1)
	check("targets", XAffixAbsorb.targets(s).size() == 1 and is_same(XAffixAbsorb.targets(s)[0], target))
	check("label", XAffixAbsorb.label(d1) == "Mod特效:最大物攻+5%", XAffixAbsorb.label(d1))

	# 额外特效
	var ex := XAffixAbsorb.extra_affixes(m1)
	check("extra m1", ex.any(func(x): return x.db == d1.db and x.id == d1.id), ex)
	check("extra plain none", XAffixAbsorb.extra_affixes(plain).is_empty())
	var mats := XAffixAbsorb.materials(s, target)
	check("materials", mats.size() == 2 and mats.any(func(x): return is_same(x, m1)) and mats.any(func(x): return is_same(x, m2)), mats.map(func(x): return x.name))
	var merch := XGear.template("weapon", 1)
	merch[XAffixAbsorb.EXTRA_KEY] = d2
	check("extra merchant only", XAffixAbsorb.extra_affixes(merch) == [d2])

	# 校验与错误文字
	check("err slot", XAffixAbsorb.absorb(s, target, m1, d1, 1) == "所选吸取槽位尚未开放。")
	check("err affix", XAffixAbsorb.absorb(s, target, m1, d2, 0) == "材料不包含所选额外特效。")
	check("err plain target", XAffixAbsorb.absorb(s, plain, m1, d1, 0) == "请先持有当前开放的专武。")
	var name0 := str(m1.name)
	m1.name = name0 + "[锁定]"
	check("err locked", XAffixAbsorb.absorb(s, target, m1, d1, 0) == "请选择背包中未锁定、未装备的材料。")
	m1.name = name0
	check("unchanged after errors", not target.has(XAffixAbsorb.KEY) and s.gear.has(m1))

	# 吸取
	var traits0 := (target.traits as Array).size()
	var rec1 := XAffixAbsorb.record(d1)
	check("absorb ok", XAffixAbsorb.absorb(s, target, m1, d1, 0) == "")
	check("material consumed", not s.gear.any(func(x): return is_same(x, m1)))
	check("stored", target[XAffixAbsorb.KEY] == [d1], target.get(XAffixAbsorb.KEY))
	var v: Dictionary = a.equip_list()[0]
	check("view", v.has(XAffixAbsorb.VIEW_FLAG) and not is_same(v, target))
	check("view traits", (v.traits as Array).size() == traits0 + (rec1.traits as Array).size())
	check("view note", str(v.note).contains("Mod特效:最大物攻+5%"))
	check("view cached", is_same(a.equip_list()[0], v))
	check("real", is_same(XAffixAbsorb.real(v), target))
	check("raw list", is_same(a.raw_equip_list()[0], target))
	check("owns", s.owns_gear(target))
	check("target untouched", (target.traits as Array).size() == traits0 and not str(target.note).contains("Mod特效:最大物攻+5%"))
	var t1: Dictionary = rec1.traits[0]
	check("actor trait", a.all_traits().any(func(t): return int(t.code) == int(t1.code) and int(t.dataId) == int(t1.dataId) and float(t.value) == float(t1.value)))
	check("rows", XMerchant29Page.absorb_rows(s)[0].text == "%s（1／1条）" % str(target.name), XMerchant29Page.absorb_rows(s))

	# 本体改动后视图跟着变
	var atk0 := float(v.params[2])
	target.params[2] = float(target.params[2]) + 10.0
	check("view follows params", float(a.equip_list()[0].params[2]) == atk0 + 10.0)

	# 等级开槽、第二槽、替换
	a.change_level(35)
	check("cap lv35", XAffixAbsorb.capacity(target, s) == 2)
	var sr := XMerchant29Page.slot_rows(s, target)
	check("slot rows", sr.map(func(r): return r.text) == ["槽位1：Mod特效:最大物攻+5%", "槽位2：空槽", "槽位3：所属角色60级开放"] and sr.map(func(r): return r.enabled) == [true, true, false], sr)
	check("absorb slot2", XAffixAbsorb.absorb(s, target, m2, d2, 1) == "")
	check("stored2", target[XAffixAbsorb.KEY] == [d1, d2])
	var v2: Dictionary = a.equip_list()[0]
	check("view2 notes", str(v2.note).contains("Mod特效:最大物攻+5%") and str(v2.note).contains(XAffixAbsorb.label(d2)))
	a.change_level(60)
	check("cap lv60", XAffixAbsorb.capacity(target, s) == 3)
	var m3 := material_with(s, 1, d2)
	check("replace slot1", XAffixAbsorb.absorb(s, target, m3, d2, 0) == "")
	check("stored3", target[XAffixAbsorb.KEY] == [d2, d2])

	# 存档往返（JSON 把编号变成小数）
	var back = JSON.parse_string(JSON.stringify(target))
	back.instanceId = "xg:test-roundtrip"
	var rv := XAffixAbsorb.view(back, s)
	check("roundtrip view", rv.has(XAffixAbsorb.VIEW_FLAG) and (rv.traits as Array).size() == (v2.traits as Array).size() - (rec1.traits as Array).size() + (XAffixAbsorb.record(d2).traits as Array).size())

	# 旧单条描述（字典）照认
	var legacy := XGear.create("weapon", wid, s)
	s.register_gear(legacy)
	legacy[XAffixAbsorb.KEY] = d1
	check("legacy", XAffixAbsorb.absorptions(legacy) == [d1] and XAffixAbsorb.view(legacy, s).has(XAffixAbsorb.VIEW_FLAG))

	# 技能页入口
	var sc := XSkillScene.new()
	add_child(sc)
	await get_tree().process_frame
	sc.actor_index = 0
	check("skill usable", sc.usable(XDB.rec("Skills", XActor.AFFIX_ABSORB_SKILL)))
	sc.open_absorb()
	await get_tree().process_frame
	check("page open", sc.absorb_page != null and sc.absorb_page.mode == "absorb" and sc.absorb_page.rows.size() == 1 and XAbyssMerchant.active)
	sc.absorb_page._close()
	await get_tree().process_frame
	check("page closed", sc.absorb_page == null and not XAbyssMerchant.active)
	sc.queue_free()
	_finish()


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
