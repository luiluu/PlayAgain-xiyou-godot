extends Node
## 天启篇 31～36 层重做专项（XTianqiSummit、summit.json）。
## 一、数据：数字避开 4、台词齐全、借的图和敌群在。
## 二、门：变量 20 到 33 照原版；34 起接管，34 层鸿钧（赢了 → 35、输了／不上回大厅），35 层本线影子（→ 36），36 层本线决战（记通关、可轮回），
##    打完 36 层门上说「空了」；地图名换新层名、换色、回大厅复原。
## 三、洪荒通关奖励和 6213 挪到 36 层：开关 2483 开着才有；打过鸿钧给奖励，没打过照原版学 6213（天启篇默认不学）。
## 四、旧 34 层（158）：天启篇不随机遇敌、决战事件不跑。
## 五、再挑战（大厅 EV062）：打过的 34～36 层守层者能再打，不改进度；「别的事」照原事件。
## 六、鸿钧：鸿蒙老祖那只换名字、能力值乘 rate。
## 七、原版档、开关关掉、线没做好：一处都不动。
## 数字避开 4（Kyo 11-11）：用例里的层号、地图号照实写。

## 地图场景的替身：文字记下，选项依次取 answers（取完选最后一个），换图记下（连同当时的地图名），开战按 results 依次给结果
class FakeHost extends RefCounted:
	var answers: Array = []
	var asked: Array = []
	var said: Array = []
	var moves: Array = []
	var names: Array = []
	var battles: Array = []
	var results: Array = []
	func show_text(_f: String, _i: int, lines: Array) -> void:
		said.append_array(lines)
	func show_text_with_choices(_f: String, _i: int, lines: Array, options: Array, _cancel: int) -> int:
		said.append_array(lines)
		asked.append(options)
		return int(answers.pop_front()) if not answers.is_empty() else options.size() - 1
	func transfer(id: int, x: int, y: int, d: int, _fade := 0) -> void:
		moves.append([id, x, y, d])
		names.append(XTianqiSummit.map_name(XState.current, id, "原名"))
		XState.current.map_id = id
	func start_battle(troop: int, can_escape: bool, can_lose: bool, _random := false) -> int:
		battles.append({"troop": troop, "escape": can_escape, "lose": can_lose, "summit": XTianqiSummit.pending(),
			"knight": XTianqiHorsemen.pending(), "mode": XTianqiHorsemen._pending_mode, "tone": XState.current.screen.tone.duplicate()})
		XTianqiSummit._pending = ""
		XTianqiHorsemen._pending = ""
		XTianqiHorsemen._pending_mode = "body"
		return int(results.pop_front()) if not results.is_empty() else 0


var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


## 天启篇存档、5 个弱者、选了 line（战争线默认开场已打完）、变量 20 = floor
func _state(floor := 34, line := "war", opening := true) -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, floor)
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
	if opening and line == "war":
		XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	return s


func _has(host: FakeHost, text: String) -> bool:
	return host.said.any(func(t): return str(t).contains(text))


func _run() -> void:
	XMessageBox.auto = true
	seed(20261111)
	XSave.dir_override = "user://test_xiyou_tianqi_summit"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	DirAccess.remove_absolute(XSave.dir_override.path_join("global.json"))
	_data()
	await _door34()
	await _door35()
	await _door36()
	await _honghuang()
	_old158()
	await _rechallenge()
	_hongjun_battle()
	await _plain()
	DirAccess.remove_absolute(XGlobalVars.path())
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _data() -> void:
	XTianqiSummit.reload()
	_check("nice_numbers", XTianqiSummit.nice_number_violations().is_empty(), XTianqiSummit.nice_number_violations())
	var keys := ["door", "door_top", "arrive34", "arrive35", "arrive36", "ask", "hongjun_before", "hongjun_win", "hongjun_lost",
		"shadow_win", "lost", "not_ready", "honghuang_ask", "honghuang_done", "honghuang_skip", "rechallenge_head"]
	_check("scenes_all", keys.all(func(k): return not XTianqiSummit.scene(k).is_empty()), keys.filter(func(k): return XTianqiSummit.scene(k).is_empty()))
	_check("top_36", XTianqiSummit.top() == 36 and XTianqiSummit.from_floor() == 34)
	for n in [34, 35, 36]:
		var info := XTianqiSummit.floor_info(n)
		_check("floor_map_%d" % n, not XDB.map(int(info.map)).is_empty(), info)
	var t := XDB.rec("Troops", int(XTianqiSummit.data().hongjun.troop))
	_check("hongjun_troop", t.get("members", []).any(func(m): return int(m.enemyId) == int(XTianqiSummit.data().hongjun.enemy)), t)
	_check("shell_troop", not XDB.rec("Troops", int(XTianqiSummit.data().shell_troop)).is_empty())


