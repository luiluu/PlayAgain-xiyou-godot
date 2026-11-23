extends Node
## 天启篇开局（XTianqi，Kyo 2026-11-10）：
## 一、随机阵容：五档各抽 1000 次（D265 取消弱者人数下限），人数、不重复、弱者数 0～5（寻常／艰险出现 0 弱者）、超强者上限、候选池（寻常／艰险无超强者）；lineup_ok 接受 0 弱者与全弱者并拒绝坏阵容。
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
	for d0 in XTianqi.DIFFICULTIES:
		var d := XTianqi.difficulty(d0.key)  # super_cap／min_weak 并自数值表（第三批；D265 起 min_weak=0）
		var p := XTianqi.pool(d.key)
		var pool_all: Array = p[XTier.WEAK] + p[XTier.STRONG] + p[XTier.SUPER]
		var bad := []
		var seen_super := false
		var firsts := {}
		var weak_min := 6
		var weak_max := -1
		var zero_weak := 0
		# D265：五档各抽 1000 次，不再检查 weak >= min_weak，验证候选池、超强者上限与弱者数分布（0～5）
		for i in 1000:
			var l := XTianqi.roll_lineup(d.key, rng)
			var weak := l.filter(func(id): return XTianqiSkills.is_weak(id, true)).size()
			var supers := l.filter(func(id): return XTianqiSkills.is_super(id, true)).size()
			var uniq := {}
			for id in l:
				uniq[id] = true
			seen_super = seen_super or supers > 0
			firsts[l[0]] = true
			weak_min = mini(weak_min, weak)
			weak_max = maxi(weak_max, weak)
			if weak == 0:
				zero_weak += 1
			if l.size() != 5 or uniq.size() != 5 or supers > XTianqi.lineup_super_max(d.key) or not XTianqi.lineup_ok(d.key, l) \
					or l.any(func(id): return not pool_all.has(int(id)) or XImportedBalance.is_disabled_actor(id)):
				bad.append(l)
		_check("roll_%s" % d.key, bad.is_empty(), bad.slice(0, 3))
		_check("roll_%s_super_seen" % d.key, seen_super == (int(d.super_cap) > 0), seen_super)
		_check("roll_%s_varied" % d.key, firsts.size() > 20, firsts.size())
		_check("roll_%s_weak_range_d265" % d.key, weak_min >= 0 and weak_max <= 5 and (zero_weak > 0 if d.key in ["xunchang", "jianxian"] else weak_min <= 1),
			{"weak_min": weak_min, "weak_max": weak_max, "zero_weak": zero_weak})
	var w: Array = XTianqiSkills.ids(XTier.WEAK, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var st: Array = XTianqiSkills.ids(XTier.STRONG, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var sup: Array = XTianqiSkills.ids(XTier.SUPER, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not [95, 173].has(id))
	_check("lineup_ok_rejects", not XTianqi.lineup_ok("jiusi", [w[0], w[0], w[1], w[2], w[3]])
		and not XTianqi.lineup_ok("jiusi", [w[0], w[1], w[2], sup[0], sup[1]])
		and not XTianqi.lineup_ok("jianxian", [w[0], w[1], w[2], w[3], sup[0]])
		and not XTianqi.lineup_ok("jiusi", [w[0], w[1], w[2], w[3]])
		and not XTianqi.lineup_ok("jiusi", [w[0], w[1], w[2], w[3], sup[0]])  # D57：九死第 5 位（助力位）不许超强者
		and XTianqi.lineup_ok("jiusi", [sup[0], w[0], w[1], w[2], w[3]]))
	# D265：取消弱者人数下限，0 弱者合规阵容五档皆过；全弱者（5 弱者）同样合法
	_check("lineup_ok_d265_zero_and_all_weak",
		XTianqi.lineup_ok("xunchang", [st[0], st[1], st[2], st[3], st[4]])
		and XTianqi.lineup_ok("jianxian", [st[0], st[1], st[2], st[3], st[4]])
		and XTianqi.lineup_ok("jiusi", [sup[0], st[0], st[1], st[2], st[3]])
		and XTianqi.lineup_ok("lianyu", [sup[0], sup[1], st[0], st[1], st[2]])
		and XTianqi.lineup_ok("zhengdao", [sup[0], sup[1], st[0], st[1], sup[2]])
		and XTianqi.DIFFICULTIES.all(func(d0): return XTianqi.lineup_ok(d0.key, [w[0], w[1], w[2], w[3], w[4]])))
	_check("zhengdao_locked", XTianqi.locked("zhengdao") and not XTianqi.locked("lianyu"))


func _title_pages() -> void:
	_check("enter_xiyou", GameApp.enter_mode("xiyou"))
	await _wait(func(): return _scene() != null and _scene().has_method("_tq_slot"), 300)
	var entry = _scene()
	entry._tq_slot()
	await get_tree().process_frame
	var slots := range(1, 11).filter(func(i): return _find(entry, "TianqiSlot%d" % i) != null)
	_check("page_slots", slots.size() == 10, slots)
	var skin := XTianqiTitle.skin_on()
	if skin:
		# 新界面（T102）：10 格一列（同一 x、纵向递增），光标默认停第一个空格（本测试没预置存档＝1 号）
		await get_tree().process_frame
		var xs := {}
		var ys := []
		for i in range(1, 11):
			var r := _find(entry, "TianqiSlot%d" % i) as Control
			xs[r.position.x] = true
			ys.append(r.position.y)
		var asc := range(9).all(func(i): return ys[i] < ys[i + 1])
		_check("page_slots_one_column", xs.size() == 1 and asc and _find(entry, "TianqiStartPage") != null, [xs.keys(), ys])
		var fo = get_viewport().gui_get_focus_owner()
		_check("page_slots_focus_first_empty", fo != null and str(fo.name) == "TianqiSlot1", fo.name if fo != null else null)
	entry._tq_difficulty(2)
	await get_tree().process_frame
	var diffs := {}
	for d in XTianqi.DIFFICULTIES:
		var b = _find(entry, "TianqiDifficulty_" + str(d.key))
		if skin:
			# 新界面（T102）：徽记是卡里的 Badge；证道不设 disabled（焦点要能落上去），锁记在 meta locked
			var badge = b.get_node_or_null("Badge") if b != null else null
			diffs[d.key] = b != null and badge is TextureRect and badge.texture != null and not b.disabled and b.get_meta("locked", false) == XTianqi.locked(d.key)
		else:
			diffs[d.key] = b != null and b.icon != null and b.disabled == XTianqi.locked(d.key)
	_check("page_difficulty", diffs.values().all(func(v): return v), diffs)
	if skin:
		# D265：难度卡不再显示「弱者至少 N 名」（保留「能抽到」与「超强者最多上阵」）
		var diff_no_min_weak := true
		for d in XTianqi.DIFFICULTIES:
			var rows := XTianqiStartPage._rule_rows(XTianqi.difficulty(d.key))
			if rows.size() != 2 or rows.any(func(r): return str(r[0]).contains("弱者") or str(r[0]).contains("至少") or str(r[1]).contains("至少")):
				diff_no_min_weak = false
			var b = _find(entry, "TianqiDifficulty_" + str(d.key))
			if b != null:
				for n in b.get_children():
					if n is Label and (n.text.contains("弱者至少") or n.text.contains("至少")):
						diff_no_min_weak = false
		_check("page_difficulty_no_min_weak_d265", diff_no_min_weak)
	if skin and XTianqi.locked("zhengdao"):
		# 证道能拿到焦点，按确定还停在难度页（抖一下、出提示）
		var zd = _find(entry, "TianqiDifficulty_zhengdao") as Button
		zd.grab_focus()
		await get_tree().process_frame
		var got: bool = get_viewport().gui_get_focus_owner() == zd
		zd.pressed.emit()
		await get_tree().process_frame
		var toast = _find(entry, "TianqiToast")
		_check("page_zhengdao_focus_stays", got and _find(entry, "TianqiDifficulty_zhengdao") != null and _find(entry, "TianqiReroll") == null
			and toast is Label and toast.visible and toast.text == "「证道」暂未开放", [got, toast.text if toast is Label else null])
	entry._tq_lineup(2, "lianyu", [])
	await get_tree().process_frame
	_check("page_lineup", _find(entry, "TianqiReroll") != null and _find(entry, "TianqiConfirm") != null)
	if skin:
		# D265：阵容页规则句去掉「至少 N 名弱者」，保留超强者上限说明
		var rl = _find(entry, "LineupRule")
		_check("page_lineup_rule_no_min_weak_d265", rl is Label and rl.text.contains("最多上阵 2 名超强者") and not rl.text.contains("弱者") and not rl.text.contains("至少"),
			rl.text if rl is Label else null)
		# 动效「关」：重抽后新卡直接到位，不翻牌（scale／透明度当帧就是 1）
		var keep := XUiSkin.motion_override
		XUiSkin.motion_override = XUiSkin.Motion.OFF
		entry._tq_lineup(2, "lianyu", [])
		await get_tree().process_frame
		var cards := range(XTianqi.LINEUP_SIZE).map(func(i): return _find(entry, "TianqiActor%d" % i))
		_check("page_lineup_motion_off_no_flip", cards.all(func(c): return c is Control and c.scale == Vector2.ONE and c.modulate.a == 1.0),
			cards.map(func(c): return [c.scale, c.modulate.a] if c is Control else null))
		XUiSkin.motion_override = keep
		# 设置「界面风格」切原版：skin_on() 关，三页回旧窗口（不建 TianqiStartPage；难度按钮照旧 disabled 锁证道）。只改内存
		XConfig._values["codexUiSkin"] = false
		entry._tq_slot()
		await get_tree().process_frame
		var old_slots := _find(entry, "TianqiStartPage") == null and _find(entry, "TianqiSlot1") != null
		entry._tq_difficulty(2)
		await get_tree().process_frame
		var zd = _find(entry, "TianqiDifficulty_zhengdao")
		var old_diff: bool = _find(entry, "TianqiStartPage") == null and zd is Button and zd.disabled == XTianqi.locked("zhengdao")
		entry._tq_lineup(2, "lianyu", [])
		await get_tree().process_frame
		var old_lineup := _find(entry, "TianqiStartPage") == null and _find(entry, "TianqiReroll") != null
		_check("setting_old_pages_old_frame", not XTianqiTitle.skin_on() and old_slots and old_diff and old_lineup, [old_slots, old_diff, old_lineup])
		XConfig._values["codexUiSkin"] = true


func _opening() -> void:
	var w: Array = XTianqiSkills.ids(XTier.WEAK, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id))
	var sup: Array = XTianqiSkills.ids(XTier.SUPER, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not [95, 173].has(id))
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
	# 第三批（XTianqi.UNIFIED_LEGACY）：五档在数值上都按艰险跑，开局一律走原版普通（3）分支；九死与普通的差别只来自数值表
	_check("difficulty", s.difficulty == 3 and s.switch(2491) and not s.switch(2490) and not s.switch(2500) and s.flags.get("DCultyL3") == true, [s.difficulty, s.flags])
	_check("switches", s.switch(682) and s.switch(14) and s.switch(15) and s.switch(166) and int(s.variable(20)) == 1)
	_check("no_sect", not s.switch(2301) and not s.switch(2302) and not s.switch(2303) and not s.switch(2307))
	_check("items", s.item_count(4) == 1 and s.item_count(2896) == 1 and s.item_count(10) == 0 and s.item_count(1395) == 0,
		[s.item_count(4), s.item_count(2896), s.item_count(10), s.item_count(1395)])
	_check("first_slot_skills", s.actor(lineup[0]).skill_ids.has(2571) and s.actor(lineup[0]).skill_ids.has(2786))
	_check("init_events_ran", s.switch(1561) and range(1694, 1700).any(func(id): return s.switch(id)))
	_check("active", XTianqi.active(s) and XTianqi.super_cap(s) == 1)
	var saved = JSON.parse_string(XSaveSeal.read_text(XSave.path(3)))
	var flags = saved.get("flags", {}) if saved is Dictionary else {}
	_check("saved_rules", flags is Dictionary and flags.get("tianqi") is Dictionary and int(flags.tianqi.get("rules", 0)) == 1
		and str(flags.tianqi.get("difficulty", "")) == "jiusi", flags.get("tianqi") if flags is Dictionary else saved)
	# 大厅首次到达的漩涡过场（EV76）放完再离开，免得协程挂着
	# 苍龙破晓过场（EV203，XRift.CHAIN_AFTER_RIFT1）紧接着放：也等它放完
	await _wait(func(): return _map_idle(4) and s.self_switch(4, 76, "A") and (not XRift.STAGE2 or s.self_switch(4, XRift.RIFT2, "A")))


func _rules() -> void:
	var s := XState.current
	_check("bonds_off", not XBonds.enabled(s) and not XBonds.changed(s, {}) and XBonds.refresh(s, {}).is_empty())
	var sup: Array = XTianqiSkills.ids(XTier.SUPER, true).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not [95, 173].has(id))
	for id in sup.slice(0, 2):
		if not s.party.has(id):
			s.party.append(id)
			s.actor(id)
	s.battle_slots = [sup[0], sup[1], s.party[0], 0, 0]
	XItemMarks.enforce_party(s)
	var on_field := s.battle_slots.filter(func(id): return XTianqiSkills.is_super(int(id), true))
	_check("super_cap_enforced", on_field == [sup[0]], s.battle_slots)
	_check("can_deploy_cap", not XItemMarks.can_deploy(s, sup[1], 1) and not XItemMarks.can_deploy(s, sup[1], XTianqi.HELPER_SLOT) and XItemMarks.can_deploy(s, sup[0]) and XItemMarks.can_acquire_actor(s, sup[1]))
	# 原版开局建的档：不是天启篇，羁绊照旧、超强者按原版
	var old := XState.new_game_blank()
	_check("legacy_untouched", not XTianqi.active(old) and XBonds.enabled(old) and XTianqi.super_cap(old) == -1 and not XItemMarks.can_acquire_actor(old, sup[0]))
	XBonds.TIANQI_OFF = false
	_check("bonds_switch_back", XBonds.enabled(s))
	XBonds.TIANQI_OFF = true


## 开关回退：XTianqi.ENABLED = false 时标题「新的游戏」回到原版 Map001 开局（不是天启篇存档）
func _revert() -> void:
	# 发行构建（Kyo 11-11 整包只带标题和载入画面）：RELEASE_OPEN = false 时新游戏不走天启篇开局，开了才走；开发版照 ENABLED
	var sim := ReleaseEntry.simulate_release
	_check("dev_new_game_tianqi", XTianqi.new_game_enabled())
	ReleaseEntry.simulate_release = true
	_check("release_new_game_original", not XTianqi.new_game_enabled() and not XTianqi.RELEASE_OPEN)
	XTianqi.RELEASE_OPEN = true
	_check("release_open_new_game_tianqi", XTianqi.new_game_enabled())
	XTianqi.RELEASE_OPEN = false
	ReleaseEntry.simulate_release = sim
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
