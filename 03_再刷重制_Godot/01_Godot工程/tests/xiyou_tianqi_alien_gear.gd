extends Node
## 天启篇异化装备专项（XTianqiAlienGear、tianqi_data/alien_gear.json；四线异化 v0.8 第 4 节）。
## 一、数据：数字避开 4、四级齐、每线 4 条、共生／夺舍／寄生化形起才出。
## 二、掉落：本线异化怪倒下按级掷；本体从它的掉落表挑；终焉没本体给核；没倒下、没掷中、原版档、开关关掉都不掉。
## 三、工坊规则：详情、按级分解、族内重抽（沿用原版待选）、取核、刻印（含替换）、净化；存档后标记还在。
## 四、工坊页：天启篇存档多出取核、净化、异化核一节，按钮点得动；原版档没有这些。
## 数字避开 4（Kyo 11-11）。

const CONFIG := "user://xiyou_tianqi_alien_gear_config.json"
const TROOP_GEAR := 1     # 嘤嘤怪：掉草帽（52）、毛布裤（53）
const TROOP_NO_GEAR := 69 # 灵狼祭祀：只掉物品
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(line := "war") -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	s.set_variable(20, 3)
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
		XTianqiLine.progress(line, s)["stage"] = XTianqiLine.stage_done(line)
	return s


## 开一场、把第一只怪变成 line 的 level 级异化、打死它、发奖；返回 logic
func _fight(s: XState, troop: int, line: String, level: String, kill := true) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	var e: XEnemy = lg.enemies[0]
	var kinds: Array = XTianqiLine.alien_kinds(line)
	XTianqiLine.alien_apply(line, lg, s, [{"enemy": e, "tier": level, "kind": str(kinds[0])}])
	if kill:
		e.hp = 0
		e.add_state(1)
	lg.grant(lg.rewards())
	return lg


func _tq_gear(s: XState) -> Array:
	return s.gear.filter(func(i): return XTianqiAlienGear.is_tq(i))


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig._loaded_path = "<unloaded>"
	_data()
	_drops()
	_rules()
	await _page()
	XTianqiAlienGear.force_roll = -1.0
	XAlienation.force_roll = -1.0
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig.path_override = ""
	XConfig._loaded_path = "<unloaded>"
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 一、数据 ----

func _data() -> void:
	XTianqiAlienGear.reload()
	var d := XTianqiAlienGear.data()
	_check("draft", d.get("draft") == true)
	_check("nice_numbers", XTianqiAlienGear.nice_number_violations().is_empty(), XTianqiAlienGear.nice_number_violations())
	_check("levels_four", (d.level_order as Array).size() == 4 and (d.level_order as Array).all(func(k): return d.levels.has(k)))
	_check("rates", XTianqiAlienGear.level_info("qinran").rate == 0.03 and XTianqiAlienGear.level_info("zhongyan").rate == 1.0)
	for line in ["war", "famine", "plague", "death"]:
		_check("line_four_" + line, XTianqiAlienGear.line_keys(line).size() == 4)
		_check("family_full_" + line, XTianqiAlienGear.family(line, "huaxing").size() == 4)
	_check("late_only_low", not XTianqiAlienGear.family("plague", "shigu").has("lifelink") and XTianqiAlienGear.family("plague", "shigu").size() == 3,
		XTianqiAlienGear.family("plague", "shigu"))
	_check("new_affix_view", str(XTianqiAlienGear.affix_view(_state(), "dying").name) == "临终" and XTianqiAlienGear.is_new_affix("venom"))
	_check("old_affix_new_name", str(XTianqiAlienGear.affix_view(_state(), "hollow").name) == "血铠")


# ---- 二、掉落 ----