func _door34() -> void:
	# 33 层照原版的门
	var s := _state(33)
	_check("door33_original", not XTianqiSummit.intercepts(s, 4, 36))
	s.set_variable(20, 34)
	_check("door34_intercept", XTianqiSummit.intercepts(s, 4, 36) and not XTianqiSummit.intercepts(s, 4, 35))
	# 门上「离开」：不动
	var host := FakeHost.new()
	host.answers = [1]
	_check("door_leave", await XTianqiSummit.run_event(host, s, 4, 36) and host.moves.is_empty() and host.battles.is_empty())
	_check("door_prompt", _has(host, "当前层数：34"), host.said)
	# 进图不上：回大厅
	host = FakeHost.new()
	host.answers = [0, 1]
	await XTianqiSummit.run_door(host, s)
	_check("floor34_back", host.battles.is_empty() and host.moves.map(func(m): return int(m[0])) == [158, 4] and int(s.variable(20)) == 34, host.moves)
	_check("floor34_name", host.names[0] == "34层 太清天" and host.names[1] == "原名", host.names)
	_check("floor34_said", _has(host, "太清天"))
	# 输了：层数不变、回大厅
	host = FakeHost.new()
	host.answers = [0, 0]
	host.results = [2]
	await XTianqiSummit.run_door(host, s)
	_check("hongjun_battle", host.battles.size() == 1 and host.battles[0].troop == 469 and host.battles[0].summit == "hongjun" and host.battles[0].lose
		and not host.battles[0].escape, host.battles)
	_check("hongjun_tone", host.battles[0].tone == XTianqiSummit.floor_info(34).tone.map(func(x): return float(x)), host.battles[0].tone)
	_check("hongjun_lost", int(s.variable(20)) == 34 and not XTianqiSummit.hongjun_beaten(s) and _has(host, "想清楚了再来") and host.moves[-1][0] == 4)
	_check("tone_reset", s.screen.tone == [0.0, 0.0, 0.0, 0.0], s.screen.tone)
	# 赢了：→ 35
	host = FakeHost.new()
	host.answers = [0, 0]
	host.results = [0]
	await XTianqiSummit.run_door(host, s)
	_check("hongjun_win", int(s.variable(20)) == 35 and XTianqiSummit.hongjun_beaten(s) and _has(host, "第 34 层") and host.moves[-1][0] == 4)
	var back := XState.from_dict(s.to_dict())
	_check("progress_saved", XTianqiSummit.hongjun_beaten(back))
	# 别的线（饥荒，还没做好）：34 层鸿钧照样打
	var f := _state(34, "famine")
	host = FakeHost.new()
	host.answers = [0, 0]
	await XTianqiSummit.run_door(host, f)
	_check("famine_hongjun", host.battles.size() == 1 and host.battles[0].summit == "hongjun" and int(f.variable(20)) == 35)


func _door35() -> void:
	var s := _state(35)
	var host := FakeHost.new()
	host.answers = [0, 0]
	host.results = [0]
	await XTianqiSummit.run_door(host, s)
	_check("shadow_battle", host.battles.size() == 1 and host.battles[0].knight == "war" and host.battles[0].mode == "shadow" and host.battles[0].troop == 30, host.battles)
	_check("shadow_map", host.moves.map(func(m): return int(m[0])) == [157, 4] and host.names[0] == "35层 玉清天", [host.moves, host.names])
	_check("shadow_win", int(s.variable(20)) == 36 and _has(host, "裂缝还在") and _has(host, "第 35 层"))
	# 输了：不变
	var s2 := _state(35)
	host = FakeHost.new()
	host.answers = [0, 0]
	host.results = [2]
	await XTianqiSummit.run_door(host, s2)
	_check("shadow_lost", int(s2.variable(20)) == 35 and _has(host, "还能再来"))
	# 线还没做好（饥荒）：说一句、不打、不变
	var f := _state(35, "famine")
	host = FakeHost.new()
	host.answers = [0, 0]
	_check("famine_shadow", await XTianqiSummit.run_floor(host, f, 35) == -1 and host.battles.is_empty() and _has(host, "还没修好") and int(f.variable(20)) == 35)
	# 战争线开场没打完（不该到这里，保险）：不打
	var w := _state(35, "war", false)
	host = FakeHost.new()
	host.answers = [0, 0]
	_check("war_not_open", await XTianqiSummit.run_floor(host, w, 35) == -1 and host.battles.is_empty())


