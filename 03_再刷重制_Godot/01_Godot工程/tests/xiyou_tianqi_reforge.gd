extends Node
## 天启篇装备重铸专项（XTianqiReforge；cc 草案，表 tianqi_data/reforge.json）。
## 同一层重抽、不和别的词条重复、阶与槽数不变、不出稀有、按阶扣金钱、金钱不够／穿着的不能重铸、工坊页按钮点得动、原版档没有。

const CONFIG := "user://xiyou_tianqi_reforge_config.json"
const T := preload("res://modes/xiyou/core/tianqi_affix_table.gd")
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state() -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 0
	XState.current = s
	return s


func _find_weapon() -> int:
	var table: Array = XDB.table("Weapons")
	for r in table:
		if r is Dictionary and str(r.get("name", "")) != "":
			var tpl := XGear.template("weapon", int(r.id))
			if XQuality.grade(tpl) == 6 and XTianqiAffixRoll.tier_of(tpl) == 4 and not XEquipment.is_exclusive(tpl):
				return int(r.id)
	return 0


## 一件带三条词条的神话四阶武器：基础、特效、传说各一条（先手、连击是这件能出的）
func _make(s: XState, wid: int) -> Dictionary:
	var it := XGear.create("weapon", wid, s)
	XTianqiAffixRoll.set_affixes(it, [{"key": str(XTianqiAffixRoll.layer_candidates(it, "base")[0]), "tier": 4, "grade": "normal", "extra": {}},
		{"key": str(XTianqiAffixRoll.layer_candidates(it, "special")[0]), "tier": 4, "grade": "normal", "extra": {}},
		{"key": "first_strike", "tier": 4, "grade": "normal", "extra": {}}])
	s.register_gear(it)
	s.gear.append(it)
	return it


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig._loaded_path = "<unloaded>"
	var s := _state()
	var wid := _find_weapon()
	_check("found", wid > 0)
	var it := _make(s, wid)
	var before: Array = (it.tianqi_affixes as Array).duplicate(true)
	s.gold = 50000
	# 重铸基础那一条：还是基础层、阶不变、不和另两条重复、扣四阶的钱
	var r := XTianqiReforge.reforge(s, it, 0, func(): return 0.6)
	var after: Array = it.tianqi_affixes
	_check("reforge_ok", r.has("ok") and after.size() == 3, r)
	_check("same_layer", str(T.affix(str(after[0].key)).layer) == "base" and int(after[0].tier) == 4)
	_check("others_kept", str(after[1].key) == str(before[1].key) and str(after[2].key) == str(before[2].key))
	_check("cost_tier4", s.gold == 40000, s.gold)
	# 传说那一条：不出稀有（连击、再动）
	var cs := XTianqiReforge.choices(it, 2)
	_check("no_rare", not cs.is_empty() and not cs.has("combo") and not cs.has("reaction"), cs)
	_check("no_dup", not cs.has(str(after[0].key)) and not cs.has(str(after[1].key)))
	var ok := true
	for i in 20:
		var rr := XTianqiReforge.reforge(s, it, 2, func(): return randf())
		if rr.has("error"):
			break
		ok = ok and not bool(T.affix(str(it.tianqi_affixes[2].key)).get("rare", false)) and str(T.affix(str(it.tianqi_affixes[2].key)).layer) == "legendary"
	_check("legendary_stays_legendary", ok)
	_check("desc_rewritten", str(it.description).contains(XTianqiAffixText.line(str(it.tianqi_affixes[2].key), 4, str(it.tianqi_affixes[2].grade), it.tianqi_affixes[2].get("extra", {}))))
	# 金钱不够
	s.gold = 10
	_check("poor", XTianqiReforge.reforge(s, it, 0).has("error") and s.gold == 10)
	s.gold = 50000
	# 穿着的不能重铸
	var worn := _make(s, wid)
	var a: XActor = s.members()[0]
	a.equips[a.equip_slots().find(1)] = worn  # 直接穿上（等级需求不够，测的只是「穿着的不能重铸」）
	s.lose_gear(worn, false)
	var on := a.equip_list().has(worn)
	_check("worn_blocked", on and XTianqiReforge.reforge(s, worn, 0).has("error"), on)
	# 工坊页：有「装备重铸」一节，按钮点得动
	XAlienWorkshop.selected = ""
	var page := XAlienWorkshop.new()
	add_child(page)
	await get_tree().process_frame
	page.set_value("reforge", str(it.instanceId))
	await get_tree().process_frame
	var texts := XAlienWorkshop.flatten(page.tree).map(func(x): return str(x.get("text", "")))
	_check("page_section", texts.has("装备重铸") and texts.has("重铸第1条（10000金钱）"), texts)
	var g0 := s.gold
	_check("page_click", page.click("重铸第1条（10000金钱）") and s.gold == g0 - 10000)
	page.queue_free()
	# 开关关掉、原版档
	XTianqiReforge.ENABLED = false
	_check("off", XTianqiReforge.reforge(s, it, 0).has("error"))
	XTianqiReforge.ENABLED = true
	var plain := XState.new_game(3, 1, [8, 9, 10])
	_check("plain", not XTianqiReforge.on(plain))
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig.path_override = ""
	XConfig._loaded_path = "<unloaded>"
	var passed := results.filter(func(x): return x.passed).size()
	for x in results:
		if not x.passed:
			print("FAIL ", x.name, " ", JSON.stringify(x.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