func _drops() -> void:
	var s := _state("war")
	XTianqiAlienGear.force_roll = 0.0
	var lg := _fight(s, TROOP_GEAR, "war", "shigu")
	var got := _tq_gear(s)
	_check("drop_one", got.size() == 1, got.map(func(i): return i.name))
	if got.is_empty():
		return
	var i: Dictionary = got[0]
	var t := XTianqiAlienGear.tq(i)
	_check("drop_mark", str(t.line) == "war" and str(t.level) == "shigu" and XTianqiAlienGear.line_keys("war").has(str(i.alien.affix)), i.alien)
	_check("drop_body", [52, 53].has(int(i.base)) and str(i.kind) == "armor", [i.kind, i.base])
	_check("drop_name", str(i.name).begins_with("蚀骨·") and str(i.name).contains(XTianqiAlienGear.affix_name(str(i.alien.affix))), i.name)
	_check("drop_text", lg.victory_texts.any(func(x): return str(x) == "获得 " + str(i.name)), lg.victory_texts)
	_check("drop_recent", str(XAlienation.ledger(s).recent[0].name) == str(i.name))
	# 没掷中
	XTianqiAlienGear.force_roll = 0.5
	var s2 := _state("war")
	_fight(s2, TROOP_GEAR, "war", "huaxing")
	_check("miss_none", _tq_gear(s2).is_empty())
	# 没倒下
	XTianqiAlienGear.force_roll = 0.0
	var s3 := _state("war")
	_fight(s3, TROOP_GEAR, "war", "zhongyan", false)
	_check("alive_none", _tq_gear(s3).is_empty())
	# 终焉、掉落表没有本体：给核
	var s4 := _state("famine")
	var before := XTianqiAlienGear.cores(s4).size()
	_fight(s4, TROOP_NO_GEAR, "famine", "zhongyan")
	var cs := XTianqiAlienGear.cores(s4)
	_check("zhongyan_core", _tq_gear(s4).is_empty() and cs.size() == before + 1 and str(cs[-1].level) == "zhongyan" and str(cs[-1].line) == "famine", cs)
	# 侵染、没本体：什么都不给
	var s5 := _state("famine")
	_fight(s5, TROOP_NO_GEAR, "famine", "qinran")
	_check("qinran_no_body_none", _tq_gear(s5).is_empty() and XTianqiAlienGear.cores(s5).is_empty())
	# 开关关掉
	XTianqiAlienGear.ENABLED = false
	var s6 := _state("war")
	_fight(s6, TROOP_GEAR, "war", "zhongyan")
	_check("off_none", _tq_gear(s6).is_empty())
	XTianqiAlienGear.ENABLED = true
	# 原版档：不掉
	var plain := XState.new()
	plain.add_actor(1)
	XState.current = plain
	var lp := XBattleLogic.new()
	lp.setup(TROOP_GEAR, plain)
	lp.enemies[0].hp = 0
	lp.enemies[0].add_state(1)
	lp.grant(lp.rewards())
	_check("plain_none", _tq_gear(plain).is_empty())
	# 本体筛选：专属武器、法宝不算
	_check("body_filter", XTianqiAlienGear.body_ok(XGear.template("armor", 52)) and not XTianqiAlienGear.body_ok(XGear.template("armor", 3612)))


# ---- 三、工坊规则 ----

func _rules() -> void:
	var s := _state("war")
	var r := XTianqiAlienGear.create(s, "armor", 52, "war", "shigu", "inversebone")
	var i: Dictionary = r.ok
	s.gear.append(i)
	_check("create_name", str(i.name) == "蚀骨·装甲冲击·草帽", i.name)
	var det := XAlienation.details(s, i)
	_check("details", str(det[0]).contains("装甲冲击") and str(det[0]).contains("蚀骨") and str(det[3]).contains("2点"), det)
	# 存档往返
	var back := XState.from_dict(s.to_dict())
	var bi = back.gear.filter(func(e): return XTianqiAlienGear.is_tq(e))
	_check("saved", bi.size() == 1 and str(XTianqiAlienGear.tq(bi[0]).level) == "shigu" and str(bi[0].name) == str(i.name))
	# 重抽：本线本级、沿用原版待选
	s.gain_item(XAlienation.stone_id(), 5)
	XAlienation.force_roll = 0.0
	var rr := XAlienation.reroll(s, i)
	_check("reroll_pending", rr.has("ok") and XTianqiAlienGear.family("war", "shigu").has(str(rr.ok.next)) and str(rr.ok.next) != "inversebone", rr)
	XAlienation.resolve(s, true)
	_check("reroll_relabel", str(i.name).begins_with("蚀骨·") and str(i.name).ends_with("·草帽") and str(i.alien.affix) != "inversebone", i.name)
	_check("reroll_stone", s.item_count(XAlienation.stone_id()) == 4)
	# 分解按级
	var d2: Dictionary = XTianqiAlienGear.create(s, "armor", 53, "war", "huaxing", "faceless").ok
	s.gear.append(d2)
	var e0 := s.item_count(XAlienation.energy_id())
	var dr := XAlienation.dismantle(s, d2)
	_check("dismantle_level", dr.get("ok") == 5 and s.item_count(XAlienation.energy_id()) == e0 + 5 and not s.gear.has(d2), dr)
	# 取核
	var c0 := XTianqiAlienGear.cores(s).size()
	var affix := str(i.alien.affix)
	var xr := XTianqiAlienGear.extract_core(s, i)
	var cs := XTianqiAlienGear.cores(s)
	_check("extract", xr.has("ok") and cs.size() == c0 + 1 and str(cs[-1].affix) == affix and str(cs[-1].level) == "shigu" and not s.gear.has(i), cs)
	_check("core_label", XTianqiAlienGear.core_label(cs[-1]).begins_with("蚀骨·"), XTianqiAlienGear.core_label(cs[-1]))
	# 刻印到一件普通装备
	s.gain_gear("armor", 53, 1)
	var plain_item: Dictionary = s.gear.filter(func(e): return int(e.base) == 53 and XAlienation.mark(e).is_empty())[0]
	var st0 := s.item_count(XAlienation.stone_id())
	var er := XTianqiAlienGear.engrave(s, cs.size() - 1, plain_item)
	_check("engrave", er.has("ok") and str(XTianqiAlienGear.tq(plain_item).level) == "shigu" and str(plain_item.alien.affix) == affix
		and XTianqiAlienGear.cores(s).size() == c0 and s.item_count(XAlienation.stone_id()) == st0 - 1, [er, plain_item.get("name")])
	_check("engrave_name", str(plain_item.name).begins_with("蚀骨·") and str(plain_item.name).ends_with("毛布裤"), plain_item.name)
	# 刻印替换：再给一颗终焉核刻到同一件
	XTianqiAlienGear.add_core(s, "war", "again", "zhongyan", "test")
	var er2 := XTianqiAlienGear.engrave(s, XTianqiAlienGear.cores(s).size() - 1, plain_item)
	_check("engrave_replace", er2.has("ok") and str(plain_item.alien.affix) == "again" and str(plain_item.name) == "终焉·再动·毛布裤", plain_item.name)
	_check("new_affix_active", not XAlienation.details(s, plain_item).any(func(x): return str(x).begins_with("未生效")))
	# 刻印不到穿着的、法宝
	var a: XActor = s.members()[0]
	var worn: Dictionary = a.equip_list().filter(func(e): return e is Dictionary and not e.is_empty())[0] if not a.equip_list().filter(func(e): return e is Dictionary and not e.is_empty()).is_empty() else {}
	XTianqiAlienGear.add_core(s, "war", "swallow", "qinran", "test")
	if not worn.is_empty():
		_check("engrave_not_worn", XTianqiAlienGear.engrave(s, XTianqiAlienGear.cores(s).size() - 1, worn).has("error"))
	s.gain_gear("armor", 3612, 1)
	var fabao: Dictionary = s.gear.filter(func(e): return int(e.base) == 3612)[0]
	_check("engrave_not_fabao", XTianqiAlienGear.engrave(s, XTianqiAlienGear.cores(s).size() - 1, fabao).has("error"))
	# 净化
	var e1 := s.item_count(XAlienation.energy_id())
	var pr := XTianqiAlienGear.purify(s, plain_item)
	_check("purify", pr.get("ok") == 5 and XAlienation.mark(plain_item).is_empty() and str(plain_item.name) == "毛布裤"
		and s.item_count(XAlienation.energy_id()) == e1 + 5, [pr, plain_item.name])


