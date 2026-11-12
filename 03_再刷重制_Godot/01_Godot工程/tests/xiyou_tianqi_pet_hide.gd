extends Node
## 天启篇隐藏宠物专项（XTianqiPetHide；四线异化 v0.8 第 2.4 节）。
## 天启篇存档：主菜单没有「宠物」、捕获道具／魔兽要诀／宠物口粮得不到也看不见、商店不卖、开战不掷可捕捉（敌群 1 也不强制）、
## 神秘生物不刷新且已开的关掉、星级仓库只剩「装备」；原版档、开关关掉照原版。

const CONFIG := "user://xiyou_tianqi_pet_hide_config.json"
var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _tianqi() -> XState:
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


func _plain() -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	return s


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XConfig.path_override = ProjectSettings.globalize_path(CONFIG)
	if FileAccess.file_exists(CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	XConfig._loaded_path = "<unloaded>"
	_items()
	_tianqi_side()
	_plain_side()
	_switch_off()
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


func _items() -> void:
	var ids := XTianqiPetHide.item_ids()
	_check("capture_items", [200, 315, 316, 317].all(func(i): return ids.has(i)))
	_check("books", ids.has(343) and XDB.rec("Items", 343).name.begins_with("魔兽要诀"))
	_check("food", XPets.food_items().all(func(i): return ids.has(int(i))) and not XPets.food_items().is_empty())
	_check("not_others", not ids.has(241) and not ids.has(2743) and not ids.has(1), [ids.has(241), ids.has(2743)])


func _tianqi_side() -> void:
	var s := _tianqi()
	_check("active", XTianqiPetHide.active(s))
	_check("menu_no_pet", not XMenu.commands().any(func(c): return c[1] == "pet") and XMenu.commands().any(func(c): return c[1] == "zhenqi"))
	var n0 := s.item_count(200)
	s.gain_item(200, 3)
	s.gain_item(426, 1)
	_check("gain_blocked", s.item_count(200) == n0 and s.item_count(426) == 0)
	var n1 := s.item_count(1)
	s.gain_item(1, 1)
	_check("gain_other", s.item_count(1) == n1 + 1)
	_check("goods", XTianqiPetHide.filter_goods([[0, 200], [0, 1], [1, 200]]) == [[0, 1], [1, 200]])
	var entries := [{"rec": XDB.rec("Items", 343)}, {"rec": XDB.rec("Items", 1)}]
	_check("entries", XTianqiPetHide.filter_entries(entries).size() == 1)
	# 开战：敌群 1 不强制可捕捉，没有「宝宝」
	var lg := XBattleLogic.new()
	lg.setup(1, s)
	XPetCapture.roll_battle(lg)
	_check("no_capture", lg.enemies.all(func(e): return not e.capture))
	lg.end_battle(1)
	# 神秘生物：已开的关掉、不刷新
	var m: Dictionary = XPetCapture.pet_maps().values()[0]
	s.set_self_switch(m.maps[0], m.events[0], m.switches[0], true)
	var out := XPetCapture.check(s)
	_check("mystic_off", out.is_empty() and not s.self_switch(m.maps[0], m.events[0], m.switches[0]))
	# 星级仓库：只剩装备
	_check("warehouse_cats", XStarWarehouseScene.cat_ops().size() == 1, XStarWarehouseScene.cat_ops().size())


func _plain_side() -> void:
	var s := _plain()
	_check("plain_inactive", not XTianqiPetHide.active(s))
	_check("plain_menu", XMenu.commands().any(func(c): return c[1] == "pet"))
	var n0 := s.item_count(200)
	s.gain_item(200, 1)
	_check("plain_gain", s.item_count(200) == n0 + 1)
	var lg := XBattleLogic.new()
	lg.setup(1, s)
	XPetCapture.roll_battle(lg)
	_check("plain_capture", lg.enemies[0].capture)
	lg.end_battle(1)
	_check("plain_warehouse_cats", XStarWarehouseScene.cat_ops().size() == 2)


func _switch_off() -> void:
	XTianqiPetHide.ENABLED = false
	var s := _tianqi()
	_check("off_menu", XMenu.commands().any(func(c): return c[1] == "pet"))
	var n0 := s.item_count(200)
	s.gain_item(200, 1)
	_check("off_gain", s.item_count(200) == n0 + 1)
	XTianqiPetHide.ENABLED = true
