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
## - 第三批（events3）：投石问路 CE2486 每个敌人一条暴闪提示（troopCev）；猛击 CE78 带 345 且穿着防具 506 时全体敌人加 43（setArmorState.*）。
## - 第四批（八戒 events1）：极尽升华 CE1388～1390（Map047／147／182 守层者送原初火种后调）：会 A 的角色（在队、不在队都算）换成 B，
##   对照 ascend.* 十二例；再核存读档后 actor_ops 带 from、读档后才建的角色同样套用；漏了 forgetSkill 的变体仍记认不出，无条件版本照普通循环认得。
## - 没装载的插件（八戒 events1）：签到板／补签（CE6、330、373）、状态图鉴 CE429、地图快捷栏 CE478／485：原版抛错被吞，无操作，
##   对照 unloaded.* 七例（存档内容、场景都不变）；`itemslot` 只认 show／hide，别的写法仍记认不出。
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


## 猫哥清理存档（zchuli.js，审查 21 期 P3①）：在队成员回满 HP／MP、倒下的救起（参照 cleanupHeal）；身上与背包的装备不变；
## 仓库里的武器防具：O-147 o_cleanup_keep_warehouse 默认留着，false 照原版丢掉（道具不动）
func _cleanup(ref: Dictionary) -> void:
	for keep in [true, false]:
		if keep:
			MVScript.o_cleanup_keep_warehouse = true
		else:
			MVScript.o_cleanup_keep_warehouse = false
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		var m := s.members()
		m[0].hp = floorf(m[0].mhp / 2.0)
		m[0].mp = floorf(m[0].mmp / 2.0)
		m[1].hp = 0.0
		m[1].add_state(1)
		XWarehouse.create(s, "<仓库:999>")
		var w: Dictionary = s.warehouses["仓库"]
		w.items.armor.append(XGear.create("armor", 2, s))
		w.items.item.append(5)
		w.qtty.item["5"] = 3
		w.currentCapacity = 4
		var before := JSON.stringify(s.gear)
		var miss: Array = await script("DataManager.cleanupIndependentItems();")
		var got: Array = s.members().map(func(a): return {"id": int(a.actor_id), "full": a.hp == a.mhp and a.mp == a.mmp, "dead": a.is_dead()})
		var want: Array = ref.cleanupHeal.observed.members.map(func(x): return {"id": int(x.id), "full": bool(x.full), "dead": bool(x.dead)})
		_check("cleanup_heal_%s" % keep, miss.is_empty() and got == want and JSON.stringify(s.gear) == before, [miss, got, want])
		_check("cleanup_warehouse_%s" % keep, w.items.armor.size() == (1 if keep else 0) and w.items.item == [5] and int(w.qtty.item["5"]) == 3
			and int(w.currentCapacity) == (4 if keep else 3), [w.items.armor.size(), w.items.item, w.currentCapacity])
	MVScript.o_cleanup_keep_warehouse = true


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


func _battle_run(l: XBattleLogic, list: Array) -> XBattleEventRunner:
	var r := XBattleEventRunner.new(l, list.duplicate(true))
	for k in 50:
		if r.advance().kind == "done":
			break
	return r


func _battle_batch3(ref: Dictionary) -> void:
	var s := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s
	var l := XBattleLogic.new()
	l.elite_roll = 100.0
	l.setup(53, s)   # 敌群 53：有暴闪 5% 的敌人（同参照）
	var list: Array = XDB.rec("CommonEvents", 2486).list.filter(func(c): return int(c.code) in [355, 655, 0]).slice(-4)
	var r := _battle_run(l, list)
	var got: Array = r.take_logs().filter(func(x): return x.get("type", "") == "toast").map(func(x): return str(x.text))
	_check("troop_cev", r.skipped.is_empty() and got == ref.troopCev.observed.toasts, [r.skipped, got, ref.troopCev.observed])
	for tag in ["wear", "bare"]:
		var c: Dictionary = ref["setArmorState." + tag]
		s = XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		l = XBattleLogic.new()
		l.elite_roll = 100.0
		l.setup(2, s)
		for b in l.actors:
			if b != null and int(b.actor_id) == 1:
				b.add_state(345)
				if tag == "wear":   # 同参照：当作穿着 506（新局穿不上，开战会卸下穿不了的），开战后直接放进第 5 槽
					var eq: Array = b.equips.duplicate()
					eq[4] = XGear.create("armor", 506, s)
					b.equips = eq
		r = _battle_run(l, XDB.rec("CommonEvents", 78).list)
		var hit := l.enemies.map(func(e): return e.is_state_affected(43))
		_check("set_armor_state_" + tag, r.skipped.is_empty() and hit == c.observed.enemies, [r.skipped, hit, c.observed])


