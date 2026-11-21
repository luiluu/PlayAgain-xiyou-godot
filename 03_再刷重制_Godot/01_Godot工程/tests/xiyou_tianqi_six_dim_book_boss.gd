extends Node
## 天启篇六维⑤（T279）专项：怪物图鉴＋战斗内首领详情「六维」页签。
## 一、XBossStatus.six_summary：四骑士免控（「免疫停手控制」）、普通怪给控制抗性、关开关／西游档回 {}、无战力字。
## 二、怪物图鉴 status_ops：天启篇已登记画 radar＋简注；未登记整窗空；战斗内未登记「？？？」不画；西游档与关开关无 radar。
## 三、首领详情：骑士在六维开着时算首领、有第四个页签、点它切到「六维」、点拦截仍在；关开关时骑士不是首领、仍 3 个页签、点 (450,58) 仍是「全部」。
## 四、真战斗画面里画「六维」页（旧面板与新界面两种）不报错。

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _frames(n := 6) -> void:
	for i in range(n):
		await get_tree().process_frame


func _tianqi(on: bool) -> XState:
	var s := XState.new_game(3, 8, [9])
	if on:
		s.flags["tianqi"] = {"rules": 1}
	XState.current = s
	return s


func _has_op(ops: Array, kind: String) -> bool:
	return ops.any(func(o): return o[0] == kind)


func _all_text(ops: Array) -> String:
	return "".join(ops.filter(func(o): return o[0] == "t").map(func(o): return str(o[1])))


func _knight_battle(line: String) -> XBattleScene:
	var s := XTianqi.start_new_game(3, "jianxian", [9])
	XTianqi.take_pending()
	XState.current = s
	s.party.assign([9])
	XTianqiHorsemen.prepare(line, s)
	var sc := XBattleScene.new()
	sc.setup(2, true, false, XDB.map(5))
	add_child(sc)
	return sc


