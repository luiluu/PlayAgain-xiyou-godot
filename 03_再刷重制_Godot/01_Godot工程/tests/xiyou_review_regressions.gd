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
	# 进度审查 25%：伤害致死后同一次行动的「附加状态」不再生效（MV isStateAddable 要求活着），存活目标照常附加
	var lethal: Dictionary = XDB.rec("Skills", 1).duplicate(true)
	lethal.damage = {"type": 1, "elementId": 0, "formula": "1000000", "formulaGd": "1000000", "variance": 0, "critical": false}
	lethal.hitType = 0
	lethal.successRate = 100
	lethal.effects = [{"code": 21, "dataId": 4, "value1": 100.0, "value2": 0.0}]
	var foe: XBattler = logic.enemies[0]
	var killed := logic.apply(a, lethal, foe)
	check("lethal_damage_skips_add_state", killed.died and foe.state_ids == [1] and killed.added.is_empty())
	var soft: Dictionary = lethal.duplicate(true)
	soft.damage.type = 0
	var foe2: XBattler = logic.enemies[1] if logic.enemies.size() > 1 else null
	if foe2 == null:
		foe.remove_state(1)
		foe.hp = foe.mhp
		foe2 = foe
	var alive_r := logic.apply(a, soft, foe2)
	check("living_target_gets_state", alive_r.added == [4] and foe2.is_state_affected(4))
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
	# MV testItemEffect：TP 恢复走 default（TP 满也可用）；HP 恢复值为负时满血也可用。
	a.tp = 100.0
	fake.effects = [{"code": 13, "dataId": 0, "value1": 10.0, "value2": 0}]
	check("tp_gain_valid_when_full", page._effective(a))
	a.hp = a.mhp
	fake.effects = [{"code": 11, "dataId": 0, "value1": 0.0, "value2": -5.0}]
	check("negative_hp_valid_when_full", page._effective(a))
	fake.effects = [{"code": 11, "dataId": 0, "value1": 0.1, "value2": 0.0}]
	check("heal_invalid_when_full", not page._effective(a))
	# 负值恢复允许使用之后，要经过 MV gainHp/gainMp 的下限钳制与阵亡同步。
	fake.effects = [{"code": 11, "dataId": 0, "value1": 0.0, "value2": -a.mhp * 2}]
	page._use()
	check("negative_hp_clamps_to_zero", a.hp == 0.0 and a.is_state_affected(1))
	a.recover_all()
	fake.effects = [{"code": 12, "dataId": 0, "value1": 0.0, "value2": -a.mmp * 2}]
	page._use()
	check("negative_mp_clamps_to_zero", a.mp == 0.0)
	a.recover_all()
	a.add_state(2)
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
	# MV 清理生命周期：阵亡清掉增减益计时，战斗结束连后备成员的临时增减益也移除。
	var all := XState.new_game(3, 1, [8, 9, 10, 2, 3, 4])
	var battle := XBattleLogic.new()
	battle.elite_roll = 100
	battle.setup(2, all)
	for member in all.members():
		member.buffs[2] = 1
		member.buff_turns[2] = 3
		member.buffs[0] = 1
		member.buffs[1] = 1
		member.hp = member.mhp
		member.mp = member.mmp
	battle._die(all.actor(9))
	check("death_clears_buff_timers", all.actor(9).buff_turns.all(func(n): return n == 0))
	battle.end_battle()
	check("battle_end_clears_bench_buffs", all.members().all(func(member): return member.buffs.all(func(n): return n == 0) and member.buff_turns.all(func(n): return n == 0) and member.hp <= member.mhp and member.mp <= member.mmp))
	page.queue_free()
	await get_tree().process_frame
	for slot in [1, 2]:
		DirAccess.remove_absolute(XSave.path(slot))
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
