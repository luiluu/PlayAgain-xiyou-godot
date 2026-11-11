extends Node
## 天启篇开局（XTianqi，Kyo 2026-11-10）：
## 一、随机阵容：五档各抽 200 次，人数、不重复、弱者下限、超强者上限、候选池（寻常／艰险无超强者）；lineup_ok 能拒绝坏阵容。
## 二、标题新游戏三页：存档位 10 格、五档难度（证道锁定）、随机阵容页可重抽。
## 三、实跑开局：九死、存档位 3、固定阵容 → 大厅跑完开局指令与 EV020 → 阵容、道号、存档位、难度、开关、物品、1 号位技能、
##     存档里的规则版本；没有教派、没有号角。
## 四、天启篇存档关羁绊、超强者按难度限出战；原版开局建的档不受影响。
## 存档写到 user://test_xiyou_tianqi，测试结束删除。

var results: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _scene() -> Node:
	return get_tree().current_scene


func _wait(cond: Callable, timeout := 6000) -> bool:
	for i in range(timeout):
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _map_idle(map_id: int) -> bool:
	var s = _scene()
	return s is XMapScene and s.map_id == map_id and s.player != null and not s.busy


func _find(root: Node, name: String) -> Node:
	return root.find_child(name, true, false)


func _run() -> void:
	XMessageBox.auto = true
	XBattleScene.force_auto = true
	XSave.dir_override = "user://test_xiyou_tianqi"
	Engine.time_scale = 6.0
	seed(20261110)
	_lineups()
	await _title_pages()
	await _opening()
	_rules()
	await _revert()
	for slot in range(1, 11):
		DirAccess.remove_absolute(XSave.path(slot))
	DirAccess.remove_absolute(XSave.dir())
	Engine.time_scale = 1.0
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _lineups() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261110
	for d in XTianqi.DIFFICULTIES:
		var bad := []
		var seen_super := false
		var firsts := {}
		for i in 200:
			var l := XTianqi.roll_lineup(d.key, rng)
			var weak := l.filter(func(id): return XTier.is_weak(id)).size()
			var supers := l.filter(func(id): return XTier.is_super(id)).size()
			var uniq := {}
			for id in l:
				uniq[id] = true
			seen_super = seen_super or supers > 0
			firsts[l[0]] = true
			if l.size() != 5 or uniq.size() != 5 or weak < int(d.min_weak) or supers > int(d.super_cap) or not XTianqi.lineup_ok(d.key, l) \
					or l.any(func(id): return XImportedBalance.is_disabled_actor(id)):
				bad.append(l)
		_check("roll_%s" % d.key, bad.is_empty(), bad.slice(0, 3))
		_check("roll_%s_super_seen" % d.key, seen_super == (int(d.super_cap) > 0), seen_super)
		_check("roll_%s_varied" % d.key, firsts.size() > 20, firsts.size())
	var w: Array = XTier.ids(XTier.WEAK)
	var sup: Array = XTier.ids(XTier.SUPER)
	_check("lineup_ok_rejects", not XTianqi.lineup_ok("jiusi", [w[0], w[0], w[1], w[2], w[3]])
		and not XTianqi.lineup_ok("jiusi", [w[0], w[1], w[2], sup[0], sup[1]])
		and not XTianqi.lineup_ok("jianxian", [w[0], w[1], w[2], w[3], sup[0]])
		and not XTianqi.lineup_ok("jiusi", [w[0], w[1], w[2], w[3]])
		and XTianqi.lineup_ok("jiusi", [w[0], w[1], w[2], w[3], sup[0]]))
	_check("zhengdao_locked", XTianqi.locked("zhengdao") and not XTianqi.locked("lianyu"))


func _title_pages() -> void:
	_check("enter_xiyou", GameApp.enter_mode("xiyou"))
	await _wait(func(): return _scene() != null and _scene().has_method("_tq_slot"), 300)
	var entry = _scene()
	entry._tq_slot()
	await get_tree().process_frame
	var slots := range(1, 11).filter(func(i): return _find(entry, "TianqiSlot%d" % i) != null)
	_check("page_slots", slots.size() == 10, slots)
	entry._tq_difficulty(2)
	await get_tree().process_frame
	var diffs := {}
	for d in XTianqi.DIFFICULTIES:
		var b = _find(entry, "TianqiDifficulty_" + str(d.key))
		diffs[d.key] = b != null and b.icon != null and b.disabled == XTianqi.locked(d.key)
	_check("page_difficulty", diffs.values().all(func(v): return v), diffs)
	entry._tq_lineup(2, "lianyu", [])
	await get_tree().process_frame
	_check("page_lineup", _find(entry, "TianqiReroll") != null and _find(entry, "TianqiConfirm") != null)


