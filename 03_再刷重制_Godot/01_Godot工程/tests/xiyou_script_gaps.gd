extends Node
## 事件脚本普查第一批（悟空 events1，xiyou_script_census 列出的认不出写法里玩家看得到的）：
## - 大厅小盖盖调速（Map004 EV044）：$gamePlayer._moveSpeed = 3／4／5 → XState.player_move_speed；走路速度＝它＋冲刺 1（realMoveSpeed），随存档；
##   对照 mv_oracle/script_gaps_probe（generated/oracle/script_gaps.json）的 moveSpeed.*；下载具回 4（getOffVehicle setMoveSpeed(4)）另核。
## - 牛头人／纯爱战士认证（Map017 EV004）：条件分支脚本 $gameSystem.defeatNumber(66) >= 999／9999 → XEnemyBook.defeat_number；
##   对照 defeat.* 各例的分支；再用真事件页（选「认证 牛头人」）核 999 只时开称号 5、成就 121，998 只时不开。
## - 大厅猫哥「清理存档」（Map004 EV024）DataManager.cleanupIndependentItems()：无操作，不再记认不出。
## - 第二批（events2）：失去剩余伙伴号角 CE1391（for 循环 loseItem）；按变量 348 取人学技能＋角色名提示（CE1313 第一支），
##   没人时不学不提示；鲲拳 CE1160 只有一句声明的段无操作；大厅老妪头顶倒计时（Map004 EV005，画在看不见的名字条上）无操作；
##   战斗里按角色号加状态（CE43 脚本段，XBattleEventRunner._actor_states_script）：13～15 在队、不在队都加上 708。
## 反向：写法稍变（速度写成变量、击败数写成别的对象）仍记认不出。
const REF := "oracle/script_gaps.json"

var results: Array = []
var toasts: Array = []
var messages: Array = []


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


## 解释器的 host：只提供这些脚本与事件页用到的服务
func toast(text: String) -> void:
	toasts.append(text)


func show_message(msg: Dictionary) -> int:
	messages.append(msg)
	return 0   # 选项取第一项（「正常」／「认证 牛头人」）


func refresh_events() -> void:
	pass


func character(_id: int, _this_event: int):
	return null


func script(code: String) -> Array:
	return await MVScript.run(code, MVInterpreter.new(self, 0, 0, []))


func _ready() -> void:
	_run.call_deferred()


func _ref() -> Dictionary:
	var out := {}
	for c in XDB.load_json(REF).cases:
		out[str(c.id)] = c
	return out


func _speed(ref: Dictionary) -> void:
	for speed in [3, 4, 5]:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		var miss: Array = await script("$gamePlayer._moveSpeed = %d" % speed)
		var o: Dictionary = ref["moveSpeed.%d" % speed].observed
		var p := MVPlayer.new()
		p.dash = false   # 走：不冲刺（参照 _dashing false）
		p.touch_target = Vector2i(-1, -1)
		var walk := p.walk_speed()
		p.dash = true
		p.touch_target = Vector2i(0, 0)   # 点地走路算冲刺（is_dashing）
		var dash := p.walk_speed()
		p.free()
		var loaded := XState.from_dict(s.to_dict())
		_check("speed%d" % speed, miss.is_empty() and s.player_move_speed == int(o.moveSpeed) and walk == int(o.walk) and dash == int(o.dash)
			and loaded.player_move_speed == int(o.afterLoad), [miss, s.player_move_speed, walk, dash, loaded.player_move_speed, o])
	# 旧存档没有这个字段：照新游戏 4
	var d := XState.new_game(3, 1, [8, 9, 10]).to_dict()
	d.erase("playerMoveSpeed")
	_check("speed_old_save", XState.from_dict(d).player_move_speed == 4)
	# 反向：速度写成变量，仍认不出
	_check("speed_var_unknown", (await script("$gamePlayer._moveSpeed = $gameVariables.value(1)")).size() == 1)


func _defeat(ref: Dictionary) -> void:
	for id in ref:
		if not str(id).begins_with("defeat."):
			continue
		var c: Dictionary = ref[id]
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		for i in int(c.setup.kills):
			XEnemyBook.add_defeat(s, 66)
		var it := MVInterpreter.new(self, 0, 0, [
			{"code": 111, "indent": 0, "parameters": [12, str(c.setup.condition)]},
			{"code": 122, "indent": 1, "parameters": [1, 1, 0, 0, 1]}, {"code": 0, "indent": 1, "parameters": []},
			{"code": 411, "indent": 0, "parameters": []},
			{"code": 122, "indent": 1, "parameters": [1, 1, 0, 0, 2]}, {"code": 0, "indent": 1, "parameters": []},
			{"code": 412, "indent": 0, "parameters": []}, {"code": 0, "indent": 0, "parameters": []}])
		await it.run()
		_check(str(id), it.skipped.is_empty() and XEnemyBook.defeat_number(s, 66) == int(c.observed.defeatNumber) and int(s.variable(1)) == int(c.observed.branch),
			[it.skipped, XEnemyBook.defeat_number(s, 66), s.variable(1), c.observed])
	# 真事件页：选「认证 牛头人」；999 只开称号 5、成就 121，998 只不开
	for kills in [998, 999]:
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		for i in kills:
			XEnemyBook.add_defeat(s, 66)
		var page: Dictionary = {}
		for e in XDB.map(17).events:
			if e != null and int(e.id) == 4:
				page = e.pages[0]
		var it := MVInterpreter.new(self, 17, 4, page.list)
		await it.run()
		var ok: bool = kills >= 999
		_check("map17_ev4_%d" % kills, it.skipped.is_empty() and XDesignation.unlocked(5) == ok and s.achievements.has("121") == ok,
			[it.skipped, XDesignation.unlocked(5), s.achievements.keys()])
	# 反向：别的对象上的同名函数仍认不出（按假走）
	var it2 := MVInterpreter.new(self, 0, 0, [])
	it2._condition([12, "$gameTroop.defeatNumber(66) >= 1"])
	_check("defeat_other_unknown", it2.skipped.size() == 1, it2.skipped)