func _door36() -> void:
	var s := _state(36)
	var host := FakeHost.new()
	host.answers = [0, 0]
	host.results = [2]
	await XTianqiSummit.run_door(host, s)
	_check("final_lost", host.battles.size() == 1 and host.battles[0].knight == "war" and host.battles[0].mode == "body" and not XTianqiSummit.top_cleared(s))
	host = FakeHost.new()
	host.answers = [0, 0]
	host.results = [0]
	await XTianqiSummit.run_door(host, s)
	_check("final_map", host.moves.map(func(m): return int(m[0])) == [158, 4] and host.names[0] == "36层 天外天", [host.moves, host.names])
	_check("final_win", XTianqiSummit.top_cleared(s) and bool(XTianqiWarLine.progress(s).cleared) and bool(s.flags.tianqi.reincarnate)
		and int(s.variable(20)) == 36 and _has(host, "未经姐姐复核"))
	# 打完：门上说空了，不再进
	host = FakeHost.new()
	await XTianqiSummit.run_door(host, s)
	_check("door_top", host.moves.is_empty() and host.battles.is_empty() and _has(host, "空了"))
	# 变量 20 超过 36（旧档等）也按 36 算
	var s2 := _state(37)
	host = FakeHost.new()
	host.answers = [1]
	await XTianqiSummit.run_door(host, s2)
	_check("door_cap_36", _has(host, "当前层数：36"), host.said)


func _honghuang() -> void:
	# 开关 2483 没开：没有奖励
	var s := _state(36)
	XTianqiSummit.progress(s)["hongjun"] = true
	var host := FakeHost.new()
	host.answers = [0, 0]
	await XTianqiSummit.run_door(host, s)
	_check("honghuang_off", int(s.variable(1476)) == 0 and not _has(host, "完美通关"))
	# 开着、打过鸿钧：问存档，答「是」给奖励
	var s2 := _state(36)
	XTianqiSummit.progress(s2)["hongjun"] = true
	s2.set_switch(2483, true)
	host = FakeHost.new()
	host.answers = [0, 0, 0]
	await XTianqiSummit.run_door(host, s2)
	_check("honghuang_done", int(s2.variable(1476)) == 1 and _has(host, "完美通关") and bool(XTianqiSummit.progress(s2).honghuang), host.said)
	_check("honghuang_global", float(XGlobalVars.stored().variables.get(1476, 0)) == 1.0, XGlobalVars.stored())
	# 开着、没打过鸿钧：天启篇默认不学 6213；开关关掉照原版学
	var s3 := _state(36)
	s3.set_switch(2483, true)
	host = FakeHost.new()
	host.answers = [0, 0]
	await XTianqiSummit.run_door(host, s3)
	_check("gaze_skip", _has(host, "天道注视") and s3.members().all(func(a): return not a.native_skill_ids().has(6213)))
	var s4 := _state(36)
	s4.set_switch(2483, true)
	XTianqi.NO_HEAVEN_GAZE = false
	host = FakeHost.new()
	host.answers = [0, 0]
	await XTianqiSummit.run_door(host, s4)
	XTianqi.NO_HEAVEN_GAZE = true
	_check("gaze_learn", s4.members().all(func(a): return a.native_skill_ids().has(6213)))


func _old158() -> void:
	var s := _state(34)
	_check("no_encounter_158", XTianqiSummit.no_encounter(s, 158) and not XTianqiSummit.no_encounter(s, 157))
	_check("relic_blocked", XTianqiSummit.intercepts(s, 158, 1) and not XTianqiSummit.intercepts(s, 158, 2))
	_check("name_other_map", XTianqiSummit.map_name(s, 158, "决战：天外天") == "决战：天外天")