func _opening() -> void:
	var w: Array = XTier.ids(XTier.WEAK).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var sup: Array = XTier.ids(XTier.SUPER).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var lineup := [w[5], sup[0], w[1], w[2], w[3]]
	_check("fixed_lineup_ok", XTianqi.lineup_ok("jiusi", lineup), lineup)
	XMessageBox.auto_answers = ["测试道号"]
	XTianqi.start_new_game(3, "jiusi", lineup)
	var s := XState.current
	s.random_master = XRandomStream.hex64(20261110)
	get_tree().change_scene_to_file("res://modes/xiyou/map/map_scene.tscn")
	var ok := await _wait(func(): return _map_idle(4) and s.self_switch(4, 20, "A"))
	_check("hub_reached", ok, [s.map_id])
	_check("party", s.party == lineup, s.party)
	_check("dao_hao", s.actor_name == "测试道号", s.actor_name)
	_check("slot", s.fixed_save_slot() == 3 and XSave.exists(3), [s.fixed_save_slot(), XSave.exists(3)])
	_check("difficulty", s.difficulty == 4 and s.switch(2490) and s.switch(2500) and s.flags.get("DCultyL4") == true, [s.difficulty, s.flags])
	_check("switches", s.switch(682) and s.switch(14) and s.switch(15) and s.switch(166) and int(s.variable(20)) == 1)
	_check("no_sect", not s.switch(2301) and not s.switch(2302) and not s.switch(2303) and not s.switch(2307))
	_check("items", s.item_count(4) == 1 and s.item_count(2896) == 1 and s.item_count(10) == 0 and s.item_count(1395) == 1,
		[s.item_count(4), s.item_count(2896), s.item_count(10), s.item_count(1395)])
	_check("first_slot_skills", s.actor(lineup[0]).skill_ids.has(2571) and s.actor(lineup[0]).skill_ids.has(2786))
	_check("init_events_ran", s.switch(1561) and range(1694, 1700).any(func(id): return s.switch(id)))
	_check("active", XTianqi.active(s) and XTianqi.super_cap(s) == 1)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(XSave.path(3)))
	var flags = saved.get("flags", {}) if saved is Dictionary else {}
	_check("saved_rules", flags is Dictionary and flags.get("tianqi") is Dictionary and int(flags.tianqi.get("rules", 0)) == 1
		and str(flags.tianqi.get("difficulty", "")) == "jiusi", flags.get("tianqi") if flags is Dictionary else saved)
	# 大厅首次到达的漩涡过场（EV76）放完再离开，免得协程挂着
	await _wait(func(): return _map_idle(4) and s.self_switch(4, 76, "A"))


func _rules() -> void:
	var s := XState.current
	_check("bonds_off", not XBonds.enabled(s) and not XBonds.changed(s, {}) and XBonds.refresh(s, {}).is_empty())
	var sup: Array = XTier.ids(XTier.SUPER).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	for id in sup.slice(0, 2):
		if not s.party.has(id):
			s.party.append(id)
			s.actor(id)
	s.battle_slots = [sup[0], sup[1], s.party[0], 0, 0]
	XItemMarks.enforce_party(s)
	var on_field := s.battle_slots.filter(func(id): return XTier.is_super(int(id)))
	_check("super_cap_enforced", on_field == [sup[0]], s.battle_slots)
	_check("can_deploy_cap", not XItemMarks.can_deploy(s, sup[1], 1) and XItemMarks.can_deploy(s, sup[1], XTianqi.HELPER_SLOT) and XItemMarks.can_deploy(s, sup[0]) and XItemMarks.can_acquire_actor(s, sup[1]))
	# 原版开局建的档：不是天启篇，羁绊照旧、超强者按原版
	var old := XState.new_game_blank()
	_check("legacy_untouched", not XTianqi.active(old) and XBonds.enabled(old) and XTianqi.super_cap(old) == -1 and not XItemMarks.can_acquire_actor(old, sup[0]))
	XBonds.TIANQI_OFF = false
	_check("bonds_switch_back", XBonds.enabled(s))
	XBonds.TIANQI_OFF = true


## 开关回退：XTianqi.ENABLED = false 时标题「新的游戏」回到原版 Map001 开局（不是天启篇存档）
func _revert() -> void:
	XTianqi.ENABLED = false
	_check("enter_xiyou_again", GameApp.enter_mode("xiyou"))
	await _wait(func(): return _scene() != null and _scene().has_method("_on_new_game"), 300)
	_scene()._on_new_game()
	var s := XState.current
	_check("revert_original_opening", s.map_id == 1 and not XTianqi.active(s) and not XTianqi.has_pending(), [s.map_id, s.flags])
	# 同一帧再切回标题，不真的进 Map001（开局事件的协程挂着退出会报资源未释放）
	GameApp.enter_mode("xiyou")
	await _wait(func(): return _scene() != null and _scene().has_method("_on_new_game"), 300)
	XTianqi.ENABLED = true