func _cleanup() -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var before := JSON.stringify(s.gear)
	var miss: Array = await script("DataManager.cleanupIndependentItems();")
	_check("cleanup_noop", miss.is_empty() and JSON.stringify(s.gear) == before, miss)


func _batch2(ref: Dictionary) -> void:
	# 伙伴号角：同参照给法，跑 CE1391
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	for g in [[2700, 1], [2701, 1], [2750, 3], [2805, 1], [2806, 1]]:
		s.gain_item(g[0], g[1])
	var it := MVInterpreter.new(self, 0, 0, XDB.rec("CommonEvents", 1391).list)
	await it.run()
	var want: Dictionary = ref.loseHorns.observed
	var got := {}
	for id in [2700, 2701, 2750, 2805, 2806]:
		got[str(id)] = s.item_count(id)
	_check("lose_horns", it.skipped.is_empty() and want.keys().all(func(k): return int(got[k]) == int(want[k])), [it.skipped, got, want])
	# 按变量取人学技能＋提示
	for who in [1, 0]:
		var c: Dictionary = ref["actorVar.learn.%d" % who]
		s = XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		s.set_variable(348, who)
		toasts.clear()
		var miss: Array = await script("\n".join(c.setup.lines))
		_check("actor_var_learn%d" % who, miss.is_empty() and s.actor(1).skill_ids.has(6128) == bool(c.observed.learned) and toasts == c.observed.toasts,
			[miss, s.actor(1).skill_ids.has(6128), toasts, c.observed])
	s = XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	s.set_variable(348, 1)
	toasts.clear()
	var before := str(s.actor(1).skill_ids)
	var miss2: Array = await script(str(ref["actorVar.declareOnly"].setup.line))
	_check("actor_var_declare_only", miss2.is_empty() and str(s.actor(1).skill_ids) == before and toasts.is_empty() and bool(ref["actorVar.declareOnly"].observed.sameSkills), [miss2, toasts])
	# 反向：声明后跟认不出的语句，整段仍记认不出、不学
	var miss3: Array = await script("var actor = $gameActors.actor($gameVariables.value(348));\nactor.gainExp(5);")
	_check("actor_var_unknown_tail", not miss3.is_empty(), miss3)
	# 老妪头顶倒计时：两段脚本都无操作；夹了改状态的写法仍认不出
	var ev: Dictionary = {}
	for e in XDB.map(4).events:
		if e != null and int(e.id) == 5:
			ev = e
	var blocks := []
	var list: Array = ev.pages[0].list
	var i := 0
	while i < list.size():
		if int(list[i].code) == 355:
			var code := str(list[i].parameters[0])
			while i + 1 < list.size() and int(list[i + 1].code) == 655:
				i += 1
				code += "\n" + str(list[i].parameters[0])
			blocks.append(code)
		i += 1
	var all_ok := blocks.size() == 2
	for b in blocks:
		all_ok = all_ok and (await script(b)).is_empty()
	_check("lottery_timer_noop", all_ok, blocks.size())
	_check("lottery_timer_write_unknown", not (await script("window.StarGetRefLAM45Time = setInterval(function(){ Star.GetLotteryAnimation._eventsName[5].bitmap.clear(); $gameVariables.setValue(1, 2); }, 1000)")).is_empty())


func _battle_states(ref: Dictionary) -> void:
	var list: Array = XDB.rec("CommonEvents", 43).list.slice(8)
	for tag in ["inParty", "notInParty"]:
		var c: Dictionary = ref["actorStates." + tag]
		var party: Array = c.setup.party
		var s := XState.new_game(3, int(party[0]), party.slice(1).map(func(x): return int(x)))
		XState.current = s
		var l := XBattleLogic.new()
		l.elite_roll = 100.0
		l.setup(2, s)
		var r := XBattleEventRunner.new(l, list.duplicate(true))
		for k in 50:
			if r.advance().kind == "done":
				break
		var got := {}
		for id in [13, 14, 15]:
			var b = null
			for a in l.actors:
				if a != null and int(a.actor_id) == id:
					b = a
			got[str(id)] = (b if b != null else s.actor(id)).is_state_affected(708)
		_check("battle_states_" + tag, r.skipped.is_empty() and got.keys().all(func(k): return bool(got[k]) == bool(c.observed[k])), [r.skipped, got, c.observed])
	# 反向：夹一句别的写法，整段不认、照记认不出
	var l2 := XBattleLogic.new()
	l2.setup(2, XState.current)
	var r2 := XBattleEventRunner.new(l2, [{"code": 355, "indent": 0, "parameters": ["var a = $gameActors.actor(13);"]},
		{"code": 655, "indent": 0, "parameters": ["a.addState(708); a.gainHp(5);"]}, {"code": 0, "indent": 0, "parameters": []}])
	for k in 20:
		if r2.advance().kind == "done":
			break
	_check("battle_states_unknown_tail", not r2.skipped.is_empty(), r2.skipped)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_script_gaps"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	var ref := _ref()
	_check("ref_loaded", ref.size() == 16, ref.size())
	await _speed(ref)
	await _defeat(ref)
	await _cleanup()
	await _batch2(ref)
	_battle_states(ref)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