## 极尽升华：对照 ascend.<CE>.<场景> 的 1／8／11 号 A、B 有无
func _ascend(ref: Dictionary) -> void:
	for ce in [1388, 1389, 1390]:
		for tag in ["none", "party", "offParty", "both"]:
			var c: Dictionary = ref["ascend.%d.%s" % [ce, tag]]
			var a_id := int(c.setup["from"])
			var b_id := int(c.setup.to)
			var s := XState.new_game(3, 1, [8, 9, 10])
			XState.current = s
			for who in c.setup.who:
				s.actor(int(who)).learn_skill(a_id)
			var learned_ok: bool = c.setup.who.all(func(w): return s.actor(int(w)).skill_ids.has(a_id))
			var it := MVInterpreter.new(self, 0, 0, XDB.rec("CommonEvents", ce).list)
			await it.run()
			var got := {}
			for id in [1, 8, 11]:
				var a := s.actor(id)
				got["a%d" % id] = [a.skill_ids.has(a_id), a.skill_ids.has(b_id)]
			var want: Dictionary = c.observed
			var same: bool = true
			for k in got:
				same = same and got[k][0] == bool(want[k][0]) and got[k][1] == bool(want[k][1])
			_check("ascend_%d_%s" % [ce, tag], learned_ok and it.skipped.is_empty() and same, [learned_ok, it.skipped, got, want])
	# 存读档：actor_ops 带 from；读档后才建的角色（装着 A 的初始技能不会有，这里直接塞 A 再建？不——只核 op 回来）
	var s2 := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s2
	s2.actor(1).learn_skill(6133)
	await MVInterpreter.new(self, 0, 0, XDB.rec("CommonEvents", 1388).list).run()
	var s3 := XState.from_dict(JSON.parse_string(JSON.stringify(s2.to_dict())))
	XState.current = s3
	_check("ascend_save_roundtrip", s3.actor_ops.size() == s2.actor_ops.size() and s3.actor_ops.size() >= 1 and int(s3.actor_ops[-1].get("from", 0)) == 6133 and str(s3.actor_ops[-1].op) == "replace" and s3.actor(1).skill_ids.has(6236) and not s3.actor(1).skill_ids.has(6133),
		[s3.actor_ops, s3.actor(1).skill_ids])
	# 反向：去掉 hasSkill 判断的写法（会把没学过的人也学上 B）仍记认不出
	var miss: Array = await script("for (var j = 1; j < $dataActors.length; j++) {\nvar actor = $gameActors.actor(j);\nactor.forgetSkill(6133);\nactor.learnSkill(6236);\n}")
	_check("ascend_unconditional_is_plain_loop", miss.is_empty(), miss)   # 无条件版本本来就是普通循环（forget＋learn 各一条），照旧认得
	var miss2: Array = await script("for (var j = 1; j < $dataActors.length; j++) {\nvar actor = $gameActors.actor(j);\nif(actor.hasSkill(6133)){\nactor.learnSkill(6236);\n}\n}")
	_check("ascend_missing_forget_unknown", not miss2.is_empty(), miss2)


## 没装载的插件：整段无操作、不记认不出，存档内容不变（同 oracle unloaded.*）
func _unloaded(ref: Dictionary) -> void:
	for pair in [["signBoardScene", 6], ["makeUpSign", 330], ["makeUpSign", 373], ["stateBook", 429], ["openItemSlot", 478]]:
		var c: Dictionary = ref["unloaded.%s" % pair[0]]
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		var before := JSON.stringify(s.to_dict())
		var it := MVInterpreter.new(self, 0, 0, XDB.rec("CommonEvents", int(pair[1])).list)
		await it.run()
		_check("unloaded_%s_ce%d" % [pair[0], pair[1]], it.skipped.is_empty() and bool(c.observed.sameState) and JSON.stringify(s.to_dict()) == before, [it.skipped, c.observed])
	# CE485 的两条插件指令分开核（CE 里夹着开关与提示，这里只核插件指令本身）
	for line in ["itemslot show", "itemslot hide"]:
		var it2 := MVInterpreter.new(self, 0, 0, [])
		it2._plugin_command(line)
		_check("itemslot_cmd_" + line.split(" ")[1], it2.skipped.is_empty(), it2.skipped)
	var it3 := MVInterpreter.new(self, 0, 0, [])
	it3._plugin_command("itemslot toggle")
	_check("itemslot_other_unknown", it3.skipped.size() == 1, it3.skipped)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_script_gaps"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XMessageBox.auto = true
	var ref := _ref()
	_check("ref_loaded", ref.size() == 39, ref.size())
	await _speed(ref)
	await _defeat(ref)
	await _cleanup(ref)
	await _batch2(ref)
	_battle_states(ref)
	_battle_batch3(ref)
	await _ascend(ref)
	await _unloaded(ref)
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