func _rechallenge() -> void:
	var s := _state(34)
	_check("rechallenge_none", not XTianqiSummit.intercepts(s, 4, 62) and XTianqiSummit.rechallenge_options(s).is_empty())
	XTianqiSummit.progress(s)["hongjun"] = true
	s.set_variable(20, 35)
	_check("rechallenge_34", XTianqiSummit.intercepts(s, 4, 62) and XTianqiSummit.rechallenge_options(s) == [34])
	var host := FakeHost.new()
	host.answers = [0]
	_check("rechallenge_fight", await XTianqiSummit.run_event(host, s, 4, 62) and host.battles.size() == 1 and host.battles[0].summit == "hongjun"
		and int(s.variable(20)) == 35 and host.moves.is_empty(), host.battles)
	host = FakeHost.new()
	host.answers = [1]
	_check("rechallenge_other", not await XTianqiSummit.run_event(host, s, 4, 62) and host.battles.is_empty())
	host = FakeHost.new()
	host.answers = [2]
	_check("rechallenge_leave", await XTianqiSummit.run_event(host, s, 4, 62) and host.battles.is_empty())
	s.set_variable(20, 36)
	XTianqiSummit.progress(s)["cleared"] = true
	_check("rechallenge_all", XTianqiSummit.rechallenge_options(s) == [34, 35, 36])
	host = FakeHost.new()
	host.answers = [2]
	await XTianqiSummit.run_rechallenge(host, s)
	_check("rechallenge_knight", host.battles.size() == 1 and host.battles[0].knight == "war" and host.battles[0].mode == "body"
		and host.asked[0].any(func(o): return str(o).contains("战争骑士")), [host.battles, host.asked])
	host = FakeHost.new()
	host.answers = [1]
	await XTianqiSummit.run_rechallenge(host, s)
	_check("rechallenge_shadow", host.battles.size() == 1 and host.battles[0].mode == "shadow" and int(s.variable(20)) == 36)


func _hongjun_battle() -> void:
	var s := _state(34)
	var plain := XBattleLogic.new()
	plain.setup(469, s)
	var p0: XEnemy = plain.enemies.filter(func(e): return int(e.enemy_id) == 537)[0]
	_check("prepare_hongjun", XTianqiSummit.prepare_hongjun(s))
	var lg := XBattleLogic.new()
	lg.setup(469, s)
	var e: XEnemy = lg.enemies.filter(func(x): return int(x.enemy_id) == 537)[0]
	_check("hongjun_name", e.display_name().contains("鸿钧") and not e.display_name().contains("鸿蒙") and p0.display_name().contains("鸿蒙老祖"),
		[e.display_name(), p0.display_name()])
	_check("hongjun_hp", is_equal_approx(e.mhp / p0.mhp, 2.0) and is_equal_approx(e.hp, e.mhp), [e.mhp, p0.mhp])
	_check("hongjun_atk", is_equal_approx(float(e.atk) / float(p0.atk), 1.5), [e.atk, p0.atk])
	_check("hongjun_no_borrowed_drops", e.data().dropItems.is_empty() and not p0.data().dropItems.is_empty())
	_check("hongjun_pending_used", XTianqiSummit.pending() == "")
	plain.end_battle(0)
	lg.end_battle(0)


func _plain() -> void:
	# 原版档：门照原版、158 照旧遇敌、事件照跑、鸿钧不换
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var p := XState.new_game_blank()
	for id in lineup:
		p.add_actor(int(id))
	p.set_variable(20, 34)
	XState.current = p
	_check("plain_door", not XTianqiSummit.intercepts(p, 4, 36) and not XTianqiSummit.intercepts(p, 158, 1) and not XTianqiSummit.intercepts(p, 4, 62))
	_check("plain_encounter", not XTianqiSummit.no_encounter(p, 158))
	_check("plain_name", XTianqiSummit.map_name(p, 158, "决战：天外天") == "决战：天外天")
	_check("plain_no_prepare", not XTianqiSummit.prepare_hongjun(p))
	# 天启篇没选线：不接（门由选线的门锁挡）
	var n := _state(34, "")
	_check("no_line", not XTianqiSummit.intercepts(n, 4, 36) and not XTianqiSummit.no_encounter(n, 158))
	# 开关关掉：回到原版
	var s := _state(34)
	XTianqiSummit.ENABLED = false
	_check("switch_off", not XTianqiSummit.intercepts(s, 4, 36) and not XTianqiSummit.intercepts(s, 158, 1) and not XTianqiSummit.no_encounter(s, 158)
		and not XTianqiSummit.prepare_hongjun(s))
	XTianqiSummit.ENABLED = true
	# 发行构建（天启篇没开放）：不接
	_check("release_closed", not XTianqi.RELEASE_OPEN)