func _run() -> void:
	XTianqiSixDim.ENABLED = true
	var ids: Array = XEnemyBook.ids()
	var pick := -1
	for id in XTianqiSixDim.data().get("enemies", {}):
		if ids.has(int(id)):
			pick = int(id)
			break
	_check("have_enemy_pick", pick > 0, pick)
	# 一、摘要
	var s := _tianqi(true)
	var e := XEnemyBookPage.new_enemy(pick)
	var sm := XBossStatus.six_summary(e)
	_check("summary_keys", sm.has("six") and sm.has("tier_line") and sm.has("wit_hint") and sm.has("control_line") and sm.tier_line.begins_with("战商 "), sm)
	_check("summary_plain_enemy_resist", not sm.immune and str(sm.control_line).begins_with("控制抗性"), sm)
	_check("summary_six_matches_table", sm.six == XTianqiSixDim.of_enemy(pick))
	_check("summary_no_power", not JSON.stringify(sm).contains("战力"))
	_check("summary_null", XBossStatus.six_summary(null).is_empty())
	var tiers_ok := true
	for t in range(1, 6):
		tiers_ok = tiers_ok and XBossStatus.TIER_HINTS.has(t) and str(XBossStatus.TIER_HINTS[t]) != ""
	_check("tier_hints_all", tiers_ok)
	# 二、图鉴
	XEnemyBook.add(s, pick)
	var ops := XEnemyBookPage.status_ops(XEnemyBookPage.new_enemy(pick))
	_check("book_radar_registered", _has_op(ops, "radar"), ops.size())
	var radar: Array = ops.filter(func(o): return o[0] == "radar")[0]
	_check("book_radar_six", radar[1] == XTianqiSixDim.of_enemy(pick))
	_check("book_note_text", _all_text(ops).contains("战商 ") and _all_text(ops).contains("控制抗性"), _all_text(ops).left(80))
	_check("book_no_power_text", not _all_text(ops).contains("战力"))
	var other := -1
	for id in ids:
		if id != pick and not XEnemyBook.registered(s, id):
			other = id
			break
	var hid := XEnemyBookPage.status_ops(XEnemyBookPage.new_enemy(other))
	_check("book_unregistered_empty", hid.is_empty(), hid.size())
	XEnemyBookPage.BATTLE_SHOW_UNREGISTERED = false
	var hid_b2 := XEnemyBookPage.status_ops(XEnemyBookPage.new_enemy(other), false)
	_check("battle_unregistered_hidden_no_radar", not _has_op(hid_b2, "radar"))
	XEnemyBookPage.BATTLE_SHOW_UNREGISTERED = true
	var hid_b3 := XEnemyBookPage.status_ops(XEnemyBookPage.new_enemy(other), false)
	_check("battle_unregistered_shown_has_radar", _has_op(hid_b3, "radar"))
	var s2 := _tianqi(false)
	XEnemyBook.add(s2, pick)
	_check("book_xiyou_no_radar", not _has_op(XEnemyBookPage.status_ops(XEnemyBookPage.new_enemy(pick)), "radar"))
	XTianqiSixDim.ENABLED = false
	_tianqi(true)
	XEnemyBook.add(XState.current, pick)
	_check("book_disabled_no_radar", not _has_op(XEnemyBookPage.status_ops(XEnemyBookPage.new_enemy(pick)), "radar"))
	_check("summary_disabled_empty", XBossStatus.six_summary(XEnemyBookPage.new_enemy(pick)).is_empty())
	XTianqiSixDim.ENABLED = true
	# 图鉴页真画一帧
	var s3 := _tianqi(true)
	XEnemyBook.add(s3, pick)
	var page := XEnemyBookPage.new()
	add_child(page)
	await _frames(3)
	page.select(page.ids.find(pick))
	await _frames(4)
	_check("book_page_draws_radar", _has_op(page._status_ops, "radar"))
	page.queue_free()
	await _frames(2)
	# 三、首领详情
	for line in ["death", "war", "famine", "plague"]:
		var sc := _knight_battle(line)
		await _frames(40)
		var panel: XBossStatusPanel = sc.boss_panel
		var kn = XTianqiHorsemen.fight(sc.logic).knight
		var sum := XBossStatus.six_summary(kn, sc.logic)
		_check("knight_is_boss_%s" % line, XBossStatus.is_boss(kn) and panel.visible and panel.battler == kn)
		_check("knight_immune_%s" % line, sum.immune and sum.control_line == "免疫停手控制", sum)
		_check("knight_six_%s" % line, sum.six == XTianqiSixDim.of_knight(line))
		_check("tabs_four_%s" % line, panel.six_tab_on() and panel.tab_keys().size() == 4)
		panel.click_bar()
		await _frames(3)
		_check("detail_open_%s" % line, panel.open and panel.detail.visible)
		panel.click_detail(Vector2(450, 58))
		_check("tab_six_%s" % line, panel.filter == "Six", panel.filter)
		panel.click_detail(Vector2(100, 58))
		_check("tab_debuff_back_%s" % line, panel.filter == "Debuff")
		panel.click_detail(Vector2(300, 58))
		_check("tab_all_third_%s" % line, panel.filter == "All", panel.filter)
		panel.click_detail(Vector2(450, 58))
		await _frames(4)
		_check("six_page_draws_%s" % line, panel.filter == "Six" and panel.detail.visible)
		sc.queue_free()
		await _frames(4)
	# 关开关：骑士不算首领、3 个页签不变
	XTianqiSixDim.ENABLED = false
	var sc2 := _knight_battle("death")
	await _frames(40)
	var p2: XBossStatusPanel = sc2.boss_panel
	var kn2 = XTianqiHorsemen.fight(sc2.logic).knight
	_check("off_knight_not_boss", not XBossStatus.is_boss(kn2) and not p2.visible)
	_check("off_three_tabs", p2.tab_keys().size() == 3 and not p2.six_tab_on())
	sc2.queue_free()
	await _frames(4)
	XTianqiSixDim.ENABLED = true
	# 西游档：三个页签、(450,58) 仍是「全部」
	var s4 := XState.new_game_blank()
	s4.party.clear()
	s4.battle_slots.clear()
	s4.add_actor(1)
	XState.current = s4
	var sc3 := XBattleScene.new()
	sc3.setup(2, true, false, XDB.map(5))
	add_child(sc3)
	await _frames(30)
	var p3: XBossStatusPanel = sc3.boss_panel
	var boss: XEnemy = sc3.logic.enemies[0]
	boss.boss_difficulty_boss = true
	await _frames(10)
	_check("xiyou_three_tabs", p3.tab_keys().size() == 3 and not p3.six_tab_on() and p3.visible)
	p3.click_bar()
	p3.click_detail(Vector2(450, 58))
	_check("xiyou_tab_all", p3.filter == "All", p3.filter)
	_check("xiyou_summary_empty", p3.six_summary().is_empty())
	sc3.queue_free()
	await _frames(3)
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