# ---- 四、工坊页 ----

func _flat_texts(page) -> Array:
	return XAlienWorkshop.flatten(page.tree).map(func(r): return str(r.get("text", "")))


func _page() -> void:
	var s := _state("plague")
	s.gain_item(XAlienation.stone_id(), 3)
	var i: Dictionary = XTianqiAlienGear.create(s, "armor", 52, "plague", "huaxing", "mimic").ok
	s.gear.append(i)
	XTianqiAlienGear.add_core(s, "plague", "insulation", "shigu", "test")
	s.gain_gear("armor", 53, 1)
	XAlienWorkshop.selected = ""
	var page := XAlienWorkshop.new()
	add_child(page)
	await get_tree().process_frame
	var texts := _flat_texts(page)
	_check("page_buttons", texts.has("取核") and texts.has("使用1颗异化石净化") and texts.has("分解为5点能量"), texts)
	_check("page_cores", texts.has("异化核（1）") and texts.has("蚀骨·心无旁骛 异化核") and texts.has("刻上（1颗异化石）"), texts)
	# 刻上：默认刻到第一件能刻的（背包里的草帽异化件或毛布裤），改选毛布裤
	var target: Dictionary = s.gear.filter(func(e): return int(e.base) == 53)[0]
	page.set_value("engrave", str(target.instanceId))
	await get_tree().process_frame
	_check("page_engrave", page.click("刻上（1颗异化石）") and str(XTianqiAlienGear.tq(target).get("level", "")) == "shigu" and XTianqiAlienGear.cores(s).is_empty(), target.get("name"))
	# 取核要确认
	XAlienWorkshop.selected = str(i.alien.uid)
	page.render()
	await get_tree().process_frame
	_check("page_core_confirm", page.click("取核") and _flat_texts(page).has("确认取核"))
	_check("page_core_done", page.click("确认取核") and not s.gear.has(i) and XTianqiAlienGear.cores(s).size() == 1)
	page.queue_free()
	# 原版档没有这些
	var plain := XState.new()
	plain.add_actor(1)
	XState.current = plain
	var r: Dictionary = XAlienation.create(plain, "a", 52, "boss")
	if r.has("ok"):
		plain.gear.append(r.ok)
	XAlienWorkshop.selected = ""
	var pp := XAlienWorkshop.new()
	add_child(pp)
	await get_tree().process_frame
	var pt := _flat_texts(pp)
	_check("plain_page", not pt.has("取核") and not pt.any(func(x): return x.begins_with("异化核")), pt)
	pp.queue_free()
