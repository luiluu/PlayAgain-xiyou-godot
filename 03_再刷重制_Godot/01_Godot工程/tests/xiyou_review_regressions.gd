extends Node
## 核查发现的玩家流程边界：错误对象不消耗药品、指定复活对象、状态道具、损坏存档与写入失败保留旧档。
var results := []


func check(name: String, ok: bool) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_review_regressions"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var s := XState.new_game(3, 1, [8, 9, 10])
	var a := s.actor(1)
	var dead := s.actor(9)
	var page := XItemScene.new()
	add_child(page)
	await get_tree().process_frame
	s.gain_item(1, 3)
	dead.add_state(1)
	page._item = XDB.rec("Items", 1)
	page._actor = s.party.find(9)
	page._use()
	check("healing_cannot_revive", dead.hp == 0 and s.item_count(1) == 3)
	s.gain_item(137, 2)
	page._item = XDB.rec("Items", 137)
	page._actor = 0
	page._use()
	check("revival_cannot_heal_living", s.item_count(137) == 2)
	page._actor = s.party.find(9)
	page._use()
	check("menu_revive_removes_death", dead.is_alive() and not dead.is_state_affected(1) and s.item_count(137) == 1)
	check("menu_revive_heal_rounded", dead.hp == minf(dead.mhp, 1 + floorf(dead.mhp * 0.2 * dead.rec * a.pha)))
	var logic := XBattleLogic.new()
	logic.elite_roll = 100
	logic.setup(2, s)
	s.actor(8).add_state(1)
	dead.add_state(1)
	s.gain_item(183, 1)  # 回魂秘药(137)仅菜单使用；复活秘药(183)可用于战斗。
	logic.execute(a, XDB.rec("Items", 183), dead)
	check("battle_revives_selected_dead", dead.is_alive() and s.actor(8).is_dead() and s.item_count(183) == 0)
	logic.end_battle()
	# 阵亡的药物知识高者不能充当菜单物品的使用者。
	var phantom := XGear.template("armor", 1)
	phantom.traits.append({"code": 23, "dataId": 3, "value": 10.0})
	s.actor(8).equips[1] = phantom
	s.actor(8).refresh_passive()
	s.actor(8).add_state(1)
	page._item = XDB.rec("Items", 1)
	page._actor = 0
	a.change_level(30)  # 最大HP大于500，避免回复量被低等级上限夹住而掩盖选人错误。
	a.hp = 1
	page._use()
	check("dead_pharmacist_not_selected", a.hp == minf(a.mhp, 1 + floorf(500 * a.rec * a.pha)))
	# 不保留测试药物知识装备，后面的存档仍用真实合法槽位。
	s.actor(8).equips[1] = null
	s.actor(8).refresh_passive()
	s.gain_item(1, 1)
	# 效果栏添加状态的道具：原 _effective 允许，但 _use 没有执行任何效果。
	var fake := XDB.rec("Items", 1).duplicate(true)
	fake.effects = [{"code": 21, "dataId": 2, "value1": 1.0, "value2": 0}]
	page._item = fake
	page._actor = 0
	page._use()
	check("menu_add_state_applies", a.is_state_affected(2) and s.item_count(1) == 2)
	page._use()
	check("repeated_state_does_not_consume", s.item_count(1) == 2)
	# 存档写入、覆盖、读取及错误档处理，全部在专用测试目录。
	a.tp = 37
	a.state_turns[2] = 4
	a.buffs[2] = 1
	a.buff_turns[2] = 3
	check("save_valid", XSave.save(1))
	var before := FileAccess.get_file_as_string(XSave.path(1))
	check("saved_shape_valid", XSave.valid_data(JSON.parse_string(before)))
	DirAccess.make_dir_recursive_absolute(XSave.path(1) + ".tmp")
	check("failed_write_preserves_save", not XSave.save(1) and FileAccess.get_file_as_string(XSave.path(1)) == before)
	DirAccess.remove_absolute(XSave.path(1) + ".tmp")
	s.gold = 12345
	check("atomic_overwrite", XSave.save(1) and XSave.load_slot(1) and XState.current.gold == 12345 and not FileAccess.file_exists(XSave.path(1) + ".tmp"))
	var restored := XState.current.actor(1)
	check("save_preserves_combat_state", restored.tp == 37 and restored.state_turns.get(2) == 4 and restored.buffs[2] == 1 and restored.buff_turns[2] == 3)
	var previous := XState.current
	var f := FileAccess.open(XSave.path(2), FileAccess.WRITE)
	f.store_string('{"mode":"xiyou","version":2}')
	f.close()
	check("broken_summary_safe", XSave.summary(2) == "存档 2：无法读取")
	check("broken_load_keeps_current", not XSave.load_slot(2) and is_same(XState.current, previous) and XSave.current_slot == 1)
	var future: Dictionary = JSON.parse_string(before)
	future.version = 999
	check("future_version_rejected", not XSave.valid_data(future))
	var legacy: Dictionary = JSON.parse_string(before)
	for row in legacy.actors.values():
		for field in ["tp", "stateTurns", "buffs", "buffTurns"]:
			row.erase(field)
	check("legacy_save_optional_fields", XSave.valid_data(legacy) and XState.from_dict(legacy).actor(1).tp == 0)
	check("invalid_slot_rejected", not XSave.save(0) and not XSave.exists(31) and not XSave.load_slot(0))
	page.queue_free()
	await get_tree().process_frame
	for slot in [1, 2]:
		DirAccess.remove_absolute(XSave.path(slot))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
