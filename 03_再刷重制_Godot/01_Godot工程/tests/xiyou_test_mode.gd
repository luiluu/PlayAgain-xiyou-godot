extends Node
## 设置页「测试模式」「GM 工具」（XTestMode）：
## - 没有本机解锁文件：入口关闭（设置页两项仍留灰、状态空白）、所有功能返回「关」，哪怕状态文件写着开；
## - 有解锁文件（测试里用临时路径）：开关可切并跨重载保留；经验 ×10、使用后技能升满、普通怪掉落装备词缀加速、
##   GM 工具各项（加物品／装备／金币／经验、恢复、四种资源）的效果与数值校验；
## - 导出排除规则与 .gitignore 里有这个文件名（user:// 本身在工程之外）。
var results := []
const DIR := "user://test_xiyou_test_mode"


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _reset_files() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in ["unlock", "state"]:
		DirAccess.remove_absolute(DIR.path_join(f))
	XTestMode.unlock_override = DIR.path_join("unlock")
	XTestMode.state_override = DIR.path_join("state")
	XTestMode._on_loaded_from = "<unloaded>"
	XTestMode._on = false


func _touch(name: String, text: String) -> void:
	var f := FileAccess.open(DIR.path_join(name), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _first_with_affixes(table: String) -> int:
	var t: Array = XDB.table(table)
	for i in range(1, t.size()):
		if t[i] != null and not (t[i].get("equipment", {}).get("affixes", []) as Array).is_empty() and int(t[i].get("equipment", {}).get("affixes", [])[0].choices.size()) > 0:
			return i
	return 0


func _run() -> void:
	XSave.dir_override = DIR
	XConfig.path_override = DIR.path_join("options.json")
	XConfig._loaded_path = "<unloaded>"
	_reset_files()
	var s := XState.new_game_blank()
	XState.current = s
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)

	# ---- 没有解锁文件 ----
	_touch("state", "1")  # 状态文件写开也没用
	check("locked_unlocked_false", not XTestMode.unlocked())
	check("locked_enabled_false", not XTestMode.enabled())
	check("locked_exp_rate_1", XTestMode.exp_rate() == 1)
	check("locked_cannot_open", not XTestMode.can_open(s))
	XTestMode.set_enabled(true)
	check("locked_set_enabled_noop", not XTestMode.enabled() and FileAccess.get_file_as_string(DIR.path_join("state")) == "1")
	var gold0 := s.gold
	var r: Dictionary = XTestMode.give_gold(s, 100)
	check("locked_give_gold_refused", not r.ok and s.gold == gold0, r)
	check("locked_give_item_refused", not XTestMode.give_item(s, "items", 1, 1).ok)
	check("locked_recover_refused", not XTestMode.recover(s).ok)
	check("locked_used_skills_empty", XTestMode.used_skills(s.actor(1)).is_empty())
	var opt := XOptionsScene.new()
	add_child(opt)
	var li: Array = opt.symbols()
	var ti: int = li.find("codexTestMode")
	var gi: int = li.find("codexGM")
	check("locked_options_present", ti >= 0 and gi >= 0)
	check("locked_options_grey", not opt._list[ti][2] and not opt._list[gi][2])
	check("locked_options_status_blank", opt.status_text(ti) == "" and opt.status_text(gi) == "")
	opt.index = ti
	opt.ok()
	check("locked_ok_no_toggle", not XTestMode.enabled() and opt._page == null)
	opt.index = gi
	opt.ok()
	check("locked_gm_not_opened", opt._page == null)
	opt.queue_free()

	# ---- 有解锁文件 ----
	_reset_files()
	_touch("unlock", "")
	check("unlocked_true", XTestMode.unlocked())
	check("default_off", not XTestMode.enabled() and XTestMode.exp_rate() == 1)
	XTestMode.set_enabled(true)
	XTestMode._on_loaded_from = "<unloaded>"
	XTestMode._on = false
	check("state_persists", XTestMode.enabled() and XTestMode.exp_rate() == 10)
	XTestMode.set_enabled(false)
	check("off_again", not XTestMode.enabled())
	var opt2 := XOptionsScene.new()
	add_child(opt2)
	li = opt2.symbols()
	ti = li.find("codexTestMode")
	gi = li.find("codexGM")
	check("unlocked_options_live", opt2._list[ti][2] and opt2._list[gi][2])
	check("status_off_need", opt2.status_text(ti) == "OFF" and opt2.status_text(gi) == "需开启")
	opt2.index = ti
	opt2.ok()
	check("ok_toggles_on", XTestMode.enabled() and opt2.status_text(ti) == "ON" and opt2.status_text(gi) == "打开")
	opt2._side(false)
	check("left_turns_off", not XTestMode.enabled())
	opt2._side(true)
	check("right_turns_on", XTestMode.enabled())
	opt2.index = gi
	opt2.ok()
	check("gm_opens_scene", opt2._page is XTestModeScene)
	if opt2._page is XTestModeScene:
		var sc: XTestModeScene = opt2._page
		await get_tree().process_frame
		check("scene_lists_items", sc.results.item_count > 0 and sc.actor.item_count >= 2, [sc.results.item_count, sc.actor.item_count])
		sc.gold.value = 1234
		var g1 := s.gold
		sc._do_gold()
		check("scene_gold_button", s.gold == g1 + 1234 and sc.status.text.contains("已增加金币 1234"), sc.status.text)
		sc.close()
	opt2.queue_free()

	# ---- GM 功能 ----
	var g := s.gold
	r = XTestMode.give_gold(s, 500)
	check("gold_add", r.ok and s.gold == g + 500 and r.n == 500, r)
	for bad in [0.0, -5.0, 1.5, 1000000000.0]:
		check("gold_range_%s" % bad, not XTestMode.give_gold(s, bad).ok)
	var items := XTestMode.catalog("items", "")
	check("catalog_items", items.size() > 100 and not items.any(func(i): return str(i.name).strip_edges() == "" or str(i.name).begins_with("-")))
	var first_item: Dictionary = items[0]
	check("catalog_by_id", XTestMode.catalog("items", str(int(first_item.id)))[0].id == first_item.id)
	check("catalog_by_name", XTestMode.catalog("items", str(first_item.name)).any(func(i): return i.id == first_item.id))
	var n0 := s.item_count(int(first_item.id))
	r = XTestMode.give_item(s, "items", int(first_item.id), 7)
	check("item_add", r.ok and s.item_count(int(first_item.id)) == n0 + 7 or r.n < 7, r)
	check("item_range", not XTestMode.give_item(s, "items", int(first_item.id), 10000).ok and not XTestMode.give_item(s, "items", int(first_item.id), 0).ok)
	var w: Array = XTestMode.catalog("weapons", "")
	check("catalog_weapons_are_equipment", w.size() > 10 and w.all(func(i): return int(i.get("wtypeId", 0)) > 0))
	var gear0 := s.gear.size()
	r = XTestMode.give_item(s, "weapons", int(w[0].id), 3)
	check("weapon_add", r.ok and s.gear.size() == gear0 + 3 and r.n == 3, r)
	check("equipment_cap_99", not XTestMode.give_item(s, "weapons", int(w[0].id), 100).ok)
	check("missing_item", not XTestMode.give_item(s, "items", 999999, 1).ok)

	var a1: XActor = s.members()[0]
	var lv0 := a1.level
	var exp0 := a1.exp_total
	r = XTestMode.give_exp(s, a1.actor_id, 1000)
	check("exp_exact", r.ok and a1.exp_total == exp0 + 1000 and r.n == 1, [r, a1.exp_total, exp0])
	r = XTestMode.give_exp(s, 0, 999999999)
	check("exp_all_levels_up", r.ok and a1.level > lv0, [a1.level, lv0])
	# changeExp 末尾 refresh()：超上限的当前值被夹回（升级后 mhp／mmp 变大，当前值不得超过新上限）
	a1.hp = a1.mhp + 5000.0
	a1.mp = a1.mmp + 5000.0
	r = XTestMode.give_exp(s, a1.actor_id, 1)
	check("exp_refresh_clamps", r.ok and a1.hp == a1.mhp and a1.mp == a1.mmp, [a1.hp, a1.mhp, a1.mp, a1.mmp])
	check("exp_bad_actor", not XTestMode.give_exp(s, 99999, 10).ok)
	a1.hp = 1.0
	a1.add_state(1) if a1.has_method("add_state") else null
	r = XTestMode.recover(s)
	check("recover_full", r.ok and a1.hp == a1.mhp and not a1.state_ids.has(1), [a1.hp, a1.mhp])

	s.set_variable(206, 10)
	r = XTestMode.change_resource(s, "points", 90, "add")
	check("resource_points_add", r.ok and s.variable(206) == 100 and r.change == 90, r)
	r = XTestMode.change_resource(s, "points", 5, "set")
	check("resource_points_set", r.ok and s.variable(206) == 5, r)
	r = XTestMode.change_resource(s, "points", 0, "set")
	check("resource_set_zero", r.ok and s.variable(206) == 0)
	check("resource_add_zero_refused", not XTestMode.change_resource(s, "points", 0, "add").ok)
	r = XTestMode.change_resource(s, "fragments", 12, "set")
	check("resource_fragments", r.ok and s.item_count(2530) == 12 and s.variable(1478) == 12, r)
	check("resource_bad_key", not XTestMode.change_resource(s, "nope", 1, "add").ok)
	check("resource_bad_mode", not XTestMode.change_resource(s, "points", 1, "mul").ok)

	# ---- 战斗经验 ×10 ----
	XTestMode.set_enabled(false)
	var troop := 1
	var exp_off := _reward_exp(s, troop)
	XTestMode.set_enabled(true)
	var exp_on := _reward_exp(s, troop)
	check("exp_x10", exp_off > 0 and exp_on == exp_off * 10, [exp_off, exp_on])
	XTestMode.set_enabled(false)

	# ---- 技能使用后升满 ----
	var sid := _mastery_skill()
	var b: XActor = s.actor(1)
	check("mastery_skill_found", sid > 0)
	if sid > 0:
		b.action_mastery = [sid]
		XSkillMastery.all_actions_end(b)
		check("mastery_off_one_use", XSkillMastery.level(b, sid) <= 1, XSkillMastery.level(b, sid))
		XTestMode.set_enabled(true)
		b.mastery_levels.erase(sid)
		b.mastery_uses.erase(sid)
		b.action_mastery = [sid]
		XSkillMastery.all_actions_end(b)
		var cap := XTestMode.mastery_cap(b, sid)
		check("mastery_on_to_cap", cap > 1 and XSkillMastery.level(b, sid) == cap, [XSkillMastery.level(b, sid), cap])
		s.set_variable(13, 1)
		s.set_variable(8, 3)
		b.mastery_levels.erase(sid)
		b.action_mastery = [sid]
		XSkillMastery.all_actions_end(b)
		check("mastery_respects_difficulty_cap", XSkillMastery.level(b, sid) == mini(3, XSkillMastery.max_level(sid)), XSkillMastery.level(b, sid))
		s.set_variable(13, 0)
		XTestMode.set_enabled(false)

	# ---- 掉落装备词缀加速 ----
	var wid := _first_with_affixes("Weapons")
	check("affix_weapon_found", wid > 0)
	if wid > 0:
		XGear.force_roll = -1.0
		var normal := 0
		var boosted := 0
		var max_boost := 0
		var trials := 200
		for i in trials:
			normal += XGear.create("weapon", wid, s).affixIds.size()
			XTestMode.boost_depth += 1
			var it := XGear.create("weapon", wid, s)
			XTestMode.boost_depth -= 1
			boosted += it.affixIds.size()
			max_boost = maxi(max_boost, it.affixIds.size())
		check("boost_more_affixes", boosted > normal * 2 and boosted > trials / 2, [normal, boosted])
		check("boost_capped_4", max_boost <= XTestMode.MAX_AFFIXES, max_boost)
		check("boost_depth_restored", XTestMode.boost_depth == 0)
	# 战斗掉落：带 boost 标记的掉落走加速，没标记的（Boss）照旧；深度用完复位
	if wid > 0:
		var logic := XBattleLogic.new()
		logic.setup(troop, s, XBattleRandom.create("0000000000000176"))
		s.gear.clear()
		for i in 100:
			logic.gain_drops([{"kind": 2, "id": wid}])
		var plain: int = s.gear.map(func(e): return e.affixIds.size()).reduce(func(x, y): return x + y, 0)
		s.gear.clear()
		for i in 100:
			logic.gain_drops([{"kind": 2, "id": wid, "boost": true}])
		var fast: int = s.gear.map(func(e): return e.affixIds.size()).reduce(func(x, y): return x + y, 0)
		check("drops_boost_flag", fast > plain * 2 and XTestMode.boost_depth == 0, [plain, fast])
	XTestMode.set_enabled(true)
	var any_boss := false
	var any_plain := false
	var lg := XBattleLogic.new()
	lg.setup(troop, s, XBattleRandom.create("0000000000000176"))
	for d in lg.rewards().drops:
		any_plain = true
		any_boss = any_boss or not d.get("boost", false)
	check("rewards_tag_non_boss_drops", not any_boss or not lg.enemies.all(func(e): return not XEnemy.boss_id(e.enemy_id)), lg.rewards().drops)
	XTestMode.set_enabled(false)

	# ---- 导出排除 / gitignore ----
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var n_excl := 0
	for line in presets.split("\n"):
		if line.begins_with("exclude_filter="):
			n_excl += 1
			check("export_excludes_unlock_%d" % n_excl, line.contains("*test_mode_unlock*") and line.contains("*test_mode_state*"), line)
	check("export_presets_found", n_excl >= 2, n_excl)
	check("unlock_path_outside_project", XTestMode.UNLOCK_PATH.begins_with("user://") and XTestMode.STATE_PATH.begins_with("user://"))
	var gi_path := ProjectSettings.globalize_path("res://").path_join("../../.gitignore")
	if FileAccess.file_exists(gi_path):
		var ign := FileAccess.get_file_as_string(gi_path)
		check("gitignore_has_unlock", ign.contains("test_mode_unlock") and ign.contains("test_mode_state"))

	XTestMode.unlock_override = ""
	XTestMode.state_override = ""
	finish()


func _reward_exp(s: XState, troop: int) -> int:
	var logic := XBattleLogic.new()
	logic.setup(troop, s, XBattleRandom.create("0000000000000176"))
	return int(logic.rewards().exp)


func _mastery_skill() -> int:
	var t: Array = XDB.table("Skills")
	for i in range(1, t.size()):
		if t[i] != null and i < 10000 and XSkillMastery.max_level(i) >= 5 and XSkillMastery.usage_max(XActor.new(), i) > 1:
			return i
	return 0


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
